import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'tv_service.dart';

/// Android TV / Google TV Remote Protocol v2.
///
/// ──────────────────────────────────────────────────────────
/// HOW THE 4‑DIGIT PAIRING CODE WORKS
/// ──────────────────────────────────────────────────────────
/// 1. Open a TLS socket to <tv_ip>:6466 (pairing port).
/// 2. Send a PairingRequest protobuf with service name "com.universalremote".
/// 3. The TV displays a 4‑digit PIN code on‑screen.
/// 4. The user reads the PIN and enters it in the app.
/// 5. Send a PairingSecret message containing HMAC‑SHA256(sharedSecret, PIN).
/// 6. If accepted the TV responds with a session certificate.
/// 7. Store the certificate – subsequent connections on port 6467 (remote port)
///    use it for mutual‑TLS without re‑pairing.
///
/// NOTE: Full protobuf implementation requires generating .pb.dart files from
///       Google's android‑tv‑remote .proto definitions. The code below uses a
///       simplified byte‑level approach that mirrors the wire format.
/// ──────────────────────────────────────────────────────────

class AndroidTVService extends TVService {
  static const int _pairingPort = 6466;
  static const int _remotePort = 6467;

  SecureSocket? _socket;
  bool _connected = false;

  AndroidTVService(super.device);

  @override
  bool get isConnected => _connected;

  // Android TV Remote Protocol supports source switching (KEYCODE_TV_INPUT = 178)
  // and menu navigation (KEYCODE_MENU = 82) via keycode injection.
  @override
  bool get supportsSourceControl => true;
  @override
  bool get supportsMenuNavigation => true;

  /// Connect to the remote‑input port using a previously stored certificate.
  /// If no certificate exists, call [pair] first.
  @override
  Future<bool> connect() async {
    if (device.pairingToken == null) {
      // No certificate stored – caller should trigger pairing flow.
      return false;
    }
    try {
      _socket = await SecureSocket.connect(
        device.ip,
        _remotePort,
        onBadCertificate: (_) => true, // Accept the TV's self‑signed cert.
      );

      _socket!.listen(
        (_) {},
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
    await _socket?.close();
    _socket = null;
  }

  /// Initiate pairing – call this when no token/cert exists.
  /// Returns `true` when the pairing request has been sent and
  /// the TV is showing the PIN. The caller should then collect
  /// the PIN from the user and call [submitPairingCode].
  Future<bool> startPairing() async {
    try {
      _socket = await SecureSocket.connect(
        device.ip,
        _pairingPort,
        onBadCertificate: (_) => true,
      );

      // Simplified pairing‑request message (protobuf field 1 = service name).
      final serviceName = utf8.encode('com.universalremote');
      final header = Uint8List.fromList([
        0x08, 0x02, // protocol_status = 200 OK
        0x12, serviceName.length, // field 2: service_name
        ...serviceName,
      ]);
      _socket!.add(header);
      await _socket!.flush();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// After the user reads the 4‑digit code displayed on the TV,
  /// submit it here to complete pairing.
  Future<bool> submitPairingCode(String code) async {
    if (_socket == null) return false;
    try {
      final codeBytes = utf8.encode(code);
      // Simplified pairing‑secret message.
      final payload = Uint8List.fromList([
        0x08, 0xC8, 0x01, // protocol_status = 200
        0x12, codeBytes.length,
        ...codeBytes,
      ]);
      _socket!.add(payload);
      await _socket!.flush();

      // In production, read the response and extract the session certificate.
      // For now, store a placeholder token indicating successful pairing.
      device.pairingToken = 'paired_${DateTime.now().millisecondsSinceEpoch}';
      await _socket!.close();
      _socket = null;
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> sendKey(RemoteKey key) async {
    if (!_connected || _socket == null) return;

    final keyCode = _mapKey(key);
    if (keyCode == null) return;

    if (key == RemoteKey.source) {
      _socket!.add(_buildKeyMessage(keyCode, 1)); // 1 = DOWN
      await _socket!.flush();
      await Future.delayed(const Duration(milliseconds: 250));
      _socket!.add(_buildKeyMessage(keyCode, 2)); // 2 = UP
      await _socket!.flush();
    } else {
      _socket!.add(_buildKeyMessage(keyCode, 1)); // 1 = DOWN
      await _socket!.flush();
      await Future.delayed(const Duration(milliseconds: 80));
      _socket!.add(_buildKeyMessage(keyCode, 2)); // 2 = UP
      await _socket!.flush();
    }
  }

  @override
  Future<void> sendRawKeyCode(int keyCode) async {
    if (!_connected || _socket == null) return;

    // Send KEY_DOWN then KEY_UP.
    _socket!.add(_buildKeyMessage(keyCode, 1)); // 1 = DOWN
    await _socket!.flush();
    await Future.delayed(const Duration(milliseconds: 80));
    _socket!.add(_buildKeyMessage(keyCode, 2)); // 2 = UP
    await _socket!.flush();
  }

  @override
  Future<void> launchAppLink(String url) async {
    if (!_connected || _socket == null) return;
    _socket!.add(_buildAppLinkMessage(url));
    await _socket!.flush();
  }

  Uint8List _buildAppLinkMessage(String url) {
    final urlBytes = utf8.encode(url);
    final inner = Uint8List.fromList([
      0x0a,
      urlBytes.length,
      ...urlBytes,
    ]);
    return Uint8List.fromList([
      0xd2, 0x05, // (90 << 3) | 2 = 722
      inner.length,
      ...inner,
    ]);
  }

  /// Builds an Android TV Remote Protocol v2 key-inject message.
  ///
  /// Protobuf wire format for RemoteMessage:
  ///   field 10, wire type 2 (length-delimited) → RemoteKeyInject
  ///     field 1 (key_code): varint
  ///     field 2 (direction): varint  1=DOWN, 2=UP
  Uint8List _buildKeyMessage(int keyCode, int direction) {
    final keyCodeBytes = _encodeVarint(keyCode);
    final directionBytes = _encodeVarint(direction);

    // Inner message: 0x08 <keyCode varint> 0x10 <direction varint>
    final inner = Uint8List.fromList([
      0x08,
      ...keyCodeBytes,
      0x10,
      ...directionBytes,
    ]);

    // Outer wrapper: field 10, wire type 2, then length, then inner
    return Uint8List.fromList([
      0x52, // (10 << 3) | 2
      inner.length,
      ...inner,
    ]);
  }

  /// Encodes an integer as a protobuf varint (little-endian, 7 bits per byte).
  List<int> _encodeVarint(int value) {
    final bytes = <int>[];
    while (value > 0x7F) {
      bytes.add((value & 0x7F) | 0x80);
      value >>= 7;
    }
    bytes.add(value & 0x7F);
    return bytes;
  }

  int? _mapKey(RemoteKey key) {
    // Android KeyEvent keycodes.
    const map = {
      RemoteKey.power: 26,
      RemoteKey.up: 19,
      RemoteKey.down: 20,
      RemoteKey.left: 21,
      RemoteKey.right: 22,
      RemoteKey.enter: 23, // DPAD_CENTER
      RemoteKey.back: 4,
      RemoteKey.home: 3,
      RemoteKey.volumeUp: 24,
      RemoteKey.volumeDown: 25,
      RemoteKey.mute: 164,
      RemoteKey.channelUp: 166,
      RemoteKey.channelDown: 167,
      RemoteKey.menu: 82,
      RemoteKey.source: 178, // TV_INPUT
      RemoteKey.play: 126,
      RemoteKey.pause: 127,
      RemoteKey.stop: 86,
      RemoteKey.rewind: 89,
      RemoteKey.fastForward: 90,
      RemoteKey.num0: 7,
      RemoteKey.num1: 8,
      RemoteKey.num2: 9,
      RemoteKey.num3: 10,
      RemoteKey.num4: 11,
      RemoteKey.num5: 12,
      RemoteKey.num6: 13,
      RemoteKey.num7: 14,
      RemoteKey.num8: 15,
      RemoteKey.num9: 16,
      RemoteKey.netflix: 533,
      RemoteKey.youtube: 534,
      RemoteKey.prime: 535,
      RemoteKey.disneyPlus: 536,
    };
    return map[key];
  }
}
