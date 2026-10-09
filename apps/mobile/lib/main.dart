import 'package:firebase_core/firebase_core.dart';
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
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  if (apiKey.isNotEmpty) {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: apiKey,
          appId: String.fromEnvironment('FIREBASE_APP_ID'),
          messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
          projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
          authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        ),
      );
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
    }
  }
  runApp(const CceOutpassApp());
}

class CceOutpassApp extends StatelessWidget {
  const CceOutpassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CCE Outpass',
      theme: AppTheme.lightTheme,
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

    Widget screen;
    switch (state.userRole) {
      case 'STUDENT':
        screen = const StudentHome();
        break;
      case 'TUTOR':
      case 'HOD':
        screen = const ApproverHome();
        break;
      case 'GUARD':
        screen = const GuardHome();
        break;
      case 'ADMIN':
        screen = const AdminHome();
        break;
      default:
        screen = Scaffold(
          body: Center(child: Text('Role ${state.userRole} has no UI in this MVP')),
        );
    }

    final showDemo = state.api.isDemoMode &&
        (!kReleaseMode || const bool.fromEnvironment('IS_DEMO_MODE', defaultValue: false));

    if (showDemo) {
      return Stack(
        children: [
          screen,
          const Positioned(
            left: 16,
            bottom: 16,
            child: _DemoRoleSwitcherButton(),
          ),
        ],
      );
    }
    return screen;
  }
}

class _DemoRoleSwitcherButton extends StatelessWidget {
  const _DemoRoleSwitcherButton();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final role = state.userRole ?? '';
    final name = state.userName ?? '';

    String icon;
    Color color;
    switch (role) {
      case 'STUDENT':
        icon = '🎓';
        color = Colors.teal;
        break;
      case 'TUTOR':
        icon = '👨‍🏫';
        color = Colors.indigo;
        break;
      case 'HOD':
        icon = '🏛️';
        color = Colors.deepPurple;
        break;
      case 'GUARD':
        icon = '🛡️';
        color = Colors.blueGrey;
        break;
      case 'ADMIN':
        icon = '⚡';
        color = AppTheme.adminAccent;
        break;
      default:
        icon = '👤';
        color = Colors.grey;
    }

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(24),
      color: color,
      child: PopupMenuButton<String>(
        tooltip: 'Switch Demo Role',
        offset: const Offset(0, -260),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (mobile) {
          if (mobile == 'logout') {
            state.logout();
          } else {
            state.loginDemoMobile(mobile);
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(
            enabled: false,
            child: Text('SWITCH DEMO ROLE (PRD MVP)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          const PopupMenuItem(
            value: '9074121510',
            child: Text('🎓 Demo Student (9074121510)'),
          ),
          const PopupMenuItem(
            value: '9000000001',
            child: Text('👨‍🏫 Tutor — Dr. Anand Kumar'),
          ),
          const PopupMenuItem(
            value: '9000000002',
            child: Text('🏛️ HOD — Dr. Priya Menon'),
          ),
          const PopupMenuItem(
            value: '9000000090',
            child: Text('🛡️ Guard — Suresh (Security)'),
          ),
          const PopupMenuItem(
            value: '8921578838',
            child: Text('⚡ Admin — System Administrator'),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'logout',
            child: Text('🚪 Sign out'),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                '$role: $name',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Icon(Icons.arrow_drop_up, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
