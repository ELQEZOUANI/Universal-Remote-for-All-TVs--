import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'tv_service.dart';

/// Samsung Tizen TV control via WebSocket on port 8001 (non‑SSL) or 8002 (SSL).
///
/// Protocol overview:
///   1. Connect to ws://<ip>:8001/api/v2/channels/samsung.remote.control?name=<base64>
///   2. On first connection the TV shows a pairing popup – the user must accept.
///   3. The TV responds with a JSON payload containing a `token`.
///   4. Subsequent connections append &token=<token> to skip pairing.
class SamsungService extends TVService {
  WebSocketChannel? _channel;
  bool _connected = false;

  SamsungService(super.device);

  static const _appName = 'UniversalRemote';

  String get _encodedName => base64.encode(utf8.encode(_appName));

  String get _wsUrl {
    final token = device.pairingToken;
    final base =
        'ws://${device.ip}:${device.port}/api/v2/channels/samsung.remote.control?name=$_encodedName';
    return token != null ? '$base&token=$token' : base;
  }

  @override
  bool get isConnected => _connected;

  // Samsung Tizen supports app launching, input source switching, and menu navigation.
  @override
  bool get supportsAppLaunching => true;
  @override
  bool get supportsSourceControl => true;
  @override
  bool get supportsMenuNavigation => true;

  @override
  Future<bool> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      await _channel!.ready;

      // Listen for the initial handshake – extract token.
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            if (data['event'] == 'ms.channel.connect') {
              final tokenData = data['data'] as Map<String, dynamic>?;
              if (tokenData != null && tokenData.containsKey('token')) {
                device.pairingToken = tokenData['token'] as String;
              }
            }
          } catch (_) {}
        },
        onError: (_) => _connected = false,
        onDone: () => _connected = false,
      );

      _connected = true;
      return true;
    } catch (e) {
      _connected = false;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _channel?.sink.close();
    _channel = null;
  }

  @override
  Future<void> sendKey(RemoteKey key) async {
    if (!_connected || _channel == null) return;

    final keyCode = _mapKey(key);
    if (keyCode == null) return;

    final payload = jsonEncode({
      'method': 'ms.remote.control',
      'params': {
        'Cmd': 'Click',
        'DataOfCmd': keyCode,
        'Option': 'false',
        'TypeOfRemote': 'SendRemoteKey',
      },
    });

    _channel!.sink.add(payload);
  }

  String? _mapKey(RemoteKey key) {
    const map = {
      RemoteKey.power: 'KEY_POWER',
      RemoteKey.up: 'KEY_UP',
      RemoteKey.down: 'KEY_DOWN',
      RemoteKey.left: 'KEY_LEFT',
      RemoteKey.right: 'KEY_RIGHT',
      RemoteKey.enter: 'KEY_ENTER',
      RemoteKey.back: 'KEY_RETURN',
      RemoteKey.home: 'KEY_HOME',
      RemoteKey.volumeUp: 'KEY_VOLUP',
      RemoteKey.volumeDown: 'KEY_VOLDOWN',
      RemoteKey.mute: 'KEY_MUTE',
      RemoteKey.channelUp: 'KEY_CHUP',
      RemoteKey.channelDown: 'KEY_CHDOWN',
      RemoteKey.menu: 'KEY_MENU',
      RemoteKey.source: 'KEY_SOURCE',
      RemoteKey.play: 'KEY_PLAY',
      RemoteKey.pause: 'KEY_PAUSE',
      RemoteKey.stop: 'KEY_STOP',
      RemoteKey.rewind: 'KEY_REWIND',
      RemoteKey.fastForward: 'KEY_FF',
      RemoteKey.num0: 'KEY_0',
      RemoteKey.num1: 'KEY_1',
      RemoteKey.num2: 'KEY_2',
      RemoteKey.num3: 'KEY_3',
      RemoteKey.num4: 'KEY_4',
      RemoteKey.num5: 'KEY_5',
      RemoteKey.num6: 'KEY_6',
      RemoteKey.num7: 'KEY_7',
      RemoteKey.num8: 'KEY_8',
      RemoteKey.num9: 'KEY_9',
    };
    return map[key];
  }
}
