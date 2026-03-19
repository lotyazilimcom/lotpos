import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../servisler/lisans_servisi.dart';
import '../../../servisler/lospay_kredi_servisi.dart';
import '../../../servisler/pro_satin_alma_servisi.dart'
    show ProSatinAlmaOnBilgi;
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';

Future<bool?> showLosPayKrediYukleDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _LosPayKrediYukleDialog(),
  );
}

enum _CreditStep { amount, form, checkout }

enum _CheckoutState { idle, waiting, paymentReceived, completed }

class _LosPayKrediYukleDialog extends StatefulWidget {
  const _LosPayKrediYukleDialog();

  @override
  State<_LosPayKrediYukleDialog> createState() =>
      _LosPayKrediYukleDialogState();
}

class _LosPayKrediYukleDialogState extends State<_LosPayKrediYukleDialog> {
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
  final _creditController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxOfficeController = TextEditingController();
  final _taxIdController = TextEditingController();

  _CreditStep _step = _CreditStep.amount;
  LosPayKrediProfili? _paymentProfile;
  ProSatinAlmaOnBilgi? _prefill;
  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;
  String? _infoMessage;
  Uri? _checkoutUri;
  String? _requestKey;
  String? _checkoutEventLabel;
  DateTime? _checkoutEventAt;
  double _currentBalance = 0;
  Timer? _pollTimer;
  Timer? _profileRefreshTimer;
  Timer? _successCloseTimer;
  RealtimeChannel? _checkoutRealtimeChannel;
  _CheckoutState _checkoutState = _CheckoutState.idle;

  String get _odemeLocale => CeviriServisi().mevcutDil == 'tr' ? 'tr' : 'en';

  LosPayKrediProfili get _activeProfile =>
      _paymentProfile ??
      LosPayKrediServisi.varsayilanOdemeProfili(_odemeLocale);

  LosPayKrediDialogMetinleri get _dialog => _activeProfile.dialog;

  int get _creditAmount => int.tryParse(_creditController.text.trim()) ?? 0;

  double get _totalAmount =>
      (_creditAmount * _activeProfile.credit.pricePerCredit).toDouble();

  String get _currencyCode => _activeProfile.currencyCode;

  String get _loadingText => _dialog.loadingText;
  String get _requiredText => _dialog.requiredFieldText;
  String get _invalidEmailText => _dialog.invalidEmailText;
  String get _checkoutOpenErrorText => _dialog.checkoutOpenErrorText;
  String get _copySuccessText => _dialog.copySuccessText;
  String get _checkoutOpenedText => _dialog.checkoutOpenedBannerText;
  String get _paymentReceivedText => _dialog.paymentReceivedBannerText;
  String get _creditLoadedText => _dialog.creditLoadedBannerText;
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
    _creditController.dispose();
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

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        LosPayKrediServisi.hazirBilgileriGetir(),
        LosPayKrediServisi.odemeProfiliniGetir(locale: _odemeLocale),
      ]);

      final prefill = results[0] as ProSatinAlmaOnBilgi;
      final profile = results[1] as LosPayKrediProfili;

      _prefill = prefill;
      _paymentProfile = profile;
      _currentBalance = LisansServisi().losPayBalance;
      _creditController.text = profile.credit.defaultCredits.toString();
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
          _step == _CreditStep.checkout) {
        return;
      }
      unawaited(_refreshPaymentProfile());
    });
  }

  Future<void> _refreshPaymentProfile() async {
    try {
      final profile = await LosPayKrediServisi.odemeProfiliniGetir(
        locale: _odemeLocale,
      );
      if (!mounted) return;
      setState(() {
        _paymentProfile = profile;
        if (_creditAmount <= 0) {
          _creditController.text = profile.credit.defaultCredits.toString();
        }
      });
    } catch (_) {}
  }

  String _formatPrice(double value) {
    final hasFraction = (value - value.truncateToDouble()).abs() > 0.0001;
    final digits = hasFraction ? 2 : 0;
    return value.toStringAsFixed(digits);
  }

  String _replaceTemplate(
    String template, {
    required int creditAmount,
    required double totalAmount,
  }) {
    return template
        .replaceAll('{min}', _activeProfile.credit.minCredits.toString())
        .replaceAll(
          '{amount}',
          '${_formatPrice(_activeProfile.credit.minimumChargeAmount)} $_currencyCode',
        )
        .replaceAll('{price}', '${_formatPrice(totalAmount)} $_currencyCode')
        .replaceAll('{step}', _activeProfile.credit.stepCredits.toString())
        .replaceAll('{credit}', creditAmount.toString());
  }

  String? _validateRequired(String? value) {
    if ((value ?? '').trim().isEmpty) return _requiredText;
    return null;
  }

  String? _validateEmail(String? value) {
    if ((value ?? '').trim().isEmpty) return _requiredText;
    final email = value!.trim();
    if (!email.contains('@') || !email.contains('.')) return _invalidEmailText;
    return null;
  }

  String? _validateCreditAmount(String? value) {
    final amount = int.tryParse((value ?? '').trim()) ?? 0;
    if (amount <= 0) return _dialog.creditAmountRequiredText;
    if (amount < _activeProfile.credit.minCredits) {
      return _replaceTemplate(
        _dialog.creditAmountMinText,
        creditAmount: amount,
        totalAmount: _totalAmount,
      );
    }
    if (amount > _activeProfile.credit.maxCredits) {
      return _dialog.creditAmountMaxText.replaceAll(
        '{max}',
        _activeProfile.credit.maxCredits.toString(),
      );
    }
    if (amount % _activeProfile.credit.stepCredits != 0) {
      return _replaceTemplate(
        _dialog.creditAmountStepText,
        creditAmount: amount,
        totalAmount: amount * _activeProfile.credit.pricePerCredit,
      );
    }
    if (_totalAmount < _activeProfile.credit.minimumChargeAmount) {
      return _replaceTemplate(
        _dialog.minimumChargeNote,
        creditAmount: amount,
        totalAmount: _totalAmount,
      );
    }
    return null;
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

    final opened = await LosPayKrediServisi.odemeSayfasiniAc(uri);
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
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        await _refreshCheckoutStatus(silent: true);
      } catch (_) {}
    });
  }

  Future<void> _startCheckoutRealtime() async {
    final prefill = _prefill;
    final requestKey = _requestKey;
    if (prefill == null || requestKey == null || requestKey.isEmpty) return;

    await _stopCheckoutRealtime();

    final client = Supabase.instance.client;
    final channel = client.channel(
      'lospay-credit-${prefill.hardwareId.toLowerCase()}-$requestKey',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lospay_credit_loads',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'request_key',
            value: requestKey,
          ),
          callback: (_) {
            unawaited(_refreshCheckoutStatus(silent: true));
          },
        )
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
          table: 'program_deneme',
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
    final requestKey = _requestKey;
    if (prefill == null || requestKey == null || requestKey.isEmpty) return;

    try {
      final status = await LosPayKrediServisi.yuklemeDurumunuGetir(
        requestKey: requestKey,
        hardwareId: prefill.hardwareId,
        customerId: prefill.customerId,
      );
      await LisansServisi().dogrula();
      if (!mounted) return;

      if (status.krediYuklendi) {
        await _handleCreditsLoaded(status);
        return;
      }

      final nextState = status.odemeAlindi
          ? _CheckoutState.paymentReceived
          : _CheckoutState.waiting;

      setState(() {
        _checkoutState = nextState;
        _currentBalance = status.currentBalance;
        _checkoutEventLabel = _formatCheckoutEvent(
          status.status,
          status.orderId,
        );
        _checkoutEventAt = (status.completedAt ?? status.updatedAt)?.toLocal();
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

  Future<void> _handleCreditsLoaded(LosPayKrediDurumu status) async {
    if (!mounted) return;
    if (_checkoutState == _CheckoutState.completed &&
        (_successCloseTimer?.isActive ?? false)) {
      return;
    }

    setState(() {
      _checkoutState = _CheckoutState.completed;
      _checkoutEventLabel = _formatCheckoutEvent(status.status, status.orderId);
      _checkoutEventAt = (status.completedAt ?? status.updatedAt)?.toLocal();
      _currentBalance = status.currentBalance;
      _errorMessage = null;
      _infoMessage = _creditLoadedText;
    });

    _pollTimer?.cancel();
    await _stopCheckoutRealtime();
    await LisansServisi().dogrula();
    await LisansServisi().senkronizeLosPayBakiyesiBestEffort(force: true);
    await LosPayKrediServisi.odemeSayfasiniKapat();

    _successCloseTimer?.cancel();
    _successCloseTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  Future<void> _manualCheckoutRefresh() async {
    setState(() => _errorMessage = null);
    await _refreshCheckoutStatus();
  }

  String? _formatCheckoutEvent(String? status, String? orderId) {
    final normalizedStatus = (status ?? '').trim().toLowerCase();
    if (normalizedStatus.isEmpty && (orderId ?? '').trim().isEmpty) return null;
    return switch (normalizedStatus) {
      'completed' => _dialog.eventLabelOrderCreated,
      'pending' => _dialog.checkoutTimelineWaitingTitle,
      'failed' => _dialog.eventLabelFailed,
      'cancelled' => _dialog.eventLabelCancelled,
      'refunded' => _dialog.eventLabelRefunded,
      _ => _dialog.eventLabelOrderCreated,
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

  Future<void> _submit() async {
    final prefill = _prefill;
    if (prefill == null) return;

    final creditError = _validateCreditAmount(_creditController.text);
    if (creditError != null) {
      setState(() {
        _errorMessage = creditError;
      });
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final checkout = await LosPayKrediServisi.checkoutOlustur(
        creditAmount: _creditAmount,
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

      final opened = await LosPayKrediServisi.odemeSayfasiniAc(
        checkout.checkoutUri,
      );
      if (!mounted) return;

      setState(() {
        _step = _CreditStep.checkout;
        _checkoutUri = checkout.checkoutUri;
        _requestKey = checkout.requestKey;
        _checkoutEventLabel = null;
        _checkoutEventAt = null;
        _checkoutState = _CheckoutState.waiting;
        _submitting = false;
        _errorMessage = opened ? null : _checkoutOpenErrorText;
        _infoMessage = opened ? _checkoutOpenedText : null;
      });

      await _startCheckoutRealtime();
      _startPolling();
      await _refreshCheckoutStatus(silent: true);
    } on LosPayKrediHatasi catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = error.mesaj;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 900;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 24,
        vertical: compact ? 12 : 18,
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 1120,
          maxHeight: MediaQuery.of(context).size.height - (compact ? 24 : 36),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: _loading ? _buildLoading() : _buildContent(compact),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            _loadingText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool compact) {
    final dialog = _dialog;
    final banner = _buildStatusBanner();
    final showInlineInfoBanner =
        _infoMessage != null &&
        !(_step == _CreditStep.checkout && banner != null);

    return Column(
      children: [
        _buildHeader(dialog),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (banner != null) ...[banner, const SizedBox(height: 12)],
                if (_errorMessage != null) ...[
                  _buildBanner(
                    icon: Icons.error_outline_rounded,
                    color: _error,
                    message: _errorMessage!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (showInlineInfoBanner) ...[
                  _buildBanner(
                    icon: Icons.check_circle_outline_rounded,
                    color: _success,
                    message: _infoMessage!,
                  ),
                  const SizedBox(height: 12),
                ],
                _buildBody(compact),
              ],
            ),
          ),
        ),
        _buildFooter(compact),
      ],
    );
  }

  Widget _buildHeader(LosPayKrediDialogMetinleri dialog) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      decoration: const BoxDecoration(
        color: _cta,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _accentStrong.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: _accentStrong,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dialog.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildStepChip(
                label: dialog.creditStepLabel,
                active: _step == _CreditStep.amount,
                done: _step.index > _CreditStep.amount.index,
              ),
              _buildStepChip(
                label: dialog.formStepLabel,
                active: _step == _CreditStep.form,
                done: _step.index > _CreditStep.form.index,
              ),
              _buildStepChip(
                label: dialog.checkoutStepLabel,
                active: _step == _CreditStep.checkout,
                done: _checkoutState == _CheckoutState.completed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildStatusBanner() {
    if (_step != _CreditStep.checkout) return null;

    final message = switch (_checkoutState) {
      _CheckoutState.paymentReceived => _paymentReceivedText,
      _CheckoutState.completed => _creditLoadedText,
      _ => _checkoutOpenedText,
    };
    final color = switch (_checkoutState) {
      _CheckoutState.completed => _success,
      _CheckoutState.paymentReceived => _accentStrong,
      _ => _success,
    };

    return _buildBanner(
      icon: _checkoutState == _CheckoutState.completed
          ? Icons.verified_rounded
          : Icons.open_in_new_rounded,
      color: color,
      message: message,
    );
  }

  Widget _buildBody(bool compact) {
    return switch (_step) {
      _CreditStep.amount => _buildAmountStep(compact),
      _CreditStep.form => _buildFormStep(compact),
      _CreditStep.checkout => _buildCheckoutStep(compact),
    };
  }

  Widget _buildAmountStep(bool compact) {
    final formCard = _buildAmountCard();
    final sideCard = _buildSummaryCard(compact: compact);

    if (compact) {
      return Column(children: [formCard, const SizedBox(height: 12), sideCard]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: formCard),
        const SizedBox(width: 12),
        Expanded(flex: 4, child: sideCard),
      ],
    );
  }

  Widget _buildFormStep(bool compact) {
    final summaryCard = _buildSelectedAmountSummary();
    final formCard = _buildFormCard();
    final sideCard = _buildSummaryCard(compact: compact);

    return Column(
      children: [
        summaryCard,
        const SizedBox(height: 12),
        if (compact) ...[
          formCard,
          const SizedBox(height: 12),
          sideCard,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: formCard),
              const SizedBox(width: 12),
              Expanded(flex: 4, child: sideCard),
            ],
          ),
      ],
    );
  }

  Widget _buildCheckoutStep(bool compact) {
    final statusCard = _buildCheckoutStatusCard();
    final sideCard = _buildSummaryCard(compact: compact);

    if (compact) {
      return Column(
        children: [statusCard, const SizedBox(height: 12), sideCard],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: statusCard),
        const SizedBox(width: 12),
        Expanded(flex: 4, child: sideCard),
      ],
    );
  }

  Widget _buildAmountCard() {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dialog.creditSectionTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _dialog.creditSectionSubtitle,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
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
                    _dialog.creditInfoText,
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
          ),
          const SizedBox(height: 14),
          Text(
            _dialog.creditAmountLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _creditController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
            decoration: InputDecoration(
              hintText: _dialog.creditAmountPlaceholder,
              prefixIcon: const Icon(
                Icons.account_balance_wallet_outlined,
                color: _accentStrong,
              ),
              suffixIcon: Container(
                width: 84,
                alignment: Alignment.center,
                child: Text(
                  _dialog.creditUnitLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _accentStrong,
                  ),
                ),
              ),
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _accentStrong, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _dialog.creditAmountHelp,
            style: const TextStyle(
              fontSize: 11,
              height: 1.45,
              color: _textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 560;
              final items = [
                _MetricCard(
                  label: _dialog.pricePerCreditLabel,
                  value:
                      '${_formatPrice(_activeProfile.credit.pricePerCredit)} $_currencyCode',
                  accent: _accentStrong,
                ),
                _MetricCard(
                  label: _dialog.totalPriceLabel,
                  value: '${_formatPrice(_totalAmount)} $_currencyCode',
                  accent: _cta,
                ),
              ];

              if (stacked) {
                return Column(
                  children: [items[0], const SizedBox(height: 10), items[1]],
                );
              }

              return Row(
                children: [
                  Expanded(child: items[0]),
                  const SizedBox(width: 10),
                  Expanded(child: items[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _buildRuleNote(
            message: _replaceTemplate(
              _dialog.minimumCreditsNote,
              creditAmount: _creditAmount,
              totalAmount: _totalAmount,
            ),
          ),
          const SizedBox(height: 8),
          _buildRuleNote(
            message: _replaceTemplate(
              _dialog.minimumChargeNote,
              creditAmount: _creditAmount,
              totalAmount: _totalAmount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleNote({required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _warningBorder.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: _warningText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: _warningText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedAmountSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
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
                  _dialog.formSectionTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$_creditAmount ${_dialog.creditUnitLabel} · ${_formatPrice(_totalAmount)} $_currencyCode',
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
                : () => setState(() => _step = _CreditStep.amount),
            style: TextButton.styleFrom(
              foregroundColor: _textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: _border),
              ),
            ),
            child: Text(
              _dialog.changeCreditsLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    final prefill = _prefill;
    final note = prefill?.mevcutMusteri == true
        ? _dialog.existingCustomerNote
        : _dialog.newCustomerNote;

    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
            ),
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
    );
  }

  Widget _buildSummaryCard({required bool compact}) {
    return Container(
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
            _dialog.summaryTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _dialog.summaryBody,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _buildSummaryRow(
            label: _dialog.summaryCreditsLabel,
            value: '$_creditAmount ${_dialog.creditUnitLabel}',
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            label: _dialog.summaryUnitPriceLabel,
            value:
                '${_formatPrice(_activeProfile.credit.pricePerCredit)} $_currencyCode',
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            label: _dialog.summaryMinimumCreditsLabel,
            value:
                '${_activeProfile.credit.minCredits} ${_dialog.creditUnitLabel}',
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            label: _dialog.summaryMinimumChargeLabel,
            value:
                '${_formatPrice(_activeProfile.credit.minimumChargeAmount)} $_currencyCode',
          ),
          const SizedBox(height: 12),
          for (final line in [
            _replaceTemplate(
              _dialog.minimumCreditsNote,
              creditAmount: _creditAmount,
              totalAmount: _totalAmount,
            ),
            _replaceTemplate(
              _dialog.minimumChargeNote,
              creditAmount: _creditAmount,
              totalAmount: _totalAmount,
            ),
          ]) ...[_buildFeatureLine(line), const SizedBox(height: 8)],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _warningBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _warningBorder.withValues(alpha: 0.55)),
            ),
            child: Text(
              _dialog.invoiceNote,
              style: const TextStyle(
                color: _warningText,
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dialog.totalPriceLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatPrice(_totalAmount)} $_currencyCode',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_creditAmount ${_dialog.creditUnitLabel}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: _accentStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (_step == _CreditStep.checkout) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dialog.currentBalanceLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatPrice(_currentBalance)} ${_dialog.creditUnitLabel}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow({required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: _textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11.5,
            color: _textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutStatusCard() {
    final checkoutSubtitle = _dialog.checkoutTimelineOpenedSubtitle;

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
                        checkoutSubtitle,
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
          Padding(
            padding: const EdgeInsets.all(16),
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
                  title: _dialog.checkoutTimelineOpenedTitle,
                  subtitle: checkoutSubtitle,
                  done: true,
                  active: _checkoutState == _CheckoutState.waiting,
                ),
                const SizedBox(height: 10),
                _buildCheckoutTimelineItem(
                  title: _dialog.checkoutTimelineWaitingTitle,
                  subtitle:
                      _checkoutState == _CheckoutState.paymentReceived ||
                          _checkoutState == _CheckoutState.completed
                      ? _dialog.checkoutTimelineReceivedSubtitle
                      : _dialog.checkoutTimelineWaitingSubtitle,
                  done:
                      _checkoutState == _CheckoutState.paymentReceived ||
                      _checkoutState == _CheckoutState.completed,
                  active: _checkoutState == _CheckoutState.waiting,
                ),
                const SizedBox(height: 10),
                _buildCheckoutTimelineItem(
                  title: _dialog.checkoutTimelineActivationTitle,
                  subtitle: _checkoutState == _CheckoutState.completed
                      ? _dialog.checkoutTimelineCompletedSubtitle
                      : _dialog.checkoutTimelineActivationSubtitle,
                  done: _checkoutState == _CheckoutState.completed,
                  active: _checkoutState == _CheckoutState.paymentReceived,
                ),
                const SizedBox(height: 16),
                _buildRuleNote(
                  message: _checkoutState == _CheckoutState.waiting
                      ? _dialog.checkoutOpenAgainHint
                      : _dialog.checkoutBrowserHint,
                ),
                const SizedBox(height: 16),
                _buildCheckoutActionPanel(),
              ],
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
    final title = switch (_checkoutState) {
      _CheckoutState.paymentReceived =>
        _dialog.checkoutTrackingPaymentReceivedTitle,
      _CheckoutState.completed => _dialog.checkoutTrackingCompletedTitle,
      _ => _dialog.checkoutTrackingWaitingTitle,
    };
    final body = switch (_checkoutState) {
      _CheckoutState.paymentReceived =>
        _dialog.checkoutTrackingPaymentReceivedBody,
      _CheckoutState.completed => _dialog.checkoutTrackingCompletedBody,
      _ => _dialog.checkoutTrackingWaitingBody,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
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
                label: Text(_dialog.checkoutReloadLabel),
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
                label: Text(_dialog.checkoutCopyLinkLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textSecondary,
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (_checkoutState == _CheckoutState.waiting)
                FilledButton.icon(
                  onPressed: _submitting ? null : _openCheckoutAgain,
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text(_dialog.checkoutOpenAgainLabel),
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

  Widget _buildFooter(bool compact) {
    final footerText = switch (_step) {
      _CreditStep.amount =>
        '${_formatPrice(_totalAmount)} $_currencyCode · $_creditAmount ${_dialog.creditUnitLabel}',
      _CreditStep.form => _dialog.footerNote,
      _CreditStep.checkout => _checkoutFooterText,
    };
    final purchaseLabel = _replaceTemplate(
      _dialog.purchaseButtonTemplate,
      creditAmount: _creditAmount,
      totalAmount: _totalAmount,
    );

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
                      purchaseLabel: purchaseLabel,
                      wrap: false,
                    ),
                  ],
                )
              else ...[
                if (_step != _CreditStep.amount)
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
    required String purchaseLabel,
    required bool wrap,
  }) {
    final checkoutWaiting = _checkoutState == _CheckoutState.waiting;
    final secondaryButton = TextButton(
      onPressed: _submitting
          ? null
          : _step == _CreditStep.checkout
          ? checkoutWaiting
                ? () => setState(() => _step = _CreditStep.form)
                : () => Navigator.of(context).pop(false)
          : _step == _CreditStep.form
          ? () => setState(() => _step = _CreditStep.amount)
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
        _step == _CreditStep.amount
            ? _dialog.cancelLabel
            : _step == _CreditStep.checkout && !checkoutWaiting
            ? _dialog.cancelLabel
            : _dialog.backLabel,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );

    final primaryButton = FilledButton(
      onPressed: _submitting || _loading
          ? null
          : _step == _CreditStep.checkout
          ? checkoutWaiting
                ? _openCheckoutAgain
                : _manualCheckoutRefresh
          : _step == _CreditStep.form
          ? _submit
          : () {
              final creditError = _validateCreditAmount(_creditController.text);
              if (creditError != null) {
                setState(() => _errorMessage = creditError);
                return;
              }
              setState(() {
                _errorMessage = null;
                _step = _CreditStep.form;
              });
            },
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
              _step == _CreditStep.amount
                  ? _dialog.continueLabel
                  : _step == _CreditStep.form
                  ? purchaseLabel
                  : checkoutWaiting
                  ? _dialog.checkoutOpenAgainLabel
                  : _dialog.checkoutReloadLabel,
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
        ? _accentStrong.withValues(alpha: 0.5)
        : done
        ? _success.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.12);
    final textColor = active
        ? _accentStrong
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
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _textSecondary,
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
          child: Icon(Icons.check_circle_rounded, size: 16, color: _success),
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

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _LosPayKrediYukleDialogState._surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _LosPayKrediYukleDialogState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: _LosPayKrediYukleDialogState._textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
