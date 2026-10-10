import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../qr_token.dart';
import '../util/platform_print.dart';

/// Modern Academic Ticket Outpass
///
/// Designed with:
/// - Institutional Christ College of Engineering branding
/// - Perforated ticket aesthetic with detachable gate stub and side cutouts
/// - Authorized approval signatures & backend-driven verification timeline
/// - Live cryptographic ECDSA dynamic QR code (re-keys every 30s)
/// - Subtle 3D tilt interaction for desktop/web (with static fallback)
/// - Functional clean printing & summary export
class TicketOutpass extends StatefulWidget {
  const TicketOutpass({
    super.key,
    required this.outpass,
    this.showStub = true,
    this.enableTilt = true,
    this.onStatusChanged,
  });

  final Map<String, dynamic> outpass;
  final bool showStub;
  final bool enableTilt;
  final VoidCallback? onStatusChanged;

  @override
  State<TicketOutpass> createState() => _TicketOutpassState();
}

class _TicketOutpassState extends State<TicketOutpass> with SingleTickerProviderStateMixin {
  // 3D Tilt state
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  bool _isHovering = false;
  bool _staticMode = false;

  // QR Rotating Step
  int _step = DeviceKeys.currentStep();
  late final AnimationController _countdownController;

  @override
  void initState() {
    super.initState();
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _syncStepAndTimer();
  }

  void _syncStepAndTimer() {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _step = (nowSec ~/ 30) * 30;
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
    if (_staticMode || !widget.enableTilt || (kIsWeb == false && defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.macOS && defaultTargetPlatform != TargetPlatform.linux)) {
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

    // Outer ticket styling
    final ticketBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFFCFBF7);
    final ticketBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E0D8);
    final primaryNavy = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A);
    final mutedTeal = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);

    final transform = (_staticMode || reduceMotion || !widget.enableTilt || !_isHovering)
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateX(_tiltX)
          ..rotateY(_tiltY));

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(constraints.maxWidth, 460.0);

        return Center(
          child: MouseRegion(
            onHover: (e) => _onHover(e, Size(cardWidth, 800)),
            onExit: _onExit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: transform,
              transformAlignment: FractionalOffset.center,
              width: cardWidth,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.45)
                        : const Color(0xFF0F172A).withValues(alpha: 0.10),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipPath(
                clipper: _TicketPerforatedClipper(notchRadius: 14.0),
                child: CustomPaint(
                  painter: _TicketPerforatedBorderPainter(
                    borderColor: ticketBorder,
                    notchRadius: 14.0,
                    isDark: isDark,
                  ),
                  child: Container(
                    color: ticketBg,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Institutional College Branding Header
                        _buildInstitutionalHeader(isDark, primaryNavy, mutedTeal),

                        // 2. Student Identity & Pass Details Body
                        _buildPassBody(context, isDark, primaryNavy, mutedTeal),

                        // 3. Backend Verification Timeline & Approvals
                        _buildApprovalLedger(context, isDark, primaryNavy, mutedTeal),

                        // 4. Perforation Divider & Detachable Gate Stub
                        if (widget.showStub) ...[
                          _buildPerforationDivider(isDark, ticketBorder),
                          _buildGateStub(context, isDark, primaryNavy, mutedTeal),
                        ],

                        // 5. Utility Actions (Print / Copy / Tilt Toggle)
                        _buildTicketActions(context, isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Institutional College Branding Header
  // ---------------------------------------------------------------------------
  Widget _buildInstitutionalHeader(bool isDark, Color primaryNavy, Color mutedTeal) {
    final status = (widget.outpass['status'] as String? ?? 'PENDING_TUTOR').toUpperCase();
    final displayId = widget.outpass['displayId'] ?? widget.outpass['id'] ?? 'OP-PENDING';
    final type = widget.outpass['type'] ?? 'NORMAL';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E3A8A),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFF172554),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Institutional Crest Badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // College Title & Autonomous Accreditation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CHRIST COLLEGE OF ENGINEERING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'IRINJALAKUDA, THRISSUR · AUTONOMOUS',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.80),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Type Tag (NORMAL / EMERGENCY)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: type == 'EMERGENCY'
                      ? const Color(0xFFDC2626)
                      : Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type == 'EMERGENCY' ? 'EMERGENCY' : 'STANDARD',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Sub-bar with Pass Identifier & Official Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.confirmation_number_outlined, color: Colors.white70, size: 15),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$displayId',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Student Identity & Pass Details Body
  // ---------------------------------------------------------------------------
  Widget _buildPassBody(BuildContext context, bool isDark, Color primaryNavy, Color mutedTeal) {
    final state = AppStateScope.of(context);
    final student = widget.outpass['student'] as Map<String, dynamic>?;

    final studentName = student?['name'] ?? state.userName ?? 'Authorized Student';
    final regNo = student?['registerNo'] ?? 'REG-RECORD';
    final dept = student?['department'] ?? state.userDepartment ?? 'General Engineering';
    final sem = student?['semester'];
    final year = student?['year'] ?? state.userYear;
    final div = student?['division'] ?? state.userDivision;
    final tutorName = student?['tutorName'] ?? widget.outpass['tutorName'];

    final academicInfo = StringBuffer(dept);
    if (year != null) academicInfo.write(' · Year $year');
    if (sem != null && year == null) academicInfo.write(' · Sem $sem');
    if (div != null && div.toString().isNotEmpty) academicInfo.write(' · Div $div');

    final destination = widget.outpass['destination'] ?? 'Not specified';
    final purposeCategory = widget.outpass['purposeCategory'] ?? 'General';
    final purposeText = widget.outpass['purposeText'] as String?;

    final exitTime = _formatDateTime(widget.outpass['exitAt'] ?? widget.outpass['requestedExitAt']);
    final returnTime = _formatDateTime(widget.outpass['entryAt'] ?? widget.outpass['expectedReturnAt']);

    final textColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Info Block
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: primaryNavy.withValues(alpha: 0.12),
                child: Text(
                  studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryNavy,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            regNo,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: labelColor,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        if (tutorName != null) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Tutor: $tutorName',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: labelColor),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      academicInfo.toString(),
                      style: TextStyle(fontSize: 11.5, color: labelColor),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 14),

          // Schedule Details (Departure & Expected Return)
          Row(
            children: [
              Expanded(
                child: _buildDetailTile(
                  title: 'DEPARTURE (EXIT)',
                  value: exitTime,
                  icon: Icons.logout_rounded,
                  accentColor: const Color(0xFF0284C7),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDetailTile(
                  title: 'EXPECTED RETURN',
                  value: returnTime,
                  icon: Icons.login_rounded,
                  accentColor: mutedTeal,
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Trip Destination & Reason
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: primaryNavy),
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
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: mutedTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        purposeCategory,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: mutedTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                if (purposeText != null && purposeText.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    purposeText.trim(),
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: labelColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Backend Verification Timeline & Approvals Ledger
  // ---------------------------------------------------------------------------
  Widget _buildApprovalLedger(BuildContext context, bool isDark, Color primaryNavy, Color mutedTeal) {
    final status = (widget.outpass['status'] as String? ?? 'PENDING_TUTOR').toUpperCase();
    final approvals = (widget.outpass['approvals'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    Map<String, dynamic>? tutorAppr;
    Map<String, dynamic>? hodAppr;

    for (final a in approvals) {
      final stage = (a['stage'] as String? ?? '').toUpperCase();
      if (stage.contains('TUTOR')) tutorAppr = a;
      if (stage.contains('HOD')) hodAppr = a;
    }

    final isTutorDone = tutorAppr != null && tutorAppr['decision'] == 'APPROVED';
    final isHodDone = (hodAppr != null && hodAppr['decision'] == 'APPROVED') ||
        status == 'APPROVED' ||
        status == 'EXITED' ||
        status == 'RETURNED';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 14, color: mutedTeal),
              const SizedBox(width: 5),
              Text(
                'OFFICIAL AUTHORIZATION AUDIT',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Stepper row showing progress
          Row(
            children: [
              _buildTimelineStep(
                label: 'Requested',
                isCompleted: true,
                isDark: isDark,
                activeColor: mutedTeal,
              ),
              _buildTimelineConnector(isCompleted: isTutorDone, isDark: isDark, activeColor: mutedTeal),
              _buildTimelineStep(
                label: 'Tutor',
                isCompleted: isTutorDone,
                isPending: status == 'PENDING_TUTOR',
                isDark: isDark,
                activeColor: mutedTeal,
              ),
              _buildTimelineConnector(isCompleted: isHodDone, isDark: isDark, activeColor: mutedTeal),
              _buildTimelineStep(
                label: 'HOD',
                isCompleted: isHodDone,
                isPending: status == 'PENDING_HOD',
                isDark: isDark,
                activeColor: mutedTeal,
              ),
              _buildTimelineConnector(
                isCompleted: status == 'EXITED' || status == 'RETURNED',
                isDark: isDark,
                activeColor: mutedTeal,
              ),
              _buildTimelineStep(
                label: 'Gate Clear',
                isCompleted: status == 'EXITED' || status == 'RETURNED',
                isDark: isDark,
                activeColor: mutedTeal,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Sign-off Ledger Details
          Row(
            children: [
              Expanded(
                child: _buildApproverSignBlock(
                  role: 'Assigned Tutor',
                  approval: tutorAppr,
                  fallbackStatus: isTutorDone ? 'Approved' : (status == 'PENDING_TUTOR' ? 'Reviewing' : 'Awaiting'),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildApproverSignBlock(
                  role: 'Head of Dept (HOD)',
                  approval: hodAppr,
                  fallbackStatus: isHodDone ? 'Approved' : (status == 'PENDING_HOD' ? 'Reviewing' : 'Pending Stage'),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Perforation Divider & Detachable Gate Stub
  // ---------------------------------------------------------------------------
  Widget _buildPerforationDivider(bool isDark, Color ticketBorder) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: List.generate(
              32,
              (index) => Expanded(
                child: Container(
                  height: 1.5,
                  color: index.isEven
                      ? (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
                      : Colors.transparent,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFCFBF7),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.content_cut,
                  size: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  'DETACHABLE GATE SCAN STUB',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGateStub(BuildContext context, bool isDark, Color primaryNavy, Color mutedTeal) {
    final status = (widget.outpass['status'] as String? ?? 'PENDING_TUTOR').toUpperCase();
    final outpassId = widget.outpass['id'] as String? ?? '';
    final canShowQr = (status == 'APPROVED' || status == 'EXITED');

    final keys = AppStateScope.of(context).deviceKeys;
    final token = (keys != null && outpassId.isNotEmpty)
        ? keys.buildToken(outpassId, _step)
        : 'v1.preview.token';

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final secsLeft = ((_step + 30) - nowSec).clamp(0, 30);
    final progress = secsLeft / 30.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        children: [
          if (canShowQr) ...[
            // Rotating Countdown Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      secsLeft > 5 ? mutedTeal : const Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Dynamic token refresh in ${secsLeft}s',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: secsLeft > 5
                        ? (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155))
                        : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Genuine QR Code Container (Strictly flat, sharp, unobstructed for scanner)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white, // Always pure white background for optical contrast
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: QrImageView(
                data: token,
                size: 210,
                version: QrVersions.auto,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0F172A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'PRESENT TO GATE SECURITY FOR SCANNING',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ECDSA P-256 rotating token. Server verified at College Gate.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),

            // Quick Copy Token for Manual Guard Entry
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: token));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cryptographic token copied for security guard manual entry.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('Copy Token for Guard Manual Entry', style: TextStyle(fontSize: 11.5)),
            ),
          ] else ...[
            // Status when QR is not yet active
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFFDE68A),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock_clock_outlined, color: Color(0xFFD97706), size: 32),
                  const SizedBox(height: 8),
                  Text(
                    status == 'PENDING_TUTOR'
                        ? 'QR Code Locked: Awaiting Tutor Approval'
                        : (status == 'PENDING_HOD'
                            ? 'QR Code Locked: Awaiting HOD Approval'
                            : 'QR Pass Inactive: $status'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'The dynamic gate QR code activates automatically once authorized by college leadership.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          // Security disclaimer
          Text(
            'NOTICE: This visual ticket alone does NOT constitute valid gate authorization. Validity is strictly enforced at the gate terminal via cryptographic token verification against the CCE backend.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8.5,
              height: 1.3,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Utility Actions (Print / Copy / Tilt Toggle)
  // ---------------------------------------------------------------------------
  Widget _buildTicketActions(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          // Print / Save Pass
          TextButton.icon(
            onPressed: () => _handlePrintPass(context),
            icon: const Icon(Icons.print_outlined, size: 16),
            label: const Text('Print Pass', style: TextStyle(fontSize: 12)),
          ),
          // Copy Pass Summary
          TextButton.icon(
            onPressed: () => _copyPassSummary(context),
            icon: const Icon(Icons.share_outlined, size: 16),
            label: const Text('Share Summary', style: TextStyle(fontSize: 12)),
          ),
          // Toggle 3D Tilt / Flat Mode
          if (widget.enableTilt)
            TextButton.icon(
              onPressed: () => setState(() => _staticMode = !_staticMode),
              icon: Icon(
                _staticMode ? Icons.layers_clear_outlined : Icons.layers_outlined,
                size: 16,
              ),
              label: Text(
                _staticMode ? 'Enable Tilt' : 'Static Flat',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'APPROVED':
        bg = const Color(0xFF047857);
        fg = Colors.white;
        label = 'APPROVED';
        break;
      case 'PENDING_TUTOR':
        bg = const Color(0xFFD97706);
        fg = Colors.white;
        label = 'PENDING TUTOR';
        break;
      case 'PENDING_HOD':
        bg = const Color(0xFFB45309);
        fg = Colors.white;
        label = 'PENDING HOD';
        break;
      case 'EXITED':
        bg = const Color(0xFF1D4ED8);
        fg = Colors.white;
        label = 'EXITED';
        break;
      case 'RETURNED':
        bg = const Color(0xFF4338CA);
        fg = Colors.white;
        label = 'RETURNED';
        break;
      case 'REJECTED':
        bg = const Color(0xFFB91C1C);
        fg = Colors.white;
        label = 'REJECTED';
        break;
      case 'CANCELLED':
        bg = const Color(0xFF475569);
        fg = Colors.white;
        label = 'CANCELLED';
        break;
      default:
        bg = const Color(0xFF64748B);
        fg = Colors.white;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDetailTile({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String label,
    required bool isCompleted,
    bool isPending = false,
    required bool isDark,
    required Color activeColor,
  }) {
    final color = isCompleted
        ? activeColor
        : (isPending ? const Color(0xFFD97706) : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)));

    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: isCompleted ? activeColor : (isPending ? const Color(0xFFD97706) : Colors.transparent),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: isCompleted
              ? const Center(child: Icon(Icons.check, size: 9, color: Colors.white))
              : null,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: isCompleted || isPending ? FontWeight.w700 : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineConnector({
    required bool isCompleted,
    required bool isDark,
    required Color activeColor,
  }) {
    return Expanded(
      child: Container(
        height: 2,
        color: isCompleted
            ? activeColor
            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildApproverSignBlock({
    required String role,
    required Map<String, dynamic>? approval,
    required String fallbackStatus,
    required bool isDark,
  }) {
    final decision = approval?['decision'] as String?;
    final decidedAt = approval?['decidedAt'] as String?;
    final comment = approval?['comment'] as String?;

    final isApproved = decision == 'APPROVED';
    final isRejected = decision == 'REJECTED';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isApproved
                    ? Icons.check_circle_outline
                    : (isRejected ? Icons.cancel_outlined : Icons.schedule_outlined),
                size: 13,
                color: isApproved
                    ? const Color(0xFF047857)
                    : (isRejected ? const Color(0xFFB91C1C) : const Color(0xFFD97706)),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  role,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            decision != null ? '$decision · ${_formatShortDate(decidedAt)}' : fallbackStatus,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: isApproved
                  ? const Color(0xFF047857)
                  : (isRejected ? const Color(0xFFB91C1C) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ),
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '"$comment"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontStyle: FontStyle.italic,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(dynamic dateStr) {
    if (dateStr == null) return '—';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('hh:mm a, dd MMM').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  String _formatShortDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('dd/MM hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  void _handlePrintPass(BuildContext context) {
    if (kIsWeb) {
      triggerPrint();
    } else {
      // Show clean Printable Preview dialog on mobile
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
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
        content: Text('Outpass summary copied to clipboard.'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Ticket Custom Clipper with Semicircular Perforation Notches
// -----------------------------------------------------------------------------
class _TicketPerforatedClipper extends CustomClipper<Path> {
  _TicketPerforatedClipper({this.notchRadius = 14.0});
  final double notchRadius;

  @override
  Path getClip(Size size) {
    const cornerRadius = 14.0;
    final path = Path();
    final w = size.width;
    final h = size.height;

    final notchY = h * 0.65;

    // Start at top-left after corner
    path.moveTo(cornerRadius, 0);
    // Top edge
    path.lineTo(w - cornerRadius, 0);
    path.quadraticBezierTo(w, 0, w, cornerRadius);

    // Right edge down to notch
    path.lineTo(w, notchY - notchRadius);
    // Semicircular bite on right edge
    path.arcToPoint(
      Offset(w, notchY + notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    // Right edge to bottom corner
    path.lineTo(w, h - cornerRadius);
    path.quadraticBezierTo(w, h, w - cornerRadius, h);

    // Bottom edge
    path.lineTo(cornerRadius, h);
    path.quadraticBezierTo(0, h, 0, h - cornerRadius);

    // Left edge up to notch
    path.lineTo(0, notchY + notchRadius);
    // Semicircular bite on left edge
    path.arcToPoint(
      Offset(0, notchY - notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    // Left edge to top corner
    path.lineTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(_TicketPerforatedClipper oldClipper) =>
      oldClipper.notchRadius != notchRadius;
}

// -----------------------------------------------------------------------------
// Border Painter matching the Perforated Ticket Path
// -----------------------------------------------------------------------------
class _TicketPerforatedBorderPainter extends CustomPainter {
  _TicketPerforatedBorderPainter({
    required this.borderColor,
    this.notchRadius = 14.0,
    required this.isDark,
  });

  final Color borderColor;
  final double notchRadius;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    const cornerRadius = 14.0;
    final w = size.width;
    final h = size.height;
    final notchY = h * 0.65;

    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    path.moveTo(cornerRadius, 0);
    path.lineTo(w - cornerRadius, 0);
    path.quadraticBezierTo(w, 0, w, cornerRadius);
    path.lineTo(w, notchY - notchRadius);
    path.arcToPoint(
      Offset(w, notchY + notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(w, h - cornerRadius);
    path.quadraticBezierTo(w, h, w - cornerRadius, h);
    path.lineTo(cornerRadius, h);
    path.quadraticBezierTo(0, h, 0, h - cornerRadius);
    path.lineTo(0, notchY + notchRadius);
    path.arcToPoint(
      Offset(0, notchY - notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TicketPerforatedBorderPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor || oldDelegate.isDark != isDark;
}
