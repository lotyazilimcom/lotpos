import 'package:flutter/material.dart';
import 'package:patisyov10/sayfalar/ayarlar/yazdirma_ayarlari/modeller/qr_kod_icerik_model.dart';
import 'package:patisyov10/yardimcilar/ceviri/ceviri_servisi.dart';

class QrKodIcerikDialog extends StatefulWidget {
  final QrKodIcerikModel? initialValue;
  final Map<String, dynamic> previewData;

  const QrKodIcerikDialog({
    super.key,
    this.initialValue,
    required this.previewData,
  });

  static Future<QrKodIcerikModel?> show(
    BuildContext context, {
    QrKodIcerikModel? initialValue,
    required Map<String, dynamic> previewData,
  }) {
    return showDialog<QrKodIcerikModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => QrKodIcerikDialog(
        initialValue: initialValue,
        previewData: previewData,
      ),
    );
  }

  @override
  State<QrKodIcerikDialog> createState() => _QrKodIcerikDialogState();
}

class _QrKodIcerikDialogState extends State<QrKodIcerikDialog> {
  static const Color _accent = Color(0xFF2C3E50);
  static const Color _surface = Color(0xFFF8F9FA);

  late String _type;
  late final TextEditingController _plainTextController;
  late final TextEditingController _urlController;
  late final TextEditingController _emailAddressController;
  late final TextEditingController _emailSubjectController;
  late final TextEditingController _emailBodyController;
  late final TextEditingController _phoneController;
  late final TextEditingController _smsNumberController;
  late final TextEditingController _smsMessageController;
  late final TextEditingController _wifiSsidController;
  late final TextEditingController _wifiPasswordController;
  late String _wifiEncryption;
  late bool _wifiHidden;
  late final TextEditingController _contactNameController;
  late final TextEditingController _contactCompanyController;
  late final TextEditingController _contactTitleController;
  late final TextEditingController _contactPhoneController;
  late final TextEditingController _contactEmailController;
  late final TextEditingController _contactWebsiteController;
  late final TextEditingController _contactAddressController;
  late final TextEditingController _contactNoteController;

  TextEditingController? _activeController;
  String? _errorText;

  static const List<String> _quickTokenKeys = [
    'seller_name',
    'seller_phone',
    'seller_email',
    'seller_web',
    'seller_address',
    'invoice_no',
    'receipt_qr',
    'date',
    'time',
    'grand_total_rounded',
    'currency',
    'payment_type',
    'cashier_name',
  ];

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue ?? QrKodIcerikModel.defaultLotYazilim();
    _type = value.type;
    _plainTextController = TextEditingController(
      text: _toDisplayText(value.plainText),
    );
    _urlController = TextEditingController(text: _toDisplayText(value.url));
    _emailAddressController = TextEditingController(
      text: _toDisplayText(value.emailAddress),
    );
    _emailSubjectController = TextEditingController(
      text: _toDisplayText(value.emailSubject),
    );
    _emailBodyController = TextEditingController(
      text: _toDisplayText(value.emailBody),
    );
    _phoneController = TextEditingController(
      text: _toDisplayText(value.phoneNumber),
    );
    _smsNumberController = TextEditingController(
      text: _toDisplayText(value.smsNumber),
    );
    _smsMessageController = TextEditingController(
      text: _toDisplayText(value.smsMessage),
    );
    _wifiSsidController = TextEditingController(
      text: _toDisplayText(value.wifiSsid),
    );
    _wifiPasswordController = TextEditingController(text: value.wifiPassword);
    _wifiEncryption = value.wifiEncryption;
    _wifiHidden = value.wifiHidden;
    _contactNameController = TextEditingController(
      text: _toDisplayText(value.contactName),
    );
    _contactCompanyController = TextEditingController(
      text: _toDisplayText(value.contactCompany),
    );
    _contactTitleController = TextEditingController(
      text: _toDisplayText(value.contactTitle),
    );
    _contactPhoneController = TextEditingController(
      text: _toDisplayText(value.contactPhone),
    );
    _contactEmailController = TextEditingController(
      text: _toDisplayText(value.contactEmail),
    );
    _contactWebsiteController = TextEditingController(
      text: _toDisplayText(value.contactWebsite),
    );
    _contactAddressController = TextEditingController(
      text: _toDisplayText(value.contactAddress),
    );
    _contactNoteController = TextEditingController(
      text: _toDisplayText(value.contactNote),
    );
  }

  @override
  void dispose() {
    _plainTextController.dispose();
    _urlController.dispose();
    _emailAddressController.dispose();
    _emailSubjectController.dispose();
    _emailBodyController.dispose();
    _phoneController.dispose();
    _smsNumberController.dispose();
    _smsMessageController.dispose();
    _wifiSsidController.dispose();
    _wifiPasswordController.dispose();
    _contactNameController.dispose();
    _contactCompanyController.dispose();
    _contactTitleController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _contactWebsiteController.dispose();
    _contactAddressController.dispose();
    _contactNoteController.dispose();
    super.dispose();
  }

  String _storedText(String value) => _toStoredText(value).trim();

  String _rawTokenForKey(String key) => '{{$key}}';

  String _displayTokenForKey(String key) => '{{${tr('print.qr.token.$key')}}}';

  String _toDisplayText(String value) {
    var result = value;
    for (final key in _quickTokenKeys) {
      result = result.replaceAll(
        _rawTokenForKey(key),
        _displayTokenForKey(key),
      );
    }
    return result;
  }

  String _toStoredText(String value) {
    var result = value;
    final tokenKeys = [..._quickTokenKeys]
      ..sort(
        (a, b) => _displayTokenForKey(
          b,
        ).length.compareTo(_displayTokenForKey(a).length),
      );
    for (final key in tokenKeys) {
      result = result.replaceAll(
        _displayTokenForKey(key),
        _rawTokenForKey(key),
      );
    }
    return result;
  }

  QrKodIcerikModel get _currentValue => QrKodIcerikModel(
    type: _type,
    plainText: _storedText(_plainTextController.text),
    url: _storedText(_urlController.text),
    emailAddress: _storedText(_emailAddressController.text),
    emailSubject: _storedText(_emailSubjectController.text),
    emailBody: _storedText(_emailBodyController.text),
    phoneNumber: _storedText(_phoneController.text),
    smsNumber: _storedText(_smsNumberController.text),
    smsMessage: _storedText(_smsMessageController.text),
    wifiSsid: _storedText(_wifiSsidController.text),
    wifiPassword: _wifiPasswordController.text,
    wifiEncryption: _wifiEncryption,
    wifiHidden: _wifiHidden,
    contactName: _storedText(_contactNameController.text),
    contactCompany: _storedText(_contactCompanyController.text),
    contactTitle: _storedText(_contactTitleController.text),
    contactPhone: _storedText(_contactPhoneController.text),
    contactEmail: _storedText(_contactEmailController.text),
    contactWebsite: _storedText(_contactWebsiteController.text),
    contactAddress: _storedText(_contactAddressController.text),
    contactNote: _storedText(_contactNoteController.text),
  );

  String get _previewPayload => _currentValue.buildPayload(widget.previewData);

  void _setActive(TextEditingController controller) {
    _activeController = controller;
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  void _insertToken(String token) {
    final controller = _activeController ?? _defaultControllerForCurrentType();
    if (controller == null) return;

    final selection = controller.selection;
    final text = controller.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final safeStart = start < 0 ? text.length : start;
    final safeEnd = end < 0 ? text.length : end;

    controller.value = TextEditingValue(
      text: text.replaceRange(safeStart, safeEnd, token),
      selection: TextSelection.collapsed(offset: safeStart + token.length),
    );
    setState(() {
      _errorText = null;
    });
  }

  TextEditingController? _defaultControllerForCurrentType() {
    return switch (_type) {
      QrKodIcerikTuru.url => _urlController,
      QrKodIcerikTuru.email => _emailBodyController,
      QrKodIcerikTuru.phone => _phoneController,
      QrKodIcerikTuru.sms => _smsMessageController,
      QrKodIcerikTuru.wifi => _wifiSsidController,
      QrKodIcerikTuru.vcard => _contactNoteController,
      _ => _plainTextController,
    };
  }

  void _save() {
    if (_previewPayload.trim().isEmpty) {
      setState(() {
        _errorText = tr('print.qr.validation.empty');
      });
      return;
    }
    Navigator.of(context).pop(_currentValue);
  }

  void _closeWithDraft() {
    Navigator.of(context).pop(_currentValue);
  }

  String _modeTitle(String type) {
    return tr('print.qr.mode.$type');
  }

  IconData _modeIcon(String type) {
    return switch (type) {
      QrKodIcerikTuru.url => Icons.link_rounded,
      QrKodIcerikTuru.email => Icons.email_outlined,
      QrKodIcerikTuru.phone => Icons.phone_outlined,
      QrKodIcerikTuru.sms => Icons.sms_outlined,
      QrKodIcerikTuru.wifi => Icons.wifi_rounded,
      QrKodIcerikTuru.vcard => Icons.badge_outlined,
      _ => Icons.notes_rounded,
    };
  }

  String _previewSchemeLabel() {
    return switch (_type) {
      QrKodIcerikTuru.url => '${tr('print.qr.mode.url')} (https://)',
      QrKodIcerikTuru.email => '${tr('print.qr.mode.email')} (mailto:)',
      QrKodIcerikTuru.phone => '${tr('print.qr.mode.phone')} (tel:)',
      QrKodIcerikTuru.sms => '${tr('print.qr.mode.sms')} (SMSTO:)',
      QrKodIcerikTuru.wifi => '${tr('print.qr.mode.wifi')} (WIFI:)',
      QrKodIcerikTuru.vcard => '${tr('print.qr.mode.vcard')} (vCard 4.0)',
      _ => tr('print.qr.preview.free_text'),
    };
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.4),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF606368),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: QrKodIcerikTuru.values.map((type) {
        final isSelected = type == _type;
        return InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: () {
            setState(() {
              _type = type;
              _errorText = null;
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? _accent.withValues(alpha: 0.12)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? _accent : const Color(0xFFE0E0E0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _modeIcon(type),
                  size: 18,
                  color: isSelected ? _accent : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Text(
                  _modeTitle(type),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? _accent : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helper,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onTap: () {
        _setActive(controller);
      },
      onChanged: (_) {
        if (!mounted) return;
        setState(() {
          _activeController = controller;
          _errorText = null;
        });
      },
      decoration: _inputDecoration(label: label, hint: hint, helper: helper),
    );
  }

  Widget _buildDynamicForm() {
    switch (_type) {
      case QrKodIcerikTuru.url:
        return _buildTextField(
          controller: _urlController,
          label: tr('print.qr.field.url'),
          hint: 'www.lotyazilim.com',
          helper: tr('print.qr.field.url_helper'),
        );
      case QrKodIcerikTuru.email:
        return Column(
          children: [
            _buildTextField(
              controller: _emailAddressController,
              label: tr('print.qr.field.email'),
              hint: _displayTokenForKey('seller_email'),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _emailSubjectController,
              label: tr('print.qr.field.subject'),
              hint: _toDisplayText('Lot Yazılım | {{invoice_no}}'),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _emailBodyController,
              label: tr('print.qr.field.message'),
              maxLines: 4,
              hint: _toDisplayText(tr('print.qr.default.email_body')),
            ),
          ],
        );
      case QrKodIcerikTuru.phone:
        return _buildTextField(
          controller: _phoneController,
          label: tr('common.phone'),
          hint: _displayTokenForKey('seller_phone'),
          helper: tr('print.qr.field.phone_helper'),
        );
      case QrKodIcerikTuru.sms:
        return Column(
          children: [
            _buildTextField(
              controller: _smsNumberController,
              label: tr('print.qr.field.sms_number'),
              hint: _displayTokenForKey('seller_phone'),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _smsMessageController,
              label: tr('print.qr.field.message'),
              maxLines: 4,
              hint: _toDisplayText(
                'Lot Yazılım | {{invoice_no}} | {{grand_total_rounded}} {{currency}}',
              ),
            ),
          ],
        );
      case QrKodIcerikTuru.wifi:
        return Column(
          children: [
            _buildTextField(
              controller: _wifiSsidController,
              label: tr('print.qr.field.wifi_name'),
              hint: 'Lot Yazılım Ofis',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _wifiPasswordController,
              label: tr('print.qr.field.wifi_password'),
              hint: tr('print.qr.field.wifi_password_hint'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _wifiEncryption,
              items: [
                DropdownMenuItem(
                  value: 'WPA',
                  child: Text(tr('print.qr.wifi.encryption.wpa')),
                ),
                DropdownMenuItem(
                  value: 'WEP',
                  child: Text(tr('print.qr.wifi.encryption.wep')),
                ),
                DropdownMenuItem(
                  value: 'nopass',
                  child: Text(tr('print.qr.wifi.encryption.none')),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _wifiEncryption = value);
              },
              decoration: _inputDecoration(
                label: tr('print.qr.field.wifi_security'),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              value: _wifiHidden,
              onChanged: (value) => setState(() => _wifiHidden = value),
              title: Text(
                tr('print.qr.field.wifi_hidden'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      case QrKodIcerikTuru.vcard:
        return Column(
          children: [
            _buildTextField(
              controller: _contactNameController,
              label: tr('common.name'),
              hint: 'Lot Yazılım',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _contactCompanyController,
              label: tr('print.qr.field.company'),
              hint: 'Lot POS',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _contactTitleController,
              label: tr('print.qr.field.job_title'),
              hint: tr('print.qr.default.job_title'),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _contactPhoneController,
              label: tr('common.phone'),
              hint: _displayTokenForKey('seller_phone'),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _contactEmailController,
              label: tr('print.qr.field.email'),
              hint: _displayTokenForKey('seller_email'),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _contactWebsiteController,
              label: tr('print.qr.field.website'),
              hint: _displayTokenForKey('seller_web'),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _contactAddressController,
              label: tr('print.qr.field.address'),
              hint: _displayTokenForKey('seller_address'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _contactNoteController,
              label: tr('print.qr.field.note'),
              maxLines: 4,
              hint: _toDisplayText(tr('print.qr.default.note')),
            ),
          ],
        );
      default:
        return _buildTextField(
          controller: _plainTextController,
          label: tr('print.qr.field.plain_text'),
          maxLines: 7,
          hint: _toDisplayText(tr('print.qr.default.plain_text')),
          helper: tr('print.qr.placeholder_help'),
        );
    }
  }

  Widget _buildPreviewCard() {
    final payload = _previewPayload.trim();
    final lineCount = payload.isEmpty ? 0 : '\n'.allMatches(payload).length + 1;

    return _buildCard(
      icon: Icons.qr_code_2_rounded,
      title: tr('print.qr.preview.title'),
      description: tr('print.qr.preview.description'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: payload.isEmpty
                ? Text(
                    tr('print.qr.preview.empty'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9AA0A6),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : SelectableText(
                    payload,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Color(0xFF202124),
                      fontFamily: 'Roboto',
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  tr('print.qr.preview.scheme'),
                  _previewSchemeLabel(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetric(
                  tr('print.qr.preview.characters'),
                  payload.length.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetric(
                  tr('print.qr.preview.lines'),
                  lineCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF606368),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF202124),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenCard() {
    return _buildCard(
      icon: Icons.data_object_rounded,
      title: tr('print.qr.tokens.title'),
      description: tr('print.qr.tokens.description'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickTokenKeys.map((tokenKey) {
              final displayToken = _displayTokenForKey(tokenKey);
              return ActionChip(
                label: Text(displayToken),
                onPressed: () => _insertToken(displayToken),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE0E0E0)),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            tr('print.qr.tokens.helper'),
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 780),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 32,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        color: _accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('print.qr.dialog.title'),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF202124),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr('print.qr.dialog.subtitle'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF606368),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _closeWithDraft,
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF5F6368),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 860;
                    final formContent = SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildCard(
                            icon: Icons.tune_rounded,
                            title: tr('print.qr.mode.title'),
                            description: tr('print.qr.mode.description'),
                            child: _buildModeSelector(),
                          ),
                          const SizedBox(height: 16),
                          _buildCard(
                            icon: Icons.edit_note_rounded,
                            title: tr('print.qr.content.title'),
                            description: tr('print.qr.content.description'),
                            child: _buildDynamicForm(),
                          ),
                          const SizedBox(height: 16),
                          _buildTokenCard(),
                          if (_errorText != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFCA5A5),
                                ),
                              ),
                              child: Text(
                                _errorText!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );

                    final previewContent = SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                      child: _buildPreviewCard(),
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: formContent),
                          Container(width: 1, color: const Color(0xFFE8EAED)),
                          SizedBox(width: 320, child: previewContent),
                        ],
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildCard(
                            icon: Icons.tune_rounded,
                            title: tr('print.qr.mode.title'),
                            description: tr('print.qr.mode.description'),
                            child: _buildModeSelector(),
                          ),
                          const SizedBox(height: 16),
                          _buildCard(
                            icon: Icons.edit_note_rounded,
                            title: tr('print.qr.content.title'),
                            description: tr('print.qr.content.description'),
                            child: _buildDynamicForm(),
                          ),
                          const SizedBox(height: 16),
                          _buildTokenCard(),
                          const SizedBox(height: 16),
                          _buildPreviewCard(),
                          if (_errorText != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFCA5A5),
                                ),
                              ),
                              child: Text(
                                _errorText!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _closeWithDraft,
                      child: Text(tr('common.cancel')),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text(tr('common.save')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
