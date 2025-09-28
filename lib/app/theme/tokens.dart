import 'package:flutter/material.dart';

/// Centralized design tokens for colors, typography scale, spacing, radii,
/// elevations, and motion. Keep these primitive and app-agnostic.
class AppColors {
  AppColors._();

  // Brand
  static const Color brandPrimary = Color(0xFF0988B0); // main color
  static const Color brandAccent = Color(0xFF0D9C9E); // lime/teal
  static const Color brandAlert = Color(0xFFEC3F09); // mycel red

  // Semantic
  static const Color success = Color(0xFF1E8E3E);
  static const Color warning = Color(0xFFF9AB00);
  static const Color error = Color(0xFFB3261E);

  // Data visualization colors
  static const Color dataUpload = Color(0xFF0988B0); // Blue for upload (TX)
  static const Color dataDownload = Color(0xFF10B981); // Green for download (RX)
  static const Color dataPeers = Color(0xFF0988B0); // Primary blue for peers
  static const Color dataUptime = Color(0xFF10B981); // Green for uptime
  static const Color dataTraffic = Color(0xFF0D9C9E); // Accent teal for traffic

  // Neutrals
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color neutral900 = Color(0xFF111315);
  static const Color neutral800 = Color(0xFF1C1F22);
  static const Color neutral700 = Color(0xFF2A2E32);
  static const Color neutral600 = Color(0xFF3A3F44);
  static const Color neutral500 = Color(0xFF5C6268);
  static const Color neutral400 = Color(0xFF8A9096);
  static const Color neutral300 = Color(0xFFBCC2C8);
  static const Color neutral200 = Color(0xFFD8DDE2);
  static const Color neutral100 = Color(0xFFF1F3F5);

  // Surfaces
  static const Color surface = white;
  static const Color surfaceDim = neutral100;
  static const Color background = white;
}

class AppSpacing {
  AppSpacing._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double xxxxl = 48; // For desktop layouts
}

class AppRadii {
  AppRadii._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
}

class AppMotion {
  AppMotion._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
}

class AppElevation {
  AppElevation._();
  static const List<BoxShadow> level1 = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    )
  ];
  static const List<BoxShadow> level2 = [
    BoxShadow(
      color: Color(0x26000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    )
  ];
  static const List<BoxShadow> level3 = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    )
  ];
}

class AppTypography {
  AppTypography._();

  // Base font family is declared in pubspec and Theme
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
  static const TextStyle headline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );
  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );
}
