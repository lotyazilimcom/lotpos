import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart';
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

  Registration? _registration;
  Discovery? _discovery;

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
    final completer = Completer<Service?>();
    Timer? timeoutTimer;

    try {
      debugPrint('mDNS: Sunucu aranıyor...');
      _discovery = await startDiscovery(_serviceType);

      _discovery!.addServiceListener((service, status) async {
        if (status == ServiceStatus.found) {
          final resolved = await resolve(service);
          debugPrint(
            'mDNS: Sunucu bulundu (Çözüldü): ${resolved.name} IP: ${resolved.host} Port: ${resolved.port}',
          );
          timeoutTimer?.cancel();
          stopDiscovery(_discovery!);
          completer.complete(resolved);
        }
      });

      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          debugPrint('mDNS: Arama zaman aşımına uğradı.');
          stopDiscovery(_discovery!);
          completer.complete(null);
        }
      });
    } catch (e) {
      debugPrint('mDNS Arama hatası: $e');
      if (!completer.isCompleted) completer.complete(null);
    }

    return completer.future;
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
          debugPrint(
            'mDNS: Hızlı tarama ile bulundu: ${resolved.name} IP: ${resolved.host}',
          );
          if (!completer.isCompleted) {
            completer.complete(resolved);
          }
        } catch (e) {
          debugPrint('mDNS: Hızlı çözümleme uyarısı: $e');
          return;
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
}
