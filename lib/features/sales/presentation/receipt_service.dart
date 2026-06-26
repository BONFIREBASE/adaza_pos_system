import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/sale.dart';

/// Builds an 80mm thermal-style sales receipt for a [Sale].
abstract final class ReceiptService {
  static final _money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
  static final _dt = DateFormat('MMM d, yyyy  h:mm a');

  static Future<Uint8List> build(Sale sale, {String? cashier}) async {
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final theme = pw.ThemeData.withFont(base: base, bold: bold);
    final doc = pw.Document(theme: theme);

    pw.Widget divider() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            children: List.generate(
              48,
              (_) => pw.Expanded(
                child: pw.Text('-',
                    style: const pw.TextStyle(fontSize: 6),
                    textAlign: pw.TextAlign.center),
              ),
            ),
          ),
        );

    pw.Widget kv(String a, String b, {bool bold = false}) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(a,
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ),
            pw.Text(b,
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(8),
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text('ADAZA',
                    style: const pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2)),
              ),
              pw.Center(
                child: pw.Text(
                  'School & Office Supplies\nTrading and Apparel',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text('SALES RECEIPT',
                    style: const pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
              divider(),
              kv('Date', _dt.format(sale.createdAt)),
              kv('Receipt', '#${sale.id}'),
              if (cashier != null && cashier.isNotEmpty) kv('Cashier', cashier),
              divider(),
              // Line items
              for (final l in sale.lines) ...[
                pw.Text(l.productName, style: const pw.TextStyle(fontSize: 8)),
                kv('  ${l.quantity} x ${_money.format(l.unitPrice)}',
                    _money.format(l.lineTotal)),
                pw.SizedBox(height: 2),
              ],
              divider(),
              kv('TOTAL', _money.format(sale.total), bold: true),
              pw.SizedBox(height: 2),
              kv('Items',
                  '${sale.lines.fold<int>(0, (s, l) => s + l.quantity)}'),
              divider(),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('Thank you for shopping at Adaza!',
                    style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text('This serves as your sales receipt.',
                    style: const pw.TextStyle(
                        fontSize: 6, color: PdfColors.grey700)),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }
}
