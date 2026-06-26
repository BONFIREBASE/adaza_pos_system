import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/domain/app_user.dart';
import '../../roles/domain/role.dart';
import '../domain/management_repository.dart';
import '../domain/staff_member.dart';

bool get _isMobile =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Opens the create/edit staff modal. Pass [member] to edit. [actorIsOwner]
/// widens which roles can be assigned (only the Owner can assign manager roles).
Future<bool?> showStaffFormModal(
  BuildContext context, {
  required bool actorIsOwner,
  StaffMember? member,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _StaffFormModal(actorIsOwner: actorIsOwner, member: member),
  );
}

class _StaffFormModal extends ConsumerStatefulWidget {
  const _StaffFormModal({required this.actorIsOwner, this.member});
  final bool actorIsOwner;
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
  String? _roleId;
  late SalaryPeriod _period = widget.member?.salaryPeriod ?? SalaryPeriod.monthly;
  late bool _active = widget.member?.active ?? true;
  late String? _photo = widget.member?.photo;
  final _picker = ImagePicker();
  bool _busy = false;

  bool get _isEdit => widget.member != null;

  @override
  void initState() {
    super.initState();
    _roleId = widget.member?.roleId;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
          source: source, maxWidth: 400, maxHeight: 400, imageQuality: 70);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _photo = base64Encode(bytes));
    } catch (_) {
      if (mounted) AppSnack.error(context, 'Could not load image.');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _position.dispose();
    _salary.dispose();
    super.dispose();
  }

  /// Roles this actor may assign: never the Owner role; non-owners also can't
  /// assign roles that include staff management.
  List<Role> _assignable(List<Role> roles) {
    return roles.where((r) {
      if (r.isOwner) return false;
      if (!widget.actorIsOwner &&
          r.permissions.contains(AppPermission.manageUsers)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roleId == null) {
      AppSnack.error(context, 'Select a role.');
      return;
    }
    final repo = ref.read(managementRepositoryProvider);
    if (repo == null) return;

    setState(() => _busy = true);
    try {
      if (_isEdit) {
        await repo.updateStaff(StaffMember(
          uid: widget.member!.uid,
          email: widget.member!.email,
          roleId: _roleId!,
          name: _name.text.trim(),
          position: _position.text.trim(),
          salary: double.tryParse(_salary.text) ?? 0,
          salaryPeriod: _period,
          active: _active,
          photo: _photo,
        ));
      } else {
        await repo.createStaff(
          email: _email.text.trim(),
          password: _password.text,
          name: _name.text.trim(),
          roleId: _roleId!,
          position: _position.text.trim(),
          salary: double.tryParse(_salary.text) ?? 0,
          salaryPeriod: _period,
          photo: _photo,
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
    final roles = _assignable(ref.watch(rolesProvider).valueOrNull ?? const []);
    // Keep the selected role valid against the available list.
    if (_roleId != null && !roles.any((r) => r.id == _roleId)) {
      _roleId = null;
    }

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
                _PhotoRow(
                  photo: _photo,
                  initial: (_name.text.trim().isNotEmpty
                          ? _name.text.trim()
                          : (_email.text.trim().isNotEmpty
                              ? _email.text.trim()
                              : '?'))
                      .substring(0, 1)
                      .toUpperCase(),
                  onChoose: () => _pickPhoto(ImageSource.gallery),
                  onCamera: _isMobile
                      ? () => _pickPhoto(ImageSource.camera)
                      : null,
                  onClear:
                      _photo == null ? null : () => setState(() => _photo = null),
                ),
                const SizedBox(height: 12),
                _text(_name, 'Full name'),
                _text(_email, 'Email',
                    enabled: !_isEdit,
                    keyboard: TextInputType.emailAddress),
                if (!_isEdit)
                  _text(_password, 'Temporary password',
                      obscure: true,
                      helper:
                          'Minimum 6 characters. They must change it on first login.'),
                _text(_position, 'Position', required: false),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _roleId,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: [
                    for (final r in roles)
                      DropdownMenuItem(value: r.id, child: Text(r.name)),
                  ],
                  onChanged: (v) => setState(() => _roleId = v),
                  validator: (v) => v == null ? 'Select a role' : null,
                ),
                if (roles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No assignable roles. Create one in Manage roles first.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _text(_salary, 'Salary',
                          number: true, required: false),
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
                    activeThumbColor: AppColors.teal,
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

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.photo,
    required this.initial,
    required this.onChoose,
    required this.onCamera,
    required this.onClear,
  });

  final String? photo;
  final String initial;
  final VoidCallback onChoose;
  final VoidCallback? onCamera;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(photo);
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppColors.teal.withValues(alpha: 0.15),
          backgroundImage: bytes != null ? MemoryImage(bytes) : null,
          child: bytes == null
              ? Text(initial,
                  style: const TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w700,
                      fontSize: 22))
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Photo',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onChoose,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Choose'),
                  ),
                  if (onCamera != null)
                    OutlinedButton.icon(
                      onPressed: onCamera,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Camera'),
                    ),
                  if (onClear != null)
                    TextButton.icon(
                      onPressed: onClear,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Remove'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Uint8List? _decode(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
}
