import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Veritabanı Yapılandırma Servisi
class VeritabaniYapilandirma {
  static final VeritabaniYapilandirma _instance =
      VeritabaniYapilandirma._internal();
  factory VeritabaniYapilandirma() => _instance;
  VeritabaniYapilandirma._internal();

  // SharedPreferences Keys
  static const String _prefConnectionMode =
      'patisyo_connection_mode'; // 'local' or 'cloud'
  static const String _prefLastDiscoveredHost = 'patisyo_last_host';
  static const String _prefCloudHost = 'patisyo_cloud_db_host';
  static const String _prefCloudPort = 'patisyo_cloud_db_port';
  static const String _prefCloudUsername = 'patisyo_cloud_db_user';
  static const String _prefCloudPassword = 'patisyo_cloud_db_password';
  static const String _prefCloudDatabase = 'patisyo_cloud_db_name';
  static const String _prefCloudSslRequired = 'patisyo_cloud_db_ssl_required';

  // Environment Variable Keys
  static const String _hostKey = 'PATISYO_DB_HOST';
  static const String _portKey = 'PATISYO_DB_PORT';
  static const String _usernameKey = 'PATISYO_DB_USER';
  static const String _passwordKey = 'PATISYO_DB_PASSWORD';
  static const String _databaseKey = 'PATISYO_DB_NAME';
  static const String _maxConnectionsKey = 'PATISYO_DB_MAX_CONNECTIONS';
  static const String _batchSizeKey = 'PATISYO_BATCH_SIZE';

  // Varsayılan değerler
  static const String _defaultHost = '127.0.0.1';
  static const int _defaultPort = 5432;
  static const String _defaultUsername = 'patisyo';
  static const String _defaultDatabase = 'patisyosettings';
  static const int _defaultMaxConnections = 20;
  static const int _defaultBatchSize = 5000;
  static const List<int> _legacyPasswordBytes = [53, 56, 50, 56, 52, 56, 54];

  // State
  static bool _configLoadedOnce = false;
  static String? _discoveredHost;
  static String _connectionMode = 'cloud'; // Varsayılan bulut
  static String? _cloudHost;
  static int? _cloudPort;
  static String? _cloudUsername;
  static String? _cloudPassword;
  static String? _cloudDatabase;
  static bool? _cloudSslRequired;

  /// Mobil cihaz mı? (Android/iOS)
  bool get isMobilePlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Bulut modu mu?
  bool get isCloudMode => VeritabaniYapilandirma.connectionMode == 'cloud';

  /// Uygulama gerçekten bulut (remote) veritabanına mı bağlı?
  /// - Cloud modu seçili + admin panelden kimlikler hazırsa "gerçek bulut" kabul edilir.
  /// - Cloud modu seçili ama kimlikler hazır değilse, host/port env/localhost'a düşebilir (yerel gibi).
  bool get isEffectiveCloudDatabase =>
      isCloudMode && VeritabaniYapilandirma.cloudCredentialsReady;

  /// Ağır arka plan DB bakım işleri çalışsın mı?
  /// - Mobil + Bulut: Kullanıcı işlemlerini bloklamaması için kapalı.
  /// - Diğer platformlar: açık.
  bool get allowBackgroundDbMaintenance {
    if (kIsWeb) return true;
    if (isMobilePlatform && isCloudMode) return false;
    return true;
  }

  /// Pool'dan bağlantı alırken bekleme süresi.
  /// Cloud ortamlarında (yüksek latency/şema kontrolü) kısa timeout'lar kullanıcıya
  /// "Failed to acquire pool lock" hatası olarak dönebiliyor.
  Duration get poolConnectTimeout {
    if (kIsWeb) return const Duration(seconds: 15);
    if (isCloudMode) {
      // Mobilde ağ dalgalanması daha fazla: biraz daha toleranslı.
      return isMobilePlatform
          ? const Duration(seconds: 45)
          : const Duration(seconds: 30);
    }
    return const Duration(seconds: 15);
  }

  /// Yeni açılan bağlantılar için session seviyesinde ayarlar.
  /// Supabase gibi managed ortamlarda `statement_timeout` varsayılanı düşük olabildiği için,
  /// şema kontrolü / migration gibi işlemlerin yarım kalmasını engeller.
  Future<void> tuneConnection(Connection connection) async {
    try {
      if (isCloudMode) {
        await connection.execute('SET statement_timeout TO 0');
      }
    } catch (_) {
      // Sessiz: bağlantı kurulumu, kullanıcı akışını bozmamalı.
    }
  }

  /// Bağlantı tipini ve host'u yükler (Işık hızında açılış için)
  static Future<void> loadPersistedConfig({bool force = false}) async {
    if (_configLoadedOnce && !force) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSavedMode = prefs.containsKey(_prefConnectionMode);
      if (hasSavedMode) {
        _connectionMode = prefs.getString(_prefConnectionMode) ?? 'cloud';
      } else {
        // İlk kurulum varsayılanı:
        // - Desktop: Yerel (kullanıcı ilk açılışta direkt çalışsın).
        // - Mobil/Tablet: Bulut (kurulum ekranı bunu yönetiyor).
        if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          _connectionMode = 'local';
        } else {
          _connectionMode = 'cloud';
        }
      }
      _discoveredHost = prefs.getString(_prefLastDiscoveredHost);
      _cloudHost = prefs.getString(_prefCloudHost);
      _cloudPort = prefs.getInt(_prefCloudPort);
      _cloudUsername = prefs.getString(_prefCloudUsername);
      _cloudPassword = prefs.getString(_prefCloudPassword);
      _cloudDatabase = prefs.getString(_prefCloudDatabase);
      _cloudSslRequired = prefs.getBool(_prefCloudSslRequired);
      _configLoadedOnce = true;
      debugPrint(
        'VeritabaniYapilandirma: Yapılandırma yüklendi. Mod: $_connectionMode, Host: $_discoveredHost',
      );
    } catch (e) {
      debugPrint('VeritabaniYapilandirma: Yükleme hatası: $e');
    }
  }

  /// Bağlantı tercihlerini kaydeder
  static Future<void> saveConnectionPreferences(
    String mode,
    String? host,
  ) async {
    _connectionMode = mode;
    final normalizedHost = host?.trim();
    _discoveredHost =
        (normalizedHost != null && normalizedHost.isNotEmpty) ? normalizedHost : null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefConnectionMode, mode);
    if (_discoveredHost != null) {
      await prefs.setString(_prefLastDiscoveredHost, _discoveredHost!);
    }
    debugPrint(
      'VeritabaniYapilandirma: Tercihler kaydedildi. Mod: $mode, Host: $_discoveredHost',
    );
  }

  static String get connectionMode => _connectionMode;
  static String? get discoveredHost {
    final host = _discoveredHost?.trim();
    if (host == null || host.isEmpty) return null;
    return host;
  }
  static bool get cloudCredentialsReady {
    final host = _cloudHost?.trim() ?? '';
    final db = _cloudDatabase?.trim() ?? '';
    final user = _cloudUsername?.trim() ?? '';
    final pass = _cloudPassword ?? '';
    return host.isNotEmpty && db.isNotEmpty && user.isNotEmpty && pass.isNotEmpty;
  }

  static Future<void> saveCloudDatabaseCredentials({
    required String host,
    required int port,
    required String username,
    required String password,
    required String database,
    bool sslRequired = true,
  }) async {
    _cloudHost = host.trim();
    _cloudPort = port;
    _cloudUsername = username.trim();
    _cloudPassword = password;
    _cloudDatabase = database.trim();
    _cloudSslRequired = sslRequired;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCloudHost, _cloudHost!);
    await prefs.setInt(_prefCloudPort, _cloudPort ?? _defaultPort);
    await prefs.setString(_prefCloudUsername, _cloudUsername!);
    await prefs.setString(_prefCloudPassword, _cloudPassword!);
    await prefs.setString(_prefCloudDatabase, _cloudDatabase!);
    await prefs.setBool(_prefCloudSslRequired, sslRequired);

    debugPrint('VeritabaniYapilandirma: Bulut kimlikleri kaydedildi.');
  }

  static Future<void> clearCloudDatabaseCredentials() async {
    _cloudHost = null;
    _cloudPort = null;
    _cloudUsername = null;
    _cloudPassword = null;
    _cloudDatabase = null;
    _cloudSslRequired = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefCloudHost);
    await prefs.remove(_prefCloudPort);
    await prefs.remove(_prefCloudUsername);
    await prefs.remove(_prefCloudPassword);
    await prefs.remove(_prefCloudDatabase);
    await prefs.remove(_prefCloudSslRequired);
    debugPrint('VeritabaniYapilandirma: Bulut kimlikleri temizlendi.');
  }
  static String get _legacyPassword =>
      String.fromCharCodes(_legacyPasswordBytes);

  /// Veritabanı Sunucu Adresi
  String get host {
    if (kIsWeb) return _defaultHost;

    // Mobil/Tablet: Bulut modu seçili ama kimlikler hazır değilse
    // kesinlikle yerel keşfe (discoveredHost) veya env/localhost fallback'ine düşme.
    // Bu durumda bağlantı akışı "bekleme/kontrol" ekranı üzerinden ilerlemeli.
    if ((Platform.isAndroid || Platform.isIOS) &&
        _connectionMode == 'cloud' &&
        !cloudCredentialsReady) {
      return _defaultHost;
    }

    // Bulut modu: admin tarafından girilen remote host'u kullan
    if (_connectionMode == 'cloud' && cloudCredentialsReady) {
      return _cloudHost!.trim();
    }

    // 1. Manuel keşif veya yüklenen host
    if (_discoveredHost != null && _discoveredHost!.isNotEmpty) {
      return _discoveredHost!;
    }

    // 2. Çevresel değişken
    final envHost = Platform.environment[_hostKey];
    if (envHost != null && envHost.isNotEmpty) return envHost;

    // 3. Desktop varsayılanı
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return '127.0.0.1';
    }

    return _defaultHost;
  }

  /// Veritabanı Port Numarası
  int get port {
    if (kIsWeb) return _defaultPort;
    if (_connectionMode == 'cloud' && cloudCredentialsReady) {
      return _cloudPort ?? _defaultPort;
    }
    final portStr = Platform.environment[_portKey];
    if (portStr != null) {
      return int.tryParse(portStr) ?? _defaultPort;
    }
    return _defaultPort;
  }

  /// Veritabanı Kullanıcı Adı
  String get username {
    if (kIsWeb) return _defaultUsername;
    if (_connectionMode == 'cloud' && cloudCredentialsReady) {
      return _cloudUsername!.trim();
    }
    return Platform.environment[_usernameKey] ?? _defaultUsername;
  }

  /// Veritabanı Şifresi
  String get password {
    if (kIsWeb) return _legacyPassword;
    if (_connectionMode == 'cloud' && cloudCredentialsReady) {
      return _cloudPassword!;
    }
    final fromEnv = Platform.environment[_passwordKey];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return _legacyPassword;
  }

  /// Veritabanı Adı
  String get database {
    if (kIsWeb) return _defaultDatabase;
    if (_connectionMode == 'cloud' && cloudCredentialsReady) {
      return _cloudDatabase!.trim();
    }
    return Platform.environment[_databaseKey] ?? _defaultDatabase;
  }

  SslMode get sslMode {
    if (kIsWeb) return SslMode.disable;
    if (_connectionMode == 'cloud' && cloudCredentialsReady) {
      final required = _cloudSslRequired ?? true;
      return required ? SslMode.require : SslMode.disable;
    }
    return SslMode.disable;
  }

  /// Maksimum Bağlantı Sayısı (Connection Pool)
  int get maxConnections {
    if (kIsWeb) return _defaultMaxConnections;
    final connStr = Platform.environment[_maxConnectionsKey];
    final int requested = connStr != null
        ? (int.tryParse(connStr) ?? _defaultMaxConnections)
        : _defaultMaxConnections;

    // Mobile devices can easily exhaust Postgres connection limits because
    // multiple modules each keep their own pool. Cap the pool size on iOS/Android.
    if (Platform.isAndroid || Platform.isIOS) {
      // Cloud DB (Supabase vb.) bağlantı limitleri daha düşük olabildiği için
      // mobilde havuz boyutunu daha agresif kısıtla.
      // Not: 1 bağlantı bazı senaryolarda (transaction + paralel okuma) TimeoutException'a sebep olabilir.
      final int mobileCap = _connectionMode == 'cloud' ? 2 : 2;
      if (requested < 1) return 1;
      return requested > mobileCap ? mobileCap : requested;
    }

    return requested;
  }

  /// Batch İşlem Boyutu (Toplu güncellemeler için)
  int get batchSize {
    if (kIsWeb) return _defaultBatchSize;
    final sizeStr = Platform.environment[_batchSizeKey];
    if (sizeStr != null) {
      return int.tryParse(sizeStr) ?? _defaultBatchSize;
    }
    return _defaultBatchSize;
  }

  /// Debug modda yapılandırma bilgilerini logla (Şifre gizli)
  void logYapilandirma() {
    if (kDebugMode) {
      debugPrint('═══════════════════════════════════════════');
      debugPrint('📊 VERİTABANI YAPILANDIRMASI');
      debugPrint('───────────────────────────────────────────');
      debugPrint('Host: $host');
      debugPrint('Port: $port');
      debugPrint('Kullanıcı: $username');
      debugPrint('Şifre: ${'*' * password.length}');
      debugPrint('Max Bağlantı: $maxConnections');
      debugPrint('Batch Boyutu: $batchSize');
      debugPrint('═══════════════════════════════════════════');
    }
  }

  /// Production modunda mı çalışıyor?
  bool get isProduction {
    if (kIsWeb) return false;
    return Platform.environment.containsKey(_hostKey) ||
        Platform.environment.containsKey(_usernameKey);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Local DB: Schema (SQL) Export (Desktop Only)
  // ──────────────────────────────────────────────────────────────────────────

  static String? _cachedPgDumpPath;

  bool get isDesktopPlatform {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  Future<String?> _pgDumpYolunuBul() async {
    if (kIsWeb) return null;

    final cached = _cachedPgDumpPath;
    if (cached != null && cached.trim().isNotEmpty) {
      try {
        if (await File(cached).exists()) return cached;
      } catch (_) {}
    }

    if (Platform.isWindows) {
      // 1) PATH (where pg_dump)
      try {
        final which = await Process.run('where', ['pg_dump.exe']);
        if (which.exitCode == 0) {
          final out = which.stdout.toString().trim();
          if (out.isNotEmpty) {
            final first = out.split(RegExp(r'\r?\n')).first.trim();
            if (first.isNotEmpty && await File(first).exists()) {
              _cachedPgDumpPath = first;
              return first;
            }
          }
        }
      } catch (_) {}

      // 2) Common install locations
      final versions = ['18', '17', '16', '15', '14', '13', '12'];
      final candidates = <String>[
        for (final v in versions) 'C:\\Program Files\\PostgreSQL\\$v\\bin\\pg_dump.exe',
        for (final v in versions)
          'C:\\Program Files (x86)\\PostgreSQL\\$v\\bin\\pg_dump.exe',
      ];

      for (final path in candidates) {
        try {
          if (await File(path).exists()) {
            _cachedPgDumpPath = path;
            return path;
          }
        } catch (_) {}
      }

      return null;
    }

    // macOS/Linux (Unix)
    final sep = Platform.pathSeparator;

    // 1) PATH (which pg_dump)
    try {
      final which = await Process.run('which', ['pg_dump']);
      if (which.exitCode == 0) {
        final out = which.stdout.toString().trim();
        if (out.isNotEmpty) {
          final first = out.split(RegExp(r'\r?\n')).first.trim();
          if (first.isNotEmpty && await File(first).exists()) {
            _cachedPgDumpPath = first;
            return first;
          }
        }
      }
    } catch (_) {}

    // 2) Common locations
    final versions = ['18', '17', '16', '15', '14', '13', '12'];
    final binDirs = <String>[
      '/usr/local/bin',
      '/usr/bin',
      '/bin',
      '/usr/sbin',
      '/sbin',
      '/Applications/Postgres.app/Contents/Versions/latest/bin',
      for (final v in versions) ...[
        '/Library/PostgreSQL/$v/bin',
        '/usr/lib/postgresql/$v/bin',
        '/usr/pgsql-$v/bin',
        '/opt/homebrew/opt/postgresql@$v/bin',
        '/usr/local/opt/postgresql@$v/bin',
      ],
      '/opt/homebrew/opt/postgresql/bin',
      '/usr/local/opt/postgresql/bin',
    ];

    for (final dir in binDirs) {
      final candidate = '$dir${sep}pg_dump';
      try {
        if (await File(candidate).exists()) {
          _cachedPgDumpPath = candidate;
          return candidate;
        }
      } catch (_) {}
    }

    return null;
  }

  /// Yerel veritabanının şemasını (verisiz) SQL olarak dışa aktarır.
  ///
  /// Notlar:
  /// - Desktop (Windows/macOS/Linux) için tasarlanmıştır.
  /// - Veri (COPY/INSERT) içermez; sadece şema + indeks/trigger/fonksiyonları içerir.
  Future<void> yerelSemayiSqlOlarakDisariAktar({
    required String outputPath,
    required String databaseName,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web platformunda desteklenmiyor.');
    }
    if (!isDesktopPlatform) {
      throw UnsupportedError('Bu özellik sadece desktop platformlarda çalışır.');
    }
    if (VeritabaniYapilandirma.connectionMode != 'local') {
      throw StateError(
        'Şema dışa aktarma sadece yerel veritabanı modunda yapılır.',
      );
    }

    final pgDump = await _pgDumpYolunuBul();
    if (pgDump == null) {
      throw StateError(
        'pg_dump bulunamadı. PostgreSQL kurulumunu kontrol edin (bin klasörü PATH içinde olmalı).',
      );
    }

    final args = <String>[
      '--host',
      host,
      '--port',
      port.toString(),
      '--username',
      username,
      '--no-password',
      '--format',
      'p',
      '--no-owner',
      '--no-privileges',
      // Data section'ı hariç tut: sadece şema + post-data (index/trigger/constraint)
      '--section',
      'pre-data',
      '--section',
      'post-data',
      '--file',
      outputPath,
      databaseName,
    ];

    final env = Map<String, String>.from(Platform.environment);
    final pass = password;
    if (pass.trim().isNotEmpty) {
      env['PGPASSWORD'] = pass;
    }

    // SSL gerekiyorsa libpq üzerinden belirt (ileride cloud için genişletilebilir).
    if (sslMode == SslMode.require) {
      env['PGSSLMODE'] = 'require';
    } else {
      env['PGSSLMODE'] = 'disable';
    }

    final result = await Process.run(pgDump, args, environment: env);
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      final stdout = result.stdout.toString().trim();
      final msg = stderr.isNotEmpty ? stderr : stdout;
      throw Exception('pg_dump başarısız (exit ${result.exitCode}): $msg');
    }

    final file = File(outputPath);
    if (!await file.exists()) {
      throw Exception('SQL dosyası oluşturulamadı: $outputPath');
    }

    // pg_dump çıktısından psql meta-komutlarını temizle
    // (\restrict, \unrestrict, \connect, \encoding vb.)
    // Bu komutlar sadece psql CLI'da çalışır, SQL motorunda syntax error verir.
    final rawContent = await file.readAsString();
    final cleanedLines = rawContent
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('\\'))
        .toList();
    await file.writeAsString(cleanedLines.join('\n'));
  }

  /// Dinamik keşif sonrası host'u günceller
  static void setDiscoveredHost(String? newHost) {
    final normalizedHost = newHost?.trim();
    _discoveredHost =
        (normalizedHost != null && normalizedHost.isNotEmpty) ? normalizedHost : null;
    debugPrint('VeritabaniYapilandirma: Host güncellendi -> $_discoveredHost');
  }
}
