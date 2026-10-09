import 'package:cce_outpass/api_client.dart';
import 'package:cce_outpass/mock_backend.dart';
import 'package:cce_outpass/qr_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CCE Outpass Core Loop Lifecycle Tests (Demo Mock)', () {
    late ApiClient api;
    late DeviceKeys deviceKeys;

    setUp(() {
      MockBackend.instance.resetForTesting();
      api = ApiClient(isDemoMode: true);
      deviceKeys = DeviceKeys.generate();
    });

    test('Full lifecycle: Student Request -> Tutor Approve -> HOD Approve -> QR Scan -> Return', () async {
      // 1. Student login
      final studentUser = await api.verifyFirebasePhone('9074121510');
      expect(studentUser['role'], equals('STUDENT'));
      expect(studentUser['name'], equals('Demo Student'));

      // Register device key
      await api.registerDevice(deviceKeys.publicKeyPem(), 'web');

      // 2. Student creates outpass request
      final now = DateTime.now();
      final outpass = await api.createOutpass(
        requestedExitAt: now.add(const Duration(minutes: 30)).toIso8601String(),
        expectedReturnAt: now.add(const Duration(hours: 3)).toIso8601String(),
        destination: 'Thrissur Medical College',
        purposeCategory: 'Medical',
        purposeText: 'Consultation',
      );

      final outpassId = outpass['id'] as String;
      expect(outpass['status'], equals('PENDING_TUTOR'));
      expect(outpass['displayId'], startsWith('OUT-2026-'));

      // 3. Tutor login & view pending
      final tutorUser = await api.verifyFirebasePhone('9000000001');
      expect(tutorUser['role'], equals('TUTOR'));

      final tutorPending = await api.pending();
      expect(tutorPending.any((o) => o['id'] == outpassId), isTrue);

      // Tutor approves
      final tutorDecision = await api.decide(outpassId, 'APPROVED');
      expect(tutorDecision['status'], equals('PENDING_HOD'));

      // 4. HOD login & view pending
      final hodUser = await api.verifyFirebasePhone('9000000002');
      expect(hodUser['role'], equals('HOD'));

      final hodPending = await api.pending();
      expect(hodPending.any((o) => o['id'] == outpassId), isTrue);

      // HOD approves
      final hodDecision = await api.decide(outpassId, 'APPROVED');
      expect(hodDecision['status'], equals('APPROVED'));

      // 5. Student checks active outpass -> APPROVED
      await api.verifyFirebasePhone('9074121510');
      final myPasses = await api.myOutpasses();
      final activePass = myPasses.firstWhere((o) => o['id'] == outpassId);
      expect(activePass['status'], equals('APPROVED'));

      // Student generates rotating QR token
      final step = DeviceKeys.currentStep();
      final token = deviceKeys.buildToken(outpassId, step);
      expect(token, startsWith('v1.$outpassId.$step.'));

      // 6. Guard scans at exit gate
      final guardUser = await api.verifyFirebasePhone('9000000090');
      expect(guardUser['role'], equals('GUARD'));

      final exitScan = await api.scan(
        token: token,
        direction: 'EXIT',
        gateId: 'main-gate',
        clientScanId: uuidV4(),
      );

      expect(exitScan['result'], equals('OK_EXIT'));
      expect(exitScan['outpass']['status'], equals('EXITED'));

      // 7. Test replay/duplicate scan prevention
      final duplicateScan = await api.scan(
        token: token,
        direction: 'EXIT',
        gateId: 'main-gate',
        clientScanId: uuidV4(),
      );
      expect(duplicateScan['result'], equals('ALREADY_USED'));

      // 8. Test immediate return dwell rejection (10-minute return rule)
      final returnStep = DeviceKeys.currentStep() + 30;
      final returnToken = deviceKeys.buildToken(outpassId, returnStep);

      final immediateScan = await api.scan(
        token: returnToken,
        direction: 'ENTRY',
        gateId: 'main-gate',
        clientScanId: uuidV4(),
      );
      expect(immediateScan['result'], equals('MIN_DWELL'));

      // 9. Backdate exitAt by 11 minutes and scan again -> OK_ENTRY
      activePass['exitAt'] = DateTime.now().subtract(const Duration(minutes: 11)).toIso8601String();

      final validEntryStep = returnStep + 30;
      final validEntryToken = deviceKeys.buildToken(outpassId, validEntryStep);

      final entryScan = await api.scan(
        token: validEntryToken,
        direction: 'ENTRY',
        gateId: 'main-gate',
        clientScanId: uuidV4(),
      );

      expect(entryScan['result'], equals('OK_ENTRY'));
      expect(entryScan['outpass']['status'], equals('RETURNED'));
    });

    test('Student cancellation before exit marks outpass CANCELLED', () async {
      await api.verifyFirebasePhone('9074121510');
      final now = DateTime.now();
      final outpass = await api.createOutpass(
        requestedExitAt: now.add(const Duration(hours: 1)).toIso8601String(),
        expectedReturnAt: now.add(const Duration(hours: 4)).toIso8601String(),
        destination: 'Library',
        purposeCategory: 'Official',
      );

      final outpassId = outpass['id'] as String;
      expect(outpass['status'], equals('PENDING_TUTOR'));

      await api.cancelOutpass(outpassId);

      final passes = await api.myOutpasses();
      final cancelled = passes.firstWhere((o) => o['id'] == outpassId);
      expect(cancelled['status'], equals('CANCELLED'));
    });

    test('ApiClient demo mode configuration respects explicit flags', () {
      final forcedDemo = ApiClient(isDemoMode: true);
      expect(forcedDemo.isDemoMode, isTrue);

      final forcedProd = ApiClient(isDemoMode: false);
      expect(forcedProd.isDemoMode, isFalse);
    });

    test('Admin role: 8921578838 logs in as ADMIN and can manage users, depts, and settings', () async {
      // 1. Admin login with 8921578838
      final adminUser = await api.verifyFirebasePhone('8921578838');
      expect(adminUser['role'], equals('ADMIN'));
      expect(adminUser['name'], equals('System Administrator'));

      // 2. Unregistered phone number is rejected
      expect(
        () => api.verifyFirebasePhone('9999999999'),
        throwsA(isA<Exception>()),
      );

      // 3. Admin adds a new student
      final newStudent = await api.adminAddUser({
        'name': 'Rahul Sharma',
        'mobile': '9888877777',
        'role': 'STUDENT',
        'department': 'CSE',
        'semester': 4,
      });
      expect(newStudent['name'], equals('Rahul Sharma'));
      expect(newStudent['mobile'], equals('9888877777'));

      // 4. Newly added user can now log in
      final studentLogin = await api.verifyFirebasePhone('9888877777');
      expect(studentLogin['role'], equals('STUDENT'));
      expect(studentLogin['name'], equals('Rahul Sharma'));

      // 5. Admin updates college settings
      await api.adminUpdateSettings(
        collegeName: 'Christ Institute of Technology',
        minDwellMinutes: 15,
        categories: ['Medical', 'Sports', 'Emergency'],
      );
      final settings = await api.adminGetSettings();
      expect(settings['collegeName'], equals('Christ Institute of Technology'));
      expect(settings['minDwellMinutes'], equals(15));
      expect(settings['categories'], contains('Sports'));

      // 6. Admin adds department
      final dept = await api.adminAddOrUpdateDepartment('AI', 'Artificial Intelligence', null);
      expect(dept['code'], equals('AI'));
      final allDepts = await api.adminGetDepartments();
      expect(allDepts.any((d) => d['code'] == 'AI'), isTrue);
    });
  });
}
