import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'veritabani_yapilandirma.dart';

enum VeritabaniAktarimTipi { tamAktar, birlestir }

class VeritabaniAktarimIlerleme {
  final int tamamlananAdim;
  final int toplamAdim;
  final String? mevcut;

  const VeritabaniAktarimIlerleme({
    required this.tamamlananAdim,
    required this.toplamAdim,
    this.mevcut,
  });

  double? get oran {
    if (toplamAdim <= 0) return null;
    if (tamamlananAdim <= 0) return 0;
    return tamamlananAdim / toplamAdim;
  }

  int? get yuzde {
    final v = oran;
    if (v == null) return null;
    final pct = (v * 100).round();
    if (pct < 0) return 0;
    if (pct > 100) return 100;
    return pct;
  }
}

class VeritabaniAktarimNiyeti {
  final String fromMode; // local | cloud
  final String toMode; // local | cloud
  final String? localHost; // local tarafı için gerekli
  final String? localCompanyDb; // opsiyonel: özellikle local -> cloud geçişinde
  final DateTime createdAt;

  const VeritabaniAktarimNiyeti({
    required this.fromMode,
    required this.toMode,
    required this.localHost,
    required this.localCompanyDb,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'from': fromMode,
    'to': toMode,
    'localHost': localHost,
    'localCompanyDb': localCompanyDb,
    'createdAt': createdAt.toIso8601String(),
  };

  static VeritabaniAktarimNiyeti? fromJson(Object? raw) {
    try {
      if (raw == null) return null;
      final map = raw is Map<String, dynamic>
          ? raw
          : jsonDecode(raw.toString()) as Map<String, dynamic>;

      final from = (map['from'] as String?)?.trim() ?? '';
      final to = (map['to'] as String?)?.trim() ?? '';
      final localHost = (map['localHost'] as String?)?.trim();
      final localCompanyDb = (map['localCompanyDb'] as String?)?.trim();
      final createdRaw = (map['createdAt'] as String?)?.trim();
      final createdAt = createdRaw == null || createdRaw.isEmpty
          ? DateTime.now()
          : DateTime.tryParse(createdRaw) ?? DateTime.now();

      if (from.isEmpty || to.isEmpty) return null;
      return VeritabaniAktarimNiyeti(
        fromMode: from,
        toMode: to,
        localHost: (localHost == null || localHost.isEmpty) ? null : localHost,
        localCompanyDb: (localCompanyDb == null || localCompanyDb.isEmpty)
            ? null
            : localCompanyDb,
        createdAt: createdAt,
      );
    } catch (_) {
      return null;
    }
  }
}

class VeritabaniAktarimServisi {
  static final VeritabaniAktarimServisi _instance =
      VeritabaniAktarimServisi._internal();
  factory VeritabaniAktarimServisi() => _instance;
  VeritabaniAktarimServisi._internal();

  static const String _prefPendingKey = 'patisyo_pending_db_transfer';
  static const String _tombstonesTable = 'sync_tombstones';
  static const String _tombstoneTriggerFn = 'patisyo_capture_delete_tombstone';
  static const String _tombstoneTriggerName = 'trg_patisyo_capture_delete';
  static const String _deltaOutboxTable = 'sync_delta_outbox';
  static const String _deltaOutboxTriggerFn = 'patisyo_capture_delta_outbox';
  static const String _deltaOutboxTriggerName =
      'trg_patisyo_capture_delta_outbox';
  static const String _syncApplyGuc = 'patisyo.sync_apply';
  static const String _updatedAtTriggerFn = 'patisyo_set_updated_at';
  static const String _updatedAtTriggerName = 'trg_patisyo_set_updated_at';
  static const int _localSequenceParity = 1; // odd
  static const int _cloudSequenceParity = 0; // even
  static const Set<String> _transferExcludedTables = <String>{
    // Dahili kuyruk: cross-db aktarımda kopyalanırsa yan etki/çift uygulanma üretir.
    'sync_outbox',
    // Offline-first delta kuyruğu: sadece kaynak DB içinde çalışır.
    _deltaOutboxTable,
  };

  final Map<String, Map<String, String>> _targetColumnUdtNameCacheByTable =
      <String, Map<String, String>>{};

  // Karma modda "hızlı" yerel -> bulut delta senkronu için istatistik cache'i.
  // pg_stat_user_tables sayaçlarını okuyup son durumla karşılaştırırız.
  final Map<String, int> _deltaSettingsModsByTable = <String, int>{};
  final Map<String, int> _deltaCompanyModsByTable = <String, int>{};
  final Map<String, int> _deltaCloudModsByTable = <String, int>{};
  String? _deltaSettingsDbName;
  String? _deltaCompanyDbName;
  String? _deltaCloudKey;

  static const Set<String> _deltaFullCopyAllowlistNoTimestamps = <String>{
    'sequences',
    'table_counts',
    'account_metadata',
  };

  final Set<String> _tombstoneInfraReadyByDbKey = <String>{};
  final Set<String> _deltaOutboxInfraReadyByDbKey = <String>{};
  final Set<String> _timestampInfraReadyByDbKey = <String>{};
  final Set<String> _sequenceParityReadyByDbKey = <String>{};

  void _resetRunCaches() {
    _targetColumnUdtNameCacheByTable.clear();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('DBAktarim: $message');
    }
  }

  Future<void> niyetKaydet(VeritabaniAktarimNiyeti niyet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPendingKey, jsonEncode(niyet.toJson()));
  }

  Future<VeritabaniAktarimNiyeti?> niyetOku() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefPendingKey);
    return VeritabaniAktarimNiyeti.fromJson(raw);
  }

  Future<void> niyetTemizle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefPendingKey);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Transfer (Data Migration) Core
  // ──────────────────────────────────────────────────────────────────────────

  Future<VeritabaniAktarimHazirlik?> hazirlikYap({
    required VeritabaniAktarimNiyeti niyet,
  }) async {
    final from = niyet.fromMode.trim();
    final to = niyet.toMode.trim();

    final isLocalCloudSwitch =
        (from == 'local' && to == 'cloud') ||
        (from == 'cloud' && to == 'local');
    if (!isLocalCloudSwitch) return null;

    // Cloud kimlikleri yoksa hazır değil.
    if ((from == 'cloud' || to == 'cloud') &&
        !VeritabaniYapilandirma.cloudCredentialsReady) {
      return null;
    }

    // Yerel host:
    // - Önce niyet içindeki explicit localHost
    // - Sonra discoveredHost (mobil/tablet)
    // - Desktop fallback: 127.0.0.1 (discoveredHost null olabilir)
    String localHost =
        (niyet.localHost ?? VeritabaniYapilandirma.discoveredHost ?? '').trim();
    if (localHost.isEmpty && !kIsWeb) {
      try {
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          localHost = '127.0.0.1';
        }
      } catch (_) {}
    }
    if ((from == 'local' || to == 'local') && localHost.isEmpty) return null;

    final localSettings = _buildLocalConnection(
      host: localHost,
      database: _localSettingsDatabaseName(),
    );

    final cloud = _buildCloudConnection();
    if (cloud == null) return null;

    String localCompanyDb = (niyet.localCompanyDb ?? '').trim();
    if (localCompanyDb.isEmpty) {
      localCompanyDb =
          await _tryResolveDefaultLocalCompanyDb(localSettings) ??
          'patisyo2025';
    }

    final localCompany = _buildLocalConnection(
      host: localHost,
      database: localCompanyDb,
    );

    // Hızlı sağlık kontrolü: bağlan + kritik tablolar var mı?
    final ok = await _quickReadinessCheck(
      fromMode: from,
      toMode: to,
      localSettings: localSettings,
      localCompany: localCompany,
      cloud: cloud,
    );
    if (!ok) return null;

    return VeritabaniAktarimHazirlik._(
      fromMode: from,
      toMode: to,
      localSettings: localSettings,
      localCompany: localCompany,
      cloud: cloud,
    );
  }

  Future<void> aktarimYap({
    required VeritabaniAktarimHazirlik hazirlik,
    required VeritabaniAktarimTipi tip,
    void Function(VeritabaniAktarimIlerleme ilerleme)? onIlerleme,
  }) async {
    _resetRunCaches();

    if (hazirlik.fromMode == 'local' && hazirlik.toMode == 'cloud') {
      await _localToCloud(
        localSettings: hazirlik._localSettings,
        localCompany: hazirlik._localCompany,
        cloud: hazirlik._cloud,
        tip: tip,
        onIlerleme: onIlerleme,
      );
      return;
    }
    if (hazirlik.fromMode == 'cloud' && hazirlik.toMode == 'local') {
      await _cloudToLocal(
        cloud: hazirlik._cloud,
        localSettings: hazirlik._localSettings,
        localCompany: hazirlik._localCompany,
        tip: tip,
        onIlerleme: onIlerleme,
      );
      return;
    }

    throw StateError(
      'Aktarım yönü desteklenmiyor: ${hazirlik.fromMode} -> ${hazirlik.toMode}',
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Hybrid: Delta Sync (Local -> Cloud)
  // ──────────────────────────────────────────────────────────────────────────

  Future<VeritabaniDeltaSenkronRapor> deltaSenkronYerelBulut({
    required String localHost,
    required String localCompanyDb,
    required DateTime since,
    Duration overlap = const Duration(minutes: 2),
    int maxTables = 0,
  }) async {
    _resetRunCaches();

    final cloud = _buildCloudConnection();
    if (cloud == null) {
      throw StateError('Bulut bağlantı bilgileri hazır değil.');
    }

    final cloudDbKey = 'cloud://${cloud.host}:${cloud.port}/${cloud.database}';
    final settingsDb = _localSettingsDatabaseName();
    final normalizedLocalHost =
        localHost.trim().isEmpty ? '127.0.0.1' : localHost.trim();
    if (_deltaSettingsDbName != settingsDb) {
      _deltaSettingsDbName = settingsDb;
      _deltaSettingsModsByTable.clear();
    }
    if (_deltaCompanyDbName != localCompanyDb) {
      _deltaCompanyDbName = localCompanyDb;
      _deltaCompanyModsByTable.clear();
    }

    final effectiveSince = since.subtract(overlap);
    final localSettings =
        _buildLocalConnection(host: normalizedLocalHost, database: settingsDb);
    final localCompany = _buildLocalConnection(
      host: normalizedLocalHost,
      database: localCompanyDb,
    );
    final localSettingsDbKey =
        'local://$normalizedLocalHost:${localSettings.port}/$settingsDb';
    final localCompanyDbKey =
        'local://$normalizedLocalHost:${localCompany.port}/$localCompanyDb';

    Connection? sSettings;
    Connection? sCompany;
    Connection? tCloud;

    final sw = Stopwatch()..start();
    var appliedRows = 0;
    final touchedTables = <String>{};

    try {
      sSettings = await _open(localSettings);
      sCompany = await _open(localCompany);
      final Connection sSettingsConn = sSettings;
      final Connection sCompanyConn = sCompany;

      // DELETE senkronu için tombstone altyapısını önceden garanti altına al.
      await _ensureTombstoneInfraBestEffort(
        sSettingsConn,
        dbKey: localSettingsDbKey,
      );
      await _ensureTombstoneInfraBestEffort(
        sCompanyConn,
        dbKey: localCompanyDbKey,
      );

      await _ensureDeltaTimestampInfraBestEffort(
        sSettingsConn,
        dbKey: localSettingsDbKey,
      );
      await _ensureDeltaTimestampInfraBestEffort(
        sCompanyConn,
        dbKey: localCompanyDbKey,
      );

      await _ensureSequenceParityBestEffort(
        sSettingsConn,
        dbKey: localSettingsDbKey,
        desiredParity: _localSequenceParity,
      );
      await _ensureSequenceParityBestEffort(
        sCompanyConn,
        dbKey: localCompanyDbKey,
        desiredParity: _localSequenceParity,
      );

      // 1) Offline-first delta: DB içi outbox kuyruğunu oku (hızlı, idempotent).
      final settingsOutboxReady = await _isDeltaOutboxOperational(
        sSettingsConn,
        dbKey: localSettingsDbKey,
      );
      final companyOutboxReady = await _isDeltaOutboxOperational(
        sCompanyConn,
        dbKey: localCompanyDbKey,
      );

      final outboxItems = <_DeltaOutboxItem>[];
      if (settingsOutboxReady) {
        final rows = await _readDeltaOutbox(sSettingsConn);
        outboxItems.addAll(
          rows.map(
            (r) => _DeltaOutboxItem(
              source: sSettingsConn,
              sourceLabel: 'settings',
              row: r,
            ),
          ),
        );
      }
      if (companyOutboxReady) {
        final rows = await _readDeltaOutbox(sCompanyConn);
        outboxItems.addAll(
          rows.map(
            (r) => _DeltaOutboxItem(
              source: sCompanyConn,
              sourceLabel: 'company',
              row: r,
            ),
          ),
        );
      }
      outboxItems.sort((a, b) => a.row.touchedAt.compareTo(b.row.touchedAt));

      // 2) Geriye dönük fallback (outbox altyapısı yoksa): pg_stat + timestamp delta.
      final fallbackChangedTables =
          (!settingsOutboxReady && !companyOutboxReady)
              ? <String>{
                  ...await _detectChangedTables(
                    conn: sSettingsConn,
                    prev: _deltaSettingsModsByTable,
                  ),
                  ...await _detectChangedTables(
                    conn: sCompanyConn,
                    prev: _deltaCompanyModsByTable,
                  ),
                }
              : <String>{};

      if (outboxItems.isEmpty && fallbackChangedTables.isEmpty) {
        return VeritabaniDeltaSenkronRapor(
          tabloSayisi: 0,
          satirSayisi: 0,
          tablolar: const <String>[],
          elapsed: sw.elapsed,
        );
      }

      tCloud = await _open(cloud);
      final Connection tCloudConn = tCloud;

      await _ensureTombstoneInfraBestEffort(tCloudConn, dbKey: cloudDbKey);
      await _ensureDeltaTimestampInfraBestEffort(
        tCloudConn,
        dbKey: cloudDbKey,
      );
      await _ensureSequenceParityBestEffort(
        tCloudConn,
        dbKey: cloudDbKey,
        desiredParity: _cloudSequenceParity,
      );
      // Best-effort: cloud outbox altyapısını hazırla (cloud->local akışında kullanılır).
      await _isDeltaOutboxOperational(tCloudConn, dbKey: cloudDbKey);
      await _setSyncApplyFlagBestEffort(
        tCloudConn,
        enabled: true,
        debugContext: 'delta-local->cloud',
      );

      if (outboxItems.isNotEmpty) {
        List<_DeltaOutboxItem> toApply = outboxItems;
        if (maxTables > 0) {
          final seen = <String>{};
          final keepTables = <String>[];
          for (final it in outboxItems) {
            final t = it.row.tableName.trim();
            if (t.isEmpty) continue;
            if (seen.add(t)) {
              keepTables.add(t);
              if (keepTables.length >= maxTables) break;
            }
          }
          final keepSet = keepTables.toSet();
          toApply = <_DeltaOutboxItem>[
            for (final it in outboxItems)
              if (keepSet.contains(it.row.tableName.trim())) it,
          ];
        }

        final apply = await _applyDeltaOutboxItemsToTarget(
          tCloudConn,
          items: toApply,
          companyIdOverride: cloud.database,
        );
        appliedRows += apply.applied;
        touchedTables.addAll(apply.tablesTouched);

        for (final it in apply.succeeded) {
          await _ackDeltaOutboxRow(it.source, row: it.row);
        }
        for (final f in apply.failed) {
          await _markDeltaOutboxRowFailed(
            f.item.source,
            row: f.item.row,
            error: f.error,
          );
        }
      }

      var copiedRows = 0;
      if (fallbackChangedTables.isNotEmpty) {
        final changedTables = <String>{...fallbackChangedTables};
        changedTables.remove(_tombstonesTable);
        changedTables.removeAll(_transferExcludedTables);

        final allTables = changedTables.toList()..sort();
        final limitedTables = (maxTables > 0 && allTables.length > maxTables)
            ? allTables.take(maxTables).toList()
            : allTables;

        final ordered = await _topologicalInsertOrder(tCloudConn, limitedTables);

        for (final table in ordered) {
          final targetCols = await _columns(tCloudConn, table);
          if (targetCols.isEmpty) continue;

          final sources = <_DbSource>[];
          if (await _tableExistsCached(sSettingsConn, table)) {
            sources.add(_DbSource(sSettingsConn, 'settings'));
          }
          if (await _tableExistsCached(sCompanyConn, table)) {
            sources.add(_DbSource(sCompanyConn, 'company'));
          }
          if (sources.isEmpty) continue;

          final copied = await _copyTableFromMultipleSources(
            sources: sources,
            target: tCloudConn,
            table: table,
            tip: VeritabaniAktarimTipi.birlestir,
            companyIdOverride: cloud.database,
            deltaSince: effectiveSince,
          );

          if (copied > 0) {
            touchedTables.add(table);
          }
          copiedRows += copied;
        }
      }

      // DELETE senkronu: Yerelden gelen tombstone'ları buluta yaz ve hedefte sil.
      await _syncTombstonesLocalToCloud(
        localSettings: sSettingsConn,
        localCompany: sCompanyConn,
        cloud: tCloudConn,
        since: effectiveSince,
      );

      appliedRows += copiedRows;

      if (touchedTables.isNotEmpty) {
        await _fixSequences(
          tCloudConn,
          touchedTables.toList(),
          desiredParity: _cloudSequenceParity,
        );
      }

      final list = touchedTables.toList()..sort();
      return VeritabaniDeltaSenkronRapor(
        tabloSayisi: list.length,
        satirSayisi: appliedRows,
        tablolar: list,
        elapsed: sw.elapsed,
      );
    } finally {
      sw.stop();
      await _safeClose(sSettings);
      await _safeClose(sCompany);
      await _safeClose(tCloud);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Hybrid: Delta Sync (Cloud -> Local)
  // ──────────────────────────────────────────────────────────────────────────

  Future<VeritabaniDeltaSenkronRapor> deltaSenkronBulutYerel({
    required String localHost,
    required String localCompanyDb,
    required DateTime since,
    Duration overlap = const Duration(minutes: 2),
    int maxTables = 0,
  }) async {
    _resetRunCaches();

    final cloud = _buildCloudConnection();
    if (cloud == null) {
      throw StateError('Bulut bağlantı bilgileri hazır değil.');
    }

    final cloudDbKey = 'cloud://${cloud.host}:${cloud.port}/${cloud.database}';
    final cloudKey = '${cloud.host}:${cloud.port}/${cloud.database}';
    if (_deltaCloudKey != cloudKey) {
      _deltaCloudKey = cloudKey;
      _deltaCloudModsByTable.clear();
    }

    final settingsDb = _localSettingsDatabaseName();
    final effectiveSince = since.subtract(overlap);

    final normalizedHost =
        localHost.trim().isEmpty ? '127.0.0.1' : localHost.trim();
    final localSettings =
        _buildLocalConnection(host: normalizedHost, database: settingsDb);
    final localCompany = _buildLocalConnection(
      host: normalizedHost,
      database: localCompanyDb,
    );
    final localSettingsDbKey =
        'local://$normalizedHost:${localSettings.port}/$settingsDb';
    final localCompanyDbKey =
        'local://$normalizedHost:${localCompany.port}/$localCompanyDb';

    Connection? sCloud;
    Connection? tSettings;
    Connection? tCompany;

    final sw = Stopwatch()..start();
    var appliedRows = 0;
    final touchedTables = <String>{};

    try {
      sCloud = await _open(cloud);
      tSettings = await _open(localSettings);
      tCompany = await _open(localCompany);

      final Connection sCloudConn = sCloud;
      final Connection tSettingsConn = tSettings;
      final Connection tCompanyConn = tCompany;

      await _ensureTombstoneInfraBestEffort(sCloudConn, dbKey: cloudDbKey);
      await _ensureTombstoneInfraBestEffort(
        tSettingsConn,
        dbKey: localSettingsDbKey,
      );
      await _ensureTombstoneInfraBestEffort(
        tCompanyConn,
        dbKey: localCompanyDbKey,
      );

      await _ensureDeltaTimestampInfraBestEffort(sCloudConn, dbKey: cloudDbKey);
      await _ensureDeltaTimestampInfraBestEffort(
        tSettingsConn,
        dbKey: localSettingsDbKey,
      );
      await _ensureDeltaTimestampInfraBestEffort(
        tCompanyConn,
        dbKey: localCompanyDbKey,
      );

      await _ensureSequenceParityBestEffort(
        sCloudConn,
        dbKey: cloudDbKey,
        desiredParity: _cloudSequenceParity,
      );
      await _ensureSequenceParityBestEffort(
        tSettingsConn,
        dbKey: localSettingsDbKey,
        desiredParity: _localSequenceParity,
      );
      await _ensureSequenceParityBestEffort(
        tCompanyConn,
        dbKey: localCompanyDbKey,
        desiredParity: _localSequenceParity,
      );

      await _setSyncApplyFlagBestEffort(
        tSettingsConn,
        enabled: true,
        debugContext: 'delta-cloud->local(settings)',
      );
      await _setSyncApplyFlagBestEffort(
        tCompanyConn,
        enabled: true,
        debugContext: 'delta-cloud->local(company)',
      );

      final settingsTables = (await _listTables(tSettingsConn)).toSet();
      final companyTables = (await _listTables(tCompanyConn)).toSet();

      // 1) Hızlı delta: cloud outbox kuyruğunu yerele uygula.
      final cloudOutboxReady = await _isDeltaOutboxOperational(
        sCloudConn,
        dbKey: cloudDbKey,
      );

      final outboxItems = <_DeltaOutboxItem>[];
      if (cloudOutboxReady) {
        final rows = await _readDeltaOutbox(sCloudConn);
        outboxItems.addAll(
          rows.map(
            (r) => _DeltaOutboxItem(
              source: sCloudConn,
              sourceLabel: 'cloud',
              row: r,
            ),
          ),
        );
      }
      outboxItems.sort((a, b) => a.row.touchedAt.compareTo(b.row.touchedAt));

      if (outboxItems.isNotEmpty) {
        List<_DeltaOutboxItem> filteredItems = outboxItems;
        if (maxTables > 0) {
          final seen = <String>{};
          final keepTables = <String>[];
          for (final it in outboxItems) {
            final t = it.row.tableName.trim();
            if (t.isEmpty) continue;
            if (!settingsTables.contains(t) && !companyTables.contains(t)) {
              continue;
            }
            if (seen.add(t)) {
              keepTables.add(t);
              if (keepTables.length >= maxTables) break;
            }
          }
          final keepSet = keepTables.toSet();
          filteredItems = <_DeltaOutboxItem>[
            for (final it in outboxItems)
              if (keepSet.contains(it.row.tableName.trim())) it,
          ];
        }

        final itemsForSettings = <_DeltaOutboxItem>[
          for (final it in filteredItems)
            if (settingsTables.contains(it.row.tableName.trim())) it,
        ];
        final itemsForCompany = <_DeltaOutboxItem>[
          for (final it in filteredItems)
            if (companyTables.contains(it.row.tableName.trim())) it,
        ];

        final settingsApply = await _applyDeltaOutboxItemsToTarget(
          tSettingsConn,
          items: itemsForSettings,
          companyIdOverride: localCompanyDb,
        );
        final companyApply = await _applyDeltaOutboxItemsToTarget(
          tCompanyConn,
          items: itemsForCompany,
          companyIdOverride: localCompanyDb,
        );

        appliedRows += settingsApply.applied + companyApply.applied;
        touchedTables
          ..addAll(settingsApply.tablesTouched)
          ..addAll(companyApply.tablesTouched);

        if (settingsApply.tablesTouched.isNotEmpty) {
          await _fixSequences(
            tSettingsConn,
            settingsApply.tablesTouched.toList(),
            desiredParity: _localSequenceParity,
          );
        }
        if (companyApply.tablesTouched.isNotEmpty) {
          await _fixSequences(
            tCompanyConn,
            companyApply.tablesTouched.toList(),
            desiredParity: _localSequenceParity,
          );
        }

        String idOf(_DeltaOutboxItem it) =>
            '${it.row.tableName}|${it.row.pkHash}|${it.row.touchedAt.toIso8601String()}|${it.row.action}';

        final succeededSettings = <String>{
          for (final it in settingsApply.succeeded) idOf(it),
        };
        final succeededCompany = <String>{
          for (final it in companyApply.succeeded) idOf(it),
        };
        final failuresById = <String, String>{};
        for (final f in [...settingsApply.failed, ...companyApply.failed]) {
          failuresById[idOf(f.item)] = f.error;
        }

        for (final it in filteredItems) {
          final table = it.row.tableName.trim();
          final needSettings = settingsTables.contains(table);
          final needCompany = companyTables.contains(table);

          if (!needSettings && !needCompany) {
            await _ackDeltaOutboxRow(sCloudConn, row: it.row);
            continue;
          }

          final okSettings =
              !needSettings || succeededSettings.contains(idOf(it));
          final okCompany = !needCompany || succeededCompany.contains(idOf(it));
          if (okSettings && okCompany) {
            await _ackDeltaOutboxRow(sCloudConn, row: it.row);
          } else {
            await _markDeltaOutboxRowFailed(
              sCloudConn,
              row: it.row,
              error: failuresById[idOf(it)] ?? 'apply_failed',
            );
          }
        }
      }

      // 2) Fallback delta (outbox altyapısı yoksa): pg_stat tabanlı tespit + timestamp delta kopyalama.
      var copiedRows = 0;
      final copiedTables = <String>{};
      final copiedSettingsTables = <String>[];
      final copiedCompanyTables = <String>[];

      if (!cloudOutboxReady) {
        final changedTables = await _detectChangedTables(
          conn: sCloudConn,
          prev: _deltaCloudModsByTable,
        );

        // Tombstone tablosunu "veri" gibi delta kopyalamayız; ayrı akışta işleriz.
        final effectiveChanged = <String>{
          for (final t in changedTables)
            if (t != _tombstonesTable &&
                !_transferExcludedTables.contains(t.trim().toLowerCase()))
              t,
        };

        final allTables = <String>[
          for (final t in effectiveChanged)
            if (settingsTables.contains(t) || companyTables.contains(t)) t,
        ]..sort();

        if (allTables.isNotEmpty) {
          final limitedTables =
              (maxTables > 0 && allTables.length > maxTables)
                  ? allTables.take(maxTables).toList()
                  : allTables;

          final ordered =
              await _topologicalInsertOrder(sCloudConn, limitedTables);

          for (final table in ordered) {
            if (settingsTables.contains(table)) {
              final copied = await _copyTableFromMultipleSources(
                sources: <_DbSource>[_DbSource(sCloudConn, 'cloud')],
                target: tSettingsConn,
                table: table,
                tip: VeritabaniAktarimTipi.birlestir,
                companyIdOverride: localCompanyDb,
                deltaSince: effectiveSince,
              );
              if (copied > 0) {
                copiedTables.add(table);
                copiedSettingsTables.add(table);
                touchedTables.add(table);
              }
              copiedRows += copied;
            }

            if (companyTables.contains(table)) {
              final copied = await _copyTableFromMultipleSources(
                sources: <_DbSource>[_DbSource(sCloudConn, 'cloud')],
                target: tCompanyConn,
                table: table,
                tip: VeritabaniAktarimTipi.birlestir,
                companyIdOverride: localCompanyDb,
                deltaSince: effectiveSince,
              );
              if (copied > 0) {
                copiedTables.add(table);
                copiedCompanyTables.add(table);
                touchedTables.add(table);
              }
              copiedRows += copied;
            }
          }

          if (copiedSettingsTables.isNotEmpty) {
            await _fixSequences(
              tSettingsConn,
              copiedSettingsTables,
              desiredParity: _localSequenceParity,
            );
          }
          if (copiedCompanyTables.isNotEmpty) {
            await _fixSequences(
              tCompanyConn,
              copiedCompanyTables,
              desiredParity: _localSequenceParity,
            );
          }
        }
      }

      // DELETE senkronu: Buluttaki tombstone'ları yerele uygula (best-effort).
      await _syncTombstonesCloudToLocal(
        cloud: sCloudConn,
        localSettings: tSettingsConn,
        localCompany: tCompanyConn,
        settingsTables: settingsTables,
        companyTables: companyTables,
        since: effectiveSince,
      );

      appliedRows += copiedRows;

      final list = touchedTables.toList()..sort();
      return VeritabaniDeltaSenkronRapor(
        tabloSayisi: list.length,
        satirSayisi: appliedRows,
        tablolar: list,
        elapsed: sw.elapsed,
      );
    } finally {
      sw.stop();
      await _safeClose(sCloud);
      await _safeClose(tSettings);
      await _safeClose(tCompany);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Direction implementations
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _localToCloud({
    required _DbConn localSettings,
    required _DbConn localCompany,
    required _DbConn cloud,
    required VeritabaniAktarimTipi tip,
    void Function(VeritabaniAktarimIlerleme ilerleme)? onIlerleme,
  }) async {
    // Güvenlik: kaynak/hedef aynı görünüyorsa asla truncate/aktarim yapma.
    if (_isSameEndpoint(cloud, localSettings) ||
        _isSameEndpoint(cloud, localCompany)) {
      throw StateError(
        'Veri aktarımı iptal edildi: Kaynak ve hedef veritabanı aynı görünüyor. '
        'Bağlantı ayarlarını kontrol edin.',
      );
    }

    Connection? sSettings;
    Connection? sCompany;
    Connection? tCloud;

    try {
      sSettings = await _open(localSettings);
      sCompany = await _open(localCompany);
      tCloud = await _open(cloud);

      final Connection sSettingsConn = sSettings;
      final Connection sCompanyConn = sCompany;
      final Connection tCloudConn = tCloud;

      final targetTables = await _listTables(tCloudConn);
      final settingsTables = await _listTables(sSettingsConn);
      final companyTables = await _listTables(sCompanyConn);

      final Set<String> tableSet = <String>{};
      for (final t in targetTables) {
        if (settingsTables.contains(t) || companyTables.contains(t)) {
          tableSet.add(t);
        }
      }
      final tables = tableSet.toList()..sort();
      if (tables.isEmpty) return;

      final insertOrder = await _topologicalInsertOrder(tCloudConn, tables);

      // Tam aktarımda veri kaybını önlemek için: truncate öncesi şema ön-kontrolü.
      // Her tabloda en az bir kaynakla ortak kolon yoksa copy aşamasında tablo boş kalır.
      if (tip == VeritabaniAktarimTipi.tamAktar) {
        final cloudColsCache = <String, List<String>>{};
        final settingsColsCache = <String, List<String>>{};
        final companyColsCache = <String, List<String>>{};

        Future<List<String>> colsCached(
          Connection conn,
          Map<String, List<String>> cache,
          String table,
        ) async {
          final existing = cache[table];
          if (existing != null) return existing;
          final cols = await _columns(conn, table);
          cache[table] = cols;
          return cols;
        }

        bool hasAnyCommon(List<String> a, List<String> b) {
          if (a.isEmpty || b.isEmpty) return false;
          final setB = b.toSet();
          for (final c in a) {
            if (setB.contains(c)) return true;
          }
          return false;
        }

        final issues = <String>[];
        for (final table in insertOrder) {
          final targetCols = await colsCached(
            tCloudConn,
            cloudColsCache,
            table,
          );
          var ok = false;
          if (settingsTables.contains(table)) {
            final srcCols = await colsCached(
              sSettingsConn,
              settingsColsCache,
              table,
            );
            ok = ok || hasAnyCommon(targetCols, srcCols);
          }
          if (companyTables.contains(table)) {
            final srcCols = await colsCached(
              sCompanyConn,
              companyColsCache,
              table,
            );
            ok = ok || hasAnyCommon(targetCols, srcCols);
          }
          if (!ok) issues.add(table);
        }

        if (issues.isNotEmpty) {
          final shown = issues.take(12).join(', ');
          final extra = issues.length > 12 ? ' (+${issues.length - 12})' : '';
          throw StateError(
            'Tam aktarım yapılamadı: Şema uyumsuzluğu. '
            'Aşağıdaki tablolar için ortak kolon bulunamadı: $shown$extra',
          );
        }
      }

      final totalSteps =
          insertOrder.length +
          1 +
          (tip == VeritabaniAktarimTipi.tamAktar ? 1 : 0) +
          (tip == VeritabaniAktarimTipi.birlestir ? 1 : 0);
      var doneSteps = 0;
      void emit(String? current) {
        onIlerleme?.call(
          VeritabaniAktarimIlerleme(
            tamamlananAdim: doneSteps,
            toplamAdim: totalSteps,
            mevcut: current,
          ),
        );
      }

      emit(null);

      await _withTransaction(tCloudConn, () async {
        final snapshots = tip == VeritabaniAktarimTipi.birlestir
            ? await _captureMergeSnapshots(target: tCloudConn, tables: tableSet)
            : null;

        if (tip == VeritabaniAktarimTipi.tamAktar) {
          emit('truncate');
          // Tam aktarım: sadece aktaracağımız tabloları temizle (CASCADE kullanma).
          // Böylece hedefte olup kaynakta olmayan tablolar yanlışlıkla boşaltılmaz.
          await _truncateTables(tCloudConn, tables);
          doneSteps++;
          emit('truncate');
        }

        for (final table in insertOrder) {
          emit(table);
          final List<_DbSource> sources = <_DbSource>[];
          // Önce settings, sonra company (çakışmada company kazansın).
          if (settingsTables.contains(table)) {
            sources.add(_DbSource(sSettingsConn, 'settings'));
          }
          if (companyTables.contains(table)) {
            sources.add(_DbSource(sCompanyConn, 'company'));
          }
          if (sources.isEmpty) continue;

          await _copyTableFromMultipleSources(
            sources: sources,
            target: tCloudConn,
            table: table,
            tip: tip,
            // Cloud modda `company_id` filtreleri aktif DB adına göre çalışır.
            // Local DB'de `company_id` genelde şirket DB adı (örn. patisyo_lotpos).
            // Cloud DB'de ise tek veritabanı adı (örn. postgres) kullanılır.
            // Bu yüzden local -> cloud aktarımında `company_id` hedef DB adına normalize edilir.
            companyIdOverride: cloud.database,
          );
          doneSteps++;
          emit(table);
        }

        emit('sequences');
        await _fixSequences(
          tCloudConn,
          tables,
          desiredParity: _cloudSequenceParity,
        );
        doneSteps++;
        emit('sequences');

        if (tip == VeritabaniAktarimTipi.birlestir) {
          emit('maintenance');
          await _postMergeMaintenance(
            target: tCloudConn,
            tables: tableSet,
            snapshots: snapshots,
          );
          doneSteps++;
          emit('maintenance');
        }
      });
    } finally {
      await _safeClose(sSettings);
      await _safeClose(sCompany);
      await _safeClose(tCloud);
    }
  }

  Future<void> _cloudToLocal({
    required _DbConn cloud,
    required _DbConn localSettings,
    required _DbConn localCompany,
    required VeritabaniAktarimTipi tip,
    void Function(VeritabaniAktarimIlerleme ilerleme)? onIlerleme,
  }) async {
    // Güvenlik: kaynak/hedef aynı görünüyorsa asla truncate/aktarim yapma.
    if (_isSameEndpoint(cloud, localSettings) ||
        _isSameEndpoint(cloud, localCompany) ||
        _isSameEndpoint(localSettings, localCompany)) {
      throw StateError(
        'Veri aktarımı iptal edildi: Kaynak ve hedef veritabanı aynı görünüyor. '
        'Bağlantı ayarlarını kontrol edin.',
      );
    }

    Connection? sCloud;
    Connection? tSettings;
    Connection? tCompany;

    try {
      sCloud = await _open(cloud);
      tSettings = await _open(localSettings);
      tCompany = await _open(localCompany);

      final Connection sCloudConn = sCloud;
      final Connection tSettingsConn = tSettings;
      final Connection tCompanyConn = tCompany;

      final sourceTables = await _listTables(sCloudConn);
      final settingsTables = await _listTables(tSettingsConn);
      final companyTables = await _listTables(tCompanyConn);

      final Set<String> settingsCopy = <String>{};
      final Set<String> companyCopy = <String>{};

      for (final t in sourceTables) {
        if (settingsTables.contains(t)) settingsCopy.add(t);
        if (companyTables.contains(t)) companyCopy.add(t);
      }

      final settingsList = settingsCopy.toList()..sort();
      final companyList = companyCopy.toList()..sort();
      if (settingsList.isEmpty && companyList.isEmpty) return;

      final settingsOrder = settingsList.isEmpty
          ? const <String>[]
          : await _topologicalInsertOrder(tSettingsConn, settingsList);
      final companyOrder = companyList.isEmpty
          ? const <String>[]
          : await _topologicalInsertOrder(tCompanyConn, companyList);

      final totalTables = settingsOrder.length + companyOrder.length;
      final totalSteps =
          totalTables +
          (tip == VeritabaniAktarimTipi.tamAktar ? 2 : 0) +
          (settingsList.isNotEmpty ? 1 : 0) +
          (companyList.isNotEmpty ? 1 : 0) +
          (tip == VeritabaniAktarimTipi.birlestir ? 1 : 0);
      var doneSteps = 0;
      void emit(String? current) {
        onIlerleme?.call(
          VeritabaniAktarimIlerleme(
            tamamlananAdim: doneSteps,
            toplamAdim: totalSteps,
            mevcut: current,
          ),
        );
      }

      emit(null);

      // Tam aktarımda veri kaybını önlemek için: truncate öncesi şema ön-kontrolü.
      if (tip == VeritabaniAktarimTipi.tamAktar) {
        final cloudColsCache = <String, List<String>>{};
        final settingsColsCache = <String, List<String>>{};
        final companyColsCache = <String, List<String>>{};

        Future<List<String>> colsCached(
          Connection conn,
          Map<String, List<String>> cache,
          String table,
        ) async {
          final existing = cache[table];
          if (existing != null) return existing;
          final cols = await _columns(conn, table);
          cache[table] = cols;
          return cols;
        }

        bool hasAnyCommon(List<String> a, List<String> b) {
          if (a.isEmpty || b.isEmpty) return false;
          final setB = b.toSet();
          for (final c in a) {
            if (setB.contains(c)) return true;
          }
          return false;
        }

        final issues = <String>[];
        for (final table in settingsOrder) {
          final targetCols = await colsCached(
            tSettingsConn,
            settingsColsCache,
            table,
          );
          final srcCols = await colsCached(sCloudConn, cloudColsCache, table);
          if (!hasAnyCommon(targetCols, srcCols)) {
            issues.add('settings.$table');
          }
        }
        for (final table in companyOrder) {
          final targetCols = await colsCached(
            tCompanyConn,
            companyColsCache,
            table,
          );
          final srcCols = await colsCached(sCloudConn, cloudColsCache, table);
          if (!hasAnyCommon(targetCols, srcCols)) {
            issues.add('company.$table');
          }
        }

        if (issues.isNotEmpty) {
          final shown = issues.take(12).join(', ');
          final extra = issues.length > 12 ? ' (+${issues.length - 12})' : '';
          throw StateError(
            'Tam aktarım yapılamadı: Şema uyumsuzluğu. '
            'Aşağıdaki tablolar için ortak kolon bulunamadı: $shown$extra',
          );
        }
      }

      // Cloud -> Local: iki ayrı DB var. Partial state bırakmamak için mümkün olduğunca
      // iki hedefi de transaction içinde güncelle (TRUNCATE dahil rollback edilebilir).
      final settingsReplica = await _trySetSessionReplicationRole(
        tSettingsConn,
        'replica',
        debugContext: 'cloudToLocal.settings',
      );
      final companyReplica = await _trySetSessionReplicationRole(
        tCompanyConn,
        'replica',
        debugContext: 'cloudToLocal.company',
      );

      await tSettingsConn.execute('BEGIN');
      await tCompanyConn.execute('BEGIN');
      try {
        final snapshots = tip == VeritabaniAktarimTipi.birlestir
            ? await _captureMergeSnapshots(
                target: tCompanyConn,
                tables: companyCopy,
              )
            : null;

        await _bestEffortInTransaction(
          tSettingsConn,
          'SET CONSTRAINTS ALL DEFERRED',
          debugContext: 'cloudToLocal.settings',
        );
        await _bestEffortInTransaction(
          tCompanyConn,
          'SET CONSTRAINTS ALL DEFERRED',
          debugContext: 'cloudToLocal.company',
        );
        // [2026 PERF] Trigger'ları devre dışı bırak (cloud→local)
        // NOT: Trigger disable (session_replication_role) best-effort olarak
        // transaction DIŞINDA denenir. (Superuser yoksa başarısız olabilir.)

        if (tip == VeritabaniAktarimTipi.tamAktar) {
          emit('settings.truncate');
          // Tam aktarım: sadece aktaracağımız tabloları temizle (CASCADE kullanma).
          // Böylece hedefte olup kaynakta olmayan tablolar yanlışlıkla boşaltılmaz.
          await _truncateTables(tSettingsConn, settingsList);
          doneSteps++;
          emit('settings.truncate');

          emit('company.truncate');
          await _truncateTables(tCompanyConn, companyList);
          doneSteps++;
          emit('company.truncate');
        }

        for (final table in settingsOrder) {
          emit('settings.$table');
          await _copyTableFromMultipleSources(
            sources: <_DbSource>[_DbSource(sCloudConn, 'cloud')],
            target: tSettingsConn,
            table: table,
            tip: tip,
            // Cloud tarafında `company_id` hedef DB adı olabilir (örn. postgres).
            // Local tarafta `company_id` şirket DB adı olmalı (örn. patisyo_lotpos).
            companyIdOverride: localCompany.database,
          );
          doneSteps++;
          emit('settings.$table');
        }
        for (final table in companyOrder) {
          emit('company.$table');
          await _copyTableFromMultipleSources(
            sources: <_DbSource>[_DbSource(sCloudConn, 'cloud')],
            target: tCompanyConn,
            table: table,
            tip: tip,
            companyIdOverride: localCompany.database,
          );
          doneSteps++;
          emit('company.$table');
        }

        if (settingsList.isNotEmpty) {
          emit('settings.sequences');
          await _fixSequences(
            tSettingsConn,
            settingsList,
            desiredParity: _localSequenceParity,
          );
          doneSteps++;
          emit('settings.sequences');
        }
        if (companyList.isNotEmpty) {
          emit('company.sequences');
          await _fixSequences(
            tCompanyConn,
            companyList,
            desiredParity: _localSequenceParity,
          );
          doneSteps++;
          emit('company.sequences');
        }

        if (tip == VeritabaniAktarimTipi.birlestir) {
          emit('company.maintenance');
          await _postMergeMaintenance(
            target: tCompanyConn,
            tables: companyCopy,
            snapshots: snapshots,
          );
          doneSteps++;
          emit('company.maintenance');
        }

        // Transaction'ları commit et (iki hedef DB)
        await tSettingsConn.execute('COMMIT');
        await tCompanyConn.execute('COMMIT');
      } catch (_) {
        try {
          await tSettingsConn.execute('ROLLBACK');
        } catch (_) {}
        try {
          await tCompanyConn.execute('ROLLBACK');
        } catch (_) {}
        rethrow;
      } finally {
        if (settingsReplica) {
          await _trySetSessionReplicationRole(
            tSettingsConn,
            'DEFAULT',
            debugContext: 'cloudToLocal.settings',
          );
        }
        if (companyReplica) {
          await _trySetSessionReplicationRole(
            tCompanyConn,
            'DEFAULT',
            debugContext: 'cloudToLocal.company',
          );
        }
      }
    } finally {
      await _safeClose(sCloud);
      await _safeClose(tSettings);
      await _safeClose(tCompany);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Copy helpers
  // ──────────────────────────────────────────────────────────────────────────

  Future<_MergeSnapshots?> _captureMergeSnapshots({
    required Connection target,
    required Set<String> tables,
  }) async {
    if (tables.isEmpty) return null;
    final suffix = DateTime.now().microsecondsSinceEpoch;

    String? bankOpenings;
    String? cashOpenings;
    String? creditOpenings;

    // Açılış bakiyeleri: (mevcut bakiye) - (işlem toplamı)
    // Not: ON COMMIT DROP => commit/rollback sonrası temizlik otomatik.
    if (tables.contains('banks') && tables.contains('bank_transactions')) {
      bankOpenings = 'tmp_bank_openings_$suffix';
      await target.execute('''
        CREATE TEMP TABLE $bankOpenings ON COMMIT DROP AS
        SELECT
          b.id,
          COALESCE(b.balance, 0) - COALESCE(t.delta, 0) AS opening
        FROM public.banks b
        LEFT JOIN (
          SELECT
            bank_id,
            SUM(
              CASE WHEN type = 'Tahsilat'
              THEN COALESCE(amount, 0)
              ELSE -COALESCE(amount, 0)
              END
            ) AS delta
          FROM public.bank_transactions
          WHERE bank_id IS NOT NULL
          GROUP BY bank_id
        ) t ON t.bank_id = b.id
      ''');
    }

    if (tables.contains('cash_registers') &&
        tables.contains('cash_register_transactions')) {
      cashOpenings = 'tmp_cash_openings_$suffix';
      await target.execute('''
        CREATE TEMP TABLE $cashOpenings ON COMMIT DROP AS
        SELECT
          cr.id,
          COALESCE(cr.balance, 0) - COALESCE(t.delta, 0) AS opening
        FROM public.cash_registers cr
        LEFT JOIN (
          SELECT
            cash_register_id,
            SUM(
              CASE WHEN type IN ('Tahsilat', 'Para Alındı')
              THEN COALESCE(amount, 0)
              ELSE -COALESCE(amount, 0)
              END
            ) AS delta
          FROM public.cash_register_transactions
          WHERE cash_register_id IS NOT NULL
          GROUP BY cash_register_id
        ) t ON t.cash_register_id = cr.id
      ''');
    }

    if (tables.contains('credit_cards') &&
        tables.contains('credit_card_transactions')) {
      creditOpenings = 'tmp_credit_openings_$suffix';
      await target.execute('''
        CREATE TEMP TABLE $creditOpenings ON COMMIT DROP AS
        SELECT
          cc.id,
          COALESCE(cc.balance, 0) - COALESCE(t.delta, 0) AS opening
        FROM public.credit_cards cc
        LEFT JOIN (
          SELECT
            credit_card_id,
            SUM(
              CASE WHEN type IN ('Çıkış', 'Harcama')
              THEN -COALESCE(amount, 0)
              ELSE COALESCE(amount, 0)
              END
            ) AS delta
          FROM public.credit_card_transactions
          WHERE credit_card_id IS NOT NULL
          GROUP BY credit_card_id
        ) t ON t.credit_card_id = cc.id
      ''');
    }

    if (bankOpenings == null &&
        cashOpenings == null &&
        creditOpenings == null) {
      return null;
    }

    return _MergeSnapshots(
      bankOpeningsTable: bankOpenings,
      cashOpeningsTable: cashOpenings,
      creditOpeningsTable: creditOpenings,
    );
  }

  Future<void> _postMergeMaintenance({
    required Connection target,
    required Set<String> tables,
    required _MergeSnapshots? snapshots,
  }) async {
    if (tables.isEmpty) return;

    // 1) Stok + maliyet (kronolojik): stock_movements.running_* + products.stok/alis_fiyati
    if (tables.contains('stock_movements') && tables.contains('products')) {
      await _recalculateProductStocksAndCosts(target);

      // 2) Depo stoklarını yeniden üret (warehouse_stocks.quantity)
      if (tables.contains('warehouse_stocks')) {
        await _rebuildWarehouseStocks(target);
      }
    }

    // 3) Cari bakiye ve hareket bakiyeleri (kümülatif)
    if (tables.contains('current_accounts') &&
        tables.contains('current_account_transactions')) {
      await _recalculateCurrentAccountBalances(target);
    }

    // 4) Banka/Kasa/Kart bakiyeleri (açılış + işlem toplamı)
    await _restoreFinancialBalancesFromSnapshots(
      target: target,
      snapshots: snapshots,
    );
  }

  Future<void> _recalculateProductStocksAndCosts(Connection conn) async {
    final smCols = await _columns(conn, 'stock_movements');
    final prodCols = await _columns(conn, 'products');

    const requiredSmCols = <String>{
      'id',
      'product_id',
      'quantity',
      'is_giris',
      'unit_price',
      'currency_rate',
      'movement_date',
      'running_stock',
      'running_cost',
    };
    const requiredProdCols = <String>{'id', 'stok', 'alis_fiyati'};
    if (!requiredSmCols.every(smCols.contains) ||
        !requiredProdCols.every(prodCols.contains)) {
      return;
    }

    final hasProductUpdatedAt = prodCols.contains('updated_at');

    // Weighted Average Cost (WAC) + running stock, per product, chronologically.
    // Bu işlem "Birleştir" sonrasında zorunlu: iki kaynağın hareketleri zaman içinde
    // iç içe geçebilir; mevcut running_* alanları tek başına güvenilir değildir.
    if (hasProductUpdatedAt) {
      await conn.execute(r'''
        DO $$
        DECLARE
          v_product_id INTEGER;
          v_move RECORD;
          current_stock NUMERIC := 0;
          current_total_value NUMERIC := 0;
          current_avg_cost NUMERIC := 0;
          qty NUMERIC := 0;
          local_price NUMERIC := 0;
        BEGIN
          FOR v_product_id IN
            SELECT DISTINCT product_id
            FROM public.stock_movements
            WHERE product_id IS NOT NULL
            ORDER BY product_id
          LOOP
            current_stock := 0;
            current_total_value := 0;
            current_avg_cost := 0;

            FOR v_move IN
              SELECT id, quantity, is_giris, unit_price, currency_rate
              FROM public.stock_movements
              WHERE product_id = v_product_id
              ORDER BY movement_date ASC, id ASC
            LOOP
              qty := COALESCE(v_move.quantity, 0);
              local_price := COALESCE(v_move.unit_price, 0) * COALESCE(v_move.currency_rate, 1);

              IF v_move.is_giris THEN
                current_total_value := current_total_value + (qty * local_price);
                current_stock := current_stock + qty;
                IF current_stock > 0 THEN
                  current_avg_cost := current_total_value / current_stock;
                END IF;
              ELSE
                current_stock := current_stock - qty;
                current_total_value := current_stock * current_avg_cost;
                IF current_stock <= 0 THEN
                  current_total_value := 0;
                END IF;
              END IF;

              UPDATE public.stock_movements
              SET running_stock = current_stock,
                  running_cost = current_avg_cost
              WHERE id = v_move.id;
            END LOOP;

            UPDATE public.products
            SET stok = current_stock,
                alis_fiyati = current_avg_cost,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_product_id;
          END LOOP;
        END $$;
      ''');
      return;
    }

    await conn.execute(r'''
      DO $$
      DECLARE
        v_product_id INTEGER;
        v_move RECORD;
        current_stock NUMERIC := 0;
        current_total_value NUMERIC := 0;
        current_avg_cost NUMERIC := 0;
        qty NUMERIC := 0;
        local_price NUMERIC := 0;
      BEGIN
        FOR v_product_id IN
          SELECT DISTINCT product_id
          FROM public.stock_movements
          WHERE product_id IS NOT NULL
          ORDER BY product_id
        LOOP
          current_stock := 0;
          current_total_value := 0;
          current_avg_cost := 0;

          FOR v_move IN
            SELECT id, quantity, is_giris, unit_price, currency_rate
            FROM public.stock_movements
            WHERE product_id = v_product_id
            ORDER BY movement_date ASC, id ASC
          LOOP
            qty := COALESCE(v_move.quantity, 0);
            local_price := COALESCE(v_move.unit_price, 0) * COALESCE(v_move.currency_rate, 1);

            IF v_move.is_giris THEN
              current_total_value := current_total_value + (qty * local_price);
              current_stock := current_stock + qty;
              IF current_stock > 0 THEN
                current_avg_cost := current_total_value / current_stock;
              END IF;
            ELSE
              current_stock := current_stock - qty;
              current_total_value := current_stock * current_avg_cost;
              IF current_stock <= 0 THEN
                current_total_value := 0;
              END IF;
            END IF;

            UPDATE public.stock_movements
            SET running_stock = current_stock,
                running_cost = current_avg_cost
            WHERE id = v_move.id;
          END LOOP;

          UPDATE public.products
          SET stok = current_stock,
              alis_fiyati = current_avg_cost
          WHERE id = v_product_id;
        END LOOP;
      END $$;
    ''');
  }

  Future<void> _rebuildWarehouseStocks(Connection conn) async {
    final wsCols = await _columns(conn, 'warehouse_stocks');
    if (!wsCols.contains('warehouse_id') ||
        !wsCols.contains('product_code') ||
        !wsCols.contains('quantity')) {
      return;
    }

    final hasUpdatedAt = wsCols.contains('updated_at');

    // 1) Eski miktarları sıfırla (reserved_quantity korunur)
    if (hasUpdatedAt) {
      await conn.execute(
        'UPDATE public.warehouse_stocks SET quantity = 0, updated_at = CURRENT_TIMESTAMP',
      );
    } else {
      await conn.execute('UPDATE public.warehouse_stocks SET quantity = 0');
    }

    // 2) stock_movements üzerinden tekrar üret
    final updateClause = hasUpdatedAt
        ? 'quantity = EXCLUDED.quantity, updated_at = CURRENT_TIMESTAMP'
        : 'quantity = EXCLUDED.quantity';

    await conn.execute('''
      INSERT INTO public.warehouse_stocks (warehouse_id, product_code, quantity${hasUpdatedAt ? ', updated_at' : ''})
      SELECT
        sm.warehouse_id,
        p.kod AS product_code,
        SUM(
          CASE WHEN sm.is_giris
          THEN COALESCE(sm.quantity, 0)
          ELSE -COALESCE(sm.quantity, 0)
          END
        ) AS quantity
        ${hasUpdatedAt ? ', CURRENT_TIMESTAMP' : ''}
      FROM public.stock_movements sm
      JOIN public.products p ON p.id = sm.product_id
      WHERE sm.warehouse_id IS NOT NULL AND sm.product_id IS NOT NULL
      GROUP BY sm.warehouse_id, p.kod
      ON CONFLICT (warehouse_id, product_code)
      DO UPDATE SET $updateClause
    ''');
  }

  Future<void> _recalculateCurrentAccountBalances(Connection conn) async {
    final catCols = await _columns(conn, 'current_account_transactions');
    final caCols = await _columns(conn, 'current_accounts');

    const requiredCat = <String>{
      'id',
      'date',
      'current_account_id',
      'amount',
      'type',
      'para_birimi',
      'kur',
      'bakiye_borc',
      'bakiye_alacak',
    };
    const requiredCa = <String>{
      'id',
      'bakiye_borc',
      'bakiye_alacak',
      'para_birimi',
    };
    if (!requiredCat.every(catCols.contains) ||
        !requiredCa.every(caCols.contains)) {
      return;
    }

    final hasBalanceStatus = caCols.contains('bakiye_durumu');

    // 1) Hareket bakiyelerini (kümülatif) güncelle — döviz dönüşümü dahil
    await conn.execute(r'''
      WITH base AS (
        SELECT
          cat.id,
          cat.date,
          cat.current_account_id,
          cat.type,
          CASE
            WHEN cat.amount IS NULL THEN 0
            WHEN cat.para_birimi IS NULL OR ca.para_birimi IS NULL OR cat.para_birimi = ca.para_birimi THEN cat.amount
            WHEN cat.kur IS NULL OR cat.kur <= 0 THEN cat.amount
            WHEN ca.para_birimi = 'TRY' THEN cat.amount * cat.kur
            WHEN cat.para_birimi = 'TRY' THEN cat.amount / cat.kur
            ELSE cat.amount * cat.kur
          END AS amount_conv
        FROM public.current_account_transactions cat
        JOIN public.current_accounts ca ON ca.id = cat.current_account_id
      ),
      ordered AS (
        SELECT
          id,
          date,
          current_account_id,
          SUM(CASE WHEN type = 'Borç' THEN amount_conv ELSE 0 END)
            OVER (PARTITION BY current_account_id ORDER BY date ASC, id ASC) AS run_borc,
          SUM(CASE WHEN type = 'Alacak' THEN amount_conv ELSE 0 END)
            OVER (PARTITION BY current_account_id ORDER BY date ASC, id ASC) AS run_alacak
        FROM base
      )
      UPDATE public.current_account_transactions cat
      SET bakiye_borc = ordered.run_borc,
          bakiye_alacak = ordered.run_alacak
      FROM ordered
      WHERE cat.id = ordered.id AND cat.date = ordered.date
    ''');

    // 2) Cari kart bakiyelerini yeniden üret — döviz dönüşümü dahil
    if (hasBalanceStatus) {
      await conn.execute(r'''
        WITH base AS (
          SELECT
            cat.current_account_id,
            cat.type,
            CASE
              WHEN cat.amount IS NULL THEN 0
              WHEN cat.para_birimi IS NULL OR ca.para_birimi IS NULL OR cat.para_birimi = ca.para_birimi THEN cat.amount
              WHEN cat.kur IS NULL OR cat.kur <= 0 THEN cat.amount
              WHEN ca.para_birimi = 'TRY' THEN cat.amount * cat.kur
              WHEN cat.para_birimi = 'TRY' THEN cat.amount / cat.kur
              ELSE cat.amount * cat.kur
            END AS amount_conv
          FROM public.current_account_transactions cat
          JOIN public.current_accounts ca ON ca.id = cat.current_account_id
        ),
        sums AS (
          SELECT
            current_account_id,
            SUM(CASE WHEN type = 'Borç' THEN amount_conv ELSE 0 END) AS borc,
            SUM(CASE WHEN type = 'Alacak' THEN amount_conv ELSE 0 END) AS alacak
          FROM base
          GROUP BY current_account_id
        )
        UPDATE public.current_accounts ca
        SET bakiye_borc = COALESCE(sums.borc, 0),
            bakiye_alacak = COALESCE(sums.alacak, 0),
            bakiye_durumu = CASE
              WHEN COALESCE(sums.borc, 0) > COALESCE(sums.alacak, 0) THEN 'Borç'
              WHEN COALESCE(sums.alacak, 0) > COALESCE(sums.borc, 0) THEN 'Alacak'
              ELSE 'Dengeli'
            END
        FROM sums
        WHERE ca.id = sums.current_account_id
      ''');
      return;
    }

    await conn.execute(r'''
      WITH base AS (
        SELECT
          cat.current_account_id,
          cat.type,
          CASE
            WHEN cat.amount IS NULL THEN 0
            WHEN cat.para_birimi IS NULL OR ca.para_birimi IS NULL OR cat.para_birimi = ca.para_birimi THEN cat.amount
            WHEN cat.kur IS NULL OR cat.kur <= 0 THEN cat.amount
            WHEN ca.para_birimi = 'TRY' THEN cat.amount * cat.kur
            WHEN cat.para_birimi = 'TRY' THEN cat.amount / cat.kur
            ELSE cat.amount * cat.kur
          END AS amount_conv
        FROM public.current_account_transactions cat
        JOIN public.current_accounts ca ON ca.id = cat.current_account_id
      ),
      sums AS (
        SELECT
          current_account_id,
          SUM(CASE WHEN type = 'Borç' THEN amount_conv ELSE 0 END) AS borc,
          SUM(CASE WHEN type = 'Alacak' THEN amount_conv ELSE 0 END) AS alacak
        FROM base
        GROUP BY current_account_id
      )
      UPDATE public.current_accounts ca
      SET bakiye_borc = COALESCE(sums.borc, 0),
          bakiye_alacak = COALESCE(sums.alacak, 0)
      FROM sums
      WHERE ca.id = sums.current_account_id
    ''');
  }

  Future<void> _restoreFinancialBalancesFromSnapshots({
    required Connection target,
    required _MergeSnapshots? snapshots,
  }) async {
    if (snapshots == null) return;

    if (snapshots.bankOpeningsTable != null) {
      final o = snapshots.bankOpeningsTable!;
      await target.execute('''
        UPDATE public.banks b
        SET balance = o.opening + COALESCE(t.delta, 0)
        FROM $o o
        LEFT JOIN (
          SELECT
            bank_id,
            SUM(
              CASE WHEN type = 'Tahsilat'
              THEN COALESCE(amount, 0)
              ELSE -COALESCE(amount, 0)
              END
            ) AS delta
          FROM public.bank_transactions
          WHERE bank_id IS NOT NULL
          GROUP BY bank_id
        ) t ON t.bank_id = o.id
        WHERE b.id = o.id
      ''');
    }

    if (snapshots.cashOpeningsTable != null) {
      final o = snapshots.cashOpeningsTable!;
      await target.execute('''
        UPDATE public.cash_registers cr
        SET balance = o.opening + COALESCE(t.delta, 0)
        FROM $o o
        LEFT JOIN (
          SELECT
            cash_register_id,
            SUM(
              CASE WHEN type IN ('Tahsilat', 'Para Alındı')
              THEN COALESCE(amount, 0)
              ELSE -COALESCE(amount, 0)
              END
            ) AS delta
          FROM public.cash_register_transactions
          WHERE cash_register_id IS NOT NULL
          GROUP BY cash_register_id
        ) t ON t.cash_register_id = o.id
        WHERE cr.id = o.id
      ''');
    }

    if (snapshots.creditOpeningsTable != null) {
      final o = snapshots.creditOpeningsTable!;
      await target.execute('''
        UPDATE public.credit_cards cc
        SET balance = o.opening + COALESCE(t.delta, 0)
        FROM $o o
        LEFT JOIN (
          SELECT
            credit_card_id,
            SUM(
              CASE WHEN type IN ('Çıkış', 'Harcama')
              THEN -COALESCE(amount, 0)
              ELSE COALESCE(amount, 0)
              END
            ) AS delta
          FROM public.credit_card_transactions
          WHERE credit_card_id IS NOT NULL
          GROUP BY credit_card_id
        ) t ON t.credit_card_id = o.id
        WHERE cc.id = o.id
      ''');
    }
  }

  Future<int> _copyTableFromMultipleSources({
    required List<_DbSource> sources,
    required Connection target,
    required String table,
    required VeritabaniAktarimTipi tip,
    String? companyIdOverride,
    DateTime? deltaSince,
  }) async {
    final normalizedTable = table.trim().toLowerCase();
    if (_transferExcludedTables.contains(normalizedTable)) return 0;

    // Target şemaya göre conflict kolonlarını al (PK)
    final conflictCols = await _primaryKeyColumns(target, table);
    final targetCols = await _columns(target, table);
    if (targetCols.isEmpty) return 0;

    var totalCopied = 0;
    for (final src in sources) {
      final srcCols = await _columns(src.conn, table);
      if (srcCols.isEmpty) continue;

      final cols = <String>[
        for (final c in targetCols)
          if (srcCols.contains(c)) c,
      ];
      if (cols.isEmpty) continue;

      final where = deltaSince == null
          ? null
          : await _buildDeltaWhereClause(
              source: src.conn,
              table: table,
              since: deltaSince,
            );

      // Delta senkron: timestamp kolonu yoksa küçük tabloları full kopyalamaya izin ver.
      // Büyük tablolar için filtre yoksa atla (performans + yanlış senkron riskini azalt).
      if (deltaSince != null && where == null) {
        final allowlisted = _deltaFullCopyAllowlistNoTimestamps.contains(table);
        if (!allowlisted) {
          final est = await _estimateRowCount(src.conn, table);
          // reltuples=0 olabilir (istatistik yok). Bu durumda riskli: tabloyu atla.
          if (est == null || est <= 0 || est > 5000) continue;
        }
      }

      totalCopied += await _copyTableData(
        source: src.conn,
        sourceLabel: src.label,
        target: target,
        table: table,
        columns: cols,
        conflictColumns: conflictCols,
        // Tam aktarımda hedef tablo zaten temiz; yine de kaynaklar arası çakışmada update faydalı.
        upsert: tip == VeritabaniAktarimTipi.birlestir || sources.length > 1,
        companyIdOverride: companyIdOverride,
        whereClause: where?.sql,
        whereParams: where?.params,
      );
    }

    return totalCopied;
  }

  Future<int> _copyTableData({
    required Connection source,
    required String sourceLabel,
    required Connection target,
    required String table,
    required List<String> columns,
    required List<String> conflictColumns,
    required bool upsert,
    String? companyIdOverride,
    String? whereClause,
    Map<String, dynamic>? whereParams,
  }) async {
    // Cursor ile batch oku, batch insert.
    final sw = Stopwatch()..start();
    var totalRows = 0;
    final cursorName = 'cur_${DateTime.now().microsecondsSinceEpoch}';
    // Parametre limiti (65535) ve SQL boyutu için güvenli batch boyutu.
    final batchSize = _safeBatchSize(columns.length);
    final selectSql =
        'SELECT ${columns.map(_qi).join(', ')} FROM ${_qt(table)} ${whereClause ?? ''}';

    _log(
      'Copy start: $sourceLabel -> target, table=$table, cols=${columns.length}, batchSize=$batchSize',
    );

    await source.execute('BEGIN');
    try {
      final declareSql = 'DECLARE $cursorName NO SCROLL CURSOR FOR $selectSql';
      if (whereParams != null && whereParams.isNotEmpty) {
        await source.execute(Sql.named(declareSql), parameters: whereParams);
      } else {
        await source.execute(declareSql);
      }

      while (true) {
        final batch = await source.execute(
          'FETCH FORWARD $batchSize FROM $cursorName',
        );
        if (batch.isEmpty) break;
        totalRows += batch.length;

        final rows = <List<dynamic>>[];
        final companyIdIndex = companyIdOverride == null
            ? -1
            : columns.indexOf('company_id');
        for (final r in batch) {
          final row = List<dynamic>.from(r);
          if (companyIdIndex >= 0 && companyIdIndex < row.length) {
            row[companyIdIndex] = companyIdOverride;
          }
          rows.add(row);
        }

        await _insertBatch(
          target: target,
          table: table,
          columns: columns,
          conflictColumns: conflictColumns,
          rows: rows,
          upsert: upsert,
        );
      }

      await source.execute('CLOSE $cursorName');
      await source.execute('COMMIT');

      sw.stop();
      _log(
        'Copy done: $sourceLabel -> target, table=$table, rows=$totalRows, elapsed=${sw.elapsedMilliseconds}ms',
      );
      return totalRows;
    } catch (e) {
      try {
        await source.execute('ROLLBACK');
      } catch (_) {}
      sw.stop();
      _log(
        'Copy failed: $sourceLabel -> target, table=$table, rows=$totalRows, elapsed=${sw.elapsedMilliseconds}ms, error=$e',
      );
      rethrow;
    }
  }

  Future<void> _insertBatch({
    required Connection target,
    required String table,
    required List<String> columns,
    required List<String> conflictColumns,
    required List<List<dynamic>> rows,
    required bool upsert,
  }) async {
    if (rows.isEmpty) return;

    final udtByColumn = await _targetColumnUdtNames(target, table);
    final params = <String, dynamic>{};
    final sb = StringBuffer();
    sb.write(
      'INSERT INTO ${_qt(table)} AS t (${columns.map(_qi).join(', ')}) '
      'OVERRIDING SYSTEM VALUE VALUES ',
    );

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      sb.write('(');
      for (var j = 0; j < columns.length; j++) {
        final key = 'v_${i}_$j';
        final col = columns[j];
        final rawValue = j < row.length ? row[j] : null;
        params[key] = _bindValueForUdt(udtByColumn[col], rawValue);
        sb.write('@$key');
        if (j < columns.length - 1) sb.write(', ');
      }
      sb.write(')');
      if (i < rows.length - 1) sb.write(', ');
    }

    if (conflictColumns.isNotEmpty) {
      sb.write(' ON CONFLICT (${conflictColumns.map(_qi).join(', ')}) ');
      if (!upsert) {
        sb.write('DO NOTHING');
      } else {
        final updateCols = <String>[
          for (final c in columns)
            if (!conflictColumns.contains(c)) c,
        ];
        if (updateCols.isEmpty) {
          sb.write('DO NOTHING');
        } else {
          final hasUpdatedAt = updateCols.contains('updated_at');
          sb.write('DO UPDATE SET ');
          sb.write(
            updateCols.map((c) => '${_qi(c)} = EXCLUDED.${_qi(c)}').join(', '),
          );
          // No-op update'leri atla (ping-pong döngüsünü ve gereksiz yazımları engeller).
          final distinctExpr = updateCols
              .map((c) => 't.${_qi(c)} IS DISTINCT FROM EXCLUDED.${_qi(c)}')
              .join(' OR ');
          sb.write(' WHERE (');
          sb.write(distinctExpr);
          sb.write(')');
          if (hasUpdatedAt) {
            // Hibrit çatışma koruması: daha yeni kaydı daha eski veriyle ezme.
            sb.write(
              ' AND (t."updated_at" IS NULL OR (EXCLUDED."updated_at" IS NOT NULL AND EXCLUDED."updated_at" >= t."updated_at"))',
            );
          }
        }
      }
    } else {
      // PK yoksa: duplicate riskine karşı en güvenli davranış
      sb.write(' ON CONFLICT DO NOTHING');
    }

    try {
      await target.execute(Sql.named(sb.toString()), parameters: params);
    } catch (e) {
      if (kDebugMode) {
        final jsonCols = <String>[
          for (final c in columns)
            if ((udtByColumn[c] ?? '') == 'jsonb' ||
                (udtByColumn[c] ?? '') == 'json')
              c,
        ];
        debugPrint(
          'DBAktarim: Insert batch failed. table=$table rows=${rows.length} jsonCols=${jsonCols.join(', ')} error=$e',
        );
      }
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Schema helpers
  // ──────────────────────────────────────────────────────────────────────────

  Future<List<String>> _listTables(Connection conn) async {
    final result = await conn.execute('''
      SELECT c.relname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relkind IN ('r', 'p')
        AND NOT c.relispartition
      ORDER BY c.relname
    ''');

    return result
        .map((r) => (r[0] as String).trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  Future<List<String>> _columns(Connection conn, String table) async {
    final result = await conn.execute(
      Sql.named('''
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = @t
        ORDER BY ordinal_position
      '''),
      parameters: {'t': table},
    );
    return result
        .map((r) => (r[0] as String?)?.trim() ?? '')
        .where((c) => c.isNotEmpty)
        .toList();
  }

  Future<bool> _tableExistsCached(Connection conn, String table) async {
    // _columns zaten empty döner ama info_schema sorgusu pahalı olabilir; burada hafif kontrol yap.
    // NOT: pg_class sadece public şeması.
    try {
      final result = await conn.execute(
        Sql.named('''
          SELECT 1
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'public'
            AND c.relname = @t
            AND c.relkind IN ('r', 'p')
          LIMIT 1
        '''),
        parameters: {'t': table},
      );
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, _ColumnMeta>> _columnMetas(
    Connection conn,
    String table,
  ) async {
    final result = await conn.execute(
      Sql.named('''
        SELECT column_name, column_default
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = @t
      '''),
      parameters: {'t': table},
    );

    final map = <String, _ColumnMeta>{};
    for (final r in result) {
      final name = (r[0] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final def = (r[1] as String?)?.trim();
      map[name] = _ColumnMeta(name: name, defaultExpr: def);
    }
    return map;
  }

  bool _isDefaultNow(String? expr) {
    final v = (expr ?? '').toLowerCase();
    return v.contains('current_timestamp') || v.contains('now()');
  }

  Future<_DeltaWhere?> _buildDeltaWhereClause({
    required Connection source,
    required String table,
    required DateTime since,
  }) async {
    final metas = await _columnMetas(source, table);
    final hasUpdated = metas.containsKey('updated_at');
    final hasCreated = metas.containsKey('created_at');

    if (hasUpdated && hasCreated) {
      return _DeltaWhere(
        sql:
            'WHERE (${_qi('updated_at')} >= @since OR (${_qi('updated_at')} IS NULL AND ${_qi('created_at')} >= @since))',
        params: {'since': since},
      );
    }
    if (hasUpdated) {
      return _DeltaWhere(
        sql: 'WHERE ${_qi('updated_at')} >= @since',
        params: {'since': since},
      );
    }
    if (hasCreated) {
      return _DeltaWhere(
        sql: 'WHERE ${_qi('created_at')} >= @since',
        params: {'since': since},
      );
    }

    // Bazı eski tablolarda created_at/updated_at yok; "date" default now ise best-effort kullan.
    final dateMeta = metas['date'];
    if (dateMeta != null && _isDefaultNow(dateMeta.defaultExpr)) {
      return _DeltaWhere(
        sql: 'WHERE ${_qi('date')} >= @since',
        params: {'since': since},
      );
    }

    return null;
  }

  Future<int?> _estimateRowCount(Connection conn, String table) async {
    try {
      final result = await conn.execute(
        Sql.named('''
          SELECT c.reltuples
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'public' AND c.relname = @t
          LIMIT 1
        '''),
        parameters: {'t': table},
      );
      if (result.isEmpty) return null;
      final v = result.first[0];
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    } catch (_) {
      return null;
    }
  }

  Future<Set<String>> _detectChangedTables({
    required Connection conn,
    required Map<String, int> prev,
  }) async {
    try {
      final rows = await conn.execute('''
        SELECT relname, (n_tup_ins + n_tup_upd + n_tup_del) AS mods
        FROM pg_stat_user_tables
      ''');

      final next = <String, int>{};
      final changed = <String>{};

      for (final r in rows) {
        final name = (r[0] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        final raw = r[1];
        final mods = raw is num ? raw.toInt() : int.tryParse(raw.toString()) ?? 0;
        next[name] = mods;
        final before = prev[name];
        if (before == null) {
          if (mods > 0) changed.add(name);
        } else if (mods != before) {
          changed.add(name);
        }
      }

      prev
        ..clear()
        ..addAll(next);

      return changed;
    } catch (e) {
      // pg_stat_user_tables okunamazsa: sessizce "0 değişti" demek, eksik senkron üretir.
      // Best-effort fallback: tüm tabloları değişti kabul edip timestamp delta ile ilerle.
      if (kDebugMode) {
        debugPrint('DBAktarim: pg_stat_user_tables okunamadı: $e');
      }
      try {
        final tables = await _listTables(conn);
        prev.clear();
        return tables.toSet();
      } catch (inner) {
        if (kDebugMode) {
          debugPrint('DBAktarim: changed-table fallback listTables failed: $inner');
        }
        return const <String>{};
      }
    }
  }

  Future<Map<String, String>> _targetColumnUdtNames(
    Connection target,
    String table,
  ) async {
    final cached = _targetColumnUdtNameCacheByTable[table];
    if (cached != null) return cached;

    final result = await target.execute(
      Sql.named('''
        SELECT column_name, udt_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = @t
      '''),
      parameters: {'t': table},
    );

    final map = <String, String>{};
    for (final r in result) {
      final name = (r[0] as String?)?.trim() ?? '';
      final udt = (r[1] as String?)?.trim().toLowerCase() ?? '';
      if (name.isEmpty) continue;
      map[name] = udt;
    }

    _targetColumnUdtNameCacheByTable[table] = map;
    return map;
  }

  dynamic _bindValueForUdt(String? udtName, dynamic value) {
    if (value == null) return null;
    final t = (udtName ?? '').trim().toLowerCase();
    if (t == 'jsonb') {
      return TypedValue(Type.jsonb, _coerceJsonEncodable(value));
    }
    if (t == 'json') {
      return TypedValue(Type.json, _coerceJsonEncodable(value));
    }
    if (t == '_jsonb') {
      final list = _coerceJsonbArray(value);
      if (list == null) return null;
      return TypedValue(Type.jsonbArray, list);
    }
    return value;
  }

  Object? _coerceJsonEncodable(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty &&
          (trimmed.startsWith('{') || trimmed.startsWith('['))) {
        try {
          return jsonDecode(trimmed);
        } catch (_) {}
      }
    }
    return value;
  }

  List<dynamic>? _coerceJsonbArray(dynamic value) {
    if (value == null) return null;
    if (value is List) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) return decoded;
        } catch (_) {}
      }
    }
    return <dynamic>[value];
  }

  Future<List<String>> _primaryKeyColumns(Connection conn, String table) async {
    try {
      final result = await conn.execute(
        Sql.named('''
        SELECT a.attname
        FROM pg_index i
        JOIN pg_class c ON c.oid = i.indrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_attribute a
          ON a.attrelid = c.oid
         AND a.attnum = ANY(i.indkey)
        WHERE i.indisprimary
          AND n.nspname = 'public'
          AND c.relname = @t
        ORDER BY array_position(i.indkey, a.attnum)
      '''),
        parameters: {'t': table},
      );

      return result
          .map((r) => (r[0] as String?)?.trim() ?? '')
          .where((c) => c.isNotEmpty)
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<List<String>> _topologicalInsertOrder(
    Connection conn,
    List<String> tables,
  ) async {
    final tableSet = tables.toSet();
    final edges = await _foreignKeyEdges(conn);

    // parent -> children
    final Map<String, Set<String>> graph = <String, Set<String>>{};
    final Map<String, int> indegree = <String, int>{};
    for (final t in tables) {
      graph[t] = <String>{};
      indegree[t] = 0;
    }

    for (final e in edges) {
      final child = e.child;
      final parent = e.parent;
      if (!tableSet.contains(child) || !tableSet.contains(parent)) continue;
      if (graph[parent]!.add(child)) {
        indegree[child] = (indegree[child] ?? 0) + 1;
      }
    }

    final List<String> queue = <String>[
      for (final t in tables)
        if ((indegree[t] ?? 0) == 0) t,
    ];
    queue.sort();

    final List<String> ordered = <String>[];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      ordered.add(current);
      for (final nxt in graph[current]!.toList()..sort()) {
        indegree[nxt] = (indegree[nxt] ?? 0) - 1;
        if ((indegree[nxt] ?? 0) == 0) {
          queue.add(nxt);
          queue.sort();
        }
      }
    }

    if (ordered.length != tables.length) {
      // Cycle veya eksik bağımlılık: deterministik şekilde kalanları ekle.
      final remaining = <String>[
        for (final t in tables)
          if (!ordered.contains(t)) t,
      ]..sort();
      ordered.addAll(remaining);
    }

    return ordered;
  }

  Future<List<_FkEdge>> _foreignKeyEdges(Connection conn) async {
    try {
      final result = await conn.execute('''
        SELECT c1.relname AS child, c2.relname AS parent
        FROM pg_constraint con
        JOIN pg_class c1 ON c1.oid = con.conrelid
        JOIN pg_class c2 ON c2.oid = con.confrelid
        JOIN pg_namespace n1 ON n1.oid = c1.relnamespace
        JOIN pg_namespace n2 ON n2.oid = c2.relnamespace
        WHERE con.contype = 'f'
          AND n1.nspname = 'public'
          AND n2.nspname = 'public'
      ''');
      return result
          .map(
            (r) => _FkEdge(
              child: (r[0] as String?)?.trim() ?? '',
              parent: (r[1] as String?)?.trim() ?? '',
            ),
          )
          .where((e) => e.child.isNotEmpty && e.parent.isNotEmpty)
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('FK edge read error: $e');
      return const <_FkEdge>[];
    }
  }

  Future<void> _truncateTables(Connection conn, List<String> tables) async {
    if (tables.isEmpty) return;
    final list = tables.map(_qt).join(', ');
    // RESTART IDENTITY: serial/identity alanlar sıfırlansın.
    // NOT: CASCADE kullanma. Aksi halde listede olmayan tablolar da boşalabilir ve veri kaybına yol açar.
    await conn.execute('TRUNCATE TABLE $list RESTART IDENTITY');
  }

  static bool _isSameEndpoint(_DbConn a, _DbConn b) {
    final ah = a.host.trim().toLowerCase();
    final bh = b.host.trim().toLowerCase();
    final ad = a.database.trim().toLowerCase();
    final bd = b.database.trim().toLowerCase();
    return ah == bh && a.port == b.port && ad == bd;
  }

  static int _safeBatchSize(int columnCount) {
    if (columnCount <= 0) return 200;
    const int maxParams = 60000;
    final rows = maxParams ~/ columnCount;
    if (rows <= 0) return 1;
    // [2026 PERF] 500 → 2000: 100M+ kayıtlı tablolarda 4x hızlanma.
    // 65535 parametre limiti dahilinde güvenli.
    return rows > 2000 ? 2000 : rows;
  }

  Future<void> _withTransaction(
    Connection conn,
    Future<void> Function() work,
  ) async {
    final replicaSet = await _trySetSessionReplicationRole(
      conn,
      'replica',
      debugContext: 'withTransaction',
    );

    await conn.execute('BEGIN');
    try {
      await _bestEffortInTransaction(
        conn,
        'SET CONSTRAINTS ALL DEFERRED',
        debugContext: 'withTransaction',
      );
      // [2026 PERF] Aktarım sırasında trigger'ları devre dışı bırak.
      // search_tags rebuild gibi ağır trigger'lar her satırda tetiklenmez.
      // NOT: session_replication_role transaction DIŞINDA best-effort denenir.
      await work();
      // Transaction'ı commit et
      await conn.execute('COMMIT');
    } catch (_) {
      try {
        await conn.execute('ROLLBACK');
      } catch (rollbackErr) {
        if (kDebugMode) {
          debugPrint('Rollback error (original error rethrown): $rollbackErr');
        }
      }
      rethrow;
    } finally {
      if (replicaSet) {
        await _trySetSessionReplicationRole(
          conn,
          'DEFAULT',
          debugContext: 'withTransaction',
        );
      }
    }
  }

  static int _savepointSeq = 0;

  static String _nextSavepointName() {
    _savepointSeq++;
    return 'sp_${DateTime.now().microsecondsSinceEpoch}_$_savepointSeq';
  }

  Future<void> _bestEffortInTransaction(
    Connection conn,
    String sql, {
    required String debugContext,
  }) async {
    final sp = _nextSavepointName();
    try {
      await conn.execute('SAVEPOINT $sp');
      try {
        await conn.execute(sql);
      } catch (e) {
        try {
          await conn.execute('ROLLBACK TO SAVEPOINT $sp');
        } catch (rollbackErr) {
          if (kDebugMode) {
            debugPrint(
              'Best-effort tx rollback failed ($debugContext): $rollbackErr',
            );
          }
        }
        if (kDebugMode) {
          debugPrint('Best-effort tx statement failed ($debugContext): $e');
        }
      } finally {
        try {
          await conn.execute('RELEASE SAVEPOINT $sp');
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Best-effort tx wrapper failed ($debugContext): $e');
      }
    }
  }

  Future<bool> _trySetSessionReplicationRole(
    Connection conn,
    String value, {
    required String debugContext,
  }) async {
    try {
      await conn.execute('SET session_replication_role = $value');
      return true;
    } catch (e) {
      final code = e is ServerException ? e.code : null;
      if (code == '42501') {
        // Neon gibi managed PostgreSQL'lerde superuser olmadığımız için normal.
        return false;
      }
      if (kDebugMode) {
        debugPrint(
          'SET session_replication_role failed ($debugContext, $value): $e',
        );
      }
      return false;
    }
  }

  Future<void> _ensureSequenceParityBestEffort(
    Connection conn, {
    required String dbKey,
    required int desiredParity,
  }) async {
    if (_sequenceParityReadyByDbKey.contains(dbKey)) return;
    final p = desiredParity == 0 ? 0 : 1;
    try {
      await conn.execute('''
        DO \$\$
        DECLARE
          r RECORD;
          maxv BIGINT;
          nextv BIGINT;
          seq_fqn TEXT;
        BEGIN
          FOR r IN
            SELECT
              seq.relname AS seq_name,
              tab.relname AS table_name,
              att.attname AS column_name
            FROM pg_class seq
            JOIN pg_depend dep ON dep.objid = seq.oid
            JOIN pg_class tab ON tab.oid = dep.refobjid
            JOIN pg_attribute att
              ON att.attrelid = tab.oid
             AND att.attnum = dep.refobjsubid
            JOIN pg_namespace ns_seq ON ns_seq.oid = seq.relnamespace
            JOIN pg_namespace ns_tab ON ns_tab.oid = tab.relnamespace
            WHERE seq.relkind = 'S'
              AND ns_seq.nspname = 'public'
              AND ns_tab.nspname = 'public'
          LOOP
            BEGIN
              EXECUTE format(
                'SELECT COALESCE(MAX(%I), 0) FROM public.%I',
                r.column_name,
                r.table_name
              ) INTO maxv;

              nextv := maxv + 1;
              IF mod(nextv, 2) <> $p THEN
                nextv := nextv + 1;
              END IF;

              EXECUTE format('ALTER SEQUENCE public.%I INCREMENT BY 2', r.seq_name);

              seq_fqn := format('%I.%I', 'public', r.seq_name);
              EXECUTE format(
                'SELECT setval(%L::regclass, %s, false)',
                seq_fqn,
                nextv
              );
            EXCEPTION WHEN others THEN
              -- ignore
            END;
          END LOOP;
        END
        \$\$;
      ''');
      _sequenceParityReadyByDbKey.add(dbKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DBAktarim: Sequence parity ensure failed ($dbKey): $e');
      }
    }
  }

  Future<void> _fixSequences(
    Connection conn,
    List<String> tables, {
    int? desiredParity,
  }) async {
    if (tables.isEmpty) return;
    final tableSet = tables.toSet();

    final result = await conn.execute('''
      SELECT
        seq.relname AS sequence_name,
        tab.relname AS table_name,
        att.attname AS column_name
      FROM pg_class seq
      JOIN pg_depend dep ON dep.objid = seq.oid
      JOIN pg_class tab ON tab.oid = dep.refobjid
      JOIN pg_attribute att
        ON att.attrelid = tab.oid
       AND att.attnum = dep.refobjsubid
      JOIN pg_namespace ns_seq ON ns_seq.oid = seq.relnamespace
      JOIN pg_namespace ns_tab ON ns_tab.oid = tab.relnamespace
      WHERE seq.relkind = 'S'
        AND ns_seq.nspname = 'public'
        AND ns_tab.nspname = 'public'
    ''');

    for (final row in result) {
      final seq = (row[0] as String?)?.trim() ?? '';
      final table = (row[1] as String?)?.trim() ?? '';
      final col = (row[2] as String?)?.trim() ?? '';
      if (seq.isEmpty || table.isEmpty || col.isEmpty) continue;
      if (!tableSet.contains(table)) continue;

      try {
        if (desiredParity == null) {
          await conn.execute(
            'SELECT setval(${_qs(seq)}, (SELECT COALESCE(MAX(${_qi(col)}), 0) FROM ${_qt(table)}) + 1, false)',
          );
        } else {
          final maxResult = await conn.execute(
            'SELECT COALESCE(MAX(${_qi(col)}), 0) FROM ${_qt(table)}',
          );
          final raw = maxResult.isNotEmpty ? maxResult.first[0] : 0;
          final maxId = raw is num ? raw.toInt() : int.tryParse(raw.toString()) ?? 0;
          var next = maxId + 1;
          final p = desiredParity == 0 ? 0 : 1;
          if (next % 2 != p) next++;

          await conn.execute('ALTER SEQUENCE public.${_qi(seq)} INCREMENT BY 2');
          await conn.execute('SELECT setval(${_qs(seq)}, $next, false)');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Sequence fix warning ($seq on $table.$col): $e');
        }
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Hybrid: DELETE sync via tombstones (sync_tombstones)
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _ensureTombstoneInfraBestEffort(
    Connection conn, {
    required String dbKey,
  }) async {
    if (_tombstoneInfraReadyByDbKey.contains(dbKey)) return;
    try {
      await conn.execute('''
        CREATE TABLE IF NOT EXISTS public.$_tombstonesTable (
          id BIGSERIAL PRIMARY KEY,
          table_name TEXT NOT NULL,
          pk JSONB NOT NULL,
          pk_hash TEXT NOT NULL,
          deleted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await conn.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS ux_sync_tombstones_table_pk ON public.$_tombstonesTable (table_name, pk_hash)',
      );
      await conn.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_tombstones_deleted_at ON public.$_tombstonesTable (deleted_at)',
      );

      await conn.execute('''
        CREATE OR REPLACE FUNCTION public.$_tombstoneTriggerFn()
        RETURNS trigger AS \$\$
        DECLARE
          pk_cols TEXT[];
          col TEXT;
          pk JSONB := '{}'::jsonb;
          row JSONB;
        BEGIN
          -- Senkron uygulaması sırasında (remote tombstone apply) tekrar tombstone üretme.
          IF COALESCE(current_setting('$_syncApplyGuc', true), '') = '1' THEN
            RETURN OLD;
          END IF;

          -- Dahili tabloları asla tombstone'lama.
          IF TG_TABLE_SCHEMA <> 'public' THEN
            RETURN OLD;
          END IF;
          IF TG_TABLE_NAME = '$_tombstonesTable' OR TG_TABLE_NAME = 'sync_outbox' OR TG_TABLE_NAME = '$_deltaOutboxTable' THEN
            RETURN OLD;
          END IF;

          row := to_jsonb(OLD);

          SELECT array_agg(a.attname ORDER BY a.attnum)
          INTO pk_cols
          FROM pg_index i
          JOIN pg_attribute a
            ON a.attrelid = i.indrelid
           AND a.attnum = ANY(i.indkey)
          WHERE i.indrelid = TG_RELID
            AND i.indisprimary;

          IF pk_cols IS NULL OR array_length(pk_cols, 1) IS NULL THEN
            RETURN OLD;
          END IF;

          FOREACH col IN ARRAY pk_cols LOOP
            pk := pk || jsonb_build_object(col, row -> col);
          END LOOP;

          INSERT INTO public.$_tombstonesTable (table_name, pk, pk_hash, deleted_at)
          VALUES (TG_TABLE_NAME, pk, md5(pk::text), CURRENT_TIMESTAMP)
          ON CONFLICT (table_name, pk_hash) DO UPDATE
            SET deleted_at = GREATEST(public.$_tombstonesTable.deleted_at, EXCLUDED.deleted_at),
                pk = EXCLUDED.pk;

          RETURN OLD;
        END;
        \$\$ LANGUAGE plpgsql;
      ''');

      // Trigger'ları sadece base tablolara kur (partition child tablolarını dışarıda bırak).
      await conn.execute('''
        DO \$\$
        DECLARE
          r RECORD;
        BEGIN
          FOR r IN
            SELECT c.oid AS oid, c.relname AS name
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public'
              AND c.relkind IN ('r', 'p')
              AND c.relispartition = false
              AND c.relname NOT IN ('$_tombstonesTable', 'sync_outbox', '$_deltaOutboxTable')
          LOOP
            IF NOT EXISTS (
              SELECT 1
              FROM pg_trigger t
              WHERE t.tgname = '$_tombstoneTriggerName'
                AND t.tgrelid = r.oid
            ) THEN
              EXECUTE format(
                'CREATE TRIGGER %s AFTER DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.%s()',
                '$_tombstoneTriggerName',
                r.name,
                '$_tombstoneTriggerFn'
              );
            END IF;
          END LOOP;
        END
        \$\$;
      ''');

      _tombstoneInfraReadyByDbKey.add(dbKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DBAktarim: Tombstone infra ensure failed ($dbKey): $e');
      }
    }
  }

  Future<void> _ensureDeltaOutboxInfraBestEffort(
    Connection conn, {
    required String dbKey,
  }) async {
    if (_deltaOutboxInfraReadyByDbKey.contains(dbKey)) return;
    try {
      await conn.execute('''
        CREATE TABLE IF NOT EXISTS public.$_deltaOutboxTable (
          table_name TEXT NOT NULL,
          pk JSONB NOT NULL,
          pk_hash TEXT NOT NULL,
          action TEXT NOT NULL, -- 'upsert' | 'delete'
          touched_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
          acked_at TIMESTAMPTZ,
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          dead BOOLEAN NOT NULL DEFAULT false,
          PRIMARY KEY (table_name, pk_hash)
        )
      ''');
      await conn.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_delta_outbox_touched_at ON public.$_deltaOutboxTable (touched_at)',
      );
      await conn.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_delta_outbox_acked_at ON public.$_deltaOutboxTable (acked_at)',
      );

      await conn.execute('''
        CREATE OR REPLACE FUNCTION public.$_deltaOutboxTriggerFn()
        RETURNS trigger AS \$\$
        DECLARE
          pk_cols TEXT[];
          col TEXT;
          pk JSONB := '{}'::jsonb;
          row JSONB;
          v_action TEXT;
        BEGIN
          -- Senkron uygulanırken (remote -> local/cloud upsert/delete) outbox üretme.
          IF COALESCE(current_setting('$_syncApplyGuc', true), '') = '1' THEN
            IF TG_OP = 'DELETE' THEN
              RETURN OLD;
            END IF;
            RETURN NEW;
          END IF;

          IF TG_TABLE_SCHEMA <> 'public' THEN
            IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
            RETURN NEW;
          END IF;

          -- Dahili/derivatif tabloları asla delta outbox'a alma.
          IF TG_TABLE_NAME IN (
            '$_tombstonesTable',
            '$_deltaOutboxTable',
            'sync_outbox',
            'table_counts',
            'sequences',
            'account_metadata'
          ) THEN
            IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
            RETURN NEW;
          END IF;

          v_action := CASE WHEN TG_OP = 'DELETE' THEN 'delete' ELSE 'upsert' END;
          row := to_jsonb(CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END);

          SELECT array_agg(a.attname ORDER BY a.attnum)
          INTO pk_cols
          FROM pg_index i
          JOIN pg_attribute a
            ON a.attrelid = i.indrelid
           AND a.attnum = ANY(i.indkey)
          WHERE i.indrelid = TG_RELID
            AND i.indisprimary;

          IF pk_cols IS NULL OR array_length(pk_cols, 1) IS NULL THEN
            IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
            RETURN NEW;
          END IF;

          FOREACH col IN ARRAY pk_cols LOOP
            pk := pk || jsonb_build_object(col, row -> col);
          END LOOP;

          INSERT INTO public.$_deltaOutboxTable (
            table_name,
            pk,
            pk_hash,
            action,
            touched_at,
            acked_at,
            retry_count,
            last_error,
            dead
          )
          VALUES (
            TG_TABLE_NAME,
            pk,
            md5(pk::text),
            v_action,
            CURRENT_TIMESTAMP,
            NULL,
            0,
            NULL,
            false
          )
          ON CONFLICT (table_name, pk_hash) DO UPDATE
            SET pk = EXCLUDED.pk,
                action = EXCLUDED.action,
                touched_at = EXCLUDED.touched_at,
                acked_at = NULL,
                retry_count = 0,
                last_error = NULL,
                dead = false;

          IF TG_OP = 'DELETE' THEN
            RETURN OLD;
          END IF;
          RETURN NEW;
        END;
        \$\$ LANGUAGE plpgsql;
      ''');

      await conn.execute('''
        DO \$\$
        DECLARE
          r RECORD;
        BEGIN
          FOR r IN
            SELECT c.oid AS oid, c.relname AS name
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public'
              AND c.relkind IN ('r', 'p')
              AND c.relispartition = false
              AND c.relname NOT IN (
                '$_tombstonesTable',
                '$_deltaOutboxTable',
                'sync_outbox',
                'table_counts',
                'sequences',
                'account_metadata'
              )
          LOOP
            IF NOT EXISTS (
              SELECT 1
              FROM pg_trigger t
              WHERE t.tgname = '$_deltaOutboxTriggerName'
                AND t.tgrelid = r.oid
            ) THEN
              EXECUTE format(
                'CREATE TRIGGER %s AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.%s()',
                '$_deltaOutboxTriggerName',
                r.name,
                '$_deltaOutboxTriggerFn'
              );
            END IF;
          END LOOP;
        END
        \$\$;
      ''');

      _deltaOutboxInfraReadyByDbKey.add(dbKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DBAktarim: Delta outbox infra ensure failed ($dbKey): $e');
      }
    }
  }

  Future<void> _ensureDeltaTimestampInfraBestEffort(
    Connection conn, {
    required String dbKey,
  }) async {
    if (_timestampInfraReadyByDbKey.contains(dbKey)) return;
    try {
      await conn.execute('''
        CREATE OR REPLACE FUNCTION public.$_updatedAtTriggerFn()
        RETURNS trigger AS \$\$
        BEGIN
          -- Senkron uygulanırken (remote -> local/cloud upsert) updated_at'ı bozma.
          IF COALESCE(current_setting('$_syncApplyGuc', true), '') = '1' THEN
            RETURN NEW;
          END IF;
          NEW.updated_at = CURRENT_TIMESTAMP;
          RETURN NEW;
        END;
        \$\$ LANGUAGE plpgsql;
      ''');

      // Timestamp kolonları ve updated_at trigger'ı: best-effort kur.
      await conn.execute('''
        DO \$\$
        DECLARE
          r RECORD;
        BEGIN
          FOR r IN
            SELECT c.oid AS oid, c.relname AS name
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public'
              AND c.relkind IN ('r', 'p')
              AND c.relispartition = false
          LOOP
            BEGIN
              EXECUTE format(
                'ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS created_at TIMESTAMP',
                r.name
              );
            EXCEPTION WHEN others THEN
              -- ignore
            END;
            BEGIN
              EXECUTE format(
                'ALTER TABLE public.%I ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP',
                r.name
              );
            EXCEPTION WHEN others THEN
              -- ignore
            END;
            BEGIN
              EXECUTE format(
                'ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP',
                r.name
              );
            EXCEPTION WHEN others THEN
              -- ignore
            END;
            BEGIN
              EXECUTE format(
                'ALTER TABLE public.%I ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP',
                r.name
              );
            EXCEPTION WHEN others THEN
              -- ignore
            END;

            BEGIN
              IF NOT EXISTS (
                SELECT 1
                FROM pg_trigger t
                WHERE t.tgname = '$_updatedAtTriggerName'
                  AND t.tgrelid = r.oid
              ) THEN
                EXECUTE format(
                  'CREATE TRIGGER %s BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.%s()',
                  '$_updatedAtTriggerName',
                  r.name,
                  '$_updatedAtTriggerFn'
                );
              END IF;
            EXCEPTION WHEN others THEN
              -- ignore
            END;
          END LOOP;
        END
        \$\$;
      ''');

      _timestampInfraReadyByDbKey.add(dbKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DBAktarim: Timestamp infra ensure failed ($dbKey): $e');
      }
    }
  }

  Future<bool> _isDeltaOutboxOperational(
    Connection conn, {
    required String dbKey,
  }) async {
    if (_deltaOutboxInfraReadyByDbKey.contains(dbKey)) return true;

    await _ensureDeltaOutboxInfraBestEffort(conn, dbKey: dbKey);

    final exists = await _tableExistsCached(conn, _deltaOutboxTable);
    if (!exists) return false;

    try {
      final result = await conn.execute(
        Sql.named('''
          SELECT COUNT(*)::int
          FROM pg_trigger t
          JOIN pg_class c ON c.oid = t.tgrelid
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'public'
            AND t.tgname = @name
            AND NOT t.tgisinternal
        '''),
        parameters: {'name': _deltaOutboxTriggerName},
      );
      final raw = result.isNotEmpty ? result.first[0] : 0;
      final count = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
      final ok = count > 0;
      if (ok) _deltaOutboxInfraReadyByDbKey.add(dbKey);
      return ok;
    } catch (_) {
      // Trigger listesini okuyamazsak bile tablo varsa denemek daha güvenli.
      _deltaOutboxInfraReadyByDbKey.add(dbKey);
      return true;
    }
  }

  Future<List<_DeltaOutboxRow>> _readDeltaOutbox(
    Connection conn, {
    int limit = 2000,
  }) async {
    try {
      final result = await conn.execute(
        Sql.named('''
          SELECT table_name, pk, pk_hash, action, touched_at, retry_count, dead
          FROM public.$_deltaOutboxTable
          WHERE acked_at IS NULL AND dead = false
          ORDER BY retry_count ASC, touched_at ASC
          LIMIT @limit
        '''),
        parameters: {'limit': limit},
      );

      return result
          .map((r) {
            final table = (r[0] as String?)?.trim() ?? '';
            final pk = r[1];
            final hash = (r[2] as String?)?.trim() ?? '';
            final action = (r[3] as String?)?.trim().toLowerCase() ?? '';
            final touchedAt = r[4] is DateTime
                ? (r[4] as DateTime)
                : DateTime.tryParse(r[4]?.toString() ?? '');
            final retry =
                r[5] is num ? (r[5] as num).toInt() : int.tryParse('${r[5]}') ?? 0;
            final dead = r[6] == true;
            if (table.isEmpty ||
                pk == null ||
                hash.isEmpty ||
                (action != 'upsert' && action != 'delete') ||
                touchedAt == null) {
              return null;
            }
            return _DeltaOutboxRow(
              tableName: table,
              pk: pk,
              pkHash: hash,
              action: action,
              touchedAt: touchedAt,
              retryCount: retry,
              dead: dead,
            );
          })
          .whereType<_DeltaOutboxRow>()
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DBAktarim: Delta outbox read failed: $e');
      }
      return const <_DeltaOutboxRow>[];
    }
  }

  Future<void> _ackDeltaOutboxRow(
    Connection source, {
    required _DeltaOutboxRow row,
  }) async {
    try {
      await source.execute(
        Sql.named('''
          UPDATE public.$_deltaOutboxTable
          SET acked_at = CURRENT_TIMESTAMP
          WHERE table_name = @t
            AND pk_hash = @h
            AND touched_at = @ts
            AND acked_at IS NULL
        '''),
        parameters: {
          't': row.tableName,
          'h': row.pkHash,
          'ts': row.touchedAt,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DBAktarim: Delta outbox ack failed: $e');
      }
    }
  }

  Future<void> _markDeltaOutboxRowFailed(
    Connection source, {
    required _DeltaOutboxRow row,
    required String error,
    int maxRetry = 20,
  }) async {
    try {
      await source.execute(
        Sql.named('''
          UPDATE public.$_deltaOutboxTable
          SET retry_count = retry_count + 1,
              last_error = @e,
              dead = CASE WHEN retry_count + 1 >= @max THEN true ELSE dead END
          WHERE table_name = @t
            AND pk_hash = @h
            AND touched_at = @ts
            AND acked_at IS NULL
        '''),
        parameters: {
          't': row.tableName,
          'h': row.pkHash,
          'ts': row.touchedAt,
          'e': error,
          'max': maxRetry,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DBAktarim: Delta outbox fail mark failed: $e');
      }
    }
  }

  Future<List<_TombstoneRow>> _readTombstones(
    Connection conn, {
    required DateTime since,
    int limit = 2000,
    int afterId = 0,
  }) async {
    try {
      final result = await conn.execute(
        Sql.named('''
          SELECT id, table_name, pk, pk_hash, deleted_at
          FROM public.$_tombstonesTable
          WHERE deleted_at >= @since AND id > @after
          ORDER BY id ASC
          LIMIT @limit
        '''),
        parameters: {
          'since': since,
          'after': afterId,
          'limit': limit,
        },
      );

      return result
          .map((r) {
            final id = int.tryParse(r[0]?.toString() ?? '') ?? 0;
            final table = (r[1] as String?)?.trim() ?? '';
            final pk = r[2];
            final hash = (r[3] as String?)?.trim() ?? '';
            final deletedAt = r[4] is DateTime
                ? (r[4] as DateTime)
                : DateTime.tryParse(r[4]?.toString() ?? '') ?? DateTime.now();
            if (id <= 0 || table.isEmpty || hash.isEmpty || pk == null) {
              return null;
            }
            return _TombstoneRow(
              id: id,
              tableName: table,
              pk: pk,
              pkHash: hash,
              deletedAt: deletedAt,
            );
          })
          .whereType<_TombstoneRow>()
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DBAktarim: Tombstone read failed: $e');
      }
      return const <_TombstoneRow>[];
    }
  }

  Future<void> _upsertTombstones(
    Connection target, {
    required List<_TombstoneRow> rows,
  }) async {
    if (rows.isEmpty) return;

    const batchSize = 500;
    for (var i = 0; i < rows.length; i += batchSize) {
      final chunk = rows.sublist(i, (i + batchSize).clamp(0, rows.length));
      final params = <String, dynamic>{};
      final sb = StringBuffer();
      sb.write(
        'INSERT INTO public.$_tombstonesTable (table_name, pk, pk_hash, deleted_at) VALUES ',
      );

      for (var j = 0; j < chunk.length; j++) {
        final t = chunk[j];
        final tn = 't_$j';
        final pk = 'pk_$j';
        final h = 'h_$j';
        final d = 'd_$j';
        params[tn] = t.tableName;
        params[pk] = TypedValue(Type.jsonb, _coerceJsonEncodable(t.pk));
        params[h] = t.pkHash;
        params[d] = t.deletedAt;
        sb.write('(@$tn, @$pk, @$h, @$d)');
        if (j < chunk.length - 1) sb.write(', ');
      }

      sb.write(
        ' ON CONFLICT (table_name, pk_hash) DO UPDATE '
        'SET deleted_at = GREATEST(public.$_tombstonesTable.deleted_at, EXCLUDED.deleted_at), '
        'pk = EXCLUDED.pk',
      );

      await target.execute(Sql.named(sb.toString()), parameters: params);
    }
  }

  Future<void> _syncTombstonesLocalToCloud({
    required Connection localSettings,
    required Connection localCompany,
    required Connection cloud,
    required DateTime since,
  }) async {
    final collected = <_TombstoneRow>[];

    Future<void> collectFrom(Connection src) async {
      var afterId = 0;
      while (true) {
        final batch = await _readTombstones(
          src,
          since: since,
          afterId: afterId,
        );
        if (batch.isEmpty) break;
        collected.addAll(batch);
        afterId = batch.last.id;
        if (batch.length < 2000) break;
      }
    }

    await collectFrom(localSettings);
    await collectFrom(localCompany);
    if (collected.isEmpty) return;

    await _upsertTombstones(cloud, rows: collected);
    await _applyTombstonesToTarget(cloud, tombstones: collected);
  }

  Future<void> _syncTombstonesCloudToLocal({
    required Connection cloud,
    required Connection localSettings,
    required Connection localCompany,
    required Set<String> settingsTables,
    required Set<String> companyTables,
    required DateTime since,
  }) async {
    final collected = <_TombstoneRow>[];
    var afterId = 0;
    while (true) {
      final batch = await _readTombstones(
        cloud,
        since: since,
        afterId: afterId,
      );
      if (batch.isEmpty) break;
      collected.addAll(batch);
      afterId = batch.last.id;
      if (batch.length < 2000) break;
    }
    if (collected.isEmpty) return;

    final settingsList = <_TombstoneRow>[
      for (final t in collected)
        if (settingsTables.contains(t.tableName)) t,
    ];
    final companyList = <_TombstoneRow>[
      for (final t in collected)
        if (companyTables.contains(t.tableName)) t,
    ];

    if (settingsList.isNotEmpty) {
      await _applyTombstonesToTarget(localSettings, tombstones: settingsList);
    }
    if (companyList.isNotEmpty) {
      await _applyTombstonesToTarget(localCompany, tombstones: companyList);
    }
  }

  Future<void> _applyTombstonesToTarget(
    Connection target, {
    required List<_TombstoneRow> tombstones,
  }) async {
    if (tombstones.isEmpty) return;

    final tables = tombstones.map((t) => t.tableName).toSet();
    final ordered = await _topologicalInsertOrder(target, tables.toList());
    final deleteOrder = ordered.reversed.toList();

    final byTable = <String, List<_TombstoneRow>>{};
    for (final t in tombstones) {
      (byTable[t.tableName] ??= <_TombstoneRow>[]).add(t);
    }

    await _withTransaction(target, () async {
      await _bestEffortInTransaction(
        target,
        "SET LOCAL $_syncApplyGuc = '1'",
        debugContext: 'tombstone-apply',
      );

      for (final table in deleteOrder) {
        final list = byTable[table];
        if (list == null || list.isEmpty) continue;
        for (final ts in list) {
          final pkMap = _asJsonObject(ts.pk);
          if (pkMap == null || pkMap.isEmpty) continue;

          final keys = pkMap.keys.toList()..sort();
          final params = <String, dynamic>{
            for (final k in keys) _paramKey(table, k): pkMap[k],
          };
          final where = keys.map((k) => '${_qi(k)} = @${_paramKey(table, k)}').join(' AND ');

          await _bestEffortStatementInTransaction(
            target,
            Sql.named('DELETE FROM ${_qt(table)} WHERE $where'),
            parameters: params,
            debugContext: 'tombstone-delete:$table',
          );
        }
      }
    });
  }

  Future<_DeltaOutboxApplyResult> _applyDeltaOutboxItemsToTarget(
    Connection target, {
    required List<_DeltaOutboxItem> items,
    required String? companyIdOverride,
  }) async {
    if (items.isEmpty) {
      return const _DeltaOutboxApplyResult(
        applied: 0,
        tablesTouched: <String>{},
        succeeded: <_DeltaOutboxItem>[],
        failed: <_DeltaOutboxItemFailure>[],
      );
    }

    final byTable = <String, List<_DeltaOutboxItem>>{};
    for (final it in items) {
      final t = it.row.tableName.trim();
      if (t.isEmpty) continue;
      if (_transferExcludedTables.contains(t.toLowerCase())) continue;
      if (t.toLowerCase() == _tombstonesTable) continue;
      (byTable[t] ??= <_DeltaOutboxItem>[]).add(it);
    }

    final tables = byTable.keys.toList();
    if (tables.isEmpty) {
      return const _DeltaOutboxApplyResult(
        applied: 0,
        tablesTouched: <String>{},
        succeeded: <_DeltaOutboxItem>[],
        failed: <_DeltaOutboxItemFailure>[],
      );
    }

    final ordered = await _topologicalInsertOrder(target, tables);
    final deleteOrder = ordered.reversed.toList();

    final targetColsCache = <String, List<String>>{};
    final conflictColsCache = <String, List<String>>{};
    final sourceColsCache = <String, List<String>>{};

    Future<List<String>> colsCached(
      Connection conn,
      Map<String, List<String>> cache,
      String key,
      String table,
    ) async {
      final cached = cache[key];
      if (cached != null) return cached;
      final cols = await _columns(conn, table);
      cache[key] = cols;
      return cols;
    }

    Future<List<String>> targetCols(String table) async =>
        targetColsCache[table] ??= await _columns(target, table);

    Future<List<String>> conflictCols(String table) async =>
        conflictColsCache[table] ??= await _primaryKeyColumns(target, table);

    final succeeded = <_DeltaOutboxItem>[];
    final failed = <_DeltaOutboxItemFailure>[];
    final touched = <String>{};

    await _withTransaction(target, () async {
      await _bestEffortInTransaction(
        target,
        "SET LOCAL $_syncApplyGuc = '1'",
        debugContext: 'delta-outbox-apply',
      );

      // Upserts (parent -> child)
      for (final table in ordered) {
        final list = byTable[table];
        if (list == null || list.isEmpty) continue;

        final tCols = await targetCols(table);
        if (tCols.isEmpty) continue;

        final pkCols = await conflictCols(table);
        if (pkCols.isEmpty) continue;

        for (final it in list) {
          if (it.row.action != 'upsert') continue;

          final pkMap = _asJsonObject(it.row.pk);
          if (pkMap == null || pkMap.isEmpty) {
            failed.add(
              _DeltaOutboxItemFailure(item: it, error: 'pk_parse_failed'),
            );
            continue;
          }

          final srcKey = '${it.sourceLabel}::$table';
          final sCols = await colsCached(
            it.source,
            sourceColsCache,
            srcKey,
            table,
          );
          if (sCols.isEmpty) {
            failed.add(
              _DeltaOutboxItemFailure(item: it, error: 'source_table_missing'),
            );
            continue;
          }

          final cols = <String>[
            for (final c in tCols)
              if (sCols.contains(c)) c,
          ];
          final allPkPresent = pkCols.every(cols.contains);
          if (cols.isEmpty || !allPkPresent) {
            failed.add(
              _DeltaOutboxItemFailure(item: it, error: 'schema_mismatch'),
            );
            continue;
          }

          final ok = await _tryWorkInTransaction(
            target,
            () async {
              final keys = pkMap.keys.toList()..sort();
              final params = <String, dynamic>{
                for (final k in keys) _paramKey(table, k): pkMap[k],
              };
              final where =
                  keys.map((k) => '${_qi(k)} = @${_paramKey(table, k)}').join(' AND ');

              final sel = await it.source.execute(
                Sql.named(
                  'SELECT ${cols.map(_qi).join(', ')} FROM ${_qt(table)} WHERE $where LIMIT 1',
                ),
                parameters: params,
              );

              if (sel.isEmpty) {
                // Kaynakta yoksa: hedefte sil (best-effort).
                await target.execute(
                  Sql.named('DELETE FROM ${_qt(table)} WHERE $where'),
                  parameters: params,
                );
                return;
              }

              final rowValues = List<dynamic>.from(sel.first);
              final companyIdIndex =
                  companyIdOverride == null ? -1 : cols.indexOf('company_id');
              if (companyIdIndex >= 0 && companyIdIndex < rowValues.length) {
                rowValues[companyIdIndex] = companyIdOverride;
              }

              await _insertBatch(
                target: target,
                table: table,
                columns: cols,
                conflictColumns: pkCols,
                rows: <List<dynamic>>[rowValues],
                upsert: true,
              );
            },
            debugContext: 'delta-outbox-upsert:$table',
          );

          if (ok) {
            succeeded.add(it);
            touched.add(table);
          } else {
            failed.add(_DeltaOutboxItemFailure(item: it, error: 'apply_failed'));
          }
        }
      }

      // Deletes (child -> parent)
      for (final table in deleteOrder) {
        final list = byTable[table];
        if (list == null || list.isEmpty) continue;

        for (final it in list) {
          if (it.row.action != 'delete') continue;
          final pkMap = _asJsonObject(it.row.pk);
          if (pkMap == null || pkMap.isEmpty) {
            failed.add(
              _DeltaOutboxItemFailure(item: it, error: 'pk_parse_failed'),
            );
            continue;
          }

          final keys = pkMap.keys.toList()..sort();
          final params = <String, dynamic>{
            for (final k in keys) _paramKey(table, k): pkMap[k],
          };
          final where =
              keys.map((k) => '${_qi(k)} = @${_paramKey(table, k)}').join(' AND ');

          final ok = await _tryStatementInTransaction(
            target,
            Sql.named('DELETE FROM ${_qt(table)} WHERE $where'),
            parameters: params,
            debugContext: 'delta-outbox-delete:$table',
          );

          if (ok) {
            succeeded.add(it);
            touched.add(table);
          } else {
            failed.add(_DeltaOutboxItemFailure(item: it, error: 'apply_failed'));
          }
        }
      }
    });

    return _DeltaOutboxApplyResult(
      applied: succeeded.length,
      tablesTouched: touched,
      succeeded: succeeded,
      failed: failed,
    );
  }

  static String _paramKey(String table, String column) {
    String normalize(String v) =>
        v.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').toLowerCase();
    final t = normalize(table);
    final c = normalize(column);
    final key = 'p_${t}_$c';
    if (key.length <= 60) return key;
    return 'p_${t.hashCode.abs()}_${c.hashCode.abs()}';
  }

  Map<String, dynamic>? _asJsonObject(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return value.map((k, v) => MapEntry(k.toString(), v));
      } catch (_) {
        return null;
      }
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('{')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) {
            return decoded.map((k, v) => MapEntry(k.toString(), v));
          }
        } catch (_) {}
      }
    }
    return null;
  }

  Future<void> _bestEffortStatementInTransaction(
    Connection conn,
    Sql statement, {
    required Map<String, dynamic> parameters,
    required String debugContext,
  }) async {
    final sp = _nextSavepointName();
    try {
      await conn.execute('SAVEPOINT $sp');
      try {
        await conn.execute(statement, parameters: parameters);
      } catch (e) {
        try {
          await conn.execute('ROLLBACK TO SAVEPOINT $sp');
        } catch (rollbackErr) {
          if (kDebugMode) {
            debugPrint(
              'Best-effort tx rollback failed ($debugContext): $rollbackErr',
            );
          }
        }
        if (kDebugMode) {
          debugPrint('Best-effort tx statement failed ($debugContext): $e');
        }
      } finally {
        try {
          await conn.execute('RELEASE SAVEPOINT $sp');
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Best-effort tx wrapper failed ($debugContext): $e');
      }
    }
  }

  Future<bool> _tryStatementInTransaction(
    Connection conn,
    Sql statement, {
    required Map<String, dynamic> parameters,
    required String debugContext,
  }) async {
    final sp = _nextSavepointName();
    try {
      await conn.execute('SAVEPOINT $sp');
      try {
        await conn.execute(statement, parameters: parameters);
        return true;
      } catch (e) {
        try {
          await conn.execute('ROLLBACK TO SAVEPOINT $sp');
        } catch (rollbackErr) {
          if (kDebugMode) {
            debugPrint(
              'Best-effort tx rollback failed ($debugContext): $rollbackErr',
            );
          }
        }
        if (kDebugMode) {
          debugPrint('Best-effort tx statement failed ($debugContext): $e');
        }
        return false;
      } finally {
        try {
          await conn.execute('RELEASE SAVEPOINT $sp');
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Best-effort tx wrapper failed ($debugContext): $e');
      }
      return false;
    }
  }

  Future<bool> _tryWorkInTransaction(
    Connection conn,
    Future<void> Function() work, {
    required String debugContext,
  }) async {
    final sp = _nextSavepointName();
    try {
      await conn.execute('SAVEPOINT $sp');
      try {
        await work();
        return true;
      } catch (e) {
        try {
          await conn.execute('ROLLBACK TO SAVEPOINT $sp');
        } catch (rollbackErr) {
          if (kDebugMode) {
            debugPrint(
              'Best-effort tx rollback failed ($debugContext): $rollbackErr',
            );
          }
        }
        if (kDebugMode) {
          debugPrint('Best-effort tx work failed ($debugContext): $e');
        }
        return false;
      } finally {
        try {
          await conn.execute('RELEASE SAVEPOINT $sp');
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Best-effort tx work wrapper failed ($debugContext): $e');
      }
      return false;
    }
  }

  Future<void> _setSyncApplyFlagBestEffort(
    Connection conn, {
    required bool enabled,
    required String debugContext,
  }) async {
    final v = enabled ? '1' : '0';
    try {
      await conn.execute("SET $_syncApplyGuc = '$v'");
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DBAktarim: SET $_syncApplyGuc failed ($debugContext): $e');
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Connection + readiness
  // ──────────────────────────────────────────────────────────────────────────

  static const String _localLegacyPassword = '5828486';

  String _localSettingsDatabaseName() {
    if (kIsWeb) return 'patisyosettings';
    final fromEnv = Platform.environment['PATISYO_DB_NAME'];
    if (fromEnv != null && fromEnv.trim().isNotEmpty) return fromEnv.trim();
    return 'patisyosettings';
  }

  _DbConn _buildLocalConnection({
    required String host,
    required String database,
  }) {
    final envPort = Platform.environment['PATISYO_DB_PORT'];
    final port = int.tryParse(envPort ?? '') ?? 5432;
    final user = Platform.environment['PATISYO_DB_USER'] ?? 'patisyo';
    final passEnv = Platform.environment['PATISYO_DB_PASSWORD'];
    final pass = (passEnv != null && passEnv.trim().isNotEmpty)
        ? passEnv.trim()
        : _localLegacyPassword;

    return _DbConn(
      host: host.trim(),
      port: port,
      database: database.trim(),
      username: user.trim(),
      password: pass,
      sslMode: SslMode.disable,
      isCloud: false,
    );
  }

  _DbConn? _buildCloudConnection() {
    final host = VeritabaniYapilandirma.cloudHost;
    final user = VeritabaniYapilandirma.cloudUsername;
    final pass = VeritabaniYapilandirma.cloudPassword;
    final db = VeritabaniYapilandirma.cloudDatabase;
    if (host == null ||
        user == null ||
        pass == null ||
        db == null ||
        host.trim().isEmpty ||
        user.trim().isEmpty ||
        db.trim().isEmpty) {
      return null;
    }

    final port = VeritabaniYapilandirma.cloudPort ?? 5432;
    final sslRequired = VeritabaniYapilandirma.cloudSslRequired ?? true;

    return _DbConn(
      host: host.trim(),
      port: port,
      database: db.trim(),
      username: user.trim(),
      password: pass,
      sslMode: sslRequired ? SslMode.require : SslMode.disable,
      isCloud: true,
    );
  }

  Future<Connection> _open(_DbConn info) async {
    final cfg = VeritabaniYapilandirma();
    final conn = await Connection.open(
      Endpoint(
        host: info.host,
        port: info.port,
        database: info.database,
        username: info.username,
        password: info.password,
      ),
      settings: ConnectionSettings(
        sslMode: info.sslMode,
        connectTimeout: info.isCloud
            ? const Duration(seconds: 20)
            : const Duration(seconds: 6),
        onOpen: (c) async {
          // Var olan tuneConnection sadece "current mode cloud" iken çalışıyor olabilir.
          // Burada bağlantı tipine göre güvenli ayar uygula.
          try {
            if (info.isCloud) {
              await c.execute('SET statement_timeout TO 0');
            } else {
              await cfg.tuneConnection(c);
            }
          } catch (_) {}
        },
      ),
    );
    return conn;
  }

  Future<void> _safeClose(Connection? conn) async {
    try {
      await conn?.close();
    } catch (_) {}
  }

  Future<String?> _tryResolveDefaultLocalCompanyDb(
    _DbConn localSettings,
  ) async {
    Connection? conn;
    try {
      conn = await _open(localSettings);
      // company_settings içinden varsayılan şirket kodunu çek
      final result = await conn.execute(
        "SELECT kod FROM company_settings WHERE varsayilan_mi = 1 ORDER BY id ASC LIMIT 1",
      );
      String? code;
      if (result.isNotEmpty) {
        code = (result.first[0] as String?)?.trim();
      }
      if (code == null || code.isEmpty) {
        final r2 = await conn.execute(
          'SELECT kod FROM company_settings ORDER BY id ASC LIMIT 1',
        );
        if (r2.isNotEmpty) {
          code = (r2.first[0] as String?)?.trim();
        }
      }
      if (code == null || code.isEmpty) return null;
      return _localCompanyDbNameFromCode(code);
    } catch (_) {
      return null;
    } finally {
      await _safeClose(conn);
    }
  }

  static String _localCompanyDbNameFromCode(String code) {
    final c = code.trim();
    if (c == 'patisyo2025') return 'patisyo2025';
    final safe = c.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    if (safe.isEmpty) return 'patisyo2025';
    return 'patisyo_$safe';
  }

  Future<bool> _quickReadinessCheck({
    required String fromMode,
    required String toMode,
    required _DbConn localSettings,
    required _DbConn localCompany,
    required _DbConn cloud,
  }) async {
    Connection? a;
    Connection? b;
    Connection? c;

    Future<bool> checkHas(Connection conn, String table) async {
      final res = await conn.execute(
        Sql.named("SELECT to_regclass('public.' || @t) IS NOT NULL"),
        parameters: {'t': table},
      );
      return res.isNotEmpty && res.first[0] == true;
    }

    try {
      if (fromMode == 'local' || toMode == 'local') {
        a = await _open(localSettings);
        b = await _open(localCompany);
        await a.execute('SELECT 1');
        await b.execute('SELECT 1');

        // Yerel settings kritik tablolar
        final usersOk = await checkHas(a, 'users');
        final companyOk = await checkHas(a, 'company_settings');
        if (!usersOk || !companyOk) return false;

        // Yerel company kritik tablolar (en azından ürün/depots)
        final productsOk = await checkHas(b, 'products');
        final depotsOk = await checkHas(b, 'depots');
        if (!productsOk || !depotsOk) return false;
      }

      if (fromMode == 'cloud' || toMode == 'cloud') {
        c = await _open(cloud);
        await c.execute('SELECT 1');
        final usersOk = await checkHas(c, 'users');
        final productsOk = await checkHas(c, 'products');
        if (!usersOk || !productsOk) return false;
      }

      return true;
    } on SocketException {
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Aktarım readiness error: $e');
      return false;
    } finally {
      await _safeClose(a);
      await _safeClose(b);
      await _safeClose(c);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SQL quoting helpers
  // ──────────────────────────────────────────────────────────────────────────

  static String _qi(String ident) => '"${ident.replaceAll('"', '""')}"';
  static String _qt(String table) => 'public.${_qi(table)}';
  static String _qs(String seq) => "'public.${seq.replaceAll("'", "''")}'";
}

class VeritabaniDeltaSenkronRapor {
  final int tabloSayisi;
  final int satirSayisi;
  final List<String> tablolar;
  final Duration elapsed;

  const VeritabaniDeltaSenkronRapor({
    required this.tabloSayisi,
    required this.satirSayisi,
    required this.tablolar,
    required this.elapsed,
  });
}

class _TombstoneRow {
  final int id;
  final String tableName;
  final dynamic pk;
  final String pkHash;
  final DateTime deletedAt;

  const _TombstoneRow({
    required this.id,
    required this.tableName,
    required this.pk,
    required this.pkHash,
    required this.deletedAt,
  });
}

class _DeltaOutboxRow {
  final String tableName;
  final dynamic pk;
  final String pkHash;
  final String action; // 'upsert' | 'delete'
  final DateTime touchedAt;
  final int retryCount;
  final bool dead;

  const _DeltaOutboxRow({
    required this.tableName,
    required this.pk,
    required this.pkHash,
    required this.action,
    required this.touchedAt,
    required this.retryCount,
    required this.dead,
  });
}

class _DeltaOutboxItem {
  final Connection source;
  final String sourceLabel;
  final _DeltaOutboxRow row;

  const _DeltaOutboxItem({
    required this.source,
    required this.sourceLabel,
    required this.row,
  });
}

class _DeltaOutboxItemFailure {
  final _DeltaOutboxItem item;
  final String error;

  const _DeltaOutboxItemFailure({required this.item, required this.error});
}

class _DeltaOutboxApplyResult {
  final int applied;
  final Set<String> tablesTouched;
  final List<_DeltaOutboxItem> succeeded;
  final List<_DeltaOutboxItemFailure> failed;

  const _DeltaOutboxApplyResult({
    required this.applied,
    required this.tablesTouched,
    required this.succeeded,
    required this.failed,
  });
}

class _DeltaWhere {
  final String sql;
  final Map<String, dynamic> params;

  const _DeltaWhere({required this.sql, required this.params});
}

class _ColumnMeta {
  final String name;
  final String? defaultExpr;

  const _ColumnMeta({required this.name, required this.defaultExpr});
}

class _DbConn {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final SslMode sslMode;
  final bool isCloud;

  const _DbConn({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    required this.sslMode,
    required this.isCloud,
  });
}

class _DbSource {
  final Connection conn;
  final String label;
  const _DbSource(this.conn, this.label);
}

class _FkEdge {
  final String child;
  final String parent;
  const _FkEdge({required this.child, required this.parent});
}

class _MergeSnapshots {
  final String? bankOpeningsTable;
  final String? cashOpeningsTable;
  final String? creditOpeningsTable;

  const _MergeSnapshots({
    required this.bankOpeningsTable,
    required this.cashOpeningsTable,
    required this.creditOpeningsTable,
  });
}

class VeritabaniAktarimHazirlik {
  final String fromMode;
  final String toMode;
  final _DbConn _localSettings;
  final _DbConn _localCompany;
  final _DbConn _cloud;

  const VeritabaniAktarimHazirlik._({
    required this.fromMode,
    required this.toMode,
    required _DbConn localSettings,
    required _DbConn localCompany,
    required _DbConn cloud,
  }) : _localSettings = localSettings,
       _localCompany = localCompany,
       _cloud = cloud;
}
