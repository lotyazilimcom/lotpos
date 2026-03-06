import 'dart:convert';
import 'cihaz_model.dart';

class UrunModel {
  final int id;
  final String kod;
  final String ad;
  final String birim;
  final double alisFiyati;
  final double satisFiyati1;
  final double satisFiyati2;
  final double satisFiyati3;
  final double kdvOrani;
  final double stok;
  final double erkenUyariMiktari;
  final String grubu;
  final String ozellikler;
  final String barkod;
  final String kullanici;
  final String? resimUrl;
  final List<String> resimler;
  final bool aktifMi;
  final String? createdBy;
  final DateTime? createdAt;
  final bool matchedInHidden; // For search results explaining why it matched
  final List<CihazModel> cihazlar;

  const UrunModel({
    required this.id,
    required this.kod,
    required this.ad,
    required this.birim,
    required this.alisFiyati,
    required this.satisFiyati1,
    required this.satisFiyati2,
    required this.satisFiyati3,
    required this.kdvOrani,
    required this.stok,
    required this.erkenUyariMiktari,
    required this.grubu,
    required this.ozellikler,
    required this.barkod,
    required this.kullanici,
    this.resimUrl,
    this.resimler = const [],
    required this.aktifMi,
    this.createdBy,
    this.createdAt,
    this.matchedInHidden = false,
    this.cihazlar = const [],
  });

  UrunModel copyWith({
    int? id,
    String? kod,
    String? ad,
    String? birim,
    double? alisFiyati,
    double? satisFiyati1,
    double? satisFiyati2,
    double? satisFiyati3,
    double? kdvOrani,
    double? stok,
    double? erkenUyariMiktari,
    String? grubu,
    String? ozellikler,
    String? barkod,
    String? kullanici,
    String? resimUrl,
    List<String>? resimler,
    bool? aktifMi,
    String? createdBy,
    DateTime? createdAt,
    bool? matchedInHidden,
    List<CihazModel>? cihazlar,
  }) {
    return UrunModel(
      id: id ?? this.id,
      kod: kod ?? this.kod,
      ad: ad ?? this.ad,
      birim: birim ?? this.birim,
      alisFiyati: alisFiyati ?? this.alisFiyati,
      satisFiyati1: satisFiyati1 ?? this.satisFiyati1,
      satisFiyati2: satisFiyati2 ?? this.satisFiyati2,
      satisFiyati3: satisFiyati3 ?? this.satisFiyati3,
      kdvOrani: kdvOrani ?? this.kdvOrani,
      stok: stok ?? this.stok,
      erkenUyariMiktari: erkenUyariMiktari ?? this.erkenUyariMiktari,
      grubu: grubu ?? this.grubu,
      ozellikler: ozellikler ?? this.ozellikler,
      barkod: barkod ?? this.barkod,
      kullanici: kullanici ?? this.kullanici,
      resimUrl: resimUrl ?? this.resimUrl,
      resimler: resimler ?? this.resimler,
      aktifMi: aktifMi ?? this.aktifMi,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      matchedInHidden: matchedInHidden ?? this.matchedInHidden,
      cihazlar: cihazlar ?? this.cihazlar,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id == 0 ? null : id,
      'kod': kod,
      'ad': ad,
      'birim': birim,
      'alis_fiyati': alisFiyati,
      'satis_fiyati_1': satisFiyati1,
      'satis_fiyati_2': satisFiyati2,
      'satis_fiyati_3': satisFiyati3,
      'kdv_orani': kdvOrani,
      'stok': stok,
      'erken_uyari_miktari': erkenUyariMiktari,
      'grubu': grubu,
      'ozellikler': ozellikler,
      'barkod': barkod,
      'kullanici': kullanici,
      'resim_url': resimUrl,
      'resimler': resimler,
      'aktif_mi': aktifMi ? 1 : 0,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'cihazlar': cihazlar.map((e) => e.toMap()).toList(),
      // matchedInHidden is not stored in DB, so usually not needed in toMap, but ok to skip or add transiently
    };
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return true;
    if (value is int) return value == 1;
    if (value is bool) return value;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return true;
  }

  static List<int> _stripJsonbHeader(List<int> bytes) {
    if (bytes.isEmpty) return bytes;
    // Postgres JSONB binary format: first byte is version (usually 1),
    // followed by UTF-8 JSON text.
    if (bytes[0] == 1 && bytes.length > 1) {
      final b1 = bytes[1];
      if (b1 == 91 /* [ */ || b1 == 123 /* { */) {
        return bytes.sublist(1);
      }
    }
    return bytes;
  }

  factory UrunModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedResimler = [];

    final resimlerRaw = map['resimler'];
    if (resimlerRaw != null) {
      if (resimlerRaw is List) {
        if (resimlerRaw.isNotEmpty && resimlerRaw.first is int) {
          try {
            final rawBytes = resimlerRaw.cast<int>();
            final decodedStr = utf8.decode(_stripJsonbHeader(rawBytes));
            final decoded = jsonDecode(decodedStr);
            if (decoded is List) {
              parsedResimler = decoded
                  .where((e) => e != null)
                  .map((e) => e.toString())
                  .where((s) => s.isNotEmpty && s != 'null')
                  .toList();
            }
          } catch (_) {
            // ignore
          }
        } else {
          parsedResimler = resimlerRaw
              .where((e) => e != null)
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty && s != 'null')
              .toList();
        }
      } else if (resimlerRaw is String) {
        try {
          final decoded = jsonDecode(resimlerRaw);
          if (decoded is List) {
            parsedResimler = decoded
                .where((e) => e != null)
                .map((e) => e.toString())
                .where((s) => s.isNotEmpty && s != 'null')
                .toList();
          }
        } catch (_) {
          // ignore
        }
      } else {
        // Support postgres UndecodedBytes or byte-like values for JSONB
        try {
          final bytes = (resimlerRaw as dynamic).bytes;
          if (bytes is List<int>) {
            final decodedStr = utf8.decode(_stripJsonbHeader(bytes));
            final decoded = jsonDecode(decodedStr);
            if (decoded is List) {
              parsedResimler = decoded
                  .where((e) => e != null)
                  .map((e) => e.toString())
                  .where((s) => s.isNotEmpty && s != 'null')
                  .toList();
            }
          }
        } catch (_) {
          // ignore
        }
      }
    }

    return UrunModel(
      id: map['id'] as int,
      kod: map['kod'] as String,
      ad: map['ad'] as String,
      birim: map['birim'] as String? ?? 'Adet',
      alisFiyati: _parseDouble(map['alis_fiyati']),
      satisFiyati1: _parseDouble(map['satis_fiyati_1']),
      satisFiyati2: _parseDouble(map['satis_fiyati_2']),
      satisFiyati3: _parseDouble(map['satis_fiyati_3']),
      kdvOrani: _parseDouble(map['kdv_orani']),
      stok: _parseDouble(map['stok']),
      erkenUyariMiktari: _parseDouble(map['erken_uyari_miktari']),
      grubu: map['grubu'] as String? ?? '',
      ozellikler: map['ozellikler'] as String? ?? '',
      barkod: map['barkod'] as String? ?? '',
      kullanici: map['kullanici'] as String? ?? '',
      resimUrl: map['resim_url'] as String?,
      resimler: parsedResimler,
      aktifMi: _parseBool(map['aktif_mi']),
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] is DateTime
          ? map['created_at'] as DateTime
          : (map['created_at'] != null
                ? DateTime.tryParse(map['created_at'].toString())
                : null),
      matchedInHidden: map['matched_in_hidden'] == true,
      cihazlar:
          (map['cihazlar'] as List<dynamic>?)
              ?.map((e) => CihazModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  // Mock data generator
  static List<UrunModel> ornekVeriler() {
    return [
      const UrunModel(
        id: 1,
        kod: 'U001',
        ad: 'Salkım Domates (Yerli Üretim)',
        birim: 'Kg',
        alisFiyati: 20.00,
        satisFiyati1: 25.50,
        satisFiyati2: 24.00,
        satisFiyati3: 23.50,
        kdvOrani: 1,
        stok: 1500.0,
        erkenUyariMiktari: 100.0,
        grubu: 'Sebze',
        ozellikler: 'Taze, Yerli',
        barkod: '869000000001',
        kullanici: 'Ahmet Yılmaz',
        resimUrl: null,
        resimler: [],
        aktifMi: true,
      ),
      const UrunModel(
        id: 2,
        kod: 'U002',
        ad: 'Çengelköy Salatalık',
        birim: 'Kg',
        alisFiyati: 15.00,
        satisFiyati1: 18.90,
        satisFiyati2: 18.00,
        satisFiyati3: 17.50,
        kdvOrani: 1,
        stok: 850.0,
        erkenUyariMiktari: 50.0,
        grubu: 'Sebze',
        ozellikler: 'Çıtır, Taze',
        barkod: '869000000002',
        kullanici: 'Mehmet Demir',
        resimUrl: null,
        resimler: [],
        aktifMi: true,
      ),
      const UrunModel(
        id: 3,
        kod: 'U003',
        ad: 'Köy Biberi',
        birim: 'Kg',
        alisFiyati: 28.00,
        satisFiyati1: 35.00,
        satisFiyati2: 33.50,
        satisFiyati3: 32.00,
        kdvOrani: 1,
        stok: 450.0,
        erkenUyariMiktari: 40.0,
        grubu: 'Sebze',
        ozellikler: 'Acı, Yeşil',
        barkod: '869000000003',
        kullanici: 'Ayşe Kaya',
        resimUrl: null,
        resimler: [],
        aktifMi: true,
      ),
      const UrunModel(
        id: 4,
        kod: 'U004',
        ad: 'Kemer Patlıcan',
        birim: 'Kg',
        alisFiyati: 18.00,
        satisFiyati1: 22.00,
        satisFiyati2: 21.00,
        satisFiyati3: 20.00,
        kdvOrani: 1,
        stok: 600.0,
        erkenUyariMiktari: 60.0,
        grubu: 'Sebze',
        ozellikler: 'Kemer, Taze',
        barkod: '869000000004',
        kullanici: 'Fatma Çelik',
        resimUrl: null,
        resimler: [],
        aktifMi: false,
      ),
      const UrunModel(
        id: 5,
        kod: 'U005',
        ad: 'Kuru Soğan',
        birim: 'Kg',
        alisFiyati: 8.00,
        satisFiyati1: 12.50,
        satisFiyati2: 11.50,
        satisFiyati3: 11.00,
        kdvOrani: 1,
        stok: 3000.0,
        erkenUyariMiktari: 200.0,
        grubu: 'Sebze',
        ozellikler: 'Kuru, Dayanıklı',
        barkod: '869000000005',
        kullanici: 'Ali Vural',
        resimUrl: null,
        resimler: [],
        aktifMi: true,
      ),
    ];
  }
}
