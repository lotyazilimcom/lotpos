import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../baslangic/bootstrap_sayfasi.dart';
import '../../servisler/local_network_discovery_service.dart';
import '../../servisler/online_veritabani_servisi.dart';
import '../../servisler/veritabani_yapilandirma.dart';
import '../../servisler/lisans_servisi.dart';

class MobilKurulumSayfasi extends StatefulWidget {
  const MobilKurulumSayfasi({super.key});

  @override
  State<MobilKurulumSayfasi> createState() => _MobilKurulumSayfasiState();
}

class _MobilKurulumSayfasiState extends State<MobilKurulumSayfasi> {
  bool _isSearching = false;
  String? _foundServerIp;
  String? _foundServerName;

  Future<void> _bulutTalebiGonderBestEffort() async {
    try {
      await Supabase.initialize(url: LisansServisi.u, anonKey: LisansServisi.k);
    } catch (_) {
      // Zaten başlatılmış olabilir.
    }

    try {
      await LisansServisi().baslat();
    } catch (_) {}

    final hardwareId = LisansServisi().hardwareId;
    if (hardwareId == null || hardwareId.trim().isEmpty) return;

    await OnlineVeritabaniServisi().talepGonder(
      hardwareId: hardwareId.trim(),
      source: 'mobile_setup',
    );
  }

  Future<void> _bulVeBaglan() async {
    setState(() {
      _isSearching = true;
      _foundServerIp = null;
      _foundServerName = null;
    });

    try {
      final service = await LocalNetworkDiscoveryService().sunucuBul();

      if (service != null && service.host != null) {
        setState(() {
          _foundServerIp = service.host;
          _foundServerName = service.name;
          _isSearching = false;
        });

        // Host'u yapılandırmaya kaydet (Bellekte)
        VeritabaniYapilandirma.setDiscoveredHost(service.host);

        // Lisans durumunu devral
        bool isPro = false;
        final txt = service.txt;
        if (txt != null && txt['isPro'] != null) {
          isPro = utf8.decode(txt['isPro']!) == 'true';
        }
        await LisansServisi().setInheritedPro(isPro);
      } else {
        setState(() => _isSearching = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sunucu bulunamadı. Lütfen ana bilgisayarda programın açık olduğundan emin olun.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSearching = false);
      debugPrint('Arama hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2C3E50), // Proje ana rengi
              Color(0xFF0F323D), // Daha koyu versiyonu
            ],
          ),
        ),
        child: Stack(
          children: [
            // Arka plan desen parçacıkları
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.03),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // Logo ve Başlık Bölümü
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            size: 72,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          tr('app.title'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(flex: 2),

                    if (_foundServerIp != null) ...[
                      // Sunucu Bulundu Kartı
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.greenAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: Colors.greenAccent,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Sunucu Bulundu!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_foundServerName\n$_foundServerIp',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent,
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () =>
                                    _setupTamamla(context, mode: 'local'),
                                child: const Text(
                                  'Devam Et',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _foundServerIp = null),
                              child: Text(
                                'Tekrar Ara',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Seçenekler
                      _isSearching
                          ? Column(
                              children: [
                                const CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Sunucu aranıyor...',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _buildOptionCard(
                                  context,
                                  icon: Icons.lan_outlined,
                                  title: 'Yerel Ana Bilgisayarı Bul',
                                  subtitle:
                                      'Ofis ağındaki sunucuya otomatik bağlanın',
                                  color: const Color(0xFF64B5F6),
                                  onTap: _bulVeBaglan,
                                ),
                                const SizedBox(height: 16),
                                _buildOptionCard(
                                  context,
                                  icon: Icons.public_rounded,
                                  title: 'İnternetten Kullan',
                                  subtitle:
                                      'Bulut altyapısı üzerinden her yerden erişim',
                                  color: const Color(0xFF81C784),
                                  onTap: () =>
                                      _setupTamamla(context, mode: 'cloud'),
                                ),
                              ],
                            ),
                    ],

                    const Spacer(flex: 3),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setupTamamla(
    BuildContext context, {
    required String mode,
  }) async {
    // Tercihleri kaydet
    await VeritabaniYapilandirma.saveConnectionPreferences(
      mode,
      mode == 'local' ? _foundServerIp : null,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mobil_kurulum_tamamlandi', true);

    if (mode == 'cloud' && context.mounted) {
      unawaited(_bulutTalebiGonderBestEffort());
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('setup.cloud.preparing_title')),
          content: Text(tr('setup.cloud.preparing_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('common.ok')),
            ),
          ],
        ),
      );
    }

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const BootstrapSayfasi()),
      );
    }
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withValues(alpha: 0.1),
        highlightColor: color.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Inter',
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
