// ignore_for_file: avoid_print

import 'dart:io';

import 'package:postgres/postgres.dart';

import 'package:patisyov10/servisler/arama/buyuk_olcek_arama_bootstrap_spec.dart';
import 'package:patisyov10/servisler/pg_eklentiler.dart';

const String _settingsDb = 'patisyosettings';
const String _defaultDb = 'patisyo2025';
const int _minimumPgVersionNum = 180003; // PostgreSQL 18.3

Future<void> main(List<String> args) async {
  final onlyDb = _parseOnlyDbArg(args);
  final apply = args.any((a) => a.trim() == '--apply');
  final explain = args.any((a) => a.trim() == '--explain');
  final q = _parseValueArg(args, '--q');
  final companyId = _parseValueArg(args, '--company')?.trim().isNotEmpty == true
      ? _parseValueArg(args, '--company')!.trim()
      : _defaultDb;

  if ((apply || explain) &&
      !_isTruthy(Platform.environment['PATISYO_ALLOW_HEAVY_MAINTENANCE'])) {
    print(
      '❌ --apply/--explain icin bakim onayi gerekli: '
      'PATISYO_ALLOW_HEAVY_MAINTENANCE=true',
    );
    exitCode = 2;
    return;
  }

  final host =
      (Platform.environment['PATISYO_PG_HOST'] ??
              Platform.environment['PATISYO_DB_HOST'] ??
              '127.0.0.1')
          .trim();
  final port =
      int.tryParse(
        (Platform.environment['PATISYO_PG_PORT'] ??
                Platform.environment['PATISYO_DB_PORT'] ??
                '')
            .trim(),
      ) ??
      5432;
  final username =
      (Platform.environment['PATISYO_PG_USER'] ??
              Platform.environment['PATISYO_DB_USER'] ??
              'patisyo')
          .trim();
  final password =
      (Platform.environment['PATISYO_PG_PASSWORD'] ??
              Platform.environment['PATISYO_DB_PASSWORD'] ??
              '')
          .trim();
  final sslMode = _sslModeFromEnv();

  final dbNames = <String>{};
  if (onlyDb != null) {
    dbNames.add(onlyDb);
  } else {
    dbNames
      ..add(_settingsDb)
      ..add(_defaultDb);
    final codes = await _fetchCompanyCodesBestEffort(
      host: host,
      port: port,
      username: username,
      password: password,
      settingsDb: _settingsDb,
      sslMode: sslMode,
    );
    for (final code in codes) {
      dbNames.add(_veritabaniAdiHesapla(code));
    }
  }

  print('--- Prod Report Index Check Basliyor ---');
  print('Host: $host:$port  User: $username  DB count: ${dbNames.length}');
  if (onlyDb != null) print('Sadece DB hedefi: $onlyDb');
  if (apply) print('MODE: APPLY');
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

  final bool isSettingsDb = db == _settingsDb;
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

    final versionInfo = await _serverVersionInfo(conn);
    final bool versionOk = versionInfo.versionNum >= _minimumPgVersionNum;
    print(
      'postgres: ${versionInfo.versionText} '
      '(num=${versionInfo.versionNum}) ${versionOk ? 'OK' : 'MIN 18.3 GEREKLI'}',
    );
    if (!versionOk && exitCode == 0) {
      exitCode = 3;
    }

    final hasTrgm = await PgEklentiler.hasExtension(conn, 'pg_trgm');
    print('pg_trgm: ${hasTrgm ? 'OK' : 'YOK'}');

    if (apply) {
      await _prepareSearchColumns(conn, isSettingsDb: isSettingsDb);
    }

    final specs = isSettingsDb ? _settingsIndexSpecs() : _companyIndexSpecs();
    var ok = 0;
    final missing = <_IndexSpec>[];

    for (final spec in specs) {
      if (!await _tableExists(conn, spec.table)) {
        continue;
      }
      final exists = await _hasAnyIndex(conn, spec.acceptedNames);
      if (exists) {
        ok++;
      } else {
        missing.add(spec);
      }
    }

    print('Index: OK=$ok MISS=${missing.length} TOTAL=${specs.length}');
    if (missing.isNotEmpty) {
      print('Eksikler:');
      for (final spec in missing) {
        print('  - ${spec.acceptedNames.first} (${spec.table})');
      }
    }

    if (apply && missing.isNotEmpty) {
      print('');
      print('--- APPLY: Eksik indexler kuruluyor ---');
      for (final spec in missing) {
        final createSql = spec.createSql?.trim() ?? '';
        if (createSql.isEmpty) continue;
        try {
          await conn.execute(createSql);
          final nowOk = await _hasAnyIndex(conn, spec.acceptedNames);
          print('  ${spec.acceptedNames.first}: ${nowOk ? 'OK' : 'FAIL'}');
        } on ServerException catch (e) {
          print(
            '  ${spec.acceptedNames.first}: ServerException ${e.code} ${e.message}',
          );
        } catch (e) {
          print('  ${spec.acceptedNames.first}: ERR $e');
        }
      }
    }

    await _reportBackfillStatus(conn, isSettingsDb: isSettingsDb);

    if (explain) {
      print('');
      print('--- EXPLAIN (ANALYZE, BUFFERS) ---');
      await _runExplains(
        conn,
        isSettingsDb: isSettingsDb,
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

Future<void> _prepareSearchColumns(
  Connection conn, {
  required bool isSettingsDb,
}) async {
  final tables = isSettingsDb
      ? const <String>[
          'users',
          'user_transactions',
          'roles',
          'company_settings',
        ]
      : BuyukOlcekAramaBootstrapSpec.searchTables;

  for (final table in tables) {
    if (!await _tableExists(conn, table)) continue;
    await _bestEffortExecute(
      conn,
      "ALTER TABLE ${_qi(table)} ADD COLUMN IF NOT EXISTS search_tags TEXT NOT NULL DEFAULT ''",
    );
  }

  if (!isSettingsDb) return;
}

Future<void> _reportBackfillStatus(
  Connection conn, {
  required bool isSettingsDb,
}) async {
  final tables = isSettingsDb
      ? const <String>[
          'users',
          'user_transactions',
          'roles',
          'company_settings',
        ]
      : BuyukOlcekAramaBootstrapSpec.searchTables;
  final dirtyTables = <String>[];

  for (final table in tables) {
    if (!await _tableExists(conn, table)) continue;
    final hasMissing = await _hasMissingSearchTags(conn, table);
    if (hasMissing) {
      dirtyTables.add(table);
    }
  }

  if (dirtyTables.isEmpty) {
    print('Backfill: CLEAN');
  } else {
    print('Backfill gerekiyor: ${dirtyTables.join(', ')}');
    if (exitCode == 0) {
      exitCode = 4;
    }
  }
}

Future<bool> _hasMissingSearchTags(Connection conn, String table) async {
  try {
    final rows = await conn.execute(
      Sql.named('''
        SELECT 1
        FROM ${_qi(table)}
        WHERE search_tags IS NULL OR BTRIM(search_tags) = ''
        LIMIT 1
      '''),
    );
    return rows.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<void> _runExplains(
  Connection conn, {
  required bool isSettingsDb,
  required String? searchQuery,
  required String companyId,
}) async {
  final trimmedQ = (searchQuery ?? '').trim().toLowerCase();
  final hasQ = trimmedQ.length >= 2;

  if (isSettingsDb) {
    final explainUsers = hasQ
        ? Sql.named(r'''
          EXPLAIN (ANALYZE, BUFFERS)
          SELECT u.id
          FROM users u
          WHERE u.search_tags LIKE @search
          ORDER BY u.hire_date_sort DESC NULLS LAST, u.id DESC
          LIMIT 26
        ''')
        : Sql.named(r'''
          EXPLAIN (ANALYZE, BUFFERS)
          SELECT u.id
          FROM users u
          ORDER BY u.hire_date_sort DESC NULLS LAST, u.id DESC
          LIMIT 26
        ''');

    final explainUserTx = Sql.named(r'''
      EXPLAIN (ANALYZE, BUFFERS)
      SELECT ut.id, ut.date
      FROM user_transactions ut
      WHERE COALESCE(ut.company_id, 'patisyo2025') = @companyId
      ORDER BY ut.date DESC, ut.id DESC
      LIMIT 26
    ''');

    final explainCompany = hasQ
        ? Sql.named(r'''
          EXPLAIN (ANALYZE, BUFFERS)
          SELECT cs.id
          FROM company_settings cs
          WHERE cs.search_tags LIKE @search
          ORDER BY cs.kod ASC, cs.id ASC
          LIMIT 26
        ''')
        : Sql.named(r'''
          EXPLAIN (ANALYZE, BUFFERS)
          SELECT cs.id
          FROM company_settings cs
          ORDER BY cs.kod ASC, cs.id ASC
          LIMIT 26
        ''');

    final paramsSearch = <String, dynamic>{if (hasQ) 'search': '%$trimmedQ%'};
    final paramsCompany = <String, dynamic>{'companyId': companyId};

    await _printExplain(conn, '1) users_list', explainUsers, paramsSearch);
    await _printExplain(
      conn,
      '2) user_activity_report',
      explainUserTx,
      paramsCompany,
    );
    await _printExplain(
      conn,
      '3) company_settings_list',
      explainCompany,
      paramsSearch,
    );
    return;
  }

  final explain1 = hasQ
      ? Sql.named(r'''
        EXPLAIN (ANALYZE, BUFFERS)
        SELECT sm.id
        FROM stock_movements sm
        INNER JOIN products p ON p.id = sm.product_id
        WHERE (
          sm.search_tags LIKE @search
          OR p.search_tags LIKE @search
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
        WHERE search_tags LIKE @search
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

  final explain3 = hasQ
      ? Sql.named(r'''
        EXPLAIN (ANALYZE, BUFFERS)
        SELECT s.id
        FROM shipments s
        WHERE s.search_tags LIKE @search
        ORDER BY s.date DESC, s.id DESC
        LIMIT 26
      ''')
      : Sql.named(r'''
        EXPLAIN (ANALYZE, BUFFERS)
        SELECT s.id
        FROM shipments s
        ORDER BY s.date DESC, s.id DESC
        LIMIT 26
      ''');

  final paramsSearch = <String, dynamic>{if (hasQ) 'search': '%$trimmedQ%'};

  await _printExplain(conn, '1) product_movements', explain1, paramsSearch);
  await _printExplain(conn, '2) all_movements', explain2, paramsSearch);
  await _printExplain(
    conn,
    '3) warehouse_shipment_list',
    explain3,
    paramsSearch,
  );
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
      if (v.isNotEmpty) {
        print(v);
      }
    }
  } catch (e) {
    print('EXPLAIN hata: $e');
  }
}

List<_IndexSpec> _companyIndexSpecs() {
  final specs = <_IndexSpec>[];

  for (final table in BuyukOlcekAramaBootstrapSpec.searchTables) {
    specs.add(
      _IndexSpec(
        table: table,
        acceptedNames: <String>[_trgmIndexName(table)],
        createSql:
            'CREATE INDEX IF NOT EXISTS ${_trgmIndexName(table)} '
            'ON ${_qi(table)} USING GIN (search_tags gin_trgm_ops)',
      ),
    );
  }

  for (final spec in BuyukOlcekAramaBootstrapSpec.brinSpecs) {
    specs.add(
      _IndexSpec(
        table: spec.table,
        acceptedNames: <String>[spec.indexName],
        createSql:
            'CREATE INDEX IF NOT EXISTS ${spec.indexName} '
            'ON ${_qi(spec.table)} USING BRIN (${_qi(spec.column)})',
      ),
    );
  }

  for (final spec in BuyukOlcekAramaBootstrapSpec.compositeSpecs) {
    specs.add(
      _IndexSpec(
        table: spec.table,
        acceptedNames: <String>[spec.indexName],
        createSql:
            'CREATE INDEX IF NOT EXISTS ${spec.indexName} '
            'ON ${_qi(spec.table)} (${spec.expressions.join(', ')})',
      ),
    );
  }

  return specs;
}

List<_IndexSpec> _settingsIndexSpecs() {
  return <_IndexSpec>[
    _IndexSpec(
      table: 'users',
      acceptedNames: const <String>['idx_settings_users_search_tags_gin'],
      createSql:
          'CREATE INDEX IF NOT EXISTS idx_settings_users_search_tags_gin '
          'ON users USING GIN (search_tags gin_trgm_ops)',
    ),
    _IndexSpec(
      table: 'user_transactions',
      acceptedNames: const <String>['idx_settings_user_tx_search_tags_gin'],
      createSql:
          'CREATE INDEX IF NOT EXISTS idx_settings_user_tx_search_tags_gin '
          'ON user_transactions USING GIN (search_tags gin_trgm_ops)',
    ),
    _IndexSpec(
      table: 'roles',
      acceptedNames: const <String>['idx_settings_roles_search_tags_gin'],
      createSql:
          'CREATE INDEX IF NOT EXISTS idx_settings_roles_search_tags_gin '
          'ON roles USING GIN (search_tags gin_trgm_ops)',
    ),
    _IndexSpec(
      table: 'company_settings',
      acceptedNames: const <String>['idx_settings_company_search_tags_gin'],
      createSql:
          'CREATE INDEX IF NOT EXISTS idx_settings_company_search_tags_gin '
          'ON company_settings USING GIN (search_tags gin_trgm_ops)',
    ),
    _IndexSpec(
      table: 'users',
      acceptedNames: const <String>['idx_settings_users_hire_date_sort'],
      createSql:
          'CREATE INDEX IF NOT EXISTS idx_settings_users_hire_date_sort '
          'ON users (hire_date_sort, id)',
    ),
    _IndexSpec(
      table: 'users',
      acceptedNames: const <String>['idx_settings_users_role_active_id'],
      createSql:
          'CREATE INDEX IF NOT EXISTS idx_settings_users_role_active_id '
          'ON users (role, is_active, id)',
    ),
    _IndexSpec(
      table: 'roles',
      acceptedNames: const <String>['idx_settings_roles_name_id'],
      createSql:
          'CREATE INDEX IF NOT EXISTS idx_settings_roles_name_id '
          'ON roles (name, id)',
    ),
    _IndexSpec(
      table: 'company_settings',
      acceptedNames: const <String>['idx_settings_company_kod_id'],
      createSql:
          'CREATE INDEX IF NOT EXISTS idx_settings_company_kod_id '
          'ON company_settings (kod, id)',
    ),
    _IndexSpec(
      table: 'company_settings',
      acceptedNames: const <String>['idx_settings_company_ad_id'],
      createSql:
          'CREATE INDEX IF NOT EXISTS idx_settings_company_ad_id '
          'ON company_settings (ad, id)',
    ),
    _IndexSpec(
      table: 'user_transactions',
      acceptedNames: const <String>['idx_ut_company_date_id'],
      createSql:
          "CREATE INDEX IF NOT EXISTS idx_ut_company_date_id "
          "ON user_transactions (COALESCE(company_id, 'patisyo2025'), date DESC, id DESC)",
    ),
  ];
}

class _IndexSpec {
  final String table;
  final List<String> acceptedNames;
  final String? createSql;

  const _IndexSpec({
    required this.table,
    required this.acceptedNames,
    required this.createSql,
  });
}

Future<({String versionText, int versionNum})> _serverVersionInfo(
  Connection conn,
) async {
  final textRes = await conn.execute('SHOW server_version');
  final numRes = await conn.execute('SHOW server_version_num');
  final versionText = textRes.isEmpty ? '-' : textRes.first[0].toString();
  final versionNum = _toInt(numRes.isEmpty ? null : numRes.first[0]);
  return (versionText: versionText, versionNum: versionNum);
}

Future<bool> _hasAnyIndex(Session executor, List<String> names) async {
  for (final name in names) {
    if (await PgEklentiler.hasIndex(executor, name)) {
      return true;
    }
  }
  return false;
}

String _trgmIndexName(String table) {
  switch (table) {
    case 'current_accounts':
      return 'idx_accounts_search_tags_gin';
    case 'stock_movements':
      return 'idx_sm_search_tags_gin';
    default:
      return 'idx_${table}_search_tags_gin';
  }
}

Future<void> _bestEffortExecute(Connection conn, String sql) async {
  final trimmed = sql.trim();
  if (trimmed.isEmpty) return;
  try {
    await conn.execute(trimmed);
  } catch (_) {
    // Best effort.
  }
}

String _qi(String ident) {
  final trimmed = ident.trim();
  final safe = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');
  if (trimmed.isEmpty || !safe.hasMatch(trimmed)) {
    throw ArgumentError.value(ident, 'ident', 'Unsafe identifier');
  }
  return '"$trimmed"';
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
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
  required SslMode sslMode,
}) async {
  Connection? conn;
  try {
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
  if (trimmed == _defaultDb) return _defaultDb;
  final safeCode = trimmed
      .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
      .toLowerCase();
  return safeCode.isEmpty ? _defaultDb : 'patisyo_$safeCode';
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

Future<bool> _tableExists(Session executor, String table) async {
  final trimmed = table.trim();
  if (trimmed.isEmpty) return false;
  try {
    final res = await executor.execute(
      Sql.named('''
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = @table
        LIMIT 1
      '''),
      parameters: {'table': trimmed},
    );
    return res.isNotEmpty;
  } catch (_) {
    return false;
  }
}
