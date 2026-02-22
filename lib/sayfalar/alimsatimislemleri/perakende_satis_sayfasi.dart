import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../yardimcilar/app_route_observer.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../yardimcilar/responsive_yardimcisi.dart';
import '../../bilesenler/onay_dialog.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../../servisler/depolar_veritabani_servisi.dart';
import '../../servisler/kasalar_veritabani_servisi.dart';
import '../../servisler/kredi_kartlari_veritabani_servisi.dart';
import '../../servisler/perakende_satis_veritabani_servisleri.dart';
import '../../servisler/urunler_veritabani_servisi.dart';
import '../../servisler/uretimler_veritabani_servisi.dart';
import '../kasalar/kasalar_sayfasi.dart';
import '../kasalar/modeller/kasa_model.dart';
import '../kredikartlari/modeller/kredi_karti_model.dart';
import '../ortak/print_preview_screen.dart';
import '../urunler_ve_depolar/depolar/modeller/depo_model.dart';
import '../../bilesenler/tek_tarih_secici_dialog.dart';
import '../../servisler/sayfa_senkronizasyon_servisi.dart';
import '../urunler_ve_depolar/urunler/modeller/urun_model.dart';

class _PerakendeSepetItem {
  final String kodNo;
  final String barkodNo;
  final String adi;
  final double birimFiyati;
  final double iskontoOrani;
  final double miktar;
  final String olcu;
  final double toplamFiyat;
  final String paraBirimi;
  final int? depoId;
  final String? depoAdi;

  const _PerakendeSepetItem({
    required this.kodNo,
    required this.barkodNo,
    required this.adi,
    required this.birimFiyati,
    required this.iskontoOrani,
    required this.miktar,
    required this.olcu,
    required this.toplamFiyat,
    required this.paraBirimi,
    required this.depoId,
    required this.depoAdi,
  });

  _PerakendeSepetItem copyWith({
    double? miktar,
    double? iskontoOrani,
    double? birimFiyati,
    double? toplamFiyat,
    int? depoId,
    String? depoAdi,
  }) {
    return _PerakendeSepetItem(
      kodNo: kodNo,
      barkodNo: barkodNo,
      adi: adi,
      birimFiyati: birimFiyati ?? this.birimFiyati,
      iskontoOrani: iskontoOrani ?? this.iskontoOrani,
      miktar: miktar ?? this.miktar,
      olcu: olcu,
      toplamFiyat: toplamFiyat ?? this.toplamFiyat,
      paraBirimi: paraBirimi,
      depoId: depoId ?? this.depoId,
      depoAdi: depoAdi ?? this.depoAdi,
    );
  }
}

class _PerakendeUrunSearchDialog extends StatefulWidget {
  final String initialQuery;
  final ValueChanged<dynamic> onSelect;

  const _PerakendeUrunSearchDialog({
    required this.onSelect,
    this.initialQuery = '',
  });

  @override
  State<_PerakendeUrunSearchDialog> createState() =>
      _PerakendeUrunSearchDialogState();
}

class _PerakendeUrunSearchDialogState
    extends State<_PerakendeUrunSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<dynamic> _items = [];
  bool _isLoading = false;
  Timer? _debounce;

  static const Color _primaryColor = Color(0xFF1E88E5);

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _searchProducts(widget.initialQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _searchProducts(query);
    });
  }

  Future<void> _searchProducts(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        UrunlerVeritabaniServisi().urunleriGetir(
          aramaTerimi: query,
          sayfaBasinaKayit: 50,
          sortAscending: true,
          sortBy: 'ad',
          aktifMi: true,
        ),
        UretimlerVeritabaniServisi().uretimleriGetir(
          aramaTerimi: query,
          sayfaBasinaKayit: 50,
          sortAscending: true,
          sortBy: 'ad',
          aktifMi: true,
        ),
      ]);

      if (!mounted) return;

      final combined = [...results[0], ...results[1]];
      // Sort combined by name
      combined.sort(
        (a, b) => ((a as dynamic).ad as String).compareTo(
          (b as dynamic).ad as String,
        ),
      );

      setState(() {
        _items = combined;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('shipment.form.product.search_title'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('shipment.form.product.search_subtitle'),
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
                  crossAxisAlignment: CrossAxisAlignment.end,
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
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: tr('common.close'),
                      ),
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
                  : _items.isEmpty
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
                      itemCount: _items.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFEFEFEF),
                      ),
                      itemBuilder: (context, index) {
                        final p = _items[index];
                        return InkWell(
                          mouseCursor: WidgetStateMouseCursor.clickable,
                          onTap: () {
                            widget.onSelect(p);
                            Navigator.of(context).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 6,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    (p as dynamic).kod,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF202124),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    (p as dynamic).ad,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF202124),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    (p as dynamic).barkod,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF606368),
                                    ),
                                  ),
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

class PerakendeSatisSayfasi extends StatefulWidget {
  const PerakendeSatisSayfasi({super.key});

  @override
  State<PerakendeSatisSayfasi> createState() => _PerakendeSatisSayfasiState();
}

class _PerakendeSatisSayfasiState extends State<PerakendeSatisSayfasi>
    with RouteAware {
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();
  bool _routeSubscribed = false;

  // Controllers
  final _barkodController = TextEditingController();
  final _miktarController = TextEditingController(text: '1');
  final _aciklamaController = TextEditingController();
  final _odenenTutarController = TextEditingController();

  final _barkodFocusNode = FocusNode();
  final _miktarFocusNode = FocusNode();
  final _aciklamaFocusNode = FocusNode();
  final _odenenTutarFocusNode = FocusNode();
  // State
  DateTime _selectedDate = DateTime.now();
  int _selectedFiyatGrubu = 1;
  String? _selectedDepo;
  int? _selectedDepoId;
  List<int> _selectedDepoIds = [];
  bool _fisYazdir = true;
  String _selectedParaBirimi = 'TRY';
  double _odenenTutar = 0.0;
  int? _selectedRowIndex;
  bool _isProcessing = false;
  double _faturaIskontoOrani = 0.0;
  bool _showHizliUrunler = false; // Closed by default as per user request

  final List<_PerakendeSepetItem> _sepetItems = [];
  final List<DepoModel> _depolar = [];
  final List<String> _depoList = [];
  List<UrunModel> _hizliUrunler = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadHizliUrunler();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barkodFocusNode.requestFocus();
    });
  }

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _lockPortraitOnly() {
    if (!_isMobilePlatform) return;
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  }

  void _enableRetailOrientationsIfTablet() {
    if (!_isMobilePlatform) return;
    if (!ResponsiveYardimcisi.tabletMi(context)) {
      _lockPortraitOnly();
      return;
    }

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_routeSubscribed) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
      _routeSubscribed = true;
      _enableRetailOrientationsIfTablet();
    }
  }

  @override
  void didPush() => _enableRetailOrientationsIfTablet();

  @override
  void didPopNext() => _enableRetailOrientationsIfTablet();

  @override
  void didPushNext() => _lockPortraitOnly();

  Future<void> _loadInitialData() async {
    await Future.wait([_loadSettings(), _loadDepolar()]);
  }

  Future<void> _loadHizliUrunler() async {
    try {
      final list = await UrunlerVeritabaniServisi().hizliUrunleriGetir();
      if (mounted) {
        setState(() {
          _hizliUrunler = list;
        });
      }
    } catch (e) {
      debugPrint('Hızlı ürünler yüklenirken hata: $e');
    }
  }

  Future<void> _selectDate() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(initialDate: _selectedDate),
    );
    if (result != null) {
      setState(() {
        _selectedDate = result;
      });
    }
  }

  Future<void> _selectWarehouses() async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) {
        List<int> tempSelected = List.from(_selectedDepoIds);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(tr('retail.warehouse')),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _depolar.map((depo) {
                      return CheckboxListTile(
                        title: Text(depo.ad),
                        value: tempSelected.contains(depo.id),
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              tempSelected.add(depo.id);
                            } else {
                              tempSelected.remove(depo.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('common.cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, tempSelected),
                  child: Text(tr('common.apply')),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null) {
      setState(() {
        _selectedDepoIds = result;
        if (_selectedDepoIds.isNotEmpty) {
          final firstDepo = _depolar.firstWhere(
            (d) => d.id == _selectedDepoIds.first,
            orElse: () => _depolar.first,
          );
          _selectedDepo = firstDepo.ad;
          _selectedDepoId = firstDepo.id;
        } else {
          _selectedDepo = null;
          _selectedDepoId = null;
        }
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'retail_selected_warehouse_ids',
        _selectedDepoIds.map((e) => e.toString()).toList(),
      );
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      if (mounted) {
        setState(() {
          _genelAyarlar = settings;
          _selectedParaBirimi = settings.varsayilanParaBirimi;
          _fisYazdir = settings.otomatikYazdir;
        });
      }
    } catch (e) {
      debugPrint('Ayarlar yüklenirken hata: $e');
    }
  }

  Future<void> _loadDepolar() async {
    try {
      final depolar = await DepolarVeritabaniServisi().tumDepolariGetir();
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final savedIdsStr = prefs.getStringList('retail_selected_warehouse_ids');

      setState(() {
        _depolar
          ..clear()
          ..addAll(depolar);
        _depoList
          ..clear()
          ..addAll(depolar.map((e) => e.ad));

        if (savedIdsStr != null) {
          final savedIds = savedIdsStr
              .map((e) => int.tryParse(e))
              .whereType<int>()
              .toList();
          _selectedDepoIds = _depolar
              .where((d) => savedIds.contains(d.id))
              .map((d) => d.id)
              .toList();
        }

        if (_selectedDepoIds.isEmpty && _depolar.isNotEmpty) {
          _selectedDepoIds = _depolar.map((e) => e.id).toList();
        }

        if (_selectedDepoIds.isNotEmpty) {
          final firstDepo = _depolar.firstWhere(
            (d) => d.id == _selectedDepoIds.first,
            orElse: () => _depolar.first,
          );
          _selectedDepo = firstDepo.ad;
          _selectedDepoId = firstDepo.id;
        } else {
          _selectedDepo = null;
          _selectedDepoId = null;
        }
      });
    } catch (e) {
      debugPrint('Depolar yüklenirken hata: $e');
    }
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    _lockPortraitOnly();
    _barkodController.dispose();
    _miktarController.dispose();
    _aciklamaController.dispose();
    _odenenTutarController.dispose();
    _barkodFocusNode.dispose();
    _miktarFocusNode.dispose();
    _aciklamaFocusNode.dispose();
    _odenenTutarFocusNode.dispose();
    super.dispose();
  }

  double get _genelToplam {
    return _sepetItems.fold(0.0, (sum, item) => sum + item.toplamFiyat);
  }

  int get _satirSayisi => _sepetItems.length;

  double get _paraUstu {
    final diff = _odenenTutar - _genelToplam;
    return diff > 0 ? diff : 0;
  }

  String _formatTutar(double tutar, {int? decimalDigits}) {
    return FormatYardimcisi.sayiFormatlaOndalikli(
      tutar,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: decimalDigits ?? _genelAyarlar.fiyatOndalik,
    );
  }

  String _formatParaBirimiGosterimi(double tutar) {
    final formatted = _formatTutar(tutar);
    if (!_genelAyarlar.sembolGoster) {
      return '$formatted $_selectedParaBirimi';
    }

    switch (_selectedParaBirimi) {
      case 'TRY':
        return '$formatted ₺';
      case 'USD':
        return '$formatted \$';
      case 'EUR':
        return '$formatted €';
      case 'GBP':
        return '$formatted £';
      default:
        return '$formatted $_selectedParaBirimi';
    }
  }

  double _parseMiktar() {
    return FormatYardimcisi.parseDouble(
      _miktarController.text,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
    );
  }

  double _secilenFiyat(dynamic item) {
    switch (_selectedFiyatGrubu) {
      case 2:
        return item.satisFiyati2;
      case 3:
        return item.satisFiyati3;
      case 1:
      default:
        return item.satisFiyati1;
    }
  }

  Future<void> _barkodAraVeEkle({bool dialogAc = true}) async {
    if (_isProcessing) return;

    final query = _barkodController.text.trim();
    if (query.isEmpty) {
      if (dialogAc) _openProductSearchDialog();
      return;
    }

    final qty = _parseMiktar();
    if (qty <= 0) {
      MesajYardimcisi.hataGoster(context, tr('retail.error.invalid_quantity'));
      return;
    }

    try {
      // 1. Ürünlerde ara
      final urun = await UrunlerVeritabaniServisi().urunGetirKodVeyaBarkod(
        query,
      );

      if (urun != null) {
        if (!mounted) return;
        _sepeteEkle(item: urun, miktar: qty);
        _finishItemAddition();
        return;
      }

      // 2. Üretimlerde ara
      final uretim = await UretimlerVeritabaniServisi()
          .uretimGetirKodVeyaBarkod(query);

      if (uretim != null) {
        if (!mounted) return;
        _sepeteEkle(item: uretim, miktar: qty);
        _finishItemAddition();
        return;
      }

      // 3. Bulunamadı
      if (!mounted) return;
      MesajYardimcisi.bilgiGoster(context, tr('products.no_products_found'));
      if (dialogAc) _openProductSearchDialog(initialQuery: query);
    } catch (e) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  void _finishItemAddition() {
    _barkodController.clear();
    _miktarController.text = '1';
    _barkodFocusNode.requestFocus();
    final isTablet = ResponsiveYardimcisi.tabletMi(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (isTablet && isLandscape) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    }
    setState(() {});
  }

  void _sepeteEkle({required dynamic item, required double miktar}) {
    final depoAdi = _selectedDepo;
    final depoId = _selectedDepoId;
    final birimFiyat = _secilenFiyat(item);
    final iskonto = _faturaIskontoOrani;
    final toplam = (birimFiyat * miktar) * (1 - (iskonto / 100));

    final existingIndex = _sepetItems.indexWhere(
      (x) =>
          x.kodNo == item.kod &&
          x.birimFiyati == birimFiyat &&
          x.iskontoOrani == iskonto &&
          x.depoId == depoId,
    );

    if (existingIndex >= 0) {
      final existing = _sepetItems[existingIndex];
      final yeniMiktar = existing.miktar + miktar;
      final yeniToplam = (birimFiyat * yeniMiktar) * (1 - (iskonto / 100));
      _sepetItems[existingIndex] = existing.copyWith(
        miktar: yeniMiktar,
        toplamFiyat: yeniToplam,
      );
      return;
    }

    _sepetItems.add(
      _PerakendeSepetItem(
        kodNo: item.kod,
        barkodNo: item.barkod,
        adi: item.ad,
        birimFiyati: birimFiyat,
        iskontoOrani: iskonto,
        miktar: miktar,
        olcu: item.birim,
        toplamFiyat: toplam,
        paraBirimi: _selectedParaBirimi,
        depoId: depoId,
        depoAdi: depoAdi,
      ),
    );
  }

  List<int> _nakitButonDegerleri() {
    final raw = [
      _genelAyarlar.nakit1,
      _genelAyarlar.nakit2,
      _genelAyarlar.nakit3,
      _genelAyarlar.nakit4,
      _genelAyarlar.nakit5,
      _genelAyarlar.nakit6,
    ];

    final parsed = raw
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList(growable: false);

    if (parsed.length == 6) return parsed;
    return const [5, 10, 20, 50, 100, 200];
  }

  Future<void> _tamamlaSatisTekOdeme({
    required String odemeYeri,
    double? alinanTutar,
  }) async {
    if (_isProcessing) return;

    if (_sepetItems.isEmpty) {
      MesajYardimcisi.hataGoster(context, tr('sale.error.no_items'));
      return;
    }

    if (_selectedDepoId == null) {
      MesajYardimcisi.hataGoster(context, tr('sale.msg.select_warehouse'));
      return;
    }

    final genelToplam = _genelToplam;
    if (genelToplam <= 0) return;

    final tahsilatTutar = alinanTutar ?? genelToplam;

    final tendered = _odenenTutar;
    if (odemeYeri == 'Kasa' &&
        tahsilatTutar > 0 &&
        tendered > 0 &&
        tendered < genelToplam) {
      MesajYardimcisi.hataGoster(
        context,
        tr('retail.error.insufficient_payment'),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = prefs.getString('current_username') ?? 'Sistem';

      final faturaNo = 'PRK-${DateTime.now().millisecondsSinceEpoch}';
      final entegrasyonRef = 'RETAIL-$faturaNo';

      final List<Map<String, dynamic>> payments = [];
      if (odemeYeri == 'Kasa' && tahsilatTutar > 0) {
        final kasa = await _varsayilanKasaGetir();
        if (kasa == null) {
          throw Exception(tr('retail.error.no_cash_register'));
        }
        payments.add({
          'type': 'Kasa',
          'amount': tahsilatTutar,
          'accountCode': kasa.kod,
        });
      } else if (odemeYeri == 'Kredi Kartı' && tahsilatTutar > 0) {
        final kart = await _varsayilanKrediKartiGetir();
        if (kart == null) {
          throw Exception(tr('retail.error.no_credit_card_account'));
        }
        payments.add({
          'type': 'Kredi Kartı',
          'amount': tahsilatTutar,
          'accountCode': kart.kod,
        });
      }

      final satisBilgileri = {
        'kullanici': currentUser,
        'tarih': _selectedDate,
        'belgeTuru': 'Perakende',
        'faturaNo': faturaNo,
        'aciklama': _aciklamaController.text,
        'genelToplam': genelToplam,
        'odemeYeri': odemeYeri,
        'odemeHesapKodu': '',
        'odemeAciklama': '',
        'alinanTutar': tahsilatTutar,
        'integrationRef': entegrasyonRef,
        'paraBirimi': _selectedParaBirimi,
        'payments': payments,
        'items': _sepetItems
            .map(
              (e) => {
                'code': e.kodNo,
                'name': e.adi,
                'unit': e.olcu,
                'quantity': e.miktar,
                'price': e.birimFiyati,
                'total': e.toplamFiyat,
                'warehouseId': _selectedDepoId,
              },
            )
            .toList(growable: false),
      };

      await PerakendeSatisVeritabaniServisi().satisIsleminiKaydet(
        satisBilgileri: satisBilgileri,
      );

      if (!mounted) return;

      if (_fisYazdir) {
        await _fisYazdirOnizleme(faturaNo: faturaNo);
        if (!mounted) return;
      }

      setState(() {
        _sepetItems.clear();
        _odenenTutar = 0;
        _odenenTutarController.clear();
        _selectedRowIndex = null;
      });

      MesajYardimcisi.basariGoster(context, tr('common.saved_successfully'));
      SayfaSenkronizasyonServisi().veriDegisti('cari');
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _fisYazdirOnizleme({required String faturaNo}) async {
    final headers = [
      tr('retail.table.code'),
      tr('retail.table.barcode'),
      tr('retail.table.name'),
      tr('retail.table.unit_price'),
      tr('retail.table.discount'),
      tr('retail.table.quantity'),
      tr('retail.table.unit'),
      tr('retail.table.total_price'),
      tr('retail.table.currency'),
    ];

    final data = _sepetItems
        .map(
          (e) => [
            e.kodNo,
            e.barkodNo,
            e.adi,
            _formatTutar(e.birimFiyati),
            _formatTutar(e.iskontoOrani, decimalDigits: 2),
            _formatTutar(e.miktar, decimalDigits: _genelAyarlar.miktarOndalik),
            e.olcu,
            _formatTutar(e.toplamFiyat),
            e.paraBirimi,
          ],
        )
        .toList(growable: false);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PrintPreviewScreen(
          title: '${tr('nav.trading_operations.retail_sale')} - $faturaNo',
          headers: headers,
          data: data,
        ),
      ),
    );
  }

  Future<void> _openProductSearchDialog({String initialQuery = ''}) async {
    showDialog(
      context: context,
      builder: (context) => _PerakendeUrunSearchDialog(
        initialQuery: initialQuery,
        onSelect: (urun) {
          final qty = _parseMiktar();
          if (qty <= 0) {
            MesajYardimcisi.hataGoster(
              context,
              tr('retail.error.invalid_quantity'),
            );
            return;
          }
          setState(() {
            _sepeteEkle(item: urun, miktar: qty);
            _barkodController.clear();
            _miktarController.text = '1';
            _barkodFocusNode.requestFocus();
          });
        },
      ),
    );
  }

  Future<void> _tumunuSil() async {
    if (_sepetItems.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr('common.confirm_delete_all'),
        onayButonMetni: tr('common.delete'),
        isDestructive: true,
        onOnay: () {
          setState(() {
            _sepetItems.clear();
            _selectedRowIndex = null;
            _odenenTutar = 0;
            _odenenTutarController.clear();
          });
        },
      ),
    );
  }

  void _seciliyiSil() {
    if (_sepetItems.isEmpty) return;
    setState(() {
      final index = _selectedRowIndex ?? (_sepetItems.length - 1);
      if (index >= 0 && index < _sepetItems.length) {
        _sepetItems.removeAt(index);
      }
      _selectedRowIndex = null;
    });
  }

  void _showInvoiceDiscountDialog() {
    if (_sepetItems.isEmpty) {
      MesajYardimcisi.bilgiGoster(context, tr('sale.error.no_items'));
      return;
    }

    final controller = TextEditingController(
      text: _faturaIskontoOrani == 0 ? '' : _faturaIskontoOrani.toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('sale.dialog.invoice_discount_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('sale.dialog.invoice_discount_message')),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                suffixText: '%',
                hintText: tr('common.placeholder.zero'),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final val =
                  double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
              setState(() {
                _faturaIskontoOrani = val;
                for (var i = 0; i < _sepetItems.length; i++) {
                  final item = _sepetItems[i];
                  final yeniToplam =
                      (item.birimFiyati * item.miktar) * (1 - (val / 100));
                  _sepetItems[i] = item.copyWith(
                    iskontoOrani: val,
                    toplamFiyat: yeniToplam,
                  );
                }
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: Text(tr('common.apply')),
          ),
        ],
      ),
    );
  }

  Future<void> _openNakitTutarDialog() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('common.amount')),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: _formatTutar(0),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final val = FormatYardimcisi.parseDouble(
                controller.text,
                binlik: _genelAyarlar.binlikAyiraci,
                ondalik: _genelAyarlar.ondalikAyiraci,
              );
              setState(() => _odenenTutar = val);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: Text(tr('common.apply')),
          ),
        ],
      ),
    );
  }

  Future<KasaModel?> _varsayilanKasaGetir() async {
    final kasalar = await KasalarVeritabaniServisi().tumKasalariGetir();
    if (kasalar.isEmpty) return null;
    final varsayilan = kasalar.where((e) => e.varsayilan).toList();
    return varsayilan.isNotEmpty ? varsayilan.first : kasalar.first;
  }

  Future<KrediKartiModel?> _varsayilanKrediKartiGetir() async {
    final kartlar = await KrediKartlariVeritabaniServisi()
        .tumKrediKartlariniGetir();
    if (kartlar.isEmpty) return null;
    final varsayilan = kartlar.where((e) => e.varsayilan).toList();
    return varsayilan.isNotEmpty ? varsayilan.first : kartlar.first;
  }

  Future<void> _tamamlaCariSatis() async {
    await _tamamlaSatisTekOdeme(odemeYeri: 'Cari', alinanTutar: 0);
  }

  void _showPartialPaymentDialog() {
    if (_sepetItems.isEmpty) {
      MesajYardimcisi.hataGoster(context, tr('sale.error.no_items'));
      return;
    }

    final total = _genelToplam;
    final nakitController = TextEditingController(text: _formatTutar(total));
    final kartController = TextEditingController(text: _formatTutar(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('retail.partial_payment')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tr('retail.grand_total')} ${_formatParaBirimiGosterimi(total)}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nakitController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: tr('settings.users.payment.source.cash'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kartController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: tr('settings.users.payment.source.credit_card'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final nakit = FormatYardimcisi.parseDouble(
                nakitController.text,
                binlik: _genelAyarlar.binlikAyiraci,
                ondalik: _genelAyarlar.ondalikAyiraci,
              );
              final kart = FormatYardimcisi.parseDouble(
                kartController.text,
                binlik: _genelAyarlar.binlikAyiraci,
                ondalik: _genelAyarlar.ondalikAyiraci,
              );

              if (nakit < 0 || kart < 0 || (nakit + kart) <= 0) {
                MesajYardimcisi.hataGoster(
                  context,
                  tr('retail.error.invalid_payment'),
                );
                return;
              }
              if ((nakit + kart) > total) {
                MesajYardimcisi.hataGoster(
                  context,
                  tr('retail.error.payment_exceeds_total'),
                );
                return;
              }

              Navigator.pop(context);
              await _tamamlaParcaliOdeme(
                nakitTutar: nakit,
                krediKartiTutar: kart,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.white,
            ),
            child: Text(tr('common.apply')),
          ),
        ],
      ),
    );
  }

  Future<void> _tamamlaParcaliOdeme({
    required double nakitTutar,
    required double krediKartiTutar,
  }) async {
    if (_isProcessing) return;

    if (_sepetItems.isEmpty) {
      MesajYardimcisi.hataGoster(context, tr('sale.error.no_items'));
      return;
    }

    if (_selectedDepoId == null) {
      MesajYardimcisi.hataGoster(context, tr('sale.msg.select_warehouse'));
      return;
    }

    final genelToplam = _genelToplam;
    if ((nakitTutar + krediKartiTutar) > genelToplam) {
      MesajYardimcisi.hataGoster(
        context,
        tr('retail.error.payment_exceeds_total'),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = prefs.getString('current_username') ?? 'Sistem';

      final faturaNo = 'PRK-${DateTime.now().millisecondsSinceEpoch}';
      final entegrasyonRef = 'RETAIL-$faturaNo';

      final List<Map<String, dynamic>> payments = [];
      if (nakitTutar > 0) {
        final kasa = await _varsayilanKasaGetir();
        if (kasa == null) {
          throw Exception(tr('retail.error.no_cash_register'));
        }
        payments.add({
          'type': 'Kasa',
          'amount': nakitTutar,
          'accountCode': kasa.kod,
        });
      }

      if (krediKartiTutar > 0) {
        final kart = await _varsayilanKrediKartiGetir();
        if (kart == null) {
          throw Exception(tr('retail.error.no_credit_card_account'));
        }
        payments.add({
          'type': 'Kredi Kartı',
          'amount': krediKartiTutar,
          'accountCode': kart.kod,
        });
      }

      await PerakendeSatisVeritabaniServisi().satisIsleminiKaydet(
        satisBilgileri: {
          'kullanici': currentUser,
          'tarih': _selectedDate,
          'belgeTuru': 'Perakende',
          'faturaNo': faturaNo,
          'aciklama': _aciklamaController.text,
          'genelToplam': genelToplam,
          'alinanTutar': 0,
          'integrationRef': entegrasyonRef,
          'paraBirimi': _selectedParaBirimi,
          'payments': payments,
          'items': _sepetItems
              .map(
                (e) => {
                  'code': e.kodNo,
                  'name': e.adi,
                  'unit': e.olcu,
                  'quantity': e.miktar,
                  'price': e.birimFiyati,
                  'total': e.toplamFiyat,
                  'warehouseId': _selectedDepoId,
                },
              )
              .toList(growable: false),
        },
      );

      if (!mounted) return;

      if (_fisYazdir) {
        await _fisYazdirOnizleme(faturaNo: faturaNo);
        if (!mounted) return;
      }

      setState(() {
        _sepetItems.clear();
        _odenenTutar = 0;
        _selectedRowIndex = null;
      });

      MesajYardimcisi.basariGoster(context, tr('common.saved_successfully'));
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

	@override
	Widget build(BuildContext context) {
	    final theme = Theme.of(context);
	    final isTablet = ResponsiveYardimcisi.tabletMi(context);
	    final isLandscape =
	        MediaQuery.orientationOf(context) == Orientation.landscape;
	    final useTabletLandscapeLayout = isTablet && isLandscape;
	    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

	    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        LogicalKeySet(LogicalKeyboardKey.f1): () {
          _miktarFocusNode.requestFocus();
          _miktarController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _miktarController.text.length,
          );
        },
        LogicalKeySet(LogicalKeyboardKey.f2): () {
          _odenenTutarFocusNode.requestFocus();
          _odenenTutarController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _odenenTutarController.text.length,
          );
        },
        LogicalKeySet(LogicalKeyboardKey.f11): () {
          final isCompact = MediaQuery.sizeOf(context).width < 1100;
          if (isCompact) {
            _openHizliUrunlerSheet();
            return;
          }
          setState(() => _showHizliUrunler = !_showHizliUrunler);
        },
      },
	      child: Scaffold(
	        key: _scaffoldKey,
	        backgroundColor: const Color(0xFFF5F5F5),
	        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            tr('nav.trading_operations.retail_sale'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 21,
            ),
          ),
          centerTitle: false,
        ),
		        body: LayoutBuilder(
		          builder: (context, constraints) {
		            final bool tightHeightForKeyboard =
		                useTabletLandscapeLayout && constraints.maxHeight < 320;
		            final bool treatAsKeyboardVisible =
		                keyboardVisible || tightHeightForKeyboard;
		            final collapseSecondRow = useTabletLandscapeLayout &&
		                treatAsKeyboardVisible &&
		                !_aciklamaFocusNode.hasFocus;
		            final hideBottomAreaForKeyboard =
		                useTabletLandscapeLayout && treatAsKeyboardVisible;

		            final isCompact =
		                constraints.maxWidth < 1100 && !useTabletLandscapeLayout;

	            if (isCompact) {
	              return Column(
	                children: [
	                  _buildTopControlArea(),
	                  Expanded(child: _buildProductTable()),
	                  _buildCompactActionBar(),
	                  _buildBottomArea(),
	                ],
              );
            }

            final allowQuickSidePanel = constraints.maxWidth >= 1300;
            if (!allowQuickSidePanel && _showHizliUrunler) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (!_showHizliUrunler) return;
                setState(() => _showHizliUrunler = false);
              });
            }

	            return Row(
	              children: [
	                // Ana İçerik (Tablo, Üst Alan, Alt Alan)
	                Expanded(
	                  child: Column(
	                    children: [
	                      // Üst kontrol alanı
	                      _buildTopControlArea(
	                        collapseSecondRow: collapseSecondRow,
	                      ),
	                      // Tablo
	                      Expanded(child: _buildProductTable()),
	                      // Alt para butonları ve toplam
	                      if (hideBottomAreaForKeyboard)
	                        _buildKeyboardSummaryBar()
	                      else
	                        _buildBottomArea(),
	                    ],
	                  ),
	                ),
                // Entegre Hızlı Ürünler Paneli
                if (allowQuickSidePanel && _showHizliUrunler)
                  _buildHizliUrunlerSidePanel(),
                // Sağ Dar Aksiyon Paneli
                _buildRightActionPanel(useQuickProductsSheet: !allowQuickSidePanel),
              ],
            );
          },
        ),
      ),
    );
  }

  void _hizliUrunSecildi(UrunModel urun) {
    final qty = _parseMiktar();
    if (qty <= 0) {
      MesajYardimcisi.hataGoster(context, tr('retail.error.invalid_quantity'));
      return;
    }

    setState(() {
      _sepeteEkle(item: urun, miktar: qty);
      _barkodController.clear();
      _miktarController.text = '1';
    });
    _barkodFocusNode.requestFocus();
  }

  Future<void> _openHizliUrunlerSheet() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: Material(
                color: Colors.white,
                child: _PerakendeHizliUrunlerPaneli(
                  headerPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  hizliUrunler: _hizliUrunler,
                  onSelect: _hizliUrunSecildi,
                  onChanged: _loadHizliUrunler,
                  onClose: () => Navigator.of(sheetContext).pop(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMoreActionsSheet() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
            child: Material(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr('common.other'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      label: tr('retail.account_sale'),
                      shortcut: '',
                      color: Colors.grey.shade100,
                      textColor: Colors.grey.shade700,
                      icon: Icons.account_balance_wallet,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _tamamlaCariSatis();
                      },
                      outlined: true,
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      label: tr('retail.apply_discount'),
                      shortcut: '',
                      color: Colors.grey.shade100,
                      textColor: Colors.grey.shade700,
                      icon: Icons.percent,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _showInvoiceDiscountDialog();
                      },
                      outlined: true,
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      label: tr('retail.delete_all'),
                      shortcut: '',
                      color: const Color(0xFFFFEBEE),
                      textColor: const Color(0xFFEA4335),
                      icon: Icons.delete_outline,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _tumunuSil();
                      },
                      outlined: true,
                      borderColor: const Color(0xFFEA4335),
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      label: tr('retail.delete_selected'),
                      shortcut: '',
                      color: Colors.grey.shade50,
                      textColor: Colors.grey.shade700,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _seciliyiSil();
                      },
                      outlined: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: tr('retail.cash_sale'),
                  shortcut: '',
                  color: const Color(0xFF4CAF50),
                  icon: Icons.monetization_on,
                  onPressed: () =>
                      _tamamlaSatisTekOdeme(odemeYeri: 'Kasa'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  label: tr('retail.credit_card'),
                  shortcut: '',
                  color: const Color(0xFF26A69A),
                  icon: Icons.credit_card,
                  onPressed: () =>
                      _tamamlaSatisTekOdeme(odemeYeri: 'Kredi Kartı'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  label: tr('retail.partial_payment'),
                  shortcut: '',
                  color: const Color(0xFFFF9800),
                  icon: Icons.pie_chart,
                  onPressed: _showPartialPaymentDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTextActionButton(
                  label: tr('retail.quick_products'),
                  shortcut: '',
                  icon: Icons.bolt,
                  onPressed: _openHizliUrunlerSheet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextActionButton(
                  label: tr('retail.numeric_keyboard'),
                  shortcut: '',
                  icon: Icons.dialpad,
                  onPressed: _openNakitTutarDialog,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextActionButton(
                  label: tr('retail.cash_register'),
                  shortcut: '',
                  icon: Icons.point_of_sale,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const KasalarSayfasi(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextActionButton(
                  label: tr('common.other'),
                  shortcut: '',
                  icon: Icons.more_horiz_rounded,
                  onPressed: _openMoreActionsSheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopControlArea({bool collapseSecondRow = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
	      child: Column(
	        children: [
	          // Birinci satır: Miktar, Barkod arama
	          Row(
	            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Miktar alanı
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tr('retail.quantity'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildShortcutBadge('F1'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 48,
                        child: TextField(
                          controller: _miktarController,
                          focusNode: _miktarFocusNode,
                          onSubmitted: (_) => _barkodFocusNode.requestFocus(),
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildSmallButton(
                        icon: Icons.add,
                        label: tr('retail.add'),
                        onPressed: () => _barkodAraVeEkle(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 24),
              // Barkod arama
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF1E88E5),
                            width: 2,
                          ),
                        ),
                        child: TextField(
                          controller: _barkodController,
                          focusNode: _barkodFocusNode,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          onSubmitted: (_) => _barkodAraVeEkle(),
                          decoration: InputDecoration(
                            hintText: tr('retail.barcode_placeholder'),
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _barkodAraVeEkle(),
                      icon: const Icon(Icons.search, size: 20),
                      label: Text(
                        tr('retail.find'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
	          ),
	          if (!collapseSecondRow) ...[
	            const SizedBox(height: 16),
	            // İkinci satır: Fiyat grubu, Depo, Tarih, Açıklama, Fiş Yazdır
	            LayoutBuilder(
	              builder: (context, constraints) {
	              final isTablet = ResponsiveYardimcisi.tabletMi(context);
	              final isCompact = constraints.maxWidth < 900;
	
	              final labelFontSize = isTablet ? 11.0 : 12.0;
	              final fieldFontSize = isTablet ? 12.0 : 13.0;
	              final fieldHeight = isTablet ? 34.0 : 36.0;
	              final priceGroupButtonSize = isTablet ? 28.0 : 32.0;
	              final priceGroupButtonFontSize = isTablet ? 11.0 : 12.0;
	              final allowFlexibleFields = isTablet && isCompact;

	              final priceGroup = Column(
	                crossAxisAlignment: CrossAxisAlignment.start,
	                children: [
	                  Text(
	                    tr('retail.price_group'),
	                    style: TextStyle(
	                      fontSize: labelFontSize,
	                      fontWeight: FontWeight.w500,
	                      color: Colors.grey.shade600,
	                    ),
	                  ),
	                  const SizedBox(height: 4),
	                  Row(
	                    children: [
	                      _buildPriceGroupButton(
	                        1,
	                        size: priceGroupButtonSize,
	                        fontSize: priceGroupButtonFontSize,
	                      ),
	                      const SizedBox(width: 4),
	                      _buildPriceGroupButton(
	                        2,
	                        size: priceGroupButtonSize,
	                        fontSize: priceGroupButtonFontSize,
	                      ),
	                      const SizedBox(width: 4),
	                      _buildPriceGroupButton(
	                        3,
	                        size: priceGroupButtonSize,
	                        fontSize: priceGroupButtonFontSize,
	                      ),
	                    ],
	                  ),
	                ],
	              );

	              final warehouse = Column(
	                crossAxisAlignment: CrossAxisAlignment.start,
	                children: [
	                  Text(
	                    tr('retail.warehouse'),
	                    style: TextStyle(
	                      fontSize: labelFontSize,
	                      fontWeight: FontWeight.w500,
	                      color: Colors.grey.shade600,
	                    ),
	                  ),
	                  const SizedBox(height: 4),
	                  Container(
	                    width: allowFlexibleFields ? null : 220,
	                    height: fieldHeight,
	                    padding: EdgeInsets.symmetric(horizontal: isTablet ? 10 : 12),
	                    decoration: BoxDecoration(
	                      color: Colors.white,
	                      borderRadius: BorderRadius.circular(6),
	                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: InkWell(
                      mouseCursor: WidgetStateMouseCursor.clickable,
                      onTap: _selectWarehouses,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
	                              _selectedDepoIds.isEmpty
	                                  ? tr("retail.select_warehouse")
	                                  : _selectedDepoIds.length == 1
	                                      ? _depolar
	                                            .firstWhere(
                                              (d) =>
                                                  d.id ==
                                                  _selectedDepoIds.first,
                                              orElse: () => _depolar.first,
                                            )
                                            .ad
	                                      : "${_selectedDepoIds.length} ${tr("retail.warehouses_selected")}",
	                              style: TextStyle(
	                                fontSize: fieldFontSize,
	                                fontWeight: FontWeight.w500,
	                                color: Color(0xFF333333),
	                              ),
	                              overflow: TextOverflow.ellipsis,
	                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );

	              final date = Column(
	                crossAxisAlignment: CrossAxisAlignment.start,
	                children: [
	                  Text(
	                    tr('common.date'),
	                    style: TextStyle(
	                      fontSize: labelFontSize,
	                      fontWeight: FontWeight.w500,
	                      color: Colors.grey.shade600,
	                    ),
	                  ),
	                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _selectDate,
                    mouseCursor: SystemMouseCursors.click,
                    borderRadius: BorderRadius.circular(6),
	                    child: Container(
	                      width: allowFlexibleFields ? null : 180,
	                      height: fieldHeight,
	                      padding: EdgeInsets.symmetric(horizontal: isTablet ? 10 : 12),
	                      decoration: BoxDecoration(
	                        color: Colors.white,
	                        borderRadius: BorderRadius.circular(6),
	                        border: Border.all(color: Colors.grey.shade300),
	                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
	                          Expanded(
	                            child: Text(
	                              DateFormat('dd.MM.yyyy').format(_selectedDate),
	                              style: TextStyle(
	                                fontSize: fieldFontSize,
	                                fontWeight: FontWeight.w500,
	                                color: Color(0xFF333333),
	                              ),
	                              maxLines: 1,
	                              overflow: TextOverflow.ellipsis,
	                            ),
	                          ),
	                          IconButton(
	                            padding: EdgeInsets.zero,
	                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.clear,
                              size: 16,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(() => _selectedDate = DateTime.now());
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );

	              final description = Column(
	                crossAxisAlignment: CrossAxisAlignment.start,
	                children: [
	                  Text(
	                    tr('retail.description'),
	                    style: TextStyle(
	                      fontSize: labelFontSize,
	                      fontWeight: FontWeight.w500,
	                      color: Colors.grey.shade600,
	                    ),
	                  ),
	                  const SizedBox(height: 4),
	                  SizedBox(
	                    height: fieldHeight,
	                    child: TextField(
	                      controller: _aciklamaController,
	                      focusNode: _aciklamaFocusNode,
	                      style: TextStyle(fontSize: fieldFontSize),
	                      decoration: InputDecoration(
	                        contentPadding: const EdgeInsets.symmetric(
	                          horizontal: 12,
	                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                ],
              );

	              final printReceipt = Column(
	                crossAxisAlignment: CrossAxisAlignment.start,
	                children: [
	                  Text(
	                    tr('retail.print_receipt'),
	                    style: TextStyle(
	                      fontSize: labelFontSize,
	                      fontWeight: FontWeight.w500,
	                      color: Colors.grey.shade600,
	                    ),
	                  ),
	                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildToggleSwitch(),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.settings,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () => MesajYardimcisi.bilgiGoster(
                            context,
                            tr('common.feature_coming_soon'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );

	              if (isCompact) {
	                if (isTablet) {
	                  final gap = constraints.maxWidth < 760 ? 8.0 : 12.0;
	                  return Row(
	                    crossAxisAlignment: CrossAxisAlignment.end,
	                    children: [
	                      priceGroup,
	                      SizedBox(width: gap),
	                      Expanded(flex: 3, child: warehouse),
	                      SizedBox(width: gap),
	                      Expanded(flex: 3, child: date),
	                      SizedBox(width: gap),
	                      printReceipt,
	                      SizedBox(width: gap),
	                      Expanded(flex: 4, child: description),
	                    ],
	                  );
	                }

	                return Column(
	                  crossAxisAlignment: CrossAxisAlignment.stretch,
	                  children: [
	                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        priceGroup,
                        warehouse,
                        date,
                        printReceipt,
                      ],
                    ),
                    const SizedBox(height: 12),
                    description,
                  ],
                );
	              }

	              final wideGap = isTablet ? 16.0 : 24.0;
	              final trailingGap = isTablet ? 12.0 : 16.0;
	              return Row(
	                crossAxisAlignment: CrossAxisAlignment.end,
	                children: [
	                  priceGroup,
	                  SizedBox(width: wideGap),
	                  warehouse,
	                  SizedBox(width: wideGap),
	                  date,
	                  SizedBox(width: wideGap),
	                  Expanded(child: description),
	                  SizedBox(width: trailingGap),
	                  printReceipt,
	                ],
	              );
	            },
	          ),
	          ],
	        ],
	      ),
	    );
	  }

  Widget _buildKeyboardSummaryBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${tr('retail.row_count')}: $_satirSayisi',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const Spacer(),
          Text(
            tr('retail.grand_total'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTutar(_genelToplam),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _selectedParaBirimi,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

	  Widget _buildPriceGroupButton(
	    int group, {
	    double size = 32,
	    double fontSize = 12,
	  }) {
	    final isSelected = _selectedFiyatGrubu == group;
	    return InkWell(
	      mouseCursor: WidgetStateMouseCursor.clickable,
	      onTap: () => setState(() => _selectedFiyatGrubu = group),
	      child: Container(
	        width: size,
	        height: size,
	        decoration: BoxDecoration(
	          color: isSelected ? const Color(0xFF1E88E5) : Colors.white,
	          borderRadius: BorderRadius.circular(6),
	          border: Border.all(
            color: isSelected ? const Color(0xFF1E88E5) : Colors.grey.shade300,
          ),
        ),
	        child: Center(
	          child: Text(
	            '[$group]',
	            style: TextStyle(
	              fontSize: fontSize,
	              fontWeight: FontWeight.w600,
	              color: isSelected ? Colors.white : Colors.grey.shade700,
	            ),
	          ),
	        ),
	      ),
	    );
	  }

  Widget _buildToggleSwitch() {
    return MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
      onTap: () => setState(() => _fisYazdir = !_fisYazdir),
      child: Container(
        width: 60,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: _fisYazdir ? const Color(0xFF4CAF50) : Colors.grey.shade300,
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              left: _fisYazdir ? 32 : 4,
              top: 4,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: _fisYazdir ? 8 : null,
              right: _fisYazdir ? null : 8,
              top: 7,
              child: Text(
                _fisYazdir ? tr('common.on') : tr('common.off'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _fisYazdir ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildSmallButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade700,
        side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildProductTable() {
    final isTablet = ResponsiveYardimcisi.tabletMi(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final tightMode = isTablet && isLandscape && keyboardVisible;

    return Container(
      margin: tightMode
          ? const EdgeInsets.fromLTRB(16, 8, 16, 8)
          : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tablo başlığı
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: tightMode ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildTableHeader(tr('retail.table.code'), flex: 1),
                _buildTableHeader(tr('retail.table.barcode'), flex: 2),
                _buildTableHeader(tr('retail.table.name'), flex: 3),
                _buildTableHeader(
                  tr('retail.table.unit_price'),
                  flex: 1,
                  align: TextAlign.right,
                ),
                _buildTableHeader(
                  tr('retail.table.discount'),
                  flex: 1,
                  align: TextAlign.center,
                ),
                _buildTableHeader(
                  tr('retail.table.quantity'),
                  flex: 1,
                  align: TextAlign.center,
                ),
                _buildTableHeader(
                  tr('retail.table.unit'),
                  flex: 1,
                  align: TextAlign.center,
                ),
                _buildTableHeader(
                  tr('retail.table.total_price'),
                  flex: 1,
                  align: TextAlign.right,
                ),
                _buildTableHeader(
                  tr('retail.table.currency'),
                  flex: 1,
                  align: TextAlign.center,
                ),
              ],
            ),
          ),
          // Tablo içeriği
          Expanded(
            child: ListView.separated(
              itemCount: _sepetItems.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final item = _sepetItems[index];
                return MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                  onTap: () => setState(() => _selectedRowIndex = index),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: tightMode ? 10 : 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildTableCell(item.kodNo, flex: 1),
                        _buildTableCell(item.barkodNo, flex: 2),
                        _buildTableCell(item.adi, flex: 3),
                        _buildTableCell(
                          _formatTutar(item.birimFiyati),
                          flex: 1,
                          align: TextAlign.right,
                        ),
                        _buildTableCell(
                          _formatTutar(item.iskontoOrani, decimalDigits: 2),
                          flex: 1,
                          align: TextAlign.center,
                        ),
                        _buildTableCell(
                          _formatTutar(
                            item.miktar,
                            decimalDigits: _genelAyarlar.miktarOndalik,
                          ),
                          flex: 1,
                          align: TextAlign.center,
                        ),
                        _buildTableCell(
                          item.olcu,
                          flex: 1,
                          align: TextAlign.center,
                        ),
                        _buildTableCell(
                          _formatTutar(item.toplamFiyat),
                          flex: 1,
                          align: TextAlign.right,
                          isBold: true,
                        ),
                        _buildTableCell(
                          item.paraBirimi,
                          flex: 1,
                          align: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ));
              },
            ),
          ),
        ],
      ),
    );
  }

	  Widget _buildTableHeader(
	    String text, {
	    int flex = 1,
	    TextAlign align = TextAlign.left,
	  }) {
	    final isTablet = ResponsiveYardimcisi.tabletMi(context);
	    return Expanded(
	      flex: flex,
	      child: Text(
	        text,
	        textAlign: align,
	        style: TextStyle(
	          fontSize: isTablet ? 10 : 11,
	          fontWeight: FontWeight.w700,
	          color: Colors.grey.shade700,
	        ),
	        maxLines: isTablet ? 2 : null,
	        overflow: isTablet ? TextOverflow.ellipsis : null,
	      ),
	    );
	  }

  Widget _buildTableCell(
    String text, {
    int flex = 1,
    TextAlign align = TextAlign.left,
    bool isBold = false,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          color: const Color(0xFF333333),
        ),
      ),
    );
  }

	  Widget _buildBottomArea() {
	    final nakitButonlari = _nakitButonDegerleri();

	    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
	      child: LayoutBuilder(
		        builder: (context, constraints) {
		          final isTablet = ResponsiveYardimcisi.tabletMi(context);
			          final isLandscape =
			              MediaQuery.orientationOf(context) == Orientation.landscape;
			          final forceRowLayout = isTablet && isLandscape;
			          final isNarrow = constraints.maxWidth < 980 && !forceRowLayout;
			          final usePortraitTabletSplitLayout = isTablet && !isLandscape;
			          final moneyButtonGap = isTablet ? 3.0 : 4.0;
			          final sectionGap = isTablet ? 10.0 : 12.0;
			          final aboveButtonsGap = isTablet ? 4.0 : 6.0;

			          final rowCountText = Text(
			            '${tr('retail.row_count')}: $_satirSayisi',
			            style: TextStyle(
			              fontSize: 11,
			              fontWeight: FontWeight.w600,
			              color: Colors.grey.shade600,
			            ),
			          );

			          final paymentEntry = Column(
			            mainAxisSize: MainAxisSize.min,
			            children: [
			              Row(
			                mainAxisSize: MainAxisSize.min,
			                children: [
			                  _buildShortcutBadge('F2'),
			                  const SizedBox(width: 4),
			                  Text(
			                    tr('retail.payment_entry'),
			                    style: const TextStyle(
			                      fontSize: 10,
			                      fontWeight: FontWeight.w500,
			                      color: Colors.grey,
			                    ),
			                  ),
			                ],
			              ),
			              const SizedBox(height: 4),
			              SizedBox(
			                width: 85,
			                height: 36,
			                child: TextField(
			                  controller: _odenenTutarController,
			                  focusNode: _odenenTutarFocusNode,
			                  textAlign: TextAlign.center,
			                  keyboardType: const TextInputType.numberWithOptions(
			                    decimal: true,
			                  ),
			                  style: const TextStyle(
			                    fontSize: 14,
			                    fontWeight: FontWeight.w600,
			                    color: Color(0xFF333333),
			                  ),
			                  decoration: InputDecoration(
			                    contentPadding: EdgeInsets.zero,
			                    filled: true,
			                    fillColor: Colors.white,
			                    enabledBorder: OutlineInputBorder(
			                      borderRadius: BorderRadius.circular(4),
			                      borderSide: BorderSide(color: Colors.grey.shade300),
			                    ),
			                    focusedBorder: OutlineInputBorder(
			                      borderRadius: BorderRadius.circular(4),
			                      borderSide: const BorderSide(
			                        color: Color(0xFF1E88E5),
			                        width: 1.5,
			                      ),
			                    ),
			                  ),
			                  onChanged: (val) {
			                    setState(() {
			                      _odenenTutar = FormatYardimcisi.parseDouble(
			                        val,
			                        binlik: _genelAyarlar.binlikAyiraci,
			                        ondalik: _genelAyarlar.ondalikAyiraci,
			                      );
			                    });
			                  },
			                ),
			              ),
			              const SizedBox(height: 4),
			              SizedBox(height: isTablet ? 12 : 24),
			            ],
			          );

			          final changeCard = Container(
			            padding: EdgeInsets.fromLTRB(
			              24,
			              12,
			              24,
			              isTablet ? 8 : 12,
			            ),
			            decoration: BoxDecoration(
			              gradient: const LinearGradient(
			                colors: [Color(0xFF26C6DA), Color(0xFF00ACC1)],
			                begin: Alignment.topLeft,
			                end: Alignment.bottomRight,
			              ),
			              borderRadius: BorderRadius.circular(24),
			            ),
			            child: Column(
			              children: [
			                Text(
			                  tr('retail.change'),
			                  style: const TextStyle(
			                    fontSize: 11,
			                    fontWeight: FontWeight.w500,
			                    color: Colors.white70,
			                  ),
			                ),
			                if (isTablet) const SizedBox(height: 2),
			                Text(
			                  _formatParaBirimiGosterimi(_paraUstu),
			                  style: TextStyle(
			                    fontSize: isTablet ? 17 : 18,
			                    fontWeight: FontWeight.w700,
			                    color: Colors.white,
			                  ),
			                ),
			              ],
			            ),
			          );

			          final leftControls = Column(
			            crossAxisAlignment: CrossAxisAlignment.start,
			            mainAxisSize: MainAxisSize.min,
			            children: [
			              rowCountText,
			              SizedBox(height: aboveButtonsGap),
			              if (usePortraitTabletSplitLayout)
			                SingleChildScrollView(
			                  scrollDirection: Axis.horizontal,
			                  child: Column(
			                    mainAxisSize: MainAxisSize.min,
			                    crossAxisAlignment: CrossAxisAlignment.start,
			                    children: [
			                      Row(
			                        mainAxisSize: MainAxisSize.min,
			                        crossAxisAlignment: CrossAxisAlignment.end,
			                        children: [
			                          _buildMoneyButton(nakitButonlari[0]),
			                          SizedBox(width: moneyButtonGap),
			                          _buildMoneyButton(nakitButonlari[1]),
			                          SizedBox(width: moneyButtonGap),
			                          _buildMoneyButton(nakitButonlari[2]),
			                        ],
			                      ),
			                      SizedBox(height: isTablet ? 6 : 8),
			                      Row(
			                        mainAxisSize: MainAxisSize.min,
			                        crossAxisAlignment: CrossAxisAlignment.end,
			                        children: [
			                          _buildMoneyButton(nakitButonlari[3]),
			                          SizedBox(width: moneyButtonGap),
			                          _buildMoneyButton(nakitButonlari[4]),
			                          SizedBox(width: moneyButtonGap),
			                          _buildMoneyButton(nakitButonlari[5]),
			                          SizedBox(width: sectionGap),
			                          paymentEntry,
			                          SizedBox(width: sectionGap),
			                          changeCard,
			                        ],
			                      ),
			                    ],
			                  ),
			                )
			              else
			                SingleChildScrollView(
			                  scrollDirection: Axis.horizontal,
			                  child: Row(
			                    mainAxisSize: MainAxisSize.min,
			                    crossAxisAlignment: CrossAxisAlignment.end,
			                    children: [
			                      // Para butonları
			                      _buildMoneyButton(nakitButonlari[0]),
			                      SizedBox(width: moneyButtonGap),
			                      _buildMoneyButton(nakitButonlari[1]),
			                      SizedBox(width: moneyButtonGap),
			                      _buildMoneyButton(nakitButonlari[2]),
			                      SizedBox(width: moneyButtonGap),
			                      _buildMoneyButton(nakitButonlari[3]),
			                      SizedBox(width: moneyButtonGap),
			                      _buildMoneyButton(nakitButonlari[4]),
			                      SizedBox(width: moneyButtonGap),
			                      _buildMoneyButton(nakitButonlari[5]),
			                      SizedBox(width: sectionGap),
			                      paymentEntry,
			                      SizedBox(width: sectionGap),
			                      changeCard,
			                    ],
			                  ),
			                ),
			            ],
			          );

          final grandTotal = Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tr('retail.grand_total'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTutar(_genelToplam),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _selectedParaBirimi,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

	          if (isNarrow && !usePortraitTabletSplitLayout) {
	            return Column(
	              crossAxisAlignment: CrossAxisAlignment.stretch,
	              children: [
	                leftControls,
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: grandTotal,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: leftControls),
              const SizedBox(width: 12),
              grandTotal,
            ],
          );
        },
      ),
    );
  }

  Widget _buildMoneyButton(int amount) {
    final individualChange = amount.toDouble() - _genelToplam;
    final showChange = individualChange > 0 && _sepetItems.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 50,
          height: 36,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _odenenTutar += amount.toDouble();
                _odenenTutarController.text = _formatTutar(
                  _odenenTutar,
                  decimalDigits: 2,
                );
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF333333),
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Text(
              '$amount',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 50,
          height: 24,
          decoration: BoxDecoration(
            color: showChange ? const Color(0xFFE1F5FE) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: showChange ? const Color(0xFFB3E5FC) : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            showChange ? _formatTutar(individualChange) : '',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0277BD),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightActionPanel({bool useQuickProductsSheet = false}) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              primary: false,
              padding: EdgeInsets.zero,
              children: [
                // Nakit Satış [F4]
                _buildActionButton(
                  label: tr('retail.cash_sale'),
                  shortcut: '[F4]',
                  color: const Color(0xFF4CAF50),
                  icon: Icons.monetization_on,
                  onPressed: () => _tamamlaSatisTekOdeme(odemeYeri: 'Kasa'),
                ),
                const SizedBox(height: 8),
                // Kredi Kartı [F6]
                _buildActionButton(
                  label: tr('retail.credit_card'),
                  shortcut: '[F6]',
                  color: const Color(0xFF26A69A),
                  icon: Icons.credit_card,
                  onPressed: () =>
                      _tamamlaSatisTekOdeme(odemeYeri: 'Kredi Kartı'),
                ),
                const SizedBox(height: 8),
                // Parçalı Ödeme [F7]
                _buildActionButton(
                  label: tr('retail.partial_payment'),
                  shortcut: '[F7]',
                  color: const Color(0xFFFF9800),
                  icon: Icons.pie_chart,
                  onPressed: _showPartialPaymentDialog,
                ),
                const SizedBox(height: 8),
                // Cari Satış [F8]
                _buildActionButton(
                  label: tr('retail.account_sale'),
                  shortcut: '[F8]',
                  color: Colors.grey.shade100,
                  textColor: Colors.grey.shade700,
                  icon: Icons.account_balance_wallet,
                  onPressed: _tamamlaCariSatis,
                  outlined: true,
                ),
                const SizedBox(height: 8),
                // İskonto Yap [F9]
                _buildActionButton(
                  label: tr('retail.apply_discount'),
                  shortcut: '[F9]',
                  color: Colors.grey.shade100,
                  textColor: Colors.grey.shade700,
                  icon: Icons.percent,
                  onPressed: _showInvoiceDiscountDialog,
                  outlined: true,
                ),
                const SizedBox(height: 8),
                // Tümünü Sil [F10]
                _buildActionButton(
                  label: tr('retail.delete_all'),
                  shortcut: '[F10]',
                  color: const Color(0xFFFFEBEE),
                  textColor: const Color(0xFFEA4335),
                  icon: Icons.delete_outline,
                  onPressed: _tumunuSil,
                  outlined: true,
                  borderColor: const Color(0xFFEA4335),
                ),
                const SizedBox(height: 8),
                // Seçiliyi Sil
                _buildActionButton(
                  label: tr('retail.delete_selected'),
                  shortcut: '',
                  color: Colors.grey.shade50,
                  textColor: Colors.grey.shade700,
                  onPressed: _seciliyiSil,
                  outlined: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Hızlı Ürünler [F11]
          _buildTextActionButton(
            label: tr('retail.quick_products'),
            shortcut: '[F11]',
            icon: Icons.bolt,
            onPressed: useQuickProductsSheet
                ? _openHizliUrunlerSheet
                : () => setState(() => _showHizliUrunler = !_showHizliUrunler),
          ),
          const SizedBox(height: 8),
          // Sayısal Klavye [F12]
          _buildTextActionButton(
            label: tr('retail.numeric_keyboard'),
            shortcut: '[F12]',
            icon: Icons.dialpad,
            onPressed: _openNakitTutarDialog,
          ),
          const SizedBox(height: 8),
          // Yazar Kasa [F3]
          _buildTextActionButton(
            label: tr('retail.cash_register'),
            shortcut: '[F3]',
            icon: Icons.point_of_sale,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const KasalarSayfasi()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required String shortcut,
    required Color color,
    Color? textColor,
    IconData? icon,
    required VoidCallback onPressed,
    bool outlined = false,
    Color? borderColor,
  }) {
    final effectiveTextColor = textColor ?? Colors.white;

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: effectiveTextColor,
                side: BorderSide(color: borderColor ?? Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (shortcut.isNotEmpty)
                    Text(
                      shortcut,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: effectiveTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: effectiveTextColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (shortcut.isNotEmpty)
                    Text(
                      shortcut,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: effectiveTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextActionButton({
    required String label,
    required String shortcut,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: color,
          foregroundColor: const Color(0xFF1E88E5),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (shortcut.isNotEmpty)
              Text(
                shortcut,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF5F6368),
        ),
      ),
    );
  }

  Widget _buildHizliUrunlerSidePanel() {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: _PerakendeHizliUrunlerPaneli(
        hizliUrunler: _hizliUrunler,
        onSelect: _hizliUrunSecildi,
        onChanged: _loadHizliUrunler,
        onClose: () => setState(() => _showHizliUrunler = false),
      ),
    );
  }
}

class _PerakendeHizliUrunlerPaneli extends StatefulWidget {
  final List<UrunModel> hizliUrunler;
  final Function(UrunModel) onSelect;
  final VoidCallback onChanged;
  final VoidCallback? onClose;
  final EdgeInsets headerPadding;

  const _PerakendeHizliUrunlerPaneli({
    required this.hizliUrunler,
    required this.onSelect,
    required this.onChanged,
    this.onClose,
    this.headerPadding = const EdgeInsets.fromLTRB(16, 48, 16, 16),
  });

  @override
  State<_PerakendeHizliUrunlerPaneli> createState() =>
      _PerakendeHizliUrunlerPaneliState();
}

class _PerakendeHizliUrunlerPaneliState
    extends State<_PerakendeHizliUrunlerPaneli> {
  bool _editMode = false;
  final TextEditingController _searchController = TextEditingController();
  List<UrunModel> _searchResults = [];
  bool _isSearching = false;

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await UrunlerVeritabaniServisi().urunleriGetir(
        aramaTerimi: query,
        sayfaBasinaKayit: 10,
      );
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Arama hatası: $e');
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        if (_editMode) _buildEditArea(),
        Expanded(child: _buildProductGrid()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: widget.headerPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Color(0xFFFFA000)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('retail.quick_products'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: Icon(
              _editMode ? Icons.check_circle : Icons.settings_outlined,
              color: _editMode ? Colors.green : Colors.grey.shade600,
            ),
            onPressed: () {
              setState(() {
                _editMode = !_editMode;
                if (!_editMode) {
                  _searchController.clear();
                  _searchResults = [];
                }
              });
            },
            tooltip: _editMode ? tr('common.ok') : tr('common.manage'),
          ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onClose,
            ),
        ],
      ),
    );
  }

  Widget _buildEditArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('products.add'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: tr('retail.product_search_placeholder'),
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue.shade200),
              ),
            ),
            onChanged: _searchProducts,
          ),
          if (_searchResults.isNotEmpty || _isSearching)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: _isSearching
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final urun = _searchResults[index];
                        final isAlreadyAdded = widget.hizliUrunler.any(
                          (e) => e.id == urun.id,
                        );
                        return ListTile(
                          dense: true,
                          leading: SizedBox(
                            width: 40,
                            height: 40,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: _buildProductImage(urun, size: 20),
                            ),
                          ),
                          title: Text(
                            urun.ad,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(urun.kod),
                          trailing: IconButton(
                            icon: Icon(
                              isAlreadyAdded
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: isAlreadyAdded
                                  ? Colors.green
                                  : Colors.blue,
                            ),
                            onPressed: isAlreadyAdded
                                ? null
                                : () async {
                                    await UrunlerVeritabaniServisi()
                                        .hizliUruneEkle(urun.id);
                                    widget.onChanged();
                                  },
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    if (widget.hizliUrunler.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              tr('retail.quick_product_not_found'),
              style: TextStyle(color: Colors.grey.shade500),
            ),
            if (!_editMode)
              TextButton(
                onPressed: () => setState(() => _editMode = true),
                child: Text(tr('products.add')),
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: widget.hizliUrunler.length,
      itemBuilder: (context, index) {
        final urun = widget.hizliUrunler[index];
        return _buildProductCard(urun);
      },
    );
  }

  Widget _buildProductCard(UrunModel urun) {
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: _editMode ? null : () => widget.onSelect(urun),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildProductImage(urun),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    urun.ad,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (_editMode)
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: () async {
                    await UrunlerVeritabaniServisi().hizliUrundenCikar(urun.id);
                    widget.onChanged();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(UrunModel urun, {double? size}) {
    String? raw;
    if (urun.resimUrl != null && urun.resimUrl!.isNotEmpty) {
      raw = urun.resimUrl!;
    } else if (urun.resimler.isNotEmpty) {
      raw = urun.resimler.first;
    }

    if (raw != null && raw.isNotEmpty) {
      final img = raw.trim();
      if (img.startsWith('http')) {
        return Image.network(
          img,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.image_outlined,
            color: Colors.grey.shade300,
            size: size,
          ),
        );
      }

      final normalized = _stripDataUriPrefix(img).replaceAll(RegExp(r'\s'), '');
      try {
        return Image.memory(
          base64Decode(normalized),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.image_outlined,
            color: Colors.grey.shade300,
            size: size,
          ),
        );
      } catch (_) {
        try {
          return Image.memory(
            base64Url.decode(normalized),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.image_outlined,
              color: Colors.grey.shade300,
              size: size,
            ),
          );
        } catch (_) {
          return Icon(
            Icons.image_outlined,
            color: Colors.grey.shade300,
            size: size,
          );
        }
      }
    }
    return Icon(Icons.image_outlined, color: Colors.grey.shade300, size: size);
  }

  String _stripDataUriPrefix(String value) {
    if (!value.startsWith('data:image')) return value;
    final commaIndex = value.indexOf(',');
    if (commaIndex == -1) return value;
    return value.substring(commaIndex + 1);
  }
}
