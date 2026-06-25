import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/services/sync/sync_service.dart';
import '../../../firebase_options.dart';
import '../../auth/domain/app_user.dart';
import '../domain/management_repository.dart';
import '../domain/staff_member.dart';

/// [ManagementRepository] backed by Firestore (for the `users` docs) plus a
/// secondary Firebase app for creating accounts without disturbing the current
/// signed-in session.
class FirestoreManagementRepository implements ManagementRepository {
  FirestoreManagementRepository(this._sync);

  final SyncService _sync;
  static const _collection = 'users';

  @override
  Stream<List<StaffMember>> watchStaff() {
    return _sync.watchCollection(_collection).map((rows) {
      final staff = rows.map(StaffMember.fromMap).toList()
        ..sort((a, b) {
          // Owner first, then by name.
          if (a.role == UserRole.owner && b.role != UserRole.owner) return -1;
          if (b.role == UserRole.owner && a.role != UserRole.owner) return 1;
          return a.displayName
              .toLowerCase()
              .compareTo(b.displayName.toLowerCase());
        });
      return staff;
    });
  }

  @override
  Future<void> createStaff({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required String position,
    required double salary,
    required SalaryPeriod salaryPeriod,
  }) async {
    FirebaseApp? secondary;
    try {
      // Use a throwaway app so creating the account does not sign the new user
      // into the current (Owner/Admin) session.
      secondary = await Firebase.initializeApp(
        name: 'staff_creator_${DateTime.now().microsecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final auth = FirebaseAuth.instanceFor(app: secondary);
      final cred = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      await auth.signOut();

      final member = StaffMember(
        uid: uid,
        email: email.trim(),
        role: role,
        name: name.trim(),
        position: position.trim(),
        salary: salary,
        salaryPeriod: salaryPeriod,
        active: true,
      );
      await _sync.setDocument(_collection, uid, member.toMap());
    } on FirebaseAuthException catch (e) {
      throw ManagementException(switch (e.code) {
        'email-already-in-use' => 'That email already has an account.',
        'invalid-email' => 'That email address is invalid.',
        'weak-password' => 'Password is too weak (min 6 characters).',
        _ => e.message ?? 'Could not create the account.',
      });
    } catch (e) {
      throw ManagementException('Could not create the account: $e');
    } finally {
      await secondary?.delete();
    }
  }

  @override
  Future<void> updateStaff(StaffMember member) async {
    try {
      await _sync.updateDocument(_collection, member.uid, member.toMap());
    } catch (_) {
      throw const ManagementException('Could not update the account.');
    }
  }

  @override
  Future<void> setActive(String uid, bool active) async {
    try {
      await _sync.updateDocument(_collection, uid, {'active': active});
    } catch (_) {
      throw const ManagementException('Could not update the account.');
    }
  }

  @override
  Future<void> removeStaff(String uid) async {
    try {
      await _sync.deleteDocument(_collection, uid);
    } catch (_) {
      throw const ManagementException('Could not remove the account.');
    }
  }
}
