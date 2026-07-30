import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, BoxShadow, Divider;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/tv_provider.dart';
import '../remote_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Design Tokens — Light Theme (mirrors HomeView's _L)
// ─────────────────────────────────────────────────────────────────────────────
class _L {
  _L._();
  static const bg = Color(0xFFF4F6F8);
  static const card = Color(0xFFFFFFFF);
  static const accent = Color(0xFF0A8C68);
  static const accentDeep = Color(0xFF077A5A);
  static const accentLight = Color(0xFFE8F5F0);
  static const accentEdge = Color(0xFFB2DFDB);
  static const title = Color(0xFF1A202C);
  static const subtitle = Color(0xFF718096);
  static const divider = Color(0xFFE2E8F0);
  static const dpadRing = Color(0xFFF0F2F5);
  static const red = Color(0xFFE53E3E);
  static const amber = Color(0xFFED8936);

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
  static List<BoxShadow> accentShadow() => [
    BoxShadow(
      color: const Color(0xFF0A8C68).withOpacity(0.3),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────────────────
Widget _card({
  required Widget child,
  double radius = 24,
  EdgeInsetsGeometry? padding,
  List<BoxShadow>? shadows,
  Color? color,
}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? _L.card,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: shadows ?? _L.cardShadow(),
    ),
    child: child,
  );
}

Widget _sectionLabel(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Text(
    t,
    style: const TextStyle(
      color: _L.subtitle,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
//  Pressable wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Tap({required this.child, required this.onTap});
  @override
  State<_Tap> createState() => _TapState();
}

class _TapState extends State<_Tap> {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.92),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RemoteView — Root
// ─────────────────────────────────────────────────────────────────────────────
class RemoteView extends StatefulWidget {
  const RemoteView({super.key});
  @override
  State<RemoteView> createState() => _RemoteViewState();
}

class _RemoteViewState extends State<RemoteView> {
  bool _touchpadMode = false;
  bool _numpadVisible = false;

  /// Sends a key through the provider and shows a brief toast if not connected.
  Future<void> _sendKey(BuildContext context, RemoteKey key) async {
    final pv = context.read<TVProvider>();
    final ok = await pv.sendKey(key);
    if (!ok && context.mounted) {
      _showToast(context, 'Not connected — reconnect to TV first');
    }
  }

  void _showToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 80,
        left: 24,
        right: 24,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A202C).withOpacity(0.92),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), entry.remove);
  }

  @override
  Widget build(BuildContext context) {
    final pv = context.watch<TVProvider>();
    return CupertinoPageScaffold(
      backgroundColor: _L.bg,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _TopBar(pv: pv),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Status strip ──────────────────────────────────
                        if (!pv.isConnected) _DisconnectBanner(),
                        // ── App Launcher (hidden if TV can't launch apps) ──
                        if (pv.supportsAppLaunching) _AppLauncher(pv: pv),
                        if (pv.supportsAppLaunching) const SizedBox(height: 22),
                        // ── Mode toggle ───────────────────────────────────
                        _ModeToggle(
                          touchpad: _touchpadMode,
                          onChange: (v) {
                            HapticFeedback.selectionClick();
                            setState(() => _touchpadMode = v);
                          },
                        ),
                        const SizedBox(height: 22),
                        // ── Centre: VOL | D-Pad | CH ──────────────────────
                        _card(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('CONTROL PAD'),
                              SizedBox(
                                height: 280,
                                child: Row(
                                  children: [
                                    _VolumePill(pv: pv),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _touchpadMode
                                          ? _TouchPad(pv: pv)
                                          : _DPad(pv: pv),
                                    ),
                                    const SizedBox(width: 16),
                                    _ChannelPill(pv: pv),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        // ── Control grid ──────────────────────────────────
                        _ControlGrid(
                          pv: pv,
                          canSource: pv.supportsSourceControl,
                          canMenu: pv.supportsMenuNavigation,
                          onSendKey: (key) => _sendKey(context, key),
                        ),
                        const SizedBox(height: 22),
                        // ── Playback ──────────────────────────────────────
                        _PlaybackBar(pv: pv),
                        const SizedBox(height: 22),
                        // ── Numpad toggle ─────────────────────────────────
                        _Tap(
                          onTap: () =>
                              setState(() => _numpadVisible = !_numpadVisible),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _L.card,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: _L.cardShadow(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _numpadVisible
                                      ? CupertinoIcons.chevron_up
                                      : CupertinoIcons.number,
                                  size: 14,
                                  color: _L.subtitle,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _numpadVisible
                                      ? 'Hide Number Pad'
                                      : 'Show Number Pad',
                                  style: const TextStyle(
                                    color: _L.subtitle,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_numpadVisible) ...[
                          const SizedBox(height: 16),
                          _NumPad(pv: pv),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Top Bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final TVProvider pv;
  const _TopBar({required this.pv});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Row(
        children: [
          _Tap(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _L.card,
                borderRadius: BorderRadius.circular(13),
                boxShadow: _L.cardShadow(),
              ),
              child: const Icon(
                CupertinoIcons.chevron_left,
                color: _L.title,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UNIVERSAL REMOTE',
                  style: TextStyle(
                    color: _L.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pv.activeDevice?.name ?? 'Remote Control',
                  style: const TextStyle(
                    color: _L.title,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: pv.isConnected ? _L.accentLight : const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: pv.isConnected ? _L.accentEdge : const Color(0xFFFEB2B2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseDot(color: pv.isConnected ? _L.accent : _L.red),
                const SizedBox(width: 7),
                Text(
                  pv.isConnected ? 'Live' : 'Offline',
                  style: TextStyle(
                    color: pv.isConnected ? _L.accent : _L.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _a = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(_a.value),
          boxShadow: [
            BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 5),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Disconnect Banner
// ─────────────────────────────────────────────────────────────────────────────
class _DisconnectBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFEB2B2)),
        ),
        child: const Row(
          children: [
            Icon(CupertinoIcons.wifi_slash, size: 14, color: _L.red),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Disconnected — go back to reconnect',
                style: TextStyle(
                  color: _L.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  App Launcher (Quick Launch)
// ─────────────────────────────────────────────────────────────────────────────
class _AppLauncher extends StatelessWidget {
  final TVProvider pv;
  const _AppLauncher({required this.pv});
  @override
  Widget build(BuildContext context) {
    return _card(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('APPS'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AppBtn(
                label: 'Netflix',
                icon: CupertinoIcons.play_rectangle_fill,
                color: const Color(0xFFE50914),
                onTap: () => pv.sendKey(RemoteKey.netflix),
              ),
              _AppBtn(
                label: 'YouTube',
                icon: CupertinoIcons.play_circle_fill,
                color: const Color(0xFFFF3D00),
                onTap: () => pv.sendKey(RemoteKey.youtube),
              ),
              _AppBtn(
                label: 'Prime',
                icon: CupertinoIcons.star_circle_fill,
                color: const Color(0xFF0099FF),
                onTap: () => pv.sendKey(RemoteKey.prime),
              ),
              _AppBtn(
                label: 'Disney+',
                icon: CupertinoIcons.sparkles,
                color: const Color(0xFF3355FF),
                onTap: () => pv.sendKey(RemoteKey.disneyPlus),
              ),
              _AppBtn(
                label: 'Live',
                icon: CupertinoIcons.tv_fill,
                color: const Color(0xFF9C27B0),
                onTap: () => pv.sendKey(RemoteKey.source),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AppBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  @override
  State<_AppBtn> createState() => _AppBtnState();
}

class _AppBtnState extends State<_AppBtn> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) {
        setState(() => _p = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _p = false),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _p ? widget.color.withOpacity(0.12) : _L.bg,
              border: Border.all(
                color: _p ? widget.color.withOpacity(0.5) : _L.divider,
                width: 1.5,
              ),
              boxShadow: _p ? [] : _L.cardShadow(),
            ),
            child: Icon(
              widget.icon,
              color: _p ? widget.color : _L.subtitle,
              size: 20,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            widget.label,
            style: TextStyle(
              color: _p ? _L.title : _L.subtitle,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Mode Toggle
// ─────────────────────────────────────────────────────────────────────────────
class _ModeToggle extends StatelessWidget {
  final bool touchpad;
  final ValueChanged<bool> onChange;
  const _ModeToggle({required this.touchpad, required this.onChange});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _L.card,
        borderRadius: BorderRadius.circular(100),
        boxShadow: _L.cardShadow(),
      ),
      child: Row(
        children: [
          _ModeTab(
            icon: CupertinoIcons.circle_grid_3x3_fill,
            label: 'D-Pad',
            active: !touchpad,
            onTap: () => onChange(false),
          ),
          _ModeTab(
            icon: CupertinoIcons.hand_draw_fill,
            label: 'Touchpad',
            active: touchpad,
            onTap: () => onChange(true),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? _L.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? Colors.white : _L.subtitle),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : _L.subtitle,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Volume Pill (left slider)
// ─────────────────────────────────────────────────────────────────────────────
class _VolumePill extends StatelessWidget {
  final TVProvider pv;
  const _VolumePill({required this.pv});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      decoration: BoxDecoration(
        color: _L.card,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _L.accentEdge, width: 1.2),
        boxShadow: _L.cardShadow(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillBtn(
            icon: CupertinoIcons.plus,
            accent: _L.accent,
            onTap: () => pv.sendKey(RemoteKey.volumeUp),
          ),
          const _PillDivider(color: _L.accentEdge),
          _PillBtn(
            icon: CupertinoIcons.speaker_slash_fill,
            accent: _L.accent,
            onTap: () => pv.sendKey(RemoteKey.mute),
          ),
          const _PillDivider(color: _L.accentEdge),
          _PillBtn(
            icon: CupertinoIcons.minus,
            accent: _L.accent,
            onTap: () => pv.sendKey(RemoteKey.volumeDown),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                'VOL',
                style: TextStyle(
                  color: _L.accent.withOpacity(0.5),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Channel Pill (right slider)
// ─────────────────────────────────────────────────────────────────────────────
class _ChannelPill extends StatelessWidget {
  final TVProvider pv;
  const _ChannelPill({required this.pv});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      decoration: BoxDecoration(
        color: _L.card,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _L.amber.withOpacity(0.35), width: 1.2),
        boxShadow: _L.cardShadow(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillBtn(
            icon: CupertinoIcons.chevron_up,
            accent: _L.amber,
            onTap: () => pv.sendKey(RemoteKey.channelUp),
          ),
          _PillDivider(color: _L.amber.withOpacity(0.3)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                'CH',
                style: TextStyle(
                  color: _L.amber.withOpacity(0.5),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          _PillDivider(color: _L.amber.withOpacity(0.3)),
          _PillBtn(
            icon: CupertinoIcons.chevron_down,
            accent: _L.amber,
            onTap: () => pv.sendKey(RemoteKey.channelDown),
          ),
        ],
      ),
    );
  }
}

class _PillBtn extends StatefulWidget {
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  const _PillBtn({
    required this.icon,
    required this.accent,
    required this.onTap,
  });
  @override
  State<_PillBtn> createState() => _PillBtnState();
}

class _PillBtnState extends State<_PillBtn> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) {
        setState(() => _p = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _p ? widget.accent.withOpacity(0.1) : Colors.transparent,
        ),
        child: Icon(
          widget.icon,
          color: _p ? widget.accent : _L.subtitle,
          size: 17,
        ),
      ),
    );
  }
}

class _PillDivider extends StatelessWidget {
  final Color color;
  const _PillDivider({required this.color});
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 12,
      endIndent: 12,
      color: color,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  D-Pad  (clean light circular ring)
// ─────────────────────────────────────────────────────────────────────────────
class _DPad extends StatelessWidget {
  final TVProvider pv;
  const _DPad({required this.pv});
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _L.dpadRing,
          border: Border.all(color: _L.divider, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Cross lines
            CustomPaint(painter: _CrossLinePainter(), size: Size.infinite),

            // Arrows
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: _DPadArrow(
                  icon: CupertinoIcons.chevron_up,
                  onTap: () => pv.sendKey(RemoteKey.up),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: _DPadArrow(
                  icon: CupertinoIcons.chevron_down,
                  onTap: () => pv.sendKey(RemoteKey.down),
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _DPadArrow(
                  icon: CupertinoIcons.chevron_left,
                  onTap: () => pv.sendKey(RemoteKey.left),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _DPadArrow(
                  icon: CupertinoIcons.chevron_right,
                  onTap: () => pv.sendKey(RemoteKey.right),
                ),
              ),
            ),

            // OK button
            _OKButton(onTap: () => pv.sendKey(RemoteKey.enter)),
          ],
        ),
      ),
    );
  }
}

class _CrossLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = _L.divider
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(s.width / 2, 0), Offset(s.width / 2, s.height), p);
    canvas.drawLine(Offset(0, s.height / 2), Offset(s.width, s.height / 2), p);
  }

  @override
  bool shouldRepaint(_CrossLinePainter o) => false;
}

class _DPadArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _DPadArrow({required this.icon, required this.onTap});
  @override
  State<_DPadArrow> createState() => _DPadArrowState();
}

class _DPadArrowState extends State<_DPadArrow> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) {
        setState(() => _p = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _p ? _L.accentLight : Colors.transparent,
        ),
        child: Icon(widget.icon, color: _p ? _L.accent : _L.subtitle, size: 18),
      ),
    );
  }
}

class _OKButton extends StatefulWidget {
  final VoidCallback onTap;
  const _OKButton({required this.onTap});
  @override
  State<_OKButton> createState() => _OKButtonState();
}

class _OKButtonState extends State<_OKButton> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) {
        setState(() => _p = false);
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: _p ? 74 : 80,
        height: _p ? 74 : 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _p ? _L.accentDeep : _L.accent,
          boxShadow: _p
              ? _L.accentShadow()
              : [
                  ..._L.accentShadow(),
                  const BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: const Center(
          child: Text(
            'OK',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TouchPad
// ─────────────────────────────────────────────────────────────────────────────
class _TouchPad extends StatefulWidget {
  final TVProvider pv;
  const _TouchPad({required this.pv});
  @override
  State<_TouchPad> createState() => _TouchPadState();
}

class _TouchPadState extends State<_TouchPad> {
  Offset? _start;
  bool _swiped = false;
  Offset? _touch;
  static const double _kT = 26.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) {
        _start = d.localPosition;
        _swiped = false;
        setState(() => _touch = d.localPosition);
      },
      onPanUpdate: (d) {
        setState(() => _touch = d.localPosition);
        if (_start == null || _swiped) return;
        final dx = d.localPosition.dx - _start!.dx;
        final dy = d.localPosition.dy - _start!.dy;
        if (dx.abs() > _kT || dy.abs() > _kT) {
          _swiped = true;
          HapticFeedback.lightImpact();
          if (dx.abs() > dy.abs()) {
            pv.sendKey(dx > 0 ? RemoteKey.right : RemoteKey.left);
          } else {
            pv.sendKey(dy > 0 ? RemoteKey.down : RemoteKey.up);
          }
          _start = d.localPosition;
          _swiped = false;
        }
      },
      onPanEnd: (_) => setState(() {
        _touch = null;
      }),
      onTap: () {
        HapticFeedback.lightImpact();
        pv.sendKey(RemoteKey.enter);
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _L.dpadRing,
            border: Border.all(color: _L.divider, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_touch != null)
                Positioned(
                  left: _touch!.dx - 22,
                  top: _touch!.dy - 22,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _L.accent.withOpacity(0.12),
                      border: Border.all(color: _L.accentEdge, width: 1),
                    ),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.hand_draw,
                    size: 26,
                    color: _L.subtitle.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Swipe to navigate',
                    style: TextStyle(color: _L.subtitle, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap for OK',
                    style: TextStyle(color: _L.subtitle, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TVProvider get pv => context.read<TVProvider>();
}

// ─────────────────────────────────────────────────────────────────────────────
//  Control Grid
// ─────────────────────────────────────────────────────────────────────────────
class _ControlGrid extends StatelessWidget {
  final TVProvider pv;
  final bool canSource;
  final bool canMenu;
  final Future<void> Function(RemoteKey) onSendKey;
  const _ControlGrid({
    required this.pv,
    required this.onSendKey,
    this.canSource = true,
    this.canMenu = true,
  });

  @override
  Widget build(BuildContext context) {
    return _card(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('CONTROLS'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CtrlBtn(
                icon: CupertinoIcons.house_fill,
                label: 'Home',
                accent: _L.accent,
                onTap: () => onSendKey(RemoteKey.home),
              ),
              _CtrlBtn(
                icon: CupertinoIcons.arrow_uturn_left,
                label: 'Back',
                onTap: () => onSendKey(RemoteKey.back),
              ),
              _CtrlBtn(
                icon: CupertinoIcons.line_horizontal_3,
                label: 'Menu',
                enabled: canMenu,
                onTap: () => onSendKey(RemoteKey.menu),
              ),
              _CtrlBtn(
                icon: CupertinoIcons.arrow_right_arrow_left,
                label: 'Source',
                enabled: canSource,
                onTap: () => onSendKey(RemoteKey.source),
              ),
              _CtrlBtn(
                icon: CupertinoIcons.power,
                label: 'Power',
                accent: _L.red,
                onTap: () => onSendKey(RemoteKey.power),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



class _CtrlBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;
  final bool enabled;
  const _CtrlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = _L.subtitle,
    this.enabled = true,
  });
  @override
  State<_CtrlBtn> createState() => _CtrlBtnState();
}

class _CtrlBtnState extends State<_CtrlBtn> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    // When disabled, ignore taps and render at 35% opacity.
    final effectiveColor = widget.enabled ? widget.accent : _L.divider;
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.35,
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _p = true) : null,
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _p = false);
                HapticFeedback.lightImpact();
                widget.onTap();
              }
            : null,
        onTapCancel: widget.enabled ? () => setState(() => _p = false) : null,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _p ? effectiveColor.withOpacity(0.1) : _L.bg,
                border: Border.all(
                  color: _p ? effectiveColor.withOpacity(0.4) : _L.divider,
                  width: 1.5,
                ),
              ),
              child: Icon(
                widget.icon,
                color: _p ? effectiveColor : _L.subtitle,
                size: 19,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              widget.label,
              style: TextStyle(
                color: _p ? effectiveColor : _L.subtitle,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Playback Bar
// ─────────────────────────────────────────────────────────────────────────────
class _PlaybackBar extends StatelessWidget {
  final TVProvider pv;
  const _PlaybackBar({required this.pv});
  @override
  Widget build(BuildContext context) {
    return _card(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('PLAYBACK'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MediaBtn(
                icon: CupertinoIcons.backward_fill,
                label: 'Rewind',
                onTap: () => pv.sendKey(RemoteKey.rewind),
              ),
              _MediaBtn(
                icon: CupertinoIcons.playpause_fill,
                label: 'Play / Pause',
                accent: true,
                size: 60,
                iconSize: 22,
                onTap: () => pv.sendKey(RemoteKey.play),
              ),
              _MediaBtn(
                icon: CupertinoIcons.forward_fill,
                label: 'Forward',
                onTap: () => pv.sendKey(RemoteKey.fastForward),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;
  final double size;
  final double iconSize;
  const _MediaBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
    this.size = 52,
    this.iconSize = 19,
  });
  @override
  State<_MediaBtn> createState() => _MediaBtnState();
}

class _MediaBtnState extends State<_MediaBtn> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.accent ? _L.accent : _L.subtitle;
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) {
        setState(() => _p = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _p = false),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Accent button gets filled background; others stay hollow.
              color: widget.accent
                  ? (_p ? _L.accentDeep : _L.accent)
                  : (_p ? c.withOpacity(0.1) : _L.bg),
              border: widget.accent
                  ? null
                  : Border.all(
                      color: _p ? c.withOpacity(0.4) : _L.divider,
                      width: 1.5,
                    ),
              boxShadow: widget.accent && !_p
                  ? _L.accentShadow()
                  : _L.cardShadow(),
            ),
            child: Icon(
              widget.icon,
              color: widget.accent ? Colors.white : (_p ? c : _L.subtitle),
              size: widget.iconSize,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            widget.label,
            style: TextStyle(
              color: _p ? c : _L.subtitle,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Number Pad
// ─────────────────────────────────────────────────────────────────────────────
class _NumPad extends StatelessWidget {
  final TVProvider pv;
  const _NumPad({required this.pv});
  static const _keys = [
    RemoteKey.num1,
    RemoteKey.num2,
    RemoteKey.num3,
    RemoteKey.num4,
    RemoteKey.num5,
    RemoteKey.num6,
    RemoteKey.num7,
    RemoteKey.num8,
    RemoteKey.num9,
    RemoteKey.num0,
  ];
  @override
  Widget build(BuildContext context) {
    return _card(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _sectionLabel('NUMBER PAD'),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _keys.map((k) {
              final label = k.name.replaceFirst('num', '');
              return _NumKey(label: label, onTap: () => pv.sendKey(k));
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _NumKey extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NumKey({required this.label, required this.onTap});
  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) {
        setState(() => _p = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 62,
        height: 54,
        decoration: BoxDecoration(
          color: _p ? _L.accentLight : _L.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _p ? _L.accentEdge : _L.divider,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w300,
              color: _p ? _L.accent : _L.title,
            ),
          ),
        ),
      ),
    );
  }

  String get label => widget.label;
}
