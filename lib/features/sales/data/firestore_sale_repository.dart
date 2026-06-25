import '../../../core/services/sync/sync_service.dart';
import '../../finance/domain/finance_record.dart';
import '../domain/sale.dart';
import '../domain/sale_repository.dart';

/// [SaleRepository] that records sales atomically with stock + income updates.
class FirestoreSaleRepository implements SaleRepository {
  FirestoreSaleRepository(this._sync);

  final SyncService _sync;
  static const _salesCollection = 'sales';
  static const _productsCollection = 'products';
  static const _financeCollection = 'finance';

  @override
  Stream<List<Sale>> watchSales() =>
      _sync.watchCollection(_salesCollection).map((rows) {
        final sales = rows.map(Sale.fromMap).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return sales;
      });

  @override
  Future<Sale> recordSale(List<SaleLine> lines) async {
    if (lines.isEmpty) {
      throw const SaleException('Add at least one product to the sale.');
    }

    final now = DateTime.now();
    final sale = Sale(id: '_', lines: lines, createdAt: now);

    return _sync.runTransaction<Sale>((txn) async {
      // Validate and compute new stock for each line (Req 4.1, 4.5).
      final newQuantities = <String, int>{};
      for (final line in lines) {
        final data = await txn.get(_productsCollection, line.productId);
        if (data == null) {
          throw SaleException('Product "${line.productName}" no longer exists.');
        }
        final current = (data['stockQuantity'] as num?)?.toInt() ?? 0;
        final remaining = current - line.quantity;
        if (remaining < 0) {
          throw SaleException(
            'Insufficient stock for "${line.productName}".',
          );
        }
        newQuantities[line.productId] = remaining;
      }

      // Persist sale.
      final saleId = '${now.microsecondsSinceEpoch}';
      txn.set(_salesCollection, saleId, sale.toMap());

      // Decrement stock.
      newQuantities.forEach((productId, qty) {
        txn.update(_productsCollection, productId, {'stockQuantity': qty});
      });

      // Derived income record (Req 5.2).
      final income = FinanceRecord(
        id: '_',
        type: FinanceType.income,
        amount: sale.total,
        category: 'Sale',
        date: now,
        saleId: saleId,
      );
      txn.set(_financeCollection, 'sale_$saleId', income.toMap());

      return Sale(id: saleId, lines: lines, createdAt: now);
    });
  }
}
