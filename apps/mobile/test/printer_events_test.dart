import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cce_outpass/app_state.dart';
import 'package:cce_outpass/api_client.dart';
import 'package:cce_outpass/qr_token.dart';
import 'package:cce_outpass/widgets/ticket_outpass.dart';
import 'package:cce_outpass/widgets/printed_receipt_reveal.dart';
import 'package:cce_outpass/widgets/request_receipt_card.dart';
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

  final pendingSubmissionOutpass = {
    'id': 'op-req-778899',
    'displayId': 'CCE-REQ-202610120001',
    'outpassNumber': 'CCE-REQ-202610120001',
    'type': 'NORMAL',
    'status': 'PENDING_TUTOR',
    'destination': 'Thrissur Round',
    'purposeCategory': 'Academic',
    'purposeText': 'Library book reference',
    'requestedExitAt': '2026-10-12T10:00:00.000Z',
    'expectedReturnAt': '2026-10-12T14:00:00.000Z',
    'createdAt': '2026-10-12T09:15:00.000Z',
    'student': {
      'name': 'Sayanth Kumar',
      'registerNo': 'CCE23CS042',
      'department': 'Computer Science & Engineering',
    },
  };

  final approvedOutpass = {
    'id': 'op-app-998877',
    'displayId': 'CCE-OP-202610129999',
    'outpassNumber': 'CCE-OP-202610129999',
    'type': 'NORMAL',
    'status': 'APPROVED',
    'destination': 'Irinjalakuda Town',
    'purposeCategory': 'Medical',
    'purposeText': 'Dental Clinic Consultation',
    'requestedExitAt': '2026-10-12T10:00:00.000Z',
    'expectedReturnAt': '2026-10-12T13:00:00.000Z',
    'createdAt': '2026-10-12T08:00:00.000Z',
    'student': {
      'name': 'Sayanth Kumar',
      'registerNo': 'CCE23CS042',
      'department': 'Computer Science & Engineering',
    },
  };

  group('EVENT 1: OUTPASS REQUEST SUBMISSION', () {
    testWidgets('Successful request submission triggers one receipt animation with POS-80 printer', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool viewRequestCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            state: testState,
            child: RequestReceiptScreen(
              outpass: pendingSubmissionOutpass,
              onViewRequest: () {
                viewRequestCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Confirms printer shell is active
      expect(find.byType(PrintedReceiptReveal), findsOneWidget);
      expect(find.text('CCE THERMAL POS-80'), findsOneWidget);
      expect(find.text('FEED'), findsOneWidget);
      expect(find.text('Printing pass · Tap anywhere to skip'), findsOneWidget);

      // Fast-forward animation to completion (3500ms)
      await tester.pump(const Duration(milliseconds: 4000));
      await tester.pump();

      // Check request receipt details printed
      expect(find.textContaining('REQUEST RECEIPT'), findsWidgets);
      expect(find.text('REF #CCE-REQ-202610120001'), findsWidgets);
      expect(find.text('Sayanth Kumar'), findsOneWidget);
      expect(find.textContaining('PENDING TUTOR APPROVAL'), findsWidgets);
      expect(find.textContaining('EXIT PROHIBITED'), findsWidgets);

      // Action button "View Submitted Request" is present and functional
      expect(find.text('View Submitted Request'), findsOneWidget);
      await tester.tap(find.text('View Submitted Request'));
      await tester.pump();
      expect(viewRequestCalled, isTrue);
    });

    testWidgets('Receipt animation contains NO usable QR code credential and displays locked warning', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            state: testState,
            child: RequestReceiptCard(
              outpass: pendingSubmissionOutpass,
            ),
          ),
        ),
      );
      await tester.pump();

      // Must NOT contain any QrImageView
      expect(find.byType(QrImageView), findsNothing);

      // Must explicitly indicate locked QR state
      expect(find.text('GATE PASS QR LOCKED'), findsOneWidget);
      expect(
        find.text('Valid gate pass QR credentials are only generated after both Tutor and HOD grant approval.'),
        findsOneWidget,
      );
    });

    testWidgets('Session memory tracks receipt event preventing replay on page rebuilds', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final receiptEventKey = PrintedReceiptReveal.receiptEventKey('op-req-778899');
      expect(PrintedReceiptReveal.hasPrintedEvent(receiptEventKey), isFalse);

      // Mount RequestReceiptScreen and skip/finish
      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            state: testState,
            child: RequestReceiptScreen(
              outpass: pendingSubmissionOutpass,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4000));
      await tester.pump();

      // Must now be marked as printed
      expect(PrintedReceiptReveal.hasPrintedEvent(receiptEventKey), isTrue);

      // Rebuilding the widget does NOT restart animation
      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            state: testState,
            child: RequestReceiptScreen(
              outpass: pendingSubmissionOutpass,
            ),
          ),
        ),
      );
      await tester.pump();

      // Does not show the printing skip hint because it is immediately complete
      expect(find.text('Printing pass · Tap anywhere to skip'), findsNothing);
      expect(find.textContaining('REQUEST RECEIPT'), findsWidgets);
    });
  });

  group('EVENT 2: APPROVED OUTPASS ISSUANCE', () {
    testWidgets('Approved pass triggers thermal printer issuance animation with live QR code', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final issuanceKey = PrintedReceiptReveal.issuanceEventKey('op-app-998877');
      expect(PrintedReceiptReveal.hasPrintedEvent(issuanceKey), isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            state: testState,
            child: Scaffold(
              body: SingleChildScrollView(
                child: TicketOutpass(
                  outpass: approvedOutpass,
                  animatePrint: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially in printer mode
      expect(find.byType(PrintedReceiptReveal), findsOneWidget);
      expect(find.text('Printing pass · Tap anywhere to skip'), findsOneWidget);

      // Fast-forward animation to finish
      await tester.pump(const Duration(milliseconds: 4000));
      await tester.pump();

      // Verified: Real QrImageView rendered with backend credential
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('CCE OUTPASS - NORMAL - #CCE-OP-202610129999'), findsOneWidget);
      expect(find.text('★ APPROVED ★'), findsOneWidget);

      // Issuance event marked in session
      expect(PrintedReceiptReveal.hasPrintedEvent(issuanceKey), isTrue);
    });

    testWidgets('QR rotating countdown timer refresh does NOT restart approved pass printing', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            state: testState,
            child: Scaffold(
              body: SingleChildScrollView(
                child: TicketOutpass(
                  outpass: approvedOutpass,
                  animatePrint: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4000));
      await tester.pump();

      expect(find.text('Printing pass · Tap anywhere to skip'), findsNothing);

      // Advance by 35 seconds to simulate QR step timer completion and token refresh
      await tester.pump(const Duration(seconds: 35));
      await tester.pump();

      // Animation must NOT have restarted
      expect(find.text('Printing pass · Tap anywhere to skip'), findsNothing);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('Pending request does NOT trigger issuance printing in TicketOutpass', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            state: testState,
            child: Scaffold(
              body: SingleChildScrollView(
                child: TicketOutpass(
                  outpass: pendingSubmissionOutpass,
                  animatePrint: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // No printer animation for pending status
      expect(find.text('Printing pass · Tap anywhere to skip'), findsNothing);

      // QR is locked
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('QR Code Locked: Awaiting Tutor Approval'), findsOneWidget);
    });
  });

  group('DUPLICATE-PREVENTION & EVENT SEPARATION', () {
    test('Receipt event key and issuance event key are distinct and independent', () {
      const id = 'op-dual-123';
      final receiptKey = PrintedReceiptReveal.receiptEventKey(id);
      final issuanceKey = PrintedReceiptReveal.issuanceEventKey(id);

      expect(receiptKey, isNot(equals(issuanceKey)));
      expect(receiptKey, equals('RECEIPT_op-dual-123'));
      expect(issuanceKey, equals('ISSUANCE_op-dual-123'));

      PrintedReceiptReveal.resetSessionMemory();

      // Marking receipt event does not mark issuance event
      PrintedReceiptReveal.markEventPrinted(receiptKey);
      expect(PrintedReceiptReveal.hasPrintedEvent(receiptKey), isTrue);
      expect(PrintedReceiptReveal.hasPrintedEvent(issuanceKey), isFalse);

      // Marking issuance event does not clear receipt event
      PrintedReceiptReveal.markEventPrinted(issuanceKey);
      expect(PrintedReceiptReveal.hasPrintedEvent(receiptKey), isTrue);
      expect(PrintedReceiptReveal.hasPrintedEvent(issuanceKey), isTrue);
    });

    test('Sound toggle remains functional across print events', () {
      expect(PrinterSoundHelper.soundEnabled, isTrue);
      PrinterSoundHelper.setSoundEnabled(false);
      expect(PrinterSoundHelper.soundEnabled, isFalse);
      PrinterSoundHelper.setSoundEnabled(true);
      expect(PrinterSoundHelper.soundEnabled, isTrue);
    });
  });
}
