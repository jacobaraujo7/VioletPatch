import 'package:flutter/foundation.dart';

import '../../../data/services/audio_service.dart';
import '../../../domain/entities/entities.dart';
import '../states/dashboard_state.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel(this._audioService) {
    _audioService.addListener(_onServiceChanged);
    _syncFromService();
  }

  final AudioService _audioService;
  DashboardState _state = const DashboardState();

  DashboardState get state => _state;

  void _onServiceChanged() {
    _syncFromService();
  }

  void _syncFromService() {
    _state = DashboardState(
      devices: _audioService.devices,
      defaults: _audioService.defaults,
      routes: _audioService.routes,
      isLoading: _audioService.isLoading,
      statusMessage: _audioService.error,
      lastDeviceEvent: _audioService.lastDeviceEvent,
    );
    notifyListeners();
  }

  Future<void> loadDevices() async {
    await _audioService.loadDevices();
  }

  Future<bool> addRoute({
    required String inputUID,
    required String outputUID,
    required int inL,
    required int inR,
    required int outL,
    required int outR,
  }) async {
    final route = AudioRoute(
      inDeviceUID: inputUID,
      inL: inL,
      inR: inR,
      outDeviceUID: outputUID,
      outL: outL,
      outR: outR,
    );

    final success = await _audioService.addRoute(route);
    if (success) {
      _updateStatus('Route added.');
    }
    return success;
  }

  Future<void> removeRoute(String routeId) async {
    await _audioService.removeRoute(routeId);
  }

  Future<void> setRouteEnabled(String routeId, bool enabled) async {
    await _audioService.setRouteEnabled(routeId, enabled);
  }

  Future<void> setRouteGain(String routeId, double gain) async {
    await _audioService.setRouteGain(routeId, gain);
  }

  AudioDeviceEntity? deviceForUID(String? uid) {
    return _audioService.deviceForUID(uid);
  }

  String deviceNameForUID(String uid) {
    return _audioService.deviceNameForUID(uid);
  }

  /// Gets the display name for a device in a route.
  /// Uses cached name from the route if device is disconnected.
  String deviceNameForRoute(AudioRoute route, {required bool isInput}) {
    return _audioService.deviceNameForRoute(route, isInput: isInput);
  }

  void clearStatus() {
    _audioService.clearError();
    _state = _state.copyWith(clearStatusMessage: true);
    notifyListeners();
  }

  void _updateStatus(String message) {
    _state = _state.copyWith(statusMessage: message);
    notifyListeners();
  }

  /// Clears the last device event after it has been handled by the UI
  void clearLastDeviceEvent() {
    _audioService.clearLastDeviceEvent();
    _state = _state.copyWith(clearLastDeviceEvent: true);
    notifyListeners();
  }

  /// Attempts to restore routes that were disabled due to device disconnection
  Future<void> restoreRoutesForDevice(String deviceUID) async {
    await _audioService.restoreRoutesForDevice(deviceUID);
  }

  /// Gets routes that are disabled due to a specific device being disconnected
  List<AudioRoute> getDisabledRoutesForDevice(String deviceUID) {
    return _audioService.getDisabledRoutesForDevice(deviceUID);
  }

  @override
  void dispose() {
    _audioService.removeListener(_onServiceChanged);
    super.dispose();
  }
}
