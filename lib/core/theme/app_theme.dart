import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color heroCardBg = Color(0xFF0F2309);
  static const Color brandGreen = Color(0xFF4A7C2F);
  static const Color limeAccent = Color(0xFFBEFF35);

  // Dark surfaces
  static const Color darkBg = Color(0xFF0D0D0D);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color darkCardHigh = Color(0xFF242424);
  static const Color darkOutline = Color(0xFF2E2E2E);

  // Light surfaces — all green-tinted (same palette as leaderboard top-3)
  static const Color lightBg = Color(0xFFF3F7F1);
  static const Color lightCard = Color(0xFFEAF0E8);
  static const Color lightCardHigh = Color(0xFFE1E9DF);
  static const Color lightOutline = Color(0xFFCDD8CB);

  // Gradient stops — same green-tinted palette
  static const Color lightGradientTop = Color(0xFFF3F7F1);
  static const Color lightGradientBottom = Color(0xFFE6EEE4);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(_lightScheme);
  static ThemeData get dark => _build(_darkScheme);

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF3D6820),
    onPrimary: Colors.white,
    primaryContainer: AppColors.heroCardBg,
    onPrimaryContainer: Colors.white,
    secondary: Color(0xFF4A7C2F),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD4EDB8),
    onSecondaryContainer: Color(0xFF0F2B06),
    tertiary: Color(0xFF5A8A3A),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFCCE8B0),
    onTertiaryContainer: Color(0xFF0F2B06),
    error: Color(0xFFB3261E),
    onError: Colors.white,
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: AppColors.lightBg,
    onSurface: Color(0xFF1A2418),
    surfaceContainerHighest: AppColors.lightCardHigh,
    surfaceContainerHigh: AppColors.lightCard,
    surfaceContainer: Color(0xFFEDF4EB),
    surfaceContainerLow: AppColors.lightCard,
    outline: AppColors.lightOutline,
    outlineVariant: Color(0xFFCDD8CB),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF1A1A1A),
    onInverseSurface: Color(0xFFF3F7F1),
    inversePrimary: Color(0xFF88C96A),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF6AB84A),
    onPrimary: Color(0xFF0F2B06),
    primaryContainer: AppColors.heroCardBg,
    onPrimaryContainer: Colors.white,
    secondary: Color(0xFF78C458),
    onSecondary: Color(0xFF0F2B06),
    secondaryContainer: Color(0xFF1E4A10),
    onSecondaryContainer: Color(0xFFB8EDAC),
    tertiary: Color(0xFF80CC60),
    onTertiary: Color(0xFF0F2B06),
    tertiaryContainer: Color(0xFF244A14),
    onTertiaryContainer: Color(0xFFC0EBA8),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: AppColors.darkBg,
    onSurface: Color(0xFFEEEEEE),
    surfaceContainerHighest: AppColors.darkCardHigh,
    surfaceContainerHigh: Color(0xFF222222),
    surfaceContainer: Color(0xFF1E1E1E),
    surfaceContainerLow: AppColors.darkCard,
    outline: AppColors.darkOutline,
    outlineVariant: Color(0xFF252525),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFEEEEEE),
    onInverseSurface: Color(0xFF0D0D0D),
    inversePrimary: Color(0xFF3D6820),
  );

  static ThemeData _build(ColorScheme cs) {
    final base = GoogleFonts.dmSansTextTheme().apply(
      bodyColor: cs.onSurface,
      displayColor: cs.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: base,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: cs.outline),
          foregroundColor: cs.onSurface,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.35)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: cs.surfaceContainerLow,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: cs.surface,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
