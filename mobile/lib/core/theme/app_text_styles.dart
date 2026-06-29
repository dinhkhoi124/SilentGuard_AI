import 'package:flutter/material.dart';

/// Centralized typographic design tokens mapped to Material 3 semantics.
abstract final class AppTextStyles {
  // Headings
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -1.0,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.3,
    letterSpacing: -0.5,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.5,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.35,
    letterSpacing: -0.2,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.4,
    letterSpacing: 0,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.45,
    letterSpacing: 0,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
    letterSpacing: 0,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.1,
  );

  // Custom Legal / Long Form Reading Text (Not part of standard TextTheme)
  static const TextStyle bodyLongText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: 0,
  );
}

/// Extension to easily access custom styles from context
extension AppTextThemeExtension on TextTheme {
  TextStyle? get bodyLongText =>
      AppTextStyles.bodyLongText.copyWith(color: bodyLarge?.color);
}
