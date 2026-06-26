import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../roles/domain/role.dart';
import '../../roles/domain/roles_repository.dart';
import 'management_screen.dart' show roleColor;
import 'role_form_modal.dart';

/// Owner-only screen to create and manage custom roles.
class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(rolesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Roles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showRoleFormModal(context);
          if (created == true && context.mounted) {
            AppSnack.success(context, 'Role created.');
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New role'),
      ),
      body: rolesAsync.when(
        loading: () => const SkeletonList(),
        error: (_, __) =>
            const Center(child: Text('Could not load roles.')),
        data: (roles) {
          if (roles.isEmpty) {
            return const Center(child: Text('No roles yet. Create one.'));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Define what each role can do. The Owner role always has full '
                'access and cannot be changed.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ...roles.map((r) => _RoleCard(role: r)),
            ],
          );
        },
      ),
    );
  }
}

class _RoleCard extends ConsumerWidget {
  const _RoleCard({required this.role});
  final Role role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = roleColor(role);
    final perms = role.isOwner
        ? 'Full access'
        : role.permissions.map((p) => p.label).join(', ');

    Future<void> edit() async {
      if (role.protected) return;
      final saved = await showRoleFormModal(context, role: role);
      if (saved == true && context.mounted) {
        AppSnack.success(context, 'Role updated.');
      }
    }

    Future<void> remove() async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete role'),
          content: Text(
              'Delete the "${role.name}" role? Accounts using it will lose '
              'access until reassigned.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      try {
        await ref.read(rolesRepositoryProvider)?.deleteRole(role.id);
        if (context.mounted) AppSnack.success(context, 'Role deleted.');
      } on RoleException catch (e) {
        if (context.mounted) AppSnack.error(context, e.message);
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(Icons.shield_outlined, color: color),
        ),
        title: Text(role.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(perms,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: role.protected
            ? const _Chip(label: 'Reserved')
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit_outlined), onPressed: edit),
                  IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.error),
                      onPressed: remove),
                ],
              ),
        onTap: role.protected ? null : edit,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text('Reserved',
          style: TextStyle(
              color: AppColors.bronze,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }
}
