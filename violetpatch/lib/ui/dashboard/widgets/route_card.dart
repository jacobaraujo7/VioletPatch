import 'package:flutter/material.dart';

import '../../../domain/entities/audio_route.dart';
import '../../core/theme/app_colors.dart';

class RouteCard extends StatefulWidget {
  const RouteCard({
    super.key,
    required this.route,
    required this.inputName,
    required this.outputName,
    required this.onRemove,
    required this.onGainChanged,
    required this.onEnabledChanged,
    this.inputAvailable = true,
    this.outputAvailable = true,
  });

  final AudioRoute route;
  final String inputName;
  final String outputName;
  final VoidCallback onRemove;
  final ValueChanged<double> onGainChanged;
  final ValueChanged<bool> onEnabledChanged;
  final bool inputAvailable;
  final bool outputAvailable;

  bool get devicesAvailable => inputAvailable && outputAvailable;

  @override
  State<RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<RouteCard> {
  late double _gain;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _gain = widget.route.gain;
    _enabled = widget.route.enabled;
  }

  @override
  void didUpdateWidget(RouteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.gain != widget.route.gain) {
      _gain = widget.route.gain;
    }
    if (oldWidget.route.enabled != widget.route.enabled) {
      _enabled = widget.route.enabled;
    }
  }

  String _getDisabledTooltip() {
    if (!widget.inputAvailable && !widget.outputAvailable) {
      return 'Input and output devices disconnected';
    } else if (!widget.inputAvailable) {
      return 'Input device disconnected: ${widget.inputName}';
    } else if (!widget.outputAvailable) {
      return 'Output device disconnected: ${widget.outputName}';
    }
    return '';
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Text(
          'Remove Route',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Remove route "${widget.inputName} → ${widget.outputName}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onRemove();
    }
  }

  Widget _buildDeviceName(String name, bool isAvailable, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: isAvailable ? AppColors.textMuted : AppColors.error,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            style: TextStyle(
              color: isAvailable ? AppColors.textPrimary : AppColors.error,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              decoration: isAvailable ? null : TextDecoration.lineThrough,
              decorationColor: AppColors.error,
              decorationThickness: 2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!isAvailable) ...[
          const SizedBox(width: 4),
          const Icon(Icons.link_off, size: 14, color: AppColors.error),
        ],
      ],
    );
  }

  Widget _buildChannelMapping() {
    final inL = widget.route.inL;
    final inR = widget.route.inR;
    final outL = widget.route.outL;
    final outR = widget.route.outR;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Input channels
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildChannelChip('IN $inL', AppColors.accentPurple),
              const SizedBox(height: 4),
              _buildChannelChip('IN $inR', AppColors.accentBlue),
            ],
          ),
          // Arrows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: AppColors.accentPurple.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: AppColors.accentBlue.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
          // Output channels
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChannelChip('OUT $outL', AppColors.accentPurple),
              const SizedBox(height: 4),
              _buildChannelChip('OUT $outR', AppColors.accentBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = !_enabled;
    final canToggle = widget.devicesAvailable;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDisabled ? 0.7 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDisabled
                ? AppColors.routeCardGradientDisabled
                : AppColors.routeCardGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDisabled
                ? AppColors.cardBorderDisabled
                : AppColors.routeCardBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with devices, switch and remove button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDeviceName(
                        widget.inputName,
                        widget.inputAvailable,
                        Icons.mic,
                      ),
                      const SizedBox(height: 4),
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.arrow_downward,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildDeviceName(
                        widget.outputName,
                        widget.outputAvailable,
                        Icons.speaker,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: canToggle
                          ? (_enabled ? 'Disable route' : 'Enable route')
                          : _getDisabledTooltip(),
                      child: Switch(
                        value: _enabled,
                        onChanged: canToggle
                            ? (value) {
                                setState(() => _enabled = value);
                                widget.onEnabledChanged(value);
                              }
                            : null,
                        activeThumbColor: AppColors.switchActiveThumb,
                        inactiveThumbColor: canToggle
                            ? AppColors.switchInactiveThumb
                            : AppColors.error.withValues(alpha: 0.5),
                        inactiveTrackColor: canToggle
                            ? AppColors.switchInactiveTrack
                            : AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    IconButton(
                      onPressed: _showDeleteConfirmation,
                      tooltip: 'Remove route',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Channel mapping
            _buildChannelMapping(),

            const SizedBox(height: 16),

            // Gain slider
            Row(
              children: [
                Icon(
                  _gain > 0 ? Icons.volume_up : Icons.volume_off,
                  size: 20,
                  color: isDisabled
                      ? AppColors.textMuted
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.sliderActive,
                      inactiveTrackColor: AppColors.sliderInactive,
                      thumbColor: AppColors.sliderThumb,
                      overlayColor: AppColors.sliderActive.withValues(
                        alpha: 0.2,
                      ),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _gain,
                      min: 0.0,
                      max: 2.0,
                      onChanged: isDisabled
                          ? null
                          : (value) => setState(() => _gain = value),
                      onChangeEnd: isDisabled ? null : widget.onGainChanged,
                    ),
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
