import 'tv_brand.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Abstract Controller — Adapter Pattern interface
//
//  Every brand-specific controller must implement this contract.
//  The UI only ever talks to TVController — it never knows which brand
//  is underneath.
// ─────────────────────────────────────────────────────────────────────────────

/// Unified remote-control interface.
///
/// Key names follow the Android [KeyEvent] naming convention
/// (e.g. 'UP', 'DOWN', 'OK', 'HOME', 'BACK', 'VOLUME_UP', 'POWER').
abstract class TVController {
  /// The detected brand of the TV this controller is managing.
  TVBrand get brand;

  /// The IP address of the TV.
  String get ipAddress;

  /// Whether an active connection is currently established.
  bool get isConnected;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Opens the communication channel and performs pairing if necessary.
  Future<void> connect(String ip);

  /// Gracefully closes the communication channel.
  Future<void> disconnect();

  // ── Controls ───────────────────────────────────────────────────────────────

  /// Sends a named key press to the TV.
  ///
  /// Standard key names:
  ///   Navigation : UP | DOWN | LEFT | RIGHT | OK
  ///   System     : HOME | BACK | MENU | POWER | SOURCE
  ///   Volume     : VOLUME_UP | VOLUME_DOWN | MUTE
  ///   Channels   : CHANNEL_UP | CHANNEL_DOWN
  ///   Playback   : PLAY | PAUSE | STOP | REWIND | FAST_FORWARD
  ///   Numbers    : 0–9
  ///   Apps       : NETFLIX | YOUTUBE | PRIME | DISNEY_PLUS
  Future<void> sendKey(String keyName);

  /// Adjusts volume — [isUp] true raises volume, false lowers it.
  /// [level] is 0–100 (ignored by brands that only support step-wise control).
  Future<void> volume(int level, {required bool isUp});

  /// Toggles power on/off.
  Future<void> power();
}
