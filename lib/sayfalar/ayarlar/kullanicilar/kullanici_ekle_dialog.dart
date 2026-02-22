import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../servisler/ayarlar_veritabani_servisi.dart';
import '../roller_ve_izinler/modeller/rol_model.dart';
import 'modeller/kullanici_model.dart';

class KullaniciEkleDialog extends StatefulWidget {
  const KullaniciEkleDialog({super.key, this.kullanici});

  final KullaniciModel? kullanici;

  @override
  State<KullaniciEkleDialog> createState() => _KullaniciEkleDialogState();
}

class _KullaniciEkleDialogState extends State<KullaniciEkleDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TextEditingController _adController;
  late TextEditingController _soyadController;
  late TextEditingController _kullaniciAdiController;
  late TextEditingController _epostaController;
  late TextEditingController _telefonController;
  late TextEditingController _sifreController;

  String? _seciliRol;
  bool _aktifMi = true;

  Uint8List? _profilResmi;
  String? _profilDosyaAdi;

  late _CountryCode _selectedCountry;

  static const Color _primaryColor = Color(0xFF2C3E50);

  List<RolModel> _mevcutRoller = [];
  bool _rollerYukleniyor = true;

  @override
  void initState() {
    super.initState();
    _rolleriYukle();
    final kullanici = widget.kullanici;
    _adController = TextEditingController(text: kullanici?.ad ?? '');
    _soyadController = TextEditingController(text: kullanici?.soyad ?? '');
    _kullaniciAdiController = TextEditingController(
      text: kullanici?.kullaniciAdi ?? '',
    );
    _epostaController = TextEditingController(text: kullanici?.eposta ?? '');
    _sifreController = TextEditingController(text: kullanici?.sifre ?? '');
    _seciliRol = kullanici?.rol;
    _aktifMi = kullanici?.aktifMi ?? true;

    // Telefon ayrıştırma
    String rawPhone = kullanici?.telefon ?? '';
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

    if (kullanici?.profilResmi != null && kullanici!.profilResmi!.isNotEmpty) {
      try {
        _profilResmi = base64Decode(kullanici.profilResmi!);
      } catch (e) {
        debugPrint('Profil resmi decode hatası: $e');
      }
    }
  }

  Future<void> _rolleriYukle() async {
    try {
      final roller = await AyarlarVeritabaniServisi().rolleriGetir(
        sayfa: 1,
        sayfaBasinaKayit: 1000, // Dropdown için yeterince büyük bir sayı
      );
      if (mounted) {
        setState(() {
          _mevcutRoller = roller;
          _rollerYukleniyor = false;

          // Eğer seçili rol listede yoksa (ve yeni kayıt değilse), varsayılanı seçme
          // Ama mevcut rol listede yoksa bile (silinmişse) dropdown'da göstermek gerekebilir
          // Şimdilik basit tutalım, veritabanından gelenleri gösterelim.

          if (_seciliRol == null && _mevcutRoller.isNotEmpty) {
            // Yeni kullanıcı eklerken varsayılan rol seçimi yapılabilir
            // _seciliRol = _mevcutRoller.first.id;
          }
        });
      }
    } catch (e) {
      debugPrint('Roller yüklenirken hata: $e');
      if (mounted) {
        setState(() {
          _rollerYukleniyor = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _kullaniciAdiController.dispose();
    _epostaController.dispose();
    _telefonController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  Future<void> _profilResmiSec() async {
    final XFile? dosya = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: tr('common.images'),
          extensions: ['png', 'jpg', 'jpeg'],
          uniformTypeIdentifiers: ['public.image'],
        ),
      ],
    );

    if (dosya == null) return;

    final Uint8List bytes = await dosya.readAsBytes();
    setState(() {
      _profilResmi = bytes;
      _profilDosyaAdi = dosya.name;
    });
  }

  void _kaydet() {
    if (!_formKey.currentState!.validate()) return;

    String? profilResmiBase64;
    if (_profilResmi != null) {
      profilResmiBase64 = base64Encode(_profilResmi!);
    }

    final KullaniciModel sonuc = KullaniciModel(
      id: widget.kullanici?.id ?? '',
      kullaniciAdi: _kullaniciAdiController.text.trim(),
      ad: _adController.text.trim(),
      soyad: _soyadController.text.trim(),
      eposta: _epostaController.text.trim(),
      rol: _seciliRol ?? 'admin',
      aktifMi: _aktifMi,
      telefon: _telefonController.text.trim().isNotEmpty
          ? '${_selectedCountry.dialCode} ${_telefonController.text.trim()}'
          : '',
      profilResmi: profilResmiBase64,
      sifre: _sifreController.text.isEmpty ? null : _sifreController.text,
    );

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

    Widget buildPhotoPicker({required bool compactPhotoAction}) {
      final uploadButton = compactPhotoAction
          ? OutlinedButton(
              onPressed: _profilResmiSec,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF374151),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                padding: const EdgeInsets.all(14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Icon(Icons.upload_file_rounded, size: 20),
            )
          : OutlinedButton.icon(
              onPressed: _profilResmiSec,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(tr('settings.users.form.photo.hint')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF374151),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('settings.users.form.photo.label'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A4A4A),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFFF9FAFB),
                      backgroundImage: _profilResmi != null
                          ? MemoryImage(_profilResmi!)
                          : null,
                      child: _profilResmi == null
                          ? const Icon(
                              Icons.person,
                              size: 32,
                              color: Color(0xFF9CA3AF),
                            )
                          : null,
                    ),
                  ),
                  if (_profilResmi != null)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _profilResmi = null;
                              _profilDosyaAdi = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        )),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    uploadButton,
                    if (_profilDosyaAdi != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _profilDosyaAdi!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return CallbackShortcuts(
      bindings: {
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
                                  widget.kullanici != null
                                      ? tr('settings.users.edit.title')
                                      : tr('settings.users.add.title'),
                                  style: TextStyle(
                                    fontSize: isCompact ? 19 : 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF202124),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.kullanici != null
                                      ? tr('settings.users.edit.subtitle')
                                      : tr('settings.users.add.subtitle'),
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
                              widget.kullanici != null
                                  ? tr('settings.users.edit.title')
                                  : tr('settings.users.add.title'),
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
                                  label: tr('settings.users.form.name.label'),
                                  hint: tr('settings.users.form.name.hint'),
                                  controller: _adController,
                                  isRequired: true,
                                  icon: Icons.person_outline,
                                );
                                final secondField = _buildUnderlinedField(
                                  label: tr(
                                    'settings.users.form.surname.label',
                                  ),
                                  hint: tr('settings.users.form.surname.hint'),
                                  controller: _soyadController,
                                  isRequired: true,
                                  icon: Icons.person_outline,
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
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool stack = constraints.maxWidth < 640;
                                final usernameField = _buildUnderlinedField(
                                  label: tr(
                                    'settings.users.form.username.label',
                                  ),
                                  hint: tr('settings.users.form.username.hint'),
                                  controller: _kullaniciAdiController,
                                  isRequired: true,
                                  icon: Icons.account_circle_outlined,
                                );
                                final passwordField = _buildUnderlinedField(
                                  label: tr(
                                    'settings.users.form.password.label',
                                  ),
                                  hint: tr('settings.users.form.password.hint'),
                                  controller: _sifreController,
                                  obscureText: true,
                                  isRequired: true,
                                  icon: Icons.lock_outline,
                                );

                                if (stack) {
                                  return Column(
                                    children: [
                                      usernameField,
                                      const SizedBox(height: 18),
                                      passwordField,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: usernameField),
                                    const SizedBox(width: 24),
                                    Expanded(child: passwordField),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 22),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool stack = constraints.maxWidth < 640;
                                final phoneField = _buildPhoneInputRow();
                                final emailField = _buildUnderlinedField(
                                  label: tr('settings.users.form.email.label'),
                                  hint: tr('settings.users.form.email.hint'),
                                  controller: _epostaController,
                                  keyboardType: TextInputType.emailAddress,
                                  icon: Icons.email_outlined,
                                  validator: (deger) {
                                    if (deger == null || deger.trim().isEmpty) {
                                      return tr('settings.users.form.required');
                                    }
                                    if (!RegExp(
                                      r'^[^@]+@[^@]+\.[^@]+',
                                    ).hasMatch(deger.trim())) {
                                      return tr(
                                        'settings.users.form.invalid_email',
                                      );
                                    }
                                    return null;
                                  },
                                );

                                if (stack) {
                                  return Column(
                                    children: [
                                      phoneField,
                                      const SizedBox(height: 18),
                                      emailField,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: phoneField),
                                    const SizedBox(width: 24),
                                    Expanded(child: emailField),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 22),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool stack = constraints.maxWidth < 760;
                                final bool compactPhotoAction =
                                    constraints.maxWidth < 360;

                                final photoSection = buildPhotoPicker(
                                  compactPhotoAction: compactPhotoAction,
                                );
                                final roleSection = _buildRolSecimi();

                                if (stack) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      photoSection,
                                      const SizedBox(height: 18),
                                      roleSection,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: photoSection),
                                    const SizedBox(width: 24),
                                    Expanded(child: roleSection),
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
                            widget.kullanici != null
                                ? tr('settings.users.form.update')
                                : tr('settings.users.form.save'),
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
                            const SizedBox(width: 16),
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
          decoration: InputDecoration(
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
          ),
        ),
      ],
    );
  }

  Widget _buildRolSecimi() {
    if (_rollerYukleniyor) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('settings.users.form.role.label'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4A4A4A),
            ),
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(
            backgroundColor: Color(0xFFE0E0E0),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2C3E50)),
          ),
        ],
      );
    }

    // Seçili rol listede yoksa (örn: silinmişse), null yap veya listeye ekle
    // Şimdilik null yapıp kullanıcıyı seçmeye zorlayalım veya eski değeri koruyalım
    // Eğer eski değer listede yoksa dropdown hata verir.
    // Bu yüzden listede olup olmadığını kontrol edelim.
    final bool rolListedeVar =
        _seciliRol == null || _mevcutRoller.any((r) => r.id == _seciliRol);

    // Eğer rol listede yoksa, geçici olarak ekleyelim ki hata vermesin
    // (veya null yapabiliriz ama kullanıcı eski rolünü görsün isteriz)
    // Ancak RolModel nesnesi lazım. Elimizde sadece ID var.
    // Basit çözüm: Eğer yoksa null yap.
    if (!rolListedeVar) {
      // _seciliRol = null; // State içinde değiştirmek build sırasında sorun olabilir
      // O yüzden value olarak null geçeceğiz eğer listede yoksa.
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('settings.users.form.role.label'),
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
          // value: rolListedeVar ? _seciliRol : null, // Deprecated use initialValue if not controlled
          // ignore: deprecated_member_use
          value: rolListedeVar ? _seciliRol : null,
          decoration: const InputDecoration(
            prefixIcon: Icon(
              Icons.assignment_ind_outlined,
              size: 20,
              color: Color(0xFFBDC1C6),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 12),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2C3E50), width: 2),
            ),
          ),
          items: _mevcutRoller
              .map(
                (rol) => DropdownMenuItem<String>(
                  value: rol.id,
                  child: Text(rol.ad),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _seciliRol = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return tr('settings.users.form.required');
            }
            return null;
          },
        ),
        if (!rolListedeVar && _seciliRol != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${tr('settings.users.role.unknown')}: $_seciliRol',
              style: const TextStyle(color: Colors.red, fontSize: 12),
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF202124),
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

  Widget _buildPhoneInputRow() {
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
            final bool stack = constraints.maxWidth < 430;

            final countryField = SizedBox(
              width: stack ? double.infinity : 135,
              child: DropdownButtonFormField<_CountryCode>(
                mouseCursor: WidgetStateMouseCursor.clickable,
                dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
                // ignore: deprecated_member_use
                value: _selectedCountry,
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF202124),
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
              keyboardType: TextInputType.phone,
              inputFormatters: [_PhoneInputFormatter()],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF202124),
              ),
              decoration: InputDecoration(
                hintText: tr('common.placeholder.phone'),
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
                  borderSide: BorderSide(color: Color(0xFF2C3E50), width: 2),
                ),
              ),
            );

            if (stack) {
              return Column(
                children: [
                  countryField,
                  const SizedBox(height: 12),
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
