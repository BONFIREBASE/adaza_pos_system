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
import '../features/products/domain/product_repository.dart';
import '../features/sales/data/firestore_sale_repository.dart';
import '../features/sales/domain/sale_repository.dart';
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

// --- Feature repositories ----------------------------------------------------
final productRepositoryProvider = Provider<ProductRepository?>((ref) {
  final sync = ref.watch(syncServiceProvider);
  return sync == null ? null : FirestoreProductRepository(sync);
});

final saleRepositoryProvider = Provider<SaleRepository?>((ref) {
  final sync = ref.watch(syncServiceProvider);
  return sync == null ? null : FirestoreSaleRepository(sync);
});

final financeRepositoryProvider = Provider<FinanceRepository?>((ref) {
  final sync = ref.watch(syncServiceProvider);
  return sync == null ? null : FirestoreFinanceRepository(sync);
});

final managementRepositoryProvider = Provider<ManagementRepository?>((ref) {
  final sync = ref.watch(syncServiceProvider);
  return sync == null ? null : FirestoreManagementRepository(sync);
});
