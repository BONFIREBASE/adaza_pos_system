import 'sale.dart';

/// Raised when a sale cannot be recorded (empty sale, insufficient stock).
class SaleException implements Exception {
  const SaleException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Contract for recording and reading sales (Req 5).
abstract interface class SaleRepository {
  /// Sales ordered by transaction date, newest first (Req 5.5).
  Stream<List<Sale>> watchSales();

  /// Atomically records the sale, decrements stock (Req 4.1) and writes the
  /// derived income record (Req 5.2). Throws [SaleException] for empty sales
  /// (Req 5.4) or insufficient stock (Req 4.5).
  Future<Sale> recordSale(List<SaleLine> lines);

  /// Voids a sale: restocks the sold items and removes the linked income
  /// record, atomically. For Owner/Admin (manage finance) only.
  Future<void> voidSale(String saleId);
}
