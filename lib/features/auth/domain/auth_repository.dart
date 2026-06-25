import 'app_user.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Contract for authentication and access control (Req 1).
abstract interface class AuthRepository {
  /// Emits the current user, or null while signed out (Req 1.3).
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  /// Grants access on valid credentials (Req 1.1); throws [AuthException] on
  /// invalid credentials (Req 1.2) or when the account has no assigned role.
  Future<AppUser> signIn({
    required String email,
    required String password,
  });

  /// Ends the session (Req 1.4).
  Future<void> signOut();

  /// Updates the signed-in user's display name and/or photo (base64).
  Future<void> updateProfile({String? name, String? photo});

  /// Re-authenticates with [currentPassword] and sets [newPassword].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
