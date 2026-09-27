import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_state.dart';

/// Approver dashboard (FR-TUT-02/04, FR-HOD-03): pending requests for the
/// role's scope (tutor → own students, HOD → department), approve/reject.
class ApproverHome extends StatefulWidget {
  const ApproverHome({super.key});

  @override
  State<ApproverHome> createState() => _ApproverHomeState();
}

class _ApproverHomeState extends State<ApproverHome> {
  List<dynamic> _pending = [];
  bool _loading = true;
  String? _error;
  Timer? _poll;

  AppState get _state => AppStateScope.of(context);

  @override
  void initState() {
    super.initState();
    _refresh();
    // Real-time-ish: new requests appear within a few seconds (FR-TUT-01's
    // push notification is the later phase).
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
      final rows = await _state.api.pending();
      if (!mounted) return;
      setState(() { _pending = rows; _loading = false; _error = null; });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _decide(Map<String, dynamic> o, String decision) async {
    String? comment;
    if (decision == 'REJECTED') {
      // Reason is mandatory for rejection (FR-TUT-04).
      comment = await _askReason();
      if (comment == null) return;
    }
    try {
      await _state.api.decide(o['id'] as String, decision, comment: comment);
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<String?> _askReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejection reason'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'e.g. Internal examination scheduled'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = _state.isHod ? 'HOD' : 'Tutor';
    return Scaffold(
      appBar: AppBar(
        title: Text('$roleLabel approvals'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _state.logout()),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _pending.isEmpty
                  ? const Center(child: Text('No pending requests 🎉'))
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: _pending.map((r) {
                          final o = (r as Map).cast<String, dynamic>();
                          final s = (o['student'] as Map?)?.cast<String, dynamic>() ?? {};
                          final emergency = o['type'] == 'EMERGENCY';
                          return Card(
                            color: emergency ? Colors.red.shade50 : null,
                            child: ListTile(
                              title: Text(
                                  '${emergency ? "🚨 " : ""}${s['name'] ?? 'Student'}'
                                  ' · ${o['destination']}'),
                              subtitle: Text(
                                  '${s['registerNo'] ?? ''} · ${o['purposeCategory']}'
                                  '\n${(o['requestedExitAt'] as String).substring(0, 16).replaceAll("T", " ")}'
                                  ' → ${(o['expectedReturnAt'] as String).substring(11, 16)}'),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Approve',
                                    icon: const Icon(Icons.check_circle,
                                        color: Colors.green, size: 32),
                                    onPressed: () => _decide(o, 'APPROVED'),
                                  ),
                                  IconButton(
                                    tooltip: 'Reject',
                                    icon: const Icon(Icons.cancel,
                                        color: Colors.red, size: 32),
                                    onPressed: () => _decide(o, 'REJECTED'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
    );
  }
}
