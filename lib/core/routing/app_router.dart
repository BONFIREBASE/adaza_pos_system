import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/landing_screen.dart';
import '../../features/auth/presentation/set_password_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/finance/presentation/finance_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/labels/labels_screen.dart';
import '../../features/management/presentation/management_screen.dart';
import '../providers.dart';

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<AppUser?> stream) {
    _sub = stream.listen((user) {
      _user = user;
      _ready = true;
      notifyListeners();
    });
  }

  late final StreamSubscription<AppUser?> _sub;
  AppUser? _user;
  bool _ready = false;

  bool get signedIn => _user != null;
  bool get ready => _ready;
  AppUser? get user => _user;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Maps a route to the permission required to view it.
const _routePermissions = <String, AppPermission>{
  '/products': AppPermission.manageProducts,
  '/labels': AppPermission.manageProducts,
  '/sales': AppPermission.recordSales,
  '/finance': AppPermission.manageFinance,
  '/management': AppPermission.manageUsers,
  '/dashboard': AppPermission.viewDashboard,
};

/// Centralized route table. Redirects guard authenticated areas (Req 1.3) and
/// enforce role permissions per route (Req 1.5).
final routerProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final refresh = _AuthRefresh(authRepository.authStateChanges());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final onSignIn = state.matchedLocation == '/sign-in';
      if (!refresh.signedIn) return onSignIn ? null : '/sign-in';
      if (onSignIn) return '/dashboard';

      // Force first-login password change for new staff.
      final mustChange = refresh.user?.mustChangePassword ?? false;
      final onSetPw = state.matchedLocation == '/set-password';
      if (mustChange) return onSetPw ? null : '/set-password';
      if (onSetPw) return '/dashboard';

      // Enforce per-route permissions: send users without access back to the
      // dashboard rather than letting a direct URL bypass the dock filtering.
      final loc = state.matchedLocation;
      final required = _routePermissions[loc];
      final user = refresh.user;
      if (required != null && user != null && !user.can(required)) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (_, __) => const LandingScreen(),
      ),
      GoRoute(
        path: '/set-password',
        builder: (_, __) => const SetPasswordScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/products',
        builder: (_, __) => const ProductsScreen(),
      ),
      GoRoute(
        path: '/labels',
        builder: (_, __) => const LabelsScreen(),
      ),
      GoRoute(
        path: '/sales',
        builder: (_, __) => const SalesScreen(),
      ),
      GoRoute(
        path: '/finance',
        builder: (_, __) => const FinanceScreen(),
      ),
      GoRoute(
        path: '/management',
        builder: (_, __) => const ManagementScreen(),
      ),
    ],
  );
});
