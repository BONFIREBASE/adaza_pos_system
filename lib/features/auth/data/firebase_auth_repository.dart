import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

/// Production [AuthRepository] backed by Firebase Authentication (Req 1).
///
/// Identity comes from Firebase Auth; the user's role id comes from
/// `users/{uid}`, and the role's permissions come from `roles/{roleId}` — so
/// roles are fully data-driven. The Owner role always has full access.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required fb.FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _db = firestore;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AppUser? _cached;

  /// Builds an [AppUser] from the live `users/{uid}` doc data and the live
  /// `roles/{roleId}` doc data. Returns null when access should be denied
  /// (no role, disabled, or an invalid/unknown role).
  AppUser? _resolveSync(
    fb.User user,
    Map<String, dynamic>? data,
    Map<String, dynamic>? roleData,
  ) {
    if (data == null || data['role'] == null || data['active'] == false) {
      return null;
    }
    final roleId = data['role'] as String;

    Set<AppPermission> permissions;
    String roleName;
    if (roleId == kOwnerRoleId) {
      permissions = AppPermission.values.toSet();
      roleName = 'Owner';
    } else {
      if (roleData == null) return null; // missing / invalid role
      permissions = ((roleData['permissions'] as List<dynamic>?) ?? [])
          .map((e) => AppPermission.fromName(e as String?))
          .whereType<AppPermission>()
          .toSet();
      roleName = roleData['name'] as String? ?? roleId;
    }

    return AppUser(
      id: user.uid,
      email: user.email ?? (data['email'] as String? ?? ''),
      roleId: roleId,
      roleName: roleName,
      permissions: permissions,
      name: data['name'] as String? ?? '',
      photo: data['photo'] as String?,
      mustChangePassword: data['mustChangePassword'] as bool? ?? false,
    );
  }

  @override
  Stream<AppUser?> authStateChanges() {
    late StreamController<AppUser?> controller;
    StreamSubscription<fb.User?>? authSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? roleSub;

    fb.User? fbUser;
    Map<String, dynamic>? userData;
    Map<String, dynamic>? roleData;
    String? watchedRoleId;
    bool roleLoaded = false;

    void emit() {
      final user = fbUser;
      if (user == null) {
        _cached = null;
        if (!controller.isClosed) controller.add(null);
        return;
      }
      final data = userData;
      // Wait until the user doc has loaded before emitting anything.
      if (data == null) return;
      final roleId = data['role'] as String?;
      final active = data['active'] != false;
      // For an active, non-owner account, hold off emitting until the role doc
      // has loaded at least once — avoids a transient "signed out" flash that
      // would bounce the user to the sign-in screen.
      if (active &&
          roleId != null &&
          roleId != kOwnerRoleId &&
          !roleLoaded) {
        return;
      }
      final mapped = _resolveSync(user, data, roleData);
      _cached = mapped;
      if (!controller.isClosed) controller.add(mapped);
    }

    // (Re)subscribe to the role document so permission edits apply live.
    void watchRole(String? roleId) {
      if (roleId == watchedRoleId) return;
      watchedRoleId = roleId;
      roleSub?.cancel();
      roleSub = null;
      roleData = null;
      roleLoaded = false;
      if (roleId == null || roleId == kOwnerRoleId) {
        roleLoaded = true; // owner needs no role doc
        return;
      }
      roleSub = _db.collection('roles').doc(roleId).snapshots().listen(
        (snap) {
          roleData = snap.data();
          roleLoaded = true;
          emit();
        },
        onError: (_) {
          roleLoaded = true;
          emit();
        },
      );
    }

    controller = StreamController<AppUser?>(
      onListen: () {
        authSub = _auth.authStateChanges().listen((user) {
          fbUser = user;
          userSub?.cancel();
          userSub = null;
          roleSub?.cancel();
          roleSub = null;
          watchedRoleId = null;
          userData = null;
          roleData = null;
          roleLoaded = false;
          if (user == null) {
            emit();
            return;
          }
          userSub = _db.collection('users').doc(user.uid).snapshots().listen(
            (snap) {
              userData = snap.data();
              watchRole(userData?['role'] as String?);
              emit();
            },
            onError: (_) {
              if (!controller.isClosed) controller.add(null);
            },
          );
        });
      },
      onCancel: () async {
        await roleSub?.cancel();
        await userSub?.cancel();
        await authSub?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  AppUser? get currentUser => _cached;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final fb.UserCredential cred;
    try {
      cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on fb.FirebaseAuthException {
      throw const AuthException('Invalid email or password.');
    }

    final user = cred.user;
    if (user == null) {
      throw const AuthException('Sign-in failed. Please try again.');
    }

    final snap = await _db.collection('users').doc(user.uid).get();
    final data = snap.data();
    Map<String, dynamic>? roleData;
    final roleId = data?['role'] as String?;
    if (roleId != null && roleId != kOwnerRoleId) {
      final roleDoc = await _db.collection('roles').doc(roleId).get();
      roleData = roleDoc.data();
    }
    final mapped = _resolveSync(user, data, roleData);
    if (mapped == null) {
      await _auth.signOut();
      throw const AuthException(
        'This account has no access, or has been disabled. Contact the owner.',
      );
    }
    _cached = mapped;
    return mapped;
  }

  @override
  Future<void> signOut() async {
    _cached = null;
    await _auth.signOut();
  }

  @override
  Future<void> updateProfile({String? name, String? photo}) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('Not signed in.');
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (photo != null) data['photo'] = photo;
    if (data.isEmpty) return;
    try {
      await _db.collection('users').doc(user.uid).set(
            data,
            SetOptions(merge: true),
          );
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Could not update profile.');
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const AuthException('Not signed in.');
    }
    try {
      final cred = fb.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(switch (e.code) {
        'wrong-password' ||
        'invalid-credential' =>
          'Current password is incorrect.',
        'weak-password' => 'New password is too weak (min 6 characters).',
        _ => e.message ?? 'Could not change password.',
      });
    }
  }

  @override
  Future<void> markPasswordChanged() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).set(
        {'mustChangePassword': false},
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Could not update account.');
    }
  }
}
