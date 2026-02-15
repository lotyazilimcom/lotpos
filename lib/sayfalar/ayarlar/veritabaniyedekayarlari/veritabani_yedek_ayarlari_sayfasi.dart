import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../servisler/lite_ayarlar_servisi.dart';
import '../../../servisler/lite_kisitlari.dart';
import '../../../servisler/lisans_servisi.dart';
import '../../../servisler/online_veritabani_servisi.dart';
import '../../../servisler/oturum_servisi.dart';
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
    _seciliMod = VeritabaniYapilandirma.connectionMode;
    if (_seciliMod != 'local' && _seciliMod != 'hybrid' && _seciliMod != 'cloud') {
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
        final bool isMobilePlatform = defaultTargetPlatform == TargetPlatform.iOS ||
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

    return Column(
      children: children,
    );
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

          if (!isMobilePlatform) {
            // Desktop/Web davranışını hiç bozma
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tr('settings.ai.save_success')),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          final String oncekiMod = VeritabaniYapilandirma.connectionMode;

          if (_seciliMod == 'local') {
            final host = VeritabaniYapilandirma.discoveredHost;
            if (host == null || host.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr('settings.database.mobile_local_requires_server')),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
          }

          await VeritabaniYapilandirma.saveConnectionPreferences(
            _seciliMod,
            _seciliMod == 'local' ? VeritabaniYapilandirma.discoveredHost : null,
          );

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
          }

          if (!mounted) return;

          final bool modDegisti = oncekiMod != _seciliMod;
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

  Widget _buildYerelSemaIndirmeCard(Color primaryColor, {required bool isMobile}) {
    final bool canExportLocalSchema =
        VeritabaniYapilandirma.connectionMode == 'local' && _seciliMod == 'local';
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
        VeritabaniYapilandirma.connectionMode == 'local' && _seciliMod == 'local';
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
