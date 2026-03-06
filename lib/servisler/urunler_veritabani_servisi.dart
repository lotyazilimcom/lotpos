import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../sayfalar/urunler_ve_depolar/urunler/modeller/urun_model.dart';
import 'oturum_servisi.dart';
import 'depolar_veritabani_servisi.dart';
import '../sayfalar/urunler_ve_depolar/depolar/sevkiyat_olustur_sayfasi.dart';
import 'bulut_sema_dogrulama_servisi.dart';
import 'pg_eklentiler.dart';
import 'veritabani_yapilandirma.dart';
import 'veritabani_havuzu.dart';
import 'ayarlar_veritabani_servisi.dart';
import '../sayfalar/urunler_ve_depolar/urunler/modeller/cihaz_model.dart';
import 'lisans_yazma_koruma.dart';

class UrunlerVeritabaniServisi {
  static final UrunlerVeritabaniServisi _instance =
      UrunlerVeritabaniServisi._internal();
  factory UrunlerVeritabaniServisi() => _instance;
  UrunlerVeritabaniServisi._internal();

  Pool? _pool;
  bool _isInitialized = false;

  Pool? getPool() => _pool;

  // PostgreSQL Bağlantı Ayarları (Merkezi Yapılandırma)
  final _yapilandirma = VeritabaniYapilandirma();

  Completer<void>? _initCompleter;
  int _initToken = 0;

  // Transaction Helper for Orchestrators
  Future<T> transactionBaslat<T>(
    Future<T> Function(TxSession session) action, {
    IsolationLevel? isolationLevel,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) throw Exception('Veritabanı bağlantısı başlatılamadı!');

    return await _pool!.runTx((s) async {
      if (isolationLevel != null) {
        String level = 'READ COMMITTED';
        if (isolationLevel == IsolationLevel.serializable) {
          level = 'SERIALIZABLE';
        } else if (isolationLevel == IsolationLevel.repeatableRead) {
          level = 'REPEATABLE READ';
        } else if (isolationLevel == IsolationLevel.readCommitted) {
          level = 'READ COMMITTED';
        } else if (isolationLevel == IsolationLevel.readUncommitted) {
          level = 'READ UNCOMMITTED';
        }
        await s.execute('SET TRANSACTION ISOLATION LEVEL $level');
      }
      return await action(s);
    });
  }

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
        debugPrint(
          'Bağlantı limiti aşıldı (53300). Mevcut bağlantılar temizleniyor...',
        );
        await _acikBaglantilariKapat();
        try {
          _pool = await _poolOlustur();
        } catch (e2) {
          debugPrint('Temizleme sonrası bağlantı hatası: $e2');
        }
      } else {
        debugPrint(
          'Standart bağlantı başarısız, kurulum deneniyor... Hata: $e',
        );
        try {
          _pool = await _poolOlustur();
        } catch (e2) {
          debugPrint('Kurulum sonrası bağlantı hatası: $e2');
        }
      }
    }

    if (_pool == null) {
      final err = StateError('Ürünler veritabanı bağlantısı kurulamadı.');
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
            'UrunlerVeritabaniServisi: Bulut şema hazır, tablo kurulumu atlandı.',
          );
        }

        // Bulut şema "hazır" olsa bile stock_movements için cari ay partition'ı runtime'da lazımdır.
        // Best-effort: DDL yetkisi yoksa sessizce DEFAULT partition ile devam eder.
        await _ensureStockMovementsPartition(DateTime.now());

        // NOT:
        // Global arka plan indeksleme (_verileriIndeksle) ağır bir işlemdir.
        // 1B kayıt senaryosunda bu işlemin uygulama açılışında tetiklenmesi yerine
        // bakım / CLI komutu ile elle çağrılması daha güvenlidir.
        // Bu nedenle burada otomatik çağrı devre dışı bırakılmıştır.
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
        debugPrint(
          'Ürünler veritabanı bağlantısı başarılı (Havuz): ${OturumServisi().aktifVeritabaniAdi}',
        );

        // Initialization Completer - BAŞARILI
        if (!initCompleter.isCompleted) {
          initCompleter.complete();
        }

        // Arka plan görevlerini başlat (İndeksleme vb.)
        // Mobil+Bulut'ta kullanıcı işlemlerini bloklamamak için ağır bakım işleri kapalı.
        if (_yapilandirma.allowBackgroundDbMaintenance &&
            _yapilandirma.allowBackgroundHeavyMaintenance) {
          // Arka plan işi: asla uygulamayı çökertmesin.
          unawaited(
            Future<void>.delayed(const Duration(seconds: 2), () async {
              try {
                await _verileriIndeksle();
              } catch (e) {
                debugPrint(
                  'UrunlerVeritabaniServisi: Arka plan indeksleme hatası (yutuldu): $e',
                );
              }
            }),
          );
        }
      }
    } catch (e) {
      if (!initCompleter.isCompleted) {
        initCompleter.completeError(e);
      }
      if (identical(_initCompleter, initCompleter)) {
        _initCompleter = null;
      }
      // Hata zaten yukarıda loglandı
    }
  }

  Future<void> _ensureStockMovementsPartition(DateTime date) async {
    if (_pool == null) return;

    final int year = date.year;
    final int month = date.month;
    final String monthStr = month.toString().padLeft(2, '0');
    final String partitionName = 'stock_movements_y${year}_m$monthStr';

    final String startStr = '$year-$monthStr-01';
    final endDate = DateTime(year, month + 1, 1);
    final String endStr =
        '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-01';

    try {
      await _pool!.execute(
        'CREATE TABLE IF NOT EXISTS stock_movements_default PARTITION OF stock_movements DEFAULT',
      );
    } catch (_) {}

    try {
      await _pool!.execute('''
        CREATE TABLE IF NOT EXISTS $partitionName
        PARTITION OF stock_movements
        FOR VALUES FROM ('$startStr') TO ('$endStr')
      ''');
    } catch (_) {}
  }

  /// Bakım Modu: İndeksleri manuel tetikler (Performans için manuel)
  Future<void> bakimModuCalistir() async {
    await _verileriIndeksle();
  }

  // Concurrency Guard
  static bool _isIndexingActive = false;

  // Backfill / İndeksleme Fonksiyonu (Self-Healing Mechanism v2 - Optimized for 50M)
  // ignore: unused_element
  // Backfill / İndeksleme Fonksiyonu (Self-Healing Mechanism v2 - Batch Optimized)
  Future<void> _verileriIndeksle() async {
    if (_isIndexingActive) return; // Prevent concurrent runs
    _isIndexingActive = true;

    try {
      final pool = _pool;
      if (pool == null || !pool.isOpen) return;

      // 1. AŞAMA: Sadece Eksik Olan Ürün Bilgilerini İndeksle (Batch Loop)
      while (true) {
        if (!pool.isOpen) break;
        final result = await pool.execute('''
           WITH batch AS (
             SELECT id FROM products 
             WHERE search_tags IS NULL 
             LIMIT 1000
           )
           UPDATE products 
           SET search_tags = LOWER(
              COALESCE(kod, '') || ' ' || 
              COALESCE(ad, '') || ' ' || 
              COALESCE(barkod, '') || ' ' || 
              COALESCE(grubu, '') || ' ' || 
              COALESCE(kullanici, '') || ' ' || 
              COALESCE(ozellikler, '') || ' ' || 
              COALESCE(birim, '') || ' ' || 
              CAST(products.id AS TEXT) || ' ' ||
              COALESCE(CAST(alis_fiyati AS TEXT), '') || ' ' ||
              COALESCE(CAST(satis_fiyati_1 AS TEXT), '') || ' ' ||
              COALESCE(CAST(satis_fiyati_2 AS TEXT), '') || ' ' ||
              COALESCE(CAST(satis_fiyati_3 AS TEXT), '') || ' ' ||
              COALESCE(CAST(erken_uyari_miktari AS TEXT), '') || ' ' ||
              COALESCE(CAST(stok AS TEXT), '') || ' ' ||
              COALESCE(CAST(kdv_orani AS TEXT), '') || ' ' ||
              (CASE WHEN aktif_mi = 1 THEN 'aktif' ELSE 'pasif' END)
           )
           FROM batch
           WHERE products.id = batch.id
           RETURNING products.id
         ''');

        if (result.isEmpty) break; // Bitti
        await Future.delayed(
          const Duration(milliseconds: 50),
        ); // CPU nefes alsın
      }

      // 3. AŞAMA: Cihaz Bilgilerini (Seri No, IMEI) Üzerine Ekle (Batch Loop)
      // Sadece 'search_tags' içinde 'seri_no' veya 'imei' ibaresi geçmeyenleri işle
      while (true) {
        if (!pool.isOpen) break;
        final result = await pool.execute('''
        WITH targets AS (
            SELECT id FROM products 
            WHERE search_tags NOT LIKE '%cihaz_kimlik%'
            LIMIT 100
        ),
        device_details AS (
          SELECT 
            pd.product_id as p_id,
            STRING_AGG(LOWER(pd.identity_value), ' ') as identities
          FROM product_devices pd
          INNER JOIN targets t ON pd.product_id = t.id
          GROUP BY pd.product_id
        )
        UPDATE products p
        SET search_tags = p.search_tags || ' cihaz_kimlik ' || COALESCE(dd.identities, '')
        FROM device_details dd
        WHERE p.id = dd.p_id;
       ''');

        if (result.affectedRows == 0) break;
        await Future.delayed(const Duration(milliseconds: 50));
      }

      debugPrint('✅ Arama İndeksleri (Device Identifiers) Kontrol Edildi.');
    } catch (e) {
      if (e is LisansYazmaEngelliHatasi) return;
      debugPrint('İndeksleme sırasında uyarı: $e');
    } finally {
      _isIndexingActive = false;
    }
  }

  Future<void> baglantiyiKapat() async {
    _initToken++;
    final pending = _initCompleter;
    _initCompleter = null;
    _isInitialized = false;

    final pool = _pool;
    _pool = null;
    await VeritabaniHavuzu().kapatPool(pool);
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('Bağlantı kapatıldı'));
    }
  }

  Future<Pool> _poolOlustur() async {
    return VeritabaniHavuzu().havuzAl(database: OturumServisi().aktifVeritabaniAdi);
  }

  Future<Connection?> _yoneticiBaglantisiAl() async {
    if (VeritabaniYapilandirma.connectionMode == 'cloud' &&
        VeritabaniYapilandirma.cloudApiCredentialsReady) {
      return null;
    }

    final List<String> olasiKullanicilar = [];
    if (Platform.environment.containsKey('USER')) {
      olasiKullanicilar.add(Platform.environment['USER']!);
    }
    olasiKullanicilar.add('postgres');

    final List<String> olasiSifreler = [
      '',
      'postgres',
      'password',
      '123456',
      'admin',
      'root',
    ];

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
            settings: ConnectionSettings(
              sslMode: _yapilandirma.sslMode,
              queryMode: _yapilandirma.queryMode,
              onOpen: _yapilandirma.tuneConnection,
            ),
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

    // Ürünler Tablosu
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id BIGSERIAL PRIMARY KEY,
        kod TEXT NOT NULL,
        ad TEXT NOT NULL,
        birim TEXT DEFAULT 'Adet',
        alis_fiyati NUMERIC DEFAULT 0,
        satis_fiyati_1 NUMERIC DEFAULT 0,
        satis_fiyati_2 NUMERIC DEFAULT 0,
        satis_fiyati_3 NUMERIC DEFAULT 0,
        kdv_orani NUMERIC DEFAULT 18,
        stok NUMERIC DEFAULT 0,
        erken_uyari_miktari NUMERIC DEFAULT 0,
        grubu TEXT,
        ozellikler TEXT,
        barkod TEXT,
        kullanici TEXT,
        resim_url TEXT,
        resimler JSONB DEFAULT '[]',
        aktif_mi INTEGER DEFAULT 1,
        search_tags TEXT NOT NULL DEFAULT '', -- 1 Milyar Kayıt İçin Performans Sütunu
        created_by TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Cihazlar (IMEI, Seri No, vb.) Tablosu
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS product_devices (
        id BIGSERIAL PRIMARY KEY,
        product_id BIGINT REFERENCES products(id) ON DELETE CASCADE,
        identity_type TEXT NOT NULL,
        identity_value TEXT NOT NULL,
        condition TEXT DEFAULT 'Sıfır',
        color TEXT,
        capacity TEXT,
        warranty_end_date TIMESTAMP,
        has_box INTEGER DEFAULT 0,
        has_invoice INTEGER DEFAULT 0,
        has_original_charger INTEGER DEFAULT 0,
        is_sold INTEGER DEFAULT 0, -- 0: Stokta, 1: Satıldı
        sale_ref TEXT, -- Satışın entegrasyon referansı
        -- [2026 GOOGLE-LIKE] Seri/IMEI listesi için "son işlem" ve hızlı arama
        last_tx_at TIMESTAMP,
        last_tx_type TEXT,
        last_tx_shipment_id BIGINT,
        search_tags TEXT NOT NULL DEFAULT '',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Migration: Add is_sold and sale_ref if doesn't exist
    try {
      await _pool!.execute(
        'ALTER TABLE product_devices ADD COLUMN IF NOT EXISTS is_sold INTEGER DEFAULT 0',
      );
      await _pool!.execute(
        'ALTER TABLE product_devices ADD COLUMN IF NOT EXISTS sale_ref TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE product_devices ADD COLUMN IF NOT EXISTS last_tx_at TIMESTAMP',
      );
      await _pool!.execute(
        'ALTER TABLE product_devices ADD COLUMN IF NOT EXISTS last_tx_type TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE product_devices ADD COLUMN IF NOT EXISTS last_tx_shipment_id BIGINT',
      );
      await _pool!.execute(
        'ALTER TABLE product_devices ADD COLUMN IF NOT EXISTS search_tags TEXT NOT NULL DEFAULT \'\'',
      );
    } catch (_) {}

    // Indexler: identity_value için arama amaçlı, product_id için join amaçlı
    await _pool!.execute(
      'CREATE INDEX IF NOT EXISTS idx_pd_identity_value ON product_devices (identity_value)',
    );
    await _pool!.execute(
      'CREATE INDEX IF NOT EXISTS idx_pd_product_id ON product_devices (product_id)',
    );
    await _pool!.execute(
      'CREATE INDEX IF NOT EXISTS idx_pd_product_sold_id ON product_devices (product_id, is_sold, id)',
    );

      // [2026 GOOGLE-LIKE] product_devices search_tags (indexed deep search)
    try {
      await PgEklentiler.ensurePgTrgm(_pool!);
      // ParadeDB / BM25 (best-effort; extension yoksa no-op)
      try {
        await PgEklentiler.ensurePgSearch(_pool!);
      } catch (_) {}
      await PgEklentiler.ensureSearchTagsNotNullDefault(_pool!, 'product_devices');
      await PgEklentiler.ensureSearchTagsFtsIndex(
        _pool!,
        table: 'product_devices',
        indexName: 'idx_pd_search_tags_fts_gin',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_pd_search_tags_gin ON product_devices USING GIN (search_tags gin_trgm_ops)',
      );
      try {
        await PgEklentiler.ensureBm25Index(
          _pool!,
          table: 'product_devices',
          indexName: 'idx_product_devices_search_tags_bm25',
        );
      } catch (_) {}

      // normalize_text yoksa trigger kurulumları patlar; burada best-effort garanti ediyoruz.
      await _pool!.execute('''
        CREATE OR REPLACE FUNCTION normalize_text(val TEXT) RETURNS TEXT AS \$\$
        BEGIN
          IF val IS NULL THEN
            RETURN '';
          END IF;

          val := COALESCE(val, '');
          -- Handle combining characters and common variations before translate
          val := REPLACE(val, 'i̇', 'i'); -- Turkish dotted i variation
          RETURN LOWER(
            TRANSLATE(val,
              'ÇĞİÖŞÜIçğıöşü',
              'cgiosuicgiosu'
            )
          );
        END;
        \$\$ LANGUAGE plpgsql IMMUTABLE;
      ''');

      await _pool!.execute('''
        CREATE OR REPLACE FUNCTION update_product_devices_search_tags()
        RETURNS TRIGGER AS \$\$
        DECLARE
          prod_text TEXT := '';
          sold_text TEXT := '';
        BEGIN
          IF to_regclass('public.products') IS NOT NULL THEN
            SELECT COALESCE(kod, '') || ' ' || COALESCE(ad, '') || ' ' || COALESCE(barkod, '')
            INTO prod_text
            FROM products
            WHERE id = NEW.product_id
            LIMIT 1;
          END IF;

          sold_text := CASE WHEN COALESCE(NEW.is_sold, 0) = 1 THEN 'satildi satıldı sold' ELSE 'stokta stock' END;

          NEW.search_tags := normalize_text(
            '|v2026| ' ||
            COALESCE(prod_text, '') || ' ' ||
            COALESCE(NEW.identity_type, '') || ' ' ||
            COALESCE(NEW.identity_value, '') || ' ' ||
            COALESCE(NEW.condition, '') || ' ' ||
            COALESCE(NEW.color, '') || ' ' ||
            COALESCE(NEW.capacity, '') || ' ' ||
            COALESCE(sold_text, '') || ' ' ||
            COALESCE(NEW.sale_ref, '') || ' ' ||
            COALESCE(NEW.last_tx_type, '') || ' ' ||
            COALESCE(TO_CHAR(NEW.last_tx_at, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
            COALESCE(TO_CHAR(NEW.last_tx_at, 'DD.MM'), '') || ' ' ||
            COALESCE(TO_CHAR(NEW.last_tx_at, 'HH24:MI'), '') || ' ' ||
            CAST(NEW.product_id AS TEXT) || ' ' ||
            CAST(NEW.id AS TEXT)
          );
          RETURN NEW;
        END;
        \$\$ LANGUAGE plpgsql;
      ''');

      await _pool!.execute('''
        DO \$\$
        BEGIN
          IF NOT EXISTS (
            SELECT 1 FROM pg_trigger WHERE tgname = 'trg_update_product_devices_search_tags'
          ) THEN
            CREATE TRIGGER trg_update_product_devices_search_tags
            BEFORE INSERT OR UPDATE ON product_devices
            FOR EACH ROW EXECUTE FUNCTION update_product_devices_search_tags();
          END IF;
        END;
        \$\$;
      ''');

      // Smart incremental backfill (batch): eski kayıtların search_tags'ını doldur.
      // Not: Büyük datasetlerde tek seferde full UPDATE yapmayız.
      if (_yapilandirma.allowBackgroundDbMaintenance &&
          _yapilandirma.allowBackgroundHeavyMaintenance) {
        for (int i = 0; i < 50; i++) {
          final res = await _pool!.execute(
            Sql.named('''
              WITH todo AS (
                SELECT id, product_id
                FROM product_devices
                WHERE search_tags IS NULL OR search_tags = '' OR search_tags NOT LIKE '%|v2026|%'
                ORDER BY id ASC
                LIMIT @limit
              )
              UPDATE product_devices pd
              SET search_tags = normalize_text(
                '|v2026| ' ||
                COALESCE(p.kod, '') || ' ' ||
                COALESCE(p.ad, '') || ' ' ||
                COALESCE(p.barkod, '') || ' ' ||
                COALESCE(pd.identity_type, '') || ' ' ||
                COALESCE(pd.identity_value, '') || ' ' ||
                COALESCE(pd.condition, '') || ' ' ||
                COALESCE(pd.color, '') || ' ' ||
                COALESCE(pd.capacity, '') || ' ' ||
                CASE WHEN COALESCE(pd.is_sold, 0) = 1 THEN 'satildi satıldı sold' ELSE 'stokta stock' END || ' ' ||
                COALESCE(pd.sale_ref, '') || ' ' ||
                COALESCE(pd.last_tx_type, '') || ' ' ||
                COALESCE(TO_CHAR(pd.last_tx_at, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
                COALESCE(TO_CHAR(pd.last_tx_at, 'DD.MM'), '') || ' ' ||
                COALESCE(TO_CHAR(pd.last_tx_at, 'HH24:MI'), '') || ' ' ||
                CAST(pd.product_id AS TEXT) || ' ' ||
                CAST(pd.id AS TEXT)
              )
              FROM todo t
              LEFT JOIN products p ON p.id = t.product_id
              WHERE pd.id = t.id
              RETURNING pd.id
            '''),
            parameters: {'limit': 2000},
          );
          if (res.isEmpty) break;
          await Future.delayed(const Duration(milliseconds: 25));
        }
      }
    } catch (e) {
      debugPrint('product_devices search/index kurulum uyarısı: $e');
    }

    // Hızlı Ürünler Tablosu
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS quick_products (
        id BIGSERIAL PRIMARY KEY,
        product_id BIGINT UNIQUE REFERENCES products(id) ON DELETE CASCADE,
        display_order INTEGER DEFAULT 0
      )
    ''');

    // Migration: Add updated_at if doesn't exist
    try {
      await _pool!.execute(
        'ALTER TABLE products ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP',
      );
    } catch (_) {}

    // Sequence (Sayaç) Tablosu - O(1) Kod Üretimi
    try {
      await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS sequences (
        name TEXT PRIMARY KEY,
        current_value BIGINT DEFAULT 0
      )
    ''');
    } catch (e) {
      debugPrint('Sequence tablosu zaten var veya erişim hatası: $e');
    }

    // 3. AŞAMA: 1 Milyar Kayıt İçin Metadata ve İstatistik Tabloları (New Architecture)
    // Filtre menülerinin 100ms altında açılması için "DISTINCT" sorgularından kurtuluyoruz.
    // Bunun yerine, trigger ile beslenen özet tabloları kullanıyoruz.

    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS product_metadata (
        type TEXT NOT NULL, -- 'group', 'unit', 'vat'
        value TEXT NOT NULL,
        frequency BIGINT DEFAULT 1,
        PRIMARY KEY (type, value)
      )
    ''');

    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS table_counts (
        table_name TEXT PRIMARY KEY,
        row_count BIGINT DEFAULT 0
      )
    ''');

    // 2. AŞAMA: Genel stok hareketleri tablosu (Partitioned & Standardized)
    try {
      final tableCheck = await _pool!.execute(
        "SELECT relkind::text FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'stock_movements'",
      );

      bool shouldCreatePartitioned = true;
      if (tableCheck.isNotEmpty) {
        final relkind = tableCheck.first[0].toString().toLowerCase();
        if (relkind == 'p') {
          shouldCreatePartitioned = false;
        } else {
          debugPrint(
            'Stok hareketleri tablosu bölümlendirme moduna geçiriliyor...',
          );
          await _pool!.execute(
            'DROP TABLE IF EXISTS stock_movements_old CASCADE',
          );
          await _pool!.execute(
            'ALTER TABLE stock_movements RENAME TO stock_movements_old',
          );
        }
      }

      if (shouldCreatePartitioned) {
        await _pool!.execute('''
          CREATE TABLE IF NOT EXISTS stock_movements (
            id BIGSERIAL,
            product_id BIGINT,
            warehouse_id BIGINT,
            shipment_id BIGINT,
            quantity NUMERIC DEFAULT 0,
            is_giris BOOLEAN NOT NULL DEFAULT true,
            unit_price NUMERIC DEFAULT 0,
            currency_code TEXT DEFAULT 'TRY',
            currency_rate NUMERIC DEFAULT 1,
            vat_status TEXT DEFAULT 'excluded',
            movement_date TIMESTAMP NOT NULL,
            description TEXT,
            movement_type TEXT,
            created_by TEXT,
            integration_ref TEXT,
            running_cost NUMERIC DEFAULT 0,
            running_stock NUMERIC DEFAULT 0,
            search_tags TEXT NOT NULL DEFAULT '',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id, created_at)
          ) PARTITION BY RANGE (created_at)
        ''');
      }

      // [2025 ROBUST] Partitions MUST be checked every time, individually.
      // 1. Default Partition
      try {
        await _pool!.execute('''
          CREATE TABLE IF NOT EXISTS stock_movements_default 
          PARTITION OF stock_movements DEFAULT
        ''');
      } catch (e) {
        debugPrint('SM Default Partition bypass: $e');
      }

      // 2. Month Partitions
      final Set<int> legacyYearPartitions = <int>{};
      try {
        final legacyRows = await _pool!.execute('''
          SELECT c.relname
          FROM pg_inherits i
          JOIN pg_class c ON c.oid = i.inhrelid
          JOIN pg_class p ON p.oid = i.inhparent
          WHERE p.relname = 'stock_movements'
            AND c.relname ~ '^stock_movements_[0-9]{4}\$'
        ''');
        for (final r in legacyRows) {
          final name = r[0]?.toString() ?? '';
          final yearStr = name.replaceFirst('stock_movements_', '');
          final y = int.tryParse(yearStr);
          if (y != null) legacyYearPartitions.add(y);
        }
      } catch (_) {}

      final DateTime now = DateTime.now();
      for (int i = -12; i <= 36; i++) {
        final d = DateTime(now.year, now.month + i, 1);
        final int year = d.year;
        final int month = d.month;
        final String monthStr = month.toString().padLeft(2, '0');
        final String partitionName = 'stock_movements_y${year}_m$monthStr';

        // Legacy yıllık partition (stock_movements_2026) varsa aylık partition deneme.
        if (legacyYearPartitions.contains(year)) continue;

        final startStr = '$year-$monthStr-01';
        final endDate = DateTime(year, month + 1, 1);
        final endStr =
            '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-01';

        try {
          await _pool!.execute('''
            CREATE TABLE IF NOT EXISTS $partitionName 
            PARTITION OF stock_movements 
            FOR VALUES FROM ('$startStr') TO ('$endStr')
          ''');
        } catch (e) {
          final isOverlap = e is ServerException && e.code == '42P17';
          if (!isOverlap) {
            debugPrint('SM Partition $partitionName bypass: $e');
          }
        }
      }

      // Migration: Old data to new partitioned table
      if (shouldCreatePartitioned && tableCheck.isNotEmpty) {
        debugPrint('Eski stok hareket verileri yeni bölümlere aktarılıyor...');
        try {
          // [100B/20Y] Eski veriler DEFAULT partition'a yığılmasın:
          // Eski tablodaki created_at aralığına göre aylık partition'ları hazırla.
          try {
            final rangeRows = await _pool!.execute('''
              SELECT MIN(created_at), MAX(created_at)
              FROM stock_movements_old
              WHERE created_at IS NOT NULL
            ''');
            if (rangeRows.isNotEmpty) {
              final minDt = rangeRows.first[0] as DateTime?;
              final maxDt = rangeRows.first[1] as DateTime?;
              if (minDt != null && maxDt != null) {
                await _ensureStockMovementPartitionsForRange(minDt, maxDt);
              }
            }
          } catch (e) {
            debugPrint('SM partition aralık hazırlığı uyarısı: $e');
          }

          await _pool!.execute('''
            INSERT INTO stock_movements (
              id, product_id, warehouse_id, shipment_id, quantity, is_giris, unit_price, 
              currency_code, currency_rate, vat_status, movement_date, description, 
              movement_type, created_by, integration_ref, running_cost, running_stock, created_at
            )
            SELECT 
              id, product_id, warehouse_id, shipment_id, quantity, is_giris, unit_price, 
              currency_code, currency_rate, vat_status, movement_date, description, 
              movement_type, created_by, integration_ref, running_cost, running_stock, created_at
            FROM stock_movements_old
            ON CONFLICT (id, created_at) DO NOTHING
          ''');
          debugPrint('✅ Stok hareket verileri başarıyla bölümlendirildi.');

          // [100B/20Y] DEFAULT partition'a düşmüş eski satırları ilgili aylık partitionlara taşı (best-effort).
          // [100B SAFE] Varsayılan kapalı.
          if (_yapilandirma.allowBackgroundDbMaintenance &&
              _yapilandirma.allowBackgroundHeavyMaintenance) {
            try {
              await _backfillStockMovementsDefault();
            } catch (e) {
              debugPrint('SM default backfill uyarısı: $e');
            }
          }
        } catch (e) {
          debugPrint('🔴 Stok hareket migrasyon hatası: $e');
        }
      }
    } catch (e) {
      debugPrint('Stok hareketleri ana tablo kurulum hatası: $e');
    }

    try {
      // [2025 HYPER-ROBUST] Verify table existence before any ALTER/INDEX operation
      final smCheck = await _pool!.execute(
        "SELECT relkind::text FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'stock_movements'",
      );

      if (smCheck.isNotEmpty) {
        final relkind = smCheck.first[0].toString();
        debugPrint(
          'Stok Hareketleri Tablo Durumu (Products): relkind=$relkind',
        );

        // Migration: Eksik kolonları ekle (Tüm servisler için ortak kanonik şema)
        await _pool!.execute(
          'ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS is_giris BOOLEAN NOT NULL DEFAULT true',
        );
        await _pool!.execute(
          'ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS shipment_id BIGINT',
        );
        await _pool!.execute(
          "ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS currency_code TEXT DEFAULT 'TRY'",
        );
        await _pool!.execute(
          'ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS currency_rate NUMERIC DEFAULT 1',
        );
        await _pool!.execute(
          'ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS integration_ref TEXT',
        );
        await _pool!.execute(
          'ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS running_cost NUMERIC DEFAULT 0',
        );
        await _pool!.execute(
          'ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS running_stock NUMERIC DEFAULT 0',
        );
        await _pool!.execute(
          'ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS search_tags TEXT NOT NULL DEFAULT \'\'',
        );

        // İndeksler
        await _executeCreateIndexSafe(
          'CREATE INDEX IF NOT EXISTS idx_sm_product_id ON stock_movements(product_id)',
        );
        await _executeCreateIndexSafe(
          'CREATE INDEX IF NOT EXISTS idx_sm_warehouse_id ON stock_movements(warehouse_id)',
        );
        await _executeCreateIndexSafe(
          'CREATE INDEX IF NOT EXISTS idx_sm_date ON stock_movements(movement_date)',
        );
        await _executeCreateIndexSafe(
          'CREATE INDEX IF NOT EXISTS idx_sm_ref ON stock_movements(integration_ref)',
        );
        await _executeCreateIndexSafe(
          'CREATE INDEX IF NOT EXISTS idx_sm_shipment_id ON stock_movements(shipment_id)',
        );
      } else {
        debugPrint(
          'stock_movements henüz oluşturulmadı veya geçici olarak yok. Atlanıyor...',
        );
      }
    } catch (e) {
      debugPrint('Stok hareketleri tablosu fix hatası: $e');
    }

    if (_yapilandirma.allowBackgroundDbMaintenance &&
        _yapilandirma.allowBackgroundHeavyMaintenance) {
      unawaited(() async {
        try {
          await _backfillStockMovementsDefault();
        } catch (e) {
          debugPrint('SM arka plan default backfill uyarısı: $e');
        }
      }());
    }

    // 4. AŞAMA: TRIGGERLAR (Otomatik Bakım)
    // 4.1. Kayıt Sayısı Sayacı (Count Cache)
    await _pool!.execute('''
      CREATE OR REPLACE FUNCTION update_table_counts() RETURNS TRIGGER AS \$\$
      BEGIN
        IF (TG_OP = 'INSERT') THEN
          INSERT INTO table_counts (table_name, row_count) 
          VALUES (TG_TABLE_NAME, 1) 
          ON CONFLICT (table_name) DO UPDATE SET row_count = table_counts.row_count + 1;
        ELSIF (TG_OP = 'DELETE') THEN
          UPDATE table_counts SET row_count = row_count - 1 WHERE table_name = TG_TABLE_NAME;
        END IF;
        RETURN NULL;
      END;
      \$\$ LANGUAGE plpgsql;
    ''');

    // Trigger'ı bağla
    final countTriggerExists = await _pool!.execute(
      "SELECT 1 FROM pg_trigger WHERE tgname = 'trg_update_products_count'",
    );
    if (countTriggerExists.isEmpty) {
      await _pool!.execute('''
        CREATE TRIGGER trg_update_products_count
        AFTER INSERT OR DELETE ON products
        FOR EACH ROW EXECUTE FUNCTION update_table_counts();
      ''');

      // İlk Kurulum: Mevcut sayıyı hesapla ve yaz
      await _pool!.execute('''
        INSERT INTO table_counts (table_name, row_count)
        SELECT 'products', COUNT(*) FROM products
        ON CONFLICT (table_name) DO UPDATE SET row_count = EXCLUDED.row_count;
      ''');
    }

    // 4.2. Filtre Metadata Okuyucu (Distinct Value Cache)
    await _pool!.execute('''
      CREATE OR REPLACE FUNCTION update_product_metadata() RETURNS TRIGGER AS \$\$
      BEGIN
        -- INSERT İŞLEMİ
        IF (TG_OP = 'INSERT') THEN
           IF NEW.grubu IS NOT NULL THEN
             INSERT INTO product_metadata (type, value, frequency) VALUES ('group', NEW.grubu, 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
           END IF;
           IF NEW.birim IS NOT NULL THEN
             INSERT INTO product_metadata (type, value, frequency) VALUES ('unit', NEW.birim, 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
           END IF;
           IF NEW.kdv_orani IS NOT NULL THEN
             INSERT INTO product_metadata (type, value, frequency) VALUES ('vat', CAST(NEW.kdv_orani AS TEXT), 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
           END IF;
           
        -- UPDATE İŞLEMİ
        ELSIF (TG_OP = 'UPDATE') THEN
           -- Group Değişimi
           IF OLD.grubu IS DISTINCT FROM NEW.grubu THEN
               IF OLD.grubu IS NOT NULL THEN
                  UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'group' AND value = OLD.grubu;
               END IF;
               IF NEW.grubu IS NOT NULL THEN
                  INSERT INTO product_metadata (type, value, frequency) VALUES ('group', NEW.grubu, 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
               END IF;
           END IF;
           
           -- Birim Değişimi
           IF OLD.birim IS DISTINCT FROM NEW.birim THEN
               IF OLD.birim IS NOT NULL THEN
                  UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'unit' AND value = OLD.birim;
               END IF;
               IF NEW.birim IS NOT NULL THEN
                  INSERT INTO product_metadata (type, value, frequency) VALUES ('unit', NEW.birim, 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
               END IF;
           END IF;

           -- KDV Değişimi
           IF OLD.kdv_orani IS DISTINCT FROM NEW.kdv_orani THEN
               IF OLD.kdv_orani IS NOT NULL THEN
                  UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'vat' AND value = CAST(OLD.kdv_orani AS TEXT);
               END IF;
               IF NEW.kdv_orani IS NOT NULL THEN
                  INSERT INTO product_metadata (type, value, frequency) VALUES ('vat', CAST(NEW.kdv_orani AS TEXT), 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = product_metadata.frequency + 1;
               END IF;
           END IF;

        -- DELETE İŞLEMİ
        ELSIF (TG_OP = 'DELETE') THEN
           IF OLD.grubu IS NOT NULL THEN
             UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'group' AND value = OLD.grubu;
           END IF;
           IF OLD.birim IS NOT NULL THEN
             UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'unit' AND value = OLD.birim;
           END IF;
           IF OLD.kdv_orani IS NOT NULL THEN
             UPDATE product_metadata SET frequency = frequency - 1 WHERE type = 'vat' AND value = CAST(OLD.kdv_orani AS TEXT);
           END IF;
        END IF;

        -- Temizlik (Sıfır olanları sil ki tablo şişmesin)
        DELETE FROM product_metadata WHERE frequency <= 0;
        
        RETURN NULL;
      END;
      \$\$ LANGUAGE plpgsql;
    ''');

    final metaTriggerExists = await _pool!.execute(
      "SELECT 1 FROM pg_trigger WHERE tgname = 'trg_update_products_metadata'",
    );
    if (metaTriggerExists.isEmpty) {
      await _pool!.execute('''
        CREATE TRIGGER trg_update_products_metadata
        AFTER INSERT OR UPDATE OR DELETE ON products
        FOR EACH ROW EXECUTE FUNCTION update_product_metadata();
      ''');

      // İlk Kurulum: Metadata tablosunu doldur (Backfill)
      // Bu işlem 1 kere çalışır.
      await _pool!.execute('''
        INSERT INTO product_metadata (type, value, frequency)
        SELECT 'group', grubu, COUNT(*) FROM products WHERE grubu IS NOT NULL GROUP BY grubu
        ON CONFLICT (type, value) DO UPDATE SET frequency = EXCLUDED.frequency;
      ''');
      await _pool!.execute('''
        INSERT INTO product_metadata (type, value, frequency)
        SELECT 'unit', birim, COUNT(*) FROM products WHERE birim IS NOT NULL GROUP BY birim
        ON CONFLICT (type, value) DO UPDATE SET frequency = EXCLUDED.frequency;
      ''');
      await _pool!.execute('''
         INSERT INTO product_metadata (type, value, frequency)
         SELECT 'vat', CAST(kdv_orani AS TEXT), COUNT(*) FROM products WHERE kdv_orani IS NOT NULL GROUP BY kdv_orani
         ON CONFLICT (type, value) DO UPDATE SET frequency = EXCLUDED.frequency;
      ''');
    }

    // 50 Milyon+ Kayıt İçin Ürün İndeksleri
    // Not: Bu blok yalnızca şema kurulurken çalışır, mevcut indekslere zarar vermez.
    try {
      await PgEklentiler.ensurePgTrgm(_pool!);
      // ParadeDB / BM25 (best-effort; extension yoksa no-op)
      try {
        await PgEklentiler.ensurePgSearch(_pool!);
      } catch (_) {}
      await PgEklentiler.ensureSearchTagsNotNullDefault(_pool!, 'products');
      await PgEklentiler.ensureSearchTagsNotNullDefault(_pool!, 'stock_movements');
      await PgEklentiler.ensureSearchTagsFtsIndex(
        _pool!,
        table: 'products',
        indexName: 'idx_products_search_tags_fts_gin',
      );
      await PgEklentiler.ensureSearchTagsFtsIndex(
        _pool!,
        table: 'stock_movements',
        indexName: 'idx_sm_search_tags_fts_gin',
      );

      // Metin aramaları için trigram indeksleri
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_kod_trgm ON products USING GIN (kod gin_trgm_ops)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_ad_trgm ON products USING GIN (ad gin_trgm_ops)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_barkod_trgm ON products USING GIN (barkod gin_trgm_ops)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_search_tags_gin ON products USING GIN (search_tags gin_trgm_ops)',
      );

      // Eşitlik ve filtreler için B-Tree indeksleri
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_kod_btree ON products (kod)',
      );
      // [100B] Sıralama + keyset cursor için composite index (ORDER BY ad, id)
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_ad_id ON products (ad, id)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_barkod_btree ON products (barkod) WHERE barkod IS NOT NULL',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_grubu_btree ON products (grubu)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_birim_btree ON products (birim)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_kdv_btree ON products (kdv_orani)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_aktif_btree ON products (aktif_mi)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_created_by ON products (created_by)',
      );

      debugPrint('🚀 Ürünler Performans Modu: GIN ve B-Tree indeksleri hazır.');

      // BM25 indexler (Google-like search fast path)
      try {
        await PgEklentiler.ensureBm25Index(
          _pool!,
          table: 'products',
          indexName: 'idx_products_search_tags_bm25',
        );
        await PgEklentiler.ensureBm25Index(
          _pool!,
          table: 'stock_movements',
          indexName: 'idx_stock_movements_search_tags_bm25',
        );
      } catch (_) {}

      // [2025 HYPERSCALE] BRIN Index for 10B rows
      await _executeCreateIndexSafe('''
        CREATE INDEX IF NOT EXISTS idx_sm_created_at_brin 
        ON stock_movements USING BRIN (created_at) 
        WITH (pages_per_range = 128)
      ''');

      await _executeCreateIndexSafe('''
        CREATE INDEX IF NOT EXISTS idx_sm_date_brin 
        ON stock_movements USING BRIN (movement_date) 
        WITH (pages_per_range = 128)
      ''');

      // B-Tree for Joins and Filters
      await _executeCreateIndexSafe(
        'CREATE INDEX IF NOT EXISTS idx_sm_product_id ON stock_movements(product_id)',
      );
      await _executeCreateIndexSafe(
        'CREATE INDEX IF NOT EXISTS idx_sm_warehouse_id ON stock_movements(warehouse_id)',
      );
      await _executeCreateIndexSafe(
        'CREATE INDEX IF NOT EXISTS idx_sm_ref ON stock_movements(integration_ref)',
      );
      await _executeCreateIndexSafe(
        'CREATE INDEX IF NOT EXISTS idx_sm_search_tags_gin ON stock_movements USING GIN (search_tags gin_trgm_ops)',
      );

      // [2026 GOOGLE-LIKE] stock_movements search_tags (indexed deep search)
      await _pool!.execute('''
        CREATE OR REPLACE FUNCTION update_stock_movements_search_tags()
        RETURNS TRIGGER AS \$\$
        DECLARE
          wh_text TEXT := '';
          prod_text TEXT := '';
          type_text TEXT := '';
          dir_text TEXT := '';
        BEGIN
          IF to_regclass('public.depots') IS NOT NULL THEN
            SELECT COALESCE(kod, '') || ' ' || COALESCE(ad, '')
            INTO wh_text
            FROM depots
            WHERE id = NEW.warehouse_id;
          END IF;

          IF to_regclass('public.products') IS NOT NULL THEN
            SELECT
              COALESCE(kod, '') || ' ' ||
              COALESCE(ad, '') || ' ' ||
              COALESCE(barkod, '')
            INTO prod_text
            FROM products
            WHERE id = NEW.product_id;
          END IF;

          dir_text := CASE
            WHEN NEW.is_giris THEN 'giriş stok giriş'
            ELSE 'çıkış stok çıkış'
          END;

          type_text := CASE
            WHEN COALESCE(NEW.integration_ref, '') = 'opening_stock' OR COALESCE(NEW.description, '') ILIKE '%Açılış%' THEN 'açılış stoğu'
            WHEN COALESCE(NEW.integration_ref, '') LIKE 'SALE-%' OR COALESCE(NEW.integration_ref, '') LIKE 'RETAIL-%' THEN 'satış faturası satış yapıldı'
            WHEN COALESCE(NEW.integration_ref, '') LIKE 'PURCHASE-%' THEN 'alış faturası alış yapıldı'
            WHEN COALESCE(NEW.integration_ref, '') = 'production_output' OR COALESCE(NEW.description, '') ILIKE '%Üretim%' THEN 'üretim'
            ELSE COALESCE(NEW.movement_type, '')
          END;

          NEW.search_tags := LOWER(
            COALESCE(type_text, '') || ' ' ||
            COALESCE(dir_text, '') || ' ' ||
            COALESCE(TO_CHAR(NEW.movement_date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
            COALESCE(TO_CHAR(NEW.movement_date, 'DD.MM'), '') || ' ' ||
            COALESCE(TO_CHAR(NEW.movement_date, 'HH24:MI'), '') || ' ' ||
            COALESCE(prod_text, '') || ' ' ||
            COALESCE(wh_text, '') || ' ' ||
            COALESCE(CAST(NEW.quantity AS TEXT), '') || ' ' ||
            COALESCE(REPLACE(CAST(NEW.quantity AS TEXT), '.', ','), '') || ' ' ||
            COALESCE(CAST(NEW.unit_price AS TEXT), '') || ' ' ||
            COALESCE(REPLACE(CAST(NEW.unit_price AS TEXT), '.', ','), '') || ' ' ||
            COALESCE(NEW.currency_code, '') || ' ' ||
            COALESCE(CAST(NEW.currency_rate AS TEXT), '') || ' ' ||
            COALESCE(REPLACE(CAST(NEW.currency_rate AS TEXT), '.', ','), '') || ' ' ||
            COALESCE(NEW.vat_status, '') || ' ' ||
            (CASE WHEN NEW.vat_status = 'included' THEN 'kdv dahil dahil' ELSE 'kdv hariç hariç' END) || ' ' ||
            COALESCE(NEW.description, '') || ' ' ||
            COALESCE(NEW.created_by, '') || ' ' ||
            COALESCE(NEW.integration_ref, '') || ' ' ||
            COALESCE(CAST(NEW.id AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.shipment_id AS TEXT), '')
          );
          RETURN NEW;
        END;
        \$\$ LANGUAGE plpgsql;
      ''');

      await _pool!.execute(
        'DROP TRIGGER IF EXISTS trg_update_stock_movements_search_tags ON stock_movements',
      );
      await _pool!.execute('''
        CREATE TRIGGER trg_update_stock_movements_search_tags
        BEFORE INSERT OR UPDATE ON stock_movements
        FOR EACH ROW EXECUTE FUNCTION update_stock_movements_search_tags();
      ''');

      if (_yapilandirma.allowBackgroundDbMaintenance &&
          _yapilandirma.allowBackgroundHeavyMaintenance) {
        unawaited(_backfillStockMovementSearchTags());
      }

      await _pool!.execute('''
        CREATE INDEX IF NOT EXISTS idx_products_created_at_brin 
        ON products USING BRIN (created_at) 
        WITH (pages_per_range = 128)
      ''');

      debugPrint('🚀 10B Performans: BRIN indeksleri hazır.');
    } catch (e) {
      debugPrint('Ürün indeksleri oluşturulurken uyarı: $e');
    }
  }

  // --- Hızlı Ürünler Metotları ---

  Future<List<UrunModel>> hizliUrunleriGetir() async {
    if (!_isInitialized) await baslat();
    final result = await _pool!.execute('''
      SELECT p.* FROM products p
      INNER JOIN quick_products qp ON p.id = qp.product_id
      ORDER BY qp.display_order ASC, qp.id ASC
    ''');
    return result.map((row) => UrunModel.fromMap(row.toColumnMap())).toList();
  }

  Future<void> hizliUruneEkle(int urunId) async {
    if (!_isInitialized) await baslat();
    await _pool!.execute(
      Sql.named(
        'INSERT INTO quick_products (product_id) VALUES (@id) ON CONFLICT (product_id) DO NOTHING',
      ),
      parameters: {'id': urunId},
    );
  }

  Future<void> hizliUrundenCikar(int urunId) async {
    if (!_isInitialized) await baslat();
    await _pool!.execute(
      Sql.named('DELETE FROM quick_products WHERE product_id = @id'),
      parameters: {'id': urunId},
    );
  }

  Future<String> _getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_username') ?? 'system';
  }

  int? _extractTrailingNumber(String input) {
    final match = RegExp(r'(\d+)$').firstMatch(input.trim());
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  // --- ÜRÜN İŞLEMLERİ ---

  Future<bool> urunKoduVarMi(String kod, {int? haricId}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    // 1. Products tablosunda kontrol
    String query1 = 'SELECT 1 FROM products WHERE kod = @kod';
    final Map<String, dynamic> params1 = {'kod': kod};

    if (haricId != null) {
      query1 += ' AND id != @id';
      params1['id'] = haricId;
    }

    query1 += ' LIMIT 1';

    final result1 = await _pool!.execute(
      Sql.named(query1),
      parameters: params1,
    );
    if (result1.isNotEmpty) return true;

    // 2. Productions tablosunda kontrol (Ortak havuz)
    // Ürün kaydederken, herhangi bir üretim kaydıyla çakışma olup olmadığına bakılır.
    // Productions tablosundaki ID, ürün ID'si ile aynı değildir, bu yüzden haricId burada kullanılmaz.
    try {
      const String query2 =
          'SELECT 1 FROM productions WHERE kod = @kod LIMIT 1';
      final Map<String, dynamic> params2 = {'kod': kod};
      final result2 = await _pool!.execute(
        Sql.named(query2),
        parameters: params2,
      );
      return result2.isNotEmpty;
    } catch (e) {
      // productions tablosu henüz oluşturulmamışsa (42P01), sadece products kontrolü yeterli
      debugPrint('Productions tablo kontrolü atlandı: $e');
      return false;
    }
  }

  Future<UrunModel?> urunGetir({required String kod}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    final result = await _pool!.execute(
      Sql.named('SELECT * FROM products WHERE kod = @kod LIMIT 1'),
      parameters: {'kod': kod},
    );

    if (result.isEmpty) return null;

    final row = result.first.toColumnMap();
    return UrunModel.fromMap(row);
  }

  Future<UrunModel?> urunGetirById(int id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    final result = await _pool!.execute(
      Sql.named('SELECT * FROM products WHERE id = @id LIMIT 1'),
      parameters: {'id': id},
    );

    if (result.isEmpty) return null;

    final row = result.first.toColumnMap();
    return UrunModel.fromMap(row);
  }

  /// Entegrasyon referansına bağlı stok hareketlerinden ilk ürünü bulur.
  ///
  /// Perakende satış gibi (RETAIL-*) akışlarda banka/kasa/kart işlemleri
  /// ürün bilgisini taşımaz; ürün kartına gidebilmek için entegrasyon ref
  /// üzerinden stok hareketlerinden ürün tespit edilir.
  Future<UrunModel?> urunGetirByIntegrationRef(
    String integrationRef, {
    TxSession? session,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    final ref = integrationRef.trim();
    if (ref.isEmpty) return null;

    final executor = session ?? _pool!;

    final productResult = await executor.execute(
      Sql.named('''
        SELECT product_id
        FROM stock_movements
        WHERE integration_ref = @ref
        ORDER BY movement_date ASC
        LIMIT 1
      '''),
      parameters: {'ref': ref},
    );
    if (productResult.isEmpty) return null;

    final int? productId = productResult.first[0] as int?;
    if (productId == null) return null;

    final productRow = await executor.execute(
      Sql.named('SELECT * FROM products WHERE id = @id LIMIT 1'),
      parameters: {'id': productId},
    );
    if (productRow.isEmpty) return null;

    return UrunModel.fromMap(productRow.first.toColumnMap());
  }

  Future<List<UrunModel>> urunleriGetir({
    int sayfa = 1,
    int sayfaBasinaKayit = 25,
    String? aramaTerimi,
    String? sortBy,
    bool sortAscending = true,
    bool? aktifMi,
    String? grup,
    String? birim,
    double? kdvOrani,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    List<int>? depoIds,
    String? islemTuru,
    String? kullanici,
    List<int>? sadeceIdler, // Harici arama indeksi gibi kaynaklardan gelen ID filtreleri
    int? lastId, // Keyset Pagination Cursor
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    // Sorting logic - Keyset Pagination Optimization
    // Keyset pagination requires deterministic sorting.
    String sortColumn = 'id';
    switch (sortBy) {
      case 'kod':
        sortColumn = 'kod';
        break;
      case 'ad':
        sortColumn = 'ad';
        break;
      case 'fiyat':
        sortColumn = 'alis_fiyati';
        break;
      case 'satis_fiyati_1':
        sortColumn = 'satis_fiyati_1';
        break;
      case 'stok':
        sortColumn = (depoIds != null && depoIds.isNotEmpty)
            ? 'depo_stogu'
            : 'stok';
        break;
      case 'birim':
        sortColumn = 'birim';
        break;
      case 'aktif_mi':
        sortColumn = 'aktif_mi';
        break;
      default:
        sortColumn = 'id';
    }
    final String direction = sortAscending ? 'ASC' : 'DESC';

    final String? depoStoguExpr = (depoIds != null && depoIds.isNotEmpty)
        ? '''
        (
          SELECT COALESCE(SUM(quantity), 0)
          FROM warehouse_stocks ws_sum
          WHERE ws_sum.product_code = products.kod
            AND ws_sum.warehouse_id = ANY(@depoIdArray)
        )
      '''
        : null;

    // [2025 HYBRID PAGINATION]
    // UI'dan gelen 'lastId' ile cursor değerini sunucuda oluştur.
    dynamic lastSortValue;
    if (lastId != null && lastId > 0 && sortColumn != 'id') {
      try {
        final String cursorExpr =
            sortColumn == 'depo_stogu' ? (depoStoguExpr ?? '0') : sortColumn;

        final cursorParams = <String, dynamic>{'id': lastId};
        if (sortColumn == 'depo_stogu' && depoIds != null && depoIds.isNotEmpty) {
          cursorParams['depoIdArray'] = depoIds;
        }

        final cursorRow = await _pool!.execute(
          Sql.named('SELECT $cursorExpr FROM products WHERE id = @id LIMIT 1'),
          parameters: cursorParams,
        );
        if (cursorRow.isNotEmpty) {
          lastSortValue = cursorRow.first[0];
        }
      } catch (e) {
        debugPrint('Product cursor fetch error: $e');
      }
    }

    // Select Clause
    String selectClause = 'SELECT products.*';
    String query;

    // 1 Milyar Kayıt Optimisazyonu: Deep Search (Derin Arama)
    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      // Logic: Eğer 'search_tags' (Tüm Veri) eşleşiyor AMA
      // Görünen ana alanlar (Kod, Ad, Barkod) eşleşmiyorsa -> Bu bir "Gizli/Detay" eşleşmesidir.
      // Bu sayede satır otomatik genişler.
      selectClause += '''
          , (CASE 
              WHEN (
	                (
	                  (
	                    products.search_tags ILIKE @search
	                    OR to_tsvector('simple', products.search_tags) @@ plainto_tsquery('simple', @fts)
	                  )
	                  OR EXISTS (
	                    SELECT 1
	                    FROM stock_movements sm
	                    WHERE sm.product_id = products.id
	                      AND (
	                        sm.search_tags ILIKE @search
	                        OR to_tsvector('simple', sm.search_tags) @@ plainto_tsquery('simple', @fts)
	                      )
	                    LIMIT 1
	                  )
	                )
                AND NOT (
                  kod ILIKE @search OR 
                  ad ILIKE @search OR 
                  barkod ILIKE @search OR
                  COALESCE(grubu, '') ILIKE @search
                )
              )
              THEN true 
              ELSE false 
             END) as matched_in_hidden
      ''';
    } else {
      selectClause += ', false as matched_in_hidden';
    }

    if (depoStoguExpr != null) {
      // Depo görünümünde stok, seçili depoların toplamıdır (parametreli ANY).
      selectClause += ''', $depoStoguExpr as depo_stogu''';
    }

    // Filter conditions
    List<String> whereConditions = [];
    Map<String, dynamic> params = {};

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      // 1 Milyar Kayıt İçin Tekil İndeks Araması
      // GIN indeksi (gin_trgm_ops) ILIKE ve LIKE operatorlerini destekler.
      // Ancak '%' ile baslayan LIKE sorgulari normal B-Tree indekslerini oldurur,
      // fakat Trigram indeksler ile calisir. Yine de garanti performans icin ILIKE kullaniyoruz
      // ve "Full Text Search" mantigini simule ediyoruz.
	      whereConditions.add('''
	        (
	          (
	            products.search_tags ILIKE @search
	            OR to_tsvector('simple', products.search_tags) @@ plainto_tsquery('simple', @fts)
	          )
	          OR EXISTS (
	            SELECT 1
	            FROM stock_movements sm
	            WHERE sm.product_id = products.id
	              AND (
	                sm.search_tags ILIKE @search
	                OR to_tsvector('simple', sm.search_tags) @@ plainto_tsquery('simple', @fts)
	              )
	            LIMIT 1
	          )
	        )
	      '''); // Optimized for GIN
	      params['search'] = '%${aramaTerimi.toLowerCase()}%';
	      params['fts'] = aramaTerimi.toLowerCase();
	    }

    if (aktifMi != null) {
      whereConditions.add('products.aktif_mi = @aktifMi');
      params['aktifMi'] = aktifMi ? 1 : 0;
    }

    if (grup != null) {
      whereConditions.add('products.grubu = @grup');
      params['grup'] = grup;
    }

    if (birim != null) {
      whereConditions.add('products.birim = @birim');
      params['birim'] = birim;
    }

    if (kdvOrani != null) {
      whereConditions.add('products.kdv_orani = @kdvOrani');
      params['kdvOrani'] = kdvOrani;
    }

    if (sadeceIdler != null && sadeceIdler.isNotEmpty) {
      whereConditions.add('products.id = ANY(@idArray)');
      params['idArray'] = sadeceIdler;
    }

    // Tarih / İşlem Türü / Kullanıcı filtresi (stock_movements üzerinden)
    if (baslangicTarihi != null ||
        bitisTarihi != null ||
        islemTuru != null ||
        kullanici != null) {
      final bool needsShipmentJoin = islemTuru == 'Devir Çıktı';
      String existsQuery = '''
        EXISTS (
          SELECT 1 FROM stock_movements sm
      ''';

      if (needsShipmentJoin) {
        existsQuery += ' JOIN shipments s ON s.id = sm.shipment_id';
      }

      existsQuery += ' WHERE sm.product_id = products.id';

      if (baslangicTarihi != null) {
        existsQuery += ' AND sm.movement_date >= @startDate';
        params['startDate'] = baslangicTarihi.toIso8601String();
      }
      if (bitisTarihi != null) {
        existsQuery += ' AND sm.movement_date <= @endDate';
        final eDate = bitisTarihi;
        final endOfDay = DateTime(
          eDate.year,
          eDate.month,
          eDate.day,
          23,
          59,
          59,
          999,
        );
        params['endDate'] = endOfDay.toIso8601String();
      }

      if (kullanici != null && kullanici.trim().isNotEmpty) {
        existsQuery += ' AND COALESCE(sm.created_by, \'\') = @movementUser';
        params['movementUser'] = kullanici.trim();
      }

      if (islemTuru != null && islemTuru.trim().isNotEmpty) {
        switch (islemTuru.trim()) {
          case 'Açılış Stoğu (Girdi)':
            existsQuery +=
                " AND sm.movement_type = 'giris' AND (sm.integration_ref = 'opening_stock' OR COALESCE(sm.description, '') ILIKE '%Açılış%')";
            break;
          case 'Devir Girdi':
            existsQuery +=
                " AND sm.movement_type = 'giris' AND NOT (sm.integration_ref = 'opening_stock' OR COALESCE(sm.description, '') ILIKE '%Açılış%') AND NOT (COALESCE(sm.integration_ref, '') LIKE 'PURCHASE-%' OR sm.movement_type = 'Alış Faturası' OR COALESCE(sm.description, '') ILIKE 'Alış%' OR COALESCE(sm.description, '') ILIKE 'Alis%')";
            break;
          case 'Devir Çıktı':
            existsQuery +=
                " AND sm.movement_type = 'cikis' AND NOT (sm.integration_ref = 'production_output' OR COALESCE(sm.description, '') ILIKE '%Üretim (Çıktı)%') AND NOT ((COALESCE(sm.integration_ref, '') LIKE 'SALE-%' OR COALESCE(sm.integration_ref, '') LIKE 'RETAIL-%') OR sm.movement_type = 'Satış Faturası' OR COALESCE(sm.description, '') ILIKE 'Satış%' OR COALESCE(sm.description, '') ILIKE 'Satis%') AND s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL";
            break;
          case 'Sevkiyat':
            existsQuery += " AND sm.movement_type = 'transfer_giris'";
            break;
          case 'Satış Yapıldı':
          case 'Satış Faturası':
            existsQuery +=
                " AND ((COALESCE(sm.integration_ref, '') LIKE 'SALE-%' OR COALESCE(sm.integration_ref, '') LIKE 'RETAIL-%') OR sm.movement_type = 'Satış Faturası' OR COALESCE(sm.description, '') ILIKE 'Satış%' OR COALESCE(sm.description, '') ILIKE 'Satis%')";
            break;
          case 'Alış Yapıldı':
          case 'Alış Faturası':
            existsQuery +=
                " AND (COALESCE(sm.integration_ref, '') LIKE 'PURCHASE-%' OR sm.movement_type = 'Alış Faturası' OR COALESCE(sm.description, '') ILIKE 'Alış%' OR COALESCE(sm.description, '') ILIKE 'Alis%')";
            break;
          case 'Üretim Girişi':
          case 'Üretim (Girdi)':
            existsQuery += " AND sm.movement_type = 'uretim_giris'";
            break;
          case 'Üretim Çıkışı':
          case 'Üretim (Çıktı)':
            existsQuery +=
                " AND sm.movement_type = 'cikis' AND (sm.integration_ref = 'production_output' OR COALESCE(sm.description, '') ILIKE '%Üretim (Çıktı)%')";
            break;
        }
      }

      existsQuery += ')';
      whereConditions.add(existsQuery);
    }

    String joinClause = '';

    // Depo Filtrelemesi: warehouse_stocks tablosunu kullanır (New Architecture)
    if (depoIds != null && depoIds.isNotEmpty) {
      // Join yerine EXISTS kullanıyoruz (Multi-select için daha güvenli ve duplicate yapmaz)
      whereConditions.add('''
        EXISTS (
          SELECT 1 FROM warehouse_stocks ws_filter 
          WHERE ws_filter.product_code = products.kod 
          AND ws_filter.warehouse_id = ANY(@depoIdArray)
          AND ws_filter.quantity > 0
        )
      ''');
      params['depoIdArray'] = depoIds;
    }

    // Optimized Query Construction
    // [2025 KEYSET PAGINATION LOGIC]
    if (lastId != null && lastId > 0) {
      final String op = direction == 'ASC' ? '>' : '<';

      if (sortColumn == 'id' || sortColumn == 'products.id') {
        whereConditions.add('products.id $op @lastId');
        params['lastId'] = lastId;
      } else if (sortColumn == 'depo_stogu') {
        if (depoStoguExpr != null && lastSortValue != null) {
          whereConditions.add(
            '($depoStoguExpr, products.id) $op (@lastSort, @lastId)',
          );
          params['lastSort'] = lastSortValue;
          params['lastId'] = lastId;
        } else {
          // Fallback: id cursor
          whereConditions.add('products.id $op @lastId');
          params['lastId'] = lastId;
        }
      } else {
        final String dbSortCol = sortColumn.startsWith('products.')
            ? sortColumn
            : 'products.$sortColumn';

        if (lastSortValue != null) {
          whereConditions.add(
            '($dbSortCol $op @lastSort OR ($dbSortCol = @lastSort AND products.id $op @lastId))',
          );
          params['lastSort'] = lastSortValue;
          params['lastId'] = lastId;
        } else {
          // Fallback: id cursor
          whereConditions.add('products.id $op @lastId');
          params['lastId'] = lastId;
        }
      }
    }

    final String whereClause = whereConditions.isNotEmpty
        ? 'WHERE ${whereConditions.join(' AND ')}'
        : '';

    final String orderByClause = sortColumn == 'id'
        ? 'ORDER BY products.id $direction'
        : 'ORDER BY $sortColumn $direction, products.id $direction';

    query =
        '''
      $selectClause
      FROM products
      $joinClause
      $whereClause
      $orderByClause
      LIMIT @limit
    ''';

    params['limit'] = sayfaBasinaKayit;

    // Fix: Date End Inclusive
    if (params.containsKey('endDate')) {
      // Ensure endDate covers the full day
      final eDate = DateTime.parse(params['endDate']);
      final endOfDay = DateTime(
        eDate.year,
        eDate.month,
        eDate.day,
        23,
        59,
        59,
        999,
      );
      params['endDate'] = endOfDay.toIso8601String();
    }

    final result = await _pool!.execute(Sql.named(query), parameters: params);

    // Ağır map işlemini Isolate'e taşıyoruz (mobilde unsendable tipler için güvenli fallback ile)
    final List<Map<String, dynamic>> dataList = result
        .map((row) {
          final map = row.toColumnMap();
          if (depoIds != null &&
              depoIds.isNotEmpty &&
              map.containsKey('depo_stogu')) {
            map['stok'] = map['depo_stogu']; // Display local stock
          }
          _makeIsolateSafeMapInPlace(map);
          return map;
        })
        .toList(growable: false);

    try {
      return await compute(_parseUrunlerIsolate, dataList);
    } catch (e) {
      // iOS/Android'de bazı Postgres tipleri (örn: UndecodedBytes/DateTime) isolate mesajına
      // gönderilemediği için compute patlayabiliyor. Bu durumda ana isolate'te parse ediyoruz.
      debugPrint(
        'UrunlerVeritabaniServisi: Isolate parse başarısız, fallback devrede: $e',
      );
      return dataList.map(UrunModel.fromMap).toList(growable: false);
    }
  }

  Future<int> urunSayisiGetir({
    String? aramaTerimi,
    bool? aktifMi,
    String? grup,
    String? birim,
    double? kdvOrani,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    List<int>? depoIds,
    String? islemTuru,
    String? kullanici,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;

    String query = 'SELECT COUNT(*) FROM products';
    Map<String, dynamic> params = {};
    List<String> whereConditions = [];

    String joinClause = '';

    // 1 Milyar Kayıt Optimisazyonu: Hızlı Sayım (Metadata Based Count)
    // Eğer HİÇBİR filtre yoksa, direkt cache tablosundan oku (O(1) süre)
    if (aramaTerimi == null &&
        aktifMi == null &&
        grup == null &&
        birim == null &&
        kdvOrani == null &&
        islemTuru == null &&
        kullanici == null &&
        baslangicTarihi == null &&
        bitisTarihi == null &&
        (depoIds == null || depoIds.isEmpty)) {
      final countResult = await _pool!.execute(
        "SELECT row_count FROM table_counts WHERE table_name = 'products'",
      );
      if (countResult.isNotEmpty) {
        return (countResult.first[0] as int?) ?? 0;
      }
    }

    if (depoIds != null && depoIds.isNotEmpty) {
      whereConditions.add('''
        EXISTS (
          SELECT 1 FROM warehouse_stocks ws_filter 
          WHERE ws_filter.product_code = products.kod 
          AND ws_filter.warehouse_id = ANY(@depoIdArray)
          AND ws_filter.quantity > 0
        )
      ''');
      params['depoIdArray'] = depoIds;
    }

    // Add join clause to query if needed
    query += joinClause;

	    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
	      whereConditions.add('''
	        (
	          (
	            products.search_tags LIKE @search
	            OR to_tsvector('simple', products.search_tags) @@ plainto_tsquery('simple', @fts)
	          )
	          OR EXISTS (
	            SELECT 1
	            FROM stock_movements sm
	            WHERE sm.product_id = products.id
	              AND (
	                sm.search_tags LIKE @search
	                OR to_tsvector('simple', sm.search_tags) @@ plainto_tsquery('simple', @fts)
	              )
	            LIMIT 1
	          )
	        )
	      ''');
	      params['search'] = '%${aramaTerimi.toLowerCase()}%';
	      params['fts'] = aramaTerimi.toLowerCase();
	    }

    if (aktifMi != null) {
      whereConditions.add('products.aktif_mi = @aktifMi');
      params['aktifMi'] = aktifMi ? 1 : 0;
    }

    if (grup != null) {
      whereConditions.add('products.grubu = @grup');
      params['grup'] = grup;
    }

    if (birim != null) {
      whereConditions.add('products.birim = @birim');
      params['birim'] = birim;
    }

    if (kdvOrani != null) {
      whereConditions.add('products.kdv_orani = @kdvOrani');
      params['kdvOrani'] = kdvOrani;
    }

    // Tarih / İşlem Türü / Kullanıcı filtresi (stock_movements üzerinden)
    if (baslangicTarihi != null ||
        bitisTarihi != null ||
        islemTuru != null ||
        kullanici != null) {
      final bool needsShipmentJoin = islemTuru == 'Devir Çıktı';
      String existsQuery = '''
        EXISTS (
          SELECT 1 FROM stock_movements sm
      ''';

      if (needsShipmentJoin) {
        existsQuery += ' JOIN shipments s ON s.id = sm.shipment_id';
      }

      existsQuery += ' WHERE sm.product_id = products.id';

      if (baslangicTarihi != null) {
        existsQuery += ' AND sm.movement_date >= @startDate';
        params['startDate'] = baslangicTarihi.toIso8601String();
      }
      if (bitisTarihi != null) {
        existsQuery += ' AND sm.movement_date <= @endDate';
        params['endDate'] = bitisTarihi.toIso8601String();
      }

      if (kullanici != null && kullanici.trim().isNotEmpty) {
        existsQuery += ' AND COALESCE(sm.created_by, \'\') = @movementUser';
        params['movementUser'] = kullanici.trim();
      }

      if (islemTuru != null && islemTuru.trim().isNotEmpty) {
        switch (islemTuru.trim()) {
          case 'Açılış Stoğu (Girdi)':
            existsQuery +=
                " AND sm.movement_type = 'giris' AND (sm.integration_ref = 'opening_stock' OR COALESCE(sm.description, '') ILIKE '%Açılış%')";
            break;
          case 'Devir Girdi':
            existsQuery +=
                " AND sm.movement_type = 'giris' AND NOT (sm.integration_ref = 'opening_stock' OR COALESCE(sm.description, '') ILIKE '%Açılış%') AND NOT (COALESCE(sm.integration_ref, '') LIKE 'PURCHASE-%' OR sm.movement_type = 'Alış Faturası' OR COALESCE(sm.description, '') ILIKE 'Alış%' OR COALESCE(sm.description, '') ILIKE 'Alis%')";
            break;
          case 'Devir Çıktı':
            existsQuery +=
                " AND sm.movement_type = 'cikis' AND NOT (sm.integration_ref = 'production_output' OR COALESCE(sm.description, '') ILIKE '%Üretim (Çıktı)%') AND NOT ((COALESCE(sm.integration_ref, '') LIKE 'SALE-%' OR COALESCE(sm.integration_ref, '') LIKE 'RETAIL-%') OR sm.movement_type = 'Satış Faturası' OR COALESCE(sm.description, '') ILIKE 'Satış%' OR COALESCE(sm.description, '') ILIKE 'Satis%') AND s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL";
            break;
          case 'Sevkiyat':
            existsQuery += " AND sm.movement_type = 'transfer_giris'";
            break;
          case 'Satış Yapıldı':
          case 'Satış Faturası':
            existsQuery +=
                " AND ((COALESCE(sm.integration_ref, '') LIKE 'SALE-%' OR COALESCE(sm.integration_ref, '') LIKE 'RETAIL-%') OR sm.movement_type = 'Satış Faturası' OR COALESCE(sm.description, '') ILIKE 'Satış%' OR COALESCE(sm.description, '') ILIKE 'Satis%')";
            break;
          case 'Alış Yapıldı':
          case 'Alış Faturası':
            existsQuery +=
                " AND (COALESCE(sm.integration_ref, '') LIKE 'PURCHASE-%' OR sm.movement_type = 'Alış Faturası' OR COALESCE(sm.description, '') ILIKE 'Alış%' OR COALESCE(sm.description, '') ILIKE 'Alis%')";
            break;
          case 'Üretim Girişi':
          case 'Üretim (Girdi)':
            existsQuery += " AND sm.movement_type = 'uretim_giris'";
            break;
          case 'Üretim Çıkışı':
          case 'Üretim (Çıktı)':
            existsQuery +=
                " AND sm.movement_type = 'cikis' AND (sm.integration_ref = 'production_output' OR COALESCE(sm.description, '') ILIKE '%Üretim (Çıktı)%')";
            break;
        }
      }

      existsQuery += ')';
      whereConditions.add(existsQuery);
    }

    if (whereConditions.isNotEmpty) {
      query += ' WHERE ${whereConditions.join(' AND ')}';

      // 🚀 ESTIMATE COUNT OPTIMIZATION

      try {
        String filterQueryForPlan = 'SELECT 1 FROM products';
        if (joinClause.isNotEmpty) filterQueryForPlan += ' $joinClause';
        if (whereConditions.isNotEmpty) {
          filterQueryForPlan += ' WHERE ${whereConditions.join(' AND ')}';
        }

        final planResult = await _pool!.execute(
          Sql.named("EXPLAIN (FORMAT JSON) $filterQueryForPlan"),
          parameters: params,
        );
        final planJson = planResult[0][0];

        if (planJson != null) {
          dynamic decoded;
          if (planJson is String) {
            decoded = jsonDecode(planJson);
          } else {
            decoded = planJson;
          }
          if (decoded is List && decoded.isNotEmpty) {
            final planRows =
                num.tryParse(
                  decoded[0]['Plan']['Plan Rows']?.toString() ?? '',
                ) ??
                0;
            if (planRows > 100000) {
              return planRows.toInt();
            }
          }
        }
      } catch (e) {
        debugPrint('Count Estimate Failed: $e');
      }
    } else {
      final estimateResult = await _pool!.execute(
        "SELECT reltuples::bigint AS estimate FROM pg_class WHERE relname = 'products'",
      );
      if (estimateResult.isNotEmpty && estimateResult[0][0] != null) {
        final estimate = estimateResult[0][0] as int;
        if (estimate > 0) return estimate;
      }
    }

    // Fix: Date End Inclusive
    if (params.containsKey('endDate')) {
      final eDate = DateTime.parse(params['endDate']);
      final endOfDay = DateTime(
        eDate.year,
        eDate.month,
        eDate.day,
        23,
        59,
        59,
        999,
      );
      params['endDate'] = endOfDay.toIso8601String();
    }

    final result = await _pool!.execute(Sql.named(query), parameters: params);
    return result[0][0] as int;
  }

  /// [2026] Ürünler sayfası için dinamik filtre istatistiklerini (facet counts) getirir.
  /// Cari Hesaplar ekranındaki gibi her filtre seçeneğinde "(n)" gösterebilmek için kullanılır.
  Future<Map<String, Map<String, int>>> urunFiltreIstatistikleriniGetir({
    String? aramaTerimi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    bool? aktifMi,
    String? grup,
    String? birim,
    double? kdvOrani,
    List<int>? depoIds,
    String? islemTuru,
    String? kullanici,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return {};

    const List<String> supportedStockTypes = <String>[
      'Açılış Stoğu (Girdi)',
      'Devir Girdi',
      'Devir Çıktı',
      'Sevkiyat',
      'Üretim Girişi',
      'Üretim Çıkışı',
      'Satış Yapıldı',
      'Alış Yapıldı',
    ];

    String buildWhere(List<String> conds) {
      return conds.isEmpty ? '' : 'WHERE ${conds.join(' AND ')}';
    }

    DateTime? endOfDay(DateTime? d) {
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
    }

    void addProductConds(
      List<String> conds,
      Map<String, dynamic> params, {
      String? q,
      bool? aktif,
      String? g,
      String? u,
      double? vat,
      List<int>? depolar,
    }) {
	      final String? trimmedQ = q?.trim();
	      if (trimmedQ != null && trimmedQ.isNotEmpty) {
	        conds.add('''
	          (
	            (
	              products.search_tags ILIKE @search
	              OR to_tsvector('simple', products.search_tags) @@ plainto_tsquery('simple', @fts)
	            )
	            OR EXISTS (
	              SELECT 1
	              FROM stock_movements sm_search
	              WHERE sm_search.product_id = products.id
	                AND (
	                  sm_search.search_tags ILIKE @search
	                  OR to_tsvector('simple', sm_search.search_tags) @@ plainto_tsquery('simple', @fts)
	                )
	              LIMIT 1
	            )
	          )
	        ''');
	        params['search'] = '%${trimmedQ.toLowerCase()}%';
	        params['fts'] = trimmedQ.toLowerCase();
	      }

      if (aktif != null) {
        conds.add('products.aktif_mi = @aktifMi');
        params['aktifMi'] = aktif ? 1 : 0;
      }

      final String? trimmedGroup = g?.trim();
      if (trimmedGroup != null && trimmedGroup.isNotEmpty) {
        conds.add('products.grubu = @grup');
        params['grup'] = trimmedGroup;
      }

      final String? trimmedUnit = u?.trim();
      if (trimmedUnit != null && trimmedUnit.isNotEmpty) {
        conds.add('products.birim = @birim');
        params['birim'] = trimmedUnit;
      }

      if (vat != null) {
        conds.add('products.kdv_orani = @kdvOrani');
        params['kdvOrani'] = vat;
      }

      if (depolar != null && depolar.isNotEmpty) {
        conds.add('''
          EXISTS (
            SELECT 1 FROM warehouse_stocks ws_filter
            WHERE ws_filter.product_code = products.kod
              AND ws_filter.warehouse_id = ANY(@depoIdArray)
              AND ws_filter.quantity > 0
          )
        ''');
        params['depoIdArray'] = depolar;
      }
    }

    String? buildMovementTypeCondition({
      required String type,
      required bool includeShipmentConstraint,
    }) {
      switch (type) {
        case 'Açılış Stoğu (Girdi)':
          return "sm.movement_type = 'giris' AND (sm.integration_ref = 'opening_stock' OR COALESCE(sm.description, '') ILIKE '%Açılış%')";
        case 'Devir Girdi':
          return "sm.movement_type = 'giris' AND NOT (sm.integration_ref = 'opening_stock' OR COALESCE(sm.description, '') ILIKE '%Açılış%') AND NOT (COALESCE(sm.integration_ref, '') LIKE 'PURCHASE-%' OR sm.movement_type = 'Alış Faturası' OR COALESCE(sm.description, '') ILIKE 'Alış%' OR COALESCE(sm.description, '') ILIKE 'Alis%')";
        case 'Devir Çıktı':
          return "sm.movement_type = 'cikis' AND NOT (sm.integration_ref = 'production_output' OR COALESCE(sm.description, '') ILIKE '%Üretim (Çıktı)%') AND NOT ((COALESCE(sm.integration_ref, '') LIKE 'SALE-%' OR COALESCE(sm.integration_ref, '') LIKE 'RETAIL-%') OR sm.movement_type = 'Satış Faturası' OR COALESCE(sm.description, '') ILIKE 'Satış%' OR COALESCE(sm.description, '') ILIKE 'Satis%')${includeShipmentConstraint ? ' AND s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL' : ''}";
        case 'Sevkiyat':
          return "sm.movement_type = 'transfer_giris'";
        case 'Üretim Girişi':
          return "sm.movement_type = 'uretim_giris'";
        case 'Üretim Çıkışı':
          return "sm.movement_type = 'cikis' AND (sm.integration_ref = 'production_output' OR COALESCE(sm.description, '') ILIKE '%Üretim (Çıktı)%')";
        case 'Satış Yapıldı':
        case 'Satış Faturası':
          return "((COALESCE(sm.integration_ref, '') LIKE 'SALE-%' OR COALESCE(sm.integration_ref, '') LIKE 'RETAIL-%') OR sm.movement_type = 'Satış Faturası' OR COALESCE(sm.description, '') ILIKE 'Satış%' OR COALESCE(sm.description, '') ILIKE 'Satis%')";
        case 'Alış Yapıldı':
        case 'Alış Faturası':
          return "(COALESCE(sm.integration_ref, '') LIKE 'PURCHASE-%' OR sm.movement_type = 'Alış Faturası' OR COALESCE(sm.description, '') ILIKE 'Alış%' OR COALESCE(sm.description, '') ILIKE 'Alis%')";
      }
      return null;
    }

    String buildMovementExists({
      required Map<String, dynamic> params,
      DateTime? start,
      DateTime? end,
      String? type,
      String? user,
    }) {
      final String? trimmedUser = user?.trim();
      final String? trimmedType = type?.trim();

      if (start == null &&
          end == null &&
          (trimmedUser == null || trimmedUser.isEmpty) &&
          (trimmedType == null || trimmedType.isEmpty)) {
        return '';
      }

      final bool needsShipmentJoin = trimmedType == 'Devir Çıktı';

      final List<String> movementConds = ['sm.product_id = products.id'];

      if (start != null) {
        movementConds.add('sm.movement_date >= @startDate');
        params['startDate'] = start.toIso8601String();
      }
      if (end != null) {
        movementConds.add('sm.movement_date <= @endDate');
        params['endDate'] = endOfDay(end)!.toIso8601String();
      }

      if (trimmedUser != null && trimmedUser.isNotEmpty) {
        movementConds.add("COALESCE(sm.created_by, '') = @movementUser");
        params['movementUser'] = trimmedUser;
      }

      if (trimmedType != null && trimmedType.isNotEmpty) {
        final typeCond = buildMovementTypeCondition(
          type: trimmedType,
          includeShipmentConstraint: needsShipmentJoin,
        );
        if (typeCond != null && typeCond.isNotEmpty) {
          movementConds.add(typeCond);
        }
      }

      return '''
        EXISTS (
          SELECT 1 FROM stock_movements sm
          ${needsShipmentJoin ? 'JOIN shipments s ON s.id = sm.shipment_id' : ''}
          WHERE ${movementConds.join(' AND ')}
        )
      ''';
    }

    // 0) Genel toplam (arama + tarih) - diğer tüm facet seçimleri hariç
    final int genelToplam = await urunSayisiGetir(
      aramaTerimi: aramaTerimi,
      baslangicTarihi: baslangicTarihi,
      bitisTarihi: bitisTarihi,
    );

    // 1) Durum facet
    final statusParams = <String, dynamic>{};
    final statusConds = <String>[];
    addProductConds(
      statusConds,
      statusParams,
      q: aramaTerimi,
      aktif: null,
      g: grup,
      u: birim,
      vat: kdvOrani,
      depolar: depoIds,
    );
    final statusExists = buildMovementExists(
      params: statusParams,
      start: baslangicTarihi,
      end: bitisTarihi,
      type: islemTuru,
      user: kullanici,
    );
    if (statusExists.isNotEmpty) statusConds.add(statusExists);
    final statusQuery =
        '''
      SELECT products.aktif_mi, COUNT(*)
      FROM products
      ${buildWhere(statusConds)}
      GROUP BY 1
    ''';

    // 2) Grup facet
    final groupParams = <String, dynamic>{};
    final groupConds = <String>[];
    addProductConds(
      groupConds,
      groupParams,
      q: aramaTerimi,
      aktif: aktifMi,
      g: null,
      u: birim,
      vat: kdvOrani,
      depolar: depoIds,
    );
    final groupExists = buildMovementExists(
      params: groupParams,
      start: baslangicTarihi,
      end: bitisTarihi,
      type: islemTuru,
      user: kullanici,
    );
    if (groupExists.isNotEmpty) groupConds.add(groupExists);
    final groupQuery =
        '''
      SELECT COALESCE(products.grubu, '') as grubu, COUNT(*)
      FROM products
      ${buildWhere(groupConds)}
      GROUP BY 1
    ''';

    // 3) Birim facet
    final unitParams = <String, dynamic>{};
    final unitConds = <String>[];
    addProductConds(
      unitConds,
      unitParams,
      q: aramaTerimi,
      aktif: aktifMi,
      g: grup,
      u: null,
      vat: kdvOrani,
      depolar: depoIds,
    );
    final unitExists = buildMovementExists(
      params: unitParams,
      start: baslangicTarihi,
      end: bitisTarihi,
      type: islemTuru,
      user: kullanici,
    );
    if (unitExists.isNotEmpty) unitConds.add(unitExists);
    final unitQuery =
        '''
      SELECT COALESCE(products.birim, '') as birim, COUNT(*)
      FROM products
      ${buildWhere(unitConds)}
      GROUP BY 1
    ''';

    // 4) KDV facet
    final vatParams = <String, dynamic>{};
    final vatConds = <String>[];
    addProductConds(
      vatConds,
      vatParams,
      q: aramaTerimi,
      aktif: aktifMi,
      g: grup,
      u: birim,
      vat: null,
      depolar: depoIds,
    );
    final vatExists = buildMovementExists(
      params: vatParams,
      start: baslangicTarihi,
      end: bitisTarihi,
      type: islemTuru,
      user: kullanici,
    );
    if (vatExists.isNotEmpty) vatConds.add(vatExists);
    final vatQuery =
        '''
      SELECT COALESCE(CAST(products.kdv_orani AS TEXT), '') as kdv, COUNT(*)
      FROM products
      ${buildWhere(vatConds)}
      GROUP BY 1
    ''';

    // 5) Depo facet (warehouse_stocks üzerinden)
    final warehouseParams = <String, dynamic>{};
    final warehouseConds = <String>[];
    addProductConds(
      warehouseConds,
      warehouseParams,
      q: aramaTerimi,
      aktif: aktifMi,
      g: grup,
      u: birim,
      vat: kdvOrani,
      depolar: null, // Depo facet sayımı için depo seçimi facet olarak hariç
    );
    final warehouseExists = buildMovementExists(
      params: warehouseParams,
      start: baslangicTarihi,
      end: bitisTarihi,
      type: islemTuru,
      user: kullanici,
    );
    if (warehouseExists.isNotEmpty) warehouseConds.add(warehouseExists);
    final warehouseQuery =
        '''
      SELECT ws.warehouse_id, COUNT(DISTINCT products.id)
      FROM warehouse_stocks ws
      JOIN products ON products.kod = ws.product_code
      WHERE ws.quantity > 0
      ${warehouseConds.isNotEmpty ? 'AND ${warehouseConds.join(' AND ')}' : ''}
      GROUP BY ws.warehouse_id
    ''';

    // 6) İşlem türü facet (her tip için ürün sayısı)
    Future<int> countForType(String t) async {
      final typeParams = <String, dynamic>{};
      final typeConds = <String>[];
      addProductConds(
        typeConds,
        typeParams,
        q: aramaTerimi,
        aktif: aktifMi,
        g: grup,
        u: birim,
        vat: kdvOrani,
        depolar: depoIds,
      );
      final exists = buildMovementExists(
        params: typeParams,
        start: baslangicTarihi,
        end: bitisTarihi,
        type: t,
        user: kullanici, // kullanıcı seçimi facet olarak dahil
      );
      if (exists.isNotEmpty) typeConds.add(exists);
      final q = '''
        SELECT COUNT(*)
        FROM products
        ${buildWhere(typeConds)}
      ''';
      final res = await _pool!.execute(Sql.named(q), parameters: typeParams);
      return res.isEmpty ? 0 : (res.first[0] as int);
    }

    // 7) Kullanıcı facet (stock_movements.created_by üzerinden)
    final userParams = <String, dynamic>{};
    final userProductConds = <String>[];
    addProductConds(
      userProductConds,
      userParams,
      q: aramaTerimi,
      aktif: aktifMi,
      g: grup,
      u: birim,
      vat: kdvOrani,
      depolar: depoIds,
    );
    final String? trimmedSelectedType = islemTuru?.trim();
    final bool userNeedsShipmentJoin = trimmedSelectedType == 'Devir Çıktı';
    final List<String> userMovementConds = ['sm.product_id = products.id'];

    if (baslangicTarihi != null) {
      userMovementConds.add('sm.movement_date >= @startDate');
      userParams['startDate'] = baslangicTarihi.toIso8601String();
    }
    if (bitisTarihi != null) {
      userMovementConds.add('sm.movement_date <= @endDate');
      userParams['endDate'] = endOfDay(bitisTarihi)!.toIso8601String();
    }

    if (trimmedSelectedType != null && trimmedSelectedType.isNotEmpty) {
      final typeCond = buildMovementTypeCondition(
        type: trimmedSelectedType,
        includeShipmentConstraint: userNeedsShipmentJoin,
      );
      if (typeCond != null && typeCond.isNotEmpty) {
        userMovementConds.add(typeCond);
      }
    }

    final userQuery =
        '''
      SELECT COALESCE(sm.created_by, '') as kullanici, COUNT(DISTINCT products.id)
      FROM products
      JOIN stock_movements sm ON sm.product_id = products.id
      ${userNeedsShipmentJoin ? 'JOIN shipments s ON s.id = sm.shipment_id' : ''}
      ${buildWhere(userProductConds)}
      ${userProductConds.isNotEmpty ? 'AND' : 'WHERE'} ${userMovementConds.join(' AND ')}
      GROUP BY 1
    ''';

    try {
      final results = await Future.wait([
        _pool!.execute(Sql.named(statusQuery), parameters: statusParams),
        _pool!.execute(Sql.named(groupQuery), parameters: groupParams),
        _pool!.execute(Sql.named(unitQuery), parameters: unitParams),
        _pool!.execute(Sql.named(vatQuery), parameters: vatParams),
        _pool!.execute(Sql.named(warehouseQuery), parameters: warehouseParams),
        _pool!.execute(Sql.named(userQuery), parameters: userParams),
        Future.wait(supportedStockTypes.map(countForType)),
      ]);

      final Result statusRows = results[0] as Result;
      final Result groupRows = results[1] as Result;
      final Result unitRows = results[2] as Result;
      final Result vatRows = results[3] as Result;
      final Result warehouseRows = results[4] as Result;
      final Result userRows = results[5] as Result;
      final typeCounts = results[6] as List<int>;

      final Map<String, int> durumlar = {};
      for (final row in statusRows) {
        final key = (row[0] == 1 || row[0] == true) ? 'active' : 'passive';
        durumlar[key] = row[1] as int;
      }

      final Map<String, int> gruplar = {};
      for (final row in groupRows) {
        final key = row[0]?.toString() ?? '';
        if (key.trim().isNotEmpty) gruplar[key] = row[1] as int;
      }

      final Map<String, int> birimler = {};
      for (final row in unitRows) {
        final key = row[0]?.toString() ?? '';
        if (key.trim().isNotEmpty) birimler[key] = row[1] as int;
      }

      final Map<String, int> kdvler = {};
      for (final row in vatRows) {
        final key = row[0]?.toString() ?? '';
        if (key.trim().isNotEmpty) kdvler[key] = row[1] as int;
      }

      final Map<String, int> depolar = {};
      for (final row in warehouseRows) {
        final id = row[0];
        if (id == null) continue;
        depolar[id.toString()] = row[1] as int;
      }

      final Map<String, int> kullanicilar = {};
      for (final row in userRows) {
        final key = row[0]?.toString() ?? '';
        if (key.trim().isNotEmpty) kullanicilar[key] = row[1] as int;
      }

      final Map<String, int> islemTurleri = {};
      for (int i = 0; i < supportedStockTypes.length; i++) {
        final int c = typeCounts[i];
        if (c > 0) islemTurleri[supportedStockTypes[i]] = c;
      }

      return {
        'durumlar': durumlar,
        'gruplar': gruplar,
        'birimler': birimler,
        'kdvler': kdvler,
        'depolar': depolar,
        'islem_turleri': islemTurleri,
        'kullanicilar': kullanicilar,
        'ozet': {'toplam': genelToplam},
      };
    } catch (e) {
      debugPrint('Ürün filtre istatistikleri hatası: $e');
      return {
        'ozet': {'toplam': genelToplam},
      };
    }
  }

  // --- YARDIMCI VERİLER (CACHE TABLOSUNDAN) ---

  Future<List<String>> urunGruplariniGetir() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    // 1 Milyar Kayıt: Metadata Tablosundan Oku (O(1))
    final result = await _pool!.execute(
      "SELECT value FROM product_metadata WHERE type = 'group' ORDER BY value ASC",
    );
    return result.map((row) => row[0] as String).toList();
  }

  Future<List<String>> urunBirimleriniGetir() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    // 1 Milyar Kayıt: Metadata Tablosundan Oku (O(1))
    final result = await _pool!.execute(
      "SELECT value FROM product_metadata WHERE type = 'unit' ORDER BY value ASC",
    );
    return result.map((row) => row[0] as String).toList();
  }

  Future<List<double>> urunKdvOranlariniGetir() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    // 1 Milyar Kayıt: Metadata Tablosundan Oku (O(1))
    final result = await _pool!.execute(
      "SELECT value FROM product_metadata WHERE type = 'vat' ORDER BY value ASC",
    );
    return result
        .map((row) => double.tryParse(row[0] as String) ?? 0.0)
        .toList();
  }

  // --- TOPLU İŞLEMLER (QUERY-BASED ACTION) ---

  Future<void> topluUrunSilByFilter({
    String? aramaTerimi,
    bool? aktifMi,
    String? grup,
    String? birim,
    double? kdvOrani,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    List<int>? depoIds,
    String? islemTuru,
    String? kullanici,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    List<String> whereConditions = [];
    Map<String, dynamic> params = {};

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      whereConditions.add(
        "(search_tags LIKE @search OR to_tsvector('simple', search_tags) @@ plainto_tsquery('simple', @fts))",
      );
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
      params['fts'] = aramaTerimi.toLowerCase();
    }

    if (aktifMi != null) {
      whereConditions.add('aktif_mi = @aktifMi');
      params['aktifMi'] = aktifMi ? 1 : 0;
    }

    if (grup != null) {
      whereConditions.add('grubu = @grup');
      params['grup'] = grup;
    }

    if (birim != null) {
      whereConditions.add('birim = @birim');
      params['birim'] = birim;
    }

    if (kdvOrani != null) {
      whereConditions.add('kdv_orani = @kdvOrani');
      params['kdvOrani'] = kdvOrani;
    }

    if (baslangicTarihi != null ||
        bitisTarihi != null ||
        islemTuru != null ||
        kullanici != null) {
      final bool needsShipmentJoin = islemTuru == 'Devir Çıktı';
      String existsQuery = '''
          EXISTS (
            SELECT 1 FROM stock_movements sm
        ''';

      if (needsShipmentJoin) {
        existsQuery += ' JOIN shipments s ON s.id = sm.shipment_id';
      }

      existsQuery += ' WHERE sm.product_id = products.id';

      if (baslangicTarihi != null) {
        existsQuery += ' AND sm.movement_date >= @startDate';
        params['startDate'] = baslangicTarihi.toIso8601String();
      }
      if (bitisTarihi != null) {
        existsQuery += ' AND sm.movement_date <= @endDate';
        params['endDate'] = bitisTarihi.toIso8601String();
      }

      if (kullanici != null && kullanici.trim().isNotEmpty) {
        existsQuery += ' AND COALESCE(sm.created_by, \'\') = @movementUser';
        params['movementUser'] = kullanici.trim();
      }

      if (islemTuru != null && islemTuru.trim().isNotEmpty) {
        switch (islemTuru.trim()) {
          case 'Açılış Stoğu (Girdi)':
            existsQuery +=
                " AND sm.movement_type = 'giris' AND (sm.integration_ref = 'opening_stock' OR COALESCE(sm.description, '') ILIKE '%Açılış%')";
            break;
          case 'Devir Girdi':
            existsQuery +=
                " AND sm.movement_type = 'giris' AND NOT (sm.integration_ref = 'opening_stock' OR COALESCE(sm.description, '') ILIKE '%Açılış%') AND NOT (COALESCE(sm.integration_ref, '') LIKE 'PURCHASE-%' OR sm.movement_type = 'Alış Faturası' OR COALESCE(sm.description, '') ILIKE 'Alış%' OR COALESCE(sm.description, '') ILIKE 'Alis%')";
            break;
          case 'Devir Çıktı':
            existsQuery +=
                " AND sm.movement_type = 'cikis' AND NOT (sm.integration_ref = 'production_output' OR COALESCE(sm.description, '') ILIKE '%Üretim (Çıktı)%') AND NOT ((COALESCE(sm.integration_ref, '') LIKE 'SALE-%' OR COALESCE(sm.integration_ref, '') LIKE 'RETAIL-%') OR sm.movement_type = 'Satış Faturası' OR COALESCE(sm.description, '') ILIKE 'Satış%' OR COALESCE(sm.description, '') ILIKE 'Satis%') AND s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL";
            break;
          case 'Sevkiyat':
            existsQuery += " AND sm.movement_type = 'transfer_giris'";
            break;
          case 'Satış Yapıldı':
          case 'Satış Faturası':
            existsQuery +=
                " AND ((COALESCE(sm.integration_ref, '') LIKE 'SALE-%' OR COALESCE(sm.integration_ref, '') LIKE 'RETAIL-%') OR sm.movement_type = 'Satış Faturası' OR COALESCE(sm.description, '') ILIKE 'Satış%' OR COALESCE(sm.description, '') ILIKE 'Satis%')";
            break;
          case 'Alış Yapıldı':
          case 'Alış Faturası':
            existsQuery +=
                " AND (COALESCE(sm.integration_ref, '') LIKE 'PURCHASE-%' OR sm.movement_type = 'Alış Faturası' OR COALESCE(sm.description, '') ILIKE 'Alış%' OR COALESCE(sm.description, '') ILIKE 'Alis%')";
            break;
          case 'Üretim Girişi':
          case 'Üretim (Girdi)':
            existsQuery += " AND sm.movement_type = 'uretim_giris'";
            break;
          case 'Üretim Çıkışı':
          case 'Üretim (Çıktı)':
            existsQuery +=
                " AND sm.movement_type = 'cikis' AND (sm.integration_ref = 'production_output' OR COALESCE(sm.description, '') ILIKE '%Üretim (Çıktı)%')";
            break;
        }
      }

      existsQuery += ')';
      whereConditions.add(existsQuery);
    }

    if (depoIds != null && depoIds.isNotEmpty) {
      whereConditions.add('''
         EXISTS (
           SELECT 1 FROM warehouse_stocks ws_filter 
           WHERE ws_filter.product_code = products.kod 
           AND ws_filter.warehouse_id = ANY(@depoIdArray)
           AND ws_filter.quantity > 0
         )
       ''');
      params['depoIdArray'] = depoIds;
    }

    String whereClause = '';
    if (whereConditions.isNotEmpty) {
      whereClause = 'WHERE ${whereConditions.join(' AND ')}';
    }

    // Batch silme (büyük veri setlerinde güvenli)
    final int batchSize = _yapilandirma.batchSize;
    while (true) {
      final deleteSql = StringBuffer()
        ..writeln('WITH to_delete AS (')
        ..writeln('  SELECT id FROM products')
        ..writeln(whereClause.isNotEmpty ? '  $whereClause' : '')
        ..writeln('  ORDER BY id')
        ..writeln('  LIMIT @limit')
        ..writeln(')')
        ..writeln('DELETE FROM products p')
        ..writeln('USING to_delete d')
        ..writeln('WHERE p.id = d.id')
        ..writeln('RETURNING p.id;');

      final deleteParams = {...params, 'limit': batchSize};

      final result = await _pool!.execute(
        Sql.named(deleteSql.toString()),
        parameters: deleteParams,
      );

      if (result.isEmpty) {
        break;
      }
    }
  }

  Future<void> urunEkle(
    UrunModel urun, {
    int? initialStockWarehouseId,
    double? initialStockUnitCost,
    String? createdBy,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final currentUser = createdBy ?? await _getCurrentUser();

    // Depo seçimi zorunluluğu:
    // Ürün eklerken stok girildiyse, açılış stoğu kaydının sağlıklı oluşması için depo seçilmiş olmalı.
    if (urun.stok > 0) {
      final wid =
          (initialStockWarehouseId != null && initialStockWarehouseId > 0)
          ? initialStockWarehouseId
          : null;
      if (wid == null) {
        throw Exception('Lütfen bir depo seçiniz.');
      }

      try {
        await DepolarVeritabaniServisi().baslat();
      } catch (e) {
        debugPrint('Depolar servisi başlatılamadı (depo kontrolü): $e');
      }

      try {
        final exists = await _pool!.execute(
          Sql.named('SELECT 1 FROM depots WHERE id = @id LIMIT 1'),
          parameters: {'id': wid},
        );
        if (exists.isEmpty) {
          throw Exception('Lütfen bir depo seçiniz.');
        }
      } catch (e) {
        // Depo tablosu yoksa veya sorgu hata verirse kullanıcıya depo seçimi gerektiğini söyle
        if (e.toString().contains('Lütfen bir depo seçiniz.')) rethrow;
        throw Exception('Lütfen bir depo seçiniz.');
      }
    }

    final map = urun.toMap();
    map.remove('id');
    map['created_by'] = currentUser;
    map['created_at'] = DateTime.now();
    map.remove('cihazlar');

    // Sequence Update (Eğer numerik ise sayacı güncelle)
    final codeSeqVal = _extractTrailingNumber(urun.kod);
    if (codeSeqVal != null) {
      await _pool!.execute(
        Sql.named(
          "INSERT INTO sequences (name, current_value) VALUES ('product_code', @val) ON CONFLICT (name) DO UPDATE SET current_value = GREATEST(sequences.current_value, @val)",
        ),
        parameters: {'val': codeSeqVal},
      );
    }
    final barcodeSeqVal = _extractTrailingNumber(urun.barkod);
    if (barcodeSeqVal != null) {
      await _pool!.execute(
        Sql.named(
          "INSERT INTO sequences (name, current_value) VALUES ('barcode', @val) ON CONFLICT (name) DO UPDATE SET current_value = GREATEST(sequences.current_value, @val)",
        ),
        parameters: {'val': barcodeSeqVal},
      );
    }
    map['created_at'] = DateTime.now();
    map['resimler'] = jsonEncode(urun.resimler);

    // Search Tags Oluşturma (Denormalization)
    // Ürünün tüm aranabilir metinlerini birleştiriyoruz.
    final searchTags = [
      urun.kod,
      urun.ad,
      urun.barkod,
      urun.grubu,
      urun.kullanici,
      urun.ozellikler,
      urun.birim,
      urun.id.toString(),
      // Fiyatlar string olarak ekleniyor ki aramada bulunsun
      urun.alisFiyati.toString(),
      urun.satisFiyati1.toString(),
      urun.satisFiyati2.toString(),
      urun.satisFiyati3.toString(), // Eksik Fiyat 3
      urun.erkenUyariMiktari.toString(), // Kritik Stok (15)
      urun.stok.toString(), // Anlık Stok
      urun.kdvOrani.toString(), // KDV ("18" olarak aranabilsin)
      urun.aktifMi ? 'aktif' : 'pasif', // Durum ("Aktif" olarak aranabilsin)
      createdBy ?? currentUser, // Oluşturan kişi
      ...urun.cihazlar.map((e) => e.identityValue), // Device IDs (IMEI/Serial)
    ].where((e) => e.toString().trim().isNotEmpty).join(' ').toLowerCase();

    map['search_tags'] = searchTags;

    await _pool!.execute(
      Sql.named('''
        INSERT INTO products (
          kod, ad, birim, alis_fiyati, satis_fiyati_1, satis_fiyati_2, satis_fiyati_3,
          kdv_orani, stok, erken_uyari_miktari, grubu, ozellikler, barkod, kullanici,
          resim_url, resimler, aktif_mi, created_by, created_at, search_tags
        )
        VALUES (
          @kod, @ad, @birim, @alis_fiyati, @satis_fiyati_1, @satis_fiyati_2, @satis_fiyati_3,
          @kdv_orani, @stok, @erken_uyari_miktari, @grubu, @ozellikler, @barkod, @kullanici,
          @resim_url, @resimler, @aktif_mi, @created_by, @created_at, @search_tags
        )
      '''),
      parameters: map,
    );

    // Açılış Stoğu İşlemi
    if (urun.stok > 0 && initialStockWarehouseId != null) {
      try {
        // 1. Sevkiyat Kaydı (UpdateStock: false, çünkü products.stok zaten INSERT ile set edildi)
        await DepolarVeritabaniServisi().sevkiyatEkle(
          sourceId: null, // Opening Stock
          destId: initialStockWarehouseId,
          date: DateTime.now(),
          description: '',
          items: [
            ShipmentItem(
              code: urun.kod,
              name: urun.ad,
              unit: urun.birim,
              quantity: urun.stok,
              unitCost: initialStockUnitCost,
              devices: urun.cihazlar.map((e) => e.toMap()).toList(),
            ),
          ],
          updateStock: false,
          createdBy: currentUser,
          integrationRef: 'opening_stock',
        );

        // 2. Depo Stoğu (Manuel Güncelleme - çünkü sevkiyatEkle'de updateStock false yaptık)
        await _pool!.execute(
          Sql.named('''
            INSERT INTO warehouse_stocks (warehouse_id, product_code, quantity)
            VALUES (@wid, @code, @qty)
            ON CONFLICT (warehouse_id, product_code) 
            DO UPDATE SET quantity = warehouse_stocks.quantity + EXCLUDED.quantity
            '''),
          parameters: {
            'wid': initialStockWarehouseId,
            'code': urun.kod,
            'qty': urun.stok,
          },
        );
      } catch (e) {
        debugPrint('Açılış stoğu oluşturulurken hata: $e');
      }
    }

    // 3. Cihaz Kayıtları
    if (urun.cihazlar.isNotEmpty) {
      try {
        // En son eklenen ürünün ID'sini al
        final idResult = await _pool!.execute(
          Sql.named('SELECT id FROM products WHERE kod = @kod LIMIT 1'),
          parameters: {'kod': urun.kod},
        );
        if (idResult.isNotEmpty) {
          final productId = idResult.first[0] as int;
          for (final cihaz in urun.cihazlar) {
            final cihazMap = cihaz.toMap();
            cihazMap['product_id'] = productId;
            cihazMap.remove('id');
            await _pool!.execute(
              Sql.named('''
                INSERT INTO product_devices (
                  product_id, identity_type, identity_value, condition, color, capacity,
                  warranty_end_date, has_box, has_invoice, has_original_charger,
                  is_sold, sale_ref
                ) VALUES (
                  @product_id, @identity_type, @identity_value, @condition, @color, @capacity,
                  CAST(@warranty_end_date AS TIMESTAMP), @has_box, @has_invoice, @has_original_charger,
                  @is_sold, @sale_ref
                )
              '''),
              parameters: cihazMap,
            );
          }
        }
      } catch (e) {
        debugPrint('Cihazlar kaydedilirken hata: $e');
      }
    }
  }

  Future<void> urunGuncelle(UrunModel urun) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final map = urun.toMap();
    map.remove('created_by');
    map.remove('created_at');
    map.remove('cihazlar');
    map['resimler'] = jsonEncode(urun.resimler);

    // Search Tags Güncelleme (Full Spectrum)
    final searchTags = [
      urun.kod,
      urun.ad,
      urun.barkod,
      urun.grubu,
      urun.kullanici,
      urun.ozellikler,
      urun.birim,
      urun.id.toString(),
      urun.alisFiyati.toString(),
      urun.satisFiyati1.toString(),
      urun.satisFiyati2.toString(),
      urun.satisFiyati3.toString(),
      urun.erkenUyariMiktari.toString(),
      urun.stok.toString(),
      urun.kdvOrani.toString(), // KDV
      urun.aktifMi ? 'aktif' : 'pasif', // Durum
      ...urun.cihazlar.map((e) => e.identityValue), // Device IDs (IMEI/Serial)
    ].where((e) => e.toString().trim().isNotEmpty).join(' ').toLowerCase();

    map['search_tags'] = searchTags;

    await _pool!.execute(
      Sql.named('''
        UPDATE products SET 
        kod=@kod, ad=@ad, birim=@birim, alis_fiyati=@alis_fiyati, 
        satis_fiyati_1=@satis_fiyati_1, satis_fiyati_2=@satis_fiyati_2, satis_fiyati_3=@satis_fiyati_3,
        kdv_orani=@kdv_orani, stok=@stok, erken_uyari_miktari=@erken_uyari_miktari,
        grubu=@grubu, ozellikler=@ozellikler, barkod=@barkod, kullanici=@kullanici,
        resim_url=@resim_url, resimler=@resimler, aktif_mi=@aktif_mi, search_tags=@search_tags
        WHERE id=@id
      '''),
      parameters: map,
    );

    // Cihazları güncelle: Eski cihazları sil ve yenilerini ekle (Basit yaklaşım)
    try {
      await _pool!.execute(
        Sql.named('DELETE FROM product_devices WHERE product_id = @id'),
        parameters: {'id': urun.id},
      );
      for (final cihaz in urun.cihazlar) {
        final cihazMap = cihaz.toMap();
        cihazMap['product_id'] = urun.id;
        cihazMap.remove('id');
        await _pool!.execute(
          Sql.named('''
            INSERT INTO product_devices (
              product_id, identity_type, identity_value, condition, color, capacity,
              warranty_end_date, has_box, has_invoice, has_original_charger,
              is_sold, sale_ref
            ) VALUES (
              @product_id, @identity_type, @identity_value, @condition, @color, @capacity,
              CAST(@warranty_end_date AS TIMESTAMP), @has_box, @has_invoice, @has_original_charger,
              @is_sold, @sale_ref
            )
          '''),
          parameters: cihazMap,
        );
      }
    } catch (e) {
      debugPrint('Cihazlar güncellenirken hata: $e');
    }
  }

  Future<void> urunSil(int id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // [INTEGRITY CHECK] Stok Hareketi Varsa Silmeyi Engelle ("Hayalet Borç" Önleme)
    // Askeri Düzen: Hareketi olan kart silinemez. Pasife alınır.
    final hareketVarMi = await _pool!.execute(
      Sql.named('SELECT 1 FROM stock_movements WHERE product_id = @id LIMIT 1'),
      parameters: {'id': id},
    );

    if (hareketVarMi.isNotEmpty) {
      throw Exception(
        'Bu ürünle ilişkili stok hareketleri (Alış/Satış/İade) bulunmaktadır. '
        'Veri bütünlüğü için bu ürün silinemez! Lütfen ürünü "Pasif" duruma getiriniz.\\n\\n'
        '(İpucu: Eğer bu bir hatalı giriş ise, önce faturayı silmeyi deneyiniz.)',
      );
    }

    await _pool!.runTx((ctx) async {
      // 1. Ürün Kodunu Al (İlişkili tablolar kod kullanıyorsa gereklidir)
      final codeRes = await ctx.execute(
        Sql.named('SELECT kod FROM products WHERE id = @id'),
        parameters: {'id': id},
      );

      String? productCode;
      if (codeRes.isNotEmpty) {
        productCode = codeRes[0][0] as String;
      }

      // 2. Stok Hareketlerini Sil (product_id bazlı)
      // Zaten yukarıdaki check geçtiyse hareket yoktur, ama yine de güvenli temizlik.
      await ctx.execute(
        Sql.named('DELETE FROM stock_movements WHERE product_id = @id'),
        parameters: {'id': id},
      );

      if (productCode != null) {
        // 3. Depo Stoklarını Sil (product_code bazlı)
        await ctx.execute(
          Sql.named('DELETE FROM warehouse_stocks WHERE product_code = @code'),
          parameters: {'code': productCode},
        );

        // 4. Reçetelerden Sil (Bu ürünün hammadde olduğu reçeteler)
        await ctx.execute(
          Sql.named(
            'DELETE FROM production_recipe_items WHERE product_code = @code',
          ),
          parameters: {'code': productCode},
        );
      }

      // 5. Ürünü Sil
      await ctx.execute(
        Sql.named('DELETE FROM products WHERE id = @id'),
        parameters: {'id': id},
      );
    });
  }

  Future<void> topluUrunSil(List<int> ids) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;
    if (ids.isEmpty) return;

    await _pool!.execute(
      Sql.named('DELETE FROM products WHERE id = ANY(@idArray)'),
      parameters: {'idArray': ids},
    );
  }

  /// Toplu Fiyat Güncelleme (1 Milyar Kayıt Optimizasyonu)
  ///
  /// Batch processing ile parçalı güncelleme yapar.
  /// Ana thread'i bloklamaz, arka planda çalışır.
  Future<void> topluFiyatGuncelle({
    required String fiyatTipi,
    required String islem,
    required double oran,
    Function(int tamamlanan, int toplam)? ilerlemeCallback,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    String column = 'satis_fiyati_1';
    if (fiyatTipi == 'satis_2') column = 'satis_fiyati_2';
    if (fiyatTipi == 'satis_3') column = 'satis_fiyati_3';
    if (fiyatTipi == 'alis') column = 'alis_fiyati';

    final String updateOperator = islem == 'artir' ? '+' : '-';
    final int batchSize = _yapilandirma.batchSize;

    // 1. Toplam kayıt sayısını al (pg_class estimate ile hızlı)
    int toplamKayit = 0;
    try {
      final estimateResult = await _pool!.execute(
        "SELECT reltuples::bigint AS estimate FROM pg_class WHERE relname = 'products'",
      );
      if (estimateResult.isNotEmpty && estimateResult[0][0] != null) {
        toplamKayit = (estimateResult[0][0] as int);
      }
    } catch (_) {
      // Fallback: Count (Sadece estimate başarısızsa)
      final countResult = await _pool!.execute('SELECT COUNT(*) FROM products');
      toplamKayit = countResult[0][0] as int;
    }

    if (toplamKayit == 0) return;

    // 2. Küçük veri setlerinde tek seferde güncelle
    if (toplamKayit <= batchSize) {
      await _pool!.execute(
        Sql.named(
          'UPDATE products SET $column = $column $updateOperator ($column * @oran / 100)',
        ),
        parameters: {'oran': oran},
      );
      ilerlemeCallback?.call(toplamKayit, toplamKayit);
      debugPrint('✅ Toplu fiyat güncelleme tamamlandı: $toplamKayit kayıt');
      return;
    }

    // 3. Batch güncelleme döngüsü (Büyük veri setleri, keyset pagination)
    int islenenKayit = 0;
    int? lastId;

    while (islenenKayit < toplamKayit) {
      // ID tabanlı keyset pagination: son id'den sonrasını al
      final Sql sql = lastId == null
          ? Sql.named('''
              UPDATE products 
              SET $column = $column $updateOperator ($column * @oran / 100)
              WHERE id IN (
                SELECT id FROM products 
                ORDER BY id 
                LIMIT @batchSize
              )
              RETURNING id
            ''')
          : Sql.named('''
              UPDATE products 
              SET $column = $column $updateOperator ($column * @oran / 100)
              WHERE id IN (
                SELECT id FROM products 
                WHERE id > @lastId
                ORDER BY id 
                LIMIT @batchSize
              )
              RETURNING id
            ''');

      final result = await _pool!.execute(
        sql,
        parameters: {
          'oran': oran,
          'batchSize': batchSize,
          ...?(lastId == null ? null : <String, dynamic>{'lastId': lastId}),
        },
      );

      if (result.isEmpty) {
        break;
      }

      // Son işlenen id'yi güncelle
      lastId = (result.last[0] as int);
      islenenKayit += result.length;

      // İlerleme callback'i çağır (UI güncellemesi için)
      ilerlemeCallback?.call(islenenKayit.clamp(0, toplamKayit), toplamKayit);

      // Ana thread'i rahatlatmak için kısa bekleme
      await Future.delayed(const Duration(milliseconds: 10));
    }

    debugPrint('✅ Toplu fiyat güncelleme tamamlandı: $toplamKayit kayıt');
  }

  /// Toplu KDV Oranı Güncelleme (1 Milyar Kayıt Optimizasyonu)
  ///
  /// Batch processing ile parçalı güncelleme yapar.
  Future<void> topluKdvGuncelle({
    required double eskiKdv,
    required double yeniKdv,
    Function(int tamamlanan, int toplam)? ilerlemeCallback,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final int batchSize = _yapilandirma.batchSize;

    // 1. Etkilenecek kayıt sayısını al
    // Öncelik: product_metadata üzerinden O(1) okuma
    int toplamKayit = 0;
    try {
      final metaResult = await _pool!.execute(
        Sql.named(
          "SELECT frequency FROM product_metadata WHERE type = 'vat' AND value = @vat",
        ),
        parameters: {'vat': eskiKdv.toString()},
      );
      if (metaResult.isNotEmpty && metaResult.first[0] != null) {
        toplamKayit = metaResult.first[0] as int;
      }
    } catch (_) {
      // Metadata eksik / uyumsuz olabilir, aşağıdaki COUNT(*) yedeği çalışacak.
    }

    // Metadata'da kayıt yoksa klasik COUNT(*) ile devam et
    if (toplamKayit == 0) {
      final countResult = await _pool!.execute(
        Sql.named('SELECT COUNT(*) FROM products WHERE kdv_orani = @eskiKdv'),
        parameters: {'eskiKdv': eskiKdv},
      );
      toplamKayit = countResult[0][0] as int;
    }

    if (toplamKayit == 0) {
      debugPrint('Güncellenecek kayıt bulunamadı (KDV: $eskiKdv)');
      return;
    }

    // 2. Küçük veri setlerinde tek seferde güncelle
    if (toplamKayit <= batchSize) {
      await _pool!.execute(
        Sql.named(
          'UPDATE products SET kdv_orani = @yeniKdv WHERE kdv_orani = @eskiKdv',
        ),
        parameters: {'eskiKdv': eskiKdv, 'yeniKdv': yeniKdv},
      );
      ilerlemeCallback?.call(toplamKayit, toplamKayit);
      debugPrint('✅ Toplu KDV güncelleme tamamlandı: $toplamKayit kayıt');
      return;
    }

    // 3. Büyük veri setlerinde batch işlemi (keyset pagination)
    int islenenKayit = 0;
    int? lastId;

    while (islenenKayit < toplamKayit) {
      final Sql sql = lastId == null
          ? Sql.named('''
              UPDATE products 
              SET kdv_orani = @yeniKdv 
              WHERE id IN (
                SELECT id FROM products 
                WHERE kdv_orani = @eskiKdv 
                ORDER BY id 
                LIMIT @batchSize
              )
              RETURNING id
            ''')
          : Sql.named('''
              UPDATE products 
              SET kdv_orani = @yeniKdv 
              WHERE id IN (
                SELECT id FROM products 
                WHERE kdv_orani = @eskiKdv 
                  AND id > @lastId
                ORDER BY id 
                LIMIT @batchSize
              )
              RETURNING id
            ''');

      final result = await _pool!.execute(
        sql,
        parameters: {
          'eskiKdv': eskiKdv,
          'yeniKdv': yeniKdv,
          'batchSize': batchSize,
          ...?(lastId == null ? null : <String, dynamic>{'lastId': lastId}),
        },
      );

      if (result.isEmpty) {
        break;
      }

      lastId = (result.last[0] as int);
      islenenKayit += result.length;
      ilerlemeCallback?.call(islenenKayit.clamp(0, toplamKayit), toplamKayit);

      // Ana thread'i rahatlatmak için kısa bekleme
      await Future.delayed(const Duration(milliseconds: 10));
    }

    // 🔄 METADATA GÜNCELLEME - Dropdown listesinin güncel kalması için
    // Eski KDV oranını listeden kaldır veya frequency'yi azalt
    // Yeni KDV oranını listeye ekle veya frequency'yi artır
    try {
      await _pool!.runTx((ctx) async {
        // 1. Eski KDV'nin frequency'sini güncelle (silme veya azaltma)
        await ctx.execute(
          Sql.named('''
            UPDATE product_metadata 
            SET frequency = GREATEST(0, frequency - @count)
            WHERE type = 'vat' AND value = @oldVat
          '''),
          parameters: {'oldVat': eskiKdv.toString(), 'count': toplamKayit},
        );

        // Frequency 0 ise sil
        await ctx.execute(
          Sql.named('''
            DELETE FROM product_metadata 
            WHERE type = 'vat' AND value = @oldVat AND frequency <= 0
          '''),
          parameters: {'oldVat': eskiKdv.toString()},
        );

        // 2. Yeni KDV'yi ekle veya frequency'yi artır
        await ctx.execute(
          Sql.named('''
            INSERT INTO product_metadata (type, value, frequency)
            VALUES ('vat', @newVat, @count)
            ON CONFLICT (type, value) 
            DO UPDATE SET frequency = product_metadata.frequency + EXCLUDED.frequency
          '''),
          parameters: {'newVat': yeniKdv.toString(), 'count': toplamKayit},
        );
      });
    } catch (e) {
      debugPrint('Metadata güncellenirken hata (KDV dropdown): $e');
    }

    debugPrint('✅ Toplu KDV güncelleme tamamlandı: $toplamKayit kayıt');
  }

  Future<String?> sonUrunKoduGetir() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    // 1. Önce Sequence tablosuna bak (Hızlı - O(1))
    final seqResult = await _pool!.execute(
      "SELECT current_value FROM sequences WHERE name = 'product_code'",
    );

    if (seqResult.isNotEmpty) {
      return seqResult[0][0].toString();
    }

    // 2. Eğer Sequence yoksa (İlk kurulum), HEM Ürünler HEM Üretimler tablosuna bak
    int maxCode = 0;

    // Products table check
    final prodResult = await _pool!.execute(
      "SELECT MAX((substring(trim(kod) from '([0-9]+)\$'))::BIGINT) FROM products WHERE trim(kod) ~ '[0-9]+\$'",
    );
    if (prodResult.isNotEmpty && prodResult[0][0] != null) {
      final pc = int.tryParse(prodResult[0][0].toString());
      if (pc != null && pc > maxCode) maxCode = pc;
    }

    // Productions table check (Üretimler de aynı havuzdan kod alıyorsa)
    try {
      final uretimResult = await _pool!.execute(
        "SELECT MAX((substring(trim(kod) from '([0-9]+)\$'))::BIGINT) FROM productions WHERE trim(kod) ~ '[0-9]+\$'",
      );
      if (uretimResult.isNotEmpty && uretimResult[0][0] != null) {
        final uc = int.tryParse(uretimResult[0][0].toString());
        if (uc != null && uc > maxCode) maxCode = uc;
      }
    } catch (e) {
      // productions tablosu henüz oluşturulmamışsa (42P01), sadece products kontrolü yeterli
      debugPrint('Productions kod kontrolü atlandı: $e');
    }

    // Sequence'i başlat / güncelle (yarış durumlarını önlemek için ON CONFLICT)
    await _pool!.execute(
      Sql.named(
        "INSERT INTO sequences (name, current_value) VALUES ('product_code', @val) "
        "ON CONFLICT (name) DO UPDATE "
        "SET current_value = GREATEST(sequences.current_value, @val)",
      ),
      parameters: {'val': maxCode},
    );

    return maxCode.toString();
  }

  Future<String?> sonBarkodGetir() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    // 1. Sequence Kontrolü
    final seqResult = await _pool!.execute(
      "SELECT current_value FROM sequences WHERE name = 'barcode'",
    );

    if (seqResult.isNotEmpty) {
      return seqResult[0][0].toString();
    }

    // 2. Fallback (Init) - Sort yerine MAX kullan (online DB'de çok daha hızlı)
    final result = await _pool!.execute(
      "SELECT MAX((substring(trim(barkod) from '([0-9]+)\$'))::BIGINT) FROM products WHERE trim(barkod) ~ '[0-9]+\$'",
    );

    final maxBarcode =
        (result.isNotEmpty && result[0][0] != null)
        ? (int.tryParse(result[0][0].toString()) ?? 0)
        : 0;

    // Sequence'i başlat / güncelle (yarış durumlarını önlemek için ON CONFLICT)
    await _pool!.execute(
      Sql.named(
        "INSERT INTO sequences (name, current_value) VALUES ('barcode', @val) "
        "ON CONFLICT (name) DO UPDATE "
        "SET current_value = GREATEST(sequences.current_value, @val)",
      ),
      parameters: {'val': maxBarcode},
    );

    return maxBarcode.toString();
  }

  Future<Map<String, double>> acilisStoguDetayGetir(
    int transactionId,
    String urunKod,
  ) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) throw Exception('Veritabanı bağlantısı yok');

    final result = await _pool!.execute(
      Sql.named('SELECT items FROM shipments WHERE id = @id'),
      parameters: {'id': transactionId},
    );

    if (result.isEmpty) throw Exception('Kayıt bulunamadı');

    final itemsJson = result[0][0];
    List<dynamic> items;
    if (itemsJson is String) {
      items = jsonDecode(itemsJson);
    } else {
      items = itemsJson as List<dynamic>;
    }

    for (var item in items) {
      if (item['code'] == urunKod) {
        return {
          'quantity':
              double.tryParse(item['quantity']?.toString() ?? '') ?? 0.0,
          'unit_cost':
              double.tryParse(
                (item['unitCost'] ?? item['unit_cost'])?.toString() ?? '',
              ) ??
              0.0,
        };
      }
    }
    throw Exception('Ürün bu kayıtta bulunamadı');
  }

  Future<void> acilisStoguGuncelle({
    required int transactionId,
    required int urunId,
    required String urunKod,
    required double oldQuantity,
    required double newQuantity,
    required double newCost,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // 1. Shipment Update
    // JSON dizisi içinde "code" eşleşen item'ı bulup güncelliyoruz.
    // Logic: JSONB - Önce oku, sonra güncelle.

    final shipRes = await _pool!.execute(
      Sql.named(
        'SELECT dest_warehouse_id, items FROM shipments WHERE id = @id',
      ),
      parameters: {'id': transactionId},
    );

    if (shipRes.isEmpty) throw Exception('Sevkiyat bulunamadı');

    final warehouseId = shipRes[0][0] as int;
    final currentItems = shipRes[0][1] as dynamic;

    List<dynamic> itemsList;
    if (currentItems is String) {
      itemsList = jsonDecode(currentItems);
    } else {
      itemsList = currentItems;
    }

    bool found = false;
    for (var item in itemsList) {
      if (item['code'] == urunKod) {
        item['quantity'] = newQuantity;
        item['unitCost'] = newCost;
        item['unit_cost'] = newCost;
        found = true;
        break;
      }
    }

    if (!found) throw Exception('Ürün sevkiyat içinde bulunamadı');

    await _pool!.execute(
      Sql.named('UPDATE shipments SET items = @items WHERE id = @id'),
      parameters: {'items': jsonEncode(itemsList), 'id': transactionId},
    );

    // 2. Warehouse Stock Update (Fark kadar)
    final diff = newQuantity - oldQuantity;
    if (diff != 0) {
      await _pool!.execute(
        Sql.named('''
            INSERT INTO warehouse_stocks (warehouse_id, product_code, quantity)
            VALUES (@wid, @code, @qty)
            ON CONFLICT (warehouse_id, product_code) 
            DO UPDATE SET quantity = warehouse_stocks.quantity + @diff
          '''),
        parameters: {
          'wid': warehouseId,
          'code': urunKod,
          'qty': newQuantity,
          'diff': diff,
        },
      );
    }

    // 3. Product Total Stock Update (Fark kadar)
    if (diff != 0) {
      await _pool!.execute(
        Sql.named('UPDATE products SET stok = stok + @diff WHERE id = @uid'),
        parameters: {'diff': diff, 'uid': urunId},
      );
    }
  }

  // --- STOK İŞLEMLERİ (Entegrasyon) ---

  Future<void> stokIslemiYap({
    required int urunId,
    required String urunKodu,
    required double miktar,
    required bool isGiris, // true: Stok Artar, false: Stok Azalır
    required String islemTuru, // 'Alış', 'Satış', 'İade'
    required DateTime tarih,
    String? aciklama,
    String? kullanici,
    double? birimFiyat,
    String? paraBirimi,
    double? kur,
    int? depoId, // Opsiyonel
    int? shipmentId, // Opsiyonel (Shipments entegrasyonu)
    String? entegrasyonRef,
    String? serialNumber, // Seçili cihazın seri nosu/IMEI'si
    TxSession? session,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final executor = session ?? _pool!;

    // Negatif miktar kontrolü
    // final double islemMiktari = isGiris ? miktar : -miktar; // Bu artık recalculateAverageCosts içinde yönetilecek

    // [VALIDATION] Eksi Stok Kontrolü - Satış işlemlerinde stok kontrolü
    // Genel ayarlardaki eksiStokSatis ayarına göre kontrol yap
    if (!isGiris) {
      try {
        final genelAyarlar = await AyarlarVeritabaniServisi()
            .genelAyarlariGetir();
        // eksiStokSatis = true ise eksi stoğa izin var, false ise kontrol yap
        if (!genelAyarlar.eksiStokSatis) {
          // Mevcut stoku kontrol et - KİLİTLE (FOR UPDATE)
          final stokResult = await executor.execute(
            Sql.named('SELECT stok FROM products WHERE id = @id FOR UPDATE'),
            parameters: {'id': urunId},
          );
          if (stokResult.isNotEmpty) {
            final mevcutStok =
                double.tryParse(stokResult.first[0]?.toString() ?? '') ?? 0.0;
            if (mevcutStok < miktar) {
              throw Exception(
                'Yetersiz stok! Mevcut stok: $mevcutStok, İstenen miktar: $miktar. '
                'Eksi stok satışı genel ayarlardan kapalı.',
              );
            }
          }
        }
      } catch (e) {
        // Ayarlar okunamazsa Exception'ı yeniden fırlat (stok hatası ise)
        if (e.toString().contains('Yetersiz stok')) {
          rethrow;
        }
        // Diğer hatalar için loglama yapıp devam et
        debugPrint('Genel ayarlar okunamadı, eksi stok kontrolü atlanıyor: $e');
      }
    }

    try {
      final double fiyat = birimFiyat ?? 0.0;
      final double dovizKuru = kur ?? 1.0;

      // 1. Stok Hareket Kaydı
      await executor.execute(
        Sql.named('''
          INSERT INTO stock_movements
          (product_id, warehouse_id, shipment_id, quantity, is_giris, unit_price, currency_code, currency_rate, movement_date, movement_type, description, created_by, integration_ref)
          VALUES
          (@urunId, @depoId, @shipmentId, @miktar, @isGiris, @fiyat, @paraBirimi, @kur, @tarih, @islemTuru, @aciklama, @kullanici, @ref)
        '''),
        parameters: {
          'urunId': urunId,
          'depoId': depoId,
          'shipmentId': shipmentId,
          'miktar': miktar,
          'isGiris': isGiris,
          'fiyat': fiyat,
          'paraBirimi': paraBirimi ?? 'TRY', // Varsayılan değer
          'kur': dovizKuru,
          'tarih': tarih.toIso8601String(),
          'islemTuru': islemTuru,
          'aciklama': aciklama,
          'kullanici': kullanici,
          'ref': entegrasyonRef,
        },
      );

      // 2. [BUTTERFLY EFFECT PREVENTION] Hareketi ekledikten sonra tüm maliyetleri kronolojik düzelt
      // Bu sayede araya (geçmişe) eklenen hareketler de doğru maliyeti hesaplar.
      await recalculateAverageCosts(urunId, session: session);

      // 3. Depo Stoğu Güncellemesi (Eğer depo seçiliyse)
      if (depoId != null) {
        final double islemMiktariDepo = isGiris ? miktar : -miktar;
        await executor.execute(
          Sql.named('''
            INSERT INTO warehouse_stocks (warehouse_id, product_code, quantity)
            VALUES (@depoId, @kod, @miktar)
            ON CONFLICT (warehouse_id, product_code) 
            DO UPDATE SET quantity = warehouse_stocks.quantity + EXCLUDED.quantity, updated_at = CURRENT_TIMESTAMP
          '''),
          parameters: {
            'depoId': depoId,
            'kod': urunKodu,
            'miktar': islemMiktariDepo,
          },
        );
      }

      // 4. Cihaz Durumu / Kayıt Güncellemesi (IMEI/Seri No takipli ürünler)
      final String cleanedSerial = (serialNumber ?? '').toString().trim();
      if (cleanedSerial.isNotEmpty) {
        if (isGiris) {
          // Alış / giriş işlemlerinde cihaz stokta olmalı (yoksa oluştur, varsa geri stokta yap)
          final existing = await executor.execute(
            Sql.named('''
              SELECT id 
              FROM product_devices 
              WHERE product_id = @urunId AND identity_value = @serial
              ORDER BY id DESC
              LIMIT 1
            '''),
            parameters: {'urunId': urunId, 'serial': cleanedSerial},
          );

          if (existing.isEmpty) {
            final bool looksLikeImei = RegExp(
              r'^[0-9]{14,16}$',
            ).hasMatch(cleanedSerial);
            await executor.execute(
              Sql.named('''
                INSERT INTO product_devices (
                  product_id, identity_type, identity_value, condition,
                  color, capacity, warranty_end_date,
                  has_box, has_invoice, has_original_charger,
                  is_sold, sale_ref, created_at, updated_at
                ) VALUES (
                  @urunId, @identityType, @serial, @condition,
                  NULL, NULL, NULL,
                  0, 0, 0,
                  0, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                )
              '''),
              parameters: {
                'urunId': urunId,
                'identityType': looksLikeImei ? 'IMEI' : 'Seri No',
                'serial': cleanedSerial,
                'condition': 'Sıfır',
              },
            );
          } else {
            final id = existing.first[0] as int;
            await executor.execute(
              Sql.named('''
                UPDATE product_devices
                SET is_sold = 0, sale_ref = NULL, updated_at = CURRENT_TIMESTAMP
                WHERE id = @id
              '''),
              parameters: {'id': id},
            );
          }
        } else {
          // Satış / çıkış işlemlerinde cihaz satıldı olarak işaretlenir
          await executor.execute(
            Sql.named('''
              UPDATE product_devices 
              SET is_sold = 1, sale_ref = @ref, updated_at = CURRENT_TIMESTAMP
              WHERE identity_value = @serial AND product_id = @urunId
            '''),
            parameters: {
              'serial': cleanedSerial,
              'ref': entegrasyonRef,
              'urunId': urunId,
            },
          );
        }
      }
    } catch (e) {
      debugPrint('Stok işlemi hatası: $e');
      rethrow;
    }
  }

  /// [FINANCE ENGINE 2025] Hareketli Ortalama Maliyeti Yeniden Hesapla
  /// Geçmişe dönük silme veya düzenlemelerde stok ve maliyet dengesini otomatik düzeltir.
  Future<void> recalculateAverageCosts(int urunId, {TxSession? session}) async {
    final executor = session ?? _pool!;

    // 1. Tüm hareketleri kronolojik sırayla çek
    final movements = await executor.execute(
      Sql.named('''
        SELECT id, quantity, is_giris, unit_price, currency_rate 
        FROM stock_movements 
        WHERE product_id = @urunId 
        ORDER BY movement_date ASC, id ASC
      '''),
      parameters: {'urunId': urunId},
    );

    double safeDouble(dynamic value, {double fallback = 0.0}) {
      if (value == null) return fallback;
      if (value is num) return value.toDouble();
      final parsed =
          double.tryParse(value.toString().replaceAll(',', '.')) ?? fallback;
      return parsed;
    }

    double currentStock = 0.0;
    double currentTotalValue = 0.0; // Toplam Envanter Değieri (Yerel Para)
    double currentAvgCost = 0.0;

    for (var row in movements) {
      final int moveId = row[0] as int;
      final double qty = safeDouble(row[1]);
      final bool isGiris = row[2] as bool;
      final double unitPrice = safeDouble(row[3]);
      final double rate = safeDouble(row[4], fallback: 1.0);
      final double localPrice = unitPrice * rate;

      if (isGiris) {
        // GİRİŞ: Maliyet ortalamaya dahil edilir
        currentTotalValue += (qty * localPrice);
        currentStock += qty;
        if (currentStock > 0) {
          currentAvgCost = currentTotalValue / currentStock;
        }
      } else {
        // ÇIKIŞ: Stok düşer, değer mevcut ortalama üzerinden azalır
        currentStock -= qty;
        currentTotalValue = currentStock * currentAvgCost;
        if (currentStock <= 0) {
          currentTotalValue = 0;
          if (currentStock < 0) currentAvgCost = currentAvgCost;
        }
      }

      // Hareket kaydını yeni stok ve maliyetle güncelle
      await executor.execute(
        Sql.named('''
          UPDATE stock_movements 
          SET running_stock = @stok, running_cost = @cost 
          WHERE id = @id
        '''),
        parameters: {
          'id': moveId,
          'stok': currentStock,
          'cost': currentAvgCost,
        },
      );
    }

    // 2. Ürün kartını en son hesaplanan değerlerle güncelle
    await executor.execute(
      Sql.named('''
        UPDATE products 
        SET stok = @stok, alis_fiyati = @cost, updated_at = CURRENT_TIMESTAMP 
        WHERE id = @urunId
      '''),
      parameters: {
        'urunId': urunId,
        'stok': currentStock,
        'cost': currentAvgCost,
      },
    );
  }

  Future<UrunModel?> urunGetirKodVeyaBarkod(String query) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    final q = query.trim();
    if (q.isEmpty) return null;

    final result = await _pool!.execute(
      Sql.named(
        'SELECT * FROM products WHERE aktif_mi = 1 AND (kod = @q OR barkod = @q) LIMIT 1',
      ),
      parameters: {'q': q},
    );

    if (result.isEmpty) return null;
    return UrunModel.fromMap(result.first.toColumnMap());
  }

  Future<List<CihazModel>> cihazlariGetir(int productId) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    final result = await _pool!.execute(
      Sql.named(
        'SELECT * FROM product_devices WHERE product_id = @id AND is_sold = 0',
      ),
      parameters: {'id': productId},
    );

    return result.map((row) => CihazModel.fromMap(row.toColumnMap())).toList();
  }

  /// [2026] Ürün Kartı "Seri/IMEI Liste" için:
  /// - Cursor (keyset) pagination: id > lastId
  /// - Backend arama: product_devices.search_tags (GIN trgm) + normalize_text uyumlu input
  /// - Tarih filtresi: last_tx_at üzerinde
  Future<List<Map<String, dynamic>>> urunCihazlariniSayfalaGetir({
    required int productId,
    int limit = 25,
    int? lastId,
    bool includeSold = false,
    String? aramaTerimi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    Session? session,
  }) async {
    if (session == null) {
      if (!_isInitialized) await baslat();
      if (_pool == null) return [];
    }

    final executor = session ?? _pool!;
    final int safeLimit = limit.clamp(1, 1000);

    String normalizeTurkish(String text) {
      if (text.isEmpty) return '';
      return text
          .toLowerCase()
          .replaceAll('ç', 'c')
          .replaceAll('ğ', 'g')
          .replaceAll('ı', 'i')
          .replaceAll('ö', 'o')
          .replaceAll('ş', 's')
          .replaceAll('ü', 'u')
          .replaceAll('i̇', 'i');
    }

    final conds = <String>['pd.product_id = @pid'];
    final params = <String, dynamic>{'pid': productId, 'limit': safeLimit};

    if (!includeSold) {
      conds.add('COALESCE(pd.is_sold, 0) = 0');
    }

    if (lastId != null && lastId > 0) {
      conds.add('pd.id > @lastId');
      params['lastId'] = lastId;
    }

    final trimmedSearch = (aramaTerimi ?? '').trim();
    if (trimmedSearch.isNotEmpty) {
      conds.add(
        "(pd.search_tags LIKE @search OR to_tsvector('simple', pd.search_tags) @@ plainto_tsquery('simple', @fts))",
      );
      params['search'] = '%${normalizeTurkish(trimmedSearch)}%';
      params['fts'] = normalizeTurkish(trimmedSearch);
    }

    if (baslangicTarihi != null || bitisTarihi != null) {
      conds.add('pd.last_tx_at IS NOT NULL');
      if (baslangicTarihi != null) {
        conds.add('pd.last_tx_at >= @startDate');
        params['startDate'] = DateTime(
          baslangicTarihi.year,
          baslangicTarihi.month,
          baslangicTarihi.day,
        ).toIso8601String();
      }
      if (bitisTarihi != null) {
        // inclusive end-of-day
        final e = DateTime(bitisTarihi.year, bitisTarihi.month, bitisTarihi.day)
            .add(const Duration(days: 1));
        conds.add('pd.last_tx_at < @endDate');
        params['endDate'] = e.toIso8601String();
      }
    }

    final where = conds.isEmpty ? '' : 'WHERE ${conds.join(' AND ')}';
    final res = await executor.execute(
      Sql.named('''
        SELECT
          pd.id,
          pd.identity_type,
          pd.identity_value,
          pd.is_sold,
          pd.sale_ref,
          pd.last_tx_at,
          pd.last_tx_type,
          pd.last_tx_shipment_id
        FROM product_devices pd
        $where
        ORDER BY pd.id ASC
        LIMIT @limit
      '''),
      parameters: params,
    );

    return res.map((r) => r.toColumnMap()).toList(growable: false);
  }

  /// Ürünün stokta (is_sold=0) cihazı var mı? (Seri liste modunda sold fallback kararı için)
  Future<bool> urunStoktaCihazVarMi(int productId, {Session? session}) async {
    if (session == null) {
      if (!_isInitialized) await baslat();
      if (_pool == null) return false;
    }
    final executor = session ?? _pool!;
    final res = await executor.execute(
      Sql.named(
        'SELECT 1 FROM product_devices WHERE product_id = @pid AND COALESCE(is_sold, 0) = 0 LIMIT 1',
      ),
      parameters: {'pid': productId},
    );
    return res.isNotEmpty;
  }

  /// [2026] Seri/IMEI listesinde arama + filtreler tam kapsama olsun diye:
  /// geçmiş sevkiyatları tarayıp product_devices.last_tx_* kolonlarını best-effort doldurur.
  ///
  /// Not: Cursor ile shipment'leri geriye doğru tarar; cihaz başına ilk gördüğü shipment en güncel olduğu için
  /// sadece `last_tx_at IS NULL` olan cihazları günceller (çok daha hızlı).
  Future<void> urunCihazSonIslemleriniBackfillEt({
    required int productId,
    required String urunKodu,
    required double kdvOrani,
    int shipmentPageSize = 1000,
    int maxPages = 5000,
    Duration throttle = const Duration(milliseconds: 5),
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // last_tx kolonu olmayan eski şemalarda sessizce çık.
    try {
      final test = await _pool!.execute(
        Sql.named(
          'SELECT 1 FROM information_schema.columns WHERE table_name = \'product_devices\' AND column_name = \'last_tx_at\' LIMIT 1',
        ),
      );
      if (test.isEmpty) return;
    } catch (_) {
      return;
    }

    // Backfill gerekmiyorsa çık.
    try {
      final missing = await _pool!.execute(
        Sql.named(
          'SELECT 1 FROM product_devices WHERE product_id = @pid AND last_tx_at IS NULL LIMIT 1',
        ),
        parameters: {'pid': productId},
      );
      if (missing.isEmpty) return;
    } catch (_) {
      return;
    }

    String? identityOf(Map raw) {
      try {
        final m = raw.cast<String, dynamic>();
        final v =
            (m['identity_value'] ??
                    m['identityValue'] ??
                    m['identity'] ??
                    m['imei'] ??
                    m['serial'] ??
                    m['serialNumber'] ??
                    m['serial_number'])
                ?.toString()
                .trim();
        if (v == null || v.isEmpty) return null;
        return v;
      } catch (_) {
        return null;
      }
    }

    DateTime? lastDate;
    int? lastShipmentId;

    for (int page = 0; page < maxPages; page++) {
      // Hâlâ boş kalan cihaz var mı?
      final stillMissing = await _pool!.execute(
        Sql.named(
          'SELECT 1 FROM product_devices WHERE product_id = @pid AND last_tx_at IS NULL LIMIT 1',
        ),
        parameters: {'pid': productId},
      );
      if (stillMissing.isEmpty) break;

      final txs = await DepolarVeritabaniServisi().urunHareketleriniGetir(
        urunKodu,
        kdvOrani: kdvOrani,
        limit: shipmentPageSize.clamp(1, 1000),
        lastDate: lastDate,
        lastShipmentId: lastShipmentId,
      );

      if (txs.isEmpty) break;

      for (final tx in txs) {
        final shipId = tx['id'] is int
            ? tx['id'] as int
            : int.tryParse(tx['id']?.toString() ?? '');
        final DateTime? dt =
            tx['date_raw'] is DateTime ? tx['date_raw'] as DateTime : null;
        final String typeLabel = (tx['customTypeLabel'] ?? tx['type'] ?? '')
            .toString()
            .trim();

        if (shipId == null || dt == null || typeLabel.isEmpty) continue;

        final rawDevices = tx['devices'];
        if (rawDevices is! List || rawDevices.isEmpty) continue;

        final identities = <String>{};
        for (final raw in rawDevices) {
          if (raw is! Map) continue;
          final idv = identityOf(raw);
          if (idv != null && idv.isNotEmpty) identities.add(idv);
        }

        if (identities.isEmpty) continue;

        try {
          await _pool!.execute(
            Sql.named('''
              UPDATE product_devices
              SET last_tx_at = @dt,
                  last_tx_type = @type,
                  last_tx_shipment_id = @sid
              WHERE product_id = @pid
                AND identity_value = ANY(@idents)
                AND last_tx_at IS NULL
            '''),
            parameters: {
              'dt': dt.toIso8601String(),
              'type': typeLabel,
              'sid': shipId,
              'pid': productId,
              'idents': identities.toList(growable: false),
            },
          );
        } catch (_) {
          // best-effort
        }
      }

      final last = txs.last;
      final prevDate = lastDate;
      final prevShipmentId = lastShipmentId;

      final DateTime? nextDate =
          last['date_raw'] is DateTime
              ? last['date_raw'] as DateTime
              : DateTime.tryParse(last['date_raw']?.toString() ?? '');
      final int? nextShipmentId =
          last['id'] is int
              ? last['id'] as int
              : int.tryParse(last['id']?.toString() ?? '');

      // Güvenlik: cursor ilerlemiyorsa sonsuz döngüye girme.
      if (nextDate == null && nextShipmentId == null) break;
      if (prevDate == nextDate && prevShipmentId == nextShipmentId) break;

      lastDate = nextDate;
      lastShipmentId = nextShipmentId;

      if (txs.length < shipmentPageSize.clamp(1, 1000)) break;
      if (throttle.inMilliseconds > 0) {
        await Future.delayed(throttle);
      }
    }
  }

  Future<List<Map<String, dynamic>>> cihazlariIdIleGetir({
    required List<int> ids,
    Session? session,
  }) async {
    if (ids.isEmpty) return const <Map<String, dynamic>>[];

    if (session == null) {
      if (!_isInitialized) await baslat();
      if (_pool == null) return [];
    }

    final executor = session ?? _pool!;
    final unique = ids.toSet().toList(growable: false);
    final res = await executor.execute(
      Sql.named('''
        SELECT
          pd.id,
          pd.product_id,
          pd.identity_type,
          pd.identity_value,
          pd.is_sold,
          pd.sale_ref,
          pd.last_tx_at,
          pd.last_tx_type,
          pd.last_tx_shipment_id
        FROM product_devices pd
        WHERE pd.id = ANY(@ids)
        ORDER BY pd.id ASC
      '''),
      parameters: {'ids': unique},
    );
    return res.map((r) => r.toColumnMap()).toList(growable: false);
  }

  Future<int?> urunIdGetir(String kod) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    final result = await _pool!.execute(
      Sql.named('SELECT id FROM products WHERE kod = @kod'),
      parameters: {'kod': kod},
    );

    if (result.isEmpty) return null;
    return result.first[0] as int?;
  }

  /// [PERFORMANCE] Batch ID Fetching (N+1 Killer)
  Future<Map<String, int>> urunIdleriniGetir(List<String> kodlar) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return {};
    if (kodlar.isEmpty) return {};

    final uniqueKods = kodlar.toSet().toList();

    final result = await _pool!.execute(
      Sql.named('SELECT kod, id FROM products WHERE kod = ANY(@kods)'),
      parameters: {'kods': uniqueKods},
    );

    final Map<String, int> idMap = {};
    for (final row in result) {
      idMap[row[0] as String] = row[1] as int;
    }
    return idMap;
  }

  /// [PERFORMANCE] Batch barcode fetcher
  /// Returns: { kod: barkod }
  Future<Map<String, String>> urunBarkodlariniGetir(List<String> kodlar) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return {};
    if (kodlar.isEmpty) return {};

    final uniqueKods = kodlar
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueKods.isEmpty) return {};

    final result = await _pool!.execute(
      Sql.named('SELECT kod, barkod FROM products WHERE kod = ANY(@kods)'),
      parameters: {'kods': uniqueKods},
    );

    final Map<String, String> barkodMap = {};
    for (final row in result) {
      final String kod = row[0]?.toString() ?? '';
      if (kod.isEmpty) continue;
      barkodMap[kod] = row[1]?.toString() ?? '';
    }

    final missingKods = uniqueKods.where((k) => !barkodMap.containsKey(k));
    if (missingKods.isNotEmpty) {
      final prodResult = await _pool!.execute(
        Sql.named('SELECT kod, barkod FROM productions WHERE kod = ANY(@kods)'),
        parameters: {'kods': missingKods.toList()},
      );
      for (final row in prodResult) {
        final String kod = row[0]?.toString() ?? '';
        if (kod.isEmpty) continue;
        barkodMap[kod] = row[1]?.toString() ?? '';
      }
    }

    return barkodMap;
  }
  // --- FIFO MALİYET HESAPLAMA ---

  /// Verilen miktar için FIFO yöntemine göre maliyet hesaplar.
  /// [productCode]: Hammadde/Ürün kodu
  /// [quantityNeeded]: İhtiyaç duyulan miktar
  /// Return: Toplam Maliyet (Birim Maliyet Değil)
  Future<double> calculateFifoCost(
    String productCode,
    double quantityNeeded, {
    TxSession? session,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0.0;
    if (quantityNeeded <= 0) return 0.0;

    final executor = session ?? _pool!;

    // Helper for safe double parsing
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    try {
      debugPrint(
        '    💰 [FIFO] Başladı: $productCode, Miktar: $quantityNeeded, Session: ${session != null}',
      );
      // 1. Toplam Çıkan Miktarı Bul (Sıra atlamak için)
      // Bu ürün için yapılmış tüm çıkışların toplamı (Negatif değerlerin mutlak toplamı)
      final outResult = await executor.execute(
        Sql.named('''
          SELECT ABS(COALESCE(SUM(quantity), 0)) as total_out
          FROM stock_movements
          WHERE product_id = (SELECT id FROM products WHERE kod = @code LIMIT 1)
          AND quantity < 0
        '''),
        parameters: {'code': productCode},
      );
      double totalOut = 0.0;
      if (outResult.isNotEmpty) {
        totalOut = parseDouble(outResult.first[0]);
      }
      debugPrint('    💰 [FIFO] Toplam Çıkış: $totalOut');

      // 2. Giriş Hareketlerini Getir (Tarihe göre eskiden yeniye)
      // Stoktaki mevcut katmanları bulmak için
      final inResult = await executor.execute(
        Sql.named('''
          SELECT quantity, unit_price
          FROM stock_movements
          WHERE product_id = (SELECT id FROM products WHERE kod = @code LIMIT 1)
          AND quantity > 0
          ORDER BY movement_date ASC, id ASC
        '''),
        parameters: {'code': productCode},
      );

      if (inResult.isEmpty) {
        debugPrint('    💰 [FIFO] Giriş hareketi bulunamadı, maliyet 0.');
        return 0.0;
      }

      double remainingToSkip = totalOut;
      double remainingNeeded = quantityNeeded;
      double totalCost = 0.0;
      debugPrint(
        '    💰 [FIFO] Döngü başlıyor. Giriş sayısı: ${inResult.length}',
      );

      for (final row in inResult) {
        double batchQuantity = parseDouble(row[0]);
        double batchPrice = parseDouble(row[1]);

        // Eğer bu batch tamamen daha önce kullanıldıysa atla
        if (remainingToSkip >= batchQuantity) {
          remainingToSkip -= batchQuantity;
          continue;
        }

        // Batch'in bir kısmı daha önce kullanılmış
        if (remainingToSkip > 0) {
          batchQuantity -= remainingToSkip;
          remainingToSkip = 0;
        }

        // Şimdi elimizde kullanılabilir batchQuantity var
        if (batchQuantity >= remainingNeeded) {
          // Bu batch ihtiyacımızı tamamen karşılıyor
          totalCost += remainingNeeded * batchPrice;
          remainingNeeded = 0;
          break;
        } else {
          // Bu batch'i tamamen kullanıyoruz ama yetmiyor
          totalCost += batchQuantity * batchPrice;
          remainingNeeded -= batchQuantity;
        }
      }

      debugPrint('    💰 [FIFO] Bitti. Toplam Maliyet: $totalCost');
      return totalCost;
    } catch (e) {
      debugPrint('FIFO Hesaplama Hatası ($productCode): $e');
      return 0.0;
    }
  }

  /// Entegrasyon referansına göre stok hareketlerini siler ve stokları geri alır.
  /// [OPTIMIZATION]: Batch Update (N+1 Query Killer)
  /// [2025 GUARD]: Çifte Silme Koruma - Aynı ref ile işlem yoksa erken çık
  Future<void> stokIslemiSilByRef(String ref, {TxSession? session}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // [2025 GUARD] Boş veya geçersiz referans kontrolü
    if (ref.isEmpty) {
      debugPrint(
        '[GUARD] stokIslemiSilByRef: Boş ref ile çağrıldı, atlanıyor.',
      );
      return;
    }

    final executor = session ?? _pool!;

    // 1. Verileri Topla (Join ile Code'u da al) - Tek Sorgu
    // [2025 GUARD]: Bu sorgu boş dönerse = Zaten silinmiş veya hiç oluşturulmamış
    final rows = await executor.execute(
      Sql.named('''
        SELECT sm.product_id, sm.warehouse_id, sm.quantity, sm.is_giris, p.kod 
        FROM stock_movements sm
        JOIN products p ON sm.product_id = p.id
        WHERE sm.integration_ref = @ref
      '''),
      parameters: {'ref': ref},
    );

    // [2025 GUARD] Çifte silme veya olmayan işlem kontrolü
    if (rows.isEmpty) {
      debugPrint(
        '[GUARD] stokIslemiSilByRef: ref=$ref için stock_movements bulunamadı. Shipments (üretim kodları dahil) temizliği denenecek.',
      );
    }

    // 2. Değişiklikleri Grupla (Memory Aggregation)
    final Map<int, double> productChanges =
        {}; // ProductID -> TotalQty (to subtract)
    final Map<String, double> warehouseChanges =
        {}; // "WarehouseID|ProductCode" -> TotalQty

    for (final row in rows) {
      final int pid = row[0] as int;
      final int? wid = row[1] as int?;
      final double qty = double.tryParse(row[2].toString()) ?? 0.0;
      final bool isGiris = row[3] as bool? ?? true;
      final String pCode = row[4] as String;

      // Reverse delta: incoming -> -qty, outgoing -> +qty
      final double signedQty = isGiris ? qty : -qty;

      // Product Total (Stoktan düşülecek miktar)
      productChanges[pid] = (productChanges[pid] ?? 0.0) + signedQty;

      // Warehouse Total
      if (wid != null) {
        final key = '$wid|$pCode';
        warehouseChanges[key] = (warehouseChanges[key] ?? 0.0) + signedQty;
      }
    }

    // 3. Batch Update: Products
    if (productChanges.isNotEmpty) {
      final updates = <String>[];
      final Map<String, dynamic> updateParams = {};
      int idx = 0;

      productChanges.forEach((pid, qty) {
        final pIdKey = 'pId$idx';
        final pQtyKey = 'pQty$idx';
        // (id, val)
        updates.add('(@$pIdKey::int, @$pQtyKey::numeric)');
        updateParams[pIdKey] = pid;
        updateParams[pQtyKey] = qty;
        idx++;
      });

      await executor.execute(
        Sql.named('''
          UPDATE products AS p 
          SET stok = p.stok - v.val 
          FROM (VALUES ${updates.join(',')}) AS v(id, val) 
          WHERE p.id = v.id
        '''),
        parameters: updateParams,
      );
    }

    // 4. Batch Update: Warehouse Stocks
    if (warehouseChanges.isNotEmpty) {
      final updates = <String>[];
      final Map<String, dynamic> updateParams = {};
      int idx = 0;

      warehouseChanges.forEach((key, qty) {
        final parts = key.split('|');
        final wid = int.parse(parts[0]);
        final code = parts[1];

        final wIdKey = 'wId$idx';
        final cKey = 'c$idx';
        final qKey = 'q$idx';

        // (id, code, val)
        updates.add('(@$wIdKey::int, @$cKey::text, @$qKey::numeric)');
        updateParams[wIdKey] = wid;
        updateParams[cKey] = code;
        updateParams[qKey] = qty;
        idx++;
      });

      await executor.execute(
        Sql.named('''
          UPDATE warehouse_stocks AS w 
          SET quantity = w.quantity - v.val 
          FROM (VALUES ${updates.join(',')}) AS v(id, code, val) 
          WHERE w.warehouse_id = v.id AND w.product_code = v.code
        '''),
        parameters: updateParams,
      );
    }

    // 5. Bulk Delete Movements
    await executor.execute(
      Sql.named('DELETE FROM stock_movements WHERE integration_ref = @ref'),
      parameters: {'ref': ref},
    );

    // 6. Shipments temizliği + (sadece productions kodları için) stok geri alma
    // Not: Ürün (products) stokları zaten stock_movements üzerinden geri alındı.
    try {
      final shipRes = await executor.execute(
        Sql.named('''
          SELECT id, source_warehouse_id, dest_warehouse_id, items
          FROM shipments
          WHERE integration_ref = @ref
        '''),
        parameters: {'ref': ref},
      );

      for (final row in shipRes) {
        final int? sourceId = row[1] as int?;
        final int? destId = row[2] as int?;
        final itemsRaw = row[3];
        final List itemsList = itemsRaw is String
            ? (jsonDecode(itemsRaw) as List)
            : (itemsRaw as List);

        // Sadece girdi/çıktı hareketleri için
        final int? warehouseIdForReverse = (sourceId == null && destId != null)
            ? destId
            : (sourceId != null && destId == null ? sourceId : null);
        if (warehouseIdForReverse == null) continue;

        final bool wasIncoming = sourceId == null && destId != null;

        for (final item in itemsList) {
          final code = (item as Map)['code']?.toString() ?? '';
          if (code.isEmpty) continue;
          final double qty =
              double.tryParse((item)['quantity']?.toString() ?? '') ?? 0.0;
          if (qty == 0) continue;

          // Reverse delta: incoming -> -qty, outgoing -> +qty
          final double delta = wasIncoming ? -qty : qty;

          // Productions stok geri al (code products'ta yoksa)
          await executor.execute(
            Sql.named('''
              UPDATE productions
              SET stok = stok + @delta
              WHERE kod = @code
                AND NOT EXISTS (SELECT 1 FROM products WHERE kod = @code)
            '''),
            parameters: {'delta': delta, 'code': code},
          );

          // Depo stok geri al (code products'ta yoksa)
          await executor.execute(
            Sql.named('''
              INSERT INTO warehouse_stocks (warehouse_id, product_code, quantity)
              SELECT @wid, @code, @delta
              WHERE NOT EXISTS (SELECT 1 FROM products WHERE kod = @code)
              ON CONFLICT (warehouse_id, product_code)
              DO UPDATE SET
                quantity = warehouse_stocks.quantity + EXCLUDED.quantity,
                updated_at = CURRENT_TIMESTAMP
            '''),
            parameters: {
              'wid': warehouseIdForReverse,
              'code': code,
              'delta': delta,
            },
          );
        }
      }

      await executor.execute(
        Sql.named('DELETE FROM shipments WHERE integration_ref = @ref'),
        parameters: {'ref': ref},
      );
    } catch (e) {
      // Shipments tablosu/kolonu yoksa veya migration çalışmadıysa, sessiz geç
      debugPrint('Shipments ref temizliği atlandı: $e');
    }

    // 7. [BUTTERFLY EFFECT FIX] Silinen her ürün için maliyetleri yeniden hesapla
    for (int pid in productChanges.keys) {
      await recalculateAverageCosts(pid, session: session);
    }
  }

  /// [2025 SMART UPDATE] Stok Hareketini (Miktar/Ürün/Depo değişmediyse) güncelle
  /// Eğer kritik alanlar değiştiyse, çağıran servis delete-insert yapmalıdır.
  /// Bu metod sadece description, date, price, currency güncellemesi içindir.
  Future<void> stokIslemiGuncelleByRef({
    required String ref,
    required DateTime tarih,
    required String aciklama,
    String? kullanici,
    TxSession? session,
    // Fiyat değişimi de maliyeti etkiler, bu yüzden sadece bilgi alanları güncellenmeli.
    // Eğer fiyat değişiyorsa, recalculateAverageCosts çalışmalı.
    // O yüzden burada fiyat güncellemesi de destekleyelim ama recalculate çağıralım.
    double? yeniFiyat,
    double? yeniKur,
    String? yeniParaBirimi,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final executor = session ?? _pool!;

    // 1. Etkilenen Ürünleri Bul (Maliyet Tekrar Hesaplanacak)
    final affectedProductsResult = await executor.execute(
      Sql.named(
        'SELECT DISTINCT product_id FROM stock_movements WHERE integration_ref = @ref',
      ),
      parameters: {'ref': ref},
    );
    final List<int> affectedProductIds = affectedProductsResult
        .map((r) => r[0] as int)
        .toList();

    // 2. Güncelleme
    String updateQuery = '''
      UPDATE stock_movements 
      SET movement_date = @tarih, 
          description = @aciklama,
          created_by = COALESCE(@kullanici, created_by)
    ''';

    Map<String, dynamic> params = {
      'ref': ref,
      'tarih': tarih.toIso8601String(),
      'aciklama': aciklama,
      'kullanici': kullanici,
    };

    if (yeniFiyat != null) {
      updateQuery += ', unit_price = @fiyat';
      params['fiyat'] = yeniFiyat;
    }
    if (yeniKur != null) {
      updateQuery += ', currency_rate = @kur';
      params['kur'] = yeniKur;
    }
    if (yeniParaBirimi != null) {
      updateQuery += ', currency_code = @pb';
      params['pb'] = yeniParaBirimi;
    }

    updateQuery += ' WHERE integration_ref = @ref';

    await executor.execute(Sql.named(updateQuery), parameters: params);

    // 3. Maliyetleri Yeniden Hesapla (Sadece fiyat/tarih değiştiyse gerekir ama güvenli olsun)
    if (affectedProductIds.isNotEmpty) {
      for (final pid in affectedProductIds) {
        await recalculateAverageCosts(pid, session: session);
      }
    }
  }

  Future<List<Map<String, dynamic>>> urunHareketleriniGetir({
    required int urunId,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? arama,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    String query = '''
      SELECT 
        sm.id,
        sm.movement_type as islem_turu,
        sm.movement_date as tarih,
        sm.quantity as miktar,
        sm.unit_price as birim_fiyat,
        (sm.quantity * sm.unit_price) as tutar,
        sm.description as aciklama,
        sm.created_by as kullanici,
        w.name as depo_adi,
        sm.integration_ref,
        CASE WHEN sm.quantity > 0 THEN 'Giriş' ELSE 'Çıkış' END as yon
      FROM stock_movements sm
      LEFT JOIN warehouses w ON sm.warehouse_id = w.id
      WHERE sm.product_id = @urunId
    ''';

    Map<String, dynamic> params = {'urunId': urunId};

    if (baslangicTarihi != null) {
      query += ' AND sm.movement_date >= @baslangic';
      params['baslangic'] = baslangicTarihi.toIso8601String();
    }
    if (bitisTarihi != null) {
      query += ' AND sm.movement_date <= @bitis';
      params['bitis'] = bitisTarihi.toIso8601String();
    }

    query += ' ORDER BY sm.movement_date DESC';

    final result = await _pool!.execute(Sql.named(query), parameters: params);

    return result.map((row) {
      dynamic rawDate = row[2];
      String dateStr = '';
      if (rawDate is DateTime) {
        dateStr = DateFormat('dd.MM.yyyy HH:mm').format(rawDate);
      } else if (rawDate != null) {
        dateStr = rawDate.toString();
      }

      return {
        'id': row[0],
        'islem_turu': row[1],
        'tarih': dateStr,
        'miktar': row[3],
        'birim_fiyat': row[4],
        'tutar': row[5],
        'aciklama': row[6],
        'kullanici': row[7],
        'depo_adi': row[8],
        'integration_ref': row[9],
        'yon': row[10],
      };
    }).toList();
  }

  Future<void> _backfillStockMovementSearchTags({
    int batchSize = 2000,
    int maxBatches = 50,
  }) async {
    final pool = _pool;
    if (pool == null) return;

    try {
      for (int i = 0; i < maxBatches; i++) {
        final res = await pool.execute(
          Sql.named('''
            WITH todo AS (
              SELECT
                sm.id,
                sm.created_at,
                sm.product_id,
                sm.warehouse_id,
                sm.shipment_id,
                sm.quantity,
                sm.is_giris,
                sm.unit_price,
                sm.currency_code,
                sm.currency_rate,
                sm.vat_status,
                sm.movement_date,
                sm.description,
                sm.movement_type,
                sm.created_by,
                sm.integration_ref
              FROM stock_movements sm
              WHERE sm.search_tags IS NULL OR sm.search_tags = ''
              ORDER BY sm.created_at DESC, sm.id DESC
              LIMIT @limit
            ),
            computed AS (
              SELECT
                t.id,
                t.created_at,
                LOWER(
                  COALESCE((
                    CASE
                      WHEN COALESCE(t.integration_ref, '') = 'opening_stock' OR COALESCE(t.description, '') ILIKE '%Açılış%' THEN 'açılış stoğu'
                      WHEN COALESCE(t.integration_ref, '') LIKE 'SALE-%' OR COALESCE(t.integration_ref, '') LIKE 'RETAIL-%' THEN 'satış faturası satış yapıldı'
                      WHEN COALESCE(t.integration_ref, '') LIKE 'PURCHASE-%' THEN 'alış faturası alış yapıldı'
                      WHEN COALESCE(t.integration_ref, '') = 'production_output' OR COALESCE(t.description, '') ILIKE '%Üretim%' THEN 'üretim'
                      ELSE COALESCE(t.movement_type, '')
                    END
                  ), '') || ' ' ||
                  (CASE WHEN t.is_giris THEN 'giriş stok giriş' ELSE 'çıkış stok çıkış' END) || ' ' ||
                  COALESCE(TO_CHAR(t.movement_date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
                  COALESCE(TO_CHAR(t.movement_date, 'DD.MM'), '') || ' ' ||
                  COALESCE(TO_CHAR(t.movement_date, 'HH24:MI'), '') || ' ' ||
                  COALESCE(p.kod, '') || ' ' || COALESCE(p.ad, '') || ' ' || COALESCE(p.barkod, '') || ' ' ||
                  COALESCE(d.kod, '') || ' ' || COALESCE(d.ad, '') || ' ' ||
                  COALESCE(CAST(t.quantity AS TEXT), '') || ' ' ||
                  COALESCE(REPLACE(CAST(t.quantity AS TEXT), '.', ','), '') || ' ' ||
                  COALESCE(CAST(t.unit_price AS TEXT), '') || ' ' ||
                  COALESCE(REPLACE(CAST(t.unit_price AS TEXT), '.', ','), '') || ' ' ||
                  COALESCE(t.currency_code, '') || ' ' ||
                  COALESCE(CAST(t.currency_rate AS TEXT), '') || ' ' ||
                  COALESCE(REPLACE(CAST(t.currency_rate AS TEXT), '.', ','), '') || ' ' ||
                  COALESCE(t.vat_status, '') || ' ' ||
                  (CASE WHEN t.vat_status = 'included' THEN 'kdv dahil dahil' ELSE 'kdv hariç hariç' END) || ' ' ||
                  COALESCE(t.description, '') || ' ' ||
                  COALESCE(t.created_by, '') || ' ' ||
                  COALESCE(t.integration_ref, '') || ' ' ||
                  COALESCE(CAST(t.id AS TEXT), '') || ' ' ||
                  COALESCE(CAST(t.shipment_id AS TEXT), '')
                ) AS new_tags
              FROM todo t
              LEFT JOIN depots d ON t.warehouse_id = d.id
              LEFT JOIN products p ON t.product_id = p.id
            )
            UPDATE stock_movements sm
            SET search_tags = c.new_tags
            FROM computed c
            WHERE sm.id = c.id AND sm.created_at = c.created_at
            RETURNING sm.id
          '''),
          parameters: {'limit': batchSize},
        );

        if (res.isEmpty) break;
        await Future.delayed(const Duration(milliseconds: 25));
      }
    } catch (e) {
      if (e is LisansYazmaEngelliHatasi) return;
      debugPrint('stock_movements search_tags backfill uyarısı: $e');
    }
  }

  static bool _isDesktopPlatform() {
    if (kIsWeb) return false;
    // CREATE INDEX races can happen on all native platforms during concurrent startup.
    return Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isWindows ||
        Platform.isIOS ||
        Platform.isAndroid;
  }

  static bool _isBenignCreateIndexError(Object e) {
    final msg = e.toString();
    final code = e is ServerException ? e.code : null;

    // Concurrent CREATE INDEX (even with IF NOT EXISTS) can race and throw unique_violation
    // on pg_class_relname_nsp_index. If we lost the race, treat as success.
    if (code == '23505') {
      return msg.contains('pg_class_relname_nsp_index');
    }

    // Relation already exists / duplicate object.
    if (code == '42P07' || code == '42710') return true;

    // Fallback: sometimes error type isn't ServerException.
    if (msg.contains('pg_class_relname_nsp_index') && msg.contains('23505')) {
      return true;
    }
    if (msg.contains('42P07') || msg.contains('42710')) return true;

    return false;
  }

  static String? _extractIndexName(String sql) {
    final match = RegExp(
      r'CREATE\s+INDEX\s+IF\s+NOT\s+EXISTS\s+([a-zA-Z0-9_]+)',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(sql);
    return match?.group(1);
  }

  Future<void> _executeCreateIndexSafe(String sql) async {
    if (_pool == null) return;
    try {
      await _pool!.execute(sql);
    } catch (e) {
      if (_isDesktopPlatform() && _isBenignCreateIndexError(e)) {
        final indexName = _extractIndexName(sql);
        if (indexName != null) {
          // Wait for the other concurrent creator to finish committing the index.
          for (int i = 0; i < 20; i++) {
            final exists = await _pool!.execute(
              Sql.named('SELECT 1 FROM pg_class WHERE relname = @n'),
              parameters: {'n': indexName},
            );
            if (exists.isNotEmpty) return;
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }
        return;
      }
      rethrow;
    }
  }

  Future<void> _ensureStockMovementPartitionsForRange(
    DateTime start,
    DateTime end, {
    Session? session,
  }) async {
    final executor = session ?? _pool;
    if (executor == null) return;

    var s = start;
    var e = end;
    if (e.isBefore(s)) {
      final tmp = s;
      s = e;
      e = tmp;
    }

    final DateTime cursorStart = DateTime(s.year, s.month, 1);
    final DateTime endMonth = DateTime(e.year, e.month, 1);

    var cursor = cursorStart;
    for (var i = 0; i < 600; i++) {
      final int year = cursor.year;
      final int month = cursor.month;
      final String monthStr = month.toString().padLeft(2, '0');
      final String partitionName = 'stock_movements_y${year}_m$monthStr';
      final String startStr = '$year-$monthStr-01';
      final endDate = DateTime(year, month + 1, 1);
      final String endStr =
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-01';

      try {
        await executor.execute('''
          CREATE TABLE IF NOT EXISTS $partitionName
          PARTITION OF stock_movements
          FOR VALUES FROM ('$startStr') TO ('$endStr')
        ''');
      } catch (e) {
        // 42P17 overlap: legacy yıllık partition veya farklı isimli partition bu aralığı kapsıyor.
        if (e is ServerException && e.code == '42P17') {
          // ignore
        } else {
          rethrow;
        }
      }

      if (cursor.year == endMonth.year && cursor.month == endMonth.month) break;
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
  }

  Future<void> _backfillStockMovementsDefault({Session? session}) async {
    final executor = session ?? _pool;
    if (executor == null) return;

    final range = await executor.execute('''
      SELECT MIN(created_at), MAX(created_at)
      FROM stock_movements_default
      WHERE created_at IS NOT NULL
    ''');
    if (range.isEmpty) return;
    final minDt = range.first[0] as DateTime?;
    final maxDt = range.first[1] as DateTime?;
    if (minDt == null || maxDt == null) return;

    await _ensureStockMovementPartitionsForRange(minDt, maxDt, session: executor);

    await PgEklentiler.moveRowsFromDefaultPartition(
      executor: executor,
      parentTable: 'stock_movements',
      defaultTable: 'stock_movements_default',
      partitionKeyColumn: 'created_at',
    );
  }
}

// Top-level function for Isolate
List<UrunModel> _parseUrunlerIsolate(List<Map<String, dynamic>> data) {
  return data.map((d) => UrunModel.fromMap(d)).toList();
}

void _makeIsolateSafeMapInPlace(Map<String, dynamic> map) {
  map.updateAll((_, v) => _toIsolateSafeValue(v));
}

dynamic _toIsolateSafeValue(dynamic value) {
  if (value == null || value is num || value is String || value is bool) {
    return value;
  }
  if (value is DateTime) return value.toIso8601String();

  if (value is List) {
    return value.map(_toIsolateSafeValue).toList(growable: false);
  }

  if (value is Map) {
    final out = <String, dynamic>{};
    value.forEach((k, v) => out[k.toString()] = _toIsolateSafeValue(v));
    return out;
  }

  // postgres UndecodedBytes gibi tipler (jsonb/bytea): { bytes: List<int> }
  try {
    final bytes = (value as dynamic).bytes;
    if (bytes is List<int>) return bytes;
  } catch (_) {}

  return value;
}
