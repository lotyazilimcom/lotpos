import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../servisler/baglanti_yoneticisi.dart';
import '../mobil_kurulum/mobil_kurulum_sayfasi.dart';
import '../mobil_kurulum/online_veritabani_bekleniyor_sayfasi.dart';
import '../giris/giris_sayfasi.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';

class BootstrapSayfasi extends StatefulWidget {
  const BootstrapSayfasi({super.key});

  @override
  State<BootstrapSayfasi> createState() => _BootstrapSayfasiState();
}

class _BootstrapSayfasiState extends State<BootstrapSayfasi> {
  final DateTime _acilisAni = DateTime.now();
  static const Duration _minimumSplashSuresi = Duration(milliseconds: 900);
  bool _yonlendirmeBasladi = false;
  bool _yereleGeciliyor = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_baslat());
      }
    });
  }

  @override
  void dispose() {
    BaglantiYoneticisi().removeListener(_durumDinleyici);
    super.dispose();
  }

  Future<void> _baslat() async {
    final yonetici = BaglantiYoneticisi();

    // BaglantiYoneticisi'ni dinle
    yonetici.addListener(_durumDinleyici);

    // Sistemi başlat (Async)
    yonetici.sistemiBaslat();
  }

  void _durumDinleyici() {
    final yonetici = BaglantiYoneticisi();

    if (!mounted) return;

    if (yonetici.durum == BaglantiDurumu.basarili) {
      unawaited(_minimumBeklemeIleYonlendir(const GirisSayfasi()));
    } else if (yonetici.durum == BaglantiDurumu.bulutKurulumBekleniyor) {
      unawaited(
        _minimumBeklemeIleYonlendir(const OnlineVeritabaniBekleniyorSayfasi()),
      );
    } else if (yonetici.durum == BaglantiDurumu.kurulumGerekli ||
        yonetici.durum == BaglantiDurumu.sunucuBulunamadi) {
      unawaited(_minimumBeklemeIleYonlendir(const MobilKurulumSayfasi()));
    } else if (yonetici.durum == BaglantiDurumu.hata ||
        yonetici.durum == BaglantiDurumu.bulutErisimHatasi) {
      setState(() {});
    }
  }

  Future<void> _minimumBeklemeIleYonlendir(Widget sayfa) async {
    if (_yonlendirmeBasladi) return;
    _yonlendirmeBasladi = true;

    final gecenSure = DateTime.now().difference(_acilisAni);
    if (gecenSure < _minimumSplashSuresi) {
      await Future.delayed(_minimumSplashSuresi - gecenSure);
    }

    if (!mounted) return;
    _yonlendir(sayfa);
  }

  void _yonlendir(Widget sayfa) {
    BaglantiYoneticisi().removeListener(_durumDinleyici);
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => sayfa));
  }

  Future<void> _yereleGecOnay() async {
    const primaryColor = Color(0xFF2C3E50);
    const destructiveColor = Color(0xFFEA4335);
    const dialogRadius = 14.0;

    final onay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dialogRadius),
        ),
        child: Container(
          width: 420,
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: destructiveColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.home_rounded,
                  color: destructiveColor,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              // Title
              Text(
                tr('bootstrap.local_fallback.title'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              // Message
              Text(
                tr('bootstrap.local_fallback.message'),
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        tr('bootstrap.local_fallback.cancel'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: Text(
                        tr('bootstrap.local_fallback.confirm'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: destructiveColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (onay != true || !mounted) return;

    setState(() => _yereleGeciliyor = true);
    _yonlendirmeBasladi = false; // Tekrar yönlendirme yapılabilsin

    await BaglantiYoneticisi().yereleGec();

    // yereleGec() sistemiBaslat çağıracak ve durumDinleyici tekrar tetiklenecek
    // Eğer yerel de başarısızsa _durumDinleyici hata durumunu yakalar
    if (mounted) {
      setState(() => _yereleGeciliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final yonetici = BaglantiYoneticisi();
    final bulutHatasi = yonetici.durum == BaglantiDurumu.bulutErisimHatasi;
    final hataDurumu = yonetici.durum == BaglantiDurumu.hata || bulutHatasi;
    final hataMesaji = yonetici.hataMesaji ?? 'Bilinmeyen bağlantı hatası.';
    final mobileMi =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final masaustuMu = !kIsWeb && !mobileMi;

    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50), // Proje ana rengi
      body: Center(
        child: _yereleGeciliyor
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    tr('bootstrap.local_fallback.switching'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : hataDurumu
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // İkon
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color:
                            (bulutHatasi
                                    ? Colors.orangeAccent
                                    : Colors.redAccent)
                                .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        bulutHatasi
                            ? Icons.cloud_off_rounded
                            : Icons.error_outline_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Başlık
                    Text(
                      bulutHatasi
                          ? tr('bootstrap.error.cloud_unreachable')
                          : tr('bootstrap.error.connection'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Hata detayı
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hataMesaji,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),

                    // Cluster ID uyumsuzluğu detayları
                    if (yonetici.clusterUyumsuz) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Beklenen: ${yonetici.beklenenClusterId ?? '-'}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Bulunan: ${yonetici.aktifClusterId ?? '-'}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Cloud hatası bilgi notu
                    if (bulutHatasi) ...[
                      const SizedBox(height: 12),
                      Text(
                        tr('bootstrap.error.cloud_hint'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.amber.shade200,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),

                    // Butonlar
                    SizedBox(
                      width: 260,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _yonlendirmeBasladi = false;
                          BaglantiYoneticisi().sistemiBaslat();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(tr('bootstrap.retry')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2C3E50),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    // Cluster mismatch: kullanıcı bilinçli olarak bu veri setini kabul edebilir.
                    if (yonetici.clusterUyumsuz) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 260,
                        child: OutlinedButton.icon(
                          onPressed: () => unawaited(
                            BaglantiYoneticisi().clusterKimliginiKabulEt(),
                          ),
                          icon: const Icon(Icons.verified_rounded, size: 18),
                          label: const Text('Bu veri setini kabul et'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Masaüstünde ve bulutu hatası varsa: Yerele Geç butonu
                    if (bulutHatasi && masaustuMu) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 260,
                        child: OutlinedButton.icon(
                          onPressed: _yereleGecOnay,
                          icon: const Icon(Icons.home_rounded, size: 18),
                          label: Text(tr('bootstrap.local_fallback.button')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Mobilede kurulum ekranına dönüş
                    if (mobileMi) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () =>
                            _yonlendir(const MobilKurulumSayfasi()),
                        child: Text(
                          tr('bootstrap.open_setup'),
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Alanı
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Yükleme Göstergesi
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Bilgi Metni
                  Text(
                    tr('bootstrap.loading'),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
