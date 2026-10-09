import 'package:flutter/material.dart';

/// NOVA Launcher visual identity.
/// Midnight Navy base + Electric Blue / Violet accents, restrained neon.
class NovaColors {
  NovaColors._();

  static const Color bg = Color(0xFF0A0F1E); // Midnight Navy
  static const Color bgDeep = Color(0xFF070B16);
  static const Color surface = Color(0xFF121A2F);
  static const Color surfaceLight = Color(0xFF1A2440);
  static const Color cardStroke = Color(0x2EFFFFFF);

  static const Color electricBlue = Color(0xFF38BDF8);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color neonCyan = Color(0xFF22D3EE);
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFF87171);

  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [electricBlue, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient playGradient = LinearGradient(
    colors: [Color(0xFF22D3EE), Color(0xFF38BDF8), Color(0xFF8B5CF6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient subtleCard = LinearGradient(
    colors: [Color(0x1F38BDF8), Color(0x148B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Glassmorphism decoration used by cards (restrained, performance-safe).
Decoration novaGlass({double radius = 20, double stroke = 0.18}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: const LinearGradient(
      colors: [Color(0x26FFFFFF), Color(0x0AFFFFFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    border: Border.all(
      color: NovaColors.cardStroke.withOpacity(stroke),
      width: 1,
    ),
    boxShadow: const [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 18,
        offset: Offset(0, 8),
      ),
    ],
  );
}
