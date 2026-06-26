import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds an A4 sheet of barcode labels (2 columns) for a product code,
/// matching a standard label-sheet layout.
abstract final class LabelService {
  static const _teal = PdfColor.fromInt(0xFF1F6E6A);

  static Future<Uint8List> sheet({
    required String code,
    String? name,
    int quantity = 12,
  }) async {
    final doc = pw.Document();

    pw.Widget label() => pw.Container(
          height: 64,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.code128(),
              data: code,
              drawText: true,
              textStyle: const pw.TextStyle(fontSize: 9, letterSpacing: 1),
              height: 38,
            ),
          ),
        );

    final rows = <pw.Widget>[];
    for (var i = 0; i < quantity; i += 2) {
      rows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: label()),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: (i + 1) < quantity ? label() : pw.SizedBox(),
              ),
            ],
          ),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                name == null || name.isEmpty ? 'Barcode labels' : name,
                style: const pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _teal),
              ),
              pw.Text('$quantity labels · $code',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
        ),
        build: (_) => rows,
      ),
    );

    return doc.save();
  }

  /// Builds a page (in the chosen [format]) with barcodes placed at free
  /// positions (designer mode). Positions/size are fractions of the page.
  static Future<Uint8List> designed({
    required List<LabelPlacement> items,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document();
    final pageW = format.width;
    final pageH = format.height;

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (_) {
          return pw.Stack(
            children: [
              for (final it in items)
                pw.Positioned(
                  left: it.xFrac * pageW,
                  top: it.yFrac * pageH,
                  child: pw.Container(
                    width: it.wFrac * pageW,
                    padding:
                        const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: pw.BoxDecoration(
                      border:
                          pw.Border.all(color: PdfColors.grey400, width: 0.8),
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: it.code,
                      drawText: true,
                      textStyle: const pw.TextStyle(fontSize: 8, letterSpacing: 1),
                      height: it.wFrac * pageW * 0.34,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }
}

/// A barcode placed on the designer canvas (fractional coordinates).
class LabelPlacement {
  const LabelPlacement({
    required this.code,
    required this.xFrac,
    required this.yFrac,
    required this.wFrac,
  });
  final String code;
  final double xFrac;
  final double yFrac;
  final double wFrac;
}

/// Selectable paper sizes for the label sheet.
enum PaperSize {
  a4('A4', 210, 297),
  letter('Letter (Short)', 215.9, 279.4),
  long('Long / Folio', 215.9, 330.2),
  legal('Legal', 215.9, 355.6),
  a5('A5', 148, 210);

  const PaperSize(this.label, this.widthMm, this.heightMm);
  final String label;
  final double widthMm;
  final double heightMm;

  /// width / height — used for the on-screen canvas aspect.
  double get ratio => widthMm / heightMm;

  PdfPageFormat get format => PdfPageFormat(
        widthMm * PdfPageFormat.mm,
        heightMm * PdfPageFormat.mm,
      );
}
