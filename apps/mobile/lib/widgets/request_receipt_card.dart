import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../theme/app_theme.dart';
import 'printed_receipt_reveal.dart';

/// Request Receipt emerging from the thermal printer upon successful request submission.
///
/// Contains:
/// - Request reference number
/// - Student name
/// - Roll number / register number
/// - Requested departure time
/// - Expected return time
/// - Submission timestamp
/// - Status: PENDING TUTOR APPROVAL
/// - Prominently indicates NOT AN APPROVED GATE PASS
/// - Contains NO usable QR credential
/// - Action button to view submitted request
class RequestReceiptCard extends StatelessWidget {
  const RequestReceiptCard({
    super.key,
    required this.outpass,
    this.onViewRequest,
  });

  final Map<String, dynamic> outpass;
  final VoidCallback? onViewRequest;

  String _formatDateTime(dynamic dtVal) {
    if (dtVal == null) return '-';
    try {
      final dt = dtVal is DateTime ? dtVal : DateTime.parse(dtVal.toString());
      return '${DateFormat('dd MMM yyyy, hh:mm a').format(dt)} IST';
    } catch (_) {
      return dtVal.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appState = AppStateScope.of(context);

    final rawDisplayId = outpass['displayId'] ?? outpass['id'] ?? 'OP-PENDING';
    final displayId = rawDisplayId.toString();

    // Student info resolution
    final studentMap = outpass['student'] as Map? ?? {};
    final studentName = outpass['studentName'] ??
        studentMap['name'] ??
        appState.userName ??
        'Student';
    final regNo = studentMap['registerNo'] ??
        outpass['regNo'] ??
        '-';
    final dept = outpass['department'] ??
        studentMap['department'] ??
        appState.userDepartment ??
        'CSE';
    final year = outpass['year'] ?? studentMap['year'] ?? appState.userYear;
    final div = outpass['division'] ?? studentMap['division'] ?? appState.userDivision;

    final exitTime = _formatDateTime(outpass['requestedExitAt']);
    final returnTime = _formatDateTime(outpass['expectedReturnAt']);
    final submittedTime = _formatDateTime(outpass['createdAt'] ?? DateTime.now());

    final destination = (outpass['destination'] ?? 'Not specified').toString();
    final purposeCat = (outpass['purposeCategory'] ?? outpass['purpose'] ?? 'General').toString();
    final purposeText = (outpass['purposeText'] ?? '').toString();

    final ticketBg = isDark ? const Color(0xFF1C1917) : AppTheme.cream;
    final ticketBorder = isDark ? const Color(0xFF292524) : AppTheme.border;
    final textColor = isDark ? const Color(0xFFFAF6F0) : AppTheme.charcoal;
    final labelColor = isDark ? const Color(0xFFA8A29E) : AppTheme.muted;

    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      decoration: BoxDecoration(
        color: ticketBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ticketBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Monospace Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF292524) : const Color(0xFFF0EBE1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
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
                    'CCE OUTPASS - REQUEST RECEIPT - #$displayId',
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
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Pill: PENDING TUTOR APPROVAL
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade400, width: 1.2),
                  ),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hourglass_top, size: 18, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Text(
                              'STATUS: PENDING TUTOR APPROVAL',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.amber.shade900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'NOT AN APPROVED GATE PASS · EXIT PROHIBITED',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.red.shade900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'This document confirms submission of your outpass request. You may not exit campus until Tutor and HOD approve your request.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.brown.shade800,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Student Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.studentAccent.withValues(alpha: 0.15),
                      child: const Icon(Icons.person, color: AppTheme.studentAccent, size: 22),
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
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Roll / Reg: $regNo · Dept: $dept${year != null ? ' · Year $year' : ''}${div != null ? ' ($div)' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: labelColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Timings Section
                _buildReceiptRow('Requested Departure', exitTime, textColor, labelColor, Icons.login),
                const SizedBox(height: 8),
                _buildReceiptRow('Expected Return', returnTime, textColor, labelColor, Icons.logout),
                const SizedBox(height: 8),
                _buildReceiptRow('Submission Time', submittedTime, textColor, labelColor, Icons.access_time),

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Destination & Purpose
                _buildReceiptRow('Destination', destination, textColor, labelColor, Icons.place_outlined),
                const SizedBox(height: 8),
                _buildReceiptRow('Purpose Category', purposeCat, textColor, labelColor, Icons.category_outlined),
                if (purposeText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildReceiptRow('Purpose Details', purposeText, textColor, labelColor, Icons.notes),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Locked QR section (strictly NO QR code issued)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF292524) : Colors.amber.shade50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF44403C) : Colors.amber.shade300,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.lock_clock_outlined, size: 24, color: Colors.amber.shade900),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GATE PASS QR LOCKED',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Valid gate pass QR credentials are only generated after both Tutor and HOD grant approval.',
                              style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Action button: View Submitted Request
                if (onViewRequest != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.studentAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onViewRequest,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text(
                        'View Submitted Request',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Barcode Watermark
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF292524) : const Color(0xFFF0EBE1),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'CHRIST COLLEGE OF ENGINEERING',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: labelColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'REF #$displayId',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value,
    Color textColor,
    Color labelColor,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: labelColor),
        const SizedBox(width: 8),
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}


/// Full screen view presenting the POS-80 thermal printer feeding out the submission receipt.
class RequestReceiptScreen extends StatelessWidget {
  const RequestReceiptScreen({
    super.key,
    required this.outpass,
    this.onViewRequest,
  });

  final Map<String, dynamic> outpass;
  final VoidCallback? onViewRequest;

  @override
  Widget build(BuildContext context) {
    final rawId = (outpass['id'] ?? outpass['displayId'] ?? outpass['outpassNumber'])?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Receipt'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close receipt',
          onPressed: () {
            if (onViewRequest != null) {
              onViewRequest!();
            } else {
              Navigator.of(context).pop(true);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: PrintedReceiptReveal(
              key: const Key('submission_printer_reveal'),
              outpassId: rawId,
              printEventId: rawId != null ? PrintedReceiptReveal.receiptEventKey(rawId) : null,
              status: outpass['status']?.toString() ?? 'PENDING_TUTOR',
              printerLabel: 'CCE THERMAL POS-80',
              initialPrint: true,
              child: RequestReceiptCard(
                outpass: outpass,
                onViewRequest: () {
                  if (onViewRequest != null) {
                    onViewRequest!();
                  } else {
                    Navigator.of(context).pop(true);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
