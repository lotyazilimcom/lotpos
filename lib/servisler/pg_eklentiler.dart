import 'package:postgres/postgres.dart';

import 'veritabani_yapilandirma.dart';

class PgEklentiler {
  static const String _ensurePgTrgmSql = '''
DO \$\$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
  WHEN unique_violation THEN
    NULL;
  WHEN insufficient_privilege THEN
    NULL;
  WHEN undefined_file THEN
    NULL;
  WHEN feature_not_supported THEN
    NULL;
  WHEN others THEN
    NULL;
END;
\$\$;
''';

  static Future<void> ensurePgTrgm(Session session) async {
    await session.execute(_ensurePgTrgmSql);
  }

  static const String _ensureCitusSql = '''
DO \$\$
BEGIN
  CREATE EXTENSION IF NOT EXISTS citus;
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
  WHEN unique_violation THEN
    NULL;
  WHEN insufficient_privilege THEN
    NULL;
  WHEN undefined_file THEN
    NULL;
  WHEN feature_not_supported THEN
    NULL;
  WHEN others THEN
    NULL;
END;
\$\$;
''';

  static Future<void> ensureCitus(Session session) async {
    if (!VeritabaniYapilandirma().allowCitusExtension) return;
    await session.execute(_ensureCitusSql);
  }

  static final RegExp _safeIdent = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

  static String _qi(String ident) {
    final v = ident.trim();
    if (v.isEmpty || !_safeIdent.hasMatch(v)) {
      throw ArgumentError.value(ident, 'ident', 'Unsafe identifier');
    }
    return '"$v"';
  }

  static String _qt(String table) => _qi(table);

  static Future<bool> hasExtension(Session executor, String extName) async {
    final e = extName.trim();
    if (e.isEmpty) return false;
    try {
      final res = await executor.execute(
        Sql.named('SELECT 1 FROM pg_extension WHERE extname = @e LIMIT 1'),
        parameters: {'e': e},
      );
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasIndex(Session executor, String indexName) async {
    final i = indexName.trim();
    if (i.isEmpty) return false;
    try {
      final res = await executor.execute(
        Sql.named(r'''
          SELECT 1
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'public'
            AND c.relkind IN ('i', 'I')
            AND c.relname = @i
          LIMIT 1
        '''),
        parameters: {'i': i},
      );
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isCitusTable(Session executor, String table) async {
    final t = table.trim();
    if (t.isEmpty) return false;
    try {
      final res = await executor.execute(
        Sql.named(r'''
          SELECT 1
          FROM pg_dist_partition
          WHERE logicalrelid = to_regclass(@t)
          LIMIT 1
        '''),
        parameters: {'t': 'public.$t'},
      );
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> ensureDistributedTable(
    Session executor, {
    required String table,
    required String distributionColumn,
    String? colocateWith,
  }) async {
    final t = table.trim();
    final d = distributionColumn.trim();
    if (t.isEmpty || d.isEmpty) return;
    if (!_safeIdent.hasMatch(t) || !_safeIdent.hasMatch(d)) return;
    if (!await hasExtension(executor, 'citus')) return;
    if (await isCitusTable(executor, t)) return;

    // `create_distributed_table` is idempotent only if the table is not already distributed.
    // We check pg_dist_partition above to avoid "already distributed" errors.
    final colocate = (colocateWith ?? '').trim();
    try {
      if (colocate.isEmpty) {
        await executor.execute(
          "SELECT create_distributed_table('public.$t', '$d')",
        );
        return;
      }
      if (!_safeIdent.hasMatch(colocate)) return;

      // Named arg uses := in SQL.
      await executor.execute(
        "SELECT create_distributed_table('public.$t', '$d', colocate_with := 'public.$colocate')",
      );
    } catch (_) {
      // Best-effort: Citus dağıtımı ortam/izin/kısıtlara göre başarısız olabilir.
      // Uygulama akışını bozma.
    }
  }

  static Future<List<String>> primaryKeyColumns(
    Session executor,
    String table,
  ) async {
    final t = table.trim();
    if (t.isEmpty) return const [];
    final res = await executor.execute(
      Sql.named(r'''
        SELECT a.attname::text
        FROM pg_index i
        JOIN pg_attribute a
          ON a.attrelid = i.indrelid
         AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = to_regclass(@table)
          AND i.indisprimary
        ORDER BY array_position(i.indkey, a.attnum)
      '''),
      parameters: {'table': 'public.$t'},
    );
    return res
        .map((r) => (r[0] as String?)?.trim() ?? '')
        .where((c) => c.isNotEmpty)
        .toList(growable: false);
  }

  /// DEFAULT partition'a yığılan satırları, mevcut partitionlara yeniden yönlendirir.
  ///
  /// - Partition key NULL olan satırlar taşınmaz (DEFAULT'ta kalır).
  /// - Partitionlar eksikse satırlar tekrar DEFAULT'a döneceği için önce partition aralığını oluşturun.
  static Future<int> moveRowsFromDefaultPartition({
    required Session executor,
    required String parentTable,
    required String defaultTable,
    required String partitionKeyColumn,
    List<String>? conflictColumns,
    int batchSize = 5000,
    int maxBatches = 200000,
  }) async {
    final parent = parentTable.trim();
    final def = defaultTable.trim();
    final key = partitionKeyColumn.trim();
    if (parent.isEmpty || def.isEmpty || key.isEmpty) return 0;

    final pkCols = (conflictColumns == null || conflictColumns.isEmpty)
        ? await primaryKeyColumns(executor, parent)
        : conflictColumns;

    final conflictSql = pkCols.isEmpty
        ? 'ON CONFLICT DO NOTHING'
        : 'ON CONFLICT (${pkCols.map(_qi).join(', ')}) DO NOTHING';

    var totalMoved = 0;
    for (var i = 0; i < maxBatches; i++) {
      final moved = await executor.execute(
        Sql.named('''
          WITH moved AS (
            DELETE FROM ${_qt(def)}
            WHERE ${_qi(key)} IS NOT NULL
              AND ctid IN (
                SELECT ctid
                FROM ${_qt(def)}
                WHERE ${_qi(key)} IS NOT NULL
                LIMIT @lim
              )
            RETURNING *
          ),
          ins AS (
            INSERT INTO ${_qt(parent)}
            SELECT * FROM moved
            $conflictSql
            RETURNING 1
          )
          SELECT COUNT(*)::bigint FROM ins
        '''),
        parameters: {'lim': batchSize},
      );

      if (moved.isEmpty) break;
      final c = moved.first[0];
      final movedCount = (c is int)
          ? c
          : int.tryParse(c?.toString() ?? '') ?? 0;
      if (movedCount <= 0) break;
      totalMoved += movedCount;
    }
    return totalMoved;
  }

  /// `search_tags` kolonunu standartlaştırır:
  /// - Yoksa ekler: `TEXT NOT NULL DEFAULT ''`
  /// - Varsa: DEFAULT'i garanti eder, NULL'ları temizler, NOT NULL'ı dener.
  ///
  /// Not: Büyük tablolarda `SET NOT NULL` tablo taraması yapabilir. Bu nedenle best-effort
  /// uygulanır; uygulama akışını bozmaz.
  static Future<void> ensureSearchTagsNotNullDefault(
    Session executor,
    String table, {
    String column = 'search_tags',
  }) async {
    final t = table.trim();
    final c = column.trim();
    if (t.isEmpty || c.isEmpty) return;

    // 1) Kolon yoksa ekle (PG11+ constant DEFAULT ile hızlıdır)
    await executor.execute(
      'ALTER TABLE ${_qt(t)} ADD COLUMN IF NOT EXISTS ${_qi(c)} TEXT NOT NULL DEFAULT \'\'',
    );

    // 2) DEFAULT'i garanti et
    try {
      await executor.execute(
        'ALTER TABLE ${_qt(t)} ALTER COLUMN ${_qi(c)} SET DEFAULT \'\'',
      );
    } catch (_) {}

    // 3) NULL temizliği (minimum)
    try {
      await executor.execute(
        'UPDATE ${_qt(t)} SET ${_qi(c)} = \'\' WHERE ${_qi(c)} IS NULL',
      );
    } catch (_) {}

    // 4) NOT NULL dene (best-effort)
    try {
      await executor.execute(
        'ALTER TABLE ${_qt(t)} ALTER COLUMN ${_qi(c)} SET NOT NULL',
      );
    } catch (_) {}
  }

  /// `search_tags` için trigram GIN indeksini garanti eder.
  static Future<void> ensureSearchTagsTrgmIndex(
    Session executor, {
    required String table,
    required String indexName,
    String column = 'search_tags',
  }) async {
    final t = table.trim();
    final i = indexName.trim();
    final c = column.trim();
    if (t.isEmpty || i.isEmpty || c.isEmpty) return;

    await ensurePgTrgm(executor);
    await executor.execute(
      'CREATE INDEX IF NOT EXISTS ${_qi(i)} ON ${_qt(t)} USING GIN (${_qi(c)} gin_trgm_ops)',
    );
  }

  static Future<bool> hasTrgmIndexForTableColumn(
    Session executor, {
    required String table,
    String column = 'search_tags',
  }) async {
    final t = table.trim();
    final c = column.trim();
    if (t.isEmpty || c.isEmpty) return false;
    try {
      final res = await executor.execute(
        Sql.named(r'''
          SELECT 1
          FROM pg_indexes
          WHERE schemaname = 'public'
            AND tablename = @t
            AND indexdef ILIKE @colPattern
            AND indexdef ILIKE '%gin_trgm_ops%'
          LIMIT 1
        '''),
        parameters: {'t': t, 'colPattern': '%$c%'},
      );
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> ensureCompositeIndex(
    Session executor, {
    required String table,
    required String indexName,
    required List<String> expressions,
  }) async {
    final t = table.trim();
    final i = indexName.trim();
    final exprs = expressions
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (t.isEmpty || i.isEmpty || exprs.isEmpty) return;
    await executor.execute(
      'CREATE INDEX IF NOT EXISTS ${_qi(i)} ON ${_qt(t)} (${exprs.join(', ')})',
    );
  }

  static Future<void> ensureBrinIndex(
    Session executor, {
    required String table,
    required String indexName,
    required String column,
    int pagesPerRange = 128,
  }) async {
    final t = table.trim();
    final i = indexName.trim();
    final c = column.trim();
    if (t.isEmpty || i.isEmpty || c.isEmpty) return;
    await executor.execute(
      'CREATE INDEX IF NOT EXISTS ${_qi(i)} ON ${_qt(t)} USING BRIN (${_qi(c)}) WITH (pages_per_range = $pagesPerRange)',
    );
  }

}
