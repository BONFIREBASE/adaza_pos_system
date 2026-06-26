import '../../auth/domain/app_user.dart';

/// A data-driven role the Owner can create/edit. The `owner` role is reserved
/// (full access, not editable or deletable).
class Role {
  const Role({
    required this.id,
    required this.name,
    required this.permissions,
    this.protected = false,
  });

  final String id;
  final String name;
  final Set<AppPermission> permissions;

  /// Protected roles (the Owner) cannot be edited or deleted.
  final bool protected;

  bool get isOwner => id == kOwnerRoleId;

  Role copyWith({String? name, Set<AppPermission>? permissions}) => Role(
        id: id,
        name: name ?? this.name,
        permissions: permissions ?? this.permissions,
        protected: protected,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'permissions': permissions.map((p) => p.name).toList(),
        'protected': protected,
      };

  factory Role.fromMap(Map<String, dynamic> map) => Role(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        permissions: ((map['permissions'] as List<dynamic>?) ?? [])
            .map((e) => AppPermission.fromName(e as String?))
            .whereType<AppPermission>()
            .toSet(),
        protected: map['protected'] as bool? ?? false,
      );

  /// Built-in roles seeded on first run.
  static const List<Role> defaults = [
    Role(
      id: kOwnerRoleId,
      name: 'Owner',
      permissions: {
        AppPermission.manageProducts,
        AppPermission.adjustInventory,
        AppPermission.recordSales,
        AppPermission.manageFinance,
        AppPermission.viewDashboard,
        AppPermission.manageUsers,
      },
      protected: true,
    ),
    Role(
      id: 'admin',
      name: 'Administrator',
      permissions: {
        AppPermission.manageProducts,
        AppPermission.adjustInventory,
        AppPermission.recordSales,
        AppPermission.manageFinance,
        AppPermission.viewDashboard,
        AppPermission.manageUsers,
      },
    ),
    Role(
      id: 'cashier',
      name: 'Cashier',
      permissions: {
        AppPermission.recordSales,
        AppPermission.viewDashboard,
      },
    ),
  ];
}
