// lib/app/theme.dart
import 'package:material_ui/material_ui.dart';

/// Bright, high-contrast palette for kid mode.
class AppColors {
  const AppColors._();

  static const Color honey = Color(0xFFFFD23F);
  static const Color honeyDeep = Color(0xFFFFB703);
  static const Color cream = Color(0xFFFFF6D6);
  static const Color ink = Color(0xFF3A2A1A);
  static const Color sky = Color(0xFF4CC9F0);
  static const Color leaf = Color(0xFF52B788);
  static const Color berry = Color(0xFFFF8FA3);
  static const Color grape = Color(0xFF5E60CE);
  static const Color white = Color(0xFFFFFFFF);
}

class AppTheme {
  const AppTheme._();

  static const String uiFont = 'Nunito';
  static const String writingFont = 'Andika';
  static const String emojiFont = 'NotoColorEmoji';

  static ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.honeyDeep,
      brightness: Brightness.light,
    ).copyWith(surface: AppColors.cream, onSurface: AppColors.ink);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: uiFont,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
        bodyLarge: TextStyle(fontSize: 17, color: AppColors.ink),
        bodyMedium: TextStyle(fontSize: 15, color: AppColors.ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}
