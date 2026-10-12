import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colors.dart';

class NovaTheme {
  NovaTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: NovaColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: NovaColors.electricBlue,
          secondary: NovaColors.violet,
          surface: NovaColors.surface,
          error: NovaColors.danger,
          onSurface: NovaColors.textPrimary,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          iconTheme: IconThemeData(color: NovaColors.textPrimary),
          titleTextStyle: TextStyle(
            color: NovaColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: NovaColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 32,
          ),
          titleLarge: TextStyle(
            color: NovaColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
          titleMedium: TextStyle(
            color: NovaColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(color: NovaColors.textPrimary, fontSize: 14),
          bodySmall: TextStyle(color: NovaColors.textSecondary, fontSize: 12),
          labelLarge: TextStyle(
            color: NovaColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.4,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: NovaColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: NovaColors.electricBlue,
        ),
      );
}
