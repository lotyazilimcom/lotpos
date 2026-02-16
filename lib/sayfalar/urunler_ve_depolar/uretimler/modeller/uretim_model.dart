import 'dart:convert';

class UretimModel {
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

  const UretimModel({
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
  });

  UretimModel copyWith({
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
  }) {
    return UretimModel(
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
    if (bytes[0] == 1 && bytes.length > 1) {
      final b1 = bytes[1];
      if (b1 == 91 /* [ */ || b1 == 123 /* { */) {
        return bytes.sublist(1);
      }
    }
    return bytes;
  }

  factory UretimModel.fromMap(Map<String, dynamic> map) {
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

    return UretimModel(
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
    );
  }

  // Mock data generator
  static List<UretimModel> ornekVeriler() {
    return [
      const UretimModel(
        id: 1,
        kod: 'UR001',
        ad: 'Karışık Salata',
        birim: 'Porsiyon',
        alisFiyati: 15.00,
        satisFiyati1: 35.50,
        satisFiyati2: 32.00,
        satisFiyati3: 30.00,
        kdvOrani: 8,
        stok: 50.0,
        erkenUyariMiktari: 10.0,
        grubu: 'Salata',
        ozellikler: 'Taze, Günlük',
        barkod: '869100000001',
        kullanici: 'Ahmet Yılmaz',
        resimUrl: null,
        resimler: [],
        aktifMi: true,
      ),
      const UretimModel(
        id: 2,
        kod: 'UR002',
        ad: 'Tavuk Döner',
        birim: 'Porsiyon',
        alisFiyati: 25.00,
        satisFiyati1: 65.00,
        satisFiyati2: 60.00,
        satisFiyati3: 55.00,
        kdvOrani: 8,
        stok: 100.0,
        erkenUyariMiktari: 20.0,
        grubu: 'Et Ürünleri',
        ozellikler: 'Taze, Günlük',
        barkod: '869100000002',
        kullanici: 'Mehmet Demir',
        resimUrl: null,
        resimler: [],
        aktifMi: true,
      ),
    ];
  }
}
