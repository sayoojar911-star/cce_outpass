import 'package:flutter/material.dart';
export 'app_layout.dart';

/// Central design system token definitions for CCE Outpass.
/// Provides unified colors, typography, role-based visual accents,
/// status badges, rounded cards, and elevation styles.
class AppTheme {
  AppTheme._();

  // Burgundy & Cream Primary Palette
  static const Color burgundy = Color(0xFF702632); // Primary actions, active nav
  static const Color darkWine = Color(0xFF481C25); // Stronger navigation accents (used sparingly)
  static const Color cream = Color(0xFFFAF6F0); // Paper, canvas accents
  static const Color white = Color(0xFFFFFFFF); // Forms, tables, content surfaces
  static const Color warmGrey = Color(0xFFE7E0D8); // Borders, dividers
  static const Color charcoal = Color(0xFF292524); // Headings and primary text
  static const Color neutralBg = Color(0xFFF7F6F3); // Canvas / app background
  static const Color mutedText = Color(0xFF737373); // Subtitles, secondary text

  // Aliases for compatibility
  static const Color primary = burgundy;
  static const Color primaryLight = Color(0xFF8A3040);
  static const Color primaryDark = darkWine;
  static const Color appBackground = neutralBg;
  static const Color surface = white;
  static const Color surfaceBg = neutralBg;
  static const Color cardBg = white;
  static const Color textDark = charcoal;
  static const Color textMuted = mutedText;
  static const Color muted = mutedText;
  static const Color borderLight = warmGrey;
  static const Color border = warmGrey;

  // Semantic Colors
  static const Color success = Color(0xFF15803D); // Completed approvals, verified
  static const Color successGreen = success;
  static const Color warning = Color(0xFFB45309); // Pending actions, warnings
  static const Color warningAmber = warning;
  static const Color error = Color(0xFFB91C1C); // Rejections, invalid, cancelled
  static const Color errorRed = error;

  // Role Accent Colors (aligned with Burgundy & Cream palette)
  static const Color studentAccent = burgundy;
  static const Color tutorAccent = darkWine;
  static const Color hodAccent = burgundy;
  static const Color guardAccent = charcoal;
  static const Color adminAccent = darkWine;

  static Color statusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'APPROVED':
        return success;
      case 'PENDING':
      case 'PENDING_TUTOR':
      case 'PENDING_TUTOR_APPROVAL':
      case 'PENDING_HOD':
      case 'PENDING_HOD_APPROVAL':
        return warning;
      case 'REJECTED':
      case 'INVALID':
      case 'REVOKED':
        return error;
      case 'EXITED':
        return burgundy;
      case 'RETURNED':
        return success;
      case 'CANCELLED':
        return mutedText;
      default:
        return mutedText;
    }
  }

  static IconData statusIcon(String? status) {
    switch (status?.toUpperCase()) {
      case 'APPROVED':
      case 'RETURNED':
        return Icons.check_circle_outline;
      case 'PENDING':
      case 'PENDING_TUTOR':
      case 'PENDING_TUTOR_APPROVAL':
      case 'PENDING_HOD':
      case 'PENDING_HOD_APPROVAL':
        return Icons.hourglass_top_outlined;
      case 'REJECTED':
      case 'INVALID':
      case 'REVOKED':
        return Icons.cancel_outlined;
      case 'EXITED':
        return Icons.logout_rounded;
      case 'CANCELLED':
        return Icons.block_outlined;
      default:
        return Icons.info_outline;
    }
  }

  // Status Chip Colors
  static const Color statusPendingBg = Color(0xFFFEF3C7);
  static const Color statusPendingText = warning;

  static const Color statusApprovedBg = Color(0xFFDCFCE7);
  static const Color statusApprovedText = success;

  static const Color statusRejectedBg = Color(0xFFFEE2E2);
  static const Color statusRejectedText = error;

  static const Color statusExitedBg = Color(0xFFF4ECEC);
  static const Color statusExitedText = burgundy;

  static const Color statusReturnedBg = Color(0xFFDCFCE7);
  static const Color statusReturnedText = success;

  static const Color statusCancelledBg = Color(0xFFF5F5F4);
  static const Color statusCancelledText = mutedText;

  // Spacing & Border Radii (Restrained, thin borders, subtle corners)
  static const double radiusSm = 6.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 14.0;
  static const double radiusXl = 20.0;

  static const EdgeInsets screenPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);

  static Color roleColor(String? role) {
    switch (role?.toUpperCase()) {
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
        return burgundy;
    }
  }

  static IconData roleIcon(String? role) {
    switch (role?.toUpperCase()) {
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

  static const Color surfaceVariant = cream;
  static const double cardRadius = radiusMd;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: burgundy,
        onPrimary: white,
        primaryContainer: cream,
        onPrimaryContainer: darkWine,
        secondary: darkWine,
        onSecondary: white,
        secondaryContainer: cream,
        onSecondaryContainer: charcoal,
        surface: white,
        onSurface: charcoal,
        error: error,
        onError: white,
        outline: warmGrey,
        outlineVariant: Color(0xFFDCD5CC),
      ),
      scaffoldBackgroundColor: neutralBg,
      fontFamily: 'Inter',
      cardTheme: CardThemeData(
        elevation: 0,
        color: white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: warmGrey, width: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: white,
        foregroundColor: charcoal,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: charcoal,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 1,
        backgroundColor: white,
        indicatorColor: cream,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: burgundy,
              fontFamily: 'Inter',
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: mutedText,
            fontFamily: 'Inter',
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: warmGrey, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: warmGrey, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: burgundy, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error, width: 1.0),
        ),
        labelStyle: const TextStyle(color: mutedText, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFFA8A29E), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: burgundy,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: burgundy,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: charcoal,
          side: const BorderSide(color: warmGrey, width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: warmGrey,
        thickness: 1.0,
        space: 1.0,
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
      case 'PENDING_TUTOR_APPROVAL':
        bg = AppTheme.statusPendingBg;
        fg = AppTheme.statusPendingText;
        icon = Icons.hourglass_top_rounded;
        label = 'Pending Tutor';
        break;
      case 'PENDING_HOD':
      case 'PENDING_HOD_APPROVAL':
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
    final sub = subtitle;
    final act = action;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.borderLight.withValues(alpha: 0.5),
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
            if (sub != null && sub.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (act != null) ...[
              const SizedBox(height: 20),
              act,
            ],
          ],
        ),
      ),
    );
  }
}
