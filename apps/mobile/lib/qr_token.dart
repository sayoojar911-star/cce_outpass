import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:pointycastle/export.dart';

/// Device signing keys + QR token construction (PRD §7.2, §7.3).
/// `v1.<outpass_id>.<ts>.<signature>`
///   ts: unix seconds rounded to a 30 s step
///   signature: ECDSA P-256 / SHA-256 over `v1.<outpass_id>.<ts>`, DER, base64url
///
/// MVP note (docs/decisions.md #3): keys are software-generated with
/// pointycastle. Native targets should swap this for Keystore / Secure Enclave
/// with attestation before production.

const int kTokenStepSeconds = 30;

class DeviceKeys {
  DeviceKeys(this._pair);
  final AsymmetricKeyPair<PublicKey, PrivateKey> _pair;

  late final ECPublicKey _pub = _pair.publicKey as ECPublicKey;
  late final ECPrivateKey _priv = _pair.privateKey as ECPrivateKey;

  static DeviceKeys generate() {
    final domain = ECDomainParameters('prime256v1');
    final seed = Uint8List(32);
    final secure = Random.secure();
    for (var i = 0; i < 32; i++) {
      seed[i] = secure.nextInt(256);
    }
    final rnd = FortunaRandom()..seed(KeyParameter(seed));
    final gen = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(domain), rnd));
    return DeviceKeys(gen.generateKeyPair());
  }

  /// SPKI PEM of the public key — exactly what the backend stores.
  String publicKeyPem() {
    // id-ecPublicKey 1.2.840.10045.2.1, prime256v1 1.2.840.10045.3.1.7
    final algId = ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromComponentString('1.2.840.10045.2.1'))
      ..add(ASN1ObjectIdentifier.fromComponentString('1.2.840.10045.3.1.7'));
    final spki = ASN1Sequence()
      ..add(algId)
      ..add(ASN1BitString(_pub.Q!.getEncoded(false)));
    final der = spki.encodedBytes;
    final b64 = base64.encode(der);
    final lines = <String>[];
    for (var i = 0; i < b64.length; i += 64) {
      lines.add(b64.substring(i, min(i + 64, b64.length)));
    }
    return '-----BEGIN PUBLIC KEY-----\n${lines.join('\n')}\n-----END PUBLIC KEY-----\n';
  }

  /// PKCS#8 PEM of the private key for secure local persistence.
  String privateKeyPkcs8Pem() {
    final algId = ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromComponentString('1.2.840.10045.2.1'))
      ..add(ASN1ObjectIdentifier.fromComponentString('1.2.840.10045.3.1.7'));

    // RFC 5915 ECPrivateKey: version(1), privateKey(OCTET STRING)
    final privBytes = _bigIntTo32Bytes(_priv.d!);
    final ecPrivKey = ASN1Sequence()
      ..add(ASN1Integer(BigInt.one))
      ..add(ASN1OctetString(privBytes))
      ..add(ASN1BitString(_pub.Q!.getEncoded(false), tag: 0xA1));

    // PKCS#8 OneAsymmetricKey: version(0), privateKeyAlgorithm, privateKey
    final pkcs8 = ASN1Sequence()
      ..add(ASN1Integer(BigInt.zero))
      ..add(algId)
      ..add(ASN1OctetString(ecPrivKey.encodedBytes));

    final der = pkcs8.encodedBytes;
    final b64 = base64.encode(der);
    final lines = <String>[];
    for (var i = 0; i < b64.length; i += 64) {
      lines.add(b64.substring(i, min(i + 64, b64.length)));
    }
    return '-----BEGIN PRIVATE KEY-----\n${lines.join('\n')}\n-----END PRIVATE KEY-----\n';
  }

  /// Restores a [DeviceKeys] instance from a stored PKCS#8 PEM.
  static DeviceKeys fromPrivateKeyPem(String pem) {
    final clean = pem
        .replaceAll('-----BEGIN PRIVATE KEY-----', '')
        .replaceAll('-----END PRIVATE KEY-----', '')
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .trim();
    final der = base64.decode(clean);
    final p = ASN1Parser(der);
    final topSeq = p.nextObject() as ASN1Sequence;
    final privKeyOctet = topSeq.elements[2] as ASN1OctetString;

    final innerParser = ASN1Parser(privKeyOctet.valueBytes());
    final innerSeq = innerParser.nextObject() as ASN1Sequence;
    final dOctets = innerSeq.elements[1] as ASN1OctetString;
    final d = _bytesToBigInt(dOctets.valueBytes());

    final domain = ECDomainParameters('prime256v1');
    final q = domain.G * d;

    final privKey = ECPrivateKey(d, domain);
    final pubKey = ECPublicKey(q, domain);
    return DeviceKeys(AsymmetricKeyPair<PublicKey, PrivateKey>(pubKey, privKey));
  }

  static Uint8List _bigIntTo32Bytes(BigInt number) {
    var hex = number.toRadixString(16);
    if (hex.length % 2 != 0) hex = '0$hex';
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    final result = Uint8List(32);
    if (bytes.length > 32) {
      result.setRange(0, 32, bytes.sublist(bytes.length - 32));
    } else {
      result.setRange(32 - bytes.length, 32, bytes);
    }
    return result;
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    if (hex.isEmpty) return BigInt.zero;
    return BigInt.parse(hex, radix: 16);
  }

  /// Current unix time rounded down to the token step.
  static int currentStep() =>
      (DateTime.now().millisecondsSinceEpoch ~/ 1000) ~/ kTokenStepSeconds *
          kTokenStepSeconds;

  String signMessage(String message) {
    final rnd = FortunaRandom()..seed(KeyParameter(_randomSeed()));
    final signer = ECDSASigner(SHA256Digest())
      ..init(true, ParametersWithRandom(PrivateKeyParameter<ECPrivateKey>(_priv), rnd));
    final sig = signer.generateSignature(Uint8List.fromList(utf8.encode(message))) as ECSignature;
    final der = ASN1Sequence()
      ..add(ASN1Integer(sig.r))
      ..add(ASN1Integer(sig.s));
    return base64Url.encode(der.encodedBytes).replaceAll('=', '');
  }

  String buildToken(String outpassId, int tsSec) {
    final message = 'v1.$outpassId.$tsSec';
    return '$message.${signMessage(message)}';
  }

  static Uint8List _randomSeed() {
    final seed = Uint8List(32);
    final secure = Random.secure();
    for (var i = 0; i < 32; i++) {
      seed[i] = secure.nextInt(256);
    }
    return seed;
  }
}
