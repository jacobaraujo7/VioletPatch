import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/audio_route.dart';

/// Configuration for a VioletPatch session that can be persisted and restored.
class SessionConfig {
  SessionConfig({
    this.outputDeviceUID,
    this.bufferFrames = 256,
    this.routes = const [],
  });

  /// The UID of the output device for the session.
  final String? outputDeviceUID;

  /// Buffer size in frames (64, 128, 256, or 512).
  final int bufferFrames;

  /// List of route configurations.
  final List<AudioRoute> routes;

  static const String _storageKey = 'violetpatch.session_config';

  /// Creates a copy with updated fields.
  SessionConfig copyWith({
    String? outputDeviceUID,
    bool clearOutputDeviceUID = false,
    int? bufferFrames,
    List<AudioRoute>? routes,
  }) {
    return SessionConfig(
      outputDeviceUID: clearOutputDeviceUID
          ? null
          : (outputDeviceUID ?? this.outputDeviceUID),
      bufferFrames: bufferFrames ?? this.bufferFrames,
      routes: routes ?? this.routes,
    );
  }

  /// Serializes the config to JSON.
  Map<String, Object?> toJson() {
    return {
      'outputDeviceUID': outputDeviceUID,
      'bufferFrames': bufferFrames,
      'routes': routes.map((r) => r.toMap()).toList(),
    };
  }

  /// Deserializes the config from JSON.
  factory SessionConfig.fromJson(Map<String, Object?> json) {
    final routesList = json['routes'];
    final routes = <AudioRoute>[];

    if (routesList is List) {
      for (final entry in routesList) {
        if (entry is Map) {
          routes.add(AudioRoute.fromMap(entry.cast<String, Object?>()));
        }
      }
    }

    return SessionConfig(
      outputDeviceUID: json['outputDeviceUID'] as String?,
      bufferFrames: (json['bufferFrames'] as num?)?.toInt() ?? 256,
      routes: routes,
    );
  }

  /// Saves the config to SharedPreferences.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(toJson());
    await prefs.setString(_storageKey, payload);
  }

  /// Loads the config from SharedPreferences.
  /// Returns null if no config is saved.
  static Future<SessionConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      return SessionConfig.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SessionConfig) return false;

    if (outputDeviceUID != other.outputDeviceUID) return false;
    if (bufferFrames != other.bufferFrames) return false;
    if (routes.length != other.routes.length) return false;

    for (var i = 0; i < routes.length; i++) {
      if (routes[i].id != other.routes[i].id) return false;
      if (routes[i].inDeviceUID != other.routes[i].inDeviceUID) return false;
      if (routes[i].outDeviceUID != other.routes[i].outDeviceUID) return false;
      if (routes[i].inL != other.routes[i].inL) return false;
      if (routes[i].inR != other.routes[i].inR) return false;
      if (routes[i].outL != other.routes[i].outL) return false;
      if (routes[i].outR != other.routes[i].outR) return false;
      if (routes[i].gain != other.routes[i].gain) return false;
      if (routes[i].enabled != other.routes[i].enabled) return false;
    }

    return true;
  }

  @override
  int get hashCode => Object.hash(outputDeviceUID, bufferFrames, routes.length);
}
