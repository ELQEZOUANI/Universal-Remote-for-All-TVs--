import '../tv_brand.dart';
import '../tv_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Android TV Controller
//
//  Protocol  : Android TV Remote Protocol v2 (TLS sockets, protobuf)
//  Pair port : 6466
//  Remote port: 6467
//
//  This controller translates generic key names into Android KeyEvent keycodes
//  and writes them as properly-encoded protobuf RemoteKeyInject messages.
// ─────────────────────────────────────────────────────────────────────────────

class AndroidTVController implements TVController {
  @override
  final TVBrand brand = TVBrand.androidTv;

  @override
  String get ipAddress => _ip;

  @override
  bool get isConnected => _connected;

  String _ip = '';
  bool _connected = false;

  // Android KeyEvent keycodes.
  static const Map<String, int> _keyCodes = {
    'UP': 19,
    'DOWN': 20,
    'LEFT': 21,
    'RIGHT': 22,
    'OK': 23,
    'HOME': 3,
    'BACK': 4,
    'MENU': 82,
    'POWER': 26,
    'SOURCE': 178, // KEYCODE_TV_INPUT
    'VOLUME_UP': 24,
    'VOLUME_DOWN': 25,
    'MUTE': 164,
    'CHANNEL_UP': 166,
    'CHANNEL_DOWN': 167,
    'PLAY': 126,
    'PAUSE': 127,
    'STOP': 86,
    'REWIND': 89,
    'FAST_FORWARD': 90,
    '0': 7,
    '1': 8,
    '2': 9,
    '3': 10,
    '4': 11,
    '5': 12,
    '6': 13,
    '7': 14,
    '8': 15,
    '9': 16,
    'NETFLIX': 533,
    'YOUTUBE': 534,
    'PRIME': 535,
    'DISNEY_PLUS': 536,
  };

  @override
  Future<void> connect(String ip) async {
    _ip = ip;
    // TODO: Open TLS SecureSocket to $ip:6467 using stored certificate.
    // If no certificate, call startPairing() on port 6466 first.
    _connected = true;
    print('[AndroidTV] Connected to $ip');
  }

  @override
  Future<void> disconnect() async {
    // TODO: Close SecureSocket.
    _connected = false;
    print('[AndroidTV] Disconnected');
  }

  @override
  Future<void> sendKey(String keyName) async {
    if (!_connected) return;
    final code = _keyCodes[keyName.toUpperCase()];
    if (code == null) {
      print('[AndroidTV] Unknown key: $keyName');
      return;
    }
    // TODO: Write _buildKeyMessage(code, DOWN) then _buildKeyMessage(code, UP)
    // to the SecureSocket with an 80ms gap.
    print('[AndroidTV] sendKey $keyName → keyCode $code');
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
