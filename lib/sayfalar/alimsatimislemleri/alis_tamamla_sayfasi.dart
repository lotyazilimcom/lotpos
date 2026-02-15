import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../carihesaplar/modeller/cari_hesap_model.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import 'modeller/transaction_item.dart';
import '../../servisler/alisyap_veritabani_servisleri.dart';
import '../../bilesenler/akilli_aciklama_input.dart';
import '../../servisler/kasalar_veritabani_servisi.dart';
import '../../servisler/bankalar_veritabani_servisi.dart';
import '../../servisler/kredi_kartlari_veritabani_servisi.dart';
import '../../bilesenler/tek_tarih_secici_dialog.dart';
import '../../servisler/sayfa_senkronizasyon_servisi.dart';
import '../kasalar/modeller/kasa_model.dart';
import '../bankalar/modeller/banka_model.dart';
import '../kredikartlari/modeller/kredi_karti_model.dart';

/// Alış Tamamla Sayfası - "Alış Yap" butonuna tıklandığında açılan sayfa
/// Ürün listesi, cari hesap seçimi, fatura ve ödeme bilgilerini içerir.
class AlisTamamlaSayfasi extends StatefulWidget {
  final List<PurchaseItem> items;
  final double genelToplam;
  final double toplamIskonto;
  final double toplamKdv;
  final String paraBirimi;
  final Map<String, dynamic>? duzenlenecekIslem;

  const AlisTamamlaSayfasi({
    super.key,
    required this.items,
    required this.genelToplam,
    required this.toplamIskonto,
    required this.toplamKdv,
    required this.paraBirimi,
    this.selectedCariId,
    this.selectedCariName,
    this.selectedCariCode,
    this.orderId,
    this.duzenlenecekIslem,
  });

  final int? selectedCariId;
  final String? selectedCariName;
  final String? selectedCariCode;
  final int? orderId;

  @override
  State<AlisTamamlaSayfasi> createState() => _AlisTamamlaSayfasiState();
}

class _AlisTamamlaSayfasiState extends State<AlisTamamlaSayfasi> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();
  String? _editingIntegrationRef;

  // Cari Hesap Bilgileri
  final _cariAramaController = TextEditingController();
  final _cariAdiController = TextEditingController();
  int? _selectedCariId;
  String? _selectedCariCode;

  // Fatura Bilgileri
  final _tarihController = TextEditingController();
  DateTime _selectedTarih = DateTime.now();

  String _selectedBelge = 'Fatura';
  final List<String> _belgeTurleri = [
    '',
    'Fatura',
    'İrsaliye',
    'Fatura + İrsaliye',
    'Perakende',
    'Diğer',
  ];

  final _irsaliyeNoController = TextEditingController();
  final _faturaNoController = TextEditingController();

  final String _selectedAciklama = '';
  final List<String> _aciklamaListesi = [
    '',
    'Peşin Alış',
    'Vadeli Alış',
    'İade',
    'Değişim',
    'Numune',
    'Diğer',
  ];

  final String _selectedAciklama2 = '';
  final List<String> _aciklama2Listesi = [
    '',
    'Normal',
    'Acil',
    'Kampanyalı',
    'İndirimli',
    'Mağaza',
    'Online',
    'Diğer',
  ];

  // Vade Tarihi
  final _vadeTarihiController = TextEditingController();
  DateTime? _selectedVadeTarihi;

  // Tutar Bilgileri
  final _genelToplamController = TextEditingController();
  final _yuvarlamaController = TextEditingController();
  final _sonGenelToplamController = TextEditingController();
  final _verilenTutarController = TextEditingController();
  String _verilenTutarParaBirimi = 'TRY';

  final _aciklamaController = TextEditingController();
  final _aciklama2Controller = TextEditingController();

  // Ödeme Bilgileri
  String _selectedYer = 'Kasa';
  final List<String> _yerListesi = [
    'Kasa',
    'Banka',
    'Kredi Kartı',
    'Çek',
    'Senet',
    'Diğer',
  ];

  final _hesapKoduController = TextEditingController();
  final _hesapAdiController = TextEditingController();

  String _selectedOdemeAciklama = '';
  final List<String> _odemeAciklamaListesi = [
    '',
    'Nakit',
    'Havale',
    'EFT',
    'Kredi Kartı',
    'Çek',
    'Senet',
    'Diğer',
  ];

  final _kalanTutarController = TextEditingController();

  // Focus Nodes
  late FocusNode _cariAramaFocusNode;
  late FocusNode _verilenTutarFocusNode;
  late FocusNode _hesapKoduFocusNode;

  // Timer for Debounce
  Timer? _searchDebounce;
  Timer? _cariAramaDebounce;

  // Enter to Save

  // Style Constants (Proje stiline uyumlu)
  static const Color _primaryColor = Color(0xFF2C3E50);
  static const Color _textColor = Color(0xFF202124);

  @override
  void initState() {
    super.initState();
    _cariAramaFocusNode = FocusNode();
    _verilenTutarFocusNode = FocusNode();
    _hesapKoduFocusNode = FocusNode();

    _tarihController.text = DateFormat('dd.MM.yyyy').format(_selectedTarih);
    _yuvarlamaController.text = '0,00';
    _verilenTutarController.text = '0,00';

    if (widget.selectedCariId != null) {
      _selectedCariId = widget.selectedCariId;
      _selectedCariCode = widget.selectedCariCode;
      _cariAramaController.text = widget.selectedCariName ?? '';
      _cariAdiController.text = widget.selectedCariName ?? '';
    }

    _aciklamaController.text = _selectedAciklama;
    _aciklama2Controller.text = _selectedAciklama2;

    _loadSettings().then((_) async {
      if (!mounted) return;
      if (widget.duzenlenecekIslem != null) {
        await _initializeEditMode();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedCariId == null) {
        _cariAramaFocusNode.requestFocus();
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      if (mounted) {
        setState(() {
          _genelAyarlar = settings;
          _verilenTutarParaBirimi = widget.paraBirimi;

          // Tutar alanlarını doldur
          _genelToplamController.text = FormatYardimcisi.sayiFormatlaOndalikli(
            widget.genelToplam,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: _genelAyarlar.fiyatOndalik,
          );
          _sonGenelToplamController.text =
              FormatYardimcisi.sayiFormatlaOndalikli(
                widget.genelToplam,
                binlik: _genelAyarlar.binlikAyiraci,
                ondalik: _genelAyarlar.ondalikAyiraci,
                decimalDigits: _genelAyarlar.fiyatOndalik,
              );
          _kalanTutarController.text = FormatYardimcisi.sayiFormatlaOndalikli(
            widget.genelToplam,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: _genelAyarlar.fiyatOndalik,
          );
        });
      }
    } catch (e) {
      debugPrint('Ayarlar yüklenirken hata: $e');
    }
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  Future<void> _initializeEditMode() async {
    final edit = widget.duzenlenecekIslem;
    final ref = edit?['integration_ref']?.toString().trim();
    if (edit == null || ref == null || ref.isEmpty) return;

    final DateTime? editDate = _parseDate(edit['tarih'] ?? edit['date']);
    final DateTime? editVade = _parseDate(
      edit['vade_tarihi'] ?? edit['vadeTarihi'],
    );

    final String editFaturaNo = (edit['fatura_no'] ?? edit['faturaNo'] ?? '')
        .toString();
    final String editIrsaliyeNo =
        (edit['irsaliye_no'] ?? edit['irsaliyeNo'] ?? '').toString();
    final String editAciklama = (edit['aciklama'] ?? edit['description'] ?? '')
        .toString();
    final String editAciklama2 = (edit['aciklama2'] ?? '').toString();

    String? belgeTuru = (edit['belge'] ?? '').toString().trim();
    if (belgeTuru.isEmpty) {
      belgeTuru = await CariHesaplarVeritabaniServisi()
          .entegrasyonBelgeTuruGetir(ref);
    }

    String? matchedBelge;
    if (belgeTuru != null && belgeTuru.trim().isNotEmpty) {
      final normalized = belgeTuru.trim().toLowerCase();
      for (final b in _belgeTurleri) {
        if (b.toLowerCase() == normalized) {
          matchedBelge = b;
          break;
        }
      }
    }

    setState(() {
      _editingIntegrationRef = ref;

      if (editDate != null) {
        _selectedTarih = editDate;
        _tarihController.text = DateFormat('dd.MM.yyyy').format(editDate);
      }

      if (editVade != null) {
        _selectedVadeTarihi = editVade;
        _vadeTarihiController.text = DateFormat('dd.MM.yyyy').format(editVade);
      }

      if (matchedBelge != null) {
        _selectedBelge = matchedBelge;
      }

      _faturaNoController.text = editFaturaNo;
      _irsaliyeNoController.text = editIrsaliyeNo;
      _aciklamaController.text = editAciklama;
      _aciklama2Controller.text = editAciklama2;
    });

    final odeme = await CariHesaplarVeritabaniServisi()
        .entegrasyonOdemeBilgisiGetir(ref);
    if (!mounted) return;

    if (odeme != null) {
      final String odemeYeri = (odeme['odemeYeri'] ?? '').toString();
      final double tutar = (odeme['tutar'] is num)
          ? (odeme['tutar'] as num).toDouble()
          : double.tryParse((odeme['tutar'] ?? '0').toString()) ?? 0.0;
      final String hesapKodu = (odeme['hesapKodu'] ?? '').toString();
      final String hesapAdi = (odeme['hesapAdi'] ?? '').toString();
      final String odemeAciklama = (odeme['odemeAciklama'] ?? '').toString();

      setState(() {
        if (_yerListesi.contains(odemeYeri)) {
          _selectedYer = odemeYeri;
        }
        _hesapKoduController.text = hesapKodu;
        _hesapAdiController.text = hesapAdi;

        final normalizedOdemeAciklama = odemeAciklama.trim().toLowerCase();
        for (final opt in _odemeAciklamaListesi) {
          final optLower = opt.trim().toLowerCase();
          if (optLower.isEmpty) continue;
          if (normalizedOdemeAciklama == optLower ||
              normalizedOdemeAciklama.startsWith('$optLower ') ||
              normalizedOdemeAciklama.startsWith('$optLower-') ||
              normalizedOdemeAciklama.startsWith('$optLower|') ||
              normalizedOdemeAciklama.startsWith('$optLower:')) {
            _selectedOdemeAciklama = opt;
            break;
          }
        }

        _verilenTutarController.text = FormatYardimcisi.sayiFormatlaOndalikli(
          tutar,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.fiyatOndalik,
        );
      });

      _calculateKalanTutar();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _cariAramaDebounce?.cancel();
    _cariAramaController.dispose();
    _cariAdiController.dispose();
    _tarihController.dispose();
    _irsaliyeNoController.dispose();
    _faturaNoController.dispose();
    _vadeTarihiController.dispose();
    _genelToplamController.dispose();
    _yuvarlamaController.dispose();
    _sonGenelToplamController.dispose();
    _verilenTutarController.dispose();
    _hesapKoduController.dispose();
    _hesapAdiController.dispose();
    _kalanTutarController.dispose();
    _cariAramaFocusNode.dispose();
    _verilenTutarFocusNode.dispose();
    _hesapKoduFocusNode.dispose();
    _aciklamaController.dispose();
    _aciklama2Controller.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context, {
    bool isVadeTarihi = false,
  }) async {
    final initialDate = isVadeTarihi
        ? (_selectedVadeTarihi ?? DateTime.now())
        : _selectedTarih;

    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(
        initialDate: initialDate,
        title: isVadeTarihi ? tr('common.validity_date') : tr('common.date'),
      ),
    );

    if (picked != null) {
      setState(() {
        if (isVadeTarihi) {
          _selectedVadeTarihi = picked;
          _vadeTarihiController.text = DateFormat('dd.MM.yyyy').format(picked);
        } else {
          _selectedTarih = picked;
          _tarihController.text = DateFormat('dd.MM.yyyy').format(picked);
        }
      });
    }
  }

  void _calculateKalanTutar() {
    final sonGenelToplam = FormatYardimcisi.parseDouble(
      _sonGenelToplamController.text,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
    );
    final verilenTutar = FormatYardimcisi.parseDouble(
      _verilenTutarController.text,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
    );

    final kalan = sonGenelToplam - verilenTutar;
    setState(() {
      _kalanTutarController.text = FormatYardimcisi.sayiFormatlaOndalikli(
        kalan < 0 ? 0 : kalan,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: _genelAyarlar.fiyatOndalik,
      );
    });
  }

  void _setVerilenTutarToAll() {
    setState(() {
      _verilenTutarController.text = _sonGenelToplamController.text;
      _verilenTutarController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _verilenTutarController.text.length,
      );
    });
    _calculateKalanTutar();
  }

  void _calculateSonGenelToplam() {
    final genelToplam = FormatYardimcisi.parseDouble(
      _genelToplamController.text,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
    );
    final yuvarlama = FormatYardimcisi.parseDouble(
      _yuvarlamaController.text,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
    );

    final sonToplam = genelToplam + yuvarlama;
    setState(() {
      _sonGenelToplamController.text = FormatYardimcisi.sayiFormatlaOndalikli(
        sonToplam,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: _genelAyarlar.fiyatOndalik,
      );
    });
    _calculateKalanTutar();
  }

  void _clearVadeTarihi() {
    setState(() {
      _selectedVadeTarihi = null;
      _vadeTarihiController.clear();
    });
  }

  void _clearHesapFields() {
    setState(() {
      _hesapKoduController.clear();
      _hesapAdiController.clear();
    });
  }

  void _openCariSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _CariSearchDialogWrapper(
        onSelect: (cari) {
          setState(() {
            _selectedCariId = cari.id;
            _selectedCariCode = cari.kodNo;
            _cariAramaController.text = cari.adi;
            _cariAdiController.text = cari.adi;
          });
        },
      ),
    );
  }

  Future<void> _openHesapSearchDialog() async {
    switch (_selectedYer) {
      case 'Kasa':
        _showKasaSearchDialog();
        break;
      case 'Banka':
        _showBankaSearchDialog();
        break;
      case 'Kredi Kartı':
        _showKrediKartiSearchDialog();
        break;
      default:
        MesajYardimcisi.bilgiGoster(
          context,
          tr('common.payment.no_account_required_or_manual_entry'),
        );
    }
  }

  void _showKasaSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _KasaSearchDialog(
        onSelect: (kasa) {
          setState(() {
            _hesapKoduController.text = kasa.kod;
            _hesapAdiController.text = kasa.ad;
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
            _hesapKoduController.text = banka.kod;
            _hesapAdiController.text = banka.ad;
          });
        },
      ),
    );
  }

  void _showKrediKartiSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _KrediKartiSearchDialog(
        onSelect: (kart) {
          setState(() {
            _hesapKoduController.text = kart.kod;
            _hesapAdiController.text = kart.ad;
          });
        },
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCariId == null) {
      MesajYardimcisi.hataGoster(
        context,
        tr('purchase.complete.error.no_customer'),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final currentUser = prefs.getString('current_username') ?? 'Sistem';

      // Servis üzerinden kayıt işlemi
      final alisBilgileri = {
        'cariId': _selectedCariId,
        'selectedCariCode': _selectedCariCode,
        'selectedCariName': _cariAdiController.text,
        'kullanici': currentUser,
        'tarih': _selectedTarih,
        'vadeTarihi': _selectedVadeTarihi,
        'belgeTuru': _selectedBelge,
        'irsaliyeNo': _irsaliyeNoController.text,
        'faturaNo': _faturaNoController.text,
        'aciklama': _aciklamaController.text,
        'aciklama2': _aciklama2Controller.text,
        'paraBirimi': widget.paraBirimi == 'TL' ? 'TRY' : widget.paraBirimi,
        'kur': widget.items.isNotEmpty ? widget.items.first.exchangeRate : 1.0,
        'genelToplam': FormatYardimcisi.parseDouble(
          _genelToplamController.text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        ),
        'odemeYeri': _selectedYer,
        'odemeHesapKodu': _hesapKoduController.text,
        'odemeAciklama': _selectedOdemeAciklama,
        'verilenTutar': FormatYardimcisi.parseDouble(
          _verilenTutarController.text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        ),
        'items': widget.items
            .map(
              (e) => {
                'name': e.name,
                'code': e.code,
                'unit': e.unit,
                'quantity': e.quantity,
                'price': e.netUnitPrice,
                'total': e.total,
                'discountRate': e.discountRate,
                'vatRate': e.vatRate,
                'vatIncluded': e.vatIncluded,
                'otvRate': e.otvRate,
                'otvIncluded': e.otvIncluded,
                'oivRate': e.oivRate,
                'oivIncluded': e.oivIncluded,
                'kdvTevkifatOrani': e.kdvTevkifatOrani,
                'warehouseId': e.warehouseId,
                'warehouseName': e.warehouseName,
                'exchangeRate': e.exchangeRate,
                'currency': e.currency,
                'serialNumber': e.serialNumber,
              },
            )
            .toList(),
        'orderRef': widget.orderId,
        'orderStatus': tr('orders.status.converted'),
      };

      if (_editingIntegrationRef != null) {
        await AlisYapVeritabaniServisi().alisIsleminiGuncelle(
          oldIntegrationRef: _editingIntegrationRef!,
          newAlisBilgileri: alisBilgileri,
        );
      } else {
        await AlisYapVeritabaniServisi().alisIsleminiKaydet(
          alisBilgileri: alisBilgileri,
        );
      }

      if (!mounted) return;

      MesajYardimcisi.basariGoster(context, tr('common.saved_successfully'));
      SayfaSenkronizasyonServisi().veriDegisti('cari');

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isMobileLayout = MediaQuery.sizeOf(context).width < 900;
    final double pagePadding = isMobileLayout ? 12 : 16;
    final double sectionGap = isMobileLayout ? 16 : 24;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_isLoading) _handleSave();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_isLoading) _handleSave();
        },
      },
      child: Focus(
        autofocus: true,
        canRequestFocus: true,
        skipTraversal: false,
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
            leadingWidth: 80,
            title: Text(
              tr('purchase.complete.title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: isMobileLayout ? 19 : 21,
              ),
            ),
            centerTitle: false,
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(pagePadding),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobileLayout ? 760 : 1000,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(theme),
                            SizedBox(height: isMobileLayout ? 20 : 32),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth > 900) {
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Sol sütun: Cari Hesap + Ödeme
                                      Expanded(
                                        child: Column(
                                          children: [
                                            _buildSection(
                                              theme,
                                              title: tr(
                                                'purchase.complete.section.customer',
                                              ),
                                              child: _buildCariHesapSection(
                                                theme,
                                              ),
                                              icon: Icons.person_rounded,
                                              color: Colors.blue.shade700,
                                            ),
                                            SizedBox(height: sectionGap),
                                            _buildSection(
                                              theme,
                                              title: tr(
                                                'purchase.complete.section.payment',
                                              ),
                                              child:
                                                  _buildOdemeBilgileriSection(
                                                    theme,
                                                  ),
                                              icon: Icons.payment_rounded,
                                              color: Colors.purple.shade700,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      // Sağ sütun: Belge + Tutar
                                      Expanded(
                                        child: Column(
                                          children: [
                                            _buildSection(
                                              theme,
                                              title: tr(
                                                'purchase.complete.section.document',
                                              ),
                                              child:
                                                  _buildBelgeBilgileriSection(
                                                    theme,
                                                  ),
                                              icon: Icons.description_rounded,
                                              color: Colors.green.shade700,
                                            ),
                                            SizedBox(height: sectionGap),
                                            _buildSection(
                                              theme,
                                              title: tr(
                                                'purchase.complete.section.totals',
                                              ),
                                              child:
                                                  _buildTutarBilgileriSection(
                                                    theme,
                                                  ),
                                              icon: Icons.calculate_rounded,
                                              color: Colors.orange.shade700,
                                              compactHeader: true,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  return Column(
                                    children: [
                                      _buildSection(
                                        theme,
                                        title: tr(
                                          'purchase.complete.section.customer',
                                        ),
                                        child: _buildCariHesapSection(theme),
                                        icon: Icons.person_rounded,
                                        color: Colors.blue.shade700,
                                        isCompact: isMobileLayout,
                                      ),
                                      SizedBox(height: sectionGap),
                                      _buildSection(
                                        theme,
                                        title: tr(
                                          'purchase.complete.section.payment',
                                        ),
                                        child: _buildOdemeBilgileriSection(
                                          theme,
                                        ),
                                        icon: Icons.payment_rounded,
                                        color: Colors.purple.shade700,
                                        isCompact: isMobileLayout,
                                      ),
                                      SizedBox(height: sectionGap),
                                      _buildSection(
                                        theme,
                                        title: tr(
                                          'purchase.complete.section.document',
                                        ),
                                        child: _buildBelgeBilgileriSection(
                                          theme,
                                        ),
                                        icon: Icons.description_rounded,
                                        color: Colors.green.shade700,
                                        isCompact: isMobileLayout,
                                      ),
                                      SizedBox(height: sectionGap),
                                      _buildSection(
                                        theme,
                                        title: tr(
                                          'purchase.complete.section.totals',
                                        ),
                                        child: _buildTutarBilgileriSection(
                                          theme,
                                        ),
                                        icon: Icons.calculate_rounded,
                                        color: Colors.orange.shade700,
                                        isCompact: isMobileLayout,
                                        compactHeader: true,
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                            SizedBox(height: isMobileLayout ? 24 : 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final bool isCompact = MediaQuery.sizeOf(context).width < 760;

    final Widget totalChip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(isCompact ? 10 : 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('purchase.complete.total'),
            style: TextStyle(
              color: _primaryColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              fontSize: isCompact ? 12 : 14,
            ),
          ),
          SizedBox(width: isCompact ? 6 : 8),
          Text(
            '${FormatYardimcisi.sayiFormatlaOndalikli(widget.genelToplam, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${widget.paraBirimi}',
            style: TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: isCompact ? 14 : 16,
            ),
          ),
        ],
      ),
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shopping_cart_checkout_rounded,
                  color: _primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('purchase.complete.title'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        fontSize: 19,
                      ),
                    ),
                    Text(
                      '${widget.items.length} ${tr("purchase.complete.items_count")}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          totalChip,
        ],
      );
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.shopping_cart_checkout_rounded,
            color: _primaryColor,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('purchase.complete.title'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontSize: 23,
                ),
              ),
              Text(
                '${widget.items.length} ${tr("purchase.complete.items_count")}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        totalChip,
      ],
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required String title,
    required Widget child,
    required IconData icon,
    required Color color,
    bool compactHeader = false,
    bool isCompact = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: isCompact ? 12 : 20,
            offset: Offset(0, isCompact ? 4 : 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(isCompact ? 14 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all((compactHeader || isCompact) ? 6 : 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    (compactHeader || isCompact) ? 6 : 10,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: (compactHeader || isCompact) ? 16 : 20,
                ),
              ),
              SizedBox(width: (compactHeader || isCompact) ? 10 : 16),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontSize: (compactHeader || isCompact) ? 15 : 18,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: (compactHeader || isCompact) ? 14 : 24),
          child,
        ],
      ),
    );
  }

  Widget _buildResponsiveRow({
    required Widget first,
    required Widget second,
    double spacing = 16,
    bool forceNarrow = false,
  }) {
    final bool isCompact =
        forceNarrow || MediaQuery.sizeOf(context).width < 700;
    if (isCompact) {
      return Column(
        children: [
          first,
          SizedBox(height: spacing),
          second,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: first),
        SizedBox(width: spacing),
        Expanded(child: second),
      ],
    );
  }

  Widget _buildCariHesapSection(ThemeData theme) {
    const requiredColor = Colors.red;
    return Column(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${tr('purchase.find_customer')} *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: requiredColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  tr('purchase.search_hint_customer'),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                return RawAutocomplete<CariHesapModel>(
                  focusNode: _cariAramaFocusNode,
                  textEditingController: _cariAramaController,
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<CariHesapModel>.empty();
                    }

                    if (_cariAramaDebounce?.isActive ?? false) {
                      _cariAramaDebounce!.cancel();
                    }

                    final completer = Completer<Iterable<CariHesapModel>>();

                    _cariAramaDebounce = Timer(
                      const Duration(milliseconds: 500),
                      () async {
                        try {
                          final results = await CariHesaplarVeritabaniServisi()
                              .cariHesaplariGetir(
                                aramaTerimi: textEditingValue.text,
                                sayfaBasinaKayit: 10,
                              );
                          if (!completer.isCompleted) {
                            completer.complete(results);
                          }
                        } catch (e) {
                          if (!completer.isCompleted) completer.complete([]);
                        }
                      },
                    );

                    return completer.future;
                  },
                  onSelected: (CariHesapModel selection) {
                    setState(() {
                      _selectedCariId = selection.id;
                      _selectedCariCode = selection.kodNo;
                      _cariAramaController.text = selection.adi;
                      _cariAdiController.text = selection.adi;
                    });
                  },
                  displayStringForOption: (CariHesapModel option) => option.adi,
                  fieldViewBuilder:
                      (
                        BuildContext context,
                        TextEditingController textEditingController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted,
                      ) {
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          style: const TextStyle(fontSize: 17),
                          validator: (value) {
                            if (_selectedCariId == null) {
                              return tr('validation.required');
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: tr('common.search'),
                            hintStyle: TextStyle(
                              color: Colors.grey.withValues(alpha: 0.3),
                              fontSize: 16,
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.search,
                                color: Colors.grey,
                              ),
                              onPressed: _openCariSearchDialog,
                            ),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: requiredColor.withValues(alpha: 0.3),
                              ),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: requiredColor.withValues(alpha: 0.3),
                              ),
                            ),
                            errorBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: requiredColor),
                            ),
                            focusedErrorBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: requiredColor,
                                width: 2,
                              ),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: requiredColor,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                          onFieldSubmitted: (String value) {
                            onFieldSubmitted();
                          },
                        );
                      },
                  optionsViewBuilder:
                      (
                        BuildContext context,
                        AutocompleteOnSelected<CariHesapModel> onSelected,
                        Iterable<CariHesapModel> options,
                      ) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: 300,
                                maxWidth: constraints.maxWidth,
                              ),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shrinkWrap: true,
                                itemCount: options.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (BuildContext context, int index) {
                                  final option = options.elementAt(index);
                                  return InkWell(
                                    onTap: () => onSelected(option),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            option.adi,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              color: Color(0xFF202124),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Builder(
                                            builder: (context) {
                                              final term = _cariAramaController
                                                  .text
                                                  .toLowerCase();
                                              String subtitle =
                                                  '${option.fatSehir} • ${option.hesapTuru}';

                                              if (term.isNotEmpty) {
                                                if (option.kodNo
                                                    .toLowerCase()
                                                    .contains(term)) {
                                                  subtitle =
                                                      '${tr('common.code')}: ${option.kodNo}';
                                                } else if (option.telefon1
                                                        .contains(term) ||
                                                    option.telefon2.contains(
                                                      term,
                                                    )) {
                                                  subtitle =
                                                      'Tel: ${option.telefon1}';
                                                } else if (option.fatAdresi
                                                        .toLowerCase()
                                                        .contains(term) ||
                                                    option.fatIlce
                                                        .toLowerCase()
                                                        .contains(term)) {
                                                  subtitle =
                                                      'Adres: ${option.fatAdresi}';
                                                }
                                              }

                                              return Text(
                                                subtitle,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            },
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
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _cariAdiController,
          label: tr('purchase.complete.field.customer_name'),
          isRequired: true,
          color: requiredColor,
          readOnly: true,
        ),
      ],
    );
  }

  Widget _buildBelgeBilgileriSection(ThemeData theme) {
    final optionalColor = Colors.green.shade700;
    const requiredColor = Colors.red;

    return Column(
      children: [
        _buildResponsiveRow(
          first: _buildDateField(
            controller: _tarihController,
            label: tr('common.date'),
            isRequired: true,
            color: requiredColor,
            onTap: () => _selectDate(context),
          ),
          second: _buildDropdown(
            value: _selectedBelge,
            label: tr('purchase.complete.field.document'),
            items: _belgeTurleri,
            onChanged: (val) => setState(() => _selectedBelge = val!),
            color: optionalColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildResponsiveRow(
          first: _buildTextField(
            controller: _irsaliyeNoController,
            label: tr('purchase.complete.field.waybill_no'),
            color: optionalColor,
          ),
          second: _buildTextField(
            controller: _faturaNoController,
            label: tr('purchase.complete.field.invoice_no'),
            color: optionalColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildResponsiveRow(
          first: AkilliAciklamaInput(
            controller: _aciklamaController,
            label: tr('shipment.field.description'),
            category: 'purchase_description',
            defaultItems: _aciklamaListesi,
          ),
          second: AkilliAciklamaInput(
            controller: _aciklama2Controller,
            label: tr('common.description2'),
            category: 'purchase_description_2',
            defaultItems: _aciklama2Listesi,
          ),
        ),
        const SizedBox(height: 16),
        _buildVadeTarihiField(theme),
      ],
    );
  }

  Widget _buildTutarBilgileriSection(ThemeData theme) {
    final color = Colors.orange.shade700;

    return Column(
      children: [
        _buildResponsiveRow(
          first: _buildTutarField(
            controller: _genelToplamController,
            label: tr('purchase.complete.field.grand_total'),
            currency: widget.paraBirimi,
            color: color,
            readOnly: true,
          ),
          second: _buildTutarField(
            controller: _yuvarlamaController,
            label: tr('purchase.complete.field.rounding'),
            currency: widget.paraBirimi,
            color: color,
            onChanged: (_) => _calculateSonGenelToplam(),
          ),
        ),
        const SizedBox(height: 16),
        _buildTutarField(
          controller: _sonGenelToplamController,
          label: tr('purchase.complete.field.final_total'),
          currency: widget.paraBirimi,
          color: _primaryColor,
          readOnly: true,
          isHighlighted: true,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 700;
            if (isCompact) {
              return Column(
                children: [
                  _buildTutarField(
                    controller: _verilenTutarController,
                    label: tr('purchase.complete.field.paid_amount'),
                    currency: '',
                    color: color,
                    focusNode: _verilenTutarFocusNode,
                    onChanged: (_) => _calculateKalanTutar(),
                    selectAllOnTap: true,
                    suffixIcon: IconButton(
                      tooltip: tr('common.all'),
                      icon: Icon(Icons.done_all, size: 18, color: color),
                      onPressed: _setVerilenTutarToAll,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    value: _verilenTutarParaBirimi,
                    label: tr('purchase.field.currency'),
                    items: ['TRY', 'USD', 'EUR'],
                    onChanged: (val) =>
                        setState(() => _verilenTutarParaBirimi = val!),
                    color: color,
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTutarField(
                    controller: _verilenTutarController,
                    label: tr('purchase.complete.field.paid_amount'),
                    currency: '',
                    color: color,
                    focusNode: _verilenTutarFocusNode,
                    onChanged: (_) => _calculateKalanTutar(),
                    selectAllOnTap: true,
                    suffixIcon: IconButton(
                      tooltip: tr('common.all'),
                      icon: Icon(Icons.done_all, size: 18, color: color),
                      onPressed: _setVerilenTutarToAll,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildDropdown(
                    value: _verilenTutarParaBirimi,
                    label: '',
                    items: ['TRY', 'USD', 'EUR'],
                    onChanged: (val) =>
                        setState(() => _verilenTutarParaBirimi = val!),
                    color: color,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildOdemeBilgileriSection(ThemeData theme) {
    final color = Colors.purple.shade700;

    return Column(
      children: [
        _buildDropdown(
          value: _selectedYer,
          label: tr('purchase.complete.field.location'),
          items: _yerListesi,
          onChanged: (val) {
            setState(() => _selectedYer = val!);
            _clearHesapFields();
          },
          color: color,
        ),
        const SizedBox(height: 16),
        _buildHesapAutocompleteField(
          controller: _hesapKoduController,
          label: tr('purchase.complete.field.account_code'),
          color: color,
          focusNode: _hesapKoduFocusNode,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _hesapAdiController,
          label: tr('purchase.complete.field.account_name'),
          color: color,
          readOnly: true,
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          value: _selectedOdemeAciklama,
          label: tr('shipment.field.description'),
          items: _odemeAciklamaListesi,
          onChanged: (val) => setState(() => _selectedOdemeAciklama = val!),
          color: color,
        ),
        const SizedBox(height: 16),
        _buildTutarField(
          controller: _kalanTutarController,
          label: tr('purchase.complete.field.remaining_amount'),
          currency: widget.paraBirimi,
          color: Colors.red.shade700,
          readOnly: true,
          isHighlighted: true,
        ),
      ],
    );
  }

  Widget _buildFooter(ThemeData theme) {
    final bool isCompact = MediaQuery.sizeOf(context).width < 760;
    return Container(
      padding: EdgeInsets.all(isCompact ? 12.0 : 16.0),
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
          constraints: BoxConstraints(maxWidth: isCompact ? 760 : 1000),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
                                tr('purchase.complete.button.complete'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          tr('common.back'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        tr('common.back'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
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
                              tr('purchase.complete.button.complete'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumeric = false,
    bool isRequired = false,
    bool readOnly = false,
    Color? color,
    FocusNode? focusNode,
    void Function(String)? onChanged,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? _primaryColor;

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
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: isNumeric
              ? [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                  LengthLimitingTextInputFormatter(20),
                ]
              : null,
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
          onChanged: onChanged,
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return tr('validation.required');
            }
            return null;
          },
          decoration: InputDecoration(
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
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          ),
        ),
      ],
    );
  }

  Widget _buildHesapAutocompleteField({
    required TextEditingController controller,
    required String label,
    required FocusNode focusNode,
    bool isRequired = false,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? _primaryColor;

    Future<Iterable<Map<String, String>>> search(String query) async {
      if (query.isEmpty) return [];

      try {
        List<Map<String, String>> results = [];

        switch (_selectedYer) {
          case 'Kasa':
            final items = await KasalarVeritabaniServisi().kasalariGetir(
              aramaKelimesi: query,
              sayfaBasinaKayit: 10,
            );
            results = items
                .where((e) => e.aktifMi)
                .map((e) => {'code': e.kod, 'name': e.ad, 'address': ''})
                .toList();
            break;
          case 'Banka':
            final items = await BankalarVeritabaniServisi().bankalariGetir(
              aramaKelimesi: query,
              sayfaBasinaKayit: 10,
            );
            results = items
                .where((e) => e.aktifMi)
                .map((e) => {'code': e.kod, 'name': e.ad, 'address': ''})
                .toList();
            break;
          case 'Kredi Kartı':
            final items = await KrediKartlariVeritabaniServisi()
                .krediKartlariniGetir(
                  aramaKelimesi: query,
                  sayfaBasinaKayit: 10,
                );
            results = items
                .where((e) => e.aktifMi)
                .map((e) => {'code': e.kod, 'name': e.ad, 'address': ''})
                .toList();
            break;
          default:
            return [];
        }

        return results;
      } catch (e) {
        debugPrint('Hesap arama hatası: $e');
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
                color: effectiveColor,
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
          displayStringForOption: (option) => option['code'] ?? '',
          onSelected: (option) {
            setState(() {
              controller.text = option['code'] ?? '';
              _hesapAdiController.text = option['name'] ?? '';
            });
          },
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
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
                      icon: Icon(Icons.search, color: effectiveColor),
                      onPressed: _openHesapSearchDialog,
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
                    isDense: true,
                    contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
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
                  constraints: const BoxConstraints(
                    maxHeight: 250,
                    maxWidth: 400,
                  ),
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
                                option['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Color(0xFF202124),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                option['code'] ?? '',
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
    bool isRequired = false,
    Color? color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? _primaryColor;

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
                    readOnly: true,
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
                      hintText: tr('common.placeholder.date'),
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
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
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
                  });
                },
                tooltip: tr('common.clear'),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: effectiveColor,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required String label,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool isRequired = false,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? _primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Text(
            isRequired ? '$label *' : label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: effectiveColor,
              fontSize: 14,
            ),
          ),
        if (label.isNotEmpty) const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          key: ValueKey(value),
          initialValue: items.contains(value) ? value : null,
          decoration: InputDecoration(
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
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item.isEmpty ? '-' : item,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down, color: effectiveColor),
          validator: isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return tr('validation.required');
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildTutarField({
    required TextEditingController controller,
    required String label,
    required String currency,
    Color? color,
    bool readOnly = false,
    bool isHighlighted = false,
    FocusNode? focusNode,
    void Function(String)? onChanged,
    Widget? suffixIcon,
    bool selectAllOnTap = false,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? _primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
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
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                readOnly: readOnly,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: isHighlighted ? 18 : 17,
                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                  color: isHighlighted ? effectiveColor : _textColor,
                ),
                onChanged: onChanged,
                onTap: selectAllOnTap
                    ? () {
                        if (controller.text.isNotEmpty) {
                          controller.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: controller.text.length,
                          );
                        }
                      }
                    : null,
                decoration: InputDecoration(
                  suffixIcon: suffixIcon,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
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
                  isDense: true,
                  contentPadding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                ),
              ),
            ),
            if (currency.isNotEmpty)
              Text(
                currency,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: effectiveColor,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildVadeTarihiField(ThemeData theme) {
    final effectiveColor = _selectedVadeTarihi != null
        ? Colors.orange.shade700
        : Colors.grey.shade400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('purchase.complete.field.due_date'),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: _vadeTarihiController,
          readOnly: true,
          onTap: () => _selectDate(context, isVadeTarihi: true),
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
          decoration: InputDecoration(
            hintText:
                "${tr('common.placeholder.date')} (${tr('common.optional')})",
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.withValues(alpha: 0.3),
              fontSize: 16,
            ),
            suffixIcon: _selectedVadeTarihi != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                    onPressed: _clearVadeTarihi,
                    tooltip: tr('common.clear'),
                  )
                : Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: Colors.grey.shade600,
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
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          ),
        ),
      ],
    );
  }
}

// --- CARI ARAMA DIALOG ---
class _CariSearchDialogWrapper extends StatefulWidget {
  final Function(CariHesapModel) onSelect;
  const _CariSearchDialogWrapper({required this.onSelect});

  @override
  State<_CariSearchDialogWrapper> createState() =>
      _CariSearchDialogWrapperState();
}

class _CariSearchDialogWrapperState extends State<_CariSearchDialogWrapper> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<CariHesapModel> _carilar = [];
  bool _isLoading = false;
  Timer? _debounce;
  static const Color _primaryColor = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    _searchCari('');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
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
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchCari(query);
    });
  }

  Future<void> _searchCari(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await CariHesaplarVeritabaniServisi().cariHesaplariGetir(
        aramaTerimi: query,
        sayfaBasinaKayit: 50,
        sortAscending: true,
        sortBy: 'adi',
        aktifMi: true,
      );
      if (mounted) {
        setState(() {
          _carilar = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double dialogRadius = 14;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dialogRadius),
      ),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(dialogRadius),
        ),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
        child: Column(
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('accounts.search.title'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('accounts.search.subtitle'),
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
                  children: [
                    Text(
                      tr('common.esc'),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: Color(0xFF606368),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Search Field
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(
                hintText: tr('common.search'),
                hintStyle: TextStyle(
                  color: Colors.grey.withValues(alpha: 0.4),
                  fontSize: 16,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: _primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: _primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            // Results
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _primaryColor),
                    )
                  : _carilar.isEmpty
                  ? Center(
                      child: Text(
                        tr('common.no_results'),
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _carilar.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final cari = _carilar[index];
                        return InkWell(
                          onTap: () {
                            widget.onSelect(cari);
                            Navigator.of(context).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 4,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline,
                                    color: _primaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cari.adi,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Color(0xFF202124),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${tr('common.code')}: ${cari.kodNo} • ${cari.hesapTuru} • ${cari.fatSehir}',
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
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

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
              Icons.account_balance,
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
                    color: const Color(0xFFE8F0FE),
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
            const Icon(Icons.credit_card, size: 48, color: Color(0xFFE0E0E0)),
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
                    color: const Color(0xFFE8F5E9),
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
