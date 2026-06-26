import 'package:flutter/material.dart';

/// The kind of action recorded in the audit log. Drives the icon/colour shown
/// in the activity feed and notification panel.
enum ActivityKind {
  saleRecorded,
  saleVoided,
  productCreated,
  productUpdated,
  productDeleted,
  stockAdjusted,
  financeCreated,
  financeUpdated,
  financeDeleted,
  accountCreated,
  accountUpdated,
  accountDisabled,
  accountEnabled,
  accountRemoved,
  roleCreated,
  roleUpdated,
  roleDeleted,
  passwordChanged,
  other;

  static ActivityKind fromName(String? n) {
    for (final k in ActivityKind.values) {
      if (k.name == n) return k;
    }
    return ActivityKind.other;
  }

  IconData get icon => switch (this) {
        ActivityKind.saleRecorded => Icons.point_of_sale_outlined,
        ActivityKind.saleVoided => Icons.remove_shopping_cart_outlined,
        ActivityKind.productCreated => Icons.add_box_outlined,
        ActivityKind.productUpdated => Icons.edit_outlined,
        ActivityKind.productDeleted => Icons.delete_outline,
        ActivityKind.stockAdjusted => Icons.inventory_outlined,
        ActivityKind.financeCreated => Icons.account_balance_wallet_outlined,
        ActivityKind.financeUpdated => Icons.edit_note_outlined,
        ActivityKind.financeDeleted => Icons.money_off_outlined,
        ActivityKind.accountCreated => Icons.person_add_outlined,
        ActivityKind.accountUpdated => Icons.manage_accounts_outlined,
        ActivityKind.accountDisabled => Icons.block_outlined,
        ActivityKind.accountEnabled => Icons.check_circle_outline,
        ActivityKind.accountRemoved => Icons.person_remove_outlined,
        ActivityKind.roleCreated => Icons.badge_outlined,
        ActivityKind.roleUpdated => Icons.badge_outlined,
        ActivityKind.roleDeleted => Icons.badge_outlined,
        ActivityKind.passwordChanged => Icons.lock_reset_outlined,
        ActivityKind.other => Icons.history,
      };

  /// True for actions that are destructive / sensitive (shown in a warm tone).
  bool get isSensitive => switch (this) {
        ActivityKind.saleVoided ||
        ActivityKind.productDeleted ||
        ActivityKind.financeDeleted ||
        ActivityKind.accountDisabled ||
        ActivityKind.accountRemoved ||
        ActivityKind.roleDeleted =>
          true,
        _ => false,
      };
}

/// An immutable audit-log entry: who did what, when. Stored append-only in the
/// `activity` Firestore collection.
class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.kind,
    required this.summary,
    required this.actorId,
    required this.actorName,
    required this.at,
  });

  final String id;
  final ActivityKind kind;

  /// Human-readable description, e.g. `Recorded a sale of ₱350.00 (3 items)`.
  final String summary;

  final String actorId;
  final String actorName;
  final DateTime at;

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'summary': summary,
        'actorId': actorId,
        'actorName': actorName,
        'at': at.toIso8601String(),
      };

  factory ActivityLog.fromMap(Map<String, dynamic> map) => ActivityLog(
        id: map['id'] as String? ?? '',
        kind: ActivityKind.fromName(map['kind'] as String?),
        summary: map['summary'] as String? ?? '',
        actorId: map['actorId'] as String? ?? '',
        actorName: map['actorName'] as String? ?? 'Unknown',
        at: DateTime.tryParse(map['at'] as String? ?? '') ?? DateTime.now(),
      );
}
