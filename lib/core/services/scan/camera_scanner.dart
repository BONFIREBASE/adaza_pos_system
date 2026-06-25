import 'scan_source.dart';

/// Camera-based [ScanSource] implementation (Req 3.2).
///
/// The actual frame decoding is driven by the `mobile_scanner` widget in the
/// presentation layer; this class adapts a decoded value into a [ScanResult]
/// and reports availability so callers stay decoupled from the camera package.
class CameraScanner implements ScanSource {
  CameraScanner({Future<bool> Function()? availabilityCheck})
      : _availabilityCheck = availabilityCheck;

  final Future<bool> Function()? _availabilityCheck;

  @override
  String get id => 'camera';

  @override
  Future<bool> isAvailable() async {
    if (_availabilityCheck != null) return _availabilityCheck();
    return true;
  }

  /// Adapts a value decoded by the scanner widget into a [ScanResult].
  ScanResult fromDecodedValue(String value) =>
      ScanResult(barcode: value, source: id);

  @override
  Future<ScanResult> scanOnce() {
    // Continuous camera scanning is surfaced through a widget stream rather
    // than a one-shot future; this throws so misuse is caught early.
    throw const ScanUnavailableException(
      'Use the scanner widget stream; scanOnce is not supported for camera.',
    );
  }
}
