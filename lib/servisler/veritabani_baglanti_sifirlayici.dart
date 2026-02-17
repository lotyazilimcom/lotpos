import 'package:flutter/foundation.dart';

import 'ayarlar_veritabani_servisi.dart';
import 'cari_hesaplar_veritabani_servisi.dart';
import 'depolar_veritabani_servisi.dart';
import 'giderler_veritabani_servisi.dart';
import 'personel_islemleri_veritabani_servisi.dart';
import 'siparisler_veritabani_servisi.dart';
import 'teklifler_veritabani_servisi.dart';
import 'uretimler_veritabani_servisi.dart';
import 'urunler_veritabani_servisi.dart';

class VeritabaniBaglantiSifirlayici {
  static final VeritabaniBaglantiSifirlayici _instance =
      VeritabaniBaglantiSifirlayici._internal();
  factory VeritabaniBaglantiSifirlayici() => _instance;
  VeritabaniBaglantiSifirlayici._internal();

  Future<void> tumunuKapat({bool log = false}) async {
    Future<void> safe(String name, Future<void> Function() fn) async {
      try {
        await fn();
      } catch (e) {
        if (log) debugPrint('VeritabaniBaglantiSifirlayici: $name kapatılamadı: $e');
      }
    }

    await Future.wait(<Future<void>>[
      safe('Ayarlar', () => AyarlarVeritabaniServisi().baglantiyiKapat()),
      safe('Depolar', () => DepolarVeritabaniServisi().baglantiyiKapat()),
      safe('Urunler', () => UrunlerVeritabaniServisi().baglantiyiKapat()),
      safe('Uretimler', () => UretimlerVeritabaniServisi().baglantiyiKapat()),
      safe('CariHesaplar', () => CariHesaplarVeritabaniServisi().baglantiyiKapat()),
      safe('Giderler', () => GiderlerVeritabaniServisi().baglantiyiKapat()),
      safe('Personel', () => PersonelIslemleriVeritabaniServisi().baglantiyiKapat()),
      safe('Siparisler', () => SiparislerVeritabaniServisi().baglantiyiKapat()),
      safe('Teklifler', () => TekliflerVeritabaniServisi().baglantiyiKapat()),
    ]);
  }
}
