import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_nav_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/domain/app_user.dart';
import '../../roles/domain/role.dart';
import '../domain/management_repository.dart';
import '../domain/staff_member.dart';
import 'roles_screen.dart';
import 'staff_form_modal.dart';

final _money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

Color roleColor(Role? role) {
  if (role == null) return AppColors.copper;
  if (role.isOwner) return AppColors.gold;
  if (role.permissions.contains(AppPermission.manageUsers)) {
    return AppColors.teal;
  }
  return AppColors.copper;
}

Uint8List? _decodePhoto(String? b64) {
  if (b64 == null || b64.isEmpty) return null;
  try {
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

/// Staff & account management (Req 1.5): Owner/Admin control who can access the
/// POS, their roles, status, and salary.
class ManagementScreen extends ConsumerStatefulWidget {
  const ManagementScreen({super.key});

  @override
  ConsumerState<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends ConsumerState<ManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Seed the built-in roles on first visit (Owner only — rules permit it).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final me = ref.read(currentUserProvider);
      if (me?.isOwner ?? false) {
        ref.read(rolesRepositoryProvider)?.ensureDefaults();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(managementRepositoryProvider);
    final me = ref.watch(currentUserProvider);
    final roles = ref.watch(rolesProvider).valueOrNull ?? const <Role>[];
    final rolesById = {for (final r in roles) r.id: r};

    return AppNavScaffold(
      title: 'Management',
      currentRoute: '/management',
      actions: [
        if (me?.isOwner ?? false)
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RolesScreen()),
            ),
            icon: const Icon(Icons.shield_outlined, size: 18),
            label: const Text('Manage roles'),
          ),
      ],
      floatingActionButton: (me?.isOwner ?? false)
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created =
                    await showStaffFormModal(context, actorIsOwner: true);
                if (created == true && context.mounted) {
                  AppSnack.success(context, 'Account created.');
                }
              },
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add staff'),
            )
          : null,
      body: (repo == null || me == null)
          ? const SkeletonList()
          : StreamBuilder<List<StaffMember>>(
              stream: repo.watchStaff(),
              builder: (context, snap) {
                if (!snap.hasData) return const SkeletonList();
                return _Body(
                  staff: snap.data!,
                  me: me,
                  repo: repo,
                  rolesById: rolesById,
                );
              },
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.staff,
    required this.me,
    required this.repo,
    required this.rolesById,
  });

  final List<StaffMember> staff;
  final AppUser me;
  final ManagementRepository repo;
  final Map<String, Role> rolesById;

  bool _canModify(StaffMember m) {
    if (m.isOwner) return false;
    if (m.uid == me.id) return false;
    final targetRole = rolesById[m.roleId];
    final targetManages =
        targetRole?.permissions.contains(AppPermission.manageUsers) ?? false;
    if (!me.isOwner && targetManages) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = staff.where((s) => s.active).length;
    final payroll = staff
        .where((s) => s.active)
        .fold<double>(0, (sum, s) => sum + s.monthlySalary);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _Stat(
                label: 'Total accounts',
                value: '${staff.length}',
                icon: Icons.group_outlined,
                color: AppColors.teal),
            _Stat(
                label: 'Active',
                value: '$activeCount',
                icon: Icons.verified_user_outlined,
                color: AppColors.success),
            _Stat(
                label: 'Monthly payroll',
                value: _money.format(payroll),
                icon: Icons.payments_outlined,
                color: AppColors.copper),
          ],
        ),
        const SizedBox(height: 24),
        Text('Accounts', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...staff.map((s) {
          final role = rolesById[s.roleId];
          return _StaffRow(
            member: s,
            roleName: s.isOwner ? 'Owner' : (role?.name ?? s.roleId),
            color: roleColor(role ?? (s.isOwner ? Role.defaults.first : null)),
            canModify: _canModify(s),
            isMe: s.uid == me.id,
            onEdit: () => _edit(context, s),
            onRemove: () => _remove(context, s),
          );
        }),
      ],
    );
  }

  Future<void> _edit(BuildContext context, StaffMember s) async {
    final saved = await showStaffFormModal(context,
        actorIsOwner: me.isOwner, member: s);
    if (saved == true && context.mounted) {
      AppSnack.success(context, 'Account updated.');
    }
  }

  Future<void> _remove(BuildContext context, StaffMember s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove account'),
        content: Text(
            'Remove "${s.displayName}"? They will lose access to the POS.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await repo.removeStaff(s.uid);
      if (context.mounted) AppSnack.success(context, 'Account removed.');
    } on ManagementException catch (e) {
      if (context.mounted) AppSnack.error(context, e.message);
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppTheme.fontDisplay,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: color)),
                    Text(label,
                        style:
                            const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.member,
    required this.roleName,
    required this.color,
    required this.canModify,
    required this.isMe,
    required this.onEdit,
    required this.onRemove,
  });

  final StaffMember member;
  final String roleName;
  final Color color;
  final bool canModify;
  final bool isMe;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: _content(),
    );
    if (!canModify) return card;

    return Dismissible(
      key: ValueKey(member.uid),
      direction: DismissDirection.endToStart,
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_remove_outlined, color: Colors.white),
            SizedBox(width: 8),
            Text('Remove',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onRemove();
        return false;
      },
      child: GestureDetector(onDoubleTap: onEdit, child: card),
    );
  }

  Widget _content() {
    final initial = member.displayName.isNotEmpty
        ? member.displayName[0].toUpperCase()
        : '?';
    final bytes = _decodePhoto(member.photo);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.18),
            backgroundImage: bytes != null ? MemoryImage(bytes) : null,
            child: bytes == null
                ? Text(initial,
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(member.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                    const SizedBox(width: 8),
                    _Chip(label: roleName, color: color),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      const _Chip(label: 'You', color: AppColors.bronze),
                    ],
                    if (!member.active) ...[
                      const SizedBox(width: 6),
                      const _Chip(label: 'Disabled', color: AppColors.error),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${member.email}'
                  '${member.position.isNotEmpty ? ' • ${member.position}' : ''}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                if (member.salary > 0)
                  Text(
                    '${_money.format(member.salary)} / ${member.salaryPeriod.label.toLowerCase()}',
                    style: AppTheme.mono(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
