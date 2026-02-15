import 'package:flutter/material.dart';
// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:intl/intl.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../servisler/depolar_veritabani_servisi.dart';
import '../../servisler/urunler_veritabani_servisi.dart';
import '../../servisler/uretimler_veritabani_servisi.dart';
import '../urunler_ve_depolar/uretimler/modeller/uretim_model.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../urunler_ve_depolar/urunler/modeller/urun_model.dart';
import '../urunler_ve_depolar/depolar/modeller/depo_model.dart';
import '../carihesaplar/modeller/cari_hesap_model.dart';
import '../../bilesenler/onay_dialog.dart';
import '../../bilesenler/tab_acici_scope.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import 'package:flutter/services.dart';
import 'alis_tamamla_sayfasi.dart';
import '../../bilesenler/akilli_aciklama_input.dart';
import 'modeller/transaction_item.dart';
import '../ayarlar/genel_ayarlar/modeller/doviz_kuru_model.dart';
import '../../bilesenler/tek_tarih_secici_dialog.dart';
import '../../yardimcilar/islem_turu_renkleri.dart';

class AlisYapSayfasi extends StatefulWidget {
  final CariHesapModel? initialCari;
  final List<PurchaseItem>? initialItems;
  final String? initialCurrency;
  final String? initialDescription;
  final String? initialOrderRef;
  final double? initialRate;

  /// Düzenleme modu için mevcut işlem verisi (Cari Karttan açıldığında kullanılır)
  final Map<String, dynamic>? duzenlenecekIslem;

  const AlisYapSayfasi({
    super.key,
    this.initialCari,
    this.initialItems,
    this.initialCurrency,
    this.initialDescription,
    this.initialOrderRef,
    this.initialRate,
    this.duzenlenecekIslem,
  });

  @override
  State<AlisYapSayfasi> createState() => _AlisYapSayfasiState();
}

class _AlisYapSayfasiState extends State<AlisYapSayfasi> {
  final _formKey = GlobalKey<FormState>();
  final _itemFormKey = GlobalKey<FormState>();

  // Header State
  // ignore: unused_field
  int? _selectedSupplierId;
  String? _selectedSupplierCode;
  // String _selectedSupplierName = ''; // Unused, handled by controller
  final _supplierNameController = TextEditingController();
  int? _selectedWarehouseId;
  final _dateController = TextEditingController();
  final DateTime _selectedDate = DateTime.now();
  final _descriptionController = TextEditingController();
  Timer? _searchDebounce;
  UrunModel? _currentProduct;

  // Supplier Autocomplete
  Timer? _supplierSearchDebounce;
  final _supplierFocusNode = FocusNode();

  // Product Entry Controllers
  final _productCodeController = TextEditingController();
  final _productCodeFocusNode = FocusNode();
  final _productNameController = TextEditingController();
  final _productNameFocusNode = FocusNode();
  final _unitPriceController = TextEditingController();
  final _vatRateController = TextEditingController(text: '20');
  final _otvRateController = TextEditingController(text: '0');
  final _oivRateController = TextEditingController(text: '0');
  final _discountRateController = TextEditingController();
  final _quantityController = TextEditingController();

  String _productUnit = 'Adet';
  String _productBarcode = '';
  String _selectedCurrency = 'TRY';
  String _vatStatus =
      'excluded'; // 'excluded' = KDV Hariç, 'included' = KDV Dahil
  String _otvStatus = 'excluded';
  String _oivStatus = 'excluded';
  String _kdvTevkifatValue = '0'; // '0' = Yok, '2/10' = 2/10, vb.

  // Data State
  final List<PurchaseItem> _items = [];
  final Set<int> _selectedItemIndices = {};

  // Settings
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  // Inline Editing State
  int? _editingIndex;
  String? _editingField; // 'price', 'discount', 'quantity'

  List<DepoModel> _allWarehouses = [];
  // List<CariHesapModel> _allSuppliers = []; // Unused, replaced by Autocomplete
  bool _isLoadingData = true;

  // Focus
  final _quantityFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();

  // Style Constants (Copied from SeviyatOlusturSayfasi for Strict Visual Integrity)
  static const Color _primaryColor = Color(0xFF2C3E50);

  static const Color _textColor = Color(0xFF202124);
  static const Color _borderColor = Color(0xFFE0E0E0);

  String _invoiceCurrency = 'TRY'; // Global invoice currency
  double _currentCurrencyRate = 1.0;
  double _invoiceCurrencyRate = 1.0;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd.MM.yyyy').format(_selectedDate);
    _loadInitialData();

    // Dışarıdan gelen verileri yükle
    if (widget.initialCari != null) {
      _selectedSupplierId = widget.initialCari!.id;
      _selectedSupplierCode = widget.initialCari!.kodNo;
      _supplierNameController.text = widget.initialCari!.adi;
    }
    if (widget.initialCurrency != null) {
      _selectedCurrency = widget.initialCurrency!;
      _invoiceCurrency = widget.initialCurrency!;
    }
    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
    }
    if (widget.initialItems != null) {
      _items.addAll(widget.initialItems!);
    }
    if (widget.initialRate != null) {
      _currentCurrencyRate = widget.initialRate!;
    }
    // Keyboard shortcuts
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    // Initial Focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _supplierFocusNode.requestFocus();
    });
  }

  Future<void> _loadInitialData() async {
    try {
      final warehouses = await DepolarVeritabaniServisi().tumDepolariGetir();
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();

      if (mounted) {
        setState(() {
          _allWarehouses = warehouses;
          _genelAyarlar = settings;

          if (_allWarehouses.isNotEmpty) {
            _selectedWarehouseId = _allWarehouses.first.id;
          }

          // Para birimini güncelle
          if (widget.initialCurrency == null) {
            String currency = settings.varsayilanParaBirimi;
            if (currency == 'TL') currency = 'TRY';
            _selectedCurrency = currency;
            _invoiceCurrency = currency;
          } else {
            _selectedCurrency = widget.initialCurrency!;
            _invoiceCurrency = widget.initialCurrency!;
          }

          // Varsayılan vergi durumlarını uygula
          _vatStatus = settings.varsayilanKdvDurumu;
          _otvStatus = settings.otvKdvDurumu;
          _oivStatus = settings.oivKdvDurumu;

          // Eğer initialItems varsa ve içlerinden birinin kuru varsa onu al
          if (_items.isNotEmpty) {
            _currentCurrencyRate = _items.first.exchangeRate;
          } else if (widget.initialRate != null) {
            _currentCurrencyRate = widget.initialRate!;
          }

          _updateInvoiceRate(_invoiceCurrency);

          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        MesajYardimcisi.hataGoster(context, tr('common.error'));
      }
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _searchDebounce?.cancel();
    _supplierSearchDebounce?.cancel();
    _productCodeController.removeListener(_onSearchChanged);
    _dateController.dispose();
    _descriptionController.dispose();
    _productCodeController.dispose();
    _productNameController.dispose();
    _unitPriceController.dispose();
    _vatRateController.dispose();
    _discountRateController.dispose();
    _quantityController.dispose();
    _quantityFocusNode.dispose();
    _priceFocusNode.dispose();
    _supplierFocusNode.dispose();
    _productCodeFocusNode.dispose();
    _productNameFocusNode.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.f1) {
        _addItem();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.f3) {
        _productCodeFocusNode.requestFocus();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.f5) {
        _showInvoiceDiscountDialog();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.f6) {
        _deleteAllItems();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.f8) {
        _deleteSelected();
        return true;
      }
    }
    return false;
  }

  // --- Logic ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(
        initialDate: _selectedDate,
        title: tr('common.date'),
      ),
    );

    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    final query = _productCodeController.text.trim();
    if (query.isEmpty) {
      _clearProductFields(shouldClearCode: false);
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _findProduct(query: query, isAuto: true);
    });
  }

  Future<void> _findProduct({String? query, bool isAuto = false}) async {
    final codeTerm = _productCodeController.text.trim();
    final nameTerm = _productNameController.text.trim();
    final searchTerm = (query?.trim().isNotEmpty ?? false)
        ? query!.trim()
        : (codeTerm.isNotEmpty ? codeTerm : nameTerm);

    if (searchTerm.isEmpty) {
      if (!isAuto) _openProductSearchDialog();
      return;
    }

    try {
      // Önce ürünlerde ara
      final urunResults = await UrunlerVeritabaniServisi().urunleriGetir(
        aramaTerimi: searchTerm,
        sayfaBasinaKayit: 1,
      );

      if (mounted) {
        if (urunResults.isNotEmpty) {
          final p = urunResults.first;
          _fillProductFields(p, updateCodeField: !isAuto);
        } else {
          // Ürün bulunamadı, üretimlerde ara
          final uretimResults = await UretimlerVeritabaniServisi()
              .uretimleriGetir(aramaTerimi: searchTerm, sayfaBasinaKayit: 1);

          if (mounted) {
            if (uretimResults.isNotEmpty) {
              final u = uretimResults.first;
              // UretimModel'i UrunModel'e dönüştür
              final urunFromUretim = UrunModel(
                id: u.id,
                kod: u.kod,
                ad: u.ad,
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
              );
              _fillProductFields(urunFromUretim, updateCodeField: !isAuto);
            } else {
              if (isAuto) {
                // "yoksa bulamaz" - Clear fields to indicate invalid code
                _clearProductFields(shouldClearCode: false);
              } else {
                MesajYardimcisi.hataGoster(
                  context,
                  tr('shipment.form.error.product_not_found'),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      // silent fail or log
    }
  }

  void _clearProductFields({bool shouldClearCode = true}) {
    setState(() {
      _currentProduct = null;
      _productBarcode = '';
      if (shouldClearCode) {
        _productCodeController.clear();
      }
      _productNameController.clear();
      _productUnit = 'Adet';
      _unitPriceController.clear();
      _vatRateController.clear();
      _discountRateController.clear();
      _quantityController.clear();
    });
  }

  Future<void> _openProductSearchDialog() async {
    // We can reuse the dialog logic or just call a simple search.
    // Since we don't have access to the private `_ProductSearchDialog` from `sevkiyat_olustur`,
    // we would need to replicate it or use a public one.
    // For now, I'll simulate a simple dialog or just use the find logic.
    // Wait, `sevkiyat_olustur_sayfasi.dart` has `_ProductSearchDialog` inside it (private).
    // I cannot access it. I should allow manual entry as fallback or create a new Search Dialog.
    // For simplicity and stability without creating more files, I will assume manual entry logic
    // OR create a simple dialog here.
    // Better: I will implement a quick dialog here since pixel perfect match is required.

    // .. Wait, `sevkiyat_olustur_sayfasi.dart` was provided as a reference file path.
    // I can read it and copy the dialog class if needed.

    // Implementing a minimal product search dialog here.
    showDialog(
      context: context,
      builder: (context) =>
          _ProductSearchDialogWrapper(onSelect: (p) => _fillProductFields(p)),
    );
  }

  void _fillProductFields(UrunModel p, {bool updateCodeField = true}) {
    setState(() {
      _currentProduct = p;
      if (updateCodeField) {
        _productCodeController.text = p.kod;
      }
      _productNameController.text = p.ad;
      _productUnit = p.birim;
      _productBarcode = p.barkod;
      _unitPriceController.text = FormatYardimcisi.sayiFormatlaOndalikli(
        p.alisFiyati,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: _genelAyarlar.fiyatOndalik,
      );
      // VAT is usually an integer or simple rate
      _vatRateController.text = FormatYardimcisi.sayiFormatlaOran(
        p.kdvOrani,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );
      _discountRateController.clear();
      _quantityController.text = '1';
      if (updateCodeField) {
        _quantityFocusNode.requestFocus();
      }
    });
  }

  bool _checkAndShowIMEIInput(UrunModel? product, {PurchaseItem? baseItem}) {
    if (product == null && baseItem == null) return false;

    if (_allWarehouses.isEmpty || _selectedWarehouseId == null) {
      MesajYardimcisi.hataGoster(context, tr('purchase.msg.select_warehouse'));
      return false;
    }

    bool hasImeiTracking = false;

    // 1. Özellikler JSON içinde "imei", "seri", "sn" geçiyor mu?
    if (product != null && product.ozellikler.isNotEmpty) {
      final String ozLower = product.ozellikler.toLowerCase();
      if (ozLower.contains('imei') ||
          ozLower.contains('seri') ||
          ozLower.contains('sn')) {
        hasImeiTracking = true;
      }
    }

    // 2. İsim veya kod içerisinde geçiyor mu?
    if (!hasImeiTracking) {
      final nameLower = (product?.ad ?? baseItem?.name ?? '').toLowerCase();
      final codeLower = (product?.kod ?? baseItem?.code ?? '').toLowerCase();
      if (nameLower.contains('imei') ||
          nameLower.contains('seri') ||
          nameLower.contains('sn') ||
          codeLower.contains('imei') ||
          codeLower.contains('seri')) {
        hasImeiTracking = true;
      }
    }

    // 3. Mevcut cihaz kaydı var mı?
    if (!hasImeiTracking && (product?.cihazlar.isNotEmpty ?? false)) {
      hasImeiTracking = true;
    }

    if (hasImeiTracking) {
      final finalBaseItem =
          baseItem ??
          PurchaseItem(
            code: product!.kod,
            name: product.ad,
            barcode: product.barkod,
            unit: product.birim,
            quantity: 1,
            unitPrice:
                _parseFlexibleDouble(_unitPriceController.text) *
                (_currentCurrencyRate / _invoiceCurrencyRate),
            currency: _invoiceCurrency,
            exchangeRate: _invoiceCurrencyRate,
            vatRate: _parseFlexibleDouble(_vatRateController.text),
            discountRate: _parseFlexibleDouble(_discountRateController.text),
            warehouseId: _selectedWarehouseId!,
            warehouseName: _allWarehouses
                .firstWhere(
                  (w) => w.id == _selectedWarehouseId,
                  orElse: () => _allWarehouses.first,
                )
                .ad,
            vatIncluded: _vatStatus == 'included',
            otvRate: _parseFlexibleDouble(_otvRateController.text),
            otvIncluded: _otvStatus == 'included',
            oivRate: _parseFlexibleDouble(_oivRateController.text),
            oivIncluded: _oivStatus == 'included',
            kdvTevkifatOrani: _parseTevkifat(_kdvTevkifatValue),
          );

      _showIMEIInputDialog(finalBaseItem, product);
      return true;
    }
    return false;
  }

  Future<void> _addItem() async {
    if (!(_itemFormKey.currentState?.validate() ?? false)) return;

    if (_allWarehouses.isEmpty || _selectedWarehouseId == null) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(context, tr('purchase.msg.select_warehouse'));
      return;
    }

    final codeTerm = _productCodeController.text.trim();
    final nameTerm = _productNameController.text.trim();
    final searchTerm = codeTerm.isNotEmpty ? codeTerm : nameTerm;

    UrunModel? resolvedProduct = _currentProduct;
    if (resolvedProduct == null && searchTerm.isNotEmpty) {
      try {
        final urunResults = await UrunlerVeritabaniServisi().urunleriGetir(
          aramaTerimi: searchTerm,
          sayfaBasinaKayit: 1,
        );
        if (urunResults.isNotEmpty) {
          resolvedProduct = urunResults.first;
        } else {
          final uretimResults = await UretimlerVeritabaniServisi()
              .uretimleriGetir(aramaTerimi: searchTerm, sayfaBasinaKayit: 1);
          if (uretimResults.isNotEmpty) {
            final u = uretimResults.first;
            resolvedProduct = UrunModel(
              id: u.id,
              kod: u.kod,
              ad: u.ad,
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
            );
          }
        }
      } catch (_) {
        // ignore
      }
    }

    final itemCode = (resolvedProduct?.kod ?? codeTerm).trim();
    if (itemCode.isEmpty) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(
        context,
        tr('shipment.form.error.product_not_found'),
      );
      return;
    }

    final qty = _parseFlexibleDouble(
      _quantityController.text,
      maxDecimalDigits: _genelAyarlar.miktarOndalik,
    );
    final price = _parseFlexibleDouble(
      _unitPriceController.text,
      maxDecimalDigits: _genelAyarlar.fiyatOndalik,
    );
    final vat = _parseFlexibleDouble(
      _vatRateController.text,
      maxDecimalDigits: 2,
    );
    final discount = _parseFlexibleDouble(
      _discountRateController.text,
      maxDecimalDigits: 2,
    );

    final otv = _parseFlexibleDouble(_otvRateController.text);
    final oiv = _parseFlexibleDouble(_oivRateController.text);
    final tevkifat = _parseTevkifat(_kdvTevkifatValue);

    if (qty <= 0) return;

    final selectedWarehouse = _allWarehouses.firstWhere(
      (w) => w.id == _selectedWarehouseId,
      orElse: () => _allWarehouses.first,
    );

    final convertedPrice =
        price * (_currentCurrencyRate / _invoiceCurrencyRate);

    final newItem = PurchaseItem(
      code: itemCode,
      name: (resolvedProduct?.ad ?? _productNameController.text).trim(),
      barcode: (resolvedProduct?.barkod ?? _productBarcode).trim(),
      unit: resolvedProduct?.birim ?? _productUnit,
      quantity: qty,
      unitPrice: convertedPrice,
      currency: _invoiceCurrency,
      exchangeRate: _invoiceCurrencyRate,
      vatRate: vat,
      discountRate: discount,
      warehouseId: _selectedWarehouseId!,
      warehouseName: selectedWarehouse.ad,
      vatIncluded: _vatStatus == 'included',
      otvRate: otv,
      otvIncluded: _otvStatus == 'included',
      oivRate: oiv,
      oivIncluded: _oivStatus == 'included',
      kdvTevkifatOrani: tevkifat,
    );

    setState(() {
      final existingIndex = _items.indexWhere(
        (e) =>
            e.code == newItem.code &&
            e.warehouseId == newItem.warehouseId &&
            e.serialNumber == null, // Seri nosuz olanları birleştir
      );

      // Ürün seri no takipli mi kontrol et ve diyaloğu aç (Satış sayfası gibi anında tetikleme veya Ekle butonu fallback)
      if (newItem.serialNumber == null) {
        if (_checkAndShowIMEIInput(resolvedProduct, baseItem: newItem)) {
          return;
        }
      }

      if (existingIndex != -1) {
        final existing = _items[existingIndex];
        _items[existingIndex] = existing.copyWith(
          name: newItem.name,
          barcode: newItem.barcode,
          unit: newItem.unit,
          quantity: existing.quantity + newItem.quantity,
          unitPrice: newItem.unitPrice,
          currency: newItem.currency,
          exchangeRate: newItem.exchangeRate,
          vatRate: newItem.vatRate,
          discountRate: newItem.discountRate,
          warehouseName: newItem.warehouseName,
          vatIncluded: newItem.vatIncluded,
          otvRate: newItem.otvRate,
          otvIncluded: newItem.otvIncluded,
          oivRate: newItem.oivRate,
          oivIncluded: newItem.oivIncluded,
          kdvTevkifatOrani: newItem.kdvTevkifatOrani,
        );
      } else {
        _items.add(newItem);
      }
    });

    _productCodeController.clear();
    _clearProductFields(shouldClearCode: false);
  }

  double _parseFlexibleDouble(String text, {int? maxDecimalDigits}) {
    final raw = text.trim();
    if (raw.isEmpty) return 0.0;

    final hasDot = raw.contains('.');
    final hasComma = raw.contains(',');

    String clean;
    if (hasDot && hasComma) {
      final lastDot = raw.lastIndexOf('.');
      final lastComma = raw.lastIndexOf(',');
      final decimalSep = lastDot > lastComma ? '.' : ',';
      final thousandSep = decimalSep == '.' ? ',' : '.';
      clean = raw.replaceAll(thousandSep, '').replaceAll(decimalSep, '.');
      return double.tryParse(clean) ?? 0.0;
    }

    if (hasDot || hasComma) {
      final sep = hasDot ? '.' : ',';
      final sepCount = raw.split(sep).length - 1;
      if (sepCount > 1) {
        clean = raw.replaceAll(sep, '');
        return double.tryParse(clean) ?? 0.0;
      }

      final idx = raw.lastIndexOf(sep);
      final digitsAfter = raw.length - idx - 1;
      final treatAsDecimal =
          (maxDecimalDigits != null) &&
          digitsAfter > 0 &&
          digitsAfter <= maxDecimalDigits;

      if (treatAsDecimal) {
        clean = raw.replaceAll(sep, '.');
        return double.tryParse(clean) ?? 0.0;
      }

      // Fallback: parse using configured separators (supports thousand separators)
      return FormatYardimcisi.parseDouble(
        raw,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );
    }

    clean = raw.replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }

  double _parseTevkifat(String val) {
    if (val == '0') return 0.0;
    final parts = val.split('/');
    if (parts.length == 2) {
      final pay = double.tryParse(parts[0]) ?? 0.0;
      final payda = double.tryParse(parts[1]) ?? 1.0;
      return pay / payda;
    }
    return 0.0;
  }

  Future<void> _updateCurrentRate(String val) async {
    final rate = await _fetchRateFromDb(val);
    setState(() {
      _currentCurrencyRate = rate;
    });
  }

  Future<void> _updateInvoiceRate(String val) async {
    final rate = await _fetchRateFromDb(val);
    setState(() {
      _invoiceCurrencyRate = rate;
    });
  }

  Future<double> _fetchRateFromDb(String val) async {
    if (val == 'TRY' ||
        val == 'TL' ||
        val == _genelAyarlar.varsayilanParaBirimi) {
      return 1.0;
    }

    try {
      final kurlar = await AyarlarVeritabaniServisi().kurlariGetir();
      final kur = kurlar.firstWhere(
        (k) =>
            k.kaynakParaBirimi == val &&
            (k.hedefParaBirimi == 'TRY' ||
                k.hedefParaBirimi == 'TL' ||
                k.hedefParaBirimi == _genelAyarlar.varsayilanParaBirimi),
        orElse: () => kurlar.firstWhere(
          (k) =>
              (k.kaynakParaBirimi == 'TRY' ||
                  k.kaynakParaBirimi == 'TL' ||
                  k.kaynakParaBirimi == _genelAyarlar.varsayilanParaBirimi) &&
              k.hedefParaBirimi == val,
          orElse: () => DovizKuruModel(
            kaynakParaBirimi: val,
            hedefParaBirimi: 'TRY',
            kur: 1.0,
            guncellemeZamani: DateTime.now(),
          ),
        ),
      );

      double rate = kur.kur;
      if (kur.hedefParaBirimi == val) {
        rate = 1.0 / rate;
      }
      return rate;
    } catch (e) {
      return 1.0;
    }
  }

  Future<void> _completePurchase() async {
    // Listede ürün olmalı
    if (_items.isEmpty) {
      MesajYardimcisi.hataGoster(context, tr('purchase.error.no_items'));
      return;
    }

    // Depo seçimi zorunlu
    if (_allWarehouses.isEmpty || _items.any((e) => e.warehouseId <= 0)) {
      MesajYardimcisi.hataGoster(context, tr('purchase.msg.select_warehouse'));
      return;
    }

    // Hesaplamaları yap
    double toplamTutar = 0;
    double toplamIskonto = 0;
    double toplamKdv = 0;
    for (var item in _items) {
      toplamTutar += (item.quantity * item.netUnitPrice);
      toplamIskonto += item.discountAmount;
      toplamKdv += item.vatAmount;
    }
    final genelToplam = toplamTutar - toplamIskonto + toplamKdv;

    // AlisTamamlaSayfasi'na yönlendir
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => AlisTamamlaSayfasi(
          items: _items,
          genelToplam: genelToplam,
          toplamIskonto: toplamIskonto,
          toplamKdv: toplamKdv,
          paraBirimi: _invoiceCurrency,
          selectedCariId: _selectedSupplierId,
          selectedCariName: _supplierNameController.text,
          selectedCariCode: _selectedSupplierCode,
          orderId: widget.initialOrderRef != null
              ? int.tryParse(widget.initialOrderRef!)
              : null,
          duzenlenecekIslem: widget.duzenlenecekIslem,
        ),
      ),
    );

    if (result == true && mounted) {
      if (widget.duzenlenecekIslem == null) {
        _resetPage();
      } else {
        // Cari karttan düzenleme olarak açıldıysa, kayıt sonrası bu sayfayı da kapat
        final tabScope = TabAciciScope.of(context);
        if (tabScope != null && widget.initialCari != null) {
          tabScope.tabAc(
            menuIndex: TabAciciScope.cariKartiIndex,
            initialCari: widget.initialCari,
          );
        }
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    }
  }

  void _resetPage() {
    setState(() {
      _items.clear();
      _selectedItemIndices.clear();
      _selectedSupplierId = widget.initialCari?.id;
      _selectedSupplierCode = widget.initialCari?.kodNo;
      _supplierNameController.text = widget.initialCari?.adi ?? '';
      _descriptionController.clear();
      _clearProductFields();

      // Tekrar cari seçimine odaklan (eğer initial cari yoksa)
      if (widget.initialCari == null) {
        _supplierFocusNode.requestFocus();
      } else {
        _productCodeFocusNode.requestFocus();
      }
    });
  }

  void _deleteSelected() {
    if (_selectedItemIndices.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr('common.confirm_delete_selected'),
        onayButonMetni: tr('common.delete'),
        isDestructive: true,
        onOnay: () {
          setState(() {
            final indices = _selectedItemIndices.toList()
              ..sort((a, b) => b.compareTo(a));
            for (final index in indices) {
              if (index < _items.length) {
                _items.removeAt(index);
              }
            }
            _selectedItemIndices.clear();
          });
        },
      ),
    );
  }

  void _deleteAllItems() {
    if (_items.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr('common.confirm_delete_all'),
        onayButonMetni: tr('common.delete'),
        isDestructive: true,
        onOnay: () {
          setState(() {
            _items.clear();
            _selectedItemIndices.clear();
          });
        },
      ),
    );
  }

  void _removeItemAt(int index) {
    if (index < 0 || index >= _items.length) return;

    setState(() {
      _items.removeAt(index);

      final Set<int> updatedSelected = {};
      for (final selectedIndex in _selectedItemIndices) {
        if (selectedIndex == index) continue;
        updatedSelected.add(
          selectedIndex > index ? selectedIndex - 1 : selectedIndex,
        );
      }
      _selectedItemIndices
        ..clear()
        ..addAll(updatedSelected);
    });
  }

  void _showInvoiceDiscountDialog() {
    if (_items.isEmpty) {
      MesajYardimcisi.bilgiGoster(context, tr('purchase.error.no_items'));
      return;
    }

    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('purchase.dialog.invoice_discount_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('purchase.dialog.invoice_discount_message')),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                LengthLimitingTextInputFormatter(5),
              ],
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
                for (var i = 0; i < _items.length; i++) {
                  _items[i] = _items[i].copyWith(discountRate: val);
                }
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA4335),
              foregroundColor: Colors.white,
            ),
            child: Text(tr('common.apply')),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableCell({
    required int index,
    required String field,
    required double value,
    required void Function(double) onSubmitted,
    String prefix = '',
    String suffix = '',
  }) {
    final isEditing = _editingIndex == index && _editingField == field;

    int decimals = 2;
    if (field == 'price') {
      decimals = _genelAyarlar.fiyatOndalik;
    } else if (field == 'quantity') {
      decimals = _genelAyarlar.miktarOndalik;
    }

    if (isEditing) {
      return _InlineNumberEditor(
        value: value,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: decimals,
        onSubmitted: (val) {
          onSubmitted(val);
          setState(() {
            _editingIndex = null;
            _editingField = null;
          });
        },
      );
    }

    String formattedValue = '';
    if (field == 'price') {
      formattedValue = '$prefix${_fmt(value)}';
    } else if (field == 'exchangeRate') {
      formattedValue = FormatYardimcisi.sayiFormatlaOndalikli(
        value,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: 2,
      );
    } else if (field == 'quantity') {
      formattedValue = FormatYardimcisi.sayiFormatla(
        value,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: _genelAyarlar.miktarOndalik,
      );
    } else {
      formattedValue =
          '$prefix${FormatYardimcisi.sayiFormatlaOran(value, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci)}';
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
          Icon(Icons.edit, size: 12, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(width: 4),
          Text(
            '$formattedValue$suffix',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF202124),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Components ---

  Widget _buildTableActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedItemIndices.isNotEmpty) ...[
          Tooltip(
            message: '${tr('common.delete_selected_items')} (F8)',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _deleteSelected,
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
                        '${tr('common.delete_selected_items')} (${_selectedItemIndices.length})',
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
          const SizedBox(width: 8),
        ],
        Tooltip(
          message: '${tr('common.delete_all')} (F6)',
          child: MouseRegion(
            cursor: _items.isEmpty
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _items.isEmpty ? null : _deleteAllItems,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFEF5350,
                  ).withValues(alpha: _items.isEmpty ? 0.5 : 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_forever,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr('common.delete_all'),
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
        const SizedBox(width: 8),
        Tooltip(
          message: '${tr('purchase.button.invoice_discount')} (F5)',
          child: MouseRegion(
            cursor: _items.isEmpty
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _items.isEmpty ? null : _showInvoiceDiscountDialog,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF2C3E50,
                  ).withValues(alpha: _items.isEmpty ? 0.5 : 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.percent, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      tr('purchase.button.invoice_discount'),
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
                        tr('common.key.f5'),
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

  @override
  Widget build(BuildContext context) {
    // Footer Calculations
    double subTotal = 0;
    double totalDiscount = 0;
    double totalVat = 0;
    double totalOtv = 0;
    double totalOiv = 0;
    double totalTevkifat = 0;

    for (var item in _items) {
      subTotal += (item.quantity * item.netUnitPrice);
      totalDiscount +=
          (item.quantity * item.netUnitPrice +
              item.otvAmount +
              item.oivAmount) *
          (item.discountRate / 100);
      totalVat += item.vatAmount;
      totalOtv += item.otvAmount;
      totalOiv += item.oivAmount;
      totalTevkifat += item.kdvTevkifatAmount;
    }

    // 2026 Mevzuatı: KDV dahil toplam tutar 12.000 TL'nin altındaysa tevkifat uygulanmaz
    double inclusiveTotal =
        subTotal + totalOtv + totalOiv - totalDiscount + totalVat;
    if (inclusiveTotal < 12000) {
      totalTevkifat = 0;
    }

    double grandTotal = inclusiveTotal - totalTevkifat;

    final bool isDense =
        _genelAyarlar.otvKullanimi ||
        _genelAyarlar.oivKullanimi ||
        _genelAyarlar.kdvTevkifati;
    final bool isMobileLayout = MediaQuery.sizeOf(context).width < 900;
    final double pagePadding = isMobileLayout ? 12 : 16;
    final double sectionGap = isMobileLayout ? 16 : 24;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          tr('purchase.title'),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF202124),
            fontSize: isMobileLayout ? 18 : 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF3C4043)),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.all(pagePadding),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isMobileLayout ? 760 : 1400,
                        ),
                        child: FocusTraversalGroup(
                          policy: OrderedTraversalPolicy(),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header & Entry
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth > 980) {
                                      final double computedGeneralInfoWidth =
                                          (constraints.maxWidth - 24) / 3;
                                      final double generalInfoWidth =
                                          computedGeneralInfoWidth > 360
                                          ? 360
                                          : computedGeneralInfoWidth;

                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: generalInfoWidth,
                                            child: _buildSection(
                                              title: tr(
                                                'common.section.general_info',
                                              ),
                                              icon: Icons.info_outline_rounded,
                                              child: _buildGeneralInfoFields(
                                                isDense: isDense,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          Expanded(
                                            child: _buildSection(
                                              title: tr(
                                                'common.section.product_entry',
                                              ),
                                              icon: Icons
                                                  .add_shopping_cart_rounded,
                                              child: _buildProductEntryFields(
                                                isDense: isDense,
                                              ),
                                              action:
                                                  _buildAddItemActionButton(),
                                            ),
                                          ),
                                        ],
                                      );
                                    } else {
                                      return Column(
                                        children: [
                                          _buildSection(
                                            title: tr(
                                              'common.section.general_info',
                                            ),
                                            icon: Icons.info_outline_rounded,
                                            child: _buildGeneralInfoFields(
                                              isDense: true,
                                            ),
                                            isCompact: isMobileLayout,
                                          ),
                                          SizedBox(height: sectionGap),
                                          _buildSection(
                                            title: tr(
                                              'common.section.product_entry',
                                            ),
                                            icon:
                                                Icons.add_shopping_cart_rounded,
                                            child: _buildProductEntryFields(
                                              isDense: true,
                                            ),
                                            action: _buildAddItemActionButton(
                                              compact: true,
                                            ),
                                            isCompact: isMobileLayout,
                                          ),
                                        ],
                                      );
                                    }
                                  },
                                ),
                                SizedBox(height: sectionGap),
                                // Table
                                _buildSection(
                                  title:
                                      '${tr('purchase.title')} Listesi (${_items.length})',
                                  icon: Icons.list_alt_rounded,
                                  padding: isMobileLayout
                                      ? const EdgeInsets.all(12)
                                      : EdgeInsets.zero,
                                  child: isMobileLayout
                                      ? Column(
                                          children: [
                                            _buildMobileTableActions(),
                                            const SizedBox(height: 12),
                                            _buildItemsTable(),
                                          ],
                                        )
                                      : _buildItemsTable(),
                                  action: isMobileLayout
                                      ? null
                                      : _buildTableActions(),
                                  isCompact: isMobileLayout,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (isMobileLayout)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: _buildFooter(
                          subTotal,
                          totalDiscount,
                          totalVat,
                          grandTotal,
                          totalOtv: totalOtv,
                          totalOiv: totalOiv,
                          totalTevkifat: totalTevkifat,
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 0,
                        child: _buildFooterQuickAddButton(),
                      ),
                    ],
                  )
                else
                  // Footer
                  _buildFooter(
                    subTotal,
                    totalDiscount,
                    totalVat,
                    grandTotal,
                    totalOtv: totalOtv,
                    totalOiv: totalOiv,
                    totalTevkifat: totalTevkifat,
                  ),
              ],
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(24),
    Widget? action,
    bool isCompact = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: isCompact ? 8 : 12,
            offset: Offset(0, isCompact ? 2 : 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 12 : 16,
              isCompact ? 10 : 12,
              isCompact ? 12 : 16,
              0,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 5 : 6),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    color: _primaryColor,
                    size: isCompact ? 15 : 16,
                  ),
                ),
                SizedBox(width: isCompact ? 8 : 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompact ? 13 : 14,
                      fontWeight: FontWeight.w700,
                      color: _textColor,
                    ),
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 8), action],
              ],
            ),
          ),
          SizedBox(height: isCompact ? 8 : 10),
          const Divider(height: 1, color: _borderColor),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  Widget _buildAddItemActionButton({bool compact = false}) {
    return Tooltip(
      message: '${tr('common.add')} (F1)',
      child: SizedBox(
        height: compact ? 30 : 32,
        child: ElevatedButton.icon(
          onPressed: _addItem,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(compact ? 8 : 6),
            ),
            elevation: 0,
          ),
          icon: Icon(Icons.add, size: compact ? 14 : 16),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('common.add'),
                style: TextStyle(fontSize: compact ? 12 : 13),
              ),
              if (!compact) ...[
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
    );
  }

  Widget _buildFooterQuickAddButton() {
    return Tooltip(
      message: '${tr('common.add')} (F1)',
      child: SizedBox(
        height: 28,
        child: ElevatedButton.icon(
          onPressed: _addItem,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.add, size: 12),
          label: Text(
            tr('common.add'),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralInfoFields({bool isDense = false}) {
    return Column(
      children: [
        // Cari Hesap Autocomplete (Order: 1)
        _buildSupplierAutocomplete(isDense: isDense),
        SizedBox(height: isDense ? 8 : 16),
        // Tarih
        _buildInputField(
          controller: _dateController,
          label: tr('common.date'),
          readOnly: true,
          isDense: isDense,
          onTap: () => _selectDate(context),
          suffixIcon: _dateController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20, color: _primaryColor),
                  onPressed: () {
                    setState(() {
                      _dateController.clear();
                    });
                  },
                  tooltip: tr('common.clear'),
                )
              : const Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: Colors.grey,
                ),
        ),
        SizedBox(height: isDense ? 8 : 16),
        // İskonto (Order: 2)
        _buildInputField(
          controller: _discountRateController,
          label: tr('purchase.field.discount_rate'),
          isNumeric: true,
          maxDecimalDigits: 2,
          focusOrder: 2,
          isDense: isDense,
        ),
        SizedBox(height: isDense ? 8 : 16),
        // Açıklama (Order: 3)
        // Açıklama (Order: 3)
        AkilliAciklamaInput(
          controller: _descriptionController,
          label: tr('shipment.field.description'),
          category: 'purchase_description',
          isDense: isDense,
          defaultItems: [
            tr('smart_select.purchase.desc.1'),
            tr('smart_select.purchase.desc.2'),
            tr('smart_select.purchase.desc.3'),
            tr('smart_select.purchase.desc.4'),
            tr('smart_select.purchase.desc.5'),
          ],
        ),
      ],
    );
  }

  Widget _buildSupplierAutocomplete({bool isDense = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              tr('purchase.find_customer'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
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
        LayoutBuilder(
          builder: (context, constraints) {
            return RawAutocomplete<CariHesapModel>(
              focusNode: _supplierFocusNode,
              textEditingController: _supplierNameController,
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<CariHesapModel>.empty();
                }

                // Debounce Logic
                if (_supplierSearchDebounce?.isActive ?? false) {
                  _supplierSearchDebounce!.cancel();
                }

                final completer = Completer<Iterable<CariHesapModel>>();

                _supplierSearchDebounce = Timer(
                  const Duration(milliseconds: 500),
                  () async {
                    try {
                      final results = await CariHesaplarVeritabaniServisi()
                          .cariHesaplariGetir(
                            aramaTerimi: textEditingValue.text,
                            sayfaBasinaKayit: 10, // Google-like limit
                          );
                      if (!completer.isCompleted) completer.complete(results);
                    } catch (e) {
                      if (!completer.isCompleted) completer.complete([]);
                    }
                  },
                );

                return completer.future;
              },
              onSelected: (CariHesapModel selection) {
                setState(() {
                  _selectedSupplierId = selection.id;
                  _selectedSupplierCode = selection.kodNo;
                  // _selectedSupplierName = selection.adi;
                  // Controller is updated automatically by RawAutocomplete,
                  // but we might want to ensure it shows the name properly.
                  // Default behavior puts generic `toString` if displayStringForOption not distinct.
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
                    return FocusTraversalOrder(
                      order: const NumericFocusOrder(1),
                      child: TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        style: const TextStyle(fontSize: 17),
                        decoration: InputDecoration(
                          hintText: tr('common.search'),
                          hintStyle: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.3),
                            fontSize: 16,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, color: Colors.grey),
                            onPressed: _openSupplierSearchDialog,
                          ),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.blue.shade700.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.blue.shade700.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.blue.shade700,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: isDense ? 4 : 10,
                          ),
                        ),
                        onFieldSubmitted: (String value) {
                          onFieldSubmitted();
                        },
                      ),
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
                            maxWidth:
                                constraints.maxWidth, // Use LayoutBuilder width
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
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
                                          final term = _supplierNameController
                                              .text
                                              .toLowerCase();
                                          String subtitle =
                                              '${option.fatSehir} • ${option.hesapTuru}';

                                          if (term.isNotEmpty) {
                                            if (option.kodNo
                                                .toLowerCase()
                                                .contains(term)) {
                                              subtitle = 'Kod: ${option.kodNo}';
                                            } else if (option.telefon1.contains(
                                                  term,
                                                ) ||
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
    );
  }

  void _openSupplierSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _SupplierSearchDialogWrapper(
        onSelect: (supplier) {
          setState(() {
            _selectedSupplierId = supplier.id;
            _selectedSupplierCode = supplier.kodNo;
            // _selectedSupplierName = supplier.adi; // Unused
            _supplierNameController.text = supplier.adi;
          });
        },
      ),
    );
  }

  Widget _buildProductEntryFields({bool isDense = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 640;
        final bool twoColumn = constraints.maxWidth > 560;
        final bool threeColumn = constraints.maxWidth > 860;
        final bool denseMode = isDense || isCompact;
        final double spacing = denseMode ? 8 : 12;
        final bool showMetaFields =
            _genelAyarlar.otvKullanimi ||
            _genelAyarlar.oivKullanimi ||
            _genelAyarlar.kdvTevkifati;

        final warehouseField = _buildDropdownField<int>(
          value: _selectedWarehouseId,
          label: tr('purchase.field.warehouse'),
          isRequired: true,
          isDense: denseMode,
          items: _allWarehouses
              .map((d) => DropdownMenuItem(value: d.id, child: Text(d.ad)))
              .toList(),
          onChanged: (val) => setState(() => _selectedWarehouseId = val),
          focusOrder: 4,
        );

        final codeField = _buildProductAutocompleteField(
          controller: _productCodeController,
          focusNode: _productCodeFocusNode,
          label: tr('common.product_or_production'),
          searchHint: tr('common.search_fields.code_name_barcode'),
          isRequired: true,
          isCodeField: true,
          isDense: denseMode,
          suffixIcon: IconButton(
            icon: Icon(Icons.search, size: isCompact ? 18 : 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _findProduct(query: _productCodeController.text),
          ),
          onExternalSubmit: () =>
              _findProduct(query: _productCodeController.text),
          focusOrder: 6,
        );

        final nameField = _buildProductAutocompleteField(
          controller: _productNameController,
          focusNode: _productNameFocusNode,
          label: tr('purchase.field.product_name'),
          searchHint: tr('common.search_fields.name_code'),
          isRequired: true,
          isCodeField: false,
          isDense: denseMode,
          suffixIcon: IconButton(
            icon: Icon(Icons.search, size: isCompact ? 18 : 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _findProduct(query: _productNameController.text),
          ),
          onExternalSubmit: () =>
              _findProduct(query: _productNameController.text),
          focusOrder: 7,
        );

        final Widget priceField = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputField(
              controller: _unitPriceController,
              label: tr('purchase.field.unit_price'),
              isRequired: true,
              isNumeric: true,
              isDense: denseMode,
              maxDecimalDigits: _genelAyarlar.fiyatOndalik,
              focusNode: _priceFocusNode,
              focusOrder: 8,
            ),
            ValueListenableBuilder(
              valueListenable: _unitPriceController,
              builder: (context, value, child) {
                final price = _parseFlexibleDouble(
                  _unitPriceController.text,
                  maxDecimalDigits: _genelAyarlar.fiyatOndalik,
                );
                final vat = _parseFlexibleDouble(
                  _vatRateController.text,
                  maxDecimalDigits: 2,
                );
                final otv = _parseFlexibleDouble(_otvRateController.text);
                final oiv = _parseFlexibleDouble(_oivRateController.text);

                double currentPrice = price;
                if (_vatStatus == 'included') {
                  currentPrice /= (1 + vat / 100);
                }
                double divisor = 1.0;
                if (_otvStatus == 'included') divisor += (otv / 100);
                if (_oivStatus == 'included') divisor += (oiv / 100);

                final hamFiyat = currentPrice / divisor;

                if (price > 0 &&
                    (_vatStatus == 'included' ||
                        _otvStatus == 'included' ||
                        _oivStatus == 'included')) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      '${tr('common.raw')}: ${_fmt(hamFiyat)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        );

        final currencyField = _buildDropdownField<String>(
          value: _selectedCurrency,
          label: tr('purchase.field.currency'),
          isRequired: true,
          isDense: denseMode,
          items: _genelAyarlar.kullanilanParaBirimleri
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedCurrency = val);
              _updateCurrentRate(val);
            }
          },
          focusOrder: 9,
        );

        final vatStatusField = _buildDropdownField<String>(
          value: _vatStatus,
          label: tr('purchase.field.vat_status'),
          isRequired: true,
          isDense: denseMode,
          items: [
            DropdownMenuItem(
              value: 'excluded',
              child: Text(tr('purchase.field.vat_excluded')),
            ),
            DropdownMenuItem(
              value: 'included',
              child: Text(tr('purchase.field.vat_included')),
            ),
          ],
          onChanged: (val) => setState(() => _vatStatus = val!),
          focusOrder: 10,
        );

        final quantityField = _buildInputField(
          controller: _quantityController,
          label: tr('purchase.field.quantity'),
          isRequired: true,
          isNumeric: true,
          isDense: denseMode,
          maxDecimalDigits: _genelAyarlar.miktarOndalik,
          focusNode: _quantityFocusNode,
          onFieldSubmitted: (_) => _completePurchase(),
          focusOrder: 16,
        );

        final tevkifatField = _buildDropdownField<String>(
          value: _kdvTevkifatValue,
          label: tr('purchase.field.vat_withholding'),
          isRequired: true,
          isDense: denseMode,
          items: [
            DropdownMenuItem(value: '0', child: Text(tr('tevkifat.none'))),
            DropdownMenuItem(
              value: '2/10',
              child: Text(tr('tevkifat.2_10_freight')),
            ),
            DropdownMenuItem(
              value: '3/10',
              child: Text(tr('tevkifat.3_10_advertising')),
            ),
            DropdownMenuItem(
              value: '4/10',
              child: Text(tr('tevkifat.4_10_construction')),
            ),
            DropdownMenuItem(
              value: '5/10',
              child: Text(tr('tevkifat.5_10_catering_metal')),
            ),
            DropdownMenuItem(
              value: '7/10',
              child: Text(tr('tevkifat.7_10_maintenance')),
            ),
            DropdownMenuItem(
              value: '9/10',
              child: Text(tr('tevkifat.9_10_cleaning')),
            ),
            DropdownMenuItem(
              value: '10/10',
              child: Text(tr('tevkifat.10_10_full')),
            ),
          ],
          onChanged: (val) => setState(() => _kdvTevkifatValue = val!),
          focusOrder: 15,
        );

        return Form(
          key: _itemFormKey,
          child: Column(
            children: [
              _buildResponsiveRow(
                isWide: threeColumn,
                spacing: spacing,
                children: [warehouseField, codeField, nameField],
              ),
              SizedBox(height: denseMode ? 8 : 16),
              _buildResponsiveRow(
                isWide: threeColumn,
                spacing: spacing,
                children: [priceField, currencyField, vatStatusField],
              ),
              if (showMetaFields) SizedBox(height: denseMode ? 8 : 16),
              if (_genelAyarlar.otvKullanimi)
                _buildResponsiveRow(
                  isWide: twoColumn,
                  spacing: spacing,
                  children: [
                    _buildInputField(
                      controller: _otvRateController,
                      label: tr('purchase.field.otv_rate'),
                      isNumeric: true,
                      isDense: denseMode,
                      focusOrder: 11,
                    ),
                    _buildDropdownField<String>(
                      value: _otvStatus,
                      label: tr('purchase.field.otv_status'),
                      isDense: denseMode,
                      items: [
                        DropdownMenuItem(
                          value: 'excluded',
                          child: Text(tr('purchase.field.vat_excluded')),
                        ),
                        DropdownMenuItem(
                          value: 'included',
                          child: Text(tr('purchase.field.vat_included')),
                        ),
                      ],
                      onChanged: (val) => setState(() => _otvStatus = val!),
                      focusOrder: 12,
                    ),
                  ],
                ),
              if (_genelAyarlar.otvKullanimi && _genelAyarlar.oivKullanimi)
                SizedBox(height: denseMode ? 8 : 12),
              if (_genelAyarlar.oivKullanimi)
                _buildResponsiveRow(
                  isWide: twoColumn,
                  spacing: spacing,
                  children: [
                    _buildInputField(
                      controller: _oivRateController,
                      label: tr('purchase.field.oiv_rate'),
                      isNumeric: true,
                      isDense: denseMode,
                      focusOrder: 13,
                    ),
                    _buildDropdownField<String>(
                      value: _oivStatus,
                      label: tr('purchase.field.oiv_status'),
                      isDense: denseMode,
                      items: [
                        DropdownMenuItem(
                          value: 'excluded',
                          child: Text(tr('purchase.field.vat_excluded')),
                        ),
                        DropdownMenuItem(
                          value: 'included',
                          child: Text(tr('purchase.field.vat_included')),
                        ),
                      ],
                      onChanged: (val) => setState(() => _oivStatus = val!),
                      focusOrder: 14,
                    ),
                  ],
                ),
              if (_genelAyarlar.otvKullanimi || _genelAyarlar.oivKullanimi)
                SizedBox(height: denseMode ? 8 : 16),
              _buildResponsiveRow(
                isWide: _genelAyarlar.kdvTevkifati ? twoColumn : false,
                spacing: spacing,
                children: _genelAyarlar.kdvTevkifati
                    ? [quantityField, tevkifatField]
                    : [quantityField],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemsTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return _buildMobileItemsList();
        }
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
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
                indent: 0,
                endIndent: 0,
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
                  dataRowMinHeight: 60, // Increased height
                  dataRowMaxHeight: 60, // Increased height
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFF8F9FA),
                  ),
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5F6368),
                    fontSize: 12, // Reduced from 13
                    letterSpacing: 0.5,
                  ),
                  dataTextStyle: const TextStyle(
                    fontSize: 12, // Reduced from 14
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
                    DataColumn(label: Text(tr('purchase.grid.warehouse'))),
                    DataColumn(label: Text(tr('purchase.grid.code'))),
                    DataColumn(label: Text(tr('purchase.grid.barcode'))),
                    DataColumn(label: Text(tr('purchase.grid.name'))),
                    DataColumn(
                      label: Text(
                        tr('purchase.grid.vat'),
                        textAlign: TextAlign.right,
                      ),
                      numeric: true,
                    ),
                    if (_genelAyarlar.otvKullanimi)
                      DataColumn(
                        label: Text(
                          tr('purchase.grid.otv'),
                          textAlign: TextAlign.right,
                        ),
                        numeric: true,
                      ),
                    if (_genelAyarlar.oivKullanimi)
                      DataColumn(
                        label: Text(
                          tr('purchase.grid.oiv'),
                          textAlign: TextAlign.right,
                        ),
                        numeric: true,
                      ),
                    if (_genelAyarlar.kdvTevkifati)
                      DataColumn(
                        label: Text(
                          tr('purchase.grid.tevkifat'),
                          textAlign: TextAlign.right,
                        ),
                        numeric: true,
                      ),
                    DataColumn(
                      label: Text(
                        tr('purchase.grid.price'),
                        textAlign: TextAlign.right,
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        tr('common.raw_price'),
                        textAlign: TextAlign.right,
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        tr('purchase.grid.discount'),
                        textAlign: TextAlign.right,
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        tr('purchase.grid.quantity'),
                        textAlign: TextAlign.right,
                      ),
                      numeric: true,
                    ),
                    DataColumn(label: Text(tr('purchase.grid.unit'))),
                    DataColumn(
                      label: Text(
                        tr('purchase.grid.total'),
                        textAlign: TextAlign.right,
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        tr('common.rate'),
                        textAlign: TextAlign.right,
                      ),
                      numeric: true,
                    ),
                  ],
                  rows: _items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isSelected = _selectedItemIndices.contains(index);
                    return DataRow(
                      selected: isSelected,
                      color: WidgetStateProperty.resolveWith<Color?>((
                        Set<WidgetState> states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return _primaryColor.withValues(alpha: 0.08);
                        }
                        // Zebra striping for readability? Or just white.
                        // Professional usually implies clean white.
                        return null; // Transparent/White
                      }),
                      onSelectChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedItemIndices.add(index);
                          } else {
                            _selectedItemIndices.remove(index);
                          }
                        });
                      },
                      cells: [
                        DataCell(Text(item.warehouseName)),
                        DataCell(
                          Text(
                            item.code,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(Text(item.barcode)),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 200,
                            ), // Expanded width for names
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.serialNumber != null) ...[
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF2C3E50,
                                      ).withAlpha(25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${tr('products.devices.identity')}: ${item.serialNumber}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '%${FormatYardimcisi.sayiFormatlaOran(item.vatRate, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        if (_genelAyarlar.otvKullanimi)
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '%${FormatYardimcisi.sayiFormatlaOran(item.otvRate, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        if (_genelAyarlar.oivKullanimi)
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '%${FormatYardimcisi.sayiFormatlaOran(item.oivRate, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        if (_genelAyarlar.kdvTevkifati)
                          DataCell(
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${(item.kdvTevkifatOrani * 10).round()}/10',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        // Price
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildEditableCell(
                              index: index,
                              field: 'price',
                              value: item.unitPrice,
                              suffix: ' ${item.currency}',
                              onSubmitted: (val) {
                                setState(() {
                                  _items[index] = item.copyWith(unitPrice: val);
                                });
                              },
                            ),
                          ),
                        ),
                        // Ham Fiyat
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildEditableCell(
                              index: index,
                              field: 'netPrice',
                              value: item.netUnitPrice,
                              onSubmitted: (val) {
                                setState(() {
                                  double newUnitPrice = val;
                                  if (item.vatIncluded) {
                                    newUnitPrice =
                                        val * (1 + item.vatRate / 100);
                                  }
                                  _items[index] = item.copyWith(
                                    unitPrice: newUnitPrice,
                                  );
                                });
                              },
                            ),
                          ),
                        ),
                        // Discount
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildEditableCell(
                              index: index,
                              field: 'discount',
                              value: item.discountRate,
                              prefix: '%',
                              onSubmitted: (val) {
                                setState(() {
                                  _items[index] = item.copyWith(
                                    discountRate: val,
                                  );
                                });
                              },
                            ),
                          ),
                        ),
                        // Quantity
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildEditableCell(
                              index: index,
                              field: 'quantity',
                              value: item.quantity,
                              onSubmitted: (val) {
                                setState(() {
                                  _items[index] = item.copyWith(quantity: val);
                                });
                              },
                            ),
                          ),
                        ),
                        DataCell(Text(item.unit)),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${_fmt(item.total)} ${item.currency}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildEditableCell(
                              index: index,
                              field: 'exchangeRate',
                              value: item.exchangeRate,
                              suffix: ' ${tr('common.currency.try')}',
                              onSubmitted: (val) {
                                setState(() {
                                  _items[index] = item.copyWith(
                                    exchangeRate: val,
                                  );
                                });
                              },
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

  Widget _buildMobileTableActions() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_selectedItemIndices.isNotEmpty)
            _buildMobileActionButton(
              icon: Icons.delete_outline_rounded,
              label:
                  '${tr('common.delete_selected_items')} (${_selectedItemIndices.length})',
              color: const Color(0xFFEA4335),
              onTap: _deleteSelected,
            ),
          _buildMobileActionButton(
            icon: Icons.delete_forever_outlined,
            label: tr('common.delete_all'),
            color: const Color(0xFFEF5350),
            onTap: _items.isEmpty ? null : _deleteAllItems,
          ),
          _buildMobileActionButton(
            icon: Icons.percent_rounded,
            label: tr('purchase.button.invoice_discount'),
            color: _primaryColor,
            onTap: _items.isEmpty ? null : _showInvoiceDiscountDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final bool enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: enabled ? 1 : 0.45),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileItemsList() {
    if (_items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEAECEF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            Text(
              tr('purchase.error.no_items'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildMobileItemCard(index, _items[index]);
      },
    );
  }

  Widget _buildMobileItemCard(int index, PurchaseItem item) {
    final bool isSelected = _selectedItemIndices.contains(index);
    final bool showSerial =
        item.serialNumber != null && item.serialNumber!.trim().isNotEmpty;
    final bool twoColumn = MediaQuery.sizeOf(context).width > 420;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? _primaryColor.withValues(alpha: 0.05)
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? _primaryColor.withValues(alpha: 0.35)
              : _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
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
                          _selectedItemIndices.add(index);
                        } else {
                          _selectedItemIndices.remove(index);
                        }
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.code} • ${item.warehouseName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (showSerial) ...[
                        const SizedBox(height: 6),
                        _buildMobileMetaChip(
                          label: tr('products.devices.identity'),
                          value: item.serialNumber!,
                          color: _primaryColor,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_fmt(item.total)} ${item.currency}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _primaryColor,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeItemAt(index),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      tooltip: tr('common.delete'),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 18, color: Color(0xFFEAECEF)),
            _buildResponsiveRow(
              isWide: twoColumn,
              spacing: 8,
              children: [
                _buildMobileEditableCellBlock(
                  index: index,
                  label: tr('purchase.grid.price'),
                  field: 'price',
                  value: item.unitPrice,
                  suffix: ' ${item.currency}',
                  onSubmitted: (val) {
                    setState(() {
                      if (index >= _items.length) return;
                      _items[index] = _items[index].copyWith(unitPrice: val);
                    });
                  },
                ),
                _buildMobileEditableCellBlock(
                  index: index,
                  label: '${tr('purchase.grid.quantity')} (${item.unit})',
                  field: 'quantity',
                  value: item.quantity,
                  onSubmitted: (val) {
                    setState(() {
                      if (index >= _items.length) return;
                      _items[index] = _items[index].copyWith(quantity: val);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildResponsiveRow(
              isWide: twoColumn,
              spacing: 8,
              children: [
                _buildMobileEditableCellBlock(
                  index: index,
                  label: tr('common.raw_price'),
                  field: 'netPrice',
                  value: item.netUnitPrice,
                  onSubmitted: (val) {
                    setState(() {
                      if (index >= _items.length) return;
                      final current = _items[index];
                      double newUnitPrice = val;
                      if (current.vatIncluded) {
                        newUnitPrice = val * (1 + current.vatRate / 100);
                      }
                      _items[index] = current.copyWith(unitPrice: newUnitPrice);
                    });
                  },
                ),
                _buildMobileEditableCellBlock(
                  index: index,
                  label: tr('purchase.grid.discount'),
                  field: 'discount',
                  value: item.discountRate,
                  prefix: '%',
                  onSubmitted: (val) {
                    setState(() {
                      if (index >= _items.length) return;
                      _items[index] = _items[index].copyWith(discountRate: val);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildMobileEditableCellBlock(
              index: index,
              label: tr('common.rate'),
              field: 'exchangeRate',
              value: item.exchangeRate,
              suffix: ' ${tr('common.currency.try')}',
              onSubmitted: (val) {
                setState(() {
                  if (index >= _items.length) return;
                  _items[index] = _items[index].copyWith(exchangeRate: val);
                });
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildMobileMetaChip(
                    label: tr('purchase.grid.vat'),
                    value:
                        '%${FormatYardimcisi.sayiFormatlaOran(item.vatRate, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci)} • ${item.vatIncluded ? tr('purchase.field.vat_included') : tr('purchase.field.vat_excluded')}',
                  ),
                  if (_genelAyarlar.otvKullanimi || item.otvRate > 0)
                    _buildMobileMetaChip(
                      label: tr('purchase.grid.otv'),
                      value:
                          '%${FormatYardimcisi.sayiFormatlaOran(item.otvRate, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci)} • ${item.otvIncluded ? tr('purchase.field.vat_included') : tr('purchase.field.vat_excluded')}',
                    ),
                  if (_genelAyarlar.oivKullanimi || item.oivRate > 0)
                    _buildMobileMetaChip(
                      label: tr('purchase.grid.oiv'),
                      value:
                          '%${FormatYardimcisi.sayiFormatlaOran(item.oivRate, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci)} • ${item.oivIncluded ? tr('purchase.field.vat_included') : tr('purchase.field.vat_excluded')}',
                    ),
                  if (_genelAyarlar.kdvTevkifati || item.kdvTevkifatOrani > 0)
                    _buildMobileMetaChip(
                      label: tr('purchase.grid.tevkifat'),
                      value: '${(item.kdvTevkifatOrani * 10).round()}/10',
                    ),
                ],
              ),
            ),
            if (item.barcode.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${tr('purchase.grid.barcode')}: ${item.barcode}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileEditableCellBlock({
    required int index,
    required String label,
    required String field,
    required double value,
    required void Function(double value) onSubmitted,
    String prefix = '',
    String suffix = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: _buildEditableCell(
              index: index,
              field: field,
              value: value,
              prefix: prefix,
              suffix: suffix,
              onSubmitted: onSubmitted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileMetaChip({
    required String label,
    required String value,
    Color color = _primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildFooter(
    double subTotal,
    double discount,
    double vat,
    double grandTotal, {
    double totalOtv = 0,
    double totalOiv = 0,
    double totalTevkifat = 0,
  }) {
    // Toplam Tutar (Gross)
    // İskonto
    // Ara Toplam (Net before tax)
    // Toplam KDV
    // Genel Toplam (Grand Total)

    final bool showCombinedTaxes =
        _genelAyarlar.otvKullanimi || _genelAyarlar.oivKullanimi;
    final bool showTevkifatRow =
        _genelAyarlar.kdvTevkifati || totalTevkifat > 0;
    final bool compactFooter = showCombinedTaxes || _genelAyarlar.kdvTevkifati;
    final double rowTopPadding = compactFooter ? 2 : 4;
    final double grandRowTopPadding = compactFooter ? 6 : 8;
    final double grandBadgeVerticalPadding = compactFooter ? 3 : 4;

    final double araToplam =
        subTotal + (showCombinedTaxes ? 0 : (totalOtv + totalOiv)) - discount;
    final double toplamVergiler = vat + totalOtv + totalOiv;
    final bool isMobileLayout = MediaQuery.sizeOf(context).width < 900;

    if (isMobileLayout) {
      return _buildMobileFooter(
        subTotal,
        discount,
        vat,
        grandTotal,
        totalOtv: totalOtv,
        totalOiv: totalOiv,
        totalTevkifat: totalTevkifat,
        showCombinedTaxes: showCombinedTaxes,
        showTevkifatRow: showTevkifatRow,
        araToplam: araToplam,
        toplamVergiler: toplamVergiler,
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: compactFooter ? 8 : 12,
      ),
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
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Totals Column - Dikey hizalı tablo yapısı
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Table(
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    columnWidths: const {
                      0: IntrinsicColumnWidth(), // Label (sağa hizalı)
                      1: FixedColumnWidth(16), // Boşluk
                      2: IntrinsicColumnWidth(), // Değer (sola hizalı)
                      3: FixedColumnWidth(8), // Boşluk
                      4: FixedColumnWidth(
                        80,
                      ), // Currency/Select (sabit genişlik)
                    },
                    children: [
                      // 1. Toplam Tutar
                      TableRow(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              tr('purchase.footer.subtotal'),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _fmt(subTotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _textColor,
                              ),
                            ),
                          ),
                          const SizedBox(),
                          _buildFooterCurrencyDropdown(),
                        ],
                      ),
                      if (!showCombinedTaxes && totalOtv > 0)
                        TableRow(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: rowTopPadding),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  tr('tax.total_otv'),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(),
                            Padding(
                              padding: EdgeInsets.only(top: rowTopPadding),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '+${_fmt(totalOtv)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(),
                            Padding(
                              padding: EdgeInsets.only(top: rowTopPadding),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _invoiceCurrency,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _textColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (!showCombinedTaxes && totalOiv > 0)
                        TableRow(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: rowTopPadding),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  tr('tax.total_oiv'),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(),
                            Padding(
                              padding: EdgeInsets.only(top: rowTopPadding),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '+${_fmt(totalOiv)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(),
                            Padding(
                              padding: EdgeInsets.only(top: rowTopPadding),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _invoiceCurrency,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _textColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      // 2. İskonto
                      TableRow(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: rowTopPadding),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                tr('purchase.footer.discount'),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(),
                          Padding(
                            padding: EdgeInsets.only(top: rowTopPadding),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '-${_fmt(discount)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(),
                          Padding(
                            padding: EdgeInsets.only(top: rowTopPadding),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _invoiceCurrency,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _textColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // 3. Ara Toplam
                      TableRow(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: rowTopPadding),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                tr('common.subtotal'),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(),
                          Padding(
                            padding: EdgeInsets.only(top: rowTopPadding),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                _fmt(araToplam),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _textColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(),
                          Padding(
                            padding: EdgeInsets.only(top: rowTopPadding),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _invoiceCurrency,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _textColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (showCombinedTaxes)
                        TableRow(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: rowTopPadding),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  tr('tax.total_vat_otv_oiv'),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(),
                            Padding(
                              padding: EdgeInsets.only(top: rowTopPadding),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _fmt(toplamVergiler),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _textColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(),
                            Padding(
                              padding: EdgeInsets.only(top: rowTopPadding),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _invoiceCurrency,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _textColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        // 4. Toplam Kdv
                        TableRow(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: rowTopPadding),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  tr('purchase.footer.vat_total'),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(),
                            Padding(
                              padding: EdgeInsets.only(top: rowTopPadding),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _fmt(vat),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _textColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(),
                            Padding(
                              padding: EdgeInsets.only(top: rowTopPadding),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _invoiceCurrency,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _textColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (showTevkifatRow)
                        TableRow(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: rowTopPadding),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  tr('tax.total_withholding'),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(),
                            Padding(
                              padding: EdgeInsets.only(top: rowTopPadding),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  totalTevkifat > 0
                                      ? '-${_fmt(totalTevkifat)}'
                                      : _fmt(0),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: totalTevkifat > 0
                                        ? Colors.red
                                        : _textColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(),
                            Padding(
                              padding: EdgeInsets.only(top: rowTopPadding),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _invoiceCurrency,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _textColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      // 5. Genel Toplam
                      TableRow(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: grandRowTopPadding),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: grandBadgeVerticalPadding,
                              ),
                              decoration: BoxDecoration(
                                color: IslemTuruRenkleri.alisArkaplan,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  tr('purchase.footer.grand_total'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: IslemTuruRenkleri.alisMetin,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(),
                          Padding(
                            padding: EdgeInsets.only(top: grandRowTopPadding),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Baseline(
                                  baseline: 18,
                                  baselineType: TextBaseline.alphabetic,
                                  child: Text(
                                    _fmt(grandTotal),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: IslemTuruRenkleri.alisMetin,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(),
                          Padding(
                            padding: EdgeInsets.only(top: grandRowTopPadding),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Baseline(
                                  baseline: 18,
                                  baselineType: TextBaseline.alphabetic,
                                  child: Text(
                                    _invoiceCurrency,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: IslemTuruRenkleri.alisMetin,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 24),

              // Save Button - Genel Toplam ile alttan hizalı
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: _completePurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      tr('purchase.title'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.3,
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
  }

  Widget _buildMobileFooter(
    double subTotal,
    double discount,
    double vat,
    double grandTotal, {
    required double totalOtv,
    required double totalOiv,
    required double totalTevkifat,
    required bool showCombinedTaxes,
    required bool showTevkifatRow,
    required double araToplam,
    required double toplamVergiler,
  }) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('purchase.footer.grand_total'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmt(grandTotal)} $_invoiceCurrency',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: IslemTuruRenkleri.alisMetin,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _completePurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(
                      Icons.shopping_cart_checkout_rounded,
                      size: 18,
                    ),
                    label: Text(
                      tr('purchase.title'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  tr('purchase.field.currency'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 96, child: _buildFooterCurrencyDropdown()),
              ],
            ),
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMobileFooterChip(
                      tr('purchase.footer.subtotal'),
                      _fmt(subTotal),
                    ),
                    const SizedBox(width: 8),
                    _buildMobileFooterChip(
                      tr('purchase.footer.discount'),
                      '-${_fmt(discount)}',
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    _buildMobileFooterChip(
                      tr('common.subtotal'),
                      _fmt(araToplam),
                    ),
                    const SizedBox(width: 8),
                    _buildMobileFooterChip(
                      showCombinedTaxes
                          ? tr('tax.total_vat_otv_oiv')
                          : tr('purchase.footer.vat_total'),
                      _fmt(showCombinedTaxes ? toplamVergiler : vat),
                      color: Colors.blue.shade700,
                    ),
                    if (!showCombinedTaxes && totalOtv > 0) ...[
                      const SizedBox(width: 8),
                      _buildMobileFooterChip(
                        tr('tax.total_otv'),
                        '+${_fmt(totalOtv)}',
                        color: Colors.blue.shade700,
                      ),
                    ],
                    if (!showCombinedTaxes && totalOiv > 0) ...[
                      const SizedBox(width: 8),
                      _buildMobileFooterChip(
                        tr('tax.total_oiv'),
                        '+${_fmt(totalOiv)}',
                        color: Colors.blue.shade700,
                      ),
                    ],
                    if (showTevkifatRow) ...[
                      const SizedBox(width: 8),
                      _buildMobileFooterChip(
                        tr('tax.total_withholding'),
                        totalTevkifat > 0 ? '-${_fmt(totalTevkifat)}' : _fmt(0),
                        color: totalTevkifat > 0 ? Colors.red : Colors.blueGrey,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFooterChip(String label, String value, {Color? color}) {
    final effectiveColor = color ?? _primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: effectiveColor,
            ),
          ),
          Text(
            '$value $_invoiceCurrency',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }

  // Styled Dropdown matching 'borc_alacak_dekontu_isle_sayfasi.dart'
  Widget _buildFooterCurrencyDropdown() {
    return DropdownButtonFormField<String>(
      value: _invoiceCurrency,
      items: _genelAyarlar.kullanilanParaBirimleri
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text(
                c,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: _items.isNotEmpty
          ? null
          : (val) {
              if (val != null) {
                _invoiceCurrency = val;
                _updateInvoiceRate(val);
              }
            },
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: _primaryColor.withValues(alpha: 0.3)),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _primaryColor.withValues(alpha: 0.3)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
      ),
      icon: const Icon(Icons.arrow_drop_down, color: _primaryColor, size: 18),
      style: const TextStyle(
        fontSize: 13,
        color: _textColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildResponsiveRow({
    required bool isWide,
    required List<Widget> children,
    double spacing = 12,
    CrossAxisAlignment wideCrossAxisAlignment = CrossAxisAlignment.start,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.first;

    if (isWide) {
      return Row(
        crossAxisAlignment: wideCrossAxisAlignment,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i != children.length - 1) SizedBox(width: spacing),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }

  // Styled input decoration matching urun_ekle_sayfasi.dart
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
    bool isNumeric = false,
    int? maxDecimalDigits,
    bool readOnly = false,
    FocusNode? focusNode,
    Widget? suffixIcon,
    VoidCallback? onTap,
    void Function(String)? onFieldSubmitted,
    int? focusOrder,
    bool isDense = false,
  }) {
    final Color effectiveColor = isRequired
        ? Colors.red.shade700
        : Colors.blue.shade700;
    final bool isCompact = MediaQuery.sizeOf(context).width < 640;

    Widget inputField = TextFormField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumeric
          ? [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              CurrencyInputFormatter(
                binlik: _genelAyarlar.binlikAyiraci,
                ondalik: _genelAyarlar.ondalikAyiraci,
                maxDecimalDigits: maxDecimalDigits,
              ),
              LengthLimitingTextInputFormatter(20),
            ]
          : null,
      style: TextStyle(fontSize: isCompact ? 15 : 17),
      validator: isRequired
          ? (value) {
              if (value == null || value.isEmpty) {
                return tr('validation.required');
              }
              return null;
            }
          : null,
      onTap: () {
        if (onTap != null && suffixIcon == null) {
          onTap();
        }
        if (controller.text.isNotEmpty) {
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }
      },
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        suffixIcon: onTap == null ? suffixIcon : null,
        hintStyle: TextStyle(
          color: Colors.grey.withValues(alpha: 0.3),
          fontSize: isCompact ? 14 : 16,
        ),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: effectiveColor.withValues(alpha: 0.3)),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: effectiveColor.withValues(alpha: 0.3)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: effectiveColor, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          vertical: isDense ? 4 : (isCompact ? 8 : 10),
        ),
      ),
    );

    if (onTap != null) {
      inputField = Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              mouseCursor: SystemMouseCursors.click,
              child: IgnorePointer(child: inputField),
            ),
          ),
          ...[suffixIcon].whereType<Widget>(),
        ],
      );
    }

    if (focusOrder != null) {
      inputField = FocusTraversalOrder(
        order: NumericFocusOrder(focusOrder.toDouble()),
        child: inputField,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: isCompact ? 13 : 14,
          ),
        ),
        SizedBox(height: isDense ? 2 : 4),
        inputField,
      ],
    );
  }

  // Styled dropdown matching urun_ekle_sayfasi.dart
  Widget _buildDropdownField<T>({
    required T? value,
    required String label,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool isRequired = false,
    int? focusOrder,
    bool isDense = false,
  }) {
    final Color effectiveColor = isRequired
        ? Colors.red.shade700
        : Colors.blue.shade700;
    final bool isCompact = MediaQuery.sizeOf(context).width < 640;

    Widget dropdown = DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      icon: Icon(Icons.arrow_drop_down, color: effectiveColor),
      validator: isRequired
          ? (value) {
              if (value == null) {
                return tr('validation.required');
              }
              return null;
            }
          : null,
      decoration: InputDecoration(
        hintStyle: TextStyle(
          color: Colors.grey.withValues(alpha: 0.3),
          fontSize: isCompact ? 14 : 16,
        ),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: effectiveColor.withValues(alpha: 0.3)),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: effectiveColor.withValues(alpha: 0.3)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: effectiveColor, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          vertical: isDense ? 4 : (isCompact ? 8 : 10),
        ),
      ),
    );

    if (focusOrder != null) {
      dropdown = FocusTraversalOrder(
        order: NumericFocusOrder(focusOrder.toDouble()),
        child: dropdown,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: isCompact ? 13 : 14,
          ),
        ),
        SizedBox(height: isDense ? 2 : 4),
        dropdown,
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
    VoidCallback? onExternalSubmit, // Renamed to avoid shadowing
    int? focusOrder,
    bool isDense = false,
  }) {
    final effectiveColor = isRequired
        ? Colors.red.shade700
        : Colors.blue.shade700;
    final bool isCompact = MediaQuery.sizeOf(context).width < 640;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isCompact && searchHint != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  isRequired ? '$label *' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: effectiveColor,
                    fontSize: isCompact ? 13 : 14,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  searchHint,
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8.5,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isRequired ? '$label *' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: effectiveColor,
                  fontSize: isCompact ? 13 : 14,
                ),
              ),
              if (searchHint != null) ...[
                const SizedBox(height: 2),
                Text(
                  searchHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 9 : 10,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        SizedBox(height: isDense ? 2 : 4),
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
                      // Hem ürünleri hem de üretimleri paralel olarak ara
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

                      // Üretimleri UrunModel'e dönüştür (aynı yapıya sahipler)
                      final uretimlerAsUrun = uretimler
                          .map(
                            (u) => UrunModel(
                              id: u.id,
                              kod: u.kod,
                              ad: '${u.ad} (Üretim)', // Üretim olduğunu belirtmek için
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

                      // Birleştir: Önce ürünler, sonra üretimler
                      final combined = [...urunler, ...uretimlerAsUrun];

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
                // If we select from Name field, we must ensure Code field is updated too, and vice versa.
                // _fillProductFields handles distinct updates.
                // But we must prevent infinite loops if they trigger each other (they don't, manually called).
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

                              // Üretim mi kontrol et (adının sonunda "(Üretim)" var mı)
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

                              // Stock styling
                              final bool hasStock = option.stok > 0;
                              final Color stockBgColor = hasStock
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE);
                              final Color stockTextColor = hasStock
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828);

                              // Item type badge (Ürün veya Üretim)
                              final Color typeBgColor = isProduction
                                  ? const Color(0xFFFFF3E0)
                                  : const Color(0xFFE3F2FD);
                              final Color typeTextColor = isProduction
                                  ? const Color(0xFFE65100)
                                  : const Color(0xFF1565C0);

                              return InkWell(
                                onTap: () => onSelected(option),
                                hoverColor: const Color(0xFFF5F7FA),
                                child: Padding(
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
                                          // Ürün/Üretim type badge
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
                    Widget field = TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      style: TextStyle(fontSize: isCompact ? 15 : 17),
                      decoration: InputDecoration(
                        suffixIcon: suffixIcon,
                        hintStyle: TextStyle(
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
                          borderSide: BorderSide(
                            color: effectiveColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: isDense ? 4 : (isCompact ? 8 : 10),
                        ),
                      ),
                      onFieldSubmitted: (String value) {
                        onFieldSubmitted();
                        if (onExternalSubmit != null) {
                          onExternalSubmit();
                        }
                      },
                    );

                    if (focusOrder != null) {
                      return FocusTraversalOrder(
                        order: NumericFocusOrder(focusOrder.toDouble()),
                        child: field,
                      );
                    }
                    return field;
                  },
            );
          },
        ),
      ],
    );
  }

  String _fmt(double val) => FormatYardimcisi.sayiFormatlaOndalikli(
    val,
    binlik: _genelAyarlar.binlikAyiraci,
    ondalik: _genelAyarlar.ondalikAyiraci,
    decimalDigits: 2,
  );

  void _showIMEIInputDialog(PurchaseItem baseItem, UrunModel? product) {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.pop(context);
            }
          },
          child: Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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
                              tr('products.imei_input_title'),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF202124),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${baseItem.name} (${baseItem.code})',
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
                          tr('products.imei_input_subtitle'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A4A4A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                              ),
                            ),
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              maxLines: null,
                              expands: true,
                              autofocus: true,
                              style: const TextStyle(
                                fontSize: 15,
                                fontFamily: 'Monospace',
                                height: 1.5,
                              ),
                              decoration: InputDecoration(
                                hintText: tr('products.imei_input_hint'),
                                hintStyle: const TextStyle(
                                  color: Color(0xFF9AA0A6),
                                  fontSize: 14,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        child: Text(
                          tr('common.cancel'),
                          style: const TextStyle(
                            color: Color(0xFF606368),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          final text = controller.text.trim();
                          if (text.isEmpty) {
                            Navigator.pop(context);
                            return;
                          }

                          final lines = text
                              .split(RegExp(r'[\n\r,;]'))
                              .map((l) => l.trim())
                              .where((l) => l.isNotEmpty)
                              .toList();

                          if (lines.isEmpty) {
                            Navigator.pop(context);
                            return;
                          }

                          // Girilen her IMEI için listeye ekle
                          setState(() {
                            for (final imei in lines) {
                              _items.add(
                                baseItem.copyWith(
                                  quantity: 1,
                                  serialNumber: imei,
                                ),
                              );
                            }
                          });

                          Navigator.pop(context);
                          _productCodeController.clear();
                          _clearProductFields(shouldClearCode: false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA4335),
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
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
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
    );
  }
}

// --- PROFESSIONAL PRODUCT SEARCH DIALOG (Matching sevkiyat_olustur_sayfasi.dart) ---
class _ProductSearchDialogWrapper extends StatefulWidget {
  final Function(UrunModel) onSelect;
  const _ProductSearchDialogWrapper({required this.onSelect});
  @override
  State<_ProductSearchDialogWrapper> createState() =>
      _ProductSearchDialogWrapperState();
}

class _ProductSearchDialogWrapperState
    extends State<_ProductSearchDialogWrapper> {
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
      // Hem ürünleri hem de üretimleri paralel olarak ara
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
      );

      final results = await Future.wait([urunlerFuture, uretimlerFuture]);

      final urunler = results[0] as List<UrunModel>;
      final uretimler = results[1] as List<UretimModel>;

      // Üretimleri UrunModel'e dönüştür ve isimlendir
      final uretimlerAsUrun = uretimler
          .map(
            (u) => UrunModel(
              id: u.id,
              kod: u.kod,
              ad: '${u.ad} (Üretim)', // Üretim olduğunu belirtmek için suffix
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

      if (mounted) {
        setState(() {
          // Birleştir ve ID/AD çakışmasını önle
          _products = [...urunler, ...uretimlerAsUrun];
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
            // Header: Title + ESC + Close Button
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
            ),
            const SizedBox(height: 24),

            // Search Input (Underline Style)
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

                        // Üretim mi kontrol et (adının sonunda "(Üretim)" var mı)
                        final bool isProduction = product.ad.endsWith(
                          '(Üretim)',
                        );

                        // Item type badge styling
                        final Color typeBgColor = isProduction
                            ? const Color(0xFFFFF3E0)
                            : const Color(0xFFE3F2FD);
                        final Color typeTextColor = isProduction
                            ? const Color(0xFFE65100)
                            : const Color(0xFF1565C0);

                        return InkWell(
                          onTap: () {
                            widget.onSelect(product);
                            Navigator.pop(context);
                          },
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
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              product.ad,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF202124),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Ürün/Üretim Badge
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
                                      const SizedBox(height: 4),
                                      Text(
                                        product.kod,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF606368),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Stok Göstergesi
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: product.stok > 0
                                        ? const Color(0xFFE6F4EA)
                                        : const Color(0xFFFCE8E6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${product.stok.toStringAsFixed(0)} ${product.birim}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: product.stok > 0
                                          ? const Color(0xFF1E7E34)
                                          : const Color(0xFFC5221F),
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
    );
  }
}

// --- PROFESSIONAL SUPPLIER SEARCH DIALOG (Matching Product Search Dialog) ---
class _SupplierSearchDialogWrapper extends StatefulWidget {
  final Function(CariHesapModel) onSelect;
  const _SupplierSearchDialogWrapper({required this.onSelect});
  @override
  State<_SupplierSearchDialogWrapper> createState() =>
      _SupplierSearchDialogWrapperState();
}

class _SupplierSearchDialogWrapperState
    extends State<_SupplierSearchDialogWrapper> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<CariHesapModel> _suppliers = [];
  bool _isLoading = false;
  Timer? _debounce;
  static const Color _primaryColor = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    _searchSuppliers('');
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
      _searchSuppliers(query);
    });
  }

  Future<void> _searchSuppliers(String query) async {
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
          _suppliers = results;
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
                        tr('accounts.search_title'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('accounts.search_subtitle'),
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
                        tooltip: tr('common.close'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

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
                    hintText: tr('accounts.search_placeholder'),
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

            // Supplier List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _suppliers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.business_outlined,
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
                      itemCount: _suppliers.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      itemBuilder: (context, index) {
                        final supplier = _suppliers[index];
                        return InkWell(
                          onTap: () {
                            widget.onSelect(supplier);
                            Navigator.pop(context);
                          },
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
                                    Icons.business,
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
                                        supplier.adi,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF202124),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        supplier.kodNo,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF606368),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Bakiye Göstergesi (Borç - Alacak)
                                Builder(
                                  builder: (context) {
                                    final bakiye =
                                        supplier.bakiyeBorc -
                                        supplier.bakiyeAlacak;
                                    if (bakiye == 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: bakiye > 0
                                            ? const Color(
                                                0xFFFCE8E6,
                                              ) // Borç = kırmızı
                                            : const Color(
                                                0xFFE6F4EA,
                                              ), // Alacak = yeşil
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${bakiye.abs().toStringAsFixed(2)} ${tr('common.currency.try')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: bakiye > 0
                                              ? const Color(0xFFC5221F)
                                              : const Color(0xFF1E7E34),
                                        ),
                                      ),
                                    );
                                  },
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
  });

  @override
  State<_InlineNumberEditor> createState() => _InlineNumberEditorState();
}

class _InlineNumberEditorState extends State<_InlineNumberEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: FormatYardimcisi.sayiFormatlaOndalikli(
        widget.value,
        binlik: widget.binlik,
        ondalik: widget.ondalik,
        decimalDigits: widget.decimalDigits,
      ),
    );
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
    // Unfocus to prevent "Enter" from bubbling to DataTable row selection
    FocusScope.of(context).unfocus();

    final newValue = _parseFlexibleDouble(_controller.text);
    widget.onSubmitted(newValue);
  }

  double _parseFlexibleDouble(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return 0.0;

    final hasDot = raw.contains('.');
    final hasComma = raw.contains(',');

    String clean;
    if (hasDot && hasComma) {
      final lastDot = raw.lastIndexOf('.');
      final lastComma = raw.lastIndexOf(',');
      final decimalSep = lastDot > lastComma ? '.' : ',';
      final thousandSep = decimalSep == '.' ? ',' : '.';
      clean = raw.replaceAll(thousandSep, '').replaceAll(decimalSep, '.');
      return double.tryParse(clean) ?? 0.0;
    }

    if (hasDot || hasComma) {
      final sep = hasDot ? '.' : ',';
      final sepCount = raw.split(sep).length - 1;
      if (sepCount > 1) {
        clean = raw.replaceAll(sep, '');
        return double.tryParse(clean) ?? 0.0;
      }

      final idx = raw.lastIndexOf(sep);
      final digitsAfter = raw.length - idx - 1;
      final treatAsDecimal =
          digitsAfter > 0 && digitsAfter <= widget.decimalDigits;

      if (treatAsDecimal) {
        clean = raw.replaceAll(sep, '.');
        return double.tryParse(clean) ?? 0.0;
      }
    }

    return FormatYardimcisi.parseDouble(
      raw,
      binlik: widget.binlik,
      ondalik: widget.ondalik,
    );
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
          // CRITICAL: Disable default "Done/Next" action to prevent bubbling
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
          // onFieldSubmitted is still useful for some soft keyboards, but
          // key event handler above takes precedence for hardware Enter.
          onFieldSubmitted: (_) => _save(),
        ),
      ),
    );
  }
}
