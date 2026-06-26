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
import '../domain/finance_record.dart';
import '../domain/finance_repository.dart';

/// Income and expense list (Req 6). Owner/Admin can edit/delete manual entries.
/// Sale-derived income is locked (void the sale to reverse it).
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(financeRepositoryProvider);
    final canManage =
        ref.watch(currentUserProvider)?.can(AppPermission.manageFinance) ??
            false;
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final dateFmt = DateFormat.yMMMd();

    return AppNavScaffold(
      title: 'Income & Expenses',
      currentRoute: '/finance',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: repo == null ? null : () => _showSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add entry'),
      ),
      body: repo == null
          ? const SkeletonList()
          : StreamBuilder<List<FinanceRecord>>(
              stream: repo.watchRecords(),
              builder: (context, snap) {
                if (!snap.hasData) return const SkeletonList();
                final records = snap.data!;
                if (records.isEmpty) {
                  return const Center(child: Text('No records yet.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: records.length,
                  itemBuilder: (context, i) {
                    final r = records[i];
                    final card = _RecordCard(
                      record: r,
                      money: money,
                      dateFmt: dateFmt,
                    );

                    // Editable only for managers, and never sale-derived income.
                    if (!canManage || r.isFromSale) return card;

                    return Dismissible(
                      key: ValueKey(r.id),
                      direction: DismissDirection.endToStart,
                      background: const SizedBox.shrink(),
                      secondaryBackground: _deleteBg(),
                      confirmDismiss: (_) async {
                        await _delete(context, ref, r);
                        return false;
                      },
                      child: GestureDetector(
                        onDoubleTap: () =>
                            _showSheet(context, ref, existing: r),
                        child: card,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _deleteBg() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Future<void> _delete(
      BuildContext context, WidgetRef ref, FinanceRecord r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry'),
        content: Text('Delete "${r.category}"? This cannot be undone.'),
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
    final repo = ref.read(financeRepositoryProvider);
    if (repo == null) return;
    try {
      await repo.delete(r.id);
      if (context.mounted) AppSnack.success(context, 'Entry deleted.');
    } catch (_) {
      if (context.mounted) AppSnack.error(context, 'Could not delete entry.');
    }
  }

  void _showSheet(BuildContext context, WidgetRef ref,
      {FinanceRecord? existing}) {
    final isEdit = existing != null;
    final amount = TextEditingController(
        text: existing != null ? '${existing.amount}' : '');
    final category = TextEditingController(text: existing?.category ?? '');
    FinanceType type = existing?.type ?? FinanceType.expense;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEdit ? 'Edit entry' : 'Add entry',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              SegmentedButton<FinanceType>(
                segments: const [
                  ButtonSegment(
                      value: FinanceType.expense, label: Text('Expense')),
                  ButtonSegment(
                      value: FinanceType.income, label: Text('Income')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setSheet(() => type = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: category,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final repo = ref.read(financeRepositoryProvider);
                    if (repo == null) return;
                    final record = FinanceRecord(
                      id: existing?.id ?? '_',
                      type: type,
                      amount: double.tryParse(amount.text) ?? 0,
                      category: category.text.trim().isEmpty
                          ? type.name
                          : category.text.trim(),
                      date: existing?.date ?? DateTime.now(),
                      note: existing?.note ?? '',
                      saleId: existing?.saleId,
                    );
                    try {
                      if (isEdit) {
                        await repo.update(record);
                      } else {
                        await repo.create(record);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        AppSnack.success(context,
                            isEdit ? 'Entry updated.' : 'Entry added.');
                      }
                    } on FinanceValidationException catch (e) {
                      if (!ctx.mounted) return;
                      AppSnack.error(ctx, e.message);
                    }
                  },
                  child: Text(isEdit ? 'Save changes' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.money,
    required this.dateFmt,
  });

  final FinanceRecord record;
  final NumberFormat money;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final income = record.type == FinanceType.income;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Icon(
          income ? Icons.arrow_downward : Icons.arrow_upward,
          color: income ? AppColors.success : AppColors.error,
        ),
        title: Row(
          children: [
            Flexible(child: Text(record.category)),
            if (record.isFromSale) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('From sale',
                    style: TextStyle(
                        color: AppColors.teal,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
        subtitle: Text(dateFmt.format(record.date)),
        trailing: Text(
          '${income ? '+' : '-'}${money.format(record.amount)}',
          style: AppTheme.mono(
            fontWeight: FontWeight.w700,
            color: income ? AppColors.success : AppColors.error,
          ),
        ),
      ),
    );
  }
}
