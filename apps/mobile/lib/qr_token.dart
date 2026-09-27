import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:pointycastle/export.dart';

/// Device signing keys + QR token construction (PRD §7.2, §7.3).
///
/// v1.<outpass_id>.<ts>.<signature>
///   ts: unix seconds rounded to a 30 s step
///   signature: ECDSA P-256 / SHA-256 over "v1.<outpass_id>.<ts>", DER, base64url
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
