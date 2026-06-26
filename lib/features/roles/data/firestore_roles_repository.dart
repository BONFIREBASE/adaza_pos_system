import '../../../core/services/sync/sync_service.dart';
import '../domain/role.dart';
import '../domain/roles_repository.dart';

/// [RolesRepository] backed by the `roles` collection via [SyncService].
class FirestoreRolesRepository implements RolesRepository {
  FirestoreRolesRepository(this._sync);

  final SyncService _sync;
  static const _collection = 'roles';

  @override
  Stream<List<Role>> watchRoles() => _sync.watchCollection(_collection).map(
        (rows) => rows.map(Role.fromMap).toList()
          ..sort((a, b) {
            if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }),
      );

  @override
  Future<List<Role>> getRoles() async {
    final rows = await _sync.fetchCollection(_collection);
    return rows.map(Role.fromMap).toList();
  }

  @override
  Future<void> createRole(Role role) async {
    final id = _slug(role.name);
    if (id.isEmpty) throw const RoleException('Enter a role name.');
    if (role.permissions.isEmpty) {
      throw const RoleException('Select at least one permission.');
    }
    final existing = await getRoles();
    if (existing.any((r) => r.id == id)) {
      throw const RoleException('A role with that name already exists.');
    }
    try {
      await _sync.setDocument(_collection, id, role.toMap());
    } catch (_) {
      throw const RoleException('Could not create the role.');
    }
  }

  @override
  Future<void> updateRole(Role role) async {
    if (role.protected) {
      throw const RoleException('This role cannot be edited.');
    }
    if (role.permissions.isEmpty) {
      throw const RoleException('Select at least one permission.');
    }
    try {
      await _sync.updateDocument(_collection, role.id, role.toMap());
    } catch (_) {
      throw const RoleException('Could not update the role.');
    }
  }

  @override
  Future<void> deleteRole(String id) async {
    if (id == 'owner') {
      throw const RoleException('The Owner role cannot be deleted.');
    }
    try {
      await _sync.deleteDocument(_collection, id);
    } catch (_) {
      throw const RoleException('Could not delete the role.');
    }
  }

  @override
  Future<void> ensureDefaults() async {
    final existing = await getRoles();
    if (existing.isNotEmpty) return;
    for (final r in Role.defaults) {
      await _sync.setDocument(_collection, r.id, r.toMap());
    }
  }

  /// Lowercase, hyphen-free slug used as the role document id.
  static String _slug(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
