import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../core/config.dart';
import '../core/utils.dart';

/// Module 8 – Reports dataset + PDF / Excel export.
class ReportData {
  final String title;
  final String subtitle;
  final List<String> columns;
  final List<List<String>> rows;
  final List<List<String>> footer;

  ReportData({
    required this.title,
    required this.columns,
    this.rows = const [],
    this.subtitle = '',
    this.footer = const [],
  });
}

class ReportsExporter {
  ReportsExporter._();

  /// Preview + print / save as PDF (system dialog, free, offline).
  static Future<void> exportPdf(ReportData r) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(AppConfig.orgName,
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF1565C0))),
              pw.Text(Fmt.dateTime(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
        build: (ctx) => [
          pw.Text(r.title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          if (r.subtitle.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
              child: pw.Text(r.subtitle, style: const pw.TextStyle(fontSize: 11)),
            ),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 10),
            headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF1565C0)),
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            cellAlignments: {
              for (var i = 0; i < r.columns.length; i++)
                i: i == 0 ? pw.Alignment.centerLeft : pw.Alignment.centerRight
            },
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            headers: r.columns,
            data: [...r.rows, ...r.footer],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(
        onLayout: (format) => doc.save(), name: '${r.title}.pdf');
  }

  /// Build .xlsx in temp storage and hand it to the Android share sheet.
  static Future<void> exportExcel(ReportData r) async {
    final excel = Excel.createExcel();
    final sheetName = r.title.length > 28 ? r.title.substring(0, 28) : r.title;
    final sheet = excel[sheetName];
    sheet.appendRow(r.columns.map((c) => TextCellValue(c)).toList());
    for (final row in r.rows) {
      sheet.appendRow(row.map((c) {
        final n = num.tryParse(c.replaceAll(RegExp(r'[^\d.\-]'), ''));
        if (n != null && RegExp(r'^[\d,.\-]+$').hasMatch(c.trim())) {
          return DoubleCellValue(n.toDouble());
        }
        return TextCellValue(c) as CellValue;
      }).toList());
    }
    for (final row in r.footer) {
      sheet.appendRow(row.map((c) => TextCellValue(c)).toList());
    }
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/${r.title.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}.xlsx');
    final bytes = excel.save(fileName: file.path);
    if (bytes != null && !file.existsSync()) {
      await file.writeAsBytes(bytes);
    }
    await Share.shareXFiles([XFile(file.path)],
        subject: '${AppConfig.orgName} – ${r.title}');
  }
}
