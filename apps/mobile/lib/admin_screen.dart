import 'package:flutter/material.dart';

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

  AppState get _state => AppStateScope.of(context);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _busy = true);
    try {
      final u = await _state.api.adminGetUsers();
      final d = await _state.api.adminGetDepartments();
      final o = await _state.api.adminGetOutpasses();
      final s = await _state.api.adminGetSettings();
      if (mounted) {
        setState(() {
          _users = u;
          _departments = d;
          _outpasses = o;
          _settings = s;
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
                color: AppTheme.adminAccent.withOpacity(0.1),
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
                ),
                _AdminSettingsTab(
                  settings: _settings,
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
    required this.onNavigate,
  });

  final List<dynamic> users;
  final List<dynamic> outpasses;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final students = users.where((u) => u['role'] == 'STUDENT').length;
    final tutors = users.where((u) => u['role'] == 'TUTOR').length;
    final hods = users.where((u) => u['role'] == 'HOD').length;
    final guards = users.where((u) => u['role'] == 'GUARD').length;

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
                          '${users.length} registered accounts across all roles',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.adminAccent,
                    ),
                    onPressed: () => onNavigate(1), // go to people
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
          Row(
            children: [
              _StatCard(title: 'Students', count: students, color: AppTheme.studentAccent, icon: Icons.school),
              const SizedBox(width: 10),
              _StatCard(title: 'Tutors', count: tutors, color: AppTheme.tutorAccent, icon: Icons.supervisor_account),
              const SizedBox(width: 10),
              _StatCard(title: 'HODs', count: hods, color: AppTheme.hodAccent, icon: Icons.account_balance),
              const SizedBox(width: 10),
              _StatCard(title: 'Guards', count: guards, color: AppTheme.guardAccent, icon: Icons.security),
            ],
          ),
          const SizedBox(height: 20),

          // Today's Outpasses Section
          const Text("Today's Outpass Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatCard(title: 'Pending', count: pending, color: AppTheme.statusPendingText, icon: Icons.hourglass_top),
              const SizedBox(width: 10),
              _StatCard(title: 'Approved', count: approved, color: AppTheme.statusApprovedText, icon: Icons.check_circle),
              const SizedBox(width: 10),
              _StatCard(title: 'Exited', count: exited, color: AppTheme.statusExitedText, icon: Icons.logout),
              const SizedBox(width: 10),
              _StatCard(title: 'Returned', count: returned, color: AppTheme.statusReturnedText, icon: Icons.task_alt),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Outpass Activity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Outpass Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              TextButton(
                onPressed: () => onNavigate(3),
                child: const Text('View all in Monitor →'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (outpasses.isEmpty)
            const EmptyState(
              icon: Icons.history,
              title: 'No outpasses created yet',
              subtitle: 'Activity will appear here as students request passes',
            )
          else
            ...outpasses.take(5).map((o) {
              final student = o['student'] as Map? ?? {};
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${student['name'] ?? 'Student'} • ${o['displayId']}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('${o['purposeCategory']} · ${o['destination']}',
                      style: const TextStyle(fontSize: 12)),
                  trailing: StatusChip(status: o['status'] ?? 'PENDING_TUTOR'),
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
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. PEOPLE TAB (CRUD + TABS)
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    final state = AppStateScope.of(context);
    final newStatus = user['status'] == 'INACTIVE' ? 'ACTIVE' : 'INACTIVE';
    try {
      await state.api.adminUpdateUser(user['id'], {'status': newStatus});
      widget.onReload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        'Total: ${widget.users.length} members',
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
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.adminAccent,
                unselectedLabelColor: AppTheme.textMuted,
                indicatorColor: AppTheme.adminAccent,
                tabs: [
                  Tab(text: 'Students (${widget.users.where((u) => u['role'] == 'STUDENT').length})'),
                  Tab(text: 'Tutors (${widget.users.where((u) => u['role'] == 'TUTOR').length})'),
                  Tab(text: 'HODs (${widget.users.where((u) => u['role'] == 'HOD').length})'),
                  Tab(text: 'Guards (${widget.users.where((u) => u['role'] == 'GUARD').length})'),
                ],
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleList(String role) {
    final list = widget.users.where((u) => u['role'] == role).toList();
    if (list.isEmpty) {
      return EmptyState(
        icon: AppTheme.roleIcon(role),
        title: 'No ${role.toLowerCase()}s found',
        subtitle: 'Click "Add Person" or import via CSV to register users.',
      );
    }

    return ListView.separated(
      padding: AppTheme.screenPadding,
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final u = list[i];
        final isInactive = u['status'] == 'INACTIVE';
        return Card(
          child: ListTile(
            leading: CircleAvatar(
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
                    u['name'] ?? 'Unnamed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: isInactive ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (isInactive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Deactivated', style: TextStyle(fontSize: 10, color: Colors.red)),
                  ),
              ],
            ),
            subtitle: Text(
              '${u['mobile']} · Dept: ${u['department'] ?? 'None'}${role == 'STUDENT' ? ' · Sem ${u['semester'] ?? 1}' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') {
                  _showAddPersonDialog(editUser: u);
                } else if (val == 'toggle') {
                  _toggleDeactivate(u);
                } else if (val == 'delete') {
                  _deleteUser(u);
                }
              },
              itemBuilder: (c) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(isInactive ? 'Activate' : 'Deactivate'),
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

// Dialog: Add/Edit Person
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
  late String _name;
  late String _mobile;
  late String _role;
  String? _department;
  String? _tutorId;
  int _semester = 1;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = widget.editUser;
    _name = u?['name'] ?? '';
    _mobile = u?['mobile'] ?? '';
    _role = u?['role'] ?? 'STUDENT';
    _department = u?['department'] ?? (widget.departments.isNotEmpty ? widget.departments.first['code'] : 'CSE');
    _tutorId = u?['tutorId'];
    _semester = u?['semester'] ?? 1;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final cleanMobile = _mobile.replaceAll(RegExp(r'\D+'), '');
    final normMobile = cleanMobile.length > 10 ? cleanMobile.substring(cleanMobile.length - 10) : cleanMobile;

    // Check duplicate phone
    final isEdit = widget.editUser != null;
    final exists = widget.allUsers.any((u) =>
        u['mobile'] == normMobile && (!isEdit || u['id'] != widget.editUser!['id']));
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This 10-digit phone number is already registered')),
      );
      return;
    }

    setState(() => _busy = true);
    final state = AppStateScope.of(context);
    try {
      final payload = {
        'name': _name,
        'mobile': normMobile,
        'role': _role,
        'department': _department,
        if (_role == 'STUDENT') ...{
          'semester': _semester,
          if (_tutorId != null) 'tutorId': _tutorId,
        },
      };

      if (isEdit) {
        await state.api.adminUpdateUser(widget.editUser!['id'], payload);
      } else {
        await state.api.adminAddUser(payload);
      }
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tutors = widget.allUsers.where((u) => u['role'] == 'TUTOR').toList();
    final isEdit = widget.editUser != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Person' : 'Register New Person'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                onSaved: (v) => _name = v!.trim(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _mobile,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (10 digits)',
                  prefixText: '+91 ',
                ),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'\D+'), '');
                  final norm = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
                  return norm.length != 10 ? 'Enter valid 10-digit number' : null;
                },
                onSaved: (v) => _mobile = v!,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'STUDENT', child: Text('Student')),
                  DropdownMenuItem(value: 'TUTOR', child: Text('Tutor')),
                  DropdownMenuItem(value: 'HOD', child: Text('HOD')),
                  DropdownMenuItem(value: 'GUARD', child: Text('Security Guard')),
                ],
                onChanged: (v) => setState(() => _role = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _department,
                decoration: const InputDecoration(labelText: 'Department'),
                items: widget.departments.map<DropdownMenuItem<String>>((d) {
                  return DropdownMenuItem<String>(
                    value: d['code'] as String,
                    child: Text('${d['code']} — ${d['name']}'),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _department = v),
              ),
              if (_role == 'STUDENT') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _semester,
                  decoration: const InputDecoration(labelText: 'Semester'),
                  items: List.generate(8, (i) => i + 1).map((s) {
                    return DropdownMenuItem(value: s, child: Text('Semester $s'));
                  }).toList(),
                  onChanged: (v) => setState(() => _semester = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _tutorId,
                  decoration: const InputDecoration(labelText: 'Assigned Tutor'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None / Select Tutor')),
                    ...tutors.map((t) => DropdownMenuItem<String>(
                          value: t['id'] as String,
                          child: Text('${t['name']} (${t['department']})'),
                        )),
                  ],
                  onChanged: (v) => setState(() => _tutorId = v),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Saving…' : (isEdit ? 'Update' : 'Register')),
        ),
      ],
    );
  }
}

// Dialog: Bulk Add CSV
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
        'Ramanathan, 9876543212, GUARD, Security',
  );
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    final state = AppStateScope.of(context);
    try {
      final lines = _controller.text.split('\n');
      final rows = <Map<String, String>>[];
      for (final line in lines) {
        final parts = line.split(',');
        if (parts.length >= 4) {
          rows.add({
            'name': parts[0].trim(),
            'phone': parts[1].trim(),
            'role': parts[2].trim(),
            'department': parts[3].trim(),
          });
        }
      }
      final count = await state.api.adminBulkAddUsers(rows);
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
      title: const Text('Bulk Add People (CSV)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Format per line:\nName, Phone (10 digits), Role (STUDENT/TUTOR/HOD/GUARD), Department',
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
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Importing…' : 'Import Users'),
        ),
      ],
    );
  }
}

// ==========================================
// 3. DEPARTMENTS TAB
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
    final hods = users.where((u) => u['role'] == 'HOD').toList();

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
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final d = departments[i];
                final hod = users.firstWhere((u) => u['id'] == d['hodId'], orElse: () => null);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryLight.withOpacity(0.15),
                      child: Text(
                        d['code'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 12),
                      ),
                    ),
                    title: Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      hod != null ? 'HOD: ${hod['name']} (${hod['mobile']})' : 'HOD: None assigned',
                      style: TextStyle(
                        fontSize: 12,
                        color: hod != null ? AppTheme.hodAccent : AppTheme.textMuted,
                        fontWeight: hod != null ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showDeptDialog(context, dept: d),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 4. OUTPASS MONITOR TAB
// ==========================================
class _AdminOutpassMonitorTab extends StatefulWidget {
  const _AdminOutpassMonitorTab({
    required this.outpasses,
    required this.departments,
  });

  final List<dynamic> outpasses;
  final List<dynamic> departments;

  @override
  State<_AdminOutpassMonitorTab> createState() => _AdminOutpassMonitorTabState();
}

class _AdminOutpassMonitorTabState extends State<_AdminOutpassMonitorTab> {
  String _search = '';
  String? _statusFilter;
  String? _deptFilter;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.outpasses.where((o) {
      final student = o['student'] as Map? ?? {};
      final name = (student['name'] as String? ?? '').toLowerCase();
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
                    return Card(
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
                            Text('${s['name']} (${s['registerNo']}) · ${s['department']}',
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
                              ],
                            ),
                          ],
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

// ==========================================
// 5. SETTINGS TAB
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
  late TextEditingController _collegeNameCtrl;
  late TextEditingController _dwellCtrl;
  late TextEditingController _catCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _collegeNameCtrl = TextEditingController(text: widget.settings['collegeName'] ?? 'Christ College of Engineering, Irinjalakuda');
    _dwellCtrl = TextEditingController(text: (widget.settings['minDwellMinutes'] ?? 10).toString());
    final cats = (widget.settings['categories'] as List?)?.cast<String>() ?? ['Medical', 'Personal', 'Official', 'Academic', 'Emergency'];
    _catCtrl = TextEditingController(text: cats.join(', '));
  }

  @override
  void dispose() {
    _collegeNameCtrl.dispose();
    _dwellCtrl.dispose();
    _catCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final state = AppStateScope.of(context);
    try {
      final name = _collegeNameCtrl.text.trim();
      final dwell = int.tryParse(_dwellCtrl.text.trim()) ?? 10;
      final cats = _catCtrl.text.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();

      await state.api.adminUpdateSettings(
        collegeName: name,
        minDwellMinutes: dwell,
        categories: cats,
      );
      widget.onReload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppTheme.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('College Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _collegeNameCtrl,
                    decoration: const InputDecoration(labelText: 'College Name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _dwellCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Return Dwell Time (minutes)',
                      helperText: 'Enforces anti-passback delay before a student can re-enter campus',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _catCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Outpass Purpose Categories (comma-separated)',
                      helperText: 'Options available for students when requesting an outpass',
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(_busy ? 'Saving…' : 'Save Changes'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
