import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'qr_token.dart';

/// Session state: one user, one role per login (PRD §2.1 role switcher is a
/// later phase — the MVP seeds separate staff accounts).
class AppState extends ChangeNotifier {
  AppState({FlutterSecureStorage? storage, ApiClient? api})
      : storage = storage ?? const FlutterSecureStorage(),
        api = api ?? ApiClient();

  final ApiClient api;
  final FlutterSecureStorage storage;

  String? userName;
  String? userRole;
  String? userMobile;
  DeviceKeys? deviceKeys;

  bool get loggedIn => userRole != null;
  bool get isStudent => userRole == 'STUDENT';
  bool get isTutor => userRole == 'TUTOR';
  bool get isHod => userRole == 'HOD';
  bool get isGuard => userRole == 'GUARD';

  static String storageKeyForUser(String mobile) => 'cce_device_privkey_$mobile';

  Future<DeviceKeys> _loadOrCreateDeviceKeys(String mobile) async {
    final storageKey = storageKeyForUser(mobile);
    try {
      final storedPem = await storage.read(key: storageKey);
      if (storedPem != null && storedPem.trim().isNotEmpty) {
        try {
          return DeviceKeys.fromPrivateKeyPem(storedPem);
        } catch (e) {
          debugPrint('Failed to parse stored device key, regenerating: $e');
        }
      }
    } catch (e) {
      debugPrint('Failed reading secure storage: $e');
    }

    final newKeys = DeviceKeys.generate();
    try {
      await storage.write(key: storageKey, value: newKeys.privateKeyPkcs8Pem());
    } catch (e) {
      debugPrint('Failed writing secure storage: $e');
    }
    return newKeys;
  }

  Future<void> loginWithFirebaseToken(String idToken) async {
    final user = await api.verifyFirebasePhone(idToken);
    userName = user['name'] as String?;
    userRole = user['role'] as String?;
    userMobile = user['mobile'] as String?;

    final mobile = userMobile ?? '';
    deviceKeys = await _loadOrCreateDeviceKeys(mobile);

    // Device binding (PRD §10.3): key is registered server-side; scans are
    // verified against this key and DEVICE_REVOKED after revocation.
    await api.registerDevice(deviceKeys!.publicKeyPem(), 'web');
    notifyListeners();
  }

  Future<void> loginDemoMobile(String mobile) async {
    final user = await api.verifyFirebasePhone('mock-token:$mobile');
    userName = user['name'] as String?;
    userRole = user['role'] as String?;
    userMobile = user['mobile'] as String?;

    deviceKeys = await _loadOrCreateDeviceKeys(userMobile ?? mobile);
    await api.registerDevice(deviceKeys!.publicKeyPem(), 'web');
    notifyListeners();
  }

  void logout() {
    userName = null;
    userRole = null;
    userMobile = null;
    deviceKeys = null;
    api.accessToken = null;
    notifyListeners();
  }
}

/// Makes [AppState] reachable from any widget and rebuilds dependents on change.
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStateScope>()!.notifier!;
}
