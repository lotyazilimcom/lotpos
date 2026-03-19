import 'dart:io';

import 'package:postgres/postgres.dart';

import 'sirket_veritabani_kimligi.dart';

/// VERİTABANI SIFIRLAMA SERVİSİ (CLI + integration_test uyumlu)
///
/// Kullanım:
/// - Tam ilk kurulum sıfırlaması:
///   `dart lib/servisler/veritabani_reset_servisi.dart`
/// - Sadece şirket verilerini temizleme (eski davranış):
///   `LOSPOS_RESET_MODE=truncate dart lib/servisler/veritabani_reset_servisi.dart`
class VeritabaniResetServisi {
  final String _host = Platform.environment['LOSPOS_DB_HOST'] ?? 'localhost';
  final int _port =
      int.tryParse(Platform.environment['LOSPOS_DB_PORT'] ?? '5432') ?? 5432;
  final String _preferredUsername =
      Platform.environment['LOSPOS_DB_USER'] ?? 'lospos';
  final String _mainDbName =
      (Platform.environment['LOSPOS_SETTINGS_DB_NAME'] ?? 'lospossettings')
          .trim();

  static const String _legacyPassword = '5828486';

  static const Set<String> _knownSettingsDatabases = <String>{
    'lospossettings',
    'patisyosettings',
    'lotpossettings',
  };

  static const Set<String> _knownDefaultDatabases = <String>{
    'lospos2026',
    'patisyo2025',
    'lotpos2026',
  };

  _ResolvedDbProfile? _cachedProfile;
  _ResolvedDbProfile? _cachedAdminProfile;

  QueryMode get _queryMode {
    final raw = (Platform.environment['LOSPOS_DB_QUERY_MODE'] ?? '')
        .trim()
        .toLowerCase();
    if (raw == 'simple') return QueryMode.simple;
    if (raw == 'extended') return QueryMode.extended;

    final poolerMode = (Platform.environment['LOSPOS_DB_POOLER_MODE'] ?? '')
        .trim()
        .toLowerCase();
    if (poolerMode == 'transaction' || poolerMode == 'tx') {
      return QueryMode.simple;
    }
    if (poolerMode == 'session') return QueryMode.extended;

    final hostLower = _host.trim().toLowerCase();
    final bool looksLikePooler =
        hostLower.contains('-pooler') || hostLower.contains('pooler.');
    final bool looksLikeTxPort = _port == 6543;

    if (looksLikePooler || looksLikeTxPort) return QueryMode.simple;
    return QueryMode.extended;
  }

  bool get _looksLocalHost {
    final h = _host.trim().toLowerCase();
    return h == 'localhost' || h == '127.0.0.1' || h == '::1';
  }

  SslMode get _sslMode {
    final raw = (Platform.environment['LOSPOS_DB_SSLMODE'] ?? '')
        .trim()
        .toLowerCase();
    if (raw == 'require') return SslMode.require;
    if (raw == 'disable') return SslMode.disable;
    return _looksLocalHost ? SslMode.disable : SslMode.require;
  }

  List<String> _candidateUsernames() {
    final env = Platform.environment;
    final result = <String>[];
    final seen = <String>{};

    void add(String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return;
      if (seen.add(v)) result.add(v);
    }

    add('postgres');
    add(_preferredUsername);
    add('patisyo');
    add('lospos');
    add(env['USER']);
    add(env['USERNAME']);
    return result;
  }

  List<String> _candidatePasswords() {
    final env = Platform.environment;
    final result = <String>[];
    final seen = <String>{};

    void add(String? value) {
      if (value == null) return;
      if (seen.add(value)) result.add(value);
    }

    add((env['LOSPOS_DB_PASSWORD'] ?? '').trim().isEmpty
        ? null
        : env['LOSPOS_DB_PASSWORD']!.trim());
    add((env['PGPASSWORD'] ?? '').trim().isEmpty
        ? null
        : env['PGPASSWORD']!.trim());
    add(_legacyPassword);
    add('');
    add('postgres');
    add('password');
    add('123456');
    add('admin');
    add('root');
    return result;
  }

  List<String> _candidateProbeDatabases() {
    final result = <String>[];
    final seen = <String>{};

    void add(String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return;
      if (seen.add(v)) result.add(v);
    }

    add('postgres');
    add(_mainDbName);
    for (final db in _knownSettingsDatabases) {
      add(db);
    }
    for (final db in _knownDefaultDatabases) {
      add(db);
    }
    return result;
  }

  Future<_ResolvedDbProfile> _resolveProfile({bool requireAdmin = false}) async {
    final cached = requireAdmin ? _cachedAdminProfile : _cachedProfile;
    if (cached != null) return cached;

    final candidates = _candidateProbeDatabases();
    final users = _candidateUsernames();
    final passwords = _candidatePasswords();

    for (final user in users) {
      for (final password in passwords) {
        for (final database in candidates) {
          Connection? conn;
          try {
            conn = await Connection.open(
              Endpoint(
                host: _host,
                port: _port,
                database: database,
                username: user,
                password: password,
              ),
              settings: ConnectionSettings(
                sslMode: _sslMode,
                queryMode: _queryMode,
              ),
            );

            final attrs = await conn.execute('''
              SELECT r.rolsuper, r.rolcreatedb
              FROM pg_roles r
              WHERE r.rolname = current_user
            ''');
            final first = attrs.isNotEmpty ? attrs.first : null;
            final isSuper = first?[0] == true;
            final canCreateDb = first?[1] == true;
            final isAdmin = isSuper || canCreateDb;

            final profile = _ResolvedDbProfile(
              username: user,
              password: password,
              probeDatabase: database,
              isAdmin: isAdmin,
            );

            if (requireAdmin && !profile.isAdmin) {
              continue;
            }

            _cachedProfile ??= profile;
            if (profile.isAdmin) {
              _cachedAdminProfile ??= profile;
            }
            return profile;
          } catch (_) {
            continue;
          } finally {
            await conn?.close();
          }
        }
      }
    }

    throw StateError(
      'Yerel PostgreSQL için uygun giriş profili bulunamadı. '
      'LOSPOS_DB_HOST/PORT/USER/PASSWORD değişkenlerini kontrol edin.',
    );
  }

  Future<Connection> _openWithProfile({
    required _ResolvedDbProfile profile,
    required String database,
  }) {
    return Connection.open(
      Endpoint(
        host: _host,
        port: _port,
        database: database,
        username: profile.username,
        password: profile.password,
      ),
      settings: ConnectionSettings(
        sslMode: _sslMode,
        queryMode: _queryMode,
      ),
    );
  }

  bool _isSettingsDatabase(String dbName) {
    return _knownSettingsDatabases.contains(dbName.trim().toLowerCase());
  }

  bool _isAppDatabase(String dbName) {
    final normalized = dbName.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'postgres') return false;
    if (_isSettingsDatabase(normalized)) return true;
    if (_knownDefaultDatabases.contains(normalized)) return true;
    return normalized.startsWith('lospos_') ||
        normalized.startsWith('patisyo_') ||
        normalized.startsWith('lotpos_');
  }

  Future<List<String>> _listAppDatabases({
    required _ResolvedDbProfile profile,
  }) async {
    Connection? conn;
    try {
      conn = await _openWithProfile(profile: profile, database: 'postgres');
      final rows = await conn.execute('''
        SELECT datname
        FROM pg_database
        WHERE datistemplate = false
        ORDER BY datname
      ''');

      final result = <String>[];
      for (final row in rows) {
        final dbName = (row[0] as String? ?? '').trim();
        if (_isAppDatabase(dbName)) {
          result.add(dbName);
        }
      }
      return result;
    } finally {
      await conn?.close();
    }
  }

  Future<List<String>> _listSettingsDatabases({
    required _ResolvedDbProfile profile,
  }) async {
    final appDatabases = await _listAppDatabases(profile: profile);
    return appDatabases.where(_isSettingsDatabase).toList();
  }

  Future<Set<String>> _collectMappedCompanyDatabases({
    required _ResolvedDbProfile profile,
    required List<String> settingsDatabases,
  }) async {
    final result = <String>{};

    for (final settingsDb in settingsDatabases) {
      Connection? conn;
      try {
        conn = await _openWithProfile(profile: profile, database: settingsDb);
        final rows = await conn.execute('SELECT kod FROM company_settings');
        for (final row in rows) {
          final code = (row[0] as String? ?? '').trim();
          if (code.isEmpty) continue;
          result.add(_veritabaniAdiHesapla(code));
        }
      } on ServerException catch (e) {
        if (e.code != '42P01') {
          stdout.writeln(
            '⚠️ $settingsDb içinden company_settings okunamadı: ${e.code} ${e.message}',
          );
        }
      } catch (e) {
        stdout.writeln('⚠️ $settingsDb içinden şirket kodları okunamadı: $e');
      } finally {
        await conn?.close();
      }
    }

    return result;
  }

  Future<void> tumSirketVeritabanlariniSifirla() async {
    stdout.writeln(
      '------------------------------------------------------------',
    );
    stdout.writeln('🚀 LOSPOS ŞİRKET VERİTABANI TEMİZLİĞİ');
    stdout.writeln(
      '------------------------------------------------------------',
    );

    final profile = await _resolveProfile();
    final settingsDatabases = await _listSettingsDatabases(profile: profile);
    final mappedDatabases = await _collectMappedCompanyDatabases(
      profile: profile,
      settingsDatabases: settingsDatabases,
    );
    final appDatabases = await _listAppDatabases(profile: profile);

    final sirketDbNames = <String>{
      ...appDatabases.where((db) => !_isSettingsDatabase(db)),
      ...mappedDatabases.where((db) => !_isSettingsDatabase(db)),
    };

    final directDb =
        (Platform.environment['LOSPOS_RESET_DB_NAME'] ??
                Platform.environment['LOSPOS_DB_NAME'] ??
                '')
            .trim();
    if (directDb.isNotEmpty) {
      sirketDbNames.add(directDb);
    }

    if (sirketDbNames.isEmpty) {
      stdout.writeln('ℹ️ Temizlenecek şirket veritabanı bulunamadı.');
      return;
    }

    final ordered = sirketDbNames.toList()..sort();
    stdout.writeln('📂 Temizlenecek şirket veritabanları: ${ordered.join(', ')}');

    for (final dbName in ordered) {
      if (_isSettingsDatabase(dbName)) {
        stdout.writeln('🛡️ Ayar veritabanı atlandı -> $dbName');
        continue;
      }
      await _sirketVeritabaniSifirla(profile: profile, dbName: dbName);
    }
  }

  Future<void> tamIlkKurulumSifirlamasiYap() async {
    stdout.writeln(
      '------------------------------------------------------------',
    );
    stdout.writeln('🧼 LOSPOS TAM İLK KURULUM SIFIRLAMASI');
    stdout.writeln(
      '------------------------------------------------------------',
    );

    final profile = await _resolveProfile(requireAdmin: true);
    final appDatabases = await _listAppDatabases(profile: profile);
    if (appDatabases.isEmpty) {
      stdout.writeln('ℹ️ Silinecek uygulama veritabanı bulunamadı.');
    } else {
      stdout.writeln('📂 Silinecek veritabanları: ${appDatabases.join(', ')}');
      for (final dbName in appDatabases) {
        await _dropDatabase(profile: profile, dbName: dbName);
      }
    }

    await _uygulamaIzleriniTemizle();

    stdout.writeln('');
    stdout.writeln(
      '✅ Tam sıfırlama tamamlandı. Sonraki açılışta uygulama ilk kurulum akışına düşecek.',
    );
  }

  Future<void> sirketVeritabaniSifirlaKodIle(String sirketKodu) async {
    final profile = await _resolveProfile();
    final String dbName = _veritabaniAdiHesapla(sirketKodu);
    if (_isSettingsDatabase(dbName)) {
      stdout.writeln('🛡️ Ayar veritabanı sıfırlanmadı -> $dbName');
      return;
    }
    await _sirketVeritabaniSifirla(profile: profile, dbName: dbName);
  }

  String _veritabaniAdiHesapla(String kod) {
    return SirketVeritabaniKimligi.databaseNameFromCompanyCode(kod);
  }

  Future<void> _sirketVeritabaniSifirla({
    required _ResolvedDbProfile profile,
    required String dbName,
  }) async {
    stdout.writeln('\n🧹 Sıfırlama başlıyor -> $dbName');

    Connection? conn;
    try {
      conn = await _openWithProfile(profile: profile, database: dbName);

      final List<String> tablolar = [
        'sales',
        'sale_items',
        'purchases',
        'purchase_items',
        'orders',
        'order_items',
        'quotes',
        'quote_items',
        'shipments',
        'stock_movements',
        'warehouse_stocks',
        'products',
        'product_metadata',
        'product_devices',
        'table_counts',
        'cash_register_transactions',
        'bank_transactions',
        'banks',
        'credit_card_transactions',
        'credit_cards',
        'expenses',
        'expense_items',
        'cheques',
        'cheque_transactions',
        'promissory_notes',
        'note_transactions',
        'current_account_transactions',
        'current_accounts',
        'account_metadata',
        'installments',
        'productions',
        'production_recipe_items',
        'production_stock_movements',
        'production_metadata',
        'user_transactions',
        'users',
        'roles',
        'sync_delta_outbox',
        'sync_tombstones',
        'sync_outbox',
        'sequences',
        'logs',
        'company_settings',
        'general_settings',
        'saved_descriptions',
        'hidden_descriptions',
        'currency_rates',
      ];

      for (final table in tablolar) {
        await _safeTruncate(conn, table);
      }

      stdout.writeln('✅ Sıfırlama tamamlandı -> $dbName');
    } on ServerException catch (e) {
      if (e.code == '3D000') {
        stdout.writeln('⏭️ Veritabanı bulunamadı, atlanıyor -> $dbName');
      } else {
        stdout.writeln('❌ "$dbName" ServerException: ${e.code} ${e.message}');
      }
    } catch (e) {
      stdout.writeln('❌ "$dbName" beklenmeyen hata: $e');
    } finally {
      await conn?.close();
    }
  }

  Future<void> _safeTruncate(Connection conn, String tableName) async {
    try {
      await conn.execute('TRUNCATE TABLE $tableName RESTART IDENTITY CASCADE');
      stdout.writeln('   🔹 $tableName temizlendi');
    } on ServerException catch (e) {
      if (e.code == '42P01') {
        return;
      }
      stdout.writeln('   ⚠️ $tableName hatası: ${e.code} ${e.message}');
    } catch (e) {
      stdout.writeln('   ⚠️ $tableName beklenmeyen hata: $e');
    }
  }

  Future<void> _dropDatabase({
    required _ResolvedDbProfile profile,
    required String dbName,
  }) async {
    if (!_isAppDatabase(dbName)) {
      stdout.writeln('🛡️ Uygulama dışı DB atlandı -> $dbName');
      return;
    }

    stdout.writeln('\n🗑️ Veritabanı siliniyor -> $dbName');

    Connection? conn;
    try {
      conn = await _openWithProfile(profile: profile, database: 'postgres');

      await conn.execute(
        Sql.named('''
          SELECT pg_terminate_backend(pid)
          FROM pg_stat_activity
          WHERE datname = @dbName
            AND pid <> pg_backend_pid()
        '''),
        parameters: <String, Object?>{'dbName': dbName},
      );

      await conn.execute('DROP DATABASE IF EXISTS "${_escapeIdentifier(dbName)}"');
      stdout.writeln('   ✅ Silindi -> $dbName');
    } catch (e) {
      stdout.writeln('   ❌ Silinemedi -> $dbName ($e)');
      rethrow;
    } finally {
      await conn?.close();
    }
  }

  Future<void> _uygulamaIzleriniTemizle() async {
    stdout.writeln('');
    stdout.writeln('🧽 Yerel uygulama izleri temizleniyor...');

    final paths = _uygulamaIziYollari();
    if (Platform.isMacOS) {
      await _macosDefaultsSil('com.example.lospos');
      await _macosDefaultsSil('com.example.patisyov10');
    }

    for (final path in paths) {
      await _safeDeletePath(path);
    }
  }

  Future<void> _macosDefaultsSil(String domain) async {
    try {
      final result = await Process.run('defaults', ['delete', domain]);
      if (result.exitCode == 0) {
        stdout.writeln('   🔹 macOS preferences silindi -> $domain');
      }
    } catch (_) {
      // Sessiz: dosya bazlı silme zaten aşağıda çalışacak.
    }
  }

  List<String> _uygulamaIziYollari() {
    final env = Platform.environment;
    final home = env['HOME'] ?? '';
    final baseData =
        env['LOCALAPPDATA'] ??
        env['APPDATA'] ??
        env['USERPROFILE'] ??
        home;

    final result = <String>{};

    void add(String path) {
      if (path.trim().isNotEmpty) result.add(path);
    }

    if (home.isNotEmpty && Platform.isMacOS) {
      add('$home/Library/Preferences/com.example.lospos.plist');
      add('$home/Library/Preferences/com.example.patisyov10.plist');
      add('$home/Library/Application Support/com.example.lospos');
      add('$home/Library/Application Support/com.example.patisyov10');
      add('$home/Library/Caches/com.example.lospos');
      add('$home/Library/Caches/com.example.patisyov10');
      add('$home/Library/HTTPStorages/com.example.lospos');
      add('$home/Library/HTTPStorages/com.example.lospos.binarycookies');
      add('$home/Library/HTTPStorages/com.example.patisyov10');
      add('$home/Library/HTTPStorages/com.example.patisyov10.binarycookies');
      add('$home/Library/WebKit/com.example.lospos');
      add('$home/Library/WebKit/com.example.patisyov10');
      add('$home/Library/Saved Application State/com.example.lospos.savedState');
      add(
        '$home/Library/Saved Application State/com.example.patisyov10.savedState',
      );
    }

    if (baseData.trim().isNotEmpty) {
      add(_joinPath(<String>[baseData, 'lospos', 'postgresql']));
      add(_joinPath(<String>[baseData, 'lospos']));
      add(_joinPath(<String>[baseData, 'com.example.lospos']));
      add(_joinPath(<String>[baseData, 'com.example.patisyov10']));
    }

    if (Platform.isLinux && home.isNotEmpty) {
      add(_joinPath(<String>[home, '.config', 'lospos']));
      add(_joinPath(<String>[home, '.config', 'com.example.lospos']));
      add(_joinPath(<String>[home, '.config', 'com.example.patisyov10']));
      add(_joinPath(<String>[home, '.local', 'share', 'lospos']));
      add(_joinPath(<String>[home, '.cache', 'lospos']));
    }

    return result.toList()..sort();
  }

  Future<void> _safeDeletePath(String path) async {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    try {
      switch (type) {
        case FileSystemEntityType.notFound:
          return;
        case FileSystemEntityType.file:
        case FileSystemEntityType.link:
          await File(path).delete();
          stdout.writeln('   🔹 Silindi -> $path');
          return;
        case FileSystemEntityType.directory:
          await Directory(path).delete(recursive: true);
          stdout.writeln('   🔹 Silindi -> $path');
          return;
        case FileSystemEntityType.unixDomainSock:
        case FileSystemEntityType.pipe:
          return;
      }
    } catch (e) {
      stdout.writeln('   ⚠️ Silinemedi -> $path ($e)');
    }
  }

  String _joinPath(List<String> parts) {
    final cleaned = <String>[];
    for (var i = 0; i < parts.length; i++) {
      final raw = parts[i].trim();
      if (raw.isEmpty) continue;
      if (i == 0) {
        cleaned.add(raw.replaceAll(RegExp(r'[\\/]+$'), ''));
      } else {
        cleaned.add(raw.replaceAll(RegExp(r'^[\\/]+|[\\/]+$'), ''));
      }
    }
    return cleaned.join(Platform.pathSeparator);
  }

  String _escapeIdentifier(String identifier) {
    return identifier.replaceAll('"', '""');
  }
}

class _ResolvedDbProfile {
  final String username;
  final String password;
  final String probeDatabase;
  final bool isAdmin;

  const _ResolvedDbProfile({
    required this.username,
    required this.password,
    required this.probeDatabase,
    required this.isAdmin,
  });
}

Future<void> main() async {
  stdout.writeln('\n🔔 BAŞLATILIYOR...');

  final mode = (Platform.environment['LOSPOS_RESET_MODE'] ?? 'fresh_install')
      .trim()
      .toLowerCase();
  final servis = VeritabaniResetServisi();

  if (mode == 'truncate') {
    await servis.tumSirketVeritabanlariniSifirla();
  } else {
    await servis.tamIlkKurulumSifirlamasiYap();
  }

  stdout.writeln('\n🏁 TÜM İŞLEMLER BİTTİ.\n');
}
