/// Result of a scan attempt from any [ScanSource].
class ScanResult {
  const ScanResult({required this.barcode, required this.source});

  final String barcode;
  final String source;
}

/// Raised when a scan source cannot operate (e.g. camera permission denied).
/// Callers should fall back to manual barcode entry (Req 3.6).
class ScanUnavailableException implements Exception {
  const ScanUnavailableException(this.message);
  final String message;

  @override
  String toString() => 'ScanUnavailableException: $message';
}

/// Abstraction over barcode input (Req 3.5).
///
/// The POS accesses all scanning through this interface so that additional
/// implementations (hardware scanner, IoT device) can be added later without
/// changing any calling feature.
abstract interface class ScanSource {
  /// Human-readable identifier, e.g. "camera".
  String get id;

  /// Whether this source is currently usable on the running platform.
  Future<bool> isAvailable();

  /// Requests a single decoded barcode value.
  ///
  /// Throws [ScanUnavailableException] when the source cannot operate.
  Future<ScanResult> scanOnce();
}
