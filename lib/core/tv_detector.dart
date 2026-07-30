import 'dart:io';
import 'package:http/http.dart' as http;
import 'tv_brand.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TV Detector — Port-Sniffing Fingerprinter
//
//  Identifies the brand of a TV at a given IP by probing well-known TCP ports
//  that each platform's remote-control server listens on.
//
//  Each probe uses an 800 ms timeout to keep the overall scan fast.
//  Probes run in parallel where possible and the first match wins.
// ─────────────────────────────────────────────────────────────────────────────

class TVDetector {
  static const Duration _timeout = Duration(milliseconds: 800);

  /// Identifies the TV brand at [ip] by sniffing open ports.
  ///
  /// Port map:
  ///   LG WebOS   → 3000
  ///   Samsung    → 8001 or 8002
  ///   Android TV → 6466, 8008, or 5555
  ///   Roku       → 8060 (ECP)
  ///
  /// Returns [TVBrand.unknown] if no known port responds.
  Future<TVBrand> identifyTV(String ip) async {
    // Run all brand checks concurrently; first resolved brand wins.
    final results = await Future.wait([
      _checkLG(ip),
      _checkSamsung(ip),
      _checkAndroidTV(ip),
      _checkRoku(ip),
    ]);

    for (final brand in results) {
      if (brand != TVBrand.unknown) return brand;
    }
    return TVBrand.unknown;
  }

  // ── Brand-specific probes ─────────────────────────────────────────────────

  Future<TVBrand> _checkLG(String ip) async {
    final open = await _isPortOpen(ip, 3000);
    return open ? TVBrand.lg : TVBrand.unknown;
  }

  Future<TVBrand> _checkSamsung(String ip) async {
    // Samsung uses either port 8001 (plain) or 8002 (TLS).
    final results = await Future.wait([
      _isPortOpen(ip, 8001),
      _isPortOpen(ip, 8002),
    ]);
    return results.any((r) => r) ? TVBrand.samsung : TVBrand.unknown;
  }

  Future<TVBrand> _checkAndroidTV(String ip) async {
    // Android TV remote port (6466), Chromecast (8008), ADB (5555).
    final results = await Future.wait([
      _isPortOpen(ip, 6466),
      _isPortOpen(ip, 8008),
      _isPortOpen(ip, 5555),
    ]);
    return results.any((r) => r) ? TVBrand.androidTv : TVBrand.unknown;
  }

  /// Checks for a Roku device via ECP (External Control Protocol) on port 8060.
  ///
  /// Strategy:
  ///   1. Quick TCP probe on port 8060.
  ///   2. If the port is open, fire an HTTP GET to http://<ip>:8060/ and confirm
  ///      the response body contains the Roku device-info XML marker so we don't
  ///      mis-classify other devices that happen to listen on port 8060.
  Future<TVBrand> _checkRoku(String ip) async {
    final portOpen = await _isPortOpen(ip, 8060);
    if (!portOpen) return TVBrand.unknown;

    try {
      final uri = Uri.parse('http://$ip:8060/');
      final response = await http.get(uri).timeout(_timeout);

      // Roku ECP root returns a 200 with an XML body that includes
      // "<root" or references "roku". Accept either 200 or 301 redirects
      // that routers might produce, but require the Roku XML marker.
      if (response.statusCode == 200) {
        final body = response.body.toLowerCase();
        if (body.contains('roku') || body.contains('<root')) {
          return TVBrand.roku;
        }
      }
    } catch (_) {
      // HTTP failed even though TCP succeeded — not a Roku ECP server.
    }

    return TVBrand.unknown;
  }

  // ── Low-level probe ───────────────────────────────────────────────────────

  /// Attempts a TCP connection to [ip]:[port] within [_timeout].
  /// Returns true if the port is open (connection accepted), false otherwise.
  Future<bool> _isPortOpen(String ip, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: _timeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }
}
