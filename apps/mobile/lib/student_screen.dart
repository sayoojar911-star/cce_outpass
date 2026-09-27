import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api_client.dart';
import 'app_state.dart';
import 'qr_token.dart';

const _statusLabels = {
  'PENDING_TUTOR': 'Pending — Tutor',
  'PENDING_HOD': 'Pending — HOD',
  'APPROVED': 'Approved — show QR',
  'EXITED': 'Out of campus',
  'RETURNED': 'Returned',
  'REJECTED': 'Rejected',
  'CANCELLED': 'Cancelled',
  'EXPIRED': 'Expired',
  'OVERDUE': 'Overdue — return now',
};

Color _statusColor(String status) {
  switch (status) {
    case 'APPROVED':
      return Colors.green;
    case 'EXITED':
      return Colors.blue;
    case 'OVERDUE':
      return Colors.deepOrange;
    case 'REJECTED':
    case 'CANCELLED':
    case 'EXPIRED':
      return Colors.red;
    case 'PENDING_TUTOR':
    case 'PENDING_HOD':
      return Colors.orange;
    case 'RETURNED':
      return Colors.teal;
    default:
      return Colors.grey;
  }
}

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  List<dynamic> _outpasses = [];
  bool _loading = true;
  String? _error;
  Timer? _poll;

  AppState get _state => AppStateScope.of(context);

  @override
  void initState() {
    super.initState();
    _refresh();
    // Real-time-ish: poll for status changes (approvals, QR ready) while the
    // screen is open. Push notifications are the later phase (PRD §6.10).
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
      if (!mounted || silent) return; // keep old data on background failures
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Map<String, dynamic>? get _active {
    const activeStatuses = ['PENDING_TUTOR', 'PENDING_HOD', 'APPROVED', 'EXITED', 'OVERDUE'];
    for (final o in _outpasses) {
      if (activeStatuses.contains(o['status'])) return (o as Map).cast<String, dynamic>();
    }
    return null;
  }

  Future<void> _openRequestForm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RequestFormScreen()),
    );
    if (created == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CCE Outpass'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _state.logout(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('Error: $_error'),
                      ),
                    ),
                  if (active != null) _ActiveCard(outpass: active, onChanged: _refresh)
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          const Text('No active outpass'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _openRequestForm,
                            icon: const Icon(Icons.exit_to_app),
                            label: const Text('Request outpass'),
                          ),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('History', style: Theme.of(context).textTheme.titleMedium),
                  ..._outpasses.map((o) {
                    final m = (o as Map).cast<String, dynamic>();
                    return Card(
                      child: ListTile(
                        title: Text('${m['displayId']} · ${m['destination']}'),
                        subtitle: Text(
                            '${(m['requestedExitAt'] as String).substring(0, 16).replaceAll("T", " ")}'
                            ' → ${(m['expectedReturnAt'] as String).substring(11, 16)}'),
                        trailing: Chip(
                          label: Text(_statusLabels[m['status']] ?? m['status'],
                              style: const TextStyle(color: Colors.white, fontSize: 11)),
                          backgroundColor: _statusColor(m['status'] as String),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
      floatingActionButton: active == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openRequestForm,
              label: const Text('New request'),
              icon: const Icon(Icons.add),
            ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.outpass, required this.onChanged});

  final Map<String, dynamic> outpass;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final status = outpass['status'] as String;
    final canShowQr = status == 'APPROVED' || status == 'EXITED' || status == 'OVERDUE';
    return Card(
      color: canShowQr ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_statusLabels[status] ?? status,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${outpass['destination']} · ${outpass['displayId']}'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: canShowQr
                      ? () => Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (_) => QrScreen(outpassId: outpass['id'] as String)))
                          .then((_) => onChanged())
                      : null,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Show QR'),
                ),
              ),
              const SizedBox(width: 8),
              if (status == 'APPROVED' || status.startsWith('PENDING'))
                TextButton.icon(
                  onPressed: () async {
                    final api = AppStateScope.of(context).api;
                    try {
                      await api.cancelOutpass(outpass['id'] as String);
                      onChanged();
                    } on ApiException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  final _destination = TextEditingController();
  final _purposeText = TextEditingController();
  String _purposeCategory = 'Medical';
  bool _emergency = false;
  DateTime _exit = DateTime.now().add(const Duration(minutes: 30));
  DateTime _ret = DateTime.now().add(const Duration(hours: 3));
  bool _busy = false;
  String? _error;

  static const _categories = [
    'Medical', 'Family', 'Official', 'Home visit', 'Other',
  ];

  Future<void> _pick(DateTime initial, bool isExit) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => isExit ? _exit = value : _ret = value);
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
      'T${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:00';

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      await AppStateScope.of(context).api.createOutpass(
            requestedExitAt: _fmt(_exit),
            expectedReturnAt: _fmt(_ret),
            destination: _destination.text.trim(),
            purposeCategory: _purposeCategory,
            purposeText: _purposeText.text.trim().isEmpty ? null : _purposeText.text.trim(),
            type: _emergency ? 'EMERGENCY' : 'NORMAL',
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _destination.text.trim().isNotEmpty && _ret.isAfter(_exit);
    return Scaffold(
      appBar: AppBar(title: const Text('Request outpass')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Normal')),
              ButtonSegment(value: true, label: Text('Emergency')),
            ],
            selected: {_emergency},
            onSelectionChanged: (s) => setState(() => _emergency = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _destination,
            decoration: const InputDecoration(
                labelText: 'Destination', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _purposeCategory,
            decoration:
                const InputDecoration(labelText: 'Purpose', border: OutlineInputBorder()),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _purposeCategory = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _purposeText,
            decoration: const InputDecoration(
                labelText: 'Details (optional)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pick(_exit, true),
                child: Text('Exit: ${_fmt(_exit).substring(5, 16).replaceAll("T", " ")}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pick(_ret, false),
                child: Text('Return: ${_fmt(_ret).substring(5, 16).replaceAll("T", " ")}'),
              ),
            ),
          ]),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: (_busy || !valid) ? null : _submit,
            child: Text(_busy ? 'Submitting…' : 'Submit for approval'),
          ),
        ],
      ),
    );
  }
}

/// Rotating QR screen (FR-STU-08/09, PRD §7.3): token re-signed every 30 s;
/// a screenshot dies within the server's 75 s acceptance window.
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
    final secsLeft = _step + 30 - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return Scaffold(
      appBar: AppBar(title: const Text('Gate pass')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  QrImageView(data: token, size: 260),
                  const SizedBox(height: 16),
                  Text('Refreshes in ${secsLeft}s',
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Show this at the gate. Do not share or screenshot.'),
          ],
        ),
      ),
    );
  }
}
