import 'dart:convert';
import 'dart:io';

import 'package:cce_outpass/api_client.dart' show uuidV4;
import 'package:cce_outpass/qr_token.dart';

/// Debug: print one generated public key (run with --print-key).

/// E2E cross-implementation check: drives the live API through the full
/// lifecycle using the SAME crypto module the Flutter app ships
/// (lib/qr_token.dart). Proves the client's ECDSA P-256 signing is
/// server-compatible, plus single-use, replay and dwell rules.
const student = '8921578831';
const tutor = '8921578833'; // Dr. Anand Kumar (TUTOR)
const hod = '8921578832'; // Dr. Priya Menon (HOD)
const guard = '8921578834';
const admin = '8921578838';

late String apiBase;

Future<dynamic> call(String method, String path, String? token, [Map<String, dynamic>? body]) async {
  final req = await HttpClient().openUrl(method, Uri.parse('$apiBase$path'));
  req.headers.set('content-type', 'application/json');
  if (token != null) req.headers.set('Authorization', 'Bearer $token');
  if (body != null) req.write(jsonEncode(body));
  final res = await req.close();
  final text = await res.transform(utf8.decoder).join();
  if (res.statusCode >= 400) throw Exception('$method $path -> ${res.statusCode}: $text');
  return text.isEmpty ? null : jsonDecode(text);
}

Future<String> login(String mobile) async {
  final idToken = Platform.environment['FIREBASE_ID_TOKEN_$mobile'];
  if (idToken != null) {
    final verify = await call(
        'POST', '/auth/firebase/verify', null, {'idToken': idToken});
    return (verify as Map)['accessToken'] as String;
  }
  await call('POST', '/auth/otp/send', null, {'mobile': mobile});
  final verify = await call(
      'POST', '/auth/otp/verify', null, {'mobile': mobile, 'code': '123456'});
  return (verify as Map)['accessToken'] as String;
}

void check(String name, bool ok) {
  stdout.writeln('${ok ? "✅" : "❌"} $name');
  if (!ok) exitCode = 1;
}

Future<void> main(List<String> args) async {
  if (args.contains('--print-key')) {
    stdout.writeln(DeviceKeys.generate().publicKeyPem());
    return;
  }
  apiBase = args.isNotEmpty ? args[0] : 'http://localhost:3000/v1';

  final adminTok = await login(admin);
  for (final o in (await call('GET', '/admin/outpasses', adminTok) as List)) {
    final m = o as Map;
    try {
      await call('POST', '/admin/outpasses/${m['id']}/cancel', adminTok, {'reason': 'E2E Reset'});
    } catch (_) {}
  }

  // -- Student: login, device binding, request --
  final studentTok = await login(student);
  final keys = DeviceKeys.generate();
  await call('POST', '/auth/device/register', studentTok,
      {'publicKeyPem': keys.publicKeyPem(), 'platform': 'dart-e2e'});
  final created = await call('POST', '/outpasses', studentTok, {
    'requestedExitAt': DateTime.now().toIso8601String(),
    'expectedReturnAt': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
    'destination': 'Govt Hospital',
    'purposeCategory': 'Medical',
    'type': 'EMERGENCY',
  }) as Map;
  final id = created['id'] as String;
  check('1. Student login + device bind + request (${created['displayId']})',
      created['status'] == 'PENDING_TUTOR');

  // -- Tutor approval --
  final tutorTok = await login(tutor);
  final t1 = await call('POST', '/approvals/$id/decision', tutorTok, {'decision': 'APPROVED'});
  check('2. Tutor approval → PENDING_HOD', (t1 as Map)['status'] == 'PENDING_HOD');

  // -- HOD approval --
  final hodTok = await login(hod);
  final t2 = await call('POST', '/approvals/$id/decision', hodTok, {'decision': 'APPROVED'});
  check('3. HOD approval → APPROVED (QR active)', (t2 as Map)['status'] == 'APPROVED');

  // -- Guard: exit with a token signed by the APP's own crypto module --
  final guardTok = await login(guard);
  await call('POST', '/gate/session/start', guardTok, {'gateId': 'main-gate'});
  Future<dynamic> scan(String token, String dir) => call('POST', '/gate/scans', guardTok, {
        'token': token,
        'direction': dir,
        'gateId': 'main-gate',
        'clientScanId': uuidV4(),
      });

  final step = DeviceKeys.currentStep();
  final exitRes = await scan(keys.buildToken(id, step), 'EXIT') as Map;
  check('4. Guard exit scan (app-signed token) → OK_EXIT', exitRes['result'] == 'OK_EXIT');

  // Single-use (SEC-06): fresh token, same pass, exit mode again.
  final step2 = step + 30;
  final reuse = await scan(keys.buildToken(id, step2), 'EXIT') as Map;
  check('5. Rescan in exit mode → ALREADY_USED', reuse['result'] == 'ALREADY_USED');

  // Replay protection (SEC-QR-05): stale ts is rejected outright.
  final stale = await scan(keys.buildToken(id, step - 60), 'EXIT') as Map;
  check('6. Stale token rejection → QR_STALE', stale['result'] == 'QR_STALE');

  // Return flow: dwell rule blocks an immediate re-entry (10 min, PRD §6.9).
  final tooSoon = await scan(keys.buildToken(id, step2 + 30), 'ENTRY') as Map;
  check('7. Guard immediate re-entry blocked → MIN_DWELL', tooSoon['result'] == 'MIN_DWELL');

  // Cancel first active pass via admin so student can create subsequent passes for testing
  await call('POST', '/admin/outpasses/$id/cancel', adminTok, {'reason': 'Test Lifecycle Reset'});

  // 8. Test Cancellation Flow: Student creates request and immediately cancels
  final reqToCancel = await call('POST', '/outpasses', studentTok, {
    'requestedExitAt': DateTime.now().toIso8601String(),
    'expectedReturnAt': DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
    'destination': 'Library',
    'purposeCategory': 'Academic',
    'type': 'NORMAL',
  }) as Map;
  final cancelId = reqToCancel['id'] as String;
  final cancelRes = await call('POST', '/outpasses/$cancelId/cancel', studentTok) as Map;
  check('8. Student cancellation flow → CANCELLED', cancelRes['status'] == 'CANCELLED');

  // 9. Test Rejection Flow: Student creates request, Tutor rejects with reason
  final reqToReject = await call('POST', '/outpasses', studentTok, {
    'requestedExitAt': DateTime.now().toIso8601String(),
    'expectedReturnAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    'destination': 'Market',
    'purposeCategory': 'Personal',
    'type': 'NORMAL',
  }) as Map;
  final rejectId = reqToReject['id'] as String;
  final rejectRes = await call('POST', '/approvals/$rejectId/decision', tutorTok, {
    'decision': 'REJECTED',
    'remarks': 'Class test scheduled at this hour',
  }) as Map;
  check('9. Tutor rejection flow with reason → REJECTED', rejectRes['status'] == 'REJECTED');

  // 10. Audit Log Verification via Admin API
  final auditLogs = await call('GET', '/admin/audit', adminTok) as List;
  check('10. Admin Audit Log populated and verifiable', auditLogs.isNotEmpty);
}
