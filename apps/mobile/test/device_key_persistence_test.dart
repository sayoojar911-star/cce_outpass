import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cce_outpass/qr_token.dart';
import 'package:cce_outpass/app_state.dart';
import 'package:cce_outpass/api_client.dart';
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

    test('AppState reuses existing device key from secure storage on repeated logins', () async {
      final fakeStorage = FakeSecureStorage();
      final state1 = AppState(storage: fakeStorage, api: ApiClient(isDemoMode: true));

      await state1.loginDemoMobile('9074121510');
      final firstKeyPem = state1.deviceKeys!.publicKeyPem();
      final storedKey = await fakeStorage.read(key: AppState.storageKeyForUser('9074121510'));
      expect(storedKey, isNotNull);

      // Simulate app restart / new AppState instance with the same persistent storage
      final state2 = AppState(storage: fakeStorage, api: ApiClient(isDemoMode: true));
      await state2.loginDemoMobile('9074121510');
      final secondKeyPem = state2.deviceKeys!.publicKeyPem();

      expect(secondKeyPem, equals(firstKeyPem),
          reason: 'Existing device key must be reused across app restarts');
    });

    test('AppState handles corrupt storage gracefully by generating new key', () async {
      final fakeStorage = FakeSecureStorage();
      await fakeStorage.write(
        key: AppState.storageKeyForUser('9074121510'),
        value: 'corrupt-not-a-valid-pem',
      );

      final state = AppState(storage: fakeStorage, api: ApiClient(isDemoMode: true));
      await state.loginDemoMobile('9074121510');

      expect(state.deviceKeys, isNotNull);
      expect(state.deviceKeys!.publicKeyPem(), startsWith('-----BEGIN PUBLIC KEY-----'));
    });

    test('AppState does not crash if storage read or write throws', () async {
      final fakeStorage = FakeSecureStorage();
      fakeStorage.throwOnRead = true;
      fakeStorage.throwOnWrite = true;

      final state = AppState(storage: fakeStorage, api: ApiClient(isDemoMode: true));
      await state.loginDemoMobile('9074121510');

      expect(state.deviceKeys, isNotNull);
      expect(state.deviceKeys!.publicKeyPem(), startsWith('-----BEGIN PUBLIC KEY-----'));
    });
  });
}
