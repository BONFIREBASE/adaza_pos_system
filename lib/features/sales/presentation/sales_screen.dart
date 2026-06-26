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
import '../domain/sale.dart';
import '../domain/sale_repository.dart';
import 'new_sale_modal.dart';
import 'receipt_service.dart';
import 'package:printing/printing.dart';

/// Recorded sales list, newest first (Req 5.5). Owner/Admin can void a sale
/// (swipe left) — which restocks the items and removes its income record.
class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(saleRepositoryProvider);
    final canVoid = ref.watch(currentUserProvider)?.can(
              AppPermission.manageFinance,
            ) ??
        false;
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
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: sales.length,
                  itemBuilder: (context, i) {
                    final s = sales[i];
                    final card = Card(
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _receipt(context, s),
                                  icon: const Icon(Icons.receipt_long_outlined,
                                      size: 18),
                                  label: const Text('Receipt'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );

                    if (!canVoid) return card;

                    return Dismissible(
                      key: ValueKey(s.id),
                      direction: DismissDirection.endToStart,
                      background: const SizedBox.shrink(),
                      secondaryBackground: _voidBg(),
                      confirmDismiss: (_) async {
                        await _void(context, ref, repo, s, money);
                        return false;
                      },
                      child: card,
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _receipt(BuildContext context, Sale s) async {
    try {
      await Printing.layoutPdf(
        name: 'Adaza Receipt #${s.id}',
        onLayout: (_) => ReceiptService.build(s),
      );
    } catch (_) {
      if (context.mounted) {
        AppSnack.error(context, 'Could not generate the receipt.');
      }
    }
  }

  Widget _voidBg() => Container(
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
            Icon(Icons.undo, color: Colors.white),
            SizedBox(width: 8),
            Text('Void',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Future<void> _void(BuildContext context, WidgetRef ref, SaleRepository repo,
      Sale s, NumberFormat money) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void sale'),
        content: Text(
          'Void this ${money.format(s.total)} sale? The items will be '
          'restocked and its income entry removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Void sale'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await repo.voidSale(s.id);
      if (context.mounted) AppSnack.success(context, 'Sale voided & restocked.');
    } on SaleException catch (e) {
      if (context.mounted) AppSnack.error(context, e.message);
    } catch (_) {
      if (context.mounted) AppSnack.error(context, 'Could not void the sale.');
    }
  }
}
