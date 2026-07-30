import 'package:http/http.dart' as http;
import '../tv_brand.dart';
import '../tv_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Roku TV Controller  (ECP — External Control Protocol)
//
//  Protocol : HTTP/1.1 over port 8060 (no authentication required).
//  Key presses: POST http://<ip>:8060/keypress/<RokuKey>
//  App launch:  POST http://<ip>:8060/launch/<appId>
//
//  Roku ECP key reference:
//    https://developer.roku.com/docs/developer-program/debugging/external-control-api.md
//
//  Volume notes:
//    Roku ECP does not expose an absolute volume-level setter; only
//    VolumeUp / VolumeDown step commands are available.
// ─────────────────────────────────────────────────────────────────────────────

class RokuTVController implements TVController {
  @override
  final TVBrand brand = TVBrand.roku;

  @override
  String get ipAddress => _ip;

  @override
  bool get isConnected => _connected;

  // ── Capabilities ───────────────────────────────────────────────────────────

  /// Roku supports app launching via POST /launch/<appId>.
  final bool supportsAppLaunch = true;

  /// Roku supports source / input selection.
  final bool supportsSourceControl = true;

  /// Roku supports full menu navigation via ECP key presses.
  final bool supportsMenuNavigation = true;

  // ── Internal state ─────────────────────────────────────────────────────────

  String _ip = '';
  bool _connected = false;

  static const Duration _requestTimeout = Duration(seconds: 2);

  // ── Key mapping: app key → Roku ECP key string ────────────────────────────

  /// Keys that POST to /keypress/<rokuKey>.
  static const Map<String, String> _keyMap = {
    // Navigation
    'UP': 'Up',
    'DOWN': 'Down',
    'LEFT': 'Left',
    'RIGHT': 'Right',
    'OK': 'Select',

    // System
    'HOME': 'Home',
    'BACK': 'Back',
    'MENU': 'Info', // Roku's * (Options/Info) key
    'POWER': 'PowerOff',

    // Volume (step-wise only — Roku has no absolute level API)
    'VOLUME_UP': 'VolumeUp',
    'VOLUME_DOWN': 'VolumeDown',
    'MUTE': 'VolumeMute',

    // Channels
    'CHANNEL_UP': 'ChannelUp',
    'CHANNEL_DOWN': 'ChannelDown',

    // Playback
    'PLAY': 'Play',
    'PAUSE': 'Play', // Roku uses the same key to toggle play/pause
    'PLAY_PAUSE': 'Play',
    'STOP': 'Stop',
    'REWIND': 'Rev',
    'FAST_FORWARD': 'Fwd',

    // Number pad
    '0': 'Lit_0',
    '1': 'Lit_1',
    '2': 'Lit_2',
    '3': 'Lit_3',
    '4': 'Lit_4',
    '5': 'Lit_5',
    '6': 'Lit_6',
    '7': 'Lit_7',
    '8': 'Lit_8',
    '9': 'Lit_9',

    // Source / input
    'SOURCE': 'InputTuner',
    'HDMI_1': 'InputHDMI1',
    'HDMI_2': 'InputHDMI2',
    'HDMI_3': 'InputHDMI3',
    'HDMI_4': 'InputHDMI4',
    'AV': 'InputAV1',
  };

  /// Keys that POST to /launch/<appId> instead of /keypress/<key>.
  static const Map<String, String> _appIds = {
    'NETFLIX': '12',
    'YOUTUBE': '195316',
    'PRIME': '13',
    'DISNEY_PLUS': '291097',
  };

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  Future<void> connect(String ip) async {
    _ip = ip;
    // ECP is stateless HTTP — confirm reachability with a GET to /query/device-info.
    try {
      final uri = Uri.parse('http://$_ip:8060/query/device-info');
      final response = await http.get(uri).timeout(_requestTimeout);
      _connected = response.statusCode == 200;
    } catch (_) {
      _connected = false;
    }
    print('[Roku] ${_connected ? 'Connected' : 'Unreachable'} at $_ip');
  }

  @override
  Future<void> disconnect() async {
    // ECP is stateless — nothing to tear down.
    _connected = false;
    print('[Roku] Disconnected');
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  @override
  Future<void> sendKey(String keyName) async {
    if (!_connected) return;
    final key = keyName.toUpperCase();

    // App launch?
    final appId = _appIds[key];
    if (appId != null) {
      await _postLaunch(appId, key);
      return;
    }

    // Standard keypress?
    final rokuKey = _keyMap[key];
    if (rokuKey != null) {
      await _postKeypress(rokuKey, key);
      return;
    }

    print('[Roku] Unknown key: $keyName');
  }

  /// [level] is ignored — Roku ECP only supports step-wise volume.
  /// [isUp] true → VolumeUp, false → VolumeDown.
  @override
  Future<void> volume(int level, {required bool isUp}) async {
    await sendKey(isUp ? 'VOLUME_UP' : 'VOLUME_DOWN');
  }

  @override
  Future<void> power() async {
    await sendKey('POWER');
  }

  // ── HTTP helpers ───────────────────────────────────────────────────────────

  Future<void> _postKeypress(String rokuKey, String originalKey) async {
    final uri = Uri.parse('http://$_ip:8060/keypress/$rokuKey');
    try {
      final response = await http.post(uri).timeout(_requestTimeout);
      if (response.statusCode == 200) {
        print('[Roku] Keypress $originalKey → $rokuKey ✓');
      } else {
        print('[Roku] Keypress $rokuKey returned ${response.statusCode}');
      }
    } on Exception catch (e) {
      // Swallow timeouts / connection errors so the UI stays responsive.
      print('[Roku] Keypress $rokuKey failed: $e');
    }
  }

  Future<void> _postLaunch(String appId, String originalKey) async {
    final uri = Uri.parse('http://$_ip:8060/launch/$appId');
    try {
      final response = await http.post(uri).timeout(_requestTimeout);
      if (response.statusCode == 200) {
        print('[Roku] Launch $originalKey → appId $appId ✓');
      } else {
        print('[Roku] Launch appId $appId returned ${response.statusCode}');
      }
    } on Exception catch (e) {
      print('[Roku] Launch $originalKey failed: $e');
    }
  }
}
