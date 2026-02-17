import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import '../sayfalar/kasalar/modeller/kasa_model.dart';
import 'package:intl/intl.dart';
import 'cari_hesaplar_veritabani_servisi.dart';
import 'bankalar_veritabani_servisi.dart';
import 'kredi_kartlari_veritabani_servisi.dart';
import 'personel_islemleri_veritabani_servisi.dart';
import 'oturum_servisi.dart';
import 'lisans_yazma_koruma.dart';
import 'bulut_sema_dogrulama_servisi.dart';
import 'pg_eklentiler.dart';
import 'veritabani_yapilandirma.dart';
import 'ayarlar_veritabani_servisi.dart';

class KasalarVeritabaniServisi {
  static final KasalarVeritabaniServisi _instance =
      KasalarVeritabaniServisi._internal();
  factory KasalarVeritabaniServisi() => _instance;
  KasalarVeritabaniServisi._internal();

  Pool? _pool;
  bool _isInitialized = false;
  String? _initializedDatabase;
  String? _initializingDatabase;
  static const String _searchTagsVersionPrefix = 'v4';

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
      try {
        await _pool!.close();
      } catch (_) {}
      _pool = null;
      _isInitialized = false;
      _initializedDatabase = null;
    }

    final initToken = ++_initToken;
    final initCompleter = Completer<void>();
    _initCompleter = initCompleter;
    _initializingDatabase = targetDatabase;

    try {
      final Pool createdPool = LisansKorumaliPool(
        Pool.withEndpoints(
          [
            Endpoint(
              host: _config.host,
              port: _config.port,
              database: targetDatabase,
              username: _config.username,
              password: _config.password,
            ),
          ],
          settings: PoolSettings(
            sslMode: _config.sslMode,
            connectTimeout: _config.poolConnectTimeout,
            onOpen: _config.tuneConnection,
            maxConnectionCount: _config.maxConnections,
          ),
        ),
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
          'KasalarVeritabaniServisi: Bulut şema hazır, tablo kurulumu atlandı.',
        );
      }
      if (initToken != _initToken) {
        try {
          await createdPool.close();
        } catch (_) {}
        if (!initCompleter.isCompleted) {
          initCompleter.completeError(StateError('Bağlantı kapatıldı'));
        }
        return;
      }

      _isInitialized = true;
      _initializedDatabase = targetDatabase;
      _initializingDatabase = null;
      debugPrint(
        'KasalarVeritabaniServisi: Pool connection established successfully.',
      );
      if (!initCompleter.isCompleted) {
        initCompleter.complete();
      }
    } catch (e) {
      debugPrint('KasalarVeritabaniServisi: Connection error: $e');
      if (initToken == _initToken) {
        try {
          await _pool?.close();
        } catch (_) {}
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

    try {
      await pool?.close();
    } catch (_) {}
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('Bağlantı kapatıldı'));
    }
  }

  /// Bakım Modu: İndeksleri manuel günceller
  Future<void> bakimModuCalistir() async {
    await verileriIndeksle(forceUpdate: true);
  }

  /// "Sanal Kasa" veya "Diğer Ödemeler" adında özel bir kasa getirir veya oluşturur.
  Future<int> getSanalKasaId({
    String userName = 'Sistem',
    Session? session,
  }) async {
    if (session == null) {
      if (!_isInitialized) await baslat();
      if (_pool == null) throw Exception('Veritabanı bağlantısı yok');
    }

    final executor = session ?? _pool!;

    // 1. Ara
    final search = await executor.execute(
      Sql.named(
        "SELECT id FROM cash_registers WHERE (code = 'SANAL' OR name = 'Sanal Kasa' OR name = 'Diğer Ödemeler' OR search_tags LIKE '%sanal%') AND COALESCE(company_id, '$_defaultCompanyId') = @companyId LIMIT 1",
      ),
      parameters: {'companyId': _companyId},
    );

    if (search.isNotEmpty) {
      return search.first[0] as int;
    }

    // 2. Yoksa Oluştur (Sessizce)
    final result = await executor.execute(
      Sql.named('''
        INSERT INTO cash_registers (company_id, code, name, balance, currency, info1, is_active, is_default, search_tags)
        VALUES (@companyId, 'SANAL', 'Diğer Ödemeler (Sanal)', 0, 'TRY', 'Otomatik Oluşturuldu', 1, 0, 'sanal diğer ödemeler')
        RETURNING id
      '''),
      parameters: {'companyId': _companyId},
    );
    return result.first[0] as int;
  }

  Future<void> _tablolariOlustur() async {
    if (_pool == null) return;

    // Create Cash Registers Table
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS cash_registers (
        id SERIAL PRIMARY KEY,
        company_id TEXT,
        code TEXT,
        name TEXT,
        balance NUMERIC(15, 2) DEFAULT 0,
        currency TEXT,
        info1 TEXT,
        info2 TEXT,
        is_active INTEGER DEFAULT 1,
        is_default INTEGER DEFAULT 0,
        search_tags TEXT,
        matched_in_hidden INTEGER DEFAULT 0
      )
    ''');

    // [2025 HYPERSCALE] Create Cash Register Transactions Table - Native Partitioning Support
    try {
      // 1. Ana tablonun durumunu kontrol et
      final tableCheck = await _pool!.execute(
        "SELECT relkind::text FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'cash_register_transactions'",
      );

      bool isPartitioned = false;
      bool tableExists = tableCheck.isNotEmpty;

      if (tableExists) {
        final String relkind = tableCheck.first[0].toString().toLowerCase();
        isPartitioned = relkind.contains('p');
        debugPrint(
          'Kasa Hareketleri Tablo Durumu: tableExists=true, relkind=$relkind, isPartitioned=$isPartitioned',
        );
      }

      // 2. Eğer tablo YOK - yeni partitioned tablo oluştur
      if (!tableExists) {
        debugPrint('Kasa hareketleri tablosu oluşturuluyor (Partitioned)...');
        await _pool!.execute('''
          CREATE TABLE IF NOT EXISTS cash_register_transactions (
            id SERIAL,
            company_id TEXT,
            cash_register_id INTEGER,
            date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            description TEXT,
            amount NUMERIC(15, 2) DEFAULT 0,
            type TEXT,
            location TEXT,
            location_code TEXT,
            location_name TEXT,
            user_name TEXT,
            integration_ref TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id, date)
          ) PARTITION BY RANGE (date)
        ''');
        isPartitioned = true;
      }

      // 3. Eğer tablo VAR ama partitioned DEĞİL - migration gerekli
      if (tableExists && !isPartitioned) {
        debugPrint(
          '⚠️ Kasa hareketleri tablosu regular modda. Partitioned yapıya geçiliyor...',
        );

        // Eski tabloyu yeniden adlandır
        await _pool!.execute(
          'DROP TABLE IF EXISTS cash_register_transactions_old CASCADE',
        );
        await _pool!.execute(
          'ALTER TABLE cash_register_transactions RENAME TO cash_register_transactions_old',
        );

        // [FIX] Rename sequence to avoid collision
        try {
          await _pool!.execute(
            'ALTER SEQUENCE IF EXISTS cash_register_transactions_id_seq RENAME TO cash_register_transactions_old_id_seq',
          );
        } catch (_) {}

        // Yeni partitioned tabloyu oluştur
        await _pool!.execute('''
          CREATE TABLE cash_register_transactions (
            id SERIAL,
            company_id TEXT,
            cash_register_id INTEGER,
            date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            description TEXT,
            amount NUMERIC(15, 2) DEFAULT 0,
            type TEXT,
            location TEXT,
            location_code TEXT,
            location_name TEXT,
            user_name TEXT,
            integration_ref TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id, date)
          ) PARTITION BY RANGE (date)
        ''');
        isPartitioned = true;
      }

      // 4. Partition'ların olduğundan emin ol (ULTRA ROBUST)
      if (isPartitioned) {
        final int currentYear = DateTime.now().year;
        // Sadece cari yılı bekle (KRİTİK)
        await _createCashRegisterPartitions(currentYear);
      }

      // 5. Arka Plan İşlemleri: İndeksler, Triggerlar ve Diğer Yıllar
      if (_config.allowBackgroundDbMaintenance) {
        unawaited(() async {
          try {
            if (isPartitioned) {
              final int currentYear = DateTime.now().year;
              for (
                int year = currentYear - 2;
                year <= currentYear + 5;
                year++
              ) {
                if (year == currentYear) continue;
                await _createCashRegisterPartitions(year);
              }

              // DEFAULT partition
              await _pool!.execute('''
              CREATE TABLE IF NOT EXISTS cash_register_transactions_default 
              PARTITION OF cash_register_transactions DEFAULT
            ''');
            }

            // [MIGRATION & PERFORMANCE] İndeksler ve diğer ayarlar metodun sonunda arka planda kuruluyor.
          } catch (e) {
            debugPrint('Kasa arka plan kurulum hatası: $e');
          }
        }());
      }

      // 5. _old tablosu varsa migration yap
      final oldTableCheck = await _pool!.execute(
        "SELECT 1 FROM pg_class WHERE relname = 'cash_register_transactions_old' LIMIT 1",
      );

      if (oldTableCheck.isNotEmpty) {
        debugPrint('💾 Eski kasa hareketleri yeni bölümlere aktarılıyor...');
        try {
          await _pool!.execute('''
            INSERT INTO cash_register_transactions (
              id, company_id, cash_register_id, date, description, amount, type, 
              location, location_code, location_name, user_name, integration_ref, created_at
            )
            SELECT 
              id, company_id, cash_register_id, COALESCE(date, created_at, CURRENT_TIMESTAMP), 
              description, amount, type, location, location_code, location_name, 
              user_name, integration_ref, created_at
            FROM cash_register_transactions_old
            ON CONFLICT (id, date) DO NOTHING
          ''');

          // Sequence güncelle (Serial için kritik)
          final maxIdResult = await _pool!.execute(
            'SELECT COALESCE(MAX(id), 0) FROM cash_register_transactions',
          );
          final maxId =
              int.tryParse(maxIdResult.first[0]?.toString() ?? '0') ?? 0;
          if (maxId > 0) {
            await _pool!.execute(
              "SELECT setval(pg_get_serial_sequence('cash_register_transactions', 'id'), $maxId)",
            );
          }

          // Migration başarılı - _old tablosunu sil
          await _pool!.execute(
            'DROP TABLE cash_register_transactions_old CASCADE',
          );
          debugPrint('✅ Kasa hareketleri başarıyla bölümlendirildi.');
        } catch (e) {
          debugPrint('❌ Migration hatası: $e');
        }
      }
    } catch (e) {
      debugPrint('Kasa hareketleri ana yapı kurulum hatası: $e');
      rethrow;
    }

    // Add columns if they don't exist (Migration-like check)
    try {
      await _pool!.execute(
        'ALTER TABLE cash_register_transactions ADD COLUMN IF NOT EXISTS location TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE cash_register_transactions ADD COLUMN IF NOT EXISTS location_code TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE cash_register_transactions ADD COLUMN IF NOT EXISTS location_name TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE cash_register_transactions ADD COLUMN IF NOT EXISTS integration_ref TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE cash_registers ADD COLUMN IF NOT EXISTS company_id TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE cash_register_transactions ADD COLUMN IF NOT EXISTS company_id TEXT',
      );

      // [2025 ELITE] get_professional_label SQL Helper Function
      // Global yardımcı fonksiyon
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

      // [2026 FIX] get_professional_label overload ambiguity (42725)
      // Eski DB'lerde 3 parametreli overload DEFAULT arg'larla geldiği için,
      // 2 parametreli çağrılarda "is not unique" hatası oluşabiliyor.
      // Çözüm: 3 parametreli overload'un DEFAULT'larını kaldıran (no-default) bir sürümle replace et.
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

        final int defaultCount = procRows.isNotEmpty
            ? (int.tryParse(procRows.first[0].toString()) ?? 0)
            : 0;

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
      } catch (_) {}

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

    // [2025 HYPER-SPEED] İndeksler ve Triggerlar arka planda kurulur (Sayfa anında açılır)
    if (_config.allowBackgroundDbMaintenance) {
      unawaited(() async {
        try {
          // 1 Milyar Kayıt İçin GIN İndeksi (Trigram)
          await PgEklentiler.ensurePgTrgm(_pool!);
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_cash_registers_search_tags_gin ON cash_registers USING GIN (search_tags gin_trgm_ops)',
          );
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_cash_registers_code_trgm ON cash_registers USING GIN (code gin_trgm_ops)',
          );
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_cash_registers_name_trgm ON cash_registers USING GIN (name gin_trgm_ops)',
          );

          // B-Tree İndeksleri
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_crt_cash_register_id ON cash_register_transactions (cash_register_id)',
          );
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_crt_date ON cash_register_transactions (date)',
          );
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_crt_type ON cash_register_transactions (type)',
          );
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_crt_created_at ON cash_register_transactions (created_at)',
          );
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_crt_integration_ref ON cash_register_transactions (integration_ref)',
          );
          await _pool!.execute(
            'CREATE INDEX IF NOT EXISTS idx_crt_created_at_brin ON cash_register_transactions USING BRIN (created_at) WITH (pages_per_range = 128)',
          );

          // Search Tags Trigger
          await _pool!.execute('''
          CREATE OR REPLACE FUNCTION update_cash_register_search_tags() RETURNS TRIGGER AS \$\$
          BEGIN
            UPDATE cash_registers cr
            SET search_tags = normalize_text(
              '$_searchTagsVersionPrefix ' ||
              COALESCE(cr.code, '') || ' ' ||
              COALESCE(cr.name, '') || ' ' ||
              COALESCE(cr.currency, '') || ' ' ||
              COALESCE(cr.info1, '') || ' ' ||
              COALESCE(cr.info2, '') || ' ' ||
              CAST(cr.id AS TEXT) || ' ' ||
              (CASE WHEN cr.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
              COALESCE((
             SELECT STRING_AGG(
                 get_professional_label(crt.type, 'cash') || ' ' ||
                 get_professional_label(crt.type, 'cari') || ' ' ||
                 COALESCE(crt.type, '') || ' ' ||
                 COALESCE(TO_CHAR(crt.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
               COALESCE(crt.description, '') || ' ' ||
               COALESCE(crt.location, '') || ' ' ||
               COALESCE(crt.location_code, '') || ' ' ||
                  COALESCE(crt.location_name, '') || ' ' ||
                  COALESCE(crt.user_name, '') || ' ' ||
                  COALESCE(CAST(crt.amount AS TEXT), '') || ' ' ||
                  COALESCE(crt.integration_ref, '') || ' ' ||
                  (CASE 
                    WHEN crt.integration_ref = 'opening_stock' OR crt.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                    WHEN crt.integration_ref LIKE '%production%' OR crt.description ILIKE '%Üretim%' THEN 'üretim'
                    WHEN crt.integration_ref LIKE '%transfer%' OR crt.description ILIKE '%Devir%' THEN 'devir'
                    WHEN crt.integration_ref LIKE '%shipment%' THEN 'sevkiyat'
                    WHEN crt.integration_ref LIKE '%collection%' THEN 'tahsilat'
                    WHEN crt.integration_ref LIKE '%payment%' THEN 'ödeme'
                    WHEN crt.integration_ref LIKE 'SALE-%' OR crt.integration_ref LIKE 'RETAIL-%' THEN 'satış yapıldı'
                    WHEN crt.integration_ref LIKE 'PURCHASE-%' THEN 'alış yapıldı'
                    ELSE ''
                   END),
                  ' '
                )
                FROM (
                  SELECT * FROM cash_register_transactions sub_crt
                  WHERE sub_crt.cash_register_id = cr.id
                  ORDER BY sub_crt.created_at DESC
                  LIMIT 50
                ) crt
              ), '')
            )
            WHERE cr.id = COALESCE(NEW.cash_register_id, OLD.cash_register_id);
            RETURN NULL;
          END;
          \$\$ LANGUAGE plpgsql;
        ''');

          final triggerExists = await _pool!.execute(
            "SELECT 1 FROM pg_trigger WHERE tgname = 'trg_update_cash_register_search_tags'",
          );
          if (triggerExists.isEmpty) {
            await _pool!.execute(
              'CREATE TRIGGER trg_update_cash_register_search_tags AFTER INSERT OR DELETE ON cash_register_transactions FOR EACH ROW EXECUTE FUNCTION update_cash_register_search_tags()',
            );
          }
          // Initial İndeksleme: Arka planda çalıştır (sayfa açılışını bloklama)
          await verileriIndeksle(forceUpdate: false);
        } catch (e) {
          if (e is LisansYazmaEngelliHatasi) return;
          debugPrint('Kasa arka plan bakım hatası: $e');
        }
      }());
    }
  }

  /// Kasa için search_tags güncellemesi yapar (işlem geçmişi dahil)
  Future<void> _updateSearchTags(int kasaId, {Session? session}) async {
    final executor = session ?? _pool;
    if (executor == null) return;

    try {
      // Kasa ana bilgileri + son 50 işlem geçmişi birleştirilerek search_tags güncellenir
      await executor.execute(
        Sql.named('''
        UPDATE cash_registers cr
        SET search_tags = normalize_text(
          '$_searchTagsVersionPrefix ' ||
          -- Ana Alanlar
          COALESCE(cr.code, '') || ' ' ||
          COALESCE(cr.name, '') || ' ' ||
          COALESCE(cr.currency, '') || ' ' ||
          COALESCE(cr.info1, '') || ' ' ||
          COALESCE(cr.info2, '') || ' ' ||
          CAST(cr.id AS TEXT) || ' ' ||
          (CASE WHEN cr.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
          -- İşlem Geçmişi (Son 50)
          COALESCE((
             SELECT STRING_AGG(
                 get_professional_label(crt.type, 'cash') || ' ' ||
                 get_professional_label(crt.type, 'cari') || ' ' ||
                 COALESCE(crt.type, '') || ' ' ||
                 COALESCE(TO_CHAR(crt.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
               COALESCE(crt.description, '') || ' ' ||
               COALESCE(crt.location, '') || ' ' ||
               COALESCE(crt.location_code, '') || ' ' ||
              COALESCE(crt.location_name, '') || ' ' ||
              COALESCE(crt.user_name, '') || ' ' ||
              COALESCE(CAST(crt.amount AS TEXT), '') || ' ' ||
              COALESCE(crt.integration_ref, '') || ' ' ||
              (CASE 
                WHEN crt.integration_ref = 'opening_stock' OR crt.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                WHEN crt.integration_ref LIKE '%production%' OR crt.description ILIKE '%Üretim%' THEN 'üretim'
                WHEN crt.integration_ref LIKE '%transfer%' OR crt.description ILIKE '%Devir%' THEN 'devir'
                WHEN crt.integration_ref LIKE '%shipment%' THEN 'sevkiyat'
                WHEN crt.integration_ref LIKE '%collection%' THEN 'tahsilat'
                WHEN crt.integration_ref LIKE '%payment%' THEN 'ödeme'
                WHEN crt.integration_ref LIKE 'SALE-%' OR crt.integration_ref LIKE 'RETAIL-%' THEN 'satış yapıldı'
                WHEN crt.integration_ref LIKE 'PURCHASE-%' THEN 'alış yapıldı'
                ELSE ''
               END),
              ' '
            )
            FROM (
              SELECT * FROM cash_register_transactions sub_crt
              WHERE sub_crt.cash_register_id = cr.id
              ORDER BY sub_crt.created_at DESC
              LIMIT 50
            ) crt
          ), '')
        )
        WHERE cr.id = @kasaId
      '''),
        parameters: {'kasaId': kasaId},
      );
    } catch (e) {
      if (e is LisansYazmaEngelliHatasi) return;
      debugPrint('search_tags güncelleme hatası (kasa $kasaId): $e');
    }
  }

  /// Tüm kasalar için search_tags indekslemesi yapar (Bakım modu)
  /// forceUpdate=true ise tüm kasaları yeniden indeksler
  /// Tüm kasalar için search_tags indekslemesi yapar (Batch Processing)
  Future<void> verileriIndeksle({bool forceUpdate = true}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    try {
      debugPrint('🚀 Kasa İndeksleme Başlatılıyor (Batch Modu)...');

      const int batchSize = 500;
      int processedCount = 0;
      int lastId = 0;

      while (true) {
        final String versionPredicate =
            "(search_tags IS NULL OR search_tags = '' OR search_tags NOT LIKE '$_searchTagsVersionPrefix%')";

        final idRows = await _pool!.execute(
          Sql.named(
            "SELECT id FROM cash_registers WHERE id > @lastId AND COALESCE(company_id, '$_defaultCompanyId') = @companyId ${forceUpdate ? '' : 'AND $versionPredicate'} ORDER BY id ASC LIMIT @batchSize",
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

        final String idListStr = ids.join(',');

        final String conditionalWhere = forceUpdate
            ? ""
            : " AND $versionPredicate";

        await _pool!.execute(
          Sql.named('''
          UPDATE cash_registers cr
          SET search_tags = normalize_text(
            '$_searchTagsVersionPrefix ' ||
            -- Ana Alanlar
            COALESCE(cr.code, '') || ' ' ||
            COALESCE(cr.name, '') || ' ' ||
            COALESCE(cr.currency, '') || ' ' ||
            COALESCE(cr.info1, '') || ' ' ||
            COALESCE(cr.info2, '') || ' ' ||
            CAST(cr.id AS TEXT) || ' ' ||
            (CASE WHEN cr.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
            -- İşlem Geçmişi (Son 50)
            COALESCE((
              SELECT STRING_AGG(
                get_professional_label(crt.type, 'cash') || ' ' ||
                get_professional_label(crt.type, 'cari') || ' ' ||
                COALESCE(crt.type, '') || ' ' ||
                COALESCE(TO_CHAR(crt.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
                COALESCE(crt.description, '') || ' ' ||
                COALESCE(crt.location, '') || ' ' ||
                COALESCE(crt.location_code, '') || ' ' ||
                COALESCE(crt.location_name, '') || ' ' ||
                COALESCE(crt.user_name, '') || ' ' ||
                COALESCE(CAST(crt.amount AS TEXT), '') || ' ' ||
                COALESCE(crt.integration_ref, '') || ' ' ||
                (CASE 
                  WHEN crt.integration_ref = 'opening_stock' OR crt.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                  WHEN crt.integration_ref LIKE '%production%' OR crt.description ILIKE '%Üretim%' THEN 'üretim'
                  WHEN crt.integration_ref LIKE '%transfer%' OR crt.description ILIKE '%Devir%' THEN 'devir'
                  WHEN crt.integration_ref LIKE '%shipment%' THEN 'sevkiyat'
                  WHEN crt.integration_ref LIKE '%collection%' THEN 'tahsilat'
                  WHEN crt.integration_ref LIKE '%payment%' THEN 'ödeme'
                  WHEN crt.integration_ref LIKE 'SALE-%' OR crt.integration_ref LIKE 'RETAIL-%' THEN 'satış yapıldı'
                  WHEN crt.integration_ref LIKE 'PURCHASE-%' THEN 'alış yapıldı'
                  ELSE ''
                 END),
                ' '
              )
              FROM (
                SELECT * FROM cash_register_transactions sub_crt
                WHERE sub_crt.cash_register_id = cr.id
                ORDER BY sub_crt.created_at DESC
                LIMIT 50
              ) crt
            ), '')
          )
          WHERE cr.id IN ($idListStr) $conditionalWhere
        '''),
        );

        processedCount += ids.length;
        debugPrint('   ...$processedCount kasa indekslendi.');
        await Future.delayed(const Duration(milliseconds: 10));
      }

      debugPrint('✅ Kasa Arama İndeksleri Tamamlandı. Toplam: $processedCount');
    } catch (e) {
      if (e is LisansYazmaEngelliHatasi) return;
      debugPrint('Kasa indeksleme sırasında hata: $e');
    }
  }

  /// Varsayılan kasayı getirir
  Future<KasaModel?> varsayilanKasaGetir() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    final result = await _pool!.execute(
      Sql.named(
        "SELECT * FROM cash_registers WHERE is_default = 1 AND COALESCE(company_id, '$_defaultCompanyId') = @companyId LIMIT 1",
      ),
      parameters: {'companyId': _companyId},
    );

    if (result.isEmpty) return null;
    return _mapToKasaModel(result.first.toColumnMap());
  }

  /// Kasaları getirir (1 Milyar Kayıt Optimizasyonu)
  /// Deep Search: Tüm alanlarda + işlem geçmişinde arama yapar.
  /// Arama sonucu görünmeyen alanlarda eşleşme bulunursa matchedInHidden=true döner.
  Future<List<KasaModel>> kasalariGetir({
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
    int? kasaId,
    Session? session,
  }) async {
    if (session == null) {
      if (!_isInitialized) await baslat();
      if (_pool == null) return [];
    }

    final executor = session ?? _pool!;

    // 1 Milyar Kayıt Optimizasyonu: Deep Search
    // search_tags alanı tüm ilişkili verileri içerir (işlem geçmişi dahil)
    String selectClause = 'SELECT cr.*';

    // Arama varsa matched_in_hidden hesapla
    if (aramaKelimesi != null && aramaKelimesi.isNotEmpty) {
      selectClause +=
          ''',
        (CASE
          WHEN (
            -- Expanded/detail-only fields
            normalize_text(COALESCE(cr.info1, '')) LIKE @search OR
            normalize_text(COALESCE(cr.info2, '')) LIKE @search OR
            -- Expanded timeline (last 50 transactions)
            EXISTS (
              SELECT 1
              FROM (
                SELECT *
                FROM cash_register_transactions sub_crt
                WHERE sub_crt.cash_register_id = cr.id
                  AND COALESCE(sub_crt.company_id, '$_defaultCompanyId') = @companyId
                ORDER BY sub_crt.created_at DESC
                LIMIT 50
               ) crt
               WHERE normalize_text(
                 COALESCE(get_professional_label(crt.type, 'cash'), '') || ' ' ||
                 COALESCE(get_professional_label(crt.type, 'cari'), '') || ' ' ||
                 COALESCE(crt.type, '') || ' ' ||
                 COALESCE(TO_CHAR(crt.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
                 COALESCE(crt.description, '') || ' ' ||
                 COALESCE(crt.location, '') || ' ' ||
                COALESCE(crt.location_code, '') || ' ' ||
                COALESCE(crt.location_name, '') || ' ' ||
                COALESCE(crt.user_name, '') || ' ' ||
                COALESCE(CAST(crt.amount AS TEXT), '') || ' ' ||
                COALESCE(crt.integration_ref, '') || ' ' ||
                (CASE 
                  WHEN crt.integration_ref = 'opening_stock' OR crt.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                  WHEN crt.integration_ref LIKE '%production%' OR crt.description ILIKE '%Üretim%' THEN 'üretim'
                  WHEN crt.integration_ref LIKE '%transfer%' OR crt.description ILIKE '%Devir%' THEN 'devir'
                  WHEN crt.integration_ref LIKE '%shipment%' THEN 'sevkiyat'
                  WHEN crt.integration_ref LIKE '%collection%' THEN 'tahsilat'
                  WHEN crt.integration_ref LIKE '%payment%' THEN 'ödeme'
                  WHEN crt.integration_ref LIKE 'SALE-%' OR crt.integration_ref LIKE 'RETAIL-%' THEN 'satış yapıldı'
                  WHEN crt.integration_ref LIKE 'PURCHASE-%' THEN 'alış yapıldı'
                  ELSE ''
                 END)
              ) LIKE @search
            )
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
      // Deep Search (indexed): v2 normalize_text + trigram (search_tags)
      conditions.add("COALESCE(cr.search_tags, '') LIKE @search");
      params['search'] = '%${_normalizeTurkish(aramaKelimesi)}%';
    }

    if (aktifMi != null) {
      conditions.add('is_active = @isActive');
      params['isActive'] = aktifMi ? 1 : 0;
    }

    if (varsayilan != null) {
      conditions.add('is_default = @varsayilan');
      params['varsayilan'] = varsayilan ? 1 : 0;
    }

    if (kasaId != null) {
      conditions.add('id = @kasaId');
      params['kasaId'] = kasaId;
    }

    // Kullanıcı Filtresi
    if (kullanici != null && kullanici.isNotEmpty) {
      conditions.add('''
        EXISTS (
          SELECT 1 FROM cash_register_transactions crt
          WHERE crt.cash_register_id = cr.id
          AND crt.user_name = @kullanici
          AND COALESCE(crt.company_id, '$_defaultCompanyId') = @companyId
        )
      ''');
      params['kullanici'] = kullanici;
    }

    // İşlem Türü Filtresi: İşlem geçmişinde belirtilen tür varsa getir
    if (islemTuru != null && islemTuru.isNotEmpty) {
      final normalized = islemTuru.trim();
      if (normalized == 'Satış Yapıldı' || normalized == 'Satis Yapildi') {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM cash_register_transactions crt
            WHERE crt.cash_register_id = cr.id
            AND (crt.integration_ref LIKE 'SALE-%' OR crt.integration_ref LIKE 'RETAIL-%')
            AND COALESCE(crt.company_id, '$_defaultCompanyId') = @companyId
          )
        ''');
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM cash_register_transactions crt
            WHERE crt.cash_register_id = cr.id
            AND crt.integration_ref LIKE 'PURCHASE-%'
            AND COALESCE(crt.company_id, '$_defaultCompanyId') = @companyId
          )
        ''');
      } else {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM cash_register_transactions crt
            WHERE crt.cash_register_id = cr.id
            AND crt.type = @islemTuru
            AND COALESCE(crt.company_id, '$_defaultCompanyId') = @companyId
          )
        ''');
        params['islemTuru'] = normalized;
      }
    }

    // Tarih Filtresi: Belirtilen tarih aralığında işlemi olan kasaları getir
    if (baslangicTarihi != null || bitisTarihi != null) {
      String existsQuery =
          '''
        EXISTS (
          SELECT 1 FROM cash_register_transactions crt
          WHERE crt.cash_register_id = cr.id
          AND COALESCE(crt.company_id, '$_defaultCompanyId') = @companyId
      ''';

      if (baslangicTarihi != null) {
        existsQuery += " AND crt.date >= @startDate";
        params['startDate'] = DateTime(
          baslangicTarihi.year,
          baslangicTarihi.month,
          baslangicTarihi.day,
        ).toIso8601String();
      }
      if (bitisTarihi != null) {
        existsQuery += " AND crt.date < @endDate";
        params['endDate'] = DateTime(
          bitisTarihi.year,
          bitisTarihi.month,
          bitisTarihi.day,
        ).add(const Duration(days: 1)).toIso8601String();
      }

      existsQuery += ')';
      conditions.add(existsQuery);
    }

    String whereClause = '';
    if (conditions.isNotEmpty) {
      whereClause = 'WHERE ${conditions.join(' AND ')}';
    }

    // Sorting
    String orderBy = 'id';
    if (siralama != null) {
      switch (siralama) {
        case 'kod':
          orderBy = 'code';
          break;
        case 'ad':
          orderBy = 'name';
          break;
        case 'bakiye':
          orderBy = 'balance';
          break;
      }
    }

    final String query =
        '''
      $selectClause
      FROM cash_registers cr
      $whereClause
      ORDER BY $orderBy ${artanSiralama ? 'ASC' : 'DESC'}
      LIMIT @limit OFFSET @offset
    ''';

    params['limit'] = sayfaBasinaKayit;
    params['offset'] = (sayfa - 1) * sayfaBasinaKayit;

    final result = await executor.execute(Sql.named(query), parameters: params);

    return result.map((row) {
      final map = row.toColumnMap();
      return _mapToKasaModel(map);
    }).toList();
  }

  /// Kasa sayısını getirir (Deep Search destekli)
  Future<int> kasaSayisiGetir({
    String? aramaTerimi,
    bool? aktifMi,
    bool? varsayilan,
    String? kullanici,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? islemTuru,
    int? kasaId,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;

    // 🚀 10 Milyar Kayıt Optimizasyonu: Filtresiz sorgular için yaklaşık sayım
    if (aramaTerimi == null &&
        aktifMi == null &&
        varsayilan == null &&
        kullanici == null &&
        baslangicTarihi == null &&
        bitisTarihi == null &&
        islemTuru == null &&
        kasaId == null) {
      try {
        final approxResult = await _pool!.execute(
          "SELECT reltuples::BIGINT FROM pg_class WHERE relname = 'cash_registers'",
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

    String query = 'SELECT COUNT(*) FROM cash_registers cr';
    List<String> conditions = [];
    Map<String, dynamic> params = {'companyId': _companyId};

    conditions.add("COALESCE(company_id, '$_defaultCompanyId') = @companyId");

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      // Deep Search (indexed): v2 normalize_text + trigram (search_tags)
      conditions.add("COALESCE(cr.search_tags, '') LIKE @search");
      params['search'] = '%${_normalizeTurkish(aramaTerimi)}%';
    }

    if (aktifMi != null) {
      conditions.add('is_active = @isActive');
      params['isActive'] = aktifMi ? 1 : 0;
    }

    if (varsayilan != null) {
      conditions.add('is_default = @varsayilan');
      params['varsayilan'] = varsayilan ? 1 : 0;
    }

    if (kasaId != null) {
      conditions.add('id = @kasaId');
      params['kasaId'] = kasaId;
    }

    // Kullanıcı Filtresi
    if (kullanici != null && kullanici.isNotEmpty) {
      conditions.add('''
        EXISTS (
          SELECT 1 FROM cash_register_transactions crt
          WHERE crt.cash_register_id = cr.id
          AND crt.user_name = @kullanici
          AND COALESCE(crt.company_id, '$_defaultCompanyId') = @companyId
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
            SELECT 1 FROM cash_register_transactions crt
            WHERE crt.cash_register_id = cr.id
            AND (crt.integration_ref LIKE 'SALE-%' OR crt.integration_ref LIKE 'RETAIL-%')
            AND COALESCE(crt.company_id, '$_defaultCompanyId') = @companyId
          )
        ''');
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM cash_register_transactions crt
            WHERE crt.cash_register_id = cr.id
            AND crt.integration_ref LIKE 'PURCHASE-%'
            AND COALESCE(crt.company_id, '$_defaultCompanyId') = @companyId
          )
        ''');
      } else {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM cash_register_transactions crt
            WHERE crt.cash_register_id = cr.id
            AND crt.type = @islemTuru
            AND COALESCE(crt.company_id, '$_defaultCompanyId') = @companyId
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
          SELECT 1 FROM cash_register_transactions crt
          WHERE crt.cash_register_id = cr.id
          AND COALESCE(crt.company_id, '$_defaultCompanyId') = @companyId
      ''';

      if (baslangicTarihi != null) {
        existsQuery += " AND crt.date >= @startDate";
        params['startDate'] = DateTime(
          baslangicTarihi.year,
          baslangicTarihi.month,
          baslangicTarihi.day,
        ).toIso8601String();
      }
      if (bitisTarihi != null) {
        existsQuery += " AND crt.date < @endDate";
        params['endDate'] = DateTime(
          bitisTarihi.year,
          bitisTarihi.month,
          bitisTarihi.day,
        ).add(const Duration(days: 1)).toIso8601String();
      }

      existsQuery += ')';
      conditions.add(existsQuery);
    }

    if (conditions.isNotEmpty) {
      query += ' WHERE ${conditions.join(' AND ')}';
    }

    final result = await _pool!.execute(Sql.named(query), parameters: params);
    return result[0][0] as int;
  }

  /// [2026 HYPER-SPEED] Dinamik filtre seçeneklerini ve sayılarını getirir.
  /// 1 Milyar+ kayıt için optimize edilmiş, SARGable predicates ve Capped Count kullanır.
  Future<Map<String, Map<String, int>>> kasaFiltreIstatistikleriniGetir({
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

    Map<String, dynamic> params = {'companyId': _companyId};
    List<String> baseConditions = [];
    baseConditions.add(
      "COALESCE(cash_registers.company_id, '$_defaultCompanyId') = @companyId",
    );

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      baseConditions.add("COALESCE(search_tags, '') LIKE @search");
      params['search'] = '%${_normalizeTurkish(aramaTerimi)}%';
    }

    // Transaction conditions used across facets (always includes company filter)
    String transactionFilters =
        " AND COALESCE(cat.company_id, '$_defaultCompanyId') = @companyId";
    if (baslangicTarihi != null) {
      transactionFilters += " AND cat.date >= @start";
      params['start'] = DateTime(
        baslangicTarihi.year,
        baslangicTarihi.month,
        baslangicTarihi.day,
      ).toIso8601String();
    }
    if (bitisTarihi != null) {
      transactionFilters += " AND cat.date < @end";
      params['end'] = DateTime(
        bitisTarihi.year,
        bitisTarihi.month,
        bitisTarihi.day,
      ).add(const Duration(days: 1)).toIso8601String();
    }

    // Date facet: only add EXISTS when user selected a range
    if (baslangicTarihi != null || bitisTarihi != null) {
      baseConditions.add('''
        EXISTS (
          SELECT 1 FROM cash_register_transactions cat 
          WHERE cat.cash_register_id = cash_registers.id 
          $transactionFilters
        )
      ''');
    }

    // Helper to generate query with specific filters applied (excluding the facet itself)
    String buildQuery(
      String selectAndGroup,
      List<String> facetConds,
      Map<String, dynamic> facetParams,
    ) {
      String where = (baseConditions.isNotEmpty || facetConds.isNotEmpty)
          ? 'WHERE ${(baseConditions + facetConds).join(' AND ')}'
          : '';
      return 'SELECT $selectAndGroup FROM (SELECT * FROM cash_registers $where LIMIT 100001) as sub GROUP BY 1';
    }

    // 1. Durum İstatistikleri
    List<String> durumConds = [];
    if (varsayilan != null) durumConds.add('is_default = @varsayilan');
    if (kullanici != null && kullanici.isNotEmpty) {
      durumConds.add('''
        EXISTS (
          SELECT 1 FROM cash_register_transactions cat 
          WHERE cat.cash_register_id = cash_registers.id 
          AND cat.user_name = @kullanici
            $transactionFilters
        )
      ''');
    }
    if (islemTuru != null && islemTuru.isNotEmpty) {
      final normalized = islemTuru.trim();
      if (normalized == 'Satış Yapıldı' || normalized == 'Satis Yapildi') {
        durumConds.add('''
          EXISTS (
            SELECT 1 FROM cash_register_transactions cat 
            WHERE cat.cash_register_id = cash_registers.id 
            AND (cat.integration_ref LIKE 'SALE-%' OR cat.integration_ref LIKE 'RETAIL-%')
              $transactionFilters
          )
        ''');
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        durumConds.add('''
          EXISTS (
            SELECT 1 FROM cash_register_transactions cat 
            WHERE cat.cash_register_id = cash_registers.id 
            AND cat.integration_ref LIKE 'PURCHASE-%'
              $transactionFilters
          )
        ''');
      } else {
        durumConds.add('''
          EXISTS (
            SELECT 1 FROM cash_register_transactions cat 
            WHERE cat.cash_register_id = cash_registers.id 
            AND cat.type = @islemTuru
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
          SELECT 1 FROM cash_register_transactions cat 
          WHERE cat.cash_register_id = cash_registers.id 
          AND cat.user_name = @kullanici
          $transactionFilters
        )
      ''');
    }
    if (islemTuru != null && islemTuru.isNotEmpty) {
      final normalized = islemTuru.trim();
      if (normalized == 'Satış Yapıldı' || normalized == 'Satis Yapildi') {
        defaultConds.add('''
          EXISTS (
            SELECT 1 FROM cash_register_transactions cat 
            WHERE cat.cash_register_id = cash_registers.id 
            AND (cat.integration_ref LIKE 'SALE-%' OR cat.integration_ref LIKE 'RETAIL-%')
            $transactionFilters
          )
        ''');
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        defaultConds.add('''
          EXISTS (
            SELECT 1 FROM cash_register_transactions cat 
            WHERE cat.cash_register_id = cash_registers.id 
            AND cat.integration_ref LIKE 'PURCHASE-%'
            $transactionFilters
          )
        ''');
      } else {
        defaultConds.add('''
          EXISTS (
            SELECT 1 FROM cash_register_transactions cat 
            WHERE cat.cash_register_id = cash_registers.id 
            AND cat.type = @islemTuru
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
          SELECT 1 FROM cash_register_transactions cat 
          WHERE cat.cash_register_id = cash_registers.id 
          AND cat.user_name = @kullanici
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
            SELECT 1 FROM cash_register_transactions cat 
            WHERE cat.cash_register_id = cash_registers.id 
            AND (cat.integration_ref LIKE 'SALE-%' OR cat.integration_ref LIKE 'RETAIL-%')
            $transactionFilters
          )
        ''');
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        userConds.add('''
          EXISTS (
            SELECT 1 FROM cash_register_transactions cat 
            WHERE cat.cash_register_id = cash_registers.id 
            AND cat.integration_ref LIKE 'PURCHASE-%'
            $transactionFilters
          )
        ''');
      } else {
        userConds.add('''
          EXISTS (
            SELECT 1 FROM cash_register_transactions cat 
            WHERE cat.cash_register_id = cash_registers.id 
            AND cat.type = @islemTuru
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
          'SELECT COUNT(*) FROM cash_registers ${baseConditions.isNotEmpty ? 'WHERE ${baseConditions.join(' AND ')}' : ''}',
        ),
        parameters: params,
      ),
      // Durumlar
      _pool!.execute(
        Sql.named(buildQuery('is_active, COUNT(*)', durumConds, durumParams)),
        parameters: durumParams,
      ),
      // Varsayılanlar
      _pool!.execute(
        Sql.named(
          buildQuery('is_default, COUNT(*)', defaultConds, defaultParams),
        ),
        parameters: defaultParams,
      ),
      // İşlem Türleri
      _pool!.execute(
        Sql.named('''
        SELECT 
          CASE
            WHEN cat.integration_ref LIKE 'SALE-%' OR cat.integration_ref LIKE 'RETAIL-%' THEN 'Satış Yapıldı'
            WHEN cat.integration_ref LIKE 'PURCHASE-%' THEN 'Alış Yapıldı'
            ELSE cat.type
          END AS type_key,
          COUNT(DISTINCT cash_registers.id)
        FROM cash_registers
        JOIN cash_register_transactions cat ON cat.cash_register_id = cash_registers.id
        WHERE ${(baseConditions + typeConds).join(' AND ')}
        $transactionFilters
        GROUP BY type_key
      '''),
        parameters: typeParams,
      ),
      // Kullanıcılar
      _pool!.execute(
        Sql.named('''
        SELECT cat.user_name, COUNT(DISTINCT cash_registers.id)
        FROM cash_registers
        JOIN cash_register_transactions cat ON cat.cash_register_id = cash_registers.id
        WHERE ${(baseConditions + userConds).join(' AND ')}
        $transactionFilters
        GROUP BY cat.user_name
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

  Future<List<Map<String, dynamic>>> sonIslemleriGetir() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    // Fetch latest 50 transactions across all registers
    final result = await _pool!.execute(
      Sql.named(
        "SELECT t.*, cr.code as kasa_kodu, cr.name as kasa_adi FROM cash_register_transactions t LEFT JOIN cash_registers cr ON t.cash_register_id = cr.id WHERE COALESCE(t.company_id, '$_defaultCompanyId') = @companyId ORDER BY t.created_at DESC LIMIT 50",
      ),
      parameters: {'companyId': _companyId},
    );

    return result.map((row) {
      final map = row.toColumnMap();
      return _mapToTransaction(map);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> kasaIslemleriniGetir(
    int kasaId, {
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

    // Keyset Pagination Logic:
    // We use 'id' as the cursor because it's unique and indexed.
    // Since we order by created_at DESC (latest first), we roughly equate high IDs to new dates.
    // Ideally we should cursor on (created_at, id) tuple, but id is often sufficient for simple needs.
    // To range efficiently: WHERE id < @lastId ORDER BY id DESC LIMIT @limit
    // Note: If sorting by date is strict, we should use date in cursor.
    // For now, assuming ID correlates with time is safe enough for basic perf fix.

    String query =
        "SELECT t.*, cr.code as kasa_kodu, cr.name as kasa_adi FROM cash_register_transactions t LEFT JOIN cash_registers cr ON t.cash_register_id = cr.id WHERE t.cash_register_id = @kasaId AND COALESCE(t.company_id, '$_defaultCompanyId') = @companyId";
    Map<String, dynamic> params = {'kasaId': kasaId, 'companyId': _companyId};

    // Keyset Filter
    if (lastId != null) {
      query += ' AND t.id < @lastId';
      params['lastId'] = lastId;
    }

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      query += '''
           AND normalize_text(
             COALESCE(get_professional_label(t.type, 'cash'), '') || ' ' ||
             COALESCE(get_professional_label(t.type, 'cari'), '') || ' ' ||
             COALESCE(t.type, '') || ' ' ||
             COALESCE(TO_CHAR(t.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
             COALESCE(t.description, '') || ' ' ||
             COALESCE(t.location, '') || ' ' ||
             COALESCE(t.location_code, '') || ' ' ||
            COALESCE(t.location_name, '') || ' ' ||
            COALESCE(t.user_name, '') || ' ' ||
            COALESCE(CAST(t.amount AS TEXT), '') || ' ' ||
            COALESCE(t.integration_ref, '') || ' ' ||
            (CASE 
              WHEN t.integration_ref = 'opening_stock' OR t.description ILIKE '%Açılış%' THEN 'açılış stoğu'
              WHEN t.integration_ref LIKE '%production%' OR t.description ILIKE '%Üretim%' THEN 'üretim'
              WHEN t.integration_ref LIKE '%transfer%' OR t.description ILIKE '%Devir%' THEN 'devir'
              WHEN t.integration_ref LIKE '%shipment%' THEN 'sevkiyat'
              WHEN t.integration_ref LIKE '%collection%' THEN 'tahsilat'
              WHEN t.integration_ref LIKE '%payment%' THEN 'ödeme'
              WHEN t.integration_ref LIKE 'SALE-%' OR t.integration_ref LIKE 'RETAIL-%' THEN 'satış yapıldı'
              WHEN t.integration_ref LIKE 'PURCHASE-%' THEN 'alış yapıldı'
              ELSE ''
             END)
          ) LIKE @search
        ''';
      params['search'] = '%${_normalizeTurkish(aramaTerimi)}%';
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
        "SELECT DISTINCT type FROM cash_register_transactions WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId ORDER BY type ASC",
      ),
      parameters: {'companyId': _companyId},
    );

    return result.map((r) => r[0] as String).toList();
  }

  Future<List<KasaModel>> tumKasalariGetir() async {
    return kasalariGetir(sayfaBasinaKayit: 1000);
  }

  Future<void> kasaEkle(KasaModel kasa) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final result = await _pool!.execute(
      Sql.named('''
        INSERT INTO cash_registers (company_id, code, name, balance, currency, info1, info2, is_active, is_default, search_tags, matched_in_hidden)
        VALUES (@companyId, @code, @name, @balance, @currency, @info1, @info2, @is_active, @is_default, @search_tags, @matched_in_hidden)
        RETURNING id
      '''),
      parameters: {
        'companyId': _companyId,
        'code': kasa.kod,
        'name': kasa.ad,
        'balance': kasa.bakiye,
        'currency': kasa.paraBirimi,
        'info1': kasa.bilgi1,
        'info2': kasa.bilgi2,
        'is_active': kasa.aktifMi ? 1 : 0,
        'is_default': kasa.varsayilan ? 1 : 0,
        'search_tags': kasa.searchTags,
        'matched_in_hidden': kasa.matchedInHidden ? 1 : 0,
      },
    );

    // Yeni eklenen kasanın search_tags'ını güncelle
    if (result.isNotEmpty) {
      final newId = result.first[0] as int;
      await _updateSearchTags(newId);
    }
  }

  Future<void> kasaGuncelle(KasaModel kasa) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('''
        UPDATE cash_registers 
        SET code=@code, name=@name, balance=@balance, currency=@currency, 
            info1=@info1, info2=@info2, is_active=@is_active, is_default=@is_default, 
            search_tags=@search_tags, matched_in_hidden=@matched_in_hidden
        WHERE id=@id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
      '''),
      parameters: {
        'id': kasa.id,
        'companyId': _companyId,
        'code': kasa.kod,
        'name': kasa.ad,
        'balance': kasa.bakiye,
        'currency': kasa.paraBirimi,
        'info1': kasa.bilgi1,
        'info2': kasa.bilgi2,
        'is_active': kasa.aktifMi ? 1 : 0,
        'is_default': kasa.varsayilan ? 1 : 0,
        'search_tags': kasa.searchTags,
        'matched_in_hidden': kasa.matchedInHidden ? 1 : 0,
      },
    );

    // Güncellenen kasanın search_tags'ını güncelle
    await _updateSearchTags(kasa.id);
  }

  Future<void> kasaVarsayilanDegistir(int id, bool varsayilan) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      if (varsayilan) {
        // Eğer bu kasa varsayılan yapılıyorsa, diğerlerinin varsayılan özelliğini kaldır
        await session.execute(
          Sql.named(
            "UPDATE cash_registers SET is_default = 0 WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId",
          ),
          parameters: {'companyId': _companyId},
        );
      }

      await session.execute(
        Sql.named(
          "UPDATE cash_registers SET is_default = @val WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {
          'val': varsayilan ? 1 : 0,
          'id': id,
          'companyId': _companyId,
        },
      );
    });
  }

  Future<void> kasaSil(int id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // [2025 FIX] ÖNCE işlemleri bakiye düzelterek sil, SONRA kasayı sil
      // 1. Bu kasaya ait tüm işlemleri al
      final islemler = await session.execute(
        Sql.named(
          "SELECT id, amount, type, location_code, integration_ref FROM cash_register_transactions WHERE cash_register_id = @id AND COALESCE(company_id, '\$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      // 2. Her işlem için cari bakiyeyi düzelt
      final cariServis = CariHesaplarVeritabaniServisi();
      for (final row in islemler) {
        final int islemId = row[0] as int;
        final double amount = double.tryParse(row[1]?.toString() ?? '') ?? 0.0;
        final String type = row[2] as String? ?? 'Tahsilat';
        final String? locCode = row[3] as String?;

        // Cari entegrasyonunu geri al
        if (locCode != null && locCode.isNotEmpty) {
          final int? cariId = await cariServis.cariIdGetir(
            locCode,
            session: session,
          );
          if (cariId != null) {
            // Tahsilat (Alacak) siliniyorsa -> Alacak azalt
            // Ödeme (Borç) siliniyorsa -> Borç azalt
            bool wasBorc = type != 'Tahsilat';
            await cariServis.cariIslemSil(
              cariId,
              amount,
              wasBorc,
              kaynakTur: 'Kasa',
              kaynakId: islemId,
              session: session,
            );
          }
        }
      }

      // 3. Tüm işlemleri sil (bakiyeler zaten düzeltildi)
      await session.execute(
        Sql.named(
          "DELETE FROM cash_register_transactions WHERE cash_register_id = @id AND COALESCE(company_id, '\$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      // 4. Son olarak kasayı sil
      await session.execute(
        Sql.named(
          "DELETE FROM cash_registers WHERE id = @id AND COALESCE(company_id, '\$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );
    });
  }

  Future<void> kayitlariTemizle() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      await session.execute(
        Sql.named(
          "DELETE FROM cash_registers WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'companyId': _companyId},
      );
      await session.execute(
        Sql.named(
          "DELETE FROM cash_register_transactions WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'companyId': _companyId},
      );
    });
  }

  Future<String> siradakiKasaKodunuGetir({bool alfanumerik = true}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return alfanumerik ? 'KS-001' : '1';

    if (!alfanumerik) {
      final result = await _pool!.execute(
        Sql.named('''
          SELECT COALESCE(MAX(CAST(code AS BIGINT)), 0) 
	          FROM cash_registers
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
	        FROM cash_registers
	        WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId
	          AND code ~ '^KS-[0-9]+\$'
	      '''),
      parameters: {'companyId': _companyId},
    );

    final maxSuffix = int.tryParse(result.first[0]?.toString() ?? '0') ?? 0;
    final nextId = maxSuffix + 1;
    return 'KS-${nextId.toString().padLeft(3, '0')}';
  }

  Future<bool> kasaKoduVarMi(String kod, {int? haricId}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    String query =
        "SELECT COUNT(*) FROM cash_registers WHERE code = @code AND COALESCE(company_id, '$_defaultCompanyId') = @companyId";
    Map<String, dynamic> params = {'code': kod, 'companyId': _companyId};

    if (haricId != null) {
      query += ' AND id != @haricId';
      params['haricId'] = haricId;
    }

    final result = await _pool!.execute(Sql.named(query), parameters: params);

    return (result[0][0] as int) > 0;
  }

  Future<List<KasaModel>> kasaAra(
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
          FROM cash_registers
          WHERE code = @code
            AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
          ORDER BY id ASC
          LIMIT @limit
        '''),
        parameters: {'code': q, 'companyId': _companyId, 'limit': limit},
      );
      if (byCode.isNotEmpty) {
        return byCode.map((row) => _mapToKasaModel(row.toColumnMap())).toList();
      }
    } catch (_) {}

    return kasalariGetir(
      aramaKelimesi: q,
      sayfaBasinaKayit: limit,
      session: session,
    );
  }

  // Helpers
  KasaModel _mapToKasaModel(Map<String, dynamic> map) {
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

    return KasaModel(
      id: map['id'] as int,
      kod: map['code'] as String? ?? '',
      ad: map['name'] as String? ?? '',
      bakiye: double.tryParse(map['balance']?.toString() ?? '') ?? 0.0,
      paraBirimi: map['currency'] as String? ?? 'TRY',
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
      'kasaKodu': map['kasa_kodu'] ?? '',
      'kasaAdi': map['kasa_adi'] ?? '',
      'islem': map['type'] ?? '',
      'tarih': map['date'] ?? '',
      'yer': map['location'] ?? '',
      'yerKodu': map['location_code'] ?? '',
      'yerAdi': map['location_name'] ?? '',
      'aciklama': map['description'] ?? '',
      'kullanici': map['user_name'] ?? '',
      'tutar': double.tryParse(map['amount']?.toString() ?? '') ?? 0.0,
      'isIncoming': map['type'] == 'Tahsilat',
      'integration_ref': map['integration_ref'],
    };
  }

  // Cache for checked partitions to avoid redundant DB calls
  final Set<int> _checkedPartitions = {};
  bool _checkedDefaultPartition = false;

  /// Ensures that a partition exists for the given year.
  Future<void> _ensurePartitionExists(int year, {TxSession? session}) async {
    if (_pool == null && session == null) return;
    if (_checkedPartitions.contains(year) && _checkedDefaultPartition) return;

    try {
      await _createCashRegisterPartitions(year, session: session);
      _cachePartitionReady(year);
    } catch (e) {
      debugPrint('Partition check failed for $year: $e');
    }
  }

  Future<void> _createCashRegisterPartitions(
    int year, {
    TxSession? session,
  }) async {
    final executor = session ?? _pool!;
    if (_pool == null && session == null) return;

    final yearTable = 'cash_register_transactions_$year';
    final defaultTable = 'cash_register_transactions_default';

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
      return parent == 'cash_register_transactions';
    }

    // --- PROFESYONEL RECOVERY VE BAĞLAMA MANTIĞI ---

    // 1. DEFAULT Partition
    if (!await isAttached(defaultTable)) {
      if (await isTableExists(defaultTable)) {
        final currentParent = await getParentTable(defaultTable);
        debugPrint(
          '🛠️ Kasa default partition table $defaultTable detached or attached to $currentParent. Fixing...',
        );
        try {
          if (currentParent != null &&
              currentParent != 'cash_register_transactions') {
            await executor.execute(
              'ALTER TABLE $currentParent DETACH PARTITION $defaultTable',
            );
          }
          await executor.execute(
            'ALTER TABLE cash_register_transactions ATTACH PARTITION $defaultTable DEFAULT',
          );
        } catch (e) {
          debugPrint(
            '⚠️ Kasa default recovery failed: $e. Dropping as last resort...',
          );
          await executor.execute('DROP TABLE IF EXISTS $defaultTable CASCADE');
          await executor.execute(
            'CREATE TABLE $defaultTable PARTITION OF cash_register_transactions DEFAULT',
          );
        }
      } else {
        await executor.execute(
          'CREATE TABLE IF NOT EXISTS $defaultTable PARTITION OF cash_register_transactions DEFAULT',
        );
      }
    }

    // 2. Yıllık Partition
    if (!await isAttached(yearTable)) {
      final startStr = '$year-01-01';
      final endStr = '${year + 1}-01-01';

      if (await isTableExists(yearTable)) {
        final currentParent = await getParentTable(yearTable);
        debugPrint(
          '🛠️ Kasa partition table $yearTable detached or attached to $currentParent. Attaching for range $startStr - $endStr...',
        );
        try {
          if (currentParent != null &&
              currentParent != 'cash_register_transactions') {
            await executor.execute(
              'ALTER TABLE $currentParent DETACH PARTITION $yearTable',
            );
          }
          await executor.execute(
            "ALTER TABLE cash_register_transactions ATTACH PARTITION $yearTable FOR VALUES FROM ('$startStr') TO ('$endStr')",
          );
        } catch (e) {
          debugPrint(
            '⚠️ Kasa $yearTable recovery failed: $e. Investigating table type...',
          );
          // Tablo aslında partitioned olabilir (hatalı migration kalıntısı)
          final typeCheck = await executor.execute(
            Sql.named(
              "SELECT relkind::text FROM pg_class WHERE relname = @name",
            ),
            parameters: {'name': yearTable},
          );
          if (typeCheck.isNotEmpty &&
              typeCheck.first[0].toString().contains('p')) {
            debugPrint(
              '❌ $yearTable is already partitioned! Renaming to fix...',
            );
            await executor.execute(
              "ALTER TABLE $yearTable RENAME TO ${yearTable}_corrupt_${DateTime.now().millisecondsSinceEpoch}",
            );
          } else {
            debugPrint(
              '❌ $yearTable has data conflicts or schema mismatch. Dropping...',
            );
            await executor.execute('DROP TABLE IF EXISTS $yearTable CASCADE');
          }
          // Yeniden temiz bir şekilde oluştur
          await executor.execute(
            "CREATE TABLE IF NOT EXISTS $yearTable PARTITION OF cash_register_transactions FOR VALUES FROM ('$startStr') TO ('$endStr')",
          );
        }
      } else {
        try {
          await executor.execute(
            "CREATE TABLE IF NOT EXISTS $yearTable PARTITION OF cash_register_transactions FOR VALUES FROM ('$startStr') TO ('$endStr')",
          );
        } catch (e) {
          if (!e.toString().contains('already exists')) rethrow;
        }
      }
    }

    // İndeksler (Her zaman kontrol et)
    if (await isAttached(yearTable)) {
      await executor.execute(
        'CREATE INDEX IF NOT EXISTS idx_kasa_trans_${year}_basic ON $yearTable (cash_register_id, date)',
      );
    }
    if (await isAttached(defaultTable)) {
      await executor.execute(
        'CREATE INDEX IF NOT EXISTS idx_kasa_trans_default_basic ON $defaultTable (cash_register_id, date)',
      );
    }
  }

  /// [2025 ENHANCED] Partition-safe UPDATE with DELETE+INSERT fallback
  /// Bu metod UPDATE başarısız olduğunda DELETE + INSERT yapar.
  Future<void> _partitionSafeKasaTransUpdate(
    TxSession s, {
    required DateTime tarih,
    required String sql,
    required Map<String, dynamic> params,
  }) async {
    // [2025 FIX] Hem mevcut yıl hem hedef yılın partition'larını proaktif oluştur
    final int targetYear = tarih.year;
    final int currentYear = DateTime.now().year;

    // Proaktif partition oluşturma (session dışında)
    try {
      if (!_checkedPartitions.contains(targetYear)) {
        await _createCashRegisterPartitionsInSession(s, targetYear);
        _cachePartitionReady(targetYear);
      }
      if (currentYear != targetYear &&
          !_checkedPartitions.contains(currentYear)) {
        await _createCashRegisterPartitionsInSession(s, currentYear);
        _cachePartitionReady(currentYear);
      }
    } catch (e) {
      debugPrint('Proaktif partition oluşturma uyarısı: $e');
    }

    await s.execute(Sql.named('SAVEPOINT sp_update_partition_check'));
    try {
      await s.execute(Sql.named(sql), parameters: params);
      await s.execute(Sql.named('RELEASE SAVEPOINT sp_update_partition_check'));
    } catch (e) {
      await s.execute(
        Sql.named('ROLLBACK TO SAVEPOINT sp_update_partition_check'),
      );

      if (_isPartitionError(e)) {
        debugPrint(
          '⚠️ Partition hatası tespit edildi, DELETE+INSERT fallback uygulanıyor...',
        );

        try {
          // 1. Partition'ları oluştur
          await _createCashRegisterPartitionsInSession(s, targetYear);
          _cachePartitionReady(targetYear);

          // 2. Tekrar UPDATE dene
          await s.execute(Sql.named('SAVEPOINT sp_update_retry'));
          try {
            await s.execute(Sql.named(sql), parameters: params);
            await s.execute(Sql.named('RELEASE SAVEPOINT sp_update_retry'));
            return; // Başarılı
          } catch (retryError) {
            await s.execute(Sql.named('ROLLBACK TO SAVEPOINT sp_update_retry'));

            // UPDATE hala başarısız - DELETE + INSERT fallback
            if (_isPartitionError(retryError)) {
              debugPrint(
                '⚠️ UPDATE tekrar başarısız, DELETE+INSERT uygulanıyor...',
              );
              await _deleteAndReinsertTransaction(s, params, tarih);
            } else {
              rethrow;
            }
          }
        } catch (fallbackError) {
          debugPrint('DELETE+INSERT fallback hatası: $fallbackError');
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  /// Session içinde partition oluştur (SAVEPOINT kullanmadan)
  Future<void> _createCashRegisterPartitionsInSession(
    TxSession s,
    int year,
  ) async {
    final yearTable = 'cash_register_transactions_$year';
    final defaultTable = 'cash_register_transactions_default';

    // Partition mevcut mu kontrol et
    final checkResult = await s.execute(
      Sql.named('''
        SELECT 1 FROM pg_inherits i
        JOIN pg_class c ON c.oid = i.inhrelid
        JOIN pg_class p ON p.oid = i.inhparent
        WHERE p.relname = 'cash_register_transactions' AND c.relname = @child
        LIMIT 1
      '''),
      parameters: {'child': yearTable},
    );

    if (checkResult.isEmpty) {
      try {
        await s.execute('''
          CREATE TABLE IF NOT EXISTS $yearTable 
          PARTITION OF cash_register_transactions 
          FOR VALUES FROM ('$year-01-01') TO ('${year + 1}-01-01')
        ''');
        debugPrint('✅ Partition $yearTable oluşturuldu (session içi)');
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (!msg.contains('already exists') && !msg.contains('overlap')) {
          debugPrint('Partition oluşturma uyarısı: $e');
        }
      }
    }

    // Default partition kontrolü
    final defaultCheck = await s.execute(
      Sql.named('''
        SELECT 1 FROM pg_inherits i
        JOIN pg_class c ON c.oid = i.inhrelid
        JOIN pg_class p ON p.oid = i.inhparent
        WHERE p.relname = 'cash_register_transactions' AND c.relname = @child
        LIMIT 1
      '''),
      parameters: {'child': defaultTable},
    );

    if (defaultCheck.isEmpty) {
      try {
        await s.execute('''
          CREATE TABLE IF NOT EXISTS $defaultTable 
          PARTITION OF cash_register_transactions DEFAULT
        ''');
      } catch (e) {
        // Ignore - default zaten varsa hata verir
      }
    }
  }

  /// DELETE + INSERT fallback işlemi
  Future<void> _deleteAndReinsertTransaction(
    TxSession s,
    Map<String, dynamic> params,
    DateTime tarih,
  ) async {
    final int id = params['id'] as int;

    // 1. Mevcut kaydı al
    final existing = await s.execute(
      Sql.named("""
        SELECT * FROM cash_register_transactions 
        WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
      """),
      parameters: {'id': id, 'companyId': _companyId},
    );

    if (existing.isEmpty) {
      throw Exception('Güncellenecek kayıt bulunamadı: $id');
    }

    final oldRow = existing.first.toColumnMap();

    // 2. Eski kaydı sil
    await s.execute(
      Sql.named("""
        DELETE FROM cash_register_transactions 
        WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
      """),
      parameters: {'id': id, 'companyId': _companyId},
    );

    // 3. Yeni kaydı ekle (tüm eski değerleri koru, sadece güncellenen alanları değiştir)
    await s.execute(
      Sql.named('''
        INSERT INTO cash_register_transactions 
        (id, company_id, cash_register_id, date, description, amount, type, 
         location, location_code, location_name, user_name, integration_ref, created_at)
        VALUES 
        (@id, @companyId, @cash_register_id, @date, @description, @amount, @type,
         @location, @location_code, @location_name, @user_name, @integration_ref, @created_at)
      '''),
      parameters: {
        'id': id,
        'companyId': _companyId,
        'cash_register_id': oldRow['cash_register_id'],
        'date': DateFormat('yyyy-MM-dd HH:mm').format(tarih),
        'description': params['description'] ?? oldRow['description'],
        'amount': params['amount'] ?? oldRow['amount'],
        'type': oldRow['type'], // Type değişmez
        'location': params['location'] ?? oldRow['location'],
        'location_code': params['location_code'] ?? oldRow['location_code'],
        'location_name': params['location_name'] ?? oldRow['location_name'],
        'user_name': params['user_name'] ?? oldRow['user_name'],
        'integration_ref': oldRow['integration_ref'],
        'created_at': oldRow['created_at'],
      },
    );

    debugPrint('✅ DELETE+INSERT fallback başarılı: id=$id');
  }

  bool _isPartitionError(Object e) {
    final msg = e.toString().toLowerCase();
    // 23514: check_violation (no partition)
    // Partition keyword check as fallback
    return msg.contains('23514') ||
        msg.contains('partition') ||
        msg.contains('no partition') ||
        msg.contains('failing row contains');
  }

  void _cachePartitionReady(int year) {
    _checkedPartitions.add(year);
    _checkedDefaultPartition = true;
  }

  Future<int> kasaIslemEkle({
    required int kasaId,
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
    if (session == null) {
      if (!_isInitialized) await baslat();
      if (_pool == null) return -1;
    }

    // [2025 PROACTIVE PARTITIONING]
    await _ensurePartitionExists(tarih.year, session: session);

    int yeniIslemId = -1;

    // Eğer entegrasyon yapılacaksa ve ref yoksa oluştur
    String? finalRef = entegrasyonRef;
    if (cariEntegrasyonYap &&
        finalRef == null &&
        locationType != null &&
        [
          'bank',
          'cash',
          'credit_card',
          'personnel',
          'current_account',
        ].contains(locationType)) {
      finalRef = 'AUTO-TR-${DateTime.now().microsecondsSinceEpoch}';
    }

    // [FIX] Pre-fetch needed data BEFORE starting transaction to avoid "inside runTx" error
    KasaModel? currentKasa;
    KasaModel? targetKasa;
    if (cariEntegrasyonYap) {
      // ALWAYS pre-fetch current asset if integrating with Cari so we have Name/Code for the other side
      final kasalar = await kasalariGetir(kasaId: kasaId, session: session);
      currentKasa = kasalar.firstOrNull;
      // For recursive cash transfer
      if (locationType == 'cash' && cariKodu.isNotEmpty) {
        final hedefKasalar = await kasaAra(
          cariKodu,
          limit: 1,
          session: session,
        );
        if (hedefKasalar.isNotEmpty) {
          targetKasa = hedefKasalar.first;
        }
      }
    }

    // Transaction Logic Wrap
    Future<void> operation(TxSession s) async {
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
                "SELECT balance FROM cash_registers WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId FOR UPDATE",
              ),
              parameters: {'id': kasaId, 'companyId': _companyId},
            );

            if (bakiyeResult.isNotEmpty) {
              final double mevcutBakiye =
                  double.tryParse(bakiyeResult.first[0]?.toString() ?? '') ??
                  0.0;
              if (mevcutBakiye < tutar) {
                throw Exception(
                  'Yetersiz bakiye! Kasa bakiyesi: $mevcutBakiye, İşlem tutarı: $tutar. '
                  'Bu işlem kasayı eksi bakiyeye düşürecektir.',
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

      // 1. İşlemi kaydet (JIT Partitioning ile - SAVEPOINT kullanarak)
      Result islemResult;

      // Savepoint oluştur (Transaction abort olmasını engellemek için)
      await s.execute('SAVEPOINT sp_insert_partition_check');

      try {
        islemResult = await s.execute(
          Sql.named('''
            INSERT INTO cash_register_transactions 
            (company_id, cash_register_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref)
            VALUES 
            (@companyId, @kasaId, @date, @description, @amount, @type, @location, @location_code, @location_name, @user_name, @integration_ref)
            RETURNING id
          '''),
          parameters: {
            'companyId': _companyId,
            'kasaId': kasaId,
            'date': tarih, // DateTime nesnesi kullanmak daha sağlıklıdır
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
        // Başarılı olursa savepoint'i serbest bırak
        await s.execute('RELEASE SAVEPOINT sp_insert_partition_check');
      } catch (e) {
        // [FIX 25P02] Hata durumunda derhal Savepoint'e geri dön
        await s.execute('ROLLBACK TO SAVEPOINT sp_insert_partition_check');

        final String errorStr = e.toString();
        final bool isMissingTable =
            errorStr.contains('42P01') ||
            errorStr.toLowerCase().contains('does not exist');

        // [2025 FIX] Table/Partition Hatası yakala ve onar (Self-Healing)
        if (isMissingTable || _isPartitionError(e)) {
          debugPrint(
            '⚠️ Kasa Tablo/Partition hatası yakalandı, Self-Healing JIT onarımı... Yıl: ${tarih.year}',
          );

          if (isMissingTable) {
            debugPrint(
              '🚨 Kasa hareketleri tablosu eksik! Yeniden oluşturuluyor...',
            );
            await _tablolariOlustur();
          } else {
            // Partition oluştur (Session içinde)
            await _createCashRegisterPartitions(tarih.year, session: s);
          }
          _cachePartitionReady(tarih.year);

          // 4. Tekrar dene (Retry) - Yeni bir SAVEPOINT ile
          await s.execute('SAVEPOINT sp_insert_retry');
          try {
            islemResult = await s.execute(
              Sql.named('''
                INSERT INTO cash_register_transactions 
                (company_id, cash_register_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref)
                VALUES 
                (@companyId, @kasaId, @date, @description, @amount, @type, @location, @location_code, @location_name, @user_name, @integration_ref)
                RETURNING id
              '''),
              parameters: {
                'companyId': _companyId,
                'kasaId': kasaId,
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
            await s.execute('RELEASE SAVEPOINT sp_insert_retry');
          } catch (retryE) {
            await s.execute('ROLLBACK TO SAVEPOINT sp_insert_retry');
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      final int kasaIslemId = (islemResult.first[0] as int?) ?? 0;
      yeniIslemId = kasaIslemId;

      // 2. Kasa bakiyesini güncelle
      String updateQuery =
          'UPDATE cash_registers SET balance = balance + @amount WHERE id = @id';
      // [CUSTOM] Para Alındı da bakiyeyi artırır
      if (islemTuru != 'Tahsilat' && islemTuru != 'Para Alındı') {
        updateQuery =
            'UPDATE cash_registers SET balance = balance - @amount WHERE id = @id';
      }

      await s.execute(
        Sql.named(updateQuery),
        parameters: {'amount': tutar, 'id': kasaId},
      );

      // --- OTOMATİK ENTEGRASYONLAR ---
      if (cariEntegrasyonYap) {
        // A. Cari Hesap Entegrasyonu (Standart)
        if ((locationType == 'current_account' || locationType == null) &&
            cariKodu.isNotEmpty) {
          final cariServis = CariHesaplarVeritabaniServisi();
          final int? cariId = await cariServis.cariIdGetir(
            cariKodu,
            session: s,
          );

          if (cariId != null) {
            // Kasa Tahsilat -> Cari Alacak (isBorc: false)
            // Kasa Ödeme -> Cari Borç (isBorc: true)
            // [FIX] Para Alındı -> Tahsilat -> Alacak
            bool isBorc = islemTuru != 'Tahsilat' && islemTuru != 'Para Alındı';

            await cariServis.cariIslemEkle(
              cariId: cariId,
              tutar: tutar,
              isBorc: isBorc,
              islemTuru: 'Kasa',
              aciklama: aciklama,
              tarih: tarih,
              kullanici: kullanici,
              kaynakId: kasaIslemId,
              kaynakAdi: currentKasa?.ad ?? 'Kasa',
              kaynakKodu: currentKasa?.kod ?? '',
              entegrasyonRef: finalRef, // Referans buraya eklendi
              session: s,
            );
          }
        }
        // B. Banka Entegrasyonu
        else if (locationType == 'bank') {
          final bankaServis = BankalarVeritabaniServisi();
          final bankalar = await bankaServis.bankaAra(
            cariKodu,
            limit: 1,
            session: s,
          );
          if (bankalar.isNotEmpty) {
            // Kasa Tahsilat (Para Buraya Geldi) -> Bankadan Çıktı (Ödeme)
            // Kasa Ödeme (Para Buradan Gitti) -> Bankaya Girdi (Tahsilat)
            String karsiIslemTuru =
                (islemTuru == 'Tahsilat' || islemTuru == 'Para Alındı')
                ? 'Ödeme'
                : 'Tahsilat';

            await bankaServis.bankaIslemEkle(
              bankaId: bankalar.first.id,
              tutar: tutar,
              islemTuru: karsiIslemTuru,
              aciklama: aciklama,
              tarih: tarih,
              cariTuru: 'Kasa',
              cariKodu: currentKasa?.kod ?? '',
              cariAdi: currentKasa?.ad ?? '',
              kullanici: kullanici,
              cariEntegrasyonYap: false, // Döngüyü engelle
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
            // Kasa Tahsilat (Para Buraya Geldi) -> Karttan Çekildi (Çıkış/Harcama)
            // Kasa Ödeme (Para Buradan Gitti) -> Karta Yatırıldı (Giriş/İade)
            String karsiIslemTuru =
                (islemTuru == 'Tahsilat' || islemTuru == 'Para Alındı')
                ? 'Çıkış'
                : 'Giriş';

            await kartServis.krediKartiIslemEkle(
              krediKartiId: kartlar.first.id,
              tutar: tutar,
              islemTuru: karsiIslemTuru,
              aciklama: aciklama,
              tarih: tarih,
              cariTuru: 'Kasa',
              cariKodu: currentKasa?.kod ?? '',
              cariAdi: currentKasa?.ad ?? '',
              kullanici: kullanici,
              cariEntegrasyonYap: false,
              entegrasyonRef: finalRef,
              session: s,
            );
          }
        }
        // D. Kasa Transferi (Virman)
        else if (locationType == 'cash') {
          if (targetKasa != null) {
            String karsiIslemTuru =
                (islemTuru == 'Tahsilat' || islemTuru == 'Para Alındı')
                ? 'Ödeme'
                : 'Tahsilat';

            // Insert Target Transaction
            // Burada da aynı JIT Partition logic uygulanabilir ama basitlik için normal insert
            // Eğer burası patlarsa rethrow olur ve dıştaki partition logic çalışmaz.
            // O yüzden buraya da basit bir try-catch koymak mantıklı ama kod bloğu uzar.
            // Şimdilik ana kasa işlemi partition'ı hallederse diğerleri de muhtemelen aynı yıl içindedir.
            // Fakat transfer farklı yıllarda olabilir mi? Hayır transfer aynı anda olur.
            // Yani yukarıdaki JIT çalışırsa `cash_register_transactions` tablosunun partition'ı oluşur ve burası da çalışır.
            await s.execute(
              Sql.named('''
                INSERT INTO cash_register_transactions 
                (company_id, cash_register_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref)
                VALUES 
                (@companyId, @kasaId, @date, @description, @amount, @type, @location, @location_code, @location_name, @user_name, @integration_ref)
              '''),
              parameters: {
                'companyId': _companyId,
                'kasaId': targetKasa.id,
                'date': DateFormat('yyyy-MM-dd HH:mm').format(tarih),
                'description': aciklama,
                'amount': tutar,
                'type': karsiIslemTuru,
                'location': 'Kasa',
                'location_code': currentKasa?.kod ?? '',
                'location_name': currentKasa?.ad ?? '',
                'user_name': kullanici,
                'integration_ref': finalRef,
              },
            );

            // Update Target Balance
            String targetUpdateQuery =
                'UPDATE cash_registers SET balance = balance + @amount WHERE id = @id';
            if (karsiIslemTuru != 'Tahsilat') {
              targetUpdateQuery =
                  'UPDATE cash_registers SET balance = balance - @amount WHERE id = @id';
            }
            await s.execute(
              Sql.named(targetUpdateQuery),
              parameters: {'amount': tutar, 'id': targetKasa.id},
            );
          }
        }
        // E. Personel Entegrasyonu
        else if (locationType == 'personnel') {
          String personelIslemTuru =
              (islemTuru == 'Tahsilat' || islemTuru == 'Para Alındı')
              ? 'credit'
              : 'payment';

          await PersonelIslemleriVeritabaniServisi().entegrasyonKaydiEkle(
            kullaniciId: cariKodu, // Personel ID
            tutar: tutar,
            tarih: tarih,
            aciklama: aciklama,
            islemTuru: personelIslemTuru,
            kaynakTuru: 'Kasa',
            kaynakId: kasaId.toString(),
            ref: finalRef,
            session: s,
          );
        }
        // F. Gelir/Gider Entegrasyonu (Standalone - Çapraz modül gerektirmez)
        else if (locationType == 'income' || locationType == 'other') {
          debugPrint(
            '📝 Kasa $locationType işlemi kaydedildi: $tutar ${islemTuru == "Tahsilat" ? "+" : "-"}',
          );
        }
      }
    }

    if (session != null) {
      await operation(session);
      if (yeniIslemId != -1) {
        await _updateSearchTags(kasaId, session: session);
      }
    } else {
      await _pool!.runTx((s) async {
        await operation(s);
        if (yeniIslemId != -1) {
          await _updateSearchTags(kasaId, session: s);
        }
      });
    }

    return yeniIslemId;
  }

  // --- PARTITIONING HELPERS ---

  /// [2025 SMART UPDATE] Kasa İşlemi Güncelleme (Silmeden)
  Future<void> kasaIslemGuncelleByRef({
    required String ref,
    required double tutar,
    required String islemTuru, // 'Tahsilat', 'Ödeme'
    required String aciklama,
    required DateTime tarih,
    String? kullanici,
    TxSession? session,
    bool retry = true,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // [2025 PROACTIVE PARTITIONING]
    await _ensurePartitionExists(tarih.year);

    Future<void> operation(TxSession s) async {
      // 1. Mevcut kaydı bul
      final existingRows = await s.execute(
        Sql.named(
          "SELECT id, cash_register_id, amount, type FROM cash_register_transactions WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId LIMIT 1",
        ),
        parameters: {'ref': ref, 'companyId': _companyId},
      );

      if (existingRows.isEmpty) return;

      final row = existingRows.first;
      final int transId = row[0] as int;
      final int kasaId = row[1] as int;
      final double oldAmount = double.tryParse(row[2]?.toString() ?? '') ?? 0.0;
      final String oldType = row[3] as String; // 'Tahsilat' or 'Ödeme'

      // 2. Bakiyeyi Düzelt (Eski işlemin etkisini geri al)
      // Tahsilat (+): Bakiyeden düş
      // Ödeme (-): Bakiyeye ekle
      String revertQuery =
          'UPDATE cash_registers SET balance = balance - @amount WHERE id = @id';
      if (oldType != 'Tahsilat') {
        revertQuery =
            'UPDATE cash_registers SET balance = balance + @amount WHERE id = @id';
      }
      await s.execute(
        Sql.named(revertQuery),
        parameters: {'amount': oldAmount, 'id': kasaId},
      );

      // 3. Yeni Bakiyeyi İşle
      // Tahsilat (+): Bakiyeye ekle
      // Ödeme (-): Bakiyeden düş
      String applyQuery =
          'UPDATE cash_registers SET balance = balance + @amount WHERE id = @id';
      if (islemTuru != 'Tahsilat') {
        applyQuery =
            'UPDATE cash_registers SET balance = balance - @amount WHERE id = @id';
      }
      await s.execute(
        Sql.named(applyQuery),
        parameters: {'amount': tutar, 'id': kasaId},
      );

      // 4. İşlemi Güncelle
      await _partitionSafeKasaTransUpdate(
        s,
        tarih: tarih,
        sql: '''
          UPDATE cash_register_transactions 
          SET date = @tarih,
              description = @aciklama,
              amount = @tutar,
              type = @type,
              user_name = COALESCE(@kullanici, user_name)
          WHERE id = @id
        ''',
        params: {
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
      try {
        await _pool!.runTx((s) => operation(s));
      } catch (e) {
        if (retry && _isPartitionError(e)) {
          await _createCashRegisterPartitions(tarih.year);
          _cachePartitionReady(tarih.year);
          return kasaIslemGuncelleByRef(
            ref: ref,
            tutar: tutar,
            islemTuru: islemTuru,
            aciklama: aciklama,
            tarih: tarih,
            kullanici: kullanici,
            session: null,
            retry: false,
          );
        }
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>?> kasaIslemGetir(int id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    final result = await _pool!.execute(
      Sql.named(
        "SELECT * FROM cash_register_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
      ),
      parameters: {'id': id, 'companyId': _companyId},
    );

    if (result.isEmpty) return null;

    // Fetch register name/code for mapping consistency if needed, but for edit we mostly need raw data
    // Let's use existing _mapToTransaction but we might miss joined fields if we don't join.
    // For editing, we typically need the raw fields.
    // However, the existing _mapToTransaction expects 'kasa_kodu' etc.
    // Let's do a JOIN like others.
    final resultWithJoin = await _pool!.execute(
      Sql.named(
        "SELECT t.*, cr.code as kasa_kodu, cr.name as kasa_adi FROM cash_register_transactions t LEFT JOIN cash_registers cr ON t.cash_register_id = cr.id WHERE t.id = @id AND COALESCE(t.company_id, '$_defaultCompanyId') = @companyId",
      ),
      parameters: {'id': id, 'companyId': _companyId},
    );
    if (resultWithJoin.isEmpty) return null;

    return _mapToTransaction(resultWithJoin.first.toColumnMap());
  }

  Future<void> kasaIslemSil(
    int id, {
    bool skipLinked = false,
    TxSession? session,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    String? entegrasyonRef;

    Future<void> operation(TxSession s) async {
      // 1. Get transaction to revert balance
      final result = await s.execute(
        Sql.named(
          "SELECT * FROM cash_register_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      if (result.isEmpty) return;

      final row = result.first.toColumnMap();
      entegrasyonRef = row['integration_ref'] as String?;
      final double amount =
          double.tryParse(row['amount']?.toString() ?? '') ?? 0.0;
      final String type = row['type'] as String? ?? 'Tahsilat';
      final int registerId = row['cash_register_id'] as int;

      // 2. Revert Balance
      // If it was Tahsilat (Income), we subtract amount.
      // If it was Ödeme (Outcome), we add amount.
      String updateQuery =
          'UPDATE cash_registers SET balance = balance - @amount WHERE id = @id';
      if (type != 'Tahsilat') {
        updateQuery =
            'UPDATE cash_registers SET balance = balance + @amount WHERE id = @id';
      }

      await s.execute(
        Sql.named(updateQuery),
        parameters: {'amount': amount, 'id': registerId},
      );

      // 3. Delete Transaction
      await s.execute(
        Sql.named(
          "DELETE FROM cash_register_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      // --- ENTEGRASYON: CARİ HESAP (Geri Al) ---
      if (skipLinked) return;
      final String locCode = row['location_code'] as String? ?? '';

      if (locCode.isNotEmpty) {
        final cariServis = CariHesaplarVeritabaniServisi();
        final int? cariId = await cariServis.cariIdGetir(locCode, session: s);

        if (cariId != null) {
          // [2026 CRITICAL FIX] Önce bu kaynak için gerçekten cari işlem var mı kontrol et
          // Çek tahsilatı gibi işlemlerde cariEntegrasyonYap: false kullanılıyor,
          // bu yüzden silinirken de cari işlem silmeye çalışılmamalı
          final existingCariTx = await s.execute(
            Sql.named('''
              SELECT id FROM current_account_transactions 
              WHERE source_type = 'Kasa' AND source_id = @sourceId
              LIMIT 1
            '''),
            parameters: {'sourceId': id},
          );

          if (existingCariTx.isNotEmpty) {
            // Tahsilat (Alacak) siliniyorsa -> Alacak azalt (isBorc: false)
            bool wasBorc = type != 'Tahsilat';
            await cariServis.cariIslemSil(
              cariId,
              amount,
              wasBorc,
              kaynakTur: 'Kasa',
              kaynakId: id,
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
      await entegrasyonBaglantiliIslemleriSil(
        entegrasyonRef!,
        haricKasaIslemId: id,
        session: session,
      );
    }
  }

  Future<void> kasaIslemGuncelle({
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
    bool retry = true,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // [2025 PROACTIVE PARTITIONING]
    await _ensurePartitionExists(tarih.year);

    String? entegrasyonRef;

    Future<void> operation(TxSession s) async {
      // 1. Get old transaction
      final oldResult = await s.execute(
        Sql.named(
          "SELECT * FROM cash_register_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      if (oldResult.isEmpty) return;
      final oldRow = oldResult.first.toColumnMap();
      entegrasyonRef = oldRow['integration_ref'] as String?;
      final double oldAmount =
          double.tryParse(oldRow['amount']?.toString() ?? '') ?? 0.0;
      final String oldType = oldRow['type'] as String? ?? 'Tahsilat';
      final String oldLocCode = oldRow['location_code'] as String? ?? '';
      final int registerId = oldRow['cash_register_id'] as int;

      // 2. Revert Old Balance
      String revertQuery =
          'UPDATE cash_registers SET balance = balance - @amount WHERE id = @id';
      if (oldType != 'Tahsilat') {
        revertQuery =
            'UPDATE cash_registers SET balance = balance + @amount WHERE id = @id';
      }
      await s.execute(
        Sql.named(revertQuery),
        parameters: {'amount': oldAmount, 'id': registerId},
      );

      // --- ENTEGRASYON: CARİ HESAP ---
      if (!skipLinked) {
        final cariServis = CariHesaplarVeritabaniServisi();

        int? oldCariId;
        if (oldLocCode.isNotEmpty) {
          oldCariId = await cariServis.cariIdGetir(oldLocCode, session: s);
        }

        int? newCariId;
        if (cariKodu.isNotEmpty) {
          newCariId = await cariServis.cariIdGetir(cariKodu, session: s);
        }

        // [2025 SMART UPDATE] Cari Değişmediyse ve Ref Varsa -> Update
        if (oldCariId != null &&
            newCariId != null &&
            oldCariId == newCariId &&
            (entegrasyonRef ?? '').isNotEmpty) {
          // Tahsilat (Giriş) -> Alacak (isBorc: false)
          // Ödeme (Çıkış) -> Borç (isBorc: true)
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
                kaynakTur: 'Kasa',
                kaynakId: id,
                session: s,
              );
            }
          }

          if (newCariId != null &&
              (locationType == 'current_account' || locationType == null)) {
            // Kasa bilgilerini çek
            final kasaResult = await s.execute(
              Sql.named("SELECT code, name FROM cash_registers WHERE id = @id"),
              parameters: {'id': registerId},
            );
            String kasaAdi = '';
            String kasaKodu = '';
            if (kasaResult.isNotEmpty) {
              final kasaRow = kasaResult.first.toColumnMap();
              kasaKodu = kasaRow['code'] as String? ?? '';
              kasaAdi = kasaRow['name'] as String? ?? '';
            }

            bool isBorc = oldType != 'Tahsilat';

            await cariServis.cariIslemEkle(
              cariId: newCariId,
              tutar: tutar,
              isBorc: isBorc,
              islemTuru: 'Kasa',
              aciklama: aciklama,
              tarih: tarih,
              kullanici: kullanici,
              kaynakId: id,
              kaynakAdi: kasaAdi,
              kaynakKodu: kasaKodu,
              entegrasyonRef: entegrasyonRef,
              session: s,
            );
          }
        }
      }

      // 3. Update Transaction Record
      await _partitionSafeKasaTransUpdate(
        s,
        tarih: tarih,
        sql: '''
          UPDATE cash_register_transactions 
          SET date=@date, description=@description, amount=@amount, 
              location=@location, location_code=@location_code, location_name=@location_name, user_name=@user_name
          WHERE id=@id
        ''',
        params: {
          'id': id,
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
          'UPDATE cash_registers SET balance = balance + @amount WHERE id = @id';
      if (oldType != 'Tahsilat') {
        applyQuery =
            'UPDATE cash_registers SET balance = balance - @amount WHERE id = @id';
      }
      await s.execute(
        Sql.named(applyQuery),
        parameters: {'amount': tutar, 'id': registerId},
      );
    }

    if (session != null) {
      await operation(session);
    } else {
      try {
        await _pool!.runTx((s) => operation(s));
      } catch (e) {
        if (retry && _isPartitionError(e)) {
          await _createCashRegisterPartitions(tarih.year);
          _cachePartitionReady(tarih.year);
          return kasaIslemGuncelle(
            id: id,
            tutar: tutar,
            aciklama: aciklama,
            tarih: tarih,
            cariTuru: cariTuru,
            cariKodu: cariKodu,
            cariAdi: cariAdi,
            kullanici: kullanici,
            skipLinked: skipLinked,
            session: null,
            retry: false,
          );
        }
        rethrow;
      }
    }

    if (!skipLinked && (entegrasyonRef ?? '').isNotEmpty) {
      await entegrasyonBaglantiliIslemleriGuncelle(
        entegrasyonRef: entegrasyonRef!,
        tutar: tutar,
        aciklama: aciklama,
        tarih: tarih,
        kullanici: kullanici,
        haricKasaIslemId: id,
        session: session,
      );
    }
  }

  Future<void> entegrasyonBaglantiliIslemleriSil(
    String entegrasyonRef, {
    required int haricKasaIslemId,
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

    // 1) Diğer kasa işlemleri
    final cashRows = await runQuery(
      "SELECT id FROM cash_register_transactions WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId AND id != @id",
      params: {
        'ref': entegrasyonRef,
        'companyId': _companyId,
        'id': haricKasaIslemId,
      },
    );
    for (final r in cashRows) {
      final int otherId = r[0] as int;
      await kasaIslemSil(otherId, skipLinked: true, session: session);
    }

    // 2) Banka işlemleri
    final bankRows = await runQuery(
      "SELECT id FROM bank_transactions WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
      params: {'ref': entegrasyonRef, 'companyId': _companyId},
    );
    for (final r in bankRows) {
      final int bankId = r[0] as int;
      await BankalarVeritabaniServisi().bankaIslemSil(
        bankId,
        skipLinked: true,
        session: session, // Bank allows session now
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
    required int haricKasaIslemId,
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

    // Diğer kasa işlemleri
    final cashRows = await runQuery(
      "SELECT id, location, location_code, location_name FROM cash_register_transactions WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId AND id != @id",
      params: {
        'ref': entegrasyonRef,
        'companyId': _companyId,
        'id': haricKasaIslemId,
      },
    );
    for (final r in cashRows) {
      final int otherId = r[0] as int;
      await kasaIslemGuncelle(
        id: otherId,
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

    // Banka işlemleri
    final bankRows = await runQuery(
      "SELECT id, location, location_code, location_name FROM bank_transactions WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
      params: {'ref': entegrasyonRef, 'companyId': _companyId},
    );
    for (final r in bankRows) {
      await BankalarVeritabaniServisi().bankaIslemGuncelle(
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

    // Kredi kartı işlemleri
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
