import 'package:flutter/material.dart';

class AppPalette {
  AppPalette._();

  // Core palette (shared)
  static const Color red = Color(0xFFEA4335);
  static const Color slate = Color(0xFF2C3E50);
  static const Color amber = Color(0xFFF39C12);
  static const Color grey = Color(0xFF95A5A6);

  // Mode-specific palette
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightText = Color(0xFF34495E);

  static const Color darkBackground = Color(0xFF1A2530);
  static const Color darkText = Color(0xFFECF0F1);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppPalette.slate,
      onPrimary: AppPalette.darkText,
      primaryContainer: AppPalette.slate,
      onPrimaryContainer: AppPalette.darkText,
      secondary: AppPalette.amber,
      onSecondary: AppPalette.slate,
      secondaryContainer: AppPalette.amber,
      onSecondaryContainer: AppPalette.slate,
      tertiary: AppPalette.red,
      onTertiary: AppPalette.darkText,
      tertiaryContainer: AppPalette.red,
      onTertiaryContainer: AppPalette.darkText,
      error: AppPalette.red,
      onError: AppPalette.darkText,
      errorContainer: AppPalette.red,
      onErrorContainer: AppPalette.darkText,
      surface: AppPalette.lightBackground,
      onSurface: AppPalette.lightText,
      surfaceContainerHighest: AppPalette.lightBackground,
      surfaceTint: AppPalette.slate,
      onSurfaceVariant: AppPalette.lightText,
      outline: AppPalette.grey,
      outlineVariant: AppPalette.grey,
      shadow: AppPalette.slate,
      scrim: AppPalette.slate,
      inverseSurface: AppPalette.slate,
      onInverseSurface: AppPalette.darkText,
      inversePrimary: AppPalette.red,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: scheme,
      primaryColor: AppPalette.slate,
      scaffoldBackgroundColor: AppPalette.lightBackground,
      canvasColor: AppPalette.lightBackground,
      dividerColor: AppPalette.grey.withValues(alpha: 0.35),
      disabledColor: AppPalette.grey.withValues(alpha: 0.55),
      splashColor: AppPalette.grey.withValues(alpha: 0.12),
      highlightColor: AppPalette.grey.withValues(alpha: 0.10),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.lightBackground,
        foregroundColor: AppPalette.slate,
        surfaceTintColor: AppPalette.lightBackground,
        elevation: 0,
        centerTitle: false,
      ),
      iconTheme: const IconThemeData(color: AppPalette.slate),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppPalette.lightBackground,
        surfaceTintColor: AppPalette.lightBackground,
      ),
      cardTheme: const CardThemeData(
        color: AppPalette.lightBackground,
        surfaceTintColor: AppPalette.lightBackground,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.slate,
        contentTextStyle: const TextStyle(
          color: AppPalette.darkText,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: AppPalette.amber,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.lightBackground,
        hintStyle: TextStyle(
          color: AppPalette.grey.withValues(alpha: 0.85),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: const TextStyle(
          color: AppPalette.lightText,
          fontWeight: FontWeight.w600,
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppPalette.grey.withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppPalette.red, width: 2),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppPalette.red),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppPalette.red, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.red,
          foregroundColor: AppPalette.darkText,
          disabledBackgroundColor: AppPalette.grey.withValues(alpha: 0.35),
          disabledForegroundColor: AppPalette.darkText.withValues(alpha: 0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.red,
          foregroundColor: AppPalette.darkText,
          disabledBackgroundColor: AppPalette.grey.withValues(alpha: 0.35),
          disabledForegroundColor: AppPalette.darkText.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.slate,
          side: BorderSide(color: AppPalette.grey.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.slate,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppPalette.red,
        foregroundColor: AppPalette.darkText,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppPalette.red,
        circularTrackColor: AppPalette.grey,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppPalette.red;
          return null;
        }),
        checkColor: WidgetStateProperty.all(AppPalette.darkText),
        side: BorderSide(color: AppPalette.grey.withValues(alpha: 0.6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppPalette.red;
          return AppPalette.grey.withValues(alpha: 0.7);
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppPalette.red;
          return AppPalette.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppPalette.red.withValues(alpha: 0.35);
          }
          return AppPalette.grey.withValues(alpha: 0.35);
        }),
      ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppPalette.slate,
      onPrimary: AppPalette.darkText,
      primaryContainer: AppPalette.slate,
      onPrimaryContainer: AppPalette.darkText,
      secondary: AppPalette.amber,
      onSecondary: AppPalette.slate,
      secondaryContainer: AppPalette.amber,
      onSecondaryContainer: AppPalette.slate,
      tertiary: AppPalette.red,
      onTertiary: AppPalette.darkText,
      tertiaryContainer: AppPalette.red,
      onTertiaryContainer: AppPalette.darkText,
      error: AppPalette.red,
      onError: AppPalette.darkText,
      errorContainer: AppPalette.red,
      onErrorContainer: AppPalette.darkText,
      surface: AppPalette.slate,
      onSurface: AppPalette.darkText,
      surfaceContainerHighest: AppPalette.slate,
      surfaceTint: AppPalette.slate,
      onSurfaceVariant: AppPalette.darkText,
      outline: AppPalette.grey,
      outlineVariant: AppPalette.grey,
      shadow: AppPalette.darkBackground,
      scrim: AppPalette.darkBackground,
      inverseSurface: AppPalette.darkText,
      onInverseSurface: AppPalette.darkBackground,
      inversePrimary: AppPalette.red,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: scheme,
      primaryColor: AppPalette.slate,
      scaffoldBackgroundColor: AppPalette.darkBackground,
      canvasColor: AppPalette.darkBackground,
      dividerColor: AppPalette.grey.withValues(alpha: 0.35),
      disabledColor: AppPalette.grey.withValues(alpha: 0.55),
      splashColor: AppPalette.grey.withValues(alpha: 0.12),
      highlightColor: AppPalette.grey.withValues(alpha: 0.10),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.darkBackground,
        foregroundColor: AppPalette.darkText,
        surfaceTintColor: AppPalette.darkBackground,
        elevation: 0,
        centerTitle: false,
      ),
      iconTheme: const IconThemeData(color: AppPalette.darkText),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppPalette.darkBackground,
        surfaceTintColor: AppPalette.darkBackground,
      ),
      cardTheme: const CardThemeData(
        color: AppPalette.slate,
        surfaceTintColor: AppPalette.slate,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.slate,
        contentTextStyle: const TextStyle(
          color: AppPalette.darkText,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: AppPalette.amber,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.slate,
        hintStyle: TextStyle(
          color: AppPalette.grey.withValues(alpha: 0.85),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: const TextStyle(
          color: AppPalette.darkText,
          fontWeight: FontWeight.w600,
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppPalette.grey.withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppPalette.red, width: 2),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppPalette.red),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppPalette.red, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.red,
          foregroundColor: AppPalette.darkText,
          disabledBackgroundColor: AppPalette.grey.withValues(alpha: 0.35),
          disabledForegroundColor: AppPalette.darkText.withValues(alpha: 0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.red,
          foregroundColor: AppPalette.darkText,
          disabledBackgroundColor: AppPalette.grey.withValues(alpha: 0.35),
          disabledForegroundColor: AppPalette.darkText.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.darkText,
          side: BorderSide(color: AppPalette.grey.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.darkText,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppPalette.red,
        foregroundColor: AppPalette.darkText,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppPalette.red,
        circularTrackColor: AppPalette.grey,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppPalette.red;
          return null;
        }),
        checkColor: WidgetStateProperty.all(AppPalette.darkText),
        side: BorderSide(color: AppPalette.grey.withValues(alpha: 0.6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppPalette.red;
          return AppPalette.grey.withValues(alpha: 0.7);
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppPalette.red;
          return AppPalette.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppPalette.red.withValues(alpha: 0.35);
          }
          return AppPalette.grey.withValues(alpha: 0.35);
        }),
      ),
    );
  }
}
