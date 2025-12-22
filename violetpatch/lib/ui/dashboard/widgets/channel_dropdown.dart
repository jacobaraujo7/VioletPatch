import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class ChannelDropdown extends StatelessWidget {
  const ChannelDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final List<int> options;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasOptions = options.isNotEmpty;
    return SizedBox(
      width: 110,
      child: DropdownButtonFormField<int>(
        value: hasOptions ? value : null,
        items: options
            .map(
              (channel) => DropdownMenuItem(
                value: channel,
                child: Text(channel.toString()),
              ),
            )
            .toList(),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          hintText: hasOptions ? null : 'N/A',
        ),
        dropdownColor: AppColors.dropdownBackground,
        style: Theme.of(context).textTheme.bodyMedium,
        onChanged: hasOptions ? onChanged : null,
      ),
    );
  }
}
