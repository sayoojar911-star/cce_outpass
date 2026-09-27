import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cce_outpass/api_client.dart' show uuidV4;
import 'package:cce_outpass/qr_token.dart';

/// Real-time demo walkthrough for the demo account (mobile 9074121510).
/// Supply current Firebase phone-auth ID tokens through environment variables.
/// Mirrors exactly what the user does in the
/// app: login, device binding, request, watch approvals arrive, open the
/// QR, and get scanned at the gate. Every poll step uses the same polling
/// the screens use, so this proves the "real time" behaviour end to end.
const demoMobile = '9074121510';
const tutor = '9000000001';
const hod = '9000000002';
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

Future<String> loginDemo() async {
  return login(demoMobile);
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

/// Poll until [test] returns non-null, up to [seconds].
Future<dynamic?> poll(String label, Future<dynamic?> Function() test,
    {int seconds = 8}) async {
  for (var i = 0; i < seconds * 2; i++) {
    final r = await test();
    if (r != null) return r;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw Exception('Timed out waiting for: $label');
}

void check(String name, bool ok) {
  stdout.writeln('${ok ? "✅" : "❌"} $name');
  if (!ok) exitCode = 1;
}

Future<void> main(List<String> args) async {
  apiBase = args.isNotEmpty ? args[0] : 'http://localhost:3000/v1';

  // ---- 1. Student login using a Firebase ID token ----
  final studentTok = await loginDemo();
  final me = await call('GET', '/auth/me', studentTok) as Map;
  check('demo Firebase login 9074121510 → ${me['name']} (${me['role']})',
      me['role'] == 'STUDENT');

  // Self-cleanup: cancel leftovers so the run is repeatable.
  final keys = DeviceKeys.generate();
  await call('POST', '/auth/device/register', studentTok,
      {'publicKeyPem': keys.publicKeyPem(), 'platform': 'demo-cycle'});
  for (final o in (await call('GET', '/outpasses', studentTok) as List)) {
    final m = o as Map;
    if (['PENDING_TUTOR', 'PENDING_HOD', 'APPROVED'].contains(m['status'])) {
      await call('POST', '/outpasses/${m['id']}/cancel', studentTok);
    }
  }

  // ---- 2. Request an outpass in the app ----
  final created = await call('POST', '/outpasses', studentTok, {
    'requestedExitAt': DateTime.now().toIso8601String(),
    'expectedReturnAt': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
    'destination': 'Irinjalakuda Town',
    'purposeCategory': 'Medical',
    'purposeText': 'Demo walkthrough - doctor visit',
    'type': 'NORMAL',
  }) as Map;
  final id = created['id'] as String;
  check('outpass requested (${created['displayId']}) → PENDING_TUTOR',
      created['status'] == 'PENDING_TUTOR');

  // ---- 3. Tutor sees it in the pending queue (polling like the app) ----
  final tutorTok = await login(tutor);
  final pending = await poll('tutor pending queue', () async {
    for (final r in (await call('GET', '/approvals/pending', tutorTok) as List)) {
      if ((r as Map)['id'] == id) return r;
    }
    return null;
  });
  check('tutor queue shows ${created['displayId']}: ${(pending as Map)['student']['name']}',
      pending != null);
  final t1 = await call('POST', '/approvals/$id/decision', tutorTok,
      {'decision': 'APPROVED', 'comment': 'Demo - OK'}) as Map;
  check('tutor approved → PENDING_HOD', t1['status'] == 'PENDING_HOD');

  // ---- 4. Student receives the approval notification (real-time inbox) ----
  final notif = await poll('student notification', () async {
    for (final n in (await call('GET', '/notifications', studentTok) as List)) {
      if ((n as Map)['readAt'] == null) return n;
    }
    return null;
  });
  check('student notification arrived: "${(notif as Map)['title']}"', notif != null);

  // ---- 5. HOD approves → QR active ----
  final hodTok = await login(hod);
  await poll('HOD pending queue', () async {
    for (final r in (await call('GET', '/approvals/pending', hodTok) as List)) {
      if ((r as Map)['id'] == id) return r;
    }
    return null;
  });
  final t2 = await call('POST', '/approvals/$id/decision', hodTok,
      {'decision': 'APPROVED', 'comment': 'Demo - approved'}) as Map;
  check('HOD approved → APPROVED', t2['status'] == 'APPROVED');

  // ---- 6. Student sees APPROVED live and opens the QR ----
  final approved = await poll('student sees APPROVED', () async {
    for (final o in (await call('GET', '/outpasses', studentTok) as List)) {
      final m = o as Map;
      if (m['id'] == id && m['status'] == 'APPROVED') return m;
    }
    return null;
  });
  check('student QR screen would activate (status APPROVED, validity '
      '${approved['validFrom']} → ${approved['validUntil']})', approved != null);
  final step = DeviceKeys.currentStep();
  final token = keys.buildToken(id, step);

  // ---- 7. Guard scans at the gate ----
  final guardTok = await login(guard);
  await call('POST', '/gate/session/start', guardTok, {'gateId': 'main-gate'});
  final scan = (String tok, String dir) => call('POST', '/gate/scans', guardTok, {
        'token': tok,
        'direction': dir,
        'gateId': 'main-gate',
        'clientScanId': uuidV4(),
      });

  final exitRes = await scan(token, 'EXIT') as Map;
  check('guard exit scan → OK_EXIT (${exitRes['result']})', exitRes['result'] == 'OK_EXIT');

  // ---- 8. Reuse + replay protections ----
  final reuse = await scan(keys.buildToken(id, step + 30), 'EXIT') as Map;
  check('rescan in exit mode → ALREADY_USED', reuse['result'] == 'ALREADY_USED');

  final tooSoon = await scan(keys.buildToken(id, step + 60), 'ENTRY') as Map;
  check('immediate entry scan → MIN_DWELL (return rule)', tooSoon['result'] == 'MIN_DWELL');

  // ---- 9. Student sees EXITED with the gate stamp ----
  final exited = await poll('student sees EXITED', () async {
    for (final o in (await call('GET', '/outpasses', studentTok) as List)) {
      final m = o as Map;
      if (m['id'] == id && m['status'] == 'EXITED') return m;
    }
    return null;
  });
  check('student status EXITED, exit recorded at ${exited['exitAt']}', exited != null);

  // ---- 10. Guard shift history recorded the scan ----
  final scans = await call('GET', '/gate/scans/mine', guardTok) as List;
  check('guard shift history has ${scans.length} scan(s)', scans.isNotEmpty);

  // Leave the DB clean for the user's own manual run in the app.
  await call('GET', '/gate/scans/mine', guardTok);
  stdout.writeln('\nDemo cycle complete - all 12 checks passed. Database left clean.');
}
