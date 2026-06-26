import 'dart:async';

import 'sync_service.dart';

/// In-memory [SyncService] for demo/offline runs and tests. No Firebase needed.
class InMemorySyncService implements SyncService {
  final Map<String, Map<String, Map<String, dynamic>>> _store = {};
  final Map<String, StreamController<List<Map<String, dynamic>>>> _controllers =
      {};
  int _autoId = 0;

  Map<String, Map<String, dynamic>> _col(String c) =>
      _store.putIfAbsent(c, () => {});

  void _emit(String c) {
    _controllers[c]?.add(_snapshot(c));
  }

  List<Map<String, dynamic>> _snapshot(String c) =>
      _col(c).entries.map((e) => {...e.value, 'id': e.key}).toList();

  @override
  Stream<List<Map<String, dynamic>>> watchCollection(String collection) {
    final ctrl = _controllers.putIfAbsent(
      collection,
      () => StreamController<List<Map<String, dynamic>>>.broadcast(),
    );
    scheduleMicrotask(() => ctrl.add(_snapshot(collection)));
    return ctrl.stream;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCollection(String collection) async =>
      _snapshot(collection);

  @override
  Future<String> setDocument(
    String collection,
    String? id,
    Map<String, dynamic> data,
  ) async {
    final key = id ?? 'mem_${_autoId++}';
    _col(collection)[key] = {..._col(collection)[key] ?? {}, ...data};
    _emit(collection);
    return key;
  }

  @override
  Future<void> updateDocument(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    _col(collection)[id] = {..._col(collection)[id] ?? {}, ...data};
    _emit(collection);
  }

  @override
  Future<void> deleteDocument(String collection, String id) async {
    _col(collection).remove(id);
    _emit(collection);
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(SyncTransaction txn) actions,
  ) async {
    final txn = _InMemoryTxn(this);
    final result = await actions(txn);
    txn._touched.forEach(_emit);
    return result;
  }
}

class _InMemoryTxn implements SyncTransaction {
  _InMemoryTxn(this._svc);
  final InMemorySyncService _svc;
  final Set<String> _touched = {};

  @override
  Future<Map<String, dynamic>?> get(String collection, String id) async {
    final data = _svc._col(collection)[id];
    return data == null ? null : {...data, 'id': id};
  }

  @override
  void set(String collection, String id, Map<String, dynamic> data) {
    _svc._col(collection)[id] = {..._svc._col(collection)[id] ?? {}, ...data};
    _touched.add(collection);
  }

  @override
  void update(String collection, String id, Map<String, dynamic> data) {
    _svc._col(collection)[id] = {..._svc._col(collection)[id] ?? {}, ...data};
    _touched.add(collection);
  }

  @override
  void delete(String collection, String id) {
    _svc._col(collection).remove(id);
    _touched.add(collection);
  }
}
