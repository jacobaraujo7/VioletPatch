import 'package:audio_plugin/audio_plugin.dart';

import '../../../domain/entities/entities.dart';

class DashboardState {
  const DashboardState({
    this.devices = const [],
    this.defaults = AudioDefaultDevices.empty,
    this.routes = const [],
    this.isLoading = false,
    this.statusMessage,
    this.lastDeviceEvent,
  });

  final List<AudioDeviceEntity> devices;
  final AudioDefaultDevices defaults;
  final List<AudioRoute> routes;
  final bool isLoading;
  final String? statusMessage;
  final DeviceEvent? lastDeviceEvent;

  List<AudioDeviceEntity> get inputDevices =>
      devices.where((d) => d.isInput).toList();

  List<AudioDeviceEntity> get outputDevices =>
      devices.where((d) => d.isOutput).toList();

  DashboardState copyWith({
    List<AudioDeviceEntity>? devices,
    AudioDefaultDevices? defaults,
    List<AudioRoute>? routes,
    bool? isLoading,
    String? statusMessage,
    bool clearStatusMessage = false,
    DeviceEvent? lastDeviceEvent,
    bool clearLastDeviceEvent = false,
  }) {
    return DashboardState(
      devices: devices ?? this.devices,
      defaults: defaults ?? this.defaults,
      routes: routes ?? this.routes,
      isLoading: isLoading ?? this.isLoading,
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
      lastDeviceEvent: clearLastDeviceEvent
          ? null
          : (lastDeviceEvent ?? this.lastDeviceEvent),
    );
  }
}
