import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../servisler/baglanti_yoneticisi.dart';
import '../mobil_kurulum/mobil_kurulum_sayfasi.dart';
import '../mobil_kurulum/online_veritabani_bekleniyor_sayfasi.dart';
import '../giris/giris_sayfasi.dart';

class BootstrapSayfasi extends StatefulWidget {
  const BootstrapSayfasi({super.key});

  @override
  State<BootstrapSayfasi> createState() => _BootstrapSayfasiState();
}

class _BootstrapSayfasiState extends State<BootstrapSayfasi> {
  final DateTime _acilisAni = DateTime.now();
  static const Duration _minimumSplashSuresi = Duration(milliseconds: 900);
  bool _yonlendirmeBasladi = false;

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
    } else if (yonetici.durum == BaglantiDurumu.hata) {
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

  @override
  Widget build(BuildContext context) {
    final yonetici = BaglantiYoneticisi();
    final hataDurumu = yonetici.durum == BaglantiDurumu.hata;
    final hataMesaji = yonetici.hataMesaji ?? 'Bilinmeyen bağlantı hatası.';
    final mobileMi =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50), // Proje ana rengi
      body: Center(
        child: hataDurumu
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Bağlantı Hatası',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hataMesaji,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => BaglantiYoneticisi().sistemiBaslat(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2C3E50),
                      ),
                      child: const Text('Tekrar Dene'),
                    ),
                    if (mobileMi) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () =>
                            _yonlendir(const MobilKurulumSayfasi()),
                        child: const Text(
                          'Kurulum Ekranını Aç',
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
                  const Text(
                    'Sistem Hazırlanıyor...',
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
