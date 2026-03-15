import 'dart:convert';

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

enum _SortValueType { integer, number, text, dateTime }

@immutable
class _ParsedSort {
  final String field;
  final bool ascending;

  const _ParsedSort({required this.field, required this.ascending});
}

@immutable
class _ParsedCursor {
  final int rootId;
  final Object? sortValue;

  const _ParsedCursor({required this.rootId, required this.sortValue});
}

@immutable
class _ParsedRange {
  final DateTime? start;
  final DateTime? endExclusive;

  const _ParsedRange({this.start, this.endExclusive});
}

@immutable
class _ParsedFilters {
  final int? rootId;
  final bool? rootActive;
  final bool? rootIsDefault;
  final String? rootType;
  final String? rootStatus;
  final String? rootAccount;
  final String? rootUser;
  final String? rootAccountType;
  final String? rootCity;
  final String? rootCategory;
  final String? rootPaymentStatus;
  final String? rootGroup;
  final String? rootUnit;
  final String? rootBank;
  final double? rootVat;
  final int? warehouseId;
  final String? unit;
  final String? userName;
  final String? sourceType;
  final String? type;
  final String? tableScope;
  final List<String> integrationRefPrefixes;
  final _ParsedRange rootDateRange;
  final _ParsedRange transactionDateRange;

  const _ParsedFilters({
    required this.rootId,
    required this.rootActive,
    required this.rootIsDefault,
    required this.rootType,
    required this.rootStatus,
    required this.rootAccount,
    required this.rootUser,
    required this.rootAccountType,
    required this.rootCity,
    required this.rootCategory,
    required this.rootPaymentStatus,
    required this.rootGroup,
    required this.rootUnit,
    required this.rootBank,
    required this.rootVat,
    required this.warehouseId,
    required this.unit,
    required this.userName,
    required this.sourceType,
    required this.type,
    required this.tableScope,
    required this.integrationRefPrefixes,
    required this.rootDateRange,
    required this.transactionDateRange,
  });

  bool get hasGenericChildFilters =>
      warehouseId != null ||
      unit != null ||
      userName != null ||
      sourceType != null ||
      type != null ||
      tableScope != null ||
      integrationRefPrefixes.isNotEmpty ||
      transactionDateRange.start != null ||
      transactionDateRange.endExclusive != null;
}

@immutable
class _CandidateRow {
  final int rootId;
  final Object? sortValue;

  const _CandidateRow({required this.rootId, required this.sortValue});
}

@immutable
class _CandidatePage {
  final List<_CandidateRow> rows;
  final _ParsedCursor? nextScanCursor;
  final bool exhausted;

  const _CandidatePage({
    required this.rows,
    required this.nextScanCursor,
    required this.exhausted,
  });
}

class AramaPrimaryPath {
  static final RegExp _safeIdent = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');
  static const String _defaultCompanyId = 'patisyo2025';

  static final Map<String, bool> _indexReadyCache = <String, bool>{};

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

  static bool _isSafeIdent(String value) => _safeIdent.hasMatch(value.trim());

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

  static String _normalizeQuery(String query) =>
      _normalizeTurkish(query).trim();

  static String _searchTrgmIndexNameForTable(String table) =>
      'idx_${table.trim()}_search_tags_gin';

  static Future<Pool<void>?> _poolBestEffort() async {
    try {
      final dbName = OturumServisi().aktifVeritabaniAdi;
      return await VeritabaniHavuzu().havuzAl(
        database: dbName,
        preferDirectSocket: true,
        allowApiFallback: false,
        maxConnectionsOverride: 12,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _isIndexReadyForTables(
    Session executor,
    List<String> tables,
  ) async {
    try {
      for (final raw in tables) {
        final table = raw.trim();
        if (table.isEmpty || !_isSafeIdent(table)) return false;
        final indexName = _searchTrgmIndexNameForTable(table);
        final ok =
            await PgEklentiler.hasIndex(executor, indexName) ||
            await PgEklentiler.hasTrgmIndexForTableColumn(
              executor,
              table: table,
            );
        if (!ok) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _isIndexReadyCached(
    Session executor, {
    required String databaseName,
    required List<String> tables,
  }) async {
    final sorted = tables.toSet().toList()..sort();
    final cacheKey = '${databaseName.trim()}|${sorted.join(',')}';
    final cached = _indexReadyCache[cacheKey];
    if (cached == true) return true;
    final ready = await _isIndexReadyForTables(executor, sorted);
    if (ready) {
      _indexReadyCache[cacheKey] = true;
    }
    return ready;
  }

  static _ParsedSort? _parseSort(String sortBy) {
    final raw = sortBy.trim().toLowerCase();
    if (raw.isEmpty) return null;
    final parts = raw.split(':').map((e) => e.trim()).toList(growable: false);
    if (parts.isEmpty || parts.first.isEmpty) return null;
    final field = parts.first.replaceAll('.keyword', '');
    final dir = parts.length > 1 ? parts[1] : 'asc';
    if (dir != 'asc' && dir != 'desc') return null;
    if (!field.startsWith('root_')) return null;
    return _ParsedSort(field: field, ascending: dir == 'asc');
  }

  static _ParsedCursor? _parseCursor(String? cursor) {
    final raw = (cursor ?? '').trim();
    if (raw.isEmpty) return null;

    final legacy = int.tryParse(raw);
    if (legacy != null && legacy > 0) {
      return _ParsedCursor(rootId: legacy, sortValue: null);
    }

    final parts = raw.split('|');
    if (parts.length != 3) return null;
    final type = parts[0];
    final encoded = parts[1];
    final rootId = int.tryParse(parts[2]);
    if (rootId == null || rootId <= 0) return null;

    switch (type) {
      case 'z':
        return _ParsedCursor(rootId: rootId, sortValue: null);
      case 'd':
        final micros = int.tryParse(encoded);
        if (micros == null) return null;
        return _ParsedCursor(
          rootId: rootId,
          sortValue: DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true),
        );
      case 'n':
        final parsed = num.tryParse(encoded);
        if (parsed == null) return null;
        return _ParsedCursor(rootId: rootId, sortValue: parsed);
      case 's':
        try {
          final decoded = utf8.decode(base64Url.decode(encoded));
          return _ParsedCursor(rootId: rootId, sortValue: decoded);
        } catch (_) {
          return null;
        }
    }
    return null;
  }

  static String _encodeCursor(Object? sortValue, int rootId) {
    if (sortValue == null) return 'z||$rootId';
    if (sortValue is DateTime) {
      return 'd|${sortValue.toUtc().microsecondsSinceEpoch}|$rootId';
    }
    if (sortValue is num) {
      return 'n|${sortValue.toString()}|$rootId';
    }
    return 's|${base64Url.encode(utf8.encode(sortValue.toString()))}|$rootId';
  }

  static String? _extractQuotedValue(String raw, String key) {
    final match = RegExp('$key:"((?:[^"\\\\]|\\\\.)*)"').firstMatch(raw);
    if (match == null) return null;
    final value = (match.group(1) ?? '').replaceAll(r'\"', '"').trim();
    return value.isEmpty ? null : value;
  }

  static int? _extractIntValue(String raw, String key) {
    final match = RegExp(
      r'\bKEY:(\d+)\b'.replaceFirst('KEY', key),
    ).firstMatch(raw);
    return int.tryParse(match?.group(1) ?? '');
  }

  static double? _extractDoubleValue(String raw, String key) {
    final match = RegExp(
      r'\bKEY:([0-9]+(?:\.[0-9]+)?)\b'.replaceFirst('KEY', key),
    ).firstMatch(raw);
    return double.tryParse(match?.group(1) ?? '');
  }

  static bool? _extractBoolValue(String raw, String key) {
    final match = RegExp(
      r'\bKEY:(true|false)\b'.replaceFirst('KEY', key),
      caseSensitive: false,
    ).firstMatch(raw);
    final value = (match?.group(1) ?? '').toLowerCase();
    if (value == 'true') return true;
    if (value == 'false') return false;
    return null;
  }

  static _ParsedRange _extractEpochRange(String raw, String key) {
    final match = RegExp(
      '$key:\\[(\\*|\\d+) TO (\\*|\\d+)\\}',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return const _ParsedRange();

    DateTime? parsePart(String? value) {
      if (value == null || value == '*' || value.isEmpty) return null;
      final seconds = int.tryParse(value);
      if (seconds == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    }

    return _ParsedRange(
      start: parsePart(match.group(1)),
      endExclusive: parsePart(match.group(2)),
    );
  }

  static List<String> _extractIntegrationPrefixes(String raw) {
    final matches = RegExp(
      r'integration_ref:([A-Za-z0-9_\-]+)\*',
      caseSensitive: false,
    ).allMatches(raw);
    final out = <String>[];
    for (final match in matches) {
      final value = (match.group(1) ?? '').trim();
      if (value.isNotEmpty) out.add(value);
    }
    return out;
  }

  static _ParsedFilters _parseExtraFilter(String? extraFilter) {
    final raw = (extraFilter ?? '').trim();
    return _ParsedFilters(
      rootId: _extractIntValue(raw, 'root_id'),
      rootActive: _extractBoolValue(raw, 'root_aktif_mi'),
      rootIsDefault: _extractBoolValue(raw, 'root_is_default'),
      rootType: _extractQuotedValue(raw, 'root_type'),
      rootStatus: _extractQuotedValue(raw, 'root_status'),
      rootAccount: _extractQuotedValue(raw, 'root_account'),
      rootUser: _extractQuotedValue(raw, 'root_user'),
      rootAccountType: _extractQuotedValue(raw, 'root_account_type'),
      rootCity: _extractQuotedValue(raw, 'root_city'),
      rootCategory: _extractQuotedValue(raw, 'root_category'),
      rootPaymentStatus: _extractQuotedValue(raw, 'root_payment_status'),
      rootGroup: _extractQuotedValue(raw, 'root_group'),
      rootUnit: _extractQuotedValue(raw, 'root_unit'),
      rootBank: _extractQuotedValue(raw, 'root_bank'),
      rootVat: _extractDoubleValue(raw, 'root_vat'),
      warehouseId: _extractIntValue(raw, 'warehouse_id'),
      unit: _extractQuotedValue(raw, 'unit'),
      userName: _extractQuotedValue(raw, 'user_name'),
      sourceType: _extractQuotedValue(raw, 'source_type'),
      type: _extractQuotedValue(raw, 'type'),
      tableScope:
          _extractQuotedValue(raw, 'table') ??
          (() {
            final match = RegExp(
              r'\btable:([a-zA-Z_][a-zA-Z0-9_]*)\b',
            ).firstMatch(raw);
            final value = (match?.group(1) ?? '').trim();
            return value.isEmpty ? null : value;
          }()),
      integrationRefPrefixes: _extractIntegrationPrefixes(raw),
      rootDateRange: _extractEpochRange(raw, 'root_date'),
      transactionDateRange: _extractEpochRange(raw, 'date'),
    );
  }

  static void _addCompanyCondition(
    List<String> conditions,
    Map<String, dynamic> params, {
    required String table,
    required String column,
    required String? companyId,
  }) {
    final cid = (companyId ?? '').trim();
    if (cid.isEmpty || !_tablesWithCompanyId.contains(table)) return;
    final paramName = 'company_${column.replaceAll('.', '_')}';
    conditions.add("COALESCE($column, '$_defaultCompanyId') = @$paramName");
    params[paramName] = cid;
  }

  static String _searchClause({
    required String expression,
    required String paramPrefix,
    required String normalizedQuery,
    required Map<String, dynamic> params,
  }) {
    params['${paramPrefix}search'] = '%$normalizedQuery%';
    return '''
      (
        $expression LIKE @${paramPrefix}search
      )
    ''';
  }

  static void _addDateRangeCondition(
    List<String> conditions,
    Map<String, dynamic> params, {
    required String expression,
    required String paramPrefix,
    required _ParsedRange range,
  }) {
    if (range.start != null) {
      conditions.add('$expression >= @${paramPrefix}start');
      params['${paramPrefix}start'] = range.start;
    }
    if (range.endExclusive != null) {
      conditions.add('$expression < @${paramPrefix}end');
      params['${paramPrefix}end'] = range.endExclusive;
    }
  }

  static String? _buildChildMembershipClause({
    required String rootIdExpr,
    required String childTable,
    required String childAlias,
    required List<String> parentIdExprs,
    required String searchTagsExpr,
    required Map<String, dynamic> params,
    required _ParsedFilters filters,
    required String? companyId,
    required bool includeSearch,
    required String normalizedQuery,
    String? companyColumn,
    String? dateColumn,
    String? userColumn,
    String? typeColumn,
    String? sourceTypeColumn,
    String? unitColumn,
    String? warehouseCondition,
  }) {
    if (parentIdExprs.isEmpty) return null;
    final conditions = <String>[];

    if (companyColumn != null && companyColumn.trim().isNotEmpty) {
      _addCompanyCondition(
        conditions,
        params,
        table: childTable,
        column: companyColumn,
        companyId: companyId,
      );
    }

    if (dateColumn != null && dateColumn.trim().isNotEmpty) {
      _addDateRangeCondition(
        conditions,
        params,
        expression: dateColumn,
        paramPrefix: '${childAlias}_date_',
        range: filters.transactionDateRange,
      );
    }

    if (filters.userName != null && userColumn != null) {
      conditions.add("COALESCE($userColumn, '') = @${childAlias}_user_name");
      params['${childAlias}_user_name'] = filters.userName!;
    }

    if (filters.unit != null && unitColumn != null) {
      conditions.add("COALESCE($unitColumn, '') = @${childAlias}_unit");
      params['${childAlias}_unit'] = filters.unit!;
    }

    if (filters.warehouseId != null &&
        warehouseCondition != null &&
        warehouseCondition.trim().isNotEmpty) {
      conditions.add(warehouseCondition);
      params['${childAlias}_warehouse_id'] = filters.warehouseId!;
    }

    if (filters.type != null) {
      if (typeColumn != null) {
        conditions.add("COALESCE($typeColumn, '') = @${childAlias}_type");
        params['${childAlias}_type'] = filters.type!;
      } else {
        conditions.add(
          _searchClause(
            expression: searchTagsExpr,
            paramPrefix: '${childAlias}_type_filter_',
            normalizedQuery: _normalizeQuery(filters.type!),
            params: params,
          ),
        );
      }
    }

    if (filters.sourceType != null) {
      if (sourceTypeColumn != null) {
        conditions.add(
          "COALESCE($sourceTypeColumn, '') = @${childAlias}_source_type",
        );
        params['${childAlias}_source_type'] = filters.sourceType!;
      } else {
        conditions.add(
          _searchClause(
            expression: searchTagsExpr,
            paramPrefix: '${childAlias}_source_type_filter_',
            normalizedQuery: _normalizeQuery(filters.sourceType!),
            params: params,
          ),
        );
      }
    }

    if (filters.integrationRefPrefixes.isNotEmpty) {
      final orParts = <String>[];
      for (var i = 0; i < filters.integrationRefPrefixes.length; i++) {
        final key = '${childAlias}_integration_ref_$i';
        orParts.add("COALESCE($childAlias.integration_ref, '') LIKE @$key");
        params[key] = '${filters.integrationRefPrefixes[i]}%';
      }
      conditions.add('(${orParts.join(' OR ')})');
    }

    if (includeSearch) {
      conditions.add(
        _searchClause(
          expression: searchTagsExpr,
          paramPrefix: '${childAlias}_query_',
          normalizedQuery: normalizedQuery,
          params: params,
        ),
      );
    }

    final whereClause = conditions.isEmpty
        ? ''
        : ' WHERE ${conditions.join(' AND ')}';
    final selects = parentIdExprs
        .map(
          (expr) =>
              'SELECT $expr AS parent_id FROM $childTable $childAlias$whereClause',
        )
        .join(' UNION ');
    final groupedAlias = '${childAlias}_parent_ids';
    return '''
      $rootIdExpr IN (
        SELECT parent_id
        FROM ($selects) $groupedAlias
        WHERE parent_id IS NOT NULL
        GROUP BY parent_id
      )
    ''';
  }

  static ({String expression, _SortValueType type})? _resolveSort(
    String rootTable,
    _ParsedSort sort,
    _ParsedFilters filters,
  ) {
    switch (rootTable) {
      case 'products':
        switch (sort.field) {
          case 'root_id':
            return (expression: 'p.id', type: _SortValueType.integer);
          case 'root_code':
            return (expression: 'p.kod', type: _SortValueType.text);
          case 'root_name':
            return (expression: 'p.ad', type: _SortValueType.text);
          case 'root_price':
            return (
              expression: 'COALESCE(p.alis_fiyati, 0)',
              type: _SortValueType.number,
            );
          case 'root_sale_price_1':
            return (
              expression: 'COALESCE(p.satis_fiyati_1, 0)',
              type: _SortValueType.number,
            );
          case 'root_stock':
            if (filters.warehouseId != null) {
              return (
                expression:
                    'COALESCE((SELECT SUM(ws.quantity) FROM warehouse_stocks ws WHERE ws.product_code = p.kod AND ws.warehouse_id = @sort_product_warehouse_id), 0)',
                type: _SortValueType.number,
              );
            }
            return (
              expression: 'COALESCE(p.stok, 0)',
              type: _SortValueType.number,
            );
          case 'root_unit':
            return (
              expression: "COALESCE(p.birim, '')",
              type: _SortValueType.text,
            );
          case 'root_aktif_mi':
            return (
              expression: 'COALESCE(p.aktif_mi, 0)',
              type: _SortValueType.integer,
            );
        }
        break;
      case 'productions':
        switch (sort.field) {
          case 'root_id':
            return (expression: 'pr.id', type: _SortValueType.integer);
          case 'root_code':
            return (expression: 'pr.kod', type: _SortValueType.text);
          case 'root_name':
            return (expression: 'pr.ad', type: _SortValueType.text);
          case 'root_price':
            return (
              expression: 'COALESCE(pr.alis_fiyati, 0)',
              type: _SortValueType.number,
            );
          case 'root_sale_price_1':
            return (
              expression: 'COALESCE(pr.satis_fiyati_1, 0)',
              type: _SortValueType.number,
            );
          case 'root_stock':
            return (
              expression: 'COALESCE(pr.stok, 0)',
              type: _SortValueType.number,
            );
          case 'root_unit':
            return (
              expression: "COALESCE(pr.birim, '')",
              type: _SortValueType.text,
            );
          case 'root_aktif_mi':
            return (
              expression: 'COALESCE(pr.aktif_mi, 0)',
              type: _SortValueType.integer,
            );
        }
        break;
      case 'current_accounts':
        switch (sort.field) {
          case 'root_id':
            return (expression: 'ca.id', type: _SortValueType.integer);
          case 'root_code':
            return (expression: 'ca.kod_no', type: _SortValueType.text);
          case 'root_name':
            return (expression: 'ca.adi', type: _SortValueType.text);
          case 'root_account_type':
            return (expression: 'ca.hesap_turu', type: _SortValueType.text);
          case 'root_balance_debit':
            return (
              expression: 'COALESCE(ca.bakiye_borc, 0)',
              type: _SortValueType.number,
            );
          case 'root_balance_credit':
            return (
              expression: 'COALESCE(ca.bakiye_alacak, 0)',
              type: _SortValueType.number,
            );
          case 'root_aktif_mi':
            return (
              expression: 'COALESCE(ca.aktif_mi, 0)',
              type: _SortValueType.integer,
            );
        }
        break;
      case 'banks':
        switch (sort.field) {
          case 'root_id':
            return (expression: 'b.id', type: _SortValueType.integer);
          case 'root_code':
            return (expression: 'b.code', type: _SortValueType.text);
          case 'root_name':
            return (expression: 'b.name', type: _SortValueType.text);
          case 'root_amount':
            return (
              expression: 'COALESCE(b.balance, 0)',
              type: _SortValueType.number,
            );
        }
        break;
      case 'cash_registers':
        switch (sort.field) {
          case 'root_id':
            return (expression: 'cr.id', type: _SortValueType.integer);
          case 'root_code':
            return (expression: 'cr.code', type: _SortValueType.text);
          case 'root_name':
            return (expression: 'cr.name', type: _SortValueType.text);
          case 'root_address':
            return (
              expression: "COALESCE(cr.address, '')",
              type: _SortValueType.text,
            );
          case 'root_responsible':
            return (
              expression: "COALESCE(cr.responsible, '')",
              type: _SortValueType.text,
            );
          case 'root_phone':
            return (
              expression: "COALESCE(cr.phone, '')",
              type: _SortValueType.text,
            );
          case 'root_aktif_mi':
            return (
              expression: 'COALESCE(cr.is_active, 0)',
              type: _SortValueType.integer,
            );
          case 'root_amount':
            return (
              expression: 'COALESCE(cr.balance, 0)',
              type: _SortValueType.number,
            );
        }
        break;
      case 'credit_cards':
        switch (sort.field) {
          case 'root_id':
            return (expression: 'cc.id', type: _SortValueType.integer);
          case 'root_code':
            return (expression: 'cc.code', type: _SortValueType.text);
          case 'root_name':
            return (expression: 'cc.name', type: _SortValueType.text);
          case 'root_address':
            return (
              expression: "COALESCE(cc.address, '')",
              type: _SortValueType.text,
            );
          case 'root_responsible':
            return (
              expression: "COALESCE(cc.responsible, '')",
              type: _SortValueType.text,
            );
          case 'root_phone':
            return (
              expression: "COALESCE(cc.phone, '')",
              type: _SortValueType.text,
            );
          case 'root_aktif_mi':
            return (
              expression: 'COALESCE(cc.is_active, 0)',
              type: _SortValueType.integer,
            );
          case 'root_amount':
            return (
              expression: 'COALESCE(cc.balance, 0)',
              type: _SortValueType.number,
            );
        }
        break;
      case 'depots':
        switch (sort.field) {
          case 'root_id':
            return (expression: 'd.id', type: _SortValueType.integer);
          case 'root_code':
            return (expression: 'd.kod', type: _SortValueType.text);
          case 'root_name':
            return (expression: 'd.ad', type: _SortValueType.text);
          case 'root_address':
            return (
              expression: "COALESCE(d.adres, '')",
              type: _SortValueType.text,
            );
          case 'root_responsible':
            return (
              expression: "COALESCE(d.sorumlu, '')",
              type: _SortValueType.text,
            );
          case 'root_phone':
            return (
              expression: "COALESCE(d.telefon, '')",
              type: _SortValueType.text,
            );
          case 'root_aktif_mi':
            return (
              expression: 'COALESCE(d.aktif_mi, 0)',
              type: _SortValueType.integer,
            );
        }
        break;
      case 'expenses':
        switch (sort.field) {
          case 'root_id':
            return (expression: 'e.id', type: _SortValueType.integer);
          case 'root_code':
            return (expression: 'e.kod', type: _SortValueType.text);
          case 'root_name':
            return (expression: 'e.baslik', type: _SortValueType.text);
          case 'root_amount':
            return (
              expression: 'COALESCE(e.tutar, 0)',
              type: _SortValueType.number,
            );
          case 'root_category':
            return (
              expression: "COALESCE(e.kategori, '')",
              type: _SortValueType.text,
            );
          case 'root_date':
            return (expression: 'e.tarih', type: _SortValueType.dateTime);
          case 'root_aktif_mi':
            return (
              expression: 'COALESCE(e.aktif_mi, 0)',
              type: _SortValueType.integer,
            );
          case 'root_description':
            return (
              expression: "COALESCE(e.aciklama, '')",
              type: _SortValueType.text,
            );
        }
        break;
      case 'orders':
        switch (sort.field) {
          case 'root_id':
            return (expression: 'o.id', type: _SortValueType.integer);
          case 'root_date':
            return (expression: 'o.tarih', type: _SortValueType.dateTime);
          case 'root_amount':
            return (
              expression: 'COALESCE(o.tutar, 0)',
              type: _SortValueType.number,
            );
          case 'root_status':
            return (expression: 'o.durum', type: _SortValueType.text);
        }
        break;
      case 'quotes':
        switch (sort.field) {
          case 'root_id':
            return (expression: 'q.id', type: _SortValueType.integer);
          case 'root_date':
            return (expression: 'q.tarih', type: _SortValueType.dateTime);
          case 'root_amount':
            return (
              expression: 'COALESCE(q.tutar, 0)',
              type: _SortValueType.number,
            );
          case 'root_status':
            return (expression: 'q.durum', type: _SortValueType.text);
        }
        break;
      case 'cheques':
        switch (sort.field) {
          case 'root_id':
            return (expression: 'c.id', type: _SortValueType.integer);
          case 'root_code':
            return (expression: 'c.check_no', type: _SortValueType.text);
          case 'root_name':
            return (
              expression: "COALESCE(c.customer_name, '')",
              type: _SortValueType.text,
            );
          case 'root_amount':
            return (
              expression: 'COALESCE(c.amount, 0)',
              type: _SortValueType.number,
            );
          case 'root_issue_date':
            return (expression: 'c.issue_date', type: _SortValueType.dateTime);
          case 'root_due_date':
            return (expression: 'c.due_date', type: _SortValueType.dateTime);
        }
        break;
      case 'promissory_notes':
        switch (sort.field) {
          case 'root_id':
            return (expression: 'n.id', type: _SortValueType.integer);
          case 'root_code':
            return (expression: 'n.note_no', type: _SortValueType.text);
          case 'root_name':
            return (
              expression: "COALESCE(n.customer_name, '')",
              type: _SortValueType.text,
            );
          case 'root_amount':
            return (
              expression: 'COALESCE(n.amount, 0)',
              type: _SortValueType.number,
            );
          case 'root_issue_date':
            return (expression: 'n.issue_date', type: _SortValueType.dateTime);
          case 'root_due_date':
            return (expression: 'n.due_date', type: _SortValueType.dateTime);
        }
        break;
    }
    return null;
  }

  static String _cursorWhere({
    required String idExpr,
    required String sortExpr,
    required _SortValueType type,
    required bool ascending,
    required _ParsedCursor cursor,
    required Map<String, dynamic> params,
  }) {
    final op = ascending ? '>' : '<';
    if (sortExpr == idExpr || cursor.sortValue == null) {
      params['cursor_id'] = cursor.rootId;
      return '$idExpr $op @cursor_id';
    }

    params['cursor_id'] = cursor.rootId;
    switch (type) {
      case _SortValueType.dateTime:
        params['cursor_sort'] = cursor.sortValue;
        break;
      case _SortValueType.integer:
      case _SortValueType.number:
        params['cursor_sort'] =
            num.tryParse(cursor.sortValue.toString()) ?? cursor.sortValue;
        break;
      case _SortValueType.text:
        params['cursor_sort'] = cursor.sortValue.toString();
        break;
    }
    return '($sortExpr $op @cursor_sort OR ($sortExpr = @cursor_sort AND $idExpr $op @cursor_id))';
  }

  static Future<Object?> _resolveCursorSortValue(
    Session executor, {
    required String rootTable,
    required _ParsedSort sort,
    required _ParsedFilters filters,
    required int rootId,
  }) async {
    final sortSpec = _resolveSort(rootTable, sort, filters);
    if (sortSpec == null) return null;

    final params = <String, dynamic>{'cursor_id': rootId};
    switch (rootTable) {
      case 'products':
        if (filters.warehouseId != null && sort.field == 'root_stock') {
          params['sort_product_warehouse_id'] = filters.warehouseId!;
        }
        final rows = await executor.execute(
          Sql.named(
            'SELECT ${sortSpec.expression} AS sort_value FROM products p WHERE p.id = @cursor_id LIMIT 1',
          ),
          parameters: params,
        );
        return rows.isEmpty ? null : rows.first[0];
      case 'productions':
        final rows = await executor.execute(
          Sql.named(
            'SELECT ${sortSpec.expression} AS sort_value FROM productions pr WHERE pr.id = @cursor_id LIMIT 1',
          ),
          parameters: params,
        );
        return rows.isEmpty ? null : rows.first[0];
      case 'current_accounts':
        final rows = await executor.execute(
          Sql.named(
            'SELECT ${sortSpec.expression} AS sort_value FROM current_accounts ca WHERE ca.id = @cursor_id LIMIT 1',
          ),
          parameters: params,
        );
        return rows.isEmpty ? null : rows.first[0];
      case 'banks':
        _addCompanyCondition(
          <String>[],
          params,
          table: 'banks',
          column: 'b.company_id',
          companyId: OturumServisi().aktifVeritabaniAdi,
        );
        final rows = await executor.execute(
          Sql.named('''
            SELECT ${sortSpec.expression} AS sort_value
            FROM banks b
            WHERE b.id = @cursor_id
            LIMIT 1
          '''),
          parameters: params,
        );
        return rows.isEmpty ? null : rows.first[0];
      case 'cash_registers':
        final rows = await executor.execute(
          Sql.named('''
            SELECT ${sortSpec.expression} AS sort_value
            FROM cash_registers cr
            WHERE cr.id = @cursor_id
            LIMIT 1
          '''),
          parameters: params,
        );
        return rows.isEmpty ? null : rows.first[0];
      case 'credit_cards':
        final rows = await executor.execute(
          Sql.named('''
            SELECT ${sortSpec.expression} AS sort_value
            FROM credit_cards cc
            WHERE cc.id = @cursor_id
            LIMIT 1
          '''),
          parameters: params,
        );
        return rows.isEmpty ? null : rows.first[0];
      case 'depots':
        final rows = await executor.execute(
          Sql.named(
            'SELECT ${sortSpec.expression} AS sort_value FROM depots d WHERE d.id = @cursor_id LIMIT 1',
          ),
          parameters: params,
        );
        return rows.isEmpty ? null : rows.first[0];
      case 'expenses':
        final rows = await executor.execute(
          Sql.named(
            'SELECT ${sortSpec.expression} AS sort_value FROM expenses e WHERE e.id = @cursor_id LIMIT 1',
          ),
          parameters: params,
        );
        return rows.isEmpty ? null : rows.first[0];
      case 'orders':
        final rows = await executor.execute(
          Sql.named(
            'SELECT ${sortSpec.expression} AS sort_value FROM orders o WHERE o.id = @cursor_id LIMIT 1',
          ),
          parameters: params,
        );
        return rows.isEmpty ? null : rows.first[0];
      case 'quotes':
        final rows = await executor.execute(
          Sql.named(
            'SELECT ${sortSpec.expression} AS sort_value FROM quotes q WHERE q.id = @cursor_id LIMIT 1',
          ),
          parameters: params,
        );
        return rows.isEmpty ? null : rows.first[0];
      case 'cheques':
        final rows = await executor.execute(
          Sql.named(
            'SELECT ${sortSpec.expression} AS sort_value FROM cheques c WHERE c.id = @cursor_id LIMIT 1',
          ),
          parameters: params,
        );
        return rows.isEmpty ? null : rows.first[0];
      case 'promissory_notes':
        final rows = await executor.execute(
          Sql.named(
            'SELECT ${sortSpec.expression} AS sort_value FROM promissory_notes n WHERE n.id = @cursor_id LIMIT 1',
          ),
          parameters: params,
        );
        return rows.isEmpty ? null : rows.first[0];
    }
    return null;
  }

  static Future<_CandidatePage> _fetchCandidatePage({
    required Session executor,
    required String normalizedQuery,
    required List<String> tables,
    required String rootTable,
    required _ParsedSort sort,
    required _ParsedFilters filters,
    required int limit,
    required _ParsedCursor? cursor,
    required String? companyId,
  }) async {
    final sortSpec = _resolveSort(rootTable, sort, filters);
    if (sortSpec == null) {
      return const _CandidatePage(
        rows: <_CandidateRow>[],
        nextScanCursor: null,
        exhausted: true,
      );
    }

    final params = <String, dynamic>{'limit': limit.clamp(1, 500)};
    if (rootTable == 'products' &&
        sort.field == 'root_stock' &&
        filters.warehouseId != null) {
      params['sort_product_warehouse_id'] = filters.warehouseId!;
    }

    final where = <String>[];
    String fromClause;
    String idExpr;
    String rootSearchExpr;
    String? requiredChildExists;
    String? childSearchExists;
    bool allowRootSearch = true;

    switch (rootTable) {
      case 'products':
        fromClause = 'products p';
        idExpr = 'p.id';
        rootSearchExpr = 'p.search_tags';
        if (filters.rootId != null) {
          where.add('p.id = @root_id');
          params['root_id'] = filters.rootId!;
        }
        if (filters.rootActive != null) {
          where.add('p.aktif_mi = @root_aktif');
          params['root_aktif'] = filters.rootActive! ? 1 : 0;
        }
        if (filters.rootGroup != null) {
          where.add('p.grubu = @root_group');
          params['root_group'] = filters.rootGroup!;
        }
        if (filters.rootUnit != null) {
          where.add('p.birim = @root_unit');
          params['root_unit'] = filters.rootUnit!;
        }
        if (filters.rootVat != null) {
          where.add('p.kdv_orani = @root_vat');
          params['root_vat'] = filters.rootVat!;
        }
        if (filters.warehouseId != null) {
          requiredChildExists = '''
            EXISTS (
              SELECT 1
              FROM warehouse_stocks wsf
              WHERE wsf.product_code = p.kod
                AND wsf.warehouse_id = @product_warehouse_id
                AND wsf.quantity > 0
            )
          ''';
          params['product_warehouse_id'] = filters.warehouseId!;
        }
        if (tables.contains('stock_movements')) {
          final childBase = _buildChildMembershipClause(
            rootIdExpr: 'p.id',
            childTable: 'stock_movements',
            childAlias: 'sm',
            parentIdExprs: const <String>['sm.product_id'],
            searchTagsExpr: 'sm.search_tags',
            params: params,
            filters: filters,
            companyId: companyId,
            includeSearch: true,
            normalizedQuery: normalizedQuery,
            dateColumn: 'sm.movement_date',
            userColumn: 'sm.created_by',
            unitColumn: null,
            warehouseCondition: 'sm.warehouse_id = @sm_warehouse_id',
          );
          childSearchExists = childBase;
          if (filters.userName != null ||
              filters.sourceType != null ||
              filters.transactionDateRange.start != null ||
              filters.transactionDateRange.endExclusive != null) {
            requiredChildExists ??= _buildChildMembershipClause(
              rootIdExpr: 'p.id',
              childTable: 'stock_movements',
              childAlias: 'smf',
              parentIdExprs: const <String>['smf.product_id'],
              searchTagsExpr: 'smf.search_tags',
              params: params,
              filters: filters,
              companyId: companyId,
              includeSearch: false,
              normalizedQuery: normalizedQuery,
              dateColumn: 'smf.movement_date',
              userColumn: 'smf.created_by',
              warehouseCondition: filters.warehouseId == null
                  ? null
                  : 'smf.warehouse_id = @smf_warehouse_id',
            );
          }
        }
        break;
      case 'productions':
        fromClause = 'productions pr';
        idExpr = 'pr.id';
        rootSearchExpr = 'pr.search_tags';
        if (filters.rootId != null) {
          where.add('pr.id = @root_id');
          params['root_id'] = filters.rootId!;
        }
        if (filters.rootActive != null) {
          where.add('pr.aktif_mi = @root_aktif');
          params['root_aktif'] = filters.rootActive! ? 1 : 0;
        }
        if (filters.rootGroup != null) {
          where.add('pr.grubu = @root_group');
          params['root_group'] = filters.rootGroup!;
        }
        if (filters.rootUnit != null) {
          where.add('pr.birim = @root_unit');
          params['root_unit'] = filters.rootUnit!;
        }
        if (filters.rootVat != null) {
          where.add('pr.kdv_orani = @root_vat');
          params['root_vat'] = filters.rootVat!;
        }
        if (filters.warehouseId != null) {
          requiredChildExists = '''
            EXISTS (
              SELECT 1
              FROM production_stock_movements psm_depo
              WHERE psm_depo.production_id = pr.id
                AND psm_depo.warehouse_id = @production_warehouse_id
            )
          ''';
          params['production_warehouse_id'] = filters.warehouseId!;
        }
        if (tables.contains('production_stock_movements')) {
          childSearchExists = _buildChildMembershipClause(
            rootIdExpr: 'pr.id',
            childTable: 'production_stock_movements',
            childAlias: 'psm',
            parentIdExprs: const <String>['psm.production_id'],
            searchTagsExpr: 'psm.search_tags',
            params: params,
            filters: filters,
            companyId: companyId,
            includeSearch: true,
            normalizedQuery: normalizedQuery,
            dateColumn: 'psm.movement_date',
            userColumn: 'psm.created_by',
            warehouseCondition: 'psm.warehouse_id = @psm_warehouse_id',
          );
          if (filters.userName != null ||
              filters.sourceType != null ||
              filters.transactionDateRange.start != null ||
              filters.transactionDateRange.endExclusive != null) {
            requiredChildExists ??= _buildChildMembershipClause(
              rootIdExpr: 'pr.id',
              childTable: 'production_stock_movements',
              childAlias: 'psmf',
              parentIdExprs: const <String>['psmf.production_id'],
              searchTagsExpr: 'psmf.search_tags',
              params: params,
              filters: filters,
              companyId: companyId,
              includeSearch: false,
              normalizedQuery: normalizedQuery,
              dateColumn: 'psmf.movement_date',
              userColumn: 'psmf.created_by',
              warehouseCondition: filters.warehouseId == null
                  ? null
                  : 'psmf.warehouse_id = @psmf_warehouse_id',
            );
          }
        }
        break;
      case 'current_accounts':
        fromClause = 'current_accounts ca';
        idExpr = 'ca.id';
        rootSearchExpr = 'ca.search_tags';
        if (filters.rootId != null) {
          where.add('ca.id = @root_id');
          params['root_id'] = filters.rootId!;
        }
        if (filters.rootActive != null) {
          where.add('ca.aktif_mi = @root_aktif');
          params['root_aktif'] = filters.rootActive! ? 1 : 0;
        }
        if (filters.rootAccountType != null) {
          where.add('ca.hesap_turu = @root_account_type');
          params['root_account_type'] = filters.rootAccountType!;
        }
        if (filters.rootCity != null) {
          where.add('ca.fat_sehir = @root_city');
          params['root_city'] = filters.rootCity!;
        }
        if (tables.contains('current_account_transactions')) {
          if (filters.tableScope != null &&
              filters.tableScope != 'current_account_transactions') {
            allowRootSearch = false;
          }
          childSearchExists = _buildChildMembershipClause(
            rootIdExpr: 'ca.id',
            childTable: 'current_account_transactions',
            childAlias: 'cat',
            parentIdExprs: const <String>['cat.current_account_id'],
            searchTagsExpr: 'cat.search_tags',
            params: params,
            filters: filters,
            companyId: companyId,
            includeSearch: true,
            normalizedQuery: normalizedQuery,
            dateColumn: 'cat.date',
            userColumn: 'cat.user_name',
          );
          if (filters.hasGenericChildFilters) {
            requiredChildExists = _buildChildMembershipClause(
              rootIdExpr: 'ca.id',
              childTable: 'current_account_transactions',
              childAlias: 'catf',
              parentIdExprs: const <String>['catf.current_account_id'],
              searchTagsExpr: 'catf.search_tags',
              params: params,
              filters: filters,
              companyId: companyId,
              includeSearch: false,
              normalizedQuery: normalizedQuery,
              dateColumn: 'catf.date',
              userColumn: 'catf.user_name',
            );
          }
        }
        break;
      case 'banks':
        fromClause = 'banks b';
        idExpr = 'b.id';
        rootSearchExpr = 'b.search_tags';
        _addCompanyCondition(
          where,
          params,
          table: 'banks',
          column: 'b.company_id',
          companyId: companyId,
        );
        if (filters.rootId != null) {
          where.add('b.id = @root_id');
          params['root_id'] = filters.rootId!;
        }
        if (filters.rootActive != null) {
          where.add('b.is_active = @root_aktif');
          params['root_aktif'] = filters.rootActive! ? 1 : 0;
        }
        if (filters.rootIsDefault != null) {
          where.add('b.is_default = @root_default');
          params['root_default'] = filters.rootIsDefault! ? 1 : 0;
        }
        if (tables.contains('bank_transactions')) {
          childSearchExists = _buildChildMembershipClause(
            rootIdExpr: 'b.id',
            childTable: 'bank_transactions',
            childAlias: 'bt',
            parentIdExprs: const <String>['bt.bank_id'],
            searchTagsExpr: 'bt.search_tags',
            params: params,
            filters: filters,
            companyId: companyId,
            includeSearch: true,
            normalizedQuery: normalizedQuery,
            companyColumn: 'bt.company_id',
            dateColumn: 'bt.date',
            userColumn: 'bt.user_name',
            typeColumn: 'bt.type',
          );
          if (filters.hasGenericChildFilters) {
            allowRootSearch = filters.tableScope == null;
            requiredChildExists = _buildChildMembershipClause(
              rootIdExpr: 'b.id',
              childTable: 'bank_transactions',
              childAlias: 'btf',
              parentIdExprs: const <String>['btf.bank_id'],
              searchTagsExpr: 'btf.search_tags',
              params: params,
              filters: filters,
              companyId: companyId,
              includeSearch: false,
              normalizedQuery: normalizedQuery,
              companyColumn: 'btf.company_id',
              dateColumn: 'btf.date',
              userColumn: 'btf.user_name',
              typeColumn: 'btf.type',
            );
          }
        }
        break;
      case 'cash_registers':
        fromClause = 'cash_registers cr';
        idExpr = 'cr.id';
        rootSearchExpr = 'cr.search_tags';
        _addCompanyCondition(
          where,
          params,
          table: 'cash_registers',
          column: 'cr.company_id',
          companyId: companyId,
        );
        if (filters.rootId != null) {
          where.add('cr.id = @root_id');
          params['root_id'] = filters.rootId!;
        }
        if (filters.rootActive != null) {
          where.add('cr.is_active = @root_aktif');
          params['root_aktif'] = filters.rootActive! ? 1 : 0;
        }
        if (filters.rootIsDefault != null) {
          where.add('cr.is_default = @root_default');
          params['root_default'] = filters.rootIsDefault! ? 1 : 0;
        }
        if (tables.contains('cash_register_transactions')) {
          childSearchExists = _buildChildMembershipClause(
            rootIdExpr: 'cr.id',
            childTable: 'cash_register_transactions',
            childAlias: 'crt',
            parentIdExprs: const <String>['crt.cash_register_id'],
            searchTagsExpr: 'crt.search_tags',
            params: params,
            filters: filters,
            companyId: companyId,
            includeSearch: true,
            normalizedQuery: normalizedQuery,
            companyColumn: 'crt.company_id',
            dateColumn: 'crt.date',
            userColumn: 'crt.user_name',
            typeColumn: 'crt.type',
          );
          if (filters.hasGenericChildFilters) {
            allowRootSearch = filters.tableScope == null;
            requiredChildExists = _buildChildMembershipClause(
              rootIdExpr: 'cr.id',
              childTable: 'cash_register_transactions',
              childAlias: 'crtf',
              parentIdExprs: const <String>['crtf.cash_register_id'],
              searchTagsExpr: 'crtf.search_tags',
              params: params,
              filters: filters,
              companyId: companyId,
              includeSearch: false,
              normalizedQuery: normalizedQuery,
              companyColumn: 'crtf.company_id',
              dateColumn: 'crtf.date',
              userColumn: 'crtf.user_name',
              typeColumn: 'crtf.type',
            );
          }
        }
        break;
      case 'credit_cards':
        fromClause = 'credit_cards cc';
        idExpr = 'cc.id';
        rootSearchExpr = 'cc.search_tags';
        _addCompanyCondition(
          where,
          params,
          table: 'credit_cards',
          column: 'cc.company_id',
          companyId: companyId,
        );
        if (filters.rootId != null) {
          where.add('cc.id = @root_id');
          params['root_id'] = filters.rootId!;
        }
        if (filters.rootActive != null) {
          where.add('cc.is_active = @root_aktif');
          params['root_aktif'] = filters.rootActive! ? 1 : 0;
        }
        if (filters.rootIsDefault != null) {
          where.add('cc.is_default = @root_default');
          params['root_default'] = filters.rootIsDefault! ? 1 : 0;
        }
        if (tables.contains('credit_card_transactions')) {
          childSearchExists = _buildChildMembershipClause(
            rootIdExpr: 'cc.id',
            childTable: 'credit_card_transactions',
            childAlias: 'cct',
            parentIdExprs: const <String>['cct.credit_card_id'],
            searchTagsExpr: 'cct.search_tags',
            params: params,
            filters: filters,
            companyId: companyId,
            includeSearch: true,
            normalizedQuery: normalizedQuery,
            companyColumn: 'cct.company_id',
            dateColumn: 'cct.date',
            userColumn: 'cct.user_name',
            typeColumn: 'cct.type',
          );
          if (filters.hasGenericChildFilters) {
            allowRootSearch = filters.tableScope == null;
            requiredChildExists = _buildChildMembershipClause(
              rootIdExpr: 'cc.id',
              childTable: 'credit_card_transactions',
              childAlias: 'cctf',
              parentIdExprs: const <String>['cctf.credit_card_id'],
              searchTagsExpr: 'cctf.search_tags',
              params: params,
              filters: filters,
              companyId: companyId,
              includeSearch: false,
              normalizedQuery: normalizedQuery,
              companyColumn: 'cctf.company_id',
              dateColumn: 'cctf.date',
              userColumn: 'cctf.user_name',
              typeColumn: 'cctf.type',
            );
          }
        }
        break;
      case 'depots':
        fromClause = 'depots d';
        idExpr = 'd.id';
        rootSearchExpr = 'd.search_tags';
        if (filters.rootId != null) {
          where.add('d.id = @root_id');
          params['root_id'] = filters.rootId!;
        }
        if (filters.rootActive != null) {
          where.add('d.aktif_mi = @root_aktif');
          params['root_aktif'] = filters.rootActive! ? 1 : 0;
        }
        if (tables.contains('shipments')) {
          final childWarehouseCondition =
              '(s.source_warehouse_id = @s_warehouse_id OR s.dest_warehouse_id = @s_warehouse_id)';
          childSearchExists = _buildChildMembershipClause(
            rootIdExpr: 'd.id',
            childTable: 'shipments',
            childAlias: 's',
            parentIdExprs: const <String>[
              's.source_warehouse_id',
              's.dest_warehouse_id',
            ],
            searchTagsExpr: 's.search_tags',
            params: params,
            filters: filters,
            companyId: companyId,
            includeSearch: true,
            normalizedQuery: normalizedQuery,
            dateColumn: 's.date',
            userColumn: 's.created_by',
            warehouseCondition: childWarehouseCondition,
          );
          if (filters.hasGenericChildFilters) {
            allowRootSearch = filters.tableScope == null;
            requiredChildExists = _buildChildMembershipClause(
              rootIdExpr: 'd.id',
              childTable: 'shipments',
              childAlias: 'sf',
              parentIdExprs: const <String>[
                'sf.source_warehouse_id',
                'sf.dest_warehouse_id',
              ],
              searchTagsExpr: 'sf.search_tags',
              params: params,
              filters: filters,
              companyId: companyId,
              includeSearch: false,
              normalizedQuery: normalizedQuery,
              dateColumn: 'sf.date',
              userColumn: 'sf.created_by',
              warehouseCondition:
                  '(sf.source_warehouse_id = @sf_warehouse_id OR sf.dest_warehouse_id = @sf_warehouse_id)',
            );
          }
        }
        break;
      case 'expenses':
        fromClause = 'expenses e';
        idExpr = 'e.id';
        rootSearchExpr = 'e.search_tags';
        if (filters.rootId != null) {
          where.add('e.id = @root_id');
          params['root_id'] = filters.rootId!;
        }
        if (filters.rootActive != null) {
          where.add('e.aktif_mi = @root_aktif');
          params['root_aktif'] = filters.rootActive! ? 1 : 0;
        }
        if (filters.rootCategory != null) {
          where.add('e.kategori = @root_category');
          params['root_category'] = filters.rootCategory!;
        }
        if (filters.rootPaymentStatus != null) {
          where.add('e.odeme_durumu = @root_payment_status');
          params['root_payment_status'] = filters.rootPaymentStatus!;
        }
        if (filters.rootUser != null) {
          where.add('e.kullanici = @root_user');
          params['root_user'] = filters.rootUser!;
        }
        _addDateRangeCondition(
          where,
          params,
          expression: 'e.tarih',
          paramPrefix: 'expense_root_date_',
          range: filters.rootDateRange,
        );
        if (tables.contains('expense_items')) {
          childSearchExists = _buildChildMembershipClause(
            rootIdExpr: 'e.id',
            childTable: 'expense_items',
            childAlias: 'ei',
            parentIdExprs: const <String>['ei.expense_id'],
            searchTagsExpr: 'ei.search_tags',
            params: params,
            filters: filters,
            companyId: companyId,
            includeSearch: true,
            normalizedQuery: normalizedQuery,
          );
        }
        break;
      case 'orders':
        fromClause = 'orders o';
        idExpr = 'o.id';
        rootSearchExpr = 'o.search_tags';
        if (filters.rootId != null) {
          where.add('o.id = @root_id');
          params['root_id'] = filters.rootId!;
        }
        if (filters.rootType != null) {
          where.add('o.tur = @root_type');
          params['root_type'] = filters.rootType!;
        }
        if (filters.rootStatus != null) {
          where.add('o.durum = @root_status');
          params['root_status'] = filters.rootStatus!;
        }
        if (filters.rootAccount != null) {
          where.add('o.ilgili_hesap_adi = @root_account');
          params['root_account'] = filters.rootAccount!;
        }
        if (filters.rootUser != null) {
          where.add('o.kullanici = @root_user');
          params['root_user'] = filters.rootUser!;
        }
        _addDateRangeCondition(
          where,
          params,
          expression: 'o.tarih',
          paramPrefix: 'order_root_date_',
          range: filters.rootDateRange,
        );
        if (tables.contains('order_items')) {
          childSearchExists = _buildChildMembershipClause(
            rootIdExpr: 'o.id',
            childTable: 'order_items',
            childAlias: 'oi',
            parentIdExprs: const <String>['oi.order_id'],
            searchTagsExpr: 'oi.search_tags',
            params: params,
            filters: filters,
            companyId: companyId,
            includeSearch: true,
            normalizedQuery: normalizedQuery,
            unitColumn: 'oi.birim',
            warehouseCondition: 'oi.depo_id = @oi_warehouse_id',
          );
          if (filters.warehouseId != null || filters.unit != null) {
            requiredChildExists = _buildChildMembershipClause(
              rootIdExpr: 'o.id',
              childTable: 'order_items',
              childAlias: 'oif',
              parentIdExprs: const <String>['oif.order_id'],
              searchTagsExpr: 'oif.search_tags',
              params: params,
              filters: filters,
              companyId: companyId,
              includeSearch: false,
              normalizedQuery: normalizedQuery,
              unitColumn: 'oif.birim',
              warehouseCondition: filters.warehouseId == null
                  ? null
                  : 'oif.depo_id = @oif_warehouse_id',
            );
          }
        }
        break;
      case 'quotes':
        fromClause = 'quotes q';
        idExpr = 'q.id';
        rootSearchExpr = 'q.search_tags';
        if (filters.rootId != null) {
          where.add('q.id = @root_id');
          params['root_id'] = filters.rootId!;
        }
        if (filters.rootType != null) {
          where.add('q.tur = @root_type');
          params['root_type'] = filters.rootType!;
        }
        if (filters.rootStatus != null) {
          where.add('q.durum = @root_status');
          params['root_status'] = filters.rootStatus!;
        }
        if (filters.rootAccount != null) {
          where.add('q.ilgili_hesap_adi = @root_account');
          params['root_account'] = filters.rootAccount!;
        }
        if (filters.rootUser != null) {
          where.add('q.kullanici = @root_user');
          params['root_user'] = filters.rootUser!;
        }
        _addDateRangeCondition(
          where,
          params,
          expression: 'q.tarih',
          paramPrefix: 'quote_root_date_',
          range: filters.rootDateRange,
        );
        if (tables.contains('quote_items')) {
          childSearchExists = _buildChildMembershipClause(
            rootIdExpr: 'q.id',
            childTable: 'quote_items',
            childAlias: 'qi',
            parentIdExprs: const <String>['qi.quote_id'],
            searchTagsExpr: 'qi.search_tags',
            params: params,
            filters: filters,
            companyId: companyId,
            includeSearch: true,
            normalizedQuery: normalizedQuery,
            unitColumn: 'qi.birim',
            warehouseCondition: 'qi.depo_id = @qi_warehouse_id',
          );
          if (filters.warehouseId != null || filters.unit != null) {
            requiredChildExists = _buildChildMembershipClause(
              rootIdExpr: 'q.id',
              childTable: 'quote_items',
              childAlias: 'qif',
              parentIdExprs: const <String>['qif.quote_id'],
              searchTagsExpr: 'qif.search_tags',
              params: params,
              filters: filters,
              companyId: companyId,
              includeSearch: false,
              normalizedQuery: normalizedQuery,
              unitColumn: 'qif.birim',
              warehouseCondition: filters.warehouseId == null
                  ? null
                  : 'qif.depo_id = @qif_warehouse_id',
            );
          }
        }
        break;
      case 'cheques':
        fromClause = 'cheques c';
        idExpr = 'c.id';
        rootSearchExpr = 'c.search_tags';
        _addCompanyCondition(
          where,
          params,
          table: 'cheques',
          column: 'c.company_id',
          companyId: companyId,
        );
        if (filters.rootId != null) {
          where.add('c.id = @root_id');
          params['root_id'] = filters.rootId!;
        }
        if (filters.rootBank != null) {
          where.add('c.bank = @root_bank');
          params['root_bank'] = filters.rootBank!;
        }
        if (tables.contains('cheque_transactions')) {
          if (filters.tableScope != null &&
              filters.tableScope != 'cheque_transactions') {
            allowRootSearch = false;
          } else if (filters.tableScope == 'cheque_transactions') {
            allowRootSearch = false;
          }
          childSearchExists = _buildChildMembershipClause(
            rootIdExpr: 'c.id',
            childTable: 'cheque_transactions',
            childAlias: 'ct',
            parentIdExprs: const <String>['ct.cheque_id'],
            searchTagsExpr: 'ct.search_tags',
            params: params,
            filters: filters,
            companyId: companyId,
            includeSearch: true,
            normalizedQuery: normalizedQuery,
            companyColumn: 'ct.company_id',
            dateColumn: 'ct.date',
            userColumn: 'ct.user_name',
            typeColumn: 'ct.type',
          );
          if (filters.hasGenericChildFilters || filters.tableScope != null) {
            requiredChildExists = _buildChildMembershipClause(
              rootIdExpr: 'c.id',
              childTable: 'cheque_transactions',
              childAlias: 'ctf',
              parentIdExprs: const <String>['ctf.cheque_id'],
              searchTagsExpr: 'ctf.search_tags',
              params: params,
              filters: filters,
              companyId: companyId,
              includeSearch: false,
              normalizedQuery: normalizedQuery,
              companyColumn: 'ctf.company_id',
              dateColumn: 'ctf.date',
              userColumn: 'ctf.user_name',
              typeColumn: 'ctf.type',
            );
          }
        }
        break;
      case 'promissory_notes':
        fromClause = 'promissory_notes n';
        idExpr = 'n.id';
        rootSearchExpr = 'n.search_tags';
        _addCompanyCondition(
          where,
          params,
          table: 'promissory_notes',
          column: 'n.company_id',
          companyId: companyId,
        );
        if (filters.rootId != null) {
          where.add('n.id = @root_id');
          params['root_id'] = filters.rootId!;
        }
        if (filters.rootBank != null) {
          where.add('n.bank = @root_bank');
          params['root_bank'] = filters.rootBank!;
        }
        if (tables.contains('note_transactions')) {
          if (filters.tableScope != null &&
              filters.tableScope != 'note_transactions') {
            allowRootSearch = false;
          } else if (filters.tableScope == 'note_transactions') {
            allowRootSearch = false;
          }
          childSearchExists = _buildChildMembershipClause(
            rootIdExpr: 'n.id',
            childTable: 'note_transactions',
            childAlias: 'nt',
            parentIdExprs: const <String>['nt.note_id'],
            searchTagsExpr: 'nt.search_tags',
            params: params,
            filters: filters,
            companyId: companyId,
            includeSearch: true,
            normalizedQuery: normalizedQuery,
            companyColumn: 'nt.company_id',
            dateColumn: 'nt.date',
            userColumn: 'nt.user_name',
            typeColumn: 'nt.type',
          );
          if (filters.hasGenericChildFilters || filters.tableScope != null) {
            requiredChildExists = _buildChildMembershipClause(
              rootIdExpr: 'n.id',
              childTable: 'note_transactions',
              childAlias: 'ntf',
              parentIdExprs: const <String>['ntf.note_id'],
              searchTagsExpr: 'ntf.search_tags',
              params: params,
              filters: filters,
              companyId: companyId,
              includeSearch: false,
              normalizedQuery: normalizedQuery,
              companyColumn: 'ntf.company_id',
              dateColumn: 'ntf.date',
              userColumn: 'ntf.user_name',
              typeColumn: 'ntf.type',
            );
          }
        }
        break;
      default:
        return const _CandidatePage(
          rows: <_CandidateRow>[],
          nextScanCursor: null,
          exhausted: true,
        );
    }

    if (cursor != null && sort.field != 'root_id' && cursor.sortValue == null) {
      final resolved = await _resolveCursorSortValue(
        executor,
        rootTable: rootTable,
        sort: sort,
        filters: filters,
        rootId: cursor.rootId,
      );
      if (resolved != null) {
        cursor = _ParsedCursor(rootId: cursor.rootId, sortValue: resolved);
      }
    }

    if (requiredChildExists != null && requiredChildExists.trim().isNotEmpty) {
      where.add(requiredChildExists);
    }

    final searchParts = <String>[];
    if (allowRootSearch) {
      searchParts.add(
        _searchClause(
          expression: rootSearchExpr,
          paramPrefix: 'root_query_',
          normalizedQuery: normalizedQuery,
          params: params,
        ),
      );
    }
    if (childSearchExists != null && childSearchExists.trim().isNotEmpty) {
      searchParts.add(childSearchExists);
    }
    if (searchParts.isEmpty) {
      return const _CandidatePage(
        rows: <_CandidateRow>[],
        nextScanCursor: null,
        exhausted: true,
      );
    }
    where.add('(${searchParts.join(' OR ')})');

    if (cursor != null) {
      where.add(
        _cursorWhere(
          idExpr: idExpr,
          sortExpr: sortSpec.expression,
          type: sortSpec.type,
          ascending: sort.ascending,
          cursor: cursor,
          params: params,
        ),
      );
    }

    final direction = sort.ascending ? 'ASC' : 'DESC';
    final query =
        '''
      SELECT $idExpr AS root_id, ${sortSpec.expression} AS sort_value
      FROM $fromClause
      WHERE ${where.join(' AND ')}
      ORDER BY ${sortSpec.expression} $direction, $idExpr $direction
      LIMIT @limit
    ''';

    final result = await executor.execute(Sql.named(query), parameters: params);
    final rows = <_CandidateRow>[];
    for (final row in result) {
      final rawId = row[0];
      final rootId = rawId is int
          ? rawId
          : rawId is BigInt
          ? rawId.toInt()
          : int.tryParse(rawId?.toString() ?? '');
      if (rootId == null || rootId <= 0) continue;
      rows.add(_CandidateRow(rootId: rootId, sortValue: row[1]));
    }

    return _CandidatePage(
      rows: rows,
      nextScanCursor: rows.isEmpty
          ? cursor
          : _ParsedCursor(
              rootId: rows.last.rootId,
              sortValue: rows.last.sortValue,
            ),
      exhausted: rows.length < limit,
    );
  }

  /// Harici arama motoru yok; sadece PostgreSQL index-first akış.
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
    if (normalized.isEmpty || normalized.length < 2) {
      return AramaIndexPrimaryPathResult<T>(
        indexEnabled: false,
        rows: <T>[],
        hasNextPage: false,
        nextCursor: null,
      );
    }

    final sort = _parseSort(sortBy);
    if (sort == null) {
      return AramaIndexPrimaryPathResult<T>(
        indexEnabled: false,
        rows: <T>[],
        hasNextPage: false,
        nextCursor: null,
      );
    }

    final tables = tablolar
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && _isSafeIdent(e))
        .toList(growable: false);
    if (tables.isEmpty) {
      return AramaIndexPrimaryPathResult<T>(
        indexEnabled: false,
        rows: <T>[],
        hasNextPage: false,
        nextCursor: null,
      );
    }

    final pool = await _poolBestEffort();
    if (pool == null) {
      return AramaIndexPrimaryPathResult<T>(
        indexEnabled: false,
        rows: <T>[],
        hasNextPage: false,
        nextCursor: null,
      );
    }

    final dbName = OturumServisi().aktifVeritabaniAdi;
    final indexReady = await _isIndexReadyCached(
      pool,
      databaseName: dbName,
      tables: tables,
    );
    if (!indexReady) {
      return AramaIndexPrimaryPathResult<T>(
        indexEnabled: false,
        rows: <T>[],
        hasNextPage: false,
        nextCursor: null,
      );
    }

    final parsedFilters = _parseExtraFilter(extraFilter);
    final mergedFilters = _ParsedFilters(
      rootId: parsedFilters.rootId,
      rootActive: parsedFilters.rootActive,
      rootIsDefault: parsedFilters.rootIsDefault,
      rootType: parsedFilters.rootType,
      rootStatus: parsedFilters.rootStatus,
      rootAccount: parsedFilters.rootAccount,
      rootUser: parsedFilters.rootUser,
      rootAccountType: parsedFilters.rootAccountType,
      rootCity: parsedFilters.rootCity,
      rootCategory: parsedFilters.rootCategory,
      rootPaymentStatus: parsedFilters.rootPaymentStatus,
      rootGroup: parsedFilters.rootGroup,
      rootUnit: parsedFilters.rootUnit,
      rootBank: parsedFilters.rootBank,
      rootVat: parsedFilters.rootVat,
      warehouseId: parsedFilters.warehouseId,
      unit: parsedFilters.unit,
      userName: parsedFilters.userName,
      sourceType: parsedFilters.sourceType,
      type: parsedFilters.type,
      tableScope: parsedFilters.tableScope,
      integrationRefPrefixes: parsedFilters.integrationRefPrefixes,
      rootDateRange:
          parsedFilters.rootDateRange.start != null ||
              parsedFilters.rootDateRange.endExclusive != null
          ? parsedFilters.rootDateRange
          : _ParsedRange(
              start: startDate == null
                  ? null
                  : DateTime(startDate.year, startDate.month, startDate.day),
              endExclusive: endDate == null
                  ? null
                  : DateTime(
                      endDate.year,
                      endDate.month,
                      endDate.day,
                    ).add(const Duration(days: 1)),
            ),
      transactionDateRange:
          parsedFilters.transactionDateRange.start != null ||
              parsedFilters.transactionDateRange.endExclusive != null
          ? parsedFilters.transactionDateRange
          : _ParsedRange(
              start: startDate == null
                  ? null
                  : DateTime(startDate.year, startDate.month, startDate.day),
              endExclusive: endDate == null
                  ? null
                  : DateTime(
                      endDate.year,
                      endDate.month,
                      endDate.day,
                    ).add(const Duration(days: 1)),
            ),
    );

    final safePageSize = pageSize.clamp(1, 200);
    final scanBatchSize = (safePageSize * 4).clamp(40, 400);
    final loops = maxIndexLoops.clamp(1, 24);
    final companyId = dbName.trim().isEmpty ? null : dbName.trim();

    final collected = <T>[];
    final seenRootIds = <int>{};
    final candidateById = <int, _CandidateRow>{};
    var scanCursor = _parseCursor(cursor);
    var exhausted = false;

    // API stabilitesi için callback'e dokun.
    final _ = setMatchedInHidden;

    try {
      for (var i = 0; i < loops; i++) {
        if (collected.length >= safePageSize + 1 || exhausted) break;

        final candidatePage = await _fetchCandidatePage(
          executor: pool,
          normalizedQuery: normalized,
          tables: tables,
          rootTable: rootTable.trim(),
          sort: sort,
          filters: mergedFilters,
          limit: scanBatchSize,
          cursor: scanCursor,
          companyId: companyId,
        );

        if (candidatePage.rows.isEmpty) {
          exhausted = true;
          break;
        }

        scanCursor = candidatePage.nextScanCursor;
        exhausted = candidatePage.exhausted;

        final batchIds = <int>[];
        for (final candidate in candidatePage.rows) {
          if (!seenRootIds.add(candidate.rootId)) continue;
          batchIds.add(candidate.rootId);
          candidateById[candidate.rootId] = candidate;
        }
        if (batchIds.isEmpty) continue;

        final dbRows = await dbFetchByIds(batchIds);
        if (dbRows.isEmpty) continue;

        final byId = <int, T>{};
        for (final row in dbRows) {
          byId[idOf(row)] = row;
        }

        for (final id in batchIds) {
          final row = byId[id];
          if (row == null) continue;
          collected.add(row);
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
    String? nextCursorValue;
    if (page.isNotEmpty) {
      final lastId = idOf(page.last);
      final candidate = candidateById[lastId];
      nextCursorValue = _encodeCursor(candidate?.sortValue, lastId);
    }

    return AramaIndexPrimaryPathResult<T>(
      indexEnabled: true,
      rows: page,
      hasNextPage: hasNext,
      nextCursor: nextCursorValue,
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
      return AramaPrimaryPathResult<T>(indexEnabled: false, rows: <T>[]);
    }

    final tables = tablolar
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && _isSafeIdent(e))
        .toList(growable: false);
    if (tables.isEmpty) {
      return AramaPrimaryPathResult<T>(indexEnabled: false, rows: <T>[]);
    }

    final pool = await _poolBestEffort();
    if (pool == null) {
      return AramaPrimaryPathResult<T>(indexEnabled: false, rows: <T>[]);
    }

    final dbName = OturumServisi().aktifVeritabaniAdi;
    final indexReady = await _isIndexReadyCached(
      pool,
      databaseName: dbName,
      tables: tables,
    );
    if (!indexReady) {
      return AramaPrimaryPathResult<T>(indexEnabled: false, rows: <T>[]);
    }

    final parsedFilters = _ParsedFilters(
      rootId: null,
      rootActive: null,
      rootIsDefault: null,
      rootType: null,
      rootStatus: null,
      rootAccount: null,
      rootUser: null,
      rootAccountType: null,
      rootCity: null,
      rootCategory: null,
      rootPaymentStatus: null,
      rootGroup: null,
      rootUnit: null,
      rootBank: null,
      rootVat: null,
      warehouseId: null,
      unit: null,
      userName: null,
      sourceType: null,
      type: null,
      tableScope: null,
      integrationRefPrefixes: const <String>[],
      rootDateRange: _ParsedRange(
        start: startDate == null
            ? null
            : DateTime(startDate.year, startDate.month, startDate.day),
        endExclusive: endDate == null
            ? null
            : DateTime(
                endDate.year,
                endDate.month,
                endDate.day,
              ).add(const Duration(days: 1)),
      ),
      transactionDateRange: _ParsedRange(
        start: startDate == null
            ? null
            : DateTime(startDate.year, startDate.month, startDate.day),
        endExclusive: endDate == null
            ? null
            : DateTime(
                endDate.year,
                endDate.month,
                endDate.day,
              ).add(const Duration(days: 1)),
      ),
    );

    final safeLimit = limit.clamp(1, 500);
    final scanBatch = indexBatchRootIds.clamp(20, 1000);
    final loops = maxIndexCalls.clamp(1, 40);
    final maxCandidates = maxCandidateIds.clamp(100, 50000);

    final candidates = <int>[];
    final seen = <int>{};
    var cursor = lastRootId == null || lastRootId <= 0
        ? null
        : _ParsedCursor(rootId: lastRootId, sortValue: null);
    var exhausted = false;

    try {
      for (var i = 0; i < loops; i++) {
        if (candidates.length >= safeLimit ||
            candidates.length >= maxCandidates ||
            exhausted) {
          break;
        }

        final page = await _fetchCandidatePage(
          executor: pool,
          normalizedQuery: normalized,
          tables: tables,
          rootTable: rootTable.trim(),
          sort: _ParsedSort(field: 'root_id', ascending: sortAscending),
          filters: parsedFilters,
          limit: scanBatch,
          cursor: cursor,
          companyId: dbName.trim().isEmpty ? null : dbName.trim(),
        );

        if (page.rows.isEmpty) break;
        cursor = page.nextScanCursor;
        exhausted = page.exhausted;

        for (final row in page.rows) {
          if (!seen.add(row.rootId)) continue;
          candidates.add(row.rootId);
          if (candidates.length >= safeLimit ||
              candidates.length >= maxCandidates) {
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('AramaPrimaryPath: root-id path failed: $e');
      return AramaPrimaryPathResult<T>(indexEnabled: false, rows: <T>[]);
    }

    if (candidates.isEmpty) {
      return AramaPrimaryPathResult<T>(indexEnabled: true, rows: <T>[]);
    }

    final rows = await dbFetch(candidates, safeLimit);
    return AramaPrimaryPathResult<T>(indexEnabled: true, rows: rows);
  }
}
