import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cce_outpass/api_client.dart';
import 'package:cce_outpass/app_state.dart';
import 'package:cce_outpass/login_screen.dart';
import 'package:cce_outpass/student_registration_screen.dart';
import 'package:cce_outpass/theme/app_theme.dart';

class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data.remove(key);

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data.clear();

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      Map.from(_data);

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data.containsKey(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockRegistrationApiClient extends ApiClient {
  MockRegistrationApiClient() : super(baseUrl: 'http://localhost:3000/v1');

  bool sendSignupOtpCalled = false;
  bool verifySignupOtpCalled = false;
  bool registerStudentCalled = false;
  Map<String, dynamic>? lastRegistrationPayload;

  @override
  Future<Map<String, dynamic>> sendSignupOtp(String mobile) async {
    sendSignupOtpCalled = true;
    return {'ok': true, 'message': 'OTP sent'};
  }

  @override
  Future<Map<String, dynamic>> verifySignupOtp(String mobile, String code) async {
    verifySignupOtpCalled = true;
    if (code == '123456') {
      return {'ok': true, 'idToken': 'test:$mobile', 'mobile': mobile};
    }
    throw ApiException('Invalid OTP. Please try again.', 401);
  }

  @override
  Future<Map<String, dynamic>> registerStudent({
    required String idToken,
    required String name,
    required String rollNo,
    required int year,
    required String department,
    required String photo,
  }) async {
    registerStudentCalled = true;
    lastRegistrationPayload = {
      'idToken': idToken,
      'name': name,
      'rollNo': rollNo,
      'year': year,
      'department': department,
      'photo': photo,
    };
    return {
      'accessToken': 'mock-access-token',
      'refreshToken': 'mock-refresh-token',
      'user': {
        'id': 'mock-student-id',
        'name': name,
        'mobile': '9895061555',
        'roleId': 'student',
        'role': 'STUDENT',
        'permissions': ['createOutpass'],
        'department': department,
        'year': year,
      },
      'student': {
        'registerNo': rollNo,
        'department': department,
        'year': year,
        'semester': (year - 1) * 2 + 1,
      },
    };
  }

  @override
  Future<dynamic> registerDevice(String publicKeyPem, String platform) async {
    return {'id': 'mock-device-id', 'platform': platform};
  }

  @override
  Future<Map<String, dynamic>> getAllConfig() async {
    return {
      'roles': [
        {'id': 'student', 'name': 'Student', 'permissions': ['createOutpass']},
      ],
      'departments': [
        {'id': 'd1', 'code': 'CSE', 'name': 'Computer Science and Engineering'},
        {'id': 'd2', 'code': 'ECE', 'name': 'Electronics and Communication'},
      ],
      'purposeCategories': [],
      'outpassTypes': [],
      'settings': {},
    };
  }
}

Widget buildTestApp({required AppState state, required Widget child}) {
  return AppStateScope(
    state: state,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Student Registration UI & Flow Tests', () {
    late MockRegistrationApiClient mockApi;
    late FakeSecureStorage fakeStorage;
    late AppState state;

    setUp(() {
      mockApi = MockRegistrationApiClient();
      fakeStorage = FakeSecureStorage();
      state = AppState(api: mockApi, storage: fakeStorage);
    });

    testWidgets('1. Login screen renders "New student? Create an account" link and navigates',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(state: state, child: const LoginScreen()));
      await tester.pump(const Duration(milliseconds: 50));

      // Link text exists
      expect(find.text('New student? '), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);

      // Tap 'Create an account'
      await tester.tap(find.text('Create an account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Navigated to StudentRegistrationScreen
      expect(find.byType(StudentRegistrationScreen), findsOneWidget);
      expect(find.text('CHRIST COLLEGE OF ENGINEERING'), findsWidgets);
    });

    testWidgets('2. Student registration screen renders ID card interface with all required fields',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(state: state, child: const StudentRegistrationScreen()));
      await tester.pump(const Duration(milliseconds: 50));

      // College physical ID card header elements
      expect(find.text('CHRIST COLLEGE OF ENGINEERING'), findsWidgets);
      expect(find.text('OFFICIAL STUDENT IDENTITY CARD'), findsOneWidget);

      // Required fields
      expect(find.text('Student Photo'), findsOneWidget);
      expect(find.text('Full Name *'), findsOneWidget);
      expect(find.text('Mobile Number *'), findsOneWidget);
      expect(find.text('College Roll Number *'), findsOneWidget);
      expect(find.text('Current Year of Study *'), findsOneWidget);
      expect(find.text('Department *'), findsOneWidget);

      // Buttons
      expect(find.text('Send OTP'), findsOneWidget);
      expect(find.text('Complete Registration & Issue ID'), findsOneWidget);
    });

    testWidgets('3. Year dropdown contains 1st, 2nd, 3rd, and 4th Year', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(state: state, child: const StudentRegistrationScreen()));
      await tester.pump(const Duration(milliseconds: 50));

      // Find the year dropdown (defaults to 1st Year)
      expect(find.text('1st Year'), findsOneWidget);

      // Open the year dropdown
      await tester.tap(find.text('1st Year'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Dropdown menu options exist
      expect(find.text('2nd Year'), findsWidgets);
      expect(find.text('3rd Year'), findsWidgets);
      expect(find.text('4th Year'), findsWidgets);

      // Select 3rd Year
      await tester.tap(find.text('3rd Year').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('3rd Year'), findsWidgets);
    });

    testWidgets('4. Validates required fields and roll number format before submission',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(state: state, child: const StudentRegistrationScreen()));
      await tester.pump(const Duration(milliseconds: 50));

      // Try submitting empty form
      await tester.ensureVisible(find.text('Complete Registration & Issue ID'));
      await tester.tap(find.text('Complete Registration & Issue ID'));
      await tester.pump(const Duration(milliseconds: 100));

      // Validation errors shown
      expect(find.text('Please enter student full name'), findsOneWidget);
      expect(find.text('10-digit number'), findsOneWidget);
      expect(find.text('Please enter roll number'), findsOneWidget);

      // Enter invalid roll number (does not start with CCE)
      await tester.enterText(find.widgetWithText(TextFormField, 'College Roll Number *'), 'INVALID123');
      await tester.tap(find.text('Complete Registration & Issue ID'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Must start with CCE followed by alphanumeric characters'), findsOneWidget);
    });

    testWidgets('5. Performs OTP verification flow and completes student registration',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(state: state, child: const StudentRegistrationScreen()));
      await tester.pump(const Duration(milliseconds: 50));

      // 1. Enter full name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name *'),
        'Devanand P',
      );

      // 2. Enter 10-digit mobile number
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mobile Number *'),
        '9895061555',
      );

      // 3. Tap Send OTP
      await tester.tap(find.text('Send OTP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockApi.sendSignupOtpCalled, isTrue);
      expect(find.text('Enter OTP sent to +91 9895061555'), findsOneWidget);

      // 4. Enter 6-digit OTP
      await tester.enterText(
        find.widgetWithText(TextFormField, '6-digit OTP'),
        '123456',
      );

      // 5. Tap Verify OTP
      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockApi.verifySignupOtpCalled, isTrue);
      expect(find.text('Mobile Verified: +91 9895061555'), findsOneWidget);

      // 6. Enter valid CCE Roll Number
      await tester.enterText(
        find.widgetWithText(TextFormField, 'College Roll Number *'),
        'CCE23CS042',
      );

      // 7. Submit registration
      await tester.ensureVisible(find.text('Complete Registration & Issue ID'));
      await tester.tap(find.text('Complete Registration & Issue ID'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockApi.registerStudentCalled, isTrue);
      expect(mockApi.lastRegistrationPayload!['rollNo'], 'CCE23CS042');
      expect(mockApi.lastRegistrationPayload!['name'], 'Devanand P');
      expect(mockApi.lastRegistrationPayload!['year'], 1);

      // Success modal is presented
      expect(find.text('Registration Successful!'), findsOneWidget);
      expect(find.text('Continue to Student Dashboard →'), findsOneWidget);
      expect(find.text('Roll No: CCE23CS042'), findsOneWidget);
    });
  });
}
