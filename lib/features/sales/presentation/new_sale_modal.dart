import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_thumb.dart';
import '../domain/sale.dart';
import '../domain/sale_repository.dart';

/// Opens the new-sale modal. Returns true if a sale was recorded.
Future<bool?> showNewSaleModal(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _NewSaleModal(),
  );
}

/// Build and confirm a sale in a popup modal (Req 5) instead of a full page.
class _NewSaleModal extends ConsumerStatefulWidget {
  const _NewSaleModal();

  @override
  ConsumerState<_NewSaleModal> createState() => _NewSaleModalState();
}

class _NewSaleModalState extends ConsumerState<_NewSaleModal> {
  final Map<String, int> _cart = {}; // productId -> quantity
  Map<String, Product> _byId = {}; // latest products snapshot
  final _money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
  bool _busy = false;

  Future<void> _confirm() async {
    final repo = ref.read(saleRepositoryProvider);
    if (repo == null) return;

    final lines = <SaleLine>[];
    _cart.forEach((id, qty) {
      final p = _byId[id];
      if (p != null) {
        lines.add(SaleLine(
          productId: p.id,
          productName: p.name,
          quantity: qty,
          unitPrice: p.price,
        ));
      }
    });

    setState(() => _busy = true);
    try {
      await repo.recordSale(lines);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on SaleException catch (e) {
      AppSnack.error(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productRepo = ref.watch(productRepositoryProvider);

    return AlertDialog(
      title: const Text('New sale'),
      content: SizedBox(
        width: 460,
        height: 460,
        child: productRepo == null
            ? const SkeletonList(count: 5)
            : StreamBuilder<List<Product>>(
                stream: productRepo.watchProducts(),
                builder: (context, snap) {
                  final products = snap.data ?? const <Product>[];
                  _byId = {for (final p in products) p.id: p};
                  double total = 0;
                  _cart.forEach((id, qty) {
                    final p = _byId[id];
                    if (p != null) total += p.price * qty;
                  });

                  if (products.isEmpty) {
                    return const Center(
                      child: Text('No products yet. Add a product first.'),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView(
                          children: [
                            for (final p in products)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: ProductThumb(image: p.image, size: 40),
                                title: Text(p.name),
                                subtitle: Text(
                                    '${_money.format(p.price)} - ${p.stockQuantity} in stock'),
                                trailing: _QuantityStepper(
                                  quantity: _cart[p.id] ?? 0,
                                  onChanged: (q) => setState(() {
                                    if (q <= 0) {
                                      _cart.remove(p.id);
                                    } else {
                                      _cart[p.id] = q;
                                    }
                                  }),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Row(
                        children: [
                          const Text('Total',
                              style: TextStyle(color: AppColors.textSecondary)),
                          const Spacer(),
                          Text(
                            _money.format(total),
                            style: AppTheme.mono(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.teal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: (_busy || _cart.isEmpty) ? null : _confirm,
          icon: _busy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: const Text('Confirm sale'),
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: quantity > 0 ? () => onChanged(quantity - 1) : null,
        ),
        Text('$quantity', style: AppTheme.mono(fontWeight: FontWeight.w700)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged(quantity + 1),
        ),
      ],
    );
  }
}
