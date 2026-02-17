import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:intl/intl.dart';
import 'cari_hesaplar_veritabani_servisi.dart';
import 'kasalar_veritabani_servisi.dart';
import 'bankalar_veritabani_servisi.dart';
import 'oturum_servisi.dart';
import 'bulut_sema_dogrulama_servisi.dart';
import 'pg_eklentiler.dart';
import '../sayfalar/ceksenet/modeller/senet_model.dart';
import 'veritabani_yapilandirma.dart';
import 'kredi_kartlari_veritabani_servisi.dart';
import 'lisans_yazma_koruma.dart';
import 'lite_kisitlari.dart';

import '../yardimcilar/ceviri/islem_ceviri_yardimcisi.dart';
import '../yardimcilar/islem_turu_renkleri.dart';

class SenetlerVeritabaniServisi {
  static final SenetlerVeritabaniServisi _instance =
      SenetlerVeritabaniServisi._internal();
  factory SenetlerVeritabaniServisi() => _instance;
  SenetlerVeritabaniServisi._internal();

  Pool? _pool;
  bool _isInitialized = false;
  String? _initializedDatabase;
  static const String _searchTagsVersionPrefix = 'v2';

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

  String _buildNoteSearchTags(
    SenetModel senet, {
    required String integrationRef,
  }) {
    // UI'da görünen translate edilmiş durumları da ekle
    final turLabel = senet.tur == 'Alınan Senet'
        ? 'Alınan Senet'
        : 'Verilen Senet';

    final tahsilatLabel = IslemCeviriYardimcisi.cevirDurum(senet.tahsilat);

    return _normalizeTurkish(
      '$_searchTagsVersionPrefix '
      '${senet.tur} '
      '$turLabel '
      '${senet.tahsilat} '
      '$tahsilatLabel '
      '${senet.cariKod} '
      '${senet.cariAdi} '
      '${senet.duzenlenmeTarihi} '
      '${senet.kesideTarihi} '
      '${senet.tutar} '
      '${senet.paraBirimi} '
      '${senet.senetNo} '
      '${senet.banka} '
      '${senet.aciklama} '
      '${senet.kullanici} '
      '${senet.aktifMi ? 'aktif' : 'pasif'} '
      '$integrationRef',
    );
  }

  String _buildNoteTransactionSearchTags({
    required DateTime date,
    required String description,
    required double amount,
    required String type,
    required String sourceDest,
    required String userName,
    required String integrationRef,
  }) {
    final String dateText = DateFormat('dd.MM.yyyy HH:mm').format(date);

    // UI'da gösterilen profesyonel etiketi al ve çevir
    final String professionalLabel = IslemCeviriYardimcisi.cevir(
      IslemTuruRenkleri.getProfessionalLabel(type, context: 'promissory_note'),
    );

    return _normalizeTurkish(
      '$_searchTagsVersionPrefix '
      '$type '
      '$professionalLabel '
      '$dateText '
      '$description '
      '$sourceDest '
      '$userName '
      '$amount '
      '$integrationRef',
    );
  }

  // Merkezi yapılandırma
  final VeritabaniYapilandirma _config = VeritabaniYapilandirma();

  Future<void> baslat() async {
    final targetDatabase = OturumServisi().aktifVeritabaniAdi;
    if (_isInitialized && _initializedDatabase == targetDatabase) return;

    try {
      if (_pool != null && _initializedDatabase != targetDatabase) {
        try {
          await _pool!.close();
        } catch (_) {}
        _pool = null;
        _isInitialized = false;
      }

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

      final semaHazir = await BulutSemaDogrulamaServisi().bulutSemasiHazirMi(
        executor: _pool!,
        databaseName: targetDatabase,
      );
      if (!semaHazir) {
        await _tablolariOlustur();
      } else {
        debugPrint(
          'SenetlerVeritabaniServisi: Bulut şema hazır, tablo kurulumu atlandı.',
        );
      }
      _isInitialized = true;
      _initializedDatabase = targetDatabase;
      debugPrint(
        'SenetlerVeritabaniServisi: Pool connection established successfully.',
      );
    } catch (e) {
      debugPrint('SenetlerVeritabaniServisi: Connection error: $e');
    }
  }

  /// Pool bağlantısını güvenli şekilde kapatır ve tüm durum değişkenlerini sıfırlar.
  Future<void> baglantiyiKapat() async {
    try {
      await _pool?.close();
    } catch (_) {}
    _pool = null;
    _isInitialized = false;
    _initializedDatabase = null;
  }

  Future<void> _tablolariOlustur() async {
    if (_pool == null) return;

    // Create Promissory Notes Table
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS promissory_notes (
        id SERIAL PRIMARY KEY,
        company_id TEXT,
        type TEXT, -- Alınan Senet / Verilen Senet
        collection_status TEXT,
        customer_code TEXT,
        customer_name TEXT,
        issue_date TIMESTAMP,
        due_date TIMESTAMP,
        amount NUMERIC(15, 2) DEFAULT 0,
        currency TEXT,
        note_no TEXT, -- Senet No
        bank TEXT, -- Opsiyonel (kefil vs için kullanılabilir veya boş)
        description TEXT,
        user_name TEXT,
        is_active INTEGER DEFAULT 1,
        search_tags TEXT,
        matched_in_hidden INTEGER DEFAULT 0,
        integration_ref TEXT
      )
    ''');

    // Create Note Transactions Table
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS note_transactions (
        id SERIAL PRIMARY KEY,
        company_id TEXT,
        note_id INTEGER,
        date TIMESTAMP,
        description TEXT,
        amount NUMERIC(15, 2) DEFAULT 0,
        type TEXT,
        source_dest TEXT,
        user_name TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        search_tags TEXT,
        integration_ref TEXT
      )
    ''');

    // Migration: company_id columns and search_tags
    try {
      await _pool!.execute(
        'ALTER TABLE promissory_notes ADD COLUMN IF NOT EXISTS company_id TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE note_transactions ADD COLUMN IF NOT EXISTS company_id TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE note_transactions ADD COLUMN IF NOT EXISTS integration_ref TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE note_transactions ADD COLUMN IF NOT EXISTS search_tags TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE promissory_notes ADD COLUMN IF NOT EXISTS integration_ref TEXT',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_notes_ref ON promissory_notes (integration_ref)',
      );
    } catch (_) {}

    // [2026 FIX] Türkçe normalize fonksiyonu (Cari araması ile uyumlu)
    try {
      await _pool!.execute('''
        -- Hyper-Optimized Turkish Normalization for 100B+ Rows
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

    // 1 Milyar Kayıt İçin Performans İndeksleri (GIN Trigram)
    try {
      await PgEklentiler.ensurePgTrgm(_pool!);

      // Senetler için trigram indeksleri
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_notes_search_tags_gin ON promissory_notes USING GIN (search_tags gin_trgm_ops)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_notes_note_no_trgm ON promissory_notes USING GIN (note_no gin_trgm_ops)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_notes_customer_name_trgm ON promissory_notes USING GIN (customer_name gin_trgm_ops)',
      );

      // Senet işlemleri için trigram indeksleri
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_note_transactions_search_tags_gin ON note_transactions USING GIN (search_tags gin_trgm_ops)',
      );

      // B-Tree indeksleri (filtre ve sıralama için)
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_notes_company_id ON promissory_notes (company_id)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_notes_is_active ON promissory_notes (is_active)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_notes_type ON promissory_notes (type)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_note_transactions_note_id ON note_transactions (note_id)',
      );

      // [2025 HYPERSCALE] BRIN Index for 10B rows (Range Scans)
      try {
        await _pool!.execute('''
          CREATE INDEX IF NOT EXISTS idx_notes_issue_date_brin 
          ON promissory_notes USING BRIN (issue_date) 
          WITH (pages_per_range = 128)
        ''');
        await _pool!.execute('''
          CREATE INDEX IF NOT EXISTS idx_notes_due_date_brin 
          ON promissory_notes USING BRIN (due_date) 
          WITH (pages_per_range = 128)
        ''');
      } catch (e) {
        debugPrint('BRIN index error: $e');
      }

      debugPrint(
        '🚀 Senetler Performans Modu: GIN ve B-Tree indeksleri hazır.',
      );
    } catch (e) {
      debugPrint('⚠️ Senet indeksleri oluşturulurken uyarı: $e');
    }

    // Initial indeksleme: arka planda çalıştır (sayfa açılışını bloklama)
    Future(() async {
      await verileriIndeksle(forceUpdate: false);
    });
  }

  /// Senetler ve senet hareketleri için search_tags indekslemesi yapar (Batch Processing)
  /// - forceUpdate=false: sadece v2 olmayan / boş search_tags kayıtlarını günceller
  Future<void> verileriIndeksle({bool forceUpdate = true}) async {
    if (_pool == null) return;

    try {
      debugPrint('🚀 Senet Arama İndeksleme Başlatılıyor (Batch Modu)...');

      const int batchSize = 500;
      int processedNotes = 0;
      int processedTransactions = 0;

      final String versionPredicate =
          "(search_tags IS NULL OR search_tags = '' OR search_tags NOT LIKE '$_searchTagsVersionPrefix%')";

      // 1) promissory_notes (main)
      int lastId = 0;
      while (true) {
        final idRows = await _pool!.execute(
          Sql.named(
            "SELECT id FROM promissory_notes WHERE id > @lastId AND COALESCE(company_id, '$_defaultCompanyId') = @companyId ${forceUpdate ? '' : 'AND $versionPredicate'} ORDER BY id ASC LIMIT @batchSize",
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
            ? ''
            : ' AND $versionPredicate';

        await _pool!.execute(
          Sql.named('''
            UPDATE promissory_notes p
            SET search_tags = normalize_text(
              '$_searchTagsVersionPrefix ' ||
              COALESCE(p.type, '') || ' ' ||
              COALESCE(p.collection_status, '') || ' ' ||
              COALESCE(p.customer_code, '') || ' ' ||
              COALESCE(p.customer_name, '') || ' ' ||
              COALESCE(TO_CHAR(p.issue_date, 'DD.MM.YYYY'), '') || ' ' ||
              COALESCE(TO_CHAR(p.due_date, 'DD.MM.YYYY'), '') || ' ' ||
              COALESCE(CAST(p.amount AS TEXT), '') || ' ' ||
              COALESCE(p.currency, '') || ' ' ||
              COALESCE(p.note_no, '') || ' ' ||
              COALESCE(p.bank, '') || ' ' ||
              COALESCE(p.description, '') || ' ' ||
              COALESCE(p.user_name, '') || ' ' ||
              CAST(p.id AS TEXT) || ' ' ||
              (CASE WHEN p.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
              COALESCE(p.integration_ref, '')
            )
            WHERE p.id IN ($idListStr)
              AND COALESCE(p.company_id, '$_defaultCompanyId') = @companyId
              $conditionalWhere
          '''),
          parameters: {'companyId': _companyId},
        );

        processedNotes += ids.length;
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // 2) note_transactions
      lastId = 0;
      while (true) {
        final idRows = await _pool!.execute(
          Sql.named(
            "SELECT id FROM note_transactions WHERE id > @lastId AND COALESCE(company_id, '$_defaultCompanyId') = @companyId ${forceUpdate ? '' : 'AND $versionPredicate'} ORDER BY id ASC LIMIT @batchSize",
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
            ? ''
            : ' AND $versionPredicate';

        await _pool!.execute(
          Sql.named('''
            UPDATE note_transactions nt
            SET search_tags = normalize_text(
              '$_searchTagsVersionPrefix ' ||
              COALESCE(nt.type, '') || ' ' ||
              COALESCE(TO_CHAR(nt.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
              COALESCE(nt.description, '') || ' ' ||
              COALESCE(nt.source_dest, '') || ' ' ||
              COALESCE(nt.user_name, '') || ' ' ||
              COALESCE(CAST(nt.amount AS TEXT), '') || ' ' ||
              CAST(nt.id AS TEXT) || ' ' ||
              COALESCE(nt.integration_ref, '')
            )
            WHERE nt.id IN ($idListStr)
              AND COALESCE(nt.company_id, '$_defaultCompanyId') = @companyId
              $conditionalWhere
          '''),
          parameters: {'companyId': _companyId},
        );

        processedTransactions += ids.length;
        await Future.delayed(const Duration(milliseconds: 10));
      }

      debugPrint(
        '✅ Senet Arama İndeksleri Tamamlandı (forceUpdate: $forceUpdate). Senet: $processedNotes, Hareket: $processedTransactions',
      );
    } catch (e) {
      if (e is LisansYazmaEngelliHatasi) return;
      debugPrint('Senet indeksleme sırasında hata: $e');
    }
  }

  Future<void> _updateNoteSearchTags(int senetId, TxSession session) async {
    await session.execute(
      Sql.named('''
        UPDATE promissory_notes p
        SET search_tags = normalize_text(
          '$_searchTagsVersionPrefix ' ||
          COALESCE(p.type, '') || ' ' ||
          COALESCE(p.collection_status, '') || ' ' ||
          COALESCE(p.customer_code, '') || ' ' ||
          COALESCE(p.customer_name, '') || ' ' ||
          COALESCE(TO_CHAR(p.issue_date, 'DD.MM.YYYY'), '') || ' ' ||
          COALESCE(TO_CHAR(p.due_date, 'DD.MM.YYYY'), '') || ' ' ||
          COALESCE(CAST(p.amount AS TEXT), '') || ' ' ||
          COALESCE(p.currency, '') || ' ' ||
          COALESCE(p.note_no, '') || ' ' ||
          COALESCE(p.bank, '') || ' ' ||
          COALESCE(p.description, '') || ' ' ||
          COALESCE(p.user_name, '') || ' ' ||
          CAST(p.id AS TEXT) || ' ' ||
          (CASE WHEN p.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
          COALESCE(p.integration_ref, '')
        )
        WHERE p.id = @id
          AND COALESCE(p.company_id, '$_defaultCompanyId') = @companyId
      '''),
      parameters: {'id': senetId, 'companyId': _companyId},
    );
  }

  /// Senetleri getirir - 1 Milyar Kayıt İçin Optimize Edilmiş Derin Arama
  ///
  /// [aramaKelimesi] hem ana alanlarda hem de detay işlemlerinde arama yapar.
  /// Eğer arama terimi sadece detay işlemlerinde bulunursa [matchedInHidden] true döner.
  Future<List<SenetModel>> senetleriGetir({
    int sayfa = 1,
    int sayfaBasinaKayit = 25,
    String? aramaKelimesi,
    String? siralama,
    bool artanSiralama = true,
    bool? aktifMi,
    String? banka,
    String? kullanici,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? islemTuru,
    int? senetId,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    // 1 Milyar Kayıt Optimizasyonu: Deep Search (Derin Arama)
    String selectClause = 'SELECT promissory_notes.*';

    if (aramaKelimesi != null && aramaKelimesi.isNotEmpty) {
      selectClause +=
          '''
          , (CASE 
              WHEN (
                normalize_text(COALESCE(promissory_notes.customer_code, '')) LIKE @search OR
                normalize_text(COALESCE(promissory_notes.description, '')) LIKE @search OR
                normalize_text(COALESCE(promissory_notes.user_name, '')) LIKE @search OR
                normalize_text(COALESCE(promissory_notes.collection_status, '')) LIKE @search OR
                EXISTS (
                  SELECT 1 FROM note_transactions nt 
                  WHERE nt.note_id = promissory_notes.id 
                  AND COALESCE(nt.company_id, '$_defaultCompanyId') = @companyId
                  AND COALESCE(nt.search_tags, '') LIKE @search
                )
              )
              THEN 1 
              ELSE 0 
             END) as matched_in_hidden_calc
      ''';
    } else {
      selectClause += ', 0 as matched_in_hidden_calc';
    }

    List<String> conditions = [];
    Map<String, dynamic> params = {'companyId': _companyId};

    conditions.add(
      "COALESCE(promissory_notes.company_id, '$_defaultCompanyId') = @companyId",
    );

    if (aramaKelimesi != null && aramaKelimesi.isNotEmpty) {
      conditions.add('''
        (
          COALESCE(promissory_notes.search_tags, '') LIKE @search
          OR promissory_notes.id IN (
            SELECT nt.note_id
            FROM note_transactions nt
            WHERE COALESCE(nt.company_id, '$_defaultCompanyId') = @companyId
            AND COALESCE(nt.search_tags, '') LIKE @search
            GROUP BY nt.note_id
          )
        )
      ''');
      params['search'] = '%${_normalizeTurkish(aramaKelimesi)}%';
    }

    if (aktifMi != null) {
      conditions.add('promissory_notes.is_active = @isActive');
      params['isActive'] = aktifMi ? 1 : 0;
    }

    if (banka != null && banka.isNotEmpty) {
      conditions.add('promissory_notes.bank = @banka');
      params['banka'] = banka;
    }

    // [2026 FACET FILTER] Tarih aralığı + işlem türü filtreleri transaction tablosundan uygulanır.
    // Bu sayede "Senet Alındı / Tahsil Edildi / Ciro Edildi" gibi gerçek hareket türleriyle filtreleme yapılır.
    if ((baslangicTarihi != null || bitisTarihi != null) ||
        (islemTuru != null && islemTuru.isNotEmpty) ||
        (kullanici != null && kullanici.isNotEmpty)) {
      String existsQuery =
          "EXISTS (SELECT 1 FROM note_transactions nt WHERE nt.note_id = promissory_notes.id AND COALESCE(nt.company_id, '$_defaultCompanyId') = @companyId";

      if (baslangicTarihi != null) {
        existsQuery += ' AND nt.date >= @startDate';
        params['startDate'] = DateTime(
          baslangicTarihi.year,
          baslangicTarihi.month,
          baslangicTarihi.day,
        ).toIso8601String();
      }

      if (bitisTarihi != null) {
        existsQuery += ' AND nt.date < @endDate';
        params['endDate'] = DateTime(
          bitisTarihi.year,
          bitisTarihi.month,
          bitisTarihi.day,
        ).add(const Duration(days: 1)).toIso8601String();
      }

      if (islemTuru != null && islemTuru.isNotEmpty) {
        existsQuery += ' AND nt.type = @islemTuru';
        params['islemTuru'] = islemTuru;
      }

      if (kullanici != null && kullanici.isNotEmpty) {
        existsQuery += ' AND nt.user_name = @kullanici';
        params['kullanici'] = kullanici;
      }

      existsQuery += ')';
      conditions.add(existsQuery);
    }

    if (senetId != null) {
      conditions.add('promissory_notes.id = @senetId');
      params['senetId'] = senetId;
    }

    String whereClause = '';
    if (conditions.isNotEmpty) {
      whereClause = ' WHERE ${conditions.join(' AND ')}';
    }

    // Sorting
    String orderBy = 'promissory_notes.id';
    if (siralama != null) {
      switch (siralama) {
        case 'kod':
          orderBy = 'promissory_notes.note_no';
          break;
        case 'ad':
          orderBy = 'promissory_notes.customer_name';
          break;
        case 'bakiye':
          orderBy = 'promissory_notes.amount';
          break;
        case 'duzenlenmeTarihi':
          orderBy = 'promissory_notes.issue_date';
          break;
        case 'kesideTarihi':
          orderBy = 'promissory_notes.due_date';
          break;
      }
    }

    String query =
        '''
      $selectClause
      FROM promissory_notes
      $whereClause
      ORDER BY $orderBy ${artanSiralama ? 'ASC' : 'DESC'}
      LIMIT @limit OFFSET @offset
    ''';

    params['limit'] = sayfaBasinaKayit;
    params['offset'] = (sayfa - 1) * sayfaBasinaKayit;

    final result = await _pool!.execute(Sql.named(query), parameters: params);

    return result.map((row) {
      final map = row.toColumnMap();
      final matchedInHiddenCalc = (map['matched_in_hidden_calc'] as int?) == 1;
      return _mapToSenetModel(
        map,
        matchedInHiddenOverride: matchedInHiddenCalc,
      );
    }).toList();
  }

  /// Senet sayısını getirir - Derin arama destekli
  Future<int> senetSayisiGetir({
    String? aramaTerimi,
    bool? aktifMi,
    String? banka,
    String? kullanici,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? islemTuru,
    int? senetId,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;

    String query =
        'SELECT COUNT(DISTINCT promissory_notes.id) FROM promissory_notes';
    List<String> conditions = [];
    Map<String, dynamic> params = {'companyId': _companyId};

    conditions.add(
      "COALESCE(promissory_notes.company_id, '$_defaultCompanyId') = @companyId",
    );

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      conditions.add('''
        (
          COALESCE(promissory_notes.search_tags, '') LIKE @search
          OR promissory_notes.id IN (
            SELECT nt.note_id
            FROM note_transactions nt
            WHERE COALESCE(nt.company_id, '$_defaultCompanyId') = @companyId
            AND COALESCE(nt.search_tags, '') LIKE @search
            GROUP BY nt.note_id
          )
        )
      ''');
      params['search'] = '%${_normalizeTurkish(aramaTerimi)}%';
    }

    if (aktifMi != null) {
      conditions.add('promissory_notes.is_active = @isActive');
      params['isActive'] = aktifMi ? 1 : 0;
    }

    if (banka != null && banka.isNotEmpty) {
      conditions.add('promissory_notes.bank = @banka');
      params['banka'] = banka;
    }

    if ((baslangicTarihi != null || bitisTarihi != null) ||
        (islemTuru != null && islemTuru.isNotEmpty) ||
        (kullanici != null && kullanici.isNotEmpty)) {
      String existsQuery =
          "EXISTS (SELECT 1 FROM note_transactions nt WHERE nt.note_id = promissory_notes.id AND COALESCE(nt.company_id, '$_defaultCompanyId') = @companyId";

      if (baslangicTarihi != null) {
        existsQuery += ' AND nt.date >= @startDate';
        params['startDate'] = DateTime(
          baslangicTarihi.year,
          baslangicTarihi.month,
          baslangicTarihi.day,
        ).toIso8601String();
      }

      if (bitisTarihi != null) {
        existsQuery += ' AND nt.date < @endDate';
        params['endDate'] = DateTime(
          bitisTarihi.year,
          bitisTarihi.month,
          bitisTarihi.day,
        ).add(const Duration(days: 1)).toIso8601String();
      }

      if (islemTuru != null && islemTuru.isNotEmpty) {
        existsQuery += ' AND nt.type = @islemTuru';
        params['islemTuru'] = islemTuru;
      }

      if (kullanici != null && kullanici.isNotEmpty) {
        existsQuery += ' AND nt.user_name = @kullanici';
        params['kullanici'] = kullanici;
      }

      existsQuery += ')';
      conditions.add(existsQuery);
    }

    if (senetId != null) {
      conditions.add('promissory_notes.id = @senetId');
      params['senetId'] = senetId;
    }

    if (conditions.isNotEmpty) {
      query += ' WHERE ${conditions.join(' AND ')}';
    }

    final result = await _pool!.execute(Sql.named(query), parameters: params);
    return result[0][0] as int;
  }

  /// [2026 HYPER-SPEED] Dinamik filtre seçeneklerini ve sayıları getirir.
  /// Büyük veri için optimize edilmiştir (SARGable predicates + EXISTS).
  Future<Map<String, Map<String, int>>> senetFiltreIstatistikleriniGetir({
    String? aramaTerimi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? banka,
    String? islemTuru,
    String? kullanici,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return {};

    Map<String, dynamic> params = {'companyId': _companyId};
    List<String> baseConditions = [];
    baseConditions.add(
      "COALESCE(promissory_notes.company_id, '$_defaultCompanyId') = @companyId",
    );

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      baseConditions.add('''
        (
          COALESCE(promissory_notes.search_tags, '') LIKE @search
          OR promissory_notes.id IN (
            SELECT nt.note_id
            FROM note_transactions nt
            WHERE COALESCE(nt.company_id, '$_defaultCompanyId') = @companyId
            AND COALESCE(nt.search_tags, '') LIKE @search
            GROUP BY nt.note_id
          )
        )
      ''');
      params['search'] = '%${_normalizeTurkish(aramaTerimi)}%';
    }

    // Transaction conditions used across facets (always includes company filter)
    String transactionFilters =
        " AND COALESCE(nt.company_id, '$_defaultCompanyId') = @companyId";
    if (baslangicTarihi != null) {
      transactionFilters += ' AND nt.date >= @start';
      params['start'] = DateTime(
        baslangicTarihi.year,
        baslangicTarihi.month,
        baslangicTarihi.day,
      ).toIso8601String();
    }
    if (bitisTarihi != null) {
      transactionFilters += ' AND nt.date < @end';
      params['end'] = DateTime(
        bitisTarihi.year,
        bitisTarihi.month,
        bitisTarihi.day,
      ).add(const Duration(days: 1)).toIso8601String();
    }

    if (baslangicTarihi != null || bitisTarihi != null) {
      baseConditions.add('''
        EXISTS (
          SELECT 1 FROM note_transactions nt 
          WHERE nt.note_id = promissory_notes.id 
          $transactionFilters
        )
      ''');
    }

    String buildQuery(String selectAndGroup, List<String> facetConds) {
      String where = (baseConditions.isNotEmpty || facetConds.isNotEmpty)
          ? 'WHERE ${(baseConditions + facetConds).join(' AND ')}'
          : '';
      return 'SELECT $selectAndGroup FROM (SELECT * FROM promissory_notes $where LIMIT 100001) as sub GROUP BY 1';
    }

    // 1. Banka istatistikleri (dinamik)
    List<String> bankConds = [];
    Map<String, dynamic> bankParams = Map.from(params);
    if ((islemTuru != null && islemTuru.isNotEmpty) ||
        (kullanici != null && kullanici.isNotEmpty)) {
      String existsQuery = '''
        EXISTS (
          SELECT 1 FROM note_transactions nt 
          WHERE nt.note_id = promissory_notes.id 
      ''';

      if (islemTuru != null && islemTuru.isNotEmpty) {
        existsQuery += ' AND nt.type = @islemTuru';
        bankParams['islemTuru'] = islemTuru;
      }

      if (kullanici != null && kullanici.isNotEmpty) {
        existsQuery += ' AND nt.user_name = @kullanici';
        bankParams['kullanici'] = kullanici;
      }

      existsQuery += '$transactionFilters\n        )';
      bankConds.add(existsQuery);
    }

    // 2. İşlem türü istatistikleri (dinamik)
    List<String> typeConds = [];
    Map<String, dynamic> typeParams = Map.from(params);
    if (banka != null && banka.isNotEmpty) {
      typeConds.add('promissory_notes.bank = @banka');
      typeParams['banka'] = banka;
    }
    if (kullanici != null && kullanici.isNotEmpty) {
      typeConds.add('nt.user_name = @kullanici');
      typeParams['kullanici'] = kullanici;
    }

    // 3. Kullanıcı istatistikleri (dinamik)
    List<String> userConds = [];
    Map<String, dynamic> userParams = Map.from(params);
    if (banka != null && banka.isNotEmpty) {
      userConds.add('promissory_notes.bank = @banka');
      userParams['banka'] = banka;
    }
    if (islemTuru != null && islemTuru.isNotEmpty) {
      userConds.add('nt.type = @islemTuru');
      userParams['islemTuru'] = islemTuru;
    }

    final results = await Future.wait([
      // Toplam (search + tarih aralığı bazında)
      _pool!.execute(
        Sql.named(
          'SELECT COUNT(*) FROM promissory_notes ${baseConditions.isNotEmpty ? 'WHERE ${baseConditions.join(' AND ')}' : ''}',
        ),
        parameters: params,
      ),
      // Bankalar
      _pool!.execute(
        Sql.named(buildQuery('bank, COUNT(*)', bankConds)),
        parameters: bankParams,
      ),
      // İşlem türleri (transaction.type)
      _pool!.execute(
        Sql.named('''
        SELECT nt.type, COUNT(DISTINCT promissory_notes.id)
        FROM promissory_notes
        JOIN note_transactions nt ON nt.note_id = promissory_notes.id
        WHERE ${(baseConditions + typeConds).join(' AND ')}
        $transactionFilters
        GROUP BY nt.type
      '''),
        parameters: typeParams,
      ),
      // Kullanıcılar (transaction.user_name)
      _pool!.execute(
        Sql.named('''
        SELECT nt.user_name, COUNT(DISTINCT promissory_notes.id)
        FROM promissory_notes
        JOIN note_transactions nt ON nt.note_id = promissory_notes.id
        WHERE ${(baseConditions + userConds).join(' AND ')}
        $transactionFilters
        GROUP BY nt.user_name
      '''),
        parameters: userParams,
      ),
    ]);

    Map<String, Map<String, int>> stats = {
      'ozet': {'toplam': results[0][0][0] as int},
      'bankalar': {},
      'islem_turleri': {},
      'kullanicilar': {},
    };

    for (final row in results[1]) {
      if (row[0] != null) {
        stats['bankalar']![row[0] as String] = row[1] as int;
      }
    }

    for (final row in results[2]) {
      if (row[0] != null) {
        stats['islem_turleri']![row[0] as String] = row[1] as int;
      }
    }

    for (final row in results[3]) {
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
        "SELECT t.*, p.note_no as senet_no, p.customer_name as cari_adi, p.customer_code as cari_kod, p.collection_status as tahsilat, p.issue_date as duzenlenme_tarihi, p.due_date as keside_tarihi, p.currency as para_birimi FROM note_transactions t LEFT JOIN promissory_notes p ON t.note_id = p.id WHERE COALESCE(t.company_id, '$_defaultCompanyId') = @companyId ORDER BY t.created_at DESC LIMIT 50",
      ),
      parameters: {'companyId': _companyId},
    );

    return result.map((row) {
      final map = row.toColumnMap();
      return _mapToTransaction(map);
    }).toList();
  }

  /// Senet işlemlerini getirir - Arama destekli
  ///
  /// [aramaTerimi] verilirse işlem detayları içinde arama yapar
  Future<List<Map<String, dynamic>>> senetIslemleriniGetir(
    int senetId, {
    String? aramaTerimi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? islemTuru,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    String query =
        '''
      SELECT t.*, 
             p.note_no as senet_no, 
             p.customer_name as cari_adi, 
             p.customer_code as cari_kod, 
             p.collection_status as tahsilat, 
             p.issue_date as duzenlenme_tarihi, 
             p.due_date as keside_tarihi, 
             p.currency as para_birimi 
      FROM note_transactions t 
      LEFT JOIN promissory_notes p ON t.note_id = p.id 
      WHERE t.note_id = @senetId 
      AND COALESCE(t.company_id, '$_defaultCompanyId') = @companyId
    ''';
    Map<String, dynamic> params = {'senetId': senetId, 'companyId': _companyId};

    // Arama filtresi
    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      query += " AND COALESCE(t.search_tags, '') LIKE @search";
      params['search'] = '%${_normalizeTurkish(aramaTerimi)}%';
    }

    // İşlem türü filtresi
    if (islemTuru != null && islemTuru.isNotEmpty) {
      query += ' AND t.type = @islemTuru';
      params['islemTuru'] = islemTuru;
    }

    // Tarih filtreleri (SARGable)
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
        "SELECT DISTINCT type FROM note_transactions WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId ORDER BY type ASC",
      ),
      parameters: {'companyId': _companyId},
    );

    return result
        .where((r) => r[0] != null)
        .map((r) => r[0] as String)
        .toList();
  }

  Future<void> senetEkle(
    SenetModel senet, {
    TxSession? session,
    bool cariEntegrasyonYap = true,
  }) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isCheckPromissoryActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde senet işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // [2026 FIX] integrationRef yoksa otomatik oluştur
    // Bu, ciro işleminde orijinal cari kaydının bulunabilmesini sağlar
    final String finalIntegrationRef =
        senet.integrationRef ??
        'note_${senet.cariKod}_${DateTime.now().millisecondsSinceEpoch}';

    Future<void> operation(TxSession s) async {
      // 1. Senet Kaydı
      final result = await s.execute(
        Sql.named('''
          INSERT INTO promissory_notes (
            company_id,
            type, collection_status, customer_code, customer_name, 
            issue_date, due_date, amount, currency, note_no, bank, 
            description, user_name, is_active, search_tags, matched_in_hidden, integration_ref
          )
          VALUES (
            @companyId,
            @type, @collection_status, @customer_code, @customer_name, 
            @issue_date, @due_date, @amount, @currency, @note_no, @bank, 
            @description, @user_name, @is_active, @search_tags, @matched_in_hidden, @integration_ref
          )
          RETURNING id
        '''),
        parameters: {
          'companyId': _companyId,
          'type': senet.tur,
          'collection_status': senet.tahsilat.isEmpty
              ? 'Portföyde'
              : senet.tahsilat,
          'customer_code': senet.cariKod,
          'customer_name': senet.cariAdi,
          'issue_date': DateFormat('dd.MM.yyyy').parse(senet.duzenlenmeTarihi),
          'due_date': DateFormat(
            'dd.MM.yyyy',
          ).parse(senet.kesideTarihi), // Modeldeki isim kesideTarihi
          'amount': senet.tutar,
          'currency': senet.paraBirimi,
          'note_no': senet.senetNo,
          'bank': senet.banka, // bank yerine kefil alanını kullanıyoruz
          'description': senet.aciklama,
          'user_name': senet.kullanici,
          'is_active': senet.aktifMi ? 1 : 0,
          'search_tags': _buildNoteSearchTags(
            senet,
            integrationRef: finalIntegrationRef,
          ),
          'matched_in_hidden': senet.matchedInHidden ? 1 : 0,
          'integration_ref': finalIntegrationRef,
        },
      );

      final int newId = result[0][0] as int;

      // 2. İlk Hareket
      final String hareketTuru = senet.tur == 'Alınan Senet'
          ? 'Senet Alındı'
          : 'Senet Verildi';
      final String yon = senet.cariAdi;

      final DateTime parsedDate = DateFormat(
        'dd.MM.yyyy',
      ).parse(senet.duzenlenmeTarihi);
      final DateTime now = DateTime.now();
      final DateTime islemTarihi = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        now.hour,
        now.minute,
        now.second,
      );

      await s.execute(
        Sql.named('''
          INSERT INTO note_transactions 
          (company_id, note_id, date, description, amount, type, source_dest, user_name, search_tags, integration_ref)
          VALUES 
          (@companyId, @note_id, @date, @description, @amount, @type, @source_dest, @user_name, @search_tags, @integration_ref)
        '''),
        parameters: {
          'companyId': _companyId,
          'note_id': newId,
          'date': islemTarihi,
          'description': senet.aciklama,
          'amount': senet.tutar,
          'type': hareketTuru,
          'source_dest': yon,
          'user_name': senet.kullanici,
          'search_tags': _buildNoteTransactionSearchTags(
            date: islemTarihi,
            description: senet.aciklama,
            amount: senet.tutar,
            type: hareketTuru,
            sourceDest: yon,
            userName: senet.kullanici,
            integrationRef: finalIntegrationRef,
          ),
          'integration_ref': finalIntegrationRef,
        },
      );

      // --- ENTEGRASYON: CARİ HESAP ---
      if (cariEntegrasyonYap && senet.cariKod.isNotEmpty) {
        final cariServis = CariHesaplarVeritabaniServisi();
        final int? cariId = await cariServis.cariIdGetir(
          senet.cariKod,
          session: s,
        );

        if (cariId != null) {
          bool isBorc = senet.tur == 'Verilen Senet';

          await cariServis.cariIslemEkle(
            cariId: cariId,
            tutar: senet.tutar,
            isBorc: isBorc,
            islemTuru: isBorc ? 'Senet Verildi' : 'Senet Alındı',
            aciklama: senet.aciklama,
            tarih: islemTarihi,
            kullanici: senet.kullanici,
            kaynakId: newId,
            kaynakAdi:
                '${senet.cariAdi}\nSenet ${senet.senetNo}\n${senet.banka}',
            kaynakKodu: senet.senetNo,
            entegrasyonRef: finalIntegrationRef,
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
  }

  Future<void> senetGuncelle(SenetModel senet) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isCheckPromissoryActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde senet işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // 1. Get old note data
      final oldResult = await session.execute(
        Sql.named(
          "SELECT * FROM promissory_notes WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': senet.id, 'companyId': _companyId},
      );

      if (oldResult.isEmpty) return;
      final oldRow = oldResult.first.toColumnMap();
      final double oldAmount =
          double.tryParse(oldRow['amount']?.toString() ?? '') ?? 0.0;
      final String oldType = oldRow['type'] as String? ?? '';
      final String oldCustomerCode = oldRow['customer_code'] as String? ?? '';
      final String finalRef =
          senet.integrationRef ?? (oldRow['integration_ref'] as String? ?? '');

      // 2. Update Note Record
      await session.execute(
        Sql.named('''
          UPDATE promissory_notes 
          SET type=@type, collection_status=@collection_status, 
              customer_code=@customer_code, customer_name=@customer_name, 
              issue_date=@issue_date, due_date=@due_date, amount=@amount, 
              currency=@currency, note_no=@note_no, bank=@bank, 
              description=@description, user_name=@user_name, is_active=@is_active,
              search_tags=@search_tags
          WHERE id=@id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
        '''),
        parameters: {
          'id': senet.id,
          'companyId': _companyId,
          'type': senet.tur,
          'collection_status': senet.tahsilat,
          'customer_code': senet.cariKod,
          'customer_name': senet.cariAdi,
          'issue_date': DateFormat('dd.MM.yyyy').parse(senet.duzenlenmeTarihi),
          'due_date': DateFormat('dd.MM.yyyy').parse(senet.kesideTarihi),
          'amount': senet.tutar,
          'currency': senet.paraBirimi,
          'note_no': senet.senetNo,
          'bank': senet.banka,
          'description': senet.aciklama,
          'user_name': senet.kullanici,
          'is_active': senet.aktifMi ? 1 : 0,
          'search_tags': _buildNoteSearchTags(senet, integrationRef: finalRef),
        },
      );

      // --- ENTEGRASYON: CARİ HESAP ---
      final cariServis = CariHesaplarVeritabaniServisi();

      // [2025 SMART UPDATE] Ref Varsa ve Cari Değişmediyse -> Update
      if (oldCustomerCode == senet.cariKod && finalRef.isNotEmpty) {
        bool isBorc = senet.tur == 'Verilen Senet';
        await cariServis.cariIslemGuncelleByRef(
          ref: finalRef,
          tarih: DateFormat('dd.MM.yyyy').parse(senet.duzenlenmeTarihi),
          aciklama: senet.aciklama,
          tutar: senet.tutar,
          isBorc: isBorc,
          kaynakAdi: senet.cariAdi,
          kaynakKodu: senet.senetNo,
          kullanici: senet.kullanici,
          session: session,
        );
      } else {
        // A. Revert Old
        if (finalRef.isNotEmpty) {
          await cariServis.cariIslemSilByRef(finalRef, session: session);
        } else if (oldCustomerCode.isNotEmpty) {
          final int? oldCariId = await cariServis.cariIdGetir(
            oldCustomerCode,
            session: session,
          );
          if (oldCariId != null) {
            bool wasBorc = oldType == 'Verilen Senet';
            await cariServis.cariIslemSil(
              oldCariId,
              oldAmount,
              wasBorc,
              kaynakTur: 'Senet',
              kaynakId: senet.id,
              session: session,
            );
          }
        }

        // B. Apply New
        if (senet.cariKod.isNotEmpty) {
          final int? newCariId = await cariServis.cariIdGetir(
            senet.cariKod,
            session: session,
          );
          if (newCariId != null) {
            bool isBorc = senet.tur == 'Verilen Senet';
            await cariServis.cariIslemEkle(
              cariId: newCariId,
              tutar: senet.tutar,
              isBorc: isBorc,
              islemTuru: isBorc ? 'Senet Verildi' : 'Senet Alındı',
              aciklama: senet.aciklama,
              tarih: DateFormat('dd.MM.yyyy').parse(senet.duzenlenmeTarihi),
              kullanici: senet.kullanici,
              kaynakId: senet.id,
              kaynakAdi: senet.banka,
              kaynakKodu: senet.senetNo,
              entegrasyonRef: finalRef,
              session: session,
            );
          }
        }
      }
    });
  }

  Future<void> senetSil(int id, {TxSession? session}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    Future<void> operation(TxSession s) async {
      // 1. Get note data
      final result = await s.execute(
        Sql.named(
          "SELECT * FROM promissory_notes WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      if (result.isEmpty) return;
      final row = result.first.toColumnMap();
      final double amount =
          double.tryParse(row['amount']?.toString() ?? '') ?? 0.0;
      final String type = row['type'] as String? ?? '';
      final String customerCode = row['customer_code'] as String? ?? '';

      // 2. Delete Note
      await s.execute(
        Sql.named(
          "DELETE FROM promissory_notes WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );
      await s.execute(
        Sql.named(
          "DELETE FROM note_transactions WHERE note_id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      // --- MALİ ENTEGRASYONLARI TEMİZLE (Kasa, Banka, Kredi Kartı) ---
      final txRows = await s.execute(
        Sql.named(
          "SELECT integration_ref FROM note_transactions WHERE note_id = @id AND integration_ref IS NOT NULL AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      for (final txRow in txRows) {
        final String? intRef = txRow[0] as String?;
        if (intRef != null && intRef.isNotEmpty) {
          // Kasadaki islemi sil
          await KasalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
            intRef,
            haricKasaIslemId: -1,
            silinecekCariyiEtkilesin: false,
            session: s,
          );
          // Bankadaki islemi sil
          await BankalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
            intRef,
            haricBankaIslemId: -1,
            silinecekCariyiEtkilesin: false,
            session: s,
          );
          // Kredi kartindaki islemi sil
          await KrediKartlariVeritabaniServisi()
              .entegrasyonBaglantiliIslemleriSil(
                intRef,
                haricKrediKartiIslemId: -1,
                silinecekCariyiEtkilesin: false,
                session: s,
              );
        }
      }

      // --- ENTEGRASYON: CARİ HESAP (Geri Al) ---
      final cariServis = CariHesaplarVeritabaniServisi();
      final String? finalRef = row['integration_ref'] as String?;
      if (finalRef != null && finalRef.isNotEmpty) {
        await cariServis.cariIslemSilByRef(finalRef, session: s);
      } else if (customerCode.isNotEmpty) {
        final int? cariId = await cariServis.cariIdGetir(
          customerCode,
          session: s,
        );

        if (cariId != null) {
          bool wasBorc = type == 'Verilen Senet';
          await cariServis.cariIslemSil(
            cariId,
            amount,
            wasBorc,
            kaynakTur: 'Senet',
            kaynakId: id,
            session: s,
          );
        }
      }
    }

    if (session != null) {
      await operation(session);
    } else {
      await _pool!.runTx(operation);
    }
  }

  Future<bool> senetNoVarMi(String senetNo, {int? haricId}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    String query =
        "SELECT COUNT(*) FROM promissory_notes WHERE note_no = @note_no AND COALESCE(company_id, '$_defaultCompanyId') = @companyId";
    Map<String, dynamic> params = {'note_no': senetNo, 'companyId': _companyId};

    if (haricId != null) {
      query += ' AND id != @haricId';
      params['haricId'] = haricId;
    }

    final result = await _pool!.execute(Sql.named(query), parameters: params);

    return (result[0][0] as int) > 0;
  }

  /// Entegrasyon referansına göre senetleri bulur ve siler.
  ///
  /// [KRİTİK] Bu fonksiyon sadece senedi silmez, aynı zamanda:
  /// 1. Tahsil edilmiş/Ciro edilmiş senetlerin Kasa/Banka işlemlerini geri alır
  /// 2. İlişkili tüm hareket kayıtlarını temizler
  /// Bu sayede "Hayalet Para" sorunu önlenir.
  /// [2025 GUARD]: Çifte Silme Koruma - Aynı ref ile işlem yoksa erken çık
  Future<void> senetSilByRef(String ref, {TxSession? session}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // [2025 GUARD] Boş veya geçersiz referans kontrolü
    if (ref.isEmpty) {
      debugPrint('[GUARD] senetSilByRef: Boş ref ile çağrıldı, atlanıyor.');
      return;
    }

    final executor = session ?? _pool!;
    final cariServis = CariHesaplarVeritabaniServisi();

    final rows = await executor.execute(
      Sql.named(
        "SELECT id, collection_status FROM promissory_notes WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
      ),
      parameters: {'ref': ref, 'companyId': _companyId},
    );

    // [2025 GUARD] Çifte silme veya olmayan işlem kontrolü
    if (rows.isEmpty) {
      debugPrint(
        '[GUARD] senetSilByRef: ref=$ref için senet bulunamadı (zaten silinmiş veya hiç oluşturulmamış).',
      );
      return;
    }

    for (final row in rows) {
      final int id = row[0] as int;
      final String durum = row[1] as String? ?? '';

      // [KRİTİK FIX] Eğer senet tahsil edilmiş veya ciro edilmişse,
      // önce mali entegrasyonları (Kasa/Banka işlemlerini) geri al
      if (durum == 'Tahsil Edildi' ||
          durum == 'Ödendi' ||
          durum == 'Ciro Edildi') {
        // Bu senedin işlem hareketlerinde integration_ref bulunanları bul
        final txRows = await executor.execute(
          Sql.named(
            "SELECT integration_ref FROM note_transactions WHERE note_id = @senetId AND integration_ref IS NOT NULL AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
          ),
          parameters: {'senetId': id, 'companyId': _companyId},
        );

        for (final txRow in txRows) {
          final String? intRef = txRow[0] as String?;
          if (intRef != null && intRef.isNotEmpty) {
            // Kasa ve Banka entegrasyonlarını geri al
            await KasalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
              intRef,
              haricKasaIslemId: -1, // Hepsini sil
              silinecekCariyiEtkilesin: false,
              session: session,
            );
            await BankalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
              intRef,
              haricBankaIslemId: -1, // Hepsini sil
              silinecekCariyiEtkilesin: false,
              session: session,
            );
          }
        }
      }

      // 3. [FIX] Tüm Hareketlerin Cari Entegrasyonlarını Temizle (Ciro Dahil)
      final txs = await executor.execute(
        Sql.named(
          "SELECT id FROM note_transactions WHERE note_id = @senetId AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'senetId': id, 'companyId': _companyId},
      );

      for (final tx in txs) {
        final int txId = tx[0] as int;
        // Harekete bağlı cari işlemleri sil
        await cariServis.cariIslemSilOrphaned(kaynakId: txId, session: session);
      }

      // Standart silme fonksiyonunu kullan
      await senetSil(id, session: session);
    }
  }

  /// Senet tahsil et - Senedin tahsilat durumunu günceller ve hareket ekler
  Future<void> senetTahsilEt({
    required int senetId,
    required String yerTuru,
    required String yerKodu,
    required String yerAdi,
    required String aciklama,
    required DateTime tarih,
    required String kullanici,
  }) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isCheckPromissoryActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde senet işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // 1. Senet Bilgilerini Al
      final noteRes = await session.execute(
        Sql.named(
          "SELECT * FROM promissory_notes WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': senetId, 'companyId': _companyId},
      );
      if (noteRes.isEmpty) return;
      final noteRow = noteRes.first.toColumnMap();
      final double tutar =
          double.tryParse(noteRow['amount']?.toString() ?? '') ?? 0.0;

      final String cariKod = noteRow['customer_code'] as String? ?? '';
      final String cariAd = noteRow['customer_name'] as String? ?? '';
      final String tur = noteRow['type'] as String? ?? ''; // Alınan/Verilen
      final String mevcutDurum = noteRow['collection_status'] as String? ?? '';

      // [VALIDATION] Senedin zaten işlem görmüş olup olmadığını kontrol et
      if (mevcutDurum == 'Ciro Edildi' ||
          mevcutDurum == 'Tahsil Edildi' ||
          mevcutDurum == 'Ödendi' ||
          mevcutDurum == 'Karşılıksız') {
        debugPrint(
          '⚠️ Senet zaten işlem görmüş! Mevcut durum: $mevcutDurum. Tahsil/Ödeme işlemi yapılamaz.',
        );
        throw Exception(
          'Bu senet zaten "$mevcutDurum" durumunda. Tekrar tahsil/ödeme yapılamaz.',
        );
      }

      // 2. Durum ve Açıklama Belirle
      String yeniDurum;
      String islemTuru; // 'Giriş' veya 'Çıkış'
      String detayAciklama = aciklama;
      String kaynakHedef = yerAdi;

      if (tur == 'Alınan Senet') {
        yeniDurum = 'Tahsil Edildi';
        islemTuru = 'Senet Tahsil';
      } else {
        yeniDurum = 'Ödendi';
        islemTuru = 'Senet Ödendi';
      }

      // 3. Senedi Güncelle (Aktiflik kapanır çünkü işlem bitti)
      await session.execute(
        Sql.named('''
          UPDATE promissory_notes 
          SET collection_status = @status, is_active = 0 
          WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
        '''),
        parameters: {
          'status': yeniDurum,
          'id': senetId,
          'companyId': _companyId,
        },
      );
      await _updateNoteSearchTags(senetId, session);

      // [ENTEGRASYON] Cari Hesap Islem Turunu Guncelle
      final String? initialRef = noteRow['integration_ref'] as String?;
      if (initialRef != null && initialRef.isNotEmpty) {
        await session.execute(
          Sql.named('''
            UPDATE current_account_transactions 
            SET source_type = @yeniIslemTuru 
            WHERE integration_ref = @ref
          '''),
          parameters: {
            'yeniIslemTuru': tur == 'Alınan Senet'
                ? 'Senet Alındı ($yeniDurum)'
                : 'Senet Verildi ($yeniDurum)',
            'ref': initialRef,
          },
        );
      }

      final String intRef =
          'note_collect_${senetId}_${DateTime.now().millisecondsSinceEpoch}';

      // 4. Tahsilat/Ödeme Hareketi Ekle (Senet İçin)
      await session.execute(
        Sql.named('''
          INSERT INTO note_transactions 
          (company_id, note_id, date, description, amount, type, source_dest, user_name, search_tags, integration_ref)
          VALUES 
          (@companyId, @note_id, @date, @description, @amount, @type, @source_dest, @user_name, @search_tags, @integration_ref)
        '''),
        parameters: {
          'companyId': _companyId,
          'note_id': senetId,
          'date': tarih,
          'description': detayAciklama,
          'amount': tutar,
          'type': islemTuru,
          'source_dest': kaynakHedef,
          'user_name': kullanici,
          'search_tags': _buildNoteTransactionSearchTags(
            date: tarih,
            description: '$yeniDurum $detayAciklama',
            amount: tutar,
            type: islemTuru,
            sourceDest: kaynakHedef,
            userName: kullanici,
            integrationRef: intRef,
          ),
          'integration_ref': intRef,
        },
      );

      // 4. MALI ENTEGRASYON: KASA veya BANKA'ya Para Giriş/Çıkışı
      // [FIX] UI'dan gelen 'yerTuru' stringine güvenme.

      final kasaServis = KasalarVeritabaniServisi();
      final kasalar = await kasaServis.kasaAra(yerKodu, limit: 1);

      if (kasalar.isNotEmpty) {
        final String kasaIslem = tur == 'Alınan Senet' ? 'Tahsilat' : 'Ödeme';
        await kasaServis.kasaIslemEkle(
          kasaId: kasalar.first.id,
          tutar: tutar,
          islemTuru: kasaIslem,
          aciklama: aciklama,
          tarih: tarih,
          cariTuru: 'Cari Hesap',
          cariKodu: cariKod,
          cariAdi: cariAd,
          kullanici: kullanici,
          entegrasyonRef: intRef,
          cariEntegrasyonYap: false,
        );
      } else {
        final bankaServis = BankalarVeritabaniServisi();
        final bankalar = await bankaServis.bankaAra(yerKodu, limit: 1);
        if (bankalar.isNotEmpty) {
          final String bankaIslem = tur == 'Alınan Senet'
              ? 'Tahsilat'
              : 'Ödeme';
          await bankaServis.bankaIslemEkle(
            bankaId: bankalar.first.id,
            tutar: tutar,
            islemTuru: bankaIslem,
            aciklama: aciklama,
            tarih: tarih,
            cariTuru: 'Cari Hesap',
            cariKodu: cariKod,
            cariAdi: cariAd,
            kullanici: kullanici,
            entegrasyonRef: intRef,
            cariEntegrasyonYap: false,
          );
        } else {
          debugPrint('⚠️ Senet Tahsilat yeri bulunamadı: $yerKodu ($yerTuru)');
        }
      }
    });
  }

  /// Senet ciro et - Senedin ciro durumunu günceller ve hareket ekler
  Future<void> senetCiroEt({
    required int senetId,
    required String cariKodu,
    required String cariAdi,
    required String aciklama,
    required DateTime tarih,
    required String kullanici,
  }) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isCheckPromissoryActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde senet işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // 1. Senet Verisini Al
      final noteRes = await session.execute(
        Sql.named(
          "SELECT * FROM promissory_notes WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': senetId, 'companyId': _companyId},
      );

      if (noteRes.isEmpty) return;
      final noteRow = noteRes.first.toColumnMap();
      final String mevcutDurum = noteRow['collection_status'] as String? ?? '';
      final double noteAmount =
          double.tryParse(noteRow['amount']?.toString() ?? '') ?? 0.0;

      // [VALIDATION] Senedin zaten işlem görmüş olup olmadığını kontrol et
      if (mevcutDurum == 'Ciro Edildi' ||
          mevcutDurum == 'Tahsil Edildi' ||
          mevcutDurum == 'Ödendi' ||
          mevcutDurum == 'Karşılıksız') {
        debugPrint(
          '⚠️ Senet zaten işlem görmüş! Mevcut durum: $mevcutDurum. Ciro işlemi yapılamaz.',
        );
        throw Exception(
          'Bu senet zaten "$mevcutDurum" durumunda. Tekrar ciro edilemez.',
        );
      }

      // 2. Durum ve Açıklama Belirle
      const String yeniDurum = 'Ciro Edildi';
      const String islemTuru = 'Senet Ciro'; // Portföyden Çıktı
      String detayAciklama = aciklama;
      String kaynakHedef = cariAdi;

      // 3. Senedi Güncelle
      await session.execute(
        Sql.named('''
          UPDATE promissory_notes 
          SET collection_status = @status, is_active = 0 
          WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
        '''),
        parameters: {
          'status': yeniDurum,
          'id': senetId,
          'companyId': _companyId,
        },
      );
      await _updateNoteSearchTags(senetId, session);

      // [2026 FIX] Orijinal Cari İşlemini Güncelle (Senet Alındı -> Senet Alındı (Ciro Edildi))
      // Ayrıca İlgili Hesap bilgisine Ciro bilgisini ekle
      final String? initialRef = noteRow['integration_ref'] as String?;
      final String orijinalCariAdi = noteRow['customer_name']?.toString() ?? '';
      final String senetNo = noteRow['note_no']?.toString() ?? '';

      // [2026 FIX] GENİŞ KAPSAMLI GÜNCELLEME
      // Hem integration_ref (yeni kayıtlar) hem de source_id (eski/kopuk kayıtlar) üzerinden dener.
      String whereClause =
          "source_id = @senetId AND source_type IN ('Senet Alındı', 'Senet Verildi')";
      Map<String, dynamic> updateParams = {
        'sourceName': '$orijinalCariAdi\nSenet $senetNo\nCiro $cariAdi',
        'senetId': senetId,
      };

      if (initialRef != null && initialRef.isNotEmpty) {
        whereClause = "($whereClause) OR integration_ref = @ref";
        updateParams['ref'] = initialRef;
      }

      await session.execute(
        Sql.named('''
          UPDATE current_account_transactions 
          SET source_type = 'Senet Alındı (Ciro Edildi)',
              source_name = @sourceName
          WHERE $whereClause
        '''),
        parameters: updateParams,
      );

      // 4. Ciro Hareketi Ekle
      final String ciroIntRef =
          'ciro_${senetId}_${DateTime.now().millisecondsSinceEpoch}';
      final txResult = await session.execute(
        Sql.named('''
          INSERT INTO note_transactions 
          (company_id, note_id, date, description, amount, type, source_dest, user_name, search_tags, integration_ref)
          VALUES 
          (@companyId, @note_id, @date, @description, (SELECT amount FROM promissory_notes WHERE id = @note_id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId), @type, @source_dest, @user_name, @search_tags, @integration_ref)

          RETURNING id
        '''),
        parameters: {
          'companyId': _companyId,
          'note_id': senetId,
          'date': tarih,
          'description': detayAciklama,
          'type': islemTuru,
          'source_dest': kaynakHedef,
          'user_name': kullanici,
          'search_tags': _buildNoteTransactionSearchTags(
            date: tarih,
            description: '$yeniDurum $detayAciklama',
            amount: noteAmount,
            type: islemTuru,
            sourceDest: kaynakHedef,
            userName: kullanici,
            integrationRef: ciroIntRef,
          ),
          'integration_ref': ciroIntRef,
        },
      );
      final int txId = txResult.first[0] as int;

      // --- ENTEGRASYON: CARİ HESAP (Ciro Edilen Kişi) ---
      if (cariKodu.isNotEmpty) {
        final cariServis = CariHesaplarVeritabaniServisi();
        final int? cariId = await cariServis.cariIdGetir(
          cariKodu,
          session: session,
        );

        if (cariId != null) {
          // Ciro edilen kişi (Tedarikçi) -> Borç (isBorc: true)
          final amountRes = await session.execute(
            Sql.named(
              "SELECT amount FROM promissory_notes WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
            ),
            parameters: {'id': senetId, 'companyId': _companyId},
          );
          double amount = 0;
          if (amountRes.isNotEmpty) {
            amount =
                double.tryParse(amountRes.first[0]?.toString() ?? '') ?? 0.0;
          }

          await cariServis.cariIslemEkle(
            cariId: cariId,
            tutar: amount,
            isBorc: true, // Borç
            islemTuru: 'Senet Verildi (Ciro Edildi)',
            aciklama: detayAciklama,
            tarih: tarih,
            kullanici: kullanici,
            kaynakId: txId,
            kaynakAdi: '$cariAdi\nSenet $senetNo\nCiro $orijinalCariAdi',
            kaynakKodu: senetNo,
            entegrasyonRef: ciroIntRef,
            session: session,
          );
        }
      }
    });
  }

  // Helpers
  SenetModel _mapToSenetModel(
    Map<String, dynamic> map, {
    bool? matchedInHiddenOverride,
  }) {
    return SenetModel(
      id: map['id'] as int,
      tur: map['type'] as String? ?? '',
      tahsilat: map['collection_status'] as String? ?? '',
      cariKod: map['customer_code'] as String? ?? '',
      cariAdi: map['customer_name'] as String? ?? '',
      duzenlenmeTarihi: map['issue_date'] is DateTime
          ? DateFormat('dd.MM.yyyy').format(map['issue_date'] as DateTime)
          : (map['issue_date']?.toString() ?? ''),
      kesideTarihi: map['due_date'] is DateTime
          ? DateFormat('dd.MM.yyyy').format(map['due_date'] as DateTime)
          : (map['due_date']?.toString() ?? ''),
      tutar: double.tryParse(map['amount']?.toString() ?? '') ?? 0.0,
      paraBirimi: map['currency'] as String? ?? 'TRY',
      senetNo: map['note_no'] as String? ?? '',
      banka: map['bank'] as String? ?? '', // Using 'bank' column for 'kefil'
      aciklama: map['description'] as String? ?? '',
      kullanici: map['user_name'] as String? ?? '',
      aktifMi: (map['is_active'] as int?) == 1,
      searchTags: map['search_tags'] as String?,
      matchedInHidden:
          matchedInHiddenOverride ?? (map['matched_in_hidden'] as int?) == 1,
    );
  }

  Map<String, dynamic> _mapToTransaction(Map<String, dynamic> map) {
    return {
      'id': map['id'],
      'type': map['type'] ?? '',
      'date': map['date'] ?? '',
      'description': map['description'] ?? '',
      'amount': double.tryParse(map['amount']?.toString() ?? '') ?? 0.0,
      'user_name': map['user_name'] ?? '',
      'para_birimi': map['para_birimi'] ?? 'TRY',
      'source_dest': map['source_dest'] ?? '',
      'integration_ref': map['integration_ref'],
      'created_at': map['created_at'],
    };
  }

  /// Senet işlemini siler ve mali etkileri geri alır
  Future<void> senetIsleminiSil(int islemId) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // 1. İşlemi bul
      final txRes = await session.execute(
        Sql.named(
          "SELECT * FROM note_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': islemId, 'companyId': _companyId},
      );
      if (txRes.isEmpty) return;
      final tx = txRes.first.toColumnMap();
      final int senetId = tx['note_id'] as int;
      final String? intRef = tx['integration_ref'] as String?;
      final double tutar =
          double.tryParse(tx['amount']?.toString() ?? '') ?? 0.0;
      final String type = tx['type']?.toString() ?? '';

      // 2. Kasa/Banka Entegrasyonlarını Geri Al
      if ((intRef ?? '').isNotEmpty) {
        await KasalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
          intRef!,
          haricKasaIslemId: -1,
          silinecekCariyiEtkilesin: false,
        );
        await BankalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
          intRef,
          haricBankaIslemId: -1,
          silinecekCariyiEtkilesin: false,
        );
      }

      // 3. Cari Entegrasyonu Geri Al
      final cariServis = CariHesaplarVeritabaniServisi();
      if ((intRef ?? '').isNotEmpty) {
        await cariServis.cariIslemSilByRef(intRef!, session: session);
      } else {
        final searchCariTx = await session.execute(
          Sql.named('''
            SELECT current_account_id FROM current_account_transactions 
            WHERE source_id = @islemId AND (source_type = 'Senet Ciro' OR source_type = 'Para Verildi (Senet Ciro)' OR source_type = 'Senet Verildi (Ciro Edildi)')
          '''),
          parameters: {'islemId': islemId},
        );
        if (searchCariTx.isNotEmpty) {
          final int rCariId = searchCariTx.first[0] as int;
          await cariServis.cariIslemSil(
            rCariId,
            tutar,
            true, // isBorc: biz ciro yaparken borçlandırmıştık
            kaynakTur: 'Senet',
            kaynakId: islemId,
            session: session,
          );
        }
      }

      // 4. Senet Durumunu Geri Al
      if (type != 'Senet Alındı' && type != 'Senet Verildi') {
        await session.execute(
          Sql.named(
            "UPDATE promissory_notes SET collection_status = 'Portföyde', is_active = 1 WHERE id = @id",
          ),
          parameters: {'id': senetId},
        );
        await _updateNoteSearchTags(senetId, session);

        // [ENTEGRASYON] Cari Hesap Islem Turunu Geri Al
        final noteRes = await session.execute(
          Sql.named(
            "SELECT type, integration_ref, customer_name, note_no FROM promissory_notes WHERE id = @id",
          ),
          parameters: {'id': senetId},
        );
        if (noteRes.isNotEmpty) {
          final row = noteRes.first.toColumnMap();
          final String? cRef = row['integration_ref'] as String?;
          if (cRef != null && cRef.isNotEmpty) {
            final String cTur = row['type'] as String? ?? '';
            final String cariAdi = row['customer_name']?.toString() ?? '';
            final String senetNo = row['note_no']?.toString() ?? '';
            await session.execute(
              Sql.named('''
                    UPDATE current_account_transactions 
                    SET source_type = @eskiIslemTuru,
                        source_name = @sourceName,
                        source_code = @sourceCode
                    WHERE integration_ref = @ref
                '''),
              parameters: {
                'eskiIslemTuru': cTur == 'Alınan Senet'
                    ? 'Senet Alındı'
                    : 'Senet Verildi',
                'sourceName': '$cariAdi\nSenet $senetNo',
                'sourceCode': senetNo,
                'ref': cRef,
              },
            );
          }
        }
      }

      // 5. İşlemi Sil
      await session.execute(
        Sql.named("DELETE FROM note_transactions WHERE id = @id"),
        parameters: {'id': islemId},
      );
    });
  }

  /// Senet işlemini günceller ve mali etkileri yansıtır
  Future<void> senetIsleminiGuncelle({
    required int islemId,
    required double tutar,
    required String aciklama,
    required DateTime tarih,
    required String kullanici,
  }) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isCheckPromissoryActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde senet işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // 1. İşlemi bul
      final txRes = await session.execute(
        Sql.named(
          "SELECT * FROM note_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': islemId, 'companyId': _companyId},
      );
      if (txRes.isEmpty) return;
      final tx = txRes.first.toColumnMap();
      final String? intRef = tx['integration_ref'] as String?;
      final String txType = tx['type'] as String? ?? '';
      final String txSourceDest = tx['source_dest'] as String? ?? '';
      final String txUserName = tx['user_name'] as String? ?? '';

      // 2. Kasa/Banka Entegrasyonlarını Güncelle
      if ((intRef ?? '').isNotEmpty) {
        await KasalarVeritabaniServisi().entegrasyonBaglantiliIslemleriGuncelle(
          entegrasyonRef: intRef!,
          tutar: tutar,
          aciklama: aciklama,
          tarih: tarih,
          kullanici: kullanici,
          haricKasaIslemId: -1,
        );
        await BankalarVeritabaniServisi()
            .entegrasyonBaglantiliIslemleriGuncelle(
              entegrasyonRef: intRef,
              tutar: tutar,
              aciklama: aciklama,
              tarih: tarih,
              kullanici: kullanici,
              haricBankaIslemId: -1,
            );
      }

      // 3. Cari Entegrasyonu Güncelle
      final cariServis = CariHesaplarVeritabaniServisi();
      if ((intRef ?? '').isNotEmpty) {
        await cariServis.cariIslemGuncelleByRef(
          ref: intRef!,
          tarih: tarih,
          aciklama: aciklama,
          tutar: tutar,
          isBorc: true,
          kullanici: kullanici,
          session: session,
        );
      } else {
        final searchCariTx = await session.execute(
          Sql.named('''
            SELECT current_account_id, amount FROM current_account_transactions 
            WHERE source_id = @islemId AND (source_type = 'Senet Ciro' OR source_type = 'Para Verildi (Senet Ciro)' OR source_type = 'Senet Verildi (Ciro Edildi)')
          '''),
          parameters: {'islemId': islemId},
        );
        if (searchCariTx.isNotEmpty) {
          final int rCariId = searchCariTx.first[0] as int;
          final double oldAmount =
              double.tryParse(searchCariTx.first[1]?.toString() ?? '') ?? 0.0;

          await cariServis.cariIslemSil(
            rCariId,
            oldAmount,
            true, // isBorc
            kaynakTur: 'Senet',
            kaynakId: islemId,
            session: session,
          );

          await cariServis.cariIslemEkle(
            cariId: rCariId,
            tutar: tutar,
            isBorc: true,
            islemTuru: 'Senet Verildi (Ciro Edildi)',
            aciklama: aciklama,
            tarih: tarih,
            kullanici: kullanici,
            kaynakId: islemId,
            session: session,
          );
        }
      }

      // 4. İşlemi Güncelle
      await session.execute(
        Sql.named('''
          UPDATE note_transactions 
          SET amount = @amount, description = @description, date = @date, search_tags = @search_tags
          WHERE id = @id
        '''),
        parameters: {
          'amount': tutar,
          'description': aciklama,
          'date': DateFormat('dd.MM.yyyy HH:mm').format(tarih),
          'search_tags': _buildNoteTransactionSearchTags(
            date: tarih,
            description: aciklama,
            amount: tutar,
            type: txType,
            sourceDest: txSourceDest,
            userName: txUserName,
            integrationRef: intRef ?? '',
          ),
          'id': islemId,
        },
      );
    });
  }

  /// Senet Karşılıksız Çıktı İşlemi
  /// Tahsil edilmiş bir senet karşılıksız çıkarsa:
  /// 1. Senet durumunu "Karşılıksız" olarak günceller
  /// 2. Daha önce yapılmış kasa/banka girişini tersine çevirir (para çıkışı)
  /// 3. Cari hesaba tekrar borç yazar (müşteri tekrar borçlanır)
  /// 4. Senedi tekrar aktif yapar (takip için)
  Future<void> senetKarsiliksiziCikti({
    required int senetId,
    required String aciklama,
    required DateTime tarih,
    required String kullanici,
  }) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isCheckPromissoryActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde senet işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // 1. Senet Verisini Al
      final noteRes = await session.execute(
        Sql.named(
          "SELECT * FROM promissory_notes WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': senetId, 'companyId': _companyId},
      );
      if (noteRes.isEmpty) return;

      final noteRow = noteRes.first.toColumnMap();
      final double tutar =
          double.tryParse(noteRow['amount']?.toString() ?? '') ?? 0.0;
      final String tur = noteRow['type'] as String? ?? '';

      final String cariKod = noteRow['customer_code'] as String? ?? '';
      final String cariAd = noteRow['customer_name'] as String? ?? '';
      final String mevcutDurum = noteRow['collection_status'] as String? ?? '';

      // Sadece "Tahsil Edildi" veya "Ödendi" durumundaki senetler karşılıksız çıkabilir
      if (mevcutDurum != 'Tahsil Edildi' && mevcutDurum != 'Ödendi') {
        debugPrint(
          '⚠️ Senet karşılıksız işlemi yapılamaz. Mevcut durum: $mevcutDurum',
        );
        return;
      }

      // 2. Orijinal tahsilat işlemini bul (entegrasyon ref ile)
      final txRes = await session.execute(
        Sql.named('''
          SELECT * FROM note_transactions 
          WHERE note_id = @senetId 
            AND type IN ('Giriş', 'Çıkış')
            AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
          ORDER BY created_at DESC 
          LIMIT 1
        '''),
        parameters: {'senetId': senetId, 'companyId': _companyId},
      );

      String? originalIntRef;
      if (txRes.isNotEmpty) {
        final txRow = txRes.first.toColumnMap();
        originalIntRef = txRow['integration_ref'] as String?;
      }

      // 3. Senet durumunu "Karşılıksız" olarak güncelle ve aktif yap
      await session.execute(
        Sql.named('''
          UPDATE promissory_notes 
          SET collection_status = 'Karşılıksız', is_active = 1 
          WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
        '''),
        parameters: {'id': senetId, 'companyId': _companyId},
      );
      await _updateNoteSearchTags(senetId, session);

      final String intRef =
          'note_bounce_${senetId}_${DateTime.now().millisecondsSinceEpoch}';
      final String detayAciklama = aciklama;

      // 4. Karşılıksız işlem kaydı ekle
      await session.execute(
        Sql.named('''
          INSERT INTO note_transactions 
          (company_id, note_id, date, description, amount, type, source_dest, user_name, search_tags, integration_ref)
          VALUES 
          (@companyId, @note_id, @date, @description, @amount, @type, @source_dest, @user_name, @search_tags, @integration_ref)
        '''),
        parameters: {
          'companyId': _companyId,
          'note_id': senetId,
          'date': tarih,
          'description': detayAciklama,
          'amount': tutar,
          'type': 'Karşılıksız Senet',
          'source_dest': 'Cari Hesap: $cariAd',
          'user_name': kullanici,
          'search_tags': _buildNoteTransactionSearchTags(
            date: tarih,
            description: 'Karşılıksız $detayAciklama $cariAd',
            amount: tutar,
            type: 'Karşılıksız Senet',
            sourceDest: 'Cari Hesap: $cariAd',
            userName: kullanici,
            integrationRef: intRef,
          ),
          'integration_ref': intRef,
        },
      );

      // 5. MALI ENTEGRASYON: Önceki kasa/banka işlemini tersine çevir
      if ((originalIntRef ?? '').isNotEmpty) {
        // Önceki tahsilat işlemlerini sil (bu otomatik olarak bakiyeleri geri alır)
        await KasalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
          originalIntRef!,
          haricKasaIslemId: -1,
          silinecekCariyiEtkilesin: false,
        );
        await BankalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
          originalIntRef,
          haricBankaIslemId: -1,
          silinecekCariyiEtkilesin: false,
        );
      }

      // 6. CARİ HESAP ENTEGRASYONU: Müşteriyi tekrar borçlandır
      if (tur == 'Alınan Senet' && cariKod.isNotEmpty) {
        final cariServis = CariHesaplarVeritabaniServisi();
        final int? cariId = await cariServis.cariIdGetir(
          cariKod,
          session: session,
        );

        if (cariId != null) {
          // Müşteriyi tekrar borçlandır (Açık ve net bir karşılıksız işlem kaydı)
          await cariServis.cariIslemEkle(
            cariId: cariId,
            tutar: tutar,
            isBorc: true, // Tekrar borç yazılıyor
            islemTuru: 'Senet Karşılıksız',
            aciklama: detayAciklama,
            tarih: tarih,
            kullanici: kullanici,
            kaynakId: senetId,
            session: session,
          );
        }
      }
    });
  }

  /// Senedin zaten tahsil edilmiş veya ciro edilmiş olup olmadığını kontrol eder
  Future<bool> senetIslemYapilmisMi(int senetId) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    final result = await _pool!.execute(
      Sql.named('''
        SELECT collection_status FROM promissory_notes 
        WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
      '''),
      parameters: {'id': senetId, 'companyId': _companyId},
    );

    if (result.isEmpty) return false;

    final status = result.first[0] as String? ?? '';
    return status == 'Tahsil Edildi' ||
        status == 'Ödendi' ||
        status == 'Ciro Edildi' ||
        status == 'Karşılıksız';
  }
}
