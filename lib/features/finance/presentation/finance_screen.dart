import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_nav_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/finance_record.dart';
import '../domain/finance_repository.dart';

/// Income and expense list with quick entry (Req 6).
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(financeRepositoryProvider);
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final dateFmt = DateFormat.yMMMd();

    return AppNavScaffold(
      title: 'Income & Expenses',
      currentRoute: '/finance',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: repo == null ? null : () => _showAddSheet(context, ref),
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
                  itemCount: records.length,
                  itemBuilder: (context, i) {
                    final r = records[i];
                    final income = r.type == FinanceType.income;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: Icon(
                          income ? Icons.arrow_downward : Icons.arrow_upward,
                          color: income ? AppColors.success : AppColors.error,
                        ),
                        title: Text(r.category),
                        subtitle: Text(dateFmt.format(r.date)),
                        trailing: Text(
                          '${income ? '+' : '-'}${money.format(r.amount)}',
                          style: AppTheme.mono(
                            fontWeight: FontWeight.w700,
                            color:
                                income ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final amount = TextEditingController();
    final category = TextEditingController();
    FinanceType type = FinanceType.expense;

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
                    try {
                      await repo.create(
                        FinanceRecord(
                          id: '_',
                          type: type,
                          amount: double.tryParse(amount.text) ?? 0,
                          category: category.text.trim().isEmpty
                              ? type.name
                              : category.text.trim(),
                          date: DateTime.now(),
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        AppSnack.success(context, 'Entry added.');
                      }
                    } on FinanceValidationException catch (e) {
                      if (!ctx.mounted) return;
                      AppSnack.error(ctx, e.message);
                    }
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
