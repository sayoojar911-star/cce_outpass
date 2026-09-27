import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'api_client.dart';
import 'qr_token.dart';

/// Session state: one user, one role per login (PRD §2.1 role switcher is a
/// later phase — the MVP seeds separate staff accounts).
class AppState extends ChangeNotifier {
  final ApiClient api = ApiClient();

  String? userName;
  String? userRole;
  DeviceKeys? deviceKeys;

  bool get loggedIn => userRole != null;
  bool get isStudent => userRole == 'STUDENT';
  bool get isTutor => userRole == 'TUTOR';
  bool get isHod => userRole == 'HOD';
  bool get isGuard => userRole == 'GUARD';

  Future<void> loginWithFirebaseToken(String idToken) async {
    final user = await api.verifyFirebasePhone(idToken);
    userName = user['name'] as String?;
    userRole = user['role'] as String?;
    deviceKeys = DeviceKeys.generate();
    try {
      // Device binding (PRD §10.3): key is registered server-side; scans are
      // verified against this key and DEVICE_REVOKED after revocation.
      await api.registerDevice(deviceKeys!.publicKeyPem(), 'web');
    } on ApiException {
      rethrow;
    }
    notifyListeners();
  }

  void logout() {
    userName = null;
    userRole = null;
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
