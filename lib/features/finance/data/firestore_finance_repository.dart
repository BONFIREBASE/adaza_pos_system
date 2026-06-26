import '../../../core/services/activity/activity_log_service.dart';
import '../../../core/services/sync/sync_service.dart';
import '../../activity/domain/activity_log.dart';
import '../domain/finance_record.dart';
import '../domain/finance_repository.dart';

/// [FinanceRepository] backed by the [SyncService] (Req 6).
class FirestoreFinanceRepository implements FinanceRepository {
  FirestoreFinanceRepository(this._sync, [this._log]);

  final SyncService _sync;
  final ActivityLogService? _log;
  static const _collection = 'finance';

  @override
  Stream<List<FinanceRecord>> watchRecords() => _sync
      .watchCollection(_collection)
      .map((rows) => rows.map(FinanceRecord.fromMap).toList()
        ..sort((a, b) => b.date.compareTo(a.date)));

  @override
  Future<List<FinanceRecord>> recordsInRange(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _sync.fetchCollection(_collection);
    return rows
        .map(FinanceRecord.fromMap)
        .where((r) => !r.date.isBefore(start) && !r.date.isAfter(end))
        .toList();
  }

  @override
  Future<FinanceRecord> create(FinanceRecord record) async {
    if (record.amount <= 0) {
      throw const FinanceValidationException('Amount must be greater than 0.');
    }
    final id = await _sync.setDocument(_collection, null, record.toMap());
    _log?.log(
        ActivityKind.financeCreated,
        '${record.type == FinanceType.income ? 'Added income' : 'Added expense'} '
        'of ₱${record.amount.toStringAsFixed(2)}'
        '${record.category.isEmpty ? '' : ' (${record.category})'}');
    return FinanceRecord(
      id: id,
      type: record.type,
      amount: record.amount,
      category: record.category,
      date: record.date,
      note: record.note,
      saleId: record.saleId,
    );
  }

  @override
  Future<void> update(FinanceRecord record) async {
    if (record.amount <= 0) {
      throw const FinanceValidationException('Amount must be greater than 0.');
    }
    await _sync.updateDocument(_collection, record.id, record.toMap());
    _log?.log(ActivityKind.financeUpdated,
        'Edited a ${record.type.name} entry (₱${record.amount.toStringAsFixed(2)})');
  }

  @override
  Future<void> delete(String id) async {
    await _sync.deleteDocument(_collection, id);
    _log?.log(ActivityKind.financeDeleted, 'Deleted a finance entry');
  }

  @override
  Future<double> profitInRange(DateTime start, DateTime end) async {
    final records = await recordsInRange(start, end);
    double income = 0;
    double expense = 0;
    for (final r in records) {
      if (r.type == FinanceType.income) {
        income += r.amount;
      } else {
        expense += r.amount;
      }
    }
    return income - expense;
  }
}
