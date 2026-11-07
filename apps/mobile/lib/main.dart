import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'admin_screen.dart';
import 'approver_screen.dart';
import 'guard_screen.dart';
import 'login_screen.dart';
import 'role_service.dart';
import 'splash_screen.dart';
import 'student_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('════════════════════════════════════════════════════════════════════════════');
    debugPrint('[FlutterError.onError] Framework error: ${details.exception}');
    debugPrint('Context: ${details.context}');
    debugPrint('Stack trace:\n${details.stack}');
    debugPrint('════════════════════════════════════════════════════════════════════════════');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('════════════════════════════════════════════════════════════════════════════');
    debugPrint('[PlatformDispatcher.onError] Async platform error: $error');
    debugPrint('Stack trace:\n$stack');
    debugPrint('════════════════════════════════════════════════════════════════════════════');
    return true;
  };

  runApp(const CceOutpassApp());
}

class CceOutpassApp extends StatefulWidget {
  const CceOutpassApp({super.key});

  @override
  State<CceOutpassApp> createState() => _CceOutpassAppState();
}

class _CceOutpassAppState extends State<CceOutpassApp> {
  final AppState _appState = AppState();

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: _appState,
      child: MaterialApp(
        title: 'CCE Outpass',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: SplashScreen(appState: _appState),
      ),
    );
  }
}

/// Routes by dynamic permissions via RoleService.
/// Single source of truth is RoleService, never raw strings or email.
class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (!state.loggedIn) return const LoginScreen();

    // 1. Pending role check
    if (RoleService.isPending(state)) {
      return const PendingApprovalScreen();
    }

    // 2. Admin access (manageUsers / manageRoles / viewAll)
    if (RoleService.canAccessAdmin(state)) {
      return const AdminHome();
    }

    // 3. Approver portal (approveOutpass)
    if (RoleService.canApproveOutpass(state)) {
      return const ApproverHome();
    }

    // 4. Security gate portal (scanGate)
    if (RoleService.canScanGate(state)) {
      return const GuardHome();
    }

    // 5. Student outpass creation (createOutpass)
    if (RoleService.canCreateOutpass(state)) {
      return const StudentHome();
    }

    // Fallback if role is not recognized or has no active permissions
    return const PendingApprovalScreen();
  }
}

/// Screen displayed when user has registered but admin has not assigned a role yet.
class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _refreshing = false;

  Future<void> _checkStatus(AppState state) async {
    setState(() => _refreshing = true);
    try {
      await state.refreshProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile refreshed. Checking role assignment...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CCE Outpass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => state.logout(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hourglass_top_rounded,
                        color: Colors.amber.shade800,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Account Pending Approval',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Hello, ${state.userName ?? 'User'}!\nYour account (${state.userMobile ?? ''}) has been registered successfully, but an Administrator has not assigned you an active role yet.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 20, color: AppTheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Current Role: ${state.userRoleName ?? state.userRoleId ?? "Pending"}\nPlease contact your college office to activate your role.',
                              style: const TextStyle(fontSize: 13, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: _refreshing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(_refreshing ? 'Checking...' : 'Check Status / Refresh'),
                        onPressed: _refreshing ? null : () => _checkStatus(state),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => state.logout(),
                        child: const Text('Sign Out'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
