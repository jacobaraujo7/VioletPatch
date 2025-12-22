import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_plugin_platform_interface.dart';

/// An implementation of [AudioPluginPlatform] that uses method channels.
class MethodChannelAudioPlugin extends AudioPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('audio_plugin');

  /// The event channel for device events.
  @visibleForTesting
  final eventChannel = const EventChannel('audio_plugin/device_events');

  Stream<Map<String, Object?>>? _deviceEventsStream;

  @override
  Future<List<Map<String, Object?>>> listDevices() async {
    final devices = await methodChannel.invokeMethod<List<Object?>>(
      'listDevices',
    );
    return devices
            ?.whereType<Map>()
            .map((device) => device.cast<String, Object?>())
            .toList() ??
        <Map<String, Object?>>[];
  }

  @override
  Future<Map<String, Object?>> getDefaultDevices() async {
    final defaults = await methodChannel.invokeMethod<Map>('getDefaultDevices');
    return defaults?.cast<String, Object?>() ?? <String, Object?>{};
  }

  @override
  Future<Map<String, Object?>> startSession(
    Map<String, Object?> options,
  ) async {
    final session = await methodChannel.invokeMethod<Map>(
      'startSession',
      options,
    );
    return session?.cast<String, Object?>() ?? <String, Object?>{};
  }

  @override
  Future<void> stopSession() async {
    await methodChannel.invokeMethod<void>('stopSession');
  }

  @override
  Future<Map<String, Object?>> getStats() async {
    final stats = await methodChannel.invokeMethod<Map>('getStats');
    return stats?.cast<String, Object?>() ?? <String, Object?>{};
  }

  @override
  Future<void> addRoute(Map<String, Object?> route) async {
    await methodChannel.invokeMethod<void>('addRoute', route);
  }

  @override
  Future<void> removeRoute(Map<String, Object?> args) async {
    await methodChannel.invokeMethod<void>('removeRoute', args);
  }

  @override
  Future<void> setRouteEnabled(Map<String, Object?> args) async {
    await methodChannel.invokeMethod<void>('setRouteEnabled', args);
  }

  @override
  Future<void> setRouteGain(Map<String, Object?> args) async {
    await methodChannel.invokeMethod<void>('setRouteGain', args);
  }

  @override
  Stream<Map<String, Object?>> get deviceEvents {
    _deviceEventsStream ??= eventChannel.receiveBroadcastStream().map(
      (event) => (event as Map).cast<String, Object?>(),
    );
    return _deviceEventsStream!;
  }
}
