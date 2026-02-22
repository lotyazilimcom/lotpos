import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/mesaj_yardimcisi.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import 'modeller/cari_hesap_model.dart';

import '../../../servisler/ayarlar_veritabani_servisi.dart';
import '../../bilesenler/tek_tarih_secici_dialog.dart';
import '../../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../../servisler/sayfa_senkronizasyon_servisi.dart';

class BorcAlacakDekontuIsleSayfasi extends StatefulWidget {
  final CariHesapModel cari;
  final Map<String, dynamic>? duzenlenecekIslem;

  const BorcAlacakDekontuIsleSayfasi({
    super.key,
    required this.cari,
    this.duzenlenecekIslem,
  });

  @override
  State<BorcAlacakDekontuIsleSayfasi> createState() =>
      _BorcAlacakDekontuIsleSayfasiState();
}

class _BorcAlacakDekontuIsleSayfasiState
    extends State<BorcAlacakDekontuIsleSayfasi> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  // Controllers
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedTransactionType = 'Borç'; // 'Borç' or 'Alacak'
  String _currency = 'TL';
  DateTime? _selectedDate;
  DateTime? _selectedDueDate;

  late FocusNode _amountFocusNode;
  late FocusNode _descriptionFocusNode;

  @override
  void initState() {
    super.initState();
    _amountFocusNode = FocusNode();
    _descriptionFocusNode = FocusNode();

    // Giriş alanlarını doldur (Read-only)
    _codeController.text = widget.cari.kodNo;
    _nameController.text = widget.cari.adi;
    _isEditing = widget.duzenlenecekIslem != null;

    _initializeData();

    _loadSettings();

    // Tutar alanına odaklan (sadece yeni kayıtlarda)
    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _amountFocusNode.requestFocus();
      });
    }
  }

  void _initializeData() {
    final editing = widget.duzenlenecekIslem;

    if (editing != null) {
      // DÜZENLEME MODU
      final islemTuru =
          editing['islem_turu']?.toString() ??
          editing['type']?.toString() ??
          '';
      final isBorc = islemTuru.contains('Borç') || islemTuru.contains('Borc');
      _selectedTransactionType = isBorc ? 'Borç' : 'Alacak';

      final double tutar =
          double.tryParse(
            (editing['tutar'] ?? editing['amount'])?.toString() ?? '',
          ) ??
          0.0;

      // İlk yüklemede ham format - _loadSettings sonrası ayırıcılarla tekrar formatlanacak
      _amountController.text = FormatYardimcisi.sayiFormatlaOndalikli(
        tutar,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: _genelAyarlar.fiyatOndalik,
      );

      _currency = editing['para_birimi'] ?? widget.cari.paraBirimi;

      final rawDate = editing['tarih'] ?? editing['date'];
      if (rawDate != null) {
        _selectedDate = rawDate is DateTime
            ? rawDate
            : DateTime.tryParse(rawDate.toString());
      } else {
        _selectedDate = DateTime.now();
      }

      final rawDueDate = editing['vade_tarihi'];
      if (rawDueDate != null) {
        _selectedDueDate = rawDueDate is DateTime
            ? rawDueDate
            : DateTime.tryParse(rawDueDate.toString());
      }

      _descriptionController.text =
          editing['aciklama']?.toString() ??
          editing['description']?.toString() ??
          '';
    } else {
      // YENİ EKLEME MODU
      _selectedDate = DateTime.now();
      _currency = widget.cari.paraBirimi;
    }

    if (_selectedDate != null) {
      _dateController.text = DateFormat('dd.MM.yyyy').format(_selectedDate!);
    }

    if (_selectedDueDate != null) {
      _dueDateController.text = DateFormat(
        'dd.MM.yyyy',
      ).format(_selectedDueDate!);
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      if (mounted) {
        setState(() {
          _genelAyarlar = settings;
          // Ayarlar gelince tutarı tekrar formatla ki ayırıcılar doğru olsun
          if (_isEditing) {
            final double tutar =
                double.tryParse(
                  (widget.duzenlenecekIslem?['tutar'] ??
                              widget.duzenlenecekIslem?['amount'])
                          ?.toString() ??
                      '',
                ) ??
                0.0;
            _amountController.text = FormatYardimcisi.sayiFormatlaOndalikli(
              tutar,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
              decimalDigits: _genelAyarlar.fiyatOndalik,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Genel ayarlar yüklenemedi: $e');
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _dueDateController.dispose();
    _descriptionController.dispose();
    _amountFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context, {
    bool isDueDate = false,
  }) async {
    final initialDate = isDueDate
        ? (_selectedDueDate ?? DateTime.now())
        : (_selectedDate ?? DateTime.now());

    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(
        initialDate: initialDate,
        title: isDueDate
            ? tr('accounts.transaction.due_date')
            : tr('common.date'),
      ),
    );

    if (picked != null) {
      // Tarih seçildiğinde o anki saati koru
      final now = DateTime.now();
      final DateTime dateWithTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        now.hour,
        now.minute,
      );

      setState(() {
        if (isDueDate) {
          _selectedDueDate = dateWithTime;
          _dueDateController.text = DateFormat(
            'dd.MM.yyyy',
          ).format(dateWithTime);
        } else {
          _selectedDate = dateWithTime;
          _dateController.text = DateFormat('dd.MM.yyyy').format(dateWithTime);
        }
      });
    }
  }

  void _clearDueDate() {
    setState(() {
      _selectedDueDate = null;
      _dueDateController.clear();
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTransactionType == null) {
      MesajYardimcisi.hataGoster(context, tr('validation.required'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = prefs.getString('current_username') ?? 'Sistem';

      final amount = FormatYardimcisi.parseDouble(
        _amountController.text,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );

      final bool isBorc = _selectedTransactionType == 'Borç';

      final DateTime tarih = _selectedDate ?? DateTime.now();

      final String aciklama = _descriptionController.text.trim();

      await CariHesaplarVeritabaniServisi().cariDekontKaydet(
        cariId: widget.cari.id,
        tutar: amount,
        isBorc: isBorc,
        aciklama: aciklama,
        tarih: tarih,
        kullanici: currentUser,
        cariAdi: widget.cari.adi,
        cariKodu: widget.cari.kodNo,
        belgeNo: null,
        vadeTarihi: _selectedDueDate,
        duzenlenecekIslem: widget.duzenlenecekIslem,
      );

      if (!mounted) return;

      MesajYardimcisi.basariGoster(context, tr('common.saved_successfully'));
      SayfaSenkronizasyonServisi().veriDegisti('cari');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).pop();
        },
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_isLoading) _handleSave();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_isLoading) _handleSave();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
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
            leadingWidth: 80,
            title: Text(
              widget.duzenlenecekIslem != null
                  ? 'Borç / Alacak Dekontu Güncelle'
                  : tr('accounts.actions.receipt'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 21,
              ),
            ),
            centerTitle: false,
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(theme),
                            const SizedBox(height: 32),
                            _buildSection(
                              theme,
                              title: tr('products.form.section.general'),
                              child: _buildGeneralInfoSection(theme),
                              icon: Icons.info_rounded,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(height: 24),
                            _buildSection(
                              theme,
                              title: tr('accounts.transaction.details'),
                              child: _buildTransactionDetailsSection(theme),
                              icon: Icons.receipt_long_rounded,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(height: 24),
                            _buildSection(
                              theme,
                              title: tr('shipment.field.description'),
                              child: _buildDescriptionSection(theme),
                              icon: Icons.description_rounded,
                              color: Colors.teal.shade700,
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: _buildActionButtons(theme),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.receipt_long_rounded,
            color: theme.colorScheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing
                  ? 'Borç / Alacak Dekontu Güncelle'
                  : tr('accounts.actions.receipt'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                fontSize: 23,
              ),
            ),
            Text(
              _isEditing
                  ? 'Mevcut borç veya alacak dekontunu güncelleyebilirsiniz.'
                  : tr('accounts.transaction.subtitle'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required String title,
    required Widget child,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontSize: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildGeneralInfoSection(ThemeData theme) {
    const requiredColor = Colors.red;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Column(
          children: [
            _buildRow(isWide, [
              _buildTextField(
                controller: _codeController,
                label: tr('accounts.form.code'),
                isRequired: true,
                color: requiredColor,
                readOnly: true,
              ),
              _buildTextField(
                controller: _nameController,
                label: tr('accounts.form.name'),
                isRequired: true,
                color: requiredColor,
                readOnly: true,
              ),
            ]),
          ],
        );
      },
    );
  }

  Widget _buildTransactionDetailsSection(ThemeData theme) {
    const requiredColor = Colors.red;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Column(
          children: [
            _buildRow(isWide, [
              _buildDropdown(
                value: _selectedTransactionType,
                label: tr('products.transaction.type'),
                items: ['Borç', 'Alacak'],
                onChanged: (val) =>
                    setState(() => _selectedTransactionType = val as String?),
                isRequired: true,
                color: requiredColor,
                itemLabels: {
                  'Borç': tr('accounts.table.type_debit'),
                  'Alacak': tr('accounts.table.type_credit'),
                },
              ),
              _buildTextField(
                controller: _dateController,
                label: tr('common.date'),
                hint: tr('common.placeholder.date'),
                isRequired: true,
                color: requiredColor,
                onTap: () => _selectDate(context),
                suffixIcon: _dateController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 18,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            _dateController.clear();
                            _selectedDate = null;
                          });
                        },
                        tooltip: tr('common.clear'),
                      )
                    : Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
              ),
            ]),
            const SizedBox(height: 16),
            _buildRow(isWide, [
              _buildTextField(
                controller: _amountController,
                label: tr('common.amount'),
                isNumeric: true,
                isRequired: true,
                color: requiredColor,
                focusNode: _amountFocusNode,
                maxDecimalDigits: _genelAyarlar.fiyatOndalik,
              ),
              _buildDropdown(
                value: _currency,
                label: tr('common.currency_unit'),
                items: _genelAyarlar.kullanilanParaBirimleri,
                onChanged: (val) => setState(() => _currency = val as String),
                isRequired: true,
                color: requiredColor,
              ),
            ]),
            const SizedBox(height: 16),
            _buildDueDateField(theme),
          ],
        );
      },
    );
  }

  Widget _buildDueDateField(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            controller: _dueDateController,
            label: tr('accounts.transaction.due_date'),
            hint: "${tr('common.placeholder.date')} (${tr('common.optional')})",
            readOnly: true,
            onTap: () => _selectDate(context, isDueDate: true),
            color: _selectedDueDate != null
                ? Colors.orange.shade700
                : Colors.grey.shade400,
            suffixIcon: _selectedDueDate != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                    onPressed: _clearDueDate,
                    tooltip: tr('common.clear'),
                  )
                : Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(ThemeData theme) {
    final color = Colors.teal.shade700;

    return _buildTextField(
      controller: _descriptionController,
      label: tr('shipment.field.description'),
      color: color,
      maxLines: 3,
      minLines: 1,
      focusNode: _descriptionFocusNode,
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.duzenlenecekIslem != null
                      ? tr('common.update')
                      : tr('common.save'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
        ),
      ],
    );
  }

  // --- Helper Widgets ---

  Widget _buildRow(bool isWide, List<Widget> children) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            children.map<Widget>((c) {
                if (c is Expanded) return c; // Already expanded
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: c,
                  ),
                );
              }).toList()
              ..last = (children.last is Expanded
                  ? children.last
                  : Expanded(child: children.last)),
      );
    } else {
      return Column(
        children: children
            .map(
              (c) =>
                  Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
            )
            .toList(),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumeric = false,
    bool isRequired = false,
    Color? color,
    String? hint,
    FocusNode? focusNode,
    int? maxLines = 1,
    int? minLines,
    bool readOnly = false,
    int? maxDecimalDigits,
    Widget? suffixIcon,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          onTap: onTap,
          mouseCursor: onTap != null ? SystemMouseCursors.click : null,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          maxLines: maxLines,
          minLines: minLines,
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
          inputFormatters: isNumeric
              ? [
                  CurrencyInputFormatter(
                    binlik: _genelAyarlar.binlikAyiraci,
                    ondalik: _genelAyarlar.ondalikAyiraci,
                    maxDecimalDigits: maxDecimalDigits,
                  ),
                  LengthLimitingTextInputFormatter(20),
                ]
              : null,
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return tr('validation.required');
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.withValues(alpha: 0.3),
              fontSize: 16,
            ),
            suffixIcon: suffixIcon,
            suffixIconConstraints: suffixIcon != null
                ? const BoxConstraints(minWidth: 24, minHeight: 24)
                : null,
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color: effectiveColor.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: effectiveColor.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: effectiveColor, width: 2),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required dynamic value,
    required String label,
    required List<dynamic> items,
    required ValueChanged<dynamic> onChanged,
    bool isRequired = false,
    String? hint,
    Color? color,
    Map<dynamic, String>? itemLabels,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<dynamic>(
          mouseCursor: WidgetStateMouseCursor.clickable,
          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
          key: ValueKey(value),
          initialValue: items.contains(value)
              ? value
              : null, // Changed from value to initialValue
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.withValues(alpha: 0.3),
              fontSize: 16,
            ),
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color: effectiveColor.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: effectiveColor.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: effectiveColor, width: 2),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    itemLabels?[item] ?? item.toString(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down, color: effectiveColor),
          validator: isRequired
              ? (value) {
                  if (value == null || (value is String && value.isEmpty)) {
                    return tr('validation.required');
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }
}
