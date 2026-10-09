import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'qr_token.dart';

/// Session state: one user, one role per login (PRD §2.1).
class AppState extends ChangeNotifier {
  AppState({FlutterSecureStorage? storage, ApiClient? api})
      : storage = storage ?? const FlutterSecureStorage(),
        api = api ?? ApiClient();

  final ApiClient api;
  final FlutterSecureStorage storage;

  String? userId;
  String? userName;
  String? userRole;
  String? userMobile;
  String? userDepartment;
  String? refreshToken;
  DeviceKeys? deviceKeys;

  bool get loggedIn => userRole != null;
  bool get isStudent => userRole == 'STUDENT';
  bool get isTutor => userRole == 'TUTOR';
  bool get isHod => userRole == 'HOD';
  bool get isGuard => userRole == 'GUARD';
  bool get isAdmin => userRole == 'ADMIN';

  static String storageKeyForUser(String mobile) => 'cce_device_privkey_$mobile';
  static const String _refreshTokenKey = 'cce_refresh_token';
  static const String _userMobileKey = 'cce_user_mobile';

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

  /// Send OTP to mobile number.
  Future<void> sendOtp(String mobile) async {
    await api.sendOtp(mobile);
  }

  /// Verify OTP, get user data and JWT, register device.
  Future<void> verifyOtpAndLogin(String mobile, String code) async {
    final user = await api.verifyOtp(mobile, code);
    userId = user['id'] as String?;
    userName = user['name'] as String?;
    userRole = user['role'] as String?;
    userMobile = user['mobile'] as String?;
    userDepartment = user['department'] as String?;

    // Persist refresh token for session recovery
    try {
      await storage.write(key: _refreshTokenKey, value: api.accessToken);
      await storage.write(key: _userMobileKey, value: userMobile);
    } catch (_) {}

    deviceKeys = await _loadOrCreateDeviceKeys(userMobile ?? mobile);

    // Device binding (PRD §10.3): key is registered server-side; scans are
    // verified against this key and DEVICE_REVOKED after revocation.
    await api.registerDevice(deviceKeys!.publicKeyPem(), 'web');
    notifyListeners();
  }

  void logout() {
    userId = null;
    userName = null;
    userRole = null;
    userMobile = null;
    userDepartment = null;
    refreshToken = null;
    deviceKeys = null;
    api.accessToken = null;
    // Clear persisted session
    try {
      storage.delete(key: _refreshTokenKey);
      storage.delete(key: _userMobileKey);
    } catch (_) {}
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
