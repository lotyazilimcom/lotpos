import 'package:flutter/material.dart';

/// İşlem türlerine göre modern ve soluk renkler döndüren yardımcı sınıf.
/// Tüm sayfalarda tutarlı renk kullanımı sağlar.
class IslemTuruRenkleri {
  IslemTuruRenkleri._();

  // ==========================================================================
  // AÇILIŞ STOĞU - Soft Indigo / Mavi
  // ==========================================================================
  static const Color acilisStokuArkaplan = Color(0xFFE8EAF6); // Indigo 50
  static const Color acilisStokuMetin = Color(0xFF3949AB); // Indigo 600
  static const Color acilisStokuIkon = Color(0xFF5C6BC0); // Indigo 400

  // ==========================================================================
  // DEVİR GİRDİ / DEVİR ÇIKTI - Soft Purple / Mor
  // ==========================================================================
  static const Color devirArkaplan = Color(0xFFF3E5F5); // Purple 50
  static const Color devirMetin = Color(0xFF7B1FA2); // Purple 700
  static const Color devirIkon = Color(0xFFAB47BC); // Purple 400

  // ==========================================================================
  // ÜRETİM (Girdi/Çıktı) - Soft Amber / Turuncu
  // ==========================================================================
  static const Color uretimArkaplan = Color(0xFFFFF8E1); // Amber 50
  static const Color uretimMetin = Color(0xFFFF8F00); // Amber 800
  static const Color uretimIkon = Color(0xFFFFB300); // Amber 600

  // ==========================================================================
  // SEVKİYAT GİRDİ - Soft Teal / Yeşil
  // ==========================================================================
  static const Color sevkiyatGirdiArkaplan = Color(0xFFE0F2F1); // Teal 50
  static const Color sevkiyatGirdiMetin = Color(0xFF00796B); // Teal 700
  static const Color sevkiyatGirdiIkon = Color(0xFF26A69A); // Teal 400

  // ==========================================================================
  // SEVKİYAT ÇIKTI - Soft Rose / Kırmızı
  // ==========================================================================
  static const Color sevkiyatCiktiArkaplan = Color(0xFFFFEBEE); // Red 50
  static const Color sevkiyatCiktiMetin = Color(0xFFC62828); // Red 800
  static const Color sevkiyatCiktiIkon = Color(0xFFEF5350); // Red 400

  // ==========================================================================
  // VARSAYILAN GİRDİ (Fallback) - Soft Green
  // ==========================================================================
  static const Color varsayilanGirdiArkaplan = Color(0xFFE8F5E9); // Green 50
  static const Color varsayilanGirdiMetin = Color(0xFF2E7D32); // Green 700
  static const Color varsayilanGirdiIkon = Color(0xFF66BB6A); // Green 400

  // ==========================================================================
  // VARSAYILAN ÇIKTI (Fallback) - Soft Red
  // ==========================================================================
  static const Color varsayilanCiktiArkaplan = Color(0xFFFCE4EC); // Pink 50
  static const Color varsayilanCiktiMetin = Color(0xFFC2185B); // Pink 700
  static const Color varsayilanCiktiIkon = Color(0xFFEC407A); // Pink 400

  // ==========================================================================
  // ÇEK/SENET - ALINAN - Soft Teal / Yeşil
  // ==========================================================================
  static const Color cekAlinanArkaplan = Color(0xFFE0F7FA); // Cyan 50
  static const Color cekAlinanMetin = Color(0xFF00838F); // Cyan 800
  static const Color cekAlinanIkon = Color(0xFF00ACC1); // Cyan 600

  // ==========================================================================
  // ÇEK/SENET - VERİLEN - Soft Deep Orange / Turuncu
  // ==========================================================================
  static const Color cekVerilenArkaplan = Color(0xFFFBE9E7); // Deep Orange 50
  static const Color cekVerilenMetin = Color(0xFFD84315); // Deep Orange 800
  static const Color cekVerilenIkon = Color(0xFFFF7043); // Deep Orange 400

  // ==========================================================================
  // ÇEK/SENET - TAHSİL - Soft Green
  // ==========================================================================
  static const Color cekTahsilArkaplan = Color(0xFFE8F5E9); // Green 50
  static const Color cekTahsilMetin = Color(0xFF2E7D32); // Green 800
  static const Color cekTahsilIkon = Color(0xFF66BB6A); // Green 400

  // ==========================================================================
  // ÇEK/SENET - CİRO - Soft Blue
  // ==========================================================================
  static const Color cekCiroArkaplan = Color(0xFFE3F2FD); // Blue 50
  static const Color cekCiroMetin = Color(0xFF1565C0); // Blue 700
  static const Color cekCiroIkon = Color(0xFF42A5F5); // Blue 400

  // ==========================================================================
  // CARİ HESAP - BORÇ DEKONTU - Soft Red/Rose
  // ==========================================================================
  static const Color borcDekontuArkaplan = Color(0xFFFFEBEE); // Red 50
  static const Color borcDekontuMetin = Color(0xFFC62828); // Red 800
  static const Color borcDekontuIkon = Color(0xFFEF5350); // Red 400

  // ==========================================================================
  // CARİ HESAP - ALACAK DEKONTU - Soft Green
  // ==========================================================================
  static const Color alacakDekontuArkaplan = Color(0xFFE8F5E9); // Green 50
  static const Color alacakDekontuMetin = Color(0xFF2E7D32); // Green 700
  static const Color alacakDekontuIkon = Color(0xFF66BB6A); // Green 400

  // ==========================================================================
  // CARİ HESAP - TAHSİLAT - Soft Teal
  // ==========================================================================
  static const Color tahsilatArkaplan = Color(0xFFE0F2F1); // Teal 50
  static const Color tahsilatMetin = Color(0xFF00796B); // Teal 700
  static const Color tahsilatIkon = Color(0xFF26A69A); // Teal 400

  // ==========================================================================
  // CARİ HESAP - ÖDEME - Soft Deep Orange
  // ==========================================================================
  static const Color odemeArkaplan = Color(0xFFFBE9E7); // Deep Orange 50
  static const Color odemeMetin = Color(0xFFD84315); // Deep Orange 800
  static const Color odemeIkon = Color(0xFFFF7043); // Deep Orange 400

  // ==========================================================================
  // CARİ HESAP - SATIŞ - Soft Indigo
  // ==========================================================================
  static const Color satisArkaplan = Color(0xFFE8EAF6); // Indigo 50
  static const Color satisMetin = Color(0xFF3949AB); // Indigo 600
  static const Color satisIkon = Color(0xFF5C6BC0); // Indigo 400

  // ==========================================================================
  // CARİ HESAP - ALIŞ - Soft Amber
  // ==========================================================================
  static const Color alisArkaplan = Color(0xFFFFF8E1); // Amber 50
  static const Color alisMetin = Color(0xFFFF8F00); // Amber 800
  static const Color alisIkon = Color(0xFFFFB300); // Amber 600

  // ==========================================================================
  // KASA - PARA GİRİŞİ - Soft Light Green
  // ==========================================================================
  static const Color kasaGirisArkaplan = Color(0xFFF1F8E9); // Light Green 50
  static const Color kasaGirisMetin = Color(0xFF558B2F); // Light Green 700
  static const Color kasaGirisIkon = Color(0xFF8BC34A); // Light Green 400

  // ==========================================================================
  // KASA - PARA ÇIKIŞI - Soft Brown
  // ==========================================================================
  static const Color kasaCikisArkaplan = Color(0xFFEFEBE9); // Brown 50
  static const Color kasaCikisMetin = Color(0xFF5D4037); // Brown 700
  static const Color kasaCikisIkon = Color(0xFF8D6E63); // Brown 400

  // ==========================================================================
  // BANKA - HAVALE/EFT GİRİŞİ - Soft Light Blue
  // ==========================================================================
  static const Color bankaGirisArkaplan = Color(0xFFE1F5FE); // Light Blue 50
  static const Color bankaGirisMetin = Color(0xFF0277BD); // Light Blue 800
  static const Color bankaGirisIkon = Color(0xFF29B6F6); // Light Blue 400

  // ==========================================================================
  // BANKA - HAVALE/EFT ÇIKIŞI - Soft Blue Grey
  // ==========================================================================
  static const Color bankaCikisArkaplan = Color(0xFFECEFF1); // Blue Grey 50
  static const Color bankaCikisMetin = Color(0xFF455A64); // Blue Grey 700
  static const Color bankaCikisIkon = Color(0xFF78909C); // Blue Grey 400

  // ==========================================================================
  // ÇEK/SENET - KARŞILIKSIZ - Soft Red
  // ==========================================================================
  static const Color karsiliksizArkaplan = Color(0xFFFFEBEE); // Red 50
  static const Color karsiliksizMetin = Color(0xFFC62828); // Red 800
  static const Color karsiliksizIkon = Color(0xFFEF5350); // Red 400

  // ==========================================================================
  // KREDİ KARTI - TAHSİLAT (Giriş) - Soft Deep Purple
  // ==========================================================================
  static const Color krediKartiGirisArkaplan = Color(
    0xFFEDE7F6,
  ); // Deep Purple 50
  static const Color krediKartiGirisMetin = Color(
    0xFF512DA8,
  ); // Deep Purple 700
  static const Color krediKartiGirisIkon = Color(0xFF7E57C2); // Deep Purple 400

  // ==========================================================================
  // KREDİ KARTI - HARCAMA (Çıkış) - Soft Grey
  // ==========================================================================
  static const Color krediKartiCikisArkaplan = Color(0xFFFAFAFA); // Grey 50
  static const Color krediKartiCikisMetin = Color(0xFF616161); // Grey 700
  static const Color krediKartiCikisIkon = Color(0xFF9E9E9E); // Grey 500

  // ==========================================================================
  // PERSONEL - MAAŞ ÖDEMESİ - Soft Lime
  // ==========================================================================
  static const Color personelMaasArkaplan = Color(0xFFF9FBE7); // Lime 50
  static const Color personelMaasMetin = Color(0xFF9E9D24); // Lime 800
  static const Color personelMaasIkon = Color(0xFFCDDC39); // Lime 500

  // ==========================================================================
  // PERSONEL - AVANS ÖDEMESİ - Soft Yellow
  // ==========================================================================
  static const Color personelAvansArkaplan = Color(0xFFFFFDE7); // Yellow 50
  static const Color personelAvansMetin = Color(0xFFF9A825); // Yellow 800
  static const Color personelAvansIkon = Color(0xFFFFEB3B); // Yellow 500

  // ==========================================================================
  // FATURA - SATIŞ FATURASI - Soft Indigo (Satış ile aynı)
  // ==========================================================================
  static const Color satisFaturasiArkaplan = Color(0xFFE8EAF6); // Indigo 50
  static const Color satisFaturasiMetin = Color(0xFF3949AB); // Indigo 600
  static const Color satisFaturasiIkon = Color(0xFF5C6BC0); // Indigo 400

  // ==========================================================================
  // FATURA - ALIŞ FATURASI - Soft Amber (Alış ile aynı)
  // ==========================================================================
  static const Color alisFaturasiArkaplan = Color(0xFFFFF8E1); // Amber 50
  static const Color alisFaturasiMetin = Color(0xFFFF8F00); // Amber 800
  static const Color alisFaturasiIkon = Color(0xFFFFB300); // Amber 600

  // ==========================================================================
  // KISMİ İŞLEMLER - Soft Cyan / Turkuaz
  // ==========================================================================
  static const Color kismiArkaplan = Color(0xFFE0F7FA); // Cyan 50
  static const Color kismiMetin = Color(0xFF00838F); // Cyan 800
  static const Color kismiIkon = Color(0xFF00ACC1); // Cyan 600

  // ==========================================================================
  // SİPARİŞ / TEKLİF TÜRLERİ - Order Types
  // ==========================================================================
  static const Color siparisArkaplan = Color(0xFFE0F2FE); // Sky 100
  static const Color siparisMetin = Color(0xFF0369A1); // Sky 700
  static const Color siparisIkon = Color(0xFF38BDF8); // Sky 400

  static const Color teklifArkaplan = Color(0xFFF1F5F9); // Slate 100
  static const Color teklifMetin = Color(0xFF334155); // Slate 700
  static const Color teklifIkon = Color(0xFF64748B); // Slate 500

  // ==========================================================================
  // CARİ HESAP TÜRLERİ - Account Types (Alıcı, Satıcı, Alıcı/Satıcı)
  // ==========================================================================
  static const Color aliciArkaplan = Color(0xFFE8F5E9); // Green 50
  static const Color aliciMetin = Color(0xFF2E7D32); // Green 700
  static const Color aliciIkon = Color(0xFF66BB6A); // Green 400

  static const Color saticiArkaplan = Color(0xFFFFF3E0); // Orange 50
  static const Color saticiMetin = Color(0xFFE65100); // Orange 900
  static const Color saticiIkon = Color(0xFFFFA726); // Orange 400

  static const Color aliciSaticiArkaplan = Color(0xFFF3E5F5); // Purple 50
  static const Color aliciSaticiMetin = Color(0xFF7B1FA2); // Purple 700
  static const Color aliciSaticiIkon = Color(0xFFAB47BC); // Purple 400

  /// İşlem türüne göre arka plan rengi döndürür.
  static Color arkaplanRengiGetir(String? customTypeLabel, bool isIncoming) {
    if (customTypeLabel == null) {
      return isIncoming ? varsayilanGirdiArkaplan : varsayilanCiktiArkaplan;
    }

    final label = customTypeLabel.toLowerCase();

    if (label.contains('açılış stoğu') || label.contains('acilis stogu')) {
      return acilisStokuArkaplan;
    } else if (label.contains('devir')) {
      return devirArkaplan;
    } else if (label.contains('üretim') || label.contains('uretim')) {
      return uretimArkaplan;
    } else if (label.contains('sevkiyat')) {
      return isIncoming ? sevkiyatGirdiArkaplan : sevkiyatCiktiArkaplan;
    } else if (label.contains('tahsil')) {
      return cekTahsilArkaplan;
    } else if (label.contains('ciro')) {
      return cekCiroArkaplan;
    } else if (label.contains('alınan') ||
        label.contains('alinan') ||
        label.contains('alındı') ||
        label.contains('alindi')) {
      return cekAlinanArkaplan;
    } else if (label.contains('verilen') || label.contains('verildi')) {
      return cekVerilenArkaplan;
    } else if (label.contains('borç dekontu') ||
        label.contains('borc dekontu')) {
      return borcDekontuArkaplan;
    } else if (label.contains('alacak dekontu')) {
      return alacakDekontuArkaplan;
    } else if (label.contains('tahsilat')) {
      return tahsilatArkaplan;
    } else if (label.contains('ödeme') || label.contains('odeme')) {
      return odemeArkaplan;
    } else if (label.contains('satış') || label.contains('satis')) {
      return satisArkaplan;
    } else if (label.contains('alış') || label.contains('alis')) {
      return alisArkaplan;
    } else if (label.contains('kasa') &&
        (label.contains('gir') || label.contains('giriş'))) {
      return kasaGirisArkaplan;
    } else if (label.contains('kasa') &&
        (label.contains('çık') ||
            label.contains('cik') ||
            label.contains('çıkış'))) {
      return kasaCikisArkaplan;
    } else if (label.contains('banka') &&
        (label.contains('gir') ||
            label.contains('havale') ||
            label.contains('eft'))) {
      return bankaGirisArkaplan;
    } else if (label.contains('banka') &&
        (label.contains('çık') || label.contains('cik'))) {
      return bankaCikisArkaplan;
    } else if (label.contains('kredi') &&
        label.contains('kart') &&
        (label.contains('gir') || label.contains('tahsil'))) {
      return krediKartiGirisArkaplan;
    } else if (label.contains('kredi') &&
        label.contains('kart') &&
        (label.contains('çık') ||
            label.contains('cik') ||
            label.contains('harcama'))) {
      return krediKartiCikisArkaplan;
    } else if (label.contains('maaş') || label.contains('maas')) {
      return personelMaasArkaplan;
    } else if (label.contains('avans')) {
      return personelAvansArkaplan;
    } else if (label.contains('fatura') &&
        (label.contains('satış') || label.contains('satis'))) {
      return satisFaturasiArkaplan;
    } else if (label.contains('fatura') &&
        (label.contains('alış') || label.contains('alis'))) {
      return alisFaturasiArkaplan;
    } else if (label.contains('beklemede')) {
      return const Color(0xFFFFF3E0); // Orange 50
    } else if (label.contains('onaylandı') ||
        label.contains('tamamlandi') ||
        label.contains('onaylandi') ||
        label.contains('satış yapıldı')) {
      return const Color(0xFFE8F5E9); // Green 50
    } else if (label.contains('iptal') || label.contains('redd edildi')) {
      return const Color(0xFFFFEBEE); // Red 50
    } else if (label.contains('teklif')) {
      return teklifArkaplan;
    } else if (label.contains('sipariş') || label.contains('siparis')) {
      return siparisArkaplan;
    } else if (label.contains('karşılıksız') || label.contains('karşiliksiz')) {
      return karsiliksizArkaplan;
    } else if (label.contains('alıcı/satıcı') ||
        label.contains('alici/satici')) {
      return aliciSaticiArkaplan;
    } else if (label.contains('alıcı') || label.contains('alici')) {
      return aliciArkaplan;
    } else if (label.contains('satıcı') || label.contains('satici')) {
      return saticiArkaplan;
    }

    return isIncoming ? varsayilanGirdiArkaplan : varsayilanCiktiArkaplan;
  }

  /// İşlem türüne göre metin rengi döndürür.
  static Color metinRengiGetir(String? customTypeLabel, bool isIncoming) {
    if (customTypeLabel == null) {
      return isIncoming ? varsayilanGirdiMetin : varsayilanCiktiMetin;
    }

    final label = customTypeLabel.toLowerCase();

    if (label.contains('açılış stoğu') || label.contains('acilis stogu')) {
      return acilisStokuMetin;
    } else if (label.contains('devir')) {
      return devirMetin;
    } else if (label.contains('üretim') || label.contains('uretim')) {
      return uretimMetin;
    } else if (label.contains('sevkiyat')) {
      return isIncoming ? sevkiyatGirdiMetin : sevkiyatCiktiMetin;
    } else if (label.contains('tahsil')) {
      return cekTahsilMetin;
    } else if (label.contains('ciro')) {
      return cekCiroMetin;
    } else if (label.contains('alınan') ||
        label.contains('alinan') ||
        label.contains('alındı') ||
        label.contains('alindi')) {
      return cekAlinanMetin;
    } else if (label.contains('verilen') || label.contains('verildi')) {
      return cekVerilenMetin;
    } else if (label.contains('borç dekontu') ||
        label.contains('borc dekontu')) {
      return borcDekontuMetin;
    } else if (label.contains('alacak dekontu')) {
      return alacakDekontuMetin;
    } else if (label.contains('tahsilat')) {
      return tahsilatMetin;
    } else if (label.contains('ödeme') || label.contains('odeme')) {
      return odemeMetin;
    } else if (label.contains('satış') || label.contains('satis')) {
      return satisMetin;
    } else if (label.contains('alış') || label.contains('alis')) {
      return alisMetin;
    } else if (label.contains('kasa') &&
        (label.contains('gir') || label.contains('giriş'))) {
      return kasaGirisMetin;
    } else if (label.contains('kasa') &&
        (label.contains('çık') ||
            label.contains('cik') ||
            label.contains('çıkış'))) {
      return kasaCikisMetin;
    } else if (label.contains('banka') &&
        (label.contains('gir') ||
            label.contains('havale') ||
            label.contains('eft'))) {
      return bankaGirisMetin;
    } else if (label.contains('banka') &&
        (label.contains('çık') || label.contains('cik'))) {
      return bankaCikisMetin;
    } else if (label.contains('kredi') &&
        label.contains('kart') &&
        (label.contains('gir') || label.contains('tahsil'))) {
      return krediKartiGirisMetin;
    } else if (label.contains('kredi') &&
        label.contains('kart') &&
        (label.contains('çık') ||
            label.contains('cik') ||
            label.contains('harcama'))) {
      return krediKartiCikisMetin;
    } else if (label.contains('maaş') || label.contains('maas')) {
      return personelMaasMetin;
    } else if (label.contains('avans')) {
      return personelAvansMetin;
    } else if (label.contains('fatura') &&
        (label.contains('satış') || label.contains('satis'))) {
      return satisFaturasiMetin;
    } else if (label.contains('fatura') &&
        (label.contains('alış') || label.contains('alis'))) {
      return alisFaturasiMetin;
    } else if (label.contains('beklemede')) {
      return const Color(0xFFF39C12); // Orange 800
    } else if (label.contains('onaylandı') ||
        label.contains('tamamlandi') ||
        label.contains('onaylandi') ||
        label.contains('satış yapıldı')) {
      return const Color(0xFF2E7D32); // Green 800
    } else if (label.contains('iptal') || label.contains('redd edildi')) {
      return const Color(0xFFC62828); // Red 800
    } else if (label.contains('teklif')) {
      return teklifMetin;
    } else if (label.contains('sipariş') || label.contains('siparis')) {
      return siparisMetin;
    } else if (label.contains('karşılıksız') || label.contains('karşiliksiz')) {
      return karsiliksizMetin;
    } else if (label.contains('alıcı/satıcı') ||
        label.contains('alici/satici')) {
      return aliciSaticiMetin;
    } else if (label.contains('alıcı') || label.contains('alici')) {
      return aliciMetin;
    } else if (label.contains('satıcı') || label.contains('satici')) {
      return saticiMetin;
    }

    return isIncoming ? varsayilanGirdiMetin : varsayilanCiktiMetin;
  }

  /// İşlem türüne göre ikon rengi döndürür.
  static Color ikonRengiGetir(String? customTypeLabel, bool isIncoming) {
    if (customTypeLabel == null) {
      return isIncoming ? varsayilanGirdiIkon : varsayilanCiktiIkon;
    }

    final label = customTypeLabel.toLowerCase();

    if (label.contains('açılış stoğu') || label.contains('acilis stogu')) {
      return acilisStokuIkon;
    } else if (label.contains('devir')) {
      return devirIkon;
    } else if (label.contains('üretim') || label.contains('uretim')) {
      return uretimIkon;
    } else if (label.contains('sevkiyat')) {
      return isIncoming ? sevkiyatGirdiIkon : sevkiyatCiktiIkon;
    } else if (label.contains('tahsil')) {
      return cekTahsilIkon;
    } else if (label.contains('ciro')) {
      return cekCiroIkon;
    } else if (label.contains('alınan') ||
        label.contains('alinan') ||
        label.contains('alındı') ||
        label.contains('alindi')) {
      return cekAlinanIkon;
    } else if (label.contains('verilen') || label.contains('verildi')) {
      return cekVerilenIkon;
    } else if (label.contains('borç dekontu') ||
        label.contains('borc dekontu')) {
      return borcDekontuIkon;
    } else if (label.contains('alacak dekontu')) {
      return alacakDekontuIkon;
    } else if (label.contains('tahsilat')) {
      return tahsilatIkon;
    } else if (label.contains('ödeme') || label.contains('odeme')) {
      return odemeIkon;
    } else if (label.contains('satış') || label.contains('satis')) {
      return satisIkon;
    } else if (label.contains('alış') || label.contains('alis')) {
      return alisIkon;
    } else if (label.contains('kasa') &&
        (label.contains('gir') || label.contains('giriş'))) {
      return kasaGirisIkon;
    } else if (label.contains('kasa') &&
        (label.contains('çık') ||
            label.contains('cik') ||
            label.contains('çıkış'))) {
      return kasaCikisIkon;
    } else if (label.contains('banka') &&
        (label.contains('gir') ||
            label.contains('havale') ||
            label.contains('eft'))) {
      return bankaGirisIkon;
    } else if (label.contains('banka') &&
        (label.contains('çık') || label.contains('cik'))) {
      return bankaCikisIkon;
    } else if (label.contains('kredi') &&
        label.contains('kart') &&
        (label.contains('gir') || label.contains('tahsil'))) {
      return krediKartiGirisIkon;
    } else if (label.contains('kredi') &&
        label.contains('kart') &&
        (label.contains('çık') ||
            label.contains('cik') ||
            label.contains('harcama'))) {
      return krediKartiCikisIkon;
    } else if (label.contains('maaş') || label.contains('maas')) {
      return personelMaasIkon;
    } else if (label.contains('avans')) {
      return personelAvansIkon;
    } else if (label.contains('fatura') &&
        (label.contains('satış') || label.contains('satis'))) {
      return satisFaturasiIkon;
    } else if (label.contains('fatura') &&
        (label.contains('alış') || label.contains('alis'))) {
      return alisFaturasiIkon;
    } else if (label.contains('kısmi satış') || label.contains('kismi satis')) {
      return kismiIkon;
    } else if (label.contains('kısmi sevk') || label.contains('kismi sevk')) {
      return kismiIkon;
    } else if (label.contains('kısmi ödeme') || label.contains('kismi odeme')) {
      return kismiIkon;
    } else if (label.contains('kısmi') || label.contains('kismi')) {
      return kismiIkon;
    } else if (label.contains('beklemede')) {
      return const Color(0xFFF59E0B); // Amber 500
    } else if (label.contains('onaylandı') ||
        label.contains('tamamlandi') ||
        label.contains('onaylandi') ||
        label.contains('satış yapıldı')) {
      return const Color(0xFF10B981); // Emerald 500
    } else if (label.contains('teklif')) {
      return teklifIkon;
    } else if (label.contains('sipariş') || label.contains('siparis')) {
      return siparisIkon;
    } else if (label.contains('karşılıksız') || label.contains('karşiliksiz')) {
      return karsiliksizIkon;
    } else if (label.contains('alıcı/satıcı') ||
        label.contains('alici/satici')) {
      return aliciSaticiIkon;
    } else if (label.contains('alıcı') || label.contains('alici')) {
      return aliciIkon;
    } else if (label.contains('satıcı') || label.contains('satici')) {
      return saticiIkon;
    }

    return isIncoming ? varsayilanGirdiIkon : varsayilanCiktiIkon;
  }

  /// İşlem türüne göre arka plan rengi döndürür (basitleştirilmiş - isIncoming gerektirmez)
  static Color getBackgroundColor(String? islemTuru) {
    if (islemTuru == null || islemTuru.isEmpty) {
      return varsayilanGirdiArkaplan;
    }

    final label = islemTuru.toLowerCase();

    if (label.contains('açılış stoğu') || label.contains('acilis stogu')) {
      return acilisStokuArkaplan;
    } else if (label.contains('devir')) {
      return devirArkaplan;
    } else if (label.contains('üretim') || label.contains('uretim')) {
      return uretimArkaplan;
    } else if (label.contains('sevkiyat')) {
      return label.contains('çıkış') || label.contains('cikis')
          ? sevkiyatCiktiArkaplan
          : sevkiyatGirdiArkaplan;
    } else if (label.contains('tahsilat')) {
      return tahsilatArkaplan;
    } else if (label.contains('ödeme') || label.contains('odeme')) {
      return odemeArkaplan;
    } else if (label.contains('borç dekontu') ||
        label.contains('borc dekontu')) {
      return borcDekontuArkaplan;
    } else if (label.contains('alacak dekontu')) {
      return alacakDekontuArkaplan;
    } else if (label.contains('satış') || label.contains('satis')) {
      return satisArkaplan;
    } else if (label.contains('alış') || label.contains('alis')) {
      return alisArkaplan;
    } else if (label.contains('tahsil')) {
      return cekTahsilArkaplan;
    } else if (label.contains('ciro')) {
      return cekCiroArkaplan;
    } else if (label.contains('alınan') ||
        label.contains('alinan') ||
        label.contains('alındı') ||
        label.contains('alindi')) {
      return cekAlinanArkaplan;
    } else if (label.contains('verilen') || label.contains('verildi')) {
      return cekVerilenArkaplan;
    } else if (label.contains('kasa') &&
        (label.contains('gir') || label.contains('giriş'))) {
      return kasaGirisArkaplan;
    } else if (label.contains('kasa') &&
        (label.contains('çık') ||
            label.contains('cik') ||
            label.contains('çıkış'))) {
      return kasaCikisArkaplan;
    } else if (label.contains('banka') &&
        (label.contains('gir') ||
            label.contains('havale') ||
            label.contains('eft'))) {
      return bankaGirisArkaplan;
    } else if (label.contains('banka') &&
        (label.contains('çık') || label.contains('cik'))) {
      return bankaCikisArkaplan;
    } else if (label.contains('kredi') &&
        label.contains('kart') &&
        (label.contains('gir') || label.contains('tahsil'))) {
      return krediKartiGirisArkaplan;
    } else if (label.contains('kredi') &&
        label.contains('kart') &&
        (label.contains('çık') ||
            label.contains('cik') ||
            label.contains('harcama'))) {
      return krediKartiCikisArkaplan;
    } else if (label.contains('maaş') || label.contains('maas')) {
      return personelMaasArkaplan;
    } else if (label.contains('avans')) {
      return personelAvansArkaplan;
    } else if (label.contains('fatura') &&
        (label.contains('satış') || label.contains('satis'))) {
      return satisFaturasiArkaplan;
    } else if (label.contains('fatura') &&
        (label.contains('alış') || label.contains('alis'))) {
      return alisFaturasiArkaplan;
    } else if (label.contains('beklemede')) {
      return const Color(0xFFFEF3C7); // Amber 100
    } else if (label.contains('onaylandı') ||
        label.contains('tamamlandi') ||
        label.contains('onaylandi') ||
        label.contains('satış yapıldı')) {
      return const Color(0xFFDCFCE7); // Emerald 100
    } else if (label.contains('iptal') || label.contains('redd edildi')) {
      return const Color(0xFFFFE4E6); // Rose 100
    } else if (label.contains('teklif')) {
      return teklifArkaplan;
    } else if (label.contains('sipariş') || label.contains('siparis')) {
      return siparisArkaplan;
    } else if (label.contains('karşılıksız') || label.contains('karşiliksiz')) {
      return karsiliksizArkaplan;
    } else if (label.contains('alıcı/satıcı') ||
        label.contains('alici/satici')) {
      return aliciSaticiArkaplan;
    } else if (label.contains('alıcı') || label.contains('alici')) {
      return aliciArkaplan;
    } else if (label.contains('satıcı') || label.contains('satici')) {
      return saticiArkaplan;
    }

    return varsayilanGirdiArkaplan;
  }

  /// İşlem türüne göre metin rengi döndürür (basitleştirilmiş - isIncoming gerektirmez)
  static Color getTextColor(String? islemTuru) {
    if (islemTuru == null || islemTuru.isEmpty) {
      return varsayilanGirdiMetin;
    }

    final label = islemTuru.toLowerCase();

    if (label.contains('açılış stoğu') || label.contains('acilis stogu')) {
      return acilisStokuMetin;
    } else if (label.contains('devir')) {
      return devirMetin;
    } else if (label.contains('üretim') || label.contains('uretim')) {
      return uretimMetin;
    } else if (label.contains('sevkiyat')) {
      return label.contains('çıkış') || label.contains('cikis')
          ? sevkiyatCiktiMetin
          : sevkiyatGirdiMetin;
    } else if (label.contains('tahsilat')) {
      return tahsilatMetin;
    } else if (label.contains('ödeme') || label.contains('odeme')) {
      return odemeMetin;
    } else if (label.contains('borç dekontu') ||
        label.contains('borc dekontu')) {
      return borcDekontuMetin;
    } else if (label.contains('alacak dekontu')) {
      return alacakDekontuMetin;
    } else if (label.contains('satış') || label.contains('satis')) {
      return satisMetin;
    } else if (label.contains('alış') || label.contains('alis')) {
      return alisMetin;
    } else if (label.contains('tahsil')) {
      return cekTahsilMetin;
    } else if (label.contains('ciro')) {
      return cekCiroMetin;
    } else if (label.contains('alınan') ||
        label.contains('alinan') ||
        label.contains('alındı') ||
        label.contains('alindi')) {
      return cekAlinanMetin;
    } else if (label.contains('verilen') || label.contains('verildi')) {
      return cekVerilenMetin;
    } else if (label.contains('kasa') &&
        (label.contains('gir') || label.contains('giriş'))) {
      return kasaGirisMetin;
    } else if (label.contains('kasa') &&
        (label.contains('çık') ||
            label.contains('cik') ||
            label.contains('çıkış'))) {
      return kasaCikisMetin;
    } else if (label.contains('banka') &&
        (label.contains('gir') ||
            label.contains('havale') ||
            label.contains('eft'))) {
      return bankaGirisMetin;
    } else if (label.contains('banka') &&
        (label.contains('çık') || label.contains('cik'))) {
      return bankaCikisMetin;
    } else if (label.contains('kredi') &&
        label.contains('kart') &&
        (label.contains('gir') || label.contains('tahsil'))) {
      return krediKartiGirisMetin;
    } else if (label.contains('kredi') &&
        label.contains('kart') &&
        (label.contains('çık') ||
            label.contains('cik') ||
            label.contains('harcama'))) {
      return krediKartiCikisMetin;
    } else if (label.contains('maaş') || label.contains('maas')) {
      return personelMaasMetin;
    } else if (label.contains('avans')) {
      return personelAvansMetin;
    } else if (label.contains('fatura') &&
        (label.contains('satış') || label.contains('satis'))) {
      return satisFaturasiMetin;
    } else if (label.contains('fatura') &&
        (label.contains('alış') || label.contains('alis'))) {
      return alisFaturasiMetin;
    } else if (label.contains('beklemede')) {
      return const Color(0xFFB45309); // Amber 700
    } else if (label.contains('onaylandı') ||
        label.contains('tamamlandi') ||
        label.contains('onaylandi') ||
        label.contains('satış yapıldı')) {
      return const Color(0xFF15803D); // Emerald 700
    } else if (label.contains('iptal') || label.contains('redd edildi')) {
      return const Color(0xFFBE123C); // Rose 700
    } else if (label.contains('teklif')) {
      return teklifMetin;
    } else if (label.contains('sipariş') || label.contains('siparis')) {
      return siparisMetin;
    } else if (label.contains('karşılıksız') || label.contains('karşiliksiz')) {
      return karsiliksizMetin;
    } else if (label.contains('alıcı/satıcı') ||
        label.contains('alici/satici')) {
      return aliciSaticiMetin;
    } else if (label.contains('alıcı') || label.contains('alici')) {
      return aliciMetin;
    } else if (label.contains('satıcı') || label.contains('satici')) {
      return saticiMetin;
    }

    return varsayilanGirdiMetin;
  }

  // ==========================================================================
  // PROFESİYONEL ETİKET DÖNÜŞTÜRÜCÜ
  // ==========================================================================

  /// Veritabanından gelen raw işlem türünü, profesyonel ve kullanıcı dostu
  /// bir etikete dönüştürür.
  ///
  /// Örnek:
  /// - 'tahsilat' -> 'Nakit Tahsilat'
  /// - 'odeme' -> 'Nakit Ödeme'
  /// - 'Giriş' -> 'Kasa Giriş'
  /// - 'Çıkış' -> 'Kasa Çıkış'
  ///
  /// [rawType]: Veritabanından gelen ham işlem türü
  /// [context]: İşlemin hangi modülden geldiğini belirten bağlam
  ///            (cash, bank, credit_card, check, promissory_note, current_account, stock, personnel)
  static String getProfessionalLabel(
    String? rawType, {
    String? context,
    String? fallback,
    String? yon,
    String? suffix,
  }) {
    if (rawType == null || rawType.isEmpty) {
      return fallback ?? 'İşlem';
    }

    final type = rawType.toLowerCase().trim();
    final ctx = context?.toLowerCase() ?? '';

    // KASA İŞLEMLERİ
    if (ctx == 'cash' || ctx == 'kasa') {
      if (type == 'tahsilat' || type == 'giriş' || type == 'giris') {
        return 'Kasa Tahsilat';
      } else if (type == 'ödeme' ||
          type == 'odeme' ||
          type == 'çıkış' ||
          type == 'cikis') {
        return 'Kasa Ödeme';
      }
      return fallback ?? 'Kasa İşlemi';
    }

    // BANKA İŞLEMLERİ
    if (ctx == 'bank' || ctx == 'banka') {
      if (type == 'tahsilat' ||
          type == 'giriş' ||
          type == 'giris' ||
          type == 'havale' ||
          type == 'eft') {
        return 'Banka Tahsilat';
      } else if (type == 'ödeme' ||
          type == 'odeme' ||
          type == 'çıkış' ||
          type == 'cikis') {
        return 'Banka Ödeme';
      } else if (type == 'transfer') {
        return 'Banka Transfer';
      }
      return fallback ?? 'Banka İşlemi';
    }

    // KREDİ KARTI İŞLEMLERİ
    if (ctx == 'credit_card' || ctx == 'kredi_karti') {
      if (type == 'tahsilat' || type == 'giriş' || type == 'giris') {
        return 'Kredi Kartı Tahsilat';
      } else if (type == 'harcama' || type == 'çıkış' || type == 'cikis') {
        return 'Kredi Kartı Harcama';
      }
      return fallback ?? 'Kredi Kartı İşlemi';
    }

    // ÇEK İŞLEMLERİ
    if (ctx == 'check' || ctx == 'cek') {
      if (type.contains('ödendi') || type.contains('odendi')) {
        return 'Çek Ödendi';
      } else if (type.contains('tahsil')) {
        return 'Çek Tahsil';
      } else if (type.contains('ciro')) {
        return 'Çek Ciro';
      } else if (type.contains('verilen') || type.contains('verildi')) {
        return 'Çek Verildi';
      } else if (type.contains('alınan') ||
          type.contains('alinan') ||
          type.contains('alındı') ||
          type.contains('alindi')) {
        return 'Çek Alındı';
      } else if (type.contains('karşılıksız') || type.contains('karşiliksiz')) {
        return 'Karşılıksız Çek';
      } else if (type == 'giriş' || type == 'giris') {
        return 'Çek Tahsil';
      } else if (type == 'çıkış' || type == 'cikis') {
        return 'Çek Ödendi';
      }
      return fallback ?? 'Çek İşlemi';
    }

    // SENET İŞLEMLERİ
    if (ctx == 'promissory_note' || ctx == 'senet') {
      if (type.contains('ödendi') || type.contains('odendi')) {
        return 'Senet Ödendi';
      } else if (type.contains('verilen') || type.contains('verildi')) {
        return 'Senet Verildi';
      } else if (type.contains('alınan') ||
          type.contains('alinan') ||
          type.contains('alındı') ||
          type.contains('alindi')) {
        return 'Senet Alındı';
      } else if (type.contains('tahsil')) {
        return 'Senet Tahsil';
      } else if (type.contains('ciro')) {
        return 'Senet Ciro';
      } else if (type.contains('karşılıksız') || type.contains('karşiliksiz')) {
        return 'Karşılıksız Senet';
      }
      return fallback ?? 'Senet İşlemi';
    }

    // CARİ HESAP İŞLEMLERİ
    if (ctx == 'current_account' || ctx == 'cari') {
      if (type == 'borç' || type == 'borc') {
        return 'Cari Borç';
      } else if (type == 'alacak') {
        return 'Cari Alacak';
      }

      // Açılış Devirleri (Cari)
      if ((type.contains('açılış') || type.contains('acilis')) &&
          (type.contains('devir') || type.contains('devri'))) {
        if (type.contains('alacak')) return 'Açılış Alacak Devri';
        if (type.contains('borç') || type.contains('borc')) {
          return 'Açılış Borç Devri';
        }
      }

      // Çek İşlemleri (Cari context'inde)
      if (type.contains('çek') || type.contains('cek')) {
        if (type.contains('tahsil')) return 'Çek Alındı (Tahsil Edildi)';
        if (type.contains('ödendi') || type.contains('odendi')) {
          return 'Çek Verildi (Ödendi)';
        }
        if (type.contains('ciro')) return 'Çek Ciro Edildi';
        if (type.contains('karşılıksız') || type.contains('karşiliksiz')) {
          return 'Karşılıksız Çek';
        }
        if (type.contains('verildi') || type.contains('verilen')) {
          return 'Çek Verildi';
        }
        if (type.contains('alındı') ||
            type.contains('alindi') ||
            type.contains('alınan') ||
            type.contains('alinan')) {
          return 'Çek Alındı';
        }
        return 'Çek İşlemi';
      }

      // Senet İşlemleri (Cari context'inde)
      if (type.contains('senet')) {
        if (type.contains('tahsil')) return 'Senet Alındı (Tahsil Edildi)';
        if (type.contains('ödendi') || type.contains('odendi')) {
          return 'Senet Verildi (Ödendi)';
        }
        if (type.contains('ciro')) return 'Senet Ciro Edildi';
        if (type.contains('karşılıksız') || type.contains('karşiliksiz')) {
          return 'Karşılıksız Senet';
        }
        if (type.contains('verildi') || type.contains('verilen')) {
          return 'Senet Verildi';
        }
        if (type.contains('alındı') ||
            type.contains('alindi') ||
            type.contains('alınan') ||
            type.contains('alinan')) {
          return 'Senet Alındı';
        }
        return 'Senet İşlemi';
      }

      if (type.contains('tahsilat') ||
          type.contains('girdi') ||
          type.contains('giriş') ||
          type == 'para alındı' ||
          type == 'para alindi') {
        return 'Para Alındı';
      } else if (type.contains('ödeme') ||
          type.contains('odeme') ||
          type.contains('çıktı') ||
          type.contains('çıkış') ||
          type == 'para verildi') {
        return 'Para Verildi';
      } else if (type.contains('borç dekontu') ||
          type.contains('borc dekontu')) {
        return 'Borç Dekontu';
      } else if (type.contains('alacak dekontu')) {
        return 'Alacak Dekontu';
      } else if (type.contains('satış yapıldı') ||
          type.contains('satis yapildi')) {
        return 'Satış Yapıldı';
      } else if (type.contains('alış yapıldı') || type.contains('alis yapildi')) {
        return 'Alış Yapıldı';
      } else if (type.contains('satış') || type.contains('satis')) {
        return 'Satış Faturası';
      } else if (type.contains('alış') || type.contains('alis')) {
        return 'Alış Faturası';
      }

      // [2026 FIX] Fallback logic to match table labels exactly
      if (yon != null) {
        final isIncoming =
            yon.toLowerCase().contains('alacak') ||
            type.contains('tahsilat') ||
            type.contains('girdi') ||
            type.contains('giriş') ||
            type.contains('alındı') ||
            type.contains('alindi') ||
            type == 'para alındı' ||
            type == 'para alindi';
        return isIncoming ? 'Para Alındı' : 'Para Verildi';
      }

      return fallback ?? 'Cari İşlem';
    }

    // STOK İŞLEMLERİ
    if (ctx == 'stock' ||
        ctx == 'stok' ||
        ctx == 'warehouse' ||
        ctx == 'depo') {
      if (type.contains('açılış') || type.contains('acilis')) {
        return 'Açılış Stoğu';
      } else if (type.contains('devir') && type.contains('gir')) {
        return 'Devir Giriş';
      } else if (type.contains('devir') && type.contains('çık')) {
        return 'Devir Çıkış';
      } else if (type.contains('sevkiyat')) {
        return 'Sevkiyat';
      } else if (type.contains('üretim') || type.contains('uretim')) {
        if (type.contains('gir')) {
          return 'Üretim Girişi';
        } else if (type.contains('çık') || type.contains('cik')) {
          return 'Üretim Çıkışı';
        }
        return 'Üretim';
      } else if (type.contains('satış') || type.contains('satis')) {
        return 'Satış Yapıldı';
      } else if (type.contains('alış') || type.contains('alis')) {
        return 'Alış Yapıldı';
      } else if (type == 'giriş' || type == 'giris') {
        return 'Stok Giriş';
      } else if (type == 'çıkış' || type == 'cikis') {
        return 'Stok Çıkış';
      } else if (type == 'transfer') {
        return 'Depo Transfer';
      }
      return fallback ?? 'Stok Hareketi';
    }

    // PERSONEL İŞLEMLERİ
    if (ctx == 'personnel' || ctx == 'personel') {
      if (type.contains('maaş') || type.contains('maas')) {
        return 'Maaş Ödemesi';
      } else if (type.contains('avans')) {
        return 'Avans Ödemesi';
      } else if (type.contains('prim')) {
        return 'Prim Ödemesi';
      } else if (type == 'payment' ||
          type.contains('ödeme') ||
          type.contains('odeme')) {
        return 'Personel Ödemesi';
      }
      return fallback ?? 'Personel İşlemi';
    }

    // GENEL İŞLEM TÜRLERİ (Context belirtilmemişse)
    if (type == 'tahsilat') {
      return 'Tahsilat';
    } else if (type == 'ödeme' || type == 'odeme') {
      return 'Ödeme';
    } else if (type == 'giriş' || type == 'giris') {
      return 'Giriş';
    } else if (type == 'çıkış' || type == 'cikis') {
      return 'Çıkış';
    } else if (type == 'borç' || type == 'borc') {
      return 'Borç';
    } else if (type == 'alacak') {
      return 'Alacak';
    } else if (type.contains('borç dekontu') || type.contains('borc dekontu')) {
      return 'Borç Dekontu';
    } else if (type.contains('alacak dekontu')) {
      return 'Alacak Dekontu';
    } else if (type.contains('satış') || type.contains('satis')) {
      return 'Satış';
    } else if (type.contains('alış') || type.contains('alis')) {
      return 'Alış';
    } else if (type.contains('kısmi satış') || type.contains('kismi satis')) {
      return 'Kısmi Satış';
    } else if (type.contains('kısmi sevk') || type.contains('kismi sevk')) {
      return 'Kısmi Sevk';
    } else if (type.contains('kısmi ödeme') || type.contains('kismi odeme')) {
      return 'Kısmi Ödeme';
    } else if (type.contains('beklemede')) {
      return 'Beklemede';
    } else if (type.contains('onaylandı') || type.contains('onaylandi')) {
      return 'Onaylandı';
    } else if (type.contains('iptal') || type.contains('redd edildi')) {
      return 'İptal Edildi';
    } else if (type.contains('satış yapıldı') ||
        type.contains('satis yapildi')) {
      return 'Satış Yapıldı';
    } else if (type.contains('açılış') || type.contains('acilis')) {
      return 'Açılış Stoğu';
    } else if (type.contains('devir')) {
      return 'Devir';
    } else if (type.contains('sevkiyat')) {
      return 'Sevkiyat';
    } else if (type.contains('üretim') || type.contains('uretim')) {
      return 'Üretim';
    } else if (type.contains('tahsil')) {
      return 'Tahsil';
    } else if (type.contains('ciro')) {
      return 'Ciro';
    } else if (type.contains('transfer')) {
      return 'Transfer';
    } else if (type.contains('sipariş') || type.contains('siparis')) {
      return 'Sipariş';
    } else if (type.contains('teklif')) {
      return 'Teklif';
    } else if (type.contains('alıcı/satıcı') || type.contains('alici/satici')) {
      return 'Alıcı/Satıcı';
    } else if (type.contains('alıcı') || type.contains('alici')) {
      return 'Alıcı';
    } else if (type.contains('satıcı') || type.contains('satici')) {
      return 'Satıcı';
    }

    // Raw değeri capitalize ederek döndür
    return fallback ?? _capitalizeFirst(rawType);
  }

  /// String'in ilk harfini büyük yapar
  static String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
