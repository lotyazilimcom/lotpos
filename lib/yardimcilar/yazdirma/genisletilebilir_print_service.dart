import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import '../../servisler/oturum_servisi.dart';
import '../ceviri/ceviri_servisi.dart';
import '../format_yardimcisi.dart';

class ExpandableRowData {
  final List<String> mainRow;
  final Map<String, String> details;
  final DetailTable? transactions;
  final List<String>? imageUrls;
  final List<pw.ImageProvider>? resolvedImages;
  final bool isExpanded;

  ExpandableRowData({
    required this.mainRow,
    this.details = const {},
    this.transactions,
    this.imageUrls,
    this.resolvedImages,
    this.isExpanded = true,
  });

  ExpandableRowData copyWith({
    List<pw.ImageProvider>? resolvedImages,
    bool? isExpanded,
  }) {
    return ExpandableRowData(
      mainRow: mainRow,
      details: details,
      transactions: transactions,
      imageUrls: imageUrls,
      resolvedImages: resolvedImages ?? this.resolvedImages,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

class DetailTable {
  final String title;
  final List<String> headers;
  final List<List<String>> data;

  DetailTable({required this.title, required this.headers, required this.data});
}

class GenisletilebilirPrintService {
  static Future<pw.ImageProvider> _resolveImage(String pathOrUrl) async {
    final source = pathOrUrl.trim();

    if (source.startsWith('http')) {
      return await networkImage(pathOrUrl);
    }

    // data URL (data:image/...;base64,XXXX) formatını destekle
    if (source.startsWith('data:image')) {
      final commaIndex = source.indexOf(',');
      if (commaIndex != -1 && commaIndex < source.length - 1) {
        final base64Part = source.substring(commaIndex + 1);
        try {
          final bytes = base64Decode(base64Part);
          if (bytes.isNotEmpty) {
            return pw.MemoryImage(bytes);
          }
        } catch (_) {
          // data URL hatalıysa diğer yöntemlere geç
        }
      }
    } else {
      // Önce base64 olarak dene (ürün resimleri çoğunlukla bu formatta tutuluyor)
      try {
        final bytes = base64Decode(source);
        if (bytes.isNotEmpty) {
          return pw.MemoryImage(bytes);
        }
      } catch (_) {
        // base64 değilse dosya yolu olarak dene
      }
    }

    final file = File(source);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      return pw.MemoryImage(bytes);
    }
    throw Exception('Image source not found: $source');
  }

  static Future<Uint8List> generatePdf({
    required PdfPageFormat format,
    required String title,
    required List<String> headers,
    required List<ExpandableRowData> data,
    bool printFeatures = true,
    bool showHeaders = true,
    bool showBackground = true,
    pw.EdgeInsets? margin,
    String? dateInterval,
    Map<String, dynamic>? headerInfo,
    Map<String, bool>? headerFieldToggles,
  }) async {
    final doc = pw.Document();

    // Load Fonts in parallel
    // Load Fonts in parallel
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();
    final fontArabic = await PdfGoogleFonts.notoSansArabicRegular();

    // Pre-load images if needed
    List<ExpandableRowData> processedData = [];
    if (printFeatures) {
      // We process sequentially to avoid overwhelming resources if many images,
      // but parallel processing for rows is okay.
      // Memory Safe Image Processing (Batch by 20)
      // 1000 resimli raporda RAM patlamasını önlemek için chunk yapısı.
      const int batchSize = 20;
      for (var i = 0; i < data.length; i += batchSize) {
        final end = (i + batchSize < data.length) ? i + batchSize : data.length;
        final batch = data.sublist(i, end);

        final processedBatch = await Future.wait(
          batch.map((item) async {
            if (item.imageUrls != null && item.imageUrls!.isNotEmpty) {
              List<pw.ImageProvider> loadedImages = [];
              for (final url in item.imageUrls!) {
                try {
                  final img = await _resolveImage(url);
                  loadedImages.add(img);
                } catch (e) {
                  // Ignore failing images individually
                }
              }

              if (loadedImages.isNotEmpty) {
                return item.copyWith(resolvedImages: loadedImages);
              }
            }
            return item;
          }),
        );
        processedData.addAll(processedBatch);
      }
    } else {
      processedData = data;
    }

    // Theme with Font Fallback
    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
      italic: fontItalic,
      fontFallback: [fontArabic, fontRegular],
    );

    // Date
    final dateStr = intl.DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: format,
          theme: theme,
          margin: margin ?? const pw.EdgeInsets.all(PdfPageFormat.mm * 10),
        ),
        header: showHeaders
            ? (context) => _buildHeader(context, title, dateStr, dateInterval)
            : null,
        footer: showHeaders ? (context) => _buildFooter(context) : null,
        build: (context) => [
          if (headerInfo != null &&
              headerInfo.isNotEmpty &&
              (headerFieldToggles == null || printFeatures))
            _buildInfoCard(headerInfo, headerFieldToggles),
          _buildTable(
            headers,
            processedData,
            context,
            printFeatures,
            showBackground,
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildInfoCard(
    Map<String, dynamic> info, [
    Map<String, bool>? toggles,
  ]) {
    final String? cardType = info['type']?.toString();
    if (cardType == 'product') {
      return _buildProductInfoCard(info, toggles);
    }

    final bool isExpanded = info['isExpanded'] ?? false;
    final List<dynamic> images = info['images'] ?? [];
    final bool showLogo = toggles?['h_logo'] ?? true;
    final bool showName = toggles?['h_name'] ?? true;
    final bool showCode = toggles?['h_code'] ?? true;
    final bool showPhone = toggles?['h_phone'] ?? true;
    final bool showEmail = toggles?['h_email'] ?? true;
    final bool showInvoice = toggles?['h_invoice'] ?? true;
    final bool showSpecial = toggles?['h_special'] ?? true;
    final bool showBalance = toggles?['h_balance'] ?? true;

    if (!isExpanded) {
      // ========= MINIMAL VIEW (CARD COLLAPSED) =========
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.black, width: 2),
          ),
        ),
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: Basic Details
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (showName)
                    pw.Text(
                      info['name']?.toString().toUpperCase() ?? '',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  if (showCode || showPhone || showInvoice) ...[
                    pw.SizedBox(height: 2),
                    pw.Row(
                      children: [
                        if (showPhone &&
                            info['phone1'] != null &&
                            info['phone1'].toString().isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(right: 8),
                            child: pw.Text(
                              info['phone1'].toString(),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                        if (showInvoice &&
                            info['taxOffice'] != null &&
                            info['taxOffice'].toString().isNotEmpty)
                          pw.Text(
                            '${info['taxOffice']} / ${info['taxNo'] ?? ''}',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                      ],
                    ),
                  ],
                  if (showInvoice &&
                      info['fatAdresi'] != null &&
                      info['fatAdresi'].toString().isNotEmpty) ...[
                    pw.SizedBox(height: 1),
                    pw.Text(
                      '${info['fatAdresi']} ${info['fatSehir'] ?? ''}',
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.grey700,
                      ),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                    ),
                  ],
                ],
              ),
            ),
            // Right: Summary Box
            if (showBalance) _buildBakiyeKutusu(info, toggles),
          ],
        ),
      );
    }

    // ========= DETAILED VIEW (CARD EXPANDED) =========
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 2),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Row 1: Images + Name/Code + Summary
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Photos
              if (showLogo && images.isNotEmpty)
                pw.Container(
                  width: 60,
                  height: 60,
                  margin: const pw.EdgeInsets.only(right: 12),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: _buildPdfImage(images.first),
                ),
              // 2. Name & Basic Info
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (showName)
                      pw.Text(
                        info['name']?.toString().toUpperCase() ?? '',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    if (showCode) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        info['code'] ?? '',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFF2C3E50),
                        ),
                      ),
                    ],
                    if (showLogo && images.length > 1) ...[
                      pw.SizedBox(height: 6),
                      // Small thumbnails
                      pw.Row(
                        children: images.skip(1).take(4).map((img) {
                          return pw.Container(
                            width: 25,
                            height: 25,
                            margin: const pw.EdgeInsets.only(right: 4),
                            decoration: pw.BoxDecoration(
                              borderRadius: pw.BorderRadius.circular(2),
                              border: pw.Border.all(color: PdfColors.grey200),
                            ),
                            child: _buildPdfImage(img),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              // 3. Summary
              if (showBalance) _buildBakiyeKutusu(info, toggles),
            ],
          ),
          pw.SizedBox(height: 12),

          // Row 2: Information Grids (resembling UI sections)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Group 1: Communication
              if (showPhone || showEmail)
                pw.Expanded(
                  child: _buildInfoSection(tr('accounts.card.communication_info'), [
                    if (showPhone) ...[
                      '${tr('accounts.table.phone')} 1: ${info['phone1'] ?? '-'}',
                      '${tr('accounts.table.phone')} 2: ${info['phone2'] ?? '-'}',
                    ],
                    if (showEmail) ...[
                      'E-Posta: ${info['email'] ?? '-'}',
                      'Web: ${info['website'] ?? '-'}',
                    ],
                  ]),
                ),
              if ((showPhone || showEmail) && (showInvoice || showSpecial))
                pw.SizedBox(width: 10),

              // Group 2: Invoice
              if (showInvoice)
                pw.Expanded(
                  child: _buildInfoSection(tr('accounts.card.invoice_tax_info'), [
                    'Unvan: ${info['fatUnvani'] ?? '-'}',
                    'Adres: ${info['fatAdresi'] ?? '-'} / ${info['fatSehir'] ?? '-'}',
                    'V.D: ${info['taxOffice'] ?? '-'} / ${info['taxNo'] ?? '-'}',
                  ]),
                ),
              if (showInvoice && showSpecial) pw.SizedBox(width: 10),

              // Group 3: Commercial / Special
              if (showSpecial)
                pw.Expanded(
                  child: _buildInfoSection(
                    tr('accounts.card.special_info_fields'),
                    [
                      'Bilgi 1: ${info['ozelBilgi1'] ?? '-'}',
                      'Bilgi 2: ${info['ozelBilgi2'] ?? '-'}',
                      'Limit: ${FormatYardimcisi.sayiFormatlaOndalikli(info['riskLimit'] ?? 0)} ${info['currency'] ?? ''}',
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildProductInfoCard(
    Map<String, dynamic> info, [
    Map<String, bool>? toggles,
  ]) {
    final bool isExpanded = info['isExpanded'] == true;

    final List<String> images = (info['images'] is List)
        ? (info['images'] as List)
              .map((e) => e.toString())
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList()
        : <String>[];

    final bool showImages = toggles?['p_images'] ?? true;
    final bool showName = toggles?['p_name'] ?? true;
    final bool showCode = toggles?['p_code'] ?? true;
    final bool showGroup = toggles?['p_group'] ?? true;
    final bool showPrices = toggles?['p_prices'] ?? true;
    final bool showStockTax = toggles?['p_stock_tax'] ?? true;
    final bool showFeatures = toggles?['p_features'] ?? true;
    final bool showStockSummary = toggles?['p_stock_summary'] ?? true;

    final String name = (info['name'] ?? '').toString();
    final String code = (info['code'] ?? '').toString();
    final String group = (info['group'] ?? '').toString();

    final String stockText = (info['stockText'] ?? '').toString();
    final bool stockPositive = info['stockPositive'] == true;

    final String buyPrice = (info['buyPrice'] ?? '').toString();
    final String sellPrice1 = (info['sellPrice1'] ?? '').toString();
    final String sellPrice2 = (info['sellPrice2'] ?? '').toString();

    final String vatRate = (info['vatRate'] ?? '').toString();
    final String unit = (info['unit'] ?? '').toString();
    final String barcode = (info['barcode'] ?? '').toString();
    final String stockQty = (info['stockQty'] ?? '').toString();

    final String featuresText = _formatProductFeatures(info['features']);

    pw.Widget buildImageBox({double size = 60}) {
      final String firstLetter = name.trim().isNotEmpty
          ? name.trim()[0].toUpperCase()
          : '?';

      return pw.Container(
        width: size,
        height: size,
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: (showImages && images.isNotEmpty)
            ? pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: _buildPdfImage(images.first),
              )
            : pw.Center(
                child: pw.Text(
                  firstLetter,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: size >= 60 ? 20 : 14,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
      );
    }

    pw.Widget buildCodeBadge(String text) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF8F9FA),
          borderRadius: pw.BorderRadius.circular(3),
          border: pw.Border.all(
            color: PdfColor.fromInt(0xFF95A5A6),
            width: 0.5,
          ),
        ),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF2C3E50),
          ),
        ),
      );
    }

    pw.Widget buildGroupBadge(String text) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          borderRadius: pw.BorderRadius.circular(3),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
      );
    }

    pw.Widget buildSectionTitle(String title) {
      return pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFF2C3E50),
        ),
      );
    }

    pw.Widget buildKeyValueSection(
      String title,
      List<MapEntry<String, String>> items,
    ) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          buildSectionTitle(title),
          pw.SizedBox(height: 2),
          ...items.map(
            (e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 1.5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 64,
                    child: pw.Text(
                      e.key,
                      style: pw.TextStyle(
                        fontSize: 6.5,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      e.value.isNotEmpty ? e.value : '-',
                      style: pw.TextStyle(
                        fontSize: 6.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    pw.Widget buildFeaturesSection(String title, String content) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          buildSectionTitle(title),
          pw.SizedBox(height: 2),
          pw.Text(
            content.isNotEmpty ? content : '-',
            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey800),
          ),
        ],
      );
    }

    pw.Widget buildStockSummary() {
      if (!showStockSummary || stockText.trim().isEmpty) return pw.SizedBox();
      return pw.Text(
        stockText,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: stockPositive
              ? PdfColor.fromInt(0xFF2C3E50)
              : PdfColor.fromInt(0xFFEA4335),
        ),
      );
    }

    pw.Widget buildThumbnails() {
      if (!showImages || images.length <= 1) return pw.SizedBox();
      final thumbs = images.skip(1).take(4).toList();
      if (thumbs.isEmpty) return pw.SizedBox();

      return pw.Wrap(
        spacing: 4,
        runSpacing: 4,
        children: thumbs
            .map(
              (img) => pw.Container(
                width: 20,
                height: 20,
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(3),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.ClipRRect(
                  horizontalRadius: 3,
                  verticalRadius: 3,
                  child: _buildPdfImage(img),
                ),
              ),
            )
            .toList(),
      );
    }

    if (!isExpanded) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.black, width: 2),
          ),
        ),
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (showImages) buildImageBox(size: 40),
            if (showImages) pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (showName)
                    pw.Text(
                      name,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                    ),
                  pw.SizedBox(height: 4),
                  pw.Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (showCode && code.trim().isNotEmpty)
                        buildCodeBadge(code),
                      if (showGroup && group.trim().isNotEmpty)
                        buildGroupBadge(group),
                    ],
                  ),
                ],
              ),
            ),
            buildStockSummary(),
          ],
        ),
      );
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 2),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Top row: image + basic info + stock summary
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (showImages) buildImageBox(size: 60),
              if (showImages) pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (showName)
                      pw.Text(
                        name,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: pw.TextOverflow.clip,
                      ),
                    pw.SizedBox(height: 6),
                    pw.Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (showCode && code.trim().isNotEmpty)
                          buildCodeBadge(code),
                        if (showGroup && group.trim().isNotEmpty)
                          buildGroupBadge(group),
                      ],
                    ),
                    if (showImages && images.length > 1) pw.SizedBox(height: 8),
                    if (showImages && images.length > 1) buildThumbnails(),
                  ],
                ),
              ),
              if (showStockSummary && stockText.trim().isNotEmpty)
                pw.Container(
                  alignment: pw.Alignment.topRight,
                  child: buildStockSummary(),
                ),
            ],
          ),

          pw.SizedBox(height: 12),

          // Detail sections
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (showPrices)
                pw.Expanded(
                  flex: 2,
                  child: buildKeyValueSection('Fiyat Bilgileri', [
                    MapEntry('Alış Fiyatı', buyPrice),
                    MapEntry('Satış Fiyatı 1', sellPrice1),
                    MapEntry('Satış Fiyatı 2', sellPrice2),
                  ]),
                ),
              if (showPrices && (showStockTax || showFeatures))
                pw.SizedBox(width: 10),
              if (showStockTax)
                pw.Expanded(
                  flex: 2,
                  child: buildKeyValueSection('Stok & Vergi', [
                    MapEntry('KDV Oranı', vatRate.isNotEmpty ? vatRate : '-'),
                    MapEntry('Birim', unit.isNotEmpty ? unit : '-'),
                    MapEntry('Barkod', barcode.isNotEmpty ? barcode : '-'),
                    MapEntry(
                      'Stok Miktarı',
                      stockQty.isNotEmpty ? stockQty : '-',
                    ),
                  ]),
                ),
              if (showStockTax && showFeatures) pw.SizedBox(width: 10),
              if (showFeatures)
                pw.Expanded(
                  flex: 3,
                  child: buildFeaturesSection(
                    'Özellikler / Açıklama',
                    featuresText,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatProductFeatures(dynamic raw) {
    if (raw == null) return '-';

    if (raw is List) {
      final names = raw
          .map((e) {
            if (e is Map && e['name'] != null) return e['name'].toString();
            return e.toString();
          })
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      return names.isEmpty ? '-' : names.join(', ');
    }

    final String text = raw.toString().trim();
    if (text.isEmpty) return '-';

    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        final names = decoded
            .map((e) {
              if (e is Map && e['name'] != null) return e['name'].toString();
              return e.toString();
            })
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return names.isEmpty ? '-' : names.join(', ');
      }
    } catch (_) {
      // ignore
    }

    return text;
  }

  static pw.Widget _buildBakiyeKutusu(
    Map<String, dynamic> info, [
    Map<String, bool>? toggles,
  ]) {
    final bool showPayMade = toggles?['h_bal_pay_made'] ?? true;
    final bool showDebNote = toggles?['h_bal_deb_note'] ?? true;
    final bool showPayRec = toggles?['h_bal_pay_rec'] ?? true;
    final bool showCreNote = toggles?['h_bal_cre_note'] ?? true;
    final bool showNet = toggles?['h_bal_net'] ?? true;

    if (info['odemeYapildiSum'] == null) {
      if (info['totalStock'] != null && showNet) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              info['totalStockLabel'] ?? '',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            ),
            pw.Text(
              info['totalStock'].toString(),
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        );
      }
      return pw.SizedBox();
    }

    if (!showPayMade &&
        !showDebNote &&
        !showPayRec &&
        !showCreNote &&
        !showNet) {
      return pw.SizedBox();
    }

    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (showPayMade)
            _buildSummaryRow(
              tr('accounts.card.summary.payment_made'),
              info['odemeYapildiSum'],
              info['currency'],
              PdfColors.red700,
            ),
          if (showPayMade &&
              (showDebNote || showPayRec || showCreNote || showNet))
            pw.SizedBox(height: 1),
          if (showDebNote)
            _buildSummaryRow(
              tr('accounts.card.summary.debit_note'),
              info['borcDekontuSum'],
              info['currency'],
              PdfColors.red500,
            ),
          if (showDebNote && (showPayRec || showCreNote || showNet))
            pw.SizedBox(height: 2),
          if (showPayRec)
            _buildSummaryRow(
              tr('accounts.card.summary.payment_received'),
              info['odemeAlindiSum'],
              info['currency'],
              PdfColors.green700,
            ),
          if (showPayRec && (showCreNote || showNet)) pw.SizedBox(height: 1),
          if (showCreNote)
            _buildSummaryRow(
              tr('accounts.card.summary.credit_note'),
              info['alacakDekontuSum'],
              info['currency'],
              PdfColors.green500,
            ),
          if (showNet &&
              (showPayMade || showDebNote || showPayRec || showCreNote))
            pw.Divider(height: 4, thickness: 0.5, color: PdfColors.grey400),
          if (showNet)
            _buildSummaryRow(
              '${tr('common.total')} (${(info['netBalance'] ?? 0) >= 0 ? tr('accounts.table.type_debit') : tr('accounts.table.type_credit')})',
              info['netBalance'],
              info['currency'],
              PdfColors.black,
              isBold: true,
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoSection(String title, List<String> lines) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF2C3E50),
          ),
        ),
        pw.SizedBox(height: 2),
        ...lines.map(
          (line) => pw.Text(line, style: const pw.TextStyle(fontSize: 6.5)),
        ),
      ],
    );
  }

  static pw.Widget _buildPdfImage(String base64) {
    try {
      String b64 = base64;
      if (b64.contains(',')) b64 = b64.split(',').last;
      final bytes = base64Decode(b64);
      return pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain);
    } catch (_) {
      return pw.SizedBox();
    }
  }

  static pw.Widget _buildSummaryRow(
    String label,
    dynamic value,
    String currency,
    PdfColor color, {
    bool isBold = false,
  }) {
    final double amount = double.tryParse(value?.toString() ?? '0') ?? 0.0;
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(
            fontSize: 6.5,
            color: PdfColors.grey700,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          intl.NumberFormat.decimalPattern('tr').format(amount),
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(width: 2),
        pw.Text(
          currency,
          style: pw.TextStyle(
            fontSize: 5.5,
            color: PdfColors.grey600,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildHeader(
    pw.Context context,
    String title,
    String date,
    String? dateInterval,
  ) {
    final sirket = OturumServisi().aktifSirket;
    pw.ImageProvider? logoImage;
    if (sirket?.ustBilgiLogosu != null && sirket!.ustBilgiLogosu!.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(base64Decode(sirket.ustBilgiLogosu!));
      } catch (_) {}
    }

    final ustBilgiSatirlari = sirket?.ustBilgiSatirlari ?? [];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Left: Logo & Company Name
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null)
                  pw.Container(
                    height: 30,
                    margin: const pw.EdgeInsets.only(right: 10),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (sirket?.ad != null)
                      pw.Text(
                        sirket!.ad,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ...ustBilgiSatirlari
                        .take(2)
                        .map(
                          (l) => pw.Text(
                            l,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                  ],
                ),
              ],
            ),
            // Right: Doc Title & Date
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  title.toUpperCase(),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                pw.Text(date, style: const pw.TextStyle(fontSize: 8)),
                if (dateInterval != null)
                  pw.Text(
                    dateInterval,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.black, thickness: 1),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      // Hiçbir padding/margin bırakmıyoruz, tamamen raw.
      padding: pw.EdgeInsets.zero,
      margin: pw.EdgeInsets.zero,
      child: pw.Transform.translate(
        // User'ın ısrarı üzerine metni çok agresif bir şekilde aşağı (-20 birim) itiyoruz.
        // Bu işlem metni görsel olarak kağıdın en altına, margin çizgisine yapıştırır.
        offset: const PdfPoint(0, -40),
        child: pw.Text(
          '${intl.DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())} - ${tr('common.page')} ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
    );
  }

  static pw.Widget _buildTable(
    List<String> headers,
    List<ExpandableRowData> data,
    pw.Context context,
    bool printFeatures,
    bool
    showBackground, // Parametre olarak kaldı ama kullanmayacağız (Classic style)
  ) {
    // Column Width Calculation
    Map<int, pw.TableColumnWidth> columnWidths = {};

    // Sipariş tablosu kontrolü
    bool isOrderTable = headers.length == 11;

    final upperHeaders = headers.map((h) => h.toUpperCase()).toList();
    final bool isProductsMainTable =
        upperHeaders.any(
          (h) =>
              h.contains('ÜRÜN') || h.contains('URUN') || h.contains('PRODUCT'),
        ) &&
        upperHeaders.any((h) => h.contains('STOK') || h.contains('STOCK')) &&
        upperHeaders.any((h) => h.contains('KDV') || h.contains('VAT'));
    final bool isExpenseTable =
        headers.length == 9 &&
        upperHeaders.any(
          (h) =>
              h.contains('ÖDEME') ||
              h.contains('ODEME') ||
              h.contains('PAYMENT'),
        ) &&
        upperHeaders.any(
          (h) =>
              h.contains('GİDER') ||
              h.contains('GIDER') ||
              h.contains('EXPENSE'),
        ) &&
        upperHeaders.any(
          (h) =>
              h.contains('BAŞLIK') ||
              h.contains('BASLIK') ||
              h.contains('TITLE'),
        ) &&
        upperHeaders.any((h) => h.contains('TUTAR') || h.contains('AMOUNT'));

    // Ürün Kartı Tablosu kontrolü (12 sütun)
    // 0: Sıra No, 1: İşlem, 2: İlgili Hesap, 3: Tarih, 4: Depo, 5: Miktar, 6: Birim,
    // 7: Birim Fiyat, 8: Birim Fiyat (VD), 9: Toplam Fiyat, 10: Açıklama, 11: Kullanıcı
    final bool isProductCardTable =
        headers.length == 12 &&
        (upperHeaders.any(
              (h) =>
                  h.contains('MİKTAR') ||
                  h.contains('MIKTAR') ||
                  h.contains('QUANTITY'),
            ) &&
            upperHeaders.any(
              (h) =>
                  h.contains('BİRİM') ||
                  h.contains('BIRIM') ||
                  h.contains('UNIT'),
            ) &&
            upperHeaders.any(
              (h) =>
                  h.contains('FİYAT') ||
                  h.contains('FIYAT') ||
                  h.contains('PRICE'),
            ));

    // Ürün Kartı (Sadece Listeyi Göster / Seri-IMEI listesi) tablosu kontrolü (10 sütun)
    // 0: Sıra No, 1: Barkod, 2: IMEI/Seri, 3: İşlem, 4: Tarih,
    // 5: Alış Fiyatı, 6: Satış Fiyatı, 7: KDV, 8: KDV %, 9: KDV Tutar
    final bool isProductCardSerialListTable =
        headers.length == 10 &&
        upperHeaders.any(
          (h) => h.contains('BARKOD') || h.contains('BARCODE'),
        ) &&
        upperHeaders.any((h) => h.contains('EMEI') || h.contains('IMEI')) &&
        upperHeaders.any((h) => h.contains('KDV') || h.contains('VAT')) &&
        upperHeaders.any(
          (h) =>
              h.contains('SATIŞ') || h.contains('SATIS') || h.contains('SALE'),
        );

    // Sağa hizalanacak sütun indisleri
    Set<int> rightAlignedColumns = {};
    if (isProductCardTable) {
      // Miktar (5), Birim Fiyat (7), Birim Fiyat VD (8), Toplam Fiyat (9)
      rightAlignedColumns = {5, 7, 8, 9};
    } else if (isProductCardSerialListTable) {
      // Alış (5), Satış (6), KDV Tutar (9)
      rightAlignedColumns = {5, 6, 9};
    }

    for (int index = 0; index < headers.length; index++) {
      double flexValue = 1;

      if (isProductCardSerialListTable) {
        switch (index) {
          case 0:
            flexValue = 0.6;
            break; // Sıra No (dar)
          case 1:
            flexValue = 1.4;
            break; // Barkod
          case 2:
            flexValue = 4.5;
            break; // IMEI / Seri (çok geniş - tek satır hedefi)
          case 3:
            flexValue = 1.6;
            break; // İşlem
          case 4:
            flexValue = 1.6;
            break; // Tarih
          case 5:
            flexValue = 1.4;
            break; // Alış Fiyatı
          case 6:
            flexValue = 1.4;
            break; // Satış Fiyatı
          case 7:
            flexValue = 1.0;
            break; // KDV
          case 8:
            flexValue = 0.9;
            break; // KDV %
          case 9:
            flexValue = 1.2;
            break; // KDV Tutar
        }
      } else if (isProductCardTable) {
        // 0: Sıra No, 1: İşlem, 2: İlgili Hesap, 3: Tarih, 4: Depo, 5: Miktar, 6: Birim,
        // 7: Birim Fiyat, 8: Birim Fiyat (VD), 9: Toplam Fiyat, 10: Açıklama, 11: Kullanıcı
        switch (index) {
          case 0:
            flexValue = 0.6;
            break; // Sıra No (dar)
          case 1:
            flexValue = 1.6;
            break; // İşlem
          case 2:
            flexValue = 2.0;
            break; // İlgili Hesap
          case 3:
            flexValue = 1.6;
            break; // Tarih
          case 4:
            flexValue = 1.3;
            break; // Depo
          case 5:
            flexValue = 1.0;
            break; // Miktar
          case 6:
            flexValue = 0.7;
            break; // Birim (dar)
          case 7:
            flexValue = 1.6;
            break; // Birim Fiyat
          case 8:
            flexValue = 2.0;
            break; // Birim Fiyat (VD)
          case 9:
            flexValue = 1.8;
            break; // Toplam Fiyat
          case 10:
            flexValue = 1.6;
            break; // Açıklama
          case 11:
            flexValue = 1.0;
            break; // Kullanıcı
        }
      } else if (isExpenseTable) {
        // 0: Sıra, 1: Kod, 2: Başlık, 3: Tutar, 4: Kategori, 5: Tarih, 6: Ödeme, 7: Durum, 8: Açıklama
        switch (index) {
          case 0:
            flexValue = 1;
            break;
          case 1:
            flexValue = 1.6;
            break;
          case 2:
            flexValue = 3.5; // Başlık epey geniş
            break;
          case 3:
            flexValue = 2.0; // Tutar biraz dar
            break;
          case 4:
            flexValue = 1.4;
            break;
          case 5:
            flexValue = 2.2;
            break;
          case 6:
            flexValue = 2.0; // Beklemede/Ödendi tek satır
            break;
          case 7:
            flexValue = 1.2;
            break;
          case 8:
            flexValue = 1.6; // Açıklama biraz dar
            break;
        }
      } else if (isOrderTable) {
        // 0: Sıra, 1: Tür, 2: Durum, 3: Tarih, 4: Hesap, 5: Tutar, 6: Kur, 7: Açık1, 8: Açık2, 9: Geçerlilik, 10: User
        if (index == 4) {
          flexValue = 3;
        } else if (index == 1 || index == 2) {
          flexValue = 2;
        } else if (index == 7 || index == 8) {
          flexValue = 2;
        } else if (index == 9) {
          flexValue = 2;
        } else if (index == 3 || index == 5) {
          flexValue = 2;
        }
      } else if (headers.length >= 7) {
        // Generic wide table (7+ cols)
        final h = headers[index].toUpperCase();
        final hLower = headers[index].toLowerCase();
        // İLGİLİ HESAP must be checked FIRST (flex=5)
        // Robust matching for Turkish I/İ using both upper and lowercase
        if (h.contains('İLGİLİ') ||
            h.contains('ILGILI') ||
            hLower.contains('ilgili') ||
            h.contains('RELATED') ||
            (headers.length == 7 && index == 5)) {
          flexValue = 2; // Wide column for related account
        } else if (h.contains('AÇIKLAMA') ||
            h.contains('ACIKLAMA') ||
            hLower.contains('açıklama') ||
            h.contains('DESCRIPTION')) {
          flexValue = 2; // Narrow column for description
        } else if (h.contains('TUTAR') || h.contains('AMOUNT')) {
          flexValue = 3; // Standard width for amounts
        } else if (h.contains('ALACAK') ||
            h.contains('BORÇ') ||
            h.contains('BORC') ||
            h.contains('BAKİYE') ||
            h.contains('BAKIYE')) {
          flexValue = 3; // Standard width for amounts
        } else if (h.contains('DATE') ||
            h.contains('TARİH') ||
            h.contains('TARIH') ||
            h.contains('VAD')) {
          flexValue = 2; // Reduced width for dates
        } else if (h.contains('KULLANICI ADI') ||
            hLower.contains('kullanıcı adı') ||
            hLower.contains('kullanici adi') ||
            h.contains('USERNAME')) {
          flexValue = 2; // Wider column for username
        } else if (h.contains('SOYAD') ||
            hLower.contains('adı soyadı') ||
            hLower.contains('ad soyad') ||
            h.contains('SURNAME') ||
            h.contains('FULL NAME')) {
          flexValue = 3; // Wider column for name/surname
        } else if (h.contains('CARİ HESAP') ||
            h.contains('CARI HESAP') ||
            hLower.contains('cari hesap')) {
          flexValue = 4; // Wide column for account name
        } else if (h.contains('İŞLEM') ||
            h.contains('ISLEM') ||
            h.contains('PROCESS')) {
          flexValue = 2;
        }
      }
      columnWidths[index] = pw.FlexColumnWidth(flexValue);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // 1. HEADER TABLE
        pw.Table(
          border: const pw.TableBorder(
            bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
          ),
          columnWidths: columnWidths,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColors.white,
              ), // No background or white
              children: headers
                  .asMap()
                  .entries
                  .map(
                    (entry) => pw.Padding(
                      padding: const pw.EdgeInsets.only(
                        top: 4,
                        bottom: 4,
                        left: 2,
                        right: 2,
                      ),
                      child: pw.Text(
                        entry
                            .value, // Removed toUpperCase(), keeping Title Case
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          // Use standard font size, layout should handle it now
                          fontSize: 7,
                        ),
                        textAlign: rightAlignedColumns.contains(entry.key)
                            ? pw.TextAlign.right
                            : pw.TextAlign.left,
                        maxLines: 1,
                        overflow: pw.TextOverflow.clip,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),

        // 2. DATA ROWS (Each row is a separate Table to allow Detail expansion block in between)
        ...data.map((item) {
          final hasDetails =
              printFeatures &&
              item.isExpanded &&
              (item.details.isNotEmpty ||
                  (item.resolvedImages != null &&
                      item.resolvedImages!.isNotEmpty));

          return pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // Main Row Table
              pw.Table(
                // Top border is shared with previous element, so we essentially rely on Bottom border of prev element
                // BUT strict grid requires full borders.
                // To avoid double borders, we usually remove Top border except for the first one.
                // However, simplifying: just use standard borders. PDF rendering usually overlaps exactly.
                // We will shift up by border width? No.
                // Just use TableBorder.all. The tiny overlap is usually invisible or acceptable in PDF.
                border: const pw.TableBorder(
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
                  horizontalInside: pw.BorderSide(
                    color: PdfColors.black,
                    width: 0.5,
                  ),
                ),
                columnWidths: columnWidths,
                children: [
                  pw.TableRow(
                    children: item.mainRow.asMap().entries.map((e) {
                      final idx = e.key;
                      final cellData = e.value;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(
                          top: 4,
                          bottom: 4,
                          left: 2,
                          right: 2,
                        ),
                        child: pw.Text(
                          cellData,
                          style: pw.TextStyle(
                            fontSize:
                                (headers[idx].toUpperCase().contains(
                                      'İLGİLİ',
                                    ) ||
                                    headers[idx].toUpperCase().contains(
                                      'VAD.',
                                    ) ||
                                    headers[idx].toUpperCase().contains(
                                      'AÇIKLAMA',
                                    ))
                                ? 6
                                : 7,
                            fontWeight:
                                (headers[idx].toUpperCase().contains('TUTAR') ||
                                    headers[idx].toUpperCase().contains(
                                      'BAKİYE',
                                    ) ||
                                    headers[idx].toUpperCase().contains(
                                      'ALACAK',
                                    ) ||
                                    headers[idx].toUpperCase().contains(
                                      'BORÇ',
                                    ) ||
                                    rightAlignedColumns.contains(idx))
                                ? pw.FontWeight.bold
                                : pw.FontWeight.normal,
                          ),
                          textAlign: rightAlignedColumns.contains(idx)
                              ? pw.TextAlign.right
                              : pw.TextAlign.left,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // Details Block - Clean Layout (No Background, 3 Columns)
              if (hasDetails)
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // LEFT: Product Images (all images, 3 per row)
                      if (item.resolvedImages != null &&
                          item.resolvedImages!.isNotEmpty)
                        pw.Container(
                          width: 68,
                          margin: const pw.EdgeInsets.only(right: 10),
                          child: pw.Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            children: item.resolvedImages!
                                .map(
                                  (img) => pw.Container(
                                    width: 20,
                                    height: 20,
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.white,
                                      borderRadius: const pw.BorderRadius.all(
                                        pw.Radius.circular(2),
                                      ),
                                      border: pw.Border.all(
                                        color: PdfColors.grey300,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: pw.ClipRRect(
                                      horizontalRadius: 2,
                                      verticalRadius: 2,
                                      child: pw.Image(
                                        img,
                                        fit: pw.BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      // CENTER: Details in 3 columns grid
                      if (item.details.entries.any(
                        (e) =>
                            e.key != tr('products.transaction.type.input') &&
                            e.key != tr('products.transaction.type.output') &&
                            e.key != tr('checks.received') &&
                            e.key != tr('checks.given') &&
                            e.key != tr('common.total') &&
                            e.key != tr('settings.users.table.balance_debt') &&
                            e.key !=
                                tr('settings.users.table.balance_credit') &&
                            !e.key.startsWith(tr('common.difference')),
                      ))
                        pw.Expanded(
                          flex: 3,
                          child: pw.Wrap(
                            spacing: 10,
                            runSpacing: 5,
                            children: item.details.entries
                                .where(
                                  (e) =>
                                      e.key !=
                                          tr(
                                            'products.transaction.type.input',
                                          ) &&
                                      e.key !=
                                          tr(
                                            'products.transaction.type.output',
                                          ) &&
                                      e.key != tr('checks.received') &&
                                      e.key != tr('checks.given') &&
                                      e.key != tr('common.total') &&
                                      e.key !=
                                          tr(
                                            'settings.users.table.balance_debt',
                                          ) &&
                                      e.key !=
                                          tr(
                                            'settings.users.table.balance_credit',
                                          ) &&
                                      !e.key.startsWith(
                                        tr('common.difference'),
                                      ),
                                )
                                .map(
                                  (e) => pw.Container(
                                    width: 95, // 3 columns
                                    child: pw.Column(
                                      crossAxisAlignment:
                                          pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(
                                          e.key,
                                          style: pw.TextStyle(
                                            fontSize: 5,
                                            fontWeight: pw.FontWeight.bold,
                                            color: PdfColors.grey600,
                                          ),
                                        ),
                                        pw.SizedBox(height: 1),
                                        pw.Text(
                                          e.value,
                                          style: const pw.TextStyle(
                                            fontSize: 7,
                                            color: PdfColors.black,
                                          ),
                                          maxLines: 2,
                                          overflow: pw.TextOverflow.clip,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      // RIGHT: Summary blocks (Stock/Checks or User Balance)
                      if (item.details.containsKey(
                            tr('products.transaction.type.input'),
                          ) ||
                          item.details.containsKey(tr('checks.received')) ||
                          item.details.containsKey(
                            tr('products.transaction.type.output'),
                          ) ||
                          item.details.containsKey(tr('checks.given')) ||
                          item.details.containsKey(tr('common.total')))
                        pw.Container(
                          width: 85,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              // Girdi / Alınan Çek Row
                              if (item.details.containsKey(
                                    tr('products.transaction.type.input'),
                                  ) ||
                                  item.details.containsKey(
                                    tr('checks.received'),
                                  )) ...[
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      item.details.containsKey(
                                            tr('checks.received'),
                                          )
                                          ? tr('checks.received')
                                          : tr(
                                              'products.transaction.type.input',
                                            ),
                                      style: const pw.TextStyle(
                                        fontSize: 6,
                                        color: PdfColors.grey700,
                                      ),
                                    ),
                                    pw.Text(
                                      (item.details.containsKey(
                                                tr('checks.received'),
                                              )
                                              ? item.details[tr(
                                                  'checks.received',
                                                )]
                                              : item.details[tr(
                                                  'products.transaction.type.input',
                                                )]) ??
                                          '0',
                                      style: pw.TextStyle(
                                        fontSize: 7,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.green700,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.Container(
                                  margin: const pw.EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  height: 0.5,
                                  color: PdfColors.grey400,
                                ),
                              ],
                              // Çıktı / Verilen Çek Row
                              if (item.details.containsKey(
                                    tr('products.transaction.type.output'),
                                  ) ||
                                  item.details.containsKey(
                                    tr('checks.given'),
                                  )) ...[
                                pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      item.details.containsKey(
                                            tr('checks.given'),
                                          )
                                          ? tr('checks.given')
                                          : tr(
                                              'products.transaction.type.output',
                                            ),
                                      style: const pw.TextStyle(
                                        fontSize: 6,
                                        color: PdfColors.grey700,
                                      ),
                                    ),
                                    pw.Text(
                                      (item.details.containsKey(
                                                tr('checks.given'),
                                              )
                                              ? item.details[tr('checks.given')]
                                              : item.details[tr(
                                                  'products.transaction.type.output',
                                                )]) ??
                                          '0',
                                      style: pw.TextStyle(
                                        fontSize: 7,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.red700,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.Container(
                                  margin: const pw.EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  height: 0.5,
                                  color: PdfColors.grey400,
                                ),
                              ],
                              // Toplam Row - Use common.total if present, otherwise calculate
                              pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    item.details.containsKey(tr('common.total'))
                                        ? tr('common.total')
                                        : tr('warehouses.detail.total_stock'),
                                    style: pw.TextStyle(
                                      fontSize: 6,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.grey700,
                                    ),
                                  ),
                                  pw.Text(
                                    () {
                                      // If common.total is present in details, use it directly
                                      if (item.details.containsKey(
                                        tr('common.total'),
                                      )) {
                                        return item.details[tr(
                                              'common.total',
                                            )] ??
                                            '0';
                                      }

                                      // Get values with check support
                                      final girdiStr =
                                          (item.details[tr(
                                            'products.transaction.type.input',
                                          )] ??
                                          item.details[tr('checks.received')] ??
                                          '0');
                                      final ciktiStr =
                                          (item.details[tr(
                                            'products.transaction.type.output',
                                          )] ??
                                          item.details[tr('checks.given')] ??
                                          '0');

                                      final girdi =
                                          double.tryParse(
                                            girdiStr
                                                .replaceAll(
                                                  RegExp(r'[^\d,.]'),
                                                  '',
                                                )
                                                .replaceAll(',', '.'),
                                          ) ??
                                          0;
                                      final cikti =
                                          double.tryParse(
                                            ciktiStr
                                                .replaceAll(
                                                  RegExp(r'[^\d,.]'),
                                                  '',
                                                )
                                                .replaceAll(',', '.'),
                                          ) ??
                                          0;
                                      final total = girdi - cikti;
                                      return total.toStringAsFixed(0);
                                    }(),
                                    style: pw.TextStyle(
                                      fontSize: 7,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else if (item.details.containsKey(
                            tr('settings.users.table.balance_debt'),
                          ) ||
                          item.details.containsKey(
                            tr('settings.users.table.balance_credit'),
                          ) ||
                          item.details.keys.any(
                            (k) => k.startsWith(tr('common.difference')),
                          ))
                        pw.Container(
                          width: 85,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              // Bakiye Borç
                              pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    tr('settings.users.table.balance_debt'),
                                    style: const pw.TextStyle(
                                      fontSize: 6,
                                      color: PdfColors.grey700,
                                    ),
                                  ),
                                  pw.Text(
                                    item.details[tr(
                                          'settings.users.table.balance_debt',
                                        )] ??
                                        '-',
                                    style: pw.TextStyle(
                                      fontSize: 7,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.red700,
                                    ),
                                  ),
                                ],
                              ),
                              pw.Container(
                                margin: const pw.EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                height: 0.5,
                                color: PdfColors.grey400,
                              ),
                              // Bakiye Alacak
                              pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    tr('settings.users.table.balance_credit'),
                                    style: const pw.TextStyle(
                                      fontSize: 6,
                                      color: PdfColors.grey700,
                                    ),
                                  ),
                                  pw.Text(
                                    item.details[tr(
                                          'settings.users.table.balance_credit',
                                        )] ??
                                        '-',
                                    style: pw.TextStyle(
                                      fontSize: 7,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.green700,
                                    ),
                                  ),
                                ],
                              ),
                              pw.Container(
                                margin: const pw.EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                height: 0.5,
                                color: PdfColors.grey400,
                              ),
                              // Fark
                              pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    () {
                                      for (final k in item.details.keys) {
                                        if (k.startsWith(
                                          tr('common.difference'),
                                        )) {
                                          return k;
                                        }
                                      }
                                      return tr('common.difference');
                                    }(),
                                    style: pw.TextStyle(
                                      fontSize: 6,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.grey700,
                                    ),
                                  ),
                                  pw.Text(
                                    () {
                                      for (final k in item.details.keys) {
                                        if (k.startsWith(
                                          tr('common.difference'),
                                        )) {
                                          return item.details[k] ?? '-';
                                        }
                                      }
                                      return '-';
                                    }(),
                                    style: pw.TextStyle(
                                      fontSize: 7,
                                      fontWeight: pw.FontWeight.bold,
                                      color: () {
                                        for (final k in item.details.keys) {
                                          if (k.startsWith(
                                            tr('common.difference'),
                                          )) {
                                            if (k.contains(
                                              tr('accounts.table.type_credit'),
                                            )) {
                                              return PdfColors.green700;
                                            }
                                            if (k.contains(
                                              tr('accounts.table.type_debit'),
                                            )) {
                                              return PdfColors.red700;
                                            }
                                          }
                                        }
                                        return PdfColors.black;
                                      }(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

              if (hasDetails || (item.isExpanded && item.transactions != null))
                pw.SizedBox(height: 4),

              // Transaction Sub-Table (with left indent)
              if (item.isExpanded && item.transactions != null)
                pw.Container(
                  padding: const pw.EdgeInsets.only(left: 10),
                  child: pw.Table(
                    border: const pw.TableBorder(
                      bottom: pw.BorderSide(
                        color: PdfColors.black,
                        width: 0.25,
                      ),
                      horizontalInside: pw.BorderSide(
                        color: PdfColors.black,
                        width: 0.25,
                      ),
                    ),
                    columnWidths: {
                      for (
                        int i = 0;
                        i < item.transactions!.headers.length;
                        i++
                      )
                        i: ((h) {
                          // Smart Width Calculation for Sub-Table
                          if (isProductsMainTable) {
                            // Ürünler sayfası: "İşlem" dar, "Depo" dar, "Toplam Fiyat" geniş
                            if ((h.contains('TOPLAM') || h.contains('TOTAL')) &&
                                (h.contains('FIYAT') ||
                                    h.contains('FİYAT') ||
                                    h.contains('PRICE'))) {
                              return const pw.FlexColumnWidth(2);
                            } else if (h.contains('DEPO') ||
                                h.contains('WAREHOUSE')) {
                              return const pw.FlexColumnWidth(0.85);
                            } else if (h.contains('İŞLEM') ||
                                h.contains('ISLEM') ||
                                h.contains('TRANSACTION')) {
                              return const pw.FlexColumnWidth(1.4);
                            }
                          }
                          if (h.contains('AÇIKLAMA') ||
                              h.contains('DESCRIPTION')) {
                            return const pw.FlexColumnWidth(1.5); // Daraltıldı
                          } else if (h.contains('İLGİLİ HESAP') ||
                              h.contains('RELATED')) {
                            return const pw.FlexColumnWidth(4); // Daraltıldı
                          } else if (h.contains('İŞLEM') ||
                              h.contains('TRANSACTION')) {
                            return const pw.FlexColumnWidth(2);
                          } else if (h.contains('TARİH') ||
                              h.contains('DATE')) {
                            return const pw.FlexColumnWidth(6); // Ayarlandı
                          } else if (h.contains('TUTAR') ||
                              h.contains('AMOUNT') ||
                              h.contains('BORÇ') ||
                              h.contains('ALACAK') ||
                              h.contains('BAKİYE')) {
                            return const pw.FlexColumnWidth(1.5); // Daraltıldı
                          }
                          return const pw.FlexColumnWidth(1);
                        })(item.transactions!.headers[i].toUpperCase()),
                    },
                    children: [
                      // Headers
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.white,
                        ),
                        children: item.transactions!.headers
                            .map(
                              (h) => pw.Padding(
                                padding: const pw.EdgeInsets.all(2),
                                child: pw.Text(
                                  h,
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 6,
                                  ),
                                  textAlign:
                                      (h.toUpperCase().contains('BORÇ') ||
                                          h.toUpperCase().contains('ALACAK') ||
                                          h.toUpperCase().contains('BAKİYE') ||
                                          h.toUpperCase().contains('MİKTAR') ||
                                          h.toUpperCase().contains('MIKTAR') ||
                                          h.toUpperCase().contains(
                                            'QUANTITY',
                                          ) ||
                                          h.toUpperCase().contains('FİYAT') ||
                                          h.toUpperCase().contains('PRICE') ||
                                          h.toUpperCase().contains('TOPLAM') ||
                                          h.toUpperCase().contains('TOTAL'))
                                      ? pw.TextAlign.right
                                      : pw.TextAlign.left,
                                  maxLines: 2,
                                  overflow: pw.TextOverflow.clip,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      // Data
                      ...item.transactions!.data.map(
                        (row) => pw.TableRow(
                          children: row
                              .asMap()
                              .entries
                              .map(
                                (e) => pw.Padding(
                                  padding: const pw.EdgeInsets.all(2),
                                  child: pw.Text(
                                    e.value,
                                    style: const pw.TextStyle(fontSize: 6),
                                    textAlign:
                                        (item.transactions!.headers[e.key]
                                                .toUpperCase()
                                                .contains('BORÇ') ||
                                            item.transactions!.headers[e.key]
                                                .toUpperCase()
                                                .contains('ALACAK') ||
                                            item.transactions!.headers[e.key]
                                                .toUpperCase()
                                                .contains('BAKİYE') ||
                                            item.transactions!.headers[e.key]
                                                .toUpperCase()
                                                .contains('MİKTAR') ||
                                            item.transactions!.headers[e.key]
                                                .toUpperCase()
                                                .contains('MIKTAR') ||
                                            item.transactions!.headers[e.key]
                                                .toUpperCase()
                                                .contains('QUANTITY') ||
                                            item.transactions!.headers[e.key]
                                                .toUpperCase()
                                                .contains('FİYAT') ||
                                            item.transactions!.headers[e.key]
                                                .toUpperCase()
                                                .contains('PRICE') ||
                                            item.transactions!.headers[e.key]
                                                .toUpperCase()
                                                .contains('TOPLAM') ||
                                            item.transactions!.headers[e.key]
                                                .toUpperCase()
                                                .contains('TOTAL'))
                                        ? pw.TextAlign.right
                                        : pw.TextAlign.left,
                                    maxLines: 2,
                                    overflow: pw.TextOverflow.clip,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}
