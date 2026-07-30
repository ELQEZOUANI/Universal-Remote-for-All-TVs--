import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'tv_service.dart';

/// LG webOS TV control via WebSocket (SSAP protocol on port 3000).
///
/// Pairing handshake:
///   1. Connect to ws://<ip>:3000
///   2. Send a registration payload (with client‑key if previously paired).
///   3. If no client‑key, the TV shows a pairing prompt – user clicks "Accept".
///   4. The TV responds with a `client-key` to store for future connections.
class LGService extends TVService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connected = false;
  int _commandId = 0;

  LGService(super.device);

  @override
  bool get isConnected => _connected;

  // LG WebOS supports app launching, input source switching, and menu navigation.
  @override
  bool get supportsAppLaunching => true;
  @override
  bool get supportsSourceControl => true;
  @override
  bool get supportsMenuNavigation => true;

  @override
  Future<bool> connect() async {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://${device.ip}:${device.port}'),
      );
      await _channel!.ready;

      // Send SSAP registration handshake.
      _channel!.sink.add(
        jsonEncode(_buildRegistrationPayload(device.pairingToken)),
      );

      // Wait for the TV to send back 'registered'.
      // The TV shows a pairing prompt — user must accept it on the TV screen.
      final completer = Completer<bool>();

      _sub = _channel!.stream.listen(
        (raw) {
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            final type = data['type'] as String?;
            if (type == 'registered') {
              final payload = data['payload'] as Map<String, dynamic>?;
              if (payload != null && payload.containsKey('client-key')) {
                device.pairingToken = payload['client-key'] as String;
              }
              _connected = true;
              if (!completer.isCompleted) completer.complete(true);
            } else if (type == 'error') {
              if (!completer.isCompleted) completer.complete(false);
            }
          } catch (_) {}
        },
        onError: (_) {
          _connected = false;
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          _connected = false;
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      // Give user up to 30 s to accept the pairing prompt on the TV.
      final ok = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _connected = false;
          return false;
        },
      );

      if (!ok) await disconnect();
      return ok;
    } catch (_) {
      _connected = false;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  @override
  Future<void> sendKey(RemoteKey key) async {
    if (!_connected || _channel == null) return;

    _commandId++;

    // App launches use ssap://system.launcher/launch with an app ID payload.
    final appId = _getAppId(key);
    if (appId != null) {
      final msg = jsonEncode({
        'id': 'command_$_commandId',
        'type': 'request',
        'uri': 'ssap://system.launcher/launch',
        'payload': {'id': appId},
      });
      _channel!.sink.add(msg);
      return;
    }

    final uri = _mapKeyToUri(key);
    if (uri == null) return;

    final msg = jsonEncode({
      'id': 'command_$_commandId',
      'type': 'request',
      'uri': uri,
      if (_isButtonPress(key)) 'payload': {'name': _mapKeyToButtonName(key)},
    });
    _channel!.sink.add(msg);
  }

  /// Returns the LG webOS app ID for keys that launch apps, null otherwise.
  String? _getAppId(RemoteKey key) {
    const map = {
      RemoteKey.netflix: 'netflix',
      RemoteKey.youtube: 'youtube.leanback.v4',
      RemoteKey.prime: 'amazon',
      RemoteKey.disneyPlus: 'com.disney.disneyplus-prod',
      RemoteKey.source: 'com.webos.app.inputpicker',
    };
    return map[key];
  }

  bool _isButtonPress(RemoteKey key) {
    // Only D-Pad / nav keys use the button-name API via pointer socket.
    const buttonKeys = {
      RemoteKey.up,
      RemoteKey.down,
      RemoteKey.left,
      RemoteKey.right,
      RemoteKey.enter,
      RemoteKey.back,
    };
    return buttonKeys.contains(key);
  }

  String? _mapKeyToUri(RemoteKey key) {
    const map = {
      RemoteKey.power: 'ssap://system/turnOff',
      RemoteKey.volumeUp: 'ssap://audio/volumeUp',
      RemoteKey.volumeDown: 'ssap://audio/volumeDown',
      RemoteKey.mute: 'ssap://audio/setMute',
      RemoteKey.channelUp: 'ssap://tv/channelUp',
      RemoteKey.channelDown: 'ssap://tv/channelDown',
      RemoteKey.home: 'ssap://com.webos.service.ime/sendEnterKey',
      RemoteKey.menu: 'ssap://settings/open',
      RemoteKey.play: 'ssap://media.controls/play',
      RemoteKey.pause: 'ssap://media.controls/pause',
      RemoteKey.stop: 'ssap://media.controls/stop',
      RemoteKey.rewind: 'ssap://media.controls/rewind',
      RemoteKey.fastForward: 'ssap://media.controls/fastForward',
    };

    // D‑Pad and other keys go through the input socket button API.
    if (!map.containsKey(key)) {
      return 'ssap://com.webos.service.networkinput/getPointerInputSocket';
    }
    return map[key];
  }

  String _mapKeyToButtonName(RemoteKey key) {
    const map = {
      RemoteKey.up: 'UP',
      RemoteKey.down: 'DOWN',
      RemoteKey.left: 'LEFT',
      RemoteKey.right: 'RIGHT',
      RemoteKey.enter: 'ENTER',
      RemoteKey.back: 'BACK',
      RemoteKey.home: 'HOME',
      RemoteKey.menu: 'MENU',
      RemoteKey.source: 'INPUT',
      RemoteKey.prime: 'AMAZON',
      RemoteKey.disneyPlus: 'DISNEY',
    };
    return map[key] ?? key.name.toUpperCase();
  }

  Map<String, dynamic> _buildRegistrationPayload(String? clientKey) {
    return {
      'type': 'register',
      'id': 'register_0',
      'payload': {
        'forcePairing': false,
        'pairingType': 'PROMPT',
        if (clientKey != null) 'client-key': clientKey,
        'manifest': {
          'manifestVersion': 1,
          'appVersion': '1.0.0',
          'signed': {
            'created': '20240101',
            'appId': 'com.universalremote',
            'vendorId': 'com.universalremote',
          },
          'permissions': [
            'LAUNCH',
            'LAUNCH_WEBAPP',
            'APP_TO_APP',
            'CLOSE',
            'TEST_OPEN',
            'TEST_PROTECTED',
            'CONTROL_AUDIO',
            'CONTROL_DISPLAY',
            'CONTROL_INPUT_JOYSTICK',
            'CONTROL_INPUT_MEDIA_RECORDING',
            'CONTROL_INPUT_MEDIA_PLAYBACK',
            'CONTROL_INPUT_TV',
            'CONTROL_POWER',
            'READ_APP_STATUS',
            'READ_CURRENT_CHANNEL',
            'READ_INPUT_DEVICE_LIST',
            'READ_NETWORK_STATE',
            'READ_RUNNING_APPS',
            'READ_TV_CHANNEL_LIST',
            'WRITE_NOTIFICATION_TOAST',
            'CONTROL_INPUT_TEXT',
            'CONTROL_MOUSE_AND_KEYBOARD',
            'READ_INSTALLED_APPS',
            'READ_LGE_TV_INPUT_EVENTS',
            'READ_TV_CURRENT_TIME',
          ],
        },
      },
    };
  }
}
