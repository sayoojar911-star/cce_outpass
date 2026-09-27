import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'api_client.dart';
import 'app_state.dart';

/// Guard gate screen (FR-SEC-01..07): gate + direction selection, camera scan,
/// big green/red result, scan history. Offline mode is a later phase (PRD §7.6).
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
    _startShiftAndLoad();
    // Keep the shift log current even between scans.
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _loadHistory());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _startShiftAndLoad() async {
    try {
      await _state.api.startShift(_gateId.text.trim());
    } on ApiException {
      // Shift record is bookkeeping; scanning still works.
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
          backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
          title: Text(
            ok
                ? (_dir == _Dir.exit ? '🟢 OUTPASS APPROVED' : '🟢 RETURN RECORDED')
                : '🔴 NOT APPROVED',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result['result'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
              if (o != null) ...[
                const SizedBox(height: 8),
                Text('${o['displayId']}',
                    style: const TextStyle(color: Colors.white70)),
              ],
              if (s != null) ...[
                Text('${s['name']} · ${s['registerNo']}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                if (o != null && o['destination'] != null)
                  Text('To: ${o['destination']}',
                      style: const TextStyle(color: Colors.white70)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    _startShiftAndLoad();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate — Security'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _state.logout()),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _gateId,
                  decoration: const InputDecoration(labelText: 'Gate ID'),
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<_Dir>(
                segments: const [
                  ButtonSegment(value: _Dir.exit, label: Text('EXIT')),
                  ButtonSegment(value: _Dir.entry, label: Text('ENTRY')),
                ],
                selected: {_dir},
                onSelectionChanged: (s) => setState(() => _dir = s.first),
              ),
            ]),
          ),
          if (_cameraOn)
            Expanded(
              child: Stack(children: [
                MobileScanner(
                  onDetect: _onDetect,
                  controller: MobileScannerController(
                    detectionSpeed: DetectionSpeed.normal,
                  ),
                ),
                if (_submitting)
                  const ColoredBox(
                    color: Colors.black54,
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
              ]),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 20),
                        textStyle: const TextStyle(fontSize: 22),
                      ),
                      onPressed: () => setState(() => _cameraOn = true),
                      icon: const Icon(Icons.qr_code_scanner, size: 32),
                      label: const Text('SCAN QR'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        final ctrl = TextEditingController();
                        showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Manual token entry'),
                            content: TextField(
                              controller: ctrl,
                              decoration: const InputDecoration(
                                  hintText: 'v1.<id>.<ts>.<sig>'),
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel')),
                              FilledButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _submitScan(ctrl.text.trim());
                                },
                                child: const Text('Submit'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('Manual entry'),
                    ),
                  ],
                ),
              ),
            ),
          if (_history.isNotEmpty)
            SizedBox(
              height: 150,
              child: ListView(
                children: _history.take(6).map((e) {
                  final ev = (e as Map).cast<String, dynamic>();
                  final ok = (ev['resultCode'] as String).startsWith('OK_');
                  return ListTile(
                    dense: true,
                    leading: Icon(ok ? Icons.check_circle : Icons.cancel,
                        color: ok ? Colors.green : Colors.red),
                    title: Text('${ev['direction']} · ${ev['resultCode']}'),
                    subtitle: Text('${ev['scannedAt']}'.substring(0, 19)),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
