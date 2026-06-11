// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════
// COLOR TOKENS — Light Neomorphic Blue Theme
// ═══════════════════════════════════════════════════════════════

class AppColors {
  AppColors._();

  // ─── Background / Surface ──────────────────────────────────
  static const Color background = Color(0xFFEEF0FB); // lavender page bg
  static const Color surface = Color(0xFFFFFFFF); // card white
  static const Color surfaceElevated = Color(0xFFF5F6FD); // subtle inner bg
  static const Color border = Color(0xFFE0E4F5); // light blue border
  static const Color borderSubtle = Color(0xFFF0F2FC);

  // ─── Brand Blue ────────────────────────────────────────────
  static const Color primary = Color(0xFF3D5AFE); // royal blue — CTA, active
  static const Color primaryLight =
      Color(0xFF6B82FF); // lighter blue for dots/icons
  static const Color primaryGlow = Color(0x403D5AFE);
  static const Color primaryFill = Color(0x133D5AFE);
  static const Color primarySurface = Color(0xFFEEF0FB); // same as bg — tinted

  // ─── Detection States ──────────────────────────────────────
  static const Color idle = Color(0xFF3D5AFE); // blue — idle viewfinder
  static const Color idleGlow = Color(0x263D5AFE);
  static const Color detecting = Color(0xFF6B82FF); // lighter — detecting
  static const Color detected = Color(0xFF00C853); // green — detected
  static const Color detectedGlow = Color(0x4000C853);

  // ─── Text ──────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1F5E); // dark navy
  static const Color textSecondary = Color(0xFF8892C8); // muted blue-grey
  static const Color textTertiary = Color(0xFFB8BDE8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textAccent = Color(0xFF3D5AFE);

  // ─── UI Specific ───────────────────────────────────────────
  static const Color liveGreen = Color(0xFF4CAF50);
  static const Color badgeBg = Color(0xFFEEF0FB);
  static const Color scanLine = Color(0xFF3D5AFE);
  static const Color brailleDot = Color(0xFFB8BDE8); // soft dot color
  static const Color brailleDotDark = Color(0xFF8892C8);
  static const Color overlayDark = Color(0x800A0A2E);
  static const Color scanOverlay = Color(0x0F3D5AFE);
  static const Color shadowColor = Color(0x1A3D5AFE);
  static const Color error = Color(0xFFEF5350);

  static const Color warning = Color(0xFFFFB300); // kept for compat
  static const Color warningGlow = Color(0x40FFB300);
  static const Color warningFill = Color(0x12FFB300);
}

// ═══════════════════════════════════════════════════════════════
// TEXT STYLES
// ═══════════════════════════════════════════════════════════════

class AppTextStyles {
  AppTextStyles._();

  static const String _font = 'SpaceMono';

  static const TextStyle appBarTitle = TextStyle(
    fontFamily: _font,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 4.0,
  );

  static const TextStyle displayLarge = TextStyle(
    fontFamily: _font,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _font,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: _font,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 2.0,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: _font,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 1.5,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _font,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.65,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _font,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
    height: 1.55,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _font,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: _font,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 2.2,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: _font,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 2.0,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _font,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 1.8,
  );

  static const TextStyle resultText = TextStyle(
    fontFamily: _font,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.7,
  );

  static const TextStyle placeholder = TextStyle(
    fontFamily: _font,
    fontSize: 13,
    fontStyle: FontStyle.italic,
    color: AppColors.textTertiary,
    height: 1.6,
  );

  static const TextStyle statusChip = TextStyle(
    fontFamily: _font,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
  );

  static const TextStyle metadata = TextStyle(
    fontFamily: _font,
    fontSize: 9,
    color: AppColors.textTertiary,
    letterSpacing: 1.0,
  );

  static const TextStyle scanningLabel = TextStyle(
    fontFamily: _font,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textOnPrimary,
    letterSpacing: 1.0,
  );

  static const TextStyle readAloudLabel = TextStyle(
    fontFamily: _font,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textOnPrimary,
    letterSpacing: 0.5,
  );
}

// ═══════════════════════════════════════════════════════════════
// THEME
// ═══════════════════════════════════════════════════════════════

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        surface: AppColors.surface,
        surfaceContainer: AppColors.surfaceElevated,
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        secondary: AppColors.primaryLight,
        onSecondary: AppColors.textOnPrimary,
        tertiary: AppColors.detecting,
        onTertiary: AppColors.textOnPrimary,
        error: AppColors.error,
        onError: AppColors.textOnPrimary,
        outline: AppColors.border,
        outlineVariant: AppColors.borderSubtle,
        shadow: AppColors.shadowColor,
      ),
      fontFamily: 'SpaceMono',
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.displayLarge,
        displayMedium: AppTextStyles.displayMedium,
        titleLarge: AppTextStyles.titleLarge,
        titleMedium: AppTextStyles.titleMedium,
        titleSmall: AppTextStyles.titleSmall,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.labelLarge,
        labelMedium: AppTextStyles.labelMedium,
        labelSmall: AppTextStyles.labelSmall,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: AppTextStyles.appBarTitle,
        iconTheme: IconThemeData(color: AppColors.textPrimary, size: 20),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 20,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      splashColor: AppColors.primaryFill,
      highlightColor: AppColors.primaryFill,
      splashFactory: InkRipple.splashFactory,
    );
  }

  // Alias — agar main.dart cukup tulis AppTheme.dark (backward compat)
  static ThemeData get dark => light;

  static const SystemUiOverlayStyle systemUiStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.dark,
  );
}

// ═══════════════════════════════════════════════════════════════
// EXTENSIONS
// ═══════════════════════════════════════════════════════════════

extension BuildContextTheme on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenW => MediaQuery.sizeOf(this).width;
  double get screenH => MediaQuery.sizeOf(this).height;
  EdgeInsets get padding => MediaQuery.paddingOf(this);
}

extension AppColorUtils on Color {
  Color withBrightness(double factor) {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness * factor).clamp(0.0, 1.0))
        .toColor();
  }
}
