import 'dart:io';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' show Service;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../bilesenler/veritabani_aktarim_secim_dialog.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../servisler/lite_ayarlar_servisi.dart';
import '../../../servisler/lite_kisitlari.dart';
import '../../../servisler/lisans_servisi.dart';
import '../../../servisler/local_network_discovery_service.dart';
import '../../../servisler/online_veritabani_servisi.dart';
import '../../../servisler/oturum_servisi.dart';
import '../../../servisler/veritabani_aktarim_servisi.dart';
import '../../../servisler/veritabani_yapilandirma.dart';
import '../../baslangic/bootstrap_sayfasi.dart';

class VeritabaniYedekAyarlariSayfasi extends StatefulWidget {
  const VeritabaniYedekAyarlariSayfasi({super.key});

  @override
  State<VeritabaniYedekAyarlariSayfasi> createState() =>
      _VeritabaniYedekAyarlariSayfasiState();
}

class _VeritabaniYedekAyarlariSayfasiState
    extends State<VeritabaniYedekAyarlariSayfasi> {
  String _seciliMod = 'local'; // local, hybrid, cloud
  bool _yedeklemeAcik = true;
  String _yedeklemePeriyodu = '15days'; // 15days, monthly, 3months, 6months
  bool _semaIndiriliyor = false;

  @override
  void initState() {
    super.initState();
    // Tüm platformlarda gerçek mod tercihini ekranda doğru göster.
    final persistedMode = VeritabaniYapilandirma.connectionMode;
    _seciliMod = persistedMode == VeritabaniYapilandirma.cloudPendingMode
        ? 'cloud'
        : persistedMode;
    if (_seciliMod != 'local' &&
        _seciliMod != 'hybrid' &&
        _seciliMod != 'cloud') {
      _seciliMod = 'local';
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2C3E50);

    return ListenableBuilder(
      listenable: Listenable.merge([LisansServisi(), LiteAyarlarServisi()]),
      builder: (context, _) {
        final isLite = LisansServisi().isLiteMode;
        final isLiteBackupKapali = isLite && !LiteKisitlari.isCloudBackupActive;
        final bool isMobile = MediaQuery.of(context).size.width < 700;
        final bool isMobilePlatform =
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android;
        final bool isDesktopPlatform =
            !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.linux);

        if (isMobilePlatform && _seciliMod == 'hybrid') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_seciliMod == 'hybrid') setState(() => _seciliMod = 'local');
          });
        }

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 14.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(primaryColor, isMobile: isMobile),
                  if (isLiteBackupKapali) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        tr('settings.backup.lite_cloud_hybrid_disabled_banner'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: primaryColor.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: isMobile ? 24 : 32),
                  _buildSectionTitle(
                    tr('settings.database.title'),
                    Icons.storage_rounded,
                    primaryColor,
                    isMobile: isMobile,
                  ),
                  const SizedBox(height: 16),
                  _buildDatabaseModes(
                    primaryColor,
                    isLite: isLiteBackupKapali,
                    isMobile: isMobile,
                    hideHybridMode: isMobilePlatform,
                  ),
                  SizedBox(height: isMobile ? 24 : 32),
                  _buildSectionTitle(
                    tr('settings.backup.title'),
                    Icons.cloud_upload_rounded,
                    primaryColor,
                    isMobile: isMobile,
                  ),
                  const SizedBox(height: 16),
                  _buildBackupSettings(
                    primaryColor,
                    isLite: isLiteBackupKapali,
                    isMobile: isMobile,
                  ),
                  if (isDesktopPlatform) ...[
                    SizedBox(height: isMobile ? 24 : 32),
                    _buildSectionTitle(
                      tr('settings.database.schema_export.title'),
                      Icons.download_rounded,
                      primaryColor,
                      isMobile: isMobile,
                    ),
                    const SizedBox(height: 16),
                    _buildYerelSemaIndirmeCard(
                      primaryColor,
                      isMobile: isMobile,
                    ),
                  ],
                  SizedBox(height: isMobile ? 32 : 48),
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showProGerekiyor() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('common.pro_required')),
        content: Text(tr('common.lite_feature_disabled_go_pro')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('common.close')),
          ),
        ],
      ),
    );
  }

  Future<void> _uygulaYerelSunucuLisansBestEffort(Service service) async {
    try {
      final txt = service.txt;
      if (txt == null || txt['isPro'] == null) return;
      final inherited = utf8.decode(txt['isPro']!) == 'true';
      await LisansServisi().setInheritedPro(inherited);
    } catch (_) {
      // Sessiz: yerel keşif lisans bilgisi opsiyonel.
    }
  }

  Future<Service?> _yerelSunucuBulVeSec({String? oncekiHost}) async {
    if (!mounted) return null;

    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(tr('common.loading')),
          content: const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Yerel sunucu aranıyor...',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );

    List<Service> servers = const [];
    try {
      servers = await LocalNetworkDiscoveryService().sunuculariBul(
        timeout: const Duration(seconds: 3),
      );
    } catch (_) {
      servers = const [];
    } finally {
      try {
        if (navigator.canPop()) navigator.pop();
      } catch (_) {}
    }

    if (!mounted) return null;

    if (servers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings.database.mobile_local_requires_server')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

    if (servers.length == 1) {
      return servers.first;
    }

    final preferred = (oncekiHost ?? '').trim();
    Service selected = servers.first;
    if (preferred.isNotEmpty) {
      for (final s in servers) {
        if ((s.host ?? '').trim() == preferred) {
          selected = s;
          break;
        }
      }
    }

    final Service? result = await showDialog<Service>(
      context: context,
      builder: (ctx) {
        Service current = selected;
        return StatefulBuilder(
          builder: (ctx, setState) {
            final host = (current.host ?? '').trim();
            final groupValue = host.isEmpty ? null : host;

            return AlertDialog(
              title: const Text('Yerel Sunucu Seç'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: RadioGroup<String>(
                    groupValue: groupValue,
                    onChanged: (v) {
                      if (v == null) return;
                      for (final s in servers) {
                        final host = (s.host ?? '').trim();
                        if (host == v) {
                          setState(() => current = s);
                          break;
                        }
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: servers.map((s) {
                        final host = (s.host ?? '').trim();
                        final name = (s.name ?? host).trim();
                        final isSelected = (current.host ?? '').trim() == host;
                        return ListTile(
                          dense: true,
                          title: Text(name.isEmpty ? host : name),
                          subtitle: Text(host),
                          trailing: Radio<String>(value: host),
                          selected: isSelected,
                          onTap: () => setState(() => current = s),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(tr('common.cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(current),
                  child: Text(tr('common.select')),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Widget _buildHeader(Color primaryColor, {required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('nav.settings.database_backup'),
          style: TextStyle(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF202124),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('settings.database.subtitle'),
          style: TextStyle(
            fontSize: isMobile ? 13 : 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    String title,
    IconData icon,
    Color primaryColor, {
    required bool isMobile,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: isMobile ? 15 : 16,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDatabaseModes(
    Color primaryColor, {
    required bool isLite,
    required bool isMobile,
    required bool hideHybridMode,
  }) {
    final localTitleKey = hideHybridMode
        ? 'settings.database.mode.local_mobile.title'
        : 'settings.database.mode.local.title';
    final localDescKey = hideHybridMode
        ? 'settings.database.mode.local_mobile.desc'
        : 'settings.database.mode.local.desc';
    final localHelpKey = hideHybridMode
        ? 'settings.database.mode.local_mobile.help'
        : 'settings.database.mode.local.help';

    final children = <Widget>[
      _buildModeCard(
        id: 'local',
        title: tr(localTitleKey),
        desc: tr(localDescKey),
        help: tr(localHelpKey),
        icon: Icons.computer_rounded,
        primaryColor: primaryColor,
        enabled: true,
        isMobile: isMobile,
      ),
    ];

    if (!hideHybridMode) {
      children.addAll([
        const SizedBox(height: 12),
        _buildModeCard(
          id: 'hybrid',
          title: tr('settings.database.mode.hybrid.title'),
          desc: tr('settings.database.mode.hybrid.desc'),
          help: tr('settings.database.mode.hybrid.help'),
          icon: Icons.sync_rounded,
          primaryColor: primaryColor,
          enabled: !isLite,
          isMobile: isMobile,
        ),
      ]);
    }

    children.addAll([
      const SizedBox(height: 12),
      _buildModeCard(
        id: 'cloud',
        title: tr('settings.database.mode.cloud.title'),
        desc: tr('settings.database.mode.cloud.desc'),
        help: tr('settings.database.mode.cloud.help'),
        icon: Icons.cloud_done_rounded,
        primaryColor: primaryColor,
        enabled: !isLite,
        isMobile: isMobile,
      ),
    ]);

    return Column(children: children);
  }

  Widget _buildModeCard({
    required String id,
    required String title,
    required String desc,
    required String help,
    required IconData icon,
    required Color primaryColor,
    required bool enabled,
    required bool isMobile,
  }) {
    final isSelected = _seciliMod == id;

    return InkWell(
      onTap: () {
        if (!enabled) {
          _showProGerekiyor();
          return;
        }
        setState(() => _seciliMod = id);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = isMobile || constraints.maxWidth < 380;

            final Widget infoColumn = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? primaryColor
                          : const Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    help,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: primaryColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );

            final Widget selector = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<String>(
                  value: id,
                  // ignore: deprecated_member_use
                  groupValue: _seciliMod,
                  activeColor: primaryColor,
                  // ignore: deprecated_member_use
                  onChanged: enabled
                      ? (val) {
                          if (val != null) setState(() => _seciliMod = val);
                        }
                      : null,
                ),
                if (!enabled)
                  const Icon(Icons.lock_rounded, size: 16, color: Colors.grey),
              ],
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      infoColumn,
                    ],
                  ),
                  Align(alignment: Alignment.centerRight, child: selector),
                ],
              );
            }

            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                infoColumn,
                selector,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackupSettings(
    Color primaryColor, {
    required bool isLite,
    required bool isMobile,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildBackupRow(
            title: tr('settings.backup.status'),
            subtitle: isLite
                ? 'Pro sürümde kullanılabilir.'
                : (_yedeklemeAcik
                      ? tr('common.on')
                      : tr('settings.backup.warning.off')),
            trailing: Switch.adaptive(
              value: isLite ? false : _yedeklemeAcik,
              // ignore: deprecated_member_use
              activeColor: primaryColor,
              onChanged: isLite
                  ? null
                  : (val) => setState(() => _yedeklemeAcik = val),
            ),
            isMobile: isMobile,
          ),
          const Divider(height: 32),
          _buildBackupRow(
            title: tr('settings.backup.period'),
            subtitle: tr('settings.backup.subtitle'),
            trailing: Opacity(
              opacity: (!isLite && _yedeklemeAcik) ? 1.0 : 0.5,
              child: IgnorePointer(
                ignoring: isLite || !_yedeklemeAcik,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButton<String>(
                    value: _yedeklemePeriyodu,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    items: [
                      DropdownMenuItem(
                        value: '15days',
                        child: Text(tr('settings.backup.period.15days')),
                      ),
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text(tr('settings.backup.period.monthly')),
                      ),
                      DropdownMenuItem(
                        value: '3months',
                        child: Text(tr('settings.backup.period.3months')),
                      ),
                      DropdownMenuItem(
                        value: '6months',
                        child: Text(tr('settings.backup.period.6months')),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _yedeklemePeriyodu = val);
                    },
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF202124),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            isMobile: isMobile,
          ),
          const Divider(height: 32),
          _buildBackupRow(
            title: tr('settings.backup.target'),
            subtitle: tr('settings.backup.target.cloud'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_queue_rounded,
                    size: 14,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Cloud",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            isMobile: isMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildBackupRow({
    required String title,
    required String subtitle,
    required Widget trailing,
    required bool isMobile,
  }) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF202124),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: subtitle.startsWith('⚠️')
                  ? Colors.red
                  : Colors.grey.shade600,
              fontWeight: subtitle.startsWith('⚠️')
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: trailing),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: subtitle.startsWith('⚠️')
                      ? Colors.red
                      : Colors.grey.shade600,
                  fontWeight: subtitle.startsWith('⚠️')
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: () async {
          final bool isMobilePlatform =
              defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android;
          final bool isDesktopPlatform =
              !kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.windows ||
                  defaultTargetPlatform == TargetPlatform.macOS ||
                  defaultTargetPlatform == TargetPlatform.linux);

          if (!isMobilePlatform && !isDesktopPlatform) {
            // Web: Mevcut davranışı koru
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tr('settings.ai.save_success')),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          if (isDesktopPlatform) {
            await _handleDesktopSave();
            return;
          }

          final String oncekiMod = VeritabaniYapilandirma.connectionMode;
          final String? oncekiYerelHost = VeritabaniYapilandirma.discoveredHost;
          final String? oncekiYerelCompanyDb = oncekiMod == 'local'
              ? OturumServisi().aktifVeritabaniAdi
              : null;
          String? yerelHostKaydi;

          if (_seciliMod == 'local') {
            // Bulut -> Yerel geçişinde: kurulum/giriş ekranındaki gibi
            // otomatik sunucu tara, tekse seç, çoksa kullanıcıya sor.
            if (oncekiMod == 'cloud') {
              final secilen = await _yerelSunucuBulVeSec(
                oncekiHost: VeritabaniYapilandirma.discoveredHost,
              );
              if (secilen == null) {
                if (mounted) setState(() => _seciliMod = oncekiMod);
                return;
              }

              final host = (secilen.host ?? '').trim();
              if (host.isEmpty) {
                if (mounted) setState(() => _seciliMod = oncekiMod);
                return;
              }

              yerelHostKaydi = host;
              VeritabaniYapilandirma.setDiscoveredHost(host);
              await _uygulaYerelSunucuLisansBestEffort(secilen);
            } else {
              final host = VeritabaniYapilandirma.discoveredHost;
              if (host == null || host.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      tr('settings.database.mobile_local_requires_server'),
                    ),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              yerelHostKaydi = host.trim();
            }
          }

          await VeritabaniYapilandirma.saveConnectionPreferences(
            _seciliMod,
            _seciliMod == 'local' ? yerelHostKaydi : null,
          );

          // Local <-> Cloud geçişinde: veri aktarımı sorusu için niyet kaydet (mobil/tablet).
          final bool modDegisti = oncekiMod != _seciliMod;
          final bool localCloudSwitch =
              (oncekiMod == 'local' && _seciliMod == 'cloud') ||
              (oncekiMod == 'cloud' && _seciliMod == 'local');
          if (modDegisti && localCloudSwitch) {
            final localHost =
                (oncekiMod == 'local'
                        ? (oncekiYerelHost ?? '')
                        : (yerelHostKaydi ?? ''))
                    .trim();
            await VeritabaniAktarimServisi().niyetKaydet(
              VeritabaniAktarimNiyeti(
                fromMode: oncekiMod,
                toMode: _seciliMod,
                localHost: localHost.isEmpty ? null : localHost,
                localCompanyDb: oncekiYerelCompanyDb,
                createdAt: DateTime.now(),
              ),
            );
          }

          if (_seciliMod == 'cloud') {
            final hardwareId = LisansServisi().hardwareId;
            if (hardwareId != null && hardwareId.trim().isNotEmpty) {
              await OnlineVeritabaniServisi().talepGonder(
                hardwareId: hardwareId.trim(),
                source: 'database_settings',
              );
            }

            if (mounted) {
              await showDialog<void>(
                context: context,
                builder: (ctx) => Dialog(
                  backgroundColor: Colors.white,
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Container(
                    width: 450,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('setup.cloud.preparing_title'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF202124),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('setup.cloud.preparing_message'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF606368),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  foregroundColor: const Color(0xFF2C3E50),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: Text(tr('common.ok')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          }

          if (!mounted) return;

          if (modDegisti) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const BootstrapSayfasi()),
              (_) => false,
            );
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('settings.ai.save_success')),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEA4335),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.save_rounded),
            const SizedBox(width: 12),
            Text(
              tr('common.save'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _desktopBulutKimlikleriniHazirlaBestEffort() async {
    try {
      await Supabase.initialize(url: LisansServisi.u, anonKey: LisansServisi.k);
    } catch (_) {
      // Zaten başlatılmış olabilir.
    }

    try {
      await LisansServisi().baslat();
    } catch (_) {}

    final hardwareId = LisansServisi().hardwareId;
    if (hardwareId == null || hardwareId.trim().isEmpty) return false;

    final creds = await OnlineVeritabaniServisi().kimlikleriGetir(
      hardwareId.trim(),
    );
    if (creds == null) {
      await OnlineVeritabaniServisi().talepGonder(
        hardwareId: hardwareId.trim(),
        source: 'desktop_settings',
      );
      return false;
    }

    await VeritabaniYapilandirma.saveCloudDatabaseCredentials(
      host: creds.host,
      port: creds.port,
      username: creds.username,
      password: creds.password,
      database: creds.database,
      sslRequired: creds.sslRequired,
    );

    if (!VeritabaniYapilandirma.cloudCredentialsReady) return false;

    // Kimlikler kaydedilmiş olsa bile, Postgres gerçekten erişilebilir olmayabilir
    // (yanlış şifre/db adı, geçici ağ sorunu vb.). Desktop akışında "hazır" saymadan önce
    // bağlantıyı doğrula.
    return VeritabaniYapilandirma.testSavedCloudDatabaseConnection(
      timeout: const Duration(seconds: 6),
    );
  }

  Future<void> _savePendingTransferChoiceValue(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      VeritabaniYapilandirma.prefPendingTransferChoiceKey,
      normalized,
    );
  }

  Future<void> _clearPendingTransferChoice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(VeritabaniYapilandirma.prefPendingTransferChoiceKey);
  }

  Future<void> _handleDesktopSave() async {
    final String oncekiMod = VeritabaniYapilandirma.connectionMode;
    final String? oncekiYerelHost = VeritabaniYapilandirma.discoveredHost;

    String normalizeMode(String mode) => mode == 'cloud' ? 'cloud' : 'local';
    final String previousUiMode =
        oncekiMod == VeritabaniYapilandirma.cloudPendingMode
        ? 'cloud'
        : oncekiMod;

    // Desktop: sadece Yerel <-> Bulut akışı (Bulut: sadece internet).
    // Hibrit ve diğer ayarlar: mevcut davranışı bozma.
    if (_seciliMod != 'local' && _seciliMod != 'cloud') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings.ai.save_success')),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Cloud Pending -> Local: beklemeyi iptal et, yerelden devam et.
    if (_seciliMod == 'local' &&
        oncekiMod == VeritabaniYapilandirma.cloudPendingMode) {
      await VeritabaniYapilandirma.saveConnectionPreferences(
        'local',
        oncekiYerelHost,
      );
      await VeritabaniAktarimServisi().niyetTemizle();
      await _clearPendingTransferChoice();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings.ai.save_success')),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Local/Hybrid -> Cloud
    if (_seciliMod == 'cloud' && oncekiMod != 'cloud') {
      // Desktop: her seferinde admin tarafını kontrol et (cache'e güvenme).
      // Hazır değilse "Online Veritabanı Hazırlanıyor" akışına düş.
      final bool credsReady =
          await _desktopBulutKimlikleriniHazirlaBestEffort();

      final localHost =
          ((oncekiYerelHost ?? '').trim().isNotEmpty
                  ? oncekiYerelHost!
                  : '127.0.0.1')
              .trim();
      final localCompanyDb = OturumServisi().aktifVeritabaniAdi;

      // Cloud kimlikleri yoksa: cloud_pending kaydet, yerelden devam et.
      if (!credsReady) {
        // Eski/stale kimlikler varsa: pending modda yanlışlıkla "hazır" sayılmasın.
        await VeritabaniYapilandirma.clearCloudDatabaseCredentials();
        await _clearPendingTransferChoice();

        await VeritabaniAktarimServisi().niyetKaydet(
          VeritabaniAktarimNiyeti(
            fromMode: normalizeMode(oncekiMod),
            toMode: 'cloud',
            localHost: localHost.isEmpty ? null : localHost,
            localCompanyDb: localCompanyDb,
            createdAt: DateTime.now(),
          ),
        );

        await VeritabaniYapilandirma.saveConnectionPreferences(
          VeritabaniYapilandirma.cloudPendingMode,
          oncekiYerelHost,
        );

        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Container(
                width: 450,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('setup.cloud.preparing_title'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('setup.cloud.preparing_message'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF606368),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              foregroundColor: const Color(0xFF2C3E50),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: Text(tr('common.ok')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return;
      }

      if (!mounted) return;
      final secim = await veritabaniAktarimSecimDialogGoster(
        context: context,
        localToCloud: true,
      );
      if (secim == null) {
        if (mounted) setState(() => _seciliMod = previousUiMode);
        return;
      }

      if (secim == DesktopVeritabaniAktarimSecimi.hicbirSeyYapma) {
        await VeritabaniAktarimServisi().niyetTemizle();
        await _clearPendingTransferChoice();
      } else {
        final choiceValue = secim == DesktopVeritabaniAktarimSecimi.birlestir
            ? 'merge'
            : 'full';
        await _savePendingTransferChoiceValue(choiceValue);
        await VeritabaniAktarimServisi().niyetKaydet(
          VeritabaniAktarimNiyeti(
            fromMode: normalizeMode(oncekiMod),
            toMode: 'cloud',
            localHost: localHost.isEmpty ? null : localHost,
            localCompanyDb: localCompanyDb,
            createdAt: DateTime.now(),
          ),
        );
      }

      await VeritabaniYapilandirma.saveConnectionPreferences(
        'cloud',
        oncekiYerelHost,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BootstrapSayfasi()),
        (_) => false,
      );
      return;
    }

    // Cloud -> Local
    if (_seciliMod == 'local' && oncekiMod == 'cloud') {
      final secim = await veritabaniAktarimSecimDialogGoster(
        context: context,
        localToCloud: false,
      );
      if (secim == null) {
        if (mounted) setState(() => _seciliMod = 'cloud');
        return;
      }

      if (secim == DesktopVeritabaniAktarimSecimi.hicbirSeyYapma) {
        await VeritabaniAktarimServisi().niyetTemizle();
        await _clearPendingTransferChoice();
      } else {
        final choiceValue = secim == DesktopVeritabaniAktarimSecimi.birlestir
            ? 'merge'
            : 'full';
        await _savePendingTransferChoiceValue(choiceValue);
        final localHost =
            ((oncekiYerelHost ?? '').trim().isNotEmpty
                    ? oncekiYerelHost!
                    : '127.0.0.1')
                .trim();

        await VeritabaniAktarimServisi().niyetKaydet(
          VeritabaniAktarimNiyeti(
            fromMode: 'cloud',
            toMode: 'local',
            localHost: localHost.isEmpty ? null : localHost,
            localCompanyDb: null,
            createdAt: DateTime.now(),
          ),
        );
      }

      await VeritabaniYapilandirma.saveConnectionPreferences(
        'local',
        oncekiYerelHost,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BootstrapSayfasi()),
        (_) => false,
      );
      return;
    }

    // Diğer durumlar: mevcut davranış (başka özelliği bozma).
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('settings.ai.save_success')),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildYerelSemaIndirmeCard(
    Color primaryColor, {
    required bool isMobile,
  }) {
    final bool canExportLocalSchema =
        VeritabaniYapilandirma.connectionMode == 'local' &&
        _seciliMod == 'local';
    final String aktifDb = OturumServisi().aktifVeritabaniAdi;

    final String subtitle = canExportLocalSchema
        ? '${tr('settings.database.schema_export.desc')} (DB: $aktifDb)'
        : tr('settings.database.schema_export.only_local');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: _buildBackupRow(
        title: tr('settings.database.schema_export.row_title'),
        subtitle: subtitle,
        trailing: SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            onPressed: (!canExportLocalSchema || _semaIndiriliyor)
                ? null
                : () async => _yerelSemayiSqlOlarakIndir(primaryColor),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            icon: _semaIndiriliyor
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.code_rounded, size: 18),
            label: Text(
              tr('settings.database.schema_export.button'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        isMobile: isMobile,
      ),
    );
  }

  String _schemaFileName(String dbName) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final ts =
        '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
    final safeDb = dbName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'patisyo_${safeDb}_schema_$ts.sql';
  }

  Future<void> _yerelSemayiSqlOlarakIndir(Color primaryColor) async {
    if (_semaIndiriliyor) return;

    final bool canExportLocalSchema =
        VeritabaniYapilandirma.connectionMode == 'local' &&
        _seciliMod == 'local';
    if (!canExportLocalSchema) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings.database.schema_export.only_local')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _semaIndiriliyor = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastPath = prefs.getString('last_sql_schema_export_path');

      final dbName = OturumServisi().aktifVeritabaniAdi;
      final fileName = _schemaFileName(dbName);

      final FileSaveLocation? result = await getSaveLocation(
        suggestedName: fileName,
        initialDirectory: lastPath,
        acceptedTypeGroups: [
          XTypeGroup(
            label: 'SQL',
            extensions: const ['sql'],
            uniformTypeIdentifiers: const ['public.sql'],
          ),
        ],
      );

      if (result == null) return;

      final outputPath = result.path;
      await VeritabaniYapilandirma().yerelSemayiSqlOlarakDisariAktar(
        outputPath: outputPath,
        databaseName: dbName,
      );

      try {
        await prefs.setString(
          'last_sql_schema_export_path',
          File(outputPath).parent.path,
        );
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'common.success.export_path',
              args: {'name': 'SQL', 'path': outputPath},
            ),
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('common.error.generic')}$e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _semaIndiriliyor = false);
    }
  }
}
