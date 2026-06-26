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

  Future<AppUser?> _resolve(fb.User user, Map<String, dynamic>? data) async {
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
      final roleDoc = await _db.collection('roles').doc(roleId).get();
      final roleData = roleDoc.data();
      if (!roleDoc.exists || roleData == null) return null; // invalid role
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
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? docSub;

    controller = StreamController<AppUser?>(
      onListen: () {
        authSub = _auth.authStateChanges().listen((user) {
          docSub?.cancel();
          if (user == null) {
            _cached = null;
            controller.add(null);
            return;
          }
          docSub = _db.collection('users').doc(user.uid).snapshots().listen(
            (snap) async {
              final mapped = await _resolve(user, snap.data());
              _cached = mapped;
              if (!controller.isClosed) controller.add(mapped);
            },
            onError: (_) => controller.add(null),
          );
        });
      },
      onCancel: () async {
        await docSub?.cancel();
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
    final mapped = await _resolve(user, snap.data());
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
