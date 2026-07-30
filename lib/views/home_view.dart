import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Colors, BoxShadow, Divider, LinearGradient, Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ads/banner_ad_widget.dart';
import '../ads/interstitial_ad_manager.dart';
import '../providers/tv_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../remote_engine.dart';

import '../widgets/premium_widgets.dart';
import 'remote_view.dart';

void _startScanWithAd(BuildContext context, TVProvider pv) {
  final interstitialAdManager = context.read<InterstitialAdManager>();
  interstitialAdManager.showAdThen(
    onAdDismissed: () {
      pv.startScan();
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Design-token helpers (theme-aware)
// ─────────────────────────────────────────────────────────────────────────────
class _T {
  _T._();

  // ── Backgrounds ──
  static Color bg(bool d) => d ? AppTheme.deepBg : AppTheme.lightBg;
  static Color card(bool d) => d ? AppTheme.charcoal : AppTheme.lightCard;
  static Color divider(bool d) =>
      d ? const Color(0xFF1C3628) : AppTheme.lightDivider;

  // ── Text ──
  static Color title(bool d) => d ? AppTheme.white : AppTheme.lightTitle;
  static Color sub(bool d) => d ? AppTheme.grey : AppTheme.lightSub;

  // ── Brand ──
  static Color accent(bool d) => d ? AppTheme.emerald : AppTheme.lightAccent;
  static Color accentDeep(bool d) => d ? AppTheme.teal : AppTheme.lightAccentD;
  static Color accentBg(bool d) =>
      d ? AppTheme.emerald.withOpacity(0.12) : AppTheme.lightAccentBg;
  static Color accentBorder(bool d) =>
      d ? AppTheme.emerald.withOpacity(0.25) : const Color(0xFFB2DFDB);
  static Color inputBg(bool d) =>
      d ? AppTheme.surface : const Color(0xFFF7F9FC);

  static List<BoxShadow> cardShadow(bool d) =>
      d ? AppTheme.darkCardShadow() : AppTheme.cardShadow();
  static List<BoxShadow> luxuryShadow(bool d) =>
      d ? AppTheme.glowShadow() : AppTheme.luxuryShadow();
}

// ─────────────────────────────────────────────────────────────────────────────
//  HomeView
// ─────────────────────────────────────────────────────────────────────────────
class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with SingleTickerProviderStateMixin {
  int _navIndex = 0;
  late AnimationController _radarCtrl;

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _radarCtrl.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pv = context.watch<TVProvider>();
    final isDark = context.watch<ThemeProvider>().isDark;

    return CupertinoPageScaffold(
      backgroundColor: _T.bg(isDark),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Remote wallpaper background ───────────────────────────────────
          Image.asset('assets/images/remote_wallpaper.png', fit: BoxFit.cover),
          // ── Theme-aware scrim — light enough to see the remote ───────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [
                        Color(0x8C050D0A), // 55% top
                        Color(0x4D050D0A), // 30% mid — remote most visible
                        Color(0xCC050D0A), // 80% bottom — nav bar area
                      ]
                    : const [
                        Color(0xC8F0F7F4),
                        Color(0x90F0F7F4),
                        Color(0xDDF0F7F4),
                      ],
              ),
            ),
          ),
          // ── Ambient radial glow (dark mode only) ──────────────────────────
          if (isDark)
            Positioned(
              top: -120,
              left: -80,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.emerald.withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _PremiumTopBar(isDark: isDark, pv: pv),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 185),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.03),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_navIndex),
                        child: _navIndex == 1
                            ? _RecentView(pv: pv, isDark: isDark)
                            : _navIndex == 2
                            ? _SettingsView(isDark: isDark)
                            : _DeviceSection(
                                pv: pv,
                                radarCtrl: _radarCtrl,
                                isDark: isDark,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Floating Bottom Nav ───────────────────────────────────────────
          Positioned(
            left: 20,
            right: 20,
            bottom: 105,
            child: PremiumBottomNav(
              index: _navIndex,
              isDark: isDark,
              onTap: (i) {
                if (i == 2 && _navIndex != 2) {
                  context.read<InterstitialAdManager>().showAdThen(
                    onAdDismissed: () {
                      setState(() => _navIndex = i);
                    },
                  );
                } else {
                  setState(() => _navIndex = i);
                }
              },
            ),
          ),

          // ── Banner Ad (Below Navbar at Bottom) ─────────────────────────────
          const Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: SafeArea(
              top: false,
              child: Center(child: BannerAdWidget()),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Premium Top Bar
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumTopBar extends StatelessWidget {
  final bool isDark;
  final TVProvider pv;

  const _PremiumTopBar({required this.isDark, required this.pv});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: Row(
        children: [
          // Logo mark + wordmark
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              boxShadow: AppTheme.glowShadow(intensity: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/images/icon.png', fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Uni TV Remote+',
                  style: TextStyle(
                    color: _T.title(isDark),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Universal Control',
                  style: TextStyle(
                    color: _T.sub(isDark),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          GlowIconButton(
            icon: CupertinoIcons.tv_music_note,
            isDark: isDark,
            accent: true,
            onTap: () {
              if (pv.activeDevice != null && pv.isConnected) {
                Navigator.of(
                  context,
                ).push(CupertinoPageRoute(builder: (_) => const RemoteView()));
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Device Section  (Scan card + device list)
// ─────────────────────────────────────────────────────────────────────────────
class _DeviceSection extends StatelessWidget {
  final TVProvider pv;
  final AnimationController radarCtrl;
  final bool isDark;

  const _DeviceSection({
    required this.pv,
    required this.radarCtrl,
    required this.isDark,
  });

  void _showPairDialog(BuildContext ctx, TVDevice device) {
    showCupertinoDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _PairingDialog(device: device, isDark: isDark),
    );
  }

  void _showManualDialog(BuildContext ctx) {
    String ip = '';
    showCupertinoDialog(
      context: ctx,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Manual IP'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              const Text(
                "Enter the TV's local IP address.",
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                autofocus: true,
                keyboardType: TextInputType.url,
                placeholder: '192.168.1.x',
                onChanged: (v) => ip = v,
                decoration: BoxDecoration(
                  color: _T.inputBg(isDark),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _T.divider(isDark)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Connect'),
            onPressed: () {
              ctx.read<TVProvider>().probeManualIp(ip);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Section header ────────────────────────────────────────────────
        _SectionHeader(
          label: 'AVAILABLE DEVICES',
          isDark: isDark,
          trailing: pv.scanning
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoActivityIndicator(
                      color: _T.accent(isDark),
                      radius: 7,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Scanning',
                      style: TextStyle(
                        color: _T.accent(isDark).withOpacity(0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : PremiumTap(
                  onTap: () => _startScanWithAd(context, pv),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.refresh,
                        size: 13,
                        color: _T.accent(isDark),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Rescan',
                        style: TextStyle(
                          color: _T.accent(isDark),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        // ── Connecting banner ─────────────────────────────────────────────
        if (pv.isConnecting) _ConnectingBanner(isDark: isDark),

        const SizedBox(height: 4),

        if (pv.devices.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Scan / Radar CTA ────────────────────────────────
              ScanDeviceCard(
                scanning: pv.scanning,
                isDark: isDark,
                radarCtrl: radarCtrl,
                onTap: () => _startScanWithAd(context, pv),
              ),

              const SizedBox(height: 20),

              // ── Quick Tips ─────────────────────────────────────
              _QuickTipsCard(isDark: isDark),
            ],
          )
        else
          // ── Device list ───────────────────────────────────────────────
          _DeviceListCard(
            pv: pv,
            isDark: isDark,
            onDeviceTap: (dev) => _showPairDialog(context, dev),
            onManual: () => _showManualDialog(context),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section header strip
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isDark;
  final Widget? trailing;

  const _SectionHeader({
    required this.label,
    required this.isDark,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_T.accent(isDark), _T.accentDeep(isDark)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: _T.sub(isDark),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Connecting Banner
// ─────────────────────────────────────────────────────────────────────────────
class _ConnectingBanner extends StatelessWidget {
  final bool isDark;
  const _ConnectingBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_T.accent(isDark), _T.accentDeep(isDark)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.glowShadow(intensity: 0.8),
      ),
      child: const Row(
        children: [
          CupertinoActivityIndicator(color: Colors.white, radius: 9),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connecting to TV…',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Accept the pairing prompt on your TV screen.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Quick Tips Card
// ─────────────────────────────────────────────────────────────────────────────
class _QuickTipsCard extends StatelessWidget {
  final bool isDark;
  const _QuickTipsCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: _T.card(isDark),
        borderRadius: BorderRadius.circular(24),
        border: isDark
            ? Border.all(color: const Color(0xFF1C3628), width: 0.8)
            : null,
        boxShadow: _T.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK TIPS',
            style: TextStyle(
              color: _T.sub(isDark),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ScanTip(
            icon: Icons.wifi,
            iconColor: _T.accent(isDark),
            title: 'Same Wi-Fi Network',
            subtitle: 'Ensure phone and TV are on the same Wi-Fi.',
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          ScanTip(
            icon: Icons.tv,
            iconColor: const Color(0xFF5B6AF0),
            title: 'Turn on your TV',
            subtitle: 'Make sure the TV is fully powered on, not in standby.',
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          ScanTip(
            icon: Icons.security,
            iconColor: const Color(0xFFFFAB00),
            title: 'Disable VPN',
            subtitle: 'Turn off any active VPNs on your device.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Device List Card
// ─────────────────────────────────────────────────────────────────────────────
class _DeviceListCard extends StatelessWidget {
  final TVProvider pv;
  final bool isDark;
  final void Function(TVDevice) onDeviceTap;
  final VoidCallback onManual;

  const _DeviceListCard({
    required this.pv,
    required this.isDark,
    required this.onDeviceTap,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.card(isDark),
        borderRadius: BorderRadius.circular(28),
        border: isDark
            ? Border.all(color: const Color(0xFF1C3628), width: 0.8)
            : null,
        boxShadow: _T.luxuryShadow(isDark),
      ),
      child: Column(
        children: [
          ...pv.devices.asMap().entries.map((e) {
            final i = e.key;
            final dev = e.value;
            final active = pv.activeDevice?.ip == dev.ip;
            return Column(
              children: [
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(height: 1, color: _T.divider(isDark)),
                  ),
                _DeviceRow(
                  device: dev,
                  active: active,
                  connected: active && pv.isConnected,
                  isDark: isDark,
                  onTap: () => onDeviceTap(dev),
                  onWake: () => pv.wakeDevice(dev),
                ),
              ],
            );
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1, color: _T.divider(isDark)),
          ),
          PremiumTap(
            onTap: onManual,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _T.accentBg(isDark),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: _T.accentBorder(isDark)),
                    ),
                    child: Icon(
                      CupertinoIcons.add,
                      color: _T.accent(isDark),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add device manually',
                          style: TextStyle(
                            color: _T.accent(isDark),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Enter IP address',
                          style: TextStyle(color: _T.sub(isDark), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: _T.accentBorder(isDark),
                    size: 15,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1, color: _T.divider(isDark)),
          ),
          PremiumTap(
            onTap: () => _startScanWithAd(context, pv),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _T.accentBg(isDark),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: _T.accentBorder(isDark)),
                    ),
                    child: Icon(
                      CupertinoIcons.search,
                      color: _T.accent(isDark),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search again for devices',
                          style: TextStyle(
                            color: _T.accent(isDark),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rescan Wi-Fi network for TVs',
                          style: TextStyle(color: _T.sub(isDark), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: _T.accentBorder(isDark),
                    size: 15,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Device Row
// ─────────────────────────────────────────────────────────────────────────────
class _DeviceRow extends StatefulWidget {
  final TVDevice device;
  final bool active, connected, isDark;
  final VoidCallback onTap, onWake;

  const _DeviceRow({
    required this.device,
    required this.active,
    required this.connected,
    required this.isDark,
    required this.onTap,
    required this.onWake,
  });

  @override
  State<_DeviceRow> createState() => _DeviceRowState();
}

class _DeviceRowState extends State<_DeviceRow> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.isDark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) {
        setState(() => _p = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: _p
              ? _T.accentBg(d)
              : widget.active
              ? _T.accentBg(d)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: widget.active
              ? Border.all(color: _T.accentBorder(d), width: 1.2)
              : null,
        ),
        child: Row(
          children: [
            // TV icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: widget.active
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_T.accent(d), _T.accentDeep(d)],
                      )
                    : null,
                color: widget.active ? null : _T.bg(d),
                borderRadius: BorderRadius.circular(18),
                boxShadow: widget.active
                    ? [
                        BoxShadow(
                          color: _T.accent(d).withOpacity(0.30),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                CupertinoIcons.tv_fill,
                color: widget.active ? Colors.white : _T.sub(d),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.device.name,
                    style: TextStyle(
                      color: widget.active ? _T.accent(d) : _T.title(d),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: widget.connected
                              ? AppTheme.connected
                              : _T.divider(d),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.connected ? 'Connected' : widget.device.ip,
                        style: TextStyle(
                          color: widget.connected
                              ? AppTheme.connected
                              : _T.sub(d),
                          fontSize: 12,
                          fontWeight: widget.connected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.connected)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_T.accent(d), _T.accentDeep(d)],
                  ),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: AppTheme.glowShadow(intensity: 0.5),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: widget.onWake,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _T.bg(d),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: _T.divider(d)),
                  ),
                  child: Icon(
                    CupertinoIcons.bolt_fill,
                    color: _T.sub(d),
                    size: 16,
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
//  Pairing Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _PairingDialog extends StatefulWidget {
  final TVDevice device;
  final bool isDark;
  const _PairingDialog({required this.device, required this.isDark});

  @override
  State<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<_PairingDialog> {
  String _phase = 'confirm';
  String _code = '';

  Future<void> _startConnect() async {
    setState(() => _phase = 'connecting');
    final pv = context.read<TVProvider>();
    pv.prepareService(widget.device);

    if (pv.needsPairing) {
      final ok = await pv.startPairing(widget.device);
      if (!mounted) return;
      if (ok) {
        setState(() => _phase = 'entering_code');
      } else {
        setState(() => _phase = 'error');
      }
      return;
    }

    final ok = await pv.connectTo(widget.device);
    if (!mounted) return;
    setState(() => _phase = ok ? 'success' : 'error');
  }

  Future<void> _submitCode() async {
    if (_code.isEmpty) return;
    setState(() => _phase = 'connecting');
    final pv = context.read<TVProvider>();
    final ok = await pv.submitPairingCode(_code);
    if (!mounted) return;

    if (ok) {
      // Token saved, now actually connect on the normal port
      final connected = await pv.connectTo(widget.device);
      if (!mounted) return;
      setState(() => _phase = connected ? 'success' : 'error');
    } else {
      setState(() => _phase = 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(_title()),
      content: Padding(padding: const EdgeInsets.only(top: 12), child: _body()),
      actions: _actions(),
    );
  }

  String _title() {
    switch (_phase) {
      case 'connecting':
        return 'Pairing…';
      case 'entering_code':
        return 'Enter Code';
      case 'success':
        return 'Connected!';
      case 'error':
        return 'Connection Failed';
      default:
        return 'Connect to TV';
    }
  }

  Widget _body() {
    switch (_phase) {
      case 'connecting':
        return const Column(
          children: [
            CupertinoActivityIndicator(radius: 14),
            SizedBox(height: 12),
            Text(
              'Connecting to your TV…',
              style: TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        );
      case 'entering_code':
        return Column(
          children: [
            const Text(
              'Please enter the code shown on your TV screen.',
              style: TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CupertinoTextField(
              autofocus: true,
              keyboardType: TextInputType.visiblePassword,
              placeholder: 'Enter code',
              textAlign: TextAlign.center,
              onChanged: (v) => _code = v,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black,
                fontSize: 20,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      case 'success':
        return Text(
          '"${widget.device.name}" is ready to control.',
          style: const TextStyle(fontSize: 13),
          textAlign: TextAlign.center,
        );
      case 'error':
        return Column(
          children: [
            Text(
              'Could not connect to "${widget.device.name}".',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Please check the following:\n'
                '• TV is turned on and not in standby\n'
                '• Devices are on the same Wi-Fi\n'
                '• Accepted pairing prompt on TV\n'
                '• VPN is disabled on this device',
                style: TextStyle(fontSize: 13, height: 1.4),
                textAlign: TextAlign.left,
              ),
            ),
          ],
        );
      default:
        return Text(
          'Your TV will show a pairing prompt.\nPlease accept it on "${widget.device.name}".',
          style: const TextStyle(fontSize: 13),
          textAlign: TextAlign.center,
        );
    }
  }

  List<CupertinoDialogAction> _actions() {
    if (_phase == 'connecting') return [];
    if (_phase == 'entering_code') {
      return [
        CupertinoDialogAction(
          isDestructiveAction: true,
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _submitCode,
          child: const Text('Submit'),
        ),
      ];
    }
    if (_phase == 'success') {
      return [
        CupertinoDialogAction(
          isDefaultAction: true,
          child: const Text('Open Remote'),
          onPressed: () {
            Navigator.pop(context);
            Navigator.of(
              context,
            ).push(CupertinoPageRoute(builder: (_) => const RemoteView()));
          },
        ),
      ];
    }
    if (_phase == 'error') {
      return [
        CupertinoDialogAction(
          isDestructiveAction: true,
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _startConnect,
          child: const Text('Try Again'),
        ),
      ];
    }
    return [
      CupertinoDialogAction(
        isDestructiveAction: true,
        child: const Text('Cancel'),
        onPressed: () => Navigator.pop(context),
      ),
      CupertinoDialogAction(
        isDefaultAction: true,
        onPressed: _startConnect,
        child: const Text('Connect'),
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Recent Devices View
// ─────────────────────────────────────────────────────────────────────────────
class _RecentView extends StatelessWidget {
  final TVProvider pv;
  final bool isDark;
  const _RecentView({required this.pv, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final recent = pv.recentDevices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(label: 'RECENTLY CONNECTED', isDark: isDark),
        if (recent.isEmpty)
          // ── Premium empty state ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            decoration: BoxDecoration(
              color: _T.card(isDark),
              borderRadius: BorderRadius.circular(28),
              border: isDark
                  ? Border.all(color: const Color(0xFF1C3628), width: 0.8)
                  : null,
              boxShadow: _T.cardShadow(isDark),
            ),
            child: EmptyRecentState(isDark: isDark),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: _T.card(isDark),
              borderRadius: BorderRadius.circular(28),
              border: isDark
                  ? Border.all(color: const Color(0xFF1C3628), width: 0.8)
                  : null,
              boxShadow: _T.cardShadow(isDark),
            ),
            child: Column(
              children: [
                ...recent.asMap().entries.map((e) {
                  final i = e.key;
                  final dev = e.value;
                  final isActive = pv.activeDevice?.ip == dev.ip;
                  return Column(
                    children: [
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Divider(height: 1, color: _T.divider(isDark)),
                        ),
                      PremiumTap(
                        onTap: () {
                          showCupertinoDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) =>
                                _PairingDialog(device: dev, isDark: isDark),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: isActive
                                      ? LinearGradient(
                                          colors: [
                                            _T.accent(isDark),
                                            _T.accentDeep(isDark),
                                          ],
                                        )
                                      : null,
                                  color: isActive ? null : _T.bg(isDark),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: isActive
                                      ? AppTheme.glowShadow(intensity: 0.5)
                                      : null,
                                ),
                                child: Icon(
                                  CupertinoIcons.tv_fill,
                                  color: isActive
                                      ? Colors.white
                                      : _T.sub(isDark),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dev.name,
                                      style: TextStyle(
                                        color: _T.title(isDark),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      dev.ip,
                                      style: TextStyle(
                                        color: _T.sub(isDark),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isActive && pv.isConnected)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _T.accentBg(isDark),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: _T.accentBorder(isDark),
                                    ),
                                  ),
                                  child: Text(
                                    'Active',
                                    style: TextStyle(
                                      color: _T.accent(isDark),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  CupertinoIcons.chevron_right,
                                  color: _T.divider(isDark),
                                  size: 15,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Settings View
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsView extends StatelessWidget {
  final bool isDark;
  const _SettingsView({required this.isDark});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Premium branding header card ────────────────────────────────
        _BrandingHeader(isDark: isDark),
        const SizedBox(height: 28),

        // ── Support section ─────────────────────────────────────────────
        _SectionHeader(label: 'SUPPORT', isDark: isDark),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.05,
          padding: EdgeInsets.zero,
          children: [
            PremiumSquareTile(
              icon: CupertinoIcons.star_fill,
              iconColor: const Color(0xFFFFB800),
              iconBg: isDark
                  ? const Color(0xFFFFB800).withOpacity(0.14)
                  : const Color(0xFFFFF8E1),
              title: 'Rate the App',
              subtitle: 'Enjoying it? Leave a review!',
              isDark: isDark,
              onTap: () => _launch(
                'https://apps.apple.com/app/id6796001501?action=write-review',
              ),
            ),
            PremiumSquareTile(
              icon: CupertinoIcons.share_solid,
              iconColor: const Color(0xFF7B8FFF),
              iconBg: isDark
                  ? const Color(0xFF7B8FFF).withOpacity(0.14)
                  : const Color(0xFFEEF0FD),
              title: 'Share with Friends',
              subtitle: 'Spread the word',
              isDark: isDark,
              onTap: () => _launch('https://apps.apple.com/app/id6796001501'),
            ),
            PremiumSquareTile(
              icon: CupertinoIcons.envelope_fill,
              iconColor: _T.accent(isDark),
              iconBg: _T.accentBg(isDark),
              title: 'Contact Us',
              subtitle: 'Get help or send feedback',
              isDark: isDark,
              onTap: () => _launch('mailto:azoworkspace@gmail.com'),
            ),
            PremiumSquareTile(
              icon: CupertinoIcons.doc_text_fill,
              iconColor: isDark
                  ? const Color(0xFFA0A9C0)
                  : const Color(0xFF8E8E93),
              iconBg: isDark
                  ? const Color(0xFF1C3628)
                  : const Color(0xFFF2F2F7),
              title: 'Privacy Policy',
              subtitle: 'Terms of use and privacy information',
              isDark: isDark,
              onTap: () => _launch(
                'https://universalremoteforalltvs.blogspot.com/2026/07/universal-remote-for-all-tvs.html',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Branding Header (Settings top)
// ─────────────────────────────────────────────────────────────────────────────
class _BrandingHeader extends StatelessWidget {
  final bool isDark;
  const _BrandingHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? AppTheme.emerald.withOpacity(0.18)
                  : AppTheme.lightAccent.withOpacity(0.20),
              width: 0.8,
            ),
            boxShadow: _T.cardShadow(isDark),
          ),
          child: Column(
            children: [
              // Glowing icon
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.glowShadow(intensity: 0.8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/images/icon.png', fit: BoxFit.cover),
              ),
              const SizedBox(height: 14),
              Text(
                'Uni TV Remote+',
                style: TextStyle(
                  color: _T.title(isDark),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _T.accentBg(isDark),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: _T.accentBorder(isDark)),
                ),
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: _T.accent(isDark),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
