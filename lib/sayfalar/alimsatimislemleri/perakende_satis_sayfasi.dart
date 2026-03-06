import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../yardimcilar/app_route_observer.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../yardimcilar/responsive_yardimcisi.dart';
import '../../bilesenler/onay_dialog.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../../servisler/bankalar_veritabani_servisi.dart';
import '../../servisler/depolar_veritabani_servisi.dart';
import '../../servisler/kasalar_veritabani_servisi.dart';
import '../../servisler/kredi_kartlari_veritabani_servisi.dart';
import '../../servisler/perakende_satis_veritabani_servisleri.dart';
import '../../servisler/urunler_veritabani_servisi.dart';
import '../../servisler/uretimler_veritabani_servisi.dart';
import '../bankalar/modeller/banka_model.dart';
import '../kasalar/kasalar_sayfasi.dart';
import '../kasalar/modeller/kasa_model.dart';
import '../kredikartlari/modeller/kredi_karti_model.dart';
import '../ortak/print_preview_screen.dart';
import '../urunler_ve_depolar/depolar/modeller/depo_model.dart';
import '../../bilesenler/tek_tarih_secici_dialog.dart';
import '../../servisler/sayfa_senkronizasyon_servisi.dart';
import '../urunler_ve_depolar/urunler/modeller/urun_model.dart';

enum _RetailNumericKeypadTarget {
  barkod,
  miktar,
  aciklama,
  odeme,
}

class _PerakendeSepetItem {
  final String kodNo;
  final String barkodNo;
  final String adi;
  final double birimFiyati;
  final double iskontoOrani;
  final double miktar;
  final String olcu;
  final double toplamFiyat;
  final String paraBirimi;
  final int? depoId;
  final String? depoAdi;

  const _PerakendeSepetItem({
    required this.kodNo,
    required this.barkodNo,
    required this.adi,
    required this.birimFiyati,
    required this.iskontoOrani,
    required this.miktar,
    required this.olcu,
    required this.toplamFiyat,
    required this.paraBirimi,
    required this.depoId,
    required this.depoAdi,
  });

  _PerakendeSepetItem copyWith({
    double? miktar,
    double? iskontoOrani,
    double? birimFiyati,
    double? toplamFiyat,
    int? depoId,
    String? depoAdi,
  }) {
    return _PerakendeSepetItem(
      kodNo: kodNo,
      barkodNo: barkodNo,
      adi: adi,
      birimFiyati: birimFiyati ?? this.birimFiyati,
      iskontoOrani: iskontoOrani ?? this.iskontoOrani,
      miktar: miktar ?? this.miktar,
      olcu: olcu,
      toplamFiyat: toplamFiyat ?? this.toplamFiyat,
      paraBirimi: paraBirimi,
      depoId: depoId ?? this.depoId,
      depoAdi: depoAdi ?? this.depoAdi,
    );
  }
}

class _PerakendeUrunSearchDialog extends StatefulWidget {
  final String initialQuery;
  final ValueChanged<dynamic> onSelect;
  final bool includeProductions;

  const _PerakendeUrunSearchDialog({
    required this.onSelect,
    this.initialQuery = '',
    this.includeProductions = true,
  });

  @override
  State<_PerakendeUrunSearchDialog> createState() =>
      _PerakendeUrunSearchDialogState();
}

class _PerakendeUrunSearchDialogState
    extends State<_PerakendeUrunSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<dynamic> _items = [];
  bool _isLoading = false;
  Timer? _debounce;

  static const Color _primaryColor = Color(0xFF1E88E5);

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _searchProducts(widget.initialQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _searchProducts(query);
    });
  }

  Future<void> _searchProducts(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final futures = <Future<List<dynamic>>>[
        UrunlerVeritabaniServisi().urunleriGetir(
          aramaTerimi: query,
          sayfaBasinaKayit: 50,
          sortAscending: true,
          sortBy: 'ad',
          aktifMi: true,
        ),
        if (widget.includeProductions)
          UretimlerVeritabaniServisi().uretimleriGetir(
            aramaTerimi: query,
            sayfaBasinaKayit: 50,
            sortAscending: true,
            sortBy: 'ad',
            aktifMi: true,
          ),
      ];
      final results = await Future.wait(futures);

      if (!mounted) return;

      final combined = results.expand<dynamic>((e) => e).toList();
      // Sort combined by name
      combined.sort(
        (a, b) => ((a as dynamic).ad as String).compareTo(
          (b as dynamic).ad as String,
        ),
      );

      setState(() {
        _items = combined;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double dialogRadius = 14;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dialogRadius),
      ),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(dialogRadius),
        ),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('shipment.form.product.search_title'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('shipment.form.product.search_subtitle'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF606368),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('common.esc'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9AA0A6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: tr('common.close'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('common.search'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A4A4A),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF202124),
                  ),
                  decoration: InputDecoration(
                    hintText: tr('products.search_placeholder'),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: Color(0xFFBDC1C6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Color(0xFFE0E0E0),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr('products.no_products_found'),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF606368),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _items.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFEFEFEF),
                      ),
                      itemBuilder: (context, index) {
                        final p = _items[index];
                        return InkWell(
                          mouseCursor: WidgetStateMouseCursor.clickable,
                          onTap: () {
                            widget.onSelect(p);
                            Navigator.of(context).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 6,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    (p as dynamic).kod,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF202124),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    (p as dynamic).ad,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF202124),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    (p as dynamic).barkod,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF606368),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParcaliOdemeResult {
  final double nakit;
  final double krediKarti;
  final double havale;

  const _ParcaliOdemeResult({
    required this.nakit,
    required this.krediKarti,
    required this.havale,
  });
}

class _PerakendeParcaliOdemeDialog extends StatefulWidget {
  final GenelAyarlarModel genelAyarlar;
  final double total;
  final String Function(double) formatTutar;
  final String Function(double) formatParaBirimiGosterimi;

  const _PerakendeParcaliOdemeDialog({
    required this.genelAyarlar,
    required this.total,
    required this.formatTutar,
    required this.formatParaBirimiGosterimi,
  });

  @override
  State<_PerakendeParcaliOdemeDialog> createState() =>
      _PerakendeParcaliOdemeDialogState();
}

class _PerakendeParcaliOdemeDialogState
    extends State<_PerakendeParcaliOdemeDialog> {
  late final TextEditingController _nakitController;
  late final TextEditingController _kartController;
  late final TextEditingController _havaleController;

  late final FocusNode _nakitFocusNode;
  late final FocusNode _kartFocusNode;
  late final FocusNode _havaleFocusNode;

  late final List<TextInputFormatter> _amountFormatters;

  bool _updatingAuto = false;

  static const Color _primaryColor = Color(0xFFFF9800);
  static const Color _nakitColor = Color(0xFF4CAF50);
  static const Color _kartColor = Color(0xFF26A69A);
  static const Color _havaleColor = Color(0xFF1E88E5);
  static const Color _dangerColor = Color(0xFFEA4335);

  @override
  void initState() {
    super.initState();
    _nakitController =
        TextEditingController(text: widget.formatTutar(widget.total));
    _kartController = TextEditingController(text: widget.formatTutar(0));
    _havaleController = TextEditingController(text: widget.formatTutar(0));

    _nakitFocusNode = FocusNode();
    _kartFocusNode = FocusNode();
    _havaleFocusNode = FocusNode();

    _nakitFocusNode.addListener(() {
      if (!_nakitFocusNode.hasFocus) return;
      _selectAll(_nakitController);
    });
    _kartFocusNode.addListener(() {
      if (_kartFocusNode.hasFocus) {
        _selectAll(_kartController);
        return;
      }
      _formatAmountController(_kartController);
    });
    _havaleFocusNode.addListener(() {
      if (_havaleFocusNode.hasFocus) {
        _selectAll(_havaleController);
        return;
      }
      _formatAmountController(_havaleController);
    });

    _amountFormatters = [
      CurrencyInputFormatter(
        binlik: widget.genelAyarlar.binlikAyiraci,
        ondalik: widget.genelAyarlar.ondalikAyiraci,
        maxDecimalDigits: widget.genelAyarlar.fiyatOndalik,
      ),
      LengthLimitingTextInputFormatter(20),
    ];

    _nakitController.addListener(_onAmountsChanged);
    _kartController.addListener(_onAmountsChanged);
    _havaleController.addListener(_onAmountsChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recalculateAuto(force: true);
      _kartFocusNode.requestFocus();
      _selectAll(_kartController);
    });
  }

  @override
  void dispose() {
    _nakitController.removeListener(_onAmountsChanged);
    _kartController.removeListener(_onAmountsChanged);
    _havaleController.removeListener(_onAmountsChanged);
    _nakitController.dispose();
    _kartController.dispose();
    _havaleController.dispose();
    _nakitFocusNode.dispose();
    _kartFocusNode.dispose();
    _havaleFocusNode.dispose();
    super.dispose();
  }

  double _parseAmount(String text) {
    return FormatYardimcisi.parseDouble(
      text,
      binlik: widget.genelAyarlar.binlikAyiraci,
      ondalik: widget.genelAyarlar.ondalikAyiraci,
    );
  }

  int _factor() {
    var factor = 1;
    for (var i = 0; i < widget.genelAyarlar.fiyatOndalik; i++) {
      factor *= 10;
    }
    return factor;
  }

  int _minor(double value) {
    final factor = _factor();
    return (value * factor).round();
  }

  void _onAmountsChanged() {
    _recalculateAuto();
  }

  void _selectAll(TextEditingController controller) {
    final length = controller.text.length;
    if (length <= 0) return;
    controller.selection = TextSelection(baseOffset: 0, extentOffset: length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latestLength = controller.text.length;
      if (latestLength <= 0) return;
      controller.selection =
          TextSelection(baseOffset: 0, extentOffset: latestLength);
    });
  }

  void _formatAmountController(TextEditingController controller) {
    if (_updatingAuto) return;
    final parsed = _parseAmount(controller.text);
    final formatted = widget.formatTutar(parsed);
    _setControllerValue(controller, formatted);
  }

  void _setControllerValue(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  void _recalculateAuto({bool force = false}) {
    if (_updatingAuto) return;

    _updatingAuto = true;
    try {
      final total = widget.total;
      final kart = _parseAmount(_kartController.text);
      final havale = _parseAmount(_havaleController.text);

      var remaining = total - kart - havale;
      if (remaining < 0) remaining = 0;
      _setControllerValue(_nakitController, widget.formatTutar(remaining));
    } finally {
      _updatingAuto = false;
    }
  }

  bool _isComplete({
    required double nakit,
    required double krediKarti,
    required double havale,
  }) {
    if (nakit < 0 || krediKarti < 0 || havale < 0) return false;
    final paidMinor = _minor(nakit + krediKarti + havale);
    if (paidMinor <= 0) return false;
    return paidMinor == _minor(widget.total);
  }

  void _reset() {
    _setControllerValue(_kartController, widget.formatTutar(0));
    _setControllerValue(_havaleController, widget.formatTutar(0));
    _recalculateAuto(force: true);
    _kartFocusNode.requestFocus();
    _selectAll(_kartController);
  }

  void _submit() {
    final nakit = _parseAmount(_nakitController.text);
    final kart = _parseAmount(_kartController.text);
    final havale = _parseAmount(_havaleController.text);

    final paidMinor = _minor(nakit + kart + havale);
    final totalMinor = _minor(widget.total);

    if (nakit < 0 || kart < 0 || havale < 0 || paidMinor <= 0) {
      MesajYardimcisi.hataGoster(context, tr('retail.error.invalid_payment'));
      return;
    }

    if (paidMinor > totalMinor) {
      MesajYardimcisi.hataGoster(
        context,
        tr('retail.error.payment_exceeds_total'),
      );
      return;
    }

    if (!_isComplete(nakit: nakit, krediKarti: kart, havale: havale)) {
      MesajYardimcisi.hataGoster(
        context,
        tr('retail.error.insufficient_payment'),
      );
      return;
    }

    Navigator.of(context).pop(
      _ParcaliOdemeResult(nakit: nakit, krediKarti: kart, havale: havale),
    );
  }

  Widget _buildAmountField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required Color borderColor,
    bool readOnly = false,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: borderColor,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: textInputAction,
          inputFormatters: readOnly ? null : _amountFormatters,
          onSubmitted: onSubmitted,
          onTap: () => _selectAll(controller),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
          decoration: InputDecoration(
            hintText: widget.formatTutar(0),
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFFBDC1C6)),
            hintStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFFBDC1C6),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: borderColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const double dialogRadius = 14;
    final Size screenSize = MediaQuery.of(context).size;
    final bool isCompact = screenSize.width < 720;
    final bool isVeryCompact = screenSize.width < 560;
    final double horizontalInset = isVeryCompact ? 10 : (isCompact ? 16 : 32);
    final double verticalInset = isVeryCompact ? 12 : 24;
    final double maxDialogWidth = isCompact
        ? screenSize.width - (horizontalInset * 2)
        : 720;
    final double maxDialogHeight = screenSize.height * 0.92;
    final double contentPadding = isCompact ? 16 : 28;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).pop();
        },
        const SingleActivator(LogicalKeyboardKey.enter): _submit,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _submit,
      },
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Focus(
          autofocus: true,
          child: Dialog(
            backgroundColor: Colors.white,
            insetPadding: EdgeInsets.symmetric(
              horizontal: horizontalInset,
              vertical: verticalInset,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dialogRadius),
            ),
            child: Container(
              width: maxDialogWidth,
              constraints: BoxConstraints(maxHeight: maxDialogHeight),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(dialogRadius),
              ),
              padding: EdgeInsets.fromLTRB(
                contentPadding,
                isCompact ? 18 : 24,
                contentPadding,
                isCompact ? 16 : 22,
              ),
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _nakitController,
                  _kartController,
                  _havaleController,
                ]),
                builder: (context, child) {
                  final nakit = _parseAmount(_nakitController.text);
                  final kart = _parseAmount(_kartController.text);
                  final havale = _parseAmount(_havaleController.text);
                  final paidMinor = _minor(nakit + kart + havale);
                  final totalMinor = _minor(widget.total);
                  final remainingMinor = totalMinor - paidMinor;
                  final remaining = widget.total - (nakit + kart + havale);

                  final bool complete = _isComplete(
                    nakit: nakit,
                    krediKarti: kart,
                    havale: havale,
                  );

                  final Color remainingColor = remainingMinor == 0
                      ? _nakitColor
                      : remainingMinor > 0
                          ? _primaryColor
                          : _dangerColor;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('retail.partial_payment.dialog.title'),
                                  style: TextStyle(
                                    fontSize: isCompact ? 19 : 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF202124),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  tr('retail.partial_payment.dialog.subtitle'),
                                  style: TextStyle(
                                    fontSize: isCompact ? 13 : 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF606368),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isVeryCompact)
                                Text(
                                  tr('common.esc'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF9AA0A6),
                                  ),
                                ),
                              if (!isVeryCompact) const SizedBox(width: 8),
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F3F4),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => Navigator.of(context).pop(),
                                  tooltip: tr('common.close'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 14 : 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('retail.grand_total'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF606368),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.formatParaBirimiGosterimi(
                                      widget.total,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF202124),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('sale.complete.field.remaining_amount'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF606368),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.formatParaBirimiGosterimi(remaining),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: remainingColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final fields = Column(
                            children: [
                              _buildAmountField(
                                label: tr('retail.partial_payment.field.cash'),
                                controller: _nakitController,
                                focusNode: _nakitFocusNode,
                                icon: Icons.monetization_on,
                                borderColor: _nakitColor,
                                readOnly: true,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) =>
                                    _kartFocusNode.requestFocus(),
                              ),
                              const SizedBox(height: 18),
                              _buildAmountField(
                                label: tr(
                                  'retail.partial_payment.field.credit_card',
                                ),
                                controller: _kartController,
                                focusNode: _kartFocusNode,
                                icon: Icons.credit_card,
                                borderColor: _kartColor,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) {
                                  _formatAmountController(_kartController);
                                  _havaleFocusNode.requestFocus();
                                },
                              ),
                              const SizedBox(height: 18),
                              _buildAmountField(
                                label:
                                    tr('retail.partial_payment.field.transfer'),
                                controller: _havaleController,
                                focusNode: _havaleFocusNode,
                                icon: Icons.account_balance,
                                borderColor: _havaleColor,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  _formatAmountController(_havaleController);
                                  _submit();
                                },
                              ),
                            ],
                          );

                          return fields;
                        },
                      ),
                      SizedBox(height: isCompact ? 8 : 4),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final bool stackButtons = constraints.maxWidth < 420;

                          final resetButton = OutlinedButton.icon(
                            onPressed: _reset,
                            icon: const Icon(Icons.restart_alt, size: 18),
                            label: Text(
                              tr('retail.partial_payment.action.reset'),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF5F6368),
                              side: const BorderSide(color: Color(0xFFE0E0E0)),
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 16 : 18,
                                vertical: isCompact ? 12 : 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          );

                          final cancelButton = TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: _primaryColor,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tr('common.cancel'),
                                  style: TextStyle(
                                    fontSize: isCompact ? 13 : 14,
                                    fontWeight: FontWeight.w700,
                                    color: _primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if (!isVeryCompact)
                                  const Text(
                                    'ESC',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF9AA0A6),
                                    ),
                                  ),
                              ],
                            ),
                          );

                          final completeButton = ElevatedButton(
                            onPressed: complete ? _submit : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 24 : 32,
                                vertical: isCompact ? 14 : 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              tr('sale.complete.button.complete'),
                              style: TextStyle(
                                fontSize: isCompact ? 13 : 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );

                          if (stackButtons) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                resetButton,
                                const SizedBox(height: 10),
                                cancelButton,
                                const SizedBox(height: 8),
                                completeButton,
                              ],
                            );
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              resetButton,
                              const Spacer(),
                              cancelButton,
                              const SizedBox(width: 12),
                              completeButton,
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

typedef _FormatTutarFn = String Function(double, {int? decimalDigits});

class _IskontoResult {
  final double percent;
  final double amount;

  const _IskontoResult({
    required this.percent,
    required this.amount,
  });
}

class _PerakendeIskontoDialog extends StatefulWidget {
  final GenelAyarlarModel genelAyarlar;
  final double grossTotal;
  final double initialPercent;
  final _FormatTutarFn formatTutar;
  final String Function(double) formatParaBirimiGosterimi;

  const _PerakendeIskontoDialog({
    required this.genelAyarlar,
    required this.grossTotal,
    required this.formatTutar,
    required this.formatParaBirimiGosterimi,
    this.initialPercent = 0,
  });

  @override
  State<_PerakendeIskontoDialog> createState() => _PerakendeIskontoDialogState();
}

class _PerakendeIskontoDialogState extends State<_PerakendeIskontoDialog> {
  late final TextEditingController _percentController;
  late final TextEditingController _amountController;

  late final FocusNode _percentFocusNode;
  late final FocusNode _amountFocusNode;

  late final List<TextInputFormatter> _percentFormatters;
  late final List<TextInputFormatter> _amountFormatters;

  bool _updating = false;
  String _lastEdited = 'percent'; // percent | amount

  static const Color _primaryColor = Color(0xFF1E88E5);
  static const Color _dangerColor = Color(0xFFEA4335);

  @override
  void initState() {
    super.initState();

    _percentController = TextEditingController();
    _amountController = TextEditingController();
    _percentFocusNode = FocusNode();
    _amountFocusNode = FocusNode();

    _percentFormatters = [
      CurrencyInputFormatter(
        binlik: widget.genelAyarlar.binlikAyiraci,
        ondalik: widget.genelAyarlar.ondalikAyiraci,
        maxDecimalDigits: 2,
      ),
      LengthLimitingTextInputFormatter(8),
    ];

    _amountFormatters = [
      CurrencyInputFormatter(
        binlik: widget.genelAyarlar.binlikAyiraci,
        ondalik: widget.genelAyarlar.ondalikAyiraci,
        maxDecimalDigits: widget.genelAyarlar.fiyatOndalik,
      ),
      LengthLimitingTextInputFormatter(20),
    ];

    final initialPercent = widget.initialPercent.clamp(0, 100).toDouble();
    final initialAmount =
        widget.grossTotal <= 0 ? 0.0 : widget.grossTotal * initialPercent / 100;

    if (initialPercent > 0) {
      _percentController.text =
          widget.formatTutar(initialPercent, decimalDigits: 2);
    }
    if (initialAmount > 0) {
      _amountController.text = widget.formatTutar(initialAmount);
    }

    _percentController.addListener(_onPercentChanged);
    _amountController.addListener(_onAmountChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _percentFocusNode.requestFocus();
      _percentController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _percentController.text.length,
      );
    });
  }

  @override
  void dispose() {
    _percentController.removeListener(_onPercentChanged);
    _amountController.removeListener(_onAmountChanged);
    _percentController.dispose();
    _amountController.dispose();
    _percentFocusNode.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  double _parse(String text) {
    return FormatYardimcisi.parseDouble(
      text,
      binlik: widget.genelAyarlar.binlikAyiraci,
      ondalik: widget.genelAyarlar.ondalikAyiraci,
    );
  }

  void _setControllerValue(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  void _onPercentChanged() {
    if (_updating) return;
    _lastEdited = 'percent';

    final gross = widget.grossTotal;
    final rawPercent = _parse(_percentController.text);
    final percent = rawPercent.clamp(0, 100).toDouble();
    final amount = gross <= 0 ? 0.0 : gross * percent / 100;

    _updating = true;
    try {
      if (rawPercent != percent && gross > 0) {
        _setControllerValue(
          _percentController,
          percent <= 0
              ? ''
              : widget.formatTutar(percent, decimalDigits: 2),
        );
      }
      _setControllerValue(
        _amountController,
        amount <= 0 ? '' : widget.formatTutar(amount),
      );
    } finally {
      _updating = false;
    }
  }

  void _onAmountChanged() {
    if (_updating) return;
    _lastEdited = 'amount';

    final gross = widget.grossTotal;
    final rawAmount = _parse(_amountController.text);
    final amount = gross <= 0 ? 0.0 : rawAmount.clamp(0, gross).toDouble();
    final percent = gross <= 0 ? 0.0 : (amount / gross) * 100;

    _updating = true;
    try {
      if (rawAmount != amount && gross > 0) {
        _setControllerValue(
          _amountController,
          amount <= 0 ? '' : widget.formatTutar(amount),
        );
      }
      _setControllerValue(
        _percentController,
        percent <= 0 ? '' : widget.formatTutar(percent, decimalDigits: 2),
      );
    } finally {
      _updating = false;
    }
  }

  void _reset() {
    _updating = true;
    try {
      _setControllerValue(_percentController, '');
      _setControllerValue(_amountController, '');
      _lastEdited = 'percent';
    } finally {
      _updating = false;
    }

    _percentFocusNode.requestFocus();
  }

  void _submit() {
    final gross = widget.grossTotal;
    final percentFromField = _parse(_percentController.text).clamp(0, 100);
    final amountFromField =
        gross <= 0 ? 0.0 : _parse(_amountController.text).clamp(0, gross);

    final double percent;
    final double amount;
    if (_lastEdited == 'amount') {
      amount = amountFromField.toDouble();
      percent = gross <= 0 ? 0.0 : (amount / gross) * 100;
    } else {
      percent = percentFromField.toDouble();
      amount = gross <= 0 ? 0.0 : gross * percent / 100;
    }

    if (gross <= 0) {
      MesajYardimcisi.hataGoster(context, tr('sale.error.no_items'));
      return;
    }

    Navigator.of(context).pop(
      _IskontoResult(percent: percent, amount: amount),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required Color borderColor,
    required List<TextInputFormatter> formatters,
    String? suffixText,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: borderColor,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: textInputAction,
          inputFormatters: formatters,
          onSubmitted: onSubmitted,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
          decoration: InputDecoration(
            hintText: '0',
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFFBDC1C6)),
            suffixText: suffixText,
            hintStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFFBDC1C6),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: borderColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const double dialogRadius = 14;

    final size = MediaQuery.sizeOf(context);
    final bool isCompact = size.width < 860;
    final double maxDialogWidth = isCompact ? 560 : 640;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).pop();
        },
        const SingleActivator(LogicalKeyboardKey.enter): _submit,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _submit,
      },
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Focus(
          autofocus: true,
          child: Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dialogRadius),
            ),
            child: Container(
              width: maxDialogWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(dialogRadius),
              ),
              padding: EdgeInsets.fromLTRB(
                isCompact ? 18 : 28,
                isCompact ? 18 : 24,
                isCompact ? 18 : 28,
                isCompact ? 16 : 22,
              ),
              child: AnimatedBuilder(
                animation: Listenable.merge([_percentController, _amountController]),
                builder: (context, child) {
                  final gross = widget.grossTotal;
                  final percent = _parse(_percentController.text).clamp(0, 100).toDouble();
                  final amount = gross <= 0
                      ? 0.0
                      : _parse(_amountController.text).clamp(0, gross).toDouble();

                  final effectivePercent = _lastEdited == 'amount'
                      ? (gross <= 0 ? 0.0 : (amount / gross) * 100)
                      : percent;
                  final effectiveAmount = _lastEdited == 'amount'
                      ? amount
                      : (gross <= 0 ? 0.0 : gross * effectivePercent / 100);

                  final newTotal = (gross - effectiveAmount).clamp(0, gross).toDouble();

                  final discountText = effectiveAmount <= 0
                      ? ''
                      : '-${widget.formatParaBirimiGosterimi(effectiveAmount)}';

                  final percentText = effectiveAmount <= 0
                      ? ''
                      : '${widget.formatTutar(effectivePercent, decimalDigits: 2)}${tr('common.symbol.percent')}';

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('retail.discount.dialog.title'),
                                  style: TextStyle(
                                    fontSize: isCompact ? 19 : 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF202124),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  tr('retail.discount.dialog.subtitle'),
                                  style: TextStyle(
                                    fontSize: isCompact ? 13 : 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF606368),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tr('common.esc'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9AA0A6),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F3F4),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => Navigator.of(context).pop(),
                                  tooltip: tr('common.close'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('retail.grand_total'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF606368),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.formatParaBirimiGosterimi(gross),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF202124),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('retail.discount.dialog.new_total'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF606368),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.formatParaBirimiGosterimi(newTotal),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (effectiveAmount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${tr('common.discount')}: $discountText',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _dangerColor,
                                  ),
                                ),
                              ),
                              Text(
                                percentText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _dangerColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final bool stack = constraints.maxWidth < 520;
                          final percentField = _buildField(
                            label: '${tr('common.discount')} ${tr('common.symbol.percent')}',
                            controller: _percentController,
                            focusNode: _percentFocusNode,
                            icon: Icons.percent,
                            borderColor: _primaryColor,
                            formatters: _percentFormatters,
                            suffixText: tr('common.symbol.percent'),
                            textInputAction: stack ? TextInputAction.next : TextInputAction.done,
                            onSubmitted: (_) => _amountFocusNode.requestFocus(),
                          );

                          final amountField = _buildField(
                            label: tr('retail.discount.dialog.amount'),
                            controller: _amountController,
                            focusNode: _amountFocusNode,
                            icon: Icons.payments_outlined,
                            borderColor: _primaryColor,
                            formatters: _amountFormatters,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                          );

                          if (stack) {
                            return Column(
                              children: [
                                percentField,
                                const SizedBox(height: 18),
                                amountField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: percentField),
                              const SizedBox(width: 18),
                              Expanded(child: amountField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final bool stackButtons = constraints.maxWidth < 520;

                          final resetButton = OutlinedButton.icon(
                            onPressed: _reset,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(
                              tr('retail.partial_payment.action.reset'),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF5F6368),
                              side: const BorderSide(color: Color(0xFFE0E0E0)),
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 16 : 18,
                                vertical: isCompact ? 12 : 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          );

                          final cancelButton = TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF5F6368),
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 18 : 20,
                                vertical: isCompact ? 12 : 14,
                              ),
                            ),
                            child: Text(
                              tr('common.cancel'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );

                          final applyButton = ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 24 : 32,
                                vertical: isCompact ? 14 : 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              tr('common.apply'),
                              style: TextStyle(
                                fontSize: isCompact ? 13 : 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );

                          if (stackButtons) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                resetButton,
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    cancelButton,
                                    const SizedBox(width: 12),
                                    applyButton,
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              resetButton,
                              const Spacer(),
                              cancelButton,
                              const SizedBox(width: 12),
                              applyButton,
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PerakendeSatisSayfasi extends StatefulWidget {
  const PerakendeSatisSayfasi({super.key});

  @override
  State<PerakendeSatisSayfasi> createState() => _PerakendeSatisSayfasiState();
}

class _PerakendeSatisSayfasiState extends State<PerakendeSatisSayfasi>
    with RouteAware {
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();
  bool _routeSubscribed = false;

  // Controllers
  final _barkodController = TextEditingController();
  final _miktarController = TextEditingController(text: '1');
  final _aciklamaController = TextEditingController();
  final _odenenTutarController = TextEditingController();

  final _barkodFocusNode = FocusNode();
  final _miktarFocusNode = FocusNode();
  final _aciklamaFocusNode = FocusNode();
  final _odenenTutarFocusNode = FocusNode();
  final _tableFocusNode = FocusNode(debugLabel: 'retail_product_table');

  static const double _numericKeypadWidth = 260;
  static const double _virtualKeyboardLettersWidth = 720;
  static const double _numericKeypadHeight = 390;
  static const double _rightActionPanelWidth = 180;
  static const String _prefNumericKeypadDx = 'retail_numeric_keypad_dx';
  static const String _prefNumericKeypadDy = 'retail_numeric_keypad_dy';
  static const String _prefVirtualKeyboardLettersMode =
      'retail_virtual_keyboard_letters_mode';

  bool _showNumericKeypad = false;
  Offset? _numericKeypadOffset;
  bool _virtualKeyboardLettersMode = false;
  TextEditingController? _numericKeypadExternalController;
  FocusNode? _numericKeypadExternalFocusNode;
  CurrencyInputFormatter? _numericKeypadExternalFormatter;
  _RetailNumericKeypadTarget _numericKeypadTarget =
      _RetailNumericKeypadTarget.barkod;
  // State
  DateTime _selectedDate = DateTime.now();
  int _selectedFiyatGrubu = 1;
  String? _selectedDepo;
  int? _selectedDepoId;
  List<int> _selectedDepoIds = [];
  bool _fisYazdir = true;
  String _selectedParaBirimi = 'TRY';
  double _odenenTutar = 0.0;
  int? _selectedRowIndex;
  int? _editingIndex;
  String? _editingField;
  bool _isProcessing = false;
  double _faturaIskontoOrani = 0.0;
  bool _showHizliUrunler = false; // Closed by default as per user request

  final List<_PerakendeSepetItem> _sepetItems = [];
  final List<DepoModel> _depolar = [];
  final List<String> _depoList = [];
  List<UrunModel> _hizliUrunler = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _setupNumericKeypadTargetTracking();
    _loadNumericKeypadState();
    _loadInitialData();
    _loadHizliUrunler();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barkodFocusNode.requestFocus();
    });
  }

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _lockPortraitOnly() {
    if (!_isMobilePlatform) return;
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  }

  void _enableRetailOrientationsIfTablet() {
    if (!_isMobilePlatform) return;
    if (!ResponsiveYardimcisi.tabletMi(context)) {
      _lockPortraitOnly();
      return;
    }

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_routeSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
      _routeSubscribed = true;
      _enableRetailOrientationsIfTablet();
    }
  }

  @override
  void didPush() => _enableRetailOrientationsIfTablet();

  @override
  void didPopNext() => _enableRetailOrientationsIfTablet();

  @override
  void didPushNext() => _lockPortraitOnly();

  Future<void> _loadInitialData() async {
    await Future.wait([_loadSettings(), _loadDepolar()]);
  }

  Future<void> _loadHizliUrunler() async {
    try {
      final list = await UrunlerVeritabaniServisi().hizliUrunleriGetir();
      if (mounted) {
        setState(() {
          _hizliUrunler = list;
        });
      }
    } catch (e) {
      debugPrint('Hızlı ürünler yüklenirken hata: $e');
    }
  }

  Future<void> _selectDate() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(initialDate: _selectedDate),
    );
    if (result != null) {
      setState(() {
        _selectedDate = result;
      });
    }
  }

  Future<void> _selectWarehouses() async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) {
        List<int> tempSelected = List.from(_selectedDepoIds);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(tr('retail.warehouse')),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _depolar.map((depo) {
                      return CheckboxListTile(
                        title: Text(depo.ad),
                        value: tempSelected.contains(depo.id),
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              tempSelected.add(depo.id);
                            } else {
                              tempSelected.remove(depo.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('common.cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, tempSelected),
                  child: Text(tr('common.apply')),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null) {
      setState(() {
        _selectedDepoIds = result;
        if (_selectedDepoIds.isNotEmpty) {
          final firstDepo = _depolar.firstWhere(
            (d) => d.id == _selectedDepoIds.first,
            orElse: () => _depolar.first,
          );
          _selectedDepo = firstDepo.ad;
          _selectedDepoId = firstDepo.id;
        } else {
          _selectedDepo = null;
          _selectedDepoId = null;
        }
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'retail_selected_warehouse_ids',
        _selectedDepoIds.map((e) => e.toString()).toList(),
      );
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      if (mounted) {
        setState(() {
          _genelAyarlar = settings;
          _selectedParaBirimi = settings.varsayilanParaBirimi;
          _fisYazdir = settings.otomatikYazdir;
        });
      }
    } catch (e) {
      debugPrint('Ayarlar yüklenirken hata: $e');
    }
  }

  Future<void> _loadDepolar() async {
    try {
      final depolar = await DepolarVeritabaniServisi().tumDepolariGetir();
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final savedIdsStr = prefs.getStringList('retail_selected_warehouse_ids');

      setState(() {
        _depolar
          ..clear()
          ..addAll(depolar);
        _depoList
          ..clear()
          ..addAll(depolar.map((e) => e.ad));

        if (savedIdsStr != null) {
          final savedIds = savedIdsStr
              .map((e) => int.tryParse(e))
              .whereType<int>()
              .toList();
          _selectedDepoIds = _depolar
              .where((d) => savedIds.contains(d.id))
              .map((d) => d.id)
              .toList();
        }

        if (_selectedDepoIds.isEmpty && _depolar.isNotEmpty) {
          _selectedDepoIds = _depolar.map((e) => e.id).toList();
        }

        if (_selectedDepoIds.isNotEmpty) {
          final firstDepo = _depolar.firstWhere(
            (d) => d.id == _selectedDepoIds.first,
            orElse: () => _depolar.first,
          );
          _selectedDepo = firstDepo.ad;
          _selectedDepoId = firstDepo.id;
        } else {
          _selectedDepo = null;
          _selectedDepoId = null;
        }
      });
    } catch (e) {
      debugPrint('Depolar yüklenirken hata: $e');
    }
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    _lockPortraitOnly();
    _clearNumericKeypadExternalTarget();
    _barkodController.dispose();
    _miktarController.dispose();
    _aciklamaController.dispose();
    _odenenTutarController.dispose();
    _barkodFocusNode.dispose();
    _miktarFocusNode.dispose();
    _aciklamaFocusNode.dispose();
    _odenenTutarFocusNode.dispose();
    _tableFocusNode.dispose();
    super.dispose();
  }

  void _setupNumericKeypadTargetTracking() {
    _barkodFocusNode.addListener(() {
      if (_barkodFocusNode.hasFocus) {
        _numericKeypadTarget = _RetailNumericKeypadTarget.barkod;
      }
    });
    _miktarFocusNode.addListener(() {
      if (_miktarFocusNode.hasFocus) {
        _numericKeypadTarget = _RetailNumericKeypadTarget.miktar;
      }
    });
    _aciklamaFocusNode.addListener(() {
      if (_aciklamaFocusNode.hasFocus) {
        _numericKeypadTarget = _RetailNumericKeypadTarget.aciklama;
      }
    });
    _odenenTutarFocusNode.addListener(() {
      if (_odenenTutarFocusNode.hasFocus) {
        _numericKeypadTarget = _RetailNumericKeypadTarget.odeme;
      }
    });
  }

  Future<void> _loadNumericKeypadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dx = prefs.getDouble(_prefNumericKeypadDx);
      final dy = prefs.getDouble(_prefNumericKeypadDy);
      final lettersMode = prefs.getBool(_prefVirtualKeyboardLettersMode);
      if (!mounted) return;
      if (dx == null || dy == null) {
        if (lettersMode == null) return;
        setState(() => _virtualKeyboardLettersMode = lettersMode);
        return;
      }
      setState(() {
        _numericKeypadOffset = Offset(dx, dy);
        if (lettersMode != null) {
          _virtualKeyboardLettersMode = lettersMode;
        }
      });
    } catch (e) {
      debugPrint('Sayısal klavye durumu yüklenirken hata: $e');
    }
  }

  Future<void> _saveNumericKeypadOffset(Offset offset) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefNumericKeypadDx, offset.dx);
      await prefs.setDouble(_prefNumericKeypadDy, offset.dy);
    } catch (e) {
      debugPrint('Sayısal klavye durumu kaydedilirken hata: $e');
    }
  }

  Future<void> _saveVirtualKeyboardLettersMode(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefVirtualKeyboardLettersMode, value);
    } catch (e) {
      debugPrint('Sanal klavye modu kaydedilirken hata: $e');
    }
  }

  void _toggleNumericKeypad() {
    setState(() => _showNumericKeypad = !_showNumericKeypad);
  }

  void _toggleVirtualKeyboardLettersMode() {
    final next = !_virtualKeyboardLettersMode;
    setState(() => _virtualKeyboardLettersMode = next);
    _saveVirtualKeyboardLettersMode(next);
  }

  void _bindNumericKeypadExternalTarget({
    required TextEditingController controller,
    required FocusNode focusNode,
    required int decimalDigits,
    required String binlik,
    required String ondalik,
  }) {
    _numericKeypadExternalController = controller;
    _numericKeypadExternalFocusNode = focusNode;
    _numericKeypadExternalFormatter = CurrencyInputFormatter(
      binlik: binlik,
      ondalik: ondalik,
      maxDecimalDigits: decimalDigits,
    );
  }

  void _clearNumericKeypadExternalTarget() {
    _numericKeypadExternalController = null;
    _numericKeypadExternalFocusNode = null;
    _numericKeypadExternalFormatter = null;
  }

  TextEditingController _numericTargetController() {
    final externalController = _numericKeypadExternalController;
    final externalFocusNode = _numericKeypadExternalFocusNode;
    if (externalController != null &&
        externalFocusNode != null &&
        externalFocusNode.hasFocus) {
      return externalController;
    }
    switch (_numericKeypadTarget) {
      case _RetailNumericKeypadTarget.miktar:
        return _miktarController;
      case _RetailNumericKeypadTarget.aciklama:
        return _aciklamaController;
      case _RetailNumericKeypadTarget.odeme:
        return _odenenTutarController;
      case _RetailNumericKeypadTarget.barkod:
        return _barkodController;
    }
  }

  FocusNode _numericTargetFocusNode() {
    final externalFocusNode = _numericKeypadExternalFocusNode;
    if (externalFocusNode != null && externalFocusNode.hasFocus) {
      return externalFocusNode;
    }
    switch (_numericKeypadTarget) {
      case _RetailNumericKeypadTarget.miktar:
        return _miktarFocusNode;
      case _RetailNumericKeypadTarget.aciklama:
        return _aciklamaFocusNode;
      case _RetailNumericKeypadTarget.odeme:
        return _odenenTutarFocusNode;
      case _RetailNumericKeypadTarget.barkod:
        return _barkodFocusNode;
    }
  }

  void _updateOdenenTutarFromText(String text) {
    setState(() {
      _odenenTutar = FormatYardimcisi.parseDouble(
        text,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );
    });
  }

  void _applyNumericKeypadInsert(String insert) {
    final controller = _numericTargetController();
    final focusNode = _numericTargetFocusNode();
    final externalFormatter = _numericKeypadExternalFormatter;
    final externalFocusNode = _numericKeypadExternalFocusNode;
    final isExternalActive =
        externalFormatter != null &&
        externalFocusNode != null &&
        externalFocusNode.hasFocus &&
        identical(controller, _numericKeypadExternalController);
    final selection = controller.selection;
    final fullText = controller.text;

    final start = selection.isValid ? selection.start : fullText.length;
    final end = selection.isValid ? selection.end : fullText.length;
    final safeStart = math.min(start, end).clamp(0, fullText.length);
    final safeEnd = math.max(start, end).clamp(0, fullText.length);

    final newText = fullText.replaceRange(safeStart, safeEnd, insert);
    final newCaret = safeStart + insert.length;

    final oldValue = controller.value;
    final newValue = oldValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newCaret),
      composing: TextRange.empty,
    );
    controller.value = isExternalActive
        ? externalFormatter.formatEditUpdate(oldValue, newValue)
        : newValue;

    if (_numericKeypadTarget == _RetailNumericKeypadTarget.odeme) {
      _updateOdenenTutarFromText(newText);
    }

    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
  }

  void _applyNumericKeypadBackspace() {
    final controller = _numericTargetController();
    final focusNode = _numericTargetFocusNode();
    final externalFormatter = _numericKeypadExternalFormatter;
    final externalFocusNode = _numericKeypadExternalFocusNode;
    final isExternalActive =
        externalFormatter != null &&
        externalFocusNode != null &&
        externalFocusNode.hasFocus &&
        identical(controller, _numericKeypadExternalController);
    final selection = controller.selection;
    final fullText = controller.text;

    if (fullText.isEmpty) {
      focusNode.requestFocus();
      return;
    }

    final start = selection.isValid ? selection.start : fullText.length;
    final end = selection.isValid ? selection.end : fullText.length;
    final safeStart = math.min(start, end).clamp(0, fullText.length);
    final safeEnd = math.max(start, end).clamp(0, fullText.length);

    String newText;
    int newCaret;
    if (safeStart != safeEnd) {
      newText = fullText.replaceRange(safeStart, safeEnd, '');
      newCaret = safeStart;
    } else if (safeStart > 0) {
      newText = fullText.replaceRange(safeStart - 1, safeStart, '');
      newCaret = safeStart - 1;
    } else {
      focusNode.requestFocus();
      return;
    }

    final oldValue = controller.value;
    final newValue = oldValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newCaret),
      composing: TextRange.empty,
    );
    controller.value = isExternalActive
        ? externalFormatter.formatEditUpdate(oldValue, newValue)
        : newValue;

    if (_numericKeypadTarget == _RetailNumericKeypadTarget.odeme) {
      _updateOdenenTutarFromText(newText);
    }

    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
  }

  void _applyNumericKeypadClear() {
    final controller = _numericTargetController();
    final focusNode = _numericTargetFocusNode();
    final externalFormatter = _numericKeypadExternalFormatter;
    final externalFocusNode = _numericKeypadExternalFocusNode;
    final isExternalActive =
        externalFormatter != null &&
        externalFocusNode != null &&
        externalFocusNode.hasFocus &&
        identical(controller, _numericKeypadExternalController);
    controller.value = controller.value.copyWith(
      text: '',
      selection: const TextSelection.collapsed(offset: 0),
      composing: TextRange.empty,
    );
    if (isExternalActive) {
      controller.value = externalFormatter.formatEditUpdate(
        controller.value,
        controller.value,
      );
    }
    if (_numericKeypadTarget == _RetailNumericKeypadTarget.odeme) {
      _updateOdenenTutarFromText('');
    }
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
  }

  Offset _clampNumericKeypadOffset(
    Offset desired,
    BoxConstraints constraints, {
    required double keypadWidth,
    required double keypadHeight,
  }) {
    final maxDx = math.max(16.0, constraints.maxWidth - keypadWidth - 16);
    final maxDy =
        math.max(16.0, constraints.maxHeight - keypadHeight - 16);
    return Offset(
      desired.dx.clamp(16.0, maxDx),
      desired.dy.clamp(16.0, maxDy),
    );
  }

  Widget _buildNumericKeypadOverlay({
    required BoxConstraints constraints,
    required bool hasRightActionPanel,
  }) {
    final requestedWidth = _virtualKeyboardLettersMode
        ? _virtualKeyboardLettersWidth
        : _numericKeypadWidth;
    final keypadWidth = math.min(
      requestedWidth,
      math.max(200.0, constraints.maxWidth - 32),
    );
    final keypadHeight = math.min(
      _numericKeypadHeight,
      math.max(200.0, constraints.maxHeight - 32),
    );

    final baseOffset = _numericKeypadOffset ??
        Offset(
          constraints.maxWidth -
              keypadWidth -
              (hasRightActionPanel ? (_rightActionPanelWidth + 16) : 16),
          constraints.maxHeight - keypadHeight - 16,
        );

    final clampedOffset = _clampNumericKeypadOffset(
      baseOffset,
      constraints,
      keypadWidth: keypadWidth,
      keypadHeight: keypadHeight,
    );
    final decimalSeparator = _genelAyarlar.ondalikAyiraci.trim().isNotEmpty
        ? _genelAyarlar.ondalikAyiraci.trim()
        : ',';

    return Positioned(
      left: clampedOffset.dx,
      top: clampedOffset.dy,
      child: TextFieldTapRegion(
        child: _FloatingNumericKeypad(
          width: keypadWidth,
          height: keypadHeight,
          decimalSeparator: decimalSeparator,
          lettersMode: _virtualKeyboardLettersMode,
          onToggleLettersMode: _toggleVirtualKeyboardLettersMode,
          onClose: () {
            setState(() => _showNumericKeypad = false);
          },
          onDragUpdate: (delta) {
            final current = _clampNumericKeypadOffset(
              _numericKeypadOffset ?? clampedOffset,
              constraints,
              keypadWidth: keypadWidth,
              keypadHeight: keypadHeight,
            );
            setState(() {
              _numericKeypadOffset = _clampNumericKeypadOffset(
                current + delta,
                constraints,
                keypadWidth: keypadWidth,
                keypadHeight: keypadHeight,
              );
            });
          },
          onDragEnd: () {
            final toSave = _clampNumericKeypadOffset(
              _numericKeypadOffset ?? clampedOffset,
              constraints,
              keypadWidth: keypadWidth,
              keypadHeight: keypadHeight,
            );
            _numericKeypadOffset = toSave;
            _saveNumericKeypadOffset(toSave);
          },
          onInsert: _applyNumericKeypadInsert,
          onBackspace: _applyNumericKeypadBackspace,
          onClear: _applyNumericKeypadClear,
        ),
      ),
    );
  }

  double get _genelToplam {
    return _sepetItems.fold(0.0, (sum, item) => sum + item.toplamFiyat);
  }

  int get _satirSayisi => _sepetItems.length;

  double get _paraUstu {
    final diff = _odenenTutar - _genelToplam;
    return diff > 0 ? diff : 0;
  }

  String _formatTutar(double tutar, {int? decimalDigits}) {
    return FormatYardimcisi.sayiFormatlaOndalikli(
      tutar,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: decimalDigits ?? _genelAyarlar.fiyatOndalik,
    );
  }

  String _formatMiktar(double miktar) {
    final decimals = _genelAyarlar.miktarOndalik;
    final hasFraction = (miktar - miktar.truncateToDouble()).abs() > 0.000000001;
    if (!hasFraction || decimals <= 0) {
      return FormatYardimcisi.sayiFormatla(
        miktar,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: 0,
      );
    }

    return FormatYardimcisi.sayiFormatlaOndalikli(
      miktar,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: decimals,
    );
  }

  String _formatParaBirimiGosterimi(double tutar) {
    final formatted = _formatTutar(tutar);
    if (!_genelAyarlar.sembolGoster) {
      return '$formatted $_selectedParaBirimi';
    }

    switch (_selectedParaBirimi) {
      case 'TRY':
        return '$formatted ₺';
      case 'USD':
        return '$formatted \$';
      case 'EUR':
        return '$formatted €';
      case 'GBP':
        return '$formatted £';
      default:
        return '$formatted $_selectedParaBirimi';
    }
  }

  double _parseMiktar() {
    return FormatYardimcisi.parseDouble(
      _miktarController.text,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
    );
  }

  double _secilenFiyat(dynamic item) {
    switch (_selectedFiyatGrubu) {
      case 2:
        return item.satisFiyati2;
      case 3:
        return item.satisFiyati3;
      case 1:
      default:
        return item.satisFiyati1;
    }
  }

  Future<void> _barkodAraVeEkle({bool dialogAc = true}) async {
    if (_isProcessing) return;

    final query = _barkodController.text.trim();
    if (query.isEmpty) {
      if (dialogAc) _openProductSearchDialog();
      return;
    }

    final qty = _parseMiktar();
    if (qty <= 0) {
      MesajYardimcisi.hataGoster(context, tr('retail.error.invalid_quantity'));
      return;
    }

    try {
      // 1. Ürünlerde ara
      final urun = await UrunlerVeritabaniServisi().urunGetirKodVeyaBarkod(
        query,
      );

      if (urun != null) {
        if (!mounted) return;
        _sepeteEkle(item: urun, miktar: qty);
        _finishItemAddition();
        return;
      }

      // 2. Üretimlerde ara
      final uretim = await UretimlerVeritabaniServisi()
          .uretimGetirKodVeyaBarkod(query);

      if (uretim != null) {
        if (!mounted) return;
        _sepeteEkle(item: uretim, miktar: qty);
        _finishItemAddition();
        return;
      }

      // 3. Bulunamadı
      if (!mounted) return;
      MesajYardimcisi.bilgiGoster(context, tr('products.no_products_found'));
      if (dialogAc) _openProductSearchDialog(initialQuery: query);
    } catch (e) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  void _finishItemAddition() {
    _barkodController.clear();
    _miktarController.text = '1';
    _barkodFocusNode.requestFocus();
    final isTablet = ResponsiveYardimcisi.tabletMi(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (isTablet && isLandscape) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    }
    setState(() {});
  }

  void _sepeteEkle({required dynamic item, required double miktar}) {
    final depoAdi = _selectedDepo;
    final depoId = _selectedDepoId;
    final birimFiyat = _secilenFiyat(item);
    final iskonto = _faturaIskontoOrani;
    final toplam = (birimFiyat * miktar) * (1 - (iskonto / 100));

    final existingIndex = _sepetItems.indexWhere(
      (x) =>
          x.kodNo == item.kod &&
          x.birimFiyati == birimFiyat &&
          x.iskontoOrani == iskonto &&
          x.depoId == depoId,
    );

    if (existingIndex >= 0) {
      final existing = _sepetItems[existingIndex];
      final yeniMiktar = existing.miktar + miktar;
      final yeniToplam = (birimFiyat * yeniMiktar) * (1 - (iskonto / 100));
      _sepetItems[existingIndex] = existing.copyWith(
        miktar: yeniMiktar,
        toplamFiyat: yeniToplam,
      );
      return;
    }

    _sepetItems.add(
      _PerakendeSepetItem(
        kodNo: item.kod,
        barkodNo: item.barkod,
        adi: item.ad,
        birimFiyati: birimFiyat,
        iskontoOrani: iskonto,
        miktar: miktar,
        olcu: item.birim,
        toplamFiyat: toplam,
        paraBirimi: _selectedParaBirimi,
        depoId: depoId,
        depoAdi: depoAdi,
      ),
    );
  }

  List<int> _nakitButonDegerleri() {
    final raw = [
      _genelAyarlar.nakit1,
      _genelAyarlar.nakit2,
      _genelAyarlar.nakit3,
      _genelAyarlar.nakit4,
      _genelAyarlar.nakit5,
      _genelAyarlar.nakit6,
    ];

    final parsed = raw
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList(growable: false);

    if (parsed.length == 6) return parsed;
    return const [5, 10, 20, 50, 100, 200];
  }

  Future<void> _tamamlaSatisTekOdeme({
    required String odemeYeri,
    double? alinanTutar,
  }) async {
    if (_isProcessing) return;

    if (_sepetItems.isEmpty) {
      MesajYardimcisi.hataGoster(context, tr('sale.error.no_items'));
      return;
    }

    if (_selectedDepoId == null) {
      MesajYardimcisi.hataGoster(context, tr('sale.msg.select_warehouse'));
      return;
    }

    final genelToplam = _genelToplam;
    if (genelToplam <= 0) return;

    final tahsilatTutar = alinanTutar ?? genelToplam;

    final tendered = _odenenTutar;
    if (odemeYeri == 'Kasa' &&
        tahsilatTutar > 0 &&
        tendered > 0 &&
        tendered < genelToplam) {
      MesajYardimcisi.hataGoster(
        context,
        tr('retail.error.insufficient_payment'),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = prefs.getString('current_username') ?? 'Sistem';

      final faturaNo = 'PRK-${DateTime.now().millisecondsSinceEpoch}';
      final entegrasyonRef = 'RETAIL-$faturaNo';

      final List<Map<String, dynamic>> payments = [];
      if (tahsilatTutar > 0) {
        String? target;
        String? accountCode;
        if (odemeYeri == 'Kasa') {
          target = _normalizeRetailPostingTarget(
            _genelAyarlar.perakendeNakitIslemeYeri,
            fallback: 'cash',
          );
          accountCode = _genelAyarlar.perakendeNakitIslemeHesapKodu;
        } else if (odemeYeri == 'Kredi Kartı') {
          target = _normalizeRetailPostingTarget(
            _genelAyarlar.perakendeKrediKartiIslemeYeri,
            fallback: 'credit_card',
          );
          accountCode = _genelAyarlar.perakendeKrediKartiIslemeHesapKodu;
        } else if (odemeYeri == 'Havale') {
          target = _normalizeRetailPostingTarget(
            _genelAyarlar.perakendeHavaleIslemeYeri,
            fallback: 'bank',
          );
          accountCode = _genelAyarlar.perakendeHavaleIslemeHesapKodu;
        }

        if (target != null) {
          await _addRetailPayment(
            payments: payments,
            sourceType: odemeYeri,
            target: target,
            amount: tahsilatTutar,
            accountCode: accountCode,
          );
        }
      }

      final satisBilgileri = {
        'kullanici': currentUser,
        'tarih': _selectedDate,
        'belgeTuru': 'Perakende',
        'faturaNo': faturaNo,
        'aciklama': _aciklamaController.text,
        'genelToplam': genelToplam,
        'odemeYeri': odemeYeri,
        'odemeHesapKodu': '',
        'odemeAciklama': '',
        'alinanTutar': tahsilatTutar,
        'integrationRef': entegrasyonRef,
        'paraBirimi': _selectedParaBirimi,
        'payments': payments,
        'items': _sepetItems
            .map(
              (e) => {
                'code': e.kodNo,
                'name': e.adi,
                'unit': e.olcu,
                'quantity': e.miktar,
                'price': e.birimFiyati,
                'total': e.toplamFiyat,
                'discountRate': e.iskontoOrani,
                'warehouseId': _selectedDepoId,
              },
            )
            .toList(growable: false),
      };

      await PerakendeSatisVeritabaniServisi().satisIsleminiKaydet(
        satisBilgileri: satisBilgileri,
      );

      if (!mounted) return;

      if (_fisYazdir) {
        await _fisYazdirOnizleme(faturaNo: faturaNo);
        if (!mounted) return;
      }

      setState(() {
        _sepetItems.clear();
        _odenenTutar = 0;
        _odenenTutarController.clear();
        _selectedRowIndex = null;
      });

      MesajYardimcisi.basariGoster(context, tr('common.saved_successfully'));
      SayfaSenkronizasyonServisi().veriDegisti('cari');
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _fisYazdirOnizleme({required String faturaNo}) async {
    final headers = [
      tr('retail.table.code'),
      tr('retail.table.barcode'),
      tr('retail.table.name'),
      tr('retail.table.unit_price'),
      tr('retail.table.discount'),
      tr('retail.table.quantity'),
      tr('retail.table.unit'),
      tr('retail.table.total_price'),
    ];

    final data = _sepetItems
        .map(
          (e) => [
            e.kodNo,
            e.barkodNo,
            e.adi,
            _formatTutar(e.birimFiyati),
            _formatTutar(e.iskontoOrani, decimalDigits: 2),
            _formatTutar(e.miktar, decimalDigits: _genelAyarlar.miktarOndalik),
            e.olcu,
            '${_formatTutar(e.toplamFiyat)} ${e.paraBirimi}',
          ],
        )
        .toList(growable: false);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PrintPreviewScreen(
          title: '${tr('nav.trading_operations.retail_sale')} - $faturaNo',
          headers: headers,
          data: data,
        ),
      ),
    );
  }

  Future<void> _openProductSearchDialog({String initialQuery = ''}) async {
    showDialog(
      context: context,
      builder: (context) => _PerakendeUrunSearchDialog(
        initialQuery: initialQuery,
        onSelect: (urun) {
          final qty = _parseMiktar();
          if (qty <= 0) {
            MesajYardimcisi.hataGoster(
              context,
              tr('retail.error.invalid_quantity'),
            );
            return;
          }
          setState(() {
            _sepeteEkle(item: urun, miktar: qty);
            _barkodController.clear();
            _miktarController.text = '1';
            _barkodFocusNode.requestFocus();
          });
        },
      ),
    );
  }

  Future<void> _tumunuSil() async {
    if (_sepetItems.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr('common.confirm_delete_all'),
        onayButonMetni: tr('common.delete'),
        isDestructive: true,
        onOnay: () {
          setState(() {
            _sepetItems.clear();
            _selectedRowIndex = null;
            _odenenTutar = 0;
            _odenenTutarController.clear();
          });
        },
      ),
    );
  }

  void _seciliyiSil() {
    if (_sepetItems.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr('common.confirm_delete_selected'),
        onayButonMetni: tr('common.delete'),
        isDestructive: true,
        onOnay: () {
          if (!mounted) return;
          setState(() {
            final index = _selectedRowIndex ?? (_sepetItems.length - 1);
            if (index >= 0 && index < _sepetItems.length) {
              _sepetItems.removeAt(index);
            }
            _selectedRowIndex = null;
          });
          if (_sepetItems.isEmpty) {
            _barkodFocusNode.requestFocus();
          } else {
            _tableFocusNode.requestFocus();
          }
        },
      ),
    );
  }

  void _showInvoiceDiscountDialog() async {
    if (_sepetItems.isEmpty) {
      MesajYardimcisi.bilgiGoster(context, tr('sale.error.no_items'));
      return;
    }

    final grossTotal = _sepetItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.birimFiyati * item.miktar),
    );

    final result = await showDialog<_IskontoResult>(
      context: context,
      builder: (context) => _PerakendeIskontoDialog(
        genelAyarlar: _genelAyarlar,
        grossTotal: grossTotal,
        initialPercent: _faturaIskontoOrani,
        formatTutar: _formatTutar,
        formatParaBirimiGosterimi: _formatParaBirimiGosterimi,
      ),
    );
    if (!mounted || result == null) return;

    final val = result.percent.clamp(0, 100).toDouble();
    setState(() {
      _faturaIskontoOrani = val;
      for (var i = 0; i < _sepetItems.length; i++) {
        final item = _sepetItems[i];
        final yeniToplam =
            (item.birimFiyati * item.miktar) * (1 - (val / 100));
        _sepetItems[i] = item.copyWith(
          iskontoOrani: val,
          toplamFiyat: yeniToplam,
        );
      }
    });
  }

  Future<KasaModel?> _varsayilanKasaGetir() async {
    final kasalar = await KasalarVeritabaniServisi().tumKasalariGetir();
    if (kasalar.isEmpty) return null;
    final varsayilan = kasalar.where((e) => e.varsayilan).toList();
    return varsayilan.isNotEmpty ? varsayilan.first : kasalar.first;
  }

  Future<BankaModel?> _varsayilanBankaGetir() async {
    final bankalar = await BankalarVeritabaniServisi().tumBankalariGetir();
    if (bankalar.isEmpty) return null;
    final varsayilan = bankalar.where((e) => e.varsayilan).toList();
    return varsayilan.isNotEmpty ? varsayilan.first : bankalar.first;
  }

  Future<KrediKartiModel?> _varsayilanKrediKartiGetir() async {
    final kartlar = await KrediKartlariVeritabaniServisi()
        .tumKrediKartlariniGetir();
    if (kartlar.isEmpty) return null;
    final varsayilan = kartlar.where((e) => e.varsayilan).toList();
    return varsayilan.isNotEmpty ? varsayilan.first : kartlar.first;
  }

  static const Set<String> _retailPostingTargets = {
    'cash',
    'bank',
    'credit_card',
  };

  String _normalizeRetailPostingTarget(String value, {required String fallback}) {
    if (_retailPostingTargets.contains(value)) return value;
    return fallback;
  }

  Future<void> _addRetailPayment({
    required List<Map<String, dynamic>> payments,
    required String sourceType,
    required String target,
    required double amount,
    String? accountCode,
  }) async {
    if (amount <= 0) return;

    final preferredCode = accountCode?.trim() ?? '';

    switch (target) {
      case 'cash':
        if (preferredCode.isNotEmpty) {
          payments.add({
            'type': 'Kasa',
            'amount': amount,
            'accountCode': preferredCode,
            'sourceType': sourceType,
          });
          return;
        }
        final kasa = await _varsayilanKasaGetir();
        if (kasa == null) {
          throw Exception(tr('retail.error.no_cash_register'));
        }
        payments.add({
          'type': 'Kasa',
          'amount': amount,
          'accountCode': kasa.kod,
          'sourceType': sourceType,
        });
        return;
      case 'bank':
        if (preferredCode.isNotEmpty) {
          final bankalar = await BankalarVeritabaniServisi().bankaAra(
            preferredCode,
            limit: 1,
          );
          if (bankalar.isNotEmpty) {
            payments.add({
              'type': 'Banka',
              'amount': amount,
              'accountCode': bankalar.first.kod,
              'sourceType': sourceType,
            });
            return;
          }
        }
        final banka = await _varsayilanBankaGetir();
        if (banka == null) {
          throw Exception(tr('retail.error.no_bank_account'));
        }
        payments.add({
          'type': 'Banka',
          'amount': amount,
          'accountCode': banka.kod,
          'sourceType': sourceType,
        });
        return;
      case 'credit_card':
        if (preferredCode.isNotEmpty) {
          payments.add({
            'type': 'Kredi Kartı',
            'amount': amount,
            'accountCode': preferredCode,
            'sourceType': sourceType,
          });
          return;
        }
        final kart = await _varsayilanKrediKartiGetir();
        if (kart == null) {
          throw Exception(tr('retail.error.no_credit_card_account'));
        }
        payments.add({
          'type': 'Kredi Kartı',
          'amount': amount,
          'accountCode': kart.kod,
          'sourceType': sourceType,
        });
        return;
    }
  }

  Future<void> _tamamlaCariSatis() async {
    await _tamamlaSatisTekOdeme(odemeYeri: 'Cari', alinanTutar: 0);
  }

  void _showPartialPaymentDialog() {
    if (_sepetItems.isEmpty) {
      MesajYardimcisi.hataGoster(context, tr('sale.error.no_items'));
      return;
    }

    final total = _genelToplam;
    showDialog<_ParcaliOdemeResult>(
      context: context,
      builder: (context) => _PerakendeParcaliOdemeDialog(
        genelAyarlar: _genelAyarlar,
        total: total,
        formatTutar: _formatTutar,
        formatParaBirimiGosterimi: _formatParaBirimiGosterimi,
      ),
    ).then((result) async {
      if (!mounted || result == null) return;
      await _tamamlaParcaliOdeme(
        nakitTutar: result.nakit,
        krediKartiTutar: result.krediKarti,
        havaleTutar: result.havale,
      );
    });
  }

  Future<void> _tamamlaParcaliOdeme({
    required double nakitTutar,
    required double krediKartiTutar,
    required double havaleTutar,
  }) async {
    if (_isProcessing) return;

    if (_sepetItems.isEmpty) {
      MesajYardimcisi.hataGoster(context, tr('sale.error.no_items'));
      return;
    }

    if (_selectedDepoId == null) {
      MesajYardimcisi.hataGoster(context, tr('sale.msg.select_warehouse'));
      return;
    }

    final genelToplam = _genelToplam;
    final factor = () {
      var v = 1;
      for (var i = 0; i < _genelAyarlar.fiyatOndalik; i++) {
        v *= 10;
      }
      return v;
    }();
    final paidMinor =
        ((nakitTutar + krediKartiTutar + havaleTutar) * factor).round();
    final totalMinor = (genelToplam * factor).round();

    if (paidMinor > totalMinor) {
      MesajYardimcisi.hataGoster(
        context,
        tr('retail.error.payment_exceeds_total'),
      );
      return;
    }

    if (paidMinor != totalMinor) {
      MesajYardimcisi.hataGoster(context, tr('retail.error.insufficient_payment'));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = prefs.getString('current_username') ?? 'Sistem';

      final faturaNo = 'PRK-${DateTime.now().millisecondsSinceEpoch}';
      final entegrasyonRef = 'RETAIL-$faturaNo';

      final List<Map<String, dynamic>> payments = [];
      if (nakitTutar > 0) {
        final target = _normalizeRetailPostingTarget(
          _genelAyarlar.perakendeNakitIslemeYeri,
          fallback: 'cash',
        );
        await _addRetailPayment(
          payments: payments,
          sourceType: 'Kasa',
          target: target,
          amount: nakitTutar,
          accountCode: _genelAyarlar.perakendeNakitIslemeHesapKodu,
        );
      }

      if (krediKartiTutar > 0) {
        final target = _normalizeRetailPostingTarget(
          _genelAyarlar.perakendeKrediKartiIslemeYeri,
          fallback: 'credit_card',
        );
        await _addRetailPayment(
          payments: payments,
          sourceType: 'Kredi Kartı',
          target: target,
          amount: krediKartiTutar,
          accountCode: _genelAyarlar.perakendeKrediKartiIslemeHesapKodu,
        );
      }

      if (havaleTutar > 0) {
        final target = _normalizeRetailPostingTarget(
          _genelAyarlar.perakendeHavaleIslemeYeri,
          fallback: 'bank',
        );
        await _addRetailPayment(
          payments: payments,
          sourceType: 'Havale',
          target: target,
          amount: havaleTutar,
          accountCode: _genelAyarlar.perakendeHavaleIslemeHesapKodu,
        );
      }

      await PerakendeSatisVeritabaniServisi().satisIsleminiKaydet(
        satisBilgileri: {
          'kullanici': currentUser,
          'tarih': _selectedDate,
          'belgeTuru': 'Perakende',
          'faturaNo': faturaNo,
          'aciklama': _aciklamaController.text,
          'genelToplam': genelToplam,
          'alinanTutar': genelToplam,
          'integrationRef': entegrasyonRef,
          'paraBirimi': _selectedParaBirimi,
          'payments': payments,
          'items': _sepetItems
              .map(
                (e) => {
                  'code': e.kodNo,
                  'name': e.adi,
                  'unit': e.olcu,
                  'quantity': e.miktar,
                  'price': e.birimFiyati,
                  'total': e.toplamFiyat,
                  'discountRate': e.iskontoOrani,
                  'warehouseId': _selectedDepoId,
                },
              )
              .toList(growable: false),
        },
      );

      if (!mounted) return;

      if (_fisYazdir) {
        await _fisYazdirOnizleme(faturaNo: faturaNo);
        if (!mounted) return;
      }

      setState(() {
        _sepetItems.clear();
        _odenenTutar = 0;
        _odenenTutarController.clear();
        _selectedRowIndex = null;
      });

      MesajYardimcisi.basariGoster(context, tr('common.saved_successfully'));
      SayfaSenkronizasyonServisi().veriDegisti('cari');
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

	@override
	Widget build(BuildContext context) {
	    final theme = Theme.of(context);
	    final isTablet = ResponsiveYardimcisi.tabletMi(context);
	    final isLandscape =
	        MediaQuery.orientationOf(context) == Orientation.landscape;
	    final useTabletLandscapeLayout = isTablet && isLandscape;
	    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

	    return CallbackShortcuts(
	      bindings: <ShortcutActivator, VoidCallback>{
	        LogicalKeySet(LogicalKeyboardKey.f1): () {
	          _miktarFocusNode.requestFocus();
	          _miktarController.selection = TextSelection(
	            baseOffset: 0,
	            extentOffset: _miktarController.text.length,
	          );
	        },
	        LogicalKeySet(LogicalKeyboardKey.f2): () {
	          _odenenTutarFocusNode.requestFocus();
	          _odenenTutarController.selection = TextSelection(
	            baseOffset: 0,
	            extentOffset: _odenenTutarController.text.length,
	          );
	        },
	        LogicalKeySet(LogicalKeyboardKey.f3): () {
	          Navigator.of(context).push(
	            MaterialPageRoute(builder: (context) => const KasalarSayfasi()),
	          );
	        },
	        LogicalKeySet(LogicalKeyboardKey.f4): () {
	          _tamamlaSatisTekOdeme(odemeYeri: 'Kasa');
	        },
	        LogicalKeySet(LogicalKeyboardKey.f5): () {
	          _tamamlaSatisTekOdeme(odemeYeri: 'Havale');
	        },
	        LogicalKeySet(LogicalKeyboardKey.f6): () {
	          _tamamlaSatisTekOdeme(odemeYeri: 'Kredi Kartı');
	        },
	        LogicalKeySet(LogicalKeyboardKey.f7): () {
	          _showPartialPaymentDialog();
	        },
	        LogicalKeySet(LogicalKeyboardKey.f8): () {
	          _tamamlaCariSatis();
	        },
	        LogicalKeySet(LogicalKeyboardKey.f9): () {
	          _showInvoiceDiscountDialog();
	        },
	        LogicalKeySet(LogicalKeyboardKey.f10): () {
	          _tumunuSil();
	        },
	        LogicalKeySet(LogicalKeyboardKey.f11): () {
	          final isCompact = MediaQuery.sizeOf(context).width < 1100;
	          if (isCompact) {
	            _openHizliUrunlerSheet();
	            return;
	          }
	          setState(() => _showHizliUrunler = !_showHizliUrunler);
	        },
	        LogicalKeySet(LogicalKeyboardKey.f12): _toggleNumericKeypad,
	      },
	      child: Scaffold(
	        key: _scaffoldKey,
	        backgroundColor: const Color(0xFFF5F5F5),
	        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            tr('nav.trading_operations.retail_sale'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 21,
            ),
          ),
          centerTitle: false,
        ),
		        body: LayoutBuilder(
		          builder: (context, constraints) {
		            final bool tightHeightForKeyboard =
		                useTabletLandscapeLayout && constraints.maxHeight < 320;
		            final bool treatAsKeyboardVisible =
		                keyboardVisible || tightHeightForKeyboard;
		            final collapseSecondRow = useTabletLandscapeLayout &&
		                treatAsKeyboardVisible &&
		                !_aciklamaFocusNode.hasFocus;
		            final hideBottomAreaForKeyboard =
		                useTabletLandscapeLayout && treatAsKeyboardVisible;

		            final isCompact = constraints.maxWidth < 1100 || isTablet;

		            if (isCompact) {
		              return Stack(
		                fit: StackFit.expand,
		                children: [
		                  SafeArea(
		                    top: false,
		                    child: ListView(
		                      padding: EdgeInsets.zero,
		                      keyboardDismissBehavior:
		                          ScrollViewKeyboardDismissBehavior.onDrag,
		                      children: [
		                        _buildTopControlArea(),
		                        _buildProductTable(compactMode: true),
		                        _buildCompactActionBar(),
		                        _buildBottomArea(),
		                      ],
		                    ),
		                  ),
		                  if (_showNumericKeypad)
		                    _buildNumericKeypadOverlay(
		                      constraints: constraints,
		                      hasRightActionPanel: false,
		                    ),
		                ],
		              );
	            }

            final allowQuickSidePanel = constraints.maxWidth >= 1300;
            if (!allowQuickSidePanel && _showHizliUrunler) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (!_showHizliUrunler) return;
                setState(() => _showHizliUrunler = false);
              });
            }

		            return Stack(
		              fit: StackFit.expand,
		              children: [
		                Row(
		                  children: [
		                    // Ana İçerik (Tablo, Üst Alan, Alt Alan)
		                    Expanded(
		                      child: Column(
		                        children: [
		                          // Üst kontrol alanı
		                          _buildTopControlArea(
		                            collapseSecondRow: collapseSecondRow,
		                          ),
		                          // Tablo
		                          Expanded(child: _buildProductTable()),
		                          // Alt para butonları ve toplam
		                          if (hideBottomAreaForKeyboard)
		                            _buildKeyboardSummaryBar()
		                          else
		                            _buildBottomArea(),
		                        ],
		                      ),
		                    ),
		                    // Entegre Hızlı Ürünler Paneli
		                    if (allowQuickSidePanel && _showHizliUrunler)
		                      _buildHizliUrunlerSidePanel(),
		                    // Sağ Dar Aksiyon Paneli
		                    _buildRightActionPanel(
		                      useQuickProductsSheet: !allowQuickSidePanel,
		                    ),
		                  ],
		                ),
		                if (_showNumericKeypad)
		                  _buildNumericKeypadOverlay(
		                    constraints: constraints,
		                    hasRightActionPanel: true,
		                  ),
		              ],
		            );
	          },
	        ),
      ),
    );
  }

  void _hizliUrunSecildi(UrunModel urun) {
    final qty = _parseMiktar();
    if (qty <= 0) {
      MesajYardimcisi.hataGoster(context, tr('retail.error.invalid_quantity'));
      return;
    }

    setState(() {
      _sepeteEkle(item: urun, miktar: qty);
      _barkodController.clear();
      _miktarController.text = '1';
    });
    _barkodFocusNode.requestFocus();
  }

  Future<void> _openHizliUrunlerSheet() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: Material(
                color: Colors.white,
                child: _PerakendeHizliUrunlerPaneli(
                  headerPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  hizliUrunler: _hizliUrunler,
                  onSelect: _hizliUrunSecildi,
                  onChanged: _loadHizliUrunler,
                  onClose: () => Navigator.of(sheetContext).pop(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMoreActionsSheet() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
            child: Material(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr('common.other'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      label: tr('retail.account_sale'),
                      shortcut: '',
                      color: Colors.grey.shade100,
                      textColor: Colors.grey.shade700,
                      icon: Icons.account_balance_wallet,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _tamamlaCariSatis();
                      },
                      outlined: true,
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      label: tr('retail.apply_discount'),
                      shortcut: '',
                      color: Colors.grey.shade100,
                      textColor: Colors.grey.shade700,
                      icon: Icons.percent,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _showInvoiceDiscountDialog();
                      },
                      outlined: true,
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      label: tr('retail.delete_all'),
                      shortcut: '',
                      color: const Color(0xFFFFEBEE),
                      textColor: const Color(0xFFEA4335),
                      icon: Icons.delete_outline,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _tumunuSil();
                      },
                      outlined: true,
                      borderColor: const Color(0xFFEA4335),
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      label: tr('retail.delete_selected'),
                      shortcut: '',
                      color: Colors.grey.shade50,
                      textColor: Colors.grey.shade700,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _seciliyiSil();
                      },
                      outlined: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: tr('retail.cash_sale'),
                  shortcut: '',
                  color: const Color(0xFF4CAF50),
                  icon: Icons.monetization_on,
                  onPressed: () =>
                      _tamamlaSatisTekOdeme(odemeYeri: 'Kasa'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  label: tr('retail.credit_card'),
                  shortcut: '',
                  color: const Color(0xFF26A69A),
                  icon: Icons.credit_card,
                  onPressed: () =>
                      _tamamlaSatisTekOdeme(odemeYeri: 'Kredi Kartı'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: tr('retail.transfer_sale'),
                  shortcut: '',
                  color: const Color(0xFF1E88E5),
                  icon: Icons.account_balance,
                  onPressed: () =>
                      _tamamlaSatisTekOdeme(odemeYeri: 'Havale'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  label: tr('retail.partial_payment'),
                  shortcut: '',
                  color: const Color(0xFFFF9800),
                  icon: Icons.pie_chart,
                  onPressed: _showPartialPaymentDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTextActionButton(
                  label: tr('retail.quick_products'),
                  shortcut: '',
                  icon: Icons.bolt,
                  onPressed: _openHizliUrunlerSheet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextActionButton(
                  label: tr('retail.numeric_keyboard'),
                  shortcut: '',
                  icon: Icons.dialpad,
                  onPressed: _toggleNumericKeypad,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextActionButton(
                  label: tr('retail.cash_register'),
                  shortcut: '',
                  icon: Icons.point_of_sale,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const KasalarSayfasi(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextActionButton(
                  label: tr('common.other'),
                  shortcut: '',
                  icon: Icons.more_horiz_rounded,
                  onPressed: _openMoreActionsSheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopControlArea({bool collapseSecondRow = false}) {
    final bool isTablet = ResponsiveYardimcisi.tabletMi(context);
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isPhoneNarrow = !isTablet && screenWidth < 520;
    return Container(
      padding: isPhoneNarrow
          ? const EdgeInsets.fromLTRB(12, 12, 12, 12)
          : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
	      child: Column(
	        children: [
	          // Birinci satır: Miktar, Barkod arama
	          LayoutBuilder(
	            builder: (context, constraints) {
	              final bool isNarrow = constraints.maxWidth < 640;
	              final bool isVeryNarrow = constraints.maxWidth < 480;
	              final double fieldHeight = isVeryNarrow ? 44 : 48;

	              final quantitySection = Column(
	                crossAxisAlignment: CrossAxisAlignment.start,
	                children: [
	                  Row(
	                    children: [
	                      Text(
	                        tr('retail.quantity'),
	                        style: TextStyle(
	                          fontSize: 12,
	                          fontWeight: FontWeight.w500,
	                          color: Colors.grey.shade600,
	                        ),
	                      ),
	                      const SizedBox(width: 4),
	                      _buildShortcutBadge('F1'),
	                    ],
	                  ),
	                  const SizedBox(height: 4),
	                  Row(
	                    crossAxisAlignment: CrossAxisAlignment.end,
	                    children: [
	                      SizedBox(
	                        width: 60,
	                        height: fieldHeight,
	                        child: TextField(
	                          controller: _miktarController,
	                          focusNode: _miktarFocusNode,
	                          onSubmitted: (_) =>
	                              _barkodFocusNode.requestFocus(),
	                          textAlign: TextAlign.center,
	                          keyboardType: TextInputType.number,
	                          style: const TextStyle(
	                            fontSize: 16,
	                            fontWeight: FontWeight.w600,
	                          ),
	                          decoration: InputDecoration(
	                            contentPadding: const EdgeInsets.symmetric(
	                              horizontal: 8,
	                            ),
	                            border: OutlineInputBorder(
	                              borderRadius: BorderRadius.circular(8),
	                              borderSide: BorderSide(
	                                color: Colors.grey.shade300,
	                              ),
	                            ),
	                            enabledBorder: OutlineInputBorder(
	                              borderRadius: BorderRadius.circular(8),
	                              borderSide: BorderSide(
	                                color: Colors.grey.shade300,
	                              ),
	                            ),
	                          ),
	                        ),
	                      ),
	                      const SizedBox(width: 8),
	                      _buildSmallButton(
	                        icon: Icons.add,
	                        label: tr('retail.add'),
	                        onPressed: () => _barkodAraVeEkle(),
	                        iconOnly: isVeryNarrow,
	                        height: fieldHeight,
	                      ),
	                    ],
	                  ),
	                ],
	              );

	              final barcodeSection = Row(
	                crossAxisAlignment: CrossAxisAlignment.end,
	                children: [
	                  Expanded(
	                    child: Container(
	                      height: fieldHeight,
	                      decoration: BoxDecoration(
	                        color: Colors.white,
	                        borderRadius: BorderRadius.circular(8),
	                        border: Border.all(
	                          color: const Color(0xFF1E88E5),
	                          width: 2,
	                        ),
	                      ),
	                      child: TextField(
	                        controller: _barkodController,
	                        focusNode: _barkodFocusNode,
	                        style: const TextStyle(
	                          fontSize: 18,
	                          fontWeight: FontWeight.w500,
	                        ),
	                        onSubmitted: (_) => _barkodAraVeEkle(),
	                        decoration: InputDecoration(
	                          hintText: tr('retail.barcode_placeholder'),
	                          hintStyle: TextStyle(
	                            color: Colors.grey.shade400,
	                            fontSize: 18,
	                            fontWeight: FontWeight.w400,
	                          ),
	                          contentPadding: EdgeInsets.symmetric(
	                            horizontal: isVeryNarrow ? 12 : 16,
	                          ),
	                          border: InputBorder.none,
	                        ),
	                      ),
	                    ),
	                  ),
	                  const SizedBox(width: 8),
	                  SizedBox(
	                    height: fieldHeight,
	                    child: isVeryNarrow
	                        ? ElevatedButton(
	                            onPressed: () => _barkodAraVeEkle(),
	                            style: ElevatedButton.styleFrom(
	                              backgroundColor: const Color(0xFF1E88E5),
	                              foregroundColor: Colors.white,
	                              padding: EdgeInsets.zero,
	                              minimumSize: const Size(48, 44),
	                              shape: RoundedRectangleBorder(
	                                borderRadius: BorderRadius.circular(8),
	                              ),
	                            ),
	                            child: const Icon(Icons.search, size: 20),
	                          )
	                        : ElevatedButton.icon(
	                            onPressed: () => _barkodAraVeEkle(),
	                            icon: const Icon(Icons.search, size: 20),
	                            label: Text(
	                              tr('retail.find'),
	                              style: const TextStyle(
	                                fontWeight: FontWeight.w600,
	                                fontSize: 15,
	                              ),
	                            ),
	                            style: ElevatedButton.styleFrom(
	                              backgroundColor: const Color(0xFF1E88E5),
	                              foregroundColor: Colors.white,
	                              padding: const EdgeInsets.symmetric(
	                                horizontal: 20,
	                                vertical: 14,
	                              ),
	                              shape: RoundedRectangleBorder(
	                                borderRadius: BorderRadius.circular(8),
	                              ),
	                            ),
	                          ),
	                  ),
	                ],
	              );

	              if (!isNarrow) {
	                return Row(
	                  crossAxisAlignment: CrossAxisAlignment.end,
	                  children: [
	                    quantitySection,
	                    const SizedBox(width: 24),
	                    Expanded(child: barcodeSection),
	                  ],
	                );
	              }

	              if (!isVeryNarrow) {
	                return Column(
	                  crossAxisAlignment: CrossAxisAlignment.stretch,
	                  children: [
	                    quantitySection,
	                    const SizedBox(height: 12),
	                    barcodeSection,
	                  ],
	                );
	              }

	              return Column(
	                crossAxisAlignment: CrossAxisAlignment.stretch,
	                children: [
	                  Row(
	                    children: [
	                      Text(
	                        tr('retail.quantity'),
	                        style: TextStyle(
	                          fontSize: 12,
	                          fontWeight: FontWeight.w500,
	                          color: Colors.grey.shade600,
	                        ),
	                      ),
	                      const SizedBox(width: 4),
	                      _buildShortcutBadge('F1'),
	                    ],
	                  ),
	                  const SizedBox(height: 6),
	                  Row(
	                    crossAxisAlignment: CrossAxisAlignment.end,
	                    children: [
	                      SizedBox(
	                        width: 56,
	                        height: fieldHeight,
	                        child: TextField(
	                          controller: _miktarController,
	                          focusNode: _miktarFocusNode,
	                          onSubmitted: (_) =>
	                              _barkodFocusNode.requestFocus(),
	                          textAlign: TextAlign.center,
	                          keyboardType: TextInputType.number,
	                          style: const TextStyle(
	                            fontSize: 16,
	                            fontWeight: FontWeight.w600,
	                          ),
	                          decoration: InputDecoration(
	                            contentPadding: const EdgeInsets.symmetric(
	                              horizontal: 8,
	                            ),
	                            border: OutlineInputBorder(
	                              borderRadius: BorderRadius.circular(8),
	                              borderSide: BorderSide(
	                                color: Colors.grey.shade300,
	                              ),
	                            ),
	                            enabledBorder: OutlineInputBorder(
	                              borderRadius: BorderRadius.circular(8),
	                              borderSide: BorderSide(
	                                color: Colors.grey.shade300,
	                              ),
	                            ),
	                          ),
	                        ),
	                      ),
	                      const SizedBox(width: 8),
	                      _buildSmallButton(
	                        icon: Icons.add,
	                        label: tr('retail.add'),
	                        onPressed: () => _barkodAraVeEkle(),
	                        iconOnly: true,
	                        height: fieldHeight,
	                      ),
	                      const SizedBox(width: 12),
	                      Expanded(child: barcodeSection),
	                    ],
	                  ),
	                ],
	              );
	            },
	          ),
	          if (!collapseSecondRow) ...[
	            SizedBox(height: isPhoneNarrow ? 12 : 16),
	            // İkinci satır: Fiyat grubu, Depo, Tarih, Açıklama, Fiş Yazdır
	            LayoutBuilder(
	              builder: (context, constraints) {
	              final isTablet = ResponsiveYardimcisi.tabletMi(context);
	              final isCompact = constraints.maxWidth < 900;
	              final bool isPhone = !isTablet && constraints.maxWidth < 520;
	
	              final labelFontSize = isTablet || isPhone ? 11.0 : 12.0;
	              final fieldFontSize = isTablet || isPhone ? 12.0 : 13.0;
	              final fieldHeight = (isTablet || isPhone) ? 34.0 : 36.0;
	              final priceGroupButtonSize = isTablet ? 28.0 : 32.0;
	              final priceGroupButtonFontSize = isTablet ? 11.0 : 12.0;
	              final allowFlexibleFields = (isTablet && isCompact) || isPhone;

	              final priceGroup = Column(
	                crossAxisAlignment: CrossAxisAlignment.start,
	                children: [
	                  Text(
	                    tr('retail.price_group'),
	                    style: TextStyle(
	                      fontSize: labelFontSize,
	                      fontWeight: FontWeight.w500,
	                      color: Colors.grey.shade600,
	                    ),
	                  ),
	                  const SizedBox(height: 4),
	                  Row(
	                    children: [
	                      _buildPriceGroupButton(
	                        1,
	                        size: priceGroupButtonSize,
	                        fontSize: priceGroupButtonFontSize,
	                      ),
	                      const SizedBox(width: 4),
	                      _buildPriceGroupButton(
	                        2,
	                        size: priceGroupButtonSize,
	                        fontSize: priceGroupButtonFontSize,
	                      ),
	                      const SizedBox(width: 4),
	                      _buildPriceGroupButton(
	                        3,
	                        size: priceGroupButtonSize,
	                        fontSize: priceGroupButtonFontSize,
	                      ),
	                    ],
	                  ),
	                ],
	              );

	              final warehouse = Column(
	                crossAxisAlignment: CrossAxisAlignment.start,
	                children: [
	                  Text(
	                    tr('retail.warehouse'),
	                    style: TextStyle(
	                      fontSize: labelFontSize,
	                      fontWeight: FontWeight.w500,
	                      color: Colors.grey.shade600,
	                    ),
	                  ),
	                  const SizedBox(height: 4),
	                  Container(
	                    width: allowFlexibleFields ? null : 220,
	                    height: fieldHeight,
	                    padding: EdgeInsets.symmetric(horizontal: isTablet ? 10 : 12),
	                    decoration: BoxDecoration(
	                      color: Colors.white,
	                      borderRadius: BorderRadius.circular(6),
	                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: InkWell(
                      mouseCursor: WidgetStateMouseCursor.clickable,
                      onTap: _selectWarehouses,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
	                              _selectedDepoIds.isEmpty
	                                  ? tr("retail.select_warehouse")
	                                  : _selectedDepoIds.length == 1
	                                      ? _depolar
	                                            .firstWhere(
                                              (d) =>
                                                  d.id ==
                                                  _selectedDepoIds.first,
                                              orElse: () => _depolar.first,
                                            )
                                            .ad
	                                      : "${_selectedDepoIds.length} ${tr("retail.warehouses_selected")}",
	                              style: TextStyle(
	                                fontSize: fieldFontSize,
	                                fontWeight: FontWeight.w500,
	                                color: Color(0xFF333333),
	                              ),
	                              overflow: TextOverflow.ellipsis,
	                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );

	              final date = Column(
	                crossAxisAlignment: CrossAxisAlignment.start,
	                children: [
	                  Text(
	                    tr('common.date'),
	                    style: TextStyle(
	                      fontSize: labelFontSize,
	                      fontWeight: FontWeight.w500,
	                      color: Colors.grey.shade600,
	                    ),
	                  ),
	                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _selectDate,
                    mouseCursor: SystemMouseCursors.click,
                    borderRadius: BorderRadius.circular(6),
	                    child: Container(
	                      width: allowFlexibleFields ? null : 180,
	                      height: fieldHeight,
	                      padding: EdgeInsets.symmetric(horizontal: isTablet ? 10 : 12),
	                      decoration: BoxDecoration(
	                        color: Colors.white,
	                        borderRadius: BorderRadius.circular(6),
	                        border: Border.all(color: Colors.grey.shade300),
	                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
	                          Expanded(
	                            child: Text(
	                              DateFormat('dd.MM.yyyy').format(_selectedDate),
	                              style: TextStyle(
	                                fontSize: fieldFontSize,
	                                fontWeight: FontWeight.w500,
	                                color: Color(0xFF333333),
	                              ),
	                              maxLines: 1,
	                              overflow: TextOverflow.ellipsis,
	                            ),
	                          ),
	                          IconButton(
	                            padding: EdgeInsets.zero,
	                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.clear,
                              size: 16,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(() => _selectedDate = DateTime.now());
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );

	              final description = Column(
	                crossAxisAlignment: CrossAxisAlignment.start,
	                children: [
	                  Text(
	                    tr('retail.description'),
	                    style: TextStyle(
	                      fontSize: labelFontSize,
	                      fontWeight: FontWeight.w500,
	                      color: Colors.grey.shade600,
	                    ),
	                  ),
	                  const SizedBox(height: 4),
	                  SizedBox(
	                    height: fieldHeight,
	                    child: TextField(
	                      controller: _aciklamaController,
	                      focusNode: _aciklamaFocusNode,
	                      style: TextStyle(fontSize: fieldFontSize),
	                      decoration: InputDecoration(
	                        contentPadding: const EdgeInsets.symmetric(
	                          horizontal: 12,
	                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                ],
              );

	              final printReceipt = Column(
	                crossAxisAlignment: CrossAxisAlignment.start,
	                children: [
	                  Text(
	                    tr('retail.print_receipt'),
	                    style: TextStyle(
	                      fontSize: labelFontSize,
	                      fontWeight: FontWeight.w500,
	                      color: Colors.grey.shade600,
	                    ),
	                  ),
	                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildToggleSwitch(),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.settings,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () => MesajYardimcisi.bilgiGoster(
                            context,
                            tr('common.feature_coming_soon'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );

	              if (isCompact) {
	                if (isTablet) {
	                  final gap = constraints.maxWidth < 760 ? 8.0 : 12.0;
	                  return Row(
	                    crossAxisAlignment: CrossAxisAlignment.end,
	                    children: [
	                      priceGroup,
	                      SizedBox(width: gap),
	                      Expanded(flex: 3, child: warehouse),
	                      SizedBox(width: gap),
	                      Expanded(flex: 3, child: date),
	                      SizedBox(width: gap),
	                      printReceipt,
	                      SizedBox(width: gap),
	                      Expanded(flex: 4, child: description),
	                    ],
	                  );
	                }

	                if (isPhone) {
	                  const gap = 12.0;
	                  return Column(
	                    crossAxisAlignment: CrossAxisAlignment.stretch,
	                    children: [
	                      Row(
	                        crossAxisAlignment: CrossAxisAlignment.end,
	                        children: [
	                          Expanded(flex: 3, child: warehouse),
	                          const SizedBox(width: gap),
	                          Expanded(flex: 2, child: date),
	                        ],
	                      ),
	                      const SizedBox(height: gap),
	                      Row(
	                        crossAxisAlignment: CrossAxisAlignment.end,
	                        children: [
	                          priceGroup,
	                          const Spacer(),
	                          printReceipt,
	                        ],
	                      ),
	                      const SizedBox(height: gap),
	                      description,
	                    ],
	                  );
	                }

	                return Column(
	                  crossAxisAlignment: CrossAxisAlignment.stretch,
	                  children: [
	                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        priceGroup,
                        warehouse,
                        date,
                        printReceipt,
                      ],
                    ),
                    const SizedBox(height: 12),
                    description,
                  ],
                );
	              }

	              final wideGap = isTablet ? 16.0 : 24.0;
	              final trailingGap = isTablet ? 12.0 : 16.0;
	              return Row(
	                crossAxisAlignment: CrossAxisAlignment.end,
	                children: [
	                  priceGroup,
	                  SizedBox(width: wideGap),
	                  warehouse,
	                  SizedBox(width: wideGap),
	                  date,
	                  SizedBox(width: wideGap),
	                  Expanded(child: description),
	                  SizedBox(width: trailingGap),
	                  printReceipt,
	                ],
	              );
	            },
	          ),
	          ],
	        ],
	      ),
	    );
	  }

  Widget _buildKeyboardSummaryBar() {
    final rawDiscountAmount = _sepetItems.fold<double>(
      0.0,
      (sum, item) => sum + ((item.birimFiyati * item.miktar) - item.toplamFiyat),
    );
    final discountAmount = rawDiscountAmount > 0 ? rawDiscountAmount : 0.0;
    final bool showDiscountLine =
        _faturaIskontoOrani > 0 && discountAmount > 0.000001;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${tr('retail.row_count')}: $_satirSayisi',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          Text(
            tr('retail.grand_total'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          if (showDiscountLine) ...[
            const SizedBox(width: 10),
            Text(
              '${tr('common.discount')}: -${_formatTutar(discountAmount)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFFEA4335),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Text(
            _formatTutar(_genelToplam),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _selectedParaBirimi,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

	  Widget _buildPriceGroupButton(
	    int group, {
	    double size = 32,
	    double fontSize = 12,
	  }) {
	    final isSelected = _selectedFiyatGrubu == group;
	    return InkWell(
	      mouseCursor: WidgetStateMouseCursor.clickable,
	      onTap: () => setState(() => _selectedFiyatGrubu = group),
	      child: Container(
	        width: size,
	        height: size,
	        decoration: BoxDecoration(
	          color: isSelected ? const Color(0xFF1E88E5) : Colors.white,
	          borderRadius: BorderRadius.circular(6),
	          border: Border.all(
            color: isSelected ? const Color(0xFF1E88E5) : Colors.grey.shade300,
          ),
        ),
	        child: Center(
	          child: Text(
	            '[$group]',
	            style: TextStyle(
	              fontSize: fontSize,
	              fontWeight: FontWeight.w600,
	              color: isSelected ? Colors.white : Colors.grey.shade700,
	            ),
	          ),
	        ),
	      ),
	    );
	  }

  Widget _buildToggleSwitch() {
    return MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
      onTap: () => setState(() => _fisYazdir = !_fisYazdir),
      child: Container(
        width: 60,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: _fisYazdir ? const Color(0xFF4CAF50) : Colors.grey.shade300,
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              left: _fisYazdir ? 32 : 4,
              top: 4,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: _fisYazdir ? 8 : null,
              right: _fisYazdir ? null : 8,
              top: 7,
              child: Text(
                _fisYazdir ? tr('common.on') : tr('common.off'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _fisYazdir ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildSmallButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool iconOnly = false,
    double? height,
  }) {
    if (iconOnly) {
      final buttonSize = height ?? 44.0;
      return SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
            side: BorderSide(color: Colors.grey.shade300),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Icon(icon, size: 18),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade700,
        side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildProductTable({bool compactMode = false}) {
    final isTablet = ResponsiveYardimcisi.tabletMi(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final tightMode = isTablet && isLandscape && keyboardVisible;

    return Focus(
      focusNode: _tableFocusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        if (_editingIndex != null || _editingField != null) {
          return KeyEventResult.ignored;
        }

        if (event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace) {
          _seciliyiSil();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        margin: tightMode
            ? const EdgeInsets.fromLTRB(16, 8, 16, 8)
            : const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Tablo başlığı
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: tightMode ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: compactMode
                  ? Row(
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 18,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr('retail.basket'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            _satirSayisi.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildTableHeader(tr('retail.table.code'), flex: 1),
                        _buildTableHeader(tr('retail.table.barcode'), flex: 2),
                        _buildTableHeader(tr('retail.table.name'), flex: 3),
                        _buildTableHeader(
                          tr('retail.table.unit_price'),
                          flex: 1,
                          align: TextAlign.right,
                        ),
                        _buildTableHeader(
                          tr('retail.table.discount'),
                          flex: 1,
                          align: TextAlign.center,
                        ),
                        _buildTableHeader(
                          tr('retail.table.quantity'),
                          flex: 1,
                          align: TextAlign.right,
                          padding: const EdgeInsets.only(right: 6),
                        ),
                        _buildTableHeader(
                          tr('retail.table.unit'),
                          flex: 1,
                          align: TextAlign.left,
                          padding: const EdgeInsets.only(left: 6),
                        ),
                        _buildTableHeader(
                          tr('retail.table.total_price'),
                          flex: 2,
                          align: TextAlign.right,
                        ),
                      ],
                    ),
            ),
            // Tablo içeriği
            if (compactMode)
              (_sepetItems.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
                      child: Center(
                        child: Text(
                          tr('common.no_records_found'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _sepetItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildCompactBasketItemCard(
                          item: _sepetItems[index],
                          index: index,
                          tightMode: tightMode,
                        );
                      },
                    ))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _sepetItems.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final item = _sepetItems[index];
                    final isSelected = _selectedRowIndex == index;
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      hitTestBehavior: HitTestBehavior.deferToChild,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() => _selectedRowIndex = index);
                          _tableFocusNode.requestFocus();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOut,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: tightMode ? 10 : 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFE8F0FE)
                                : Colors.white,
                            border: Border(
                              left: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF1E88E5)
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildTableCell(item.kodNo, flex: 1),
                              _buildTableCell(item.barkodNo, flex: 2),
                              _buildTableCell(item.adi, flex: 3),
                              _buildEditableTableCell(
                                index: index,
                                field: 'price',
                                value: item.birimFiyati,
                                flex: 1,
                                align: TextAlign.right,
                                onSubmitted: (val) {
                                  final newPrice = val < 0 ? 0.0 : val;
                                  final current = _sepetItems[index];
                                  final newTotal = (newPrice * current.miktar) *
                                      (1 - (current.iskontoOrani / 100));
                                  _sepetItems[index] = current.copyWith(
                                    birimFiyati: newPrice,
                                    toplamFiyat: newTotal,
                                  );
                                },
                              ),
                              _buildEditableTableCell(
                                index: index,
                                field: 'discount',
                                value: item.iskontoOrani,
                                flex: 1,
                                align: TextAlign.center,
                                onSubmitted: (val) {
                                  final newDiscount =
                                      val.clamp(0, 100).toDouble();
                                  final current = _sepetItems[index];
                                  final newTotal =
                                      (current.birimFiyati * current.miktar) *
                                          (1 - (newDiscount / 100));
                                  _sepetItems[index] = current.copyWith(
                                    iskontoOrani: newDiscount,
                                    toplamFiyat: newTotal,
                                  );
                                },
                              ),
                              _buildEditableTableCell(
                                index: index,
                                field: 'quantity',
                                value: item.miktar,
                                flex: 1,
                                align: TextAlign.right,
                                padding: const EdgeInsets.only(right: 6),
                                onSubmitted: (val) {
                                  final newQty = val;
                                  if (newQty <= 0) {
                                    MesajYardimcisi.hataGoster(
                                      context,
                                      tr('retail.error.invalid_quantity'),
                                    );
                                    return;
                                  }
                                  final current = _sepetItems[index];
                                  final newTotal =
                                      (current.birimFiyati * newQty) *
                                          (1 - (current.iskontoOrani / 100));
                                  _sepetItems[index] = current.copyWith(
                                    miktar: newQty,
                                    toplamFiyat: newTotal,
                                  );
                                },
                              ),
                              _buildTableCell(
                                item.olcu,
                                flex: 1,
                                align: TextAlign.left,
                                padding: const EdgeInsets.only(left: 6),
                              ),
                              _buildTableCell(
                                '${_formatTutar(item.toplamFiyat)} ${item.paraBirimi}',
                                flex: 2,
                                align: TextAlign.right,
                                isBold: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactBasketItemCard({
    required _PerakendeSepetItem item,
    required int index,
    required bool tightMode,
  }) {
    final bool isSelected = _selectedRowIndex == index;
    final String totalText =
        '${_formatTutar(item.toplamFiyat)} ${item.paraBirimi}';

    final String depoAdiRaw = (item.depoAdi ?? '').trim();
    final String? depoAdi = depoAdiRaw.isEmpty ? null : depoAdiRaw;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      hitTestBehavior: HitTestBehavior.deferToChild,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _selectedRowIndex = index);
          _tableFocusNode.requestFocus();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: EdgeInsets.all(tightMode ? 12 : 14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2C3E50).withValues(alpha: 0.04)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2C3E50).withValues(alpha: 0.28)
                  : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF2C3E50).withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: isSelected ? 12 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.adi,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        totalText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2C3E50),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.qr_code_2_outlined,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.barkodNo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      item.kodNo,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              if (depoAdi != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        depoAdi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildCompactEditableField(
                    index: index,
                    field: 'quantity',
                    label: tr('retail.table.quantity'),
                    value: item.miktar,
                    suffix: item.olcu,
                    onSubmitted: (val) {
                      final newQty = val;
                      if (newQty <= 0) {
                        MesajYardimcisi.hataGoster(
                          context,
                          tr('retail.error.invalid_quantity'),
                        );
                        return;
                      }
                      final current = _sepetItems[index];
                      final newTotal = (current.birimFiyati * newQty) *
                          (1 - (current.iskontoOrani / 100));
                      _sepetItems[index] = current.copyWith(
                        miktar: newQty,
                        toplamFiyat: newTotal,
                      );
                    },
                  ),
                  _buildCompactEditableField(
                    index: index,
                    field: 'price',
                    label: tr('retail.table.unit_price'),
                    value: item.birimFiyati,
                    onSubmitted: (val) {
                      final newPrice = val < 0 ? 0.0 : val;
                      final current = _sepetItems[index];
                      final newTotal = (newPrice * current.miktar) *
                          (1 - (current.iskontoOrani / 100));
                      _sepetItems[index] = current.copyWith(
                        birimFiyati: newPrice,
                        toplamFiyat: newTotal,
                      );
                    },
                  ),
                  _buildCompactEditableField(
                    index: index,
                    field: 'discount',
                    label: tr('retail.table.discount'),
                    value: item.iskontoOrani,
                    onSubmitted: (val) {
                      final newDiscount = val.clamp(0, 100).toDouble();
                      final current = _sepetItems[index];
                      final newTotal = (current.birimFiyati * current.miktar) *
                          (1 - (newDiscount / 100));
                      _sepetItems[index] = current.copyWith(
                        iskontoOrani: newDiscount,
                        toplamFiyat: newTotal,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactEditableField({
    required int index,
    required String field,
    required String label,
    required double value,
    required void Function(double) onSubmitted,
    String? suffix,
  }) {
    final bool isEditing = _editingIndex == index && _editingField == field;

    int decimals = 2;
    if (field == 'price') {
      decimals = _genelAyarlar.fiyatOndalik;
    } else if (field == 'quantity') {
      decimals = _genelAyarlar.miktarOndalik;
    }

    final String formattedValue = switch (field) {
      'price' => _formatTutar(value),
      'quantity' => _formatMiktar(value),
      _ => _formatTutar(value, decimalDigits: 2),
    };

    final Widget valueWidget = isEditing
        ? _InlineNumberEditor(
            value: value,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: decimals,
            onBindNumericKeypad: _bindNumericKeypadExternalTarget,
            onSubmitted: (val) {
              onSubmitted(val);
              if (!mounted) return;
              setState(() {
                _editingIndex = null;
                _editingField = null;
              });
              _clearNumericKeypadExternalTarget();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _tableFocusNode.requestFocus();
              });
            },
          )
        : InkWell(
            onTap: () {
              setState(() {
                _selectedRowIndex = index;
                _editingIndex = index;
                _editingField = field;
              });
              _tableFocusNode.requestFocus();
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit,
                    size: 14,
                    color: Colors.grey.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formattedValue,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  if (suffix != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      suffix,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          if (isEditing && suffix != null && field != 'discount')
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                valueWidget,
                const SizedBox(width: 8),
                Text(
                  suffix,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            )
          else
            valueWidget,
        ],
      ),
    );
  }

  Widget _buildEditableTableCell({
    required int index,
    required String field,
    required double value,
    required void Function(double) onSubmitted,
    int flex = 1,
    TextAlign align = TextAlign.center,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    final isEditing = _editingIndex == index && _editingField == field;

    int decimals = 2;
    if (field == 'price') {
      decimals = _genelAyarlar.fiyatOndalik;
    } else if (field == 'quantity') {
      decimals = _genelAyarlar.miktarOndalik;
    }

    final Alignment alignment = switch (align) {
      TextAlign.right => Alignment.centerRight,
      TextAlign.center => Alignment.center,
      _ => Alignment.centerLeft,
    };

    final String formattedValue = switch (field) {
      'price' => _formatTutar(value),
      'quantity' => _formatMiktar(value),
      _ => _formatTutar(value, decimalDigits: 2),
    };

    if (isEditing) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: padding,
          child: Align(
            alignment: alignment,
            child: _InlineNumberEditor(
              value: value,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
              decimalDigits: decimals,
              textAlign: align,
              onBindNumericKeypad: _bindNumericKeypadExternalTarget,
              onSubmitted: (val) {
                onSubmitted(val);
                if (!mounted) return;
                setState(() {
                  _editingIndex = null;
                  _editingField = null;
                });
                _clearNumericKeypadExternalTarget();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _tableFocusNode.requestFocus();
                });
              },
            ),
          ),
        ),
      );
    }

    return Expanded(
      flex: flex,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedRowIndex = index;
            _editingIndex = index;
            _editingField = field;
          });
          _tableFocusNode.requestFocus();
        },
        child: Padding(
          padding: padding,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Align(
              alignment: alignment,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.edit,
                    size: 12,
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formattedValue,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

		  Widget _buildTableHeader(
		    String text, {
		    int flex = 1,
		    TextAlign align = TextAlign.left,
        EdgeInsetsGeometry padding = EdgeInsets.zero,
	  }) {
	    final isTablet = ResponsiveYardimcisi.tabletMi(context);
	    final alignment = switch (align) {
	      TextAlign.right => Alignment.centerRight,
	      TextAlign.center => Alignment.center,
	      _ => Alignment.centerLeft,
	    };
	    return Expanded(
	      flex: flex,
	      child: Padding(
	        padding: padding,
	        child: Align(
	          alignment: alignment,
	          child: FittedBox(
	            fit: BoxFit.scaleDown,
	            alignment: alignment,
	            child: Text(
	              text,
	              textAlign: align,
	              style: TextStyle(
	                fontSize: isTablet ? 10 : 11,
	                fontWeight: FontWeight.w700,
	                color: Colors.grey.shade700,
	              ),
	              maxLines: 1,
	              softWrap: false,
	              overflow: TextOverflow.visible,
	            ),
	          ),
	        ),
	      ),
	    );
	  }

  Widget _buildTableCell(
    String text, {
    int flex = 1,
    TextAlign align = TextAlign.left,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    bool isBold = false,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: padding,
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: const Color(0xFF333333),
          ),
        ),
      ),
    );
  }

	  Widget _buildBottomArea() {
	    final nakitButonlari = _nakitButonDegerleri();

	    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
	      child: LayoutBuilder(
		        builder: (context, constraints) {
		          final isTablet = ResponsiveYardimcisi.tabletMi(context);
			          final isLandscape =
			              MediaQuery.orientationOf(context) == Orientation.landscape;
			          final forceRowLayout = isTablet && isLandscape;
			          final isNarrow = constraints.maxWidth < 980 && !forceRowLayout;
			          final usePortraitTabletSplitLayout = isTablet && !isLandscape;
			          final moneyButtonGap = isTablet ? 3.0 : 4.0;
			          final sectionGap = isTablet ? 10.0 : 12.0;
			          final aboveButtonsGap = isTablet ? 4.0 : 6.0;

			          final rowCountText = Text(
			            '${tr('retail.row_count')}: $_satirSayisi',
			            style: TextStyle(
			              fontSize: 11,
			              fontWeight: FontWeight.w600,
			              color: Colors.grey.shade600,
			            ),
			          );

			          final paymentEntry = Column(
			            mainAxisSize: MainAxisSize.min,
			            children: [
			              Row(
			                mainAxisSize: MainAxisSize.min,
			                children: [
			                  _buildShortcutBadge('F2'),
			                  const SizedBox(width: 4),
			                  Text(
			                    tr('retail.payment_entry'),
			                    style: const TextStyle(
			                      fontSize: 10,
			                      fontWeight: FontWeight.w500,
			                      color: Colors.grey,
			                    ),
			                  ),
			                ],
			              ),
			              const SizedBox(height: 4),
			              SizedBox(
			                width: 85,
			                height: 36,
			                child: TextField(
			                  controller: _odenenTutarController,
			                  focusNode: _odenenTutarFocusNode,
			                  textAlign: TextAlign.center,
			                  keyboardType: const TextInputType.numberWithOptions(
			                    decimal: true,
			                  ),
			                  style: const TextStyle(
			                    fontSize: 14,
			                    fontWeight: FontWeight.w600,
			                    color: Color(0xFF333333),
			                  ),
			                  decoration: InputDecoration(
			                    contentPadding: EdgeInsets.zero,
			                    filled: true,
			                    fillColor: Colors.white,
			                    enabledBorder: OutlineInputBorder(
			                      borderRadius: BorderRadius.circular(4),
			                      borderSide: BorderSide(color: Colors.grey.shade300),
			                    ),
			                    focusedBorder: OutlineInputBorder(
			                      borderRadius: BorderRadius.circular(4),
			                      borderSide: const BorderSide(
			                        color: Color(0xFF1E88E5),
			                        width: 1.5,
			                      ),
			                    ),
			                  ),
			                  onChanged: (val) {
			                    setState(() {
			                      _odenenTutar = FormatYardimcisi.parseDouble(
			                        val,
			                        binlik: _genelAyarlar.binlikAyiraci,
			                        ondalik: _genelAyarlar.ondalikAyiraci,
			                      );
			                    });
			                  },
			                ),
			              ),
			              const SizedBox(height: 4),
			              SizedBox(height: isTablet ? 12 : 24),
			            ],
			          );

			          final changeCard = Container(
			            padding: EdgeInsets.fromLTRB(
			              24,
			              12,
			              24,
			              isTablet ? 8 : 12,
			            ),
			            decoration: BoxDecoration(
			              gradient: const LinearGradient(
			                colors: [Color(0xFF26C6DA), Color(0xFF00ACC1)],
			                begin: Alignment.topLeft,
			                end: Alignment.bottomRight,
			              ),
			              borderRadius: BorderRadius.circular(24),
			            ),
			            child: Column(
			              children: [
			                Text(
			                  tr('retail.change'),
			                  style: const TextStyle(
			                    fontSize: 11,
			                    fontWeight: FontWeight.w500,
			                    color: Colors.white70,
			                  ),
			                ),
			                if (isTablet) const SizedBox(height: 2),
			                Text(
			                  _formatParaBirimiGosterimi(_paraUstu),
			                  style: TextStyle(
			                    fontSize: isTablet ? 17 : 18,
			                    fontWeight: FontWeight.w700,
			                    color: Colors.white,
			                  ),
			                ),
			              ],
			            ),
			          );

			          final leftControls = Column(
			            crossAxisAlignment: CrossAxisAlignment.start,
			            mainAxisSize: MainAxisSize.min,
			            children: [
			              rowCountText,
			              SizedBox(height: aboveButtonsGap),
			              if (usePortraitTabletSplitLayout)
			                SingleChildScrollView(
			                  scrollDirection: Axis.horizontal,
			                  child: Column(
			                    mainAxisSize: MainAxisSize.min,
			                    crossAxisAlignment: CrossAxisAlignment.start,
			                    children: [
			                      Row(
			                        mainAxisSize: MainAxisSize.min,
			                        crossAxisAlignment: CrossAxisAlignment.end,
			                        children: [
			                          _buildMoneyButton(nakitButonlari[0]),
			                          SizedBox(width: moneyButtonGap),
			                          _buildMoneyButton(nakitButonlari[1]),
			                          SizedBox(width: moneyButtonGap),
			                          _buildMoneyButton(nakitButonlari[2]),
			                        ],
			                      ),
			                      SizedBox(height: isTablet ? 6 : 8),
			                      Row(
			                        mainAxisSize: MainAxisSize.min,
			                        crossAxisAlignment: CrossAxisAlignment.end,
			                        children: [
			                          _buildMoneyButton(nakitButonlari[3]),
			                          SizedBox(width: moneyButtonGap),
			                          _buildMoneyButton(nakitButonlari[4]),
			                          SizedBox(width: moneyButtonGap),
			                          _buildMoneyButton(nakitButonlari[5]),
			                          SizedBox(width: sectionGap),
			                          paymentEntry,
			                          SizedBox(width: sectionGap),
			                          changeCard,
			                        ],
			                      ),
			                    ],
			                  ),
			                )
			              else
			                SingleChildScrollView(
			                  scrollDirection: Axis.horizontal,
			                  child: Row(
			                    mainAxisSize: MainAxisSize.min,
			                    crossAxisAlignment: CrossAxisAlignment.end,
			                    children: [
			                      // Para butonları
			                      _buildMoneyButton(nakitButonlari[0]),
			                      SizedBox(width: moneyButtonGap),
			                      _buildMoneyButton(nakitButonlari[1]),
			                      SizedBox(width: moneyButtonGap),
			                      _buildMoneyButton(nakitButonlari[2]),
			                      SizedBox(width: moneyButtonGap),
			                      _buildMoneyButton(nakitButonlari[3]),
			                      SizedBox(width: moneyButtonGap),
			                      _buildMoneyButton(nakitButonlari[4]),
			                      SizedBox(width: moneyButtonGap),
			                      _buildMoneyButton(nakitButonlari[5]),
			                      SizedBox(width: sectionGap),
			                      paymentEntry,
			                      SizedBox(width: sectionGap),
			                      changeCard,
			                    ],
			                  ),
			                ),
			            ],
			          );

          final rawDiscountAmount = _sepetItems.fold<double>(
            0.0,
            (sum, item) =>
                sum + ((item.birimFiyati * item.miktar) - item.toplamFiyat),
          );
          final discountAmount =
              rawDiscountAmount > 0 ? rawDiscountAmount : 0.0;
          final bool showDiscountLine =
              _faturaIskontoOrani > 0 && discountAmount > 0.000001;

          final grandTotal = Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tr('retail.grand_total'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              if (showDiscountLine)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${tr('common.discount')} (${_formatTutar(_faturaIskontoOrani, decimalDigits: 2)}${tr('common.symbol.percent')}):',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEA4335),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '-${_formatTutar(discountAmount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEA4335),
                        ),
                      ),
                    ],
                  ),
                ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTutar(_genelToplam),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _selectedParaBirimi,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

	          if (isNarrow && !usePortraitTabletSplitLayout) {
	            return Column(
	              crossAxisAlignment: CrossAxisAlignment.stretch,
	              children: [
	                leftControls,
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: grandTotal,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: leftControls),
              const SizedBox(width: 12),
              grandTotal,
            ],
          );
        },
      ),
    );
  }

  Widget _buildMoneyButton(int amount) {
    final individualChange = amount.toDouble() - _genelToplam;
    final showChange = individualChange > 0 && _sepetItems.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 50,
          height: 36,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _odenenTutar += amount.toDouble();
                _odenenTutarController.text = _formatTutar(
                  _odenenTutar,
                  decimalDigits: 2,
                );
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF333333),
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Text(
              '$amount',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 50,
          height: 24,
          decoration: BoxDecoration(
            color: showChange ? const Color(0xFFE1F5FE) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: showChange ? const Color(0xFFB3E5FC) : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            showChange ? _formatTutar(individualChange) : '',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0277BD),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightActionPanel({bool useQuickProductsSheet = false}) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              primary: false,
              padding: EdgeInsets.zero,
              children: [
                // Nakit Satış [F4]
                _buildActionButton(
                  label: tr('retail.cash_sale'),
                  shortcut: '[F4]',
                  color: const Color(0xFF4CAF50),
                  icon: Icons.monetization_on,
                  onPressed: () => _tamamlaSatisTekOdeme(odemeYeri: 'Kasa'),
                ),
                const SizedBox(height: 8),
                // Kredi Kartı [F6]
                _buildActionButton(
                  label: tr('retail.credit_card'),
                  shortcut: '[F6]',
                  color: const Color(0xFF26A69A),
                  icon: Icons.credit_card,
                  onPressed: () =>
                      _tamamlaSatisTekOdeme(odemeYeri: 'Kredi Kartı'),
                ),
                const SizedBox(height: 8),
                // Havale Satış [F5]
                _buildActionButton(
                  label: tr('retail.transfer_sale'),
                  shortcut: '[F5]',
                  color: const Color(0xFF1E88E5),
                  icon: Icons.account_balance,
                  onPressed: () => _tamamlaSatisTekOdeme(odemeYeri: 'Havale'),
                ),
                const SizedBox(height: 8),
                // Parçalı Ödeme [F7]
                _buildActionButton(
                  label: tr('retail.partial_payment'),
                  shortcut: '[F7]',
                  color: const Color(0xFFFF9800),
                  icon: Icons.pie_chart,
                  onPressed: _showPartialPaymentDialog,
                ),
                const SizedBox(height: 8),
                // Cari Satış [F8]
                _buildActionButton(
                  label: tr('retail.account_sale'),
                  shortcut: '[F8]',
                  color: Colors.grey.shade100,
                  textColor: Colors.grey.shade700,
                  icon: Icons.account_balance_wallet,
                  onPressed: _tamamlaCariSatis,
                  outlined: true,
                ),
                const SizedBox(height: 8),
                // İskonto Yap [F9]
                _buildActionButton(
                  label: tr('retail.apply_discount'),
                  shortcut: '[F9]',
                  color: Colors.grey.shade100,
                  textColor: Colors.grey.shade700,
                  icon: Icons.percent,
                  onPressed: _showInvoiceDiscountDialog,
                  outlined: true,
                ),
                const SizedBox(height: 8),
                // Tümünü Sil [F10]
                _buildActionButton(
                  label: tr('retail.delete_all'),
                  shortcut: '[F10]',
                  color: const Color(0xFFFFEBEE),
                  textColor: const Color(0xFFEA4335),
                  icon: Icons.delete_outline,
                  onPressed: _tumunuSil,
                  outlined: true,
                  borderColor: const Color(0xFFEA4335),
                ),
                const SizedBox(height: 8),
                // Seçiliyi Sil
                _buildActionButton(
                  label: tr('retail.delete_selected'),
                  shortcut: '[Del]',
                  color: Colors.grey.shade50,
                  textColor: Colors.grey.shade700,
                  onPressed: _seciliyiSil,
                  outlined: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Hızlı Ürünler [F11]
          _buildTextActionButton(
            label: tr('retail.quick_products'),
            shortcut: '[F11]',
            icon: Icons.bolt,
            onPressed: useQuickProductsSheet
                ? _openHizliUrunlerSheet
                : () => setState(() => _showHizliUrunler = !_showHizliUrunler),
          ),
          const SizedBox(height: 8),
          // Sayısal Klavye [F12]
          _buildTextActionButton(
            label: tr('retail.numeric_keyboard'),
            shortcut: '[F12]',
            icon: Icons.dialpad,
            onPressed: _toggleNumericKeypad,
          ),
          const SizedBox(height: 8),
          // Yazar Kasa [F3]
          _buildTextActionButton(
            label: tr('retail.cash_register'),
            shortcut: '[F3]',
            icon: Icons.point_of_sale,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const KasalarSayfasi()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required String shortcut,
    required Color color,
    Color? textColor,
    IconData? icon,
    required VoidCallback onPressed,
    bool outlined = false,
    Color? borderColor,
  }) {
    final effectiveTextColor = textColor ?? Colors.white;

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: effectiveTextColor,
                side: BorderSide(color: borderColor ?? Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (shortcut.isNotEmpty)
                    Text(
                      shortcut,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: effectiveTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: effectiveTextColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (shortcut.isNotEmpty)
                    Text(
                      shortcut,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: effectiveTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextActionButton({
    required String label,
    required String shortcut,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return FocusScope(
      canRequestFocus: false,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: color,
            foregroundColor: const Color(0xFF1E88E5),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (shortcut.isNotEmpty)
                Text(
                  shortcut,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF5F6368),
        ),
      ),
    );
  }

  Widget _buildHizliUrunlerSidePanel() {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: _PerakendeHizliUrunlerPaneli(
        hizliUrunler: _hizliUrunler,
        onSelect: _hizliUrunSecildi,
        onChanged: _loadHizliUrunler,
        onClose: () => setState(() => _showHizliUrunler = false),
      ),
    );
  }
}

class _InlineNumberEditor extends StatefulWidget {
  final double value;
  final void Function(double) onSubmitted;
  final String binlik;
  final String ondalik;
  final int decimalDigits;
  final TextAlign textAlign;
  final void Function({
    required TextEditingController controller,
    required FocusNode focusNode,
    required int decimalDigits,
    required String binlik,
    required String ondalik,
  })? onBindNumericKeypad;

  const _InlineNumberEditor({
    required this.value,
    required this.onSubmitted,
    required this.binlik,
    required this.ondalik,
    required this.decimalDigits,
    this.textAlign = TextAlign.right,
    this.onBindNumericKeypad,
  });

  @override
  State<_InlineNumberEditor> createState() => _InlineNumberEditorState();
}

class _InlineNumberEditorState extends State<_InlineNumberEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: FormatYardimcisi.sayiFormatlaOndalikli(
        widget.value,
        binlik: widget.binlik,
        ondalik: widget.ondalik,
        decimalDigits: widget.decimalDigits,
      ),
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    _focusNode.requestFocus();
    widget.onBindNumericKeypad?.call(
      controller: _controller,
      focusNode: _focusNode,
      decimalDigits: widget.decimalDigits,
      binlik: widget.binlik,
      ondalik: widget.ondalik,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _save();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final newValue = _parseFlexibleDouble(_controller.text);
    widget.onSubmitted(newValue);
  }

  double _parseFlexibleDouble(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return 0.0;

    final hasDot = raw.contains('.');
    final hasComma = raw.contains(',');

    String clean;
    if (hasDot && hasComma) {
      final lastDot = raw.lastIndexOf('.');
      final lastComma = raw.lastIndexOf(',');
      final decimalSep = lastDot > lastComma ? '.' : ',';
      final thousandSep = decimalSep == '.' ? ',' : '.';
      clean = raw.replaceAll(thousandSep, '').replaceAll(decimalSep, '.');
      return double.tryParse(clean) ?? 0.0;
    }

    if (hasDot || hasComma) {
      final sep = hasDot ? '.' : ',';
      final sepCount = raw.split(sep).length - 1;
      if (sepCount > 1) {
        clean = raw.replaceAll(sep, '');
        return double.tryParse(clean) ?? 0.0;
      }

      final idx = raw.lastIndexOf(sep);
      final digitsAfter = raw.length - idx - 1;
      final treatAsDecimal =
          digitsAfter > 0 && digitsAfter <= widget.decimalDigits;

      if (treatAsDecimal) {
        clean = raw.replaceAll(sep, '.');
        return double.tryParse(clean) ?? 0.0;
      }
    }

    return FormatYardimcisi.parseDouble(
      raw,
      binlik: widget.binlik,
      ondalik: widget.ondalik,
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2C3E50);
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          _save();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        width: 92,
        height: 40,
        child: TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.none,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: widget.textAlign,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: primaryColor),
            ),
          ),
          inputFormatters: [
            CurrencyInputFormatter(
              binlik: widget.binlik,
              ondalik: widget.ondalik,
              maxDecimalDigits: widget.decimalDigits,
            ),
            LengthLimitingTextInputFormatter(20),
          ],
          onFieldSubmitted: (_) => _save(),
        ),
      ),
    );
  }
}

class _FloatingNumericKeypad extends StatelessWidget {
  final double width;
  final double height;
  final String decimalSeparator;
  final bool lettersMode;
  final VoidCallback onToggleLettersMode;
  final VoidCallback onClose;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueChanged<String> onInsert;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const _FloatingNumericKeypad({
    required this.width,
    required this.height,
    required this.decimalSeparator,
    required this.lettersMode,
    required this.onToggleLettersMode,
    required this.onClose,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onInsert,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = Colors.grey.shade200;
    final titleColor = const Color(0xFF202124);

    Widget buildKey({
      required Widget child,
      required VoidCallback onPressed,
      Color? background,
      Color? foreground,
      BorderSide? side,
    }) {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: background ?? Colors.white,
            foregroundColor: foreground ?? const Color(0xFF202124),
            side: side ?? BorderSide(color: outline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.zero,
          ),
          child: child,
        ),
      );
    }

    final digitStyle = const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      height: 1,
    );

    final numericKeys = <Widget>[
      buildKey(child: Text('7', style: digitStyle), onPressed: () => onInsert('7')),
      buildKey(child: Text('8', style: digitStyle), onPressed: () => onInsert('8')),
      buildKey(child: Text('9', style: digitStyle), onPressed: () => onInsert('9')),
      buildKey(child: Text('4', style: digitStyle), onPressed: () => onInsert('4')),
      buildKey(child: Text('5', style: digitStyle), onPressed: () => onInsert('5')),
      buildKey(child: Text('6', style: digitStyle), onPressed: () => onInsert('6')),
      buildKey(child: Text('1', style: digitStyle), onPressed: () => onInsert('1')),
      buildKey(child: Text('2', style: digitStyle), onPressed: () => onInsert('2')),
      buildKey(child: Text('3', style: digitStyle), onPressed: () => onInsert('3')),
      buildKey(
        child: Text(decimalSeparator, style: digitStyle),
        onPressed: () => onInsert(decimalSeparator),
      ),
      buildKey(child: Text('0', style: digitStyle), onPressed: () => onInsert('0')),
      buildKey(
        child: const Icon(Icons.backspace_outlined, size: 20),
        onPressed: onBackspace,
        background: const Color(0xFFFFEBEE),
        foreground: const Color(0xFFEA4335),
        side: const BorderSide(color: Color(0xFFF8BBD0)),
      ),
    ];

    final letterStyle = const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      height: 1,
    );

    Widget buildKeyExpanded({
      required Widget child,
      required VoidCallback onPressed,
      int flex = 1,
      Color? background,
      Color? foreground,
      BorderSide? side,
    }) {
      return Expanded(
        flex: flex,
        child: buildKey(
          child: child,
          onPressed: onPressed,
          background: background,
          foreground: foreground,
          side: side,
        ),
      );
    }

    Widget buildRow(List<Widget> children, {double spacing = 6}) {
      return Expanded(
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1) SizedBox(width: spacing),
            ],
          ],
        ),
      );
    }

    Widget buildLettersLayout() {
      final row1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'ı', 'o', 'p', 'ğ', 'ü'];
      final row2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'ş', 'i'];
      final row3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm', 'ö', 'ç'];

      Widget letterKey(String value) {
        return buildKeyExpanded(
          child: Text(value, style: letterStyle),
          onPressed: () => onInsert(value),
        );
      }

      final numericPanelWidth = math.min(220.0, math.max(170.0, width * 0.36));

      return Row(
        children: [
          Expanded(
            child: Column(
              children: [
                buildRow(row1.map(letterKey).toList(growable: false)),
                const SizedBox(height: 6),
                buildRow(row2.map(letterKey).toList(growable: false)),
                const SizedBox(height: 6),
                buildRow(row3.map(letterKey).toList(growable: false)),
                const SizedBox(height: 6),
                buildRow(
                  [
                    buildKeyExpanded(
                      child: const Icon(Icons.space_bar_rounded, size: 18),
                      onPressed: () => onInsert(' '),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: numericPanelWidth,
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.28,
              physics: const NeverScrollableScrollPhysics(),
              children: numericKeys,
            ),
          ),
        ],
      );
    }

    return FocusScope(
      canRequestFocus: false,
      child: Material(
        elevation: 10,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.move,
                child: GestureDetector(
                  onPanUpdate: (details) => onDragUpdate(details.delta),
                  onPanEnd: (_) => onDragEnd(),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: outline),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: onToggleLettersMode,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  lettersMode
                                      ? Icons.dialpad_rounded
                                      : Icons.keyboard_alt_outlined,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  lettersMode ? '123' : 'TR-Q',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey.shade700,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr('retail.numeric_keyboard'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: tr('common.close'),
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: lettersMode
                    ? buildLettersLayout()
                    : GridView.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.28,
                        physics: const NeverScrollableScrollPhysics(),
                        children: numericKeys,
                      ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: onClear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5F6368),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: Text(
                    tr('common.clear'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
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

class _PerakendeHizliUrunlerPaneli extends StatefulWidget {
  final List<UrunModel> hizliUrunler;
  final Function(UrunModel) onSelect;
  final VoidCallback onChanged;
  final VoidCallback? onClose;
  final EdgeInsets headerPadding;

  const _PerakendeHizliUrunlerPaneli({
    required this.hizliUrunler,
    required this.onSelect,
    required this.onChanged,
    this.onClose,
    this.headerPadding = const EdgeInsets.fromLTRB(16, 48, 16, 16),
  });

  @override
  State<_PerakendeHizliUrunlerPaneli> createState() =>
      _PerakendeHizliUrunlerPaneliState();
}

class _PerakendeHizliUrunlerPaneliState
    extends State<_PerakendeHizliUrunlerPaneli> {
  bool _editMode = false;
  final TextEditingController _searchController = TextEditingController();
  List<UrunModel> _searchResults = [];
  bool _isSearching = false;

  Future<void> _openFullProductListDialog() async {
    showDialog(
      context: context,
      builder: (context) => _PerakendeUrunSearchDialog(
        initialQuery: _searchController.text.trim(),
        includeProductions: false,
        onSelect: (urun) {
          if (urun is! UrunModel) return;
          UrunlerVeritabaniServisi().hizliUruneEkle(urun.id).then((_) {
            if (!mounted) return;
            widget.onChanged();
          });
        },
      ),
    );
  }

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await UrunlerVeritabaniServisi().urunleriGetir(
        aramaTerimi: query,
        sayfaBasinaKayit: 10,
      );
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Arama hatası: $e');
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        if (_editMode) _buildEditArea(),
        Expanded(child: _buildProductGrid()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: widget.headerPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Color(0xFFFFA000)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('retail.quick_products'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: Icon(
              _editMode ? Icons.check_circle : Icons.settings_outlined,
              color: _editMode ? Colors.green : Colors.grey.shade600,
            ),
            onPressed: () {
              setState(() {
                _editMode = !_editMode;
                if (!_editMode) {
                  _searchController.clear();
                  _searchResults = [];
                }
              });
            },
            tooltip: _editMode ? tr('common.ok') : tr('common.manage'),
          ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onClose,
            ),
        ],
      ),
    );
  }

  Widget _buildEditArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('products.add'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: tr('retail.product_search_placeholder'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue.shade200),
                      ),
                    ),
                    onChanged: _searchProducts,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _openFullProductListDialog,
                  icon: const Icon(Icons.search, size: 18),
                  label: Text(
                    tr('retail.find'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_searchResults.isNotEmpty || _isSearching)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: _isSearching
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final urun = _searchResults[index];
                        final isAlreadyAdded = widget.hizliUrunler.any(
                          (e) => e.id == urun.id,
                        );
                        return ListTile(
                          dense: true,
                          leading: SizedBox(
                            width: 40,
                            height: 40,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: _buildProductImage(urun, size: 20),
                            ),
                          ),
                          title: Text(
                            urun.ad,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(urun.kod),
                          trailing: IconButton(
                            icon: Icon(
                              isAlreadyAdded
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: isAlreadyAdded
                                  ? Colors.green
                                  : Colors.blue,
                            ),
                            onPressed: isAlreadyAdded
                                ? null
                                : () async {
                                    await UrunlerVeritabaniServisi()
                                        .hizliUruneEkle(urun.id);
                                    widget.onChanged();
                                  },
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    if (widget.hizliUrunler.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              tr('retail.quick_product_not_found'),
              style: TextStyle(color: Colors.grey.shade500),
            ),
            if (!_editMode)
              TextButton(
                onPressed: () => setState(() => _editMode = true),
                child: Text(tr('products.add')),
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: widget.hizliUrunler.length,
      itemBuilder: (context, index) {
        final urun = widget.hizliUrunler[index];
        return _buildProductCard(urun);
      },
    );
  }

  Widget _buildProductCard(UrunModel urun) {
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: _editMode ? null : () => widget.onSelect(urun),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildProductImage(urun),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    urun.ad,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (_editMode)
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: () async {
                    await UrunlerVeritabaniServisi().hizliUrundenCikar(urun.id);
                    widget.onChanged();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(UrunModel urun, {double? size}) {
    String? raw;
    if (urun.resimUrl != null && urun.resimUrl!.isNotEmpty) {
      raw = urun.resimUrl!;
    } else if (urun.resimler.isNotEmpty) {
      raw = urun.resimler.first;
    }

    if (raw != null && raw.isNotEmpty) {
      final img = raw.trim();
      if (img.startsWith('http')) {
        return Image.network(
          img,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.image_outlined,
            color: Colors.grey.shade300,
            size: size,
          ),
        );
      }

      final normalized = _stripDataUriPrefix(img).replaceAll(RegExp(r'\s'), '');
      try {
        return Image.memory(
          base64Decode(normalized),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.image_outlined,
            color: Colors.grey.shade300,
            size: size,
          ),
        );
      } catch (_) {
        try {
          return Image.memory(
            base64Url.decode(normalized),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.image_outlined,
              color: Colors.grey.shade300,
              size: size,
            ),
          );
        } catch (_) {
          return Icon(
            Icons.image_outlined,
            color: Colors.grey.shade300,
            size: size,
          );
        }
      }
    }
    return Icon(Icons.image_outlined, color: Colors.grey.shade300, size: size);
  }

  String _stripDataUriPrefix(String value) {
    if (!value.startsWith('data:image')) return value;
    final commaIndex = value.indexOf(',');
    if (commaIndex == -1) return value;
    return value.substring(commaIndex + 1);
  }
}
