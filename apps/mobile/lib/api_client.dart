import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'mock_backend.dart';

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

/// Thin typed client for the /v1 API. Single source of truth is the server
/// (PRD §4 principles) — the app only displays and requests.
class ApiClient {
  ApiClient({
    this.baseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000/v1'),
    bool? isDemoMode,
  }) : isDemoMode = isDemoMode ??
            (const bool.fromEnvironment('IS_DEMO_MODE', defaultValue: false) ||
                !kReleaseMode);

  final String baseUrl;
  bool isDemoMode;
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
    final r = await http.post(Uri.parse('$baseUrl$path'),
        headers: _headers, body: jsonEncode(body ?? {}));
    return _decode(r);
  }

  Future<dynamic> get(String path) async {
    if (isDemoMode && path == '/gate/scans/mine') {
      return MockBackend.instance.guardScans();
    }
    final r = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    return _decode(r);
  }

  // ---- Auth (Firebase Phone Auth) ----

  Future<Map<String, dynamic>> verifyFirebasePhone(String idToken) async {
    if (isDemoMode) {
      final res = MockBackend.instance.loginUser(idToken);
      accessToken = res['accessToken'] as String?;
      return (res['user'] as Map).cast<String, dynamic>();
    }
    final res = await post('/auth/firebase/verify', body: {'idToken': idToken});
    accessToken = res['accessToken'] as String?;
    return (res['user'] as Map).cast<String, dynamic>();
  }

  Future<dynamic> registerDevice(String publicKeyPem, String platform) async {
    if (isDemoMode) {
      MockBackend.instance.registerDevice(publicKeyPem);
      return {'ok': true};
    }
    return post('/auth/device/register',
        body: {'publicKeyPem': publicKeyPem, 'platform': platform});
  }

  // ---- Outpasses (FR-STU) ----

  Future<List<dynamic>> myOutpasses() async {
    if (isDemoMode) {
      return MockBackend.instance.myOutpasses();
    }
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
    if (isDemoMode) {
      return MockBackend.instance.createOutpass(
        requestedExitAt: requestedExitAt,
        expectedReturnAt: expectedReturnAt,
        destination: destination,
        purposeCategory: purposeCategory,
        purposeText: purposeText,
        type: type,
      );
    }
    return (await post('/outpasses', body: {
      'requestedExitAt': requestedExitAt,
      'expectedReturnAt': expectedReturnAt,
      'destination': destination,
      'purposeCategory': purposeCategory,
      if (purposeText != null) 'purposeText': purposeText,
      'type': type,
    }))
        .cast<String, dynamic>();
  }

  Future<void> cancelOutpass(String id) async {
    if (isDemoMode) {
      MockBackend.instance.cancelOutpass(id);
      return;
    }
    await post('/outpasses/$id/cancel');
  }

  // ---- Approvals (FR-TUT / FR-HOD) ----

  Future<List<dynamic>> pending() async {
    if (isDemoMode) {
      return MockBackend.instance.pendingApprovals();
    }
    return await get('/approvals/pending') as List<dynamic>;
  }

  Future<Map<String, dynamic>> decide(String outpassId, String decision,
      {String? comment}) async {
    if (isDemoMode) {
      return MockBackend.instance
          .decide(outpassId, decision, comment: comment);
    }
    return (await post('/approvals/$outpassId/decision',
            body: {'decision': decision, if (comment != null) 'comment': comment}))
        .cast<String, dynamic>();
  }

  // ---- Gate (FR-SEC) ----

  Future<void> startShift(String gateId) async {
    if (isDemoMode) {
      MockBackend.instance.startShift(gateId);
      return;
    }
    await post('/gate/session/start', body: {'gateId': gateId});
  }

  Future<Map<String, dynamic>> scan({
    required String token,
    required String direction,
    required String gateId,
    required String clientScanId,
  }) async {
    if (isDemoMode) {
      return MockBackend.instance.scan(
        token: token,
        direction: direction,
        gateId: gateId,
        clientScanId: clientScanId,
      );
    }
    return (await post('/gate/scans', body: {
      'token': token,
      'direction': direction,
      'gateId': gateId,
      'clientScanId': clientScanId,
    }))
        .cast<String, dynamic>();
  }

  // ---- Admin APIs ----

  Future<List<dynamic>> adminGetUsers() async {
    if (isDemoMode) return MockBackend.instance.getAllUsers();
    return (await get('/admin/users') as List).cast<dynamic>();
  }

  Future<Map<String, dynamic>> adminAddUser(Map<String, dynamic> data) async {
    if (isDemoMode) return MockBackend.instance.addUser(data);
    return (await post('/admin/users', body: data) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> adminUpdateUser(String id, Map<String, dynamic> data) async {
    if (isDemoMode) return MockBackend.instance.updateUser(id, data);
    return (await post('/admin/users/$id', body: data) as Map).cast<String, dynamic>();
  }

  Future<void> adminDeleteUser(String id) async {
    if (isDemoMode) {
      MockBackend.instance.deleteUser(id);
      return;
    }
    await post('/admin/users/$id/delete');
  }

  Future<int> adminBulkAddUsers(List<Map<String, String>> rows) async {
    if (isDemoMode) return MockBackend.instance.bulkAddUsers(rows);
    final res = await post('/admin/users/bulk', body: {'rows': rows});
    return res['count'] as int;
  }

  Future<List<dynamic>> adminGetDepartments() async {
    if (isDemoMode) return MockBackend.instance.getDepartments();
    return (await get('/admin/departments') as List).cast<dynamic>();
  }

  Future<Map<String, dynamic>> adminAddOrUpdateDepartment(String code, String name, String? hodId) async {
    if (isDemoMode) return MockBackend.instance.addOrUpdateDepartment(code, name, hodId);
    return (await post('/admin/departments', body: {'code': code, 'name': name, 'hodId': hodId}) as Map).cast<String, dynamic>();
  }

  Future<List<dynamic>> adminGetOutpasses() async {
    if (isDemoMode) return MockBackend.instance.getAllOutpasses();
    return (await get('/admin/outpasses') as List).cast<dynamic>();
  }

  Future<Map<String, dynamic>> adminGetSettings() async {
    if (isDemoMode) return MockBackend.instance.getSettings();
    return (await get('/admin/settings') as Map).cast<String, dynamic>();
  }

  Future<void> adminUpdateSettings({String? collegeName, int? minDwellMinutes, List<String>? categories}) async {
    if (isDemoMode) {
      MockBackend.instance.updateSettings(
        collegeName: collegeName,
        minDwellMinutes: minDwellMinutes,
        categories: categories,
      );
      return;
    }
    await post('/admin/settings', body: {
      if (collegeName != null) 'collegeName': collegeName,
      if (minDwellMinutes != null) 'minDwellMinutes': minDwellMinutes,
      if (categories != null) 'categories': categories,
    });
  }
}

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}
