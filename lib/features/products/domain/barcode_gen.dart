import 'dart:math';

/// Generates a short, human-readable, scanner-friendly product code.
///
/// Format: ddMMyy + 2 letters + 2 digits, e.g. `070601ET67`. Uppercase and
/// digits only, so it encodes cleanly as a Code128 barcode.
String generateBarcode([DateTime? now]) {
  final d = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final date = '${two(d.day)}${two(d.month)}${two(d.year % 100)}';

  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; // no I/O to avoid confusion
  final r = Random();
  final l = '${letters[r.nextInt(letters.length)]}'
      '${letters[r.nextInt(letters.length)]}';
  final n = (10 + r.nextInt(90)).toString();
  return '$date$l$n';
}
