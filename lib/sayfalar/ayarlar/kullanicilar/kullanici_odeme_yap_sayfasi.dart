import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../bilesenler/tek_tarih_secici_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import 'modeller/kullanici_model.dart';
import '../../../yardimcilar/mesaj_yardimcisi.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../../servisler/ayarlar_veritabani_servisi.dart';
import '../../../servisler/kasalar_veritabani_servisi.dart';
import '../../../servisler/bankalar_veritabani_servisi.dart';
import '../../../servisler/kredi_kartlari_veritabani_servisi.dart';
import '../../kasalar/modeller/kasa_model.dart';
import '../../bankalar/modeller/banka_model.dart';
import '../../kredikartlari/modeller/kredi_karti_model.dart';
import '../../../../bilesenler/akilli_aciklama_input.dart';
import '../../../servisler/personel_islemleri_veritabani_servisi.dart';

class KullaniciOdemeYapSayfasi extends StatefulWidget {
  final KullaniciModel kullanici;

  const KullaniciOdemeYapSayfasi({super.key, required this.kullanici});

  @override
  State<KullaniciOdemeYapSayfasi> createState() =>
      _KullaniciOdemeYapSayfasiState();
}

class _KullaniciOdemeYapSayfasiState extends State<KullaniciOdemeYapSayfasi> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  // Controllers
  final _dateController = TextEditingController();
  final _accountCodeController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Focus Nodes
  final _accountCodeFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();

  // State
  String _selectedSource = 'cash';
  DateTime _selectedDate = DateTime.now();
  int? _selectedAccountId;

  // Source options
  final List<Map<String, String>> _sourceOptions = [
    {'value': 'cash', 'key': 'settings.users.payment.source.cash'},
    {'value': 'bank', 'key': 'settings.users.payment.source.bank'},
    {
      'value': 'credit_card',
      'key': 'settings.users.payment.source.credit_card',
    },
  ];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd.MM.yyyy').format(_selectedDate);
    _loadSettings();
    _attachAmountFormatter();
  }

  void _attachAmountFormatter() {
    _amountFocusNode.addListener(() {
      if (!_amountFocusNode.hasFocus) {
        final text = _amountController.text.trim();
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
        _amountController
          ..text = formatted
          ..selection = TextSelection.collapsed(offset: formatted.length);
      }
    });
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
    _amountController.dispose();
    _descriptionController.dispose();
    _accountCodeFocusNode.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _clearAccountFields() {
    setState(() {
      _accountCodeController.clear();
      _accountNameController.clear();
      _selectedAccountId = null;
    });
  }

  Future<void> _openSearchDialog() async {
    switch (_selectedSource) {
      case 'cash':
        _showKasaSearchDialog();
        break;
      case 'bank':
        _showBankaSearchDialog();
        break;
      case 'credit_card':
        _showKrediKartiSearchDialog();
        break;
      default:
        MesajYardimcisi.bilgiGoster(context, tr('common.feature_coming_soon'));
    }
  }

  void _showKasaSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _KasaSearchDialog(
        onSelect: (kasa) {
          setState(() {
            _accountCodeController.text = kasa.kod;
            _accountNameController.text = kasa.ad;
            _selectedAccountId = kasa.id;
          });
        },
      ),
    );
  }

  void _showBankaSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _BankaSearchDialog(
        onSelect: (banka) {
          setState(() {
            _accountCodeController.text = banka.kod;
            _accountNameController.text = banka.ad;
            _selectedAccountId = banka.id;
          });
        },
      ),
    );
  }

  void _showKrediKartiSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _KrediKartiSearchDialog(
        onSelect: (krediKarti) {
          setState(() {
            _accountCodeController.text = krediKarti.kod;
            _accountNameController.text = krediKarti.ad;
            _selectedAccountId = krediKarti.id;
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
        title: tr('common.date_select'),
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_accountCodeController.text.isEmpty || _selectedAccountId == null) {
        throw Exception(tr('settings.users.payment.error.no_account'));
      }

      await _loadSettings(); // Ensure settings loaded for correct parsing

      final amount = FormatYardimcisi.parseDouble(
        _amountController.text,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );

      if (amount <= 0) {
        throw Exception(tr('settings.users.payment.error.invalid_amount'));
      }

      final prefs = await SharedPreferences.getInstance();
      final currentUser = prefs.getString('current_username') ?? 'Sistem';

      // Servisi kullanarak ödeme işlemini yap
      await PersonelIslemleriVeritabaniServisi().odemeYap(
        kullanici: widget.kullanici,
        tutar: amount,
        tarih: _selectedDate,
        aciklama: _descriptionController.text,
        kaynakTuru: _selectedSource,
        kaynakId: _selectedAccountId.toString(),
        // Not: Service içinde int.parse yapılıyor ama ID burada zaten elimizde.
        // Yine de service metodunu değiştirmemek için String olarak gönderiyorum.
        kaynakAdi: _accountNameController.text,
        islemYapanKullaniciAdi: currentUser,
      );

      if (mounted) {
        MesajYardimcisi.basariGoster(context, tr('common.saved_successfully'));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

    return CallbackShortcuts(
      bindings: {
        // ESC: Geri dön
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
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Focus(
          autofocus: false,
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
                tr('settings.users.actions.make_payment'),
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
                              _buildHeader(theme, compact: isCompact),
                              SizedBox(height: sectionGap),
                              _buildSection(
                                theme,
                                title: tr(
                                  'settings.users.actions.make_payment',
                                ),
                                child: _buildFormFields(theme),
                                icon: Icons.payments_outlined,
                                color: Colors.green.shade700,
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
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, {bool compact = false}) {
    final paraBirimi = widget.kullanici.paraBirimi ?? 'TRY';

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool stack = constraints.maxWidth < 640;

          final codeBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('settings.users.payment.personnel_code'),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.kullanici.id,
                style: TextStyle(
                  fontSize: compact ? 15 : 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF202124),
                ),
              ),
            ],
          );

          final nameBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('settings.users.payment.personnel_name'),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.kullanici.ad} ${widget.kullanici.soyad}',
                style: TextStyle(
                  fontSize: compact ? 15 : 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF202124),
                ),
              ),
            ],
          );

          final balanceBlock = Column(
            crossAxisAlignment: stack
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Text(
                tr('settings.users.payment.balance_credit'),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${FormatYardimcisi.sayiFormatlaOndalikli(widget.kullanici.bakiyeAlacak, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} $paraBirimi',
                style: TextStyle(
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.w800,
                  color: widget.kullanici.bakiyeAlacak >= 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
            ],
          );

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                codeBlock,
                const SizedBox(height: 10),
                nameBlock,
                const Divider(height: 18),
                balanceBlock,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: codeBlock),
              Container(height: 40, width: 1, color: Colors.grey.shade300),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24),
                  child: nameBlock,
                ),
              ),
              Container(height: 40, width: 1, color: Colors.grey.shade300),
              Expanded(child: balanceBlock),
            ],
          );
        },
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
            // Yer (Source)
            _buildDropdown<String>(
              value: _selectedSource,
              label: tr('settings.users.payment.source'),
              items: _sourceOptions.map((e) => e['value']!).toList(),
              itemLabels: Map.fromEntries(
                _sourceOptions.map((e) => MapEntry(e['value']!, tr(e['key']!))),
              ),
              onChanged: (val) {
                setState(() {
                  _selectedSource = val!;
                  _clearAccountFields();
                });
              },
              isRequired: true,
              color: requiredColor,
            ),
            const SizedBox(height: 16),
            // Hesap Kodu & Hesap Adı
            _buildRow(isWide, [
              _buildAutocompleteField(
                controller: _accountCodeController,
                label: tr('settings.users.payment.account_code'),
                isRequired: true,
                color: requiredColor,
                focusNode: _accountCodeFocusNode,
              ),
              _buildTextField(
                controller: _accountNameController,
                label: tr('settings.users.payment.account_name'),
                isRequired: true,
                color: requiredColor,
                readOnly: true,
                noGrayBackground: true,
              ),
            ]),
            const SizedBox(height: 16),
            // Tutar & Tarih
            _buildRow(isWide, [
              _buildTextField(
                controller: _amountController,
                label: tr('settings.users.payment.amount'),
                isNumeric: true,
                isRequired: true,
                color: requiredColor,
                focusNode: _amountFocusNode,
                suffix: widget.kullanici.paraBirimi ?? 'TRY',
              ),
              _buildDateField(
                controller: _dateController,
                label: tr('settings.users.payment.date'),
                onTap: _selectDate,
                isRequired: true,
                color: requiredColor,
              ),
            ]),
            const SizedBox(height: 16),
            // Açıklama (Dropdown)
            AkilliAciklamaInput(
              controller: _descriptionController,
              label: tr('settings.users.payment.description'),
              category: 'user_payment_description',
              color: optionalColor,
              defaultItems: [
                tr('settings.users.payment.desc.salary'),
                tr('settings.users.payment.desc.bonus'),
                tr('settings.users.payment.desc.advance'),
                tr('settings.users.payment.desc.expense'),
                tr('settings.users.payment.desc.other'),
              ],
            ),
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
                onPressed: _isLoading ? null : _handleSave,
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
                        tr('common.save'),
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
    bool isNumeric = false,
    bool isRequired = false,
    Color? color,
    String? hint,
    FocusNode? focusNode,
    bool readOnly = false,
    bool noGrayBackground = false,
    int maxLines = 1,
    String? suffix,
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
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
          inputFormatters: isNumeric
              ? [
                  CurrencyInputFormatter(
                    binlik: _genelAyarlar.binlikAyiraci,
                    ondalik: _genelAyarlar.ondalikAyiraci,
                    maxDecimalDigits: _genelAyarlar.fiyatOndalik,
                  ),
                  LengthLimitingTextInputFormatter(20),
                ]
              : null,
          validator: isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return tr('validation.required');
                  }
                  return null;
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
            suffixText: suffix,
            suffixStyle: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 14,
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

    // Helpers to get data based on source
    Future<Iterable<Map<String, String>>> search(String query) async {
      if (query.isEmpty) return [];

      try {
        List<Map<String, String>> results = [];

        switch (_selectedSource) {
          case 'cash':
            final items = await KasalarVeritabaniServisi().kasalariGetir(
              aramaKelimesi: query,
              sayfaBasinaKayit: 10,
            );
            results = items
                .map(
                  (e) => {
                    'code': e.kod,
                    'name': e.ad,
                    'type': 'Kasa',
                    'id': e.id.toString(),
                    'address': '',
                  },
                )
                .toList();
            break;

          case 'bank':
            final items = await BankalarVeritabaniServisi().bankalariGetir(
              aramaKelimesi: query,
              sayfaBasinaKayit: 10,
            );
            results = items
                .map(
                  (e) => {
                    'code': e.kod,
                    'name': e.ad,
                    'type': 'Banka',
                    'id': e.id.toString(),
                    'address': '',
                  },
                )
                .toList();
            break;

          case 'credit_card':
            final items = await KrediKartlariVeritabaniServisi()
                .krediKartlariniGetir(
                  aramaKelimesi: query,
                  sayfaBasinaKayit: 10,
                );
            results = items
                .map(
                  (e) => {
                    'code': e.kod,
                    'name': e.ad,
                    'type': 'Kredi Kartı',
                    'id': e.id.toString(),
                    'address': '',
                  },
                )
                .toList();
            break;

          default:
            return [];
        }
        return results;
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
              _selectedAccountId = int.tryParse(option['id'] ?? '');
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
                      onPressed: _openSearchDialog,
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
                  constraints: BoxConstraints(maxHeight: 250, maxWidth: 400),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return InkWell(
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
                    _selectedDate = DateTime.now();
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

  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    bool isRequired = false,
    Color? color,
    Map<T, String>? itemLabels,
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
        DropdownButtonFormField<T>(
          // ignore: deprecated_member_use
          value: value,
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
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
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
                  if (value == null) return tr('validation.required');
                  return null;
                }
              : null,
        ),
      ],
    );
  }
}

// CurrencyInputFormatter
class CurrencyInputFormatter extends TextInputFormatter {
  final String binlik;
  final String ondalik;
  final int maxDecimalDigits;

  CurrencyInputFormatter({
    required this.binlik,
    required this.ondalik,
    required this.maxDecimalDigits,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String text = newValue.text;

    // Allow only digits and decimal separator
    final regex = RegExp('[^0-9$ondalik]');
    text = text.replaceAll(regex, '');

    // Ensure only one decimal separator
    final parts = text.split(ondalik);
    if (parts.length > 2) {
      text = '${parts[0]}$ondalik${parts.sublist(1).join('')}';
    }

    // Limit decimal digits
    if (parts.length == 2 && parts[1].length > maxDecimalDigits) {
      text = '${parts[0]}$ondalik${parts[1].substring(0, maxDecimalDigits)}';
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// --- KASA SEARCH DIALOG ---
class _KasaSearchDialog extends StatefulWidget {
  final Function(KasaModel) onSelect;
  const _KasaSearchDialog({required this.onSelect});

  @override
  State<_KasaSearchDialog> createState() => _KasaSearchDialogState();
}

class _KasaSearchDialogState extends State<_KasaSearchDialog> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<KasaModel> _items = [];
  bool _isLoading = false;
  Timer? _debounce;
  static const Color _primaryColor = Color(0xFF2C3E50);

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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await KasalarVeritabaniServisi().kasalariGetir(
        aramaKelimesi: query,
      );
      if (mounted) {
        setState(() {
          _items = results.where((k) => k.aktifMi).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
              tr('cashregisters.search_title'),
              tr('cashregisters.search_subtitle'),
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
                fontWeight: FontWeight.w700,
                color: Color(0xFF9AA0A6),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.close, size: 22, color: Color(0xFF3C4043)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchInput() {
    return Column(
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
            hintText: tr('cashregisters.search_placeholder'),
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
    );
  }

  Widget _buildList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 48,
              color: Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 16),
            Text(
              tr('cashregisters.no_cashregisters_found'),
              style: const TextStyle(fontSize: 16, color: Color(0xFF606368)),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
      itemBuilder: (context, index) {
        final item = _items[index];
        return InkWell(
          onTap: () {
            widget.onSelect(item);
            Navigator.pop(context);
          },
          hoverColor: const Color(0xFFF5F7FA),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                    Icons.account_balance_wallet,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.ad,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.kod,
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
    );
  }
}

// --- BANKA SEARCH DIALOG ---
class _BankaSearchDialog extends StatefulWidget {
  final Function(BankaModel) onSelect;
  const _BankaSearchDialog({required this.onSelect});

  @override
  State<_BankaSearchDialog> createState() => _BankaSearchDialogState();
}

class _BankaSearchDialogState extends State<_BankaSearchDialog> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<BankaModel> _items = [];
  bool _isLoading = false;
  Timer? _debounce;
  static const Color _primaryColor = Color(0xFF2C3E50);

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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await BankalarVeritabaniServisi().bankalariGetir(
        aramaKelimesi: query,
      );
      if (mounted) {
        setState(() {
          _items = results.where((b) => b.aktifMi).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
              tr('banks.search_title'),
              tr('banks.search_subtitle'),
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
                fontWeight: FontWeight.w700,
                color: Color(0xFF9AA0A6),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.close, size: 22, color: Color(0xFF3C4043)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchInput() {
    return Column(
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
            hintText: tr('banks.search_placeholder'),
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
    );
  }

  Widget _buildList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_outlined,
              size: 48,
              color: Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 16),
            Text(
              tr('banks.no_banks_found'),
              style: const TextStyle(fontSize: 16, color: Color(0xFF606368)),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
      itemBuilder: (context, index) {
        final item = _items[index];
        return InkWell(
          onTap: () {
            widget.onSelect(item);
            Navigator.pop(context);
          },
          hoverColor: const Color(0xFFF5F7FA),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                    Icons.account_balance,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.ad,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.kod,
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
    );
  }
}

// --- KREDİ KARTI SEARCH DIALOG ---
class _KrediKartiSearchDialog extends StatefulWidget {
  final Function(KrediKartiModel) onSelect;
  const _KrediKartiSearchDialog({required this.onSelect});

  @override
  State<_KrediKartiSearchDialog> createState() =>
      _KrediKartiSearchDialogState();
}

class _KrediKartiSearchDialogState extends State<_KrediKartiSearchDialog> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<KrediKartiModel> _items = [];
  bool _isLoading = false;
  Timer? _debounce;
  static const Color _primaryColor = Color(0xFF2C3E50);

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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await KrediKartlariVeritabaniServisi()
          .krediKartlariniGetir(aramaKelimesi: query);
      if (mounted) {
        setState(() {
          _items = results.where((k) => k.aktifMi).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
              tr('creditcards.search_title'),
              tr('creditcards.search_subtitle'),
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
                fontWeight: FontWeight.w700,
                color: Color(0xFF9AA0A6),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.close, size: 22, color: Color(0xFF3C4043)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchInput() {
    return Column(
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
            hintText: tr('creditcards.search_placeholder'),
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
    );
  }

  Widget _buildList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.credit_card_outlined,
              size: 48,
              color: Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 16),
            Text(
              tr('creditcards.no_creditcards_found'),
              style: const TextStyle(fontSize: 16, color: Color(0xFF606368)),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
      itemBuilder: (context, index) {
        final item = _items[index];
        return InkWell(
          onTap: () {
            widget.onSelect(item);
            Navigator.pop(context);
          },
          hoverColor: const Color(0xFFF5F7FA),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                    Icons.credit_card,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.ad,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.kod,
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
    );
  }
}
