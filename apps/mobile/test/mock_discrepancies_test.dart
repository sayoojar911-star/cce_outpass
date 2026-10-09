import 'package:flutter_test/flutter_test.dart';
import 'package:cce_outpass/mock_backend.dart';
import 'package:cce_outpass/api_client.dart';
import 'package:cce_outpass/qr_token.dart';

void main() {
  group('Mock vs Live Discrepancy Alignment Tests', () {
    late ApiClient api;
    late DeviceKeys keys;

    setUp(() {
      MockBackend.instance.resetForTesting();
      api = ApiClient(isDemoMode: true);
      keys = DeviceKeys.generate();
    });

    test('Rule 1: Return dwell rule enforces minimum 10 minutes between exit and return', () async {
      await api.verifyFirebasePhone('9074121510');
      await api.registerDevice(keys.publicKeyPem(), 'web');

      final now = DateTime.now();
      final outpass = await api.createOutpass(
        requestedExitAt: now.toIso8601String(),
        expectedReturnAt: now.add(const Duration(hours: 2)).toIso8601String(),
        destination: 'Market',
        purposeCategory: 'Personal',
      );
      final id = outpass['id'] as String;

      // Move to APPROVED
      await api.verifyFirebasePhone('9000000001');
      await api.decide(id, 'APPROVED');
      await api.verifyFirebasePhone('9000000002');
      await api.decide(id, 'APPROVED');

      // Exit scan
      await api.verifyFirebasePhone('9000000090');
      final step = DeviceKeys.currentStep();
      final exitToken = keys.buildToken(id, step);
      final exitResult = await api.scan(
        token: exitToken,
        direction: 'EXIT',
        gateId: 'main-gate',
        clientScanId: uuidV4(),
      );
      expect(exitResult['result'], equals('OK_EXIT'));

      // Attempt entry scan immediately -> MIN_DWELL rejection
      final entryToken = keys.buildToken(id, step + 30);
      final earlyEntry = await api.scan(
        token: entryToken,
        direction: 'ENTRY',
        gateId: 'main-gate',
        clientScanId: uuidV4(),
      );
      expect(earlyEntry['result'], equals('MIN_DWELL'),
          reason: 'Return scan within 10 minutes of exit must be rejected with MIN_DWELL');

      // Backdate exit to 10 minutes and 1 second ago -> OK_ENTRY allowed
      await api.verifyFirebasePhone('9074121510');
      final passes = await api.myOutpasses();
      final pass = passes.firstWhere((p) => p['id'] == id);
      pass['exitAt'] = DateTime.now().subtract(const Duration(minutes: 10, seconds: 1)).toIso8601String();

      await api.verifyFirebasePhone('9000000090');
      final validEntryToken = keys.buildToken(id, step + 60);
      final validEntry = await api.scan(
        token: validEntryToken,
        direction: 'ENTRY',
        gateId: 'main-gate',
        clientScanId: uuidV4(),
      );
      expect(validEntry['result'], equals('OK_ENTRY'));
      expect(validEntry['outpass']['status'], equals('RETURNED'));
    });

    test('Rule 2: Concurrent active outpasses are rejected', () async {
      await api.verifyFirebasePhone('9074121510');
      final now = DateTime.now();

      // Create first active outpass
      await api.createOutpass(
        requestedExitAt: now.toIso8601String(),
        expectedReturnAt: now.add(const Duration(hours: 2)).toIso8601String(),
        destination: 'Hospital',
        purposeCategory: 'Medical',
      );

      // Attempt second outpass while first is active -> throws Exception
      expect(
        () => api.createOutpass(
          requestedExitAt: now.toIso8601String(),
          expectedReturnAt: now.add(const Duration(hours: 2)).toIso8601String(),
          destination: 'Station',
          purposeCategory: 'Personal',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Rule 3: QR replay and stale timestamp validation (monotonic check)', () async {
      await api.verifyFirebasePhone('9074121510');
      await api.registerDevice(keys.publicKeyPem(), 'web');

      final now = DateTime.now();
      final outpass = await api.createOutpass(
        requestedExitAt: now.toIso8601String(),
        expectedReturnAt: now.add(const Duration(hours: 2)).toIso8601String(),
        destination: 'Bank',
        purposeCategory: 'Official',
      );
      final id = outpass['id'] as String;

      await api.verifyFirebasePhone('9000000001');
      await api.decide(id, 'APPROVED');
      await api.verifyFirebasePhone('9000000002');
      await api.decide(id, 'APPROVED');

      await api.verifyFirebasePhone('9000000090');
      final step = DeviceKeys.currentStep();

      // Timestamp older than 75 seconds -> QR_STALE
      final staleToken = keys.buildToken(id, step - 90);
      final staleResult = await api.scan(
        token: staleToken,
        direction: 'EXIT',
        gateId: 'main-gate',
        clientScanId: uuidV4(),
      );
      expect(staleResult['result'], equals('QR_STALE'));

      // Monotonic replay test: set outpass lastTokenTs to a future/current step
      await api.verifyFirebasePhone('9074121510');
      final passes = await api.myOutpasses();
      final pass = passes.firstWhere((p) => p['id'] == id);
      pass['lastTokenTs'] = step + 30; // already seen a token at step + 30

      await api.verifyFirebasePhone('9000000090');
      final replayToken = keys.buildToken(id, step);
      final replayResult = await api.scan(
        token: replayToken,
        direction: 'EXIT',
        gateId: 'main-gate',
        clientScanId: uuidV4(),
      );
      expect(replayResult['result'], equals('QR_STALE'),
          reason: 'Tokens with timestamp less than or equal to lastTokenTs must be rejected');
    });

    test('Rule 4: Emergency approval notifications are dispatched to Tutor and HOD simultaneously', () async {
      await api.verifyFirebasePhone('9074121510');
      final now = DateTime.now();

      await api.createOutpass(
        requestedExitAt: now.toIso8601String(),
        expectedReturnAt: now.add(const Duration(hours: 2)).toIso8601String(),
        destination: 'Emergency Clinic',
        purposeCategory: 'Medical',
        type: 'EMERGENCY',
      );

      final tutorNotifs = MockBackend.instance.notificationsFor('u-tutor-1');
      final hodNotifs = MockBackend.instance.notificationsFor('u-hod-1');

      expect(tutorNotifs, isNotEmpty);
      expect(tutorNotifs.first['title'], contains('EMERGENCY'));

      expect(hodNotifs, isNotEmpty);
      expect(hodNotifs.first['title'], contains('EMERGENCY'));
    });
  });
}
