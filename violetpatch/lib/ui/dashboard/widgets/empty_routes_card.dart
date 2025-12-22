import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class EmptyRoutesCard extends StatelessWidget {
  const EmptyRoutesCard({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.emptyStateBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.emptyStateBorder),
        ),
        child: Text(
          'No active routes. Create a route to get started.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
