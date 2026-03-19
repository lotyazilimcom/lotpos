import 'dart:async';

import 'package:flutter/foundation.dart';
import '../sayfalar/ayarlar/sirketayarlari/modeller/sirket_ayarlari_model.dart';
import 'bankalar_veritabani_servisi.dart';
import 'buyuk_olcek_arama_bootstrap_servisi.dart';
import 'cari_hesaplar_veritabani_servisi.dart';
import 'cekler_veritabani_servisi.dart';
import 'depolar_veritabani_servisi.dart';
import 'giderler_veritabani_servisi.dart';
import 'kasalar_veritabani_servisi.dart';
import 'kredi_kartlari_veritabani_servisi.dart';
import 'personel_islemleri_veritabani_servisi.dart';
import 'senetler_veritabani_servisi.dart';
import 'siparisler_veritabani_servisi.dart';
import 'teklifler_veritabani_servisi.dart';
import 'uretimler_veritabani_servisi.dart';
import 'urunler_veritabani_servisi.dart';
import 'sirket_veritabani_kimligi.dart';
import 'veritabani_yapilandirma.dart';

class OturumServisi {
  static final OturumServisi _instance = OturumServisi._internal();
  factory OturumServisi() => _instance;
  OturumServisi._internal();

  SirketAyarlariModel? _aktifSirket;
  String? _sonVeritabaniAdi;
  String? _uzakSunucuAktifVeritabaniAdi;
  String? _uzakSunucuAktifSirketKodu;
  String? _uzakSunucuAktifSirketAdi;
  String? _uzakSunucuVeritabaniEtiketi;

  SirketAyarlariModel? get aktifSirket => _aktifSirket;
  String? get uzakSunucuAktifVeritabaniAdi =>
      _normalize(_uzakSunucuAktifVeritabaniAdi);
  String? get uzakSunucuAktifSirketKodu => _normalize(_uzakSunucuAktifSirketKodu);
  String? get uzakSunucuAktifSirketAdi => _normalize(_uzakSunucuAktifSirketAdi);
  String? get uzakSunucuVeritabaniEtiketi =>
      _normalize(_uzakSunucuVeritabaniEtiketi);
  String? get gorunenSirketAdi {
    final remoteName = uzakSunucuAktifSirketAdi;
    if (remoteName != null) return remoteName;

    final activeName = _normalize(_aktifSirket?.ad);
    if (VeritabaniYapilandirma.connectionMode == 'cloud') {
      final cloudDb = _normalize(VeritabaniYapilandirma().database);
      if (activeName == null || activeName == cloudDb) {
        return 'BulutDb';
      }
    }

    return activeName;
  }

  bool get uzakYerelSunucuBaglantisiAktif {
    final mode = VeritabaniYapilandirma.connectionMode;
    if (mode != 'local' && mode != 'hybrid') return false;
    return !VeritabaniYapilandirma.yerelAnaSunucuHostMu(
      VeritabaniYapilandirma.discoveredHost,
    );
  }

  bool get uzakSunucuAktifSirketKilidiVar {
    if (!uzakYerelSunucuBaglantisiAktif) return false;
    return uzakSunucuAktifVeritabaniAdi != null ||
        uzakSunucuAktifSirketKodu != null;
  }

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
      unawaited(_servisleriYenidenBaslat());

      // [2026 GOOGLE-LIKE] Yeni DB için saf PostgreSQL arama/index bootstrap'i (best-effort).
      unawaited(
        BuyukOlcekAramaBootstrapServisi().hazirlaBestEffort(
          databaseName: yeniDb,
        ),
      );
    }
  }

  void uzakSunucuBaglantiBilgisiniGuncelle({
    String? aktifVeritabaniAdi,
    String? aktifSirketKodu,
    String? aktifSirketAdi,
    String? veritabaniEtiketi,
  }) {
    _uzakSunucuAktifVeritabaniAdi = _normalize(aktifVeritabaniAdi);
    _uzakSunucuAktifSirketKodu = _normalize(aktifSirketKodu);
    _uzakSunucuAktifSirketAdi = _normalize(aktifSirketAdi);
    _uzakSunucuVeritabaniEtiketi = _normalize(veritabaniEtiketi);
  }

  void uzakSunucuBaglantiBilgisiniTemizle() {
    _uzakSunucuAktifVeritabaniAdi = null;
    _uzakSunucuAktifSirketKodu = null;
    _uzakSunucuAktifSirketAdi = null;
    _uzakSunucuVeritabaniEtiketi = null;
  }

  String get aktifVeritabaniAdi {
    // Cloud modda tek veritabanı var, doğrudan onu kullan
    if (VeritabaniYapilandirma.connectionMode == 'cloud') {
      return VeritabaniYapilandirma().database;
    }

    final uzakDb = uzakSunucuAktifVeritabaniAdi;
    if (uzakYerelSunucuBaglantisiAktif && uzakDb != null) {
      return uzakDb;
    }

    if (_aktifSirket != null && _aktifSirket!.kod.isNotEmpty) {
      return SirketVeritabaniKimligi.databaseNameFromCompanyCode(
        _aktifSirket!.kod,
      );
    }
    return SirketVeritabaniKimligi.legacyDefaultDatabaseName;
  }

  String get gorunenVeritabaniEtiketi {
    final mode = VeritabaniYapilandirma.connectionMode;
    final aktifDb = aktifVeritabaniAdi.trim();

    if (mode == 'cloud') {
      return 'BulutDb';
    }

    if (mode == 'hybrid') {
      return aktifDb.isEmpty ? 'BulutDb' : '$aktifDb + BulutDb';
    }

    final uzakEtiket = uzakSunucuVeritabaniEtiketi;
    if (uzakYerelSunucuBaglantisiAktif && uzakEtiket != null) {
      return uzakEtiket;
    }

    return aktifDb.isEmpty
        ? SirketVeritabaniKimligi.legacyDefaultDatabaseName
        : aktifDb;
  }

  String? _normalize(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _servisleriYenidenBaslat() async {
    // Tüm servis pool'larını kapat (Ayarlar hariç — o connectionMode üzerinden yönetiliyor)
    await UrunlerVeritabaniServisi().baglantiyiKapat();
    await DepolarVeritabaniServisi().baglantiyiKapat();
    await UretimlerVeritabaniServisi().baglantiyiKapat();
    await GiderlerVeritabaniServisi().baglantiyiKapat();
    await CariHesaplarVeritabaniServisi().baglantiyiKapat();
    await PersonelIslemleriVeritabaniServisi().baglantiyiKapat();
    await SiparislerVeritabaniServisi().baglantiyiKapat();
    await TekliflerVeritabaniServisi().baglantiyiKapat();
    await KasalarVeritabaniServisi().baglantiyiKapat();
    await BankalarVeritabaniServisi().baglantiyiKapat();
    await CeklerVeritabaniServisi().baglantiyiKapat();
    await SenetlerVeritabaniServisi().baglantiyiKapat();
    await KrediKartlariVeritabaniServisi().baglantiyiKapat();

    // Yeni bağlantıları başlat (Lazy loading olduğu için çağrıldıklarında açılacaklar ama
    // burada resetlemek önemli)
  }
}
