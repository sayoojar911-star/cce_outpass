import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cce_outpass/admin_screen.dart';
import 'package:cce_outpass/app_state.dart';
import 'package:cce_outpass/api_client.dart';

class TestMockApi extends ApiClient {
  TestMockApi({this.shouldFail = false, this.isUnauthorized = false});

  final bool shouldFail;
  final bool isUnauthorized;

  @override
  Future<List<dynamic>> adminGetUsers() async {
    if (isUnauthorized) {
      throw Exception('HTTP 401: Unauthorized access');
    }
    if (shouldFail) {
      throw Exception('Network connection refused');
    }
    return [
      {
        'id': '1',
        'name': 'shyama',
        'mobile': '9895061544',
        'roleId': 'student',
        'role': 'Student',
        'departmentId': 'dept-1',
        'department': 'CSE',
        'year': 1,
        'division': 'D',
        'tutorId': '4',
        'active': true,
        'status': 'ACTIVE',
      },
      {
        'id': '2',
        'name': 'sreedha',
        'mobile': '9895061540',
        'roleId': 'hod',
        'role': 'Head of Department',
        'department': 'CSE',
        'active': true,
        'status': 'ACTIVE',
      },
      {
        'id': '3',
        'name': 'nidhin',
        'mobile': '9895061545',
        'roleId': 'student',
        'role': 'Student',
        'department': 'CSE',
        'year': 1,
        'division': 'A',
        'tutorId': '4',
        'active': true,
        'status': 'ACTIVE',
      },
      {
        'id': '4',
        'name': 'sreedevi',
        'mobile': '1234567890',
        'roleId': 'tutor',
        'role': 'Class Tutor',
        'department': 'CSE',
        'year': 1,
        'division': 'A',
        'active': true,
        'status': 'ACTIVE',
      },
      {
        'id': '5',
        'name': 'ranjima',
        'mobile': '1234567891',
        'roleId': 'tutor',
        'role': 'Class Tutor',
        'department': 'CE',
        'active': true,
        'status': 'ACTIVE',
      },
      {
        'id': '6',
        'name': 'Chief Guard Suresh',
        'mobile': '9895061549',
        'roleId': 'guard',
        'role': 'Gate Security Guard',
        'department': null,
        'active': true,
        'status': 'ACTIVE',
      },
      {
        'id': '7',
        'name': 'Arjun K',
        'mobile': '9895061546',
        'roleId': 'student',
        'role': 'Student',
        'department': 'CSE',
        'year': 3,
        'division': 'A',
        'tutorId': '4',
        'active': true,
        'status': 'ACTIVE',
      },
      {
        'id': '8',
        'name': 'System Administrator',
        'mobile': '9895061547',
        'roleId': 'admin',
        'role': 'System Administrator',
        'department': null,
        'active': true,
        'status': 'ACTIVE',
      },
    ];
  }

  @override
  Future<List<dynamic>> adminGetDepartments() async => [
        {'id': 'dept-1', 'code': 'CSE', 'name': 'Computer Science'},
        {'id': 'dept-2', 'code': 'CE', 'name': 'Civil Engineering'},
      ];

  @override
  Future<List<dynamic>> adminGetOutpasses() async => [];

  @override
  Future<Map<String, dynamic>> adminGetSettings() async => {};

  @override
  Future<List<dynamic>> adminGetAuditLog({int limit = 50, int offset = 0}) async => [];

  @override
  Future<List<dynamic>> getRoles() async => [
        {'id': 'student', 'name': 'Student'},
        {'id': 'tutor', 'name': 'Class Tutor'},
        {'id': 'hod', 'name': 'Head of Department'},
        {'id': 'guard', 'name': 'Gate Security Guard'},
        {'id': 'admin', 'name': 'System Administrator'},
      ];

  @override
  Future<List<dynamic>> getPurposeCategories() async => [];

  @override
  Future<List<dynamic>> getOutpassTypes() async => [];
}

void main() {
  testWidgets('Dashboard population cards display correct non-zero counts for all 8 accounts', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final state = AppState(api: TestMockApi());
    await tester.pumpWidget(AppStateScope(state: state, child: const MaterialApp(home: AdminHome())));
    await tester.pumpAndSettle();

    // Verify 8 registered active accounts header
    expect(find.text('8 registered active accounts'), findsOneWidget);

    // Verify Population counts: Students 3, Tutors 2, HODs 1, Guards 1, Admins 1
    expect(find.text('Students'), findsWidgets);
    expect(find.text('3'), findsAtLeastNWidgets(1)); // 3 students
    expect(find.text('Tutors'), findsWidgets);
    expect(find.text('2'), findsAtLeastNWidgets(1)); // 2 tutors
    expect(find.text('HODs'), findsWidgets);
    expect(find.text('1'), findsAtLeastNWidgets(3)); // 1 HOD, 1 Guard, 1 Admin
  });

  testWidgets('People tab displays all 3 students, and switching tabs shows members', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final state = AppState(api: TestMockApi());
    await tester.pumpWidget(AppStateScope(state: state, child: const MaterialApp(home: AdminHome())));
    await tester.pumpAndSettle();

    // Navigate to People tab
    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();

    expect(find.text('Total: 8 members'), findsOneWidget);
    expect(find.text('Students (3)'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'shyama'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'nidhin'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Arjun K'), findsOneWidget);

    // Switch to Tutors tab
    await tester.tap(find.text('Tutors (2)'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'sreedevi'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'ranjima'), findsOneWidget);

    // Switch to HODs tab
    await tester.tap(find.text('HODs (1)'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'sreedha'), findsOneWidget);

    // Switch to Guards tab
    await tester.tap(find.text('Guards (1)'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Chief Guard Suresh'), findsOneWidget);

    // Switch to Admins tab
    await tester.tap(find.text('Admins (1)'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'System Administrator'), findsOneWidget);
  });

  testWidgets('Search and department filters work, and clearing them restores members', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final state = AppState(api: TestMockApi());
    await tester.pumpWidget(AppStateScope(state: state, child: const MaterialApp(home: AdminHome())));
    await tester.pumpAndSettle();

    // Navigate to People tab
    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();

    // Search for "shyama"
    await tester.enterText(find.byType(TextField).first, 'shyama');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'shyama'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'nidhin'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Arjun K'), findsNothing);
    expect(find.text('Filtered by: Search "shyama"'), findsOneWidget);

    // Search for nonexistent person
    await tester.enterText(find.byType(TextField).first, 'nonexistent');
    await tester.pumpAndSettle();

    expect(find.text('No students match active filters'), findsOneWidget);
    expect(find.text('Reset All Filters'), findsOneWidget);

    // Tap "Reset All Filters"
    await tester.tap(find.text('Reset All Filters'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'shyama'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'nidhin'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Arjun K'), findsOneWidget);
  });

  testWidgets('API failure displays error card with Retry instead of false empty state', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final state = AppState(api: TestMockApi(shouldFail: true));
    await tester.pumpWidget(AppStateScope(state: state, child: const MaterialApp(home: AdminHome())));
    await tester.pumpAndSettle();

    expect(find.text('Unable to Load Data'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No students found'), findsNothing);
  });

  testWidgets('Unauthorized error displays Unauthorized Access screen', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final state = AppState(api: TestMockApi(isUnauthorized: true));
    await tester.pumpWidget(AppStateScope(state: state, child: const MaterialApp(home: AdminHome())));
    await tester.pumpAndSettle();

    expect(find.text('Unauthorized Access'), findsOneWidget);
    expect(find.text('Sign In Again'), findsOneWidget);
    expect(find.text('No students found'), findsNothing);
  });
}
