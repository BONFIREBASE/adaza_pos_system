import 'staff_member.dart';

class ManagementException implements Exception {
  const ManagementException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Manages POS user accounts and their employment details (Req 1.5).
abstract interface class ManagementRepository {
  /// All staff accounts, live.
  Stream<List<StaffMember>> watchStaff();

  /// Creates a new POS account (Firebase Auth user + `users/{uid}` doc).
  /// Throws [ManagementException] on failure (e.g. email already in use).
  Future<void> createStaff({
    required String email,
    required String password,
    required String name,
    required String roleId,
    required String position,
    required double salary,
    required SalaryPeriod salaryPeriod,
    String? photo,
  });

  /// Updates an existing staff member's profile/role/salary (not credentials).
  Future<void> updateStaff(StaffMember member);

  /// Enables or disables access without deleting the account.
  Future<void> setActive(String uid, bool active);

  /// Revokes access by removing the role document.
  Future<void> removeStaff(String uid);
}
