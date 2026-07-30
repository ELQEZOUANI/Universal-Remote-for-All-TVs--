import '../tv_brand.dart';
import '../tv_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  LG TV Controller  (WebOS / SSAP)
//
//  Protocol : LG SSAP (Simple Service Access Protocol) over WebSocket.
//  Endpoint : ws://<ip>:3000 — all commands are JSON.
//
//  Flow:
//    1. Connect to ws://<ip>:3000
//    2. Send a 'register' message with the client manifest.
//    3. TV shows a pairing prompt; user accepts → server replies 'registered'.
//    4. Store the returned 'client-key' for future sessions.
//
//  Two API paths:
//    • App launches → ssap://system.launcher/launch  { "id": "<appId>" }
//    • D-Pad/nav    → ssap://com.webos.service.networkinput/getPointerInputSocket
//                     (opens a secondary socket; button name sent there)
//    • Media/sys    → direct SSAP URI, no extra payload
// ─────────────────────────────────────────────────────────────────────────────

class LGTVController implements TVController {
  @override
  final TVBrand brand = TVBrand.lg;

  @override
  String get ipAddress => _ip;

  @override
  bool get isConnected => _connected;

  String _ip = '';
  bool _connected = false;

  // Keys that open an app via ssap://system.launcher/launch.
  static const Map<String, String> _appIds = {
    'NETFLIX': 'netflix',
    'YOUTUBE': 'youtube.leanback.v4',
    'PRIME': 'amazon',
    'DISNEY_PLUS': 'com.disney.disneyplus-prod',
    'SOURCE': 'com.webos.app.inputpicker',
  };

  // Keys sent as direct SSAP service requests.
  static const Map<String, String> _ssapUris = {
    'POWER': 'ssap://system/turnOff',
    'VOLUME_UP': 'ssap://audio/volumeUp',
    'VOLUME_DOWN': 'ssap://audio/volumeDown',
    'MUTE': 'ssap://audio/setMute',
    'CHANNEL_UP': 'ssap://tv/channelUp',
    'CHANNEL_DOWN': 'ssap://tv/channelDown',
    'HOME': 'ssap://com.webos.service.ime/sendEnterKey',
    'MENU': 'ssap://settings/open',
    'PLAY': 'ssap://media.controls/play',
    'PAUSE': 'ssap://media.controls/pause',
    'STOP': 'ssap://media.controls/stop',
    'REWIND': 'ssap://media.controls/rewind',
    'FAST_FORWARD': 'ssap://media.controls/fastForward',
  };

  // D-Pad / nav keys sent via the pointer-input socket (button name).
  static const Map<String, String> _buttonNames = {
    'UP': 'UP',
    'DOWN': 'DOWN',
    'LEFT': 'LEFT',
    'RIGHT': 'RIGHT',
    'OK': 'ENTER',
    'BACK': 'BACK',
    '0': '0',
    '1': '1',
    '2': '2',
    '3': '3',
    '4': '4',
    '5': '5',
    '6': '6',
    '7': '7',
    '8': '8',
    '9': '9',
  };

  @override
  Future<void> connect(String ip) async {
    _ip = ip;
    // TODO: Open WebSocket to ws://$ip:3000
    // Send registration message; wait for 'registered' response.
    // Store received 'client-key' in device.pairingToken.
    _connected = true;
    print('[LG] Connected to $ip');
  }

  @override
  Future<void> disconnect() async {
    // TODO: Close WebSocket channel.
    _connected = false;
    print('[LG] Disconnected');
  }

  @override
  Future<void> sendKey(String keyName) async {
    if (!_connected) return;
    final key = keyName.toUpperCase();

    // 1. App launch?
    final appId = _appIds[key];
    if (appId != null) {
      // TODO: Send via WebSocket:
      // { "type":"request", "uri":"ssap://system.launcher/launch",
      //   "payload": { "id": "$appId" } }
      print('[LG] Launch app $key → appId: $appId');
      return;
    }

    // 2. Direct SSAP URI?
    final uri = _ssapUris[key];
    if (uri != null) {
      // TODO: Send via WebSocket:
      // { "type":"request", "uri": "$uri" }
      print('[LG] SSAP $key → $uri');
      return;
    }

    // 3. D-Pad / button via pointer-input socket?
    final btnName = _buttonNames[key];
    if (btnName != null) {
      // TODO: Send button press over the secondary pointer socket.
      print('[LG] Button $key → $btnName');
      return;
    }

    print('[LG] Unknown key: $keyName');
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
