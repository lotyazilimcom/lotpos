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

  final Map<String, Map<String, String>> _targetColumnUdtNameCacheByTable =
      <String, Map<String, String>>{};

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
          (tip == VeritabaniAktarimTipi.tamAktar ? 1 : 0);
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
          );
          doneSteps++;
          emit(table);
        }

        emit('sequences');
        await _fixSequences(tCloudConn, tables);
        doneSteps++;
        emit('sequences');
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
          (companyList.isNotEmpty ? 1 : 0);
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
          );
          doneSteps++;
          emit('company.$table');
        }

        if (settingsList.isNotEmpty) {
          emit('settings.sequences');
          await _fixSequences(tSettingsConn, settingsList);
          doneSteps++;
          emit('settings.sequences');
        }
        if (companyList.isNotEmpty) {
          emit('company.sequences');
          await _fixSequences(tCompanyConn, companyList);
          doneSteps++;
          emit('company.sequences');
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

  Future<void> _copyTableFromMultipleSources({
    required List<_DbSource> sources,
    required Connection target,
    required String table,
    required VeritabaniAktarimTipi tip,
  }) async {
    // Target şemaya göre conflict kolonlarını al (PK)
    final conflictCols = await _primaryKeyColumns(target, table);
    final targetCols = await _columns(target, table);
    if (targetCols.isEmpty) return;

    for (final src in sources) {
      final srcCols = await _columns(src.conn, table);
      if (srcCols.isEmpty) continue;

      final cols = <String>[
        for (final c in targetCols)
          if (srcCols.contains(c)) c,
      ];
      if (cols.isEmpty) continue;

      await _copyTableData(
        source: src.conn,
        sourceLabel: src.label,
        target: target,
        table: table,
        columns: cols,
        conflictColumns: conflictCols,
        // Tam aktarımda hedef tablo zaten temiz; yine de kaynaklar arası çakışmada update faydalı.
        upsert: tip == VeritabaniAktarimTipi.birlestir || sources.length > 1,
      );
    }
  }

  Future<void> _copyTableData({
    required Connection source,
    required String sourceLabel,
    required Connection target,
    required String table,
    required List<String> columns,
    required List<String> conflictColumns,
    required bool upsert,
  }) async {
    // Cursor ile batch oku, batch insert.
    final sw = Stopwatch()..start();
    var totalRows = 0;
    final cursorName = 'cur_${DateTime.now().microsecondsSinceEpoch}';
    // Parametre limiti (65535) ve SQL boyutu için güvenli batch boyutu.
    final batchSize = _safeBatchSize(columns.length);
    final selectSql =
        'SELECT ${columns.map(_qi).join(', ')} FROM ${_qt(table)}';

    _log(
      'Copy start: $sourceLabel -> target, table=$table, cols=${columns.length}, batchSize=$batchSize',
    );

    await source.execute('BEGIN');
    try {
      await source.execute(
        'DECLARE $cursorName NO SCROLL CURSOR FOR $selectSql',
      );

      while (true) {
        final batch = await source.execute(
          'FETCH FORWARD $batchSize FROM $cursorName',
        );
        if (batch.isEmpty) break;
        totalRows += batch.length;

        final rows = <List<dynamic>>[];
        for (final r in batch) {
          rows.add(List<dynamic>.from(r));
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
      'INSERT INTO ${_qt(table)} (${columns.map(_qi).join(', ')}) '
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
          sb.write('DO UPDATE SET ');
          sb.write(
            updateCols.map((c) => '${_qi(c)} = EXCLUDED.${_qi(c)}').join(', '),
          );
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

  Future<void> _fixSequences(Connection conn, List<String> tables) async {
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
        await conn.execute(
          'SELECT setval(${_qs(seq)}, (SELECT COALESCE(MAX(${_qi(col)}), 0) FROM ${_qt(table)}) + 1, false)',
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Sequence fix warning ($seq on $table.$col): $e');
        }
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
