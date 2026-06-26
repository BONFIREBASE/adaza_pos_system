import '../../auth/domain/app_user.dart';

/// How often a salary is paid.
enum SalaryPeriod {
  monthly,
  weekly,
  daily;

  String get label => switch (this) {
        SalaryPeriod.monthly => 'Monthly',
        SalaryPeriod.weekly => 'Weekly',
        SalaryPeriod.daily => 'Daily',
      };

  static SalaryPeriod fromName(String? n) =>
      SalaryPeriod.values.firstWhere((p) => p.name == n,
          orElse: () => SalaryPeriod.monthly);
}

/// A POS user account with employment details (stored in `users/{uid}`).
class StaffMember {
  const StaffMember({
    required this.uid,
    required this.email,
    required this.roleId,
    this.name = '',
    this.position = '',
    this.salary = 0,
    this.salaryPeriod = SalaryPeriod.monthly,
    this.active = true,
    this.photo,
  });

  final String uid;
  final String email;
  final String roleId;
  final String name;
  final String position;
  final double salary;
  final SalaryPeriod salaryPeriod;
  final bool active;
  final String? photo;

  bool get isOwner => roleId == kOwnerRoleId;

  String get displayName => name.trim().isEmpty ? email : name;

  /// Normalised to a monthly figure for payroll totals.
  double get monthlySalary => switch (salaryPeriod) {
        SalaryPeriod.monthly => salary,
        SalaryPeriod.weekly => salary * 52 / 12,
        SalaryPeriod.daily => salary * 26, // ~26 working days/month
      };

  Map<String, dynamic> toMap() => {
        'email': email,
        'role': roleId,
        'name': name,
        'position': position,
        'salary': salary,
        'salaryPeriod': salaryPeriod.name,
        'active': active,
        'photo': photo,
      };

  factory StaffMember.fromMap(Map<String, dynamic> map) => StaffMember(
        uid: map['id'] as String,
        email: map['email'] as String? ?? '',
        roleId: map['role'] as String? ?? 'cashier',
        name: map['name'] as String? ?? '',
        position: map['position'] as String? ?? '',
        salary: (map['salary'] as num?)?.toDouble() ?? 0,
        salaryPeriod: SalaryPeriod.fromName(map['salaryPeriod'] as String?),
        active: map['active'] as bool? ?? true,
        photo: map['photo'] as String?,
      );
}
