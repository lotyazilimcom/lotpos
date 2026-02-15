import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sayfalar/giderler/modeller/gider_model.dart';
import 'oturum_servisi.dart';
import 'veritabani_yapilandirma.dart';
import 'lisans_yazma_koruma.dart';

class GiderlerVeritabaniServisi {
  static final GiderlerVeritabaniServisi _instance =
      GiderlerVeritabaniServisi._internal();
  factory GiderlerVeritabaniServisi() => _instance;
  GiderlerVeritabaniServisi._internal();

  Pool? _pool;
  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  final VeritabaniYapilandirma _config = VeritabaniYapilandirma();

  Future<void> baslat() async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();

    try {
      _pool = await _poolOlustur();
    } catch (e) {
      final isConnectionLimitError =
          e.toString().contains('53300') ||
          (e is ServerException && e.code == '53300');

      if (isConnectionLimitError) {
        debugPrint(
          'Giderler: Bağlantı limiti aşıldı (53300). Mevcut bağlantılar temizleniyor...',
        );
        await _acikBaglantilariKapat();
        try {
          _pool = await _poolOlustur();
        } catch (e2) {
          debugPrint('Giderler: Temizleme sonrası bağlantı hatası: $e2');
        }
      } else {
        debugPrint('Giderler: Bağlantı hatası: $e');
      }
    }

    try {
      if (_pool != null) {
        await _tablolariOlustur();
        _isInitialized = true;
        _initCompleter!.complete();
        debugPrint(
          'Giderler veritabanı bağlantısı başarılı (Havuz): ${OturumServisi().aktifVeritabaniAdi}',
        );
      } else {
        throw Exception('Giderler: Veritabanı havuzu oluşturulamadı.');
      }
    } catch (e) {
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.completeError(e);
        _initCompleter = null;
      }
      rethrow;
    }
  }

  Future<void> baglantiyiKapat() async {
    if (_pool != null) {
      await _pool!.close();
    }
    _pool = null;
    _isInitialized = false;
    _initCompleter = null;
  }

  Future<Pool> _poolOlustur() async {
    return LisansKorumaliPool(
      Pool.withEndpoints(
        [
          Endpoint(
            host: _config.host,
            port: _config.port,
            database: OturumServisi().aktifVeritabaniAdi,
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
              host: _config.host,
              port: _config.port,
              database: 'postgres',
              username: user,
              password: sifre,
            ),
            settings: ConnectionSettings(sslMode: _config.sslMode),
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
        final username = _config.username;
        await adminConn.execute(
          "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = '$username' AND pid <> pg_backend_pid()",
        );
      } catch (e) {
        debugPrint('Giderler: Bağlantı sonlandırma hatası: $e');
      } finally {
        await adminConn.close();
      }
    }
  }

  Future<void> _tablolariOlustur() async {
    if (_pool == null) return;

    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id SERIAL PRIMARY KEY,
        kod TEXT NOT NULL,
        baslik TEXT NOT NULL,
        tutar NUMERIC DEFAULT 0,
        para_birimi TEXT DEFAULT 'TRY',
        tarih TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        odeme_durumu TEXT DEFAULT 'Beklemede',
        kategori TEXT DEFAULT '',
        aciklama TEXT DEFAULT '',
        not_metni TEXT DEFAULT '',
        resimler JSONB DEFAULT '[]',
        ai_islenmis_mi BOOLEAN DEFAULT false,
        ai_verileri JSONB,
        aktif_mi INTEGER DEFAULT 1,
        search_tags TEXT,
        kullanici TEXT DEFAULT '',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS expense_items (
        id SERIAL PRIMARY KEY,
        expense_id INTEGER NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
        aciklama TEXT DEFAULT '',
        tutar NUMERIC DEFAULT 0,
        not_metni TEXT DEFAULT '',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Migration safety
    try {
      await _pool!.execute(
        'ALTER TABLE expenses RENAME COLUMN "not" TO not_metni',
      );
    } catch (_) {}
    try {
      await _pool!.execute(
        'ALTER TABLE expense_items RENAME COLUMN "not" TO not_metni',
      );
    } catch (_) {}

    final alterQueries = [
      "ALTER TABLE expenses ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP",
      "ALTER TABLE expenses ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP",
      "ALTER TABLE expenses ADD COLUMN IF NOT EXISTS search_tags TEXT",
      "ALTER TABLE expenses ADD COLUMN IF NOT EXISTS kullanici TEXT DEFAULT ''",
      "ALTER TABLE expenses ADD COLUMN IF NOT EXISTS not_metni TEXT DEFAULT ''",
      "ALTER TABLE expense_items ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP",
      "ALTER TABLE expense_items ADD COLUMN IF NOT EXISTS not_metni TEXT DEFAULT ''",
    ];
    for (final q in alterQueries) {
      try {
        await _pool!.execute(q);
      } catch (_) {}
    }

    // Indexes
    try {
      await _pool!.execute('CREATE EXTENSION IF NOT EXISTS pg_trgm');

      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_search_tags_gin ON expenses USING GIN (search_tags gin_trgm_ops)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_kod_trgm ON expenses USING GIN (kod gin_trgm_ops)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_baslik_trgm ON expenses USING GIN (baslik gin_trgm_ops)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_kategori_btree ON expenses (kategori)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_odeme_durumu_btree ON expenses (odeme_durumu)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_aktif_btree ON expenses (aktif_mi)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_tarih_brin ON expenses USING BRIN (tarih) WITH (pages_per_range = 64)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_kullanici_btree ON expenses (kullanici)',
      );
      await _pool!.execute(
        'CREATE INDEX IF NOT EXISTS idx_expense_items_expense_id ON expense_items (expense_id)',
      );
    } catch (e) {
      debugPrint('Giderler: indeks uyarısı: $e');
    }
  }

  Future<String> _getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('current_username') ?? 'Sistem';
    return user.trim().isNotEmpty ? user : 'Sistem';
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static bool _toBool(dynamic value, {bool defaultValue = true}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final s = value.toLowerCase();
      if (s == '1' || s == 'true') return true;
      if (s == '0' || s == 'false') return false;
    }
    return defaultValue;
  }

  static dynamic _decodeJsonb(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map || raw is List) return raw;
    if (raw is String) {
      try {
        return jsonDecode(raw);
      } catch (_) {
        return null;
      }
    }
    if (raw is List) {
      if (raw.isNotEmpty && raw.first is int) {
        try {
          final decodedStr = utf8.decode(raw.cast<int>());
          return jsonDecode(decodedStr);
        } catch (_) {
          return null;
        }
      }
      return raw;
    }
    try {
      final bytes = (raw as dynamic).bytes;
      if (bytes is List<int>) {
        final decodedStr = utf8.decode(bytes);
        return jsonDecode(decodedStr);
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  static Map<String, dynamic>? _asJsonMap(dynamic raw) {
    final decoded = _decodeJsonb(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static List<String> _asStringList(dynamic raw) {
    final decoded = _decodeJsonb(raw);
    if (decoded is List) {
      return decoded
          .where((e) => e != null)
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty && s != 'null')
          .toList();
    }
    return [];
  }

  static Object? _jsonSafeValue(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is num || value is String || value is bool) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _jsonSafeValue(v)));
    }
    if (value is List) {
      return value.map(_jsonSafeValue).toList();
    }
    return value.toString();
  }

  static String _buildSearchTags({
    required String kod,
    required String baslik,
    required String kategori,
    required String aciklama,
    required String not,
    required String paraBirimi,
    required String odemeDurumu,
    required String kullanici,
    required double tutar,
    required DateTime tarih,
    required List<GiderKalemi> kalemler,
    required bool aktifMi,
  }) {
    final parts = <String>[
      kod,
      baslik,
      kategori,
      aciklama,
      not,
      paraBirimi,
      odemeDurumu,
      kullanici,
      tutar.toString(),
      tarih.toIso8601String(),
      DateTime(tarih.year, tarih.month, tarih.day).toIso8601String(),
      aktifMi ? 'aktif' : 'pasif',
      for (final k in kalemler) ...[k.aciklama, k.not, k.tutar.toString()],
    ];

    return parts
        .where((e) => e.trim().isNotEmpty)
        .join(' ')
        .toLowerCase()
        .trim();
  }

  Future<int> giderEkle(GiderModel gider, {String? createdBy}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;

    final currentUser =
        createdBy ??
        (gider.kullanici.trim().isNotEmpty
            ? gider.kullanici.trim()
            : await _getCurrentUser());

    final double toplamTutar = gider.kalemler.isNotEmpty
        ? gider.kalemler.fold(0.0, (sum, k) => sum + k.tutar)
        : gider.tutar;

    final aiSafe = gider.aiVerileri != null
        ? _jsonSafeValue(gider.aiVerileri!)
        : null;
    final aiJson = aiSafe != null ? jsonEncode(aiSafe) : null;

    final resimlerJson = jsonEncode(gider.resimler);

    final searchTags = _buildSearchTags(
      kod: gider.kod,
      baslik: gider.baslik,
      kategori: gider.kategori,
      aciklama: gider.aciklama,
      not: gider.not,
      paraBirimi: gider.paraBirimi,
      odemeDurumu: gider.odemeDurumu,
      kullanici: currentUser,
      tutar: toplamTutar,
      tarih: gider.tarih,
      kalemler: gider.kalemler,
      aktifMi: gider.aktifMi,
    );

    return await _pool!.runTx((ctx) async {
      final insertRes = await ctx.execute(
        Sql.named('''
          INSERT INTO expenses (
            kod, baslik, tutar, para_birimi, tarih, odeme_durumu,
            kategori, aciklama, not_metni, resimler, ai_islenmis_mi, ai_verileri,
            aktif_mi, search_tags, kullanici, created_at, updated_at
          )
          VALUES (
            @kod, @baslik, @tutar, @para_birimi, @tarih, @odeme_durumu,
            @kategori, @aciklama, @not_metni, @resimler, @ai_islenmis_mi, @ai_verileri,
            @aktif_mi, @search_tags, @kullanici, @created_at, @updated_at
          )
          RETURNING id
        '''),
        parameters: {
          'kod': gider.kod,
          'baslik': gider.baslik,
          'tutar': toplamTutar,
          'para_birimi': gider.paraBirimi,
          'tarih': gider.tarih,
          'odeme_durumu': gider.odemeDurumu,
          'kategori': gider.kategori,
          'aciklama': gider.aciklama,
          'not_metni': gider.not,
          'resimler': resimlerJson,
          'ai_islenmis_mi': gider.aiIslenmisMi,
          'ai_verileri': aiJson,
          'aktif_mi': gider.aktifMi ? 1 : 0,
          'search_tags': searchTags,
          'kullanici': currentUser,
          'created_at': gider.olusturmaTarihi,
          'updated_at': gider.guncellemeTarihi ?? DateTime.now(),
        },
      );

      final int giderId = insertRes.first[0] as int;

      if (gider.kalemler.isNotEmpty) {
        for (final kalem in gider.kalemler) {
          await ctx.execute(
            Sql.named('''
              INSERT INTO expense_items (expense_id, aciklama, tutar, not_metni, created_at)
              VALUES (@expense_id, @aciklama, @tutar, @not_metni, @created_at)
            '''),
            parameters: {
              'expense_id': giderId,
              'aciklama': kalem.aciklama,
              'tutar': kalem.tutar,
              'not_metni': kalem.not,
              'created_at': DateTime.now(),
            },
          );
        }
      }

      return giderId;
    });
  }

  Future<void> giderGuncelle(GiderModel gider, {String? updatedBy}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final currentUser =
        updatedBy ??
        (gider.kullanici.trim().isNotEmpty
            ? gider.kullanici.trim()
            : await _getCurrentUser());

    final double toplamTutar = gider.kalemler.isNotEmpty
        ? gider.kalemler.fold(0.0, (sum, k) => sum + k.tutar)
        : gider.tutar;

    final aiSafe = gider.aiVerileri != null
        ? _jsonSafeValue(gider.aiVerileri!)
        : null;
    final aiJson = aiSafe != null ? jsonEncode(aiSafe) : null;
    final resimlerJson = jsonEncode(gider.resimler);

    final searchTags = _buildSearchTags(
      kod: gider.kod,
      baslik: gider.baslik,
      kategori: gider.kategori,
      aciklama: gider.aciklama,
      not: gider.not,
      paraBirimi: gider.paraBirimi,
      odemeDurumu: gider.odemeDurumu,
      kullanici: currentUser,
      tutar: toplamTutar,
      tarih: gider.tarih,
      kalemler: gider.kalemler,
      aktifMi: gider.aktifMi,
    );

    await _pool!.runTx((ctx) async {
      await ctx.execute(
        Sql.named('''
          UPDATE expenses SET
            kod = @kod,
            baslik = @baslik,
            tutar = @tutar,
            para_birimi = @para_birimi,
            tarih = @tarih,
          odeme_durumu = @odeme_durumu,
          kategori = @kategori,
          aciklama = @aciklama,
            not_metni = @not_metni,
          resimler = @resimler,
          ai_islenmis_mi = @ai_islenmis_mi,
          ai_verileri = @ai_verileri,
          aktif_mi = @aktif_mi,
            search_tags = @search_tags,
            kullanici = @kullanici,
            updated_at = @updated_at
          WHERE id = @id
        '''),
        parameters: {
          'id': gider.id,
          'kod': gider.kod,
          'baslik': gider.baslik,
          'tutar': toplamTutar,
          'para_birimi': gider.paraBirimi,
          'tarih': gider.tarih,
          'odeme_durumu': gider.odemeDurumu,
          'kategori': gider.kategori,
          'aciklama': gider.aciklama,
          'not_metni': gider.not,
          'resimler': resimlerJson,
          'ai_islenmis_mi': gider.aiIslenmisMi,
          'ai_verileri': aiJson,
          'aktif_mi': gider.aktifMi ? 1 : 0,
          'search_tags': searchTags,
          'kullanici': currentUser,
          'updated_at': DateTime.now(),
        },
      );

      // Items: simplest is rewrite for correctness.
      await ctx.execute(
        Sql.named('DELETE FROM expense_items WHERE expense_id = @id'),
        parameters: {'id': gider.id},
      );

      for (final kalem in gider.kalemler) {
        await ctx.execute(
          Sql.named('''
            INSERT INTO expense_items (expense_id, aciklama, tutar, not_metni, created_at)
            VALUES (@expense_id, @aciklama, @tutar, @not_metni, @created_at)
          '''),
          parameters: {
            'expense_id': gider.id,
            'aciklama': kalem.aciklama,
            'tutar': kalem.tutar,
            'not_metni': kalem.not,
            'created_at': DateTime.now(),
          },
        );
      }
    });
  }

  Future<void> giderSil(int id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('DELETE FROM expenses WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  Future<void> giderDurumGuncelle({
    required int id,
    required bool aktifMi,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named(
        'UPDATE expenses SET aktif_mi = @aktif_mi, updated_at = CURRENT_TIMESTAMP WHERE id = @id',
      ),
      parameters: {'id': id, 'aktif_mi': aktifMi ? 1 : 0},
    );
  }

  Future<void> giderOdemeDurumuGuncelle({
    required int id,
    required String odemeDurumu,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named(
        'UPDATE expenses SET odeme_durumu = @odeme_durumu, updated_at = CURRENT_TIMESTAMP WHERE id = @id',
      ),
      parameters: {'id': id, 'odeme_durumu': odemeDurumu},
    );
  }

  Future<void> giderKalemiEkle({
    required int giderId,
    required GiderKalemi kalem,
    String? yeniAciklama,
    String? paraBirimi,
    String? updatedBy,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final currentUser = updatedBy ?? await _getCurrentUser();

    await _pool!.runTx((ctx) async {
      await ctx.execute(
        Sql.named('''
          INSERT INTO expense_items (expense_id, aciklama, tutar, not_metni, created_at)
          VALUES (@expense_id, @aciklama, @tutar, @not_metni, @created_at)
        '''),
        parameters: {
          'expense_id': giderId,
          'aciklama': kalem.aciklama,
          'tutar': kalem.tutar,
          'not_metni': kalem.not,
          'created_at': DateTime.now(),
        },
      );

      // Total + tags update (single shot)
      final tagsAppend = [
        kalem.aciklama,
        kalem.not,
        kalem.tutar.toString(),
      ].where((e) => e.trim().isNotEmpty).join(' ').toLowerCase();

      await ctx.execute(
        Sql.named('''
          UPDATE expenses e
          SET 
            tutar = COALESCE((SELECT SUM(tutar) FROM expense_items WHERE expense_id = e.id), 0),
            para_birimi = COALESCE(NULLIF(@para_birimi, ''), e.para_birimi),
            aciklama = COALESCE(@aciklama, e.aciklama),
            search_tags = LOWER(TRIM(COALESCE(e.search_tags, '') || ' ' || @append_tags)),
            kullanici = COALESCE(NULLIF(@kullanici, ''), e.kullanici),
            updated_at = CURRENT_TIMESTAMP
          WHERE e.id = @id
        '''),
        parameters: {
          'id': giderId,
          'append_tags': tagsAppend,
          'aciklama': yeniAciklama,
          'para_birimi': paraBirimi,
          'kullanici': currentUser,
        },
      );
    });
  }

  Future<GiderModel?> giderGetir(int id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    final res = await _pool!.execute(
      Sql.named('SELECT * FROM expenses WHERE id = @id LIMIT 1'),
      parameters: {'id': id},
    );
    if (res.isEmpty) return null;

    final giderMap = res.first.toColumnMap();
    final kalemler = await giderKalemleriniGetir(id);
    return _giderFromMap(giderMap, kalemler: kalemler);
  }

  Future<List<GiderKalemi>> giderKalemleriniGetir(int giderId) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    final res = await _pool!.execute(
      Sql.named(
        'SELECT aciklama, tutar, not_metni FROM expense_items WHERE expense_id = @id ORDER BY id ASC',
      ),
      parameters: {'id': giderId},
    );

    return res.map((row) {
      final m = row.toColumnMap();
      return GiderKalemi(
        aciklama: (m['aciklama'] as String?) ?? '',
        tutar: _toDouble(m['tutar']),
        not: (m['not_metni'] as String?) ?? '',
      );
    }).toList();
  }

  Future<List<GiderModel>> giderleriGetir({
    int sayfa = 1,
    int sayfaBasinaKayit = 25,
    String? aramaTerimi,
    String? sortBy,
    bool sortAscending = true,
    bool? aktifMi,
    String? odemeDurumu,
    String? kategori,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? kullanici,
    int? lastId,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    String sortColumn = 'id';
    switch (sortBy) {
      case 'kod':
        sortColumn = 'kod';
        break;
      case 'baslik':
        sortColumn = 'baslik';
        break;
      case 'tutar':
        sortColumn = 'tutar';
        break;
      case 'kategori':
        sortColumn = 'kategori';
        break;
      case 'tarih':
        sortColumn = 'tarih';
        break;
      case 'aktif_mi':
        sortColumn = 'aktif_mi';
        break;
      case 'aciklama':
        sortColumn = 'aciklama';
        break;
      default:
        sortColumn = 'id';
    }

    final String direction = sortAscending ? 'ASC' : 'DESC';
    final String idDirection = sortAscending ? 'ASC' : 'DESC';

    final whereConditions = <String>[];
    final params = <String, dynamic>{};

    if (aramaTerimi != null && aramaTerimi.trim().isNotEmpty) {
      whereConditions.add('search_tags ILIKE @search');
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
    }

    if (aktifMi != null) {
      whereConditions.add('aktif_mi = @aktifMi');
      params['aktifMi'] = aktifMi ? 1 : 0;
    }

    if (odemeDurumu != null && odemeDurumu.trim().isNotEmpty) {
      whereConditions.add('odeme_durumu = @odemeDurumu');
      params['odemeDurumu'] = odemeDurumu;
    }

    if (kategori != null && kategori.trim().isNotEmpty) {
      whereConditions.add('kategori = @kategori');
      params['kategori'] = kategori;
    }

    if (kullanici != null && kullanici.trim().isNotEmpty) {
      whereConditions.add('kullanici = @kullanici');
      params['kullanici'] = kullanici;
    }

    if (baslangicTarihi != null) {
      whereConditions.add('tarih >= @startDate');
      params['startDate'] = baslangicTarihi;
    }

    if (bitisTarihi != null) {
      whereConditions.add('tarih <= @endDate');
      params['endDate'] = bitisTarihi.add(const Duration(days: 1));
    }

    bool useKeyset = false;
    dynamic lastSortValue;
    if (lastId != null && lastId > 0) {
      if (sortColumn == 'id') {
        lastSortValue = lastId;
        useKeyset = true;
      } else {
        try {
          final cursor = await _pool!.execute(
            Sql.named('SELECT $sortColumn FROM expenses WHERE id = @id'),
            parameters: {'id': lastId},
          );
          if (cursor.isNotEmpty) {
            lastSortValue = cursor.first[0];
            useKeyset = lastSortValue != null;
          }
        } catch (_) {
          useKeyset = false;
        }
      }
    }

    if (useKeyset) {
      params['lastId'] = lastId;
      params['lastSort'] = lastSortValue;

      final op = sortAscending ? '>' : '<';
      whereConditions.add(
        '($sortColumn $op @lastSort OR ($sortColumn = @lastSort AND id $op @lastId))',
      );
    }

    final String whereClause = whereConditions.isNotEmpty
        ? 'WHERE ${whereConditions.join(' AND ')}'
        : '';

    final int offset = (sayfa - 1) * sayfaBasinaKayit;
    final limitClause = useKeyset
        ? 'LIMIT @limit'
        : 'LIMIT @limit OFFSET @offset';

    params['limit'] = sayfaBasinaKayit;
    if (!useKeyset) {
      params['offset'] = offset;
    }

    String selectClause = 'SELECT expenses.*';
    final String? trimmedQ = aramaTerimi?.trim();
    if (trimmedQ != null && trimmedQ.isNotEmpty) {
      selectClause += '''
        , (CASE 
            WHEN search_tags ILIKE @search
              AND NOT (
                kod ILIKE @search OR
                baslik ILIKE @search OR
                COALESCE(kategori, '') ILIKE @search OR
                COALESCE(aciklama, '') ILIKE @search OR
                COALESCE(odeme_durumu, '') ILIKE @search OR
                COALESCE(para_birimi, '') ILIKE @search
              )
            THEN true
            ELSE false
          END) as matched_in_hidden
      ''';
    } else {
      selectClause += ', false as matched_in_hidden';
    }

    final query =
        '''
      $selectClause
      FROM expenses
      $whereClause
      ORDER BY $sortColumn $direction, id $idDirection
      $limitClause
    ''';

    final result = await _pool!.execute(Sql.named(query), parameters: params);

    if (result.isEmpty) return [];

    final giderMaps = result.map((r) => r.toColumnMap()).toList();
    final ids = giderMaps.map((m) => m['id'] as int).toList();

    final kalemlerMap = await _kalemleriTopluGetir(ids);

    return giderMaps
        .map((m) => _giderFromMap(m, kalemler: kalemlerMap[m['id'] as int]))
        .toList();
  }

  Future<List<GiderModel>> giderleriGetirByIds(List<int> ids) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];
    if (ids.isEmpty) return [];

    final result = await _pool!.execute(
      Sql.named('''
        SELECT expenses.*, false as matched_in_hidden
        FROM expenses
        WHERE id = ANY(@ids)
        ORDER BY id ASC
      '''),
      parameters: {'ids': ids},
    );

    if (result.isEmpty) return [];

    final giderMaps = result.map((r) => r.toColumnMap()).toList();
    final fetchedIds = giderMaps.map((m) => m['id'] as int).toList();
    final kalemlerMap = await _kalemleriTopluGetir(fetchedIds);

    final byId = <int, GiderModel>{
      for (final m in giderMaps)
        m['id'] as int: _giderFromMap(
          m,
          kalemler: kalemlerMap[m['id'] as int],
        ),
    };

    return ids.where(byId.containsKey).map((id) => byId[id]!).toList();
  }

  Future<Map<int, List<GiderKalemi>>> _kalemleriTopluGetir(
    List<int> giderIds,
  ) async {
    if (giderIds.isEmpty) return {};
    if (_pool == null) return {};

    final res = await _pool!.execute(
      Sql.named('''
        SELECT expense_id, aciklama, tutar, not_metni
        FROM expense_items
        WHERE expense_id = ANY(@ids)
        ORDER BY expense_id ASC, id ASC
      '''),
      parameters: {'ids': giderIds},
    );

    final Map<int, List<GiderKalemi>> map = {};
    for (final row in res) {
      final m = row.toColumnMap();
      final int expenseId = m['expense_id'] as int;
      map.putIfAbsent(expenseId, () => []);
      map[expenseId]!.add(
        GiderKalemi(
          aciklama: (m['aciklama'] as String?) ?? '',
          tutar: _toDouble(m['tutar']),
          not: (m['not_metni'] as String?) ?? '',
        ),
      );
    }
    return map;
  }

  GiderModel _giderFromMap(
    Map<String, dynamic> map, {
    List<GiderKalemi>? kalemler,
  }) {
    return GiderModel(
      id: map['id'] as int,
      kod: (map['kod'] as String?) ?? '',
      baslik: (map['baslik'] as String?) ?? '',
      tutar: _toDouble(map['tutar']),
      paraBirimi: (map['para_birimi'] as String?) ?? 'TRY',
      tarih: map['tarih'] is DateTime
          ? (map['tarih'] as DateTime)
          : DateTime.tryParse(map['tarih']?.toString() ?? '') ?? DateTime.now(),
      odemeDurumu: (map['odeme_durumu'] as String?) ?? 'Beklemede',
      kategori: (map['kategori'] as String?) ?? '',
      aciklama: (map['aciklama'] as String?) ?? '',
      not: (map['not_metni'] as String?) ?? '',
      resimler: _asStringList(map['resimler']),
      kalemler: kalemler ?? [],
      aiIslenmisMi: _toBool(map['ai_islenmis_mi'], defaultValue: false),
      aiVerileri: _asJsonMap(map['ai_verileri']),
      aktifMi: _toBool(map['aktif_mi'], defaultValue: true),
      olusturmaTarihi: map['created_at'] is DateTime
          ? (map['created_at'] as DateTime)
          : DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                DateTime.now(),
      guncellemeTarihi: map['updated_at'] is DateTime
          ? (map['updated_at'] as DateTime)
          : (map['updated_at'] != null
                ? DateTime.tryParse(map['updated_at'].toString())
                : null),
      kullanici: (map['kullanici'] as String?) ?? '',
      matchedInHidden: map['matched_in_hidden'] == true,
    );
  }

  Future<int> giderSayisiGetir({
    String? aramaTerimi,
    bool? aktifMi,
    String? odemeDurumu,
    String? kategori,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? kullanici,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;

    final whereConditions = <String>[];
    final params = <String, dynamic>{};

    if (aramaTerimi != null && aramaTerimi.trim().isNotEmpty) {
      whereConditions.add('search_tags ILIKE @search');
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
    }

    if (aktifMi != null) {
      whereConditions.add('aktif_mi = @aktifMi');
      params['aktifMi'] = aktifMi ? 1 : 0;
    }

    if (odemeDurumu != null && odemeDurumu.trim().isNotEmpty) {
      whereConditions.add('odeme_durumu = @odemeDurumu');
      params['odemeDurumu'] = odemeDurumu;
    }

    if (kategori != null && kategori.trim().isNotEmpty) {
      whereConditions.add('kategori = @kategori');
      params['kategori'] = kategori;
    }

    if (kullanici != null && kullanici.trim().isNotEmpty) {
      whereConditions.add('kullanici = @kullanici');
      params['kullanici'] = kullanici;
    }

    if (baslangicTarihi != null) {
      whereConditions.add('tarih >= @startDate');
      params['startDate'] = baslangicTarihi;
    }

    if (bitisTarihi != null) {
      whereConditions.add('tarih <= @endDate');
      params['endDate'] = bitisTarihi.add(const Duration(days: 1));
    }

    final whereClause = whereConditions.isNotEmpty
        ? 'WHERE ${whereConditions.join(' AND ')}'
        : '';

    final res = await _pool!.execute(
      Sql.named('SELECT COUNT(*) FROM expenses $whereClause'),
      parameters: params,
    );
    return (res.first[0] as num).toInt();
  }

  Future<Map<String, Map<String, int>>> giderFiltreIstatistikleriniGetir({
    String? aramaTerimi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    bool? aktifMi,
    String? kategori,
    String? odemeDurumu,
    String? kullanici,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return {};

    const int cappedLimit = 100001;

    String buildWhere(List<String> conds) {
      return conds.isEmpty ? '' : 'WHERE ${conds.join(' AND ')}';
    }

    DateTime? endOfDay(DateTime? d) {
      if (d == null) return null;
      return DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
    }

    void addExpenseConds(
      List<String> conds,
      Map<String, dynamic> params, {
      String? q,
      bool? aktif,
      String? cat,
      String? payment,
      String? user,
      DateTime? start,
      DateTime? end,
    }) {
      final String? trimmedQ = q?.trim();
      if (trimmedQ != null && trimmedQ.isNotEmpty) {
        conds.add('search_tags ILIKE @search');
        params['search'] = '%${trimmedQ.toLowerCase()}%';
      }

      if (aktif != null) {
        conds.add('aktif_mi = @aktifMi');
        params['aktifMi'] = aktif ? 1 : 0;
      }

      final String? trimmedCategory = cat?.trim();
      if (trimmedCategory != null && trimmedCategory.isNotEmpty) {
        conds.add('kategori = @kategori');
        params['kategori'] = trimmedCategory;
      }

      final String? trimmedPayment = payment?.trim();
      if (trimmedPayment != null && trimmedPayment.isNotEmpty) {
        conds.add('odeme_durumu = @odemeDurumu');
        params['odemeDurumu'] = trimmedPayment;
      }

      final String? trimmedUser = user?.trim();
      if (trimmedUser != null && trimmedUser.isNotEmpty) {
        conds.add('kullanici = @kullanici');
        params['kullanici'] = trimmedUser;
      }

      if (start != null) {
        conds.add('tarih >= @startDate');
        params['startDate'] = start;
      }
      if (end != null) {
        conds.add('tarih <= @endDate');
        params['endDate'] = endOfDay(end);
      }
    }

    final int genelToplam = await giderSayisiGetir(
      aramaTerimi: aramaTerimi,
      baslangicTarihi: baslangicTarihi,
      bitisTarihi: bitisTarihi,
    );

    // Durum facet (aktif/pasif)
    final statusParams = <String, dynamic>{};
    final statusConds = <String>[];
    addExpenseConds(
      statusConds,
      statusParams,
      q: aramaTerimi,
      aktif: null,
      cat: kategori,
      payment: odemeDurumu,
      user: kullanici,
      start: baslangicTarihi,
      end: bitisTarihi,
    );
    final statusQuery =
        '''
      SELECT aktif_mi, COUNT(*)
      FROM (
        SELECT aktif_mi
        FROM expenses
        ${buildWhere(statusConds)}
        LIMIT $cappedLimit
      ) sub
      GROUP BY aktif_mi
    ''';

    // Kategori facet
    final categoryParams = <String, dynamic>{};
    final categoryConds = <String>[];
    addExpenseConds(
      categoryConds,
      categoryParams,
      q: aramaTerimi,
      aktif: aktifMi,
      cat: null,
      payment: odemeDurumu,
      user: kullanici,
      start: baslangicTarihi,
      end: bitisTarihi,
    );
    final categoryQuery =
        '''
      SELECT kategori, COUNT(*)
      FROM (
        SELECT COALESCE(kategori, '') as kategori
        FROM expenses
        ${buildWhere(categoryConds)}
        LIMIT $cappedLimit
      ) sub
      GROUP BY kategori
    ''';

    // Ödeme durumu facet
    final paymentParams = <String, dynamic>{};
    final paymentConds = <String>[];
    addExpenseConds(
      paymentConds,
      paymentParams,
      q: aramaTerimi,
      aktif: aktifMi,
      cat: kategori,
      payment: null,
      user: kullanici,
      start: baslangicTarihi,
      end: bitisTarihi,
    );
    final paymentQuery =
        '''
      SELECT odeme_durumu, COUNT(*)
      FROM (
        SELECT COALESCE(odeme_durumu, '') as odeme_durumu
        FROM expenses
        ${buildWhere(paymentConds)}
        LIMIT $cappedLimit
      ) sub
      GROUP BY odeme_durumu
    ''';

    // Kullanıcı facet
    final userParams = <String, dynamic>{};
    final userConds = <String>[];
    addExpenseConds(
      userConds,
      userParams,
      q: aramaTerimi,
      aktif: aktifMi,
      cat: kategori,
      payment: odemeDurumu,
      user: null,
      start: baslangicTarihi,
      end: bitisTarihi,
    );
    final userQuery =
        '''
      SELECT kullanici, COUNT(*)
      FROM (
        SELECT COALESCE(kullanici, '') as kullanici
        FROM expenses
        ${buildWhere(userConds)}
        LIMIT $cappedLimit
      ) sub
      GROUP BY kullanici
    ''';

    try {
      final results = await Future.wait([
        _pool!.execute(Sql.named(statusQuery), parameters: statusParams),
        _pool!.execute(Sql.named(categoryQuery), parameters: categoryParams),
        _pool!.execute(Sql.named(paymentQuery), parameters: paymentParams),
        _pool!.execute(Sql.named(userQuery), parameters: userParams),
      ]);

      final statusRows = results[0];
      final categoryRows = results[1];
      final paymentRows = results[2];
      final userRows = results[3];

      final Map<String, int> durumlar = {};
      for (final row in statusRows) {
        final key = (row[0] == 1 || row[0] == true) ? 'active' : 'passive';
        durumlar[key] = (row[1] as num).toInt();
      }

      final Map<String, int> kategoriler = {};
      for (final row in categoryRows) {
        final key = row[0]?.toString() ?? '';
        if (key.trim().isNotEmpty) {
          kategoriler[key] = (row[1] as num).toInt();
        }
      }

      final Map<String, int> odemeDurumlari = {};
      for (final row in paymentRows) {
        final key = row[0]?.toString() ?? '';
        if (key.trim().isNotEmpty) {
          odemeDurumlari[key] = (row[1] as num).toInt();
        }
      }

      final Map<String, int> kullanicilar = {};
      for (final row in userRows) {
        final key = row[0]?.toString() ?? '';
        if (key.trim().isNotEmpty) {
          kullanicilar[key] = (row[1] as num).toInt();
        }
      }

      return {
        'durumlar': durumlar,
        'kategoriler': kategoriler,
        'odeme_durumlari': odemeDurumlari,
        'kullanicilar': kullanicilar,
        'ozet': {'toplam': genelToplam},
      };
    } catch (e) {
      debugPrint('Gider filtre istatistikleri hatası: $e');
      return {
        'ozet': {'toplam': genelToplam},
      };
    }
  }

  Future<List<String>> giderKategorileriniGetir() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    final res = await _pool!.execute(
      "SELECT DISTINCT kategori FROM expenses WHERE kategori IS NOT NULL AND kategori <> '' ORDER BY kategori ASC",
    );
    return res
        .map((r) => (r[0] as String?) ?? '')
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }
}
