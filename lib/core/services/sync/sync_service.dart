/// Raised when a sync operation fails, e.g. due to lost connectivity (Req 8.3).
class SyncException implements Exception {
  const SyncException(this.message);
  final String message;

  @override
  String toString() => 'SyncException: $message';
}

/// Abstraction over cloud persistence (Req 8).
///
/// Feature repositories depend on this contract rather than Firestore directly,
/// keeping application logic platform-independent (Req 8.5) and allowing the
/// backend to be swapped or mocked in tests.
abstract interface class SyncService {
  /// Streams a live collection of documents under [collection] scoped to the
  /// current owner.
  Stream<List<Map<String, dynamic>>> watchCollection(String collection);

  /// One-time fetch of a collection (Req 8.2).
  Future<List<Map<String, dynamic>>> fetchCollection(String collection);

  /// Creates or replaces a document, returning its id (Req 8.1).
  Future<String> setDocument(
    String collection,
    String? id,
    Map<String, dynamic> data,
  );

  /// Updates fields on an existing document.
  Future<void> updateDocument(
    String collection,
    String id,
    Map<String, dynamic> data,
  );

  /// Deletes a document.
  Future<void> deleteDocument(String collection, String id);

  /// Runs [actions] atomically so multi-document changes (e.g. a sale that also
  /// decrements stock and writes an income record) stay consistent.
  Future<T> runTransaction<T>(
    Future<T> Function(SyncTransaction txn) actions,
  );
}

/// Handle passed into [SyncService.runTransaction] for atomic operations.
abstract interface class SyncTransaction {
  Future<Map<String, dynamic>?> get(String collection, String id);
  void set(String collection, String id, Map<String, dynamic> data);
  void update(String collection, String id, Map<String, dynamic> data);
  void delete(String collection, String id);
}
