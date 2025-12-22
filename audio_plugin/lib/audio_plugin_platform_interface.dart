import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'audio_plugin_method_channel.dart';

abstract class AudioPluginPlatform extends PlatformInterface {
  /// Constructs a AudioPluginPlatform.
  AudioPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static AudioPluginPlatform _instance = MethodChannelAudioPlugin();

  /// The default instance of [AudioPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelAudioPlugin].
  static AudioPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AudioPluginPlatform] when
  /// they register themselves.
  static set instance(AudioPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<List<Map<String, Object?>>> listDevices() {
    throw UnimplementedError('listDevices() has not been implemented.');
  }

  Future<Map<String, Object?>> getDefaultDevices() {
    throw UnimplementedError('getDefaultDevices() has not been implemented.');
  }

  Future<Map<String, Object?>> startSession(Map<String, Object?> options) {
    throw UnimplementedError('startSession() has not been implemented.');
  }

  Future<void> stopSession() {
    throw UnimplementedError('stopSession() has not been implemented.');
  }

  Future<Map<String, Object?>> getStats() {
    throw UnimplementedError('getStats() has not been implemented.');
  }

  Future<void> addRoute(Map<String, Object?> route) {
    throw UnimplementedError('addRoute() has not been implemented.');
  }

  Future<void> removeRoute(Map<String, Object?> args) {
    throw UnimplementedError('removeRoute() has not been implemented.');
  }

  Future<void> setRouteEnabled(Map<String, Object?> args) {
    throw UnimplementedError('setRouteEnabled() has not been implemented.');
  }

  Future<void> setRouteGain(Map<String, Object?> args) {
    throw UnimplementedError('setRouteGain() has not been implemented.');
  }

  /// Stream of device events (connected/disconnected)
  Stream<Map<String, Object?>> get deviceEvents {
    throw UnimplementedError('deviceEvents has not been implemented.');
  }
}
