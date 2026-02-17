import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../sayfalar/urunler_ve_depolar/depolar/modeller/depo_model.dart';
import '../sayfalar/urunler_ve_depolar/depolar/sevkiyat_olustur_sayfasi.dart';

import 'alisyap_veritabani_servisleri.dart';
import 'oturum_servisi.dart';
import 'perakende_satis_veritabani_servisleri.dart';
import 'satisyap_veritabani_servisleri.dart';
import 'bulut_sema_dogrulama_servisi.dart';
import 'pg_eklentiler.dart';
import 'veritabani_yapilandirma.dart';
import 'uretimler_veritabani_servisi.dart';
import 'lisans_yazma_koruma.dart';

class DepolarVeritabaniServisi {
  static final DepolarVeritabaniServisi _instance =
      DepolarVeritabaniServisi._internal();
  factory DepolarVeritabaniServisi() => _instance;
  DepolarVeritabaniServisi._internal();

  Pool? _pool;
  bool _isInitialized = false;
  final Set<int> _ensuredStockMovementYears = <int>{};

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
        final bool kurulumBasarili = await _baslangicKurulumuYap();

        if (kurulumBasarili) {
          try {
            _pool = await _poolOlustur();
          } catch (e2) {
            debugPrint('Kurulum sonrası bağlantı hatası: $e2');
          }
        } else {
          debugPrint('Otomatik kurulum başarısız oldu.');
        }
      }
    }

    if (_pool == null) {
      final err = StateError('Depolar veritabanı bağlantısı kurulamadı.');
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
            'DepolarVeritabaniServisi: Bulut şema hazır, tablo kurulumu atlandı.',
          );
        }
        // NOT:
        // Depo arama indekslerinin (search_tags) global backfill işlemi
        // yüksek hacimli verilerde ağır bir operasyondur.
        // Uygulama açılışında otomatik tetiklemek yerine,
        // bakım / CLI komutu ile manuel çağrılması daha güvenlidir.
        //
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
          'Depolar veritabanı bağlantısı başarılı (Havuz): ${OturumServisi().aktifVeritabaniAdi}',
        );

        // Initialization Completer - BAŞARILI
        if (!initCompleter.isCompleted) {
          initCompleter.complete();
        }

        // Arka plan görevlerini başlat (İndeksleme vb.)
        // Mobil+Bulut'ta kullanıcı işlemlerini bloklamamak için ağır bakım işleri kapalı.
        if (_yapilandirma.allowBackgroundDbMaintenance) {
          verileriIndeksle(forceUpdate: false);
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

  static bool _isIndexingActive = false;

  /// Tüm depolar için search_tags indekslemesi yapar
  Future<void> verileriIndeksle({
    bool forceUpdate = true,
    List<int>? depotIds,
  }) async {
    if (_isIndexingActive && depotIds == null) return;
    _isIndexingActive = true;

    try {
      String whereClause = forceUpdate ? '1=1' : 'search_tags IS NULL';
      if (depotIds != null && depotIds.isNotEmpty) {
        // Eğer özel ID'ler verildiyse, sadece onları güncelle (search_tags dolu olsa bile)
        whereClause = 'd.id = ANY(@depoIdArray)';
      }

      await _pool!.execute(
        Sql.named('''
        UPDATE depots d
        SET search_tags = LOWER(
            -- Ana Alanlar
            COALESCE(d.kod, '') || ' ' || 
            COALESCE(d.ad, '') || ' ' || 
            COALESCE(d.adres, '') || ' ' || 
            COALESCE(d.sorumlu, '') || ' ' || 
            COALESCE(d.telefon, '') || ' ' ||
            CAST(d.id AS TEXT) || ' ' ||
            (CASE WHEN d.aktif_mi = 1 THEN 'aktif' ELSE 'pasif' END)
        ) || ' ' || 
        -- Geçmiş İşlemler (Varsa ekle, yoksa boş, Limit 50 - TOAST Önlemi)
        COALESCE(
           (SELECT STRING_AGG(history_line, ' ') 
            FROM (
              SELECT * FROM (
                 SELECT 
                   ' ' ||
                   -- Transaction Type Label Logic for Search Tags (UI Match)
                   (CASE 
                      WHEN s.integration_ref LIKE 'SALE-%' OR s.integration_ref LIKE 'RETAIL-%' THEN 'satış faturası satış yapıldı'
                      WHEN s.integration_ref LIKE 'PURCHASE-%' THEN 'alış faturası alış yapıldı'
                      WHEN s.integration_ref = 'opening_stock' OR s.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                      WHEN s.integration_ref = 'production_output' OR s.description ILIKE '%Üretim (Çıktı)%' THEN 'üretim çıktısı üretim çıkışı'
                      WHEN s.description ILIKE '%Üretim (Girdi)%' OR s.description ILIKE '%Üretim (Giriş)%' THEN 'üretim girdisi üretim girişi'
                      WHEN EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type LIKE 'uretim%') THEN 'üretim'
                      WHEN s.source_warehouse_id = d.id AND s.dest_warehouse_id IS NOT NULL THEN 'transfer sevkiyat çıkış devir çıkış'
                      WHEN s.dest_warehouse_id = d.id AND s.source_warehouse_id IS NOT NULL THEN 'transfer sevkiyat giriş devir giriş'
                      WHEN s.dest_warehouse_id = d.id THEN 'giriş stok giriş'
                      ELSE 'çıkış stok çıkış'
                   END) || ' ' ||
                   TO_CHAR(s.date, 'DD.MM.YYYY HH24:MI') || ' ' ||
                   COALESCE(s.description, '') || ' ' ||
                   COALESCE(s.created_by, '') || ' ' ||
                   (SELECT STRING_AGG(LOWER(COALESCE(item->>'code', '') || ' ' || COALESCE(item->>'name', '')), ' ') 
                    FROM jsonb_array_elements(COALESCE(s.items, '[]'::jsonb)) item) as history_line
                 FROM shipments s 
                 WHERE s.source_warehouse_id = d.id OR s.dest_warehouse_id = d.id
                 ORDER BY s.date DESC
                 LIMIT 50
              ) sub_ordered
            ) sub_agg
           ), ''
        )
        WHERE $whereClause
       '''),
        parameters: {
          if (depotIds != null && depotIds.isNotEmpty) 'depoIdArray': depotIds,
        },
      );

      if (depotIds == null) {
        debugPrint(
          '✅ Depo Arama İndeksleri (Smart Incremental) Kontrol Edildi.',
        );
      }
    } catch (e) {
      if (e is LisansYazmaEngelliHatasi) return;
      debugPrint('İndeksleme sırasında uyarı: $e');
    } finally {
      if (depotIds == null) _isIndexingActive = false;
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

  Future<bool> _baslangicKurulumuYap() async {
    final adminConnection = await _yoneticiBaglantisiAl();

    if (adminConnection == null) {
      return false;
    }

    try {
      final username = _yapilandirma.username;
      final password = _yapilandirma.password;
      final dbName = OturumServisi().aktifVeritabaniAdi;

      try {
        await adminConnection.execute(
          "CREATE USER $username WITH PASSWORD '$password' CREATEDB",
        );
      } catch (e) {
        // Kullanıcı zaten var olabilir
      }

      try {
        await adminConnection.execute(
          'CREATE DATABASE "$dbName" OWNER "$username"',
        );
      } catch (e) {
        // Veritabanı zaten var olabilir
      }

      try {
        await adminConnection.execute(
          'GRANT ALL PRIVILEGES ON DATABASE "$dbName" TO "$username"',
        );
      } catch (e) {
        // Yetki hatası
      }

      return true;
    } catch (e) {
      return false;
    } finally {
      await adminConnection.close();
    }
  }

  Future<void> _tablolariOlustur() async {
    if (_pool == null) return;

    // Depolar Tablosu
    final depotsExist = await _pool!.execute(
      "SELECT 1 FROM information_schema.tables WHERE table_name = 'depots'",
    );

    if (depotsExist.isEmpty) {
      try {
        await _pool!.execute('DROP SEQUENCE IF EXISTS depots_id_seq CASCADE');
      } catch (e) {
        debugPrint('Sequence temizleme uyarısı: $e');
      }

      await _pool!.execute('''
        CREATE TABLE depots (
          id SERIAL PRIMARY KEY,
          kod TEXT NOT NULL,
          ad TEXT NOT NULL,
          adres TEXT,
          sorumlu TEXT,
          telefon TEXT,
          aktif_mi INTEGER DEFAULT 1,
          search_tags TEXT,
          created_by TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    }

    // Sevkiyatlar Tablosu
    final shipmentsExist = await _pool!.execute(
      "SELECT 1 FROM information_schema.tables WHERE table_name = 'shipments'",
    );

    if (shipmentsExist.isEmpty) {
      try {
        await _pool!.execute(
          'DROP SEQUENCE IF EXISTS shipments_id_seq CASCADE',
        );
      } catch (e) {
        debugPrint('Sequence temizleme uyarısı: $e');
      }

      await _pool!.execute('''
        CREATE TABLE shipments (
          id SERIAL PRIMARY KEY,
          source_warehouse_id INTEGER,
          dest_warehouse_id INTEGER,
          date TIMESTAMP,
          description TEXT,
          items JSONB,
          integration_ref TEXT,
          created_by TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    }

    // Migration: Shipments integration_ref (Purchase/Sale linkage, safe deletion)
    try {
      await _pool!.execute(
        'ALTER TABLE shipments ADD COLUMN IF NOT EXISTS integration_ref TEXT',
      );
    } catch (e) {
      debugPrint('Shipments integration_ref migration uyarısı: $e');
    }

    // ÖZET STOK TABLOSU (Warehouse Stocks) - Performans için Kritik
    final stocksExist = await _pool!.execute(
      "SELECT 1 FROM information_schema.tables WHERE table_name = 'warehouse_stocks'",
    );

    if (stocksExist.isEmpty) {
      await _pool!.execute('''
        CREATE TABLE warehouse_stocks (
          warehouse_id INTEGER NOT NULL,
          product_code TEXT NOT NULL,
          quantity NUMERIC DEFAULT 0,
          reserved_quantity NUMERIC DEFAULT 0,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (warehouse_id, product_code)
        )
      ''');
      // İndeksler
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_warehouse_stocks_wid ON warehouse_stocks(warehouse_id)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_warehouse_stocks_pcode ON warehouse_stocks(product_code)',
      );
    }

    // Migration: Warehouse stocks güncellemeleri
    try {
      await _pool!.execute(
        'ALTER TABLE warehouse_stocks ADD COLUMN IF NOT EXISTS reserved_quantity NUMERIC DEFAULT 0',
      );
    } catch (e) {
      debugPrint('warehouse_stocks update error: $e');
    }

    // Not: stock_movements güncellemeleri aşağıdaki 2. AŞAMA bloğunda daha sağlıklı yönetilmektedir.

    // 2. AŞAMA: Genel stok hareketleri tablosu (Partitioned & Standardized)
    try {
      final tableCheck = await _pool!.execute(
        "SELECT relkind::text FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'stock_movements'",
      );

      bool isPartitioned = false;
      bool smExists = tableCheck.isNotEmpty;

      if (smExists) {
        final String relkind = tableCheck.first[0].toString().toLowerCase();
        isPartitioned = relkind.contains('p');
        debugPrint(
          'Stok Hareketleri Tablo Durumu: tableExists=true, relkind=$relkind, isPartitioned=$isPartitioned',
        );
      }

      if (!smExists) {
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

        isPartitioned = true;
      }

      // Partitionların her yıl için olduğundan emin ol (RECOVERY dahil)
      if (isPartitioned) {
        final int currentYear = DateTime.now().year;

        // Sadece cari yılı bekle (HIZ İÇİN)
        await _ensureStockMovementPartitionExists(currentYear);

        // Arka Plan İşlemleri: İndeksler, Triggerlar ve Diğer Yıllar
        if (_yapilandirma.allowBackgroundDbMaintenance) {
          unawaited(() async {
            try {
              if (isPartitioned) {
                final int currentYear = DateTime.now().year;
                for (
                  int year = currentYear - 1;
                  year <= currentYear + 5;
                  year++
                ) {
                  if (year == currentYear) continue;
                  await _ensureStockMovementPartitionExists(year);
                }

                // Default partition check
                await _pool!.execute(
                  'CREATE TABLE IF NOT EXISTS stock_movements_default PARTITION OF stock_movements DEFAULT',
                );
              }

              // [2025 HYPER-ROBUST] Verify table existence before any background ALTER/INDEX operation
              final smCheck = await _pool!.execute(
                "SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'stock_movements'",
              );

              if (smCheck.isNotEmpty) {
                // Migration: Eksik kolonları ekle
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
                  'Background: stock_movements henüz yok. Atlanıyor...',
                );
              }

              // 50 Milyon Veri İçin Performans İndeksleri
              await PgEklentiler.ensurePgTrgm(_pool!);
              await _pool!.execute(
                'ALTER TABLE depots ADD COLUMN IF NOT EXISTS search_tags TEXT',
              );
              await _pool!.execute(
                'CREATE INDEX IF NOT EXISTS idx_depots_kod_trgm ON depots USING GIN (kod gin_trgm_ops)',
              );
              await _pool!.execute(
                'CREATE INDEX IF NOT EXISTS idx_depots_ad_trgm ON depots USING GIN (ad gin_trgm_ops)',
              );
              await _pool!.execute(
                'CREATE INDEX IF NOT EXISTS idx_depots_search_tags_gin ON depots USING GIN (search_tags gin_trgm_ops)',
              );
              await _pool!.execute(
                'CREATE INDEX IF NOT EXISTS idx_depots_kod_btree ON depots (kod)',
              );
              await _pool!.execute(
                'CREATE INDEX IF NOT EXISTS idx_shipments_description_trgm ON shipments USING GIN (description gin_trgm_ops)',
              );
              await _pool!.execute(
                'CREATE INDEX IF NOT EXISTS idx_shipments_items_gin ON shipments USING GIN (items)',
              );
              await _pool!.execute(
                'CREATE INDEX IF NOT EXISTS idx_shipments_date ON shipments(date)',
              );
              await _pool!.execute(
                'CREATE INDEX IF NOT EXISTS idx_shipments_source_id ON shipments(source_warehouse_id)',
              );
              await _pool!.execute(
                'CREATE INDEX IF NOT EXISTS idx_shipments_dest_id ON shipments(dest_warehouse_id)',
              );
              await _pool!.execute(
                'CREATE INDEX IF NOT EXISTS idx_shipments_created_by_trgm ON shipments USING GIN (created_by gin_trgm_ops)',
              );

              // Trigger (Depolar İçin)
              await _pool!.execute('''
              CREATE OR REPLACE FUNCTION update_depots_search_tags()
              RETURNS TRIGGER AS \$\$
              DECLARE
                history_text TEXT := '';
                stats_text TEXT := '';
              BEGIN
                SELECT COALESCE(SUM(quantity), 0)::TEXT || ' ' || COUNT(DISTINCT product_code)::TEXT
                INTO stats_text
                FROM warehouse_stocks 
                WHERE warehouse_id = NEW.id AND quantity > 0;

                SELECT STRING_AGG(
                  LOWER(
                     (CASE 
                        WHEN s.integration_ref LIKE 'SALE-%' OR s.integration_ref LIKE 'RETAIL-%' THEN 'satış faturası satış yapıldı'
                        WHEN s.integration_ref LIKE 'PURCHASE-%' THEN 'alış faturası alış yapıldı'
                        WHEN s.integration_ref = 'opening_stock' OR s.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                        WHEN s.integration_ref = 'production_output' OR s.description ILIKE '%Üretim (Çıktı)%' THEN 'üretim çıktısı üretim çıkışı'
                        WHEN s.description ILIKE '%Üretim (Girdi)%' OR s.description ILIKE '%Üretim (Giriş)%' THEN 'üretim girdisi üretim girişi'
                        WHEN EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type LIKE 'uretim%') THEN 'üretim'
                        WHEN s.source_warehouse_id = NEW.id AND s.dest_warehouse_id IS NOT NULL THEN 'transfer sevkiyat çıkış devir çıkış'
                        WHEN s.dest_warehouse_id = NEW.id AND s.source_warehouse_id IS NOT NULL THEN 'transfer sevkiyat giriş devir giriş'
                        WHEN s.dest_warehouse_id = NEW.id THEN 'giriş stok giriş'
                        ELSE 'çıkış stok çıkış'
                     END) || ' ' ||
                     TO_CHAR(s.date, 'DD.MM.YYYY HH24:MI') || ' ' ||
                     COALESCE(s.description, '') || ' ' ||
                     COALESCE(s.created_by, '') || ' ' ||
                     (
                       SELECT STRING_AGG(
                         LOWER(
                           COALESCE(item->>'code', '') || ' ' ||
                           COALESCE(item->>'name', '') || ' ' ||
                           COALESCE(item->>'unit', '') || ' ' ||
                           COALESCE(item->>'quantity', '') || ' ' ||
                           COALESCE(item->>'unitCost', '')
                         ), ' '
                       )
                       FROM jsonb_array_elements(COALESCE(s.items, '[]'::jsonb)) item
                     )
                  ), ' '
                ) INTO history_text
                FROM (
                   SELECT * FROM shipments s 
                   WHERE s.source_warehouse_id = NEW.id OR s.dest_warehouse_id = NEW.id
                   ORDER BY s.date DESC LIMIT 50
                ) s;

                NEW.search_tags := LOWER(
                  COALESCE(NEW.kod, '') || ' ' || COALESCE(NEW.ad, '') || ' ' || COALESCE(NEW.adres, '') || ' ' || 
                  COALESCE(NEW.sorumlu, '') || ' ' || COALESCE(NEW.telefon, '') || ' ' ||
                  CAST(NEW.id AS TEXT) || ' ' || (CASE WHEN NEW.aktif_mi = 1 THEN 'aktif' ELSE 'pasif' END)
                ) || ' ' || COALESCE(history_text, '') || ' ' || COALESCE(stats_text, '');
                RETURN NEW;
              END;
              \$\$ LANGUAGE plpgsql;
            ''');

              await _pool!.execute('''
              DO \$\$
              BEGIN
                 IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_update_depots_search_tags') THEN
                   CREATE TRIGGER trg_update_depots_search_tags
                   BEFORE INSERT OR UPDATE ON depots FOR EACH ROW EXECUTE FUNCTION update_depots_search_tags();
                 END IF;
              END \$\$;
            ''');

              // BACKFILL
              await _pool!.execute('''
               UPDATE depots SET search_tags = LOWER(COALESCE(kod, '') || ' ' || COALESCE(ad, '') || ' ' || COALESCE(adres, '') || ' ' || 
               COALESCE(sorumlu, '') || ' ' || COALESCE(telefon, '') || ' ' || CAST(id AS TEXT))
               WHERE search_tags IS NULL OR length(search_tags) < 3
            ''');
              // Initial İndeksleme: Arka planda çalıştır (Sayfa açılışını bloklama)
              await verileriIndeksle(forceUpdate: false);
            } catch (e) {
              if (e is LisansYazmaEngelliHatasi) return;
              if (e is ServerException &&
                  (e.code == '23505' || e.code == '42P07') &&
                  e.toString().contains('pg_class_relname_nsp_index')) {
                // Index creation can race across modules during first boot.
                // If another module won the race, treat as success.
                return;
              }
              debugPrint('Depo arka plan kurulum hatası: $e');
            }
          }());
        }
      }
    } catch (e) {
      debugPrint('Stok hareketleri tablosu fix hatası (depots): $e');
    }
  }

  static bool _isStockSyncActive = false;

  // ignore: unused_element
  Future<void> _stoklariSenkronizeEt() async {
    if (_pool == null || _isStockSyncActive) return;
    _isStockSyncActive = true;

    try {
      // Eğer tablo boşsa ve sevkiyat varsa senkronize et
      final result = await _pool!.execute(
        'SELECT 1 FROM warehouse_stocks LIMIT 1',
      );
      if (result.isEmpty) {
        final shipmentCheck = await _pool!.execute(
          'SELECT 1 FROM shipments LIMIT 1',
        );
        if (shipmentCheck.isNotEmpty) {
          debugPrint('🔄 Depo stokları optimize ediliyor (Backfilling)...');
          // Bu işlem transaction içinde yapılmalı çünkü uzun sürebilir ve consistency önemli
          await _pool!.runTx((ctx) async {
            await ctx.execute('''
            INSERT INTO warehouse_stocks (warehouse_id, product_code, quantity)
            SELECT 
              t.warehouse_id, 
              t.product_code, 
              SUM(t.quantity)
            FROM (
              SELECT dest_warehouse_id as warehouse_id, item->>'code' as product_code, (item->>'quantity')::numeric as quantity
              FROM shipments, jsonb_array_elements(items) as item
              WHERE dest_warehouse_id IS NOT NULL
              UNION ALL
              SELECT source_warehouse_id as warehouse_id, item->>'code' as product_code, -((item->>'quantity')::numeric) as quantity
              FROM shipments, jsonb_array_elements(items) as item
              WHERE source_warehouse_id IS NOT NULL
            ) as t
            GROUP BY t.warehouse_id, t.product_code
            ON CONFLICT (warehouse_id, product_code) DO UPDATE SET quantity = EXCLUDED.quantity
          ''');
          });
          debugPrint('✅ Depo stokları senkronize edildi.');
        }
      }
    } catch (e) {
      // XX000 concurrency error yutulur, bir sonraki sefer denenir.
      debugPrint('Stok senkronizasyonu uyarısı: $e');
    } finally {
      _isStockSyncActive = false;
    }
  }

  Future<String> _getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_username') ?? 'system';
  }

  // --- DEPO İŞLEMLERİ ---

  Future<bool> depoKoduVarMi(String kod, {int? haricId}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    String query = 'SELECT 1 FROM depots WHERE kod = @kod';
    final Map<String, dynamic> params = {'kod': kod};

    if (haricId != null) {
      query += ' AND id != @id';
      params['id'] = haricId;
    }

    query += ' LIMIT 1';

    final result = await _pool!.execute(Sql.named(query), parameters: params);
    return result.isNotEmpty;
  }

  Future<List<DepoModel>> depolariGetir({
    int sayfa = 1,
    int sayfaBasinaKayit = 25,
    String? aramaKelimesi,
    String? siralama,
    bool artanSiralama = true,
    bool? aktifMi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? islemTuru,
    String? kullanici,
    int? depoId,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    // Sorting logic
    String sortColumn = 'id';
    switch (siralama) {
      case 'kod':
        sortColumn = 'kod';
        break;
      case 'ad':
        sortColumn = 'ad';
        break;
      case 'adres':
        sortColumn = 'adres';
        break;
      case 'sorumlu':
        sortColumn = 'sorumlu';
        break;
      case 'telefon':
        sortColumn = 'telefon';
        break;
      case 'aktif_mi':
        sortColumn = 'aktif_mi';
        break;
      default:
        sortColumn = 'id';
    }
    String direction = artanSiralama ? 'ASC' : 'DESC';

    String selectClause = 'SELECT depots.*';

    List<String> whereConditions = [];
    Map<String, dynamic> params = {};

    if (aramaKelimesi != null && aramaKelimesi.isNotEmpty) {
      // 1 Milyar Kayıt Optimisazyonu: Full Denormalized Search
      // Sadece search_tags sütununu kullan. Veritabanını yorma.

      selectClause += '''
          , (CASE 
              WHEN search_tags LIKE @search 
              THEN true 
              ELSE false 
           END) as matched_in_hidden
      ''';

      // OPTIMIZASYON: LOWER(search_tags) yerine direkt search_tags (DB'de zaten lower tutuluyor)
      whereConditions.add('search_tags LIKE @search');
      params['search'] = '%${aramaKelimesi.toLowerCase()}%';
    } else {
      selectClause += ', false as matched_in_hidden';
    }

    if (aktifMi != null) {
      whereConditions.add('aktif_mi = @aktifMi');
      params['aktifMi'] = aktifMi ? 1 : 0;
    }

    final String? trimmedUser = kullanici?.trim();
    final String? trimmedType = islemTuru?.trim();

    String? typeCondition;
    if (trimmedType != null && trimmedType.isNotEmpty) {
      if (trimmedType == 'Sevkiyat' || trimmedType == 'Transfer') {
        typeCondition =
            's.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NOT NULL';
      } else if (trimmedType == 'Açılış Stoğu' ||
          trimmedType.contains('Açılış')) {
        typeCondition =
            "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%')";
      } else if (trimmedType == 'Giriş' ||
          trimmedType == 'Devir Girdi' ||
          trimmedType == 'Devir (Girdi)' ||
          trimmedType.contains('Giriş') ||
          trimmedType == 'Alış Yapıldı' ||
          trimmedType == 'Üretim Girişi') {
        typeCondition =
            "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%')";

        if (trimmedType == 'Üretim Girişi') {
          typeCondition =
              "$typeCondition AND EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris')";
        } else if (trimmedType == 'Alış Yapıldı') {
          typeCondition =
              "$typeCondition AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
        } else if (trimmedType == 'Devir Girdi' ||
            trimmedType == 'Devir (Girdi)') {
          typeCondition =
              "$typeCondition AND NOT EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
        }
      } else if (trimmedType == 'Çıkış' ||
          trimmedType == 'Devir Çıktı' ||
          trimmedType == 'Devir (Çıktı)' ||
          trimmedType.contains('Çıkış') ||
          trimmedType == 'Satış Yapıldı' ||
          trimmedType == 'Üretim Çıkışı') {
        typeCondition =
            's.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL';

        if (trimmedType == 'Üretim Çıkışı') {
          typeCondition =
              "$typeCondition AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%')";
        } else if (trimmedType == 'Satış Yapıldı') {
          typeCondition =
              "$typeCondition AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
        } else if (trimmedType == 'Devir Çıktı' ||
            trimmedType == 'Devir (Çıktı)') {
          typeCondition =
              "$typeCondition AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
        }
      }
    }

    if (baslangicTarihi != null ||
        bitisTarihi != null ||
        (trimmedUser != null && trimmedUser.isNotEmpty) ||
        typeCondition != null) {
      String existsQuery = '''
        EXISTS (
          SELECT 1 FROM shipments s
          WHERE (s.source_warehouse_id = depots.id OR s.dest_warehouse_id = depots.id)
      ''';

      if (baslangicTarihi != null) {
        existsQuery += ' AND s.date >= @startDate';
        params['startDate'] = baslangicTarihi.toIso8601String();
      }
      if (bitisTarihi != null) {
        existsQuery += ' AND s.date <= @endDate';
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

      if (trimmedUser != null && trimmedUser.isNotEmpty) {
        existsQuery += ' AND COALESCE(s.created_by, \'\') = @shipmentUser';
        params['shipmentUser'] = trimmedUser;
      }

      if (typeCondition != null) {
        existsQuery += ' AND $typeCondition';
      }

      existsQuery += ')';
      whereConditions.add(existsQuery);
    }

    if (depoId != null) {
      whereConditions.add('id = @depoId');
      params['depoId'] = depoId;
    }

    String whereClause = '';
    if (whereConditions.isNotEmpty) {
      whereClause = 'WHERE ${whereConditions.join(' AND ')}';
    }

    final query =
        '''
      $selectClause
      FROM depots
      $whereClause
      ORDER BY depots.$sortColumn $direction
      LIMIT @limit OFFSET @offset
    ''';

    params['limit'] = sayfaBasinaKayit;
    params['offset'] = (sayfa - 1) * sayfaBasinaKayit;

    final result = await _pool!.execute(Sql.named(query), parameters: params);

    final List<Map<String, dynamic>> dataList = result
        .map((row) {
          final map = row.toColumnMap();
          _makeIsolateSafeMapInPlace(map);
          return map;
        })
        .toList(growable: false);

    try {
      return await compute(_parseDepolarIsolate, dataList);
    } catch (e) {
      debugPrint(
        'DepolarVeritabaniServisi: Isolate parse başarısız, fallback devrede: $e',
      );
      return dataList.map(DepoModel.fromMap).toList(growable: false);
    }
  }

  Future<int> depoSayisiGetir({
    String? aramaTerimi,
    bool? aktifMi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? islemTuru,
    String? kullanici,
    int? depoId,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;

    String query = 'SELECT COUNT(*) FROM depots';
    Map<String, dynamic> params = {};
    List<String> whereConditions = [];

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      whereConditions.add('search_tags LIKE @search');
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
    }

    if (aktifMi != null) {
      whereConditions.add('aktif_mi = @aktifMi');
      params['aktifMi'] = aktifMi ? 1 : 0;
    }

    final String? trimmedUser = kullanici?.trim();
    final String? trimmedType = islemTuru?.trim();

    String? typeCondition;
    if (trimmedType != null && trimmedType.isNotEmpty) {
      if (trimmedType == 'Sevkiyat' || trimmedType == 'Transfer') {
        typeCondition =
            's.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NOT NULL';
      } else if (trimmedType == 'Açılış Stoğu' ||
          trimmedType.contains('Açılış')) {
        typeCondition =
            "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%')";
      } else if (trimmedType == 'Üretim Girişi') {
        typeCondition =
            "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris')";
      } else if (trimmedType == 'Üretim Çıkışı') {
        typeCondition =
            "s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%')";
      } else if (trimmedType == 'Satış Yapıldı') {
        typeCondition =
            "s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
      } else if (trimmedType == 'Alış Yapıldı') {
        typeCondition =
            "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
      } else if (trimmedType == 'Devir Girdi' ||
          trimmedType == 'Devir (Girdi)') {
        typeCondition =
            "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%') AND NOT EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
      } else if (trimmedType == 'Devir Çıktı' ||
          trimmedType == 'Devir (Çıktı)') {
        typeCondition =
            "s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
      } else if (trimmedType == 'Giriş' || trimmedType.contains('Giriş')) {
        typeCondition =
            "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%')";
      } else if (trimmedType == 'Çıkış' || trimmedType.contains('Çıkış')) {
        typeCondition =
            's.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL';
      }
    }

    if (baslangicTarihi != null ||
        bitisTarihi != null ||
        (trimmedUser != null && trimmedUser.isNotEmpty) ||
        typeCondition != null) {
      String existsQuery = '''
        EXISTS (
          SELECT 1 FROM shipments s
          WHERE (s.source_warehouse_id = depots.id OR s.dest_warehouse_id = depots.id)
      ''';

      if (baslangicTarihi != null) {
        existsQuery += ' AND s.date >= @startDate';
        params['startDate'] = baslangicTarihi.toIso8601String();
      }
      if (bitisTarihi != null) {
        existsQuery += ' AND s.date <= @endDate';
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

      if (trimmedUser != null && trimmedUser.isNotEmpty) {
        existsQuery += ' AND COALESCE(s.created_by, \'\') = @shipmentUser';
        params['shipmentUser'] = trimmedUser;
      }

      if (typeCondition != null) {
        existsQuery += ' AND $typeCondition';
      }

      existsQuery += ')';
      whereConditions.add(existsQuery);
    }

    if (depoId != null) {
      whereConditions.add('id = @depoId');
      params['depoId'] = depoId;
    }

    if (whereConditions.isNotEmpty) {
      query += ' WHERE ${whereConditions.join(' AND ')}';
    } else {
      // Filtre yoksa pg_class üzerinden tahmini sayıyı al (HIZLI)
      final estimateResult = await _pool!.execute(
        "SELECT reltuples::bigint AS estimate FROM pg_class WHERE relname = 'depots'",
      );
      if (estimateResult.isNotEmpty && estimateResult[0][0] != null) {
        final estimate = estimateResult[0][0] as int;
        if (estimate > 0) return estimate;
      }
    }

    final result = await _pool!.execute(Sql.named(query), parameters: params);
    return result[0][0] as int;
  }

  Future<Map<String, Map<String, int>>> depoFiltreIstatistikleriniGetir({
    String? aramaTerimi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    bool? aktifMi,
    String? islemTuru,
    String? kullanici,
    int? depoId,
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

    DateTime? endOfDay(DateTime? d) {
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
    }

    String buildWhere(List<String> conds) {
      return conds.isEmpty ? '' : 'WHERE ${conds.join(' AND ')}';
    }

    void addBaseConds(List<String> conds, Map<String, dynamic> params) {
      final String? trimmedSearch = aramaTerimi?.trim();
      if (trimmedSearch != null && trimmedSearch.isNotEmpty) {
        conds.add('search_tags LIKE @search');
        params['search'] = '%${trimmedSearch.toLowerCase()}%';
      }

      if (baslangicTarihi != null || bitisTarihi != null) {
        final List<String> shipmentConds = [
          '(s.source_warehouse_id = depots.id OR s.dest_warehouse_id = depots.id)',
        ];

        if (baslangicTarihi != null) {
          shipmentConds.add('s.date >= @startDate');
          params['startDate'] = baslangicTarihi.toIso8601String();
        }
        if (bitisTarihi != null) {
          shipmentConds.add('s.date <= @endDate');
          params['endDate'] = endOfDay(bitisTarihi)!.toIso8601String();
        }

        conds.add('''
          EXISTS (
            SELECT 1 FROM shipments s
            WHERE ${shipmentConds.join(' AND ')}
          )
        ''');
      }
    }

    String? buildTypeCondition(String? t) {
      final String? trimmedType = t?.trim();
      if (trimmedType == null || trimmedType.isEmpty) return null;

      switch (trimmedType) {
        case 'Sevkiyat':
        case 'Transfer':
          return 's.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NOT NULL';
        case 'Açılış Stoğu (Girdi)':
        case 'Açılış Stoğu':
          return "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%')";
        case 'Üretim Girişi':
          return "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%') AND EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris')";
        case 'Üretim Çıkışı':
          return "s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%')";
        case 'Satış Yapıldı':
        case 'Satış Faturası':
          return "s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
        case 'Alış Yapıldı':
        case 'Alış Faturası':
          return "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
        case 'Devir Girdi':
        case 'Devir (Girdi)':
          return "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%') AND NOT EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
        case 'Devir Çıktı':
        case 'Devir (Çıktı)':
          return "s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
      }

      if (trimmedType.contains('Giriş')) {
        return "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%')";
      }

      if (trimmedType.contains('Çıkış')) {
        return 's.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL';
      }

      return null;
    }

    String buildShipmentExists(
      Map<String, dynamic> params, {
      String? type,
      String? user,
    }) {
      final String? trimmedUser = user?.trim();
      final String? trimmedType = type?.trim();

      if ((trimmedUser == null || trimmedUser.isEmpty) &&
          (trimmedType == null || trimmedType.isEmpty)) {
        return '';
      }

      final List<String> shipmentConds = [
        '(s.source_warehouse_id = depots.id OR s.dest_warehouse_id = depots.id)',
      ];

      if (baslangicTarihi != null) {
        shipmentConds.add('s.date >= @startDate');
        params['startDate'] = baslangicTarihi.toIso8601String();
      }
      if (bitisTarihi != null) {
        shipmentConds.add('s.date <= @endDate');
        params['endDate'] = endOfDay(bitisTarihi)!.toIso8601String();
      }

      if (trimmedUser != null && trimmedUser.isNotEmpty) {
        shipmentConds.add("COALESCE(s.created_by, '') = @shipmentUser");
        params['shipmentUser'] = trimmedUser;
      }

      if (trimmedType != null && trimmedType.isNotEmpty) {
        final cond = buildTypeCondition(trimmedType);
        if (cond != null && cond.isNotEmpty) {
          shipmentConds.add(cond);
        }
      }

      return '''
        EXISTS (
          SELECT 1 FROM shipments s
          WHERE ${shipmentConds.join(' AND ')}
        )
      ''';
    }

    // [GENEL TOPLAM] Sadece arama + tarih filtresi (diğer facetler hariç)
    final totalParams = <String, dynamic>{};
    final totalConds = <String>[];
    addBaseConds(totalConds, totalParams);
    final totalResult = await _pool!.execute(
      Sql.named('SELECT COUNT(*) FROM depots ${buildWhere(totalConds)}'),
      parameters: totalParams,
    );
    final int genelToplam = totalResult.isEmpty
        ? 0
        : (totalResult.first[0] as int);

    // 1) Durum facet (aktif_mi)
    final statusParams = <String, dynamic>{};
    final statusConds = <String>[];
    addBaseConds(statusConds, statusParams);
    if (depoId != null) {
      statusConds.add('id = @depoId');
      statusParams['depoId'] = depoId;
    }
    final statusExists = buildShipmentExists(
      statusParams,
      type: islemTuru,
      user: kullanici,
    );
    if (statusExists.isNotEmpty) statusConds.add(statusExists);
    final statusQuery =
        '''
      SELECT aktif_mi, COUNT(*) FROM (
        SELECT depots.aktif_mi
        FROM depots
        ${buildWhere(statusConds)}
      ) sub
      GROUP BY aktif_mi
    ''';

    // 2) Depo facet (id)
    final depotParams = <String, dynamic>{};
    final depotConds = <String>[];
    addBaseConds(depotConds, depotParams);
    if (aktifMi != null) {
      depotConds.add('aktif_mi = @aktifMi');
      depotParams['aktifMi'] = aktifMi ? 1 : 0;
    }
    final depotExists = buildShipmentExists(
      depotParams,
      type: islemTuru,
      user: kullanici,
    );
    if (depotExists.isNotEmpty) depotConds.add(depotExists);
    final depotQuery =
        '''
      SELECT id, COUNT(*) FROM (
        SELECT depots.id
        FROM depots
        ${buildWhere(depotConds)}
      ) sub
      GROUP BY id
    ''';

    // 3) Kullanıcı facet (shipments.created_by)
    final userParams = <String, dynamic>{};
    final userConds = <String>[];
    final String? trimmedSearch = aramaTerimi?.trim();
    if (trimmedSearch != null && trimmedSearch.isNotEmpty) {
      userConds.add('d.search_tags LIKE @search');
      userParams['search'] = '%${trimmedSearch.toLowerCase()}%';
    }
    if (aktifMi != null) {
      userConds.add('d.aktif_mi = @aktifMi');
      userParams['aktifMi'] = aktifMi ? 1 : 0;
    }
    if (depoId != null) {
      userConds.add('d.id = @depoId');
      userParams['depoId'] = depoId;
    }
    if (baslangicTarihi != null) {
      userConds.add('s.date >= @startDate');
      userParams['startDate'] = baslangicTarihi.toIso8601String();
    }
    if (bitisTarihi != null) {
      userConds.add('s.date <= @endDate');
      userParams['endDate'] = endOfDay(bitisTarihi)!.toIso8601String();
    }
    final String? trimmedTypeForUser = islemTuru?.trim();
    if (trimmedTypeForUser != null && trimmedTypeForUser.isNotEmpty) {
      final cond = buildTypeCondition(trimmedTypeForUser);
      if (cond != null && cond.isNotEmpty) {
        userConds.add(cond);
      }
    }
    final userQuery =
        '''
      SELECT COALESCE(s.created_by, '') as kullanici, COUNT(DISTINCT d.id)
      FROM depots d
      JOIN shipments s ON (s.source_warehouse_id = d.id OR s.dest_warehouse_id = d.id)
      ${userConds.isNotEmpty ? 'WHERE ${userConds.join(' AND ')}' : ''}
      GROUP BY 1
    ''';

    Future<int> countForType(String t) async {
      final typeParams = <String, dynamic>{};
      final typeConds = <String>[];
      addBaseConds(typeConds, typeParams);
      if (aktifMi != null) {
        typeConds.add('aktif_mi = @aktifMi');
        typeParams['aktifMi'] = aktifMi ? 1 : 0;
      }
      if (depoId != null) {
        typeConds.add('id = @depoId');
        typeParams['depoId'] = depoId;
      }
      final typeExists = buildShipmentExists(
        typeParams,
        type: t,
        user: kullanici,
      );
      if (typeExists.isNotEmpty) typeConds.add(typeExists);

      final result = await _pool!.execute(
        Sql.named('''
          SELECT COUNT(*) FROM (
            SELECT depots.id
            FROM depots
            ${buildWhere(typeConds)}
          ) sub
        '''),
        parameters: typeParams,
      );
      return result.isEmpty ? 0 : (result.first[0] as int);
    }

    try {
      final results = await Future.wait([
        _pool!.execute(Sql.named(statusQuery), parameters: statusParams),
        _pool!.execute(Sql.named(depotQuery), parameters: depotParams),
        _pool!.execute(Sql.named(userQuery), parameters: userParams),
        Future.wait(supportedStockTypes.map(countForType)),
      ]);

      final Result statusRows = results[0] as Result;
      final Result depotRows = results[1] as Result;
      final Result userRows = results[2] as Result;
      final typeCounts = results[3] as List<int>;

      final Map<String, int> durumlar = {};
      for (final row in statusRows) {
        final key = (row[0] == 1 || row[0] == true) ? 'active' : 'passive';
        durumlar[key] = row[1] as int;
      }

      final Map<String, int> depolar = {};
      for (final row in depotRows) {
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
        'depolar': depolar,
        'islem_turleri': islemTurleri,
        'kullanicilar': kullanicilar,
        'ozet': {'toplam': genelToplam},
      };
    } catch (e) {
      debugPrint('Depo filtre istatistikleri hatası: $e');
      return {
        'ozet': {'toplam': genelToplam},
      };
    }
  }

  Future<List<DepoModel>> depoAra(String aramaTerimi, {int limit = 20}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    String query = 'SELECT * FROM depots';
    Map<String, dynamic> params = {};

    if (aramaTerimi.isNotEmpty) {
      query +=
          ' WHERE kod ILIKE @search OR ad ILIKE @search OR adres ILIKE @search OR sorumlu ILIKE @search';
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
    }

    query += ' ORDER BY ad ASC LIMIT @limit';
    params['limit'] = limit;

    final result = await _pool!.execute(Sql.named(query), parameters: params);
    return result.map((row) {
      final map = row.toColumnMap();
      return DepoModel.fromMap(map);
    }).toList();
  }

  Future<void> depoEkle(DepoModel depo) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final currentUser = await _getCurrentUser();
    final map = depo.toMap();
    map.remove('id');
    map.remove('matched_in_hidden');
    map['created_by'] = currentUser;
    map['created_at'] = DateTime.now();

    final searchTags = [
      depo.kod,
      depo.ad,
      depo.adres,
      depo.sorumlu,
      depo.telefon,
      depo.id.toString(),
      depo.aktifMi ? 'aktif' : 'pasif',
      currentUser,
    ].where((e) => e.toString().trim().isNotEmpty).join(' ').toLowerCase();

    map['search_tags'] = searchTags;

    await _pool!.execute(
      Sql.named('''
        INSERT INTO depots (kod, ad, adres, sorumlu, telefon, aktif_mi, created_by, created_at, search_tags)
        VALUES (@kod, @ad, @adres, @sorumlu, @telefon, @aktif_mi, @created_by, @created_at, @search_tags)
      '''),
      parameters: map,
    );
  }

  Future<void> depoGuncelle(DepoModel depo) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final map = depo.toMap();
    map.remove('created_by'); // Keep original creator
    map.remove('created_at');
    map.remove('matched_in_hidden');

    await _pool!.execute(
      Sql.named('''
        UPDATE depots SET 
        kod=@kod, 
        ad=@ad, 
        adres=@adres, 
        sorumlu=@sorumlu, 
        telefon=@telefon, 
        aktif_mi=@aktif_mi,
        -- Arama etiketi: Mevcut etikete yeni temel alanları ekle (geçmişi silmeden)
        search_tags = LOWER(
          COALESCE(search_tags, '') || ' ' ||
          COALESCE(@kod, '') || ' ' ||
          COALESCE(@ad, '') || ' ' ||
          COALESCE(@adres, '') || ' ' ||
          COALESCE(@sorumlu, '') || ' ' ||
          COALESCE(@telefon, '') || ' ' ||
          CAST(@id AS TEXT) || ' ' ||
          (CASE WHEN @aktif_mi = 1 THEN 'aktif' ELSE 'pasif' END)
        )
        WHERE id=@id
      '''),
      parameters: map,
    );
  }

  Future<void> depoSil(int id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('DELETE FROM depots WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  // --- SEVKİYAT İŞLEMLERİ ---

  Future<List<DepoModel>> tumDepolariGetir() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    const query = 'SELECT * FROM depots WHERE aktif_mi = 1 ORDER BY ad ASC';

    final result = await _pool!.execute(query);
    return result.map((row) {
      final map = row.toColumnMap();
      return DepoModel.fromMap(map);
    }).toList();
  }

  Future<int> sevkiyatEkle({
    required int? sourceId,
    required int? destId,
    required DateTime date,
    required String description,
    required List<ShipmentItem> items,
    bool updateStock = true,
    String? createdBy,
    String? integrationRef,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;

    final currentUser = createdBy ?? await _getCurrentUser();
    final int partitionYear = DateTime.now().year;
    if (!_ensuredStockMovementYears.contains(partitionYear)) {
      await _ensureStockMovementPartitionExists(partitionYear);
      _ensuredStockMovementYears.add(partitionYear);
    }

    final itemsJson = items
        .map(
          (item) => {
            'code': item.code,
            'name': item.name,
            'unit': item.unit,
            'quantity': item.quantity,
            if (item.unitCost != null) 'unitCost': item.unitCost,
            if (item.devices != null) 'devices': item.devices,
          },
        )
        .toList();

    final resultId = await _pool!.runTx((ctx) async {
      // 1. Shipment Insert (Single)
      final shipmentRes = await ctx.execute(
        Sql.named('''
          INSERT INTO shipments (source_warehouse_id, dest_warehouse_id, date, description, items, integration_ref, created_by, created_at)
          VALUES (@sourceId, @destId, @date, @description, @items, @integration_ref, @created_by, @created_at)
          RETURNING id
        '''),
        parameters: {
          'sourceId': sourceId,
          'destId': destId,
          'date': date,
          'description': description,
          'items': jsonEncode(itemsJson),
          'integration_ref': integrationRef,
          'created_by': currentUser,
          'created_at': DateTime.now(),
        },
      );
      final shipmentId = shipmentRes[0][0] as int;

      // --- BATCH PROCESSING (50M Optimization) ---

      // Data Maps
      final Map<String, double> globalStockChanges = {};
      final Map<int, Map<String, double>> warehouseStockChanges = {};

      // Calculate Stock Deltas
      for (final item in items) {
        // Global Stock Delta
        double globalDelta = 0;
        if (sourceId == null && destId != null) {
          globalDelta = item.quantity;
        } else if (sourceId != null && destId == null) {
          globalDelta = -item.quantity;
        }

        if (globalDelta != 0) {
          globalStockChanges[item.code] =
              (globalStockChanges[item.code] ?? 0) + globalDelta;
        }

        // Local Stock Delta - Source
        if (sourceId != null) {
          warehouseStockChanges.putIfAbsent(sourceId, () => {});
          warehouseStockChanges[sourceId]![item.code] =
              (warehouseStockChanges[sourceId]![item.code] ?? 0) -
              item.quantity;
        }
        // Local Stock Delta - Dest
        if (destId != null) {
          warehouseStockChanges.putIfAbsent(destId, () => {});
          warehouseStockChanges[destId]![item.code] =
              (warehouseStockChanges[destId]![item.code] ?? 0) + item.quantity;
        }
      }

      if (updateStock) {
        // 2. BATCH UPDATE PRODUCT GLOBAL STOCK (parametrik, plan cache dostu)
        if (globalStockChanges.isNotEmpty) {
          final List<String> globalCodes = [];
          final List<double> globalDeltas = [];

          globalStockChanges.forEach((code, delta) {
            globalCodes.add(code);
            globalDeltas.add(delta);
          });

          await ctx.execute(
            Sql.named('''
              UPDATE products AS p
              SET stok = p.stok + v.qty
              FROM (
                SELECT unnest(@codes::text[]) AS code,
                       unnest(@deltas::numeric[]) AS qty
              ) AS v
              WHERE p.kod = v.code
            '''),
            parameters: {'codes': globalCodes, 'deltas': globalDeltas},
          );
        }

        // 3. BATCH INSERT/UPDATE WAREHOUSE STOCK (parametrik, injection-sız)
        if (warehouseStockChanges.isNotEmpty) {
          final List<int> wsWarehouseIds = [];
          final List<String> wsProductCodes = [];
          final List<double> wsQuantities = [];

          warehouseStockChanges.forEach((wid, productMap) {
            productMap.forEach((pCode, qty) {
              wsWarehouseIds.add(wid);
              wsProductCodes.add(pCode);
              wsQuantities.add(qty);
            });
          });

          if (wsWarehouseIds.isNotEmpty) {
            await ctx.execute(
              Sql.named('''
                INSERT INTO warehouse_stocks (warehouse_id, product_code, quantity)
                SELECT * FROM unnest(
                  @wids::int[],
                  @codes::text[],
                  @qtys::numeric[]
                )
                ON CONFLICT (warehouse_id, product_code) 
                DO UPDATE SET quantity = warehouse_stocks.quantity + EXCLUDED.quantity
              '''),
              parameters: {
                'wids': wsWarehouseIds,
                'codes': wsProductCodes,
                'qtys': wsQuantities,
              },
            );
          }
        }
      }

      // 4. BATCH SEARCH TAG UPDATE (Optimized)
      // Fetch Depo Names & KDVs in Bulk (No N+1 Queries)
      String sourceName = '';
      String destName = '';

      if (sourceId != null) {
        final res = await ctx.execute(
          Sql.named('SELECT ad FROM depots WHERE id=@id'),
          parameters: {'id': sourceId},
        );
        if (res.isNotEmpty) sourceName = res.first[0] as String;
      }
      if (destId != null) {
        final res = await ctx.execute(
          Sql.named('SELECT ad FROM depots WHERE id=@id'),
          parameters: {'id': destId},
        );
        if (res.isNotEmpty) destName = res.first[0] as String;
      }

      // Bulk ürün bilgisi (ID + KDV)
      final Map<String, double> productKdvMap = {};
      final Map<String, int> productIdMap = {};
      final productCodes = items
          .map((e) => e.code)
          .toSet()
          .toList(); // unique kodlar
      if (productCodes.isNotEmpty) {
        final kdvRes = await ctx.execute(
          Sql.named(
            'SELECT id, kod, kdv_orani FROM products WHERE kod = ANY(@codes)',
          ),
          parameters: {'codes': productCodes},
        );
        for (final row in kdvRes) {
          final code = row[1] as String;
          final val = row[2];
          double kdvVal = 0.0;
          if (val is num) {
            kdvVal = val.toDouble();
          } else if (val is String) {
            kdvVal = double.tryParse(val) ?? 0.0;
          }
          productKdvMap[code] = kdvVal;
          productIdMap[code] = row[0] as int;
        }
      }

      String typeLabel = 'sevkiyat';
      if (sourceId == null) typeLabel = 'devir girdi';
      if (destId == null) typeLabel = 'devir çıktı';

      final commonTagPart = [
        description.toLowerCase(),
        typeLabel,
        currentUser.toLowerCase(),
        "${date.day}.${date.month}.${date.year}",
        sourceName.toLowerCase(),
        destName.toLowerCase(),
      ].join(' ');

      List<String> tagUpdates = [];
      for (final item in items) {
        double kdv = productKdvMap[item.code] ?? 18.0;
        double itemVatPrice = 0.0;
        if (item.unitCost != null) {
          itemVatPrice = item.unitCost! * (1 + kdv / 100.0);
        }

        final specificTag = [
          commonTagPart,
          item.quantity.toString(),
          item.unitCost?.toString() ?? '',
          itemVatPrice > 0 ? itemVatPrice.toStringAsFixed(2) : '',
        ].where((e) => e.toString().trim().isNotEmpty).join(' ').toLowerCase();

        // Escape single quotes in tag for SQL literal safety
        final safeTag = specificTag.replaceAll("'", "''");
        tagUpdates.add("('${item.code}', '$safeTag')");
      }

      if (tagUpdates.isNotEmpty) {
        final tagValuesStr = tagUpdates.join(',');
        await ctx.execute('''
             UPDATE products AS p
             SET search_tags = COALESCE(search_tags, '') || ' ' || v.tag
             FROM (VALUES $tagValuesStr) AS v(code, tag)
             WHERE p.kod = v.code
          ''');
      }

      // 5. Stok hareketleri tablosuna satır ekle (ürün bazlı tarih filtresi için)
      if (productIdMap.isNotEmpty) {
        for (final item in items) {
          final productId = productIdMap[item.code];
          if (productId == null) continue;

          // Kaynak depo için çıkış hareketi
          if (sourceId != null) {
            await ctx.execute(
              Sql.named('''
                INSERT INTO stock_movements (
                  product_id,
                  warehouse_id,
                  shipment_id,
                  quantity,
                  is_giris,
                  unit_price,
                  currency_code,
                  currency_rate,
                  vat_status,
                  movement_date,
                  description,
                  movement_type,
                  created_by,
                  integration_ref,
                  created_at
                )
                VALUES (
                  @productId,
                  @warehouseId,
                  @shipmentId,
                  @quantity::numeric,
                  false,
                  @unitPrice,
                  'TRY',
                  1,
                  'excluded',
                  @movementDate,
                  @description,
                  @movementType,
                  @createdBy,
                  @integrationRef,
                  @createdAt
                )
              '''),
              parameters: {
                'productId': productId,
                'warehouseId': sourceId,
                'shipmentId': shipmentId,
                'quantity': item.quantity,
                'unitPrice': item.unitCost ?? 0,
                'movementDate': date,
                'description': description,
                'movementType': 'cikis',
                'createdBy': currentUser,
                'integrationRef': integrationRef,
                'createdAt': DateTime.now(),
              },
            );
          }

          // Hedef depo için giriş hareketi
          if (destId != null) {
            await ctx.execute(
              Sql.named('''
                INSERT INTO stock_movements (
                  product_id,
                  warehouse_id,
                  shipment_id,
                  quantity,
                  is_giris,
                  unit_price,
                  currency_code,
                  currency_rate,
                  vat_status,
                  movement_date,
                  description,
                  movement_type,
                  created_by,
                  integration_ref,
                  created_at
                )
                VALUES (
                  @productId,
                  @warehouseId,
                  @shipmentId,
                  @quantity::numeric,
                  true,
                  @unitPrice,
                  'TRY',
                  1,
                  'excluded',
                  @movementDate,
                  @description,
                  @movementType,
                  @createdBy,
                  @integrationRef,
                  @createdAt
                )
              '''),
              parameters: {
                'productId': productId,
                'warehouseId': destId,
                'shipmentId': shipmentId,
                'quantity': item.quantity,
                'unitPrice': item.unitCost ?? 0,
                'movementDate': date,
                'description': description,
                'movementType': sourceId == null ? 'giris' : 'transfer_giris',
                'createdBy': currentUser,
                'integrationRef': integrationRef,
                'createdAt': DateTime.now(),
              },
            );
          }
        }
      }

      // 6. Depo arama etiketlerini artımsal olarak güncelle (Deep Search - Incremental)
      if (sourceId != null || destId != null) {
        // Tarihi, açıklamayı, kullanıcıyı ve tüm ürünleri tek satıra indir
        final String formattedDate =
            '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} '
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

        final String itemsSummary = items
            .map(
              (item) => [
                item.code,
                item.name,
                item.unit,
                item.quantity.toString(),
                if (item.unitCost != null) item.unitCost!.toString(),
              ].where((part) => part.toString().trim().isNotEmpty).join(' '),
            )
            .where((segment) => segment.trim().isNotEmpty)
            .join(' ');

        Future<void> appendDepotTag({
          required int depotId,
          required String typeLabel,
        }) async {
          final parts = [
            typeLabel,
            formattedDate,
            description,
            currentUser,
            itemsSummary,
          ].where((e) => e.toString().trim().isNotEmpty);

          final historyTag = parts.join(' ').toLowerCase();

          if (historyTag.isEmpty) return;

          await ctx.execute(
            Sql.named('''
              UPDATE depots
              SET search_tags = COALESCE(search_tags, '') || ' ' || @tag
              WHERE id = @id
            '''),
            parameters: {'tag': historyTag, 'id': depotId},
          );
        }

        // Kaynak depo için "çıkış", hedef depo için "giriş" etiketi kullan
        if (sourceId != null) {
          await appendDepotTag(depotId: sourceId, typeLabel: 'çıkış');
        }
        if (destId != null) {
          await appendDepotTag(depotId: destId, typeLabel: 'giriş');
        }
      }
      return shipmentId;
    });

    // İşlem türleri cache'ini temizle (Yeni işlem tipi eklenmiş olabilir)
    islemTurleriCacheTemizle();

    return resultId;
  }

  Future<void> sevkiyatSil(
    int id, {
    bool skipProductionCheck = false,
    TxSession? session,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null && session == null) return;

    Future<void> innerLogic(TxSession ctx) async {
      // [FIX] Production Check (Butterfly Effect)
      // If this shipment is part of a production, we must delete the entire production movement
      if (!skipProductionCheck) {
        final prodRes = await ctx.execute(
          Sql.named('''
            SELECT id FROM production_stock_movements 
            WHERE related_shipment_ids @> @idJson::jsonb 
            LIMIT 1
          '''),
          parameters: {
            'idJson': jsonEncode([id]),
          },
        );

        if (prodRes.isNotEmpty) {
          await UretimlerVeritabaniServisi().uretimHareketiSil(
            id,
            session: ctx,
          );
          return; // uretimHareketiSil will call sevkiyatSil(skipProductionCheck: true)
        }
      }

      final result = await ctx.execute(
        Sql.named(
          'SELECT source_warehouse_id, dest_warehouse_id, items, integration_ref FROM shipments WHERE id = @id',
        ),
        parameters: {'id': id},
      );

      if (result.isEmpty) return;

      final row = result.first;
      final sourceId = row[0] as int?;
      final destId = row[1] as int?;
      final itemsRaw = row[2];
      final String integrationRef = row[3]?.toString() ?? '';

      // [CRITICAL FIX] Satış/Alış hareketlerinde sadece sevkiyatı silmek,
      // cari hesaplarda yetim kayıt bırakır. Entegrasyon ref bazlı tam silme yapılmalı.
      final String normalizedRef = integrationRef.trim();
      if (normalizedRef.startsWith('SALE-')) {
        await SatisYapVeritabaniServisi().satisIsleminiSil(
          normalizedRef,
          session: ctx,
        );
        return;
      }
      if (normalizedRef.startsWith('RETAIL-')) {
        await PerakendeSatisVeritabaniServisi().satisIsleminiSil(
          normalizedRef,
          session: ctx,
        );
        return;
      }
      if (normalizedRef.startsWith('PURCHASE-')) {
        await AlisYapVeritabaniServisi().alisIsleminiSil(
          normalizedRef,
          session: ctx,
        );
        return;
      }

      final List items = itemsRaw is String
          ? jsonDecode(itemsRaw) as List
          : itemsRaw as List;

      for (final item in items) {
        final code = item['code'] as String;
        final quantity = double.tryParse(item['quantity'].toString()) ?? 0.0;

        // 1. Reverse Global Stock
        double globalChange = 0;
        if (sourceId == null && destId != null) {
          globalChange = -quantity; // Was Input -> Decrease
        } else if (sourceId != null && destId == null) {
          globalChange = quantity; // Was Output -> Increase
        }

        if (globalChange != 0) {
          await ctx.execute(
            Sql.named('''
              UPDATE products 
              SET stok = stok + @change 
              WHERE kod = @code
            '''),
            parameters: {'change': globalChange, 'code': code},
          );

          // If code belongs to a production (and not a product), reverse production stock too
          await ctx.execute(
            Sql.named('''
              UPDATE productions
              SET stok = stok + @change
              WHERE kod = @code
                AND NOT EXISTS (SELECT 1 FROM products WHERE kod = @code)
            '''),
            parameters: {'change': globalChange, 'code': code},
          );
        }

        // 2. Reverse Warehouse Stock
        // Dest: Decrease
        if (destId != null) {
          await ctx.execute(
            Sql.named('''
                UPDATE warehouse_stocks 
                SET quantity = quantity - @qty
                WHERE warehouse_id = @wid AND product_code = @code
              '''),
            parameters: {'wid': destId, 'code': code, 'qty': quantity},
          );
        }
        // Source: Increase
        if (sourceId != null) {
          await ctx.execute(
            Sql.named('''
                UPDATE warehouse_stocks 
                SET quantity = quantity + @qty
                WHERE warehouse_id = @wid AND product_code = @code
              '''),
            parameters: {'wid': sourceId, 'code': code, 'qty': quantity},
          );
        }
      }

      await ctx.execute(
        Sql.named('DELETE FROM stock_movements WHERE shipment_id = @id'),
        parameters: {'id': id},
      );

      await ctx.execute(
        Sql.named('DELETE FROM shipments WHERE id = @id'),
        parameters: {'id': id},
      );
    }

    if (session != null) {
      await innerLogic(session);
    } else {
      await _pool!.runTx((ctx) async => await innerLogic(ctx));
    }
  }

  // --- OTO KOD ÜRETME ---

  Future<String> siradakiDepoKodunuGetir({
    String prefix = '',
    bool alfanumerik = false,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) {
      if (!alfanumerik) return '1';
      final p = prefix.isEmpty ? 'DP-' : prefix;
      return '$p${'1'.padLeft(3, '0')}';
    }

    if (!alfanumerik) {
      final result = await _pool!.execute(
        "SELECT COALESCE(MAX(CAST(kod AS BIGINT)), 0) FROM depots WHERE kod ~ '^[0-9]+\$'",
      );
      final maxCode = int.tryParse(result.first[0]?.toString() ?? '0') ?? 0;
      return (maxCode + 1).toString();
    }

    final effectivePrefix = prefix.isEmpty ? 'DP-' : prefix;
    final pattern = '^${RegExp.escape(effectivePrefix)}[0-9]+\$';

    final result = await _pool!.execute(
      Sql.named('''
        SELECT COALESCE(MAX(CAST(SUBSTRING(kod FROM '[0-9]+\$') AS BIGINT)), 0) 
        FROM depots
        WHERE kod ~ @pattern
      '''),
      parameters: {'pattern': pattern},
    );

    final maxSuffix = int.tryParse(result.first[0]?.toString() ?? '0') ?? 0;
    final nextId = maxSuffix + 1;
    return '$effectivePrefix${nextId.toString().padLeft(3, '0')}';
  }

  Future<List<Map<String, dynamic>>> sonIslemleriGetir() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    final result = await _pool!.execute(
      "SELECT s.id, s.date, s.description, s.items, s.created_by, d1.ad as source_name, d2.ad as dest_name, s.source_warehouse_id, s.dest_warehouse_id, "
      "(SELECT MAX(sm.integration_ref) FROM stock_movements sm WHERE sm.shipment_id = s.id) AS integration_ref, "
      "EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris') AS has_uretim_giris, "
      "(SELECT ca.adi FROM current_account_transactions cat JOIN current_accounts ca ON ca.id = cat.current_account_id WHERE cat.integration_ref = (SELECT MAX(sm.integration_ref) FROM stock_movements sm WHERE sm.shipment_id = s.id) LIMIT 1) as related_party_name, "
      "(SELECT ca.kod_no FROM current_account_transactions cat JOIN current_accounts ca ON ca.id = cat.current_account_id WHERE cat.integration_ref = (SELECT MAX(sm.integration_ref) FROM stock_movements sm WHERE sm.shipment_id = s.id) LIMIT 1) as related_party_code "
      "FROM shipments s "
      "LEFT JOIN depots d1 ON s.source_warehouse_id = d1.id "
      "LEFT JOIN depots d2 ON s.dest_warehouse_id = d2.id "
      "ORDER BY s.created_at DESC LIMIT 20",
    );

    List<Map<String, dynamic>> transactions = [];

    for (final row in result) {
      final itemsRaw = row[3];
      final List items = itemsRaw is String
          ? jsonDecode(itemsRaw) as List
          : itemsRaw as List;
      final quantity = items.fold<double>(
        0,
        (sum, item) =>
            sum + (double.tryParse(item['quantity'].toString()) ?? 0.0),
      );
      final date = row[1] as DateTime;
      final String? sourceName = row[5] as String?;
      final String? destName = row[6] as String?;
      final Object? rawDescription = row[2];
      final Object? rawCreatedBy = row[4];
      final String integrationRef = row[9]?.toString() ?? '';
      final bool hasUretimGiris = row[10] == true;
      final String? relatedPartyName = row[11] as String?;
      final String? relatedPartyCode = row[12] as String?;

      String? customTypeLabel;
      String warehouseLabel;
      bool isIncoming;

      if (sourceName == null && destName != null) {
        customTypeLabel = 'Giriş'; // Was: Devir (Girdi)
        warehouseLabel = destName;
        isIncoming = true;
      } else if (sourceName != null && destName == null) {
        customTypeLabel = 'Çıkış'; // Was: Devir (Çıktı)
        warehouseLabel = sourceName;
        isIncoming = false;
      } else if (sourceName != null && destName != null) {
        customTypeLabel = 'Transfer'; // Was: Sevkiyat
        warehouseLabel = '$sourceName -> $destName';
        isIncoming = true;
      } else {
        customTypeLabel = 'İşlem';
        warehouseLabel = '-';
        isIncoming = true;
      }

      final descStr = rawDescription?.toString() ?? '';
      if (customTypeLabel == 'Giriş' &&
          (integrationRef == 'opening_stock' || descStr.contains('Açılış'))) {
        customTypeLabel = 'Açılış Stoğu'; // Was: Açılış Stoğu (Girdi)
      } else if (integrationRef == 'production_output' ||
          descStr.contains('Üretim (Çıktı)')) {
        customTypeLabel = 'Üretim (Çıktı)';
      } else if (hasUretimGiris ||
          descStr.contains('Üretim (Girdi)') ||
          descStr.contains('Üretim (Giriş)')) {
        customTypeLabel = 'Üretim (Girdi)';
      }

      final desc = rawDescription?.toString() ?? '';

      String productSummary;
      String unit = 'Adet';

      String code = '';
      String name = '';

      if (items.length == 1) {
        final item = items.first as Map;
        code = item['code']?.toString() ?? '';
        name = item['name']?.toString() ?? '';
        unit = item['unit']?.toString() ?? 'Adet';

        if (code.isNotEmpty && name.isNotEmpty) {
          productSummary = '$code - $name';
        } else if (name.isNotEmpty) {
          productSummary = name;
        } else if (code.isNotEmpty) {
          productSummary = code;
        } else {
          productSummary = '1 ürün';
        }
      } else {
        productSummary = '${items.length} ürün';
        if (items.isNotEmpty) {
          unit = (items.first as Map)['unit']?.toString() ?? 'Adet';
        }
      }

      final quantityText = quantity.toStringAsFixed(0);

      transactions.add({
        'id': row[0] as int,
        'type': 'transfer',
        'isIncoming': isIncoming,
        'amount': '$quantityText $unit',
        'quantity': quantityText,
        'unit': unit,
        'date':
            '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
        'user': rawCreatedBy?.toString() ?? 'Sistem',
        'description': desc,
        'warehouse': warehouseLabel,
        'customTypeLabel': customTypeLabel,
        'product': productSummary,
        'product_code': code,
        'product_name': name,
        'source_warehouse_id': row[7] as int?,
        'dest_warehouse_id': row[8] as int?,
        'relatedPartyName': relatedPartyName,
        'relatedPartyCode': relatedPartyCode,
      });
    }
    return transactions;
  }

  Future<List<Map<String, dynamic>>> depoIslemleriniGetir(
    int depoId, {
    String? aramaTerimi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? islemTuru,
    String? kullanici,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    String whereClause = '1=1'; // Default

    if (islemTuru != null) {
      if (islemTuru == 'Sevkiyat' || islemTuru == 'Transfer') {
        whereClause =
            's.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NOT NULL';
      } else if (islemTuru == 'Açılış Stoğu' || islemTuru.contains('Açılış')) {
        whereClause =
            "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%')";
      } else if (islemTuru == 'Giriş' ||
          islemTuru == 'Devir Girdi' ||
          islemTuru == 'Devir (Girdi)' ||
          islemTuru.contains('Giriş') ||
          islemTuru == 'Alış Yapıldı' ||
          islemTuru == 'Üretim Girişi') {
        whereClause =
            "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%')";

        if (islemTuru == 'Üretim Girişi') {
          whereClause =
              "$whereClause AND EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris')";
        } else if (islemTuru == 'Alış Yapıldı') {
          whereClause =
              "$whereClause AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
        } else if (islemTuru == 'Devir Girdi' || islemTuru == 'Devir (Girdi)') {
          whereClause =
              "$whereClause AND NOT EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
        }
      } else if (islemTuru == 'Çıkış' ||
          islemTuru == 'Devir Çıktı' ||
          islemTuru == 'Devir (Çıktı)' ||
          islemTuru.contains('Çıkış') ||
          islemTuru == 'Satış Yapıldı' ||
          islemTuru == 'Üretim Çıkışı') {
        whereClause =
            's.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL';

        if (islemTuru == 'Üretim Çıkışı') {
          whereClause =
              "$whereClause AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%')";
        } else if (islemTuru == 'Satış Yapıldı') {
          whereClause =
              "$whereClause AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
        } else if (islemTuru == 'Devir Çıktı' || islemTuru == 'Devir (Çıktı)') {
          whereClause =
              "$whereClause AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
        }
      }
    } else {
      // Hepsi (Fallback filtering to ensure current depot is involved)
      whereClause =
          '(s.source_warehouse_id = @depoId OR s.dest_warehouse_id = @depoId)';
    }

    // Ensure we are only looking at this depot's transactions
    if (islemTuru != null) {
      // Append the depot condition safely
      whereClause =
          '($whereClause) AND (s.source_warehouse_id = @depoId OR s.dest_warehouse_id = @depoId)';
    }

    // [FIX] Added related_party_name and related_party_code subqueries
    // [FIX] Use s.integration_ref preference if available, fallback to subquery
    String query =
        '''
      SELECT 
        s.id, 
        s.date, 
        s.description, 
        s.items, 
        s.created_by,
        d1.ad as source_name, 
        d2.ad as dest_name,
        s.source_warehouse_id,
        s.dest_warehouse_id,
        COALESCE(s.integration_ref, (SELECT MAX(sm.integration_ref) FROM stock_movements sm WHERE sm.shipment_id = s.id)) AS integration_ref,
        EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris') AS has_uretim_giris,
        (
          SELECT ca.adi 
          FROM current_account_transactions cat 
          JOIN current_accounts ca ON ca.id = cat.current_account_id 
          WHERE cat.integration_ref = s.integration_ref 
             OR cat.integration_ref = (SELECT MAX(sm.integration_ref) FROM stock_movements sm WHERE sm.shipment_id = s.id)
          LIMIT 1
        ) as related_party_name,
        (
          SELECT ca.kod_no 
          FROM current_account_transactions cat 
          JOIN current_accounts ca ON ca.id = cat.current_account_id 
          WHERE cat.integration_ref = s.integration_ref
             OR cat.integration_ref = (SELECT MAX(sm.integration_ref) FROM stock_movements sm WHERE sm.shipment_id = s.id)
          LIMIT 1
        ) as related_party_code,
        EXISTS (
          SELECT 1
          FROM cash_register_transactions crt
          WHERE crt.integration_ref = s.integration_ref
             OR crt.integration_ref = (SELECT MAX(sm.integration_ref) FROM stock_movements sm WHERE sm.shipment_id = s.id)
        ) AS has_cash_tx,
        EXISTS (
          SELECT 1
          FROM bank_transactions bt
          WHERE bt.integration_ref = s.integration_ref
             OR bt.integration_ref = (SELECT MAX(sm.integration_ref) FROM stock_movements sm WHERE sm.shipment_id = s.id)
        ) AS has_bank_tx,
        EXISTS (
          SELECT 1
          FROM credit_card_transactions cct
          WHERE cct.integration_ref = s.integration_ref
             OR cct.integration_ref = (SELECT MAX(sm.integration_ref) FROM stock_movements sm WHERE sm.shipment_id = s.id)
        ) AS has_card_tx
      FROM shipments s
      LEFT JOIN depots d1 ON s.source_warehouse_id = d1.id
      LEFT JOIN depots d2 ON s.dest_warehouse_id = d2.id
      WHERE $whereClause
    ''';

    Map<String, dynamic> params = {'depoId': depoId};

    if (baslangicTarihi != null) {
      query += ' AND s.date >= @startDate';
      params['startDate'] = baslangicTarihi.toIso8601String();
    }

    if (bitisTarihi != null) {
      query += ' AND s.date <= @endDate';
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
      query += ' AND COALESCE(s.created_by, \'\') = @kullanici';
      params['kullanici'] = kullanici.trim();
    }

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      query += '''
        AND (
          LOWER(COALESCE(s.description, '')) LIKE @search 
          OR TO_CHAR(s.date, 'DD.MM.YYYY HH24:MI') LIKE @search
          OR LOWER(COALESCE(s.created_by, '')) LIKE @search
           -- Transaction Type Search Logic - BROADER MATCHING & UI LABEL SUPPORT
          OR (
             CASE 
                -- Satış: UI'da 'Satış Yapıldı' olarak görünüyor
                WHEN s.integration_ref LIKE 'SALE-%' OR s.integration_ref LIKE 'RETAIL-%' OR s.description ILIKE '%Satış%' OR s.description ILIKE '%Satis%' THEN 'satış faturası satış yapıldı'
                -- Alış: UI'da 'Alış Yapıldı' olarak görünüyor
                WHEN s.integration_ref LIKE 'PURCHASE-%' OR s.description ILIKE '%Alış%' OR s.description ILIKE '%Alis%' THEN 'alış faturası alış yapıldı'
                -- Açılış: UI'da 'Açılış Stoğu'
                WHEN s.integration_ref = 'opening_stock' OR s.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                -- Üretim
                WHEN s.integration_ref = 'production_output' OR s.description ILIKE '%Üretim (Çıktı)%' THEN 'üretim çıktısı üretim çıkışı'
                WHEN s.description ILIKE '%Üretim (Girdi)%' OR s.description ILIKE '%Üretim (Giriş)%' THEN 'üretim girdisi üretim girişi'
                WHEN EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type LIKE 'uretim%') THEN 'üretim'
                -- Transferler
                WHEN s.source_warehouse_id = @depoId AND s.dest_warehouse_id IS NOT NULL THEN 'transfer sevkiyat çıkış devir çıkış'
                WHEN s.dest_warehouse_id = @depoId AND s.source_warehouse_id IS NOT NULL THEN 'transfer sevkiyat giriş devir giriş'
                WHEN s.dest_warehouse_id = @depoId THEN 'giriş stok giriş'
                ELSE 'çıkış stok çıkış'
             END
          ) LIKE @search
          OR LOWER(COALESCE(s.description, '')) LIKE @search
          OR EXISTS (
              SELECT 1 FROM jsonb_array_elements(s.items) item 
              WHERE LOWER(item->>'name') LIKE @search 
              OR LOWER(item->>'code') LIKE @search
              OR LOWER(item->>'unit') LIKE @search
              OR (item->>'quantity')::text LIKE @search
          )
        )
      ''';
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
    }

    query += ' ORDER BY s.date DESC LIMIT 50';

    final result = await _pool!.execute(Sql.named(query), parameters: params);

    List<Map<String, dynamic>> transactions = [];

    for (final row in result) {
      final itemsRaw = row[3];
      final List items = itemsRaw is String
          ? jsonDecode(itemsRaw) as List
          : itemsRaw as List;
      final quantity = items.fold<double>(
        0,
        (sum, item) =>
            sum + (double.tryParse(item['quantity'].toString()) ?? 0.0),
      );
      final date = row[1] as DateTime;
      final String? sourceName = row[5] as String?;
      final String? destName = row[6] as String?;
      final Object? rawDescription = row[2];
      final Object? rawCreatedBy = row[4];
      final int? sourceId = row[7] as int?;
      final int? destId = row[8] as int?;
      final String integrationRef = row[9]?.toString() ?? '';
      final bool hasUretimGiris = row[10] == true;
      final String? relatedPartyName = row[11] as String?;
      final String? relatedPartyCode = row[12] as String?;
      final bool hasCashTx = row[13] == true;
      final bool hasBankTx = row[14] == true;
      final bool hasCardTx = row[15] == true;

      String? customTypeLabel;
      String warehouseLabel;
      bool isIncoming;

      if (sourceName == null && destName != null) {
        customTypeLabel = 'Devir (Girdi)';
        warehouseLabel = destName;
        isIncoming = true;
      } else if (sourceName != null && destName == null) {
        customTypeLabel = 'Devir (Çıktı)';
        warehouseLabel = sourceName;
        isIncoming = false;
      } else if (sourceName != null && destName != null) {
        customTypeLabel = 'Sevkiyat';
        warehouseLabel = '$sourceName -> $destName';
        isIncoming = true;
      } else {
        customTypeLabel = 'İşlem';
        warehouseLabel = '-';
        isIncoming = true;
      }

      if (customTypeLabel == 'Sevkiyat') {
        if (destId == depoId) {
          isIncoming = true;
        } else {
          isIncoming = false;
        }
      }

      final descStr = rawDescription?.toString() ?? '';
      final lower = descStr.toLowerCase().trim();

      if (customTypeLabel == 'Devir (Girdi)' &&
          (integrationRef == 'opening_stock' || descStr.contains('Açılış'))) {
        customTypeLabel = 'Açılış Stoğu (Girdi)';
      } else if (integrationRef == 'production_output' ||
          descStr.contains('Üretim (Çıktı)')) {
        customTypeLabel = 'Üretim (Çıktı)';
      } else if (hasUretimGiris ||
          descStr.contains('Üretim (Girdi)') ||
          descStr.contains('Üretim (Giriş)')) {
        customTypeLabel = 'Üretim (Girdi)';
      } else {
        // [FIX] Explicitly check integration references for Sale/Purchase to label correctly
        if (integrationRef.startsWith('SALE-') ||
            integrationRef.startsWith('RETAIL-') ||
            lower.startsWith('satış') ||
            lower.startsWith('satis')) {
          customTypeLabel = 'Satış Faturası';
        } else if (integrationRef.startsWith('PURCHASE-') ||
            lower.startsWith('alış') ||
            lower.startsWith('alis')) {
          customTypeLabel = 'Alış Faturası';
        }
      }

      String sourceSuffix = '';
      final bool isSale =
          integrationRef.startsWith('SALE-') ||
          integrationRef.startsWith('RETAIL-') ||
          customTypeLabel == 'Satış Faturası';
      final bool isPurchase =
          integrationRef.startsWith('PURCHASE-') ||
          customTypeLabel == 'Alış Faturası';
      if (isSale || isPurchase) {
        if (hasCashTx) {
          sourceSuffix = '(Nakit)';
        } else if (hasBankTx) {
          sourceSuffix = '(Banka)';
        } else if (hasCardTx) {
          sourceSuffix = '(K.Kartı)';
        } else {
          sourceSuffix = '(Cari)';
        }
      }

      final desc = rawDescription?.toString() ?? '';

      String productSummary;
      String unit = 'Adet';

      String code = '';
      String name = '';
      double unitPrice = 0.0;
      double unitPriceVat = 0.0;

      if (items.isNotEmpty) {
        // First item logic for basic display
        final firstItem = items.first as Map;
        code = firstItem['code']?.toString() ?? '';
        name = firstItem['name']?.toString() ?? '';
        unit = firstItem['unit']?.toString() ?? 'Adet';

        // Price Logic
        // We will separate logic: if it's a single item, take its price.
        // If multiple items, we calculate weighted average for "Unit Price" representation
        if (items.length == 1) {
          final double price =
              double.tryParse(
                firstItem['unitCost']?.toString() ??
                    firstItem['price']?.toString() ??
                    '0',
              ) ??
              0.0;
          final double vatRate =
              double.tryParse(
                firstItem['vatRate']?.toString() ??
                    firstItem['vat_rate']?.toString() ??
                    '0',
              ) ??
              0.0;
          unitPrice = price;
          unitPriceVat = price * (1 + (vatRate / 100));

          if (code.isNotEmpty && name.isNotEmpty) {
            productSummary = '$code - $name';
          } else if (name.isNotEmpty) {
            productSummary = name;
          } else if (code.isNotEmpty) {
            productSummary = code;
          } else {
            productSummary = '1 ürün';
          }
        } else {
          // Multiple Items
          productSummary = '${items.length} ürün';

          double totalBasePrice = 0.0;
          double totalVatPrice = 0.0;
          double totalQuantity = 0.0;

          for (var item in items) {
            final q = double.tryParse(item['quantity'].toString()) ?? 0.0;
            final p =
                double.tryParse(
                  item['unitCost']?.toString() ??
                      item['price']?.toString() ??
                      '0',
                ) ??
                0.0;
            final v =
                double.tryParse(
                  item['vatRate']?.toString() ??
                      item['vat_rate']?.toString() ??
                      '0',
                ) ??
                0.0;

            totalBasePrice += q * p;
            totalVatPrice += q * (p * (1 + (v / 100)));
            totalQuantity += q;
          }

          if (totalQuantity > 0) {
            unitPrice = totalBasePrice / totalQuantity;
            unitPriceVat = totalVatPrice / totalQuantity;
          }
        }
      } else {
        productSummary = '0 ürün';
      }

      final quantityText = quantity.toStringAsFixed(0);

      String? displayRelatedPartyName = relatedPartyName;
      String? displayRelatedPartyCode = relatedPartyCode;
      if (integrationRef.startsWith('RETAIL-') && isSale) {
        final String perakendePaySuffix = hasCashTx
            ? '(Nakit)'
            : hasCardTx
            ? '(K.Kartı)'
            : hasBankTx
            ? '(Banka)'
            : '(Cari)';
        displayRelatedPartyName = 'Perakende Satış Yapıldı $perakendePaySuffix';
        displayRelatedPartyCode = '';
      }

      transactions.add({
        'id': row[0] as int,
        'type': 'transfer',
        'isIncoming': isIncoming,
        'amount': '$quantityText $unit',
        'quantity': quantityText,
        'unit': unit,
        'date':
            '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
        'user': rawCreatedBy?.toString() ?? 'Sistem',
        'description': desc,
        'warehouse': warehouseLabel,
        'customTypeLabel': customTypeLabel,
        'product': productSummary,
        'product_code': code,
        'product_name': name,
        'source_warehouse_id': sourceId,
        'dest_warehouse_id': destId,
        // [FIX] Pass the fetched related party info
        'relatedPartyName': displayRelatedPartyName,
        'relatedPartyCode': displayRelatedPartyCode,
        'unitPrice': unitPrice,
        'unitPriceVat': unitPriceVat,
        'sourceSuffix': sourceSuffix,
      });
    }
    return transactions;
  }

  Future<List<Map<String, dynamic>>> urunHareketleriniGetir(
    String urunKodu, {
    double kdvOrani = 0,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    List<int>? warehouseIds,
    String? islemTuru,
    String? kullanici,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    int? productId;
    try {
      final productRes = await _pool!.execute(
        Sql.named('SELECT id FROM products WHERE kod = @kod LIMIT 1'),
        parameters: {'kod': urunKodu},
      );
      if (productRes.isNotEmpty) {
        productId = productRes.first[0] as int;
      }
    } catch (e) {
      debugPrint('Ürün ID getirilemedi (cihaz detayı): $e');
    }

    String query = '''
        SELECT 
          s.id,
          s.date,
          s.description,
          s.items,
          sw.ad as source_name,
          dw.ad as dest_name,
          s.created_by,
          COALESCE(s.integration_ref, smref.integration_ref) AS integration_ref,
          EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris') AS has_uretim_giris,
          (
            SELECT ca.adi 
            FROM current_account_transactions cat 
            JOIN current_accounts ca ON ca.id = cat.current_account_id 
            WHERE cat.integration_ref = COALESCE(s.integration_ref, smref.integration_ref)
            LIMIT 1
          ) as related_party_name,
          (
            SELECT ca.kod_no 
            FROM current_account_transactions cat 
            JOIN current_accounts ca ON ca.id = cat.current_account_id 
            WHERE cat.integration_ref = COALESCE(s.integration_ref, smref.integration_ref)
            LIMIT 1
          ) as related_party_code,
          EXISTS (SELECT 1 FROM cash_register_transactions crt WHERE crt.integration_ref = COALESCE(s.integration_ref, smref.integration_ref)) AS has_cash_tx,
          EXISTS (SELECT 1 FROM bank_transactions bt WHERE bt.integration_ref = COALESCE(s.integration_ref, smref.integration_ref)) AS has_bank_tx,
          EXISTS (SELECT 1 FROM credit_card_transactions cct WHERE cct.integration_ref = COALESCE(s.integration_ref, smref.integration_ref)) AS has_card_tx
        FROM shipments s
        LEFT JOIN depots sw ON s.source_warehouse_id = sw.id
        LEFT JOIN depots dw ON s.dest_warehouse_id = dw.id
        LEFT JOIN LATERAL (
          SELECT MAX(sm.integration_ref) AS integration_ref
          FROM stock_movements sm
          WHERE sm.shipment_id = s.id
        ) smref ON true
        WHERE s.items @> @searchJson::jsonb
      ''';

    Map<String, dynamic> params = {
      'searchJson': jsonEncode([
        {'code': urunKodu},
      ]),
    };

    if (baslangicTarihi != null) {
      query += ' AND s.date >= @startDate';
      params['startDate'] = baslangicTarihi.toIso8601String();
    }

    if (bitisTarihi != null) {
      query += ' AND s.date <= @endDate';
      // Ensure inclusive end of day
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

    // Warehouse Filtering for Details
    // Logic: If warehouseIds provided, show transactions where Source OR Dest is in the list.
    if (warehouseIds != null && warehouseIds.isNotEmpty) {
      query +=
          ' AND (s.source_warehouse_id = ANY(@warehouseIdArray) OR s.dest_warehouse_id = ANY(@warehouseIdArray))';
      params['warehouseIdArray'] = warehouseIds;
    }

    if (kullanici != null && kullanici.trim().isNotEmpty) {
      query += ' AND COALESCE(s.created_by, \'\') = @kullanici';
      params['kullanici'] = kullanici.trim();
    }

    if (islemTuru != null && islemTuru.trim().isNotEmpty) {
      final String t = islemTuru.trim();
      String? typeCondition;

      if (t == 'Açılış Stoğu (Girdi)') {
        typeCondition =
            "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%')";
      } else if (t == 'Devir Girdi') {
        typeCondition =
            "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%') AND NOT EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris')";
      } else if (t == 'Devir Çıktı') {
        typeCondition =
            "s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%')";
      } else if (t == 'Sevkiyat') {
        typeCondition =
            's.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NOT NULL';
      } else if (t == 'Satış Yapıldı') {
        typeCondition =
            "(EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
      } else if (t == 'Alış Yapıldı') {
        typeCondition =
            "(EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
      } else if (t == 'Üretim Girişi') {
        typeCondition =
            "EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris')";
      } else if (t == 'Üretim Çıkışı') {
        typeCondition =
            "(EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%')";
      }

      if (typeCondition != null) {
        query += ' AND $typeCondition';
      }
    }

    query += ' ORDER BY s.date DESC LIMIT 250';

    final result = await _pool!.execute(Sql.named(query), parameters: params);

    List<Map<String, dynamic>> transactions = [];

    for (final row in result) {
      final itemsRaw = row[3];
      final List items = itemsRaw is String
          ? jsonDecode(itemsRaw) as List
          : itemsRaw as List;
      final productItems = items
          .where((item) => item is Map && item['code'] == urunKodu)
          .cast<Map>()
          .toList(growable: false);

      if (productItems.isEmpty) continue;

      Future<List<Map<String, dynamic>>> extractDevicesForItem(Map item) async {
        final dynamic rawDevices = item['devices'] ?? item['cihazlar'];
        if (rawDevices is List) {
          return rawDevices
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList(growable: false);
        }

        final String serialNumber =
            (item['serialNumber'] ?? item['serial_number'] ?? '')
                .toString()
                .trim();
        if (serialNumber.isEmpty) return [];

        if (productId != null) {
          try {
            final deviceRes = await _pool!.execute(
              Sql.named('''
                SELECT
                  identity_type,
                  identity_value,
                  condition,
                  color,
                  capacity,
                  warranty_end_date,
                  has_box,
                  has_invoice,
                  has_original_charger,
                  is_sold,
                  sale_ref
                FROM product_devices
                WHERE product_id = @pid AND identity_value = @serial
                ORDER BY id DESC
                LIMIT 1
              '''),
              parameters: {'pid': productId, 'serial': serialNumber},
            );

            if (deviceRes.isNotEmpty) {
              return [deviceRes.first.toColumnMap()];
            }
          } catch (e) {
            debugPrint('Cihaz detayı getirilemedi: $e');
          }
        }

        final bool looksLikeImei = RegExp(
          r'^[0-9]{14,16}$',
        ).hasMatch(serialNumber);
        return [
          looksLikeImei ? {'imei': serialNumber} : {'serial': serialNumber},
        ];
      }

      double toDouble(dynamic value) {
        if (value == null) return 0.0;
        if (value is num) return value.toDouble();
        return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
      }

      final date = row[1] as DateTime;
      final sourceName = row[4] as String?;
      final destName = row[5] as String?;
      final createdBy = row[6] as String?;
      final String integrationRef = row[7]?.toString() ?? '';
      final bool hasUretimGiris = row[8] == true;
      final String? relatedPartyName = row[9] as String?;
      final String? relatedPartyCode = row[10] as String?;
      final bool hasCashTx = row[11] == true;
      final bool hasBankTx = row[12] == true;
      final bool hasCardTx = row[13] == true;

      String? customTypeLabel;
      String warehouseLabel = '';
      bool isIncoming = true;

      if (sourceName == null && destName != null) {
        customTypeLabel = 'Devir Girdi';
        warehouseLabel = destName;
        isIncoming = true;
      } else if (sourceName != null && destName == null) {
        customTypeLabel = 'Devir Çıktı';
        warehouseLabel = sourceName;
        isIncoming = false;
      } else if (sourceName != null && destName != null) {
        customTypeLabel = 'Sevkiyat';
        warehouseLabel = '$sourceName -> $destName';
        isIncoming = true;
      } else {
        customTypeLabel = 'İşlem';
        warehouseLabel = '-';
      }

      String description = row[2] as String? ?? '';
      final String rawDescLower = description.toLowerCase().trim();
      if (integrationRef == 'production_output' ||
          description.contains('Üretim (Çıktı)')) {
        customTypeLabel = 'Üretim Çıkışı';
        // User asked not to modify description
      } else if (hasUretimGiris ||
          description.contains('Üretim (Girdi)') ||
          description.contains('Üretim (Giriş)')) {
        customTypeLabel = 'Üretim Girişi';
        // User asked not to modify description
      } else if (customTypeLabel == 'Devir Girdi' &&
          (integrationRef == 'opening_stock' ||
              (row[2] as String?)?.contains('Açılış') == true)) {
        customTypeLabel = 'Açılış Stoğu (Girdi)';
      } else if (integrationRef.startsWith('SALE-') ||
          integrationRef.startsWith('RETAIL-') ||
          rawDescLower.startsWith('satış') ||
          rawDescLower.startsWith('satis') ||
          (relatedPartyName != null && !isIncoming && sourceName != null)) {
        customTypeLabel = 'Satış Yapıldı';
        // User asked not to modify description
      } else if (integrationRef.startsWith('PURCHASE-') ||
          rawDescLower.startsWith('alış') ||
          rawDescLower.startsWith('alis') ||
          (relatedPartyName != null && isIncoming && destName != null)) {
        customTypeLabel = 'Alış Yapıldı';
        // User asked not to modify description
      }

      String sourceSuffix = '';
      if (customTypeLabel == 'Satış Yapıldı' ||
          customTypeLabel == 'Alış Yapıldı') {
        if (hasCashTx) {
          sourceSuffix = '(Nakit)';
        } else if (hasBankTx) {
          sourceSuffix = '(Banka)';
        } else if (hasCardTx) {
          sourceSuffix = '(K.Kartı)';
        } else {
          sourceSuffix = '(Cari)';
        }
      }

      String? displayRelatedPartyName = relatedPartyName;
      if (integrationRef.startsWith('RETAIL-') &&
          customTypeLabel == 'Satış Yapıldı') {
        final String perakendePaySuffix = hasCashTx
            ? '(Nakit)'
            : hasCardTx
            ? '(K.Kartı)'
            : hasBankTx
            ? '(Banka)'
            : '(Cari)';
        displayRelatedPartyName = 'Perakende Satış Yapıldı $perakendePaySuffix';
      }

      double totalQty = 0.0;
      double totalValue = 0.0;
      final List<Map<String, dynamic>> allDevices = [];
      String unit = '';

      for (final item in productItems) {
        final qty = toDouble(item['quantity']);
        final unitCost = toDouble(item['unitCost']);

        totalQty += qty;
        totalValue += unitCost * qty;
        allDevices.addAll(await extractDevicesForItem(item));

        if (unit.isEmpty) {
          final String u = (item['unit'] ?? item['birim'] ?? '')
              .toString()
              .trim();
          if (u.isNotEmpty) unit = u;
        }
      }

      if (unit.isEmpty) unit = 'Adet';

      final avgUnitCost = totalQty > 0 ? (totalValue / totalQty) : 0.0;
      final unitPriceVat = avgUnitCost * (1 + kdvOrani / 100);

      transactions.add({
        'id': row[0] as int,
        'date':
            '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
        'warehouse': warehouseLabel,
        'quantity': totalQty,
        'unit': unit,
        'unitPrice': avgUnitCost,
        'unitPriceVat': unitPriceVat,
        'isIncoming': isIncoming,
        'customTypeLabel': customTypeLabel,
        'user': createdBy,
        'description': description,
        'relatedPartyName': displayRelatedPartyName,
        'relatedPartyCode': relatedPartyCode,
        'sourceSuffix': sourceSuffix,
        'devices': allDevices,
      });
    }
    return transactions;
  }

  /// Ürün Kartı ekranındaki filtre dropdown'larında "(n)" göstermek için
  /// dinamik filtre istatistiklerini getirir.
  ///
  /// Not: Facet mantığı UrunlerSayfasi ile aynıdır:
  /// - `ozet.toplam`: Sadece tarih aralığına göre toplam (diğer facet seçimleri hariç)
  /// - `islem_turleri`: depo + kullanıcı seçimleri uygulanır, işlem türü hariç
  /// - `depolar`: işlem türü + kullanıcı seçimleri uygulanır, depo seçimi hariç
  /// - `kullanicilar`: işlem türü + depo seçimleri uygulanır, kullanıcı seçimi hariç
  Future<Map<String, Map<String, int>>> urunHareketFiltreIstatistikleriniGetir(
    String urunKodu, {
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    List<int>? warehouseIds,
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

    DateTime endOfDay(DateTime d) {
      return DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
    }

    void addDateConds(List<String> conds, Map<String, dynamic> params) {
      if (baslangicTarihi != null) {
        conds.add('s.date >= @startDate');
        params['startDate'] = baslangicTarihi.toIso8601String();
      }
      if (bitisTarihi != null) {
        conds.add('s.date <= @endDate');
        params['endDate'] = endOfDay(bitisTarihi).toIso8601String();
      }
    }

    void addUserCond(
      List<String> conds,
      Map<String, dynamic> params,
      String? user,
    ) {
      final String? trimmed = user?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        conds.add("COALESCE(s.created_by, '') = @kullanici");
        params['kullanici'] = trimmed;
      }
    }

    void addWarehouseCond(
      List<String> conds,
      Map<String, dynamic> params,
      List<int>? ids,
    ) {
      if (ids != null && ids.isNotEmpty) {
        conds.add(
          '(s.source_warehouse_id = ANY(@warehouseIdArray) OR s.dest_warehouse_id = ANY(@warehouseIdArray))',
        );
        params['warehouseIdArray'] = ids;
      }
    }

    String? buildTypeCondition(String? raw) {
      final String? t = raw?.trim();
      if (t == null || t.isEmpty) return null;

      if (t == 'Açılış Stoğu (Girdi)') {
        return "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%')";
      } else if (t == 'Devir Girdi') {
        return "s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%') AND NOT EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris')";
      } else if (t == 'Devir Çıktı') {
        return "s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%')";
      } else if (t == 'Sevkiyat') {
        return 's.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NOT NULL';
      } else if (t == 'Satış Yapıldı') {
        return "(EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%')";
      } else if (t == 'Alış Yapıldı') {
        return "(EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%')";
      } else if (t == 'Üretim Girişi') {
        return "EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris')";
      } else if (t == 'Üretim Çıkışı') {
        return "(EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%')";
      }

      return null;
    }

    final Map<String, dynamic> baseParams = {
      'searchJson': jsonEncode([
        {'code': urunKodu},
      ]),
    };

    int total = 0;

    try {
      // 0) Ozet toplam (sadece tarih aralığı)
      {
        final params = <String, dynamic>{...baseParams};
        final conds = <String>['s.items @> @searchJson::jsonb'];
        addDateConds(conds, params);

        final res = await _pool!.execute(
          Sql.named('''
            SELECT COUNT(*)
            FROM shipments s
            WHERE ${conds.join(' AND ')}
          '''),
          parameters: params,
        );
        total = (res.isNotEmpty ? (res.first[0] as int) : 0);
      }

      // 1) İşlem Türleri facet (depo + kullanıcı uygulanır, işlem türü hariç)
      final Map<String, int> islemTurleri = {};
      {
        final params = <String, dynamic>{...baseParams};
        final conds = <String>['s.items @> @searchJson::jsonb'];
        addDateConds(conds, params);
        addWarehouseCond(conds, params, warehouseIds);
        addUserCond(conds, params, kullanici);

        final res = await _pool!.execute(
          Sql.named('''
            WITH typed AS (
              SELECT
                s.id,
                CASE
                  WHEN (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output')
                        OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%')
                    THEN 'Üretim Çıkışı'
                  WHEN (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris')
                        OR COALESCE(s.description, '') ILIKE '%Üretim (Girdi)%'
                        OR COALESCE(s.description, '') ILIKE '%Üretim (Giriş)%')
                    THEN 'Üretim Girişi'
                  WHEN (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%'))
                        OR COALESCE(s.description, '') ILIKE 'Satış%'
                        OR COALESCE(s.description, '') ILIKE 'Satis%')
                    THEN 'Satış Yapıldı'
                  WHEN (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%')
                        OR COALESCE(s.description, '') ILIKE 'Alış%'
                        OR COALESCE(s.description, '') ILIKE 'Alis%')
                    THEN 'Alış Yapıldı'
                  WHEN (s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL
                        AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock')
                             OR COALESCE(s.description, '') ILIKE '%Açılış%'))
                    THEN 'Açılış Stoğu (Girdi)'
                  WHEN (s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NOT NULL)
                    THEN 'Sevkiyat'
                  WHEN (s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL
                        AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output')
                                 OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%'))
                    THEN 'Devir Çıktı'
                  WHEN (s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL
                        AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock')
                                 OR COALESCE(s.description, '') ILIKE '%Açılış%')
                        AND NOT EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris'))
                    THEN 'Devir Girdi'
                  ELSE NULL
                END AS type_label
              FROM shipments s
              WHERE ${conds.join(' AND ')}
            )
            SELECT type_label, COUNT(*)
            FROM typed
            WHERE type_label IS NOT NULL
            GROUP BY type_label
          '''),
          parameters: params,
        );

        final tmp = <String, int>{};
        for (final row in res) {
          final String key = row[0]?.toString() ?? '';
          if (key.trim().isEmpty) continue;
          tmp[key] = row[1] as int;
        }

        for (final t in supportedStockTypes) {
          final c = tmp[t] ?? 0;
          if (c > 0) islemTurleri[t] = c;
        }
      }

      // 2) Depolar facet (işlem türü + kullanıcı uygulanır, depo seçimi hariç)
      final Map<String, int> depolar = {};
      {
        final params = <String, dynamic>{...baseParams};
        final conds = <String>['s.items @> @searchJson::jsonb'];
        addDateConds(conds, params);
        addUserCond(conds, params, kullanici);
        final typeCond = buildTypeCondition(islemTuru);
        if (typeCond != null) conds.add(typeCond);

        final res = await _pool!.execute(
          Sql.named('''
            WITH base_shipments AS (
              SELECT s.id, s.source_warehouse_id, s.dest_warehouse_id
              FROM shipments s
              WHERE ${conds.join(' AND ')}
            )
            SELECT warehouse_id::text, COUNT(DISTINCT shipment_id) as cnt
            FROM (
              SELECT id as shipment_id, source_warehouse_id as warehouse_id
              FROM base_shipments
              WHERE source_warehouse_id IS NOT NULL
              UNION ALL
              SELECT id as shipment_id, dest_warehouse_id as warehouse_id
              FROM base_shipments
              WHERE dest_warehouse_id IS NOT NULL
            ) w
            GROUP BY warehouse_id
          '''),
          parameters: params,
        );

        for (final row in res) {
          final String key = row[0]?.toString() ?? '';
          if (key.trim().isEmpty) continue;
          depolar[key] = row[1] as int;
        }
      }

      // 3) Kullanıcı facet (işlem türü + depo uygulanır, kullanıcı seçimi hariç)
      final Map<String, int> kullanicilar = {};
      {
        final params = <String, dynamic>{...baseParams};
        final conds = <String>['s.items @> @searchJson::jsonb'];
        addDateConds(conds, params);
        addWarehouseCond(conds, params, warehouseIds);
        final typeCond = buildTypeCondition(islemTuru);
        if (typeCond != null) conds.add(typeCond);

        final res = await _pool!.execute(
          Sql.named('''
            SELECT s.created_by, COUNT(*)
            FROM shipments s
            WHERE ${conds.join(' AND ')}
            GROUP BY s.created_by
          '''),
          parameters: params,
        );

        for (final row in res) {
          final String key = row[0]?.toString() ?? '';
          if (key.trim().isEmpty) continue;
          kullanicilar[key] = row[1] as int;
        }
      }

      return {
        'depolar': depolar,
        'islem_turleri': islemTurleri,
        'kullanicilar': kullanicilar,
        'ozet': {'toplam': total},
      };
    } catch (e) {
      debugPrint('Ürün hareket filtre istatistikleri hatası: $e');
      return {
        'ozet': {'toplam': total},
      };
    }
  }

  Future<List<Map<String, dynamic>>> urunAra(String query) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    if (query.isEmpty) return [];

    // Gerçek veritabanı araması
    // 'products' tablosunu bildiğimiz için (Urunler servisi tarafından oluşturuluyor)
    // burada sorgu atabiliriz. Ancak normalde servis sınırlarını aşmak iyi değildir.
    // Fakat performans için ve search dialog için direkt sorgu gereklidir.
    final result = await _pool!.execute(
      Sql.named('''
        SELECT kod, ad, birim FROM products 
        WHERE LOWER(kod) LIKE @search 
           OR LOWER(ad) LIKE @search
        LIMIT 20
      '''),
      parameters: {'search': '%${query.toLowerCase()}%'},
    );

    return result.map((row) {
      return {
        'code': row[0] as String,
        'name': row[1] as String,
        'unit': row[2] as String? ?? 'Adet',
      };
    }).toList();
  }

  // İşlem Türleri Cache (1B Kayıt Optimizasyonu)
  static List<String>? _cachedIslemTurleri;
  static DateTime? _cacheZamani;
  static const Duration _cacheSuresi = Duration(minutes: 30);

  // Stok İşlem Türleri Cache (Ürünler/Üretimler filtresi için)
  static List<String>? _cachedStokIslemTurleri;
  static DateTime? _stokCacheZamani;
  static const Duration _stokCacheSuresi = Duration(minutes: 30);

  /// Mevcut İşlem Türlerini Getir (1 Milyar Kayıt Optimizasyonu)
  ///
  /// Artık her çağrıda tüm shipments tablosunu taramak yerine:
  /// 1. Cache varsa onu döner
  /// 2. Yoksa DB'den hızlıca "var mı" kontrolü yapar (LIMIT 1)
  /// 3. Cache 30 dakika geçerlidir
  Future<List<String>> getMevcutIslemTurleri() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    // Cache kontrolü
    if (_cachedIslemTurleri != null && _cacheZamani != null) {
      final gecenSure = DateTime.now().difference(_cacheZamani!);
      if (gecenSure < _cacheSuresi) {
        return _cachedIslemTurleri!;
      }
    }

    try {
      final List<String> types = [];

      final girisExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%') LIMIT 1",
      );
      if (girisExists.isNotEmpty) {
        types.add('Giriş');
      }

      final cikisExists = await _pool!.execute(
        'SELECT 1 FROM shipments s WHERE s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL LIMIT 1',
      );
      if (cikisExists.isNotEmpty) {
        types.add('Çıkış');
      }

      final transferExists = await _pool!.execute(
        'SELECT 1 FROM shipments s WHERE s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NOT NULL LIMIT 1',
      );
      if (transferExists.isNotEmpty) {
        types.add('Transfer');
      }

      final openingExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%') LIMIT 1",
      );
      if (openingExists.isNotEmpty) {
        types.add('Açılış Stoğu');
      }

      _cachedIslemTurleri = types;
      _cacheZamani = DateTime.now();
      return types;
    } catch (e) {
      debugPrint('İşlem türleri sorgu hatası: $e');
      return [];
    }
  }

  /// Ürünler/Üretimler sayfalarındaki "İşlem Türü" filtresi için mevcut tipleri getirir.
  ///
  /// Not: Bu liste, stock_movements içindeki hareketlerin kullanıcıya gösterilen etiketleriyle aynıdır.
  Future<List<String>> getMevcutStokIslemTurleri() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    // Cache kontrolü
    if (_cachedStokIslemTurleri != null && _stokCacheZamani != null) {
      final gecenSure = DateTime.now().difference(_stokCacheZamani!);
      if (gecenSure < _stokCacheSuresi) {
        return _cachedStokIslemTurleri!;
      }
    }

    try {
      final List<String> types = [];

      // [FIX] Ensure we only show transaction types that have items belonging to 'products' table
      const String productItemCheck =
          "EXISTS (SELECT 1 FROM jsonb_array_elements(s.items) AS item WHERE item->>'code' IN (SELECT kod FROM products))";

      final openingExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE $productItemCheck AND s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%') LIMIT 1",
      );
      if (openingExists.isNotEmpty) {
        types.add('Açılış Stoğu (Girdi)');
      }

      final devirGirdiExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE $productItemCheck AND s.source_warehouse_id IS NULL AND s.dest_warehouse_id IS NOT NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'opening_stock') OR COALESCE(s.description, '') ILIKE '%Açılış%') AND NOT EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%') LIMIT 1",
      );
      if (devirGirdiExists.isNotEmpty) {
        types.add('Devir Girdi');
      }

      final devirCiktiExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE $productItemCheck AND s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NULL AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%') AND NOT (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%') LIMIT 1",
      );
      if (devirCiktiExists.isNotEmpty) {
        types.add('Devir Çıktı');
      }

      final sevkiyatExists = await _pool!.execute(
        'SELECT 1 FROM shipments s WHERE $productItemCheck AND s.source_warehouse_id IS NOT NULL AND s.dest_warehouse_id IS NOT NULL LIMIT 1',
      );
      if (sevkiyatExists.isNotEmpty) {
        types.add('Sevkiyat');
      }

      final uretimGirdiExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE $productItemCheck AND EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.movement_type = 'uretim_giris') LIMIT 1",
      );
      if (uretimGirdiExists.isNotEmpty) {
        types.add('Üretim Girişi');
      }

      final uretimCiktiExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE $productItemCheck AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref = 'production_output') OR COALESCE(s.description, '') ILIKE '%Üretim (Çıktı)%') LIMIT 1",
      );
      if (uretimCiktiExists.isNotEmpty) {
        types.add('Üretim Çıkışı');
      }

      final satisExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE $productItemCheck AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND (sm.integration_ref LIKE 'SALE-%' OR sm.integration_ref LIKE 'RETAIL-%')) OR COALESCE(s.description, '') ILIKE 'Satış%' OR COALESCE(s.description, '') ILIKE 'Satis%') LIMIT 1",
      );
      if (satisExists.isNotEmpty) {
        types.add('Satış Yapıldı');
      }

      final alisExists = await _pool!.execute(
        "SELECT 1 FROM shipments s WHERE $productItemCheck AND (EXISTS (SELECT 1 FROM stock_movements sm WHERE sm.shipment_id = s.id AND sm.integration_ref LIKE 'PURCHASE-%') OR COALESCE(s.description, '') ILIKE 'Alış%' OR COALESCE(s.description, '') ILIKE 'Alis%') LIMIT 1",
      );
      if (alisExists.isNotEmpty) {
        types.add('Alış Yapıldı');
      }

      _cachedStokIslemTurleri = types;
      _stokCacheZamani = DateTime.now();
      return types;
    } catch (e) {
      debugPrint('Stok işlem türleri sorgu hatası: $e');
      return [];
    }
  }

  /// Cache'i temizle (Yeni sevkiyat eklendiğinde çağrılabilir)
  void islemTurleriCacheTemizle() {
    _cachedIslemTurleri = null;
    _cacheZamani = null;
    _cachedStokIslemTurleri = null;
    _stokCacheZamani = null;
  }

  Future<Map<String, dynamic>?> sevkiyatGetir(int id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    final result = await _pool!.execute(
      Sql.named('SELECT * FROM shipments WHERE id = @id'),
      parameters: {'id': id},
    );

    if (result.isEmpty) return null;

    final row = result.first;
    final map = row.toColumnMap();

    // Items JSON decode
    if (map['items'] is String) {
      map['items'] = jsonDecode(map['items'] as String);
    }

    return map;
  }

  Future<void> sevkiyatGuncelle({
    required int id,
    required int? sourceId,
    required int? destId,
    required DateTime date,
    required String description,
    required List<ShipmentItem> items,
    String? createdBy,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // Transaction bloğu: Önce eski stokları geri al, sonra yenileri ekle
    await _pool!.runTx((ctx) async {
      // 1. Eski kaydı getir
      final oldResult = await ctx.execute(
        Sql.named(
          'SELECT items, source_warehouse_id, dest_warehouse_id FROM shipments WHERE id = @id FOR UPDATE',
        ),
        parameters: {'id': id},
      );

      if (oldResult.isEmpty) {
        throw Exception('Sevkiyat bulunamadı');
      }

      final oldRow = oldResult.first;
      final oldItemsRaw = oldRow[0];
      final oldSourceId = oldRow[1] as int?;
      final oldDestId = oldRow[2] as int?;

      final List oldItemsList = oldItemsRaw is String
          ? jsonDecode(oldItemsRaw) as List
          : oldItemsRaw as List;

      // 2. Eski stok hareketlerini geri al (Revert)
      for (final item in oldItemsList) {
        final code = item['code'] as String;
        final pQuantity = (double.tryParse(item['quantity'].toString()) ?? 0.0);

        // Eski Hedef: Azalt (destId'ye eklenmişti)
        if (oldDestId != null) {
          await ctx.execute(
            Sql.named('''
               UPDATE warehouse_stocks 
               SET quantity = quantity - @qty::numeric
               WHERE warehouse_id = @wid AND product_code = @code
            '''),
            parameters: {'wid': oldDestId, 'code': code, 'qty': pQuantity},
          );
        }
        // Eski Kaynak: Artır (sourceId'den çıkmıştı)
        if (oldSourceId != null) {
          await ctx.execute(
            Sql.named('''
               INSERT INTO warehouse_stocks (warehouse_id, product_code, quantity)
               VALUES (@wid, @code, @qty)
               ON CONFLICT (warehouse_id, product_code) 
               DO UPDATE SET quantity = warehouse_stocks.quantity + @qty::numeric
            '''),
            parameters: {'wid': oldSourceId, 'code': code, 'qty': pQuantity},
          );
        }
      }

      // 3. Yeni stok hareketlerini uygula (Apply New)
      for (final item in items) {
        // Yeni Hedef: Artır
        if (destId != null) {
          await ctx.execute(
            Sql.named('''
              INSERT INTO warehouse_stocks (warehouse_id, product_code, quantity)
              VALUES (@wid, @code, @qty)
              ON CONFLICT (warehouse_id, product_code) 
              DO UPDATE SET quantity = warehouse_stocks.quantity + @qty::numeric
            '''),
            parameters: {
              'wid': destId,
              'code': item.code,
              'qty': item.quantity,
            },
          );
        }
        // Yeni Kaynak: Azalt
        if (sourceId != null) {
          await ctx.execute(
            Sql.named('''
              INSERT INTO warehouse_stocks (warehouse_id, product_code, quantity)
              VALUES (@wid, @code, -@qty::numeric)
              ON CONFLICT (warehouse_id, product_code) 
              DO UPDATE SET quantity = warehouse_stocks.quantity - @qty::numeric
            '''),
            parameters: {
              'wid': sourceId,
              'code': item.code,
              'qty': item.quantity,
            },
          );
        }
      }

      // 4. Shipment kaydını güncelle
      final itemsJson = items
          .map(
            (i) => {
              'code': i.code,
              'name': i.name,
              'unit': i.unit,
              'quantity': i.quantity,
              'unitCost': i.unitCost,
              if (i.devices != null) 'devices': i.devices,
            },
          )
          .toList();

      await ctx.execute(
        Sql.named('''
          UPDATE shipments 
          SET source_warehouse_id = @sourceId,
              dest_warehouse_id = @destId,
              date = @date,
              description = @description,
              items = @itemsJson
          WHERE id = @id
        '''),
        parameters: {
          'id': id,
          'sourceId': sourceId,
          'destId': destId,
          'date': date,
          'description': description,
          'itemsJson': jsonEncode(itemsJson),
        },
      );
      // 5. İlgili depoları güncelle (search_tags tetiklemek için)
      // Hem eski hem yeni depoların stokları değiştiği için hepsini tetikliyoruz.
      final affectedDepotIds = {
        oldSourceId,
        oldDestId,
        sourceId,
        destId,
      }.whereType<int>().toSet().toList();

      if (affectedDepotIds.isNotEmpty) {
        await ctx.execute(
          Sql.named(
            'UPDATE depots SET created_at = created_at WHERE id = ANY(@ids)',
          ),
          parameters: {'ids': affectedDepotIds},
        );
      }
    });

    // Cache'i temizle
    islemTurleriCacheTemizle();
  }

  /// Depo istatistiklerini getir (Toplam Ürün Miktarı, Girdi/Çıktı Toplamları)
  /// 1 Milyar Kayıt İçin Optimize Edilmiş Sorgu
  Future<Map<String, dynamic>> depoIstatistikleriniGetir(int depoId) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) {
      return {
        'toplamUrunMiktari': 0.0,
        'toplamGirdi': 0.0,
        'toplamCikti': 0.0,
        'urunSayisi': 0,
      };
    }

    // Helper: Güvenli double dönüşümü (String veya num kabul eder)
    double safeDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Helper: Güvenli int dönüşümü
    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    try {
      // 1. warehouse_stocks tablosundan toplam stok miktarını al (Direkt ve Hızlı)
      final stockResult = await _pool!.execute(
        Sql.named('''
          SELECT 
            COALESCE(SUM(quantity), 0) as toplam_miktar,
            COUNT(DISTINCT product_code) as urun_sayisi
          FROM warehouse_stocks 
          WHERE warehouse_id = @depoId AND quantity > 0
        '''),
        parameters: {'depoId': depoId},
      );

      double toplamMiktar = 0.0;
      int urunSayisi = 0;
      if (stockResult.isNotEmpty && stockResult[0][0] != null) {
        toplamMiktar = safeDouble(stockResult[0][0]);
        urunSayisi = safeInt(stockResult[0][1]);
      }

      // 2. Girdi/Çıktı toplamlarını hesapla (shipments tablosundan)
      final movementResult = await _pool!.execute(
        Sql.named('''
          SELECT 
            COALESCE(SUM(CASE WHEN dest_warehouse_id = @depoId THEN (item->>'quantity')::numeric ELSE 0 END), 0) as toplam_girdi,
            COALESCE(SUM(CASE WHEN source_warehouse_id = @depoId THEN (item->>'quantity')::numeric ELSE 0 END), 0) as toplam_cikti
          FROM shipments, jsonb_array_elements(items) as item
          WHERE dest_warehouse_id = @depoId OR source_warehouse_id = @depoId
        '''),
        parameters: {'depoId': depoId},
      );

      double toplamGirdi = 0.0;
      double toplamCikti = 0.0;
      if (movementResult.isNotEmpty) {
        toplamGirdi = safeDouble(movementResult[0][0]);
        toplamCikti = safeDouble(movementResult[0][1]);
      }

      return {
        'toplamUrunMiktari': toplamMiktar,
        'toplamGirdi': toplamGirdi,
        'toplamCikti': toplamCikti,
        'urunSayisi': urunSayisi,
      };
    } catch (e) {
      debugPrint('Depo istatistikleri hatası: $e');
      return {
        'toplamUrunMiktari': 0.0,
        'toplamGirdi': 0.0,
        'toplamCikti': 0.0,
        'urunSayisi': 0,
      };
    }
  }

  /// Depo stoklarını listele (Ürün Adı, Kod, Miktar ile birlikte)
  /// 1 Milyar Kayıt İçin Optimize Edilmiş Sorgu
  Future<List<Map<String, dynamic>>> depoStoklariniListele(
    int depoId, {
    String? aramaTerimi,
    int limit = 100,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    try {
      String whereClause = 'ws.warehouse_id = @depoId AND ws.quantity > 0';
      final Map<String, dynamic> params = {'depoId': depoId};

      if (aramaTerimi != null && aramaTerimi.trim().isNotEmpty) {
        whereClause +=
            ' AND (LOWER(p.ad) LIKE @arama OR LOWER(p.kod) LIKE @arama)';
        params['arama'] = '%${aramaTerimi.toLowerCase()}%';
      }

      final result = await _pool!.execute(
        Sql.named('''
          SELECT 
            ws.product_code,
            COALESCE(p.ad, ws.product_code) as urun_adi,
            ws.quantity,
            COALESCE(p.birim, 'Adet') as birim,
            p.barkod,
            p.grubu,
            p.ozellikler
          FROM warehouse_stocks ws
          LEFT JOIN products p ON p.kod = ws.product_code
          WHERE $whereClause
          ORDER BY p.ad ASC NULLS LAST, ws.product_code ASC
          LIMIT @limit
        '''),
        parameters: {...params, 'limit': limit},
      );

      // Helper: Güvenli double dönüşümü
      double safeDouble(dynamic value) {
        if (value == null) return 0.0;
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? 0.0;
        return 0.0;
      }

      return result.map((row) {
        final featuresStr = row[6] as String? ?? '';
        List<dynamic> featuresList = [];

        if (featuresStr.isNotEmpty) {
          try {
            // Try to decode as JSON list
            final decoded = jsonDecode(featuresStr);
            if (decoded is List) {
              featuresList = decoded;
            } else {
              featuresList = featuresStr
                  .split(',')
                  .map((e) => e.trim())
                  .toList();
            }
          } catch (_) {
            // Not JSON, treat as comma separated string
            featuresList = featuresStr.split(',').map((e) => e.trim()).toList();
          }
        }

        return {
          'product_code': row[0] as String? ?? '',
          'product_name': row[1] as String? ?? '',
          'quantity': safeDouble(row[2]),
          'unit': row[3] as String? ?? 'Adet',
          'barcode': row[4] as String? ?? '',
          'group': row[5] as String? ?? '',
          'features': featuresList,
        };
      }).toList();
    } catch (e) {
      debugPrint('Depo stokları listeleme hatası: $e');
      return [];
    }
  }

  /// Stok rezervasyonunu günceller (reserved_quantity).
  Future<void> stokRezervasyonuGuncelle(
    int warehouseId,
    String productCode,
    double miktar, {
    required bool isArtis,
    Session? session,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final executor = session ?? _pool!;

    await executor.execute(
      Sql.named('''
        INSERT INTO warehouse_stocks (warehouse_id, product_code, quantity, reserved_quantity)
        VALUES (@wId, @pCode, 0, @qty::numeric)
        ON CONFLICT (warehouse_id, product_code) 
        DO UPDATE SET 
          reserved_quantity = warehouse_stocks.reserved_quantity + @qty::numeric,
          updated_at = CURRENT_TIMESTAMP
      '''),
      parameters: {
        'wId': warehouseId,
        'pCode': productCode,
        'qty': isArtis ? miktar : -miktar,
      },
    );
  }

  Future<void> _ensureStockMovementPartitionExists(
    int year, {
    Session? session,
  }) async {
    if (_pool == null && session == null) return;
    final executor = session ?? _pool!;

    final partitionName = 'stock_movements_$year';
    final defaultTable = 'stock_movements_default';

    Future<bool> isTableExists(String tableName) async {
      final rows = await executor.execute(
        Sql.named("SELECT 1 FROM pg_class WHERE relname = @name"),
        parameters: {'name': tableName},
      );
      return rows.isNotEmpty;
    }

    Future<String?> getParentTable(String childTable) async {
      final rows = await executor.execute(
        Sql.named('''
          SELECT p.relname 
          FROM pg_inherits i
          JOIN pg_class c ON c.oid = i.inhrelid
          JOIN pg_class p ON p.oid = i.inhparent
          WHERE c.relname = @child
          LIMIT 1
        '''),
        parameters: {'child': childTable},
      );
      if (rows.isEmpty) return null;
      return rows.first[0]?.toString();
    }

    Future<bool> isAttached(String childTable) async {
      final parent = await getParentTable(childTable);
      return parent == 'stock_movements';
    }

    // 1. DEFAULT Partition
    if (!await isAttached(defaultTable)) {
      if (await isTableExists(defaultTable)) {
        final currentParent = await getParentTable(defaultTable);
        debugPrint(
          '🛠️ Stok default partition table $defaultTable detached or attached to $currentParent. Fixing...',
        );
        try {
          if (currentParent != null && currentParent != 'stock_movements') {
            await executor.execute(
              'ALTER TABLE $currentParent DETACH PARTITION $defaultTable',
            );
          }
          await executor.execute(
            'ALTER TABLE stock_movements ATTACH PARTITION $defaultTable DEFAULT',
          );
        } catch (_) {
          await executor.execute('DROP TABLE IF EXISTS $defaultTable CASCADE');
          await executor.execute(
            'CREATE TABLE $defaultTable PARTITION OF stock_movements DEFAULT',
          );
        }
      } else {
        await executor.execute(
          'CREATE TABLE IF NOT EXISTS $defaultTable PARTITION OF stock_movements DEFAULT',
        );
      }
    }

    // 2. Yıllık Partition
    if (!await isAttached(partitionName)) {
      final startStr = '$year-01-01';
      final endStr = '${year + 1}-01-01';

      if (await isTableExists(partitionName)) {
        final currentParent = await getParentTable(partitionName);
        debugPrint(
          '🛠️ Stok partition table $partitionName detached or attached to $currentParent. Attaching...',
        );
        try {
          if (currentParent != null && currentParent != 'stock_movements') {
            await executor.execute(
              'ALTER TABLE $currentParent DETACH PARTITION $partitionName',
            );
          }
          await executor.execute(
            "ALTER TABLE stock_movements ATTACH PARTITION $partitionName FOR VALUES FROM ('$startStr') TO ('$endStr')",
          );
        } catch (e) {
          debugPrint('Stok attach failed ($partitionName): $e. Recreating...');
          await executor.execute('DROP TABLE IF EXISTS $partitionName CASCADE');
          await executor.execute(
            "CREATE TABLE $partitionName PARTITION OF stock_movements FOR VALUES FROM ('$startStr') TO ('$endStr')",
          );
        }
      } else {
        try {
          await executor.execute(
            "CREATE TABLE IF NOT EXISTS $partitionName PARTITION OF stock_movements FOR VALUES FROM ('$startStr') TO ('$endStr')",
          );
        } catch (e) {
          if (!e.toString().contains('already exists')) rethrow;
        }
      }
    }
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

    if (code == '23505') {
      return msg.contains('pg_class_relname_nsp_index');
    }
    if (code == '42P07' || code == '42710') return true;

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
List<DepoModel> _parseDepolarIsolate(List<Map<String, dynamic>> data) {
  return data.map((d) => DepoModel.fromMap(d)).toList();
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
