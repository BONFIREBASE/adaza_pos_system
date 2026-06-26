/// Capabilities that can be granted to a role. Roles are now data-driven, so
/// the Owner can define custom roles by choosing any combination of these.
enum AppPermission {
  manageProducts,
  adjustInventory,
  recordSales,
  manageFinance,
  viewDashboard,
  manageUsers;

  String get label => switch (this) {
        AppPermission.manageProducts => 'Manage products',
        AppPermission.adjustInventory => 'Adjust inventory',
        AppPermission.recordSales => 'Record sales',
        AppPermission.manageFinance => 'Income & expenses',
        AppPermission.viewDashboard => 'View dashboard',
        AppPermission.manageUsers => 'Manage staff',
      };

  static AppPermission? fromName(String? n) {
    for (final p in AppPermission.values) {
      if (p.name == n) return p;
    }
    return null;
  }
}

/// The reserved role id that always has full access (cannot be edited/deleted).
const String kOwnerRoleId = 'owner';

/// An authenticated user of the POS. Role is data-driven: [roleId] points at a
/// `roles/{roleId}` document whose permissions are resolved into [permissions].
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.roleId,
    this.roleName = '',
    this.permissions = const {},
    this.name = '',
    this.photo,
    this.mustChangePassword = false,
  });

  final String id;
  final String email;

  /// Role document id (e.g. 'owner', 'cashier', or a custom id).
  final String roleId;

  /// Human-readable role name for display.
  final String roleName;

  /// Resolved permission set for this user's role.
  final Set<AppPermission> permissions;

  final String name;
  final String? photo;

  /// True for newly-created staff who must set a new password before using
  /// the system.
  final bool mustChangePassword;

  bool get isOwner => roleId == kOwnerRoleId;

  String get displayName => name.trim().isEmpty ? email : name;

  String get roleLabel => roleName.trim().isEmpty
      ? (isOwner ? 'Owner' : roleId)
      : roleName;

  /// The Owner implicitly holds every permission.
  bool can(AppPermission permission) =>
      isOwner || permissions.contains(permission);
}
