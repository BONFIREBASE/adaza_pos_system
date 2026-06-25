import 'dart:async';

import '../../../core/config/env_config.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

/// Demo/offline [AuthRepository]. Validates against the password in `.env`
/// (default `admin123`) and signs in as Owner. Used by `main_demo.dart`;
/// production uses [FirebaseAuthRepository].
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository();

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  @override
  Stream<AppUser?> authStateChanges() {
    scheduleMicrotask(() => _controller.add(_user));
    return _controller.stream;
  }

  @override
  AppUser? get currentUser => _user;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty ||
        password != EnvConfig.passwordFor(UserRole.owner)) {
      throw const AuthException('Invalid email or password.');
    }
    _user = AppUser(id: 'owner', email: email.trim(), role: UserRole.owner);
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> updateProfile({String? name, String? photo}) async {
    final u = _user;
    if (u == null) return;
    _user = AppUser(
      id: u.id,
      email: u.email,
      role: u.role,
      name: name ?? u.name,
      photo: photo ?? u.photo,
    );
    _controller.add(_user);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Demo mode: accept any current password matching the env default.
    if (currentPassword != EnvConfig.passwordFor(UserRole.owner)) {
      throw const AuthException('Current password is incorrect.');
    }
  }
}
