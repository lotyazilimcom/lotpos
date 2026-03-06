import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../servisler/uretimler_veritabani_servisi.dart';
import '../../../yardimcilar/mesaj_yardimcisi.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../../servisler/ayarlar_veritabani_servisi.dart';

class FiyatlariDegistirDialog extends StatefulWidget {
  const FiyatlariDegistirDialog({super.key});

  @override
  State<FiyatlariDegistirDialog> createState() =>
      _FiyatlariDegistirDialogState();
}

class _FiyatlariDegistirDialogState extends State<FiyatlariDegistirDialog> {
  final _formKey = GlobalKey<FormState>();

  String _selectedPriceType = 'satis_1';
  String _selectedOperation = 'artir';
  final _rateController = TextEditingController();
  final _rateFocusNode = FocusNode();
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  static const Color _primaryColor = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rateFocusNode.requestFocus();
    });
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      if (mounted) {
        setState(() {
          _genelAyarlar = settings;
        });
      }
    } catch (e) {
      debugPrint('Genel ayarlar yüklenemedi: $e');
    }
  }

  @override
  void dispose() {
    _rateController.dispose();
    _rateFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final double rate = FormatYardimcisi.parseDouble(
        _rateController.text,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );

      await UretimlerVeritabaniServisi().topluFiyatGuncelle(
        fiyatTipi: _selectedPriceType,
        islem: _selectedOperation,
        oran: rate,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
      MesajYardimcisi.basariGoster(context, tr('common.saved_successfully'));
    } catch (e) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const double dialogRadius = 14;
    final media = MediaQuery.of(context);
    final bool isMobile = media.size.width < 640;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): _handleSave,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _handleSave,
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: Colors.white,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 32,
            vertical: isMobile ? 16 : 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dialogRadius),
          ),
          child: Container(
            width: isMobile ? double.infinity : 450,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(dialogRadius),
            ),
            padding: EdgeInsets.fromLTRB(
              isMobile ? 18 : 28,
              isMobile ? 18 : 24,
              isMobile ? 18 : 28,
              isMobile ? 18 : 22,
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            tr('productions.actions.change_prices'),
                            style: TextStyle(
                              fontSize: isMobile ? 19 : 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF202124),
                            ),
                          ),
                        ),
                        if (!isMobile)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              tr('common.esc'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9AA0A6),
                              ),
                            ),
                          ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: Icon(
                              Icons.close,
                              size: isMobile ? 20 : 22,
                              color: const Color(0xFF3C4043),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 18 : 24),

                    // Fields
                    _buildDropdown(
                      label: tr('productions.table.price'),
                      value: _selectedPriceType,
                      items: [
                        DropdownMenuItem(
                          value: 'satis_1',
                          child: Text(tr('productions.table.sales_price_1')),
                        ),
                        DropdownMenuItem(
                          value: 'satis_2',
                          child: Text(tr('productions.table.sales_price_2')),
                        ),
                        DropdownMenuItem(
                          value: 'satis_3',
                          child: Text(tr('productions.table.sales_price_3')),
                        ),
                        DropdownMenuItem(
                          value: 'alis',
                          child: Text(tr('productions.table.purchase_price')),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedPriceType = val!),
                    ),
                    const SizedBox(height: 16),

                    _buildDropdown(
                      label: tr('common.operation'),
                      value: _selectedOperation,
                      items: [
                        DropdownMenuItem(
                          value: 'artir',
                          child: Text(tr('common.increase')),
                        ),
                        DropdownMenuItem(
                          value: 'azalt',
                          child: Text(tr('common.decrease')),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedOperation = val!),
                    ),
                    const SizedBox(height: 16),

                    _buildUnderlinedField(
                      label: tr('common.rate_percent'),
                      controller: _rateController,
                      focusNode: _rateFocusNode,
                      isNumeric: true,
                      isRequired: true,
                      hint: '0.00',
                    ),

                    SizedBox(height: isMobile ? 24 : 32),

                    if (isMobile) ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final double maxRowWidth = constraints.maxWidth > 320
                              ? 320
                              : constraints.maxWidth;
                          const double gap = 12;
                          final double buttonWidth = (maxRowWidth - gap) / 2;

                          return Align(
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: maxRowWidth,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: buttonWidth,
                                    child: TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      style: TextButton.styleFrom(
                                        foregroundColor: _primaryColor,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                      child: Text(
                                        tr('common.cancel'),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: gap),
                                  SizedBox(
                                    width: buttonWidth,
                                    child: ElevatedButton(
                                      onPressed: _handleSave,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFEA4335),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        tr('common.save'),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ] else
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
                            onPressed: _handleSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA4335),
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
                              tr('common.save'),
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

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
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
          initialValue: value,
          items: items,
          onChanged: onChanged,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(vertical: 12),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFBDC1C6)),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
        ),
      ],
    );
  }

  Widget _buildUnderlinedField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    bool isNumeric = false,
    bool isRequired = false,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(
                  0xFF4A4A4A,
                ), // Using dark grey instead of red for label to match style
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
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: isNumeric
              ? [
                  CurrencyInputFormatter(
                    binlik: _genelAyarlar.binlikAyiraci,
                    ondalik: _genelAyarlar.ondalikAyiraci,
                    maxDecimalDigits: 2,
                  ),
                ]
              : null,
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return tr('validation.required');
            }
            return null;
          },
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
          decoration: InputDecoration(
            hintText: hint,
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
            errorStyle: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
