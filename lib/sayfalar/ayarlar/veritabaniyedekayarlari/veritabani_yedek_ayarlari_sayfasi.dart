import 'dart:io';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nsd/nsd.dart' show Service;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../bilesenler/veritabani_aktarim_secim_dialog.dart';
import '../../../bilesenler/standart_alt_aksiyon_bar.dart';
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

enum _BulutVeritabaniSecimTipi { mevcut, yeni }

class _BulutOnlineDbKaynakAdayi {
  final OnlineVeritabaniCihazBilgisi cihaz;
  final OnlineVeritabaniKimlikleri kimlikler;

  const _BulutOnlineDbKaynakAdayi({
    required this.cihaz,
    required this.kimlikler,
  });
}

class _BulutVeritabaniSecimSonucu {
  final _BulutVeritabaniSecimTipi tip;
  final _BulutOnlineDbKaynakAdayi? kaynak;

  const _BulutVeritabaniSecimSonucu._(this.tip, this.kaynak);

  const _BulutVeritabaniSecimSonucu.mevcut(_BulutOnlineDbKaynakAdayi kaynak)
    : this._(_BulutVeritabaniSecimTipi.mevcut, kaynak);

  const _BulutVeritabaniSecimSonucu.yeni()
    : this._(_BulutVeritabaniSecimTipi.yeni, null);
}

class _BulutHazirlikDurumu {
  final bool cloudReadyNow;
  final bool requestSent;

  const _BulutHazirlikDurumu({
    required this.cloudReadyNow,
    required this.requestSent,
  });
}

class VeritabaniYedekAyarlariSayfasi extends StatefulWidget {
  const VeritabaniYedekAyarlariSayfasi({super.key, this.standalone = false});

  /// Bu sayfa ana uygulama menüsünde gömülü olarak da kullanılıyor.
  /// `standalone: true` olduğunda (örn. giriş ekranından açıldığında) geri/ESC ve
  /// altta Kaydet/İptal aksiyon barı gösterilir.
  final bool standalone;

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

  late String _kayitliMod;
  late bool _kayitliYedeklemeAcik;
  late String _kayitliYedeklemePeriyodu;

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

    _kayitliMod = _seciliMod;
    _kayitliYedeklemeAcik = _yedeklemeAcik;
    _kayitliYedeklemePeriyodu = _yedeklemePeriyodu;
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
            if (_kayitliMod == 'hybrid') _kayitliMod = 'local';
          });
        }

        final content = _buildIcerik(
          primaryColor,
          isLiteBackupKapali: isLiteBackupKapali,
          isMobile: isMobile,
          isMobilePlatform: isMobilePlatform,
          isDesktopPlatform: isDesktopPlatform,
          showSaveButton: false,
        );

        if (!widget.standalone) {
          final bool isCompactLayout = MediaQuery.sizeOf(context).width < 860;
          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.grey.shade50,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isMobile ? 14.0 : 24.0),
                        child: content,
                      ),
                    ),
                  ),
                  _buildMenuActionBar(primaryColor, isCompact: isCompactLayout),
                ],
              ),
            ),
          );
        }

        final theme = Theme.of(context);
        final bool isCompactLayout = MediaQuery.sizeOf(context).width < 900;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: theme.colorScheme.onSurface,
                  ),
                  onPressed: _handleCancel,
                ),
                if (isDesktopPlatform)
                  Text(
                    tr('common.esc'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            leadingWidth: isDesktopPlatform ? 80 : 56,
            title: Text(
              tr('nav.settings.database_backup'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 21,
              ),
            ),
            centerTitle: false,
          ),
          body: FocusScope(
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: content,
                      ),
                    ),
                  ),
                ),
                _buildStandaloneActionBar(
                  primaryColor,
                  isCompact: isCompactLayout,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcerik(
    Color primaryColor, {
    required bool isLiteBackupKapali,
    required bool isMobile,
    required bool isMobilePlatform,
    required bool isDesktopPlatform,
    required bool showSaveButton,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          primaryColor,
          isMobile: isMobile,
          standalone: widget.standalone,
        ),
        if (isLiteBackupKapali) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primaryColor.withValues(alpha: 0.18)),
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
          _buildYerelSemaIndirmeCard(primaryColor, isMobile: isMobile),
        ],
        if (showSaveButton) ...[
          SizedBox(height: isMobile ? 32 : 48),
          _buildSaveButton(),
        ] else ...[
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  void _handleCancel() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _handleCancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _kayitliDegerleriGuncelle() {
    _kayitliMod = _seciliMod;
    _kayitliYedeklemeAcik = _yedeklemeAcik;
    _kayitliYedeklemePeriyodu = _yedeklemePeriyodu;
  }

  void _iptalEt() {
    setState(() {
      _seciliMod = _kayitliMod;
      _yedeklemeAcik = _kayitliYedeklemeAcik;
      _yedeklemePeriyodu = _kayitliYedeklemePeriyodu;
    });
  }

  Widget _buildMenuActionBar(Color primaryColor, {required bool isCompact}) {
    return StandartAltAksiyonBar(
      isCompact: isCompact,
      secondaryText: tr('common.cancel'),
      onSecondaryPressed: _iptalEt,
      primaryText: tr('common.save'),
      onPrimaryPressed: _buildSaveButtonOnPressed,
      textColor: primaryColor,
      alignment: Alignment.centerRight,
    );
  }

  Widget _buildStandaloneActionBar(
    Color primaryColor, {
    required bool isCompact,
  }) {
    return StandartAltAksiyonBar(
      isCompact: isCompact,
      secondaryText: tr('common.cancel'),
      onSecondaryPressed: _handleCancel,
      primaryText: tr('common.save'),
      onPrimaryPressed: _buildSaveButtonOnPressed,
      textColor: primaryColor,
    );
  }

  Future<void> _buildSaveButtonOnPressed() async => _handleSavePressed();

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

  Widget _buildHeader(
    Color primaryColor, {
    required bool isMobile,
    bool standalone = false,
  }) {
    if (!standalone) {
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

    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.storage_rounded, color: primaryColor, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('nav.settings.database_backup'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontSize: isMobile ? 20 : 23,
                ),
              ),
              Text(
                tr('settings.database.subtitle'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: isMobile ? 13 : 16,
                ),
              ),
            ],
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
      mouseCursor: WidgetStateMouseCursor.clickable,
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
                    mouseCursor: WidgetStateMouseCursor.clickable,
                    dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
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
        onPressed: _buildSaveButtonOnPressed,
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

  Future<void> _ensureSupabaseInitializedBestEffort() async {
    try {
      await Supabase.initialize(url: LisansServisi.u, anonKey: LisansServisi.k);
    } catch (_) {
      // Zaten başlatılmış olabilir.
    }
  }

  Future<void> _showCloudAccessErrorDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                tr('setup.cloud.error_title'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('setup.cloud.access_error_contact_support'),
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

  Future<List<_BulutOnlineDbKaynakAdayi>> _bulutMevcutKaynaklariGetir({
    required String currentHardwareId,
    required String licenseId,
  }) async {
    final normalizedHw = currentHardwareId.trim();
    final normalizedLicense = licenseId.trim();
    if (normalizedHw.isEmpty || normalizedLicense.isEmpty) return const [];

    final devices = await OnlineVeritabaniServisi()
        .cihazBilgileriGetirByLisansKimligi(normalizedLicense);

    final otherDevices = devices
        .where(
          (d) =>
              d.hardwareId.trim().isNotEmpty &&
              d.hardwareId.trim() != normalizedHw,
        )
        .toList();

    final List<_BulutOnlineDbKaynakAdayi> kaynaklar = [];
    for (final device in otherDevices) {
      final creds = await OnlineVeritabaniServisi().kimlikleriGetir(
        device.hardwareId,
      );
      if (creds != null) {
        kaynaklar.add(
          _BulutOnlineDbKaynakAdayi(cihaz: device, kimlikler: creds),
        );
      }
    }

    return kaynaklar;
  }

  Future<_BulutVeritabaniSecimSonucu?> _bulutBirlesikLisansSecimDialogGoster({
    required List<_BulutOnlineDbKaynakAdayi> kaynaklar,
  }) async {
    if (!mounted) return null;
    if (kaynaklar.isEmpty) return null;

    final firstDeviceName = kaynaklar.first.cihaz.displayName;

    return showDialog<_BulutVeritabaniSecimSonucu>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool mevcutSecili = true;
        int selectedIndex = 0;

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Container(
                width: 520,
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
                      tr('setup.cloud.cross_device_choice.title'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tr(
                        'setup.cloud.cross_device_choice.message',
                        args: {'device': firstDeviceName},
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF606368),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    CheckboxListTile(
                      value: mevcutSecili,
                      onChanged: (_) => setState(() => mevcutSecili = true),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        tr(
                          'setup.cloud.cross_device_choice.use_existing_title',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202124),
                        ),
                      ),
                      subtitle: Text(
                        tr('setup.cloud.cross_device_choice.use_existing_desc'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF606368),
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (mevcutSecili && kaynaklar.length > 1) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        mouseCursor: WidgetStateMouseCursor.clickable,
                        dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
                        initialValue: selectedIndex,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: tr(
                            'setup.cloud.cross_device_choice.source_label',
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        items: [
                          for (int i = 0; i < kaynaklar.length; i++)
                            DropdownMenuItem<int>(
                              value: i,
                              child: Text(kaynaklar[i].cihaz.displayName),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => selectedIndex = v);
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      value: !mevcutSecili,
                      onChanged: (_) => setState(() => mevcutSecili = false),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        tr('setup.cloud.cross_device_choice.create_new_title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202124),
                        ),
                      ),
                      subtitle: Text(
                        tr('setup.cloud.cross_device_choice.create_new_desc'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF606368),
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(null),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            foregroundColor: const Color(0xFF2C3E50),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: Text(tr('common.cancel')),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            if (mevcutSecili) {
                              Navigator.of(ctx).pop(
                                _BulutVeritabaniSecimSonucu.mevcut(
                                  kaynaklar[selectedIndex],
                                ),
                              );
                            } else {
                              Navigator.of(
                                ctx,
                              ).pop(const _BulutVeritabaniSecimSonucu.yeni());
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF81C784),
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          child: Text(tr('common.continue')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<_BulutHazirlikDurumu?> _bulutGecisHazirla({
    required String requestSource,
    required Duration connectionTestTimeout,
  }) async {
    await _ensureSupabaseInitializedBestEffort();

    try {
      await LisansServisi().baslat();
    } catch (_) {}

    final hardwareId = (LisansServisi().hardwareId ?? '').trim();
    if (hardwareId.isEmpty) return null;

    // Not: Lisans birleştirme (license_id) durumu admin panelden sonradan değişebilir.
    // Bu ekranda kullanıcı "Bulut" seçtiği anda, cache yerine sunucudaki en güncel license_id ile kontrol et.
    String licenseId = (LisansServisi().licenseId ?? '').trim();
    try {
      final data = await Supabase.instance.client
          .from('program_deneme')
          .select('license_id')
          .eq('hardware_id', hardwareId)
          .maybeSingle();
      if (data is Map<String, dynamic>) {
        final serverLicenseId = data['license_id']?.toString().trim();
        if (serverLicenseId != null && serverLicenseId.isNotEmpty) {
          licenseId = serverLicenseId;
        }
      }
    } on PostgrestException catch (e) {
      final msg = (e.message).toLowerCase();
      final licenseIdColumnMissing =
          msg.contains('license_id') &&
          (msg.contains('column') || msg.contains('schema'));
      if (!licenseIdColumnMissing) {
        // Best-effort: akışı bozma, cache ile devam et.
        debugPrint('license_id fetch failed (best-effort): $e');
      }
    } catch (_) {}
    if (licenseId.isNotEmpty) {
      final kaynaklar = await _bulutMevcutKaynaklariGetir(
        currentHardwareId: hardwareId,
        licenseId: licenseId,
      );

      if (kaynaklar.isNotEmpty) {
        final secim = await _bulutBirlesikLisansSecimDialogGoster(
          kaynaklar: kaynaklar,
        );
        if (secim == null) return null;

        if (secim.tip == _BulutVeritabaniSecimTipi.yeni) {
          await VeritabaniYapilandirma.clearCloudDatabaseCredentials();
          await OnlineVeritabaniServisi().talepGonder(
            hardwareId: hardwareId,
            source: requestSource,
          );
          return const _BulutHazirlikDurumu(
            cloudReadyNow: false,
            requestSent: true,
          );
        }

        final selected = secim.kaynak;
        if (selected != null) {
          await VeritabaniYapilandirma.saveCloudDatabaseCredentials(
            host: selected.kimlikler.host,
            port: selected.kimlikler.port,
            username: selected.kimlikler.username,
            password: selected.kimlikler.password,
            database: selected.kimlikler.database,
            sslRequired: selected.kimlikler.sslRequired,
          );

          // Admin panel görünürlüğü için bu cihaza da kopyala (best-effort).
          await OnlineVeritabaniServisi().kimlikleriCihazaKaydet(
            hardwareId: hardwareId,
            kimlikler: selected.kimlikler,
          );

          final ok = VeritabaniYapilandirma.testSavedCloudDatabaseConnection(
            timeout: connectionTestTimeout,
          );

          return _BulutHazirlikDurumu(
            cloudReadyNow: await ok,
            requestSent: false,
          );
        }
      }
    }

    final creds = await OnlineVeritabaniServisi().kimlikleriGetir(hardwareId);
    if (creds == null) {
      await VeritabaniYapilandirma.clearCloudDatabaseCredentials();
      await OnlineVeritabaniServisi().talepGonder(
        hardwareId: hardwareId,
        source: requestSource,
      );
      return const _BulutHazirlikDurumu(
        cloudReadyNow: false,
        requestSent: true,
      );
    }

    await VeritabaniYapilandirma.saveCloudDatabaseCredentials(
      host: creds.host,
      port: creds.port,
      username: creds.username,
      password: creds.password,
      database: creds.database,
      sslRequired: creds.sslRequired,
    );

    final ok = await VeritabaniYapilandirma.testSavedCloudDatabaseConnection(
      timeout: connectionTestTimeout,
    );
    return _BulutHazirlikDurumu(cloudReadyNow: ok, requestSent: false);
  }

  Future<void> _handleSavePressed() async {
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
      _kayitliDegerleriGuncelle();
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

    final String previousUiMode =
        oncekiMod == VeritabaniYapilandirma.cloudPendingMode
        ? 'cloud'
        : oncekiMod;
    final String normalizedOncekiMod =
        oncekiMod == VeritabaniYapilandirma.cloudPendingMode
        ? 'cloud'
        : oncekiMod;

    // Local <-> Cloud geçişinde:
    // - Bulut kimlikleri hazırsa veri aktarım seçimini sor.
    // - Hazır değilse talep gönder ve "hazırlanıyor" mesajını göster.
    final bool modDegisti = normalizedOncekiMod != _seciliMod;
    final bool localCloudSwitch =
        (normalizedOncekiMod == 'local' && _seciliMod == 'cloud') ||
        (normalizedOncekiMod == 'cloud' && _seciliMod == 'local');

    DesktopVeritabaniAktarimSecimi? transferSecim;
    _BulutHazirlikDurumu? bulutDurumu;
    final bool localToCloud =
        modDegisti &&
        localCloudSwitch &&
        normalizedOncekiMod == 'local' &&
        _seciliMod == 'cloud';
    final bool cloudToLocal =
        modDegisti &&
        localCloudSwitch &&
        normalizedOncekiMod == 'cloud' &&
        _seciliMod == 'local';

    if (localToCloud) {
      bulutDurumu = await _bulutGecisHazirla(
        requestSource: 'database_settings',
        connectionTestTimeout: const Duration(seconds: 8),
      );
      if (bulutDurumu == null) {
        if (mounted) setState(() => _seciliMod = previousUiMode);
        return;
      }

      if (!bulutDurumu.cloudReadyNow && !bulutDurumu.requestSent) {
        await _showCloudAccessErrorDialog();
        if (mounted) setState(() => _seciliMod = previousUiMode);
        return;
      }

      if (bulutDurumu.cloudReadyNow) {
        if (!mounted) return;
        transferSecim = await veritabaniAktarimSecimDialogGoster(
          context: context,
          localToCloud: true,
          barrierDismissible: false,
        );
        if (transferSecim == null) {
          if (mounted) setState(() => _seciliMod = previousUiMode);
          return;
        }
      }
    } else if (cloudToLocal) {
      if (!mounted) return;
      transferSecim = await veritabaniAktarimSecimDialogGoster(
        context: context,
        localToCloud: false,
        barrierDismissible: false,
      );
      if (transferSecim == null) {
        if (mounted) setState(() => _seciliMod = previousUiMode);
        return;
      }
    }

    await VeritabaniYapilandirma.saveConnectionPreferences(
      _seciliMod,
      _seciliMod == 'local' ? yerelHostKaydi : null,
    );

    if (modDegisti && localCloudSwitch) {
      if (transferSecim == null) {
        // Cloud seçildi ama kimlikler hazır değil: veri aktarımı ekranını gösterme.
        await _clearPendingTransferChoice();

        final localHost = (oncekiYerelHost ?? '').trim();
        await VeritabaniAktarimServisi().niyetKaydet(
          VeritabaniAktarimNiyeti(
            fromMode: normalizedOncekiMod,
            toMode: _seciliMod,
            localHost: localHost.isEmpty ? null : localHost,
            localCompanyDb: oncekiYerelCompanyDb,
            createdAt: DateTime.now(),
          ),
        );
      } else if (transferSecim ==
          DesktopVeritabaniAktarimSecimi.hicbirSeyYapma) {
        await VeritabaniAktarimServisi().niyetTemizle();
        await _clearPendingTransferChoice();
      } else {
        final choiceValue =
            transferSecim == DesktopVeritabaniAktarimSecimi.birlestir
            ? 'merge'
            : 'full';
        await _savePendingTransferChoiceValue(choiceValue);

        final localHost =
            (normalizedOncekiMod == 'local'
                    ? (oncekiYerelHost ?? '')
                    : (yerelHostKaydi ?? ''))
                .trim();
        await VeritabaniAktarimServisi().niyetKaydet(
          VeritabaniAktarimNiyeti(
            fromMode: normalizedOncekiMod,
            toMode: _seciliMod,
            localHost: localHost.isEmpty ? null : localHost,
            localCompanyDb: oncekiYerelCompanyDb,
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    final bool shouldShowPreparingDialog =
        localToCloud && (bulutDurumu?.requestSent ?? false);

    if (shouldShowPreparingDialog && mounted) {
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

    if (!mounted) return;

    if (modDegisti) {
      _kayitliDegerleriGuncelle();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BootstrapSayfasi()),
        (_) => false,
      );
      return;
    }

    _kayitliDegerleriGuncelle();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('settings.ai.save_success')),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
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
      _kayitliDegerleriGuncelle();
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
      _kayitliDegerleriGuncelle();
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
      final localHost =
          ((oncekiYerelHost ?? '').trim().isNotEmpty
                  ? oncekiYerelHost!
                  : '127.0.0.1')
              .trim();
      final localCompanyDb = OturumServisi().aktifVeritabaniAdi;

      final bulutDurumu = await _bulutGecisHazirla(
        requestSource: 'desktop_settings',
        connectionTestTimeout: const Duration(seconds: 6),
      );
      if (bulutDurumu == null) {
        if (mounted) setState(() => _seciliMod = previousUiMode);
        return;
      }

      if (!bulutDurumu.cloudReadyNow && !bulutDurumu.requestSent) {
        await _showCloudAccessErrorDialog();
        if (mounted) setState(() => _seciliMod = previousUiMode);
        return;
      }

      if (!bulutDurumu.cloudReadyNow) {
        // Cloud kimlikleri hazır değil (veya bağlantı doğrulanamadı): cloud_pending kaydet, yerelden devam et.
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

        final bool shouldShowPreparingDialog = bulutDurumu.requestSent;
        if (shouldShowPreparingDialog && mounted) {
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

        _kayitliDegerleriGuncelle();
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
    _kayitliDegerleriGuncelle();
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
