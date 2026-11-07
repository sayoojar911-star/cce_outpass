import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cce_outpass/admin_screen.dart';
import 'package:cce_outpass/app_state.dart';
import 'package:cce_outpass/api_client.dart';

class MockApi extends ApiClient {
  @override
  Future<List<dynamic>> adminGetUsers() async {
    return [
      {
        'id': '1',
        'name': 'shyama',
        'email': null,
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
        'roleId': 'hod',
        'role': 'Head of Department',
        'department': 'CSE',
        'active': true,
        'status': 'ACTIVE',
      },
      {
        'id': '3',
        'name': 'nidhin',
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
        'roleId': 'tutor',
        'role': 'Class Tutor',
        'department': 'CE',
        'active': true,
        'status': 'ACTIVE',
      },
      {
        'id': '6',
        'name': 'Chief Guard Suresh',
        'roleId': 'guard',
        'role': 'Gate Security Guard',
        'department': null,
        'active': true,
        'status': 'ACTIVE',
      },
      {
        'id': '7',
        'name': 'Arjun K',
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
        'roleId': 'admin',
        'role': 'System Administrator',
        'department': null,
        'active': true,
        'status': 'ACTIVE',
      },
    ];
  }

  @override
  Future<List<dynamic>> adminGetDepartments() async => [{'id': 'dept-1', 'code': 'CSE', 'name': 'CSE'}];

  @override
  Future<List<dynamic>> adminGetOutpasses() async => [];

  @override
  Future<Map<String, dynamic>> adminGetSettings() async => {};

  @override
  Future<List<dynamic>> adminGetAuditLog({int limit = 50, int offset = 0}) async => [];

  @override
  Future<List<dynamic>> getRoles() async => [];

  @override
  Future<List<dynamic>> getPurposeCategories() async => [];

  @override
  Future<List<dynamic>> getOutpassTypes() async => [];
}

void main() {
  testWidgets('Test AdminHome dashboard and people tab', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final state = AppState(api: MockApi());

    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(
          home: AdminHome(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Check Dashboard counts
    print('DASHBOARD TEXTS:');
    print('Found "8 registered active accounts": ' + find.text('8 registered active accounts').evaluate().length.toString());
    print('Found "Students": ' + find.text('Students').evaluate().length.toString());

    // Switch to People tab (tab index 1 in NavigationRail)
    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();

    print('PEOPLE TAB:');
    print('Found "Total: 8 members": ' + find.text('Total: 8 members').evaluate().length.toString());
    print('Found "Students (3)": ' + find.text('Students (3)').evaluate().length.toString());
    print('Found "shyama": ' + find.text('shyama').evaluate().length.toString());
    print('Found "nidhin": ' + find.text('nidhin').evaluate().length.toString());
    print('Found "Arjun K": ' + find.text('Arjun K').evaluate().length.toString());
    print('Found "No students found": ' + find.text('No students found').evaluate().length.toString());
  });
}
