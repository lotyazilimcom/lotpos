import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nsd/nsd.dart' show Service;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'veritabani_yapilandirma.dart';
import 'local_network_discovery_service.dart';
import 'lisans_servisi.dart';
import 'online_veritabani_servisi.dart';
import 'ayarlar_veritabani_servisi.dart';
import 'veritabani_baglanti_sifirlayici.dart';
import '../yardimcilar/ceviri/ceviri_servisi.dart';
import 'doviz_guncelleme_servisi.dart';

enum BaglantiDurumu {
  baslangic,
  baglaniyor,
  kurulumGerekli,
  bulutKurulumBekleniyor,
  sunucuBulunamadi,
  basarili,
  hata,

  /// Cloud mod'da DB erişilemediğinde (internet yok, DB silinmiş, şifre yanlış vb.)
  bulutErisimHatasi,
}

class BaglantiYoneticisi extends ChangeNotifier {
  static final BaglantiYoneticisi _instance = BaglantiYoneticisi._internal();
  factory BaglantiYoneticisi() => _instance;
  BaglantiYoneticisi._internal();

  static bool _supabaseInitDone = false;

  BaglantiDurumu _durum = BaglantiDurumu.baslangic;
  BaglantiDurumu get durum => _durum;

  String? _hataMesaji;
  String? get hataMesaji => _hataMesaji;

  /// Tüm sistemi başlatan ana döngü
  Future<void> sistemiBaslat() async {
    _durum = BaglantiDurumu.baglaniyor;
    notifyListeners();

    try {
      // Mod değişimi / yeniden başlatma senaryolarında eski pool'lar açık kalırsa,
      // yeni bağlantılar yanlış endpoint'e gidebilir veya arka plan işler sırasında
      // "closed pool / pool lock" hataları tetiklenebilir. Bu yüzden her başlatmada
      // mevcut havuzları best-effort kapat.
      await VeritabaniBaglantiSifirlayici().tumunuKapat();

      // 1. Temel yapılandırmayı yükle (Zaten main'de yüklendi ama burada garantiye alıyoruz)
      await VeritabaniYapilandirma.loadPersistedConfig();

      // 2. Platform kontrolü
      if (kIsWeb) {
        await _standartBaslatma();
      } else if (Platform.isAndroid || Platform.isIOS) {
        await _mobilAkilliBaslatma();
      } else {
        await _masaustuBaslatma();
      }
    } catch (e) {
      _durum = BaglantiDurumu.hata;
      _hataMesaji = e.toString();
      notifyListeners();
    }
  }

  /// Mobil için "Auto-Heal" mantığı (Scenario B)
  Future<void> _mobilAkilliBaslatma() async {
    final prefs = await SharedPreferences.getInstance();
    final kurulumTamamlandi =
        prefs.getBool('mobil_kurulum_tamamlandi') ?? false;
    final hasSavedConnectionMode = prefs.containsKey('patisyo_connection_mode');

    // İlk kurulum tamamlanmadıysa kullanıcıyı mutlaka kurulum ekranına yönlendir.
    // Eski sürümden gelen cihazlarda bağlantı tercihi zaten varsa bir kez normalize ediyoruz.
    if (!kurulumTamamlandi) {
      if (!hasSavedConnectionMode) {
        _durum = BaglantiDurumu.kurulumGerekli;
        notifyListeners();
        return;
      }
      await prefs.setBool('mobil_kurulum_tamamlandi', true);
    }

    final mode = VeritabaniYapilandirma.connectionMode;
    final savedHost = VeritabaniYapilandirma.discoveredHost;

    // A. İlk Kurulum Kontrolü (Scenario A)
    if (mode == 'local' && (savedHost == null || savedHost.isEmpty)) {
      _durum = BaglantiDurumu.kurulumGerekli;
      notifyListeners();
      return;
    }

    // Bulut modu seçiliyse: kimlikler hazır değilse bekleme ekranı
    if (mode == 'cloud' && !VeritabaniYapilandirma.cloudCredentialsReady) {
      final hazir = await _bulutKimlikleriniHazirlaBestEffort();
      if (!hazir) {
        _durum = BaglantiDurumu.bulutKurulumBekleniyor;
        notifyListeners();
        return;
      }
    }

    // B. Mevcut IP'yi Dene (Scenario B - Attempt 1)
    if (mode == 'local') {
      final hedefHost = savedHost!.trim();
      debugPrint('BaglantiYoneticisi: Kayıtlı IP deneniyor: $hedefHost');
      bool bagli = await _baglantiTestEt(
        hedefHost,
        timeout: const Duration(milliseconds: 900),
      );

      if (!bagli) {
        // C. Auto-Heal: IP değişmiş olabilir, yeniden tara (Scenario B - Attempt 2)
        debugPrint(
          'BaglantiYoneticisi: IP yanıt vermiyor, otomatik tarama başlatılıyor...',
        );
        final service = await LocalNetworkDiscoveryService().hizliSunucuBul(
          timeout: const Duration(milliseconds: 1800),
        );

        if (service != null &&
            service.host != null &&
            service.host!.isNotEmpty) {
          final yeniHost = service.host!.trim();
          final yeniHostCanli = await _baglantiTestEt(
            yeniHost,
            timeout: const Duration(milliseconds: 1200),
          );
          if (!yeniHostCanli) {
            debugPrint(
              'BaglantiYoneticisi: Keşfedilen host canlı değil ($yeniHost).',
            );
            _durum = BaglantiDurumu.sunucuBulunamadi;
            notifyListeners();
            return;
          }

          debugPrint('BaglantiYoneticisi: Yeni IP bulundu: $yeniHost');
          // Yeni IP'yi kaydet ve devam et
          await VeritabaniYapilandirma.saveConnectionPreferences(
            'local',
            yeniHost,
          );
          VeritabaniYapilandirma.setDiscoveredHost(yeniHost);
          await _mdnsLisansBilgisiniUygula(service);
        } else {
          debugPrint('BaglantiYoneticisi: Sunucu ağda bulunamadı.');
          _durum = BaglantiDurumu.sunucuBulunamadi;
          notifyListeners();
          return;
        }
      }
    }

    // D. Her şey yolunda, servisleri başlat
    await _standartBaslatma();
  }

  Future<void> _ensureSupabaseInitialized() async {
    if (_supabaseInitDone) return;
    try {
      await Supabase.initialize(url: LisansServisi.u, anonKey: LisansServisi.k);
    } catch (_) {
      // Zaten başlatılmış olabilir.
    } finally {
      _supabaseInitDone = true;
    }
  }

  Future<bool> _bulutKimlikleriniHazirlaBestEffort() async {
    if (VeritabaniYapilandirma.cloudCredentialsReady) return true;

    await _ensureSupabaseInitialized();

    try {
      await LisansServisi().baslat();
    } catch (e) {
      debugPrint('BaglantiYoneticisi: Lisans servisi başlatılamadı: $e');
    }

    final hardwareId = LisansServisi().hardwareId;
    if (hardwareId == null || hardwareId.trim().isEmpty) return false;

    // Admin panel tarafında görünmesi için talebi upsert et (best-effort)
    await OnlineVeritabaniServisi().talepGonder(
      hardwareId: hardwareId.trim(),
      source: 'startup',
    );

    final creds = await OnlineVeritabaniServisi().kimlikleriGetir(
      hardwareId.trim(),
    );
    if (creds == null) return false;

    await VeritabaniYapilandirma.saveCloudDatabaseCredentials(
      host: creds.host,
      port: creds.port,
      username: creds.username,
      password: creds.password,
      database: creds.database,
      sslRequired: creds.sslRequired,
    );

    if (!VeritabaniYapilandirma.cloudCredentialsReady) return false;

    // Kimlikler kaydedilmiş olsa bile Postgres erişilemeyebilir (yanlış şifre/db adı vb.).
    // Mobil akışında da "hazır" saymadan önce bağlantıyı doğrula.
    return VeritabaniYapilandirma.testSavedCloudDatabaseConnection(
      timeout: const Duration(seconds: 8),
    );
  }

  /// Masaüstü başlatma
  Future<void> _masaustuBaslatma() async {
    await _standartBaslatma();

    // Sunucu modundaysa mDNS yayını başlat
    try {
      final ayarlar = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      if (ayarlar.sunucuModu == 'server') {
        LocalNetworkDiscoveryService().yayiniBaslat();
      }
    } catch (e) {
      debugPrint('mDNS Yayını hatası: $e');
    }
  }

  /// Temel servisleri (Supabase, DB, Çeviri vb.) ayağa kaldırır
  Future<void> _standartBaslatma() async {
    // Supabase (Zaten main'de başlatılmış olabilir ama burada da güvenlik için tutabiliriz)
    // Ancak user main'den taşımamı istediği için burada kalması doğru.
    await _ensureSupabaseInitialized();

    // Çeviri
    await CeviriServisi().yukle();

    // Veritabanı (Burada gerçek bağlantı kurulur)
    await AyarlarVeritabaniServisi().baslat();

    // Veritabanı bağlantısı başarısızsa
    if (!AyarlarVeritabaniServisi().baslatildiMi) {
      final sonHata = AyarlarVeritabaniServisi().sonHata ?? '';

      // Cloud modda: özel durum — kullanıcıya "Yerele geç" seçeneği sun
      if (VeritabaniYapilandirma.connectionMode == 'cloud') {
        _hataMesaji = sonHata.isNotEmpty
            ? sonHata
            : 'Bulut veritabanına bağlanılamadı. İnternet bağlantınızı kontrol edin.';
        _durum = BaglantiDurumu.bulutErisimHatasi;
        notifyListeners();
        return;
      }

      // Lokal mod: mevcut davranış
      _durum = BaglantiDurumu.hata;
      _hataMesaji = sonHata.isNotEmpty
          ? sonHata
          : 'Veritabanı bağlantısı kurulamadı. Lütfen bağlantı bilgilerinizi kontrol edin.';
      notifyListeners();
      return;
    }

    // Diğerleri
    DovizGuncellemeServisi().baslat();
    await LisansServisi().baslat();

    _durum = BaglantiDurumu.basarili;
    notifyListeners();
  }

  /// Cloud erişim hatası sonrası yerel veritabanına geçiş yapar.
  /// Kullanıcı onay verdikten sonra çağrılmalıdır.
  Future<void> yereleGec() async {
    debugPrint('BaglantiYoneticisi: Kullanıcı isteğiyle yerele geçiliyor...');
    // Modu local'e çevir ve 127.0.0.1'e bağlan
    await VeritabaniYapilandirma.saveConnectionPreferences(
      'local',
      '127.0.0.1',
    );
    // Var olan cloud pool'larını temizle
    await VeritabaniBaglantiSifirlayici().tumunuKapat();
    // Yapılandırmayı yeniden yükle ve sistemi yeniden başlat
    await VeritabaniYapilandirma.loadPersistedConfig(force: true);
    await sistemiBaslat();
  }

  Future<void> _mdnsLisansBilgisiniUygula(Service service) async {
    try {
      final txt = service.txt;
      if (txt == null || txt['isPro'] == null) return;
      final inherited = utf8.decode(txt['isPro']!) == 'true';
      await LisansServisi().setInheritedPro(inherited);
    } catch (e) {
      debugPrint('BaglantiYoneticisi: mDNS lisans bilgisi çözümlenemedi: $e');
    }
  }

  /// Basit bir soket bağlantısı ile IP'nin canlı olup olmadığını test eder
  Future<bool> _baglantiTestEt(
    String host, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final port = VeritabaniYapilandirma().port;
      final socket = await Socket.connect(host, port, timeout: timeout);
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }
}
