import 'package:flutter/material.dart';
import 'tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandPrimary,
      brightness: Brightness.light,
    ).copyWith(
      secondary: AppColors.brandAccent,
      error: AppColors.error,
      surface: AppColors.surface,
      outline: AppColors.neutral300,
    );

    final rawTextTheme = base.textTheme
        .copyWith(
          displayLarge: AppTypography.display,
          headlineMedium: AppTypography.headline,
          titleMedium: AppTypography.title,
          bodyMedium: AppTypography.body,
          labelMedium: AppTypography.label,
        )
        .apply(fontFamily: 'Roboto');

    final textTheme = rawTextTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.neutral900,
        elevation: 0,
        centerTitle: false,
        titleTextStyle:
            AppTypography.title.copyWith(color: AppColors.neutral900),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        margin: const EdgeInsets.all(0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.neutral300;
            }
            return colorScheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withValues(alpha: 0.38);
            }
            return colorScheme.onPrimary;
          }),
          minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),
          animationDuration: AppMotion.medium,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: AppColors.neutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: AppColors.brandPrimary),
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.lg),
      ),
      dividerColor: AppColors.neutral200,
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      secondary: AppColors.brandAccent,
      error: AppColors.error,
      onError: AppColors.white,
      surface: AppColors.neutral800,
      outline: AppColors.neutral600,
    );

    final rawTextTheme = base.textTheme
        .copyWith(
          displayLarge: AppTypography.display,
          headlineMedium: AppTypography.headline,
          titleMedium: AppTypography.title,
          bodyMedium: AppTypography.body,
          labelMedium: AppTypography.label,
        )
        .apply(fontFamily: 'Roboto');

    final textTheme = rawTextTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle:
            AppTypography.title.copyWith(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        margin: const EdgeInsets.all(0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.neutral600;
            }
            return colorScheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withValues(alpha: 0.38);
            }
            return colorScheme.onPrimary;
          }),
          minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),
          animationDuration: AppMotion.medium,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.lg),
      ),
      dividerColor: colorScheme.outline,
    );
  }
}
