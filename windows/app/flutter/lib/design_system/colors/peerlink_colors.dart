import 'package:flutter/material.dart';

/// Minimalist Light-Only Color Palette for PeerLink (Zero dark surfaces, zero glow).
class PeerLinkColors {
  // Brand Primary
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryBlueDark = Color(0xFF1D4ED8);
  static const Color primaryBlueLight = Color(0xFFEFF6FF);

  // Intent Accents (Restrained Essential Accents)
  static const Color sendAccent = Color(0xFF2563EB);
  static const Color accessAccent = Color(0xFF0F766E);
  static const Color syncAccent = Color(0xFFD97706);
  static const Color backupAccent = Color(0xFF4F46E5);
  static const Color securityAccent = Color(0xFF15803D);

  // Status & Verdicts
  static const Color verifiedGreen = Color(0xFF15803D);
  static const Color verifiedGreenBg = Color(0xFFF0FDF4);
  static const Color warningAmber = Color(0xFFB45309);
  static const Color warningAmberBg = Color(0xFFFFFBEB);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color dangerRedBg = Color(0xFFFEF2F2);
  static const Color neutralGrey = Color(0xFF64748B);
  static const Color neutralGreyBg = Color(0xFFF8FAFC);

  // Minimalist Light Mode Surfaces & Borders
  static const Color lightBg = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSubtle = Color(0xFFF3F4F6);
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightBorderStrong = Color(0xFFCBD5E1);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
}
