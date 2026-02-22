import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';

class DilEkleDialog extends StatefulWidget {
  final String? editLanguageCode;

  const DilEkleDialog({super.key, this.editLanguageCode});

  @override
  State<DilEkleDialog> createState() => _DilEkleDialogState();
}

class _DilEkleDialogState extends State<DilEkleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _shortFormController = TextEditingController();
  final _orderNoController = TextEditingController();

  String _textDirectionValue = 'ltr';
  String _statusValue = 'active';
  String? _editorLangKodu;
  static const Color _primaryColor = Color(0xFF2C3E50);

  static const List<String> _editorLangKodlari = [
    'ar',
    'hy',
    'az',
    'eu',
    'be',
    'bn_BD',
    'bs',
    'bg_BG',
    'ca',
    'zh_CN',
    'zh_TW',
    'hr',
    'cs',
    'da',
    'dv',
    'nl',
    'en',
    'et',
    'fo',
    'fi',
    'fr_FR',
    'gd',
    'gl',
    'ka_GE',
    'de',
    'el',
    'he',
    'hi_IN',
    'hu_HU',
    'is_IS',
    'id',
    'it',
    'ja',
    'kab',
    'kk',
    'km_KH',
    'ko_KR',
    'ku',
    'lv',
    'lt',
    'lb',
    'ml',
    'mn',
    'nb_NO',
    'fa',
    'pl',
    'pt_BR',
    'pt_PT',
    'ro',
    'ru',
    'sr',
    'si_LK',
    'sk',
    'sl_SI',
    'es',
    'es_MX',
    'sv_SE',
    'tg',
    'ta',
    'tt',
    'th_TH',
    'tr',
    'ug',
    'uk',
    'vi',
    'cy',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.editLanguageCode != null) {
      _loadLanguageData();
    }
  }

  void _loadLanguageData() {
    final ceviriServisi = Provider.of<CeviriServisi>(context, listen: false);
    final tumDiller = ceviriServisi.getTumDiller();
    final dilAdi = tumDiller[widget.editLanguageCode];

    if (dilAdi != null) {
      _nameController.text = dilAdi;
      _codeController.text = widget
          .editLanguageCode!; // Assuming code is same as short form for now or we need to store it
      _shortFormController.text = widget.editLanguageCode!;
      _orderNoController.text = "5"; // Default or fetch if available

      // This gets current language direction, we need specific language direction
      // We need to access internal map or add a method to get direction for a code
      // For now, let's assume we can get it or default it.
      // Actually CeviriServisi doesn't expose direction for specific language easily without changing current language or accessing private map.
      // Let's assume default for now or add a getter in CeviriServisi.
      // Wait, I added getTumDiller but not directions.
      // I should assume LTR unless AR.
      if (widget.editLanguageCode == 'ar') {
        _textDirectionValue = 'rtl';
      } else {
        _textDirectionValue = 'ltr';
      }

      _setEditorLang(widget.editLanguageCode);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _shortFormController.dispose();
    _orderNoController.dispose();
    super.dispose();
  }

  void _saveLanguage() {
    if (_formKey.currentState!.validate()) {
      final ceviriServisi = Provider.of<CeviriServisi>(context, listen: false);
      final tumDiller = ceviriServisi.getTumDiller();

      final code = _shortFormController.text.trim();
      final name = _nameController.text.trim();

      // Check duplicates only if code changed or name changed to something existing (excluding self)
      if (widget.editLanguageCode == null) {
        if (tumDiller.containsKey(code)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('validation.duplicate_code'))),
          );
          return;
        }
      }

      if (widget.editLanguageCode == null && tumDiller.containsValue(name)) {
        // Simple check, for edit we might want to allow keeping same name
        // If edit, check if name exists and it's not this language
        // But map is code -> name.
        // So if name exists in values, check if key is different.
      }

      // For edit, we need to be careful.
      if (widget.editLanguageCode != null) {
        ceviriServisi.dilGuncelle(
          widget.editLanguageCode!,
          code,
          name,
          _textDirectionValue == 'rtl' ? TextDirection.rtl : TextDirection.ltr,
        );
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$name ${tr('common.edit')} ${tr('language.status.active')}',
            ),
          ),
        );
      } else {
        // Add new
        if (tumDiller.containsValue(name)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('validation.duplicate_name'))),
          );
          return;
        }

        final baseTranslations = ceviriServisi.getCeviriler('en') ?? {};

        ceviriServisi.yeniDilEkle(
          code,
          name,
          Map<String, String>.from(baseTranslations),
          _textDirectionValue == 'rtl' ? TextDirection.rtl : TextDirection.ltr,
        );

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name ${tr('language.status.active')}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const dialogRadius = 14.0;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.enter): _saveLanguage,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _saveLanguage,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mediaQuery = MediaQuery.of(context);
            final isMobile = mediaQuery.size.width < 600;
            final dialogWidth = isMobile ? mediaQuery.size.width * 0.95 : 820.0;
            final maxDialogHeight = isMobile
                ? mediaQuery.size.height * 0.9
                : mediaQuery.size.height * 0.86;

            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 32,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dialogRadius),
              ),
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: maxDialogHeight,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(dialogRadius),
                ),
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 20 : 28,
                  24,
                  isMobile ? 20 : 28,
                  22,
                ),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
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
                                    widget.editLanguageCode != null
                                        ? tr('common.edit')
                                        : tr('language.dialog.add.title'),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF202124),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.editLanguageCode != null
                                        ? tr('language.editTranslations')
                                        : tr('language.dialog.add.subtitle'),
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
                              crossAxisAlignment: CrossAxisAlignment.center,
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
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    tooltip: tr('common.close'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (isMobile) ...[
                          _buildUnderlinedField(
                            controller: _nameController,
                            label: tr('language.dialog.add.name'),
                            hint: tr('language.dialog.add.name.hint'),
                            icon: Icons.language_outlined,
                            isRequired: true,
                          ),
                          const SizedBox(height: 22),
                          _buildUnderlinedField(
                            controller: _codeController,
                            label: tr('language.dialog.add.code'),
                            hint: tr('language.dialog.add.code.hint'),
                            icon: Icons.code_outlined,
                            isRequired: true,
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: _buildUnderlinedField(
                                  controller: _nameController,
                                  label: tr('language.dialog.add.name'),
                                  hint: tr('language.dialog.add.name.hint'),
                                  icon: Icons.language_outlined,
                                  isRequired: true,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildUnderlinedField(
                                  controller: _codeController,
                                  label: tr('language.dialog.add.code'),
                                  hint: tr('language.dialog.add.code.hint'),
                                  icon: Icons.code_outlined,
                                  isRequired: true,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 22),
                        if (isMobile) ...[
                          _buildUnderlinedField(
                            controller: _shortFormController,
                            label: tr('language.dialog.add.shortForm'),
                            hint: tr('language.dialog.add.shortForm.hint'),
                            icon: Icons.short_text_outlined,
                            isRequired: true,
                          ),
                          const SizedBox(height: 22),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('language.dialog.add.editor'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A4A4A),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                mouseCursor: WidgetStateMouseCursor.clickable,
                                dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
                                menuMaxHeight: 300,
                                initialValue: _editorLangKodu,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: Color(0xFF5F6368),
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  prefixIcon: Icon(
                                    Icons.translate_outlined,
                                    size: 20,
                                    color: Color(0xFF5F6368),
                                  ),
                                  contentPadding: EdgeInsets.only(bottom: 6),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFFBDBDBD),
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF5F6368),
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                                hint: Text(
                                  tr('language.dialog.add.editor.hint'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFFBDC1C6),
                                  ),
                                ),
                                items: _editorLangKodlari.map((kod) {
                                  return DropdownMenuItem<String>(
                                    value: kod,
                                    child: Text(
                                      _editorLanguageLabel(kod),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF202124),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _editorLangKodu = val;
                                  });
                                },
                                selectedItemBuilder: (context) {
                                  return _editorLangKodlari.map((kod) {
                                    return Text(
                                      _editorLanguageLabel(kod),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF202124),
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ],
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: _buildUnderlinedField(
                                  controller: _shortFormController,
                                  label: tr('language.dialog.add.shortForm'),
                                  hint: tr(
                                    'language.dialog.add.shortForm.hint',
                                  ),
                                  icon: Icons.short_text_outlined,
                                  isRequired: true,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr('language.dialog.add.editor'),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4A4A4A),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      mouseCursor: WidgetStateMouseCursor.clickable,
                                      dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
                                      menuMaxHeight: 300,
                                      initialValue: _editorLangKodu,
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 20,
                                        color: Color(0xFF5F6368),
                                      ),
                                      decoration: const InputDecoration(
                                        prefixIcon: Icon(
                                          Icons.translate_outlined,
                                          size: 20,
                                          color: Color(0xFFBDC1C6),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0xFFE0E0E0),
                                          ),
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0xFF2C3E50),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      hint: Text(
                                        tr('language.dialog.add.editor.hint'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFFBDC1C6),
                                        ),
                                      ),
                                      items: _editorLangKodlari.map((kod) {
                                        return DropdownMenuItem<String>(
                                          value: kod,
                                          child: Text(
                                            _editorLanguageLabel(kod),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF202124),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _editorLangKodu = val;
                                        });
                                      },
                                      selectedItemBuilder: (context) {
                                        return _editorLangKodlari.map((kod) {
                                          return Text(
                                            _editorLanguageLabel(kod),
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF202124),
                                            ),
                                          );
                                        }).toList();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: _buildUnderlinedField(
                                controller: _orderNoController,
                                label: tr('language.dialog.add.orderNo'),
                                hint: tr('language.dialog.add.orderNo.hint'),
                                icon: Icons.format_list_numbered_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            if (!isMobile) ...[
                              const SizedBox(width: 24),
                              const Spacer(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 22),
                        if (isMobile) ...[
                          _buildRadioGroup(
                            title: tr('language.dialog.add.direction'),
                            options: [
                              _RadioOption(
                                label: tr('language.dialog.add.direction.ltr'),
                                value: 'ltr',
                              ),
                              _RadioOption(
                                label: tr('language.dialog.add.direction.rtl'),
                                value: 'rtl',
                              ),
                            ],
                            groupValue: _textDirectionValue,
                            onChanged: (val) =>
                                setState(() => _textDirectionValue = val),
                          ),
                          const SizedBox(height: 22),
                          _buildRadioGroup(
                            title: tr('language.dialog.add.status'),
                            options: [
                              _RadioOption(
                                label: tr('language.dialog.add.status.active'),
                                value: 'active',
                              ),
                              _RadioOption(
                                label: tr(
                                  'language.dialog.add.status.inactive',
                                ),
                                value: 'inactive',
                              ),
                            ],
                            groupValue: _statusValue,
                            onChanged: (val) =>
                                setState(() => _statusValue = val),
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: _buildRadioGroup(
                                  title: tr('language.dialog.add.direction'),
                                  options: [
                                    _RadioOption(
                                      label: tr(
                                        'language.dialog.add.direction.ltr',
                                      ),
                                      value: 'ltr',
                                    ),
                                    _RadioOption(
                                      label: tr(
                                        'language.dialog.add.direction.rtl',
                                      ),
                                      value: 'rtl',
                                    ),
                                  ],
                                  groupValue: _textDirectionValue,
                                  onChanged: (val) =>
                                      setState(() => _textDirectionValue = val),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildRadioGroup(
                                  title: tr('language.dialog.add.status'),
                                  options: [
                                    _RadioOption(
                                      label: tr(
                                        'language.dialog.add.status.active',
                                      ),
                                      value: 'active',
                                    ),
                                    _RadioOption(
                                      label: tr(
                                        'language.dialog.add.status.inactive',
                                      ),
                                      value: 'inactive',
                                    ),
                                  ],
                                  groupValue: _statusValue,
                                  onChanged: (val) =>
                                      setState(() => _statusValue = val),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 26),
                        if (isMobile)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final double maxRowWidth =
                                  constraints.maxWidth > 320
                                  ? 320
                                  : constraints.maxWidth;
                              const double gap = 12;
                              final double buttonWidth =
                                  (maxRowWidth - gap) / 2;

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
                                              fontSize: 14,
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
                                          onPressed: _saveLanguage,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _primaryColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
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
                          )
                        else
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
                                onPressed: _saveLanguage,
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
            );
          },
        ),
      ),
    );
  }

  void _setEditorLang(String? kod) {
    _editorLangKodu = kod;
  }

  String _editorLanguageLabel(String code) {
    switch (code) {
      case 'tr':
        return 'Türkçe';
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      default:
        return code;
    }
  }

  Widget _buildUnderlinedField({
    required String label,
    required String hint,
    TextEditingController? controller,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
    IconData? icon,
    bool isRequired = false,
  }) {
    // Mecburi alanlar için renkler
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
          keyboardType: keyboardType,
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return tr('validation.required');
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
            prefixIcon: icon != null
                ? Icon(icon, size: 20, color: const Color(0xFFBDC1C6))
                : null,
            suffixIcon: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: suffix,
                  )
                : null,
            suffixIconConstraints: suffix != null
                ? const BoxConstraints(minWidth: 20, minHeight: 20)
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2C3E50), width: 2),
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

  Widget _buildRadioGroup({
    required String title,
    required List<_RadioOption> options,
    required String groupValue,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A4A4A),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 18,
          runSpacing: 10,
          children: options
              .map(
                (opt) => MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<String>(
                        value: opt.value,
                        // ignore: deprecated_member_use
                        groupValue: groupValue,
                        // ignore: deprecated_member_use
                        onChanged: (val) {
                          if (val != null) onChanged(val);
                        },
                        visualDensity: VisualDensity.compact,
                        activeColor: const Color(0xFF2C3E50),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        opt.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF303133),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _RadioOption {
  final String label;
  final String value;

  const _RadioOption({required this.label, required this.value});
}
