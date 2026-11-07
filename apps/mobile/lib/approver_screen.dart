import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'theme/app_theme.dart';
import 'async_action_helper.dart';
import 'widgets/ticket_outpass.dart';

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
  final StreamController<List<dynamic>> _streamController = StreamController<List<dynamic>>.broadcast();

  AppState get _state => AppStateScope.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchPending(showLoading: true);
    });
    // Real-time periodic update stream every 3 seconds
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _fetchPending(showLoading: false);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _streamController.close();
    super.dispose();
  }

  Future<void> _fetchPending({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final approverRole = _state.userRoleId ?? (_state.isHod ? 'hod' : 'tutor');
    final approverId = _state.userId ?? '';
    debugPrint(
      '[ApproverHome] Querying pending approvals: role=$approverRole, approverId=$approverId, timestamp=${DateTime.now().toIso8601String()}',
    );

    try {
      final rows = await _state.api.pending();
      debugPrint(
        '[ApproverHome] Pending approvals received: count=${rows.length}, filters={role: $approverRole, approverId: $approverId}',
      );
      if (!mounted) return;
      _streamController.add(rows);
      setState(() {
        _pending = rows;
        _loading = false;
        _error = null;
      });
    } catch (e, stackTrace) {
      final message = AsyncActionHelper.extractErrorMessage(e);
      debugPrint('[ApproverHome] ERROR querying pending approvals: $e\n$stackTrace');
      if (!mounted) return;
      // No swallowed exceptions! Visible error state if query fails
      setState(() {
        _error = message;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() => _fetchPending(showLoading: true);

  Future<void> _approveDirect(Map<String, dynamic> o) async {
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: 'Approve Directly',
      titleIcon: Icons.verified_rounded,
      content: const Text(
        'This action gives final approval and bypasses HOD approval. Continue?',
      ),
      actions: [
        AppTextButton(
          onPressed: () => Navigator.pop(context, false),
          label: 'Cancel',
        ),
        PrimaryButton(
          backgroundColor: AppTheme.success,
          onPressed: () => Navigator.pop(context, true),
          label: 'Approve Directly',
          fullWidth: false,
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    final outpassId = o['id']?.toString() ?? '';
    await AsyncActionHelper.run(
      context,
      action: () async {
        await _state.api.approveDirect(outpassId);
        await _fetchPending(showLoading: false);
      },
      successMessage: 'Outpass #${o['displayId'] ?? outpassId} approved directly',
    );
  }

  Future<void> _forwardToHod(Map<String, dynamic> o) async {
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: 'Approve & Forward to HOD',
      titleIcon: Icons.forward_rounded,
      content: const Text(
        'This request will be forwarded to the HOD for final approval. Continue?',
      ),
      actions: [
        AppTextButton(
          onPressed: () => Navigator.pop(context, false),
          label: 'Cancel',
        ),
        PrimaryButton(
          backgroundColor: AppTheme.tutorAccent,
          onPressed: () => Navigator.pop(context, true),
          label: 'Forward to HOD',
          fullWidth: false,
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    final outpassId = o['id']?.toString() ?? '';
    await AsyncActionHelper.run(
      context,
      action: () async {
        await _state.api.forwardToHod(outpassId);
        await _fetchPending(showLoading: false);
      },
      successMessage: 'Outpass #${o['displayId'] ?? outpassId} forwarded to HOD',
    );
  }

  Future<void> _approveHod(Map<String, dynamic> o) async {
    final s = (o['student'] as Map?)?.cast<String, dynamic>() ?? {};
    final studentName = s['name'] ?? 'Student';
    final passId = o['displayId'] ?? o['id'] ?? '';
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: 'Approve Outpass',
      titleIcon: Icons.verified_rounded,
      content: Text(
        'Are you sure you want to approve outpass #$passId for $studentName?',
      ),
      actions: [
        AppTextButton(
          onPressed: () => Navigator.pop(context, false),
          label: 'Cancel',
        ),
        PrimaryButton(
          backgroundColor: AppTheme.hodAccent,
          onPressed: () => Navigator.pop(context, true),
          label: 'Confirm Approval',
          fullWidth: false,
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    final outpassId = o['id']?.toString() ?? '';
    await AsyncActionHelper.run(
      context,
      action: () async {
        await _state.api.decide(outpassId, 'APPROVED');
        await _fetchPending(showLoading: false);
      },
      successMessage: 'Outpass #${o['displayId'] ?? outpassId} approved',
    );
  }

  Future<void> _reject(Map<String, dynamic> o) async {
    final reason = await _askReason();
    if (reason == null || !mounted) return;
    final outpassId = o['id']?.toString() ?? '';
    await AsyncActionHelper.run(
      context,
      action: () async {
        await _state.api.rejectOutpass(outpassId, reason);
        await _fetchPending(showLoading: false);
      },
      successMessage: 'Outpass #${o['displayId'] ?? outpassId} rejected',
    );
  }

  Future<String?> _askReason() {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          void confirm() {
            final text = controller.text.trim();
            if (text.isEmpty) {
              setDialogState(() {
                errorText = 'A rejection reason is mandatory';
              });
              return;
            }
            Navigator.pop(ctx, text);
          }

          return AppDialog(
            title: 'Rejection Reason',
            titleIcon: Icons.cancel_outlined,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => confirm(),
                  hintText: 'e.g. Internal examination scheduled',
                  labelText: 'Reason for rejection *',
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    errorText!,
                    style: const TextStyle(color: AppTheme.error, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              AppTextButton(onPressed: () => Navigator.pop(ctx), label: 'Cancel'),
              DestructiveButton(
                filled: true,
                onPressed: confirm,
                label: 'Confirm Rejection',
                fullWidth: false,
              ),
            ],
          );
        },
      ),
    );
  }

  void _inspectTicket(Map<String, dynamic> outpass) {
    showDialog<void>(
      context: context,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(ctx).pop(),
        },
        child: Dialog(
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
                    outpass: outpass,
                    enableTilt: true,
                    showStub: true,
                  ),
                ),
              ),
            ],
          ),
        ),
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
              padding: const EdgeInsets.all(AppSpacing.s8 - 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: AppRadii.roundedSm,
              ),
              child: Icon(AppTheme.roleIcon(_state.userRole), color: accent, size: 22),
            ),
            const SizedBox(width: AppSpacing.s8 + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$roleName Approvals',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _state.userName ?? 'Approver Dashboard',
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
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _refresh),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign out', onPressed: () => _state.logout()),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: AppLayout.maxDashboardWidth,
          padding: EdgeInsets.zero,
          child: _loading && _pending.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _pending.isEmpty
                  ? EmptyState(
                      icon: Icons.error_outline,
                      title: 'Unable to load approvals',
                      subtitle: _error ?? 'An unexpected error occurred. Please try again.',
                      action: SecondaryButton(
                        onPressed: _refresh,
                        label: 'Retry',
                        fullWidth: false,
                      ),
                    )
                  : _pending.isEmpty
                      ? const EmptyState(
                          icon: Icons.checklist_rtl_rounded,
                          title: 'All caught up!',
                          subtitle: 'No student outpasses waiting for your approval right now.',
                        )
                      : ListView.separated(
                          padding: AppLayout.screenPadding(context),
                          itemCount: _pending.length + (_error != null ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s12),
                          itemBuilder: (ctx, index) {
                            if (_error != null && index == 0) {
                              return Container(
                                padding: const EdgeInsets.all(AppSpacing.s12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: AppRadii.roundedSm,
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                    const SizedBox(width: AppSpacing.s8),
                                    Expanded(
                                      child: Text(
                                        'Sync error: $_error',
                                        style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                                      ),
                                    ),
                                    AppTextButton(
                                      onPressed: _refresh,
                                      label: 'Retry',
                                    ),
                                  ],
                                ),
                              );
                            }
                            final i = _error != null ? index - 1 : index;
                            final o = _pending[i];
                            final s = (o['student'] as Map?)?.cast<String, dynamic>() ?? {};
                            final isEmergency = (o['typeId']?.toString().toLowerCase() == 'emergency') ||
                                (o['type']?.toString().toUpperCase() == 'EMERGENCY');

                            return AppCard(
                              borderColor: isEmergency ? Colors.red.shade400 : null,
                              padding: const EdgeInsets.all(AppSpacing.s16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                s['name'] ?? 'Student',
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            if (isEmergency) ...[
                                              const SizedBox(width: AppSpacing.s8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade100,
                                                  borderRadius: AppRadii.roundedSm,
                                                  border: Border.all(color: Colors.red.shade300),
                                                ),
                                                child: Text(
                                                  'EMERGENCY',
                                                  style: TextStyle(
                                                    color: Colors.red.shade900,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.s8),
                                      StatusChip(status: o['status'] ?? 'PENDING_TUTOR'),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.s4),
                                  Text(
                                    '${s['registerNo'] ?? ''} · Dept: ${s['department'] ?? ''} · Sem ${s['semester'] ?? ''}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  const SizedBox(height: AppSpacing.s12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(AppSpacing.s12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceBg,
                                      borderRadius: AppRadii.roundedMd,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${o['purposeCategory']} · ${o['destination']}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        if (!isEmergency && o['purposeText'] != null && (o['purposeText'] as String).isNotEmpty) ...[
                                          const SizedBox(height: AppSpacing.s4),
                                          Text(
                                            'Note: ${o['purposeText']}',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isEmergency && o['purposeText'] != null && (o['purposeText'] as String).trim().isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.s8 + 2),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(AppSpacing.s12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: AppRadii.roundedMd,
                                        border: Border.all(color: Colors.red.shade300),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade800),
                                              const SizedBox(width: 6),
                                              Text(
                                                'EMERGENCY EXPLANATION',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  letterSpacing: 0.5,
                                                  color: Colors.red.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: AppSpacing.s4 + 2),
                                          Text(
                                            o['purposeText'].toString(),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.s4 + 2),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: AppTextButton(
                                      onPressed: () => _inspectTicket(o as Map<String, dynamic>),
                                      icon: Icons.confirmation_number_outlined,
                                      label: 'View Official Pass Ticket',
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.s8),
                                  if (isHod)
                                    AppButtonRow(
                                      sideBySideMobile: true,
                                      secondary: DestructiveButton(
                                        icon: Icons.close,
                                        label: 'Reject Request',
                                        onPressed: () => _reject(o),
                                      ),
                                      primary: PrimaryButton(
                                        backgroundColor: AppTheme.hodAccent,
                                        icon: Icons.check,
                                        label: 'Approve Request',
                                        onPressed: () => _approveHod(o),
                                      ),
                                    )
                                  else
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final isNarrow = constraints.maxWidth < 420;
                                        if (isNarrow) {
                                          return Column(
                                            children: [
                                              PrimaryButton(
                                                backgroundColor: AppTheme.success,
                                                icon: Icons.verified_rounded,
                                                label: 'Approve Directly',
                                                onPressed: () => _approveDirect(o),
                                              ),
                                              const SizedBox(height: AppSpacing.s8),
                                              SecondaryButton(
                                                color: AppTheme.tutorAccent,
                                                icon: Icons.forward_rounded,
                                                label: 'Approve & Forward to HOD',
                                                onPressed: () => _forwardToHod(o),
                                              ),
                                              const SizedBox(height: AppSpacing.s8),
                                              DestructiveButton(
                                                icon: Icons.close,
                                                label: 'Reject Request',
                                                onPressed: () => _reject(o),
                                              ),
                                            ],
                                          );
                                        }
                                        return Column(
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: PrimaryButton(
                                                    backgroundColor: AppTheme.success,
                                                    icon: Icons.verified_rounded,
                                                    label: 'Approve Directly',
                                                    onPressed: () => _approveDirect(o),
                                                  ),
                                                ),
                                                const SizedBox(width: AppSpacing.s8),
                                                Expanded(
                                                  child: SecondaryButton(
                                                    color: AppTheme.tutorAccent,
                                                    icon: Icons.forward_rounded,
                                                    label: 'Approve & Forward to HOD',
                                                    onPressed: () => _forwardToHod(o),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: AppSpacing.s8),
                                            DestructiveButton(
                                              icon: Icons.close,
                                              label: 'Reject Request',
                                              onPressed: () => _reject(o),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}
