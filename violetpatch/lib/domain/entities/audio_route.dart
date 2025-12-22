class AudioRoute {
  AudioRoute({
    String? id,
    required this.inDeviceUID,
    required this.inL,
    required this.inR,
    required this.outDeviceUID,
    required this.outL,
    required this.outR,
    this.gain = 1.0,
    this.enabled = true,
    this.disabledByDevice = false,
    this.inDeviceName,
    this.outDeviceName,
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

  /// True if the route was disabled due to device disconnection.
  /// Routes disabled by device disconnection can be auto-restored when the device reconnects.
  /// Routes disabled manually by the user should NOT be auto-restored.
  final bool disabledByDevice;

  /// Cached name of the input device (preserved when device disconnects).
  final String? inDeviceName;

  /// Cached name of the output device (preserved when device disconnects).
  final String? outDeviceName;

  static String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = DateTime.now().millisecond;
    return '$now-$rand';
  }

  AudioRoute copyWith({
    String? id,
    String? inDeviceUID,
    int? inL,
    int? inR,
    String? outDeviceUID,
    int? outL,
    int? outR,
    double? gain,
    bool? enabled,
    bool? disabledByDevice,
    String? inDeviceName,
    String? outDeviceName,
  }) {
    return AudioRoute(
      id: id ?? this.id,
      inDeviceUID: inDeviceUID ?? this.inDeviceUID,
      inL: inL ?? this.inL,
      inR: inR ?? this.inR,
      outDeviceUID: outDeviceUID ?? this.outDeviceUID,
      outL: outL ?? this.outL,
      outR: outR ?? this.outR,
      gain: gain ?? this.gain,
      enabled: enabled ?? this.enabled,
      disabledByDevice: disabledByDevice ?? this.disabledByDevice,
      inDeviceName: inDeviceName ?? this.inDeviceName,
      outDeviceName: outDeviceName ?? this.outDeviceName,
    );
  }

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
      'disabledByDevice': disabledByDevice,
      'inDeviceName': inDeviceName,
      'outDeviceName': outDeviceName,
    };
  }

  factory AudioRoute.fromMap(Map<String, Object?> map) {
    return AudioRoute(
      id: map['id'] as String?,
      inDeviceUID: map['inDeviceUID'] as String? ?? '',
      inL: (map['inL'] as num?)?.toInt() ?? 1,
      inR: (map['inR'] as num?)?.toInt() ?? 2,
      outDeviceUID: map['outDeviceUID'] as String? ?? '',
      outL: (map['outL'] as num?)?.toInt() ?? 1,
      outR: (map['outR'] as num?)?.toInt() ?? 2,
      gain: (map['gain'] as num?)?.toDouble() ?? 1.0,
      enabled: map['enabled'] as bool? ?? true,
      disabledByDevice: map['disabledByDevice'] as bool? ?? false,
      inDeviceName: map['inDeviceName'] as String?,
      outDeviceName: map['outDeviceName'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioRoute && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
