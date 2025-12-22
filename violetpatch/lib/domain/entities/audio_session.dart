class AudioSession {
  const AudioSession({
    required this.sessionId,
    required this.actualSampleRate,
    required this.bufferFrames,
  });

  final String sessionId;
  final int actualSampleRate;
  final int bufferFrames;

  static const AudioSession empty = AudioSession(
    sessionId: '',
    actualSampleRate: 0,
    bufferFrames: 0,
  );

  bool get isActive => sessionId.isNotEmpty;
}

class AudioDefaultDevices {
  const AudioDefaultDevices({
    required this.defaultInputUID,
    required this.defaultOutputUID,
  });

  final String defaultInputUID;
  final String defaultOutputUID;

  static const AudioDefaultDevices empty = AudioDefaultDevices(
    defaultInputUID: '',
    defaultOutputUID: '',
  );
}
