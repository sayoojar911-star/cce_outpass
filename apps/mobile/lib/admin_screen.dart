import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_roles_workflows.dart';
import 'api_client.dart';
import 'app_state.dart';
import 'theme/app_theme.dart';
import 'async_action_helper.dart';
import 'widgets/ticket_outpass.dart';

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
  List<dynamic> _roles = [];
  List<dynamic> _categories = [];
  List<dynamic> _outpassTypes = [];

  AppState get _state => AppStateScope.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAll();
    });
  }

  String? _loadError;
  bool _isUnauthorized = false;

  Future<void> _loadAll() async {
    setState(() {
      _busy = true;
      _loadError = null;
      _isUnauthorized = false;
    });
    try {
      final u = await _state.api.adminGetUsers();
      final d = await _state.api.adminGetDepartments();
      final o = await _state.api.adminGetOutpasses();
      final s = await _state.api.adminGetSettings();
      final a = await _state.api.adminGetAuditLog(limit: 50);
      final r = await _state.api.getRoles();
      final c = await _state.api.getPurposeCategories();
      final t = await _state.api.getOutpassTypes();
      if (mounted) {
        setState(() {
          _users = u;
          _departments = d;
          _outpasses = o;
          _settings = s;
          _auditLogs = a;
          _roles = r;
          _categories = c;
          _outpassTypes = t;
          _loadError = null;
          _isUnauthorized = false;
        });
      }
    } catch (e) {
      final errStr = e.toString();
      final unauth = errStr.contains('401') || errStr.contains('403') || errStr.toLowerCase().contains('unauthorized');
      if (mounted) {
        setState(() {
          _loadError = errStr;
          _isUnauthorized = unauth;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int get _compactNavIndex {
    switch (_currentIndex) {
      case 0:
        return 0; // Dashboard
      case 1:
        return 1; // People
      case 5:
        return 2; // Monitor
      case 4:
        return 3; // Departments
      default:
        return 4; // More
    }
  }

  void _onCompactNavSelected(int idx) {
    if (idx == 0) {
      setState(() => _currentIndex = 0);
    } else if (idx == 1) {
      setState(() => _currentIndex = 1);
    } else if (idx == 2) {
      setState(() => _currentIndex = 5);
    } else if (idx == 3) {
      setState(() => _currentIndex = 4);
    } else {
      _showMoreMenu();
    }
  }

  void _showMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Text(
                'More Admin Tools',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.security, color: AppTheme.adminAccent),
              title: const Text('Roles & Permissions'),
              selected: _currentIndex == 2,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _currentIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.route, color: AppTheme.adminAccent),
              title: const Text('Workflows & Outpass Types'),
              selected: _currentIndex == 3,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _currentIndex = 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: AppTheme.adminAccent),
              title: const Text('System Settings'),
              selected: _currentIndex == 6,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _currentIndex = 6);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: AppTheme.adminAccent),
              title: const Text('Audit Log'),
              selected: _currentIndex == 7,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _currentIndex = 7);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < AppLayout.breakpointCompact;

    final tabsContent = IndexedStack(
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
          roles: _roles,
          onReload: _loadAll,
        ),
        AdminRolesTab(
          roles: _roles,
          onReload: _loadAll,
        ),
        AdminWorkflowsTab(
          outpassTypes: _outpassTypes,
          categories: _categories,
          roles: _roles,
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
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.adminAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Icon(Icons.admin_panel_settings, color: AppTheme.adminAccent, size: 22),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Admin Console', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('CCE Outpass Control Panel', style: TextStyle(fontSize: 11, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
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
          : _loadError != null && _users.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isUnauthorized ? Icons.lock_outline : Icons.error_outline,
                              size: 48,
                              color: _isUnauthorized ? Colors.amber.shade800 : Colors.red.shade700,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _isUnauthorized ? 'Unauthorized Access' : 'Unable to Load Data',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _isUnauthorized
                                  ? 'Your session may have expired or you do not have administrative privileges.'
                                  : 'Could not connect to the CCE Outpass backend server: $_loadError',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isUnauthorized)
                                  PrimaryButton(
                                    label: 'Sign In Again',
                                    icon: Icons.login,
                                    fullWidth: false,
                                    onPressed: () => _state.logout(),
                                  )
                                else ...[
                                  SecondaryButton(
                                    label: 'Sign Out',
                                    icon: Icons.logout,
                                    fullWidth: false,
                                    onPressed: () => _state.logout(),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  PrimaryButton(
                                    label: 'Retry',
                                    icon: Icons.refresh,
                                    fullWidth: false,
                                    onPressed: _loadAll,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : isCompact
              ? tabsContent
              : Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _currentIndex,
                      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
                      labelType: screenWidth >= 900
                          ? NavigationRailLabelType.all
                          : NavigationRailLabelType.selected,
                      minWidth: 72,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: Text('Dashboard'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.people_outline),
                          selectedIcon: Icon(Icons.people),
                          label: Text('People'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.security_outlined),
                          selectedIcon: Icon(Icons.security),
                          label: Text('Roles'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.route_outlined),
                          selectedIcon: Icon(Icons.route),
                          label: Text('Workflows'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.apartment_outlined),
                          selectedIcon: Icon(Icons.apartment),
                          label: Text('Departments'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.manage_search_outlined),
                          selectedIcon: Icon(Icons.manage_search),
                          label: Text('Monitor'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.settings_outlined),
                          selectedIcon: Icon(Icons.settings),
                          label: Text('Settings'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.history_outlined),
                          selectedIcon: Icon(Icons.history),
                          label: Text('Audit Log'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(
                      child: Center(
                        child: ResponsiveContainer(
                          maxWidth: AppLayout.maxDashboardWidth,
                          child: tabsContent,
                        ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: isCompact
          ? NavigationBar(
              selectedIndex: _compactNavIndex,
              onDestinationSelected: _onCompactNavSelected,
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
                  icon: Icon(Icons.manage_search_outlined),
                  selectedIcon: Icon(Icons.manage_search),
                  label: 'Monitor',
                ),
                NavigationDestination(
                  icon: Icon(Icons.apartment_outlined),
                  selectedIcon: Icon(Icons.apartment),
                  label: 'Departments',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_outlined),
                  selectedIcon: Icon(Icons.menu),
                  label: 'More',
                ),
              ],
            )
          : null,
    );
  }
}

// ==========================================
// 1. DASHBOARD TAB
// ==========================================

/// Normalizes role matching between backend roleId, roleRef name, and role enums.
bool isUserRoleMatch(dynamic u, String targetRole) {
  if (u == null) return false;
  final target = targetRole.toLowerCase().trim();
  final roleId = (u['roleId'] ?? '').toString().toLowerCase().trim();
  final roleName = (u['role'] ?? '').toString().toLowerCase().trim();

  if (target == 'student') {
    return roleId == 'student' || roleName == 'student';
  } else if (target == 'tutor') {
    return roleId == 'tutor' || roleName == 'class tutor' || roleName == 'tutor';
  } else if (target == 'hod') {
    return roleId == 'hod' ||
        roleName.contains('head of department') ||
        roleName == 'hod' ||
        roleName.contains('deputy hod');
  } else if (target == 'guard' || target == 'security') {
    return roleId == 'guard' ||
        roleId == 'security' ||
        roleName.contains('guard') ||
        roleName.contains('security');
  } else if (target == 'admin') {
    return roleId == 'admin' ||
        roleId == 'super_admin' ||
        roleName.contains('administrator') ||
        roleName == 'admin';
  } else if (target == 'pending') {
    return roleId == 'pending' || roleName.contains('pending');
  }
  return roleId == target || roleName == target;
}

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
    final students = users.where((u) => isUserRoleMatch(u, 'student') && u['status'] != 'DELETED').length;
    final tutors = users.where((u) => isUserRoleMatch(u, 'tutor') && u['status'] != 'DELETED').length;
    final hods = users.where((u) => isUserRoleMatch(u, 'hod') && u['status'] != 'DELETED').length;
    final guards = users.where((u) => isUserRoleMatch(u, 'guard') && u['status'] != 'DELETED').length;
    final admins = users.where((u) => isUserRoleMatch(u, 'admin') && u['status'] != 'DELETED').length;

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
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 480;
                  final textCol = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'System Overview',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${users.where((u) => u['status'] != 'DELETED').length} registered active accounts',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                      ),
                    ],
                  );

                  final addBtn = ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.adminAccent,
                    ),
                    onPressed: () => onNavigate(1),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Add Person'),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        textCol,
                        const SizedBox(height: AppSpacing.s12),
                        addBtn,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: textCol),
                      const SizedBox(width: AppSpacing.s12),
                      addBtn,
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (_) {
              final unassigned = users.where((u) {
                final r = (u['roleId'] ?? u['role'] ?? '').toString().toLowerCase();
                if (r != 'student' || u['status'] == 'DELETED') return false;
                final s = u['student'] as Map? ?? {};
                final hasTutor = (u['tutorId'] != null && u['tutorId'].toString().trim().isNotEmpty) ||
                    (s['tutorId'] != null && s['tutorId'].toString().trim().isNotEmpty) ||
                    (s['tutor'] != null) ||
                    (u['tutor'] != null);
                return !hasTutor;
              }).length;

              if (unassigned == 0) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  color: Colors.amber.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.amber.shade400),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 480;
                        final contentCol = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$unassigned Students Without Assigned Tutor',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Students cannot submit normal outpasses until a faculty tutor is assigned.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        );

                        final actionBtn = ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.adminAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => onNavigate(1),
                          icon: const Icon(Icons.people_alt_outlined, size: 16),
                          label: const Text('Review Students'),
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(child: contentCol),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.s12),
                              actionBtn,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 28),
                            const SizedBox(width: 12),
                            Expanded(child: contentCol),
                            const SizedBox(width: AppSpacing.s12),
                            actionBtn,
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

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
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 380) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent System Activity',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => onNavigate(5),
                      child: const Text('View Audit Log →'),
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Recent System Activity',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: () => onNavigate(5),
                    child: const Text('View Audit Log →'),
                  ),
                ],
              );
            },
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
    required this.roles,
    required this.onReload,
  });

  final List<dynamic> users;
  final List<dynamic> departments;
  final List<dynamic> roles;
  final VoidCallback onReload;

  @override
  State<_AdminPeopleTab> createState() => _AdminPeopleTabState();
}

class _AdminPeopleTabState extends State<_AdminPeopleTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String? _deptFilter;
  String? _statusFilter;
  bool _unassignedTutorOnly = false;

  final Set<String> _selectedStudentIds = {};

  bool get _hasActiveFilters =>
      _search.isNotEmpty || _deptFilter != null || _statusFilter != null || _unassignedTutorOnly;

  void _resetFilters() {
    setState(() {
      _search = '';
      _searchController.clear();
      _deptFilter = null;
      _statusFilter = null;
      _unassignedTutorOnly = false;
      _selectedStudentIds.clear();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.index != 0 && _selectedStudentIds.isNotEmpty) {
      setState(() {
        _selectedStudentIds.clear();
      });
    } else {
      setState(() {});
    }
  }



  void _showAddPersonDialog({Map<String, dynamic>? editUser}) {
    final state = AppStateScope.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AppStateScope(
        state: state,
        child: _PersonFormDialog(
          editUser: editUser,
          departments: widget.departments,
          allUsers: widget.users,
          roles: widget.roles,
          onSuccess: widget.onReload,
        ),
      ),
    );
  }

  void _showBulkAddDialog() {
    final state = AppStateScope.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AppStateScope(
        state: state,
        child: _BulkAddDialog(
          onSuccess: widget.onReload,
        ),
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

    final tutors = widget.users.where((u) {
      final role = (u['roleId'] ?? u['role'] ?? '').toString().toLowerCase();
      final perms = (u['permissions'] as List?) ?? [];
      return (role == 'tutor' || perms.contains('approveOutpass')) && u['status'] == 'ACTIVE';
    }).toList();
    String? chosenTutorId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDState) {
          Future<void> assign() async {
            final state = AppStateScope.of(context);
            final messenger = ScaffoldMessenger.of(context);
            await AsyncActionHelper.run(
              context,
              action: () async {
                final count = await state.api.adminAssignTutors(studentIds, chosenTutorId);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() => _selectedStudentIds.clear());
                widget.onReload();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Assigned tutor for $count student(s)')),
                  );
                }
              },
            );
          }

          return CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter): () => assign(),
              const SingleActivator(LogicalKeyboardKey.numpadEnter): () => assign(),
              const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(ctx),
            },
            child: AlertDialog(
              title: Text('Assign Tutor (${studentIds.length} students)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select the faculty tutor for the chosen students:', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: chosenTutorId,
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
                  onPressed: assign,
                  child: const Text('Assign'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final state = AppStateScope.of(context);
    if (user['id'] == state.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot delete your own user account.')),
      );
      return;
    }

    final activeAdmins = widget.users.where((u) {
      final role = (u['roleId'] ?? u['role'] ?? '').toString().toLowerCase();
      return role == 'admin' && u['status'] != 'DELETED' && u['active'] != false;
    }).length;

    final userRole = (user['roleId'] ?? user['role'] ?? '').toString().toLowerCase();
    if (userRole == 'admin' && activeAdmins <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the last system administrator.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () => Navigator.pop(ctx, true),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () => Navigator.pop(ctx, true),
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(ctx, false),
        },
        child: Focus(
          autofocus: true,
          child: AlertDialog(
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
        ),
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      await AsyncActionHelper.run(
        context,
        action: () async {
          await state.api.adminDeleteUser(user['id']);
          widget.onReload();
        },
        successMessage: 'User ${user['name']} deleted',
      );
    }
  }

  Future<void> _toggleDeactivate(Map<String, dynamic> user) async {
    final state = AppStateScope.of(context);
    if (user['id'] == state.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot deactivate your own account.')),
      );
      return;
    }

    final userRole = (user['roleId'] ?? user['role'] ?? '').toString().toLowerCase();
    if (userRole == 'admin' && user['status'] == 'ACTIVE') {
      final activeAdmins = widget.users.where((u) {
        final role = (u['roleId'] ?? u['role'] ?? '').toString().toLowerCase();
        return role == 'admin' && u['status'] == 'ACTIVE' && u['active'] != false;
      }).length;
      if (activeAdmins <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot deactivate the last active administrator.')),
        );
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () => Navigator.pop(ctx, true),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () => Navigator.pop(ctx, true),
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(ctx, false),
        },
        child: Focus(
          autofocus: true,
          child: AlertDialog(
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
        ),
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final newStatus = user['status'] == 'INACTIVE' ? 'ACTIVE' : 'INACTIVE';
      await AsyncActionHelper.run(
        context,
        action: () async {
          await state.api.adminUpdateUser(user['id'], {'status': newStatus, 'active': newStatus == 'ACTIVE'});
          widget.onReload();
        },
        successMessage: newStatus == 'ACTIVE' ? 'User reactivated' : 'User deactivated',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeUsers = widget.users.where((u) => u['status'] != 'DELETED').toList();

    int countByRole(String target) {
      return activeUsers.where((u) {
        if (!isUserRoleMatch(u, target)) return false;
        if (_hasActiveFilters) {
          final name = (u['name'] as String? ?? '').toLowerCase();
          final phone = (u['mobile'] as String? ?? '').toLowerCase();
          final q = _search.toLowerCase();
          if (_search.isNotEmpty && !name.contains(q) && !phone.contains(q)) return false;
          if (_deptFilter != null && u['department'] != _deptFilter) return false;
          if (_statusFilter != null && u['status'] != _statusFilter) return false;
          if (target.toLowerCase() == 'student' && _unassignedTutorOnly) {
            final s = u['student'] as Map? ?? {};
            final hasTutor = (u['tutorId'] != null && u['tutorId'].toString().trim().isNotEmpty) ||
                (s['tutorId'] != null && s['tutorId'].toString().trim().isNotEmpty) ||
                (s['tutor'] != null) ||
                (u['tutor'] != null);
            if (hasTutor) return false;
          }
        }
        return true;
      }).length;
    }

    int totalByRole(String target) {
      return activeUsers.where((u) => isUserRoleMatch(u, target)).length;
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 440;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Total: ${activeUsers.length} members',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Expanded(
                                child: SecondaryButton(
                                  label: 'Bulk CSV',
                                  icon: Icons.upload_file,
                                  onPressed: _showBulkAddDialog,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: PrimaryButton(
                                  label: 'Add Person',
                                  icon: Icons.add,
                                  onPressed: () => _showAddPersonDialog(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total: ${activeUsers.length} members',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        SecondaryButton(
                          label: 'Bulk CSV',
                          icon: Icons.upload_file,
                          fullWidth: false,
                          onPressed: _showBulkAddDialog,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        PrimaryButton(
                          label: 'Add Person',
                          icon: Icons.add,
                          fullWidth: false,
                          onPressed: () => _showAddPersonDialog(),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Search and filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 560;
                    final searchField = TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search name, phone, or ID...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _search = '');
                                },
                              )
                            : null,
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _search = v.trim()),
                    );
                    final deptDropdown = DropdownButtonFormField<String>(
                      initialValue: _deptFilter,
                      decoration: const InputDecoration(isDense: true, labelText: 'Dept'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Depts')),
                        ...widget.departments.map((d) => DropdownMenuItem<String>(
                              value: d['code'] as String,
                              child: Text(d['code'] as String),
                            )),
                      ],
                      onChanged: (v) => setState(() => _deptFilter = v),
                    );
                    final statusDropdown = DropdownButtonFormField<String>(
                      initialValue: _statusFilter,
                      decoration: const InputDecoration(isDense: true, labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All')),
                        DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                        DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                      ],
                      onChanged: (v) => setState(() => _statusFilter = v),
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          searchField,
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Expanded(child: deptDropdown),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(child: statusDropdown),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(flex: 3, child: searchField),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(flex: 2, child: deptDropdown),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(flex: 2, child: statusDropdown),
                      ],
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    FilterChip(
                      selected: _unassignedTutorOnly,
                      avatar: Icon(
                        _unassignedTutorOnly ? Icons.assignment_late : Icons.assignment_late_outlined,
                        size: 16,
                        color: _unassignedTutorOnly ? Colors.white : Colors.deepOrange.shade800,
                      ),
                      label: Builder(
                        builder: (_) {
                          final unassignedCount = activeUsers.where((u) {
                            final r = (u['roleId'] ?? u['role'] ?? '').toString().toLowerCase();
                            if (r != 'student') return false;
                            final s = u['student'] as Map? ?? {};
                            final hasTutor = (u['tutorId'] != null && u['tutorId'].toString().trim().isNotEmpty) ||
                                (s['tutorId'] != null && s['tutorId'].toString().trim().isNotEmpty) ||
                                (s['tutor'] != null) ||
                                (u['tutor'] != null);
                            return !hasTutor;
                          }).length;
                          return Text(
                            'No Tutor Assigned ($unassignedCount)',
                            style: TextStyle(
                              color: _unassignedTutorOnly ? Colors.white : Colors.deepOrange.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                      selectedColor: Colors.deepOrange,
                      backgroundColor: Colors.deepOrange.shade50,
                      checkmarkColor: Colors.white,
                      onSelected: (val) {
                        setState(() {
                          _unassignedTutorOnly = val;
                          if (val && _tabController.index != 0) {
                            _tabController.animateTo(0);
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    if (_unassignedTutorOnly && _tabController.index == 0)
                      ActionChip(
                        avatar: const Icon(Icons.select_all, size: 16),
                        label: const Text('Select All', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          final unassignedIds = activeUsers.where((u) {
                            final r = (u['roleId'] ?? u['role'] ?? '').toString().toLowerCase();
                            if (r != 'student') return false;
                            final s = u['student'] as Map? ?? {};
                            final hasTutor = (u['tutorId'] != null && u['tutorId'].toString().trim().isNotEmpty) ||
                                (s['tutorId'] != null && s['tutorId'].toString().trim().isNotEmpty) ||
                                (s['tutor'] != null) ||
                                (u['tutor'] != null);
                            return !hasTutor;
                          }).map((u) => u['id'].toString()).toSet();
                          setState(() {
                            _selectedStudentIds.addAll(unassignedIds);
                          });
                        },
                      ),
                  ],
                ),
              ),

              if (_hasActiveFilters)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_alt, size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Filtered by: ' +
                              [
                                if (_search.isNotEmpty) 'Search "$_search"',
                                if (_deptFilter != null) 'Dept $_deptFilter',
                                if (_statusFilter != null) 'Status $_statusFilter',
                                if (_unassignedTutorOnly) 'Unassigned Only',
                              ].join(' · '),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.close, size: 14),
                        label: const Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                onTap: (index) {
                  if (index != 0 && _selectedStudentIds.isNotEmpty) {
                    setState(() => _selectedStudentIds.clear());
                  }
                },
                tabs: [
                  Tab(text: _hasActiveFilters ? 'Students (${countByRole("student")}/${totalByRole("student")})' : 'Students (${totalByRole("student")})'),
                  Tab(text: _hasActiveFilters ? 'Tutors (${countByRole("tutor")}/${totalByRole("tutor")})' : 'Tutors (${totalByRole("tutor")})'),
                  Tab(text: _hasActiveFilters ? 'HODs (${countByRole("hod")}/${totalByRole("hod")})' : 'HODs (${totalByRole("hod")})'),
                  Tab(text: _hasActiveFilters ? 'Guards (${countByRole("guard")}/${totalByRole("guard")})' : 'Guards (${totalByRole("guard")})'),
                  Tab(text: _hasActiveFilters ? 'Admins (${countByRole("admin")}/${totalByRole("admin")})' : 'Admins (${totalByRole("admin")})'),
                  Tab(text: _hasActiveFilters ? 'Pending (${countByRole("pending")}/${totalByRole("pending")})' : 'Pending (${totalByRole("pending")})'),
                ],
              ),
            ],
          ),
        ),

        // Action banner for batch tutor assignment (only on Students tab)
        if (_tabController.index == 0 && _selectedStudentIds.isNotEmpty)
          Container(
            color: AppTheme.primaryLight.withValues(alpha: 0.2),
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
              _buildRoleList('student'),
              _buildRoleList('tutor'),
              _buildRoleList('hod'),
              _buildRoleList('guard'),
              _buildRoleList('admin'),
              _buildRoleList('pending'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleList(String roleKey) {
    final target = roleKey.toLowerCase();
    final list = widget.users.where((u) {
      if (u['status'] == 'DELETED') return false;
      if (!isUserRoleMatch(u, roleKey)) return false;

      final name = (u['name'] as String? ?? '').toLowerCase();
      final phone = (u['mobile'] as String? ?? '').toLowerCase();
      final s = u['student'] as Map? ?? {};
      final regNo = (s['registerNo'] as String? ?? '').toLowerCase();
      final q = _search.toLowerCase();
      if (_search.isNotEmpty && !name.contains(q) && !phone.contains(q) && !regNo.contains(q)) return false;

      if (_deptFilter != null && u['department'] != _deptFilter) return false;
      if (_statusFilter != null && u['status'] != _statusFilter) return false;

      if (target == 'student' && _unassignedTutorOnly) {
        final hasTutor = (u['tutorId'] != null && u['tutorId'].toString().trim().isNotEmpty) ||
            (s['tutorId'] != null && s['tutorId'].toString().trim().isNotEmpty) ||
            (s['tutor'] != null) ||
            (u['tutor'] != null);
        if (hasTutor) return false;
      }

      return true;
    }).toList();

    if (list.isEmpty) {
      if (target == 'student' && _unassignedTutorOnly) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'All students have tutors assigned!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  'No unassigned students found. Turn off the filter to view all students.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.filter_alt_off, size: 16),
                  label: const Text('Show All Students'),
                ),
              ],
            ),
          ),
        );
      }
      if (_hasActiveFilters) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_list_off, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'No ${roleKey.toLowerCase()}s match active filters',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Active search or department filters excluded all results.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Reset All Filters'),
                ),
              ],
            ),
          ),
        );
      }
      return EmptyState(
        icon: AppTheme.roleIcon(roleKey.toUpperCase()),
        title: 'No ${roleKey.toLowerCase()}s found',
        subtitle: 'Click "Add Person" to register a new member.',
      );
    }

    return ListView.separated(
      padding: AppTheme.screenPadding,
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final u = list[i];
        final isInactive = u['status'] == 'INACTIVE' || u['active'] == false;
        final isStudent = target == 'student';
        final isPending = target == 'pending';
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
                        : (isPending ? Colors.amber.shade100 : AppTheme.roleColor(roleKey.toUpperCase()).withValues(alpha: 0.15)),
                    child: Icon(
                      isPending ? Icons.hourglass_top : AppTheme.roleIcon(roleKey.toUpperCase()),
                      color: isInactive ? Colors.grey : (isPending ? Colors.amber.shade900 : AppTheme.roleColor(roleKey.toUpperCase())),
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
                if (isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Text('Pending Approval', style: TextStyle(fontSize: 10, color: Colors.brown, fontWeight: FontWeight.bold)),
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
                  Builder(
                    builder: (_) {
                      final s = studentInfo;
                      final hasTutor = (u['tutorId'] != null && u['tutorId'].toString().trim().isNotEmpty) ||
                          (s['tutorId'] != null && s['tutorId'].toString().trim().isNotEmpty) ||
                          (s['tutor'] != null) ||
                          (u['tutor'] != null);
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Reg: ${s['registerNo'] ?? '-'} · Year ${u['year'] ?? s['year'] ?? '-'} ${u['division'] != null ? '(${u['division']})' : ''} · Tutor: ${hasTutor ? (s['tutor']?['name'] ?? u['tutor']?['name'] ?? 'Assigned') : 'Not assigned'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: hasTutor ? AppTheme.tutorAccent : Colors.red.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!hasTutor)
                            InkWell(
                              onTap: () => _showAssignTutorDialog(preselectedIds: [u['id'] as String]),
                              child: Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Text(
                                  'Assign Tutor',
                                  style: TextStyle(fontSize: 10, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
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
                PopupMenuItem(
                  value: 'edit',
                  child: Text(isPending ? 'Assign Role & Department' : 'Edit Person & Role'),
                ),
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
    required this.roles,
    required this.onSuccess,
  });

  final Map<String, dynamic>? editUser;
  final List<dynamic> departments;
  final List<dynamic> allUsers;
  final List<dynamic> roles;
  final VoidCallback onSuccess;

  @override
  State<_PersonFormDialog> createState() => _PersonFormDialogState();
}

class _PersonFormDialogState extends State<_PersonFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _regNoCtrl = TextEditingController();

  String _roleId = 'student';
  String _role = 'Student';
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
      _roleId = (u['roleId'] ?? u['role']?.toString().toLowerCase() ?? 'student').toString().toLowerCase();
      _role = (u['role'] ?? _roleId).toString();
      _nameCtrl.text = u['name'] ?? '';
      _phoneCtrl.text = u['mobile'] ?? '';
      _department = u['department'] as String?;
      _year = u['year'] as int?;
      _division = u['division'] as String?;

      final student = u['student'] as Map? ?? {};
      _tutorId = (student['tutorId'] ?? u['tutorId']) as String?;
      _regNoCtrl.text = (student['registerNo'] ?? '') as String;
      if (_year == null && student['year'] != null) {
        _year = student['year'] as int?;
      }
      if (_division == null && student['division'] != null) {
        _division = student['division'] as String?;
      }
    } else {
      _roleId = widget.roles.isNotEmpty ? widget.roles.first['id'].toString().toLowerCase() : 'student';
      _role = widget.roles.isNotEmpty ? widget.roles.first['name'].toString() : 'Student';
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
      _replaceHod = false;
      _division = null;
      _tutorId = null;
      _ensureValidDepartmentAndDivisions();
    });
  }

  bool get _isHod {
    final rId = _roleId.toLowerCase().trim();
    final rName = _role.toLowerCase().trim();
    return rId == 'hod' ||
        rId.contains('head of department') ||
        rName == 'hod' ||
        rName.contains('head of department');
  }

  bool get _isTutor {
    final rId = _roleId.toLowerCase().trim();
    final rName = _role.toLowerCase().trim();
    return rId == 'tutor' || rName.contains('tutor');
  }

  bool get _isStudent {
    final rId = _roleId.toLowerCase().trim();
    final rName = _role.toLowerCase().trim();
    return rId == 'student' || rName.contains('student');
  }

  bool get _isGuard {
    final rId = _roleId.toLowerCase().trim();
    final rName = _role.toLowerCase().trim();
    return rId == 'guard' || rId.contains('guard') || rName.contains('guard') || rName.contains('security');
  }

  bool get _isAdmin {
    final rId = _roleId.toLowerCase().trim();
    final rName = _role.toLowerCase().trim();
    return rId == 'admin' || rName.contains('admin');
  }

  void _onRoleChanged(String newRoleId) {
    final roleObj = widget.roles.firstWhere(
      (r) => r['id'].toString().toLowerCase() == newRoleId.toLowerCase(),
      orElse: () => {'id': newRoleId, 'name': newRoleId, 'permissions': []},
    );
    setState(() {
      _roleId = newRoleId.toLowerCase();
      _role = (roleObj['name'] ?? newRoleId).toString();
      _replaceHod = false;

      final isHod = _isHod;
      final isGuard = _isGuard;
      final isAdmin = _isAdmin;

      if (isGuard || isAdmin) {
        _department = null;
        _year = null;
        _division = null;
        _tutorId = null;
      } else if (isHod) {
        if (_department == null && widget.departments.isNotEmpty) {
          _department = widget.departments.first['code'] as String?;
        }
        _year = null;
        _division = null;
        _tutorId = null;
      } else {
        if (_department == null && widget.departments.isNotEmpty) {
          _department = widget.departments.first['code'] as String?;
        }
        _year ??= 1;
        _ensureValidDepartmentAndDivisions();
      }
    });
  }

  String? get _nameError {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return 'Full Name is required';
    return null;
  }

  String? get _phoneError {
    final raw = _phoneCtrl.text.trim();
    if (raw.isEmpty) return 'Phone number is required (10 digits)';
    final phone = normalizeMobilePhone(raw);
    if (phone.length != 10) return 'Must be exactly 10 digits';
    final isEdit = widget.editUser != null;
    final editId = widget.editUser?['id'] as String?;
    final exists = widget.allUsers.any((u) =>
        u['mobile'] == phone && (!isEdit || u['id'] != editId));
    if (exists) return 'This phone number is already registered';
    return null;
  }

  String? get _departmentError {
    if (_isGuard || _isAdmin) return null;
    if (widget.departments.isEmpty) return 'Create a department first';
    if (_department == null || _department!.isEmpty) return 'Department is required';
    return null;
  }

  String? get _yearError {
    if (!_isStudent && !_isTutor) return null;
    final yr = _year;
    if (yr == null || yr < 1 || yr > 4) return 'Year of study is required';
    return null;
  }

  String? get _divisionError {
    if (!_isStudent && !_isTutor) return null;
    final divNames = _currentDivisionNames;
    if (divNames.isNotEmpty && (_division == null || _division!.isEmpty)) {
      return 'Division is required';
    }
    return null;
  }

  String? get _disabledReason {
    if (_nameError != null) return _nameError;
    if (_phoneError != null) return _phoneError;
    if (_departmentError != null) return _departmentError;
    if (_yearError != null) return _yearError;
    if (_divisionError != null) return _divisionError;
    return null;
  }

  Map<String, dynamic>? get _existingActiveHod {
    if (!_isHod || _department == null) return null;
    final isEdit = widget.editUser != null;
    final editId = widget.editUser?['id'];
    for (final u in widget.allUsers) {
      final uRoleId = (u['roleId'] ?? '').toString().toLowerCase().trim();
      final uRoleName = (u['role'] ?? '').toString().toLowerCase().trim();
      final isUserHod = uRoleId == 'hod' ||
          uRoleId.contains('head of department') ||
          uRoleName == 'hod' ||
          uRoleName.contains('head of department');
      final isActive = u['status'] != 'INACTIVE' &&
          u['status'] != 'DELETED' &&
          u['status'] != 'DEACTIVATED' &&
          u['active'] != false;
      if (isUserHod &&
          isActive &&
          u['department'] == _department &&
          (!isEdit || u['id'] != editId)) {
        return u as Map<String, dynamic>;
      }
    }
    final deptObj = _currentDepartmentObj;
    final deptHodUserId = deptObj?['hodUserId'] ?? deptObj?['hodId'];
    if (deptHodUserId != null) {
      for (final u in widget.allUsers) {
        if (u['id'] == deptHodUserId && (!isEdit || u['id'] != editId)) {
          final isActive = u['status'] != 'INACTIVE' &&
              u['status'] != 'DELETED' &&
              u['status'] != 'DEACTIVATED' &&
              u['active'] != false;
          if (isActive) return u as Map<String, dynamic>;
        }
      }
    }
    return null;
  }

  List<dynamic> get _availableTutors {
    return widget.allUsers.where((u) {
      final uRole = (u['roleId'] ?? u['role'] ?? '').toString().toLowerCase();
      final perms = (u['permissions'] as List?) ?? [];
      final canApprove = uRole == 'tutor' || perms.contains('approveOutpass');
      if (!canApprove || u['status'] == 'DELETED') return false;
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
    final nameValid = _nameError == null;
    final phoneValid = _phoneError == null;
    final deptValid = _departmentError == null;

    if (_isHod) {
      final name = _nameCtrl.text.trim();
      final phone = normalizeMobilePhone(_phoneCtrl.text);
      final dept = _department;
      final existingHod = _existingActiveHod;
      final hasExisting = existingHod != null;
      final replaceConfirmed = _replaceHod;

      final isHodValid = nameValid && phoneValid && deptValid;

      debugPrint('[HOD Validation Check] ========================================');
      debugPrint('[HOD Validation Check] Role: $_role (roleId: $_roleId)');
      debugPrint('[HOD Validation Check] Condition 1 (Name): $nameValid ("$name")');
      debugPrint('[HOD Validation Check] Condition 2 (Phone 10 digits): $phoneValid ("$phone")');
      debugPrint('[HOD Validation Check] Condition 3 (Department): $deptValid ("$dept")');
      debugPrint('[HOD Validation Check] Condition 4 (Existing Active HOD): $hasExisting '
          '(${hasExisting ? "${existingHod['name']} (${existingHod['status'] ?? 'ACTIVE'})" : "None"})');
      debugPrint('[HOD Validation Check] Condition 5 (Replace HOD Confirmed): $replaceConfirmed');

      if (!nameValid) {
        debugPrint('[HOD Validation Check] BLOCKING: Name is empty or invalid.');
      } else if (!phoneValid) {
        debugPrint('[HOD Validation Check] BLOCKING: Phone is not 10 digits or is duplicate.');
      } else if (!deptValid) {
        debugPrint('[HOD Validation Check] BLOCKING: Department is missing.');
      } else if (hasExisting && !replaceConfirmed) {
        debugPrint('[HOD Validation Check] INFO: Department already has an HOD (${existingHod["name"]}). '
            'Register button ENABLED so admin can click Register to trigger confirmation dialog or use inline replace action.');
      } else {
        debugPrint('[HOD Validation Check] RESULT: All HOD conditions satisfied.');
      }
      debugPrint('[HOD Validation Check] ========================================');

      return isHodValid;
    }

    if (!nameValid || !phoneValid) return false;

    if (_isGuard || _isAdmin) {
      return true;
    }

    if (!deptValid) return false;

    if (_isStudent || _isTutor) {
      if (_yearError != null) return false;
      if (_divisionError != null) return false;
    }

    return true;
  }

  Future<bool> _showReplaceHodDialog(String existingName, String existingStatus) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(ctx).pop(false),
          const SingleActivator(LogicalKeyboardKey.enter): () => Navigator.of(ctx).pop(true),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () => Navigator.of(ctx).pop(true),
        },
        child: AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36),
          title: const Text('Replace Existing HOD?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_department already has an HOD: $existingName ($existingStatus).',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(
                'A department can only have one active Head of Department at a time.\n\n'
                'Replacing will deactivate $existingName, assign the new HOD, and update '
                'the department in one single transaction.\n\n'
                'All future departmental and Emergency outpasses will immediately route to the new HOD.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Replace existing HOD'),
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  Future<void> _submit() async {
    if (_busy) return;

    if (_isHod && _existingActiveHod != null && !_replaceHod) {
      final existing = _existingActiveHod!;
      final existingName = (existing['name'] ?? 'Existing HOD').toString();
      final existingStatus = (existing['status'] ?? 'ACTIVE').toString();
      final confirmed = await _showReplaceHodDialog(existingName, existingStatus);
      if (!confirmed || !mounted) return;
      setState(() {
        _replaceHod = true;
      });
    }

    final state = AppStateScope.of(context);
    final isEdit = widget.editUser != null;
    final editUser = widget.editUser;
    final editId = editUser?['id'] as String?;

    if (isEdit && editId == state.userId) {
      final oldRoleId = (editUser?['roleId'] ?? editUser?['role'] ?? '').toString().toLowerCase();
      if (_roleId != oldRoleId) {
        setState(() => _errorMessage = 'You cannot change your own role.');
        return;
      }
    }

    final normPhone = normalizeMobilePhone(_phoneCtrl.text);
    if (normPhone.length != 10) {
      setState(() => _errorMessage = 'Enter a valid 10-digit mobile number');
      return;
    }

    final exists = widget.allUsers.any((u) =>
        u['mobile'] == normPhone && (!isEdit || u['id'] != editId));
    if (exists) {
      setState(() => _errorMessage = 'This 10-digit phone number is already registered');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final deptObj = _currentDepartmentObj;
      final tutorIdVal = _tutorId?.trim();
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'mobile': normPhone,
        'roleId': _roleId,
        'role': _role,
        if (_department != null) 'department': _department,
        if (deptObj != null) 'departmentId': deptObj['id'],
        if (_year != null && (_isStudent || _isTutor)) 'year': _year,
        if (_division != null && (_isStudent || _isTutor)) 'division': _division,
        if (tutorIdVal != null && tutorIdVal.isNotEmpty && _isStudent) 'tutorId': tutorIdVal,
        if (_regNoCtrl.text.trim().isNotEmpty && _isStudent) 'registerNo': _regNoCtrl.text.trim(),
        if (_isHod && _replaceHod) 'replaceHod': true,
      };

      if (isEdit) {
        if (editId == null || editId.isEmpty) {
          throw Exception('User ID is missing for editing');
        }
        await state.api
            .adminUpdateUser(editId, payload)
            .timeout(const Duration(seconds: 15));
      } else {
        await state.api
            .adminAddUser(payload)
            .timeout(const Duration(seconds: 15));
      }

      if (mounted) {
        navigator.pop(true);
        messenger.showSnackBar(
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
        widget.onSuccess();
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _errorMessage = 'Request timed out after 15 seconds. Please try again.';
          _busy = false;
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Request timed out after 15s')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        final msg = e.statusCode == 409
            ? 'This phone number is already registered to another user'
            : e.message;
        setState(() {
          _errorMessage = msg;
          _busy = false;
        });
        messenger.showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        final errText = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _errorMessage = errText;
          _busy = false;
        });
        messenger.showSnackBar(
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
    final state = AppStateScope.of(context);
    final isEdit = widget.editUser != null;
    final isSelf = isEdit && widget.editUser?['id'] == state.userId;
    final divNames = _currentDivisionNames;
    final tutors = _availableTutors;
    final existingHod = _existingActiveHod;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (_isValid && !_busy) _submit();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (_isValid && !_busy) _submit();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_busy) Navigator.pop(context);
        },
      },
      child: AlertDialog(
        title: Text(isEdit ? 'Edit Person & Role' : 'Register New Person'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxDialogWidth),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dynamic Role Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: widget.roles.any((r) => r['id'].toString().toLowerCase() == _roleId.toLowerCase())
                        ? _roleId.toLowerCase()
                        : (widget.roles.isNotEmpty ? widget.roles.first['id'].toString().toLowerCase() : null),
                    decoration: const InputDecoration(labelText: 'Role *'),
                    items: widget.roles.map<DropdownMenuItem<String>>((r) {
                      final rId = (r['id'] ?? '').toString().toLowerCase();
                      final rName = (r['name'] ?? rId).toString();
                      return DropdownMenuItem<String>(
                        value: rId,
                        child: Text(rName),
                      );
                    }).toList(),
                    onChanged: isSelf ? null : (v) {
                      if (v != null) _onRoleChanged(v);
                    },
                  ),
                  if (isSelf)
                    const Padding(
                      padding: EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        'You cannot change your own role.',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Name
                  TextFormField(
                    controller: _nameCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      errorText: _nameError,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  TextFormField(
                    controller: _phoneCtrl,
                    textInputAction: _isStudent ? TextInputAction.next : TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_isStudent && _isValid && !_busy) _submit();
                    },
                    decoration: InputDecoration(
                      labelText: 'Phone Number (10 digits) *',
                      prefixText: '+91 ',
                      errorText: _phoneError,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                const SizedBox(height: 12),

                // Department (Only for STUDENT, TUTOR, HOD)
                if (!_isGuard && !_isAdmin) ...[
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
                      isExpanded: true,
                      initialValue: _department,
                      decoration: InputDecoration(
                        labelText: 'Department *',
                        errorText: _departmentError,
                      ),
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

                // HOD warning & replace banner
                if (_isHod && existingHod != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _replaceHod ? Colors.green.shade50 : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _replaceHod ? Colors.green.shade300 : Colors.amber.shade400,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _replaceHod ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                              color: _replaceHod ? Colors.green.shade800 : Colors.orange.shade900,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$_department already has an HOD: ${existingHod['name']} (${existingHod['status'] ?? 'ACTIVE'}).',
                                style: TextStyle(
                                  color: _replaceHod ? Colors.green.shade900 : Colors.brown.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_replaceHod) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Will replace ${existingHod['name']} as HOD and deactivate the previous HOD upon registration.',
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.brown.shade700,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => setState(() => _replaceHod = false),
                                child: const Text('Cancel Replace'),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            'Only one active HOD is allowed per department. You can replace the existing HOD or cancel.',
                            style: TextStyle(color: Colors.brown.shade800, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () async {
                                  final confirmed = await _showReplaceHodDialog(
                                    existingHod['name'] ?? 'Existing HOD',
                                    existingHod['status'] ?? 'ACTIVE',
                                  );
                                  if (confirmed && mounted) {
                                    setState(() => _replaceHod = true);
                                  }
                                },
                                child: const Text('Replace existing HOD'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  setState(() => _replaceHod = false);
                                },
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Year (STUDENT & TUTOR ONLY)
                if (_isStudent || _isTutor) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: InputDecoration(
                      labelText: 'Year of Study *',
                      errorText: _yearError,
                    ),
                    items: [1, 2, 3, 4].map((y) {
                      return DropdownMenuItem<int>(
                        value: y,
                        child: Text(_yearLabels[y] ?? 'Year $y'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() {
                      _year = v;
                      _tutorId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                ],

                // Division (Shown and required ONLY if department has divisions, STUDENT & TUTOR ONLY)
                if ((_isStudent || _isTutor) && divNames.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _division,
                    decoration: InputDecoration(
                      labelText: 'Division *',
                      errorText: _divisionError,
                    ),
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
                if (_isStudent) ...[
                  TextFormField(
                    controller: _regNoCtrl,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (_isValid && !_busy) _submit();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Register / Roll No (Optional)',
                      hintText: 'e.g. CCE22CS045',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: tutors.any((t) => t['id'] == _tutorId) ? _tutorId : null,
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
                            _errorMessage ?? '',
                            style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!_isValid && _disabledReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      _disabledReason!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      actions: [
        SecondaryButton(
          label: 'Cancel',
          fullWidth: false,
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
        PrimaryButton(
          label: isEdit ? 'Update Person' : 'Register',
          fullWidth: false,
          loading: _busy,
          onPressed: (_busy || !_isValid) ? null : _submit,
        ),
      ],
    ),
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
    await AsyncActionHelper.run(
      context,
      action: () async {
        final count = await state.api.adminBulkAddUsers(_parsedValid);
        widget.onSuccess();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully registered $count users from CSV')),
          );
        }
      },
      onFinally: () {
        if (mounted) setState(() => _busy = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_busy) {
            if (_showPreview && _parsedValid.isNotEmpty) {
              _submit();
            }
          }
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_busy) {
            if (_showPreview && _parsedValid.isNotEmpty) {
              _submit();
            }
          }
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_busy) Navigator.pop(context);
        },
      },
      child: AlertDialog(
        title: Text(_showPreview ? 'CSV Import Preview' : 'Bulk Add People (CSV)'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxDialogWidth),
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
                  Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
                          (HardwareKeyboard.instance.isControlPressed ||
                              HardwareKeyboard.instance.isMetaPressed)) {
                        _parseAndPreview();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: 'Paste CSV rows here...',
                        helperText: 'Press Ctrl+Enter (⌘+Enter) to preview & validate',
                      ),
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
        actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        actions: [
          if (_showPreview)
            SecondaryButton(
              label: 'Back to Edit',
              fullWidth: false,
              onPressed: () => setState(() => _showPreview = false),
            ),
          SecondaryButton(
            label: 'Cancel',
            fullWidth: false,
            onPressed: () => Navigator.pop(context),
          ),
          if (!_showPreview)
            PrimaryButton(
              label: 'Preview & Validate',
              fullWidth: false,
              onPressed: _parseAndPreview,
            )
          else
            PrimaryButton(
              label: 'Import ${_parsedValid.length} Users',
              fullWidth: false,
              loading: _busy,
              onPressed: _busy || _parsedValid.isEmpty ? null : _submit,
            ),
        ],
      ),
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
    final hods = users.where((u) => isUserRoleMatch(u, 'hod') && u['status'] != 'DELETED').toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDState) {
          Future<void> submit() async {
            final code = codeCtrl.text.trim();
            final name = nameCtrl.text.trim();
            if (code.isEmpty || name.isEmpty) return;
            final state = AppStateScope.of(context);
            await AsyncActionHelper.run(
              context,
              action: () async {
                await state.api.adminAddOrUpdateDepartment(code, name, hodId);
                onReload();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              successMessage: 'Department $code saved',
            );
          }

          return CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(ctx),
              const SingleActivator(LogicalKeyboardKey.enter): submit,
              const SingleActivator(LogicalKeyboardKey.numpadEnter): submit,
            },
            child: AlertDialog(
              title: Text(dept != null ? 'Edit Department' : 'Add Department'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeCtrl,
                    autofocus: dept == null,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Code (e.g. CSE)'),
                    enabled: dept == null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    autofocus: dept != null,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                    decoration: const InputDecoration(labelText: 'Department Name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: hodId,
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
                  onPressed: submit,
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddDivisionDialog(BuildContext context, Map<String, dynamic> dept) {
    final divCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        Future<void> submit() async {
          final name = divCtrl.text.trim().toUpperCase();
          if (name.isEmpty) return;
          final state = AppStateScope.of(context);
          await AsyncActionHelper.run(
            context,
            action: () async {
              await state.api.adminAddDivision(dept['id'], name);
              onReload();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            successMessage: 'Division $name added to ${dept['code']}',
          );
        }

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(ctx),
            const SingleActivator(LogicalKeyboardKey.enter): submit,
            const SingleActivator(LogicalKeyboardKey.numpadEnter): submit,
          },
          child: AlertDialog(
            title: Text('Add Division to ${dept['code']}'),
            content: TextField(
              controller: divCtrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
              decoration: const InputDecoration(
                labelText: 'Division Name (e.g. A, B, C)',
                hintText: 'Enter division letter/name',
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: submit,
                child: const Text('Add Division'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteDivision(
      BuildContext context, Map<String, dynamic> dept, Map<String, dynamic> div) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(ctx, false),
          const SingleActivator(LogicalKeyboardKey.enter): () => Navigator.pop(ctx, true),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () => Navigator.pop(ctx, true),
        },
        child: AlertDialog(
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
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      final state = AppStateScope.of(context);
      await AsyncActionHelper.run(
        context,
        action: () async {
          await state.api.adminDeleteDivision(dept['id'], div['id']);
          onReload();
        },
        successMessage: 'Division ${div['name']} deleted from ${dept['code']}',
      );
    }
  }

  Future<void> _deleteDepartment(BuildContext context, Map<String, dynamic> dept) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(ctx, false),
          const SingleActivator(LogicalKeyboardKey.enter): () => Navigator.pop(ctx, true),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () => Navigator.pop(ctx, true),
        },
        child: AlertDialog(
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
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      final state = AppStateScope.of(context);
      await AsyncActionHelper.run(
        context,
        action: () async {
          await state.api.adminDeleteDepartment(dept['id']);
          onReload();
        },
        successMessage: 'Deleted department ${dept['code']}',
      );
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
              separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                              backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.15),
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
                      initialValue: _statusFilter,
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
                      initialValue: _deptFilter,
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
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
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
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        void confirm() => Navigator.pop(ctx, true);
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.enter): confirm,
            const SingleActivator(LogicalKeyboardKey.numpadEnter): confirm,
            const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(ctx, false),
          },
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.cancel_outlined, color: Colors.red.shade700),
                const SizedBox(width: 8),
                const Text('Cancel Outpass (Admin)'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Are you sure you want to cancel pass ${outpass['displayId']}? This will invalidate the dynamic QR and pass code immediately.'),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => confirm(),
                  decoration: const InputDecoration(
                    labelText: 'Administrative Cancellation Reason (Optional)',
                    hintText: 'e.g. Disciplinary hold / Emergency campus closure',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Pass')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: confirm,
                child: const Text('Yes, Cancel Pass'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      final state = AppStateScope.of(context);
      final reason = reasonCtrl.text.trim();
      await AsyncActionHelper.run(
        context,
        action: () async {
          await state.api.adminCancelOutpass(outpass['id'], reason: reason.isNotEmpty ? reason : null);
          onCancelled();
        },
        successMessage: 'Pass ${outpass['displayId']} cancelled',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = outpass['student'] as Map? ?? {};
    final user = s['user'] as Map? ?? {};
    final status = outpass['status'] as String? ?? 'PENDING_TUTOR';
    final exitAt = outpass['exitAt'];
    final hasExited = exitAt != null || status == 'EXITED' || status == 'RETURNED';
    final isOverdue = status == 'OVERDUE';
    final canCancel = (isOverdue || !hasExited) && !['RETURNED', 'CANCELLED', 'REJECTED'].contains(status);

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
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
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
            },
            icon: const Icon(Icons.confirmation_number_outlined),
            label: const Text('Inspect Official Digital Pass'),
          ),
          if (canCancel) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => _cancelPass(context),
              icon: const Icon(Icons.cancel),
              label: const Text('Admin Cancel This Outpass'),
            ),
          ],
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
  late TextEditingController _durationCtrl;
  late TextEditingController _startTimeCtrl;
  late TextEditingController _endTimeCtrl;
  String? _defaultRoleId;
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
    _collegeCtrl = TextEditingController(text: widget.settings['collegeName']?.toString() ?? 'Christ College of Engineering, Irinjalakuda');
    _dwellCtrl = TextEditingController(text: '${widget.settings['minDwellMinutes'] ?? 10}');
    _durationCtrl = TextEditingController(text: '${widget.settings['defaultDurationHours'] ?? 3}');
    _startTimeCtrl = TextEditingController(text: widget.settings['allowedStartTime']?.toString() ?? '06:00');
    _endTimeCtrl = TextEditingController(text: widget.settings['allowedEndTime']?.toString() ?? '21:00');
    _defaultRoleId = widget.settings['defaultRoleId']?.toString() ?? 'pending';
  }

  @override
  void dispose() {
    _collegeCtrl.dispose();
    _dwellCtrl.dispose();
    _durationCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final state = AppStateScope.of(context);
    final dwell = int.tryParse(_dwellCtrl.text.trim()) ?? 10;
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 3;

    await AsyncActionHelper.run(
      context,
      action: () async {
        await state.api.adminUpdateSettings({
          'collegeName': _collegeCtrl.text.trim(),
          'minDwellMinutes': dwell,
          'defaultDurationHours': duration,
          'allowedStartTime': _startTimeCtrl.text.trim(),
          'allowedEndTime': _endTimeCtrl.text.trim(),
          'defaultRoleId': _defaultRoleId ?? 'pending',
        });
        await state.loadConfig();
        widget.onReload();
      },
      successMessage: 'Settings saved successfully in database',
      onFinally: () {
        if (mounted) setState(() => _saving = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final availableRoles = state.roles.isNotEmpty
        ? state.roles
        : [
            {'id': 'pending', 'name': 'Pending Approval'},
            {'id': 'student', 'name': 'Student'},
            {'id': 'tutor', 'name': 'Tutor'},
            {'id': 'hod', 'name': 'HOD'},
            {'id': 'guard', 'name': 'Security Guard'},
            {'id': 'admin', 'name': 'Administrator'},
          ];

    return SingleChildScrollView(
      padding: AppTheme.screenPadding,
      child: Center(
        child: ResponsiveContainer(
          maxWidth: AppLayout.maxFormWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('System & Policy Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _dwellCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Min Dwell (mins)',
                                helperText: 'Return dwell check',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _durationCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Default Duration (hrs)',
                                helperText: 'Default outpass duration',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _startTimeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Allowed Start Time',
                                helperText: 'Format: HH:mm (e.g. 06:00)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _endTimeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Allowed End Time',
                                helperText: 'Format: HH:mm (e.g. 21:00)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: availableRoles.any((r) => r['id'] == _defaultRoleId) ? _defaultRoleId : null,
                        decoration: const InputDecoration(
                          labelText: 'Default Role for New Sign-ups',
                          helperText: 'Users get this role upon registration until promoted',
                        ),
                        items: availableRoles.map<DropdownMenuItem<String>>((r) {
                          final id = r['id'].toString();
                          final name = r['name']?.toString() ?? id;
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _defaultRoleId = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: PrimaryButton(
                  label: 'Save Settings',
                  icon: Icons.save,
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                  maxWidth: 320,
                ),
              ),
            ],
          ),
        ),
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
              separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                                color: AppTheme.adminAccent.withValues(alpha: 0.12),
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
