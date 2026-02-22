import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:postgres/postgres.dart';

import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../../servisler/depolar_veritabani_servisi.dart';
import '../../servisler/urunler_veritabani_servisi.dart';
import '../../servisler/uretimler_veritabani_servisi.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../ayarlar/genel_ayarlar/modeller/doviz_kuru_model.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../urunler_ve_depolar/depolar/modeller/depo_model.dart';
import '../urunler_ve_depolar/uretimler/modeller/uretim_model.dart';
import '../urunler_ve_depolar/urunler/modeller/cihaz_model.dart';
import '../urunler_ve_depolar/urunler/modeller/urun_model.dart';
import 'modeller/transaction_item.dart';
import 'satis_tamamla_sayfasi.dart';

class HizliSatisSayfasi extends StatefulWidget {
  const HizliSatisSayfasi({super.key});

  @override
  State<HizliSatisSayfasi> createState() => _HizliSatisSayfasiState();
}

class _HizliSatisSayfasiState extends State<HizliSatisSayfasi> {
  static const Color _primaryColor = Color(0xFF2C3E50);
  static const Color _accentColor = Color(0xFF1E88E5);

  final TextEditingController _quickSearchController = TextEditingController();
  final FocusNode _quickSearchFocusNode = FocusNode();

  final List<_HizliSatisSatir> _rows = <_HizliSatisSatir>[];
  final Set<int> _flashRowIds = <int>{};

  Timer? _quickSearchDebounce;

  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();
  List<DepoModel> _allWarehouses = <DepoModel>[];

  bool _isLoading = true;
  bool _isCompletingSale = false;

  bool _isDeviceListModuleActive = false;
  int _selectedSalePriceGroup = 1;
  int _rowSeed = 0;

  int? _defaultWarehouseId;

  String _invoiceCurrency = 'TRY';
  double _invoiceCurrencyRate = 1.0;

  String _defaultVatStatus = 'excluded';
  String _defaultOtvStatus = 'excluded';
  String _defaultOivStatus = 'excluded';
  String _defaultTevkifatValue = '0';

  final Set<int> _expandedRowIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _quickSearchDebounce?.cancel();
    _quickSearchController.dispose();
    _quickSearchFocusNode.dispose();

    for (final row in _rows) {
      row.dispose();
    }

    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final warehouses = await DepolarVeritabaniServisi().tumDepolariGetir();
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();

      String currency = settings.varsayilanParaBirimi;
      if (currency == 'TL') currency = 'TRY';
      final invoiceRate = await _fetchRateFromDb(currency, settings);

      if (!mounted) return;
      setState(() {
        _allWarehouses = warehouses;
        _genelAyarlar = settings;
        _defaultWarehouseId = warehouses.isNotEmpty
            ? warehouses.first.id
            : null;
        _invoiceCurrency = currency;
        _invoiceCurrencyRate = invoiceRate;
        _isDeviceListModuleActive = settings.cihazListesiModuluAktif;

        _defaultVatStatus = settings.varsayilanKdvDurumu;
        _defaultOtvStatus = settings.otvKdvDurumu;
        _defaultOivStatus = settings.oivKdvDurumu;
        _defaultTevkifatValue = '0';

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      MesajYardimcisi.hataGoster(context, tr('common.error'));
    }
  }

  Future<double> _fetchRateFromDb(
    String currency,
    GenelAyarlarModel settings,
  ) async {
    if (currency == 'TRY' ||
        currency == 'TL' ||
        currency == settings.varsayilanParaBirimi) {
      return 1.0;
    }

    try {
      final rates = await AyarlarVeritabaniServisi().kurlariGetir();
      final rate = rates.firstWhere(
        (r) =>
            r.kaynakParaBirimi == currency &&
            (r.hedefParaBirimi == 'TRY' ||
                r.hedefParaBirimi == 'TL' ||
                r.hedefParaBirimi == settings.varsayilanParaBirimi),
        orElse: () => rates.firstWhere(
          (r) =>
              (r.kaynakParaBirimi == 'TRY' ||
                  r.kaynakParaBirimi == 'TL' ||
                  r.kaynakParaBirimi == settings.varsayilanParaBirimi) &&
              r.hedefParaBirimi == currency,
          orElse: () => DovizKuruModel(
            kaynakParaBirimi: currency,
            hedefParaBirimi: 'TRY',
            kur: 1.0,
            guncellemeZamani: DateTime.now(),
          ),
        ),
      );

      double value = rate.kur;
      if (rate.hedefParaBirimi == currency) {
        value = 1.0 / value;
      }
      return value;
    } catch (_) {
      return 1.0;
    }
  }

  Future<void> _onInvoiceCurrencyChanged(String? newCurrency) async {
    if (newCurrency == null) return;

    final rate = await _fetchRateFromDb(newCurrency, _genelAyarlar);
    if (!mounted) return;

    setState(() {
      _invoiceCurrency = newCurrency;
      _invoiceCurrencyRate = rate;

      for (final row in _rows) {
        row.currency = newCurrency;
        row.exchangeRateController.text = _formatDecimal(
          rate,
          digits: _genelAyarlar.kurOndalik,
        );
      }
    });
  }

  Future<List<_UrunSecenek>> _searchProductOptions(String query) async {
    final q = query.trim();
    if (q.isEmpty) return <_UrunSecenek>[];

    try {
      final results = await Future.wait<dynamic>([
        UrunlerVeritabaniServisi().urunleriGetir(
          aramaTerimi: q,
          sayfaBasinaKayit: 20,
          aktifMi: true,
        ),
        UretimlerVeritabaniServisi().uretimleriGetir(
          aramaTerimi: q,
          sayfaBasinaKayit: 20,
          aktifMi: true,
        ),
      ]);

      final products = (results[0] as List<UrunModel>)
          .map((p) => _UrunSecenek(product: p, isProduction: false))
          .toList(growable: false);
      final productions = (results[1] as List<UretimModel>)
          .map(
            (u) => _UrunSecenek(
              product: _productionToProduct(u),
              isProduction: true,
            ),
          )
          .toList(growable: false);

      final merged = <_UrunSecenek>[...products, ...productions];
      merged.sort(
        (a, b) =>
            a.product.ad.toLowerCase().compareTo(b.product.ad.toLowerCase()),
      );
      return merged;
    } catch (_) {
      return <_UrunSecenek>[];
    }
  }

  Future<_ProductResolveResult?> _resolveProductFromQuery(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;

    try {
      final products = await UrunlerVeritabaniServisi().urunleriGetir(
        aramaTerimi: q,
        sayfaBasinaKayit: 25,
      );

      if (products.isNotEmpty) {
        return _ProductResolveResult(product: _pickBestProduct(products, q));
      }

      if (_isDeviceListModuleActive) {
        try {
          final pool = UrunlerVeritabaniServisi().getPool();
          final deviceResult = await pool?.execute(
            Sql.named(
              'SELECT * FROM product_devices '
              'WHERE identity_value = @q AND is_sold = 0 LIMIT 1',
            ),
            parameters: {'q': q},
          );

          if (deviceResult != null && deviceResult.isNotEmpty) {
            final device = CihazModel.fromMap(deviceResult.first.toColumnMap());
            final product = await UrunlerVeritabaniServisi().urunGetirById(
              device.productId,
            );
            if (product != null) {
              return _ProductResolveResult(
                product: product,
                serialNumber: device.identityValue,
              );
            }
          }
        } catch (_) {
          // fall-through
        }
      }

      final productions = await UretimlerVeritabaniServisi().uretimleriGetir(
        aramaTerimi: q,
        sayfaBasinaKayit: 25,
      );
      if (productions.isNotEmpty) {
        return _ProductResolveResult(
          product: _productionToProduct(productions.first),
        );
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  UrunModel _pickBestProduct(List<UrunModel> products, String query) {
    final q = query.trim().toLowerCase();

    UrunModel? exactBarcode;
    UrunModel? exactCode;
    UrunModel? exactName;
    UrunModel? partial;

    for (final p in products) {
      final barcode = p.barkod.trim().toLowerCase();
      final code = p.kod.trim().toLowerCase();
      final name = p.ad.trim().toLowerCase();

      if (barcode.isNotEmpty && barcode == q) {
        exactBarcode = p;
        break;
      }
      if (exactCode == null && code == q) exactCode = p;
      if (exactName == null && name == q) exactName = p;
      if (partial == null &&
          (code.contains(q) || name.contains(q) || barcode.contains(q))) {
        partial = p;
      }
    }

    return exactBarcode ?? exactCode ?? exactName ?? partial ?? products.first;
  }

  UrunModel _productionToProduct(UretimModel production) {
    return UrunModel(
      id: production.id,
      kod: production.kod,
      ad: '${production.ad} (Üretim)',
      birim: production.birim,
      alisFiyati: production.alisFiyati,
      satisFiyati1: production.satisFiyati1,
      satisFiyati2: production.satisFiyati2,
      satisFiyati3: production.satisFiyati3,
      kdvOrani: production.kdvOrani,
      stok: production.stok,
      erkenUyariMiktari: production.erkenUyariMiktari,
      grubu: production.grubu,
      ozellikler: production.ozellikler,
      barkod: production.barkod,
      kullanici: production.kullanici,
      resimUrl: production.resimUrl,
      resimler: production.resimler,
      aktifMi: production.aktifMi,
      createdBy: production.createdBy,
      createdAt: production.createdAt,
    );
  }

  Future<void> _addFromQuickInput() async {
    final query = _quickSearchController.text.trim();
    if (query.isEmpty) {
      _addEmptyRow();
      return;
    }

    final resolved = await _resolveProductFromQuery(query);
    if (resolved == null) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(
        context,
        tr('fast_sale.error.product_not_found'),
      );
      return;
    }

    await _appendProductRow(
      resolved.product,
      preselectedSerial: resolved.serialNumber,
    );

    if (!mounted) return;
    setState(() {
      _quickSearchController.clear();
    });
    _quickSearchFocusNode.requestFocus();
  }

  void _addEmptyRow() {
    final row = _createRow();
    setState(() {
      _rows.add(row);
    });

    Future.microtask(() {
      if (!mounted) return;
      row.productFocusNode.requestFocus();
    });
  }

  _HizliSatisSatir _createRow() {
    return _HizliSatisSatir(
      rowId: ++_rowSeed,
      productSearchController: TextEditingController(),
      productFocusNode: FocusNode(),
      quantityController: TextEditingController(text: '1'),
      priceController: TextEditingController(),
      rawPriceController: TextEditingController(),
      discountController: TextEditingController(),
      vatRateController: TextEditingController(text: '20'),
      otvRateController: TextEditingController(text: '0'),
      oivRateController: TextEditingController(text: '0'),
      exchangeRateController: TextEditingController(
        text: _formatDecimal(
          _invoiceCurrencyRate,
          digits: _genelAyarlar.kurOndalik,
        ),
      ),
      quantityFocusNode: FocusNode(),
      priceFocusNode: FocusNode(),
      rawPriceFocusNode: FocusNode(),
      discountFocusNode: FocusNode(),
      vatFocusNode: FocusNode(),
      otvFocusNode: FocusNode(),
      oivFocusNode: FocusNode(),
      exchangeRateFocusNode: FocusNode(),
      warehouseId: _defaultWarehouseId,
      unit: _defaultUnit,
      currency: _invoiceCurrency,
      vatStatus: _defaultVatStatus,
      otvStatus: _defaultOtvStatus,
      oivStatus: _defaultOivStatus,
      tevkifatValue: _defaultTevkifatValue,
    );
  }

  Future<void> _appendProductRow(
    UrunModel product, {
    String? preselectedSerial,
  }) async {
    final row = _createRow();

    setState(() {
      _rows.add(row);
    });

    await _applyProductToRow(
      row,
      product,
      preselectedSerial: preselectedSerial,
    );
    _flashRow(row.rowId);
  }

  Future<void> _applyProductToRow(
    _HizliSatisSatir row,
    UrunModel product, {
    String? preselectedSerial,
  }) async {
    final int resolvedPriceGroup = _resolveSalePriceGroupForProduct(
      product,
      _selectedSalePriceGroup,
    );
    final double selectedPrice = _selectSalePrice(product, resolvedPriceGroup);

    setState(() {
      row.productId = product.id;
      row.code = product.kod;
      row.barcode = product.barkod;
      row.name = product.ad;
      row.productSearchController.text = product.ad;

      row.unit = product.birim;
      row.currency = _invoiceCurrency;
      row.vatStatus = _defaultVatStatus;
      row.otvStatus = _defaultOtvStatus;
      row.oivStatus = _defaultOivStatus;
      row.tevkifatValue = _defaultTevkifatValue;

      row.quantityController.text = '1';
      row.priceController.text = _formatDecimal(
        selectedPrice,
        digits: _genelAyarlar.fiyatOndalik,
      );
      row.discountController.clear();
      row.vatRateController.text = _formatRate(product.kdvOrani);
      row.otvRateController.text = '0';
      row.oivRateController.text = '0';
      row.exchangeRateController.text = _formatDecimal(
        _invoiceCurrencyRate,
        digits: _genelAyarlar.kurOndalik,
      );

      row.availableDevices = <CihazModel>[];
      row.serialNumber = preselectedSerial;
    });

    _syncRawFromPrice(row);

    if (_isDeviceListModuleActive) {
      await _loadDevicesForRow(row, preselectedSerial: preselectedSerial);
    }
  }

  Future<void> _onRowProductSubmitted(_HizliSatisSatir row) async {
    final query = row.productSearchController.text.trim();
    if (query.isEmpty) return;

    final resolved = await _resolveProductFromQuery(query);
    if (resolved == null) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(
        context,
        tr('fast_sale.error.product_not_found'),
      );
      return;
    }

    await _applyProductToRow(
      row,
      resolved.product,
      preselectedSerial: resolved.serialNumber,
    );

    if (!mounted) return;
    _flashRow(row.rowId);
    row.quantityFocusNode.requestFocus();
  }

  Future<void> _loadDevicesForRow(
    _HizliSatisSatir row, {
    String? preselectedSerial,
  }) async {
    if (!_isDeviceListModuleActive) return;
    final productId = row.productId;
    if (productId == null) return;

    try {
      final devices = await UrunlerVeritabaniServisi().cihazlariGetir(
        productId,
      );
      if (!mounted) return;
      if (!_rows.any((r) => r.rowId == row.rowId)) return;

      setState(() {
        row.availableDevices = devices;
        if (preselectedSerial != null && preselectedSerial.isNotEmpty) {
          row.serialNumber = preselectedSerial;
        } else if (devices.length == 1) {
          row.serialNumber = devices.first.identityValue;
        }

        if (row.serialNumber != null && row.serialNumber!.isNotEmpty) {
          row.quantityController.text = '1';
        }
      });
    } catch (_) {
      // no-op
    }
  }

  void _removeRow(_HizliSatisSatir row) {
    setState(() {
      _rows.removeWhere((r) => r.rowId == row.rowId);
      _flashRowIds.remove(row.rowId);
    });
    row.dispose();
  }

  void _flashRow(int rowId) {
    setState(() => _flashRowIds.add(rowId));
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _flashRowIds.remove(rowId));
    });
  }

  int _resolveSalePriceGroupForProduct(UrunModel product, int preferredGroup) {
    final availableGroups = <int>[
      if (product.satisFiyati1 > 0) 1,
      if (product.satisFiyati2 > 0) 2,
      if (product.satisFiyati3 > 0) 3,
    ];

    if (availableGroups.isEmpty) return preferredGroup;
    if (availableGroups.contains(preferredGroup)) return preferredGroup;
    return availableGroups.first;
  }

  double _selectSalePrice(UrunModel product, int group) {
    switch (group) {
      case 2:
        return product.satisFiyati2 > 0
            ? product.satisFiyati2
            : product.satisFiyati1;
      case 3:
        return product.satisFiyati3 > 0
            ? product.satisFiyati3
            : product.satisFiyati1;
      case 1:
      default:
        return product.satisFiyati1;
    }
  }

  String get _defaultUnit {
    final units = _allUnits;
    return units.isNotEmpty ? units.first : 'Adet';
  }

  List<String> get _allUnits {
    final fromSettings = _genelAyarlar.urunBirimleri
        .map((e) => (e['name'] ?? '').toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (fromSettings.isEmpty) {
      return <String>['Adet'];
    }

    return fromSettings;
  }

  void _syncRawFromPrice(_HizliSatisSatir row) {
    final price = _parseFlexibleDouble(
      row.priceController.text,
      maxDecimalDigits: _genelAyarlar.fiyatOndalik,
    );
    final vat = _parseFlexibleDouble(
      row.vatRateController.text,
      maxDecimalDigits: 2,
    );
    final otv = _parseFlexibleDouble(
      row.otvRateController.text,
      maxDecimalDigits: 2,
    );
    final oiv = _parseFlexibleDouble(
      row.oivRateController.text,
      maxDecimalDigits: 2,
    );

    double current = price;
    if (row.vatStatus == 'included') {
      final divisor = 1 + (vat / 100);
      if (divisor > 0) {
        current /= divisor;
      }
    }

    double divisor = 1.0;
    if (row.otvStatus == 'included') divisor += otv / 100;
    if (row.oivStatus == 'included') divisor += oiv / 100;

    final raw = divisor > 0 ? current / divisor : current;
    row.rawPriceController.text = _formatDecimal(
      raw,
      digits: _genelAyarlar.fiyatOndalik,
    );
  }

  void _syncPriceFromRaw(_HizliSatisSatir row) {
    final raw = _parseFlexibleDouble(
      row.rawPriceController.text,
      maxDecimalDigits: _genelAyarlar.fiyatOndalik,
    );
    final vat = _parseFlexibleDouble(
      row.vatRateController.text,
      maxDecimalDigits: 2,
    );
    final otv = _parseFlexibleDouble(
      row.otvRateController.text,
      maxDecimalDigits: 2,
    );
    final oiv = _parseFlexibleDouble(
      row.oivRateController.text,
      maxDecimalDigits: 2,
    );

    double price = raw;
    if (row.otvStatus == 'included') price *= (1 + otv / 100);
    if (row.oivStatus == 'included') price *= (1 + oiv / 100);
    if (row.vatStatus == 'included') price *= (1 + vat / 100);

    row.priceController.text = _formatDecimal(
      price,
      digits: _genelAyarlar.fiyatOndalik,
    );
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
          maxDecimalDigits != null &&
          digitsAfter > 0 &&
          digitsAfter <= maxDecimalDigits;

      if (treatAsDecimal) {
        clean = raw.replaceAll(sep, '.');
        return double.tryParse(clean) ?? 0.0;
      }

      return FormatYardimcisi.parseDouble(
        raw,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );
    }

    clean = raw.replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }

  double _parseTevkifat(String value) {
    if (value == '0') return 0.0;

    final parts = value.split('/');
    if (parts.length != 2) return 0.0;

    final pay = double.tryParse(parts[0]) ?? 0.0;
    final payda = double.tryParse(parts[1]) ?? 1.0;
    if (payda == 0) return 0.0;

    return pay / payda;
  }

  List<SaleItem> _collectSaleItems({bool validateRequired = false}) {
    final items = <SaleItem>[];

    for (final row in _rows) {
      final warehouseId = row.warehouseId;
      final quantity = _parseFlexibleDouble(
        row.quantityController.text,
        maxDecimalDigits: _genelAyarlar.miktarOndalik,
      );
      final price = _parseFlexibleDouble(
        row.priceController.text,
        maxDecimalDigits: _genelAyarlar.fiyatOndalik,
      );
      final rate = _parseFlexibleDouble(
        row.exchangeRateController.text,
        maxDecimalDigits: _genelAyarlar.kurOndalik,
      );
      final vat = _parseFlexibleDouble(
        row.vatRateController.text,
        maxDecimalDigits: 2,
      );
      final otv = _parseFlexibleDouble(
        row.otvRateController.text,
        maxDecimalDigits: 2,
      );
      final oiv = _parseFlexibleDouble(
        row.oivRateController.text,
        maxDecimalDigits: 2,
      );
      final discount = _parseFlexibleDouble(
        row.discountController.text,
        maxDecimalDigits: 2,
      );

      if (row.code.trim().isEmpty ||
          row.name.trim().isEmpty ||
          price <= 0 ||
          quantity <= 0) {
        continue;
      }

      if (validateRequired && (warehouseId == null || warehouseId <= 0)) {
        throw tr('fast_sale.error.select_warehouse');
      }

      if (validateRequired &&
          _isDeviceListModuleActive &&
          row.availableDevices.isNotEmpty &&
          (row.serialNumber == null || row.serialNumber!.trim().isEmpty)) {
        throw tr('fast_sale.error.serial_required');
      }

      final warehouse = _allWarehouses.firstWhere(
        (w) => w.id == warehouseId,
        orElse: () => _allWarehouses.isNotEmpty
            ? _allWarehouses.first
            : const DepoModel(
                id: 0,
                kod: '',
                ad: '-',
                adres: '',
                sorumlu: '',
                telefon: '',
                aktifMi: true,
              ),
      );

      final exchangeRate = rate > 0 ? rate : 1.0;
      final convertedPrice = price * (exchangeRate / _invoiceCurrencyRate);

      items.add(
        SaleItem(
          code: row.code,
          name: row.name,
          barcode: row.barcode,
          unit: row.unit,
          quantity: row.serialNumber != null ? 1 : quantity,
          unitPrice: convertedPrice,
          currency: _invoiceCurrency,
          exchangeRate: exchangeRate,
          vatRate: vat,
          discountRate: discount,
          warehouseId: warehouse.id,
          warehouseName: warehouse.ad,
          vatIncluded: row.vatStatus == 'included',
          otvRate: otv,
          otvIncluded: row.otvStatus == 'included',
          oivRate: oiv,
          oivIncluded: row.oivStatus == 'included',
          kdvTevkifatOrani: _parseTevkifat(row.tevkifatValue),
          serialNumber: row.serialNumber,
        ),
      );
    }

    return items;
  }

  _HizliSatisToplam _calculateTotals(List<SaleItem> items) {
    double subTotal = 0;
    double totalDiscount = 0;
    double totalVat = 0;
    double totalOtv = 0;
    double totalOiv = 0;
    double totalTevkifat = 0;

    for (final item in items) {
      subTotal += item.quantity * item.netUnitPrice;
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

    final inclusiveTotal =
        subTotal + totalOtv + totalOiv - totalDiscount + totalVat;
    if (inclusiveTotal < 12000) {
      totalTevkifat = 0;
    }

    final grandTotal = inclusiveTotal - totalTevkifat;

    return _HizliSatisToplam(
      subTotal: subTotal,
      totalDiscount: totalDiscount,
      totalVat: totalVat,
      totalOtv: totalOtv,
      totalOiv: totalOiv,
      totalTevkifat: totalTevkifat,
      grandTotal: grandTotal,
    );
  }

  Future<void> _completeSale() async {
    if (_isCompletingSale) return;

    try {
      final items = _collectSaleItems(validateRequired: true);
      if (items.isEmpty) {
        MesajYardimcisi.hataGoster(context, tr('sale.error.no_items'));
        return;
      }

      final totals = _calculateTotals(items);

      setState(() => _isCompletingSale = true);

      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => SatisTamamlaSayfasi(
            items: items,
            genelToplam: totals.grandTotal,
            toplamIskonto: totals.totalDiscount,
            toplamKdv: totals.totalVat,
            paraBirimi: _invoiceCurrency,
          ),
        ),
      );

      if (result == true && mounted) {
        setState(() {
          for (final row in _rows) {
            row.dispose();
          }
          _rows.clear();
        });
        _quickSearchFocusNode.requestFocus();
      }
    } catch (e) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isCompletingSale = false);
      }
    }
  }

  String _formatDecimal(double value, {required int digits}) {
    return FormatYardimcisi.sayiFormatlaOndalikli(
      value,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: digits,
    );
  }

  String _formatRate(double value) {
    return FormatYardimcisi.sayiFormatlaOran(
      value,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: 2,
    );
  }

  int get _warehouseFlex {
    final int maxLen = _allWarehouses.fold<int>(
      10,
      (prev, item) => item.ad.length > prev ? item.ad.length : prev,
    );

    if (maxLen >= 48) return 36;
    if (maxLen >= 40) return 32;
    if (maxLen >= 32) return 28;
    if (maxLen >= 24) return 22;
    if (maxLen >= 16) return 18;
    return 14;
  }

  @override
  Widget build(BuildContext context) {
    final previewItems = _collectSaleItems();
    final totals = _calculateTotals(previewItems);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return _buildMobileLayout(totals);
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _primaryColor),
                )
              : Column(
                  children: [
                    _buildHeaderSection(),
                    Expanded(child: _buildGridSection()),
                    _buildFooterSection(totals),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildMobileLayout(_HizliSatisToplam totals) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          tr('fast_sale.title'),
          style: const TextStyle(
            color: Color(0xFF202124),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                for (final row in _rows) {
                  row.dispose();
                }
                _rows.clear();
                _expandedRowIds.clear();
              });
            },
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
            tooltip: tr('common.clear'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : Column(
              children: [
                _buildMobileHeader(),
                Expanded(
                  child: _rows.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_basket_outlined,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                tr('fast_sale.empty'),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          itemCount: _rows.length,
                          itemBuilder: (context, index) {
                            return _buildMobileProductCard(_rows[index], index);
                          },
                        ),
                ),
                _buildMobileFooter(totals),
              ],
            ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          _buildQuickSearchAutocomplete(
            maxOptionsWidth: MediaQuery.of(context).size.width - 24,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactDropdown<String>(
                  label: tr('sale.field.currency'),
                  value: _invoiceCurrency,
                  items: _genelAyarlar.kullanilanParaBirimleri,
                  onChanged: _onInvoiceCurrencyChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactDropdown<String>(
                  label: tr('sale.field.vat_status'),
                  value: _defaultVatStatus,
                  items: const <String>['excluded', 'included'],
                  itemTextBuilder: (v) => v == 'excluded'
                      ? tr('sale.field.vat_excluded')
                      : tr('sale.field.vat_included'),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _defaultVatStatus = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildPriceGroupSelector()),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _addEmptyRow,
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: Text(tr('fast_sale.add_empty_row')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    side: const BorderSide(color: _primaryColor),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileProductCard(_HizliSatisSatir row, int index) {
    final bool isExpanded = _expandedRowIds.contains(row.rowId);
    final bool isFlashing = _flashRowIds.contains(row.rowId);
    final tempItem = _buildTempItem(row);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isFlashing ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isFlashing ? const Color(0xFF4CAF50) : const Color(0xFFEAEEF2),
          width: isFlashing ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Card Header
          InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedRowIds.remove(row.rowId);
                } else {
                  _expandedRowIds.add(row.rowId);
                }
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: row.productId == 0
                        ? _productSearchCell(row, dense: true)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF202124),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (row.code.isNotEmpty)
                                Text(
                                  row.code,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_formatDecimal(tempItem.total, digits: _genelAyarlar.fiyatOndalik)} $_invoiceCurrency',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _primaryColor,
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Essential Controls
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildMobileInputBlock(
                    label: tr('sale.grid.quantity'),
                    child: _numberCell(
                      row.quantityController,
                      focusNode: row.quantityFocusNode,
                      maxDecimalDigits: _genelAyarlar.miktarOndalik,
                      readOnly: row.serialNumber != null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildMobileInputBlock(
                    label: tr('sale.grid.unit'),
                    child: _unitCell(row),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: _buildMobileInputBlock(
                    label: tr('sale.grid.price'),
                    child: _numberCell(
                      row.priceController,
                      focusNode: row.priceFocusNode,
                      maxDecimalDigits: _genelAyarlar.fiyatOndalik,
                      onSubmitted: (_) {
                        _syncRawFromPrice(row);
                        setState(() {});
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Expanded Controls
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMobileInputBlock(
                          label: tr('sale.grid.warehouse'),
                          child: _warehouseCell(row),
                        ),
                      ),
                      if (_isDeviceListModuleActive) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMobileInputBlock(
                            label: tr('products.devices.identity'),
                            child: _serialCell(row),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMobileInputBlock(
                          label: tr('common.raw_price'),
                          child: _numberCell(
                            row.rawPriceController,
                            focusNode: row.rawPriceFocusNode,
                            maxDecimalDigits: _genelAyarlar.fiyatOndalik,
                            onSubmitted: (_) {
                              _syncPriceFromRaw(row);
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMobileInputBlock(
                          label: tr('sale.grid.discount'),
                          child: _numberCell(
                            row.discountController,
                            focusNode: row.discountFocusNode,
                            maxDecimalDigits: 2,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMobileInputBlock(
                          label: tr('sale.grid.vat'),
                          child: _numberCell(
                            row.vatRateController,
                            focusNode: row.vatFocusNode,
                            maxDecimalDigits: 2,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMobileInputBlock(
                          label: tr('sale.field.currency'),
                          child: _currencyCell(row),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_genelAyarlar.otvKullanimi ||
                      _genelAyarlar.oivKullanimi ||
                      _genelAyarlar.kdvTevkifati) ...[
                    Row(
                      children: [
                        if (_genelAyarlar.otvKullanimi)
                          Expanded(
                            child: _buildMobileInputBlock(
                              label: tr('sale.grid.otv'),
                              child: _numberCell(
                                row.otvRateController,
                                focusNode: row.otvFocusNode,
                                maxDecimalDigits: 2,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ),
                        if (_genelAyarlar.otvKullanimi &&
                            (_genelAyarlar.oivKullanimi ||
                                _genelAyarlar.kdvTevkifati))
                          const SizedBox(width: 8),
                        if (_genelAyarlar.oivKullanimi)
                          Expanded(
                            child: _buildMobileInputBlock(
                              label: tr('sale.grid.oiv'),
                              child: _numberCell(
                                row.oivRateController,
                                focusNode: row.oivFocusNode,
                                maxDecimalDigits: 2,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ),
                        if (_genelAyarlar.oivKullanimi &&
                            _genelAyarlar.kdvTevkifati)
                          const SizedBox(width: 8),
                        if (_genelAyarlar.kdvTevkifati)
                          Expanded(
                            child: _buildMobileInputBlock(
                              label: tr('sale.grid.tevkifat'),
                              child: _tevkifatCell(row),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _buildMobileInputBlock(
                          label: tr('common.rate'),
                          child: _numberCell(
                            row.exchangeRateController,
                            focusNode: row.exchangeRateFocusNode,
                            maxDecimalDigits: _genelAyarlar.kurOndalik,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => _removeRow(row),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: Text(tr('common.delete')),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                      Text(
                        'Row ID: ${row.rowId}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileInputBlock({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _buildMobileFooter(_HizliSatisToplam totals) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('fast_sale.total'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    '${_formatDecimal(totals.grandTotal, digits: _genelAyarlar.fiyatOndalik)} $_invoiceCurrency',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _isCompletingSale ? null : _completeSale,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isCompletingSale
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shopping_cart_checkout_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tr('fast_sale.complete_button'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _totalsChip(
                    tr('sale.footer.subtotal'),
                    totals.subTotal,
                    icon: Icons.list_alt_rounded,
                  ),
                  const SizedBox(width: 8),
                  _totalsChip(
                    tr('sale.footer.discount'),
                    totals.totalDiscount,
                    prefix: '-',
                    icon: Icons.discount_outlined,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  _totalsChip(
                    tr('sale.footer.vat_total'),
                    totals.totalVat,
                    icon: Icons.receipt_long_outlined,
                    color: Colors.blue.shade700,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double contentWidth = constraints.maxWidth;
          final bool keepTopSingleLine = contentWidth >= 1450;
          const double currencyWidth = 150;
          const double vatWidth = 150;
          const double priceGroupWidth = 116;
          const double emptyRowWidth = 132;
          const double controlGap = 12;
          final double reservedControlsWidth =
              currencyWidth +
              vatWidth +
              priceGroupWidth +
              emptyRowWidth +
              (controlGap * 4);
          final double quickSearchWidth = keepTopSingleLine
              ? (contentWidth - reservedControlsWidth)
                    .clamp(340, 940)
                    .toDouble()
              : (contentWidth * 0.58).clamp(280, 860).toDouble();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('fast_sale.title'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr('fast_sale.subtitle'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              if (keepTopSingleLine)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: quickSearchWidth,
                      child: _buildQuickSearchAutocomplete(
                        maxOptionsWidth: quickSearchWidth,
                      ),
                    ),
                    const SizedBox(width: controlGap),
                    SizedBox(
                      width: currencyWidth,
                      child: _buildCompactDropdown<String>(
                        label: tr('sale.field.currency'),
                        value: _invoiceCurrency,
                        items: _genelAyarlar.kullanilanParaBirimleri,
                        onChanged: _onInvoiceCurrencyChanged,
                      ),
                    ),
                    const SizedBox(width: controlGap),
                    SizedBox(
                      width: vatWidth,
                      child: _buildCompactDropdown<String>(
                        label: tr('sale.field.vat_status'),
                        value: _defaultVatStatus,
                        items: const <String>['excluded', 'included'],
                        itemTextBuilder: (v) => v == 'excluded'
                            ? tr('sale.field.vat_excluded')
                            : tr('sale.field.vat_included'),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _defaultVatStatus = v);
                        },
                      ),
                    ),
                    const SizedBox(width: controlGap),
                    SizedBox(
                      width: priceGroupWidth,
                      child: _buildPriceGroupSelector(),
                    ),
                    const SizedBox(width: controlGap),
                    SizedBox(
                      width: emptyRowWidth,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _addEmptyRow,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(tr('fast_sale.add_empty_row')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryColor,
                          side: const BorderSide(color: _primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: quickSearchWidth,
                      child: _buildQuickSearchAutocomplete(
                        maxOptionsWidth: quickSearchWidth,
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: _buildCompactDropdown<String>(
                        label: tr('sale.field.currency'),
                        value: _invoiceCurrency,
                        items: _genelAyarlar.kullanilanParaBirimleri,
                        onChanged: _onInvoiceCurrencyChanged,
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: _buildCompactDropdown<String>(
                        label: tr('sale.field.vat_status'),
                        value: _defaultVatStatus,
                        items: const <String>['excluded', 'included'],
                        itemTextBuilder: (v) => v == 'excluded'
                            ? tr('sale.field.vat_excluded')
                            : tr('sale.field.vat_included'),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _defaultVatStatus = v);
                        },
                      ),
                    ),
                    _buildPriceGroupSelector(),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _addEmptyRow,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(tr('fast_sale.add_empty_row')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryColor,
                          side: const BorderSide(color: _primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_genelAyarlar.otvKullanimi ||
                  _genelAyarlar.oivKullanimi ||
                  _genelAyarlar.kdvTevkifati) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (_genelAyarlar.otvKullanimi)
                      SizedBox(
                        width: 170,
                        child: _buildCompactDropdown<String>(
                          label: tr('sale.field.otv_status'),
                          value: _defaultOtvStatus,
                          items: const <String>['excluded', 'included'],
                          itemTextBuilder: (v) => v == 'excluded'
                              ? tr('sale.field.vat_excluded')
                              : tr('sale.field.vat_included'),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _defaultOtvStatus = v);
                          },
                        ),
                      ),
                    if (_genelAyarlar.oivKullanimi)
                      SizedBox(
                        width: 170,
                        child: _buildCompactDropdown<String>(
                          label: tr('sale.field.oiv_status'),
                          value: _defaultOivStatus,
                          items: const <String>['excluded', 'included'],
                          itemTextBuilder: (v) => v == 'excluded'
                              ? tr('sale.field.vat_excluded')
                              : tr('sale.field.vat_included'),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _defaultOivStatus = v);
                          },
                        ),
                      ),
                    if (_genelAyarlar.kdvTevkifati)
                      SizedBox(
                        width: 190,
                        child: _buildCompactDropdown<String>(
                          label: tr('sale.field.vat_withholding'),
                          value: _defaultTevkifatValue,
                          items: const <String>[
                            '0',
                            '2/10',
                            '3/10',
                            '4/10',
                            '5/10',
                            '7/10',
                            '9/10',
                            '10/10',
                          ],
                          itemTextBuilder: (v) =>
                              v == '0' ? tr('tevkifat.none') : v,
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _defaultTevkifatValue = v);
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickSearchAutocomplete({required double maxOptionsWidth}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('fast_sale.search_label'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A4A4A),
          ),
        ),
        const SizedBox(height: 6),
        RawAutocomplete<_UrunSecenek>(
          focusNode: _quickSearchFocusNode,
          textEditingController: _quickSearchController,
          displayStringForOption: (option) => option.product.ad,
          optionsBuilder: (textEditingValue) async {
            final query = textEditingValue.text.trim();
            if (query.isEmpty) {
              return const Iterable<_UrunSecenek>.empty();
            }

            if (_quickSearchDebounce?.isActive ?? false) {
              _quickSearchDebounce!.cancel();
            }

            final completer = Completer<Iterable<_UrunSecenek>>();
            _quickSearchDebounce = Timer(
              const Duration(milliseconds: 320),
              () async {
                final results = await _searchProductOptions(query);
                if (!completer.isCompleted) completer.complete(results);
              },
            );

            return completer.future;
          },
          onSelected: (option) async {
            await _appendProductRow(option.product);
            if (!mounted) return;
            setState(() => _quickSearchController.clear());
            _quickSearchFocusNode.requestFocus();
          },
          optionsViewBuilder: (context, onSelected, options) {
            // Her ürün tile'ı yaklaşık 70px yüksekliğinde
            const double itemHeight = 70.0;
            const double verticalPadding = 16.0; // 8 + 8
            final double calculatedHeight =
                (options.length * itemHeight) + verticalPadding;
            final double dynamicHeight = calculatedHeight
                .clamp(0, 280)
                .toDouble();

            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: dynamicHeight,
                    maxWidth: maxOptionsWidth,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return _buildProductOptionTile(
                        option: option,
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return SizedBox(
              height: 44,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onSubmitted: (_) => _addFromQuickInput(),
                onChanged: (_) => setState(() {}),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: tr('fast_sale.search_hint'),
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    onPressed: _addFromQuickInput,
                    icon: Icon(
                      controller.text.trim().isEmpty
                          ? Icons.add_rounded
                          : Icons.add_circle_rounded,
                      color: _accentColor,
                    ),
                    tooltip: tr('common.add'),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: _accentColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPriceGroupSelector() {
    Widget buildButton(int group) {
      final selected = _selectedSalePriceGroup == group;
      return InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () => setState(() => _selectedSalePriceGroup = group),
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _accentColor : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? _accentColor : Colors.grey.shade300,
            ),
          ),
          child: Text(
            '$group',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('retail.price_group'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A4A4A),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            buildButton(1),
            const SizedBox(width: 6),
            buildButton(2),
            const SizedBox(width: 6),
            buildButton(3),
          ],
        ),
      ],
    );
  }

  Widget _buildGridSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool desktopTable = constraints.maxWidth >= 1560;

          return Column(
            children: [
              if (desktopTable) _buildGridHeaderDesktop(),
              if (desktopTable) const Divider(height: 1),
              Expanded(
                child: _rows.isEmpty
                    ? Center(
                        child: Text(
                          tr('fast_sale.empty'),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _rows.length,
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          return desktopTable
                              ? _buildGridRowDesktop(row, index)
                              : _buildGridRowResponsive(
                                  row,
                                  index,
                                  constraints.maxWidth,
                                );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGridHeaderDesktop() {
    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF5F6368),
    );

    Widget cell(
      String text,
      int flex, {
      Alignment alignment = Alignment.centerLeft,
      TextAlign textAlign = TextAlign.left,
    }) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Align(
            alignment: alignment,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlign,
              style: headerStyle,
            ),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF8F9FA),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          cell('#', 2),
          cell(tr('sale.grid.name'), 26),
          cell(tr('sale.grid.warehouse'), _warehouseFlex),
          if (_isDeviceListModuleActive)
            cell(tr('products.devices.identity'), 14),
          cell(tr('sale.grid.quantity'), 7),
          cell(tr('sale.grid.unit'), 7),
          cell(tr('sale.grid.price'), 9),
          cell(tr('common.raw_price'), 9),
          cell(tr('sale.grid.discount'), 7),
          cell(tr('sale.grid.vat'), 7),
          if (_genelAyarlar.otvKullanimi) cell(tr('sale.grid.otv'), 7),
          if (_genelAyarlar.oivKullanimi) cell(tr('sale.grid.oiv'), 7),
          if (_genelAyarlar.kdvTevkifati) cell(tr('sale.grid.tevkifat'), 10),
          cell(tr('sale.field.currency'), 7),
          cell(tr('common.rate'), 7),
          cell(
            tr('sale.grid.total'),
            10,
            alignment: Alignment.centerRight,
            textAlign: TextAlign.right,
          ),
          cell('', 3),
        ],
      ),
    );
  }

  Widget _buildGridRowDesktop(_HizliSatisSatir row, int index) {
    final bool isFlashing = _flashRowIds.contains(row.rowId);
    final tempItem = _buildTempItem(row);

    Widget cell({required Widget child, required int flex}) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: child,
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isFlashing ? const Color(0xFFE8F5E9) : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
          left: BorderSide(
            color: isFlashing ? const Color(0xFF4CAF50) : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          cell(
            flex: 2,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: isFlashing
                    ? const Color(0xFF2E7D32)
                    : Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          cell(flex: 26, child: _productSearchCell(row, dense: true)),
          cell(flex: _warehouseFlex, child: _warehouseCell(row)),
          if (_isDeviceListModuleActive)
            cell(flex: 14, child: _serialCell(row)),
          cell(
            flex: 7,
            child: _numberCell(
              row.quantityController,
              focusNode: row.quantityFocusNode,
              maxDecimalDigits: _genelAyarlar.miktarOndalik,
              readOnly: row.serialNumber != null,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          cell(flex: 7, child: _unitCell(row)),
          cell(
            flex: 9,
            child: _numberCell(
              row.priceController,
              focusNode: row.priceFocusNode,
              maxDecimalDigits: _genelAyarlar.fiyatOndalik,
              onSubmitted: (_) {
                _syncRawFromPrice(row);
                setState(() {});
                FocusScope.of(context).nextFocus();
              },
              onChanged: (_) => setState(() {}),
            ),
          ),
          cell(
            flex: 9,
            child: _numberCell(
              row.rawPriceController,
              focusNode: row.rawPriceFocusNode,
              maxDecimalDigits: _genelAyarlar.fiyatOndalik,
              onSubmitted: (_) {
                _syncPriceFromRaw(row);
                setState(() {});
                FocusScope.of(context).nextFocus();
              },
            ),
          ),
          cell(
            flex: 7,
            child: _numberCell(
              row.discountController,
              focusNode: row.discountFocusNode,
              maxDecimalDigits: 2,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          cell(
            flex: 7,
            child: _numberCell(
              row.vatRateController,
              focusNode: row.vatFocusNode,
              maxDecimalDigits: 2,
              onSubmitted: (_) {
                _syncRawFromPrice(row);
                setState(() {});
                FocusScope.of(context).nextFocus();
              },
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_genelAyarlar.otvKullanimi)
            cell(
              flex: 7,
              child: _numberCell(
                row.otvRateController,
                focusNode: row.otvFocusNode,
                maxDecimalDigits: 2,
                onSubmitted: (_) {
                  _syncRawFromPrice(row);
                  setState(() {});
                  FocusScope.of(context).nextFocus();
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
          if (_genelAyarlar.oivKullanimi)
            cell(
              flex: 7,
              child: _numberCell(
                row.oivRateController,
                focusNode: row.oivFocusNode,
                maxDecimalDigits: 2,
                onSubmitted: (_) {
                  _syncRawFromPrice(row);
                  setState(() {});
                  FocusScope.of(context).nextFocus();
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
          if (_genelAyarlar.kdvTevkifati)
            cell(flex: 10, child: _tevkifatCell(row)),
          cell(flex: 7, child: _currencyCell(row)),
          cell(
            flex: 7,
            child: _numberCell(
              row.exchangeRateController,
              focusNode: row.exchangeRateFocusNode,
              maxDecimalDigits: _genelAyarlar.kurOndalik,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          cell(
            flex: 10,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${_formatDecimal(tempItem.total, digits: _genelAyarlar.fiyatOndalik)} $_invoiceCurrency',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _primaryColor,
                  ),
                ),
              ),
            ),
          ),
          cell(
            flex: 3,
            child: IconButton(
              onPressed: () => _removeRow(row),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 20,
              ),
              tooltip: tr('common.delete'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridRowResponsive(
    _HizliSatisSatir row,
    int index,
    double width,
  ) {
    final bool isFlashing = _flashRowIds.contains(row.rowId);
    final tempItem = _buildTempItem(row);

    final double fieldWidth = ((width - 64) / 4).clamp(140, 260).toDouble();

    Widget block({required String label, required Widget child}) {
      return SizedBox(
        width: fieldWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isFlashing ? const Color(0xFFE8F5E9) : const Color(0xFFFBFCFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFlashing ? const Color(0xFF81C784) : const Color(0xFFE5E9EF),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '#${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isFlashing
                      ? const Color(0xFF2E7D32)
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _productSearchCell(row, dense: false)),
              IconButton(
                onPressed: () => _removeRow(row),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 20,
                ),
                tooltip: tr('common.delete'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              block(
                label: tr('sale.grid.warehouse'),
                child: _warehouseCell(row),
              ),
              if (_isDeviceListModuleActive)
                block(
                  label: tr('products.devices.identity'),
                  child: _serialCell(row),
                ),
              block(
                label: tr('sale.grid.quantity'),
                child: _numberCell(
                  row.quantityController,
                  focusNode: row.quantityFocusNode,
                  maxDecimalDigits: _genelAyarlar.miktarOndalik,
                  readOnly: row.serialNumber != null,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              block(label: tr('sale.grid.unit'), child: _unitCell(row)),
              block(
                label: tr('sale.grid.price'),
                child: _numberCell(
                  row.priceController,
                  focusNode: row.priceFocusNode,
                  maxDecimalDigits: _genelAyarlar.fiyatOndalik,
                  onSubmitted: (_) {
                    _syncRawFromPrice(row);
                    setState(() {});
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              block(
                label: tr('common.raw_price'),
                child: _numberCell(
                  row.rawPriceController,
                  focusNode: row.rawPriceFocusNode,
                  maxDecimalDigits: _genelAyarlar.fiyatOndalik,
                  onSubmitted: (_) {
                    _syncPriceFromRaw(row);
                    setState(() {});
                  },
                ),
              ),
              block(
                label: tr('sale.grid.discount'),
                child: _numberCell(
                  row.discountController,
                  focusNode: row.discountFocusNode,
                  maxDecimalDigits: 2,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              block(
                label: tr('sale.grid.vat'),
                child: _numberCell(
                  row.vatRateController,
                  focusNode: row.vatFocusNode,
                  maxDecimalDigits: 2,
                  onSubmitted: (_) {
                    _syncRawFromPrice(row);
                    setState(() {});
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_genelAyarlar.otvKullanimi)
                block(
                  label: tr('sale.grid.otv'),
                  child: _numberCell(
                    row.otvRateController,
                    focusNode: row.otvFocusNode,
                    maxDecimalDigits: 2,
                    onSubmitted: (_) {
                      _syncRawFromPrice(row);
                      setState(() {});
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              if (_genelAyarlar.oivKullanimi)
                block(
                  label: tr('sale.grid.oiv'),
                  child: _numberCell(
                    row.oivRateController,
                    focusNode: row.oivFocusNode,
                    maxDecimalDigits: 2,
                    onSubmitted: (_) {
                      _syncRawFromPrice(row);
                      setState(() {});
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              if (_genelAyarlar.kdvTevkifati)
                block(
                  label: tr('sale.grid.tevkifat'),
                  child: _tevkifatCell(row),
                ),
              block(
                label: tr('sale.field.currency'),
                child: _currencyCell(row),
              ),
              block(
                label: tr('common.rate'),
                child: _numberCell(
                  row.exchangeRateController,
                  focusNode: row.exchangeRateFocusNode,
                  maxDecimalDigits: _genelAyarlar.kurOndalik,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              block(
                label: tr('sale.grid.total'),
                child: Container(
                  height: 38,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    '${_formatDecimal(tempItem.total, digits: _genelAyarlar.fiyatOndalik)} $_invoiceCurrency',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  SaleItem _buildTempItem(_HizliSatisSatir row) {
    final warehouse = _allWarehouses.firstWhere(
      (w) => w.id == row.warehouseId,
      orElse: () => _allWarehouses.isNotEmpty
          ? _allWarehouses.first
          : const DepoModel(
              id: 0,
              kod: '',
              ad: '-',
              adres: '',
              sorumlu: '',
              telefon: '',
              aktifMi: true,
            ),
    );

    final qty = _parseFlexibleDouble(
      row.quantityController.text,
      maxDecimalDigits: _genelAyarlar.miktarOndalik,
    );
    final price = _parseFlexibleDouble(
      row.priceController.text,
      maxDecimalDigits: _genelAyarlar.fiyatOndalik,
    );
    final discount = _parseFlexibleDouble(
      row.discountController.text,
      maxDecimalDigits: 2,
    );
    final vat = _parseFlexibleDouble(
      row.vatRateController.text,
      maxDecimalDigits: 2,
    );
    final otv = _parseFlexibleDouble(
      row.otvRateController.text,
      maxDecimalDigits: 2,
    );
    final oiv = _parseFlexibleDouble(
      row.oivRateController.text,
      maxDecimalDigits: 2,
    );
    final rate = _parseFlexibleDouble(
      row.exchangeRateController.text,
      maxDecimalDigits: _genelAyarlar.kurOndalik,
    );

    final convertedPrice =
        price * ((rate > 0 ? rate : 1.0) / _invoiceCurrencyRate);

    return SaleItem(
      code: row.code,
      name: row.name,
      barcode: row.barcode,
      unit: row.unit,
      quantity: row.serialNumber != null ? 1 : (qty > 0 ? qty : 0),
      unitPrice: convertedPrice,
      currency: _invoiceCurrency,
      exchangeRate: rate > 0 ? rate : 1.0,
      vatRate: vat,
      discountRate: discount,
      warehouseId: warehouse.id,
      warehouseName: warehouse.ad,
      vatIncluded: row.vatStatus == 'included',
      otvRate: otv,
      otvIncluded: row.otvStatus == 'included',
      oivRate: oiv,
      oivIncluded: row.oivStatus == 'included',
      kdvTevkifatOrani: _parseTevkifat(row.tevkifatValue),
      serialNumber: row.serialNumber,
    );
  }

  Widget _productSearchCell(_HizliSatisSatir row, {required bool dense}) {
    return RawAutocomplete<_UrunSecenek>(
      focusNode: row.productFocusNode,
      textEditingController: row.productSearchController,
      displayStringForOption: (option) => option.product.ad,
      optionsBuilder: (textEditingValue) async {
        final query = textEditingValue.text.trim();
        if (query.isEmpty) {
          return const Iterable<_UrunSecenek>.empty();
        }

        if (row.searchDebounce?.isActive ?? false) {
          row.searchDebounce!.cancel();
        }

        final completer = Completer<Iterable<_UrunSecenek>>();
        row.searchDebounce = Timer(const Duration(milliseconds: 320), () async {
          final options = await _searchProductOptions(query);
          if (!completer.isCompleted) completer.complete(options);
        });

        return completer.future;
      },
      onSelected: (option) async {
        await _applyProductToRow(row, option.product);
        if (!mounted) return;
        _flashRow(row.rowId);
        row.quantityFocusNode.requestFocus();
      },
      optionsViewBuilder: (context, onSelected, options) {
        // Her ürün tile'ı yaklaşık 70px yüksekliğinde
        const double itemHeight = 70.0;
        const double verticalPadding = 16.0; // 8 + 8
        final double calculatedHeight =
            (options.length * itemHeight) + verticalPadding;
        final double dynamicHeight = calculatedHeight.clamp(0, 280).toDouble();

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: dynamicHeight,
                maxWidth: 540,
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return _buildProductOptionTile(
                    option: option,
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: focusNode.hasFocus
                  ? _accentColor.withValues(alpha: 0.6)
                  : Colors.grey.shade200,
              width: focusNode.hasFocus ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: Color(0xFF78909C),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textAlignVertical: TextAlignVertical.center,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: dense ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF202124),
                      height: 1.15,
                    ),
                    onSubmitted: (_) => _onRowProductSubmitted(row),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      hintText: tr('fast_sale.search_hint'),
                      hintStyle: TextStyle(
                        fontSize: dense ? 11 : 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ),
              if (row.code.isNotEmpty || row.barcode.isNotEmpty)
                Tooltip(
                  message:
                      '${row.code} ${row.barcode.isNotEmpty ? '• ${row.barcode}' : ''}',
                  child: Text(
                    row.code,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductOptionTile({
    required _UrunSecenek option,
    required VoidCallback onTap,
  }) {
    final product = option.product;
    final hasStock = product.stok > 0;

    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      hoverColor: const Color(0xFFF5F7FA),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.ad,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF202124),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: option.isProduction
                        ? const Color(0xFFFFF3E0)
                        : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    option.isProduction
                        ? tr('common.production')
                        : tr('common.product'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: option.isProduction
                          ? const Color(0xFFE65100)
                          : const Color(0xFF1565C0),
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
                    'Kod: ${product.kod}${product.barkod.isNotEmpty ? ' • Barkod: ${product.barkod}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: hasStock
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${FormatYardimcisi.sayiFormatla(product.stok)} ${product.birim}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: hasStock
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _warehouseCell(_HizliSatisSatir row) {
    final warehouseItems = _allWarehouses
        .map(
          (w) => DropdownMenuItem<int>(
            value: w.id,
            child: Text(
              w.ad,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        )
        .toList(growable: false);

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          mouseCursor: WidgetStateMouseCursor.clickable,
          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
          value: row.warehouseId,
          isExpanded: true,
          isDense: true,
          menuMaxHeight: 360,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          onChanged: (v) => setState(() => row.warehouseId = v),
          selectedItemBuilder: (context) {
            return _allWarehouses
                .map(
                  (w) => Align(
                    alignment: Alignment.centerLeft,
                    child: Tooltip(
                      message: w.ad,
                      waitDuration: const Duration(milliseconds: 300),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          w.ad,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false);
          },
          items: warehouseItems,
        ),
      ),
    );
  }

  Widget _serialCell(_HizliSatisSatir row) {
    if (row.availableDevices.isEmpty) {
      return Container(
        height: 38,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          tr('fast_sale.serial_not_required'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
      );
    }

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: row.serialNumber == null
              ? const Color(0xFFFFC107)
              : Colors.grey.shade200,
          width: row.serialNumber == null ? 1.5 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          mouseCursor: WidgetStateMouseCursor.clickable,
          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
          value: row.serialNumber,
          isExpanded: true,
          isDense: true,
          hint: Text(tr('common.select'), style: const TextStyle(fontSize: 11)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          onChanged: (v) {
            setState(() {
              row.serialNumber = v;
              if (v != null) {
                row.quantityController.text = '1';
              }
            });
          },
          items: row.availableDevices
              .map(
                (d) => DropdownMenuItem<String>(
                  value: d.identityValue,
                  child: Text(
                    d.identityValue,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _unitCell(_HizliSatisSatir row) {
    final units = _allUnits;
    if (row.unit.isNotEmpty && !units.contains(row.unit)) {
      units.add(row.unit);
    }

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          mouseCursor: WidgetStateMouseCursor.clickable,
          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
          value: row.unit,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          onChanged: (v) {
            if (v == null) return;
            setState(() => row.unit = v);
          },
          items: units
              .map(
                (u) => DropdownMenuItem<String>(
                  value: u,
                  child: Text(
                    u,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _currencyCell(_HizliSatisSatir row) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          mouseCursor: WidgetStateMouseCursor.clickable,
          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
          value: row.currency,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          onChanged: (v) async {
            if (v == null) return;
            final rate = await _fetchRateFromDb(v, _genelAyarlar);
            if (!mounted) return;

            setState(() {
              row.currency = v;
              row.exchangeRateController.text = _formatDecimal(
                rate,
                digits: _genelAyarlar.kurOndalik,
              );
            });
          },
          items: _genelAyarlar.kullanilanParaBirimleri
              .map(
                (c) => DropdownMenuItem<String>(
                  value: c,
                  child: Text(
                    c,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _tevkifatCell(_HizliSatisSatir row) {
    const tevkifatOptions = <String>[
      '0',
      '2/10',
      '3/10',
      '4/10',
      '5/10',
      '7/10',
      '9/10',
      '10/10',
    ];

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          mouseCursor: WidgetStateMouseCursor.clickable,
          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
          value: row.tevkifatValue,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          onChanged: (v) {
            if (v == null) return;
            setState(() => row.tevkifatValue = v);
          },
          items: tevkifatOptions
              .map(
                (v) => DropdownMenuItem<String>(
                  value: v,
                  child: Text(
                    v == '0' ? tr('tevkifat.none') : v,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _numberCell(
    TextEditingController controller, {
    FocusNode? focusNode,
    int? maxDecimalDigits,
    bool readOnly = false,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: focusNode?.hasFocus == true
              ? _accentColor.withValues(alpha: 0.6)
              : Colors.grey.shade200,
          width: focusNode?.hasFocus == true ? 1.4 : 1,
        ),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          textAlign: TextAlign.right,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.15,
            color: readOnly ? Colors.grey.shade600 : const Color(0xFF202124),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            CurrencyInputFormatter(
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
              maxDecimalDigits: maxDecimalDigits,
            ),
            LengthLimitingTextInputFormatter(20),
          ],
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterSection(_HizliSatisToplam totals) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 980;

          final chips = Wrap(
            spacing: 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _totalsChip(tr('sale.footer.subtotal'), totals.subTotal),
              _totalsChip(
                tr('sale.footer.discount'),
                totals.totalDiscount,
                prefix: '-',
              ),
              _totalsChip(tr('sale.footer.vat_total'), totals.totalVat),
              if (_genelAyarlar.otvKullanimi)
                _totalsChip(tr('sale.grid.otv'), totals.totalOtv),
              if (_genelAyarlar.oivKullanimi)
                _totalsChip(tr('sale.grid.oiv'), totals.totalOiv),
              if (_genelAyarlar.kdvTevkifati)
                _totalsChip(
                  tr('sale.grid.tevkifat'),
                  totals.totalTevkifat,
                  prefix: '-',
                ),
            ],
          );

          final totalWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tr('fast_sale.total'),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatDecimal(totals.grandTotal, digits: _genelAyarlar.fiyatOndalik)} $_invoiceCurrency',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _primaryColor,
                ),
              ),
            ],
          );

          final completeButton = SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isCompletingSale ? null : _completeSale,
              icon: _isCompletingSale
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.shopping_cart_checkout_rounded, size: 20),
              label: Text(
                tr('fast_sale.complete_button'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                chips,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: totalWidget),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: completeButton),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: chips),
              const SizedBox(width: 16),
              totalWidget,
              const SizedBox(width: 16),
              completeButton,
            ],
          );
        },
      ),
    );
  }

  Widget _totalsChip(
    String label,
    double value, {
    String prefix = '',
    IconData? icon,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? const Color(0xFFF5F7FA)).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (color ?? const Color(0xFFF5F7FA)).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color ?? const Color(0xFF5F6368)),
            const SizedBox(width: 6),
          ],
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color ?? const Color(0xFF5F6368),
            ),
          ),
          Text(
            '$prefix${_formatDecimal(value, digits: _genelAyarlar.fiyatOndalik)} $_invoiceCurrency',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color ?? const Color(0xFF202124),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String Function(T)? itemTextBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A4A4A),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: DropdownButtonFormField<T>(
            mouseCursor: WidgetStateMouseCursor.clickable,
            dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
            initialValue: value,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            items: items
                .map(
                  (item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      itemTextBuilder != null
                          ? itemTextBuilder(item)
                          : item.toString(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductResolveResult {
  final UrunModel product;
  final String? serialNumber;

  const _ProductResolveResult({required this.product, this.serialNumber});
}

class _UrunSecenek {
  final UrunModel product;
  final bool isProduction;

  const _UrunSecenek({required this.product, required this.isProduction});
}

class _HizliSatisToplam {
  final double subTotal;
  final double totalDiscount;
  final double totalVat;
  final double totalOtv;
  final double totalOiv;
  final double totalTevkifat;
  final double grandTotal;

  const _HizliSatisToplam({
    required this.subTotal,
    required this.totalDiscount,
    required this.totalVat,
    required this.totalOtv,
    required this.totalOiv,
    required this.totalTevkifat,
    required this.grandTotal,
  });
}

class _HizliSatisSatir {
  final int rowId;

  int? productId = 0;
  String code = '';
  String barcode = '';
  String name = '';

  int? warehouseId;
  String unit;
  String currency;

  String vatStatus;
  String otvStatus;
  String oivStatus;
  String tevkifatValue;

  String? serialNumber;
  List<CihazModel> availableDevices = <CihazModel>[];

  final TextEditingController productSearchController;
  final FocusNode productFocusNode;

  final TextEditingController quantityController;
  final TextEditingController priceController;
  final TextEditingController rawPriceController;
  final TextEditingController discountController;
  final TextEditingController vatRateController;
  final TextEditingController otvRateController;
  final TextEditingController oivRateController;
  final TextEditingController exchangeRateController;

  final FocusNode quantityFocusNode;
  final FocusNode priceFocusNode;
  final FocusNode rawPriceFocusNode;
  final FocusNode discountFocusNode;
  final FocusNode vatFocusNode;
  final FocusNode otvFocusNode;
  final FocusNode oivFocusNode;
  final FocusNode exchangeRateFocusNode;

  Timer? searchDebounce;

  _HizliSatisSatir({
    required this.rowId,
    required this.productSearchController,
    required this.productFocusNode,
    required this.quantityController,
    required this.priceController,
    required this.rawPriceController,
    required this.discountController,
    required this.vatRateController,
    required this.otvRateController,
    required this.oivRateController,
    required this.exchangeRateController,
    required this.quantityFocusNode,
    required this.priceFocusNode,
    required this.rawPriceFocusNode,
    required this.discountFocusNode,
    required this.vatFocusNode,
    required this.otvFocusNode,
    required this.oivFocusNode,
    required this.exchangeRateFocusNode,
    required this.warehouseId,
    required this.unit,
    required this.currency,
    required this.vatStatus,
    required this.otvStatus,
    required this.oivStatus,
    required this.tevkifatValue,
  });

  void dispose() {
    searchDebounce?.cancel();

    productSearchController.dispose();
    productFocusNode.dispose();

    quantityController.dispose();
    priceController.dispose();
    rawPriceController.dispose();
    discountController.dispose();
    vatRateController.dispose();
    otvRateController.dispose();
    oivRateController.dispose();
    exchangeRateController.dispose();

    quantityFocusNode.dispose();
    priceFocusNode.dispose();
    rawPriceFocusNode.dispose();
    discountFocusNode.dispose();
    vatFocusNode.dispose();
    otvFocusNode.dispose();
    oivFocusNode.dispose();
    exchangeRateFocusNode.dispose();
  }
}
