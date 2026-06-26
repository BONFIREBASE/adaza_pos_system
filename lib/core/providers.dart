import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/firebase_auth_repository.dart';
import '../features/auth/domain/app_user.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/finance/data/firestore_finance_repository.dart';
import '../features/finance/domain/finance_repository.dart';
import '../features/management/data/firestore_management_repository.dart';
import '../features/management/domain/management_repository.dart';
import '../features/products/data/firestore_product_repository.dart';
import '../features/products/domain/product.dart';
import '../features/products/domain/product_repository.dart';
import '../features/roles/data/firestore_roles_repository.dart';
import '../features/roles/domain/role.dart';
import '../features/roles/domain/roles_repository.dart';
import '../features/sales/data/firestore_sale_repository.dart';
import '../features/sales/domain/sale_repository.dart';
import '../features/activity/domain/activity_log.dart';
import 'services/activity/activity_log_service.dart';
import 'services/scan/camera_scanner.dart';
import 'services/scan/scan_source.dart';
import 'services/sync/firestore_sync_service.dart';
import 'services/sync/sync_service.dart';

/// Central composition root. Repositories depend on these so features stay
/// decoupled from concrete Firebase classes.

// --- Firebase singletons -----------------------------------------------------
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// --- Auth --------------------------------------------------------------------
// Production: real Firebase Auth with roles resolved from Firestore users/{uid}.
// The demo entry point (main_demo.dart) overrides this with LocalAuthRepository.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  ),
);

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// The signed-in user, or null. Convenience for role/permission checks.
final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(authStateProvider).valueOrNull,
);

/// Whether the current user holds [permission]. Features gate UI on this.
final permissionProvider = Provider.family<bool, AppPermission>(
  (ref, permission) =>
      ref.watch(currentUserProvider)?.can(permission) ?? false,
);

// --- Sync (shared business data, gated on an authenticated session) ----------
final syncServiceProvider = Provider<SyncService?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return FirestoreSyncService(firestore: ref.watch(firestoreProvider));
});

// --- Scanning ----------------------------------------------------------------
final scanSourceProvider = Provider<ScanSource>((ref) => CameraScanner());

// --- Activity log (append-only audit trail) ----------------------------------
final activityLogProvider = Provider<ActivityLogService?>((ref) {
  final sync = ref.watch(syncServiceProvider);
  if (sync == null) return null;
  return ActivityLogService(
    sync: sync,
    actor: () => ref.read(currentUserProvider),
  );
});

/// Live feed of recent audit-log entries (newest first); empty while signed out.
final activityFeedProvider = StreamProvider<List<ActivityLog>>((ref) {
  final log = ref.watch(activityLogProvider);
  if (log == null) return Stream.value(const []);
  return log.watchRecent();
});

/// Products currently at or below their low-stock threshold (drives alerts).
final lowStockProductsProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo
      .watchProducts()
      .map((items) => items.where((p) => p.isLowStock).toList()
        ..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity)));
});

/// Tracks the timestamp the current user last opened notifications, so the bell
/// can surface an unread count. Session-scoped (resets on reload).
final notificationsSeenProvider =
    NotifierProvider<NotificationsSeenNotifier, DateTime>(
  NotificationsSeenNotifier.new,
);

class NotificationsSeenNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void markSeen() => state = DateTime.now();
}

// --- Feature repositories ----------------------------------------------------
final productRepositoryProvider = Provider<ProductRepository?>((ref) {
  final sync = ref.watch(syncServiceProvider);
  return sync == null
      ? null
      : FirestoreProductRepository(sync, ref.watch(activityLogProvider));
});

final saleRepositoryProvider = Provider<SaleRepository?>((ref) {
  final sync = ref.watch(syncServiceProvider);
  return sync == null
      ? null
      : FirestoreSaleRepository(sync, ref.watch(activityLogProvider));
});

final financeRepositoryProvider = Provider<FinanceRepository?>((ref) {
  final sync = ref.watch(syncServiceProvider);
  return sync == null
      ? null
      : FirestoreFinanceRepository(sync, ref.watch(activityLogProvider));
});

final managementRepositoryProvider = Provider<ManagementRepository?>((ref) {
  final sync = ref.watch(syncServiceProvider);
  return sync == null
      ? null
      : FirestoreManagementRepository(sync, ref.watch(activityLogProvider));
});

final rolesRepositoryProvider = Provider<RolesRepository?>((ref) {
  final sync = ref.watch(syncServiceProvider);
  return sync == null
      ? null
      : FirestoreRolesRepository(sync, ref.watch(activityLogProvider));
});

/// Live list of roles; empty while signed out.
final rolesProvider = StreamProvider<List<Role>>((ref) {
  final repo = ref.watch(rolesRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchRoles();
});
