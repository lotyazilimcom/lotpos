// ignore_for_file: avoid_print

import 'dart:io';

import 'package:postgres/postgres.dart';

import 'package:patisyov10/servisler/pg_eklentiler.dart';

/// Prod DB'lerde rapor performansı için kritik index kontrol/aracı.
///
/// Amaç:
/// - Büyük tablolarda `search_tags` trigram + FTS GIN indexleri var mı?
/// - Cursor/keyset pagination için eklenen composite indexler var mı?
///
/// Güvenlik:
/// - Yanlışlıkla DDL çalışmasın diye `--apply` için
///   `PATISYO_ALLOW_HEAVY_MAINTENANCE=true` zorunlu.
///
/// ÇALIŞTIRMA (sadece kontrol):
///   PATISYO_PG_HOST=127.0.0.1 \\
///   PATISYO_PG_PORT=5432 \\
///   PATISYO_PG_USER=patisyo \\
///   PATISYO_PG_PASSWORD=... \\
///   dart run tool/prod_check_report_indexes.dart --db=patisyo2025
///
/// ÇALIŞTIRMA (eksikleri kur):
///   PATISYO_ALLOW_HEAVY_MAINTENANCE=true \\
///   ... \\
///   dart run tool/prod_check_report_indexes.dart --db=patisyo2025 --apply
Future<void> main(List<String> args) async {
  final onlyDb = _parseOnlyDbArg(args);
  final apply = args.any((a) => a.trim() == '--apply');
  final explain = args.any((a) => a.trim() == '--explain');
  final q = _parseValueArg(args, '--q');
  final companyId =
      _parseValueArg(args, '--company')?.trim().isNotEmpty == true
          ? _parseValueArg(args, '--company')!.trim()
          : 'patisyo2025';

  if ((apply || explain) &&
      !_isTruthy(Platform.environment['PATISYO_ALLOW_HEAVY_MAINTENANCE'])) {
    print(
      '❌ --apply/--explain için bakım onayı gerekli: env PATISYO_ALLOW_HEAVY_MAINTENANCE=true',
    );
    exitCode = 2;
    return;
  }

  final host = (Platform.environment['PATISYO_PG_HOST'] ??
          Platform.environment['PATISYO_DB_HOST'] ??
          '127.0.0.1')
      .trim();
  final sslMode = _sslModeFromEnv();
  final port = int.tryParse(
        (Platform.environment['PATISYO_PG_PORT'] ??
                Platform.environment['PATISYO_DB_PORT'] ??
                '')
            .trim(),
      ) ??
      5432;
  final username = (Platform.environment['PATISYO_PG_USER'] ??
          Platform.environment['PATISYO_DB_USER'] ??
          'patisyo')
      .trim();
  final password = (Platform.environment['PATISYO_PG_PASSWORD'] ??
          Platform.environment['PATISYO_DB_PASSWORD'] ??
          '')
      .trim();

  const settingsDb = 'patisyosettings';
  const defaultDb = 'patisyo2025';

  final dbNames = <String>{};
  if (onlyDb != null) {
    dbNames.add(onlyDb);
  } else {
    dbNames.add(defaultDb);
    final codes = await _fetchCompanyCodesBestEffort(
      host: host,
      port: port,
      username: username,
      password: password,
      settingsDb: settingsDb,
    );
    for (final code in codes) {
      dbNames.add(_veritabaniAdiHesapla(code));
    }
  }

  print('--- Prod Report Index Check Başlıyor ---');
  print('Host: $host:$port  User: $username  DB count: ${dbNames.length}');
  if (onlyDb != null) print('Sadece DB hedefi: $onlyDb');
  if (apply) print('MODE: APPLY (eksikler kurulacak)');
  if (explain) print('MODE: EXPLAIN (ANALYZE, BUFFERS)');
  if (q != null && q.trim().isNotEmpty) print('EXPLAIN query: "${q.trim()}"');

  for (final db in dbNames) {
      await _checkDb(
        host: host,
        port: port,
        username: username,
        password: password,
        database: db,
        sslMode: sslMode,
        apply: apply,
        explain: explain,
        searchQuery: q,
        companyId: companyId,
      );
  }

  print('--- Prod Report Index Check Bitti ---');
}

Future<void> _checkDb({
  required String host,
  required int port,
  required String username,
  required String password,
  required String database,
  required SslMode sslMode,
  required bool apply,
  required bool explain,
  required String? searchQuery,
  required String companyId,
}) async {
  final db = database.trim();
  if (db.isEmpty) return;

  print('');
  print('=== DB: $db ===');

  Connection? conn;
  try {
    conn = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: db,
        username: username,
        password: password,
      ),
      settings: ConnectionSettings(sslMode: sslMode),
    );

    final hasTrgm = await PgEklentiler.hasExtension(conn, 'pg_trgm');
    print('pg_trgm: ${hasTrgm ? 'OK' : 'YOK'}');

    if (apply) {
      // Bazı prod DB'lerde (özellikle background maintenance kapalıysa)
      // bu kolonlar henüz eklenmemiş olabiliyor. Raporlar artık DB-side
      // search_tags üzerinden aradığı için indexlerden önce garantile.
      await _bestEffortExecute(
        conn,
        "ALTER TABLE current_account_transactions ADD COLUMN IF NOT EXISTS search_tags TEXT NOT NULL DEFAULT ''",
      );
      await _bestEffortExecute(
        conn,
        "ALTER TABLE bank_transactions ADD COLUMN IF NOT EXISTS search_tags TEXT NOT NULL DEFAULT ''",
      );
      await _bestEffortExecute(
        conn,
        "ALTER TABLE cash_register_transactions ADD COLUMN IF NOT EXISTS search_tags TEXT NOT NULL DEFAULT ''",
      );
      await _bestEffortExecute(
        conn,
        "ALTER TABLE credit_card_transactions ADD COLUMN IF NOT EXISTS search_tags TEXT NOT NULL DEFAULT ''",
      );
      await _bestEffortExecute(
        conn,
        "ALTER TABLE stock_movements ADD COLUMN IF NOT EXISTS search_tags TEXT NOT NULL DEFAULT ''",
      );
      await _bestEffortExecute(
        conn,
        "ALTER TABLE shipments ADD COLUMN IF NOT EXISTS search_tags TEXT NOT NULL DEFAULT ''",
      );
    }

    final specs = _indexSpecs();

    var ok = 0;
    final missing = <_IndexSpec>[];
    for (final s in specs) {
      final exists = await PgEklentiler.hasIndex(conn, s.name);
      if (exists) {
        ok++;
      } else {
        missing.add(s);
      }
    }

    print('Index: OK=$ok MISS=${missing.length} TOTAL=${specs.length}');
    if (missing.isNotEmpty) {
      print('Eksikler:');
      for (final m in missing) {
        print('  - ${m.name}');
      }
    }

    if (apply && missing.isNotEmpty) {
      print('');
      print('--- APPLY: Eksik indexler kuruluyor (best-effort) ---');
      for (final m in missing) {
        if (m.createSql == null || m.createSql!.trim().isEmpty) continue;
        try {
          await conn.execute(m.createSql!);
          final nowOk = await PgEklentiler.hasIndex(conn, m.name);
          print('  ${m.name}: ${nowOk ? 'OK' : 'FAIL'}');
        } on ServerException catch (e) {
          print('  ${m.name}: ServerException ${e.code} ${e.message}');
        } catch (e) {
          print('  ${m.name}: ERR $e');
        }
      }
    }

    if (explain) {
      print('');
      print('--- EXPLAIN (ANALYZE, BUFFERS): En kötü 3 rapor (temsili) ---');
      await _runExplains(
        conn,
        searchQuery: searchQuery,
        companyId: companyId,
      );
    }
  } on ServerException catch (e) {
    print('DB hata (ServerException): ${e.code} ${e.message}');
  } catch (e) {
    print('DB hata: $e');
  } finally {
    await conn?.close();
  }
}

Future<void> _bestEffortExecute(Connection conn, String sql) async {
  final s = sql.trim();
  if (s.isEmpty) return;
  try {
    await conn.execute(s);
  } catch (_) {
    // Best-effort; bazı DB'lerde tablo/izin yoksa uygulamayı bozma.
  }
}

Future<void> _runExplains(
  Connection conn, {
  required String? searchQuery,
  required String companyId,
}) async {
  final trimmedQ = (searchQuery ?? '').trim();
  final hasQ = trimmedQ.length >= 2;

  // 1) product_movements (stock_movements + products)
  final explain1 = hasQ
      ? Sql.named(r'''
        EXPLAIN (ANALYZE, BUFFERS)
        SELECT sm.id
        FROM stock_movements sm
        INNER JOIN products p ON p.id = sm.product_id
        WHERE (
          sm.search_tags LIKE @search
          OR to_tsvector('simple', sm.search_tags) @@ plainto_tsquery('simple', @fts)
          OR p.search_tags LIKE @search
          OR to_tsvector('simple', p.search_tags) @@ plainto_tsquery('simple', @fts)
        )
        ORDER BY sm.movement_date DESC, sm.id DESC
        LIMIT 26
      ''')
      : Sql.named(r'''
        EXPLAIN (ANALYZE, BUFFERS)
        SELECT sm.id
        FROM stock_movements sm
        ORDER BY sm.movement_date DESC, sm.id DESC
        LIMIT 26
      ''');

  // 2) all_movements (union)
  final explain2 = hasQ
      ? Sql.named(r'''
        EXPLAIN (ANALYZE, BUFFERS)
        WITH m AS (
          SELECT date AS tarih, id::text AS gid, search_tags FROM current_account_transactions
          UNION ALL
          SELECT date AS tarih, id::text AS gid, search_tags FROM bank_transactions
          UNION ALL
          SELECT date AS tarih, id::text AS gid, search_tags FROM cash_register_transactions
          UNION ALL
          SELECT date AS tarih, id::text AS gid, search_tags FROM credit_card_transactions
          UNION ALL
          SELECT movement_date AS tarih, id::text AS gid, search_tags FROM stock_movements
        )
        SELECT gid, tarih
        FROM m
        WHERE (
          search_tags LIKE @search
          OR to_tsvector('simple', search_tags) @@ plainto_tsquery('simple', @fts)
        )
        ORDER BY tarih DESC, gid DESC
        LIMIT 26
      ''')
      : Sql.named(r'''
        EXPLAIN (ANALYZE, BUFFERS)
        WITH m AS (
          SELECT date AS tarih, id::text AS gid FROM current_account_transactions
          UNION ALL
          SELECT date AS tarih, id::text AS gid FROM bank_transactions
          UNION ALL
          SELECT date AS tarih, id::text AS gid FROM cash_register_transactions
          UNION ALL
          SELECT date AS tarih, id::text AS gid FROM credit_card_transactions
          UNION ALL
          SELECT movement_date AS tarih, id::text AS gid FROM stock_movements
        )
        SELECT gid, tarih
        FROM m
        ORDER BY tarih DESC, gid DESC
        LIMIT 26
      ''');

  // 3) user_activity_report (user_transactions)
  final explain3 = Sql.named(r'''
    EXPLAIN (ANALYZE, BUFFERS)
    SELECT ut.id, ut.date
    FROM user_transactions ut
    WHERE COALESCE(ut.company_id, 'patisyo2025') = @companyId
    ORDER BY ut.date DESC, ut.id DESC
    LIMIT 26
  ''');

  final paramsSearch = <String, dynamic>{
    if (hasQ) 'search': '%${trimmedQ.toLowerCase()}%',
    if (hasQ) 'fts': trimmedQ.toLowerCase(),
  };
  final paramsCompany = <String, dynamic>{'companyId': companyId};

  await _printExplain(conn, '1) product_movements', explain1, paramsSearch);
  await _printExplain(conn, '2) all_movements (union)', explain2, paramsSearch);
  await _printExplain(conn, '3) user_activity_report', explain3, paramsCompany);
}

Future<void> _printExplain(
  Connection conn,
  String title,
  Sql sql,
  Map<String, dynamic> params,
) async {
  print('');
  print('>>> $title');
  try {
    final res = await conn.execute(sql, parameters: params);
    for (final row in res) {
      final v = (row.isNotEmpty ? row[0] : null)?.toString() ?? '';
      if (v.isNotEmpty) print(v);
    }
  } catch (e) {
    print('EXPLAIN hata: $e');
  }
}

List<_IndexSpec> _indexSpecs() {
  // Sadece index adı + yaratma SQL'i. `IF NOT EXISTS` ile idempotent.
  // Not: Bazı DB'lerde tablo yoksa create hata verebilir; best-effort.
  return const <_IndexSpec>[
    // search_tags: trigram + FTS
    _IndexSpec(
      'idx_accounts_search_tags_gin',
      'CREATE INDEX IF NOT EXISTS idx_accounts_search_tags_gin ON current_accounts USING GIN (search_tags gin_trgm_ops)',
    ),
    _IndexSpec(
      'idx_accounts_search_tags_fts_gin',
      "CREATE INDEX IF NOT EXISTS idx_accounts_search_tags_fts_gin ON current_accounts USING GIN (to_tsvector('simple', search_tags))",
    ),
    _IndexSpec(
      'idx_products_search_tags_gin',
      'CREATE INDEX IF NOT EXISTS idx_products_search_tags_gin ON products USING GIN (search_tags gin_trgm_ops)',
    ),
    _IndexSpec(
      'idx_products_search_tags_fts_gin',
      "CREATE INDEX IF NOT EXISTS idx_products_search_tags_fts_gin ON products USING GIN (to_tsvector('simple', search_tags))",
    ),
    _IndexSpec(
      'idx_sm_search_tags_gin',
      'CREATE INDEX IF NOT EXISTS idx_sm_search_tags_gin ON stock_movements USING GIN (search_tags gin_trgm_ops)',
    ),
    _IndexSpec(
      'idx_sm_search_tags_fts_gin',
      "CREATE INDEX IF NOT EXISTS idx_sm_search_tags_fts_gin ON stock_movements USING GIN (to_tsvector('simple', search_tags))",
    ),
    _IndexSpec(
      'idx_shipments_search_tags_gin',
      'CREATE INDEX IF NOT EXISTS idx_shipments_search_tags_gin ON shipments USING GIN (search_tags gin_trgm_ops)',
    ),
    _IndexSpec(
      'idx_shipments_search_tags_fts_gin',
      "CREATE INDEX IF NOT EXISTS idx_shipments_search_tags_fts_gin ON shipments USING GIN (to_tsvector('simple', search_tags))",
    ),
    _IndexSpec(
      'idx_orders_search_tags_gin',
      'CREATE INDEX IF NOT EXISTS idx_orders_search_tags_gin ON orders USING GIN (search_tags gin_trgm_ops)',
    ),
    _IndexSpec(
      'idx_orders_search_tags_fts_gin',
      "CREATE INDEX IF NOT EXISTS idx_orders_search_tags_fts_gin ON orders USING GIN (to_tsvector('simple', search_tags))",
    ),
    _IndexSpec(
      'idx_quotes_search_tags_gin',
      'CREATE INDEX IF NOT EXISTS idx_quotes_search_tags_gin ON quotes USING GIN (search_tags gin_trgm_ops)',
    ),
    _IndexSpec(
      'idx_quotes_search_tags_fts_gin',
      "CREATE INDEX IF NOT EXISTS idx_quotes_search_tags_fts_gin ON quotes USING GIN (to_tsvector('simple', search_tags))",
    ),

    // Cursor/keyset composite indexler
    _IndexSpec(
      'idx_sm_movement_date_id',
      'CREATE INDEX IF NOT EXISTS idx_sm_movement_date_id ON stock_movements(movement_date, id)',
    ),
    _IndexSpec(
      'idx_shipments_date_id',
      'CREATE INDEX IF NOT EXISTS idx_shipments_date_id ON shipments(date, id)',
    ),
    _IndexSpec(
      'idx_orders_tarih_id',
      'CREATE INDEX IF NOT EXISTS idx_orders_tarih_id ON orders(tarih, id)',
    ),
    _IndexSpec(
      'idx_quotes_tarih_id',
      'CREATE INDEX IF NOT EXISTS idx_quotes_tarih_id ON quotes(tarih, id)',
    ),
    _IndexSpec(
      'idx_ut_company_date_id',
      "CREATE INDEX IF NOT EXISTS idx_ut_company_date_id ON user_transactions (COALESCE(company_id, 'patisyo2025'), date DESC, id DESC)",
    ),
  ];
}

class _IndexSpec {
  final String name;
  final String? createSql;
  const _IndexSpec(this.name, this.createSql);
}

String? _parseOnlyDbArg(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final a = args[i].trim();
    if (a == '--db' && i + 1 < args.length) {
      final v = args[i + 1].trim();
      return v.isEmpty ? null : v;
    }
    if (a.startsWith('--db=')) {
      final v = a.substring('--db='.length).trim();
      return v.isEmpty ? null : v;
    }
  }
  return null;
}

String? _parseValueArg(List<String> args, String key) {
  final k = key.trim();
  if (k.isEmpty) return null;
  for (var i = 0; i < args.length; i++) {
    final a = args[i].trim();
    if (a == k && i + 1 < args.length) {
      final v = args[i + 1].trim();
      return v.isEmpty ? null : v;
    }
    if (a.startsWith('$k=')) {
      final v = a.substring('$k='.length).trim();
      return v.isEmpty ? null : v;
    }
  }
  return null;
}

bool _isTruthy(String? value) {
  final v = (value ?? '').trim().toLowerCase();
  return v == '1' || v == 'true' || v == 'yes' || v == 'y' || v == 'on';
}

Future<List<String>> _fetchCompanyCodesBestEffort({
  required String host,
  required int port,
  required String username,
  required String password,
  required String settingsDb,
}) async {
  Connection? conn;
  try {
    final sslMode = _sslModeFromEnv();
    conn = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: settingsDb,
        username: username,
        password: password,
      ),
      settings: ConnectionSettings(sslMode: sslMode),
    );

    final res = await conn.execute('SELECT kod FROM company_settings');
    final out = <String>[];
    for (final row in res) {
      final v = (row[0] ?? '').toString().trim();
      if (v.isNotEmpty) out.add(v);
    }
    return out;
  } catch (_) {
    return const <String>[];
  } finally {
    await conn?.close();
  }
}

String _veritabaniAdiHesapla(String companyCode) {
  final trimmed = companyCode.trim();
  if (trimmed == 'patisyo2025') return 'patisyo2025';
  final safeCode = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
  return safeCode.isEmpty ? 'patisyo2025' : 'patisyo_$safeCode';
}

SslMode _sslModeFromEnv() {
  final raw =
      (Platform.environment['PATISYO_PG_SSLMODE'] ??
              Platform.environment['PATISYO_DB_SSLMODE'] ??
              Platform.environment['PGSSLMODE'] ??
              '')
          .trim()
          .toLowerCase();
  if (raw == 'require') return SslMode.require;
  if (raw == 'verifyfull') return SslMode.verifyFull;
  return SslMode.disable;
}
