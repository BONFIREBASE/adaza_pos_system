import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../finance/domain/finance_record.dart';
import '../products/domain/product.dart';
import '../sales/domain/sale.dart';
import 'report_service.dart';

/// Lets the owner/admin generate branded PDF reports to print or download.
Future<void> showExportModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ExportModal(),
  );
}

class _ExportModal extends ConsumerStatefulWidget {
  const _ExportModal();

  @override
  ConsumerState<_ExportModal> createState() => _ExportModalState();
}

class _ExportModalState extends ConsumerState<_ExportModal> {
  String? _busy;

  Future<void> _run(String key, Future<void> Function() action) async {
    setState(() => _busy = key);
    try {
      await action();
    } catch (_) {
      if (mounted) AppSnack.error(context, 'Could not generate the report.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _products() => _run('products', () async {
        final repo = ref.read(productRepositoryProvider);
        if (repo == null) return;
        final List<Product> items = await repo.getProducts();
        await Printing.layoutPdf(
          name: 'Adaza Products',
          onLayout: (_) => ReportService.products(items),
        );
      });

  Future<void> _sales() => _run('sales', () async {
        final repo = ref.read(saleRepositoryProvider);
        if (repo == null) return;
        final List<Sale> items = await repo.watchSales().first;
        await Printing.layoutPdf(
          name: 'Adaza Sales',
          onLayout: (_) => ReportService.sales(items),
        );
      });

  Future<void> _finance() => _run('finance', () async {
        final repo = ref.read(financeRepositoryProvider);
        if (repo == null) return;
        final List<FinanceRecord> items = await repo.watchRecords().first;
        await Printing.layoutPdf(
          name: 'Adaza Finance',
          onLayout: (_) => ReportService.finance(items),
        );
      });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reports'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Generate a branded PDF you can print or save.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            _row('Product catalog', Icons.inventory_2_outlined, 'products',
                _products),
            _row('Sales report', Icons.point_of_sale_outlined, 'sales', _sales),
            _row('Income & expense report', Icons.savings_outlined, 'finance',
                _finance),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _row(String label, IconData icon, String key, VoidCallback onTap) {
    final busy = _busy == key;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.teal),
      title: Text(label),
      trailing: busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.picture_as_pdf_outlined),
      onTap: _busy == null ? onTap : null,
    );
  }
}
