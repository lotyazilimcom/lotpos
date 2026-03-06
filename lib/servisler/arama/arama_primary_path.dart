import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import '../oturum_servisi.dart';
import '../pg_eklentiler.dart';
import '../veritabani_havuzu.dart';

class AramaPrimaryPathResult<T> {
  final bool indexEnabled;
  final List<T> rows;

  const AramaPrimaryPathResult({
    required this.indexEnabled,
    required this.rows,
  });
}

@immutable
class _TableSearchSpec {
  final String table;
  final String rootIdColumn;

  const _TableSearchSpec({
    required this.table,
    required this.rootIdColumn,
  });
}

/// [2026] Index-primary arama akışı:
/// - Arama motorundan `root_id` adaylarını (cursor/keyset) çeker
/// - DB'de mevcut filtre/sıralama/expanded-search mantığını BOZMADAN
///   `sadeceIdler` ile sayfayı doldurur.
///
/// Not: Şimdilik sadece `root_id` sıralaması ile güvenli (ID sort) akış içindir.
class AramaPrimaryPath {
  static final RegExp _safeIdent = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');
  static const String _defaultCompanyId = 'patisyo2025';

  /// [100B] Partition pruning için tablo->tarih kolonu eşlemesi.
  /// Sadece arama akışında kullanılan kritik tablolar dahil edilmiştir.
  static const Map<String, String> _dateColumnByTable = <String, String>{
    // Partitioned transaction tables
    'bank_transactions': 'date',
    'cash_register_transactions': 'date',
    'credit_card_transactions': 'date',
    'current_account_transactions': 'date',
    // Root tables partitioned by date
    'orders': 'tarih',
    'quotes': 'tarih',
    // Root tables with date filters
    'expenses': 'tarih',
    // Movement / shipment semantics
    'shipments': 'date',
    'stock_movements': 'movement_date',
    'production_stock_movements': 'movement_date',
    // Notes / cheques
    'cheque_transactions': 'date',
    'note_transactions': 'date',
  };

  /// Bu tablolar tek DB içinde multi-tenant olabilir (company_id ile).
  static const Set<String> _tablesWithCompanyId = <String>{
    'banks',
    'bank_transactions',
    'cash_registers',
    'cash_register_transactions',
    'credit_cards',
    'credit_card_transactions',
    'cheques',
    'cheque_transactions',
    'promissory_notes',
    'note_transactions',
  };

  static ({DateTime? start, DateTime? endExclusive}) _normalizeDayRange(
    DateTime? start,
    DateTime? end,
  ) {
    DateTime? s;
    if (start != null) {
      s = DateTime(start.year, start.month, start.day);
    }
    DateTime? e;
    if (end != null) {
      e = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    }
    return (start: s, endExclusive: e);
  }

  static bool _isSafeIdent(String v) => _safeIdent.hasMatch(v.trim());

  static String _normalizeTurkish(String text) {
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

  static String _normalizeQuery(String q) {
    final v = _normalizeTurkish(q).trim();
    // Google-like UX: 1 harf araması 100B'de zaten patlar; ayrıca ngram(2,3) ile eşleşmez.
    return v;
  }

  static ({bool supported, bool ascending}) _parseRootIdSort(String sortBy) {
    final s = sortBy.trim().toLowerCase();
    if (s.isEmpty) return (supported: false, ascending: true);
    final parts = s.split(':').map((e) => e.trim()).toList(growable: false);
    if (parts.isEmpty) return (supported: false, ascending: true);
    if (parts.first != 'root_id') return (supported: false, ascending: true);
    if (parts.length == 1) return (supported: true, ascending: true);
    final dir = parts[1];
    if (dir == 'asc') return (supported: true, ascending: true);
    if (dir == 'desc') return (supported: true, ascending: false);
    return (supported: false, ascending: true);
  }

  static int? _parseCursorRootId(String? cursor) {
    final c = (cursor ?? '').trim();
    if (c.isEmpty) return null;
    return int.tryParse(c);
  }

  static int? _extractRootIdFilter(String? extraFilter) {
    final f = (extraFilter ?? '').trim();
    if (f.isEmpty) return null;
    final m = RegExp(r'\broot_id:(\d+)\b').firstMatch(f);
    if (m == null) return null;
    return int.tryParse(m.group(1) ?? '');
  }

  static String _bm25IndexNameForTable(String table) {
    final t = table.trim();
    return 'idx_${t}_search_tags_bm25';
  }

  static Future<Pool<void>?> _poolBestEffort() async {
    try {
      final dbName = OturumServisi().aktifVeritabaniAdi;
      return await VeritabaniHavuzu().havuzAl(database: dbName);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _isIndexReadyForTables(
    Session executor,
    List<String> tables,
  ) async {
    try {
      final hasPgSearch = await PgEklentiler.hasExtension(executor, 'pg_search');
      if (!hasPgSearch) return false;

      for (final tRaw in tables) {
        final t = tRaw.trim();
        if (t.isEmpty || !_isSafeIdent(t)) return false;
        final idx = _bm25IndexNameForTable(t);
        final ok =
            await PgEklentiler.hasIndex(executor, idx) ||
            await PgEklentiler.hasBm25IndexForTable(executor, t);
        if (!ok) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static List<_TableSearchSpec> _buildSearchSpecs({
    required String rootTable,
    required List<String> tables,
  }) {
    final rt = rootTable.trim();
    if (rt.isEmpty) return const <_TableSearchSpec>[];

    final specs = <_TableSearchSpec>[];
    for (final raw in tables) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      if (t == rt) {
        specs.add(
          _TableSearchSpec(table: t, rootIdColumn: 'id'),
        );
        continue;
      }

      if (rt == 'products') {
        if (t == 'stock_movements') {
          specs.add(
            _TableSearchSpec(
              table: t,
              rootIdColumn: 'product_id',
            ),
          );
        }
        continue;
      }

      if (rt == 'banks') {
        if (t == 'bank_transactions') {
          specs.add(
            _TableSearchSpec(
              table: t,
              rootIdColumn: 'bank_id',
            ),
          );
        }
        continue;
      }

      if (rt == 'cash_registers') {
        if (t == 'cash_register_transactions') {
          specs.add(
            _TableSearchSpec(
              table: t,
              rootIdColumn: 'cash_register_id',
            ),
          );
        }
        continue;
      }

      if (rt == 'credit_cards') {
        if (t == 'credit_card_transactions') {
          specs.add(
            _TableSearchSpec(
              table: t,
              rootIdColumn: 'credit_card_id',
            ),
          );
        }
        continue;
      }

      if (rt == 'current_accounts') {
        if (t == 'current_account_transactions') {
          specs.add(
            _TableSearchSpec(
              table: t,
              rootIdColumn: 'current_account_id',
            ),
          );
        }
        continue;
      }

      if (rt == 'cheques') {
        if (t == 'cheque_transactions') {
          specs.add(
            _TableSearchSpec(
              table: t,
              rootIdColumn: 'cheque_id',
            ),
          );
        }
        continue;
      }

      if (rt == 'promissory_notes') {
        if (t == 'note_transactions') {
          specs.add(
            _TableSearchSpec(
              table: t,
              rootIdColumn: 'note_id',
            ),
          );
        }
        continue;
      }

      if (rt == 'orders') {
        if (t == 'order_items') {
          specs.add(
            _TableSearchSpec(
              table: t,
              rootIdColumn: 'order_id',
            ),
          );
        }
        continue;
      }

      if (rt == 'quotes') {
        if (t == 'quote_items') {
          specs.add(
            _TableSearchSpec(
              table: t,
              rootIdColumn: 'quote_id',
            ),
          );
        }
        continue;
      }

      if (rt == 'expenses') {
        if (t == 'expense_items') {
          specs.add(
            _TableSearchSpec(
              table: t,
              rootIdColumn: 'expense_id',
            ),
          );
        }
        continue;
      }

      if (rt == 'productions') {
        if (t == 'production_stock_movements') {
          specs.add(
            _TableSearchSpec(
              table: t,
              rootIdColumn: 'production_id',
            ),
          );
        }
        continue;
      }

      if (rt == 'depots') {
        if (t == 'shipments') {
          // Sevkiyat hem çıkış hem giriş depoya bağlanır.
          specs.add(
            _TableSearchSpec(
              table: t,
              rootIdColumn: 'source_warehouse_id',
            ),
          );
          specs.add(
            _TableSearchSpec(
              table: t,
              rootIdColumn: 'dest_warehouse_id',
            ),
          );
        }
        continue;
      }
    }

    return specs;
  }

  static Future<List<int>> _fetchRootIdsForSpec({
    required Session executor,
    required _TableSearchSpec spec,
    required String normalizedQuery,
    required bool sortAscending,
    required int? afterRootId,
    required int limit,
    required ({DateTime? start, DateTime? endExclusive}) dayRange,
    required String? companyId,
    int? forcedRootId,
  }) async {
    final t = spec.table.trim();
    final rootCol = spec.rootIdColumn.trim();
    if (t.isEmpty || rootCol.isEmpty) return const <int>[];
    if (!_isSafeIdent(t) || !_isSafeIdent(rootCol)) return const <int>[];
    if (limit <= 0) return const <int>[];

    final tokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.length >= 2)
        .toList(growable: false);
    if (tokens.isEmpty) return const <int>[];

    final whereParts = <String>[
      // ParadeDB search:
      // - OR per-token (|||), AND across tokens -> Postgres FTS/plainto_tsquery'e yakın davranış.
      // - Query-level cast to ngram for "%term%" UX.
      for (var i = 0; i < tokens.length; i++)
        "search_tags ||| @q$i::pdb.ngram(2,3)",
    ];
    final params = <String, dynamic>{'lim': limit};
    for (var i = 0; i < tokens.length; i++) {
      params['q$i'] = tokens[i];
    }

    // [100B] Tenant filter (best-effort; sadece ilgili tablolar).
    final cId = (companyId ?? '').trim();
    if (cId.isNotEmpty && _tablesWithCompanyId.contains(t)) {
      whereParts.add("COALESCE(company_id, '$_defaultCompanyId') = @companyId");
      params['companyId'] = cId;
    }

    // [100B] Tarih aralığı (partition pruning / range scan).
    final dateCol = (_dateColumnByTable[t] ?? '').trim();
    if (dateCol.isNotEmpty && _isSafeIdent(dateCol)) {
      final start = dayRange.start;
      final endEx = dayRange.endExclusive;
      if (start != null) {
        whereParts.add('$dateCol >= @startDate');
        params['startDate'] = start;
      }
      if (endEx != null) {
        whereParts.add('$dateCol < @endDate');
        params['endDate'] = endEx;
      }
    }

    if (forcedRootId != null && forcedRootId > 0) {
      whereParts.add('$rootCol = @forced');
      params['forced'] = forcedRootId;
    } else if (afterRootId != null) {
      whereParts.add(
        sortAscending ? '$rootCol > @after' : '$rootCol < @after',
      );
      params['after'] = afterRootId;
    }

    final orderDir = sortAscending ? 'ASC' : 'DESC';
    final sql = '''
      SELECT DISTINCT $rootCol::bigint AS root_id
      FROM $t
      WHERE ${whereParts.join(' AND ')}
      ORDER BY root_id $orderDir
      LIMIT @lim
    ''';

    try {
      final res = await executor.execute(Sql.named(sql), parameters: params);
      final out = <int>[];
      for (final row in res) {
        final v = row[0];
        if (v is int) {
          out.add(v);
        } else if (v is BigInt) {
          out.add(v.toInt());
        } else {
          final parsed = int.tryParse(v?.toString() ?? '');
          if (parsed != null) out.add(parsed);
        }
      }
      return out;
    } catch (e) {
      debugPrint(
        'AramaPrimaryPath: index query failed for $t ($rootCol): $e',
      );
      rethrow;
    }
  }

  /// Harici arama motoru (OpenSearch/Typesense/Meilisearch) kullanılmıyor.
  /// Bu yüzden tüm sayfalarda mevcut DB fallback akışı çalışsın diye
  /// `indexEnabled=false` döner.
  static Future<AramaIndexPrimaryPathResult<T>> fetchPageIndexFirst<T>({
    required String query,
    required List<String> tablolar,
    required String rootTable,
    required int pageSize,
    required String? cursor,
    required String sortBy,
    required String? extraFilter,
    DateTime? startDate,
    DateTime? endDate,
    required Future<List<T>> Function(List<int> ids) dbFetchByIds,
    required int Function(T row) idOf,
    required T Function(T row, bool matchedInHidden) setMatchedInHidden,
    int maxIndexLoops = 8,
  }) async {
    final normalized = _normalizeQuery(query);
    if (normalized.isEmpty) {
      return AramaIndexPrimaryPathResult<T>(
        indexEnabled: false,
        rows: <T>[],
        hasNextPage: false,
        nextCursor: null,
      );
    }
    if (normalized.length < 2) {
      return AramaIndexPrimaryPathResult<T>(
        indexEnabled: false,
        rows: <T>[],
        hasNextPage: false,
        nextCursor: null,
      );
    }

    final sort = _parseRootIdSort(sortBy);
    if (!sort.supported) {
      return AramaIndexPrimaryPathResult<T>(
        indexEnabled: false,
        rows: <T>[],
        hasNextPage: false,
        nextCursor: null,
      );
    }

    final tables = tablolar.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (tables.isEmpty) {
      return AramaIndexPrimaryPathResult<T>(
        indexEnabled: false,
        rows: <T>[],
        hasNextPage: false,
        nextCursor: null,
      );
    }

    final specs = _buildSearchSpecs(rootTable: rootTable, tables: tables);
    if (specs.isEmpty) {
      return AramaIndexPrimaryPathResult<T>(
        indexEnabled: false,
        rows: <T>[],
        hasNextPage: false,
        nextCursor: null,
      );
    }

    final dayRange = _normalizeDayRange(startDate, endDate);
    final String? companyId =
        OturumServisi().aktifVeritabaniAdi.trim().isEmpty
            ? null
            : OturumServisi().aktifVeritabaniAdi.trim();

    final pool = await _poolBestEffort();
    if (pool == null) {
      return AramaIndexPrimaryPathResult<T>(
        indexEnabled: false,
        rows: <T>[],
        hasNextPage: false,
        nextCursor: null,
      );
    }

    final indexReady = await _isIndexReadyForTables(pool, tables);
    if (!indexReady) {
      return AramaIndexPrimaryPathResult<T>(
        indexEnabled: false,
        rows: <T>[],
        hasNextPage: false,
        nextCursor: null,
      );
    }

    final forcedRootId = _extractRootIdFilter(extraFilter);
    final int? startAfter = forcedRootId != null
        ? null
        : _parseCursorRootId(cursor);

    final int safePageSize = pageSize.clamp(1, 200);
    final int indexBatchRootIds = (safePageSize * 10).clamp(50, 500);
    final int maxLoops = maxIndexLoops.clamp(1, 50);

    final collected = <T>[];
    // Touch param (API stability): bazı sayfalar index-first aramada bu callback'i
    // kullanmak isteyebilir. Burada matchedInHidden hesabını DB zaten yapıyor.
    final _ = setMatchedInHidden;

    // Cursor/keyset: iteration cursor for index scans. We always return the last *returned* id
    // as the next cursor, but scanning might go further due to DB-side filters.
    int? scanAfter = startAfter;

    try {
      if (forcedRootId != null && forcedRootId > 0) {
        // Root-id pin: verify there is at least one hit in either root or tx tables.
        var anyHit = false;
        for (final s in specs) {
          final hits = await _fetchRootIdsForSpec(
            executor: pool,
            spec: s,
            normalizedQuery: normalized,
            sortAscending: sort.ascending,
            afterRootId: null,
            limit: 1,
            dayRange: dayRange,
            companyId: companyId,
            forcedRootId: forcedRootId,
          );
          if (hits.isNotEmpty) {
            anyHit = true;
            break;
          }
        }

        if (!anyHit) {
          return AramaIndexPrimaryPathResult<T>(
            indexEnabled: true,
            rows: <T>[],
            hasNextPage: false,
            nextCursor: null,
          );
        }

        final rows = await dbFetchByIds(<int>[forcedRootId]);
        final out = rows.toList(growable: false);
        return AramaIndexPrimaryPathResult<T>(
          indexEnabled: true,
          rows: out,
          hasNextPage: false,
          nextCursor: out.isNotEmpty ? idOf(out.last).toString() : null,
        );
      }

      for (var loop = 0; loop < maxLoops; loop++) {
        if (collected.length >= safePageSize + 1) break;

        // 1) Fetch next candidate root ids (UNION across tables, then take first batch).
        final perTableResults = <List<int>>[];
        for (final s in specs) {
          perTableResults.add(
            await _fetchRootIdsForSpec(
              executor: pool,
              spec: s,
              normalizedQuery: normalized,
              sortAscending: sort.ascending,
              afterRootId: scanAfter,
              limit: indexBatchRootIds,
              dayRange: dayRange,
              companyId: companyId,
            ),
          );
        }

        final mergedSet = <int>{};
        final merged = <int>[];
        for (var i = 0; i < specs.length; i++) {
          for (final id in perTableResults[i]) {
            if (id <= 0) continue;
            if (mergedSet.add(id)) {
              merged.add(id);
            }
          }
        }

        if (merged.isEmpty) break;

        merged.sort((a, b) => sort.ascending ? a.compareTo(b) : b.compareTo(a));
        final batch = merged.length <= indexBatchRootIds
            ? merged
            : merged.sublist(0, indexBatchRootIds);

        // Move scan cursor forward based on the last candidate we considered in-order.
        scanAfter = batch.isNotEmpty ? batch.last : scanAfter;

        // 2) Fetch DB rows for these candidates using existing filters/search.
        final dbRows = await dbFetchByIds(batch);
        if (dbRows.isEmpty) {
          continue;
        }

        // 3) Re-order DB rows to match candidate order (stable).
        final byId = <int, T>{};
        for (final r in dbRows) {
          byId[idOf(r)] = r;
        }

        for (final id in batch) {
          final r = byId[id];
          if (r == null) continue;
          collected.add(r);
          if (collected.length >= safePageSize + 1) break;
        }
      }
    } catch (e) {
      debugPrint('AramaPrimaryPath: index-first failed, fallback to DB: $e');
      return AramaIndexPrimaryPathResult<T>(
        indexEnabled: false,
        rows: <T>[],
        hasNextPage: false,
        nextCursor: null,
      );
    }

    final hasNext = collected.length > safePageSize;
    final page = hasNext ? collected.sublist(0, safePageSize) : collected;
    final nextCur = page.isNotEmpty ? idOf(page.last).toString() : null;

    return AramaIndexPrimaryPathResult<T>(
      indexEnabled: true,
      rows: page,
      hasNextPage: hasNext,
      nextCursor: nextCur,
    );
  }

  static Future<AramaPrimaryPathResult<T>> fetchPageByRootId<T>({
    required String query,
    required List<String> tablolar,
    required String rootTable,
    required int limit,
    required bool sortAscending,
    required int? lastRootId,
    DateTime? startDate,
    DateTime? endDate,
    required Future<List<T>> Function(List<int> ids, int limit) dbFetch,
    int maxIndexCalls = 8,
    int indexBatchRootIds = 250,
    int maxCandidateIds = 20000,
  }) async {
    final normalized = _normalizeQuery(query);
    if (normalized.isEmpty || normalized.length < 2) {
      return AramaPrimaryPathResult<T>(indexEnabled: false, rows: const []);
    }

    final tables =
        tablolar.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (tables.isEmpty) {
      return AramaPrimaryPathResult<T>(indexEnabled: false, rows: const []);
    }

    final specs = _buildSearchSpecs(rootTable: rootTable, tables: tables);
    if (specs.isEmpty) {
      return AramaPrimaryPathResult<T>(indexEnabled: false, rows: const []);
    }

    final pool = await _poolBestEffort();
    if (pool == null) {
      return AramaPrimaryPathResult<T>(indexEnabled: false, rows: const []);
    }

    final indexReady = await _isIndexReadyForTables(pool, tables);
    if (!indexReady) {
      return AramaPrimaryPathResult<T>(indexEnabled: false, rows: const []);
    }

    final dayRange = _normalizeDayRange(startDate, endDate);
    final String? companyId =
        OturumServisi().aktifVeritabaniAdi.trim().isEmpty
            ? null
            : OturumServisi().aktifVeritabaniAdi.trim();

    final safeLimit = limit.clamp(1, 500);
    final safeBatch = indexBatchRootIds.clamp(10, 2000);
    final safeMaxCalls = maxIndexCalls.clamp(1, 200);
    final safeMaxCandidates = maxCandidateIds.clamp(100, 200000);

    final seen = <int>{};
    final candidates = <int>[];

    int? scanAfter = lastRootId;
    for (var i = 0; i < safeMaxCalls; i++) {
      if (candidates.length >= safeMaxCandidates) break;

      final perTableResults = <List<int>>[];
      for (final s in specs) {
        perTableResults.add(
          await _fetchRootIdsForSpec(
            executor: pool,
            spec: s,
            normalizedQuery: normalized,
            sortAscending: sortAscending,
            afterRootId: scanAfter,
            limit: safeBatch,
            dayRange: dayRange,
            companyId: companyId,
          ),
        );
      }

      final merged = <int>[];
      for (final ids in perTableResults) {
        for (final id in ids) {
          if (id <= 0) continue;
          if (seen.add(id)) merged.add(id);
        }
      }

      if (merged.isEmpty) break;
      merged.sort((a, b) => sortAscending ? a.compareTo(b) : b.compareTo(a));
      final batch = merged.length <= safeBatch ? merged : merged.sublist(0, safeBatch);

      scanAfter = batch.isNotEmpty ? batch.last : scanAfter;
      candidates.addAll(batch);
      if (candidates.length >= safeLimit) break;
    }

    if (candidates.isEmpty) {
      return AramaPrimaryPathResult<T>(indexEnabled: true, rows: const []);
    }

    final rows = await dbFetch(candidates, safeLimit);
    return AramaPrimaryPathResult<T>(indexEnabled: true, rows: rows);
  }
}

class AramaIndexPrimaryPathResult<T> {
  final bool indexEnabled;
  final List<T> rows;
  final bool hasNextPage;
  final String? nextCursor;

  const AramaIndexPrimaryPathResult({
    required this.indexEnabled,
    required this.rows,
    required this.hasNextPage,
    required this.nextCursor,
  });
}
