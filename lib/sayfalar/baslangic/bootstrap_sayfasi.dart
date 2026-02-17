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
    final onay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(
          Icons.home_rounded,
          color: Color(0xFF2C3E50),
          size: 40,
        ),
        title: const Text(
          'Yerel Veritabanına Geçiş',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: const Text(
          'Bulut veritabanı erişilemediği için yerel veritabanına (127.0.0.1) '
          'geçiş yapılacak.\n\n'
          'Not: Yerel PostgreSQL sunucusunun bilgisayarınızda çalışıyor olması gerekir. '
          'Bulut bağlantınız düzeldiğinde ayarlardan tekrar buluta geçebilirsiniz.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Yerele Geç'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2C3E50),
            ),
          ),
        ],
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
                  const Text(
                    'Yerel Veritabanına Geçiliyor...',
                    style: TextStyle(
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
                          ? 'Bulut Veritabanına Erişilemiyor'
                          : 'Bağlantı Hatası',
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

                    // Cloud hatası bilgi notu
                    if (bulutHatasi) ...[
                      const SizedBox(height: 12),
                      Text(
                        'İnternet bağlantınız olmayabilir veya '
                        'bulut veritabanı kapatılmış/silinmiş olabilir.',
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
                        label: const Text('Tekrar Dene'),
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

                    // Masaüstünde ve bulutu hatası varsa: Yerele Geç butonu
                    if (bulutHatasi && masaustuMu) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 260,
                        child: OutlinedButton.icon(
                          onPressed: _yereleGecOnay,
                          icon: const Icon(Icons.home_rounded, size: 18),
                          label: const Text('Yerel Veritabanına Geç'),
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
