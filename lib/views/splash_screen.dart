import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../ads/app_open_ad_manager.dart';
import '../theme/app_theme.dart';
import 'home_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Splash Screen — Premium Theme-Aware
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Primary animation controller (icon scale + text fade) ──────────────
  late final AnimationController _ctrl;
  late final Animation<double> _iconScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  // ── Progress bar controller ─────────────────────────────────────────────
  late final AnimationController _loadCtrl;
  late final Animation<double> _progress;

  // ── Ambient glow pulse ──────────────────────────────────────────────────
  late final AnimationController _glowCtrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();

    // Main animation
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
          ),
        );

    // Progress bar
    _loadCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    _progress = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _loadCtrl, curve: Curves.easeInOut));

    // Glow pulse
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glow = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _ctrl.forward();
    _loadCtrl.forward();

    Timer(const Duration(milliseconds: 5400), () async {
      if (!mounted) return;
      HapticFeedback.lightImpact();

      final adManager = context.read<AppOpenAdManager>();

      // Wait for the ad to finish loading (or timeout after 5 seconds)
      await adManager.loadingFuture.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏰ Ad load timed out, proceeding without ad');
        },
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const HomeView(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          ),
        ),
      );

      Future.delayed(const Duration(milliseconds: 200), () {
        adManager.showAdIfAvailable();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _loadCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  String _loadingLabel(double p) {
    if (p < 0.30) return 'Initializing...';
    if (p < 0.58) return 'Loading services...';
    if (p < 0.82) return 'Scanning network...';
    return 'Almost ready...';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg = isDark ? AppTheme.deepBg : AppTheme.lightBg;
    final titleColor = isDark ? AppTheme.white : AppTheme.lightTitle;
    final subColor = isDark ? AppTheme.grey : AppTheme.lightSub;
    final accentColor = isDark ? AppTheme.emerald : AppTheme.lightAccent;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return CupertinoPageScaffold(
      backgroundColor: bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Remote wallpaper ────────────────────────────────────────────
          Image.asset('assets/images/remote_wallpaper.png', fit: BoxFit.cover),
          // ── Scrim ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [
                        Color(0x8C050D0A),
                        Color(0x4D050D0A),
                        Color(0xCC050D0A),
                      ]
                    : const [
                        Color(0xC8F0F7F4),
                        Color(0x90F0F7F4),
                        Color(0xDDF0F7F4),
                      ],
              ),
            ),
          ),
          // ── Ambient radial glow ──────────────────────────────────────────
          AnimatedBuilder(
            animation: _glow,
            builder: (_, __) => Center(
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withOpacity(0.12 * _glow.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── Top-right accent orb ────────────────────────────────────────
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [accentColor.withOpacity(0.08), Colors.transparent],
                ),
              ),
            ),
          ),
          // ── Main content ─────────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon ─────────────────────────────────────────────────
                ScaleTransition(
                  scale: _iconScale,
                  child: AnimatedBuilder(
                    animation: _glow,
                    builder: (_, child) => Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(
                              0.38 * _glow.value,
                            ),
                            blurRadius: 36,
                            spreadRadius: 0,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: AppTheme.teal.withOpacity(
                              0.18 * _glow.value,
                            ),
                            blurRadius: 60,
                            spreadRadius: 0,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: child,
                    ),
                    child: Image.asset(
                      'assets/images/icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // ── Branding text ────────────────────────────────────────
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppTheme.emeraldGradient.createShader(bounds),
                          child: const Text(
                            'Universal',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 3.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Remote for All TVs -',
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 56),

                // ── Progress bar ────────────────────────────────────────
                AnimatedBuilder(
                  animation: _progress,
                  builder: (_, __) {
                    final pct = _progress.value;
                    final pctInt = (pct * 100).toInt();
                    return FadeTransition(
                      opacity: _textFade,
                      child: SizedBox(
                        width: 220,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _loadingLabel(pct),
                                  style: TextStyle(
                                    color: subColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                ShaderMask(
                                  shaderCallback: (b) =>
                                      AppTheme.emeraldGradient.createShader(b),
                                  child: Text(
                                    '$pctInt%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Progress track
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                height: 4,
                                child: Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(
                                          0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: pct,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: AppTheme.emeraldGradient,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.emerald
                                                  .withOpacity(0.5),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
