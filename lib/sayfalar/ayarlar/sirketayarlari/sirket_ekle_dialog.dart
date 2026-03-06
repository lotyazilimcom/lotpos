import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../yardimcilar/ceviri/ceviri_servisi.dart';
import 'modeller/sirket_ayarlari_model.dart';

class SirketEkleDialog extends StatefulWidget {
  final SirketAyarlariModel? duzenlenecekSirket;

  const SirketEkleDialog({super.key, this.duzenlenecekSirket});

  @override
  State<SirketEkleDialog> createState() => _SirketEkleDialogState();
}

class _SirketEkleDialogState extends State<SirketEkleDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _kodController;
  late TextEditingController _adController;
  late TextEditingController _adresController;
  late TextEditingController _vergiDairesiController;
  late TextEditingController _vergiNoController;
  late TextEditingController _telefonController;
  late TextEditingController _epostaController;
  late TextEditingController _webController;

  // Antet Satırları (Header Lines)
  final List<TextEditingController> _antetSatirControllers = [];

  bool _aktifMi = true;
  bool _duzenlenebilirMi = true;
  bool _varsayilanMi = false;

  // Logo
  Uint8List? _logoBytes;

  // Colors
  static const Color _primaryColor = Color(0xFF2C3E50);
  static const Color _textColor = Color(0xFF202124);
  static const Color _labelColor = Color(0xFF4A4A4A);
  static const Color _borderColor = Color(0xFFE0E0E0);
  static const Color _hintColor = Color(0xFFBDC1C6);

  @override
  void initState() {
    super.initState();
    final sirket = widget.duzenlenecekSirket;
    _kodController = TextEditingController(text: sirket?.kod ?? '');
    _adController = TextEditingController(text: sirket?.ad ?? '');
    _adresController = TextEditingController(text: sirket?.adres ?? '');
    _vergiDairesiController = TextEditingController(
      text: sirket?.vergiDairesi ?? '',
    );
    _vergiNoController = TextEditingController(text: sirket?.vergiNo ?? '');
    _telefonController = TextEditingController(text: sirket?.telefon ?? '');
    _epostaController = TextEditingController(text: sirket?.eposta ?? '');
    _webController = TextEditingController(text: sirket?.webAdresi ?? '');

    if (sirket != null) {
      _aktifMi = sirket.aktifMi;
      _duzenlenebilirMi = sirket.duzenlenebilirMi;
      _varsayilanMi = sirket.varsayilanMi;

      // Antet satırlarını yükle
      for (var satir in sirket.ustBilgiSatirlari) {
        _antetSatirControllers.add(TextEditingController(text: satir));
      }

      // Logoyu yükle (Base64 varsayımı)
      if (sirket.ustBilgiLogosu != null && sirket.ustBilgiLogosu!.isNotEmpty) {
        try {
          _logoBytes = base64Decode(sirket.ustBilgiLogosu!);
        } catch (e) {
          debugPrint('Logo decode hatası: $e');
        }
      }
    } else {
      if (_antetSatirControllers.isEmpty) {
        _antetSatirControllers.add(TextEditingController());
      }
    }
  }

  @override
  void dispose() {
    _kodController.dispose();
    _adController.dispose();
    _adresController.dispose();
    _vergiDairesiController.dispose();
    _vergiNoController.dispose();
    _telefonController.dispose();
    _epostaController.dispose();
    _webController.dispose();
    for (var controller in _antetSatirControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _logoSec() async {
    final XTypeGroup typeGroup = XTypeGroup(
      label: tr('common.images'),
      extensions: <String>['jpg', 'png', 'jpeg'],
      uniformTypeIdentifiers: ['public.image'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[typeGroup],
    );

    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _logoBytes = bytes;
      });
    }
  }

  void _logoSil() {
    setState(() {
      _logoBytes = null;
    });
  }

  void _kaydet() {
    if (_formKey.currentState!.validate()) {
      String? logoBase64;
      if (_logoBytes != null) {
        logoBase64 = base64Encode(_logoBytes!);
      }

      final yeniSirket = SirketAyarlariModel(
        id: widget.duzenlenecekSirket?.id,
        kod: _kodController.text.trim(),
        ad: _adController.text.trim(),
        // Başlıklar UI'da yok, boş liste veya mevcutu koru
        basliklar: widget.duzenlenecekSirket?.basliklar ?? [],
        logolar: widget.duzenlenecekSirket?.logolar ?? [],
        adres: _adresController.text.trim(),
        vergiDairesi: _vergiDairesiController.text.trim(),
        vergiNo: _vergiNoController.text.trim(),
        telefon: _telefonController.text.trim(),
        eposta: _epostaController.text.trim(),
        webAdresi: _webController.text.trim(),
        aktifMi: _aktifMi,
        varsayilanMi: _varsayilanMi,
        duzenlenebilirMi: _duzenlenebilirMi,
        ustBilgiLogosu: logoBase64,
        ustBilgiSatirlari: _antetSatirControllers
            .map((c) => c.text.trim())
            .toList(),
      );

      Navigator.of(context).pop(yeniSirket);
    }
  }

  void _antetSatirEkle() {
    setState(() {
      _antetSatirControllers.add(TextEditingController());
    });
  }

  void _antetSatirSil(int index) {
    setState(() {
      _antetSatirControllers[index].dispose();
      _antetSatirControllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    const dialogRadius = 16.0;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.enter): _kaydet,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _kaydet,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mediaQuery = MediaQuery.of(context);
            final isMobile = mediaQuery.size.width < 600;
            final dialogWidth = isMobile ? mediaQuery.size.width * 0.95 : 850.0;
            final maxDialogHeight = isMobile
                ? mediaQuery.size.height * 0.9
                : mediaQuery.size.height * 0.88;

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
                constraints: BoxConstraints(maxHeight: maxDialogHeight),
                padding: EdgeInsets.all(isMobile ? 20 : 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.duzenlenecekSirket != null
                                  ? tr('settings.company.dialog.title.edit')
                                  : tr('settings.company.dialog.title.add'),
                              style: TextStyle(
                                fontSize: isMobile ? 20 : 24,
                                fontWeight: FontWeight.w800,
                                color: _textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              if (!isMobile) ...[
                                Text(
                                  tr('common.esc'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF9AA0A6),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: const Icon(
                                    Icons.close,
                                    size: 24,
                                    color: _textColor,
                                  ),
                                )),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Kod ve Ad
                              if (isMobile) ...[
                                _buildUnderlinedField(
                                  controller: _kodController,
                                  label: tr('settings.company.dialog.code'),
                                  hint: tr('settings.company.dialog.code_hint'),
                                  helperText: tr(
                                    'settings.company.dialog.code_helper',
                                  ),
                                  helperColor: Colors.red,
                                  isRequired: true,
                                  icon: Icons.qr_code,
                                ),
                                const SizedBox(height: 24),
                                _buildUnderlinedField(
                                  controller: _adController,
                                  label: tr('settings.company.dialog.name'),
                                  hint: tr('settings.company.dialog.name_hint'),
                                  isRequired: true,
                                  icon: Icons.business,
                                ),
                              ] else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildUnderlinedField(
                                        controller: _kodController,
                                        label: tr(
                                          'settings.company.dialog.code',
                                        ),
                                        hint: tr(
                                          'settings.company.dialog.code_hint',
                                        ),
                                        helperText: tr(
                                          'settings.company.dialog.code_helper',
                                        ),
                                        helperColor: Colors.red,
                                        isRequired: true,
                                        icon: Icons.qr_code,
                                      ),
                                    ),
                                    const SizedBox(width: 32),
                                    Expanded(
                                      child: _buildUnderlinedField(
                                        controller: _adController,
                                        label: tr(
                                          'settings.company.dialog.name',
                                        ),
                                        hint: tr(
                                          'settings.company.dialog.name_hint',
                                        ),
                                        isRequired: true,
                                        icon: Icons.business,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 32),

                              // Firma Bilgileri
                              Text(
                                tr('settings.company.dialog.company_info'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _textColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildUnderlinedField(
                                controller: _adresController,
                                label: tr('settings.company.dialog.address'),
                                hint: tr(
                                  'settings.company.dialog.address_hint',
                                ),
                                icon: Icons.location_on_outlined,
                                maxLines: 3,
                              ),
                              const SizedBox(height: 20),
                              if (isMobile) ...[
                                _buildUnderlinedField(
                                  controller: _vergiDairesiController,
                                  label: tr(
                                    'settings.company.dialog.tax_office',
                                  ),
                                  hint: tr(
                                    'settings.company.dialog.tax_office_hint',
                                  ),
                                  icon: Icons.account_balance_outlined,
                                ),
                                const SizedBox(height: 20),
                                _buildUnderlinedField(
                                  controller: _vergiNoController,
                                  label: tr('settings.company.dialog.tax_no'),
                                  hint: tr(
                                    'settings.company.dialog.tax_no_hint',
                                  ),
                                  icon: Icons.numbers_rounded,
                                ),
                                const SizedBox(height: 20),
                                _buildUnderlinedField(
                                  controller: _telefonController,
                                  label: tr('settings.company.dialog.phone'),
                                  hint: tr(
                                    'settings.company.dialog.phone_hint',
                                  ),
                                  icon: Icons.phone_outlined,
                                ),
                                const SizedBox(height: 20),
                                _buildUnderlinedField(
                                  controller: _epostaController,
                                  label: tr('settings.company.dialog.email'),
                                  hint: tr(
                                    'settings.company.dialog.email_hint',
                                  ),
                                  icon: Icons.email_outlined,
                                ),
                                const SizedBox(height: 20),
                                _buildUnderlinedField(
                                  controller: _webController,
                                  label: tr('settings.company.dialog.website'),
                                  hint: tr(
                                    'settings.company.dialog.website_hint',
                                  ),
                                  icon: Icons.language_rounded,
                                ),
                              ] else ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildUnderlinedField(
                                        controller: _vergiDairesiController,
                                        label: tr(
                                          'settings.company.dialog.tax_office',
                                        ),
                                        hint: tr(
                                          'settings.company.dialog.tax_office_hint',
                                        ),
                                        icon: Icons.account_balance_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 32),
                                    Expanded(
                                      child: _buildUnderlinedField(
                                        controller: _vergiNoController,
                                        label: tr(
                                          'settings.company.dialog.tax_no',
                                        ),
                                        hint: tr(
                                          'settings.company.dialog.tax_no_hint',
                                        ),
                                        icon: Icons.numbers_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildUnderlinedField(
                                        controller: _telefonController,
                                        label: tr(
                                          'settings.company.dialog.phone',
                                        ),
                                        hint: tr(
                                          'settings.company.dialog.phone_hint',
                                        ),
                                        icon: Icons.phone_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 32),
                                    Expanded(
                                      child: _buildUnderlinedField(
                                        controller: _epostaController,
                                        label: tr(
                                          'settings.company.dialog.email',
                                        ),
                                        hint: tr(
                                          'settings.company.dialog.email_hint',
                                        ),
                                        icon: Icons.email_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildUnderlinedField(
                                  controller: _webController,
                                  label: tr('settings.company.dialog.website'),
                                  hint: tr(
                                    'settings.company.dialog.website_hint',
                                  ),
                                  icon: Icons.language_rounded,
                                ),
                              ],
                              const SizedBox(height: 32),

                              // Antet Satırı
                              if (isMobile)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr('settings.company.dialog.header_line'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (_antetSatirControllers.length >= 3)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          tr(
                                            'settings.company.dialog.header_line_limit',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFEA4335),
                                          ),
                                        ),
                                      ),
                                    MouseRegion(
                                      cursor: _antetSatirControllers.length >= 3
                                          ? SystemMouseCursors.basic
                                          : SystemMouseCursors.click,
                                      child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                                        onTap:
                                            _antetSatirControllers.length >= 3
                                            ? null
                                            : _antetSatirEkle,
                                        child: Opacity(
                                          opacity:
                                              _antetSatirControllers.length >= 3
                                              ? 0.5
                                              : 1.0,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.add,
                                                size: 18,
                                                color: _primaryColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                tr(
                                                  'settings.company.dialog.add_header_line',
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: _primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )),
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      tr('settings.company.dialog.header_line'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _textColor,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        if (_antetSatirControllers.length >= 3)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 12.0,
                                            ),
                                            child: Text(
                                              tr(
                                                'settings.company.dialog.header_line_limit',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFEA4335),
                                              ),
                                            ),
                                          ),
                                        MouseRegion(
                                          cursor:
                                              _antetSatirControllers.length >= 3
                                              ? SystemMouseCursors.basic
                                              : SystemMouseCursors.click,
                                          child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                                            onTap:
                                                _antetSatirControllers.length >=
                                                    3
                                                ? null
                                                : _antetSatirEkle,
                                            child: Opacity(
                                              opacity:
                                                  _antetSatirControllers
                                                          .length >=
                                                      3
                                                  ? 0.5
                                                  : 1.0,
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.add,
                                                    size: 18,
                                                    color: _primaryColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    tr(
                                                      'settings.company.dialog.add_header_line',
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: _primaryColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 12),
                              ..._antetSatirControllers.asMap().entries.map((
                                entry,
                              ) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildBoxField(
                                          controller: entry.value,
                                          hint:
                                              '${tr('settings.company.dialog.header_line_hint')} ${entry.key + 1}',
                                          icon: Icons.text_fields,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                                          onTap: () =>
                                              _antetSatirSil(entry.key),
                                          child: const Icon(
                                            Icons.delete_outline,
                                            color: Color(0xFFEA4335),
                                            size: 24,
                                          ),
                                        )),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 32),

                              // Antet Resimleri
                              Text(
                                tr('settings.company.dialog.header_images'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _textColor,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Logo Preview / Upload Area
                              if (_logoBytes != null)
                                Stack(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F9FA),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE0E0E0),
                                          width: 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.memory(
                                          _logoBytes!,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                                          onTap: _logoSil,
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.1),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.delete_outline,
                                              color: Color(0xFFEA4335),
                                              size: 20,
                                            ),
                                          ),
                                        )),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                                    onTap: _logoSec,
                                    child: Container(
                                      width: double.infinity,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F9FA),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFB2DFDB),
                                          width: 1,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.cloud_upload_outlined,
                                            size: 32,
                                            color: Color(0xFF26A69A),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            tr(
                                              'settings.company.dialog.upload_image',
                                            ),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF26A69A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            tr(
                                              'settings.company.image_formats',
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF9AA0A6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )),
                                ),

                              const SizedBox(height: 32),

                              // Radio Buttons Row
                              if (isMobile) ...[
                                _buildRadioGroup(
                                  title: tr('settings.company.dialog.status'),
                                  options: [
                                    _RadioOption(
                                      label: tr(
                                        'settings.company.dialog.active',
                                      ),
                                      value: 'active',
                                    ),
                                    _RadioOption(
                                      label: tr(
                                        'settings.company.dialog.passive',
                                      ),
                                      value: 'passive',
                                    ),
                                  ],
                                  groupValue: _aktifMi ? 'active' : 'passive',
                                  onChanged: (val) => setState(
                                    () => _aktifMi = val == 'active',
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildRadioGroup(
                                  title: tr(
                                    'settings.company.dialog.default_company',
                                  ),
                                  options: [
                                    _RadioOption(
                                      label: tr('settings.company.dialog.yes'),
                                      value: 'yes',
                                    ),
                                    _RadioOption(
                                      label: tr('settings.company.dialog.no'),
                                      value: 'no',
                                    ),
                                  ],
                                  groupValue: _varsayilanMi ? 'yes' : 'no',
                                  onChanged: (val) => setState(
                                    () => _varsayilanMi = val == 'yes',
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildRadioGroup(
                                  title: tr(
                                    'settings.company.dialog.changeable',
                                  ),
                                  options: [
                                    _RadioOption(
                                      label: tr('settings.company.dialog.yes'),
                                      value: 'yes',
                                    ),
                                    _RadioOption(
                                      label: tr('settings.company.dialog.no'),
                                      value: 'no',
                                    ),
                                  ],
                                  groupValue: _duzenlenebilirMi ? 'yes' : 'no',
                                  onChanged: (val) => setState(
                                    () => _duzenlenebilirMi = val == 'yes',
                                  ),
                                ),
                              ] else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildRadioGroup(
                                        title: tr(
                                          'settings.company.dialog.status',
                                        ),
                                        options: [
                                          _RadioOption(
                                            label: tr(
                                              'settings.company.dialog.active',
                                            ),
                                            value: 'active',
                                          ),
                                          _RadioOption(
                                            label: tr(
                                              'settings.company.dialog.passive',
                                            ),
                                            value: 'passive',
                                          ),
                                        ],
                                        groupValue: _aktifMi
                                            ? 'active'
                                            : 'passive',
                                        onChanged: (val) => setState(
                                          () => _aktifMi = val == 'active',
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildRadioGroup(
                                        title: tr(
                                          'settings.company.dialog.default_company',
                                        ),
                                        options: [
                                          _RadioOption(
                                            label: tr(
                                              'settings.company.dialog.yes',
                                            ),
                                            value: 'yes',
                                          ),
                                          _RadioOption(
                                            label: tr(
                                              'settings.company.dialog.no',
                                            ),
                                            value: 'no',
                                          ),
                                        ],
                                        groupValue: _varsayilanMi
                                            ? 'yes'
                                            : 'no',
                                        onChanged: (val) => setState(
                                          () => _varsayilanMi = val == 'yes',
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildRadioGroup(
                                        title: tr(
                                          'settings.company.dialog.changeable',
                                        ),
                                        options: [
                                          _RadioOption(
                                            label: tr(
                                              'settings.company.dialog.yes',
                                            ),
                                            value: 'yes',
                                          ),
                                          _RadioOption(
                                            label: tr(
                                              'settings.company.dialog.no',
                                            ),
                                            value: 'no',
                                          ),
                                        ],
                                        groupValue: _duzenlenebilirMi
                                            ? 'yes'
                                            : 'no',
                                        onChanged: (val) => setState(
                                          () =>
                                              _duzenlenebilirMi = val == 'yes',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Footer Buttons
                      if (isMobile)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final double maxRowWidth =
                                constraints.maxWidth > 320
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
                                        onPressed: _kaydet,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildUnderlinedField({
    required String label,
    String? hint,
    String? helperText,
    Color? helperColor,
    TextEditingController? controller,
    bool isRequired = false,
    IconData? icon,
    int maxLines = 1,
  }) {
    final labelColor = isRequired ? Colors.red : _labelColor;
    final borderColor = isRequired ? Colors.red : _borderColor;

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
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null
                ? Icon(icon, size: 20, color: _hintColor)
                : null,
            hintStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: _hintColor,
            ),
            helperText: helperText,
            helperStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: helperColor ?? _hintColor,
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
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
          ),
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return tr('validation.required');
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildBoxField({
    TextEditingController? controller,
    String? hint,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _textColor,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: _hintColor)
            : null,
        hintStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _hintColor,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: _textColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
      ),
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
            color: _textColor,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 24,
          runSpacing: 12,
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
                          color: isSelected ? _primaryColor : _textColor,
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _textColor,
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
