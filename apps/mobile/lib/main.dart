import 'package:flutter/material.dart';

import 'app_state.dart';
import 'admin_screen.dart';
import 'approver_screen.dart';
import 'guard_screen.dart';
import 'login_screen.dart';
import 'student_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CceOutpassApp());
}

class CceOutpassApp extends StatelessWidget {
  const CceOutpassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CCE Outpass',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
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
      case 'ADMIN':
        return const AdminHome();
      default:
        return Scaffold(
          body: Center(
              child: Text('Role ${state.userRole} has no UI in this MVP')),
        );
    }
  }
}
