import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/mesaj_yardimcisi.dart';
import '../../../servisler/uretimler_veritabani_servisi.dart';
import '../../../servisler/urunler_veritabani_servisi.dart';
import '../../../servisler/ayarlar_veritabani_servisi.dart';
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import 'modeller/uretim_model.dart';
import 'modeller/recete_item_model.dart';
import '../urunler/modeller/urun_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UretimEkleSayfasi extends StatefulWidget {
  const UretimEkleSayfasi({super.key, this.urun, this.focusOnStock = false});

  final UretimModel? urun;
  final bool focusOnStock;

  @override
  State<UretimEkleSayfasi> createState() => _UretimEkleSayfasiState();
}

class _UretimEkleSayfasiState extends State<UretimEkleSayfasi> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();
  List<String> _units = ['Adet', 'Kg', 'Lt', 'Mt'];
  List<String> _groups = ['Genel'];

  // Basic Info Controllers
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _vatRateController = TextEditingController();
  final _alertQuantityController = TextEditingController();

  // Validation State
  String? _codeError;

  String? _selectedUnit;
  String? _selectedGroup;

  // Prices
  final _purchasePriceController = TextEditingController();
  String _purchaseCurrency = 'TRY';
  String _purchaseVatStatus = 'excluded';

  final List<Map<String, dynamic>> _salesPrices = [];
  bool _salesPricesOptionsTouched = false;

  // Attributes
  final List<Map<String, dynamic>> _attributes = [];

  // Images
  final List<String> _selectedImages = [];

  late FocusNode _purchasePriceFocusNode;
  final List<FocusNode> _salesPriceFocusNodes = [];

  // Reçete (BOM - Bill of Materials)
  final _recipeFormKey = GlobalKey<FormState>();
  final _recipeCodeController = TextEditingController();
  final _recipeNameController = TextEditingController();
  final _recipeQuantityController = TextEditingController();
  final _recipeUnitController = TextEditingController();
  final List<ReceteItem> _recipeItems = [];
  final Set<int> _selectedRecipeIndices = {};

  // Autocomplete/Focus Helpers
  final FocusNode _recipeCodeFocusNode = FocusNode();
  final FocusNode _recipeNameFocusNode = FocusNode();
  final FocusNode _recipeQuantityFocusNode = FocusNode();
  Timer? _searchDebounce;

  // Style Constants
  static const Color _primaryColor = Color(0xFF2C3E50);
  static const Color _labelColor = Color(0xFF4A4A4A);
  static const Color _textColor = Color(0xFF202124);
  static const Color _hintColor = Color(0xFFBDC1C6);
  static const Color _borderColor = Color(0xFFE0E0E0);

  late FocusNode _codeFocusNode;
  late FocusNode _nameFocusNode;
  late FocusNode _vatRateFocusNode;

  @override
  void initState() {
    super.initState();
    _codeFocusNode = FocusNode();
    _nameFocusNode = FocusNode();
    _vatRateFocusNode = FocusNode();
    _purchasePriceFocusNode = FocusNode();
    _attachPriceFormatter(_purchasePriceFocusNode, _purchasePriceController);
    _attachVatFormatter(_vatRateFocusNode, _vatRateController);
    _loadSettings();

    if (widget.urun != null) {
      _populateForm();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _codeFocusNode.requestFocus();
      });
    } else {
      // Add one default sales price row for new product
      _addSalesPriceRow();
      _requestInitialFocusForNewProduction();
    }
  }

  void _requestInitialFocusForNewProduction({bool onlyIfUnfocused = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.urun != null) return;

      final targetNode = _genelAyarlar.otoUretimKodu
          ? _nameFocusNode
          : _codeFocusNode;
      final primaryFocus = FocusManager.instance.primaryFocus;

      if (onlyIfUnfocused) {
        final isInitialFocus =
            primaryFocus == null ||
            primaryFocus == _codeFocusNode ||
            primaryFocus == _nameFocusNode;
        if (!isInitialFocus) return;

        if (targetNode == _codeFocusNode &&
            primaryFocus == _nameFocusNode &&
            _nameController.text.trim().isNotEmpty) {
          return;
        }
      }

      if (primaryFocus != targetNode) {
        targetNode.requestFocus();
      }
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

  void _attachVatFormatter(
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

        final formatted = FormatYardimcisi.sayiFormatlaOran(
          value,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: 2,
        );

        controller
          ..text = formatted
          ..selection = TextSelection.collapsed(offset: formatted.length);
      }
    });
  }

  void _populateForm() {
    final urun = widget.urun!;
    _codeController.text = urun.kod;
    _nameController.text = urun.ad;
    _barcodeController.text = urun.barkod;
    _vatRateController.text = FormatYardimcisi.sayiFormatlaOran(
      urun.kdvOrani,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: 2,
    );
    _alertQuantityController.text = FormatYardimcisi.sayiFormatla(
      urun.erkenUyariMiktari,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.miktarOndalik,
    );
    _purchasePriceController.text = FormatYardimcisi.sayiFormatla(
      urun.alisFiyati,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.fiyatOndalik,
    );

    // Ensure selected unit exists in list
    final unit = urun.birim.trim();
    if (unit.isNotEmpty) {
      if (!_units.contains(unit)) {
        _units.add(unit);
      }
      _selectedUnit = unit;
    } else {
      _selectedUnit = null;
    }

    // Ensure selected group exists in list
    if (urun.grubu.isNotEmpty) {
      if (!_groups.contains(urun.grubu)) {
        _groups.add(urun.grubu);
      }
      _selectedGroup = urun.grubu;
    } else {
      _selectedGroup = null;
    }

    // Sales Prices
    _salesPrices.clear();
    _salesPriceFocusNodes.clear();
    if (urun.satisFiyati1 > 0) {
      final controller = TextEditingController(
        text: FormatYardimcisi.sayiFormatla(
          urun.satisFiyati1,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.fiyatOndalik,
        ),
      );
      final focusNode = FocusNode();
      _attachPriceFormatter(focusNode, controller);
      _salesPriceFocusNodes.add(focusNode);
      _salesPrices.add({
        'price': controller,
        'currency': _genelAyarlar.varsayilanParaBirimi,
        'vatStatus': _genelAyarlar.varsayilanKdvDurumu,
        'focusNode': focusNode,
      });
    }
    if (urun.satisFiyati2 > 0) {
      final controller = TextEditingController(
        text: FormatYardimcisi.sayiFormatla(
          urun.satisFiyati2,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.fiyatOndalik,
        ),
      );
      final focusNode = FocusNode();
      _attachPriceFormatter(focusNode, controller);
      _salesPriceFocusNodes.add(focusNode);
      _salesPrices.add({
        'price': controller,
        'currency': _genelAyarlar.varsayilanParaBirimi,
        'vatStatus': _genelAyarlar.varsayilanKdvDurumu,
        'focusNode': focusNode,
      });
    }
    if (urun.satisFiyati3 > 0) {
      final controller = TextEditingController(
        text: FormatYardimcisi.sayiFormatla(
          urun.satisFiyati3,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.fiyatOndalik,
        ),
      );
      final focusNode = FocusNode();
      _attachPriceFormatter(focusNode, controller);
      _salesPriceFocusNodes.add(focusNode);
      _salesPrices.add({
        'price': controller,
        'currency': _genelAyarlar.varsayilanParaBirimi,
        'vatStatus': _genelAyarlar.varsayilanKdvDurumu,
        'focusNode': focusNode,
      });
    }
    if (_salesPrices.isEmpty) {
      _addSalesPriceRow();
    }

    // Attributes
    if (urun.ozellikler.isNotEmpty) {
      try {
        final List<dynamic> attrs = jsonDecode(urun.ozellikler);
        for (var attr in attrs) {
          _attributes.add({
            'name': TextEditingController(text: attr['name']),
            'color': attr['color'],
          });
        }
      } catch (e) {
        debugPrint('Özellikler parse edilirken hata: $e');
      }
    }

    // Images
    _selectedImages.addAll(urun.resimler);

    // Reçeteyi Yükle
    _loadRecipe(urun.id);
  }

  Future<void> _loadRecipe(int productionId) async {
    try {
      final items = await UretimlerVeritabaniServisi().receteGetir(
        productionId,
      );
      if (mounted) {
        setState(() {
          _recipeItems.clear();
          for (final item in items) {
            _recipeItems.add(ReceteItem.fromMap(item));
          }
        });
      }
    } catch (e) {
      debugPrint('Reçete yüklenirken hata: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      setState(() {
        _genelAyarlar = settings;

        // Birimleri güncelle
        if (settings.urunBirimleri.isNotEmpty) {
          _units = settings.urunBirimleri
              .map((e) => (e['name'] ?? '').toString().trim())
              .where((name) => name.isNotEmpty)
              .toList();
          // Varsayılan birimi seç
          final defaultUnit = settings.urunBirimleri.firstWhere(
            (e) => e['isDefault'] == true,
            orElse: () => settings.urunBirimleri.first,
          );
          final defaultUnitName = (defaultUnit['name'] ?? '').toString().trim();
          if ((_selectedUnit == null || _selectedUnit!.trim().isEmpty) &&
              defaultUnitName.isNotEmpty) {
            _selectedUnit = defaultUnitName;
          }
        }

        // Grupları güncelle
        if (settings.urunGruplari.isNotEmpty) {
          _groups = settings.urunGruplari
              .map((e) => e['name'].toString())
              .toList();
        }

        final selectedUnit = _selectedUnit?.trim();
        if (selectedUnit != null &&
            selectedUnit.isNotEmpty &&
            !_units.contains(selectedUnit)) {
          _units.add(selectedUnit);
        }

        if ((_selectedUnit == null || _selectedUnit!.trim().isEmpty) &&
            _units.isNotEmpty) {
          _selectedUnit = _units.first;
        }

        // Para birimini güncelle
        String currency = settings.varsayilanParaBirimi;
        if (currency == 'TL') currency = 'TRY';

        _purchaseCurrency = currency;

        // Varsayılan KDV durumunu uygula
        _purchaseVatStatus = settings.varsayilanKdvDurumu;

        if (!_salesPricesOptionsTouched) {
          for (final price in _salesPrices) {
            price['currency'] = currency;
            price['vatStatus'] = settings.varsayilanKdvDurumu;
          }
        }
      });

      // Kodları oluştur - SADECE YENİ EKLERKEN VE AYARLARDA OTOMATİK AKTİFSE
      if (widget.urun == null) {
        // Otomatik Üretim Kodu kontrolü
        if (settings.otoUretimKodu && _codeController.text.isEmpty) {
          final nextCode = await UretimlerVeritabaniServisi()
              .sonUretimKoduGetir();
          if (mounted) {
            int nextValue = 1;
            if (nextCode != null) {
              nextValue = (int.tryParse(nextCode) ?? 0) + 1;
            }

            final String newCode = settings.otoUretimKoduAlfanumerik
                ? 'URT-${nextValue.toString().padLeft(6, '0')}'
                : nextValue.toString();

            setState(() {
              _codeController.text = newCode;
            });
          }
        }

        // Otomatik Üretim Barkodu kontrolü
        if (settings.otoUretimBarkodu && _barcodeController.text.isEmpty) {
          final nextBarcode = await UretimlerVeritabaniServisi()
              .sonBarkodGetir();
          if (mounted) {
            int nextValue = 1;
            if (nextBarcode != null) {
              nextValue = (int.tryParse(nextBarcode) ?? 0) + 1;
            }

            final String newBarcode = settings.otoUretimBarkoduAlfanumerik
                ? 'URB-${nextValue.toString().padLeft(8, '0')}'
                : nextValue.toString();

            setState(() {
              _barcodeController.text = newBarcode;
            });
          }
        }

        _requestInitialFocusForNewProduction(onlyIfUnfocused: true);
      }

      // Depoları getir
    } catch (e) {
      debugPrint('Ayarlar yüklenirken hata: $e');
    }
  }

  @override
  void dispose() {
    _codeFocusNode.dispose();
    _nameFocusNode.dispose();
    _vatRateFocusNode.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _barcodeController.dispose();
    _vatRateController.dispose();
    _alertQuantityController.dispose();
    _purchasePriceController.dispose();
    _purchasePriceFocusNode.dispose();
    for (var price in _salesPrices) {
      (price['price'] as TextEditingController).dispose();
      // focusNode is tracked in _salesPriceFocusNodes and disposed below
    }
    for (final node in _salesPriceFocusNodes) {
      node.dispose();
    }
    for (var attr in _attributes) {
      (attr['name'] as TextEditingController).dispose();
    }
    // Reçete kontrolcüleri
    _recipeCodeController.dispose();
    _recipeNameController.dispose();
    _recipeQuantityController.dispose();
    _recipeUnitController.dispose();
    _recipeCodeFocusNode.dispose();
    _recipeNameFocusNode.dispose();
    _recipeQuantityFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _addSalesPriceRow() {
    setState(() {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      _attachPriceFormatter(focusNode, controller);
      _salesPriceFocusNodes.add(focusNode);
      String currency = _genelAyarlar.varsayilanParaBirimi;
      if (currency == 'TL') currency = 'TRY';
      _salesPrices.add({
        'price': controller,
        'currency': currency,
        'vatStatus': _genelAyarlar.varsayilanKdvDurumu,
        'focusNode': focusNode,
      });
    });
  }

  void _removeSalesPriceRow(int index) {
    if (_salesPrices.length > 1) {
      setState(() {
        (_salesPrices[index]['price'] as TextEditingController).dispose();
        _salesPrices.removeAt(index);
      });
    }
  }

  void _addAttributeRow() {
    setState(() {
      _attributes.add({
        'name': TextEditingController(),
        'color': 0xFF9E9E9E, // Default Grey
      });
    });
  }

  void _removeAttributeRow(int index) {
    setState(() {
      (_attributes[index]['name'] as TextEditingController).dispose();
      _attributes.removeAt(index);
    });
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) {
      MesajYardimcisi.uyariGoster(context, tr('productions.form.images.limit'));
      return;
    }

    try {
      final XTypeGroup typeGroup = XTypeGroup(
        label: tr('common.images'),
        extensions: <String>['jpg', 'png', 'jpeg'],
        uniformTypeIdentifiers: ['public.image'],
      );
      final List<XFile> files = await openFiles(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );

      if (files.isNotEmpty) {
        for (final file in files) {
          if (_selectedImages.length >= 5) break;
          final bytes = await file.readAsBytes();
          final base64Image = base64Encode(bytes);
          setState(() {
            _selectedImages.add(base64Image);
          });
        }
      }
    } catch (e) {
      debugPrint('Resim seçme hatası: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final isDuplicate = await UretimlerVeritabaniServisi().uretimKoduVarMi(
        _codeController.text,
        haricId: widget.urun?.id,
      );

      if (isDuplicate) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _codeError = tr('common.code_exists_error');
        });
        return;
      }

      // Prepare attributes as JSON string
      final attributesJson = jsonEncode(
        _attributes.map((e) {
          return {
            'name': (e['name'] as TextEditingController).text,
            'color': e['color'],
          };
        }).toList(),
      );

      // Prepare sales prices
      double price1 = 0;
      double price2 = 0;
      double price3 = 0;

      final prefs = await SharedPreferences.getInstance();
      final currentUser = prefs.getString('current_username') ?? 'Sistem';

      if (_salesPrices.isNotEmpty) {
        price1 = FormatYardimcisi.parseDouble(
          (_salesPrices[0]['price'] as TextEditingController).text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        );
      }
      if (_salesPrices.length > 1) {
        price2 = FormatYardimcisi.parseDouble(
          (_salesPrices[1]['price'] as TextEditingController).text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        );
      }
      if (_salesPrices.length > 2) {
        price3 = FormatYardimcisi.parseDouble(
          (_salesPrices[2]['price'] as TextEditingController).text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        );
      }

      final urun = UretimModel(
        id: 0, // New product
        kod: _codeController.text,
        ad: _nameController.text,
        birim: _selectedUnit ?? 'Adet',
        alisFiyati: FormatYardimcisi.parseDouble(
          _purchasePriceController.text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        ),
        satisFiyati1: price1,
        satisFiyati2: price2,
        satisFiyati3: price3,
        kdvOrani: FormatYardimcisi.parseDouble(
          _vatRateController.text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        ),
        stok: 0,
        erkenUyariMiktari: FormatYardimcisi.parseDouble(
          _alertQuantityController.text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        ),
        grubu: _selectedGroup ?? '',
        ozellikler: attributesJson,
        barkod: _barcodeController.text,
        kullanici: currentUser,
        resimler: _selectedImages,
        aktifMi: true,
      );

      if (widget.urun != null) {
        // Update existing product
        final updatedUrun = urun.copyWith(id: widget.urun!.id);
        await UretimlerVeritabaniServisi().uretimGuncelle(updatedUrun);

        // Reçete Güncelle
        if (_recipeItems.isNotEmpty) {
          final recipeList = _recipeItems.map((item) => item.toMap()).toList();
          await UretimlerVeritabaniServisi().receteKaydet(
            widget.urun!.id,
            recipeList,
          );
        } else {
          // Reçete boşsa eski reçeteyi sil
          await UretimlerVeritabaniServisi().receteSil(widget.urun!.id);
        }
      } else {
        // Add new product
        final newId = await UretimlerVeritabaniServisi().uretimEkle(
          urun,
          createdBy: currentUser,
        );

        // Reçete Kaydet
        if (_recipeItems.isNotEmpty && newId > 0) {
          final recipeList = _recipeItems.map((item) => item.toMap()).toList();
          await UretimlerVeritabaniServisi().receteKaydet(newId, recipeList);
        }
      }

      if (!mounted) return;

      MesajYardimcisi.basariGoster(
        context,
        widget.urun != null
            ? tr('common.updated_successfully')
            : tr('common.saved_successfully'),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      setState(() => _isLoading = false);
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  void _handleClear() {
    _formKey.currentState?.reset();
    _codeController.clear();
    _nameController.clear();
    _barcodeController.clear();
    _vatRateController.clear();
    _alertQuantityController.clear();
    _purchasePriceController.clear();

    setState(() {
      _codeError = null;
      final defaultUnit = _genelAyarlar.urunBirimleri.firstWhere(
        (e) => e['isDefault'] == true,
        orElse: () => _genelAyarlar.urunBirimleri.isNotEmpty
            ? _genelAyarlar.urunBirimleri.first
            : {'name': ''},
      );
      final defaultUnitName = (defaultUnit['name'] ?? '').toString().trim();
      _selectedUnit = defaultUnitName.isNotEmpty
          ? defaultUnitName
          : (_units.isNotEmpty ? _units.first : null);
      _selectedGroup = null;
      String currency = _genelAyarlar.varsayilanParaBirimi;
      if (currency == 'TL') currency = 'TRY';
      _purchaseCurrency = currency;
      _purchaseVatStatus = _genelAyarlar.varsayilanKdvDurumu;
      _salesPricesOptionsTouched = false;

      // Clear dynamic lists
      for (var price in _salesPrices) {
        (price['price'] as TextEditingController).dispose();
      }
      _salesPrices.clear();
      _addSalesPriceRow();

      for (var attr in _attributes) {
        (attr['name'] as TextEditingController).dispose();
      }
      _attributes.clear();

      _selectedImages.clear();

      // Reçete temizle
      _recipeItems.clear();
      _selectedRecipeIndices.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final bool isMobile = media.size.width < 760;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.f4): _handleClear,
        const SingleActivator(LogicalKeyboardKey.f9): _pickImages,
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_isLoading) _handleSave();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_isLoading) _handleSave();
        },
      },
      child: Focus(
        autofocus: true,
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
              widget.urun != null
                  ? tr('productions.edit')
                  : tr('productions.add'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 21,
              ),
            ),
            centerTitle: false,
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? double.infinity : 850,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(theme),
                            SizedBox(height: isMobile ? 20 : 32),
                            _buildSection(
                              theme,
                              title: tr('productions.form.section.general'),
                              child: _buildBasicInfoSection(theme),
                              icon: Icons.info_rounded,
                              color: Colors.blue.shade700,
                            ),
                            SizedBox(height: isMobile ? 16 : 24),
                            _buildSection(
                              theme,
                              title: tr('productions.form.section.pricing'),
                              child: _buildPricesSection(theme),
                              icon: Icons.monetization_on_rounded,
                              color: Colors.green.shade700,
                            ),
                            SizedBox(height: isMobile ? 16 : 24),
                            _buildSection(
                              theme,
                              title: tr('productions.recipe.title'),
                              child: _buildRecipeSection(theme),
                              icon: Icons.receipt_long_rounded,
                              color: Colors.deepOrange.shade700,
                            ),
                            SizedBox(height: isMobile ? 16 : 24),
                            _buildSection(
                              theme,
                              title: tr('productions.table.features'),
                              child: _buildAttributesSection(theme),
                              icon: Icons.list_alt_rounded,
                              color: Colors.purple.shade700,
                            ),
                            SizedBox(height: isMobile ? 16 : 24),
                            _buildSection(
                              theme,
                              title: tr('productions.form.section.images'),
                              child: _buildImagesSection(theme),
                              icon: Icons.image_rounded,
                              color: Colors.teal.shade700,
                            ),
                            SizedBox(height: isMobile ? 20 : 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: isMobile
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
                    constraints: BoxConstraints(maxWidth: isMobile ? 760 : 850),
                    child: _buildActionButtons(theme, isCompact: isMobile),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final bool isMobile = MediaQuery.of(context).size.width < 760;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 10 : 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.add_box_rounded,
            color: theme.colorScheme.primary,
            size: isMobile ? 24 : 28,
          ),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.urun != null
                    ? tr('productions.edit')
                    : tr('productions.add'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontSize: isMobile ? 20 : 23,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.urun != null
                    ? tr('productions.edit.subtitle')
                    : tr('productions.add.subtitle'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: isMobile ? 13 : 16,
                ),
              ),
            ],
          ),
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
  }) {
    final bool isMobile = MediaQuery.of(context).size.width < 760;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: isMobile ? 12 : 20,
            offset: Offset(0, isMobile ? 4 : 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: isMobile ? 18 : 20),
              ),
              SizedBox(width: isMobile ? 10 : 16),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontSize: isMobile ? 16 : 21,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 14 : 24),
          child,
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(ThemeData theme) {
    final requiredColor = Colors.red.shade700;
    final optionalColor = Colors.blue.shade700;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Column(
          children: [
            _buildRow(isWide, [
              _buildTextField(
                controller: _codeController,
                label: tr('productions.form.code.label'),
                hint: tr('productions.form.code.hint'),
                isRequired: true,
                color: requiredColor,
                focusNode: _codeFocusNode,
                errorText: _codeError,
                onChanged: (val) {
                  if (_codeError != null) {
                    setState(() => _codeError = null);
                  }
                },
              ),
              _buildTextField(
                controller: _nameController,
                label: tr('productions.form.name.label'),
                hint: tr('productions.form.name.hint'),
                isRequired: true,
                color: requiredColor,
                focusNode: _nameFocusNode,
              ),
            ]),
            const SizedBox(height: 16),
            _buildRow(isWide, [
              _buildDropdown(
                value: _selectedUnit,
                label: tr('productions.form.unit.label'),
                hint: tr('productions.form.unit.hint'),
                items: _units,
                onChanged: (val) => setState(() => _selectedUnit = val),
                isRequired: true,
                color: requiredColor,
              ),
              _buildTextField(
                controller: _vatRateController,
                label: tr('productions.form.vat.label'),
                isNumeric: true,
                isRequired: true,
                color: requiredColor,
                focusNode: _vatRateFocusNode,
                maxDecimalDigits: 2,
              ),
            ]),
            const SizedBox(height: 16),
            _buildRow(isWide, [
              _buildTextField(
                controller: _barcodeController,
                label: tr('productions.form.barcode.label'),
                hint: tr('productions.form.barcode.hint'),
                color: optionalColor,
              ),
              _buildDropdown(
                value: _selectedGroup,
                label: tr('productions.form.group.label'),
                hint: tr('productions.form.group.hint'),
                items: _groups,
                onChanged: (val) => setState(() => _selectedGroup = val),
                color: optionalColor,
              ),
            ]),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _alertQuantityController,
              label: tr('productions.form.alert_qty.label'),
              isNumeric: true,
              color: optionalColor,
              maxDecimalDigits: _genelAyarlar.miktarOndalik,
            ),
          ],
        );
      },
    );
  }

  Widget _buildPricesSection(ThemeData theme) {
    final color = Colors.green.shade700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('productions.form.manual_cost_price.label'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tr('productions.form.manual_cost_price.help'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.withValues(alpha: 0.8),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildPriceRow(
          controller: _purchasePriceController,
          currency: _purchaseCurrency,
          vatStatus: _purchaseVatStatus,
          onCurrencyChanged: (val) => setState(() => _purchaseCurrency = val!),
          onVatStatusChanged: (val) =>
              setState(() => _purchaseVatStatus = val!),
          color: color,
          focusNode: _purchasePriceFocusNode,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tr('productions.form.sales_price_item'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 18,
              ),
            ),
            TextButton.icon(
              onPressed: _addSalesPriceRow,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(
                tr('productions.form.sales_price_add'),
                style: const TextStyle(fontSize: 17),
              ),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._salesPrices.asMap().entries.map((entry) {
          final index = entry.key;
          final price = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildPriceRow(
                    controller: price['price'] as TextEditingController,
                    currency: price['currency'] as String,
                    vatStatus: price['vatStatus'] as String,
                    onCurrencyChanged: (val) => setState(() {
                      _salesPricesOptionsTouched = true;
                      price['currency'] = val!;
                    }),
                    onVatStatusChanged: (val) => setState(() {
                      _salesPricesOptionsTouched = true;
                      price['vatStatus'] = val!;
                    }),
                    labelOverride: tr('productions.form.sales_price_item'),
                    color: color,
                    focusNode: price['focusNode'] as FocusNode,
                  ),
                ),
                if (_salesPrices.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                    onPressed: () => _removeSalesPriceRow(index),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAttributesSection(ThemeData theme) {
    final color = Colors.purple.shade700;

    // Professional Color Palette (16 colors)
    final List<Color> palette = [
      const Color(0xFFEF5350), // Red 400
      const Color(0xFFAB47BC), // Purple 400
      const Color(0xFF5C6BC0), // Indigo 400
      const Color(0xFF42A5F5), // Blue 400
      const Color(0xFF26C6DA), // Cyan 400
      const Color(0xFF26A69A), // Teal 400
      const Color(0xFF66BB6A), // Green 400
      const Color(0xFF9CCC65), // Light Green 400
      const Color(0xFFFFEE58), // Yellow 400
      const Color(0xFFFFA726), // Orange 400
      const Color(0xFFFF7043), // Deep Orange 400
      const Color(0xFF8D6E63), // Brown 400
      const Color(0xFFBDBDBD), // Grey 400
      const Color(0xFF78909C), // Blue Grey 400
      const Color(0xFF000000), // Black
    ];

    return Column(
      children: [
        if (_attributes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              tr('productions.form.attribute.empty_hint'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
                fontSize: 18,
              ),
            ),
          ),
        ..._attributes.asMap().entries.map((entry) {
          final index = entry.key;
          final attr = entry.value;
          final controller = attr['name'] as TextEditingController;
          final int colorValue = attr['color'] as int;
          final Color currentColor = Color(colorValue);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Color Picker Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 12),
                  child: InkWell(
                    mouseCursor: WidgetStateMouseCursor.clickable,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            tr('productions.form.attribute.select_color'),
                            style: const TextStyle(fontSize: 20),
                          ),
                          content: SizedBox(
                            width: 300,
                            child: GridView.builder(
                              shrinkWrap: true,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount: palette.length,
                              itemBuilder: (context, i) {
                                final pColor = palette[i];
                                return InkWell(
                                  mouseCursor: WidgetStateMouseCursor.clickable,
                                  onTap: () {
                                    setState(() {
                                      attr['color'] = pColor.toARGB32();
                                    });
                                    Navigator.of(context).pop();
                                  },
                                  borderRadius: BorderRadius.circular(50),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: pColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: currentColor == pColor
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 20,
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: currentColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: currentColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Attribute Name Input
                Expanded(
                  child: _buildTextField(
                    controller: controller,
                    label: tr('productions.form.attribute.name'),
                    hint: tr('common.example.features'),
                    color: color,
                  ),
                ),

                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeAttributeRow(index),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addAttributeRow,
            icon: const Icon(Icons.add_circle_outline, size: 19),
            label: Text(
              tr('productions.form.feature_add'),
              style: const TextStyle(fontSize: 18),
            ),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagesSection(ThemeData theme) {
    final color = Colors.teal.shade700;
    final isFull = _selectedImages.length >= 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isFull)
          InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 37,
                    color: color.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tr('productions.form.image.dropzone_hint'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: color.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr('common.key.f9'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedImages.length}/5',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color.withValues(alpha: 0.5),
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              // final path = _selectedImages[index]; // Unused variable removed
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey.shade200,
                        child: Image.memory(
                          base64Decode(_selectedImages[index]),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.broken_image,
                              size: 42,
                              color: Colors.grey,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      mouseCursor: WidgetStateMouseCursor.clickable,
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
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
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme, {bool isCompact = false}) {
    if (isCompact) {
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
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA4335),
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
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _handleClear,
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
            backgroundColor: const Color(0xFFEA4335),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
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
    Widget? suffix,
    String? errorText,
    int? maxDecimalDigits,
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
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
          inputFormatters: isNumeric
              ? [
                  CurrencyInputFormatter(
                    binlik: _genelAyarlar.binlikAyiraci,
                    ondalik: _genelAyarlar.ondalikAyiraci,
                    maxDecimalDigits: maxDecimalDigits,
                  ),
                  LengthLimitingTextInputFormatter(20),
                ]
              : null,
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return tr('validation.required');
            }
            return null;
          },
          decoration: InputDecoration(
            errorText: errorText,
            hintText: hint,
            suffixIcon: suffix,
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
          mouseCursor: WidgetStateMouseCursor.clickable,
          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
          key: ValueKey(value),
          initialValue: value,
          decoration: InputDecoration(
            hintText: hint,
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

  Widget _buildPriceRow({
    required TextEditingController controller,
    required String currency,
    required String vatStatus,
    required ValueChanged<String?> onCurrencyChanged,
    required ValueChanged<String?> onVatStatusChanged,
    Color? color,
    String? labelOverride,
    FocusNode? focusNode,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          return Column(
            children: [
              _buildTextField(
                controller: controller,
                label:
                    labelOverride ??
                    tr('productions.form.purchase_price.label'),
                isNumeric: true,
                color: color,
                focusNode: focusNode,
                maxDecimalDigits: _genelAyarlar.fiyatOndalik,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      value: currency,
                      label: tr('common.currency'),
                      items: ['TRY', 'USD', 'EUR'],
                      onChanged: onCurrencyChanged,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      value: vatStatus,
                      label: tr('common.vat_status'),
                      items: ['excluded', 'included'],
                      itemLabels: {
                        'excluded': tr('common.vat_excluded'),
                        'included': tr('common.vat_included'),
                      },
                      onChanged: onVatStatusChanged,
                      color: color,
                    ),
                  ),
                ],
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
                controller: controller,
                label:
                    labelOverride ??
                    tr('productions.form.purchase_price.label'),
                isNumeric: true,
                color: color,
                focusNode: focusNode,
                maxDecimalDigits: _genelAyarlar.fiyatOndalik,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: _buildDropdown(
                value: currency,
                label: tr('common.currency'),
                items: ['TRY', 'USD', 'EUR'],
                onChanged: onCurrencyChanged,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildDropdown(
                value: vatStatus,
                label: tr('common.vat_status'),
                items: ['excluded', 'included'],
                itemLabels: {
                  'excluded': tr('common.vat_excluded'),
                  'included': tr('common.vat_included'),
                },
                onChanged: onVatStatusChanged,
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }

  // ====== REÇETE (BOM - Bill of Materials) BÖLÜMÜ ======

  Widget _buildProductAutocompleteField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool isRequired,
    required bool isCodeField,
    String? searchHint,
    Widget? suffixIcon,
    VoidCallback? onExternalSubmit,
  }) {
    final effectiveColor = isRequired ? Colors.red.shade700 : _labelColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              isRequired && !label.endsWith('*') ? '$label *' : label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: effectiveColor,
                fontSize: 14,
              ),
            ),
            if (searchHint != null)
              Text(
                searchHint,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
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
                      final results = await UrunlerVeritabaniServisi()
                          .urunleriGetir(
                            aramaTerimi: textEditingValue.text,
                            sayfaBasinaKayit: 10,
                          );
                      if (!completer.isCompleted) completer.complete(results);
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
                // Populate fields
                setState(() {
                  _recipeCodeController.text = selection.kod;
                  _recipeNameController.text = selection.ad;
                  _recipeUnitController.text = selection.birim;
                  // Focus next field
                  _recipeQuantityFocusNode.requestFocus();
                });
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

                              final title = option.ad;
                              String subtitle = 'Kod: ${option.kod}';

                              final term = controller.text.toLowerCase();
                              if (option.barkod.isNotEmpty &&
                                  option.barkod.contains(term)) {
                                subtitle += ' • Barkod: ${option.barkod}';
                              }

                              // Stock styling
                              final bool hasStock = option.stok > 0;
                              final Color stockBgColor = hasStock
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE);
                              final Color stockTextColor = hasStock
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828);

                              return InkWell(
                                mouseCursor: WidgetStateMouseCursor.clickable,
                                onTap: () => onSelected(option),
                                hoverColor: const Color(0xFFF5F7FA),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Color(0xFF202124),
                                        ),
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
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  hasStock
                                                      ? Icons
                                                            .check_circle_outline
                                                      : Icons.error_outline,
                                                  size: 14,
                                                  color: stockTextColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${FormatYardimcisi.sayiFormatla(option.stok)} ${option.birim}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: stockTextColor,
                                                  ),
                                                ),
                                              ],
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
                    return SizedBox(
                      height: 52,
                      child: TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                        decoration: InputDecoration(
                          suffixIcon: suffixIcon,
                          prefixIcon: isCodeField
                              ? const Icon(
                                  Icons.qr_code,
                                  size: 20,
                                  color: _hintColor,
                                )
                              : const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 20,
                                  color: _hintColor,
                                ),
                          hintStyle: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.3),
                            fontSize: 16,
                          ),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: isRequired
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : _borderColor,
                            ),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: isRequired
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : _borderColor,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: isRequired ? Colors.red : _primaryColor,
                              width: 2,
                            ),
                          ),
                          errorBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                        ),
                        onFieldSubmitted: (String value) {
                          onFieldSubmitted();
                          if (onExternalSubmit != null) {
                            onExternalSubmit();
                          }
                        },
                      ),
                    );
                  },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecipeSection(ThemeData theme) {
    final color = Colors.deepOrange.shade700;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideForm = constraints.maxWidth > 700;
        final bool isWideActionBar = constraints.maxWidth > 520;
        final bool useDesktopTable = constraints.maxWidth > 760;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _recipeFormKey,
              child: Column(
                children: [
                  if (isWideForm)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildProductAutocompleteField(
                            controller: _recipeCodeController,
                            focusNode: _recipeCodeFocusNode,
                            label: tr('orders.field.find_product'),
                            searchHint: tr(
                              'common.search_fields.code_name_barcode',
                            ),
                            isRequired: true,
                            isCodeField: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: _searchProduct,
                            ),
                            onExternalSubmit: _searchProduct,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: _buildProductAutocompleteField(
                            controller: _recipeNameController,
                            focusNode: _recipeNameFocusNode,
                            label: tr('productions.recipe.product_name'),
                            searchHint: tr('common.search_fields.name_code'),
                            isRequired: true,
                            isCodeField: false,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: _searchProduct,
                            ),
                            onExternalSubmit: _searchProduct,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildProductAutocompleteField(
                          controller: _recipeCodeController,
                          focusNode: _recipeCodeFocusNode,
                          label: tr('orders.field.find_product'),
                          searchHint: tr(
                            'common.search_fields.code_name_barcode',
                          ),
                          isRequired: true,
                          isCodeField: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _searchProduct,
                          ),
                          onExternalSubmit: _searchProduct,
                        ),
                        const SizedBox(height: 14),
                        _buildProductAutocompleteField(
                          controller: _recipeNameController,
                          focusNode: _recipeNameFocusNode,
                          label: tr('productions.recipe.product_name'),
                          searchHint: tr('common.search_fields.name_code'),
                          isRequired: true,
                          isCodeField: false,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _searchProduct,
                          ),
                          onExternalSubmit: _searchProduct,
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (isWideForm)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _recipeQuantityController,
                            label: tr('productions.recipe.quantity'),
                            isNumeric: true,
                            color: color,
                            maxDecimalDigits: _genelAyarlar.miktarOndalik,
                            focusNode: _recipeQuantityFocusNode,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _recipeUnitController,
                            label: tr('productions.form.unit.label'),
                            color: color,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildTextField(
                          controller: _recipeQuantityController,
                          label: tr('productions.recipe.quantity'),
                          isNumeric: true,
                          color: color,
                          maxDecimalDigits: _genelAyarlar.miktarOndalik,
                          focusNode: _recipeQuantityFocusNode,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _recipeUnitController,
                          label: tr('productions.form.unit.label'),
                          color: color,
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: isWideForm
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _addRecipeItem,
                      icon: const Icon(Icons.add),
                      label: Text(tr('productions.recipe.add_product')),
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        padding: EdgeInsets.symmetric(
                          horizontal: isWideForm ? 24 : 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (isWideActionBar)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_selectedRecipeIndices.isNotEmpty)
                    TextButton.icon(
                      onPressed: _deleteSelectedRecipes,
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 18,
                      ),
                      label: Text(
                        tr('productions.recipe.delete_selected'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _recipeItems.isEmpty ? null : _deleteAllRecipes,
                    icon: Icon(
                      Icons.delete_sweep,
                      size: 18,
                      color: _recipeItems.isEmpty ? Colors.grey : color,
                    ),
                    label: Text(
                      tr('productions.recipe.delete_all'),
                      style: TextStyle(
                        color: _recipeItems.isEmpty ? Colors.grey : color,
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_selectedRecipeIndices.isNotEmpty)
                    TextButton.icon(
                      onPressed: _deleteSelectedRecipes,
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 18,
                      ),
                      label: Text(
                        tr('productions.recipe.delete_selected'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _recipeItems.isEmpty ? null : _deleteAllRecipes,
                    icon: Icon(
                      Icons.delete_sweep,
                      size: 18,
                      color: _recipeItems.isEmpty ? Colors.grey : color,
                    ),
                    label: Text(
                      tr('productions.recipe.delete_all'),
                      style: TextStyle(
                        color: _recipeItems.isEmpty ? Colors.grey : color,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            if (useDesktopTable)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      color.withValues(alpha: 0.05),
                    ),
                    columnSpacing: 32,
                    horizontalMargin: 16,
                    columns: [
                      DataColumn(
                        label: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            tr('productions.recipe.product_code'),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            tr('productions.recipe.product_name'),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            tr('productions.recipe.quantity'),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        numeric: true,
                      ),
                      DataColumn(
                        label: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            tr('productions.form.unit.label'),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                    rows: List.generate(_recipeItems.length, (index) {
                      final item = _recipeItems[index];
                      return DataRow(
                        selected: _selectedRecipeIndices.contains(index),
                        onSelectChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _selectedRecipeIndices.add(index);
                            } else {
                              _selectedRecipeIndices.remove(index);
                            }
                          });
                        },
                        cells: [
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                item.kod,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                item.ad,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                FormatYardimcisi.sayiFormatla(item.miktar),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                item.birim,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              )
            else
              _buildMobileRecipeList(color),
            if (_recipeItems.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    tr('productions.recipe.empty'),
                    style: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMobileRecipeList(Color color) {
    if (_recipeItems.isEmpty) return const SizedBox.shrink();

    return Column(
      children: List.generate(_recipeItems.length, (index) {
        final item = _recipeItems[index];
        final bool isSelected = _selectedRecipeIndices.contains(index);

        return MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedRecipeIndices.remove(index);
              } else {
                _selectedRecipeIndices.add(index);
              }
            });
          },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.06) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.45)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedRecipeIndices.add(index);
                        } else {
                          _selectedRecipeIndices.remove(index);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.ad,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.kod,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF606368),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${FormatYardimcisi.sayiFormatla(item.miktar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.miktarOndalik)} ${item.birim}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
      }),
    );
  }

  void _addRecipeItem() {
    final code = _recipeCodeController.text.trim();
    final name = _recipeNameController.text.trim();
    final unit = _recipeUnitController.text.trim();
    final quantityText = _recipeQuantityController.text.trim();

    if (code.isEmpty || name.isEmpty || quantityText.isEmpty) {
      MesajYardimcisi.uyariGoster(
        context,
        tr('productions.recipe.fill_fields'),
      );
      return;
    }

    final quantity = FormatYardimcisi.parseDouble(
      quantityText,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
    );

    setState(() {
      _recipeItems.add(
        ReceteItem(kod: code, ad: name, birim: unit, miktar: quantity),
      );
      _recipeCodeController.clear();
      _recipeNameController.clear();
      _recipeQuantityController.clear();
      _recipeUnitController.clear();
    });
  }

  void _deleteSelectedRecipes() {
    setState(() {
      final indices = _selectedRecipeIndices.toList()
        ..sort((a, b) => b.compareTo(a));
      for (final index in indices) {
        if (index < _recipeItems.length) {
          _recipeItems.removeAt(index);
        }
      }
      _selectedRecipeIndices.clear();
    });
  }

  void _deleteAllRecipes() {
    setState(() {
      _recipeItems.clear();
      _selectedRecipeIndices.clear();
    });
  }

  Future<void> _searchProduct() async {
    // Ürün seçim dialog'u göster - dialog kendi içinde arama yapacak
    final selected = await showDialog<UrunModel>(
      context: context,
      builder: (context) => const _ProductSelectionDialog(),
    );

    if (selected != null && mounted) {
      setState(() {
        _recipeCodeController.text = selected.kod;
        _recipeNameController.text = selected.ad;
        _recipeUnitController.text = selected.birim;
      });
    }
  }
}

/// Ürün Seçim Dialog'u - Sevkiyat sayfasıyla aynı tasarım
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
    // Auto-search initially
    _searchProducts('');
    // Auto-focus after build
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
      _searchProducts(query);
    });
  }

  Future<void> _searchProducts(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await UrunlerVeritabaniServisi().urunleriGetir(
        aramaTerimi: query,
        sayfaBasinaKayit: 50,
        sortAscending: true,
        sortBy: 'ad',
        aktifMi: true,
      );
      if (mounted) {
        setState(() {
          _products = results;
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
    final media = MediaQuery.of(context);
    final bool isMobile = media.size.width < 760;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dialogRadius),
      ),
      child: Container(
        width: isMobile ? double.infinity : 720,
        constraints: BoxConstraints(
          maxHeight: isMobile ? media.size.height * 0.88 : 680,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(dialogRadius),
        ),
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 28,
          isMobile ? 16 : 24,
          isMobile ? 16 : 28,
          isMobile ? 16 : 22,
        ),
        child: Column(
          children: [
            // Header: Title + Close Button
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
                          fontSize: isMobile ? 19 : 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('productions.recipe.search_subtitle'),
                        maxLines: isMobile ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF606368),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isMobile)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      tr('common.esc'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9AA0A6),
                      ),
                    ),
                  ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(
                      Icons.close,
                      size: isMobile ? 20 : 22,
                      color: const Color(0xFF3C4043),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: tr('common.close'),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 24),

            // Search Input
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
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF202124),
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
            SizedBox(height: isMobile ? 14 : 20),

            // Product List
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
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return InkWell(
                          mouseCursor: WidgetStateMouseCursor.clickable,
                          onTap: () => Navigator.pop(context, product),
                          hoverColor: const Color(0xFFF5F7FA),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 10 : 12,
                              horizontal: isMobile ? 4 : 8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: isMobile ? 36 : 40,
                                  height: isMobile ? 36 : 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.inventory_2,
                                    color: _primaryColor,
                                    size: isMobile ? 18 : 20,
                                  ),
                                ),
                                SizedBox(width: isMobile ? 10 : 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.ad,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: isMobile ? 14 : 15,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF202124),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        product.kod,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF606368),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: product.stok > 0
                                                  ? const Color(0xFFE6F4EA)
                                                  : const Color(0xFFFCE8E6),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${product.stok.toStringAsFixed(0)} ${product.birim}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: product.stok > 0
                                                    ? const Color(0xFF1E7E34)
                                                    : const Color(0xFFC5221F),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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
    );
  }
}
