// lib/app/theme.dart
import 'package:material_ui/material_ui.dart';

/// The Ong Bi palette: honey gold on warm white, with soft pastel tints for
/// tiles. Cards float on soft shadows instead of thick outlines.
class AppColors {
  const AppColors._();

  /// Brand honey: buttons, highlights, the child's own bubbles.
  static const Color honey = Color(0xFFFFC52E);

  /// Deeper honey: gradient ends and pressed states.
  static const Color honeyDeep = Color(0xFFFFA90A);

  /// Pale honey tint for tiles and selected cards.
  static const Color honeySoft = Color(0xFFFFF2C9);

  /// App background (warm white).
  static const Color cream = Color(0xFFFFFAF0);

  /// Text.
  static const Color ink = Color(0xFF2F2418);

  /// Secondary text (Vietnamese meanings, captions).
  static const Color inkSoft = Color(0xFF7A6A55);

  /// Hairlines and quiet outlines.
  static const Color line = Color(0xFFF0E5CF);

  static const Color sky = Color(0xFF38BDF8);
  static const Color skySoft = Color(0xFFE2F4FD);
  static const Color leaf = Color(0xFF34C17B);
  static const Color leafSoft = Color(0xFFE1F6EA);
  static const Color berry = Color(0xFFFF7A93);
  static const Color berrySoft = Color(0xFFFFE8ED);

  /// Accent for the word highlight and parent charts.
  static const Color grape = Color(0xFF7C5CFF);
  static const Color grapeSoft = Color(0xFFEEE9FF);
  static const Color white = Color(0xFFFFFFFF);
}

/// Soft, warm shadows (tinted with the ink colour, never pure black).
class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x162F2418), blurRadius: 22, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A2F2418), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x102F2418), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Upward shadow of a bottom sheet or panel.
  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x142F2418), blurRadius: 20, offset: Offset(0, -6)),
  ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(color: color.withValues(alpha: 0.38), blurRadius: 20, offset: const Offset(0, 8)),
      ];
}

class AppGradients {
  const AppGradients._();

  static const LinearGradient honey = LinearGradient(
    colors: [Color(0xFFFFD95E), Color(0xFFFFAD12)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunrise = LinearGradient(
    colors: [Color(0xFFFFF4D2), Color(0xFFFFE0B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
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
    ).copyWith(
      primary: AppColors.honeyDeep,
      onPrimary: AppColors.ink,
      surface: AppColors.cream,
      onSurface: AppColors.ink,
      secondary: AppColors.grape,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: uiFont,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: uiFont,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: AppColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shadowColor: const Color(0x162F2418),
        surfaceTintColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink),
        titleLarge: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink),
        titleMedium: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        bodyLarge: TextStyle(fontSize: 17, color: AppColors.ink),
        bodyMedium: TextStyle(fontSize: 15, color: AppColors.ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.honey,
          foregroundColor: AppColors.ink,
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.honeySoft,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
      ),
    );
  }
}
