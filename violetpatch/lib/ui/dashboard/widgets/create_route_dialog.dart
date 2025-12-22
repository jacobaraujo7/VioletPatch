import 'package:flutter/material.dart';

import '../../../domain/entities/audio_device.dart';
import '../../core/theme/app_colors.dart';
import 'channel_dropdown.dart';
import 'device_dropdown.dart';

class CreateRouteDialog extends StatefulWidget {
  const CreateRouteDialog({
    super.key,
    required this.devices,
    required this.initialInputUID,
    required this.initialOutputUID,
    required this.onRouteCreated,
  });

  final List<AudioDeviceEntity> devices;
  final String? initialInputUID;
  final String? initialOutputUID;
  final Future<bool> Function(
    String inputUID,
    String outputUID,
    int inL,
    int inR,
    int outL,
    int outR,
  )
  onRouteCreated;

  @override
  State<CreateRouteDialog> createState() => _CreateRouteDialogState();
}

class _CreateRouteDialogState extends State<CreateRouteDialog> {
  late String? _inputUID;
  late String? _outputUID;
  int? _inL;
  int? _inR;
  int? _outL;
  int? _outR;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _inputUID = widget.initialInputUID;
    _outputUID = widget.initialOutputUID;
    _syncChannels();
  }

  AudioDeviceEntity? _deviceForUID(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    for (final device in widget.devices) {
      if (device.uid == uid) return device;
    }
    return null;
  }

  void _syncChannels() {
    final inputDevice = _deviceForUID(_inputUID);
    final outputDevice = _deviceForUID(_outputUID);
    final inputCount = inputDevice?.inputChannels ?? 0;
    final outputCount = outputDevice?.outputChannels ?? 0;

    _inL = _pickChannelValue(_inL, inputCount, 1);
    _inR = _pickChannelValue(_inR, inputCount, 2);
    _outL = _pickChannelValue(_outL, outputCount, 1);
    _outR = _pickChannelValue(_outR, outputCount, 2);
  }

  int? _pickChannelValue(int? current, int maxChannels, int fallback) {
    if (maxChannels <= 0) return null;
    if (current != null && current >= 1 && current <= maxChannels) {
      return current;
    }
    if (fallback <= maxChannels) return fallback;
    return 1;
  }

  List<int> _channelOptions(int count) {
    if (count <= 0) return const [];
    return List.generate(count, (index) => index + 1);
  }

  bool get _canCreate {
    return _inputUID != null &&
        _inputUID!.isNotEmpty &&
        _outputUID != null &&
        _outputUID!.isNotEmpty &&
        _inL != null &&
        _inR != null &&
        _outL != null &&
        _outR != null;
  }

  Future<void> _create() async {
    if (!_canCreate || _isCreating) return;
    setState(() => _isCreating = true);
    try {
      final success = await widget.onRouteCreated(
        _inputUID!,
        _outputUID!,
        _inL!,
        _inR!,
        _outL!,
        _outR!,
      );
      if (success && mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputDevice = _deviceForUID(_inputUID);
    final outputDevice = _deviceForUID(_outputUID);
    final inputChannels = inputDevice?.inputChannels ?? 0;
    final outputChannels = outputDevice?.outputChannels ?? 0;
    final inputOptions = _channelOptions(inputChannels);
    final outputOptions = _channelOptions(outputChannels);

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.cardBackground, Color(0xFF24142F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  'Create Route',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            DeviceDropdown(
              label: 'Input',
              value: _inputUID,
              devices: widget.devices.where((d) => d.isInput).toList(),
              onChanged: (value) {
                setState(() {
                  _inputUID = value;
                  _syncChannels();
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ChannelDropdown(
                    label: 'In L',
                    value: _inL,
                    options: inputOptions,
                    onChanged: (value) => setState(() => _inL = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChannelDropdown(
                    label: 'In R',
                    value: _inR,
                    options: inputOptions,
                    onChanged: (value) => setState(() => _inR = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            DeviceDropdown(
              label: 'Output',
              value: _outputUID,
              devices: widget.devices.where((d) => d.isOutput).toList(),
              onChanged: (value) {
                setState(() {
                  _outputUID = value;
                  _syncChannels();
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ChannelDropdown(
                    label: 'Out L',
                    value: _outL,
                    options: outputOptions,
                    onChanged: (value) => setState(() => _outL = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChannelDropdown(
                    label: 'Out R',
                    value: _outR,
                    options: outputOptions,
                    onChanged: (value) => setState(() => _outR = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _canCreate && !_isCreating ? _create : null,
                  icon: _isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('Create Route'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
