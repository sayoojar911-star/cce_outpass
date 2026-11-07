import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cce_outpass/api_client.dart';
import 'package:cce_outpass/app_state.dart';
import 'package:cce_outpass/login_screen.dart';
import 'package:cce_outpass/splash_screen.dart';
import 'package:cce_outpass/student_screen.dart';
import 'package:cce_outpass/widgets/physical_id_card_login.dart';

class MockSplashApiClient extends ApiClient {
  @override
  Future<dynamic> get(String path) async => [];
  @override
  Future<dynamic> post(String path, {Object? body}) async => {};
  @override
  Future<Map<String, dynamic>> getAllConfig() async => {
        'roles': [],
        'departments': [],
        'purposeCategories': [],
        'outpassTypes': [],
        'settings': {},
      };
}

class FakeSecureStorage extends FlutterSecureStorage {
  FakeSecureStorage() : super();
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data.remove(key);

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      Map.from(_data);

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data.clear();

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data.containsKey(key);
}

void main() {
  setUp(() {
    SplashScreen.hasPlayedStartup = false;
  });

  group('Redesigned CCE Outpass Startup Screen & Login Transition', () {
    testWidgets('1. Opening — renders authentic college logo on #F4F1E8 warm ivory background',
        (WidgetTester tester) async {
      final state = AppState(api: MockSplashApiClient(), storage: FakeSecureStorage());

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(appState: state),
        ),
      );

      // Verify warm ivory background #F4F1E8
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFF4F1E8));

      // Verify official college identity texts
      expect(find.text('CCE OUTPASS'), findsOneWidget);
      expect(find.text('CHRIST COLLEGE OF ENGINEERING'), findsWidgets);
      expect(find.text('AUTONOMOUS • IRINJALAKUDA'), findsWidgets);

      // Verify logo presence
      expect(find.byType(CceCollegeLogo), findsOneWidget);
    });

    testWidgets('2. Single ID Card Entrance — suspended by a visible rope with hidden pivot',
        (WidgetTester tester) async {
      final state = AppState(api: MockSplashApiClient(), storage: FakeSecureStorage());

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(appState: state),
        ),
      );

      // Advance into the single ID card swing phase (t ~ 0.46 = 1750ms)
      await tester.pump(const Duration(milliseconds: 1750));

      // Verify exactly ONE physical ID card login widget is rendered
      expect(find.byType(PhysicalIdCardLogin), findsOneWidget);

      // Verify visible suspension rope is rendered
      final ropeFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is SuspendedRopePainter,
      );
      expect(ropeFinder, findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(ropeFinder);
      final ropePainter = customPaint.painter as SuspendedRopePainter;

      // Verify hidden pivot: pivot is above the viewport (y < 0)
      expect(ropePainter.pivot.dy, lessThan(0.0));
      expect(ropePainter.pivot.dy, equals(-240.0));

      // Verify rope is visible and connected to the card
      expect(ropePainter.ropeOpacity, greaterThan(0.0));
      expect(ropePainter.cardTopCenter.dy, greaterThan(0.0));

      // Verify card content: functional login interface inside ID card
      expect(find.text('WELCOME BACK'), findsWidgets);
      expect(find.text('SEND OTP'), findsWidgets);
      expect(find.text('INSTITUTIONAL LOGIN PORTAL'), findsWidgets);
      expect(find.text('CCE OUTPASS'), findsWidgets);
      expect(find.text('DIGITAL CAMPUS PASS'), findsWidgets);

      // Verify NO hardcoded mock student details exist (removed per redesign requirements)
      expect(find.text('NIDHIN RAJ'), findsNothing);
      expect(find.text('CCE23CS071'), findsNothing);

      // Verify NO hooks or generic clips exist
      expect(find.text('HOOK'), findsNothing);
      expect(find.text('LANYARD'), findsNothing);
    });

    testWidgets('3. Realistic Swing Animation — rope and card swing together around hidden pivot',
        (WidgetTester tester) async {
      final state = AppState(api: MockSplashApiClient(), storage: FakeSecureStorage());

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(appState: state),
        ),
      );

      // Advance to beginning of swing phase (~2000ms = t ~ 0.52)
      await tester.pump(const Duration(milliseconds: 2000));
      expect(find.byType(PhysicalIdCardLogin), findsOneWidget);

      // Verify rope is actively connected during swing
      final ropeFinder1 = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is SuspendedRopePainter,
      );
      expect(ropeFinder1, findsOneWidget);
      final ropePainter1 = tester.widget<CustomPaint>(ropeFinder1).painter as SuspendedRopePainter;
      expect(ropePainter1.ropeOpacity, equals(1.0));

      // Advance to middle of swing phase (~2300ms = t ~ 0.60)
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PhysicalIdCardLogin), findsOneWidget);

      // Advance to end of swing / start of zoom (~2700ms = t ~ 0.71)
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PhysicalIdCardLogin), findsOneWidget);
    });

    testWidgets('4. Continuous Zoom & Morph into Login — seamlessly reveals live functional login form',
        (WidgetTester tester) async {
      final state = AppState(api: MockSplashApiClient(), storage: FakeSecureStorage());

      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            home: SplashScreen(appState: state),
          ),
        ),
      );

      // Advance past the full 3800ms animation
      await tester.pump(const Duration(milliseconds: 3900));
      await tester.pumpAndSettle();

      // Verify the card has settled into the live interactive login interface
      expect(find.byType(PhysicalIdCardLogin), findsOneWidget);

      // Verify interactive login fields are present
      expect(find.text('WELCOME BACK'), findsOneWidget);
      expect(find.text('SEND OTP'), findsOneWidget);
      expect(find.text('New student? '), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);

      // Verify rope naturally moved out of view and is no longer present
      final finalRopeFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is SuspendedRopePainter,
      );
      expect(finalRopeFinder, findsNothing);

      // Verify startup flag is recorded
      expect(SplashScreen.hasPlayedStartup, isTrue);
    });

    testWidgets('5. Authenticated user navigates directly to role dashboard',
        (WidgetTester tester) async {
      final state = AppState(api: MockSplashApiClient(), storage: FakeSecureStorage());
      state.userId = 'student-test-1';
      state.userRoleId = 'student';
      state.userPermissions = ['createOutpass'];

      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            home: SplashScreen(appState: state),
          ),
        ),
      );

      // Complete transition
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();

      // Verify transitioned to StudentHome dashboard
      expect(find.byType(StudentHome), findsOneWidget);
    });

    testWidgets('6. Respects reduced-motion preference (disableAnimations: true)',
        (WidgetTester tester) async {
      final state = AppState(api: MockSplashApiClient(), storage: FakeSecureStorage());

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AppStateScope(
            state: state,
            child: MaterialApp(
              home: SplashScreen(appState: state),
            ),
          ),
        ),
      );

      // Immediately settles to completed state
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.byType(PhysicalIdCardLogin), findsOneWidget);
      expect(find.text('WELCOME BACK'), findsOneWidget);
      expect(find.text('SEND OTP'), findsOneWidget);
    });

    testWidgets('7. Replay prevention — subsequent display skips intro immediately',
        (WidgetTester tester) async {
      final state = AppState(api: MockSplashApiClient(), storage: FakeSecureStorage());
      SplashScreen.hasPlayedStartup = true; // Simulating subsequent visit / after logout

      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            home: SplashScreen(appState: state),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.byType(PhysicalIdCardLogin), findsOneWidget);
      expect(find.text('WELCOME BACK'), findsOneWidget);
      expect(find.text('SEND OTP'), findsOneWidget);
    });

    testWidgets('8. Visual Verification Frame Capture — renders rope drop and swing',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(720, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repaintKey = GlobalKey();
      final state = AppState(api: MockSplashApiClient(), storage: FakeSecureStorage());

      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            home: SplashScreen(
              appState: state,
              repaintKey: repaintKey,
            ),
          ),
        ),
      );

      // Frame A: Card drop attached to rope (t ~ 0.38 = 1450ms)
      await tester.pump(const Duration(milliseconds: 1450));
      expect(find.byType(PhysicalIdCardLogin), findsOneWidget);
      await tester.runAsync(() async {
        final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final file = File('C:/Users/SAYOOJ A R/.gemini/antigravity/brain/7b7bcc07-43be-47ba-b22f-6c4d3413fd64/splash_drop_with_rope.png');
          await file.writeAsBytes(byteData.buffer.asUint8List());
        }
      });

      // Frame B: Card swinging with rope around hidden pivot (t ~ 0.55 = 650ms further)
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.byType(PhysicalIdCardLogin), findsOneWidget);
      await tester.runAsync(() async {
        final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final file = File('C:/Users/SAYOOJ A R/.gemini/antigravity/brain/7b7bcc07-43be-47ba-b22f-6c4d3413fd64/splash_swing_with_rope.png');
          await file.writeAsBytes(byteData.buffer.asUint8List());
        }
      });

      // Frame C: Settled login interface (t = 1.0 = 1800ms further)
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pumpAndSettle();
      expect(find.byType(PhysicalIdCardLogin), findsOneWidget);
      await tester.runAsync(() async {
        final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final file = File('C:/Users/SAYOOJ A R/.gemini/antigravity/brain/7b7bcc07-43be-47ba-b22f-6c4d3413fd64/splash_settled_login.png');
          await file.writeAsBytes(byteData.buffer.asUint8List());
        }
      });
    });
  });
}
