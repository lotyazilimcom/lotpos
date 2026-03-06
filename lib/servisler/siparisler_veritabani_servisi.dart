import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sayfalar/siparisler_teklifler/modeller/siparis_model.dart';
import '../yardimcilar/format_yardimcisi.dart';
import '../yardimcilar/islem_turu_renkleri.dart';
import 'oturum_servisi.dart';
import 'bulut_sema_dogrulama_servisi.dart';
import 'pg_eklentiler.dart';
import 'veritabani_yapilandirma.dart';
import 'veritabani_havuzu.dart';
import 'depolar_veritabani_servisi.dart';
import 'lisans_yazma_koruma.dart';

class SiparislerVeritabaniServisi {
  static final SiparislerVeritabaniServisi _instance =
      SiparislerVeritabaniServisi._internal();
  factory SiparislerVeritabaniServisi() => _instance;
  SiparislerVeritabaniServisi._internal();

  Pool? _pool;
  bool _isInitialized = false;
  final _yapilandirma = VeritabaniYapilandirma();
  Completer<void>? _initCompleter;
  int _initToken = 0;
  static bool _isIndexingActive = false;
  static bool _isPartitionIndexingActive = false;
  bool _orderItemsHasSearchTags = false;

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
      final err = StateError('Siparişler veritabanı bağlantısı kurulamadı.');
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
            'SiparislerVeritabaniServisi: Bulut şema hazır, tablo kurulumu atlandı.',
          );
        }
        await _ensureOrderItemSearchTagsBestEffort();
        await _kritikIndeksleriGarantiEt();
        // Arka planda eksik indeksleri tamamla
        if (_yapilandirma.allowBackgroundDbMaintenance &&
            _yapilandirma.allowBackgroundHeavyMaintenance) {
          // Arka plan işi: asla uygulamayı çökertmesin.
          unawaited(
            Future<void>.delayed(const Duration(seconds: 2), () async {
              try {
                await _verileriIndeksle();
              } catch (e) {
                debugPrint(
                  'SiparislerVeritabaniServisi: Arka plan indeksleme hatası (yutuldu): $e',
                );
              }
            }),
          );
          unawaited(
            Future<void>.delayed(const Duration(seconds: 3), () async {
              try {
                await _partitionIndeksleriniTamamla();
              } catch (e) {
                debugPrint(
                  'SiparislerVeritabaniServisi: Arka plan partition indeksleme hatası (yutuldu): $e',
                );
              }
            }),
          );
          // [100B/20Y] DEFAULT partition'a yığılan eski verileri doğru aylık partitionlara taşı (best-effort).
          unawaited(
            Future<void>.delayed(const Duration(seconds: 4), () async {
              try {
                await _backfillOrdersDefault();
              } catch (e) {
                debugPrint(
                  'SiparislerVeritabaniServisi: Arka plan default backfill uyarısı (yutuldu): $e',
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
        debugPrint('Siparisler veritabanı bağlantısı başarılı (Havuz)');
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
    await VeritabaniHavuzu().kapatPool(pool);
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('Bağlantı kapatıldı'));
    }
  }

  Future<void> bakimModuCalistir() async {
    await _verileriIndeksle();
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
             SELECT id FROM orders 
             WHERE search_tags IS NULL OR search_tags NOT LIKE '%|v2026|%'
             LIMIT 100
           ),
	            order_data AS (
	              SELECT 
	                o.id,
	                LOWER(
	                  '|id:' || COALESCE(o.id::text, '') || '| ' ||
	                  '|no:' || COALESCE(o.order_no, '') || '| ' ||
	                  '|ref:' || COALESCE(o.integration_ref, '') || '| ' ||
	                  '|type:' || get_professional_label(o.tur, 'cari') || '| ' || 
	                  '|status:' || COALESCE(o.durum, '') || '| ' || 
	                  '|date:' || COALESCE(TO_CHAR(o.tarih, 'DD.MM.YYYY HH24:MI'), '') || '| ' ||
	                  '|acc_code:' || COALESCE(o.cari_kod, '') || '| ' ||
	                  '|acc:' || COALESCE(o.cari_adi, '') || '| ' || 
	                  '|rel:' || COALESCE(o.ilgili_hesap_adi, '') || '| ' || 
	                  '|total:' || COALESCE(o.tutar::text, '') || '| ' ||
	                  '|total_tr:' || COALESCE(REPLACE(o.tutar::text, '.', ','), '') || '| ' ||
	                  '|rate:' || COALESCE(o.kur::text, '') || '| ' ||
	                  '|rate_tr:' || COALESCE(REPLACE(o.kur::text, '.', ','), '') || '| ' ||
	                  '|cur:' || COALESCE(o.para_birimi, '') || '| ' ||
	                  '|d1:' || COALESCE(o.aciklama, '') || '| ' ||
	                  '|d2:' || COALESCE(o.aciklama2, '') || '| ' ||
	                  '|valid:' || COALESCE(TO_CHAR(o.gecerlilik_tarihi, 'DD.MM.YYYY'), '') || '| ' ||
	                  '|user:' || COALESCE(o.kullanici, '') || '| ' ||
	                  '|v2026|' ||
	                  COALESCE((
	                    SELECT STRING_AGG(
	                      LOWER(
	                        '|it:' || COALESCE(oi.urun_kodu, '') || '| ' || 
	                        '|iname:' || COALESCE(oi.urun_adi, '') || '| ' || 
	                        '|ibc:' || COALESCE(oi.barkod, '') || '| ' || 
	                        '|dep:' || COALESCE(oi.depo_adi, '') || '| ' ||
	                        '|vat:' || COALESCE(oi.kdv_orani::text, '') || ' ' ||
	                          COALESCE(oi.kdv_orani::int::text, '') || '| ' ||
	                        '|vst:' || COALESCE(oi.kdv_durumu, '') || ' ' ||
	                          CASE WHEN oi.kdv_durumu = 'included' THEN 'kdv dahil dahil' ELSE 'kdv hariç hariç' END || '| ' ||
	                        '|qty:' || COALESCE(oi.miktar::text, '') || ' ' ||
	                          COALESCE(REPLACE(oi.miktar::text, '.', ','), '') || '| ' ||
	                        '|unit:' || COALESCE(oi.birim, '') || '| ' ||
	                        '|disc:' || COALESCE(oi.iskonto::text, '') || ' ' ||
	                          COALESCE(REPLACE(oi.iskonto::text, '.', ','), '') || '| ' ||
	                        '|price:' || COALESCE(oi.birim_fiyati::text, '') || ' ' ||
	                          COALESCE(REPLACE(oi.birim_fiyati::text, '.', ','), '') || '| ' ||
	                        '|cur:' || COALESCE(oi.para_birimi, '') || '| ' ||
	                        '|line_total:' || COALESCE(oi.toplam_fiyati::text, '') || ' ' ||
	                          COALESCE(REPLACE(oi.toplam_fiyati::text, '.', ','), '') || '| ' ||
	                        '|del:' || COALESCE(oi.delivered_quantity::text, '') || '|'
	                      ), ' '
	                    )
	                    FROM order_items oi
	                    WHERE oi.order_id = o.id
	                  ), '')
                ) as new_tags
              FROM orders o
              INNER JOIN batch b ON o.id = b.id
            )
           UPDATE orders o
           SET search_tags = od.new_tags
           FROM order_data od
           WHERE o.id = od.id
           RETURNING o.id
        ''');

        if (result.isEmpty) break;
        await Future.delayed(const Duration(milliseconds: 50));
      }
      debugPrint('✅ Sipariş Arama İndeksleri Kontrol Edildi.');
    } catch (e) {
      if (e is LisansYazmaEngelliHatasi) return;
      debugPrint('Sipariş indeksleme hatası: $e');
    } finally {
      _isIndexingActive = false;
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

    try {
      // Tablo durumunu detaylı kontrol et (Casting relkind to text is crucial for Dart driver)
      final tableCheck = await _pool!.execute(
        "SELECT c.relkind::text, n.nspname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relname = 'orders' AND n.nspname = 'public'",
      );

      if (tableCheck.isEmpty) {
        // Tablo yok, sıfırdan oluştur
        debugPrint(
          'Siparişler: Tablo bulunamadı. Partitioned kurulum yapılıyor...',
        );
        await _createPartitionedOrdersTable();
      } else {
        final relkind = tableCheck.first[0]
            .toString(); // Artık 'p' veya 'r' dönecek
        debugPrint(
          'Mevcut Tablo Durumu: relkind=$relkind (r=regular, p=partitioned)',
        );

        // Eğer tablo var ama partitioned değilse (r), migration yap
        if (relkind != 'p') {
          debugPrint(
            'Siparişler: Tablo regular modda. Partitioned yapıya geçiliyor...',
          );
          await _migrateToPartitionedStructure();
        } else {
          debugPrint('✅ Tablo zaten Partitioned yapıda. Migration gerekmiyor.');
        }
      }
    } catch (e) {
      debugPrint('Tablo kontrol/kurulum hatası: $e');
    }

    // Partition Yönetimi (Her başlangıçta kontrol et)
    try {
      await _ensurePartitionExists(DateTime.now());
      // Bir sonraki ayın partition'ını da şimdiden hazırla
      await _ensurePartitionExists(
        DateTime.now().add(const Duration(days: 32)),
      );
    } catch (e) {
      debugPrint('Initial partition check hatası: $e');
    }

    // [MIGRATION] Diğer eksik kolonları kontrol et
    await _eksikKolonlariTamamla();

    // Sipariş Ürünleri Tablosu
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
        id BIGSERIAL PRIMARY KEY,
        order_id BIGINT NOT NULL,
        urun_id BIGINT,
        urun_kodu TEXT NOT NULL,
        urun_adi TEXT NOT NULL,
        barkod TEXT,
        depo_id BIGINT,
        depo_adi TEXT,
        kdv_orani NUMERIC DEFAULT 0,
        miktar NUMERIC DEFAULT 0,
        birim TEXT DEFAULT 'Adet',
        birim_fiyati NUMERIC DEFAULT 0,
        para_birimi TEXT DEFAULT 'TRY',
        kdv_durumu TEXT DEFAULT 'excluded',
        iskonto NUMERIC DEFAULT 0,
        toplam_fiyati NUMERIC DEFAULT 0,
        delivered_quantity NUMERIC DEFAULT 0,
        search_tags TEXT NOT NULL DEFAULT '',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // İndeksler
    try {
      await PgEklentiler.ensurePgTrgm(_pool!);
      try {
        await PgEklentiler.ensurePgSearch(_pool!);
      } catch (_) {}
      await PgEklentiler.ensureSearchTagsNotNullDefault(_pool!, 'orders');
      await PgEklentiler.ensureSearchTagsNotNullDefault(_pool!, 'order_items');
      await PgEklentiler.ensureSearchTagsFtsIndex(
        _pool!,
        table: 'orders',
        indexName: 'idx_orders_search_tags_fts_gin',
      );
      await PgEklentiler.ensureSearchTagsFtsIndex(
        _pool!,
        table: 'order_items',
        indexName: 'idx_order_items_search_tags_fts_gin',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_tarih ON orders(tarih DESC)',
      );
      // Partitioned tablolarda unique index partition key içermelidir, bu yüzden global unique yerine uygulama kontrolü tercih edilir
      // veya integration_ref + tarih composite key yapılır.
      // Şimdilik performans için normal index:
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_integration_ref ON orders(integration_ref)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_search_tags_gin ON orders USING GIN (search_tags gin_trgm_ops)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_order_items_search_tags_gin ON order_items USING GIN (search_tags gin_trgm_ops)',
      );

      try {
        await PgEklentiler.ensureBm25Index(
          _pool!,
          table: 'orders',
          indexName: 'idx_orders_search_tags_bm25',
        );
        await PgEklentiler.ensureBm25Index(
          _pool!,
          table: 'order_items',
          indexName: 'idx_order_items_search_tags_bm25',
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('İndeksleme uyarısı: $e');
    }
  }

  Future<void> _kritikIndeksleriGarantiEt() async {
    final pool = _pool;
    if (pool == null || !pool.isOpen) return;
    try {
      await PgEklentiler.ensurePgTrgm(pool);
      try {
        await PgEklentiler.ensurePgSearch(pool);
      } catch (_) {}
      await PgEklentiler.ensureSearchTagsNotNullDefault(pool, 'orders');
      await PgEklentiler.ensureSearchTagsNotNullDefault(pool, 'order_items');
      await PgEklentiler.ensureSearchTagsFtsIndex(
        pool,
        table: 'orders',
        indexName: 'idx_orders_search_tags_fts_gin',
      );
      await PgEklentiler.ensureSearchTagsFtsIndex(
        pool,
        table: 'order_items',
        indexName: 'idx_order_items_search_tags_fts_gin',
      );
      await pool.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_tarih ON orders(tarih DESC)',
      );
      await pool.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_integration_ref ON orders(integration_ref)',
      );
      await pool.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_search_tags_gin ON orders USING GIN (search_tags gin_trgm_ops)',
      );
      await pool.execute(
        'CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id)',
      );
      await pool.execute(
        'CREATE INDEX IF NOT EXISTS idx_order_items_search_tags_gin ON order_items USING GIN (search_tags gin_trgm_ops)',
      );
      try {
        await PgEklentiler.ensureBm25Index(
          pool,
          table: 'orders',
          indexName: 'idx_orders_search_tags_bm25',
        );
        await PgEklentiler.ensureBm25Index(
          pool,
          table: 'order_items',
          indexName: 'idx_order_items_search_tags_bm25',
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('Siparisler kritik indeks garantisi uyarısı: $e');
    }
  }

  Future<void> _partitionIndeksleriniTamamla() async {
    if (_isPartitionIndexingActive) return;
    _isPartitionIndexingActive = true;

    try {
      final pool = _pool;
      if (pool == null || !pool.isOpen) return;

      // Parent indekslerin varlığını garanti et (attach için şart).
      await _kritikIndeksleriGarantiEt();

      final partitions = await pool.execute('''
        SELECT c.relname::text
        FROM pg_inherits i
        JOIN pg_class c ON c.oid = i.inhrelid
        WHERE i.inhparent = to_regclass('orders')
      ''');

      for (final row in partitions) {
        if (!pool.isOpen) break;
        final partitionName = row[0]?.toString();
        if (partitionName == null || partitionName.trim().isEmpty) continue;
        await _partitionIcinIndeksleriGarantiEt(partitionName.trim());
      }
    } catch (e) {
      if (e is LisansYazmaEngelliHatasi) return;
      debugPrint('Siparisler partition indeksleme hatası: $e');
    } finally {
      _isPartitionIndexingActive = false;
    }
  }

  Future<void> _partitionIcinIndeksleriGarantiEt(String partitionTable) async {
    final pool = _pool;
    if (pool == null || !pool.isOpen) return;

    await _partitionIndexiniGarantiEt(
      parentIndex: 'idx_orders_tarih',
      partitionTable: partitionTable,
      childIndexName: 'idx_${partitionTable}_tarih',
      createChildSql:
          'CREATE INDEX IF NOT EXISTS idx_${partitionTable}_tarih ON $partitionTable (tarih DESC)',
    );
    await _partitionIndexiniGarantiEt(
      parentIndex: 'idx_orders_integration_ref',
      partitionTable: partitionTable,
      childIndexName: 'idx_${partitionTable}_integration_ref',
      createChildSql:
          'CREATE INDEX IF NOT EXISTS idx_${partitionTable}_integration_ref ON $partitionTable (integration_ref)',
    );
    await _partitionIndexiniGarantiEt(
      parentIndex: 'idx_orders_search_tags_gin',
      partitionTable: partitionTable,
      childIndexName: 'idx_${partitionTable}_search_tags_gin',
      createChildSql:
          'CREATE INDEX IF NOT EXISTS idx_${partitionTable}_search_tags_gin ON $partitionTable USING GIN (search_tags gin_trgm_ops)',
    );
    await _partitionIndexiniGarantiEt(
      parentIndex: 'idx_orders_search_tags_fts_gin',
      partitionTable: partitionTable,
      childIndexName: 'idx_${partitionTable}_search_tags_fts_gin',
      createChildSql:
          "CREATE INDEX IF NOT EXISTS idx_${partitionTable}_search_tags_fts_gin ON $partitionTable USING GIN (to_tsvector('simple', search_tags))",
    );
  }

  Future<void> _partitionIndexiniGarantiEt({
    required String parentIndex,
    required String partitionTable,
    required String childIndexName,
    required String createChildSql,
  }) async {
    final pool = _pool;
    if (pool == null || !pool.isOpen) return;

    try {
      final attached = await pool.execute(
        Sql.named('''
          SELECT 1
          FROM pg_inherits inh
          JOIN pg_index i ON i.indexrelid = inh.inhrelid
          WHERE inh.inhparent = to_regclass(@parentIndex)
            AND i.indrelid = to_regclass(@partitionTable)
          LIMIT 1
        '''),
        parameters: {
          'parentIndex': parentIndex,
          'partitionTable': partitionTable,
        },
      );
      if (attached.isNotEmpty) return;

      await PgEklentiler.ensurePgTrgm(pool);
      await pool.execute(createChildSql);
      try {
        await pool.execute(
          'ALTER INDEX $parentIndex ATTACH PARTITION $childIndexName',
        );
      } catch (_) {
        // Attach başarısız olsa bile partition üzerinde indeks varsa arama yine hızlı olur.
      }
    } catch (e) {
      // Parçalı/legacy kurulumlarda beklenen: sessizce geç.
      if (e.toString().contains('42P01')) return;
      debugPrint('Siparis partition indeks garantisi uyarısı: $e');
    }
  }

  /// Mevcut standart tabloyu Partitioned yapıya dönüştürür.
  Future<void> _migrateToPartitionedStructure() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupName = 'orders_legacy_backup_$timestamp';

    debugPrint('🚀 MIGRATION START: $backupName');

    try {
      // 1. Mevcut tabloyu yedekle
      await _pool!.execute('ALTER TABLE orders RENAME TO $backupName');

      // 2. Partitioned tabloyu oluştur
      await _createPartitionedOrdersTable();

      // 3. Partition'ların hazır olduğundan emin ol (Veri aktarımı öncesi kritik adım)
      //    Bu sayede veriler DEFAULT yerine optimize edilmiş partlara gider.
      debugPrint('📦 Partitionlar hazırlanıyor...');
      // [100B/20Y] Eski veriler DEFAULT partition'a yığılmasın:
      // Eski tablodaki tarih aralığına göre aylık partition'ları hazırla.
      try {
        final rangeRows = await _pool!.execute('''
          SELECT
            MIN(COALESCE(tarih, created_at)),
            MAX(COALESCE(tarih, created_at))
          FROM $backupName
        ''');
        if (rangeRows.isNotEmpty) {
          final minDt = rangeRows.first[0] as DateTime?;
          final maxDt = rangeRows.first[1] as DateTime?;
          if (minDt != null && maxDt != null) {
            await _ensurePartitionsForRange(minDt, maxDt);
          }
        }
      } catch (e) {
        debugPrint('Sipariş partition aralık hazırlığı uyarısı: $e');
      }

      // 4. Verileri aktar
      debugPrint('💾 Veriler aktarılıyor...');
      await _pool!.execute('''
        INSERT INTO orders (
          id, integration_ref, order_no, tur, durum, tarih, cari_id, cari_kod, cari_adi, ilgili_hesap_adi,
          tutar, kur, aciklama, aciklama2, gecerlilik_tarihi, para_birimi,
          kullanici, search_tags, sales_ref, stok_rezerve_mi, created_at, updated_at
        )
        SELECT 
          id, integration_ref, order_no, tur, durum, tarih, cari_id, cari_kod, cari_adi, ilgili_hesap_adi,
          tutar, kur, aciklama, aciklama2, gecerlilik_tarihi, para_birimi,
          kullanici, search_tags, sales_ref, stok_rezerve_mi, created_at, updated_at
        FROM $backupName
        ON CONFLICT (id, tarih) DO NOTHING
      ''');

      // 5. Sequence güncelle
      final maxIdResult = await _pool!.execute(
        'SELECT COALESCE(MAX(id), 0) FROM $backupName',
      );
      final maxId = _toInt(maxIdResult.first[0]) ?? 1;
      await _pool!.execute("SELECT setval('orders_id_seq', $maxId)");

      // [100B/20Y] DEFAULT partition'a düşmüş eski satırları ilgili aylık partitionlara taşı (best-effort).
      try {
        await _backfillOrdersDefault();
      } catch (e) {
        debugPrint('Sipariş default backfill uyarısı: $e');
      }

      debugPrint('✅ MIGRATION SUCCESSFUL: Tablo artık Partitioned yapıda.');
    } catch (e) {
      debugPrint('MIGRATION FAILED: $e');
      // Geri alma (Rollback) senaryosu düşünülebilir
      // Şimdilik sistemin çalışmaya devam etmesi için exception fırlatmıyoruz
    }
  }

  /// 100 Milyar satır için optimize edilmiş Partitioned Table oluşturur.
  Future<void> _createPartitionedOrdersTable() async {
    // 1. Ana Tablo (Partitioned by Range)
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id BIGSERIAL,
        integration_ref TEXT,
        order_no TEXT,
        tur TEXT NOT NULL DEFAULT 'Satış Siparişi',
        durum TEXT NOT NULL DEFAULT 'Beklemede',
        tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        cari_id BIGINT,
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
        search_tags TEXT NOT NULL DEFAULT '',
        sales_ref TEXT,
        stok_rezerve_mi BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP,
        PRIMARY KEY (id, tarih)
      ) PARTITION BY RANGE (tarih)
    ''');

    // 2. Default Partition (Çöp Kutusu / Güvenlik Ağı)
    // Beklenmedik tarihli veriler buraya düşer, hata vermez.
    await _pool!.execute(
      'CREATE TABLE IF NOT EXISTS orders_default PARTITION OF orders DEFAULT',
    );
  }

  /// Belirtilen tarih için gerekli partition'ın varlığını garanti eder.
  Future<void> _ensurePartitionExists(
    DateTime date, {
    bool retry = true,
  }) async {
    if (_pool == null) return;
    try {
      final year = date.year;
      final month = date.month;
      final partitionName =
          'orders_y${year}_m${month.toString().padLeft(2, '0')}';

      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final startStr =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-01';
      final endStr =
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-01';

      // Check if partition exists
      final check = await _pool!.execute(
        "SELECT 1 FROM pg_class WHERE relname = '$partitionName'",
      );

      if (check.isEmpty) {
        debugPrint(
          'Siparişler: Partition oluşturuluyor: $partitionName ($startStr - $endStr)',
        );
        await _pool!.execute('''
          CREATE TABLE IF NOT EXISTS $partitionName 
          PARTITION OF orders 
          FOR VALUES FROM ('$startStr') TO ('$endStr')
        ''');
      }
    } catch (e) {
      // 42P17: "orders" is not partitioned
      if (retry && e.toString().contains('42P17')) {
        debugPrint(
          'Siparişler: Partition hatası (42P17) tespit edildi. Hızlı migrasyon başlatılıyor...',
        );
        await _migrateToPartitionedStructure();
        // Retry once
        return _ensurePartitionExists(date, retry: false);
      }
      debugPrint('Partition kontrol hatası ($date): $e');
    }
  }

  Future<void> _ensurePartitionsForRange(DateTime start, DateTime end) async {
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
      await _ensurePartitionExists(cursor);
      if (cursor.year == endMonth.year && cursor.month == endMonth.month) break;
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
  }

  Future<void> _backfillOrdersDefault() async {
    if (_pool == null) return;
    final pool = _pool!;
    final range = await pool.execute('''
      SELECT MIN(tarih), MAX(tarih)
      FROM orders_default
      WHERE tarih IS NOT NULL
    ''');
    if (range.isEmpty) return;
    final minDt = range.first[0] as DateTime?;
    final maxDt = range.first[1] as DateTime?;
    if (minDt == null || maxDt == null) return;

    await _ensurePartitionsForRange(minDt, maxDt);

    await PgEklentiler.moveRowsFromDefaultPartition(
      executor: pool,
      parentTable: 'orders',
      defaultTable: 'orders_default',
      partitionKeyColumn: 'tarih',
    );
  }

  Future<void> _eksikKolonlariTamamla() async {
    final columns = {
      'integration_ref': 'TEXT UNIQUE',
      'order_no': 'TEXT',
      'tur': "TEXT NOT NULL DEFAULT 'Satış Siparişi'",
      'durum': "TEXT NOT NULL DEFAULT 'Beklemede'",
      'tarih': 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP',
      'cari_id': 'BIGINT',
      'cari_kod': 'TEXT',
      'cari_adi': 'TEXT',
      'ilgili_hesap_adi': 'TEXT',
      'tutar': 'NUMERIC DEFAULT 0',
      'kur': 'NUMERIC DEFAULT 1',
      'aciklama': 'TEXT',
      'aciklama2': 'TEXT',
      'gecerlilik_tarihi': 'TIMESTAMP',
      'para_birimi': "TEXT DEFAULT 'TRY'",
      'kullanici': 'TEXT',
      'search_tags': "TEXT NOT NULL DEFAULT ''",
      'sales_ref': 'TEXT',
      'stok_rezerve_mi': 'BOOLEAN DEFAULT false',
      'updated_at': 'TIMESTAMP',
    };

    for (var entry in columns.entries) {
      try {
        await _pool!.execute(
          'ALTER TABLE orders ADD COLUMN IF NOT EXISTS ${entry.key} ${entry.value}',
        );
      } catch (_) {}
    }

    // items için de benzer kontrol
    try {
      await _pool!.execute(
        'ALTER TABLE order_items ADD COLUMN IF NOT EXISTS delivered_quantity NUMERIC DEFAULT 0',
      );
    } catch (_) {}
    try {
      await _pool!.execute(
        'ALTER TABLE order_items ADD COLUMN IF NOT EXISTS search_tags TEXT NOT NULL DEFAULT \'\'',
      );
    } catch (_) {}
  }

  Future<bool> _columnExists({
    required String table,
    required String column,
    Session? session,
  }) async {
    final executor = session ?? _pool;
    if (executor == null) return false;
    try {
      final rows = await executor.execute(
        Sql.named('''
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = @t
            AND column_name = @c
          LIMIT 1
        '''),
        parameters: {'t': table, 'c': column},
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureOrderItemSearchTagsBestEffort() async {
    final pool = _pool;
    if (pool == null || !pool.isOpen) return;

    try {
      await PgEklentiler.ensureSearchTagsNotNullDefault(pool, 'order_items');
    } catch (_) {}

    try {
      await PgEklentiler.ensurePgTrgm(pool);
      await PgEklentiler.ensureSearchTagsFtsIndex(
        pool,
        table: 'order_items',
        indexName: 'idx_order_items_search_tags_fts_gin',
      );
      await pool.execute(
        'CREATE INDEX IF NOT EXISTS idx_order_items_search_tags_gin ON order_items USING GIN (search_tags gin_trgm_ops)',
      );
    } catch (_) {}

    _orderItemsHasSearchTags =
        await _columnExists(table: 'order_items', column: 'search_tags');

    if (_orderItemsHasSearchTags &&
        _yapilandirma.allowBackgroundDbMaintenance &&
        _yapilandirma.allowBackgroundHeavyMaintenance) {
      unawaited(_backfillOrderItemSearchTags());
    }
  }

  static String _buildOrderItemSearchTags(Map<String, dynamic> u) {
    final miktar = (u['miktar'] as num?)?.toDouble() ?? 0;
    final iskonto = (u['iskonto'] as num?)?.toDouble() ?? 0;
    final birimFiyati = (u['birimFiyati'] as num?)?.toDouble() ?? 0;
    final toplamFiyati = (u['toplamFiyati'] as num?)?.toDouble() ?? 0;
    final kdvOrani = (u['kdvOrani'] as num?)?.toDouble() ?? 0;

    final kdvDurumu = (u['kdvDurumu'] ?? '').toString();
    final kdvLabel =
        (kdvDurumu == 'included' || kdvDurumu == 'dahil')
            ? 'kdv dahil dahil'
            : 'kdv hariç hariç';

    final parts = <String>[
      (u['urunId'] ?? '').toString(),
      (u['urunKodu'] ?? '').toString(),
      (u['urunAdi'] ?? '').toString(),
      (u['barkod'] ?? '').toString(),
      (u['depoId'] ?? '').toString(),
      (u['depoAdi'] ?? '').toString(),
      kdvOrani.toString(),
      kdvOrani.toInt().toString(),
      kdvDurumu,
      kdvLabel,
      miktar.toString(),
      FormatYardimcisi.sayiFormatlaOndalikli(miktar),
      (u['birim'] ?? '').toString(),
      iskonto.toString(),
      FormatYardimcisi.sayiFormatlaOndalikli(iskonto),
      birimFiyati.toString(),
      FormatYardimcisi.sayiFormatlaOndalikli(birimFiyati),
      toplamFiyati.toString(),
      FormatYardimcisi.sayiFormatlaOndalikli(toplamFiyati),
      (u['paraBirimi'] ?? '').toString(),
    ];

    return parts
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != 'null')
        .join(' ')
        .toLowerCase()
        .trim();
  }

  Future<void> _backfillOrderItemSearchTags({
    int batchSize = 2000,
    int maxBatches = 50,
  }) async {
    final pool = _pool;
    if (pool == null || !pool.isOpen) return;
    if (!_orderItemsHasSearchTags) return;

    for (int i = 0; i < maxBatches; i++) {
      final updated = await pool.execute(
        Sql.named('''
          WITH todo AS (
            SELECT id
            FROM order_items
            WHERE search_tags IS NULL OR search_tags = ''
            LIMIT @batchSize
          )
          UPDATE order_items oi
          SET search_tags = LOWER(
            COALESCE(oi.urun_kodu, '') || ' ' ||
            COALESCE(oi.urun_adi, '') || ' ' ||
            COALESCE(oi.barkod, '') || ' ' ||
            COALESCE(oi.depo_adi, '') || ' ' ||
            COALESCE(oi.kdv_orani::text, '') || ' ' ||
            COALESCE(oi.kdv_orani::int::text, '') || ' ' ||
            COALESCE(oi.kdv_durumu, '') || ' ' ||
            CASE WHEN oi.kdv_durumu = 'included' THEN 'kdv dahil dahil' ELSE 'kdv hariç hariç' END || ' ' ||
            COALESCE(oi.miktar::text, '') || ' ' ||
            COALESCE(REPLACE(oi.miktar::text, '.', ','), '') || ' ' ||
            COALESCE(oi.birim, '') || ' ' ||
            COALESCE(oi.iskonto::text, '') || ' ' ||
            COALESCE(REPLACE(oi.iskonto::text, '.', ','), '') || ' ' ||
            COALESCE(oi.birim_fiyati::text, '') || ' ' ||
            COALESCE(REPLACE(oi.birim_fiyati::text, '.', ','), '') || ' ' ||
            COALESCE(oi.toplam_fiyati::text, '') || ' ' ||
            COALESCE(REPLACE(oi.toplam_fiyati::text, '.', ','), '') || ' ' ||
            COALESCE(oi.para_birimi, '') || ' ' ||
            COALESCE(TO_CHAR(oi.created_at, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
            COALESCE(oi.order_id::text, '') || ' ' ||
            COALESCE(oi.id::text, '')
          )
          FROM todo
          WHERE oi.id = todo.id
          RETURNING 1
        '''),
        parameters: {'batchSize': batchSize},
      );
      if (updated.isEmpty) break;
      await Future.delayed(const Duration(milliseconds: 25));
    }
  }

  Future<String> _getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_username') ?? 'system';
  }

  // --- CRUD İŞLEMLERİ ---

  Future<int> siparisEkle({
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
        'ORDER-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond % 1000}';

    final itemTags = urunler.map((u) => _buildOrderItemSearchTags(u)).join(' ');

    final professionalTur = IslemTuruRenkleri.getProfessionalLabel(
      tur,
      context: 'cari',
    );
    final searchTags = [
      ref,
      professionalTur,
      tur,
      durum,
      DateFormat('dd.MM.yyyy HH:mm').format(tarih),
      cariId?.toString() ?? '',
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
      '|v2026|',
      itemTags,
    ].join(' ').toLowerCase();

    try {
      return await _pool!.runTx((ctx) async {
        // Ana sipariş kaydı (Artık Partition hatası verme ihtimali yok)
        final result = await ctx.execute(
          Sql.named('''
            INSERT INTO orders (
              integration_ref, order_no, tur, durum, tarih, cari_id, cari_kod, cari_adi, ilgili_hesap_adi,
              tutar, kur, aciklama, aciklama2, gecerlilik_tarihi, para_birimi,
              kullanici, search_tags
            ) VALUES (
              @ref, @ref, @tur, @durum, @tarih, @cariId, @cariKod, @cariAdi, @ilgiliHesapAdi,
              @tutar, @kur, @aciklama, @aciklama2, @gecerlilikTarihi, @paraBirimi,
              @kullanici, @searchTags
            ) RETURNING id
          '''),
          parameters: {
            'ref': ref,
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

        final orderId = _toInt(result.first[0]) ?? 0;
        if (orderId == 0) return 0;

        // Ürünleri ekle
        for (var urun in urunler) {
          final itemSearchTags = _buildOrderItemSearchTags(urun);

          if (_orderItemsHasSearchTags) {
            await ctx.execute(
              Sql.named('''
                INSERT INTO order_items (
                  order_id, urun_id, urun_kodu, urun_adi, barkod, depo_id, depo_adi,
                  kdv_orani, miktar, birim, birim_fiyati, para_birimi, kdv_durumu,
                  iskonto, toplam_fiyati, search_tags
                ) VALUES (
                  @orderId, @urunId, @urunKodu, @urunAdi, @barkod, @depoId, @depoAdi,
                  @kdvOrani, @miktar, @birim, @birimFiyati, @paraBirimi, @kdvDurumu,
                  @iskonto, @toplamFiyati, @searchTags
                )
              '''),
              parameters: {
                'orderId': orderId,
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
                'searchTags': itemSearchTags,
              },
            );
          } else {
            await ctx.execute(
              Sql.named('''
                INSERT INTO order_items (
                  order_id, urun_id, urun_kodu, urun_adi, barkod, depo_id, depo_adi,
                  kdv_orani, miktar, birim, birim_fiyati, para_birimi, kdv_durumu,
                  iskonto, toplam_fiyati
                ) VALUES (
                  @orderId, @urunId, @urunKodu, @urunAdi, @barkod, @depoId, @depoAdi,
                  @kdvOrani, @miktar, @birim, @birimFiyati, @paraBirimi, @kdvDurumu,
                  @iskonto, @toplamFiyati
                )
              '''),
              parameters: {
                'orderId': orderId,
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

        if (durum == 'Onaylandı') {
          await _stokRezervasyonunuYonet(
            ctx: ctx,
            orderId: orderId,
            isArtis: true,
          );
        }

        return orderId;
      });
    } catch (e) {
      if (e.toString().contains('23514') ||
          e.toString().contains('no partition of relation')) {
        debugPrint(
          'Sipariş eklerken partition hatası algılandı. Düzeltme devreye giriyor...',
        );
        await _emergencyFixForPartitioning();
        try {
          // İkinci deneme...
          return await siparisEkle(
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
      debugPrint('Sipariş ekleme genel hata: $e');
      return -1;
    }
  }

  Future<List<SiparisModel>> siparisleriGetir({
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
    List<int>? sadeceIdler, // Harici arama indeksi gibi kaynaklardan gelen ID filtreleri
    int? lastId, // [2025 HYBRID PAGINATION]
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

    // [2026 KEYSET] If the UI only sends lastId, fetch the last sort value for stable cursor pagination.
    dynamic lastSortValue;
    if (lastId != null && sortColumn != 'id') {
      try {
        final cursorRow = await _pool!.execute(
          Sql.named('SELECT $sortColumn FROM orders WHERE id = @id'),
          parameters: {'id': lastId},
        );
        if (cursorRow.isNotEmpty) {
          lastSortValue = cursorRow.first[0];
        }
      } catch (e) {
        debugPrint('Sipariş cursor fetch error: $e');
      }
    }

    List<String> whereConditions = [];
    Map<String, dynamic> params = {};

    // Select Clause
    String selectCols = 'orders.*';

	    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
	      whereConditions.add(
	        "(search_tags ILIKE @search OR to_tsvector('simple', search_tags) @@ plainto_tsquery('simple', @fts))",
	      );
	      params['search'] = '%${aramaTerimi.toLowerCase()}%';
	      params['fts'] = aramaTerimi.toLowerCase();

	      // matched_in_hidden mantığı
	      selectCols += ''', (CASE 
	          WHEN (
	                 search_tags ILIKE @search
	                 OR to_tsvector('simple', search_tags) @@ plainto_tsquery('simple', @fts)
	               )
	               AND NOT (
	                 COALESCE(id::text, '') ILIKE @search OR
	                 COALESCE(tur, '') ILIKE @search OR 
                 COALESCE(durum, '') ILIKE @search OR 
                 COALESCE(TO_CHAR(tarih, 'DD.MM.YYYY'), '') ILIKE @search OR
                 COALESCE(cari_adi, '') ILIKE @search OR
                 COALESCE(ilgili_hesap_adi, '') ILIKE @search OR
                 COALESCE(tutar::text, '') ILIKE @search OR
                 COALESCE(REPLACE(tutar::text, '.', ','), '') ILIKE @search OR
                 COALESCE(kur::text, '') ILIKE @search OR
                 COALESCE(REPLACE(kur::text, '.', ','), '') ILIKE @search OR
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

    if (sadeceIdler != null && sadeceIdler.isNotEmpty) {
      whereConditions.add('id = ANY(@idArray)');
      params['idArray'] = sadeceIdler;
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
          'EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = orders.id';
      if (depoId != null) {
        existsQuery += ' AND oi.depo_id = @depoId';
        params['depoId'] = depoId;
      }
      if (birim != null && birim.trim().isNotEmpty) {
        existsQuery += ' AND oi.birim = @birim';
        params['birim'] = birim.trim();
      }
      existsQuery += ')';
      whereConditions.add(existsQuery);
    }

    if (lastId != null) {
      if (sortColumn == 'id') {
        whereConditions.add('id ${direction == 'ASC' ? '>' : '<'} @lastId');
        params['lastId'] = lastId;
      } else {
        final String op = direction == 'ASC' ? '>' : '<';
        if (lastSortValue == null) {
          // Fallback: still move forward with ID-based cursor (may be less stable but safe)
          whereConditions.add('id ${direction == 'ASC' ? '>' : '<'} @lastId');
          params['lastId'] = lastId;
        } else {
          whereConditions.add('($sortColumn, id) $op (@lastSortVal, @lastId)');
          params['lastSortVal'] = lastSortValue;
          params['lastId'] = lastId;
        }
      }
    }

    String whereClause = whereConditions.isEmpty
        ? ''
        : 'WHERE ${whereConditions.join(' AND ')}';

    final String orderByClause = sortColumn == 'id'
        ? 'ORDER BY id $direction'
        : 'ORDER BY $sortColumn $direction, id $direction';
    String query =
        '''
      SELECT $selectCols 
      FROM orders 
      $whereClause 
      $orderByClause 
      LIMIT @limit
    ''';

    params['limit'] = sayfaBasinaKayit;

    final results = await _pool!.execute(Sql.named(query), parameters: params);

    final orderMaps = results.map((row) => row.toColumnMap()).toList();
    final orderIds = <int>[];
    for (final map in orderMaps) {
      final orderId = _toInt(map['id']) ?? 0;
      if (orderId > 0) orderIds.add(orderId);
    }

    // [2026 PERF] Avoid N+1: fetch items for all orders in one query.
    final Map<int, List<SiparisUrunModel>> itemsByOrder = {};
    if (orderIds.isNotEmpty) {
      final itemsResult = await _pool!.execute(
        Sql.named('SELECT * FROM order_items WHERE order_id = ANY(@orderIds)'),
        parameters: {'orderIds': orderIds},
      );

      for (final itemRow in itemsResult) {
        final itemMap = itemRow.toColumnMap();
        final orderId = _toInt(itemMap['order_id']) ?? 0;
        if (orderId == 0) continue;
        final model = SiparisUrunModel(
          id: _toInt(itemMap['id']) ?? 0,
          urunId: _toInt(itemMap['urun_id']) ?? 0,
          urunKodu: itemMap['urun_kodu']?.toString() ?? '',
          urunAdi: itemMap['urun_adi']?.toString() ?? '',
          barkod: itemMap['barkod']?.toString() ?? '',
          depoId: _toInt(itemMap['depo_id']),
          depoAdi: itemMap['depo_adi']?.toString() ?? '',
          kdvOrani: _toDouble(itemMap['kdv_orani']),
          miktar: _toDouble(itemMap['miktar']),
          birim: itemMap['birim']?.toString() ?? 'Adet',
          birimFiyati: _toDouble(itemMap['birim_fiyati']),
          toplamFiyati: _toDouble(itemMap['toplam_fiyati']),
          paraBirimi: itemMap['para_birimi']?.toString() ?? 'TRY',
          kdvDurumu: itemMap['kdv_durumu']?.toString() ?? 'excluded',
          iskonto: _toDouble(itemMap['iskonto']),
        );
        (itemsByOrder[orderId] ??= []).add(model);
      }
    }

    final siparisler = <SiparisModel>[];
    for (final map in orderMaps) {
      final orderId = _toInt(map['id']) ?? 0;
      if (orderId == 0) continue;

      final urunler = itemsByOrder[orderId] ?? const <SiparisUrunModel>[];

      siparisler.add(
        SiparisModel(
          id: orderId,
          tur: map['tur']?.toString() ?? '',
          durum: map['durum']?.toString() ?? '',
          tarih: map['tarih'] is DateTime
              ? map['tarih']
              : DateTime.tryParse(map['tarih']?.toString() ?? '') ??
                    DateTime.now(),
          cariId: _toInt(map['cari_id']),
          cariKod: map['cari_kod']?.toString(),
          cariAdi: map['cari_adi']?.toString(),
          ilgiliHesapAdi: map['ilgili_hesap_adi']?.toString() ?? '',
          tutar: _toDouble(map['tutar']),
          kur: _toDouble(map['kur']),
          aciklama: map['aciklama']?.toString() ?? '',
          aciklama2: map['aciklama2']?.toString() ?? '',
          gecerlilikTarihi: map['gecerlilik_tarihi'] is DateTime
              ? map['gecerlilik_tarihi']
              : map['gecerlilik_tarihi'] != null
              ? DateTime.tryParse(map['gecerlilik_tarihi'].toString())
              : null,
          paraBirimi: map['para_birimi']?.toString() ?? 'TRY',
          kullanici: map['kullanici']?.toString() ?? '',
          integrationRef: map['integration_ref']?.toString(),
          orderNo: map['order_no']?.toString(),
          urunler: urunler,
          matchedInHidden: map['matched_in_hidden'] == true,
        ),
      );
    }

    return siparisler;
  }

  Future<int> siparisSayisiGetir({
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

    List<String> whereConditions = [];
    Map<String, dynamic> params = {};

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      whereConditions.add(
        "(search_tags ILIKE @search OR to_tsvector('simple', search_tags) @@ plainto_tsquery('simple', @fts))",
      );
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
      params['fts'] = aramaTerimi.toLowerCase();
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
          'EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = orders.id';
      if (depoId != null) {
        existsQuery += ' AND oi.depo_id = @depoId';
        params['depoId'] = depoId;
      }
      if (birim != null && birim.trim().isNotEmpty) {
        existsQuery += ' AND oi.birim = @birim';
        params['birim'] = birim.trim();
      }
      existsQuery += ')';
      whereConditions.add(existsQuery);
    }

    final String whereClause = whereConditions.isEmpty
        ? ''
        : 'WHERE ${whereConditions.join(' AND ')}';

    // [2026] Unfiltered: use reltuples estimate to avoid COUNT(*) on huge tables.
    if (whereConditions.isEmpty) {
      try {
        final approx = await _pool!.execute(
          "SELECT reltuples::BIGINT FROM pg_class WHERE relname = 'orders'",
        );
        if (approx.isNotEmpty && approx.first[0] != null) {
          final v = approx.first[0] as int;
          if (v > 0) return v;
        }
      } catch (e) {
        debugPrint('orders reltuples estimate failed: $e');
      }
    }

    // [2026] Filtered: use planner estimate first (fast), fallback to exact COUNT(*).
    try {
      final planResult = await _pool!.execute(
        Sql.named("EXPLAIN (FORMAT JSON) SELECT 1 FROM orders $whereClause"),
        parameters: params,
      );
      final planJson = planResult[0][0];

      dynamic decoded;
      if (planJson is String) {
        decoded = jsonDecode(planJson);
      } else {
        decoded = planJson;
      }

      if (decoded is List && decoded.isNotEmpty) {
        final planRows =
            num.tryParse(decoded[0]['Plan']['Plan Rows']?.toString() ?? '') ??
            0;
        if (planRows > 0) return planRows.toInt();
      }
    } catch (e) {
      debugPrint('orders count estimate failed: $e');
    }

    final result = await _pool!.execute(
      Sql.named('SELECT COUNT(*) FROM orders $whereClause'),
      parameters: params,
    );
    return _toInt(result.first[0]) ?? 0;
  }

  /// [2026 HYPER-SPEED] Dinamik filtre seçeneklerini ve sayıları getirir.
  /// Büyük veri için optimize edilmiştir (SARGable predicates + EXISTS + capped queries).
  Future<Map<String, Map<String, int>>> siparisFiltreIstatistikleriniGetir({
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
      baseConditions.add(
        "(search_tags ILIKE @search OR to_tsvector('simple', search_tags) @@ plainto_tsquery('simple', @fts))",
      );
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
      params['fts'] = aramaTerimi.toLowerCase();
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

    String buildOrderCappedGroupQuery(
      String selectAndGroup,
      List<String> facetConds,
    ) {
      final allConds = [...baseConditions, ...facetConds];
      final where = allConds.isEmpty ? '' : 'WHERE ${allConds.join(' AND ')}';
      return 'SELECT $selectAndGroup FROM (SELECT * FROM orders $where) as sub GROUP BY 1';
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
          'EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = orders.id';
      if (depoId != null) {
        existsQuery += ' AND oi.depo_id = @depoId';
        statusParams['depoId'] = depoId;
      }
      if (birim != null && birim.trim().isNotEmpty) {
        existsQuery += ' AND oi.birim = @birim';
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
          'EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = orders.id';
      if (depoId != null) {
        existsQuery += ' AND oi.depo_id = @depoId';
        typeParams['depoId'] = depoId;
      }
      if (birim != null && birim.trim().isNotEmpty) {
        existsQuery += ' AND oi.birim = @birim';
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
    // Birim seçiliyse, depot facet sayımı için item-level filtre
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
          'EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = orders.id';
      if (depoId != null) {
        existsQuery += ' AND oi.depo_id = @depoId';
        accountParams['depoId'] = depoId;
      }
      if (birim != null && birim.trim().isNotEmpty) {
        existsQuery += ' AND oi.birim = @birim';
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
          'EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = orders.id';
      if (depoId != null) {
        existsQuery += ' AND oi.depo_id = @depoId';
        userParams['depoId'] = depoId;
      }
      if (birim != null && birim.trim().isNotEmpty) {
        existsQuery += ' AND oi.birim = @birim';
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
          'EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = orders.id';
      if (depoId != null) {
        existsQuery += ' AND oi.depo_id = @depoId';
        totalParams['depoId'] = depoId;
      }
      if (birim != null && birim.trim().isNotEmpty) {
        existsQuery += ' AND oi.birim = @birim';
        totalParams['birim'] = birim.trim();
      }
      existsQuery += ')';
      totalConds.add(existsQuery);
    }
    final totalWhere = totalConds.isEmpty
        ? ''
        : 'WHERE ${totalConds.join(' AND ')}';
    final totalQuery = 'SELECT COUNT(*) FROM orders $totalWhere';

    final depotQuery =
        '''
      WITH filtered_orders AS (
        SELECT id FROM orders ${([...baseConditions, ...depotOrderConds]).isEmpty ? '' : 'WHERE ${([...baseConditions, ...depotOrderConds]).join(' AND ')}'}
      )
      SELECT oi.depo_id, COUNT(DISTINCT fo.id)
      FROM filtered_orders fo
      JOIN order_items oi ON oi.order_id = fo.id
      ${selectedUnit != null ? 'WHERE oi.birim = @birim' : ''}
      GROUP BY oi.depo_id
    ''';

    final unitQuery =
        '''
      WITH filtered_orders AS (
        SELECT id FROM orders ${([...baseConditions, ...unitOrderConds]).isEmpty ? '' : 'WHERE ${([...baseConditions, ...unitOrderConds]).join(' AND ')}'}
      )
      SELECT oi.birim, COUNT(DISTINCT fo.id)
      FROM filtered_orders fo
      JOIN order_items oi ON oi.order_id = fo.id
      ${selectedDepotId != null ? 'WHERE oi.depo_id = @depoId' : ''}
      GROUP BY oi.birim
    ''';

    final results = await Future.wait([
      _pool!.execute(Sql.named(totalQuery), parameters: totalParams),
      _pool!.execute(
        Sql.named(buildOrderCappedGroupQuery('durum, COUNT(*)', statusConds)),
        parameters: statusParams,
      ),
      _pool!.execute(
        Sql.named(buildOrderCappedGroupQuery('tur, COUNT(*)', typeConds)),
        parameters: typeParams,
      ),
      _pool!.execute(Sql.named(depotQuery), parameters: depotParams),
      _pool!.execute(Sql.named(unitQuery), parameters: unitParams),
      _pool!.execute(
        Sql.named(
          buildOrderCappedGroupQuery(
            'ilgili_hesap_adi, COUNT(*)',
            accountConds,
          ),
        ),
        parameters: accountParams,
      ),
      _pool!.execute(
        Sql.named(buildOrderCappedGroupQuery('kullanici, COUNT(*)', userConds)),
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

  Future<bool> siparisSil(int id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    try {
      await _pool!.runTx((ctx) async {
        // [STOCK RESERVATION] Silmeden önce eğer rezerve edilmişse çöz
        final check = await ctx.execute(
          Sql.named('SELECT stok_rezerve_mi FROM orders WHERE id = @id'),
          parameters: {'id': id},
        );
        if (check.isNotEmpty && check.first[0] == true) {
          await _stokRezervasyonunuYonet(ctx: ctx, orderId: id, isArtis: false);
        }

        await ctx.execute(
          Sql.named('DELETE FROM order_items WHERE order_id = @id'),
          parameters: {'id': id},
        );
        await ctx.execute(
          Sql.named('DELETE FROM orders WHERE id = @id'),
          parameters: {'id': id},
        );
      });
      return true;
    } catch (e) {
      debugPrint('Sipariş silme hatası: $e');
      return false;
    }
  }

  Future<bool> siparisSilByRef(String ref) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    try {
      await _pool!.runTx((ctx) async {
        final result = await ctx.execute(
          Sql.named('SELECT id FROM orders WHERE integration_ref = @ref'),
          parameters: {'ref': ref},
        );
        if (result.isNotEmpty) {
          final id = _toInt(result.first[0]) ?? 0;
          if (id == 0) return;
          await ctx.execute(
            Sql.named('DELETE FROM order_items WHERE order_id = @id'),
            parameters: {'id': id},
          );
          await ctx.execute(
            Sql.named('DELETE FROM orders WHERE id = @id'),
            parameters: {'id': id},
          );
        }
      });
      return true;
    } catch (e) {
      debugPrint('Sipariş silme hatası (Ref): $e');
      return false;
    }
  }

  Future<void> siparisGuncelle({
    required int orderId,
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
    if (_pool == null) return;

    final kullanici = await _getCurrentUser();

	    await _pool!.runTx((ctx) async {
	      // [STOCK RESERVATION] Ürünleri silmeden önce eğer rezerve edilmişse çöz
	      final check = await ctx.execute(
	        Sql.named(
	          'SELECT stok_rezerve_mi, integration_ref, order_no FROM orders WHERE id = @orderId',
	        ),
	        parameters: {'orderId': orderId},
	      );
	      final existingIntegrationRef =
	          check.isNotEmpty ? (check.first[1]?.toString() ?? '').trim() : '';
	      final existingOrderNo =
	          check.isNotEmpty ? (check.first[2]?.toString() ?? '').trim() : '';

	      if (check.isNotEmpty && check.first[0] == true) {
	        await _stokRezervasyonunuYonet(
	          ctx: ctx,
	          orderId: orderId,
	          isArtis: false,
	        );
	      }

      // Önce ürünleri sil (Atomic update stratejisi)
      await ctx.execute(
        Sql.named('DELETE FROM order_items WHERE order_id = @orderId'),
        parameters: {'orderId': orderId},
      );

      // Ana siparişi güncelle
	      final itemTags = urunler
	          .map((u) => _buildOrderItemSearchTags(u))
	          .join(' ');

	      final professionalTur = IslemTuruRenkleri.getProfessionalLabel(
	        tur,
	        context: 'cari',
	      );
	      final searchTags = [
	        orderId.toString(),
	        existingIntegrationRef,
	        existingOrderNo,
	        professionalTur,
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
	        '|v2026|',
	        itemTags,
	      ].join(' ').toLowerCase();

      await ctx.execute(
        Sql.named('''
          UPDATE orders SET
            tur = @tur,
            durum = @durum,
            tarih = @tarih,
            cari_id = @cariId,
            cari_kod = @cariKod,
            cari_adi = @cariAdi,
            ilgili_hesap_adi = @ilgiliHesapAdi,
            tutar = @tutar,
            kur = @kur,
            aciklama = @aciklama,
            aciklama2 = @aciklama2,
            gecerlilik_tarihi = @gecerlilikTarihi,
            para_birimi = @paraBirimi,
            search_tags = @searchTags,
            updated_at = CURRENT_TIMESTAMP
          WHERE id = @orderId
        '''),
        parameters: {
          'orderId': orderId,
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
          'searchTags': searchTags,
        },
      );

      // Yeni ürünleri ekle
	      if (urunler.isNotEmpty) {
	        for (final urun in urunler) {
	          final itemSearchTags = _buildOrderItemSearchTags(urun);

	          if (_orderItemsHasSearchTags) {
	            await ctx.execute(
	              Sql.named('''
	                INSERT INTO order_items (
	                  order_id, urun_id, urun_kodu, urun_adi, barkod, depo_id, depo_adi,
	                  kdv_orani, miktar, birim, birim_fiyati, para_birimi, kdv_durumu,
	                  iskonto, toplam_fiyati, search_tags
	                ) VALUES (
	                  @orderId, @urunId, @urunKodu, @urunAdi, @barkod, @depoId, @depoAdi,
	                  @kdvOrani, @miktar, @birim, @birimFiyati, @paraBirimi, @kdvDurumu,
	                  @iskonto, @toplamFiyati, @searchTags
	                )
	              '''),
	              parameters: {
	                'orderId': orderId,
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
	                'searchTags': itemSearchTags,
	              },
	            );
	          } else {
	            await ctx.execute(
	              Sql.named('''
	                INSERT INTO order_items (
	                  order_id, urun_id, urun_kodu, urun_adi, barkod, depo_id, depo_adi,
	                  kdv_orani, miktar, birim, birim_fiyati, para_birimi, kdv_durumu,
	                  iskonto, toplam_fiyati
	                ) VALUES (
	                  @orderId, @urunId, @urunKodu, @urunAdi, @barkod, @depoId, @depoAdi,
	                  @kdvOrani, @miktar, @birim, @birimFiyati, @paraBirimi, @kdvDurumu,
	                  @iskonto, @toplamFiyati
	                )
	              '''),
	              parameters: {
	                'orderId': orderId,
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
	      }

      // [STOCK RESERVATION] Eğer durum 'Onaylandı' ise yeni stokları rezerve et
      if (durum == 'Onaylandı') {
        await _stokRezervasyonunuYonet(
          ctx: ctx,
          orderId: orderId,
          isArtis: true,
        );
      }
    });
  }

  Future<bool> siparisDurumGuncelle(
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
          'UPDATE orders SET durum = @durum, updated_at = CURRENT_TIMESTAMP WHERE id = @id',
        ),
        parameters: {'id': id, 'durum': durum},
      );
      return true;
    } catch (e) {
      // [EMERGENCY FIX] Partition hatası (23514)
      if (e.toString().contains('23514') ||
          e.toString().contains('no partition of relation')) {
        debugPrint(
          'Siparişler: Partition hatası (23514) algılandı. Düzeltme uygulanıyor...',
        );
        await _emergencyFixForPartitioning();
        // Düzeltme sonrası tekrar dene (Recursive değil, tek seferlik manuel tekrar)
        return await siparisDurumGuncelle(id, durum, session: session);
      }
      debugPrint('Sipariş durum güncelleme hatası: $e');
      return false;
    }
  }

  /// [23514 FIX] Eğer insert/update sırasında partition hatası alınırsa bu fonksiyon
  /// eksik olan partition'ı dinamik olarak oluşturur (Self-Healing).
  Future<void> _emergencyFixForPartitioning() async {
    debugPrint(
      'Siparişler: Eksik partition tespit edildi. Self-healing devreye giriyor...',
    );

    try {
      // Olası partition eksiklikleri için geniş bir aralığı kontrol et
      final now = DateTime.now();
      await _ensurePartitionExists(now); // Bu ay
      await _ensurePartitionExists(
        now.add(const Duration(days: 32)),
      ); // Gelecek ay
      await _ensurePartitionExists(
        now.subtract(const Duration(days: 32)),
      ); // Geçen ay

      debugPrint('✅ Partition onarımı tamamlandı.');
    } catch (e) {
      debugPrint('Partition onarım hatası: $e');
    }
  }

  /// Satış işlemi sırasında siparişin faturaya dönüştüğünü işaretler.
  Future<bool> siparisSatisReferansGuncelle(
    int id,
    String salesRef, {
    TxSession? session,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    try {
      final executor = session ?? _pool!;
      await executor.execute(
        Sql.named(
          'UPDATE orders SET sales_ref = @salesRef, updated_at = CURRENT_TIMESTAMP WHERE id = @id',
        ),
        parameters: {'id': id, 'salesRef': salesRef},
      );
      return true;
    } catch (e) {
      debugPrint('Sipariş satış referansı güncelleme hatası: $e');
      return false;
    }
  }

  /// [SMART SYNC] Satış iptal edildiğinde (silindiğinde), o satışa bağlı siparişin durumunu geri alır.
  /// sales_ref üzerinden eşleşen siparişi bulur, sales_ref'i temizler ve durumu günceller.
  Future<bool> siparisDurumGuncelleBySalesRef(
    String salesRef,
    String yeniDurum, {
    TxSession? session,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    try {
      final executor = session ?? _pool!;
      // sales_ref'i eşleşen siparişi bul, durumunu güncelle ve sales_ref'i NULL yap (Bağlantı koptu)
      await executor.execute(
        Sql.named(
          'UPDATE orders SET durum = @durum, sales_ref = NULL, updated_at = CURRENT_TIMESTAMP WHERE sales_ref = @salesRef',
        ),
        parameters: {'durum': yeniDurum, 'salesRef': salesRef},
      );
      return true;
    } catch (e) {
      debugPrint('Sipariş durum güncelleme (SalesRef) hatası: $e');
      return false;
    }
  }

  Future<bool> siparisTurVeDurumGuncelle(
    int id,
    String tur,
    String durum,
  ) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    try {
      await _pool!.execute(
        Sql.named(
          'UPDATE orders SET tur = @tur, durum = @durum, updated_at = CURRENT_TIMESTAMP WHERE id = @id',
        ),
        parameters: {'id': id, 'tur': tur, 'durum': durum},
      );
      return true;
    } catch (e) {
      debugPrint('Sipariş tür/durum güncelleme hatası: $e');
      return false;
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is BigInt) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  /// [STOCK RESERVATION] Stok rezervasyonunu yöneten yardımcı metod.
  Future<void> _stokRezervasyonunuYonet({
    required TxSession ctx,
    required int orderId,
    required bool isArtis,
  }) async {
    // Fetch items for this order
    final items = await ctx.execute(
      Sql.named(
        'SELECT urun_id, urun_kodu, miktar, depo_id FROM order_items WHERE order_id = @id',
      ),
      parameters: {'id': orderId},
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

    // Update the flag in orders table
    await ctx.execute(
      Sql.named(
        'UPDATE orders SET stok_rezerve_mi = @rezerve, updated_at = CURRENT_TIMESTAMP WHERE id = @id',
      ),
      parameters: {'rezerve': isArtis, 'id': orderId},
    );
  }
}
