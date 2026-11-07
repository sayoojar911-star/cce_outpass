import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cce_outpass/app_state.dart';
import 'package:cce_outpass/api_client.dart';
import 'package:cce_outpass/qr_token.dart';
import 'package:cce_outpass/widgets/ticket_outpass.dart';
import 'package:cce_outpass/widgets/printed_receipt_reveal.dart';
import 'package:cce_outpass/util/ticket_html_generator.dart';
import 'package:cce_outpass/util/printer_sound_helper.dart';

void main() {
  late AppState testState;

  setUp(() {
    PrintedReceiptReveal.resetSessionMemory();
    testState = AppState(api: ApiClient(baseUrl: 'http://localhost:3000/v1'));
    testState.userName = 'Sayanth Kumar';
    testState.userRole = 'STUDENT';
    testState.userDepartment = 'Computer Science & Engineering';
    testState.userYear = 3;
    testState.userDivision = 'B';
    testState.deviceKeys = DeviceKeys.generate();
  });

  Widget createWidgetUnderTest(
    Map<String, dynamic> outpass, {
    bool animatePrint = false,
  }) {
    return MaterialApp(
      home: AppStateScope(
        state: testState,
        child: Scaffold(
          body: SingleChildScrollView(
            child: TicketOutpass(
              outpass: outpass,
              enableTilt: true,
              animatePrint: animatePrint,
            ),
          ),
        ),
      ),
    );
  }

  final normalOutpass = {
    'id': 'op-12345',
    'displayId': 'CCE-OP-202610100001',
    'type': 'NORMAL',
    'typeId': 'normal',
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
      },
      {
        'stage': 'PENDING_HOD',
        'decision': 'APPROVED',
        'decidedAt': '2026-10-10T09:45:00.000Z',
      },
    ],
  };

  final emergencyOutpass = {
    'id': 'op-em-999',
    'displayId': 'CCE-EM-202610100099',
    'type': 'EMERGENCY',
    'typeId': 'emergency',
    'status': 'APPROVED',
    'destination': 'Home Urgent',
    'purposeCategory': 'Personal',
    'requestedExitAt': '2026-10-10T11:00:00.000Z',
    'expectedReturnAt': '2026-10-10T18:00:00.000Z',
    'student': {
      'name': 'Sayanth Kumar',
      'registerNo': 'CCE23CS042',
      'department': 'Computer Science & Engineering',
    },
  };

  testWidgets('Normal pass renders full digital receipt with 4-step approval tracker', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createWidgetUnderTest(normalOutpass, animatePrint: false));
    await tester.pump(const Duration(milliseconds: 50));

    // 1. Monospace header format: "CCE OUTPASS - <TYPE> - #<PASS ID>"
    expect(find.text('CCE OUTPASS - NORMAL - #CCE-OP-202610100001'), findsOneWidget);

    // 2. Student details
    expect(find.text('Sayanth Kumar'), findsOneWidget);
    expect(find.text('CCE23CS042'), findsOneWidget);
    expect(find.textContaining('Computer Science & Engineering'), findsOneWidget);

    // 3. Destination and purpose
    expect(find.text('Irinjalakuda Town'), findsOneWidget);
    expect(find.text('Medical'), findsOneWidget);
    expect(find.text('Dental Clinic Consultation'), findsOneWidget);

    // 4. Timings in IST
    expect(find.text('EXIT TIME (IST)'), findsOneWidget);
    expect(find.text('RETURN TIME (IST)'), findsOneWidget);

    // 5. Type badge & status pill
    expect(find.text('NORMAL'), findsWidgets);
    expect(find.text('APPROVED'), findsWidgets);

    // 6. Approval progress card with 4-step tracker for Normal pass
    expect(find.text('Status: APPROVED'), findsOneWidget);
    expect(find.text('Tutor'), findsOneWidget);
    expect(find.text('HOD'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);
    expect(find.text('Return'), findsOneWidget);

    // 7. QR code and stable pass code
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('PASS CODE: '), findsOneWidget);
    expect(find.text('CCE-OP-202610100001'), findsWidgets);

    // 8. Action buttons
    expect(find.text('Download Pass'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('Emergency pass renders shortened 3-step approval tracker (HOD, Exit, Return)', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createWidgetUnderTest(emergencyOutpass, animatePrint: false));
    await tester.pump(const Duration(milliseconds: 50));

    // Header & badge
    expect(find.text('CCE OUTPASS - EMERGENCY - #CCE-EM-202610100099'), findsOneWidget);
    expect(find.text('EMERGENCY'), findsWidgets);

    // Emergency approval tracker must NOT have Tutor step
    expect(find.text('Tutor'), findsNothing);
    expect(find.text('HOD'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);
    expect(find.text('Return'), findsOneWidget);
  });

  testWidgets('Receipt printer reveal animation feeds paper and completes to full receipt', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createWidgetUnderTest(normalOutpass, animatePrint: true));
    await tester.pump(); // execute postFrameCallback

    // Initially in printer mode
    expect(find.byType(PrintedReceiptReveal), findsOneWidget);
    expect(find.text('Printing pass · Tap anywhere to skip'), findsOneWidget);

    // Advance animation to end (4800ms)
    await tester.pump(const Duration(milliseconds: 5500));
    await tester.pump();

    // Final state: receipt is fully expanded, printer is gone
    expect(find.text('CCE OUTPASS - NORMAL - #CCE-OP-202610100001'), findsOneWidget);
    expect(find.text('Printing pass · Tap anywhere to skip'), findsNothing);
  });

  testWidgets('Tapping during animation skips straight to final state', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createWidgetUnderTest(normalOutpass, animatePrint: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Printing pass · Tap anywhere to skip'), findsOneWidget);

    // Tap to skip
    await tester.tap(find.byType(PrintedReceiptReveal));
    await tester.pump();

    // Must be in final state immediately
    expect(find.text('Printing pass · Tap anywhere to skip'), findsNothing);
    expect(find.text('CCE OUTPASS - NORMAL - #CCE-OP-202610100001'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('Session memory prevents replaying animation for previously printed pass', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Mark pass as printed in session
    PrintedReceiptReveal.markPrintedInSession('op-12345');

    await tester.pumpWidget(createWidgetUnderTest(normalOutpass, animatePrint: true));
    await tester.pump();

    // Should immediately show full receipt without printer animation
    expect(find.text('Printing pass · Tap anywhere to skip'), findsNothing);
    expect(find.text('CCE OUTPASS - NORMAL - #CCE-OP-202610100001'), findsOneWidget);
  });

  testWidgets('Respects MediaQuery.disableAnimations by running 1.2s shortened version', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: createWidgetUnderTest(normalOutpass, animatePrint: true),
      ),
    );
    await tester.pump(); // execute postFrameCallback
    await tester.pump(const Duration(milliseconds: 100));

    // Shows 1.2s version initially
    expect(find.byType(PrintedReceiptReveal), findsOneWidget);

    // Advances past 1.2s to final state
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump();

    expect(find.text('CCE OUTPASS - NORMAL - #CCE-OP-202610100001'), findsOneWidget);
  });

  testWidgets('Cancel Outpass button appears for cancellable status and opens dialog', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createWidgetUnderTest(normalOutpass, animatePrint: false));
    await tester.pump();

    // Cancel button should be visible
    expect(find.text('Cancel Outpass'), findsOneWidget);

    // Scroll to Cancel Outpass and tap
    await tester.ensureVisible(find.text('Cancel Outpass'));
    await tester.pump();
    await tester.tap(find.text('Cancel Outpass'));
    await tester.pump();

    // Confirmation dialog appears
    expect(find.text('Cancel Outpass Request'), findsOneWidget);
    expect(find.text('Reason for cancellation (optional)'), findsOneWidget);
    expect(find.text('Confirm Cancel'), findsOneWidget);
  });

  testWidgets('Cancel Outpass button is enabled for OVERDUE outpass', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final overdueOutpass = {
      ...normalOutpass,
      'status': 'OVERDUE',
      'exitAt': null,
    };

    await tester.pumpWidget(createWidgetUnderTest(overdueOutpass, animatePrint: false));
    await tester.pump();

    // Cancel button should be visible and enabled for overdue pass
    expect(find.text('Cancel Outpass'), findsOneWidget);
    await tester.ensureVisible(find.text('Cancel Outpass'));
    await tester.pump();

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Cancel Outpass'),
    );
    expect(button.enabled, isTrue);

    await tester.tap(find.text('Cancel Outpass'));
    await tester.pump();

    expect(find.text('Cancel Outpass Request'), findsOneWidget);
  });

  testWidgets('Responsive layouts at 360px (mobile) and 1920px (desktop) without overflow', (tester) async {
    // Narrow Mobile: 360px width
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(createWidgetUnderTest(normalOutpass, animatePrint: false));
    await tester.pump(const Duration(milliseconds: 50));
    final ex = tester.takeException();
    expect(ex, isNull);
    expect(find.text('CCE OUTPASS - NORMAL - #CCE-OP-202610100001'), findsOneWidget);

    // Ultra Wide Desktop: 1920px width
    tester.view.physicalSize = const Size(1920, 1080);
    await tester.pumpWidget(createWidgetUnderTest(normalOutpass, animatePrint: false));
    await tester.pump(const Duration(milliseconds: 50));
    final exWide = tester.takeException();
    expect(exWide, isNull);
    expect(find.text('CCE OUTPASS - NORMAL - #CCE-OP-202610100001'), findsOneWidget);

    tester.view.resetPhysicalSize();
  });

  test('TicketHtmlGenerator generates complete printable HTML with SVG QR code', () {
    final html = TicketHtmlGenerator.generate(normalOutpass, qrToken: 'v1.op-12345.100.sig');
    expect(html, contains('Christ College of Engineering'));
    expect(html, contains('CCE-OP-202610100001'));
    expect(html, contains('Sayanth Kumar'));
    expect(html, contains('CCE23CS042'));
    expect(html, contains('<svg'));
    expect(html, contains('@page {'));
  });

  test('PrinterSoundHelper sound toggle and session memory tests', () {
    // Sound helper default
    expect(PrinterSoundHelper.soundEnabled, isTrue);
    PrinterSoundHelper.setSoundEnabled(false);
    expect(PrinterSoundHelper.soundEnabled, isFalse);
    PrinterSoundHelper.setSoundEnabled(true);
    expect(PrinterSoundHelper.soundEnabled, isTrue);

    // Session print memory
    PrintedReceiptReveal.resetSessionMemory();
    expect(PrintedReceiptReveal.hasPrintedInSession('test-pass-001'), isFalse);
    PrintedReceiptReveal.markPrintedInSession('test-pass-001');
    expect(PrintedReceiptReveal.hasPrintedInSession('test-pass-001'), isTrue);
    expect(PrintedReceiptReveal.hasPrintedInSession('test-pass-002'), isFalse);
  });

  testWidgets('Thermal printer animation runs once and skips cleanly on tap', (tester) async {
    PrintedReceiptReveal.resetSessionMemory();
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createWidgetUnderTest(normalOutpass, animatePrint: true));
    await tester.pump(const Duration(milliseconds: 100));

    // Shows printer header branding
    expect(find.text('CCE THERMAL POS-80'), findsOneWidget);
    expect(find.text('FEED'), findsOneWidget);

    // Tap to skip
    await tester.tap(find.text('FEED'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    // Now marked in session
    expect(PrintedReceiptReveal.hasPrintedInSession('op-12345'), isTrue);

    // Rebuild does not restart printer
    await tester.pumpWidget(createWidgetUnderTest(normalOutpass, animatePrint: true));
    await tester.pump(const Duration(milliseconds: 100));

    // Receipt details still visible
    expect(find.text('CCE OUTPASS - NORMAL - #CCE-OP-202610100001'), findsOneWidget);
  });
}
