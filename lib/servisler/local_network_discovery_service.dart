import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart';
import 'package:postgres/postgres.dart';
import 'veritabani_yapilandirma.dart';
import 'lisans_servisi.dart';

/// Yerel Ağ Keşif Servisi (Zero-Config mDNS)
///
/// Masaüstü uygulaması için "Server" olarak kendini tanıtır.
/// Mobil uygulama için ağdaki "Server"ı bulur.
class LocalNetworkDiscoveryService {
  static final LocalNetworkDiscoveryService _instance =
      LocalNetworkDiscoveryService._internal();
  factory LocalNetworkDiscoveryService() => _instance;
  LocalNetworkDiscoveryService._internal();

  static const String _serviceType = '_patisyo-pos._tcp';
  static const String _serviceName = 'Patisyo POS Server';
  static const int _localDefaultPort = 5432;
  static const String _localDefaultDatabase = 'patisyosettings';
  static const String _localDefaultUsername = 'patisyo';
  static const String _localLegacyPassword = '5828486';

  Registration? _registration;

  bool get _isMobilePlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Masaüstü uygulaması için yayına başlar.
  Future<void> yayiniBaslat() async {
    if (kIsWeb || (Platform.isAndroid || Platform.isIOS)) return;

    try {
      final config = VeritabaniYapilandirma();
      // Veritabanı portunu ve lisans durumunu yayınlıyoruz.
      _registration = await register(
        Service(
          name: _serviceName,
          type: _serviceType,
          port: config.port,
          txt: {
            'isPro': Uint8List.fromList(
              utf8.encode(LisansServisi().isLicensed ? 'true' : 'false'),
            ),
          },
        ),
      );
      debugPrint(
        'mDNS: Sunucu yayını başlatıldı: $_serviceName ($_serviceType) Port: ${config.port}, Pro: ${LisansServisi().isLicensed}',
      );
    } catch (e) {
      debugPrint('mDNS Yayını başlatılamadı: $e');
    }
  }

  /// Yayını durdurur.
  Future<void> yayiniDurdur() async {
    if (_registration != null) {
      await unregister(_registration!);
      _registration = null;
      debugPrint('mDNS: Sunucu yayını durduruldu.');
    }
  }

  /// Mobil uygulama için ağda sunucu arar.
  Future<Service?> sunucuBul({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Geriye dönük uyumluluk: ilk sunucuyu döndür.
    final list = await sunuculariBul(timeout: timeout);
    return list.isNotEmpty ? list.first : null;
  }

  /// Mobil/Tablet için ağdaki tüm sunucuları bulur.
  ///
  /// Öncelik:
  /// 1) mDNS (program açıkken çok hızlı)
  /// 2) Port/DB taraması (program açık olmasa da, PostgreSQL çalışıyorsa bulur)
  Future<List<Service>> sunuculariBul({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (kIsWeb) return const [];

    final mdnsTimeout = timeout > const Duration(milliseconds: 1200)
        ? const Duration(milliseconds: 1200)
        : timeout;

    final scanTimeout = timeout > const Duration(milliseconds: 2200)
        ? const Duration(milliseconds: 2200)
        : timeout;

    final tasks = <Future<List<Service>>>[
      _mdnsSunuculariBul(timeout: mdnsTimeout),
    ];

    if (_isMobilePlatform) {
      tasks.add(_portVeDbTaramaIleSunuculariBul(timeout: scanTimeout));
    }

    final results = await Future.wait(tasks);
    final combined = results.expand((e) => e).toList();

    // Host'a göre tekilleştir, isim dolu olanı tercih et.
    final Map<String, Service> byHost = {};
    for (final s in combined) {
      final host = (s.host ?? '').trim();
      if (host.isEmpty) continue;
      final prev = byHost[host];
      if (prev == null) {
        byHost[host] = s;
        continue;
      }
      final prevName = (prev.name ?? '').trim();
      final nextName = (s.name ?? '').trim();
      if (prevName.isEmpty && nextName.isNotEmpty) {
        byHost[host] = s;
      }
    }

    final list = byHost.values.toList()
      ..sort((a, b) {
        final an = (a.name ?? a.host ?? '').toLowerCase();
        final bn = (b.name ?? b.host ?? '').toLowerCase();
        return an.compareTo(bn);
      });

    return list;
  }

  /// Arka planda otomatik çözümleme yapar
  Future<void> autoResolution() async {
    // 1. Zaten yapılandırma yüklendi mi? (main.dart'ta çağrılacak)
    if (VeritabaniYapilandirma.connectionMode == 'cloud') return;

    debugPrint('mDNS: Otomatik çözümleme başlatılıyor...');

    // 2. Önce mevcut host'u test et (Opsiyonel ama hızlı)
    // Şimdilik direkt hızlı tarama başlatıyoruz
    final service = await hizliSunucuBul();
    if (service != null && service.host != null) {
      VeritabaniYapilandirma.setDiscoveredHost(service.host);

      // Lisans durumunu devral
      bool isPro = false;
      final txt = service.txt;
      if (txt != null && txt['isPro'] != null) {
        isPro = utf8.decode(txt['isPro']!) == 'true';
      }
      await LisansServisi().setInheritedPro(isPro);
    }
  }

  /// Daha kısa timeout ile hızlı tarama yapar
  Future<Service?> hizliSunucuBul({
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    // Önce mDNS dene (çok hızlı).
    final mdns = await _mdnsIlkSunucuBul(timeout: timeout);
    if (mdns != null) return mdns;

    // Mobilde, program açık olmasa da PostgreSQL üzerinden bulmaya çalış.
    if (_isMobilePlatform) {
      return await _portVeDbTaramaIleIlkSunucuBul(timeout: timeout);
    }

    return null;
  }

  Future<Service?> _mdnsIlkSunucuBul({required Duration timeout}) async {
    debugPrint(
      'mDNS: Hızlı tarama başlatılıyor (Timeout: ${timeout.inMilliseconds}ms)...',
    );

    final completer = Completer<Service?>();
    Discovery? discovery;
    Timer? timeoutTimer;
    bool kapatildi = false;

    Future<void> temizle() async {
      if (kapatildi) return;
      kapatildi = true;
      timeoutTimer?.cancel();
      if (discovery != null) {
        try {
          await stopDiscovery(discovery);
        } catch (_) {}
      }
    }

    try {
      discovery = await startDiscovery(_serviceType);
      discovery.addServiceListener((service, status) async {
        if (status != ServiceStatus.found || completer.isCompleted) {
          return;
        }

        try {
          final resolved = await resolve(service);
          final host = (resolved.host ?? '').trim();
          if (host.isEmpty) return;

          final ipv4 = _ipv4FromAddresses(resolved.addresses);
          final normalizedHost = (ipv4 ?? host).trim();

          final revName = await _reverseLookupBestEffort(normalizedHost);
          final displayName = (revName != null && revName.trim().isNotEmpty)
              ? revName.trim()
              : resolved.name;

          if (!completer.isCompleted) {
            completer.complete(
              Service(
                name: displayName,
                type: resolved.type,
                host: normalizedHost,
                port: resolved.port,
                txt: resolved.txt,
                addresses: resolved.addresses,
              ),
            );
          }
        } catch (e) {
          debugPrint('mDNS: Hızlı çözümleme uyarısı: $e');
        } finally {
          unawaited(temizle());
        }
      });

      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          debugPrint('mDNS: Hızlı tarama zaman aşımına uğradı.');
          completer.complete(null);
        }
        unawaited(temizle());
      });

      final result = await completer.future;
      await temizle();
      return result;
    } catch (e) {
      debugPrint('mDNS: Hızlı tarama hatası: $e');
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      await temizle();
    }
    return null;
  }

  Future<Service?> _portVeDbTaramaIleIlkSunucuBul({
    required Duration timeout,
  }) async {
    final localIp = await _localPrivateIpv4BestEffort();
    if (localIp == null) return null;

    final prefix = _ipv4Prefix24(localIp.address);
    if (prefix == null) return null;

    final portCandidates = <int>{_localDefaultPort};
    final cfgPort = VeritabaniYapilandirma().port;
    if (cfgPort > 0) portCandidates.add(cfgPort);

    final targets = <String>[];
    for (int i = 1; i <= 254; i++) {
      final ip = '$prefix$i';
      if (ip == localIp.address) continue;
      targets.add(ip);
    }

    const int batchSize = 64;
    final socketTimeout = Duration(
      milliseconds: timeout.inMilliseconds < 180 ? timeout.inMilliseconds : 180,
    );
    final dbTimeout = Duration(
      milliseconds: timeout.inMilliseconds < 650 ? timeout.inMilliseconds : 650,
    );

    for (int start = 0; start < targets.length; start += batchSize) {
      final end = (start + batchSize) > targets.length
          ? targets.length
          : (start + batchSize);
      final batch = targets.sublist(start, end);

      final hit = await _firstNonNull<Service>(
        batch.map((ip) async {
          for (final port in portCandidates) {
            final open = await _tcpPortAcikMi(
              ip,
              port,
              timeout: socketTimeout,
            );
            if (!open) continue;

            final serverMi = await _patisyoServerMi(
              ip,
              port,
              connectTimeout: dbTimeout,
            );
            if (!serverMi) continue;

            final name = await _reverseLookupBestEffort(ip);
            return Service(
              name: name ?? ip,
              type: _serviceType,
              host: ip,
              port: port,
            );
          }
          return null;
        }),
      );

      if (hit != null) return hit;
    }

    return null;
  }

  Future<List<Service>> _mdnsSunuculariBul({required Duration timeout}) async {
    Discovery? discovery;
    try {
      discovery = await startDiscovery(_serviceType);
    } catch (e) {
      debugPrint('mDNS: Discovery başlatılamadı: $e');
      return const [];
    }

    try {
      await Future<void>.delayed(timeout);
    } finally {
      try {
        await stopDiscovery(discovery);
      } catch (_) {}
    }

    final services = discovery.services;
    if (services.isEmpty) return const [];

    final List<Service> resolved = [];
    for (final s in services) {
      try {
        final Service r = (s.host != null &&
                s.host!.trim().isNotEmpty &&
                s.port != null &&
                (s.port ?? 0) > 0)
            ? s
            : await resolve(s);

        final host = (r.host ?? '').trim();
        if (host.isEmpty) continue;

        // Bazı platformlarda host hostname dönebilir; IPv4 varsa onu tercih et.
        final ipv4 = _ipv4FromAddresses(r.addresses);
        final normalizedHost = (ipv4 ?? host).trim();

        final revName = await _reverseLookupBestEffort(normalizedHost);
        final displayName = (revName != null && revName.trim().isNotEmpty)
            ? revName.trim()
            : r.name;

        resolved.add(
          Service(
            name: displayName,
            type: r.type,
            host: normalizedHost,
            port: r.port,
            txt: r.txt,
            addresses: r.addresses,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return resolved;
  }

  Future<T?> _firstNonNull<T>(Iterable<Future<T?>> futures) {
    final completer = Completer<T?>();
    var remaining = 0;

    for (final f in futures) {
      remaining++;
      f.then((value) {
        if (value != null && !completer.isCompleted) {
          completer.complete(value);
        }
      }).whenComplete(() {
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    if (remaining == 0 && !completer.isCompleted) {
      completer.complete(null);
    }

    return completer.future;
  }

  String? _ipv4FromAddresses(List<InternetAddress>? addresses) {
    if (addresses == null) return null;
    for (final a in addresses) {
      if (a.type == InternetAddressType.IPv4) return a.address;
    }
    return null;
  }

  Future<List<Service>> _portVeDbTaramaIleSunuculariBul({
    required Duration timeout,
  }) async {
    final localIp = await _localPrivateIpv4BestEffort();
    if (localIp == null) return const [];

    final prefix = _ipv4Prefix24(localIp.address);
    if (prefix == null) return const [];

    final portCandidates = <int>{_localDefaultPort};
    // Eğer env ile farklı port set edildiyse, onu da dene (best-effort).
    final cfgPort = VeritabaniYapilandirma().port;
    if (cfgPort > 0) portCandidates.add(cfgPort);

    final targets = <String>[];
    for (int i = 1; i <= 254; i++) {
      final ip = '$prefix$i';
      if (ip == localIp.address) continue;
      targets.add(ip);
    }

    final List<Service> found = [];

    // Hız için batch + paralel denemeler (mobilde 254 IP taraması ~1-2sn).
    const int batchSize = 48;
    final socketTimeout = Duration(
      milliseconds: timeout.inMilliseconds < 220 ? timeout.inMilliseconds : 220,
    );
    final dbTimeout = Duration(
      milliseconds: timeout.inMilliseconds < 650 ? timeout.inMilliseconds : 650,
    );

    for (int start = 0; start < targets.length; start += batchSize) {
      final end = (start + batchSize) > targets.length
          ? targets.length
          : (start + batchSize);
      final batch = targets.sublist(start, end);

      final batchResults = await Future.wait(
        batch.map((ip) async {
          for (final port in portCandidates) {
            final open = await _tcpPortAcikMi(
              ip,
              port,
              timeout: socketTimeout,
            );
            if (!open) continue;

            final serverMi = await _patisyoServerMi(
              ip,
              port,
              connectTimeout: dbTimeout,
            );
            if (!serverMi) continue;

            final name = await _reverseLookupBestEffort(ip);
            return Service(
              name: name ?? ip,
              type: _serviceType,
              host: ip,
              port: port,
            );
          }
          return null;
        }),
      );

      for (final s in batchResults) {
        if (s is Service) found.add(s);
      }
    }

    return found;
  }

  Future<InternetAddress?> _localPrivateIpv4BestEffort() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type != InternetAddressType.IPv4) continue;
          if (_isPrivateIPv4(addr.address)) return addr;
        }
      }
    } catch (_) {}
    return null;
  }

  bool _isPrivateIPv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]) ?? -1;
    final b = int.tryParse(parts[1]) ?? -1;
    if (a == 10) return true;
    if (a == 192 && b == 168) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    return false;
  }

  String? _ipv4Prefix24(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}.';
  }

  Future<bool> _tcpPortAcikMi(
    String host,
    int port, {
    required Duration timeout,
  }) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _patisyoServerMi(
    String host,
    int port, {
    required Duration connectTimeout,
  }) async {
    final candidates = _dbCredentialCandidates();
    final settings = ConnectionSettings(
      sslMode: SslMode.disable,
      connectTimeout: connectTimeout,
    );

    for (final c in candidates) {
      Connection? conn;
      try {
        conn = await Connection.open(
          Endpoint(
            host: host,
            port: port,
            database: c.database,
            username: c.username,
            password: c.password,
          ),
          settings: settings,
        );

        final result = await conn.execute(
          "SELECT value FROM public.general_settings WHERE key = 'sunucuModu' LIMIT 1",
        );

        if (result.isNotEmpty) {
          final raw = result.first[0]?.toString().trim().toLowerCase();
          if (raw == 'terminal') return false;
          return true;
        }

        // Kayıt yoksa: default server kabul et (eski kurulumlarla uyumlu).
        return true;
      } catch (_) {
        continue;
      } finally {
        try {
          await conn?.close();
        } catch (_) {}
      }
    }

    return false;
  }

  List<_DbCred> _dbCredentialCandidates() {
    final cfg = VeritabaniYapilandirma();
    final candidates = <_DbCred>[];
    final seen = <String>{};

    void add(String database, String username, String password) {
      final db = database.trim();
      final user = username.trim();
      final pass = password;
      if (db.isEmpty || user.isEmpty) return;
      final key = '$db|$user|$pass';
      if (seen.add(key)) {
        candidates.add(_DbCred(db, user, pass));
      }
    }

    // En olası local kurulum.
    add(_localDefaultDatabase, _localDefaultUsername, _localLegacyPassword);
    add(_localDefaultDatabase, _localDefaultUsername, '');

    // Mevcut config (cloud olabilir, ama bazı kurulumlarda değişmiş local değerleri yakalar).
    add(cfg.database, cfg.username, cfg.password);

    return candidates;
  }

  Future<String?> _reverseLookupBestEffort(String ip) async {
    try {
      final reversed = await InternetAddress(ip)
          .reverse()
          .timeout(const Duration(milliseconds: 250));
      final name = reversed.host.trim();
      if (name.isEmpty) return null;
      if (name == ip) return null;
      return name;
    } catch (_) {
      return null;
    }
  }
}

class _DbCred {
  final String database;
  final String username;
  final String password;

  const _DbCred(this.database, this.username, this.password);
}
