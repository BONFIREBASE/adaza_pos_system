import 'package:flutter/material.dart';

/// ADAZA brand palette: teal, copper/bronze, and gold on a cream background.
/// Centralized so every screen draws from the same source (Req 9.1).
abstract final class AppColors {
  // Primary brand tones
  static const Color teal = Color(0xFF1F6E6A);
  static const Color tealDark = Color(0xFF13504D);
  static const Color copper = Color(0xFFB06A3B);
  static const Color bronze = Color(0xFF8C5A2B);
  static const Color gold = Color(0xFFCBA14B);

  // Surfaces
  static const Color cream = Color(0xFFF7F1E3);
  static const Color creamSurface = Color(0xFFFFFBF2);
  static const Color card = Color(0xFFFFFFFF);

  // Hairline borders (flat, shadow-less design language)
  static const Color border = Color(0xFFE7DECB);
  static const Color borderStrong = Color(0xFFD8CCB2);
  static const Color hover = Color(0xFFF1EADB);

  // Semantic
  static const Color success = Color(0xFF2E7D5B);
  static const Color warning = Color(0xFFC9871F);
  static const Color error = Color(0xFFB3261E);

  // Text
  static const Color textPrimary = Color(0xFF2B2620);
  static const Color textSecondary = Color(0xFF6B6358);
}
