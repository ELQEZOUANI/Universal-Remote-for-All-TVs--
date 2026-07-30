import '../tv_brand.dart';
import '../tv_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Samsung TV Controller  (Tizen / SmartThings)
//
//  Protocol : Samsung SmartThings API v2 — WebSocket on port 8001 (ws)
//             or port 8002 (wss, encrypted).
//  Endpoint : ws://<ip>:8001/api/v2/channels/samsung.remote.control
//
//  Key names are sent as JSON:
//    { "method": "ms.remote.control",
//      "params": { "Cmd": "Click", "DataOfCmd": "<KEY_NAME>",
//                  "Option": "false", "TypeOfRemote": "SendRemoteKey" } }
// ─────────────────────────────────────────────────────────────────────────────

class SamsungTVController implements TVController {
  @override
  final TVBrand brand = TVBrand.samsung;

  @override
  String get ipAddress => _ip;

  @override
  bool get isConnected => _connected;

  String _ip = '';
  bool _connected = false;

  // Samsung Tizen key names (sent verbatim in DataOfCmd).
  static const Map<String, String> _keyMap = {
    'UP': 'KEY_UP',
    'DOWN': 'KEY_DOWN',
    'LEFT': 'KEY_LEFT',
    'RIGHT': 'KEY_RIGHT',
    'OK': 'KEY_ENTER',
    'HOME': 'KEY_HOME',
    'BACK': 'KEY_RETURN',
    'MENU': 'KEY_MENU',
    'POWER': 'KEY_POWER',
    'SOURCE': 'KEY_SOURCE',
    'VOLUME_UP': 'KEY_VOLUP',
    'VOLUME_DOWN': 'KEY_VOLDOWN',
    'MUTE': 'KEY_MUTE',
    'CHANNEL_UP': 'KEY_CHUP',
    'CHANNEL_DOWN': 'KEY_CHDOWN',
    'PLAY': 'KEY_PLAY',
    'PAUSE': 'KEY_PAUSE',
    'STOP': 'KEY_STOP',
    'REWIND': 'KEY_REWIND',
    'FAST_FORWARD': 'KEY_FF',
    '0': 'KEY_0',
    '1': 'KEY_1',
    '2': 'KEY_2',
    '3': 'KEY_3',
    '4': 'KEY_4',
    '5': 'KEY_5',
    '6': 'KEY_6',
    '7': 'KEY_7',
    '8': 'KEY_8',
    '9': 'KEY_9',
    'NETFLIX': 'KEY_NETFLIX',
    'YOUTUBE': 'KEY_YOUTUBE',
  };

  @override
  Future<void> connect(String ip) async {
    _ip = ip;
    // TODO: Open WebSocket to ws://$ip:8001/api/v2/channels/samsung.remote.control
    // with query params: name=<base64 app name>, token=<stored token>.
    _connected = true;
    print('[Samsung] Connected to $ip');
  }

  @override
  Future<void> disconnect() async {
    // TODO: Close WebSocket channel.
    _connected = false;
    print('[Samsung] Disconnected');
  }

  @override
  Future<void> sendKey(String keyName) async {
    if (!_connected) return;
    final tKey =
        _keyMap[keyName.toUpperCase()] ?? 'KEY_${keyName.toUpperCase()}';
    // TODO: Send JSON payload via WebSocket.
    // {
    //   "method": "ms.remote.control",
    //   "params": { "Cmd": "Click", "DataOfCmd": "$tKey",
    //               "Option": "false", "TypeOfRemote": "SendRemoteKey" }
    // }
    print('[Samsung] sendKey $keyName → $tKey');
  }

  @override
  Future<void> volume(int level, {required bool isUp}) async {
    await sendKey(isUp ? 'VOLUME_UP' : 'VOLUME_DOWN');
  }

  @override
  Future<void> power() async {
    await sendKey('POWER');
  }
}
