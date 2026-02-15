import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../../servisler/urunler_veritabani_servisi.dart';
import '../../servisler/uretimler_veritabani_servisi.dart';
import '../../servisler/depolar_veritabani_servisi.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../urunler_ve_depolar/urunler/modeller/urun_model.dart';
import '../urunler_ve_depolar/uretimler/modeller/uretim_model.dart';
import '../urunler_ve_depolar/depolar/modeller/depo_model.dart';
import '../carihesaplar/modeller/cari_hesap_model.dart';
import '../../bilesenler/onay_dialog.dart';
import '../../bilesenler/akilli_aciklama_input.dart';
import 'package:intl/intl.dart';
import '../../servisler/siparisler_veritabani_servisi.dart';
import 'modeller/siparis_model.dart';
import '../../bilesenler/tek_tarih_secici_dialog.dart';

class SiparisEkleSayfasi extends StatefulWidget {
  final String tur;
  final SiparisModel? initialOrder;
  const SiparisEkleSayfasi({super.key, required this.tur, this.initialOrder});

  @override
  State<SiparisEkleSayfasi> createState() => _SiparisEkleSayfasiState();
}

class _SiparisEkleSayfasiState extends State<SiparisEkleSayfasi> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  // Completion Step Controls
  final _tarihController = TextEditingController();
  DateTime _selectedTarih = DateTime.now();
  final _aciklamaController = TextEditingController();
  final _aciklama2Controller = TextEditingController();
  final _gecerlilikTarihiController = TextEditingController();
  DateTime? _selectedGecerlilikTarihi;
  final _genelToplamController = TextEditingController();
  final _yuvarlamaController = TextEditingController();
  final _yuvarlamaFocusNode = FocusNode();
  final _sonGenelToplamController = TextEditingController();

  late FocusNode _cariKodStep2FocusNode;
  late FocusNode _sonGenelToplamFocusNode;
  Timer? _cariAramaStep2Debounce;

  // Depo Listesi
  List<DepoModel> _depolar = [];
  DepoModel? _selectedDepo;

  // Cari Hesap (OPSİYONEL)
  CariHesapModel? _selectedCari;
  final _cariKodController = TextEditingController();
  final _cariAdiController = TextEditingController();

  // Ürün Ekleme Form Kontrolleri
  final _urunKodController = TextEditingController();
  final _urunAdiController = TextEditingController();
  final _birimFiyatiController = TextEditingController();
  final _miktarController = TextEditingController();
  final _iskontoController = TextEditingController();
  final _birimController = TextEditingController();

  String _selectedParaBirimi = 'TRY';
  String _selectedKdvDurumu = 'excluded';
  double _kdvOrani = 0;

  // Ürün Listesi
  final List<Map<String, dynamic>> _eklenenUrunler = [];
  final Set<int> _selectedUrunIndices = {};

  // Inline Editing State
  int? _editingIndex;
  String? _editingField; // 'price', 'discount', 'quantity'

  // Focus Nodes
  final FocusNode _urunKodFocusNode = FocusNode();
  final FocusNode _urunAdiFocusNode = FocusNode();
  final FocusNode _miktarFocusNode = FocusNode();
  final FocusNode _birimFiyatiFocusNode = FocusNode();
  Timer? _searchDebounce;

  // Seçili Ürün
  UrunModel? _selectedUrun;
  List<UrunModel> _lastOptions = [];
  int _highlightedIndex = -1;

  // Style Constants
  static const Color _primaryColor = Color(0xFF2C3E50);
  static const Color _textColor = Color(0xFF202124);
  static const Color _borderColor = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _cariKodStep2FocusNode = FocusNode();
    _sonGenelToplamFocusNode = FocusNode();

    _tarihController.text = DateFormat('dd.MM.yyyy').format(_selectedTarih);
    _yuvarlamaController.text = '0,00';

    if (widget.initialOrder != null) {
      final order = widget.initialOrder!;
      _selectedTarih = order.tarih;
      _tarihController.text = DateFormat('dd.MM.yyyy').format(_selectedTarih);
      _aciklamaController.text = order.aciklama;
      _aciklama2Controller.text = order.aciklama2;
      _selectedGecerlilikTarihi = order.gecerlilikTarihi;
      _selectedParaBirimi = order.paraBirimi;
      _selectedCari = CariHesapModel(
        id: order.cariId ?? 0,
        kodNo: order.cariKod ?? '',
        adi: order.cariAdi ?? '',
      );
      _cariKodController.text = _selectedCari!.kodNo;
      _cariAdiController.text = _selectedCari!.adi;

      for (final item in order.urunler) {
        _eklenenUrunler.add({
          'urunId': item.urunId,
          'urunKodu': item.urunKodu,
          'urunAdi': item.urunAdi,
          'barkod': item.barkod,
          'depoId': item.depoId,
          'depoAdi': item.depoAdi,
          'kdvOrani': item.kdvOrani,
          'miktar': item.miktar,
          'birim': item.birim,
          'birimFiyati': item.birimFiyati,
          'paraBirimi': item.paraBirimi,
          'kdvDurumu': item.kdvDurumu,
          'iskonto': item.iskonto,
          'toplamFiyati': item.toplamFiyati,
        });
      }
      _hesaplaGenelToplam();
    }

    _loadSettings();
    _loadDepolar();
    _attachPriceFormatter(_birimFiyatiFocusNode, _birimFiyatiController);
    _attachPriceFormatter(_yuvarlamaFocusNode, _yuvarlamaController);
    // Keyboard shortcuts
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
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
      setState(() {
        _genelAyarlar = settings;
        _selectedParaBirimi = settings.varsayilanParaBirimi;
        _selectedKdvDurumu = settings.varsayilanKdvDurumu;
      });
      _hesaplaGenelToplam();
    } catch (e) {
      debugPrint('Ayarlar yüklenirken hata: $e');
    }
  }

  Future<void> _loadDepolar() async {
    try {
      final depolar = await DepolarVeritabaniServisi().depolariGetir(
        aktifMi: true,
      );
      setState(() {
        _depolar = depolar;
        if (depolar.isNotEmpty) _selectedDepo = depolar.first;
      });
    } catch (e) {
      debugPrint('Depolar yüklenirken hata: $e');
    }
  }

  @override
  void dispose() {
    _cariKodController.dispose();
    _cariAdiController.dispose();
    _urunKodController.dispose();
    _urunAdiController.dispose();
    _birimFiyatiController.dispose();
    _miktarController.dispose();
    _iskontoController.dispose();
    _birimController.dispose();
    _urunKodFocusNode.dispose();
    _urunAdiFocusNode.dispose();
    _miktarFocusNode.dispose();
    _birimFiyatiFocusNode.dispose();
    _searchDebounce?.cancel();
    _searchDebounce?.cancel();
    _cariAramaStep2Debounce?.cancel();
    _tarihController.dispose();
    _aciklamaController.dispose();
    _aciklama2Controller.dispose();
    _gecerlilikTarihiController.dispose();
    _genelToplamController.dispose();
    _yuvarlamaController.dispose();
    _yuvarlamaFocusNode.dispose();
    _sonGenelToplamController.dispose();
    _cariKodStep2FocusNode.dispose();
    _sonGenelToplamFocusNode.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.f1) {
        _addUrunToList();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.f3) {
        _searchUrun();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.f4) {
        _handleClear();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.f6) {
        _removeAllUrunler();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.f8) {
        _removeSelectedUrunler();
        return true;
      } else if ((event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
          !_birimFiyatiFocusNode.hasFocus &&
          !_miktarFocusNode.hasFocus &&
          !_urunKodFocusNode.hasFocus &&
          !_urunAdiFocusNode.hasFocus) {
        if (!_isLoading) _handleSave();
        return true;
      }
    }
    return false;
  }

  void _handleClear() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedCari = null;
      _selectedUrun = null;
      _cariKodController.clear();
      _cariAdiController.clear();
      _urunKodController.clear();
      _urunAdiController.clear();
      _birimFiyatiController.clear();
      _miktarController.clear();
      _iskontoController.clear();
      _birimController.clear();
      _eklenenUrunler.clear();
      _selectedUrunIndices.clear();
    });
  }

  Future<void> _handleSave() async {
    if (_eklenenUrunler.isEmpty) {
      MesajYardimcisi.uyariGoster(
        context,
        tr('orders.form.error.items_required'),
      );
      return;
    }

    if (_tarihController.text.isEmpty) {
      MesajYardimcisi.hataGoster(context, tr('orders.complete.error.no_date'));
      return;
    }

    // Toplamları yeniden hesapla (son kontrol)
    _hesaplaGenelToplam();

    final sonToplam = FormatYardimcisi.parseDouble(
      _sonGenelToplamController.text,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
    );

    if (sonToplam < 0) {
      MesajYardimcisi.hataGoster(
        context,
        tr('orders.complete.error.no_final_total'),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.initialOrder != null) {
        await SiparislerVeritabaniServisi().siparisGuncelle(
          orderId: widget.initialOrder!.id,
          tur: widget.tur,
          durum: widget.initialOrder!.durum,
          tarih: _selectedTarih,
          cariId: _selectedCari?.id,
          cariKod: _selectedCari?.kodNo ?? '',
          cariAdi: _selectedCari?.adi ?? '',
          ilgiliHesapAdi: _selectedCari?.adi ?? '',
          tutar: sonToplam,
          kur: 1.0,
          aciklama: _aciklamaController.text,
          aciklama2: _aciklama2Controller.text,
          gecerlilikTarihi: _selectedGecerlilikTarihi,
          paraBirimi: _selectedParaBirimi,
          urunler: _eklenenUrunler,
        );
      } else {
        await SiparislerVeritabaniServisi().siparisEkle(
          tur: widget.tur,
          durum: 'Beklemede',
          tarih: _selectedTarih,
          cariId: _selectedCari?.id,
          cariKod: _selectedCari?.kodNo ?? '',
          cariAdi: _selectedCari?.adi ?? '',
          ilgiliHesapAdi: _selectedCari?.adi ?? '',
          tutar: sonToplam,
          kur: 1.0,
          aciklama: _aciklamaController.text,
          aciklama2: _aciklama2Controller.text,
          gecerlilikTarihi: _selectedGecerlilikTarihi,
          paraBirimi: _selectedParaBirimi,
          urunler: _eklenenUrunler,
        );
      }

      if (!mounted) return;
      MesajYardimcisi.basariGoster(context, tr('orders.save_success'));

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  void _addUrunToList() {
    if (_selectedUrun == null) {
      MesajYardimcisi.uyariGoster(context, tr('orders.error.product_required'));
      return;
    }

    final miktar = FormatYardimcisi.parseDouble(
      _miktarController.text,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
    );

    if (miktar <= 0) {
      MesajYardimcisi.uyariGoster(
        context,
        tr('common.error.enter_valid_amount'),
      );
      return;
    }

    final birimFiyati = FormatYardimcisi.parseDouble(
      _birimFiyatiController.text,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
    );

    final iskonto = FormatYardimcisi.parseDouble(
      _iskontoController.text,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
    );

    double araToplam = miktar * birimFiyati;
    if (iskonto > 0) {
      araToplam = araToplam * (1 - iskonto / 100);
    }

    double toplamFiyati = araToplam;
    final String kdvStatus = _selectedKdvDurumu.toLowerCase();
    if (kdvStatus == 'excluded' || kdvStatus == 'hariç') {
      toplamFiyati = araToplam * (1 + _kdvOrani / 100);
    }

    setState(() {
      _eklenenUrunler.add({
        'urunId': _selectedUrun!.id,
        'urunKodu': _selectedUrun!.kod,
        'urunAdi': _selectedUrun!.ad,
        'barkod': _selectedUrun!.barkod,
        'depoId': _selectedDepo?.id,
        'depoAdi': _selectedDepo?.ad ?? '',
        'kdvOrani': _kdvOrani,
        'miktar': miktar,
        'birim': _birimController.text.isNotEmpty
            ? _birimController.text
            : _selectedUrun!.birim,
        'birimFiyati': birimFiyati,
        'paraBirimi': _selectedParaBirimi,
        'kdvDurumu': _selectedKdvDurumu,
        'iskonto': iskonto,
        'toplamFiyati': toplamFiyati,
      });

      _hesaplaGenelToplam();

      // Temizle
      _selectedUrun = null;
      _urunKodController.clear();
      _urunAdiController.clear();
      _birimFiyatiController.clear();
      _miktarController.clear();
      _iskontoController.clear();
      _birimController.clear();
      _kdvOrani = 0;
    });
  }

  void _removeSelectedUrunler() {
    if (_selectedUrunIndices.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr('common.confirm_delete_selected'),
        onayButonMetni: tr('common.delete'),
        isDestructive: true,
        onOnay: () {
          setState(() {
            final indices = _selectedUrunIndices.toList()
              ..sort((a, b) => b.compareTo(a));
            for (final index in indices) {
              if (index < _eklenenUrunler.length) {
                _eklenenUrunler.removeAt(index);
              }
            }
            _selectedUrunIndices.clear();
          });
          _hesaplaGenelToplam();
        },
      ),
    );
  }

  void _removeAllUrunler() {
    if (_eklenenUrunler.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr('common.confirm_delete_all'),
        onayButonMetni: tr('common.delete'),
        isDestructive: true,
        onOnay: () {
          setState(() {
            _eklenenUrunler.clear();
            _selectedUrunIndices.clear();
          });
          _hesaplaGenelToplam();
        },
      ),
    );
  }

  Future<void> _searchUrun() async {
    final selected = await showDialog<UrunModel>(
      context: context,
      builder: (context) => const _ProductSelectionDialog(),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedUrun = selected;
        _urunKodController.text = selected.kod;
        _urunAdiController.text = selected.ad;
        _birimController.text = selected.birim;
        _kdvOrani = selected.kdvOrani;
        _birimFiyatiController.text = FormatYardimcisi.sayiFormatlaOndalikli(
          selected.satisFiyati1,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.fiyatOndalik,
        );
      });
      _miktarFocusNode.requestFocus();
    }
  }

  Future<void> _searchCari() async {
    final selected = await showDialog<CariHesapModel>(
      context: context,
      builder: (context) => const _CariSelectionDialog(),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedCari = selected;
        _cariKodController.text = selected.kodNo;
        _cariAdiController.text = selected.adi;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isMobileLayout = MediaQuery.sizeOf(context).width < 900;
    final double pagePadding = isMobileLayout ? 12 : 16;
    final double sectionGap = isMobileLayout ? 16 : 24;

    return Focus(
      autofocus: true,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(theme, isMobileLayout: isMobileLayout),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(pagePadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobileLayout ? 760 : 900,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(theme, isCompact: isMobileLayout),
                          SizedBox(height: isMobileLayout ? 24 : 32),
                          _buildSection(
                            theme,
                            title: tr('orders.info_section'),
                            child: _buildOrderInfoSection(theme),
                            icon: Icons.receipt_long_rounded,
                            color: Colors.blue.shade700,
                            isCompact: isMobileLayout,
                          ),
                          SizedBox(height: sectionGap),
                          _buildSection(
                            theme,
                            title: tr('orders.add_item'),
                            child: _buildProductAddSection(
                              theme,
                              isCompact: isMobileLayout,
                            ),
                            icon: Icons.add_shopping_cart_rounded,
                            color: Colors.deepOrange.shade700,
                            isCompact: isMobileLayout,
                          ),
                          SizedBox(height: sectionGap),
                          _buildSection(
                            theme,
                            title:
                                '${tr('orders.section.added_products')} (${_eklenenUrunler.length})',
                            child: _buildProductListSection(theme),
                            icon: Icons.list_alt_rounded,
                            color: Colors.green.shade700,
                            action: isMobileLayout
                                ? _buildMobileTableActions()
                                : _buildTableActions(),
                            isCompact: isMobileLayout,
                          ),
                          SizedBox(height: sectionGap),
                          _buildSection(
                            theme,
                            title: tr('orders.complete.section.document'),
                            child: _buildBelgeBilgileriSectionStep2(
                              theme,
                              isCompact: isMobileLayout,
                            ),
                            icon: Icons.description_rounded,
                            color: Colors.purple.shade700,
                            isCompact: isMobileLayout,
                          ),
                          SizedBox(height: sectionGap),
                          _buildSection(
                            theme,
                            title: tr('orders.complete.section.totals'),
                            child: _buildTutarBilgileriSectionStep2(theme),
                            icon: Icons.calculate_rounded,
                            color: Colors.orange.shade700,
                            isCompact: isMobileLayout,
                          ),
                          SizedBox(height: isMobileLayout ? 24 : 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildBottomActions(theme, isCompact: isMobileLayout),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    ThemeData theme, {
    bool isMobileLayout = false,
  }) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          if (!isMobileLayout)
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
      leadingWidth: isMobileLayout ? 56 : 80,
      title: Text(
        tr('orders.add'),
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: isMobileLayout ? 18 : 21,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildHeader(ThemeData theme, {bool isCompact = false}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isCompact ? 10 : 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.add_box_rounded,
            color: theme.colorScheme.primary,
            size: isCompact ? 24 : 28,
          ),
        ),
        SizedBox(width: isCompact ? 12 : 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('orders.add'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isCompact ? 20 : 23,
              ),
            ),
            if (!isCompact)
              Text(
                tr('orders.create_prompt'),
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
    Widget? action,
    bool isCompact = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: isCompact ? 16 : 20,
            offset: const Offset(0, 8),
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
                padding: EdgeInsets.all(isCompact ? 8 : 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: isCompact ? 18 : 20),
              ),
              SizedBox(width: isCompact ? 10 : 16),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isCompact ? 17 : 21,
                  ),
                ),
              ),
              if (action != null) ...[const SizedBox(width: 8), action],
            ],
          ),
          SizedBox(height: isCompact ? 16 : 24),
          child,
        ],
      ),
    );
  }

  Widget _buildTableActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedUrunIndices.isNotEmpty)
          Tooltip(
            message: tr('common.delete_selected_items'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _removeSelectedUrunler,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA4335),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${tr('common.delete_selected_items')} (${_selectedUrunIndices.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          tr('common.key.f8'),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_selectedUrunIndices.isNotEmpty && _eklenenUrunler.isNotEmpty)
          const SizedBox(width: 8),
        if (_eklenenUrunler.isNotEmpty)
          Tooltip(
            message: tr('common.delete_all'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _removeAllUrunler,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF5350),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_forever, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        tr('common.delete_all'),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          tr('common.key.f6'),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileTableActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        if (_selectedUrunIndices.isNotEmpty)
          InkWell(
            onTap: _removeSelectedUrunler,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEA4335),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${tr('common.delete_selected_items')} (${_selectedUrunIndices.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_eklenenUrunler.isNotEmpty)
          InkWell(
            onTap: _removeAllUrunler,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.delete_forever,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tr('common.delete_all'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOrderInfoSection(ThemeData theme) {
    final requiredColor = Colors.red.shade700;
    final optionalColor = Colors.blue.shade700;

    return Column(
      children: [
        _buildDropdown<DepoModel>(
          value: _selectedDepo,
          label: tr('orders.field.warehouse'),
          items: _depolar,
          itemLabel: (d) => d.ad,
          onChanged: (v) => setState(() => _selectedDepo = v),
          isRequired: true,
          color: requiredColor,
        ),
        const SizedBox(height: 16),
        // Cari Hesap Bul - alis_yap_sayfasi.dart ile birebir aynı yapı
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  tr('accounts.search_title'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: optionalColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  tr('accounts.search_fields_hint'),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _cariAdiController,
              readOnly: true,
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(
                hintText: tr('accounts.select_or_leave_blank'),
                hintStyle: TextStyle(
                  color: Colors.grey.withValues(alpha: 0.3),
                  fontSize: 16,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedCari != null)
                      IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedCari = null;
                            _cariKodController.clear();
                            _cariAdiController.clear();
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.grey),
                      onPressed: _searchCari,
                    ),
                  ],
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: optionalColor.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: optionalColor.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: optionalColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onTap: _searchCari,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductAutocompleteField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool isRequired,
    required bool isCodeField,
    String? searchHint,
    Widget? suffixIcon,
    void Function()? onExternalSubmit,
  }) {
    final effectiveColor = isRequired
        ? Colors.deepOrange.shade700
        : _primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isRequired ? '$label *' : label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: effectiveColor,
                fontSize: 14,
              ),
            ),
            if (searchHint != null) ...[
              const SizedBox(width: 6),
              Text(
                searchHint,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            return RawAutocomplete<UrunModel>(
              focusNode: focusNode,
              textEditingController: controller,
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<UrunModel>.empty();
                }

                if (_searchDebounce?.isActive ?? false) {
                  _searchDebounce!.cancel();
                }

                final completer = Completer<Iterable<UrunModel>>();

                _searchDebounce = Timer(
                  const Duration(milliseconds: 500),
                  () async {
                    try {
                      final urunlerFuture = UrunlerVeritabaniServisi()
                          .urunleriGetir(
                            aramaTerimi: textEditingValue.text,
                            sayfaBasinaKayit: 10,
                          );
                      final uretimlerFuture = UretimlerVeritabaniServisi()
                          .uretimleriGetir(
                            aramaTerimi: textEditingValue.text,
                            sayfaBasinaKayit: 10,
                          );

                      final results = await Future.wait([
                        urunlerFuture,
                        uretimlerFuture,
                      ]);

                      final urunler = results[0] as List<UrunModel>;
                      final uretimler = results[1] as List<UretimModel>;

                      final uretimlerAsUrun = uretimler
                          .map(
                            (u) => UrunModel(
                              id: u.id,
                              kod: u.kod,
                              ad: '${u.ad} (Üretim)',
                              birim: u.birim,
                              alisFiyati: u.alisFiyati,
                              satisFiyati1: u.satisFiyati1,
                              satisFiyati2: u.satisFiyati2,
                              satisFiyati3: u.satisFiyati3,
                              kdvOrani: u.kdvOrani,
                              stok: u.stok,
                              erkenUyariMiktari: u.erkenUyariMiktari,
                              grubu: u.grubu,
                              ozellikler: u.ozellikler,
                              barkod: u.barkod,
                              kullanici: u.kullanici,
                              resimUrl: u.resimUrl,
                              resimler: u.resimler,
                              aktifMi: u.aktifMi,
                              createdBy: u.createdBy,
                              createdAt: u.createdAt,
                            ),
                          )
                          .toList();

                      final combined = [...urunler, ...uretimlerAsUrun];

                      if (mounted) {
                        _lastOptions = combined;
                      }

                      if (!completer.isCompleted) completer.complete(combined);
                    } catch (e) {
                      if (!completer.isCompleted) completer.complete([]);
                    }
                  },
                );

                return completer.future;
              },
              displayStringForOption: (UrunModel option) =>
                  isCodeField ? option.kod : option.ad,
              onSelected: (UrunModel selection) {
                _fillProductFields(selection);
              },
              optionsViewBuilder:
                  (
                    BuildContext context,
                    AutocompleteOnSelected<UrunModel> onSelected,
                    Iterable<UrunModel> options,
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
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (BuildContext context, int index) {
                              final option = options.elementAt(index);
                              final currentHighlight =
                                  AutocompleteHighlightedOption.of(context);

                              // Update tracked highlight index
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted &&
                                    _highlightedIndex != currentHighlight) {
                                  _highlightedIndex = currentHighlight;
                                }
                              });

                              final isHighlighted = currentHighlight == index;

                              final bool isProduction = option.ad.endsWith(
                                '(Üretim)',
                              );
                              final title = option.ad;
                              String subtitle = 'Kod: ${option.kod}';

                              final term = controller.text.toLowerCase();
                              if (option.barkod.isNotEmpty &&
                                  option.barkod.contains(term)) {
                                subtitle += ' • Barkod: ${option.barkod}';
                              }

                              final bool hasStock = option.stok > 0;
                              final Color stockBgColor = hasStock
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE);
                              final Color stockTextColor = hasStock
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828);

                              final Color typeBgColor = isProduction
                                  ? const Color(0xFFFFF3E0)
                                  : const Color(0xFFE3F2FD);
                              final Color typeTextColor = isProduction
                                  ? const Color(0xFFE65100)
                                  : const Color(0xFF1565C0);

                              return InkWell(
                                onTap: () => onSelected(option),
                                hoverColor: Colors.transparent,
                                child: Container(
                                  color: isHighlighted
                                      ? effectiveColor.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                color: Color(0xFF202124),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: typeBgColor,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isProduction
                                                  ? tr('common.production')
                                                  : tr('common.product'),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: typeTextColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              subtitle,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: stockBgColor,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: stockTextColor
                                                    .withValues(alpha: 0.2),
                                              ),
                                            ),
                                            child: Text(
                                              '${tr('products.table.stock')}: ${FormatYardimcisi.sayiFormatlaOndalikli(option.stok, ondalik: _genelAyarlar.ondalikAyiraci, binlik: _genelAyarlar.binlikAyiraci, decimalDigits: _genelAyarlar.miktarOndalik)}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: stockTextColor,
                                              ),
                                            ),
                                          ),
                                        ],
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
              fieldViewBuilder:
                  (
                    BuildContext context,
                    TextEditingController textEditingController,
                    FocusNode focusNode,
                    VoidCallback onFieldSubmitted,
                  ) {
                    void handleEnter() {
                      if (_highlightedIndex == -1 && _lastOptions.isNotEmpty) {
                        _fillProductFields(_lastOptions.first);
                      } else if (_highlightedIndex != -1 &&
                          _highlightedIndex < _lastOptions.length) {
                        _fillProductFields(_lastOptions[_highlightedIndex]);
                      } else {
                        onFieldSubmitted();
                      }
                    }

                    return CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.enter):
                            handleEnter,
                        const SingleActivator(LogicalKeyboardKey.numpadEnter):
                            handleEnter,
                        const SingleActivator(LogicalKeyboardKey.tab): () {
                          focusNode.requestFocus();
                        },
                      },
                      child: TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        style: const TextStyle(fontSize: 17),
                        decoration: InputDecoration(
                          hintText: isCodeField
                              ? tr('common.search_product_hint')
                              : tr('common.selected_product_name'),
                          hintStyle: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.3),
                            fontSize: 16,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_selectedUrun != null)
                                IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey.shade400,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedUrun = null;
                                      _urunKodController.clear();
                                      _urunAdiController.clear();
                                      _birimController.clear();
                                      _birimFiyatiController.clear();
                                      _kdvOrani = 0;
                                    });
                                  },
                                ),
                              suffixIcon ?? const SizedBox.shrink(),
                            ],
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
                            borderSide: BorderSide(
                              color: effectiveColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    );
                  },
            );
          },
        ),
      ],
    );
  }

  void _fillProductFields(UrunModel p) {
    setState(() {
      _selectedUrun = p;
      _urunKodController.text = p.kod;
      _urunAdiController.text = p.ad;
      _birimController.text = p.birim;
      _birimFiyatiController.text = FormatYardimcisi.sayiFormatlaOndalikli(
        p.satisFiyati1,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: _genelAyarlar.fiyatOndalik,
      );
      _kdvOrani = p.kdvOrani;
    });
    _miktarFocusNode.requestFocus();
  }

  Widget _buildProductAddSection(ThemeData theme, {bool isCompact = false}) {
    final color = Colors.deepOrange.shade700;

    final codeField = _buildProductAutocompleteField(
      controller: _urunKodController,
      focusNode: _urunKodFocusNode,
      label: tr('orders.field.find_product'),
      searchHint: tr('common.search_fields.code_name_barcode'),
      isRequired: true,
      isCodeField: true,
      suffixIcon: Tooltip(
        message: tr('common.key.f3'),
        child: IconButton(
          icon: const Icon(Icons.search, color: Colors.grey),
          onPressed: _searchUrun,
        ),
      ),
      onExternalSubmit: _searchUrun,
    );

    final nameField = _buildProductAutocompleteField(
      controller: _urunAdiController,
      focusNode: _urunAdiFocusNode,
      label: tr('products.table.name'),
      searchHint: tr('common.search_fields.name_code'),
      isRequired: true,
      isCodeField: false,
      suffixIcon: IconButton(
        icon: const Icon(Icons.search, color: Colors.grey),
        onPressed: _searchUrun,
      ),
      onExternalSubmit: _searchUrun,
    );

    final unitPriceField = _buildTextField(
      controller: _birimFiyatiController,
      label: tr('common.unit_price'),
      isNumeric: true,
      color: color,
      focusNode: _birimFiyatiFocusNode,
    );

    final currencyField = _buildDropdown<String>(
      value: _selectedParaBirimi,
      label: tr('common.currency'),
      items: _genelAyarlar.kullanilanParaBirimleri,
      itemLabel: (s) => s,
      onChanged: (v) => setState(() => _selectedParaBirimi = v ?? 'TRY'),
      color: color,
    );

    final kdvField = _buildDropdown<String>(
      value: _selectedKdvDurumu,
      label: tr('common.vat_status'),
      items: const ['excluded', 'included'],
      itemLabel: (s) => s == 'excluded'
          ? tr('common.vat_excluded')
          : tr('common.vat_included'),
      onChanged: (v) => setState(() => _selectedKdvDurumu = v ?? 'excluded'),
      color: color,
    );

    final qtyField = _buildTextField(
      controller: _miktarController,
      label: tr('common.quantity'),
      isNumeric: true,
      isRequired: true,
      color: color,
      focusNode: _miktarFocusNode,
    );

    final unitField = _buildTextField(
      controller: _birimController,
      label: tr('common.unit'),
      isRequired: true,
      color: color,
    );

    final discountField = _buildTextField(
      controller: _iskontoController,
      label: tr('sale.field.discount_rate'),
      isNumeric: true,
      color: Colors.blue.shade700,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stackMain = isCompact || constraints.maxWidth < 760;
        final bool stackMiddle = isCompact || constraints.maxWidth < 860;
        final bool stackBottom = isCompact || constraints.maxWidth < 820;

        return Column(
          children: [
            if (stackMain) ...[
              codeField,
              const SizedBox(height: 12),
              nameField,
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(flex: 2, child: codeField),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: nameField),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (stackMiddle) ...[
              unitPriceField,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: currencyField),
                  const SizedBox(width: 12),
                  Expanded(child: kdvField),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(flex: 2, child: unitPriceField),
                  const SizedBox(width: 12),
                  Expanded(child: currencyField),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: kdvField),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (stackBottom) ...[
              qtyField,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: unitField),
                  const SizedBox(width: 12),
                  Expanded(child: discountField),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(child: qtyField),
                  const SizedBox(width: 16),
                  Expanded(child: unitField),
                  const SizedBox(width: 16),
                  Expanded(child: discountField),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _addUrunToList,
                icon: const Icon(Icons.add),
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 14 : 24,
                    vertical: isCompact ? 12 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr('orders.add_item')),
                    if (!isCompact) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          tr('common.key.f1'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductListSection(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return _buildMobileProductListCards();
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              dividerTheme: const DividerThemeData(
                color: Colors.transparent,
                space: 0,
                thickness: 0,
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columnSpacing: 20,
                  horizontalMargin: 20,
                  headingRowHeight: 48,
                  dataRowMinHeight: 60,
                  dataRowMaxHeight: 60,
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFF8F9FA),
                  ),
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5F6368),
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                  dataTextStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF202124),
                    fontWeight: FontWeight.w500,
                  ),
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  columns: [
                    DataColumn(label: Text(tr('common.warehouse'))),
                    DataColumn(label: Text(tr('purchase.grid.code'))),
                    DataColumn(label: Text(tr('shipment.field.name'))),
                    DataColumn(
                      label: Text(tr('common.vat_short')),
                      numeric: true,
                    ),
                    DataColumn(label: Text(tr('common.price')), numeric: true),
                    DataColumn(
                      label: Text(tr('common.discount')),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(tr('common.quantity')),
                      numeric: true,
                    ),
                    DataColumn(label: Text(tr('common.unit'))),
                    DataColumn(label: Text(tr('common.total')), numeric: true),
                  ],
                  rows: _eklenenUrunler.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isSelected = _selectedUrunIndices.contains(index);
                    return DataRow(
                      selected: isSelected,
                      color: WidgetStateProperty.resolveWith<Color?>((
                        Set<WidgetState> states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return _primaryColor.withValues(alpha: 0.08);
                        }
                        return null;
                      }),
                      onSelectChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedUrunIndices.add(index);
                          } else {
                            _selectedUrunIndices.remove(index);
                          }
                        });
                      },
                      cells: [
                        DataCell(Text(item['depoAdi'] ?? '-')),
                        DataCell(
                          Text(
                            item['urunKodu'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(
                              item['urunAdi'] ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            tr('common.symbol.percent') +
                                _fmtRatio(
                                  (item['kdvOrani'] as num?)?.toDouble() ?? 0,
                                ),
                          ),
                        ),
                        // Fiyat - Düzenlenebilir
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildEditableCell(
                              index: index,
                              field: 'price',
                              value:
                                  (item['birimFiyati'] as num?)?.toDouble() ??
                                  0,
                              onSubmitted: (val) {
                                setState(() {
                                  _eklenenUrunler[index]['birimFiyati'] = val;
                                  _recalculateTotal(index);
                                });
                              },
                            ),
                          ),
                        ),
                        // İskonto - Düzenlenebilir
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildEditableCell(
                              index: index,
                              field: 'discount',
                              value: (item['iskonto'] as num?)?.toDouble() ?? 0,
                              prefix: '%',
                              onSubmitted: (val) {
                                setState(() {
                                  _eklenenUrunler[index]['iskonto'] = val;
                                  _recalculateTotal(index);
                                });
                              },
                            ),
                          ),
                        ),
                        // Miktar - Düzenlenebilir
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildEditableCell(
                              index: index,
                              field: 'quantity',
                              value: (item['miktar'] as num?)?.toDouble() ?? 0,
                              onSubmitted: (val) {
                                setState(() {
                                  _eklenenUrunler[index]['miktar'] = val;
                                  _recalculateTotal(index);
                                });
                              },
                            ),
                          ),
                        ),
                        DataCell(Text(item['birim'] ?? '')),
                        DataCell(
                          Text(
                            '${_fmtPrice((item['toplamFiyati'] as num?)?.toDouble() ?? 0)} ${item['paraBirimi'] ?? tr('common.currency.try')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileProductListCards() {
    if (_eklenenUrunler.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              tr('common.no_records_found'),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _eklenenUrunler.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _eklenenUrunler[index];
        final isSelected = _selectedUrunIndices.contains(index);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2C3E50)
                  : const Color(0xFFE0E0E0),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedUrunIndices.add(index);
                            } else {
                              _selectedUrunIndices.remove(index);
                            }
                          });
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: const BorderSide(
                          color: Color(0xFFD1D1D1),
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['urunAdi'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF202124),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item['urunKodu'] ?? ''} • ${item['depoAdi'] ?? '-'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _eklenenUrunler.removeAt(index);
                          _selectedUrunIndices
                            ..remove(index)
                            ..removeWhere((selected) => selected > index);
                          _hesaplaGenelToplam();
                        });
                      },
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildMobileEditableCellBlock(
                        label: tr('common.price'),
                        child: _buildEditableCell(
                          index: index,
                          field: 'price',
                          value: (item['birimFiyati'] as num?)?.toDouble() ?? 0,
                          onSubmitted: (val) {
                            setState(() {
                              _eklenenUrunler[index]['birimFiyati'] = val;
                              _recalculateTotal(index);
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMobileEditableCellBlock(
                        label: tr('common.discount'),
                        child: _buildEditableCell(
                          index: index,
                          field: 'discount',
                          value: (item['iskonto'] as num?)?.toDouble() ?? 0,
                          prefix: '%',
                          onSubmitted: (val) {
                            setState(() {
                              _eklenenUrunler[index]['iskonto'] = val;
                              _recalculateTotal(index);
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMobileEditableCellBlock(
                        label: tr('common.quantity'),
                        child: _buildEditableCell(
                          index: index,
                          field: 'quantity',
                          value: (item['miktar'] as num?)?.toDouble() ?? 0,
                          onSubmitted: (val) {
                            setState(() {
                              _eklenenUrunler[index]['miktar'] = val;
                              _recalculateTotal(index);
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${tr('common.vat_short')}: ${_fmtRatio((item['kdvOrani'] as num?)?.toDouble() ?? 0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${tr('common.unit')}: ${item['birim'] ?? ''}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${_fmtPrice((item['toplamFiyati'] as num?)?.toDouble() ?? 0)} ${item['paraBirimi'] ?? tr('common.currency.try')}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileEditableCellBlock({
    required String label,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }

  void _recalculateTotal(int index) {
    final item = _eklenenUrunler[index];
    final miktar = (item['miktar'] as num?)?.toDouble() ?? 0;
    final birimFiyati = (item['birimFiyati'] as num?)?.toDouble() ?? 0;
    final iskonto = (item['iskonto'] as num?)?.toDouble() ?? 0;
    final kdvOrani = (item['kdvOrani'] as num?)?.toDouble() ?? 0;
    final kdvDurumu = item['kdvDurumu'] as String? ?? 'Hariç';

    double araToplam = miktar * birimFiyati;
    if (iskonto > 0) {
      araToplam = araToplam * (1 - iskonto / 100);
    }

    double toplamFiyati = araToplam;
    final String kdvStatus = kdvDurumu.toLowerCase();
    if (kdvStatus == 'excluded' || kdvStatus == 'hariç') {
      toplamFiyati = araToplam * (1 + kdvOrani / 100);
    }

    _eklenenUrunler[index]['toplamFiyati'] = toplamFiyati;
    _hesaplaGenelToplam();
  }

  String _fmtPrice(double value) {
    return FormatYardimcisi.sayiFormatlaOndalikli(
      value,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.fiyatOndalik,
    );
  }

  String _fmtQty(double value) {
    return FormatYardimcisi.sayiFormatla(
      value,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.miktarOndalik,
    );
  }

  String _fmtRatio(double value) {
    return FormatYardimcisi.sayiFormatlaOran(
      value,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: 2,
    );
  }

  Widget _buildEditableCell({
    required int index,
    required String field,
    required double value,
    required void Function(double) onSubmitted,
    String prefix = '',
  }) {
    final isEditing = _editingIndex == index && _editingField == field;

    int decimals = 2;
    bool isPrice = false;
    if (field == 'price') {
      decimals = _genelAyarlar.fiyatOndalik;
      isPrice = true;
    } else if (field == 'quantity') {
      decimals = _genelAyarlar.miktarOndalik;
    }

    if (isEditing) {
      return _InlineNumberEditor(
        value: value,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: decimals,
        isPrice: isPrice,
        onSubmitted: (val) {
          onSubmitted(val);
          setState(() {
            _editingIndex = null;
            _editingField = null;
          });
        },
      );
    }

    return InkWell(
      onTap: () {
        setState(() {
          _editingIndex = index;
          _editingField = field;
        });
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit, size: 12, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text(
            '$prefix${field == "quantity" ? _fmtQty(value) : (field == "discount" ? _fmtRatio(value) : _fmtPrice(value))}',
            style: const TextStyle(
              fontSize: 14,
              color: _textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(ThemeData theme, {bool isCompact = false}) {
    return Container(
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
          constraints: BoxConstraints(maxWidth: isCompact ? 760 : 900),
          child: isCompact
              ? LayoutBuilder(
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
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
                                onPressed: _isLoading ? null : _handleSave,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 40),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
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
                                        tr('common.save'),
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
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _handleClear,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.refresh, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            tr('common.clear'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tr('common.key.f4'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
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
                              tr('common.save'),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumeric = false,
    bool isRequired = false,
    Color? color,
    String? hint,
    FocusNode? focusNode,
    bool readOnly = false,
    Widget? suffix,
  }) {
    final theme = Theme.of(context);
    final bool isCompact = MediaQuery.sizeOf(context).width < 900;
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: isCompact ? 13 : 14,
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
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: isCompact ? 15 : 17,
          ),
          inputFormatters: isNumeric
              ? [
                  CurrencyInputFormatter(
                    binlik: _genelAyarlar.binlikAyiraci,
                    ondalik: _genelAyarlar.ondalikAyiraci,
                  ),
                  LengthLimitingTextInputFormatter(20),
                ]
              : null,
          validator: (value) => isRequired && (value == null || value.isEmpty)
              ? tr('validation.required')
              : null,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.withValues(alpha: 0.3),
              fontSize: isCompact ? 14 : 16,
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
            contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 8 : 10),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    bool isRequired = false,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final bool isCompact = MediaQuery.sizeOf(context).width < 900;
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: isCompact ? 13 : 14,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          initialValue: value,
          decoration: InputDecoration(
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
            contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 8 : 10),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemLabel(item),
                    style: TextStyle(fontSize: isCompact ? 13 : 14),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down, color: effectiveColor),
          validator: isRequired
              ? (v) => v == null ? tr('validation.required') : null
              : null,
        ),
      ],
    );
  }

  Widget _buildBelgeBilgileriSectionStep2(
    ThemeData theme, {
    bool isCompact = false,
  }) {
    final optionalColor = Colors.purple.shade700;
    const requiredColor = Colors.red;

    final firstDescription = AkilliAciklamaInput(
      controller: _aciklamaController,
      label: tr('orders.complete.field.description'),
      category: 'order_description',
      defaultItems: [
        tr('orders.defaults.description.1'),
        tr('orders.defaults.description.2'),
        tr('orders.defaults.description.3'),
        tr('orders.defaults.description.4'),
        tr('orders.defaults.description.5'),
      ],
      minLines: 1,
      maxLines: 2,
    );

    final secondDescription = AkilliAciklamaInput(
      controller: _aciklama2Controller,
      label: tr('orders.complete.field.description2'),
      category: 'order_description_2',
      defaultItems: [
        tr('orders.defaults.description2.1'),
        tr('orders.defaults.description2.2'),
        tr('orders.defaults.description2.3'),
        tr('orders.defaults.description2.4'),
        tr('orders.defaults.description2.5'),
      ],
      minLines: 1,
      maxLines: 2,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stack = isCompact || constraints.maxWidth < 700;

        return Column(
          children: [
            if (stack) ...[
              _buildDateFieldStyled(
                controller: _tarihController,
                label: tr('orders.complete.field.date'),
                isRequired: true,
                color: requiredColor,
                onTap: () => _selectDateStep2(context),
                onClear: () {
                  setState(() {
                    _tarihController.clear();
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildDateFieldStyled(
                controller: _gecerlilikTarihiController,
                label: tr('orders.complete.field.validity_date'),
                color: optionalColor,
                onTap: () => _selectDateStep2(context, isGecerlilik: true),
                onClear: _clearGecerlilikTarihi,
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildDateFieldStyled(
                      controller: _tarihController,
                      label: tr('orders.complete.field.date'),
                      isRequired: true,
                      color: requiredColor,
                      onTap: () => _selectDateStep2(context),
                      onClear: () {
                        setState(() {
                          _tarihController.clear();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDateFieldStyled(
                      controller: _gecerlilikTarihiController,
                      label: tr('orders.complete.field.validity_date'),
                      color: optionalColor,
                      onTap: () =>
                          _selectDateStep2(context, isGecerlilik: true),
                      onClear: _clearGecerlilikTarihi,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (stack) ...[
              firstDescription,
              const SizedBox(height: 12),
              secondDescription,
            ] else ...[
              Row(
                children: [
                  Expanded(child: firstDescription),
                  const SizedBox(width: 16),
                  Expanded(child: secondDescription),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDateFieldStyled({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
    Color? color,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final theme = Theme.of(context);
    final bool isCompact = MediaQuery.sizeOf(context).width < 900;
    final effectiveColor = color ?? _primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: isCompact ? 13 : 14,
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
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: isCompact ? 15 : 17,
                    ),
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
                        fontSize: isCompact ? 14 : 16,
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
                      contentPadding: EdgeInsets.fromLTRB(
                        0,
                        isCompact ? 6 : 8,
                        0,
                        isCompact ? 6 : 8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                onPressed: onClear,
                tooltip: tr('common.clear'),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12.0),
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

  Widget _buildTutarBilgileriSectionStep2(ThemeData theme) {
    final color = Colors.orange.shade700;
    const requiredColor = Colors.red;

    return Column(
      children: [
        _buildTutarFieldStyled(
          controller: _genelToplamController,
          label: tr('orders.complete.field.grand_total'),
          currency: _selectedParaBirimi,
          color: requiredColor,
          readOnly: true,
          isRequired: true,
        ),
        const SizedBox(height: 16),
        _buildTutarFieldStyled(
          controller: _yuvarlamaController,
          label: tr('orders.complete.field.rounding'),
          currency: _selectedParaBirimi,
          color: color,
          focusNode: _yuvarlamaFocusNode,
          onChanged: (_) => _calculateSonGenelToplam(),
        ),
        const SizedBox(height: 16),
        _buildTutarFieldStyled(
          controller: _sonGenelToplamController,
          label: tr('orders.complete.field.final_total'),
          currency: _selectedParaBirimi,
          color: requiredColor,
          readOnly: true,
          isHighlighted: true,
          isRequired: true,
          focusNode: _sonGenelToplamFocusNode,
        ),
      ],
    );
  }

  Widget _buildTutarFieldStyled({
    required TextEditingController controller,
    required String label,
    required String currency,
    Color? color,
    bool readOnly = false,
    bool isHighlighted = false,
    bool isRequired = false,
    FocusNode? focusNode,
    void Function(String)? onChanged,
  }) {
    final theme = Theme.of(context);
    final bool isCompact = MediaQuery.sizeOf(context).width < 900;
    final effectiveColor = color ?? _primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: isCompact ? 13 : 14,
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
                  CurrencyInputFormatter(
                    binlik: _genelAyarlar.binlikAyiraci,
                    ondalik: _genelAyarlar.ondalikAyiraci,
                  ),
                  LengthLimitingTextInputFormatter(20),
                ],
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: isHighlighted
                      ? (isCompact ? 16 : 18)
                      : (isCompact ? 15 : 17),
                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                  color: isHighlighted ? effectiveColor : _textColor,
                ),
                onChanged: onChanged,
                validator: isRequired
                    ? (value) {
                        if (value == null || value.isEmpty) {
                          return tr('validation.required');
                        }
                        return null;
                      }
                    : null,
                decoration: InputDecoration(
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.withValues(alpha: 0.3),
                    fontSize: isCompact ? 14 : 16,
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
                  contentPadding: EdgeInsets.fromLTRB(
                    0,
                    isCompact ? 6 : 8,
                    8,
                    isCompact ? 6 : 8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              currency,
              style: TextStyle(
                fontSize: isCompact ? 13 : 14,
                fontWeight: FontWeight.bold,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ],
    );
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
  }

  void _hesaplaGenelToplam() {
    double toplam = 0;
    for (final item in _eklenenUrunler) {
      toplam += (item['toplamFiyati'] as num?)?.toDouble() ?? 0;
    }

    _genelToplamController.text = FormatYardimcisi.sayiFormatlaOndalikli(
      toplam,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.fiyatOndalik,
    );

    _calculateSonGenelToplam();
  }

  void _clearGecerlilikTarihi() {
    setState(() {
      _selectedGecerlilikTarihi = null;
      _gecerlilikTarihiController.clear();
    });
  }

  Future<void> _selectDateStep2(
    BuildContext context, {
    bool isGecerlilik = false,
  }) async {
    final initialDate = isGecerlilik
        ? (_selectedGecerlilikTarihi ?? DateTime.now())
        : _selectedTarih;

    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(
        initialDate: initialDate,
        title: isGecerlilik
            ? tr('common.validity_date')
            : tr('orders.transaction.date'),
      ),
    );

    if (picked != null) {
      setState(() {
        if (isGecerlilik) {
          _selectedGecerlilikTarihi = picked;
          _gecerlilikTarihiController.text = DateFormat(
            'dd.MM.yyyy',
          ).format(picked);
        } else {
          _selectedTarih = picked;
          _tarihController.text = DateFormat('dd.MM.yyyy').format(picked);
        }
      });
    }
  }
}

/// Ürün Seçim Dialog'u - uretim_ekle_sayfasi.dart ile birebir aynı tasarım
class _ProductSelectionDialog extends StatefulWidget {
  const _ProductSelectionDialog();
  @override
  State<_ProductSelectionDialog> createState() =>
      _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<_ProductSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<UrunModel> _products = [];
  bool _isLoading = false;
  Timer? _debounce;
  static const Color _primaryColor = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    _searchProducts('');
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
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchProducts(query),
    );
  }

  Future<void> _searchProducts(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final urunlerFuture = UrunlerVeritabaniServisi().urunleriGetir(
        aramaTerimi: query,
        sayfaBasinaKayit: 50,
        sortAscending: true,
        sortBy: 'ad',
        aktifMi: true,
      );
      final uretimlerFuture = UretimlerVeritabaniServisi().uretimleriGetir(
        aramaTerimi: query,
        sayfaBasinaKayit: 50,
        aktifMi: true,
      );

      final resultsList = await Future.wait([urunlerFuture, uretimlerFuture]);
      final urunler = resultsList[0] as List<UrunModel>;
      final uretimler = resultsList[1] as List<UretimModel>;

      final uretimlerAsUrun = uretimler
          .map(
            (u) => UrunModel(
              id: u.id,
              kod: u.kod,
              ad: '${u.ad} (Üretim)',
              birim: u.birim,
              alisFiyati: u.alisFiyati,
              satisFiyati1: u.satisFiyati1,
              satisFiyati2: u.satisFiyati2,
              satisFiyati3: u.satisFiyati3,
              kdvOrani: u.kdvOrani,
              stok: u.stok,
              erkenUyariMiktari: u.erkenUyariMiktari,
              grubu: u.grubu,
              ozellikler: u.ozellikler,
              barkod: u.barkod,
              kullanici: u.kullanici,
              resimUrl: u.resimUrl,
              resimler: u.resimler,
              aktifMi: u.aktifMi,
              createdBy: u.createdBy,
              createdAt: u.createdAt,
            ),
          )
          .toList();

      final combined = [...urunler, ...uretimlerAsUrun];
      // Sort combined list by name
      combined.sort((a, b) => a.ad.compareTo(b.ad));

      if (mounted) {
        setState(() {
          _products = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.sizeOf(context).width < 900;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: isMobile
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 0 : 14),
      ),
      child: SafeArea(
        child: Container(
          width: isMobile ? double.infinity : 720,
          height: isMobile ? MediaQuery.sizeOf(context).height : null,
          constraints: BoxConstraints(
            maxHeight: isMobile ? double.infinity : 680,
          ),
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 28,
            isMobile ? 16 : 24,
            isMobile ? 16 : 28,
            isMobile ? 16 : 22,
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('productions.recipe.select_product'),
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF202124),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr('productions.recipe.search_subtitle'),
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
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
                      IconButton(
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
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Column(
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
                      hintText: tr('products.search_placeholder'),
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
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: Color(0xFFE0E0E0),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              tr('products.no_products_found'),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF606368),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _products.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        itemBuilder: (ctx, i) {
                          final p = _products[i];
                          return InkWell(
                            onTap: () => Navigator.pop(context, p),
                            hoverColor: const Color(0xFFF5F7FA),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
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
                                      Icons.inventory_2,
                                      color: _primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.ad,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF202124),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          p.kod,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF606368),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: p.stok > 0
                                          ? const Color(0xFFE6F4EA)
                                          : const Color(0xFFFCE8E6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${p.stok.toStringAsFixed(0)} ${p.birim}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: p.stok > 0
                                            ? const Color(0xFF1E7E34)
                                            : const Color(0xFFC5221F),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F3F4),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      p.birim,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF4A4A4A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cari Hesap Seçim Dialog'u
class _CariSelectionDialog extends StatefulWidget {
  const _CariSelectionDialog();
  @override
  State<_CariSelectionDialog> createState() => _CariSelectionDialogState();
}

class _CariSelectionDialogState extends State<_CariSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<CariHesapModel> _cariler = [];
  bool _isLoading = false;
  Timer? _debounce;
  static const Color _primaryColor = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    _searchCariler('');
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
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchCariler(query),
    );
  }

  Future<void> _searchCariler(String query) async {
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
          _cariler = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.sizeOf(context).width < 900;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: isMobile
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 0 : 14),
      ),
      child: SafeArea(
        child: Container(
          width: isMobile ? double.infinity : 720,
          height: isMobile ? MediaQuery.sizeOf(context).height : null,
          constraints: BoxConstraints(
            maxHeight: isMobile ? double.infinity : 680,
          ),
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 28,
            isMobile ? 16 : 24,
            isMobile ? 16 : 28,
            isMobile ? 16 : 22,
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('accounts.select_account'),
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF202124),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr('orders.form.select_account_optional'),
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
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
                      IconButton(
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
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Column(
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
                      hintText: tr('common.search_fields.code_name_phone'),
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
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _cariler.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.person_search_outlined,
                              size: 48,
                              color: Color(0xFFE0E0E0),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              tr('accounts.no_accounts_found'),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF606368),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _cariler.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        itemBuilder: (ctx, i) {
                          final c = _cariler[i];
                          return InkWell(
                            onTap: () => Navigator.pop(context, c),
                            hoverColor: const Color(0xFFF5F7FA),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
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
                                      Icons.person,
                                      color: _primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.adi,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF202124),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${c.kodNo} • ${c.hesapTuru}',
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
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineNumberEditor extends StatefulWidget {
  final double value;
  final void Function(double) onSubmitted;
  final String binlik;
  final String ondalik;
  final int decimalDigits;

  const _InlineNumberEditor({
    required this.value,
    required this.onSubmitted,
    required this.binlik,
    required this.ondalik,
    required this.decimalDigits,
    this.isPrice = false,
  });

  final bool isPrice;

  @override
  State<_InlineNumberEditor> createState() => _InlineNumberEditorState();
}

class _InlineNumberEditorState extends State<_InlineNumberEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    String initialText;
    if (widget.isPrice) {
      initialText = FormatYardimcisi.sayiFormatlaOndalikli(
        widget.value,
        binlik: widget.binlik,
        ondalik: widget.ondalik,
        decimalDigits: widget.decimalDigits,
      );
    } else {
      initialText = FormatYardimcisi.sayiFormatla(
        widget.value,
        binlik: widget.binlik,
        ondalik: widget.ondalik,
        decimalDigits: widget.decimalDigits,
      );
    }
    _controller = TextEditingController(text: initialText);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    _focusNode.requestFocus();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _save();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    final newValue = FormatYardimcisi.parseDouble(
      _controller.text,
      binlik: widget.binlik,
      ondalik: widget.ondalik,
    );
    widget.onSubmitted(newValue);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2C3E50);
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          _save();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        width: 80,
        height: 40,
        child: TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.none,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: primaryColor),
            ),
          ),
          inputFormatters: [
            CurrencyInputFormatter(
              binlik: widget.binlik,
              ondalik: widget.ondalik,
              maxDecimalDigits: widget.decimalDigits,
            ),
            LengthLimitingTextInputFormatter(20),
          ],
          onTapOutside: (_) => _save(),
          onFieldSubmitted: (_) => _save(),
        ),
      ),
    );
  }
}
