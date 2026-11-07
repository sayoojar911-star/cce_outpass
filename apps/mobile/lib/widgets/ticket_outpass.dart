import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../async_action_helper.dart';
import '../qr_token.dart';
import '../theme/app_theme.dart';
import '../util/platform_print.dart';
import '../util/ticket_html_generator.dart';
import 'printed_receipt_reveal.dart';

/// Modern Academic Digital Outpass Receipt
///
/// Designed as a clean digital receipt with:
/// - Monospace header: `CCE OUTPASS - <TYPE> - #<PASS ID>` between dashed lines
/// - Ordered print content: student details, trip destination/purpose,
///   exit/return timings (IST), type badge & status pill, approval progress card,
///   dynamic QR token & stable pass code, and download/share actions.
/// - Step tracker with green check dots (✓) for completed steps and a dark dot (●)
///   for current step (Emergency: HOD, Exit, Return / Normal: Tutor, HOD, Exit, Return).
/// - 3D receipt printer reveal animation (when animatePrint is true) that feeds
///   out of a 3D thermal printer and smoothly expands into full digital receipt.
class TicketOutpass extends StatefulWidget {
  const TicketOutpass({
    super.key,
    required this.outpass,
    this.showStub = true,
    this.enableTilt = true,
    this.animatePrint = false,
    this.onStatusChanged,
    this.onCancel,
  });

  final Map<String, dynamic> outpass;
  final bool showStub;
  final bool enableTilt;
  final bool animatePrint;
  final VoidCallback? onStatusChanged;
  final VoidCallback? onCancel;

  @override
  State<TicketOutpass> createState() => _TicketOutpassState();
}

class _TicketOutpassState extends State<TicketOutpass> with SingleTickerProviderStateMixin {
  final GlobalKey<PrintedReceiptRevealState> _revealKey =
      GlobalKey<PrintedReceiptRevealState>();

  // 3D Tilt state
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  bool _isHovering = false;
  final bool _staticMode = false;

  // QR Rotating Step
  int _step = DeviceKeys.currentStep();
  late final AnimationController _countdownController;

  @override
  void initState() {
    super.initState();
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );

    final outpassId = (widget.outpass['id'] ?? widget.outpass['displayId'])?.toString();
    final passStatus = (widget.outpass['status'] as String? ?? '').toUpperCase();
    final isApproved = passStatus.isEmpty || passStatus == 'APPROVED';
    final issuanceKey = outpassId != null ? PrintedReceiptReveal.issuanceEventKey(outpassId) : null;
    final willAnimatePrint = widget.animatePrint &&
        isApproved &&
        (issuanceKey == null || !PrintedReceiptReveal.hasPrintedEvent(issuanceKey));

    if (!willAnimatePrint) {
      _syncStepAndTimer();
    }
  }

  void _syncStepAndTimer() {
    if (!mounted) return;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final currentStep = (nowSec ~/ 30) * 30;
    if (_step != currentStep) {
      setState(() {
        _step = currentStep;
      });
    }
    final elapsedInStep = nowSec - _step;
    final remainingSec = (30 - elapsedInStep).clamp(1, 30);

    _countdownController.duration = Duration(seconds: remainingSec);
    _countdownController.forward(from: 0.0).then((_) {
      if (mounted) {
        _syncStepAndTimer();
      }
    });
  }

  @override
  void dispose() {
    _countdownController.dispose();
    super.dispose();
  }

  void _onHover(PointerHoverEvent event, Size size) {
    if (_staticMode ||
        !widget.enableTilt ||
        (!kIsWeb &&
            defaultTargetPlatform != TargetPlatform.windows &&
            defaultTargetPlatform != TargetPlatform.macOS &&
            defaultTargetPlatform != TargetPlatform.linux)) {
      return;
    }
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final normalizedX = ((event.localPosition.dx - centerX) / centerX).clamp(-1.0, 1.0);
    final normalizedY = ((event.localPosition.dy - centerY) / centerY).clamp(-1.0, 1.0);

    setState(() {
      _isHovering = true;
      _tiltX = -normalizedY * 0.035; // subtle max ~2 degrees
      _tiltY = normalizedX * 0.035;
    });
  }

  void _onExit(PointerExitEvent event) {
    setState(() {
      _isHovering = false;
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    // Thermal Receipt Paper styling - Burgundy & Cream
    final ticketBg = isDark ? const Color(0xFF1C1917) : AppTheme.cream;
    final ticketBorder = isDark ? const Color(0xFF292524) : AppTheme.border;
    final primaryBurgundy = isDark ? const Color(0xFFD48B96) : AppTheme.burgundy;
    final darkWine = isDark ? const Color(0xFFE2A8B2) : AppTheme.darkWine;
    final textColor = isDark ? const Color(0xFFFAF6F0) : AppTheme.charcoal;
    final labelColor = isDark ? const Color(0xFFA8A29E) : AppTheme.muted;

    final status = (widget.outpass['status'] as String? ?? 'PENDING_TUTOR').toUpperCase();
    final isApproved = status == 'APPROVED';
    final rawDisplayId = widget.outpass['displayId'] ?? widget.outpass['id'] ?? 'OP-PENDING';
    final displayId = rawDisplayId.toString();
    final typeId = (widget.outpass['typeId'] ?? widget.outpass['type'] ?? '').toString().toLowerCase();
    final isEmergency = typeId == 'emergency';
    final typeUpper = isEmergency ? 'EMERGENCY' : 'NORMAL';

    final transform = (_staticMode || reduceMotion || !widget.enableTilt || !_isHovering)
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateX(_tiltX)
          ..rotateY(_tiltY));

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(constraints.maxWidth, 460.0);

        final receiptCard = MouseRegion(
          onHover: (e) => _onHover(e, Size(cardWidth, 800)),
          onExit: _onExit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: transform,
            transformAlignment: FractionalOffset.center,
            width: cardWidth,
            decoration: BoxDecoration(
              color: ticketBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ticketBorder, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.40)
                      : const Color(0xFF292524).withValues(alpha: 0.06),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // -------------------------------------------------------------
                // RECEIPT HEADER: Between two dashed lines in monospace font
                // "CCE OUTPASS - <TYPE> - #<PASS ID>"
                // -------------------------------------------------------------
                _buildReceiptHeader(isDark, typeUpper, displayId),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Student name and department
                      _buildStudentSection(context, isDark, primaryBurgundy, textColor, labelColor),
                      const SizedBox(height: 14),

                      // 2. Destination and purpose category
                      _buildDestinationAndPurpose(isDark, primaryBurgundy, darkWine, textColor, labelColor, isEmergency),
                      const SizedBox(height: 14),

                      // 3. Exit time and return time (local time, IST)
                      _buildTimingsRow(isDark, primaryBurgundy),
                      const SizedBox(height: 14),

                      // 4. Type badge (Normal / Emergency) and status pill
                      _buildTypeAndStatus(isEmergency, status),
                      const SizedBox(height: 14),

                      // 5. Approval progress card with step tracker
                      //    (Normal: Tutor, HOD, Exit, Return / Emergency: HOD, Exit, Return)
                      _buildApprovalProgressCard(context, isDark, isEmergency, status),
                      const SizedBox(height: 14),

                      // Perforation divider above QR stub (Polish 6)
                      _buildPerforationDivider(isDark),
                      const SizedBox(height: 14),

                      // 6. QR code and stable pass code beneath it
                      _buildQrAndPassCodeSection(context, isDark, primaryBurgundy, status),
                      const SizedBox(height: 12),

                      // 7. Action buttons: "Download Pass" and "Share"
                      _buildActionButtons(context, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        if (widget.animatePrint && isApproved) {
          final outpassId = (widget.outpass['id'] ?? widget.outpass['displayId'])?.toString();
          return Center(
            child: PrintedReceiptReveal(
              key: _revealKey,
              outpassId: outpassId,
              printEventId: outpassId != null ? PrintedReceiptReveal.issuanceEventKey(outpassId) : null,
              status: status,
              initialPrint: true,
              onComplete: () {
                if (mounted && !_countdownController.isAnimating) {
                  _syncStepAndTimer();
                }
              },
              child: receiptCard,
            ),
          );
        }

        return Center(
          child: receiptCard,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // RECEIPT HEADER: Dashed monospace header
  // ---------------------------------------------------------------------------
  Widget _buildReceiptHeader(bool isDark, String typeUpper, String displayId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF292524) : const Color(0xFFF0EBE1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF44403C) : AppTheme.border,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Text(
            '----------------------------------------',
            style: TextStyle(
              color: isDark ? Colors.white24 : AppTheme.muted.withValues(alpha: 0.4),
              fontSize: 11,
              fontFamily: 'monospace',
              letterSpacing: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'CCE OUTPASS - $typeUpper - #$displayId',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppTheme.cream : AppTheme.charcoal,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '----------------------------------------',
            style: TextStyle(
              color: isDark ? Colors.white24 : AppTheme.muted.withValues(alpha: 0.4),
              fontSize: 11,
              fontFamily: 'monospace',
              letterSpacing: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Student Name and Department
  // ---------------------------------------------------------------------------
  Widget _buildStudentSection(
    BuildContext context,
    bool isDark,
    Color primaryBurgundy,
    Color textColor,
    Color labelColor,
  ) {
    final state = AppStateScope.of(context);
    final student = widget.outpass['student'] as Map<String, dynamic>?;

    final studentName = student?['name'] ?? widget.outpass['studentName'] ?? state.userName ?? 'Authorized Student';
    final regNo = student?['registerNo'] ?? widget.outpass['registerNo'] ?? 'REG-RECORD';
    final dept = student?['department'] ?? widget.outpass['department'] ?? state.userDepartment ?? 'General Engineering';
    final sem = student?['semester'];
    final year = student?['year'] ?? widget.outpass['year'] ?? state.userYear;
    final div = student?['division'] ?? widget.outpass['division'] ?? state.userDivision;

    final academicInfo = StringBuffer(dept);
    if (year != null) academicInfo.write(' · Year $year');
    if (sem != null && year == null) academicInfo.write(' · Sem $sem');
    if (div != null && div.toString().isNotEmpty) academicInfo.write(' · Div $div');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: primaryBurgundy.withValues(alpha: 0.12),
          child: Text(
            studentName.toString().isNotEmpty ? studentName.toString()[0].toUpperCase() : 'S',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryBurgundy,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
           child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                studentName.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : AppTheme.border.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      regNo.toString(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: labelColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      academicInfo.toString(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: labelColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Destination and Purpose Category
  // ---------------------------------------------------------------------------
  Widget _buildDestinationAndPurpose(
    bool isDark,
    Color primaryBurgundy,
    Color darkWine,
    Color textColor,
    Color labelColor,
    bool isEmergency,
  ) {
    final destination = (widget.outpass['destination'] ?? 'Not specified').toString();
    final purposeCategory = (widget.outpass['purposeCategory'] ?? 'General').toString();
    final purposeText = widget.outpass['purposeText'] as String?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF292524) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF44403C) : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: primaryBurgundy),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  destination,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isEmergency
                      ? AppTheme.errorRed.withValues(alpha: 0.12)
                      : primaryBurgundy.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  purposeCategory,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isEmergency ? AppTheme.errorRed : primaryBurgundy,
                  ),
                ),
              ),
            ],
          ),
          if (purposeText != null && purposeText.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              purposeText.trim(),
              style: TextStyle(
                fontSize: 11.5,
                color: isEmergency ? AppTheme.errorRed : labelColor,
                fontStyle: isEmergency ? FontStyle.normal : FontStyle.italic,
                fontWeight: isEmergency ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Exit Time and Return Time (Local Time, IST)
  // ---------------------------------------------------------------------------
  Widget _buildTimingsRow(bool isDark, Color primaryBurgundy) {
    final exitTime = _formatDateTime(widget.outpass['exitAt'] ?? widget.outpass['requestedExitAt']);
    final returnTime = _formatDateTime(widget.outpass['entryAt'] ?? widget.outpass['expectedReturnAt']);

    return Row(
      children: [
        Expanded(
          child: _buildTimeTile(
            title: 'EXIT TIME (IST)',
            timeStr: exitTime,
            icon: Icons.logout_rounded,
            accentColor: AppTheme.burgundy,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTimeTile(
            title: 'RETURN TIME (IST)',
            timeStr: returnTime,
            icon: Icons.login_rounded,
            accentColor: AppTheme.darkWine,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeTile({
    required String title,
    required String timeStr,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF292524) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF44403C) : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 4),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isDark ? const Color(0xFFA8A29E) : AppTheme.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              timeStr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFFAF6F0) : AppTheme.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Type Badge (Normal / Emergency) and Status Pill
  // ---------------------------------------------------------------------------
  Widget _buildTypeAndStatus(bool isEmergency, String status) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Type Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isEmergency ? AppTheme.darkWine : AppTheme.burgundy,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isEmergency ? 'EMERGENCY' : 'NORMAL',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Status Pill
            _buildStatusBadge(status),
          ],
        ),
        if (status == 'APPROVED')
          const _ApprovedStampWidget(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Approval Progress Card with Step Tracker
  // (Emergency: HOD, Exit, Return / Normal: Tutor, HOD, Exit, Return)
  // ---------------------------------------------------------------------------
  Widget _buildApprovalProgressCard(
    BuildContext context,
    bool isDark,
    bool isEmergency,
    String status,
  ) {
    final approvalPath = widget.outpass['approvalPath']?.toString().toUpperCase();
    final isDirectApproval = approvalPath == 'DIRECT';
    final List<String> steps = isEmergency
        ? const ['HOD', 'Exit', 'Return']
        : (isDirectApproval
            ? const ['Tutor', 'Exit', 'Return']
            : const ['Tutor', 'HOD', 'Exit', 'Return']);

    // Determine current active step index and completed steps
    int currentStepIndex;
    final hasExitedTimeline = widget.outpass['exitAt'] != null || status == 'EXITED' || status == 'RETURNED';
    if (isEmergency) {
      if (status == 'PENDING_HOD' || status == 'PENDING_HOD_APPROVAL') {
        currentStepIndex = 0; // HOD active
      } else if (status == 'APPROVED') {
        currentStepIndex = 1; // Exit active
      } else if (status == 'EXITED' || (status == 'OVERDUE' && hasExitedTimeline)) {
        currentStepIndex = 2; // Return active
      } else if (status == 'RETURNED') {
        currentStepIndex = 3; // all complete
      } else {
        currentStepIndex = 1; // Exit active
      }
    } else if (isDirectApproval) {
      if (status == 'APPROVED') {
        currentStepIndex = 1; // Exit active, Tutor completed
      } else if (status == 'EXITED' || (status == 'OVERDUE' && hasExitedTimeline)) {
        currentStepIndex = 2; // Return active
      } else if (status == 'RETURNED') {
        currentStepIndex = 3; // all complete
      } else if (status == 'OVERDUE') {
        currentStepIndex = 1; // Exit active
      } else {
        currentStepIndex = 0;
      }
    } else {
      if (status == 'PENDING_TUTOR' || status == 'PENDING_TUTOR_APPROVAL' || status == 'PENDING') {
        currentStepIndex = 0; // Tutor active
      } else if (status == 'PENDING_HOD' || status == 'PENDING_HOD_APPROVAL') {
        currentStepIndex = 1; // HOD active
      } else if (status == 'APPROVED') {
        currentStepIndex = 2; // Exit active
      } else if (status == 'EXITED' || (status == 'OVERDUE' && hasExitedTimeline)) {
        currentStepIndex = 3; // Return active
      } else if (status == 'RETURNED') {
        currentStepIndex = 4; // all complete
      } else if (status == 'OVERDUE') {
        currentStepIndex = 2; // Exit active
      } else {
        currentStepIndex = 0;
      }
    }

    final cardBg = isDark ? const Color(0xFF292524) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF44403C) : AppTheme.border;
    final isCancelled = status == 'CANCELLED';
    final isApprovedOrReturned = status == 'APPROVED' || status == 'RETURNED';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCancelled
                    ? Icons.cancel_outlined
                    : (isApprovedOrReturned
                        ? Icons.verified
                        : Icons.pending_actions_outlined),
                size: 15,
                color: isCancelled
                    ? AppTheme.errorRed
                    : (isApprovedOrReturned
                        ? AppTheme.successGreen
                        : AppTheme.warningAmber),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Builder(
                  builder: (context) {
                  String statusTitle;
                  if (status == 'APPROVED') {
                    if (approvalPath == 'DIRECT') {
                      statusTitle = 'Approved by Tutor — Final Approval';
                    } else if (approvalPath == 'FORWARD_HOD') {
                      statusTitle = 'Approved by HOD — Final Approval';
                    } else {
                      statusTitle = 'Status: APPROVED';
                    }
                  } else if (status == 'PENDING_HOD' || status == 'PENDING_HOD_APPROVAL') {
                    statusTitle = 'Tutor Approved — Awaiting HOD Approval';
                  } else if (status == 'PENDING_TUTOR' || status == 'PENDING_TUTOR_APPROVAL' || status == 'PENDING') {
                    statusTitle = 'Awaiting Tutor Approval';
                  } else {
                    statusTitle = 'Status: $status';
                  }
                  return Text(
                    statusTitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isCancelled
                          ? AppTheme.errorRed
                          : (isDark ? const Color(0xFFFAF6F0) : AppTheme.charcoal),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  );
                },
              ),
            ),  ],
          ),
          if (isCancelled) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.errorRed, size: 15),
                      SizedBox(width: 6),
                      Text(
                        'Outpass Cancelled',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorRed,
                        ),
                      ),
                    ],
                  ),
                  if (widget.outpass['cancelReason'] != null &&
                      widget.outpass['cancelReason'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Reason: ${widget.outpass['cancelReason']}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFFD6D3D1) : AppTheme.charcoal,
                      ),
                    ),
                  ],
                  if (widget.outpass['cancelledAt'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Cancelled at: ${widget.outpass['cancelledAt']}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? const Color(0xFFA8A29E) : AppTheme.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Step tracker row
          Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                _buildTrackerNode(
                  label: steps[i],
                  isCompleted: i < currentStepIndex,
                  isCurrent: i == currentStepIndex,
                  isDark: isDark,
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      color: i < currentStepIndex
                          ? AppTheme.successGreen // Green connector if completed
                          : (isDark ? const Color(0xFF44403C) : AppTheme.border),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerNode({
    required String label,
    required bool isCompleted,
    required bool isCurrent,
    required bool isDark,
  }) {
    final Color dotBg;
    final Widget? dotChild;
    final Color textColor;

    if (isCompleted) {
      // Completed step: green check dot
      dotBg = AppTheme.successGreen;
      dotChild = const Icon(Icons.check, size: 10, color: Colors.white);
      textColor = AppTheme.successGreen;
    } else if (isCurrent) {
      // Current active step: dark dot
      dotBg = isDark ? Colors.white : AppTheme.charcoal;
      dotChild = Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.charcoal : Colors.white,
          shape: BoxShape.circle,
        ),
      );
      textColor = isDark ? Colors.white : AppTheme.charcoal;
    } else {
      // Upcoming step: light gray dot
      dotBg = isDark ? const Color(0xFF44403C) : AppTheme.border;
      dotChild = null;
      textColor = isDark ? const Color(0xFFA8A29E) : AppTheme.muted;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: dotBg,
            shape: BoxShape.circle,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Center(child: dotChild),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isCurrent || isCompleted ? FontWeight.w700 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 6. QR Code and Stable Pass Code
  // ---------------------------------------------------------------------------
  Widget _buildQrAndPassCodeSection(
    BuildContext context,
    bool isDark,
    Color primaryBurgundy,
    String status,
  ) {
    final outpassId = widget.outpass['id'] as String? ?? '';
    final canShowQr = (status == 'APPROVED' || status == 'EXITED');

    final keys = AppStateScope.of(context).deviceKeys;
    final token = (keys != null && outpassId.isNotEmpty)
        ? keys.buildToken(outpassId, _step)
        : 'v1.preview.token';

    final passCode = (widget.outpass['passCode'] ?? widget.outpass['displayId'] ?? '').toString();

    if (!canShowQr) {
      final isCancelled = status == 'CANCELLED';
      final isOverdue = status == 'OVERDUE';
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF292524)
              : (isCancelled
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFFFFBEB)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? const Color(0xFF44403C)
                : (isCancelled
                    ? AppTheme.errorRed.withValues(alpha: 0.3)
                    : AppTheme.border),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCancelled
                  ? Icons.cancel_outlined
                  : (isOverdue ? Icons.schedule_outlined : Icons.lock_clock_outlined),
              color: isCancelled ? AppTheme.errorRed : AppTheme.warningAmber,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isCancelled
                    ? 'QR Code Inactive: Outpass Cancelled'
                    : (status == 'PENDING_TUTOR' || status == 'PENDING_TUTOR_APPROVAL' || status == 'PENDING'
                        ? 'QR Code Locked: Awaiting Tutor Approval'
                        : (status == 'PENDING_HOD' || status == 'PENDING_HOD_APPROVAL'
                            ? 'QR Code Locked: Tutor Approved — Awaiting HOD Approval'
                            : (isOverdue
                                ? (widget.outpass['exitAt'] != null ? 'Pass Overdue: Campus Return Pending' : 'Pass Overdue: Campus Exit Window Passed')
                                : 'Pass Status: $status'))),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isCancelled ? AppTheme.errorRed : AppTheme.warningAmber,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Countdown refresh indicator scoped to AnimatedBuilder
        _CountdownRefreshIndicator(
          animation: _countdownController,
          isDark: isDark,
          primaryBurgundy: primaryBurgundy,
          step: _step,
        ),
        const SizedBox(height: 10),

        // QR Code optical scanner container wrapped in RepaintBoundary
        RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white, // Pure white background for optical scanning
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: QrImageView(
              data: token,
              size: 190,
              version: QrVersions.auto,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF000000), // QR stays pure black on white
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF000000),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'PRESENT TO GATE SECURITY FOR SCANNING',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? const Color(0xFFFAF6F0) : AppTheme.charcoal,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Stable pass code beneath QR
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF292524) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF44403C) : AppTheme.border,
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'PASS CODE: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: isDark ? const Color(0xFFA8A29E) : AppTheme.muted,
                ),
              ),
              Text(
                passCode.isNotEmpty ? passCode : '------',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                  color: AppTheme.burgundy,
                ),
              ),
              if (passCode.isNotEmpty) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.copy, size: 15),
                  tooltip: 'Copy Pass Code',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: passCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Pass code $passCode copied for gate security entry.'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Action Buttons: "Download Pass", "Share", "Replay", and "Cancel Outpass"
  // ---------------------------------------------------------------------------
  Widget _buildActionButtons(BuildContext context, bool isDark) {
    final status = (widget.outpass['status'] as String? ?? 'PENDING_TUTOR').toUpperCase();
    final exitAt = widget.outpass['exitAt'];
    final isOverdue = status == 'OVERDUE';
    final hasExited = exitAt != null || status == 'EXITED' || status == 'RETURNED';
    final cancellableStatuses = [
      'PENDING',
      'PENDING_TUTOR',
      'PENDING_TUTOR_APPROVAL',
      'PENDING_HOD',
      'PENDING_HOD_APPROVAL',
      'APPROVED',
      'OVERDUE',
      'EXPIRED',
    ];
    // Cancel allowed if OVERDUE, OR if not yet exited
    final isCancellable = (isOverdue || !hasExited) &&
        cancellableStatuses.contains(status) &&
        status != 'CANCELLED' &&
        status != 'RETURNED' &&
        status != 'REJECTED';

    return Container(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _handlePrintPass(context),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Download Pass', style: TextStyle(fontSize: 12)),
              ),
              OutlinedButton.icon(
                onPressed: () => _copyPassSummary(context),
                icon: const Icon(Icons.share_outlined, size: 16),
                label: const Text('Share', style: TextStyle(fontSize: 12)),
              ),
              if (widget.animatePrint)
                OutlinedButton.icon(
                  onPressed: () {
                    _countdownController.stop();
                    _revealKey.currentState?.replay();
                  },
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: const Text('Replay', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Cancel Outpass Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: isCancellable ? AppTheme.errorRed : AppTheme.muted,
              side: BorderSide(
                color: isCancellable ? AppTheme.errorRed.withValues(alpha: 0.6) : AppTheme.border,
                width: 1.2,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: isCancellable
                ? (widget.onCancel ?? () => _showCancelDialog(context))
                : null,
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: Text(
              isCancellable
                  ? 'Cancel Outpass'
                  : (status == 'CANCELLED'
                      ? 'Outpass Cancelled'
                      : (status == 'RETURNED'
                          ? 'Cannot Cancel (Already Returned)'
                          : (hasExited
                              ? 'Cannot Cancel (Exit Recorded)'
                              : 'Cannot Cancel ($status)'))),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCancelDialog(BuildContext context) async {
    final reasonController = TextEditingController();
    bool busy = false;
    final outpassId = widget.outpass['id']?.toString() ?? '';
    final displayId = widget.outpass['displayId']?.toString() ?? outpassId;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> handleConfirm() async {
            if (busy) return;
            setDialogState(() => busy = true);
            try {
              final state = AppStateScope.of(context);
              await state.api.cancelOutpass(outpassId, reason: reasonController.text.trim());
              if (ctx.mounted) Navigator.of(ctx).pop();
              widget.onStatusChanged?.call();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Outpass cancelled successfully'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
              }
            } catch (e) {
              setDialogState(() => busy = false);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(AsyncActionHelper.extractErrorMessage(e)),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
              }
            }
          }

          return CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(ctx).pop(),
              const SingleActivator(LogicalKeyboardKey.enter): () => handleConfirm(),
            },
            child: AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed),
                  const SizedBox(width: 8),
                  const Text('Cancel Outpass Request'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to cancel pass #$displayId? This action will immediately invalidate the dynamic QR code and pass token.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: reasonController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => handleConfirm(),
                    decoration: const InputDecoration(
                      labelText: 'Reason for cancellation (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Keep Pass'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
                  onPressed: busy ? null : handleConfirm,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirm Cancel'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Widget _buildStatusBadge(String status) {
    final bg = AppTheme.statusColor(status);
    final icon = AppTheme.statusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: bg),
          const SizedBox(width: 4),
          Text(
            status.replaceAll('_', ' '),
            style: TextStyle(
              color: bg,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic dateStr) {
    if (dateStr == null) return '—';
    try {
      final dt = DateTime.parse(dateStr.toString()).toUtc().add(const Duration(hours: 5, minutes: 30));
      return '${DateFormat('hh:mm a, dd MMM').format(dt)} IST';
    } catch (_) {
      return dateStr.toString();
    }
  }

  void _handlePrintPass(BuildContext context) {
    final keys = AppStateScope.of(context).deviceKeys;
    final outpassId = widget.outpass['id'] as String? ?? '';
    final token = (keys != null && outpassId.isNotEmpty)
        ? keys.buildToken(outpassId, _step)
        : 'v1.preview.token';
    final html = TicketHtmlGenerator.generate(widget.outpass, qrToken: token);

    if (kIsWeb) {
      triggerPrint(html: html);
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(ctx).pop(),
          },
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: SingleChildScrollView(
                    child: TicketOutpass(
                      outpass: widget.outpass,
                      enableTilt: false,
                      showStub: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _copyPassSummary(BuildContext context) {
    final o = widget.outpass;
    final s = o['student'] as Map?;
    final summary = StringBuffer();
    summary.writeln('====================================');
    summary.writeln('CHRIST COLLEGE OF ENGINEERING, IRINJALAKUDA');
    summary.writeln('OFFICIAL DIGITAL OUTPASS RECEIPT');
    summary.writeln('====================================');
    summary.writeln('Pass ID: ${o['displayId'] ?? o['id']}');
    summary.writeln('Status: ${o['status']}');
    summary.writeln('Type: ${o['type'] ?? 'NORMAL'}');
    if (s != null) {
      summary.writeln('Student: ${s['name']} (${s['registerNo']})');
      summary.writeln('Dept: ${s['department']}');
    }
    summary.writeln('Destination: ${o['destination']}');
    summary.writeln('Purpose: ${o['purposeCategory']}');
    summary.writeln('Exit Time: ${_formatDateTime(o['requestedExitAt'])}');
    summary.writeln('Expected Return: ${_formatDateTime(o['expectedReturnAt'])}');
    summary.writeln('====================================');
    summary.writeln('Verify live status with security gate terminal.');

    Clipboard.setData(ClipboardData(text: summary.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pass summary copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPerforationDivider(bool isDark) {
    return _PerforationDivider(isDark: isDark);
  }
}

/// Perforation tear line with left & right circular ticket notches (Polish 6).
class _PerforationDivider extends StatelessWidget {
  const _PerforationDivider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 16,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C0A09) : AppTheme.appBackground,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const dashWidth = 5.0;
              const dashSpace = 4.0;
              final dashCount = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(dashCount, (_) {
                  return SizedBox(
                    width: dashWidth,
                    height: 1.5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF44403C) : const Color(0xFFD6CEC5),
                        borderRadius: BorderRadius.circular(0.75),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        Container(
          width: 8,
          height: 16,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C0A09) : AppTheme.appBackground,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
          ),
        ),
      ],
    );
  }
}

/// Dynamic token refresh countdown indicator scoped to AnimatedBuilder.
class _CountdownRefreshIndicator extends StatelessWidget {
  const _CountdownRefreshIndicator({
    required this.animation,
    required this.isDark,
    required this.primaryBurgundy,
    required this.step,
  });

  final Animation<double> animation;
  final bool isDark;
  final Color primaryBurgundy;
  final int step;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final secsLeft = ((step + 30) - nowSec).clamp(0, 30);
        final progress = secsLeft / 30.0;

        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  backgroundColor: isDark ? Colors.white12 : AppTheme.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    secsLeft > 5 ? primaryBurgundy : AppTheme.errorRed,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Dynamic token refresh in ${secsLeft}s',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: secsLeft > 5
                      ? (isDark ? const Color(0xFFFAF6F0) : AppTheme.charcoal)
                      : AppTheme.errorRed,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Official APPROVED rubber stamp badge with tilt & border (Polish 9).
class _ApprovedStampWidget extends StatelessWidget {
  const _ApprovedStampWidget();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.21, // ~ -12 degrees
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppTheme.successGreen,
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              '★ APPROVED ★',
              style: TextStyle(
                color: AppTheme.successGreen,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.2,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              'CCE OUTPASS SYSTEM',
              style: TextStyle(
                color: AppTheme.successGreen,
                fontWeight: FontWeight.w700,
                fontSize: 7.0,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
