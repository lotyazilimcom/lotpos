import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';

class VeritabaniApiHatasi implements Exception {
  final int statusCode;
  final String message;
  const VeritabaniApiHatasi(this.statusCode, this.message);

  @override
  String toString() => 'VeritabaniApiHatasi($statusCode): $message';
}

final class VeritabaniApiClient {
  final Uri readBaseUrl;
  final Uri writeBaseUrl;
  final String token;
  final Duration defaultTimeout;
  final http.Client _http;
  final Duration _writeStickyDuration;
  int _forceWriteUntilEpochMs = 0;
  bool _closed = false;

  VeritabaniApiClient({
    required Uri baseUrl,
    Uri? readBaseUrl,
    Uri? writeBaseUrl,
    required this.token,
    this.defaultTimeout = const Duration(seconds: 15),
    Duration writeStickyDuration = const Duration(seconds: 3),
    http.Client? httpClient,
  }) : readBaseUrl = _normalizeBaseUrl(readBaseUrl ?? baseUrl),
       writeBaseUrl = _normalizeBaseUrl(writeBaseUrl ?? baseUrl),
       _writeStickyDuration = writeStickyDuration,
       _http = httpClient ?? http.Client();

  bool get isClosed => _closed;

  Uri get baseUrl => writeBaseUrl;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _http.close();
  }

  Uri _u(Uri base, String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    return base.resolve(p);
  }

  static Uri _normalizeBaseUrl(Uri input) {
    // Ensure it behaves as a "directory" base for Uri.resolve.
    final p = input.path;
    if (p.isEmpty || p.endsWith('/')) return input;
    return input.replace(path: '$p/');
  }

  bool get _shouldForceWriteNow {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now < _forceWriteUntilEpochMs;
  }

  void _stickToWrite() {
    if (_writeStickyDuration <= Duration.zero) return;
    _forceWriteUntilEpochMs =
        DateTime.now().millisecondsSinceEpoch +
        _writeStickyDuration.inMilliseconds;
  }

  static String _stripLeadingComments(String sql) {
    var s = sql;
    while (true) {
      final trimmedLeft = s.trimLeft();
      if (trimmedLeft.startsWith('--')) {
        final idx = trimmedLeft.indexOf('\n');
        if (idx == -1) return '';
        s = trimmedLeft.substring(idx + 1);
        continue;
      }
      if (trimmedLeft.startsWith('/*')) {
        final end = trimmedLeft.indexOf('*/');
        if (end == -1) return '';
        s = trimmedLeft.substring(end + 2);
        continue;
      }
      return trimmedLeft;
    }
  }

  static String _firstKeywordLower(String sql) {
    final cleaned = _stripLeadingComments(sql);
    if (cleaned.isEmpty) return '';
    final m = RegExp(r'^([a-zA-Z]+)').firstMatch(cleaned);
    if (m == null) return '';
    return (m.group(1) ?? '').toLowerCase();
  }

  static bool _looksLikeReadOnlySql(String sql) {
    final cleaned = _stripLeadingComments(sql);
    if (cleaned.isEmpty) return false;
    final lower = cleaned.toLowerCase();
    final kw = _firstKeywordLower(lower);
    final isCandidate =
        kw == 'select' || kw == 'show' || kw == 'values' || kw == 'explain';
    if (!isCandidate) return false;

    // "SELECT ... FOR UPDATE/SHARE" gibi kilitleyen okumaları replica'ya yönlendirme.
    final lockPatterns = <RegExp>[
      RegExp(r'\bfor\s+update\b'),
      RegExp(r'\bfor\s+no\s+key\s+update\b'),
      RegExp(r'\bfor\s+share\b'),
      RegExp(r'\bfor\s+key\s+share\b'),
      RegExp(r'\block\s+table\b'),
    ];
    for (final p in lockPatterns) {
      if (p.hasMatch(lower)) return false;
    }

    // Session/sequence/advisory lock gibi replica'da riskli işlemler.
    if (RegExp(r'\bset_config\s*\(').hasMatch(lower)) return false;
    if (RegExp(r'\bpg_catalog\.set_config\s*\(').hasMatch(lower)) return false;
    if (RegExp(r'\bpg_(try_)?advisory_lock\s*\(').hasMatch(lower)) return false;
    if (RegExp(r'\bnextval\s*\(').hasMatch(lower)) return false;
    if (RegExp(r'\bsetval\s*\(').hasMatch(lower)) return false;
    if (RegExp(r'\bcurrval\s*\(').hasMatch(lower)) return false;

    // SELECT INTO yeni tablo oluşturur (write).
    if (RegExp(r'^\s*select\b[\s\S]*\binto\b').hasMatch(lower)) return false;

    return true;
  }

  Uri _baseUrlForSql(String sql) {
    if (readBaseUrl == writeBaseUrl) return writeBaseUrl;
    if (_shouldForceWriteNow) return writeBaseUrl;
    return _looksLikeReadOnlySql(sql) ? readBaseUrl : writeBaseUrl;
  }

  Map<String, String> _headers() {
    final v = token.trim();
    final auth = v.isEmpty ? '' : 'Bearer $v';
    return <String, String>{
      'Content-Type': 'application/json',
      if (auth.isNotEmpty) 'Authorization': auth,
    };
  }

  Future<Map<String, Object?>> _postJson(
    Uri baseUrl,
    String path,
    Map<String, Object?> body, {
    Duration? timeout,
  }) async {
    if (_closed) throw StateError('API client kapalı');

    final resp = await _http
        .post(_u(baseUrl, path), headers: _headers(), body: jsonEncode(body))
        .timeout(timeout ?? defaultTimeout);

    final text = resp.body;
    Object? decoded;
    try {
      decoded = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      decoded = null;
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final msg = decoded is Map && decoded['error'] != null
          ? decoded['error'].toString()
          : (text.isNotEmpty ? text : 'HTTP ${resp.statusCode}');
      throw VeritabaniApiHatasi(resp.statusCode, msg);
    }

    if (decoded is Map<String, dynamic>) {
      return decoded.map((k, v) => MapEntry(k, v as Object?));
    }
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v as Object?));
    }
    throw VeritabaniApiHatasi(resp.statusCode, 'Geçersiz JSON yanıtı');
  }

  Future<Result> execute(
    String database,
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    Duration? timeout,
  }) async {
    final wireQuery = _queryToWire(query);
    final sqlForRouting = (wireQuery['sql'] as String?) ?? '';
    final target = _baseUrlForSql(sqlForRouting);
    if (target == writeBaseUrl) {
      // write veya belirsiz: read-after-write tutarlılığı için kısa süre master'a yapış.
      _stickToWrite();
    }

    final body = <String, Object?>{
      'database': database.trim(),
      'query': wireQuery,
      if (parameters != null) 'parameters': _encodeValue(parameters),
      if (ignoreRows) 'ignoreRows': true,
      if (timeout != null) 'timeoutMs': timeout.inMilliseconds,
    };

    final json = await _postJson(target, '/v1/execute', body, timeout: timeout);
    return _decodeResult(json);
  }

  Future<String> txBegin(
    String database, {
    TransactionSettings? settings,
    Duration? timeout,
  }) async {
    _stickToWrite();
    final body = <String, Object?>{
      'database': database.trim(),
      if (settings != null) 'settings': _txSettingsToWire(settings),
    };
    final json = await _postJson(
      writeBaseUrl,
      '/v1/tx/begin',
      body,
      timeout: timeout,
    );
    final txId = (json['txId'] as String?)?.trim() ?? '';
    if (txId.isEmpty) {
      throw const VeritabaniApiHatasi(500, 'txId alınamadı');
    }
    return txId;
  }

  Future<Result> txExecute(
    String txId,
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    Duration? timeout,
  }) async {
    _stickToWrite();
    final body = <String, Object?>{
      'txId': txId.trim(),
      'query': _queryToWire(query),
      if (parameters != null) 'parameters': _encodeValue(parameters),
      if (ignoreRows) 'ignoreRows': true,
      if (timeout != null) 'timeoutMs': timeout.inMilliseconds,
    };
    final json = await _postJson(
      writeBaseUrl,
      '/v1/tx/execute',
      body,
      timeout: timeout,
    );
    return _decodeResult(json);
  }

  Future<void> txCommit(String txId, {Duration? timeout}) async {
    _stickToWrite();
    await _postJson(writeBaseUrl, '/v1/tx/commit', <String, Object?>{
      'txId': txId.trim(),
    }, timeout: timeout);
  }

  Future<void> txRollback(String txId, {Duration? timeout}) async {
    _stickToWrite();
    await _postJson(writeBaseUrl, '/v1/tx/rollback', <String, Object?>{
      'txId': txId.trim(),
    }, timeout: timeout);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wire helpers (query + params + result)
// ─────────────────────────────────────────────────────────────────────────────

Map<String, Object?> _txSettingsToWire(TransactionSettings s) {
  String? iso(IsolationLevel? v) {
    if (v == null) return null;
    return switch (v) {
      IsolationLevel.readCommitted => 'readCommitted',
      IsolationLevel.repeatableRead => 'repeatableRead',
      IsolationLevel.serializable => 'serializable',
      IsolationLevel.readUncommitted => 'readUncommitted',
    };
  }

  String? access(AccessMode? v) {
    if (v == null) return null;
    return switch (v) {
      AccessMode.readWrite => 'readWrite',
      AccessMode.readOnly => 'readOnly',
    };
  }

  String? def(DeferrableMode? v) {
    if (v == null) return null;
    return switch (v) {
      DeferrableMode.deferrable => 'deferrable',
      DeferrableMode.notDeferrable => 'notDeferrable',
    };
  }

  return <String, Object?>{
    if (s.isolationLevel != null) 'isolationLevel': iso(s.isolationLevel),
    if (s.accessMode != null) 'accessMode': access(s.accessMode),
    if (s.deferrable != null) 'deferrable': def(s.deferrable),
  };
}

Map<String, Object?> _queryToWire(Object query) {
  if (query is String) {
    return <String, Object?>{'sql': query, 'mode': 'none'};
  }

  final dyn = query as dynamic;
  final sql = (dyn.sql as String?) ?? query.toString();
  final substitution = (dyn.substitution as String?) ?? '@';
  final mode = dyn.mode?.toString() ?? '';
  if (mode.contains('named')) {
    return <String, Object?>{
      'sql': sql,
      'mode': 'named',
      'substitution': substitution,
    };
  }
  if (mode.contains('indexed')) {
    return <String, Object?>{
      'sql': sql,
      'mode': 'indexed',
      'substitution': substitution,
    };
  }
  return <String, Object?>{'sql': sql, 'mode': 'none'};
}

Object? _encodeValue(Object? value) {
  if (value == null) return null;
  if (value is String || value is num || value is bool) return value;
  if (value is DateTime) {
    return <String, Object?>{'__t': 'dt', 'v': value.toIso8601String()};
  }
  if (value is TypedValue) {
    return <String, Object?>{
      '__t': 'tv',
      'oid': value.type.oid,
      'isSqlNull': value.isSqlNull,
      'v': _encodeValue(value.value),
    };
  }
  if (value is List) {
    return value.map(_encodeValue).toList(growable: false);
  }
  if (value is Map) {
    final out = <String, Object?>{};
    for (final entry in value.entries) {
      out[entry.key.toString()] = _encodeValue(entry.value);
    }
    return out;
  }
  return <String, Object?>{'__t': 'str', 'v': value.toString()};
}

Object? _decodeValue(Object? value) {
  if (value == null) return null;
  if (value is String || value is num || value is bool) return value;
  if (value is List) return value.map(_decodeValue).toList(growable: false);
  if (value is Map) {
    final tag = (value['__t'] as String?)?.trim();
    if (tag == 'dt') {
      final raw = (value['v'] as String?)?.trim() ?? '';
      return DateTime.tryParse(raw);
    }
    if (tag == 'tv') {
      final oid = (value['oid'] as num?)?.toInt();
      final isSqlNull = value['isSqlNull'] == true;
      final inner = _decodeValue(value['v']);
      final Type t = switch (oid) {
        null => Type.unspecified,
        final int o when o == Type.jsonb.oid => Type.jsonb,
        final int o when o == Type.json.oid => Type.json,
        final int o when o == Type.jsonbArray.oid => Type.jsonbArray,
        _ => Type.unspecified,
      };
      return TypedValue(t, inner, isSqlNull: isSqlNull);
    }
    if (tag == 'str') {
      return (value['v'] as Object?)?.toString();
    }
    final out = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key == '__t') continue;
      out[entry.key.toString()] = _decodeValue(entry.value);
    }
    return out;
  }
  return value;
}

Result _decodeResult(Map<String, Object?> json) {
  final affectedRows = (json['affectedRows'] as num?)?.toInt() ?? 0;
  final schemaRaw = (json['schema'] as List?) ?? const [];
  final cols = <ResultSchemaColumn>[];
  for (final c in schemaRaw) {
    if (c is! Map) continue;
    final typeOid = (c['typeOid'] as num?)?.toInt() ?? 0;
    cols.add(
      ResultSchemaColumn(
        typeOid: typeOid,
        type: Type.unspecified,
        tableOid: (c['tableOid'] as num?)?.toInt(),
        columnOid: (c['columnOid'] as num?)?.toInt(),
        columnName: (c['columnName'] as String?)?.trim(),
        isBinaryEncoding: c['isBinary'] == true,
      ),
    );
  }

  final schema = ResultSchema(cols);
  final rowsRaw = (json['rows'] as List?) ?? const [];
  final sqlNullsRaw = (json['sqlNulls'] as List?) ?? const [];
  final rows = <ResultRow>[];
  for (var r = 0; r < rowsRaw.length; r++) {
    final rawRow = rowsRaw[r];
    if (rawRow is! List) continue;
    final values = rawRow.map(_decodeValue).toList(growable: false);
    final rawNulls = (r < sqlNullsRaw.length) ? sqlNullsRaw[r] : null;
    final nulls = rawNulls is List
        ? rawNulls.map((e) => e == true).toList(growable: false)
        : null;
    rows.add(ResultRow(values: values, schema: schema, sqlNulls: nulls));
  }

  return Result(rows: rows, affectedRows: affectedRows, schema: schema);
}
