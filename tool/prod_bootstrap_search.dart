// ignore_for_file: avoid_print

import 'dart:io';

import 'package:postgres/postgres.dart';

import 'package:patisyov10/servisler/arama/buyuk_olcek_arama_bootstrap_spec.dart';
import 'package:patisyov10/servisler/pg_eklentiler.dart';

const String _settingsDb = 'patisyosettings';
const String _defaultDb = 'patisyo2025';
const int _minimumPgVersionNum = 180003; // PostgreSQL 18.3
const String _bootstrapVersionPrefix = 'v2026_bootstrap_1';

const Map<String, List<String>> _searchBackfillHints = <String, List<String>>{
  'products': <String>[
    'id',
    'kod',
    'ad',
    'barkod',
    'grubu',
    'birim',
    'ozellikler',
    'aciklama',
  ],
  'stock_movements': <String>[
    'id',
    'movement_type',
    'movement_date',
    'quantity',
    'unit_price',
    'description',
    'created_by',
    'integration_ref',
    'vat_status',
    'currency_code',
  ],
  'banks': <String>[
    'id',
    'code',
    'name',
    'bank_name',
    'branch_name',
    'account_holder',
    'iban',
    'currency',
  ],
  'bank_transactions': <String>[
    'id',
    'transaction_type',
    'date',
    'description',
    'location_name',
    'amount',
    'collection_status',
    'integration_ref',
  ],
  'cash_registers': <String>['id', 'code', 'name', 'currency', 'description'],
  'cash_register_transactions': <String>[
    'id',
    'transaction_type',
    'date',
    'description',
    'location',
    'amount',
    'collection_status',
    'integration_ref',
  ],
  'credit_cards': <String>[
    'id',
    'code',
    'name',
    'bank_name',
    'card_holder',
    'last_four_digits',
    'currency',
  ],
  'credit_card_transactions': <String>[
    'id',
    'transaction_type',
    'date',
    'description',
    'location_name',
    'amount',
    'collection_status',
    'integration_ref',
  ],
  'current_accounts': <String>[
    'id',
    'kod_no',
    'adi',
    'hesap_turu',
    'telefon',
    'eposta',
    'e_posta',
    'adres',
    'vkn_tckn',
    'vergi_no',
    'tc_kimlik_no',
  ],
  'current_account_transactions': <String>[
    'id',
    'date',
    'source_type',
    'description',
    'current_account_name',
    'amount',
    'collection_status',
    'integration_ref',
  ],
  'cheques': <String>[
    'id',
    'check_no',
    'owner_name',
    'bank_name',
    'branch_name',
    'account_no',
    'status',
    'amount',
    'due_date',
    'currency',
  ],
  'cheque_transactions': <String>[
    'id',
    'date',
    'type',
    'description',
    'status',
    'collection_status',
    'amount',
    'integration_ref',
  ],
  'promissory_notes': <String>[
    'id',
    'note_no',
    'owner_name',
    'status',
    'amount',
    'due_date',
    'direction',
    'currency',
  ],
  'note_transactions': <String>[
    'id',
    'date',
    'type',
    'description',
    'status',
    'collection_status',
    'amount',
    'integration_ref',
  ],
  'depots': <String>['id', 'kod', 'ad', 'adres', 'sorumlu', 'telefon'],
  'shipments': <String>[
    'id',
    'date',
    'description',
    'created_by',
    'integration_ref',
  ],
  'expenses': <String>[
    'id',
    'tarih',
    'tip',
    'kategori',
    'aciklama',
    'odeme_yontemi',
    'tutar',
    'created_by',
  ],
  'expense_items': <String>[
    'id',
    'description',
    'category',
    'amount',
    'vat_rate',
  ],
  'orders': <String>[
    'id',
    'tarih',
    'siparis_no',
    'cari_adi',
    'durum',
    'created_by',
    'aciklama',
    'integration_ref',
  ],
  'order_items': <String>[
    'id',
    'urun_kodu',
    'urun_adi',
    'birim',
    'miktar',
    'fiyat',
    'toplam',
  ],
  'quotes': <String>[
    'id',
    'tarih',
    'teklif_no',
    'cari_adi',
    'durum',
    'created_by',
    'aciklama',
    'integration_ref',
  ],
  'quote_items': <String>[
    'id',
    'urun_kodu',
    'urun_adi',
    'birim',
    'miktar',
    'fiyat',
    'toplam',
  ],
  'productions': <String>[
    'id',
    'kod',
    'ad',
    'tarih',
    'durum',
    'aciklama',
    'created_by',
  ],
  'production_stock_movements': <String>[
    'id',
    'movement_date',
    'movement_type',
    'product_code',
    'product_name',
    'quantity',
    'description',
    'integration_ref',
  ],
  'users': <String>[
    'id',
    'username',
    'name',
    'surname',
    'email',
    'role',
    'phone',
    'salary',
    'description',
  ],
  'user_transactions': <String>[
    'id',
    'date',
    'type',
    'description',
    'debt',
    'credit',
    'company_id',
  ],
  'roles': <String>['id', 'name', 'description'],
  'company_settings': <String>[
    'id',
    'kod',
    'ad',
    'vergi_no',
    'telefon',
    'email',
    'adres',
    'yetkili',
  ],
};

Future<void> main(List<String> args) async {
  if (!_isTruthy(Platform.environment['PATISYO_ALLOW_HEAVY_MAINTENANCE'])) {
    print(
      '❌ Bu script sadece bakım penceresinde çalıştırılmalı. '
      'Çalıştırmak için env: PATISYO_ALLOW_HEAVY_MAINTENANCE=true',
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
  final onlyDb = _parseOnlyDbArg(args);

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

  print('--- Prod Search Bootstrap Basliyor ---');
  print('Host: $host:$port  User: $username  DB count: ${dbNames.length}');
  if (onlyDb != null) {
    print('Sadece DB hedefi: $onlyDb');
  }

  for (final db in dbNames) {
    await _bootstrapDb(
      host: host,
      port: port,
      username: username,
      password: password,
      database: db,
      sslMode: sslMode,
    );
  }

  print('--- Prod Search Bootstrap Bitti ---');
}

Future<void> _bootstrapDb({
  required String host,
  required int port,
  required String username,
  required String password,
  required String database,
  required SslMode sslMode,
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

    final versionInfo = await _serverVersionInfo(conn);
    final bool versionOk = versionInfo.versionNum >= _minimumPgVersionNum;
    print(
      'postgres: ${versionInfo.versionText} '
      '(num=${versionInfo.versionNum}) ${versionOk ? 'OK' : 'MIN 18.3 GEREKLI'}',
    );
    if (!versionOk && exitCode == 0) {
      exitCode = 3;
    }

    await PgEklentiler.ensurePgTrgm(conn);
    final hasPgTrgm = await PgEklentiler.hasExtension(conn, 'pg_trgm');
    print('pg_trgm: ${hasPgTrgm ? 'OK' : 'YOK'}');

    await _ensureNormalizeFunction(conn);

    if (db == _settingsDb) {
      await _bootstrapSettingsDb(conn);
    } else {
      await _bootstrapCompanyDb(conn);
    }
  } on ServerException catch (e) {
    print('DB hata (ServerException): ${e.code} ${e.message}');
  } catch (e) {
    print('DB hata: $e');
  } finally {
    await conn?.close();
  }
}

Future<void> _bootstrapCompanyDb(Connection conn) async {
  var searchOk = 0;
  var searchSkip = 0;
  var searchBackfillRows = 0;
  final searchDirtyTables = <String>[];

  for (final table in BuyukOlcekAramaBootstrapSpec.searchTables) {
    final exists = await _tableExists(conn, table);
    if (!exists) {
      searchSkip++;
      continue;
    }
    await PgEklentiler.ensureSearchTagsNotNullDefault(conn, table);
    await PgEklentiler.ensureSearchTagsTrgmIndex(
      conn,
      table: table,
      indexName: _trgmIndexName(table),
    );
    final updated = await _backfillSearchTags(conn, table);
    searchBackfillRows += updated;
    if (updated > 0) {
      searchDirtyTables.add('$table:$updated');
    }
    final hasTrgm = await _hasAnyIndex(conn, <String>[_trgmIndexName(table)]);
    if (hasTrgm) {
      searchOk++;
    }
  }

  print(
    'Core search: OK=$searchOk SKIP=$searchSkip BACKFILL_ROWS=$searchBackfillRows',
  );
  if (searchDirtyTables.isNotEmpty) {
    print('Backfill tamamlanan tablolar: ${searchDirtyTables.join(', ')}');
  }

  var brinOk = 0;
  var brinSkip = 0;
  for (final spec in BuyukOlcekAramaBootstrapSpec.brinSpecs) {
    final exists = await _tableExists(conn, spec.table);
    if (!exists) {
      brinSkip++;
      continue;
    }
    await PgEklentiler.ensureBrinIndex(
      conn,
      table: spec.table,
      indexName: spec.indexName,
      column: spec.column,
    );
    if (await PgEklentiler.hasIndex(conn, spec.indexName)) {
      brinOk++;
    }
  }
  print(
    'BRIN index: OK=$brinOk SKIP=$brinSkip TOTAL=${BuyukOlcekAramaBootstrapSpec.brinSpecs.length}',
  );

  var compositeOk = 0;
  var compositeSkip = 0;
  for (final spec in BuyukOlcekAramaBootstrapSpec.compositeSpecs) {
    final exists = await _tableExists(conn, spec.table);
    if (!exists) {
      compositeSkip++;
      continue;
    }
    await PgEklentiler.ensureCompositeIndex(
      conn,
      table: spec.table,
      indexName: spec.indexName,
      expressions: spec.expressions,
    );
    if (await PgEklentiler.hasIndex(conn, spec.indexName)) {
      compositeOk++;
    }
  }
  print(
    'Composite index: OK=$compositeOk SKIP=$compositeSkip TOTAL=${BuyukOlcekAramaBootstrapSpec.compositeSpecs.length}',
  );
}

Future<void> _bootstrapSettingsDb(Connection conn) async {
  const tables = <String>[
    'users',
    'user_transactions',
    'roles',
    'company_settings',
  ];

  var searchOk = 0;
  var searchSkip = 0;
  var backfillRows = 0;

  for (final table in tables) {
    final exists = await _tableExists(conn, table);
    if (!exists) {
      searchSkip++;
      continue;
    }

    await PgEklentiler.ensureSearchTagsNotNullDefault(conn, table);
    await PgEklentiler.ensureSearchTagsTrgmIndex(
      conn,
      table: table,
      indexName: _settingsTrgmIndexName(table),
    );
    backfillRows += await _backfillSearchTags(conn, table);

    final hasTrgm = await _hasAnyIndex(conn, <String>[
      _settingsTrgmIndexName(table),
    ]);
    if (hasTrgm) {
      searchOk++;
    }
  }

  await _bestEffortExecute(
    conn,
    'CREATE INDEX IF NOT EXISTS idx_settings_users_hire_date_sort ON users (hire_date_sort, id)',
  );
  await _bestEffortExecute(
    conn,
    'CREATE INDEX IF NOT EXISTS idx_settings_users_role_active_id ON users (role, is_active, id)',
  );
  await _bestEffortExecute(
    conn,
    'CREATE INDEX IF NOT EXISTS idx_settings_roles_name_id ON roles (name, id)',
  );
  await _bestEffortExecute(
    conn,
    'CREATE INDEX IF NOT EXISTS idx_settings_company_kod_id ON company_settings (kod, id)',
  );
  await _bestEffortExecute(
    conn,
    'CREATE INDEX IF NOT EXISTS idx_settings_company_ad_id ON company_settings (ad, id)',
  );
  await _bestEffortExecute(
    conn,
    "CREATE INDEX IF NOT EXISTS idx_ut_company_date_id ON user_transactions (COALESCE(company_id, 'patisyo2025'), date DESC, id DESC)",
  );

  print(
    'Settings search: OK=$searchOk SKIP=$searchSkip BACKFILL_ROWS=$backfillRows',
  );
}

Future<int> _backfillSearchTags(
  Connection conn,
  String table, {
  int batchSize = 2000,
  int maxBatches = 400,
}) async {
  final exists = await _tableExists(conn, table);
  if (!exists) return 0;

  final columns = await _existingColumns(
    conn,
    table,
    _searchBackfillHints[table] ??
        const <String>[
          'id',
          'code',
          'kod',
          'name',
          'ad',
          'description',
          'aciklama',
        ],
  );
  if (columns.isEmpty) {
    return 0;
  }

  final valueExpr = columns
      .map((column) => "COALESCE(CAST(t.${_qi(column)} AS TEXT), '')")
      .join(', ');
  final computedExpr =
      "TRIM(CONCAT_WS(' ', @versionPrefix, prod_bootstrap_normalize_text(CONCAT_WS(' ', $valueExpr))))";

  var total = 0;
  for (var i = 0; i < maxBatches; i++) {
    final result = await conn.execute(
      Sql.named('''
        WITH todo AS (
          SELECT ctid
          FROM ${_qi(table)}
          WHERE search_tags IS NULL OR BTRIM(search_tags) = ''
          LIMIT @limit
        ),
        upd AS (
          UPDATE ${_qi(table)} t
          SET search_tags = $computedExpr
          FROM todo
          WHERE t.ctid = todo.ctid
          RETURNING 1
        )
        SELECT COUNT(*)::BIGINT FROM upd
      '''),
      parameters: {
        'limit': batchSize,
        'versionPrefix': _bootstrapVersionPrefix,
      },
    );
    final updated = _toInt(result.isEmpty ? null : result.first[0]);
    if (updated <= 0) break;
    total += updated;
  }
  return total;
}

Future<void> _ensureNormalizeFunction(Connection conn) async {
  await _bestEffortExecute(conn, '''
    CREATE OR REPLACE FUNCTION prod_bootstrap_normalize_text(val TEXT)
    RETURNS TEXT AS \$\$
    BEGIN
      IF val IS NULL THEN
        RETURN '';
      END IF;
      val := REPLACE(val, 'i̇', 'i');
      RETURN LOWER(
        REGEXP_REPLACE(
          TRANSLATE(
            val,
            'ÇĞİÖŞÜIçğıöşü',
            'cgiosuicgiosu'
          ),
          '[^a-zA-Z0-9@./:_ -]+',
          ' ',
          'g'
        )
      );
    END;
    \$\$ LANGUAGE plpgsql IMMUTABLE;
    ''');
}

Future<List<String>> _existingColumns(
  Session executor,
  String table,
  List<String> preferredColumns,
) async {
  final rows = await executor.execute(
    Sql.named('''
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = @table
    '''),
    parameters: {'table': table},
  );
  final available = rows
      .map((row) => row[0]?.toString().trim() ?? '')
      .where((name) => name.isNotEmpty)
      .toSet();
  return preferredColumns
      .where((column) => available.contains(column))
      .toList(growable: false);
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

Future<void> _bestEffortExecute(Connection conn, String sql) async {
  final trimmed = sql.trim();
  if (trimmed.isEmpty) return;
  try {
    await conn.execute(trimmed);
  } catch (_) {
    // Best effort.
  }
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

String _settingsTrgmIndexName(String table) {
  switch (table) {
    case 'users':
      return 'idx_settings_users_search_tags_gin';
    case 'user_transactions':
      return 'idx_settings_user_tx_search_tags_gin';
    case 'roles':
      return 'idx_settings_roles_search_tags_gin';
    case 'company_settings':
      return 'idx_settings_company_search_tags_gin';
    default:
      return 'idx_settings_${table}_search_tags_gin';
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

String _veritabaniAdiHesapla(String kod) {
  final trimmed = kod.trim();
  if (trimmed == _defaultDb) return _defaultDb;
  final safeCode = trimmed
      .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
      .toLowerCase();
  return safeCode.isEmpty ? _defaultDb : 'patisyo_$safeCode';
}

bool _isTruthy(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  return v == '1' || v == 'true' || v == 'yes' || v == 'on';
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
