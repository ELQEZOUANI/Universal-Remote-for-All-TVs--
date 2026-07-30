import '../models/tv_device.dart';

/// Remote‑control key names shared across all TV protocols.
enum RemoteKey {
  power,
  up,
  down,
  left,
  right,
  enter,
  back,
  home,
  volumeUp,
  volumeDown,
  mute,
  channelUp,
  channelDown,
  menu,
  source,
  play,
  pause,
  stop,
  rewind,
  fastForward,
  num0,
  num1,
  num2,
  num3,
  num4,
  num5,
  num6,
  num7,
  num8,
  num9,
  netflix,
  youtube,
  prime,
  disneyPlus,
}

/// Abstract contract that every TV‑brand service must implement.
abstract class TVService {
  final TVDevice device;
  TVService(this.device);

  /// Called by the service when [isConnected] changes asynchronously
  /// (e.g. after a multi-step handshake). The provider hooks this to
  /// call notifyListeners() so the UI refreshes without polling.
  void Function()? onConnectionStateChanged;

  /// Open communication channel and perform pairing if needed.
  Future<bool> connect();

  /// Gracefully close the channel.
  Future<void> disconnect();

  /// Send a remote‑control key press.
  Future<void> sendKey(RemoteKey key);

  /// Send a raw keycode (Android keycode integer). Not all services support this.
  /// Default implementation maps through sendKey if possible.
  Future<void> sendRawKeyCode(int keyCode) async {}

  /// Launch an app or intent via URL/URI. Not all services support this.
  Future<void> launchAppLink(String url) async {}

  /// Whether we currently hold an open connection.
  bool get isConnected;

  // ── Capability / Feature-Flag API ─────────────────────────────────────────
  // The UI reads these to hide or disable controls the TV cannot handle.
  // Subclasses override only what applies to their protocol.

  /// True if the TV supports direct app launching (Netflix, YouTube, etc.).
  bool get supportsAppLaunching => false;

  /// True if the TV can switch inputs/sources (HDMI 1, AV, etc.).
  bool get supportsSourceControl => false;

  /// True if the TV has a native menu / settings navigation command.
  bool get supportsMenuNavigation => false;

  // ── Pairing API ───────────────────────────────────────────────────────────
  // These are overridden by services that require a user-input pairing code
  // (e.g. Android TV / XiaomiService).
  
  /// True if the service requires pairing before connecting.
  bool get needsPairing => false;

  /// Initiates the pairing process (e.g. prompts the TV to show a code).
  Future<bool> startPairing() async => false;

  /// Submits the code entered by the user.
  Future<bool> submitPairingCode(String code) async => false;
}
