enum FinanceType { income, expense }

/// A money movement entry: Income_Record or Expense_Record (Req 6).
class FinanceRecord {
  const FinanceRecord({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
    this.saleId,
  });

  final String id;
  final FinanceType type;
  final double amount;
  final String category;
  final DateTime date;
  final String note;

  /// Set when this income entry was derived from a Sale (Req 5.2).
  final String? saleId;

  bool get isFromSale => saleId != null;

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'note': note,
        'saleId': saleId,
      };

  factory FinanceRecord.fromMap(Map<String, dynamic> map) => FinanceRecord(
        id: map['id'] as String,
        type: FinanceType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => FinanceType.income,
        ),
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        category: map['category'] as String? ?? '',
        date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
        note: map['note'] as String? ?? '',
        saleId: map['saleId'] as String?,
      );
}
