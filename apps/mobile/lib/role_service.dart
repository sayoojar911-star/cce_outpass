import 'package:flutter/foundation.dart';
import 'app_state.dart';

/// Single source of truth for all role and permission checks in the Flutter application.
/// Compares by roleId and explicit permission strings, never by raw role strings or email.
class RoleService {
  // Permission Constants
  static const String permCreateOutpass = 'createOutpass';
  static const String permApproveOutpass = 'approveOutpass';
  static const String permScanGate = 'scanGate';
  static const String permManageUsers = 'manageUsers';
  static const String permManageRoles = 'manageRoles';
  static const String permViewAll = 'viewAll';

  /// Evaluates whether the user holds a specific permission.
  static bool hasPermission(AppState state, String permission) {
    final permissions = state.userPermissions;
    final granted = permissions.contains(permission);
    debugPrint(
      '[RoleService] hasPermission("$permission"): $granted (userId: ${state.userId}, roleId: ${state.userRoleId}, perms: $permissions)',
    );
    return granted;
  }

  /// Whether user can request a gate outpass (e.g. Student role).
  static bool canCreateOutpass(AppState state) {
    final r = state.userRoleId?.toLowerCase() ?? state.userRole?.toLowerCase();
    return hasPermission(state, permCreateOutpass) || r == 'student';
  }

  /// Whether user can approve/reject outpass requests in workflow (e.g. Tutor, HOD, Warden).
  static bool canApproveOutpass(AppState state) {
    final r = state.userRoleId?.toLowerCase() ?? state.userRole?.toLowerCase();
    return hasPermission(state, permApproveOutpass) || r == 'tutor' || r == 'hod' || r == 'warden';
  }

  /// Whether user can scan and verify digital pass tokens at the security gate (e.g. Guard).
  static bool canScanGate(AppState state) {
    final r = state.userRoleId?.toLowerCase() ?? state.userRole?.toLowerCase();
    return hasPermission(state, permScanGate) || r == 'guard';
  }

  /// Whether user can create, update, or assign users.
  static bool canManageUsers(AppState state) {
    final r = state.userRoleId?.toLowerCase() ?? state.userRole?.toLowerCase();
    return hasPermission(state, permManageUsers) || r == 'admin';
  }

  /// Whether user can manage roles, outpass types, categories, or departments.
  static bool canManageRoles(AppState state) {
    final r = state.userRoleId?.toLowerCase() ?? state.userRole?.toLowerCase();
    return hasPermission(state, permManageRoles) || r == 'admin';
  }

  /// Whether user has access to the Admin portal.
  static bool canAccessAdmin(AppState state) {
    final r = state.userRoleId?.toLowerCase() ?? state.userRole?.toLowerCase();
    final allowed = hasPermission(state, permManageUsers) ||
        hasPermission(state, permManageRoles) ||
        hasPermission(state, permViewAll) ||
        r == 'admin';
    debugPrint('[RoleService] canAccessAdmin: $allowed (roleId: ${state.userRoleId}, userRole: ${state.userRole})');
    return allowed;
  }

  /// Whether user is in a pending role or has no actionable permissions yet.
  static bool isPending(AppState state) {
    final r = state.userRoleId?.toLowerCase() ?? state.userRole?.toLowerCase();
    if (r == 'pending') return true;
    if (canAccessAdmin(state) || canApproveOutpass(state) || canScanGate(state) || canCreateOutpass(state)) {
      return false;
    }
    return true;
  }

  /// Human-readable description of a permission.
  static String permissionLabel(String permission) {
    switch (permission) {
      case permCreateOutpass:
        return 'Create Outpasses';
      case permApproveOutpass:
        return 'Approve Outpasses';
      case permScanGate:
        return 'Scan at Gate';
      case permManageUsers:
        return 'Manage Users & Assignments';
      case permManageRoles:
        return 'Manage Roles & Workflows';
      case permViewAll:
        return 'View System Records';
      default:
        return permission;
    }
  }
}
