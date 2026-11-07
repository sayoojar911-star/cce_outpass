import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'api_client.dart';
import 'app_state.dart';
import 'theme/app_theme.dart';
import 'async_action_helper.dart';

/// Helper to convert UTC timestamp to Indian Standard Time (IST, UTC+05:30)
String formatToIST(dynamic dateInput) {
  if (dateInput == null) return '';
  DateTime? dt;
  if (dateInput is DateTime) {
    dt = dateInput;
  } else if (dateInput is String) {
    dt = DateTime.tryParse(dateInput);
  }
  if (dt == null) return dateInput.toString();
  final ist = dt.toUtc().add(const Duration(hours: 5, minutes: 30));
  final hour24 = ist.hour;
  final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final minStr = ist.minute.toString().padLeft(2, '0');
  final day = ist.day.toString().padLeft(2, '0');
  const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final monthStr = monthNames[ist.month - 1];
  return '$hour12:$minStr $period, $day $monthStr';
}

String formatToISTTime(dynamic dateInput) {
  if (dateInput == null) return '';
  DateTime? dt;
  if (dateInput is DateTime) {
    dt = dateInput;
  } else if (dateInput is String) {
    dt = DateTime.tryParse(dateInput);
  }
  if (dt == null) return dateInput.toString();
  final ist = dt.toUtc().add(const Duration(hours: 5, minutes: 30));
  final hour24 = ist.hour;
  final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final minStr = ist.minute.toString().padLeft(2, '0');
  return '$hour12:$minStr $period';
}

/// Refreshed Guard gate screen with resilient QR scan & Manual Pass Code entry
class GuardHome extends StatefulWidget {
  const GuardHome({super.key});

  @override
  State<GuardHome> createState() => _GuardHomeState();
}

enum _Dir { exit, entry }

class _GuardHomeState extends State<GuardHome> {
  final _gateId = TextEditingController(text: 'main-gate');
  _Dir _dir = _Dir.exit;
  bool _cameraOn = false;
  bool _submitting = false;
  DateTime? _lastScanTime;
  List<dynamic> _history = [];
  Timer? _poll;

  AppState get _state => AppStateScope.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startShiftAndLoad();
        _poll = Timer.periodic(const Duration(seconds: 6), (_) => _loadHistory());
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _gateId.dispose();
    super.dispose();
  }

  Future<void> _startShiftAndLoad() async {
    try {
      await _state.api.startShift(_gateId.text.trim());
    } on ApiException {
      // Shift record is bookkeeping
    }
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final h = await _state.api.get('/gate/scans/mine');
      if (!mounted) return;
      setState(() => _history = h as List<dynamic>);
    } on ApiException {
      // keep last known history
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_submitting || capture.barcodes.isEmpty) return;

    // Debounce duplicate barcode camera frames (2.5s window)
    final now = DateTime.now();
    if (_lastScanTime != null && now.difference(_lastScanTime!).inMilliseconds < 2500) {
      return;
    }

    final token = capture.barcodes.first.rawValue;
    if (token == null || !token.startsWith('v1.')) return;

    _lastScanTime = now;
    setState(() {
      _submitting = true;
    });

    try {
      debugPrint('[GateScan] Barcode detected | Direction: $_dir | Gate: ${_gateId.text}');
      await _submitScan(token);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _cameraOn = false;
        });
      }
    }
  }

  Future<void> _submitScan(String token) async {
    debugPrint('[GateScan] Submitting QR Scan | Direction: $_dir | Token prefix: ${token.substring(0, 15)}...');
    await AsyncActionHelper.run(
      context,
      action: () async {
        final result = await _state.api.scan(
          token: token,
          direction: _dir == _Dir.exit ? 'EXIT' : 'ENTRY',
          gateId: _gateId.text.trim(),
          clientScanId: uuidV4(),
        );

        debugPrint('[GateScan] Scan response: result=${result['result']}, msg=${result['message']}');
        if (mounted) {
          await _showScanResultDialog(result);
          await _loadHistory();
        }
      },
    );
  }

  Future<void> _submitManualEntry(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    setState(() {
      _submitting = true;
    });
    debugPrint('[GateScan] Submitting Manual Pass Code | Direction: $_dir | Code: $cleanCode');

    try {
      await AsyncActionHelper.run(
        context,
        action: () async {
          final result = await _state.api.manualEntry(
            code: cleanCode,
            direction: _dir == _Dir.exit ? 'EXIT' : 'ENTRY',
            gateId: _gateId.text.trim(),
            clientScanId: uuidV4(),
          );

          debugPrint('[GateScan] Manual response: result=${result['result']}, msg=${result['message']}');
          if (mounted) {
            await _showScanResultDialog(result, isManual: true, enteredCode: cleanCode);
            await _loadHistory();
          }
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _showScanResultDialog(Map<String, dynamic> result, {bool isManual = false, String? enteredCode}) async {
    final code = result['result']?.toString() ?? 'UNKNOWN';
    final detail = result['outpass'] as Map?;
    final student = (detail?['student'] as Map?)?.cast<String, dynamic>();
    final isLate = detail?['isLate'] == true;
    final lateMinutes = detail?['lateMinutes'] ?? 0;

    // Friendly Title, Message, Color and Icon mapping
    Color dialogBg;
    IconData dialogIcon;
    String titleText;
    String friendlyMessage = result['message']?.toString() ?? code;

    if (code == 'OK_EXIT') {
      dialogBg = const Color(0xFF047857); // Emerald green
      dialogIcon = Icons.check_circle;
      titleText = 'OUTPASS APPROVED — ALLOW EXIT';
    } else if (code == 'OK_ENTRY') {
      if (isLate) {
        dialogBg = const Color(0xFFD97706); // Amber for late return
        dialogIcon = Icons.alarm;
        titleText = 'RETURN RECORDED (LATE BY $lateMinutes MIN)';
        friendlyMessage = 'Student returned after expected time. Tutor & HOD have been notified.';
      } else {
        dialogBg = const Color(0xFF047857); // Emerald green
        dialogIcon = Icons.check_circle;
        titleText = 'CAMPUS RETURN RECORDED';
        friendlyMessage = 'Return verified successfully. Outpass marked as RETURNED.';
      }
    } else if (code == 'QR_STALE') {
      dialogBg = const Color(0xFFD97706); // Amber
      dialogIcon = Icons.update;
      titleText = 'SCAN REJECTED: QR EXPIRED';
      friendlyMessage = 'The rotating QR token has expired. Ask the student to refresh their screen, or use their Pass Code.';
    } else if (code == 'MIN_DWELL') {
      dialogBg = const Color(0xFFD97706); // Amber
      dialogIcon = Icons.timer;
      titleText = 'SCAN REJECTED: MINIMUM DWELL';
      friendlyMessage = result['message'] ?? 'Too early to record return.';
    } else if (code == 'ALREADY_USED') {
      dialogBg = const Color(0xFFDC2626); // Crimson
      dialogIcon = Icons.block;
      titleText = 'SCAN REJECTED: ALREADY USED';
      friendlyMessage = result['message'] ?? 'This outpass has already completed this gate movement.';
    } else if (code == 'NOT_FOUND') {
      dialogBg = const Color(0xFFDC2626); // Crimson
      dialogIcon = Icons.search_off;
      titleText = 'PASS CODE NOT FOUND';
      friendlyMessage = 'No matching outpass found for code "${enteredCode ?? ''}". Please check the student\'s pass.';
    } else if (code == 'LOCKOUT') {
      dialogBg = const Color(0xFF991B1B); // Dark crimson
      dialogIcon = Icons.security;
      titleText = 'GUARD LOCKED OUT';
      friendlyMessage = result['message'] ?? 'Too many failed attempts. Temporary security lockout active.';
    } else if (code == 'WRONG_STATE') {
      dialogBg = const Color(0xFFEA580C); // Orange
      dialogIcon = Icons.warning_amber_rounded;
      titleText = 'INVALID PASS STATE';
      friendlyMessage = _dir == _Dir.entry
          ? 'Student has not exited campus yet. Exit scan required first.'
          : 'Outpass is not currently in an approved state for exit.';
    } else if (code == 'NOT_APPROVED') {
      dialogBg = const Color(0xFFEA580C); // Orange
      dialogIcon = Icons.lock_clock;
      titleText = 'OUTPASS NOT APPROVED';
      friendlyMessage = 'This outpass is still awaiting approval and is not valid for gate exit.';
    } else if (code == 'EXPIRED') {
      dialogBg = const Color(0xFFDC2626); // Crimson
      dialogIcon = Icons.hourglass_disabled;
      titleText = 'OUTPASS EXPIRED';
      friendlyMessage = result['message'] ?? 'This outpass validity period has ended.';
    } else if (code == 'CANCELLED') {
      dialogBg = const Color(0xFFDC2626); // Crimson
      dialogIcon = Icons.cancel_outlined;
      titleText = 'PASS CANCELLED';
      friendlyMessage = result['message'] ?? 'This outpass has been cancelled and is no longer valid for gate movement.';
    } else {
      dialogBg = const Color(0xFFDC2626); // Crimson
      dialogIcon = Icons.cancel;
      titleText = 'SCAN REJECTED: $code';
    }

    final nowIST = formatToIST(DateTime.now());

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () => Navigator.of(ctx).pop(),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () => Navigator.of(ctx).pop(),
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(ctx).pop(),
        },
        child: Focus(
          autofocus: true,
          child: AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(dialogIcon, color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titleText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          friendlyMessage,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (detail != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pass: ${detail['displayId'] ?? ''}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (detail['passCode'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Code: ${detail['passCode']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Divider(color: Colors.white24, height: 16),
                        if (student != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: ClipOval(
                                  child: _buildStudentAvatar(student['photoUrl'] as String?, student['name'] ?? ''),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Student: ${student['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                                    const SizedBox(height: 2),
                                    Text('Roll No: ${student['registerNo']} | Dept: ${student['department']}', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (detail['type'] != null)
                          Text('Type: ${detail['type']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('Destination: ${detail['destination'] ?? 'N/A'}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        if (detail['purpose'] != null)
                          Text('Purpose: ${detail['purpose']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 6),
                        Text(
                          'Processed: $nowIST (IST)',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Text(
                    'Time: $nowIST (IST)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentAvatar(String? photoUrl, String name) {
    final initials = name.trim().isNotEmpty
        ? name
            .trim()
            .split(' ')
            .where((p) => p.isNotEmpty)
            .map((p) => p[0])
            .take(2)
            .join('')
            .toUpperCase()
        : 'ST';

    final fallback = Container(
      color: Colors.white24,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );

    if (photoUrl == null || photoUrl.isEmpty) {
      return fallback;
    }

    final fullUrl = _state.api.resolveMediaUrl(photoUrl);
    if (fullUrl.startsWith('data:image')) {
      try {
        final comma = fullUrl.indexOf(',');
        if (comma != -1) {
          final bytes = base64Decode(fullUrl.substring(comma + 1));
          return Image.memory(bytes, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => fallback);
        }
      } catch (_) {}
    }

    return Image.network(
      fullUrl,
      fit: BoxFit.cover,
      errorBuilder: (ctx, err, stack) => fallback,
    );
  }

  void _manualTokenEntry() {
    final controller = TextEditingController();
    void submit(BuildContext ctx) {
      Navigator.pop(ctx);
      final text = controller.text.trim();
      if (text.isNotEmpty) _submitManualEntry(text);
    }

    AppDialog.show<void>(
      context: context,
      title: 'Manual Pass Code Entry',
      titleIcon: Icons.pin,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the 6-character Pass Code from the student\'s outpass (or Pass ID). Press Enter to verify.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: AppSpacing.s12),
          AppTextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => submit(context),
            textCapitalization: TextCapitalization.characters,
            labelText: 'Student Pass Code',
            hintText: 'e.g. K9W32M or OP202610110001',
            prefixIcon: const Icon(Icons.confirmation_number_outlined),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => controller.clear(),
            ),
          ),
        ],
      ),
      actions: [
        AppTextButton(onPressed: () => Navigator.pop(context), label: 'Cancel'),
        PrimaryButton(
          backgroundColor: AppTheme.guardAccent,
          onPressed: () => submit(context),
          label: 'Verify & Record',
          fullWidth: false,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s8 - 2),
              decoration: BoxDecoration(
                color: AppTheme.guardAccent.withValues(alpha: 0.12),
                borderRadius: AppRadii.roundedSm,
              ),
              child: const Icon(Icons.security, color: AppTheme.guardAccent, size: 22),
            ),
            const SizedBox(width: AppSpacing.s8 + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Security Gate',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _state.userName ?? 'Gate Officer',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _loadHistory),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign out', onPressed: () => _state.logout()),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: AppLayout.maxDashboardWidth,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Direction Selector Card
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gate Operation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: AppSpacing.s12),
                      SegmentedButton<_Dir>(
                        segments: const [
                          ButtonSegment(
                            value: _Dir.exit,
                            label: Text('STUDENT EXIT'),
                            icon: Icon(Icons.logout),
                          ),
                          ButtonSegment(
                            value: _Dir.entry,
                            label: Text('CAMPUS RETURN'),
                            icon: Icon(Icons.login),
                          ),
                        ],
                        selected: {_dir},
                        onSelectionChanged: (s) => setState(() => _dir = s.first),
                      ),
                      const SizedBox(height: AppSpacing.fieldGap),
                      AppButtonRow(
                        sideBySideMobile: false,
                        primary: PrimaryButton(
                          backgroundColor: AppTheme.guardAccent,
                          onPressed: _submitting ? null : () => setState(() => _cameraOn = !_cameraOn),
                          icon: _cameraOn ? Icons.videocam_off : Icons.qr_code_scanner,
                          label: _submitting
                              ? 'Processing...'
                              : (_cameraOn ? 'Close Camera' : 'Scan Student QR'),
                        ),
                        secondary: SecondaryButton(
                          onPressed: _submitting ? null : _manualTokenEntry,
                          icon: Icons.keyboard_alt_outlined,
                          label: 'Manual Entry',
                        ),
                      ),
                    ],
                  ),
                ),
                if (_cameraOn) ...[
                  const SizedBox(height: AppSpacing.fieldGap),
                  ClipRRect(
                    borderRadius: AppRadii.roundedLg,
                    child: SizedBox(
                      height: 300,
                      child: MobileScanner(onDetect: _onDetect),
                    ),
                  ),
                ],
                const SectionHeader(
                  title: 'Recent Gate Scans',
                  subtitle: 'Real-time validated movements at this checkpoint',
                ),
                if (_history.isEmpty)
                  const EmptyState(
                    icon: Icons.history,
                    title: 'No scans this shift',
                    subtitle: 'Validated exits and returns will be listed here.',
                  )
                else
                  ..._history.take(10).map((h) {
                    final isOk = (h['resultCode'] as String? ?? '').startsWith('OK_');
                    final detail = h['detail'] as Map?;
                    final isLate = detail?['isLate'] == true;
                    final lateMin = detail?['lateMinutes'] ?? 0;
                    final istTime = formatToIST(h['scannedAt']);

                    return AppCard(
                      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isOk
                                ? (isLate ? Colors.amber.shade100 : Colors.green.shade100)
                                : Colors.red.shade100,
                            child: Icon(
                              isOk
                                  ? (isLate ? Icons.alarm : Icons.check)
                                  : Icons.close,
                              color: isOk
                                  ? (isLate ? Colors.amber.shade900 : Colors.green.shade800)
                                  : Colors.red.shade800,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${h['direction'] ?? ''} — ${h['resultCode'] ?? ''}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (isLate) ...[
                                      const SizedBox(width: AppSpacing.s4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade200,
                                          borderRadius: AppRadii.roundedSm,
                                        ),
                                        child: Text(
                                          'LATE ($lateMin m)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.s4),
                                if (detail?['displayId'] != null)
                                  Text(
                                    'Pass: ${detail!['displayId']} ${detail['passCode'] != null ? '(${detail['passCode']})' : ''}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                Text(
                                  'Scanned at: $istTime (IST)',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
