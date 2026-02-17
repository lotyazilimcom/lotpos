import 'package:flutter/foundation.dart';
import '../sayfalar/ayarlar/sirketayarlari/modeller/sirket_ayarlari_model.dart';
import 'depolar_veritabani_servisi.dart';
import 'giderler_veritabani_servisi.dart';
import 'uretimler_veritabani_servisi.dart';
import 'urunler_veritabani_servisi.dart';
import 'veritabani_yapilandirma.dart';

class OturumServisi {
  static final OturumServisi _instance = OturumServisi._internal();
  factory OturumServisi() => _instance;
  OturumServisi._internal();

  SirketAyarlariModel? _aktifSirket;
  String? _sonVeritabaniAdi;

  SirketAyarlariModel? get aktifSirket => _aktifSirket;

  set aktifSirket(SirketAyarlariModel? sirket) {
    final oncekiDb = aktifVeritabaniAdi;
    _aktifSirket = sirket;
    debugPrint('Aktif Şirket Değişti: ${sirket?.ad} (DB: $aktifVeritabaniAdi)');

    final yeniDb = aktifVeritabaniAdi;
    _sonVeritabaniAdi ??= oncekiDb;

    // Şirket değişse bile efektif veritabanı aynıysa (özellikle Bulut modunda)
    // pool'ları kapatmak gereksiz ve arka plandaki işler sırasında "closed pool" hatasına
    // sebep olabiliyor. Sadece DB adı gerçekten değiştiğinde sıfırla.
    if (_sonVeritabaniAdi != yeniDb) {
      _sonVeritabaniAdi = yeniDb;
      _servisleriYenidenBaslat();
    }
  }

  String get aktifVeritabaniAdi {
    // Cloud modda tek veritabanı var, doğrudan onu kullan
    if (VeritabaniYapilandirma.connectionMode == 'cloud') {
      return VeritabaniYapilandirma().database;
    }

    if (_aktifSirket != null && _aktifSirket!.kod.isNotEmpty) {
      // Özel durum: Varsayılan şirket kodu 'patisyo2025' ise, eski veritabanını kullan
      if (_aktifSirket!.kod == 'patisyo2025') {
        return 'patisyo2025';
      }

      // Şirket kodunu güvenli dosya/db ismine çevir (sadece harf ve rakam)
      final safeCode = _aktifSirket!.kod
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
      return 'patisyo_$safeCode';
    }
    return 'patisyo2025'; // Varsayılan DB
  }

  Future<void> _servisleriYenidenBaslat() async {
    await UrunlerVeritabaniServisi().baglantiyiKapat();
    await DepolarVeritabaniServisi().baglantiyiKapat();
    await UretimlerVeritabaniServisi().baglantiyiKapat();
    await GiderlerVeritabaniServisi().baglantiyiKapat();

    // Yeni bağlantıları başlat (Lazy loading olduğu için çağrıldıklarında açılacaklar ama
    // burada resetlemek önemli)
  }
}
