import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_state.dart';
import 'theme/app_theme.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _currentIndex = 0;
  bool _busy = false;

  List<dynamic> _users = [];
  List<dynamic> _departments = [];
  List<dynamic> _outpasses = [];
  Map<String, dynamic> _settings = {};
  List<dynamic> _auditLogs = [];

  AppState get _state => AppStateScope.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAll();
    });
  }

  Future<void> _loadAll() async {
    setState(() => _busy = true);
    try {
      final u = await _state.api.adminGetUsers();
      final d = await _state.api.adminGetDepartments();
      final o = await _state.api.adminGetOutpasses();
      final s = await _state.api.adminGetSettings();
      final a = await _state.api.adminGetAuditLog(limit: 50);
      if (mounted) {
        setState(() {
          _users = u;
          _departments = d;
          _outpasses = o;
          _settings = s;
          _auditLogs = a;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                color: AppTheme.adminAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings, color: AppTheme.adminAccent, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin Console', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('CCE Outpass Control Panel', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh data',
            onPressed: _busy ? null : _loadAll,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _state.logout(),
          ),
        ],
      ),
      body: _busy && _users.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentIndex,
              children: [
                _AdminDashboardTab(
                  users: _users,
                  outpasses: _outpasses,
                  auditLogs: _auditLogs,
                  onNavigate: (i) => setState(() => _currentIndex = i),
                ),
                _AdminPeopleTab(
                  users: _users,
                  departments: _departments,
                  onReload: _loadAll,
                ),
                _AdminDepartmentsTab(
                  departments: _departments,
                  users: _users,
                  onReload: _loadAll,
                ),
                _AdminOutpassMonitorTab(
                  outpasses: _outpasses,
                  departments: _departments,
                  onReload: _loadAll,
                ),
                _AdminSettingsTab(
                  settings: _settings,
                  onReload: _loadAll,
                ),
                _AdminAuditTab(
                  auditLogs: _auditLogs,
                  onReload: _loadAll,
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'People',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment),
            label: 'Departments',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_search_outlined),
            selectedIcon: Icon(Icons.manage_search),
            label: 'Monitor',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Audit Log',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. DASHBOARD TAB
// ==========================================
class _AdminDashboardTab extends StatelessWidget {
  const _AdminDashboardTab({
    required this.users,
    required this.outpasses,
    required this.auditLogs,
    required this.onNavigate,
  });

  final List<dynamic> users;
  final List<dynamic> outpasses;
  final List<dynamic> auditLogs;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final students = users.where((u) => u['role'] == 'STUDENT' && u['status'] != 'DELETED').length;
    final tutors = users.where((u) => u['role'] == 'TUTOR' && u['status'] != 'DELETED').length;
    final hods = users.where((u) => u['role'] == 'HOD' && u['status'] != 'DELETED').length;
    final guards = users.where((u) => u['role'] == 'GUARD' && u['status'] != 'DELETED').length;
    final admins = users.where((u) => u['role'] == 'ADMIN' && u['status'] != 'DELETED').length;

    final pending = outpasses.where((o) => (o['status'] as String).startsWith('PENDING')).length;
    final approved = outpasses.where((o) => o['status'] == 'APPROVED').length;
    final exited = outpasses.where((o) => o['status'] == 'EXITED').length;
    final returned = outpasses.where((o) => o['status'] == 'RETURNED').length;

    return SingleChildScrollView(
      padding: AppTheme.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Card(
            color: AppTheme.adminAccent,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'System Overview',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${users.where((u) => u['status'] != 'DELETED').length} registered active accounts',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.adminAccent,
                    ),
                    onPressed: () => onNavigate(1),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Add Person'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // User Counts Section
          const Text('Campus Population', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final itemWidth = (constraints.maxWidth - 20) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(width: itemWidth, child: _StatCard(title: 'Students', count: students, color: AppTheme.studentAccent, icon: Icons.school)),
                  SizedBox(width: itemWidth, child: _StatCard(title: 'Tutors', count: tutors, color: AppTheme.tutorAccent, icon: Icons.supervisor_account)),
                  SizedBox(width: itemWidth, child: _StatCard(title: 'HODs', count: hods, color: AppTheme.hodAccent, icon: Icons.account_balance)),
                  SizedBox(width: itemWidth, child: _StatCard(title: 'Guards', count: guards, color: AppTheme.guardAccent, icon: Icons.security)),
                  SizedBox(width: itemWidth, child: _StatCard(title: 'Admins', count: admins, color: AppTheme.adminAccent, icon: Icons.admin_panel_settings)),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Today's Outpasses Section
          const Text("Today's Outpasses by Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final itemWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(width: itemWidth, child: _StatCard(title: 'Pending Approvals', count: pending, color: AppTheme.statusPendingText, icon: Icons.hourglass_top)),
                  SizedBox(width: itemWidth, child: _StatCard(title: 'Approved Passes', count: approved, color: AppTheme.statusApprovedText, icon: Icons.check_circle)),
                  SizedBox(width: itemWidth, child: _StatCard(title: 'Currently Exited', count: exited, color: AppTheme.statusExitedText, icon: Icons.logout)),
                  SizedBox(width: itemWidth, child: _StatCard(title: 'Safely Returned', count: returned, color: AppTheme.statusReturnedText, icon: Icons.task_alt)),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Recent Activity Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent System Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              TextButton(
                onPressed: () => onNavigate(5),
                child: const Text('View Audit Log →'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (auditLogs.isEmpty)
            const EmptyState(
              icon: Icons.history,
              title: 'No activity recorded yet',
              subtitle: 'Activity will appear here as users take actions',
            )
          else
            ...auditLogs.take(5).map((a) {
              final action = (a['action'] as String? ?? '').replaceAll('_', ' ');
              final at = a['at'] != null ? DateTime.parse(a['at']).toLocal().toString().substring(0, 16) : '';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.surfaceVariant,
                    child: Icon(Icons.bolt, size: 18, color: AppTheme.adminAccent),
                  ),
                  title: Text(action, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text('By ${a['actorRole'] ?? 'SYSTEM'} · $at', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String title;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. PEOPLE TAB (5 TABS + CRUD + ASSIGN TUTOR)
// ==========================================
class _AdminPeopleTab extends StatefulWidget {
  const _AdminPeopleTab({
    required this.users,
    required this.departments,
    required this.onReload,
  });

  final List<dynamic> users;
  final List<dynamic> departments;
  final VoidCallback onReload;

  @override
  State<_AdminPeopleTab> createState() => _AdminPeopleTabState();
}

class _AdminPeopleTabState extends State<_AdminPeopleTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';
  String? _deptFilter;
  String? _statusFilter;

  final Set<String> _selectedStudentIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddPersonDialog({Map<String, dynamic>? editUser}) {
    showDialog(
      context: context,
      builder: (ctx) => _PersonFormDialog(
        editUser: editUser,
        departments: widget.departments,
        allUsers: widget.users,
        onSuccess: widget.onReload,
      ),
    );
  }

  void _showBulkAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _BulkAddDialog(
        onSuccess: widget.onReload,
      ),
    );
  }

  void _showAssignTutorDialog({List<String>? preselectedIds}) {
    final studentIds = preselectedIds ?? _selectedStudentIds.toList();
    if (studentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one student to assign a tutor')),
      );
      return;
    }

    final tutors = widget.users.where((u) => u['role'] == 'TUTOR' && u['status'] == 'ACTIVE').toList();
    String? chosenTutorId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDState) => AlertDialog(
          title: Text('Assign Tutor (${studentIds.length} students)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select the faculty tutor for the chosen students:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: chosenTutorId,
                decoration: const InputDecoration(labelText: 'Tutor'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Remove Tutor Assignment')),
                  ...tutors.map((t) => DropdownMenuItem<String>(
                        value: t['id'] as String,
                        child: Text('${t['name']} (${t['department'] ?? 'Dept'})'),
                      )),
                ],
                onChanged: (v) => setDState(() => chosenTutorId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final state = AppStateScope.of(context);
                try {
                  final count = await state.api.adminAssignTutors(studentIds, chosenTutorId);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    setState(() => _selectedStudentIds.clear());
                    widget.onReload();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Assigned tutor for $count student(s)')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text('Are you sure you want to remove ${user['name']} (${user['mobile']})? This user will no longer be able to log in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final state = AppStateScope.of(context);
      try {
        await state.api.adminDeleteUser(user['id']);
        widget.onReload();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _toggleDeactivate(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user['status'] == 'INACTIVE' ? 'Reactivate User?' : 'Deactivate User?'),
        content: Text(user['status'] == 'INACTIVE'
            ? 'Allow ${user['name']} to log in again?'
            : 'Deactivating will block ${user['name']} from logging in until reactivated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(user['status'] == 'INACTIVE' ? 'Reactivate' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final state = AppStateScope.of(context);
      final newStatus = user['status'] == 'INACTIVE' ? 'ACTIVE' : 'INACTIVE';
      try {
        await state.api.adminUpdateUser(user['id'], {'status': newStatus});
        widget.onReload();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeUsers = widget.users.where((u) => u['status'] != 'DELETED').toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total: ${activeUsers.length} members',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showBulkAddDialog,
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Bulk CSV'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _showAddPersonDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Person'),
                    ),
                  ],
                ),
              ),

              // Search and filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search name or phone...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _search = v.trim()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _deptFilter,
                        decoration: const InputDecoration(isDense: true, labelText: 'Dept'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Depts')),
                          ...widget.departments.map((d) => DropdownMenuItem<String>(
                                value: d['code'] as String,
                                child: Text(d['code'] as String),
                              )),
                        ],
                        onChanged: (v) => setState(() => _deptFilter = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        decoration: const InputDecoration(isDense: true, labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All')),
                          DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                          DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                        ],
                        onChanged: (v) => setState(() => _statusFilter = v),
                      ),
                    ),
                  ],
                ),
              ),

              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppTheme.adminAccent,
                unselectedLabelColor: AppTheme.textMuted,
                indicatorColor: AppTheme.adminAccent,
                tabs: [
                  Tab(text: 'Students (${activeUsers.where((u) => u['role'] == 'STUDENT').length})'),
                  Tab(text: 'Tutors (${activeUsers.where((u) => u['role'] == 'TUTOR').length})'),
                  Tab(text: 'HODs (${activeUsers.where((u) => u['role'] == 'HOD').length})'),
                  Tab(text: 'Guards (${activeUsers.where((u) => u['role'] == 'GUARD').length})'),
                  Tab(text: 'Admins (${activeUsers.where((u) => u['role'] == 'ADMIN').length})'),
                ],
              ),
            ],
          ),
        ),

        // Action banner for batch tutor assignment
        if (_selectedStudentIds.isNotEmpty)
          Container(
            color: AppTheme.primaryLight.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_selectedStudentIds.length} student(s) selected',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedStudentIds.clear()),
                  child: const Text('Clear'),
                ),
                FilledButton.icon(
                  onPressed: () => _showAssignTutorDialog(),
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Assign Tutor'),
                ),
              ],
            ),
          ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRoleList('STUDENT'),
              _buildRoleList('TUTOR'),
              _buildRoleList('HOD'),
              _buildRoleList('GUARD'),
              _buildRoleList('ADMIN'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleList(String role) {
    final list = widget.users.where((u) {
      if (u['status'] == 'DELETED') return false;
      if (u['role'] != role) return false;

      final name = (u['name'] as String? ?? '').toLowerCase();
      final phone = (u['mobile'] as String? ?? '').toLowerCase();
      final q = _search.toLowerCase();
      if (_search.isNotEmpty && !name.contains(q) && !phone.contains(q)) return false;

      if (_deptFilter != null && u['department'] != _deptFilter) return false;
      if (_statusFilter != null && u['status'] != _statusFilter) return false;

      return true;
    }).toList();

    if (list.isEmpty) {
      return EmptyState(
        icon: AppTheme.roleIcon(role),
        title: 'No ${role.toLowerCase()}s match',
        subtitle: 'Click "Add Person" or adjust your search filters.',
      );
    }

    return ListView.separated(
      padding: AppTheme.screenPadding,
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final u = list[i];
        final isInactive = u['status'] == 'INACTIVE';
        final isStudent = role == 'STUDENT';
        final studentInfo = u['student'] as Map? ?? {};
        final isSelected = _selectedStudentIds.contains(u['id']);

        return Card(
          child: ListTile(
            leading: isStudent
                ? Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedStudentIds.add(u['id']);
                        } else {
                          _selectedStudentIds.remove(u['id']);
                        }
                      });
                    },
                  )
                : CircleAvatar(
                    backgroundColor: isInactive
                        ? Colors.grey.shade300
                        : AppTheme.roleColor(role).withOpacity(0.15),
                    child: Icon(
                      AppTheme.roleIcon(role),
                      color: isInactive ? Colors.grey : AppTheme.roleColor(role),
                      size: 20,
                    ),
                  ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    u['name'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: isInactive ? TextDecoration.lineThrough : null,
                      color: isInactive ? AppTheme.textMuted : null,
                    ),
                  ),
                ),
                if (isInactive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Deactivated', style: TextStyle(fontSize: 10, color: Colors.red)),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${u['mobile']} · Dept: ${u['department'] ?? 'None'}${u['year'] != null ? ' · Year ${u['year']}' : ''}${u['division'] != null ? ' (${u['division']})' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                if (isStudent) ...[
                  Text(
                    'Reg: ${studentInfo['registerNo'] ?? '-'} · Year ${u['year'] ?? studentInfo['year'] ?? '-'} ${u['division'] != null ? '(${u['division']})' : ''} · Tutor: ${studentInfo['tutor']?['name'] ?? 'Not assigned'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: studentInfo['tutor'] != null ? AppTheme.tutorAccent : Colors.orange.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') {
                  _showAddPersonDialog(editUser: u);
                } else if (val == 'assign_tutor') {
                  _showAssignTutorDialog(preselectedIds: [u['id']]);
                } else if (val == 'toggle') {
                  _toggleDeactivate(u);
                } else if (val == 'delete') {
                  _deleteUser(u);
                }
              },
              itemBuilder: (c) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit Person & Role')),
                if (isStudent)
                  const PopupMenuItem(value: 'assign_tutor', child: Text('Assign Tutor')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(isInactive ? 'Reactivate' : 'Deactivate'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Dialog: Add/Edit Person (Role-specific fields & validation)
class _PersonFormDialog extends StatefulWidget {
  const _PersonFormDialog({
    this.editUser,
    required this.departments,
    required this.allUsers,
    required this.onSuccess,
  });

  final Map<String, dynamic>? editUser;
  final List<dynamic> departments;
  final List<dynamic> allUsers;
  final VoidCallback onSuccess;

  @override
  State<_PersonFormDialog> createState() => _PersonFormDialogState();
}

class _PersonFormDialogState extends State<_PersonFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _regNoCtrl = TextEditingController();

  late String _role;
  String? _department;
  int? _year; // 1, 2, 3, 4
  String? _division;
  String? _tutorId;
  bool _replaceHod = false;

  bool _busy = false;
  String? _errorMessage;

  static const _yearLabels = {
    1: '1st Year',
    2: '2nd Year',
    3: '3rd Year',
    4: '4th Year',
  };

  @override
  void initState() {
    super.initState();
    final u = widget.editUser;
    if (u != null) {
      _role = u['role'] ?? 'STUDENT';
      _nameCtrl.text = u['name'] ?? '';
      _phoneCtrl.text = u['mobile'] ?? '';
      _department = u['department'] as String?;
      _year = u['year'] as int?;
      _division = u['division'] as String?;

      final student = u['student'] as Map? ?? {};
      _tutorId = student['tutorId'] as String?;
      _regNoCtrl.text = (student['registerNo'] ?? '') as String;
      if (_year == null && student['year'] != null) {
        _year = student['year'] as int?;
      }
      if (_division == null && student['division'] != null) {
        _division = student['division'] as String?;
      }
    } else {
      _role = 'STUDENT';
      if (widget.departments.isNotEmpty) {
        _department = widget.departments.first['code'] as String?;
      }
      _year = 1;
    }

    _phoneCtrl.addListener(() => setState(() {}));
    _nameCtrl.addListener(() => setState(() {}));
    _ensureValidDepartmentAndDivisions();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _regNoCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _currentDepartmentObj {
    if (_department == null) return null;
    for (final d in widget.departments) {
      if (d['code'] == _department) return d as Map<String, dynamic>;
    }
    return null;
  }

  List<String> get _currentDivisionNames {
    final dept = _currentDepartmentObj;
    if (dept == null) return [];
    final divs = (dept['divisions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return divs.map((d) => d['name'].toString()).toList();
  }

  void _ensureValidDepartmentAndDivisions() {
    final divNames = _currentDivisionNames;
    if (divNames.isNotEmpty) {
      if (_division == null || !divNames.contains(_division)) {
        _division = divNames.first;
      }
    } else {
      _division = null;
    }
  }

  void _onDepartmentChanged(String? newDept) {
    setState(() {
      _department = newDept;
      _division = null;
      _tutorId = null;
      _ensureValidDepartmentAndDivisions();
    });
  }

  void _onRoleChanged(String newRole) {
    setState(() {
      _role = newRole;
      _replaceHod = false;
      if (_role == 'GUARD' || _role == 'ADMIN') {
        _department = null;
        _year = null;
        _division = null;
        _tutorId = null;
      } else if (_role == 'HOD') {
        if (_department == null && widget.departments.isNotEmpty) {
          _department = widget.departments.first['code'] as String?;
        }
        _year = null;
        _division = null;
        _tutorId = null;
      } else if (_role == 'TUTOR') {
        if (_department == null && widget.departments.isNotEmpty) {
          _department = widget.departments.first['code'] as String?;
        }
        _year ??= 1;
        _tutorId = null;
        _ensureValidDepartmentAndDivisions();
      } else if (_role == 'STUDENT') {
        if (_department == null && widget.departments.isNotEmpty) {
          _department = widget.departments.first['code'] as String?;
        }
        _year ??= 1;
        _ensureValidDepartmentAndDivisions();
      }
    });
  }

  Map<String, dynamic>? get _existingActiveHod {
    if (_role != 'HOD' || _department == null) return null;
    final isEdit = widget.editUser != null;
    for (final u in widget.allUsers) {
      if (u['role'] == 'HOD' &&
          u['status'] == 'ACTIVE' &&
          u['department'] == _department &&
          (!isEdit || u['id'] != widget.editUser!['id'])) {
        return u as Map<String, dynamic>;
      }
    }
    return null;
  }

  List<dynamic> get _availableTutors {
    return widget.allUsers.where((u) {
      if (u['role'] != 'TUTOR' || u['status'] == 'DELETED') return false;
      if (u['department'] != _department) return false;
      if (u['year'] != _year) return false;
      final divNames = _currentDivisionNames;
      if (divNames.isNotEmpty) {
        if (u['division'] != _division) return false;
      }
      return true;
    }).toList();
  }

  bool get _isValid {
    final name = _nameCtrl.text.trim();
    final phone = normalizeMobilePhone(_phoneCtrl.text);
    if (name.isEmpty || phone.length != 10) return false;

    if (_role == 'GUARD' || _role == 'ADMIN') {
      return true;
    }

    if (widget.departments.isEmpty) return false;
    if (_department == null || _department!.isEmpty) return false;

    if (_role == 'HOD') {
      if (_existingActiveHod != null && !_replaceHod) return false;
      return true;
    }

    if (_role == 'TUTOR' || _role == 'STUDENT') {
      if (_year == null || _year! < 1 || _year! > 4) return false;
      final divNames = _currentDivisionNames;
      if (divNames.isNotEmpty && (_division == null || _division!.isEmpty)) {
        return false;
      }
      return true;
    }

    return false;
  }

  Future<void> _submit() async {
    final normPhone = normalizeMobilePhone(_phoneCtrl.text);
    if (normPhone.length != 10) {
      setState(() => _errorMessage = 'Enter a valid 10-digit mobile number');
      return;
    }

    final isEdit = widget.editUser != null;
    final exists = widget.allUsers.any((u) =>
        u['mobile'] == normPhone && (!isEdit || u['id'] != widget.editUser!['id']));
    if (exists) {
      setState(() => _errorMessage = 'This 10-digit phone number is already registered');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final state = AppStateScope.of(context);
    try {
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'mobile': normPhone,
        'role': _role,
        if (_role != 'GUARD' && _role != 'ADMIN') 'department': _department,
        if (_role == 'TUTOR' || _role == 'STUDENT') ...{
          'year': _year,
          if (_currentDivisionNames.isNotEmpty) 'division': _division,
        },
        if (_role == 'STUDENT') ...{
          if (_tutorId != null) 'tutorId': _tutorId,
          if (_regNoCtrl.text.trim().isNotEmpty)
            'registerNo': _regNoCtrl.text.trim(),
        },
        if (_role == 'HOD' && _replaceHod) 'replaceHod': true,
      };

      if (isEdit) {
        await state.api
            .adminUpdateUser(widget.editUser!['id'], payload)
            .timeout(const Duration(seconds: 15));
      } else {
        await state.api
            .adminAddUser(payload)
            .timeout(const Duration(seconds: 15));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(isEdit ? 'Person updated successfully' : 'Person registered successfully'),
              ],
            ),
          ),
        );
      }
      widget.onSuccess();
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _errorMessage = 'Request timed out after 15 seconds. Please try again.';
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request timed out after 15s')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        final errText = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _errorMessage = errText;
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errText)),
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
    final isEdit = widget.editUser != null;
    final divNames = _currentDivisionNames;
    final tutors = _availableTutors;
    final existingHod = _existingActiveHod;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Person' : 'Register New Person'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Role Dropdown
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'STUDENT', child: Text('Student')),
                    DropdownMenuItem(value: 'TUTOR', child: Text('Tutor')),
                    DropdownMenuItem(value: 'HOD', child: Text('HOD')),
                    DropdownMenuItem(value: 'GUARD', child: Text('Security Guard')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('Administrator')),
                  ],
                  onChanged: (v) => _onRoleChanged(v!),
                ),
                const SizedBox(height: 12),

                // Name
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name *'),
                ),
                const SizedBox(height: 12),

                // Phone
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (10 digits) *',
                    prefixText: '+91 ',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),

                // Department (Only for STUDENT, TUTOR, HOD)
                if (_role != 'GUARD' && _role != 'ADMIN') ...[
                  if (widget.departments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Create a department first',
                          style: TextStyle(color: Colors.brown)),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _department,
                      decoration: const InputDecoration(labelText: 'Department *'),
                      items: widget.departments.map<DropdownMenuItem<String>>((d) {
                        return DropdownMenuItem<String>(
                          value: d['code'] as String,
                          child: Text('${d['code']} — ${d['name']}'),
                        );
                      }).toList(),
                      onChanged: _onDepartmentChanged,
                    ),
                  const SizedBox(height: 12),
                ],

                // HOD warning & replace
                if (_role == 'HOD' && existingHod != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_department already has a HOD: ${existingHod['name']}',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Replace ${existingHod['name']} as HOD',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: _replaceHod,
                          onChanged: (val) => setState(() => _replaceHod = val ?? false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Year (STUDENT & TUTOR)
                if (_role == 'STUDENT' || _role == 'TUTOR') ...[
                  DropdownButtonFormField<int>(
                    value: _year,
                    decoration: const InputDecoration(labelText: 'Year of Study *'),
                    items: [1, 2, 3, 4].map((y) {
                      return DropdownMenuItem<int>(
                        value: y,
                        child: Text(_yearLabels[y]!),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() {
                      _year = v;
                      _tutorId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                ],

                // Division (Shown and required ONLY if department has divisions)
                if ((_role == 'STUDENT' || _role == 'TUTOR') && divNames.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: _division,
                    decoration: const InputDecoration(labelText: 'Division *'),
                    items: divNames.map((d) {
                      return DropdownMenuItem<String>(
                        value: d,
                        child: Text('Division $d'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() {
                      _division = v;
                      _tutorId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                ],

                // Student specific: Register No & Tutor dropdown
                if (_role == 'STUDENT') ...[
                  TextFormField(
                    controller: _regNoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Register / Roll No (Optional)',
                      hintText: 'e.g. CCE22CS045',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: tutors.any((t) => t['id'] == _tutorId) ? _tutorId : null,
                    decoration: InputDecoration(
                      labelText: 'Assigned Tutor',
                      helperText: tutors.isEmpty
                          ? 'No tutors found for $_department ${_yearLabels[_year] ?? ''} ${divNames.isNotEmpty ? (_division ?? '') : ''}'
                          : null,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None / Select Later')),
                      ...tutors.map((t) => DropdownMenuItem<String>(
                            value: t['id'] as String,
                            child: Text('${t['name']} (${t['mobile']})'),
                          )),
                    ],
                    onChanged: (v) => setState(() => _tutorId = v),
                  ),
                  const SizedBox(height: 12),
                ],

                // Error message banner
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_busy || !_isValid) ? null : _submit,
          child: Text(_busy ? 'Saving…' : (isEdit ? 'Update Person' : 'Register')),
        ),
      ],
    );
  }
}

// Dialog: Bulk Add CSV with Preview & Validation Report
class _BulkAddDialog extends StatefulWidget {
  const _BulkAddDialog({required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<_BulkAddDialog> createState() => _BulkAddDialogState();
}

class _BulkAddDialogState extends State<_BulkAddDialog> {
  final _controller = TextEditingController(
    text: 'Anoop Nair, 9876543210, STUDENT, CSE\n'
        'Smitha George, 9876543211, TUTOR, ECE\n'
        'Dr. Jayaraj, 9876543212, HOD, CSE\n'
        'Ramanathan, 9876543213, GUARD, Security',
  );
  bool _busy = false;
  bool _showPreview = false;
  List<Map<String, String>> _parsedValid = [];
  List<String> _parseErrors = [];

  void _parseAndPreview() {
    final lines = _controller.text.split('\n');
    final valid = <Map<String, String>>[];
    final errors = <String>[];

    final validRoles = {'STUDENT', 'TUTOR', 'HOD', 'GUARD', 'ADMIN'};

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length < 4) {
        errors.add('Line ${i + 1}: expected 4 fields (Name, Phone, Role, Dept). Found ${parts.length}');
        continue;
      }

      final name = parts[0].trim();
      final phone = parts[1].replaceAll(RegExp(r'\D+'), '');
      final normPhone = phone.length > 10 ? phone.substring(phone.length - 10) : phone;
      final role = parts[2].trim().toUpperCase();
      final dept = parts[3].trim();

      if (name.isEmpty) {
        errors.add('Line ${i + 1}: Name cannot be empty');
        continue;
      }
      if (normPhone.length != 10) {
        errors.add('Line ${i + 1}: Phone must be 10 digits (got "${parts[1].trim()}")');
        continue;
      }
      if (!validRoles.contains(role)) {
        errors.add('Line ${i + 1}: Role must be STUDENT, TUTOR, HOD, GUARD, or ADMIN (got "$role")');
        continue;
      }

      valid.add({
        'name': name,
        'phone': normPhone,
        'role': role,
        'department': dept,
      });
    }

    setState(() {
      _parsedValid = valid;
      _parseErrors = errors;
      _showPreview = true;
    });
  }

  Future<void> _submit() async {
    if (_parsedValid.isEmpty) return;
    setState(() => _busy = true);
    final state = AppStateScope.of(context);
    try {
      final count = await state.api.adminBulkAddUsers(_parsedValid);
      widget.onSuccess();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully registered $count users from CSV')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_showPreview ? 'CSV Import Preview' : 'Bulk Add People (CSV)'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_showPreview) ...[
                const Text(
                  'Format per line:\nName, Phone (10 digits), Role (STUDENT/TUTOR/HOD/GUARD/ADMIN), Department',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Paste CSV rows here...',
                  ),
                ),
              ] else ...[
                if (_parseErrors.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Errors (${_parseErrors.length} lines skipped):', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                        const SizedBox(height: 4),
                        ..._parseErrors.take(4).map((e) => Text('• $e', style: const TextStyle(fontSize: 11, color: Colors.red))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text('Valid entries to import (${_parsedValid.length}):', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._parsedValid.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• ${r['name']} (${r['phone']}) — ${r['role']} / ${r['department']}', style: const TextStyle(fontSize: 12)),
                    )),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_showPreview)
          TextButton(onPressed: () => setState(() => _showPreview = false), child: const Text('Back to Edit')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        if (!_showPreview)
          FilledButton(onPressed: _parseAndPreview, child: const Text('Preview & Validate'))
        else
          FilledButton(
            onPressed: _busy || _parsedValid.isEmpty ? null : _submit,
            child: Text(_busy ? 'Importing…' : 'Import ${_parsedValid.length} Users'),
          ),
      ],
    );
  }
}

// ==========================================
// 3. DEPARTMENTS TAB (CRUD + Block delete if has people)
// ==========================================
class _AdminDepartmentsTab extends StatelessWidget {
  const _AdminDepartmentsTab({
    required this.departments,
    required this.users,
    required this.onReload,
  });

  final List<dynamic> departments;
  final List<dynamic> users;
  final VoidCallback onReload;

  void _showDeptDialog(BuildContext context, {Map<String, dynamic>? dept}) {
    final codeCtrl = TextEditingController(text: dept?['code'] ?? '');
    final nameCtrl = TextEditingController(text: dept?['name'] ?? '');
    String? hodId = dept?['hodId'];
    final hods = users.where((u) => u['role'] == 'HOD' && u['status'] != 'DELETED').toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDState) => AlertDialog(
          title: Text(dept != null ? 'Edit Department' : 'Add Department'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Code (e.g. CSE)'),
                enabled: dept == null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Department Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: hodId,
                decoration: const InputDecoration(labelText: 'Assigned HOD'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No HOD Assigned')),
                  ...hods.map((h) => DropdownMenuItem<String>(
                        value: h['id'] as String,
                        child: Text('${h['name']} (${h['mobile']})'),
                      )),
                ],
                onChanged: (v) => setDState(() => hodId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final code = codeCtrl.text.trim();
                final name = nameCtrl.text.trim();
                if (code.isEmpty || name.isEmpty) return;
                final state = AppStateScope.of(context);
                try {
                  await state.api.adminAddOrUpdateDepartment(code, name, hodId);
                  onReload();
                  if (context.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDivisionDialog(BuildContext context, Map<String, dynamic> dept) {
    final divCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Division to ${dept['code']}'),
        content: TextField(
          controller: divCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Division Name (e.g. A, B, C)',
            hintText: 'Enter division letter/name',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = divCtrl.text.trim().toUpperCase();
              if (name.isEmpty) return;
              final state = AppStateScope.of(context);
              try {
                await state.api.adminAddDivision(dept['id'], name);
                onReload();
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green.shade700,
                      content: Text('Division $name added to ${dept['code']}'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding division: $e')),
                  );
                }
              }
            },
            child: const Text('Add Division'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDivision(
      BuildContext context, Map<String, dynamic> dept, Map<String, dynamic> div) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Division ${div['name']}?'),
        content: Text('Are you sure you want to delete division ${div['name']} from ${dept['code']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final state = AppStateScope.of(context);
      try {
        await state.api.adminDeleteDivision(dept['id'], div['id']);
        onReload();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green.shade700,
              content: Text('Division ${div['name']} deleted from ${dept['code']}'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot delete division: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteDepartment(BuildContext context, Map<String, dynamic> dept) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${dept['code']}?'),
        content: Text('Are you sure you want to delete department ${dept['name']}? Departments containing active members cannot be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final state = AppStateScope.of(context);
      try {
        await state.api.adminDeleteDepartment(dept['id']);
        onReload();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted department ${dept['code']}')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot delete: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDeptDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Department'),
      ),
      body: departments.isEmpty
          ? const EmptyState(icon: Icons.apartment, title: 'No departments registered')
          : ListView.separated(
              padding: AppTheme.screenPadding,
              itemCount: departments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final d = departments[i];
                final hod = users.firstWhere((u) => u['id'] == d['hodId'], orElse: () => null);
                final memberCount = users.where((u) => u['department'] == d['code'] && u['status'] != 'DELETED').length;
                final divisions = (d['divisions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.primaryLight.withOpacity(0.15),
                              child: Text(
                                d['code'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text(
                                    hod != null ? 'HOD: ${hod['name']} (${hod['mobile']})' : 'HOD: None assigned',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: hod != null ? AppTheme.hodAccent : AppTheme.textMuted,
                                      fontWeight: hod != null ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                  Text('$memberCount active person(s) in this department', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit department',
                              onPressed: () => _showDeptDialog(context, dept: d),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Delete department',
                              onPressed: () => _deleteDepartment(context, d),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('Divisions: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(width: 6),
                            if (divisions.isEmpty)
                              const Expanded(
                                child: Text('No divisions', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              )
                            else
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: divisions.map((div) {
                                    return InputChip(
                                      label: Text(div['name'] ?? ''),
                                      deleteIconColor: Colors.red.shade400,
                                      onDeleted: () => _deleteDivision(context, d, div),
                                    );
                                  }).toList(),
                                ),
                              ),
                            TextButton.icon(
                              onPressed: () => _showAddDivisionDialog(context, d),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Division'),
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

// ==========================================
// 4. OUTPASS MONITOR TAB (Filters + Detail + Cancel)
// ==========================================
class _AdminOutpassMonitorTab extends StatefulWidget {
  const _AdminOutpassMonitorTab({
    required this.outpasses,
    required this.departments,
    required this.onReload,
  });

  final List<dynamic> outpasses;
  final List<dynamic> departments;
  final VoidCallback onReload;

  @override
  State<_AdminOutpassMonitorTab> createState() => _AdminOutpassMonitorTabState();
}

class _AdminOutpassMonitorTabState extends State<_AdminOutpassMonitorTab> {
  String _search = '';
  String? _statusFilter;
  String? _deptFilter;

  void _showOutpassDetail(Map<String, dynamic> outpass) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _OutpassDetailSheet(
        outpass: outpass,
        onCancelled: () {
          Navigator.pop(ctx);
          widget.onReload();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.outpasses.where((o) {
      final student = o['student'] as Map? ?? {};
      final name = (student['user']?['name'] as String? ?? '').toLowerCase();
      final reg = (student['registerNo'] as String? ?? '').toLowerCase();
      final disp = (o['displayId'] as String? ?? '').toLowerCase();
      final query = _search.toLowerCase();

      final matchesQuery = _search.isEmpty || name.contains(query) || reg.contains(query) || disp.contains(query);
      final matchesStatus = _statusFilter == null || o['status'] == _statusFilter;
      final matchesDept = _deptFilter == null || student['department'] == _deptFilter;

      return matchesQuery && matchesStatus && matchesDept;
    }).toList();

    return Column(
      children: [
        // Filter bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search by student name, roll no, or pass ID...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v.trim()),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _statusFilter,
                      decoration: const InputDecoration(isDense: true, labelText: 'Status Filter'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Statuses')),
                        DropdownMenuItem(value: 'PENDING_TUTOR', child: Text('Pending Tutor')),
                        DropdownMenuItem(value: 'PENDING_HOD', child: Text('Pending HOD')),
                        DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                        DropdownMenuItem(value: 'EXITED', child: Text('Out / Exited')),
                        DropdownMenuItem(value: 'RETURNED', child: Text('Returned')),
                        DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                      ],
                      onChanged: (v) => setState(() => _statusFilter = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _deptFilter,
                      decoration: const InputDecoration(isDense: true, labelText: 'Department'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Depts')),
                        ...widget.departments.map((d) => DropdownMenuItem<String>(
                              value: d['code'] as String,
                              child: Text(d['code'] as String),
                            )),
                      ],
                      onChanged: (v) => setState(() => _deptFilter = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'No matching outpasses',
                  subtitle: 'Try adjusting your filters or search keywords',
                )
              : ListView.separated(
                  padding: AppTheme.screenPadding,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final o = filtered[i];
                    final s = o['student'] as Map? ?? {};
                    final user = s['user'] as Map? ?? {};
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                        onTap: () => _showOutpassDetail(o),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(o['displayId'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  StatusChip(status: o['status'] ?? 'PENDING_TUTOR'),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('${user['name'] ?? 'Student'} (${s['registerNo'] ?? ''}) · ${s['department'] ?? ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('${o['purposeCategory']} · ${o['destination']}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.schedule, size: 14, color: AppTheme.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Exit: ${o['requestedExitAt'] != null ? DateTime.parse(o['requestedExitAt']).toLocal().toString().substring(0, 16) : '-'}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                  const Spacer(),
                                  const Text('Details →', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _OutpassDetailSheet extends StatelessWidget {
  const _OutpassDetailSheet({
    required this.outpass,
    required this.onCancelled,
  });

  final Map<String, dynamic> outpass;
  final VoidCallback onCancelled;

  Future<void> _cancelPass(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Outpass?'),
        content: Text('Are you sure you want to cancel pass ${outpass['displayId']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel Pass'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final state = AppStateScope.of(context);
      try {
        await state.api.adminCancelOutpass(outpass['id']);
        onCancelled();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = outpass['student'] as Map? ?? {};
    final user = s['user'] as Map? ?? {};
    final status = outpass['status'] as String? ?? 'PENDING_TUTOR';
    final canCancel = !['RETURNED', 'CANCELLED', 'REJECTED'].contains(status);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(outpass['displayId'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              StatusChip(status: status),
            ],
          ),
          const Divider(height: 24),
          _detailRow('Student', '${user['name'] ?? 'Student'} (${s['registerNo'] ?? ''})'),
          _detailRow('Department', s['department'] ?? '-'),
          _detailRow('Destination', outpass['destination'] ?? '-'),
          _detailRow('Category', outpass['purposeCategory'] ?? '-'),
          if (outpass['purposeText'] != null)
            _detailRow('Reason', outpass['purposeText']),
          _detailRow('Exit Time', outpass['requestedExitAt'] != null ? DateTime.parse(outpass['requestedExitAt']).toLocal().toString().substring(0, 16) : '-'),
          _detailRow('Expected Return', outpass['expectedReturnAt'] != null ? DateTime.parse(outpass['expectedReturnAt']).toLocal().toString().substring(0, 16) : '-'),
          const SizedBox(height: 20),
          if (canCancel)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => _cancelPass(context),
              icon: const Icon(Icons.cancel),
              label: const Text('Admin Cancel This Outpass'),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }
}

// ==========================================
// 5. SETTINGS TAB (Database backed)
// ==========================================
class _AdminSettingsTab extends StatefulWidget {
  const _AdminSettingsTab({
    required this.settings,
    required this.onReload,
  });

  final Map<String, dynamic> settings;
  final VoidCallback onReload;

  @override
  State<_AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<_AdminSettingsTab> {
  late TextEditingController _collegeCtrl;
  late TextEditingController _dwellCtrl;
  late TextEditingController _catCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  @override
  void didUpdateWidget(covariant _AdminSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _initValues();
    }
  }

  void _initValues() {
    _collegeCtrl = TextEditingController(text: widget.settings['collegeName'] ?? 'Christ College of Engineering, Irinjalakuda');
    _dwellCtrl = TextEditingController(text: '${widget.settings['minDwellMinutes'] ?? 10}');
    final cats = widget.settings['categories'] as List? ?? ['Medical', 'Personal', 'Official', 'Academic', 'Emergency'];
    _catCtrl = TextEditingController(text: cats.join(', '));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final state = AppStateScope.of(context);
    try {
      final dwell = int.tryParse(_dwellCtrl.text.trim()) ?? 10;
      final cats = _catCtrl.text.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      await state.api.adminUpdateSettings(
        collegeName: _collegeCtrl.text.trim(),
        minDwellMinutes: dwell,
        categories: cats,
      );
      widget.onReload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully in database')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppTheme.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('College Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _collegeCtrl,
                    decoration: const InputDecoration(labelText: 'College Name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _dwellCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Gate Return Dwell Time (minutes)',
                      helperText: 'Enforced before return scan is valid (SEC-RET-01)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _catCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Outpass Categories (comma-separated)',
                      helperText: 'Available choices for students when requesting an outpass',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(_saving ? 'Saving…' : 'Save Settings'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 6. AUDIT LOG TAB
// ==========================================
class _AdminAuditTab extends StatelessWidget {
  const _AdminAuditTab({
    required this.auditLogs,
    required this.onReload,
  });

  final List<dynamic> auditLogs;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: auditLogs.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'No audit records',
              subtitle: 'System changes and events will be permanently logged here',
            )
          : ListView.separated(
              padding: AppTheme.screenPadding,
              itemCount: auditLogs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final log = auditLogs[i];
                final action = (log['action'] as String? ?? '').replaceAll('_', ' ');
                final at = log['at'] != null ? DateTime.parse(log['at']).toLocal().toString().substring(0, 19) : '';
                final detail = log['detail'];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.adminAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(log['actorRole'] ?? 'SYSTEM', style: const TextStyle(fontSize: 10, color: AppTheme.adminAccent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Target: ${log['objectType'] ?? '-'} · ID: ${log['objectId'] ?? '-'}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        if (detail != null) ...[
                          const SizedBox(height: 4),
                          Text('$detail', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black87)),
                        ],
                        const SizedBox(height: 4),
                        Text(at, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
