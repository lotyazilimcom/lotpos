import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../servisler/bankalar_veritabani_servisi.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../servisler/cekler_veritabani_servisi.dart';
import '../../servisler/giderler_veritabani_servisi.dart';
import '../../servisler/kasalar_veritabani_servisi.dart';
import '../../servisler/kredi_kartlari_veritabani_servisi.dart';
import '../../servisler/oturum_servisi.dart';
import '../../servisler/senetler_veritabani_servisi.dart';
import '../../servisler/siparisler_veritabani_servisi.dart';
import '../../servisler/teklifler_veritabani_servisi.dart';
import '../../servisler/urunler_veritabani_servisi.dart';
import '../../servisler/veritabani_havuzu.dart';
import 'modeller/dashboard_ozet_modeli.dart';

/// Ana sayfa için tüm canlı verileri tek noktada toplayan servis.
/// Yalnızca dashboard ihtiyaçları için özet SQL sorguları çalıştırır.
class AnaSayfaServisi {
  static final AnaSayfaServisi _instance = AnaSayfaServisi._internal();
  factory AnaSayfaServisi() => _instance;
  AnaSayfaServisi._internal();

  static const String _defaultCompanyId = 'lospos2026';
  static const String _prefsCachePrefix = 'dashboard_cache_v3::';
  static final Map<String, Future<void>> _hazirlikFutureleri =
      <String, Future<void>>{};
  static final Map<String, _DashboardCacheKaydi> _dashboardCache =
      <String, _DashboardCacheKaydi>{};

  DashboardOzet? cacheliDashboardVerisiniGetir({
    String tarihFiltresi = 'bugun',
  }) {
    return _dashboardCache[_aktifCacheAnahtari(tarihFiltresi)]?.ozet;
  }

  DateTime? cacheZamaniniGetir({String tarihFiltresi = 'bugun'}) {
    return _dashboardCache[_aktifCacheAnahtari(tarihFiltresi)]?.yuklenmeAni;
  }

  Future<DashboardOzet?> diskCacheliDashboardVerisiniGetir({
    String tarihFiltresi = 'bugun',
  }) async {
    final String cacheAnahtari = _aktifCacheAnahtari(tarihFiltresi);
    final _DashboardCacheKaydi? bellekKaydi = _dashboardCache[cacheAnahtari];
    if (bellekKaydi != null) {
      return bellekKaydi.ozet;
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('$_prefsCachePrefix$cacheAnahtari');
      if (raw == null || raw.trim().isEmpty) return null;

      final Map<String, dynamic> payload = Map<String, dynamic>.from(
        jsonDecode(raw) as Map,
      );
      final Map<String, dynamic> ozetMap = Map<String, dynamic>.from(
        (payload['ozet'] as Map?) ?? payload,
      );
      final DashboardOzet ozet = DashboardOzet.fromMap(ozetMap);
      final DateTime yuklenmeAni =
          DateTime.tryParse(payload['yuklenmeAni']?.toString() ?? '') ??
          DateTime.now();

      _dashboardCache[cacheAnahtari] = _DashboardCacheKaydi(
        ozet: ozet,
        yuklenmeAni: yuklenmeAni,
      );
      return ozet;
    } catch (e) {
      debugPrint('AnaSayfaServisi: disk cache okuma uyarisi: $e');
      return null;
    }
  }

  void hazirliklariArkaPlandaBaslat() {
    unawaited(_hazirliklariYap());
  }

  Future<DashboardOzet> dashboardHizliVerileriniGetir({
    String tarihFiltresi = 'bugun',
  }) async {
    hazirliklariArkaPlandaBaslat();

    final String aktifVeritabani = OturumServisi().aktifVeritabaniAdi;
    final String companyId = aktifVeritabani.trim().isEmpty
        ? _defaultCompanyId
        : aktifVeritabani;
    final Pool pool = await VeritabaniHavuzu().havuzAl(
      database: aktifVeritabani,
    );

    final DateTime now = DateTime.now();
    final _PeriyotPenceresi seciliPeriyot = _periyotPenceresiOlustur(
      now,
      tarihFiltresi,
    );
    final _PeriyotPenceresi oncekiPeriyot = _oncekiPeriyot(seciliPeriyot);
    final _PeriyotPenceresi bosSparklinePeriyodu = _PeriyotPenceresi(
      baslangic: DateTime.fromMillisecondsSinceEpoch(0),
      bitis: DateTime.fromMillisecondsSinceEpoch(0),
    );

    final List<dynamic> sonuc = await Future.wait<dynamic>([
      _guvenliGetir<_DashboardMetrik>(
        etiket: 'hizli kasa metrikleri',
        fallback: const _DashboardMetrik(),
        islem: () => _kasaMetrikleriniGetir(
          pool: pool,
          companyId: companyId,
          seciliPeriyot: seciliPeriyot,
          sparklinePeriyodu: bosSparklinePeriyodu,
          includeSparkline: false,
        ),
      ),
      _guvenliGetir<_DashboardMetrik>(
        etiket: 'hizli banka metrikleri',
        fallback: const _DashboardMetrik(),
        islem: () => _bankaMetrikleriniGetir(
          pool: pool,
          companyId: companyId,
          seciliPeriyot: seciliPeriyot,
          sparklinePeriyodu: bosSparklinePeriyodu,
          includeSparkline: false,
        ),
      ),
      _guvenliGetir<_DashboardMetrik>(
        etiket: 'hizli stok metrikleri',
        fallback: const _DashboardMetrik(),
        islem: () => _stokMetrikleriniGetir(
          pool: pool,
          seciliPeriyot: seciliPeriyot,
          sparklinePeriyodu: bosSparklinePeriyodu,
          includeSparkline: false,
        ),
      ),
      _guvenliGetir<_DashboardMetrik>(
        etiket: 'hizli cari metrikleri',
        fallback: const _DashboardMetrik(),
        islem: () => _cariMetrikleriniGetir(
          pool: pool,
          seciliPeriyot: seciliPeriyot,
          sparklinePeriyodu: bosSparklinePeriyodu,
          includeSparkline: false,
        ),
      ),
      _guvenliGetir<_DashboardMetrik>(
        etiket: 'hizli satis metrikleri',
        fallback: const _DashboardMetrik(),
        islem: () => _satisMetrikleriniGetir(
          pool: pool,
          seciliPeriyot: seciliPeriyot,
          oncekiPeriyot: oncekiPeriyot,
          sparklinePeriyodu: bosSparklinePeriyodu,
          includeSparkline: false,
        ),
      ),
      _guvenliGetir<_FinansOzet>(
        etiket: 'hizli finans ozeti',
        fallback: const _FinansOzet(),
        islem: () =>
            _finansOzetiniGetir(pool: pool, companyId: companyId, now: now),
      ),
    ]);

    final _DashboardMetrik kasa = sonuc[0] as _DashboardMetrik;
    final _DashboardMetrik banka = sonuc[1] as _DashboardMetrik;
    final _DashboardMetrik stok = sonuc[2] as _DashboardMetrik;
    final _DashboardMetrik cari = sonuc[3] as _DashboardMetrik;
    final _DashboardMetrik satis = sonuc[4] as _DashboardMetrik;
    final _FinansOzet finans = sonuc[5] as _FinansOzet;

    return DashboardOzet(
      toplamKasa: kasa.mevcutDeger,
      toplamBanka: banka.mevcutDeger,
      toplamStokDegeri: stok.mevcutDeger,
      netCariBakiye: cari.mevcutDeger,
      bugunNetSatis: satis.mevcutDeger,
      krediKartiBakiyesi: finans.krediKartiBakiyesi,
      bekleyenCekler: finans.bekleyenCekler,
      bekleyenSenetler: finans.bekleyenSenetler,
      aktifSiparisler: finans.aktifSiparisler,
      aktifTeklifler: finans.aktifTeklifler,
      buAykiGiderler: finans.buAykiGiderler,
      kasaDegisimYuzde: _degisimYuzdesi(
        mevcut: kasa.mevcutDeger,
        onceki: kasa.oncekiDeger,
      ),
      bankaDegisimYuzde: _degisimYuzdesi(
        mevcut: banka.mevcutDeger,
        onceki: banka.oncekiDeger,
      ),
      stokDegisimYuzde: _degisimYuzdesi(
        mevcut: stok.mevcutDeger,
        onceki: stok.oncekiDeger,
      ),
      cariDegisimYuzde: _degisimYuzdesi(
        mevcut: cari.mevcutDeger,
        onceki: cari.oncekiDeger,
      ),
      satisDegisimYuzde: _degisimYuzdesi(
        mevcut: satis.mevcutDeger,
        onceki: satis.oncekiDeger,
      ),
    );
  }

  Future<DashboardOzet> dashboardVerileriniGetir({
    String tarihFiltresi = 'bugun',
  }) async {
    await _hazirliklariYap();

    final String aktifVeritabani = OturumServisi().aktifVeritabaniAdi;
    final String companyId = aktifVeritabani.trim().isEmpty
        ? _defaultCompanyId
        : aktifVeritabani;
    final Pool pool = await VeritabaniHavuzu().havuzAl(
      database: aktifVeritabani,
    );

    final DateTime now = DateTime.now();
    final _PeriyotPenceresi seciliPeriyot = _periyotPenceresiOlustur(
      now,
      tarihFiltresi,
    );
    final _PeriyotPenceresi oncekiPeriyot = _oncekiPeriyot(seciliPeriyot);
    final _PeriyotPenceresi sparklinePeriyodu = _PeriyotPenceresi(
      baslangic: _gunBaslangici(now.subtract(const Duration(days: 6))),
      bitis: _gunBaslangici(now).add(const Duration(days: 1)),
    );
    final _PeriyotPenceresi grafikPeriyodu = _PeriyotPenceresi(
      baslangic: _gunBaslangici(now.subtract(const Duration(days: 29))),
      bitis: _gunBaslangici(now).add(const Duration(days: 1)),
    );

    final Future<_DashboardMetrik> kasaFuture = _guvenliGetir<_DashboardMetrik>(
      etiket: 'kasa metrikleri',
      fallback: const _DashboardMetrik(),
      islem: () => _kasaMetrikleriniGetir(
        pool: pool,
        companyId: companyId,
        seciliPeriyot: seciliPeriyot,
        sparklinePeriyodu: sparklinePeriyodu,
      ),
    );

    final Future<_DashboardMetrik> bankaFuture =
        _guvenliGetir<_DashboardMetrik>(
          etiket: 'banka metrikleri',
          fallback: const _DashboardMetrik(),
          islem: () => _bankaMetrikleriniGetir(
            pool: pool,
            companyId: companyId,
            seciliPeriyot: seciliPeriyot,
            sparklinePeriyodu: sparklinePeriyodu,
          ),
        );

    final Future<_DashboardMetrik> stokFuture = _guvenliGetir<_DashboardMetrik>(
      etiket: 'stok metrikleri',
      fallback: const _DashboardMetrik(),
      islem: () => _stokMetrikleriniGetir(
        pool: pool,
        seciliPeriyot: seciliPeriyot,
        sparklinePeriyodu: sparklinePeriyodu,
      ),
    );

    final Future<_DashboardMetrik> cariFuture = _guvenliGetir<_DashboardMetrik>(
      etiket: 'cari metrikleri',
      fallback: const _DashboardMetrik(),
      islem: () => _cariMetrikleriniGetir(
        pool: pool,
        seciliPeriyot: seciliPeriyot,
        sparklinePeriyodu: sparklinePeriyodu,
      ),
    );

    final Future<_DashboardMetrik> satisFuture =
        _guvenliGetir<_DashboardMetrik>(
          etiket: 'satis metrikleri',
          fallback: const _DashboardMetrik(),
          islem: () => _satisMetrikleriniGetir(
            pool: pool,
            seciliPeriyot: seciliPeriyot,
            oncekiPeriyot: oncekiPeriyot,
            sparklinePeriyodu: sparklinePeriyodu,
          ),
        );

    final Future<_GrafikVerisi> grafikFuture = _guvenliGetir<_GrafikVerisi>(
      etiket: 'grafik verileri',
      fallback: const _GrafikVerisi(),
      islem: () =>
          _grafikVerileriniGetir(pool: pool, grafikPeriyodu: grafikPeriyodu),
    );

    final Future<_RiskVerisi> riskFuture = _guvenliGetir<_RiskVerisi>(
      etiket: 'risk verileri',
      fallback: const _RiskVerisi(),
      islem: () => _riskVerileriniGetir(pool: pool, companyId: companyId),
    );

    final Future<_FinansOzet> finansFuture = _guvenliGetir<_FinansOzet>(
      etiket: 'finans ozeti',
      fallback: const _FinansOzet(),
      islem: () =>
          _finansOzetiniGetir(pool: pool, companyId: companyId, now: now),
    );

    final Future<List<SonIslem>> sonIslemlerFuture =
        _guvenliGetir<List<SonIslem>>(
          etiket: 'son islemler',
          fallback: const <SonIslem>[],
          islem: () => _sonIslemleriGetir(pool: pool),
        );

    final List<dynamic> sonuc = await Future.wait<dynamic>([
      kasaFuture,
      bankaFuture,
      stokFuture,
      cariFuture,
      satisFuture,
      grafikFuture,
      riskFuture,
      finansFuture,
      sonIslemlerFuture,
    ]);

    final _DashboardMetrik kasa = sonuc[0] as _DashboardMetrik;
    final _DashboardMetrik banka = sonuc[1] as _DashboardMetrik;
    final _DashboardMetrik stok = sonuc[2] as _DashboardMetrik;
    final _DashboardMetrik cari = sonuc[3] as _DashboardMetrik;
    final _DashboardMetrik satis = sonuc[4] as _DashboardMetrik;
    final _GrafikVerisi grafik = sonuc[5] as _GrafikVerisi;
    final _RiskVerisi risk = sonuc[6] as _RiskVerisi;
    final _FinansOzet finans = sonuc[7] as _FinansOzet;
    final List<SonIslem> sonIslemler = sonuc[8] as List<SonIslem>;

    final DashboardOzet ozet = DashboardOzet(
      toplamKasa: kasa.mevcutDeger,
      toplamBanka: banka.mevcutDeger,
      toplamStokDegeri: stok.mevcutDeger,
      netCariBakiye: cari.mevcutDeger,
      bugunNetSatis: satis.mevcutDeger,
      kasaDegisimYuzde: _degisimYuzdesi(
        mevcut: kasa.mevcutDeger,
        onceki: kasa.oncekiDeger,
      ),
      bankaDegisimYuzde: _degisimYuzdesi(
        mevcut: banka.mevcutDeger,
        onceki: banka.oncekiDeger,
      ),
      stokDegisimYuzde: _degisimYuzdesi(
        mevcut: stok.mevcutDeger,
        onceki: stok.oncekiDeger,
      ),
      cariDegisimYuzde: _degisimYuzdesi(
        mevcut: cari.mevcutDeger,
        onceki: cari.oncekiDeger,
      ),
      satisDegisimYuzde: _degisimYuzdesi(
        mevcut: satis.mevcutDeger,
        onceki: satis.oncekiDeger,
      ),
      kasaSparkline: kasa.sparkline,
      bankaSparkline: banka.sparkline,
      stokSparkline: stok.sparkline,
      cariSparkline: cari.sparkline,
      satisSparkline: satis.sparkline.isNotEmpty
          ? satis.sparkline
          : grafik.satisSparkline,
      satis30Gun: grafik.satis30Gun,
      alis30Gun: grafik.alis30Gun,
      kritikStoklar: risk.kritikStoklar,
      yaklasanVadeler: risk.yaklasanVadeler,
      krediKartiBakiyesi: finans.krediKartiBakiyesi,
      bekleyenCekler: finans.bekleyenCekler,
      bekleyenSenetler: finans.bekleyenSenetler,
      aktifSiparisler: finans.aktifSiparisler,
      aktifTeklifler: finans.aktifTeklifler,
      buAykiGiderler: finans.buAykiGiderler,
      sonIslemler: sonIslemler,
    );

    final _DashboardCacheKaydi kayit = _DashboardCacheKaydi(
      ozet: ozet,
      yuklenmeAni: DateTime.now(),
    );
    final String cacheAnahtari = _cacheAnahtari(aktifVeritabani, tarihFiltresi);
    _dashboardCache[cacheAnahtari] = kayit;
    unawaited(_cacheyiDiskeKaydet(cacheAnahtari, kayit));

    return ozet;
  }

  Future<void> _hazirliklariYap() async {
    final aktifVeritabani = OturumServisi().aktifVeritabaniAdi.trim();
    final hazirlikAnahtari = aktifVeritabani.isEmpty
        ? _defaultCompanyId
        : aktifVeritabani;

    await (_hazirlikFutureleri[hazirlikAnahtari] ??= Future.wait<void>([
      _baslatGuvenli('kasalar', () => KasalarVeritabaniServisi().baslat()),
      _baslatGuvenli('bankalar', () => BankalarVeritabaniServisi().baslat()),
      _baslatGuvenli(
        'kredi kartlari',
        () => KrediKartlariVeritabaniServisi().baslat(),
      ),
      _baslatGuvenli('urunler', () => UrunlerVeritabaniServisi().baslat()),
      _baslatGuvenli(
        'cari hesaplar',
        () => CariHesaplarVeritabaniServisi().baslat(),
      ),
      _baslatGuvenli('cekler', () => CeklerVeritabaniServisi().baslat()),
      _baslatGuvenli('senetler', () => SenetlerVeritabaniServisi().baslat()),
      _baslatGuvenli(
        'siparisler',
        () => SiparislerVeritabaniServisi().baslat(),
      ),
      _baslatGuvenli('teklifler', () => TekliflerVeritabaniServisi().baslat()),
      _baslatGuvenli('giderler', () => GiderlerVeritabaniServisi().baslat()),
    ]));
  }

  Future<void> _cacheyiDiskeKaydet(
    String cacheAnahtari,
    _DashboardCacheKaydi kayit,
  ) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefsCachePrefix$cacheAnahtari',
        jsonEncode(<String, dynamic>{
          'yuklenmeAni': kayit.yuklenmeAni.toIso8601String(),
          'ozet': kayit.ozet.toMap(),
        }),
      );
    } catch (e) {
      debugPrint('AnaSayfaServisi: disk cache yazma uyarisi: $e');
    }
  }

  String _aktifCacheAnahtari(String tarihFiltresi) {
    return _cacheAnahtari(OturumServisi().aktifVeritabaniAdi, tarihFiltresi);
  }

  String _cacheAnahtari(String aktifVeritabani, String tarihFiltresi) {
    final String veritabaniKimligi = aktifVeritabani.trim().isEmpty
        ? _defaultCompanyId
        : aktifVeritabani.trim();
    return '$veritabaniKimligi::$tarihFiltresi';
  }

  Future<void> _baslatGuvenli(
    String etiket,
    Future<void> Function() islem,
  ) async {
    try {
      await islem();
    } catch (e) {
      debugPrint('AnaSayfaServisi: $etiket baslatma uyarisi: $e');
    }
  }

  Future<T> _guvenliGetir<T>({
    required String etiket,
    required T fallback,
    required Future<T> Function() islem,
  }) async {
    try {
      return await islem();
    } catch (e) {
      if (_ilkKurulumdaBeklenenSorguHatasiMi(e)) {
        return fallback;
      }
      debugPrint('AnaSayfaServisi: $etiket sorgu uyarisi: $e');
      return fallback;
    }
  }

  bool _ilkKurulumdaBeklenenSorguHatasiMi(Object error) {
    if (error is ServerException && error.code == '42P01') {
      return true;
    }

    final raw = error.toString().toLowerCase();
    return raw.contains('42p01') &&
        raw.contains('relation') &&
        raw.contains('does not exist');
  }

  Future<_DashboardMetrik> _kasaMetrikleriniGetir({
    required Pool pool,
    required String companyId,
    required _PeriyotPenceresi seciliPeriyot,
    required _PeriyotPenceresi sparklinePeriyodu,
    bool includeSparkline = true,
  }) async {
    final Future<double> mevcutToplamFuture = _tekDegerGetir(
      pool,
      '''
        SELECT COALESCE(SUM(COALESCE(balance, 0)), 0)
        FROM cash_registers
        WHERE COALESCE(is_active, 1) = 1
          AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
      ''',
      {'companyId': companyId},
    );

    final Future<double> seciliNetFuture = _tekDegerGetir(
      pool,
      '''
        SELECT COALESCE(SUM(
          CASE
            WHEN LOWER(COALESCE(type, '')) IN ('tahsilat', 'giriş', 'giris')
              THEN COALESCE(amount, 0)
            ELSE -COALESCE(amount, 0)
          END
        ), 0)
        FROM cash_register_transactions
        WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId
          AND date >= @start
          AND date < @end
      ''',
      {
        'companyId': companyId,
        'start': _ts(seciliPeriyot.baslangic),
        'end': _ts(seciliPeriyot.bitis),
      },
    );

    final Future<Map<DateTime, double>> gunlukNetlerFuture = includeSparkline
        ? _gunlukToplamHaritasi(
            pool,
            '''
              SELECT DATE(date) AS gun,
                     COALESCE(SUM(
                       CASE
                         WHEN LOWER(COALESCE(type, '')) IN ('tahsilat', 'giriş', 'giris')
                           THEN COALESCE(amount, 0)
                         ELSE -COALESCE(amount, 0)
                       END
                     ), 0) AS toplam
              FROM cash_register_transactions
              WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId
                AND date >= @start
                AND date < @end
              GROUP BY DATE(date)
            ''',
            {
              'companyId': companyId,
              'start': _ts(sparklinePeriyodu.baslangic),
              'end': _ts(sparklinePeriyodu.bitis),
            },
          )
        : Future.value(const <DateTime, double>{});

    final List<dynamic> sonuc = await Future.wait<dynamic>([
      mevcutToplamFuture,
      seciliNetFuture,
      gunlukNetlerFuture,
    ]);
    final double mevcutToplam = sonuc[0] as double;
    final double seciliNet = sonuc[1] as double;
    final Map<DateTime, double> gunlukNetler =
        sonuc[2] as Map<DateTime, double>;

    if (!includeSparkline) {
      return _DashboardMetrik(
        mevcutDeger: mevcutToplam,
        oncekiDeger: mevcutToplam - seciliNet,
      );
    }

    return _kumulatifMetrikOlustur(
      mevcutDeger: mevcutToplam,
      seciliPeriyotNeti: seciliNet,
      sparklinePeriyodu: sparklinePeriyodu,
      gunlukNetler: gunlukNetler,
    );
  }

  Future<_DashboardMetrik> _bankaMetrikleriniGetir({
    required Pool pool,
    required String companyId,
    required _PeriyotPenceresi seciliPeriyot,
    required _PeriyotPenceresi sparklinePeriyodu,
    bool includeSparkline = true,
  }) async {
    final Future<double> mevcutToplamFuture = _tekDegerGetir(
      pool,
      '''
        SELECT COALESCE(SUM(COALESCE(balance, 0)), 0)
        FROM banks
        WHERE COALESCE(is_active, 1) = 1
          AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
      ''',
      {'companyId': companyId},
    );

    final Future<double> seciliNetFuture = _tekDegerGetir(
      pool,
      '''
        SELECT COALESCE(SUM(
          CASE
            WHEN LOWER(COALESCE(type, '')) IN ('tahsilat', 'giriş', 'giris')
              THEN COALESCE(amount, 0)
            ELSE -COALESCE(amount, 0)
          END
        ), 0)
        FROM bank_transactions
        WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId
          AND date >= @start
          AND date < @end
      ''',
      {
        'companyId': companyId,
        'start': _ts(seciliPeriyot.baslangic),
        'end': _ts(seciliPeriyot.bitis),
      },
    );

    final Future<Map<DateTime, double>> gunlukNetlerFuture = includeSparkline
        ? _gunlukToplamHaritasi(
            pool,
            '''
              SELECT DATE(date) AS gun,
                     COALESCE(SUM(
                       CASE
                         WHEN LOWER(COALESCE(type, '')) IN ('tahsilat', 'giriş', 'giris')
                           THEN COALESCE(amount, 0)
                         ELSE -COALESCE(amount, 0)
                       END
                     ), 0) AS toplam
              FROM bank_transactions
              WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId
                AND date >= @start
                AND date < @end
              GROUP BY DATE(date)
            ''',
            {
              'companyId': companyId,
              'start': _ts(sparklinePeriyodu.baslangic),
              'end': _ts(sparklinePeriyodu.bitis),
            },
          )
        : Future.value(const <DateTime, double>{});

    final List<dynamic> sonuc = await Future.wait<dynamic>([
      mevcutToplamFuture,
      seciliNetFuture,
      gunlukNetlerFuture,
    ]);
    final double mevcutToplam = sonuc[0] as double;
    final double seciliNet = sonuc[1] as double;
    final Map<DateTime, double> gunlukNetler =
        sonuc[2] as Map<DateTime, double>;

    if (!includeSparkline) {
      return _DashboardMetrik(
        mevcutDeger: mevcutToplam,
        oncekiDeger: mevcutToplam - seciliNet,
      );
    }

    return _kumulatifMetrikOlustur(
      mevcutDeger: mevcutToplam,
      seciliPeriyotNeti: seciliNet,
      sparklinePeriyodu: sparklinePeriyodu,
      gunlukNetler: gunlukNetler,
    );
  }

  Future<_DashboardMetrik> _stokMetrikleriniGetir({
    required Pool pool,
    required _PeriyotPenceresi seciliPeriyot,
    required _PeriyotPenceresi sparklinePeriyodu,
    bool includeSparkline = true,
  }) async {
    final Future<double> mevcutToplamFuture = _tekDegerGetir(pool, '''
        SELECT COALESCE(
          SUM(COALESCE(stok, 0) * COALESCE(alis_fiyati, 0)),
          0
        )
        FROM products
        WHERE COALESCE(aktif_mi, 1) = 1
      ''');

    final Future<double> seciliNetFuture = _tekDegerGetir(
      pool,
      '''
        SELECT COALESCE(SUM(
          CASE
            WHEN COALESCE(is_giris, true)
              THEN COALESCE(quantity, 0) * COALESCE(unit_price, 0) * COALESCE(NULLIF(currency_rate, 0), 1)
            ELSE -COALESCE(quantity, 0) * COALESCE(unit_price, 0) * COALESCE(NULLIF(currency_rate, 0), 1)
          END
        ), 0)
        FROM stock_movements
        WHERE movement_date >= @start
          AND movement_date < @end
      ''',
      {'start': _ts(seciliPeriyot.baslangic), 'end': _ts(seciliPeriyot.bitis)},
    );

    final Future<Map<DateTime, double>> gunlukNetlerFuture = includeSparkline
        ? _gunlukToplamHaritasi(
            pool,
            '''
              SELECT DATE(movement_date) AS gun,
                     COALESCE(SUM(
                       CASE
                         WHEN COALESCE(is_giris, true)
                           THEN COALESCE(quantity, 0) * COALESCE(unit_price, 0) * COALESCE(NULLIF(currency_rate, 0), 1)
                         ELSE -COALESCE(quantity, 0) * COALESCE(unit_price, 0) * COALESCE(NULLIF(currency_rate, 0), 1)
                       END
                     ), 0) AS toplam
              FROM stock_movements
              WHERE movement_date >= @start
                AND movement_date < @end
              GROUP BY DATE(movement_date)
            ''',
            {
              'start': _ts(sparklinePeriyodu.baslangic),
              'end': _ts(sparklinePeriyodu.bitis),
            },
          )
        : Future.value(const <DateTime, double>{});

    final List<dynamic> sonuc = await Future.wait<dynamic>([
      mevcutToplamFuture,
      seciliNetFuture,
      gunlukNetlerFuture,
    ]);
    final double mevcutToplam = sonuc[0] as double;
    final double seciliNet = sonuc[1] as double;
    final Map<DateTime, double> gunlukNetler =
        sonuc[2] as Map<DateTime, double>;

    if (!includeSparkline) {
      return _DashboardMetrik(
        mevcutDeger: mevcutToplam,
        oncekiDeger: mevcutToplam - seciliNet,
      );
    }

    return _kumulatifMetrikOlustur(
      mevcutDeger: mevcutToplam,
      seciliPeriyotNeti: seciliNet,
      sparklinePeriyodu: sparklinePeriyodu,
      gunlukNetler: gunlukNetler,
    );
  }

  Future<_DashboardMetrik> _cariMetrikleriniGetir({
    required Pool pool,
    required _PeriyotPenceresi seciliPeriyot,
    required _PeriyotPenceresi sparklinePeriyodu,
    bool includeSparkline = true,
  }) async {
    final Future<double> mevcutToplamFuture = _tekDegerGetir(pool, '''
        SELECT COALESCE(
          SUM(COALESCE(bakiye_alacak, 0) - COALESCE(bakiye_borc, 0)),
          0
        )
        FROM current_accounts
        WHERE COALESCE(aktif_mi, 1) = 1
      ''');

    final Future<double> seciliNetFuture = _tekDegerGetir(
      pool,
      '''
        SELECT COALESCE(SUM(
          CASE
            WHEN type = 'Alacak'
              THEN COALESCE(amount, 0) * COALESCE(NULLIF(kur, 0), 1)
            ELSE -COALESCE(amount, 0) * COALESCE(NULLIF(kur, 0), 1)
          END
        ), 0)
        FROM current_account_transactions
        WHERE date >= @start
          AND date < @end
      ''',
      {'start': _ts(seciliPeriyot.baslangic), 'end': _ts(seciliPeriyot.bitis)},
    );

    final Future<Map<DateTime, double>> gunlukNetlerFuture = includeSparkline
        ? _gunlukToplamHaritasi(
            pool,
            '''
              SELECT DATE(date) AS gun,
                     COALESCE(SUM(
                       CASE
                         WHEN type = 'Alacak'
                           THEN COALESCE(amount, 0) * COALESCE(NULLIF(kur, 0), 1)
                         ELSE -COALESCE(amount, 0) * COALESCE(NULLIF(kur, 0), 1)
                       END
                     ), 0) AS toplam
              FROM current_account_transactions
              WHERE date >= @start
                AND date < @end
              GROUP BY DATE(date)
            ''',
            {
              'start': _ts(sparklinePeriyodu.baslangic),
              'end': _ts(sparklinePeriyodu.bitis),
            },
          )
        : Future.value(const <DateTime, double>{});

    final List<dynamic> sonuc = await Future.wait<dynamic>([
      mevcutToplamFuture,
      seciliNetFuture,
      gunlukNetlerFuture,
    ]);
    final double mevcutToplam = sonuc[0] as double;
    final double seciliNet = sonuc[1] as double;
    final Map<DateTime, double> gunlukNetler =
        sonuc[2] as Map<DateTime, double>;

    if (!includeSparkline) {
      return _DashboardMetrik(
        mevcutDeger: mevcutToplam,
        oncekiDeger: mevcutToplam - seciliNet,
      );
    }

    return _kumulatifMetrikOlustur(
      mevcutDeger: mevcutToplam,
      seciliPeriyotNeti: seciliNet,
      sparklinePeriyodu: sparklinePeriyodu,
      gunlukNetler: gunlukNetler,
    );
  }

  Future<_DashboardMetrik> _satisMetrikleriniGetir({
    required Pool pool,
    required _PeriyotPenceresi seciliPeriyot,
    required _PeriyotPenceresi oncekiPeriyot,
    required _PeriyotPenceresi sparklinePeriyodu,
    bool includeSparkline = true,
  }) async {
    final Future<double> mevcutToplamFuture = _tekDegerGetir(
      pool,
      '''
        SELECT COALESCE(SUM(COALESCE(amount, 0) * COALESCE(NULLIF(kur, 0), 1)), 0)
        FROM current_account_transactions
        WHERE date >= @start
          AND date < @end
          AND type = 'Borç'
          AND (
            COALESCE(integration_ref, '') LIKE 'SALE-%'
            OR COALESCE(integration_ref, '') LIKE 'RETAIL-%'
            OR LOWER(TRIM(COALESCE(source_type, ''))) IN (
              'satış yapıldı',
              'satis yapildi',
              'perakende satış',
              'perakende satis'
            )
          )
      ''',
      {'start': _ts(seciliPeriyot.baslangic), 'end': _ts(seciliPeriyot.bitis)},
    );

    final Future<double> oncekiToplamFuture = _tekDegerGetir(
      pool,
      '''
        SELECT COALESCE(SUM(COALESCE(amount, 0) * COALESCE(NULLIF(kur, 0), 1)), 0)
        FROM current_account_transactions
        WHERE date >= @start
          AND date < @end
          AND type = 'Borç'
          AND (
            COALESCE(integration_ref, '') LIKE 'SALE-%'
            OR COALESCE(integration_ref, '') LIKE 'RETAIL-%'
            OR LOWER(TRIM(COALESCE(source_type, ''))) IN (
              'satış yapıldı',
              'satis yapildi',
              'perakende satış',
              'perakende satis'
            )
          )
      ''',
      {'start': _ts(oncekiPeriyot.baslangic), 'end': _ts(oncekiPeriyot.bitis)},
    );

    final Future<Map<DateTime, double>> gunlukToplamlarFuture = includeSparkline
        ? _gunlukToplamHaritasi(
            pool,
            '''
              SELECT DATE(date) AS gun,
                     COALESCE(SUM(COALESCE(amount, 0) * COALESCE(NULLIF(kur, 0), 1)), 0) AS toplam
              FROM current_account_transactions
              WHERE date >= @start
                AND date < @end
                AND type = 'Borç'
                AND (
                  COALESCE(integration_ref, '') LIKE 'SALE-%'
                  OR COALESCE(integration_ref, '') LIKE 'RETAIL-%'
                  OR LOWER(TRIM(COALESCE(source_type, ''))) IN (
                    'satış yapıldı',
                    'satis yapildi',
                    'perakende satış',
                    'perakende satis'
                  )
                )
              GROUP BY DATE(date)
            ''',
            {
              'start': _ts(sparklinePeriyodu.baslangic),
              'end': _ts(sparklinePeriyodu.bitis),
            },
          )
        : Future.value(const <DateTime, double>{});

    final List<dynamic> sonuc = await Future.wait<dynamic>([
      mevcutToplamFuture,
      oncekiToplamFuture,
      gunlukToplamlarFuture,
    ]);
    final double mevcutToplam = sonuc[0] as double;
    final double oncekiToplam = sonuc[1] as double;
    final Map<DateTime, double> gunlukToplamlar =
        sonuc[2] as Map<DateTime, double>;

    if (!includeSparkline) {
      return _DashboardMetrik(
        mevcutDeger: mevcutToplam,
        oncekiDeger: oncekiToplam,
      );
    }

    final List<double> sparkline = _gunAraligi(
      sparklinePeriyodu,
    ).map((gun) => gunlukToplamlar[gun] ?? 0).toList();

    return _DashboardMetrik(
      mevcutDeger: mevcutToplam,
      oncekiDeger: oncekiToplam,
      sparkline: sparkline,
    );
  }

  Future<_GrafikVerisi> _grafikVerileriniGetir({
    required Pool pool,
    required _PeriyotPenceresi grafikPeriyodu,
  }) async {
    final List<List<dynamic>> rows = await pool.execute(
      Sql.named('''
          SELECT
            DATE(date) AS gun,
            COALESCE(SUM(
              CASE
                WHEN type = 'Borç'
                  AND (
                    COALESCE(integration_ref, '') LIKE 'SALE-%'
                    OR COALESCE(integration_ref, '') LIKE 'RETAIL-%'
                    OR LOWER(TRIM(COALESCE(source_type, ''))) IN (
                      'satış yapıldı',
                      'satis yapildi',
                      'perakende satış',
                      'perakende satis'
                    )
                  )
                  THEN COALESCE(amount, 0) * COALESCE(NULLIF(kur, 0), 1)
                ELSE 0
              END
            ), 0) AS satis_toplami,
            COALESCE(SUM(
              CASE
                WHEN type = 'Alacak'
                  AND (
                    COALESCE(integration_ref, '') LIKE 'PURCHASE-%'
                    OR LOWER(TRIM(COALESCE(source_type, ''))) IN (
                      'alış yapıldı',
                      'alis yapildi'
                    )
                  )
                  THEN COALESCE(amount, 0) * COALESCE(NULLIF(kur, 0), 1)
                ELSE 0
              END
            ), 0) AS alis_toplami
          FROM current_account_transactions
          WHERE date >= @start
            AND date < @end
          GROUP BY DATE(date)
        '''),
      parameters: {
        'start': _ts(grafikPeriyodu.baslangic),
        'end': _ts(grafikPeriyodu.bitis),
      },
    );

    final Map<DateTime, double> satisHaritasi = <DateTime, double>{};
    final Map<DateTime, double> alisHaritasi = <DateTime, double>{};

    for (final row in rows) {
      final DateTime gun = _gunAnahtari(row[0]);
      satisHaritasi[gun] = _sayiyaCevir(row[1]);
      alisHaritasi[gun] = _sayiyaCevir(row[2]);
    }

    final List<GunlukTutar> satis30Gun = <GunlukTutar>[];
    final List<GunlukTutar> alis30Gun = <GunlukTutar>[];
    final List<DateTime> gunler = _gunAraligi(grafikPeriyodu);

    for (final DateTime gun in gunler) {
      satis30Gun.add(GunlukTutar(tarih: gun, tutar: satisHaritasi[gun] ?? 0));
      alis30Gun.add(GunlukTutar(tarih: gun, tutar: alisHaritasi[gun] ?? 0));
    }

    final int sparklineBaslangicIndex = gunler.length > 7
        ? gunler.length - 7
        : 0;
    final List<double> satisSparkline = gunler
        .sublist(sparklineBaslangicIndex)
        .map((gun) => satisHaritasi[gun] ?? 0)
        .toList();

    return _GrafikVerisi(
      satis30Gun: satis30Gun,
      alis30Gun: alis30Gun,
      satisSparkline: satisSparkline,
    );
  }

  Future<_RiskVerisi> _riskVerileriniGetir({
    required Pool pool,
    required String companyId,
  }) async {
    final DateTime bugun = _gunBaslangici(DateTime.now());
    final DateTime otuzGunSonra = bugun.add(const Duration(days: 31));

    final Future<List<List<dynamic>>> stokRowsFuture = pool.execute(
      Sql.named('''
          SELECT id, ad, COALESCE(stok, 0), COALESCE(birim, 'Adet')
          FROM products
          WHERE COALESCE(aktif_mi, 1) = 1
            AND COALESCE(stok, 0) <= 5
          ORDER BY COALESCE(stok, 0) ASC, ad ASC
          LIMIT 8
        '''),
    );

    final Future<List<List<dynamic>>> vadeRowsFuture = pool.execute(
      Sql.named('''
          SELECT *
          FROM (
            SELECT
              id,
              'Çek' AS tur,
              COALESCE(description, customer_name, 'Yaklaşan çek') AS aciklama,
              COALESCE(amount, 0) AS tutar,
              due_date,
              COALESCE(customer_name, '') AS cari_adi
            FROM cheques
            WHERE COALESCE(is_active, 1) = 1
              AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
              AND LOWER(COALESCE(collection_status, '')) NOT IN (
                'tahsil edildi',
                'ödendi',
                'odendi',
                'ciro edildi',
                'karşılıksız',
                'karsiliksiz'
              )
              AND due_date IS NOT NULL
              AND due_date >= @start
              AND due_date < @end
            UNION ALL
            SELECT
              id,
              'Senet' AS tur,
              COALESCE(description, customer_name, 'Yaklaşan senet') AS aciklama,
              COALESCE(amount, 0) AS tutar,
              due_date,
              COALESCE(customer_name, '') AS cari_adi
            FROM promissory_notes
            WHERE COALESCE(is_active, 1) = 1
              AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
              AND LOWER(COALESCE(collection_status, '')) NOT IN (
                'tahsil edildi',
                'ödendi',
                'odendi',
                'ciro edildi',
                'karşılıksız',
                'karsiliksiz'
              )
              AND due_date IS NOT NULL
              AND due_date >= @start
              AND due_date < @end
          ) AS vadeler
          ORDER BY due_date ASC, id ASC
          LIMIT 8
        '''),
      parameters: {
        'companyId': companyId,
        'start': _ts(bugun),
        'end': _ts(otuzGunSonra),
      },
    );

    final List<dynamic> sonuc = await Future.wait<dynamic>([
      stokRowsFuture,
      vadeRowsFuture,
    ]);
    final List<List<dynamic>> stokRows = sonuc[0] as List<List<dynamic>>;
    final List<List<dynamic>> vadeRows = sonuc[1] as List<List<dynamic>>;

    final List<KritikStokItem> kritikStoklar = stokRows
        .map(
          (row) => KritikStokItem(
            id: _sayiyaCevir(row[0]).toInt(),
            urunAdi: row[1]?.toString() ?? '',
            mevcutStok: _sayiyaCevir(row[2]),
            birim: ((row[3]?.toString() ?? '').trim().isEmpty)
                ? 'Adet'
                : row[3].toString(),
          ),
        )
        .toList();

    final List<YaklasanVade> yaklasanVadeler = vadeRows
        .map(
          (row) => YaklasanVade(
            id: _sayiyaCevir(row[0]).toInt(),
            tur: row[1]?.toString() ?? '',
            aciklama: row[2]?.toString() ?? '',
            tutar: _sayiyaCevir(row[3]),
            vadeTarihi: _tariheCevir(row[4]) ?? DateTime.now(),
            cariAdi: row[5]?.toString() ?? '',
          ),
        )
        .toList();

    return _RiskVerisi(
      kritikStoklar: kritikStoklar,
      yaklasanVadeler: yaklasanVadeler,
    );
  }

  Future<_FinansOzet> _finansOzetiniGetir({
    required Pool pool,
    required String companyId,
    required DateTime now,
  }) async {
    final DateTime ayBaslangici = DateTime(now.year, now.month);
    final DateTime sonrakiAyBaslangici = DateTime(now.year, now.month + 1);

    final Future<double> krediKartiFuture = _tekDegerGetir(
      pool,
      '''
        SELECT COALESCE(SUM(COALESCE(balance, 0)), 0)
        FROM credit_cards
        WHERE COALESCE(is_active, 1) = 1
          AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
      ''',
      {'companyId': companyId},
    );

    final Future<double> cekFuture = _tekDegerGetir(
      pool,
      '''
        SELECT COALESCE(SUM(COALESCE(amount, 0)), 0)
        FROM cheques
        WHERE COALESCE(is_active, 1) = 1
          AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
          AND LOWER(COALESCE(collection_status, '')) NOT IN (
            'tahsil edildi',
            'ödendi',
            'odendi',
            'ciro edildi',
            'karşılıksız',
            'karsiliksiz'
          )
      ''',
      {'companyId': companyId},
    );

    final Future<double> senetFuture = _tekDegerGetir(
      pool,
      '''
        SELECT COALESCE(SUM(COALESCE(amount, 0)), 0)
        FROM promissory_notes
        WHERE COALESCE(is_active, 1) = 1
          AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
          AND LOWER(COALESCE(collection_status, '')) NOT IN (
            'tahsil edildi',
            'ödendi',
            'odendi',
            'ciro edildi',
            'karşılıksız',
            'karsiliksiz'
          )
      ''',
      {'companyId': companyId},
    );

    final Future<int> siparisFuture = _tekSayiGetir(pool, '''
        SELECT COALESCE(COUNT(*), 0)
        FROM orders
        WHERE COALESCE(durum, 'Beklemede') IN ('Beklemede', 'Onaylandı')
      ''');

    final Future<int> teklifFuture = _tekSayiGetir(pool, '''
        SELECT COALESCE(COUNT(*), 0)
        FROM quotes
        WHERE COALESCE(durum, 'Beklemede') IN ('Beklemede', 'Onaylandı')
      ''');

    final Future<double> giderFuture = _tekDegerGetir(
      pool,
      '''
        SELECT COALESCE(SUM(COALESCE(tutar, 0)), 0)
        FROM expenses
        WHERE COALESCE(aktif_mi, 1) = 1
          AND tarih >= @start
          AND tarih < @end
      ''',
      {'start': _ts(ayBaslangici), 'end': _ts(sonrakiAyBaslangici)},
    );

    final List<dynamic> sonuc = await Future.wait<dynamic>([
      krediKartiFuture,
      cekFuture,
      senetFuture,
      siparisFuture,
      teklifFuture,
      giderFuture,
    ]);

    return _FinansOzet(
      krediKartiBakiyesi: sonuc[0] as double,
      bekleyenCekler: sonuc[1] as double,
      bekleyenSenetler: sonuc[2] as double,
      aktifSiparisler: sonuc[3] as int,
      aktifTeklifler: sonuc[4] as int,
      buAykiGiderler: sonuc[5] as double,
    );
  }

  Future<List<SonIslem>> _sonIslemleriGetir({required Pool pool}) async {
    final List<List<dynamic>> rows = await pool.execute(
      Sql.named('''
          SELECT
            id,
            COALESCE(date, created_at) AS tarih,
            COALESCE(description, source_type, 'İşlem') AS aciklama,
            COALESCE(amount, 0) * COALESCE(NULLIF(kur, 0), 1) AS tutar,
            COALESCE(source_name, source_code, 'İşlem') AS cari_adi,
            CASE
              WHEN LOWER(COALESCE(source_type, '')) LIKE '%çek%'
                OR LOWER(COALESCE(source_type, '')) LIKE '%cek%'
                THEN 'cek'
              WHEN COALESCE(source_type, '') ILIKE '%Senet%' THEN 'senet'
              WHEN (
                COALESCE(integration_ref, '') LIKE 'SALE-%'
                OR COALESCE(integration_ref, '') LIKE 'RETAIL-%'
                OR LOWER(TRIM(COALESCE(source_type, ''))) IN (
                  'satış yapıldı',
                  'satis yapildi',
                  'perakende satış',
                  'perakende satis'
                )
              ) THEN 'satis'
              WHEN (
                COALESCE(integration_ref, '') LIKE 'PURCHASE-%'
                OR LOWER(TRIM(COALESCE(source_type, ''))) IN (
                  'alış yapıldı',
                  'alis yapildi'
                )
              ) THEN 'alis'
              WHEN (
                LOWER(COALESCE(source_type, '')) LIKE '%tahsil%'
                OR type = 'Alacak'
              ) THEN 'tahsilat'
              WHEN (
                LOWER(COALESCE(source_type, '')) LIKE '%ödeme%'
                OR LOWER(COALESCE(source_type, '')) LIKE '%odeme%'
                OR type = 'Borç'
              ) THEN 'odeme'
              ELSE 'tahsilat'
            END AS tur
          FROM current_account_transactions
          ORDER BY COALESCE(date, created_at) DESC, id DESC
          LIMIT 15
        '''),
    );

    return rows
        .map(
          (row) => SonIslem(
            id: _sayiyaCevir(row[0]).toInt(),
            tarih: _tariheCevir(row[1]) ?? DateTime.now(),
            aciklama: row[2]?.toString() ?? '',
            tutar: _sayiyaCevir(row[3]).abs(),
            cariAdi: row[4]?.toString() ?? '',
            tur: row[5]?.toString() ?? 'tahsilat',
          ),
        )
        .toList();
  }

  Future<double> _tekDegerGetir(
    Pool pool,
    String sql, [
    Map<String, dynamic> parameters = const <String, dynamic>{},
  ]) async {
    final List<List<dynamic>> result = await pool.execute(
      Sql.named(sql),
      parameters: parameters,
    );
    if (result.isEmpty || result.first.isEmpty) return 0;
    return _sayiyaCevir(result.first.first);
  }

  Future<int> _tekSayiGetir(
    Pool pool,
    String sql, [
    Map<String, dynamic> parameters = const <String, dynamic>{},
  ]) async {
    final List<List<dynamic>> result = await pool.execute(
      Sql.named(sql),
      parameters: parameters,
    );
    if (result.isEmpty || result.first.isEmpty) return 0;
    final dynamic value = result.first.first;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<Map<DateTime, double>> _gunlukToplamHaritasi(
    Pool pool,
    String sql, [
    Map<String, dynamic> parameters = const <String, dynamic>{},
  ]) async {
    final List<List<dynamic>> rows = await pool.execute(
      Sql.named(sql),
      parameters: parameters,
    );

    final Map<DateTime, double> values = <DateTime, double>{};
    for (final row in rows) {
      if (row.length < 2) continue;
      values[_gunAnahtari(row[0])] = _sayiyaCevir(row[1]);
    }
    return values;
  }

  _DashboardMetrik _kumulatifMetrikOlustur({
    required double mevcutDeger,
    required double seciliPeriyotNeti,
    required _PeriyotPenceresi sparklinePeriyodu,
    required Map<DateTime, double> gunlukNetler,
  }) {
    final List<DateTime> gunler = _gunAraligi(sparklinePeriyodu);
    final double toplamHareket = gunler.fold<double>(
      0,
      (sum, gun) => sum + (gunlukNetler[gun] ?? 0),
    );

    double anlikDeger = mevcutDeger - toplamHareket;
    final List<double> sparkline = <double>[];

    for (final DateTime gun in gunler) {
      anlikDeger += gunlukNetler[gun] ?? 0;
      sparkline.add(anlikDeger);
    }

    return _DashboardMetrik(
      mevcutDeger: mevcutDeger,
      oncekiDeger: mevcutDeger - seciliPeriyotNeti,
      sparkline: sparkline,
    );
  }

  double _degisimYuzdesi({required double mevcut, required double onceki}) {
    if (mevcut == 0 && onceki == 0) return 0;
    if (onceki.abs() < 0.000001) {
      return mevcut == 0 ? 0 : 100;
    }
    return ((mevcut - onceki) / onceki.abs()) * 100;
  }

  _PeriyotPenceresi _periyotPenceresiOlustur(
    DateTime now,
    String tarihFiltresi,
  ) {
    switch (tarihFiltresi) {
      case 'buHafta':
        final DateTime haftaBaslangici = _gunBaslangici(
          now.subtract(Duration(days: now.weekday - 1)),
        );
        return _PeriyotPenceresi(
          baslangic: haftaBaslangici,
          bitis: haftaBaslangici.add(const Duration(days: 7)),
        );
      case 'buAy':
        final DateTime ayBaslangici = DateTime(now.year, now.month);
        return _PeriyotPenceresi(
          baslangic: ayBaslangici,
          bitis: DateTime(now.year, now.month + 1),
        );
      case 'bugun':
      default:
        final DateTime gunBaslangici = _gunBaslangici(now);
        return _PeriyotPenceresi(
          baslangic: gunBaslangici,
          bitis: gunBaslangici.add(const Duration(days: 1)),
        );
    }
  }

  _PeriyotPenceresi _oncekiPeriyot(_PeriyotPenceresi aktifPeriyot) {
    final Duration fark = aktifPeriyot.bitis.difference(aktifPeriyot.baslangic);
    return _PeriyotPenceresi(
      baslangic: aktifPeriyot.baslangic.subtract(fark),
      bitis: aktifPeriyot.baslangic,
    );
  }

  DateTime _gunBaslangici(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<DateTime> _gunAraligi(_PeriyotPenceresi periyot) {
    final List<DateTime> gunler = <DateTime>[];
    DateTime cursor = _gunBaslangici(periyot.baslangic);

    while (cursor.isBefore(periyot.bitis)) {
      gunler.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }

    return gunler;
  }

  DateTime _gunAnahtari(dynamic value) {
    final DateTime? tarih = _tariheCevir(value);
    if (tarih == null) return _gunBaslangici(DateTime.now());
    return _gunBaslangici(tarih);
  }

  DateTime? _tariheCevir(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  double _sayiyaCevir(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _ts(DateTime value) => value.toIso8601String();
}

class _PeriyotPenceresi {
  final DateTime baslangic;
  final DateTime bitis;

  const _PeriyotPenceresi({required this.baslangic, required this.bitis});
}

class _DashboardMetrik {
  final double mevcutDeger;
  final double oncekiDeger;
  final List<double> sparkline;

  const _DashboardMetrik({
    this.mevcutDeger = 0,
    this.oncekiDeger = 0,
    this.sparkline = const <double>[],
  });
}

class _GrafikVerisi {
  final List<GunlukTutar> satis30Gun;
  final List<GunlukTutar> alis30Gun;
  final List<double> satisSparkline;

  const _GrafikVerisi({
    this.satis30Gun = const <GunlukTutar>[],
    this.alis30Gun = const <GunlukTutar>[],
    this.satisSparkline = const <double>[],
  });
}

class _RiskVerisi {
  final List<KritikStokItem> kritikStoklar;
  final List<YaklasanVade> yaklasanVadeler;

  const _RiskVerisi({
    this.kritikStoklar = const <KritikStokItem>[],
    this.yaklasanVadeler = const <YaklasanVade>[],
  });
}

class _FinansOzet {
  final double krediKartiBakiyesi;
  final double bekleyenCekler;
  final double bekleyenSenetler;
  final int aktifSiparisler;
  final int aktifTeklifler;
  final double buAykiGiderler;

  const _FinansOzet({
    this.krediKartiBakiyesi = 0,
    this.bekleyenCekler = 0,
    this.bekleyenSenetler = 0,
    this.aktifSiparisler = 0,
    this.aktifTeklifler = 0,
    this.buAykiGiderler = 0,
  });
}

class _DashboardCacheKaydi {
  final DashboardOzet ozet;
  final DateTime yuklenmeAni;

  const _DashboardCacheKaydi({required this.ozet, required this.yuklenmeAni});
}
