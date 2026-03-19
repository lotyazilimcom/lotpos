import 'dart:io';

import 'package:postgres/postgres.dart';

/// BIGINT ŞEMA MİGRASYON SERVİSİ (CLI)
///
/// Amaç:
/// - Eski kurulumlarda SERIAL/INTEGER PK ve ilgili FK sütunlarını BIGINT'e yükseltmek.
/// - 100B/20y hedefinde id taşması ve tip-uyumsuz FK problemlerini önlemek.
///
/// ÖNEMLİ:
/// - Bu işlem bazı tablolarda table rewrite + index rebuild yapar.
/// - Büyük tablolarda uzun sürebilir ve kilit alır. Bakım penceresinde çalıştırın.
///
/// ÇALIŞTIRMA:
///   # Sadece planı yazdırır (execute yok)
///   dart lib/servisler/veritabani_bigint_migrasyon_servisi.dart
///
///   # Gerçekten uygula
///   LOSPOS_BIGINT_MIGRATE_EXECUTE=1 dart lib/servisler/veritabani_bigint_migrasyon_servisi.dart
///
/// ENV:
/// - LOSPOS_DB_HOST, LOSPOS_DB_PORT, LOSPOS_DB_USER, LOSPOS_DB_PASSWORD
/// - LOSPOS_DB_SSLMODE=require|disable (opsiyonel)
/// - LOSPOS_BIGINT_MIGRATE_DATABASES="db1,db2" (opsiyonel; yoksa LOSPOS_DB_NAME kullanılır)
/// - LOSPOS_BIGINT_MIGRATE_EXECUTE=1 (opsiyonel; yoksa sadece rapor)
///
void main() async {
  final svc = _BigintMigrator();
  await svc.run();
}

final class _BigintMigrator {
  final String host = (Platform.environment['LOSPOS_DB_HOST'] ?? '127.0.0.1')
      .trim();
  final int port =
      int.tryParse((Platform.environment['LOSPOS_DB_PORT'] ?? '').trim()) ??
      5432;
  final String username = (Platform.environment['LOSPOS_DB_USER'] ?? 'lospos')
      .trim();
  final String password = (Platform.environment['LOSPOS_DB_PASSWORD'] ?? '')
      .trim();

  final bool execute =
      (Platform.environment['LOSPOS_BIGINT_MIGRATE_EXECUTE'] ?? '')
          .trim()
          .toLowerCase()
          .let((v) => v == '1' || v == 'true' || v == 'yes' || v == 'on');

  SslMode get sslMode {
    final raw = (Platform.environment['LOSPOS_DB_SSLMODE'] ?? '')
        .trim()
        .toLowerCase();
    if (raw == 'disable') return SslMode.disable;
    if (raw == 'require') return SslMode.require;
    final h = host.toLowerCase();
    final local = h == '127.0.0.1' || h == 'localhost' || h == '::1';
    return local ? SslMode.disable : SslMode.require;
  }

  List<String> _targetDbs() {
    final raw = (Platform.environment['LOSPOS_BIGINT_MIGRATE_DATABASES'] ?? '')
        .trim();
    if (raw.isNotEmpty) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }
    final fallback =
        (Platform.environment['LOSPOS_DB_NAME'] ?? 'lospossettings').trim();
    return fallback.isEmpty ? const <String>[] : <String>[fallback];
  }

  Future<void> run() async {
    final dbs = _targetDbs();
    if (dbs.isEmpty) {
      stderr.writeln(
        'Hedef veritabanı bulunamadı. LOSPOS_DB_NAME veya LOSPOS_BIGINT_MIGRATE_DATABASES ayarlayın.',
      );
      exitCode = 64;
      return;
    }

    if (password.isEmpty) {
      stderr.writeln('LOSPOS_DB_PASSWORD zorunludur (CLI migrasyon).');
      exitCode = 64;
      return;
    }

    stdout.writeln('BIGINT migrasyon modu: ${execute ? 'EXECUTE' : 'DRY-RUN'}');
    stdout.writeln('Host: $host:$port, User: $username, SSL: $sslMode');
    stdout.writeln('DBs: ${dbs.join(', ')}');

    for (final db in dbs) {
      await _migrateDatabase(db);
    }
  }

  Future<Connection> _open(String database) {
    return Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      ),
      settings: ConnectionSettings(
        sslMode: sslMode,
        connectTimeout: const Duration(seconds: 10),
        queryMode: QueryMode.extended,
        onOpen: (c) async {
          try {
            await c.execute('SET statement_timeout TO 0');
          } catch (_) {}
        },
      ),
    );
  }

  Future<void> _migrateDatabase(String database) async {
    stdout.writeln('\n=== DB: $database ===');
    Connection? conn;
    try {
      conn = await _open(database);

      final pkCols = await _findSerialIntPkColumns(conn);
      if (pkCols.isEmpty) {
        stdout.writeln('✔️ Aday SERIAL/INT PK bulunamadı (skip).');
        return;
      }

      final fkConstraints = await _findFkConstraints(conn);

      final pkSet = pkCols
          .map((c) => '${c.schema}.${c.table}.${c.column}')
          .toSet();
      final constraintsToDrop = <_FkConstraint>[];
      final columnsToAlter = <_Col>{...pkCols};

      for (final fk in fkConstraints) {
        bool touches = false;
        for (final pair in fk.pairs) {
          final parentKey =
              '${pair.parentSchema}.${pair.parentTable}.${pair.parentColumn}';
          if (pkSet.contains(parentKey)) {
            touches = true;
            columnsToAlter.add(
              _Col(
                schema: pair.childSchema,
                table: pair.childTable,
                column: pair.childColumn,
              ),
            );
          }
        }
        if (touches) constraintsToDrop.add(fk);
      }

      // Sadece gerçekten INT4 olan sütunları alter et (kısmi geçişlerde no-op kilitleri azaltır).
      final int4Only = <_Col>{};
      for (final c in columnsToAlter) {
        if (await _isInt4(conn, c)) {
          int4Only.add(c);
        }
      }
      columnsToAlter
        ..clear()
        ..addAll(int4Only);

      stdout.writeln('PK INT→BIGINT: ${pkCols.length}');
      stdout.writeln(
        'FK constraint drop/recreate: ${constraintsToDrop.length}',
      );
      stdout.writeln('Toplam sütun alter: ${columnsToAlter.length}');

      final sqlPlan = <String>[
        'BEGIN;',
        ...constraintsToDrop.map(
          (c) =>
              'ALTER TABLE ${_qTable(c.childSchema, c.childTable)} DROP CONSTRAINT ${_qIdent(c.name)};',
        ),
        ...columnsToAlter.map(
          (c) =>
              'ALTER TABLE ${_qTable(c.schema, c.table)} ALTER COLUMN ${_qIdent(c.column)} TYPE BIGINT;',
        ),
        ...constraintsToDrop.map(
          (c) =>
              'ALTER TABLE ${_qTable(c.childSchema, c.childTable)} ADD CONSTRAINT ${_qIdent(c.name)} ${c.definition};',
        ),
        'COMMIT;',
      ];

      if (!execute) {
        for (final s in sqlPlan) {
          stdout.writeln(s);
        }
        return;
      }

      await conn.execute('BEGIN');
      try {
        for (final c in constraintsToDrop) {
          await conn.execute(
            'ALTER TABLE ${_qTable(c.childSchema, c.childTable)} DROP CONSTRAINT ${_qIdent(c.name)};',
          );
        }

        for (final col in columnsToAlter) {
          await conn.execute(
            'ALTER TABLE ${_qTable(col.schema, col.table)} ALTER COLUMN ${_qIdent(col.column)} TYPE BIGINT;',
          );
        }

        for (final c in constraintsToDrop) {
          await conn.execute(
            'ALTER TABLE ${_qTable(c.childSchema, c.childTable)} ADD CONSTRAINT ${_qIdent(c.name)} ${c.definition};',
          );
        }

        await conn.execute('COMMIT');
        stdout.writeln('✅ Migrasyon tamamlandı.');
      } catch (e) {
        try {
          await conn.execute('ROLLBACK');
        } catch (_) {}
        rethrow;
      }
    } catch (e) {
      stderr.writeln('❌ Hata ($database): $e');
      exitCode = 1;
    } finally {
      try {
        await conn?.close();
      } catch (_) {}
    }
  }

  Future<List<_Col>> _findSerialIntPkColumns(Connection conn) async {
    final res = await conn.execute('''
      SELECT
        n.nspname::text AS schema_name,
        c.relname::text AS table_name,
        a.attname::text AS column_name,
        pg_get_expr(ad.adbin, ad.adrelid)::text AS default_expr
      FROM pg_constraint con
      JOIN pg_class c ON c.oid = con.conrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN unnest(con.conkey) WITH ORDINALITY AS k(attnum, ord) ON true
      JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = k.attnum
      LEFT JOIN pg_attrdef ad ON ad.adrelid = c.oid AND ad.adnum = a.attnum
      WHERE con.contype = 'p'
        AND n.nspname = 'public'
        AND a.atttypid = 'int4'::regtype
        AND (
          (ad.adbin IS NOT NULL AND pg_get_expr(ad.adbin, ad.adrelid) LIKE 'nextval(%')
          OR a.attidentity IN ('a','d')
        )
      ORDER BY n.nspname, c.relname, a.attname
    ''');

    final out = <_Col>[];
    for (final row in res) {
      final schema = (row[0] as String?)?.trim() ?? '';
      final table = (row[1] as String?)?.trim() ?? '';
      final col = (row[2] as String?)?.trim() ?? '';
      if (schema.isEmpty || table.isEmpty || col.isEmpty) continue;
      out.add(_Col(schema: schema, table: table, column: col));
    }
    return out;
  }

  Future<List<_FkConstraint>> _findFkConstraints(Connection conn) async {
    final res = await conn.execute('''
      SELECT
        c.oid::bigint AS constraint_oid,
        nc.nspname::text AS child_schema,
        cl.relname::text AS child_table,
        c.conname::text AS constraint_name,
        pg_get_constraintdef(c.oid)::text AS constraint_def,
        np.nspname::text AS parent_schema,
        pl.relname::text AS parent_table,
        array_agg(ac.attname::text ORDER BY k.ord) AS child_cols,
        array_agg(ap.attname::text ORDER BY k.ord) AS parent_cols
      FROM pg_constraint c
      JOIN pg_class cl ON cl.oid = c.conrelid
      JOIN pg_namespace nc ON nc.oid = cl.relnamespace
      JOIN pg_class pl ON pl.oid = c.confrelid
      JOIN pg_namespace np ON np.oid = pl.relnamespace
      JOIN unnest(c.conkey) WITH ORDINALITY AS k(attnum, ord) ON true
      JOIN pg_attribute ac ON ac.attrelid = cl.oid AND ac.attnum = k.attnum
      JOIN unnest(c.confkey) WITH ORDINALITY AS fk(attnum, ord) ON fk.ord = k.ord
      JOIN pg_attribute ap ON ap.attrelid = pl.oid AND ap.attnum = fk.attnum
      WHERE c.contype = 'f'
        AND nc.nspname = 'public'
        AND np.nspname = 'public'
      GROUP BY 1,2,3,4,5,6,7
      ORDER BY 2,3,4
    ''');

    final out = <_FkConstraint>[];
    for (final row in res) {
      final childSchema = (row[1] as String?)?.trim() ?? '';
      final childTable = (row[2] as String?)?.trim() ?? '';
      final name = (row[3] as String?)?.trim() ?? '';
      final def = (row[4] as String?)?.trim() ?? '';
      final parentSchema = (row[5] as String?)?.trim() ?? '';
      final parentTable = (row[6] as String?)?.trim() ?? '';
      final childCols = (row[7] as List?)?.cast<String>() ?? const <String>[];
      final parentCols = (row[8] as List?)?.cast<String>() ?? const <String>[];
      if (childSchema.isEmpty ||
          childTable.isEmpty ||
          name.isEmpty ||
          def.isEmpty ||
          parentSchema.isEmpty ||
          parentTable.isEmpty ||
          childCols.isEmpty ||
          parentCols.isEmpty ||
          childCols.length != parentCols.length) {
        continue;
      }

      final pairs = <_FkPair>[];
      for (var i = 0; i < childCols.length; i++) {
        pairs.add(
          _FkPair(
            childSchema: childSchema,
            childTable: childTable,
            childColumn: childCols[i],
            parentSchema: parentSchema,
            parentTable: parentTable,
            parentColumn: parentCols[i],
          ),
        );
      }
      out.add(
        _FkConstraint(
          childSchema: childSchema,
          childTable: childTable,
          name: name,
          definition: def,
          pairs: pairs,
        ),
      );
    }
    return out;
  }

  Future<bool> _isInt4(Connection conn, _Col c) async {
    final res = await conn.execute(
      Sql.named('''
        SELECT (a.atttypid = 'int4'::regtype) AS is_int4
        FROM pg_attribute a
        JOIN pg_class cl ON cl.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = cl.relnamespace
        WHERE n.nspname = @schema
          AND cl.relname = @table
          AND a.attname = @col
          AND a.attnum > 0
          AND NOT a.attisdropped
        LIMIT 1
      '''),
      parameters: <String, Object?>{
        'schema': c.schema,
        'table': c.table,
        'col': c.column,
      },
    );
    if (res.isEmpty) return false;
    return res.first[0] == true;
  }
}

final class _Col {
  final String schema;
  final String table;
  final String column;
  const _Col({required this.schema, required this.table, required this.column});

  @override
  bool operator ==(Object other) =>
      other is _Col &&
      other.schema == schema &&
      other.table == table &&
      other.column == column;

  @override
  int get hashCode => Object.hash(schema, table, column);
}

final class _FkPair {
  final String childSchema;
  final String childTable;
  final String childColumn;
  final String parentSchema;
  final String parentTable;
  final String parentColumn;

  const _FkPair({
    required this.childSchema,
    required this.childTable,
    required this.childColumn,
    required this.parentSchema,
    required this.parentTable,
    required this.parentColumn,
  });
}

final class _FkConstraint {
  final String childSchema;
  final String childTable;
  final String name;
  final String definition;
  final List<_FkPair> pairs;

  const _FkConstraint({
    required this.childSchema,
    required this.childTable,
    required this.name,
    required this.definition,
    required this.pairs,
  });
}

String _qIdent(String v) => '"${v.replaceAll('"', '""')}"';

String _qTable(String schema, String table) =>
    '${_qIdent(schema)}.${_qIdent(table)}';

extension on String {
  T let<T>(T Function(String) fn) => fn(this);
}
