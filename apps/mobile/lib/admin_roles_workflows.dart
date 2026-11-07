import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'async_action_helper.dart';
import 'role_service.dart';
import 'theme/app_theme.dart';

// ==========================================
// ROLES & PERMISSIONS TAB
// ==========================================

class AdminRolesTab extends StatelessWidget {
  const AdminRolesTab({
    super.key,
    required this.roles,
    required this.onReload,
  });

  final List<dynamic> roles;
  final VoidCallback onReload;

  void _showRoleDialog(BuildContext context, {Map<String, dynamic>? role}) {
    showDialog(
      context: context,
      builder: (ctx) => RoleFormDialog(
        editRole: role,
        onSuccess: onReload,
      ),
    );
  }

  Future<void> _deleteRole(BuildContext context, Map<String, dynamic> role) async {
    final state = AppStateScope.of(context);
    final isSystem = role['isSystem'] == true || role['id'] == 'admin';
    if (isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System roles cannot be deleted')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(ctx, false),
          const SingleActivator(LogicalKeyboardKey.enter): () => Navigator.pop(ctx, true),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () => Navigator.pop(ctx, true),
        },
        child: AlertDialog(
          title: const Text('Delete Role?'),
          actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SecondaryButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(ctx, false),
                ),
                const SizedBox(width: AppSpacing.sm),
                DestructiveButton(
                  label: 'Delete',
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await AsyncActionHelper.run(
        context,
        action: () async {
          await state.api.adminDeleteRole(role['id']);
          onReload();
        },
        successMessage: 'Role "${role['name']}" deleted',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: roles.isEmpty
          ? const Center(child: Text('No roles configured'))
          : ListView.separated(
              padding: AppTheme.screenPadding,
              itemCount: roles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final r = roles[i] as Map<String, dynamic>;
                final id = (r['id'] ?? '').toString();
                final name = (r['name'] ?? id).toString();
                final description = r['description'] as String?;
                final isSystem = r['isSystem'] == true || id == 'admin';
                final active = r['active'] != false;
                final perms = (r['permissions'] as List?)?.cast<String>() ?? [];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.adminAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.security, color: AppTheme.adminAccent, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          id,
                                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (description != null && description.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        description,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isSystem)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  'SYSTEM',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: active ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: active ? Colors.green.shade200 : Colors.red.shade200),
                              ),
                              child: Text(
                                active ? 'ACTIVE' : 'DISABLED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: active ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              tooltip: 'Edit Role & Permissions',
                              onPressed: () => _showRoleDialog(context, role: r),
                            ),
                            if (!isSystem)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: 'Delete Role',
                                onPressed: () => _deleteRole(context, r),
                              ),
                          ],
                        ),
                        const Divider(height: 20),
                        const Text(
                          'Authorized Permissions:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 8),
                        if (perms.isEmpty)
                          const Text(
                            'None (Read-only / Pending assignment)',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: perms.map((p) {
                              return Chip(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                label: Text(RoleService.permissionLabel(p), style: const TextStyle(fontSize: 11)),
                                avatar: const Icon(Icons.check_circle, size: 14, color: AppTheme.adminAccent),
                                backgroundColor: AppTheme.adminAccent.withValues(alpha: 0.08),
                                side: BorderSide(color: AppTheme.adminAccent.withValues(alpha: 0.2)),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_moderator),
        label: const Text('New Role'),
        backgroundColor: AppTheme.adminAccent,
        foregroundColor: Colors.white,
        onPressed: () => _showRoleDialog(context),
      ),
    );
  }
}

class RoleFormDialog extends StatefulWidget {
  const RoleFormDialog({
    super.key,
    this.editRole,
    required this.onSuccess,
  });

  final Map<String, dynamic>? editRole;
  final VoidCallback onSuccess;

  @override
  State<RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<RoleFormDialog> {
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final Set<String> _permissions = {};
  bool _active = true;
  bool _busy = false;

  static const List<Map<String, String>> _availablePermissions = [
    {
      'id': RoleService.permCreateOutpass,
      'name': 'Create Outpass Requests',
      'desc': 'Allows students/users to submit digital outpass applications',
    },
    {
      'id': RoleService.permApproveOutpass,
      'name': 'Approve & Reject Outpasses',
      'desc': 'Allows approvers (Tutors, HODs, Wardens) to decide pending passes',
    },
    {
      'id': RoleService.permScanGate,
      'name': 'Scan at Security Gate',
      'desc': 'Allows security guards to scan and record gate movements',
    },
    {
      'id': RoleService.permManageUsers,
      'name': 'Manage Users & Assignments',
      'desc': 'Allows viewing users, assigning roles, departments, and tutors',
    },
    {
      'id': RoleService.permManageRoles,
      'name': 'Manage Roles & Workflows',
      'desc': 'Allows configuring roles, outpass types, chains, and categories',
    },
    {
      'id': RoleService.permViewAll,
      'name': 'Global Oversight & Audit',
      'desc': 'Allows viewing all department outpasses and system audit logs',
    },
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.editRole;
    if (r != null) {
      _idCtrl.text = (r['id'] ?? '').toString();
      _nameCtrl.text = (r['name'] ?? '').toString();
      _descCtrl.text = (r['description'] ?? '').toString();
      _active = r['active'] != false;
      final existingPerms = (r['permissions'] as List?)?.cast<String>() ?? [];
      _permissions.addAll(existingPerms);
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role name is required')),
      );
      return;
    }

    final id = _idCtrl.text.trim().toLowerCase();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role ID is required')),
      );
      return;
    }

    setState(() => _busy = true);
    final state = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      if (widget.editRole != null) {
        // Update
        await state.api.post('/admin/roles/$id', body: {
          'name': name,
          'description': _descCtrl.text.trim(),
          'permissions': _permissions.toList(),
          'active': _active,
        });
      } else {
        // Create
        await state.api.adminSaveRole({
          'id': id,
          'name': name,
          'description': _descCtrl.text.trim(),
          'permissions': _permissions.toList(),
        });
      }

      if (mounted) {
        navigator.pop();
        widget.onSuccess();
        messenger.showSnackBar(
          SnackBar(content: Text('Role "$name" saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error saving role: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editRole != null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(context),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_busy) _save();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_busy) _save();
        },
      },
      child: AlertDialog(
        title: Text(isEdit ? 'Edit Role (${widget.editRole?['id'] ?? ''})' : 'Create New Role'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxDialogWidth),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isEdit)
                  TextField(
                    controller: _idCtrl,
                    autofocus: !isEdit,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Role ID (unique identifier, e.g. warden) *',
                      helperText: 'Lowercase alphanumeric slug',
                    ),
                  ),
                if (!isEdit) const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  autofocus: isEdit,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Role Name (e.g. Hostel Warden) *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!_busy) _save();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active Role'),
                  subtitle: const Text('Disabled roles cannot be assigned or used to log in'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
                const Divider(height: 24),
                const Text(
                  'Granted Permissions:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ..._availablePermissions.map((p) {
                  final pId = (p['id'] ?? '').toString();
                  final pName = (p['name'] ?? pId).toString();
                  final pDesc = (p['desc'] ?? '').toString();
                  final selected = _permissions.contains(pId);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: selected,
                    title: Text(pName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(pDesc, style: const TextStyle(fontSize: 11)),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _permissions.add(pId);
                        } else {
                          _permissions.remove(pId);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SecondaryButton(
                label: 'Cancel',
                onPressed: _busy ? null : () => Navigator.pop(context),
              ),
              const SizedBox(width: AppSpacing.sm),
              PrimaryButton(
                label: 'Save Role',
                loading: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// WORKFLOWS TAB (OUTPASS TYPES & CATEGORIES)
// ==========================================

class AdminWorkflowsTab extends StatefulWidget {
  const AdminWorkflowsTab({
    super.key,
    required this.outpassTypes,
    required this.categories,
    required this.roles,
    required this.onReload,
  });

  final List<dynamic> outpassTypes;
  final List<dynamic> categories;
  final List<dynamic> roles;
  final VoidCallback onReload;

  @override
  State<AdminWorkflowsTab> createState() => _AdminWorkflowsTabState();
}

class _AdminWorkflowsTabState extends State<AdminWorkflowsTab> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showOutpassTypeDialog({Map<String, dynamic>? type}) {
    showDialog(
      context: context,
      builder: (ctx) => OutpassTypeFormDialog(
        editType: type,
        roles: widget.roles,
        onSuccess: widget.onReload,
      ),
    );
  }

  void _showCategoryDialog({Map<String, dynamic>? cat}) {
    showDialog(
      context: context,
      builder: (ctx) => CategoryFormDialog(
        editCat: cat,
        onSuccess: widget.onReload,
      ),
    );
  }

  Future<void> _deleteOutpassType(Map<String, dynamic> type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(ctx, false),
          const SingleActivator(LogicalKeyboardKey.enter): () => Navigator.pop(ctx, true),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () => Navigator.pop(ctx, true),
        },
        child: AlertDialog(
          title: const Text('Delete Outpass Type?'),
          actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SecondaryButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(ctx, false),
                ),
                const SizedBox(width: AppSpacing.sm),
                DestructiveButton(
                  label: 'Delete',
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final state = AppStateScope.of(context);
      await AsyncActionHelper.run(
        context,
        action: () async {
          await state.api.adminDeleteOutpassType(type['id']);
          widget.onReload();
        },
        successMessage: 'Outpass type deleted',
      );
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(ctx, false),
          const SingleActivator(LogicalKeyboardKey.enter): () => Navigator.pop(ctx, true),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () => Navigator.pop(ctx, true),
        },
        child: AlertDialog(
          title: const Text('Delete Purpose Category?'),
          actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SecondaryButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(ctx, false),
                ),
                const SizedBox(width: AppSpacing.sm),
                DestructiveButton(
                  label: 'Delete',
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final state = AppStateScope.of(context);
      await AsyncActionHelper.run(
        context,
        action: () async {
          await state.api.adminDeletePurposeCategory(cat['id']);
          widget.onReload();
        },
        successMessage: 'Category deleted',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: AppTheme.adminAccent,
            indicatorColor: AppTheme.adminAccent,
            unselectedLabelColor: AppTheme.textMuted,
            tabs: [
              Tab(
                icon: const Icon(Icons.route, size: 18),
                text: 'Outpass Types & Chains (${widget.outpassTypes.length})',
              ),
              Tab(
                icon: const Icon(Icons.category, size: 18),
                text: 'Purpose Categories (${widget.categories.length})',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              // 1. OUTPASS TYPES LIST
              Scaffold(
                body: widget.outpassTypes.isEmpty
                    ? const Center(child: Text('No outpass types configured'))
                    : ListView.separated(
                        padding: AppTheme.screenPadding,
                        itemCount: widget.outpassTypes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final t = widget.outpassTypes[i] as Map<String, dynamic>;
                          final label = (t['label'] ?? '').toString();
                          final chain = (t['approvalChain'] as List?)?.cast<String>() ?? [];
                          final active = t['active'] != false;

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: active ? Colors.green.shade50 : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: active ? Colors.green.shade200 : Colors.red.shade200),
                                        ),
                                        child: Text(
                                          active ? 'ACTIVE' : 'DISABLED',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: active ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () => _showOutpassTypeDialog(type: t),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                        onPressed: () => _deleteOutpassType(t),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Text('Approval Chain Stages:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      for (int step = 0; step < chain.length; step++) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryLight.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            'Stage ${step + 1}: ${chain[step].toUpperCase()}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                          ),
                                        ),
                                        if (step < chain.length - 1)
                                          const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                floatingActionButton: FloatingActionButton.extended(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Outpass Type'),
                  backgroundColor: AppTheme.adminAccent,
                  foregroundColor: Colors.white,
                  onPressed: () => _showOutpassTypeDialog(),
                ),
              ),

              // 2. PURPOSE CATEGORIES LIST
              Scaffold(
                body: widget.categories.isEmpty
                    ? const Center(child: Text('No categories configured'))
                    : ListView.separated(
                        padding: AppTheme.screenPadding,
                        itemCount: widget.categories.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final c = widget.categories[i] as Map<String, dynamic>;
                          final label = (c['label'] ?? '').toString();
                          final active = c['active'] != false;

                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppTheme.surfaceVariant,
                                child: Icon(Icons.category_outlined, size: 18, color: AppTheme.adminAccent),
                              ),
                              title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: active ? Colors.green.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      active ? 'ACTIVE' : 'DISABLED',
                                      style: TextStyle(fontSize: 10, color: active ? Colors.green.shade800 : Colors.red.shade800),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _showCategoryDialog(cat: c),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    onPressed: () => _deleteCategory(c),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                floatingActionButton: FloatingActionButton.extended(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Category'),
                  backgroundColor: AppTheme.adminAccent,
                  foregroundColor: Colors.white,
                  onPressed: () => _showCategoryDialog(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class OutpassTypeFormDialog extends StatefulWidget {
  const OutpassTypeFormDialog({
    super.key,
    this.editType,
    required this.roles,
    required this.onSuccess,
  });

  final Map<String, dynamic>? editType;
  final List<dynamic> roles;
  final VoidCallback onSuccess;

  @override
  State<OutpassTypeFormDialog> createState() => _OutpassTypeFormDialogState();
}

class _OutpassTypeFormDialogState extends State<OutpassTypeFormDialog> {
  final _labelCtrl = TextEditingController();
  final List<String> _chain = [];
  bool _active = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final t = widget.editType;
    if (t != null) {
      _labelCtrl.text = (t['label'] ?? '').toString();
      _active = t['active'] != false;
      final existingChain = (t['approvalChain'] as List?)?.cast<String>() ?? [];
      _chain.addAll(existingChain);
    } else {
      // Default to tutor -> hod if roles exist
      _chain.addAll(['tutor', 'hod']);
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Type label is required')));
      return;
    }
    if (_chain.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approval chain must have at least one stage')));
      return;
    }

    setState(() => _busy = true);
    final state = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final editTypeId = widget.editType?['id'];
      final payload = <String, dynamic>{
        'label': label,
        'approvalChain': _chain,
        'active': _active,
      };
      if (editTypeId != null) {
        payload['id'] = editTypeId;
      }
      await state.api.adminSaveOutpassType(payload);

      if (mounted) {
        navigator.pop();
        widget.onSuccess();
        messenger.showSnackBar(SnackBar(content: Text('Outpass type "$label" saved')));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(AsyncActionHelper.extractErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(context),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_busy) _save();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_busy) _save();
        },
      },
      child: AlertDialog(
        title: Text(widget.editType != null ? 'Edit Outpass Type' : 'New Outpass Type'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxDialogWidth),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _labelCtrl,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!_busy) _save();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Label (e.g. Normal (Tutor -> HOD)) *',
                  ),
                ),
                const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active Outpass Type'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Approval Chain Stages:', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Stage'),
                    onPressed: () {
                      final available = widget.roles.map((r) => r['id'].toString()).toList();
                      setState(() {
                        _chain.add(available.isNotEmpty ? available.first : 'tutor');
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_chain.isEmpty)
                const Text('No stages added. Click "Add Stage" above.', style: TextStyle(color: Colors.red))
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _chain.length,
                  // ignore: deprecated_member_use
                  onReorder: (oldIdx, newIdx) {
                    setState(() {
                      if (newIdx > oldIdx) newIdx -= 1;
                      final item = _chain.removeAt(oldIdx);
                      _chain.insert(newIdx, item);
                    });
                  },
                  itemBuilder: (ctx, idx) {
                    final currentRoleId = _chain[idx];
                    return ListTile(
                      key: ValueKey('$idx-$currentRoleId'),
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.2),
                        child: Text('${idx + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      title: DropdownButton<String>(
                        isExpanded: true,
                        value: widget.roles.any((r) => r['id'] == currentRoleId)
                            ? currentRoleId
                            : (widget.roles.isNotEmpty ? widget.roles.first['id'] : null),
                        items: widget.roles.map<DropdownMenuItem<String>>((r) {
                          return DropdownMenuItem<String>(
                            value: r['id'].toString(),
                            child: Text('${r['name']} (${r['id']})'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _chain[idx] = v);
                          }
                        },
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => setState(() => _chain.removeAt(idx)),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SecondaryButton(
              label: 'Cancel',
              onPressed: _busy ? null : () => Navigator.pop(context),
            ),
            const SizedBox(width: AppSpacing.sm),
            PrimaryButton(
              label: 'Save Type',
              loading: _busy,
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ],
    ),
  );
}
}

class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({
    super.key,
    this.editCat,
    required this.onSuccess,
  });

  final Map<String, dynamic>? editCat;
  final VoidCallback onSuccess;

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _labelCtrl = TextEditingController();
  bool _active = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final c = widget.editCat;
    if (c != null) {
      _labelCtrl.text = (c['label'] ?? '').toString();
      _active = c['active'] != false;
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category label is required')));
      return;
    }

    setState(() => _busy = true);
    final state = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final editCatId = widget.editCat?['id'];
      final payload = <String, dynamic>{
        'label': label,
        'active': _active,
      };
      if (editCatId != null) {
        payload['id'] = editCatId;
      }
      await state.api.adminSavePurposeCategory(payload);

      if (mounted) {
        navigator.pop();
        widget.onSuccess();
        messenger.showSnackBar(SnackBar(content: Text('Category "$label" saved')));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(AsyncActionHelper.extractErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(context),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_busy) _save();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_busy) _save();
        },
      },
      child: AlertDialog(
        title: Text(widget.editCat != null ? 'Edit Category' : 'New Category'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxDialogWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _labelCtrl,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_busy) _save();
                },
                decoration: const InputDecoration(labelText: 'Category Label (e.g. Medical) *'),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active Category'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SecondaryButton(
                label: 'Cancel',
                onPressed: _busy ? null : () => Navigator.pop(context),
              ),
              const SizedBox(width: AppSpacing.sm),
              PrimaryButton(
                label: 'Save Category',
                loading: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
