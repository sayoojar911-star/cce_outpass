import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'theme/app_theme.dart';
import 'async_action_helper.dart';
import 'widgets/ticket_outpass.dart';
import 'widgets/request_receipt_card.dart';
import 'widgets/profile_photo_widget.dart';

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
          s == 'PENDING_TUTOR_APPROVAL' ||
          s == 'PENDING_HOD' ||
          s == 'PENDING_HOD_APPROVAL' ||
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
        .then((_) {
      if (mounted) _refresh();
    });
  }

  void _openProfileModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool uploading = false;
        String? modalError;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Student Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF702632),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ProfilePhotoWidget(
                      photoUrl: _state.userPhotoUrl,
                      radius: 54,
                      isUploading: uploading,
                      apiClient: _state.api,
                      onPhotoSelected: (result) async {
                        if (result.dataUri == null) return;
                        setModalState(() {
                          uploading = true;
                          modalError = null;
                        });
                        try {
                          await _state.updateProfilePhoto(result.dataUri!);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile photo updated successfully!'),
                                backgroundColor: Color(0xFF15803D),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (err) {
                          setModalState(() {
                            modalError = err.toString();
                          });
                        } finally {
                          if (context.mounted) {
                            setModalState(() {
                              uploading = false;
                            });
                          }
                        }
                      },
                      onPhotoRemoved: () async {
                        setModalState(() {
                          uploading = true;
                          modalError = null;
                        });
                        try {
                          await _state.removeProfilePhoto();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile photo removed'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (err) {
                          setModalState(() {
                            modalError = err.toString();
                          });
                        } finally {
                          if (context.mounted) {
                            setModalState(() {
                              uploading = false;
                            });
                          }
                        }
                      },
                      onError: (err) {
                        setModalState(() {
                          modalError = err;
                        });
                      },
                    ),
                    if (modalError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          modalError!,
                          style: const TextStyle(color: AppTheme.errorRed, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      _state.userName ?? 'Student',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dept: ${_state.userDepartment ?? 'N/A'} · Year: ${_state.userYear ?? 'N/A'}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    if (_state.userMobile != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '+91 ${_state.userMobile}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                    const SizedBox(height: 20),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeOutpass;
    final past = _outpasses.where((o) => o != active).toList();

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _openProfileModal,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.studentAccent, width: 1.5),
                  ),
                  child: ClipOval(
                    child: _state.userPhotoUrl != null && _state.userPhotoUrl!.isNotEmpty
                        ? Image.network(
                            _state.api.resolveMediaUrl(_state.userPhotoUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => const Icon(Icons.school, color: AppTheme.studentAccent, size: 20),
                          )
                        : const Icon(Icons.school, color: AppTheme.studentAccent, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _state.userName ?? 'Student Portal',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'CCE Outpass · Student',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _refresh),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign out', onPressed: () => _state.logout()),
        ],
      ),
      body: _loading && _outpasses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _outpasses.isEmpty
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Unable to load outpasses',
                  subtitle: _error ?? 'An unexpected error occurred. Please try again.',
                  action: OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                )
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
      return ResponsiveContainer(
        maxWidth: AppLayout.maxFormWidth,
        child: EmptyState(
          icon: Icons.badge_outlined,
          title: 'No active outpass',
          subtitle: 'Need to step out of campus? Create an outpass request below.',
          action: PrimaryButton(
            backgroundColor: AppTheme.studentAccent,
            onPressed: _openRequestForm,
            icon: Icons.add,
            label: 'Request New Outpass',
            fullWidth: false,
          ),
        ),
      );
    }

    return ResponsiveContainer(
      maxWidth: AppLayout.maxPassWidth,
      padding: EdgeInsets.zero,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppLayout.screenPadding(context),
          child: Column(
            children: [
              TicketOutpass(
                outpass: active,
                enableTilt: true,
                showStub: true,
                animatePrint: true,
                onStatusChanged: _refresh,
              ),
              const SizedBox(height: AppSpacing.s24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryView(List<dynamic> past) {
    if (past.isEmpty) {
      return const ResponsiveContainer(
        maxWidth: AppLayout.maxDashboardWidth,
        child: EmptyState(
          icon: Icons.history,
          title: 'No past outpasses',
          subtitle: 'Completed, expired, or cancelled passes will appear here.',
        ),
      );
    }

    return ResponsiveContainer(
      maxWidth: AppLayout.maxDashboardWidth,
      padding: EdgeInsets.zero,
      child: ListView.separated(
        padding: AppLayout.screenPadding(context),
        itemCount: past.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s8),
        itemBuilder: (ctx, i) {
          final o = past[i] as Map<String, dynamic>;
          final isEmergency = (o['typeId']?.toString().toLowerCase() == 'emergency') ||
              (o['type']?.toString().toUpperCase().contains('EMERGENCY') == true);
          return AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QrScreen(
                    outpassId: o['id'] as String,
                    initialOutpass: o,
                  ),
                ),
              );
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${o['destination']} (${o['displayId'] ?? ''})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (isEmergency)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade700,
                                borderRadius: AppRadii.roundedSm,
                              ),
                              child: const Text('EMERGENCY',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Builder(
                        builder: (_) {
                          final reqExit = o['requestedExitAt']?.toString() ?? '';
                          final exitDate = reqExit.length >= 10 ? reqExit.substring(0, 10) : reqExit;
                          return Text(
                            '${o['purposeCategory']} · $exitDate',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                StatusChip(status: o['status'] ?? 'CANCELLED'),
              ],
            ),
          );
        },
      ),
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
  final _formKey = GlobalKey<FormState>();
  final _destination = TextEditingController();
  final _purposeText = TextEditingController();
  final _destinationFocusNode = FocusNode();
  final _purposeFocusNode = FocusNode();
  String? _purposeCategory;
  String? _type;
  DateTime _exit = DateTime.now().add(const Duration(minutes: 15));
  DateTime _ret = DateTime.now().add(const Duration(hours: 3));
  bool _busy = false;
  String? _error;
  bool _initializedDropdowns = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _exit = now.add(const Duration(minutes: 15));
    _ret = now.add(const Duration(hours: 3));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedDropdowns) {
      final appState = AppStateScope.maybeOf(context);
      if (appState != null) {
        final activeCategories = appState.purposeCategories
            .where((c) => c['active'] != false)
            .map((c) => c['label'].toString())
            .toList();
        if (activeCategories.isNotEmpty) {
          _purposeCategory = activeCategories.first;
        }

        final activeTypes = appState.outpassTypes
            .where((t) => t['active'] != false)
            .toList();
        if (activeTypes.isNotEmpty) {
          final normalType = activeTypes.firstWhere(
            (t) => (t['id'] ?? '').toString().toLowerCase() == 'normal',
            orElse: () => activeTypes.first,
          );
          _type = (normalType['id'] ?? 'normal').toString().toLowerCase();
        }
        _initializedDropdowns = true;
      }
    }
  }

  @override
  void dispose() {
    _destination.dispose();
    _purposeText.dispose();
    _destinationFocusNode.dispose();
    _purposeFocusNode.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month';
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
    if (time == null || !mounted) return;

    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isExit) {
        _exit = combined;
        if (!_ret.isAfter(_exit)) {
          _ret = _exit.add(const Duration(hours: 2));
        }
      } else {
        _ret = combined;
      }
    });
  }

  Future<void> _submit() async {
    if (_busy) return;

    final form = _formKey.currentState;
    if (form != null && !form.validate()) {
      return;
    }

    final destination = _destination.text.trim();
    if (destination.isEmpty) {
      setState(() => _error = 'Please provide a destination');
      return;
    }

    final category = (_purposeCategory ?? '').trim();
    if (category.isEmpty) {
      setState(() => _error = 'Please select a purpose category');
      return;
    }

    final outpassType = (_type ?? '').trim();
    if (outpassType.isEmpty) {
      setState(() => _error = 'Please select an outpass type');
      return;
    }

    final exitTime = _exit;
    final returnTime = _ret;

    if (!returnTime.isAfter(exitTime)) {
      setState(() => _error = 'Expected return time must be after the requested exit time');
      return;
    }

    if (returnTime.isBefore(DateTime.now())) {
      setState(() => _error = 'Expected return time cannot be in the past');
      return;
    }

    final appState = AppStateScope.maybeOf(context);
    if (appState == null) {
      debugPrint('[RequestFormScreen._submit] ERROR: AppStateScope is null in current BuildContext');
      setState(() => _error = 'Session expired or not found. Please log in again.');
      return;
    }

    final selectedTypeId = (_type ?? 'normal').toLowerCase().trim();
    final matchingType = appState.outpassTypes.firstWhere(
      (t) => (t['id'] ?? '').toString().toLowerCase() == selectedTypeId,
      orElse: () => {
        'id': selectedTypeId,
        'label': selectedTypeId == 'emergency' ? 'Emergency (Direct to HOD)' : 'Normal (Tutor -> HOD)',
        'approvalChain': selectedTypeId == 'emergency' ? ['hod'] : ['tutor', 'hod'],
        'requiresExplanation': selectedTypeId == 'emergency',
      },
    );

    final isEmergency = selectedTypeId == 'emergency' || matchingType['requiresExplanation'] == true;
    final details = _purposeText.text.trim();

    if (!isEmergency && (appState.userTutorId == null || appState.userTutorId!.trim().isEmpty)) {
      debugPrint('[RequestFormScreen._submit] BLOCKED: Student has no tutor assigned (userTutorId is null/empty)');
      setState(() => _error = 'No tutor assigned, contact admin');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No tutor assigned, contact admin'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    if (isEmergency && details.length < 15) {
      setState(() => _error = 'Please explain the emergency (at least 15 characters required)');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    debugPrint('[RequestFormScreen] Selected type id: $selectedTypeId');
    debugPrint('[RequestFormScreen] Fetched type config: $matchingType');
    debugPrint('[RequestFormScreen] Approval chain: ${matchingType['approvalChain']}');
    debugPrint('[RequestFormScreen] Student tutorId: ${appState.userTutorId}');

    try {
      final createdPass = await appState.api.createOutpass(
        requestedExitAt: exitTime.toIso8601String(),
        expectedReturnAt: returnTime.toIso8601String(),
        destination: destination,
        purposeCategory: category,
        purposeText: details.isEmpty ? null : details,
        type: selectedTypeId,
      );

      debugPrint('[RequestFormScreen] Outpass document created successfully: $createdPass');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Outpass request submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RequestReceiptScreen(
            outpass: createdPass,
            onViewRequest: () => Navigator.of(context).pop(true),
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('[RequestFormScreen._submit] ERROR: $e');
      debugPrint('[RequestFormScreen._submit] STACK TRACE:\n$stackTrace');
      if (mounted) {
        final message = AsyncActionHelper.extractErrorMessage(e);
        setState(() {
          _error = message;
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final categories = appState.purposeCategories
        .where((c) => c['active'] != false)
        .toList();
    final outpassTypes = appState.outpassTypes
        .where((t) => t['active'] != false)
        .toList();
    final isEmergency = (_type ?? '').toLowerCase() == 'emergency';

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_busy && !_purposeFocusNode.hasFocus) {
            _submit();
          }
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_busy && !_purposeFocusNode.hasFocus) {
            _submit();
          }
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_busy) Navigator.of(context).maybePop();
        },
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: const Text('Request Outpass')),
        body: SafeArea(
          child: ResponsiveContainer(
            maxWidth: AppLayout.maxFormWidth,
            child: SingleChildScrollView(
              child: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (categories.isEmpty || outpassTypes.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: AppRadii.roundedSm,
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                              const SizedBox(width: AppSpacing.s8),
                              const Expanded(
                                child: Text(
                                  'No dynamic categories or outpass types are configured in the system. Please contact the administrator.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(1),
                        child: AppTextField(
                          controller: _destination,
                          focusNode: _destinationFocusNode,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _purposeFocusNode.requestFocus(),
                          labelText: 'Destination (e.g. Market / Clinic / Home)',
                          prefixIcon: const Icon(Icons.place_outlined),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Destination is required';
                            }
                            return null;
                          },
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.fieldGap),
                      AppDropdown<String>(
                        value: _purposeCategory,
                        labelText: 'Purpose Category',
                        prefixIcon: const Icon(Icons.category_outlined),
                        items: categories.map<DropdownMenuItem<String>>((c) {
                          final label = (c['label'] ?? '').toString();
                          return DropdownMenuItem<String>(
                            value: label,
                            child: Text(label),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _purposeCategory = v);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.fieldGap),
                      AppDropdown<String>(
                        value: _type,
                        labelText: 'Outpass Type & Workflow',
                        prefixIcon: const Icon(Icons.route_outlined),
                        items: outpassTypes.map<DropdownMenuItem<String>>((t) {
                          final id = (t['id'] ?? '').toString().toLowerCase();
                          final label = (t['label'] ?? id).toString();
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(label),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _type = v.toLowerCase());
                          }
                        },
                      ),
                      if (isEmergency) ...[
                        const SizedBox(height: AppSpacing.s12),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: AppRadii.roundedSm,
                            border: Border.all(color: Colors.amber.shade400),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 22),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: Text(
                                  'Emergency requests go directly to the HOD. Please explain the emergency clearly in the details below.',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!isEmergency && (appState.userTutorId == null || appState.userTutorId!.trim().isEmpty)) ...[
                        const SizedBox(height: AppSpacing.s12),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: AppRadii.roundedSm,
                            border: Border.all(color: Colors.red.shade400),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade900, size: 22),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: Text(
                                  'No tutor assigned, contact admin. You cannot submit normal outpass requests without an assigned faculty tutor.',
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.fieldGap),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(4),
                        child: Focus(
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent &&
                                (event.logicalKey == LogicalKeyboardKey.enter ||
                                    event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
                                (HardwareKeyboard.instance.isControlPressed ||
                                    HardwareKeyboard.instance.isMetaPressed)) {
                              if (!_busy) _submit();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextFormField(
                            controller: _purposeText,
                            focusNode: _purposeFocusNode,
                            decoration: InputDecoration(
                              labelText: isEmergency
                                  ? 'Explain the emergency (required)'
                                  : 'Additional Details (optional)',
                              prefixIcon: Icon(isEmergency ? Icons.emergency_outlined : Icons.notes_outlined),
                              helperText: 'Press Ctrl+Enter (⌘+Enter) to submit',
                              helperStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s16,
                                vertical: AppSpacing.s12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: AppRadii.roundedMd,
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: AppRadii.roundedMd,
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: AppRadii.roundedMd,
                                borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
                              ),
                            ),
                            maxLines: 2,
                            validator: (val) {
                              if (isEmergency) {
                                final trimmed = (val ?? '').trim();
                                if (trimmed.isEmpty) {
                                  return 'Please explain the emergency (at least 15 characters)';
                                }
                                if (trimmed.length < 15) {
                                  return 'Please provide more details (at least 15 characters required)';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.fieldGap),
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              icon: Icons.schedule,
                              onPressed: () => _pick(_exit, true),
                              label: 'Exit: ${_formatTime(_exit)} (${_formatDate(_exit)})',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.buttonGap),
                          Expanded(
                            child: SecondaryButton(
                              icon: Icons.timer_outlined,
                              onPressed: () => _pick(_ret, false),
                              label: 'Return: ${_formatTime(_ret)} (${_formatDate(_ret)})',
                            ),
                          ),
                        ],
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s16),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.s12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: AppRadii.roundedSm,
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: AppSpacing.s8),
                                Expanded(
                                  child: Text(
                                    _error ?? 'An error occurred',
                                    style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sectionGap),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(5),
                        child: PrimaryButton(
                          backgroundColor: AppTheme.studentAccent,
                          onPressed: _busy ? null : _submit,
                          loading: _busy,
                          icon: Icons.send_rounded,
                          label: 'Submit for Approval',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// DIGITAL TICKET / QR SCREEN
class QrScreen extends StatefulWidget {
  const QrScreen({super.key, required this.outpassId, this.initialOutpass});

  final String outpassId;
  final Map<String, dynamic>? initialOutpass;

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  Map<String, dynamic>? _outpass;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _outpass = widget.initialOutpass;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    if (_outpass == null) setState(() => _loading = true);
    try {
      final res = await AppStateScope.of(context).api.get('/outpasses/${widget.outpassId}');
      if (mounted) {
        setState(() {
          _outpass = (res as Map).cast<String, dynamic>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('Official Digital Pass'),
        centerTitle: true,
        actions: [
          if (_outpass != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Pass',
              onPressed: _fetchDetails,
            ),
        ],
      ),
      body: SafeArea(
        child: _loading && _outpass == null
            ? const Center(child: CircularProgressIndicator())
            : ResponsiveContainer(
                maxWidth: AppLayout.maxPassWidth,
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(
                  padding: AppLayout.screenPadding(context),
                  child: _outpass == null
                      ? const Center(child: Text('Unable to load pass details'))
                      : TicketOutpass(
                          outpass: _outpass ?? const <String, dynamic>{},
                          enableTilt: true,
                          showStub: true,
                          animatePrint: true,
                          onStatusChanged: _fetchDetails,
                        ),
                ),
              ),
      ),
    );
  }
}
