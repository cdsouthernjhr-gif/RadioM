import 'package:flutter/material.dart';

/// Dark navy + turquoise palette.
class AppColors {
  AppColors._();
  static const navy = Color(0xFF0B1F3A);
  static const navyDeep = Color(0xFF06142A);
  static const navySurface = Color(0xFF12294A);
  static const turquoise = Color(0xFF1ED6C3);
  static const turquoiseDark = Color(0xFF0E9E90);
  static const error = Color(0xFFE5484D);
  static const warning = Color(0xFFF5A524);
  static const success = Color(0xFF30C48D);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.turquoiseDark,
      brightness: Brightness.light,
    );
    return _base(scheme).copyWith(scaffoldBackgroundColor: const Color(0xFFF3F6FA));
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.turquoise,
      onPrimary: AppColors.navyDeep,
      secondary: AppColors.turquoise,
      surface: AppColors.navySurface,
      error: AppColors.error,
    );
    return _base(scheme).copyWith(scaffoldBackgroundColor: AppColors.navyDeep);
  }

  static ThemeData _base(ColorScheme scheme) {
    final focusColor = scheme.brightness == Brightness.dark
        ? AppColors.turquoise.withOpacity(0.35)
        : AppColors.turquoiseDark.withOpacity(0.30);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      focusColor: focusColor,
      visualDensity: VisualDensity.standard,
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.brightness == Brightness.dark ? AppColors.navyDeep : AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.secondary,
        thumbColor: scheme.secondary,
      ),
    );
  }
}
