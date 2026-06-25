/// Capabilities that can be granted to a role. Features check these rather than
/// checking a role directly, so new roles can be added without touching callers.
enum AppPermission {
  manageProducts,
  adjustInventory,
  recordSales,
  manageFinance,
  viewDashboard,
  manageUsers,
}

/// Roles supported by the POS (Req 1.5). The user selects their role at
/// sign-in. Features check [AppPermission]s rather than the role directly, so
/// new roles can be added without touching callers.
enum UserRole {
  owner,
  admin,
  cashier;

  Set<AppPermission> get permissions {
    switch (this) {
      case UserRole.owner:
        // Full access, including user management.
        return AppPermission.values.toSet();
      case UserRole.admin:
        return {
          AppPermission.manageProducts,
          AppPermission.adjustInventory,
          AppPermission.recordSales,
          AppPermission.manageFinance,
          AppPermission.viewDashboard,
          AppPermission.manageUsers,
        };
      case UserRole.cashier:
        return {
          AppPermission.recordSales,
          AppPermission.viewDashboard,
        };
    }
  }

  String get label {
    switch (this) {
      case UserRole.owner:
        return 'Owner';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.cashier:
        return 'Cashier';
    }
  }

  static UserRole fromName(String? name) => UserRole.values.firstWhere(
        (r) => r.name == name,
        orElse: () => UserRole.cashier,
      );
}

/// An authenticated user of the POS.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.role = UserRole.owner,
    this.name = '',
    this.photo,
  });

  final String id;
  final String email;
  final UserRole role;

  /// Display name (from the user's profile doc).
  final String name;

  /// Optional profile photo, base64-encoded.
  final String? photo;

  String get displayName => name.trim().isEmpty ? email : name;

  bool can(AppPermission permission) => role.permissions.contains(permission);
}
