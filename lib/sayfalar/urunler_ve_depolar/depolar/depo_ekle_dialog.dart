import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../servisler/depolar_veritabani_servisi.dart';
import 'modeller/depo_model.dart';

class DepoEkleDialog extends StatefulWidget {
  const DepoEkleDialog({super.key, this.depo, this.initialCode});

  final DepoModel? depo;
  final String? initialCode;

  @override
  State<DepoEkleDialog> createState() => _DepoEkleDialogState();
}

class _DepoEkleDialogState extends State<DepoEkleDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TextEditingController _kodController;
  late TextEditingController _adController;
  late TextEditingController _adresController;
  late TextEditingController _sorumluController;
  late TextEditingController _telefonController;

  late FocusNode _kodFocusNode;
  late FocusNode _adFocusNode;
  late FocusNode _adresFocusNode;
  late FocusNode _sorumluFocusNode;
  late FocusNode _telefonFocusNode;

  bool _aktifMi = true;
  late _CountryCode _selectedCountry;

  // Validation State
  String? _codeError;

  static const Color _primaryColor = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    final depo = widget.depo;
    _kodController = TextEditingController(
      text: depo?.kod ?? widget.initialCode ?? '',
    );
    _adController = TextEditingController(text: depo?.ad ?? '');
    _adresController = TextEditingController(text: depo?.adres ?? '');
    _sorumluController = TextEditingController(text: depo?.sorumlu ?? '');
    _aktifMi = depo?.aktifMi ?? true;

    // Telefon ayrıştırma
    String rawPhone = depo?.telefon ?? '';
    _selectedCountry = _countryCodes.first; // Varsayılan TR

    if (rawPhone.isNotEmpty) {
      for (final country in _countryCodes) {
        if (rawPhone.startsWith(country.dialCode)) {
          _selectedCountry = country;
          rawPhone = rawPhone.substring(country.dialCode.length).trim();
          break;
        }
      }
    }
    _telefonController = TextEditingController(text: rawPhone);

    _kodFocusNode = FocusNode();
    _adFocusNode = FocusNode();
    _adresFocusNode = FocusNode();
    _sorumluFocusNode = FocusNode();
    _telefonFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_kodController.text.isEmpty) {
        _kodFocusNode.requestFocus();
      } else if (_adController.text.isEmpty) {
        _adFocusNode.requestFocus();
      } else if (_sorumluController.text.isEmpty) {
        _sorumluFocusNode.requestFocus();
      } else if (_telefonController.text.isEmpty) {
        _telefonFocusNode.requestFocus();
      } else if (_adresController.text.isEmpty) {
        _adresFocusNode.requestFocus();
      } else {
        // If all filled, focus the first one (Code) for easy editing
        _kodFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _kodController.dispose();
    _adController.dispose();
    _adresController.dispose();
    _sorumluController.dispose();
    _telefonController.dispose();
    _kodFocusNode.dispose();
    _adFocusNode.dispose();
    _adresFocusNode.dispose();
    _sorumluFocusNode.dispose();
    _telefonFocusNode.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) {
      if (_kodController.text.trim().isEmpty) {
        _kodFocusNode.requestFocus();
      } else if (_adController.text.trim().isEmpty) {
        _adFocusNode.requestFocus();
      }
      return;
    }

    final isDuplicate = await DepolarVeritabaniServisi().depoKoduVarMi(
      _kodController.text.trim(),
      haricId: widget.depo?.id,
    );

    if (isDuplicate) {
      if (!mounted) return;
      setState(() {
        _codeError = tr('common.code_exists_error');
      });
      return;
    }

    final DepoModel sonuc = DepoModel(
      id: widget.depo?.id ?? 0, // Yeni kayıtta ID backend tarafından verilir
      kod: _kodController.text.trim(),
      ad: _adController.text.trim(),
      adres: _adresController.text.trim(),
      sorumlu: _sorumluController.text.trim(),
      telefon: _telefonController.text.trim().isNotEmpty
          ? '${_selectedCountry.dialCode} ${_telefonController.text.trim()}'
          : '',
      aktifMi: _aktifMi,
    );

    if (!mounted) return;
    Navigator.of(context).pop(sonuc);
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
    final double maxDialogHeight = isCompact ? screenSize.height * 0.92 : 680;
    final double contentPadding = isCompact ? 16 : 28;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.enter): _kaydet,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _kaydet,
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
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isVeryCompact)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.depo != null
                                      ? tr('warehouses.form.edit.title')
                                      : tr('warehouses.form.add.title'),
                                  style: TextStyle(
                                    fontSize: isCompact ? 19 : 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF202124),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.depo != null
                                      ? tr('warehouses.form.edit.subtitle')
                                      : tr('warehouses.form.add.subtitle'),
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
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.depo != null
                                  ? tr('warehouses.form.edit.title')
                                  : tr('warehouses.form.add.title'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF202124),
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: const Icon(
                              Icons.close,
                              size: 20,
                              color: Color(0xFF3C4043),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: tr('common.close'),
                          ),
                        ],
                      ),
                    SizedBox(height: isCompact ? 14 : 18),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool stack = constraints.maxWidth < 640;
                                final firstField = _buildUnderlinedField(
                                  label: tr('warehouses.form.code.label'),
                                  hint: tr('warehouses.form.code.hint'),
                                  controller: _kodController,
                                  isRequired: true,
                                  icon: Icons.qr_code,
                                  focusNode: _kodFocusNode,
                                  maxLength: 20,
                                  errorText: _codeError,
                                  onChanged: (val) {
                                    if (_codeError != null) {
                                      setState(() => _codeError = null);
                                    }
                                  },
                                );

                                final secondField = _buildUnderlinedField(
                                  label: tr('warehouses.form.name.label'),
                                  hint: tr('warehouses.form.name.hint'),
                                  controller: _adController,
                                  isRequired: true,
                                  icon: Icons.store,
                                  focusNode: _adFocusNode,
                                  maxLength: 30,
                                );

                                if (stack) {
                                  return Column(
                                    children: [
                                      firstField,
                                      const SizedBox(height: 18),
                                      secondField,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: firstField),
                                    const SizedBox(width: 24),
                                    Expanded(child: secondField),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 22),
                            _buildUnderlinedField(
                              label: tr('warehouses.form.manager.label'),
                              hint: tr('warehouses.form.manager.hint'),
                              controller: _sorumluController,
                              isRequired: false,
                              icon: Icons.person_outline,
                              focusNode: _sorumluFocusNode,
                            ),
                            const SizedBox(height: 22),
                            _buildPhoneInputRow(compact: isCompact),
                            const SizedBox(height: 22),
                            _buildUnderlinedField(
                              label: tr('warehouses.form.address.label'),
                              hint: tr('warehouses.form.address.hint'),
                              controller: _adresController,
                              isRequired: false,
                              icon: Icons.location_on_outlined,
                              focusNode: _adresFocusNode,
                              maxLength: 70,
                            ),
                            const SizedBox(height: 22),
                            _buildRadioGroup(
                              title: tr('settings.users.form.status.label'),
                              options: [
                                _RadioOption(
                                  label: tr(
                                    'settings.users.form.status.active',
                                  ),
                                  value: 'active',
                                ),
                                _RadioOption(
                                  label: tr(
                                    'settings.users.form.status.inactive',
                                  ),
                                  value: 'inactive',
                                ),
                              ],
                              groupValue: _aktifMi ? 'active' : 'inactive',
                              compact: isCompact,
                              onChanged: (val) =>
                                  setState(() => _aktifMi = val == 'active'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isCompact ? 8 : 4),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final bool stackButtons = constraints.maxWidth < 420;
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

                        final saveButton = ElevatedButton(
                          onPressed: _kaydet,
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
                            widget.depo != null
                                ? tr('warehouses.form.update')
                                : tr('warehouses.form.save'),
                            style: TextStyle(
                              fontSize: isCompact ? 13 : 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );

                        if (isCompact || stackButtons) {
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
                                    child: cancelButton,
                                  ),
                                  const SizedBox(width: gap),
                                  SizedBox(
                                    width: buttonWidth,
                                    child: saveButton,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            cancelButton,
                            const SizedBox(width: 12),
                            saveButton,
                          ],
                        );
                      },
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

  Widget _buildRadioGroup({
    required String title,
    required List<_RadioOption> options,
    required String groupValue,
    required ValueChanged<String> onChanged,
    bool compact = false,
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
        const SizedBox(height: 12),
        Wrap(
          spacing: compact ? 12 : 24,
          runSpacing: 10,
          children: options.map((opt) {
            final isSelected = groupValue == opt.value;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                onTap: () => onChanged(opt.value),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? _primaryColor
                              : const Color(0xFF202124),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _primaryColor,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      opt.label,
                      style: TextStyle(
                        fontSize: compact ? 14 : 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF202124),
                      ),
                    ),
                  ],
                ),
              )),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPhoneInputRow({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('settings.users.form.phone.label'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A4A4A),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool stack = constraints.maxWidth < 420;
            final double dropdownWidth = compact ? 120 : 135;

            final countryField = SizedBox(
              width: stack ? double.infinity : dropdownWidth,
              child: DropdownButtonFormField<_CountryCode>(
                mouseCursor: WidgetStateMouseCursor.clickable,
                dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
                initialValue: _selectedCountry,
                isExpanded: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2C3E50), width: 2),
                  ),
                ),
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xFFBDC1C6),
                ),
                selectedItemBuilder: (context) {
                  return _countryCodes.map((c) {
                    return Row(
                      children: [
                        Text(c.flag, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          c.dialCode,
                          style: TextStyle(
                            fontSize: compact ? 15 : 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF202124),
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
                items: _countryCodes.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Text(c.flag, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            c.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF202124),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          c.dialCode,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF606368),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCountry = val);
                  }
                },
              ),
            );

            final phoneField = TextFormField(
              controller: _telefonController,
              focusNode: _telefonFocusNode,
              keyboardType: TextInputType.phone,
              inputFormatters: [_PhoneInputFormatter()],
              style: TextStyle(
                fontSize: compact ? 15 : 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF202124),
              ),
              decoration: InputDecoration(
                hintText: tr('common.placeholder.phone'),
                hintStyle: TextStyle(
                  fontSize: compact ? 15 : 16,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFBDC1C6),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF2C3E50), width: 2),
                ),
              ),
            );

            if (stack) {
              return Column(
                children: [
                  countryField,
                  const SizedBox(height: 14),
                  phoneField,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                countryField,
                const SizedBox(width: 16),
                Expanded(child: phoneField),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CountryCode {
  final String code;
  final String name;
  final String dialCode;
  final String flag;

  const _CountryCode({
    required this.code,
    required this.name,
    required this.dialCode,
    required this.flag,
  });
}

const List<_CountryCode> _countryCodes = [
  _CountryCode(code: 'TR', name: 'Türkiye', dialCode: '+90', flag: '🇹🇷'),
  _CountryCode(code: 'US', name: 'USA', dialCode: '+1', flag: '🇺🇸'),
  _CountryCode(code: 'GB', name: 'UK', dialCode: '+44', flag: '🇬🇧'),
  _CountryCode(code: 'DE', name: 'Germany', dialCode: '+49', flag: '🇩🇪'),
  _CountryCode(code: 'FR', name: 'France', dialCode: '+33', flag: '🇫🇷'),
  _CountryCode(code: 'AZ', name: 'Azerbaijan', dialCode: '+994', flag: '🇦🇿'),
  _CountryCode(
    code: 'SA',
    name: 'Saudi Arabia',
    dialCode: '+966',
    flag: '🇸🇦',
  ),
  _CountryCode(code: 'AE', name: 'UAE', dialCode: '+971', flag: '🇦🇪'),
  _CountryCode(code: 'RU', name: 'Russia', dialCode: '+7', flag: '🇷🇺'),
];

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.isEmpty) return newValue;

    // Sadece rakamları al
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(text[i])) {
        buffer.write(text[i]);
      }
    }

    final String digits = buffer.toString();
    final StringBuffer formatted = StringBuffer();

    // Format: 555 123 45 67
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6 || i == 8) {
        formatted.write(' ');
      }
      formatted.write(digits[i]);
    }

    return TextEditingValue(
      text: formatted.toString(),
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _RadioOption {
  final String label;
  final String value;

  const _RadioOption({required this.label, required this.value});
}
