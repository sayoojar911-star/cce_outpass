import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cce_outpass/api_client.dart';
import 'package:cce_outpass/app_state.dart';
import 'package:cce_outpass/main.dart';
import 'package:cce_outpass/admin_screen.dart';
import 'package:cce_outpass/approver_screen.dart';
import 'package:cce_outpass/guard_screen.dart';
import 'package:cce_outpass/login_screen.dart';
import 'package:cce_outpass/student_screen.dart';

class MockTestApiClient extends ApiClient {
  @override
  Future<dynamic> get(String path) async => [];
  @override
  Future<dynamic> post(String path, {Object? body}) async => {};
  @override
  Future<dynamic> delete(String path) async => {};

  @override
  Future<List<dynamic>> adminGetUsers() async => [];
  @override
  Future<List<dynamic>> adminGetDepartments() async => [];
  @override
  Future<List<dynamic>> adminGetOutpasses() async => [];
  @override
  Future<Map<String, dynamic>> adminGetSettings() async => {};
  @override
  Future<List<dynamic>> adminGetAuditLog({int limit = 50, int offset = 0}) async => [];
  @override
  Future<List<dynamic>> guardScans() async => [];
  @override
  Future<List<dynamic>> myOutpasses() async => [];
  @override
  Future<List<dynamic>> pending() async => [];
  @override
  Future<void> startShift(String gateId) async {}
}

void main() {
  group('Phone Number Normalization', () {
    test('normalizes various phone number formats into 10 digits', () {
      expect(normalizeMobilePhone('+91 8921578839'), '8921578839');
      expect(normalizeMobilePhone('+91-8921-578839'), '8921578839');
      expect(normalizeMobilePhone('918921578839'), '8921578839');
      expect(normalizeMobilePhone('  8921578839  '), '8921578839');
      expect(normalizeMobilePhone('+91 (892) 157-8839'), '8921578839');
      expect(normalizeMobilePhone('89215 78839'), '8921578839');
    });

    test('rejects or flags invalid phone strings', () {
      expect(normalizeMobilePhone('12345'), '12345');
      expect(normalizeMobilePhone(''), '');
      expect(normalizeMobilePhone(null), '');
    });
  });

  group('RootRouter Role-Based Routing (No fallback to Student)', () {
    testWidgets('unauthenticated user sees LoginScreen', (tester) async {
      final state = AppState(api: MockTestApiClient());
      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(state: state, child: const RootRouter()),
        ),
      );
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('STUDENT lands on StudentHome', (tester) async {
      final state = AppState(api: MockTestApiClient());
      state.userRole = 'STUDENT';
      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(state: state, child: const RootRouter()),
        ),
      );
      expect(find.byType(StudentHome), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('TUTOR lands on ApproverHome', (tester) async {
      final state = AppState(api: MockTestApiClient());
      state.userRole = 'TUTOR';
      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(state: state, child: const RootRouter()),
        ),
      );
      expect(find.byType(ApproverHome), findsOneWidget);
      expect(find.byType(StudentHome), findsNothing);
    });

    testWidgets('HOD lands on ApproverHome', (tester) async {
      final state = AppState(api: MockTestApiClient());
      state.userRole = 'HOD';
      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(state: state, child: const RootRouter()),
        ),
      );
      expect(find.byType(ApproverHome), findsOneWidget);
      expect(find.byType(StudentHome), findsNothing);
    });

    testWidgets('GUARD lands on GuardHome', (tester) async {
      final state = AppState(api: MockTestApiClient());
      state.userRole = 'GUARD';
      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(state: state, child: const RootRouter()),
        ),
      );
      expect(find.byType(GuardHome), findsOneWidget);
      expect(find.byType(StudentHome), findsNothing);
    });

    testWidgets('ADMIN lands on AdminHome', (tester) async {
      final state = AppState(api: MockTestApiClient());
      state.userRole = 'ADMIN';
      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(state: state, child: const RootRouter()),
        ),
      );
      final err = tester.takeException();
      if (err != null) print('CAUGHT ADMIN ERROR: $err');
      expect(find.byType(AdminHome), findsOneWidget);
      expect(find.byType(StudentHome), findsNothing);
    });
  });
}
