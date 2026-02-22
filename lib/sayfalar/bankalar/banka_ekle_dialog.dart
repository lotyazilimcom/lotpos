import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../servisler/bankalar_veritabani_servisi.dart';
import 'modeller/banka_model.dart';

class BankaEkleDialog extends StatefulWidget {
  const BankaEkleDialog({super.key, this.banka, this.initialCode});

  final BankaModel? banka;
  final String? initialCode;

  @override
  State<BankaEkleDialog> createState() => _BankaEkleDialogState();
}

class _BankaEkleDialogState extends State<BankaEkleDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TextEditingController _kodController;
  late TextEditingController _adController;
  late TextEditingController _subeKoduController;
  late TextEditingController _subeAdiController;
  late TextEditingController _hesapNoController;
  late TextEditingController _ibanController;
  late TextEditingController _bilgi1Controller;
  late TextEditingController _bilgi2Controller;

  late FocusNode _kodFocusNode;
  late FocusNode _adFocusNode;
  late FocusNode _subeKoduFocusNode;
  late FocusNode _subeAdiFocusNode;
  late FocusNode _hesapNoFocusNode;
  late FocusNode _ibanFocusNode;
  late FocusNode _bilgi1FocusNode;
  late FocusNode _bilgi2FocusNode;

  bool _aktifMi = true;
  String _selectedParaBirimi = 'TRY';

  // Validation State
  String? _codeError;

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
    final banka = widget.banka;
    _kodController = TextEditingController(
      text: banka?.kod ?? widget.initialCode ?? '',
    );
    _adController = TextEditingController(text: banka?.ad ?? '');
    _subeKoduController = TextEditingController(text: banka?.subeKodu ?? '');
    _subeAdiController = TextEditingController(text: banka?.subeAdi ?? '');
    _hesapNoController = TextEditingController(text: banka?.hesapNo ?? '');
    _ibanController = TextEditingController(text: banka?.iban ?? '');
    _bilgi1Controller = TextEditingController(text: banka?.bilgi1 ?? '');
    _bilgi2Controller = TextEditingController(text: banka?.bilgi2 ?? '');
    _aktifMi = banka?.aktifMi ?? true;
    _selectedParaBirimi = banka?.paraBirimi ?? 'TRY';

    _kodFocusNode = FocusNode();
    _adFocusNode = FocusNode();
    _subeKoduFocusNode = FocusNode();
    _subeAdiFocusNode = FocusNode();
    _hesapNoFocusNode = FocusNode();
    _ibanFocusNode = FocusNode();
    _bilgi1FocusNode = FocusNode();
    _bilgi2FocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_kodController.text.isEmpty) {
        _kodFocusNode.requestFocus();
      } else if (_adController.text.isEmpty) {
        _adFocusNode.requestFocus();
      } else {
        _kodFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _kodController.dispose();
    _adController.dispose();
    _subeKoduController.dispose();
    _subeAdiController.dispose();
    _hesapNoController.dispose();
    _ibanController.dispose();
    _bilgi1Controller.dispose();
    _bilgi2Controller.dispose();
    _kodFocusNode.dispose();
    _adFocusNode.dispose();
    _subeKoduFocusNode.dispose();
    _subeAdiFocusNode.dispose();
    _hesapNoFocusNode.dispose();
    _ibanFocusNode.dispose();
    _bilgi1FocusNode.dispose();
    _bilgi2FocusNode.dispose();
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

    final isDuplicate = await BankalarVeritabaniServisi().bankaKoduVarMi(
      _kodController.text.trim(),
      haricId: widget.banka?.id,
    );

    if (isDuplicate) {
      if (!mounted) return;
      setState(() {
        _codeError = tr('common.code_exists_error');
      });
      return;
    }

    final BankaModel sonuc = BankaModel(
      id: widget.banka?.id ?? 0,
      kod: _kodController.text.trim(),
      ad: _adController.text.trim(),
      paraBirimi: _selectedParaBirimi,
      subeKodu: _subeKoduController.text.trim(),
      subeAdi: _subeAdiController.text.trim(),
      hesapNo: _hesapNoController.text.trim(),
      iban: _ibanController.text.trim(),
      bilgi1: _bilgi1Controller.text.trim(),
      bilgi2: _bilgi2Controller.text.trim(),
      bakiye: widget.banka?.bakiye ?? 0.0,
      aktifMi: _aktifMi,
      varsayilan: false,
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
        : 800;
    final double maxDialogHeight = isCompact ? screenSize.height * 0.92 : 850;
    final double contentPadding = isCompact ? 16 : 28;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).pop();
        },
        const SingleActivator(LogicalKeyboardKey.enter): () {
          _kaydet();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          _kaydet();
        },
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
                                  widget.banka != null
                                      ? tr('banks.form.edit.title')
                                      : tr('banks.form.add.title'),
                                  style: TextStyle(
                                    fontSize: isCompact ? 19 : 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF202124),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.banka != null
                                      ? tr('banks.form.edit.subtitle')
                                      : tr('banks.form.add.subtitle'),
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
                              widget.banka != null
                                  ? tr('banks.form.edit.title')
                                  : tr('banks.form.add.title'),
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
                                  label: tr('banks.form.code.label'),
                                  hint: tr('banks.form.code.hint'),
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
                                  label: tr('banks.form.name.label'),
                                  hint: tr('banks.form.name.hint'),
                                  controller: _adController,
                                  isRequired: true,
                                  icon: Icons.account_balance_wallet,
                                  focusNode: _adFocusNode,
                                  maxLength: 50,
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
                            _buildCurrencyDropdown(),
                            const SizedBox(height: 22),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool stack = constraints.maxWidth < 640;
                                final branchCode = _buildUnderlinedField(
                                  label: tr('banks.form.branch_code.label'),
                                  hint: tr('banks.form.branch_code.hint'),
                                  controller: _subeKoduController,
                                  isRequired: false,
                                  icon: Icons.numbers,
                                  focusNode: _subeKoduFocusNode,
                                );
                                final branchName = _buildUnderlinedField(
                                  label: tr('banks.form.branch_name.label'),
                                  hint: tr('banks.form.branch_name.hint'),
                                  controller: _subeAdiController,
                                  isRequired: false,
                                  icon: Icons.store,
                                  focusNode: _subeAdiFocusNode,
                                );

                                if (stack) {
                                  return Column(
                                    children: [
                                      branchCode,
                                      const SizedBox(height: 18),
                                      branchName,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: branchCode),
                                    const SizedBox(width: 24),
                                    Expanded(child: branchName),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 22),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool stack = constraints.maxWidth < 640;
                                final accountNo = _buildUnderlinedField(
                                  label: tr('banks.form.account_no.label'),
                                  hint: tr('banks.form.account_no.hint'),
                                  controller: _hesapNoController,
                                  isRequired: false,
                                  icon: Icons.account_box,
                                  focusNode: _hesapNoFocusNode,
                                );
                                final iban = _buildUnderlinedField(
                                  label: tr('banks.form.iban.label'),
                                  hint: tr('banks.form.iban.hint'),
                                  controller: _ibanController,
                                  isRequired: false,
                                  icon: Icons.credit_card,
                                  focusNode: _ibanFocusNode,
                                );

                                if (stack) {
                                  return Column(
                                    children: [
                                      accountNo,
                                      const SizedBox(height: 18),
                                      iban,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: accountNo),
                                    const SizedBox(width: 24),
                                    Expanded(child: iban),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 22),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool stack = constraints.maxWidth < 640;
                                final info1 = _buildUnderlinedField(
                                  label: tr('banks.form.info1.label'),
                                  hint: tr('banks.form.info1.hint'),
                                  controller: _bilgi1Controller,
                                  isRequired: false,
                                  icon: Icons.info_outline,
                                  focusNode: _bilgi1FocusNode,
                                );
                                final info2 = _buildUnderlinedField(
                                  label: tr('banks.form.info2.label'),
                                  hint: tr('banks.form.info2.hint'),
                                  controller: _bilgi2Controller,
                                  isRequired: false,
                                  icon: Icons.notes,
                                  focusNode: _bilgi2FocusNode,
                                );

                                if (stack) {
                                  return Column(
                                    children: [
                                      info1,
                                      const SizedBox(height: 18),
                                      info2,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: info1),
                                    const SizedBox(width: 24),
                                    Expanded(child: info2),
                                  ],
                                );
                              },
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
                            widget.banka != null
                                ? tr('banks.form.update')
                                : tr('banks.form.save'),
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

  Widget _buildCurrencyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              tr('banks.form.currency.label'),
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
        DropdownButtonFormField<String>(
          mouseCursor: WidgetStateMouseCursor.clickable,
          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
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
}

class _RadioOption {
  final String label;
  final String value;

  const _RadioOption({required this.label, required this.value});
}
