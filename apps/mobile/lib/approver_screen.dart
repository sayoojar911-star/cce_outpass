import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_state.dart';
import 'theme/app_theme.dart';

/// Refreshed Approver dashboard (Tutor & HOD) using AppTheme and role accents.
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
      comment = await _askReason();
      if (comment == null) return;
    }
    try {
      await _state.api.decide(o['id'] as String, decision, comment: comment);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: decision == 'APPROVED' ? Colors.green.shade700 : Colors.red.shade700,
            content: Row(
              children: [
                Icon(decision == 'APPROVED' ? Icons.check_circle : Icons.cancel, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Outpass ${o['displayId']} ${decision.toLowerCase()}'),
              ],
            ),
          ),
        );
      }
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
        title: const Text('Rejection Reason'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Internal examination scheduled'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHod = _state.isHod;
    final accent = isHod ? AppTheme.hodAccent : AppTheme.tutorAccent;
    final roleName = isHod ? 'HOD' : 'Tutor';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(AppTheme.roleIcon(_state.userRole), color: accent, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$roleName Approvals', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(_state.userName ?? 'Approver Dashboard', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _refresh),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign out', onPressed: () => _state.logout()),
        ],
      ),
      body: _loading && _pending.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _pending.isEmpty
              ? EmptyState(
                  icon: Icons.checklist_rtl_rounded,
                  title: 'All caught up!',
                  subtitle: 'No student outpasses waiting for your approval right now.',
                )
              : ListView.separated(
                  padding: AppTheme.screenPadding,
                  itemCount: _pending.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final o = _pending[i];
                    final s = (o['student'] as Map?)?.cast<String, dynamic>() ?? {};
                    final isEmergency = o['type'] == 'EMERGENCY';

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        side: BorderSide(
                          color: isEmergency ? Colors.red.shade400 : AppTheme.borderLight,
                          width: isEmergency ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      s['name'] ?? 'Student',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    if (isEmergency) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('EMERGENCY', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                StatusChip(status: o['status'] ?? 'PENDING_TUTOR'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${s['registerNo'] ?? ''} · Dept: ${s['department'] ?? ''} · Sem ${s['semester'] ?? ''}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceBg,
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${o['purposeCategory']} · ${o['destination']}',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  if (o['purposeText'] != null && (o['purposeText'] as String).isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('Note: ${o['purposeText']}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                    onPressed: () => _decide(o, 'REJECTED'),
                                    icon: const Icon(Icons.close, size: 18),
                                    label: const Text('Reject'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(backgroundColor: accent),
                                    onPressed: () => _decide(o, 'APPROVED'),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Approve'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
