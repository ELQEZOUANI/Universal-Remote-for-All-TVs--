import 'dart:async';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/tv_device.dart';

// ═══════════════════════════════════════════════════════════
//  DISCOVERY STATUS — communicates state back to UI
// ═══════════════════════════════════════════════════════════
enum DiscoveryStatus {
  idle,
  requestingPermission,
  triggeringNetwork, // forcing iOS Local Network popup
  scanning,
  probing, // direct IP port‑scan fallback
  permissionDenied,
  networkError,
  finished,
}

// ═══════════════════════════════════════════════════════════
//  NETWORK HELPER — subnet check, Wi‑Fi info, reachability
// ═══════════════════════════════════════════════════════════
class NetworkHelper {
  static final _info = NetworkInfo();

  static Future<String?> getWifiIP() async => await _info.getWifiIP();
  static Future<String?> getWifiSubnetMask() async =>
      await _info.getWifiSubmask();
  static Future<String?> getWifiName() async => await _info.getWifiName();

  /// Bitwise subnet comparison — are [deviceIp] and our phone on the same LAN?
  static Future<bool> isSameSubnet(String deviceIp) async {
    try {
      final myIp = await getWifiIP();
      final mask = await getWifiSubnetMask();
      if (myIp == null || mask == null) return false;

      final my = myIp.split('.').map(int.parse).toList();
      final tv = deviceIp.split('.').map(int.parse).toList();
      final m = mask.split('.').map(int.parse).toList();
      if (my.length != 4 || tv.length != 4 || m.length != 4) return false;

      for (int i = 0; i < 4; i++) {
        if ((my[i] & m[i]) != (tv[i] & m[i])) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// TCP reachability test.
  static Future<bool> isReachable(
    String ip,
    int port, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Extract the subnet prefix from an IP + mask.
  /// e.g. 192.168.1.45 / 255.255.255.0 → "192.168.1."
  static Future<String?> getSubnetPrefix() async {
    final ip = await getWifiIP();
    final mask = await getWifiSubnetMask();
    if (ip == null || mask == null) return null;

    final ipParts = ip.split('.').map(int.parse).toList();
    final maskParts = mask.split('.').map(int.parse).toList();
    if (ipParts.length != 4 || maskParts.length != 4) return null;

    // For /24 (255.255.255.0) this gives "192.168.1."
    final prefix = <String>[];
    for (int i = 0; i < 4; i++) {
      prefix.add('${ipParts[i] & maskParts[i]}');
    }
    // Return "X.X.X." for /24, works for common home networks
    return '${prefix[0]}.${prefix[1]}.${prefix[2]}.';
  }
}

// ═══════════════════════════════════════════════════════════
//  DISCOVERY SERVICE
// ═══════════════════════════════════════════════════════════

/// Discovers smart TVs on the local network via:
///   1. **Network trigger** — a raw socket to force iOS's Local Network popup.
///   2. **Bonjour / mDNS scan** — discovers advertised TV services.
///   3. **Direct IP probe** (fallback) — port‑scans the subnet for known TV
///      ports when mDNS returns nothing (common with Xiaomi TVs).
///
/// ─────────────────────────────────────────────────
/// iOS 14+ LOCAL NETWORK PERMISSION — HOW IT WORKS
/// ─────────────────────────────────────────────────
/// • The "Allow Local Network?" popup is triggered by the **first actual
///   network operation** (not by declaring Info.plist keys alone).
/// • Simply calling `BonsoirDiscovery.start()` counts as a network op.
///   But if that fails silently, we also do an explicit multicast/socket
///   connection in [_triggerLocalNetworkPrompt] as a safety net.
/// • If the user taps "Don't Allow", iOS **never** shows the popup again.
///   The only fix: Settings → Privacy → Local Network → toggle ON.
///   We detect this via a zero‑results timeout → [DiscoveryStatus.permissionDenied].
///
/// ─────────────────────────────────────────────────
/// XIAOMI TV SPECIFICS
/// ─────────────────────────────────────────────────
/// • Xiaomi/Mi TVs use Google Cast (`_googlecast._tcp`) but some models
///   also expose `_ccore._tcp` (Xiaomi cast core) and `_adb._tcp`.
/// • If mDNS doesn't find them, the direct probe scans common ports:
///   8008 (Google Cast HTTP), 8443 (Cast TLS), 5555 (ADB), 6467 (ATV Remote).
class DiscoveryService {
  final List<BonsoirDiscovery> _discoveries = [];
  final Set<String> _seenIps = {};
  Timer? _scanTimer;

  void Function(TVDevice device)? onDeviceFound;
  void Function(DiscoveryStatus status)? onStatusChanged;

  /// All Bonjour service types to scan.
  /// **Every entry MUST appear in Info.plist → NSBonjourServices.**
  static const _serviceTypes = [
    ('_samsung._tcp', TVBrand.samsung, 8001),
    ('_lgatv._tcp', TVBrand.lg, 3000),
    ('_googlecast._tcp', TVBrand.androidTV, 8008),
    ('_androidtvremote._tcp', TVBrand.androidTV, 6467),
    ('_ssdp._tcp', TVBrand.androidTV, 1900),
    ('_dlna._tcp', TVBrand.androidTV, 8200),
    ('_ccore._tcp', TVBrand.androidTV, 8008), // Xiaomi Cast Core
    ('_adb._tcp', TVBrand.androidTV, 5555), // ADB over Wi‑Fi
    ('_roku-remote._tcp', TVBrand.roku, 8060), // Roku ECP
  ];

  static const _probePorts = [
    (8060, TVBrand.roku, 'Roku TV'),
    (8008, TVBrand.androidTV, 'Google Cast / Android TV'),
    (8443, TVBrand.androidTV, 'Google Cast (TLS)'),
    (4567, TVBrand.androidTV, 'Xiaomi Mi TV'),
    (6091, TVBrand.androidTV, 'Xiaomi Mi Remote'),
    (6467, TVBrand.androidTV, 'Android TV Remote'),
    (5555, TVBrand.androidTV, 'ADB Wi-Fi'),
    (8001, TVBrand.samsung, 'Samsung Smart TV'),
    (8002, TVBrand.samsung, 'Samsung Smart TV (WSS)'),
    (3000, TVBrand.lg, 'LG webOS TV'),
  ];

  // ── Main entry point ────────────────────────────────────

  Future<void> startScan({
    Duration timeout = const Duration(seconds: 25),
  }) async {
    _seenIps.clear();

    // Step 1: Request location (for SSID reading, not blocking).
    _emitStatus(DiscoveryStatus.requestingPermission);
    await Permission.locationWhenInUse.request();

    // Step 2: Verify Wi‑Fi connectivity.
    final ip = await NetworkHelper.getWifiIP();
    if (ip == null || ip.isEmpty || ip == '0.0.0.0') {
      _emitStatus(DiscoveryStatus.networkError);
      return;
    }

    // Step 3: Force‑trigger iOS Local Network popup.
    _emitStatus(DiscoveryStatus.triggeringNetwork);
    await _triggerLocalNetworkPrompt(ip);

    // Step 4: Start Bonjour/mDNS AND direct subnet probe in parallel.
    // Xiaomi TVs rarely advertise via mDNS, so we don't wait.
    _emitStatus(DiscoveryStatus.scanning);

    // Start mDNS discovery (async, results stream in)
    for (final (type, brand, defaultPort) in _serviceTypes) {
      await _discover(type, brand, defaultPort);
    }

    // Start direct port probe immediately in background
    _emitStatus(DiscoveryStatus.probing);
    _directSubnetProbe();

    // After timeout, finalize.
    _scanTimer?.cancel();
    _scanTimer = Timer(timeout, () {
      if (_seenIps.isEmpty) {
        _emitStatus(DiscoveryStatus.permissionDenied);
      } else {
        _emitStatus(DiscoveryStatus.finished);
      }
    });
  }

  // ── iOS Local Network Trigger ───────────────────────────
  /// On iOS the "Allow Local Network?" popup ONLY appears when the app makes
  /// its **first real network call** to a local address. Declaring Info.plist
  /// keys alone is NOT enough.
  ///
  /// We do two things:
  ///   a) Try connecting to the router/gateway (x.x.x.1:80) — this is a
  ///      local address and will trigger the popup even if nothing responds.
  ///   b) Send a multicast DNS packet (224.0.0.251:5353).
  ///
  /// Both are fire‑and‑forget; we don't care about the result.
  Future<void> _triggerLocalNetworkPrompt(String myIp) async {
    try {
      // Attempt a) — connect to likely gateway
      final parts = myIp.split('.');
      if (parts.length == 4) {
        final gateway = '${parts[0]}.${parts[1]}.${parts[2]}.1';
        try {
          final s = await Socket.connect(
            gateway,
            80,
            timeout: const Duration(seconds: 1),
          );
          s.destroy();
        } catch (_) {
          // Expected — we just need iOS to see the attempt.
        }
      }

      // Attempt b) — multicast DNS query
      try {
        final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        sock.joinMulticast(InternetAddress('224.0.0.251'));
        sock.send([0, 0, 0, 0], InternetAddress('224.0.0.251'), 5353);
        await Future.delayed(const Duration(milliseconds: 300));
        sock.close();
      } catch (_) {}
    } catch (_) {}

    // Short pause so iOS can process the prompt before we start Bonjour.
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // ── Bonjour / mDNS Discovery ────────────────────────────

  Future<void> _discover(String type, TVBrand brand, int defaultPort) async {
    try {
      final discovery = BonsoirDiscovery(type: type);
      _discoveries.add(discovery);
      await discovery.ready;

      discovery.eventStream?.listen(
        (event) {
          if (event.type ==
              BonsoirDiscoveryEventType.discoveryServiceResolved) {
            final service = event.service as ResolvedBonsoirService;
            final ip = service.host ?? '';
            if (ip.isEmpty || _seenIps.contains('${brand.name}_$ip')) return;
            _seenIps.add('${brand.name}_$ip');

            onDeviceFound?.call(
              TVDevice(
                name: service.name,
                ip: ip,
                port: service.port != 0 ? service.port : defaultPort,
                brand: brand,
              ),
            );
          }
        },
        // ── Catch -65555 (NoAuth) and other Bonsoir stream errors ──────────
        // iOS throws PlatformException(discoveryError, -65555: NoAuth) when:
        //   • Local Network permission was denied by the user, OR
        //   • The app is running in the iOS Simulator (mDNS not supported).
        // We swallow it here so it does NOT surface as an unhandled exception.
        // The direct subnet probe (_directSubnetProbe) will still run as a
        // fallback and can find TVs via TCP port-scanning even without mDNS.
        onError: (Object error) {
          // Intentionally ignored — direct probe is the fallback.
        },
        cancelOnError: false,
      );

      await discovery.start();
    } catch (_) {
      // Individual type failure shouldn't kill the whole scan.
    }
  }

  // ── Direct IP Probe Fallback ────────────────────────────
  /// When mDNS returns nothing (Xiaomi TVs often don't advertise, or
  /// iOS blocked the scan), we port‑scan the local /24 subnet for
  /// known TV ports. This is the "hardcore" fallback.
  Future<void> _directSubnetProbe() async {
    final prefix = await NetworkHelper.getSubnetPrefix();
    if (prefix == null) return;

    // Scan .1 to .254 in parallel batches of 50 to avoid socket exhaustion.
    const batchSize = 50;
    for (int start = 1; start < 255; start += batchSize) {
      final futures = <Future>[];
      for (int i = start; i < start + batchSize && i < 255; i++) {
        final targetIp = '$prefix$i';
        futures.add(_probeHost(targetIp));
      }
      await Future.wait(futures);
    }
  }

  /// Try connecting to each known TV port on [ip].
  Future<void> _probeHost(String ip) async {
    for (final (port, brand, label) in _probePorts) {
      final key = '${brand.name}_$ip';
      if (_seenIps.contains(key)) return; // already found via mDNS

      final reachable = await NetworkHelper.isReachable(
        ip,
        port,
        timeout: const Duration(milliseconds: 600),
      );
      if (reachable && !_seenIps.contains(key)) {
        _seenIps.add(key);
        onDeviceFound?.call(
          TVDevice(name: '$label @ $ip', ip: ip, port: port, brand: brand),
        );
        return; // one hit per IP is enough
      }
    }
  }

  /// Manually probe a specific IP (user‑entered).
  /// Returns the found [TVDevice] or null.
  Future<TVDevice?> probeManualIp(String ip) async {
    for (final (port, brand, label) in _probePorts) {
      final reachable = await NetworkHelper.isReachable(ip, port);
      if (reachable) {
        final device = TVDevice(
          name: '$label @ $ip',
          ip: ip,
          port: port,
          brand: brand,
        );
        final key = '${brand.name}_$ip';
        if (!_seenIps.contains(key)) {
          _seenIps.add(key);
          onDeviceFound?.call(device);
        }
        return device;
      }
    }
    return null;
  }

  // ── Cleanup ─────────────────────────────────────────────

  Future<void> stopScan() async {
    _scanTimer?.cancel();
    for (final d in _discoveries) {
      try {
        await d.stop();
      } catch (_) {}
    }
    _discoveries.clear();
    _seenIps.clear();
    _emitStatus(DiscoveryStatus.idle);
  }

  void _emitStatus(DiscoveryStatus status) {
    onStatusChanged?.call(status);
  }
}
