import 'dart:convert';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../activity/domain/activity_log.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/auth_repository.dart';
import 'user_avatar.dart';

bool get _isMobile =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Edit display name + profile photo.
Future<void> showEditProfileModal(BuildContext context, AppUser user) {
  return showDialog<void>(
    context: context,
    builder: (_) => _EditProfileModal(user: user),
  );
}

class _EditProfileModal extends ConsumerStatefulWidget {
  const _EditProfileModal({required this.user});
  final AppUser user;

  @override
  ConsumerState<_EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends ConsumerState<_EditProfileModal> {
  late final _name = TextEditingController(text: widget.user.name);
  final _picker = ImagePicker();
  late String? _photo = widget.user.photo;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
          source: source, maxWidth: 400, maxHeight: 400, imageQuality: 70);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _photo = base64Encode(bytes));
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            name: _name.text.trim(),
            photo: _photo ?? '',
          );
      if (!mounted) return;
      AppSnack.success(context, 'Profile updated.');
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        AppSnack.error(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = AppUser(
      id: widget.user.id,
      email: widget.user.email,
      roleId: widget.user.roleId,
      roleName: widget.user.roleName,
      permissions: widget.user.permissions,
      name: _name.text,
      photo: _photo,
    );
    return AlertDialog(
      title: const Text('Edit profile'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(user: preview, radius: 40),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('Choose'),
                ),
                if (_isMobile)
                  OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Camera'),
                  ),
                if (_photo != null && _photo!.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _photo = ''),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Remove'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Display name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.user.email,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// Change password (re-auth + update).
Future<void> showChangePasswordModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ChangePasswordModal(),
  );
}

class _ChangePasswordModal extends ConsumerStatefulWidget {
  const _ChangePasswordModal();

  @override
  ConsumerState<_ChangePasswordModal> createState() =>
      _ChangePasswordModalState();
}

class _ChangePasswordModalState extends ConsumerState<_ChangePasswordModal> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      ref
          .read(activityLogProvider)
          ?.log(ActivityKind.passwordChanged, 'Changed their password');
      if (!mounted) return;
      AppSnack.success(context, 'Password changed.');
      Navigator.pop(context);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_current, 'Current password'),
              _field(_next, 'New password', minLen: 6),
              _field(_confirm, 'Confirm new password', match: _next),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Update password'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label,
      {int? minLen, TextEditingController? match}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        obscureText: true,
        decoration: InputDecoration(labelText: label),
        validator: (v) {
          if (v == null || v.isEmpty) return '$label is required';
          if (minLen != null && v.length < minLen) {
            return 'At least $minLen characters';
          }
          if (match != null && v != match.text) return 'Passwords do not match';
          return null;
        },
      ),
    );
  }
}

/// About this system: what it is, key features, compliance, and developer.
Future<void> showAboutModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _AboutModal(),
  );
}

class _AboutModal extends StatelessWidget {
  const _AboutModal();

  static const _features = <(IconData, String, String)>[
    (
      Icons.inventory_2_outlined,
      'Products & inventory',
      'Catalog with photos, pricing, margins, stock and low-stock alerts. '
          'Auto-generated barcodes and printable A4 labels.',
    ),
    (
      Icons.point_of_sale_outlined,
      'Sales & receipts',
      'Cart-based checkout with atomic stock updates, void/refund control, '
          'and printable thermal receipts.',
    ),
    (
      Icons.account_balance_wallet_outlined,
      'Income & expenses',
      'Track income and expenses with totals and profit, kept consistent '
          'with recorded sales.',
    ),
    (
      Icons.insights_outlined,
      'Live dashboard',
      'Real-time KPIs, 7-day sales chart, recent activity and a live clock.',
    ),
    (
      Icons.groups_outlined,
      'Staff & payroll',
      'Custom roles and permissions, staff accounts, and a monthly payroll '
          'summary.',
    ),
    (
      Icons.picture_as_pdf_outlined,
      'Branded reports',
      'Professional PDF reports for products, sales and finance.',
    ),
    (
      Icons.cloud_sync_outlined,
      'Cloud sync',
      'Secure cloud database with real-time sync across devices and offline '
          'support.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront_outlined,
                color: AppColors.teal, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ADAZA POS',
                    style: AppTheme.brand(
                        fontSize: 20, color: AppColors.textPrimary)),
                const Text('Point of Sale System',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A cloud-based point-of-sale and business management system '
                'for Adaza School and Office Supplies Trading and Apparel. '
                'It runs on web, mobile and Windows from a single platform.',
                style: TextStyle(
                    color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 18),
              _sectionTitle('Key features'),
              const SizedBox(height: 8),
              for (final f in _features) _featureRow(f.$1, f.$2, f.$3),
              const SizedBox(height: 18),
              _sectionTitle('Compliance'),
              const SizedBox(height: 8),
              _complianceRow(
                'BIR-compliant',
                'Supports sales recording, receipts, and income/expense '
                    'tracking aligned with Bureau of Internal Revenue '
                    'requirements for sales and bookkeeping.',
              ),
              const SizedBox(height: 8),
              _complianceRow(
                'DTI-compliant',
                'Built for a duly registered business under the Department of '
                    'Trade and Industry, supporting proper business records.',
              ),
              const SizedBox(height: 18),
              _sectionTitle('Developer & maintenance'),
              const SizedBox(height: 8),
              const Text(
                'Designed, developed and maintained by BONFIRE BASE Studio. '
                'The software and its data are owned by Adaza; BONFIRE BASE '
                'Studio provides ongoing development, maintenance and support.',
                style: TextStyle(
                    color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 10),
              _linkRow(Icons.language, 'bonfire.base69.studio'),
              _linkRow(Icons.mail_outline, 'support@base69.studio'),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Version 0.1.0  ·  © 2026 Adaza  ·  by BONFIRE BASE Studio',
                  style: AppTheme.mono(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  static Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 14),
      );

  static Widget _featureRow(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.copper),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontSize: 13)),
                Text(body,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _complianceRow(String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.verified_outlined, size: 18, color: AppColors.teal),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12, height: 1.35),
              children: [
                TextSpan(
                    text: '$title — ',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _linkRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }
}
