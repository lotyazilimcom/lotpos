import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import '../sayfalar/ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../sayfalar/ayarlar/genel_ayarlar/modeller/doviz_kuru_model.dart';
import '../sayfalar/ayarlar/kullanicilar/modeller/kullanici_model.dart';
import '../sayfalar/ayarlar/kullanicilar/modeller/kullanici_hareket_model.dart';
import '../sayfalar/ayarlar/roller_ve_izinler/modeller/rol_model.dart';
import '../sayfalar/ayarlar/sirketayarlari/modeller/sirket_ayarlari_model.dart';
import '../ayarlar/menu_ayarlari.dart';
import 'bulut_sema_dogrulama_servisi.dart';
import 'veritabani_yapilandirma.dart';
import 'lisans_yazma_koruma.dart';

class AyarlarVeritabaniServisi {
  static final AyarlarVeritabaniServisi _instance =
      AyarlarVeritabaniServisi._internal();
  factory AyarlarVeritabaniServisi() => _instance;
  AyarlarVeritabaniServisi._internal();

  Pool? _pool;
  bool _isInitialized = false;
  bool _postgresqlBaslatildiMi = false;

  // Merkezi yapılandırma
  final VeritabaniYapilandirma _config = VeritabaniYapilandirma();

  bool _baslatiliyor = false;
  String? _sonHata;

  /// Veritabanı bağlantısı başarıyla kuruldu mu?
  bool get baslatildiMi => _isInitialized;

  /// Son hata mesajı (kullanıcıya gösterilecek)
  String? get sonHata => _sonHata;

  // Hızlandırma için önbellek (Static kalsın ki tüm lifecycle boyunca hatırlansın)
  static String? _cachedPgPath;
  static String? _cachedUnixPgBinDir;
  static String? _cachedDataDir;
  static String? _cachedServiceName;
  static bool _serviceNotFound = false;
  static bool? _isPortableMode;

  Future<void> baslat() async {
    if (_isInitialized) return;

    if (_baslatiliyor) {
      while (_baslatiliyor) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (_isInitialized) return;
      }
      return;
    }

    _baslatiliyor = true;
    _sonHata = null;

    try {
      // 1. Işık hızında kontrol: Veritabanı zaten ayaktaysa hiç servis işlerine girme
      if (_desktopPlatformMi() && _baglantiLocalMakineMi()) {
        final readyNow = await _postgresqlHazirMi();
        if (!readyNow) {
          debugPrint(
            'AyarlarVeritabaniServisi: PostgreSQL is not ready, initiating fast startup...',
          );
          await _postgresqlServisiniKontrolEtVeGerekirseBaslat();
        } else {
          _postgresqlBaslatildiMi = true;
        }
      }

      try {
        _pool = await _poolOlustur();
      } catch (e) {
        final isConnectionLimitError =
            e.toString().contains('53300') ||
            (e is ServerException && e.code == '53300');
        if (isConnectionLimitError) {
          await _acikBaglantilariKapat();
          _pool = await _poolOlustur();
        } else if (_desktopPlatformMi() && _baglantiLocalMakineMi()) {
          // Bağlantı reddedildiyse tekrar başlatmayı dene (force)
          await _postgresqlServisiniBaslat();
          _pool = await _poolOlustur();
        } else {
          rethrow;
        }
      }

      if (_pool == null) {
        _baslatiliyor = false;
        return;
      }

      final hazir = await _baglantiyiDogrulaVeGerekirseKur();
      if (!hazir) {
        debugPrint(
          'AyarlarVeritabaniServisi: Database connection could not be established.',
        );
        await baglantiyiKapat();
        _baslatiliyor = false;
        return;
      }

      final bulut = _bulutModundaMi();
      final semaHazir =
          bulut
              ? await BulutSemaDogrulamaServisi().bulutSemasiHazirMi(
                  executor: _pool!,
                  databaseName: _config.database,
                )
              : false;

      if (!semaHazir) {
        await _tablolariOlustur();
      } else {
        debugPrint(
          'AyarlarVeritabaniServisi: Bulut şema hazır, tablo kurulumu atlandı.',
        );
      }
      _isInitialized = true;

      // Varsayılan verileri ekle (Bu da önemli ama tablolar hazırsa uygulama açılabilir)
      try {
        await _varsayilanVerileriEkle();
      } catch (e) {
        debugPrint('AyarlarVeritabaniServisi: Default data seed error: $e');
      }

      debugPrint(
        'AyarlarVeritabaniServisi: Database connection and setup successful: ${_config.database}',
      );
    } catch (e) {
      _sonHata = 'Veritabanı başlatma hatası: $e';
      debugPrint('AyarlarVeritabaniServisi: CRITICAL STARTUP ERROR: $e');
    } finally {
      _baslatiliyor = false;
    }
  }

  Future<void> baglantiyiKapat() async {
    if (_pool != null) {
      await _pool!.close();
    }
    _pool = null;
    _isInitialized = false;
    _baslatiliyor = false;
  }

  Future<bool> _baglantiyiDogrulaVeGerekirseKur() async {
    if (_pool == null) return false;

    final bulut = _bulutModundaMi();
    final maxAttempt = bulut ? 2 : 3;

    for (var attempt = 1; attempt <= maxAttempt; attempt++) {
      try {
        await _pool!.execute('SELECT 1');
        return true;
      } catch (e) {
        final isConnectionLimitError =
            e.toString().contains('53300') ||
            (e is ServerException && e.code == '53300');

        final isConnectionRefused = e is SocketException;

        final isDatabaseMissing =
            e.toString().contains('3D000') ||
            (e is ServerException && e.code == '3D000');

        final isAuthError =
            e.toString().contains('28P01') ||
            (e is ServerException && e.code == '28P01');

        final isStartingUp =
            e.toString().contains('57P03') ||
            (e is ServerException && e.code == '57P03');

        debugPrint(
          'AyarlarVeritabaniServisi: DB test attempt $attempt failed: $e',
        );

        // ── Cloud (Supabase) modu: hızlı çıkış ──
        if (bulut) {
          if (isAuthError) {
            _sonHata =
                'Veritabanı şifresi yanlış. Admin panelden bağlantı dizesini kontrol edin.';
            debugPrint(
              'AyarlarVeritabaniServisi: Cloud auth error – credentials are wrong, aborting.',
            );
            return false;
          }
          if (isDatabaseMissing) {
            _sonHata =
                'Veritabanı bulunamadı. Admin panelden veritabanı adını kontrol edin.';
            debugPrint(
              'AyarlarVeritabaniServisi: Cloud database not found, aborting.',
            );
            return false;
          }
          if (isConnectionRefused) {
            debugPrint(
              'AyarlarVeritabaniServisi: Cloud connection refused, retrying...',
            );
            // Sunucu geçici olarak reddetti, pool yenile ve tekrar dene
          } else if (isConnectionLimitError) {
            // Bağlantı limiti aşıldı, kısa bekle
            await Future.delayed(const Duration(milliseconds: 500));
          } else {
            _sonHata =
                'Bulut sunucuya bağlanırken beklenmeyen bir hata oluştu: $e';
            debugPrint(
              'AyarlarVeritabaniServisi: Cloud unknown error, aborting.',
            );
            return false;
          }
        } else {
          // ── Lokal mod: mevcut davranış ──
          if (isConnectionLimitError) {
            await _acikBaglantilariKapat();
          } else if (isStartingUp) {
            await _postgresqlHazirOlanaKadarBekle(
              timeout: const Duration(seconds: 20),
              interval: const Duration(milliseconds: 250),
            );
          } else if (isConnectionRefused &&
              _desktopPlatformMi() &&
              _baglantiLocalMakineMi()) {
            final started = await _postgresqlServisiniBaslat();
            if (!started) return false;
            await _postgresqlHazirOlanaKadarBekle(
              timeout: const Duration(seconds: 20),
            );
          } else if (isDatabaseMissing || isAuthError) {
            final kurulumBasarili = await _baslangicKurulumuYap();
            if (!kurulumBasarili) return false;
          } else {
            if (attempt == 1) {
              final kurulumBasarili = await _baslangicKurulumuYap();
              if (!kurulumBasarili) return false;
            } else {
              return false;
            }
          }
        }

        try {
          await _pool?.close();
        } catch (_) {}

        _pool = await _poolOlustur();
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }
    return false;
  }

  Future<Pool> _poolOlustur() async {
    return LisansKorumaliPool(
      Pool.withEndpoints(
        [
          Endpoint(
            host: _config.host,
            port: _config.port,
            database: _config.database,
            username: _config.username,
            password: _config.password,
          ),
        ],
        settings: PoolSettings(
          sslMode: _config.sslMode,
          connectTimeout: _config.poolConnectTimeout,
          onOpen: _config.tuneConnection,
          maxConnectionCount: _config.maxConnections,
        ),
      ),
    );
  }

  bool _desktopPlatformMi() {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  bool _baglantiLocalMakineMi() {
    if (kIsWeb) return false;
    final host = _config.host.trim().toLowerCase();
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  /// Cloud (Supabase) modunda mıyız?
  bool _bulutModundaMi() {
    return VeritabaniYapilandirma.connectionMode == 'cloud';
  }

  Future<void> _postgresqlServisiniKontrolEtVeGerekirseBaslat() async {
    if (_postgresqlBaslatildiMi) return;
    if (!_desktopPlatformMi() || !_baglantiLocalMakineMi()) return;

    // Port açık ama hazır değilse (starting up) sadece bekle.
    if (Platform.isWindows) {
      await _windowsPostgreSQLServisiniKontrolEt();
      return;
    }

    final portOpen = await _postgresqlPortAcikMi();
    if (portOpen) {
      _postgresqlBaslatildiMi = await _postgresqlHazirOlanaKadarBekle(
        timeout: const Duration(seconds: 20),
        interval: const Duration(milliseconds: 250),
      );
      return;
    }

    await _postgresqlServisiniBaslat();
  }

  Future<bool> _postgresqlServisiniBaslat() async {
    if (_postgresqlBaslatildiMi) return true;
    if (!_desktopPlatformMi() || !_baglantiLocalMakineMi()) return false;

    if (Platform.isWindows) {
      return await _windowsPostgreSQLServisiniBaslat();
    }

    if (Platform.isMacOS || Platform.isLinux) {
      return await _unixPostgreSQLServisiniBaslat();
    }

    return false;
  }

  Future<bool> _unixPostgreSQLServisiniBaslat() async {
    // Unix'te sistem servislerine dokunmadan user-level pg_ctl ile başlatıyoruz.
    _isPortableMode = true;
    final started = await _pgCtlIleBaslatUnix();
    _postgresqlBaslatildiMi = started;
    return started;
  }

  Future<void> _windowsPostgreSQLServisiniKontrolEt() async {
    if (_postgresqlBaslatildiMi) return;

    // Önce en hızlı socket kontrolü
    if (await _postgresqlHazirMi()) {
      _postgresqlBaslatildiMi = true;
      return;
    }

    // Hazır değilse başlatmayı dene
    await _windowsPostgreSQLServisiniBaslat();
  }

  /// PostgreSQL'in bağlantı kabul edip etmediğini kontrol eder
  Future<bool> _postgresqlPortAcikMi({
    Duration timeout = const Duration(milliseconds: 100),
  }) async {
    try {
      final socket = await Socket.connect(
        _config.host,
        _config.port,
        timeout: timeout,
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _postgresqlHazirMi() async {
    // 1. En Hızlı: TCP Port Kontrolü
    final portOpen = await _postgresqlPortAcikMi();
    if (!portOpen) return false;

    // 2. Yedek: pg_isready (Eğer yol biliniyorsa veya socket check bir şekilde yanıltıcıysa)
    final args = ['-h', _config.host, '-p', _config.port.toString(), '-t', '1'];

    if (!Platform.isWindows) {
      final sep = Platform.pathSeparator;
      String cmd = 'pg_isready';
      final cachedBinDir = _cachedUnixPgBinDir;
      if (cachedBinDir != null) {
        final candidate = '$cachedBinDir${sep}pg_isready';
        if (await File(candidate).exists()) {
          cmd = candidate;
        }
      }

      try {
        final result = await Process.run(cmd, args);
        return result.exitCode == 0;
      } on ProcessException {
        // If pg_isready isn't available, treat open port as "ready" on Unix.
        return true;
      } catch (_) {
        return true;
      }
    }

    try {
      String? pgPath = _cachedPgPath;
      if (pgPath == null) {
        // Hızlıca yaygın yolları tara
        final versions = ['18', '17', '16', '15', '14'];
        for (final v in versions) {
          final path = 'C:\\Program Files\\PostgreSQL\\$v';
          if (await File('$path\\bin\\pg_isready.exe').exists()) {
            pgPath = path;
            _cachedPgPath = path;
            break;
          }
        }
      }

      if (pgPath != null) {
        final result = await Process.run('$pgPath\\bin\\pg_isready.exe', args);
        return result.exitCode == 0;
      }
    } catch (_) {}

    return false;
  }

  Future<bool> _windowsPostgreSQLServisiniBaslat() async {
    if (_postgresqlBaslatildiMi) return true;

    // Eğer zaten taşınabilir (portable) modda olduğumuzu biliyorsak direkt pg_ctl'e git
    if (_isPortableMode == true) {
      return await _pgCtlIleBaslat();
    }

    // 1. Servis Adı Önbelleği
    if (!_serviceNotFound) {
      String? serviceName = _cachedServiceName;
      if (serviceName == null) {
        try {
          // PowerShell yerine hızlı CMD sorgusu
          final result = await Process.run('cmd', [
            '/c',
            'sc query type= service | findstr /i "postgresql"',
          ]);
          final found = result.stdout.toString().trim();
          if (found.isNotEmpty) {
            // Örnek: SERVICE_NAME: postgresql-x64-17
            final match = RegExp(r'SERVICE_NAME: ([\w\-.]+)').firstMatch(found);
            serviceName = match?.group(1) ?? 'postgresql-x64-18';
            _cachedServiceName = serviceName;
          } else {
            _serviceNotFound = true;
          }
        } catch (_) {
          _serviceNotFound = true;
        }
      }

      if (serviceName != null) {
        debugPrint(
          'AyarlarVeritabaniServisi: Starting service $serviceName...',
        );
        // net start, SC'den daha kullanıcı dostudur ve UAC izinlerine daha az takılır
        final startRes = await Process.run('net', ['start', serviceName]);
        if (startRes.exitCode == 0 ||
            startRes.stdout.toString().contains('already started')) {
          _postgresqlBaslatildiMi = await _postgresqlHazirOlanaKadarBekle(
            timeout: const Duration(seconds: 5),
          );
          if (_postgresqlBaslatildiMi) return true;
        }
      }
    }

    // 2. Servis Yoksa veya Başlatılamadıysa: pg_ctl (Portable Mode)
    return await _pgCtlIleBaslat();
  }

  /// pg_ctl komutu ile PostgreSQL'i başlatır
  /// PostgreSQL ready olana kadar bekler
  Future<bool> _postgresqlHazirOlanaKadarBekle({
    Duration timeout = const Duration(seconds: 15),
    Duration interval = const Duration(milliseconds: 500),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final ready = await _postgresqlHazirMi();
      if (ready) return true;
      await Future.delayed(interval);
    }
    return await _postgresqlHazirMi();
  }

  Future<bool> _postgresqlDataDiziniBaslatmaKurulumu({
    required String pgPath,
    required String dataDir,
  }) async {
    try {
      await Directory(dataDir).create(recursive: true);

      final pgVersion = File('$dataDir\\PG_VERSION');
      if (await pgVersion.exists()) {
        return true;
      }

      final initdb = '$pgPath\\bin\\initdb.exe';
      if (!await File(initdb).exists()) {
        debugPrint('AyarlarVeritabaniServisi: initdb.exe not found: $initdb');
        return false;
      }

      final temp = await Directory.systemTemp.createTemp('patisyov_pg_');
      final pwFile = File('${temp.path}\\pg_pw.txt');

      // Local development kolayligi: setup icin admin sifresi.
      const superuserPassword = 'postgres';

      try {
        await pwFile.writeAsString(superuserPassword);

        debugPrint(
          'AyarlarVeritabaniServisi: Initializing PostgreSQL data directory (initdb)...',
        );

        final result = await Process.run(initdb, [
          '-D',
          dataDir,
          '-U',
          'postgres',
          '--encoding=UTF8',
          '--auth=md5',
          '--pwfile',
          pwFile.path,
          '--no-locale',
        ]);

        if (result.exitCode != 0) {
          debugPrint(
            'AyarlarVeritabaniServisi: initdb failed (exit ${result.exitCode}).\nstdout: ${result.stdout}\nstderr: ${result.stderr}',
          );
          return false;
        }
      } finally {
        try {
          await temp.delete(recursive: true);
        } catch (_) {}
      }

      await _postgresqlConfGuncelle(dataDir: dataDir);
      return true;
    } catch (e) {
      debugPrint('AyarlarVeritabaniServisi: Error during data dir init: $e');
      return false;
    }
  }

  Future<void> _postgresqlConfGuncelle({required String dataDir}) async {
    try {
      final sep = Platform.pathSeparator;
      final conf = File('$dataDir${sep}postgresql.conf');
      if (!await conf.exists()) return;

      const marker = '# patisyov10 auto-config';

      final content = await conf.readAsString();
      final lines = content.split(RegExp(r'\r?\n')).toList();

      final markerIndex = lines.indexWhere((l) => l.trim() == marker);
      if (markerIndex == -1) {
        lines
          ..add('')
          ..add(marker)
          ..add("listen_addresses = '127.0.0.1'")
          ..add('port = ${_config.port}');
      } else {
        var end = markerIndex + 1;
        while (end < lines.length && lines[end].trim().isNotEmpty) {
          end++;
        }

        lines.removeRange(markerIndex + 1, end);
        lines.insert(markerIndex + 1, "listen_addresses = '127.0.0.1'");
        lines.insert(markerIndex + 2, 'port = ${_config.port}');
      }

      await conf.writeAsString(lines.join('\n'), flush: true);
    } catch (e) {
      debugPrint(
        'AyarlarVeritabaniServisi: postgresql.conf update warning: $e',
      );
    }
  }

  String _postgresqlUygulamaDataDizini() {
    if (kIsWeb) return '';
    final env = Platform.environment;
    final baseDir =
        env['LOCALAPPDATA'] ??
        env['APPDATA'] ??
        env['USERPROFILE'] ??
        env['HOME'] ??
        Directory.systemTemp.path;

    final sep = Platform.pathSeparator;
    return '$baseDir${sep}patisyov10${sep}postgresql${sep}data';
  }

  Future<String> _postgresqlDataDiziniSec(String pgPath) async {
    final standardDataDir = '$pgPath\\data';
    final appDataDir = _postgresqlUygulamaDataDizini();
    final sep = Platform.pathSeparator;

    if (await File('$standardDataDir${sep}PG_VERSION').exists()) {
      return standardDataDir;
    }
    if (await File('$appDataDir${sep}PG_VERSION').exists()) return appDataDir;

    return appDataDir;
  }

  Future<String?> _unixPgBinDiziniBul() async {
    if (kIsWeb) return null;

    final sep = Platform.pathSeparator;
    final cached = _cachedUnixPgBinDir;
    if (cached != null && cached.trim().isNotEmpty) {
      final pgCtl = '$cached${sep}pg_ctl';
      if (await File(pgCtl).exists()) return cached;
    }

    // 1) PATH (which pg_ctl)
    try {
      final which = await Process.run('which', ['pg_ctl']);
      if (which.exitCode == 0) {
        final out = which.stdout.toString().trim();
        if (out.isNotEmpty) {
          final first = out.split(RegExp(r'\r?\n')).first.trim();
          if (first.isNotEmpty) {
            final dir = File(first).parent.path;
            final pgCtl = '$dir${sep}pg_ctl';
            if (await File(pgCtl).exists()) {
              _cachedUnixPgBinDir = dir;
              return dir;
            }
          }
        }
      }
    } catch (_) {}

    // 2) Common locations
    final versions = ['18', '17', '16', '15', '14', '13', '12'];
    final candidates = <String>[
      '/usr/local/bin',
      '/usr/bin',
      '/bin',
      '/usr/sbin',
      '/sbin',
      '/Applications/Postgres.app/Contents/Versions/latest/bin',
      // EDB (EnterpriseDB) installer default path (macOS): /Library/PostgreSQL/<ver>/bin
      for (final v in versions) '/Library/PostgreSQL/$v/bin',
      for (final v in versions) ...[
        '/usr/lib/postgresql/$v/bin',
        '/usr/pgsql-$v/bin',
        '/opt/homebrew/opt/postgresql@$v/bin',
        '/usr/local/opt/postgresql@$v/bin',
      ],
      '/opt/homebrew/opt/postgresql/bin',
      '/usr/local/opt/postgresql/bin',
    ];

    for (final dir in candidates) {
      final pgCtl = '$dir${sep}pg_ctl';
      if (await File(pgCtl).exists()) {
        _cachedUnixPgBinDir = dir;
        return dir;
      }
    }

    return null;
  }

  Future<bool> _postgresqlDataDiziniBaslatmaKurulumuUnix({
    required String binDir,
    required String dataDir,
  }) async {
    try {
      final sep = Platform.pathSeparator;
      await Directory(dataDir).create(recursive: true);

      final pgVersion = File('$dataDir${sep}PG_VERSION');
      if (await pgVersion.exists()) {
        return true;
      }

      final initdbCandidate = '$binDir${sep}initdb';
      final initdb = (await File(initdbCandidate).exists())
          ? initdbCandidate
          : 'initdb';

      final temp = await Directory.systemTemp.createTemp('patisyov_pg_');
      final pwFile = File('${temp.path}${sep}pg_pw.txt');

      // Local development kolayligi: setup icin admin sifresi.
      const superuserPassword = 'postgres';

      try {
        await pwFile.writeAsString(superuserPassword);

        debugPrint(
          'AyarlarVeritabaniServisi: Initializing PostgreSQL data directory (initdb)...',
        );

        final result = await Process.run(initdb, [
          '-D',
          dataDir,
          '-U',
          'postgres',
          '--encoding=UTF8',
          '--auth=md5',
          '--pwfile',
          pwFile.path,
          '--no-locale',
        ]);

        if (result.exitCode != 0) {
          debugPrint(
            'AyarlarVeritabaniServisi: initdb failed (exit ${result.exitCode}).\nstdout: ${result.stdout}\nstderr: ${result.stderr}',
          );
          return false;
        }
      } finally {
        try {
          await temp.delete(recursive: true);
        } catch (_) {}
      }

      await _postgresqlConfGuncelle(dataDir: dataDir);
      return true;
    } catch (e) {
      debugPrint('AyarlarVeritabaniServisi: Error during data dir init: $e');
      return false;
    }
  }

  Future<bool> _pgCtlIleBaslatUnix() async {
    try {
      final sep = Platform.pathSeparator;

      final binDir = await _unixPgBinDiziniBul();
      if (binDir == null) {
        debugPrint('AyarlarVeritabaniServisi: pg_ctl not found (Unix/macOS).');
        return false;
      }

      if (await _postgresqlHazirMi()) {
        _postgresqlBaslatildiMi = true;
        return true;
      }

      String? dataDir = _cachedDataDir;
      if (dataDir == null || dataDir.trim().isEmpty) {
        dataDir = _postgresqlUygulamaDataDizini();
        _cachedDataDir = dataDir;
      }

      final initOk = await _postgresqlDataDiziniBaslatmaKurulumuUnix(
        binDir: binDir,
        dataDir: dataDir,
      );
      if (!initOk) return false;

      final pgCtlCandidate = '$binDir${sep}pg_ctl';
      final pgCtl = (await File(pgCtlCandidate).exists())
          ? pgCtlCandidate
          : 'pg_ctl';
      final logFile = '${Directory.systemTemp.path}${sep}pg_startup.log';

      _isPortableMode = true;

      debugPrint(
        'AyarlarVeritabaniServisi: Launching pg_ctl (Unix) in background...',
      );

      final process = await Process.start(pgCtl, [
        'start',
        '-D',
        dataDir,
        '-l',
        logFile,
        '-o',
        '-p ${_config.port} -h 127.0.0.1',
      ]);

      await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () => 0,
      );

      _postgresqlBaslatildiMi = await _postgresqlHazirOlanaKadarBekle(
        timeout: const Duration(seconds: 10),
        interval: const Duration(milliseconds: 200),
      );

      return _postgresqlBaslatildiMi;
    } catch (e) {
      debugPrint(
        'AyarlarVeritabaniServisi: Error starting PostgreSQL with pg_ctl (Unix): $e',
      );
      return false;
    }
  }

  Future<bool> _pgCtlIleBaslat() async {
    try {
      // 1. Hızlı Yol Tespiti
      String? pgPath = _cachedPgPath;
      if (pgPath == null) {
        final possiblePaths = [
          'C:\\Program Files\\PostgreSQL\\18',
          'C:\\Program Files\\PostgreSQL\\17',
          'C:\\Program Files\\PostgreSQL\\16',
          'C:\\Program Files\\PostgreSQL\\15',
          'C:\\Program Files\\PostgreSQL\\14',
          'C:\\Program Files (x86)\\PostgreSQL\\17',
        ];

        for (final path in possiblePaths) {
          if (await File('$path\\bin\\pg_ctl.exe').exists()) {
            pgPath = path;
            _cachedPgPath = path;
            break;
          }
        }
      }

      if (pgPath == null) {
        debugPrint('AyarlarVeritabaniServisi: PostgreSQL bin path not found.');
        return false;
      }

      // 2. Data Dizini Tespiti
      String? dataDir = _cachedDataDir;
      if (dataDir == null) {
        dataDir = await _postgresqlDataDiziniSec(pgPath);
        _cachedDataDir = dataDir;
      }

      // 3. Durum Kontrolü (Hızlı)
      if (await _postgresqlHazirMi()) {
        _postgresqlBaslatildiMi = true;
        return true;
      }

      // 4. Veri Dizini Hazırlığı (Opsiyonel)
      await _postgresqlDataDiziniBaslatmaKurulumu(
        pgPath: pgPath,
        dataDir: dataDir,
      );

      // 5. Arka Planda Başlat (IŞIK HIZINDA)
      final pgCtl = '$pgPath\\bin\\pg_ctl.exe';
      final tempDir = Platform.environment['TEMP'] ?? 'C:\\Windows\\Temp';
      final logFile = '$tempDir\\pg_startup.log';

      _isPortableMode = true; // Portable modda çalıştığımızı işaretle

      debugPrint('AyarlarVeritabaniServisi: Launching pg_ctl in background...');

      // Process.run yerine Process.start kullanarak kilitlemeyi önlüyoruz
      final process = await Process.start(pgCtl, [
        'start',
        '-D',
        dataDir,
        '-l',
        logFile,
        '-o',
        '-p ${_config.port} -h 127.0.0.1',
      ]);

      // Çıkışını beklemiyoruz ama logları bir süre takip etmek istersen process handle elimizde
      await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () => 0,
      );

      // 6. Polling (Hızlı bir döngüyle hazır olmasını bekle)
      _postgresqlBaslatildiMi = await _postgresqlHazirOlanaKadarBekle(
        timeout: const Duration(seconds: 10),
        interval: const Duration(milliseconds: 200),
      );

      return _postgresqlBaslatildiMi;
    } catch (e) {
      debugPrint(
        'AyarlarVeritabaniServisi: Error starting PostgreSQL with pg_ctl: $e',
      );
      return false;
    }
  }

  Future<Connection?> _yoneticiBaglantisiAl() async {
    final Map<String, String> env = kIsWeb ? {} : Platform.environment;
    final bool isLocalDesktop = _desktopPlatformMi() && _baglantiLocalMakineMi();

    final List<String> olasiKullanicilar = <String>[];
    final Set<String> seenUsers = <String>{};
    void addUser(String? value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return;
      if (seenUsers.add(v)) olasiKullanicilar.add(v);
    }

    // EDB / standart kurulumlarda superuser genelde `postgres` olur.
    addUser('postgres');

    // Windows'ta genellikle USER yerine USERNAME set edilir.
    addUser(env['USER']);
    addUser(env['USERNAME']);

    final List<String> olasiSifreler = <String>[];
    final Set<String> seenPass = <String>{};
    void addPass(String value) {
      if (seenPass.add(value)) olasiSifreler.add(value);
    }

    // En olası: Projenin beklediği şifre (örn. yerel kurulum scriptleri ile aynı).
    final configPass = _config.password;
    if (configPass.trim().isNotEmpty) addPass(configPass);

    // Bazı local kurulumlar "trust/peer" olabilir.
    addPass('');

    // Fallback denemeler (legacy/dev).
    addPass('postgres');
    addPass('password');
    addPass('123456');
    addPass('admin');
    addPass('root');

    final adminSettings = ConnectionSettings(
      sslMode: _config.sslMode,
      // Desktop-local kurulumlarda hızlı fail/success için kısa timeout.
      connectTimeout:
          isLocalDesktop ? const Duration(milliseconds: 800) : null,
    );

    for (final user in olasiKullanicilar) {
      for (final sifre in olasiSifreler) {
        try {
          final conn = await Connection.open(
            Endpoint(
              host: _config.host,
              port: _config.port,
              database: 'postgres',
              username: user,
              password: sifre,
            ),
            settings: adminSettings,
          );
          debugPrint(
            'AyarlarVeritabaniServisi: Admin connection established: $user',
          );
          return conn;
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  Future<void> _acikBaglantilariKapat() async {
    final adminConn = await _yoneticiBaglantisiAl();
    if (adminConn != null) {
      try {
        await adminConn.execute(
          "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = '${_config.username}' AND pid <> pg_backend_pid()",
        );
        debugPrint(
          'AyarlarVeritabaniServisi: User ${_config.username} connections terminated.',
        );
      } catch (e) {
        debugPrint(
          'AyarlarVeritabaniServisi: Connection termination error: $e',
        );
      } finally {
        await adminConn.close();
      }
    } else {
      debugPrint(
        'AyarlarVeritabaniServisi: Could not get admin connection, cannot clean up connections.',
      );
    }
  }

  Future<bool> _baslangicKurulumuYap() async {
    final adminConnection = await _yoneticiBaglantisiAl();

    if (adminConnection == null) {
      debugPrint(
        'AyarlarVeritabaniServisi: No admin account available for setup.',
      );
      return false;
    }

    try {
      try {
        await adminConnection.execute(
          "CREATE USER ${_config.username} WITH PASSWORD '${_config.password}' CREATEDB",
        );
        debugPrint(
          'AyarlarVeritabaniServisi: User created: ${_config.username}',
        );
      } catch (e) {
        if (e is ServerException && e.code == '42710') {
          debugPrint(
            'AyarlarVeritabaniServisi: User already exists. Verifying password...',
          );
          try {
            await adminConnection.execute(
              "ALTER USER ${_config.username} WITH PASSWORD '${_config.password}'",
            );
          } catch (alterE) {
            debugPrint(
              'AyarlarVeritabaniServisi: User password update error: $alterE',
            );
          }
        } else {
          debugPrint('AyarlarVeritabaniServisi: User creation warning: $e');
        }
      }

      try {
        await adminConnection.execute(
          'CREATE DATABASE "${_config.database}" OWNER "${_config.username}"',
        );
        debugPrint(
          'AyarlarVeritabaniServisi: Database created: ${_config.database}',
        );
      } catch (e) {
        if (e is ServerException && e.code == '42P04') {
          debugPrint('AyarlarVeritabaniServisi: Database already exists.');
        } else {
          debugPrint('AyarlarVeritabaniServisi: Database creation warning: $e');
        }
      }

      try {
        await adminConnection.execute(
          'GRANT ALL PRIVILEGES ON DATABASE "${_config.database}" TO "${_config.username}"',
        );
      } catch (e) {
        debugPrint('AyarlarVeritabaniServisi: Authorization warning: $e');
      }

      return true;
    } catch (e) {
      debugPrint('AyarlarVeritabaniServisi: Setup general error: $e');
      return false;
    } finally {
      await adminConnection.close();
    }
  }

  Future<void> _tablolariOlustur() async {
    if (_pool == null) return;

    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS public.general_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT,
        name TEXT,
        surname TEXT,
        email TEXT,
        role TEXT,
        is_active INTEGER,
        phone TEXT,
        profile_image TEXT,
        password TEXT,
        hire_date TEXT,
        position TEXT,
        salary REAL,
        salary_currency TEXT,
        address TEXT,
        info1 TEXT,
        info2 TEXT
      )
    ''');

    // Mevcut tabloya yeni sütunları ekle (migration)
    try {
      await _pool!.execute(
        'ALTER TABLE users ADD COLUMN IF NOT EXISTS hire_date TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE users ADD COLUMN IF NOT EXISTS position TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE users ADD COLUMN IF NOT EXISTS salary REAL',
      );
      await _pool!.execute(
        'ALTER TABLE users ADD COLUMN IF NOT EXISTS salary_currency TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE users ADD COLUMN IF NOT EXISTS address TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE users ADD COLUMN IF NOT EXISTS info1 TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE users ADD COLUMN IF NOT EXISTS info2 TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE users ADD COLUMN IF NOT EXISTS balance_debt REAL DEFAULT 0',
      );
      await _pool!.execute(
        'ALTER TABLE users ADD COLUMN IF NOT EXISTS balance_credit REAL DEFAULT 0',
      );
    } catch (e) {
      debugPrint(
        'Users tablosu migration hatası (muhtemelen sütunlar zaten mevcut): $e',
      );
    }

    // Kullanıcı hareketleri (Personel modülü ile aynı kanonik şema)
    // Not: Local modda bu DB "settings" DB olduğu için tablo küçük kalır,
    // Cloud modda ise tek DB kullanıldığı için bu şema uyumu kritik.
    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS user_transactions (
        id TEXT,
        company_id TEXT,
        user_id TEXT,
        date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        description TEXT,
        debt NUMERIC(15, 2) DEFAULT 0,
        credit NUMERIC(15, 2) DEFAULT 0,
        type TEXT,
        PRIMARY KEY (id, date)
      ) PARTITION BY RANGE (date)
    ''');

    // Migration: Eski tablolarda company_id yoksa ekle (Cloud/Local uyumu)
    try {
      await _pool!.execute(
        'ALTER TABLE user_transactions ADD COLUMN IF NOT EXISTS company_id TEXT',
      );
    } catch (_) {}

    // Default partition (ilk kurulumda insert hatası olmasın)
    try {
      await _pool!.execute('''
        CREATE TABLE IF NOT EXISTS user_transactions_default
        PARTITION OF user_transactions DEFAULT
      ''');
    } catch (_) {}

    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS roles (
        id TEXT PRIMARY KEY,
        name TEXT,
        permissions TEXT,
        is_system INTEGER,
        is_active INTEGER
      )
    ''');

    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS company_settings (
        id SERIAL PRIMARY KEY,
        kod TEXT,
        ad TEXT,
        basliklar TEXT,
        logolar TEXT,
        adres TEXT,
        vergi_dairesi TEXT,
        vergi_no TEXT,
        telefon TEXT,
        eposta TEXT,
        web_adresi TEXT,
        aktif_mi INTEGER,
        varsayilan_mi INTEGER,
        duzenlenebilir_mi INTEGER,
        ust_bilgi_logosu TEXT,
        ust_bilgi_satirlari TEXT
      )
    ''');

    // Migration: company_settings ekstra alanlar (yazdırma için)
    try {
      await _pool!.execute(
        'ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS adres TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS vergi_dairesi TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS vergi_no TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS telefon TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS eposta TEXT',
      );
      await _pool!.execute(
        'ALTER TABLE company_settings ADD COLUMN IF NOT EXISTS web_adresi TEXT',
      );
    } catch (_) {}

    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS saved_descriptions (
        id SERIAL PRIMARY KEY,
        category TEXT NOT NULL,
        content TEXT NOT NULL,
        usage_count INTEGER DEFAULT 1,
        last_used TEXT,
        CONSTRAINT unique_category_content UNIQUE (category, content)
      )
    ''');

    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS hidden_descriptions (
        category TEXT NOT NULL,
        content TEXT NOT NULL,
        PRIMARY KEY (category, content)
      )
    ''');

    // Index for performance with large datasets
    await _pool!.execute(
      'CREATE INDEX IF NOT EXISTS idx_saved_descriptions_search ON saved_descriptions (category, content)',
    );

    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS currency_rates (
        id SERIAL PRIMARY KEY,
        from_code TEXT,
        to_code TEXT,
        rate REAL,
        update_time TEXT
      )
    ''');

    await _pool!.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_currency_rates_pair ON currency_rates (from_code, to_code)',
    );

    // [2025 ELITE] get_professional_label SQL Helper Function
    // Global yardımcı fonksiyon (Arama etiketleri için)
    await _pool!.execute('''
      CREATE OR REPLACE FUNCTION get_professional_label(raw_type TEXT, context TEXT DEFAULT '') RETURNS TEXT AS \$\$
      DECLARE
          t TEXT := LOWER(TRIM(raw_type));
          ctx TEXT := LOWER(TRIM(context));
      BEGIN
          IF raw_type IS NULL OR raw_type = '' THEN
              RETURN 'İşlem';
          END IF;

          -- KASA
          IF ctx = 'cash' OR ctx = 'kasa' THEN
              IF t ~ 'tahsilat' OR t ~ 'giriş' OR t ~ 'giris' THEN RETURN 'Kasa Tahsilat';
              ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'çıkış' OR t ~ 'cikis' THEN RETURN 'Kasa Ödeme';
              END IF;
          END IF;

          -- BANKA / POS / CC
          IF ctx = 'bank' OR ctx = 'banka' OR ctx = 'bank_pos' OR ctx = 'cc' OR ctx = 'credit_card' THEN
              IF t ~ 'tahsilat' OR t ~ 'giriş' OR t ~ 'giris' OR t ~ 'havale' OR t ~ 'eft' THEN RETURN 'Banka Tahsilat';
              ELSIF t ~ 'ödeme' OR t ~ 'odeme' OR t ~ 'çıkış' OR t ~ 'cikis' OR t ~ 'harcama' THEN RETURN 'Banka Ödeme';
              ELSIF t ~ 'transfer' THEN RETURN 'Banka Transfer';
              END IF;
          END IF;

          -- CARİ
          IF ctx = 'current_account' OR ctx = 'cari' THEN
              IF t = 'borç' OR t = 'borc' THEN RETURN 'Cari Borç';
              ELSIF t = 'alacak' THEN RETURN 'Cari Alacak';
              ELSIF t ~ 'tahsilat' THEN RETURN 'Cari Tahsilat';
              ELSIF t ~ 'ödeme' OR t ~ 'odeme' THEN RETURN 'Cari Ödeme';
              ELSIF t ~ 'borç dekontu' OR t ~ 'borc dekontu' THEN RETURN 'Borç Dekontu';
              ELSIF t ~ 'alacak dekontu' THEN RETURN 'Alacak Dekontu';
              ELSIF t = 'satış yapıldı' OR t = 'satis yapildi' THEN RETURN 'Satış Yapıldı';
              ELSIF t = 'alış yapıldı' OR t = 'alis yapildi' THEN RETURN 'Alış Yapıldı';
              ELSIF t ~ 'satış' OR t ~ 'satis' THEN RETURN 'Satış Faturası';
              ELSIF t ~ 'alış' OR t ~ 'alis' THEN RETURN 'Alış Faturası';
              END IF;
          END IF;

          -- STOK
          IF ctx = 'stock' OR ctx = 'stok' THEN
              IF t ~ 'açılış' OR t ~ 'acilis' THEN RETURN 'Açılış Stoğu';
              ELSIF t ~ 'devir' AND t ~ 'gir' THEN RETURN 'Devir Giriş';
              ELSIF t ~ 'devir' AND t ~ 'çık' THEN RETURN 'Devir Çıkış';
              ELSIF t ~ 'üretim' OR t ~ 'uretim' THEN RETURN 'Üretim';
              ELSIF t ~ 'satış' OR t ~ 'satis' THEN RETURN 'Satış';
              ELSIF t ~ 'alış' OR t ~ 'alis' THEN RETURN 'Alış';
              END IF;
          END IF;

          RETURN raw_type;
      END;
      \$\$ LANGUAGE plpgsql;
    ''');

    // [2025 HYPERSCALE] Otomatik Temizlik ve Cold Storage (Arşivleme) Prosedürü
    await _pool!.execute('''
      CREATE OR REPLACE PROCEDURE archive_old_data(p_cutoff_year INTEGER)
      LANGUAGE plpgsql
      AS \$\$
      DECLARE
          row RECORD;
      BEGIN
          -- 1. Arşiv şemasını garantiye al
          CREATE SCHEMA IF NOT EXISTS archive;

          -- 2. Belirtilen yıldan önceki tüm bölümleri (partition) bul
          FOR row IN 
              SELECT nmsp_parent.nspname AS parent_schema,
                     parent.relname      AS parent_table,
                     nmsp_child.nspname  AS child_schema,
                     child.relname       AS child_table,
                     (SUBSTRING(child.relname FROM '_([0-9]{4})\$'))::INTEGER AS part_year
              FROM pg_inherits
              JOIN pg_class parent            ON pg_inherits.inhparent = parent.oid
              JOIN pg_class child             ON pg_inherits.inhrelid  = child.oid
              JOIN pg_namespace nmsp_parent   ON nmsp_parent.oid  = parent.relnamespace
              JOIN pg_namespace nmsp_child    ON nmsp_child.oid   = child.relnamespace
              WHERE nmsp_child.nspname = 'public'
                AND child.relname ~ '_[0-9]{4}\$'
          LOOP
              -- Sadece cutoff yilindan kucukleri arsivle
              IF row.part_year IS NOT NULL AND row.part_year < p_cutoff_year THEN
                  -- 3. Partition'ı ana tablodan ayır (DETACH)
                  EXECUTE format('ALTER TABLE %I.%I DETACH PARTITION %I.%I', 
                                 row.parent_schema, row.parent_table, 
                                 row.child_schema, row.child_table);
                  
                  -- 4. Ayrılan tabloyu 'archive' şemasına taşı (Cold Storage)
                  EXECUTE format('ALTER TABLE %I.%I SET SCHEMA archive', 
                                 row.child_schema, row.child_table);
                                 
                  RAISE NOTICE 'Bölüm arşivlendi: % (%) -> archive.% (Yıl: %)', 
                               row.child_table, row.parent_table, row.child_table, row.part_year;
              END IF;
          END LOOP;
      END;
      \$\$;
    ''');

    await _pool!.execute('''
      CREATE TABLE IF NOT EXISTS print_templates (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        doc_type TEXT NOT NULL,
        paper_size TEXT,
        custom_width REAL,
        custom_height REAL,
        item_row_spacing REAL DEFAULT 1.0,
        background_image TEXT,
        background_opacity REAL DEFAULT 0.5,
        background_x REAL DEFAULT 0.0,
        background_y REAL DEFAULT 0.0,
        background_width REAL,
        background_height REAL,
        layout_json TEXT,
        is_default INTEGER DEFAULT 0,
        is_landscape INTEGER DEFAULT 0,
        view_matrix TEXT
      )
    ''');

    // Migration for background fields
    try {
      await _pool!.execute(
        'ALTER TABLE print_templates ADD COLUMN IF NOT EXISTS item_row_spacing REAL DEFAULT 1.0',
      );
      await _pool!.execute(
        'ALTER TABLE print_templates ADD COLUMN IF NOT EXISTS background_opacity REAL DEFAULT 0.5',
      );
      await _pool!.execute(
        'ALTER TABLE print_templates ADD COLUMN IF NOT EXISTS background_x REAL DEFAULT 0.0',
      );
      await _pool!.execute(
        'ALTER TABLE print_templates ADD COLUMN IF NOT EXISTS background_y REAL DEFAULT 0.0',
      );
      await _pool!.execute(
        'ALTER TABLE print_templates ADD COLUMN IF NOT EXISTS background_width REAL',
      );
      await _pool!.execute(
        'ALTER TABLE print_templates ADD COLUMN IF NOT EXISTS background_height REAL',
      );
      await _pool!.execute(
        'ALTER TABLE print_templates ADD COLUMN IF NOT EXISTS is_landscape INTEGER DEFAULT 0',
      );
      await _pool!.execute(
        'ALTER TABLE print_templates ADD COLUMN IF NOT EXISTS view_matrix TEXT',
      );
    } catch (_) {}
  }

  // --- GENEL AYARLAR ---

  Future<GenelAyarlarModel> genelAyarlariGetir({TxSession? session}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null && session == null) return GenelAyarlarModel();

    final executor = session ?? _pool!;

    final result = await executor.execute(
      'SELECT key, value FROM public.general_settings',
    );
    final Map<String, dynamic> map = {};

    for (final row in result) {
      final key = row[0] as String;
      final value = row[1] as String;

      if (key == 'urunBirimleri' ||
          key == 'urunGruplari' ||
          key == 'kullanilanParaBirimleri' ||
          key == 'aktifModuller') {
        try {
          map[key] = jsonDecode(value);
        } catch (_) {
          map[key] = [];
        }
      } else if (value == 'true' || value == 'false') {
        map[key] = value == 'true' ? 1 : 0;
      } else {
        final intVal = int.tryParse(value);
        if (intVal != null) {
          map[key] = intVal;
        } else {
          map[key] = value;
        }
      }
    }

    if (map.isEmpty) return GenelAyarlarModel();
    return GenelAyarlarModel.fromMap(map);
  }

  Future<void> genelAyarlariKaydet(GenelAyarlarModel model) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final map = model.toMap();

    await _pool!.runTx((session) async {
      for (final entry in map.entries) {
        String valueStr;
        if (entry.value is List || entry.value is Map) {
          valueStr = jsonEncode(entry.value);
        } else {
          valueStr = entry.value.toString();
        }

        await session.execute(
          Sql.named(
            'INSERT INTO public.general_settings (key, value) VALUES (@key, @value) ON CONFLICT (key) DO UPDATE SET value = @value',
          ),
          parameters: {'key': entry.key, 'value': valueStr},
        );
      }
    });
  }

  // --- KULLANICILAR ---

  Future<List<KullaniciModel>> kullanicilariGetir({
    int sayfa = 1,
    int sayfaBasinaKayit = 25,
    String? aramaTerimi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? rol,
    bool? aktifMi,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    // Derin Arama SQL Yapısı - cekler_sayfasi.dart gibi
    String selectClause = 'SELECT users.*';

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      // Eşleşme detaydaysa yakala (işlemlerde eşleşme var ama ana satırda yok)
      selectClause += '''
        , (CASE 
            WHEN (
              EXISTS (
                SELECT 1 FROM user_transactions ut 
                WHERE ut.user_id = users.id 
                AND (
                  LOWER(COALESCE(ut.description, '')) LIKE @search
                  -- İşlem Tipi Çevirisi (Display Name) ile Arama
                  OR (
                    CASE 
                      WHEN LOWER(ut.type) LIKE '%odeme%' OR LOWER(ut.type) LIKE '%ödeme%' THEN 'ödeme'
                      WHEN LOWER(ut.type) LIKE '%alacak%' THEN 'alacak kaydı'
                      WHEN LOWER(ut.type) LIKE '%maas%' OR LOWER(ut.type) LIKE '%maaş%' THEN 'maaş ödemesi'
                      WHEN LOWER(ut.type) LIKE '%prim%' OR LOWER(ut.type) LIKE '%bonus%' THEN 'prim'
                      WHEN LOWER(ut.type) LIKE '%avans%' THEN 'avans'
                      WHEN LOWER(ut.type) LIKE '%kesinti%' THEN 'kesinti'
                      WHEN LOWER(ut.type) LIKE '%tahsilat%' THEN (CASE WHEN ut.credit > ut.debt THEN 'tahsilat' ELSE 'ödeme' END)
                      ELSE (CASE WHEN ut.credit > ut.debt THEN 'girdi' ELSE 'çıktı' END)
                    END LIKE @search
                  )
                  OR LOWER(COALESCE(ut.type, '')) LIKE @search
                  -- Tarih Formatlı Arama (DD.MM.YYYY HH:MM)
                  OR TO_CHAR(ut.date::timestamp, 'DD.MM.YYYY HH24:MI') LIKE @search
                  OR TO_CHAR(ut.date::timestamp, 'DD.MM') LIKE @search
                  OR TO_CHAR(ut.date::timestamp, 'HH24:MI') LIKE @search
                  OR LOWER(COALESCE(ut.date::text, '')) LIKE @search
                  OR CAST(COALESCE(ut.debt, 0) AS TEXT) LIKE @search
                  OR CAST(COALESCE(ut.credit, 0) AS TEXT) LIKE @search
                )
              )
            )
            AND NOT (
              LOWER(COALESCE(username, '')) LIKE @search OR 
              LOWER(COALESCE(name, '')) LIKE @search OR 
              LOWER(COALESCE(surname, '')) LIKE @search OR
              LOWER(COALESCE(email, '')) LIKE @search OR
              LOWER(COALESCE(phone, '')) LIKE @search OR
              LOWER(COALESCE(role, '')) LIKE @search OR
              LOWER(COALESCE(position, '')) LIKE @search OR
              LOWER(COALESCE(hire_date, '')) LIKE @search
            )
            THEN 1 
            ELSE 0 
           END) as matched_in_hidden_calc
      ''';
    } else {
      selectClause += ', 0 as matched_in_hidden_calc';
    }

    List<String> conditions = [];
    Map<String, dynamic> params = {};

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      // Derin arama: kullanıcı alanları VE işlem alanları
      conditions.add('''
        (
          LOWER(COALESCE(username, '')) LIKE @search 
          OR LOWER(COALESCE(name, '')) LIKE @search 
          OR LOWER(COALESCE(surname, '')) LIKE @search 
          OR LOWER(COALESCE(email, '')) LIKE @search 
          OR LOWER(COALESCE(phone, '')) LIKE @search
          OR LOWER(COALESCE(role, '')) LIKE @search
          OR LOWER(COALESCE(position, '')) LIKE @search
          OR LOWER(COALESCE(address, '')) LIKE @search
          OR LOWER(COALESCE(info1, '')) LIKE @search
          OR LOWER(COALESCE(info2, '')) LIKE @search
          OR LOWER(COALESCE(hire_date, '')) LIKE @search
          OR LOWER(COALESCE(salary_currency, '')) LIKE @search
          OR CAST(COALESCE(salary, 0) AS TEXT) LIKE @search
          OR CAST(COALESCE(balance_debt, 0) AS TEXT) LIKE @search
          OR CAST(COALESCE(balance_credit, 0) AS TEXT) LIKE @search
          OR EXISTS (
            SELECT 1 FROM user_transactions ut 
            WHERE ut.user_id = users.id 
            AND (
              LOWER(COALESCE(ut.description, '')) LIKE @search
              -- İşlem Tipi Çevirisi (Display Name) ile Arama
              OR (
                CASE 
                  WHEN LOWER(ut.type) LIKE '%odeme%' OR LOWER(ut.type) LIKE '%ödeme%' THEN 'ödeme'
                  WHEN LOWER(ut.type) LIKE '%alacak%' THEN 'alacak kaydı'
                  WHEN LOWER(ut.type) LIKE '%maas%' OR LOWER(ut.type) LIKE '%maaş%' THEN 'maaş ödemesi'
                  WHEN LOWER(ut.type) LIKE '%prim%' OR LOWER(ut.type) LIKE '%bonus%' THEN 'prim'
                  WHEN LOWER(ut.type) LIKE '%avans%' THEN 'avans'
                  WHEN LOWER(ut.type) LIKE '%kesinti%' THEN 'kesinti'
                  WHEN LOWER(ut.type) LIKE '%tahsilat%' THEN (CASE WHEN ut.credit > ut.debt THEN 'tahsilat' ELSE 'ödeme' END)
                  ELSE (CASE WHEN ut.credit > ut.debt THEN 'girdi' ELSE 'çıktı' END)
                END LIKE @search
              )
              OR LOWER(COALESCE(ut.type, '')) LIKE @search
              -- Tarih Formatlı Arama (DD.MM.YYYY HH:MM)
              OR TO_CHAR(ut.date::timestamp, 'DD.MM.YYYY HH24:MI') LIKE @search
              OR TO_CHAR(ut.date::timestamp, 'DD.MM') LIKE @search
              OR TO_CHAR(ut.date::timestamp, 'HH24:MI') LIKE @search
              OR LOWER(COALESCE(ut.date::text, '')) LIKE @search
              OR CAST(COALESCE(ut.debt, 0) AS TEXT) LIKE @search
              OR CAST(COALESCE(ut.credit, 0) AS TEXT) LIKE @search
            )
          )
        )
      ''');
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
    }

    if (baslangicTarihi != null) {
      conditions.add("TO_DATE(hire_date, 'DD.MM.YYYY') >= @startDate");
      params['startDate'] = baslangicTarihi;
    }

    if (bitisTarihi != null) {
      conditions.add("TO_DATE(hire_date, 'DD.MM.YYYY') <= @endDate");
      params['endDate'] = bitisTarihi;
    }

    if (rol != null && rol.isNotEmpty) {
      conditions.add('role = @role');
      params['role'] = rol;
    }

    if (aktifMi != null) {
      conditions.add('is_active = @isActive');
      params['isActive'] = aktifMi ? 1 : 0;
    }

    String whereClause = '';
    if (conditions.isNotEmpty) {
      whereClause = ' WHERE ${conditions.join(' AND ')}';
    }

    String query =
        '''
      $selectClause
      FROM users
      $whereClause
      ORDER BY id LIMIT @limit OFFSET @offset
    ''';

    params['limit'] = sayfaBasinaKayit;
    params['offset'] = (sayfa - 1) * sayfaBasinaKayit;

    final result = await _pool!.execute(Sql.named(query), parameters: params);
    return result.map((row) {
      final map = row.toColumnMap();
      return KullaniciModel.fromMap(map);
    }).toList();
  }

  Future<int> kullaniciSayisiGetir({
    String? aramaTerimi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? rol,
    bool? aktifMi,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;

    String query = 'SELECT COUNT(*) FROM users';
    List<String> conditions = [];
    Map<String, dynamic> params = {};

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      // Derin arama: kullanıcı alanları VE işlem alanları
      conditions.add('''
        (
          LOWER(COALESCE(username, '')) LIKE @search 
          OR LOWER(COALESCE(name, '')) LIKE @search 
          OR LOWER(COALESCE(surname, '')) LIKE @search 
          OR LOWER(COALESCE(email, '')) LIKE @search 
          OR LOWER(COALESCE(phone, '')) LIKE @search
          OR LOWER(COALESCE(role, '')) LIKE @search
          OR LOWER(COALESCE(position, '')) LIKE @search
          OR LOWER(COALESCE(address, '')) LIKE @search
          OR LOWER(COALESCE(info1, '')) LIKE @search
          OR LOWER(COALESCE(info2, '')) LIKE @search
          OR LOWER(COALESCE(hire_date, '')) LIKE @search
          OR LOWER(COALESCE(salary_currency, '')) LIKE @search
          OR CAST(COALESCE(salary, 0) AS TEXT) LIKE @search
          OR CAST(COALESCE(balance_debt, 0) AS TEXT) LIKE @search
          OR CAST(COALESCE(balance_credit, 0) AS TEXT) LIKE @search
          OR EXISTS (
            SELECT 1 FROM user_transactions ut 
            WHERE ut.user_id = users.id 
            AND (
              LOWER(COALESCE(ut.description, '')) LIKE @search
              -- İşlem Tipi Çevirisi (Display Name) ile Arama
              OR (
                CASE 
                  WHEN LOWER(ut.type) LIKE '%odeme%' OR LOWER(ut.type) LIKE '%ödeme%' THEN 'ödeme'
                  WHEN LOWER(ut.type) LIKE '%alacak%' THEN 'alacak kaydı'
                  WHEN LOWER(ut.type) LIKE '%maas%' OR LOWER(ut.type) LIKE '%maaş%' THEN 'maaş ödemesi'
                  WHEN LOWER(ut.type) LIKE '%prim%' OR LOWER(ut.type) LIKE '%bonus%' THEN 'prim'
                  WHEN LOWER(ut.type) LIKE '%avans%' THEN 'avans'
                  WHEN LOWER(ut.type) LIKE '%kesinti%' THEN 'kesinti'
                  WHEN LOWER(ut.type) LIKE '%tahsilat%' THEN (CASE WHEN ut.credit > ut.debt THEN 'tahsilat' ELSE 'ödeme' END)
                  ELSE (CASE WHEN ut.credit > ut.debt THEN 'girdi' ELSE 'çıktı' END)
                END LIKE @search
              )
              OR LOWER(COALESCE(ut.type, '')) LIKE @search
              -- Tarih Formatlı Arama (DD.MM.YYYY HH:MM)
              OR TO_CHAR(ut.date::timestamp, 'DD.MM.YYYY HH24:MI') LIKE @search
              OR TO_CHAR(ut.date::timestamp, 'DD.MM') LIKE @search
              OR TO_CHAR(ut.date::timestamp, 'HH24:MI') LIKE @search
              OR LOWER(COALESCE(ut.date::text, '')) LIKE @search
              OR CAST(COALESCE(ut.debt, 0) AS TEXT) LIKE @search
              OR CAST(COALESCE(ut.credit, 0) AS TEXT) LIKE @search
            )
          )
        )
      ''');
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
    }

    if (baslangicTarihi != null) {
      conditions.add("TO_DATE(hire_date, 'DD.MM.YYYY') >= @startDate");
      params['startDate'] = baslangicTarihi;
    }

    if (bitisTarihi != null) {
      conditions.add("TO_DATE(hire_date, 'DD.MM.YYYY') <= @endDate");
      params['endDate'] = bitisTarihi;
    }

    if (rol != null && rol.isNotEmpty) {
      conditions.add('role = @role');
      params['role'] = rol;
    }

    if (aktifMi != null) {
      conditions.add('is_active = @isActive');
      params['isActive'] = aktifMi ? 1 : 0;
    }

    if (conditions.isNotEmpty) {
      query += ' WHERE ${conditions.join(' AND ')}';
    }

    final result = await _pool!.execute(Sql.named(query), parameters: params);
    return result[0][0] as int;
  }

  Future<int> rolKullaniciSayisiGetir(String rol) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;

    final result = await _pool!.execute(
      Sql.named('SELECT COUNT(*) FROM users WHERE role = @role'),
      parameters: {'role': rol},
    );
    return result[0][0] as int;
  }

  /// Kullanıcı filtre select'leri için (Rol / Durum) sayım istatistikleri döner.
  /// UI'da "Tümü (n)" ve seçenek bazlı "(n)" gösterimi için kullanılır.
  Future<Map<String, Map<String, int>>> kullaniciFiltreIstatistikleriniGetir({
    String? aramaTerimi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    String? rol,
    bool? aktifMi,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return {};

    final toplam = await kullaniciSayisiGetir(
      aramaTerimi: aramaTerimi,
      baslangicTarihi: baslangicTarihi,
      bitisTarihi: bitisTarihi,
    );

    // Tüm rolleri getir (listeyi dinamik tutmak için)
    final rolesResult = await _pool!.execute(
      Sql.named("SELECT DISTINCT COALESCE(role, '') AS role FROM users"),
    );
    final roles = rolesResult
        .map((r) => (r[0] ?? '').toString())
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList();

    // Rol facet: mevcut aktiflik filtresine göre say
    final roleEntries = await Future.wait(
      roles.map((r) async {
        final count = await kullaniciSayisiGetir(
          aramaTerimi: aramaTerimi,
          baslangicTarihi: baslangicTarihi,
          bitisTarihi: bitisTarihi,
          rol: r,
          aktifMi: aktifMi,
        );
        return MapEntry(r, count);
      }),
    );

    final roleCounts = <String, int>{
      for (final e in roleEntries) e.key: e.value,
    };

    // Durum facet: mevcut rol filtresine göre say
    final activeCount = await kullaniciSayisiGetir(
      aramaTerimi: aramaTerimi,
      baslangicTarihi: baslangicTarihi,
      bitisTarihi: bitisTarihi,
      rol: rol,
      aktifMi: true,
    );
    final passiveCount = await kullaniciSayisiGetir(
      aramaTerimi: aramaTerimi,
      baslangicTarihi: baslangicTarihi,
      bitisTarihi: bitisTarihi,
      rol: rol,
      aktifMi: false,
    );

    return {
      'ozet': {'toplam': toplam},
      'roller': roleCounts,
      'durumlar': {'active': activeCount, 'passive': passiveCount},
    };
  }

  Future<void> kullaniciEkle(KullaniciModel k) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('''
        INSERT INTO users (id, username, name, surname, email, role, is_active, phone, profile_image, password, hire_date, position, salary, salary_currency, address, info1, info2, balance_debt, balance_credit)
        VALUES (@id, @username, @name, @surname, @email, @role, @is_active, @phone, @profile_image, @password, @hire_date, @position, @salary, @salary_currency, @address, @info1, @info2, @balance_debt, @balance_credit)
      '''),
      parameters: k.toMap(),
    );
  }

  Future<void> kullaniciGuncelle(KullaniciModel k) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('''
        UPDATE users SET 
        username=@username, name=@name, surname=@surname, email=@email, 
        role=@role, is_active=@is_active, phone=@phone, profile_image=@profile_image, password=@password,
        hire_date=@hire_date, position=@position, salary=@salary, salary_currency=@salary_currency,
        address=@address, info1=@info1, info2=@info2
        WHERE id=@id
      '''),
      parameters: k.toMap(),
    );
  }

  Future<void> kullaniciSil(String id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('DELETE FROM users WHERE id = @id'),
      parameters: {'id': id},
    );
    // Hareketleri de siliyoruz
    await _pool!.execute(
      Sql.named('DELETE FROM user_transactions WHERE user_id = @id'),
      parameters: {'id': id},
    );
  }

  Future<List<KullaniciHareketModel>> kullaniciHareketleriniGetir(
    String kullaniciId,
  ) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    final result = await _pool!.execute(
      Sql.named(
        'SELECT * FROM user_transactions WHERE user_id = @id ORDER BY date DESC',
      ),
      parameters: {'id': kullaniciId},
    );

    return result.map((row) {
      final map = row.toColumnMap();
      return KullaniciHareketModel.fromMap(map);
    }).toList();
  }

  Future<void> kullaniciHareketEkle(KullaniciHareketModel h) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // Hareketi ekle
      await session.execute(
        Sql.named('''
          INSERT INTO user_transactions (id, user_id, date, description, debt, credit, type)
          VALUES (@id, @user_id, @date, @description, @debt, @credit, @type)
        '''),
        parameters: h.toMap(),
      );

      // Kullanıcının bakiyesini güncelle
      await session.execute(
        Sql.named('''
          UPDATE users 
          SET balance_debt = COALESCE(balance_debt, 0) + @debt,
              balance_credit = COALESCE(balance_credit, 0) + @credit
          WHERE id = @user_id
        '''),
        parameters: {
          'debt': h.borc,
          'credit': h.alacak,
          'user_id': h.kullaniciId,
        },
      );
    });
  }

  Future<void> kullaniciHareketSil(String hareketId) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      // Önce hareketi oku (bakiye güncellemek için)
      final result = await session.execute(
        Sql.named(
          'SELECT user_id, debt, credit FROM user_transactions WHERE id = @id',
        ),
        parameters: {'id': hareketId},
      );

      if (result.isNotEmpty) {
        final row = result.first;
        final userId = row[0] as String;
        final debt = double.tryParse(row[1]?.toString() ?? '') ?? 0.0;
        final credit = double.tryParse(row[2]?.toString() ?? '') ?? 0.0;

        // Kullanıcının bakiyesinden düş
        await session.execute(
          Sql.named('''
            UPDATE users 
            SET balance_debt = COALESCE(balance_debt, 0) - @debt,
                balance_credit = COALESCE(balance_credit, 0) - @credit
            WHERE id = @user_id
          '''),
          parameters: {'debt': debt, 'credit': credit, 'user_id': userId},
        );
      }

      // Hareketi sil
      await session.execute(
        Sql.named('DELETE FROM user_transactions WHERE id = @id'),
        parameters: {'id': hareketId},
      );
    });
  }

  // --- ROLLER ---

  Future<List<RolModel>> rolleriGetir({
    int sayfa = 1,
    int sayfaBasinaKayit = 25,
    String? aramaTerimi,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    String query = 'SELECT * FROM roles';
    Map<String, dynamic> params = {};

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      query += ' WHERE LOWER(name) LIKE @search';
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
    }

    query += ' ORDER BY id LIMIT @limit OFFSET @offset';
    params['limit'] = sayfaBasinaKayit;
    params['offset'] = (sayfa - 1) * sayfaBasinaKayit;

    final result = await _pool!.execute(Sql.named(query), parameters: params);
    return result.map((row) {
      final map = row.toColumnMap();
      return RolModel.fromMap(map);
    }).toList();
  }

  Future<int> rolSayisiGetir({String? aramaTerimi}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;

    String query = 'SELECT COUNT(*) FROM roles';
    Map<String, dynamic> params = {};

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      query += ' WHERE LOWER(name) LIKE @search';
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
    }

    final result = await _pool!.execute(Sql.named(query), parameters: params);
    return result[0][0] as int;
  }

  Future<void> rolEkle(RolModel r) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('''
        INSERT INTO roles (id, name, permissions, is_system, is_active)
        VALUES (@id, @name, @permissions, @is_system, @is_active)
      '''),
      parameters: r.toMap(),
    );
  }

  Future<void> rolGuncelle(RolModel r) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('''
        UPDATE roles SET name=@name, permissions=@permissions, is_system=@is_system, is_active=@is_active
        WHERE id=@id
      '''),
      parameters: r.toMap(),
    );
  }

  Future<void> rolSil(String id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('DELETE FROM roles WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  // --- ŞİRKET AYARLARI ---

  Future<List<SirketAyarlariModel>> sirketleriGetir({
    int sayfa = 1,
    int sayfaBasinaKayit = 25,
    String? aramaTerimi,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    String query = 'SELECT * FROM company_settings';
    Map<String, dynamic> params = {};

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      query += ' WHERE LOWER(kod) LIKE @search OR LOWER(ad) LIKE @search';
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
    }

    query += ' ORDER BY id LIMIT @limit OFFSET @offset';
    params['limit'] = sayfaBasinaKayit;
    params['offset'] = (sayfa - 1) * sayfaBasinaKayit;

    final result = await _pool!.execute(Sql.named(query), parameters: params);
    return result.map((row) {
      final map = row.toColumnMap();
      return SirketAyarlariModel.fromMap(map);
    }).toList();
  }

  Future<int> sirketSayisiGetir({String? aramaTerimi}) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return 0;

    String query = 'SELECT COUNT(*) FROM company_settings';
    Map<String, dynamic> params = {};

    if (aramaTerimi != null && aramaTerimi.isNotEmpty) {
      query += ' WHERE LOWER(kod) LIKE @search OR LOWER(ad) LIKE @search';
      params['search'] = '%${aramaTerimi.toLowerCase()}%';
    }

    final result = await _pool!.execute(Sql.named(query), parameters: params);
    return result[0][0] as int;
  }

  Future<void> sirketEkle(SirketAyarlariModel s) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    final map = s.toMap();
    map.remove('id');

    await _pool!.execute(
      Sql.named('''
        INSERT INTO company_settings (
          kod, ad, basliklar, logolar,
          adres, vergi_dairesi, vergi_no, telefon, eposta, web_adresi,
          aktif_mi, varsayilan_mi, duzenlenebilir_mi, ust_bilgi_logosu, ust_bilgi_satirlari
        )
        VALUES (
          @kod, @ad, @basliklar, @logolar,
          @adres, @vergi_dairesi, @vergi_no, @telefon, @eposta, @web_adresi,
          @aktif_mi, @varsayilan_mi, @duzenlenebilir_mi, @ust_bilgi_logosu, @ust_bilgi_satirlari
        )
      '''),
      parameters: map,
    );
  }

  Future<void> sirketGuncelle(SirketAyarlariModel s) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('''
        UPDATE company_settings SET 
        kod=@kod, ad=@ad, basliklar=@basliklar, logolar=@logolar, 
        adres=@adres, vergi_dairesi=@vergi_dairesi, vergi_no=@vergi_no, telefon=@telefon, eposta=@eposta, web_adresi=@web_adresi,
        aktif_mi=@aktif_mi, varsayilan_mi=@varsayilan_mi, duzenlenebilir_mi=@duzenlenebilir_mi,
        ust_bilgi_logosu=@ust_bilgi_logosu, ust_bilgi_satirlari=@ust_bilgi_satirlari
        WHERE id=@id
      '''),
      parameters: s.toMap(),
    );
  }

  Future<void> sirketSil(int id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('DELETE FROM company_settings WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  Future<void> varsayilanSirketYap(int id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.runTx((session) async {
      await session.execute('UPDATE company_settings SET varsayilan_mi = 0');
      await session.execute(
        Sql.named(
          'UPDATE company_settings SET varsayilan_mi = 1 WHERE id = @id',
        ),
        parameters: {'id': id},
      );
    });
  }

  String sifreHashle(String sifre) {
    final bytes = utf8.encode(sifre);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _varsayilanAdminSifresi() {
    if (!kIsWeb) {
      final envPass = Platform.environment['PATISYO_DEFAULT_ADMIN_PASSWORD'];
      if (envPass != null && envPass.trim().isNotEmpty) {
        return envPass.trim();
      }
    }

    // Legacy fallback (backward-compatible)
    return String.fromCharCodes(const [97, 100, 109, 105, 110]);
  }

  Future<KullaniciModel?> girisYap(String kullaniciAdi, String sifre) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    final hashed = sifreHashle(sifre);

    final result = await _pool!.execute(
      Sql.named('SELECT * FROM users WHERE username = @username'),
      parameters: {'username': kullaniciAdi},
    );

    if (result.isEmpty) return null;

    final row = result.first;
    final map = row.toColumnMap();
    final user = KullaniciModel.fromMap(map);

    // Hem düz metin (eski kayıtlar için) hem de hashli kontrol
    if (user.sifre == sifre || user.sifre == hashed) {
      return user;
    }

    return null;
  }

  Future<void> _varsayilanVerileriEkle() async {
    if (_pool == null) return;

    try {
      final rolesCount = await _pool!.execute('SELECT COUNT(*) FROM roles');
      if (rolesCount[0][0] == 0) {
        // Rolleri ekle...
        final List<String> tumIzinler = [];
        void tara(MenuItem oge) {
          tumIzinler.add(oge.id);
          for (final alt in oge.children) {
            tara(alt);
          }
        }

        for (final item in MenuAyarlari.menuItems) {
          tara(item);
        }

        await rolEkle(
          RolModel(
            id: 'admin',
            ad: 'Yönetici',
            izinler: tumIzinler,
            sistemRoluMu: true,
            aktifMi: true,
          ),
        );
        await rolEkle(
          RolModel(
            id: 'user',
            ad: 'Kullanıcı',
            izinler: [],
            sistemRoluMu: true,
            aktifMi: true,
          ),
        );
        await rolEkle(
          RolModel(
            id: 'cashier',
            ad: 'Kasiyer',
            izinler: [],
            sistemRoluMu: true,
            aktifMi: true,
          ),
        );
        await rolEkle(
          RolModel(
            id: 'waiter',
            ad: 'Garson',
            izinler: [],
            sistemRoluMu: true,
            aktifMi: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Roller eklenirken hata: $e');
    }

    try {
      final usersCount = await _pool!.execute('SELECT COUNT(*) FROM users');
      if (usersCount[0][0] == 0) {
        await kullaniciEkle(
          KullaniciModel(
            id: '1',
            kullaniciAdi: 'admin',
            ad: 'Sistem',
            soyad: 'Yöneticisi',
            eposta: 'admin@patisyo.com',
            rol: 'admin',
            aktifMi: true,
            telefon: '',
            sifre: sifreHashle(_varsayilanAdminSifresi()),
            profilResmi: null,
          ),
        );
      }
    } catch (e) {
      debugPrint('Kullanıcılar eklenirken hata: $e');
    }

    // Şirket Kontrolü - Güncellenmiş Mantık
    try {
      final companiesCountRaw = await _pool!.execute(
        'SELECT COUNT(*) FROM company_settings',
      );
      final int companiesCount = companiesCountRaw[0][0] as int;
      final bulut = _bulutModundaMi();
      final varsayilanSirketKodu = bulut ? _config.database : 'patisyo2025';

      if (companiesCount == 0) {
        debugPrint('Şirket tablosu boş, varsayılan şirket oluşturuluyor...');
        if (bulut) {
          // Cloud modda ayrı veritabanı oluşturmadan sadece şirket kaydı ekle
          await sirketEkle(
            SirketAyarlariModel(
              kod: varsayilanSirketKodu,
              ad: varsayilanSirketKodu,
              basliklar: [],
              logolar: [],
              aktifMi: true,
              varsayilanMi: true,
              duzenlenebilirMi: true,
              ustBilgiLogosu: null,
              ustBilgiSatirlari: [],
            ),
          );
          debugPrint(
            'Cloud varsayılan şirket oluşturuldu: $varsayilanSirketKodu',
          );
        } else {
          await _varsayilanSirketiYarat(varsayilanSirketKodu);
        }
      } else {
        // Şirket var ama varsayılan şirket olmayabilir
        final defaultCompanyResult = await _pool!.execute(
          "SELECT 1 FROM company_settings WHERE varsayilan_mi = 1",
        );

        if (defaultCompanyResult.isEmpty) {
          debugPrint(
            'Varsayılan şirket bulunamadı, mevcut ilk şirketi varsayılan yapıyorum...',
          );
          await _pool!.execute(
            'UPDATE company_settings SET varsayilan_mi = 1 WHERE id = (SELECT id FROM company_settings ORDER BY id LIMIT 1)',
          );
        }

        // Şirket veritabanlarını kontrol et (sadece lokal modda)
        if (!bulut) {
          await _sirketVeritabanlariniKontrolEt();
        }
      }
    } catch (e) {
      debugPrint('Varsayılan veri ekleme (Şirket) hatası: $e');
    }
  }

  Future<void> _varsayilanSirketiYarat(String varsayilanSirketKodu) async {
    await sirketEkle(
      SirketAyarlariModel(
        kod: varsayilanSirketKodu,
        ad: 'Patisyo Yazılım A.Ş.',
        basliklar: [],
        logolar: [],
        aktifMi: true,
        varsayilanMi: true,
        duzenlenebilirMi: true,
        ustBilgiLogosu: null,
        ustBilgiSatirlari: [
          'Patisyo Yazılım Antet Satırı 1',
          'Patisyo Yazılım Antet Satırı 2',
          'Patisyo Yazılım Antet Satırı 3',
        ],
      ),
    );

    // Varsayılan şirket için veritabanını da oluştur
    try {
      await _varsayilanSirketVeritabaniOlustur(varsayilanSirketKodu);
    } catch (e) {
      debugPrint('Varsayılan şirket veritabanı oluşturma hatası: $e');
    }
  }

  /// Varsayılan şirket için veritabanı oluşturur (patisyo2025 için özel durum)
  Future<void> _varsayilanSirketVeritabaniOlustur(String sirketKodu) async {
    // patisyo2025 için veritabanı adı direkt patisyo2025
    final dbName = sirketKodu == 'patisyo2025'
        ? 'patisyo2025'
        : 'patisyo_${sirketKodu.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase()}';

    debugPrint('Varsayılan şirket veritabanı kontrol ediliyor: $dbName');

    final adminConn = await _yoneticiBaglantisiAl();
    if (adminConn == null) {
      debugPrint('Yönetici bağlantısı alınamadı, veritabanı oluşturulamadı.');
      return;
    }

    try {
      // Veritabanı var mı kontrol et
      final result = await adminConn.execute(
        "SELECT 1 FROM pg_database WHERE datname = '$dbName'",
      );

      if (result.isEmpty) {
        // Veritabanı yok, oluştur
        try {
          await adminConn.execute(
            'CREATE DATABASE "$dbName" OWNER "${_config.username}"',
          );
          debugPrint('Şirket veritabanı oluşturuldu: $dbName');
        } catch (e) {
          if (e is ServerException && e.code == '42P04') {
            debugPrint('Veritabanı zaten mevcut: $dbName');
          } else {
            rethrow;
          }
        }

        // Yetkileri ver
        try {
          await adminConn.execute(
            'GRANT ALL PRIVILEGES ON DATABASE "$dbName" TO "${_config.username}"',
          );
        } catch (e) {
          debugPrint('Yetki verme uyarısı: $e');
        }
      } else {
        debugPrint('Şirket veritabanı zaten mevcut: $dbName');
      }
    } finally {
      await adminConn.close();
    }
  }

  /// Mevcut tüm şirketlerin veritabanlarının varlığını kontrol eder
  Future<void> _sirketVeritabanlariniKontrolEt() async {
    if (_pool == null) return;

    try {
      final sirketler = await _pool!.execute(
        'SELECT kod FROM company_settings',
      );

      for (final row in sirketler) {
        final kod = row[0] as String;
        try {
          await _varsayilanSirketVeritabaniOlustur(kod);
        } catch (e) {
          debugPrint('Şirket veritabanı kontrol hatası ($kod): $e');
        }
      }
    } catch (e) {
      debugPrint('Şirket veritabanları kontrol hatası: $e');
    }
  }

  Future<RolModel?> rolGetir(String id) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return null;

    final result = await _pool!.execute(
      Sql.named('SELECT * FROM roles WHERE id = @id'),
      parameters: {'id': id},
    );

    if (result.isEmpty) return null;

    final row = result.first;
    final map = row.toColumnMap();
    return RolModel.fromMap(map);
  }

  // --- YENİ ŞİRKET VERİTABANI OLUŞTURMA ---

  Future<void> sirketVeritabaniOlustur(String sirketKodu) async {
    final safeCode = sirketKodu
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toLowerCase();
    final newDbName = 'patisyo_$safeCode';

    debugPrint('Yeni şirket veritabanı oluşturuluyor: $newDbName');

    final adminConn = await _yoneticiBaglantisiAl();
    if (adminConn == null) {
      throw Exception(
        'Yönetici bağlantısı alınamadı, veritabanı oluşturulamadı.',
      );
    }

    try {
      // 1. Veritabanını Oluştur
      try {
        await adminConn.execute(
          'CREATE DATABASE "$newDbName" OWNER "${_config.username}"',
        );
        debugPrint('AyarlarVeritabaniServisi: Database created: $newDbName');
      } catch (e) {
        if (e is ServerException && e.code == '42P04') {
          debugPrint(
            'AyarlarVeritabaniServisi: Database already exists: $newDbName',
          );
        } else {
          rethrow;
        }
      }

      // 2. Yetkileri Ver
      try {
        await adminConn.execute(
          'GRANT ALL PRIVILEGES ON DATABASE "$newDbName" TO "${_config.username}"',
        );
      } catch (e) {
        debugPrint('AyarlarVeritabaniServisi: Authorization warning: $e');
      }
    } catch (e) {
      debugPrint('Şirket veritabanı oluşturma hatası: $e');
      rethrow;
    } finally {
      await adminConn.close();
    }
  }

  // --- AÇIKLAMALAR (SMART SELECT) ---

  // Gizli olanları getir (Widget tarafında filtreleme için)
  Future<List<String>> gizliAciklamalariGetir(String category) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    final result = await _pool!.execute(
      Sql.named(
        'SELECT content FROM hidden_descriptions WHERE category = @category',
      ),
      parameters: {'category': category},
    );
    return result.map((row) => row[0] as String).toList();
  }

  Future<List<String>> aciklamalariGetir(
    String category, {
    String? query,
  }) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    // Önce gizli olanları al
    final hiddenResult = await _pool!.execute(
      Sql.named(
        'SELECT content FROM hidden_descriptions WHERE category = @category',
      ),
      parameters: {'category': category},
    );
    final hiddenItems = hiddenResult.map((row) => row[0] as String).toSet();

    String sql =
        'SELECT content FROM saved_descriptions WHERE category = @category';
    final params = {'category': category};

    if (query != null && query.isNotEmpty) {
      sql += ' AND LOWER(content) LIKE @query';
      params['query'] = '%${query.toLowerCase()}%';
    }

    // En çok kullanılanlar ve son kullanılanlar önce gelsin
    sql += ' ORDER BY usage_count DESC, last_used DESC LIMIT 50';

    final result = await _pool!.execute(Sql.named(sql), parameters: params);

    final dbItems = result.map((row) => row[0] as String).toList();

    // Gizli olanları filtrele
    return dbItems.where((item) => !hiddenItems.contains(item)).toList();
  }

  Future<void> aciklamaEkle(String category, String content) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;
    if (content.trim().isEmpty) return;

    final now = DateTime.now().toIso8601String();

    // Eğer gizliyse, gizliden kaldır
    await _pool!.execute(
      Sql.named(
        'DELETE FROM hidden_descriptions WHERE category = @category AND content = @content',
      ),
      parameters: {'category': category, 'content': content.trim()},
    );

    // Kayıt ekle
    await _pool!.execute(
      Sql.named('''
        INSERT INTO saved_descriptions (category, content, usage_count, last_used)
        VALUES (@category, @content, 1, @now)
        ON CONFLICT (category, content) 
        DO UPDATE SET 
          usage_count = saved_descriptions.usage_count + 1,
          last_used = @now
      '''),
      parameters: {'category': category, 'content': content.trim(), 'now': now},
    );
  }

  Future<void> aciklamaSil(String category, String content) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    // 1. DB'den sil (custom eklenmişse)
    await _pool!.execute(
      Sql.named(
        'DELETE FROM saved_descriptions WHERE category = @category AND content = @content',
      ),
      parameters: {'category': category, 'content': content},
    );

    // 2. Gizlilere ekle (varsayılan ise bir daha gelmemesi için)
    // Eğer zaten varsa hata vermesin diye ON CONFLICT DO NOTHING
    await _pool!.execute(
      Sql.named('''
        INSERT INTO hidden_descriptions (category, content)
        VALUES (@category, @content)
        ON CONFLICT (category, content) DO NOTHING
      '''),
      parameters: {'category': category, 'content': content},
    );
  }

  Future<List<DovizKuruModel>> kurlariGetir() async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return [];

    final result = await _pool!.execute(
      'SELECT from_code, to_code, rate, update_time FROM currency_rates',
    );
    return result
        .map((row) => DovizKuruModel.fromMap(row.toColumnMap()))
        .toList();
  }

  Future<void> kurKaydet(DovizKuruModel kur) async {
    if (!_isInitialized) await baslat();
    if (_pool == null) return;

    await _pool!.execute(
      Sql.named('''
        INSERT INTO currency_rates (from_code, to_code, rate, update_time)
        VALUES (@from_code, @to_code, @rate, @update_time)
        ON CONFLICT (from_code, to_code) DO UPDATE SET rate = @rate, update_time = @update_time
      '''),
      parameters: kur.toMap(),
    );
  }
}
