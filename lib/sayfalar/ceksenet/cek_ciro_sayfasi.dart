import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import 'modeller/cek_model.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../servisler/cekler_veritabani_servisi.dart';
import '../../bilesenler/tek_tarih_secici_dialog.dart';
import '../carihesaplar/modeller/cari_hesap_model.dart';
import '../../bilesenler/akilli_aciklama_input.dart';

class CekCiroSayfasi extends StatefulWidget {
  final CekModel cek;
  final Map<String, dynamic>? transaction;

  const CekCiroSayfasi({super.key, required this.cek, this.transaction});

  @override
  State<CekCiroSayfasi> createState() => _CekCiroSayfasiState();
}

class _CekCiroSayfasiState extends State<CekCiroSayfasi> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  // Controllers
  final _dateController = TextEditingController();
  final _accountCodeController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Focus Nodes
  final _accountCodeFocusNode = FocusNode();

  // State
  DateTime _selectedDate = DateTime.now();

  final FocusNode _pageFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _accountNameController.text = '';
    _accountCodeController.text = '';
    _descriptionController.text = '';

    if (widget.transaction != null) {
      _accountNameController.text = widget.transaction!['source_dest'] ?? '';
      _descriptionController.text = widget.transaction!['description'] ?? '';
      // Tarih parse
      try {
        final dateStr = widget.transaction!['date'];
        if (dateStr != null) {
          _selectedDate = DateFormat('dd.MM.yyyy HH:mm').parse(dateStr);
          _dateController.text = DateFormat('dd.MM.yyyy').format(_selectedDate);
        }
      } catch (_) {}
    } else {
      _dateController.text = DateFormat('dd.MM.yyyy').format(_selectedDate);
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      if (mounted) setState(() => _genelAyarlar = settings);
    } catch (e) {
      debugPrint('Ayarlar yüklenirken hata: $e');
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _accountCodeController.dispose();
    _accountNameController.dispose();
    _descriptionController.dispose();
    _accountCodeFocusNode.dispose();
    _pageFocusNode.dispose();
    super.dispose();
  }

  void _showCariHesapSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _CariHesapSearchDialog(
        onSelect: (cari) {
          setState(() {
            _accountCodeController.text = cari.kodNo;
            _accountNameController.text = cari.adi;
          });
        },
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(
        initialDate: _selectedDate,
        title: tr('common.date'),
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  Future<void> _handleEndorse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Alındığı cariye ciro edilemez kontrolü
    if (_accountCodeController.text == widget.cek.cariKod) {
      MesajYardimcisi.hataGoster(
        context,
        tr('checks.endorse.error.self_endorse'),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = prefs.getString('current_username') ?? 'Sistem';

      if (widget.transaction != null) {
        await CeklerVeritabaniServisi().cekIsleminiGuncelle(
          islemId: widget.transaction!['id'],
          tutar: widget.cek.tutar,
          aciklama: _descriptionController.text,
          tarih: _selectedDate,
          kullanici: currentUser,
        );
      } else {
        await CeklerVeritabaniServisi().cekCiroEt(
          cekId: widget.cek.id,
          cariKodu: _accountCodeController.text,
          cariAdi: _accountNameController.text,
          aciklama: _descriptionController.text,
          tarih: _selectedDate,
          kullanici: currentUser,
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
        MesajYardimcisi.basariGoster(
          context,
          widget.transaction != null
              ? tr('common.updated_successfully')
              : tr('checks.endorse.success'),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // ESC tuşu ile kapat
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
        return;
      }
      // Tek Enter ile ciro et (form geçerliyse)
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        // Form geçerli mi kontrol et ve ciro et
        if (_formKey.currentState?.validate() == true) {
          _handleEndorse();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bool isCompact = mediaQuery.size.width < 700;
    final double contentPadding = isCompact ? 12 : 16;
    final double sectionGap = isCompact ? 20 : 32;

    return KeyboardListener(
      focusNode: _pageFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
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
            leadingWidth: isCompact ? 72 : 80,
            title: Text(
              widget.transaction != null
                  ? tr('checks.actions.edit_endorse_title')
                  : tr('checks.endorse.title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: isCompact ? 19 : 21,
              ),
            ),
            centerTitle: false,
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(contentPadding),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCheckInfoHeader(theme, compact: isCompact),
                            SizedBox(height: sectionGap),
                            _buildSection(
                              theme,
                              title: tr('checks.endorse.endorsement_info'),
                              child: _buildFormFields(theme),
                              icon: Icons.swap_horiz_rounded,
                              color: Colors.blue.shade700,
                              compact: isCompact,
                            ),
                            SizedBox(height: isCompact ? 20 : 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _buildBottomBar(theme, compact: isCompact),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckInfoHeader(ThemeData theme, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 8 : 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Colors.blue.shade700,
                  size: compact ? 20 : 24,
                ),
              ),
              SizedBox(width: compact ? 12 : 16),
              Expanded(
                child: Text(
                  tr('checks.endorse.check_info'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: compact ? 16 : 18,
                  ),
                ),
              ),
              // Tutar Badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 16,
                  vertical: compact ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  '${FormatYardimcisi.sayiFormatlaOndalikli(widget.cek.tutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${widget.cek.paraBirimi}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 14 : 16,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 14 : 20),
          // Two Column Layout
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 500) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildInfoRow(
                            tr('checks.table.type'),
                            widget.cek.tur,
                          ),
                          _buildInfoRow(
                            tr('checks.form.customer_code.label'),
                            widget.cek.cariKod,
                          ),
                          _buildInfoRow(
                            tr('checks.form.issue_date.label'),
                            widget.cek.duzenlenmeTarihi,
                          ),
                          _buildInfoRow(
                            tr('checks.form.check_no.label'),
                            widget.cek.cekNo,
                          ),
                          _buildInfoRow(
                            tr('checks.form.description.label'),
                            widget.cek.aciklama,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        children: [
                          _buildInfoRow(
                            tr('checks.table.collection'),
                            widget.cek.tahsilat.isEmpty
                                ? tr('checks.collect.not_collected')
                                : widget.cek.tahsilat,
                          ),
                          _buildInfoRow(
                            tr('checks.form.customer_name.label'),
                            widget.cek.cariAdi,
                          ),
                          _buildInfoRow(
                            tr('checks.form.due_date.label'),
                            widget.cek.kesideTarihi,
                          ),
                          _buildInfoRow(
                            tr('checks.form.bank.label'),
                            widget.cek.banka,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildInfoRow(tr('checks.table.type'), widget.cek.tur),
                    _buildInfoRow(
                      tr('checks.table.collection'),
                      widget.cek.tahsilat.isEmpty
                          ? tr('checks.collect.not_collected')
                          : widget.cek.tahsilat,
                    ),
                    _buildInfoRow(
                      tr('checks.form.customer_code.label'),
                      widget.cek.cariKod,
                    ),
                    _buildInfoRow(
                      tr('checks.form.customer_name.label'),
                      widget.cek.cariAdi,
                    ),
                    _buildInfoRow(
                      tr('checks.form.issue_date.label'),
                      widget.cek.duzenlenmeTarihi,
                    ),
                    _buildInfoRow(
                      tr('checks.form.due_date.label'),
                      widget.cek.kesideTarihi,
                    ),
                    _buildInfoRow(
                      tr('checks.form.check_no.label'),
                      widget.cek.cekNo,
                    ),
                    _buildInfoRow(
                      tr('checks.form.bank.label'),
                      widget.cek.banka,
                    ),
                    _buildInfoRow(
                      tr('checks.form.description.label'),
                      widget.cek.aciklama,
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isAmount = false}) {
    final bool isNarrow = MediaQuery.of(context).size.width < 480;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isNarrow ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isNarrow ? 120 : 160,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
                fontSize: isNarrow ? 13 : 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                color: isAmount
                    ? Colors.green.shade700
                    : const Color(0xFF202124),
                fontWeight: isAmount ? FontWeight.w700 : FontWeight.w500,
                fontSize: isNarrow ? 13 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required String title,
    required Widget child,
    required IconData icon,
    required Color color,
    bool compact = false,
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
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 8 : 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: compact ? 18 : 20),
              ),
              SizedBox(width: compact ? 12 : 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontSize: compact ? 17 : 21,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 16 : 24),
          child,
        ],
      ),
    );
  }

  Widget _buildFormFields(ThemeData theme) {
    final requiredColor = Colors.red.shade700;
    final optionalColor = Colors.blue.shade700;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Column(
          children: [
            // Cari Hesap Kodu & Cari Hesap Adı
            _buildRow(isWide, [
              _buildAutocompleteField(
                controller: _accountCodeController,
                label: tr('checks.endorse.customer_code'),
                isRequired: true,
                color: requiredColor,
                focusNode: _accountCodeFocusNode,
              ),
              _buildTextField(
                controller: _accountNameController,
                label: tr('checks.endorse.customer_name'),
                isRequired: true,
                color: requiredColor,
                readOnly: true,
                noGrayBackground: true,
              ),
            ]),
            const SizedBox(height: 16),
            // Açıklama & Tarih
            _buildRow(isWide, [
              AkilliAciklamaInput(
                controller: _descriptionController,
                label: tr('checks.endorse.description'),
                category: 'check_endorse_description',
                color: optionalColor,
                defaultItems: [
                  tr('smart_select.check_issue.desc.1'),
                  tr('smart_select.check_issue.desc.2'),
                  tr('smart_select.check_issue.desc.3'),
                  tr('smart_select.check_issue.desc.4'),
                  tr('smart_select.check_issue.desc.5'),
                ],
              ),
              _buildDateField(
                controller: _dateController,
                label: tr('checks.endorse.date'),
                onTap: _selectDate,
                isRequired: true,
                color: requiredColor,
              ),
            ]),
          ],
        );
      },
    );
  }

  Widget _buildBottomBar(ThemeData theme, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool stackButtons = constraints.maxWidth < 520;

              final cancelButton = OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 18 : 24,
                    vertical: compact ? 14 : 16,
                  ),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  tr('common.cancel'),
                  style: TextStyle(
                    color: const Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 14 : 15,
                  ),
                ),
              );

              final saveButton = ElevatedButton(
                onPressed: _isLoading ? null : _handleEndorse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA4335),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 24 : 32,
                    vertical: compact ? 14 : 16,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        tr('checks.actions.endorse'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: compact ? 15 : 16,
                        ),
                      ),
              );

              if (stackButtons) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: double.infinity, child: cancelButton),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: saveButton),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [cancelButton, const SizedBox(width: 12), saveButton],
              );
            },
          ),
        ),
      ),
    );
  }

  // Helper Widgets
  Widget _buildRow(bool isWide, List<Widget> children) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            children
                .map(
                  (c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: c,
                    ),
                  ),
                )
                .toList()
              ..last = Expanded(child: children.last),
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
    bool isRequired = false,
    Color? color,
    String? hint,
    FocusNode? focusNode,
    bool readOnly = false,
    bool noGrayBackground = false,
    int maxLines = 1,
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
          maxLines: maxLines,
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
          validator: isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return tr('validation.required');
                  } else {
                    return null;
                  }
                }
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.withValues(alpha: 0.3),
              fontSize: 16,
            ),
            filled: readOnly && !noGrayBackground,
            fillColor: readOnly && !noGrayBackground
                ? Colors.grey.shade100
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
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String label,
    required bool isRequired,
    required Color color,
    FocusNode? focusNode,
  }) {
    final theme = Theme.of(context);

    Future<Iterable<Map<String, String>>> search(String query) async {
      if (query.isEmpty) {
        return [];
      }
      try {
        final items = await CariHesaplarVeritabaniServisi().cariHesaplariGetir(
          aramaTerimi: query,
          sayfaBasinaKayit: 10,
        );
        return items.map((e) {
          final addressParts = [
            e.fatIlce,
            e.fatSehir,
          ].where((s) => s.isNotEmpty).toList();
          final address = addressParts.join(' / ');
          return {
            'code': e.kodNo,
            'name': e.adi,
            'id': e.id.toString(),
            'address': address,
          };
        }).toList();
      } catch (e) {
        debugPrint('Arama hatası: $e');
        return [];
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isRequired ? '$label *' : label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              tr('common.search_fields.code_name'),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        RawAutocomplete<Map<String, String>>(
          focusNode: focusNode,
          textEditingController: controller,
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.isEmpty) return [];
            return await search(textEditingValue.text);
          },
          displayStringForOption: (option) => option['code']!,
          onSelected: (option) {
            setState(() {
              controller.text = option['code']!;
              _accountNameController.text = option['name']!;
            });
          },
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
                  validator: isRequired
                      ? (value) {
                          if (value == null || value.isEmpty) {
                            return tr('validation.required');
                          }
                          return null;
                        }
                      : null,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(Icons.search, color: color),
                      onPressed: _showCariHesapSearchDialog,
                    ),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: color.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: color.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: color, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onFieldSubmitted: (value) => onFieldSubmitted(),
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 250,
                    maxWidth: 400,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return InkWell(
                        mouseCursor: WidgetStateMouseCursor.clickable,
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option['name']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Color(0xFF202124),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${option['code']!}${option['address'] != null && option['address']!.isNotEmpty ? ' • ${option['address']}' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
    bool isRequired = false,
    Color? color,
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
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                mouseCursor: SystemMouseCursors.click,
                child: IgnorePointer(
                  child: TextFormField(
                    controller: controller,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
                    validator: isRequired
                        ? (value) {
                            if (value == null || value.isEmpty) {
                              return tr('validation.required');
                            }
                            return null;
                          }
                        : null,
                    decoration: InputDecoration(
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 20, color: Colors.red),
                onPressed: () {
                  setState(() {
                    controller.clear();
                  });
                },
                tooltip: tr('common.clear'),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: effectiveColor,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// --- CARİ HESAP SEARCH DIALOG ---
class _CariHesapSearchDialog extends StatefulWidget {
  final Function(CariHesapModel) onSelect;
  const _CariHesapSearchDialog({required this.onSelect});

  @override
  State<_CariHesapSearchDialog> createState() => _CariHesapSearchDialogState();
}

class _CariHesapSearchDialogState extends State<_CariHesapSearchDialog> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<CariHesapModel> _items = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
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
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final results = await CariHesaplarVeritabaniServisi().cariHesaplariGetir(
        aramaTerimi: query,
        sayfaBasinaKayit: 50,
        aktifMi: true,
      );
      if (mounted) {
        setState(() {
          _items = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
        child: Column(
          children: [
            _buildDialogHeader(
              tr('checks.endorse.select_customer'),
              tr('common.search'),
            ),
            const SizedBox(height: 24),
            _buildSearchInput(),
            const SizedBox(height: 20),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
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
                fontWeight: FontWeight.w600,
                color: Color(0xFF9AA0A6),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              mouseCursor: WidgetStateMouseCursor.clickable,
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.close,
                  size: 20,
                  color: Color(0xFF606368),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchInput() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: tr('common.search'),
        prefixIcon: const Icon(Icons.search, color: Color(0xFF9AA0A6)),
        filled: true,
        fillColor: const Color(0xFFF1F3F4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return Center(
        child: Text(
          tr('common.no_results'),
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _items[index];
        return ListTile(
          title: Text(
            item.adi,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(item.kodNo),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF9AA0A6)),
          onTap: () {
            widget.onSelect(item);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}
