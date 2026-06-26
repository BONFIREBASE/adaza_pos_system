import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/domain/app_user.dart';
import '../../roles/domain/role.dart';
import '../../roles/domain/roles_repository.dart';

/// Create/edit a custom role: a name + chosen permissions.
Future<bool?> showRoleFormModal(BuildContext context, {Role? role}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RoleFormModal(role: role),
  );
}

class _RoleFormModal extends ConsumerStatefulWidget {
  const _RoleFormModal({this.role});
  final Role? role;

  @override
  ConsumerState<_RoleFormModal> createState() => _RoleFormModalState();
}

class _RoleFormModalState extends ConsumerState<_RoleFormModal> {
  late final _name = TextEditingController(text: widget.role?.name ?? '');
  late final Set<AppPermission> _perms = {...?widget.role?.permissions};
  bool _busy = false;

  bool get _isEdit => widget.role != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(rolesRepositoryProvider);
    if (repo == null) return;
    setState(() => _busy = true);
    try {
      if (_isEdit) {
        await repo.updateRole(widget.role!.copyWith(
          name: _name.text.trim(),
          permissions: _perms,
        ));
      } else {
        await repo.createRole(Role(
          id: '_',
          name: _name.text.trim(),
          permissions: _perms,
        ));
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on RoleException catch (e) {
      AppSnack.error(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit role' : 'New role'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Role name',
                  hintText: 'e.g. Cleaner, Stock Clerk, Supervisor',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Permissions',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              for (final p in AppPermission.values)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(p.label),
                  value: _perms.contains(p),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _perms.add(p);
                    } else {
                      _perms.remove(p);
                    }
                  }),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEdit ? 'Save role' : 'Create role'),
        ),
      ],
    );
  }
}
