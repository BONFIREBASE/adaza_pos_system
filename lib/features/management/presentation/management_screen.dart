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
import '../domain/management_repository.dart';
import '../domain/staff_member.dart';
import 'staff_form_modal.dart';

final _money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

/// Staff & account management (Req 1.5): Owner/Admin control who can access the
/// POS, their roles, status, and salary.
class ManagementScreen extends ConsumerWidget {
  const ManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(managementRepositoryProvider);
    final me = ref.watch(currentUserProvider);

    return AppNavScaffold(
      title: 'Management',
      currentRoute: '/management',
      floatingActionButton: (me?.role == UserRole.owner)
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created =
                    await showStaffFormModal(context, actorRole: me!.role);
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
                final staff = snap.data!;
                return _Body(staff: staff, me: me, repo: repo);
              },
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.staff, required this.me, required this.repo});

  final List<StaffMember> staff;
  final AppUser me;
  final ManagementRepository repo;

  bool _canModify(StaffMember m) {
    if (m.role == UserRole.owner) return false; // never manage the owner here
    if (m.uid == me.id) return false; // not yourself
    if (me.role == UserRole.admin && m.role == UserRole.admin) {
      return false; // admins can't manage other admins
    }
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
        ...staff.map((s) => _StaffRow(
              member: s,
              canModify: _canModify(s),
              isMe: s.uid == me.id,
              onEdit: () => _edit(context, s),
              onRemove: () => _remove(context, s),
            )),
      ],
    );
  }

  Future<void> _edit(BuildContext context, StaffMember s) async {
    final saved =
        await showStaffFormModal(context, actorRole: me.role, member: s);
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
    required this.canModify,
    required this.isMe,
    required this.onEdit,
    required this.onRemove,
  });

  final StaffMember member;
  final bool canModify;
  final bool isMe;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  Color get _roleColor => switch (member.role) {
        UserRole.owner => AppColors.gold,
        UserRole.admin => AppColors.teal,
        UserRole.cashier => AppColors.copper,
      };

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: _content(),
    );

    if (!canModify) return card;

    return Dismissible(
      key: ValueKey(member.uid),
      direction: DismissDirection.endToStart, // swipe left to delete
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
      background: const SizedBox.shrink(),
      confirmDismiss: (_) async {
        onRemove();
        return false; // the live list updates after removal
      },
      child: GestureDetector(onDoubleTap: onEdit, child: card),
    );
  }

  Widget _content() {
    final initial = member.displayName.isNotEmpty
        ? member.displayName[0].toUpperCase()
        : '?';
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _roleColor.withValues(alpha: 0.18),
            child: Text(initial,
                style: TextStyle(
                    color: _roleColor, fontWeight: FontWeight.w700)),
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
                    _Chip(label: member.role.label, color: _roleColor),
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
