import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cce_outpass/api_client.dart';
import 'package:cce_outpass/app_state.dart';
import 'package:cce_outpass/admin_screen.dart';
import 'package:cce_outpass/approver_screen.dart';
import 'package:cce_outpass/guard_screen.dart';
import 'package:cce_outpass/login_screen.dart';
import 'package:cce_outpass/student_screen.dart';

class MockResponsiveApiClient extends ApiClient {
  @override
  Future<dynamic> get(String path) async => [];
  @override
  Future<dynamic> post(String path, {Object? body}) async => {};
  @override
  Future<dynamic> delete(String path) async => {};

  @override
  Future<List<dynamic>> adminGetUsers() async => [
    {
      'id': 'user-1',
      'name': 'Rahul Sharma',
      'role': 'STUDENT',
      'mobile': '9876543210',
      'department': 'CSE',
      'year': 3,
      'division': 'A',
      'status': 'ACTIVE',
      'student': {
        'registerNo': 'CCE1001',
        'year': 3,
        'division': 'A',
      },
    },
  ];

  @override
  Future<List<dynamic>> adminGetDepartments() async => [
    {
      'id': 'dept-1',
      'code': 'CSE',
      'name': 'Computer Science and Engineering',
      'divisions': [
        {'id': 'div-1', 'name': 'A'},
        {'id': 'div-2', 'name': 'B'},
      ],
    },
  ];

  @override
  Future<List<dynamic>> adminGetOutpasses() async => [];
  @override
  Future<Map<String, dynamic>> adminGetSettings() async => {};
  @override
  Future<List<dynamic>> adminGetAuditLog({int limit = 50, int offset = 0}) async => [];

  @override
  Future<List<dynamic>> guardScans() async => [];

  @override
  Future<List<dynamic>> myOutpasses() async => [
    {
      'id': 'op-101',
      'type': 'EMERGENCY',
      'reason': 'Medical emergency checkup with doctor and hospital prescription',
      'status': 'APPROVED',
      'approvedAt': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      'validUntil': DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
      'token': 'CCE-EMG-9988',
      'qrCode': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    },
  ];

  @override
  Future<List<dynamic>> pending() async => [
    {
      'id': 'op-202',
      'student': {
        'name': 'Alex John Christo Longname',
        'department': 'Computer Science Engineering',
        'year': 3,
        'division': 'B',
      },
      'type': 'ACADEMIC',
      'reason': 'Attending statewide Hackathon competition event representing college campus',
      'createdAt': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
    },
  ];

  @override
  Future<void> startShift(String gateId) async {}
}

void main() {
  const targetSizes = [
    Size(360, 640),   // Small phone
    Size(390, 844),   // Standard phone
    Size(430, 932),   // Large phone
    Size(768, 1024),  // Tablet
    Size(1280, 800),  // Desktop small
    Size(1920, 1080), // Desktop large
  ];

  const targetScales = [1.0, 1.5];

  for (final size in targetSizes) {
    for (final scale in targetScales) {
      final suffix = '${size.width.toInt()}x${size.height.toInt()}_scale_${scale}x';

      group('Responsive Overflow & Layout: $suffix', () {
        testWidgets('LoginScreen layout ($suffix)', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });

          final state = AppState(api: MockResponsiveApiClient());
          await tester.pumpWidget(
            MaterialApp(
              home: AppStateScope(
                state: state,
                child: const LoginScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(LoginScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('StudentHome layout ($suffix)', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });

          final state = AppState(api: MockResponsiveApiClient());
          state.userRole = 'STUDENT';
          await tester.pumpWidget(
            MaterialApp(
              home: AppStateScope(
                state: state,
                child: const StudentHome(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final err = tester.takeException();
          if (err != null) debugPrint('ERROR in StudentHome ($suffix): $err');
          expect(err, isNull);
        });

        testWidgets('ApproverHome layout ($suffix)', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });

          final state = AppState(api: MockResponsiveApiClient());
          state.userRole = 'TUTOR';
          await tester.pumpWidget(
            MaterialApp(
              home: AppStateScope(
                state: state,
                child: const ApproverHome(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(ApproverHome), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('GuardHome layout ($suffix)', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });

          final state = AppState(api: MockResponsiveApiClient());
          state.userRole = 'GUARD';
          await tester.pumpWidget(
            MaterialApp(
              home: AppStateScope(
                state: state,
                child: const GuardHome(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(GuardHome), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('AdminHome layout ($suffix)', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });

          FlutterErrorDetails? caught;
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            caught = details;
            prevOnError?.call(details);
          };

          final state = AppState(api: MockResponsiveApiClient());
          state.userRole = 'ADMIN';
          await tester.pumpWidget(
            MaterialApp(
              home: AppStateScope(
                state: state,
                child: const AdminHome(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(AdminHome), findsOneWidget);
          final err = tester.takeException();
          if (err != null) {
            debugPrint('ERROR in AdminHome ($suffix): $err');
            if (caught != null) {
              debugPrint('CAUGHT INFORMATION:');
              for (final line in caught!.informationCollector?.call() ?? <DiagnosticsNode>[]) {
                debugPrint('INFO: $line');
              }
            }
          }
          expect(err, isNull);
        });
      });
    }
  }
}
