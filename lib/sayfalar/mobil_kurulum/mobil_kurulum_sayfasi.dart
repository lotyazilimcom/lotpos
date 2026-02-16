import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:nsd/nsd.dart' show Service;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../baslangic/bootstrap_sayfasi.dart';
import '../../servisler/local_network_discovery_service.dart';
import '../../servisler/online_veritabani_servisi.dart';
import '../../servisler/veritabani_aktarim_servisi.dart';
import '../../servisler/veritabani_yapilandirma.dart';
import '../../servisler/lisans_servisi.dart';

class MobilKurulumSayfasi extends StatefulWidget {
  const MobilKurulumSayfasi({super.key});

  @override
  State<MobilKurulumSayfasi> createState() => _MobilKurulumSayfasiState();
}

class _MobilKurulumSayfasiState extends State<MobilKurulumSayfasi> {
  bool _isSearching = false;
  List<Service> _foundServers = [];
  Service? _selectedServer;

  @override
  void initState() {
    super.initState();
    // Giriş ekranından "veritabanı değiştir" ile gelince tek tıkta liste çıksın.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Sadece daha önce "Yerel" seçiliyse (host kayıtlıysa) otomatik aramada hata mesajı göster.
      // İlk kurulumda (varsayılan cloud) kullanıcıyı gereksiz uyarı ile rahatsız etmeyelim.
      final showError =
          VeritabaniYapilandirma.connectionMode == 'local' &&
          (VeritabaniYapilandirma.discoveredHost ?? '').trim().isNotEmpty;
      unawaited(_bulVeBaglan(showError: showError));
    });
  }

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

  Future<void> _bulVeBaglan({bool showError = true}) async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _foundServers = [];
      _selectedServer = null;
    });

    try {
      final servers = await LocalNetworkDiscoveryService().sunuculariBul(
        timeout: const Duration(seconds: 3),
      );

      if (!mounted) return;
      if (servers.isNotEmpty) {
        setState(() {
          _foundServers = servers;
          _selectedServer = servers.first;
          _isSearching = false;
        });
      } else {
        setState(() => _isSearching = false);
        if (showError && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('setup.local.server_not_found_open_app')),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
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

                    if (_foundServers.isNotEmpty) ...[
                      // Sunucular Bulundu Kartı
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
                              _foundServers.length == 1
                                  ? 'Sunucu Bulundu!'
                                  : 'Sunucular Bulundu!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_foundServers.length == 1)
                              Text(
                                '${_selectedServer?.name ?? ''}\n${_selectedServer?.host ?? ''}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: RadioGroup<String>(
                                  groupValue:
                                      (_selectedServer?.host ?? '').trim().isEmpty
                                          ? null
                                          : (_selectedServer?.host ?? '').trim(),
                                  onChanged: (v) {
                                    if (v == null) return;
                                    final match = _foundServers.firstWhere(
                                      (s) => (s.host ?? '').trim() == v,
                                      orElse: () =>
                                          _selectedServer ?? _foundServers.first,
                                    );
                                    setState(() => _selectedServer = match);
                                  },
                                  child: Column(
                                    children: _foundServers.map((s) {
                                      final host = (s.host ?? '').trim();
                                      final title = (s.name ?? host).trim();
                                      final selected = _selectedServer?.host == host;
                                      return ListTile(
                                        dense: true,
                                        visualDensity: const VisualDensity(
                                          vertical: -2,
                                        ),
                                        title: Text(
                                          title.isEmpty ? host : title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        subtitle: Text(
                                          host,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                        trailing: Radio<String>(
                                          value: host,
                                          activeColor: Colors.greenAccent,
                                        ),
                                        onTap: () =>
                                            setState(() => _selectedServer = s),
                                        selected: selected,
                                      );
                                    }).toList(),
                                  ),
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
                                onPressed: (_selectedServer?.host ?? '').trim().isEmpty
                                    ? null
                                    : () => _setupTamamla(context, mode: 'local'),
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
                                  setState(() => _foundServers = []),
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
                      const SizedBox(height: 16),
                      _buildOptionCard(
                        context,
                        icon: Icons.public_rounded,
                        title: 'İnternetten Kullan',
                        subtitle:
                            'Bulut altyapısı üzerinden her yerden erişim',
                        color: const Color(0xFF81C784),
                        onTap: () => _setupTamamla(context, mode: 'cloud'),
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
    final String oncekiMod = VeritabaniYapilandirma.connectionMode;
    final String? oncekiYerelHost = VeritabaniYapilandirma.discoveredHost;
    final selectedHost = (_selectedServer?.host ?? '').trim();
    if (mode == 'local' && selectedHost.isEmpty) return;

    if (mode == 'local') {
      VeritabaniYapilandirma.setDiscoveredHost(selectedHost);
      // Lisans durumunu devral (mDNS yayını varsa TXT üzerinden gelir).
      bool isPro = false;
      final txt = _selectedServer?.txt;
      if (txt != null && txt['isPro'] != null) {
        try {
          isPro = utf8.decode(txt['isPro']!) == 'true';
        } catch (_) {}
      }
      unawaited(LisansServisi().setInheritedPro(isPro));
    }

    // Tercihleri kaydet
    await VeritabaniYapilandirma.saveConnectionPreferences(
      mode,
      mode == 'local' ? selectedHost : null,
    );

    // Local <-> Cloud geçişinde: veri aktarımı sorusu için niyet kaydet (mobil/tablet).
    final bool modDegisti = oncekiMod != mode;
    final bool localCloudSwitch =
        (oncekiMod == 'local' && mode == 'cloud') ||
        (oncekiMod == 'cloud' && mode == 'local');
    if (modDegisti && localCloudSwitch) {
      final localHost = (mode == 'local' ? selectedHost : (oncekiYerelHost ?? '')).trim();
      await VeritabaniAktarimServisi().niyetKaydet(
        VeritabaniAktarimNiyeti(
          fromMode: oncekiMod,
          toMode: mode,
          localHost: localHost.isEmpty ? null : localHost,
          localCompanyDb: null,
          createdAt: DateTime.now(),
        ),
      );
    }

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
