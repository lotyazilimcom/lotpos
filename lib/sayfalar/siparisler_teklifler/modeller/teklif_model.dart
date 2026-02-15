class TeklifModel {
  final int id;
  final String tur;
  final String durum;
  final DateTime tarih;
  final int? cariId;
  final String? cariKod;
  final String? cariAdi;
  final String ilgiliHesapAdi;
  final double tutar;
  final double kur;
  final String aciklama;
  final String aciklama2;
  final DateTime? gecerlilikTarihi;
  final String paraBirimi;
  final String kullanici;
  final String? integrationRef;
  final String? quoteNo;
  final List<TeklifUrunModel> urunler;

  final bool matchedInHidden;

  const TeklifModel({
    required this.id,
    required this.tur,
    required this.durum,
    required this.tarih,
    this.cariId,
    this.cariKod,
    this.cariAdi,
    required this.ilgiliHesapAdi,
    required this.tutar,
    required this.kur,
    required this.aciklama,
    required this.aciklama2,
    this.gecerlilikTarihi,
    required this.paraBirimi,
    required this.kullanici,
    this.integrationRef,
    this.quoteNo,
    this.urunler = const [],
    this.matchedInHidden = false,
  });

  TeklifModel copyWith({
    int? id,
    String? tur,
    String? durum,
    DateTime? tarih,
    int? cariId,
    String? cariKod,
    String? cariAdi,
    String? ilgiliHesapAdi,
    double? tutar,
    double? kur,
    String? aciklama,
    String? aciklama2,
    DateTime? gecerlilikTarihi,
    String? paraBirimi,
    String? kullanici,
    String? integrationRef,
    String? quoteNo,
    List<TeklifUrunModel>? urunler,
    bool? matchedInHidden,
  }) {
    return TeklifModel(
      id: id ?? this.id,
      tur: tur ?? this.tur,
      durum: durum ?? this.durum,
      tarih: tarih ?? this.tarih,
      cariId: cariId ?? this.cariId,
      cariKod: cariKod ?? this.cariKod,
      cariAdi: cariAdi ?? this.cariAdi,
      ilgiliHesapAdi: ilgiliHesapAdi ?? this.ilgiliHesapAdi,
      tutar: tutar ?? this.tutar,
      kur: kur ?? this.kur,
      aciklama: aciklama ?? this.aciklama,
      aciklama2: aciklama2 ?? this.aciklama2,
      gecerlilikTarihi: gecerlilikTarihi ?? this.gecerlilikTarihi,
      paraBirimi: paraBirimi ?? this.paraBirimi,
      kullanici: kullanici ?? this.kullanici,
      integrationRef: integrationRef ?? this.integrationRef,
      quoteNo: quoteNo ?? this.quoteNo,
      urunler: urunler ?? this.urunler,
      matchedInHidden: matchedInHidden ?? this.matchedInHidden,
    );
  }
}

class TeklifUrunModel {
  final int id;
  final int urunId;
  final String urunKodu;
  final String urunAdi;
  final String barkod;
  final int? depoId;
  final String depoAdi;
  final double kdvOrani;
  final double miktar;
  final String birim;
  final double birimFiyati;
  final double toplamFiyati;
  final String paraBirimi;
  final String kdvDurumu;
  final double iskonto;

  const TeklifUrunModel({
    required this.id,
    required this.urunId,
    required this.urunKodu,
    required this.urunAdi,
    required this.barkod,
    this.depoId,
    required this.depoAdi,
    required this.kdvOrani,
    required this.miktar,
    required this.birim,
    required this.birimFiyati,
    required this.toplamFiyati,
    required this.paraBirimi,
    required this.kdvDurumu,
    required this.iskonto,
  });

  TeklifUrunModel copyWith({
    int? id,
    int? urunId,
    String? urunKodu,
    String? urunAdi,
    String? barkod,
    int? depoId,
    String? depoAdi,
    double? kdvOrani,
    double? miktar,
    String? birim,
    double? birimFiyati,
    double? toplamFiyati,
    String? paraBirimi,
    String? kdvDurumu,
    double? iskonto,
  }) {
    return TeklifUrunModel(
      id: id ?? this.id,
      urunId: urunId ?? this.urunId,
      urunKodu: urunKodu ?? this.urunKodu,
      urunAdi: urunAdi ?? this.urunAdi,
      barkod: barkod ?? this.barkod,
      depoId: depoId ?? this.depoId,
      depoAdi: depoAdi ?? this.depoAdi,
      kdvOrani: kdvOrani ?? this.kdvOrani,
      miktar: miktar ?? this.miktar,
      birim: birim ?? this.birim,
      birimFiyati: birimFiyati ?? this.birimFiyati,
      toplamFiyati: toplamFiyati ?? this.toplamFiyati,
      paraBirimi: paraBirimi ?? this.paraBirimi,
      kdvDurumu: kdvDurumu ?? this.kdvDurumu,
      iskonto: iskonto ?? this.iskonto,
    );
  }
}
