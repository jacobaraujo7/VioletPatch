import 'package:flutter/material.dart';

import '../../../domain/entities/audio_device.dart';
import '../../core/theme/app_colors.dart';

class DeviceDropdown extends StatelessWidget {
  const DeviceDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.devices,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<AudioDeviceEntity> devices;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value != null && value!.isNotEmpty ? value : null,
          items: devices
              .map(
                (device) => DropdownMenuItem(
                  value: device.uid,
                  child: Text(device.name),
                ),
              )
              .toList(),
          decoration: const InputDecoration(isDense: true),
          dropdownColor: AppColors.dropdownBackground,
          style: Theme.of(context).textTheme.bodyMedium,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
