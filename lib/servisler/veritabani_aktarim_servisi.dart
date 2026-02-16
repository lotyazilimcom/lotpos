import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'veritabani_yapilandirma.dart';

enum VeritabaniAktarimTipi { tamAktar, birlestir }

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
        localCompanyDb:
            (localCompanyDb == null || localCompanyDb.isEmpty)
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
        (from == 'local' && to == 'cloud') || (from == 'cloud' && to == 'local');
    if (!isLocalCloudSwitch) return null;

    // Cloud kimlikleri yoksa hazır değil.
    if ((from == 'cloud' || to == 'cloud') && !VeritabaniYapilandirma.cloudCredentialsReady) {
      return null;
    }

    final localHost = (niyet.localHost ?? VeritabaniYapilandirma.discoveredHost ?? '').trim();
    if ((from == 'local' || to == 'local') && localHost.isEmpty) return null;

    final localSettings = _buildLocalConnection(
      host: localHost,
      database: _localSettingsDatabaseName(),
    );

    final cloud = _buildCloudConnection();
    if (cloud == null) return null;

    String localCompanyDb = (niyet.localCompanyDb ?? '').trim();
    if (localCompanyDb.isEmpty) {
      localCompanyDb = await _tryResolveDefaultLocalCompanyDb(localSettings) ??
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
  }) async {
    if (hazirlik.fromMode == 'local' && hazirlik.toMode == 'cloud') {
      await _localToCloud(
        localSettings: hazirlik._localSettings,
        localCompany: hazirlik._localCompany,
        cloud: hazirlik._cloud,
        tip: tip,
      );
      return;
    }
    if (hazirlik.fromMode == 'cloud' && hazirlik.toMode == 'local') {
      await _cloudToLocal(
        cloud: hazirlik._cloud,
        localSettings: hazirlik._localSettings,
        localCompany: hazirlik._localCompany,
        tip: tip,
      );
      return;
    }

    throw StateError('Aktarım yönü desteklenmiyor: ${hazirlik.fromMode} -> ${hazirlik.toMode}');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Direction implementations
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _localToCloud({
    required _DbConn localSettings,
    required _DbConn localCompany,
    required _DbConn cloud,
    required VeritabaniAktarimTipi tip,
  }) async {
    Connection? sSettings;
    Connection? sCompany;
    Connection? tCloud;

    try {
      sSettings = await _open(localSettings);
      sCompany = await _open(localCompany);
      tCloud = await _open(cloud);

      final targetTables = await _listTables(tCloud);
      final settingsTables = await _listTables(sSettings);
      final companyTables = await _listTables(sCompany);

      final Set<String> tableSet = <String>{};
      for (final t in targetTables) {
        if (settingsTables.contains(t) || companyTables.contains(t)) {
          tableSet.add(t);
        }
      }
      final tables = tableSet.toList()..sort();
      if (tables.isEmpty) return;

      final insertOrder = await _topologicalInsertOrder(tCloud, tables);

      if (tip == VeritabaniAktarimTipi.tamAktar) {
        await _truncateTables(tCloud, tables);
      }

      for (final table in insertOrder) {
        final List<_DbSource> sources = <_DbSource>[];
        // Önce settings, sonra company (çakışmada company kazansın).
        if (settingsTables.contains(table)) sources.add(_DbSource(sSettings, 'settings'));
        if (companyTables.contains(table)) sources.add(_DbSource(sCompany, 'company'));
        if (sources.isEmpty) continue;

        await _copyTableFromMultipleSources(
          sources: sources,
          target: tCloud,
          table: table,
          tip: tip,
        );
      }

      await _fixSequences(tCloud, tables);
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
  }) async {
    Connection? sCloud;
    Connection? tSettings;
    Connection? tCompany;

    try {
      sCloud = await _open(cloud);
      tSettings = await _open(localSettings);
      tCompany = await _open(localCompany);

      final sourceTables = await _listTables(sCloud);
      final settingsTables = await _listTables(tSettings);
      final companyTables = await _listTables(tCompany);

      final Set<String> settingsCopy = <String>{};
      final Set<String> companyCopy = <String>{};

      for (final t in sourceTables) {
        if (settingsTables.contains(t)) settingsCopy.add(t);
        if (companyTables.contains(t)) companyCopy.add(t);
      }

      final settingsList = settingsCopy.toList()..sort();
      final companyList = companyCopy.toList()..sort();

      final settingsOrder = settingsList.isEmpty
          ? const <String>[]
          : await _topologicalInsertOrder(tSettings, settingsList);
      final companyOrder = companyList.isEmpty
          ? const <String>[]
          : await _topologicalInsertOrder(tCompany, companyList);

      if (tip == VeritabaniAktarimTipi.tamAktar) {
        if (settingsList.isNotEmpty) await _truncateTables(tSettings, settingsList);
        if (companyList.isNotEmpty) await _truncateTables(tCompany, companyList);
      }

      for (final table in settingsOrder) {
        await _copyTableFromMultipleSources(
          sources: <_DbSource>[_DbSource(sCloud, 'cloud')],
          target: tSettings,
          table: table,
          tip: tip,
        );
      }
      for (final table in companyOrder) {
        await _copyTableFromMultipleSources(
          sources: <_DbSource>[_DbSource(sCloud, 'cloud')],
          target: tCompany,
          table: table,
          tip: tip,
        );
      }

      if (settingsList.isNotEmpty) await _fixSequences(tSettings, settingsList);
      if (companyList.isNotEmpty) await _fixSequences(tCompany, companyList);
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
    required Connection target,
    required String table,
    required List<String> columns,
    required List<String> conflictColumns,
    required bool upsert,
  }) async {
    // Cursor ile batch oku, batch insert.
    final cursorName = 'cur_${DateTime.now().microsecondsSinceEpoch}';
    final selectSql =
        'SELECT ${columns.map(_qi).join(', ')} FROM ${_qt(table)}';

    await source.execute('BEGIN');
    try {
      await source.execute('DECLARE $cursorName NO SCROLL CURSOR FOR $selectSql');

      while (true) {
        final batch = await source.execute('FETCH FORWARD 200 FROM $cursorName');
        if (batch.isEmpty) break;

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
    } catch (e) {
      try {
        await source.execute('ROLLBACK');
      } catch (_) {}
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

    final params = <String, dynamic>{};
    final sb = StringBuffer();
    sb.write('INSERT INTO ${_qt(table)} (${columns.map(_qi).join(', ')}) VALUES ');

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      sb.write('(');
      for (var j = 0; j < columns.length; j++) {
        final key = 'v_${i}_$j';
        params[key] = j < row.length ? row[j] : null;
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
            updateCols
                .map((c) => '${_qi(c)} = EXCLUDED.${_qi(c)}')
                .join(', '),
          );
        }
      }
    } else {
      // PK yoksa: duplicate riskine karşı en güvenli davranış
      sb.write(' ON CONFLICT DO NOTHING');
    }

    await target.execute(Sql.named(sb.toString()), parameters: params);
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

    return result.map((r) => (r[0] as String).trim()).where((t) => t.isNotEmpty).toList();
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

  Future<List<String>> _primaryKeyColumns(Connection conn, String table) async {
    try {
      final result = await conn.execute(Sql.named('''
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
      '''), parameters: {'t': table});

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
    await conn.execute('TRUNCATE TABLE $list RESTART IDENTITY CASCADE');
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
        connectTimeout: const Duration(seconds: 4),
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

  Future<String?> _tryResolveDefaultLocalCompanyDb(_DbConn localSettings) async {
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

  static String _qi(String ident) =>
      '"${ident.replaceAll('"', '""')}"';
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
