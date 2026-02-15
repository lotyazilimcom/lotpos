import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import 'modeller/cari_hesap_model.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../../bilesenler/onay_dialog.dart';
import '../../servisler/sayfa_senkronizasyon_servisi.dart';

class CariAcilisDevriDuzenleSayfasi extends StatefulWidget {
  final int transactionId;
  final CariHesapModel cariHesap;
  final double currentAmount;
  final bool isBorc;
  final double currentKur;
  final String description;

  const CariAcilisDevriDuzenleSayfasi({
    super.key,
    required this.transactionId,
    required this.cariHesap,
    required this.currentAmount,
    required this.isBorc,
    required this.currentKur,
    required this.description,
  });

  @override
  State<CariAcilisDevriDuzenleSayfasi> createState() =>
      _CariAcilisDevriDuzenleSayfasiState();
}

class _CariAcilisDevriDuzenleSayfasiState
    extends State<CariAcilisDevriDuzenleSayfasi> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _kurController;
  late TextEditingController _descriptionController;
  bool _isLoading = false;
  late bool _isBorc;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  @override
  void initState() {
    super.initState();
    _isBorc = widget.isBorc;
    _amountController = TextEditingController(
      text: FormatYardimcisi.sayiFormatlaOndalikli(
        widget.currentAmount,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: _genelAyarlar.fiyatOndalik,
      ),
    );
    _kurController = TextEditingController(
      text: FormatYardimcisi.sayiFormatlaOndalikli(
        widget.currentKur,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: 4,
      ),
    );
    _descriptionController = TextEditingController(text: widget.description);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      setState(() {
        _genelAyarlar = settings;
        // Re-format with loaded settings
        _amountController.text = FormatYardimcisi.sayiFormatlaOndalikli(
          widget.currentAmount,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.fiyatOndalik,
        );
        _kurController.text = FormatYardimcisi.sayiFormatlaOndalikli(
          widget.currentKur,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: 4,
        );
      });
    } catch (e) {
      debugPrint('Ayarlar yüklenirken hata: $e');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _kurController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;

    // Onay iste
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr('accounts.opening_balance.confirm_update'),
        onayButonMetni: tr('common.save'),
        iptalButonMetni: tr('common.cancel'),
        onOnay: () {},
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newAmount = FormatYardimcisi.parseDouble(
        _amountController.text,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );
      final newDesc = _descriptionController.text.trim();

      await CariHesaplarVeritabaniServisi().cariDevirKaydet(
        cariId: widget.cariHesap.id,
        tutar: newAmount,
        isBorc: _isBorc,
        aciklama: newDesc,
        tarih: DateTime.now(), // Devir tarihi genelde bugündür
        kullanici: 'Sistem',
        duzenlenecekIslem: {
          'id': widget.transactionId,
          'amount': widget.currentAmount,
          'type': widget.isBorc ? 'Borç' : 'Alacak',
        },
      );

      if (!mounted) return;

      MesajYardimcisi.basariGoster(
        context,
        tr('accounts.opening_balance.success.updated'),
      );

      SayfaSenkronizasyonServisi().veriDegisti('cari');

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(
        context,
        '${tr('common.error')}: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleClear() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_isLoading) _kaydet();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_isLoading) _kaydet();
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
                Text(tr('common.esc'),
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
              tr('accounts.opening_balance.edit_title'),
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
                              title: tr(
                                'accounts.opening_balance.section.account_info',
                              ),
                              icon: Icons.account_balance_wallet_rounded,
                              color: Colors.orange.shade700,
                              child: Column(
                                children: [
                                  // Borç / Alacak Seçimi
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildRadioOption(
                                          title: tr(
                                            'accounts.opening_balance.debit_title',
                                          ),
                                          value: true,
                                          groupValue: _isBorc,
                                          color: Colors.red.shade700,
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _isBorc = val);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildRadioOption(
                                          title: tr(
                                            'accounts.opening_balance.credit_title',
                                          ),
                                          value: false,
                                          groupValue: _isBorc,
                                          color: Colors.green.shade700,
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _isBorc = val);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          controller: _amountController,
                                          label: tr(
                                            'accounts.opening_balance.amount_label',
                                          ),
                                          hint: '0.00',
                                          isNumeric: true,
                                          isRequired: true,
                                          color: Colors.orange.shade700,
                                          maxDecimalDigits:
                                              _genelAyarlar.fiyatOndalik,
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        child: _buildTextField(
                                          controller: _kurController,
                                          label: tr('common.exchange_rate'),
                                          hint: '1.0000',
                                          isNumeric: true,
                                          color: Colors.orange.shade700,
                                          maxDecimalDigits: 4,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _descriptionController,
                                    label: tr(
                                      'accounts.opening_balance.description_optional_label',
                                    ),
                                    hint: tr(
                                      'accounts.opening_balance.example.description',
                                    ),
                                    color: Colors.grey.shade700,
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue.shade100,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Colors.blue.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            tr('accounts.opening_balance.info.balance_will_update'),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.blue.shade900,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

  Widget _buildRadioOption({
    required String title,
    required bool value,
    required bool groupValue,
    required ValueChanged<bool?> onChanged,
    required Color color,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Radio<bool>(
              value: value,
              // ignore: deprecated_member_use
              groupValue: groupValue,
              // ignore: deprecated_member_use
              onChanged: onChanged,
              activeColor: color,
            ),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.black87,
              ),
            ),
          ],
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
            color: Colors.orange.shade700.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.edit_note_rounded,
            color: Colors.orange.shade700,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.cariHesap.adi,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                fontSize: 23,
              ),
            ),
            Text(
              '${tr('common.code')}: ${widget.cariHesap.kodNo}',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumeric = false,
    bool isRequired = false,
    Color? color,
    String? hint,
    String? errorText,
    int? maxDecimalDigits,
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
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
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
              return 'Bu alan zorunludur';
            }
            return null;
          },
          decoration: InputDecoration(
            errorText: errorText,
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
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _handleClear,
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          ),
          child: Row(
            children: [
              const Icon(Icons.close, size: 20),
              const SizedBox(width: 8),
              Text(
                tr('common.cancel'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _isLoading ? null : _kaydet,
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
                  tr('common.save'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
        ),
      ],
    );
  }
}
