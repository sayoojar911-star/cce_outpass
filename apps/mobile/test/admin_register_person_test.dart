import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cce_outpass/api_client.dart';
import 'package:cce_outpass/app_state.dart';
import 'package:cce_outpass/admin_screen.dart';

class MockAdminApiClient extends ApiClient {
  List<Map<String, dynamic>> users = [
    {
      'id': 'user-1',
      'name': 'Existing Student',
      'role': 'STUDENT',
      'mobile': '9111111111',
      'department': 'CSE',
      'year': 1,
      'division': 'A',
      'status': 'ACTIVE',
      'student': {
        'registerNo': 'CCE1001',
        'year': 1,
        'division': 'A',
      },
    },
    {
      'id': 'user-2',
      'name': 'Existing Tutor',
      'role': 'TUTOR',
      'mobile': '9222222222',
      'department': 'CSE',
      'year': 1,
      'division': 'A',
      'status': 'ACTIVE',
    },
  ];

  List<Map<String, dynamic>> departments = [
    {
      'id': 'dept-1',
      'code': 'CSE',
      'name': 'Computer Science',
      'divisions': [
        {'id': 'div-1', 'name': 'A'},
        {'id': 'div-2', 'name': 'B'},
      ],
    },
  ];

  bool shouldThrow409 = false;

  @override
  Future<List<dynamic>> adminGetUsers() async => List.from(users);

  @override
  Future<List<dynamic>> adminGetDepartments() async => List.from(departments);

  @override
  Future<List<dynamic>> adminGetOutpasses() async => [];

  @override
  Future<Map<String, dynamic>> adminGetSettings() async => {};

  @override
  Future<List<dynamic>> adminGetAuditLog({int limit = 50, int offset = 0}) async => [];

  @override
  Future<Map<String, dynamic>> adminAddUser(Map<String, dynamic> data) async {
    if (shouldThrow409) {
      throw ApiException('A user with this mobile already exists', 409);
    }
    final newUser = {
      'id': 'user-${users.length + 1}',
      'name': data['name'],
      'role': data['role'],
      'mobile': data['mobile'],
      'department': data['department'],
      'year': data['year'],
      'division': data['division'],
      'status': 'ACTIVE',
      'student': {
        'registerNo': data['registerNo'] ?? 'CCE2001',
        'year': data['year'],
        'division': data['division'],
      },
    };
    users.add(newUser);
    return newUser;
  }
}

Widget createTestApp({required MockAdminApiClient api}) {
  final state = AppState(api: api);
  state.userRole = 'ADMIN';
  return MaterialApp(
    home: AppStateScope(
      state: state,
      child: const AdminHome(),
    ),
  );
}

void main() {
  testWidgets('Register Person: dialog closes, snackbar appears, and list + tab count updates', (tester) async {
    final mockApi = MockAdminApiClient();

    // Set a large screen size to avoid desktop/mobile overflow in tests
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestApp(api: mockApi));
    await tester.pumpAndSettle();

    // Switch to People tab (index 1 on NavigationBar)
    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();

    // Initial check: Students tab shows "(1)"
    expect(find.text('Students (1)'), findsOneWidget);
    expect(find.text('Existing Student'), findsOneWidget);

    // Tap "Add Person" button
    await tester.tap(find.text('Add Person'));
    await tester.pumpAndSettle();

    // Verify dialog opened
    expect(find.text('Register New Person'), findsOneWidget);

    // Fill in Name and Mobile fields
    await tester.enterText(find.widgetWithText(TextFormField, 'Full Name *'), 'Rahul Sharma');
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number (10 digits) *'), '9876543210');
    await tester.pumpAndSettle();

    // Find and tap Register button
    final registerButton = find.widgetWithText(FilledButton, 'Register');
    expect(registerButton, findsOneWidget);
    await tester.tap(registerButton);

    // Wait for the async save and animation to complete
    await tester.pumpAndSettle();

    // Verify the dialog closed
    expect(find.text('Register New Person'), findsNothing);

    // Verify success snackbar appears
    expect(find.text('Person registered successfully'), findsOneWidget);

    // Verify people list and Students tab count updated
    expect(find.text('Students (2)'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsOneWidget);
  });

  testWidgets('Register Person: handles 409 duplicate phone with clear message and re-enables button', (tester) async {
    final mockApi = MockAdminApiClient();
    mockApi.shouldThrow409 = true;

    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestApp(api: mockApi));
    await tester.pumpAndSettle();

    // Switch to People tab
    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();

    // Tap Add Person
    await tester.tap(find.text('Add Person'));
    await tester.pumpAndSettle();

    // Fill in fields with a phone number that backend rejects as duplicate
    await tester.enterText(find.widgetWithText(TextFormField, 'Full Name *'), 'Duplicate User');
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number (10 digits) *'), '9998887776');
    await tester.pumpAndSettle();

    // Tap Register
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pumpAndSettle();

    // Dialog remains open
    expect(find.text('Register New Person'), findsOneWidget);

    // Clear duplicate phone message is displayed
    expect(find.text('This phone number is already registered to another user'), findsAtLeastNWidgets(1));

    // Register button is re-enabled (not stuck on Saving)
    expect(find.widgetWithText(FilledButton, 'Register'), findsOneWidget);
    expect(find.text('Saving…'), findsNothing);
  });

  testWidgets('Bug 2: Selection bar appears on Students tab and clears when switching tabs', (tester) async {
    final mockApi = MockAdminApiClient();

    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestApp(api: mockApi));
    await tester.pumpAndSettle();

    // Switch to People tab
    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();

    // Ensure we are on Students tab (index 0)
    expect(find.text('Students (1)'), findsOneWidget);
    // Selection banner should NOT be visible initially
    expect(find.text('1 student(s) selected'), findsNothing);

    // Tap checkbox for Existing Student
    final checkbox = find.byType(Checkbox).first;
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    // Selection banner MUST now appear on Students tab
    expect(find.text('1 student(s) selected'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Assign Tutor'), findsOneWidget);

    // Switch to Tutors tab
    await tester.tap(find.text('Tutors (1)'));
    await tester.pumpAndSettle();

    // Selection banner must NOT be visible on Tutors tab
    expect(find.text('1 student(s) selected'), findsNothing);

    // Switch back to Students tab
    await tester.tap(find.text('Students (1)'));
    await tester.pumpAndSettle();

    // Selection was cleared when tab changed, banner is still absent
    expect(find.text('1 student(s) selected'), findsNothing);
  });
}
