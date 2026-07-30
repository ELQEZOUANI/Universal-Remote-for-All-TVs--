import 'tv_brand.dart';
import 'tv_controller.dart';
import 'tv_detector.dart';
import 'controllers/android_tv_controller.dart';
import 'controllers/samsung_tv_controller.dart';
import 'controllers/lg_tv_controller.dart';
import 'controllers/roku_tv_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Remote Manager — Central Connection & Command Dispatcher
//
//  Usage:
//    final manager = RemoteManager();
//    await manager.connectToDevice('192.168.1.100');
//    await manager.pressButton('HOME');
//    await manager.adjustVolume(0, isUp: true);
//    await manager.pressButton('POWER');
//    await manager.disconnect();
// ─────────────────────────────────────────────────────────────────────────────

/// Callback invoked when the connection state changes.
typedef ConnectionCallback = void Function(bool connected, TVBrand brand);

/// Callback invoked when an error occurs.
typedef ErrorCallback = void Function(String message);

class RemoteManager {
  final TVDetector _detector = TVDetector();

  /// The currently active TV controller. Null if not connected.
  TVController? activeDevice;

  /// Optional listener for connection state changes.
  ConnectionCallback? onConnectionChanged;

  /// Optional listener for errors.
  ErrorCallback? onError;

  /// Whether a device is currently connected.
  bool get isConnected => activeDevice?.isConnected ?? false;

  /// The brand of the currently connected TV, or null if not connected.
  TVBrand? get connectedBrand => activeDevice?.brand;

  // ── Connection ─────────────────────────────────────────────────────────────

  /// Fingerprints the TV at [ip], instantiates the correct controller,
  /// and establishes a connection.
  ///
  /// Returns true on success, false if the brand could not be detected
  /// or the connection failed.
  Future<bool> connectToDevice(String ip) async {
    // Disconnect any existing session first.
    await disconnect();

    print('[RemoteManager] Fingerprinting $ip…');
    final brand = await _detector.identifyTV(ip);

    if (brand == TVBrand.unknown) {
      _emitError('No known TV found at $ip. Check the IP and try again.');
      return false;
    }

    print('[RemoteManager] Detected: ${brand.label}');

    // Instantiate the correct controller for this brand.
    activeDevice = _controllerFor(brand);

    try {
      await activeDevice!.connect(ip);
    } catch (e) {
      activeDevice = null;
      _emitError('Failed to connect to ${brand.label} at $ip: $e');
      return false;
    }

    onConnectionChanged?.call(true, brand);
    return true;
  }

  /// Disconnects from the current device and clears [activeDevice].
  Future<void> disconnect() async {
    if (activeDevice == null) return;
    final brand = activeDevice!.brand;
    await activeDevice!.disconnect();
    activeDevice = null;
    onConnectionChanged?.call(false, brand);
  }

  // ── Unified command surface ────────────────────────────────────────────────

  /// Sends a named key press to the active device.
  ///
  /// Does nothing if no device is connected. Key names are case-insensitive.
  /// See [TVController.sendKey] for the full list of supported key names.
  Future<void> pressButton(String button) async {
    if (!_assertConnected()) return;
    await activeDevice!.sendKey(button);
  }

  /// Adjusts the volume on the active device.
  ///
  /// [level] is 0–100 (used by brands that support absolute volume).
  /// [isUp] true = volume up, false = volume down.
  Future<void> adjustVolume(int level, {required bool isUp}) async {
    if (!_assertConnected()) return;
    await activeDevice!.volume(level, isUp: isUp);
  }

  /// Toggles power on the active device.
  Future<void> togglePower() async {
    if (!_assertConnected()) return;
    await activeDevice!.power();
  }

  // ── Factory ────────────────────────────────────────────────────────────────

  /// Returns the concrete [TVController] for the given [brand].
  TVController _controllerFor(TVBrand brand) {
    switch (brand) {
      case TVBrand.lg:
        return LGTVController();
      case TVBrand.samsung:
        return SamsungTVController();
      case TVBrand.androidTv:
        return AndroidTVController();
      case TVBrand.roku:
        return RokuTVController();
      case TVBrand.unknown:
        throw StateError('Cannot create a controller for unknown brand.');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _assertConnected() {
    if (activeDevice == null || !activeDevice!.isConnected) {
      _emitError('No TV connected. Call connectToDevice() first.');
      return false;
    }
    return true;
  }

  void _emitError(String message) {
    print('[RemoteManager] ERROR: $message');
    onError?.call(message);
  }
}
