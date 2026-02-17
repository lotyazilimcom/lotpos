import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:intl/intl.dart';
import 'cari_hesaplar_veritabani_servisi.dart';
import 'kasalar_veritabani_servisi.dart';
import 'bankalar_veritabani_servisi.dart';
import 'oturum_servisi.dart';
import 'lisans_yazma_koruma.dart';
import 'lite_kisitlari.dart';
import 'bulut_sema_dogrulama_servisi.dart';
import 'pg_eklentiler.dart';
import '../sayfalar/ceksenet/modeller/cek_model.dart';
import 'veritabani_yapilandirma.dart';
import 'kredi_kartlari_veritabani_servisi.dart';

import '../yardimcilar/ceviri/islem_ceviri_yardimcisi.dart';
import '../yardimcilar/islem_turu_renkleri.dart';

class CeklerVeritabaniServisi {
  static final CeklerVeritabaniServisi _instance =
      CeklerVeritabaniServisi._internal();
  factory CeklerVeritabaniServisi() => _instance;
  CeklerVeritabaniServisi._internal();

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

  String _buildChequeSearchTags(
    CekModel cek, {
    required String integrationRef,
  }) {
    // UI'da görünen translate edilmiş durumları da ekle
    final turLabel = cek.tur == 'Alınan Çek'
        ? 'Alınan Çek' // UI'da bazen farklı olabilir, ama genelde bu
        : 'Verilen Çek';

    final tahsilatLabel = IslemCeviriYardimcisi.cevirDurum(cek.tahsilat);

    return _normalizeTurkish(
      '$_searchTagsVersionPrefix '
      '${cek.tur} '
      '$turLabel '
      '${cek.tahsilat} '
      '$tahsilatLabel '
      '${cek.cariKod} '
      '${cek.cariAdi} '
      '${cek.duzenlenmeTarihi} '
      '${cek.kesideTarihi} '
      '${cek.tutar} '
      '${cek.paraBirimi} '
      '${cek.cekNo} '
      '${cek.banka} '
      '${cek.aciklama} '
      '${cek.kullanici} '
      '${cek.aktifMi ? 'aktif' : 'pasif'} '
      '$integrationRef',
    );
  }

  String _buildChequeTransactionSearchTags({
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
    // Örn: type='check_status_change_collected' -> 'Tahsil Edildi'
    final String professionalLabel = IslemCeviriYardimcisi.cevir(
      IslemTuruRenkleri.getProfessionalLabel(type, context: 'check'),
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
          'CeklerVeritabaniServisi: Bulut şema hazır, tablo kurulumu atlandı.',
        );
      }
      _isInitialized = true;
      _initializedDatabase = targetDatabase;
      debugPrint(
        'CeklerVeritabaniServisi: Pool connection established successfully.',
      );
    } catch (e) {
      debugPrint('CeklerVeritabaniServisi: Connection error: $e');
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

    // Çekler Tablosu
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS cheques (
        id SERIAL PRIMARY KEY,
        company_id TEXT,
        type TEXT, -- Alınan Çek / Verilen Çek
        collection_status TEXT, -- Tahsil / Ödeme / Tahsil Edildi / Ödendi / Ciro Edildi
        customer_code TEXT,
        customer_name TEXT,
        issue_date TIMESTAMP,
        due_date TIMESTAMP,
        amount NUMERIC(15, 2) DEFAULT 0,
        currency TEXT,
        check_no TEXT,
        bank TEXT,
        description TEXT,
        user_name TEXT,
        is_active INTEGER DEFAULT 1,
        search_tags TEXT,
        matched_in_hidden INTEGER DEFAULT 0,
        integration_ref TEXT
      )
    ''');

    // Çek Hareketleri Tablosu (Giriş/Çıkış Tarihçesi)
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS cheque_transactions (
        id SERIAL PRIMARY KEY,
        company_id TEXT,
        cheque_id INTEGER,
        date TIMESTAMP,
        description TEXT,
        amount NUMERIC(15, 2) DEFAULT 0,
        type TEXT, -- Giriş, Çıkış, Tahsilat, Ödeme, Ciro
        source_dest TEXT, -- Kime/Kimden (Kasa, Banka, Cari Adı)
        user_name TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        search_tags TEXT,
        integration_ref TEXT
      )
    ''');

    // Migration: Eksik kolon varsa ekle
    try {
      await _pool!.execute(
        'ALTER TABLE cheques ADD COLUMN IF NOT EXISTS company_id TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE cheque_transactions ADD COLUMN IF NOT EXISTS company_id TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE cheque_transactions ADD COLUMN IF NOT EXISTS integration_ref TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE cheque_transactions ADD COLUMN IF NOT EXISTS search_tags TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE cheques ADD COLUMN IF NOT EXISTS integration_ref TEXT',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_cheques_ref ON cheques (integration_ref)',
      );
      await _pool!.execute(
        'ALTER TABLE cheques ADD COLUMN IF NOT EXISTS issue_date TIMESTAMP',
      );
      await _pool!.execute(
        'ALTER TABLE cheques ADD COLUMN IF NOT EXISTS due_date TIMESTAMP',
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

      // Çekler için arama indeksleri
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_cheques_search_tags_gin ON cheques USING GIN (search_tags gin_trgm_ops)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_cheques_check_no_trgm ON cheques USING GIN (check_no gin_trgm_ops)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_cheques_customer_name_trgm ON cheques USING GIN (customer_name gin_trgm_ops)',
      );

      // Hareketler için arama indeksleri
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_cheque_transactions_search_tags_gin ON cheque_transactions USING GIN (search_tags gin_trgm_ops)',
      );

      // B-Tree indeksleri (Filtreleme ve Sıralama)
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_cheques_company_id ON cheques (company_id)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_cheques_is_active ON cheques (is_active)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_cheques_type ON cheques (type)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_cheque_transactions_cheque_id ON cheque_transactions (cheque_id)',
      );

      // [2025 HYPERSCALE] BRIN Index for 10B rows (Range Scans)
      try {
        await _pool!.execute('''
          CREATE INDEX IF NOT EXISTS idx_cheques_issue_date_brin 
          ON cheques USING BRIN (issue_date) 
          WITH (pages_per_range = 128)
        ''');
        await _pool!.execute('''
          CREATE INDEX IF NOT EXISTS idx_cheques_due_date_brin 
          ON cheques USING BRIN (due_date) 
          WITH (pages_per_range = 128)
        ''');
      } catch (e) {
        debugPrint('BRIN index error: $e');
      }

      debugPrint(
        '🚀 Çekler Performans Modu: İndeksler başarıyla yapılandırıldı.',
      );
    } catch (e) {
      debugPrint('⚠️ Çek indeksleri oluşturulurken uyarı: $e');
    }

    // Initial indeksleme: arka planda çalıştır (sayfa açılışını bloklama)
    Future(() async {
      await verileriIndeksle(forceUpdate: false);
    });
  }

  /// Çekler ve çek hareketleri için search_tags indekslemesi yapar (Batch Processing)
  /// - forceUpdate=false: sadece v2 olmayan / boş search_tags kayıtlarını günceller
  Future<void> verileriIndeksle({bool forceUpdate = true}) async {
    if (_pool == null) return;

    try {
      debugPrint('🚀 Çek Arama İndeksleme Başlatılıyor (Batch Modu)...');

      const int batchSize = 500;
      int processedCheques = 0;
      int processedTransactions = 0;

      final String versionPredicate =
          "(search_tags IS NULL OR search_tags = '' OR search_tags NOT LIKE '$_searchTagsVersionPrefix%')";

      // 1) Cheques (main)
      int lastId = 0;
      while (true) {
        final idRows = await _pool!.execute(
          Sql.named(
            "SELECT id FROM cheques WHERE id > @lastId AND COALESCE(company_id, '$_defaultCompanyId') = @companyId ${forceUpdate ? '' : 'AND $versionPredicate'} ORDER BY id ASC LIMIT @batchSize",
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
            UPDATE cheques c
            SET search_tags = normalize_text(
              '$_searchTagsVersionPrefix ' ||
              COALESCE(c.type, '') || ' ' ||
              COALESCE(c.collection_status, '') || ' ' ||
              COALESCE(c.customer_code, '') || ' ' ||
              COALESCE(c.customer_name, '') || ' ' ||
              COALESCE(TO_CHAR(c.issue_date, 'DD.MM.YYYY'), '') || ' ' ||
              COALESCE(TO_CHAR(c.due_date, 'DD.MM.YYYY'), '') || ' ' ||
              COALESCE(CAST(c.amount AS TEXT), '') || ' ' ||
              COALESCE(c.currency, '') || ' ' ||
              COALESCE(c.check_no, '') || ' ' ||
              COALESCE(c.bank, '') || ' ' ||
              COALESCE(c.description, '') || ' ' ||
              COALESCE(c.user_name, '') || ' ' ||
              CAST(c.id AS TEXT) || ' ' ||
              (CASE WHEN c.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
              COALESCE(c.integration_ref, '')
            )
            WHERE c.id IN ($idListStr)
              AND COALESCE(c.company_id, '$_defaultCompanyId') = @companyId
              $conditionalWhere
          '''),
          parameters: {'companyId': _companyId},
        );

        processedCheques += ids.length;
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // 2) Transactions
      lastId = 0;
      while (true) {
        final idRows = await _pool!.execute(
          Sql.named(
            "SELECT id FROM cheque_transactions WHERE id > @lastId AND COALESCE(company_id, '$_defaultCompanyId') = @companyId ${forceUpdate ? '' : 'AND $versionPredicate'} ORDER BY id ASC LIMIT @batchSize",
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
            UPDATE cheque_transactions ct
            SET search_tags = normalize_text(
              '$_searchTagsVersionPrefix ' ||
              COALESCE(ct.type, '') || ' ' ||
              COALESCE(TO_CHAR(ct.date, 'DD.MM.YYYY HH24:MI'), '') || ' ' ||
              COALESCE(ct.description, '') || ' ' ||
              COALESCE(ct.source_dest, '') || ' ' ||
              COALESCE(ct.user_name, '') || ' ' ||
              COALESCE(CAST(ct.amount AS TEXT), '') || ' ' ||
              CAST(ct.id AS TEXT) || ' ' ||
              COALESCE(ct.integration_ref, '')
            )
            WHERE ct.id IN ($idListStr)
              AND COALESCE(ct.company_id, '$_defaultCompanyId') = @companyId
              $conditionalWhere
          '''),
          parameters: {'companyId': _companyId},
        );

        processedTransactions += ids.length;
        await Future.delayed(const Duration(milliseconds: 10));
      }

      debugPrint(
        '✅ Çek Arama İndeksleri Tamamlandı (forceUpdate: $forceUpdate). Çek: $processedCheques, Hareket: $processedTransactions',
      );
    } catch (e) {
      if (e is LisansYazmaEngelliHatasi) return;
      debugPrint('Çek indeksleme sırasında hata: $e');
    }
  }

  Future<void> _updateChequeSearchTags(int cekId, TxSession session) async {
    await session.execute(
      Sql.named('''
        UPDATE cheques c
        SET search_tags = normalize_text(
          '$_searchTagsVersionPrefix ' ||
          COALESCE(c.type, '') || ' ' ||
          COALESCE(c.collection_status, '') || ' ' ||
          COALESCE(c.customer_code, '') || ' ' ||
          COALESCE(c.customer_name, '') || ' ' ||
          COALESCE(TO_CHAR(c.issue_date, 'DD.MM.YYYY'), '') || ' ' ||
          COALESCE(TO_CHAR(c.due_date, 'DD.MM.YYYY'), '') || ' ' ||
          COALESCE(CAST(c.amount AS TEXT), '') || ' ' ||
          COALESCE(c.currency, '') || ' ' ||
          COALESCE(c.check_no, '') || ' ' ||
          COALESCE(c.bank, '') || ' ' ||
          COALESCE(c.description, '') || ' ' ||
          COALESCE(c.user_name, '') || ' ' ||
          CAST(c.id AS TEXT) || ' ' ||
          (CASE WHEN c.is_active = 1 THEN 'aktif' ELSE 'pasif' END) || ' ' ||
          COALESCE(c.integration_ref, '')
        )
        WHERE c.id = @id
          AND COALESCE(c.company_id, '$_defaultCompanyId') = @companyId
      '''),
      parameters: {'id': cekId, 'companyId': _companyId},
    );
  }

  /// Çekleri getirir - 1 Milyar Kayıt İçin Optimize Edilmiş Derin Arama
  Future<List<CekModel>> cekleriGetir({
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
    int? cekId,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    // Derin Arama SQL Yapısı
    String selectClause = 'SELECT cheques.*';

    if (aramaKelimesi != null && aramaKelimesi.isNotEmpty) {
      // Eşleşme detaydaysa yakala
      selectClause +=
          '''
          , (CASE 
              WHEN (
                normalize_text(COALESCE(cheques.customer_code, '')) LIKE @search OR
                normalize_text(COALESCE(cheques.description, '')) LIKE @search OR
                normalize_text(COALESCE(cheques.user_name, '')) LIKE @search OR
                normalize_text(COALESCE(cheques.collection_status, '')) LIKE @search OR
                EXISTS (
                  SELECT 1 FROM cheque_transactions ct 
                  WHERE ct.cheque_id = cheques.id 
                  AND COALESCE(ct.company_id, '$_defaultCompanyId') = @companyId
                  AND COALESCE(ct.search_tags, '') LIKE @search
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
      "COALESCE(cheques.company_id, '$_defaultCompanyId') = @companyId",
    );

    if (aramaKelimesi != null && aramaKelimesi.isNotEmpty) {
      conditions.add('''
        (
          COALESCE(cheques.search_tags, '') LIKE @search
          OR cheques.id IN (
            SELECT ct.cheque_id
            FROM cheque_transactions ct
            WHERE COALESCE(ct.company_id, '$_defaultCompanyId') = @companyId
            AND COALESCE(ct.search_tags, '') LIKE @search
            GROUP BY ct.cheque_id
          )
        )
      ''');
      params['search'] = '%${_normalizeTurkish(aramaKelimesi)}%';
    }

    if (aktifMi != null) {
      conditions.add('cheques.is_active = @isActive');
      params['isActive'] = aktifMi ? 1 : 0;
    }

    if (banka != null && banka.isNotEmpty) {
      conditions.add('cheques.bank = @banka');
      params['banka'] = banka;
    }

    // [2026 FACET FILTER] Tarih aralığı + işlem türü filtreleri transaction tablosundan uygulanır.
    // Bu sayede "Çek Alındı / Tahsil Edildi / Ciro Edildi" gibi gerçek hareket türleriyle filtreleme yapılır.
    if ((baslangicTarihi != null || bitisTarihi != null) ||
        (islemTuru != null && islemTuru.isNotEmpty) ||
        (kullanici != null && kullanici.isNotEmpty)) {
      String existsQuery =
          "EXISTS (SELECT 1 FROM cheque_transactions ct WHERE ct.cheque_id = cheques.id AND COALESCE(ct.company_id, '$_defaultCompanyId') = @companyId";

      if (baslangicTarihi != null) {
        existsQuery += ' AND ct.date >= @startDate';
        params['startDate'] = DateTime(
          baslangicTarihi.year,
          baslangicTarihi.month,
          baslangicTarihi.day,
        ).toIso8601String();
      }

      if (bitisTarihi != null) {
        existsQuery += ' AND ct.date < @endDate';
        params['endDate'] = DateTime(
          bitisTarihi.year,
          bitisTarihi.month,
          bitisTarihi.day,
        ).add(const Duration(days: 1)).toIso8601String();
      }

      if (islemTuru != null && islemTuru.isNotEmpty) {
        existsQuery += ' AND ct.type = @islemTuru';
        params['islemTuru'] = islemTuru;
      }

      if (kullanici != null && kullanici.isNotEmpty) {
        existsQuery += ' AND ct.user_name = @kullanici';
        params['kullanici'] = kullanici;
      }

      existsQuery += ')';
      conditions.add(existsQuery);
    }

    if (cekId != null) {
      conditions.add('cheques.id = @cekId');
      params['cekId'] = cekId;
    }

    String whereClause = '';
    if (conditions.isNotEmpty) {
      whereClause = ' WHERE ${conditions.join(' AND ')}';
    }

    // Sıralama
    String orderBy = 'cheques.id';
    if (siralama != null) {
      switch (siralama) {
        case 'kod':
          orderBy = 'cheques.check_no';
          break;
        case 'ad':
          orderBy = 'cheques.customer_name';
          break;
        case 'bakiye':
          orderBy = 'cheques.amount';
          break;
        case 'duzenlenmeTarihi':
          orderBy = 'cheques.issue_date';
          break;
        case 'kesideTarihi':
          orderBy = 'cheques.due_date';
          break;
      }
    }

    String query =
        '''
      $selectClause
      FROM cheques
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
      return CekModel.fromMap(
        map,
      ).copyWith(matchedInHidden: matchedInHiddenCalc);
    }).toList();
  }

  Future<int> cekSayisiGetir({
    String? aramaTerimi,
    bool? aktifMi,
    String? banka,
    String? kullanici,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? islemTuru,
    int? cekId,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;

    String query = 'SELECT COUNT(DISTINCT cheques.id) FROM cheques';
    List<String> conditions = [];
    Map<String, dynamic> params = {'companyId': _companyId};

    conditions.add(
      "COALESCE(cheques.company_id, '$_defaultCompanyId') = @companyId",
    );

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      conditions.add('''
        (
          COALESCE(cheques.search_tags, '') LIKE @search
          OR cheques.id IN (
            SELECT ct.cheque_id
            FROM cheque_transactions ct
            WHERE COALESCE(ct.company_id, '$_defaultCompanyId') = @companyId
            AND COALESCE(ct.search_tags, '') LIKE @search
            GROUP BY ct.cheque_id
          )
        )
      ''');
      params['search'] = '%${_normalizeTurkish(aramaTerimi)}%';
    }

    if (aktifMi != null) {
      conditions.add('cheques.is_active = @isActive');
      params['isActive'] = aktifMi ? 1 : 0;
    }

    if (banka != null && banka.isNotEmpty) {
      conditions.add('cheques.bank = @banka');
      params['banka'] = banka;
    }

    if ((baslangicTarihi != null || bitisTarihi != null) ||
        (islemTuru != null && islemTuru.isNotEmpty) ||
        (kullanici != null && kullanici.isNotEmpty)) {
      String existsQuery =
          "EXISTS (SELECT 1 FROM cheque_transactions ct WHERE ct.cheque_id = cheques.id AND COALESCE(ct.company_id, '$_defaultCompanyId') = @companyId";

      if (baslangicTarihi != null) {
        existsQuery += ' AND ct.date >= @startDate';
        params['startDate'] = DateTime(
          baslangicTarihi.year,
          baslangicTarihi.month,
          baslangicTarihi.day,
        ).toIso8601String();
      }

      if (bitisTarihi != null) {
        existsQuery += ' AND ct.date < @endDate';
        params['endDate'] = DateTime(
          bitisTarihi.year,
          bitisTarihi.month,
          bitisTarihi.day,
        ).add(const Duration(days: 1)).toIso8601String();
      }

      if (islemTuru != null && islemTuru.isNotEmpty) {
        existsQuery += ' AND ct.type = @islemTuru';
        params['islemTuru'] = islemTuru;
      }

      if (kullanici != null && kullanici.isNotEmpty) {
        existsQuery += ' AND ct.user_name = @kullanici';
        params['kullanici'] = kullanici;
      }

      existsQuery += ')';
      conditions.add(existsQuery);
    }

    if (cekId != null) {
      conditions.add('cheques.id = @cekId');
      params['cekId'] = cekId;
    }

    if (conditions.isNotEmpty) {
      query += ' WHERE ${conditions.join(' AND ')}';
    }

    final result = await _pool!.execute(Sql.named(query), parameters: params);
    return result[0][0] as int;
  }

  /// [2026 HYPER-SPEED] Dinamik filtre seçeneklerini ve sayıları getirir.
  /// Büyük veri için optimize edilmiştir (SARGable predicates + EXISTS).
  Future<Map<String, Map<String, int>>> cekFiltreIstatistikleriniGetir({
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
      "COALESCE(cheques.company_id, '$_defaultCompanyId') = @companyId",
    );

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      baseConditions.add('''
        (
          COALESCE(cheques.search_tags, '') LIKE @search
          OR cheques.id IN (
            SELECT ct.cheque_id
            FROM cheque_transactions ct
            WHERE COALESCE(ct.company_id, '$_defaultCompanyId') = @companyId
            AND COALESCE(ct.search_tags, '') LIKE @search
            GROUP BY ct.cheque_id
          )
        )
      ''');
      params['search'] = '%${_normalizeTurkish(aramaTerimi)}%';
    }

    // Transaction conditions used across facets (always includes company filter)
    String transactionFilters =
        " AND COALESCE(ct.company_id, '$_defaultCompanyId') = @companyId";
    if (baslangicTarihi != null) {
      transactionFilters += ' AND ct.date >= @start';
      params['start'] = DateTime(
        baslangicTarihi.year,
        baslangicTarihi.month,
        baslangicTarihi.day,
      ).toIso8601String();
    }
    if (bitisTarihi != null) {
      transactionFilters += ' AND ct.date < @end';
      params['end'] = DateTime(
        bitisTarihi.year,
        bitisTarihi.month,
        bitisTarihi.day,
      ).add(const Duration(days: 1)).toIso8601String();
    }

    if (baslangicTarihi != null || bitisTarihi != null) {
      baseConditions.add('''
        EXISTS (
          SELECT 1 FROM cheque_transactions ct 
          WHERE ct.cheque_id = cheques.id 
          $transactionFilters
        )
      ''');
    }

    String buildQuery(String selectAndGroup, List<String> facetConds) {
      String where = (baseConditions.isNotEmpty || facetConds.isNotEmpty)
          ? 'WHERE ${(baseConditions + facetConds).join(' AND ')}'
          : '';
      return 'SELECT $selectAndGroup FROM (SELECT * FROM cheques $where LIMIT 100001) as sub GROUP BY 1';
    }

    // 1. Banka istatistikleri (dinamik)
    List<String> bankConds = [];
    Map<String, dynamic> bankParams = Map.from(params);
    if ((islemTuru != null && islemTuru.isNotEmpty) ||
        (kullanici != null && kullanici.isNotEmpty)) {
      String existsQuery = '''
        EXISTS (
          SELECT 1 FROM cheque_transactions ct 
          WHERE ct.cheque_id = cheques.id 
      ''';

      if (islemTuru != null && islemTuru.isNotEmpty) {
        existsQuery += ' AND ct.type = @islemTuru';
        bankParams['islemTuru'] = islemTuru;
      }

      if (kullanici != null && kullanici.isNotEmpty) {
        existsQuery += ' AND ct.user_name = @kullanici';
        bankParams['kullanici'] = kullanici;
      }

      existsQuery += '$transactionFilters\n        )';
      bankConds.add(existsQuery);
    }

    // 2. İşlem türü istatistikleri (dinamik)
    List<String> typeConds = [];
    Map<String, dynamic> typeParams = Map.from(params);
    if (banka != null && banka.isNotEmpty) {
      typeConds.add('cheques.bank = @banka');
      typeParams['banka'] = banka;
    }
    if (kullanici != null && kullanici.isNotEmpty) {
      typeConds.add('ct.user_name = @kullanici');
      typeParams['kullanici'] = kullanici;
    }

    // 3. Kullanıcı istatistikleri (dinamik)
    List<String> userConds = [];
    Map<String, dynamic> userParams = Map.from(params);
    if (banka != null && banka.isNotEmpty) {
      userConds.add('cheques.bank = @banka');
      userParams['banka'] = banka;
    }
    if (islemTuru != null && islemTuru.isNotEmpty) {
      userConds.add('ct.type = @islemTuru');
      userParams['islemTuru'] = islemTuru;
    }

    final results = await Future.wait([
      // Toplam (search + tarih aralığı bazında)
      _pool!.execute(
        Sql.named(
          'SELECT COUNT(*) FROM cheques ${baseConditions.isNotEmpty ? 'WHERE ${baseConditions.join(' AND ')}' : ''}',
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
        SELECT ct.type, COUNT(DISTINCT cheques.id)
        FROM cheques
        JOIN cheque_transactions ct ON ct.cheque_id = cheques.id
        WHERE ${(baseConditions + typeConds).join(' AND ')}
        $transactionFilters
        GROUP BY ct.type
      '''),
        parameters: typeParams,
      ),
      // Kullanıcılar (transaction.user_name)
      _pool!.execute(
        Sql.named('''
        SELECT ct.user_name, COUNT(DISTINCT cheques.id)
        FROM cheques
        JOIN cheque_transactions ct ON ct.cheque_id = cheques.id
        WHERE ${(baseConditions + userConds).join(' AND ')}
        $transactionFilters
        GROUP BY ct.user_name
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
        "SELECT t.*, c.check_no as cek_no, c.customer_name as cari_adi, c.customer_code as cari_kod, c.collection_status as tahsilat, c.issue_date as duzenlenme_tarihi, c.due_date as keside_tarihi, c.currency as para_birimi FROM cheque_transactions t LEFT JOIN cheques c ON t.cheque_id = c.id WHERE COALESCE(t.company_id, '$_defaultCompanyId') = @companyId ORDER BY t.created_at DESC LIMIT 50",
      ),
      parameters: {'companyId': _companyId},
    );

    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<List<Map<String, dynamic>>> cekIslemleriniGetir(
    int cekId, {
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
             c.check_no as cek_no, 
             c.customer_name as cari_adi 
      FROM cheque_transactions t 
      LEFT JOIN cheques c ON t.cheque_id = c.id 
      WHERE t.cheque_id = @cekId 
      AND COALESCE(t.company_id, '$_defaultCompanyId') = @companyId
    ''';
    Map<String, dynamic> params = {'cekId': cekId, 'companyId': _companyId};

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
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<List<String>> getMevcutIslemTurleri() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    final result = await _pool!.execute(
      Sql.named(
        "SELECT DISTINCT type FROM cheque_transactions WHERE COALESCE(company_id, '$_defaultCompanyId') = @companyId ORDER BY type ASC",
      ),
      parameters: {'companyId': _companyId},
    );

    return result
        .where((r) => r[0] != null)
        .map((r) => r[0] as String)
        .toList();
  }

  Future<void> cekEkle(
    CekModel cek, {
    TxSession? session,
    bool cariEntegrasyonYap = true,
  }) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isCheckPromissoryActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde çek işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // [2026 FIX] integrationRef yoksa otomatik oluştur
    // Bu, ciro işleminde orijinal cari kaydının bulunabilmesini sağlar
    final String finalIntegrationRef =
        cek.integrationRef ??
        'cheque_${cek.cariKod}_${DateTime.now().millisecondsSinceEpoch}';

    Future<void> operation(TxSession s) async {
      // 1. ÇEK KAYDI
      final result = await s.execute(
        Sql.named('''
          INSERT INTO cheques (
            company_id,
            type, collection_status, customer_code, customer_name, 
            issue_date, due_date, amount, currency, check_no, bank, 
            description, user_name, is_active, search_tags, matched_in_hidden, integration_ref
          )
          VALUES (
            @companyId,
            @type, @collection_status, @customer_code, @customer_name, 
            @issue_date, @due_date, @amount, @currency, @check_no, @bank, 
            @description, @user_name, @is_active, @search_tags, @matched_in_hidden, @integration_ref
          )
          RETURNING id
        '''),
        parameters: {
          'companyId': _companyId,
          'type': cek.tur,
          'collection_status': cek.tahsilat.isEmpty
              ? 'Portföyde'
              : cek.tahsilat,
          'customer_code': cek.cariKod,
          'customer_name': cek.cariAdi,
          'issue_date': DateFormat('dd.MM.yyyy').parse(cek.duzenlenmeTarihi),
          'due_date': DateFormat('dd.MM.yyyy').parse(cek.kesideTarihi),
          'amount': cek.tutar,
          'currency': cek.paraBirimi,
          'check_no': cek.cekNo,
          'bank': cek.banka,
          'description': cek.aciklama,
          'user_name': cek.kullanici,
          'is_active': cek.aktifMi ? 1 : 0,
          'search_tags': _buildChequeSearchTags(
            cek,
            integrationRef: finalIntegrationRef,
          ),
          'matched_in_hidden': cek.matchedInHidden ? 1 : 0,
          'integration_ref': finalIntegrationRef,
        },
      );

      final int newId = result[0][0] as int;

      // 2. İLK HAREKET (Portföye Giriş veya Verilen Çek Çıkışı)
      // Mantık:
      // Alınan Çek -> 'Çek Alındı'
      // Verilen Çek -> 'Çek Verildi'
      final String hareketTuru = cek.tur == 'Alınan Çek'
          ? 'Çek Alındı'
          : 'Çek Verildi';
      final String islemAciklamasi = cek.aciklama;

      final DateTime parsedDate = DateFormat(
        'dd.MM.yyyy',
      ).parse(cek.duzenlenmeTarihi);
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
          INSERT INTO cheque_transactions 
          (company_id, cheque_id, date, description, amount, type, source_dest, user_name, search_tags, integration_ref)
          VALUES 
          (@companyId, @cheque_id, @date, @description, @amount, @type, @source_dest, @user_name, @search_tags, @integration_ref)
        '''),
        parameters: {
          'companyId': _companyId,
          'cheque_id': newId,
          'date': islemTarihi,
          'description': islemAciklamasi,
          'amount': cek.tutar,
          'type': hareketTuru,
          'source_dest': cek.cariAdi, // Kimden alındı / Kime verildi
          'user_name': cek.kullanici,
          'search_tags': _buildChequeTransactionSearchTags(
            date: islemTarihi,
            description: islemAciklamasi,
            amount: cek.tutar,
            type: hareketTuru,
            sourceDest: cek.cariAdi,
            userName: cek.kullanici,
            integrationRef: finalIntegrationRef,
          ),
          'integration_ref': finalIntegrationRef,
        },
      );

      // --- ENTEGRASYON: CARİ HESAP BAKİYE GÜNCELLEME ---
      if (cariEntegrasyonYap && cek.cariKod.isNotEmpty) {
        final cariServis = CariHesaplarVeritabaniServisi();
        final int? cariId = await cariServis.cariIdGetir(
          cek.cariKod,
          session: s,
        );

        if (cariId != null) {
          bool isBorc = cek.tur == 'Verilen Çek';

          await cariServis.cariIslemEkle(
            cariId: cariId,
            tutar: cek.tutar,
            isBorc: isBorc,
            islemTuru: isBorc ? 'Çek Verildi' : 'Çek Alındı',
            aciklama: cek.aciklama,
            tarih: islemTarihi,
            kullanici: cek.kullanici,
            kaynakId: newId,
            kaynakAdi: '${cek.cariAdi}\nÇek ${cek.cekNo}\n${cek.banka}',
            kaynakKodu: cek.cekNo,
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

  Future<void> cekGuncelle(CekModel cek) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isCheckPromissoryActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde çek işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // Eski kaydı al (Cari entegrasyonu tersine çevirmek için)
      final oldResult = await session.execute(
        Sql.named(
          "SELECT * FROM cheques WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': cek.id, 'companyId': _companyId},
      );

      if (oldResult.isEmpty) return;
      final oldRow = oldResult.first.toColumnMap();
      final double oldAmount =
          double.tryParse(oldRow['amount']?.toString() ?? '') ?? 0.0;
      final String oldType = oldRow['type'] as String? ?? '';
      final String oldCustomerCode = oldRow['customer_code'] as String? ?? '';
      final String finalRef =
          cek.integrationRef ?? (oldRow['integration_ref'] as String? ?? '');

      // Çek Kartını Güncelle
      await session.execute(
        Sql.named('''
          UPDATE cheques 
          SET type=@type, collection_status=@collection_status, 
              customer_code=@customer_code, customer_name=@customer_name, 
              issue_date=@issue_date, due_date=@due_date, amount=@amount, 
              currency=@currency, check_no=@check_no, bank=@bank, 
              description=@description, user_name=@user_name, is_active=@is_active,
              search_tags=@search_tags
          WHERE id=@id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
        '''),
        parameters: {
          'id': cek.id,
          'companyId': _companyId,
          'type': cek.tur,
          'collection_status': cek.tahsilat,
          'customer_code': cek.cariKod,
          'customer_name': cek.cariAdi,
          'issue_date': DateFormat('dd.MM.yyyy').parse(cek.duzenlenmeTarihi),
          'due_date': DateFormat('dd.MM.yyyy').parse(cek.kesideTarihi),
          'amount': cek.tutar,
          'currency': cek.paraBirimi,
          'check_no': cek.cekNo,
          'bank': cek.banka,
          'description': cek.aciklama,
          'user_name': cek.kullanici,
          'is_active': cek.aktifMi ? 1 : 0,
          'search_tags': _buildChequeSearchTags(cek, integrationRef: finalRef),
        },
      );

      // --- CARİ ENTEGRASYON DÜZELTME ---
      final cariServis = CariHesaplarVeritabaniServisi();

      // [2025 SMART UPDATE] Ref Varsa ve Cari Değişmediyse -> Update
      if (oldCustomerCode == cek.cariKod && finalRef.isNotEmpty) {
        bool isBorc = cek.tur == 'Verilen Çek';
        await cariServis.cariIslemGuncelleByRef(
          ref: finalRef,
          tarih: DateFormat('dd.MM.yyyy').parse(cek.duzenlenmeTarihi),
          aciklama: cek.aciklama,
          tutar: cek.tutar,
          isBorc: isBorc,
          kaynakAdi: cek.cariAdi,
          kaynakKodu: cek.cekNo,
          kullanici: cek.kullanici,
          session: session,
        );
      } else {
        // A. Eski İşlemi Sil
        if (finalRef.isNotEmpty) {
          await cariServis.cariIslemSilByRef(finalRef, session: session);
        } else if (oldCustomerCode.isNotEmpty) {
          final int? oldCariId = await cariServis.cariIdGetir(
            oldCustomerCode,
            session: session,
          );
          if (oldCariId != null) {
            bool wasBorc = oldType == 'Verilen Çek';
            await cariServis.cariIslemSil(
              oldCariId,
              oldAmount,
              wasBorc,
              kaynakTur: 'Çek',
              kaynakId: cek.id,
              session: session,
            );
          }
        }

        // B. Yeni İşlemi Ekle
        if (cek.cariKod.isNotEmpty) {
          final int? newCariId = await cariServis.cariIdGetir(
            cek.cariKod,
            session: session,
          );
          if (newCariId != null) {
            bool isBorc = cek.tur == 'Verilen Çek';
            await cariServis.cariIslemEkle(
              cariId: newCariId,
              tutar: cek.tutar,
              isBorc: isBorc,
              islemTuru: isBorc ? 'Çek Verildi' : 'Çek Alındı',
              aciklama: cek.aciklama,
              tarih: DateFormat('dd.MM.yyyy').parse(cek.duzenlenmeTarihi),
              kullanici: cek.kullanici,
              kaynakId: cek.id,
              kaynakAdi: cek.cariAdi,
              kaynakKodu: cek.cekNo,
              entegrasyonRef: finalRef,
              session: session,
            );
          }
        }
      }
    });
  }

  Future<void> cekSil(int id, {TxSession? session}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    Future<void> operation(TxSession s) async {
      // Silinecek çeki bul
      final result = await s.execute(
        Sql.named(
          "SELECT * FROM cheques WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      if (result.isEmpty) return;
      final row = result.first.toColumnMap();
      final double amount =
          double.tryParse(row['amount']?.toString() ?? '') ?? 0.0;
      final String type = row['type'] as String? ?? '';
      final String customerCode = row['customer_code'] as String? ?? '';

      // Tablolardan sil
      await s.execute(
        Sql.named(
          "DELETE FROM cheques WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );
      await s.execute(
        Sql.named(
          "DELETE FROM cheque_transactions WHERE cheque_id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': id, 'companyId': _companyId},
      );

      // --- MALİ ENTEGRASYONLARI TEMİZLE (Kasa, Banka, Kredi Kartı) ---
      final txRows = await s.execute(
        Sql.named(
          "SELECT integration_ref FROM cheque_transactions WHERE cheque_id = @id AND integration_ref IS NOT NULL AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
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

      // --- CARİ ENTEGRASYONUNU GERİ AL ---
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
          bool wasBorc = type == 'Verilen Çek';
          await cariServis.cariIslemSil(
            cariId,
            amount,
            wasBorc,
            kaynakTur: 'Çek',
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

  Future<bool> cekNoVarMi(String cekNo, {int? haricId}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    String query =
        "SELECT COUNT(*) FROM cheques WHERE check_no = @check_no AND COALESCE(company_id, '$_defaultCompanyId') = @companyId";
    Map<String, dynamic> params = {'check_no': cekNo, 'companyId': _companyId};

    if (haricId != null) {
      query += ' AND id != @haricId';
      params['haricId'] = haricId;
    }

    final result = await _pool!.execute(Sql.named(query), parameters: params);

    return (result[0][0] as int) > 0;
  }

  /// Entegrasyon referansına göre çekleri bulur ve siler.
  /// (Alış/Satış faturası silindiğinde kullanılır)
  ///
  /// [KRİTİK] Bu fonksiyon sadece çeki silmez, aynı zamanda:
  /// 1. Tahsil edilmiş/Ciro edilmiş çeklerin Kasa/Banka işlemlerini geri alır
  /// 2. İlişkili tüm hareket kayıtlarını temizler
  /// 3. Ciro edilmişse, tedarikçinin bakiyesini de düzeltir (Ters Kayıt/Silme)
  /// Bu sayede "Hayalet Para" sorunu önlenir.
  /// [2025 GUARD]: Çifte Silme Koruma - Aynı ref ile işlem yoksa erken çık
  Future<void> cekSilByRef(String ref, {TxSession? session}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // [2025 GUARD] Boş veya geçersiz referans kontrolü
    if (ref.isEmpty) {
      debugPrint('[GUARD] cekSilByRef: Boş ref ile çağrıldı, atlanıyor.');
      return;
    }

    final executor = session ?? _pool!;

    // Referansa sahip çekleri bul
    final rows = await executor.execute(
      Sql.named(
        "SELECT id, collection_status FROM cheques WHERE integration_ref = @ref AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
      ),
      parameters: {'ref': ref, 'companyId': _companyId},
    );

    // [2025 GUARD] Çifte silme veya olmayan işlem kontrolü
    if (rows.isEmpty) {
      debugPrint(
        '[GUARD] cekSilByRef: ref=$ref için çek bulunamadı (zaten silinmiş veya hiç oluşturulmamış).',
      );
      return;
    }

    final cariServis = CariHesaplarVeritabaniServisi();

    for (final row in rows) {
      final int cekId = row[0] as int;
      final String durum = row[1] as String? ?? '';

      // 1. [Gizli Para Temizliği]: Finansal Kurum Entegrasyonlarını Geri Al
      if (['Tahsil Edildi', 'Ödendi', 'Ciro Edildi'].contains(durum)) {
        final txRows = await executor.execute(
          Sql.named(
            "SELECT integration_ref FROM cheque_transactions WHERE cheque_id = @cekId AND integration_ref IS NOT NULL AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
          ),
          parameters: {'cekId': cekId, 'companyId': _companyId},
        );

        for (final txRow in txRows) {
          final String? intRef = txRow[0] as String?;
          if (intRef != null && intRef.isNotEmpty) {
            await KasalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
              intRef,
              haricKasaIslemId: -1,
              silinecekCariyiEtkilesin: false,
              session: session,
            );
            await BankalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
              intRef,
              haricBankaIslemId: -1,
              silinecekCariyiEtkilesin: false,
              session: session,
            );
            // Kredi kartı entegrasyonu varsa onu da sil
            await KrediKartlariVeritabaniServisi()
                .entegrasyonBaglantiliIslemleriSil(
                  intRef,
                  haricKrediKartiIslemId: -1,
                  session: session,
                );
          }
        }
      }

      // 2. [CİRO DÜZELTME]: Çekin oluşturduğu tüm CARİ hareketleri sil
      // (Müşteriden alınan çek girişi VE Tedarikçiye verilen ciro çıkışı dahil)

      final etkilenenCariler = await cariServis
          .kaynakIdIleEtkilenenCarileriGetir(kaynakTur: 'Çek', kaynakId: cekId);

      for (final cariHareket in etkilenenCariler) {
        // cariIslemSil(cariId, tutar, isBorc, {kaynakId, kaynakTur})
        await cariServis.cariIslemSil(
          cariHareket['cariId'], // Positional 1
          cariHareket['tutar'], // Positional 2
          cariHareket['isBorc'], // Positional 3
          kaynakTur: 'Çek',
          kaynakId: cekId,
          session: session,
        );
      }

      // 3. [FIX] Tüm Hareketlerin Cari Entegrasyonlarını Temizle (Ciro Dahil)
      final txs = await executor.execute(
        Sql.named(
          "SELECT id FROM cheque_transactions WHERE cheque_id = @cekId AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'cekId': cekId, 'companyId': _companyId},
      );

      for (final tx in txs) {
        final int txId = tx[0] as int;
        // Bu harekete bağlı cari işlemleri sil (Ciro, Tahsilat vb.)
        await cariServis.cariIslemSilOrphaned(kaynakId: txId, session: session);
      }

      // 4. Çeki Sil
      await cekSil(cekId, session: session);
    }
  }

  // ---------------------------------------------------------------------------
  // PROFESYONEL ÇEK İŞLEMLERİ: TAHSİL & CİRO
  // ---------------------------------------------------------------------------

  /// Çek tahsil et - Çekin tahsilat durumunu günceller ve hareket ekler
  /// [yerTuru] Örn: "Kasa" veya "Banka"
  Future<void> cekTahsilEt({
    required int cekId,
    required String yerTuru, // 'Merkez Kasa' vb. görünen ad
    required String yerKodu,
    required String yerAdi,
    required String aciklama,
    required DateTime tarih,
    required String kullanici,
  }) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isCheckPromissoryActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde çek işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // 1. Çek Verisini Al
      final checkRes = await session.execute(
        Sql.named(
          "SELECT * FROM cheques WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': cekId, 'companyId': _companyId},
      );
      if (checkRes.isEmpty) return;

      final checkRow = checkRes.first.toColumnMap();
      final double tutar =
          double.tryParse(checkRow['amount']?.toString() ?? '') ?? 0.0;
      final String tur = checkRow['type'] as String? ?? ''; // Alınan/Verilen

      final String cariKod = checkRow['customer_code'] as String? ?? '';
      final String cariAd = checkRow['customer_name'] as String? ?? '';
      final String mevcutDurum = checkRow['collection_status'] as String? ?? '';

      // [VALIDATION] Çekin zaten işlem görmüş olup olmadığını kontrol et
      if (mevcutDurum == 'Ciro Edildi' ||
          mevcutDurum == 'Tahsil Edildi' ||
          mevcutDurum == 'Ödendi' ||
          mevcutDurum == 'Karşılıksız') {
        debugPrint(
          '⚠️ Çek zaten işlem görmüş! Mevcut durum: $mevcutDurum. Tahsil/Ödeme işlemi yapılamaz.',
        );
        throw Exception(
          'Bu çek zaten "$mevcutDurum" durumunda. Tekrar tahsil/ödeme yapılamaz.',
        );
      }

      // 2. Durum ve Açıklama Belirle
      String yeniDurum;
      String islemTuru; // 'Giriş' veya 'Çıkış'
      String detayAciklama = aciklama;
      String kaynakHedef = yerAdi;

      if (tur == 'Alınan Çek') {
        yeniDurum = 'Tahsil Edildi';
        islemTuru = 'Çek Tahsil';
      } else {
        yeniDurum = 'Ödendi';
        islemTuru = 'Çek Ödendi';
      }

      await session.execute(
        Sql.named('''
          UPDATE cheques 
          SET collection_status = @status, is_active = 0 
          WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
        '''),
        parameters: {'status': yeniDurum, 'id': cekId, 'companyId': _companyId},
      );
      await _updateChequeSearchTags(cekId, session);

      // [ENTEGRASYON] Cari Hesap Islem Turunu Guncelle (Görsel Durum Takibi)
      final String? initialRef = checkRow['integration_ref'] as String?;
      if (initialRef != null && initialRef.isNotEmpty) {
        await session.execute(
          Sql.named('''
          UPDATE current_account_transactions 
          SET source_type = @yeniIslemTuru 
          WHERE integration_ref = @ref
        '''),
          parameters: {
            'yeniIslemTuru': tur == 'Alınan Çek'
                ? 'Çek Alındı ($yeniDurum)'
                : 'Çek Verildi ($yeniDurum)',
            'ref': initialRef,
          },
        );
      }

      final String intRef =
          'cheque_collect_${cekId}_${DateTime.now().millisecondsSinceEpoch}';

      // 4. Tahsilat Hareketi Ekle
      await session.execute(
        Sql.named('''
          INSERT INTO cheque_transactions 
          (company_id, cheque_id, date, description, amount, type, source_dest, user_name, search_tags, integration_ref)
          VALUES 
          (@companyId, @cheque_id, @date, @description, @amount, @type, @source_dest, @user_name, @search_tags, @integration_ref)
        '''),
        parameters: {
          'companyId': _companyId,
          'cheque_id': cekId,
          'date': tarih,
          'description': detayAciklama,
          'amount': tutar,
          'type': islemTuru,
          'source_dest': kaynakHedef,
          'user_name': kullanici,
          'search_tags': _buildChequeTransactionSearchTags(
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

      // 5. MALI ENTEGRASYON: KASA veya BANKA'ya Para Giriş/Çıkışı
      // [FIX] UI'dan gelen 'yerTuru' stringine güvenme (Çeviri hatası olabilir).
      // Önce Kasa'da ara, bulamazsan Banka'da ara.

      final kasaServis = KasalarVeritabaniServisi();
      final kasalar = await kasaServis.kasaAra(yerKodu, limit: 1);

      if (kasalar.isNotEmpty) {
        // İşlem Kasa ile ilgili
        String kasaIslem = tur == 'Alınan Çek' ? 'Tahsilat' : 'Ödeme';
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
          cariEntegrasyonYap:
              false, // Çek zaten cariye işlendiği için tekrar işleme
        );
      } else {
        // Kasa değilse Banka mı?
        final bankaServis = BankalarVeritabaniServisi();
        final bankalar = await bankaServis.bankaAra(yerKodu, limit: 1);
        if (bankalar.isNotEmpty) {
          // İşlem Banka ile ilgili
          String bankaIslem = tur == 'Alınan Çek' ? 'Tahsilat' : 'Ödeme';
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
            cariEntegrasyonYap:
                false, // Çek zaten cariye işlendiği için tekrar işleme
          );
        } else {
          // Ne kasa ne banka bulundu, logla ama hata fırlatma (Pasif işlem)
          debugPrint('⚠️ Tahsilat yeri bulunamadı: $yerKodu ($yerTuru)');
        }
      }
    });
  }

  /// Çek Ciro Etme (Sadece Alınan Çek İçin)
  /// Çeki 3. şahsa (Tedarikçiye) devrediyoruz.
  Future<void> cekCiroEt({
    required int cekId,
    required String cariKodu,
    required String cariAdi,
    required String aciklama,
    required DateTime tarih,
    required String kullanici,
  }) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isCheckPromissoryActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde çek işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // 1. Çek Verisini Al
      final checkRes = await session.execute(
        Sql.named(
          "SELECT * FROM cheques WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': cekId, 'companyId': _companyId},
      );

      if (checkRes.isEmpty) return;
      final checkRow = checkRes.first.toColumnMap();
      final double tutar =
          double.tryParse(checkRow['amount']?.toString() ?? '') ?? 0.0;
      final String mevcutDurum = checkRow['collection_status'] as String? ?? '';

      // [VALIDATION] Çekin zaten işlem görmüş olup olmadığını kontrol et
      if (mevcutDurum == 'Ciro Edildi' ||
          mevcutDurum == 'Tahsil Edildi' ||
          mevcutDurum == 'Ödendi' ||
          mevcutDurum == 'Karşılıksız') {
        debugPrint(
          '⚠️ Çek zaten işlem görmüş! Mevcut durum: $mevcutDurum. Ciro işlemi yapılamaz.',
        );
        throw Exception(
          'Bu çek zaten "$mevcutDurum" durumunda. Tekrar ciro edilemez.',
        );
      }

      // Sadece 'Alınan Çek' ciro edilebilir (Genel kural)
      // Ancak kod bozulmaması için kontrol esnek bırakılabilir, biz yine de loglayacağız.

      // 2. Durum ve Açıklama
      const String yeniDurum = 'Ciro Edildi';
      const String islemTuru = 'Çek Ciro'; // Portföyden Çıktı
      String detayAciklama = aciklama;
      String kaynakHedef = cariAdi; // Kime verildi?

      // 3. Çeki Güncelle
      await session.execute(
        Sql.named('''
          UPDATE cheques 
          SET collection_status = @status, is_active = 0 
          WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
        '''),
        parameters: {'status': yeniDurum, 'id': cekId, 'companyId': _companyId},
      );
      await _updateChequeSearchTags(cekId, session);

      // [2026 FIX] Orijinal Cari İşlemini Güncelle (Çek Alındı -> Çek Alındı (Ciro Edildi))
      // Ayrıca İlgili Hesap bilgisine Ciro bilgisini ekle
      final String? initialRef = checkRow['integration_ref'] as String?;
      final String orijinalCariAdi =
          checkRow['customer_name']?.toString() ?? '';
      final String cekNo = checkRow['check_no']?.toString() ?? '';

      // [2026 FIX] GENİŞ KAPSAMLI GÜNCELLEME
      // Hem integration_ref (yeni kayıtlar) hem de source_id (eski/kopuk kayıtlar) üzerinden dener.
      // Böylece eski kayıtlarda ref olmasa bile ID üzerinden yakalar.
      String whereClause =
          "source_id = @cekId AND source_type IN ('Çek Alındı', 'Çek Verildi')";
      Map<String, dynamic> updateParams = {
        'sourceName': '$orijinalCariAdi\nÇek $cekNo\nCiro $cariAdi',
        'cekId': cekId,
      };

      if (initialRef != null && initialRef.isNotEmpty) {
        whereClause = "($whereClause) OR integration_ref = @ref";
        updateParams['ref'] = initialRef;
      }

      await session.execute(
        Sql.named('''
          UPDATE current_account_transactions 
          SET source_type = 'Çek Alındı (Ciro Edildi)',
              source_name = @sourceName
          WHERE $whereClause
        '''),
        parameters: updateParams,
      );

      // 4. Ciro Hareketi Ekle
      final String ciroIntRef =
          'ciro_${cekId}_${DateTime.now().millisecondsSinceEpoch}';
      final txResult = await session.execute(
        Sql.named('''
          INSERT INTO cheque_transactions 
          (company_id, cheque_id, date, description, amount, type, source_dest, user_name, search_tags, integration_ref)
          VALUES 
          (@companyId, @cheque_id, @date, @description, @amount, @type, @source_dest, @user_name, @search_tags, @integration_ref)
          RETURNING id
        '''),
        parameters: {
          'companyId': _companyId,
          'cheque_id': cekId,
          'date': tarih,
          'description': detayAciklama,
          'amount': tutar,
          'type': islemTuru, // 'Çıkış'
          'source_dest': kaynakHedef,
          'user_name': kullanici,
          'search_tags': _buildChequeTransactionSearchTags(
            date: tarih,
            description: '$yeniDurum $detayAciklama',
            amount: tutar,
            type: islemTuru,
            sourceDest: kaynakHedef,
            userName: kullanici,
            integrationRef: ciroIntRef,
          ),
          'integration_ref': ciroIntRef,
        },
      );
      final int txId = txResult.first[0] as int;

      // --- ENTEGRASYON: CARİ HESAP GÜNCELLEME (TEDARİKÇİYE ÇIKIŞ) ---
      // Çeki X kişisine (Tedarikçi) veriyoruz, borcumuz düşüyor.
      // isBorc: true (Borç), islemTuru: 'Çek Verildi (Ciro Edildi)'
      if (cariKodu.isNotEmpty) {
        final cariServis = CariHesaplarVeritabaniServisi();
        final int? cariId = await cariServis.cariIdGetir(
          cariKodu,
          session: session,
        );

        if (cariId != null) {
          await cariServis.cariIslemEkle(
            cariId: cariId,
            tutar: tutar,
            isBorc: true, // Borçtan düşülecek (Tedarikçiye ödeme)
            islemTuru: 'Çek Verildi (Ciro Edildi)',
            aciklama: detayAciklama,
            tarih: tarih,
            kullanici: kullanici,
            kaynakId: txId,
            kaynakAdi: '$cariAdi\nÇek $cekNo\nCiro $orijinalCariAdi',
            kaynakKodu: cekNo,
            entegrasyonRef: ciroIntRef,
            session: session,
          );
        }
      }
    });
  }

  /// Çek işlemini siler ve mali etkileri geri alır
  Future<void> cekIsleminiSil(int islemId) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // 1. İşlemi bul
      final txRes = await session.execute(
        Sql.named(
          "SELECT * FROM cheque_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': islemId, 'companyId': _companyId},
      );
      if (txRes.isEmpty) return;
      final tx = txRes.first.toColumnMap();
      final int cekId = tx['cheque_id'] as int;
      final String? intRef = tx['integration_ref'] as String?;
      final double tutar =
          double.tryParse(tx['amount']?.toString() ?? '') ?? 0.0;
      final String type = tx['type']?.toString() ?? '';

      // 2. Kasa/Banka Entegrasyonlarını Geri Al
      if ((intRef ?? '').isNotEmpty) {
        // Kasa/Banka işlemlerini bu ref üzerinden siliyoruz
        await KasalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
          intRef!,
          haricKasaIslemId: -1,
          silinecekCariyiEtkilesin: false, // KRITIK FIX
        );
        await BankalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
          intRef,
          haricBankaIslemId: -1,
          silinecekCariyiEtkilesin: false, // KRITIK FIX
        );
      }

      // 3. Cari Entegrasyonu Geri Al
      // Ciro veya herhangi bir entegre cari hareket varsa sil
      final cariServis = CariHesaplarVeritabaniServisi();
      if ((intRef ?? '').isNotEmpty) {
        await cariServis.cariIslemSilByRef(intRef!, session: session);
      } else {
        final searchCariTx = await session.execute(
          Sql.named('''
            SELECT current_account_id FROM current_account_transactions 
            WHERE source_id = @islemId AND (source_type = 'Çek Ciro' OR source_type = 'Para Verildi (Çek Ciro)' OR source_type = 'Çek Verildi (Ciro Edildi)')
          '''),
          parameters: {'islemId': islemId},
        );
        if (searchCariTx.isNotEmpty) {
          final int rCariId = searchCariTx.first[0] as int;
          await cariServis.cariIslemSil(
            rCariId,
            tutar,
            true, // isBorc: biz ciro yaparken borçlandırmıştık
            kaynakTur: 'Çek',
            kaynakId: islemId,
            session: session,
          );
        }
      }

      // 4. Çek Durumunu Geri Al
      // Eğer bu ilk giriş işlemi (Çek Alındı/Verildi) değilse 'Portföyde' durumuna döndürürüz.
      if (type != 'Çek Alındı' && type != 'Çek Verildi') {
        await session.execute(
          Sql.named(
            "UPDATE cheques SET collection_status = 'Portföyde', is_active = 1 WHERE id = @id",
          ),
          parameters: {'id': cekId},
        );
        await _updateChequeSearchTags(cekId, session);

        // [ENTEGRASYON] Cari Hesap Islem Turunu Geri Al
        final checkRes = await session.execute(
          Sql.named(
            "SELECT type, integration_ref, customer_name, check_no FROM cheques WHERE id = @id",
          ),
          parameters: {'id': cekId},
        );
        if (checkRes.isNotEmpty) {
          final row = checkRes.first.toColumnMap();
          final String? cRef = row['integration_ref'] as String?;
          final String cTur = row['type'] as String? ?? '';
          final String cariAdi = row['customer_name']?.toString() ?? '';
          final String cekNo = row['check_no']?.toString() ?? '';
          final String eskiIslemTuru = cTur == 'Alınan Çek'
              ? 'Çek Alındı'
              : 'Çek Verildi';
          final String sourceName = '$cariAdi\nÇek $cekNo';

          if (cRef != null && cRef.isNotEmpty) {
            await session.execute(
              Sql.named('''
                    UPDATE current_account_transactions 
                    SET source_type = @eskiIslemTuru,
                        source_name = @sourceName
                    WHERE integration_ref = @ref
                '''),
              parameters: {
                'eskiIslemTuru': eskiIslemTuru,
                'sourceName': sourceName,
                'ref': cRef,
              },
            );
          } else {
            // Eski çekler için: source_id ile bul
            await session.execute(
              Sql.named('''
                    UPDATE current_account_transactions 
                    SET source_type = @eskiIslemTuru,
                        source_name = @sourceName
                    WHERE source_id = @cekId AND source_type = 'Çek Alındı (Ciro Edildi)'
                '''),
              parameters: {
                'eskiIslemTuru': eskiIslemTuru,
                'sourceName': sourceName,
                'cekId': cekId,
              },
            );
          }
        }
      }

      // 5. İşlemi Sil
      await session.execute(
        Sql.named("DELETE FROM cheque_transactions WHERE id = @id"),
        parameters: {'id': islemId},
      );
    });
  }

  /// Çek işlemini günceller ve mali etkileri yansıtır
  Future<void> cekIsleminiGuncelle({
    required int islemId,
    required double tutar,
    required String aciklama,
    required DateTime tarih,
    required String kullanici,
  }) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isCheckPromissoryActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde çek işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // 1. İşlemi bul
      final txRes = await session.execute(
        Sql.named(
          "SELECT * FROM cheque_transactions WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
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
            WHERE source_id = @islemId AND (source_type = 'Çek Ciro' OR source_type = 'Para Verildi (Çek Ciro)' OR source_type = 'Çek Verildi (Ciro Edildi)')
          '''),
          parameters: {'islemId': islemId},
        );
        if (searchCariTx.isNotEmpty) {
          final int rCariId = searchCariTx.first[0] as int;
          final double oldAmount =
              double.tryParse(searchCariTx.first[1]?.toString() ?? '') ?? 0.0;

          // Önce eskiyi sil (Bakiyeyi geri alır)
          await cariServis.cariIslemSil(
            rCariId,
            oldAmount,
            true, // isBorc: biz ciro yaparken borçlandırmıştık
            kaynakTur: 'Çek',
            kaynakId: islemId,
            session: session,
          );

          // Sonra yeniyi ekle (Yeni bakiyeyi uygular)
          await cariServis.cariIslemEkle(
            cariId: rCariId,
            tutar: tutar,
            isBorc: true,
            islemTuru: 'Çek Verildi (Ciro Edildi)',
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
          UPDATE cheque_transactions 
          SET amount = @amount, description = @description, date = @date, search_tags = @search_tags
          WHERE id = @id
        '''),
        parameters: {
          'amount': tutar,
          'description': aciklama,
          'date': tarih,
          'search_tags': _buildChequeTransactionSearchTags(
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

  /// Çek Karşılıksız Çıktı İşlemi
  /// Tahsil edilmiş bir çek karşılıksız çıkarsa:
  /// 1. Çek durumunu "Karşılıksız" olarak günceller
  /// 2. Daha önce yapılmış kasa/banka girişini tersine çevirir (para çıkışı)
  /// 3. Cari hesaba tekrar borç yazar (müşteri tekrar borçlanır)
  /// 4. Çeki tekrar aktif yapar (takip için)
  Future<void> cekKarsiliksiziCikti({
    required int cekId,
    required String aciklama,
    required DateTime tarih,
    required String kullanici,
  }) async {
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isCheckPromissoryActive) {
      throw const LiteLimitHatasi(
        'LITE sürümde çek işlemleri kapalıdır. Pro sürüme geçin.',
      );
    }
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // 1. Çek Verisini Al
      final checkRes = await session.execute(
        Sql.named(
          "SELECT * FROM cheques WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId",
        ),
        parameters: {'id': cekId, 'companyId': _companyId},
      );
      if (checkRes.isEmpty) return;

      final checkRow = checkRes.first.toColumnMap();
      final double tutar =
          double.tryParse(checkRow['amount']?.toString() ?? '') ?? 0.0;
      final String tur = checkRow['type'] as String? ?? '';

      final String cariKod = checkRow['customer_code'] as String? ?? '';
      final String cariAd = checkRow['customer_name'] as String? ?? '';
      final String mevcutDurum = checkRow['collection_status'] as String? ?? '';

      // Sadece "Tahsil Edildi" veya "Ödendi" durumundaki çekler karşılıksız çıkabilir
      if (mevcutDurum != 'Tahsil Edildi' && mevcutDurum != 'Ödendi') {
        debugPrint(
          '⚠️ Çek karşılıksız işlemi yapılamaz. Mevcut durum: $mevcutDurum',
        );
        return;
      }

      // 2. Orijinal tahsilat işlemini bul (entegrasyon ref ile)
      final txRes = await session.execute(
        Sql.named('''
          SELECT * FROM cheque_transactions 
          WHERE cheque_id = @cekId 
            AND type IN ('Çek Tahsil', 'Çek Ödendi', 'Giriş', 'Çıkış')
            AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
          ORDER BY created_at DESC 
          LIMIT 1
        '''),
        parameters: {'cekId': cekId, 'companyId': _companyId},
      );

      String? originalIntRef;
      if (txRes.isNotEmpty) {
        final txRow = txRes.first.toColumnMap();
        originalIntRef = txRow['integration_ref'] as String?;
      }

      // 3. Çek durumunu "Karşılıksız" olarak güncelle ve aktif yap
      await session.execute(
        Sql.named('''
          UPDATE cheques 
          SET collection_status = 'Karşılıksız', is_active = 1 
          WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
        '''),
        parameters: {'id': cekId, 'companyId': _companyId},
      );
      await _updateChequeSearchTags(cekId, session);

      final String intRef =
          'cheque_bounce_${cekId}_${DateTime.now().millisecondsSinceEpoch}';
      final String detayAciklama = aciklama;

      // 4. Karşılıksız işlem kaydı ekle
      await session.execute(
        Sql.named('''
          INSERT INTO cheque_transactions 
          (company_id, cheque_id, date, description, amount, type, source_dest, user_name, search_tags, integration_ref)
          VALUES 
          (@companyId, @cheque_id, @date, @description, @amount, @type, @source_dest, @user_name, @search_tags, @integration_ref)
        '''),
        parameters: {
          'companyId': _companyId,
          'cheque_id': cekId,
          'date': tarih,
          'description': detayAciklama,
          'amount': tutar,
          'type': 'Karşılıksız',
          'source_dest': 'Cari Hesap: $cariAd',
          'user_name': kullanici,
          'search_tags': _buildChequeTransactionSearchTags(
            date: tarih,
            description: 'Karşılıksız $detayAciklama $cariAd',
            amount: tutar,
            type: 'Karşılıksız',
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
      if (tur == 'Alınan Çek' && cariKod.isNotEmpty) {
        final cariServis = CariHesaplarVeritabaniServisi();
        final int? cariId = await cariServis.cariIdGetir(
          cariKod,
          session: session,
        );

        if (cariId != null) {
          // Önce eski alacak kaydını ref üzerinden silmeye çalış
          bool deleted = false;
          final String? oldIntRef = checkRow['integration_ref'] as String?;
          if (oldIntRef != null && oldIntRef.isNotEmpty) {
            await cariServis.cariIslemSilByRef(oldIntRef, session: session);
            deleted = true;
          }

          if (!deleted) {
            await cariServis.cariIslemSil(
              cariId,
              tutar,
              false, // isBorc: false (alacak idi, şimdi siliyoruz)
              kaynakTur: 'Çek',
              kaynakId: cekId,
              session: session,
            );
          }
        }
      }
    });
  }

  /// Çekin zaten tahsil edilmiş veya ciro edilmiş olup olmadığını kontrol eder
  Future<bool> cekIslemYapilmisMi(int cekId) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return false;

    final result = await _pool!.execute(
      Sql.named('''
        SELECT collection_status FROM cheques 
        WHERE id = @id AND COALESCE(company_id, '$_defaultCompanyId') = @companyId
      '''),
      parameters: {'id': cekId, 'companyId': _companyId},
    );

    if (result.isEmpty) return false;

    final status = result.first[0] as String? ?? '';
    return status == 'Tahsil Edildi' ||
        status == 'Ödendi' ||
        status == 'Ciro Edildi' ||
        status == 'Karşılıksız';
  }
}
