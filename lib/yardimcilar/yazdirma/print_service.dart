import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import '../ceviri/ceviri_servisi.dart';

class PrintService {
  static Future<Uint8List> generatePdf({
    required PdfPageFormat format,
    required String title,
    required List<String> headers,
    required List<List<String>> data,
    pw.EdgeInsets? margin,
  }) async {
    final doc = pw.Document();

    // Load Fonts
    // Using OpenSans for Latin/Turkish and NotoSansArabic for Arabic
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final fontArabic = await PdfGoogleFonts.notoSansArabicRegular();

    // Theme with Font Fallback
    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
      fontFallback: [fontArabic, fontRegular],
    );

    // Date
    final dateStr = intl.DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: format,
          theme: theme,
          margin: margin ?? const pw.EdgeInsets.all(40),
        ),
        header: (context) => _buildHeader(context, title, dateStr),
        footer: (context) => _buildFooter(context),
        build: (context) => [_buildTable(headers, data, context)],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader(pw.Context context, String title, String date) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              tr('app.brand_upper'), // Placeholder Logo/Name
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.Text(
              date,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Text(
        '${intl.DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())} - ${tr('common.page')} ${context.pageNumber}/${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
    );
  }

  static pw.Widget _buildTable(
    List<String> headers,
    List<List<String>> data,
    pw.Context context,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      cellStyle: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
      cellAlignments: {
        for (var i = 0; i < headers.length; i++) i: pw.Alignment.centerLeft,
      },
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
    );
  }
}
