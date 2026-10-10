import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
    testState.userYear = 3;
    testState.userDivision = 'B';
    testState.deviceKeys = DeviceKeys.generate();
  });

  Widget createWidgetUnderTest(Map<String, dynamic> outpass) {
    return MaterialApp(
      home: AppStateScope(
        state: testState,
        child: Scaffold(
          body: SingleChildScrollView(
            child: TicketOutpass(
              outpass: outpass,
              enableTilt: true,
              showStub: true,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('TicketOutpass displays institutional branding and student details', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final outpass = {
      'id': 'op-12345',
      'displayId': 'CCE-OP-202610100001',
      'type': 'NORMAL',
      'status': 'APPROVED',
      'destination': 'Irinjalakuda Town',
      'purposeCategory': 'Medical',
      'purposeText': 'Dental Clinic Consultation',
      'requestedExitAt': '2026-10-10T10:00:00.000Z',
      'expectedReturnAt': '2026-10-10T13:00:00.000Z',
      'student': {
        'name': 'Sayanth Kumar',
        'registerNo': 'CCE23CS042',
        'department': 'Computer Science & Engineering',
        'year': 3,
        'division': 'B',
        'tutorName': 'Prof. CE Tutor',
      },
      'approvals': [
        {
          'stage': 'PENDING_TUTOR',
          'decision': 'APPROVED',
          'decidedAt': '2026-10-10T09:30:00.000Z',
          'comment': 'Approved for medical visit',
        },
        {
          'stage': 'PENDING_HOD',
          'decision': 'APPROVED',
          'decidedAt': '2026-10-10T09:45:00.000Z',
        },
      ],
    };

    await tester.pumpWidget(createWidgetUnderTest(outpass));
    await tester.pump();

    // Verify Institutional Branding
    expect(find.text('CHRIST COLLEGE OF ENGINEERING'), findsOneWidget);
    expect(find.text('IRINJALAKUDA, THRISSUR · AUTONOMOUS'), findsOneWidget);
    expect(find.text('CCE-OP-202610100001'), findsOneWidget);
    expect(find.text('APPROVED'), findsWidgets);

    // Verify Student Details
    expect(find.text('Sayanth Kumar'), findsOneWidget);
    expect(find.text('CCE23CS042'), findsOneWidget);
    expect(find.text('Tutor: Prof. CE Tutor'), findsOneWidget);
    expect(find.text('Irinjalakuda Town'), findsOneWidget);
    expect(find.text('Medical'), findsOneWidget);
    expect(find.text('Dental Clinic Consultation'), findsOneWidget);

    // Verify Perforated Stub & QR code
    expect(find.text('DETACHABLE GATE SCAN STUB'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('PRESENT TO GATE SECURITY FOR SCANNING'), findsOneWidget);
    expect(find.text('Copy Token for Guard Manual Entry'), findsOneWidget);

    // Verify Action buttons
    expect(find.text('Print Pass'), findsOneWidget);
    expect(find.text('Share Summary'), findsOneWidget);
    expect(find.text('Static Flat'), findsOneWidget);
  });

  testWidgets('TicketOutpass locks QR code when pass is pending tutor approval', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final pendingOutpass = {
      'id': 'op-99999',
      'displayId': 'CCE-OP-PENDING-01',
      'type': 'NORMAL',
      'status': 'PENDING_TUTOR',
      'destination': 'Main Library',
      'purposeCategory': 'Academic',
      'requestedExitAt': '2026-10-10T14:00:00.000Z',
      'expectedReturnAt': '2026-10-10T17:00:00.000Z',
      'student': {
        'name': 'Sayanth Kumar',
        'registerNo': 'CCE23CS042',
        'department': 'Computer Science & Engineering',
      },
      'approvals': [],
    };

    await tester.pumpWidget(createWidgetUnderTest(pendingOutpass));
    await tester.pump();

    // When pending, QR is locked
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('QR Code Locked: Awaiting Tutor Approval'), findsOneWidget);
    expect(find.text('PENDING TUTOR'), findsWidgets);
  });

  testWidgets('Tapping Static Flat toggles 3D tilt interaction mode', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final outpass = {
      'id': 'op-12345',
      'displayId': 'CCE-OP-202610100001',
      'type': 'NORMAL',
      'status': 'APPROVED',
      'destination': 'Irinjalakuda Town',
      'purposeCategory': 'Medical',
      'requestedExitAt': '2026-10-10T10:00:00.000Z',
      'expectedReturnAt': '2026-10-10T13:00:00.000Z',
      'student': {
        'name': 'Sayanth Kumar',
        'registerNo': 'CCE23CS042',
      },
    };

    await tester.pumpWidget(createWidgetUnderTest(outpass));
    await tester.pump();

    expect(find.text('Static Flat'), findsOneWidget);
    await tester.tap(find.text('Static Flat'));
    await tester.pump();

    expect(find.text('Enable Tilt'), findsOneWidget);
  });
}
