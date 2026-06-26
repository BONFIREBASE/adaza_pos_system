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

/// Build and confirm a sale in a popup modal (Req 5). Quantities are capped to
/// available stock here; the sale transaction re-checks stock server-side, so
/// overselling is impossible even if stock changes mid-sale.
class _NewSaleModal extends ConsumerStatefulWidget {
  const _NewSaleModal();

  @override
  ConsumerState<_NewSaleModal> createState() => _NewSaleModalState();
}

class _NewSaleModalState extends ConsumerState<_NewSaleModal> {
  final Map<String, int> _cart = {}; // productId -> quantity
  Map<String, Product> _byId = {}; // latest products snapshot
  final _money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
  String _query = '';
  bool _busy = false;

  int get _itemCount => _cart.values.fold(0, (a, b) => a + b);

  double get _total {
    double t = 0;
    _cart.forEach((id, qty) {
      final p = _byId[id];
      if (p != null) t += p.price * qty;
    });
    return t;
  }

  void _setQty(Product p, int qty) {
    final clamped = qty.clamp(0, p.stockQuantity);
    setState(() {
      if (clamped <= 0) {
        _cart.remove(p.id);
      } else {
        _cart[p.id] = clamped;
      }
    });
  }

  /// Keep cart quantities within current stock (handles live stock drops).
  void _reconcile() {
    var changed = false;
    _cart.removeWhere((id, qty) {
      final p = _byId[id];
      if (p == null || p.stockQuantity <= 0) {
        changed = true;
        return true;
      }
      return false;
    });
    _cart.updateAll((id, qty) {
      final stock = _byId[id]!.stockQuantity;
      if (qty > stock) {
        changed = true;
        return stock;
      }
      return qty;
    });
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

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
      title: Row(
        children: [
          const Text('New sale'),
          const Spacer(),
          if (_itemCount > 0)
            Text('$_itemCount item${_itemCount == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 500,
        child: productRepo == null
            ? const SkeletonList(count: 5)
            : StreamBuilder<List<Product>>(
                stream: productRepo.watchProducts(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SkeletonList(count: 5);
                  final all = snap.data!;
                  _byId = {for (final p in all) p.id: p};
                  _reconcile();

                  if (all.isEmpty) {
                    return const Center(
                      child: Text('No products yet. Add a product first.'),
                    );
                  }

                  final products = all
                      .where((p) =>
                          p.name.toLowerCase().contains(_query) ||
                          p.barcode.contains(_query))
                      .toList()
                    ..sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                  return Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search products',
                        ),
                        onChanged: (v) =>
                            setState(() => _query = v.toLowerCase()),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: products.isEmpty
                            ? const Center(child: Text('No matches.'))
                            : ListView.builder(
                                itemCount: products.length,
                                itemBuilder: (context, i) {
                                  final p = products[i];
                                  return _ProductRow(
                                    product: p,
                                    money: _money,
                                    inCart: _cart[p.id] ?? 0,
                                    onChanged: (q) => _setQty(p, q),
                                  );
                                },
                              ),
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Text('Total',
                              style: TextStyle(color: AppColors.textSecondary)),
                          const Spacer(),
                          Text(
                            _money.format(_total),
                            style: AppTheme.mono(
                              fontSize: 22,
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
          label: Text(_cart.isEmpty
              ? 'Confirm sale'
              : 'Confirm sale · ${_money.format(_total)}'),
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.money,
    required this.inCart,
    required this.onChanged,
  });

  final Product product;
  final NumberFormat money;
  final int inCart;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final out = product.stockQuantity <= 0;
    final low = product.isLowStock && !out;

    return Opacity(
      opacity: out ? 0.55 : 1,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: ProductThumb(image: product.image, size: 40),
        title: Text(product.name),
        subtitle: Row(
          children: [
            Text(money.format(product.price)),
            const SizedBox(width: 8),
            if (out)
              const _Tag(label: 'Out of stock', color: AppColors.error)
            else
              _Tag(
                label: '${product.stockQuantity} in stock',
                color: low ? AppColors.warning : AppColors.textSecondary,
              ),
          ],
        ),
        trailing: out
            ? null
            : _QuantityStepper(
                quantity: inCart,
                max: product.stockQuantity,
                onChanged: onChanged,
              ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600));
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.max,
    required this.onChanged,
  });

  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final atMax = quantity >= max;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: quantity > 0 ? () => onChanged(quantity - 1) : null,
        ),
        SizedBox(
          width: 24,
          child: Text('$quantity',
              textAlign: TextAlign.center,
              style: AppTheme.mono(fontWeight: FontWeight.w700)),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline),
          tooltip: atMax ? 'No more stock' : null,
          onPressed: atMax ? null : () => onChanged(quantity + 1),
        ),
      ],
    );
  }
}
