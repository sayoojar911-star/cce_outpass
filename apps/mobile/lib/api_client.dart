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
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3000/v1',
    ),
  });

  final String baseUrl;
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

  /// Verify OTP and get access + refresh tokens.
  Future<Map<String, dynamic>> verifyOtp(String mobile, String code) async {
    final res =
        await post('/auth/otp/verify', body: {'mobile': mobile, 'code': code});
    accessToken = res['accessToken'] as String?;
    return (res['user'] as Map).cast<String, dynamic>();
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
    return (await post('/outpasses', body: {
      'requestedExitAt': requestedExitAt,
      'expectedReturnAt': expectedReturnAt,
      'destination': destination,
      'purposeCategory': purposeCategory,
      'purposeText': ?purposeText,
      'type': type,
    }))
        .cast<String, dynamic>();
  }

  Future<void> cancelOutpass(String id) async {
    await post('/outpasses/$id/cancel');
  }

  // ---- Approvals (FR-TUT / FR-HOD) ----

  Future<List<dynamic>> pending() async {
    return await get('/approvals/pending') as List<dynamic>;
  }

  Future<Map<String, dynamic>> decide(String outpassId, String decision,
      {String? comment}) async {
    return (await post('/approvals/$outpassId/decision', body: {
      'decision': decision,
      'comment': ?comment,
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

  Future<void> adminCancelOutpass(String id) async {
    await post('/admin/outpasses/$id/cancel');
  }

  Future<Map<String, dynamic>> adminGetSettings() async {
    return (await get('/admin/settings') as Map).cast<String, dynamic>();
  }

  Future<void> adminUpdateSettings(
      {String? collegeName,
      int? minDwellMinutes,
      List<String>? categories}) async {
    await post('/admin/settings', body: {
      'collegeName': ?collegeName,
      'minDwellMinutes': ?minDwellMinutes,
      'categories': ?categories,
    });
  }

  Future<List<dynamic>> adminGetAuditLog({int limit = 50, int offset = 0}) async {
    return (await get('/admin/audit?limit=$limit&offset=$offset') as List)
        .cast<dynamic>();
  }

  Future<Map<String, dynamic>> adminGetDashboard() async {
    return (await get('/admin/dashboard') as Map).cast<String, dynamic>();
  }
}

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}
