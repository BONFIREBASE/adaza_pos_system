import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../finance/domain/finance_record.dart';
import '../products/domain/product.dart';
import '../sales/domain/sale.dart';

/// Builds branded ADAZA PDF reports for printing or download.
abstract final class ReportService {
  static final _money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
  static final _date = DateFormat('MMM d, yyyy');
  static final _dateTime = DateFormat('MMM d, yyyy h:mm a');

  static const _teal = PdfColor.fromInt(0xFF1F6E6A);
  static const _bronze = PdfColor.fromInt(0xFF8C5A2B);
  static const _cream = PdfColor.fromInt(0xFFF7F1E3);

  static Future<pw.ThemeData> _theme() async {
    return pw.ThemeData.withFont(
      base: await PdfGoogleFonts.notoSansRegular(),
      bold: await PdfGoogleFonts.notoSansBold(),
    );
  }

  static pw.Widget _header(String title, {String? subtitle}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ADAZA',
                    style: const pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: _teal,
                        letterSpacing: 3)),
                pw.Text('School & Office Supplies Trading and Apparel',
                    style: const pw.TextStyle(fontSize: 9, color: _bronze)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title,
                    style: const pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('Generated ${_dateTime.format(DateTime.now())}',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700)),
                if (subtitle != null)
                  pw.Text(subtitle,
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: _teal, thickness: 1.2),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    List<int>? rightAlign,
  }) {
    final right = rightAlign ?? const [];
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: null,
      headerStyle: const pw.TextStyle(
          fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: _teal),
      cellStyle: const pw.TextStyle(fontSize: 9),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _cream, width: 1)),
      ),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      cellAlignments: {
        for (var i = 0; i < headers.length; i++)
          i: right.contains(i)
              ? pw.Alignment.centerRight
              : pw.Alignment.centerLeft,
      },
    );
  }

  static pw.Document _doc(pw.ThemeData theme, String title, pw.Widget body,
      {String? subtitle}) {
    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => _header(title, subtitle: subtitle),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (_) => [body],
      ),
    );
    return doc;
  }

  // --- Products ---------------------------------------------------------------
  static Future<Uint8List> products(List<Product> items) async {
    final theme = await _theme();
    final invValue =
        items.fold<double>(0, (s, p) => s + p.price * p.stockQuantity);
    final body = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _table(
          headers: ['Name', 'Barcode', 'Price', 'Cost', 'Stock'],
          rightAlign: const [2, 3, 4],
          rows: items
              .map((p) => [
                    p.name,
                    p.barcode,
                    _money.format(p.price),
                    _money.format(p.cost),
                    '${p.stockQuantity}',
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 10),
        _summary([
          ('Total products', '${items.length}'),
          ('Inventory value (by price)', _money.format(invValue)),
        ]),
      ],
    );
    return _doc(theme, 'Product Catalog', body,
            subtitle: '${items.length} items')
        .save();
  }

  // --- Sales ------------------------------------------------------------------
  static Future<Uint8List> sales(List<Sale> sales) async {
    final theme = await _theme();
    final total = sales.fold<double>(0, (s, x) => s + x.total);
    final body = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _table(
          headers: ['Date', 'Items', 'Total'],
          rightAlign: const [1, 2],
          rows: sales
              .map((s) => [
                    _dateTime.format(s.createdAt),
                    '${s.lines.length}',
                    _money.format(s.total),
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 10),
        _summary([
          ('Transactions', '${sales.length}'),
          ('Gross sales', _money.format(total)),
        ]),
      ],
    );
    return _doc(theme, 'Sales Report', body,
            subtitle: '${sales.length} transactions')
        .save();
  }

  // --- Finance ----------------------------------------------------------------
  static Future<Uint8List> finance(List<FinanceRecord> records) async {
    final theme = await _theme();
    double income = 0, expense = 0;
    for (final r in records) {
      if (r.type == FinanceType.income) {
        income += r.amount;
      } else {
        expense += r.amount;
      }
    }
    final body = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _table(
          headers: ['Date', 'Type', 'Category', 'Amount'],
          rightAlign: const [3],
          rows: records
              .map((r) => [
                    _date.format(r.date),
                    r.type.name,
                    r.category,
                    _money.format(r.amount),
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 10),
        _summary([
          ('Total income', _money.format(income)),
          ('Total expenses', _money.format(expense)),
          ('Net profit', _money.format(income - expense)),
        ]),
      ],
    );
    return _doc(theme, 'Income & Expense Report', body).save();
  }

  static pw.Widget _summary(List<(String, String)> rows) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 240,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _cream,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          children: [
            for (final (label, value) in rows)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(value,
                        style: const pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
