import 'package:flutter/material.dart';

/// Naharym palette, taken straight from the approved courier mock-ups
/// (`Naharym-mockups-RU/courier_list.png`, `courier_route.png`).
class AppColors {
  const AppColors._();

  /// Header, primary text, map route casing.
  static const Color green = Color(0xFF0B3B2E);
  static const Color greenLight = Color(0xFF1D6B50);
  static const Color greenMuted = Color(0xFF8FB0A2);
  static const Color greenSurface = Color(0xFF11493A);

  /// Primary action colour — "На смене", "Доставил", the route line.
  static const Color orange = Color(0xFFE2542C);
  static const Color orangeSoft = Color(0xFFFFEDE6);

  /// Money. Cash bar, change chip.
  static const Color gold = Color(0xFFC8A24A);
  static const Color goldSoft = Color(0xFFF3E7C9);

  /// Warnings — "забран" chip, offline dot, late orders.
  static const Color red = Color(0xFFC84833);
  static const Color redSoft = Color(0xFFFBE7E3);

  /// Page background and cards.
  static const Color cream = Color(0xFFF6F1E7);
  static const Color white = Color(0xFFFFFFFF);

  /// Text.
  static const Color textPrimary = Color(0xFF16211D);
  static const Color textSecondary = Color(0xFF6B7B75);
  static const Color textMuted = Color(0xFFA6B2AD);
  static const Color divider = Color(0xFFE8E2D6);

  static const Color shadow = Color(0x14000000);
}
