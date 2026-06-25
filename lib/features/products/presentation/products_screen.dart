import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_nav_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/product.dart';
import 'product_form_modal.dart';
import 'product_thumb.dart';

/// Searchable product catalog (Req 2.6).
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _query = '';

  Future<void> _edit(Product p) async {
    final saved = await showProductFormModal(context, product: p);
    if (saved == true && mounted) {
      AppSnack.success(context, 'Product updated.');
    }
  }

  Future<void> _delete(Product p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product'),
        content: Text('Delete "${p.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final repo = ref.read(productRepositoryProvider);
    if (repo == null) return;
    try {
      await repo.delete(p.id);
      if (mounted) AppSnack.success(context, 'Product deleted.');
    } catch (_) {
      if (mounted) AppSnack.error(context, 'Could not delete product.');
    }
  }

  Future<void> _togglePin(Product p) async {
    final repo = ref.read(productRepositoryProvider);
    if (repo == null) return;
    try {
      await repo.update(p.copyWith(pinned: !p.pinned));
      if (mounted) {
        AppSnack.success(context, p.pinned ? 'Unpinned.' : 'Pinned to top.');
      }
    } catch (_) {
      if (mounted) AppSnack.error(context, 'Could not update product.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(productRepositoryProvider);
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

    return AppNavScaffold(
      title: 'Products',
      currentRoute: '/products',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showProductFormModal(context);
          if (created == true && context.mounted) {
            AppSnack.success(context, 'Product saved.');
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New product'),
      ),
      body: repo == null
          ? const SkeletonList()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search products',
                    ),
                    onChanged: (v) => setState(() => _query = v.toLowerCase()),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<Product>>(
                    stream: repo.watchProducts(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const SkeletonList();
                      }
                      final products = snap.data!
                          .where((p) =>
                              p.name.toLowerCase().contains(_query) ||
                              p.barcode.contains(_query))
                          .toList()
                        ..sort((a, b) {
                          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
                          return a.name
                              .toLowerCase()
                              .compareTo(b.name.toLowerCase());
                        });
                      if (products.isEmpty) {
                        return const Center(
                          child: Text('No products yet. Add one to start.'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: products.length,
                        itemBuilder: (context, i) {
                          final p = products[i];
                          return _ProductRow(
                            product: p,
                            money: money,
                            onEdit: () => _edit(p),
                            onDelete: () => _delete(p),
                            onTogglePin: () => _togglePin(p),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// A product row: double-click to edit, swipe right to pin, swipe left to
/// delete. The swipe never auto-dismisses — the actions drive the live list.
class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.money,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
  });

  final Product product;
  final NumberFormat money;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(product.id),
      // Swipe right (start->end) = pin; swipe left (end->start) = delete.
      background: _SwipeBg(
        color: AppColors.teal,
        icon: product.pinned ? Icons.push_pin_outlined : Icons.push_pin,
        label: product.pinned ? 'Unpin' : 'Pin',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: const _SwipeBg(
        color: AppColors.error,
        icon: Icons.delete_outline,
        label: 'Delete',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onTogglePin();
        } else {
          onDelete();
        }
        return false; // actions update the live list; don't remove here
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: GestureDetector(
          onDoubleTap: onEdit,
          child: ListTile(
            leading: ProductThumb(image: product.image),
            title: Row(
              children: [
                if (product.pinned) ...[
                  const Icon(Icons.push_pin, size: 14, color: AppColors.teal),
                  const SizedBox(width: 4),
                ],
                Flexible(child: Text(product.name)),
              ],
            ),
            subtitle: Text(
                'Barcode ${product.barcode} - ${product.stockQuantity} in stock'),
            trailing: Text(
              money.format(product.price),
              style: AppTheme.mono(
                  fontWeight: FontWeight.w700, color: AppColors.teal),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
