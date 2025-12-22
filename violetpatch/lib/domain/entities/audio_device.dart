class AudioDeviceEntity {
  const AudioDeviceEntity({
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

  bool get isEmpty => uid.isEmpty;

  static const AudioDeviceEntity empty = AudioDeviceEntity(
    uid: '',
    name: '',
    inputChannels: 0,
    outputChannels: 0,
    sampleRates: [],
    isInput: false,
    isOutput: false,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioDeviceEntity && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}
