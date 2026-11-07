import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'qr_token.dart';
import 'role_service.dart';

/// Central Session and Configuration state for CCE Outpass.
/// Single source of truth for dynamic DB-backed roles, permissions, and settings.
class AppState extends ChangeNotifier {
  AppState({FlutterSecureStorage? storage, ApiClient? api})
      : storage = storage ?? const FlutterSecureStorage(),
        api = api ?? ApiClient();

  final ApiClient api;
  final FlutterSecureStorage storage;

  // Authenticated User Identity
  String? userId;
  String? userName;
  String? userEmail;
  String? userMobile;
  String? userRoleId;
  String? userRoleName;
  String? userRole; // legacy role field
  List<String> userPermissions = [];
  String? userDepartmentId;
  String? userDepartment;
  int? userYear;
  String? userDivision;
  String? userTutorId;
  String? userPhotoUrl;
  String? refreshToken;
  DeviceKeys? deviceKeys;

  // Dynamic Database Configuration (Loaded from backend DB)
  List<dynamic> roles = [];
  List<dynamic> departments = [];
  List<dynamic> purposeCategories = [
    {'id': 'cat-medical', 'label': 'Medical', 'active': true},
    {'id': 'cat-personal', 'label': 'Personal', 'active': true},
    {'id': 'cat-official', 'label': 'Official', 'active': true},
    {'id': 'cat-academic', 'label': 'Academic', 'active': true},
    {'id': 'cat-emergency', 'label': 'Emergency', 'active': true},
  ];
  List<dynamic> outpassTypes = [
    {
      'id': 'normal',
      'label': 'Normal (Tutor -> HOD)',
      'approvalChain': ['tutor', 'hod'],
      'requiresExplanation': false,
      'active': true,
    },
    {
      'id': 'emergency',
      'label': 'Emergency (Direct to HOD)',
      'approvalChain': ['hod'],
      'requiresExplanation': true,
      'active': true,
    },
  ];
  Map<String, dynamic> settings = {};
  bool isConfigLoaded = false;

  // Permission & Role Status Checks via RoleService
  bool get loggedIn => userId != null || userRole != null || userRoleId != null;
  bool get isPending => RoleService.isPending(this);
  bool get canCreateOutpass => RoleService.canCreateOutpass(this);
  bool get canApproveOutpass => RoleService.canApproveOutpass(this);
  bool get canScanGate => RoleService.canScanGate(this);
  bool get canManageUsers => RoleService.canManageUsers(this);
  bool get canManageRoles => RoleService.canManageRoles(this);
  bool get canAccessAdmin => RoleService.canAccessAdmin(this);

  // Backward-compatible role flags (mapped to permission / roleId)
  bool get isStudent => canCreateOutpass;
  bool get isTutor => canApproveOutpass && (userRoleId == 'tutor' || userRole == 'TUTOR');
  bool get isHod => canApproveOutpass && (userRoleId == 'hod' || userRole == 'HOD');
  bool get isGuard => canScanGate;
  bool get isAdmin => canAccessAdmin;

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

  /// Loads all database-driven dynamic configurations from the backend.
  Future<void> loadConfig() async {
    try {
      final config = await api.getAllConfig();
      roles = (config['roles'] as List?)?.cast<dynamic>() ?? [];
      departments = (config['departments'] as List?)?.cast<dynamic>() ?? [];
      purposeCategories = (config['purposeCategories'] as List?)?.cast<dynamic>() ?? [];
      outpassTypes = (config['outpassTypes'] as List?)?.cast<dynamic>() ?? [];
      settings = (config['settings'] as Map?)?.cast<String, dynamic>() ?? {};
      isConfigLoaded = true;
      debugPrint(
        '[AppState] Config loaded: ${roles.length} roles, ${departments.length} depts, '
        '${purposeCategories.length} categories, ${outpassTypes.length} outpass types',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[AppState] Failed to load dynamic config: $e');
    }
  }

  /// Send OTP to mobile number.
  Future<void> sendOtp(String mobile) async {
    await api.sendOtp(mobile);
  }

  /// Send OTP for new student registration.
  Future<void> sendSignupOtp(String mobile) async {
    await api.sendSignupOtp(mobile);
  }

  /// Verify OTP for new student registration.
  Future<Map<String, dynamic>> verifySignupOtp(String mobile, String code) async {
    return await api.verifySignupOtp(mobile, code);
  }

  /// Register student and log in immediately.
  Future<Map<String, dynamic>> registerStudent({
    required String idToken,
    required String name,
    required String rollNo,
    required int year,
    required String department,
    required String photo,
  }) async {
    final res = await api.registerStudent(
      idToken: idToken,
      name: name,
      rollNo: rollNo,
      year: year,
      department: department,
      photo: photo,
    );
    final user = (res['user'] as Map).cast<String, dynamic>();
    _populateUserData(user);

    try {
      await storage.write(key: _refreshTokenKey, value: api.accessToken);
      await storage.write(key: _userMobileKey, value: userMobile);
    } catch (_) {}

    deviceKeys = await _loadOrCreateDeviceKeys(userMobile ?? '');
    final keys = deviceKeys;
    if (keys != null) {
      try {
        await api.registerDevice(keys.publicKeyPem(), 'web');
      } catch (_) {}
    }

    await loadConfig();
    notifyListeners();
    return res;
  }

  /// Verify OTP, get user data and JWT, load dynamic DB config, register device.
  Future<void> verifyOtpAndLogin(String mobile, String code) async {
    final user = await api.verifyOtp(mobile, code);
    _populateUserData(user);

    // Persist refresh token for session recovery
    try {
      await storage.write(key: _refreshTokenKey, value: api.accessToken);
      await storage.write(key: _userMobileKey, value: userMobile);
    } catch (_) {}

    deviceKeys = await _loadOrCreateDeviceKeys(userMobile ?? mobile);

    final keys = deviceKeys;
    if (keys != null) {
      await api.registerDevice(keys.publicKeyPem(), 'web');
    }

    // Always fetch latest dynamic DB configurations upon authentication
    await loadConfig();

    notifyListeners();
  }

  /// Attempts to restore user session from stored refresh token and mobile number.
  /// Runs in parallel with startup splash animation.
  Future<bool> tryAutoLogin() async {
    try {
      final token = await storage.read(key: _refreshTokenKey).timeout(const Duration(seconds: 2));
      final mobile = await storage.read(key: _userMobileKey).timeout(const Duration(seconds: 2));
      if (token != null && token.isNotEmpty) {
        api.accessToken = token;
        final user = await api.me().timeout(const Duration(seconds: 3));
        _populateUserData(user);
        if (mobile != null && mobile.isNotEmpty) {
          deviceKeys = await _loadOrCreateDeviceKeys(mobile);
        }
        await loadConfig().timeout(const Duration(seconds: 3));
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[AppState] Auto-login failed: $e');
      api.accessToken = null;
    }
    return false;
  }

  /// Refreshes user profile and permissions from `/auth/me` without re-authenticating.
  Future<void> refreshProfile() async {
    if (api.accessToken == null) return;
    try {
      final user = await api.me();
      _populateUserData(user);
      await loadConfig();
      notifyListeners();
    } catch (e) {
      debugPrint('[AppState] Failed to refresh profile: $e');
    }
  }

  void _populateUserData(Map<String, dynamic> user) {
    userId = user['id'] as String?;
    userName = user['name'] as String?;
    userEmail = user['email'] as String?;
    userMobile = user['mobile'] as String?;

    // Dynamic role ID and permissions from database
    userRoleId = (user['roleId'] as String?)?.toLowerCase() ??
        (user['role'] as String?)?.toLowerCase() ??
        'pending';
    userRoleName = (user['roleName'] as String?) ??
        (user['role'] as String?) ??
        userRoleId;
    userRole = user['role'] as String?;

    if (user['permissions'] is List) {
      userPermissions = (user['permissions'] as List).map((p) => p.toString()).toList();
    } else {
      userPermissions = [];
    }

    userDepartmentId = user['departmentId'] as String?;
    userDepartment = user['department'] as String?;
    userYear = user['year'] as int?;
    userDivision = user['division'] as String?;
    userPhotoUrl = user['photoUrl'] as String? ??
        (user['student'] is Map ? (user['student'] as Map)['photoUrl'] as String? : null);
    userTutorId = (user['tutorId'] as String?) ??
        (user['student'] is Map ? (user['student'] as Map)['tutorId'] as String? : null) ??
        (user['student'] is Map && (user['student'] as Map)['tutor'] is Map
            ? ((user['student'] as Map)['tutor'] as Map)['id'] as String?
            : null);

    debugPrint(
      '[AppState] _populateUserData: user=$userName ($userId), roleId=$userRoleId, '
      'permissions=$userPermissions, dept=$userDepartment, photo=$userPhotoUrl, tutorId=$userTutorId',
    );
  }

  /// Update the current authenticated user's profile photo.
  Future<String> updateProfilePhoto(String photoDataUri) async {
    final res = await api.updateProfilePhoto(photoDataUri);
    final newUrl = res['photoUrl'] as String?;
    userPhotoUrl = newUrl;
    notifyListeners();
    return newUrl ?? '';
  }

  /// Remove/reset the current authenticated user's profile photo.
  Future<void> removeProfilePhoto() async {
    await api.deleteProfilePhoto();
    userPhotoUrl = null;
    notifyListeners();
  }

  void logout() {
    userId = null;
    userName = null;
    userEmail = null;
    userRole = null;
    userRoleId = null;
    userRoleName = null;
    userPermissions = [];
    userMobile = null;
    userDepartmentId = null;
    userDepartment = null;
    userYear = null;
    userDivision = null;
    userTutorId = null;
    userPhotoUrl = null;
    refreshToken = null;
    deviceKeys = null;
    api.accessToken = null;
    isConfigLoaded = false;

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

  static AppState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStateScope>()?.notifier;

  static AppState of(BuildContext context) {
    final state = maybeOf(context);
    if (state == null) {
      throw StateError('AppStateScope not found in widget hierarchy. Make sure AppStateScope wraps MaterialApp.');
    }
    return state;
  }
}
