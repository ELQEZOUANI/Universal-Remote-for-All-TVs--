import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pointycastle/export.dart' as pc;
import 'package:shared_preferences/shared_preferences.dart';
import 'tv_service.dart';
import 'cert_manager.dart';

/// Android TV Remote Protocol v2 — controls Xiaomi, Google TV, Sony, etc.
/// Pairing port: 6467   Remote port: 6466
class XiaomiService extends TVService {
  static const int _pairingPort = 6467;
  static const int _remotePort = 6466;

  static final CertManager _certMgr = CertManager();

  SecureSocket? _socket;
  bool _connected = false;
  bool _handshakeComplete = false;
  Completer<bool>? _handshakeCompleter;

  bool get needsPairing => device.pairingToken == null;
  void Function(String status)? onStatusChanged;

  XiaomiService(super.device);

  @override
  bool get isConnected => _connected && _handshakeComplete;

  // Android TV remote protocol does not support direct app launching but
  // can inject keycodes for source switching (KEYCODE_TV_INPUT = 178).
  // Menu navigation works via the MENU keycode (82).
  @override
  bool get supportsAppLaunching => false;
  @override
  bool get supportsSourceControl => true;
  @override
  bool get supportsMenuNavigation => true;

  Future<SecurityContext> _getContext() async {
    await _certMgr.ensureReady();
    return _certMgr.buildContext();
  }

  // ═══════════════════════════════════════════════════════
  //  CONNECT (port 6466) - REACTIVE HANDSHAKE
  // ═══════════════════════════════════════════════════════
  @override
  Future<bool> connect() async {
    try {
      onStatusChanged?.call('Connecting...');
      _handshakeComplete = false;
      _handshakeCompleter = Completer<bool>();
      _remoteBuf.clear();

      final ctx = await _getContext();
      _socket = await SecureSocket.connect(
        device.ip,
        _remotePort,
        context: ctx,
        timeout: const Duration(seconds: 5),
        onBadCertificate: (_) => true,
      );

      print('[REMOTE] Connected to $_remotePort, waiting for TV handshake...');

      // DO NOT send anything proactively!
      // TV initiates: remoteConfigure -> we reply -> remoteSetActive -> we reply
      _socket!.listen(
        _onRemoteData,
        onError: (Object e) async {
          final errStr = e.toString();
          print('[REMOTE] Stream error: $errStr');
          _connected = false;
          _handshakeComplete = false;

          if (errStr.contains('CERTIFICATE_UNKNOWN') ||
              errStr.contains('268436502')) {
            // Android TV sends CERTIFICATE_UNKNOWN *through the stream*
            // (not during connect) when it no longer recognises our cert.
            // Clear the saved token and regenerate so the next attempt
            // triggers a fresh pairing flow.
            print(
              '[REMOTE] TV rejected cert via stream. Clearing pairing data for re-pair.',
            );
            device.pairingToken = null;
            try {
              final prefs = await SharedPreferences.getInstance();
              final raw = prefs.getString('tv_tokens');
              if (raw != null) {
                final tokens =
                    Map<String, String>.from(jsonDecode(raw) as Map);
                tokens.remove(device.id);
                await prefs.setString('tv_tokens', jsonEncode(tokens));
              }
              await _certMgr.regenerate();
              print('[REMOTE] Certificate regenerated. Please re-pair.');
            } catch (_) {}
            onStatusChanged?.call(
              'TV does not recognise this device — please re-pair.',
            );
          } else if (errStr.contains('errno = 54') ||
              errStr.contains('Connection reset')) {
            onStatusChanged?.call('TV reset the connection. Try again.');
          } else {
            onStatusChanged?.call('Connection error');
          }

          if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
            _handshakeCompleter!.complete(false);
          }
          onConnectionStateChanged?.call(); // notify UI
        },
        onDone: () {
          print('[REMOTE] Connection closed');
          _connected = false;
          _handshakeComplete = false;
          if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
            _handshakeCompleter!.complete(false);
          }
          onConnectionStateChanged?.call(); // notify UI
        },
        cancelOnError: false,
      );

      _connected = true;
      // Wait for the handshake to finish or fail
      return await _handshakeCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
    } catch (e) {
      print('[REMOTE] Connect failed: $e');
      _connected = false;
      _socket = null;
      final errStr = e.toString();

      if (errStr.contains('CERTIFICATE_UNKNOWN') ||
          errStr.contains('268436502')) {
        // TV does not recognize our certificate — wipe token + cert so fresh pair happens
        print(
          '[REMOTE] TV rejected our certificate. Clearing pairing data for re-pair.',
        );
        device.pairingToken = null;
        try {
          final prefs = await SharedPreferences.getInstance();
          final raw = prefs.getString('tv_tokens');
          if (raw != null) {
            final tokens = Map<String, String>.from(jsonDecode(raw) as Map);
            tokens.remove(device.id);
            await prefs.setString('tv_tokens', jsonEncode(tokens));
          }
          // Regenerate certificate so TV gets a brand-new cert to pair with
          await _certMgr.regenerate();
          print('[REMOTE] Certificate regenerated. Please re-pair with TV.');
        } catch (_) {}
        onStatusChanged?.call(
          'TV does not recognize this device. Re-pairing required.',
        );
      } else if (errStr.contains('errno = 54') ||
          errStr.contains('Connection reset')) {
        onStatusChanged?.call('TV rejected connection. Try pairing again.');
      } else {
        onStatusChanged?.call('Connection failed');
      }
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  //  PAIRING (port 6467)
  // ═══════════════════════════════════════════════════════
  SecureSocket? _pairSock;
  Completer<bool>? _pairDone;
  final List<int> _pairBuf = [];
  bool _secretSent = false;
  int _pairStep = 0;

  BigInt? _serverModulus;
  BigInt? _serverExponent;

  Future<bool> startPairing() async {
    try {
      onStatusChanged?.call('Starting pairing...');
      _pairDone = Completer<bool>();
      _pairBuf.clear();
      _secretSent = false;
      _pairStep = 0;
      _serverModulus = null;
      _serverExponent = null;

      final ctx = await _getContext();
      _pairSock = await SecureSocket.connect(
        device.ip,
        _pairingPort,
        context: ctx,
        timeout: const Duration(seconds: 8),
        onBadCertificate: (cert) {
          try {
            final parsed = CertManager.parseServerCertDer(
              Uint8List.fromList(cert.der),
            );
            _serverModulus = parsed.$1;
            _serverExponent = parsed.$2;
            print(
              '[PAIR] Server cert OK: mod=${_serverModulus!.toRadixString(16).substring(0, 8)}...',
            );
          } catch (e) {
            print('[PAIR] Cert parse error: $e');
          }
          return true;
        },
      );

      print('[PAIR] Connected to $_pairingPort');

      _pairSock!.listen(
        _onPairData,
        onError: (e) {
          print('[PAIR] Error: $e');
          _completePair(false);
        },
        onDone: () {
          print('[PAIR] Closed');
          _completePair(false);
        },
        cancelOnError: false,
      );

      _sendPair(_buildPairingRequest());
      onStatusChanged?.call('Check TV for pairing code');
      return true;
    } catch (e) {
      print('[PAIR] startPairing failed: $e');
      onStatusChanged?.call('Cannot reach TV');
      _pairSock = null;
      return false;
    }
  }

  Future<bool> submitPairingCode(String code) async {
    if (_pairSock == null || _pairDone == null) return false;
    if (_serverModulus == null || _serverExponent == null) {
      onStatusChanged?.call('Missing server certificate');
      return false;
    }
    try {
      onStatusChanged?.call('Verifying...');
      _secretSent = true;
      print('[PAIR] Submitting code: $code');
      _sendPair(_buildPairingSecret(code));

      final ok = await _pairDone!.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );

      if (ok) {
        device.pairingToken = 'paired_${DateTime.now().millisecondsSinceEpoch}';
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('tv_tokens');
        final tokens = raw != null
            ? Map<String, String>.from(jsonDecode(raw) as Map)
            : <String, String>{};
        tokens[device.id] = device.pairingToken!;
        await prefs.setString('tv_tokens', jsonEncode(tokens));
        onStatusChanged?.call('Paired!');
        print('[PAIR] SUCCESS!');
      } else {
        onStatusChanged?.call('Wrong code');
        print('[PAIR] FAILED');
      }
      await _pairSock?.close();
      _pairSock = null;
      return ok;
    } catch (e) {
      print('[PAIR] submitPairingCode error: $e');
      await _pairSock?.close();
      _pairSock = null;
      return false;
    }
  }

  void _completePair(bool v) {
    if (_pairDone != null && !_pairDone!.isCompleted) _pairDone!.complete(v);
  }

  // ═══════════════════════════════════════════════════════
  //  SEND KEY
  // ═══════════════════════════════════════════════════════
  @override
  Future<void> sendKey(RemoteKey key) async {
    if (!_connected || _socket == null || !_handshakeComplete) {
      print('[REMOTE] Cannot send key - not ready');
      return;
    }
    final kc = _mapKey(key);
    if (kc == null) return;

    print('[REMOTE] Sending key $key (code=$kc)');

    if (key == RemoteKey.source) {
      // Send KEYCODE_TV_INPUT (178) as a proper DOWN and UP sequence.
      // We use a slightly longer delay (250ms) to ensure the TV OS registers the press.
      _sendRemote(_buildKeyInject(kc, 1)); // 1 = DOWN
      await Future.delayed(const Duration(milliseconds: 250));
      _sendRemote(_buildKeyInject(kc, 2)); // 2 = UP
    } else {
      // Standard key press: DOWN then UP
      _sendRemote(_buildKeyInject(kc, 1)); // DOWN
      await Future.delayed(const Duration(milliseconds: 80));
      _sendRemote(_buildKeyInject(kc, 2)); // UP
    }
  }

  @override
  Future<void> sendRawKeyCode(int keyCode) async {
    if (!_connected || _socket == null || !_handshakeComplete) {
      print('[REMOTE] Cannot send raw keycode - not ready');
      return;
    }
    print('[REMOTE] Sending raw keycode $keyCode');
    _sendRemote(_buildKeyInject(keyCode, 1)); // DOWN
    await Future.delayed(const Duration(milliseconds: 80));
    _sendRemote(_buildKeyInject(keyCode, 2)); // UP
  }

  @override
  Future<void> launchAppLink(String url) async {
    if (!_connected || _socket == null || !_handshakeComplete) {
      print('[REMOTE] Cannot launch app link - not ready');
      return;
    }
    print('[REMOTE] Launching app link: $url');
    final inner = _fStr(1, url);
    final msg = _fBytes(90, inner);
    _sendRemote(msg);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _handshakeComplete = false;
    await _socket?.close();
    _socket = null;
    await _pairSock?.close();
    _pairSock = null;
  }

  // ═══════════════════════════════════════════════════════
  //  PAIRING PROTOCOL MESSAGES
  // ═══════════════════════════════════════════════════════
  Uint8List _wrapPairing(Uint8List inner) {
    return _cat([_fVar(1, 2), _fVar(2, 200), inner]);
  }

  Uint8List _buildPairingRequest() {
    final info = _cat([
      _fStr(1, 'androidtvremote2'),
      _fStr(2, 'Universal Remote'),
    ]);
    return _wrapPairing(_fBytes(10, info));
  }

  Uint8List _buildPairingOption() {
    final enc = _cat([_fVar(1, 3), _fVar(2, 6)]);
    return _wrapPairing(
      _fBytes(20, _cat([_fBytes(1, enc), _fBytes(2, enc), _fVar(3, 1)])),
    );
  }

  Uint8List _buildPairingConfig() {
    final enc = _cat([_fVar(1, 3), _fVar(2, 6)]);
    return _wrapPairing(_fBytes(30, _cat([_fBytes(1, enc), _fVar(2, 1)])));
  }

  Uint8List _buildPairingSecret(String code) {
    final clientModHex = _certMgr.clientModulusHex;
    final clientExpHex = _certMgr.clientExponentHex;
    final serverModHex = _serverModulus!.toRadixString(16);
    final serverExpHex = _serverExponent!.toRadixString(16);

    String padHex(String h) => h.length.isOdd ? '0$h' : h;
    String padExp(String h) {
      final p = padHex(h);
      return p.length < 6 ? p.padLeft(6, '0') : p;
    }

    final data = <int>[];
    data.addAll(_hexToBytes(padHex(clientModHex)));
    data.addAll(_hexToBytes(padExp(clientExpHex)));
    data.addAll(_hexToBytes(padHex(serverModHex)));
    data.addAll(_hexToBytes(padExp(serverExpHex)));
    final codeNonce = code.length >= 6 ? code.substring(2) : code;
    data.addAll(_hexToBytes(padHex(codeNonce)));

    final digest = pc.SHA256Digest().process(Uint8List.fromList(data));
    final codeFirstByte = int.parse(code.substring(0, 2), radix: 16);
    print(
      '[PAIR] hash[0]=0x${digest[0].toRadixString(16)} code[0]=0x${codeFirstByte.toRadixString(16)} match=${digest[0] == codeFirstByte}',
    );

    return _wrapPairing(_fBytes(40, _cat([_fBytes(1, digest)])));
  }

  // ═══════════════════════════════════════════════════════
  //  REMOTE PROTOCOL MESSAGES (per remotemessage.proto)
  // ═══════════════════════════════════════════════════════
  // RemoteMessage fields: 1=Configure, 2=SetActive, 8=PingReq, 9=PingResp, 10=KeyInject

  Uint8List _buildRemoteConfig() {
    // RemoteConfigure { code1=622, device_info={...} }
    final di = _cat([
      _fStr(1, 'iPhone'), // model
      _fStr(2, 'Apple'), // vendor
      _fVar(3, 1), // unknown1
      _fStr(4, '1'), // unknown2
      _fStr(5, 'com.uni.rem'), // package_name
      _fStr(6, '1.0.0'), // app_version
    ]);
    final rc = _cat([_fVar(1, 622), _fBytes(2, di)]);
    return _fBytes(1, rc); // field 1 = remote_configure
  }

  Uint8List _buildSetActive() {
    // RemoteSetActive { active=622 }
    return _fBytes(2, _cat([_fVar(1, 622)])); // field 2 = remote_set_active
  }

  Uint8List _buildKeyInject(int keyCode, int dir) {
    // RemoteKeyInject { key_code, direction }
    final ki = _cat([_fVar(1, keyCode), _fVar(2, dir)]);
    return _fBytes(10, ki); // field 10 = remote_key_inject
  }

  Uint8List _buildPingResponse(int val) {
    // RemotePingResponse { val1 }
    return _fBytes(9, _cat([_fVar(1, val)])); // field 9 = remote_ping_response
  }

  // ═══════════════════════════════════════════════════════
  //  SEND HELPERS - 1-byte length prefix for BOTH protocols
  // ═══════════════════════════════════════════════════════
  void _sendRemote(Uint8List msg) {
    if (_socket == null) return;
    print('[REMOTE] Sending ${msg.length}B');
    _socket!.add(Uint8List.fromList([msg.length, ...msg]));
  }

  void _sendPair(Uint8List msg) {
    if (_pairSock == null) return;
    print('[PAIR] Sending ${msg.length}B');
    _pairSock!.add(Uint8List.fromList([msg.length, ...msg]));
  }

  // ═══════════════════════════════════════════════════════
  //  DATA HANDLERS - 1-byte length prefix framing
  // ═══════════════════════════════════════════════════════
  final List<int> _remoteBuf = [];

  void _onRemoteData(Uint8List data) {
    _remoteBuf.addAll(data);

    while (_remoteBuf.isNotEmpty) {
      final msgLen = _remoteBuf[0];
      if (msgLen <= 0 || _remoteBuf.length < 1 + msgLen) break;

      final msg = Uint8List.fromList(_remoteBuf.sublist(1, 1 + msgLen));
      _remoteBuf.removeRange(0, 1 + msgLen);

      if (msg.isEmpty) continue;

      // Parse protobuf field tag (first byte)
      final fieldTag = msg[0];
      final fieldNum = fieldTag >> 3;

      print('[REMOTE] Recv ${msg.length}B field=$fieldNum');

      switch (fieldNum) {
        case 1: // RemoteConfigure from TV
          print('[REMOTE] <- remoteConfigure, replying with our config');
          _sendRemote(_buildRemoteConfig());
          break;

        case 2: // RemoteSetActive from TV
          print('[REMOTE] <- remoteSetActive, replying');
          _sendRemote(_buildSetActive());
          _handshakeComplete = true;
          onStatusChanged?.call('Connected');
          onConnectionStateChanged?.call(); // ← notify UI that isConnected is now true
          if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
            _handshakeCompleter!.complete(true);
          }
          print('[REMOTE] Handshake complete! Ready for commands.');
          break;

        case 8: // RemotePingRequest
          int pingVal = 0;
          // Extract val1 from ping request
          if (msg.length >= 4) {
            final inner = msg.sublist(2);
            if (inner.isNotEmpty && (inner[0] >> 3) == 1) {
              pingVal = inner.length > 1 ? inner[1] : 0;
            }
          }
          print('[REMOTE] <- ping($pingVal), responding');
          _sendRemote(_buildPingResponse(pingVal));
          break;

        case 40: // RemoteStart (powered state)
          print('[REMOTE] <- remoteStart (power state)');
          break;

        case 50: // RemoteSetVolumeLevel
          print('[REMOTE] <- volume level');
          break;

        default:
          print('[REMOTE] <- unknown field $fieldNum');
      }
    }
  }

  void _onPairData(Uint8List data) {
    _pairBuf.addAll(data);

    while (_pairBuf.isNotEmpty) {
      final msgLen = _pairBuf[0];
      if (msgLen <= 0 || _pairBuf.length < 1 + msgLen) break;

      final msg = Uint8List.fromList(_pairBuf.sublist(1, 1 + msgLen));
      _pairBuf.removeRange(0, 1 + msgLen);
      _handlePairMessage(msg);
    }
  }

  void _handlePairMessage(Uint8List msg) {
    print('[PAIR] Recv ${msg.length}B step=$_pairStep');
    final ok = _hasStatus200(msg);

    if (!_secretSent) {
      if (_pairStep == 0 && ok) {
        _pairStep = 1;
        print('[PAIR] -> PairingOption');
        _sendPair(_buildPairingOption());
      } else if (_pairStep == 1 && ok) {
        _pairStep = 2;
        print('[PAIR] -> PairingConfig');
        _sendPair(_buildPairingConfig());
      } else if (_pairStep == 2 && ok) {
        _pairStep = 3;
        print('[PAIR] TV should show code now');
      }
    } else {
      print('[PAIR] Secret response: ok=$ok');
      _completePair(ok);
    }
  }

  bool _hasStatus200(Uint8List d) {
    for (int i = 0; i < d.length - 2; i++) {
      if (d[i] == 0x10 && d[i + 1] == 0xC8 && d[i + 2] == 0x01) return true;
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════
  //  UTILS
  // ═══════════════════════════════════════════════════════
  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  Uint8List _fVar(int field, int value) =>
      Uint8List.fromList([..._vi((field << 3) | 0), ..._vi(value)]);

  Uint8List _fBytes(int field, List<int> data) => Uint8List.fromList([
    ..._vi((field << 3) | 2),
    ..._vi(data.length),
    ...data,
  ]);

  Uint8List _fStr(int field, String s) => _fBytes(field, utf8.encode(s));

  Uint8List _cat(List<Uint8List> parts) {
    final b = <int>[];
    for (final p in parts) {
      b.addAll(p);
    }
    return Uint8List.fromList(b);
  }

  List<int> _vi(int v) {
    final b = <int>[];
    while (v > 0x7F) {
      b.add((v & 0x7F) | 0x80);
      v >>= 7;
    }
    b.add(v & 0x7F);
    return b;
  }

  // ═══════════════════════════════════════════════════════
  //  KEY MAP
  // ═══════════════════════════════════════════════════════
  int? _mapKey(RemoteKey key) {
    const m = {
      RemoteKey.power: 26,
      RemoteKey.up: 19,
      RemoteKey.down: 20,
      RemoteKey.left: 21,
      RemoteKey.right: 22,
      RemoteKey.enter: 23,
      RemoteKey.back: 4,
      RemoteKey.home: 3,
      RemoteKey.volumeUp: 24,
      RemoteKey.volumeDown: 25,
      RemoteKey.mute: 164,
      RemoteKey.channelUp: 166,
      RemoteKey.channelDown: 167,
      RemoteKey.menu: 82,
      RemoteKey.source: 178,
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
    return m[key];
  }
}
