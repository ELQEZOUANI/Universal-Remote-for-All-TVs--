import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../remote_engine.dart';

/// Central state manager (ChangeNotifier for Provider).
///
/// Responsibilities:
///   • Drives mDNS discovery and collects found TVs.
///   • Manages the "active" TV and its protocol service.
///   • Persists pairing tokens so the user doesn't re‑pair every launch.
///   • Exposes [discoveryStatus] so the UI can react to permission / network issues.
class TVProvider extends ChangeNotifier {
  final DiscoveryService _discovery = DiscoveryService();
  final List<TVDevice> _devices = [];
  TVDevice? _activeDevice;
  TVService? _activeService;
  bool _scanning = false;
  bool _scanTimedOut = false;
  bool _isConnecting = false;
  Timer? _scanTimer;
  DiscoveryStatus _discoveryStatus = DiscoveryStatus.idle;
  String? _wifiName;
  String? _localIp;

  // ── Getters ──────────────────────────────────────────────
  List<TVDevice> get devices => List.unmodifiable(_devices);
  TVDevice? get activeDevice => _activeDevice;
  TVService? get activeService => _activeService;
  bool get scanning => _scanning;
  bool get scanTimedOut => _scanTimedOut;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _activeService?.isConnected ?? false;
  DiscoveryStatus get discoveryStatus => _discoveryStatus;
  String? get wifiName => _wifiName;
  String? get localIp => _localIp;

  // ── Capability / Feature-Flag getters ────────────────────
  // These proxy directly to the active service so the UI only
  // needs to watch TVProvider — no direct service access required.
  bool get supportsAppLaunching =>
      _activeService?.supportsAppLaunching ?? false;
  bool get supportsSourceControl =>
      _activeService?.supportsSourceControl ?? false;
  bool get supportsMenuNavigation =>
      _activeService?.supportsMenuNavigation ?? false;

  // ── Discovery ────────────────────────────────────────────
  Future<void> startScan() async {
    _scanning = true;
    _scanTimedOut = false;
    _devices.clear();
    _discoveryStatus = DiscoveryStatus.idle;
    notifyListeners();

    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 6), () {
      if (_devices.isEmpty) {
        _scanTimedOut = true;
        _scanning = false;
        notifyListeners();
      }
    });

    await _loadSavedTokens();

    // Grab Wi‑Fi info for UI display.
    _localIp = await NetworkHelper.getWifiIP();
    _wifiName = await NetworkHelper.getWifiName();

    _discovery.onDeviceFound = (device) {
      // Restore previously saved token if available.
      final existing = _savedTokens[device.id];
      if (existing != null) device.pairingToken = existing;

      _devices.add(device);
      notifyListeners();
    };

    _discovery.onStatusChanged = (status) {
      _discoveryStatus = status;
      if (status == DiscoveryStatus.finished ||
          status == DiscoveryStatus.permissionDenied ||
          status == DiscoveryStatus.networkError) {
        _scanning = false;
      }
      notifyListeners();
    };

    await _discovery.startScan();
  }

  Future<void> stopScan() async {
    await _discovery.stopScan();
    _scanning = false;
    notifyListeners();
  }

  /// Check if a specific TV IP is on the same subnet as this phone.
  Future<bool> isOnSameSubnet(String tvIp) async {
    return NetworkHelper.isSameSubnet(tvIp);
  }

  /// Manually probe a user‑entered IP address for TV services.
  /// Returns true if a TV was found.
  Future<bool> probeManualIp(String ip) async {
    final device = await _discovery.probeManualIp(ip);
    if (device != null) {
      final existing = _savedTokens[device.id];
      if (existing != null) device.pairingToken = existing;
      // Avoid duplicates
      if (!_devices.any((d) => d.id == device.id)) {
        _devices.add(device);
        notifyListeners();
      }
      return true;
    }
    return false;
  }

  // ── Connection ───────────────────────────────────────────

  /// Set up the service for [device] without attempting to connect.
  void prepareService(TVDevice device) {
    _activeDevice = device;
    _activeService = _createService(device);
    _activeService!.onConnectionStateChanged = () => notifyListeners();
    _addToRecent(device);
    notifyListeners();
  }

  Future<bool> connectTo(TVDevice device) async {
    // Disconnect previous if any.
    await _activeService?.disconnect();

    _activeDevice = device;
    _activeService = _createService(device);

    // ── Key fix: when the service's connection state changes asynchronously
    // (e.g. XiaomiService completes its 2-step handshake AFTER connect()
    // returns), notify all listeners so the UI re-evaluates isConnected.
    _activeService!.onConnectionStateChanged = () {
      notifyListeners();
    };

    _isConnecting = true;
    notifyListeners();

    final ok = await _activeService!.connect();
    _isConnecting = false;
    if (ok) {
      await _saveToken(device);
      _addToRecent(device);
    }
    notifyListeners();
    return ok;
  }

  bool get needsPairing => _activeService?.needsPairing ?? false;

  Future<bool> startPairing(TVDevice device) async {
    // Disconnect previous if any.
    await _activeService?.disconnect();

    _activeDevice = device;
    _activeService = _createService(device);
    _activeService!.onConnectionStateChanged = () => notifyListeners();
    
    _isConnecting = true;
    notifyListeners();

    final ok = await _activeService!.startPairing();
    _isConnecting = false;
    notifyListeners();
    return ok;
  }

  Future<bool> submitPairingCode(String code) async {
    if (_activeService == null) return false;
    
    _isConnecting = true;
    notifyListeners();

    final ok = await _activeService!.submitPairingCode(code);
    _isConnecting = false;
    if (ok && _activeDevice != null) {
      await _saveToken(_activeDevice!);
      _addToRecent(_activeDevice!);
    }
    notifyListeners();
    return ok;
  }

  Future<void> disconnectCurrent() async {
    await _activeService?.disconnect();
    _activeService = null;
    _activeDevice = null;
    notifyListeners();
  }

  Future<bool> sendKey(RemoteKey key) async {
    if (_activeService == null || !isConnected) return false;
    await _activeService!.sendKey(key);
    return true;
  }

  /// Send a raw keycode (Android TV only). Returns false if not connected.
  Future<bool> sendRawKeyCode(int keyCode) async {
    if (_activeService == null || !isConnected) return false;
    await _activeService!.sendRawKeyCode(keyCode);
    return true;
  }

  /// Launch an app or intent via URL (Android TV only). Returns false if not connected.
  Future<bool> launchAppLink(String url) async {
    if (_activeService == null || !isConnected) return false;
    await _activeService!.launchAppLink(url);
    return true;
  }

  /// Power‑on via Wake‑on‑LAN (requires stored MAC address).
  Future<void> wakeDevice(TVDevice device) async {
    if (device.macAddress != null) {
      await WolService.wake(device.macAddress!);
    }
  }

  // ── Factory ──────────────────────────────────────────────
  TVService _createService(TVDevice device) {
    switch (device.brand) {
      case TVBrand.samsung:
        return SamsungService(device);
      case TVBrand.lg:
        return LGService(device);
      case TVBrand.androidTV:
        return XiaomiService(device); // Works for Xiaomi + generic Android TVs
      case TVBrand.roku:
        return RokuService(device);
      case TVBrand.unknown:
        return XiaomiService(device); // fallback — try ADB/HTTP
    }
  }

  // ── Persistence ──────────────────────────────────────────
  Map<String, String> _savedTokens = {};
  List<TVDevice> _recentDevices = [];

  List<TVDevice> get recentDevices => List.unmodifiable(_recentDevices);

  void _addToRecent(TVDevice device) {
    _recentDevices.removeWhere((d) => d.ip == device.ip);
    _recentDevices.insert(0, device);
    if (_recentDevices.length > 10) {
      _recentDevices = _recentDevices.sublist(0, 10);
    }
    _saveRecent();
    notifyListeners();
  }

  Future<void> _loadSavedTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tv_tokens');
    if (raw != null) {
      _savedTokens = Map<String, String>.from(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    }
    await _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tv_recent');
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _recentDevices = list.map((e) {
        final m = e as Map<String, dynamic>;
        return TVDevice(
          name: m['name'] as String,
          ip: m['ip'] as String,
          port: (m['port'] as int?) ?? 6466,
          brand: TVBrand.values.firstWhere(
            (b) => b.name == (m['brand'] as String? ?? 'unknown'),
            orElse: () => TVBrand.unknown,
          ),
        );
      }).toList();
    }
  }

  Future<void> _saveRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _recentDevices
        .map(
          (d) => {
            'name': d.name,
            'ip': d.ip,
            'port': d.port,
            'brand': d.brand.name,
          },
        )
        .toList();
    await prefs.setString('tv_recent', jsonEncode(list));
  }

  Future<void> _saveToken(TVDevice device) async {
    if (device.pairingToken == null) return;
    _savedTokens[device.id] = device.pairingToken!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tv_tokens', jsonEncode(_savedTokens));
  }
}
