import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../siparisler_teklifler/modeller/teklif_model.dart';
import '../carihesaplar/modeller/cari_hesap_model.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../ayarlar/genel_ayarlar/modeller/doviz_kuru_model.dart';
import 'dart:async';

class TeklifDonusturDialog extends StatefulWidget {
  final TeklifModel teklif;

  const TeklifDonusturDialog({super.key, required this.teklif});

  @override
  State<TeklifDonusturDialog> createState() => _TeklifDonusturDialogState();
}

class _TeklifDonusturDialogState extends State<TeklifDonusturDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  CariHesapModel? _selectedCari;
  TextEditingController? _autocompleteController;
  late TextEditingController _kurController;
  late TextEditingController _cariAramaController;
  String _selectedParaBirimi = 'TRY';

  Timer? _searchDebounce;

  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();
  List<DovizKuruModel> _dovizKurlari = [];
  bool _isLoadingKurlar = false;

  static const Color _primaryColor = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    _selectedParaBirimi = widget.teklif.paraBirimi;
    _kurController = TextEditingController(
      text: FormatYardimcisi.sayiFormatlaOndalikli(
        widget.teklif.kur,
        decimalDigits: 4,
      ),
    );
    _cariAramaController = TextEditingController(
      text: widget.teklif.cariAdi ?? '',
    );

    _yukle().then((_) {
      if (widget.teklif.cariId != null) {
        _loadInitialCari();
      }
    });
  }

  Future<void> _yukle() async {
    setState(() => _isLoadingKurlar = true);
    try {
      final ayarlar = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      final kurlar = await AyarlarVeritabaniServisi().kurlariGetir();
      if (mounted) {
        setState(() {
          _genelAyarlar = ayarlar;
          _dovizKurlari = kurlar;
          _isLoadingKurlar = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingKurlar = false);
    }
  }

  void _onParaBirimiDegisti(String? val) {
    if (val == null) return;
    setState(() {
      _selectedParaBirimi = val;

      if (val == _genelAyarlar.varsayilanParaBirimi) {
        _kurController.text = FormatYardimcisi.sayiFormatlaOndalikli(
          1.0,
          decimalDigits: 4,
        );
        return;
      }

      final kur = _dovizKurlari.firstWhere(
        (k) =>
            k.kaynakParaBirimi == val &&
            k.hedefParaBirimi == _genelAyarlar.varsayilanParaBirimi,
        orElse: () => _dovizKurlari.firstWhere(
          (k) =>
              k.hedefParaBirimi == val &&
              k.kaynakParaBirimi == _genelAyarlar.varsayilanParaBirimi,
          orElse: () => DovizKuruModel(
            kaynakParaBirimi: val,
            hedefParaBirimi: _genelAyarlar.varsayilanParaBirimi,
            kur: 1.0,
            guncellemeZamani: DateTime.now(),
          ),
        ),
      );

      double rate = kur.kur;
      if (kur.hedefParaBirimi == val) {
        rate = 1.0 / rate;
      }

      _kurController.text = FormatYardimcisi.sayiFormatlaOndalikli(
        rate,
        decimalDigits: _genelAyarlar.kurOndalik,
      );
    });
  }

  Future<void> _searchCari() async {
    final selected = await showDialog<CariHesapModel>(
      context: context,
      builder: (context) => const _CariSelectionDialog(),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedCari = selected;
        _cariAramaController.text = selected.adi;
        if (_autocompleteController != null) {
          _autocompleteController!.text = selected.adi;
        }
      });
    }
  }

  Future<void> _loadInitialCari() async {
    try {
      final cari = await CariHesaplarVeritabaniServisi().cariHesapGetir(
        widget.teklif.cariId!,
      );
      if (mounted && cari != null) {
        setState(() {
          _selectedCari = cari;
          _cariAramaController.text = cari.adi;
          if (_autocompleteController != null) {
            _autocompleteController!.text = cari.adi;
          }
        });
      }
    } catch (e) {
      debugPrint('Cari yükleme hatası: $e');
    }
  }

  @override
  void dispose() {
    _kurController.dispose();
    _cariAramaController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double dialogRadius = 14;
    final bool isMobile = MediaQuery.sizeOf(context).width < 900;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.enter):
            _onCurrencyConversionConfirmed,
        const SingleActivator(LogicalKeyboardKey.numpadEnter):
            _onCurrencyConversionConfirmed,
      },
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: isMobile
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 0 : dialogRadius),
        ),
        child: SafeArea(
          child: Container(
            width: isMobile ? double.infinity : 500,
            height: isMobile ? MediaQuery.sizeOf(context).height : null,
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 28,
              isMobile ? 16 : 24,
              isMobile ? 16 : 28,
              isMobile ? 16 : 22,
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoadingKurlar)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(
                          backgroundColor: Color(0xFFE0E0E0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _primaryColor,
                          ),
                          minHeight: 2,
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('quotes.convert_to_sale_title'),
                                style: TextStyle(
                                  fontSize: isMobile ? 18 : 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF202124),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${tr('quotes.quote_no')}: ${widget.teklif.id}',
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF606368),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 22,
                            color: Color(0xFF3C4043),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Cari Hesap Seçimi
                    Text(
                      tr('common.account'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A4A4A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Autocomplete<CariHesapModel>(
                      displayStringForOption: (option) => option.adi,
                      initialValue: TextEditingValue(
                        text: _selectedCari?.adi ?? _cariAramaController.text,
                      ),
                      optionsBuilder:
                          (TextEditingValue textEditingValue) async {
                            if (textEditingValue.text.length < 2) {
                              return const Iterable<CariHesapModel>.empty();
                            }
                            return await CariHesaplarVeritabaniServisi()
                                .cariHesaplariGetir(
                                  aramaTerimi: textEditingValue.text,
                                  sayfaBasinaKayit: 10,
                                );
                          },
                      onSelected: (CariHesapModel selection) {
                        setState(() => _selectedCari = selection);
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            _autocompleteController = controller;
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: tr('quotes.search_customer_hint'),
                                prefixIcon: const Icon(
                                  Icons.person_search,
                                  size: 20,
                                  color: Color(0xFFBDC1C6),
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_selectedCari != null)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.clear,
                                          color: Colors.grey,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _selectedCari = null;
                                            controller.clear();
                                            _cariAramaController.clear();
                                          });
                                        },
                                      ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.search,
                                        color: Colors.grey,
                                      ),
                                      onPressed: _searchCari,
                                    ),
                                  ],
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0xFFE0E0E0),
                                  ),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: _primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 444,
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final option = options.elementAt(index);
                                  return InkWell(
                                    mouseCursor: WidgetStateMouseCursor.clickable,
                                    onTap: () => onSelected(option),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        option.adi,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Para Birimi ve Kur
                    if (isMobile)
                      Column(
                        children: [
                          _buildCurrencyField(),
                          const SizedBox(height: 12),
                          _buildRateField(),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(flex: 2, child: _buildCurrencyField()),
                          const SizedBox(width: 24),
                          Expanded(flex: 3, child: _buildRateField()),
                        ],
                      ),

                    const SizedBox(height: 32),

                    // Footer
                    if (isMobile)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primaryColor,
                                side: BorderSide(color: Colors.grey.shade300),
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                tr('common.cancel'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _onCurrencyConversionConfirmed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                tr('quotes.convert_to_sale_btn'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              tr('common.cancel'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _onCurrencyConversionConfirmed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              tr('quotes.convert_to_sale_btn'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('common.currency'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A4A4A),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          mouseCursor: WidgetStateMouseCursor.clickable,
          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
          initialValue: _selectedParaBirimi,
          decoration: const InputDecoration(
            prefixIcon: Icon(
              Icons.monetization_on_outlined,
              size: 20,
              color: Color(0xFFBDC1C6),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 12),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
          items: _genelAyarlar.kullanilanParaBirimleri
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: _onParaBirimiDegisti,
        ),
      ],
    );
  }

  Widget _buildRateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('common.exchange_rate'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A4A4A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _kurController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            hintText: tr('common.placeholder.amount_4dec'),
            prefixIcon: const Icon(
              Icons.trending_up,
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
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _onCurrencyConversionConfirmed() {
    final double yeniKur =
        double.tryParse(_kurController.text.replaceAll(',', '.')) ?? 1.0;

    Navigator.of(context).pop({
      'cari': _selectedCari,
      'paraBirimi': _selectedParaBirimi,
      'kur': yeniKur,
    });
  }
}

class _CariSelectionDialog extends StatefulWidget {
  const _CariSelectionDialog();
  @override
  State<_CariSelectionDialog> createState() => _CariSelectionDialogState();
}

class _CariSelectionDialogState extends State<_CariSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<CariHesapModel> _cariler = [];
  bool _isLoading = false;
  Timer? _debounce;
  static const Color _primaryColor = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    _searchCariler('');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchCariler(query),
    );
  }

  Future<void> _searchCariler(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await CariHesaplarVeritabaniServisi().cariHesaplariGetir(
        aramaTerimi: query,
        sayfaBasinaKayit: 50,
        sortAscending: true,
        sortBy: 'adi',
        aktifMi: true,
      );
      if (mounted) {
        setState(() {
          _cariler = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.sizeOf(context).width < 900;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: isMobile
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 0 : 14),
      ),
      child: SafeArea(
        child: Container(
          width: isMobile ? double.infinity : 720,
          height: isMobile ? MediaQuery.sizeOf(context).height : null,
          constraints: BoxConstraints(
            maxHeight: isMobile ? double.infinity : 680,
          ),
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 28,
            isMobile ? 16 : 24,
            isMobile ? 16 : 28,
            isMobile ? 16 : 22,
          ),
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
                          tr('quotes.select_customer_to_convert'),
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF202124),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr('quotes.search_customer_hint'),
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF606368),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isMobile) ...[
                        Text(
                          tr('common.esc'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9AA0A6),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: const Icon(
                          Icons.close,
                          size: 22,
                          color: Color(0xFF3C4043),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: tr('common.close'),
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
                      hintText: tr('common.search_fields.code_name_phone'),
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
                    : _cariler.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.person_search_outlined,
                              size: 48,
                              color: Color(0xFFE0E0E0),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              tr('accounts.no_accounts_found'),
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF606368),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _cariler.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        itemBuilder: (ctx, i) {
                          final c = _cariler[i];
                          return InkWell(
                            mouseCursor: WidgetStateMouseCursor.clickable,
                            onTap: () => Navigator.pop(context, c),
                            hoverColor: const Color(0xFFF5F7FA),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE3F2FD),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: _primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.adi,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF202124),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${c.kodNo} • ${c.hesapTuru}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF606368),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                    color: Color(0xFFBDC1C6),
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
      ),
    );
  }
}
