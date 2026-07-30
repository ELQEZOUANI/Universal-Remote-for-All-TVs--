import 'package:http/http.dart' as http;
import 'tv_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Roku Service  (ECP — External Control Protocol)
//
//  Roku ECP is a stateless HTTP API on port 8060.
//  No pairing, no persistent socket — each command is an independent POST.
//
//  Key presses: POST http://<ip>:8060/keypress/<RokuKey>
//  App launches: POST http://<ip>:8060/launch/<appId>
// ─────────────────────────────────────────────────────────────────────────────

class RokuService extends TVService {
  static const Duration _timeout = Duration(seconds: 2);

  bool _connected = false;

  RokuService(super.device);

  @override
  bool get isConnected => _connected;

  @override
  bool get supportsAppLaunching => true;
  @override
  bool get supportsSourceControl => true;
  @override
  bool get supportsMenuNavigation => true;

  // ── Key map: RemoteKey → Roku ECP key string ──────────────────────────────

  static const Map<RemoteKey, String> _keyMap = {
    RemoteKey.power: 'PowerOff',
    RemoteKey.up: 'Up',
    RemoteKey.down: 'Down',
    RemoteKey.left: 'Left',
    RemoteKey.right: 'Right',
    RemoteKey.enter: 'Select',
    RemoteKey.back: 'Back',
    RemoteKey.home: 'Home',
    RemoteKey.menu: 'Info',
    RemoteKey.source: 'InputTuner', // Cycle through HDMI/AV inputs
    RemoteKey.volumeUp: 'VolumeUp',
    RemoteKey.volumeDown: 'VolumeDown',
    RemoteKey.mute: 'VolumeMute',
    RemoteKey.channelUp: 'ChannelUp',
    RemoteKey.channelDown: 'ChannelDown',
    RemoteKey.play: 'Play',
    RemoteKey.pause: 'Play', // Roku toggles play/pause with the same key
    RemoteKey.stop: 'Stop',
    RemoteKey.rewind: 'Rev',
    RemoteKey.fastForward: 'Fwd',
    RemoteKey.num0: 'Lit_0',
    RemoteKey.num1: 'Lit_1',
    RemoteKey.num2: 'Lit_2',
    RemoteKey.num3: 'Lit_3',
    RemoteKey.num4: 'Lit_4',
    RemoteKey.num5: 'Lit_5',
    RemoteKey.num6: 'Lit_6',
    RemoteKey.num7: 'Lit_7',
    RemoteKey.num8: 'Lit_8',
    RemoteKey.num9: 'Lit_9',
  };

  /// Keys that launch an app via POST /launch/<appId>.
  static const Map<RemoteKey, String> _appIds = {
    RemoteKey.netflix: '12',
    RemoteKey.youtube: '195316',
    RemoteKey.prime: '13',
    RemoteKey.disneyPlus: '291097',
  };

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<bool> connect() async {
    // Verify reachability with a lightweight device-info query.
    try {
      final uri = Uri.parse('http://${device.ip}:8060/query/device-info');
      final response = await http.get(uri).timeout(_timeout);
      _connected = response.statusCode == 200;
    } catch (_) {
      _connected = false;
    }
    print(
      '[RokuService] ${_connected ? 'Connected' : 'Unreachable'} at ${device.ip}',
    );
    return _connected;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  @override
  Future<void> sendKey(RemoteKey key) async {
    if (!_connected) return;

    // App launch?
    final appId = _appIds[key];
    if (appId != null) {
      await _post('launch/$appId');
      return;
    }

    // Standard keypress?
    final rokuKey = _keyMap[key];
    if (rokuKey != null) {
      await _post('keypress/$rokuKey');
    }
  }

  // ── HTTP helper ───────────────────────────────────────────────────────────

  Future<void> _post(String path) async {
    final uri = Uri.parse('http://${device.ip}:8060/$path');
    try {
      await http.post(uri).timeout(_timeout);
    } on Exception catch (e) {
      // Swallow timeouts / connection drops so the UI stays responsive.
      print('[RokuService] POST $path failed: $e');
    }
  }
}
