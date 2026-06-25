/// A sellable item tracked by the POS (Glossary: Product).
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.cost,
    required this.stockQuantity,
    this.lowStockThreshold = 5,
    this.image,
    this.pinned = false,
  });

  final String id;
  final String name;
  final String barcode;

  /// Selling price charged to the customer.
  final double price;

  /// Acquisition cost paid to the supplier. Margin = price - cost.
  final double cost;

  final int stockQuantity;
  final int lowStockThreshold;

  /// Optional product photo, stored as a base64-encoded (compressed) image.
  final String? image;

  /// Pinned products are surfaced at the top of the catalog.
  final bool pinned;

  /// Flagged as low stock while quantity is at or below threshold (Req 4.3).
  bool get isLowStock => stockQuantity <= lowStockThreshold;

  /// Profit per unit sold.
  double get margin => price - cost;

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? price,
    double? cost,
    int? stockQuantity,
    int? lowStockThreshold,
    String? image,
    bool? pinned,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      image: image ?? this.image,
      pinned: pinned ?? this.pinned,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'barcode': barcode,
        'price': price,
        'cost': cost,
        'stockQuantity': stockQuantity,
        'lowStockThreshold': lowStockThreshold,
        'image': image,
        'pinned': pinned,
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        barcode: map['barcode'] as String? ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0,
        cost: (map['cost'] as num?)?.toDouble() ?? 0,
        stockQuantity: (map['stockQuantity'] as num?)?.toInt() ?? 0,
        lowStockThreshold: (map['lowStockThreshold'] as num?)?.toInt() ?? 5,
        image: map['image'] as String?,
        pinned: map['pinned'] as bool? ?? false,
      );
}
