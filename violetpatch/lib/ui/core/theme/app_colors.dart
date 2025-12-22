import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary
  static const Color primary = Color(0xFF8B5CF6);
  static const Color secondary = Color(0xFFA855F7);
  static const Color surface = Color(0xFF1C1325);
  static const Color error = Color(0xFFEF4444);

  // Background gradients
  static const List<Color> backgroundGradient = [
    Color(0xFF0D0814),
    Color(0xFF160E22),
    Color(0xFF24142F),
  ];

  // Cards
  static const Color cardBackground = Color(0xFF1B1226);
  static const Color cardBorder = Color(0xFF352546);
  static const Color cardBorderDisabled = Color(0xFF2A1A38);

  // Input
  static const Color inputFill = Color(0xFF24162F);
  static const Color inputBorder = Color(0xFF3E2A52);

  // Dropdown
  static const Color dropdownBackground = Color(0xFF2A1837);

  // Text
  static const Color textPrimary = Color(0xFFE6D9FF);
  static const Color textSecondary = Color(0xFFB9A8D2);
  static const Color textMuted = Color(0xFFBFA8D9);

  // Route card
  static const List<Color> routeCardGradient = [
    Color(0xFF24122F),
    Color(0xFF1B1026),
  ];
  static const List<Color> routeCardGradientDisabled = [
    Color(0xFF1A0F22),
    Color(0xFF150D1A),
  ];
  static const Color routeCardBorder = Color(0xFF3C2650);

  // Slider
  static const Color sliderActive = Color(0xFF8B5CF6);
  static const Color sliderInactive = Color(0xFF3E2A52);
  static const Color sliderThumb = Color(0xFFE9D7FF);

  // Switch
  static const Color switchActiveThumb = Color(0xFF8B5CF6);
  static const Color switchInactiveThumb = Color(0xFF6B5B7A);
  static const Color switchInactiveTrack = Color(0xFF3E2A52);

  // Empty state
  static const Color emptyStateBackground = Color(0xFF1A0F24);
  static const Color emptyStateBorder = Color(0xFF332141);

  // Accent colors for channel badges
  static const Color accentPurple = Color(0xFFA855F7);
  static const Color accentBlue = Color(0xFF60A5FA);
}
