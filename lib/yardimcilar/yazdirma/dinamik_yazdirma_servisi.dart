import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:patisyov10/sayfalar/ayarlar/yazdirma_ayarlari/modeller/yazdirma_sablonu_model.dart';

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
    final doc = await pdfOlustur(sablon: sablon, veri: veri);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${sablon.name}_Çıktı',
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

    final PdfPageFormat format =
        formatOverride ?? overrideFormat ?? getFormat(sablon);

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

  PdfPageFormat getFormat(YazdirmaSablonuModel sablon) {
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
      'Thermal58' => const PdfPageFormat(
        58 * PdfPageFormat.mm,
        150 * PdfPageFormat.mm,
      ),
      _ => PdfPageFormat(
        (sablon.customWidth ?? 210) * PdfPageFormat.mm,
        (sablon.customHeight ?? 297) * PdfPageFormat.mm,
      ),
    };

    return sablon.isLandscape ? base.landscape : base;
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
      final raw = valueOverride ?? veri[el.key];
      final bytes = _coerceToBytes(raw);
      if (bytes == null || bytes.isEmpty) {
        // [2026] QR Support: Allow passing raw string data for `receipt_qr`
        // without requiring the caller to pre-render an image.
        if (el.key == 'receipt_qr') {
          final data = raw?.toString().trim() ?? '';
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
        : (valueOverride ?? veri[el.key])?.toString() ?? '';

    final PdfColor? color = _parsePdfColor(el.color);
    final PdfColor? bgColor = _parsePdfColor(el.backgroundColor);
    final pw.Font font = resolveFont(el);
    final pw.TextDecoration decoration =
        el.underline ? pw.TextDecoration.underline : pw.TextDecoration.none;
    final pw.FontStyle fontStyle =
        el.italic ? pw.FontStyle.italic : pw.FontStyle.normal;

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
        child: bgColor == null ? content : pw.Container(color: bgColor, child: content),
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
      requests[key] ??= _getFont(family: family, weight: weight, italic: italic);
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
        return italic ? PdfGoogleFonts.interThinItalic() : PdfGoogleFonts.interThin();
      case 'Light':
        return italic ? PdfGoogleFonts.interLightItalic() : PdfGoogleFonts.interLight();
      case 'Medium':
        return italic ? PdfGoogleFonts.interMediumItalic() : PdfGoogleFonts.interMedium();
      case 'Bold':
        return italic ? PdfGoogleFonts.interBoldItalic() : PdfGoogleFonts.interBold();
      case 'Black':
        return italic ? PdfGoogleFonts.interBlackItalic() : PdfGoogleFonts.interBlack();
      case 'Regular':
      default:
        return italic ? PdfGoogleFonts.interItalic() : PdfGoogleFonts.interRegular();
    }
  }

  Future<pw.Font> _loadRoboto({required String weight, required bool italic}) {
    switch (weight) {
      case 'Thin':
        return italic ? PdfGoogleFonts.robotoThinItalic() : PdfGoogleFonts.robotoThin();
      case 'Light':
        return italic ? PdfGoogleFonts.robotoLightItalic() : PdfGoogleFonts.robotoLight();
      case 'Medium':
        return italic ? PdfGoogleFonts.robotoMediumItalic() : PdfGoogleFonts.robotoMedium();
      case 'Bold':
        return italic ? PdfGoogleFonts.robotoBoldItalic() : PdfGoogleFonts.robotoBold();
      case 'Black':
        return italic ? PdfGoogleFonts.robotoBlackItalic() : PdfGoogleFonts.robotoBlack();
      case 'Regular':
      default:
        return italic ? PdfGoogleFonts.robotoItalic() : PdfGoogleFonts.robotoRegular();
    }
  }

  Future<pw.Font> _loadOpenSans({required String weight, required bool italic}) {
    switch (weight) {
      case 'Thin':
      case 'Light':
        return italic ? PdfGoogleFonts.openSansLightItalic() : PdfGoogleFonts.openSansLight();
      case 'Medium':
        return italic ? PdfGoogleFonts.openSansMediumItalic() : PdfGoogleFonts.openSansMedium();
      case 'Bold':
      case 'Black':
        return italic ? PdfGoogleFonts.openSansBoldItalic() : PdfGoogleFonts.openSansBold();
      case 'Regular':
      default:
        return italic ? PdfGoogleFonts.openSansItalic() : PdfGoogleFonts.openSansRegular();
    }
  }

  Future<pw.Font> _loadLato({required String weight, required bool italic}) {
    switch (weight) {
      case 'Thin':
        return italic ? PdfGoogleFonts.latoThinItalic() : PdfGoogleFonts.latoThin();
      case 'Light':
        return italic ? PdfGoogleFonts.latoLightItalic() : PdfGoogleFonts.latoLight();
      case 'Medium':
      case 'Regular':
        return italic ? PdfGoogleFonts.latoItalic() : PdfGoogleFonts.latoRegular();
      case 'Bold':
        return italic ? PdfGoogleFonts.latoBoldItalic() : PdfGoogleFonts.latoBold();
      case 'Black':
        return italic ? PdfGoogleFonts.latoBlackItalic() : PdfGoogleFonts.latoBlack();
      default:
        return italic ? PdfGoogleFonts.latoItalic() : PdfGoogleFonts.latoRegular();
    }
  }

  Future<pw.Font> _loadMontserrat({required String weight, required bool italic}) {
    switch (weight) {
      case 'Thin':
        return italic ? PdfGoogleFonts.montserratThinItalic() : PdfGoogleFonts.montserratThin();
      case 'Light':
        return italic ? PdfGoogleFonts.montserratLightItalic() : PdfGoogleFonts.montserratLight();
      case 'Medium':
        return italic ? PdfGoogleFonts.montserratMediumItalic() : PdfGoogleFonts.montserratMedium();
      case 'Bold':
        return italic ? PdfGoogleFonts.montserratBoldItalic() : PdfGoogleFonts.montserratBold();
      case 'Black':
        return italic ? PdfGoogleFonts.montserratBlackItalic() : PdfGoogleFonts.montserratBlack();
      case 'Regular':
      default:
        return italic ? PdfGoogleFonts.montserratItalic() : PdfGoogleFonts.montserratRegular();
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
        return italic ? PdfGoogleFonts.ralewayThinItalic() : PdfGoogleFonts.ralewayThin();
      case 'Light':
        return italic ? PdfGoogleFonts.ralewayLightItalic() : PdfGoogleFonts.ralewayLight();
      case 'Medium':
        return italic ? PdfGoogleFonts.ralewayMediumItalic() : PdfGoogleFonts.ralewayMedium();
      case 'Bold':
        return italic ? PdfGoogleFonts.ralewayBoldItalic() : PdfGoogleFonts.ralewayBold();
      case 'Black':
        return italic ? PdfGoogleFonts.ralewayBlackItalic() : PdfGoogleFonts.ralewayBlack();
      case 'Regular':
      default:
        return italic ? PdfGoogleFonts.ralewayItalic() : PdfGoogleFonts.ralewayRegular();
    }
  }

  Future<pw.Font> _loadMerriweather({required String weight, required bool italic}) {
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
        return italic ? PdfGoogleFonts.merriweatherItalic() : PdfGoogleFonts.merriweatherRegular();
    }
  }

  Future<pw.Font> _loadPlayfairDisplay({required String weight, required bool italic}) {
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
        return italic ? PdfGoogleFonts.playfairDisplayItalic() : PdfGoogleFonts.playfairDisplayRegular();
    }
  }

  Future<pw.Font> _loadNunito({required String weight, required bool italic}) {
    switch (weight) {
      case 'Thin':
      case 'Light':
        return italic ? PdfGoogleFonts.nunitoLightItalic() : PdfGoogleFonts.nunitoLight();
      case 'Medium':
        return italic ? PdfGoogleFonts.nunitoMediumItalic() : PdfGoogleFonts.nunitoMedium();
      case 'Bold':
        return italic ? PdfGoogleFonts.nunitoBoldItalic() : PdfGoogleFonts.nunitoBold();
      case 'Black':
        return italic ? PdfGoogleFonts.nunitoBlackItalic() : PdfGoogleFonts.nunitoBlack();
      case 'Regular':
      default:
        return italic ? PdfGoogleFonts.nunitoItalic() : PdfGoogleFonts.nunitoRegular();
    }
  }

  Future<pw.Font> _loadNotoSans({required String weight, required bool italic}) {
    switch (weight) {
      case 'Thin':
        return italic ? PdfGoogleFonts.notoSansThinItalic() : PdfGoogleFonts.notoSansThin();
      case 'Light':
        return italic ? PdfGoogleFonts.notoSansLightItalic() : PdfGoogleFonts.notoSansLight();
      case 'Medium':
        return italic ? PdfGoogleFonts.notoSansMediumItalic() : PdfGoogleFonts.notoSansMedium();
      case 'Bold':
        return italic ? PdfGoogleFonts.notoSansBoldItalic() : PdfGoogleFonts.notoSansBold();
      case 'Black':
        return italic ? PdfGoogleFonts.notoSansBlackItalic() : PdfGoogleFonts.notoSansBlack();
      case 'Regular':
      default:
        return italic ? PdfGoogleFonts.notoSansItalic() : PdfGoogleFonts.notoSansRegular();
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
        return italic ? PdfGoogleFonts.ubuntuLightItalic() : PdfGoogleFonts.ubuntuLight();
      case 'Medium':
        return italic ? PdfGoogleFonts.ubuntuMediumItalic() : PdfGoogleFonts.ubuntuMedium();
      case 'Bold':
      case 'Black':
        return italic ? PdfGoogleFonts.ubuntuBoldItalic() : PdfGoogleFonts.ubuntuBold();
      case 'Regular':
      default:
        return italic ? PdfGoogleFonts.ubuntuItalic() : PdfGoogleFonts.ubuntuRegular();
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
