import 'dart:ui';
import 'package:flutter/cupertino.dart';

/// Universal Remote Control – Premium Design System
class AppTheme {
  AppTheme._();

  // ── Core Dark Palette (Relaxing Green) ──────────────────────────────────
  static const Color deepBg = Color(0xFF050D0A);
  static const Color midnight = Color(0xFF07120D);
  static const Color charcoal = Color(0xFF0D1C14);
  static const Color surface = Color(0xFF14291D);
  static const Color surfaceLight = Color(0xFF1A3626);

  // ── Accent / Brand ────────────────────────────────────────────────────────
  static const Color emerald = Color(0xFF00E5A0); // primary brand
  static const Color teal = Color(0xFF00BFA5); // gradient end
  static const Color emeraldDim = Color(0xFF00C853);

  // ── Semantics ─────────────────────────────────────────────────────────────
  static const Color amber = Color(0xFFFFAB00);
  static const Color redAccent = Color(0xFFFF1744);
  static const Color connected = Color(0xFF34D399); // green status dot

  // ── Text / Neutral ────────────────────────────────────────────────────────
  static const Color white = Color(0xFFEEEEEE);
  static const Color whiteL60 = Color(0x99EEEEEE); // 60 % opacity
  static const Color whiteL30 = Color(0x4DEEEEEE); // 30 % opacity
  static const Color grey = Color(0xFF8892B0);
  static const Color greyDark = Color(0xFF495670);

  // ── Light Theme surface palette ───────────────────────────────────────────
  static const Color lightBg = Color(0xFFF0F7F4);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightAccent = Color(0xFF10B981);
  static const Color lightAccentD = Color(0xFF059669);
  static const Color lightAccentBg = Color(0xFFECFDF5);
  static const Color lightTitle = Color(0xFF1A202C);
  static const Color lightSub = Color(0xFF718096);
  static const Color lightDivider = Color(0xFFE2E8F0);

  // ── Gradients ─────────────────────────────────────────────────────────────
  /// Primary brand gradient — Emerald → Deep Teal
  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [emerald, teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle dark card background gradient
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF0F2118), Color(0xFF0C1A12)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Full-page background gradient (dark)
  static const LinearGradient bgGradient = LinearGradient(
    colors: [deepBg, Color(0xFF07120D), Color(0xFF0A1811)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Power / destructive gradient
  static const LinearGradient powerGradient = LinearGradient(
    colors: [Color(0xFFFF1744), Color(0xFFD50000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Glow Shadows ─────────────────────────────────────────────────────────
  /// Ambient emerald glow — use on primary action surfaces
  static List<BoxShadow> glowShadow({double intensity = 1.0}) => [
    BoxShadow(
      color: emerald.withOpacity(0.28 * intensity),
      blurRadius: 24,
      spreadRadius: 0,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: teal.withOpacity(0.14 * intensity),
      blurRadius: 48,
      spreadRadius: 0,
      offset: const Offset(0, 16),
    ),
  ];

  /// Subtle card elevation shadow (dark)
  static List<BoxShadow> darkCardShadow() => const [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 32,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      spreadRadius: 0,
      offset: Offset(0, 2),
    ),
  ];

  /// Luxury card shadow for light theme
  static List<BoxShadow> luxuryShadow() => const [
    BoxShadow(
      color: Color(0x1A0A8C68),
      blurRadius: 32,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 16,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
  ];

  static List<BoxShadow> cardShadow() => const [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 24,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x07000000),
      blurRadius: 8,
      spreadRadius: 0,
      offset: Offset(0, 1),
    ),
  ];

  // ── Glassmorphism ─────────────────────────────────────────────────────────
  static BoxDecoration glass({
    double opacity = 0.08,
    double radius = 24,
    Color? border,
    Color? tint,
  }) => BoxDecoration(
    color: (tint ?? CupertinoColors.white).withOpacity(opacity),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: border ?? CupertinoColors.white.withOpacity(0.1),
      width: 0.8,
    ),
  );

  static Widget glassCard({
    required Widget child,
    double opacity = 0.08,
    double blur = 20,
    double radius = 24,
    EdgeInsets padding = const EdgeInsets.all(16),
    Color? border,
  }) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        padding: padding,
        decoration: glass(opacity: opacity, radius: radius, border: border),
        child: child,
      ),
    ),
  );

  // ── Neumorphic (kept for remote_view) ────────────────────────────────────
  static List<BoxShadow> neuShadow({bool pressed = false}) => pressed
      ? [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(0.6),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
          BoxShadow(
            color: const Color(0xFF2A2A4A).withOpacity(0.15),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
        ]
      : [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(0.7),
            offset: const Offset(4, 4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: const Color(0xFF2A2A4A).withOpacity(0.2),
            offset: const Offset(-4, -4),
            blurRadius: 10,
          ),
        ];

  static BoxDecoration neuBox({
    bool pressed = false,
    double radius = 20,
    Color? color,
  }) => BoxDecoration(
    color: color ?? charcoal,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: neuShadow(pressed: pressed),
  );
}
