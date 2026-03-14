import 'dart:math' as math;

class BarkodKagitPreset {
  final String paperSizeCode;
  final String labelKey;
  final int labelCount;
  final double pageWidthMm;
  final double pageHeightMm;
  final int columns;
  final int rows;
  final double labelWidthMm;
  final double labelHeightMm;
  final double horizontalGapMm;
  final double verticalGapMm;
  final double marginLeftMm;
  final double marginTopMm;
  final double marginRightMm;
  final double marginBottomMm;

  const BarkodKagitPreset({
    required this.paperSizeCode,
    required this.labelKey,
    required this.labelCount,
    required this.pageWidthMm,
    required this.pageHeightMm,
    required this.columns,
    required this.rows,
    required this.labelWidthMm,
    required this.labelHeightMm,
    this.horizontalGapMm = 0,
    this.verticalGapMm = 0,
    this.marginLeftMm = 0,
    this.marginTopMm = 0,
    this.marginRightMm = 0,
    this.marginBottomMm = 0,
  });
}

class BarkodKagitAyari {
  final String mode;
  final String paperSizeCode;
  final double pageWidthMm;
  final double pageHeightMm;
  final int columns;
  final int rows;
  final double labelWidthMm;
  final double labelHeightMm;
  final double horizontalGapMm;
  final double verticalGapMm;
  final double marginLeftMm;
  final double marginTopMm;
  final double marginRightMm;
  final double marginBottomMm;
  final bool cutter;
  final bool showGuides;

  const BarkodKagitAyari({
    required this.mode,
    required this.paperSizeCode,
    required this.pageWidthMm,
    required this.pageHeightMm,
    required this.columns,
    required this.rows,
    required this.labelWidthMm,
    required this.labelHeightMm,
    required this.horizontalGapMm,
    required this.verticalGapMm,
    required this.marginLeftMm,
    required this.marginTopMm,
    required this.marginRightMm,
    required this.marginBottomMm,
    required this.cutter,
    this.showGuides = true,
  });

  bool get isThermal => mode == 'thermal_manual';

  double get resolvedPageHeightMm =>
      isThermal ? marginTopMm + labelHeightMm + marginBottomMm : pageHeightMm;

  double get resolvedLabelWidthMm {
    if (!isThermal) return labelWidthMm;
    final usableWidth =
        pageWidthMm -
        marginLeftMm -
        marginRightMm -
        (math.max(columns, 1) - 1) * horizontalGapMm;
    return math.max(8.0, usableWidth / math.max(columns, 1));
  }

  int get labelCount => math.max(columns, 1) * math.max(rows, 1);

  Map<String, dynamic> toMap() {
    return {
      'mode': mode,
      'paperSizeCode': paperSizeCode,
      'pageWidthMm': pageWidthMm,
      'pageHeightMm': pageHeightMm,
      'columns': columns,
      'rows': rows,
      'labelWidthMm': labelWidthMm,
      'labelHeightMm': labelHeightMm,
      'horizontalGapMm': horizontalGapMm,
      'verticalGapMm': verticalGapMm,
      'marginLeftMm': marginLeftMm,
      'marginTopMm': marginTopMm,
      'marginRightMm': marginRightMm,
      'marginBottomMm': marginBottomMm,
      'cutter': cutter,
      'showGuides': showGuides,
    };
  }

  factory BarkodKagitAyari.fromDynamic(
    dynamic value, {
    String? fallbackPaperSizeCode,
  }) {
    if (value is BarkodKagitAyari) {
      return value;
    }

    final fallback = BarkodKagitKatalog.ayarOlustur(
      fallbackPaperSizeCode ??
          BarkodKagitKatalog.varsayilanA4Preset.paperSizeCode,
    );

    if (value is! Map) return fallback;
    final map = value.map((key, item) => MapEntry(key.toString(), item));

    double number(dynamic raw, double defaultValue) {
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '') ?? defaultValue;
    }

    int intValue(dynamic raw, int defaultValue) {
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? defaultValue;
    }

    bool boolValue(dynamic raw, bool defaultValue) {
      if (raw is bool) return raw;
      if (raw == null) return defaultValue;
      final normalized = raw.toString().trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
      return defaultValue;
    }

    return BarkodKagitAyari(
      mode: (map['mode'] ?? fallback.mode).toString(),
      paperSizeCode:
          (map['paperSizeCode'] ??
                  fallbackPaperSizeCode ??
                  fallback.paperSizeCode)
              .toString(),
      pageWidthMm: number(map['pageWidthMm'], fallback.pageWidthMm),
      pageHeightMm: number(map['pageHeightMm'], fallback.pageHeightMm),
      columns: intValue(map['columns'], fallback.columns).clamp(1, 6),
      rows: intValue(map['rows'], fallback.rows).clamp(1, 100),
      labelWidthMm: number(map['labelWidthMm'], fallback.labelWidthMm),
      labelHeightMm: number(map['labelHeightMm'], fallback.labelHeightMm),
      horizontalGapMm: number(map['horizontalGapMm'], fallback.horizontalGapMm),
      verticalGapMm: number(map['verticalGapMm'], fallback.verticalGapMm),
      marginLeftMm: number(map['marginLeftMm'], fallback.marginLeftMm),
      marginTopMm: number(map['marginTopMm'], fallback.marginTopMm),
      marginRightMm: number(map['marginRightMm'], fallback.marginRightMm),
      marginBottomMm: number(map['marginBottomMm'], fallback.marginBottomMm),
      cutter: boolValue(map['cutter'], fallback.cutter),
      showGuides: boolValue(map['showGuides'], fallback.showGuides),
    );
  }

  BarkodKagitAyari copyWith({
    String? mode,
    String? paperSizeCode,
    double? pageWidthMm,
    double? pageHeightMm,
    int? columns,
    int? rows,
    double? labelWidthMm,
    double? labelHeightMm,
    double? horizontalGapMm,
    double? verticalGapMm,
    double? marginLeftMm,
    double? marginTopMm,
    double? marginRightMm,
    double? marginBottomMm,
    bool? cutter,
    bool? showGuides,
  }) {
    return BarkodKagitAyari(
      mode: mode ?? this.mode,
      paperSizeCode: paperSizeCode ?? this.paperSizeCode,
      pageWidthMm: pageWidthMm ?? this.pageWidthMm,
      pageHeightMm: pageHeightMm ?? this.pageHeightMm,
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      labelWidthMm: labelWidthMm ?? this.labelWidthMm,
      labelHeightMm: labelHeightMm ?? this.labelHeightMm,
      horizontalGapMm: horizontalGapMm ?? this.horizontalGapMm,
      verticalGapMm: verticalGapMm ?? this.verticalGapMm,
      marginLeftMm: marginLeftMm ?? this.marginLeftMm,
      marginTopMm: marginTopMm ?? this.marginTopMm,
      marginRightMm: marginRightMm ?? this.marginRightMm,
      marginBottomMm: marginBottomMm ?? this.marginBottomMm,
      cutter: cutter ?? this.cutter,
      showGuides: showGuides ?? this.showGuides,
    );
  }
}

class BarkodKagitKatalog {
  static const List<BarkodKagitPreset> a4Presetleri = [
    BarkodKagitPreset(
      paperSizeCode: 'BarcodeA4_12',
      labelKey: 'print.paper.barcode_a4_12',
      labelCount: 12,
      pageWidthMm: 210,
      pageHeightMm: 297,
      columns: 1,
      rows: 12,
      labelWidthMm: 210,
      labelHeightMm: 24,
      marginTopMm: 4.5,
      marginBottomMm: 4.5,
    ),
    BarkodKagitPreset(
      paperSizeCode: 'BarcodeA4_24',
      labelKey: 'print.paper.barcode_a4_24',
      labelCount: 24,
      pageWidthMm: 210,
      pageHeightMm: 297,
      columns: 3,
      rows: 8,
      labelWidthMm: 70,
      labelHeightMm: 37.125,
    ),
    BarkodKagitPreset(
      paperSizeCode: 'BarcodeA4_40',
      labelKey: 'print.paper.barcode_a4_40',
      labelCount: 40,
      pageWidthMm: 210,
      pageHeightMm: 297,
      columns: 4,
      rows: 10,
      labelWidthMm: 52.5,
      labelHeightMm: 29.7,
    ),
    BarkodKagitPreset(
      paperSizeCode: 'BarcodeA4_65',
      labelKey: 'print.paper.barcode_a4_65',
      labelCount: 65,
      pageWidthMm: 210,
      pageHeightMm: 297,
      columns: 5,
      rows: 13,
      labelWidthMm: 38.1,
      labelHeightMm: 21.2,
      horizontalGapMm: 2.725,
      marginLeftMm: 5.0,
      marginRightMm: 5.0,
      marginTopMm: 10.7,
      marginBottomMm: 10.7,
    ),
    BarkodKagitPreset(
      paperSizeCode: 'BarcodeA4_80',
      labelKey: 'print.paper.barcode_a4_80',
      labelCount: 80,
      pageWidthMm: 210,
      pageHeightMm: 297,
      columns: 8,
      rows: 10,
      labelWidthMm: 26.2,
      labelHeightMm: 29.7,
      marginLeftMm: 0.2,
      marginRightMm: 0.2,
    ),
    BarkodKagitPreset(
      paperSizeCode: 'BarcodeA4_95',
      labelKey: 'print.paper.barcode_a4_95',
      labelCount: 95,
      pageWidthMm: 210,
      pageHeightMm: 297,
      columns: 5,
      rows: 19,
      labelWidthMm: 30,
      labelHeightMm: 12,
      horizontalGapMm: 6,
      verticalGapMm: 3.49,
      marginLeftMm: 18,
      marginTopMm: 3,
      marginRightMm: 18,
      marginBottomMm: 3.2,
    ),
  ];

  static const String a4ManualPaperCode = 'BarcodeA4Manual';
  static const String thermalPaperCode = 'BarcodeThermal80';
  static const String thermalCutterPaperCode = 'BarcodeThermal80Cutter';

  static const BarkodKagitPreset varsayilanA4Preset = BarkodKagitPreset(
    paperSizeCode: 'BarcodeA4_24',
    labelKey: 'print.paper.barcode_a4_24',
    labelCount: 24,
    pageWidthMm: 210,
    pageHeightMm: 297,
    columns: 3,
    rows: 8,
    labelWidthMm: 70,
    labelHeightMm: 37.125,
  );

  static bool barkodKagitMi(String? paperSizeCode) {
    if (paperSizeCode == null || paperSizeCode.trim().isEmpty) return false;
    if (paperSizeCode == a4ManualPaperCode ||
        paperSizeCode == thermalPaperCode ||
        paperSizeCode == thermalCutterPaperCode) {
      return true;
    }
    return a4Presetleri.any((item) => item.paperSizeCode == paperSizeCode);
  }

  static BarkodKagitPreset? presetBul(String? paperSizeCode) {
    for (final preset in a4Presetleri) {
      if (preset.paperSizeCode == paperSizeCode) return preset;
    }
    return null;
  }

  static BarkodKagitAyari ayarOlustur(
    String paperSizeCode, {
    Map<String, dynamic>? storedConfig,
  }) {
    if (paperSizeCode == a4ManualPaperCode) {
      final fallback = varsayilanA4Manual();
      if (storedConfig == null) return fallback;
      return BarkodKagitAyari.fromDynamic(
        storedConfig,
        fallbackPaperSizeCode: fallback.paperSizeCode,
      ).copyWith(
        mode: fallback.mode,
        paperSizeCode: fallback.paperSizeCode,
        pageWidthMm: fallback.pageWidthMm,
        pageHeightMm: fallback.pageHeightMm,
        cutter: false,
      );
    }

    final preset = presetBul(paperSizeCode);
    if (preset != null) {
      return BarkodKagitAyari(
        mode: 'a4_preset',
        paperSizeCode: preset.paperSizeCode,
        pageWidthMm: preset.pageWidthMm,
        pageHeightMm: preset.pageHeightMm,
        columns: preset.columns,
        rows: preset.rows,
        labelWidthMm: preset.labelWidthMm,
        labelHeightMm: preset.labelHeightMm,
        horizontalGapMm: preset.horizontalGapMm,
        verticalGapMm: preset.verticalGapMm,
        marginLeftMm: preset.marginLeftMm,
        marginTopMm: preset.marginTopMm,
        marginRightMm: preset.marginRightMm,
        marginBottomMm: preset.marginBottomMm,
        cutter: false,
        showGuides: true,
      );
    }

    final fallback = paperSizeCode == thermalCutterPaperCode
        ? varsayilanTermal(cutter: true)
        : varsayilanTermal();
    if (storedConfig == null) return fallback;
    return BarkodKagitAyari.fromDynamic(
      storedConfig,
      fallbackPaperSizeCode: fallback.paperSizeCode,
    );
  }

  static BarkodKagitAyari varsayilanA4Manual() {
    const preset = varsayilanA4Preset;
    return BarkodKagitAyari(
      mode: 'a4_manual',
      paperSizeCode: a4ManualPaperCode,
      pageWidthMm: 210,
      pageHeightMm: 297,
      columns: preset.columns,
      rows: preset.rows,
      labelWidthMm: preset.labelWidthMm,
      labelHeightMm: preset.labelHeightMm,
      horizontalGapMm: preset.horizontalGapMm,
      verticalGapMm: preset.verticalGapMm,
      marginLeftMm: preset.marginLeftMm,
      marginTopMm: preset.marginTopMm,
      marginRightMm: preset.marginRightMm,
      marginBottomMm: preset.marginBottomMm,
      cutter: false,
      showGuides: true,
    );
  }

  static BarkodKagitAyari varsayilanTermal({bool cutter = false}) {
    return BarkodKagitAyari(
      mode: 'thermal_manual',
      paperSizeCode: cutter ? thermalCutterPaperCode : thermalPaperCode,
      pageWidthMm: 80,
      pageHeightMm: 36,
      columns: 2,
      rows: 1,
      labelWidthMm: 37,
      labelHeightMm: 32,
      horizontalGapMm: 2,
      verticalGapMm: 0,
      marginLeftMm: 2,
      marginTopMm: 2,
      marginRightMm: 2,
      marginBottomMm: 2,
      cutter: cutter,
      showGuides: true,
    );
  }
}
