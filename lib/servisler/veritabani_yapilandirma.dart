import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lisans_servisi.dart';
import 'online_veritabani_servisi.dart';

/// Veritabanı Yapılandırma Servisi
class VeritabaniYapilandirma {
  static final VeritabaniYapilandirma _instance =
      VeritabaniYapilandirma._internal();
  factory VeritabaniYapilandirma() => _instance;
  VeritabaniYapilandirma._internal();

  // SharedPreferences Keys
  static const String _prefConnectionMode =
      'patisyo_connection_mode'; // 'local' | 'hybrid' | 'cloud' | 'cloud_pending'
  static const String _prefLastDiscoveredHost = 'patisyo_last_host';
  static const String _prefCloudHost = 'patisyo_cloud_db_host';
  static const String _prefCloudPort = 'patisyo_cloud_db_port';
  static const String _prefCloudUsername = 'patisyo_cloud_db_user';
  static const String _prefCloudPassword = 'patisyo_cloud_db_password';
  static const String _prefCloudDatabase = 'patisyo_cloud_db_name';
  static const String _prefCloudSslRequired = 'patisyo_cloud_db_ssl_required';

  // Veritabanı aktarımında (desktop) kullanıcı seçimini saklamak için.
  // Değerler: 'merge' | 'full'
  static const String prefPendingTransferChoiceKey =
      'patisyo_pending_db_transfer_choice';

  // Desktop: kullanıcı cloud istedi ama admin ayarı/kimlikleri hazır değil.
  // Bu modda uygulama yerelden çalışmaya devam eder, kimlikler hazır olunca kullanıcıya sorulur.
  static const String cloudPendingMode = 'cloud_pending';

  // Desktop: cloud pending hazır olunca UI tetikleyicisi (global dialog için).
  static final ValueNotifier<int> desktopCloudReadyTick = ValueNotifier<int>(0);

  static Timer? _desktopCloudPendingTimer;
  static bool _desktopCloudPendingCheckInFlight = false;
  static bool _desktopCloudPendingRequestSent = false;
  static bool _desktopCloudReadyEmitted = false;
  static bool _desktopCloudConnectionReady = false;

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
        if (!kIsWeb &&
            (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
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
      if (_cloudPassword != null) {
        _cloudPassword = _cloudPassword!.trim();
      }
      _cloudDatabase = prefs.getString(_prefCloudDatabase);
      _cloudSslRequired = prefs.getBool(_prefCloudSslRequired);

      // Desktop "cloud_pending" modunda: uygulama yerelden çalışmaya devam eder.
      // Bu modda cache'lenmiş kimliklere güvenmeyip, hazır olunca server'dan tekrar çekip
      // kullanıcıya soracağız. (Aksi halde stale cache ile yanlışlıkla "hazır" dialogu açılabilir.)
      if (_connectionMode == cloudPendingMode) {
        _cloudHost = null;
        _cloudPort = null;
        _cloudUsername = null;
        _cloudPassword = null;
        _cloudDatabase = null;
        _cloudSslRequired = null;
      }

      _configLoadedOnce = true;
      _syncDesktopCloudPendingWatcher();
      if (kDebugMode) {
        final cfg = VeritabaniYapilandirma();
        final discovered = (_discoveredHost ?? '').trim();
        final discoveredLabel = discovered.isEmpty ? '-' : discovered;
        debugPrint(
          'VeritabaniYapilandirma: Yapılandırma yüklendi. '
          'Mod: $_connectionMode, '
          'Effective: ${cfg.host}:${cfg.port}/${cfg.database}, '
          'CloudReady: $cloudCredentialsReady, '
          'DiscoveredHost: $discoveredLabel',
        );
      }
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
    _discoveredHost = (normalizedHost != null && normalizedHost.isNotEmpty)
        ? normalizedHost
        : null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefConnectionMode, mode);
    if (_discoveredHost != null) {
      await prefs.setString(_prefLastDiscoveredHost, _discoveredHost!);
    }
    _syncDesktopCloudPendingWatcher();
    debugPrint(
      'VeritabaniYapilandirma: Tercihler kaydedildi. Mod: $mode, Host: $_discoveredHost',
    );
  }

  static String get connectionMode => _connectionMode;
  static bool get isCloudPending => _connectionMode == cloudPendingMode;
  static String? get discoveredHost {
    final host = _discoveredHost?.trim();
    if (host == null || host.isEmpty) return null;
    return host;
  }

  static bool get cloudCredentialsReady {
    final host = _cloudHost?.trim() ?? '';
    final db = _cloudDatabase?.trim() ?? '';
    final user = _cloudUsername?.trim() ?? '';
    final pass = (_cloudPassword ?? '').trim();
    return host.isNotEmpty &&
        db.isNotEmpty &&
        user.isNotEmpty &&
        pass.isNotEmpty;
  }

  /// Desktop `cloud_pending` modunda: admin panelden gelen bulut kimlikleri kaydedilmiş olabilir,
  /// ama Postgres bağlantısı henüz gerçek anlamda hazır olmayabilir (yanlış şifre/db adı vb.).
  /// Bu flag sadece "bağlanabilirlik" kontrolü başarılı olunca true olur.
  static bool get desktopCloudConnectionReady => _desktopCloudConnectionReady;

  // Cloud kimliklerini "mod"a bakmadan okuyabilmek için (ör: local<->cloud veri aktarımı)
  static String? get cloudHost {
    final v = _cloudHost?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  static int? get cloudPort => _cloudPort;

  static String? get cloudUsername {
    final v = _cloudUsername?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  static String? get cloudPassword => _cloudPassword;

  static String? get cloudDatabase {
    final v = _cloudDatabase?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  static bool? get cloudSslRequired => _cloudSslRequired;

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
    _cloudPassword = password.trim();
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
    _syncDesktopCloudPendingWatcher();
  }

  static Future<void> clearCloudDatabaseCredentials() async {
    _cloudHost = null;
    _cloudPort = null;
    _cloudUsername = null;
    _cloudPassword = null;
    _cloudDatabase = null;
    _cloudSslRequired = null;
    _desktopCloudConnectionReady = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefCloudHost);
    await prefs.remove(_prefCloudPort);
    await prefs.remove(_prefCloudUsername);
    await prefs.remove(_prefCloudPassword);
    await prefs.remove(_prefCloudDatabase);
    await prefs.remove(_prefCloudSslRequired);
    debugPrint('VeritabaniYapilandirma: Bulut kimlikleri temizlendi.');
    _syncDesktopCloudPendingWatcher();
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
        for (final v in versions)
          'C:\\Program Files\\PostgreSQL\\$v\\bin\\pg_dump.exe',
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
      throw UnsupportedError(
        'Bu özellik sadece desktop platformlarda çalışır.',
      );
    }
    if (isEffectiveCloudDatabase) {
      throw StateError(
        'Şema dışa aktarma sadece yerel veritabanı (Yerel/Karma) modunda yapılır.',
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
        .where((line) {
          final trimmedLeft = line.trimLeft();

          // psql meta-komutları (SQL motorunda syntax error verir)
          if (trimmedLeft.startsWith('\\')) return false;

          // PostgreSQL 17+ pg_dump çıktısı: `SET transaction_timeout = 0;`
          // Managed DB'lerde (Supabase/Neon) farklı sürümde syntax hatası
          // verebildiği için kaldırıyoruz.
          final lowered = trimmedLeft.toLowerCase();
          if (lowered.startsWith('set transaction_timeout')) return false;

          return true;
        })
        .toList();

    final wrappedContent = _wrapSchemaDumpInTransactionIfMissing(
      cleanedLines.join('\n'),
    );
    final finalContent = _appendManagedCloudHybridBootstrapSql(wrappedContent);
    await file.writeAsString(finalContent);
  }

  String _appendManagedCloudHybridBootstrapSql(String content) {
    // Bu ek blok, Neon/Supabase gibi managed PostgreSQL'lerde uygulama rolüne
    // DDL/trigger/sequence izni verilmediğinde bile hibrit senkronun "tam"
    // çalışabilmesi için gerekli altyapıyı (outbox/tombstone/timestamp/sequence)
    // tek seferde kurar. İndirilen şema SQL'inin en sonuna eklenir.
    //
    // Not: Script idempotent; boş/var olan DB üzerinde güvenle tekrar çalıştırılabilir.
    if (content.contains('-- PATISYO_MANAGED_CLOUD_BOOTSTRAP')) return content;
    final trimmed = content.trimRight();
    return '$trimmed\n\n$_managedCloudHybridBootstrapSql\n';
  }

  static const String _managedCloudHybridBootstrapSql = r'''
-- PATISYO_MANAGED_CLOUD_BOOTSTRAP
-- Managed Cloud (Neon/Supabase) Hibrit Senkron Kurulumu
--
-- Bu blok, uygulama rolünün DDL/trigger/sequence yetkisi olmadığı senaryolarda
-- bile "Karma (Yerel + Bulut)" modunun eksiksiz çalışması için gerekli altyapıyı kurar:
--   - DELETE senkronu: sync_tombstones + AFTER DELETE trigger
--   - Delta (upsert/delete) kuyruğu: sync_delta_outbox + AFTER INSERT/UPDATE/DELETE trigger
--   - Timestamp altyapısı: created_at/updated_at + updated_at trigger (best-effort)
--   - Sequence çakışma azaltma: cloud tarafında SERIAL/BIGSERIAL sequence'ları "even" yap (INCREMENT BY 2)
--
-- Not: Bu scripti Neon/Supabase SQL Editor'de DB owner/admin ile bir kez çalıştırın.

BEGIN;

-- 1) Sequence parity (Cloud: even)
DO $$
DECLARE
  desired_parity int := 0; -- cloud = even
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
      IF mod(nextv, 2) <> desired_parity THEN
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
$$;

-- 2) Tombstones: DELETE propagation
CREATE TABLE IF NOT EXISTS public.sync_tombstones (
  id BIGSERIAL PRIMARY KEY,
  table_name TEXT NOT NULL,
  pk JSONB NOT NULL,
  pk_hash TEXT NOT NULL,
  deleted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sync_tombstones_table_pk
  ON public.sync_tombstones (table_name, pk_hash);
CREATE INDEX IF NOT EXISTS idx_sync_tombstones_deleted_at
  ON public.sync_tombstones (deleted_at);

CREATE OR REPLACE FUNCTION public.patisyo_capture_delete_tombstone()
RETURNS trigger AS $$
DECLARE
  pk_cols TEXT[];
  col TEXT;
  pk JSONB := '{}'::jsonb;
  row JSONB;
BEGIN
  -- Senkron uygulaması sırasında (remote tombstone apply) tekrar tombstone üretme.
  IF COALESCE(current_setting('patisyo.sync_apply', true), '') = '1' THEN
    RETURN OLD;
  END IF;

  -- Dahili tabloları asla tombstone'lama.
  IF TG_TABLE_SCHEMA <> 'public' THEN
    RETURN OLD;
  END IF;
  IF TG_TABLE_NAME = 'sync_tombstones'
     OR TG_TABLE_NAME = 'sync_outbox'
     OR TG_TABLE_NAME = 'sync_delta_outbox' THEN
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

  INSERT INTO public.sync_tombstones (table_name, pk, pk_hash, deleted_at)
  VALUES (TG_TABLE_NAME, pk, md5(pk::text), CURRENT_TIMESTAMP)
  ON CONFLICT (table_name, pk_hash) DO UPDATE
    SET deleted_at = GREATEST(public.sync_tombstones.deleted_at, EXCLUDED.deleted_at),
        pk = EXCLUDED.pk;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DO $$
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
      AND c.relname NOT IN ('sync_tombstones', 'sync_outbox', 'sync_delta_outbox')
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_trigger t
      WHERE t.tgname = 'trg_patisyo_capture_delete'
        AND t.tgrelid = r.oid
    ) THEN
      EXECUTE format(
        'CREATE TRIGGER %s AFTER DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.%s()',
        'trg_patisyo_capture_delete',
        r.name,
        'patisyo_capture_delete_tombstone'
      );
    END IF;
  END LOOP;
END
$$;

-- 3) Delta outbox: upsert/delete change capture
CREATE TABLE IF NOT EXISTS public.sync_delta_outbox (
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
);
CREATE INDEX IF NOT EXISTS idx_sync_delta_outbox_touched_at
  ON public.sync_delta_outbox (touched_at);
CREATE INDEX IF NOT EXISTS idx_sync_delta_outbox_acked_at
  ON public.sync_delta_outbox (acked_at);

CREATE OR REPLACE FUNCTION public.patisyo_capture_delta_outbox()
RETURNS trigger AS $$
DECLARE
  pk_cols TEXT[];
  col TEXT;
  pk JSONB := '{}'::jsonb;
  row JSONB;
  v_action TEXT;
BEGIN
  -- Senkron uygulanırken (remote -> local/cloud upsert/delete) outbox üretme.
  IF COALESCE(current_setting('patisyo.sync_apply', true), '') = '1' THEN
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
    'sync_tombstones',
    'sync_delta_outbox',
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

  INSERT INTO public.sync_delta_outbox (
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
$$ LANGUAGE plpgsql;

DO $$
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
        'sync_tombstones',
        'sync_delta_outbox',
        'sync_outbox',
        'table_counts',
        'sequences',
        'account_metadata'
      )
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_trigger t
      WHERE t.tgname = 'trg_patisyo_capture_delta_outbox'
        AND t.tgrelid = r.oid
    ) THEN
      EXECUTE format(
        'CREATE TRIGGER %s AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.%s()',
        'trg_patisyo_capture_delta_outbox',
        r.name,
        'patisyo_capture_delta_outbox'
      );
    END IF;
  END LOOP;
END
$$;

-- 4) Timestamp infra (best-effort): created_at/updated_at + updated_at trigger
CREATE OR REPLACE FUNCTION public.patisyo_set_updated_at()
RETURNS trigger AS $$
BEGIN
  -- Senkron uygulanırken (remote -> local/cloud upsert) updated_at'ı bozma.
  IF COALESCE(current_setting('patisyo.sync_apply', true), '') = '1' THEN
    RETURN NEW;
  END IF;
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
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
        WHERE t.tgname = 'trg_patisyo_set_updated_at'
          AND t.tgrelid = r.oid
      ) THEN
        EXECUTE format(
          'CREATE TRIGGER %s BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.%s()',
          'trg_patisyo_set_updated_at',
          r.name,
          'patisyo_set_updated_at'
        );
      END IF;
    EXCEPTION WHEN others THEN
      -- ignore
    END;
  END LOOP;
END
$$;

COMMIT;
''';

  String _wrapSchemaDumpInTransactionIfMissing(String content) {
    final lines = content.split('\n');

    bool isExactStatement(String line, String statement) =>
        line.trim().toUpperCase() == statement;

    final alreadyWrapped =
        lines.any((line) => isExactStatement(line, 'BEGIN;')) ||
        lines.any((line) => isExactStatement(line, 'COMMIT;'));
    if (alreadyWrapped) return content;

    int insertAt = 0;
    while (insertAt < lines.length) {
      final trimmed = lines[insertAt].trimLeft();
      if (trimmed.isEmpty || trimmed.startsWith('--')) {
        insertAt++;
        continue;
      }

      final lowered = trimmed.toLowerCase();
      if (lowered.startsWith('set ') ||
          lowered.startsWith('select pg_catalog.set_config')) {
        insertAt++;
        continue;
      }
      break;
    }

    lines.insert(insertAt, 'BEGIN;');
    lines.add('COMMIT;');
    return lines.join('\n');
  }

  /// Dinamik keşif sonrası host'u günceller
  static void setDiscoveredHost(String? newHost) {
    final normalizedHost = newHost?.trim();
    _discoveredHost = (normalizedHost != null && normalizedHost.isNotEmpty)
        ? normalizedHost
        : null;
    debugPrint('VeritabaniYapilandirma: Host güncellendi -> $_discoveredHost');
  }

  static void _syncDesktopCloudPendingWatcher() {
    if (kIsWeb) return;
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;

    // Pending değilse dinlemeyi durdur.
    if (!isCloudPending) {
      _desktopCloudPendingTimer?.cancel();
      _desktopCloudPendingTimer = null;
      _desktopCloudPendingCheckInFlight = false;
      _desktopCloudPendingRequestSent = false;
      _desktopCloudReadyEmitted = false;
      _desktopCloudConnectionReady = false;
      return;
    }

    // Pending + bağlantı hazırsa: tek seferlik UI sinyali üret.
    if (cloudCredentialsReady && _desktopCloudConnectionReady) {
      if (!_desktopCloudReadyEmitted) {
        _desktopCloudReadyEmitted = true;
        desktopCloudReadyTick.value = desktopCloudReadyTick.value + 1;
      }
      _desktopCloudPendingTimer?.cancel();
      _desktopCloudPendingTimer = null;
      return;
    }

    // Pending + hazır değil: timer yoksa başlat.
    if (_desktopCloudPendingTimer != null) return;
    _desktopCloudPendingTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => unawaited(_checkDesktopCloudPendingCredentials()),
    );

    // İlk kontrolü geciktirmeden yap.
    unawaited(_checkDesktopCloudPendingCredentials());
  }

  static Future<void> _ensureSupabaseInitialized() async {
    try {
      await Supabase.initialize(url: LisansServisi.u, anonKey: LisansServisi.k);
    } catch (_) {
      // Zaten başlatılmış olabilir.
    }
  }

  static Future<void> _checkDesktopCloudPendingCredentials() async {
    if (_desktopCloudPendingCheckInFlight) return;
    if (kIsWeb) return;
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
    if (!isCloudPending) return;

    _desktopCloudPendingCheckInFlight = true;
    try {
      await _ensureSupabaseInitialized();

      try {
        await LisansServisi().baslat();
      } catch (_) {}

      final hardwareId = LisansServisi().hardwareId;
      if (hardwareId == null || hardwareId.trim().isEmpty) return;

      final creds = await OnlineVeritabaniServisi().kimlikleriGetir(
        hardwareId.trim(),
      );
      if (creds == null) {
        _desktopCloudConnectionReady = false;
        // Admin panel görünürlüğü için talebi upsert et (best-effort, tek sefer).
        if (!_desktopCloudPendingRequestSent) {
          _desktopCloudPendingRequestSent = true;
          unawaited(
            OnlineVeritabaniServisi().talepGonder(
              hardwareId: hardwareId.trim(),
              source: 'desktop_pending',
            ),
          );
        }
        return;
      }

      await saveCloudDatabaseCredentials(
        host: creds.host,
        port: creds.port,
        username: creds.username,
        password: creds.password,
        database: creds.database,
        sslRequired: creds.sslRequired,
      );

      final ok = await testSavedCloudDatabaseConnection(
        timeout: const Duration(seconds: 6),
      );
      _desktopCloudConnectionReady = ok;
    } catch (e) {
      debugPrint('VeritabaniYapilandirma: Desktop pending kontrol hatası: $e');
    } finally {
      _desktopCloudPendingCheckInFlight = false;
      _syncDesktopCloudPendingWatcher();
    }
  }

  static Future<bool> testSavedCloudDatabaseConnection({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (!cloudCredentialsReady) return false;

    final host = _cloudHost?.trim() ?? '';
    final db = _cloudDatabase?.trim() ?? '';
    final user = _cloudUsername?.trim() ?? '';
    final pass = _cloudPassword ?? '';
    if (host.isEmpty || db.isEmpty || user.isEmpty || pass.isEmpty) {
      return false;
    }

    final port = _cloudPort ?? _defaultPort;
    final requiredSsl = _cloudSslRequired ?? true;

    Connection? conn;
    try {
      conn = await Connection.open(
        Endpoint(
          host: host,
          port: port,
          database: db,
          username: user,
          password: pass,
        ),
        settings: ConnectionSettings(
          sslMode: requiredSsl ? SslMode.require : SslMode.disable,
          connectTimeout: timeout,
        ),
      );
      await conn.execute('SELECT 1');
      return true;
    } on SocketException {
      return false;
    } on ServerException {
      return false;
    } catch (e) {
      debugPrint('VeritabaniYapilandirma: Bulut bağlantı testi hatası: $e');
      return false;
    } finally {
      try {
        await conn?.close();
      } catch (_) {}
    }
  }
}
