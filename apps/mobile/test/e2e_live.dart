import 'dart:convert';
import 'dart:io';

import 'package:cce_outpass/api_client.dart' show uuidV4;
import 'package:cce_outpass/qr_token.dart';

/// Debug: print one generated public key (run with --print-key).

/// E2E cross-implementation check: drives the live API through the full
/// lifecycle using the SAME crypto module the Flutter app ships
/// (lib/qr_token.dart). Proves the client's ECDSA P-256 signing is
/// server-compatible, plus single-use, replay and dwell rules.
const student = '9000000010';
const tutor = '9000000001'; // Dr. Anand Kumar (TUTOR)
const hod = '9000000002'; // Dr. Priya Menon (HOD)
const guard = '9000000090';

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
  if (idToken == null) {
    throw StateError('Set FIREBASE_ID_TOKEN_$mobile to a current Firebase phone-auth ID token');
  }
  final verify = await call(
      'POST', '/auth/firebase/verify', null, {'idToken': idToken});
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

  // -- Student: login, device binding, request --
  final studentTok = await login(student);
  // Self-cleanup so the script is repeatable: cancel leftover active passes.
  for (final o in (await call('GET', '/outpasses', studentTok) as List)) {
    final m = o as Map;
    if (['PENDING_TUTOR', 'PENDING_HOD', 'APPROVED'].contains(m['status'])) {
      await call('POST', '/outpasses/${m['id']}/cancel', studentTok);
    }
  }
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
  check('student login + device bind + request (${created['displayId']})',
      created['status'] == 'PENDING_TUTOR');

  // -- Tutor approval --
  final tutorTok = await login(tutor);
  final t1 = await call('POST', '/approvals/$id/decision', tutorTok, {'decision': 'APPROVED'});
  check('tutor approval → PENDING_HOD', (t1 as Map)['status'] == 'PENDING_HOD');

  // -- HOD approval --
  final hodTok = await login(hod);
  final t2 = await call('POST', '/approvals/$id/decision', hodTok, {'decision': 'APPROVED'});
  check('HOD approval → APPROVED (QR active)', (t2 as Map)['status'] == 'APPROVED');

  // -- Guard: exit with a token signed by the APP's own crypto module --
  final guardTok = await login(guard);
  await call('POST', '/gate/session/start', guardTok, {'gateId': 'main-gate'});
  final scan = (String token, String dir) => call('POST', '/gate/scans', guardTok, {
        'token': token,
        'direction': dir,
        'gateId': 'main-gate',
        'clientScanId': uuidV4(),
      });

  final step = DeviceKeys.currentStep();
  final exitRes = await scan(keys.buildToken(id, step), 'EXIT') as Map;
  check('exit scan (app-signed token) → OK_EXIT', exitRes['result'] == 'OK_EXIT');

  // Single-use (SEC-06): fresh token, same pass, exit mode again.
  final step2 = step + 30;
  final reuse = await scan(keys.buildToken(id, step2), 'EXIT') as Map;
  check('rescan in exit mode → ALREADY_USED', reuse['result'] == 'ALREADY_USED');

  // Replay protection (SEC-QR-05): stale ts is rejected outright.
  final stale = await scan(keys.buildToken(id, step - 60), 'EXIT') as Map;
  check('stale token → QR_STALE', stale['result'] == 'QR_STALE');

  // Return flow: dwell rule blocks an immediate re-entry (10 min, PRD §6.9).
  // The full OK_ENTRY → RETURNED transition is covered by the jest e2e suite,
  // which can backdate exitAt directly in the test database.
  final tooSoon = await scan(keys.buildToken(id, step2 + 30), 'ENTRY') as Map;
  check('immediate entry → MIN_DWELL', tooSoon['result'] == 'MIN_DWELL');
}
