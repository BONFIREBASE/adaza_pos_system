import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/domain/app_user.dart';
import '../domain/management_repository.dart';
import '../domain/staff_member.dart';

/// Opens the create/edit staff modal. Pass [member] to edit. [actorRole] is the
/// signed-in user's role, used to limit which roles can be assigned.
Future<bool?> showStaffFormModal(
  BuildContext context, {
  required UserRole actorRole,
  StaffMember? member,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _StaffFormModal(actorRole: actorRole, member: member),
  );
}

class _StaffFormModal extends ConsumerStatefulWidget {
  const _StaffFormModal({required this.actorRole, this.member});
  final UserRole actorRole;
  final StaffMember? member;

  @override
  ConsumerState<_StaffFormModal> createState() => _StaffFormModalState();
}

class _StaffFormModalState extends ConsumerState<_StaffFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.member?.name ?? '');
  late final _email = TextEditingController(text: widget.member?.email ?? '');
  final _password = TextEditingController();
  late final _position =
      TextEditingController(text: widget.member?.position ?? '');
  late final _salary = TextEditingController(
      text: widget.member != null ? '${widget.member!.salary}' : '');
  late UserRole _role = widget.member?.role ?? _assignable.first;
  late SalaryPeriod _period = widget.member?.salaryPeriod ?? SalaryPeriod.monthly;
  late bool _active = widget.member?.active ?? true;
  bool _busy = false;

  bool get _isEdit => widget.member != null;

  /// Roles this actor is allowed to assign. Owner can make Admin or Cashier;
  /// Admin can only make Cashier. Owner accounts aren't created here.
  List<UserRole> get _assignable => widget.actorRole == UserRole.owner
      ? const [UserRole.admin, UserRole.cashier]
      : const [UserRole.cashier];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _position.dispose();
    _salary.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(managementRepositoryProvider);
    if (repo == null) return;

    setState(() => _busy = true);
    try {
      if (_isEdit) {
        await repo.updateStaff(StaffMember(
          uid: widget.member!.uid,
          email: widget.member!.email,
          role: _role,
          name: _name.text.trim(),
          position: _position.text.trim(),
          salary: double.tryParse(_salary.text) ?? 0,
          salaryPeriod: _period,
          active: _active,
        ));      } else {
        await repo.createStaff(
          email: _email.text.trim(),
          password: _password.text,
          name: _name.text.trim(),
          role: _role,
          position: _position.text.trim(),
          salary: double.tryParse(_salary.text) ?? 0,
          salaryPeriod: _period,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ManagementException catch (e) {
      AppSnack.error(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit staff' : 'Add staff'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text(_name, 'Full name'),
                _text(
                  _email,
                  'Email',
                  enabled: !_isEdit,
                  keyboard: TextInputType.emailAddress,
                ),
                if (!_isEdit)
                  _text(
                    _password,
                    'Temporary password',
                    obscure: true,
                    helper: 'Minimum 6 characters. Staff can change it later.',
                  ),
                _text(_position, 'Position', required: false),
                const SizedBox(height: 8),
                const Text('Role', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                SegmentedButton<UserRole>(
                  segments: [
                    for (final r in _assignable)
                      ButtonSegment(value: r, label: Text(r.label)),
                  ],
                  selected: {_assignable.contains(_role) ? _role : _assignable.first},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _text(_salary, 'Salary', number: true,
                          required: false),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<SalaryPeriod>(
                        initialValue: _period,
                        decoration: const InputDecoration(labelText: 'Period'),
                        items: [
                          for (final p in SalaryPeriod.values)
                            DropdownMenuItem(value: p, child: Text(p.label)),
                        ],
                        onChanged: (p) =>
                            setState(() => _period = p ?? SalaryPeriod.monthly),
                      ),
                    ),
                  ],
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Account active'),
                    subtitle: const Text('Disabled accounts cannot sign in.'),
                    value: _active,
                    activeThumbColor: const Color(0xFF1F6E6A),
                    onChanged: (v) => setState(() => _active = v),
                  ),
                ],
              ],
            ),
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
              : Text(_isEdit ? 'Save changes' : 'Create account'),
        ),
      ],
    );
  }

  Widget _text(
    TextEditingController c,
    String label, {
    bool number = false,
    bool obscure = false,
    bool enabled = true,
    bool required = true,
    String? helper,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        enabled: enabled,
        obscureText: obscure,
        keyboardType:
            keyboard ?? (number ? TextInputType.number : TextInputType.text),
        decoration: InputDecoration(labelText: label, helperText: helper),
        validator: (v) {
          if (!required) return null;
          if (v == null || v.trim().isEmpty) return '$label is required';
          if (label == 'Temporary password' && v.length < 6) {
            return 'At least 6 characters';
          }
          return null;
        },
      ),
    );
  }
}
