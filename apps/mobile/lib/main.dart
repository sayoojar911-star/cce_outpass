import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'approver_screen.dart';
import 'guard_screen.dart';
import 'login_screen.dart';
import 'student_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
      appId: const String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId: const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
      authDomain: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    ),
  );
  runApp(const CceOutpassApp());
}

class CceOutpassApp extends StatelessWidget {
  const CceOutpassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CCE Outpass',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1B5E20), useMaterial3: true),
      home: AppStateScope(state: AppState(), child: const RootRouter()),
    );
  }
}

/// Routes by role after login (PRD §2.1): one app, role-specific homes.
class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (!state.loggedIn) return const LoginScreen();
    switch (state.userRole) {
      case 'STUDENT':
        return const StudentHome();
      case 'TUTOR':
      case 'HOD':
        return const ApproverHome();
      case 'GUARD':
        return const GuardHome();
      default:
        return Scaffold(
          body: Center(child: Text('Role ${state.userRole} has no UI in this MVP')),
        );
    }
  }
}
