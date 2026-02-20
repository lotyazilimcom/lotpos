import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/mesaj_yardimcisi.dart';
import '../../../servisler/urunler_veritabani_servisi.dart';
import '../../../servisler/ayarlar_veritabani_servisi.dart';
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import 'modeller/urun_model.dart';
import 'modeller/cihaz_model.dart';
import '../../../servisler/depolar_veritabani_servisi.dart';
import '../depolar/modeller/depo_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../bilesenler/tek_tarih_secici_dialog.dart';

class UrunEkleSayfasi extends StatefulWidget {
  const UrunEkleSayfasi({
    super.key,
    this.urun,
    this.focusOnStock = false,
    this.initialCode,
    this.initialBarcode,
  });

  final UrunModel? urun;
  final bool focusOnStock;
  final String? initialCode;
  final String? initialBarcode;

  @override
  State<UrunEkleSayfasi> createState() => _UrunEkleSayfasiState();
}

class _UrunEkleSayfasiState extends State<UrunEkleSayfasi> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();
  List<String> _units = ['Adet', 'Kg', 'Lt', 'Mt'];
  List<String> _groups = [tr('common.general')];

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

  // Stock
  final _currentStockController = TextEditingController();
  final _unitCostController = TextEditingController();
  int? _selectedWarehouseId;
  List<DepoModel> _warehouses = [];
  String _stockUnitCostCurrency = 'TRY';
  String _stockUnitCostVatStatus = 'excluded';

  // Attributes
  final List<Map<String, dynamic>> _attributes = [];

  // Images
  final List<String> _selectedImages = [];

  // Devices (Cihaz Listesi)
  final List<CihazModel> _devices = [];
  String _deviceIdentityType = 'IMEI';
  String _deviceCondition = 'Sıfır';
  final _deviceIdentityValueController = TextEditingController();
  final _deviceColorController = TextEditingController();
  final _deviceCapacityController = TextEditingController();
  DateTime? _deviceWarrantyEndDate;
  bool _deviceHasBox = false;
  bool _deviceHasInvoice = false;
  bool _deviceHasOriginalCharger = false;

  // Focus Nodes
  late FocusNode _codeFocusNode;
  late FocusNode _nameFocusNode;
  late FocusNode _vatRateFocusNode;
  late FocusNode _currentStockFocusNode;
  late FocusNode _purchasePriceFocusNode;
  late FocusNode _unitCostFocusNode;
  final List<FocusNode> _salesPriceFocusNodes = [];

  @override
  void initState() {
    super.initState();
    _codeFocusNode = FocusNode();
    _nameFocusNode = FocusNode();
    _vatRateFocusNode = FocusNode();
    _currentStockFocusNode = FocusNode();
    _purchasePriceFocusNode = FocusNode();
    _unitCostFocusNode = FocusNode();

    _attachPriceFormatter(_purchasePriceFocusNode, _purchasePriceController);
    _attachPriceFormatter(_unitCostFocusNode, _unitCostController);
    _attachVatFormatter(_vatRateFocusNode, _vatRateController);
    _loadSettings();

    if (widget.urun != null) {
      _populateForm();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.focusOnStock) {
          _currentStockFocusNode.requestFocus();
        } else {
          _codeFocusNode.requestFocus();
        }
      });
    } else {
      final initialCode = widget.initialCode?.trim();
      final initialBarcode = widget.initialBarcode?.trim();
      if (initialCode != null && initialCode.isNotEmpty) {
        _codeController.text = initialCode;
      }
      if (initialBarcode != null && initialBarcode.isNotEmpty) {
        _barcodeController.text = initialBarcode;
      }

      // Add one default sales price row for new product
      _addSalesPriceRow();
      _requestInitialFocusForNewProduct();
    }
  }

  void _requestInitialFocusForNewProduct({bool onlyIfUnfocused = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.urun != null) return;

      final targetNode = _genelAyarlar.otoStokKodu
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
    _currentStockController.text = FormatYardimcisi.sayiFormatla(
      urun.stok,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.miktarOndalik,
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

    // Devices
    _fetchDevices();

    // Unit Cost (Birim Maliyet) - This is not directly in UrunModel but used for initial stock
    // Since we are editing, we might not need to show initial stock cost if stock is 0 or not being updated via this form
    // But if we want to show it, we would need to fetch it or just leave it empty/default.
    // However, the user mentioned "birim maliyet gelmedi" (unit cost didn't come).
    // Assuming 'alisFiyati' might be what they refer to as cost, or we just default it.
    // If it's about the 'Birim Maliyet' field in the Stock section:
    _unitCostController.text = FormatYardimcisi.sayiFormatla(
      urun.alisFiyati,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.fiyatOndalik,
    );
  }

  Future<void> _fetchDevices() async {
    if (widget.urun == null) return;
    try {
      final devices = await UrunlerVeritabaniServisi().cihazlariGetir(
        widget.urun!.id,
      );
      if (mounted) {
        setState(() {
          _devices.clear();
          _devices.addAll(devices);
        });
      }
    } catch (e) {
      debugPrint('Cihazlar getirilirken hata: $e');
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

        // Seçili değerlerin listelerde olduğundan emin ol (Crash önleyici)
        final unit = _selectedUnit?.trim();
        if (unit != null && unit.isNotEmpty && !_units.contains(unit)) {
          _units.add(unit);
        }

        final group = _selectedGroup?.trim();
        if (group != null && group.isNotEmpty && !_groups.contains(group)) {
          _groups.add(group);
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
        _stockUnitCostCurrency = currency;

        // Varsayılan KDV durumunu uygula
        _purchaseVatStatus = settings.varsayilanKdvDurumu;
        _stockUnitCostVatStatus = settings.varsayilanKdvDurumu;

        if (!_salesPricesOptionsTouched) {
          for (final price in _salesPrices) {
            price['currency'] = currency;
            price['vatStatus'] = settings.varsayilanKdvDurumu;
          }
        }
      });

      // Kodları oluştur
      // Generate codes only if adding new product
      if (widget.urun == null) {
        await _generateCodes();
        _requestInitialFocusForNewProduct(onlyIfUnfocused: true);
      }

      // Depoları getir
      await _fetchWarehouses();
    } catch (e) {
      debugPrint('Ayarlar yüklenirken hata: $e');
    }
  }

  Future<void> _fetchWarehouses() async {
    try {
      final warehouses = await DepolarVeritabaniServisi().tumDepolariGetir();
      if (mounted) {
        setState(() {
          _warehouses = warehouses;
          if (_warehouses.isNotEmpty) {
            _selectedWarehouseId = _warehouses.first.id;
          }
        });
      }
    } catch (e) {
      debugPrint('Depolar yüklenirken hata: $e');
    }
  }

  Future<void> _generateCodes() async {
    try {
      final service = UrunlerVeritabaniServisi();

      final shouldGenerateCode =
          _genelAyarlar.otoStokKodu && _codeController.text.trim().isEmpty;
      final shouldGenerateBarcode =
          _genelAyarlar.otoStokBarkodu &&
          _barcodeController.text.trim().isEmpty;
      if (!shouldGenerateCode && !shouldGenerateBarcode) return;

      // Kod ve barkodu aynı anda başlat; ama kodu barkodu beklemeden UI'ya yaz.
      final lastCodeFuture = shouldGenerateCode
          ? service.sonUrunKoduGetir()
          : null;
      final lastBarcodeFuture = shouldGenerateBarcode
          ? service.sonBarkodGetir()
          : null;

      String? lastCode;
      if (lastCodeFuture != null) {
        try {
          lastCode = await lastCodeFuture;
        } catch (e) {
          debugPrint('Ürün kodu alınamadı: $e');
        }
      }

      if (!mounted) return;
      if (shouldGenerateCode && _codeController.text.trim().isEmpty) {
        int nextCode = 1;
        if (lastCode != null) {
          nextCode = (int.tryParse(lastCode) ?? 0) + 1;
        }

        final String newCode = _genelAyarlar.otoStokKoduAlfanumerik
            ? 'STK-${nextCode.toString().padLeft(6, '0')}'
            : nextCode.toString();

        setState(() {
          if (_codeController.text.trim().isEmpty) {
            _codeController.text = newCode;
          }
        });
      }

      String? lastBarcode;
      if (lastBarcodeFuture != null) {
        try {
          lastBarcode = await lastBarcodeFuture;
        } catch (e) {
          debugPrint('Ürün barkodu alınamadı: $e');
        }
      }

      if (!mounted) return;
      if (shouldGenerateBarcode && _barcodeController.text.trim().isEmpty) {
        int nextBarcode = 1;
        if (lastBarcode != null) {
          nextBarcode = (int.tryParse(lastBarcode) ?? 0) + 1;
        }

        final String newBarcode = _genelAyarlar.otoStokBarkoduAlfanumerik
            ? 'STB-${nextBarcode.toString().padLeft(8, '0')}'
            : nextBarcode.toString();

        setState(() {
          if (_barcodeController.text.trim().isEmpty) {
            _barcodeController.text = newBarcode;
          }
        });
      }
    } catch (e) {
      debugPrint('Kod oluşturulurken hata: $e');
    }
  }

  @override
  void dispose() {
    _codeFocusNode.dispose();
    _nameFocusNode.dispose();
    _vatRateFocusNode.dispose();
    _currentStockFocusNode.dispose();
    _purchasePriceFocusNode.dispose();
    _unitCostFocusNode.dispose();
    for (final node in _salesPriceFocusNodes) {
      node.dispose();
    }
    _codeController.dispose();
    _nameController.dispose();
    _barcodeController.dispose();
    _vatRateController.dispose();
    _alertQuantityController.dispose();
    _purchasePriceController.dispose();
    _currentStockController.dispose();
    _unitCostController.dispose();
    for (var price in _salesPrices) {
      (price['price'] as TextEditingController).dispose();
    }
    for (var attr in _attributes) {
      (attr['name'] as TextEditingController).dispose();
    }
    _deviceIdentityValueController.dispose();
    _deviceColorController.dispose();
    _deviceCapacityController.dispose();
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
      MesajYardimcisi.uyariGoster(context, tr('products.form.images.limit'));
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
      final isDuplicate = await UrunlerVeritabaniServisi().urunKoduVarMi(
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

      final stokDegeri = FormatYardimcisi.parseDouble(
        _currentStockController.text,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );

      // Stok girildiyse depo seçimi zorunlu (Açılış Stoğu kaydı için)
      if (widget.urun == null &&
          stokDegeri > 0 &&
          (_selectedWarehouseId == null || _warehouses.isEmpty)) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        MesajYardimcisi.hataGoster(
          context,
          tr('shipment.error.warehouse_required'),
        );
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

      final urun = UrunModel(
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
        stok: stokDegeri,
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
        cihazlar: _devices,
      );

      if (widget.urun != null) {
        // Update existing product
        final updatedUrun = urun.copyWith(id: widget.urun!.id);
        await UrunlerVeritabaniServisi().urunGuncelle(updatedUrun);
      } else {
        // Add new product
        await UrunlerVeritabaniServisi().urunEkle(
          urun,
          initialStockWarehouseId: _selectedWarehouseId,
          initialStockUnitCost: FormatYardimcisi.parseDouble(
            _unitCostController.text,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
          ),
          createdBy: currentUser,
        );
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
    _currentStockController.clear();
    _unitCostController.clear();

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
      _selectedWarehouseId = _warehouses.isNotEmpty
          ? _warehouses.first.id
          : null;
      String currency = _genelAyarlar.varsayilanParaBirimi;
      if (currency == 'TL') currency = 'TRY';
      _purchaseCurrency = currency;
      _purchaseVatStatus = _genelAyarlar.varsayilanKdvDurumu;
      _stockUnitCostCurrency = currency;
      _stockUnitCostVatStatus = _genelAyarlar.varsayilanKdvDurumu;
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

      _devices.clear();
      _deviceIdentityType = 'IMEI';
      _deviceCondition = 'Sıfır';
      _deviceIdentityValueController.clear();
      _deviceColorController.clear();
      _deviceCapacityController.clear();
      _deviceWarrantyEndDate = null;
      _deviceHasBox = false;
      _deviceHasInvoice = false;
      _deviceHasOriginalCharger = false;
    });
  }

  void _addDevice() {
    final value = _deviceIdentityValueController.text.trim();
    if (value.isEmpty) {
      MesajYardimcisi.uyariGoster(
        context,
        '$_deviceIdentityType / Seri No boş olamaz',
      );
      return;
    }

    if (_devices.any((d) => d.identityValue == value)) {
      MesajYardimcisi.uyariGoster(context, 'Bu $value zaten listede ekli');
      return;
    }

    setState(() {
      _devices.add(
        CihazModel(
          id: 0,
          productId: 0,
          identityType: _deviceIdentityType,
          identityValue: value,
          condition: _deviceCondition,
          color: _deviceColorController.text.trim(),
          capacity: _deviceCapacityController.text.trim(),
          warrantyEndDate: _deviceWarrantyEndDate,
          hasBox: _deviceHasBox,
          hasInvoice: _deviceHasInvoice,
          hasOriginalCharger: _deviceHasOriginalCharger,
        ),
      );
      _deviceIdentityValueController.clear();

      // Stok miktarını otomatik artır
      double currentStock = FormatYardimcisi.parseDouble(
        _currentStockController.text,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );
      _currentStockController.text = FormatYardimcisi.sayiFormatla(
        currentStock + 1,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );
      _unitCostController.text = FormatYardimcisi.sayiFormatla(
        0,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );
    });
  }

  Future<void> _openBulkAddDialog() async {
    final controller = TextEditingController();
    const primaryColor = Color(0xFF2C3E50); // matching alis_yap_sayfasi.dart

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 720,
          constraints: const BoxConstraints(maxHeight: 680),
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                          tr('products.quick_add.bulk_add_title'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF202124),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr('products.quick_add.bulk_add_hint'),
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
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Input Area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('products.quick_add.bulk_add_list_title'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A4A4A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF202124),
                        ),
                        decoration: InputDecoration(
                          hintText: tr('products.quick_add.bulk_add_hint'),
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          fillColor: const Color(0xFFF8F9FA),
                          filled: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2C3E50),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      tr('common.cancel'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final lines = controller.text
                          .split(RegExp(r'[\n,;]'))
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                      Navigator.pop(context, lines);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      tr('common.add'),
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

    if (result != null && result.isNotEmpty) {
      setState(() {
        for (final val in result) {
          if (!_devices.any((d) => d.identityValue == val)) {
            _devices.add(
              CihazModel(
                id: 0,
                productId: 0,
                identityType: _deviceIdentityType,
                identityValue: val,
                condition: _deviceCondition,
                color: _deviceColorController.text.trim(),
                capacity: _deviceCapacityController.text.trim(),
                warrantyEndDate: _deviceWarrantyEndDate,
                hasBox: _deviceHasBox,
                hasInvoice: _deviceHasInvoice,
                hasOriginalCharger: _deviceHasOriginalCharger,
              ),
            );
          }
        }
      });

      // Stok miktarını otomatik artır
      double currentStock = FormatYardimcisi.parseDouble(
        _currentStockController.text,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );
      _currentStockController.text = FormatYardimcisi.sayiFormatla(
        currentStock + result.length,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );
      _unitCostController.text = FormatYardimcisi.sayiFormatla(
        0,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );
    }
  }

  Future<void> _openWarrantyDatePicker() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(
        initialDate: _deviceWarrantyEndDate ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        title: tr('products.devices.warranty_end_date'),
      ),
    );
    if (picked != null) {
      setState(() {
        _deviceWarrantyEndDate = picked;
      });
    }
  }

  void _removeDevice(int index) {
    setState(() {
      _devices.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isMobileLayout = MediaQuery.sizeOf(context).width < 900;

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
                  ? tr('products.form.section.general')
                  : tr('products.add'),
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
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(theme),
                            const SizedBox(height: 32),
                            _buildSection(
                              theme,
                              title: tr('products.form.section.general'),
                              child: _buildBasicInfoSection(theme),
                              icon: Icons.info_rounded,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(height: 24),
                            _buildSection(
                              theme,
                              title: tr('products.form.section.pricing'),
                              child: _buildPricesSection(theme),
                              icon: Icons.monetization_on_rounded,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(height: 24),
                            _buildSection(
                              theme,
                              title: tr('products.form.section.stock_features'),
                              child: _buildStockSection(theme),
                              icon: Icons.inventory_2_rounded,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(height: 24),
                            _buildSection(
                              theme,
                              title: tr('products.table.features'),
                              child: _buildAttributesSection(theme),
                              icon: Icons.list_alt_rounded,
                              color: Colors.purple.shade700,
                            ),
                            const SizedBox(height: 24),
                            _buildSection(
                              theme,
                              title: tr('products.form.section.images'),
                              child: _buildImagesSection(theme),
                              icon: Icons.image_rounded,
                              color: Colors.teal.shade700,
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: isMobileLayout
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
                      maxWidth: isMobileLayout ? 760 : 850,
                    ),
                    child: _buildActionButtons(
                      theme,
                      isCompact: isMobileLayout,
                    ),
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            widget.urun != null
                ? Icons.edit_note_rounded
                : Icons.add_box_rounded,
            color: theme.colorScheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.urun != null ? tr('products.edit') : tr('products.add'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                fontSize: 23,
              ),
            ),
            Text(
              widget.urun != null
                  ? tr('products.edit')
                  : tr('products.form.section.general'),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontSize: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                label: tr('products.form.code.label'),
                hint: tr('products.form.code.hint'),
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
                label: tr('products.form.name.label'),
                hint: tr('products.form.name.hint'),
                isRequired: true,
                color: requiredColor,
                focusNode: _nameFocusNode,
              ),
            ]),
            const SizedBox(height: 16),
            _buildRow(isWide, [
              _buildDropdown(
                value: _selectedUnit,
                label: tr('products.form.unit.label'),
                hint: tr('products.form.unit.hint'),
                items: _units,
                onChanged: (val) => setState(() => _selectedUnit = val),
                isRequired: true,
                color: requiredColor,
              ),
              _buildTextField(
                controller: _vatRateController,
                label: tr('products.form.vat.label'),
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
                label: tr('products.form.barcode.label'),
                hint: tr('products.form.barcode.hint'),
                color: optionalColor,
              ),
              _buildDropdown(
                value: _selectedGroup,
                label: tr('products.form.group.label'),
                hint: tr('products.form.group.hint'),
                items: _groups,
                onChanged: (val) => setState(() => _selectedGroup = val),
                color: optionalColor,
              ),
            ]),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _alertQuantityController,
              label: tr('products.form.alert_qty.label'),
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
        Text(
          tr('products.form.purchase_price.label'),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
            fontSize: 18,
          ),
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
              tr('products.form.sales_price_item'),
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
                tr('products.form.sales_price_add'),
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
                    labelOverride: tr('products.form.sales_price_item'),
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

  Widget _buildStockSection(ThemeData theme) {
    final bool isEditing = widget.urun != null;
    final hasStock = _currentStockController.text.isNotEmpty;
    final color = Colors.orange.shade700;

    return Column(
      children: [
        _buildTextField(
          controller: _currentStockController,
          label: tr('products.form.stock.label'),
          isNumeric: true,
          color: color,
          focusNode: isEditing ? null : _currentStockFocusNode,
          readOnly: isEditing,
          hint: isEditing ? tr('products.form.stock_change_hint') : null,
          onChanged: (val) => setState(() {}),
          maxDecimalDigits: _genelAyarlar.miktarOndalik,
        ),
        if (!isEditing) ...[
          const SizedBox(height: 16),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: hasStock ? 1.0 : 0.5,
            child: IgnorePointer(
              ignoring: !hasStock,
              child: Column(
                children: [
                  _buildPriceRow(
                    controller: _unitCostController,
                    currency: _stockUnitCostCurrency,
                    vatStatus: _stockUnitCostVatStatus,
                    onCurrencyChanged: (val) =>
                        setState(() => _stockUnitCostCurrency = val!),
                    onVatStatusChanged: (val) =>
                        setState(() => _stockUnitCostVatStatus = val!),
                    labelOverride: tr('products.form.stock.unit_cost.label'),
                    color: color,
                    focusNode: _unitCostFocusNode,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown<int>(
                    value: _selectedWarehouseId,
                    label: tr('products.form.stock.warehouse.label'),
                    items: _warehouses.map((e) => e.id).toList(),
                    itemLabels: Map.fromEntries(
                      _warehouses.map((e) => MapEntry(e.id, e.ad)),
                    ),
                    onChanged: (val) =>
                        setState(() => _selectedWarehouseId = val),
                    color: color,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (_genelAyarlar.cihazListesiModuluAktif)
          _buildDeviceListSection(theme),
      ],
    );
  }

  Widget _buildDeviceListSection(ThemeData theme) {
    final color = const Color(0xFFFF8C42); // Orange from image

    String identityTypeLabel(String raw) {
      switch (raw) {
        case 'IMEI':
          return tr('common.identity.imei');
        case 'Seri No':
          return tr('common.identity.serial');
        case 'Diğer':
          return tr('common.identity.other');
        default:
          return raw;
      }
    }

    String conditionLabel(String raw) {
      switch (raw) {
        case 'Sıfır':
          return tr('common.condition.new');
        case 'İkinci El':
          return tr('common.condition.used');
        case 'Yenilenmiş':
          return tr('common.condition.refurbished');
        case 'Arızalı':
          return tr('common.condition.broken');
        default:
          return raw;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA), // Off-white/slate-ish background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.shade100.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone_android_rounded, color: color, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        tr('products.devices.list_title'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tr(
                        'products.devices.count',
                        args: {'count': _devices.length.toString()},
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Input Grid
              _buildRow(isWide, [
                _buildDropdown(
                  value: _deviceIdentityType,
                  label: tr('products.devices.identity_type'),
                  items: ['IMEI', 'Seri No', 'Diğer'],
                  itemLabels: {
                    'IMEI': tr('common.identity.imei'),
                    'Seri No': tr('common.identity.serial'),
                    'Diğer': tr('common.identity.other'),
                  },
                  onChanged: (val) =>
                      setState(() => _deviceIdentityType = val!),
                  color: Colors.blue.shade700,
                ),
                _buildDropdown(
                  value: _deviceCondition,
                  label: tr('products.devices.condition'),
                  items: ['Sıfır', 'İkinci El', 'Yenilenmiş', 'Arızalı'],
                  itemLabels: {
                    'Sıfır': tr('common.condition.new'),
                    'İkinci El': tr('common.condition.used'),
                    'Yenilenmiş': tr('common.condition.refurbished'),
                    'Arızalı': tr('common.condition.broken'),
                  },
                  onChanged: (val) => setState(() => _deviceCondition = val!),
                  color: Colors.blue.shade700,
                ),
                _buildTextField(
                  controller: _deviceColorController,
                  label: tr('products.field.color'),
                  color: Colors.blue.shade700,
                ),
                _buildTextField(
                  controller: _deviceCapacityController,
                  label: tr('products.field.capacity'),
                  color: Colors.blue.shade700,
                ),
              ]),
              const SizedBox(height: 12),
              InkWell(
                onTap: _openWarrantyDatePicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('products.devices.warranty_end_date'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _deviceWarrantyEndDate != null
                                ? DateFormat(
                                    'dd.MM.yyyy',
                                  ).format(_deviceWarrantyEndDate!)
                                : tr('common.select'),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildGadgetToggle(
                    label: tr('common.gadget.box'),
                    value: _deviceHasBox,
                    onChanged: (val) => setState(() => _deviceHasBox = val),
                  ),
                  _buildGadgetToggle(
                    label: tr('common.gadget.invoice'),
                    value: _deviceHasInvoice,
                    onChanged: (val) => setState(() => _deviceHasInvoice = val),
                  ),
                  _buildGadgetToggle(
                    label: tr('common.gadget.charger'),
                    value: _deviceHasOriginalCharger,
                    onChanged: (val) =>
                        setState(() => _deviceHasOriginalCharger = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isWide)
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _deviceIdentityValueController,
                        label: tr('products.devices.identity'),
                        color: Colors.blue.shade700,
                        onSubmitted: (_) => _addDevice(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _addDevice,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(tr('common.add')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade700,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _openBulkAddDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      child: Text(tr('products.quick_add.bulk_add')),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      controller: _deviceIdentityValueController,
                      label: tr('products.devices.identity'),
                      color: Colors.blue.shade700,
                      onSubmitted: (_) => _addDevice(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _addDevice,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(tr('common.add')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade700,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _openBulkAddDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                              side: BorderSide(color: Colors.blue.shade200),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(tr('products.quick_add.bulk_add')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              if (_devices.isEmpty)
                Text(
                  tr('products.quick_add.no_device_added'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _devices.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${identityTypeLabel(device.identityType)}: ${device.identityValue}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${conditionLabel(device.condition)} | ${device.color ?? "-"} | ${device.capacity ?? "-"}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeDevice(index),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGadgetToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? Colors.blue.shade300 : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: value ? FontWeight.bold : FontWeight.normal,
            color: value ? Colors.blue.shade700 : Colors.grey.shade700,
          ),
        ),
      ),
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
              tr('products.form.attribute.empty_hint'),
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
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            tr('products.form.attribute.select_color'),
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
                    label: tr('products.form.attribute.name'),
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
              tr('products.form.feature_add'),
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
                        tr('products.form.image.dropzone_hint'),
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
                        foregroundColor: const Color(0xFF2C3E50),
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
            foregroundColor: const Color(0xFF2C3E50),
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
    String? errorText,
    int? maxDecimalDigits,
    ValueChanged<String>? onSubmitted,
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
          onFieldSubmitted: onSubmitted,
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

    // Değerin seçeneklerde olduğundan emin ol (Assertion error önleyici)
    final List<T> effectiveItems = List.from(items);
    if (value != null && !effectiveItems.contains(value)) {
      effectiveItems.add(value);
    }

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
          items: effectiveItems
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
                    labelOverride ?? tr('products.form.purchase_price.label'),
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
                    labelOverride ?? tr('products.form.purchase_price.label'),
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
}
