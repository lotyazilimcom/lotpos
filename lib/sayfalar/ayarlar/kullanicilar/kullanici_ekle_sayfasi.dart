import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../bilesenler/tek_tarih_secici_dialog.dart';

import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../servisler/ayarlar_veritabani_servisi.dart';
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import '../roller_ve_izinler/modeller/rol_model.dart';
import 'modeller/kullanici_model.dart';

class KullaniciEkleSayfasi extends StatefulWidget {
  const KullaniciEkleSayfasi({super.key, this.kullanici});

  final KullaniciModel? kullanici;

  @override
  State<KullaniciEkleSayfasi> createState() => _KullaniciEkleSayfasiState();
}

class _KullaniciEkleSayfasiState extends State<KullaniciEkleSayfasi> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  // Controllers
  late TextEditingController _adController;
  late TextEditingController _soyadController;
  late TextEditingController _kullaniciAdiController;
  late TextEditingController _epostaController;
  late TextEditingController _telefonController;
  late TextEditingController _sifreController;
  late TextEditingController _goreviController;
  late TextEditingController _maasiController;
  late TextEditingController _adresiController;
  late TextEditingController _bilgi1Controller;
  late TextEditingController _bilgi2Controller;

  String? _seciliRol;
  bool _aktifMi = true;
  DateTime? _iseGirisTarihi;
  String _paraBirimi = 'TRY';

  Uint8List? _profilResmi;
  String? _profilDosyaAdi;

  late _CountryCode _selectedCountry;

  static const Color _primaryColor = Color(0xFF2C3E50);

  List<RolModel> _mevcutRoller = [];
  bool _rollerYukleniyor = true;

  // Focus Nodes
  late FocusNode _adFocusNode;
  late FocusNode _maasiFocusNode;

  @override
  void initState() {
    super.initState();
    _adFocusNode = FocusNode();
    _maasiFocusNode = FocusNode();

    _rolleriYukle();
    _loadSettings();

    final kullanici = widget.kullanici;
    _adController = TextEditingController(text: kullanici?.ad ?? '');
    _soyadController = TextEditingController(text: kullanici?.soyad ?? '');
    _kullaniciAdiController = TextEditingController(
      text: kullanici?.kullaniciAdi ?? '',
    );
    _epostaController = TextEditingController(text: kullanici?.eposta ?? '');
    _sifreController = TextEditingController(text: kullanici?.sifre ?? '');
    _goreviController = TextEditingController(text: kullanici?.gorevi ?? '');
    _maasiController = TextEditingController(
      text: kullanici?.maasi != null ? kullanici!.maasi.toString() : '',
    );
    _adresiController = TextEditingController(text: kullanici?.adresi ?? '');
    _bilgi1Controller = TextEditingController(text: kullanici?.bilgi1 ?? '');
    _bilgi2Controller = TextEditingController(text: kullanici?.bilgi2 ?? '');

    _seciliRol = kullanici?.rol;
    _aktifMi = kullanici?.aktifMi ?? true;
    _iseGirisTarihi = kullanici?.iseGirisTarihi;
    _paraBirimi = kullanici?.paraBirimi ?? 'TRY';

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

    _attachPriceFormatter(_maasiFocusNode, _maasiController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adFocusNode.requestFocus();
    });
  }

  void _attachPriceFormatter(
    FocusNode focusNode,
    TextEditingController controller,
  ) {
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        final text = controller.text.trim();
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

        controller
          ..text = formatted
          ..selection = TextSelection.collapsed(offset: formatted.length);
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      if (mounted) {
        setState(() {
          _genelAyarlar = settings;
          // Mevcut veri varsa maaşı formatla
          if (widget.kullanici?.maasi != null) {
            _maasiController.text = FormatYardimcisi.sayiFormatla(
              widget.kullanici!.maasi!,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
              decimalDigits: _genelAyarlar.fiyatOndalik,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Ayarlar yüklenirken hata: $e');
    }
  }

  Future<void> _rolleriYukle() async {
    try {
      final roller = await AyarlarVeritabaniServisi().rolleriGetir(
        sayfa: 1,
        sayfaBasinaKayit: 1000,
      );
      if (mounted) {
        setState(() {
          _mevcutRoller = roller;
          _rollerYukleniyor = false;
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
    _adFocusNode.dispose();
    _maasiFocusNode.dispose();
    _adController.dispose();
    _soyadController.dispose();
    _kullaniciAdiController.dispose();
    _epostaController.dispose();
    _telefonController.dispose();
    _sifreController.dispose();
    _goreviController.dispose();
    _maasiController.dispose();
    _adresiController.dispose();
    _bilgi1Controller.dispose();
    _bilgi2Controller.dispose();
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

  Future<void> _tarihSec() async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(
        initialDate: _iseGirisTarihi ?? DateTime.now(),
        title: tr('settings.users.form.hire_date.label'),
      ),
    );
    if (picked != null) {
      setState(() {
        _iseGirisTarihi = picked;
      });
    }
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
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
        iseGirisTarihi: _iseGirisTarihi,
        gorevi: _goreviController.text.trim().isEmpty
            ? null
            : _goreviController.text.trim(),
        maasi: _maasiController.text.trim().isEmpty
            ? null
            : FormatYardimcisi.parseDouble(
                _maasiController.text,
                binlik: _genelAyarlar.binlikAyiraci,
                ondalik: _genelAyarlar.ondalikAyiraci,
              ),
        paraBirimi: _paraBirimi,
        adresi: _adresiController.text.trim().isEmpty
            ? null
            : _adresiController.text.trim(),
        bilgi1: _bilgi1Controller.text.trim().isEmpty
            ? null
            : _bilgi1Controller.text.trim(),
        bilgi2: _bilgi2Controller.text.trim().isEmpty
            ? null
            : _bilgi2Controller.text.trim(),
      );

      Navigator.of(context).pop(sonuc);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${tr('common.error')}: $e')));
    }
  }

  void _handleClear() {
    _formKey.currentState?.reset();
    _adController.clear();
    _soyadController.clear();
    _kullaniciAdiController.clear();
    _epostaController.clear();
    _telefonController.clear();
    _sifreController.clear();
    _goreviController.clear();
    _maasiController.clear();
    _adresiController.clear();
    _bilgi1Controller.clear();
    _bilgi2Controller.clear();

    setState(() {
      _seciliRol = null;
      _aktifMi = true;
      _iseGirisTarihi = null;
      _paraBirimi = 'TRY';
      _profilResmi = null;
      _profilDosyaAdi = null;
      _selectedCountry = _countryCodes.first;
    });
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
        // F4: Formu temizle
        const SingleActivator(LogicalKeyboardKey.f4): _handleClear,
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_isLoading) _kaydet();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_isLoading) _kaydet();
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
                widget.kullanici != null
                    ? tr('settings.users.edit.title')
                    : tr('settings.users.add.title'),
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
                                  'settings.users.form.section.personal',
                                ),
                                child: _buildPersonalInfoSection(theme),
                                icon: Icons.person_rounded,
                                color: Colors.blue.shade700,
                                compact: isCompact,
                              ),
                              SizedBox(height: isCompact ? 16 : 24),
                              _buildSection(
                                theme,
                                title: tr(
                                  'settings.users.form.section.account',
                                ),
                                child: _buildAccountInfoSection(theme),
                                icon: Icons.account_circle_rounded,
                                color: Colors.green.shade700,
                                compact: isCompact,
                              ),
                              SizedBox(height: isCompact ? 16 : 24),
                              _buildSection(
                                theme,
                                title: tr(
                                  'settings.users.form.section.employment',
                                ),
                                child: _buildEmploymentInfoSection(theme),
                                icon: Icons.work_rounded,
                                color: Colors.orange.shade700,
                                compact: isCompact,
                              ),
                              SizedBox(height: isCompact ? 16 : 24),
                              _buildSection(
                                theme,
                                title: tr(
                                  'settings.users.form.section.additional',
                                ),
                                child: _buildAdditionalInfoSection(theme),
                                icon: Icons.info_rounded,
                                color: Colors.purple.shade700,
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
                Container(
                  padding: isCompact
                      ? const EdgeInsets.fromLTRB(16, 12, 16, 12)
                      : const EdgeInsets.all(16),
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
                      constraints: BoxConstraints(
                        maxWidth: isCompact ? 760 : 850,
                      ),
                      child: _buildActionButtons(theme, compact: isCompact),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, {bool compact = false}) {
    final String title = widget.kullanici != null
        ? tr('settings.users.edit.title')
        : tr('settings.users.add.title');
    final String subtitle = widget.kullanici != null
        ? tr('settings.users.edit.subtitle')
        : tr('settings.users.add.subtitle');

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stack = constraints.maxWidth < 480;

        final iconWidget = Container(
          padding: EdgeInsets.all(compact ? 10 : 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.person_add_rounded,
            color: theme.colorScheme.primary,
            size: compact ? 24 : 28,
          ),
        );

        final textWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                fontSize: compact ? 20 : 23,
              ),
            ),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: compact ? 14 : 16,
              ),
            ),
          ],
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [iconWidget, const SizedBox(height: 10), textWidget],
          );
        }

        return Row(
          children: [
            iconWidget,
            const SizedBox(width: 16),
            Expanded(child: textWidget),
          ],
        );
      },
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
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontSize: compact ? 17 : 21,
                  ),
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

  Widget _buildPersonalInfoSection(ThemeData theme) {
    final requiredColor = Colors.red.shade700;
    final optionalColor = Colors.blue.shade700;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Column(
          children: [
            _buildRow(isWide, [
              _buildTextField(
                controller: _adController,
                label: tr('settings.users.form.name.label'),
                hint: tr('settings.users.form.name.hint'),
                isRequired: true,
                color: requiredColor,
                focusNode: _adFocusNode,
              ),
              _buildTextField(
                controller: _soyadController,
                label: tr('settings.users.form.surname.label'),
                hint: tr('settings.users.form.surname.hint'),
                isRequired: true,
                color: requiredColor,
              ),
            ]),
            const SizedBox(height: 16),
            _buildRow(isWide, [
              _buildPhoneInputRow(optionalColor),
              _buildTextField(
                controller: _epostaController,
                label: tr('settings.users.form.email.label'),
                hint: tr('settings.users.form.email.hint'),
                keyboardType: TextInputType.emailAddress,
                color: optionalColor,
                validator: (deger) {
                  if (deger != null && deger.isNotEmpty) {
                    if (!RegExp(
                      r'^[^@]+@[^@]+\.[^@]+',
                    ).hasMatch(deger.trim())) {
                      return tr('settings.users.form.invalid_email');
                    }
                  }
                  return null;
                },
              ),
            ]),
            const SizedBox(height: 16),
            _buildProfilePhotoSection(optionalColor),
          ],
        );
      },
    );
  }

  Widget _buildAccountInfoSection(ThemeData theme) {
    final requiredColor = Colors.red.shade700;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Column(
          children: [
            _buildRow(isWide, [
              _buildTextField(
                controller: _kullaniciAdiController,
                label: tr('settings.users.form.username.label'),
                hint: tr('settings.users.form.username.hint'),
                isRequired: true,
                color: requiredColor,
              ),
              _buildTextField(
                controller: _sifreController,
                label: tr('settings.users.form.password.label'),
                hint: tr('settings.users.form.password.hint'),
                obscureText: true,
                isRequired: widget.kullanici == null,
                color: requiredColor,
              ),
            ]),
            const SizedBox(height: 16),
            _buildRow(isWide, [
              _buildRolSecimi(requiredColor),
              _buildRadioGroup(
                title: tr('settings.users.form.status.label'),
                options: [
                  _RadioOption(
                    label: tr('settings.users.form.status.active'),
                    value: 'active',
                  ),
                  _RadioOption(
                    label: tr('settings.users.form.status.inactive'),
                    value: 'inactive',
                  ),
                ],
                groupValue: _aktifMi ? 'active' : 'inactive',
                onChanged: (val) => setState(() => _aktifMi = val == 'active'),
              ),
            ]),
          ],
        );
      },
    );
  }

  Widget _buildEmploymentInfoSection(ThemeData theme) {
    final color = Colors.orange.shade700;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Column(
          children: [
            _buildRow(isWide, [
              _buildDateField(
                label: tr('settings.users.form.hire_date.label'),
                value: _iseGirisTarihi,
                onTap: _tarihSec,
                color: color,
              ),
              _buildTextField(
                controller: _goreviController,
                label: tr('settings.users.form.position.label'),
                hint: tr('settings.users.form.position.hint'),
                color: color,
              ),
            ]),
            const SizedBox(height: 16),
            _buildSalaryRow(color),
          ],
        );
      },
    );
  }

  Widget _buildAdditionalInfoSection(ThemeData theme) {
    final color = Colors.purple.shade700;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Column(
          children: [
            _buildTextField(
              controller: _adresiController,
              label: tr('settings.users.form.address.label'),
              hint: tr('settings.users.form.address.hint'),
              color: color,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _buildRow(isWide, [
              _buildTextField(
                controller: _bilgi1Controller,
                label: tr('settings.users.form.info1.label'),
                hint: tr('settings.users.form.info1.hint'),
                color: color,
              ),
              _buildTextField(
                controller: _bilgi2Controller,
                label: tr('settings.users.form.info2.label'),
                hint: tr('settings.users.form.info2.hint'),
                color: color,
              ),
            ]),
          ],
        );
      },
    );
  }

  Widget _buildSalaryRow(Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          return Column(
            children: [
              _buildTextField(
                controller: _maasiController,
                label: tr('settings.users.form.salary.label'),
                hint: tr('settings.users.form.salary.hint'),
                isNumeric: true,
                color: color,
                focusNode: _maasiFocusNode,
              ),
              const SizedBox(height: 12),
              _buildDropdown(
                value: _paraBirimi,
                label: tr('settings.users.form.currency.label'),
                items: ['TRY', 'USD', 'EUR'],
                onChanged: (val) => setState(() => _paraBirimi = val ?? 'TRY'),
                color: color,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildTextField(
                controller: _maasiController,
                label: tr('settings.users.form.salary.label'),
                hint: tr('settings.users.form.salary.hint'),
                isNumeric: true,
                color: color,
                focusNode: _maasiFocusNode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: _buildDropdown(
                value: _paraBirimi,
                label: tr('settings.users.form.currency.label'),
                items: ['TRY', 'USD', 'EUR'],
                onChanged: (val) => setState(() => _paraBirimi = val ?? 'TRY'),
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfilePhotoSection(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('settings.users.form.photo.label'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool stack = constraints.maxWidth < 420;
            final bool iconOnly = constraints.maxWidth < 360;

            final avatarWidget = Stack(
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
                      child: GestureDetector(
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
                            border: Border.all(color: const Color(0xFFE5E7EB)),
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
                      ),
                    ),
                  ),
              ],
            );

            final uploadButton = iconOnly
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

            final details = Column(
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
            );

            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatarWidget,
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: details),
                ],
              );
            }

            return Row(
              children: [
                avatarWidget,
                const SizedBox(width: 16),
                Expanded(child: details),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPhoneInputRow(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('settings.users.form.phone.label'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool stack = constraints.maxWidth < 430;

            final countryField = SizedBox(
              width: stack ? double.infinity : 120,
              child: DropdownButtonFormField<_CountryCode>(
                key: ValueKey(_selectedCountry),
                initialValue: _selectedCountry,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: color, width: 2),
                  ),
                ),
                icon: Icon(Icons.arrow_drop_down, color: color),
                selectedItemBuilder: (context) {
                  return _countryCodes.map((c) {
                    return Row(
                      children: [
                        Text(c.flag, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text(
                          c.dialCode,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
                        Text(c.flag, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.name,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          c.dialCode,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: tr('common.placeholder.phone'),
                hintStyle: TextStyle(
                  color: Colors.grey.withValues(alpha: 0.3),
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: color, width: 2),
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
                const SizedBox(width: 12),
                Expanded(child: phoneField),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRolSecimi(Color color) {
    if (_rollerYukleniyor) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('settings.users.form.role.label'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
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

    final bool rolListedeVar =
        _seciliRol == null || _mevcutRoller.any((r) => r.id == _seciliRol);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${tr('settings.users.form.role.label')} *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          key: ValueKey(rolListedeVar ? _seciliRol : null),
          initialValue: rolListedeVar ? _seciliRol : null,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: color, width: 2),
            ),
          ),
          items: _mevcutRoller
              .map(
                (rol) => DropdownMenuItem<String>(
                  value: rol.id,
                  child: Text(rol.ad, style: const TextStyle(fontSize: 14)),
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

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: color.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value != null
                        ? DateFormat('dd.MM.yyyy').format(value)
                        : tr('common.placeholder.date'),
                    style: TextStyle(
                      fontSize: 14,
                      color: value != null
                          ? Colors.black87
                          : Colors.grey.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                if (value != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _iseGirisTarihi = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: tr('common.clear'),
                  )
                else
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: color.withValues(alpha: 0.7),
                  ),
              ],
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
              child: GestureDetector(
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
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF202124),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme, {bool compact = false}) {
    if (compact) {
      final String saveLabel = widget.kullanici != null
          ? tr('settings.users.form.update')
          : tr('settings.users.form.save');

      return LayoutBuilder(
        builder: (context, constraints) {
          final double maxRowWidth = constraints.maxWidth > 320
              ? 320
              : constraints.maxWidth;
          const double gap = 10;
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
                    child: OutlinedButton.icon(
                      onPressed: _handleClear,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: Colors.grey.shade300),
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.refresh, size: 15),
                      label: Text(
                        tr('common.clear'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: buttonWidth,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _kaydet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              saveLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stackButtons = constraints.maxWidth < 520;

        final clearButton = TextButton(
          onPressed: _handleClear,
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 24,
              vertical: compact ? 14 : 20,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: compact ? 18 : 20),
              const SizedBox(width: 8),
              Text(
                tr('common.clear'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 14 : 15,
                ),
              ),
            ],
          ),
        );

        final saveButton = ElevatedButton(
          onPressed: _isLoading ? null : _kaydet,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 30 : 40,
              vertical: compact ? 16 : 20,
            ),
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
                  widget.kullanici != null
                      ? tr('settings.users.form.update')
                      : tr('settings.users.form.save'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 14 : 15,
                  ),
                ),
        );

        if (stackButtons) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: double.infinity, child: clearButton),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: saveButton),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [clearButton, const SizedBox(width: 12), saveButton],
        );
      },
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
    ValueChanged<String>? onChanged,
    bool readOnly = false,
    bool obscureText = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
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
          onChanged: onChanged,
          readOnly: readOnly,
          obscureText: obscureText,
          maxLines: maxLines,
          keyboardType:
              keyboardType ??
              (isNumeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text),
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
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
          validator:
              validator ??
              (isRequired
                  ? (value) {
                      if (value == null || value.isEmpty) {
                        return tr('validation.required');
                      }
                      return null;
                    }
                  : null),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.withValues(alpha: 0.3),
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

  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    bool isRequired = false,
    String? hint,
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
          key: ValueKey(value),
          initialValue: value,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.withValues(alpha: 0.3),
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
                  if (value == null) {
                    return tr('validation.required');
                  }
                  if (value is String && value.isEmpty) {
                    return tr('validation.required');
                  }
                  return null;
                }
              : null,
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

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(text[i])) {
        buffer.write(text[i]);
      }
    }

    final String digits = buffer.toString();
    final StringBuffer formatted = StringBuffer();

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
