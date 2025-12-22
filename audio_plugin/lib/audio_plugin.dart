import 'dart:math';

import 'audio_plugin_platform_interface.dart';

class AudioDevice {
  const AudioDevice({
    required this.uid,
    required this.name,
    required this.inputChannels,
    required this.outputChannels,
    required this.sampleRates,
    required this.isInput,
    required this.isOutput,
  });

  final String uid;
  final String name;
  final int inputChannels;
  final int outputChannels;
  final List<int> sampleRates;
  final bool isInput;
  final bool isOutput;

  factory AudioDevice.fromMap(Map<String, Object?> map) {
    return AudioDevice(
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      inputChannels: (map['inputChannels'] as num?)?.toInt() ?? 0,
      outputChannels: (map['outputChannels'] as num?)?.toInt() ?? 0,
      sampleRates:
          (map['sampleRates'] as List<Object?>?)
              ?.whereType<num>()
              .map((rate) => rate.toInt())
              .toList() ??
          const <int>[],
      isInput: map['isInput'] as bool? ?? false,
      isOutput: map['isOutput'] as bool? ?? false,
    );
  }
}

class DefaultDevices {
  const DefaultDevices({
    required this.defaultInputUID,
    required this.defaultOutputUID,
  });

  final String defaultInputUID;
  final String defaultOutputUID;

  factory DefaultDevices.fromMap(Map<String, Object?> map) {
    return DefaultDevices(
      defaultInputUID: map['defaultInputUID'] as String? ?? '',
      defaultOutputUID: map['defaultOutputUID'] as String? ?? '',
    );
  }
}

class SessionOptions {
  const SessionOptions({
    required this.outputDeviceUID,
    this.sampleRate = 48000,
    this.bufferFrames = 256,
  });

  final String outputDeviceUID;
  final int sampleRate;
  final int bufferFrames;

  Map<String, Object?> toMap() {
    return {
      'outputDeviceUID': outputDeviceUID,
      'sampleRate': sampleRate,
      'bufferFrames': bufferFrames,
    };
  }
}

class SessionInfo {
  const SessionInfo({
    required this.sessionId,
    required this.actualSampleRate,
    required this.bufferFrames,
  });

  final String sessionId;
  final int actualSampleRate;
  final int bufferFrames;

  factory SessionInfo.fromMap(Map<String, Object?> map) {
    return SessionInfo(
      sessionId: map['sessionId'] as String? ?? '',
      actualSampleRate: (map['actualSampleRate'] as num?)?.toInt() ?? 0,
      bufferFrames: (map['bufferFrames'] as num?)?.toInt() ?? 0,
    );
  }
}

class SessionStats {
  const SessionStats({
    required this.underruns,
    required this.overruns,
    required this.routes,
    required this.bufferFill,
  });

  final int underruns;
  final int overruns;
  final int routes;
  final double bufferFill;

  factory SessionStats.fromMap(Map<String, Object?> map) {
    return SessionStats(
      underruns: (map['underruns'] as num?)?.toInt() ?? 0,
      overruns: (map['overruns'] as num?)?.toInt() ?? 0,
      routes: (map['routes'] as num?)?.toInt() ?? 0,
      bufferFill: (map['bufferFill'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RouteConfig {
  RouteConfig({
    String? id,
    required this.inDeviceUID,
    required this.inL,
    required this.inR,
    required this.outDeviceUID,
    required this.outL,
    required this.outR,
    this.gain = 1.0,
    this.enabled = true,
  }) : id = id ?? _generateId();

  final String id;
  final String inDeviceUID;
  final int inL;
  final int inR;
  final String outDeviceUID;
  final int outL;
  final int outR;
  final double gain;
  final bool enabled;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'inDeviceUID': inDeviceUID,
      'inL': inL,
      'inR': inR,
      'outDeviceUID': outDeviceUID,
      'outL': outL,
      'outR': outR,
      'gain': gain,
      'enabled': enabled,
    };
  }

  static String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(1 << 20);
    return '$now-$rand';
  }
}

/// Base class for device events
sealed class DeviceEvent {
  const DeviceEvent({required this.uid, required this.name});

  final String uid;
  final String name;

  factory DeviceEvent.fromMap(Map<String, Object?> map) {
    final type = map['type'] as String?;
    final uid = map['uid'] as String? ?? '';
    final name = map['name'] as String? ?? '';

    return switch (type) {
      'connected' => DeviceConnectedEvent(uid: uid, name: name),
      'disconnected' => DeviceDisconnectedEvent(uid: uid, name: name),
      _ => DeviceDisconnectedEvent(uid: uid, name: name),
    };
  }
}

/// Event fired when a device is connected
class DeviceConnectedEvent extends DeviceEvent {
  const DeviceConnectedEvent({required super.uid, required super.name});
}

/// Event fired when a device is disconnected
class DeviceDisconnectedEvent extends DeviceEvent {
  const DeviceDisconnectedEvent({required super.uid, required super.name});
}

class AudioPlugin {
  Future<List<AudioDevice>> listDevices() async {
    final devices = await AudioPluginPlatform.instance.listDevices();
    return devices.map(AudioDevice.fromMap).toList();
  }

  Future<DefaultDevices> getDefaultDevices() async {
    final defaults = await AudioPluginPlatform.instance.getDefaultDevices();
    return DefaultDevices.fromMap(defaults);
  }

  Future<SessionInfo> startSession(SessionOptions options) async {
    final session = await AudioPluginPlatform.instance.startSession(
      options.toMap(),
    );
    return SessionInfo.fromMap(session);
  }

  Future<void> stopSession() {
    return AudioPluginPlatform.instance.stopSession();
  }

  Future<SessionStats> getStats() async {
    final stats = await AudioPluginPlatform.instance.getStats();
    return SessionStats.fromMap(stats);
  }

  Future<void> addRoute(RouteConfig route) {
    return AudioPluginPlatform.instance.addRoute(route.toMap());
  }

  Future<void> removeRoute(String id) {
    return AudioPluginPlatform.instance.removeRoute({'id': id});
  }

  Future<void> setRouteEnabled(String id, bool enabled) {
    return AudioPluginPlatform.instance.setRouteEnabled({
      'id': id,
      'enabled': enabled,
    });
  }

  Future<void> setRouteGain(String id, double gain) {
    return AudioPluginPlatform.instance.setRouteGain({'id': id, 'gain': gain});
  }

  /// Stream of device events (connected/disconnected)
  Stream<DeviceEvent> get deviceEvents {
    return AudioPluginPlatform.instance.deviceEvents.map(DeviceEvent.fromMap);
  }
}
