import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the ADAZA ThemeData. Minimalist, high-contrast, cream-based (Req 9).
///
/// Three bundled font families, each with a clear role:
///  - [fontBrand]   National Park   -> ADAZA wordmark + headings/titles
///  - [fontBody]    SF Pro          -> body, labels, buttons, general UI
///  - [fontMono]    Monospace       -> prices, totals, barcodes (aligned digits)
abstract final class AppTheme {
  static const String fontBrand = 'National Park';
  static const String fontBrandOutline = 'National Park Outline';
  static const String fontDisplay = 'SF Pro Display';
  static const String fontBody = 'SF Pro';
  static const String fontMono = 'Monospace';

  /// Brand wordmark / heading style (National Park).
  static TextStyle brand({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: fontBrand,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// Numeric / monospaced style for money, totals and barcodes.
  static TextStyle mono({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: fontMono,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      primary: AppColors.teal,
      secondary: AppColors.copper,
      tertiary: AppColors.gold,
      surface: AppColors.card,
      error: AppColors.error,
      brightness: Brightness.light,
    ).copyWith(
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    // Body in SF Pro; display/headline/title in National Park.
    final base = ThemeData.light().textTheme;
    final textTheme = base
        .apply(
          fontFamily: fontBody,
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        )
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(fontFamily: fontBrand),
          displayMedium: base.displayMedium?.copyWith(fontFamily: fontBrand),
          displaySmall: base.displaySmall?.copyWith(fontFamily: fontBrand),
          headlineLarge: base.headlineLarge?.copyWith(fontFamily: fontBrand),
          headlineMedium: base.headlineMedium?.copyWith(fontFamily: fontBrand),
          headlineSmall: base.headlineSmall?.copyWith(fontFamily: fontBrand),
          titleLarge: base.titleLarge?.copyWith(
            fontFamily: fontBrand,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        );

    const radius = 12.0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: AppColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: fontBody,
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      // Flat top bar: cream surface, dark brand title, hairline bottom border.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.creamSurface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: AppColors.border)),
        titleTextStyle: TextStyle(
          fontFamily: fontBrand,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.teal,
          letterSpacing: 1,
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary),
      ),
      // Flat, bordered cards — no drop shadows.
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: fontBody,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderStrong),
          textStyle: const TextStyle(
            fontFamily: fontBody,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.teal),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 1,
        highlightElevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: shape,
      ),
      chipTheme: const ChipThemeData(
        side: BorderSide(color: AppColors.border),
        backgroundColor: AppColors.creamSurface,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.teal : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.teal.withValues(alpha: 0.4)
              : null,
        ),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
