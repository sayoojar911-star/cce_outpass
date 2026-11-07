import 'package:intl/intl.dart';
import 'package:qr/qr.dart';

/// Generates a standalone, clean, print-optimized HTML ticket for CCE Outpass.
/// Suitable for printing or saving to PDF via the browser's native print engine
/// without any application chrome, navigation bars, or buttons.
class TicketHtmlGenerator {
  static String generate(Map<String, dynamic> outpass, {String? qrToken}) {
    final displayId = outpass['displayId'] ?? outpass['id'] ?? 'CCE-OP-OFFICIAL';
    final type = (outpass['type'] ?? 'STANDARD').toString().toUpperCase();
    final status = (outpass['status'] ?? 'PENDING').toString().toUpperCase();

    final student = outpass['student'] as Map<String, dynamic>?;
    final studentName = student?['name'] ?? 'Authorized Student';
    final regNo = student?['registerNo'] ?? '—';
    final dept = student?['department'] ?? 'General Engineering';
    final year = student?['year'];
    final sem = student?['semester'];
    final div = student?['division'];
    final tutorName = student?['tutorName'] ?? outpass['tutorName'] ?? '—';

    final academicInfo = StringBuffer(dept);
    if (year != null) academicInfo.write(' · Year $year');
    if (sem != null && year == null) academicInfo.write(' · Sem $sem');
    if (div != null && div.toString().isNotEmpty) academicInfo.write(' · Div $div');

    final destination = outpass['destination'] ?? 'Not specified';
    final purposeCategory = outpass['purposeCategory'] ?? 'General';
    final purposeText = outpass['purposeText'] as String?;

    final exitTime = _formatDateTime(outpass['exitAt'] ?? outpass['requestedExitAt']);
    final returnTime = _formatDateTime(outpass['entryAt'] ?? outpass['expectedReturnAt']);

    final approvals = (outpass['approvals'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    Map<String, dynamic>? tutorAppr;
    Map<String, dynamic>? hodAppr;
    for (final a in approvals) {
      final stage = (a['stage'] as String? ?? '').toUpperCase();
      if (stage.contains('TUTOR')) tutorAppr = a;
      if (stage.contains('HOD')) hodAppr = a;
    }

    final qrSvg = (qrToken != null && qrToken.isNotEmpty && (status == 'APPROVED' || status == 'EXITED'))
        ? _generateQrSvg(qrToken, size: 160)
        : '';

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>CCE Outpass - $displayId</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 15mm 20mm;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      color: #0f172a;
      background: #ffffff;
      line-height: 1.4;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .ticket-wrapper {
      max-width: 580px;
      margin: 0 auto;
      border: 1.5px solid #702632;
      border-radius: 12px;
      overflow: hidden;
      background: #FAF6F0;
    }
    .header {
      background: #702632;
      color: #FAF6F0;
      padding: 16px 20px;
      text-align: center;
    }
    .header h1 {
      font-size: 16px;
      font-weight: 800;
      letter-spacing: 1px;
      text-transform: uppercase;
      margin-bottom: 2px;
    }
    .header p {
      font-size: 10px;
      font-weight: 600;
      letter-spacing: 0.5px;
      color: rgba(250, 246, 240, 0.85);
    }
    .sub-bar {
      background: #481C25;
      color: #FAF6F0;
      padding: 8px 20px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 12px;
      border-bottom: 1px solid #702632;
    }
    .pass-id {
      font-family: monospace;
      font-weight: 700;
      font-size: 13px;
    }
    .badge {
      display: inline-block;
      padding: 2px 8px;
      border-radius: 4px;
      font-size: 10px;
      font-weight: 800;
      letter-spacing: 0.5px;
      background: #15803D;
      color: #ffffff;
    }
    .badge.emergency {
      background: #B91C1C;
    }
    .content {
      padding: 20px;
    }
    .student-block {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 16px;
      padding-bottom: 12px;
      border-bottom: 1px solid #E7E0D8;
    }
    .student-name {
      font-size: 18px;
      font-weight: 800;
      color: #292524;
    }
    .reg-no {
      font-family: monospace;
      font-size: 12px;
      font-weight: 700;
      color: #737373;
      margin-top: 2px;
    }
    .academic-info {
      font-size: 12px;
      color: #737373;
      margin-top: 4px;
    }
    .grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-bottom: 14px;
    }
    .tile {
      background: #ffffff;
      border: 1px solid #E7E0D8;
      border-radius: 8px;
      padding: 10px 12px;
    }
    .tile-label {
      font-size: 9.5px;
      font-weight: 800;
      color: #737373;
      letter-spacing: 0.5px;
      margin-bottom: 3px;
    }
    .tile-value {
      font-size: 13px;
      font-weight: 700;
      color: #292524;
    }
    .trip-box {
      background: #FAF6F0;
      border: 1px solid #E7E0D8;
      border-radius: 8px;
      padding: 12px;
      margin-bottom: 16px;
    }
    .trip-dest {
      font-size: 14px;
      font-weight: 700;
      color: #292524;
    }
    .trip-cat {
      display: inline-block;
      background: rgba(112, 38, 50, 0.10);
      color: #702632;
      font-size: 10.5px;
      font-weight: 700;
      padding: 2px 6px;
      border-radius: 4px;
      margin-left: 6px;
    }
    .trip-note {
      font-size: 12px;
      font-style: italic;
      color: #737373;
      margin-top: 4px;
    }
    .audit-section {
      margin-top: 10px;
      margin-bottom: 16px;
    }
    .audit-title {
      font-size: 10px;
      font-weight: 800;
      letter-spacing: 0.8px;
      color: #737373;
      margin-bottom: 8px;
      text-transform: uppercase;
    }
    .audit-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px;
    }
    .audit-card {
      background: #ffffff;
      border: 1px solid #E7E0D8;
      border-radius: 6px;
      padding: 8px 10px;
      font-size: 11px;
    }
    .audit-role {
      font-weight: 700;
      color: #292524;
    }
    .audit-status {
      font-weight: 600;
      color: #15803D;
      margin-top: 2px;
      font-size: 10px;
    }
    .perforation {
      border-top: 1.5px dashed #D6CEC5;
      position: relative;
      margin: 12px 0 16px 0;
      text-align: center;
    }
    .perforation span {
      position: relative;
      top: -9px;
      background: #FAF6F0;
      padding: 0 10px;
      font-size: 9px;
      font-weight: 800;
      color: #737373;
      letter-spacing: 0.8px;
    }
    .stub {
      text-align: center;
      padding: 0 20px 20px 20px;
    }
    .qr-container {
      display: inline-block;
      background: #ffffff;
      padding: 10px;
      border: 1px solid #E7E0D8;
      border-radius: 8px;
      margin-bottom: 8px;
    }
    .stub-notice {
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 0.6px;
      color: #292524;
    }
    .stub-crypto {
      font-size: 9.5px;
      color: #737373;
      margin-top: 2px;
    }
    .token-text {
      font-family: monospace;
      font-size: 8.5px;
      color: #292524;
      background: #F7F6F3;
      padding: 3px 6px;
      border-radius: 4px;
      margin-top: 6px;
      word-break: break-all;
    }
    .disclaimer {
      font-size: 8px;
      color: #737373;
      text-align: center;
      padding: 10px 20px;
      border-top: 1px solid #E7E0D8;
      background: #F7F6F3;
    }
  </style>
</head>
<body>
  <div class="ticket-wrapper">
    <div class="header">
      <h1>Christ College of Engineering</h1>
      <p>Irinjalakuda, Thrissur · Autonomous · Affiliated to APJ AKTU</p>
    </div>
    <div class="sub-bar">
      <div>
        <span class="pass-id">$displayId</span>
        <span style="margin-left: 8px; font-size: 10px; opacity: 0.85;">($type)</span>
      </div>
      <div class="badge ${type == 'EMERGENCY' ? 'emergency' : ''}">$status</div>
    </div>
    <div class="content">
      <div class="student-block">
        <div>
          <div class="student-name">$studentName</div>
          <div class="reg-no">Roll/Reg: $regNo</div>
          <div class="academic-info">${academicInfo.toString()}</div>
        </div>
        <div style="text-align: right; font-size: 11px; color: #64748b;">
          <div><strong>Tutor:</strong> $tutorName</div>
        </div>
      </div>

      <div class="grid">
        <div class="tile">
          <div class="tile-label">DEPARTURE (EXIT)</div>
          <div class="tile-value">$exitTime</div>
        </div>
        <div class="tile">
          <div class="tile-label">EXPECTED RETURN</div>
          <div class="tile-value">$returnTime</div>
        </div>
      </div>

      <div class="trip-box">
        <div>
          <span class="trip-dest">$destination</span>
          <span class="trip-cat">$purposeCategory</span>
        </div>
        ${purposeText != null && purposeText.trim().isNotEmpty ? '<div class="trip-note">Reason: ${purposeText.trim()}</div>' : ''}
      </div>

      <div class="audit-section">
        <div class="audit-title">Official Authorization Audit</div>
        <div class="audit-grid">
          <div class="audit-card">
            <div class="audit-role">Assigned Tutor</div>
            <div class="audit-status">${tutorAppr != null ? '${tutorAppr['decision']} (${_formatShortDate(tutorAppr['decidedAt'])})' : (status == 'PENDING_TUTOR' ? 'Awaiting Review' : 'Approved')}</div>
            ${tutorAppr != null && tutorAppr['comment'] != null && tutorAppr['comment'].toString().isNotEmpty ? '<div style="font-size: 9px; color: #64748b; font-style: italic;">"${tutorAppr['comment']}"</div>' : ''}
          </div>
          <div class="audit-card">
            <div class="audit-role">Head of Dept (HOD)</div>
            <div class="audit-status">${hodAppr != null ? '${hodAppr['decision']} (${_formatShortDate(hodAppr['decidedAt'])})' : (status == 'PENDING_HOD' ? 'Awaiting Review' : (status == 'APPROVED' ? 'Approved' : 'Pending Stage'))}</div>
            ${hodAppr != null && hodAppr['comment'] != null && hodAppr['comment'].toString().isNotEmpty ? '<div style="font-size: 9px; color: #64748b; font-style: italic;">"${hodAppr['comment']}"</div>' : ''}
          </div>
        </div>
      </div>

      <div class="perforation">
        <span>DETACHABLE GATE SCAN STUB</span>
      </div>

      <div class="stub">
        ${qrSvg.isNotEmpty ? '''
        <div class="qr-container">
          $qrSvg
        </div>
        <div class="stub-notice">PRESENT TO GATE SECURITY FOR VERIFICATION</div>
        <div class="stub-crypto">ECDSA P-256 cryptographically signed rotating pass token</div>
        <div class="token-text">${qrToken ?? ''}</div>
        ''' : '''
        <div style="padding: 16px; background: #fffbeb; border: 1px solid #fde68a; border-radius: 8px; color: #b45309; font-size: 12px; font-weight: 700;">
          QR Code Locked: Pending Institutional Authorization
        </div>
        '''}
      </div>
    </div>
    <div class="disclaimer">
      NOTICE: Visual presentation alone does NOT constitute valid gate authorization. Validity is strictly verified via cryptographic token scanning at the security gate terminal.
    </div>
  </div>
</body>
</html>''';
  }

  static String _formatDateTime(dynamic dateStr) {
    if (dateStr == null) return '—';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('hh:mm a, dd MMM yyyy').format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  static String _formatShortDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('dd/MM hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  static String _generateQrSvg(String data, {double size = 160}) {
    try {
      final qrCode = QrCode.fromData(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final qrImage = QrImage(qrCode);
      final moduleCount = qrImage.moduleCount;
      final moduleSize = size / moduleCount;

      final sb = StringBuffer();
      sb.writeln('<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" viewBox="0 0 $size $size">');
      sb.writeln('<rect width="100%" height="100%" fill="#ffffff"/>');
      for (var r = 0; r < moduleCount; r++) {
        for (var c = 0; c < moduleCount; c++) {
          if (qrImage.isDark(r, c)) {
            final x = (c * moduleSize).toStringAsFixed(2);
            final y = (r * moduleSize).toStringAsFixed(2);
            final s = (moduleSize + 0.08).toStringAsFixed(2);
            sb.writeln('<rect x="$x" y="$y" width="$s" height="$s" fill="#0f172a"/>');
          }
        }
      }
      sb.writeln('</svg>');
      return sb.toString();
    } catch (_) {
      return '';
    }
  }
}
