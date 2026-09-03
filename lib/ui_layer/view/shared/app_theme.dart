import 'package:flutter/material.dart';

// Single source of truth for the app's colour system. Every screen
// should read colours from here instead of hard-coding its own
// hex values, so the app reads as one consistent, lively product:
// white surfaces everywhere, a vibrant blue brand colour (not
// purple), and saturated accent colours for status/energy.
class AppColors {
  AppColors._();

  // Surfaces — always white, never cream/lavender-tinted.
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color cardBorder = Color(0xFFE3EDFC);

  // Brand blue.
  static const Color primary = Color(0xFF2F6FED);
  static const Color primaryDark = Color(0xFF163E85);
  static const Color primaryDeep = Color(0xFF10357A);
  static const Color secondary = Color(0xFF18B7C8);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, primary],
  );

  // Text.
  static const Color heading = Color(0xFF14213D);
  static const Color muted = Color(0xFF64748B);

  // Soft blue tints for chips/badges/inputs.
  static const Color tintFaint = Color(0xFFF3F8FE);
  static const Color tintLight = Color(0xFFE3EDFC);
  static const Color tintSoft = Color(0xFFDCE9FD);

  // Status accents — kept vivid on purpose for energy/legibility.
  static const Color warning = Color(0xFFFFA800);
  static const Color warningSoft = Color(0xFFFFF0C9);
  static const Color success = Color(0xFF2E7D32);
  static const Color successSoft = Color(0xFFE9F6EA);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerSoft = Color(0xFFFDEDED);
  static const Color alertDot = Color(0xFFFF4057);
}
