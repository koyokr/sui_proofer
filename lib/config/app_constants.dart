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

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 16.0;
  static const double defaultIconSize = 28.0;

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
}