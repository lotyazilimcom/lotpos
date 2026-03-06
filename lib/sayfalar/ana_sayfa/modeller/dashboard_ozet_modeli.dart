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
}

/// 30 günlük grafik verisi
class GunlukTutar {
  final DateTime tarih;
  final double tutar;

  const GunlukTutar({required this.tarih, required this.tutar});
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
}
