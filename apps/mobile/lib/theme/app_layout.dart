import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens for spacing, corner radii, sizing, breakpoints, and tap targets.
class AppSpacing {
  AppSpacing._();

  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s48 = 48.0;

  // Semantic aliases
  static const double xs = s4;
  static const double sm = s8;
  static const double md = s12;
  static const double lg = s16;
  static const double xl = s24;
  static const double xxl = s32;
  static const double xxxl = s48;

  // Rhythm gaps
  static const double fieldGap = s16;
  static const double sectionGap = s24;
  static const double labelGap = s8;
  static const double buttonGap = s12;
}

class AppRadii {
  AppRadii._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;

  static BorderRadius get roundedSm => BorderRadius.circular(sm);
  static BorderRadius get roundedMd => BorderRadius.circular(md);
  static BorderRadius get roundedLg => BorderRadius.circular(lg);
  static BorderRadius get roundedXl => BorderRadius.circular(xl);
}

class AppLayout {
  AppLayout._();

  static const double minTapTargetMobile = 48.0;
  static const double minTapTargetDesktop = 44.0;

  // Responsive Breakpoints
  static const double breakpointCompact = 600.0;
  static const double breakpointMedium = 1024.0;

  // Max content widths
  static const double maxFormWidth = 560.0;
  static const double maxPassWidth = 480.0;
  static const double maxDashboardWidth = 1200.0;
  static const double maxButtonWidth = 320.0;
  static const double maxDialogWidth = 480.0;

  static bool isCompact(BuildContext context) =>
      MediaQuery.of(context).size.width < breakpointCompact;

  static bool isMedium(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= breakpointCompact && w <= breakpointMedium;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.of(context).size.width > breakpointMedium;

  static EdgeInsets screenPadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < breakpointCompact) {
      return const EdgeInsets.all(AppSpacing.s16);
    } else if (w <= breakpointMedium) {
      return const EdgeInsets.all(AppSpacing.s24);
    } else {
      return const EdgeInsets.all(AppSpacing.s32);
    }
  }

  static double minTapTarget(BuildContext context) {
    return isCompact(context) ? minTapTargetMobile : minTapTargetDesktop;
  }
}

/// A responsive container that centers its child and enforces standard max width and padding.
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.maxDashboardWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding ?? AppLayout.screenPadding(context);
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: resolvedPadding,
          child: child,
        ),
      ),
    );
  }
}

/// Primary button with unified 48px height, loading state, focus rings, and responsive desktop width.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.disabledReason,
    this.backgroundColor,
    this.foregroundColor,
    this.fullWidth = true,
    this.maxWidth = AppLayout.maxButtonWidth,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final String? disabledReason;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool fullWidth;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppLayout.isCompact(context);
    final theme = Theme.of(context);
    final isEnabled = onPressed != null && !loading;

    Widget buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                foregroundColor ?? Colors.white,
              ),
            ),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: isEnabled ? (foregroundColor ?? Colors.white) : Colors.black38),
        if (loading || icon != null) const SizedBox(width: AppSpacing.s8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              loading ? 'Please wait…' : label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isEnabled ? (foregroundColor ?? Colors.white) : Colors.black38,
              ),
              maxLines: 1,
            ),
          ),
        ),
      ],
    );

    Widget btn = SizedBox(
      height: 48,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor ?? theme.colorScheme.primary,
          foregroundColor: foregroundColor ?? Colors.white,
          disabledBackgroundColor: Colors.black12,
          disabledForegroundColor: Colors.black38,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
        ),
        onPressed: isEnabled ? onPressed : null,
        child: buttonContent,
      ),
    );

    if (disabledReason != null && !isEnabled && !loading) {
      btn = Tooltip(
        message: disabledReason!,
        child: btn,
      );
    }

    if (fullWidth) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : maxWidth),
        child: SizedBox(
          width: isMobile ? double.infinity : maxWidth,
          child: btn,
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: btn,
    );
  }
}

/// Secondary / Outlined button with unified 48px height and matching metrics.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.disabledReason,
    this.color,
    this.fullWidth = true,
    this.maxWidth = AppLayout.maxButtonWidth,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final String? disabledReason;
  final Color? color;
  final bool fullWidth;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppLayout.isCompact(context);
    final theme = Theme.of(context);
    final activeColor = color ?? theme.colorScheme.primary;
    final isEnabled = onPressed != null && !loading;

    Widget buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(activeColor),
            ),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: isEnabled ? activeColor : Colors.black38),
        if (loading || icon != null) const SizedBox(width: AppSpacing.s8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              loading ? 'Please wait…' : label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isEnabled ? activeColor : Colors.black38,
              ),
              maxLines: 1,
            ),
          ),
        ),
      ],
    );

    Widget btn = SizedBox(
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: activeColor,
          side: BorderSide(
            color: isEnabled ? activeColor : Colors.black12,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
        ),
        onPressed: isEnabled ? onPressed : null,
        child: buttonContent,
      ),
    );

    if (disabledReason != null && !isEnabled && !loading) {
      btn = Tooltip(
        message: disabledReason!,
        child: btn,
      );
    }

    if (fullWidth) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : maxWidth),
        child: SizedBox(
          width: isMobile ? double.infinity : maxWidth,
          child: btn,
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: btn,
    );
  }
}

/// Destructive button (red outline or subtle red fill) for dangerous actions.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    super.key,
    required this.label,
    this.icon = Icons.delete_outline_rounded,
    this.onPressed,
    this.loading = false,
    this.filled = false,
    this.fullWidth = true,
    this.maxWidth = AppLayout.maxButtonWidth,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool filled;
  final bool fullWidth;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppLayout.isCompact(context);
    const redColor = Color(0xFFDC2626);
    final isEnabled = onPressed != null && !loading;

    Widget buttonContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(redColor),
            ),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: filled ? Colors.white : redColor),
        if (loading || icon != null) const SizedBox(width: AppSpacing.s8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              loading ? 'Please wait…' : label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : redColor,
              ),
              maxLines: 1,
            ),
          ),
        ),
      ],
    );

    Widget btn;
    if (filled) {
      btn = SizedBox(
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: redColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
          ),
          onPressed: isEnabled ? onPressed : null,
          child: buttonContent,
        ),
      );
    } else {
      btn = SizedBox(
        height: 48,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: redColor,
            side: const BorderSide(color: redColor, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
          ),
          onPressed: isEnabled ? onPressed : null,
          child: buttonContent,
        ),
      );
    }

    if (fullWidth) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : maxWidth),
        child: SizedBox(
          width: isMobile ? double.infinity : maxWidth,
          child: btn,
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: btn,
    );
  }
}

/// Unified text button with minimum 48px tap target.
class AppTextButton extends StatelessWidget {
  const AppTextButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = color ?? theme.colorScheme.primary;

    return SizedBox(
      height: 48,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: activeColor,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: activeColor),
              const SizedBox(width: AppSpacing.s8),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: activeColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Equal-width button pair with a 12px gap.
/// On desktop: primary on right, secondary/cancel on left.
/// On mobile compact: stacks vertically with primary on top, or side-by-side equal-width if sideBySideMobile is true.
class AppButtonRow extends StatelessWidget {
  const AppButtonRow({
    super.key,
    required this.primary,
    required this.secondary,
    this.sideBySideMobile = false,
  });

  final Widget primary;
  final Widget secondary;
  final bool sideBySideMobile;

  @override
  Widget build(BuildContext context) {
    final isMobile = AppLayout.isCompact(context);

    if (isMobile && !sideBySideMobile) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          const SizedBox(height: AppSpacing.buttonGap),
          secondary,
        ],
      );
    }

    // Side-by-side equal width with 12px gap
    return Row(
      children: [
        Expanded(child: secondary),
        const SizedBox(width: AppSpacing.buttonGap),
        Expanded(child: primary),
      ],
    );
  }
}

/// Standardized card with token padding, radius, and subtle border.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
    this.margin,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: AppRadii.roundedMd,
        border: Border.all(
          color: borderColor ?? const Color(0xFFE7E0D8),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.roundedMd,
        child: InkWell(
          borderRadius: AppRadii.roundedMd,
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    return card;
  }
}

/// Standardized text field with 48px height, 10px radius, phone +91 prefix, and consistent spacing.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.helperText,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.enabled = true,
    this.obscureText = false,
    this.maxLength,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final Widget? prefixIcon;
  final String? prefixText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool enabled;
  final bool obscureText;
  final int? maxLength;
  final int maxLines;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      obscureText: obscureText,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: prefixIcon,
        prefixText: prefixText,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF7F6F3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: const BorderSide(color: Color(0xFFE7E0D8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: const BorderSide(color: Color(0xFFE7E0D8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: const BorderSide(color: Color(0xFF702632), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: const BorderSide(color: Color(0xFFB91C1C)),
        ),
      ),
    );
  }
}

/// Standardized dropdown matching AppTextField's height, radius, and border.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.labelText,
    this.hintText,
    this.helperText,
    this.prefixIcon,
    this.validator,
  });

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final Widget? prefixIcon;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: const BorderSide(color: Color(0xFFE7E0D8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: const BorderSide(color: Color(0xFFE7E0D8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: const BorderSide(color: Color(0xFF702632), width: 1.5),
        ),
      ),
    );
  }
}

/// Standardized dialog with max width 480px, scrollable body on small screens, and right-aligned buttons.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.titleIcon,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final IconData? titleIcon;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    required List<Widget> actions,
    IconData? titleIcon,
  }) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => AppDialog(
        title: title,
        content: content,
        actions: actions,
        titleIcon: titleIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.roundedLg,
          side: const BorderSide(color: Color(0xFFE7E0D8), width: 1.0),
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxDialogWidth),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    if (titleIcon != null) ...[
                      Icon(titleIcon, size: 22, color: const Color(0xFF702632)),
                      const SizedBox(width: AppSpacing.s8),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF292524),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                // Scrollable Content
                Flexible(
                  child: SingleChildScrollView(
                    child: content,
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),
                // Right-aligned Action Buttons with 12px gap
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions.map((w) {
                    final idx = actions.indexOf(w);
                    if (idx == 0) return w;
                    return Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.buttonGap),
                      child: w,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Standardized section header with 24px vertical rhythm and optional action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.s24,
        bottom: AppSpacing.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF292524),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF737373),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Standard status badge with semantic color, icon, and uniform padding.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.label,
  });

  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    String textLabel = label ?? status;

    switch (status.toUpperCase()) {
      case 'APPROVED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        icon = Icons.check_circle_outline_rounded;
        textLabel = label ?? 'Approved';
        break;
      case 'PENDING_TUTOR':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        icon = Icons.hourglass_top_rounded;
        textLabel = label ?? 'Pending Tutor';
        break;
      case 'PENDING_HOD':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        icon = Icons.hourglass_bottom_rounded;
        textLabel = label ?? 'Pending HOD';
        break;
      case 'EXITED':
        bg = const Color(0xFFF4ECEC);
        fg = const Color(0xFF702632);
        icon = Icons.logout_rounded;
        textLabel = label ?? 'Out (Exited)';
        break;
      case 'RETURNED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        icon = Icons.task_alt_rounded;
        textLabel = label ?? 'Returned';
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        icon = Icons.cancel_outlined;
        textLabel = label ?? 'Rejected';
        break;
      case 'CANCELLED':
        bg = const Color(0xFFF5F5F4);
        fg = const Color(0xFF737373);
        icon = Icons.block_rounded;
        textLabel = label ?? 'Cancelled';
        break;
      case 'OVERDUE':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        icon = Icons.alarm_rounded;
        textLabel = label ?? 'Overdue';
        break;
      default:
        bg = const Color(0xFFF5F5F4);
        fg = const Color(0xFF737373);
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8 + 2,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: AppSpacing.s4 + 1),
          Text(
            textLabel,
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
