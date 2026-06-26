import 'role.dart';

class RoleException implements Exception {
  const RoleException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Manages the data-driven role catalog (Owner only).
abstract interface class RolesRepository {
  Stream<List<Role>> watchRoles();

  Future<List<Role>> getRoles();

  /// Creates a role from a display [name] + chosen permissions. The id is
  /// derived from the name. Throws [RoleException] on conflict/invalid input.
  Future<void> createRole(Role role);

  Future<void> updateRole(Role role);

  Future<void> deleteRole(String id);

  /// Seeds the built-in roles if the catalog is empty.
  Future<void> ensureDefaults();
}
