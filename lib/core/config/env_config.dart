import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads and exposes environment configuration from the `.env` asset.
/// Used by demo mode and to pre-fill the sign-in email.
abstract final class EnvConfig {
  static Future<void> load() => dotenv.load(fileName: '.env');

  static String get adminEmail =>
      dotenv.maybeGet('ADMIN_EMAIL') ?? 'admin@adaza.local';

  /// Password accepted by demo mode (local auth only).
  static String get ownerPassword =>
      dotenv.maybeGet('OWNER_PASSWORD') ??
      dotenv.maybeGet('ADMIN_PASSWORD') ??
      'admin123';
}
