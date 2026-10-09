import 'package:flutter/material.dart';

/// Central design system token definitions for CCE Outpass.
/// Provides unified colors, typography, role-based visual accents,
/// status badges, rounded cards, and elevation styles.
class AppTheme {
  AppTheme._();

  // Primary palette
  static const Color primary = Color(0xFF1E3A8A); // Deep Navy / Indigo
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF172554);
  static const Color surfaceBg = Color(0xFFF8FAFC); // Clean slate white
  static const Color cardBg = Colors.white;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Role Accent Colors
  static const Color studentAccent = Color(0xFF0284C7); // Sky / Blue
  static const Color tutorAccent = Color(0xFF0D9488); // Teal
  static const Color hodAccent = Color(0xFF7C3AED); // Purple
  static const Color guardAccent = Color(0xFFEA580C); // Warm Orange
  static const Color adminAccent = Color(0xFF1E293B); // Dark Navy / Slate

  // Status Chip Colors
  static const Color statusPendingBg = Color(0xFFFEF3C7);
  static const Color statusPendingText = Color(0xFFB45309);

  static const Color statusApprovedBg = Color(0xFFD1FAE5);
  static const Color statusApprovedText = Color(0xFF047857);

  static const Color statusRejectedBg = Color(0xFFFEE2E2);
  static const Color statusRejectedText = Color(0xFFB91C1C);

  static const Color statusExitedBg = Color(0xFFDBEAFE);
  static const Color statusExitedText = Color(0xFF1D4ED8);

  static const Color statusReturnedBg = Color(0xFFE0E7FF);
  static const Color statusReturnedText = Color(0xFF4338CA);

  static const Color statusCancelledBg = Color(0xFFF1F5F9);
  static const Color statusCancelledText = Color(0xFF475569);

  // Spacing & Border Radii
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;

  static const EdgeInsets screenPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(18.0);

  static Color roleColor(String? role) {
    switch (role) {
      case 'STUDENT':
        return studentAccent;
      case 'TUTOR':
        return tutorAccent;
      case 'HOD':
        return hodAccent;
      case 'GUARD':
        return guardAccent;
      case 'ADMIN':
        return adminAccent;
      default:
        return primary;
    }
  }

  static IconData roleIcon(String? role) {
    switch (role) {
      case 'STUDENT':
        return Icons.school_outlined;
      case 'TUTOR':
        return Icons.supervisor_account_outlined;
      case 'HOD':
        return Icons.account_balance_outlined;
      case 'GUARD':
        return Icons.security_outlined;
      case 'ADMIN':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.person_outline;
    }
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        background: surfaceBg,
        surface: cardBg,
        primary: primary,
      ),
      scaffoldBackgroundColor: surfaceBg,
      fontFamily: 'Inter',
      cardTheme: CardTheme(
        elevation: 0,
        color: cardBg,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 2,
        backgroundColor: Colors.white,
        indicatorColor: primary.withOpacity(0.12),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: primary);
          }
          return const TextStyle(
              fontSize: 12, fontWeight: FontWeight.normal, color: textMuted);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
    );
  }
}

/// Rich status badge chip with semantic icon and colors
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case 'PENDING_TUTOR':
        bg = AppTheme.statusPendingBg;
        fg = AppTheme.statusPendingText;
        icon = Icons.hourglass_top_rounded;
        label = 'Pending Tutor';
        break;
      case 'PENDING_HOD':
        bg = AppTheme.statusPendingBg;
        fg = AppTheme.statusPendingText;
        icon = Icons.hourglass_bottom_rounded;
        label = 'Pending HOD';
        break;
      case 'APPROVED':
        bg = AppTheme.statusApprovedBg;
        fg = AppTheme.statusApprovedText;
        icon = Icons.check_circle_outline_rounded;
        label = 'Approved';
        break;
      case 'EXITED':
        bg = AppTheme.statusExitedBg;
        fg = AppTheme.statusExitedText;
        icon = Icons.logout_rounded;
        label = 'Out (Exited)';
        break;
      case 'RETURNED':
        bg = AppTheme.statusReturnedBg;
        fg = AppTheme.statusReturnedText;
        icon = Icons.task_alt_rounded;
        label = 'Returned';
        break;
      case 'REJECTED':
        bg = AppTheme.statusRejectedBg;
        fg = AppTheme.statusRejectedText;
        icon = Icons.cancel_outlined;
        label = 'Rejected';
        break;
      case 'CANCELLED':
        bg = AppTheme.statusCancelledBg;
        fg = AppTheme.statusCancelledText;
        icon = Icons.block_rounded;
        label = 'Cancelled';
        break;
      default:
        bg = AppTheme.statusCancelledBg;
        fg = AppTheme.statusCancelledText;
        icon = Icons.info_outline;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly empty state widget
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.borderLight.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
