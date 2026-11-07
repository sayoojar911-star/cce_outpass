import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cce_outpass/app_state.dart';
import 'package:cce_outpass/api_client.dart';
import 'package:cce_outpass/approver_screen.dart';
import 'package:cce_outpass/widgets/ticket_outpass.dart';
import 'package:cce_outpass/qr_token.dart';

class MockApproverApiClient extends ApiClient {
  MockApproverApiClient({
    required this.pendingList,
    this.onApproveDirect,
    this.onForwardHod,
    this.onReject,
  }) : super(baseUrl: 'http://localhost:3000/v1');

  final List<dynamic> pendingList;
  final Future<Map<String, dynamic>> Function(String outpassId)? onApproveDirect;
  final Future<Map<String, dynamic>> Function(String outpassId)? onForwardHod;
  final Future<Map<String, dynamic>> Function(String outpassId, String reason)? onReject;

  @override
  Future<List<dynamic>> pending() async {
    return pendingList;
  }

  @override
  Future<Map<String, dynamic>> approveDirect(String outpassId, {String? comment}) async {
    if (onApproveDirect != null) return onApproveDirect!(outpassId);
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> forwardToHod(String outpassId, {String? comment}) async {
    if (onForwardHod != null) return onForwardHod!(outpassId);
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> rejectOutpass(String outpassId, String reason) async {
    if (onReject != null) return onReject!(outpassId, reason);
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> decide(String outpassId, String decision,
      {String? comment, String? path}) async {
    return {'ok': true};
  }
}

void main() {
  final samplePendingOutpass = {
    'id': 'op-991',
    'displayId': 'OP20261103001',
    'passCode': 'T991',
    'status': 'PENDING_TUTOR',
    'type': 'NORMAL',
    'typeId': 'normal',
    'destination': 'Thrissur Library',
    'purposeCategory': 'Academic',
    'purposeText': 'Reference book collection',
    'requestedExitAt': '2026-11-03T10:00:00.000Z',
    'expectedReturnAt': '2026-11-03T14:00:00.000Z',
    'student': {
      'name': 'Rahul Sharma',
      'registerNo': 'CCECSE2026',
      'department': 'CSE',
      'semester': 4,
    },
  };

  testWidgets('Tutor screen shows Approve Directly, Approve & Forward to HOD, and Reject buttons',
      (WidgetTester tester) async {
    final mockApi = MockApproverApiClient(pendingList: [samplePendingOutpass]);
    final state = AppState(api: mockApi);
    state.userId = 'tutor-1';
    state.userName = 'Prof. Tutor';
    state.userRole = 'TUTOR';
    state.userRoleId = 'tutor';

    await tester.pumpWidget(
      MaterialApp(
        home: AppStateScope(
          state: state,
          child: const ApproverHome(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Tutor sees all 3 actions
    expect(find.text('Approve Directly'), findsOneWidget);
    expect(find.text('Approve & Forward to HOD'), findsOneWidget);
    expect(find.text('Reject Request'), findsOneWidget);

    // Tap Approve Directly -> Confirmation dialog
    await tester.tap(find.text('Approve Directly'));
    await tester.pumpAndSettle();

    expect(
      find.text('This action gives final approval and bypasses HOD approval. Continue?'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Tap Approve & Forward to HOD -> Confirmation dialog
    await tester.tap(find.text('Approve & Forward to HOD'));
    await tester.pumpAndSettle();

    expect(
      find.text('This request will be forwarded to the HOD for final approval. Continue?'),
      findsOneWidget,
    );
    expect(find.text('Forward to HOD'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Tap Reject Request -> Mandatory rejection reason prompt
    await tester.tap(find.text('Reject Request'));
    await tester.pumpAndSettle();

    expect(find.text('Rejection Reason'), findsOneWidget);
    expect(find.text('Reason for rejection *'), findsOneWidget);
    expect(find.text('Confirm Rejection'), findsOneWidget);
  });

  testWidgets('HOD screen shows single Approve Request and Reject Request buttons only',
      (WidgetTester tester) async {
    final mockApi = MockApproverApiClient(pendingList: [
      {
        ...samplePendingOutpass,
        'status': 'PENDING_HOD',
        'approvalPath': 'FORWARD_HOD',
      }
    ]);
    final state = AppState(api: mockApi);
    state.userId = 'hod-1';
    state.userName = 'Dr. HOD CSE';
    state.userRole = 'HOD';
    state.userRoleId = 'hod';

    await tester.pumpWidget(
      MaterialApp(
        home: AppStateScope(
          state: state,
          child: const ApproverHome(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify HOD sees Approve Request and Reject Request
    expect(find.text('Approve Request'), findsOneWidget);
    expect(find.text('Reject Request'), findsOneWidget);

    // Verify Tutor-only actions are NOT present
    expect(find.text('Approve Directly'), findsNothing);
    expect(find.text('Approve & Forward to HOD'), findsNothing);
  });

  testWidgets('TicketOutpass displays Approved by Tutor — Final Approval for direct approval',
      (WidgetTester tester) async {
    final state = AppState(api: ApiClient(baseUrl: 'http://localhost:3000/v1'));
    state.deviceKeys = DeviceKeys.generate();

    final directApprovedOutpass = {
      ...samplePendingOutpass,
      'status': 'APPROVED',
      'approvalPath': 'DIRECT',
      'validFrom': '2026-11-03T10:00:00.000Z',
      'validUntil': '2026-11-03T14:00:00.000Z',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: AppStateScope(
          state: state,
          child: Scaffold(
            body: SingleChildScrollView(
              child: TicketOutpass(
                outpass: directApprovedOutpass,
                enableTilt: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Approved by Tutor — Final Approval'), findsOneWidget);
    // Dynamic token refresh visible because QR is active
    expect(find.textContaining('Dynamic token refresh'), findsOneWidget);
  });

  testWidgets('TicketOutpass displays Tutor Approved — Awaiting HOD Approval and locked QR when forwarded',
      (WidgetTester tester) async {
    final state = AppState(api: ApiClient(baseUrl: 'http://localhost:3000/v1'));
    state.deviceKeys = DeviceKeys.generate();

    final forwardedOutpass = {
      ...samplePendingOutpass,
      'status': 'PENDING_HOD',
      'approvalPath': 'FORWARD_HOD',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: AppStateScope(
          state: state,
          child: Scaffold(
            body: SingleChildScrollView(
              child: TicketOutpass(
                outpass: forwardedOutpass,
                enableTilt: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Tutor Approved — Awaiting HOD Approval'), findsWidgets);
    expect(
      find.text('QR Code Locked: Tutor Approved — Awaiting HOD Approval'),
      findsOneWidget,
    );
    // Dynamic QR token refresh is NOT shown because pass is locked
    expect(find.textContaining('Dynamic token refresh'), findsNothing);
  });
}
