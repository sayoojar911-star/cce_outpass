import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'api_client.dart';
import 'app_state.dart';
import 'theme/app_theme.dart';

/// Refreshed Guard gate screen using AppTheme, warm orange accents, and clean status views.
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
    final token = capture.barcodes.first.rawValue;
    if (token == null || !token.startsWith('v1.')) return;
    setState(() { _submitting = true; });
    await _submitScan(token);
    if (mounted) setState(() { _submitting = false; _cameraOn = false; });
  }

  Future<void> _submitScan(String token) async {
    final result = await _state.api.scan(
      token: token,
      direction: _dir == _Dir.exit ? 'EXIT' : 'ENTRY',
      gateId: _gateId.text.trim(),
      clientScanId: uuidV4(),
    );
    final ok = (result['result'] as String).startsWith('OK_');
    if (mounted) {
      final o = result['outpass'] as Map?;
      final s = (o?['student'] as Map?)?.cast<String, dynamic>();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: ok ? const Color(0xFF047857) : const Color(0xFFB91C1C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.cancel, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ok
                      ? (_dir == _Dir.exit ? 'OUTPASS APPROVED' : 'RETURN RECORDED')
                      : 'SCAN REJECTED',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Result: ${result['result']}',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              if (o != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pass: ${o['displayId']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      if (s != null) ...[
                        const SizedBox(height: 4),
                        Text('Student: ${s['name']}', style: const TextStyle(color: Colors.white)),
                        Text('Roll No: ${s['registerNo']}', style: const TextStyle(color: Colors.white)),
                        Text('Dept: ${s['department']}', style: const TextStyle(color: Colors.white)),
                      ],
                      const SizedBox(height: 4),
                      Text('Destination: ${o['destination']}', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
      await _loadHistory();
    }
  }

  void _manualTokenEntry() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manual Token Entry'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Paste v1.<outpassId>.<step>.<sig>',
            labelText: 'Raw QR Token String',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final text = controller.text.trim();
              if (text.isNotEmpty) _submitScan(text);
            },
            child: const Text('Verify & Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.guardAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security, color: AppTheme.guardAccent, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Security Gate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(_state.userName ?? 'Gate Officer', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _loadHistory),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign out', onPressed: () => _state.logout()),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppTheme.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Direction Selector Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gate Operation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.guardAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => setState(() => _cameraOn = !_cameraOn),
                            icon: Icon(_cameraOn ? Icons.videocam_off : Icons.qr_code_scanner),
                            label: Text(_cameraOn ? 'Close Camera' : 'Scan Student QR'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _manualTokenEntry,
                          icon: const Icon(Icons.keyboard_alt_outlined),
                          label: const Text('Manual Entry'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_cameraOn) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 300,
                  child: MobileScanner(onDetect: _onDetect),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // History Section
            const Text('Recent Gate Scans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            if (_history.isEmpty)
              const EmptyState(
                icon: Icons.history,
                title: 'No scans this shift',
                subtitle: 'Validated exits and returns will be listed here.',
              )
            else
              ..._history.take(10).map((h) {
                final isOk = (h['resultCode'] as String? ?? '').startsWith('OK_');
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isOk ? Colors.green.shade100 : Colors.red.shade100,
                      child: Icon(
                        isOk ? Icons.check : Icons.close,
                        color: isOk ? Colors.green.shade800 : Colors.red.shade800,
                        size: 20,
                      ),
                    ),
                    title: Text('${h['direction'] ?? ''} — ${h['resultCode'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('Scanned at: ${h['scannedAt']?.toString().substring(11, 19) ?? ''}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
