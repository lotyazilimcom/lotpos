import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../servisler/senetler_veritabani_servisi.dart';
import '../../bilesenler/tek_tarih_secici_dialog.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../carihesaplar/modeller/cari_hesap_model.dart';
import 'modeller/senet_model.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../../bilesenler/akilli_aciklama_input.dart';

class SenetVerDialog extends StatefulWidget {
  const SenetVerDialog({super.key, this.senet, this.initialSenetNo});

  final SenetModel? senet;
  final String? initialSenetNo;

  @override
  State<SenetVerDialog> createState() => _SenetVerDialogState();
}

class _SenetVerDialogState extends State<SenetVerDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  late TextEditingController _cariKodController;
  late TextEditingController _cariAdiController;
  late TextEditingController _duzenlenmeTarihiController;
  late TextEditingController _kesideTarihiController;
  late TextEditingController _senetNoController;
  late TextEditingController _bankaController;
  late TextEditingController _aciklamaController;
  late TextEditingController _tutarController;

  late FocusNode _cariKodFocusNode;
  late FocusNode _cariAdiFocusNode;
  late FocusNode _duzenlenmeTarihiFocusNode;
  late FocusNode _kesideTarihiFocusNode;
  late FocusNode _senetNoFocusNode;
  late FocusNode _bankaFocusNode;
  late FocusNode _aciklamaFocusNode;
  late FocusNode _tutarFocusNode;

  DateTime? _duzenlenmeTarihi;
  DateTime? _kesideTarihi;
  String _selectedParaBirimi = 'TRY';

  // Selected Cari Hesap
  // ignore: unused_field
  int? _selectedCariId;
  String _cariKodCommittedValue = '';

  // Supplier Autocomplete Debounce
  Timer? _supplierSearchDebounce;

  // Validation State
  String? _senetNoError;

  final FocusNode _dialogFocusNode = FocusNode();

  static const Color _primaryColor = Color(0xFF2C3E50);

  // Para birimleri listesi
  static const List<String> _paraBirimleri = [
    'TRY',
    'USD',
    'EUR',
    'GBP',
    'SAR',
    'AED',
    'RUB',
    'AZN',
  ];

  @override
  void initState() {
    super.initState();
    final senet = widget.senet;
    _cariKodController = TextEditingController(text: senet?.cariKod ?? '');
    _cariAdiController = TextEditingController(text: senet?.cariAdi ?? '');
    _cariKodCommittedValue = _cariKodController.text.trim();

    if (senet != null && senet.duzenlenmeTarihi.isNotEmpty) {
      try {
        _duzenlenmeTarihi = DateFormat(
          'dd.MM.yyyy',
        ).parse(senet.duzenlenmeTarihi);
      } catch (_) {
        _duzenlenmeTarihi = DateTime.now();
      }
    } else {
      _duzenlenmeTarihi = DateTime.now();
    }

    _duzenlenmeTarihiController = TextEditingController(
      text:
          senet?.duzenlenmeTarihi ??
          DateFormat('dd.MM.yyyy').format(_duzenlenmeTarihi!),
    );

    _kesideTarihiController = TextEditingController(
      text: senet?.kesideTarihi ?? '',
    );
    _senetNoController = TextEditingController(
      text: senet?.senetNo ?? widget.initialSenetNo ?? '',
    );
    _bankaController = TextEditingController(text: senet?.banka ?? '');
    _aciklamaController = TextEditingController(text: senet?.aciklama ?? '');
    _tutarController = TextEditingController(
      text: senet?.tutar != null && senet!.tutar > 0
          ? FormatYardimcisi.sayiFormatlaOndalikli(
              senet.tutar,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
              decimalDigits: _genelAyarlar.fiyatOndalik,
            )
          : '',
    );
    _selectedParaBirimi = senet?.paraBirimi ?? 'TRY';

    if (senet?.kesideTarihi.isNotEmpty == true) {
      try {
        _kesideTarihi = DateFormat('dd.MM.yyyy').parse(senet!.kesideTarihi);
      } catch (_) {}
    }

    _cariKodFocusNode = FocusNode();
    _cariAdiFocusNode = FocusNode();
    _duzenlenmeTarihiFocusNode = FocusNode();
    _kesideTarihiFocusNode = FocusNode();
    _senetNoFocusNode = FocusNode();
    _bankaFocusNode = FocusNode();
    _aciklamaFocusNode = FocusNode();
    _tutarFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cariKodFocusNode.requestFocus();
      _loadSettings();
    });
    _attachAmountFormatter();
  }

  void _attachAmountFormatter() {
    _tutarFocusNode.addListener(() {
      if (!_tutarFocusNode.hasFocus) {
        final text = _tutarController.text.trim();
        if (text.isEmpty) return;
        final value = FormatYardimcisi.parseDouble(
          text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        );
        final formatted = FormatYardimcisi.sayiFormatlaOndalikli(
          value,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.fiyatOndalik,
        );
        setState(() {
          _tutarController.text = formatted;
        });
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      if (mounted) {
        setState(() {
          _genelAyarlar = settings;
          // Ayarlar yüklendikten sonra tutarı tekrar formatla (eğer varsa)
          if (_tutarController.text.isNotEmpty) {
            final currentVal = FormatYardimcisi.parseDouble(
              _tutarController.text,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
            );
            _tutarController.text = FormatYardimcisi.sayiFormatlaOndalikli(
              currentVal,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
              decimalDigits: _genelAyarlar.fiyatOndalik,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Ayarlar yüklenirken hata: $e');
    }
  }

  @override
  void dispose() {
    _supplierSearchDebounce?.cancel();
    _dialogFocusNode.dispose();
    _cariKodController.dispose();
    _cariAdiController.dispose();
    _duzenlenmeTarihiController.dispose();
    _kesideTarihiController.dispose();
    _senetNoController.dispose();
    _bankaController.dispose();
    _aciklamaController.dispose();
    _tutarController.dispose();
    _cariKodFocusNode.dispose();
    _cariAdiFocusNode.dispose();
    _duzenlenmeTarihiFocusNode.dispose();
    _kesideTarihiFocusNode.dispose();
    _senetNoFocusNode.dispose();
    _bankaFocusNode.dispose();
    _aciklamaFocusNode.dispose();
    _tutarFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
    DateTime? currentDate,
    Function(DateTime) onSelect, {
    bool isDueDate = false,
  }) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(
        initialDate: currentDate ?? DateTime.now(),
        title: isDueDate ? tr('notes.form.due_date.label') : tr('common.date'),
      ),
    );
    if (picked != null) {
      onSelect(picked);
      controller.text = DateFormat('dd.MM.yyyy').format(picked);
    }
  }

  void _openSupplierSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _SupplierSearchDialogWrapper(
        onSelect: (supplier) {
          setState(() {
            _selectedCariId = supplier.id;
            _cariKodController.text = supplier.kodNo;
            _cariAdiController.text = supplier.adi;
            _cariKodCommittedValue = supplier.kodNo.trim();
          });
          Future.microtask(() {
            if (!mounted) return;
            _focusNextAfterCariSelected();
          });
        },
      ),
    );
  }

  void _focusNextAfterCariSelected() {
    final nextFocusNode = _findNextFocusAfterCariSelected();
    FocusScope.of(
      context,
    ).requestFocus(nextFocusNode ?? _kesideTarihiFocusNode);
  }

  FocusNode? _findNextFocusAfterCariSelected() {
    if (_duzenlenmeTarihiController.text.trim().isEmpty) {
      return _duzenlenmeTarihiFocusNode;
    }
    if (_kesideTarihiController.text.trim().isEmpty) {
      return _kesideTarihiFocusNode;
    }
    if (_senetNoController.text.trim().isEmpty) {
      return _senetNoFocusNode;
    }
    if (_tutarController.text.trim().isEmpty) {
      return _tutarFocusNode;
    }
    if (_aciklamaController.text.trim().isEmpty) {
      return _aciklamaFocusNode;
    }
    return null;
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check duplicate note number
    final isDuplicate = await SenetlerVeritabaniServisi().senetNoVarMi(
      _senetNoController.text.trim(),
      haricId: widget.senet?.id,
    );

    if (isDuplicate) {
      if (!mounted) return;
      setState(() {
        _senetNoError = tr('common.code_exists_error');
      });
      return;
    }

    // Parse tutar
    double tutar = FormatYardimcisi.parseDouble(
      _tutarController.text.trim(),
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
    );

    final String uniqueRef =
        widget.senet?.integrationRef ??
        'promissory_${DateTime.now().millisecondsSinceEpoch}';

    final SenetModel sonuc = SenetModel(
      id: widget.senet?.id ?? 0,
      tur: 'Verilen Senet',
      tahsilat: 'Ödeme',
      cariKod: _cariKodController.text.trim(),
      cariAdi: _cariAdiController.text.trim(),
      duzenlenmeTarihi: _duzenlenmeTarihiController.text.trim(),
      kesideTarihi: _kesideTarihiController.text.trim(),
      senetNo: _senetNoController.text.trim(),
      banka: _bankaController.text.trim(),
      aciklama: _aciklamaController.text.trim(),
      tutar: tutar,
      paraBirimi: _selectedParaBirimi,
      kullanici: 'admin',
      aktifMi: true,
      integrationRef: uniqueRef,
    );

    if (!mounted) return;
    Navigator.of(context).pop(sonuc);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // ESC tuşu ile kapat
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
      // Tek Enter ile kaydet (zorunlu alanlar doluysa)
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        // Tüm zorunlu alanlar dolu mu kontrol et
        final bool isReady =
            _cariKodController.text.trim().isNotEmpty &&
            _cariAdiController.text.trim().isNotEmpty &&
            _duzenlenmeTarihiController.text.trim().isNotEmpty &&
            _kesideTarihiController.text.trim().isNotEmpty &&
            _senetNoController.text.trim().isNotEmpty &&
            _tutarController.text.trim().isNotEmpty;

        if (isReady) {
          _kaydet();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
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
        : 800;
    final double maxDialogHeight = isCompact ? screenSize.height * 0.92 : 850;
    final double contentPadding = isCompact ? 16 : 28;

    return FocusScope(
      onKeyEvent: _handleKeyEvent,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
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
            child: Form(
              key: _formKey,
              child: Column(
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
                              widget.senet != null
                                  ? tr('notes.form.edit.title')
                                  : tr('notes.form.give.title'),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF202124),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.senet != null
                                  ? tr('notes.form.edit.subtitle')
                                  : tr('notes.form.give.subtitle'),
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
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: IconButton(
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
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cari Kodu ve Cari Adı (yan yana, ikisi de zorunlu)
                          _buildCariHesapFields(),
                          const SizedBox(height: 22),
                          // Düzenleme Tarihi ve Keşide Tarihi
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildDateField(
                                  label: tr('notes.form.issue_date.label'),
                                  hint: tr('notes.form.issue_date.hint'),
                                  controller: _duzenlenmeTarihiController,
                                  isRequired: true,
                                  icon: Icons.calendar_today,
                                  focusNode: _duzenlenmeTarihiFocusNode,
                                  onTap: () => _selectDate(
                                    context,
                                    _duzenlenmeTarihiController,
                                    _duzenlenmeTarihi,
                                    (date) => setState(
                                      () => _duzenlenmeTarihi = date,
                                    ),
                                  ),
                                  onClear: () {
                                    setState(() {
                                      _duzenlenmeTarihiController.clear();
                                      _duzenlenmeTarihi = null;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildDateField(
                                  label: tr('notes.form.due_date.label'),
                                  hint: tr('notes.form.due_date.hint'),
                                  controller: _kesideTarihiController,
                                  isRequired: true,
                                  icon: Icons.event,
                                  focusNode: _kesideTarihiFocusNode,
                                  onTap: () => _selectDate(
                                    context,
                                    _kesideTarihiController,
                                    _kesideTarihi,
                                    (date) =>
                                        setState(() => _kesideTarihi = date),
                                  ),
                                  onClear: () {
                                    setState(() {
                                      _kesideTarihiController.clear();
                                      _kesideTarihi = null;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          // Senet Numarası
                          _buildUnderlinedField(
                            label: tr('notes.form.note_no.label'),
                            hint: tr('notes.form.note_no.hint'),
                            controller: _senetNoController,
                            isRequired: true,
                            icon: Icons.confirmation_number,
                            focusNode: _senetNoFocusNode,
                            errorText: _senetNoError,
                            onChanged: (val) {
                              if (_senetNoError != null) {
                                setState(() => _senetNoError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 22),
                          // Para Birimi ve Tutar
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildCurrencyDropdown()),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildUnderlinedField(
                                  label: tr('notes.form.amount.label'),
                                  hint: tr('notes.form.amount.hint'),
                                  controller: _tutarController,
                                  isRequired: true,
                                  icon: Icons.attach_money,
                                  focusNode: _tutarFocusNode,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    CurrencyInputFormatter(
                                      binlik: _genelAyarlar.binlikAyiraci,
                                      ondalik: _genelAyarlar.ondalikAyiraci,
                                      maxDecimalDigits:
                                          _genelAyarlar.fiyatOndalik,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          // Açıklama (tam genişlik)
                          AkilliAciklamaInput(
                            controller: _aciklamaController,
                            label: tr('notes.form.description.label'),
                            category: 'note_issue_description',
                            color: _primaryColor,
                            focusNode: _aciklamaFocusNode,
                            defaultItems: [
                              tr('smart_select.note_issue.desc.1'),
                              tr('smart_select.note_issue.desc.2'),
                              tr('smart_select.note_issue.desc.3'),
                              tr('smart_select.note_issue.desc.4'),
                              tr('smart_select.note_issue.desc.5'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: _primaryColor,
                        ),
                        child: Row(
                          children: [
                            Text(
                              tr('common.cancel'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _primaryColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tr('common.esc'),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9AA0A6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _kaydet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          widget.senet != null
                              ? tr('notes.form.update')
                              : tr('notes.form.save'),
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
    );
  }

  Widget _buildUnderlinedField({
    required String label,
    String? hint,
    TextEditingController? controller,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
    String? Function(String?)? validator,
    bool obscureText = false,
    IconData? icon,
    FocusNode? focusNode,
    int? maxLength,
    String? errorText,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    final labelColor = isRequired ? Colors.red : const Color(0xFF4A4A4A);
    final borderColor = isRequired ? Colors.red : const Color(0xFFE0E0E0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator:
              validator ??
              (isRequired
                  ? (value) {
                      if (value == null || value.trim().isEmpty) {
                        return tr('settings.users.form.required');
                      }
                      return null;
                    }
                  : null),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          onChanged: onChanged,
          decoration: InputDecoration(
            errorText: errorText,
            hintText: hint,
            prefixIcon: icon != null
                ? Icon(icon, size: 20, color: const Color(0xFFBDC1C6))
                : null,
            hintStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFFBDC1C6),
            ),
            errorStyle: const TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: borderColor, width: 2),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            counterStyle: maxLength != null
                ? const TextStyle(fontSize: 12, color: Colors.grey)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    String? hint,
    required TextEditingController controller,
    bool isRequired = false,
    IconData? icon,
    FocusNode? focusNode,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final labelColor = isRequired ? Colors.red : const Color(0xFF4A4A4A);
    final borderColor = isRequired ? Colors.red : const Color(0xFFE0E0E0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                mouseCursor: SystemMouseCursors.click,
                child: IgnorePointer(
                  child: TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    readOnly: true,
                    validator: isRequired
                        ? (value) {
                            if (value == null || value.trim().isEmpty) {
                              return tr('settings.users.form.required');
                            }
                            return null;
                          }
                        : null,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF202124),
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      prefixIcon: icon != null
                          ? Icon(icon, size: 20, color: const Color(0xFFBDC1C6))
                          : null,
                      hintStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFBDC1C6),
                      ),
                      errorStyle: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: borderColor, width: 2),
                      ),
                      errorBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (controller.text.isNotEmpty && onClear != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                onPressed: onClear,
                tooltip: tr('common.clear'),
              )
            else
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Color(0xFFBDC1C6),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrencyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              tr('notes.form.currency.label'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
            const Text(
              ' *',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ignore: deprecated_member_use
        DropdownButtonFormField<String>(
          key: ValueKey(_selectedParaBirimi),
          initialValue: _selectedParaBirimi,
          isExpanded: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return tr('settings.users.form.required');
            }
            return null;
          },
          decoration: const InputDecoration(
            prefixIcon: Icon(
              Icons.monetization_on_outlined,
              size: 20,
              color: Color(0xFFBDC1C6),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 12),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            errorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
          ),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFBDC1C6)),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
          items: _paraBirimleri.map((currency) {
            return DropdownMenuItem(
              value: currency,
              child: Text(
                currency,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF202124),
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedParaBirimi = val);
            }
          },
        ),
      ],
    );
  }

  // Cari Kodu ve Cari Adı - İki alan yan yana, ikisi de zorunlu (kırmızı)
  Widget _buildCariHesapFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stack = constraints.maxWidth < 640;
        if (stack) {
          return Column(
            children: [
              _buildCariKodFieldWithSearch(),
              const SizedBox(height: 18),
              _buildCariAdiField(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildCariKodFieldWithSearch()),
            const SizedBox(width: 24),
            Expanded(child: _buildCariAdiField()),
          ],
        );
      },
    );
  }

  // Cari Kodu alanı + Arama butonu (Zengin aramalı profesyonel versiyon)
  Widget _buildCariKodFieldWithSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              tr('notes.form.customer_code.label'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            const Text(
              ' *',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              tr('common.search_fields.code_name'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        RawAutocomplete<CariHesapModel>(
          focusNode: _cariKodFocusNode,
          textEditingController: _cariKodController,
          displayStringForOption: (CariHesapModel option) => option.kodNo,
          optionsBuilder: (TextEditingValue textEditingValue) async {
            final query = textEditingValue.text.trim();
            if (query.isEmpty || query == _cariKodCommittedValue) {
              return const Iterable<CariHesapModel>.empty();
            }
            return await CariHesaplarVeritabaniServisi().cariHesaplariGetir(
              aramaTerimi: query,
              sayfaBasinaKayit: 10,
              aktifMi: true,
            );
          },
          onSelected: (CariHesapModel selection) {
            setState(() {
              _selectedCariId = selection.id;
              _cariKodController.text = selection.kodNo;
              _cariAdiController.text = selection.adi;
              _cariKodCommittedValue = selection.kodNo.trim();
            });
            Future.microtask(() {
              if (!mounted) return;
              _focusNextAfterCariSelected();
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: Color(0xFF202124),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return tr('settings.users.form.required');
                }
                return null;
              },
              onFieldSubmitted: (value) => onFieldSubmitted(),
              decoration: InputDecoration(
                hintText: tr('notes.form.customer_code.hint'),
                prefixIcon: const Icon(
                  Icons.person_outline,
                  size: 20,
                  color: Color(0xFFBDC1C6),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: _primaryColor),
                  onPressed: _openSupplierSearchDialog,
                  tooltip: tr('accounts.search_title'),
                ),
                hintStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFBDC1C6),
                ),
                errorStyle: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2),
                ),
                errorBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
                ),
                focusedErrorBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2),
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                child: Container(
                  width: 400,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (BuildContext context, int index) {
                      final CariHesapModel option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.adi,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Color(0xFF202124),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    option.kodNo,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (option.fatIlce.isNotEmpty ||
                                      option.fatSehir.isNotEmpty) ...[
                                    Container(
                                      width: 4,
                                      height: 4,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    Text(
                                      "${option.fatIlce}${option.fatIlce.isNotEmpty && option.fatSehir.isNotEmpty ? ' / ' : ''}${option.fatSehir}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
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
      ],
    );
  }

  // Cari Adı alanı (salt okunur, otomatik dolan)
  Widget _buildCariAdiField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              tr('notes.form.customer_name.label'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            const Text(
              ' *',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: _cariAdiController,
          focusNode: _cariAdiFocusNode,
          readOnly: true,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: Color(0xFF202124),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return tr('settings.users.form.required');
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: tr('notes.form.customer_name.hint'),
            prefixIcon: const Icon(
              Icons.business,
              size: 20,
              color: Color(0xFFBDC1C6),
            ),
            hintStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFFBDC1C6),
            ),
            errorStyle: const TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

// --- PROFESSIONAL SUPPLIER SEARCH DIALOG ---
class _SupplierSearchDialogWrapper extends StatefulWidget {
  final Function(CariHesapModel) onSelect;
  const _SupplierSearchDialogWrapper({required this.onSelect});
  @override
  State<_SupplierSearchDialogWrapper> createState() =>
      _SupplierSearchDialogWrapperState();
}

class _SupplierSearchDialogWrapperState
    extends State<_SupplierSearchDialogWrapper> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<CariHesapModel> _suppliers = [];
  bool _isLoading = false;
  Timer? _debounce;
  static const Color _primaryColor = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    _searchSuppliers('');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchSuppliers(query);
    });
  }

  Future<void> _searchSuppliers(String query) async {
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
          _suppliers = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('accounts.search_title'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('accounts.search_subtitle'),
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
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IconButton(
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
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search Input
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
                    hintText: tr('accounts.search_fields_hint'),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: Color(0xFFBDC1C6),
                    ),
                    hintStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
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
            const SizedBox(height: 16),

            // Results List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _suppliers.isEmpty
                  ? Center(
                      child: Text(
                        tr('common.no_results'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9AA0A6),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _suppliers.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final supplier = _suppliers[index];
                        return InkWell(
                          onTap: () {
                            widget.onSelect(supplier);
                            Navigator.of(context).pop();
                          },
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
                                    color: _primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.business,
                                    color: _primaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        supplier.adi,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF202124),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        supplier.kodNo,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF9AA0A6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
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
    );
  }
}
