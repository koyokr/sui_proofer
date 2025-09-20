import 'package:flutter/material.dart';

class AppConstants {
  // App Information
  static const String appTitle = 'Sui Proofer';

  // Timing Constants
  static const Duration verificationTimeout = Duration(seconds: 5);
  static const Duration urlValidationTimeout = Duration(seconds: 10);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration overlayAnimationDuration = Duration(milliseconds: 800);
  static const Duration scaleAnimationDuration = Duration(milliseconds: 400);
  static const Duration iconAnimationDuration = Duration(milliseconds: 600);

  // System Constants
  static const String mainAppPort = 'MainApp';
  static const int defaultSmsLimit = 50;
  static const int defaultHistoryLimit = 10;
  static const String defaultSubmitter = '0x8b89d808ce6e1c5a560354c264f7ff4166e05d138b8534fcae78058acfe298f4';
  static const String submitterKey = 'sui_submitter';

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 16.0;
  static const double defaultIconSize = 28.0;
  static const double largeIconSize = 60.0;
  static const double mediumIconSize = 32.0;
  static const double smallIconSize = 16.0;
  static const double cardPadding = 12.0;
  static const double sectionPadding = 18.0;
  static const double marginSmall = 6.0;
  static const double marginMedium = 12.0;
  static const double marginLarge = 24.0;

  // Text Sizes
  static const double titleTextSize = 18.0;
  static const double headingTextSize = 20.0;
  static const double bodyTextSize = 14.0;
  static const double captionTextSize = 11.0;
  static const double phoneTextSize = 16.0;

  // Colors
  static const int primaryColorValue = 0xFF1E3A8A;
  static const int backgroundColorValue = 0xFF0F172A;
  static const int surfaceColorValue = 0xFF1E293B;
}

class AppColors {
  static const primaryBlue = Color(0xFF60A5FA);
  static const primaryGreen = Color(0xFF34D399);
  static const successGreen = Color(0xFF10B981);
  static const errorRed = Color(0xFFEF4444);
  static const warningOrange = Color(0xFFF59E0B);
  static const backgroundDark = Color(0xFF0F172A);
  static const surfaceDark = Color(0xFF1E293B);
  static const surfaceLight = Color(0xFF334155);

  // Additional UI Colors
  static const cardBackground = Color(0xFF1E293B);
  static const borderColor = Color(0xFF60A5FA);
  static const overlayBackground = Colors.black;
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFB0B0B0);
  static const accentColors = [
    Color(0xFF10B981), // verified green
    Color(0xFFDC2626), // failed red
    Color(0xFF6B7280), // pending gray
  ];
}