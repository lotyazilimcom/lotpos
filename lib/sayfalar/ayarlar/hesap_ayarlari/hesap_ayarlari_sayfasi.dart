import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../bilesenler/standart_alt_aksiyon_bar.dart';
import '../../../bilesenler/lisans_diyalog.dart';
import '../../../servisler/lisans_servisi.dart';
import '../../../servisler/lite_ayarlar_servisi.dart';
import '../../../servisler/lite_kisitlari.dart';
import '../../../servisler/pro_satin_alma_servisi.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import 'lospay_kredi_yukle_dialog.dart';
import 'pro_satin_alma_dialog.dart';

class HesapAyarlariSayfasi extends StatefulWidget {
  const HesapAyarlariSayfasi({super.key});

  @override
  State<HesapAyarlariSayfasi> createState() => _HesapAyarlariSayfasiState();
}

class _HesapAyarlariSayfasiState extends State<HesapAyarlariSayfasi> {
  static const Color _primaryColor = Color(0xFF2C3E50);
  static const Color _accentColor = Color(0xFFEA4335);
  static const Color _proColor = Color(0xFFF39C12);
  static const Color _surfaceColor = Color(0xFFF8F9FA);
  static const Color _mutedColor = Color(0xFF6B7280);
  static const Duration _proCancelWindow = Duration(days: 15);

  bool _refreshing = false;
  bool _cancellingSubscription = false;
  bool _canCancelPro = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshStatus());
  }

  Future<void> _refreshStatus({bool showFeedback = false}) async {
    if (_refreshing) return;

    setState(() {
      _refreshing = true;
      _errorMessage = null;
      if (showFeedback) {
        _successMessage = null;
      }
    });

    try {
      await LisansServisi().dogrula();
      await LiteAyarlarServisi().senkronizeBestEffort(force: true);
      final canCancelPro = await _loadCancelAvailability();

      if (!mounted) return;
      setState(() {
        _canCancelPro = canCancelPro;
        if (showFeedback) {
          _successMessage = tr('settings.account.feedback.refresh_success');
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _canCancelPro = false;
        _errorMessage = tr('login.license.error.connection');
      });
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _copyIdentity(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('login.license.copy_success')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _safeIdentity(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return tr('settings.account.identity.unavailable');
    }
    return normalized;
  }

  String _formattedDate(DateTime? value) {
    if (value == null) return tr('settings.account.plan.expiry_unknown');
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$day.$month.$year';
  }

  String _formattedLosPay(double amount) {
    final normalized = amount.isFinite ? amount : 0;
    final hasFraction =
        (normalized - normalized.truncateToDouble()).abs() > 0.0001;
    final formatted = FormatYardimcisi.sayiFormatlaOndalikli(
      normalized,
      decimalDigits: hasFraction ? 2 : 0,
    );
    return '$formatted ${tr('settings.account.lospay.unit')}';
  }

  bool _isLitePackageName(String? packageName) {
    final value = (packageName ?? '').trim().toUpperCase();
    if (value.isEmpty) return true;
    return value.contains('LITE');
  }

  bool _canCancelFromLicenseData(Map<String, dynamic>? data) {
    if (data == null) return false;

    final key = (data['license_key'] ?? '').toString().trim().toUpperCase();
    final packageName = data['package_name']?.toString();
    if (_isLitePackageName(packageName) ||
        key.isEmpty ||
        key.startsWith('CANCELLED')) {
      return false;
    }

    final startDateRaw = data['start_date'];
    if (startDateRaw == null) return false;

    final parsed = DateTime.tryParse(startDateRaw.toString());
    if (parsed == null) return false;

    final startDate = DateTime(parsed.year, parsed.month, parsed.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final elapsedDays = today.difference(startDate).inDays;

    return elapsedDays < _proCancelWindow.inDays;
  }

  Future<bool> _loadCancelAvailability() async {
    final data = await LisansServisi().lisansBilgisiGetir();
    return _canCancelFromLicenseData(data);
  }

  Color _statusColor(bool isLite) => isLite ? _accentColor : _proColor;

  Future<bool> _confirmCancelPro() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_cancellingSubscription,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.undo_rounded,
                  color: _accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('settings.account.cancel.confirm_title'),
                  style: const TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('settings.account.cancel.confirm_body'),
                style: const TextStyle(
                  color: _mutedColor,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _accentColor.withValues(alpha: 0.16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DialogBullet(
                      icon: Icons.payments_outlined,
                      text: tr('settings.account.cancel.confirm_refund'),
                    ),
                    const SizedBox(height: 10),
                    _DialogBullet(
                      icon: Icons.verified_user_outlined,
                      text: tr('settings.account.cancel.confirm_downgrade'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(tr('common.cancel')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: Text(
                tr('settings.account.cancel.confirm_action'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _handleCancelPro() async {
    if (_refreshing || _cancellingSubscription) return;

    final lisans = LisansServisi();
    final hardwareId = (lisans.hardwareId ?? '').trim().toUpperCase();
    final licenseId = (lisans.licenseId ?? '').trim().toUpperCase();

    if (hardwareId.isEmpty || licenseId.isEmpty) {
      setState(() {
        _errorMessage = tr('settings.account.feedback.cancel_error');
        _successMessage = null;
      });
      return;
    }

    final confirmed = await _confirmCancelPro();
    if (!mounted || !confirmed) return;

    setState(() {
      _cancellingSubscription = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final sonuc = await ProSatinAlmaServisi.proAboneliginiIptalEt(
        hardwareId: hardwareId,
        licenseId: licenseId,
      );

      try {
        await LisansServisi().dogrula();
        await LiteAyarlarServisi().senkronizeBestEffort(force: true);
      } catch (_) {}

      if (!mounted) return;

      final successMessage = sonuc.paymentChannel.isNotEmpty
          ? tr(
              'settings.account.feedback.cancel_success_with_channel',
              args: {'channel': sonuc.paymentChannel},
            )
          : tr('settings.account.feedback.cancel_success');

      setState(() {
        _successMessage = successMessage;
      });
    } on ProSatinAlmaHatasi catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.mesaj;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = tr('settings.account.feedback.cancel_error');
      });
    } finally {
      if (mounted) {
        setState(() {
          _cancellingSubscription = false;
        });
      }
    }
  }

  Future<void> _handlePrimaryAction(bool isLite) async {
    if (isLite) {
      final purchased = await showProSatinAlmaDialog(context);
      if (!mounted || purchased != true) return;
      await _refreshStatus(showFeedback: true);
      return;
    }
    await _refreshStatus(showFeedback: true);
  }

  Future<void> _handleLoadLosPayCredit() async {
    if (_refreshing || _cancellingSubscription) return;

    final loaded = await showLosPayKrediYukleDialog(context);
    if (!mounted || loaded != true) return;
    await _refreshStatus(showFeedback: true);
  }

  Future<void> _handleOpenLicenseDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const LisansDiyalog(),
    );

    if (!mounted || result != true) return;
    await _refreshStatus(showFeedback: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([LisansServisi(), LiteAyarlarServisi()]),
      builder: (context, _) {
        final lisans = LisansServisi();
        final isLite = lisans.isLiteMode;
        final showCancelCard = !isLite && _canCancelPro;
        final busy = _refreshing || _cancellingSubscription;
        final canUseOnlineActions =
            lisans.serverReachabilityKnown && lisans.serverReachable;
        final accent = _statusColor(isLite);
        final hardwareId = _safeIdentity(lisans.hardwareId);
        final masterLicenseId = _safeIdentity(lisans.licenseId);
        final licenseDate = lisans.licenseEndDate;
        final losPayBalance = lisans.losPayBalance;
        final banner = _buildBanner();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 920;
            final bool singleColumn = constraints.maxWidth < 1100;

            return CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): () =>
                    _handlePrimaryAction(isLite),
                const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
                    _handlePrimaryAction(isLite),
              },
              child: Focus(
                autofocus: true,
                child: Scaffold(
                  backgroundColor: Colors.white,
                  body: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        _buildHeader(
                          isCompact: isCompact,
                          isLite: isLite,
                          losPayBalance: losPayBalance,
                        ),
                        Expanded(
                          child: Container(
                            color: _surfaceColor,
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                isCompact ? 16 : 24,
                                isCompact ? 16 : 20,
                                isCompact ? 16 : 24,
                                24,
                              ),
                              child: Column(
                                children: [
                                  _buildHeroCard(
                                    isLite: isLite,
                                    accent: accent,
                                    masterLicenseId: masterLicenseId,
                                    licenseDate: licenseDate,
                                    losPayBalance: losPayBalance,
                                    isCompact: isCompact,
                                  ),
                                  const SizedBox(height: 16),
                                  if (banner != null) ...[
                                    banner,
                                    const SizedBox(height: 16),
                                  ],
                                  if (singleColumn) ...[
                                    _buildIdentitySection(
                                      accent: accent,
                                      masterLicenseId: masterLicenseId,
                                      hardwareId: hardwareId,
                                      isCompact: isCompact,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildPlanSection(
                                      isLite: isLite,
                                      showCancelCard: showCancelCard,
                                      accent: accent,
                                      licenseDate: licenseDate,
                                      losPayBalance: losPayBalance,
                                      canUseOnlineActions: canUseOnlineActions,
                                    ),
                                  ] else
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 6,
                                          child: _buildIdentitySection(
                                            accent: accent,
                                            masterLicenseId: masterLicenseId,
                                            hardwareId: hardwareId,
                                            isCompact: isCompact,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          flex: 5,
                                          child: _buildPlanSection(
                                            isLite: isLite,
                                            showCancelCard: showCancelCard,
                                            accent: accent,
                                            licenseDate: licenseDate,
                                            losPayBalance: losPayBalance,
                                            canUseOnlineActions:
                                                canUseOnlineActions,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 16),
                                  _buildLimitsSection(isCompact: isCompact),
                                  const SizedBox(height: 16),
                                  _buildFeatureSection(isCompact: isCompact),
                                ],
                              ),
                            ),
                          ),
                        ),
                        StandartAltAksiyonBar(
                          isCompact: isCompact,
                          secondaryText: tr('settings.account.actions.refresh'),
                          onSecondaryPressed: busy || !canUseOnlineActions
                              ? null
                              : () => _refreshStatus(showFeedback: true),
                          primaryText: isLite
                              ? tr('settings.account.actions.upgrade')
                              : tr('settings.account.actions.verify'),
                          onPrimaryPressed: busy || !canUseOnlineActions
                              ? null
                              : () => _handlePrimaryAction(isLite),
                          primaryLoading: _refreshing,
                          primaryColor: isLite ? _accentColor : _primaryColor,
                          alignment: Alignment.centerRight,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader({
    required bool isCompact,
    required bool isLite,
    required double losPayBalance,
  }) {
    final accent = _statusColor(isLite);
    final lisans = LisansServisi();
    final canUseOnlineActions =
        lisans.serverReachabilityKnown && lisans.serverReachable;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isCompact ? 16 : 24,
        isCompact ? 14 : 20,
        isCompact ? 16 : 24,
        isCompact ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('settings.account.title'),
                style: TextStyle(
                  fontSize: isCompact ? 20 : 22,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr('settings.account.subtitle'),
                style: const TextStyle(fontSize: 13, color: _mutedColor),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              TextButton.icon(
                onPressed:
                    (_refreshing || _cancellingSubscription || !canUseOnlineActions)
                    ? null
                    : _handleLoadLosPayCredit,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB7791F),
                  backgroundColor: const Color(0xFFFFF8EE),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
                    ),
                  ),
                ),
                icon: const Icon(Icons.add_card_rounded, size: 18),
                label: Text(
                  tr('settings.account.actions.load_credit'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              _buildLosPayBadge(
                value: _formattedLosPay(losPayBalance),
                compact: isCompact,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLite
                          ? Icons.verified_user_outlined
                          : Icons.workspace_premium_outlined,
                      color: accent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isLite
                          ? tr('settings.account.plan.lite_badge')
                          : tr('settings.account.plan.pro_badge'),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard({
    required bool isLite,
    required Color accent,
    required String masterLicenseId,
    required DateTime? licenseDate,
    required double losPayBalance,
    required bool isCompact,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 18 : 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, Color.lerp(_primaryColor, accent, 0.55)!],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  tr('settings.account.hero.label'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${tr('settings.account.lospay.label')} ${_formattedLosPay(losPayBalance)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isLite
                      ? tr('settings.account.plan.lite_badge')
                      : tr('settings.account.plan.pro_badge'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            isLite
                ? tr('settings.account.hero.lite_title')
                : tr('settings.account.hero.pro_title'),
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 24 : 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isLite
                ? tr('settings.account.hero.lite_body')
                : tr('settings.account.hero.pro_body'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroMetricChip(
                icon: Icons.vpn_key_outlined,
                label: tr('settings.account.summary.version'),
                value: isLite
                    ? tr('settings.account.plan.lite_badge')
                    : tr('settings.account.plan.pro_badge'),
              ),
              _HeroMetricChip(
                icon: Icons.badge_outlined,
                label: tr('settings.account.summary.master_id'),
                value: masterLicenseId,
              ),
              _HeroMetricChip(
                icon: Icons.event_available_outlined,
                label: tr('settings.account.summary.expiry'),
                value: _formattedDate(licenseDate),
              ),
              _HeroMetricChip(
                icon: Icons.account_balance_wallet_outlined,
                label: tr('settings.account.summary.lospay'),
                value: _formattedLosPay(losPayBalance),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildBanner() {
    final String? message = _errorMessage ?? _successMessage;
    if (message == null || message.isEmpty) return null;

    final bool isError = _errorMessage != null;
    final Color color = isError ? _accentColor : const Color(0xFF16A34A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? _primaryColor : const Color(0xFF166534),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentitySection({
    required Color accent,
    required String masterLicenseId,
    required String hardwareId,
    required bool isCompact,
  }) {
    return _SectionCard(
      title: tr('settings.account.ids.title'),
      subtitle: tr('settings.account.ids.subtitle'),
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          _IdentityCard(
            title: tr('login.license.master_id'),
            helper: tr('settings.account.master_id.help'),
            value: masterLicenseId,
            accent: accent,
            onCopy: () => _copyIdentity(masterLicenseId),
          ),
          const SizedBox(height: 14),
          _IdentityCard(
            title: tr('login.license.hardware_id'),
            helper: tr('settings.account.hardware_id.help'),
            value: hardwareId,
            accent: _primaryColor,
            onCopy: () => _copyIdentity(hardwareId),
          ),
          if (isCompact) ...[
            const SizedBox(height: 14),
            _InlineHelpCard(
              icon: Icons.info_outline_rounded,
              title: tr('settings.account.help.title'),
              body: tr('login.license.help'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanSection({
    required bool isLite,
    required bool showCancelCard,
    required Color accent,
    required DateTime? licenseDate,
    required double losPayBalance,
    required bool canUseOnlineActions,
  }) {
    return _SectionCard(
      title: tr('settings.account.plan.title'),
      subtitle: tr('settings.account.plan.subtitle'),
      icon: isLite ? Icons.shield_outlined : Icons.workspace_premium_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isLite
                            ? Icons.verified_user_outlined
                            : Icons.workspace_premium_outlined,
                        color: accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isLite
                            ? tr('settings.account.plan.lite_description')
                            : tr('settings.account.plan.pro_description'),
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _PlanInfoRow(
                  label: tr('settings.account.plan.expiry_label'),
                  value: _formattedDate(licenseDate),
                ),
                const SizedBox(height: 10),
                _PlanInfoRow(
                  label: tr('settings.account.summary.lospay'),
                  value: _formattedLosPay(losPayBalance),
                ),
                const SizedBox(height: 10),
                _PlanInfoRow(
                  label: tr('settings.account.summary.connectivity'),
                  value: _refreshing
                      ? tr('settings.account.summary.connectivity.checking')
                      : canUseOnlineActions
                      ? tr('settings.account.summary.connectivity.synced')
                      : tr('settings.account.summary.connectivity.offline'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF39C12).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFF39C12).withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.security_rounded,
                        color: Color(0xFFF39C12),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr('settings.account.manual.title'),
                        style: const TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  canUseOnlineActions
                      ? tr('settings.account.manual.body_online')
                      : tr('settings.account.manual.body_offline'),
                  style: const TextStyle(
                    color: _mutedColor,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  onPressed: _refreshing || _cancellingSubscription
                      ? null
                      : _handleOpenLicenseDialog,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF39C12).withValues(
                      alpha: 0.12,
                    ),
                    foregroundColor: const Color(0xFFB45309),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.vpn_key_rounded, size: 18),
                  label: Text(
                    tr('settings.account.actions.manual_license'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          if (showCancelCard) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _accentColor.withValues(alpha: 0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.undo_rounded,
                          color: _accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr('settings.account.cancel.title'),
                          style: const TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('settings.account.cancel.body'),
                    style: const TextStyle(
                      color: _mutedColor,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    onPressed: _cancellingSubscription
                        ? null
                        : () => _handleCancelPro(),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accentColor.withValues(alpha: 0.12),
                      foregroundColor: _accentColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _cancellingSubscription
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _accentColor,
                              ),
                            ),
                          )
                        : const Icon(Icons.undo_rounded, size: 18),
                    label: Text(
                      tr(
                        _cancellingSubscription
                            ? 'settings.account.cancel.processing'
                            : 'settings.account.cancel.action',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _InlineHelpCard(
            icon: Icons.support_agent_rounded,
            title: tr('settings.account.help.title'),
            body: tr('settings.account.help.body'),
          ),
        ],
      ),
    );
  }

  Widget _buildLosPayBadge({required String value, required bool compact}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 9 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: Color(0xFFB45309),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '${tr('settings.account.lospay.label')} $value',
            style: const TextStyle(
              color: Color(0xFFB45309),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitsSection({required bool isCompact}) {
    if (isCompact) {
      return _SectionCard(
        title: tr('settings.account.limits.title'),
        subtitle: tr('settings.account.limits.subtitle'),
        icon: Icons.dataset_outlined,
        child: Column(
          children: [
            _InsightMetricCard(
              label: tr('settings.account.limit.active_accounts'),
              value: LiteKisitlari.maxAktifCari.toString(),
              icon: Icons.people_outline_rounded,
            ),
            const SizedBox(height: 12),
            _InsightMetricCard(
              label: tr('settings.account.limit.daily_transactions'),
              value: LiteKisitlari.maxGunlukSatis.toString(),
              icon: Icons.swap_horiz_rounded,
            ),
            const SizedBox(height: 12),
            _InsightMetricCard(
              label: tr('settings.account.limit.daily_retail'),
              value: LiteKisitlari.maxGunlukPerakendeSatis.toString(),
              icon: Icons.point_of_sale_rounded,
            ),
            const SizedBox(height: 12),
            _InsightMetricCard(
              label: tr('settings.account.limit.report_days'),
              value: LiteKisitlari.raporGun.toString(),
              icon: Icons.assessment_outlined,
            ),
          ],
        ),
      );
    }

    return _SectionCard(
      title: tr('settings.account.limits.title'),
      subtitle: tr('settings.account.limits.subtitle'),
      icon: Icons.dataset_outlined,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _InsightMetricCard(
            label: tr('settings.account.limit.active_accounts'),
            value: LiteKisitlari.maxAktifCari.toString(),
            icon: Icons.people_outline_rounded,
            width: 250,
          ),
          _InsightMetricCard(
            label: tr('settings.account.limit.daily_transactions'),
            value: LiteKisitlari.maxGunlukSatis.toString(),
            icon: Icons.swap_horiz_rounded,
            width: 250,
          ),
          _InsightMetricCard(
            label: tr('settings.account.limit.daily_retail'),
            value: LiteKisitlari.maxGunlukPerakendeSatis.toString(),
            icon: Icons.point_of_sale_rounded,
            width: 250,
          ),
          _InsightMetricCard(
            label: tr('settings.account.limit.report_days'),
            value: LiteKisitlari.raporGun.toString(),
            icon: Icons.assessment_outlined,
            width: 250,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureSection({required bool isCompact}) {
    if (isCompact) {
      return _SectionCard(
        title: tr('settings.account.features.title'),
        subtitle: tr('settings.account.features.subtitle'),
        icon: Icons.tune_rounded,
        child: Column(
          children: [
            _FeatureAvailabilityCard(
              title: tr('settings.account.feature.bank_credit'),
              enabled: LiteKisitlari.isBankCreditActive,
            ),
            const SizedBox(height: 12),
            _FeatureAvailabilityCard(
              title: tr('settings.account.feature.check_note'),
              enabled: LiteKisitlari.isCheckPromissoryActive,
            ),
            const SizedBox(height: 12),
            _FeatureAvailabilityCard(
              title: tr('settings.account.feature.cloud_backup'),
              enabled: LiteKisitlari.isCloudBackupActive,
            ),
            const SizedBox(height: 12),
            _FeatureAvailabilityCard(
              title: tr('settings.account.feature.excel_export'),
              enabled: LiteKisitlari.isExcelExportActive,
            ),
          ],
        ),
      );
    }

    return _SectionCard(
      title: tr('settings.account.features.title'),
      subtitle: tr('settings.account.features.subtitle'),
      icon: Icons.tune_rounded,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _FeatureAvailabilityCard(
            width: 250,
            title: tr('settings.account.feature.bank_credit'),
            enabled: LiteKisitlari.isBankCreditActive,
          ),
          _FeatureAvailabilityCard(
            width: 250,
            title: tr('settings.account.feature.check_note'),
            enabled: LiteKisitlari.isCheckPromissoryActive,
          ),
          _FeatureAvailabilityCard(
            width: 250,
            title: tr('settings.account.feature.cloud_backup'),
            enabled: LiteKisitlari.isCloudBackupActive,
          ),
          _FeatureAvailabilityCard(
            width: 250,
            title: tr('settings.account.feature.excel_export'),
            enabled: LiteKisitlari.isExcelExportActive,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C3E50).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF2C3E50), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF2C3E50),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _HeroMetricChip extends StatelessWidget {
  const _HeroMetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 170, maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.title,
    required this.helper,
    required this.value,
    required this.accent,
    required this.onCopy,
  });

  final String title;
  final String helper;
  final String value;
  final Color accent;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF2C3E50),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onCopy,
                style: FilledButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.1),
                  foregroundColor: accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text(
                  tr('settings.account.actions.copy'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            helper,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineHelpCard extends StatelessWidget {
  const _InlineHelpCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF2C3E50)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF2C3E50),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogBullet extends StatelessWidget {
  const _DialogBullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _HesapAyarlariSayfasiState._accentColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanInfoRow extends StatelessWidget {
  const _PlanInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightMetricCard extends StatelessWidget {
  const _InsightMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.width,
  });

  final String label;
  final String value;
  final IconData icon;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF2C3E50), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureAvailabilityCard extends StatelessWidget {
  const _FeatureAvailabilityCard({
    this.width,
    required this.title,
    required this.enabled,
  });

  final double? width;
  final String title;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color accent = enabled
        ? const Color(0xFF16A34A)
        : const Color(0xFF9CA3AF);

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled
                ? accent.withValues(alpha: 0.18)
                : const Color(0xFFE5E7EB),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              enabled
                  ? accent.withValues(alpha: 0.05)
                  : const Color(0xFFF8FAFC),
              Colors.white,
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: enabled ? 0.12 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                enabled ? Icons.check_rounded : Icons.remove_rounded,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    enabled
                        ? tr('settings.account.state.available')
                        : tr('settings.account.state.locked'),
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
