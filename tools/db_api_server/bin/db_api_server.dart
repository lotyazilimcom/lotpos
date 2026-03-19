import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:postgres/postgres.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────────────────────────

final class _Env {
  static String get(String key, {String fallback = ''}) =>
      (Platform.environment[key] ?? fallback).trim();

  static int getInt(String key, {required int fallback}) =>
      int.tryParse(get(key)) ?? fallback;

  static bool getBool(String key, {bool fallback = false}) {
    final v = get(key).toLowerCase();
    if (v.isEmpty) return fallback;
    return v == '1' || v == 'true' || v == 'yes' || v == 'on';
  }
}

final class ApiConfig {
  final String bindHost;
  final int port;
  final String token;
  final bool allowAnon;
  final Duration requestTimeout;
  final Duration txTtl;
  final int maxActiveTx;
  final Duration cacheTtl;
  final int cacheMaxEntries;
  final int cacheMaxRows;
  final int maxBodyBytes;

  const ApiConfig({
    required this.bindHost,
    required this.port,
    required this.token,
    required this.allowAnon,
    required this.requestTimeout,
    required this.txTtl,
    required this.maxActiveTx,
    required this.cacheTtl,
    required this.cacheMaxEntries,
    required this.cacheMaxRows,
    required this.maxBodyBytes,
  });

  factory ApiConfig.fromEnv() {
    final port = _Env.getInt('LOSPOS_API_PORT', fallback: 8080).clamp(1, 65535);
    final bindHost = _Env.get('LOSPOS_API_BIND_HOST', fallback: '0.0.0.0');
    final token = _Env.get('LOSPOS_API_TOKEN');
    final allowAnon = _Env.getBool('LOSPOS_API_ALLOW_ANON', fallback: false);

    final timeoutMs = _Env.getInt(
      'LOSPOS_API_TIMEOUT_MS',
      fallback: 15000,
    ).clamp(250, 120000);

    final txTtlSec = _Env.getInt(
      'LOSPOS_API_TX_TTL_SEC',
      fallback: 90,
    ).clamp(10, 3600);

    final maxActiveTx = _Env.getInt(
      'LOSPOS_API_MAX_ACTIVE_TX',
      fallback: 64,
    ).clamp(1, 2000);

    final cacheTtlMs = _Env.getInt(
      'LOSPOS_API_CACHE_TTL_MS',
      fallback: 0,
    ).clamp(0, 600000);

    final cacheMaxEntries = _Env.getInt(
      'LOSPOS_API_CACHE_MAX_ENTRIES',
      fallback: 2000,
    ).clamp(0, 500000);

    final cacheMaxRows = _Env.getInt(
      'LOSPOS_API_CACHE_MAX_ROWS',
      fallback: 500,
    ).clamp(0, 100000);

    final maxBodyBytes = _Env.getInt(
      'LOSPOS_API_MAX_BODY_BYTES',
      fallback: 2 * 1024 * 1024,
    ).clamp(1024, 128 * 1024 * 1024);

    return ApiConfig(
      bindHost: bindHost,
      port: port,
      token: token,
      allowAnon: allowAnon,
      requestTimeout: Duration(milliseconds: timeoutMs),
      txTtl: Duration(seconds: txTtlSec),
      maxActiveTx: maxActiveTx,
      cacheTtl: Duration(milliseconds: cacheTtlMs),
      cacheMaxEntries: cacheMaxEntries,
      cacheMaxRows: cacheMaxRows,
      maxBodyBytes: maxBodyBytes,
    );
  }
}

final class DbConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final SslMode sslMode;
  final QueryMode queryMode;
  final int maxConnections;
  final bool requirePooler;

  const DbConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.sslMode,
    required this.queryMode,
    required this.maxConnections,
    required this.requirePooler,
  });

  factory DbConfig.fromEnv() {
    final rawHost = _Env.get('LOSPOS_DB_HOST', fallback: '127.0.0.1');
    final host = _cloudPoolerHost(rawHost);
    final port = _Env.getInt('LOSPOS_DB_PORT', fallback: 5432);
    final username = _Env.get('LOSPOS_DB_USER', fallback: 'lospos');
    final password = _Env.get('LOSPOS_DB_PASSWORD');

    final sslRaw = _Env.get('LOSPOS_DB_SSLMODE').toLowerCase();
    final sslMode = switch (sslRaw) {
      'require' => SslMode.require,
      'disable' => SslMode.disable,
      '' =>
        (host == '127.0.0.1' || host == 'localhost')
            ? SslMode.disable
            : SslMode.require,
      _ => SslMode.require,
    };

    final envQueryMode = _Env.get('LOSPOS_DB_QUERY_MODE').toLowerCase();
    if (envQueryMode == 'simple') {
      throw StateError(
        'LOSPOS_DB_QUERY_MODE=simple desteklenmiyor. '
        'lospos parametreli sorgular kullandığı için EXTENDED zorunludur.',
      );
    }
    const QueryMode queryMode = QueryMode.extended;

    final maxConnections = _Env.getInt(
      'LOSPOS_DB_MAX_CONNECTIONS',
      fallback: 20,
    ).clamp(1, 1000);

    final requirePooler = _Env.getBool(
      'LOSPOS_DB_REQUIRE_PGBOUNCER',
      fallback: true,
    );

    if (requirePooler) {
      final hostLower = host.toLowerCase();
      final looksLikePooler =
          hostLower.contains('-pooler') || hostLower.contains('pooler.');
      // Supabase transaction pooler port is usually 6543; custom installs may differ.
      final looksLikePoolerPort = port == 6543 || port == 6432;
      if (!looksLikePooler && !looksLikePoolerPort) {
        throw StateError(
          'PgBouncer zorunlu (LOSPOS_DB_REQUIRE_PGBOUNCER=true) ama host/port pooler gibi görünmüyor. '
          'Host="$host", Port=$port. '
          'Pooler endpoint kullanın veya LOSPOS_DB_REQUIRE_PGBOUNCER=false yapın (önerilmez).',
        );
      }
    }

    return DbConfig(
      host: host,
      port: port,
      username: username,
      password: password,
      sslMode: sslMode,
      queryMode: queryMode,
      maxConnections: maxConnections,
      requirePooler: requirePooler,
    );
  }

  static String _cloudPoolerHost(String rawHost) {
    final envPoolerHost = _Env.get('LOSPOS_DB_POOLER_HOST');
    if (envPoolerHost.isNotEmpty) return envPoolerHost;

    final h = rawHost.trim();
    if (h.isEmpty) return h;

    // Neon: pooled endpoint is `<endpoint>-pooler...neon.tech`
    final lower = h.toLowerCase();
    if (lower.contains('.neon.tech') && !lower.contains('-pooler')) {
      final parts = h.split('.');
      if (parts.isNotEmpty) {
        parts[0] = '${parts[0]}-pooler';
        return parts.join('.');
      }
    }

    return h;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JSON Encoding helpers (parameters + results)
// ─────────────────────────────────────────────────────────────────────────────

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

  // Fallback: JSON-safe string.
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

Object _encodeResult(Result res) {
  final rows = <List<Object?>>[];
  final sqlNulls = <List<bool>?>[];
  for (final row in res) {
    final values = <Object?>[];
    final nulls = <bool>[];
    for (var i = 0; i < row.length; i++) {
      values.add(_encodeValue(row[i]));
      nulls.add(row.isSqlNull(i));
    }
    rows.add(values);
    sqlNulls.add(nulls);
  }

  final schema = <Map<String, Object?>>[];
  for (final col in res.schema.columns) {
    schema.add(<String, Object?>{
      'typeOid': col.typeOid,
      'tableOid': col.tableOid,
      'columnOid': col.columnOid,
      'columnName': col.columnName,
      'isBinary': col.isBinaryEncoding,
    });
  }

  return <String, Object?>{
    'affectedRows': res.affectedRows,
    'schema': schema,
    'rows': rows,
    'sqlNulls': sqlNulls,
  };
}

Object _wireToQuery(Map<String, Object?> wire) {
  final sql = (wire['sql'] as String?) ?? '';
  final mode = (wire['mode'] as String?)?.toLowerCase().trim() ?? 'none';
  final subst = (wire['substitution'] as String?)?.trim();
  if (mode == 'named') {
    return Sql.named(
      sql,
      substitution: (subst?.isNotEmpty ?? false) ? subst! : '@',
    );
  }
  if (mode == 'indexed') {
    return Sql.indexed(
      sql,
      substitution: (subst?.isNotEmpty ?? false) ? subst! : '@',
    );
  }
  return sql;
}

// ─────────────────────────────────────────────────────────────────────────────
// DB Pool manager (per-database)
// ─────────────────────────────────────────────────────────────────────────────

final class DbPoolManager {
  final DbConfig cfg;
  final Map<String, Pool<void>> _pools = <String, Pool<void>>{};
  final Map<String, Future<Pool<void>>> _inFlight =
      <String, Future<Pool<void>>>{};

  DbPoolManager(this.cfg);

  Future<Pool<void>> poolFor(String database) {
    final db = database.trim();
    if (db.isEmpty) {
      throw ArgumentError.value(database, 'database', 'Boş olamaz');
    }

    final existing = _pools[db];
    if (existing != null && existing.isOpen) return Future.value(existing);

    final inflight = _inFlight[db];
    if (inflight != null) return inflight;

    final created = () async {
      try {
        final pool = Pool.withEndpoints(
          <Endpoint>[
            Endpoint(
              host: cfg.host,
              port: cfg.port,
              database: db,
              username: cfg.username,
              password: cfg.password,
            ),
          ],
          settings: PoolSettings(
            sslMode: cfg.sslMode,
            queryMode: cfg.queryMode,
            maxConnectionCount: cfg.maxConnections,
            connectTimeout: const Duration(seconds: 8),
            onOpen: (c) async {
              try {
                await c.execute('SET statement_timeout TO 0');
              } catch (_) {}
            },
          ),
        );

        // Best-effort warmup.
        try {
          await pool.execute('SELECT 1', timeout: const Duration(seconds: 5));
        } catch (_) {}

        _pools[db] = pool;
        return pool;
      } finally {
        _inFlight.remove(db);
      }
    }();

    _inFlight[db] = created;
    return created;
  }

  Future<void> closeAll() async {
    final pools = _pools.values.toList(growable: false);
    _pools.clear();
    _inFlight.clear();
    for (final p in pools) {
      try {
        await p.close();
      } catch (_) {}
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transactions (cross-request)
// ─────────────────────────────────────────────────────────────────────────────

final class TxContext {
  final Connection conn;
  final String database;
  final DateTime createdAt;
  DateTime lastUsedAt;
  bool _closed = false;

  Future<void> _tail = Future<void>.value();

  TxContext({
    required this.conn,
    required this.database,
    required this.createdAt,
    required this.lastUsedAt,
  });

  bool get isClosed => _closed;

  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    Duration? timeout,
  }) {
    if (_closed) {
      throw StateError('Transaction kapalı');
    }
    lastUsedAt = DateTime.now();

    final c = Completer<Result>();
    _tail = _tail
        .then((_) async {
          if (_closed) throw StateError('Transaction kapalı');
          final res = await conn.execute(
            query,
            parameters: parameters,
            ignoreRows: ignoreRows,
            timeout: timeout,
          );
          c.complete(res);
        })
        .catchError((e, st) {
          if (!c.isCompleted) c.completeError(e, st);
        });

    return c.future;
  }

  Future<void> commit() async {
    if (_closed) return;
    _closed = true;
    try {
      await _tail;
    } catch (_) {}
    try {
      await conn.execute('COMMIT');
    } finally {
      try {
        await conn.close();
      } catch (_) {}
    }
  }

  Future<void> rollback() async {
    if (_closed) return;
    _closed = true;
    try {
      await _tail;
    } catch (_) {}
    try {
      await conn.execute('ROLLBACK');
    } catch (_) {
      // ignore
    } finally {
      try {
        await conn.close();
      } catch (_) {}
    }
  }
}

final class TxManager {
  final DbConfig cfg;
  final ApiConfig api;
  final Map<String, TxContext> _tx = <String, TxContext>{};
  Timer? _gcTimer;

  TxManager({required this.cfg, required this.api});

  int get activeCount => _tx.length;

  void startGc() {
    _gcTimer ??= Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_gc());
    });
  }

  Future<void> stopGc() async {
    _gcTimer?.cancel();
    _gcTimer = null;
    final txs = _tx.values.toList(growable: false);
    _tx.clear();
    for (final t in txs) {
      await t.rollback();
    }
  }

  Future<String> begin({
    required String database,
    TransactionSettings? settings,
  }) async {
    if (_tx.length >= api.maxActiveTx) {
      throw StateError(
        'Maksimum aktif transaction aşıldı (${api.maxActiveTx}).',
      );
    }

    final conn = await Connection.open(
      Endpoint(
        host: cfg.host,
        port: cfg.port,
        database: database,
        username: cfg.username,
        password: cfg.password,
      ),
      settings: ConnectionSettings(
        sslMode: cfg.sslMode,
        queryMode: cfg.queryMode,
        connectTimeout: const Duration(seconds: 8),
        onOpen: (c) async {
          try {
            await c.execute('SET statement_timeout TO 0');
          } catch (_) {}
        },
      ),
    );

    final beginSql = _beginSql(settings);
    await conn.execute(beginSql);

    final now = DateTime.now();
    final id = _randomToken();
    _tx[id] = TxContext(
      conn: conn,
      database: database,
      createdAt: now,
      lastUsedAt: now,
    );
    return id;
  }

  TxContext? get(String txId) => _tx[txId];

  Future<void> commit(String txId) async {
    final ctx = _tx.remove(txId);
    if (ctx == null) return;
    await ctx.commit();
  }

  Future<void> rollback(String txId) async {
    final ctx = _tx.remove(txId);
    if (ctx == null) return;
    await ctx.rollback();
  }

  String _beginSql(TransactionSettings? settings) {
    if (settings == null) return 'BEGIN';
    final parts = <String>['BEGIN'];
    if (settings.isolationLevel != null) {
      parts.add(switch (settings.isolationLevel!) {
        IsolationLevel.readCommitted => 'ISOLATION LEVEL READ COMMITTED',
        IsolationLevel.repeatableRead => 'ISOLATION LEVEL REPEATABLE READ',
        IsolationLevel.serializable => 'ISOLATION LEVEL SERIALIZABLE',
        IsolationLevel.readUncommitted => 'ISOLATION LEVEL READ UNCOMMITTED',
      });
    }
    if (settings.accessMode != null) {
      parts.add(switch (settings.accessMode!) {
        AccessMode.readWrite => 'READ WRITE',
        AccessMode.readOnly => 'READ ONLY',
      });
    }
    if (settings.deferrable != null) {
      parts.add(switch (settings.deferrable!) {
        DeferrableMode.deferrable => 'DEFERRABLE',
        DeferrableMode.notDeferrable => 'NOT DEFERRABLE',
      });
    }
    return parts.join(' ');
  }

  Future<void> _gc() async {
    if (_tx.isEmpty) return;
    final now = DateTime.now();
    final expired = <String>[];
    for (final entry in _tx.entries) {
      final ctx = entry.value;
      if (ctx.isClosed) {
        expired.add(entry.key);
        continue;
      }
      if (now.difference(ctx.lastUsedAt) > api.txTtl) {
        expired.add(entry.key);
      }
    }
    for (final id in expired) {
      final ctx = _tx.remove(id);
      if (ctx != null) {
        await ctx.rollback();
      }
    }
  }
}

String _randomToken() {
  final rnd = () {
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }();
  final bytes = List<int>.generate(24, (_) => rnd.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

// ─────────────────────────────────────────────────────────────────────────────
// Cache (best-effort; disabled by default)
// ─────────────────────────────────────────────────────────────────────────────

final class _CacheEntry {
  final Object payload;
  final DateTime expiresAt;
  _CacheEntry({required this.payload, required this.expiresAt});
}

final class QueryCache {
  final Duration ttl;
  final int maxEntries;
  final Map<String, _CacheEntry> _map = <String, _CacheEntry>{};

  QueryCache({required this.ttl, required this.maxEntries});

  Object? get(String key) {
    final e = _map[key];
    if (e == null) return null;
    if (DateTime.now().isAfter(e.expiresAt)) {
      _map.remove(key);
      return null;
    }
    return e.payload;
  }

  void set(String key, Object payload) {
    if (ttl <= Duration.zero) return;
    if (maxEntries <= 0) return;
    if (_map.length >= maxEntries) {
      // Simple eviction: remove one (insertion order is not guaranteed).
      _map.remove(_map.keys.first);
    }
    _map[key] = _CacheEntry(
      payload: payload,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  void clear() => _map.clear();
}

bool _looksLikeSelect(String sql) {
  final s = sql.trimLeft().toLowerCase();
  return s.startsWith('select') || s.startsWith('with');
}

// ─────────────────────────────────────────────────────────────────────────────
// HTTP
// ─────────────────────────────────────────────────────────────────────────────

Future<Map<String, Object?>> _readJsonBody(
  HttpRequest req, {
  required int maxBytes,
}) async {
  final bytes = <int>[];
  await for (final chunk in req) {
    bytes.addAll(chunk);
    if (bytes.length > maxBytes) {
      throw StateError('Body too large');
    }
  }
  final text = utf8.decode(bytes);
  final decoded = jsonDecode(text);
  if (decoded is Map<String, dynamic>) {
    return decoded.map((k, v) => MapEntry(k, v as Object?));
  }
  throw StateError('Invalid JSON body');
}

Future<void> _writeJson(
  HttpResponse res,
  int status,
  Object body, {
  Map<String, String>? headers,
}) async {
  res.statusCode = status;
  res.headers.contentType = ContentType.json;
  res.headers.set('Cache-Control', 'no-store');
  headers?.forEach(res.headers.set);
  res.write(jsonEncode(body));
  await res.close();
}

String _authTokenFromRequest(HttpRequest req) {
  final auth = (req.headers.value(HttpHeaders.authorizationHeader) ?? '')
      .trim();
  if (auth.isNotEmpty) {
    final lower = auth.toLowerCase();
    if (lower.startsWith('bearer ')) return auth.substring(7).trim();
    if (lower.startsWith('apikey ')) return auth.substring(7).trim();
    if (lower.startsWith('basic ')) return auth; // allow passthrough if needed
    return auth;
  }
  final x = (req.headers.value('x-api-key') ?? '').trim();
  return x;
}

bool _constantTimeEq(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

bool _isAuthorized(HttpRequest req, ApiConfig cfg) {
  if (cfg.allowAnon) return true;
  final expected = cfg.token.trim();
  if (expected.isEmpty) return false;
  final got = _authTokenFromRequest(req).trim();
  if (got.isEmpty) return false;
  return _constantTimeEq(got, expected);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('verbose', abbr: 'v', negatable: false);
  final parsed = parser.parse(args);
  if (parsed['help'] == true) {
    stdout.writeln('lospos DB API Server');
    stdout.writeln(parser.usage);
    return;
  }
  final verbose = parsed['verbose'] == true;

  final apiCfg = ApiConfig.fromEnv();
  if (!apiCfg.allowAnon && apiCfg.token.trim().isEmpty) {
    stderr.writeln(
      'LOSPOS_API_TOKEN zorunludur (veya LOSPOS_API_ALLOW_ANON=true).',
    );
    exitCode = 64;
    return;
  }

  final dbCfg = DbConfig.fromEnv();
  final poolMgr = DbPoolManager(dbCfg);
  final txMgr = TxManager(cfg: dbCfg, api: apiCfg)..startGc();
  final cache = QueryCache(
    ttl: apiCfg.cacheTtl,
    maxEntries: apiCfg.cacheMaxEntries,
  );

  ProcessSignal.sigint.watch().listen((_) async {
    if (verbose) stdout.writeln('SIGINT: shutting down...');
    await txMgr.stopGc();
    await poolMgr.closeAll();
    exit(0);
  });

  final server = await HttpServer.bind(
    apiCfg.bindHost,
    apiCfg.port,
    shared: true,
  );
  if (verbose) {
    stdout.writeln(
      'DB API listening on http://${apiCfg.bindHost}:${apiCfg.port}',
    );
  }

  await for (final req in server) {
    unawaited(() async {
      final res = req.response;
      try {
        if (!_isAuthorized(req, apiCfg)) {
          await _writeJson(res, 401, <String, Object?>{
            'error': 'unauthorized',
          });
          return;
        }

        final path = req.uri.path;
        if (req.method == 'GET' && path == '/healthz') {
          await _writeJson(res, 200, <String, Object?>{
            'status': 'ok',
            'activeTx': txMgr.activeCount,
          });
          return;
        }

        if (req.method != 'POST') {
          await _writeJson(res, 405, <String, Object?>{
            'error': 'method_not_allowed',
          });
          return;
        }

        final body = await _readJsonBody(
          req,
          maxBytes: apiCfg.maxBodyBytes,
        ).timeout(apiCfg.requestTimeout);

        if (path == '/v1/execute') {
          final db = (body['database'] as String? ?? '').trim();
          final qWire = body['query'];
          if (db.isEmpty || qWire is! Map) {
            await _writeJson(res, 400, <String, Object?>{
              'error': 'bad_request',
            });
            return;
          }
          final query = _wireToQuery(
            qWire.map((k, v) => MapEntry(k.toString(), v as Object?)),
          );
          final paramsRaw = body['parameters'];
          final params = (paramsRaw == null) ? null : _decodeValue(paramsRaw);
          final ignoreRows = body['ignoreRows'] == true;
          final timeoutMs = (body['timeoutMs'] as num?)?.toInt();
          final timeout = timeoutMs == null
              ? null
              : Duration(milliseconds: timeoutMs.clamp(1, 600000));

          final wireQuery = qWire.map((k, v) => MapEntry(k.toString(), v));
          final sqlForCache = (wireQuery['sql'] as String?) ?? '';
          final shouldCache =
              apiCfg.cacheTtl > Duration.zero &&
              apiCfg.cacheMaxEntries > 0 &&
              apiCfg.cacheMaxRows > 0 &&
              _looksLikeSelect(sqlForCache);

          // Writes invalidate cache (simple, safe).
          if (!shouldCache) {
            cache.clear();
          }

          final cacheKey = shouldCache
              ? jsonEncode(<String, Object?>{
                  'db': db,
                  'q': wireQuery,
                  'p': _encodeValue(params),
                })
              : null;

          if (cacheKey != null) {
            final cached = cache.get(cacheKey);
            if (cached != null) {
              await _writeJson(res, 200, cached);
              return;
            }
          }

          final pool = await poolMgr.poolFor(db);
          final result = await pool.execute(
            query,
            parameters: params,
            ignoreRows: ignoreRows,
            timeout: timeout,
          );

          final payload = _encodeResult(result);
          if (cacheKey != null && result.length <= apiCfg.cacheMaxRows) {
            cache.set(cacheKey, payload);
          }
          await _writeJson(res, 200, payload);
          return;
        }

        if (path == '/v1/tx/begin') {
          final db = (body['database'] as String? ?? '').trim();
          if (db.isEmpty) {
            await _writeJson(res, 400, <String, Object?>{
              'error': 'bad_request',
            });
            return;
          }

          TransactionSettings? settings;
          final sRaw = body['settings'];
          if (sRaw is Map) {
            final iso = (sRaw['isolationLevel'] as String?)
                ?.trim()
                .toLowerCase();
            final access = (sRaw['accessMode'] as String?)
                ?.trim()
                .toLowerCase();
            final def = (sRaw['deferrable'] as String?)?.trim().toLowerCase();
            settings = TransactionSettings(
              isolationLevel: switch (iso) {
                'serializable' => IsolationLevel.serializable,
                'repeatableread' ||
                'repeatable_read' => IsolationLevel.repeatableRead,
                'readcommitted' ||
                'read_committed' => IsolationLevel.readCommitted,
                'readuncommitted' ||
                'read_uncommitted' => IsolationLevel.readUncommitted,
                _ => null,
              },
              accessMode: switch (access) {
                'readonly' || 'read_only' => AccessMode.readOnly,
                'readwrite' || 'read_write' => AccessMode.readWrite,
                _ => null,
              },
              deferrable: switch (def) {
                'deferrable' => DeferrableMode.deferrable,
                'notdeferrable' ||
                'not_deferrable' => DeferrableMode.notDeferrable,
                _ => null,
              },
            );
          }

          final id = await txMgr.begin(database: db, settings: settings);
          await _writeJson(res, 200, <String, Object?>{'txId': id});
          return;
        }

        if (path == '/v1/tx/execute') {
          final txId = (body['txId'] as String? ?? '').trim();
          final qWire = body['query'];
          if (txId.isEmpty || qWire is! Map) {
            await _writeJson(res, 400, <String, Object?>{
              'error': 'bad_request',
            });
            return;
          }
          final ctx = txMgr.get(txId);
          if (ctx == null) {
            await _writeJson(res, 404, <String, Object?>{
              'error': 'tx_not_found',
            });
            return;
          }
          final query = _wireToQuery(
            qWire.map((k, v) => MapEntry(k.toString(), v as Object?)),
          );
          final paramsRaw = body['parameters'];
          final params = (paramsRaw == null) ? null : _decodeValue(paramsRaw);
          final ignoreRows = body['ignoreRows'] == true;
          final timeoutMs = (body['timeoutMs'] as num?)?.toInt();
          final timeout = timeoutMs == null
              ? null
              : Duration(milliseconds: timeoutMs.clamp(1, 600000));

          final result = await ctx.execute(
            query,
            parameters: params,
            ignoreRows: ignoreRows,
            timeout: timeout,
          );
          await _writeJson(res, 200, _encodeResult(result));
          return;
        }

        if (path == '/v1/tx/commit') {
          final txId = (body['txId'] as String? ?? '').trim();
          if (txId.isEmpty) {
            await _writeJson(res, 400, <String, Object?>{
              'error': 'bad_request',
            });
            return;
          }
          await txMgr.commit(txId);
          await _writeJson(res, 200, <String, Object?>{'ok': true});
          return;
        }

        if (path == '/v1/tx/rollback') {
          final txId = (body['txId'] as String? ?? '').trim();
          if (txId.isEmpty) {
            await _writeJson(res, 400, <String, Object?>{
              'error': 'bad_request',
            });
            return;
          }
          await txMgr.rollback(txId);
          await _writeJson(res, 200, <String, Object?>{'ok': true});
          return;
        }

        await _writeJson(res, 404, <String, Object?>{'error': 'not_found'});
      } catch (e) {
        if (verbose) {
          stderr.writeln('Request failed: $e');
        }
        try {
          await _writeJson(res, 500, <String, Object?>{
            'error': 'internal_error',
          });
        } catch (_) {}
      }
    }());
  }
}
