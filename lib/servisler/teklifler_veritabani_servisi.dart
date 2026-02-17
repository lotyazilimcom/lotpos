import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sayfalar/siparisler_teklifler/modeller/teklif_model.dart';
import '../yardimcilar/format_yardimcisi.dart';
import 'oturum_servisi.dart';
import 'bulut_sema_dogrulama_servisi.dart';
import 'pg_eklentiler.dart';
import 'veritabani_yapilandirma.dart';
import 'depolar_veritabani_servisi.dart';
import '../yardimcilar/islem_turu_renkleri.dart';
import 'lisans_yazma_koruma.dart';

class TekliflerVeritabaniServisi {
  static final TekliflerVeritabaniServisi _instance =
      TekliflerVeritabaniServisi._internal();
  factory TekliflerVeritabaniServisi() => _instance;
  TekliflerVeritabaniServisi._internal();

  Pool? _pool;
  bool _isInitialized = false;
  final _yapilandirma = VeritabaniYapilandirma();
  Completer<void>? _initCompleter;
  int _initToken = 0;
  static bool _isIndexingActive = false;

  Future<void> baslat() async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    final initToken = ++_initToken;
    final initCompleter = Completer<void>();
    _initCompleter = initCompleter;

    try {
      _pool = await _poolOlustur();
    } catch (e) {
      final isConnectionLimitError =
          e.toString().contains('53300') ||
          (e is ServerException && e.code == '53300');

      if (isConnectionLimitError) {
        debugPrint('Bağlantı limiti aşıldı (53300). Temizleniyor...');
        await _acikBaglantilariKapat();
        try {
          _pool = await _poolOlustur();
        } catch (e2) {
          debugPrint('Temizleme sonrası bağlantı hatası: $e2');
        }
      } else {
        debugPrint('Bağlantı hatası: $e');
      }
    }

    if (_pool == null) {
      final err = StateError('Teklifler veritabanı bağlantısı kurulamadı.');
      if (!initCompleter.isCompleted) {
        initCompleter.completeError(err);
      }
      if (identical(_initCompleter, initCompleter)) {
        _initCompleter = null;
      }
      return;
    }

    try {
      if (_pool != null) {
        final semaHazir = await BulutSemaDogrulamaServisi().bulutSemasiHazirMi(
          executor: _pool!,
          databaseName: OturumServisi().aktifVeritabaniAdi,
        );
        if (!semaHazir) {
          await _tablolariOlustur();
        } else {
          debugPrint(
            'TekliflerVeritabaniServisi: Bulut şema hazır, tablo kurulumu atlandı.',
          );
        }
        if (_yapilandirma.allowBackgroundDbMaintenance) {
          // Arka plan işi: asla uygulamayı çökertmesin.
          unawaited(
            Future<void>.delayed(const Duration(seconds: 2), () async {
              try {
                await _verileriIndeksle();
              } catch (e) {
                debugPrint(
                  'TekliflerVeritabaniServisi: Arka plan indeksleme hatası (yutuldu): $e',
                );
              }
            }),
          );
        }
        if (initToken != _initToken) {
          if (!initCompleter.isCompleted) {
            initCompleter.completeError(StateError('Bağlantı kapatıldı'));
          }
          if (identical(_initCompleter, initCompleter)) {
            _initCompleter = null;
          }
          return;
        }

        _isInitialized = true;
        debugPrint('Teklifler veritabanı bağlantısı başarılı (Havuz)');
        if (!initCompleter.isCompleted) {
          initCompleter.complete();
        }
      }
    } catch (e) {
      if (!initCompleter.isCompleted) {
        initCompleter.completeError(e);
      }
      if (identical(_initCompleter, initCompleter)) {
        _initCompleter = null;
      }
      rethrow;
    }
  }

  Future<void> baglantiyiKapat() async {
    _initToken++;
    final pending = _initCompleter;
    _initCompleter = null;
    _isInitialized = false;

    final pool = _pool;
    _pool = null;
    try {
      await pool?.close();
    } catch (_) {}
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('Bağlantı kapatıldı'));
    }
  }

  Future<void> _verileriIndeksle() async {
    if (_isIndexingActive) return;
    _isIndexingActive = true;

    try {
      final pool = _pool;
      if (pool == null || !pool.isOpen) return;

      while (true) {
        if (!pool.isOpen) break;
        final result = await pool.execute('''
           WITH batch AS (
             SELECT id FROM quotes 
             WHERE search_tags IS NULL OR search_tags NOT LIKE '%|v6|%'
             LIMIT 100
           ),
            quote_data AS (
              SELECT 
                q.id,
                LOWER(
                    COALESCE(q.id::text, '') || ' ' ||
                  COALESCE(q.tur, '') || ' ' || 
                  COALESCE(q.durum, '') || ' ' || 
                  COALESCE(TO_CHAR(q.tarih, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
                  COALESCE(q.cari_adi, '') || ' ' || 
                  COALESCE(q.ilgili_hesap_adi, '') || ' ' || 
                  COALESCE(q.tutar::text, '') || ' ' ||
                  COALESCE(REPLACE(q.tutar::text, '.', ','), '') || ' ' ||
                  COALESCE(q.kur::text, '') || ' ' ||
                  COALESCE(REPLACE(q.kur::text, '.', ','), '') || ' ' ||
                  COALESCE(q.aciklama, '') || ' ' || 
                  COALESCE(q.aciklama2, '') || ' ' || 
                  COALESCE(TO_CHAR(q.gecerlilik_tarihi, 'DD.MM.YYYY'), '') || ' ' ||
                  COALESCE(q.para_birimi, '') || ' ' || 
                  COALESCE(q.kullanici, '') || ' ' || 
                  COALESCE(q.integration_ref, '') || ' ' ||
                  '|v6| ' ||
                  COALESCE((
                    SELECT STRING_AGG(
                      LOWER(
                        COALESCE(qi.urun_kodu, '') || ' ' || 
                        COALESCE(qi.urun_adi, '') || ' ' || 
                        COALESCE(qi.barkod, '') || ' ' || 
                        COALESCE(qi.depo_adi, '') || ' ' ||
                        COALESCE(qi.kdv_orani::text, '') || ' ' ||
                        COALESCE(qi.kdv_orani::int::text, '') || ' ' ||
                        COALESCE(qi.kdv_durumu, '') || ' ' ||
                        CASE WHEN qi.kdv_durumu = 'included' THEN 'kdv dahil dahil' ELSE 'kdv hariç hariç' END || ' ' ||
                        COALESCE(qi.miktar::text, '') || ' ' ||
                        COALESCE(REPLACE(qi.miktar::text, '.', ','), '') || ' ' ||
                        COALESCE(qi.birim, '') || ' ' ||
                        COALESCE(qi.iskonto::text, '') || ' ' ||
                        COALESCE(REPLACE(qi.iskonto::text, '.', ','), '') || ' ' ||
                        COALESCE(qi.birim_fiyati::text, '') || ' ' ||
                        COALESCE(REPLACE(qi.birim_fiyati::text, '.', ','), '') || ' ' ||
                        COALESCE(qi.toplam_fiyati::text, '') || ' ' ||
                        COALESCE(REPLACE(qi.toplam_fiyati::text, '.', ','), '')
                      ), ' '
                    )
                    FROM quote_items qi
                    WHERE qi.quote_id = q.id
                  ), '')
                ) as new_tags
              FROM quotes q
              INNER JOIN batch b ON q.id = b.id
            )
           UPDATE quotes q
           SET search_tags = qd.new_tags
           FROM quote_data qd
           WHERE q.id = qd.id
           RETURNING q.id
        ''');

        if (result.isEmpty) break;
        await Future.delayed(const Duration(milliseconds: 50));
      }
      debugPrint('✅ Teklif Arama İndeksleri Kontrol Edildi.');
    } catch (e) {
      if (e is LisansYazmaEngelliHatasi) return;
      debugPrint('Teklif indeksleme hatası: $e');
    } finally {
      _isIndexingActive = false;
    }
  }

  Future<Pool> _poolOlustur() async {
    return LisansKorumaliPool(
      Pool.withEndpoints(
        [
          Endpoint(
            host: _yapilandirma.host,
            port: _yapilandirma.port,
            database: OturumServisi().aktifVeritabaniAdi,
            username: _yapilandirma.username,
            password: _yapilandirma.password,
          ),
        ],
        settings: PoolSettings(
          sslMode: _yapilandirma.sslMode,
          connectTimeout: _yapilandirma.poolConnectTimeout,
          onOpen: _yapilandirma.tuneConnection,
          maxConnectionCount: _yapilandirma.maxConnections,
        ),
      ),
    );
  }

  Future<Connection?> _yoneticiBaglantisiAl() async {
    final List<String> olasiKullanicilar = [];
    if (Platform.environment.containsKey('USER')) {
      olasiKullanicilar.add(Platform.environment['USER']!);
    }
    olasiKullanicilar.add('postgres');

    final List<String> olasiSifreler = ['', 'postgres', 'password', '123456'];

    for (final user in olasiKullanicilar) {
      for (final sifre in olasiSifreler) {
        try {
          final conn = await Connection.open(
            Endpoint(
              host: _yapilandirma.host,
              port: _yapilandirma.port,
              database: 'postgres',
              username: user,
              password: sifre,
            ),
            settings: ConnectionSettings(sslMode: _yapilandirma.sslMode),
          );
          return conn;
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  Future<void> _acikBaglantilariKapat() async {
    final adminConn = await _yoneticiBaglantisiAl();
    if (adminConn != null) {
      try {
        final username = _yapilandirma.username;
        await adminConn.execute(
          "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = '$username' AND pid <> pg_backend_pid()",
        );
      } catch (e) {
        debugPrint('Bağlantı sonlandırma hatası: $e');
      } finally {
        await adminConn.close();
      }
    }
  }

  Future<void> _tablolariOlustur() async {
    if (_pool == null) return;

    try {
      // Tablo durumunu detaylı kontrol et (Casting relkind to text is crucial)
      final tableCheck = await _pool!.execute(
        "SELECT c.relkind::text, n.nspname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relname = 'quotes' AND n.nspname = 'public'",
      );

      if (tableCheck.isEmpty) {
        // Tablo yok, sıfırdan oluştur
        debugPrint('Teklifler: Tablo yok. Partitioned kurulum yapılıyor...');
        await _createPartitionedQuotesTable();
      } else {
        final relkind = tableCheck.first[0].toString();
        debugPrint(
          'Mevcut Teklifler Tablo Durumu: relkind=$relkind (r=regular, p=partitioned)',
        );

        // Eğer tablo var ama partitioned değilse (r), migration yap
        if (relkind != 'p') {
          debugPrint(
            'Teklifler: Tablo regular modda. Partitioned yapıya geçiliyor...',
          );
          await _migrateToPartitionedStructure();
        } else {
          debugPrint('✅ Teklifler tablosu zaten Partitioned yapıda.');
        }
      }
    } catch (e) {
      debugPrint('Teklifler tablo kurulum hatası: $e');
    }

    // Partition Yönetimi (Her başlangıçta kontrol et)
    try {
      await _ensurePartitionExists(DateTime.now());
      // Bir sonraki ayın partition'ını da şimdiden hazırla
      await _ensurePartitionExists(
        DateTime.now().add(const Duration(days: 32)),
      );
    } catch (e) {
      debugPrint('Initial partition check hatası (Teklifler): $e');
    }

    // [MIGRATION] Diğer eksik kolonları kontrol et
    await _eksikKolonlariTamamla();

    // Teklif Ürünleri Tablosu (items partitionlanmaz)
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS quote_items (
        id SERIAL PRIMARY KEY,
        quote_id INTEGER NOT NULL,
        urun_id INTEGER,
        urun_kodu TEXT NOT NULL,
        urun_adi TEXT NOT NULL,
        barkod TEXT,
        depo_id INTEGER,
        depo_adi TEXT,
        kdv_orani NUMERIC DEFAULT 0,
        miktar NUMERIC DEFAULT 0,
        birim TEXT DEFAULT 'Adet',
        birim_fiyati NUMERIC DEFAULT 0,
        para_birimi TEXT DEFAULT 'TRY',
        kdv_durumu TEXT DEFAULT 'excluded',
        iskonto NUMERIC DEFAULT 0,
        toplam_fiyati NUMERIC DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // İndeksler
    try {
      await PgEklentiler.ensurePgTrgm(_pool!);
      // Partitioned tablolarda unique index partition key içermelidir.
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_quotes_tarih ON quotes(tarih DESC)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_quotes_integration_ref ON quotes(integration_ref)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_quote_items_quote_id ON quote_items(quote_id)',
      );
    } catch (e) {
      debugPrint('Teklif indeksleme uyarısı: $e');
    }
  }

  /// 100 Milyar satır için optimize edilmiş Partitioned Table oluşturur.
  Future<void> _createPartitionedQuotesTable() async {
    // 1. Ana Tablo (Partitioned by Range)
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS quotes (
        id SERIAL,
        integration_ref TEXT,
        quote_no TEXT,
        tur TEXT NOT NULL DEFAULT 'Satış Teklifi',
        durum TEXT NOT NULL DEFAULT 'Beklemede',
        tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        cari_id INTEGER,
        cari_kod TEXT,
        cari_adi TEXT,
        ilgili_hesap_adi TEXT,
        tutar NUMERIC DEFAULT 0,
        kur NUMERIC DEFAULT 1,
        aciklama TEXT,
        aciklama2 TEXT,
        gecerlilik_tarihi TIMESTAMP,
        para_birimi TEXT DEFAULT 'TRY',
        kullanici TEXT,
        search_tags TEXT,
        stok_rezerve_mi BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP,
        PRIMARY KEY (id, tarih)
      ) PARTITION BY RANGE (tarih)
    ''');

    // 2. Default Partition (Güvenlik Ağı)
    await _pool!.execute(
      'CREATE TABLE IF NOT EXISTS quotes_default PARTITION OF quotes DEFAULT',
    );
  }

  Future<void> _migrateToPartitionedStructure() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupName = 'quotes_legacy_backup_$timestamp';

    debugPrint('🚀 TEKLİF MIGRATION START: $backupName');

    try {
      // 1. Mevcut tabloyu yedekle
      await _pool!.execute('ALTER TABLE quotes RENAME TO $backupName');

      // 2. Partitioned tabloyu oluştur
      await _createPartitionedQuotesTable();

      // 3. Partition'ları hazırla
      debugPrint('📦 Teklif Partitionlari hazırlanıyor...');
      await _ensurePartitionExists(DateTime.now());
      await _ensurePartitionExists(
        DateTime.now().add(const Duration(days: 30)),
      );
      await _ensurePartitionExists(
        DateTime.now().subtract(const Duration(days: 30)),
      );

      // 4. Verileri aktar
      debugPrint('💾 Teklif Verileri aktarılıyor...');
      await _pool!.execute('''
        INSERT INTO quotes (
          id, integration_ref, quote_no, tur, durum, tarih, cari_id, cari_kod, cari_adi, ilgili_hesap_adi,
          tutar, kur, aciklama, aciklama2, gecerlilik_tarihi, para_birimi,
          kullanici, search_tags, stok_rezerve_mi, created_at, updated_at
        )
        SELECT 
          id, integration_ref, quote_no, tur, durum, tarih, cari_id, cari_kod, cari_adi, ilgili_hesap_adi,
          tutar, kur, aciklama, aciklama2, gecerlilik_tarihi, para_birimi,
          kullanici, search_tags, stok_rezerve_mi, created_at, updated_at
        FROM $backupName
        ON CONFLICT (id, tarih) DO NOTHING
      ''');

      // 5. Sequence güncelle
      final maxIdResult = await _pool!.execute(
        'SELECT COALESCE(MAX(id), 0) FROM $backupName',
      );
      final maxId = _toInt(maxIdResult.first[0]) ?? 1;
      await _pool!.execute("SELECT setval('quotes_id_seq', $maxId)");

      debugPrint('✅ TEKLİF MIGRATION SUCCESSFUL.');
    } catch (e) {
      debugPrint('TEKLİF MIGRATION FAILED: $e');
    }
  }

  Future<void> _ensurePartitionExists(
    DateTime date, {
    bool retry = true,
  }) async {
    if (_pool == null) return;
    try {
      final year = date.year;
      final month = date.month;
      final partitionName =
          'quotes_y${year}_m${month.toString().padLeft(2, '0')}';

      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final startStr =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-01';
      final endStr =
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-01';

      final check = await _pool!.execute(
        "SELECT 1 FROM pg_class WHERE relname = '$partitionName'",
      );

      if (check.isEmpty) {
        debugPrint(
          'Teklifler: Partition oluşturuluyor: $partitionName ($startStr - $endStr)',
        );
        await _pool!.execute('''
          CREATE TABLE IF NOT EXISTS $partitionName 
          PARTITION OF quotes 
          FOR VALUES FROM ('$startStr') TO ('$endStr')
        ''');
      }
    } catch (e) {
      if (retry && e.toString().contains('42P17')) {
        debugPrint(
          'Teklifler: Partition hatası (42P17) tespit edildi. Hızlı migrasyon başlatılıyor...',
        );
        await _migrateToPartitionedStructure();
        return _ensurePartitionExists(date, retry: false);
      }
      debugPrint('Teklif Partition kontrol hatası ($date): $e');
    }
  }

  Future<void> _recoverMissingPartition() async {
    debugPrint(
      'Teklifler: Eksik partition tespit edildi. Self-healing devreye giriyor...',
    );
    try {
      final now = DateTime.now();
      await _ensurePartitionExists(now);
      await _ensurePartitionExists(now.add(const Duration(days: 32)));
      await _ensurePartitionExists(now.subtract(const Duration(days: 32)));
      debugPrint('✅ Teklif Partition onarımı tamamlandı.');
    } catch (e) {
      debugPrint('Teklif Partition onarım hatası: $e');
    }
  }

  Future<void> _eksikKolonlariTamamla() async {
    // Mevcut kodlardaki ALTER TABLE komutlarının birleşimi
    // (Buraya dosyadaki tüm ALTER komutlarını taşıdım)
    final queries = [
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS integration_ref TEXT UNIQUE",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS tur TEXT NOT NULL DEFAULT 'Satış Teklifi'",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS durum TEXT NOT NULL DEFAULT 'Beklemede'",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS cari_id INTEGER",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS cari_kod TEXT",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS cari_adi TEXT",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS ilgili_hesap_adi TEXT",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS tutar NUMERIC DEFAULT 0",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS kur NUMERIC DEFAULT 1",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS aciklama TEXT",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS aciklama2 TEXT",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS gecerlilik_tarihi TIMESTAMP",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS para_birimi TEXT DEFAULT 'TRY'",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS kullanici TEXT",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS search_tags TEXT",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS quote_no TEXT",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP",
      "ALTER TABLE quotes ADD COLUMN IF NOT EXISTS stok_rezerve_mi BOOLEAN DEFAULT false",
      // quote_items
      "ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS urun_id INTEGER",
      "ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS urun_kodu TEXT DEFAULT ''",
      "ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS urun_adi TEXT DEFAULT ''",
      "ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS barkod TEXT",
      "ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS depo_id INTEGER",
      "ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS depo_adi TEXT",
      "ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS kdv_orani NUMERIC DEFAULT 0",
      "ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS miktar NUMERIC DEFAULT 0",
      "ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS birim TEXT DEFAULT 'Adet'",
      "ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS birim_fiyati NUMERIC DEFAULT 0",
      "ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS para_birimi TEXT DEFAULT 'TRY'",
      "ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS kdv_durumu TEXT DEFAULT 'excluded'",
      "ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS iskonto NUMERIC DEFAULT 0",
      "ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS toplam_fiyati NUMERIC DEFAULT 0",
    ];

    for (var q in queries) {
      try {
        await _pool!.execute(q);
      } catch (_) {}
    }
  }

  Future<String> _getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_username') ?? 'system';
  }

  Future<int> teklifEkle({
    required String tur,
    required String durum,
    required DateTime tarih,
    int? cariId,
    String? cariKod,
    String? cariAdi,
    required String ilgiliHesapAdi,
    required double tutar,
    required double kur,
    String? aciklama,
    String? aciklama2,
    DateTime? gecerlilikTarihi,
    required String paraBirimi,
    required List<Map<String, dynamic>> urunler,
    String? integrationRef,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return -1;

    final kullanici = await _getCurrentUser();
    final ref =
        integrationRef ??
        'QUOTE-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond % 1000}';

    final itemTags = urunler
        .map((u) {
          final miktar = (u['miktar'] as num?)?.toDouble() ?? 0;
          final iskonto = (u['iskonto'] as num?)?.toDouble() ?? 0;
          final birimFiyati = (u['birimFiyati'] as num?)?.toDouble() ?? 0;
          final toplamFiyati = (u['toplamFiyati'] as num?)?.toDouble() ?? 0;
          final kdvOrani = (u['kdvOrani'] as num?)?.toDouble() ?? 0;

          final kdvLabel =
              (u['kdvDurumu'] == 'included' || u['kdvDurumu'] == 'dahil')
              ? 'kdv dahil dahil'
              : 'kdv hariç hariç';

          return [
            u['urunKodu'] ?? '',
            u['urunAdi'] ?? '',
            u['barkod'] ?? '',
            u['depoAdi'] ?? '',
            kdvOrani.toString(),
            kdvOrani.toInt().toString(),
            u['kdvDurumu']?.toString() ?? '',
            kdvLabel,
            miktar.toString(),
            FormatYardimcisi.sayiFormatlaOndalikli(miktar),
            u['birim'] ?? '',
            iskonto.toString(),
            FormatYardimcisi.sayiFormatlaOndalikli(iskonto),
            birimFiyati.toString(),
            FormatYardimcisi.sayiFormatlaOndalikli(birimFiyati),
            toplamFiyati.toString(),
            FormatYardimcisi.sayiFormatlaOndalikli(toplamFiyati),
          ].join(' ').toLowerCase();
        })
        .join(' ');

    final searchTags = [
      tur,
      durum,
      DateFormat('dd.MM.yyyy HH:mm').format(tarih),
      cariKod ?? '',
      cariAdi ?? '',
      ilgiliHesapAdi,
      tutar.toString(),
      FormatYardimcisi.sayiFormatlaOndalikli(tutar),
      kur.toString(),
      FormatYardimcisi.sayiFormatlaOndalikli(kur),
      aciklama ?? '',
      aciklama2 ?? '',
      gecerlilikTarihi != null
          ? DateFormat('dd.MM.yyyy').format(gecerlilikTarihi)
          : '',
      paraBirimi,
      kullanici,
      ref,
      '|v6|',
      itemTags,
    ].join(' ').toLowerCase();

    final quoteNo = ref;

    try {
      return await _pool!.runTx((ctx) async {
        final result = await ctx.execute(
          Sql.named('''
            INSERT INTO quotes (
              integration_ref, quote_no, tur, durum, tarih, cari_id, cari_kod, cari_adi, ilgili_hesap_adi,
              tutar, kur, aciklama, aciklama2, gecerlilik_tarihi, para_birimi,
              kullanici, search_tags
            ) VALUES (
              @ref, @quoteNo, @tur, @durum, @tarih, @cariId, @cariKod, @cariAdi, @ilgiliHesapAdi,
              @tutar, @kur, @aciklama, @aciklama2, @gecerlilikTarihi, @paraBirimi,
              @kullanici, @searchTags
            ) RETURNING id
          '''),
          parameters: {
            'ref': ref,
            'quoteNo': quoteNo,
            'tur': tur,
            'durum': durum,
            'tarih': tarih,
            'cariId': cariId,
            'cariKod': cariKod,
            'cariAdi': cariAdi,
            'ilgiliHesapAdi': ilgiliHesapAdi,
            'tutar': tutar,
            'kur': kur,
            'aciklama': aciklama,
            'aciklama2': aciklama2,
            'gecerlilikTarihi': gecerlilikTarihi,
            'paraBirimi': paraBirimi,
            'kullanici': kullanici,
            'searchTags': searchTags,
          },
        );

        final quoteId = _toInt(result.first[0]) ?? 0;
        if (quoteId == 0) return 0;

        if (urunler.isNotEmpty) {
          for (var urun in urunler) {
            await ctx.execute(
              Sql.named('''
                INSERT INTO quote_items (
                  quote_id, urun_id, urun_kodu, urun_adi, barkod, depo_id, depo_adi,
                  kdv_orani, miktar, birim, birim_fiyati, para_birimi, kdv_durumu,
                  iskonto, toplam_fiyati
                ) VALUES (
                  @quoteId, @urunId, @urunKodu, @urunAdi, @barkod, @depoId, @depoAdi,
                  @kdvOrani, @miktar, @birim, @birimFiyati, @paraBirimi, @kdvDurumu,
                  @iskonto, @toplamFiyati
                )
              '''),
              parameters: {
                'quoteId': quoteId,
                'urunId': urun['urunId'],
                'urunKodu': urun['urunKodu'] ?? '',
                'urunAdi': urun['urunAdi'] ?? '',
                'barkod': urun['barkod'] ?? '',
                'depoId': urun['depoId'],
                'depoAdi': urun['depoAdi'] ?? '',
                'kdvOrani': urun['kdvOrani'] ?? 0,
                'miktar': urun['miktar'] ?? 0,
                'birim': urun['birim'] ?? 'Adet',
                'birimFiyati': urun['birimFiyati'] ?? 0,
                'paraBirimi': urun['paraBirimi'] ?? 'TRY',
                'kdvDurumu': urun['kdvDurumu'] ?? 'excluded',
                'iskonto': urun['iskonto'] ?? 0,
                'toplamFiyati': urun['toplamFiyati'] ?? 0,
              },
            );
          }
        }

        // [STOCK RESERVATION] Eğer durum 'Onaylandı' ise stokları rezerve et
        if (durum == 'Onaylandı') {
          await _teklifStokRezervasyonunuYonet(
            ctx: ctx,
            quoteId: quoteId,
            isArtis: true,
          );
        }

        return quoteId;
      });
    } catch (e) {
      if (e.toString().contains('23514') ||
          e.toString().contains('no partition of relation')) {
        debugPrint(
          'Teklif eklerken partition hatası algılandı. Onarım devreye giriyor...',
        );
        await _recoverMissingPartition();
        try {
          return await teklifEkle(
            tur: tur,
            durum: durum,
            tarih: tarih,
            cariId: cariId,
            cariKod: cariKod,
            cariAdi: cariAdi,
            ilgiliHesapAdi: ilgiliHesapAdi,
            tutar: tutar,
            kur: kur,
            aciklama: aciklama,
            aciklama2: aciklama2,
            gecerlilikTarihi: gecerlilikTarihi,
            paraBirimi: paraBirimi,
            urunler: urunler,
            integrationRef: integrationRef,
          );
        } catch (e2) {
          debugPrint('Düzeltme sonrası tekrar deneme başarısız: $e2');
          return -1;
        }
      }
      debugPrint('Teklif ekleme hatası: $e');
      return -1;
    }
  }

  Future<List<TeklifModel>> teklifleriGetir({
    int sayfa = 1,
    int sayfaBasinaKayit = 25,
    String? aramaTerimi,
    String? sortBy,
    bool sortAscending = true,
    String? durum,
    String? tur,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    int? depoId,
    String? birim,
    String? ilgiliHesapAdi,
    String? kullanici,
    int? lastId,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    String sortColumn = 'id';
    switch (sortBy) {
      case 'tarih':
        sortColumn = 'tarih';
        break;
      case 'tutar':
        sortColumn = 'tutar';
        break;
      case 'durum':
        sortColumn = 'durum';
        break;
      default:
        sortColumn = 'id';
    }
    String direction = sortAscending ? 'ASC' : 'DESC';

    List<String> whereConditions = [];
    Map<String, dynamic> params = {};

    String selectCols = 'quotes.*';

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      whereConditions.add('search_tags ILIKE @search');
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
      selectCols += ''', (CASE 
          WHEN search_tags ILIKE @search 
               AND NOT (
                 COALESCE(id::text, '') ILIKE @search OR
                 COALESCE(tur, '') ILIKE @search OR 
                 COALESCE(durum, '') ILIKE @search OR 
                 COALESCE(TO_CHAR(tarih, 'DD.MM.YYYY'), '') ILIKE @search OR
                 COALESCE(cari_adi, '') ILIKE @search OR
                 COALESCE(ilgili_hesap_adi, '') ILIKE @search OR
                 COALESCE(tutar::text, '') ILIKE @search OR
                 COALESCE(kur::text, '') ILIKE @search OR
                 COALESCE(aciklama, '') ILIKE @search OR
                 COALESCE(aciklama2, '') ILIKE @search OR
                 COALESCE(TO_CHAR(gecerlilik_tarihi, 'DD.MM.YYYY'), '') ILIKE @search OR
                 COALESCE(kullanici, '') ILIKE @search OR
                 COALESCE(para_birimi, '') ILIKE @search OR
                 COALESCE(integration_ref, '') ILIKE @search
               )
          THEN true 
          ELSE false 
         END) as matched_in_hidden''';
    } else {
      selectCols += ', false as matched_in_hidden';
    }

    if (durum != null) {
      whereConditions.add('durum = @durum');
      params['durum'] = durum;
    }

    if (tur != null) {
      whereConditions.add('tur = @tur');
      params['tur'] = tur;
    }

    // [2026 SARGABLE] Tarih aralığı (gün bazlı, end-exclusive)
    if (baslangicTarihi != null) {
      whereConditions.add('tarih >= @start');
      params['start'] = DateTime(
        baslangicTarihi.year,
        baslangicTarihi.month,
        baslangicTarihi.day,
      );
    }
    if (bitisTarihi != null) {
      whereConditions.add('tarih < @end');
      params['end'] = DateTime(
        bitisTarihi.year,
        bitisTarihi.month,
        bitisTarihi.day,
      ).add(const Duration(days: 1));
    }

    if (ilgiliHesapAdi != null && ilgiliHesapAdi.trim().isNotEmpty) {
      whereConditions.add('ilgili_hesap_adi = @ilgiliHesapAdi');
      params['ilgiliHesapAdi'] = ilgiliHesapAdi.trim();
    }

    if (kullanici != null && kullanici.trim().isNotEmpty) {
      whereConditions.add('kullanici = @kullanici');
      params['kullanici'] = kullanici.trim();
    }

    // [ITEM FILTER] Depo + Birim aynı satırda (intersection)
    if (depoId != null || (birim != null && birim.trim().isNotEmpty)) {
      String existsQuery =
          'EXISTS (SELECT 1 FROM quote_items qi WHERE qi.quote_id = quotes.id';
      if (depoId != null) {
        existsQuery += ' AND qi.depo_id = @depoId';
        params['depoId'] = depoId;
      }
      if (birim != null && birim.trim().isNotEmpty) {
        existsQuery += ' AND qi.birim = @birim';
        params['birim'] = birim.trim();
      }
      existsQuery += ')';
      whereConditions.add(existsQuery);
    }

    if (lastId != null) {
      if (sortColumn == 'id') {
        if (direction == 'ASC') {
          whereConditions.add('id > @lastId');
        } else {
          whereConditions.add('id < @lastId');
        }
        params['lastId'] = lastId;
      } else {
        // [2025 ELITE] Keyset pagination for non-ID columns
        whereConditions.add('id ${direction == 'ASC' ? '>' : '<'} @lastId');
        params['lastId'] = lastId;
      }
    }

    String whereClause = whereConditions.isEmpty
        ? ''
        : 'WHERE ${whereConditions.join(' AND ')}';

    // Keyset pagination kullanılırken OFFSET 0 yapılır.
    final finalOffset = lastId != null ? 0 : (sayfa - 1) * sayfaBasinaKayit;

    final result = await _pool!.execute(
      Sql.named('''
        SELECT $selectCols 
        FROM quotes 
        $whereClause 
        ORDER BY $sortColumn $direction 
        LIMIT @limit OFFSET @offset
      '''),
      parameters: {...params, 'limit': sayfaBasinaKayit, 'offset': finalOffset},
    );

    List<TeklifModel> list = [];
    for (final row in result) {
      final map = row.toColumnMap();
      final quoteId = _toInt(map['id']) ?? 0;
      if (quoteId == 0) continue;

      final itemRows = await _pool!.execute(
        Sql.named(
          'SELECT * FROM quote_items WHERE quote_id = @id ORDER BY id ASC',
        ),
        parameters: {'id': quoteId},
      );

      final items = itemRows.map((ir) {
        final im = ir.toColumnMap();
        return TeklifUrunModel(
          id: _toInt(im['id']) ?? 0,
          urunId: _toInt(im['urun_id']) ?? 0,
          urunKodu: _toString(im['urun_kodu']),
          urunAdi: _toString(im['urun_adi']),
          barkod: _toString(im['barkod']),
          depoId: _toInt(im['depo_id']),
          depoAdi: _toString(im['depo_adi']),
          kdvOrani: _toDouble(im['kdv_orani']),
          miktar: _toDouble(im['miktar']),
          birim: _toString(im['birim'], 'Adet'),
          birimFiyati: _toDouble(im['birim_fiyati']),
          toplamFiyati: _toDouble(im['toplam_fiyati']),
          paraBirimi: _toString(im['para_birimi'], 'TRY'),
          kdvDurumu: _toString(im['kdv_durumu'], 'excluded'),
          iskonto: _toDouble(im['iskonto']),
        );
      }).toList();

      DateTime tarih;
      if (map['tarih'] is DateTime) {
        tarih = map['tarih'] as DateTime;
      } else if (map['tarih'] is String) {
        tarih = DateTime.tryParse(map['tarih'] as String) ?? DateTime.now();
      } else {
        tarih = DateTime.now();
      }

      DateTime? gecerlilikTarihi;
      if (map['gecerlilik_tarihi'] is DateTime) {
        gecerlilikTarihi = map['gecerlilik_tarihi'] as DateTime;
      } else if (map['gecerlilik_tarihi'] is String) {
        gecerlilikTarihi = DateTime.tryParse(
          map['gecerlilik_tarihi'] as String,
        );
      }

      list.add(
        TeklifModel(
          id: quoteId,
          tur: _toString(map['tur'], 'Satış Teklifi'),
          durum: _toString(map['durum'], 'Beklemede'),
          tarih: tarih,
          cariId: _toInt(map['cari_id']),
          cariKod: _toString(map['cari_kod']),
          cariAdi: _toString(map['cari_adi']),
          ilgiliHesapAdi: _toString(map['ilgili_hesap_adi']),
          tutar: _toDouble(map['tutar']),
          kur: _toDouble(map['kur'], 1),
          aciklama: _toString(map['aciklama']),
          aciklama2: _toString(map['aciklama2']),
          gecerlilikTarihi: gecerlilikTarihi,
          paraBirimi: _toString(map['para_birimi'], 'TRY'),
          kullanici: _toString(map['kullanici'], 'system'),
          integrationRef: _toString(map['integration_ref']),
          quoteNo: _toString(map['quote_no']),
          urunler: items,
          matchedInHidden: map['matched_in_hidden'] == true,
        ),
      );
    }

    return list;
  }

  Future<int> teklifSayisiGetir({
    String? aramaTerimi,
    String? durum,
    String? tur,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    int? depoId,
    String? birim,
    String? ilgiliHesapAdi,
    String? kullanici,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;

    String query = 'SELECT 1 FROM quotes';
    List<String> whereConditions = [];
    Map<String, dynamic> params = {};

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      whereConditions.add('search_tags ILIKE @search');
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
    }

    if (durum != null) {
      whereConditions.add('durum = @durum');
      params['durum'] = durum;
    }

    if (tur != null) {
      whereConditions.add('tur = @tur');
      params['tur'] = tur;
    }

    // [2026 SARGABLE] Tarih aralığı (gün bazlı, end-exclusive)
    if (baslangicTarihi != null) {
      whereConditions.add('tarih >= @start');
      params['start'] = DateTime(
        baslangicTarihi.year,
        baslangicTarihi.month,
        baslangicTarihi.day,
      );
    }
    if (bitisTarihi != null) {
      whereConditions.add('tarih < @end');
      params['end'] = DateTime(
        bitisTarihi.year,
        bitisTarihi.month,
        bitisTarihi.day,
      ).add(const Duration(days: 1));
    }

    if (ilgiliHesapAdi != null && ilgiliHesapAdi.trim().isNotEmpty) {
      whereConditions.add('ilgili_hesap_adi = @ilgiliHesapAdi');
      params['ilgiliHesapAdi'] = ilgiliHesapAdi.trim();
    }

    if (kullanici != null && kullanici.trim().isNotEmpty) {
      whereConditions.add('kullanici = @kullanici');
      params['kullanici'] = kullanici.trim();
    }

    // [ITEM FILTER] Depo + Birim aynı satırda (intersection)
    if (depoId != null || (birim != null && birim.trim().isNotEmpty)) {
      String existsQuery =
          'EXISTS (SELECT 1 FROM quote_items qi WHERE qi.quote_id = quotes.id';
      if (depoId != null) {
        existsQuery += ' AND qi.depo_id = @depoId';
        params['depoId'] = depoId;
      }
      if (birim != null && birim.trim().isNotEmpty) {
        existsQuery += ' AND qi.birim = @birim';
        params['birim'] = birim.trim();
      }
      existsQuery += ')';
      whereConditions.add(existsQuery);
    }

    if (whereConditions.isNotEmpty) {
      query += ' WHERE ${whereConditions.join(' AND ')}';
    }

    // [2025 CAPPED COUNT]
    query += ' LIMIT 100001';

    final countQuery = 'SELECT COUNT(*) FROM ($query) AS sub';

    final result = await _pool!.execute(
      Sql.named(countQuery),
      parameters: params,
    );

    return _toInt(result.first[0]) ?? 0;
  }

  /// [2026 HYPER-SPEED] Dinamik filtre seçeneklerini ve sayıları getirir.
  /// Büyük veri için optimize edilmiştir (SARGable predicates + EXISTS + capped queries).
  Future<Map<String, Map<String, int>>> teklifFiltreIstatistikleriniGetir({
    String? aramaTerimi,
    String? tur,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? durum,
    int? depoId,
    String? birim,
    String? ilgiliHesapAdi,
    String? kullanici,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return {};

    final selectedTur = tur != null && tur.trim().isNotEmpty
        ? tur.trim()
        : null;

    Map<String, dynamic> params = {};
    List<String> baseConditions = [];

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      baseConditions.add('search_tags ILIKE @search');
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
    }

    // NOTE: "tur" seçimi facet olduğu için base koşullara eklenmiyor.

    if (baslangicTarihi != null) {
      baseConditions.add('tarih >= @start');
      params['start'] = DateTime(
        baslangicTarihi.year,
        baslangicTarihi.month,
        baslangicTarihi.day,
      );
    }
    if (bitisTarihi != null) {
      baseConditions.add('tarih < @end');
      params['end'] = DateTime(
        bitisTarihi.year,
        bitisTarihi.month,
        bitisTarihi.day,
      ).add(const Duration(days: 1));
    }

    String buildQuoteCappedGroupQuery(
      String selectAndGroup,
      List<String> facetConds,
    ) {
      final allConds = [...baseConditions, ...facetConds];
      final where = allConds.isEmpty ? '' : 'WHERE ${allConds.join(' AND ')}';
      return 'SELECT $selectAndGroup FROM (SELECT * FROM quotes $where LIMIT 100001) as sub GROUP BY 1';
    }

    // 1) Durumlar (exclude "durum")
    List<String> statusConds = [];
    Map<String, dynamic> statusParams = Map.from(params);
    if (selectedTur != null) {
      statusConds.add('tur = @tur');
      statusParams['tur'] = selectedTur;
    }
    if (ilgiliHesapAdi != null && ilgiliHesapAdi.trim().isNotEmpty) {
      statusConds.add('ilgili_hesap_adi = @ilgiliHesapAdi');
      statusParams['ilgiliHesapAdi'] = ilgiliHesapAdi.trim();
    }
    if (kullanici != null && kullanici.trim().isNotEmpty) {
      statusConds.add('kullanici = @kullanici');
      statusParams['kullanici'] = kullanici.trim();
    }
    if (depoId != null || (birim != null && birim.trim().isNotEmpty)) {
      String existsQuery =
          'EXISTS (SELECT 1 FROM quote_items qi WHERE qi.quote_id = quotes.id';
      if (depoId != null) {
        existsQuery += ' AND qi.depo_id = @depoId';
        statusParams['depoId'] = depoId;
      }
      if (birim != null && birim.trim().isNotEmpty) {
        existsQuery += ' AND qi.birim = @birim';
        statusParams['birim'] = birim.trim();
      }
      existsQuery += ')';
      statusConds.add(existsQuery);
    }

    // 2) Türler (exclude "tur")
    List<String> typeConds = [];
    Map<String, dynamic> typeParams = Map.from(params);
    if (durum != null && durum.trim().isNotEmpty) {
      typeConds.add('durum = @durum');
      typeParams['durum'] = durum.trim();
    }
    if (ilgiliHesapAdi != null && ilgiliHesapAdi.trim().isNotEmpty) {
      typeConds.add('ilgili_hesap_adi = @ilgiliHesapAdi');
      typeParams['ilgiliHesapAdi'] = ilgiliHesapAdi.trim();
    }
    if (kullanici != null && kullanici.trim().isNotEmpty) {
      typeConds.add('kullanici = @kullanici');
      typeParams['kullanici'] = kullanici.trim();
    }
    if (depoId != null || (birim != null && birim.trim().isNotEmpty)) {
      String existsQuery =
          'EXISTS (SELECT 1 FROM quote_items qi WHERE qi.quote_id = quotes.id';
      if (depoId != null) {
        existsQuery += ' AND qi.depo_id = @depoId';
        typeParams['depoId'] = depoId;
      }
      if (birim != null && birim.trim().isNotEmpty) {
        existsQuery += ' AND qi.birim = @birim';
        typeParams['birim'] = birim.trim();
      }
      existsQuery += ')';
      typeConds.add(existsQuery);
    }

    // 2) Depolar (exclude "depoId")
    List<String> depotOrderConds = [];
    Map<String, dynamic> depotParams = Map.from(params);
    if (selectedTur != null) {
      depotOrderConds.add('tur = @tur');
      depotParams['tur'] = selectedTur;
    }
    if (durum != null && durum.trim().isNotEmpty) {
      depotOrderConds.add('durum = @durum');
      depotParams['durum'] = durum.trim();
    }
    if (ilgiliHesapAdi != null && ilgiliHesapAdi.trim().isNotEmpty) {
      depotOrderConds.add('ilgili_hesap_adi = @ilgiliHesapAdi');
      depotParams['ilgiliHesapAdi'] = ilgiliHesapAdi.trim();
    }
    if (kullanici != null && kullanici.trim().isNotEmpty) {
      depotOrderConds.add('kullanici = @kullanici');
      depotParams['kullanici'] = kullanici.trim();
    }
    final selectedUnit = birim != null && birim.trim().isNotEmpty
        ? birim.trim()
        : null;
    if (selectedUnit != null) depotParams['birim'] = selectedUnit;

    // 3) Birimler (exclude "birim")
    List<String> unitOrderConds = [];
    Map<String, dynamic> unitParams = Map.from(params);
    if (selectedTur != null) {
      unitOrderConds.add('tur = @tur');
      unitParams['tur'] = selectedTur;
    }
    if (durum != null && durum.trim().isNotEmpty) {
      unitOrderConds.add('durum = @durum');
      unitParams['durum'] = durum.trim();
    }
    if (ilgiliHesapAdi != null && ilgiliHesapAdi.trim().isNotEmpty) {
      unitOrderConds.add('ilgili_hesap_adi = @ilgiliHesapAdi');
      unitParams['ilgiliHesapAdi'] = ilgiliHesapAdi.trim();
    }
    if (kullanici != null && kullanici.trim().isNotEmpty) {
      unitOrderConds.add('kullanici = @kullanici');
      unitParams['kullanici'] = kullanici.trim();
    }
    final selectedDepotId = depoId;
    if (selectedDepotId != null) unitParams['depoId'] = selectedDepotId;

    // 4) Hesaplar (exclude "ilgiliHesapAdi")
    List<String> accountConds = [];
    Map<String, dynamic> accountParams = Map.from(params);
    if (selectedTur != null) {
      accountConds.add('tur = @tur');
      accountParams['tur'] = selectedTur;
    }
    if (durum != null && durum.trim().isNotEmpty) {
      accountConds.add('durum = @durum');
      accountParams['durum'] = durum.trim();
    }
    if (kullanici != null && kullanici.trim().isNotEmpty) {
      accountConds.add('kullanici = @kullanici');
      accountParams['kullanici'] = kullanici.trim();
    }
    if (depoId != null || (birim != null && birim.trim().isNotEmpty)) {
      String existsQuery =
          'EXISTS (SELECT 1 FROM quote_items qi WHERE qi.quote_id = quotes.id';
      if (depoId != null) {
        existsQuery += ' AND qi.depo_id = @depoId';
        accountParams['depoId'] = depoId;
      }
      if (birim != null && birim.trim().isNotEmpty) {
        existsQuery += ' AND qi.birim = @birim';
        accountParams['birim'] = birim.trim();
      }
      existsQuery += ')';
      accountConds.add(existsQuery);
    }

    // 5) Kullanıcılar (exclude "kullanici")
    List<String> userConds = [];
    Map<String, dynamic> userParams = Map.from(params);
    if (selectedTur != null) {
      userConds.add('tur = @tur');
      userParams['tur'] = selectedTur;
    }
    if (durum != null && durum.trim().isNotEmpty) {
      userConds.add('durum = @durum');
      userParams['durum'] = durum.trim();
    }
    if (ilgiliHesapAdi != null && ilgiliHesapAdi.trim().isNotEmpty) {
      userConds.add('ilgili_hesap_adi = @ilgiliHesapAdi');
      userParams['ilgiliHesapAdi'] = ilgiliHesapAdi.trim();
    }
    if (depoId != null || (birim != null && birim.trim().isNotEmpty)) {
      String existsQuery =
          'EXISTS (SELECT 1 FROM quote_items qi WHERE qi.quote_id = quotes.id';
      if (depoId != null) {
        existsQuery += ' AND qi.depo_id = @depoId';
        userParams['depoId'] = depoId;
      }
      if (birim != null && birim.trim().isNotEmpty) {
        existsQuery += ' AND qi.birim = @birim';
        userParams['birim'] = birim.trim();
      }
      existsQuery += ')';
      userConds.add(existsQuery);
    }

    // Toplam (seçili filtrelerle)
    final totalParams = Map<String, dynamic>.from(params);
    final totalConds = <String>[...baseConditions];
    if (selectedTur != null) {
      totalConds.add('tur = @tur');
      totalParams['tur'] = selectedTur;
    }
    if (durum != null && durum.trim().isNotEmpty) {
      totalConds.add('durum = @durum');
      totalParams['durum'] = durum.trim();
    }
    if (ilgiliHesapAdi != null && ilgiliHesapAdi.trim().isNotEmpty) {
      totalConds.add('ilgili_hesap_adi = @ilgiliHesapAdi');
      totalParams['ilgiliHesapAdi'] = ilgiliHesapAdi.trim();
    }
    if (kullanici != null && kullanici.trim().isNotEmpty) {
      totalConds.add('kullanici = @kullanici');
      totalParams['kullanici'] = kullanici.trim();
    }
    if (depoId != null || (birim != null && birim.trim().isNotEmpty)) {
      String existsQuery =
          'EXISTS (SELECT 1 FROM quote_items qi WHERE qi.quote_id = quotes.id';
      if (depoId != null) {
        existsQuery += ' AND qi.depo_id = @depoId';
        totalParams['depoId'] = depoId;
      }
      if (birim != null && birim.trim().isNotEmpty) {
        existsQuery += ' AND qi.birim = @birim';
        totalParams['birim'] = birim.trim();
      }
      existsQuery += ')';
      totalConds.add(existsQuery);
    }
    final totalWhere = totalConds.isEmpty
        ? ''
        : 'WHERE ${totalConds.join(' AND ')}';
    final totalQuery =
        'SELECT COUNT(*) FROM (SELECT 1 FROM quotes $totalWhere LIMIT 100001) as sub';

    final depotQuery =
        '''
      WITH filtered_quotes AS (
        SELECT id FROM quotes ${([...baseConditions, ...depotOrderConds]).isEmpty ? '' : 'WHERE ${([...baseConditions, ...depotOrderConds]).join(' AND ')}'} LIMIT 100001
      )
      SELECT qi.depo_id, COUNT(DISTINCT fq.id)
      FROM filtered_quotes fq
      JOIN quote_items qi ON qi.quote_id = fq.id
      ${selectedUnit != null ? 'WHERE qi.birim = @birim' : ''}
      GROUP BY qi.depo_id
    ''';

    final unitQuery =
        '''
      WITH filtered_quotes AS (
        SELECT id FROM quotes ${([...baseConditions, ...unitOrderConds]).isEmpty ? '' : 'WHERE ${([...baseConditions, ...unitOrderConds]).join(' AND ')}'} LIMIT 100001
      )
      SELECT qi.birim, COUNT(DISTINCT fq.id)
      FROM filtered_quotes fq
      JOIN quote_items qi ON qi.quote_id = fq.id
      ${selectedDepotId != null ? 'WHERE qi.depo_id = @depoId' : ''}
      GROUP BY qi.birim
    ''';

    final results = await Future.wait([
      _pool!.execute(Sql.named(totalQuery), parameters: totalParams),
      _pool!.execute(
        Sql.named(buildQuoteCappedGroupQuery('durum, COUNT(*)', statusConds)),
        parameters: statusParams,
      ),
      _pool!.execute(
        Sql.named(buildQuoteCappedGroupQuery('tur, COUNT(*)', typeConds)),
        parameters: typeParams,
      ),
      _pool!.execute(Sql.named(depotQuery), parameters: depotParams),
      _pool!.execute(Sql.named(unitQuery), parameters: unitParams),
      _pool!.execute(
        Sql.named(
          buildQuoteCappedGroupQuery(
            'ilgili_hesap_adi, COUNT(*)',
            accountConds,
          ),
        ),
        parameters: accountParams,
      ),
      _pool!.execute(
        Sql.named(buildQuoteCappedGroupQuery('kullanici, COUNT(*)', userConds)),
        parameters: userParams,
      ),
    ]);

    Map<String, Map<String, int>> stats = {
      'ozet': {'toplam': _toInt(results[0][0][0]) ?? 0},
      'durumlar': {},
      'turler': {},
      'depolar': {},
      'birimler': {},
      'hesaplar': {},
      'kullanicilar': {},
    };

    for (final row in results[1]) {
      final key = row[0]?.toString();
      if (key != null && key.isNotEmpty) {
        stats['durumlar']![key] = row[1] as int;
      }
    }

    for (final row in results[2]) {
      final key = row[0]?.toString();
      if (key != null && key.isNotEmpty) {
        stats['turler']![key] = row[1] as int;
      }
    }

    for (final row in results[3]) {
      if (row[0] != null) {
        stats['depolar']![row[0].toString()] = row[1] as int;
      }
    }

    for (final row in results[4]) {
      final key = row[0]?.toString();
      if (key != null && key.isNotEmpty) {
        stats['birimler']![key] = row[1] as int;
      }
    }

    for (final row in results[5]) {
      final key = row[0]?.toString();
      if (key != null && key.isNotEmpty) {
        stats['hesaplar']![key] = row[1] as int;
      }
    }

    for (final row in results[6]) {
      final key = row[0]?.toString();
      if (key != null && key.isNotEmpty) {
        stats['kullanicilar']![key] = row[1] as int;
      }
    }

    return stats;
  }

  Future<bool> teklifSil(int id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    return await _pool!.runTx((ctx) async {
      // [STOCK RESERVATION] Silmeden önce eğer rezerve edilmişse çöz
      final checkStatus = await ctx.execute(
        Sql.named('SELECT stok_rezerve_mi FROM quotes WHERE id = @id'),
        parameters: {'id': id},
      );
      if (checkStatus.isNotEmpty && checkStatus.first[0] == true) {
        await _teklifStokRezervasyonunuYonet(
          ctx: ctx,
          quoteId: id,
          isArtis: false,
        );
      }

      await ctx.execute(
        Sql.named('DELETE FROM quote_items WHERE quote_id = @id'),
        parameters: {'id': id},
      );
      final result = await ctx.execute(
        Sql.named('DELETE FROM quotes WHERE id = @id'),
        parameters: {'id': id},
      );
      return result.affectedRows > 0;
    });
  }

  Future<bool> topluTeklifSil(List<int> ids) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    return await _pool!.runTx((ctx) async {
      for (var id in ids) {
        await ctx.execute(
          Sql.named('DELETE FROM quote_items WHERE quote_id = @id'),
          parameters: {'id': id},
        );
        await ctx.execute(
          Sql.named('DELETE FROM quotes WHERE id = @id'),
          parameters: {'id': id},
        );
      }
      return true;
    });
  }

  Future<bool> teklifDurumGuncelle(
    int id,
    String durum, {
    TxSession? session,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    try {
      final executor = session ?? _pool!;
      await executor.execute(
        Sql.named(
          'UPDATE quotes SET durum = @durum, updated_at = CURRENT_TIMESTAMP WHERE id = @id',
        ),
        parameters: {'id': id, 'durum': durum},
      );
      return true;
    } catch (e) {
      if (e.toString().contains('23514') ||
          e.toString().contains('no partition of relation')) {
        debugPrint(
          'Teklif durum güncellerken partition hatası algılandı. Onarılıyor...',
        );
        await _recoverMissingPartition();
        try {
          return await teklifDurumGuncelle(id, durum, session: session);
        } catch (_) {
          return false;
        }
      }
      debugPrint('Teklif durum güncelleme hatası: $e');
      return false;
    }
  }

  Future<bool> teklifTurVeDurumGuncelle(
    int id,
    String tur,
    String durum,
  ) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    try {
      await _pool!.execute(
        Sql.named(
          'UPDATE quotes SET tur = @tur, durum = @durum, updated_at = CURRENT_TIMESTAMP WHERE id = @id',
        ),
        parameters: {'id': id, 'tur': tur, 'durum': durum},
      );
      return true;
    } catch (e) {
      if (e.toString().contains('23514') ||
          e.toString().contains('no partition of relation')) {
        debugPrint(
          'Teklif tür/durum güncellerken partition hatası algılandı. Onarılıyor...',
        );
        await _recoverMissingPartition();
        try {
          return await teklifTurVeDurumGuncelle(id, tur, durum);
        } catch (_) {
          return false;
        }
      }
      debugPrint('Teklif tür ve durum güncelleme hatası: $e');
      return false;
    }
  }

  Future<bool> teklifGuncelle({
    required int id,
    required String tur,
    required String durum,
    required DateTime tarih,
    int? cariId,
    String? cariKod,
    String? cariAdi,
    required String ilgiliHesapAdi,
    required double tutar,
    required double kur,
    String? aciklama,
    String? aciklama2,
    DateTime? gecerlilikTarihi,
    required String paraBirimi,
    required List<Map<String, dynamic>> urunler,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    final kullanici = await _getCurrentUser();

    try {
      return await _pool!.runTx((ctx) async {
        // [STOCK RESERVATION] Güncellemeden önce eğer rezerve edilmişse çöz
        final checkStatus = await ctx.execute(
          Sql.named('SELECT stok_rezerve_mi FROM quotes WHERE id = @id'),
          parameters: {'id': id},
        );
        if (checkStatus.isNotEmpty && checkStatus.first[0] == true) {
          await _teklifStokRezervasyonunuYonet(
            ctx: ctx,
            quoteId: id,
            isArtis: false,
          );
        }

        final String professionalTur = IslemTuruRenkleri.getProfessionalLabel(
          tur,
          context: 'cari',
        );

        final itemTags = urunler
            .map((u) {
              final miktar = (u['miktar'] as num?)?.toDouble() ?? 0;
              final iskonto = (u['iskonto'] as num?)?.toDouble() ?? 0;
              final birimFiyati = (u['birimFiyati'] as num?)?.toDouble() ?? 0;
              final toplamFiyati = (u['toplamFiyati'] as num?)?.toDouble() ?? 0;
              final kdvOrani = (u['kdvOrani'] as num?)?.toDouble() ?? 0;
              final kdvLabel =
                  (u['kdvDurumu'] == 'included' || u['kdvDurumu'] == 'dahil')
                  ? 'kdv dahil dahil'
                  : 'kdv hariç hariç';

              return [
                u['urunKodu'] ?? '',
                u['urunAdi'] ?? '',
                u['barkod'] ?? '',
                u['depoAdi'] ?? '',
                kdvOrani.toString(),
                kdvOrani.toInt().toString(),
                u['kdvDurumu']?.toString() ?? '',
                kdvLabel,
                miktar.toString(),
                FormatYardimcisi.sayiFormatlaOndalikli(miktar),
                u['birim'] ?? '',
                iskonto.toString(),
                FormatYardimcisi.sayiFormatlaOndalikli(iskonto),
                birimFiyati.toString(),
                FormatYardimcisi.sayiFormatlaOndalikli(birimFiyati),
                toplamFiyati.toString(),
                FormatYardimcisi.sayiFormatlaOndalikli(toplamFiyati),
              ].join(' ').toLowerCase();
            })
            .join(' ');

        final searchTags = [
          professionalTur,
          durum,
          DateFormat('dd.MM.yyyy').format(tarih),
          cariKod ?? '',
          cariAdi ?? '',
          ilgiliHesapAdi,
          tutar.toString(),
          FormatYardimcisi.sayiFormatlaOndalikli(tutar),
          kur.toString(),
          FormatYardimcisi.sayiFormatlaOndalikli(kur),
          aciklama ?? '',
          aciklama2 ?? '',
          gecerlilikTarihi != null
              ? DateFormat('dd.MM.yyyy').format(gecerlilikTarihi)
              : '',
          paraBirimi,
          kullanici,
          '|v5|',
          itemTags,
        ].join(' ').toLowerCase();

        await ctx.execute(
          Sql.named('''
            UPDATE quotes SET
              tur = @tur, durum = @durum, tarih = @tarih, cari_id = @cariId,
              cari_kod = @cariKod, cari_adi = @cariAdi, ilgili_hesap_adi = @ilgiliHesapAdi,
              tutar = @tutar, kur = @kur, aciklama = @aciklama, aciklama2 = @aciklama2,
              gecerlilik_tarihi = @gecerlilikTarihi, para_birimi = @paraBirimi,
              kullanici = @kullanici, search_tags = @searchTags, updated_at = CURRENT_TIMESTAMP
            WHERE id = @id
          '''),
          parameters: {
            'id': id,
            'tur': tur,
            'durum': durum,
            'tarih': tarih,
            'cariId': cariId,
            'cariKod': cariKod,
            'cariAdi': cariAdi,
            'ilgiliHesapAdi': ilgiliHesapAdi,
            'tutar': tutar,
            'kur': kur,
            'aciklama': aciklama,
            'aciklama2': aciklama2,
            'gecerlilikTarihi': gecerlilikTarihi,
            'paraBirimi': paraBirimi,
            'kullanici': kullanici,
            'searchTags': searchTags,
          },
        );

        await ctx.execute(
          Sql.named('DELETE FROM quote_items WHERE quote_id = @id'),
          parameters: {'id': id},
        );

        if (urunler.isNotEmpty) {
          for (var urun in urunler) {
            await ctx.execute(
              Sql.named('''
                INSERT INTO quote_items (
                  quote_id, urun_id, urun_kodu, urun_adi, barkod, depo_id, depo_adi,
                  kdv_orani, miktar, birim, birim_fiyati, para_birimi, kdv_durumu,
                  iskonto, toplam_fiyati
                ) VALUES (
                  @quoteId, @urunId, @urunKodu, @urunAdi, @barkod, @depoId, @depoAdi,
                  @kdvOrani, @miktar, @birim, @birimFiyati, @paraBirimi, @kdvDurumu,
                  @iskonto, @toplamFiyati
                )
              '''),
              parameters: {
                'quoteId': id,
                'urunId': urun['urunId'],
                'urunKodu': urun['urunKodu'] ?? '',
                'urunAdi': urun['urunAdi'] ?? '',
                'barkod': urun['barkod'] ?? '',
                'depoId': urun['depoId'],
                'depoAdi': urun['depoAdi'] ?? '',
                'kdvOrani': urun['kdvOrani'] ?? 0,
                'miktar': urun['miktar'] ?? 0,
                'birim': urun['birim'] ?? 'Adet',
                'birimFiyati': urun['birimFiyati'] ?? 0,
                'paraBirimi': urun['paraBirimi'] ?? 'TRY',
                'kdvDurumu': urun['kdvDurumu'] ?? 'excluded',
                'iskonto': urun['iskonto'] ?? 0,
                'toplamFiyati': urun['toplamFiyati'] ?? 0,
              },
            );
          }
        }

        // [STOCK RESERVATION] Eğer durum 'Onaylandı' ise stokları rezerve et
        if (durum == 'Onaylandı') {
          await _teklifStokRezervasyonunuYonet(
            ctx: ctx,
            quoteId: id,
            isArtis: true,
          );
        }

        return true;
      });
    } catch (e) {
      if (e.toString().contains('23514') ||
          e.toString().contains('no partition of relation')) {
        debugPrint(
          'Teklif güncellerken partition hatası algılandı. Onarılıyor...',
        );
        await _recoverMissingPartition();
        try {
          return await teklifGuncelle(
            id: id,
            tur: tur,
            durum: durum,
            tarih: tarih,
            cariId: cariId,
            cariKod: cariKod,
            cariAdi: cariAdi,
            ilgiliHesapAdi: ilgiliHesapAdi,
            tutar: tutar,
            kur: kur,
            aciklama: aciklama,
            aciklama2: aciklama2,
            gecerlilikTarihi: gecerlilikTarihi,
            paraBirimi: paraBirimi,
            urunler: urunler,
          );
        } catch (_) {
          return false;
        }
      }
      debugPrint('Teklif güncelleme hatası: $e');
      return false;
    }
  }

  int? _toInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  double _toDouble(dynamic val, [double defaultValue = 0]) {
    if (val == null) return defaultValue;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? defaultValue;
    return defaultValue;
  }

  String _toString(dynamic val, [String defaultValue = '']) {
    if (val == null) return defaultValue;
    if (val is String) return val;
    return val.toString();
  }

  /// [STOCK RESERVATION] Teklif stok rezervasyonunu yöneten yardımcı metod.
  Future<void> _teklifStokRezervasyonunuYonet({
    required TxSession ctx,
    required int quoteId,
    required bool isArtis,
  }) async {
    // Fetch items for this quote
    final items = await ctx.execute(
      Sql.named(
        'SELECT urun_id, urun_kodu, miktar, depo_id FROM quote_items WHERE quote_id = @id',
      ),
      parameters: {'id': quoteId},
    );

    for (final row in items) {
      final urunKodu = row[1] as String;
      final miktar = (row[2] as num).toDouble();
      final depoId = row[3] as int?;

      if (depoId != null && urunKodu.isNotEmpty && miktar != 0) {
        await DepolarVeritabaniServisi().stokRezervasyonuGuncelle(
          depoId,
          urunKodu,
          miktar,
          isArtis: isArtis,
          session: ctx,
        );
      }
    }

    // Update the flag in quotes table
    await ctx.execute(
      Sql.named(
        'UPDATE quotes SET stok_rezerve_mi = @rezerve, updated_at = CURRENT_TIMESTAMP WHERE id = @id',
      ),
      parameters: {'rezerve': isArtis, 'id': quoteId},
    );
  }
}
