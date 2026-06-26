import '../../../features/activity/domain/activity_log.dart';
import '../../../features/auth/domain/app_user.dart';
import '../sync/sync_service.dart';

/// Writes and reads the append-only audit log (the `activity` collection).
///
/// Logging is best-effort: a failure to write a log entry must never break the
/// underlying business action, so [log] swallows its own errors.
class ActivityLogService {
  ActivityLogService({
    required SyncService sync,
    required AppUser? Function() actor,
  })  : _sync = sync,
        _actor = actor;

  final SyncService _sync;
  final AppUser? Function() _actor;

  static const _collection = 'activity';

  /// Appends an entry describing [summary] of kind [kind], attributed to the
  /// currently signed-in user. Never throws.
  Future<void> log(ActivityKind kind, String summary) async {
    try {
      final user = _actor();
      final entry = ActivityLog(
        id: '_',
        kind: kind,
        summary: summary,
        actorId: user?.id ?? 'system',
        actorName: user?.displayName ?? 'System',
        at: DateTime.now(),
      );
      await _sync.setDocument(_collection, null, entry.toMap());
    } catch (_) {
      // Audit logging is best-effort; ignore failures.
    }
  }

  /// Live stream of recent log entries, newest first (capped to [limit]).
  Stream<List<ActivityLog>> watchRecent({int limit = 100}) {
    return _sync.watchCollection(_collection).map((rows) {
      final logs = rows.map(ActivityLog.fromMap).toList()
        ..sort((a, b) => b.at.compareTo(a.at));
      return logs.length > limit ? logs.sublist(0, limit) : logs;
    });
  }
}
