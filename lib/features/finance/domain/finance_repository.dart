import 'finance_record.dart';

class FinanceValidationException implements Exception {
  const FinanceValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Contract for income and expense tracking (Req 6).
abstract interface class FinanceRepository {
  Stream<List<FinanceRecord>> watchRecords();

  /// Records within an inclusive date range (Req 6.4).
  Future<List<FinanceRecord>> recordsInRange(DateTime start, DateTime end);

  /// Creates a record. Throws [FinanceValidationException] for non-positive
  /// amounts (Req 6.3).
  Future<FinanceRecord> create(FinanceRecord record);

  /// Updates an existing record (manager only). Sale-derived income records
  /// should not be edited here — void the sale instead.
  Future<void> update(FinanceRecord record);

  Future<void> delete(String id);

  /// Profit = total income - total expense for the range (Req 6.5).
  Future<double> profitInRange(DateTime start, DateTime end);
}
