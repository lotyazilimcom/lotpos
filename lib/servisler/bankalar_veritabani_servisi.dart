import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:intl/intl.dart';
import 'arama/hizli_sayim_yardimcisi.dart';
import 'cari_hesaplar_veritabani_servisi.dart';
import 'kasalar_veritabani_servisi.dart';
import 'kredi_kartlari_veritabani_servisi.dart';
import 'personel_islemleri_veritabani_servisi.dart';
import '../sayfalar/bankalar/modeller/banka_model.dart';
import 'oturum_servisi.dart';
import 'lisans_yazma_koruma.dart';
import 'lite_kisitlari.dart';
import 'bulut_sema_dogrulama_servisi.dart';
import 'pg_eklentiler.dart';
import 'veritabani_yapilandirma.dart';
import 'ayarlar_veritabani_servisi.dart';
import 'veritabani_havuzu.dart';

class BankalarVeritabaniServisi {
  static final BankalarVeritabaniServisi _instance =
      BankalarVeritabaniServisi._internal();
  factory BankalarVeritabaniServisi() => _instance;
  BankalarVeritabaniServisi._internal();

  Pool? _pool;
  bool _isInitialized = false;
  String? _initializedDatabase;
  String? _initializingDatabase;
  static const String _searchTagsVersionPrefix = 'v6';

  Completer<void>? _initCompleter;
  int _initToken = 0;

  static const String _defaultCompanyId = 'patisyo2025';
  String get _companyId => OturumServisi().aktifVeritabaniAdi;

  /// [2026 FIX] Türkçe karakterleri ASCII karşılıklarına normalize eder.
  /// PostgreSQL tarafındaki normalize_text fonksiyonu ile tam uyumlu çalışır.
  String _normalizeTurkish(String text) {
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

  Future<List<int>> _eslesenBankaIslemIdleriniGetir({
    required Session executor,
    required String normalizedSearch,
  }) async {
    if (normalizedSearch.trim().length < 3) return const <int>[];
    try {
      final rows = await executor.execute(
        Sql.named('''
          SELECT DISTINCT bt.bank_id
          FROM bank_transactions bt
          WHERE bt.bank_id IS NOT NULL
            AND COALESCE(bt.company_id, '$_defaultCompanyId') = @companyId
            AND bt.search_tags LIKE @search
          ORDER BY bt.bank_id ASC
          LIMIT 2048
        '''),
        parameters: {'companyId': _companyId, 'search': '%$normalizedSearch%'},
      );
      return rows
          .map((row) => int.tryParse(row[0]?.toString() ?? ''))
          .whereType<int>()
          .toList(growable: false);
    } catch (e) {
      debugPrint('Banka arama ID fetch error: $e');
      return const <int>[];
    }
  }

  String _bankaAramaKosulu({
    required String alias,
    required String idParam,
    required bool hasTxMatches,
  }) {
    if (!hasTxMatches) {
      return '$alias.search_tags LIKE @search';
    }
    return '($alias.search_tags LIKE @search OR $alias.id = ANY(@$idParam))';
  }

  String _bankaHiddenTxKosulu({
    required String alias,
    required String idParam,
    required bool hasTxMatches,
  }) {
    if (!hasTxMatches) return 'FALSE';
    return '$alias.id = ANY(@$idParam)';
  }

  // Merkezi yapılandırma
  final VeritabaniYapilandirma _config = VeritabaniYapilandirma();

  Future<void> baslat() async {
    final targetDatabase = OturumServisi().aktifVeritabaniAdi;
    if (_isInitialized && _initializedDatabase == targetDatabase) return;

    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      if (_initializingDatabase == targetDatabase) {
        return _initCompleter!.future;
      }
      try {
        await _initCompleter!.future;
      } catch (_) {}
    }

    if (_pool != null &&
        _initializedDatabase != null &&
        _initializedDatabase != targetDatabase) {
      await VeritabaniHavuzu().kapatPool(_pool);
      _pool = null;
      _isInitialized = false;
      _initializedDatabase = null;
    }

    final initToken = ++_initToken;
    final initCompleter = Completer<void>();
    _initCompleter = initCompleter;
    _initializingDatabase = targetDatabase;

    try {
      final Pool createdPool = await VeritabaniHavuzu().havuzAl(
        database: targetDatabase,
      );
      _pool = createdPool;

      final semaHazir = await BulutSemaDogrulamaServisi().bulutSemasiHazirMi(
        executor: createdPool,
        databaseName: targetDatabase,
      );
      if (!semaHazir) {
        await _tablolariOlustur();
      } else {
        debugPrint(
          'BankalarVeritabaniServisi: Bulut şema hazır, tablo kurulumu atlandı.',
        );
        // Kullanıcının manuel psql çalıştırmasına gerek kalmasın:
        // SELECT relkind FROM pg_class WHERE relname='bank_transactions';
        try {
          final rel = await createdPool.execute(
            "SELECT relkind::text FROM pg_class WHERE relname = 'bank_transactions' LIMIT 1",
          );
          if (rel.isNotEmpty) {
            final String relkind = (rel.first[0]?.toString() ?? '')
                .toLowerCase();
            debugPrint('bank_transactions relkind=$relkind (p=partitioned)');
          }
        } catch (_) {}

        // Bulut şema "hazır" olsa bile aylık partitionlar runtime'da lazımdır.
        // Best-effort: DDL yetkisi yoksa sessizce DEFAULT partition ile devam eder.
        try {
          await _createBankPartitions(DateTime.now());
        } catch (e) {
          debugPrint(
            'BankalarVeritabaniServisi: Partition bootstrap uyarısı: $e',
          );
        }
      }
      if (initToken != _initToken) {
        if (!initCompleter.isCompleted) {
          initCompleter.completeError(StateError('Bağlantı kapatıldı'));
        }
        return;
      }

      _isInitialized = true;
      _initializedDatabase = targetDatabase;
      _initializingDatabase = null;
      debugPrint(
        'BankalarVeritabaniServisi: Pool connection established successfully.',
      );
      if (!initCompleter.isCompleted) {
        initCompleter.complete();
      }
    } catch (e) {
      debugPrint('BankalarVeritabaniServisi: Connection error: $e');
      if (initToken == _initToken) {
        await VeritabaniHavuzu().kapatPool(_pool);
        _pool = null;
        _isInitialized = false;
        _initializedDatabase = null;
        _initializingDatabase = null;
      }
      if (!initCompleter.isCompleted) {
        initCompleter.completeError(e);
      }
      if (identical(_initCompleter, initCompleter)) {
        _initCompleter = null;
      }
    }
  }

  /// Pool bağlantısını güvenli şekilde kapatır ve tüm durum değişkenlerini sıfırlar.
  Future<void> baglantiyiKapat() async {
    _initToken++;
    final pending = _initCompleter;
    _initCompleter = null;
    _initializingDatabase = null;

    final pool = _pool;
    _pool = null;
    _isInitialized = false;
    _initializedDatabase = null;

    await VeritabaniHavuzu().kapatPool(pool);
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('Bağlantı kapatıldı'));
    }
  }

  Future<void> _tablolariOlustur() async {
    if (_pool == null) return;

    // Create Banks Table
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS banks (
        id BIGSERIAL PRIMARY KEY,
        company_id TEXT,
        code TEXT,
        name TEXT,
        balance NUMERIC(15, 2) DEFAULT 0,
        currency TEXT,
        branch_code TEXT,
        branch_name TEXT,
        account_no TEXT,
        iban TEXT,
        info1 TEXT,
        info2 TEXT,
        is_active INTEGER DEFAULT 1,
        is_default INTEGER DEFAULT 0,
        search_tags TEXT NOT NULL DEFAULT '',
        matched_in_hidden INTEGER DEFAULT 0
      )
    ''');

    // [2026 FIX] Hyper-Optimized Turkish Normalization & Professional Labels (ALWAYS UPDATE FIRST)
    try {
      // 1. Label Fonksiyonu
      // 2 parametreli çağrılarda "is not unique" hatası oluşabiliyor.
      // Çözüm: 3 parametreli overload'un DEFAULT'larını kaldıran (no-default) bir sürümle replace et.
      int defaultCount = 0;
      try {
        final procRows = await _pool!.execute('''
            SELECT pronargdefaults
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE p.proname = 'get_professional_label'
              AND n.nspname = 'public'
              AND p.pronargs = 3
            LIMIT 1
          ''');

        defaultCount = procRows.isNotEmpty
            ? (int.tryParse(procRows.first[0].toString()) ?? 0)
            : 0;
      } catch (e) {
        debugPrint('PostgreSQL System Catalog Warning (Safe to ignore): $e');
      }

      if (defaultCount > 0) {
        try {
          await _pool!.execute(
            'DROP FUNCTION IF EXISTS get_professional_label(text, text, text)',
          );
        } catch (_) {}

        await _pool!.execute('''
            CREATE OR REPLACE FUNCTION get_professional_label(raw_type TEXT, context TEXT, direction TEXT) RETURNS TEXT AS \$\$
            BEGIN
              RETURN get_professional_label(raw_type, context);
            END;
            \$\$ LANGUAGE plpgsql;
          ''');
      }

      await _pool!.execute('''
          CREATE OR REPLACE FUNCTION get_professional_label(raw_type TEXT, context TEXT DEFAULT '') RETURNS TEXT AS \$\$

          DECLARE
              t TEXT := LOWER(TRIM(raw_type));
              ctx TEXT := LOWER(TRIM(context));
          BEGIN
              IF raw_type IS NULL OR raw_type = '' THEN
                  RETURN 'İşlem';
              END IF;

              -- KASA
              IF ctx = 'cash' OR ctx = 'kasa' THEN
                  IF t ~ 'tahsilat' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Kasa Tahsilat';
                  ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Kasa Ödeme';
                  END IF;
                  RETURN raw_type;
              END IF;

              -- BANKA
              IF ctx = 'bank' OR ctx = 'banka' THEN
                  IF t ~ 'tahsilat' OR t ~ 'giriş' OR t ~ 'giris' OR t ~ 'havale' OR t ~ 'eft' THEN RETURN 'Banka Tahsilat';
                  ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Banka Ödeme';
                  ELSIF t ~ 'transfer' THEN RETURN 'Banka Transfer';
                  END IF;
                  RETURN raw_type;
              END IF;

              -- KREDI KARTI
              IF ctx = 'credit_card' OR ctx = 'kredi_karti' THEN
                  IF t ~ 'tahsilat' OR t ~ 'collection' THEN RETURN 'K.Kartı Tahsilat';
                  ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'payment' THEN RETURN 'K.Kartı Ödeme';
                  ELSIF t ~ 'harcama' OR t ~ 'gider' THEN RETURN 'K.Kartı Harcama';
                  END IF;
                  RETURN raw_type;
              END IF;

              -- ÇEK
              IF ctx = 'cheque' OR ctx = 'cek' THEN
                  IF t ~ 'tahsil' THEN RETURN 'Çek Alındı (Tahsil Edildi)';
                  ELSIF t ~ 'ciro' THEN RETURN 'Senet Ciro';
                  ELSIF t ~ 'verilen' OR t ~ 'verildi' THEN RETURN 'Senet Verildi';
                  ELSIF t ~ 'alınan' OR t ~ 'alinan' OR t ~ 'alındı' OR t ~ 'alindi' THEN RETURN 'Senet Alındı';
                  ELSIF t ~ 'karşılıksız' OR t ~ 'karsiliksiz' THEN RETURN 'Karşılıksız Senet';
                  END IF;
                  RETURN raw_type;
              END IF;

              -- CARİ (MAIN LOGIC)
              IF ctx = 'current_account' OR ctx = 'cari' THEN
                  -- 1. Satış / Alış
                  IF t = 'satış yapıldı' OR t = 'satis yapildi' OR t ~ 'sale-' THEN RETURN 'Satış Yapıldı';
                  ELSIF t = 'alış yapıldı' OR t = 'alis yapildi' OR t ~ 'purchase-' THEN RETURN 'Alış Yapıldı';
                  
                  -- 2. Tahsilat / Ödeme
                  ELSIF t ~ 'para alındı' OR t ~ 'para alindi' OR t ~ 'collection' OR t ~ 'tahsilat' THEN RETURN 'Para Alındı';
                  ELSIF t ~ 'para verildi' OR t ~ 'para verildi' OR t ~ 'payment' OR t ~ 'ödeme' OR t ~ 'odeme' THEN RETURN 'Para Verildi';

                  -- 3. Borç / Alacak (Manuel)
                  ELSIF t = 'borç' OR t = 'borc' THEN RETURN 'Cari Borç';
                  ELSIF t = 'alacak' THEN RETURN 'Cari Alacak';
                  ELSIF t ~ 'borç dekontu' OR t ~ 'borc dekontu' THEN RETURN 'Borç Dekontu';
                  ELSIF t ~ 'alacak dekontu' THEN RETURN 'Alacak Dekontu';

                  -- 4. Çek İşlemleri
                  ELSIF t ~ 'çek' OR t ~ 'cek' OR t ~ 'cheque' THEN
                      IF t ~ 'tahsil' OR t ~ 'alındı' OR t ~ 'alindi' OR t ~ 'alinan' THEN RETURN 'Çek Alındı (Tahsil Edildi)';
                      ELSIF t ~ 'ödendi' OR t ~ 'odendi' OR t ~ 'verildi' OR t ~ 'verilen' THEN RETURN 'Çek Verildi (Ödendi)';
                      ELSIF t ~ 'ciro' THEN RETURN 'Çek Ciro Edildi';
                      ELSIF t ~ 'karşılıksız' OR t ~ 'karsiliksiz' THEN RETURN 'Karşılıksız Çek';
                      ELSE RETURN 'Çek İşlemi';
                      END IF;

                  -- 5. Senet İşlemleri
                  ELSIF t ~ 'senet' OR t ~ 'note' THEN
                      IF t ~ 'tahsil' OR t ~ 'alındı' OR t ~ 'alindi' OR t ~ 'alinan' THEN RETURN 'Senet Alındı (Tahsil Edildi)';
                      ELSIF t ~ 'ödendi' OR t ~ 'odendi' OR t ~ 'verildi' OR t ~ 'verilen' THEN RETURN 'Senet Verildi (Ödendi)';
                      ELSIF t ~ 'ciro' THEN RETURN 'Senet Ciro Edildi';
                      ELSIF t ~ 'karşılıksız' OR t ~ 'karsiliksiz' THEN RETURN 'Karşılıksız Senet';
                      ELSE RETURN 'Senet İşlemi';
                      END IF;
                  END IF;

                  RETURN raw_type;
              END IF;

              -- STOK
              IF ctx = 'stock' OR ctx = 'stok' THEN
                  IF t ~ 'açılış' OR t ~ 'acilis' THEN RETURN 'Açılış Stoğu';
                  ELSIF t ~ 'devir' AND t ~ 'gir' THEN RETURN 'Devir Giriş';
                  ELSIF t ~ 'devir' AND t ~ 'çık' THEN RETURN 'Devir Çıkış';
                  ELSIF t ~ 'üretim' OR t ~ 'uretim' THEN RETURN 'Üretim';
                  ELSIF t ~ 'satış' OR t ~ 'satis' THEN RETURN 'Satış';
                  ELSIF t ~ 'alış' OR t ~ 'alis' THEN RETURN 'Alış';
                  END IF;
              END IF;

              RETURN raw_type;
          END;
          \$\$ LANGUAGE plpgsql;
        ''');

      // 2. Normalize Text Fonksiyonu
      await _pool!.execute('''
          -- [2026 FIX] Hyper-Optimized Turkish Normalization for 100B+ Rows
          CREATE OR REPLACE FUNCTION normalize_text(val TEXT) RETURNS TEXT AS \$\$
          BEGIN
              IF val IS NULL THEN RETURN ''; END IF;
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
    } catch (_) {}

    // [2025 HYPERSCALE] Create Bank Transactions Table - Native Partitioning Support

    try {
      // 1. Ana tablonun durumunu kontrol et
      final tableCheck = await _pool!.execute(
        "SELECT relkind::text FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'bank_transactions'",
      );

      bool isPartitioned = false;
      bool tableExists = tableCheck.isNotEmpty;

      if (tableExists) {
        final String relkind = tableCheck.first[0].toString().toLowerCase();
        isPartitioned = relkind.contains('p');
        debugPrint(
          'Banka Hareketleri Tablo Durumu: tableExists=true, relkind=$relkind, isPartitioned=$isPartitioned',
        );
      }

      // 2. Eğer tablo YOK - yeni partitioned tablo oluştur
      if (!tableExists) {
        debugPrint('Banka hareketleri tablosu oluşturuluyor (Partitioned)...');
        await _pool!.execute('''
          CREATE TABLE IF NOT EXISTS bank_transactions (
            id BIGSERIAL,
            company_id TEXT,
            bank_id BIGINT,
            date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            description TEXT,
            amount NUMERIC(15, 2) DEFAULT 0,
            type TEXT,
            location TEXT,
            location_code TEXT,
            location_name TEXT,
            user_name TEXT,
            integration_ref TEXT,
            search_tags TEXT NOT NULL DEFAULT '',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id, date)
          ) PARTITION BY RANGE (date)
        ''');
        isPartitioned = true;
      }

      // 3. Eğer tablo VAR ama partitioned DEĞİL - migration gerekli
      if (tableExists && !isPartitioned) {
        debugPrint(
          '⚠️ Banka hareketleri tablosu regular modda. Partitioned yapıya geçiliyor...',
        );

        // Eski tabloyu yeniden adlandır
        await _pool!.execute(
          'DROP TABLE IF EXISTS bank_transactions_old CASCADE',
        );
        await _pool!.execute(
          'ALTER TABLE bank_transactions RENAME TO bank_transactions_old',
        );

        // [FIX] Rename sequence to avoid collision
        try {
          await _pool!.execute(
            'ALTER SEQUENCE IF EXISTS bank_transactions_id_seq RENAME TO bank_transactions_old_id_seq',
          );
        } catch (_) {}

        // Yeni partitioned tabloyu oluştur
        await _pool!.execute('''
          CREATE TABLE bank_transactions (
            id BIGSERIAL,
            company_id TEXT,
            bank_id BIGINT,
            date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            description TEXT,
            amount NUMERIC(15, 2) DEFAULT 0,
            type TEXT,
            location TEXT,
            location_code TEXT,
            location_name TEXT,
            user_name TEXT,
            integration_ref TEXT,
            search_tags TEXT NOT NULL DEFAULT '',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id, date)
          ) PARTITION BY RANGE (date)
        ''');
        isPartitioned = true;
      }

      // 4. Partition'ların olduğundan emin ol (ULTRA ROBUST)
      if (isPartitioned) {
        final DateTime now = DateTime.now();

        // Sadece cari ayı bekle (HIZ İÇİN)
        await _createBankPartitions(now);

        // Arka Plan İşlemleri: İndeksler, Triggerlar ve Diğer Yıllar
        if (_config.allowBackgroundDbMaintenance &&
            _config.allowBackgroundHeavyMaintenance) {
          unawaited(() async {
            try {
              if (isPartitioned) {
                for (int i = -24; i <= 60; i++) {
                  if (i == 0) continue;
                  await _createBankPartitions(
                    DateTime(now.year, now.month + i, 1),
                  );
                }

                // DEFAULT partition
                await _pool!.execute('''
                CREATE TABLE IF NOT EXISTS bank_transactions_default 
                PARTITION OF bank_transactions DEFAULT
              ''');
              }
              // [100B/20Y] DEFAULT partition'a yığılan eski verileri doğru aylık partitionlara taşı (best-effort).
              // [100B SAFE] Varsayılan kapalı.
              try {
                await _backfillBankTransactionsDefault();
              } catch (e) {
                debugPrint('Banka default backfill uyarısı: $e');
              }
              // Diğer ağır işlemler metodun sonunda tetiklenecek
            } catch (e) {
              debugPrint('Banka arka plan kurulum hatası: $e');
            }
          }());
        }
      }

      // 5. _old tablosu varsa migration yap
      final oldTableCheck = await _pool!.execute(
        "SELECT 1 FROM pg_class WHERE relname = 'bank_transactions_old' LIMIT 1",
      );

      if (oldTableCheck.isNotEmpty) {
        debugPrint('💾 Eski banka hareketleri yeni bölümlere aktarılıyor...');
        try {
          // [100B/20Y] Eski veriler DEFAULT partition'a yığılmasın:
          // Önce eski tablodaki tarih aralığına göre aylık partition'ları hazırla.
          try {
            final rangeRows = await _pool!.execute('''
              SELECT
                MIN(COALESCE(date, created_at)),
                MAX(COALESCE(date, created_at))
              FROM bank_transactions_old
            ''');
            if (rangeRows.isNotEmpty) {
              final minDt = rangeRows.first[0] as DateTime?;
              final maxDt = rangeRows.first[1] as DateTime?;
              if (minDt != null && maxDt != null) {
                await _ensureBankPartitionsForRange(minDt, maxDt);
              }
            }
          } catch (e) {
            debugPrint('Banka partition aralık hazırlığı uyarısı: $e');
          }

          await _pool!.execute('''
            INSERT INTO bank_transactions (
              id, company_id, bank_id, date, description, amount, type, 
              location, location_code, location_name, user_name, integration_ref, created_at
            )
            SELECT 
              id, company_id, bank_id, COALESCE(date, created_at, CURRENT_TIMESTAMP), 
              description, amount, type, location, location_code, location_name, 
              user_name, integration_ref, created_at
            FROM bank_transactions_old
            ON CONFLICT (id, date) DO NOTHING
          ''');

          // Sequence güncelle (Serial için kritik)
          final maxIdResult = await _pool!.execute(
            'SELECT COALESCE(MAX(id), 0) FROM bank_transactions',
          );
          final maxId =
              int.tryParse(maxIdResult.first[0]?.toString() ?? '0') ?? 0;
          if (maxId > 0) {
            await _pool!.execute(
              "SELECT setval(pg_get_serial_sequence('bank_transactions', 'id'), $maxId)",
            );
          }

          // [100B/20Y] DEFAULT partition'a düşmüş eski satırları ilgili aylık partitionlara taşı (best-effort).
          // [100B SAFE] Varsayılan kapalı.
          if (_config.allowBackgroundDbMaintenance &&
              _config.allowBackgroundHeavyMaintenance) {
            try {
              await _backfillBankTransactionsDefault();
            } catch (e) {
              debugPrint('Banka default backfill uyarısı: $e');
            }
          }

          // Migration başarılı - _old tablosunu sil
          await _pool!.execute('DROP TABLE bank_transactions_old CASCADE');
          debugPrint('✅ Banka hareketleri başarıyla bölümlendirildi.');
        } catch (e) {
          debugPrint('❌ Migration hatası (Banka): $e');
        }
      }
    } catch (e) {
      debugPrint('Banka hareketleri ana yapı kurulum hatası: $e');
      rethrow;
    }

    // [2025 JET] Kritik olmayan tüm işlemler arka plana
    if (_config.allowBackgroundDbMaintenance) {
      unawaited(() async {
        try {
          await _pool!.execute(
            'ALTER TABLE bank_transactions ADD COLUMN IF NOT EXISTS location TEXT',
          );
          await _pool!.execute(
            'ALTER TABLE bank_transactions ADD COLUMN IF NOT EXISTS location_code TEXT',
          );
          await _pool!.execute(
            'ALTER TABLE bank_transactions ADD COLUMN IF NOT EXISTS location_name TEXT',
          );
          await _pool!.execute(
            'ALTER TABLE bank_transactions ADD COLUMN IF NOT EXISTS integration_ref TEXT',
          );
          await _pool!.execute(
            'ALTER TABLE banks ADD COLUMN IF NOT EXISTS company_id TEXT',
          );
          await _pool!.execute(
            'ALTER TABLE bank_transactions ADD COLUMN IF NOT EXISTS company_id TEXT',
          );

          // Label Fonksiyonu
          await _pool!.execute('''
          CREATE OR REPLACE FUNCTION get_professional_label(raw_type TEXT, context TEXT DEFAULT '') RETURNS TEXT AS \$\$
          DECLARE
              t TEXT := LOWER(TRIM(raw_type));
              ctx TEXT := LOWER(TRIM(context));
          BEGIN
              IF raw_type IS NULL OR raw_type = '' THEN
                  RETURN 'İşlem';
              END IF;

              -- KASA
              IF ctx = 'cash' OR ctx = 'kasa' THEN
                  IF t ~ 'tahsilat' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Kasa Tahsilat';
                  ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Kasa Ödeme';
                  END IF;
                  RETURN raw_type;
              END IF;

              -- BANKA
              IF ctx = 'bank' OR ctx = 'banka' THEN
                  IF t ~ 'tahsilat' OR t ~ 'giriş' OR t ~ 'giris' OR t ~ 'havale' OR t ~ 'eft' THEN RETURN 'Banka Tahsilat';
                  ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Banka Ödeme';
                  ELSIF t ~ 'transfer' THEN RETURN 'Banka Transfer';
                  END IF;
                  RETURN raw_type;
              END IF;

              -- KREDİ KARTI / POS
              IF ctx = 'credit_card' OR ctx = 'kredi_karti' OR ctx = 'cc' OR ctx = 'bank_pos' THEN
                  IF t ~ 'tahsilat' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Kredi Kartı Tahsilat';
                  ELSIF t ~ 'harcama' OR t ~ 'çıkış' OR t ~ 'cikis' OR t ~ 'ödeme' OR t ~ 'odeme' THEN RETURN 'Kredi Kartı Harcama';
                  END IF;
                  RETURN raw_type;
              END IF;

              -- ÇEK
              IF ctx = 'check' OR ctx = 'cek' THEN
                  IF t ~ 'ödendi' OR t ~ 'odendi' THEN RETURN 'Çek Ödendi';
                  ELSIF t ~ 'tahsil' THEN RETURN 'Çek Tahsil';
                  ELSIF t ~ 'ciro' THEN RETURN 'Çek Ciro';
                  ELSIF t ~ 'verilen' OR t ~ 'verildi' THEN RETURN 'Çek Verildi';
                  ELSIF t ~ 'alınan' OR t ~ 'alinan' OR t ~ 'alındı' OR t ~ 'alindi' THEN RETURN 'Çek Alındı';
                  ELSIF t ~ 'karşılıksız' OR t ~ 'karsiliksiz' THEN RETURN 'Karşılıksız Çek';
                  ELSIF t = 'giriş' OR t = 'giris' THEN RETURN 'Çek Tahsil';
                  ELSIF t = 'çıkış' OR t = 'cikis' THEN RETURN 'Çek Ödendi';
                  END IF;
                  RETURN raw_type;
              END IF;

              -- SENET
              IF ctx = 'promissory_note' OR ctx = 'senet' THEN
                  IF t ~ 'ödendi' OR t ~ 'odendi' THEN RETURN 'Senet Ödendi';
                  ELSIF t ~ 'tahsil' THEN RETURN 'Senet Tahsil';
                  ELSIF t ~ 'ciro' THEN RETURN 'Senet Ciro';
                  ELSIF t ~ 'verilen' OR t ~ 'verildi' THEN RETURN 'Senet Verildi';
                  ELSIF t ~ 'alınan' OR t ~ 'alinan' OR t ~ 'alındı' OR t ~ 'alindi' THEN RETURN 'Senet Alındı';
                  ELSIF t ~ 'karşılıksız' OR t ~ 'karsiliksiz' THEN RETURN 'Karşılıksız Senet';
                  END IF;
                  RETURN raw_type;
              END IF;

              -- CARİ
              IF ctx = 'current_account' OR ctx = 'cari' THEN
                  IF t = 'borç' OR t = 'borc' THEN RETURN 'Cari Borç';
                  ELSIF t = 'alacak' THEN RETURN 'Cari Alacak';
                  ELSIF t ~ 'tahsilat' OR t ~ 'para alındı' OR t ~ 'para alindi' THEN RETURN 'Para Alındı';
                  ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'para verildi' THEN RETURN 'Para Verildi';
                  ELSIF t ~ 'borç dekontu' OR t ~ 'borc dekontu' THEN RETURN 'Borç Dekontu';
                  ELSIF t ~ 'alacak dekontu' THEN RETURN 'Alacak Dekontu';
                  ELSIF t = 'satış yapıldı' OR t = 'satis yapildi' THEN RETURN 'Satış Yapıldı';
                  ELSIF t = 'alış yapıldı' OR t = 'alis yapildi' THEN RETURN 'Alış Yapıldı';
                  ELSIF t ~ 'satış' OR t ~ 'satis' THEN RETURN 'Satış Faturası';
                  ELSIF t ~ 'alış' OR t ~ 'alis' THEN RETURN 'Alış Faturası';
                  -- ÇEK İŞLEMLERİ (CARİ)
                  ELSIF t ~ 'çek' OR t ~ 'cek' THEN
                      IF t ~ 'tahsil' THEN RETURN 'Çek Alındı (Tahsil Edildi)';
                      ELSIF t ~ 'ödendi' OR t ~ 'odendi' THEN RETURN 'Çek Verildi (Ödendi)';
                      ELSIF t ~ 'ciro' THEN RETURN 'Çek Ciro Edildi';
                      ELSIF t ~ 'karşılıksız' OR t ~ 'karsiliksiz' THEN RETURN 'Karşılıksız Çek';
                      ELSIF t ~ 'verildi' OR t ~ 'verilen' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Çek Verildi';
                      ELSIF t ~ 'alındı' OR t ~ 'alindi' OR t ~ 'alınan' OR t ~ 'alinan' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Çek Alındı';
                      ELSE RETURN 'Çek İşlemi';
                      END IF;
                  -- SENET İŞLEMLERİ (CARİ)
                  ELSIF t ~ 'senet' THEN
                      IF t ~ 'tahsil' THEN RETURN 'Senet Alındı (Tahsil Edildi)';
                      ELSIF t ~ 'ödendi' OR t ~ 'odendi' THEN RETURN 'Senet Verildi (Ödendi)';
                      ELSIF t ~ 'ciro' THEN RETURN 'Senet Ciro Edildi';
                      ELSIF t ~ 'karşılıksız' OR t ~ 'karsiliksiz' THEN RETURN 'Karşılıksız Senet';
                      ELSIF t ~ 'verildi' OR t ~ 'verilen' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Senet Verildi';
                      ELSIF t ~ 'alındı' OR t ~ 'alindi' OR t ~ 'alınan' OR t ~ 'alinan' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Senet Alındı';
                      ELSE RETURN 'Senet İşlemi';
                      END IF;
                  END IF;
                  RETURN raw_type;
              END IF;

              -- STOK
              IF ctx = 'stock' OR ctx = 'stok' THEN
                  IF t ~ 'açılış' OR t ~ 'acilis' THEN RETURN 'Açılış Stoğu';
                  ELSIF t ~ 'devir' AND t ~ 'gir' THEN RETURN 'Devir Giriş';
                  ELSIF t ~ 'devir' AND t ~ 'çık' THEN RETURN 'Devir Çıkış';
                  ELSIF t ~ 'üretim' OR t ~ 'uretim' THEN RETURN 'Üretim';
                  ELSIF t ~ 'satış' OR t ~ 'satis' THEN RETURN 'Satış';
                  ELSIF t ~ 'alış' OR t ~ 'alis' THEN RETURN 'Alış';
                  END IF;
              END IF;

              RETURN raw_type;
          END;
          \$\$ LANGUAGE plpgsql;
        ''');

          await _pool!.execute('''
          -- [2026 FIX] Hyper-Optimized Turkish Normalization for 100B+ Rows
          CREATE OR REPLACE FUNCTION normalize_text(val TEXT) RETURNS TEXT AS \$\$
          BEGIN
              IF val IS NULL THEN RETURN ''; END IF;
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

          // İndeksler
          await PgEklentiler.ensurePgTrgm(_pool!);
          // ParadeDB / BM25 (best-effort; extension yoksa no-op)
          try {
            await PgEklentiler.ensurePgSearch(_pool!);
          } catch (_) {}
          await PgEklentiler.ensureSearchTagsNotNullDefault(_pool!, 'banks');
          await PgEklentiler.ensureSearchTagsNotNullDefault(
            _pool!,
            'bank_transactions',
          );
          await PgEklentiler.ensureSearchTagsFtsIndex(
            _pool!,
            table: 'banks',
            indexName: 'idx_banks_search_tags_fts_gin',
          );
          await PgEklentiler.ensureSearchTagsFtsIndex(
            _pool!,
            table: 'bank_transactions',
            indexName: 'idx_bt_search_tags_fts_gin',
          );
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_banks_search_tags_gin ON banks USING GIN (search_tags gin_trgm_ops)',
          );
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_bt_search_tags_gin ON bank_transactions USING GIN (search_tags gin_trgm_ops)',
          );
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_bt_bank_id ON bank_transactions (bank_id)',
          );
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_bt_date ON bank_transactions (date)',
          );
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_bt_type ON bank_transactions (type)',
          );
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_bt_created_at ON bank_transactions (created_at)',
          );
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_bt_integration_ref ON bank_transactions (integration_ref)',
          );
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_bt_created_at_brin ON bank_transactions USING BRIN (created_at) WITH (pages_per_range = 128)',
          );

          // BM25 indexler (Google-like search fast path)
          try {
            await PgEklentiler.ensureBm25Index(
              _pool!,
              table: 'banks',
              indexName: 'idx_banks_search_tags_bm25',
            );
            await PgEklentiler.ensureBm25Index(
              _pool!,
              table: 'bank_transactions',
              indexName: 'idx_bank_transactions_search_tags_bm25',
            );
          } catch (_) {}

          // Trigger
          await _pool!.execute('''
            -- [2026 GOOGLE-LIKE] Transaction-level search tags (no parent string_agg limits)
	          CREATE OR REPLACE FUNCTION update_bank_search_tags() RETURNS TRIGGER AS \$\$
	          BEGIN
              NEW.search_tags = normalize_text(
                '$_searchTagsVersionPrefix ' ||
                COALESCE(get_professional_label(NEW.type, 'bank'), '') || ' ' ||
                COALESCE(get_professional_label(NEW.type, 'cari'), '') || ' ' ||
                COALESCE(NEW.type, '') || ' ' ||
                COALESCE(TO_CHAR(NEW.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
                COALESCE(NEW.description, '') || ' ' ||
                COALESCE(NEW.location, '') || ' ' ||
                COALESCE(NEW.location_code, '') || ' ' ||
                COALESCE(NEW.location_name, '') || ' ' ||
                COALESCE(NEW.user_name, '') || ' ' ||
                COALESCE(CAST(NEW.amount AS TEXT), '') || ' ' ||
                COALESCE(NEW.integration_ref, '') || ' ' ||
                (CASE 
                  WHEN NEW.integration_ref = 'opening_stock' OR COALESCE(NEW.description, '') ILIKE '%Açılış%' THEN 'açılış stoğu'
                  WHEN COALESCE(NEW.integration_ref, '') LIKE '%production%' OR COALESCE(NEW.description, '') ILIKE '%Üretim%' THEN 'üretim'
                  WHEN COALESCE(NEW.integration_ref, '') LIKE '%transfer%' OR COALESCE(NEW.description, '') ILIKE '%Devir%' THEN 'devir'
                  WHEN COALESCE(NEW.integration_ref, '') LIKE '%shipment%' THEN 'sevkiyat'
                  WHEN COALESCE(NEW.integration_ref, '') LIKE '%collection%' THEN 'tahsilat'
                  WHEN COALESCE(NEW.integration_ref, '') LIKE '%payment%' THEN 'ödeme'
                  WHEN COALESCE(NEW.integration_ref, '') LIKE 'SALE-%' OR COALESCE(NEW.integration_ref, '') LIKE 'RETAIL-%' THEN 'satış yapıldı'
                  WHEN COALESCE(NEW.integration_ref, '') LIKE 'PURCHASE-%' THEN 'alış yapıldı'
                  ELSE ''
                END)
              );
	            RETURN NEW;
	          END;
          \$\$ LANGUAGE plpgsql;
        ''');

          // Ensure trigger matches the new BEFORE INSERT/UPDATE semantics
          await _pool!.execute(
            'DROP TRIGGER IF EXISTS trg_update_bank_search_tags ON bank_transactions',
          );
          await _pool!.execute(
            'CREATE TRIGGER trg_update_bank_search_tags BEFORE INSERT OR UPDATE ON bank_transactions FOR EACH ROW EXECUTE FUNCTION update_bank_search_tags()',
          );
          if (_config.allowBackgroundDbMaintenance &&
              _config.allowBackgroundHeavyMaintenance) {
            try {
              await _backfillBankTransactionSearchTags();
            } catch (e) {
              if (!_isConcurrentTupleUpdateError(e)) rethrow;
            }
            // Initial Indeksleme: Arka planda çalıştır (Sayfa açılışını bloklama)
            try {
              await verileriIndeksle(forceUpdate: false);
            } catch (e) {
              if (!_isConcurrentTupleUpdateError(e)) rethrow;
            }
          }

          await _pool!.execute('''
            CREATE TABLE IF NOT EXISTS bank_metadata (
              type TEXT NOT NULL,
              value TEXT NOT NULL,
              frequency BIGINT DEFAULT 1,
              PRIMARY KEY (type, value)
            )
          ''');
          await _pool!.execute('''
            CREATE OR REPLACE FUNCTION update_bank_metadata() RETURNS TRIGGER AS \$\$
            BEGIN
              IF TG_OP = 'INSERT' THEN
                IF COALESCE(NEW.currency, '') != '' THEN
                  INSERT INTO bank_metadata (type, value, frequency)
                  VALUES ('currency', NEW.currency, 1)
                  ON CONFLICT (type, value)
                  DO UPDATE SET frequency = bank_metadata.frequency + 1;
                END IF;
              ELSIF TG_OP = 'UPDATE' THEN
                IF COALESCE(OLD.currency, '') != COALESCE(NEW.currency, '') THEN
                  IF COALESCE(OLD.currency, '') != '' THEN
                    UPDATE bank_metadata
                    SET frequency = frequency - 1
                    WHERE type = 'currency' AND value = OLD.currency;
                  END IF;
                  IF COALESCE(NEW.currency, '') != '' THEN
                    INSERT INTO bank_metadata (type, value, frequency)
                    VALUES ('currency', NEW.currency, 1)
                    ON CONFLICT (type, value)
                    DO UPDATE SET frequency = bank_metadata.frequency + 1;
                  END IF;
                END IF;
              ELSIF TG_OP = 'DELETE' THEN
                IF COALESCE(OLD.currency, '') != '' THEN
                  UPDATE bank_metadata
                  SET frequency = frequency - 1
                  WHERE type = 'currency' AND value = OLD.currency;
                END IF;
              END IF;

              DELETE FROM bank_metadata WHERE frequency <= 0;
              RETURN NULL;
            END;
            \$\$ LANGUAGE plpgsql;
          ''');
          final bankMetaTriggerExists = await _pool!.execute(
            "SELECT 1 FROM pg_trigger WHERE tgname = 'trg_update_bank_metadata'",
          );
          if (bankMetaTriggerExists.isEmpty) {
            await _pool!.execute('''
              CREATE TRIGGER trg_update_bank_metadata
              AFTER INSERT OR UPDATE OR DELETE ON banks
              FOR EACH ROW EXECUTE FUNCTION update_bank_metadata();
            ''');
          }
        } catch (e) {
          if (e is LisansYazmaEngelliHatasi) return;
          if (_isConcurrentTupleUpdateError(e)) return;
          debugPrint('Banka arka plan ek kurulum hatası: $e');
        }
      }());
    }
  }

  Future<void> _backfillBankTransactionSearchTags({
    int batchSize = 2000,
    int maxBatches = 50,
  }) async {
    if (_pool == null) return;

    for (int i = 0; i < maxBatches; i++) {
      final updated = await _pool!.execute(
        Sql.named('''
          WITH todo AS (
            SELECT id, date
            FROM bank_transactions
            WHERE search_tags IS NULL
              OR search_tags = ''
              OR search_tags NOT LIKE '$_searchTagsVersionPrefix%'
            LIMIT @batchSize
          )
          UPDATE bank_transactions bt
          SET search_tags = normalize_text(
            '$_searchTagsVersionPrefix ' ||
            COALESCE(get_professional_label(bt.type, 'bank'), '') || ' ' ||
            COALESCE(get_professional_label(bt.type, 'cari'), '') || ' ' ||
            COALESCE(bt.type, '') || ' ' ||
            COALESCE(TO_CHAR(bt.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
            COALESCE(bt.description, '') || ' ' ||
            COALESCE(bt.location, '') || ' ' ||
            COALESCE(bt.location_code, '') || ' ' ||
            COALESCE(bt.location_name, '') || ' ' ||
            COALESCE(bt.user_name, '') || ' ' ||
            COALESCE(CAST(bt.amount AS TEXT), '') || ' ' ||
            COALESCE(bt.integration_ref, '') || ' ' ||
            (CASE 
              WHEN bt.integration_ref = 'opening_stock' OR COALESCE(bt.description, '') ILIKE '%Açılış%' THEN 'açılış stoğu'
              WHEN COALESCE(bt.integration_ref, '') LIKE '%production%' OR COALESCE(bt.description, '') ILIKE '%Üretim%' THEN 'üretim'
              WHEN COALESCE(bt.integration_ref, '') LIKE '%transfer%' OR COALESCE(bt.description, '') ILIKE '%Devir%' THEN 'devir'
              WHEN COALESCE(bt.integration_ref, '') LIKE '%shipment%' THEN 'sevkiyat'
              WHEN COALESCE(bt.integration_ref, '') LIKE '%collection%' THEN 'tahsilat'
              WHEN COALESCE(bt.integration_ref, '') LIKE '%payment%' THEN 'ödeme'
              WHEN COALESCE(bt.integration_ref, '') LIKE 'SALE-%' OR COALESCE(bt.integration_ref, '') LIKE 'RETAIL-%' THEN 'satış yapıldı'
              WHEN COALESCE(bt.integration_ref, '') LIKE 'PURCHASE-%' THEN 'alış yapıldı'
              ELSE ''
            END)
          )
          FROM todo
          WHERE bt.id = todo.id AND bt.date = todo.date
          RETURNING 1
        '''),
        parameters: {'batchSize': batchSize},
      );

      if (updated.isEmpty) break;
    }
  }

  bool _isConcurrentTupleUpdateError(Object error) {
    return error.toString().toLowerCase().contains(
      'tuple concurrently updated',
    );
  }

  /// Tüm bankalar için search_tags indekslemesi yapar (Batch Processing)
  Future<void> verileriIndeksle({bool forceUpdate = true}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    try {
      debugPrint('🚀 Banka İndeksleme Başlatılıyor (Batch Modu)...');

      // Batch size
      const int batchSize = 500;
      int processedCount = 0;
      int lastId = 0;

      while (true) {
        final String versionPredicate =
            "(search_tags IS NULL OR search_tags = '' OR search_tags NOT LIKE '$_searchTagsVersionPrefix%')";

        // 1. Get Batch of IDs
        final idRows = await _pool!.execute(
          Sql.named(
            "SELECT id FROM banks WHERE id > @lastId AND COALESCE(company_id, '$_defaultCompanyId') = @companyId ${forceUpdate ? '' : 'AND $versionPredicate'} ORDER BY id ASC LIMIT @batchSize",
          ),
          parameters: {
            'lastId': lastId,
            'batchSize': batchSize,
            'companyId': _companyId,
          },
        );

        if (idRows.isEmpty) break;

        final List<int> ids = idRows.map((row) => row[0] as int).toList();
        lastId = ids.last;

        // 2. Build Where Condition for this batch
        // We use string interpolation for ID list because @ids array support varies
        // But since they are ints, it is safe.
        final String idListStr = ids.join(',');

        final String conditionalWhere = forceUpdate
            ? ""
            : " AND $versionPredicate";

        // 3. Execute Update for this Batch
        await _pool!.execute(
          Sql.named('''
          UPDATE banks b
          SET search_tags = normalize_text(
            '$_searchTagsVersionPrefix ' ||
            COALESCE(b.code, '') || ' ' ||
            COALESCE(b.name, '') || ' ' ||
            COALESCE(b.currency, '') || ' ' ||
            COALESCE(b.branch_code, '') || ' ' ||
            COALESCE(b.branch_name, '') || ' ' ||
            COALESCE(b.account_no, '') || ' ' ||
            COALESCE(b.iban, '') || ' ' ||
            COALESCE(b.info1, '') || ' ' ||
            COALESCE(b.info2, '') || ' ' ||
            CAST(b.id AS TEXT) || ' ' ||
            (CASE WHEN b.is_active = 1 THEN 'aktif' ELSE 'pasif' END)
          )
          WHERE b.id IN ($idListStr) $conditionalWhere
        '''),
        );

        processedCount += ids.length;
        debugPrint('   ...$processedCount banka indekslendi.');

        // Short pause to allow other transactions
        await Future.delayed(const Duration(milliseconds: 10));
      }

      debugPrint(
        '✅ Banka Arama İndeksleri Tamamlandı. Toplam: $processedCount',
      );
    } catch (e) {
      if (e is LisansYazmaEngelliHatasi) return;
      debugPrint('Banka indeksleme sırasında hata: $e');
    }
  }

  Future<void> _updateSearchTags(int bankaId) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('''
        UPDATE banks b
        SET search_tags = normalize_text(
          '$_searchTagsVersionPrefix ' ||
          COALESCE(b.code, '') || ' ' ||
          COALESCE(b.name, '') || ' ' ||
          COALESCE(b.currency, '') || ' ' ||
          COALESCE(b.branch_code, '') || ' ' ||
          COALESCE(b.branch_name, '') || ' ' ||
          COALESCE(b.account_no, '') || ' ' ||
          COALESCE(b.iban, '') || ' ' ||
          COALESCE(b.info1, '') || ' ' ||
          COALESCE(b.info2, '') || ' ' ||
          CAST(b.id AS TEXT) || ' ' ||
          (CASE WHEN b.is_active = 1 THEN 'aktif' ELSE 'pasif' END)
        )
        WHERE b.id = @id
          AND COALESCE(b.company_id, '$_defaultCompanyId') = @companyId
      '''),
      parameters: {'id': bankaId, 'companyId': _companyId},
    );
  }

  Future<List<BankaModel>> bankalariGetir({
    int sayfa = 1,
    int sayfaBasinaKayit = 25,
    String? aramaKelimesi,
    String? siralama,
    bool artanSiralama = true,
    bool? aktifMi,
    bool? varsayilan,
    String? kullanici,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? islemTuru,
    int? bankaId,
    List<int>?
    sadeceIdler, // Harici arama indeksi gibi kaynaklardan gelen ID filtreleri
    int? lastId, // [2026 KEYSET] Cursor pagination
    Session? session,
  }) async {
    if (session == null) {
      if (!_isInitialized) await baslat();
      if (_pool == null) return [];
    }

    final executor = session ?? _pool!;
    final normalizedSearch = aramaKelimesi == null
        ? ''
        : _normalizeTurkish(aramaKelimesi).trim();
    final matchedTransactionBankIds = normalizedSearch.isEmpty
        ? const <int>[]
        : await _eslesenBankaIslemIdleriniGetir(
            executor: executor,
            normalizedSearch: normalizedSearch,
          );

    // Deep Search: SELECT with matched_in_hidden
    String selectClause = 'SELECT b.*';

    if (aramaKelimesi != null && aramaKelimesi.isNotEmpty) {
      selectClause +=
          ''',
        (CASE
          WHEN (
            -- Expanded/detail-only fields
            normalize_text(COALESCE(b.branch_code, '')) LIKE @search OR
            normalize_text(COALESCE(b.branch_name, '')) LIKE @search OR
            normalize_text(COALESCE(b.account_no, '')) LIKE @search OR
            normalize_text(COALESCE(b.iban, '')) LIKE @search OR
            normalize_text(COALESCE(b.info1, '')) LIKE @search OR
            normalize_text(COALESCE(b.info2, '')) LIKE @search OR
            ${_bankaHiddenTxKosulu(alias: 'b', idParam: 'txMatchedBankIds', hasTxMatches: matchedTransactionBankIds.isNotEmpty)}
          ) THEN true
          ELSE false
        END) as matched_in_hidden
      ''';
    } else {
      selectClause += ', false as matched_in_hidden';
    }

    List<String> conditions = [];
    Map<String, dynamic> params = {'companyId': _companyId};

    conditions.add("COALESCE(company_id, '$_defaultCompanyId') = @companyId");

    if (aramaKelimesi != null && aramaKelimesi.isNotEmpty) {
      conditions.add(
        _bankaAramaKosulu(
          alias: 'b',
          idParam: 'txMatchedBankIds',
          hasTxMatches: matchedTransactionBankIds.isNotEmpty,
        ),
      );
      params['search'] = '%$normalizedSearch%';
      if (matchedTransactionBankIds.isNotEmpty) {
        params['txMatchedBankIds'] = matchedTransactionBankIds;
      }
    }

    if (aktifMi != null) {
      conditions.add('is_active = @isActive');
      params['isActive'] = aktifMi ? 1 : 0;
    }

    if (varsayilan != null) {
      conditions.add('is_default = @varsayilan');
      params['varsayilan'] = varsayilan ? 1 : 0;
    }

    if (bankaId != null) {
      conditions.add('id = @bankaId');
      params['bankaId'] = bankaId;
    }

    if (sadeceIdler != null && sadeceIdler.isNotEmpty) {
      conditions.add('b.id = ANY(@idArray)');
      params['idArray'] = sadeceIdler;
    }

    // Kullanıcı Filtresi
    if (kullanici != null && kullanici.isNotEmpty) {
      conditions.add('''
        EXISTS (
          SELECT 1 FROM bank_transactions bt
          WHERE bt.bank_id = b.id
          AND bt.user_name = @kullanici
          AND COALESCE(bt.company_id, '$_defaultCompanyId') = @companyId
        )
      ''');
      params['kullanici'] = kullanici;
    }

    // İşlem Türü Filtresi
    if (islemTuru != null && islemTuru.isNotEmpty) {
      final normalized = islemTuru.trim();
      if (normalized == 'Satış Yapıldı' || normalized == 'Satis Yapildi') {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM bank_transactions bt
            WHERE bt.bank_id = b.id
            AND (bt.integration_ref LIKE 'SALE-%' OR bt.integration_ref LIKE 'RETAIL-%')
            AND COALESCE(bt.company_id, '$_defaultCompanyId') = @companyId
          )
        ''');
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM bank_transactions bt
            WHERE bt.bank_id = b.id
            AND bt.integration_ref LIKE 'PURCHASE-%'
            AND COALESCE(bt.company_id, '$_defaultCompanyId') = @companyId
          )
        ''');
      } else {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM bank_transactions bt
            WHERE bt.bank_id = b.id
            AND bt.type = @islemTuru
            AND COALESCE(bt.company_id, '$_defaultCompanyId') = @companyId
          )
        ''');
        params['islemTuru'] = normalized;
      }
    }

    // Tarih Filtresi
    if (baslangicTarihi != null || bitisTarihi != null) {
      String existsQuery =
          '''
        EXISTS (
          SELECT 1 FROM bank_transactions bt
          WHERE bt.bank_id = b.id
          AND COALESCE(bt.company_id, '$_defaultCompanyId') = @companyId
      ''';

      if (baslangicTarihi != null) {
        existsQuery += " AND bt.date >= @startDate";
        params['startDate'] = DateTime(
          baslangicTarihi.year,
          baslangicTarihi.month,
          baslangicTarihi.day,
        ).toIso8601String();
      }
      if (bitisTarihi != null) {
        existsQuery += " AND bt.date < @endDate";
        params['endDate'] = DateTime(
          bitisTarihi.year,
          bitisTarihi.month,
          bitisTarihi.day,
        ).add(const Duration(days: 1)).toIso8601String();
      }

      existsQuery += ')';
      conditions.add(existsQuery);
    }

    // Sorting (stable for keyset)
    String sortColumn = 'b.id';
    if (siralama != null) {
      switch (siralama) {
        case 'kod':
          sortColumn = 'b.code';
          break;
        case 'ad':
          sortColumn = 'b.name';
          break;
        case 'bakiye':
          sortColumn = 'b.balance';
          break;
        default:
          sortColumn = 'b.id';
      }
    }
    final String direction = artanSiralama ? 'ASC' : 'DESC';

    // [2026 KEYSET] Resolve cursor sort value server-side for stable pagination.
    dynamic lastSortValue;
    if (lastId != null && lastId > 0 && sortColumn != 'b.id') {
      try {
        final cursorRow = await executor.execute(
          Sql.named('''
            SELECT $sortColumn
            FROM banks b
            WHERE b.id = @id
              AND COALESCE(b.company_id, '$_defaultCompanyId') = @companyId
            LIMIT 1
          '''),
          parameters: {'id': lastId, 'companyId': _companyId},
        );
        if (cursorRow.isNotEmpty) {
          lastSortValue = cursorRow.first[0];
        }
      } catch (e) {
        debugPrint('Banka cursor fetch error: $e');
      }
    }

    if (lastId != null && lastId > 0) {
      final String op = artanSiralama ? '>' : '<';
      if (sortColumn == 'b.id') {
        conditions.add('b.id $op @lastId');
        params['lastId'] = lastId;
      } else if (lastSortValue != null) {
        conditions.add(
          '($sortColumn $op @lastSort OR ($sortColumn = @lastSort AND b.id $op @lastId))',
        );
        params['lastSort'] = lastSortValue;
        params['lastId'] = lastId;
      } else {
        // Fallback: id cursor
        conditions.add('b.id $op @lastId');
        params['lastId'] = lastId;
      }
    }

    String query = '$selectClause FROM banks b';
    if (conditions.isNotEmpty) {
      query += ' WHERE ${conditions.join(' AND ')}';
    }

    query += sortColumn == 'b.id'
        ? ' ORDER BY b.id $direction'
        : ' ORDER BY $sortColumn $direction, b.id $direction';

    query += ' LIMIT @limit';
    params['limit'] = sayfaBasinaKayit;

    final result = await executor.execute(Sql.named(query), parameters: params);

    return result.map((row) {
      final map = row.toColumnMap();
      return _mapToBankaModel(map);
    }).toList();
  }

  Future<int> bankaSayisiGetir({
    String? aramaTerimi,
    bool? aktifMi,
    bool? varsayilan,
    String? kullanici,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? islemTuru,
    int? bankaId,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;
    final normalizedSearch = aramaTerimi == null
        ? ''
        : _normalizeTurkish(aramaTerimi).trim();
    final matchedTransactionBankIds = normalizedSearch.isEmpty
        ? const <int>[]
        : await _eslesenBankaIslemIdleriniGetir(
            executor: _pool!,
            normalizedSearch: normalizedSearch,
          );

    // 🚀 10 Milyar Kayıt Optimizasyonu: Filtresiz sorgular için yaklaşık sayım
    if (aramaTerimi == null &&
        aktifMi == null &&
        varsayilan == null &&
        kullanici == null &&
        baslangicTarihi == null &&
        bitisTarihi == null &&
        islemTuru == null &&
        bankaId == null) {
      try {
        final approxResult = await _pool!.execute(
          "SELECT reltuples::BIGINT FROM pg_class WHERE relname = 'banks'",
        );
        if (approxResult.isNotEmpty && approxResult.first[0] != null) {
          final approxCount = approxResult.first[0] as int;
          if (approxCount > 0) {
            return approxCount;
          }
        }
      } catch (e) {
        debugPrint('pg_class sorgusu başarısız, COUNT(*) kullanılıyor: $e');
      }
    }

    List<String> conditions = [];
    Map<String, dynamic> params = {'companyId': _companyId};

    conditions.add("COALESCE(b.company_id, '$_defaultCompanyId') = @companyId");

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      conditions.add(
        _bankaAramaKosulu(
          alias: 'b',
          idParam: 'txMatchedBankIds',
          hasTxMatches: matchedTransactionBankIds.isNotEmpty,
        ),
      );
      params['search'] = '%$normalizedSearch%';
      if (matchedTransactionBankIds.isNotEmpty) {
        params['txMatchedBankIds'] = matchedTransactionBankIds;
      }
    }

    if (aktifMi != null) {
      conditions.add('is_active = @isActive');
      params['isActive'] = aktifMi ? 1 : 0;
    }

    if (varsayilan != null) {
      conditions.add('is_default = @varsayilan');
      params['varsayilan'] = varsayilan ? 1 : 0;
    }

    if (bankaId != null) {
      conditions.add('id = @bankaId');
      params['bankaId'] = bankaId;
    }

    // Kullanıcı Filtresi
    if (kullanici != null && kullanici.isNotEmpty) {
      conditions.add('''
        EXISTS (
          SELECT 1 FROM bank_transactions bt
          WHERE bt.bank_id = b.id
          AND bt.user_name = @kullanici
          AND COALESCE(bt.company_id, '$_defaultCompanyId') = @companyId
        )
      ''');
      params['kullanici'] = kullanici;
    }

    // İşlem Türü Filtresi
    if (islemTuru != null && islemTuru.isNotEmpty) {
      final normalized = islemTuru.trim();
      if (normalized == 'Satış Yapıldı' || normalized == 'Satis Yapildi') {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM bank_transactions bt
            WHERE bt.bank_id = b.id
            AND (bt.integration_ref LIKE 'SALE-%' OR bt.integration_ref LIKE 'RETAIL-%')
            AND COALESCE(bt.company_id, '$_defaultCompanyId') = @companyId
          )
        ''');
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM bank_transactions bt
            WHERE bt.bank_id = b.id
            AND bt.integration_ref LIKE 'PURCHASE-%'
            AND COALESCE(bt.company_id, '$_defaultCompanyId') = @companyId
          )
        ''');
      } else {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM bank_transactions bt
            WHERE bt.bank_id = b.id
            AND bt.type = @islemTuru
            AND COALESCE(bt.company_id, '$_defaultCompanyId') = @companyId
          )
        ''');
        params['islemTuru'] = normalized;
      }
    }

    // Tarih Filtresi
    if (baslangicTarihi != null || bitisTarihi != null) {
      String existsQuery =
          '''
        EXISTS (
          SELECT 1 FROM bank_transactions bt
          WHERE bt.bank_id = b.id
          AND COALESCE(bt.company_id, '$_defaultCompanyId') = @companyId
      ''';

      if (baslangicTarihi != null) {
        existsQuery += " AND bt.date >= @startDate";
        params['startDate'] = DateTime(
          baslangicTarihi.year,
          baslangicTarihi.month,
          baslangicTarihi.day,
        ).toIso8601String();
      }
      if (bitisTarihi != null) {
        existsQuery += " AND bt.date < @endDate";
        params['endDate'] = DateTime(
          bitisTarihi.year,
          bitisTarihi.month,
          bitisTarihi.day,
        ).add(const Duration(days: 1)).toIso8601String();
      }

      existsQuery += ')';
      conditions.add(existsQuery);
    }

    return HizliSayimYardimcisi.tahminiVeyaKesinSayim(
      _pool!,
      fromClause: 'banks b',
      whereConditions: conditions,
      params: params,
      unfilteredTable: 'banks',
    );
  }

  /// [2026 HYPER-SPEED] Dinamik filtre seçeneklerini ve sayıları getirir.
  /// 1 Milyar+ kayıt için optimize edilmiştir, SARGable predicates kullanır.
  Future<Map<String, Map<String, int>>> bankaFiltreIstatistikleriniGetir({
    String? aramaTerimi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    bool? aktifMi,
    bool? varsayilan,
    String? kullanici,
    String? islemTuru,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return {};
    final normalizedSearch = aramaTerimi == null
        ? ''
        : _normalizeTurkish(aramaTerimi).trim();
    final matchedTransactionBankIds = normalizedSearch.isEmpty
        ? const <int>[]
        : await _eslesenBankaIslemIdleriniGetir(
            executor: _pool!,
            normalizedSearch: normalizedSearch,
          );

    Map<String, dynamic> params = {'companyId': _companyId};
    List<String> baseConditions = [];
    baseConditions.add(
      "COALESCE(banks.company_id, '$_defaultCompanyId') = @companyId",
    );

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      baseConditions.add(
        _bankaAramaKosulu(
          alias: 'banks',
          idParam: 'txMatchedBankIds',
          hasTxMatches: matchedTransactionBankIds.isNotEmpty,
        ),
      );
      params['search'] = '%$normalizedSearch%';
      if (matchedTransactionBankIds.isNotEmpty) {
        params['txMatchedBankIds'] = matchedTransactionBankIds;
      }
    }

    // Transaction conditions used across facets (always includes company filter)
    String transactionFilters =
        " AND COALESCE(bt.company_id, '$_defaultCompanyId') = @companyId";
    if (baslangicTarihi != null) {
      transactionFilters += " AND bt.date >= @start";
      params['start'] = DateTime(
        baslangicTarihi.year,
        baslangicTarihi.month,
        baslangicTarihi.day,
      ).toIso8601String();
    }
    if (bitisTarihi != null) {
      transactionFilters += " AND bt.date < @end";
      params['end'] = DateTime(
        bitisTarihi.year,
        bitisTarihi.month,
        bitisTarihi.day,
      ).add(const Duration(days: 1)).toIso8601String();
    }

    if (baslangicTarihi != null || bitisTarihi != null) {
      baseConditions.add('''
        EXISTS (
          SELECT 1 FROM bank_transactions bt 
          WHERE bt.bank_id = banks.id 
          $transactionFilters
        )
      ''');
    }

    String buildQuery(String selectAndGroup, List<String> facetConds) {
      String where = (baseConditions.isNotEmpty || facetConds.isNotEmpty)
          ? 'WHERE ${(baseConditions + facetConds).join(' AND ')}'
          : '';
      return 'SELECT $selectAndGroup FROM (SELECT * FROM banks $where) as sub GROUP BY 1';
    }

    // 1. Durum İstatistikleri
    List<String> durumConds = [];
    if (varsayilan != null) durumConds.add('is_default = @varsayilan');
    if (kullanici != null && kullanici.isNotEmpty) {
      durumConds.add('''
        EXISTS (
          SELECT 1 FROM bank_transactions bt 
          WHERE bt.bank_id = banks.id 
          AND bt.user_name = @kullanici
          $transactionFilters
        )
      ''');
    }
    if (islemTuru != null && islemTuru.isNotEmpty) {
      final normalized = islemTuru.trim();
      if (normalized == 'Satış Yapıldı' || normalized == 'Satis Yapildi') {
        durumConds.add('''
          EXISTS (
            SELECT 1 FROM bank_transactions bt 
            WHERE bt.bank_id = banks.id 
            AND (bt.integration_ref LIKE 'SALE-%' OR bt.integration_ref LIKE 'RETAIL-%')
            $transactionFilters
          )
        ''');
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        durumConds.add('''
          EXISTS (
            SELECT 1 FROM bank_transactions bt 
            WHERE bt.bank_id = banks.id 
            AND bt.integration_ref LIKE 'PURCHASE-%'
            $transactionFilters
          )
        ''');
      } else {
        durumConds.add('''
          EXISTS (
            SELECT 1 FROM bank_transactions bt 
            WHERE bt.bank_id = banks.id 
            AND bt.type = @islemTuru
            $transactionFilters
          )
        ''');
      }
    }
    Map<String, dynamic> durumParams = Map.from(params);
    if (varsayilan != null) durumParams['varsayilan'] = varsayilan ? 1 : 0;
    if (kullanici != null && kullanici.isNotEmpty) {
      durumParams['kullanici'] = kullanici;
    }
    if (islemTuru != null && islemTuru.isNotEmpty) {
      final normalized = islemTuru.trim();
      if (normalized != 'Satış Yapıldı' &&
          normalized != 'Satis Yapildi' &&
          normalized != 'Alış Yapıldı' &&
          normalized != 'Alis Yapildi') {
        durumParams['islemTuru'] = normalized;
      }
    }

    // 2. Varsayılan İstatistikleri
    List<String> defaultConds = [];
    if (aktifMi != null) defaultConds.add('is_active = @isActive');
    if (kullanici != null && kullanici.isNotEmpty) {
      defaultConds.add('''
        EXISTS (
          SELECT 1 FROM bank_transactions bt 
          WHERE bt.bank_id = banks.id 
          AND bt.user_name = @kullanici
          $transactionFilters
        )
      ''');
    }
    if (islemTuru != null && islemTuru.isNotEmpty) {
      final normalized = islemTuru.trim();
      if (normalized == 'Satış Yapıldı' || normalized == 'Satis Yapildi') {
        defaultConds.add('''
          EXISTS (
            SELECT 1 FROM bank_transactions bt 
            WHERE bt.bank_id = banks.id 
            AND (bt.integration_ref LIKE 'SALE-%' OR bt.integration_ref LIKE 'RETAIL-%')
            $transactionFilters
          )
        ''');
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        defaultConds.add('''
          EXISTS (
            SELECT 1 FROM bank_transactions bt 
            WHERE bt.bank_id = banks.id 
            AND bt.integration_ref LIKE 'PURCHASE-%'
            $transactionFilters
          )
        ''');
      } else {
        defaultConds.add('''
          EXISTS (
            SELECT 1 FROM bank_transactions bt 
            WHERE bt.bank_id = banks.id 
            AND bt.type = @islemTuru
            $transactionFilters
          )
        ''');
      }
    }
    Map<String, dynamic> defaultParams = Map.from(params);
    if (aktifMi != null) defaultParams['isActive'] = aktifMi ? 1 : 0;
    if (kullanici != null && kullanici.isNotEmpty) {
      defaultParams['kullanici'] = kullanici;
    }
    if (islemTuru != null && islemTuru.isNotEmpty) {
      final normalized = islemTuru.trim();
      if (normalized != 'Satış Yapıldı' &&
          normalized != 'Satis Yapildi' &&
          normalized != 'Alış Yapıldı' &&
          normalized != 'Alis Yapildi') {
        defaultParams['islemTuru'] = normalized;
      }
    }

    // 3. İşlem Türü İstatistikleri (Dinamik)
    List<String> typeConds = [];
    if (aktifMi != null) typeConds.add('is_active = @isActive');
    if (varsayilan != null) typeConds.add('is_default = @varsayilan');
    if (kullanici != null && kullanici.isNotEmpty) {
      typeConds.add('''
        EXISTS (
          SELECT 1 FROM bank_transactions bt 
          WHERE bt.bank_id = banks.id 
          AND bt.user_name = @kullanici
          $transactionFilters
        )
      ''');
    }
    Map<String, dynamic> typeParams = Map.from(params);
    if (aktifMi != null) typeParams['isActive'] = aktifMi ? 1 : 0;
    if (varsayilan != null) typeParams['varsayilan'] = varsayilan ? 1 : 0;
    if (kullanici != null && kullanici.isNotEmpty) {
      typeParams['kullanici'] = kullanici;
    }

    // 4. Kullanıcı İstatistikleri (Dinamik)
    List<String> userConds = [];
    if (aktifMi != null) userConds.add('is_active = @isActive');
    if (varsayilan != null) userConds.add('is_default = @varsayilan');
    if (islemTuru != null && islemTuru.isNotEmpty) {
      final normalized = islemTuru.trim();
      if (normalized == 'Satış Yapıldı' || normalized == 'Satis Yapildi') {
        userConds.add('''
          EXISTS (
            SELECT 1 FROM bank_transactions bt 
            WHERE bt.bank_id = banks.id 
            AND (bt.integration_ref LIKE 'SALE-%' OR bt.integration_ref LIKE 'RETAIL-%')
            $transactionFilters
          )
        ''');
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        userConds.add('''
          EXISTS (
            SELECT 1 FROM bank_transactions bt 
            WHERE bt.bank_id = banks.id 
            AND bt.integration_ref LIKE 'PURCHASE-%'
            $transactionFilters
          )
        ''');
      } else {
        userConds.add('''
          EXISTS (
            SELECT 1 FROM bank_transactions bt 
            WHERE bt.bank_id = banks.id 
            AND bt.type = @islemTuru
            $transactionFilters
          )
        ''');
      }
    }
    Map<String, dynamic> userParams = Map.from(params);
    if (aktifMi != null) userParams['isActive'] = aktifMi ? 1 : 0;
    if (varsayilan != null) userParams['varsayilan'] = varsayilan ? 1 : 0;
    if (islemTuru != null && islemTuru.isNotEmpty) {
      final normalized = islemTuru.trim();
      if (normalized != 'Satış Yapıldı' &&
          normalized != 'Satis Yapildi' &&
          normalized != 'Alış Yapıldı' &&
          normalized != 'Alis Yapildi') {
        userParams['islemTuru'] = normalized;
      }
    }

    final results = await Future.wait([
      // Toplam
      _pool!.execute(
        Sql.named(
          'SELECT COUNT(*) FROM banks ${baseConditions.isNotEmpty ? 'WHERE ${baseConditions.join(' AND ')}' : ''}',
        ),
        parameters: params,
      ),
      // Durumlar
      _pool!.execute(
        Sql.named(buildQuery('is_active, COUNT(*)', durumConds)),
        parameters: durumParams,
      ),
      // Varsayılanlar
      _pool!.execute(
        Sql.named(buildQuery('is_default, COUNT(*)', defaultConds)),
        parameters: defaultParams,
      ),
      // İşlem Türleri
      _pool!.execute(
        Sql.named('''
          SELECT 
            CASE
              WHEN bt.integration_ref LIKE 'SALE-%' OR bt.integration_ref LIKE 'RETAIL-%' THEN 'Satış Yapıldı'
              WHEN bt.integration_ref LIKE 'PURCHASE-%' THEN 'Alış Yapıldı'
              ELSE bt.type
            END AS type_key,
            COUNT(DISTINCT banks.id)
          FROM banks
          JOIN bank_transactions bt ON bt.bank_id = banks.id
          WHERE ${(baseConditions + typeConds).join(' AND ')}
          $transactionFilters
          GROUP BY type_key
        '''),
        parameters: typeParams,
      ),
      // Kullanıcılar
      _pool!.execute(
        Sql.named('''
          SELECT bt.user_name, COUNT(DISTINCT banks.id)
          FROM banks
          JOIN bank_transactions bt ON bt.bank_id = banks.id
          WHERE ${(baseConditions + userConds).join(' AND ')}
          $transactionFilters
          GROUP BY bt.user_name
        '''),
        parameters: userParams,
      ),
    ]);

    Map<String, Map<String, int>> stats = {
      'ozet': {'toplam': results[0][0][0] as int},
      'durumlar': {},
      'varsayilanlar': {},
      'islem_turleri': {},
      'kullanicilar': {},
    };

    for (final row in results[1]) {
      final key = (row[0] as int) == 1 ? 'active' : 'passive';
      stats['durumlar']![key] = row[1] as int;
    }

    for (final row in results[2]) {
      final key = (row[0] as int) == 1 ? 'default' : 'regular';
      stats['varsayilanlar']![key] = row[1] as int;
    }

    for (final row in results[3]) {
      if (row[0] != null) {
        stats['islem_turleri']![row[0] as String] = row[1] as int;
      }
    }

    for (final row in results[4]) {
      if (row[0] != null) {
        stats['kullanicilar']![row[0] as String] = row[1] as int;
      }
    }

    return stats;
  }

  Future<List<Map<String, dynamic>>> sonIslemleriGetir({
    int limit = 50,
    DateTime? lastCreatedAt,
    int? lastId,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    final params = <String, dynamic>{'companyId': _companyId};
    String keyset = '';
    if (lastCreatedAt != null && lastId != null && lastId > 0) {
      keyset = '''
        AND (
          t.created_at < @lastCreatedAt
          OR (t.created_at = @lastCreatedAt AND t.id < @lastId)
        )
      ''';
      params['lastCreatedAt'] = lastCreatedAt.toIso8601String();
      params['lastId'] = lastId;
    }
    params['limit'] = limit.clamp(1, 5000);

    final result = await _pool!.execute(
      Sql.named('''
        SELECT t.*, b.code as banka_kodu, b.name as banka_adi, b.currency as para_birimi
        FROM bank_transactions t
        LEFT JOIN banks b ON t.bank_id = b.id
        WHERE COALESCE(t.company_id, '$_defaultCompanyId') = @companyId
        $keyset
        ORDER BY t.created_at DESC, t.id DESC
        LIMIT @limit
        '''),
      parameters: params,
    );

    return result.map((row) {
      final map = row.toColumnMap();
      return _mapToTransaction(map);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> bankaIslemleriniGetir(
    int bankaId, {
    String? aramaTerimi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? islemTuru,
    String? kullanici,
    int limit = 50,
    int? lastId,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    // [2025 HYBRID PAGINATION] Keyser cursor for 10B rows
    String query =
        "SELECT t.*, b.code as banka_kodu, b.name as banka_adi, b.currency as para_birimi FROM bank_transactions t LEFT JOIN banks b ON t.bank_id = b.id WHERE t.bank_id = @bankaId AND COALESCE(t.company_id, '$_defaultCompanyId') = @companyId";
    Map<String, dynamic> params = {'bankaId': bankaId, 'companyId': _companyId};

    // Keyset Pagination Filter
    if (lastId != null) {
      query += ' AND t.id < @lastId';
      params['lastId'] = lastId;
    }

    final trimmedSearch = aramaTerimi?.trim() ?? '';
    if (trimmedSearch.isNotEmpty) {
      final parts = _normalizeTurkish(
        trimmedSearch,
      ).split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(8).toList();

      for (int i = 0; i < parts.length; i++) {
        query += ' AND t.search_tags LIKE @search$i';
        params['search$i'] = '%${parts[i]}%';
      }
    }

    if (islemTuru != null && islemTuru.isNotEmpty) {
      final normalized = islemTuru.trim();
      if (normalized == 'Satış Yapıldı' || normalized == 'Satis Yapildi') {
        query +=
            " AND (t.integration_ref LIKE 'SALE-%' OR t.integration_ref LIKE 'RETAIL-%')";
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        query += " AND t.integration_ref LIKE 'PURCHASE-%'";
      } else {
        query += ' AND t.type = @islemTuru';
        params['islemTuru'] = normalized;
      }
    }

    if (kullanici != null && kullanici.isNotEmpty) {
      query += ' AND t.user_name = @kullanici';
      params['kullanici'] = kullanici;
    }

    if (baslangicTarihi != null) {
      query += ' AND t.date >= @startDate';
      params['startDate'] = DateTime(
        baslangicTarihi.year,
        baslangicTarihi.month,
        baslangicTarihi.day,
      ).toIso8601String();
    }

    if (bitisTarihi != null) {
      query += ' AND t.date < @endDate';
      params['endDate'] = DateTime(
        bitisTarihi.year,
        bitisTarihi.month,
        bitisTarihi.day,
      ).add(const Duration(days: 1)).toIso8601String();
    }

    // Always order by ID DESC for consistent keyset pagination (Newest first)
    query += ' ORDER BY t.id DESC LIMIT @limit';
    params['limit'] = limit;

    final result = await _pool!.execute(Sql.named(query), parameters: params);

    return result.map((row) {
      final map = row.toColumnMap();
      return _mapToTransaction(map);
    }).toList();
  }

  Future<List<String>> getMevcutIslemTurleri() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    final result = await _pool!.execute(
      Sql.named(
        "SELECT DISTINCT type FROM bank_transactions WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId ORDER BY type ASC",
      ),
      parameters: {'companyId': _companyId},
    );

    return result.map((r) => r[0] as String).toList();
  }

  Future<List<BankaModel>> tumBankalariGetir() async {
    return bankalariGetir(sayfaBasinaKayit: 1000);
  }

  Future<void> bankaEkle(BankaModel banka) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isBankCreditActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde banka işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final result = await _pool!.execute(
      Sql.named('''
        INSERT INTO banks (company_id, code, name, balance, currency, branch_code, branch_name, account_no, iban, info1, info2, is_active, is_default, search_tags, matched_in_hidden)
        VALUES (@companyId, @code, @name, @balance, @currency, @branch_code, @branch_name, @account_no, @iban, @info1, @info2, @is_active, @is_default, @search_tags, @matched_in_hidden)
        RETURNING id
      '''),
      parameters: {
        'companyId': _companyId,
        'code': banka.kod,
        'name': banka.ad,
        'balance': banka.bakiye,
        'currency': banka.paraBirimi,
        'branch_code': banka.subeKodu,
        'branch_name': banka.subeAdi,
        'account_no': banka.hesapNo,
        'iban': banka.iban,
        'info1': banka.bilgi1,
        'info2': banka.bilgi2,
        'is_active': banka.aktifMi ? 1 : 0,
        'is_default': banka.varsayilan ? 1 : 0,
        'search_tags': banka.searchTags ?? '',
        'matched_in_hidden': banka.matchedInHidden ? 1 : 0,
      },
    );

    if (result.isNotEmpty) {
      final newId = result.first[0] as int;
      if (banka.varsayilan) {
        await bankaVarsayilanDegistir(newId, true);
      }
      await _updateSearchTags(newId);
    }
  }

  Future<void> bankaGuncelle(BankaModel banka) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isBankCreditActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde banka işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('''
        UPDATE banks 
        SET code=@code, name=@name, balance=@balance, currency=@currency, branch_code=@branch_code, branch_name=@branch_name,
            account_no=@account_no, iban=@iban, info1=@info1, info2=@info2, is_active=@is_active, is_default=@is_default, 
            search_tags=@search_tags, matched_in_hidden=@matched_in_hidden
        WHERE id=@id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
      '''),
      parameters: {
        'id': banka.id,
        'companyId': _companyId,
        'code': banka.kod,
        'name': banka.ad,
        'balance': banka.bakiye,
        'currency': banka.paraBirimi,
        'branch_code': banka.subeKodu,
        'branch_name': banka.subeAdi,
        'account_no': banka.hesapNo,
        'iban': banka.iban,
        'info1': banka.bilgi1,
        'info2': banka.bilgi2,
        'is_active': banka.aktifMi ? 1 : 0,
        'is_default': banka.varsayilan ? 1 : 0,
        'search_tags': banka.searchTags ?? '',
        'matched_in_hidden': banka.matchedInHidden ? 1 : 0,
      },
    );

    await _updateSearchTags(banka.id);
    if (banka.varsayilan) {
      await bankaVarsayilanDegistir(banka.id, true);
    }
  }

  Future<void> bankaVarsayilanDegistir(int id, bool varsayilan) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isBankCreditActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde banka işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      if (varsayilan) {
        // Eğer bu banka varsayılan yapılıyorsa, diğerlerinin varsayılan özelliğini kaldır
        await session.execute(
          Sql.named(
            "UPDATE banks SET is_default = 0 WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId",
          ),
          parameters: {'companyId': _companyId},
        );
      }
      await session.execute(
        Sql.named(
          "UPDATE banks SET is_default = @val WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {
          'val': varsayilan ? 1 : 0,
          'id': id,
          'companyId': _companyId,
        },
      );
    });
  }

  Future<void> bankaSil(int id, {TxSession? session}) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isBankCreditActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde banka işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    Future<void> operation(TxSession s) async {
      await s.execute(
        Sql.named(
          "DELETE FROM banks WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );
      await s.execute(
        Sql.named(
          "DELETE FROM bank_transactions WHERE bank_id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );
    }

    if (session != null) {
      await operation(session);
    } else {
      await _pool!.runTx((s) => operation(s));
    }
  }

  Future<void> kayitlariTemizle() async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isBankCreditActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde banka işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      await session.execute(
        Sql.named(
          "DELETE FROM banks WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'companyId': _companyId},
      );
      await session.execute(
        Sql.named(
          "DELETE FROM bank_transactions WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'companyId': _companyId},
      );
    });
  }

  Future<String> siradakiBankaKodunuGetir({bool alfanumerik = true}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return alfanumerik ? 'BK-001' : '1';

    if (!alfanumerik) {
      final result = await _pool!.execute(
        Sql.named('''
          SELECT COALESCE(MAX(CAST(code AS BIGINT)), 0) 
	          FROM banks
	          WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId
	            AND code ~ '^[0-9]+\$'
	        '''),
        parameters: {'companyId': _companyId},
      );

      final maxCode = int.tryParse(result.first[0]?.toString() ?? '0') ?? 0;
      return (maxCode + 1).toString();
    }

    final result = await _pool!.execute(
      Sql.named('''
	        SELECT COALESCE(MAX(CAST(SUBSTRING(code FROM '[0-9]+\$') AS BIGINT)), 0) 
	        FROM banks
	        WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId
	          AND code ~ '^BK-[0-9]+\$'
	      '''),
      parameters: {'companyId': _companyId},
    );

    final maxSuffix = int.tryParse(result.first[0]?.toString() ?? '0') ?? 0;
    final nextId = maxSuffix + 1;
    return 'BK-${nextId.toString().padLeft(3, '0')}';
  }

  Future<bool> bankaKoduVarMi(String kod, {int? haricId}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    String query =
        "SELECT COUNT(*) FROM banks WHERE code = @code AND COALESCE(company_id, '$_defaultCompanyId') = @companyId";
    Map<String, dynamic> params = {'code': kod, 'companyId': _companyId};

    if (haricId != null) {
      query += ' AND id != @haricId';
      params['haricId'] = haricId;
    }

    final result = await _pool!.execute(Sql.named(query), parameters: params);

    return (result[0][0] as int) > 0;
  }

  Future<List<BankaModel>> bankaAra(
    String query, {
    int limit = 100,
    Session? session,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    if (session == null) {
      if (!_isInitialized) await baslat();
      if (_pool == null) return [];
    }

    final executor = session ?? _pool!;

    // Hızlı yol: kod birebir eşleşiyorsa deep-search'e girmeden sonuç döndür.
    try {
      final byCode = await executor.execute(
        Sql.named('''
          SELECT *
          FROM banks
          WHERE code = @code
            AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
          ORDER BY id ASC
          LIMIT @limit
        '''),
        parameters: {'code': q, 'companyId': _companyId, 'limit': limit},
      );
      if (byCode.isNotEmpty) {
        return byCode
            .map((row) => _mapToBankaModel(row.toColumnMap()))
            .toList();
      }
    } catch (_) {}

    return bankalariGetir(
      aramaKelimesi: q,
      sayfaBasinaKayit: limit,
      session: session,
    );
  }

  // Helpers
  BankaModel _mapToBankaModel(Map<String, dynamic> map) {
    // matched_in_hidden: PostgreSQL boolean veya int olarak gelebilir
    bool matchedInHidden = false;
    final mihValue = map['matched_in_hidden'];
    if (mihValue is bool) {
      matchedInHidden = mihValue;
    } else if (mihValue is int) {
      matchedInHidden = mihValue == 1;
    } else if (mihValue == true) {
      matchedInHidden = true;
    }

    return BankaModel(
      id: map['id'] as int,
      kod: map['code'] as String? ?? '',
      ad: map['name'] as String? ?? '',
      bakiye: double.tryParse(map['balance']?.toString() ?? '') ?? 0.0,
      paraBirimi: map['currency'] as String? ?? 'TRY',
      subeKodu: map['branch_code'] as String? ?? '',
      subeAdi: map['branch_name'] as String? ?? '',
      hesapNo: map['account_no'] as String? ?? '',
      iban: map['iban'] as String? ?? '',
      bilgi1: map['info1'] as String? ?? '',
      bilgi2: map['info2'] as String? ?? '',
      aktifMi: (map['is_active'] as int?) == 1,
      varsayilan: (map['is_default'] as int?) == 1,
      searchTags: map['search_tags'] as String?,
      matchedInHidden: matchedInHidden,
    );
  }

  Map<String, dynamic> _mapToTransaction(Map<String, dynamic> map) {
    return {
      'id': map['id'],
      'bankaKodu': map['banka_kodu'] ?? '',
      'bankaAdi': map['banka_adi'] ?? '',
      'islem': map['type'] ?? '',
      'tarih': map['date'] ?? '',
      'yer': map['location'] ?? '',
      'yerKodu': map['location_code'] ?? '',
      'yerAdi': map['location_name'] ?? '',
      'aciklama': map['description'] ?? '',
      'kullanici': map['user_name'] ?? '',
      'tutar': double.tryParse(map['amount']?.toString() ?? '') ?? 0.0,
      'paraBirimi': map['para_birimi'] ?? 'TRY',
      'isIncoming': map['type'] == 'Tahsilat',
      'integration_ref': map['integration_ref'],
    };
  }

  bool _isPartitionError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('23514') ||
        msg.contains('partition') ||
        msg.contains('no partition') ||
        msg.contains('failing row contains');
  }

  /// Ensures that a partition exists for the given year.
  Future<void> _createBankPartitions(DateTime date, {Session? session}) async {
    if (_pool == null && session == null) return;
    final executor = session ?? _pool!;

    final int year = date.year;
    final int month = date.month;
    final String monthStr = month.toString().padLeft(2, '0');
    final partitionName = 'bank_transactions_y${year}_m$monthStr';
    final legacyYearTable = 'bank_transactions_$year';
    final defaultTable = 'bank_transactions_default';

    bool isOverlapError(Object e) {
      if (e is ServerException && e.code == '42P17') return true;
      final msg = e.toString().toLowerCase();
      return msg.contains('42p17') ||
          (msg.contains('overlap') && msg.contains('partition'));
    }

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
      return parent == 'bank_transactions';
    }

    // 1. DEFAULT Partition
    if (!await isAttached(defaultTable)) {
      if (await isTableExists(defaultTable)) {
        final currentParent = await getParentTable(defaultTable);
        debugPrint(
          '🛠️ Banka default partition table $defaultTable detached or attached to $currentParent. Fixing...',
        );
        try {
          if (currentParent != null && currentParent != 'bank_transactions') {
            await executor.execute(
              'ALTER TABLE $currentParent DETACH PARTITION $defaultTable',
            );
          }
          await executor.execute(
            'ALTER TABLE bank_transactions ATTACH PARTITION $defaultTable DEFAULT',
          );
        } catch (_) {
          await executor.execute('DROP TABLE IF EXISTS $defaultTable CASCADE');
          await executor.execute(
            'CREATE TABLE $defaultTable PARTITION OF bank_transactions DEFAULT',
          );
        }
      } else {
        await executor.execute(
          'CREATE TABLE IF NOT EXISTS $defaultTable PARTITION OF bank_transactions DEFAULT',
        );
      }
    }

    // Legacy yıllık partition varsa aylık partition oluşturmaya çalışma (42P17 overlap).
    if (await isAttached(legacyYearTable)) return;

    // 2. Aylık Partition
    if (!await isAttached(partitionName)) {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      final startStr =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-01';
      final endStr =
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-01';

      if (await isTableExists(partitionName)) {
        final currentParent = await getParentTable(partitionName);
        debugPrint(
          '🛠️ Banka partition table $partitionName detached or attached to $currentParent. Attaching...',
        );
        try {
          if (currentParent != null && currentParent != 'bank_transactions') {
            await executor.execute(
              'ALTER TABLE $currentParent DETACH PARTITION $partitionName',
            );
          }
          await executor.execute(
            "ALTER TABLE bank_transactions ATTACH PARTITION $partitionName FOR VALUES FROM ('$startStr') TO ('$endStr')",
          );
        } catch (e) {
          if (isOverlapError(e)) return;
          debugPrint(
            '⚠️ Banka attach failed ($partitionName): $e. Recreating...',
          );
          await executor.execute('DROP TABLE IF EXISTS $partitionName CASCADE');
          await executor.execute(
            "CREATE TABLE $partitionName PARTITION OF bank_transactions FOR VALUES FROM ('$startStr') TO ('$endStr')",
          );
        }
      } else {
        try {
          await executor.execute(
            "CREATE TABLE IF NOT EXISTS $partitionName PARTITION OF bank_transactions FOR VALUES FROM ('$startStr') TO ('$endStr')",
          );
        } catch (e) {
          if (isOverlapError(e)) return;
          if (!e.toString().contains('already exists')) rethrow;
        }
      }
    }
  }

  Future<void> _ensureBankPartitionsForRange(
    DateTime start,
    DateTime end, {
    Session? session,
  }) async {
    if (_pool == null && session == null) return;

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
      await _createBankPartitions(cursor, session: session);
      if (cursor.year == endMonth.year && cursor.month == endMonth.month) break;
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
  }

  Future<void> _backfillBankTransactionsDefault({Session? session}) async {
    if (_pool == null && session == null) return;
    final executor = session ?? _pool!;

    // DEFAULT partition'tan taşıma için önce aralığı öğren ve partitionları hazırla.
    final range = await executor.execute('''
      SELECT MIN(date), MAX(date)
      FROM bank_transactions_default
      WHERE date IS NOT NULL
    ''');
    if (range.isEmpty) return;
    final minDt = range.first[0] as DateTime?;
    final maxDt = range.first[1] as DateTime?;
    if (minDt == null || maxDt == null) return;

    await _ensureBankPartitionsForRange(minDt, maxDt, session: executor);

    await PgEklentiler.moveRowsFromDefaultPartition(
      executor: executor,
      parentTable: 'bank_transactions',
      defaultTable: 'bank_transactions_default',
      partitionKeyColumn: 'date',
    );
  }

  Future<int> bankaIslemEkle({
    required int bankaId,
    required double tutar,
    required String islemTuru, // 'Tahsilat', 'Ödeme'
    required String aciklama,
    required DateTime tarih,
    required String cariTuru, // 'Cari Hesap', 'Kasa' vb.
    required String cariKodu,
    required String cariAdi,
    required String kullanici,
    bool cariEntegrasyonYap = true,
    String? entegrasyonRef,
    String? locationType, // bank, credit_card, cash, personnel, current_account
    TxSession? session,
  }) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isBankCreditActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde banka işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (session == null) {
      if (!_isInitialized) await baslat();
      if (_pool == null) return -1;
    }

    int yeniIslemId = -1;

    // Eğer entegrasyon yapılacaksa ve ref yoksa oluştur
    String? finalRef = entegrasyonRef;
    if (cariEntegrasyonYap &&
        finalRef == null &&
        locationType != null &&
        ['bank', 'cash', 'credit_card', 'personnel'].contains(locationType)) {
      finalRef = 'AUTO-TR-${DateTime.now().microsecondsSinceEpoch}';
    }

    // [FIX] Pre-fetch needed data
    BankaModel? currentBanka;
    BankaModel? targetBanka;

    if (cariEntegrasyonYap) {
      // ALWAYS pre-fetch current asset if integrating with Cari
      final bankalar = await bankalariGetir(bankaId: bankaId, session: session);
      currentBanka = bankalar.firstOrNull;
      if (locationType == 'bank' && cariKodu.isNotEmpty) {
        final hedefBankalar = await bankaAra(
          cariKodu,
          limit: 1,
          session: session,
        );
        if (hedefBankalar.isNotEmpty) {
          targetBanka = hedefBankalar.first;
        }
      }
    }

    // Transaction Logic Wrap
    Future<void> operation(TxSession s) async {
      // [2026] Aylık partition garanti: DEFAULT'a düşmemesi için önce ilgili ayı hazırla.
      // DDL yetkisi yoksa sessizce geç: insert DEFAULT partition'a gider ve sistem çalışır.
      try {
        await _createBankPartitions(tarih, session: s);
      } catch (_) {}

      // 0. VALIDATION: Eksi Bakiye Kontrolü (Ayarlara Bağlı)
      if (islemTuru != 'Tahsilat') {
        try {
          // Session'ı ÇIKAR, çünkü ayarlar farklı veritabanında (patisyosettings)
          final genelAyarlar = await AyarlarVeritabaniServisi()
              .genelAyarlariGetir();
          if (genelAyarlar.eksiBakiyeKontrol) {
            // Güncel bakiyeyi KİLİTLEYEREK getir (FOR UPDATE)
            final bakiyeResult = await s.execute(
              Sql.named(
                "SELECT balance FROM banks WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId FOR UPDATE",
              ),
              parameters: {'id': bankaId, 'companyId': _companyId},
            );

            if (bakiyeResult.isNotEmpty) {
              final double mevcutBakiye =
                  double.tryParse(bakiyeResult.first[0]?.toString() ?? '') ??
                  0.0;
              if (mevcutBakiye < tutar) {
                throw Exception(
                  'Yetersiz bakiye! Banka bakiyesi: $mevcutBakiye, İşlem tutarı: $tutar. '
                  'Bu işlem banka hesabını eksi bakiyeye düşürecektir.',
                );
              }
            }
          }
        } catch (e) {
          if (e.toString().contains('Yetersiz bakiye')) rethrow;
          debugPrint(
            'Genel ayarlar okunamadı, eksi bakiye kontrolü atlanıyor: $e',
          );
        }
      }

      // 1. İşlemi kaydet (JIT Partitioning ile)
      Result insertResult;
      await s.execute('SAVEPOINT sp_bank_insert');

      try {
        insertResult = await s.execute(
          Sql.named('''
            INSERT INTO bank_transactions 
            (company_id, bank_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref)
            VALUES 
            (@companyId, @bankaId, @date, @description, @amount, @type, @location, @location_code, @location_name, @user_name, @integration_ref)
            RETURNING id
          '''),
          parameters: {
            'companyId': _companyId,
            'bankaId': bankaId,
            'date': tarih,
            'description': aciklama,
            'amount': tutar,
            'type': islemTuru,
            'location': cariTuru,
            'location_code': cariKodu,
            'location_name': cariAdi,
            'user_name': kullanici,
            'integration_ref': finalRef,
          },
        );
        await s.execute('RELEASE SAVEPOINT sp_bank_insert');
      } catch (e) {
        await s.execute('ROLLBACK TO SAVEPOINT sp_bank_insert');

        final String errorStr = e.toString();
        final bool isMissingTable =
            errorStr.contains('42P01') ||
            errorStr.toLowerCase().contains('does not exist');

        if (isMissingTable || _isPartitionError(e)) {
          debugPrint(
            '⚠️ Banka Tablo/Partition hatası (Self-Healing)... Ay: ${tarih.year}-${tarih.month.toString().padLeft(2, '0')}',
          );

          if (isMissingTable) {
            debugPrint('🚨 Banka tablosu eksik! Yeniden oluşturuluyor...');
            await _tablolariOlustur(); // Ana tabloyu ve partitionları tamir et
          } else {
            await _createBankPartitions(tarih, session: s);
          }

          // Retry
          await s.execute('SAVEPOINT sp_bank_retry');
          try {
            insertResult = await s.execute(
              Sql.named('''
                INSERT INTO bank_transactions 
                (company_id, bank_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref)
                VALUES 
                (@companyId, @bankaId, @date, @description, @amount, @type, @location, @location_code, @location_name, @user_name, @integration_ref)
                RETURNING id
              '''),
              parameters: {
                'companyId': _companyId,
                'bankaId': bankaId,
                'date': tarih,
                'description': aciklama,
                'amount': tutar,
                'type': islemTuru,
                'location': cariTuru,
                'location_code': cariKodu,
                'location_name': cariAdi,
                'user_name': kullanici,
                'integration_ref': finalRef,
              },
            );
            await s.execute('RELEASE SAVEPOINT sp_bank_retry');
          } catch (retryE) {
            await s.execute('ROLLBACK TO SAVEPOINT sp_bank_retry');
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      final int bankaIslemId = (insertResult.first[0] as int?) ?? 0;
      yeniIslemId = bankaIslemId;

      // 2. Banka bakiyesini güncelle
      String updateQuery =
          'UPDATE banks SET balance = balance + @amount WHERE id = @id';
      if (islemTuru != 'Tahsilat') {
        updateQuery =
            'UPDATE banks SET balance = balance - @amount WHERE id = @id';
      }

      await s.execute(
        Sql.named(updateQuery),
        parameters: {'amount': tutar, 'id': bankaId},
      );

      // --- OTOMATİK ENTEGRASYONLAR ---
      if (cariEntegrasyonYap) {
        // A. Cari Hesap Entegrasyonu
        if ((locationType == 'current_account' || locationType == null) &&
            cariKodu.isNotEmpty) {
          final cariServis = CariHesaplarVeritabaniServisi();
          final int? cariId = await cariServis.cariIdGetir(
            cariKodu,
            session: s,
          );

          if (cariId != null) {
            bool isBorc = islemTuru != 'Tahsilat';
            await cariServis.cariIslemEkle(
              cariId: cariId,
              tutar: tutar,
              isBorc: isBorc,
              islemTuru: 'Banka',
              aciklama: aciklama,
              tarih: tarih,
              kullanici: kullanici,
              kaynakId: yeniIslemId,
              kaynakAdi: currentBanka?.ad ?? 'Banka',
              kaynakKodu: currentBanka?.kod ?? '',
              entegrasyonRef: finalRef, // Referans buraya eklendi
              session: s,
            );
          }
        }
        // B. Kasa Entegrasyonu
        else if (locationType == 'cash') {
          final kasaServis = KasalarVeritabaniServisi();
          final kasalar = await kasaServis.kasaAra(
            cariKodu,
            limit: 1,
            session: s,
          );
          if (kasalar.isNotEmpty) {
            String karsiIslemTuru = islemTuru == 'Tahsilat'
                ? 'Ödeme'
                : 'Tahsilat';
            await kasaServis.kasaIslemEkle(
              kasaId: kasalar.first.id,
              tutar: tutar,
              islemTuru: karsiIslemTuru,
              aciklama: aciklama,
              tarih: tarih,
              cariTuru: 'Banka',
              cariKodu: currentBanka?.kod ?? '',
              cariAdi: currentBanka?.ad ?? '',
              kullanici: kullanici,
              cariEntegrasyonYap: false,
              entegrasyonRef: finalRef,
              session: s,
            );
          }
        }
        // C. Kredi Kartı Entegrasyonu
        else if (locationType == 'credit_card') {
          final kartServis = KrediKartlariVeritabaniServisi();
          final kartlar = await kartServis.krediKartiAra(
            cariKodu,
            limit: 1,
            session: s,
          );
          if (kartlar.isNotEmpty) {
            String karsiIslemTuru = islemTuru == 'Tahsilat' ? 'Çıkış' : 'Giriş';
            await kartServis.krediKartiIslemEkle(
              krediKartiId: kartlar.first.id,
              tutar: tutar,
              islemTuru: karsiIslemTuru,
              aciklama: aciklama,
              tarih: tarih,
              cariTuru: 'Banka',
              cariKodu: currentBanka?.kod ?? '',
              cariAdi: currentBanka?.ad ?? '',
              kullanici: kullanici,
              cariEntegrasyonYap: false,
              entegrasyonRef: finalRef,
              session: s,
            );
          }
        }
        // D. Banka Transferi (Virman)
        else if (locationType == 'bank') {
          if (targetBanka != null) {
            String karsiIslemTuru = islemTuru == 'Tahsilat'
                ? 'Ödeme'
                : 'Tahsilat';
            await s.execute(
              Sql.named('''
                INSERT INTO bank_transactions 
                (company_id, bank_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref)
                VALUES 
                (@companyId, @bankaId, @date, @description, @amount, @type, @location, @location_code, @location_name, @user_name, @integration_ref)
              '''),
              parameters: {
                'companyId': _companyId,
                'bankaId': targetBanka.id,
                'date': DateFormat('yyyy-MM-dd HH:mm').format(tarih),
                'description': aciklama,
                'amount': tutar,
                'type': karsiIslemTuru,
                'location': 'Banka',
                'location_code': currentBanka?.kod ?? '',
                'location_name': currentBanka?.ad ?? '',
                'user_name': kullanici,
                'integration_ref': finalRef,
              },
            );

            String targetUpdateQuery =
                'UPDATE banks SET balance = balance + @amount WHERE id = @id';
            if (karsiIslemTuru != 'Tahsilat') {
              targetUpdateQuery =
                  'UPDATE banks SET balance = balance - @amount WHERE id = @id';
            }
            await s.execute(
              Sql.named(targetUpdateQuery),
              parameters: {'amount': tutar, 'id': targetBanka.id},
            );
          }
        }
        // E. Personel Entegrasyonu
        else if (locationType == 'personnel') {
          String personelIslemTuru = islemTuru == 'Tahsilat'
              ? 'credit'
              : 'payment';
          await PersonelIslemleriVeritabaniServisi().entegrasyonKaydiEkle(
            kullaniciId: cariKodu,
            tutar: tutar,
            tarih: tarih,
            aciklama: aciklama,
            islemTuru: personelIslemTuru,
            kaynakTuru: 'Banka',
            kaynakId: bankaId.toString(),
            ref: finalRef,
            session: s,
          );
        }
        // F. Gelir/Gider Entegrasyonu
        else if (locationType == 'income' || locationType == 'other') {
          debugPrint(
            '📝 Banka $locationType işlemi kaydedildi: $tutar ${islemTuru == "Tahsilat" ? "+" : "-"}',
          );
        }
      }
    }

    if (session != null) {
      await operation(session);
    } else {
      await _pool!.runTx((s) => operation(s));
    }

    return yeniIslemId;
  }

  /// [2025 SMART UPDATE] Banka İşlemi Güncelleme (Silmeden)
  Future<void> bankaIslemGuncelleByRef({
    required String ref,
    required double tutar,
    required String islemTuru, // 'Tahsilat', 'Ödeme'
    required String aciklama,
    required DateTime tarih,
    String? kullanici,
    TxSession? session,
  }) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isBankCreditActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde banka işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    Future<void> operation(TxSession s) async {
      // [2026] Aylık partition garanti (date değişebileceği için).
      try {
        await _createBankPartitions(tarih, session: s);
      } catch (_) {}

      // 1. Mevcut kaydı bul
      final existingRows = await s.execute(
        Sql.named(
          "SELECT id, bank_id, amount, type FROM bank_transactions WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId LIMIT 1",
        ),
        parameters: {'ref': ref, 'companyId': _companyId},
      );

      if (existingRows.isEmpty) return;

      final row = existingRows.first;
      final int transId = row[0] as int;
      final int bankaId = row[1] as int;
      final double oldAmount = double.tryParse(row[2]?.toString() ?? '') ?? 0.0;
      final String oldType = row[3] as String;

      // 2. Bakiyeyi Düzelt (Eski işlemin etkisini geri al)
      // Tahsilat (+): Bakiyeden düş
      // Ödeme (-): Bakiyeye ekle
      String revertQuery =
          'UPDATE banks SET balance = balance - @amount WHERE id = @id';
      if (oldType != 'Tahsilat') {
        revertQuery =
            'UPDATE banks SET balance = balance + @amount WHERE id = @id';
      }
      await s.execute(
        Sql.named(revertQuery),
        parameters: {'amount': oldAmount, 'id': bankaId},
      );

      // 3. Yeni Bakiyeyi İşle
      // Tahsilat (+): Bakiyeye ekle
      // Ödeme (-): Bakiyeden düş
      String applyQuery =
          'UPDATE banks SET balance = balance + @amount WHERE id = @id';
      if (islemTuru != 'Tahsilat') {
        applyQuery =
            'UPDATE banks SET balance = balance - @amount WHERE id = @id';
      }
      await s.execute(
        Sql.named(applyQuery),
        parameters: {'amount': tutar, 'id': bankaId},
      );

      // 4. İşlemi Güncelle
      await s.execute(
        Sql.named('''
          UPDATE bank_transactions 
          SET date = @tarih,
              description = @aciklama,
              amount = @tutar,
              type = @type,
              user_name = COALESCE(@kullanici, user_name)
          WHERE id = @id
        '''),
        parameters: {
          'id': transId,
          'tarih': tarih,
          'aciklama': aciklama,
          'tutar': tutar,
          'type': islemTuru,
          'kullanici': kullanici,
        },
      );
    }

    if (session != null) {
      await operation(session);
    } else {
      await _pool!.runTx((s) => operation(s));
    }
  }

  Future<Map<String, dynamic>?> bankaIslemGetir(int id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    final result = await _pool!.execute(
      Sql.named(
        "SELECT * FROM bank_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
      ),
      parameters: {'id': id, 'companyId': _companyId},
    );

    if (result.isEmpty) return null;

    final resultWithJoin = await _pool!.execute(
      Sql.named(
        "SELECT t.*, b.code as banka_kodu, b.name as banka_adi, b.currency as para_birimi FROM bank_transactions t LEFT JOIN banks b ON t.bank_id = b.id WHERE t.id = @id AND COALESCE(t.company_id, '$_defaultCompanyId') = @companyId",
      ),
      parameters: {'id': id, 'companyId': _companyId},
    );
    if (resultWithJoin.isEmpty) return null;

    return _mapToTransaction(resultWithJoin.first.toColumnMap());
  }

  Future<void> bankaIslemSil(
    int id, {
    bool skipLinked = false,
    TxSession? session,
  }) async {
    if (LiteKisitlari.isLiteMode &&
        !LiteKisitlari.isBankCreditActive &&
        !skipLinked) {
      throw const LiteLimitHatasi(
        'LITE sürümde banka işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    String? entegrasyonRef;

    Future<void> operation(TxSession s) async {
      // 1. Get transaction to revert balance
      final result = await s.execute(
        Sql.named(
          "SELECT * FROM bank_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      if (result.isEmpty) return;

      final row = result.first.toColumnMap();
      final double amount =
          double.tryParse(row['amount']?.toString() ?? '') ?? 0.0;
      final String type = row['type'] as String? ?? 'Tahsilat';
      final int bankId = row['bank_id'] as int;
      entegrasyonRef = row['integration_ref'] as String?;

      // 2. Revert Balance
      // If it was Tahsilat (Income), we subtract amount.
      // If it was Ödeme (Outcome), we add amount.
      String updateQuery =
          'UPDATE banks SET balance = balance - @amount WHERE id = @id';
      if (type != 'Tahsilat') {
        updateQuery =
            'UPDATE banks SET balance = balance + @amount WHERE id = @id';
      }

      await s.execute(
        Sql.named(updateQuery),
        parameters: {'amount': amount, 'id': bankId},
      );

      // 3. Delete Transaction
      // 3. Delete Transaction
      await s.execute(
        Sql.named(
          "DELETE FROM bank_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      // --- ENTEGRASYON: CARİ HESAP (Geri Al) ---
      if (skipLinked) return;
      final cariServis = CariHesaplarVeritabaniServisi();
      // Önce kaynak ID ile bulmaya çalış (Daha güvenli)
      int? cariId = await cariServis.cariIdGetirKaynak(
        kaynakTur: 'Banka',
        kaynakId: id,
        session: s,
      );

      // Bulunamazsa ve kod varsa, kod ile bul (Robustness)
      final String locCode = row['location_code'] as String? ?? '';
      if (cariId == null && locCode.isNotEmpty) {
        cariId = await cariServis.cariIdGetir(locCode, session: s);
      }

      if (cariId != null) {
        // [2026 CRITICAL FIX] Önce bu kaynak için gerçekten cari işlem var mı kontrol et
        // Çek tahsilatı gibi işlemlerde cariEntegrasyonYap: false kullanılıyor,
        // bu yüzden silinirken de cari işlem silmeye çalışılmamalı
        final existingCariTx = await s.execute(
          Sql.named('''
            SELECT id FROM current_account_transactions 
            WHERE source_type = 'Banka' AND source_id = @sourceId
            LIMIT 1
          '''),
          parameters: {'sourceId': id},
        );

        if (existingCariTx.isNotEmpty) {
          bool wasBorc = type != 'Tahsilat';
          await cariServis.cariIslemSil(
            cariId,
            amount,
            wasBorc,
            kaynakTur: 'Banka',
            kaynakId: id,
            session: s,
          );
        }
      }
    }

    if (session != null) {
      await operation(session);
    } else {
      await _pool!.runTx((s) => operation(s));
    }

    if (!skipLinked && (entegrasyonRef ?? '').isNotEmpty) {
      await entegrasyonBaglantiliIslemleriSil(
        entegrasyonRef!,
        haricBankaIslemId: id,
        session: session,
      );
    }
  }

  Future<void> bankaIslemGuncelle({
    required int id,
    required double tutar,
    required String aciklama,
    required DateTime tarih,
    required String cariTuru,
    required String cariKodu,
    required String cariAdi,
    required String kullanici,
    String? locationType, // Yeni parametre
    bool skipLinked = false,
    TxSession? session,
  }) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isBankCreditActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde banka işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    String? entegrasyonRef;

    Future<void> operation(TxSession s) async {
      // [2026] Aylık partition garanti (date değişebileceği için).
      try {
        await _createBankPartitions(tarih, session: s);
      } catch (_) {}

      // 1. Get old transaction
      final oldResult = await s.execute(
        Sql.named(
          "SELECT * FROM bank_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      if (oldResult.isEmpty) return;
      final oldRow = oldResult.first.toColumnMap();
      final double oldAmount =
          double.tryParse(oldRow['amount']?.toString() ?? '') ?? 0.0;
      final String type = oldRow['type'] as String? ?? 'Tahsilat';
      final int bankId = oldRow['bank_id'] as int;
      entegrasyonRef = oldRow['integration_ref'] as String?;

      // 2. Revert Old Balance
      String revertQuery =
          'UPDATE banks SET balance = balance - @amount WHERE id = @id';
      if (type != 'Tahsilat') {
        revertQuery =
            'UPDATE banks SET balance = balance + @amount WHERE id = @id';
      }
      await s.execute(
        Sql.named(revertQuery),
        parameters: {'amount': oldAmount, 'id': bankId},
      );

      // 3. Update Transaction Record
      await s.execute(
        Sql.named('''
          UPDATE bank_transactions 
          SET date=@date, description=@description, amount=@amount, 
              location=@location, location_code=@location_code, location_name=@location_name, user_name=@user_name
          WHERE id=@id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
        '''),
        parameters: {
          'id': id,
          'companyId': _companyId,
          'date': DateFormat('yyyy-MM-dd HH:mm').format(tarih),
          'description': aciklama,
          'amount': tutar,
          'location': cariTuru,
          'location_code': cariKodu,
          'location_name': cariAdi,
          'user_name': kullanici,
        },
      );

      // 4. Apply New Balance
      String applyQuery =
          'UPDATE banks SET balance = balance + @amount WHERE id = @id';
      if (type != 'Tahsilat') {
        applyQuery =
            'UPDATE banks SET balance = balance - @amount WHERE id = @id';
      }
      await s.execute(
        Sql.named(applyQuery),
        parameters: {'amount': tutar, 'id': bankId},
      );

      // --- ENTEGRASYON: CARİ HESAP ---
      if (!skipLinked) {
        final cariServis = CariHesaplarVeritabaniServisi();
        final String oldType = oldRow['type'] as String? ?? 'Tahsilat';

        // 1. İlgili Cari ID'leri Bul
        final int? oldCariId = await cariServis.cariIdGetirKaynak(
          kaynakTur: 'Banka',
          kaynakId: id,
          session: s,
        );

        int? newCariId;
        if (cariKodu.isNotEmpty) {
          newCariId = await cariServis.cariIdGetir(cariKodu, session: s);
        }

        // [2025 SMART UPDATE] Cari Değişmediyse ve Ref Varsa -> Update
        if (oldCariId != null &&
            newCariId != null &&
            oldCariId == newCariId &&
            (entegrasyonRef ?? '').isNotEmpty) {
          bool isBorc = oldType != 'Tahsilat';
          await cariServis.cariIslemGuncelleByRef(
            ref: entegrasyonRef!,
            tutar: tutar,
            isBorc: isBorc,
            aciklama: aciklama,
            tarih: tarih,
            belgeNo: '',
            kullanici: kullanici,
            session: s,
          );
        } else {
          // Fallback: Delete-Then-Insert
          if (oldCariId != null) {
            if ((entegrasyonRef ?? '').isNotEmpty) {
              await cariServis.cariIslemSilByRef(entegrasyonRef!, session: s);
            } else {
              bool wasBorc = oldType != 'Tahsilat';
              await cariServis.cariIslemSil(
                oldCariId,
                oldAmount,
                wasBorc,
                kaynakTur: 'Banka',
                kaynakId: id,
                session: s,
              );
            }
          }

          if (newCariId != null &&
              (locationType == 'current_account' || locationType == null)) {
            // Banka bilgilerini çek
            final bankaResult = await s.execute(
              Sql.named("SELECT code, name FROM banks WHERE id = @id"),
              parameters: {'id': bankId},
            );
            String bankaAdi = '';
            String bankaKodu = '';
            if (bankaResult.isNotEmpty) {
              final bankaRow = bankaResult.first.toColumnMap();
              bankaKodu = bankaRow['code'] as String? ?? '';
              bankaAdi = bankaRow['name'] as String? ?? '';
            }

            bool isBorc = oldType != 'Tahsilat';

            await cariServis.cariIslemEkle(
              cariId: newCariId,
              tutar: tutar,
              isBorc: isBorc,
              islemTuru: 'Banka',
              aciklama: aciklama,
              tarih: tarih,
              kullanici: kullanici,
              kaynakId: id,
              kaynakAdi: bankaAdi,
              kaynakKodu: bankaKodu,
              entegrasyonRef: entegrasyonRef,
              session: s,
            );
          }
        }
      }
    }

    if (session != null) {
      await operation(session);
    } else {
      await _pool!.runTx((s) => operation(s));
    }

    if (!skipLinked && (entegrasyonRef ?? '').isNotEmpty) {
      await entegrasyonBaglantiliIslemleriGuncelle(
        entegrasyonRef: entegrasyonRef!,
        tutar: tutar,
        aciklama: aciklama,
        tarih: tarih,
        kullanici: kullanici,
        haricBankaIslemId: id,
        session: session,
      );
    }
  }

  Future<void> entegrasyonBaglantiliIslemleriSil(
    String entegrasyonRef, {
    required int haricBankaIslemId,
    TxSession? session,
    bool silinecekCariyiEtkilesin = true, // KRITIK PARAMETRE
  }) async {
    if (_pool == null) return;

    // Helper to run queries with correct executor
    Future<List<List<dynamic>>> runQuery(
      String sql, {
      Map<String, dynamic>? params,
    }) async {
      if (session != null) {
        return await session.execute(Sql.named(sql), parameters: params);
      } else {
        return await _pool!.execute(Sql.named(sql), parameters: params);
      }
    }

    // 1) Diğer banka işlemleri
    final bankRows = await runQuery(
      "SELECT id FROM bank_transactions WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId AND id != @id",
      params: {
        'ref': entegrasyonRef,
        'companyId': _companyId,
        'id': haricBankaIslemId,
      },
    );
    for (final r in bankRows) {
      final int otherId = r[0] as int;
      await bankaIslemSil(otherId, skipLinked: true, session: session);
    }

    // 2) Kasa işlemleri
    final cashRows = await runQuery(
      "SELECT id FROM cash_register_transactions WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
      params: {'ref': entegrasyonRef, 'companyId': _companyId},
    );
    for (final r in cashRows) {
      final int cashId = r[0] as int;
      await KasalarVeritabaniServisi().kasaIslemSil(
        cashId,
        skipLinked: true,
        session: session,
      );
    }

    // 3) Kredi kartı işlemleri
    final ccRows = await runQuery(
      "SELECT id FROM credit_card_transactions WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
      params: {'ref': entegrasyonRef, 'companyId': _companyId},
    );
    for (final r in ccRows) {
      final int ccId = r[0] as int;
      await KrediKartlariVeritabaniServisi().krediKartiIslemSil(
        ccId,
        skipLinked: true,
        session: session,
      );
    }

    if (silinecekCariyiEtkilesin) {
      // 4) Cari Hesap işlemleri
      await CariHesaplarVeritabaniServisi().cariIslemSilByRef(
        entegrasyonRef,
        session: session,
      );

      // Personel işlemleri
      await PersonelIslemleriVeritabaniServisi().entegrasyonKaydiSil(
        entegrasyonRef,
        session: session,
      );
    }
  }

  Future<void> entegrasyonBaglantiliIslemleriGuncelle({
    required String entegrasyonRef,
    required double tutar,
    required String aciklama,
    required DateTime tarih,
    required String kullanici,
    required int haricBankaIslemId,
    TxSession? session,
  }) async {
    if (_pool == null) return;

    // Helper to run queries with correct executor
    Future<List<List<dynamic>>> runQuery(
      String sql, {
      Map<String, dynamic>? params,
    }) async {
      if (session != null) {
        return await session.execute(Sql.named(sql), parameters: params);
      } else {
        return await _pool!.execute(Sql.named(sql), parameters: params);
      }
    }

    // 1) Diğer banka işlemleri
    final bankRows = await runQuery(
      "SELECT id, location, location_code, location_name FROM bank_transactions WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId AND id != @id",
      params: {
        'ref': entegrasyonRef,
        'companyId': _companyId,
        'id': haricBankaIslemId,
      },
    );
    for (final r in bankRows) {
      await bankaIslemGuncelle(
        id: r[0] as int,
        tutar: tutar,
        aciklama: aciklama,
        tarih: tarih,
        cariTuru: r[1] as String? ?? '',
        cariKodu: r[2] as String? ?? '',
        cariAdi: r[3] as String? ?? '',
        kullanici: kullanici,
        skipLinked: true,
        session: session,
      );
    }

    // 2) Kasa işlemleri
    final cashRows = await runQuery(
      "SELECT id, location, location_code, location_name FROM cash_register_transactions WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
      params: {'ref': entegrasyonRef, 'companyId': _companyId},
    );
    for (final r in cashRows) {
      await KasalarVeritabaniServisi().kasaIslemGuncelle(
        id: r[0] as int,
        tutar: tutar,
        aciklama: aciklama,
        tarih: tarih,
        cariTuru: r[1] as String? ?? '',
        cariKodu: r[2] as String? ?? '',
        cariAdi: r[3] as String? ?? '',
        kullanici: kullanici,
        skipLinked: true,
        session: session,
      );
    }

    // 3) Kredi kartı işlemleri
    final ccRows = await runQuery(
      "SELECT id, location, location_code, location_name FROM credit_card_transactions WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
      params: {'ref': entegrasyonRef, 'companyId': _companyId},
    );
    for (final r in ccRows) {
      await KrediKartlariVeritabaniServisi().krediKartiIslemGuncelle(
        id: r[0] as int,
        tutar: tutar,
        aciklama: aciklama,
        tarih: tarih,
        cariTuru: r[1] as String? ?? '',
        cariKodu: r[2] as String? ?? '',
        cariAdi: r[3] as String? ?? '',
        kullanici: kullanici,
        skipLinked: true,
        session: session,
      );
    }

    // Personel işlemleri
    await PersonelIslemleriVeritabaniServisi().entegrasyonKaydiGuncelle(
      id: entegrasyonRef,
      tutar: tutar,
      aciklama: aciklama,
      tarih: tarih,
    );
  }
}
