import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api_client.dart';
import 'app_state.dart';
import 'qr_token.dart';
import 'theme/app_theme.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int _tabIndex = 0;
  List<dynamic> _outpasses = [];
  bool _loading = true;
  String? _error;
  Timer? _poll;

  AppState get _state => AppStateScope.of(context);

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final rows = await _state.api.myOutpasses();
      if (!mounted) return;
      setState(() { _outpasses = rows; _loading = false; _error = null; });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Map<String, dynamic>? get _activeOutpass {
    for (final o in _outpasses) {
      final s = o['status'] as String?;
      if (s == 'PENDING_TUTOR' ||
          s == 'PENDING_HOD' ||
          s == 'APPROVED' ||
          s == 'EXITED' ||
          s == 'OVERDUE') {
        return o as Map<String, dynamic>;
      }
    }
    return null;
  }

  void _openRequestForm() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RequestFormScreen()))
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeOutpass;
    final past = _outpasses.where((o) => o != active).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.studentAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school, color: AppTheme.studentAccent, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_state.userName ?? 'Student Portal',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Text('CCE Outpass · Student',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _refresh),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign out', onPressed: () => _state.logout()),
        ],
      ),
      body: _loading && _outpasses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _tabIndex == 0
              ? _buildCurrentPassView(active)
              : _buildHistoryView(past),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number),
            label: 'Current Pass',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
      floatingActionButton: active == null
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.studentAccent,
              foregroundColor: Colors.white,
              onPressed: _openRequestForm,
              label: const Text('Request Outpass'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildCurrentPassView(Map<String, dynamic>? active) {
    if (active == null) {
      return EmptyState(
        icon: Icons.badge_outlined,
        title: 'No active outpass',
        subtitle: 'Need to step out of campus? Create an outpass request below.',
        action: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.studentAccent),
          onPressed: _openRequestForm,
          icon: const Icon(Icons.add),
          label: const Text('Request New Outpass'),
        ),
      );
    }

    final status = active['status'] as String;
    final canShowQr = status == 'APPROVED' || status == 'EXITED' || status == 'OVERDUE';

    return SingleChildScrollView(
      padding: AppTheme.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              side: BorderSide(
                color: canShowQr ? AppTheme.studentAccent : AppTheme.borderLight,
                width: canShowQr ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(active['displayId'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      StatusChip(status: status),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.studentAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.place_outlined, color: AppTheme.studentAccent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(active['destination'] ?? 'Destination',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('${active['purposeCategory']} — ${active['type'] ?? 'NORMAL'}',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBg,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _infoCol('Requested Exit', active['requestedExitAt']),
                        _infoCol('Expected Return', active['expectedReturnAt']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (canShowQr) ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.studentAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => QrScreen(outpassId: active['id'] as String)))
                          .then((_) => _refresh()),
                      icon: const Icon(Icons.qr_code_2, size: 24),
                      label: const Text('Open Gate QR Pass', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.statusPendingBg,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top, color: AppTheme.statusPendingText, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status == 'PENDING_TUTOR'
                                  ? 'Awaiting tutor approval'
                                  : 'Tutor approved! Awaiting HOD confirmation.',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.statusPendingText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (status == 'APPROVED' || status.startsWith('PENDING')) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () async {
                        try {
                          await _state.api.cancelOutpass(active['id'] as String);
                          _refresh();
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancel Outpass Request'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCol(String label, dynamic dateStr) {
    String text = '-';
    if (dateStr != null) {
      try {
        final d = DateTime.parse(dateStr).toLocal();
        text = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} (${d.day}/${d.month})';
      } catch (_) {}
    }
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildHistoryView(List<dynamic> past) {
    if (past.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'No past outpasses',
        subtitle: 'Completed, expired, or cancelled passes will appear here.',
      );
    }

    return ListView.separated(
      padding: AppTheme.screenPadding,
      itemCount: past.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final o = past[i];
        return Card(
          child: ListTile(
            title: Text('${o['destination']} (${o['displayId']})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${o['purposeCategory']} · ${o['requestedExitAt']?.substring(0, 10) ?? ''}',
                style: const TextStyle(fontSize: 12)),
            trailing: StatusChip(status: o['status'] ?? 'CANCELLED'),
          ),
        );
      },
    );
  }
}

// Request Form Dialog
class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  final _destination = TextEditingController();
  final _purposeText = TextEditingController();
  String _purposeCategory = 'Medical';
  String _type = 'NORMAL';
  DateTime _exit = DateTime.now().add(const Duration(minutes: 15));
  DateTime _ret = DateTime.now().add(const Duration(hours: 3));
  bool _busy = false;
  String? _error;

  AppState get _state => AppStateScope.of(context);

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      await _state.api.createOutpass(
        requestedExitAt: _exit.toIso8601String(),
        expectedReturnAt: _ret.toIso8601String(),
        destination: _destination.text.trim(),
        purposeCategory: _purposeCategory,
        purposeText: _purposeText.text.trim().isEmpty ? null : _purposeText.text.trim(),
        type: _type,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(DateTime initial, bool isExit) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isExit) {
        _exit = combined;
        if (_ret.isBefore(_exit)) _ret = _exit.add(const Duration(hours: 2));
      } else {
        _ret = combined;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Outpass')),
      body: SingleChildScrollView(
        padding: AppTheme.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _destination,
              decoration: const InputDecoration(labelText: 'Destination (e.g. Irinjalakuda Market)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _purposeCategory,
              decoration: const InputDecoration(labelText: 'Purpose Category'),
              items: const [
                DropdownMenuItem(value: 'Medical', child: Text('Medical')),
                DropdownMenuItem(value: 'Personal', child: Text('Personal')),
                DropdownMenuItem(value: 'Official', child: Text('Official')),
                DropdownMenuItem(value: 'Academic', child: Text('Academic')),
                DropdownMenuItem(value: 'Emergency', child: Text('Emergency')),
              ],
              onChanged: (v) => setState(() => _purposeCategory = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Outpass Type'),
              items: const [
                DropdownMenuItem(value: 'NORMAL', child: Text('Normal (Tutor → HOD)')),
                DropdownMenuItem(value: 'EMERGENCY', child: Text('Emergency (Concurrent alerts)')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _purposeText,
              decoration: const InputDecoration(labelText: 'Additional Details (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(_exit, true),
                    child: Text('Exit: ${_exit.hour.toString().padLeft(2, '0')}:${_exit.minute.toString().padLeft(2, '0')}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(_ret, false),
                    child: Text('Return: ${_ret.hour.toString().padLeft(2, '0')}:${_ret.minute.toString().padLeft(2, '0')}'),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.studentAccent),
              onPressed: _busy || _destination.text.trim().isEmpty ? null : _submit,
              child: Text(_busy ? 'Submitting…' : 'Submit for Approval'),
            ),
          ],
        ),
      ),
    );
  }
}

/// HERO QR VIEW
class QrScreen extends StatefulWidget {
  const QrScreen({super.key, required this.outpassId});

  final String outpassId;

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  Timer? _timer;
  int _step = DeviceKeys.currentStep();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final step = DeviceKeys.currentStep();
      if (step != _step) setState(() => _step = step);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keys = AppStateScope.of(context).deviceKeys!;
    final token = keys.buildToken(widget.outpassId, _step);
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final secsLeft = (_step + 30) - nowSec;
    final progress = (secsLeft.clamp(0, 30) / 30.0);

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('Official Gate Pass QR'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hero QR Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    side: const BorderSide(color: AppTheme.borderLight),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Countdown Ring above QR
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 54,
                              height: 54,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 5,
                                backgroundColor: AppTheme.borderLight,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  secsLeft > 5 ? AppTheme.studentAccent : Colors.red,
                                ),
                              ),
                            ),
                            Text(
                              '${secsLeft}s',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: secsLeft > 5 ? AppTheme.textDark : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: QrImageView(
                            data: token,
                            size: 240,
                            version: QrVersions.auto,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const StatusChip(status: 'APPROVED'),
                        const SizedBox(height: 10),
                        const Text(
                          'Scan at Security Gate',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Rotating ECDSA dynamic token re-keys every 30 seconds to prevent screenshots.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: token));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Token copied to clipboard for Guard manual entry.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Token for Guard Manual Entry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
