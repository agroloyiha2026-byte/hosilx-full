import 'package:flutter/material.dart';

class AppColors {
  static const forest = Color(0xFF245C36);
  static const green = Color(0xFF3F7D3A);
  static const pale = Color(0xFFE7F0DF);
  static const cream = Color(0xFFF7F5ED);
  static const earth = Color(0xFF8B6848);
  static const text = Color(0xFF26332A);
  // Dark mode
  static const darkBg = Color(0xFF0F1711);
  static const darkCard = Color(0xFF18231B);
  static const darkGreen = Color(0xFF5FA85A);
  static const darkText = Color(0xFFE8F0E8);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.green, brightness: Brightness.light).copyWith(
      primary: AppColors.green, onPrimary: Colors.white, secondary: AppColors.earth,
      surface: Colors.white, onSurface: AppColors.text, primaryContainer: AppColors.pale,
      onPrimaryContainer: AppColors.forest);
    return _base(scheme, AppColors.cream);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.green, brightness: Brightness.dark).copyWith(
      primary: AppColors.darkGreen, onPrimary: const Color(0xFF0C170E), secondary: const Color(0xFFC9A27E),
      surface: AppColors.darkCard, onSurface: AppColors.darkText,
      primaryContainer: const Color(0xFF203024), onPrimaryContainer: AppColors.darkText);
    return _base(scheme, AppColors.darkBg);
  }

  static ThemeData _base(ColorScheme s, Color bg) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return ThemeData(
      useMaterial3: true,
      colorScheme: s,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: bg, foregroundColor: s.onSurface, elevation: 0, scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(color: s.onSurface, fontSize: 20, fontWeight: FontWeight.w800),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 50), shape: shape,
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 50), shape: shape,
            side: BorderSide(color: s.primary, width: 1.5),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      textTheme: ThemeData(brightness: s.brightness).textTheme.apply(bodyColor: s.onSurface, displayColor: s.onSurface),
    );
  }
}
