import 'dart:async';

import 'package:audio_plugin/audio_plugin.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/entities.dart';
import '../../models/session_config.dart';

/// Single Source of Truth for audio operations.
/// Manages devices, sessions, and routes.
class AudioService extends ChangeNotifier {
  AudioService() {
    _init();
  }

  final AudioPlugin _plugin = AudioPlugin();

  // State
  List<AudioDeviceEntity> _devices = [];
  AudioDefaultDevices _defaults = AudioDefaultDevices.empty;
  AudioSession _session = AudioSession.empty;
  List<AudioRoute> _routes = [];
  int _bufferFrames = 256;
  String? _outputDeviceUID;
  bool _isLoading = false;
  bool _isStartingSession = false;
  String? _error;

  // Device event handling
  StreamSubscription<DeviceEvent>? _deviceEventSubscription;
  DeviceEvent? _lastDeviceEvent;

  // Getters
  List<AudioDeviceEntity> get devices => _devices;
  List<AudioDeviceEntity> get inputDevices =>
      _devices.where((d) => d.isInput).toList();
  List<AudioDeviceEntity> get outputDevices =>
      _devices.where((d) => d.isOutput).toList();
  AudioDefaultDevices get defaults => _defaults;
  List<AudioRoute> get routes => List.unmodifiable(_routes);
  bool get isLoading => _isLoading;
  String? get error => _error;
  DeviceEvent? get lastDeviceEvent => _lastDeviceEvent;

  Future<void> _init() async {
    try {
      // Request microphone permission first - required for audio input
      await _plugin.requestMicrophonePermission();
      await _loadSessionConfig();
      await loadDevices();
      _startListeningToDeviceEvents();
    } catch (e) {
      _error = 'Failed to initialize audio plugin: $e';
      notifyListeners();
    }
  }

  void _startListeningToDeviceEvents() {
    _deviceEventSubscription?.cancel();
    _deviceEventSubscription = _plugin.deviceEvents.listen(_handleDeviceEvent);
  }

  void _handleDeviceEvent(DeviceEvent event) {
    _lastDeviceEvent = event;

    if (event is DeviceDisconnectedEvent) {
      _handleDeviceDisconnected(event);
    } else if (event is DeviceConnectedEvent) {
      _handleDeviceConnected(event);
    }

    notifyListeners();
  }

  void _handleDeviceDisconnected(DeviceDisconnectedEvent event) {
    // Remove the device from the list
    _devices.removeWhere((d) => d.uid == event.uid);

    // Mark affected routes as disabled due to device disconnection
    for (var i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      if (route.inDeviceUID == event.uid || route.outDeviceUID == event.uid) {
        // Only mark as disabledByDevice if the route was previously enabled
        if (route.enabled) {
          _routes[i] = route.copyWith(enabled: false, disabledByDevice: true);
        }
      }
    }

    _error = 'Device disconnected: ${event.name}';
  }

  void _handleDeviceConnected(DeviceConnectedEvent event) {
    // Refresh device list and restore routes for the reconnected device
    _handleDeviceReconnection(event);
  }

  Future<void> _handleDeviceReconnection(DeviceConnectedEvent event) async {
    // Refresh device list to get the new device
    try {
      final pluginDevices = await _plugin.listDevices();
      _devices = pluginDevices.map(_mapDevice).toList();
    } catch (_) {}

    // Automatically restore routes that use this device
    await restoreRoutesForDevice(event.uid);

    _error = 'Device connected: ${event.name}';
    notifyListeners();
  }

  /// Clears the last device event after it has been handled by the UI
  void clearLastDeviceEvent() {
    _lastDeviceEvent = null;
  }

  /// Attempts to restore routes that were disabled due to device disconnection.
  /// Only restores routes that have disabledByDevice = true.
  /// Routes disabled manually by the user will NOT be restored.
  Future<void> restoreRoutesForDevice(String deviceUID) async {
    final routesToRestore = <AudioRoute>[];

    // Find routes that need to be restored (only those disabled by device disconnection)
    for (var i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      if ((route.inDeviceUID == deviceUID || route.outDeviceUID == deviceUID) &&
          !route.enabled &&
          route.disabledByDevice) {
        // Check if both devices are now available
        final inputAvailable = deviceForUID(route.inDeviceUID) != null;
        final outputAvailable = deviceForUID(route.outDeviceUID) != null;

        if (inputAvailable && outputAvailable) {
          routesToRestore.add(route);
        }
      }
    }

    // Restore each route by re-adding it to the audio engine
    for (final route in routesToRestore) {
      try {
        // Re-add the route to recreate InputTap and OutputUnit
        await _plugin.addRoute(
          RouteConfig(
            id: route.id,
            inDeviceUID: route.inDeviceUID,
            inL: route.inL,
            inR: route.inR,
            outDeviceUID: route.outDeviceUID,
            outL: route.outL,
            outR: route.outR,
            gain: route.gain,
            enabled: true,
          ),
        );

        // Update local state - clear disabledByDevice flag
        final index = _routes.indexWhere((r) => r.id == route.id);
        if (index >= 0) {
          _routes[index] = route.copyWith(
            enabled: true,
            disabledByDevice: false,
          );
        }
      } catch (_) {
        // Route restoration failed, keep it disabled
      }
    }

    if (routesToRestore.isNotEmpty) {
      await _saveSessionConfig();
      notifyListeners();
    }
  }

  /// Gets routes that are disabled due to a specific device being disconnected
  List<AudioRoute> getDisabledRoutesForDevice(String deviceUID) {
    return _routes.where((route) {
      if (!route.enabled) {
        return route.inDeviceUID == deviceUID ||
            route.outDeviceUID == deviceUID;
      }
      return false;
    }).toList();
  }

  Future<void> _loadSessionConfig() async {
    final config = await SessionConfig.load();
    if (config != null) {
      _bufferFrames = config.bufferFrames;
      _outputDeviceUID = config.outputDeviceUID;
      // Routes will be restored after session starts in _restoreRoutes()
    }
  }

  Future<void> _saveSessionConfig() async {
    final config = SessionConfig(
      outputDeviceUID: _outputDeviceUID,
      bufferFrames: _bufferFrames,
      routes: _routes,
    );
    await config.save();
  }

  Future<void> loadDevices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final pluginDevices = await _plugin.listDevices();
      final pluginDefaults = await _plugin.getDefaultDevices();

      _devices = pluginDevices.map(_mapDevice).toList();
      _defaults = AudioDefaultDevices(
        defaultInputUID: pluginDefaults.defaultInputUID,
        defaultOutputUID: pluginDefaults.defaultOutputUID,
      );

      if (!_session.isActive) {
        // Try to use persisted output device, fall back to default
        String? targetOutputUID = _outputDeviceUID;

        // Validate persisted output device is available
        if (targetOutputUID != null && targetOutputUID.isNotEmpty) {
          final deviceAvailable = _devices.any(
            (d) => d.uid == targetOutputUID && d.isOutput,
          );
          if (!deviceAvailable) {
            final deviceName = targetOutputUID;
            _error =
                'Saved output device is not available: $deviceName. '
                'Please select another device.';
            targetOutputUID = null;
          }
        }

        // Fall back to default output device
        if (targetOutputUID == null || targetOutputUID.isEmpty) {
          targetOutputUID = _defaults.defaultOutputUID;
        }

        if (targetOutputUID.isNotEmpty) {
          await startSession(targetOutputUID);
        }
      }
    } catch (e) {
      _error = 'Failed to list devices: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startSession(String outputUID) async {
    if (_isStartingSession || outputUID.isEmpty) return false;

    _isStartingSession = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _plugin.startSession(
        SessionOptions(outputDeviceUID: outputUID, bufferFrames: _bufferFrames),
      );

      _session = AudioSession(
        sessionId: result.sessionId,
        actualSampleRate: result.actualSampleRate,
        bufferFrames: result.bufferFrames,
      );

      // Persist the output device UID
      _outputDeviceUID = outputUID;

      _routes.clear();
      await _restoreRoutes();
      await _saveSessionConfig();
      return true;
    } catch (e) {
      _error = 'Failed to start session: $e';
      return false;
    } finally {
      _isStartingSession = false;
      notifyListeners();
    }
  }

  Future<bool> addRoute(AudioRoute route) async {
    _error = null;

    if (!_session.isActive) {
      final outputUID = route.outDeviceUID.isNotEmpty
          ? route.outDeviceUID
          : _defaults.defaultOutputUID;
      final started = await startSession(outputUID);
      if (!started) return false;
    }

    try {
      await _plugin.addRoute(
        RouteConfig(
          id: route.id,
          inDeviceUID: route.inDeviceUID,
          inL: route.inL,
          inR: route.inR,
          outDeviceUID: route.outDeviceUID,
          outL: route.outL,
          outR: route.outR,
          gain: route.gain,
          enabled: route.enabled,
        ),
      );

      // Cache device names so they persist when devices disconnect
      final routeWithNames = route.copyWith(
        inDeviceName: route.inDeviceName ?? deviceNameForUID(route.inDeviceUID),
        outDeviceName:
            route.outDeviceName ?? deviceNameForUID(route.outDeviceUID),
      );

      _routes.add(routeWithNames);
      await _saveSessionConfig();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add route: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> removeRoute(String routeId) async {
    try {
      await _plugin.removeRoute(routeId);
      _routes.removeWhere((r) => r.id == routeId);
      await _saveSessionConfig();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove route: $e';
      notifyListeners();
    }
  }

  Future<void> setRouteEnabled(String routeId, bool enabled) async {
    final index = _routes.indexWhere((r) => r.id == routeId);
    if (index < 0) return;

    final route = _routes[index];

    try {
      if (enabled) {
        // When enabling a route, we need to re-add it to the audio engine
        // to recreate InputTap and OutputUnit that may have been removed
        // when the device was disconnected
        await _plugin.addRoute(
          RouteConfig(
            id: route.id,
            inDeviceUID: route.inDeviceUID,
            inL: route.inL,
            inR: route.inR,
            outDeviceUID: route.outDeviceUID,
            outL: route.outL,
            outR: route.outR,
            gain: route.gain,
            enabled: true,
          ),
        );
      } else {
        // When disabling, just update the enabled state
        await _plugin.setRouteEnabled(routeId, false);
      }

      // When user manually changes enabled state, clear disabledByDevice flag
      _routes[index] = route.copyWith(
        enabled: enabled,
        disabledByDevice: false,
      );
      await _saveSessionConfig();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setRouteGain(String routeId, double gain) async {
    try {
      await _plugin.setRouteGain(routeId, gain);
      final index = _routes.indexWhere((r) => r.id == routeId);
      if (index >= 0) {
        _routes[index] = _routes[index].copyWith(gain: gain);
        await _saveSessionConfig();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setBufferFrames(int frames) async {
    _bufferFrames = frames;
    await _saveSessionConfig();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  AudioDeviceEntity? deviceForUID(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    for (final device in _devices) {
      if (device.uid == uid) return device;
    }
    return null;
  }

  String deviceNameForUID(String uid) {
    final device = deviceForUID(uid);
    if (device != null && device.name.isNotEmpty) return device.name;
    if (uid.isNotEmpty) return uid;
    return 'Unknown';
  }

  /// Gets the display name for a device in a route.
  /// Uses cached name from the route if device is disconnected.
  String deviceNameForRoute(AudioRoute route, {required bool isInput}) {
    final uid = isInput ? route.inDeviceUID : route.outDeviceUID;
    final cachedName = isInput ? route.inDeviceName : route.outDeviceName;

    // First try to get the name from the connected device
    final device = deviceForUID(uid);
    if (device != null && device.name.isNotEmpty) {
      return device.name;
    }

    // Fall back to cached name if device is disconnected
    if (cachedName != null && cachedName.isNotEmpty) {
      return cachedName;
    }

    // Last resort: return UID or Unknown
    if (uid.isNotEmpty) return uid;
    return 'Unknown';
  }

  Future<void> _restoreRoutes() async {
    if (!_session.isActive) return;

    final config = await SessionConfig.load();
    if (config == null || config.routes.isEmpty) return;

    final restored = <AudioRoute>[];
    for (final route in config.routes) {
      if (route.inDeviceUID.isEmpty || route.outDeviceUID.isEmpty) continue;

      // Validate that devices are available
      final inputAvailable = _devices.any((d) => d.uid == route.inDeviceUID);
      final outputAvailable = _devices.any((d) => d.uid == route.outDeviceUID);

      if (!inputAvailable || !outputAvailable) {
        // Keep routes with unavailable devices disabled and mark as disabledByDevice
        // so they can be auto-restored when the device reconnects
        restored.add(route.copyWith(enabled: false, disabledByDevice: true));
        continue;
      }

      try {
        await _plugin.addRoute(
          RouteConfig(
            id: route.id,
            inDeviceUID: route.inDeviceUID,
            inL: route.inL,
            inR: route.inR,
            outDeviceUID: route.outDeviceUID,
            outL: route.outL,
            outR: route.outR,
            gain: route.gain,
            enabled: route.enabled,
          ),
        );
        // Clear disabledByDevice flag since the route is now active
        restored.add(route.copyWith(disabledByDevice: false));
      } catch (_) {
        // If route fails to add, keep it disabled and mark as disabledByDevice
        restored.add(route.copyWith(enabled: false, disabledByDevice: true));
      }
    }

    if (restored.isNotEmpty) {
      _routes = restored;
    }
  }

  AudioDeviceEntity _mapDevice(AudioDevice d) {
    return AudioDeviceEntity(
      uid: d.uid,
      name: d.name,
      inputChannels: d.inputChannels,
      outputChannels: d.outputChannels,
      sampleRates: d.sampleRates,
      isInput: d.isInput,
      isOutput: d.isOutput,
    );
  }

  @override
  void dispose() {
    _deviceEventSubscription?.cancel();
    super.dispose();
  }
}
