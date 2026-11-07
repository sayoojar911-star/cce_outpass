import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Random UUID v4 for scan idempotency keys (PRD §8 gate_events.client_scan_id).
String uuidV4() {
  final rnd = Random.secure();
  final b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Normalizes an input mobile number: strips spaces, dashes, +91, 91 prefixes,
/// and returns the clean digit string.
String normalizeMobilePhone(String? value) {
  if (value == null) return '';
  var cleaned = value.trim().replaceAll(RegExp(r'[\s\-\(\)]+'), '');
  if (cleaned.startsWith('+91')) {
    cleaned = cleaned.substring(3);
  } else if (cleaned.startsWith('91') && cleaned.length == 12) {
    cleaned = cleaned.substring(2);
  } else if (cleaned.startsWith('+')) {
    cleaned = cleaned.substring(1);
  }
  return cleaned.replaceAll(RegExp(r'\D'), '');
}

/// Thin typed client for the /v1 API. Single source of truth is the server
/// (PRD §4 principles) — the app only displays and requests.
class ApiClient {
  ApiClient({
    String? baseUrl,
  }) : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://localhost:3000/v1',
            );

  String baseUrl;
  String? accessToken;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  dynamic _decode(http.Response r) {
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 400) {
      final msg = body is Map && body['message'] != null
          ? body['message'].toString()
          : 'Request failed (${r.statusCode})';
      throw ApiException(msg, r.statusCode);
    }
    return body;
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final r = await http
        .post(Uri.parse('$baseUrl$path'),
            headers: _headers, body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 15));
    return _decode(r);
  }

  Future<dynamic> get(String path) async {
    final r = await http
        .get(Uri.parse('$baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    return _decode(r);
  }

  Future<dynamic> delete(String path) async {
    final r = await http
        .delete(Uri.parse('$baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    return _decode(r);
  }

  // ---- Auth ----

  /// Send OTP to the given mobile number via the backend.
  Future<Map<String, dynamic>> sendOtp(String mobile) async {
    return (await post('/auth/otp/send', body: {'mobile': mobile}))
        .cast<String, dynamic>();
  }

  /// Send OTP for new student registration.
  Future<Map<String, dynamic>> sendSignupOtp(String mobile) async {
    return (await post('/auth/signup/otp/send', body: {'mobile': mobile}))
        .cast<String, dynamic>();
  }

  /// Verify OTP and get access + refresh tokens.
  Future<Map<String, dynamic>> verifyOtp(String mobile, String code) async {
    final res =
        await post('/auth/otp/verify', body: {'mobile': mobile, 'code': code});
    accessToken = res['accessToken'] as String?;
    return (res['user'] as Map).cast<String, dynamic>();
  }

  /// Verify OTP for new student registration, returning verified token.
  Future<Map<String, dynamic>> verifySignupOtp(String mobile, String code) async {
    final res = await post('/auth/signup/otp/verify',
        body: {'mobile': mobile, 'code': code});
    return (res as Map).cast<String, dynamic>();
  }

  /// Complete student registration and receive session tokens.
  Future<Map<String, dynamic>> registerStudent({
    required String idToken,
    required String name,
    required String rollNo,
    required int year,
    required String department,
    required String photo,
  }) async {
    final res = await post('/auth/register', body: {
      'idToken': idToken,
      'name': name,
      'rollNo': rollNo,
      'year': year,
      'department': department,
      'photo': photo,
    });
    accessToken = res['accessToken'] as String?;
    return (res as Map).cast<String, dynamic>();
  }

  /// Resolves relative image/media paths (e.g. /uploads/students/...) against server base URL.
  String resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('data:')) {
      return url;
    }
    final serverOrigin = baseUrl.replaceAll(RegExp(r'/v1/?$'), '');
    return '$serverOrigin${url.startsWith('/') ? '' : '/'}$url';
  }

  /// Update authenticated user's profile photo.
  Future<Map<String, dynamic>> updateProfilePhoto(String photoDataUri) async {
    final res = await post('/auth/profile/photo', body: {'photo': photoDataUri});
    return (res as Map).cast<String, dynamic>();
  }

  /// Remove authenticated user's profile photo.
  Future<Map<String, dynamic>> deleteProfilePhoto() async {
    final res = await delete('/auth/profile/photo');
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final res = await post('/auth/refresh', body: {'refreshToken': refreshToken});
    accessToken = res['accessToken'] as String?;
    return res as Map<String, dynamic>;
  }

  Future<dynamic> registerDevice(String publicKeyPem, String platform) async {
    return post('/auth/device/register',
        body: {'publicKeyPem': publicKeyPem, 'platform': platform});
  }

  Future<Map<String, dynamic>> me() async {
    return (await get('/auth/me') as Map).cast<String, dynamic>();
  }

  // ---- Outpasses (FR-STU) ----

  Future<List<dynamic>> myOutpasses() async {
    return await get('/outpasses') as List<dynamic>;
  }

  Future<Map<String, dynamic>> createOutpass({
    required String requestedExitAt,
    required String expectedReturnAt,
    required String destination,
    required String purposeCategory,
    String? purposeText,
    String type = 'NORMAL',
  }) async {
    final body = <String, dynamic>{
      'requestedExitAt': requestedExitAt,
      'expectedReturnAt': expectedReturnAt,
      'destination': destination,
      'purposeCategory': purposeCategory,
      'type': type,
    };
    if (purposeText != null && purposeText.trim().isNotEmpty) {
      body['purposeText'] = purposeText.trim();
    }
    final res = await post('/outpasses', body: body);
    if (res is Map) {
      return res.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  Future<void> cancelOutpass(String id, {String? reason}) async {
    await post(
      '/outpasses/$id/cancel',
      body: reason != null && reason.isNotEmpty ? {'reason': reason} : null,
    );
  }

  // ---- Approvals (FR-TUT / FR-HOD) ----

  Future<List<dynamic>> pending() async {
    return await get('/approvals/pending') as List<dynamic>;
  }

  Future<Map<String, dynamic>> decide(String outpassId, String decision,
      {String? comment, String? path}) async {
    final body = <String, dynamic>{'decision': decision};
    if (comment != null) body['comment'] = comment;
    if (path != null) body['path'] = path;
    return (await post('/approvals/$outpassId/decision', body: body))
        .cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> approveDirect(String outpassId,
      {String? comment}) async {
    final body = <String, dynamic>{};
    if (comment != null) body['comment'] = comment;
    return (await post('/approvals/$outpassId/approve-direct', body: body))
        .cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> forwardToHod(String outpassId,
      {String? comment}) async {
    final body = <String, dynamic>{};
    if (comment != null) body['comment'] = comment;
    return (await post('/approvals/$outpassId/forward-hod', body: body))
        .cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> rejectOutpass(String outpassId, String reason) async {
    return (await post('/approvals/$outpassId/reject', body: {
      'reason': reason,
      'comment': reason,
    }))
        .cast<String, dynamic>();
  }

  // ---- Gate (FR-SEC) ----

  Future<void> startShift(String gateId) async {
    await post('/gate/session/start', body: {'gateId': gateId});
  }

  Future<Map<String, dynamic>> scan({
    required String token,
    required String direction,
    required String gateId,
    required String clientScanId,
  }) async {
    return (await post('/gate/scans', body: {
      'token': token,
      'direction': direction,
      'gateId': gateId,
      'clientScanId': clientScanId,
    }))
        .cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> manualEntry({
    required String code,
    required String direction,
    required String gateId,
    required String clientScanId,
  }) async {
    return (await post('/gate/manual-entry', body: {
      'code': code,
      'direction': direction,
      'gateId': gateId,
      'clientScanId': clientScanId,
    }))
        .cast<String, dynamic>();
  }

  Future<List<dynamic>> guardScans() async {
    return await get('/gate/scans/mine') as List<dynamic>;
  }

  // ---- Admin APIs ----

  Future<List<dynamic>> adminGetUsers() async {
    return (await get('/admin/users') as List).cast<dynamic>();
  }

  Future<Map<String, dynamic>> adminAddUser(Map<String, dynamic> data) async {
    return (await post('/admin/users', body: data) as Map)
        .cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> adminUpdateUser(
      String id, Map<String, dynamic> data) async {
    return (await post('/admin/users/$id', body: data) as Map)
        .cast<String, dynamic>();
  }

  Future<void> adminDeleteUser(String id) async {
    await post('/admin/users/$id/delete');
  }

  Future<int> adminBulkAddUsers(List<Map<String, String>> rows) async {
    final res = await post('/admin/users/bulk', body: {'rows': rows});
    return res['count'] as int;
  }

  Future<List<dynamic>> adminGetDepartments() async {
    return (await get('/admin/departments') as List).cast<dynamic>();
  }

  Future<Map<String, dynamic>> adminAddOrUpdateDepartment(
      String code, String name, String? hodId) async {
    return (await post('/admin/departments',
            body: {'code': code, 'name': name, 'hodId': hodId}) as Map)
        .cast<String, dynamic>();
  }

  Future<void> adminDeleteDepartment(String id) async {
    await delete('/admin/departments/$id');
  }

  Future<Map<String, dynamic>> adminAddDivision(
      String deptId, String name) async {
    return (await post('/admin/departments/$deptId/divisions',
            body: {'name': name}) as Map)
        .cast<String, dynamic>();
  }

  Future<void> adminDeleteDivision(String deptId, String divisionId) async {
    await delete('/admin/departments/$deptId/divisions/$divisionId');
  }

  Future<int> adminAssignTutors(List<String> studentIds, String? tutorId) async {
    final res = await post('/admin/tutors/assign',
        body: {'studentIds': studentIds, 'tutorId': tutorId});
    return (res['count'] as num).toInt();
  }

  Future<List<dynamic>> adminGetOutpasses() async {
    return (await get('/admin/outpasses') as List).cast<dynamic>();
  }

  Future<void> adminCancelOutpass(String id, {String? reason}) async {
    await post('/admin/outpasses/$id/cancel', body: reason != null ? {'reason': reason} : null);
  }

  Future<Map<String, dynamic>> adminGetSettings() async {
    return (await get('/admin/settings') as Map).cast<String, dynamic>();
  }

  Future<void> adminUpdateSettings(Map<String, dynamic> settings) async {
    await post('/admin/settings', body: settings);
  }

  Future<List<dynamic>> adminGetAuditLog({int limit = 50, int offset = 0}) async {
    return (await get('/admin/audit?limit=$limit&offset=$offset') as List)
        .cast<dynamic>();
  }

  Future<Map<String, dynamic>> adminGetDashboard() async {
    return (await get('/admin/dashboard') as Map).cast<String, dynamic>();
  }

  // ---- Dynamic Configuration Endpoints ----

  Future<Map<String, dynamic>> getAllConfig() async {
    try {
      final res = await get('/config/all');
      if (res is Map) return res.cast<String, dynamic>();
    } catch (_) {}
    return {
      'roles': await getRoles(),
      'departments': [],
      'purposeCategories': await getPurposeCategories(),
      'outpassTypes': await getOutpassTypes(),
      'settings': {},
    };
  }

  Future<List<dynamic>> getRoles() async {
    try {
      final res = await get('/config/roles');
      if (res is List) return res.cast<dynamic>();
    } catch (_) {}
    return [
      {'id': 'student', 'name': 'Student', 'permissions': ['createOutpass']},
      {'id': 'tutor', 'name': 'Tutor', 'permissions': ['approveOutpass']},
      {'id': 'hod', 'name': 'HOD', 'permissions': ['approveOutpass']},
      {'id': 'guard', 'name': 'Security Guard', 'permissions': ['scanGate']},
      {'id': 'admin', 'name': 'Administrator', 'permissions': ['manageUsers', 'manageRoles', 'viewAll']},
      {'id': 'pending', 'name': 'Pending Approval', 'permissions': []},
    ];
  }

  Future<List<dynamic>> getPurposeCategories() async {
    try {
      final res = await get('/config/purpose-categories');
      if (res is List) return res.cast<dynamic>();
    } catch (_) {}
    return [
      {'id': 'cat-medical', 'label': 'Medical', 'active': true},
      {'id': 'cat-personal', 'label': 'Personal', 'active': true},
      {'id': 'cat-official', 'label': 'Official', 'active': true},
      {'id': 'cat-academic', 'label': 'Academic', 'active': true},
      {'id': 'cat-emergency', 'label': 'Emergency', 'active': true},
    ];
  }

  Future<List<dynamic>> getOutpassTypes() async {
    try {
      final res = await get('/config/outpass-types');
      if (res is List) return res.cast<dynamic>();
    } catch (_) {}
    return [
      {'id': 'normal', 'label': 'Normal (Tutor -> HOD)', 'approvalChain': ['tutor', 'hod'], 'active': true},
      {'id': 'emergency', 'label': 'Emergency', 'approvalChain': ['hod'], 'active': true},
    ];
  }

  Future<Map<String, dynamic>> getSettings() async {
    try {
      final res = await get('/config/settings');
      if (res is Map) return res.cast<String, dynamic>();
    } catch (_) {}
    return {};
  }

  // ---- Admin Role & Workflow Management ----

  Future<Map<String, dynamic>> adminSaveRole(Map<String, dynamic> data) async {
    return (await post('/admin/roles', body: data) as Map).cast<String, dynamic>();
  }

  Future<void> adminDeleteRole(String id) async {
    await post('/admin/roles/$id/delete');
  }

  Future<Map<String, dynamic>> adminSavePurposeCategory(Map<String, dynamic> data) async {
    return (await post('/admin/purpose-categories', body: data) as Map).cast<String, dynamic>();
  }

  Future<void> adminDeletePurposeCategory(String id) async {
    await post('/admin/purpose-categories/$id/delete');
  }

  Future<Map<String, dynamic>> adminSaveOutpassType(Map<String, dynamic> data) async {
    return (await post('/admin/outpass-types', body: data) as Map).cast<String, dynamic>();
  }

  Future<void> adminDeleteOutpassType(String id) async {
    await post('/admin/outpass-types/$id/delete');
  }
}

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}
