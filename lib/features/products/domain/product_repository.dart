import 'product.dart';

/// Raised on product rule violations so the UI can show a precise message.
class ProductValidationException implements Exception {
  const ProductValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Contract for product persistence and lookup (Req 2).
abstract interface class ProductRepository {
  Stream<List<Product>> watchProducts();

  Future<List<Product>> getProducts();

  Future<Product?> findByBarcode(String barcode);

  /// Creates a product. Throws [ProductValidationException] on missing fields
  /// (Req 2.2) or duplicate barcode (Req 2.5).
  Future<Product> create(Product product);

  Future<void> update(Product product);

  Future<void> delete(String id);

  /// Persists an adjusted stock quantity (Req 4.2).
  Future<void> adjustStock(String id, int newQuantity);
}
