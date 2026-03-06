/// Gider (Expense) veri modeli
///
/// Bu model, gider kayıtlarını temsil eder ve AI resim tarama
/// özelliği için gerekli alanları içerir.
class GiderModel {
  final int id;
  final String kod;
  final String baslik;
  final double tutar;
  final String paraBirimi;
  final DateTime tarih;
  final String odemeDurumu; // 'Beklemede' | 'Ödendi'
  final String kategori;
  final String aciklama;
  final String not;
  final List<String> resimler;
  final List<GiderKalemi> kalemler;
  final bool aiIslenmisMi;
  final Map<String, dynamic>? aiVerileri;
  final bool aktifMi;
  final DateTime olusturmaTarihi;
  final DateTime? guncellemeTarihi;
  final String kullanici;
  final bool matchedInHidden; // Arama sadece detaylarda eşleştiyse true

  GiderModel({
    required this.id,
    required this.kod,
    required this.baslik,
    required this.tutar,
    this.paraBirimi = 'TRY',
    required this.tarih,
    this.odemeDurumu = 'Beklemede',
    required this.kategori,
    this.aciklama = '',
    this.not = '',
    this.resimler = const [],
    this.kalemler = const [],
    this.aiIslenmisMi = false,
    this.aiVerileri,
    this.aktifMi = true,
    required this.olusturmaTarihi,
    this.guncellemeTarihi,
    this.kullanici = '',
    this.matchedInHidden = false,
  });

  /// copyWith - Modelin kopyasını oluşturur
  GiderModel copyWith({
    int? id,
    String? kod,
    String? baslik,
    double? tutar,
    String? paraBirimi,
    DateTime? tarih,
    String? odemeDurumu,
    String? kategori,
    String? aciklama,
    String? not,
    List<String>? resimler,
    List<GiderKalemi>? kalemler,
    bool? aiIslenmisMi,
    Map<String, dynamic>? aiVerileri,
    bool? aktifMi,
    DateTime? olusturmaTarihi,
    DateTime? guncellemeTarihi,
    String? kullanici,
    bool? matchedInHidden,
  }) {
    return GiderModel(
      id: id ?? this.id,
      kod: kod ?? this.kod,
      baslik: baslik ?? this.baslik,
      tutar: tutar ?? this.tutar,
      paraBirimi: paraBirimi ?? this.paraBirimi,
      tarih: tarih ?? this.tarih,
      odemeDurumu: odemeDurumu ?? this.odemeDurumu,
      kategori: kategori ?? this.kategori,
      aciklama: aciklama ?? this.aciklama,
      not: not ?? this.not,
      resimler: resimler ?? this.resimler,
      kalemler: kalemler ?? this.kalemler,
      aiIslenmisMi: aiIslenmisMi ?? this.aiIslenmisMi,
      aiVerileri: aiVerileri ?? this.aiVerileri,
      aktifMi: aktifMi ?? this.aktifMi,
      olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
      guncellemeTarihi: guncellemeTarihi ?? this.guncellemeTarihi,
      kullanici: kullanici ?? this.kullanici,
      matchedInHidden: matchedInHidden ?? this.matchedInHidden,
    );
  }

  /// JSON'dan model oluşturma
  factory GiderModel.fromJson(Map<String, dynamic> json) {
    return GiderModel(
      id: json['id'] as int,
      kod: json['kod'] as String? ?? '',
      baslik: json['baslik'] as String? ?? '',
      tutar: (json['tutar'] as num?)?.toDouble() ?? 0.0,
      paraBirimi: json['para_birimi'] as String? ?? 'TRY',
      tarih: json['tarih'] != null
          ? DateTime.parse(json['tarih'] as String)
          : DateTime.now(),
      odemeDurumu: json['odeme_durumu'] as String? ?? 'Beklemede',
      kategori: json['kategori'] as String? ?? '',
      aciklama: json['aciklama'] as String? ?? '',
      not: json['not'] as String? ?? '',
      resimler:
          (json['resimler'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      kalemler:
          (json['kalemler'] as List<dynamic>?)
              ?.map((e) => GiderKalemi.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      aiIslenmisMi: json['ai_islenmis_mi'] as bool? ?? false,
      aiVerileri: json['ai_verileri'] as Map<String, dynamic>?,
      aktifMi: json['aktif_mi'] as bool? ?? true,
      olusturmaTarihi: json['olusturma_tarihi'] != null
          ? DateTime.parse(json['olusturma_tarihi'] as String)
          : DateTime.now(),
      guncellemeTarihi: json['guncelleme_tarihi'] != null
          ? DateTime.parse(json['guncelleme_tarihi'] as String)
          : null,
      kullanici: json['kullanici'] as String? ?? '',
      matchedInHidden: json['matched_in_hidden'] as bool? ?? false,
    );
  }

  /// Model'i JSON'a dönüştürme
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kod': kod,
      'baslik': baslik,
      'tutar': tutar,
      'para_birimi': paraBirimi,
      'tarih': tarih.toIso8601String(),
      'odeme_durumu': odemeDurumu,
      'kategori': kategori,
      'aciklama': aciklama,
      'not': not,
      'resimler': resimler,
      'kalemler': kalemler.map((e) => e.toJson()).toList(),
      'ai_islenmis_mi': aiIslenmisMi,
      'ai_verileri': aiVerileri,
      'aktif_mi': aktifMi,
      'olusturma_tarihi': olusturmaTarihi.toIso8601String(),
      'guncelleme_tarihi': guncellemeTarihi?.toIso8601String(),
      'kullanici': kullanici,
      'matched_in_hidden': matchedInHidden,
    };
  }

  /// Örnek veriler (test için)
  static List<GiderModel> ornekVeriler() {
    final now = DateTime.now();
    return [
      GiderModel(
        id: 1,
        kod: 'GD-001',
        baslik: 'Market Alışverişi',
        tutar: 450.00,
        tarih: now.subtract(const Duration(days: 1)),
        odemeDurumu: 'Ödendi',
        kategori: 'Market',
        aciklama: 'Haftalık market alışverişi',
        olusturmaTarihi: now,
        kullanici: 'admin',
      ),
      GiderModel(
        id: 2,
        kod: 'GD-002',
        baslik: 'Elektrik Faturası',
        tutar: 890.50,
        tarih: now.subtract(const Duration(days: 5)),
        odemeDurumu: 'Beklemede',
        kategori: 'Fatura',
        aciklama: 'Ocak ayı elektrik faturası',
        olusturmaTarihi: now,
        kullanici: 'admin',
      ),
      GiderModel(
        id: 3,
        kod: 'GD-003',
        baslik: 'Taksi Ücreti',
        tutar: 120.00,
        tarih: now.subtract(const Duration(days: 2)),
        odemeDurumu: 'Ödendi',
        kategori: 'Ulaşım',
        aciklama: 'Müşteri toplantısına gidiş',
        olusturmaTarihi: now,
        kullanici: 'admin',
        kalemler: [GiderKalemi(aciklama: 'Taksi', tutar: 120.00)],
      ),
    ];
  }

  /// Varsayılan kategoriler
  static List<String> varsayilanKategoriler() {
    return ['Market', 'Fatura', 'Ulaşım', 'Ofis', 'Diğer'];
  }

  /// Ödeme durumları
  static List<String> odemeDurumlari() {
    return ['Beklemede', 'Ödendi'];
  }

  @override
  String toString() {
    return 'GiderModel(id: $id, kod: $kod, baslik: $baslik, tutar: $tutar, '
        'odemeDurumu: $odemeDurumu, kategori: $kategori)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GiderModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class GiderKalemi {
  final String aciklama;
  final double tutar;
  final String not;

  GiderKalemi({required this.aciklama, required this.tutar, this.not = ''});

  factory GiderKalemi.fromJson(Map<String, dynamic> json) {
    return GiderKalemi(
      aciklama: json['aciklama'] as String? ?? '',
      tutar: (json['tutar'] as num?)?.toDouble() ?? 0.0,
      not: json['not'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'aciklama': aciklama, 'tutar': tutar, 'not': not};
  }
}
