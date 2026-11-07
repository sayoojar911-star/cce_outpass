import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cce_outpass/app_state.dart';
import 'package:cce_outpass/api_client.dart';
import 'package:cce_outpass/student_screen.dart';

class MockOutpassApiClient extends ApiClient {
  MockOutpassApiClient() : super(baseUrl: 'http://localhost:3000/v1');

  Map<String, dynamic>? lastCreatedOutpass;

  @override
  Future<Map<String, dynamic>> createOutpass({
    required String requestedExitAt,
    required String expectedReturnAt,
    required String destination,
    required String purposeCategory,
    String? purposeText,
    String type = 'normal',
  }) async {
    lastCreatedOutpass = {
      'requestedExitAt': requestedExitAt,
      'expectedReturnAt': expectedReturnAt,
      'destination': destination,
      'purposeCategory': purposeCategory,
      'purposeText': purposeText,
      'type': type,
    };
    return {
      'id': 'op-mock-123',
      'displayId': 'CCE-OP-TEST',
      'status': 'PENDING_TUTOR',
      ...lastCreatedOutpass!,
    };
  }
}

void main() {
  testWidgets('RequestFormScreen submits successfully with normal type', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockApi = MockOutpassApiClient();
    final testState = AppState(api: mockApi);
    testState.userName = 'Test Student';
    testState.userRole = 'STUDENT';
    testState.userDepartment = 'CSE';
    testState.userYear = 3;
    testState.userTutorId = 'tutor-uuid-123';

    await tester.pumpWidget(
      AppStateScope(
        state: testState,
        child: const MaterialApp(
          home: RequestFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify fields are present
    expect(find.text('Request Outpass'), findsOneWidget);
    expect(find.text('Medical'), findsOneWidget);
    expect(find.text('Normal (Tutor -> HOD)'), findsOneWidget);
    expect(find.text('Submit for Approval'), findsOneWidget);

    // Enter destination "thrissur"
    final destFinder = find.byType(TextFormField).first;
    await tester.enterText(destFinder, 'thrissur');
    await tester.pumpAndSettle();

    // Tap "Submit for Approval"
    await tester.tap(find.text('Submit for Approval'));
    await tester.pumpAndSettle();

    // Verify mock API was called with expected arguments
    expect(mockApi.lastCreatedOutpass, isNotNull);
    expect(mockApi.lastCreatedOutpass!['destination'], 'thrissur');
    expect(mockApi.lastCreatedOutpass!['purposeCategory'], 'Medical');
    expect(mockApi.lastCreatedOutpass!['type'], 'normal');
    expect(mockApi.lastCreatedOutpass!['purposeText'], isNull); // Optional details empty
    expect(mockApi.lastCreatedOutpass!['requestedExitAt'], isNotEmpty);
    expect(mockApi.lastCreatedOutpass!['expectedReturnAt'], isNotEmpty);
  });

  testWidgets('RequestFormScreen blocks normal outpass when student has no tutor assigned', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockApi = MockOutpassApiClient();
    final testState = AppState(api: mockApi);
    testState.userName = 'Test Student';
    testState.userRole = 'STUDENT';
    testState.userDepartment = 'CSE';
    testState.userYear = 3;
    testState.userTutorId = null; // No tutor assigned!

    await tester.pumpWidget(
      AppStateScope(
        state: testState,
        child: const MaterialApp(
          home: RequestFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Warning banner should be visible
    expect(find.textContaining('No tutor assigned, contact admin'), findsOneWidget);

    // Enter destination
    final destFinder = find.byType(TextFormField).first;
    await tester.enterText(destFinder, 'thrissur');
    await tester.pumpAndSettle();

    // Tap "Submit for Approval"
    await tester.tap(find.text('Submit for Approval'));
    await tester.pumpAndSettle();

    // Verify API was NOT called
    expect(mockApi.lastCreatedOutpass, isNull);
    expect(find.text('No tutor assigned, contact admin'), findsWidgets);
  });

  testWidgets('RequestFormScreen validates emergency explanation requires >= 15 chars', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockApi = MockOutpassApiClient();
    final testState = AppState(api: mockApi);
    testState.userName = 'Test Student';
    testState.userRole = 'STUDENT';
    testState.userDepartment = 'CSE';
    testState.userYear = 3;

    await tester.pumpWidget(
      AppStateScope(
        state: testState,
        child: const MaterialApp(
          home: RequestFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter destination
    final destFinder = find.byType(TextFormField).first;
    await tester.enterText(destFinder, 'Hospital');
    await tester.pumpAndSettle();

    // Select emergency outpass type
    await tester.tap(find.text('Normal (Tutor -> HOD)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emergency (Direct to HOD)').last);
    await tester.pumpAndSettle();

    // Emergency warning note should appear
    expect(find.text('Emergency requests go directly to the HOD. Please explain the emergency clearly in the details below.'), findsOneWidget);
    expect(find.text('Explain the emergency (required)'), findsOneWidget);

    // Try submitting without explanation
    await tester.tap(find.text('Submit for Approval'));
    await tester.pumpAndSettle();
    expect(mockApi.lastCreatedOutpass, isNull);
    expect(find.text('Please explain the emergency (at least 15 characters)'), findsOneWidget);

    // Try submitting with short explanation (< 15 chars)
    final detailsFinder = find.byType(TextFormField).at(1);
    await tester.enterText(detailsFinder, 'Short note');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit for Approval'));
    await tester.pumpAndSettle();
    expect(mockApi.lastCreatedOutpass, isNull);
    expect(find.text('Please provide more details (at least 15 characters required)'), findsOneWidget);

    // Submit with valid explanation (>= 15 chars)
    await tester.enterText(detailsFinder, 'High fever and severe headache need urgent clinic visit');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit for Approval'));
    await tester.pumpAndSettle();

    expect(mockApi.lastCreatedOutpass, isNotNull);
    expect(mockApi.lastCreatedOutpass!['type'], 'emergency');
    expect(mockApi.lastCreatedOutpass!['purposeText'], 'High fever and severe headache need urgent clinic visit');
  });

  testWidgets('RequestFormScreen validates required destination before submitting', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockApi = MockOutpassApiClient();
    final testState = AppState(api: mockApi);
    testState.userRole = 'STUDENT';

    await tester.pumpWidget(
      AppStateScope(
        state: testState,
        child: const MaterialApp(
          home: RequestFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap submit with empty destination
    await tester.tap(find.text('Submit for Approval'));
    await tester.pumpAndSettle();

    // Should not call API and should show validation error
    expect(mockApi.lastCreatedOutpass, isNull);
    expect(find.text('Destination is required'), findsOneWidget);
  });
}
