import 'package:flutter/material.dart';
import '../../servisler/baglanti_yoneticisi.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../giris/giris_sayfasi.dart';
import 'mobil_kurulum_sayfasi.dart';

class OnlineVeritabaniBekleniyorSayfasi extends StatefulWidget {
  const OnlineVeritabaniBekleniyorSayfasi({super.key});

  @override
  State<OnlineVeritabaniBekleniyorSayfasi> createState() =>
      _OnlineVeritabaniBekleniyorSayfasiState();
}

class _OnlineVeritabaniBekleniyorSayfasiState
    extends State<OnlineVeritabaniBekleniyorSayfasi> {
  bool _kontrolEdiliyor = false;

  @override
  void initState() {
    super.initState();
    BaglantiYoneticisi().addListener(_durumDinle);
  }

  @override
  void dispose() {
    BaglantiYoneticisi().removeListener(_durumDinle);
    super.dispose();
  }

  void _durumDinle() {
    if (!mounted) return;
    final durum = BaglantiYoneticisi().durum;

    if (durum == BaglantiDurumu.basarili) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GirisSayfasi()),
      );
    } else if (durum == BaglantiDurumu.kurulumGerekli ||
        durum == BaglantiDurumu.sunucuBulunamadi) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MobilKurulumSayfasi()),
      );
    } else {
      setState(() {});
    }
  }

  Future<void> _kontrolEt() async {
    if (_kontrolEdiliyor) return;
    setState(() => _kontrolEdiliyor = true);
    try {
      await BaglantiYoneticisi().sistemiBaslat();
    } finally {
      if (mounted) setState(() => _kontrolEdiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final yonetici = BaglantiYoneticisi();
    final hataDurumu = yonetici.durum == BaglantiDurumu.hata;
    final hataMesaji = yonetici.hataMesaji ?? tr('common.unknown_error');

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2C3E50),
              Color(0xFF0F323D),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    hataDurumu
                        ? Icons.error_outline_rounded
                        : Icons.cloud_sync_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  hataDurumu
                      ? tr('setup.cloud.error_title')
                      : tr('setup.cloud.preparing_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  hataDurumu ? hataMesaji : tr('setup.cloud.preparing_message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(flex: 2),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _kontrolEdiliyor ? null : _kontrolEt,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF81C784),
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    icon: _kontrolEdiliyor
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black87,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      tr('setup.cloud.check_now'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const MobilKurulumSayfasi(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.settings_rounded),
                    label: Text(
                      tr('setup.cloud.open_setup_options'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

