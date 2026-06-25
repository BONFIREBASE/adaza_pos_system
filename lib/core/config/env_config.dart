import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../features/auth/domain/app_user.dart';

/// Loads and exposes environment configuration from the `.env` asset.
///
/// Secrets such as the default role passwords live here so they are never
/// hard-coded in source. Call [EnvConfig.load] once during app start-up.
abstract final class EnvConfig {
  static Future<void> load() => dotenv.load(fileName: '.env');

  static String get adminEmail =>
      dotenv.maybeGet('ADMIN_EMAIL') ?? 'admin@adaza.local';

  /// Fallback password used when a role-specific password is not configured.
  static String get _defaultPassword =>
      dotenv.maybeGet('ADMIN_PASSWORD') ?? 'admin123';

  /// The password required for a given [role]. Each role can have its own
  /// password (e.g. OWNER_PASSWORD); otherwise it falls back to the default.
  static String passwordFor(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return dotenv.maybeGet('OWNER_PASSWORD') ?? _defaultPassword;
      case UserRole.admin:
        return dotenv.maybeGet('ADMIN_PASSWORD') ?? _defaultPassword;
      case UserRole.cashier:
        return dotenv.maybeGet('CASHIER_PASSWORD') ?? _defaultPassword;
    }
  }
}
