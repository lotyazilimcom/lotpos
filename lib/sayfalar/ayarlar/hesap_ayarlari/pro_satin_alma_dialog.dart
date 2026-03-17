import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../servisler/lisans_servisi.dart';
import '../../../servisler/pro_satin_alma_servisi.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';

Future<bool?> showProSatinAlmaDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _ProSatinAlmaDialog(),
  );
}

enum _UpgradeStep { plan, form, checkout }

enum _CheckoutState { idle, waiting, paymentReceived, completed }

class _ProSatinAlmaDialog extends StatefulWidget {
  const _ProSatinAlmaDialog();

  @override
  State<_ProSatinAlmaDialog> createState() => _ProSatinAlmaDialogState();
}

class _ProSatinAlmaDialogState extends State<_ProSatinAlmaDialog> {
  static const Color _textPrimary = Color(0xFF2C3E50);
  static const Color _textSecondary = Color(0xFF6B7B8D);
  static const Color _textMuted = Color(0xFF95A5A6);
  static const Color _border = Color(0xFFE0E4E8);
  static const Color _surface = Color(0xFFF8F9FA);
  static const Color _panel = Color(0xFFFDFDFD);
  static const Color _accentSoft = Color(0xFFFFF3E0);
  static const Color _accentStrong = Color(0xFFF39C12);
  static const Color _success = Color(0xFF27AE60);
  static const Color _error = Color(0xFFE74C3C);
  static const Color _warningBg = Color(0xFFFFFBEB);
  static const Color _warningBorder = Color(0xFFFCD34D);
  static const Color _warningText = Color(0xFF92400E);
  static const Color _cta = Color(0xFF2C3E50);

  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxOfficeController = TextEditingController();
  final _taxIdController = TextEditingController();
  final PageController _mobilePlanController = PageController(
    viewportFraction: 0.92,
  );

  _UpgradeStep _step = _UpgradeStep.plan;
  ProOdemeProfili? _paymentProfile;
  ProSatinAlmaOnBilgi? _prefill;
  String? _selectedPlanCode;
  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;
  String? _infoMessage;
  Uri? _checkoutUri;
  Timer? _pollTimer;
  Timer? _profileRefreshTimer;
  Timer? _successCloseTimer;
  RealtimeChannel? _checkoutRealtimeChannel;
  String? _checkoutDisplayHost;
  String? _checkoutEventLabel;
  DateTime? _checkoutEventAt;
  _CheckoutState _checkoutState = _CheckoutState.idle;

  bool get _isShortDialog => MediaQuery.of(context).size.height < 860;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitialData());
    _startProfileRefresh();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _profileRefreshTimer?.cancel();
    _successCloseTimer?.cancel();
    unawaited(_stopCheckoutRealtime());
    _mobilePlanController.dispose();
    _companyNameController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _taxOfficeController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  String get _odemeLocale => CeviriServisi().mevcutDil == 'tr' ? 'tr' : 'en';

  ProOdemeProfili get _activeProfile =>
      _paymentProfile ??
      ProSatinAlmaServisi.varsayilanOdemeProfili(_odemeLocale);

  ProOdemeDialogMetinleri get _dialog => _activeProfile.dialog;

  List<ProPlanPaketi> get _plans => _activeProfile.planlar;

  ProPlanPaketi get _selectedPackage {
    final selectedCode =
        _selectedPlanCode ?? _activeProfile.varsayilanPlan.code;
    return _plans.firstWhere(
      (plan) => plan.code == selectedCode,
      orElse: () => _plans.first,
    );
  }

  String get _loadingText => _dialog.loadingText;
  String get _requiredText => _dialog.requiredFieldText;
  String get _invalidEmailText => _dialog.invalidEmailText;
  String get _checkoutOpenErrorText => _dialog.checkoutOpenErrorText;
  String get _copySuccessText => _dialog.copySuccessText;
  String get _checkoutStepLabel => _dialog.checkoutStepLabel;
  String get _checkoutOpenedText => _dialog.checkoutOpenedBannerText;
  String get _paymentReceivedText => _dialog.paymentReceivedBannerText;
  String get _licenseActivatedText => _dialog.licenseActivatedBannerText;
  String get _checkoutStatusCardTitle => switch (_checkoutState) {
    _CheckoutState.paymentReceived =>
      _dialog.checkoutTrackingPaymentReceivedTitle,
    _CheckoutState.completed => _dialog.checkoutTrackingCompletedTitle,
    _ => _dialog.checkoutTrackingWaitingTitle,
  };
  String get _checkoutStatusCardBody => switch (_checkoutState) {
    _CheckoutState.paymentReceived =>
      _dialog.checkoutTrackingPaymentReceivedBody,
    _CheckoutState.completed => _dialog.checkoutTrackingCompletedBody,
    _ => _dialog.checkoutTrackingWaitingBody,
  };
  String get _checkoutFooterText => switch (_checkoutState) {
    _CheckoutState.paymentReceived => _dialog.checkoutFooterPaymentReceivedText,
    _CheckoutState.completed => _dialog.checkoutFooterCompletedText,
    _ => _dialog.checkoutFooterWaitingText,
  };
  String get _checkoutReloadLabel => _dialog.checkoutReloadLabel;
  String get _checkoutBrowserHint => _dialog.checkoutBrowserHint;
  String get _checkoutOpenAgainHint => _dialog.checkoutOpenAgainHint;

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ProSatinAlmaServisi.hazirBilgileriGetir(),
        ProSatinAlmaServisi.odemeProfiliniGetir(locale: _odemeLocale),
      ]);

      final prefill = results[0] as ProSatinAlmaOnBilgi;
      final paymentProfile = results[1] as ProOdemeProfili;
      final selectedPlanCode = paymentProfile.varsayilanPlan.code;

      _prefill = prefill;
      _paymentProfile = paymentProfile;
      _selectedPlanCode = selectedPlanCode;
      _companyNameController.text = prefill.companyName;
      _fullNameController.text = prefill.fullName;
      _phoneController.text = prefill.phone;
      _emailController.text = prefill.email;
      _cityController.text = prefill.city;
      _addressController.text = prefill.address;
      _taxOfficeController.text = prefill.taxOffice;
      _taxIdController.text = prefill.taxId;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _startProfileRefresh() {
    _profileRefreshTimer?.cancel();
    _profileRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted ||
          _loading ||
          _submitting ||
          _step == _UpgradeStep.checkout) {
        return;
      }
      unawaited(_refreshPaymentProfile());
    });
  }

  Future<void> _refreshPaymentProfile() async {
    try {
      final paymentProfile = await ProSatinAlmaServisi.odemeProfiliniGetir(
        locale: _odemeLocale,
      );
      if (!mounted) return;

      final hasSelectedPlan = paymentProfile.planlar.any(
        (plan) => plan.code == _selectedPlanCode,
      );

      setState(() {
        _paymentProfile = paymentProfile;
        _selectedPlanCode = hasSelectedPlan
            ? _selectedPlanCode
            : paymentProfile.varsayilanPlan.code;
      });
    } catch (_) {}
  }

  Future<void> _copyCheckoutLink() async {
    final uri = _checkoutUri;
    if (uri == null) return;

    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_copySuccessText),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openCheckoutAgain() async {
    final uri = _checkoutUri;
    if (uri == null) return;

    final opened = await ProSatinAlmaServisi.odemeSayfasiniAc(uri);
    if (!mounted) return;

    setState(() {
      if (opened) {
        _errorMessage = null;
        if (_checkoutState != _CheckoutState.completed) {
          _infoMessage = _checkoutOpenedText;
        }
      } else {
        _errorMessage = _checkoutOpenErrorText;
      }
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (timer) async {
      try {
        await LisansServisi().dogrula();
        if (!mounted) return;
        if (!LisansServisi().isLiteMode) {
          timer.cancel();
          await _handleLicenseActivated();
          return;
        }
        await _refreshCheckoutStatus(silent: true);
      } catch (_) {}
    });
  }

  Future<void> _startCheckoutRealtime() async {
    final prefill = _prefill;
    if (prefill == null) return;

    await _stopCheckoutRealtime();

    final client = Supabase.instance.client;
    final channel = client.channel(
      'pro-checkout-${prefill.hardwareId.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'customers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'hardware_id',
            value: prefill.hardwareId,
          ),
          callback: (_) {
            unawaited(_refreshCheckoutStatus(silent: true));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'licenses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'hardware_id',
            value: prefill.hardwareId,
          ),
          callback: (_) {
            unawaited(_refreshCheckoutStatus(silent: true));
          },
        )
        .subscribe();

    _checkoutRealtimeChannel = channel;
  }

  Future<void> _stopCheckoutRealtime() async {
    final channel = _checkoutRealtimeChannel;
    _checkoutRealtimeChannel = null;
    if (channel == null) return;
    try {
      await Supabase.instance.client.removeChannel(channel);
    } catch (_) {}
  }

  Future<void> _refreshCheckoutStatus({bool silent = false}) async {
    final prefill = _prefill;
    if (prefill == null) return;

    try {
      final status = await ProSatinAlmaServisi.odemeDurumunuGetir(
        hardwareId: prefill.hardwareId,
        customerId: prefill.customerId,
      );
      await LisansServisi().dogrula();
      if (!mounted) return;

      if (!LisansServisi().isLiteMode) {
        await _handleLicenseActivated(status.lastEvent, status.lastEventAt);
        return;
      }

      final nextState = status.odemeAlindi
          ? _CheckoutState.paymentReceived
          : _CheckoutState.waiting;

      setState(() {
        _checkoutState = nextState;
        _checkoutEventLabel = _formatCheckoutEvent(status.lastEvent);
        _checkoutEventAt = status.lastEventAt?.toLocal();
        if (nextState == _CheckoutState.paymentReceived) {
          _infoMessage = _paymentReceivedText;
        }
      });
    } catch (error) {
      if (!silent && mounted) {
        setState(() {
          _errorMessage = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleLicenseActivated([
    String? lastEvent,
    DateTime? lastEventAt,
  ]) async {
    if (!mounted) return;
    if (_checkoutState == _CheckoutState.completed &&
        (_successCloseTimer?.isActive ?? false)) {
      return;
    }

    setState(() {
      _checkoutState = _CheckoutState.completed;
      _checkoutEventLabel =
          _formatCheckoutEvent(lastEvent) ?? _checkoutEventLabel;
      _checkoutEventAt = lastEventAt?.toLocal() ?? _checkoutEventAt;
      _errorMessage = null;
      _infoMessage = _licenseActivatedText;
    });

    _pollTimer?.cancel();
    await _stopCheckoutRealtime();
    await ProSatinAlmaServisi.odemeSayfasiniKapat();

    _successCloseTimer?.cancel();
    _successCloseTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  Future<void> _manualCheckoutRefresh() async {
    setState(() {
      _errorMessage = null;
    });
    await _refreshCheckoutStatus();
  }

  String? _formatCheckoutEvent(String? rawEvent) {
    final event = (rawEvent ?? '').trim();
    if (event.isEmpty) return null;

    return switch (event) {
      'order_created' => _dialog.eventLabelOrderCreated,
      'subscription_created' => _dialog.eventLabelSubscriptionCreated,
      'subscription_updated' => _dialog.eventLabelSubscriptionUpdated,
      'subscription_plan_changed' => _dialog.eventLabelSubscriptionPlanChanged,
      'subscription_payment_success' =>
        _dialog.eventLabelSubscriptionPaymentSuccess,
      'subscription_payment_recovered' =>
        _dialog.eventLabelSubscriptionPaymentRecovered,
      _ => event.replaceAll('_', ' '),
    };
  }

  String? _formatCheckoutEventTime(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  String? _validateRequired(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return _requiredText;
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final requiredMessage = _validateRequired(value);
    if (requiredMessage != null) return requiredMessage;

    final normalized = (value ?? '').trim();
    if (!normalized.contains('@') || !normalized.contains('.')) {
      return _invalidEmailText;
    }
    return null;
  }

  Future<void> _submit() async {
    final prefill = _prefill;
    if (prefill == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final result = await ProSatinAlmaServisi.checkoutOlustur(
        planCode: _selectedPackage.code,
        bilgiler: prefill,
        companyName: _companyNameController.text,
        fullName: _fullNameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        city: _cityController.text,
        address: _addressController.text,
        taxOffice: _taxOfficeController.text,
        taxId: _taxIdController.text,
        locale: _odemeLocale,
      );

      final launchFuture = ProSatinAlmaServisi.odemeSayfasiniAc(
        result.checkoutUri,
      );

      setState(() {
        _checkoutUri = result.checkoutUri;
        _checkoutDisplayHost = result.checkoutUri.host;
        _checkoutEventLabel = null;
        _checkoutEventAt = null;
        _checkoutState = _CheckoutState.waiting;
        _infoMessage = _checkoutOpenedText;
        _step = _UpgradeStep.checkout;
      });

      await _startCheckoutRealtime();
      _startPolling();
      unawaited(_refreshCheckoutStatus(silent: true));

      final opened = await launchFuture;
      if (!mounted) return;
      if (!opened) {
        setState(() {
          _errorMessage = _checkoutOpenErrorText;
        });
      }
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final screenHeight = media.size.height;
    final dialogWidth = math.min(screenWidth * 0.94, 1100.0);
    final dialogHeight = math.min(screenHeight * 0.92, 820.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 42,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _loading
                    ? _buildLoadingState()
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: switch (_step) {
                          _UpgradeStep.plan => _buildPlanStep(),
                          _UpgradeStep.form => _buildFormStep(),
                          _UpgradeStep.checkout => _buildCheckoutStep(),
                        },
                      ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final dialog = _activeProfile.dialog;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF2C3E50),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF39C12).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFF39C12),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dialog.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dialog.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(false),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStepChip(
                label: dialog.planStepLabel,
                active: _step == _UpgradeStep.plan,
                done:
                    _step == _UpgradeStep.form ||
                    _step == _UpgradeStep.checkout,
              ),
              const SizedBox(width: 10),
              Container(
                width: 24,
                height: 1,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 10),
              _buildStepChip(
                label: dialog.formStepLabel,
                active: _step == _UpgradeStep.form,
                done: _step == _UpgradeStep.checkout,
              ),
              const SizedBox(width: 10),
              Container(
                width: 24,
                height: 1,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 10),
              _buildStepChip(
                label: _checkoutStepLabel,
                active: _step == _UpgradeStep.checkout,
                done: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.8),
          ),
          const SizedBox(height: 12),
          Text(
            _loadingText,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanStep() {
    final dialog = _activeProfile.dialog;

    return Padding(
      key: const ValueKey('plan-step'),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            _buildBanner(
              icon: Icons.error_outline_rounded,
              color: _error,
              message: _errorMessage!,
            ),
            const SizedBox(height: 10),
          ],
          if (_infoMessage != null) ...[
            _buildBanner(
              icon: Icons.open_in_new_rounded,
              color: _success,
              message: _infoMessage!,
            ),
            const SizedBox(height: 10),
          ],
          _buildPlanInfoCard(dialog),
          const SizedBox(height: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useCarousel = constraints.maxWidth < 720;
                  return useCarousel
                      ? _buildMobilePlanCarousel(constraints.maxWidth)
                      : _buildDesktopPlanGrid(constraints.maxWidth);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormStep() {
    final compact = MediaQuery.of(context).size.width < 980;

    return Padding(
      key: const ValueKey('form-step'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            _buildBanner(
              icon: Icons.error_outline_rounded,
              color: _error,
              message: _errorMessage!,
            ),
            const SizedBox(height: 10),
          ],
          if (_infoMessage != null) ...[
            _buildBanner(
              icon: Icons.open_in_new_rounded,
              color: _success,
              message: _infoMessage!,
            ),
            const SizedBox(height: 10),
          ],
          _buildSelectedPlanSummary(),
          const SizedBox(height: 14),
          Expanded(
            child: compact
                ? Column(
                    children: [
                      Expanded(child: _buildFormCard()),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 230),
                        child: SingleChildScrollView(
                          child: _buildFormSideCard(compact: true),
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 7, child: _buildFormCard()),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 300,
                        child: SingleChildScrollView(
                          child: _buildFormSideCard(compact: false),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutStep() {
    final compact = MediaQuery.of(context).size.width < 980;

    return Padding(
      key: const ValueKey('checkout-step'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            _buildBanner(
              icon: Icons.error_outline_rounded,
              color: _error,
              message: _errorMessage!,
            ),
            const SizedBox(height: 10),
          ],
          if (_infoMessage != null) ...[
            _buildBanner(
              icon: Icons.lock_open_rounded,
              color: _success,
              message: _infoMessage!,
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: compact
                ? Column(
                    children: [
                      Expanded(child: _buildCheckoutStatusCard()),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: SingleChildScrollView(
                          child: _buildCheckoutSidePanel(compact: true),
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 7, child: _buildCheckoutStatusCard()),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 300,
                        child: SingleChildScrollView(
                          child: _buildCheckoutSidePanel(compact: false),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanInfoCard(ProOdemeDialogMetinleri dialog) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 760;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked) ...[
                Text(
                  dialog.planSectionTitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dialog.planSectionSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(
                      icon: Icons.badge_outlined,
                      text:
                          '${dialog.licenseIdLabel}: ${_prefill?.licenseId ?? '-'}',
                    ),
                    _buildInfoChip(
                      icon: Icons.memory_rounded,
                      text:
                          '${dialog.hardwareIdLabel}: ${_prefill?.hardwareId ?? '-'}',
                    ),
                  ],
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dialog.planSectionTitle,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dialog.planSectionSubtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: _textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildInfoChip(
                            icon: Icons.badge_outlined,
                            text:
                                '${dialog.licenseIdLabel}: ${_prefill?.licenseId ?? '-'}',
                          ),
                          _buildInfoChip(
                            icon: Icons.memory_rounded,
                            text:
                                '${dialog.hardwareIdLabel}: ${_prefill?.hardwareId ?? '-'}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: _accentStrong,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dialog.planInfoText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: _textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobilePlanCarousel(double width) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _mobilePlanController,
            itemCount: _plans.length,
            padEnds: false,
            itemBuilder: (context, index) {
              final plan = _plans[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index == _plans.length - 1 ? 0 : 12,
                ),
                child: _PlanCard(
                  plan: plan,
                  selected: plan.code == _selectedPackage.code,
                  onTap: () {
                    setState(() => _selectedPlanCode = plan.code);
                    _mobilePlanController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  chooseLabel: _activeProfile.dialog.chooseLabel,
                  selectedLabel: _activeProfile.dialog.selectedLabel,
                  compact: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopPlanGrid(double width) {
    final planCount = _plans.length;
    final useSingleRow = planCount <= 3 || width >= 1120;
    final rows = <List<ProPlanPaketi>>[];

    if (useSingleRow) {
      rows.add(_plans);
    } else {
      for (var i = 0; i < planCount; i += 2) {
        rows.add(_plans.sublist(i, (i + 2 > planCount) ? planCount : i + 2));
      }
    }

    final rowSpacing = _isShortDialog ? 10.0 : 12.0;

    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < rows[rowIndex].length; i++) ...[
                        Expanded(
                          child: _PlanCard(
                            plan: rows[rowIndex][i],
                            selected:
                                rows[rowIndex][i].code == _selectedPackage.code,
                            onTap: () => setState(
                              () => _selectedPlanCode = rows[rowIndex][i].code,
                            ),
                            chooseLabel: _activeProfile.dialog.chooseLabel,
                            selectedLabel: _activeProfile.dialog.selectedLabel,
                            compact: rows.length > 1 || _isShortDialog,
                          ),
                        ),
                        if (i != rows[rowIndex].length - 1)
                          const SizedBox(width: 12),
                      ],
                    ],
                  ),
                ),
                if (rowIndex != rows.length - 1) SizedBox(height: rowSpacing),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPlanSummary() {
    final dialog = _activeProfile.dialog;
    final selected = _selectedPackage;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 620;

          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _accentSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                            color: _accentStrong,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dialog.formSectionTitle,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${selected.title} · ${selected.price}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: _accentStrong,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _step = _UpgradeStep.plan),
                        style: TextButton.styleFrom(
                          foregroundColor: _textSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: _border),
                          ),
                        ),
                        child: Text(
                          dialog.changePlanLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _accentSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        size: 18,
                        color: _accentStrong,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dialog.formSectionTitle,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${selected.title} · ${selected.price}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _accentStrong,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _step = _UpgradeStep.plan),
                      style: TextButton.styleFrom(
                        foregroundColor: _textSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: _border),
                        ),
                      ),
                      child: Text(
                        dialog.changePlanLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomerNote(),
              const SizedBox(height: 14),
              _buildField(
                controller: _companyNameController,
                label: _activeProfile.formLabels.companyName,
              ),
              const SizedBox(height: 10),
              _buildResponsivePair(
                left: _buildField(
                  controller: _fullNameController,
                  label: _activeProfile.formLabels.fullName,
                  validator: _validateRequired,
                ),
                right: _buildField(
                  controller: _phoneController,
                  label: _activeProfile.formLabels.phone,
                  keyboardType: TextInputType.phone,
                  validator: _validateRequired,
                ),
              ),
              const SizedBox(height: 10),
              _buildResponsivePair(
                left: _buildField(
                  controller: _emailController,
                  label: _activeProfile.formLabels.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                right: _buildField(
                  controller: _cityController,
                  label: _activeProfile.formLabels.city,
                ),
              ),
              const SizedBox(height: 10),
              _buildField(
                controller: _addressController,
                label: _activeProfile.formLabels.address,
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              _buildResponsivePair(
                left: _buildField(
                  controller: _taxOfficeController,
                  label: _activeProfile.formLabels.taxOffice,
                  validator: _validateRequired,
                ),
                right: _buildField(
                  controller: _taxIdController,
                  label: _activeProfile.formLabels.taxId,
                  validator: _validateRequired,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerNote() {
    final prefill = _prefill;
    final note = prefill?.mevcutMusteri == true
        ? _activeProfile.dialog.existingCustomerNote
        : _activeProfile.dialog.newCustomerNote;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: _accentStrong,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: _textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSideCard({required bool compact}) {
    final selected = _selectedPackage;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selected.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                selected.price,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                selected.equivalent,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: _textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              for (final feature in selected.features) ...[
                _buildFeatureLine(feature.text),
                const SizedBox(height: 8),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _warningBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _warningBorder.withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  _activeProfile.dialog.invoiceNote,
                  style: const TextStyle(
                    color: _warningText,
                    fontSize: 11.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutSidePanel({required bool compact}) {
    return _buildFormSideCard(compact: compact);
  }

  Widget _buildCheckoutStatusCard() {
    final dialog = _dialog;
    final checkoutHost =
        _checkoutDisplayHost ?? dialog.checkoutTimelineOpenedSubtitle;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: _surface,
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _checkoutState == _CheckoutState.completed
                        ? _success.withValues(alpha: 0.12)
                        : _accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _checkoutState == _CheckoutState.completed
                        ? Icons.verified_rounded
                        : _checkoutState == _CheckoutState.paymentReceived
                        ? Icons.fact_check_rounded
                        : Icons.lock_rounded,
                    size: 17,
                    color: _checkoutState == _CheckoutState.completed
                        ? _success
                        : _accentStrong,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _checkoutStatusCardTitle,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        checkoutHost,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _checkoutStatusCardBody,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.55,
                            color: _textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_checkoutEventLabel != null ||
                            _formatCheckoutEventTime(_checkoutEventAt) !=
                                null) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (_checkoutEventLabel != null)
                                _buildInfoChip(
                                  icon: Icons.bolt_rounded,
                                  text: _checkoutEventLabel!,
                                ),
                              if (_formatCheckoutEventTime(_checkoutEventAt) !=
                                  null)
                                _buildInfoChip(
                                  icon: Icons.schedule_rounded,
                                  text: _formatCheckoutEventTime(
                                    _checkoutEventAt,
                                  )!,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCheckoutTimelineItem(
                    title: dialog.checkoutTimelineOpenedTitle,
                    subtitle: checkoutHost,
                    done: true,
                    active: _checkoutState == _CheckoutState.waiting,
                  ),
                  const SizedBox(height: 10),
                  _buildCheckoutTimelineItem(
                    title: dialog.checkoutTimelineWaitingTitle,
                    subtitle:
                        _checkoutState == _CheckoutState.paymentReceived ||
                            _checkoutState == _CheckoutState.completed
                        ? dialog.checkoutTimelineReceivedSubtitle
                        : dialog.checkoutTimelineWaitingSubtitle,
                    done:
                        _checkoutState == _CheckoutState.paymentReceived ||
                        _checkoutState == _CheckoutState.completed,
                    active: _checkoutState == _CheckoutState.waiting,
                  ),
                  const SizedBox(height: 10),
                  _buildCheckoutTimelineItem(
                    title: dialog.checkoutTimelineActivationTitle,
                    subtitle: _checkoutState == _CheckoutState.completed
                        ? dialog.checkoutTimelineCompletedSubtitle
                        : dialog.checkoutTimelineActivationSubtitle,
                    done: _checkoutState == _CheckoutState.completed,
                    active: _checkoutState == _CheckoutState.paymentReceived,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _warningBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _warningBorder.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: _warningText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _checkoutState == _CheckoutState.waiting
                                ? _checkoutOpenAgainHint
                                : _checkoutBrowserHint,
                            style: const TextStyle(
                              color: _warningText,
                              fontSize: 11.5,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCheckoutActionPanel(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutTimelineItem({
    required String title,
    required String subtitle,
    required bool done,
    required bool active,
  }) {
    final iconColor = done
        ? _success
        : active
        ? _accentStrong
        : _textMuted;
    final iconBackground = done
        ? _success.withValues(alpha: 0.12)
        : active
        ? _accentSoft
        : _surface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              done
                  ? Icons.check_rounded
                  : active
                  ? Icons.timelapse_rounded
                  : Icons.circle_outlined,
              size: 17,
              color: iconColor,
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutActionPanel() {
    final dialog = _dialog;
    final isWaiting = _checkoutState == _CheckoutState.waiting;
    final title = switch (_checkoutState) {
      _CheckoutState.paymentReceived => dialog.checkoutPaymentReceivedTitle,
      _CheckoutState.completed => dialog.checkoutCompletedTitle,
      _ => dialog.checkoutWaitingTitle,
    };
    final body = switch (_checkoutState) {
      _CheckoutState.paymentReceived => dialog.checkoutPaymentReceivedBody,
      _CheckoutState.completed => dialog.checkoutCompletedBody,
      _ => dialog.checkoutWaitingBody,
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _manualCheckoutRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: Text(_checkoutReloadLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textSecondary,
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _copyCheckoutLink,
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: Text(dialog.checkoutCopyLinkLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textSecondary,
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (isWaiting)
                FilledButton.icon(
                  onPressed: _submitting ? null : _openCheckoutAgain,
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text(dialog.checkoutOpenAgainLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: _cta,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResponsivePair({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(children: [left, const SizedBox(height: 10), right]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 10),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _textSecondary,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accentStrong, width: 1.2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _error, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final dialog = _activeProfile.dialog;
    final compact = MediaQuery.of(context).size.width < 900;
    final selected = _selectedPackage;
    final purchaseLabel = dialog.purchaseButtonTemplate.replaceAll(
      '{price}',
      selected.price,
    );
    final footerText = switch (_step) {
      _UpgradeStep.plan => '${selected.price} · ${selected.equivalent}',
      _UpgradeStep.form => dialog.footerNote,
      _UpgradeStep.checkout => _checkoutFooterText,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackActions = compact || constraints.maxWidth < 620;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!stackActions)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        footerText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: _textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildFooterActions(
                      dialog: dialog,
                      purchaseLabel: purchaseLabel,
                      wrap: false,
                    ),
                  ],
                )
              else ...[
                if (_step != _UpgradeStep.plan)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      footerText,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: _textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: _buildFooterActions(
                    dialog: dialog,
                    purchaseLabel: purchaseLabel,
                    wrap: true,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildFooterActions({
    required ProOdemeDialogMetinleri dialog,
    required String purchaseLabel,
    required bool wrap,
  }) {
    final checkoutWaiting = _checkoutState == _CheckoutState.waiting;
    final secondaryButton = TextButton(
      onPressed: _submitting
          ? null
          : _step == _UpgradeStep.checkout
          ? checkoutWaiting
                ? () => setState(() => _step = _UpgradeStep.form)
                : () => Navigator.of(context).pop(false)
          : _step == _UpgradeStep.form
          ? () => setState(() => _step = _UpgradeStep.plan)
          : () => Navigator.of(context).pop(false),
      style: TextButton.styleFrom(
        foregroundColor: _textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _border),
        ),
      ),
      child: Text(
        _step == _UpgradeStep.plan
            ? dialog.cancelLabel
            : _step == _UpgradeStep.checkout && !checkoutWaiting
            ? dialog.cancelLabel
            : dialog.backLabel,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );

    final primaryButton = FilledButton(
      onPressed: _submitting || _loading
          ? null
          : _step == _UpgradeStep.checkout
          ? checkoutWaiting
                ? _openCheckoutAgain
                : _manualCheckoutRefresh
          : _step == _UpgradeStep.form
          ? _submit
          : () => setState(() => _step = _UpgradeStep.form),
      style: FilledButton.styleFrom(
        backgroundColor: _cta,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _submitting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          : Text(
              _step == _UpgradeStep.plan
                  ? dialog.continueLabel
                  : _step == _UpgradeStep.form
                  ? purchaseLabel
                  : checkoutWaiting
                  ? dialog.checkoutOpenAgainLabel
                  : _checkoutReloadLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
    );

    if (wrap) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [secondaryButton, primaryButton],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [secondaryButton, const SizedBox(width: 8), primaryButton],
    );
  }

  Widget _buildBanner({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepChip({
    required String label,
    required bool active,
    required bool done,
  }) {
    final bg = active
        ? Colors.white.withValues(alpha: 0.15)
        : done
        ? _success.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.06);
    final borderColor = active
        ? const Color(0xFFF39C12).withValues(alpha: 0.5)
        : done
        ? _success.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.12);
    final textColor = active
        ? const Color(0xFFF39C12)
        : done
        ? _success
        : Colors.white.withValues(alpha: 0.55);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                Icons.check_circle_rounded,
                size: 14,
                color: _success,
              ),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _textSecondary),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureLine(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle_rounded, size: 15, color: _success),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: _textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
    required this.chooseLabel,
    required this.selectedLabel,
    this.compact = false,
  });

  final ProPlanPaketi plan;
  final bool selected;
  final VoidCallback onTap;
  final String chooseLabel;
  final String selectedLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool isHighlighted = plan.highlighted;
    const Color textPrimary = Color(0xFF2C3E50);
    const Color textMuted = Color(0xFF95A5A6);
    const Color accent = Color(0xFFF39C12);
    const Color support = Color(0xFF6B7B8D);

    final Color borderColor = selected
        ? const Color(0xFF2C3E50)
        : isHighlighted
        ? accent
        : const Color(0xFFE8ECEF);
    final double borderW = selected
        ? 2.0
        : isHighlighted
        ? 1.5
        : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: borderW),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: selected ? 0.08 : 0.04),
                blurRadius: selected ? 16 : 10,
                offset: Offset(0, selected ? 6 : 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Badge
              if (plan.badge.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(vertical: compact ? 4 : 5),
                  decoration: BoxDecoration(
                    color: isHighlighted ? accent : const Color(0xFFF1F3F5),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(13),
                      topRight: Radius.circular(13),
                    ),
                  ),
                  child: Text(
                    plan.badge.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 9 : 10,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w800,
                      color: isHighlighted ? Colors.white : support,
                    ),
                  ),
                ),

              // Card body
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 16,
                    plan.badge.isNotEmpty
                        ? (compact ? 8 : 10)
                        : (compact ? 12 : 14),
                    compact ? 12 : 16,
                    compact ? 6 : 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + check
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 13 : 15,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          if (selected)
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2C3E50),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: compact ? 6 : 10),
                      // Price
                      Text(
                        plan.price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 17 : 22,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Equivalent
                      Text(
                        plan.equivalent,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 10 : 11,
                          color: textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Note
                      if (plan.note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          plan.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 10 : 11,
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      SizedBox(height: compact ? 8 : 12),
                      // Select button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: selected
                                ? const Color(0xFF2C3E50)
                                : Colors.transparent,
                            foregroundColor: selected
                                ? Colors.white
                                : textPrimary,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(
                              vertical: compact ? 8 : 10,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFF2C3E50)
                                  : const Color(0xFFD5D9DD),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            selected ? selectedLabel : chooseLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: compact ? 11 : 11.5,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 6 : 10),
                      // Divider
                      Divider(height: 1, color: const Color(0xFFE8ECEF)),
                      SizedBox(height: compact ? 6 : 8),
                      // Features
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var i = 0;
                                i < plan.features.length;
                                i++
                              ) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        size: compact ? 13 : 14,
                                        color: const Color(0xFF27AE60),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        plan.features[i].text,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: compact ? 10 : 11,
                                          height: 1.3,
                                          color: support,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (i < plan.features.length - 1)
                                  SizedBox(height: compact ? 4 : 6),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
