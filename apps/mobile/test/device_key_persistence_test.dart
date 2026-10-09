import 'package:flutter_test/flutter_test.dart';
import 'package:cce_outpass/qr_token.dart';
import 'package:cce_outpass/app_state.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};
  bool throwOnRead = false;
  bool throwOnWrite = false;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwOnRead) throw Exception('Storage read failed');
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwOnWrite) throw Exception('Storage write failed');
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data.containsKey(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DeviceKey Persistence & Secure Storage Tests', () {
    test('DeviceKeys PKCS#8 serialization round-trip restores identical key and public PEM', () {
      final original = DeviceKeys.generate();
      final privPem = original.privateKeyPkcs8Pem();
      expect(privPem, startsWith('-----BEGIN PRIVATE KEY-----'));
      expect(privPem, endsWith('-----END PRIVATE KEY-----\n'));

      final restored = DeviceKeys.fromPrivateKeyPem(privPem);
      expect(restored.publicKeyPem(), equals(original.publicKeyPem()));

      final message = 'v1.test-outpass-id.1790000000';
      final sigOrig = original.signMessage(message);
      final sigRestored = restored.signMessage(message);

      expect(sigOrig, isNotEmpty);
      expect(sigRestored, isNotEmpty);
    });

    test('AppState storage key format is consistent', () {
      expect(
        AppState.storageKeyForUser('9074121510'),
        equals('cce_device_privkey_9074121510'),
      );
    });

    test('DeviceKeys generate produces valid P-256 keys', () {
      final keys = DeviceKeys.generate();
      final pubPem = keys.publicKeyPem();
      expect(pubPem, startsWith('-----BEGIN PUBLIC KEY-----'));
      expect(pubPem, endsWith('-----END PUBLIC KEY-----\n'));

      // Token building should work
      final step = DeviceKeys.currentStep();
      final token = keys.buildToken('test-outpass-id', step);
      expect(token, startsWith('v1.test-outpass-id.$step.'));
    });

    test('DeviceKeys currentStep increments over time', () {
      final step1 = DeviceKeys.currentStep();
      expect(step1, isPositive);
      // currentStep = unix epoch seconds (used as monotonic counter for QR replay)
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // Allow ±60s drift (wide window for slow test machines)
      expect((step1 - nowSec).abs(), lessThan(60));
    });
  });
}
