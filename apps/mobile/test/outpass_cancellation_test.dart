import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cce_outpass/app_state.dart';
import 'package:cce_outpass/api_client.dart';
import 'package:cce_outpass/qr_token.dart';
import 'package:cce_outpass/widgets/ticket_outpass.dart';

void main() {
  late AppState testState;

  setUp(() {
    testState = AppState(api: ApiClient(baseUrl: 'http://localhost:3000/v1'));
    testState.userName = 'Sayanth Kumar';
    testState.userRole = 'STUDENT';
    testState.userDepartment = 'Computer Science & Engineering';
    testState.deviceKeys = DeviceKeys.generate();
  });

  Widget createWidgetUnderTest(
    Map<String, dynamic> outpass, {
    VoidCallback? onCancel,
  }) {
    return MaterialApp(
      home: AppStateScope(
        state: testState,
        child: Scaffold(
          body: SingleChildScrollView(
            child: TicketOutpass(
              outpass: outpass,
              enableTilt: false,
              animatePrint: false,
              onCancel: onCancel,
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> samplePass({
    required String status,
    String? exitAt,
    String? entryAt,
    String? cancelReason,
    String? cancelledAt,
  }) {
    return {
      'id': 'op-test-123',
      'displayId': 'CCE-OP-9999',
      'status': status,
      'destination': 'Thrissur Library',
      'purposeCategory': 'ACADEMIC',
      'requestedExitAt': '2026-11-03T10:00:00.000Z',
      'expectedReturnAt': '2026-11-03T12:00:00.000Z',
      'validFrom': '2026-11-03T10:00:00.000Z',
      'validUntil': '2026-11-03T12:00:00.000Z',
      'exitAt': exitAt,
      'entryAt': entryAt,
      'cancelReason': cancelReason,
      'cancelledAt': cancelledAt,
      'student': {
        'name': 'Sayanth Kumar',
        'department': 'CSE',
        'registerNo': 'CCE26CS001',
      },
    };
  }

  group('Outpass Cancellation UI Tests', () {
    testWidgets('1. Cancel button is ENABLED for PENDING_TUTOR request', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final pass = samplePass(status: 'PENDING_TUTOR');
      await tester.pumpWidget(createWidgetUnderTest(pass));
      await tester.pump(const Duration(milliseconds: 50));

      final cancelBtnFinder = find.widgetWithText(OutlinedButton, 'Cancel Outpass');
      expect(cancelBtnFinder, findsOneWidget);

      final button = tester.widget<OutlinedButton>(cancelBtnFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('2. Cancel button is ENABLED for PENDING_HOD request', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final pass = samplePass(status: 'PENDING_HOD');
      await tester.pumpWidget(createWidgetUnderTest(pass));
      await tester.pump(const Duration(milliseconds: 50));

      final cancelBtnFinder = find.widgetWithText(OutlinedButton, 'Cancel Outpass');
      expect(cancelBtnFinder, findsOneWidget);

      final button = tester.widget<OutlinedButton>(cancelBtnFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('3. Cancel button is ENABLED for APPROVED request before exit', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final pass = samplePass(status: 'APPROVED', exitAt: null);
      await tester.pumpWidget(createWidgetUnderTest(pass));
      await tester.pump(const Duration(milliseconds: 50));

      final cancelBtnFinder = find.widgetWithText(OutlinedButton, 'Cancel Outpass');
      expect(cancelBtnFinder, findsOneWidget);

      final button = tester.widget<OutlinedButton>(cancelBtnFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('4. Cancel button is ENABLED for OVERDUE request without exit', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final pass = samplePass(status: 'OVERDUE', exitAt: null);
      await tester.pumpWidget(createWidgetUnderTest(pass));
      await tester.pump(const Duration(milliseconds: 50));

      final cancelBtnFinder = find.widgetWithText(OutlinedButton, 'Cancel Outpass');
      expect(cancelBtnFinder, findsOneWidget);

      final button = tester.widget<OutlinedButton>(cancelBtnFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('4b. Cancel button is ENABLED for OVERDUE request even after exit was recorded', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final pass = samplePass(status: 'OVERDUE', exitAt: '2026-10-17T05:28:07.173Z');
      await tester.pumpWidget(createWidgetUnderTest(pass));
      await tester.pump(const Duration(milliseconds: 50));

      final cancelBtnFinder = find.widgetWithText(OutlinedButton, 'Cancel Outpass');
      expect(cancelBtnFinder, findsOneWidget);

      final button = tester.widget<OutlinedButton>(cancelBtnFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('5. Cancel button is DISABLED when status is EXITED (active outside, not overdue yet)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final pass = samplePass(status: 'EXITED', exitAt: '2026-11-03T10:30:00.000Z');
      await tester.pumpWidget(createWidgetUnderTest(pass));
      await tester.pump(const Duration(milliseconds: 50));

      final cancelBtnFinder = find.widgetWithText(OutlinedButton, 'Cannot Cancel (Exit Recorded)');
      expect(cancelBtnFinder, findsOneWidget);

      final button = tester.widget<OutlinedButton>(cancelBtnFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('6. Cancel button is DISABLED when status is RETURNED', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final pass = samplePass(
        status: 'RETURNED',
        exitAt: '2026-11-03T10:30:00.000Z',
        entryAt: '2026-11-03T11:45:00.000Z',
      );
      await tester.pumpWidget(createWidgetUnderTest(pass));
      await tester.pump(const Duration(milliseconds: 50));

      final cancelBtnFinder = find.widgetWithText(OutlinedButton, 'Cannot Cancel (Already Returned)');
      expect(cancelBtnFinder, findsOneWidget);

      final button = tester.widget<OutlinedButton>(cancelBtnFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('7. Displays Outpass Cancelled and shows cancellation reason clearly', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final pass = samplePass(
        status: 'CANCELLED',
        cancelReason: 'Laboratory session rescheduled to tomorrow',
        cancelledAt: '2026-11-03 10:45 AM',
      );
      await tester.pumpWidget(createWidgetUnderTest(pass));
      await tester.pump(const Duration(milliseconds: 50));

      // Cancel button disabled and displays 'Outpass Cancelled'
      final cancelBtnFinder = find.widgetWithText(OutlinedButton, 'Outpass Cancelled');
      expect(cancelBtnFinder, findsOneWidget);
      final button = tester.widget<OutlinedButton>(cancelBtnFinder);
      expect(button.onPressed, isNull);

      // Status banner clearly displays cancellation reason
      expect(find.text('Reason: Laboratory session rescheduled to tomorrow'), findsOneWidget);
      expect(find.text('QR Code Inactive: Outpass Cancelled'), findsOneWidget);
    });

    testWidgets('8. Tapping Cancel Outpass invokes cancellation dialog or onCancel callback', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool cancelTapped = false;
      final pass = samplePass(status: 'OVERDUE', exitAt: '2026-10-17T05:28:07.173Z');

      await tester.pumpWidget(createWidgetUnderTest(
        pass,
        onCancel: () => cancelTapped = true,
      ));
      await tester.pump(const Duration(milliseconds: 50));

      final cancelBtn = find.widgetWithText(OutlinedButton, 'Cancel Outpass');
      expect(cancelBtn, findsOneWidget);

      await tester.tap(cancelBtn);
      await tester.pump(const Duration(milliseconds: 50));

      expect(cancelTapped, isTrue);
    });
  });
}
