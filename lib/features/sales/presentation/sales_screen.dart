import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_nav_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/sale.dart';
import 'new_sale_modal.dart';

/// Recorded sales list, newest first (Req 5.5).
class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(saleRepositoryProvider);
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final dateFmt = DateFormat.yMMMd().add_jm();

    return AppNavScaffold(
      title: 'Sales',
      currentRoute: '/sales',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final recorded = await showNewSaleModal(context);
          if (recorded == true && context.mounted) {
            AppSnack.success(context, 'Sale recorded.');
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New sale'),
      ),
      body: repo == null
          ? const SkeletonList()
          : StreamBuilder<List<Sale>>(
              stream: repo.watchSales(),
              builder: (context, snap) {
                if (!snap.hasData) return const SkeletonList();
                final sales = snap.data!;
                if (sales.isEmpty) {
                  return const Center(child: Text('No sales recorded yet.'));
                }
                return ListView.builder(
                  itemCount: sales.length,
                  itemBuilder: (context, i) {
                    final s = sales[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ExpansionTile(
                        title: Text(money.format(s.total),
                            style: AppTheme.mono(
                                fontWeight: FontWeight.w700,
                                color: AppColors.teal)),
                        subtitle: Text(dateFmt.format(s.createdAt)),
                        children: [
                          for (final line in s.lines)
                            ListTile(
                              dense: true,
                              title: Text(line.productName),
                              trailing: Text(
                                '${line.quantity} x ${money.format(line.unitPrice)}',
                                style: AppTheme.mono(),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
