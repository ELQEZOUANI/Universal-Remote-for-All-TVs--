import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, BoxShadow, LinearGradient;
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Haptic press-scale wrapper
// ─────────────────────────────────────────────────────────────────────────────
class PremiumTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleDown;
  const PremiumTap({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleDown = 0.94,
  });

  @override
  State<PremiumTap> createState() => _PremiumTapState();
}

class _PremiumTapState extends State<PremiumTap> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = widget.scaleDown),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RadarPainter — concentric pulse rings for scanning animation
// ─────────────────────────────────────────────────────────────────────────────
class RadarPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0, loops
  final Color color;

  RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw 3 staggered rings
    for (int i = 0; i < 3; i++) {
      final phase = (progress + i / 3.0) % 1.0;
      final radius = phase * maxRadius;
      final opacity = (1.0 - phase) * 0.55;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withOpacity(opacity);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RadarPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
//  ScanDeviceCard — primary CTA for the home screen
// ─────────────────────────────────────────────────────────────────────────────
class ScanDeviceCard extends StatelessWidget {
  final bool scanning;
  final bool isDark;
  final AnimationController radarCtrl;
  final VoidCallback onTap;

  const ScanDeviceCard({
    super.key,
    required this.scanning,
    required this.isDark,
    required this.radarCtrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (scanning) {
      return _buildScanning();
    }
    return _buildIdle();
  }

  Widget _buildIdle() {
    return PremiumTap(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0F5132), Color(0xFF063520)]
                : const [Color(0xFF34D399), Color(0xFF10B981)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppTheme.glowShadow(),
        ),
        child: Column(
          children: [
            // Radar icon with static rings
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Static outer ring
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  // Static mid ring
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  // Inner filled circle
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.18),
                    ),
                    child: const Icon(
                      CupertinoIcons.wifi,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan for Devices',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to discover Android TVs on your network',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF0F5132), Color(0xFF063520)]
              : const [Color(0xFF34D399), Color(0xFF10B981)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.glowShadow(intensity: 1.3),
      ),
      child: Column(
        children: [
          // Animated radar
          AnimatedBuilder(
            animation: radarCtrl,
            builder: (_, __) {
              return SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulse rings
                    CustomPaint(
                      size: const Size(80, 80),
                      painter: RadarPainter(
                        progress: radarCtrl.value,
                        color: Colors.white,
                      ),
                    ),
                    // Pulsing inner circle
                    AnimatedBuilder(
                      animation: radarCtrl,
                      builder: (_, __) {
                        final pulse = sin(radarCtrl.value * 2 * pi) * 0.5 + 0.5;
                        return Container(
                          width: 24 + pulse * 6,
                          height: 24 + pulse * 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.85),
                          ),
                          child: const Icon(
                            CupertinoIcons.wifi,
                            color: AppTheme.emerald,
                            size: 14,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Scanning…',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Looking for Android TVs on your Wi-Fi',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EmptyRecentPainter — custom-painted empty-state illustration
// ─────────────────────────────────────────────────────────────────────────────
class EmptyRecentPainter extends CustomPainter {
  final Color accent;
  EmptyRecentPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.45;

    // ── TV body ──
    final bodyPaint = Paint()
      ..color = accent.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    final bodyBorderPaint = Paint()
      ..color = accent.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 90, height: 62),
      const Radius.circular(10),
    );
    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRRect(bodyRect, bodyBorderPaint);

    // ── Screen ──
    final screenPaint = Paint()
      ..color = accent.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 72, height: 44),
      const Radius.circular(6),
    );
    canvas.drawRRect(screenRect, screenPaint);

    // ── Stand ──
    final standPaint = Paint()
      ..color = accent.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy + 31), Offset(cx, cy + 46), standPaint);
    canvas.drawLine(
      Offset(cx - 18, cy + 46),
      Offset(cx + 18, cy + 46),
      standPaint,
    );

    // ── Wi-Fi arcs ──
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final r = 18.0 + i * 16.0;
      arcPaint.color = accent.withOpacity(0.5 - i * 0.13);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(cx, cy - 28),
          width: r * 2,
          height: r * 2,
        ),
        pi * 1.15,
        pi * 0.7,
        false,
        arcPaint,
      );
    }

    // ── Dot under arcs ──
    canvas.drawCircle(
      Offset(cx, cy - 28),
      3,
      Paint()..color = accent.withOpacity(0.7),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  EmptyRecentState widget
// ─────────────────────────────────────────────────────────────────────────────
class EmptyRecentState extends StatelessWidget {
  final bool isDark;
  const EmptyRecentState({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppTheme.emerald : AppTheme.lightAccent;
    final title = isDark ? AppTheme.white : AppTheme.lightTitle;
    final sub = isDark ? AppTheme.grey : AppTheme.lightSub;

    return Column(
      children: [
        // Custom illustration
        SizedBox(
          width: 160,
          height: 120,
          child: CustomPaint(painter: EmptyRecentPainter(accent: accent)),
        ),
        const SizedBox(height: 8),
        Text(
          'No Recent Devices',
          style: TextStyle(
            color: title,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Devices you connect to will appear here.\nHead to Home to scan your network.',
          textAlign: TextAlign.center,
          style: TextStyle(color: sub, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PremiumSettingsTile
// ─────────────────────────────────────────────────────────────────────────────
class PremiumSettingsTile extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;
  final bool isDark;

  const PremiumSettingsTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  State<PremiumSettingsTile> createState() => _PremiumSettingsTileState();
}

class _PremiumSettingsTileState extends State<PremiumSettingsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.isDark ? AppTheme.white : AppTheme.lightTitle;
    final subColor = widget.isDark ? AppTheme.grey : AppTheme.lightSub;
    final pressedBg = widget.isDark
        ? Colors.white.withOpacity(0.06)
        : AppTheme.lightAccentBg;
    final chevronColor = widget.isDark
        ? AppTheme.greyDark
        : const Color(0xFFCBD5E0);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_pressed ? 0.98 : 1.0),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _pressed ? pressedBg : Colors.transparent,
          borderRadius: BorderRadius.vertical(
            top: widget.isFirst ? const Radius.circular(20) : Radius.zero,
            bottom: widget.isLast ? const Radius.circular(20) : Radius.zero,
          ),
        ),
        child: Row(
          children: [
            // Icon bubble with subtle inner glow & border
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.iconBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.iconColor.withOpacity(0.3),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.iconColor.withOpacity(0.25),
                    blurRadius: 10,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()..translate(_pressed ? 4.0 : 0.0),
              child: Icon(
                CupertinoIcons.chevron_right,
                color: _pressed ? widget.iconColor : chevronColor,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PremiumSquareTile
// ─────────────────────────────────────────────────────────────────────────────
class PremiumSquareTile extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDark;

  const PremiumSquareTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<PremiumSquareTile> createState() => _PremiumSquareTileState();
}

class _PremiumSquareTileState extends State<PremiumSquareTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.isDark ? AppTheme.white : AppTheme.lightTitle;
    final subColor = widget.isDark ? AppTheme.grey : AppTheme.lightSub;
    final bg = widget.isDark ? const Color(0xFF1E1E2C) : AppTheme.white;
    final borderColor = widget.isDark
        ? const Color(0xFF1C3628)
        : const Color(0xFFE2E8F0);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_pressed ? 0.96 : 1.0),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 0.8),
          boxShadow: widget.isDark
              ? AppTheme.cardShadow()
              : AppTheme.luxuryShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: widget.iconBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.iconColor.withOpacity(0.3),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.iconColor.withOpacity(0.25),
                    blurRadius: 10,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 20),
            ),
            const Spacer(),
            Text(
              widget.title,
              style: TextStyle(
                color: titleColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: subColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PremiumBottomNav  — animated frosted-glass pill
// ─────────────────────────────────────────────────────────────────────────────
class PremiumBottomNav extends StatefulWidget {
  final int index;
  final ValueChanged<int> onTap;
  final bool isDark;

  const PremiumBottomNav({
    super.key,
    required this.index,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<PremiumBottomNav> createState() => _PremiumBottomNavState();
}

class _PremiumBottomNavState extends State<PremiumBottomNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _indicatorCtrl;
  late Animation<double> _indicatorPos;
  int _prevIndex = 0;

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.index;
    _indicatorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _indicatorPos =
        Tween<double>(
          begin: widget.index.toDouble(),
          end: widget.index.toDouble(),
        ).animate(
          CurvedAnimation(parent: _indicatorCtrl, curve: Curves.easeOutCubic),
        );
  }

  @override
  void didUpdateWidget(PremiumBottomNav old) {
    super.didUpdateWidget(old);
    if (widget.index != _prevIndex) {
      _indicatorPos =
          Tween<double>(
            begin: _prevIndex.toDouble(),
            end: widget.index.toDouble(),
          ).animate(
            CurvedAnimation(parent: _indicatorCtrl, curve: Curves.easeOutCubic),
          );
      _indicatorCtrl.forward(from: 0);
      _prevIndex = widget.index;
    }
  }

  @override
  void dispose() {
    _indicatorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fillColor = widget.isDark
        ? const Color(0xFF0E0E18).withOpacity(0.82)
        : Colors.white.withOpacity(0.80);
    final borderColor = widget.isDark
        ? AppTheme.emerald.withOpacity(0.25)
        : AppTheme.lightAccent.withOpacity(0.40);
    final glowColor = widget.isDark
        ? AppTheme.emerald.withOpacity(0.18)
        : AppTheme.lightAccent.withOpacity(0.14);

    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: 28,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const items = [
                (icon: CupertinoIcons.house_fill, label: 'Home'),
                (icon: CupertinoIcons.clock_fill, label: 'Recent'),
                (icon: CupertinoIcons.settings, label: 'Settings'),
              ];

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Animated sliding indicator
                  AnimatedBuilder(
                    animation: _indicatorPos,
                    builder: (_, __) {
                      // Each tab occupies 1/3 of the row
                      final total = constraints.maxWidth;
                      final tabW = total / 3;
                      final indicatorW = _indicatorPos.value == widget.index
                          ? 96.0
                          : 48.0;
                      final x =
                          _indicatorPos.value * tabW +
                          (tabW / 2) -
                          (indicatorW / 2);
                      return Positioned(
                        left: x,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: indicatorW,
                          height: 40,
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? AppTheme.surfaceLight.withOpacity(0.4)
                                : AppTheme.lightAccentBg,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: widget.isDark
                                ? AppTheme.glowShadow(intensity: 0.6)
                                : [],
                          ),
                        ),
                      );
                    },
                  ),
                  // Tab row
                  Row(
                    children: List.generate(items.length, (i) {
                      final item = items[i];
                      final isActive = widget.index == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onTap(i);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            height: 52,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: isActive
                                  ? Row(
                                      key: ValueKey('active_$i'),
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          item.icon,
                                          size: 15,
                                          color: widget.isDark
                                              ? AppTheme.emerald
                                              : AppTheme.lightAccent,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          item.label,
                                          style: TextStyle(
                                            color: widget.isDark
                                                ? AppTheme.emerald
                                                : AppTheme.lightAccent,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Icon(
                                      key: ValueKey('inactive_$i'),
                                      item.icon,
                                      size: 18,
                                      color: widget.isDark
                                          ? AppTheme.grey
                                          : AppTheme.lightSub,
                                    ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  GlowIconButton — top-bar icon button with optional ambient glow
// ─────────────────────────────────────────────────────────────────────────────
class GlowIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;
  final bool isDark;

  const GlowIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.isDark,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgLight = accent ? AppTheme.lightAccentBg : AppTheme.lightCard;
    final bgDark = accent
        ? AppTheme.surfaceLight.withOpacity(0.4)
        : const Color(0xFF1A1A2E);
    final iconColor = accent
        ? (isDark ? AppTheme.emerald : AppTheme.lightAccent)
        : (isDark ? AppTheme.grey : AppTheme.lightSub);

    return PremiumTap(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? bgDark : bgLight,
          borderRadius: BorderRadius.circular(14),
          boxShadow: accent
              ? (isDark
                    ? AppTheme.glowShadow(intensity: 0.7)
                    : AppTheme.cardShadow())
              : AppTheme.cardShadow(),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ScanTip — a single "quick tip" row
// ─────────────────────────────────────────────────────────────────────────────
class ScanTip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isDark;

  const ScanTip({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? AppTheme.white : AppTheme.lightTitle;
    final subColor = isDark
        ? AppTheme.white.withOpacity(0.75)
        : AppTheme.lightSub;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  iconColor.withOpacity(isDark ? 0.22 : 0.15),
                  iconColor.withOpacity(isDark ? 0.10 : 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: iconColor.withOpacity(0.3), width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.15),
                  blurRadius: 12,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subColor,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
