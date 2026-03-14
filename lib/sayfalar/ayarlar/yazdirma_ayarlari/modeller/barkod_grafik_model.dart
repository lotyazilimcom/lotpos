class BarkodGrafikDestekTuru {
  static const String native = 'native';
  static const String compatible = 'compatible';
}

class BarkodGrafikOnizlemeTuru {
  static const String linear = 'linear';
  static const String stacked = 'stacked';
  static const String matrix = 'matrix';
  static const String postal = 'postal';
}

class BarkodGrafikStandartlari {
  static const String code39 = 'code_39';
  static const String code39Extended = 'code_39_extended';
  static const String code128Auto = 'code_128_auto';
  static const String code128A = 'code_128_a';
  static const String code128B = 'code_128_b';
  static const String code128C = 'code_128_c';
  static const String gs1128 = 'gs1_128';
  static const String interleaved2of5 = 'interleaved_2of5';
  static const String standard2of5 = 'standard_2of5';
  static const String code93 = 'code_93';
  static const String code11 = 'code_11';
  static const String codabar = 'codabar';
  static const String msiPlessey = 'msi_plessey';
  static const String upcA = 'upc_a';
  static const String upcE = 'upc_e';
  static const String ean13 = 'ean_13';
  static const String ean8 = 'ean_8';
  static const String intelligentMail = 'intelligent_mail';
  static const String postnet = 'postnet';
  static const String royalMail = 'royal_mail';
  static const String pdf417 = 'pdf417';
  static const String dataMatrix = 'data_matrix';
  static const String qrCode = 'qr_code';

  static const List<String> values = [
    code39,
    code39Extended,
    code128Auto,
    code128A,
    code128B,
    code128C,
    gs1128,
    interleaved2of5,
    standard2of5,
    code93,
    code11,
    codabar,
    msiPlessey,
    upcA,
    upcE,
    ean13,
    ean8,
    intelligentMail,
    postnet,
    royalMail,
    pdf417,
    dataMatrix,
    qrCode,
  ];
}

class BarkodGrafikStandartMeta {
  final String code;
  final String labelKey;
  final String descriptionKey;
  final String previewKind;
  final String supportType;
  final String sampleData;

  const BarkodGrafikStandartMeta({
    required this.code,
    required this.labelKey,
    required this.descriptionKey,
    required this.previewKind,
    required this.supportType,
    required this.sampleData,
  });

  bool get isNativeSupported => supportType == BarkodGrafikDestekTuru.native;
}

class BarkodGrafikKatalog {
  static const BarkodGrafikStandartMeta varsayilan = BarkodGrafikStandartMeta(
    code: BarkodGrafikStandartlari.code128Auto,
    labelKey: 'print.barcode.standard.code_128_auto',
    descriptionKey: 'print.barcode.standard_desc.code_128_auto',
    previewKind: BarkodGrafikOnizlemeTuru.linear,
    supportType: BarkodGrafikDestekTuru.native,
    sampleData: 'LOT-12345-2026',
  );

  static const List<BarkodGrafikStandartMeta> standartlar = [
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.code39,
      labelKey: 'print.barcode.standard.code_39',
      descriptionKey: 'print.barcode.standard_desc.code_39',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: 'LOT-12345',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.code39Extended,
      labelKey: 'print.barcode.standard.code_39_extended',
      descriptionKey: 'print.barcode.standard_desc.code_39_extended',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.compatible,
      sampleData: 'LOT POS/123',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.code128Auto,
      labelKey: 'print.barcode.standard.code_128_auto',
      descriptionKey: 'print.barcode.standard_desc.code_128_auto',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: 'LOT-12345-2026',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.code128A,
      labelKey: 'print.barcode.standard.code_128_a',
      descriptionKey: 'print.barcode.standard_desc.code_128_a',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: 'LOT12345',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.code128B,
      labelKey: 'print.barcode.standard.code_128_b',
      descriptionKey: 'print.barcode.standard_desc.code_128_b',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: 'Lot12345',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.code128C,
      labelKey: 'print.barcode.standard.code_128_c',
      descriptionKey: 'print.barcode.standard_desc.code_128_c',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: '869123456789',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.gs1128,
      labelKey: 'print.barcode.standard.gs1_128',
      descriptionKey: 'print.barcode.standard_desc.gs1_128',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: '(01)08691234567895(10)LOT26',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.interleaved2of5,
      labelKey: 'print.barcode.standard.interleaved_2of5',
      descriptionKey: 'print.barcode.standard_desc.interleaved_2of5',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: '12345678',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.standard2of5,
      labelKey: 'print.barcode.standard.standard_2of5',
      descriptionKey: 'print.barcode.standard_desc.standard_2of5',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.compatible,
      sampleData: '12345670',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.code93,
      labelKey: 'print.barcode.standard.code_93',
      descriptionKey: 'print.barcode.standard_desc.code_93',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: 'LOTPOS93',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.code11,
      labelKey: 'print.barcode.standard.code_11',
      descriptionKey: 'print.barcode.standard_desc.code_11',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.compatible,
      sampleData: '123456-78',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.codabar,
      labelKey: 'print.barcode.standard.codabar',
      descriptionKey: 'print.barcode.standard_desc.codabar',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: 'A123456B',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.msiPlessey,
      labelKey: 'print.barcode.standard.msi_plessey',
      descriptionKey: 'print.barcode.standard_desc.msi_plessey',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.compatible,
      sampleData: '1234567890',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.upcA,
      labelKey: 'print.barcode.standard.upc_a',
      descriptionKey: 'print.barcode.standard_desc.upc_a',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: '036000291452',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.upcE,
      labelKey: 'print.barcode.standard.upc_e',
      descriptionKey: 'print.barcode.standard_desc.upc_e',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: '04210005',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.ean13,
      labelKey: 'print.barcode.standard.ean_13',
      descriptionKey: 'print.barcode.standard_desc.ean_13',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: '8691234567890',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.ean8,
      labelKey: 'print.barcode.standard.ean_8',
      descriptionKey: 'print.barcode.standard_desc.ean_8',
      previewKind: BarkodGrafikOnizlemeTuru.linear,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: '55123457',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.intelligentMail,
      labelKey: 'print.barcode.standard.intelligent_mail',
      descriptionKey: 'print.barcode.standard_desc.intelligent_mail',
      previewKind: BarkodGrafikOnizlemeTuru.postal,
      supportType: BarkodGrafikDestekTuru.compatible,
      sampleData: '01234567094987654321',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.postnet,
      labelKey: 'print.barcode.standard.postnet',
      descriptionKey: 'print.barcode.standard_desc.postnet',
      previewKind: BarkodGrafikOnizlemeTuru.postal,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: '123456789',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.royalMail,
      labelKey: 'print.barcode.standard.royal_mail',
      descriptionKey: 'print.barcode.standard_desc.royal_mail',
      previewKind: BarkodGrafikOnizlemeTuru.postal,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: 'BX11LT1A',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.pdf417,
      labelKey: 'print.barcode.standard.pdf417',
      descriptionKey: 'print.barcode.standard_desc.pdf417',
      previewKind: BarkodGrafikOnizlemeTuru.stacked,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: 'LOT POS 2026 / 8691234567890',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.dataMatrix,
      labelKey: 'print.barcode.standard.data_matrix',
      descriptionKey: 'print.barcode.standard_desc.data_matrix',
      previewKind: BarkodGrafikOnizlemeTuru.matrix,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: 'LOT POS 2026',
    ),
    BarkodGrafikStandartMeta(
      code: BarkodGrafikStandartlari.qrCode,
      labelKey: 'print.barcode.standard.qr_code',
      descriptionKey: 'print.barcode.standard_desc.qr_code',
      previewKind: BarkodGrafikOnizlemeTuru.matrix,
      supportType: BarkodGrafikDestekTuru.native,
      sampleData: 'https://lotyazilim.com',
    ),
  ];

  static BarkodGrafikStandartMeta metaFor(String? code) {
    return standartlar.firstWhere(
      (meta) => meta.code == code,
      orElse: () => varsayilan,
    );
  }
}

class BarkodGrafikModel {
  final String standard;

  const BarkodGrafikModel({
    this.standard = BarkodGrafikStandartlari.code128Auto,
  });

  factory BarkodGrafikModel.defaultLotYazilim() {
    return const BarkodGrafikModel();
  }

  factory BarkodGrafikModel.fromMap(Map<String, dynamic> map) {
    final rawStandard = (map['standard'] ?? '').toString().trim();
    final normalizedStandard =
        BarkodGrafikStandartlari.values.contains(rawStandard)
        ? rawStandard
        : BarkodGrafikStandartlari.code128Auto;

    return BarkodGrafikModel(standard: normalizedStandard);
  }

  static BarkodGrafikModel? fromDynamic(dynamic raw) {
    if (raw is Map) {
      return BarkodGrafikModel.fromMap(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  BarkodGrafikStandartMeta get meta => BarkodGrafikKatalog.metaFor(standard);

  bool get isNativeSupported => meta.isNativeSupported;

  Map<String, dynamic> toMap() {
    return {'standard': standard};
  }

  BarkodGrafikModel copyWith({String? standard}) {
    return BarkodGrafikModel(standard: standard ?? this.standard);
  }

  String preparePayload(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    switch (standard) {
      case BarkodGrafikStandartlari.code128C:
        final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isEmpty) return '';
        return digits.length.isOdd ? '0$digits' : digits;
      case BarkodGrafikStandartlari.interleaved2of5:
      case BarkodGrafikStandartlari.standard2of5:
      case BarkodGrafikStandartlari.code11:
      case BarkodGrafikStandartlari.msiPlessey:
      case BarkodGrafikStandartlari.upcA:
      case BarkodGrafikStandartlari.upcE:
      case BarkodGrafikStandartlari.ean13:
      case BarkodGrafikStandartlari.ean8:
      case BarkodGrafikStandartlari.intelligentMail:
      case BarkodGrafikStandartlari.postnet:
        return trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      case BarkodGrafikStandartlari.royalMail:
        return trimmed.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      default:
        return trimmed;
    }
  }
}
