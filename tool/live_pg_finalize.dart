// ignore_for_file: avoid_print

import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:patisyov10/servisler/postgresql_tuning_profili.dart';

const String _settingsDb = 'patisyosettings';
const String _defaultDb = 'patisyo2025';
const String _legacyPassword = '5828486';
const int _minimumPgVersionNum = 180003; // PostgreSQL 18.3

Future<void> main(List<String> args) async {
  final onlyDb = _parseValueArg(args, '--db')?.trim();
  final host =
      (Platform.environment['PATISYO_PG_HOST'] ??
              Platform.environment['PATISYO_DB_HOST'] ??
              '127.0.0.1')
          .trim();
  final port =
      int.tryParse(
        (Platform.environment['PATISYO_PG_PORT'] ??
                Platform.environment['PATISYO_DB_PORT'] ??
                '5432')
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
              _legacyPassword)
          .trim();
  final sslMode = _sslModeFromEnv();

  final dbNames = <String>{};
  if (onlyDb != null && onlyDb.isNotEmpty) {
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
      dbNames.add(_companyDbName(code));
    }
  }

  print('--- Live PG Finalize Basliyor ---');
  print('host=$host port=$port user=$username db_count=${dbNames.length}');

  for (final db in dbNames) {
    await _finalizeDb(
      host: host,
      port: port,
      username: username,
      password: password,
      database: db,
      sslMode: sslMode,
    );
  }

  print('--- Live PG Finalize Bitti ---');
}

Future<void> _finalizeDb({
  required String host,
  required int port,
  required String username,
  required String password,
  required String database,
  required SslMode sslMode,
}) async {
  print('');
  print('=== DB: $database ===');
  Connection? conn;
  try {
    conn = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      ),
      settings: ConnectionSettings(sslMode: sslMode),
    );

    final version = await _serverVersion(conn);
    print(
      'postgres=${version.text} num=${version.num} ${version.num >= _minimumPgVersionNum ? 'OK' : 'MIN_18_3_GEREKLI'}',
    );

    await _reportTuningProfile(conn);

    await _bestEffort(conn, 'CREATE EXTENSION IF NOT EXISTS pg_trgm');
    await _ensureNormalizeText(conn);

    await _finalizeProducts(conn);
    await _finalizeCurrentAccounts(conn);
    await _finalizeBankMetadata(conn);
    await _migrateChequeTransactions(conn);
    await _migrateNoteTransactions(conn);
    await _migrateExpenseItems(conn);
    await _runBenchmarks(conn, database: database);
  } on ServerException catch (e) {
    print('server_hata code=${e.code} message=${e.message}');
  } catch (e) {
    print('hata=$e');
  } finally {
    await conn?.close();
  }
}

Future<void> _finalizeProducts(Connection conn) async {
  if (!await _tableExists(conn, 'products')) {
    print('products: skip');
    return;
  }

  await _bestEffort(conn, '''
    CREATE OR REPLACE FUNCTION update_products_search_tags()
    RETURNS TRIGGER AS \$\$
    BEGIN
      NEW.search_tags := normalize_text(
        COALESCE(NEW.kod, '') || ' ' ||
        COALESCE(NEW.ad, '') || ' ' ||
        COALESCE(NEW.barkod, '') || ' ' ||
        COALESCE(NEW.grubu, '') || ' ' ||
        COALESCE(NEW.kullanici, '') || ' ' ||
        COALESCE(NEW.ozellikler, '') || ' ' ||
        COALESCE(NEW.birim, '') || ' ' ||
        CAST(NEW.id AS TEXT) || ' ' ||
        COALESCE(CAST(NEW.alis_fiyati AS TEXT), '') || ' ' ||
        COALESCE(CAST(NEW.satis_fiyati_1 AS TEXT), '') || ' ' ||
        COALESCE(CAST(NEW.satis_fiyati_2 AS TEXT), '') || ' ' ||
        COALESCE(CAST(NEW.satis_fiyati_3 AS TEXT), '') || ' ' ||
        COALESCE(CAST(NEW.erken_uyari_miktari AS TEXT), '') || ' ' ||
        COALESCE(CAST(NEW.stok AS TEXT), '') || ' ' ||
        COALESCE(CAST(NEW.kdv_orani AS TEXT), '') || ' ' ||
        CASE WHEN COALESCE(NEW.aktif_mi, 0) = 1 THEN 'aktif' ELSE 'pasif' END
      );
      RETURN NEW;
    END;
    \$\$ LANGUAGE plpgsql
  ''');
  await _bestEffort(
    conn,
    'DROP TRIGGER IF EXISTS trg_update_products_search_tags ON products',
  );
  await _bestEffort(conn, '''
    CREATE TRIGGER trg_update_products_search_tags
    BEFORE INSERT OR UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_products_search_tags()
  ''');

  var afterId = 0;
  while (true) {
    final rows = await conn.execute(
      Sql.named('''
        WITH todo AS (
          SELECT id
          FROM products
          WHERE id > @afterId
          ORDER BY id ASC
          LIMIT 5000
        )
        UPDATE products p
        SET search_tags = normalize_text(
          COALESCE(p.kod, '') || ' ' ||
          COALESCE(p.ad, '') || ' ' ||
          COALESCE(p.barkod, '') || ' ' ||
          COALESCE(p.grubu, '') || ' ' ||
          COALESCE(p.kullanici, '') || ' ' ||
          COALESCE(p.ozellikler, '') || ' ' ||
          COALESCE(p.birim, '') || ' ' ||
          CAST(p.id AS TEXT) || ' ' ||
          COALESCE(CAST(p.alis_fiyati AS TEXT), '') || ' ' ||
          COALESCE(CAST(p.satis_fiyati_1 AS TEXT), '') || ' ' ||
          COALESCE(CAST(p.satis_fiyati_2 AS TEXT), '') || ' ' ||
          COALESCE(CAST(p.satis_fiyati_3 AS TEXT), '') || ' ' ||
          COALESCE(CAST(p.erken_uyari_miktari AS TEXT), '') || ' ' ||
          COALESCE(CAST(p.stok AS TEXT), '') || ' ' ||
          COALESCE(CAST(p.kdv_orani AS TEXT), '') || ' ' ||
          CASE WHEN COALESCE(p.aktif_mi, 0) = 1 THEN 'aktif' ELSE 'pasif' END
        )
        FROM todo
        WHERE p.id = todo.id
        RETURNING p.id
      '''),
      parameters: {'afterId': afterId},
    );
    if (rows.isEmpty) break;
    final last = rows.last[0];
    afterId = int.tryParse(last?.toString() ?? '') ?? afterId;
  }

  print('products: trigger+backfill OK');
}

Future<void> _finalizeCurrentAccounts(Connection conn) async {
  if (!await _tableExists(conn, 'current_accounts')) {
    print('current_accounts: skip');
    return;
  }

  await _bestEffort(conn, '''
    CREATE OR REPLACE FUNCTION update_current_account_search_tags()
    RETURNS TRIGGER AS \$\$
    BEGIN
      NEW.search_tags = normalize_text(
        COALESCE(NEW.kod_no, '') || ' ' ||
        COALESCE(NEW.adi, '') || ' ' ||
        COALESCE(NEW.hesap_turu, '') || ' ' ||
        CAST(NEW.id AS TEXT) || ' ' ||
        CASE WHEN COALESCE(NEW.aktif_mi, 0) = 1 THEN 'aktif' ELSE 'pasif' END || ' ' ||
        COALESCE(CAST(NEW.bakiye_borc AS TEXT), '') || ' ' ||
        COALESCE(CAST(NEW.bakiye_alacak AS TEXT), '') || ' ' ||
        COALESCE(NEW.fat_unvani, '') || ' ' ||
        COALESCE(NEW.fat_adresi, '') || ' ' ||
        COALESCE(NEW.fat_ilce, '') || ' ' ||
        COALESCE(NEW.fat_sehir, '') || ' ' ||
        COALESCE(NEW.posta_kodu, '') || ' ' ||
        COALESCE(NEW.v_dairesi, '') || ' ' ||
        COALESCE(NEW.v_numarasi, '') || ' ' ||
        COALESCE(NEW.sf_grubu, '') || ' ' ||
        COALESCE(CAST(NEW.s_iskonto AS TEXT), '') || ' ' ||
        COALESCE(CAST(NEW.vade_gun AS TEXT), '') || ' ' ||
        COALESCE(CAST(NEW.risk_limiti AS TEXT), '') || ' ' ||
        COALESCE(NEW.para_birimi, '') || ' ' ||
        COALESCE(NEW.bakiye_durumu, '') || ' ' ||
        COALESCE(NEW.telefon1, '') || ' ' ||
        COALESCE(NEW.telefon2, '') || ' ' ||
        COALESCE(NEW.eposta, '') || ' ' ||
        COALESCE(NEW.web_adresi, '') || ' ' ||
        COALESCE(NEW.bilgi1, '') || ' ' ||
        COALESCE(NEW.bilgi2, '') || ' ' ||
        COALESCE(NEW.bilgi3, '') || ' ' ||
        COALESCE(NEW.bilgi4, '') || ' ' ||
        COALESCE(NEW.bilgi5, '') || ' ' ||
        COALESCE(NEW.sevk_adresleri, '') || ' ' ||
        COALESCE(NEW.renk, '') || ' ' ||
        COALESCE(NEW.created_by, '')
      );
      RETURN NEW;
    END;
    \$\$ LANGUAGE plpgsql
  ''');
  await _bestEffort(
    conn,
    'DROP TRIGGER IF EXISTS trg_update_current_account_search_tags ON current_accounts',
  );
  await _bestEffort(conn, '''
    CREATE TRIGGER trg_update_current_account_search_tags
    BEFORE INSERT OR UPDATE ON current_accounts
    FOR EACH ROW EXECUTE FUNCTION update_current_account_search_tags()
  ''');

  var afterId = 0;
  while (true) {
    final rows = await conn.execute(
      Sql.named('''
        WITH todo AS (
          SELECT id
          FROM current_accounts
          WHERE id > @afterId
          ORDER BY id ASC
          LIMIT 5000
        )
        UPDATE current_accounts ca
        SET search_tags = normalize_text(
          COALESCE(ca.kod_no, '') || ' ' ||
          COALESCE(ca.adi, '') || ' ' ||
          COALESCE(ca.hesap_turu, '') || ' ' ||
          CAST(ca.id AS TEXT) || ' ' ||
          CASE WHEN COALESCE(ca.aktif_mi, 0) = 1 THEN 'aktif' ELSE 'pasif' END || ' ' ||
          COALESCE(CAST(ca.bakiye_borc AS TEXT), '') || ' ' ||
          COALESCE(CAST(ca.bakiye_alacak AS TEXT), '') || ' ' ||
          COALESCE(ca.fat_unvani, '') || ' ' ||
          COALESCE(ca.fat_adresi, '') || ' ' ||
          COALESCE(ca.fat_ilce, '') || ' ' ||
          COALESCE(ca.fat_sehir, '') || ' ' ||
          COALESCE(ca.posta_kodu, '') || ' ' ||
          COALESCE(ca.v_dairesi, '') || ' ' ||
          COALESCE(ca.v_numarasi, '') || ' ' ||
          COALESCE(ca.sf_grubu, '') || ' ' ||
          COALESCE(CAST(ca.s_iskonto AS TEXT), '') || ' ' ||
          COALESCE(CAST(ca.vade_gun AS TEXT), '') || ' ' ||
          COALESCE(CAST(ca.risk_limiti AS TEXT), '') || ' ' ||
          COALESCE(ca.para_birimi, '') || ' ' ||
          COALESCE(ca.bakiye_durumu, '') || ' ' ||
          COALESCE(ca.telefon1, '') || ' ' ||
          COALESCE(ca.telefon2, '') || ' ' ||
          COALESCE(ca.eposta, '') || ' ' ||
          COALESCE(ca.web_adresi, '') || ' ' ||
          COALESCE(ca.bilgi1, '') || ' ' ||
          COALESCE(ca.bilgi2, '') || ' ' ||
          COALESCE(ca.bilgi3, '') || ' ' ||
          COALESCE(ca.bilgi4, '') || ' ' ||
          COALESCE(ca.bilgi5, '') || ' ' ||
          COALESCE(ca.sevk_adresleri, '') || ' ' ||
          COALESCE(ca.renk, '') || ' ' ||
          COALESCE(ca.created_by, '')
        )
        FROM todo
        WHERE ca.id = todo.id
        RETURNING ca.id
      '''),
      parameters: {'afterId': afterId},
    );
    if (rows.isEmpty) break;
    final last = rows.last[0];
    afterId = int.tryParse(last?.toString() ?? '') ?? afterId;
  }

  print('current_accounts: trigger+backfill OK');
}

Future<void> _finalizeBankMetadata(Connection conn) async {
  if (!await _tableExists(conn, 'banks')) {
    print('bank_metadata: skip');
    return;
  }

  await _bestEffort(conn, '''
    CREATE TABLE IF NOT EXISTS bank_metadata (
      type TEXT NOT NULL,
      value TEXT NOT NULL,
      frequency BIGINT DEFAULT 1,
      PRIMARY KEY (type, value)
    )
  ''');
  await _bestEffort(conn, '''
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
    \$\$ LANGUAGE plpgsql
  ''');
  await _bestEffort(
    conn,
    'DROP TRIGGER IF EXISTS trg_update_bank_metadata ON banks',
  );
  await _bestEffort(conn, '''
    CREATE TRIGGER trg_update_bank_metadata
    AFTER INSERT OR UPDATE OR DELETE ON banks
    FOR EACH ROW EXECUTE FUNCTION update_bank_metadata()
  ''');
  await _bestEffort(conn, 'TRUNCATE TABLE bank_metadata');
  await _bestEffort(conn, '''
    INSERT INTO bank_metadata (type, value, frequency)
    SELECT 'currency', currency, COUNT(*)::BIGINT
    FROM banks
    WHERE COALESCE(currency, '') != ''
    GROUP BY currency
  ''');
  print('bank_metadata: trigger+backfill OK');
}

Future<void> _migrateChequeTransactions(Connection conn) async {
  await _migratePartitionedTable(
    conn,
    table: 'cheque_transactions',
    oldTable: 'cheque_transactions_old',
    dateColumn: 'date',
    parentCreateSql: '''
      CREATE TABLE IF NOT EXISTS cheque_transactions (
        id BIGSERIAL,
        company_id TEXT,
        cheque_id BIGINT,
        date TIMESTAMP NOT NULL,
        description TEXT,
        amount NUMERIC(15, 2) DEFAULT 0,
        type TEXT,
        source_dest TEXT,
        user_name TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        search_tags TEXT NOT NULL DEFAULT '',
        integration_ref TEXT,
        PRIMARY KEY (id, date)
      ) PARTITION BY RANGE (date)
    ''',
    insertSql: '''
      INSERT INTO cheque_transactions (
        id,
        company_id,
        cheque_id,
        date,
        description,
        amount,
        type,
        source_dest,
        user_name,
        created_at,
        search_tags,
        integration_ref
      )
      SELECT
        id,
        company_id,
        cheque_id,
        COALESCE(date, created_at, CURRENT_TIMESTAMP),
        description,
        amount,
        type,
        source_dest,
        user_name,
        created_at,
        COALESCE(search_tags, ''),
        integration_ref
      FROM cheque_transactions_old
      ORDER BY id ASC
    ''',
    indexStatements: const <String>[
      'CREATE INDEX IF NOT EXISTS idx_cheque_transactions_cheque_id ON cheque_transactions (cheque_id)',
      'CREATE INDEX IF NOT EXISTS idx_cheque_transactions_date ON cheque_transactions (date)',
      'CREATE INDEX IF NOT EXISTS idx_cheque_transactions_search_tags_gin ON cheque_transactions USING GIN (search_tags gin_trgm_ops)',
    ],
  );
}

Future<void> _migrateNoteTransactions(Connection conn) async {
  await _migratePartitionedTable(
    conn,
    table: 'note_transactions',
    oldTable: 'note_transactions_old',
    dateColumn: 'date',
    parentCreateSql: '''
      CREATE TABLE IF NOT EXISTS note_transactions (
        id BIGSERIAL,
        company_id TEXT,
        note_id BIGINT,
        date TIMESTAMP NOT NULL,
        description TEXT,
        amount NUMERIC(15, 2) DEFAULT 0,
        type TEXT,
        source_dest TEXT,
        user_name TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        search_tags TEXT NOT NULL DEFAULT '',
        integration_ref TEXT,
        PRIMARY KEY (id, date)
      ) PARTITION BY RANGE (date)
    ''',
    insertSql: '''
      INSERT INTO note_transactions (
        id,
        company_id,
        note_id,
        date,
        description,
        amount,
        type,
        source_dest,
        user_name,
        created_at,
        search_tags,
        integration_ref
      )
      SELECT
        id,
        company_id,
        note_id,
        COALESCE(date, created_at, CURRENT_TIMESTAMP),
        description,
        amount,
        type,
        source_dest,
        user_name,
        created_at,
        COALESCE(search_tags, ''),
        integration_ref
      FROM note_transactions_old
      ORDER BY id ASC
    ''',
    indexStatements: const <String>[
      'CREATE INDEX IF NOT EXISTS idx_note_transactions_note_id ON note_transactions (note_id)',
      'CREATE INDEX IF NOT EXISTS idx_note_transactions_date ON note_transactions (date)',
      'CREATE INDEX IF NOT EXISTS idx_note_transactions_search_tags_gin ON note_transactions USING GIN (search_tags gin_trgm_ops)',
    ],
  );
}

Future<void> _migrateExpenseItems(Connection conn) async {
  await _migratePartitionedTable(
    conn,
    table: 'expense_items',
    oldTable: 'expense_items_old',
    dateColumn: 'created_at',
    parentCreateSql: '''
      CREATE TABLE IF NOT EXISTS expense_items (
        id BIGSERIAL,
        expense_id BIGINT NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
        aciklama TEXT DEFAULT '',
        tutar NUMERIC DEFAULT 0,
        not_metni TEXT DEFAULT '',
        search_tags TEXT NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id, created_at)
      ) PARTITION BY RANGE (created_at)
    ''',
    insertSql: '''
      INSERT INTO expense_items (
        id,
        expense_id,
        aciklama,
        tutar,
        not_metni,
        search_tags,
        created_at
      )
      SELECT
        id,
        expense_id,
        aciklama,
        tutar,
        COALESCE(not_metni, ''),
        COALESCE(search_tags, ''),
        COALESCE(created_at, CURRENT_TIMESTAMP)
      FROM expense_items_old
      ORDER BY id ASC
    ''',
    indexStatements: const <String>[
      'CREATE INDEX IF NOT EXISTS idx_expense_items_expense_id ON expense_items (expense_id)',
      'CREATE INDEX IF NOT EXISTS idx_expense_items_created_at ON expense_items (created_at)',
      'CREATE INDEX IF NOT EXISTS idx_expense_items_search_tags_gin ON expense_items USING GIN (search_tags gin_trgm_ops)',
    ],
  );
}

Future<void> _migratePartitionedTable(
  Connection conn, {
  required String table,
  required String oldTable,
  required String dateColumn,
  required String parentCreateSql,
  required String insertSql,
  required List<String> indexStatements,
}) async {
  if (!await _tableExists(conn, table)) {
    await _bestEffort(conn, parentCreateSql);
    await _ensureDefaultPartition(conn, table);
    await _ensureCurrentMonthPartition(conn, table, dateColumn: dateColumn);
    for (final sql in indexStatements) {
      await _bestEffort(conn, sql);
    }
    print('$table: create OK');
    return;
  }

  final relkind = await _tableRelkind(conn, table);
  if (relkind == 'p') {
    await _ensureDefaultPartition(conn, table);
    await _ensureCurrentMonthPartition(conn, table, dateColumn: dateColumn);
    for (final sql in indexStatements) {
      await _bestEffort(conn, sql);
    }
    print('$table: already partitioned');
    return;
  }

  await _bestEffort(conn, 'DROP TABLE IF EXISTS $oldTable CASCADE');
  await _bestEffort(conn, 'ALTER TABLE $table RENAME TO $oldTable');
  try {
    await conn.execute(
      'ALTER SEQUENCE IF EXISTS ${table}_id_seq RENAME TO ${oldTable}_id_seq',
    );
  } catch (_) {}

  await _bestEffort(conn, parentCreateSql);
  await _ensureDefaultPartition(conn, table);
  await _ensurePartitionsFromOldRange(
    conn,
    table: table,
    oldTable: oldTable,
    dateColumn: dateColumn,
  );
  await _bestEffort(conn, insertSql);

  try {
    final maxIdRes = await conn.execute(
      'SELECT COALESCE(MAX(id), 0) FROM $table',
    );
    final maxId = maxIdRes.first[0];
    if (maxId != null) {
      await conn.execute(
        "SELECT setval(pg_get_serial_sequence('$table', 'id'), $maxId)",
      );
    }
  } catch (_) {}

  for (final sql in indexStatements) {
    await _bestEffort(conn, sql);
  }

  await _bestEffort(conn, 'DROP TABLE $oldTable CASCADE');
  print('$table: migrated OK');
}

Future<void> _runBenchmarks(Connection conn, {required String database}) async {
  final benches = <Map<String, String>>[
    {
      'table': 'products',
      'sql':
          "SELECT id FROM products WHERE (to_tsvector('simple'::regconfig, COALESCE(search_tags, '')) @@ plainto_tsquery('simple'::regconfig, @fts) OR COALESCE(search_tags, '') % @trgm) ORDER BY id DESC LIMIT 25",
    },
    {
      'table': 'current_accounts',
      'sql':
          "SELECT id FROM current_accounts WHERE (to_tsvector('simple'::regconfig, COALESCE(search_tags, '')) @@ plainto_tsquery('simple'::regconfig, @fts) OR COALESCE(search_tags, '') % @trgm) ORDER BY id DESC LIMIT 25",
    },
    {
      'table': 'banks',
      'sql':
          "SELECT id FROM banks WHERE (to_tsvector('simple'::regconfig, COALESCE(search_tags, '')) @@ plainto_tsquery('simple'::regconfig, @fts) OR COALESCE(search_tags, '') % @trgm) ORDER BY id DESC LIMIT 25",
    },
    {
      'table': 'depots',
      'sql':
          "SELECT id FROM depots WHERE (to_tsvector('simple'::regconfig, COALESCE(search_tags, '')) @@ plainto_tsquery('simple'::regconfig, @fts) OR COALESCE(search_tags, '') % @trgm) ORDER BY id DESC LIMIT 25",
    },
  ];

  for (final bench in benches) {
    final table = bench['table']!;
    if (!await _tableExists(conn, table)) continue;
    final token = await _sampleSearchToken(conn, table);
    if (token == null) {
      print('benchmark $table: skip (token yok)');
      continue;
    }

    try {
      final result = await conn.execute(
        Sql.named('EXPLAIN (ANALYZE, BUFFERS) ${bench['sql']}'),
        parameters: {'fts': token, 'trgm': token},
      );
      final lines = result.map((row) => row[0].toString()).toList();
      final summary = lines.take(3).join(' | ');
      print('benchmark $table: token=$token');
      print('  $summary');
    } catch (e) {
      print('benchmark $table: err=$e');
    }
  }

  print('benchmark_db=$database done');
}

Future<void> _reportTuningProfile(Connection conn) async {
  final profile = await PostgresTuningProfile.detect(
    maxConnections: _targetMaxConnections(),
  );
  print(
    'tuning_profile memory_mb=${profile.totalMemoryMb} cpu=${profile.cpuCount} max_conn=${profile.maxConnections}',
  );
  for (final setting in profile.settings) {
    final current = await _showSettingBestEffort(conn, setting.key);
    final status = current == null
        ? 'UNREADABLE'
        : _normalizeSetting(current) == _normalizeSetting(setting.value)
        ? 'OK'
        : 'DIFF';
    final currentLabel = current ?? '?';
    print(
      '  ${setting.key}: current=$currentLabel target=${setting.value} status=$status',
    );
  }
}

Future<String?> _sampleSearchToken(Connection conn, String table) async {
  try {
    final rows = await conn.execute('''
      SELECT search_tags
      FROM $table
      WHERE COALESCE(search_tags, '') != ''
      LIMIT 25
    ''');
    for (final row in rows) {
      final raw = row[0]?.toString() ?? '';
      final parts = raw
          .split(RegExp(r'\s+'))
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.length >= 3 && !e.startsWith('v'))
          .toList();
      if (parts.isNotEmpty) return parts.first;
    }
  } catch (_) {}
  return null;
}

Future<void> _ensureNormalizeText(Connection conn) async {
  await _bestEffort(conn, '''
    CREATE OR REPLACE FUNCTION normalize_text(val TEXT) RETURNS TEXT AS \$\$
    BEGIN
      IF val IS NULL THEN RETURN ''; END IF;
      val := REPLACE(val, 'i̇', 'i');
      RETURN LOWER(TRANSLATE(val, 'ÇĞİÖŞÜIçğıöşü', 'cgiosuicgiosu'));
    END;
    \$\$ LANGUAGE plpgsql IMMUTABLE
  ''');
}

Future<void> _ensureDefaultPartition(Connection conn, String table) async {
  await _bestEffort(
    conn,
    'CREATE TABLE IF NOT EXISTS ${table}_default PARTITION OF $table DEFAULT',
  );
}

Future<void> _ensureCurrentMonthPartition(
  Connection conn,
  String table, {
  required String dateColumn,
}) async {
  final now = DateTime.now();
  await _ensureMonthPartition(
    conn,
    table: table,
    dateColumn: dateColumn,
    year: now.year,
    month: now.month,
  );
}

Future<void> _ensurePartitionsFromOldRange(
  Connection conn, {
  required String table,
  required String oldTable,
  required String dateColumn,
}) async {
  try {
    final rangeRes = await conn.execute('''
      SELECT
        MIN(COALESCE($dateColumn, CURRENT_TIMESTAMP)),
        MAX(COALESCE($dateColumn, CURRENT_TIMESTAMP))
      FROM $oldTable
    ''');
    if (rangeRes.isEmpty) return;
    final minRaw = rangeRes.first[0];
    final maxRaw = rangeRes.first[1];
    final minDate = _asDateTime(minRaw);
    final maxDate = _asDateTime(maxRaw);
    if (minDate == null || maxDate == null) return;

    var cursor = DateTime(minDate.year, minDate.month, 1);
    final end = DateTime(maxDate.year, maxDate.month, 1);
    while (!cursor.isAfter(end)) {
      await _ensureMonthPartition(
        conn,
        table: table,
        dateColumn: dateColumn,
        year: cursor.year,
        month: cursor.month,
      );
      cursor = cursor.month == 12
          ? DateTime(cursor.year + 1, 1, 1)
          : DateTime(cursor.year, cursor.month + 1, 1);
    }
  } catch (_) {}
}

Future<void> _ensureMonthPartition(
  Connection conn, {
  required String table,
  required String dateColumn,
  required int year,
  required int month,
}) async {
  final monthStr = month.toString().padLeft(2, '0');
  final start = DateTime(year, month, 1);
  final end = month == 12
      ? DateTime(year + 1, 1, 1)
      : DateTime(year, month + 1, 1);
  final startStr =
      '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-01 00:00:00';
  final endStr =
      '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-01 00:00:00';
  await _bestEffort(
    conn,
    "CREATE TABLE IF NOT EXISTS ${table}_y${year}_m$monthStr PARTITION OF $table FOR VALUES FROM ('$startStr') TO ('$endStr')",
  );
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
    if (!await _tableExists(conn, 'company_settings')) return const <String>[];
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

Future<bool> _tableExists(Session executor, String table) async {
  try {
    final res = await executor.execute(
      Sql.named('''
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = @table
        LIMIT 1
      '''),
      parameters: {'table': table},
    );
    return res.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<String?> _tableRelkind(Session executor, String table) async {
  try {
    final res = await executor.execute(
      Sql.named(
        'SELECT relkind::text FROM pg_class WHERE relname = @table LIMIT 1',
      ),
      parameters: {'table': table},
    );
    if (res.isEmpty) return null;
    return res.first[0]?.toString().toLowerCase();
  } catch (_) {
    return null;
  }
}

Future<_VersionInfo> _serverVersion(Session executor) async {
  final rows = await executor.execute(
    'SELECT current_setting(\'server_version\'), current_setting(\'server_version_num\')',
  );
  final text = rows.first[0]?.toString() ?? 'unknown';
  final num = int.tryParse(rows.first[1]?.toString() ?? '') ?? 0;
  return _VersionInfo(text: text, num: num);
}

Future<String?> _showSettingBestEffort(Session executor, String key) async {
  try {
    final rows = await executor.execute('SHOW $key');
    if (rows.isEmpty) return null;
    return rows.first[0]?.toString().trim();
  } catch (_) {
    return null;
  }
}

String _normalizeSetting(String value) {
  return value.trim().toLowerCase().replaceAll(' ', '');
}

int _targetMaxConnections() {
  final raw = (Platform.environment['PATISYO_DB_MAX_CONNECTIONS'] ?? '').trim();
  return int.tryParse(raw) ?? 20;
}

Future<void> _bestEffort(Session executor, String sql) async {
  try {
    await executor.execute(sql);
  } catch (_) {}
}

DateTime? _asDateTime(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString());
}

String _companyDbName(String companyCode) {
  final trimmed = companyCode.trim();
  if (trimmed == _defaultDb) return _defaultDb;
  final safe = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
  return safe.isEmpty ? _defaultDb : 'patisyo_$safe';
}

String? _parseValueArg(List<String> args, String key) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == key && i + 1 < args.length) return args[i + 1];
    if (args[i].startsWith('$key=')) {
      return args[i].substring(key.length + 1);
    }
  }
  return null;
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

final class _VersionInfo {
  const _VersionInfo({required this.text, required this.num});

  final String text;
  final int num;
}
