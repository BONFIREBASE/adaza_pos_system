import 'package:cloud_firestore/cloud_firestore.dart';

import 'sync_service.dart';

/// Firestore-backed [SyncService] (Req 8.1, 8.2).
///
/// Business data lives in shared top-level collections (`products`, `sales`,
/// `finance`) so the Owner and any future staff accounts operate on the same
/// data. Access is governed by Firestore security rules.
class FirestoreSyncService implements SyncService {
  FirestoreSyncService({required FirebaseFirestore firestore})
      : _db = firestore;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String collection) =>
      _db.collection(collection);

  @override
  Stream<List<Map<String, dynamic>>> watchCollection(String collection) {
    return _col(collection).snapshots().map(
          (snap) => snap.docs.map(_withId).toList(),
        );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCollection(String collection) async {
    try {
      final snap = await _col(collection).get();
      return snap.docs.map(_withId).toList();
    } on FirebaseException catch (e) {
      throw SyncException(e.message ?? 'Failed to fetch $collection.');
    }
  }

  @override
  Future<String> setDocument(
    String collection,
    String? id,
    Map<String, dynamic> data,
  ) async {
    try {
      if (id == null) {
        final ref = await _col(collection).add(data);
        return ref.id;
      }
      await _col(collection).doc(id).set(data, SetOptions(merge: true));
      return id;
    } on FirebaseException catch (e) {
      throw SyncException(e.message ?? 'Failed to save document.');
    }
  }

  @override
  Future<void> updateDocument(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      await _col(collection).doc(id).update(data);
    } on FirebaseException catch (e) {
      throw SyncException(e.message ?? 'Failed to update document.');
    }
  }

  @override
  Future<void> deleteDocument(String collection, String id) async {
    try {
      await _col(collection).doc(id).delete();
    } on FirebaseException catch (e) {
      throw SyncException(e.message ?? 'Failed to delete document.');
    }
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(SyncTransaction txn) actions,
  ) async {
    try {
      return await _db.runTransaction((txn) async {
        return actions(_FirestoreTxn(txn, _col));
      });
    } on FirebaseException catch (e) {
      throw SyncException(e.message ?? 'Transaction failed.');
    }
  }

  Map<String, dynamic> _withId(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      {...doc.data(), 'id': doc.id};
}

class _FirestoreTxn implements SyncTransaction {
  _FirestoreTxn(this._txn, this._col);

  final Transaction _txn;
  final CollectionReference<Map<String, dynamic>> Function(String) _col;

  @override
  Future<Map<String, dynamic>?> get(String collection, String id) async {
    final snap = await _txn.get(_col(collection).doc(id));
    final data = snap.data();
    return data == null ? null : {...data, 'id': snap.id};
  }

  @override
  void set(String collection, String id, Map<String, dynamic> data) {
    _txn.set(_col(collection).doc(id), data, SetOptions(merge: true));
  }

  @override
  void update(String collection, String id, Map<String, dynamic> data) {
    _txn.update(_col(collection).doc(id), data);
  }
}
