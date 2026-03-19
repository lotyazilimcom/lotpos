import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  static const String _prefCloudApiBaseUrl = 'patisyo_cloud_api_base_url';
  static const String _prefCloudApiReadBaseUrl =
      'patisyo_cloud_api_read_base_url';
  static const String _prefCloudApiWriteBaseUrl =
      'patisyo_cloud_api_write_base_url';
  static const String _prefCloudApiToken = 'patisyo_cloud_api_token';

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
  static const String _poolerHostKey = 'PATISYO_DB_POOLER_HOST';
  static const String _poolerPortKey = 'PATISYO_DB_POOLER_PORT';
  static const String _poolerModeKey =
      'PATISYO_DB_POOLER_MODE'; // session | transaction
  static const String _queryModeKey =
      'PATISYO_DB_QUERY_MODE'; // extended | simple
  static const String _batchSizeKey = 'PATISYO_BATCH_SIZE';
  static const String _apiBaseUrlKey = 'PATISYO_API_BASE_URL';
  static const String _apiReadBaseUrlKey = 'PATISYO_API_READ_BASE_URL';
  static const String _apiWriteBaseUrlKey = 'PATISYO_API_WRITE_BASE_URL';
  static const String _apiTokenKey = 'PATISYO_API_TOKEN';
  static const String _allowHeavyMaintenanceKey =
      'PATISYO_ALLOW_HEAVY_MAINTENANCE';
  static const String _allowCitusExtensionKey = 'PATISYO_ALLOW_CITUS_EXTENSION';

  // Varsayılan değerler
  static const String _defaultHost = '127.0.0.1';
  static const int _defaultPort = 5432;
  static const String _defaultUsername = 'patisyo';
  static const String _defaultDatabase = 'patisyosettings';
  static const int _defaultMaxConnections = 20;
  static const int _defaultMaxConnectionsCloud = 6;
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
  static String? _cloudApiBaseUrl;
  static String? _cloudApiReadBaseUrl;
  static String? _cloudApiWriteBaseUrl;
  static String? _cloudApiToken;

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
      isCloudMode && VeritabaniYapilandirma.cloudAccessReady;

  static bool get cloudAccessReady =>
      cloudCredentialsReady || cloudApiCredentialsReady;

  /// Ağır arka plan DB bakım işleri çalışsın mı?
  /// 2026 arama omurgasında search altyapısı her platformda proaktif hazır olmalı.
  bool get allowBackgroundDbMaintenance {
    return true;
  }

  /// [100B SAFE DEFAULT]
  /// Çok büyük veri kümelerinde (1B+ / 100B) uygulama açılışında veya arka planda
  /// `UPDATE ... SET search_tags=...` gibi backfill döngülerini çalıştırmak WAL/I/O'yu
  /// patlatabilir. 2026 arama omurgasında default açık; gerekirse env ile kapatılır.
  ///
  /// Kapatmak için env:
  /// `PATISYO_ALLOW_HEAVY_MAINTENANCE=false`
  bool get allowBackgroundHeavyMaintenance {
    if (kIsWeb) return false;
    final v = (Platform.environment[_allowHeavyMaintenanceKey] ?? '')
        .trim()
        .toLowerCase();
    if (v.isEmpty) return true;
    if (v == '0' || v == 'false' || v == 'no' || v == 'off') return false;
    return v == '1' || v == 'true' || v == 'yes' || v == 'on';
  }

  /// Citus yalnızca explicit satış/kurulum senaryosunda opt-in olmalıdır.
  /// Varsayılan kapalıdır.
  bool get allowCitusExtension {
    if (kIsWeb) return false;
    final v = (Platform.environment[_allowCitusExtensionKey] ?? '')
        .trim()
        .toLowerCase();
    return v == '1' || v == 'true' || v == 'yes' || v == 'on';
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
      _discoveredHost = await _normalizeDiscoveredHostBestEffort(
        prefs.getString(_prefLastDiscoveredHost),
      );
      if (_discoveredHost != null) {
        await prefs.setString(_prefLastDiscoveredHost, _discoveredHost!);
      } else {
        await prefs.remove(_prefLastDiscoveredHost);
      }
      _cloudHost = prefs.getString(_prefCloudHost);
      _cloudPort = prefs.getInt(_prefCloudPort);
      _cloudUsername = prefs.getString(_prefCloudUsername);
      _cloudPassword = prefs.getString(_prefCloudPassword);
      if (_cloudPassword != null) {
        _cloudPassword = _cloudPassword!.trim();
      }
      _cloudDatabase = prefs.getString(_prefCloudDatabase);
      _cloudSslRequired = prefs.getBool(_prefCloudSslRequired);
      _cloudApiBaseUrl = prefs.getString(_prefCloudApiBaseUrl);
      _cloudApiReadBaseUrl = prefs.getString(_prefCloudApiReadBaseUrl);
      _cloudApiWriteBaseUrl = prefs.getString(_prefCloudApiWriteBaseUrl);
      _cloudApiToken = prefs.getString(_prefCloudApiToken);
      if (_cloudApiBaseUrl != null) {
        _cloudApiBaseUrl = _cloudApiBaseUrl!.trim();
      }
      if (_cloudApiReadBaseUrl != null) {
        _cloudApiReadBaseUrl = _cloudApiReadBaseUrl!.trim();
      }
      if (_cloudApiWriteBaseUrl != null) {
        _cloudApiWriteBaseUrl = _cloudApiWriteBaseUrl!.trim();
      }
      if (_cloudApiToken != null) {
        _cloudApiToken = _cloudApiToken!.trim();
      }

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
        _cloudApiBaseUrl = null;
        _cloudApiReadBaseUrl = null;
        _cloudApiWriteBaseUrl = null;
        _cloudApiToken = null;
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
          'CloudReady: $cloudAccessReady, '
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
    _discoveredHost = await _normalizeDiscoveredHostBestEffort(host);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefConnectionMode, mode);
    if (_discoveredHost != null) {
      await prefs.setString(_prefLastDiscoveredHost, _discoveredHost!);
    } else {
      await prefs.remove(_prefLastDiscoveredHost);
    }
    _syncDesktopCloudPendingWatcher();
    debugPrint(
      'VeritabaniYapilandirma: Tercihler kaydedildi. Mod: $mode, Host: $_discoveredHost',
    );
  }

  static String get connectionMode => _connectionMode;
  static bool get isCloudPending => _connectionMode == cloudPendingMode;
  static String? get discoveredHost {
    final host = _temizHost(_discoveredHost);
    if (host == null || host.isEmpty) return null;
    return host;
  }

  static bool yerelAnaSunucuHostMu(String? host) {
    final normalized = (host ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return normalized == '127.0.0.1' ||
        normalized == 'localhost' ||
        normalized == '::1';
  }

  static bool get masaustuAnaServerSecili {
    if (kIsWeb) return false;
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return false;
    }
    return yerelAnaSunucuHostMu(discoveredHost);
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

  static bool get cloudApiCredentialsReady {
    final url = (cloudApiWriteBaseUrl ?? '').trim();
    final token = (cloudApiToken ?? '').trim();
    final db = (_cloudDatabase?.trim() ?? '');
    return url.isNotEmpty && token.isNotEmpty && db.isNotEmpty;
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

  static String? get cloudApiBaseUrl {
    final v = (_cloudApiBaseUrl ?? Platform.environment[_apiBaseUrlKey] ?? '')
        .trim();
    return v.isEmpty ? null : v;
  }

  /// Bulut API (read replica) base URL.
  /// - Öncelik: prefs -> env -> cloudApiBaseUrl
  static String? get cloudApiReadBaseUrl {
    final v =
        (_cloudApiReadBaseUrl ?? Platform.environment[_apiReadBaseUrlKey] ?? '')
            .trim();
    if (v.isNotEmpty) return v;
    return cloudApiBaseUrl;
  }

  /// Bulut API (master/write) base URL.
  /// - Öncelik: prefs -> env -> cloudApiBaseUrl
  static String? get cloudApiWriteBaseUrl {
    final v =
        (_cloudApiWriteBaseUrl ??
                Platform.environment[_apiWriteBaseUrlKey] ??
                '')
            .trim();
    if (v.isNotEmpty) return v;
    return cloudApiBaseUrl;
  }

  static String? get cloudApiToken {
    final v = (_cloudApiToken ?? Platform.environment[_apiTokenKey] ?? '')
        .trim();
    return v.isEmpty ? null : v;
  }

  static Future<void> saveCloudApiCredentials({
    required String baseUrl,
    String? readBaseUrl,
    String? writeBaseUrl,
    required String token,
    required String database,
  }) async {
    final base = baseUrl.trim();
    final read = (readBaseUrl ?? '').trim();
    final write = (writeBaseUrl ?? '').trim();

    _cloudApiBaseUrl = base;
    if (read.isNotEmpty) _cloudApiReadBaseUrl = read;
    _cloudApiReadBaseUrl ??= base;

    if (write.isNotEmpty) _cloudApiWriteBaseUrl = write;
    _cloudApiWriteBaseUrl ??= base;

    _cloudApiToken = token.trim();
    _cloudDatabase = database.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCloudApiBaseUrl, _cloudApiBaseUrl!);
    if (readBaseUrl != null) {
      if (read.isNotEmpty) {
        await prefs.setString(_prefCloudApiReadBaseUrl, read);
      } else {
        await prefs.remove(_prefCloudApiReadBaseUrl);
      }
    }
    if (writeBaseUrl != null) {
      if (write.isNotEmpty) {
        await prefs.setString(_prefCloudApiWriteBaseUrl, write);
      } else {
        await prefs.remove(_prefCloudApiWriteBaseUrl);
      }
    }
    await prefs.setString(_prefCloudApiToken, _cloudApiToken!);
    await prefs.setString(_prefCloudDatabase, _cloudDatabase!);

    debugPrint('VeritabaniYapilandirma: Bulut API kimlikleri kaydedildi.');
    _syncDesktopCloudPendingWatcher();
  }

  static Future<void> clearCloudApiCredentials() async {
    _cloudApiBaseUrl = null;
    _cloudApiReadBaseUrl = null;
    _cloudApiWriteBaseUrl = null;
    _cloudApiToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefCloudApiBaseUrl);
    await prefs.remove(_prefCloudApiReadBaseUrl);
    await prefs.remove(_prefCloudApiWriteBaseUrl);
    await prefs.remove(_prefCloudApiToken);
    debugPrint('VeritabaniYapilandirma: Bulut API kimlikleri temizlendi.');
    _syncDesktopCloudPendingWatcher();
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
      return _cloudPoolerHost(_cloudHost!.trim());
    }

    // 1. Manuel keşif veya yüklenen host
    final resolvedDiscoveredHost = VeritabaniYapilandirma.discoveredHost;
    if (resolvedDiscoveredHost != null && resolvedDiscoveredHost.isNotEmpty) {
      return resolvedDiscoveredHost;
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

  String _cloudPoolerHost(String rawHost) {
    final envPoolerHost = (Platform.environment[_poolerHostKey] ?? '').trim();
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

  /// Veritabanı Port Numarası
  int get port {
    if (kIsWeb) return _defaultPort;
    if (_connectionMode == 'cloud' && cloudCredentialsReady) {
      final envPoolerPort = (Platform.environment[_poolerPortKey] ?? '').trim();
      if (envPoolerPort.isNotEmpty) {
        return int.tryParse(envPoolerPort) ?? (_cloudPort ?? _defaultPort);
      }
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
    if (_connectionMode == 'cloud' &&
        (cloudCredentialsReady || cloudApiCredentialsReady)) {
      final db = (_cloudDatabase ?? '').trim();
      if (db.isNotEmpty) return db;
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

  /// Pooler modu (ENV): `session` | `transaction`
  /// Not: Bazı managed ortamlarda (Supabase/Neon) pooler davranışı endpoint'e göre değişebilir.
  String get poolerMode {
    if (kIsWeb) return '';
    return (Platform.environment[_poolerModeKey] ?? '').trim();
  }

  QueryMode get queryMode {
    if (kIsWeb) return QueryMode.extended;

    final envQueryMode = (Platform.environment[_queryModeKey] ?? '')
        .trim()
        .toLowerCase();
    if (envQueryMode == 'simple') return QueryMode.simple;
    if (envQueryMode == 'extended') return QueryMode.extended;

    // IMPORTANT:
    // - Dart `postgres` paketi Simple Query Protocol modunda parametreli sorguları desteklemez.
    // - LotPOS ise neredeyse tüm modüllerde `Sql.named(..., parameters: ...)` kullanır.
    //
    // Bu yüzden "pooler/transaction" gibi ortamlarda otomatik SIMPLE'a düşmek,
    // uygulamayı runtime'da kırar.
    //
    // Pooler transaction modunda (Supabase 6543 vb.) prepared statement'lar kapalı olabilir;
    // bu durumda çözüm: session pooler veya direct endpoint kullanmak + EXTENDED.
    //
    // İhtiyaç olursa kullanıcı `PATISYO_DB_QUERY_MODE` ile manuel olarak override edebilir.
    return QueryMode.extended;
  }

  /// Maksimum Bağlantı Sayısı (Connection Pool)
  int get maxConnections {
    if (kIsWeb) return _defaultMaxConnections;
    final connStr = Platform.environment[_maxConnectionsKey];
    final int defaultRequested = _connectionMode == 'cloud'
        ? _defaultMaxConnectionsCloud
        : _defaultMaxConnections;
    final int requested = (connStr != null && connStr.trim().isNotEmpty)
        ? (int.tryParse(connStr.trim()) ?? defaultRequested)
        : defaultRequested;

    // Mobilde havuzu küçük tut ama arama/listede paralel okuma boğulmasın.
    if (Platform.isAndroid || Platform.isIOS) {
      final int mobileCap = _connectionMode == 'cloud' ? 4 : 6;
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
    final cleanedLines = rawContent.split('\n').where((line) {
      final trimmedLeft = line.trimLeft();

      // psql meta-komutları (SQL motorunda syntax error verir)
      if (trimmedLeft.startsWith('\\')) return false;

      // PostgreSQL 17+ pg_dump çıktısı: `SET transaction_timeout = 0;`
      // Managed DB'lerde (Supabase/Neon) farklı sürümde syntax hatası
      // verebildiği için kaldırıyoruz.
      final lowered = trimmedLeft.toLowerCase();
      if (lowered.startsWith('set transaction_timeout')) return false;

      return true;
    }).toList();

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
        public.sync_tombstones.pk = EXCLUDED.pk;

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
  -- [2026 GOOGLE-SEARCH] External search index consumer state
  search_acked_at TIMESTAMPTZ,
  search_retry_count INTEGER NOT NULL DEFAULT 0,
  search_last_error TEXT,
  search_dead BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (table_name, pk_hash)
);
CREATE INDEX IF NOT EXISTS idx_sync_delta_outbox_touched_at
  ON public.sync_delta_outbox (touched_at);
CREATE INDEX IF NOT EXISTS idx_sync_delta_outbox_acked_at
  ON public.sync_delta_outbox (acked_at);
CREATE INDEX IF NOT EXISTS idx_sync_delta_outbox_search_acked_at
  ON public.sync_delta_outbox (search_acked_at);

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
    dead,
    search_acked_at,
    search_retry_count,
    search_last_error,
    search_dead
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
    false,
    NULL,
    0,
    NULL,
    false
  )
  ON CONFLICT (table_name, pk_hash) DO UPDATE
    SET public.sync_delta_outbox.pk = EXCLUDED.pk,
        action = EXCLUDED.action,
        touched_at = EXCLUDED.touched_at,
        acked_at = NULL,
        retry_count = 0,
        last_error = NULL,
        dead = false,
        search_acked_at = NULL,
        search_retry_count = 0,
        search_last_error = NULL,
        search_dead = false;

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
    _discoveredHost = _temizHost(newHost);
    debugPrint('VeritabaniYapilandirma: Host güncellendi -> $_discoveredHost');
  }

  static String? _temizHost(String? host) {
    final trimmed = host?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final noTrailingDot = trimmed.endsWith('.')
        ? trimmed.substring(0, trimmed.length - 1).trim()
        : trimmed;
    return noTrailingDot.isEmpty ? null : noTrailingDot;
  }

  static bool _isIpv4Literal(String value) {
    final parts = value.trim().split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  static Future<String?> _normalizeDiscoveredHostBestEffort(String? host) async {
    final cleaned = _temizHost(host);
    if (cleaned == null) return null;
    if (yerelAnaSunucuHostMu(cleaned) || _isIpv4Literal(cleaned)) {
      return cleaned;
    }

    try {
      final lookedUp = await InternetAddress.lookup(
        cleaned,
        type: InternetAddressType.IPv4,
      ).timeout(const Duration(milliseconds: 1200));
      for (final address in lookedUp) {
        final ip = _temizHost(address.address);
        if (ip != null && _isIpv4Literal(ip)) {
          return ip;
        }
      }
    } catch (_) {}

    try {
      final lookedUp = await InternetAddress.lookup(
        cleaned,
      ).timeout(const Duration(milliseconds: 1200));
      for (final address in lookedUp) {
        final ip = _temizHost(address.address);
        if (ip != null && _isIpv4Literal(ip)) {
          return ip;
        }
      }
    } catch (_) {}

    return cleaned;
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
    if (cloudAccessReady && _desktopCloudConnectionReady) {
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

      if (creds.isValidApi) {
        final baseUrl =
            (creds.apiWriteBaseUrl ??
                    creds.apiBaseUrl ??
                    creds.apiReadBaseUrl ??
                    '')
                .trim();
        await saveCloudApiCredentials(
          baseUrl: baseUrl,
          readBaseUrl: creds.apiReadBaseUrl,
          writeBaseUrl: creds.apiWriteBaseUrl,
          token: creds.apiToken!,
          database: creds.database,
        );
      }

      if (creds.isValidDb) {
        await saveCloudDatabaseCredentials(
          host: creds.host,
          port: creds.port,
          username: creds.username,
          password: creds.password,
          database: creds.database,
          sslRequired: creds.sslRequired,
        );
      }

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
    if (cloudApiCredentialsReady) {
      final rawUrl = (cloudApiWriteBaseUrl ?? '').trim();
      final rawToken = (cloudApiToken ?? '').trim();
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || rawToken.isEmpty) return false;
      final client = http.Client();
      try {
        final resp = await client
            .get(
              uri.resolve('healthz'),
              headers: <String, String>{
                HttpHeaders.authorizationHeader: 'Bearer $rawToken',
              },
            )
            .timeout(timeout);
        return resp.statusCode == 200;
      } catch (_) {
        return false;
      } finally {
        client.close();
      }
    }

    if (!cloudCredentialsReady) return false;

    final cfg = VeritabaniYapilandirma();
    Connection? conn;
    try {
      conn = await Connection.open(
        Endpoint(
          host: cfg.host,
          port: cfg.port,
          database: cfg.database,
          username: cfg.username,
          password: cfg.password,
        ),
        settings: ConnectionSettings(
          sslMode: cfg.sslMode,
          connectTimeout: timeout,
          queryMode: cfg.queryMode,
          onOpen: cfg.tuneConnection,
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
