import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import '../sayfalar/kredikartlari/modeller/kredi_karti_model.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'cari_hesaplar_veritabani_servisi.dart';
import 'kasalar_veritabani_servisi.dart';
import 'bankalar_veritabani_servisi.dart';
import 'personel_islemleri_veritabani_servisi.dart';
import 'oturum_servisi.dart';
import 'lisans_yazma_koruma.dart';
import 'lite_kisitlari.dart';
import 'veritabani_yapilandirma.dart';
import 'ayarlar_veritabani_servisi.dart';

class KrediKartlariVeritabaniServisi {
  static final KrediKartlariVeritabaniServisi _instance =
      KrediKartlariVeritabaniServisi._internal();
  factory KrediKartlariVeritabaniServisi() => _instance;
  KrediKartlariVeritabaniServisi._internal();

  Pool? _pool;
  bool _isInitialized = false;
  String? _initializedDatabase;
  String? _initializingDatabase;
  static const String _searchTagsVersionPrefix = 'v6';

  Completer<void>? _initCompleter;

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

    _initCompleter = Completer<void>();
    _initializingDatabase = targetDatabase;

    try {
      _pool = LisansKorumaliPool(
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

      await _tablolariOlustur();
      _isInitialized = true;
      _initializedDatabase = targetDatabase;
      _initializingDatabase = null;
      debugPrint(
        'KrediKartlariVeritabaniServisi: Pool connection established successfully.',
      );
      _initCompleter!.complete();
    } catch (e) {
      debugPrint('KrediKartlariVeritabaniServisi: Connection error: $e');
      try {
        await _pool?.close();
      } catch (_) {}
      _pool = null;
      _isInitialized = false;
      _initializedDatabase = null;
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.completeError(e);
        _initCompleter = null;
      }
      _initializingDatabase = null;
    }
  }

  /// Bakım Modu: Arama indekslerini manuel tetikler
  Future<void> bakimModuCalistir() async {
    await verileriIndeksle(forceUpdate: true);
  }

  /// Entegrasyon referansına sahip tüm işlemleri siler
  Future<void> entegrasyonBaglantiliIslemleriSil(
    String entegrasyonRef, {
    required int haricKrediKartiIslemId, // Zorunlu yapıldı hiyerarşi için
    TxSession? session,
    bool silinecekCariyiEtkilesin = true, // KRITIK PARAMETRE
  }) async {
    if (!_isInitialized) await baslat();
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

    Future<void> operation(TxSession s) async {
      // 1. İlgili kredi kartı işlemlerini bul ve sil (Kendi tablosu)
      String query =
          "SELECT * FROM credit_card_transactions WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId";
      final Map<String, dynamic> params = {
        'ref': entegrasyonRef,
        'companyId': _companyId,
      };

      if (haricKrediKartiIslemId != -1) {
        query += " AND id != @haricId";
        params['haricId'] = haricKrediKartiIslemId;
      }

      final results = await s.execute(Sql.named(query), parameters: params);

      for (final row in results) {
        final map = row.toColumnMap();
        final int id = map['id'];
        final int cardId = map['credit_card_id'];
        final double amount =
            double.tryParse(map['amount']?.toString() ?? '') ?? 0.0;
        final String type = map['type'] ?? '';

        // 2. Bakiyeyi geri al
        String updateQuery =
            'UPDATE credit_cards SET balance = balance - @amount WHERE id = @id';
        if (type == 'Çıkış' || type == 'Harcama') {
          updateQuery =
              'UPDATE credit_cards SET balance = balance + @amount WHERE id = @id';
        }

        await s.execute(
          Sql.named(updateQuery),
          parameters: {'amount': amount, 'id': cardId},
        );

        // 3. İşlemi sil
        await s.execute(
          Sql.named("DELETE FROM credit_card_transactions WHERE id = @id"),
          parameters: {'id': id},
        );
      }

      if (silinecekCariyiEtkilesin) {
        // 4) Cari Hesap işlemleri
        await CariHesaplarVeritabaniServisi().cariIslemSilByRef(
          entegrasyonRef,
          session: s,
        );

        // Personel işlemleri
        await PersonelIslemleriVeritabaniServisi().entegrasyonKaydiSil(
          entegrasyonRef,
          session: s,
        );
      }
    }

    if (session != null) {
      await operation(session);
    } else {
      await _pool!.runTx((s) => operation(s));
    }

    // 4. Diğer modüllerdeki bağlı işlemleri sil
    // Kasa işlemleri
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

    // Banka işlemleri
    final bankRows = await runQuery(
      "SELECT id FROM bank_transactions WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
      params: {'ref': entegrasyonRef, 'companyId': _companyId},
    );
    for (final r in bankRows) {
      final int bankId = r[0] as int;
      await BankalarVeritabaniServisi().bankaIslemSil(
        bankId,
        skipLinked: true,
        session: session,
      );
    }

    // Personel işlemleri
    await PersonelIslemleriVeritabaniServisi().entegrasyonKaydiSil(
      entegrasyonRef,
      session: session,
    );

    // Cari Hesap Entegrasyonlarını temizle (Hayalet Bakiye Önle)
    await CariHesaplarVeritabaniServisi().cariIslemSilByRef(
      entegrasyonRef,
      session: session,
    );
  }

  Future<void> _tablolariOlustur() async {
    if (_pool == null) return;

    // [2026 FIX] Hyper-Optimized Turkish Normalization & Professional Labels (ALWAYS UPDATE FIRST)
    try {
      // 1. Label Fonksiyonu
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

              -- KREDI KARTI (Corrected Logic)
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

    // Create Credit Cards Table
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS credit_cards (
        id SERIAL PRIMARY KEY,
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
        search_tags TEXT,
        matched_in_hidden INTEGER DEFAULT 0
      )
    ''');

    // [2025 HYPERSCALE] Create Credit Card Transactions Table - Native Partitioning Support
    try {
      // 1. Ana tablonun durumunu kontrol et
      final tableCheck = await _pool!.execute(
        "SELECT relkind::text FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'credit_card_transactions'",
      );

      bool isPartitioned = false;
      bool tableExists = tableCheck.isNotEmpty;

      if (tableExists) {
        final String relkind = tableCheck.first[0].toString().toLowerCase();
        isPartitioned = relkind.contains('p');
        debugPrint(
          'Kredi Kartı Hareketleri Tablo Durumu: tableExists=true, relkind=$relkind, isPartitioned=$isPartitioned',
        );
      }

      // 2. Eğer tablo YOK - yeni partitioned tablo oluştur
      if (!tableExists) {
        debugPrint(
          'Kredi kartı hareketleri tablosu oluşturuluyor (Partitioned)...',
        );
        await _pool!.execute('''
          CREATE TABLE IF NOT EXISTS credit_card_transactions (
            id SERIAL,
            company_id TEXT,
            credit_card_id INTEGER,
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
          '⚠️ Kredi kartı hareketleri tablosu regular modda. Partitioned yapıya geçiliyor...',
        );

        // Eski tabloyu yeniden adlandır
        await _pool!.execute(
          'DROP TABLE IF EXISTS credit_card_transactions_old CASCADE',
        );
        await _pool!.execute(
          'ALTER TABLE credit_card_transactions RENAME TO credit_card_transactions_old',
        );

        // [FIX] Rename sequence if it exists to avoid collision
        try {
          await _pool!.execute(
            'ALTER SEQUENCE IF EXISTS credit_card_transactions_id_seq RENAME TO credit_card_transactions_old_id_seq',
          );
        } catch (_) {}

        // Yeni partitioned tabloyu oluştur
        await _pool!.execute('''
          CREATE TABLE credit_card_transactions (
            id SERIAL,
            company_id TEXT,
            credit_card_id INTEGER,
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

        // Sadece cari yılı bekle (HIZ İÇİN)
        await _createCreditCardPartitions(currentYear);

        // Arka Plan İşlemleri: İndeksler, Triggerlar ve Diğer Yıllar
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
                  await _createCreditCardPartitions(year);
                }

                // DEFAULT partition
                await _pool!.execute('''
                CREATE TABLE IF NOT EXISTS credit_card_transactions_default 
                PARTITION OF credit_card_transactions DEFAULT
              ''');
              }
            } catch (e) {
              debugPrint('Kredi kartı arka plan partition hatası: $e');
            }
          }());
        }
      }

      // 5. _old tablosu varsa migration yap
      final oldTableCheck = await _pool!.execute(
        "SELECT 1 FROM pg_class WHERE relname = 'credit_card_transactions_old' LIMIT 1",
      );

      if (oldTableCheck.isNotEmpty) {
        debugPrint(
          '💾 Eski kredi kartı hareketleri yeni bölümlere aktarılıyor...',
        );
        try {
          await _pool!.execute('''
            INSERT INTO credit_card_transactions (
              id, company_id, credit_card_id, date, description, amount, type, 
              location, location_code, location_name, user_name, integration_ref, created_at
            )
            SELECT 
              id, company_id, credit_card_id, COALESCE(date, created_at, CURRENT_TIMESTAMP), 
              description, amount, type, location, location_code, location_name, 
              user_name, integration_ref, created_at
            FROM credit_card_transactions_old
            ON CONFLICT (id, date) DO NOTHING
          ''');

          // Sequence güncelle (Serial için kritik)
          final maxIdResult = await _pool!.execute(
            'SELECT COALESCE(MAX(id), 0) FROM credit_card_transactions',
          );
          final maxId =
              int.tryParse(maxIdResult.first[0]?.toString() ?? '0') ?? 0;
          if (maxId > 0) {
            await _pool!.execute(
              "SELECT setval(pg_get_serial_sequence('credit_card_transactions', 'id'), $maxId)",
            );
          }

          // Migration başarılı - _old tablosunu sil
          await _pool!.execute(
            'DROP TABLE credit_card_transactions_old CASCADE',
          );
          debugPrint('✅ Kredi kartı hareketleri başarıyla bölümlendirildi.');
        } catch (e) {
          debugPrint('❌ Migration hatası (Kredi Kartı): $e');
        }
      }
    } catch (e) {
      debugPrint('Kredi kartı hareketleri ana yapı kurulum hatası: $e');
      rethrow;
    }

    // [2025 JET] Kritik olmayan tüm işlemler arka plana
    if (_config.allowBackgroundDbMaintenance) {
      unawaited(() async {
        try {
        await _pool!.execute(
          'ALTER TABLE credit_cards ADD COLUMN IF NOT EXISTS company_id TEXT',
        );
        await _pool!.execute(
          'ALTER TABLE credit_card_transactions ADD COLUMN IF NOT EXISTS company_id TEXT',
        );
        await _pool!.execute(
          'ALTER TABLE credit_card_transactions ADD COLUMN IF NOT EXISTS integration_ref TEXT',
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

              -- KREDI KARTI
              IF ctx = 'credit_card' OR ctx = 'kredi_karti' THEN
                  IF t ~ 'tahsilat' OR t ~ 'collection' THEN RETURN 'K.Kartı Tahsilat';
                  ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'payment' THEN RETURN 'K.Kartı Ödeme';
                  ELSIF t ~ 'harcama' OR t ~ 'gider' THEN RETURN 'K.Kartı Harcama';
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
        await _pool!.execute('CREATE EXTENSION IF NOT EXISTS pg_trgm');
        await _pool!.execute(
          'CREATE INDEX IF NOT EXISTS idx_credit_cards_search_tags_gin ON credit_cards USING GIN (search_tags gin_trgm_ops)',
        );
        await _pool!.execute(
          'CREATE INDEX IF NOT EXISTS idx_cct_integration_ref ON credit_card_transactions (integration_ref)',
        );
        await _pool!.execute(
          'CREATE INDEX IF NOT EXISTS idx_cct_credit_card_id ON credit_card_transactions (credit_card_id)',
        );
        await _pool!.execute(
          'CREATE INDEX IF NOT EXISTS idx_cct_date ON credit_card_transactions (date)',
        );
        await _pool!.execute(
          'CREATE INDEX IF NOT EXISTS idx_cct_type ON credit_card_transactions (type)',
        );
        await _pool!.execute(
          'CREATE INDEX IF NOT EXISTS idx_cct_created_at ON credit_card_transactions (created_at)',
        );

        // Trigger
        await _pool!.execute('''
          CREATE OR REPLACE FUNCTION update_credit_card_search_tags() RETURNS TRIGGER AS \$\$
          BEGIN
            UPDATE credit_cards cc
            SET search_tags = normalize_text(
              '$_searchTagsVersionPrefix ' ||
              COALESCE(cc.code, '') || ' ' ||
              COALESCE(cc.name, '') || ' ' ||
              COALESCE(cc.currency, '') || ' ' ||
              COALESCE(cc.branch_code, '') || ' ' ||
              COALESCE(cc.branch_name, '') || ' ' ||
              COALESCE(cc.account_no, '') || ' ' ||
              COALESCE(cc.iban, '') || ' ' ||
              COALESCE(cc.info1, '') || ' ' ||
              COALESCE(cc.info2, '') || ' ' ||
              CAST(cc.id AS TEXT) || ' ' ||
              (CASE WHEN cc.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
              COALESCE((
             SELECT STRING_AGG(
              get_professional_label(cct.type, 'credit_card') || ' ' ||
              get_professional_label(cct.type, 'cari') || ' ' ||
               COALESCE(cct.type, '') || ' ' ||
               COALESCE(TO_CHAR(cct.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
               COALESCE(cct.description, '') || ' ' ||
               COALESCE(cct.location, '') || ' ' ||
               COALESCE(cct.location_code, '') || ' ' ||
                  COALESCE(cct.location_name, '') || ' ' ||
                  COALESCE(cct.user_name, '') || ' ' ||
                  COALESCE(CAST(cct.amount AS TEXT), '') || ' ' ||
                  COALESCE(cct.integration_ref, '') || ' ' ||
                  (CASE 
                    WHEN cct.integration_ref = 'opening_stock' OR cct.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                    WHEN cct.integration_ref LIKE '%production%' OR cct.description ILIKE '%Üretim%' THEN 'üretim'
                    WHEN cct.integration_ref LIKE '%transfer%' OR cct.description ILIKE '%Devir%' THEN 'devir'
                    WHEN cct.integration_ref LIKE '%shipment%' THEN 'sevkiyat'
                    WHEN cct.integration_ref LIKE '%collection%' THEN 'tahsilat'
                    WHEN cct.integration_ref LIKE '%payment%' THEN 'ödeme'
                    WHEN cct.integration_ref LIKE 'SALE-%' OR cct.integration_ref LIKE 'RETAIL-%' THEN 'satış yapıldı'
                    WHEN cct.integration_ref LIKE 'PURCHASE-%' THEN 'alış yapıldı'
                    ELSE ''
                   END),
                  ' '
                )
                FROM (
                  SELECT * FROM credit_card_transactions sub_cct
                  WHERE sub_cct.credit_card_id = cc.id
                  ORDER BY sub_cct.created_at DESC
                  LIMIT 50
                ) cct
              ), '')
            )
            WHERE cc.id = COALESCE(NEW.credit_card_id, OLD.credit_card_id);
            RETURN NULL;
          END;
          \$\$ LANGUAGE plpgsql;
        ''');

        final triggerExists = await _pool!.execute(
          "SELECT 1 FROM pg_trigger WHERE tgname = 'trg_update_credit_card_search_tags'",
        );
        if (triggerExists.isEmpty) {
          await _pool!.execute(
            'CREATE TRIGGER trg_update_credit_card_search_tags AFTER INSERT OR DELETE ON credit_card_transactions FOR EACH ROW EXECUTE FUNCTION update_credit_card_search_tags()',
          );
        }
        // Initial Indeksleme: Arka planda çalıştır (Sayfa açılışını bloklama)
        await verileriIndeksle(forceUpdate: false);
        } catch (e) {
          if (e is LisansYazmaEngelliHatasi) return;
          debugPrint('Kredi kartı arka plan ek kurulum hatası: $e');
        }
      }());
    }
  }

  /// Tüm kredi kartları için search_tags indekslemesi yapar (Batch Processing)
  Future<void> verileriIndeksle({bool forceUpdate = true}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    try {
      debugPrint('🚀 Kredi Kartı İndeksleme Başlatılıyor (Batch Modu)...');

      const int batchSize = 500;
      int processedCount = 0;
      int lastId = 0;

      while (true) {
        final String versionPredicate =
            "(search_tags IS NULL OR search_tags = '' OR search_tags NOT LIKE '$_searchTagsVersionPrefix%')";

        final idRows = await _pool!.execute(
          Sql.named(
            "SELECT id FROM credit_cards WHERE id > @lastId AND COALESCE(company_id, '$_defaultCompanyId') = @companyId ${forceUpdate ? '' : 'AND $versionPredicate'} ORDER BY id ASC LIMIT @batchSize",
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
          UPDATE credit_cards cc
          SET search_tags = normalize_text(
            '$_searchTagsVersionPrefix ' ||
            COALESCE(cc.code, '') || ' ' ||
            COALESCE(cc.name, '') || ' ' ||
            COALESCE(cc.currency, '') || ' ' ||
            COALESCE(cc.branch_code, '') || ' ' ||
            COALESCE(cc.branch_name, '') || ' ' ||
            COALESCE(cc.account_no, '') || ' ' ||
            COALESCE(cc.iban, '') || ' ' ||
            COALESCE(cc.info1, '') || ' ' ||
            COALESCE(cc.info2, '') || ' ' ||
            CAST(cc.id AS TEXT) || ' ' ||
            (CASE WHEN cc.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
            COALESCE((
              SELECT STRING_AGG(
                get_professional_label(cct.type, 'credit_card') || ' ' ||
                get_professional_label(cct.type, 'cari') || ' ' ||
                 COALESCE(cct.type, '') || ' ' ||
                 COALESCE(TO_CHAR(cct.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
                 COALESCE(cct.description, '') || ' ' ||
                 COALESCE(cct.location, '') || ' ' ||
                 COALESCE(cct.location_code, '') || ' ' ||
                 COALESCE(cct.location_name, '') || ' ' ||
                 COALESCE(cct.user_name, '') || ' ' ||
                 COALESCE(CAST(cct.amount AS TEXT), '') || ' ' ||
                 COALESCE(cct.integration_ref, '') || ' ' ||
                 (CASE 
                  WHEN cct.integration_ref = 'opening_stock' OR cct.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                  WHEN cct.integration_ref LIKE '%production%' OR cct.description ILIKE '%Üretim%' THEN 'üretim'
                  WHEN cct.integration_ref LIKE '%transfer%' OR cct.description ILIKE '%Devir%' THEN 'devir'
                  WHEN cct.integration_ref LIKE '%shipment%' THEN 'sevkiyat'
                  WHEN cct.integration_ref LIKE '%collection%' THEN 'tahsilat'
                  WHEN cct.integration_ref LIKE '%payment%' THEN 'ödeme'
                  WHEN cct.integration_ref LIKE 'SALE-%' OR cct.integration_ref LIKE 'RETAIL-%' THEN 'satış yapıldı'
                  WHEN cct.integration_ref LIKE 'PURCHASE-%' THEN 'alış yapıldı'
                  ELSE ''
                 END),
                 ' '
               )
              FROM (
                SELECT * FROM credit_card_transactions sub_cct
                WHERE sub_cct.credit_card_id = cc.id
                ORDER BY sub_cct.created_at DESC
                LIMIT 50
              ) cct
            ), '')
          )
          WHERE cc.id IN ($idListStr) $conditionalWhere
        '''),
        );

        processedCount += ids.length;
        debugPrint('   ...$processedCount kredi kartı indekslendi.');
        await Future.delayed(const Duration(milliseconds: 10));
      }

      debugPrint(
        '✅ Kredi Kartı Arama İndeksleri Tamamlandı. Toplam: $processedCount',
      );
    } catch (e) {
      if (e is LisansYazmaEngelliHatasi) return;
      debugPrint('Kredi kartı indeksleme sırasında hata: $e');
    }
  }

  Future<void> _updateSearchTags(int krediKartiId) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('''
        UPDATE credit_cards cc
        SET search_tags = normalize_text(
          '$_searchTagsVersionPrefix ' ||
          COALESCE(cc.code, '') || ' ' ||
          COALESCE(cc.name, '') || ' ' ||
          COALESCE(cc.currency, '') || ' ' ||
          COALESCE(cc.branch_code, '') || ' ' ||
          COALESCE(cc.branch_name, '') || ' ' ||
          COALESCE(cc.account_no, '') || ' ' ||
          COALESCE(cc.iban, '') || ' ' ||
          COALESCE(cc.info1, '') || ' ' ||
          COALESCE(cc.info2, '') || ' ' ||
          CAST(cc.id AS TEXT) || ' ' ||
          (CASE WHEN cc.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
          COALESCE((
            SELECT STRING_AGG(
              get_professional_label(cct.type, 'credit_card') || ' ' ||
              get_professional_label(cct.type, 'cari') || ' ' ||
              COALESCE(cct.type, '') || ' ' ||
              COALESCE(cct.date::TEXT, '') || ' ' ||
              COALESCE(cct.description, '') || ' ' ||
              COALESCE(cct.location, '') || ' ' ||
              COALESCE(cct.location_code, '') || ' ' ||
              COALESCE(cct.location_name, '') || ' ' ||
              COALESCE(cct.user_name, '') || ' ' ||
              COALESCE(CAST(cct.amount AS TEXT), ''),
              ' '
            )
            FROM (
              SELECT * FROM credit_card_transactions sub_cct
              WHERE sub_cct.credit_card_id = cc.id
              ORDER BY sub_cct.created_at DESC
              LIMIT 50
            ) cct
          ), '')
        )
        WHERE cc.id = @id
          AND COALESCE(cc.company_id, '$_defaultCompanyId') = @companyId
      '''),
      parameters: {'id': krediKartiId, 'companyId': _companyId},
    );
  }

  Future<List<KrediKartiModel>> krediKartlariniGetir({
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
    int? krediKartiId,
    Session? session,
  }) async {
    if (session == null) {
      if (!_isInitialized) await baslat();
      if (_pool == null) return [];
    }

    final executor = session ?? _pool!;

    // Deep Search: SELECT with matched_in_hidden
    String selectClause = 'SELECT cc.*';

    if (aramaKelimesi != null && aramaKelimesi.isNotEmpty) {
      selectClause +=
          ''',
        (CASE
          WHEN (
            -- Expanded/detail-only fields
            normalize_text(COALESCE(cc.branch_code, '')) LIKE @search OR
            normalize_text(COALESCE(cc.branch_name, '')) LIKE @search OR
            normalize_text(COALESCE(cc.account_no, '')) LIKE @search OR
            normalize_text(COALESCE(cc.iban, '')) LIKE @search OR
            normalize_text(COALESCE(cc.info1, '')) LIKE @search OR
            normalize_text(COALESCE(cc.info2, '')) LIKE @search OR
            -- Expanded timeline (last 50 transactions)
            EXISTS (
              SELECT 1
              FROM (
                SELECT *
                FROM credit_card_transactions sub_cct
                WHERE sub_cct.credit_card_id = cc.id
                  AND COALESCE(sub_cct.company_id, '$_defaultCompanyId') = @companyId
                ORDER BY sub_cct.created_at DESC
                LIMIT 50
               ) cct
               WHERE normalize_text(
                 COALESCE(get_professional_label(cct.type, 'credit_card'), '') || ' ' ||
                 COALESCE(get_professional_label(cct.type, 'cari'), '') || ' ' ||
                 COALESCE(cct.type, '') || ' ' ||
                 COALESCE(TO_CHAR(cct.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
                 COALESCE(cct.description, '') || ' ' ||
                 COALESCE(cct.location, '') || ' ' ||
                 COALESCE(cct.location_code, '') || ' ' ||
                COALESCE(cct.location_name, '') || ' ' ||
                COALESCE(cct.user_name, '') || ' ' ||
                COALESCE(CAST(cct.amount AS TEXT), '') || ' ' ||
                COALESCE(cct.integration_ref, '') || ' ' ||
                (CASE 
                  WHEN cct.integration_ref = 'opening_stock' OR cct.description ILIKE '%Açılış%' THEN 'açılış stoğu'
                  WHEN cct.integration_ref LIKE '%production%' OR cct.description ILIKE '%Üretim%' THEN 'üretim'
                  WHEN cct.integration_ref LIKE '%transfer%' OR cct.description ILIKE '%Devir%' THEN 'devir'
                  WHEN cct.integration_ref LIKE '%shipment%' THEN 'sevkiyat'
                  WHEN cct.integration_ref LIKE '%collection%' THEN 'tahsilat'
                  WHEN cct.integration_ref LIKE '%payment%' THEN 'ödeme'
                  WHEN cct.integration_ref LIKE 'SALE-%' OR cct.integration_ref LIKE 'RETAIL-%' THEN 'satış yapıldı'
                  WHEN cct.integration_ref LIKE 'PURCHASE-%' THEN 'alış yapıldı'
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
      conditions.add("COALESCE(cc.search_tags, '') LIKE @search");
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

    if (krediKartiId != null) {
      conditions.add('id = @krediKartiId');
      params['krediKartiId'] = krediKartiId;
    }

    // Kullanıcı Filtresi
    if (kullanici != null && kullanici.isNotEmpty) {
      conditions.add('''
        EXISTS (
          SELECT 1 FROM credit_card_transactions cct
          WHERE cct.credit_card_id = cc.id
          AND cct.user_name = @kullanici
          AND COALESCE(cct.company_id, '$_defaultCompanyId') = @companyId
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
            SELECT 1 FROM credit_card_transactions cct
            WHERE cct.credit_card_id = cc.id
            AND (cct.integration_ref LIKE 'SALE-%' OR cct.integration_ref LIKE 'RETAIL-%')
            AND COALESCE(cct.company_id, '$_defaultCompanyId') = @companyId
          )
        ''');
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM credit_card_transactions cct
            WHERE cct.credit_card_id = cc.id
            AND cct.integration_ref LIKE 'PURCHASE-%'
            AND COALESCE(cct.company_id, '$_defaultCompanyId') = @companyId
          )
        ''');
      } else {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM credit_card_transactions cct
            WHERE cct.credit_card_id = cc.id
            AND cct.type = @islemTuru
            AND COALESCE(cct.company_id, '$_defaultCompanyId') = @companyId
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
          SELECT 1 FROM credit_card_transactions cct
          WHERE cct.credit_card_id = cc.id
          AND COALESCE(cct.company_id, '$_defaultCompanyId') = @companyId
      ''';

      if (baslangicTarihi != null) {
        existsQuery += " AND cct.date >= @startDate";
        params['startDate'] = DateTime(
          baslangicTarihi.year,
          baslangicTarihi.month,
          baslangicTarihi.day,
        ).toIso8601String();
      }
      if (bitisTarihi != null) {
        existsQuery += " AND cct.date < @endDate";
        params['endDate'] = DateTime(
          bitisTarihi.year,
          bitisTarihi.month,
          bitisTarihi.day,
        ).add(const Duration(days: 1)).toIso8601String();
      }

      existsQuery += ')';
      conditions.add(existsQuery);
    }

    String query = '$selectClause FROM credit_cards cc';
    if (conditions.isNotEmpty) {
      query += ' WHERE ${conditions.join(' AND ')}';
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
    query += ' ORDER BY $orderBy ${artanSiralama ? 'ASC' : 'DESC'}';

    // Pagination
    query += ' LIMIT @limit OFFSET @offset';
    params['limit'] = sayfaBasinaKayit;
    params['offset'] = (sayfa - 1) * sayfaBasinaKayit;

    final result = await executor.execute(Sql.named(query), parameters: params);

    return result.map((row) {
      final map = row.toColumnMap();
      return _mapToKrediKartiModel(map);
    }).toList();
  }

  Future<int> krediKartiSayisiGetir({
    String? aramaTerimi,
    bool? aktifMi,
    bool? varsayilan,
    String? kullanici,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? islemTuru,
    int? krediKartiId,
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
        krediKartiId == null) {
      try {
        final approxResult = await _pool!.execute(
          "SELECT reltuples::BIGINT FROM pg_class WHERE relname = 'credit_cards'",
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

    String query = 'SELECT COUNT(*) FROM credit_cards cc';
    List<String> conditions = [];
    Map<String, dynamic> params = {'companyId': _companyId};

    conditions.add(
      "COALESCE(cc.company_id, '$_defaultCompanyId') = @companyId",
    );

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      // Deep Search (indexed): v2 normalize_text + trigram (search_tags)
      conditions.add("COALESCE(cc.search_tags, '') LIKE @search");
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

    if (krediKartiId != null) {
      conditions.add('id = @krediKartiId');
      params['krediKartiId'] = krediKartiId;
    }

    // Kullanıcı Filtresi
    if (kullanici != null && kullanici.isNotEmpty) {
      conditions.add('''
        EXISTS (
          SELECT 1 FROM credit_card_transactions cct
          WHERE cct.credit_card_id = cc.id
          AND cct.user_name = @kullanici
          AND COALESCE(cct.company_id, '$_defaultCompanyId') = @companyId
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
            SELECT 1 FROM credit_card_transactions cct
            WHERE cct.credit_card_id = cc.id
            AND (cct.integration_ref LIKE 'SALE-%' OR cct.integration_ref LIKE 'RETAIL-%')
            AND COALESCE(cct.company_id, '$_defaultCompanyId') = @companyId
          )
        ''');
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM credit_card_transactions cct
            WHERE cct.credit_card_id = cc.id
            AND cct.integration_ref LIKE 'PURCHASE-%'
            AND COALESCE(cct.company_id, '$_defaultCompanyId') = @companyId
          )
        ''');
      } else {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM credit_card_transactions cct
            WHERE cct.credit_card_id = cc.id
            AND cct.type = @islemTuru
            AND COALESCE(cct.company_id, '$_defaultCompanyId') = @companyId
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
          SELECT 1 FROM credit_card_transactions cct
          WHERE cct.credit_card_id = cc.id
          AND COALESCE(cct.company_id, '$_defaultCompanyId') = @companyId
      ''';

      if (baslangicTarihi != null) {
        existsQuery += " AND cct.date >= @startDate";
        params['startDate'] = DateTime(
          baslangicTarihi.year,
          baslangicTarihi.month,
          baslangicTarihi.day,
        ).toIso8601String();
      }
      if (bitisTarihi != null) {
        existsQuery += " AND cct.date < @endDate";
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

  /// [2026 HYPER-SPEED] Dinamik filtre seçeneklerini ve sayıları getirir.
  /// 1 Milyar+ kayıt için optimize edilmiştir, SARGable predicates kullanır.
  Future<Map<String, Map<String, int>>> krediKartiFiltreIstatistikleriniGetir({
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
      "COALESCE(credit_cards.company_id, '$_defaultCompanyId') = @companyId",
    );

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      baseConditions.add("COALESCE(credit_cards.search_tags, '') LIKE @search");
      params['search'] = '%${_normalizeTurkish(aramaTerimi)}%';
    }

    // Transaction conditions used across facets (always includes company filter)
    String transactionFilters =
        " AND COALESCE(cct.company_id, '$_defaultCompanyId') = @companyId";
    if (baslangicTarihi != null) {
      transactionFilters += " AND cct.date >= @start";
      params['start'] = DateTime(
        baslangicTarihi.year,
        baslangicTarihi.month,
        baslangicTarihi.day,
      ).toIso8601String();
    }
    if (bitisTarihi != null) {
      transactionFilters += " AND cct.date < @end";
      params['end'] = DateTime(
        bitisTarihi.year,
        bitisTarihi.month,
        bitisTarihi.day,
      ).add(const Duration(days: 1)).toIso8601String();
    }

    if (baslangicTarihi != null || bitisTarihi != null) {
      baseConditions.add('''
        EXISTS (
          SELECT 1 FROM credit_card_transactions cct 
          WHERE cct.credit_card_id = credit_cards.id 
          $transactionFilters
        )
      ''');
    }

    String buildQuery(String selectAndGroup, List<String> facetConds) {
      String where = (baseConditions.isNotEmpty || facetConds.isNotEmpty)
          ? 'WHERE ${(baseConditions + facetConds).join(' AND ')}'
          : '';
      return 'SELECT $selectAndGroup FROM (SELECT * FROM credit_cards $where LIMIT 100001) as sub GROUP BY 1';
    }

    // 1. Durum İstatistikleri
    List<String> durumConds = [];
    if (varsayilan != null) durumConds.add('is_default = @varsayilan');
    if (kullanici != null && kullanici.isNotEmpty) {
      durumConds.add('''
        EXISTS (
          SELECT 1 FROM credit_card_transactions cct 
          WHERE cct.credit_card_id = credit_cards.id 
          AND cct.user_name = @kullanici
          $transactionFilters
        )
      ''');
    }
    if (islemTuru != null && islemTuru.isNotEmpty) {
      final normalized = islemTuru.trim();
      if (normalized == 'Satış Yapıldı' || normalized == 'Satis Yapildi') {
        durumConds.add('''
          EXISTS (
            SELECT 1 FROM credit_card_transactions cct 
            WHERE cct.credit_card_id = credit_cards.id 
            AND (cct.integration_ref LIKE 'SALE-%' OR cct.integration_ref LIKE 'RETAIL-%')
            $transactionFilters
          )
        ''');
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        durumConds.add('''
          EXISTS (
            SELECT 1 FROM credit_card_transactions cct 
            WHERE cct.credit_card_id = credit_cards.id 
            AND cct.integration_ref LIKE 'PURCHASE-%'
            $transactionFilters
          )
        ''');
      } else {
        durumConds.add('''
          EXISTS (
            SELECT 1 FROM credit_card_transactions cct 
            WHERE cct.credit_card_id = credit_cards.id 
            AND cct.type = @islemTuru
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
          SELECT 1 FROM credit_card_transactions cct 
          WHERE cct.credit_card_id = credit_cards.id 
          AND cct.user_name = @kullanici
          $transactionFilters
        )
      ''');
    }
    if (islemTuru != null && islemTuru.isNotEmpty) {
      final normalized = islemTuru.trim();
      if (normalized == 'Satış Yapıldı' || normalized == 'Satis Yapildi') {
        defaultConds.add('''
          EXISTS (
            SELECT 1 FROM credit_card_transactions cct 
            WHERE cct.credit_card_id = credit_cards.id 
            AND (cct.integration_ref LIKE 'SALE-%' OR cct.integration_ref LIKE 'RETAIL-%')
            $transactionFilters
          )
        ''');
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        defaultConds.add('''
          EXISTS (
            SELECT 1 FROM credit_card_transactions cct 
            WHERE cct.credit_card_id = credit_cards.id 
            AND cct.integration_ref LIKE 'PURCHASE-%'
            $transactionFilters
          )
        ''');
      } else {
        defaultConds.add('''
          EXISTS (
            SELECT 1 FROM credit_card_transactions cct 
            WHERE cct.credit_card_id = credit_cards.id 
            AND cct.type = @islemTuru
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
          SELECT 1 FROM credit_card_transactions cct 
          WHERE cct.credit_card_id = credit_cards.id 
          AND cct.user_name = @kullanici
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
            SELECT 1 FROM credit_card_transactions cct 
            WHERE cct.credit_card_id = credit_cards.id 
            AND (cct.integration_ref LIKE 'SALE-%' OR cct.integration_ref LIKE 'RETAIL-%')
            $transactionFilters
          )
        ''');
      } else if (normalized == 'Alış Yapıldı' || normalized == 'Alis Yapildi') {
        userConds.add('''
          EXISTS (
            SELECT 1 FROM credit_card_transactions cct 
            WHERE cct.credit_card_id = credit_cards.id 
            AND cct.integration_ref LIKE 'PURCHASE-%'
            $transactionFilters
          )
        ''');
      } else {
        userConds.add('''
          EXISTS (
            SELECT 1 FROM credit_card_transactions cct 
            WHERE cct.credit_card_id = credit_cards.id 
            AND cct.type = @islemTuru
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
          'SELECT COUNT(*) FROM credit_cards ${baseConditions.isNotEmpty ? 'WHERE ${baseConditions.join(' AND ')}' : ''}',
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
              WHEN cct.integration_ref LIKE 'SALE-%' OR cct.integration_ref LIKE 'RETAIL-%' THEN 'Satış Yapıldı'
              WHEN cct.integration_ref LIKE 'PURCHASE-%' THEN 'Alış Yapıldı'
              ELSE cct.type
            END AS type_key,
            COUNT(DISTINCT credit_cards.id)
          FROM credit_cards
          JOIN credit_card_transactions cct ON cct.credit_card_id = credit_cards.id
          WHERE ${(baseConditions + typeConds).join(' AND ')}
          $transactionFilters
          GROUP BY type_key
        '''),
        parameters: typeParams,
      ),
      // Kullanıcılar
      _pool!.execute(
        Sql.named('''
          SELECT cct.user_name, COUNT(DISTINCT credit_cards.id)
          FROM credit_cards
          JOIN credit_card_transactions cct ON cct.credit_card_id = credit_cards.id
          WHERE ${(baseConditions + userConds).join(' AND ')}
          $transactionFilters
          GROUP BY cct.user_name
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

    final result = await _pool!.execute(
      Sql.named(
        "SELECT t.*, c.code as kredi_karti_kodu, c.name as kredi_karti_adi, c.currency as para_birimi FROM credit_card_transactions t LEFT JOIN credit_cards c ON t.credit_card_id = c.id WHERE COALESCE(t.company_id, '$_defaultCompanyId') = @companyId ORDER BY t.created_at DESC LIMIT 50",
      ),
      parameters: {'companyId': _companyId},
    );

    return result.map((row) {
      final map = row.toColumnMap();
      return _mapToTransaction(map);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> krediKartiIslemleriniGetir(
    int krediKartiId, {
    String? aramaTerimi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? islemTuru,
    String? kullanici,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    String query =
        "SELECT t.*, c.code as kredi_karti_kodu, c.name as kredi_karti_adi, c.currency as para_birimi FROM credit_card_transactions t LEFT JOIN credit_cards c ON t.credit_card_id = c.id WHERE t.credit_card_id = @krediKartiId AND COALESCE(t.company_id, '$_defaultCompanyId') = @companyId";
    Map<String, dynamic> params = {
      'krediKartiId': krediKartiId,
      'companyId': _companyId,
    };

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      query += '''
        AND normalize_text(
          COALESCE(get_professional_label(t.type, 'credit_card'), '') || ' ' ||
          COALESCE(get_professional_label(t.type, 'cari'), '') || ' ' ||
          COALESCE(t.type, '') || ' ' ||
          COALESCE(TO_CHAR(t.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
          COALESCE(t.description, '') || ' ' ||
          COALESCE(t.location, '') || ' ' ||
          COALESCE(t.location_code, '') || ' ' ||
          COALESCE(t.location_name, '') || ' ' ||
          COALESCE(t.user_name, '') || ' ' ||
          COALESCE(CAST(t.amount AS TEXT), '') || ' ' ||
          COALESCE(t.integration_ref, '')
        ) LIKE @search
      ''';
      params['search'] = '%${_normalizeTurkish(aramaTerimi)}%';
    }

    if (islemTuru != null && islemTuru.isNotEmpty) {
      final normalizedType = islemTuru.trim();
      if (normalizedType == 'Satış Yapıldı' ||
          normalizedType == 'Satis Yapildi') {
        query +=
            " AND (t.integration_ref LIKE 'SALE-%' OR t.integration_ref LIKE 'RETAIL-%')";
      } else if (normalizedType == 'Alış Yapıldı' ||
          normalizedType == 'Alis Yapildi') {
        query += " AND t.integration_ref LIKE 'PURCHASE-%'";
      } else {
        query += ' AND t.type = @islemTuru';
        params['islemTuru'] = islemTuru;
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

    query += ' ORDER BY t.created_at DESC';

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
        "SELECT DISTINCT type FROM credit_card_transactions WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId ORDER BY type ASC",
      ),
      parameters: {'companyId': _companyId},
    );

    return result.map((r) => r[0] as String).toList();
  }

  Future<void> krediKartiEkle(KrediKartiModel kart) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isBankCreditActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde kredi kartı işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final result = await _pool!.execute(
      Sql.named('''
        INSERT INTO credit_cards (company_id, code, name, balance, currency, branch_code, branch_name, account_no, iban, info1, info2, is_active, is_default, search_tags, matched_in_hidden)
        VALUES (@companyId, @code, @name, @balance, @currency, @branch_code, @branch_name, @account_no, @iban, @info1, @info2, @is_active, @is_default, @search_tags, @matched_in_hidden)
        RETURNING id
      '''),
      parameters: {
        'companyId': _companyId,
        'code': kart.kod,
        'name': kart.ad,
        'balance': kart.bakiye,
        'currency': kart.paraBirimi,
        'branch_code': kart.subeKodu,
        'branch_name': kart.subeAdi,
        'account_no': kart.hesapNo,
        'iban': kart.iban,
        'info1': kart.bilgi1,
        'info2': kart.bilgi2,
        'is_active': kart.aktifMi ? 1 : 0,
        'is_default': kart.varsayilan ? 1 : 0,
        'search_tags': kart.searchTags,
        'matched_in_hidden': kart.matchedInHidden ? 1 : 0,
      },
    );

    if (result.isNotEmpty) {
      final newId = result.first[0] as int;
      await _updateSearchTags(newId);
    }
  }

  Future<void> krediKartiGuncelle(KrediKartiModel kart) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isBankCreditActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde kredi kartı işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('''
        UPDATE credit_cards 
        SET code=@code, name=@name, balance=@balance, currency=@currency, branch_code=@branch_code, branch_name=@branch_name,
            account_no=@account_no, iban=@iban, info1=@info1, info2=@info2, is_active=@is_active, is_default=@is_default, 
            search_tags=@search_tags, matched_in_hidden=@matched_in_hidden
        WHERE id=@id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
      '''),
      parameters: {
        'id': kart.id,
        'companyId': _companyId,
        'code': kart.kod,
        'name': kart.ad,
        'balance': kart.bakiye,
        'currency': kart.paraBirimi,
        'branch_code': kart.subeKodu,
        'branch_name': kart.subeAdi,
        'account_no': kart.hesapNo,
        'iban': kart.iban,
        'info1': kart.bilgi1,
        'info2': kart.bilgi2,
        'is_active': kart.aktifMi ? 1 : 0,
        'is_default': kart.varsayilan ? 1 : 0,
        'search_tags': kart.searchTags,
        'matched_in_hidden': kart.matchedInHidden ? 1 : 0,
      },
    );

    await _updateSearchTags(kart.id);
  }

  Future<void> krediKartiVarsayilanDegistir(int id, bool varsayilan) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isBankCreditActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde kredi kartı işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      if (varsayilan) {
        // Eğer bu kart varsayılan yapılıyorsa, diğerlerinin varsayılan özelliğini kaldır
        await session.execute(
          Sql.named(
            "UPDATE credit_cards SET is_default = 0 WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId",
          ),
          parameters: {'companyId': _companyId},
        );
      }
      await session.execute(
        Sql.named(
          "UPDATE credit_cards SET is_default = @val WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {
          'val': varsayilan ? 1 : 0,
          'id': id,
          'companyId': _companyId,
        },
      );
    });
  }

  Future<void> krediKartiSil(int id) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isBankCreditActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde kredi kartı işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      await session.execute(
        Sql.named(
          "DELETE FROM credit_cards WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );
      await session.execute(
        Sql.named(
          "DELETE FROM credit_card_transactions WHERE credit_card_id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );
    });
  }

  Future<int> krediKartiIslemEkle({
    required int krediKartiId,
    required double tutar,
    required String islemTuru, // 'Giriş' (Ödeme/Alacak), 'Çıkış' (Harcama/Borç)
    required String aciklama,
    required DateTime tarih,
    required String cariTuru,
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
        'LITE sürümde kredi kartı işlemleri kapalıdır. Pro sürüme geçin.',
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
    KrediKartiModel? currentKart;
    KrediKartiModel? targetKart;
    if (cariEntegrasyonYap) {
      // ALWAYS pre-fetch current asset if integrating with Cari
      final kartlar = await krediKartlariniGetir(
        krediKartiId: krediKartiId,
        session: session,
      );
      currentKart = kartlar.firstOrNull;
      if (locationType == 'credit_card' && cariKodu.isNotEmpty) {
        final hedefKartlar = await krediKartiAra(
          cariKodu,
          limit: 1,
          session: session,
        );
        if (hedefKartlar.isNotEmpty) {
          targetKart = hedefKartlar.first;
        }
      }
    }

    Future<void> operation(TxSession s) async {
      // 0. Eksi Bakiye Kontrolü (Ayarlara Bağlı)
      if (islemTuru == 'Çıkış' || islemTuru == 'Harcama') {
        try {
          final settings = await AyarlarVeritabaniServisi()
              .genelAyarlariGetir();
          if (settings.eksiBakiyeKontrol) {
            final bakiyeResult = await s.execute(
              Sql.named(
                "SELECT balance FROM credit_cards WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId FOR UPDATE",
              ),
              parameters: {'id': krediKartiId, 'companyId': _companyId},
            );

            if (bakiyeResult.isNotEmpty) {
              final double mevcutBakiye =
                  double.tryParse(bakiyeResult.first[0]?.toString() ?? '') ??
                  0.0;
              if (mevcutBakiye - tutar < 0) {
                throw Exception(
                  'Yetersiz Bakiye! Kredi kartı bakiyesi eksiye düşemez. (Mevcut: $mevcutBakiye, İşlem: $tutar)',
                );
              }
            }
          }
        } catch (e) {
          rethrow;
        }
      }

      // 1. İşlemi kaydet (JIT Partitioning ile)
      Result insertResult;
      await s.execute('SAVEPOINT sp_cc_insert');

      try {
        insertResult = await s.execute(
          Sql.named('''
            INSERT INTO credit_card_transactions 
            (company_id, credit_card_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref)
            VALUES (@companyId, @krediKartiId, @tarih, @aciklama, @tutar, @islemTuru, @cariTuru, @cariKodu, @cariAdi, @kullanici, @integration_ref)
            RETURNING id
          '''),
          parameters: {
            'companyId': _companyId,
            'krediKartiId': krediKartiId,
            'tarih': tarih,
            'aciklama': aciklama,
            'tutar': tutar,
            'islemTuru': islemTuru,
            'cariTuru': cariTuru,
            'cariKodu': cariKodu,
            'cariAdi': cariAdi,
            'kullanici': kullanici,
            'integration_ref': finalRef,
          },
        );
        await s.execute('RELEASE SAVEPOINT sp_cc_insert');
      } catch (e) {
        await s.execute('ROLLBACK TO SAVEPOINT sp_cc_insert');

        final String errorStr = e.toString();
        final bool isMissingTable =
            errorStr.contains('42P01') ||
            errorStr.toLowerCase().contains('does not exist');

        if (isMissingTable || _isPartitionError(e)) {
          debugPrint(
            '⚠️ Kredi Kartı Tablo/Partition hatası (Self-Healing)... Yıl: ${tarih.year}',
          );

          if (isMissingTable) {
            debugPrint(
              '🚨 Kredi kartı hareketleri tablosu eksik! Yeniden oluşturuluyor...',
            );
            await _tablolariOlustur();
          } else {
            await _createCreditCardPartitions(tarih.year, session: s);
          }

          // Retry
          await s.execute('SAVEPOINT sp_cc_retry');
          try {
            insertResult = await s.execute(
              Sql.named('''
                INSERT INTO credit_card_transactions 
                (company_id, credit_card_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref)
                VALUES (@companyId, @krediKartiId, @tarih, @aciklama, @tutar, @islemTuru, @cariTuru, @cariKodu, @cariAdi, @kullanici, @integration_ref)
                RETURNING id
              '''),
              parameters: {
                'companyId': _companyId,
                'krediKartiId': krediKartiId,
                'tarih': tarih,
                'aciklama': aciklama,
                'tutar': tutar,
                'islemTuru': islemTuru,
                'cariTuru': cariTuru,
                'cariKodu': cariKodu,
                'cariAdi': cariAdi,
                'kullanici': kullanici,
                'integration_ref': finalRef,
              },
            );
            await s.execute('RELEASE SAVEPOINT sp_cc_retry');
          } catch (retryE) {
            await s.execute('ROLLBACK TO SAVEPOINT sp_cc_retry');
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      final int krediKartiIslemId = (insertResult.first[0] as int?) ?? 0;
      yeniIslemId = krediKartiIslemId;

      // 2. Kredi Kartı bakiyesini güncelle
      // Giriş -> Bakiye artar (Borç azalır)
      // Çıkış -> Bakiye azalır (Borç artar)
      String updateQuery =
          'UPDATE credit_cards SET balance = balance + @amount WHERE id = @id';
      if (islemTuru == 'Çıkış' || islemTuru == 'Harcama') {
        updateQuery =
            'UPDATE credit_cards SET balance = balance - @amount WHERE id = @id';
      }

      await s.execute(
        Sql.named(updateQuery),
        parameters: {'amount': tutar, 'id': krediKartiId},
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
            bool isBorc = islemTuru == 'Çıkış' || islemTuru == 'Harcama';

            await cariServis.cariIslemEkle(
              cariId: cariId,
              tutar: tutar,
              isBorc: isBorc,
              islemTuru: 'Kredi Kartı',
              aciklama: aciklama,
              tarih: tarih,
              kullanici: kullanici,
              kaynakId: krediKartiIslemId,
              kaynakAdi: currentKart?.ad ?? 'Kredi Kartı',
              kaynakKodu: currentKart?.kod ?? '',
              entegrasyonRef: finalRef, // Referans eklendi
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
            String karsiIslemTuru =
                (islemTuru == 'Çıkış' || islemTuru == 'Harcama')
                ? 'Tahsilat'
                : 'Ödeme';

            await bankaServis.bankaIslemEkle(
              bankaId: bankalar.first.id,
              tutar: tutar,
              islemTuru: karsiIslemTuru,
              aciklama: aciklama,
              tarih: tarih,
              cariTuru: 'Kredi Kartı',
              cariKodu: currentKart?.kod ?? '',
              cariAdi: currentKart?.ad ?? '',
              kullanici: kullanici,
              cariEntegrasyonYap: false,
              entegrasyonRef: finalRef,
              session: s,
            );
          }
        }
        // C. Kasa Entegrasyonu
        else if (locationType == 'cash') {
          final kasaServis = KasalarVeritabaniServisi();
          final kasalar = await kasaServis.kasaAra(
            cariKodu,
            limit: 1,
            session: s,
          );
          if (kasalar.isNotEmpty) {
            String karsiIslemTuru =
                (islemTuru == 'Çıkış' || islemTuru == 'Harcama')
                ? 'Tahsilat'
                : 'Ödeme';

            await kasaServis.kasaIslemEkle(
              kasaId: kasalar.first.id,
              tutar: tutar,
              islemTuru: karsiIslemTuru,
              aciklama: aciklama,
              tarih: tarih,
              cariTuru: 'Kredi Kartı',
              cariKodu: currentKart?.kod ?? '',
              cariAdi: currentKart?.ad ?? '',
              kullanici: kullanici,
              cariEntegrasyonYap: false,
              entegrasyonRef: finalRef,
              session: s,
            );
          }
        }
        // D. Kredi Kartı Transferi (Virman)
        else if (locationType == 'credit_card') {
          if (targetKart != null) {
            String karsiIslemTuru =
                (islemTuru == 'Çıkış' || islemTuru == 'Harcama')
                ? 'Giriş'
                : 'Çıkış';

            // Insert Target Transaction
            await s.execute(
              Sql.named('''
              INSERT INTO credit_card_transactions 
              (company_id, credit_card_id, date, description, amount, type, location, location_code, location_name, user_name, integration_ref)
              VALUES (@companyId, @krediKartiId, @tarih, @aciklama, @tutar, @islemTuru, @cariTuru, @cariKodu, @cariAdi, @kullanici, @integration_ref)
              '''),
              parameters: {
                'companyId': _companyId,
                'krediKartiId': targetKart.id,
                'tarih': DateFormat('yyyy-MM-dd HH:mm').format(tarih),
                'aciklama': aciklama,
                'tutar': tutar,
                'islemTuru': karsiIslemTuru,
                'cariTuru': 'Kredi Kartı',
                'cariKodu': currentKart?.kod ?? '',
                'cariAdi': currentKart?.ad ?? '',
                'kullanici': kullanici,
                'integration_ref': finalRef,
              },
            );

            // Update Target Balance
            String targetUpdateQuery =
                'UPDATE credit_cards SET balance = balance + @amount WHERE id = @id';
            if (karsiIslemTuru == 'Çıkış' || karsiIslemTuru == 'Harcama') {
              targetUpdateQuery =
                  'UPDATE credit_cards SET balance = balance - @amount WHERE id = @id';
            }
            await s.execute(
              Sql.named(targetUpdateQuery),
              parameters: {'amount': tutar, 'id': targetKart.id},
            );
          }
        }
        // E. Personel Entegrasyonu
        else if (locationType == 'personnel') {
          String personelIslemTuru =
              (islemTuru == 'Çıkış' || islemTuru == 'Harcama')
              ? 'payment'
              : 'credit';

          await PersonelIslemleriVeritabaniServisi().entegrasyonKaydiEkle(
            kullaniciId: cariKodu,
            tutar: tutar,
            tarih: tarih,
            aciklama: aciklama,
            islemTuru: personelIslemTuru,
            kaynakTuru: 'Kredi Kartı',
            kaynakId: krediKartiId.toString(),
            ref: finalRef,
            session: s,
          );
        }
        // F. Gelir/Gider Entegrasyonu
        else if (locationType == 'income' || locationType == 'other') {
          debugPrint(
            '📝 Kredi Kartı $locationType işlemi kaydedildi: $tutar ${islemTuru == "Giriş" ? "+" : "-"}',
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

  Future<void> krediKartiIslemSil(
    int id, {
    bool skipLinked = false,
    TxSession? session,
  }) async {
    if (LiteKisitlari.isLiteMode &&
        !LiteKisitlari.isBankCreditActive &&
        !skipLinked) {
      throw const LiteLimitHatasi(
        'LITE sürümde kredi kartı işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    String? entegrasyonRef;

    Future<void> operation(TxSession s) async {
      // 1. İşlemi getir
      final result = await s.execute(
        Sql.named(
          "SELECT * FROM credit_card_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      if (result.isEmpty) return;

      final row = result.first.toColumnMap();
      final double amount =
          double.tryParse(row['amount']?.toString() ?? '') ?? 0.0;
      final String type = row['type'] as String? ?? 'Giriş';
      final int creditCardId = row['credit_card_id'] as int;
      entegrasyonRef = row['integration_ref'] as String?;

      // 2. Bakiyeyi geri al
      String updateQuery =
          'UPDATE credit_cards SET balance = balance - @amount WHERE id = @id';
      if (type == 'Çıkış' || type == 'Harcama') {
        updateQuery =
            'UPDATE credit_cards SET balance = balance + @amount WHERE id = @id';
      }

      await s.execute(
        Sql.named(updateQuery),
        parameters: {'amount': amount, 'id': creditCardId},
      );

      // 3. İşlemi sil
      await s.execute(
        Sql.named(
          "DELETE FROM credit_card_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      // --- ENTEGRASYON: CARİ HESAP (Geri Al) ---
      if (skipLinked) return;
      final String oldType = row['type'] as String? ?? 'Giriş';
      final cariServis = CariHesaplarVeritabaniServisi();

      // Önce kaynak ID ile bulmaya çalış
      int? cariId = await cariServis.cariIdGetirKaynak(
        kaynakTur: 'Kredi Kartı',
        kaynakId: id,
        session: s,
      );

      // Bulunamazsa kod ile bul (Robustness)
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
            WHERE source_type = 'Kredi Kartı' AND source_id = @sourceId
            LIMIT 1
          '''),
          parameters: {'sourceId': id},
        );

        if (existingCariTx.isNotEmpty) {
          bool wasBorc = oldType == 'Çıkış' || oldType == 'Harcama';
          await cariServis.cariIslemSil(
            cariId,
            amount,
            wasBorc,
            kaynakTur: 'Kredi Kartı',
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
        haricKrediKartiIslemId: id,
        silinecekCariyiEtkilesin: false, // Bakiye yukarida manuel silindi
        session: session,
      );
    }
  }

  Future<String> siradakiKrediKartiKodunuGetir({
    bool alfanumerik = true,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return alfanumerik ? 'KK-001' : '1';

    if (!alfanumerik) {
      final result = await _pool!.execute(
        Sql.named('''
	          SELECT COALESCE(MAX(CAST(code AS BIGINT)), 0) 
	          FROM credit_cards
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
	        FROM credit_cards
	        WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId
	          AND code ~ '^KK-[0-9]+\$'
	      '''),
      parameters: {'companyId': _companyId},
    );

    final maxSuffix = int.tryParse(result.first[0]?.toString() ?? '0') ?? 0;
    final nextId = maxSuffix + 1;
    return 'KK-${nextId.toString().padLeft(3, '0')}';
  }

  Future<bool> krediKartiKoduVarMi(String kod, {int? haricId}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    String query =
        "SELECT COUNT(*) FROM credit_cards WHERE code = @code AND COALESCE(company_id, '$_defaultCompanyId') = @companyId";
    Map<String, dynamic> params = {'code': kod, 'companyId': _companyId};

    if (haricId != null) {
      query += ' AND id != @haricId';
      params['haricId'] = haricId;
    }

    final result = await _pool!.execute(Sql.named(query), parameters: params);

    return (result[0][0] as int) > 0;
  }

  Future<List<KrediKartiModel>> krediKartiAra(
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
          FROM credit_cards
          WHERE code = @code
            AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
          ORDER BY id ASC
          LIMIT @limit
        '''),
        parameters: {'code': q, 'companyId': _companyId, 'limit': limit},
      );
      if (byCode.isNotEmpty) {
        return byCode
            .map((row) => _mapToKrediKartiModel(row.toColumnMap()))
            .toList();
      }
    } catch (_) {}

    return krediKartlariniGetir(
      aramaKelimesi: q,
      sayfaBasinaKayit: limit,
      session: session,
    );
  }

  Future<List<KrediKartiModel>> tumKrediKartlariniGetir({
    bool sadeceAktif = true,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    String query = 'SELECT * FROM credit_cards';
    final conditions = <String>[
      "COALESCE(company_id, '$_defaultCompanyId') = @companyId",
    ];
    final params = <String, dynamic>{'companyId': _companyId};

    if (sadeceAktif) {
      conditions.add('is_active = 1');
    }

    query += ' WHERE ${conditions.join(' AND ')}';
    query += ' ORDER BY is_default DESC, id ASC';

    final result = await _pool!.execute(Sql.named(query), parameters: params);

    return result
        .map((row) => _mapToKrediKartiModel(row.toColumnMap()))
        .toList();
  }

  // Helpers
  KrediKartiModel _mapToKrediKartiModel(Map<String, dynamic> map) {
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

    return KrediKartiModel(
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
    final type = map['type'];
    return {
      'id': map['id'],
      'krediKartiKodu': map['kredi_karti_kodu'] ?? '',
      'krediKartiAdi': map['kredi_karti_adi'] ?? '',
      'islem': type ?? '',
      'tarih': map['date'] ?? '',
      'yer': map['location'] ?? '',
      'yerKodu': map['location_code'] ?? '',
      'yerAdi': map['location_name'] ?? '',
      'aciklama': map['description'] ?? '',
      'kullanici': map['user_name'] ?? '',
      'tutar': double.tryParse(map['amount']?.toString() ?? '') ?? 0.0,
      'paraBirimi': map['para_birimi'] ?? 'TRY',
      'isIncoming': type == 'Giriş' || type == 'Ödeme' || type == 'Tahsilat',
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
  Future<void> _createCreditCardPartitions(int year, {Session? session}) async {
    if (_pool == null && session == null) return;
    final executor = session ?? _pool!;

    final partitionName = 'credit_card_transactions_$year';
    final defaultTable = 'credit_card_transactions_default';

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
      return parent == 'credit_card_transactions';
    }

    // 1. DEFAULT Partition
    if (!await isAttached(defaultTable)) {
      if (await isTableExists(defaultTable)) {
        final currentParent = await getParentTable(defaultTable);
        debugPrint(
          '🛠️ Kredi Kartı default partition table $defaultTable detached or attached to $currentParent. Fixing...',
        );
        try {
          if (currentParent != null &&
              currentParent != 'credit_card_transactions') {
            await executor.execute(
              'ALTER TABLE $currentParent DETACH PARTITION $defaultTable',
            );
          }
          await executor.execute(
            'ALTER TABLE credit_card_transactions ATTACH PARTITION $defaultTable DEFAULT',
          );
        } catch (_) {
          await executor.execute('DROP TABLE IF EXISTS $defaultTable CASCADE');
          await executor.execute(
            'CREATE TABLE $defaultTable PARTITION OF credit_card_transactions DEFAULT',
          );
        }
      } else {
        await executor.execute(
          'CREATE TABLE IF NOT EXISTS $defaultTable PARTITION OF credit_card_transactions DEFAULT',
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
          '🛠️ Kredi Kartı partition table $partitionName detached or attached to $currentParent. Attaching...',
        );
        try {
          if (currentParent != null &&
              currentParent != 'credit_card_transactions') {
            await executor.execute(
              'ALTER TABLE $currentParent DETACH PARTITION $partitionName',
            );
          }
          await executor.execute(
            "ALTER TABLE credit_card_transactions ATTACH PARTITION $partitionName FOR VALUES FROM ('$startStr') TO ('$endStr')",
          );
        } catch (e) {
          debugPrint(
            '⚠️ Kredi Kartı attach failed ($partitionName): $e. Recreating...',
          );
          await executor.execute('DROP TABLE IF EXISTS $partitionName CASCADE');
          await executor.execute(
            "CREATE TABLE $partitionName PARTITION OF credit_card_transactions FOR VALUES FROM ('$startStr') TO ('$endStr')",
          );
        }
      } else {
        try {
          await executor.execute(
            "CREATE TABLE IF NOT EXISTS $partitionName PARTITION OF credit_card_transactions FOR VALUES FROM ('$startStr') TO ('$endStr')",
          );
        } catch (e) {
          if (!e.toString().contains('already exists')) rethrow;
        }
      }
    }
  }

  Future<Map<String, dynamic>?> krediKartiIslemGetir(int id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    final result = await _pool!.execute(
      Sql.named(
        "SELECT * FROM credit_card_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
      ),
      parameters: {'id': id, 'companyId': _companyId},
    );

    if (result.isEmpty) return null;
    return _mapToTransaction(result.first.toColumnMap());
  }

  Future<void> krediKartiIslemGuncelle({
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
        'LITE sürümde kredi kartı işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    String? entegrasyonRef;

    Future<void> operation(TxSession s) async {
      // 1. Get old transaction
      final oldResult = await s.execute(
        Sql.named(
          "SELECT * FROM credit_card_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      if (oldResult.isEmpty) return;
      final oldRow = oldResult.first.toColumnMap();
      final double oldAmount =
          double.tryParse(oldRow['amount']?.toString() ?? '') ?? 0.0;
      final String type = oldRow['type'] as String? ?? 'Giriş';
      final int cardId = oldRow['credit_card_id'] as int;
      entegrasyonRef = oldRow['integration_ref'] as String?;

      // 2. Revert Old Balance
      String revertQuery =
          'UPDATE credit_cards SET balance = balance - @amount WHERE id = @id';
      if (type != 'Giriş') {
        revertQuery =
            'UPDATE credit_cards SET balance = balance + @amount WHERE id = @id';
      }
      await s.execute(
        Sql.named(revertQuery),
        parameters: {'amount': oldAmount, 'id': cardId},
      );

      // 3. Update Transaction Record
      await s.execute(
        Sql.named('''
          UPDATE credit_card_transactions 
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
          'UPDATE credit_cards SET balance = balance + @amount WHERE id = @id';
      if (type != 'Giriş') {
        applyQuery =
            'UPDATE credit_cards SET balance = balance - @amount WHERE id = @id';
      }
      await s.execute(
        Sql.named(applyQuery),
        parameters: {'amount': tutar, 'id': cardId},
      );

      // --- ENTEGRASYON: CARİ HESAP ---
      if (!skipLinked) {
        final cariServis = CariHesaplarVeritabaniServisi();
        final String oldTypeStr = oldRow['type'] as String? ?? 'Giriş';
        final bool isBorc = oldTypeStr == 'Çıkış' || oldTypeStr == 'Harcama';

        // 1. İlgili Cari ID'leri Bul
        final int? oldCariId = await cariServis.cariIdGetirKaynak(
          kaynakTur: 'Kredi Kartı',
          kaynakId: id,
          session: s,
        );

        int? newCariId;
        if (cariKodu.isNotEmpty) {
          newCariId = await cariServis.cariIdGetir(cariKodu, session: s);
        }

        // 2. [2025 SMART UPDATE] Eğer Cari Değişmediyse ve Ref Varsa -> Update (Silme Yok)
        if (oldCariId != null &&
            newCariId != null &&
            oldCariId == newCariId &&
            (entegrasyonRef ?? '').isNotEmpty) {
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
          // 3. Fallback: Hesap Değişti veya Ref Yok -> Delete-Then-Insert
          if (oldCariId != null) {
            if ((entegrasyonRef ?? '').isNotEmpty) {
              await cariServis.cariIslemSilByRef(entegrasyonRef!, session: s);
            } else {
              await cariServis.cariIslemSil(
                oldCariId,
                oldAmount,
                isBorc,
                kaynakTur: 'Kredi Kartı',
                kaynakId: id,
                session: s,
              );
            }
          }

          if (newCariId != null &&
              (locationType == 'current_account' || locationType == null)) {
            // Kart bilgilerini çek
            final cardResult = await s.execute(
              Sql.named("SELECT code, name FROM credit_cards WHERE id = @id"),
              parameters: {'id': cardId},
            );
            String cardAdi = '';
            String cardKodu = '';
            if (cardResult.isNotEmpty) {
              final cardRow = cardResult.first.toColumnMap();
              cardKodu = cardRow['code'] as String? ?? '';
              cardAdi = cardRow['name'] as String? ?? '';
            }

            await cariServis.cariIslemEkle(
              cariId: newCariId,
              tutar: tutar,
              isBorc: isBorc,
              islemTuru: 'Kredi Kartı',
              aciklama: aciklama,
              tarih: tarih,
              kullanici: kullanici,
              kaynakId: id,
              kaynakAdi: cardAdi,
              kaynakKodu: cardKodu,
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
        haricKrediKartiIslemId: id,
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
    required int haricKrediKartiIslemId,
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

    // 1) Diğer kredi kartı işlemleri
    final ccRows = await runQuery(
      "SELECT id, location, location_code, location_name FROM credit_card_transactions WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId AND id != @id",
      params: {
        'ref': entegrasyonRef,
        'companyId': _companyId,
        'id': haricKrediKartiIslemId,
      },
    );
    for (final r in ccRows) {
      await krediKartiIslemGuncelle(
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

    // 3) Banka işlemleri
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

    // Personel işlemleri
    await PersonelIslemleriVeritabaniServisi().entegrasyonKaydiGuncelle(
      id: entegrasyonRef,
      tutar: tutar,
      aciklama: aciklama,
      tarih: tarih,
    );
  }
}
