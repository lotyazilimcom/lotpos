import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:patisyov10/sayfalar/ayarlar/yazdirma_ayarlari/modeller/barkod_grafik_model.dart';
import 'package:patisyov10/sayfalar/ayarlar/yazdirma_ayarlari/modeller/yazdirma_sablonu_model.dart';
import 'package:patisyov10/yardimcilar/yazdirma/yazdirma_erisim_kontrolu.dart';

class DinamikYazdirmaServisi {
  static final DinamikYazdirmaServisi _instance =
      DinamikYazdirmaServisi._internal();
  factory DinamikYazdirmaServisi() => _instance;
  DinamikYazdirmaServisi._internal();

  // Font cache to avoid re-downloading the same Google Fonts repeatedly.
  final Map<String, Future<pw.Font>> _fontCache = {};

  Future<void> yazdir({
    required YazdirmaSablonuModel sablon,
    required Map<String, dynamic> veri,
  }) async {
    if (!YazdirmaErisimKontrolu.yazdirmaKullanilabilir) return;

    final doc = await pdfOlustur(sablon: sablon, veri: veri);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${sablon.name}_Çıktı',
      format: getFormat(sablon, veri: veri),
    );
  }

  Future<pw.Document> pdfOlustur({
    required YazdirmaSablonuModel sablon,
    required Map<String, dynamic> veri,
    PdfPageFormat? formatOverride,
    PdfPageFormat? overrideFormat,
    pw.EdgeInsets? margin,
    Map<String, bool>? visibleElements,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? bgImage;
    if (sablon.backgroundImage != null) {
      bgImage = pw.MemoryImage(base64Decode(sablon.backgroundImage!));
    }

    // [2026] Layout Filtering
    final effectiveLayout = sablon.layout.where((el) {
      if (visibleElements != null && visibleElements.containsKey(el.key)) {
        return visibleElements[el.key]!;
      }
      return true;
    }).toList();

    final nonRepeatElements = effectiveLayout.where((e) => !e.repeat).toList();
    final repeatElements = effectiveLayout.where((e) => e.repeat).toList();

    // Preload fonts used in layout (sync access inside pdf build)
    final fontsByKey = await _preloadFonts(effectiveLayout);
    pw.Font resolveFont(LayoutElement el) {
      final family = _normalizeFontFamily(el.fontFamily);
      final weight = _normalizeFontWeight(el.fontWeight);
      final italic = el.italic;
      final key = _fontCacheKey(family: family, weight: weight, italic: italic);
      return fontsByKey[key] ?? fontsByKey[_fontCacheKey()]!;
    }

    final int rowCount = _resolveRepeatRowCount(repeatElements, veri);
    final double rowHeightMm = _resolveRowHeightMm(repeatElements);
    final double rowStepMm = rowHeightMm + sablon.itemRowSpacing;

    final layoutMetrics = _resolveLayoutMetrics(
      sablon: sablon,
      nonRepeatElements: nonRepeatElements,
      repeatElements: repeatElements,
      rowCount: rowCount,
      rowStepMm: rowStepMm,
    );
    final baseFormat =
        formatOverride ??
        overrideFormat ??
        getFormat(sablon, veri: veri, visibleElements: visibleElements);
    final format = sablon.usesDynamicThermalFlow
        ? PdfPageFormat(
            baseFormat.width,
            layoutMetrics.pageHeightMm * PdfPageFormat.mm,
          )
        : baseFormat;

    final double pageHeightMm = format.height / PdfPageFormat.mm;

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw
            .EdgeInsets
            .zero, // [2026 FIX] Sabit tasarım olduğu için marginler içeriği kaydırmamalı (Full Canvas)
        build: (pw.Context context) {
          final children = <pw.Widget>[];

          if (bgImage != null) {
            final bgW = (sablon.backgroundWidth != null)
                ? sablon.backgroundWidth! * PdfPageFormat.mm
                : format.width;
            final bgH = (sablon.backgroundHeight != null)
                ? sablon.backgroundHeight! * PdfPageFormat.mm
                : format.height;

            children.add(
              pw.Positioned(
                left: sablon.backgroundX * PdfPageFormat.mm,
                top: sablon.backgroundY * PdfPageFormat.mm,
                child: pw.Opacity(
                  opacity: sablon.backgroundOpacity.clamp(0.0, 1.0),
                  child: pw.Image(
                    bgImage,
                    width: bgW,
                    height: bgH,
                    fit: pw.BoxFit.fill,
                  ),
                ),
              ),
            );
          }

          for (final el in nonRepeatElements) {
            final widget = _buildElementWidget(
              el: el,
              veri: veri,
              resolveFont: resolveFont,
              valueOverride: null,
              yOffsetMm: _footerShiftForElement(
                el: el,
                footerTopMm: layoutMetrics.footerTopMm,
                footerShiftMm: layoutMetrics.footerShiftMm,
                enabled: sablon.usesDynamicThermalFlow,
              ),
            );
            if (widget != null) children.add(widget);
          }

          // Ürün satırları (repeat=true)
          if (repeatElements.isNotEmpty && rowCount > 0) {
            for (int i = 0; i < rowCount; i++) {
              final yOffset = i * rowStepMm;
              final rowBottom = repeatElements
                  .map((e) => e.y + yOffset + e.height)
                  .fold<double>(0.0, math.max);

              // Tek sayfalık: taşanı yazma
              if (rowBottom > pageHeightMm) break;

              for (final el in repeatElements) {
                final value = _valueAtIndex(veri[el.key], i);
                final widget = _buildElementWidget(
                  el: el,
                  veri: veri,
                  resolveFont: resolveFont,
                  valueOverride: value,
                  yOffsetMm: yOffset,
                );
                if (widget != null) children.add(widget);
              }
            }
          }

          return pw.Stack(children: children);
        },
      ),
    );

    return pdf;
  }

  PdfPageFormat getFormat(
    YazdirmaSablonuModel sablon, {
    Map<String, dynamic>? veri,
    Map<String, bool>? visibleElements,
  }) {
    final barcodeConfig = sablon.barcodePaperConfig;
    if (barcodeConfig != null) {
      return PdfPageFormat(
        barcodeConfig.pageWidthMm * PdfPageFormat.mm,
        barcodeConfig.resolvedPageHeightMm * PdfPageFormat.mm,
      );
    }

    final PdfPageFormat base = switch (sablon.paperSize) {
      'A4' => PdfPageFormat.a4,
      'A5' => PdfPageFormat.a5,
      'Continuous' => const PdfPageFormat(
        240 * PdfPageFormat.mm,
        280 * PdfPageFormat.mm,
      ),
      'Thermal80' => const PdfPageFormat(
        80 * PdfPageFormat.mm,
        200 * PdfPageFormat.mm,
      ),
      'Thermal80Cutter' => const PdfPageFormat(
        80 * PdfPageFormat.mm,
        200 * PdfPageFormat.mm,
      ),
      'Thermal58' => const PdfPageFormat(
        58 * PdfPageFormat.mm,
        150 * PdfPageFormat.mm,
      ),
      _ => PdfPageFormat(
        (sablon.customWidth ?? 210) * PdfPageFormat.mm,
        (sablon.customHeight ?? 297) * PdfPageFormat.mm,
      ),
    };

    final oriented = sablon.isLandscape ? base.landscape : base;

    if (!sablon.usesDynamicThermalFlow || veri == null) {
      return oriented;
    }

    final effectiveLayout = sablon.layout.where((el) {
      if (visibleElements != null && visibleElements.containsKey(el.key)) {
        return visibleElements[el.key]!;
      }
      return true;
    }).toList();
    final nonRepeatElements = effectiveLayout.where((e) => !e.repeat).toList();
    final repeatElements = effectiveLayout.where((e) => e.repeat).toList();
    final rowCount = _resolveRepeatRowCount(repeatElements, veri);
    final rowHeightMm = _resolveRowHeightMm(repeatElements);
    final rowStepMm = rowHeightMm + sablon.itemRowSpacing;
    final layoutMetrics = _resolveLayoutMetrics(
      sablon: sablon,
      nonRepeatElements: nonRepeatElements,
      repeatElements: repeatElements,
      rowCount: rowCount,
      rowStepMm: rowStepMm,
    );

    return PdfPageFormat(
      oriented.width,
      layoutMetrics.pageHeightMm * PdfPageFormat.mm,
    );
  }

  ({double footerTopMm, double footerShiftMm, double pageHeightMm})
  _resolveLayoutMetrics({
    required YazdirmaSablonuModel sablon,
    required List<LayoutElement> nonRepeatElements,
    required List<LayoutElement> repeatElements,
    required int rowCount,
    required double rowStepMm,
  }) {
    if (!sablon.usesDynamicThermalFlow || repeatElements.isEmpty) {
      final contentBottomMm = _contentBottomForStaticLayout(
        nonRepeatElements: nonRepeatElements,
        repeatElements: repeatElements,
        rowCount: rowCount,
        rowStepMm: rowStepMm,
      );
      return (
        footerTopMm: double.infinity,
        footerShiftMm: 0.0,
        pageHeightMm: math.max(contentBottomMm + 4.0, 40.0),
      );
    }

    final double repeatBottomMm = repeatElements
        .map((e) => e.y + e.height)
        .fold<double>(0.0, math.max);
    final footerCandidates = nonRepeatElements
        .where((e) => e.y >= repeatBottomMm - 0.001)
        .toList();
    if (footerCandidates.isEmpty) {
      final contentBottomMm = _contentBottomForStaticLayout(
        nonRepeatElements: nonRepeatElements,
        repeatElements: repeatElements,
        rowCount: rowCount,
        rowStepMm: rowStepMm,
      );
      return (
        footerTopMm: double.infinity,
        footerShiftMm: 0.0,
        pageHeightMm: math.max(contentBottomMm + 4.0, 40.0),
      );
    }

    final double footerTopMm = footerCandidates
        .map((e) => e.y)
        .fold<double>(double.infinity, math.min);
    final int effectiveRowCount = math.max(rowCount, 1);
    final double actualRepeatBottomMm =
        repeatBottomMm + ((effectiveRowCount - 1) * rowStepMm);
    final double originalGapMm = math.max(0.0, footerTopMm - repeatBottomMm);
    final double compactGapMm = math.min(originalGapMm, 3.0);
    final double footerShiftMm =
        (actualRepeatBottomMm + compactGapMm) - footerTopMm;

    double contentBottomMm = 0.0;
    for (final el in nonRepeatElements) {
      final shift = _footerShiftForElement(
        el: el,
        footerTopMm: footerTopMm,
        footerShiftMm: footerShiftMm,
        enabled: true,
      );
      contentBottomMm = math.max(contentBottomMm, el.y + shift + el.height);
    }
    contentBottomMm = math.max(contentBottomMm, actualRepeatBottomMm);

    return (
      footerTopMm: footerTopMm,
      footerShiftMm: footerShiftMm,
      pageHeightMm: math.max(contentBottomMm + 4.0, 40.0),
    );
  }

  double _contentBottomForStaticLayout({
    required List<LayoutElement> nonRepeatElements,
    required List<LayoutElement> repeatElements,
    required int rowCount,
    required double rowStepMm,
  }) {
    double contentBottomMm = 0.0;
    for (final el in nonRepeatElements) {
      contentBottomMm = math.max(contentBottomMm, el.y + el.height);
    }
    if (repeatElements.isNotEmpty && rowCount > 0) {
      final repeatBottomMm = repeatElements
          .map((e) => e.y + e.height)
          .fold<double>(0.0, math.max);
      contentBottomMm = math.max(
        contentBottomMm,
        repeatBottomMm + ((rowCount - 1) * rowStepMm),
      );
    }
    return contentBottomMm;
  }

  double _footerShiftForElement({
    required LayoutElement el,
    required double footerTopMm,
    required double footerShiftMm,
    required bool enabled,
  }) {
    if (!enabled || !footerTopMm.isFinite || footerShiftMm == 0.0) return 0.0;
    return el.y >= footerTopMm - 0.001 ? footerShiftMm : 0.0;
  }

  int _resolveRepeatRowCount(
    List<LayoutElement> repeatElements,
    Map<String, dynamic> veri,
  ) {
    int maxLen = 0;
    for (final el in repeatElements) {
      final v = veri[el.key];
      if (v is Iterable) {
        maxLen = math.max(maxLen, v.length);
      }
    }
    return maxLen;
  }

  double _resolveRowHeightMm(List<LayoutElement> repeatElements) {
    double h = 0.0;
    for (final el in repeatElements) {
      h = math.max(h, el.height);
    }
    return h <= 0 ? 8.0 : h;
  }

  dynamic _valueAtIndex(dynamic value, int index) {
    if (value is List) {
      if (index < 0 || index >= value.length) return null;
      return value[index];
    }
    if (value is Iterable) {
      int i = 0;
      for (final v in value) {
        if (i == index) return v;
        i++;
      }
      return null;
    }
    return null;
  }

  bool _isEmptyValue(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable) return value.isEmpty;
    return false;
  }

  List<String> _extractBarcodeFeatureValues(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((item) {
            if (item is Map) {
              return item['name']?.toString().trim() ?? '';
            }
            return item.toString().trim();
          })
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      try {
        final decoded = jsonDecode(trimmed);
        return _extractBarcodeFeatureValues(decoded);
      } catch (_) {
        return trimmed
            .split(RegExp(r'[\n,;]+'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
    }

    return [raw.toString().trim()].where((item) => item.isNotEmpty).toList();
  }

  dynamic _resolveBarcodeFieldValue({
    required String key,
    required Map<String, dynamic> veri,
    dynamic raw,
  }) {
    if (!_isEmptyValue(raw)) return raw;

    dynamic firstOf(List<String> keys) {
      for (final candidateKey in keys) {
        final candidate = veri[candidateKey];
        if (!_isEmptyValue(candidate)) return candidate;
      }
      return null;
    }

    switch (key) {
      case 'barcode_product_code':
        return firstOf(['code', 'item_code']);
      case 'barcode_product_name':
        return firstOf(['name', 'item_name']);
      case 'barcode_number':
      case 'barcode_graphic':
        return firstOf(['barcode', 'item_barcode', 'barcode_number']);
      case 'barcode_unit':
        return firstOf(['unit', 'item_unit']);
      case 'barcode_vat_rate':
        return firstOf(['vatRate', 'item_vat_rate']);
      case 'barcode_group':
        return firstOf(['group']);
      case 'barcode_current_quantity':
        return firstOf(['stockQty', 'item_quantity']);
      case 'barcode_warning_quantity':
        return firstOf(['warningQty', 'barcode_warning_quantity']);
      case 'barcode_purchase_price':
        return firstOf(['buyPrice', 'item_unit_price_excl']);
      case 'barcode_purchase_currency':
        return firstOf(['buyPriceCurrency', 'currency', 'item_currency']);
      case 'barcode_sales_price_1':
        return firstOf(['sellPrice1', 'item_unit_price_incl']);
      case 'barcode_sales_price_1_currency':
        return firstOf(['sellPrice1Currency', 'currency', 'item_currency']);
      case 'barcode_sales_price_2':
        return firstOf(['sellPrice2']);
      case 'barcode_sales_price_2_currency':
        return firstOf(['sellPrice2Currency', 'currency', 'item_currency']);
      case 'barcode_sales_price_3':
        return firstOf(['sellPrice3']);
      case 'barcode_sales_price_3_currency':
        return firstOf(['sellPrice3Currency', 'currency', 'item_currency']);
      case 'barcode_feature_1':
      case 'barcode_feature_2':
      case 'barcode_feature_3':
      case 'barcode_feature_4':
      case 'barcode_feature_5':
        final featureIndex =
            int.tryParse(key.substring('barcode_feature_'.length)) ?? 1;
        final features = _extractBarcodeFeatureValues(veri['features']);
        if (featureIndex < 1 || featureIndex > features.length) return null;
        return features[featureIndex - 1];
      default:
        return raw;
    }
  }

  String _resolveQrDataPayload({
    required LayoutElement el,
    required Map<String, dynamic> veri,
    dynamic raw,
  }) {
    final configured = el.qrContentConfig?.buildPayload(veri).trim() ?? '';
    if (configured.isNotEmpty) return configured;
    return raw?.toString().trim() ?? '';
  }

  pw.Barcode _barcodeGraphicRenderer(BarkodGrafikModel config) {
    switch (config.standard) {
      case BarkodGrafikStandartlari.code39:
      case BarkodGrafikStandartlari.code39Extended:
        return pw.Barcode.code39();
      case BarkodGrafikStandartlari.code128A:
        return pw.Barcode.code128(
          useCode128A: true,
          useCode128B: false,
          useCode128C: false,
        );
      case BarkodGrafikStandartlari.code128B:
        return pw.Barcode.code128(
          useCode128A: false,
          useCode128B: true,
          useCode128C: false,
        );
      case BarkodGrafikStandartlari.code128C:
        return pw.Barcode.code128(
          useCode128A: false,
          useCode128B: false,
          useCode128C: true,
        );
      case BarkodGrafikStandartlari.gs1128:
        return pw.Barcode.gs128();
      case BarkodGrafikStandartlari.interleaved2of5:
      case BarkodGrafikStandartlari.standard2of5:
        return pw.Barcode.itf();
      case BarkodGrafikStandartlari.code93:
        return pw.Barcode.code93();
      case BarkodGrafikStandartlari.codabar:
        return pw.Barcode.codabar();
      case BarkodGrafikStandartlari.upcA:
        return pw.Barcode.upcA();
      case BarkodGrafikStandartlari.upcE:
        return pw.Barcode.upcE(fallback: true);
      case BarkodGrafikStandartlari.ean13:
        return pw.Barcode.ean13();
      case BarkodGrafikStandartlari.ean8:
        return pw.Barcode.ean8();
      case BarkodGrafikStandartlari.postnet:
        return pw.Barcode.postnet();
      case BarkodGrafikStandartlari.royalMail:
        return pw.Barcode.rm4scc();
      case BarkodGrafikStandartlari.pdf417:
        return pw.Barcode.pdf417();
      case BarkodGrafikStandartlari.dataMatrix:
        return pw.Barcode.dataMatrix();
      case BarkodGrafikStandartlari.qrCode:
        return pw.Barcode.qrCode();
      case BarkodGrafikStandartlari.code11:
      case BarkodGrafikStandartlari.msiPlessey:
      case BarkodGrafikStandartlari.intelligentMail:
        return pw.Barcode.code128();
      case BarkodGrafikStandartlari.code128Auto:
      default:
        return pw.Barcode.code128();
    }
  }

  String _resolveBarcodeGraphicData(
    LayoutElement el,
    Map<String, dynamic> veri,
    dynamic raw,
  ) {
    final config =
        el.barcodeGraphicConfig ?? BarkodGrafikModel.defaultLotYazilim();
    final resolvedRaw = raw?.toString() ?? '';
    return config.preparePayload(resolvedRaw);
  }

  pw.Widget? _buildElementWidget({
    required LayoutElement el,
    required Map<String, dynamic> veri,
    required pw.Font Function(LayoutElement el) resolveFont,
    required dynamic valueOverride,
    double yOffsetMm = 0.0,
  }) {
    final x = el.x * PdfPageFormat.mm;
    final y = (el.y + yOffsetMm) * PdfPageFormat.mm;
    final w = el.width * PdfPageFormat.mm;
    final h = el.height * PdfPageFormat.mm;

    if (el.elementType == 'line') {
      final PdfColor lineColor = _parsePdfColor(el.color) ?? PdfColors.black;
      return pw.Positioned(
        left: x,
        top: y,
        child: pw.SizedBox(
          width: w,
          height: h,
          child: pw.Center(
            child: pw.Container(width: w, height: 0.5, color: lineColor),
          ),
        ),
      );
    }

    if (el.elementType == 'image') {
      final raw = _resolveBarcodeFieldValue(
        key: el.key,
        veri: veri,
        raw: valueOverride ?? veri[el.key],
      );
      final bytes = _coerceToBytes(raw);
      if (bytes == null || bytes.isEmpty) {
        // [2026] QR Support: Allow passing raw string data for `receipt_qr`
        // without requiring the caller to pre-render an image.
        if (el.key == 'receipt_qr') {
          final data = _resolveQrDataPayload(el: el, veri: veri, raw: raw);
          if (data.isEmpty) return null;
          return pw.Positioned(
            left: x,
            top: y,
            child: pw.SizedBox(
              width: w,
              height: h,
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: data,
                drawText: false,
              ),
            ),
          );
        }
        if (el.key == 'barcode_graphic') {
          final data = _resolveBarcodeGraphicData(el, veri, raw);
          if (data.isEmpty) return null;
          final config =
              el.barcodeGraphicConfig ?? BarkodGrafikModel.defaultLotYazilim();
          final selectedBarcode = _barcodeGraphicRenderer(config);
          try {
            selectedBarcode.make(data, width: w, height: h, drawText: false);
            return pw.Positioned(
              left: x,
              top: y,
              child: pw.SizedBox(
                width: w,
                height: h,
                child: pw.BarcodeWidget(
                  barcode: selectedBarcode,
                  data: data,
                  drawText: false,
                ),
              ),
            );
          } catch (_) {
            final fallbackBarcode = pw.Barcode.code128();
            try {
              fallbackBarcode.make(data, width: w, height: h, drawText: false);
              return pw.Positioned(
                left: x,
                top: y,
                child: pw.SizedBox(
                  width: w,
                  height: h,
                  child: pw.BarcodeWidget(
                    barcode: fallbackBarcode,
                    data: data,
                    drawText: false,
                  ),
                ),
              );
            } catch (_) {
              return null;
            }
          }
        }
        return null;
      }

      final image = pw.MemoryImage(bytes);
      return pw.Positioned(
        left: x,
        top: y,
        child: pw.SizedBox(
          width: w,
          height: h,
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      );
    }

    final String text = el.isStatic
        ? el.label
        : _resolveBarcodeFieldValue(
                key: el.key,
                veri: veri,
                raw: valueOverride ?? veri[el.key],
              )?.toString() ??
              '';

    final PdfColor? color = _parsePdfColor(el.color);
    final PdfColor? bgColor = _parsePdfColor(el.backgroundColor);
    final pw.Font font = resolveFont(el);
    final pw.TextDecoration decoration = el.underline
        ? pw.TextDecoration.underline
        : pw.TextDecoration.none;
    final pw.FontStyle fontStyle = el.italic
        ? pw.FontStyle.italic
        : pw.FontStyle.normal;

    final content = pw.Align(
      alignment: _getPdfAlignment(el.alignment, el.vAlignment),
      child: pw.Text(
        text,
        textAlign: _getPdfTextAlign(el.alignment),
        style: pw.TextStyle(
          font: font,
          fontSize: double.tryParse(el.fontSize) ?? 10,
          color: color,
          decoration: decoration,
          fontStyle: fontStyle,
        ),
      ),
    );

    return pw.Positioned(
      left: x,
      top: y,
      child: pw.SizedBox(
        width: w,
        height: h,
        child: bgColor == null
            ? content
            : pw.Container(color: bgColor, child: content),
      ),
    );
  }

  Future<Map<String, pw.Font>> _preloadFonts(List<LayoutElement> layout) async {
    final requests = <String, Future<pw.Font>>{};

    // Always ensure fallback font exists
    final fallbackKey = _fontCacheKey();
    requests[fallbackKey] = _getFont(
      family: _normalizeFontFamily(null),
      weight: _normalizeFontWeight(null),
      italic: false,
    );

    for (final el in layout) {
      if (el.elementType != 'text') continue;
      final family = _normalizeFontFamily(el.fontFamily);
      final weight = _normalizeFontWeight(el.fontWeight);
      final italic = el.italic;
      final key = _fontCacheKey(family: family, weight: weight, italic: italic);
      requests[key] ??= _getFont(
        family: family,
        weight: weight,
        italic: italic,
      );
    }

    final resolved = <String, pw.Font>{};
    for (final entry in requests.entries) {
      resolved[entry.key] = await entry.value;
    }
    return resolved;
  }

  String _fontCacheKey({
    String family = 'Inter',
    String weight = 'Regular',
    bool italic = false,
  }) => '${family.trim()}|${weight.trim()}|${italic ? 'i' : 'n'}';

  String _normalizeFontFamily(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return 'Inter';

    // Normalize some common variants / legacy values
    if (v.toLowerCase() == 'opensans') return 'OpenSans';
    if (v.toLowerCase() == 'playfairdisplay') return 'PlayfairDisplay';
    if (v.toLowerCase() == 'titilliumweb') return 'TitilliumWeb';
    if (v.toLowerCase() == 'notosans') return 'NotoSans';

    return v;
  }

  String _normalizeFontWeight(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return 'Regular';

    final lower = v.toLowerCase();
    if (lower == 'normal' || lower == 'regular') return 'Regular';
    if (lower == 'bold') return 'Bold';

    // Handle numeric strings like "w700"
    final m = RegExp(r'w\\s*(\\d{3})').firstMatch(lower);
    if (m != null) {
      final n = int.tryParse(m.group(1)!) ?? 400;
      if (n <= 150) return 'Thin';
      if (n <= 350) return 'Light';
      if (n <= 450) return 'Regular';
      if (n <= 650) return 'Medium';
      if (n <= 850) return 'Bold';
      return 'Black';
    }

    // Designer values are like: Thin, Light, Regular, Medium, Bold, Black
    switch (v) {
      case 'Thin':
      case 'Light':
      case 'Regular':
      case 'Medium':
      case 'Bold':
      case 'Black':
        return v;
      default:
        return 'Regular';
    }
  }

  Future<pw.Font> _getFont({
    required String family,
    required String weight,
    required bool italic,
  }) {
    final key = _fontCacheKey(family: family, weight: weight, italic: italic);
    return _fontCache.putIfAbsent(
      key,
      () => _loadGoogleFont(family: family, weight: weight, italic: italic),
    );
  }

  Future<pw.Font> _loadGoogleFont({
    required String family,
    required String weight,
    required bool italic,
  }) async {
    // NOTE: Keep this mapping limited to fonts exposed in the designer.
    switch (family) {
      case 'Inter':
        return _loadInter(weight: weight, italic: italic);
      case 'Roboto':
        return _loadRoboto(weight: weight, italic: italic);
      case 'OpenSans':
        return _loadOpenSans(weight: weight, italic: italic);
      case 'Lato':
        return _loadLato(weight: weight, italic: italic);
      case 'Montserrat':
        return _loadMontserrat(weight: weight, italic: italic);
      case 'Oswald':
        return _loadOswald(weight: weight, italic: italic);
      case 'Raleway':
        return _loadRaleway(weight: weight, italic: italic);
      case 'Merriweather':
        return _loadMerriweather(weight: weight, italic: italic);
      case 'PlayfairDisplay':
        return _loadPlayfairDisplay(weight: weight, italic: italic);
      case 'Nunito':
        return _loadNunito(weight: weight, italic: italic);
      case 'NotoSans':
        return _loadNotoSans(weight: weight, italic: italic);
      case 'TitilliumWeb':
        return _loadTitilliumWeb(weight: weight, italic: italic);
      case 'Ubuntu':
        return _loadUbuntu(weight: weight, italic: italic);
      default:
        // Fallback
        return _loadInter(weight: 'Regular', italic: false);
    }
  }

  Future<pw.Font> _loadInter({required String weight, required bool italic}) {
    switch (weight) {
      case 'Thin':
        return italic
            ? PdfGoogleFonts.interThinItalic()
            : PdfGoogleFonts.interThin();
      case 'Light':
        return italic
            ? PdfGoogleFonts.interLightItalic()
            : PdfGoogleFonts.interLight();
      case 'Medium':
        return italic
            ? PdfGoogleFonts.interMediumItalic()
            : PdfGoogleFonts.interMedium();
      case 'Bold':
        return italic
            ? PdfGoogleFonts.interBoldItalic()
            : PdfGoogleFonts.interBold();
      case 'Black':
        return italic
            ? PdfGoogleFonts.interBlackItalic()
            : PdfGoogleFonts.interBlack();
      case 'Regular':
      default:
        return italic
            ? PdfGoogleFonts.interItalic()
            : PdfGoogleFonts.interRegular();
    }
  }

  Future<pw.Font> _loadRoboto({required String weight, required bool italic}) {
    switch (weight) {
      case 'Thin':
        return italic
            ? PdfGoogleFonts.robotoThinItalic()
            : PdfGoogleFonts.robotoThin();
      case 'Light':
        return italic
            ? PdfGoogleFonts.robotoLightItalic()
            : PdfGoogleFonts.robotoLight();
      case 'Medium':
        return italic
            ? PdfGoogleFonts.robotoMediumItalic()
            : PdfGoogleFonts.robotoMedium();
      case 'Bold':
        return italic
            ? PdfGoogleFonts.robotoBoldItalic()
            : PdfGoogleFonts.robotoBold();
      case 'Black':
        return italic
            ? PdfGoogleFonts.robotoBlackItalic()
            : PdfGoogleFonts.robotoBlack();
      case 'Regular':
      default:
        return italic
            ? PdfGoogleFonts.robotoItalic()
            : PdfGoogleFonts.robotoRegular();
    }
  }

  Future<pw.Font> _loadOpenSans({
    required String weight,
    required bool italic,
  }) {
    switch (weight) {
      case 'Thin':
      case 'Light':
        return italic
            ? PdfGoogleFonts.openSansLightItalic()
            : PdfGoogleFonts.openSansLight();
      case 'Medium':
        return italic
            ? PdfGoogleFonts.openSansMediumItalic()
            : PdfGoogleFonts.openSansMedium();
      case 'Bold':
      case 'Black':
        return italic
            ? PdfGoogleFonts.openSansBoldItalic()
            : PdfGoogleFonts.openSansBold();
      case 'Regular':
      default:
        return italic
            ? PdfGoogleFonts.openSansItalic()
            : PdfGoogleFonts.openSansRegular();
    }
  }

  Future<pw.Font> _loadLato({required String weight, required bool italic}) {
    switch (weight) {
      case 'Thin':
        return italic
            ? PdfGoogleFonts.latoThinItalic()
            : PdfGoogleFonts.latoThin();
      case 'Light':
        return italic
            ? PdfGoogleFonts.latoLightItalic()
            : PdfGoogleFonts.latoLight();
      case 'Medium':
      case 'Regular':
        return italic
            ? PdfGoogleFonts.latoItalic()
            : PdfGoogleFonts.latoRegular();
      case 'Bold':
        return italic
            ? PdfGoogleFonts.latoBoldItalic()
            : PdfGoogleFonts.latoBold();
      case 'Black':
        return italic
            ? PdfGoogleFonts.latoBlackItalic()
            : PdfGoogleFonts.latoBlack();
      default:
        return italic
            ? PdfGoogleFonts.latoItalic()
            : PdfGoogleFonts.latoRegular();
    }
  }

  Future<pw.Font> _loadMontserrat({
    required String weight,
    required bool italic,
  }) {
    switch (weight) {
      case 'Thin':
        return italic
            ? PdfGoogleFonts.montserratThinItalic()
            : PdfGoogleFonts.montserratThin();
      case 'Light':
        return italic
            ? PdfGoogleFonts.montserratLightItalic()
            : PdfGoogleFonts.montserratLight();
      case 'Medium':
        return italic
            ? PdfGoogleFonts.montserratMediumItalic()
            : PdfGoogleFonts.montserratMedium();
      case 'Bold':
        return italic
            ? PdfGoogleFonts.montserratBoldItalic()
            : PdfGoogleFonts.montserratBold();
      case 'Black':
        return italic
            ? PdfGoogleFonts.montserratBlackItalic()
            : PdfGoogleFonts.montserratBlack();
      case 'Regular':
      default:
        return italic
            ? PdfGoogleFonts.montserratItalic()
            : PdfGoogleFonts.montserratRegular();
    }
  }

  Future<pw.Font> _loadOswald({required String weight, required bool italic}) {
    // Oswald has no italic variants in Google Fonts.
    switch (weight) {
      case 'Thin':
      case 'Light':
        return PdfGoogleFonts.oswaldLight();
      case 'Medium':
        return PdfGoogleFonts.oswaldMedium();
      case 'Bold':
      case 'Black':
        return PdfGoogleFonts.oswaldBold();
      case 'Regular':
      default:
        return PdfGoogleFonts.oswaldRegular();
    }
  }

  Future<pw.Font> _loadRaleway({required String weight, required bool italic}) {
    switch (weight) {
      case 'Thin':
        return italic
            ? PdfGoogleFonts.ralewayThinItalic()
            : PdfGoogleFonts.ralewayThin();
      case 'Light':
        return italic
            ? PdfGoogleFonts.ralewayLightItalic()
            : PdfGoogleFonts.ralewayLight();
      case 'Medium':
        return italic
            ? PdfGoogleFonts.ralewayMediumItalic()
            : PdfGoogleFonts.ralewayMedium();
      case 'Bold':
        return italic
            ? PdfGoogleFonts.ralewayBoldItalic()
            : PdfGoogleFonts.ralewayBold();
      case 'Black':
        return italic
            ? PdfGoogleFonts.ralewayBlackItalic()
            : PdfGoogleFonts.ralewayBlack();
      case 'Regular':
      default:
        return italic
            ? PdfGoogleFonts.ralewayItalic()
            : PdfGoogleFonts.ralewayRegular();
    }
  }

  Future<pw.Font> _loadMerriweather({
    required String weight,
    required bool italic,
  }) {
    switch (weight) {
      case 'Light':
      case 'Thin':
        return italic
            ? PdfGoogleFonts.merriweatherLightItalic()
            : PdfGoogleFonts.merriweatherLight();
      case 'Bold':
        return italic
            ? PdfGoogleFonts.merriweatherBoldItalic()
            : PdfGoogleFonts.merriweatherBold();
      case 'Black':
        return italic
            ? PdfGoogleFonts.merriweatherBlackItalic()
            : PdfGoogleFonts.merriweatherBlack();
      case 'Medium':
      case 'Regular':
      default:
        return italic
            ? PdfGoogleFonts.merriweatherItalic()
            : PdfGoogleFonts.merriweatherRegular();
    }
  }

  Future<pw.Font> _loadPlayfairDisplay({
    required String weight,
    required bool italic,
  }) {
    switch (weight) {
      case 'Medium':
        return italic
            ? PdfGoogleFonts.playfairDisplayMediumItalic()
            : PdfGoogleFonts.playfairDisplayMedium();
      case 'Bold':
        return italic
            ? PdfGoogleFonts.playfairDisplayBoldItalic()
            : PdfGoogleFonts.playfairDisplayBold();
      case 'Black':
        return italic
            ? PdfGoogleFonts.playfairDisplayBlackItalic()
            : PdfGoogleFonts.playfairDisplayBlack();
      case 'Thin':
      case 'Light':
      case 'Regular':
      default:
        return italic
            ? PdfGoogleFonts.playfairDisplayItalic()
            : PdfGoogleFonts.playfairDisplayRegular();
    }
  }

  Future<pw.Font> _loadNunito({required String weight, required bool italic}) {
    switch (weight) {
      case 'Thin':
      case 'Light':
        return italic
            ? PdfGoogleFonts.nunitoLightItalic()
            : PdfGoogleFonts.nunitoLight();
      case 'Medium':
        return italic
            ? PdfGoogleFonts.nunitoMediumItalic()
            : PdfGoogleFonts.nunitoMedium();
      case 'Bold':
        return italic
            ? PdfGoogleFonts.nunitoBoldItalic()
            : PdfGoogleFonts.nunitoBold();
      case 'Black':
        return italic
            ? PdfGoogleFonts.nunitoBlackItalic()
            : PdfGoogleFonts.nunitoBlack();
      case 'Regular':
      default:
        return italic
            ? PdfGoogleFonts.nunitoItalic()
            : PdfGoogleFonts.nunitoRegular();
    }
  }

  Future<pw.Font> _loadNotoSans({
    required String weight,
    required bool italic,
  }) {
    switch (weight) {
      case 'Thin':
        return italic
            ? PdfGoogleFonts.notoSansThinItalic()
            : PdfGoogleFonts.notoSansThin();
      case 'Light':
        return italic
            ? PdfGoogleFonts.notoSansLightItalic()
            : PdfGoogleFonts.notoSansLight();
      case 'Medium':
        return italic
            ? PdfGoogleFonts.notoSansMediumItalic()
            : PdfGoogleFonts.notoSansMedium();
      case 'Bold':
        return italic
            ? PdfGoogleFonts.notoSansBoldItalic()
            : PdfGoogleFonts.notoSansBold();
      case 'Black':
        return italic
            ? PdfGoogleFonts.notoSansBlackItalic()
            : PdfGoogleFonts.notoSansBlack();
      case 'Regular':
      default:
        return italic
            ? PdfGoogleFonts.notoSansItalic()
            : PdfGoogleFonts.notoSansRegular();
    }
  }

  Future<pw.Font> _loadTitilliumWeb({
    required String weight,
    required bool italic,
  }) {
    switch (weight) {
      case 'Thin':
      case 'Light':
        return italic
            ? PdfGoogleFonts.titilliumWebLightItalic()
            : PdfGoogleFonts.titilliumWebLight();
      case 'Medium':
      case 'Regular':
        return italic
            ? PdfGoogleFonts.titilliumWebItalic()
            : PdfGoogleFonts.titilliumWebRegular();
      case 'Bold':
      case 'Black':
        return italic
            ? PdfGoogleFonts.titilliumWebBoldItalic()
            : PdfGoogleFonts.titilliumWebBold();
      default:
        return italic
            ? PdfGoogleFonts.titilliumWebItalic()
            : PdfGoogleFonts.titilliumWebRegular();
    }
  }

  Future<pw.Font> _loadUbuntu({required String weight, required bool italic}) {
    switch (weight) {
      case 'Thin':
      case 'Light':
        return italic
            ? PdfGoogleFonts.ubuntuLightItalic()
            : PdfGoogleFonts.ubuntuLight();
      case 'Medium':
        return italic
            ? PdfGoogleFonts.ubuntuMediumItalic()
            : PdfGoogleFonts.ubuntuMedium();
      case 'Bold':
      case 'Black':
        return italic
            ? PdfGoogleFonts.ubuntuBoldItalic()
            : PdfGoogleFonts.ubuntuBold();
      case 'Regular':
      default:
        return italic
            ? PdfGoogleFonts.ubuntuItalic()
            : PdfGoogleFonts.ubuntuRegular();
    }
  }

  Uint8List? _coerceToBytes(dynamic raw) {
    if (raw == null) return null;
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      // data URL: data:image/...;base64,XXXX
      if (trimmed.startsWith('data:image')) {
        final commaIndex = trimmed.indexOf(',');
        if (commaIndex != -1 && commaIndex < trimmed.length - 1) {
          final base64Part = trimmed.substring(commaIndex + 1).trim();
          if (base64Part.isEmpty) return null;
          try {
            return base64Decode(base64Part);
          } catch (_) {
            return null;
          }
        }
      }
      try {
        return base64Decode(trimmed);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  PdfColor? _parsePdfColor(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    final clean = hex.trim().replaceAll('#', '');
    String c = clean;
    if (c.length == 8) {
      // AARRGGBB => ignore alpha
      c = c.substring(2);
    }
    if (c.length != 6) return null;
    final int? value = int.tryParse(c, radix: 16);
    if (value == null) return null;
    final r = ((value >> 16) & 0xFF) / 255.0;
    final g = ((value >> 8) & 0xFF) / 255.0;
    final b = (value & 0xFF) / 255.0;
    return PdfColor(r, g, b);
  }

  pw.Alignment _getPdfAlignment(String h, String v) {
    double x = -1.0;
    if (h == 'center') x = 0.0;
    if (h == 'right') x = 1.0;

    double y = 0.0;
    if (v == 'top') y = -1.0;
    if (v == 'bottom') y = 1.0;

    return pw.Alignment(x, y);
  }

  pw.TextAlign _getPdfTextAlign(String align) {
    switch (align) {
      case 'center':
        return pw.TextAlign.center;
      case 'right':
        return pw.TextAlign.right;
      default:
        return pw.TextAlign.left;
    }
  }
}
