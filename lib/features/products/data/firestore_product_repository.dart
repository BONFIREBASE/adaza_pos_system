import '../../../core/services/activity/activity_log_service.dart';
import '../../../core/services/sync/sync_service.dart';
import '../../activity/domain/activity_log.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

/// [ProductRepository] backed by the [SyncService] (Req 2, 4.2).
class FirestoreProductRepository implements ProductRepository {
  FirestoreProductRepository(this._sync, [this._log]);

  final SyncService _sync;
  final ActivityLogService? _log;
  static const _collection = 'products';

  @override
  Stream<List<Product>> watchProducts() => _sync
      .watchCollection(_collection)
      .map((rows) => rows.map(Product.fromMap).toList());

  @override
  Future<List<Product>> getProducts() async {
    final rows = await _sync.fetchCollection(_collection);
    return rows.map(Product.fromMap).toList();
  }

  @override
  Future<Product?> findByBarcode(String barcode) async {
    final products = await getProducts();
    for (final p in products) {
      if (p.barcode == barcode) return p;
    }
    return null;
  }

  @override
  Future<Product> create(Product product) async {
    _validate(product);
    if (await findByBarcode(product.barcode) != null) {
      throw const ProductValidationException(
        'A product with this barcode already exists.',
      );
    }
    final id = await _sync.setDocument(_collection, null, product.toMap());
    _log?.log(ActivityKind.productCreated,
        'Added product "${product.name}" (₱${product.price.toStringAsFixed(2)})');
    return product.copyWith(id: id);
  }

  @override
  Future<void> update(Product product) async {
    _validate(product);
    final existing = await findByBarcode(product.barcode);
    if (existing != null && existing.id != product.id) {
      throw const ProductValidationException(
        'A product with this barcode already exists.',
      );
    }
    await _sync.updateDocument(_collection, product.id, product.toMap());
    _log?.log(ActivityKind.productUpdated, 'Updated product "${product.name}"');
  }

  @override
  Future<void> delete(String id) async {
    await _sync.deleteDocument(_collection, id);
    _log?.log(ActivityKind.productDeleted, 'Deleted a product');
  }

  @override
  Future<void> adjustStock(String id, int newQuantity) async {
    await _sync.updateDocument(_collection, id, {'stockQuantity': newQuantity});
    _log?.log(ActivityKind.stockAdjusted, 'Set stock to $newQuantity units');
  }

  void _validate(Product product) {
    if (product.name.trim().isEmpty) {
      throw const ProductValidationException('Name is required.');
    }
    if (product.barcode.trim().isEmpty) {
      throw const ProductValidationException('Barcode is required.');
    }
    if (product.price <= 0) {
      throw const ProductValidationException('Price is required.');
    }
    if (product.cost < 0) {
      throw const ProductValidationException('Cost is required.');
    }
  }
}
