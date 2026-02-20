import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../sayfalar/urunler_ve_depolar/uretimler/modeller/uretim_model.dart';
import 'oturum_servisi.dart';
import 'depolar_veritabani_servisi.dart';
import 'urunler_veritabani_servisi.dart';
import '../sayfalar/urunler_ve_depolar/depolar/sevkiyat_olustur_sayfasi.dart';
import 'bulut_sema_dogrulama_servisi.dart';
import 'pg_eklentiler.dart';
import 'veritabani_yapilandirma.dart';
import 'ayarlar_veritabani_servisi.dart';
import 'lisans_yazma_koruma.dart';

class UretimlerVeritabaniServisi {
  static final UretimlerVeritabaniServisi _instance =
      UretimlerVeritabaniServisi._internal();
  factory UretimlerVeritabaniServisi() => _instance;
  UretimlerVeritabaniServisi._internal();

  Pool? _pool;
  bool _isInitialized = false;

  // PostgreSQL Bağlantı Ayarları (Merkezi Yapılandırma)
  final _yapilandirma = VeritabaniYapilandirma();

  Completer<void>? _initCompleter;
  int _initToken = 0;

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
      final err = StateError('Üretimler veritabanı bağlantısı kurulamadı.');
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
            'UretimlerVeritabaniServisi: Bulut şema hazır, tablo kurulumu atlandı.',
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
        debugPrint(
          'Üretimler veritabanı bağlantısı başarılı (Havuz): ${OturumServisi().aktifVeritabaniAdi}',
        );
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

    // Üretimler Tablosu
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS productions (
        id SERIAL PRIMARY KEY,
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
        search_tags TEXT,
        created_by TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

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

    // MIGRATION FIX: Mevcut tablolara 'search_tags' kolonunu ekle (Eğer yoksa)
    try {
      await _pool!.execute(
        'ALTER TABLE productions ADD COLUMN IF NOT EXISTS search_tags TEXT',
      );
    } catch (e) {
      debugPrint('Kolon ekleme hatası (Normal olabilir): $e');
    }

    // 50 Milyon Veri İçin Performans İndeksleri
    try {
      await PgEklentiler.ensurePgTrgm(_pool!);

      // Üretimler tablosu için Trigram Indexler (Metin Arama)
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_productions_kod_trgm ON productions USING GIN (kod gin_trgm_ops)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_productions_ad_trgm ON productions USING GIN (ad gin_trgm_ops)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_productions_barkod_trgm ON productions USING GIN (barkod gin_trgm_ops)',
      );

      // Equality check (Unique Code Check) için B-Tree Index
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_productions_kod_btree ON productions (kod)',
      );

      // KRİTİK FİLTRE PERFORMANSI: B-Tree İndeksleri
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_productions_grubu_btree ON productions(grubu)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_productions_birim_btree ON productions(birim)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_productions_kdv_btree ON productions(kdv_orani)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_productions_aktif_btree ON productions(aktif_mi)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_productions_created_by ON productions(created_by)',
      );

      // Trigram İndeksler (Metin İçinde Arama İçin)
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_productions_kullanici_trgm ON productions USING GIN (kullanici gin_trgm_ops)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_productions_ozellikler_trgm ON productions USING GIN (ozellikler gin_trgm_ops)',
      );

      // Arama İzi İndeksi (Denormalized Search Index)
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_productions_search_tags_gin ON productions USING GIN (search_tags gin_trgm_ops)',
      );

      // OTO-INDEKSLEME (TRIGGER)
      await _pool!.execute('''
        CREATE OR REPLACE FUNCTION update_productions_search_tags()
        RETURNS TRIGGER AS \$\$
        DECLARE
          history_text TEXT := '';
        BEGIN
          -- 1 Milyar Kayıt İçin Hareket Geçmişi İndeksleme
          -- `search_tags` alanına üretim hareketlerini (Tarih, Depo, Miktar, Fiyat, Kullanıcı) ekler.
          SELECT STRING_AGG(sub.line, ' ') INTO history_text
          FROM (
             SELECT 
               LOWER(
                 COALESCE(
                   CASE 
                     WHEN psm.movement_type = 'uretim_giris' THEN 'üretim (girdi)'
                     WHEN psm.movement_type = 'uretim_cikis' THEN 'üretim (çıktı)'
                     WHEN psm.movement_type = 'satis_faturasi' THEN 'satış faturası'
                     WHEN psm.movement_type = 'alis_faturasi' THEN 'alış faturası'
                     WHEN psm.movement_type = 'devir_giris' THEN 'devir girdi'
                     WHEN psm.movement_type = 'devir_cikis' THEN 'devir çıktı'
                     WHEN psm.movement_type = 'sevkiyat' THEN 'sevkiyat' 
                     ELSE psm.movement_type 
                   END, 
                   'işlem'
                 ) || ' ' ||
                 TO_CHAR(psm.movement_date, 'DD.MM.YYYY HH24:MI') || ' ' ||
                 TO_CHAR(psm.movement_date, 'DD.MM') || ' ' ||
                 TO_CHAR(psm.movement_date, 'HH24:MI') || ' ' ||
                 COALESCE(d.ad, '') || ' ' || 
                 COALESCE(psm.quantity::text, '') || ' ' ||
                 COALESCE(psm.unit_price::text, '') || ' ' ||
                 COALESCE(psm.created_by, '')
               ) as line
             FROM production_stock_movements psm
             LEFT JOIN depots d ON psm.warehouse_id = d.id
             WHERE psm.production_id = NEW.id
             ORDER BY psm.movement_date DESC
             LIMIT 50
          ) sub;

          NEW.search_tags := LOWER(
            COALESCE(NEW.kod, '') || ' ' || 
            COALESCE(NEW.ad, '') || ' ' || 
            COALESCE(NEW.barkod, '') || ' ' || 
            COALESCE(NEW.grubu, '') || ' ' || 
            COALESCE(NEW.kullanici, '') || ' ' || 
            COALESCE(NEW.ozellikler, '') || ' ' || 
            COALESCE(NEW.birim, '') || ' ' || 
            CAST(NEW.id AS TEXT) || ' ' ||
            COALESCE(CAST(NEW.alis_fiyati AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.satis_fiyati_1 AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.satis_fiyati_2 AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.satis_fiyati_3 AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.erken_uyari_miktari AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.stok AS TEXT), '') || ' ' ||
            COALESCE(CAST(NEW.kdv_orani AS TEXT), '') || ' ' ||
            (CASE WHEN NEW.aktif_mi = 1 THEN 'aktif' ELSE 'pasif' END)
          ) || ' ' || COALESCE(history_text, '');
          RETURN NEW;
        END;
        \$\$ LANGUAGE plpgsql;
      ''');

      // Trigger zaten var mı kontrol et
      final triggerExists = await _pool!.execute(
        "SELECT 1 FROM pg_trigger WHERE tgname = 'trg_update_productions_search_tags'",
      );

      // Yoksa oluştur
      if (triggerExists.isEmpty) {
        await _pool!.execute('''
          CREATE TRIGGER trg_update_productions_search_tags
          BEFORE INSERT OR UPDATE ON productions
          FOR EACH ROW
          EXECUTE FUNCTION update_productions_search_tags();
        ''');
      }

      debugPrint(
        '🚀 Üretimler Performans Modu: Triggerlar ve B-Tree İndeksleri Aktif Edildi.',
      );
    } catch (e) {
      debugPrint('Performans indeksleri oluşturulurken uyarı: $e');
    }

    // Üretim Reçetesi (BOM - Bill of Materials) Tablosu
    try {
      await _pool!.execute('''
        CREATE TABLE IF NOT EXISTS production_recipe_items (
          id SERIAL PRIMARY KEY,
          production_id INTEGER NOT NULL,
          product_code TEXT NOT NULL,
          product_name TEXT NOT NULL,
          unit TEXT NOT NULL,
          quantity NUMERIC DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          CONSTRAINT fk_production FOREIGN KEY (production_id) 
            REFERENCES productions(id) ON DELETE CASCADE
        )
      ''');

      // Reçete performans indeksleri
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_recipe_production_id ON production_recipe_items(production_id)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_recipe_product_code ON production_recipe_items(product_code)',
      );

      debugPrint('🍳 Üretim Reçetesi Tablosu hazır.');
    } catch (e) {
      debugPrint('Reçete tablosu oluşturma hatası: $e');
    }

    // Üretim Stok Hareketleri (Production Stock Movements) Tablosu - 2025 Modernization
    // Özellikler: Native Partitioning (by created_at) + BRIN Index + GIN Index
    try {
      // 1. Mevcut tablonun durumunu kontrol et (Partitioned mı, Normal mi?)
      final checkPartition = await _pool!.execute(
        "SELECT relkind::text FROM pg_class WHERE relname = 'production_stock_movements'",
      );

      bool tableExists = checkPartition.isNotEmpty;
      final String relkind = tableExists
          ? checkPartition.first[0].toString().toLowerCase()
          : '';
      bool isPartitioned = tableExists && relkind == 'p';

      // 2. Eğer normal tablo varsa ve partitioned değilse -> Göç (Migration) başlat
      if (tableExists && !isPartitioned) {
        debugPrint(
          '🚀 Migrating production_stock_movements to Partitioned Structure...',
        );

        // Safe Rename: Drop target if it exists (remnant of failed migration)
        try {
          await _pool!.execute(
            'DROP TABLE IF EXISTS production_stock_movements_old CASCADE',
          );
        } catch (_) {}

        // Eski tabloyu yeniden adlandır
        await _pool!.execute(
          'ALTER TABLE production_stock_movements RENAME TO production_stock_movements_old',
        );

        // Yeni tablo yaratılacağı için flag'i güncelle
        tableExists = false;
      }

      // 3. Tablo yoksa (veya az önce rename edildiyse) -> Partitioned Tabloyu Oluştur
      if (!tableExists) {
        await _pool!.execute('''
          CREATE TABLE production_stock_movements (
            id SERIAL,
            production_id INTEGER NOT NULL,
            warehouse_id INTEGER NOT NULL,
            quantity NUMERIC DEFAULT 0,
            unit_price NUMERIC DEFAULT 0,
            currency TEXT DEFAULT 'TRY',
            vat_status TEXT DEFAULT 'excluded',
            movement_date TIMESTAMP,
            description TEXT,
            movement_type TEXT,
            created_by TEXT,
            consumed_items JSONB,
            related_shipment_ids JSONB,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id, created_at)
          ) PARTITION BY RANGE (created_at)
        ''');

        // Partitions (Bölümler) - Yıllık
        // [2025 AUTO-PARTITION] Dynamic Partitioning Logic - MUST RUN EVERY TIME
      }

      // Ensure partitions exist for a wide range of years to catch all historical data during migration
      // This is moved outside the 'if (!tableExists)' block to be safe.

      // 1. Default Partition
      await _pool!.execute(
        'CREATE TABLE IF NOT EXISTS production_stock_movements_default PARTITION OF production_stock_movements DEFAULT',
      );

      // 2. Year Partitions (ULTRA WIDE RANGE: 2020 to Current + 10)
      // This guarantees we cover almost any historical data and future data.
      final int currentYear = DateTime.now().year;
      final int startYear = 2020;
      final int endYear = currentYear + 10;

      for (int year = startYear; year <= endYear; year++) {
        await _pool!.execute('''
          CREATE TABLE IF NOT EXISTS production_stock_movements_$year 
          PARTITION OF production_stock_movements FOR VALUES FROM ('$year-01-01') TO ('${year + 1}-01-01')
        ''');
      }

      // 4. Veri Göçü (Eğer eski tablo varsa verileri taşı)
      // Not: Eski tabloda created_at null ise NOW() atıyoruz, partitioning için zorunlu.
      if (checkPartition.isNotEmpty && !isPartitioned) {
        try {
          await _pool!.execute('''
              INSERT INTO production_stock_movements (
                id, production_id, warehouse_id, quantity, unit_price, currency, 
                vat_status, movement_date, description, movement_type, 
                created_by, consumed_items, related_shipment_ids, created_at
              )
              SELECT 
                id, production_id, warehouse_id, quantity, unit_price, currency, 
                vat_status, movement_date, description, movement_type, 
                created_by, consumed_items, related_shipment_ids, COALESCE(created_at, NOW())
              FROM production_stock_movements_old
            ''');
          debugPrint(
            '✅ Data migration for production_stock_movements complete.',
          );
          // Opsiyonel: Eski tabloyu düşür (Güvenlik için şimdilik tutuyoruz)
          // await _pool!.execute('DROP TABLE production_stock_movements_old');
        } catch (mgrErr) {
          debugPrint('❌ Migration Insert Error: $mgrErr');
        }
      }
      // 5. İndeksler (Create IF NOT EXISTS conflict yönetir)
      // Standart B-Tree
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_psm_production_id ON production_stock_movements(production_id)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_psm_warehouse_id ON production_stock_movements(warehouse_id)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_psm_date ON production_stock_movements(movement_date)',
      );

      // [CRITICAL] BRIN Index for Time-Series Performance (1B+ records)
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_psm_created_at_brin ON production_stock_movements USING BRIN (created_at)',
      );

      // [CRITICAL] GIN Index for JSONB Queries
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_psm_related_shipments_gin ON production_stock_movements USING GIN (related_shipment_ids)',
      );

      debugPrint(
        '🏭 Üretim Stok Hareketleri Tablosu (Partitioned & Optimized) hazır.',
      );
    } catch (e) {
      debugPrint('Üretim stok hareketleri tablosu oluşturma hatası: $e');
    }

    // Migration: Add consumed_items and related_shipment_ids
    try {
      await _pool!.execute(
        'ALTER TABLE production_stock_movements ADD COLUMN IF NOT EXISTS consumed_items JSONB',
      );
      await _pool!.execute(
        'ALTER TABLE production_stock_movements ADD COLUMN IF NOT EXISTS related_shipment_ids JSONB',
      );
    } catch (e) {
      debugPrint('Kolon ekleme hatası (Normal olabilir): $e');
    }

    // Not: stock_movements güncellemeleri aşağıdaki 2. AŞAMA bloğunda daha sağlıklı yönetilmektedir.

    // 2. AŞAMA: Genel stok hareketleri tablosu (Partitioned & Standardized)
    try {
      final smExists = await _pool!.execute(
        "SELECT 1 FROM information_schema.tables WHERE table_name = 'stock_movements'",
      );

      if (smExists.isEmpty) {
        await _pool!.execute('''
          CREATE TABLE stock_movements (
            id SERIAL,
            product_id INTEGER,
            warehouse_id INTEGER,
            shipment_id INTEGER,
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
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id, created_at)
          ) PARTITION BY RANGE (created_at)
        ''');

        // Parçaları oluştur
        await _pool!.execute(
          'CREATE TABLE IF NOT EXISTS stock_movements_default PARTITION OF stock_movements DEFAULT',
        );
        // [2025 AUTO-PARTITION] Dynamic Partitioning
        final int smCurrentYear = DateTime.now().year;
        for (int i = 0; i < 5; i++) {
          final int year = smCurrentYear + i;
          await _pool!.execute('''
            CREATE TABLE IF NOT EXISTS stock_movements_$year 
            PARTITION OF stock_movements FOR VALUES FROM ('$year-01-01') TO ('${year + 1}-01-01')
          ''');
        }
      }

      // [2025 HYPER-ROBUST] Verify table existence before any ALTER/INDEX operation
      final smCheck = await _pool!.execute(
        "SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'stock_movements'",
      );

      if (smCheck.isNotEmpty) {
        // Migration: Eksik kolonları ekle (Tüm servisler için ortak kanonik şema)
        await _pool!.execute(
          'ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS is_giris BOOLEAN NOT NULL DEFAULT true',
        );
        await _pool!.execute(
          'ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS shipment_id INTEGER',
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
          'stock_movements henüz oluşturulmadı (Productions). Atlanıyor...',
        );
      }
    } catch (e) {
      debugPrint('Stok hareketleri tablosu fix hatası (productions): $e');
    }
    // 3. AŞAMA: 1 Milyar Kayıt İçin Metadata ve İstatistik Tabloları (New Architecture)

    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS production_metadata (
        type TEXT NOT NULL, -- 'group', 'unit', 'vat'
        value TEXT NOT NULL,
        frequency BIGINT DEFAULT 1,
        PRIMARY KEY (type, value)
      )
    ''');

    // table_counts zaten UrunlerServisi tarafından oluşturulmuş olabilir ama garanti olsun diye IF NOT EXISTS
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS table_counts (
        table_name TEXT PRIMARY KEY,
        row_count BIGINT DEFAULT 0
      )
    ''');

    // 4. AŞAMA: TRIGGERLAR (Otomatik Bakım)

    // 4.1. Kayıt Sayısı Sayacı (Count Cache)
    // update_table_counts fonksiyonu zaten global (public schema) olabilir ama
    // eğer UretimlerServisi tek başına çalışırsa diye kontrol edelim/oluşturalım.
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
      "SELECT 1 FROM pg_trigger WHERE tgname = 'trg_update_productions_count'",
    );
    if (countTriggerExists.isEmpty) {
      await _pool!.execute('''
        CREATE TRIGGER trg_update_productions_count
        AFTER INSERT OR DELETE ON productions
        FOR EACH ROW EXECUTE FUNCTION update_table_counts();
      ''');

      // İlk Kurulum
      await _pool!.execute('''
        INSERT INTO table_counts (table_name, row_count)
        SELECT 'productions', COUNT(*) FROM productions
        ON CONFLICT (table_name) DO UPDATE SET row_count = EXCLUDED.row_count;
      ''');
    }

    // 4.2. Filtre Metadata Okuyucu (Distinct Value Cache)
    await _pool!.execute('''
      CREATE OR REPLACE FUNCTION update_production_metadata() RETURNS TRIGGER AS \$\$
      BEGIN
        -- INSERT İŞLEMİ
        IF (TG_OP = 'INSERT') THEN
           IF NEW.grubu IS NOT NULL THEN
             INSERT INTO production_metadata (type, value, frequency) VALUES ('group', NEW.grubu, 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
           END IF;
           IF NEW.birim IS NOT NULL THEN
             INSERT INTO production_metadata (type, value, frequency) VALUES ('unit', NEW.birim, 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
           END IF;
           IF NEW.kdv_orani IS NOT NULL THEN
             INSERT INTO production_metadata (type, value, frequency) VALUES ('vat', CAST(NEW.kdv_orani AS TEXT), 1)
             ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
           END IF;
           
        -- UPDATE İŞLEMİ
        ELSIF (TG_OP = 'UPDATE') THEN
           IF OLD.grubu IS DISTINCT FROM NEW.grubu THEN
               IF OLD.grubu IS NOT NULL THEN
                  UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'group' AND value = OLD.grubu;
               END IF;
               IF NEW.grubu IS NOT NULL THEN
                  INSERT INTO production_metadata (type, value, frequency) VALUES ('group', NEW.grubu, 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
               END IF;
           END IF;
           
           IF OLD.birim IS DISTINCT FROM NEW.birim THEN
               IF OLD.birim IS NOT NULL THEN
                  UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'unit' AND value = OLD.birim;
               END IF;
               IF NEW.birim IS NOT NULL THEN
                  INSERT INTO production_metadata (type, value, frequency) VALUES ('unit', NEW.birim, 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
               END IF;
           END IF;

           IF OLD.kdv_orani IS DISTINCT FROM NEW.kdv_orani THEN
               IF OLD.kdv_orani IS NOT NULL THEN
                  UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'vat' AND value = CAST(OLD.kdv_orani AS TEXT);
               END IF;
               IF NEW.kdv_orani IS NOT NULL THEN
                  INSERT INTO production_metadata (type, value, frequency) VALUES ('vat', CAST(NEW.kdv_orani AS TEXT), 1)
                  ON CONFLICT (type, value) DO UPDATE SET frequency = production_metadata.frequency + 1;
               END IF;
           END IF;

        -- DELETE İŞLEMİ
        ELSIF (TG_OP = 'DELETE') THEN
           IF OLD.grubu IS NOT NULL THEN
             UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'group' AND value = OLD.grubu;
           END IF;
           IF OLD.birim IS NOT NULL THEN
             UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'unit' AND value = OLD.birim;
           END IF;
           IF OLD.kdv_orani IS NOT NULL THEN
             UPDATE production_metadata SET frequency = frequency - 1 WHERE type = 'vat' AND value = CAST(OLD.kdv_orani AS TEXT);
           END IF;
        END IF;

        DELETE FROM production_metadata WHERE frequency <= 0;
        
        RETURN NULL;
      END;
      \$\$ LANGUAGE plpgsql;
    ''');

    final metaTriggerExists = await _pool!.execute(
      "SELECT 1 FROM pg_trigger WHERE tgname = 'trg_update_productions_metadata'",
    );
    if (metaTriggerExists.isEmpty) {
      await _pool!.execute('''
        CREATE TRIGGER trg_update_productions_metadata
        AFTER INSERT OR UPDATE OR DELETE ON productions
        FOR EACH ROW EXECUTE FUNCTION update_production_metadata();
      ''');

      await _pool!.execute('''
        INSERT INTO production_metadata (type, value, frequency)
        SELECT 'group', grubu, COUNT(*) FROM productions WHERE grubu IS NOT NULL GROUP BY grubu
        ON CONFLICT (type, value) DO UPDATE SET frequency = EXCLUDED.frequency;
      ''');
      await _pool!.execute('''
        INSERT INTO production_metadata (type, value, frequency)
        SELECT 'unit', birim, COUNT(*) FROM productions WHERE birim IS NOT NULL GROUP BY birim
        ON CONFLICT (type, value) DO UPDATE SET frequency = EXCLUDED.frequency;
      ''');
      await _pool!.execute('''
         INSERT INTO production_metadata (type, value, frequency)
         SELECT 'vat', CAST(kdv_orani AS TEXT), COUNT(*) FROM productions WHERE kdv_orani IS NOT NULL GROUP BY kdv_orani
         ON CONFLICT (type, value) DO UPDATE SET frequency = EXCLUDED.frequency;
      ''');
    }
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

  // --- ÜRETİM İŞLEMLERİ ---

  /// Üretimler sayfası için "İşlem Türü" filtresini getirir.
  /// Sadece üretim tablosundaki ürünleri içeren sevkiyat tiplerini döndürür.
  Future<List<String>> getUretimStokIslemTurleri() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    try {
      final List<String> types = [];

      // CONSTANT: Production Filter Condition
      // Checks if the shipment contains at least one item that exists in 'productions' table
      const String productionItemCheck =
          "EXISTS (SELECT 1 FROM jsonb_array_elements(s.items) AS item WHERE item->>'code' IN (SELECT kod FROM productions))";

      // 1. Opening Stock
      final openingExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE $productionItemCheck AND s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%') LIMIT 1",
      );
      if (openingExists.isNotEmpty) types.add('Açılış Stoğu (Girdi)');

      // 2. Devir Girdi
      final devirGirdiExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE $productionItemCheck AND s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%') AND NOT EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%') LIMIT 1",
      );
      if (devirGirdiExists.isNotEmpty) types.add('Devir Girdi');

      // 3. Devir Çıktı
      final devirCiktiExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE $productionItemCheck AND s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%') LIMIT 1",
      );
      if (devirCiktiExists.isNotEmpty) types.add('Devir Çıktı');

      // 4. Sevkiyat
      final sevkiyatExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE $productionItemCheck AND s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NOT NULL LIMIT 1",
      );
      if (sevkiyatExists.isNotEmpty) types.add('Sevkiyat');

      // 5. Üretim Girişi
      final uretimGirdiExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE $productionItemCheck AND EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris') LIMIT 1",
      );
      if (uretimGirdiExists.isNotEmpty) types.add('Üretim Girişi');

      // 6. Üretim Çıkışı
      final uretimCiktiExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE $productionItemCheck AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%') LIMIT 1",
      );
      if (uretimCiktiExists.isNotEmpty) types.add('Üretim Çıkışı');

      // 7. Satış Yapıldı
      final satisExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE $productionItemCheck AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%') LIMIT 1",
      );
      if (satisExists.isNotEmpty) types.add('Satış Yapıldı');

      // 8. Alış Yapıldı
      final alisExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE $productionItemCheck AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%') LIMIT 1",
      );
      if (alisExists.isNotEmpty) types.add('Alış Yapıldı');

      return types;
    } catch (e) {
      debugPrint('Üretim işlem türleri sorgu hatası: $e');
      return [];
    }
  }

  // --- ÜRETİM İŞLEMLERİ ---

  Future<bool> uretimKoduVarMi(String kod, {int? haricId}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    // 1. Productions tablosunda kontrol
    String query1 = 'SELECT 1 FROM productions WHERE kod = @kod';
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

    // 2. Products tablosunda kontrol (Ortak havuz)
    // Üretim kaydederken, herhangi bir ürün kaydıyla çakışma olup olmadığına bakılır.
    const String query2 = 'SELECT 1 FROM products WHERE kod = @kod LIMIT 1';
    final Map<String, dynamic> params2 = {'kod': kod};
    final result2 = await _pool!.execute(
      Sql.named(query2),
      parameters: params2,
    );

    return result2.isNotEmpty;
  }

  Future<List<UretimModel>> uretimleriGetir({
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
    int? lastId, // [2025 OPTIMIZATION] Keyser cursor
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    // Sorting logic
    String sortColumn = 'id';
    switch (sortBy) {
      case 'kod':
        sortColumn = 'productions.kod';
        break;
      case 'ad':
        sortColumn = 'productions.ad';
        break;
      case 'fiyat':
        sortColumn = 'productions.alis_fiyati';
        break;
      case 'satis_fiyati_1':
        sortColumn = 'satis_fiyati_1';
        break;
      case 'stok':
        sortColumn = 'stok';
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
    String direction = sortAscending ? 'ASC' : 'DESC';

    dynamic lastSortValue;
    // [KEYSET PRE-FETCH]
    if (lastId != null && sortColumn != 'id') {
      try {
        final cursorRow = await _pool!.execute(
          Sql.named('SELECT $sortColumn FROM productions WHERE id = @id'),
          parameters: {'id': lastId},
        );
        if (cursorRow.isNotEmpty) {
          lastSortValue = cursorRow.first[0];
        }
      } catch (_) {}
    }

    // Select Clause
    String selectClause = 'SELECT productions.*';

    // 1 Milyar Kayıt Optimisazyonu: Deep Search
    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      selectClause += '''
          , (CASE 
              WHEN (
                search_tags ILIKE @search OR
                ozellikler ILIKE @search OR
                grubu ILIKE @search OR
                barkod ILIKE @search OR
                kullanici ILIKE @search OR
                EXISTS (
                  SELECT 1
                  FROM shipments s
                  LEFT JOIN depots sw ON s.source_warehouse_id = sw.id
                  LEFT JOIN depots dw ON s.dest_warehouse_id = dw.id
                  CROSS JOIN LATERAL jsonb_array_elements(
                    COALESCE(s.items, '[]'::jsonb)
                  ) item
                  WHERE
                    s.items @> jsonb_build_array(
                      jsonb_build_object('code', productions.kod)
                    )
                    AND item->>'code' = productions.kod
                    AND (
                      COALESCE(s.description, '') ILIKE @search OR
                      COALESCE(s.created_by, '') ILIKE @search OR
                      COALESCE(sw.ad, '') ILIKE @search OR
                      COALESCE(dw.ad, '') ILIKE @search OR
                      TO_CHAR(s.date, 'DD.MM.YYYY HH24:MI') ILIKE @search OR
                      TO_CHAR(s.date, 'FMDD.FMMM.YYYY HH24:MI') ILIKE @search OR
                      COALESCE(item->>'quantity', '') ILIKE @search OR
                      COALESCE(item->>'unitCost', '') ILIKE @search OR
                      (CASE
                        WHEN (item->>'unitCost') ~ '^[0-9]+(\\.[0-9]+)?\$' THEN
                          CAST(
                            ROUND(
                              ((item->>'unitCost')::numeric) *
                                  (1 + COALESCE(productions.kdv_orani, 0) / 100.0),
                              2
                            ) AS TEXT
                          )
                        ELSE ''
                      END) ILIKE @search OR
                      (CASE
                        WHEN s.source_warehouse_id IS NULL AND
                            s.dest_warehouse_id IS NOT NULL THEN 'devir girdi'
                        WHEN s.source_warehouse_id IS NOT NULL AND
                            s.dest_warehouse_id IS NULL THEN 'devir çıktı'
                        WHEN s.source_warehouse_id IS NOT NULL AND
                            s.dest_warehouse_id IS NOT NULL THEN 'sevkiyat'
                        ELSE 'işlem'
                      END) ILIKE @search
                    )
                  LIMIT 1
                )
              )
              AND NOT (
                 kod ILIKE @search OR 
                 ad ILIKE @search
              )
              THEN true 
              ELSE false 
             END) as matched_in_hidden
      ''';
    } else {
      selectClause += ', false as matched_in_hidden';
    }

    // Filter conditions
    List<String> whereConditions = [];
    Map<String, dynamic> params = {};

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      whereConditions.add('''
        (
            search_tags ILIKE @search OR
            kod ILIKE @search OR
            ad ILIKE @search OR
            ozellikler ILIKE @search OR
            grubu ILIKE @search OR
            barkod ILIKE @search OR
            kullanici ILIKE @search OR
            EXISTS (
              SELECT 1
              FROM shipments s
              LEFT JOIN depots sw ON s.source_warehouse_id = sw.id
              LEFT JOIN depots dw ON s.dest_warehouse_id = dw.id
              CROSS JOIN LATERAL jsonb_array_elements(
                COALESCE(s.items, '[]'::jsonb)
              ) item
              WHERE
                s.items @> jsonb_build_array(
                  jsonb_build_object('code', productions.kod)
                )
                AND item->>'code' = productions.kod
                AND (
                  COALESCE(s.description, '') ILIKE @search OR
                  COALESCE(s.created_by, '') ILIKE @search OR
                  COALESCE(sw.ad, '') ILIKE @search OR
                  COALESCE(dw.ad, '') ILIKE @search OR
                  TO_CHAR(s.date, 'DD.MM.YYYY HH24:MI') ILIKE @search OR
                  TO_CHAR(s.date, 'FMDD.FMMM.YYYY HH24:MI') ILIKE @search OR
                  COALESCE(item->>'quantity', '') ILIKE @search OR
                  COALESCE(item->>'unitCost', '') ILIKE @search OR
                  (CASE
                    WHEN (item->>'unitCost') ~ '^[0-9]+(\\.[0-9]+)?\$' THEN
                      CAST(
                        ROUND(
                          ((item->>'unitCost')::numeric) *
                              (1 + COALESCE(productions.kdv_orani, 0) / 100.0),
                          2
                        ) AS TEXT
                      )
                    ELSE ''
                  END) ILIKE @search OR
                  (CASE
                    WHEN s.source_warehouse_id IS NULL AND
                        s.dest_warehouse_id IS NOT NULL THEN 'devir girdi'
                    WHEN s.source_warehouse_id IS NOT NULL AND
                        s.dest_warehouse_id IS NULL THEN 'devir çıktı'
                    WHEN s.source_warehouse_id IS NOT NULL AND
                        s.dest_warehouse_id IS NOT NULL THEN 'sevkiyat'
                    ELSE 'işlem'
                  END) ILIKE @search
                )
              LIMIT 1
            )
        )
      ''');
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
    }

    if (aktifMi != null) {
      whereConditions.add('productions.aktif_mi = @aktifMi');
      params['aktifMi'] = aktifMi ? 1 : 0;
    }

    if (grup != null) {
      whereConditions.add('productions.grubu = @grup');
      params['grup'] = grup;
    }

    if (birim != null) {
      whereConditions.add('productions.birim = @birim');
      params['birim'] = birim;
    }

    if (kdvOrani != null) {
      whereConditions.add('productions.kdv_orani = @kdvOrani');
      params['kdvOrani'] = kdvOrani;
    }

    final bool useShipmentBasedMovementFilter =
        (islemTuru != null && islemTuru.trim().isNotEmpty) ||
        (kullanici != null && kullanici.trim().isNotEmpty);

    if (useShipmentBasedMovementFilter) {
      String existsQuery = '''
        EXISTS (
          SELECT 1 FROM shipments s
          WHERE s.items @> jsonb_build_array(
            jsonb_build_object('code', productions.kod)
          )
      ''';

      if (baslangicTarihi != null) {
        existsQuery += ' AND s.date >= @startDate';
        params['startDate'] = baslangicTarihi.toIso8601String();
      }

      if (bitisTarihi != null) {
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
        existsQuery += ' AND s.date <= @endDate';
        params['endDate'] = endOfDay.toIso8601String();
      }

      if (depoIds != null && depoIds.isNotEmpty) {
        existsQuery +=
            ' AND (s.source_warehouse_id = ANY(@depoIdArray) OR s.dest_warehouse_id = ANY(@depoIdArray))';
        params['depoIdArray'] = depoIds;
      }

      if (kullanici != null && kullanici.trim().isNotEmpty) {
        existsQuery += ' AND COALESCE(s.created_by, \'\') = @shipmentUser';
        params['shipmentUser'] = kullanici.trim();
      }

      if (islemTuru != null && islemTuru.trim().isNotEmpty) {
        switch (islemTuru.trim()) {
          case 'Açılış Stoğu (Girdi)':
            existsQuery +=
                " AND s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%')";
            break;
          case 'Devir Girdi':
          case 'Devir (Girdi)':
            existsQuery +=
                " AND s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%') AND NOT EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
            break;
          case 'Devir Çıktı':
          case 'Devir (Çıktı)':
            existsQuery +=
                " AND s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
            break;
          case 'Sevkiyat':
          case 'Transfer':
            existsQuery +=
                ' AND s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NOT NULL';
            break;
          case 'Satış Yapıldı':
          case 'Satış Faturası':
            existsQuery +=
                " AND s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
            break;
          case 'Alış Yapıldı':
          case 'Alış Faturası':
            existsQuery +=
                " AND s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
            break;
          case 'Üretim Girişi':
          case 'Üretim (Girdi)':
            existsQuery +=
                " AND EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris')";
            break;
          case 'Üretim Çıkışı':
          case 'Üretim (Çıktı)':
            existsQuery +=
                " AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%')";
            break;
        }
      }

      existsQuery += ')';
      whereConditions.add(existsQuery);
    } else {
      if (baslangicTarihi != null || bitisTarihi != null) {
        String existsQuery = '''
          EXISTS (
            SELECT 1 FROM production_stock_movements psm
            WHERE psm.production_id = productions.id
        ''';

        if (baslangicTarihi != null) {
          existsQuery += ' AND psm.movement_date >= @startDate';
          params['startDate'] = baslangicTarihi.toIso8601String();
        }
        if (bitisTarihi != null) {
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
          existsQuery += ' AND psm.movement_date <= @endDate';
          params['endDate'] = endOfDay.toIso8601String();
        }

        existsQuery += ')';
        whereConditions.add(existsQuery);
      }

      if (depoIds != null && depoIds.isNotEmpty) {
        whereConditions.add('''
          EXISTS (
            SELECT 1 FROM production_stock_movements psm_depo
            WHERE psm_depo.production_id = productions.id
            AND psm_depo.warehouse_id = ANY(@depoIdArray)
          )
        ''');
        params['depoIdArray'] = depoIds;
      }
    }

    // [KEYSET FILTER]
    if (lastId != null) {
      if (sortColumn == 'id') {
        if (direction == 'ASC') {
          whereConditions.add('id > @lastId');
        } else {
          whereConditions.add('id < @lastId');
        }
        params['lastId'] = lastId;
      } else {
        String op = direction == 'ASC' ? '>' : '<';
        if (lastSortValue == null) {
          if (direction == 'ASC') {
            whereConditions.add(
              '($sortColumn IS NULL OR ($sortColumn, id) $op (@lastSortVal, @lastId))',
            );
          } else {
            whereConditions.add(
              '($sortColumn IS NOT NULL AND ($sortColumn, id) $op (@lastSortVal, @lastId))',
            );
          }
        } else {
          whereConditions.add('($sortColumn, id) $op (@lastSortVal, @lastId)');
        }
        params['lastId'] = lastId;
        params['lastSortVal'] = lastSortValue ?? '';
      }
    }

    String whereClause = '';
    if (whereConditions.isNotEmpty) {
      whereClause = 'WHERE ${whereConditions.join(' AND ')}';
    }

    String query;
    bool useKeyset = lastId != null;

    if (useKeyset) {
      // Keyset Fast Path
      query =
          '''
          $selectClause
          FROM productions
          $whereClause
          ORDER BY $sortColumn $direction, productions.id ASC
          LIMIT @limit
       ''';
    } else {
      // Offset Deferred Join Path
      String indexQuery =
          '''
        SELECT DISTINCT ON ($sortColumn, productions.id) productions.id 
        FROM productions 
        $whereClause
        ORDER BY $sortColumn $direction, productions.id ASC
        LIMIT @limit OFFSET @offset
       ''';

      query =
          '''
        $selectClause
        FROM productions
        JOIN ($indexQuery) as t ON productions.id = t.id
        ORDER BY $sortColumn $direction, productions.id ASC
       ''';
      params['offset'] = (sayfa - 1) * sayfaBasinaKayit;
    }

    params['limit'] = sayfaBasinaKayit;

    final result = await _pool!.execute(Sql.named(query), parameters: params);

    final List<Map<String, dynamic>> dataList = result
        .map((row) {
          final map = row.toColumnMap();
          _makeIsolateSafeMapInPlace(map);
          return map;
        })
        .toList(growable: false);

    try {
      return await compute(_parseUretimlerIsolate, dataList);
    } catch (e) {
      debugPrint(
        'UretimlerVeritabaniServisi: Isolate parse başarısız, fallback devrede: $e',
      );
      return dataList.map(UretimModel.fromMap).toList(growable: false);
    }
  }

  Future<int> uretimSayisiGetir({
    String? aramaTerimi,
    bool? aktifMi,
    String? grup,
    String? birim,
    double? kdvOrani,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    List<int>? depoIds, // Parametre eklendi
    String? islemTuru,
    String? kullanici,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;

    String query = 'SELECT COUNT(*) FROM productions';
    Map<String, dynamic> params = {};
    List<String> whereConditions = [];

    // 1 Milyar Kayıt Optimisazyonu: Hızlı Sayım (Metadata Based Count)
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
        "SELECT row_count FROM table_counts WHERE table_name = 'productions'",
      );
      if (countResult.isNotEmpty) {
        return (countResult.first[0] as int?) ?? 0;
      }
    }

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      whereConditions.add('''
        (
          search_tags ILIKE @search OR
          kod ILIKE @search OR
          ad ILIKE @search OR
          ozellikler ILIKE @search OR
          grubu ILIKE @search OR
          barkod ILIKE @search OR
          kullanici ILIKE @search OR
          EXISTS (
            SELECT 1
            FROM shipments s
            LEFT JOIN depots sw ON s.source_warehouse_id = sw.id
            LEFT JOIN depots dw ON s.dest_warehouse_id = dw.id
            CROSS JOIN LATERAL jsonb_array_elements(
              COALESCE(s.items, '[]'::jsonb)
            ) item
            WHERE
              s.items @> jsonb_build_array(
                jsonb_build_object('code', productions.kod)
              )
              AND item->>'code' = productions.kod
              AND (
                COALESCE(s.description, '') ILIKE @search OR
                COALESCE(s.created_by, '') ILIKE @search OR
                COALESCE(sw.ad, '') ILIKE @search OR
                COALESCE(dw.ad, '') ILIKE @search OR
                TO_CHAR(s.date, 'DD.MM.YYYY HH24:MI') ILIKE @search OR
                TO_CHAR(s.date, 'FMDD.FMMM.YYYY HH24:MI') ILIKE @search OR
                TO_CHAR(s.date, 'DD.MM') ILIKE @search OR
                TO_CHAR(s.date, 'HH24:MI') ILIKE @search OR
                COALESCE(item->>'quantity', '') ILIKE @search OR
                COALESCE(item->>'unitCost', '') ILIKE @search OR
                (CASE
                  WHEN (item->>'unitCost') ~ '^[0-9]+(\\.[0-9]+)?\$' THEN
                    CAST(
                      ROUND(
                        ((item->>'unitCost')::numeric) *
                            (1 + COALESCE(productions.kdv_orani, 0) / 100.0),
                        2
                      ) AS TEXT
                    )
                  ELSE ''
                END) ILIKE @search OR
                (CASE
                  WHEN s.source_warehouse_id IS NULL AND
                      s.dest_warehouse_id IS NOT NULL THEN 'devir girdi'
                  WHEN s.source_warehouse_id IS NOT NULL AND
                      s.dest_warehouse_id IS NULL THEN 'devir çıktı'
                  WHEN s.source_warehouse_id IS NOT NULL AND
                      s.dest_warehouse_id IS NOT NULL THEN 'sevkiyat'
                  ELSE 'işlem'
                END) ILIKE @search
              )
            LIMIT 1
          )
        )
      ''');
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
    }

    if (aktifMi != null) {
      whereConditions.add('productions.aktif_mi = @aktifMi');
      params['aktifMi'] = aktifMi ? 1 : 0;
    }

    if (grup != null) {
      whereConditions.add('productions.grubu = @grup');
      params['grup'] = grup;
    }

    if (birim != null) {
      whereConditions.add('productions.birim = @birim');
      params['birim'] = birim;
    }

    if (kdvOrani != null) {
      whereConditions.add('productions.kdv_orani = @kdvOrani');
      params['kdvOrani'] = kdvOrani;
    }

    final bool useShipmentBasedMovementFilter =
        (islemTuru != null && islemTuru.trim().isNotEmpty) ||
        (kullanici != null && kullanici.trim().isNotEmpty);

    if (useShipmentBasedMovementFilter) {
      String existsQuery = '''
        EXISTS (
          SELECT 1 FROM shipments s
          WHERE s.items @> jsonb_build_array(
            jsonb_build_object('code', productions.kod)
          )
      ''';

      if (baslangicTarihi != null) {
        existsQuery += ' AND s.date >= @startDate';
        params['startDate'] = baslangicTarihi.toIso8601String();
      }

      if (bitisTarihi != null) {
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
        existsQuery += ' AND s.date <= @endDate';
        params['endDate'] = endOfDay.toIso8601String();
      }

      if (depoIds != null && depoIds.isNotEmpty) {
        existsQuery +=
            ' AND (s.source_warehouse_id = ANY(@depoIdArray) OR s.dest_warehouse_id = ANY(@depoIdArray))';
        params['depoIdArray'] = depoIds;
      }

      if (kullanici != null && kullanici.trim().isNotEmpty) {
        existsQuery += ' AND COALESCE(s.created_by, \'\') = @shipmentUser';
        params['shipmentUser'] = kullanici.trim();
      }

      if (islemTuru != null && islemTuru.trim().isNotEmpty) {
        switch (islemTuru.trim()) {
          case 'Açılış Stoğu (Girdi)':
            existsQuery +=
                " AND s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%')";
            break;
          case 'Devir Girdi':
          case 'Devir (Girdi)':
            existsQuery +=
                " AND s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%') AND NOT EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
            break;
          case 'Devir Çıktı':
          case 'Devir (Çıktı)':
            existsQuery +=
                " AND s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
            break;
          case 'Sevkiyat':
          case 'Transfer':
            existsQuery +=
                ' AND s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NOT NULL';
            break;
          case 'Satış Yapıldı':
          case 'Satış Faturası':
            existsQuery +=
                " AND s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
            break;
          case 'Alış Yapıldı':
          case 'Alış Faturası':
            existsQuery +=
                " AND s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
            break;
          case 'Üretim Girişi':
          case 'Üretim (Girdi)':
            existsQuery +=
                " AND EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris')";
            break;
          case 'Üretim Çıkışı':
          case 'Üretim (Çıktı)':
            existsQuery +=
                " AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%')";
            break;
        }
      }

      existsQuery += ')';
      whereConditions.add(existsQuery);
    } else {
      // Tarih Filtresi (Aynı mantık)
      if (baslangicTarihi != null || bitisTarihi != null) {
        String existsQuery = '''
          EXISTS (
            SELECT 1 FROM production_stock_movements psm
            WHERE psm.production_id = productions.id
        ''';

        if (baslangicTarihi != null) {
          existsQuery += ' AND psm.movement_date >= @startDate';
          params['startDate'] = baslangicTarihi.toIso8601String();
        }
        if (bitisTarihi != null) {
          // Count için end date inclusive
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
          existsQuery += ' AND psm.movement_date <= @endDate';
          params['endDate'] = endOfDay.toIso8601String();
        }

        existsQuery += ')';
        whereConditions.add(existsQuery);
      }

      // Depo Filtresi (Count için de ekle)
      if (depoIds != null && depoIds.isNotEmpty) {
        whereConditions.add('''
          EXISTS (
            SELECT 1 FROM production_stock_movements psm_depo
            WHERE psm_depo.production_id = productions.id
            AND psm_depo.warehouse_id = ANY(@depoIdArray)
          )
        ''');
        params['depoIdArray'] = depoIds;
      }
    }

    if (whereConditions.isNotEmpty) {
      query += ' WHERE ${whereConditions.join(' AND ')}';

      // 🚀 ESTIMATE COUNT OPTIMIZATION
      try {
        String filterQueryForPlan = 'SELECT 1 FROM productions';
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
        "SELECT reltuples::bigint AS estimate FROM pg_class WHERE relname = 'productions'",
      );
      if (estimateResult.isNotEmpty && estimateResult[0][0] != null) {
        final estimate = estimateResult[0][0] as int;
        if (estimate > 0) return estimate;
      }
    }

    // [2025 CAPPED EXACT COUNT]
    if (!query.contains('LIMIT')) {
      String cappedBase = query.replaceFirst(
        'SELECT COUNT(*) FROM productions',
        'SELECT 1 FROM productions',
      );
      cappedBase += ' LIMIT 100001';

      final cappedQuery = 'SELECT COUNT(*) FROM ($cappedBase) AS sub';

      final result = await _pool!.execute(
        Sql.named(cappedQuery),
        parameters: params,
      );
      return (result[0][0] as int);
    }

    final result = await _pool!.execute(Sql.named(query), parameters: params);
    return result[0][0] as int;
  }

  Future<Map<String, Map<String, int>>> uretimFiltreIstatistikleriniGetir({
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

    const int cappedLimit = 100001;
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

    DateTime? endOfDay(DateTime? d) {
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
    }

    String buildWhere(List<String> conds) {
      return conds.isEmpty ? '' : 'WHERE ${conds.join(' AND ')}';
    }

    void addProductionConds(
      List<String> conds,
      Map<String, dynamic> params, {
      String? q,
      bool? aktif,
      String? g,
      String? u,
      double? vat,
    }) {
      final String? trimmedQ = q?.trim();
      if (trimmedQ != null && trimmedQ.isNotEmpty) {
        conds.add('productions.search_tags ILIKE @search');
        params['search'] = '%${trimmedQ.toLowerCase()}%';
      }

      if (aktif != null) {
        conds.add('productions.aktif_mi = @aktifMi');
        params['aktifMi'] = aktif ? 1 : 0;
      }

      final String? trimmedGroup = g?.trim();
      if (trimmedGroup != null && trimmedGroup.isNotEmpty) {
        conds.add('productions.grubu = @grup');
        params['grup'] = trimmedGroup;
      }

      final String? trimmedUnit = u?.trim();
      if (trimmedUnit != null && trimmedUnit.isNotEmpty) {
        conds.add('productions.birim = @birim');
        params['birim'] = trimmedUnit;
      }

      if (vat != null) {
        conds.add('productions.kdv_orani = @kdvOrani');
        params['kdvOrani'] = vat;
      }
    }

    String? buildShipmentTypeCondition(String? t) {
      final String? trimmedType = t?.trim();
      if (trimmedType == null || trimmedType.isEmpty) return null;

      switch (trimmedType) {
        case 'Açılış Stoğu (Girdi)':
        case 'Açılış Stoğu':
          return "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%')";
        case 'Devir Girdi':
        case 'Devir (Girdi)':
          return "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%') AND NOT EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
        case 'Devir Çıktı':
        case 'Devir (Çıktı)':
          return "s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
        case 'Sevkiyat':
        case 'Transfer':
          return 's.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NOT NULL';
        case 'Üretim Girişi':
        case 'Üretim (Girdi)':
          return "EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris')";
        case 'Üretim Çıkışı':
        case 'Üretim (Çıktı)':
          return "(EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%')";
        case 'Satış Yapıldı':
        case 'Satış Faturası':
          return "s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
        case 'Alış Yapıldı':
        case 'Alış Faturası':
          return "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
      }

      return null;
    }

    void addMovementConds(
      List<String> conds,
      Map<String, dynamic> params, {
      required bool useShipments,
      DateTime? start,
      DateTime? end,
      List<int>? depolar,
      String? type,
      String? user,
    }) {
      if (useShipments) {
        final String? trimmedUser = user?.trim();
        final String? trimmedType = type?.trim();

        if (start == null &&
            end == null &&
            (depolar == null || depolar.isEmpty) &&
            (trimmedUser == null || trimmedUser.isEmpty) &&
            (trimmedType == null || trimmedType.isEmpty)) {
          return;
        }

        final List<String> shipmentConds = [
          's.items @> jsonb_build_array(jsonb_build_object(\'code\', productions.kod))',
        ];

        if (start != null) {
          shipmentConds.add('s.date >= @startDate');
          params['startDate'] = start.toIso8601String();
        }

        if (end != null) {
          shipmentConds.add('s.date <= @endDate');
          params['endDate'] = endOfDay(end)!.toIso8601String();
        }

        if (depolar != null && depolar.isNotEmpty) {
          shipmentConds.add(
            '(s.source_warehouse_id = ANY(@depoIdArray) OR s.dest_warehouse_id = ANY(@depoIdArray))',
          );
          params['depoIdArray'] = depolar;
        }

        if (trimmedUser != null && trimmedUser.isNotEmpty) {
          shipmentConds.add("COALESCE(s.created_by, '') = @shipmentUser");
          params['shipmentUser'] = trimmedUser;
        }

        if (trimmedType != null && trimmedType.isNotEmpty) {
          final tc = buildShipmentTypeCondition(trimmedType);
          if (tc != null && tc.isNotEmpty) {
            shipmentConds.add(tc);
          }
        }

        conds.add('''
          EXISTS (
            SELECT 1 FROM shipments s
            WHERE ${shipmentConds.join(' AND ')}
          )
        ''');
        return;
      }

      // Tarih (production_stock_movements)
      if (start != null || end != null) {
        final List<String> psmConds = ['psm.production_id = productions.id'];
        if (start != null) {
          psmConds.add('psm.movement_date >= @startDate');
          params['startDate'] = start.toIso8601String();
        }
        if (end != null) {
          psmConds.add('psm.movement_date <= @endDate');
          params['endDate'] = endOfDay(end)!.toIso8601String();
        }
        conds.add('''
          EXISTS (
            SELECT 1 FROM production_stock_movements psm
            WHERE ${psmConds.join(' AND ')}
          )
        ''');
      }

      // Depo (production_stock_movements) - tarih filtresiyle bağımsız (mevcut davranış)
      if (depolar != null && depolar.isNotEmpty) {
        conds.add('''
          EXISTS (
            SELECT 1 FROM production_stock_movements psm_depo
            WHERE psm_depo.production_id = productions.id
              AND psm_depo.warehouse_id = ANY(@depoIdArray)
          )
        ''');
        params['depoIdArray'] = depolar;
      }
    }

    // [GENEL TOPLAM] Cari ile aynı mantık: sadece arama + tarih (diğer facetler hariç)
    final int genelToplam = await uretimSayisiGetir(
      aramaTerimi: aramaTerimi,
      baslangicTarihi: baslangicTarihi,
      bitisTarihi: bitisTarihi,
    );

    final bool useShipmentBasedMovementFilter =
        (islemTuru != null && islemTuru.trim().isNotEmpty) ||
        (kullanici != null && kullanici.trim().isNotEmpty);

    // 1) Durum facet
    final statusParams = <String, dynamic>{};
    final statusConds = <String>[];
    addProductionConds(
      statusConds,
      statusParams,
      q: aramaTerimi,
      aktif: null,
      g: grup,
      u: birim,
      vat: kdvOrani,
    );
    addMovementConds(
      statusConds,
      statusParams,
      useShipments: useShipmentBasedMovementFilter,
      start: baslangicTarihi,
      end: bitisTarihi,
      depolar: depoIds,
      type: islemTuru,
      user: kullanici,
    );
    final statusQuery =
        '''
      SELECT aktif_mi, COUNT(*) FROM (
        SELECT productions.aktif_mi
        FROM productions
        ${buildWhere(statusConds)}
        LIMIT $cappedLimit
      ) as sub
      GROUP BY aktif_mi
    ''';

    // 2) Grup facet
    final groupParams = <String, dynamic>{};
    final groupConds = <String>[];
    addProductionConds(
      groupConds,
      groupParams,
      q: aramaTerimi,
      aktif: aktifMi,
      g: null,
      u: birim,
      vat: kdvOrani,
    );
    addMovementConds(
      groupConds,
      groupParams,
      useShipments: useShipmentBasedMovementFilter,
      start: baslangicTarihi,
      end: bitisTarihi,
      depolar: depoIds,
      type: islemTuru,
      user: kullanici,
    );
    final groupQuery =
        '''
      SELECT grubu, COUNT(*) FROM (
        SELECT COALESCE(productions.grubu, '') as grubu
        FROM productions
        ${buildWhere(groupConds)}
        LIMIT $cappedLimit
      ) as sub
      GROUP BY grubu
    ''';

    // 3) Birim facet
    final unitParams = <String, dynamic>{};
    final unitConds = <String>[];
    addProductionConds(
      unitConds,
      unitParams,
      q: aramaTerimi,
      aktif: aktifMi,
      g: grup,
      u: null,
      vat: kdvOrani,
    );
    addMovementConds(
      unitConds,
      unitParams,
      useShipments: useShipmentBasedMovementFilter,
      start: baslangicTarihi,
      end: bitisTarihi,
      depolar: depoIds,
      type: islemTuru,
      user: kullanici,
    );
    final unitQuery =
        '''
      SELECT birim, COUNT(*) FROM (
        SELECT COALESCE(productions.birim, '') as birim
        FROM productions
        ${buildWhere(unitConds)}
        LIMIT $cappedLimit
      ) as sub
      GROUP BY birim
    ''';

    // 4) KDV facet
    final vatParams = <String, dynamic>{};
    final vatConds = <String>[];
    addProductionConds(
      vatConds,
      vatParams,
      q: aramaTerimi,
      aktif: aktifMi,
      g: grup,
      u: birim,
      vat: null,
    );
    addMovementConds(
      vatConds,
      vatParams,
      useShipments: useShipmentBasedMovementFilter,
      start: baslangicTarihi,
      end: bitisTarihi,
      depolar: depoIds,
      type: islemTuru,
      user: kullanici,
    );
    final vatQuery =
        '''
      SELECT kdv, COUNT(*) FROM (
        SELECT COALESCE(CAST(productions.kdv_orani AS TEXT), '') as kdv
        FROM productions
        ${buildWhere(vatConds)}
        LIMIT $cappedLimit
      ) as sub
      GROUP BY kdv
    ''';

    // 5) Depo facet
    final warehouseParams = <String, dynamic>{};
    late final String warehouseQuery;
    if (useShipmentBasedMovementFilter) {
      final warehouseConds = <String>[];
      addProductionConds(
        warehouseConds,
        warehouseParams,
        q: aramaTerimi,
        aktif: aktifMi,
        g: grup,
        u: birim,
        vat: kdvOrani,
      );

      final shipmentConds = <String>[
        's.items @> jsonb_build_array(jsonb_build_object(\'code\', productions.kod))',
      ];

      if (baslangicTarihi != null) {
        shipmentConds.add('s.date >= @startDate');
        warehouseParams['startDate'] = baslangicTarihi.toIso8601String();
      }
      if (bitisTarihi != null) {
        shipmentConds.add('s.date <= @endDate');
        warehouseParams['endDate'] = endOfDay(bitisTarihi)!.toIso8601String();
      }

      final String? trimmedUser = kullanici?.trim();
      if (trimmedUser != null && trimmedUser.isNotEmpty) {
        shipmentConds.add("COALESCE(s.created_by, '') = @shipmentUser");
        warehouseParams['shipmentUser'] = trimmedUser;
      }

      final String? trimmedType = islemTuru?.trim();
      if (trimmedType != null && trimmedType.isNotEmpty) {
        final tc = buildShipmentTypeCondition(trimmedType);
        if (tc != null && tc.isNotEmpty) shipmentConds.add(tc);
      }

      final String whereProd = warehouseConds.isEmpty
          ? ''
          : 'AND ${warehouseConds.join(' AND ')}';
      final String whereShip = shipmentConds.join(' AND ');

      warehouseQuery =
          '''
        SELECT warehouse_id, COUNT(DISTINCT production_id) FROM (
          SELECT s.source_warehouse_id as warehouse_id, productions.id as production_id
          FROM productions
          JOIN shipments s ON s.items @> jsonb_build_array(jsonb_build_object('code', productions.kod))
          WHERE s.source_warehouse_id IS NOT NULL
          $whereProd
          AND $whereShip
          UNION ALL
          SELECT s.dest_warehouse_id as warehouse_id, productions.id as production_id
          FROM productions
          JOIN shipments s ON s.items @> jsonb_build_array(jsonb_build_object('code', productions.kod))
          WHERE s.dest_warehouse_id IS NOT NULL
          $whereProd
          AND $whereShip
        ) t
        GROUP BY warehouse_id
      ''';
    } else {
      final warehouseConds = <String>[];
      addProductionConds(
        warehouseConds,
        warehouseParams,
        q: aramaTerimi,
        aktif: aktifMi,
        g: grup,
        u: birim,
        vat: kdvOrani,
      );

      if (baslangicTarihi != null || bitisTarihi != null) {
        final psmConds = <String>['psm.production_id = productions.id'];
        if (baslangicTarihi != null) {
          psmConds.add('psm.movement_date >= @startDate');
          warehouseParams['startDate'] = baslangicTarihi.toIso8601String();
        }
        if (bitisTarihi != null) {
          psmConds.add('psm.movement_date <= @endDate');
          warehouseParams['endDate'] = endOfDay(bitisTarihi)!.toIso8601String();
        }
        warehouseConds.add('''
          EXISTS (
            SELECT 1 FROM production_stock_movements psm
            WHERE ${psmConds.join(' AND ')}
          )
        ''');
      }

      warehouseQuery =
          '''
        SELECT psm_depo.warehouse_id, COUNT(DISTINCT productions.id)
        FROM productions
        JOIN production_stock_movements psm_depo ON psm_depo.production_id = productions.id
        ${warehouseConds.isNotEmpty ? 'WHERE ${warehouseConds.join(' AND ')}' : ''}
        GROUP BY psm_depo.warehouse_id
      ''';
    }

    // 6) Kullanıcı facet (shipments.created_by) - seçili kullanıcı hariç
    final userParams = <String, dynamic>{};
    final userConds = <String>[];
    addProductionConds(
      userConds,
      userParams,
      q: aramaTerimi,
      aktif: aktifMi,
      g: grup,
      u: birim,
      vat: kdvOrani,
    );

    // Kullanıcı facet her zaman shipments üzerinden çalışır (kullanıcı seçimi shipments'e ait)
    final shipmentUserConds = <String>[
      's.items @> jsonb_build_array(jsonb_build_object(\'code\', productions.kod))',
    ];
    if (baslangicTarihi != null) {
      shipmentUserConds.add('s.date >= @startDate');
      userParams['startDate'] = baslangicTarihi.toIso8601String();
    }
    if (bitisTarihi != null) {
      shipmentUserConds.add('s.date <= @endDate');
      userParams['endDate'] = endOfDay(bitisTarihi)!.toIso8601String();
    }
    if (depoIds != null && depoIds.isNotEmpty) {
      shipmentUserConds.add(
        '(s.source_warehouse_id = ANY(@depoIdArray) OR s.dest_warehouse_id = ANY(@depoIdArray))',
      );
      userParams['depoIdArray'] = depoIds;
    }
    final String? trimmedSelectedType = islemTuru?.trim();
    if (trimmedSelectedType != null && trimmedSelectedType.isNotEmpty) {
      final tc = buildShipmentTypeCondition(trimmedSelectedType);
      if (tc != null && tc.isNotEmpty) shipmentUserConds.add(tc);
    }

    final String whereUserProd = userConds.isEmpty
        ? ''
        : 'AND ${userConds.join(' AND ')}';
    final String whereUserShip = shipmentUserConds.join(' AND ');

    final userQuery =
        '''
      SELECT COALESCE(s.created_by, '') as kullanici, COUNT(DISTINCT productions.id)
      FROM productions
      JOIN shipments s ON s.items @> jsonb_build_array(jsonb_build_object('code', productions.kod))
      WHERE $whereUserShip
      $whereUserProd
      GROUP BY 1
    ''';

    // 7) İşlem türü facet (her tip için üretim sayısı) - seçili işlem türü hariç, kullanıcı dahil
    Future<int> countForType(String t) async {
      final typeParams = <String, dynamic>{};
      final typeConds = <String>[];
      addProductionConds(
        typeConds,
        typeParams,
        q: aramaTerimi,
        aktif: aktifMi,
        g: grup,
        u: birim,
        vat: kdvOrani,
      );

      final List<String> shipConds = [
        's.items @> jsonb_build_array(jsonb_build_object(\'code\', productions.kod))',
      ];
      if (baslangicTarihi != null) {
        shipConds.add('s.date >= @startDate');
        typeParams['startDate'] = baslangicTarihi.toIso8601String();
      }
      if (bitisTarihi != null) {
        shipConds.add('s.date <= @endDate');
        typeParams['endDate'] = endOfDay(bitisTarihi)!.toIso8601String();
      }
      if (depoIds != null && depoIds.isNotEmpty) {
        shipConds.add(
          '(s.source_warehouse_id = ANY(@depoIdArray) OR s.dest_warehouse_id = ANY(@depoIdArray))',
        );
        typeParams['depoIdArray'] = depoIds;
      }
      final String? trimmedUser = kullanici?.trim();
      if (trimmedUser != null && trimmedUser.isNotEmpty) {
        shipConds.add("COALESCE(s.created_by, '') = @shipmentUser");
        typeParams['shipmentUser'] = trimmedUser;
      }
      final tc = buildShipmentTypeCondition(t);
      if (tc != null && tc.isNotEmpty) shipConds.add(tc);

      final String whereShip = shipConds.join(' AND ');

      typeConds.add('''
        EXISTS (
          SELECT 1 FROM shipments s
          WHERE $whereShip
        )
      ''');

      final res = await _pool!.execute(
        Sql.named('''
          SELECT COUNT(*) FROM (
            SELECT productions.id
            FROM productions
            ${buildWhere(typeConds)}
            LIMIT $cappedLimit
          ) sub
        '''),
        parameters: typeParams,
      );
      return res.isEmpty ? 0 : (res.first[0] as int);
    }

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
      debugPrint('Üretim filtre istatistikleri hatası: $e');
      return {
        'ozet': {'toplam': genelToplam},
      };
    }
  }

  // --- YARDIMCI VERİLER (CACHE TABLOSUNDAN) ---

  Future<List<String>> uretimGruplariniGetir() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    final result = await _pool!.execute(
      "SELECT value FROM production_metadata WHERE type = 'group' ORDER BY value ASC",
    );
    return result.map((row) => row[0] as String).toList();
  }

  Future<List<String>> uretimBirimleriniGetir() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    final result = await _pool!.execute(
      "SELECT value FROM production_metadata WHERE type = 'unit' ORDER BY value ASC",
    );
    return result.map((row) => row[0] as String).toList();
  }

  Future<List<double>> uretimKdvOranlariniGetir() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    final result = await _pool!.execute(
      "SELECT value FROM production_metadata WHERE type = 'vat' ORDER BY value ASC",
    );
    return result
        .map((row) => double.tryParse(row[0] as String) ?? 0.0)
        .toList();
  }

  Future<int> uretimEkle(
    UretimModel uretim, {
    int? initialStockWarehouseId,
    double? initialStockUnitCost,
    String? createdBy,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;

    final currentUser = createdBy ?? await _getCurrentUser();
    final map = uretim.toMap();
    map.remove('id');
    map['created_by'] = currentUser;
    map['created_at'] = DateTime.now();

    // Sequence Update (Eğer numerik ise sayacı güncelle)
    final codeSeqVal = _extractTrailingNumber(uretim.kod);
    if (codeSeqVal != null) {
      await _pool!.execute(
        Sql.named(
          "INSERT INTO sequences (name, current_value) VALUES ('product_code', @val) ON CONFLICT (name) DO UPDATE SET current_value = GREATEST(sequences.current_value, @val)",
        ),
        parameters: {'val': codeSeqVal},
      );
    }
    final barcodeSeqVal = _extractTrailingNumber(uretim.barkod);
    if (barcodeSeqVal != null) {
      await _pool!.execute(
        Sql.named(
          "INSERT INTO sequences (name, current_value) VALUES ('production_barcode', @val) ON CONFLICT (name) DO UPDATE SET current_value = GREATEST(sequences.current_value, @val)",
        ),
        parameters: {'val': barcodeSeqVal},
      );
    }
    map['created_at'] = DateTime.now();
    map['resimler'] = jsonEncode(uretim.resimler);

    // Search Tags Oluşturma (Denormalization)
    final searchTags = [
      uretim.kod,
      uretim.ad,
      uretim.barkod,
      uretim.grubu,
      uretim.kullanici,
      uretim.ozellikler,
      uretim.birim,
      uretim.id.toString(),
      uretim.alisFiyati.toString(),
      uretim.satisFiyati1.toString(),
      uretim.satisFiyati2.toString(),
      uretim.satisFiyati3.toString(),
      uretim.erkenUyariMiktari.toString(),
      uretim.stok.toString(),
      uretim.kdvOrani.toString(),
      uretim.aktifMi ? 'aktif' : 'pasif',
      createdBy ?? currentUser,
    ].where((e) => e.toString().trim().isNotEmpty).join(' ').toLowerCase();

    map['search_tags'] = searchTags;

    final result = await _pool!.execute(
      Sql.named('''
        INSERT INTO productions (
          kod, ad, birim, alis_fiyati, satis_fiyati_1, satis_fiyati_2, satis_fiyati_3,
          kdv_orani, stok, erken_uyari_miktari, grubu, ozellikler, barkod, kullanici,
          resim_url, resimler, aktif_mi, created_by, created_at, search_tags
        )
        VALUES (
          @kod, @ad, @birim, @alis_fiyati, @satis_fiyati_1, @satis_fiyati_2, @satis_fiyati_3,
          @kdv_orani, @stok, @erken_uyari_miktari, @grubu, @ozellikler, @barkod, @kullanici,
          @resim_url, @resimler, @aktif_mi, @created_by, @created_at, @search_tags
        )
        RETURNING id
      '''),
      parameters: map,
    );

    final newId = result[0][0] as int;

    // Açılış Stoğu İşlemi
    if (uretim.stok > 0 && initialStockWarehouseId != null) {
      try {
        await DepolarVeritabaniServisi().sevkiyatEkle(
          sourceId: null,
          destId: initialStockWarehouseId,
          date: DateTime.now(),
          description: '',
          items: [
            ShipmentItem(
              code: uretim.kod,
              name: uretim.ad,
              unit: uretim.birim,
              quantity: uretim.stok,
              unitCost: initialStockUnitCost,
            ),
          ],
          updateStock: false,
          createdBy: currentUser,
          integrationRef: 'opening_stock',
        );
      } catch (e) {
        debugPrint('Açılış stoğu oluşturulurken hata: $e');
      }
    }

    return newId;
  }

  Future<void> uretimGuncelle(UretimModel uretim) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final map = uretim.toMap();
    map.remove('created_by');
    map.remove('created_at');
    map['resimler'] = jsonEncode(uretim.resimler);

    // Search Tags Güncelleme (Full Spectrum)
    final searchTags = [
      uretim.kod,
      uretim.ad,
      uretim.barkod,
      uretim.grubu,
      uretim.kullanici,
      uretim.ozellikler,
      uretim.birim,
      uretim.id.toString(),
      uretim.alisFiyati.toString(),
      uretim.satisFiyati1.toString(),
      uretim.satisFiyati2.toString(),
      uretim.satisFiyati3.toString(),
      uretim.erkenUyariMiktari.toString(),
      uretim.stok.toString(),
      uretim.kdvOrani.toString(),
      uretim.aktifMi ? 'aktif' : 'pasif',
    ].where((e) => e.toString().trim().isNotEmpty).join(' ').toLowerCase();

    map['search_tags'] = searchTags;

    await _pool!.execute(
      Sql.named('''
        UPDATE productions SET 
        kod=@kod, ad=@ad, birim=@birim, alis_fiyati=@alis_fiyati, 
        satis_fiyati_1=@satis_fiyati_1, satis_fiyati_2=@satis_fiyati_2, satis_fiyati_3=@satis_fiyati_3,
        kdv_orani=@kdv_orani, stok=@stok, erken_uyari_miktari=@erken_uyari_miktari,
        grubu=@grubu, ozellikler=@ozellikler, barkod=@barkod, kullanici=@kullanici,
        resim_url=@resim_url, resimler=@resimler, aktif_mi=@aktif_mi, search_tags=@search_tags
        WHERE id=@id
      '''),
      parameters: map,
    );
  }

  Future<void> topluUretimSil(List<int> ids) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;
    if (ids.isEmpty) return;

    await _pool!.execute(
      Sql.named('DELETE FROM productions WHERE id = ANY(@idArray)'),
      parameters: {'idArray': ids},
    );
  }

  /// Toplu Fiyat Güncelleme (50 Milyon Kayıt Optimizasyonu)
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

    int toplamKayit = 0;
    try {
      final estimateResult = await _pool!.execute(
        "SELECT reltuples::bigint AS estimate FROM pg_class WHERE relname = 'productions'",
      );
      if (estimateResult.isNotEmpty && estimateResult[0][0] != null) {
        toplamKayit = (estimateResult[0][0] as int);
      }
    } catch (_) {
      final countResult = await _pool!.execute(
        'SELECT COUNT(*) FROM productions',
      );
      toplamKayit = countResult[0][0] as int;
    }

    if (toplamKayit == 0) return;

    if (toplamKayit <= batchSize) {
      await _pool!.execute(
        Sql.named(
          'UPDATE productions SET $column = $column $updateOperator ($column * @oran / 100)',
        ),
        parameters: {'oran': oran},
      );
      ilerlemeCallback?.call(toplamKayit, toplamKayit);
      debugPrint('✅ Toplu fiyat güncelleme tamamlandı: $toplamKayit kayıt');
      return;
    }

    int islenenKayit = 0;
    int? lastId;

    while (islenenKayit < toplamKayit) {
      final Sql sql = lastId == null
          ? Sql.named('''
              UPDATE productions 
              SET $column = $column $updateOperator ($column * @oran / 100)
              WHERE id IN (
                SELECT id FROM productions 
                ORDER BY id 
                LIMIT @batchSize
              )
              RETURNING id
            ''')
          : Sql.named('''
              UPDATE productions 
              SET $column = $column $updateOperator ($column * @oran / 100)
              WHERE id IN (
                SELECT id FROM productions 
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

      lastId = (result.last[0] as int);
      islenenKayit += result.length;

      ilerlemeCallback?.call(islenenKayit.clamp(0, toplamKayit), toplamKayit);

      await Future.delayed(const Duration(milliseconds: 10));
    }

    debugPrint('✅ Toplu fiyat güncelleme tamamlandı: $toplamKayit kayıt');
  }

  /// Toplu KDV Oranı Güncelleme (50 Milyon Kayıt Optimizasyonu)
  Future<void> topluKdvGuncelle({
    required double eskiKdv,
    required double yeniKdv,
    Function(int tamamlanan, int toplam)? ilerlemeCallback,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final int batchSize = _yapilandirma.batchSize;

    // 1. Etkilenecek kayıt sayısını al
    // Öncelik: production_metadata üzerinden O(1) okuma
    int toplamKayit = 0;
    try {
      final metaResult = await _pool!.execute(
        Sql.named(
          "SELECT frequency FROM production_metadata WHERE type = 'vat' AND value = @vat",
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
        Sql.named(
          'SELECT COUNT(*) FROM productions WHERE kdv_orani = @eskiKdv',
        ),
        parameters: {'eskiKdv': eskiKdv},
      );
      toplamKayit = countResult[0][0] as int;
    }

    if (toplamKayit == 0) {
      debugPrint('Güncellenecek kayıt bulunamadı (KDV: $eskiKdv)');
      return;
    }

    if (toplamKayit <= batchSize) {
      await _pool!.execute(
        Sql.named(
          'UPDATE productions SET kdv_orani = @yeniKdv WHERE kdv_orani = @eskiKdv',
        ),
        parameters: {'eskiKdv': eskiKdv, 'yeniKdv': yeniKdv},
      );
      ilerlemeCallback?.call(toplamKayit, toplamKayit);
      debugPrint('✅ Toplu KDV güncelleme tamamlandı: $toplamKayit kayıt');
      return;
    }

    int islenenKayit = 0;
    int? lastId;

    while (islenenKayit < toplamKayit) {
      final Sql sql = lastId == null
          ? Sql.named('''
              UPDATE productions 
              SET kdv_orani = @yeniKdv 
              WHERE id IN (
                SELECT id FROM productions 
                WHERE kdv_orani = @eskiKdv 
                ORDER BY id 
                LIMIT @batchSize
              )
              RETURNING id
            ''')
          : Sql.named('''
              UPDATE productions 
              SET kdv_orani = @yeniKdv 
              WHERE id IN (
                SELECT id FROM productions 
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
            UPDATE production_metadata 
            SET frequency = GREATEST(0, frequency - @count)
            WHERE type = 'vat' AND value = @oldVat
          '''),
          parameters: {'oldVat': eskiKdv.toString(), 'count': toplamKayit},
        );

        // Frequency 0 ise sil
        await ctx.execute(
          Sql.named('''
            DELETE FROM production_metadata 
            WHERE type = 'vat' AND value = @oldVat AND frequency <= 0
          '''),
          parameters: {'oldVat': eskiKdv.toString()},
        );

        // 2. Yeni KDV'yi ekle veya frequency'yi artır
        await ctx.execute(
          Sql.named('''
            INSERT INTO production_metadata (type, value, frequency)
            VALUES ('vat', @newVat, @count)
            ON CONFLICT (type, value) 
            DO UPDATE SET frequency = production_metadata.frequency + EXCLUDED.frequency
          '''),
          parameters: {'newVat': yeniKdv.toString(), 'count': toplamKayit},
        );
      });
    } catch (e) {
      debugPrint('Metadata güncellenirken hata (KDV dropdown): $e');
    }

    debugPrint('✅ Toplu KDV güncelleme tamamlandı: $toplamKayit kayıt');
  }

  Future<String?> sonUretimKoduGetir() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    // 1. Ortak Sequence (product_code) kontrolü
    final seqResult = await _pool!.execute(
      "SELECT current_value FROM sequences WHERE name = 'product_code'",
    );

    if (seqResult.isNotEmpty) {
      return seqResult[0][0].toString();
    }

    // 2. Sequence yoksa: Hem Ürünler hem Üretimler tablosundaki EN BÜYÜK numarayı bul
    // Not: Alfanumerik kodlarda da çalışsın diye sondaki sayıyı extract ediyoruz.
    int maxCode = 0;

    // Products table check
    try {
      final prodResult = await _pool!.execute(
        "SELECT MAX((substring(trim(kod) from '([0-9]+)\$'))::BIGINT) FROM products WHERE trim(kod) ~ '[0-9]+\$'",
      );
      if (prodResult.isNotEmpty && prodResult[0][0] != null) {
        final pc = int.tryParse(prodResult[0][0].toString());
        if (pc != null && pc > maxCode) maxCode = pc;
      }
    } catch (e) {
      debugPrint('Products kod kontrolü atlandı: $e');
    }

    // Productions table check
    try {
      final uretimResult = await _pool!.execute(
        "SELECT MAX((substring(trim(kod) from '([0-9]+)\$'))::BIGINT) FROM productions WHERE trim(kod) ~ '[0-9]+\$'",
      );
      if (uretimResult.isNotEmpty && uretimResult[0][0] != null) {
        final uc = int.tryParse(uretimResult[0][0].toString());
        if (uc != null && uc > maxCode) maxCode = uc;
      }
    } catch (e) {
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

    final seqResult = await _pool!.execute(
      "SELECT current_value FROM sequences WHERE name = 'production_barcode'",
    );

    if (seqResult.isNotEmpty) {
      return seqResult[0][0].toString();
    }

    // Fallback (Init) - Sort yerine MAX kullan (online DB'de çok daha hızlı)
    int maxBarcode = 0;
    try {
      final result = await _pool!.execute(
        "SELECT MAX((substring(trim(barkod) from '([0-9]+)\$'))::BIGINT) FROM productions WHERE trim(barkod) ~ '[0-9]+\$'",
      );
      maxBarcode = (result.isNotEmpty && result[0][0] != null)
          ? (int.tryParse(result[0][0].toString()) ?? 0)
          : 0;
    } catch (e) {
      debugPrint('Productions barkod kontrolü atlandı: $e');
    }

    // Sequence'i başlat / güncelle (yarış durumlarını önlemek için ON CONFLICT)
    await _pool!.execute(
      Sql.named(
        "INSERT INTO sequences (name, current_value) VALUES ('production_barcode', @val) "
        "ON CONFLICT (name) DO UPDATE "
        "SET current_value = GREATEST(sequences.current_value, @val)",
      ),
      parameters: {'val': maxBarcode},
    );

    return maxBarcode.toString();
  }

  // ====== REÇETE İŞLEMLERİ (BOM - Bill of Materials) ======

  /// Üretim reçetesini kaydet
  Future<void> receteKaydet(
    int productionId,
    List<Map<String, dynamic>> items,
  ) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // Önce eski reçeteyi sil
    await _pool!.execute(
      Sql.named(
        'DELETE FROM production_recipe_items WHERE production_id = @productionId',
      ),
      parameters: {'productionId': productionId},
    );

    // Yeni kalemleri ekle
    for (final item in items) {
      await _pool!.execute(
        Sql.named('''
          INSERT INTO production_recipe_items (production_id, product_code, product_name, unit, quantity)
          VALUES (@productionId, @productCode, @productName, @unit, @quantity)
        '''),
        parameters: {
          'productionId': productionId,
          'productCode': item['product_code'],
          'productName': item['product_name'],
          'unit': item['unit'],
          'quantity': item['quantity'],
        },
      );
    }
  }

  /// Üretim reçetesini getir
  Future<List<Map<String, dynamic>>> receteGetir(int productionId) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    try {
      final result = await _pool!.execute(
        Sql.named('''
          SELECT 
            pri.product_code, 
            pri.product_name, 
            pri.unit, 
            pri.quantity,
            p.barkod,
            p.grubu,
            p.ozellikler,
            COALESCE((SELECT SUM(ws.quantity) FROM warehouse_stocks ws WHERE ws.product_code = pri.product_code), 0) as total_stock
          FROM production_recipe_items pri
          LEFT JOIN products p ON p.kod = pri.product_code
          WHERE pri.production_id = @productionId
          ORDER BY pri.id ASC
        '''),
        parameters: {'productionId': productionId},
      );

      return result.map((row) {
        // Parse features if present
        List<dynamic> features = [];
        final featuresStr = row[6] as String? ?? '';
        if (featuresStr.isNotEmpty) {
          try {
            final decoded = jsonDecode(featuresStr);
            if (decoded is List) {
              features = decoded;
            }
          } catch (_) {}
        }

        // Helper: Güvenli double dönüşümü
        double safeDouble(dynamic value) {
          if (value == null) return 0.0;
          if (value is num) return value.toDouble();
          if (value is String) return double.tryParse(value) ?? 0.0;
          return 0.0;
        }

        return {
          'product_code': row[0] as String? ?? '',
          'product_name': row[1] as String? ?? '',
          'unit': row[2] as String? ?? '',
          'quantity': safeDouble(row[3]),
          'barcode': row[4] as String? ?? '',
          'group': row[5] as String? ?? '',
          'features': features,
          'total_stock': safeDouble(row[7]),
        };
      }).toList();
    } catch (e) {
      debugPrint('Reçete getirme hatası: $e');
      return [];
    }
  }

  /// Üretim reçetesini sil
  Future<void> receteSil(int productionId) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named(
        'DELETE FROM production_recipe_items WHERE production_id = @productionId',
      ),
      parameters: {'productionId': productionId},
    );
  }

  /// Üretim ID'sini kod ile bul
  Future<int?> uretimIdGetirByKod(String kod) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    final result = await _pool!.execute(
      Sql.named('SELECT id FROM productions WHERE kod = @kod LIMIT 1'),
      parameters: {'kod': kod},
    );

    if (result.isNotEmpty) {
      return result[0][0] as int;
    }
    return null;
  }

  /// Üretim bilgisini kod veya barkod ile getir
  Future<UretimModel?> uretimGetirKodVeyaBarkod(String query) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    final results = await _pool!.execute(
      Sql.named(
        'SELECT * FROM productions WHERE kod = @query OR barkod = @query LIMIT 1',
      ),
      parameters: {'query': query},
    );

    if (results.isEmpty) return null;
    return UretimModel.fromMap(results.first.toColumnMap());
  }

  /// Tahmini Birim Maliyet Hesapla (FIFO)
  Future<double> calculateEstimatedUnitCost(int productionId) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0.0;

    try {
      final recipeItems = await receteGetir(productionId);
      if (recipeItems.isEmpty) return 0.0;

      double totalCost = 0.0;

      for (final item in recipeItems) {
        final code = item['product_code'] as String? ?? '';
        final quantity =
            double.tryParse(item['quantity']?.toString() ?? '') ?? 0.0;

        if (code.isNotEmpty && quantity > 0) {
          // Recipes store quantity per 1 unit of production
          final cost = await UrunlerVeritabaniServisi().calculateFifoCost(
            code,
            quantity,
          );
          totalCost += cost;
        }
      }
      return totalCost;
    } catch (e) {
      debugPrint('Maliyet Hesaplama Hatası (ID: $productionId): $e');
      return 0.0;
    }
  }

  /// Üretim tanımını (UretimModel) ve bağlı tüm kayıtları sil
  Future<void> uretimSil(int id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // 1. Önce bu üretime ait tüm geçmiş hareketleri (production_stock_movements) bul
    final movements = await _pool!.execute(
      Sql.named(
        'SELECT id FROM production_stock_movements WHERE production_id = @id',
      ),
      parameters: {'id': id},
    );

    // 2. Her bir hareketi "uretimHareketiSil" ile sil
    // Bu metod: Stokları tersine çevirir (Revert), Sevkiyatları siler.
    // Kritik: Kullanıcı "sildin mi her yerden silinsin" dediği için bu işlem şart.
    for (final row in movements) {
      await uretimHareketiSil(row[0] as int);
    }

    // 3. Reçete kalemlerini sil (DB sadeleştirmesi)
    await receteSil(id);

    // 4. Ana Üretim kaydını sil
    await _pool!.execute(
      Sql.named('DELETE FROM productions WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  /// Üretim hareketi ekle (üretim girişi + hammadde çıkışları)
  Future<void> uretimHareketiEkle({
    required String productCode,
    required String productName,
    required double quantity,
    required String unit,
    required DateTime date,
    required int warehouseId,
    required String description,
    required List<Map<String, dynamic>> consumedItems,
    TxSession? session,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) throw Exception('Veritabanı bağlantısı kurulamadı');

    final currentUser = await _getCurrentUser();
    final now = DateTime.now();

    // 2. Genel Ayarları Al (Eksi stok kontrolü için) - Moved outside TX
    final genelAyarlar = await AyarlarVeritabaniServisi().genelAyarlariGetir();
    debugPrint(
      '⚙️ Genel Ayarlar alındı (TX dışı). Eksi stok üretim: ${genelAyarlar.eksiStokUretim}',
    );

    // [DEADLOCK FIX] Ürün Servisini işlemden ÖNCE başlat.
    // Transaction içinde başlatılırsa, DDL (create table checks) ve RowLock (for update)
    // farklı connectionlar üzerinde çakışarak DEADLOCK oluşturur.
    final urunServis = UrunlerVeritabaniServisi();
    await urunServis.baslat();
    debugPrint('📦 Ürün Servisi başlatıldı (TX dışı).');

    Future<void> operation(TxSession ctx) async {
      debugPrint('🏁 Transaction başladı (uretimHareketiEkle)');
      // 1. Üretim koduna göre Üretim Tanımını (ID) bul ve KİLİTLE (FOR UPDATE)
      debugPrint(
        '🔒 Production tablosu kilitleniyor (FOR UPDATE): $productCode',
      );
      final prodResult = await ctx.execute(
        Sql.named(
          'SELECT id, alis_fiyati FROM productions WHERE kod = @kod FOR UPDATE',
        ),
        parameters: {'kod': productCode},
      );
      debugPrint('🔓 Production kilitlendi ve okundu.');

      if (prodResult.isEmpty) {
        throw Exception('Üretim bulunamadı: $productCode');
      }

      final productionId = prodResult.first[0] as int;
      final manualCost =
          double.tryParse(prodResult.first[1]?.toString() ?? '') ?? 0.0;

      // 1b. Üretilen ürünün Ürün ID'sini bul ve KİLİTLE (FOR UPDATE)
      debugPrint('🔒 Products tablosu kilitleniyor (FOR UPDATE): $productCode');
      final productResult = await ctx.execute(
        Sql.named('SELECT id FROM products WHERE kod = @kod FOR UPDATE'),
        parameters: {'kod': productCode},
      );
      debugPrint('🔓 Products kilitlendi ve okundu.');
      int? producedProductId;
      if (productResult.isNotEmpty) {
        producedProductId = productResult.first[0] as int;
      }

      // 3. FIFO Maliyet Hesaplama ve Stok Kontrolü
      final consumedItemsWithCost = <Map<String, dynamic>>[];
      double totalConsumedCost = 0.0;
      debugPrint(
        '📊 Tüketilen kalemler işleniyor (${consumedItems.length} kalem)...',
      );

      for (var item in consumedItems) {
        final code = item['product_code'] as String;
        final qty =
            (double.tryParse(item['quantity']?.toString() ?? '') ?? 0.0) *
            quantity;

        debugPrint('  🔹 Hammadde işleniyor: $code, Miktar: $qty');

        // Ürün stokunu getir ve KİLİTLE (FOR UPDATE)
        final stokResult = await ctx.execute(
          Sql.named(
            'SELECT id, stok, ad FROM products WHERE kod = @kod FOR UPDATE',
          ),
          parameters: {'kod': code},
        );

        if (stokResult.isEmpty) {
          throw Exception('Hammadde bulunamadı: $code');
        }

        final hammaddeId = stokResult.first[0] as int;
        final mevcutStok =
            double.tryParse(stokResult.first[1]?.toString() ?? '') ?? 0.0;
        final hammaddeAdi = stokResult.first[2] as String;

        // Eksi Stok Kontrolü
        if (!genelAyarlar.eksiStokUretim && mevcutStok < qty) {
          throw Exception(
            'Yetersiz hammadde stoğu! "$hammaddeAdi" için mevcut stok: $mevcutStok, '
            'Gereken miktar: $qty. Eksi stok üretimi genel ayarlardan kapalı.',
          );
        }

        // FIFO Maliyet
        double cost = 0.0;
        if (qty > 0) {
          debugPrint('    💰 FIFO Hesapla çağrılıyor: $code');
          cost = await urunServis.calculateFifoCost(code, qty, session: ctx);
          debugPrint('    💰 FIFO Hesapla bitti: $code, Maliyet: $cost');
        }

        final newItem = Map<String, dynamic>.from(item);
        newItem['product_id'] = hammaddeId;
        newItem['totalCost'] = cost;
        newItem['unitCost'] = (qty > 0) ? (cost / qty) : 0.0;
        newItem['final_quantity'] = qty;

        consumedItemsWithCost.add(newItem);
        totalConsumedCost += cost;
      }

      // 4. Üretilen ürün birim maliyeti
      double producedUnitCost = 0.0;
      if (manualCost > 0) {
        producedUnitCost = manualCost;
      } else if (quantity > 0) {
        producedUnitCost = totalConsumedCost / quantity;
      }

      List<int> createdShipmentIds = [];

      // 1. Üretilen ürünün stokunu artır (Productions Table - Master)
      debugPrint('📝 Productions stok güncelleniyor...');
      await ctx.execute(
        Sql.named('''
          UPDATE productions SET stok = stok + @quantity::numeric WHERE id = @id
        '''),
        parameters: {'quantity': quantity, 'id': productionId},
      );

      // 2. Tüketilen hammaddeler için stok ÇIKIŞ hareketleri oluştur
      final Map<int, List<Map<String, dynamic>>> warehouseItems = {};
      for (final item in consumedItemsWithCost) {
        final wId = item['warehouse_id'] as int;
        if (!warehouseItems.containsKey(wId)) {
          warehouseItems[wId] = [];
        }
        warehouseItems[wId]!.add(item);
      }

      for (final entry in warehouseItems.entries) {
        final wId = entry.key;
        final itemsForWarehouse = entry.value;

        final shipmentItemsJson = itemsForWarehouse
            .map(
              (item) => {
                'code': item['product_code'],
                'name': item['product_name'],
                'unit': item['unit'],
                'quantity': item['final_quantity'],
                'unitCost': item['unitCost'],
              },
            )
            .toList();

        final shRes = await ctx.execute(
          Sql.named('''
            INSERT INTO shipments (source_warehouse_id, dest_warehouse_id, date, description, items, created_by, created_at)
            VALUES (@sourceId, NULL, @date, @description, @items, @created_by, @created_at)
            RETURNING id
          '''),
          parameters: {
            'sourceId': wId,
            'date': date,
            'description': description,
            'items': jsonEncode(shipmentItemsJson),
            'created_by': currentUser,
            'created_at': now,
          },
        );
        final currentShipmentId = shRes[0][0] as int;
        createdShipmentIds.add(currentShipmentId);

        for (final item in itemsForWarehouse) {
          final pId = item['product_id'] as int;
          final itemQty = item['final_quantity'] as double;
          final itemUnitCost = item['unitCost'] as double;

          await ctx.execute(
            Sql.named('''
                INSERT INTO stock_movements 
                (product_id, warehouse_id, shipment_id, quantity, is_giris, unit_price, currency_code, currency_rate, vat_status, 
                 movement_date, description, movement_type, created_by, integration_ref, created_at)
                VALUES (@productId, @warehouseId, @shipmentId, @quantity, false, @unitPrice, 'TRY', 1, 'excluded',
                        @movement_date, @description, 'cikis', @created_by, @integration_ref, @created_at)
              '''),
            parameters: {
              'productId': pId,
              'warehouseId': wId,
              'shipmentId': currentShipmentId,
              'quantity': itemQty,
              'unitPrice': itemUnitCost,
              'movement_date': date,
              'description': description,
              'created_by': currentUser,
              'created_at': now,
              'integration_ref': 'production_output',
            },
          );

          await ctx.execute(
            Sql.named(
              'UPDATE products SET stok = stok - @quantity::numeric WHERE id = @id',
            ),
            parameters: {'quantity': itemQty, 'id': pId},
          );

          await ctx.execute(
            Sql.named('''
              INSERT INTO warehouse_stocks (warehouse_id, product_code, quantity)
              VALUES (@wId, @pCode, -@qty::numeric)
              ON CONFLICT (warehouse_id, product_code) 
              DO UPDATE SET quantity = warehouse_stocks.quantity - @qty::numeric
            '''),
            parameters: {
              'wId': wId,
              'pCode': item['product_code'],
              'qty': itemQty,
            },
          );
        }
      }

      // 7. ÜRETİM GİRİŞİ (Shipment & Stock Movement)
      final prodShipmentRes = await ctx.execute(
        Sql.named('''
          INSERT INTO shipments (source_warehouse_id, dest_warehouse_id, date, description, items, created_by, created_at)
          VALUES (NULL, @destId, @date, @description, @items, @created_by, @created_at)
          RETURNING id
        '''),
        parameters: {
          'destId': warehouseId,
          'date': date,
          'description': description,
          'items': jsonEncode([
            {
              'code': productCode,
              'name': productName,
              'unit': unit,
              'quantity': quantity,
              'unitCost': producedUnitCost,
            },
          ]),
          'created_by': currentUser,
          'created_at': now,
        },
      );
      final prodShipmentId = prodShipmentRes[0][0] as int;

      await ctx.execute(
        Sql.named('''
          INSERT INTO stock_movements 
          (product_id, warehouse_id, shipment_id, quantity, is_giris, unit_price, currency_code, currency_rate, movement_date, description, movement_type, created_by, created_at)
          VALUES (@productId, @warehouseId, @shipmentId, @quantity, true, @unitPrice, 'TRY', 1, @date, @description, 'uretim_giris', @created_by, @created_at)
        '''),
        parameters: {
          'productId': producedProductId,
          'warehouseId': warehouseId,
          'shipmentId': prodShipmentId,
          'quantity': quantity,
          'unitPrice': producedUnitCost,
          'date': date,
          'description': description,
          'created_by': currentUser,
          'created_at': now,
        },
      );

      // 7b. Üretilen ürünün stokunu artır (Products & Warehouse Stocks)
      if (producedProductId != null) {
        await ctx.execute(
          Sql.named(
            'UPDATE products SET stok = stok + @quantity::numeric WHERE id = @id',
          ),
          parameters: {'quantity': quantity, 'id': producedProductId},
        );

        await ctx.execute(
          Sql.named('''
            INSERT INTO warehouse_stocks (warehouse_id, product_code, quantity)
            VALUES (@wId, @pCode, @qty::numeric)
            ON CONFLICT (warehouse_id, product_code) 
            DO UPDATE SET quantity = warehouse_stocks.quantity + @qty::numeric
          '''),
          parameters: {
            'wId': warehouseId,
            'pCode': productCode,
            'qty': quantity,
          },
        );
      }

      // 8. Ana Hareket Kaydı (production_stock_movements)
      await ctx.execute(
        Sql.named('''
          INSERT INTO production_stock_movements (
            production_id, warehouse_id, quantity, unit_price, currency, vat_status,
            movement_date, description, created_by, created_at, movement_type, 
            consumed_items, related_shipment_ids
          ) VALUES (
            @production_id, @warehouse_id, @quantity, @unitPrice, 'TRY', 'excluded',
            @movement_date, @description, @created_by, @created_at, 'giris',
            @consumedItems, @shipmentIds
          )
        '''),
        parameters: {
          'production_id': productionId,
          'warehouse_id': warehouseId,
          'quantity': quantity,
          'unitPrice': producedUnitCost,
          'movement_date': date,
          'description': description,
          'created_by': currentUser,
          'created_at': now,
          'consumedItems': jsonEncode(consumedItemsWithCost),
          'shipmentIds': jsonEncode(createdShipmentIds + [prodShipmentId]),
        },
      );
    }

    if (session != null) {
      await operation(session);
    } else {
      await _pool!.runTx((ctx) async => await operation(ctx));
    }
  }

  /// Belirtilen ID bir üretim hareketi mi? (Kontrol için)
  Future<bool> uretimHareketiVarMi(int id, {TxSession? session}) async {
    // ID'nin doğrudan production_stock_movements'de olup olmadığına bakamayız
    // Çünkü listedeki ID'ler aslında "Shipment ID".
    // uretimHareketleriniGetir fonksiyonunda "shipments" tablosundan geliyor.
    // O yüzden logic: Bu shipment ID, herhangi bir production_stock_movements kaydının
    // "related_shipment_ids" json array'i içinde geçiyor mu?

    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    final executor = session ?? _pool!;

    // JSONB array içinde arama: related_shipment_ids @> '[id]'
    // Veya text search
    final result = await executor.execute(
      Sql.named('''
        SELECT 1 FROM production_stock_movements 
        WHERE related_shipment_ids @> @idJson::jsonb
        LIMIT 1
      '''),
      parameters: {
        'idJson': jsonEncode([id]),
      },
    );

    return result.isNotEmpty;
  }

  /// Üretim hareketini sil (Geri Alma)
  Future<void> uretimHareketiSil(int shipmentId, {TxSession? session}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    Future<void> operation(TxSession ctx) async {
      // 1. Önce bu Shipment ID'ye sahip Production Movement'ı bul
      final result = await ctx.execute(
        Sql.named('''
          SELECT psm.id, psm.production_id, psm.quantity, psm.related_shipment_ids, p.kod
          FROM production_stock_movements psm
          JOIN productions p ON p.id = psm.production_id
          WHERE psm.related_shipment_ids @> @idJson::jsonb
          LIMIT 1
        '''),
        parameters: {
          'idJson': jsonEncode([shipmentId]),
        },
      );

      if (result.isEmpty) {
        // Eğer üretim kaydı bulunamazsa, sadece shipment silinsin (yetim kayıt)
        await DepolarVeritabaniServisi().sevkiyatSil(
          shipmentId,
          session: ctx,
          skipProductionCheck: true,
        );
        return;
      }

      final movementId = result[0][0] as int;
      final pId = result[0][1] as int;
      final rawQty = result[0][2];
      final qty = rawQty is num
          ? rawQty.toDouble()
          : double.tryParse(rawQty.toString()) ?? 0.0;
      final shipmentIdsRaw = result[0][3];
      final pCode = result[0][4] as String;

      List<int> shipmentIds = [];
      if (shipmentIdsRaw != null) {
        if (shipmentIdsRaw is String) {
          try {
            shipmentIds = List<int>.from(jsonDecode(shipmentIdsRaw));
          } catch (_) {}
        } else if (shipmentIdsRaw is List) {
          shipmentIds = List<int>.from(shipmentIdsRaw);
        }
      }

      // 2. Revert Production Master Stock (Ana üretim stoğunu geri al)
      // [FIX] Double Subtraction Prevention
      // If the code is NOT in products, sevkiyatSil will update productions.
      // If the code IS in products, sevkiyatSil will update products (and skip productions).
      // So we must manually update productions ONLY IF it IS in products.
      final productCheck = await ctx.execute(
        Sql.named('SELECT 1 FROM products WHERE kod = @kod'),
        parameters: {'kod': pCode},
      );

      if (productCheck.isNotEmpty) {
        await ctx.execute(
          Sql.named(
            'UPDATE productions SET stok = stok - @qty::numeric WHERE id = @id',
          ),
          parameters: {'qty': qty, 'id': pId},
        );
      }

      // 3. Revert Related Shipments (Bu üretime bağlı GİRDİ ve ÇIKTI (hammadde) tüm sevkiyatları sil)
      for (final sId in shipmentIds) {
        // Depolar servisindeki silme, stokları ve stock_movements'i de temizler.
        await DepolarVeritabaniServisi().sevkiyatSil(
          sId,
          session: ctx,
          skipProductionCheck: true,
        );
      }

      // 4. Delete Production Movement Record
      await ctx.execute(
        Sql.named('DELETE FROM production_stock_movements WHERE id = @id'),
        parameters: {'id': movementId},
      );
    }

    if (session != null) {
      await operation(session);
    } else {
      await _pool!.runTx((ctx) async => await operation(ctx));
    }
  }

  /// Üretim hareketini güncelle
  Future<void> uretimHareketiGuncelle(
    int movementId, {
    required String productCode,
    required String productName,
    required double quantity,
    required String unit,
    required DateTime date,
    required int warehouseId,
    required String description,
    required List<Map<String, dynamic>> consumedItems,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // --- SMART DELTA UPDATE (Field-Level) ---
    // Hedef: Sadece "Açıklama" değiştiyse, masraflı Stok/Maliyet (Delete-Insert) işlemine girme.

    try {
      // 1. Mevcut Veriyi Çek (Shipment ID ile Production Movement Bul)
      final result = await _pool!.execute(
        Sql.named('''
          SELECT 
            psm.id, 
            psm.description, 
            psm.movement_date, 
            psm.quantity, 
            psm.warehouse_id, 
            psm.consumed_items,
            psm.product_id,
            p.kod as main_product_code,
            psm.related_shipment_ids
          FROM production_stock_movements psm
          LEFT JOIN productions p ON p.id = psm.production_id
          WHERE psm.related_shipment_ids @> @idJson::jsonb
          LIMIT 1
        '''),
        parameters: {
          'idJson': jsonEncode([movementId]),
        },
      );

      if (result.isNotEmpty) {
        final row = result.first;
        final int psmId = row[0] as int;
        final String oldDesc = row[1] as String? ?? '';
        final DateTime oldDate = row[2] as DateTime;
        final double oldQty = double.tryParse(row[3]?.toString() ?? '') ?? 0.0;
        final int oldWarehouseId = row[4] as int;
        final dynamic oldItemsJson = row[5];
        final String oldProductCode = row[7] as String? ?? '';
        final dynamic shipmentIdsRaw = row[8];

        List<dynamic> oldConsumedItems = [];
        if (oldItemsJson is String) {
          try {
            oldConsumedItems = jsonDecode(oldItemsJson);
          } catch (_) {}
        } else if (oldItemsJson is List) {
          oldConsumedItems = oldItemsJson;
        }

        // 2. Değişiklik Analizi (Diffing)
        bool criticalChange = false;

        // A. Kritik Alanlar (Stok/Maliyet Etkileyenler)
        if ((oldQty - quantity).abs() > 0.0001) criticalChange = true;
        if (oldWarehouseId != warehouseId) criticalChange = true;
        if (oldProductCode != productCode) criticalChange = true;

        // Tarih karşılaştırma
        if (oldDate.year != date.year ||
            oldDate.month != date.month ||
            oldDate.day != date.day ||
            oldDate.hour != date.hour ||
            oldDate.minute != date.minute) {
          criticalChange = true;
        }

        // B. Reçete Kalemleri Karşılaştırma
        if (!criticalChange) {
          if (oldConsumedItems.length != consumedItems.length) {
            criticalChange = true;
          } else {
            for (int i = 0; i < oldConsumedItems.length; i++) {
              final oldItem = oldConsumedItems[i];
              final newItem = consumedItems[i];

              final String oCode = oldItem['product_code'] ?? '';
              final String nCode = newItem['product_code'] ?? '';
              final double oQ =
                  double.tryParse(oldItem['quantity']?.toString() ?? '0') ??
                  0.0;
              final double nQ =
                  double.tryParse(newItem['quantity']?.toString() ?? '0') ??
                  0.0;

              if (oCode != nCode || (oQ - nQ).abs() > 0.0001) {
                criticalChange = true;
                break;
              }
            }
          }
        }

        // 3. Karar Mekanizması
        if (!criticalChange) {
          // Sadece Açıklama (veya önemsiz alanlar) değişmiş
          if (oldDesc != description) {
            await _pool!.runTx((s) async {
              // A. Ana Kayıt Güncelle
              await s.execute(
                Sql.named(
                  'UPDATE production_stock_movements SET description = @d WHERE id = @id',
                ),
                parameters: {'d': description, 'id': psmId},
              );

              // B. Bağlı Hareketleri Güncelle
              List<int> shipmentIds = [];
              if (shipmentIdsRaw != null) {
                if (shipmentIdsRaw is String) {
                  try {
                    shipmentIds = List<int>.from(jsonDecode(shipmentIdsRaw));
                  } catch (_) {}
                } else if (shipmentIdsRaw is List) {
                  shipmentIds = List<int>.from(shipmentIdsRaw);
                }
              }

              if (shipmentIds.isNotEmpty) {
                final newDescLabel = description;
                await s.execute(
                  Sql.named(
                    'UPDATE shipments SET description = @d WHERE id = ANY(@ids)',
                  ),
                  parameters: {'d': newDescLabel, 'ids': shipmentIds},
                );
                await s.execute(
                  Sql.named(
                    'UPDATE stock_movements SET description = @d WHERE shipment_id = ANY(@ids)',
                  ),
                  parameters: {'d': newDescLabel, 'ids': shipmentIds},
                );
              }
            });
            debugPrint(
              '🚀 Smart Delta Update: Sadece açıklama güncellendi (Üretim).',
            );
            return;
          } else {
            return; // Değişiklik yok
          }
        }
      }
    } catch (e) {
      debugPrint('Smart Update Check hatası, güvenli moda geçiliyor: $e');
    }

    // --- FALLBACK: CLASSIC DELETE-THEN-INSERT ---
    await _pool!.runTx((s) async {
      await uretimHareketiSil(movementId, session: s);
      await uretimHareketiEkle(
        productCode: productCode,
        productName: productName,
        quantity: quantity,
        unit: unit,
        date: date,
        warehouseId: warehouseId,
        description: description,
        consumedItems: consumedItems,
        session: s,
      );
    });
  }

  static bool _isDesktopPlatform() {
    if (kIsWeb) return false;
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
}

// Top-level function for Isolate
List<UretimModel> _parseUretimlerIsolate(List<Map<String, dynamic>> data) {
  return data.map((d) => UretimModel.fromMap(d)).toList();
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

  try {
    final bytes = (value as dynamic).bytes;
    if (bytes is List<int>) return bytes;
  } catch (_) {}

  return value;
}
