import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import '../sayfalar/ayarlar/kullanicilar/modeller/kullanici_hareket_model.dart';
import 'kasalar_veritabani_servisi.dart';
import 'bankalar_veritabani_servisi.dart';
import 'kredi_kartlari_veritabani_servisi.dart';
import '../sayfalar/ayarlar/kullanicilar/modeller/kullanici_model.dart';
import 'oturum_servisi.dart';
import 'bulut_sema_dogrulama_servisi.dart';
import 'veritabani_yapilandirma.dart';
import 'lisans_yazma_koruma.dart';
import 'dart:async';

class PersonelIslemleriVeritabaniServisi {
  static final PersonelIslemleriVeritabaniServisi _instance =
      PersonelIslemleriVeritabaniServisi._internal();
  factory PersonelIslemleriVeritabaniServisi() => _instance;
  PersonelIslemleriVeritabaniServisi._internal();

  // [2025 FIX] Pool kullanımına geçiş - tek Connection yerine
  Pool? _pool;
  bool _isInitialized = false;
  Completer<void>? _initCompleter;
  int _initToken = 0;

  static const String _defaultCompanyId = 'patisyo2025';
  String get _companyId => OturumServisi().aktifVeritabaniAdi;

  // Merkezi yapılandırma
  final VeritabaniYapilandirma _config = VeritabaniYapilandirma();

  // Partition cache (avoid redundant catalog calls)
  final Set<int> _checkedPartitions = {};
  bool _checkedDefaultPartition = false;

  Future<void> baslat() async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    final initToken = ++_initToken;
    final initCompleter = Completer<void>();
    _initCompleter = initCompleter;

    try {
      final Pool createdPool = LisansKorumaliPool(
        Pool.withEndpoints(
          [
            Endpoint(
              host: _config.host,
              port: _config.port,
              database: OturumServisi().aktifVeritabaniAdi, // Şirket DB
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
        databaseName: OturumServisi().aktifVeritabaniAdi,
      );
      if (!semaHazir) {
        await _tablolariOlustur();
      } else {
        debugPrint(
          'PersonelIslemleriVeritabaniServisi: Bulut şema hazır, tablo kurulumu atlandı.',
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
      if (!initCompleter.isCompleted) {
        initCompleter.complete();
      }
      debugPrint(
        'PersonelIslemleriVeritabaniServisi: Pool bağlantısı başarılı.',
      );
    } catch (e) {
      if (initToken == _initToken) {
        try {
          await _pool?.close();
        } catch (_) {}
        _pool = null;
        _isInitialized = false;
      }
      if (!initCompleter.isCompleted) {
        initCompleter.completeError(e);
      }
      if (identical(_initCompleter, initCompleter)) {
        _initCompleter = null;
      }
      debugPrint('PersonelIslemleriVeritabaniServisi: Connection error: $e');
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

  Future<void> _tablolariOlustur() async {
    if (_pool == null) return;

    // [2025 HYPERSCALE] Personel Hareketleri Tablosu - Native Partitioning Support
    try {
      final tableCheck = await _pool!.execute(
        "SELECT relkind::text FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relname = 'user_transactions'",
      );

      bool tableExists = tableCheck.isNotEmpty;
      bool isPartitioned = false;

      if (tableExists) {
        final String relkind = tableCheck.first[0].toString().toLowerCase();
        isPartitioned = relkind.contains('p');
      }

      // 1) Tablo yoksa: partitioned oluştur
      if (!tableExists) {
        await _pool!.execute('''
          CREATE TABLE IF NOT EXISTS user_transactions (
            id TEXT,
            company_id TEXT,
            user_id TEXT,
            date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            description TEXT,
            debt NUMERIC(15, 2) DEFAULT 0,
            credit NUMERIC(15, 2) DEFAULT 0,
            type TEXT,
            PRIMARY KEY (id, date)
          ) PARTITION BY RANGE (date)
        ''');
        tableExists = true;
        isPartitioned = true;
      }

      // 2) Tablo var ama partitioned değilse: rename + partitioned oluştur
      if (tableExists && !isPartitioned) {
        debugPrint(
          'Personel hareketleri tablosu bölümlendirme moduna geçiriliyor...',
        );
        await _pool!.execute(
          'DROP TABLE IF EXISTS user_transactions_old_non_partitioned CASCADE',
        );
        await _pool!.execute(
          'ALTER TABLE user_transactions RENAME TO user_transactions_old_non_partitioned',
        );

        await _pool!.execute('''
          CREATE TABLE user_transactions (
            id TEXT,
            company_id TEXT,
            user_id TEXT,
            date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            description TEXT,
            debt NUMERIC(15, 2) DEFAULT 0,
            credit NUMERIC(15, 2) DEFAULT 0,
            type TEXT,
            PRIMARY KEY (id, date)
          ) PARTITION BY RANGE (date)
        ''');
        isPartitioned = true;
      }

      // 3) Partition'ların olduğundan emin ol (kasa servisi gibi sağlam)
      if (isPartitioned) {
        final int currentYear = DateTime.now().year;
        await _createUserTransactionPartitions(currentYear);

        // Diğer yılları arka planda hazırla
        if (_config.allowBackgroundDbMaintenance) {
          unawaited(() async {
            try {
              for (
                int year = currentYear - 2;
                year <= currentYear + 5;
                year++
              ) {
                if (year == currentYear) continue;
                await _createUserTransactionPartitions(year);
              }
            } catch (e) {
              debugPrint('Personel arka plan partition kurulum hatası: $e');
            }
          }());
        }
      }

      // 4) Migration: old_non_partitioned varsa aktar
      final oldTableCheck = await _pool!.execute(
        "SELECT 1 FROM pg_class WHERE relname = 'user_transactions_old_non_partitioned' LIMIT 1",
      );

      if (oldTableCheck.isNotEmpty) {
        debugPrint('Eski personel hareketleri yeni bölümlere aktarılıyor...');
        try {
          // Legacy tablo şemasını tespit et (eski sürümlerde company_id yok, date TEXT olabiliyor)
          bool hasCompanyId = false;
          bool hasDateColumn = false;
          String? dateDataType;
          try {
            final cols = await _pool!.execute('''
              SELECT column_name, data_type
              FROM information_schema.columns
              WHERE table_schema = 'public'
                AND table_name = 'user_transactions_old_non_partitioned'
            ''');

            for (final row in cols) {
              final name = (row[0] as String?)?.toLowerCase();
              final dtype = (row[1] as String?)?.toLowerCase();
              if (name == 'company_id') hasCompanyId = true;
              if (name == 'date') {
                hasDateColumn = true;
                dateDataType = dtype;
              }
            }
          } catch (_) {
            // Şema tespiti yapılamazsa, aşağıdaki fallback migration çalışır.
          }

          // Old data yıllarını tespit et ve ilgili partition'ları hazırla
          try {
            final years = await _pool!.execute(
              "SELECT DISTINCT EXTRACT(YEAR FROM COALESCE(date, CURRENT_TIMESTAMP))::int AS y FROM user_transactions_old_non_partitioned",
            );
            for (final row in years) {
              final year = (row[0] as num?)?.toInt();
              if (year != null) {
                await _createUserTransactionPartitions(year);
              }
            }
          } catch (_) {
            // Yıl tespiti başarısız olsa bile DEFAULT partition sayesinde migration devam edebilir.
          }

          final companyExpr = hasCompanyId
              ? "COALESCE(NULLIF(company_id, ''), @companyId)"
              : '@companyId';

          final dateExpr = !hasDateColumn
              ? 'CURRENT_TIMESTAMP'
              : (dateDataType != null && dateDataType.contains('timestamp'))
              ? 'COALESCE(date, CURRENT_TIMESTAMP)'
              : "COALESCE(NULLIF(date::text, ''), CURRENT_TIMESTAMP::text)::timestamp";

          await _pool!.execute(
            Sql.named('''
              INSERT INTO user_transactions (id, company_id, user_id, date, description, debt, credit, type)
              SELECT 
                id,
                $companyExpr,
                user_id,
                $dateExpr,
                description,
                COALESCE(debt, 0)::numeric,
                COALESCE(credit, 0)::numeric,
                type
              FROM user_transactions_old_non_partitioned
              ON CONFLICT (id, date) DO NOTHING
            '''),
            parameters: {'companyId': _companyId},
          );
          await _pool!.execute(
            'DROP TABLE user_transactions_old_non_partitioned CASCADE',
          );
          debugPrint('✅ Personel hareketleri başarıyla bölümlendirildi.');
        } catch (e) {
          debugPrint('❌ Personel migration hatası: $e');
        }
      }
    } catch (e) {
      debugPrint('Personel partitioning hatası: $e');
    }

    try {
      await _pool!.execute(
        'ALTER TABLE user_transactions ADD COLUMN IF NOT EXISTS company_id TEXT',
      );
    } catch (_) {}

    // Outbox Tablosu (Dual-DB Tutarlılığı İçin)
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id SERIAL PRIMARY KEY,
        target_db TEXT, -- 'settings'
        operation TEXT, -- 'update_balance'
        payload JSONB,
        status TEXT DEFAULT 'pending', -- 'pending', 'completed', 'failed'
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP
      )
    ''');

    // [2025 HYPERSCALE] Performans İndeksleri
    try {
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_outbox_status ON sync_outbox (status)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_ut_user_id ON user_transactions (user_id)',
      );

      // BRIN Index for 10B rows (Range Scans)
      await _pool!.execute('''
        CREATE INDEX IF NOT EXISTS idx_ut_date_brin 
        ON user_transactions USING BRIN (date) 
        WITH (pages_per_range = 128)
      ''');

      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_ut_type ON user_transactions (type)',
      );
    } catch (_) {}
  }

  bool _isPartitionError(Object e) {
    final msg = e.toString().toLowerCase();
    // 23514: check_violation (no partition)
    return msg.contains('23514') ||
        msg.contains('partition') ||
        msg.contains('no partition') ||
        msg.contains('failing row contains');
  }

  void _cachePartitionReady(int year) {
    _checkedPartitions.add(year);
    _checkedDefaultPartition = true;
  }

  Future<void> _ensurePartitionExists(int year, {TxSession? session}) async {
    if (_checkedPartitions.contains(year) && _checkedDefaultPartition) return;
    try {
      await _createUserTransactionPartitions(year, session: session);
      _cachePartitionReady(year);
    } catch (e) {
      debugPrint('Personel partition check failed for $year: $e');
    }
  }

  Future<void> _createUserTransactionPartitions(
    int year, {
    TxSession? session,
  }) async {
    final executor = session ?? _pool!;
    if (_pool == null && session == null) return;

    final yearTable = 'user_transactions_$year';
    final defaultTable = 'user_transactions_default';

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
      return parent == 'user_transactions';
    }

    // 1) DEFAULT partition: var ve doğru parent'a bağlı olmalı
    if (!await isAttached(defaultTable)) {
      if (await isTableExists(defaultTable)) {
        final currentParent = await getParentTable(defaultTable);
        try {
          if (currentParent != null && currentParent != 'user_transactions') {
            await executor.execute(
              'ALTER TABLE $currentParent DETACH PARTITION $defaultTable',
            );
          }
          await executor.execute(
            'ALTER TABLE user_transactions ATTACH PARTITION $defaultTable DEFAULT',
          );
        } catch (e) {
          // Çakışan/uyumsuz tablo varsa veri kaybetmeden kenara al ve yeni default oluştur
          final legacyName =
              '${defaultTable}_legacy_${DateTime.now().millisecondsSinceEpoch}';
          try {
            await executor.execute(
              'ALTER TABLE $defaultTable RENAME TO $legacyName',
            );
          } catch (_) {
            // Son çare: attach olamıyorsa ve rename de olmazsa, insertlerin çalışması için drop gerekir
            await executor.execute(
              'DROP TABLE IF EXISTS $defaultTable CASCADE',
            );
          }
          await executor.execute(
            'CREATE TABLE IF NOT EXISTS $defaultTable PARTITION OF user_transactions DEFAULT',
          );
        }
      } else {
        await executor.execute(
          'CREATE TABLE IF NOT EXISTS $defaultTable PARTITION OF user_transactions DEFAULT',
        );
      }
    }

    // 2) Yıllık partition
    if (!await isAttached(yearTable)) {
      final startStr = '$year-01-01';
      final endStr = '${year + 1}-01-01';

      if (await isTableExists(yearTable)) {
        final currentParent = await getParentTable(yearTable);
        try {
          if (currentParent != null && currentParent != 'user_transactions') {
            await executor.execute(
              'ALTER TABLE $currentParent DETACH PARTITION $yearTable',
            );
          }
          await executor.execute(
            "ALTER TABLE user_transactions ATTACH PARTITION $yearTable FOR VALUES FROM ('$startStr') TO ('$endStr')",
          );
        } catch (e) {
          // Eğer attach olamıyorsa: tabloyu legacy olarak sakla ve yeni partition oluştur
          bool renamed = false;
          final legacyName =
              '${yearTable}_legacy_${DateTime.now().millisecondsSinceEpoch}';
          try {
            await executor.execute(
              'ALTER TABLE $yearTable RENAME TO $legacyName',
            );
            renamed = true;
          } catch (_) {
            // Rename olmazsa: aynı yıl için farklı isimle yeni partition oluştur (veri kaybı yok)
            final altTable =
                '${yearTable}_p_${DateTime.now().millisecondsSinceEpoch}';
            await executor.execute(
              "CREATE TABLE IF NOT EXISTS $altTable PARTITION OF user_transactions FOR VALUES FROM ('$startStr') TO ('$endStr')",
            );
            return;
          }

          await executor.execute(
            "CREATE TABLE IF NOT EXISTS $yearTable PARTITION OF user_transactions FOR VALUES FROM ('$startStr') TO ('$endStr')",
          );

          // Legacy tablodan migration dene (başarısız olursa legacy kalır)
          if (renamed) {
            try {
              await executor.execute('''
                INSERT INTO user_transactions (id, company_id, user_id, date, description, debt, credit, type)
                SELECT id, company_id, user_id, date, description, debt, credit, type
                FROM $legacyName
                WHERE date >= TIMESTAMP '$startStr' AND date < TIMESTAMP '$endStr'
                ON CONFLICT (id, date) DO NOTHING
              ''');
            } catch (migrateE) {
              debugPrint('Personel legacy partition migrate failed: $migrateE');
            }
          }
        }
      } else {
        await executor.execute(
          "CREATE TABLE IF NOT EXISTS $yearTable PARTITION OF user_transactions FOR VALUES FROM ('$startStr') TO ('$endStr')",
        );
      }
    }
  }

  /// Settings DB üzerindeki (patisyosettings) Kullanıcı Bakiyesini günceller.
  /// [2025 OUTBOX PATTERN] Doğrudan bağlantı yerine Outbox tablosuna yazar.
  /// Gerçek senkronizasyon processOutbox() üzerinden yapılır.
  Future<void> _updateBalanceInSettings(
    String userId,
    double debtDelta,
    double creditDelta, {
    required TxSession session,
  }) async {
    if (debtDelta == 0 && creditDelta == 0) return;

    await session.execute(
      Sql.named('''
        INSERT INTO sync_outbox (target_db, operation, payload, status)
        VALUES ('settings', 'update_balance', @payload, 'pending')
      '''),
      parameters: {
        'payload': {
          'user_id': userId,
          'debt_delta': debtDelta,
          'credit_delta': creditDelta,
        },
      },
    );
  }

  /// Outbox tablosundaki bekleyen senkronizasyonları temizler.
  Future<void> processOutbox() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // Bekleyenleri al
    final pending = await _pool!.execute(
      "SELECT id, payload FROM sync_outbox WHERE status = 'pending' OR (status = 'failed' AND retry_count < 5) ORDER BY id ASC LIMIT 10",
    );

    if (pending.isEmpty) return;

    Connection? settingsConn;
    try {
      settingsConn = await Connection.open(
        Endpoint(
          host: _config.host,
          port: _config.port,
          database: _config.database, // Settings DB
          username: _config.username,
          password: _config.password,
        ),
        settings: ConnectionSettings(sslMode: _config.sslMode),
      );

      for (final row in pending) {
        final int outboxId = row[0] as int;
        final payload = row[1] as Map<String, dynamic>;
        final String userId = payload['user_id'];
        final double debtDelta =
            double.tryParse(payload['debt_delta']?.toString() ?? '0') ?? 0.0;
        final double creditDelta =
            double.tryParse(payload['credit_delta']?.toString() ?? '0') ?? 0.0;

        try {
          if (debtDelta != 0) {
            await settingsConn.execute(
              Sql.named(
                "UPDATE users SET balance_debt = COALESCE(balance_debt, 0) + @val WHERE id = @uid",
              ),
              parameters: {'val': debtDelta, 'uid': userId},
            );
          }
          if (creditDelta != 0) {
            await settingsConn.execute(
              Sql.named(
                "UPDATE users SET balance_credit = COALESCE(balance_credit, 0) + @val WHERE id = @uid",
              ),
              parameters: {'val': creditDelta, 'uid': userId},
            );
          }

          // Başarılı ise işaretle
          await _pool!.execute(
            Sql.named(
              "UPDATE sync_outbox SET status = 'completed', updated_at = CURRENT_TIMESTAMP WHERE id = @id",
            ),
            parameters: {'id': outboxId},
          );
        } catch (innerE) {
          debugPrint('Sync Item Error (ID: $outboxId): $innerE');
          await _pool!.execute(
            Sql.named('''
              UPDATE sync_outbox 
              SET status = 'failed', 
                  retry_count = retry_count + 1, 
                  last_error = @err,
                  updated_at = CURRENT_TIMESTAMP 
              WHERE id = @id
            '''),
            parameters: {'id': outboxId, 'err': innerE.toString()},
          );
        }
      }
    } catch (e) {
      debugPrint('Process Outbox Connection Error: $e');
    } finally {
      await settingsConn?.close();
    }
  }

  Future<List<KullaniciHareketModel>> kullaniciHareketleriniGetir(
    String kullaniciId,
  ) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    final result = await _pool!.execute(
      Sql.named(
        "SELECT * FROM user_transactions WHERE user_id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId ORDER BY date DESC",
      ),
      parameters: {'id': kullaniciId, 'companyId': _companyId},
    );

    return result.map((row) {
      final map = row.toColumnMap();
      return KullaniciHareketModel(
        id: map['id'] as String,
        kullaniciId: map['user_id'] as String,
        tarih: map['date'] is DateTime
            ? map['date'] as DateTime
            : DateTime.parse(map['date'] as String),
        aciklama: map['description'] as String,
        borc: double.tryParse(map['debt']?.toString() ?? '') ?? 0.0,
        alacak: double.tryParse(map['credit']?.toString() ?? '') ?? 0.0,
        islemTuru: map['type'] as String,
      );
    }).toList();
  }

  /// Ödeme Yap (Şirket -> Personel)
  /// [ACID] Atomik Transaction: Hem kaynaktan düşer, hem personelin hesabına işler.
  Future<void> odemeYap({
    required KullaniciModel kullanici,
    required double tutar,
    required DateTime tarih,
    required String aciklama,
    required String kaynakTuru, // 'cash', 'bank', 'credit_card'
    required String kaynakId,
    required String kaynakAdi,
    required String islemYapanKullaniciAdi,
    TxSession? session,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    Future<void> operation(TxSession s) async {
      final String entegrasyonRef =
          'PERS-${DateTime.now().millisecondsSinceEpoch}';

      // 1. Kaynaktan Para Çıkışı (Kasa/Banka/Kart)
      if (kaynakTuru == 'cash') {
        await KasalarVeritabaniServisi().kasaIslemEkle(
          kasaId: int.parse(kaynakId),
          tutar: tutar,
          islemTuru: 'Ödeme', // Para Çıkar
          aciklama: aciklama,
          tarih: tarih,
          cariTuru: 'Personel',
          cariKodu: kullanici.id,
          cariAdi: '${kullanici.ad} ${kullanici.soyad}',
          kullanici: islemYapanKullaniciAdi,
          entegrasyonRef: entegrasyonRef,
          locationType: 'personnel',
          session: s,
        );
      } else if (kaynakTuru == 'bank') {
        await BankalarVeritabaniServisi().bankaIslemEkle(
          bankaId: int.parse(kaynakId),
          tutar: tutar,
          islemTuru: 'Ödeme', // Para Çıkar
          aciklama: aciklama,
          tarih: tarih,
          cariTuru: 'Personel',
          cariKodu: kullanici.id,
          cariAdi: '${kullanici.ad} ${kullanici.soyad}',
          kullanici: islemYapanKullaniciAdi,
          entegrasyonRef: entegrasyonRef,
          locationType: 'personnel',
          session: s,
        );
      } else if (kaynakTuru == 'credit_card') {
        await KrediKartlariVeritabaniServisi().krediKartiIslemEkle(
          krediKartiId: int.parse(kaynakId),
          tutar: tutar,
          islemTuru: 'Çıkış', // Para Çıkar
          aciklama: aciklama,
          tarih: tarih,
          cariTuru: 'Personel',
          cariKodu: kullanici.id,
          cariAdi: '${kullanici.ad} ${kullanici.soyad}',
          kullanici: islemYapanKullaniciAdi,
          entegrasyonRef: entegrasyonRef,
          locationType: 'personnel',
          session: s,
        );
      }
    }

    if (session != null) {
      await operation(session);
    } else {
      await _pool!.runTx((s) async {
        await operation(s);
      });
      unawaited(processOutbox());
    }
  }

  /// Alacaklandır (Personel -> Şirket)
  Future<void> alacaklandir({
    required KullaniciModel kullanici,
    required double tutar,
    required DateTime tarih,
    required String aciklama,
    TxSession? session,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    Future<void> operation(TxSession s) async {
      await _ensurePartitionExists(tarih.year, session: s);
      final String hareketId = DateTime.now().millisecondsSinceEpoch.toString();
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          await s.execute(
            Sql.named('''
              INSERT INTO user_transactions (id, company_id, user_id, date, description, debt, credit, type)
              VALUES (@id, @company_id, @user_id, @date, @description, 0, @credit, 'credit')
            '''),
            parameters: {
              'id': hareketId,
              'company_id': _companyId,
              'user_id': kullanici.id,
              'date': tarih.toIso8601String(),
              'description': aciklama,
              'credit': tutar,
            },
          );
          break;
        } catch (e) {
          if (attempt == 0 && _isPartitionError(e)) {
            await _ensurePartitionExists(tarih.year, session: s);
            continue;
          }
          rethrow;
        }
      }

      // Bakiye Senkronizasyonu (Settings DB - Alacaklandır = Credit Artar)
      await _updateBalanceInSettings(kullanici.id, 0, tutar, session: s);
    }

    if (session != null) {
      await operation(session);
    } else {
      await _pool!.runTx((s) async {
        await operation(s);
      });
      unawaited(processOutbox());
    }
  }

  /// Entegrasyon Kaydı Ekle
  Future<void> entegrasyonKaydiEkle({
    required String kullaniciId,
    required double tutar,
    required DateTime tarih,
    required String aciklama,
    required String islemTuru, // 'payment' (Borç/Debit) veya 'credit' (Alacak)
    required String kaynakTuru,
    required String kaynakId,
    String? ref,
    TxSession? session,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    Future<void> operation(TxSession s) async {
      await _ensurePartitionExists(tarih.year, session: s);
      final String hareketId =
          ref ?? DateTime.now().millisecondsSinceEpoch.toString();
      double debt = 0;
      double credit = 0;
      if (islemTuru == 'payment') {
        debt = tutar;
      } else {
        credit = tutar;
      }

      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          await s.execute(
            Sql.named('''
              INSERT INTO user_transactions (id, company_id, user_id, date, description, debt, credit, type)
              VALUES (@id, @company_id, @user_id, @date, @description, @debt, @credit, @type)
            '''),
            parameters: {
              'id': hareketId,
              'company_id': _companyId,
              'user_id': kullaniciId,
              'date': tarih.toIso8601String(),
              'description': aciklama,
              'debt': debt,
              'credit': credit,
              'type': islemTuru,
            },
          );
          break;
        } catch (e) {
          if (attempt == 0 && _isPartitionError(e)) {
            await _ensurePartitionExists(tarih.year, session: s);
            continue;
          }
          rethrow;
        }
      }

      // Bakiye Senkronizasyonu
      if (islemTuru == 'payment') {
        await _updateBalanceInSettings(kullaniciId, tutar, 0, session: s);
      } else {
        await _updateBalanceInSettings(kullaniciId, 0, tutar, session: s);
      }
    }

    if (session != null) {
      await operation(session);
    } else {
      await _pool!.runTx((s) async {
        await operation(s);
      });
      unawaited(processOutbox());
    }
  }

  /// Entegrasyon Kaydı Sil
  Future<void> entegrasyonKaydiSil(String id, {TxSession? session}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    String? userId;
    double debt = 0;
    double credit = 0;

    Future<void> operation(TxSession s) async {
      final result = await s.execute(
        Sql.named(
          "SELECT * FROM user_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );
      if (result.isEmpty) return;

      final row = result.first.toColumnMap();
      userId = row['user_id'] as String;
      debt = double.tryParse(row['debt']?.toString() ?? '') ?? 0.0;
      credit = double.tryParse(row['credit']?.toString() ?? '') ?? 0.0;

      await s.execute(
        Sql.named("DELETE FROM user_transactions WHERE id = @id"),
        parameters: {'id': id},
      );

      // Settings DB'den bakiyeyi düş (Transaction içinde olmalı)
      if (userId != null) {
        await _updateBalanceInSettings(userId!, -debt, -credit, session: s);
      }
    }

    if (session != null) {
      await operation(session);
    } else {
      await _pool!.runTx((s) => operation(s));
      unawaited(processOutbox());
    }

    // Bağlı işlemleri sil (Kasa/Banka/Kart)
    if (userId != null) {
      await KasalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
        id,
        haricKasaIslemId: -1,
        session: session,
      );
      await BankalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
        id,
        haricBankaIslemId: -1,
        session: session,
      );
      await KrediKartlariVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
        id,
        haricKrediKartiIslemId: -1,
        session: session,
      );
    }
  }

  /// Entegrasyon Kaydı Güncelle
  Future<void> entegrasyonKaydiGuncelle({
    required String id,
    double? tutar,
    String? aciklama,
    DateTime? tarih,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // 1. Get Old
      final result = await session.execute(
        Sql.named("SELECT * FROM user_transactions WHERE id = @id"),
        parameters: {'id': id},
      );
      if (result.isEmpty) return;
      final row = result.first.toColumnMap();
      final String userId = row['user_id'] as String;
      final double oldDebt =
          double.tryParse(row['debt']?.toString() ?? '') ?? 0.0;
      final double oldCredit =
          double.tryParse(row['credit']?.toString() ?? '') ?? 0.0;
      final type = row['type'] as String;

      // 2. Prepare New Values
      final newDate = tarih != null ? tarih.toIso8601String() : row['date'];
      final newDesc = aciklama ?? row['description'];
      final double newAmount =
          tutar ?? (type == 'payment' ? oldDebt : oldCredit);

      double newDebt = 0;
      double newCredit = 0;
      if (type == 'payment') {
        newDebt = newAmount;
      } else {
        newCredit = newAmount;
      }

      // 3. Update Transaction
      await session.execute(
        Sql.named(
          "UPDATE user_transactions SET date=@date, description=@desc, debt=@debt, credit=@credit WHERE id=@id",
        ),
        parameters: {
          'date': newDate,
          'desc': newDesc,
          'debt': newDebt,
          'credit': newCredit,
          'id': id,
        },
      );

      // 4. Update Balance in Settings DB (Revert old, apply new)
      await _updateBalanceInSettings(
        userId,
        -oldDebt,
        -oldCredit,
        session: session,
      );
      await _updateBalanceInSettings(
        userId,
        newDebt,
        newCredit,
        session: session,
      );
    });
    unawaited(processOutbox());
  }
}
