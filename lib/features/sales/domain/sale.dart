/// One product line within a [Sale].
class SaleLine {
  const SaleLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  /// Line subtotal (Req 5.3).
  double get lineTotal => quantity * unitPrice;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  factory SaleLine.fromMap(Map<String, dynamic> map) => SaleLine(
        productId: map['productId'] as String,
        productName: map['productName'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      );
}

/// A recorded sales transaction (Glossary: Sale, Req 5).
class Sale {
  const Sale({
    required this.id,
    required this.lines,
    required this.createdAt,
  });

  final String id;
  final List<SaleLine> lines;
  final DateTime createdAt;

  /// Total amount = sum of line totals (Req 5.3).
  double get total => lines.fold(0, (sum, l) => sum + l.lineTotal);

  Map<String, dynamic> toMap() => {
        'lines': lines.map((l) => l.toMap()).toList(),
        'total': total,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
        id: map['id'] as String,
        lines: (map['lines'] as List<dynamic>? ?? [])
            .map((e) => SaleLine.fromMap(e as Map<String, dynamic>))
            .toList(),
        createdAt:
            DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                DateTime.now(),
      );
}
