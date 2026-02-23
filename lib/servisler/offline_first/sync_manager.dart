import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_models.dart';
import 'sync_store.dart';

class OfflineFirstSyncConfig {
  final String tenantId;
  final String deviceId;
  final int batchSize;
  final int deltaPageSize;
  final int maxRetryCount;
  final Duration inAppSyncInterval;
  final Map<String, String> deltaPullRpcsByTable;

  const OfflineFirstSyncConfig({
    required this.tenantId,
    required this.deviceId,
    required this.deltaPullRpcsByTable,
    this.batchSize = 50,
    this.deltaPageSize = 1000,
    this.maxRetryCount = 3,
    this.inAppSyncInterval = const Duration(minutes: 15),
  });
}

class SchemaGateException implements Exception {
  final SchemaGateResult gate;
  SchemaGateException(this.gate);

  @override
  String toString() {
    return 'SchemaGateException(action=${gate.action}, current=${gate.currentVersion}, min=${gate.minSupportedVersion})';
  }
}

class SyncManager extends ChangeNotifier {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  SupabaseClient? _client;
  SyncStore? _store;
  OfflineFirstSyncConfig? _config;

  Timer? _timer;
  bool _inFlight = false;

  String? _lastError;
  String? get lastError => _lastError;

  void configure({
    required SupabaseClient client,
    required SyncStore store,
    required OfflineFirstSyncConfig config,
  }) {
    _client = client;
    _store = store;
    _config = config;
  }

  void startInAppPeriodicSync() {
    final interval = _config?.inAppSyncInterval ?? const Duration(minutes: 15);
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(sync()));
  }

  void stopInAppPeriodicSync() {
    _timer?.cancel();
    _timer = null;
  }

  Future<SyncReport> sync() async {
    final client = _client;
    final store = _store;
    final config = _config;
    if (client == null || store == null || config == null) {
      throw StateError('SyncManager is not configured');
    }

    if (_inFlight) {
      return const SyncReport(pushed: 0, pulled: 0, elapsed: Duration.zero);
    }

    final sw = Stopwatch()..start();
    _inFlight = true;
    _lastError = null;
    notifyListeners();

    int pushed = 0;
    int pulled = 0;

    try {
      await _ensureFreshAuthSession(client);

      final schemaVersion = await store.getSchemaVersion();
      final gate = await _schemaGate(client, schemaVersion);
      if (!gate.ok) throw SchemaGateException(gate);

      pushed += await _pushOnce(
        client: client,
        store: store,
        config: config,
        schemaVersion: schemaVersion,
      );

      pulled += await _pullAllTables(
        client: client,
        store: store,
        config: config,
      );

      await _purgeLocal(store);
      return SyncReport(pushed: pushed, pulled: pulled, elapsed: sw.elapsed);
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    } finally {
      _inFlight = false;
      notifyListeners();
    }
  }

  Future<void> _ensureFreshAuthSession(SupabaseClient client) async {
    final session = client.auth.currentSession;
    if (session == null) return;
    if (!session.isExpired) return;
    await client.auth.refreshSession();
  }

  Future<SchemaGateResult> _schemaGate(
    SupabaseClient client,
    int schemaVersion,
  ) async {
    final res = await client.rpc(
      'offline_first_sync_gate',
      params: <String, dynamic>{'p_client_schema_version': schemaVersion},
    );

    if (res is Map<String, dynamic>) {
      return SchemaGateResult.fromJson(res);
    }
    if (res is Map) {
      return SchemaGateResult.fromJson(res.cast<String, dynamic>());
    }
    throw StateError('Unexpected schema gate response type: ${res.runtimeType}');
  }

  Future<int> _pushOnce({
    required SupabaseClient client,
    required SyncStore store,
    required OfflineFirstSyncConfig config,
    required int schemaVersion,
  }) async {
    final ops = await store.readPendingOperations(limit: config.batchSize);
    if (ops.isEmpty) return 0;

    final batchId = UuidV4.generate();
    try {
      final res = await client.rpc(
        'offline_first_apply_batch',
        params: <String, dynamic>{
          'p_tenant_id': config.tenantId,
          'p_device_id': config.deviceId,
          'p_schema_version': schemaVersion,
          'p_batch_id': batchId,
          'p_client_sent_at': DateTime.now().toUtc().toIso8601String(),
          'p_ops': ops.map((o) => o.toRpcMap()).toList(),
        },
      );

      final parsed = _parseApplyBatchResult(res);
      if (!parsed.ok) {
        throw StateError('Batch rejected');
      }

      await store.markOperationsAcked(ops.map((e) => e.opId));
      return ops.length;
    } catch (e) {
      for (final op in ops) {
        final attempts = await store.bumpAttemptCount(op.opId);
        final retryable = _isRetryableSyncError(e);
        if (!retryable && attempts >= config.maxRetryCount) {
          await store.moveToDeadLetter(
            operation: op,
            errorCode: 'SYNC_FAILED',
            errorMessage: e.toString(),
          );
        }
      }
      rethrow;
    }
  }

  ApplyBatchResult _parseApplyBatchResult(Object? res) {
    if (res is Map<String, dynamic>) {
      return ApplyBatchResult.fromJson(res);
    }
    if (res is Map) {
      return ApplyBatchResult.fromJson(res.cast<String, dynamic>());
    }
    throw StateError('Unexpected apply batch response type: ${res.runtimeType}');
  }

  bool _isRetryableSyncError(Object error) {
    if (error is TimeoutException) return true;
    if (error is PostgrestException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('timeout')) return true;
      if (msg.contains('connection')) return true;
      if (msg.contains('server error')) return true;
      return false;
    }
    return true;
  }

  Future<int> _pullAllTables({
    required SupabaseClient client,
    required SyncStore store,
    required OfflineFirstSyncConfig config,
  }) async {
    int pulled = 0;
    for (final entry in config.deltaPullRpcsByTable.entries) {
      pulled += await _pullTable(
        client: client,
        store: store,
        config: config,
        table: entry.key,
        rpcName: entry.value,
      );
    }
    return pulled;
  }

  Future<int> _pullTable({
    required SupabaseClient client,
    required SyncStore store,
    required OfflineFirstSyncConfig config,
    required String table,
    required String rpcName,
  }) async {
    int pulled = 0;
    var cursor = await store.getCursor(table);

    for (var page = 0; page < 50; page++) {
      final res = await client.rpc(
        rpcName,
        params: <String, dynamic>{
          'p_tenant_id': config.tenantId,
          'p_since': cursor.lastPulledAt.toUtc().toIso8601String(),
          'p_after_id': cursor.lastPulledId,
          'p_limit': config.deltaPageSize,
        },
      );

      final rows = _parseRows(res);
      if (rows.isEmpty) break;

      await store.upsertPulledRows(table, rows);
      pulled += rows.length;

      final last = rows.last;
      final lastUpdatedRaw = last['updated_at'];
      final lastIdRaw = last['id'];
      if (lastUpdatedRaw is String && lastIdRaw is String) {
        cursor = SyncCursor(
          lastPulledAt: DateTime.parse(lastUpdatedRaw).toUtc(),
          lastPulledId: lastIdRaw,
        );
        await store.setCursor(table, cursor);
      } else {
        break;
      }

      if (rows.length < config.deltaPageSize) break;
    }

    return pulled;
  }

  List<Map<String, dynamic>> _parseRows(Object? res) {
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    return const [];
  }

  Future<void> _purgeLocal(SyncStore store) async {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 90));
    await store.purgeSyncedData(syncedBefore: cutoff);
  }
}

