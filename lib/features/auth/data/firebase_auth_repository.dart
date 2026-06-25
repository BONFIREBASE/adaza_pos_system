import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

/// Production [AuthRepository] backed by Firebase Authentication (Req 1).
///
/// Identity comes from Firebase Auth; role, profile, and status come from the
/// Firestore `users/{uid}` document (Req 1.5). Profile changes propagate live
/// because the auth stream also listens to that document.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required fb.FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _db = firestore;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AppUser? _cached;

  /// Maps a Firebase user + their users-doc data into an [AppUser], or null if
  /// the account has no role assigned or has been disabled.
  AppUser? _fromData(fb.User user, Map<String, dynamic>? data) {
    if (data == null || data['role'] == null || data['active'] == false) {
      return null;
    }
    return AppUser(
      id: user.uid,
      email: user.email ?? (data['email'] as String? ?? ''),
      role: UserRole.fromName(data['role'] as String?),
      name: data['name'] as String? ?? '',
      photo: data['photo'] as String?,
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
            (snap) {
              final mapped = _fromData(user, snap.data());
              _cached = mapped;
              controller.add(mapped);
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
    final mapped = _fromData(user, snap.data());
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
    if (photo != null) data['photo'] = photo; // '' clears the photo
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
}
