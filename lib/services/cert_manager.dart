import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart' as pc;
import 'package:basic_utils/basic_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Generates and persists a self-signed X.509 client certificate + RSA key pair.
class CertManager {
  static const _prefKeyPem = 'atv_client_cert_pem';
  static const _prefKeyKey = 'atv_client_key_pem';

  String? _certPem;
  String? _keyPem;
  BigInt? _modulus;
  BigInt? _exponent;

  String? get certPem => _certPem;
  String? get keyPem => _keyPem;

  /// Client cert RSA modulus as hex string.
  String get clientModulusHex => _modulus!.toRadixString(16);

  /// Client cert RSA public exponent as hex string.
  String get clientExponentHex => _exponent!.toRadixString(16);

  Future<void> ensureReady() async {
    final prefs = await SharedPreferences.getInstance();
    _certPem = prefs.getString(_prefKeyPem);
    _keyPem = prefs.getString(_prefKeyKey);

    if (_certPem != null && _keyPem != null) {
      _extractKeysFromPrivateKey(_keyPem!);
      return;
    }

    final secureRandom = _buildSecureRandom();
    final keyGen = pc.RSAKeyGenerator()
      ..init(
        pc.ParametersWithRandom(
          pc.RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
          secureRandom,
        ),
      );

    final pair = keyGen.generateKeyPair();
    final pubKey = pair.publicKey;
    final privKey = pair.privateKey;
    _modulus = pubKey.modulus;
    _exponent = pubKey.publicExponent;

    final dn = {'CN': 'atvremote', 'O': 'AtvRemote'};
    final csr = X509Utils.generateRsaCsrPem(dn, privKey, pubKey);
    _certPem = X509Utils.generateSelfSignedCertificate(
      privKey,
      csr,
      365 * 10,
      serialNumber: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    _keyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privKey);

    await prefs.setString(_prefKeyPem, _certPem!);
    await prefs.setString(_prefKeyKey, _keyPem!);
  }

  void _extractKeysFromPrivateKey(String keyPem) {
    final privKey = CryptoUtils.rsaPrivateKeyFromPem(keyPem);
    _modulus = privKey.modulus;
    _exponent = privKey.publicExponent;
  }

  SecurityContext buildContext() {
    final ctx = SecurityContext(withTrustedRoots: false);
    ctx.useCertificateChainBytes(_certPem!.codeUnits);
    ctx.usePrivateKeyBytes(_keyPem!.codeUnits);
    return ctx;
  }

  /// Clears the stored cert/key and forces regeneration on next [ensureReady].
  Future<void> regenerate() async {
    _certPem = null;
    _keyPem = null;
    _modulus = null;
    _exponent = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyPem);
    await prefs.remove(_prefKeyKey);
    await ensureReady(); // generate fresh key pair immediately
  }

  pc.SecureRandom _buildSecureRandom() {
    final sr = pc.FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    sr.seed(pc.KeyParameter(Uint8List.fromList(seeds)));
    return sr;
  }

  /// Parse RSA modulus+exponent (as BigInt) from a DER-encoded X.509 cert.
  static (BigInt, BigInt) parseServerCertDer(Uint8List der) {
    // ASN.1 DER manual parse to extract RSA modulus and exponent.
    // X.509 cert → TBSCertificate → SubjectPublicKeyInfo → BIT STRING → RSA key
    return _parseRsaFromDer(der);
  }

  /// Brute-force ASN.1 parse: find the SubjectPublicKeyInfo RSA key in DER.
  static (BigInt, BigInt) _parseRsaFromDer(Uint8List der) {
    // The SubjectPublicKeyInfo contains a BIT STRING wrapping a SEQUENCE of
    // (modulus INTEGER, exponent INTEGER). We search for the RSA OID
    // 1.2.840.113549.1.1.1 = 06 09 2A 86 48 86 F7 0D 01 01 01
    final rsaOid = [
      0x06,
      0x09,
      0x2A,
      0x86,
      0x48,
      0x86,
      0xF7,
      0x0D,
      0x01,
      0x01,
      0x01,
    ];
    int oidPos = -1;
    for (int i = 0; i <= der.length - rsaOid.length; i++) {
      bool match = true;
      for (int j = 0; j < rsaOid.length; j++) {
        if (der[i + j] != rsaOid[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        oidPos = i;
        break;
      }
    }
    if (oidPos < 0) throw Exception('RSA OID not found in cert');

    // After the AlgorithmIdentifier SEQUENCE, there's a BIT STRING containing
    // a SEQUENCE { INTEGER modulus, INTEGER exponent }.
    // Search forward from oidPos for BIT STRING tag (0x03).
    int pos = oidPos + rsaOid.length;
    // Skip NULL after OID (if present)
    while (pos < der.length && der[pos] != 0x03) {
      pos++;
    }
    if (pos >= der.length) throw Exception('BIT STRING not found');
    pos++; // skip 0x03 tag
    final bsLen = _readDerLength(der, pos);
    pos += bsLen.$2; // skip length bytes
    pos++; // skip unused-bits byte (0x00)

    // Now we should be at a SEQUENCE
    if (der[pos] != 0x30) throw Exception('Expected SEQUENCE in BIT STRING');
    pos++; // skip 0x30
    final seqLen = _readDerLength(der, pos);
    pos += seqLen.$2;

    // First INTEGER = modulus
    if (der[pos] != 0x02) throw Exception('Expected INTEGER (modulus)');
    pos++;
    final modLen = _readDerLength(der, pos);
    pos += modLen.$2;
    final modBytes = der.sublist(pos, pos + modLen.$1);
    pos += modLen.$1;

    // Second INTEGER = exponent
    if (der[pos] != 0x02) throw Exception('Expected INTEGER (exponent)');
    pos++;
    final expLen = _readDerLength(der, pos);
    pos += expLen.$2;
    final expBytes = der.sublist(pos, pos + expLen.$1);

    final modulus = _bytesToBigInt(modBytes);
    final exponent = _bytesToBigInt(expBytes);
    return (modulus, exponent);
  }

  /// Read DER length. Returns (length, bytesConsumed).
  static (int, int) _readDerLength(Uint8List data, int offset) {
    final first = data[offset];
    if (first < 0x80) return (first, 1);
    final numBytes = first & 0x7F;
    int length = 0;
    for (int i = 0; i < numBytes; i++) {
      length = (length << 8) | data[offset + 1 + i];
    }
    return (length, 1 + numBytes);
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }
}
