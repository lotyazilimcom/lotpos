import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import 'db_api/api_pool.dart';
import 'db_api/veritabani_api_client.dart';
import 'lisans_yazma_koruma.dart';
import 'veritabani_yapilandirma.dart';

@immutable
class _PoolKey {
  final bool useApi;
  final String apiReadBaseUrl;
  final String apiWriteBaseUrl;
  final String apiToken;
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final SslMode sslMode;
  final QueryMode queryMode;
  final int maxConnections;

  const _PoolKey({
    required this.useApi,
    required this.apiReadBaseUrl,
    required this.apiWriteBaseUrl,
    required this.apiToken,
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    required this.sslMode,
    required this.queryMode,
    required this.maxConnections,
  });

  @override
  int get hashCode => Object.hash(
    useApi,
    apiReadBaseUrl,
    apiWriteBaseUrl,
    apiToken,
    host,
    port,
    database,
    username,
    password,
    sslMode,
    queryMode,
    maxConnections,
  );

  @override
  bool operator ==(Object other) {
    return other is _PoolKey &&
        useApi == other.useApi &&
        apiReadBaseUrl == other.apiReadBaseUrl &&
        apiWriteBaseUrl == other.apiWriteBaseUrl &&
        apiToken == other.apiToken &&
        host == other.host &&
        port == other.port &&
        database == other.database &&
        username == other.username &&
        password == other.password &&
        sslMode == other.sslMode &&
        queryMode == other.queryMode &&
        maxConnections == other.maxConnections;
  }
}

class VeritabaniHavuzu {
  static final VeritabaniHavuzu _instance = VeritabaniHavuzu._internal();
  factory VeritabaniHavuzu() => _instance;
  VeritabaniHavuzu._internal();

  final Map<_PoolKey, Pool<void>> _pools = <_PoolKey, Pool<void>>{};
  final Map<Pool<void>, _PoolKey> _reverse = <Pool<void>, _PoolKey>{};
  final Map<_PoolKey, Future<Pool<void>>> _inFlight =
      <_PoolKey, Future<Pool<void>>>{};

  Future<Pool<void>> havuzAl({
    required String database,
    int? maxConnectionsOverride,
    bool preferDirectSocket = false,
    bool allowApiFallback = true,
  }) async {
    final cfg = VeritabaniYapilandirma();
    final db = database.trim();
    if (db.isEmpty) {
      throw ArgumentError.value(database, 'database', 'Boş olamaz');
    }

    final canUseDirectCloud =
        cfg.isCloudMode && VeritabaniYapilandirma.cloudCredentialsReady;
    final canUseCloudApi =
        cfg.isCloudMode &&
        allowApiFallback &&
        VeritabaniYapilandirma.cloudApiCredentialsReady;

    final bool useApi;
    if (cfg.isCloudMode) {
      if (!preferDirectSocket && canUseCloudApi) {
        useApi = true;
      } else if (canUseDirectCloud) {
        useApi = false;
      } else if (canUseCloudApi) {
        useApi = true;
      } else {
        throw StateError(
          'Bulut modunda direct PostgreSQL veya API kimlikleri gerekli. '
          'Cloud DB host/user/password ya da API URL/token ayarlarını tamamlayın.',
        );
      }
    } else if (preferDirectSocket) {
      useApi = false;
    } else {
      useApi = false;
    }

    final apiReadBaseUrl = (VeritabaniYapilandirma.cloudApiReadBaseUrl ?? '')
        .trim();
    final apiWriteBaseUrl = (VeritabaniYapilandirma.cloudApiWriteBaseUrl ?? '')
        .trim();
    final apiToken = (VeritabaniYapilandirma.cloudApiToken ?? '').trim();

    final key = _PoolKey(
      useApi: useApi,
      apiReadBaseUrl: useApi ? apiReadBaseUrl : '',
      apiWriteBaseUrl: useApi ? apiWriteBaseUrl : '',
      apiToken: useApi ? apiToken : '',
      host: useApi ? '' : cfg.host,
      port: useApi ? 0 : cfg.port,
      database: db,
      username: useApi ? '' : cfg.username,
      password: useApi ? '' : cfg.password,
      sslMode: useApi ? SslMode.disable : cfg.sslMode,
      queryMode: useApi ? QueryMode.extended : cfg.queryMode,
      maxConnections: (maxConnectionsOverride ?? cfg.maxConnections).clamp(
        1,
        1000,
      ),
    );

    final existing = _pools[key];
    if (existing != null) {
      if (existing.isOpen) return existing;
      _pools.remove(key);
      _reverse.remove(existing);
    }

    final inflight = _inFlight[key];
    if (inflight != null) return inflight;

    final createdFuture = () async {
      try {
        final Pool<void> basePool;
        if (key.useApi) {
          final writeUri = Uri.tryParse(key.apiWriteBaseUrl);
          if (writeUri == null) {
            throw StateError(
              'Bulut API (WRITE) URL geçersiz: "${key.apiWriteBaseUrl}". '
              'PATISYO_API_WRITE_BASE_URL / PATISYO_API_BASE_URL veya bulut kimliklerini kontrol edin.',
            );
          }

          final readUri = Uri.tryParse(key.apiReadBaseUrl) ?? writeUri;
          basePool = ApiPool(
            client: VeritabaniApiClient(
              baseUrl: writeUri,
              readBaseUrl: readUri,
              writeBaseUrl: writeUri,
              token: key.apiToken,
              defaultTimeout: cfg.poolConnectTimeout,
            ),
            database: key.database,
          );
        } else {
          basePool = Pool.withEndpoints(
            <Endpoint>[
              Endpoint(
                host: key.host,
                port: key.port,
                database: key.database,
                username: key.username,
                password: key.password,
              ),
            ],
            settings: PoolSettings(
              sslMode: key.sslMode,
              connectTimeout: cfg.poolConnectTimeout,
              onOpen: cfg.tuneConnection,
              queryMode: key.queryMode,
              maxConnectionCount: key.maxConnections,
            ),
          );
        }

        final pool = LisansKorumaliPool<void>(basePool);

        // Best-effort: connection warmup so failures surface early.
        try {
          await pool.execute('SELECT 1');
        } catch (_) {}

        _pools[key] = pool;
        _reverse[pool] = key;
        return pool;
      } finally {
        _inFlight.remove(key);
      }
    }();

    _inFlight[key] = createdFuture;
    return createdFuture;
  }

  Future<void> kapatDatabase(String database) async {
    final db = database.trim();
    if (db.isEmpty) return;

    final keys = _pools.keys
        .where((k) => k.database == db)
        .toList(growable: false);
    for (final k in keys) {
      final pool = _pools.remove(k);
      if (pool != null) _reverse.remove(pool);
      try {
        await pool?.close();
      } catch (_) {}
    }
  }

  Future<void> kapatPool(Pool<void>? pool) async {
    if (pool == null) return;
    final key = _reverse.remove(pool);
    if (key != null) {
      _pools.remove(key);
    }
    try {
      await pool.close();
    } catch (_) {}
  }

  Future<void> tumunuKapat() async {
    final pools = _pools.values.toList(growable: false);
    _pools.clear();
    _reverse.clear();
    _inFlight.clear();
    for (final p in pools) {
      try {
        await p.close();
      } catch (_) {}
    }
  }
}
