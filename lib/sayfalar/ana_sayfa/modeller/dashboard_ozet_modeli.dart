/// Lot Pos V1.0 — Dashboard Özet Veri Modeli
/// Tüm KPI ve analitik verileri tek bir modelde toplar.
class DashboardOzet {
  // ─── Hero KPI ───
  final double toplamKasa;
  final double toplamBanka;
  final double toplamStokDegeri;
  final double netCariBakiye;
  final double bugunNetSatis;

  // ─── Sparkline (7 günlük) ───
  final List<double> kasaSparkline;
  final List<double> bankaSparkline;
  final List<double> stokSparkline;
  final List<double> cariSparkline;
  final List<double> satisSparkline;

  // ─── Analitik Grafik (30 günlük) ───
  final List<GunlukTutar> satis30Gun;
  final List<GunlukTutar> alis30Gun;

  // ─── Risk ───
  final List<KritikStokItem> kritikStoklar;
  final List<YaklasanVade> yaklasanVadeler;

  // ─── Orta Bant Finansal ───
  final double krediKartiBakiyesi;
  final double bekleyenCekler;
  final double bekleyenSenetler;
  final int aktifSiparisler;
  final int aktifTeklifler;
  final double buAykiGiderler;

  // ─── Son İşlemler ───
  final List<SonIslem> sonIslemler;

  // ─── Değişim Oranları (önceki döneme kıyasla %) ───
  final double kasaDegisimYuzde;
  final double bankaDegisimYuzde;
  final double stokDegisimYuzde;
  final double cariDegisimYuzde;
  final double satisDegisimYuzde;

  const DashboardOzet({
    this.toplamKasa = 0,
    this.toplamBanka = 0,
    this.toplamStokDegeri = 0,
    this.netCariBakiye = 0,
    this.bugunNetSatis = 0,
    this.kasaSparkline = const [],
    this.bankaSparkline = const [],
    this.stokSparkline = const [],
    this.cariSparkline = const [],
    this.satisSparkline = const [],
    this.satis30Gun = const [],
    this.alis30Gun = const [],
    this.kritikStoklar = const [],
    this.yaklasanVadeler = const [],
    this.krediKartiBakiyesi = 0,
    this.bekleyenCekler = 0,
    this.bekleyenSenetler = 0,
    this.aktifSiparisler = 0,
    this.aktifTeklifler = 0,
    this.buAykiGiderler = 0,
    this.sonIslemler = const [],
    this.kasaDegisimYuzde = 0,
    this.bankaDegisimYuzde = 0,
    this.stokDegisimYuzde = 0,
    this.cariDegisimYuzde = 0,
    this.satisDegisimYuzde = 0,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'toplamKasa': toplamKasa,
      'toplamBanka': toplamBanka,
      'toplamStokDegeri': toplamStokDegeri,
      'netCariBakiye': netCariBakiye,
      'bugunNetSatis': bugunNetSatis,
      'kasaSparkline': kasaSparkline,
      'bankaSparkline': bankaSparkline,
      'stokSparkline': stokSparkline,
      'cariSparkline': cariSparkline,
      'satisSparkline': satisSparkline,
      'satis30Gun': satis30Gun.map((e) => e.toMap()).toList(),
      'alis30Gun': alis30Gun.map((e) => e.toMap()).toList(),
      'kritikStoklar': kritikStoklar.map((e) => e.toMap()).toList(),
      'yaklasanVadeler': yaklasanVadeler.map((e) => e.toMap()).toList(),
      'krediKartiBakiyesi': krediKartiBakiyesi,
      'bekleyenCekler': bekleyenCekler,
      'bekleyenSenetler': bekleyenSenetler,
      'aktifSiparisler': aktifSiparisler,
      'aktifTeklifler': aktifTeklifler,
      'buAykiGiderler': buAykiGiderler,
      'sonIslemler': sonIslemler.map((e) => e.toMap()).toList(),
      'kasaDegisimYuzde': kasaDegisimYuzde,
      'bankaDegisimYuzde': bankaDegisimYuzde,
      'stokDegisimYuzde': stokDegisimYuzde,
      'cariDegisimYuzde': cariDegisimYuzde,
      'satisDegisimYuzde': satisDegisimYuzde,
    };
  }

  factory DashboardOzet.fromMap(Map<String, dynamic> map) {
    return DashboardOzet(
      toplamKasa: _toDouble(map['toplamKasa']),
      toplamBanka: _toDouble(map['toplamBanka']),
      toplamStokDegeri: _toDouble(map['toplamStokDegeri']),
      netCariBakiye: _toDouble(map['netCariBakiye']),
      bugunNetSatis: _toDouble(map['bugunNetSatis']),
      kasaSparkline: _toDoubleList(map['kasaSparkline']),
      bankaSparkline: _toDoubleList(map['bankaSparkline']),
      stokSparkline: _toDoubleList(map['stokSparkline']),
      cariSparkline: _toDoubleList(map['cariSparkline']),
      satisSparkline: _toDoubleList(map['satisSparkline']),
      satis30Gun: _toModelList<GunlukTutar>(
        map['satis30Gun'],
        GunlukTutar.fromMap,
      ),
      alis30Gun: _toModelList<GunlukTutar>(
        map['alis30Gun'],
        GunlukTutar.fromMap,
      ),
      kritikStoklar: _toModelList<KritikStokItem>(
        map['kritikStoklar'],
        KritikStokItem.fromMap,
      ),
      yaklasanVadeler: _toModelList<YaklasanVade>(
        map['yaklasanVadeler'],
        YaklasanVade.fromMap,
      ),
      krediKartiBakiyesi: _toDouble(map['krediKartiBakiyesi']),
      bekleyenCekler: _toDouble(map['bekleyenCekler']),
      bekleyenSenetler: _toDouble(map['bekleyenSenetler']),
      aktifSiparisler: _toInt(map['aktifSiparisler']),
      aktifTeklifler: _toInt(map['aktifTeklifler']),
      buAykiGiderler: _toDouble(map['buAykiGiderler']),
      sonIslemler: _toModelList<SonIslem>(map['sonIslemler'], SonIslem.fromMap),
      kasaDegisimYuzde: _toDouble(map['kasaDegisimYuzde']),
      bankaDegisimYuzde: _toDouble(map['bankaDegisimYuzde']),
      stokDegisimYuzde: _toDouble(map['stokDegisimYuzde']),
      cariDegisimYuzde: _toDouble(map['cariDegisimYuzde']),
      satisDegisimYuzde: _toDouble(map['satisDegisimYuzde']),
    );
  }
}

/// 30 günlük grafik verisi
class GunlukTutar {
  final DateTime tarih;
  final double tutar;

  const GunlukTutar({required this.tarih, required this.tutar});

  Map<String, dynamic> toMap() => <String, dynamic>{
        'tarih': tarih.toIso8601String(),
        'tutar': tutar,
      };

  factory GunlukTutar.fromMap(Map<String, dynamic> map) => GunlukTutar(
        tarih:
            DateTime.tryParse(map['tarih']?.toString() ?? '') ?? DateTime.now(),
        tutar: _toDouble(map['tutar']),
      );
}

/// Kritik stok uyarısı
class KritikStokItem {
  final int id;
  final String urunAdi;
  final double mevcutStok;
  final String birim;

  const KritikStokItem({
    required this.id,
    required this.urunAdi,
    required this.mevcutStok,
    this.birim = 'Adet',
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'urunAdi': urunAdi,
        'mevcutStok': mevcutStok,
        'birim': birim,
      };

  factory KritikStokItem.fromMap(Map<String, dynamic> map) => KritikStokItem(
        id: _toInt(map['id']),
        urunAdi: map['urunAdi']?.toString() ?? '',
        mevcutStok: _toDouble(map['mevcutStok']),
        birim: (map['birim']?.toString() ?? '').trim().isEmpty
            ? 'Adet'
            : map['birim'].toString(),
      );
}

/// Yaklaşan vade (Çek/Senet)
class YaklasanVade {
  final int id;
  final String tur; // 'Çek' veya 'Senet'
  final String aciklama;
  final double tutar;
  final DateTime vadeTarihi;
  final String cariAdi;

  const YaklasanVade({
    required this.id,
    required this.tur,
    required this.aciklama,
    required this.tutar,
    required this.vadeTarihi,
    this.cariAdi = '',
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'tur': tur,
        'aciklama': aciklama,
        'tutar': tutar,
        'vadeTarihi': vadeTarihi.toIso8601String(),
        'cariAdi': cariAdi,
      };

  factory YaklasanVade.fromMap(Map<String, dynamic> map) => YaklasanVade(
        id: _toInt(map['id']),
        tur: map['tur']?.toString() ?? '',
        aciklama: map['aciklama']?.toString() ?? '',
        tutar: _toDouble(map['tutar']),
        vadeTarihi: DateTime.tryParse(map['vadeTarihi']?.toString() ?? '') ??
            DateTime.now(),
        cariAdi: map['cariAdi']?.toString() ?? '',
      );
}

/// Son işlem kaydı
class SonIslem {
  final int id;
  final String tur; // 'satis', 'alis', 'tahsilat', 'odeme', 'cek', 'senet'
  final String aciklama;
  final double tutar;
  final DateTime tarih;
  final String cariAdi;

  const SonIslem({
    required this.id,
    required this.tur,
    required this.aciklama,
    required this.tutar,
    required this.tarih,
    this.cariAdi = '',
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'tur': tur,
        'aciklama': aciklama,
        'tutar': tutar,
        'tarih': tarih.toIso8601String(),
        'cariAdi': cariAdi,
      };

  factory SonIslem.fromMap(Map<String, dynamic> map) => SonIslem(
        id: _toInt(map['id']),
        tur: map['tur']?.toString() ?? 'tahsilat',
        aciklama: map['aciklama']?.toString() ?? '',
        tutar: _toDouble(map['tutar']),
        tarih:
            DateTime.tryParse(map['tarih']?.toString() ?? '') ?? DateTime.now(),
        cariAdi: map['cariAdi']?.toString() ?? '',
      );
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<double> _toDoubleList(dynamic raw) {
  if (raw is! List) return const <double>[];
  return raw.map(_toDouble).toList(growable: false);
}

List<T> _toModelList<T>(
  dynamic raw,
  T Function(Map<String, dynamic> map) factory,
) {
  if (raw is! List) return List<T>.empty(growable: false);
  return raw
      .whereType<Map>()
      .map((item) => factory(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}
