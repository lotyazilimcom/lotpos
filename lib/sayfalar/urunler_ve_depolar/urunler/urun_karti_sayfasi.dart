import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../bilesenler/genisletilebilir_tablo.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/ceviri/islem_ceviri_yardimcisi.dart';
import '../../../yardimcilar/islem_turu_renkleri.dart';
import '../../../bilesenler/tarih_araligi_secici_dialog.dart';
import 'modeller/urun_model.dart';

import '../../../servisler/ayarlar_veritabani_servisi.dart';
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import '../../../servisler/sayfa_senkronizasyon_servisi.dart';
import '../../../servisler/depolar_veritabani_servisi.dart';
import '../../../servisler/urunler_veritabani_servisi.dart';
import '../../urunler_ve_depolar/depolar/modeller/depo_model.dart';
import '../../ortak/genisletilebilir_print_preview_screen.dart';
import '../../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../../../bilesenler/highlight_text.dart';
import 'modeller/cihaz_model.dart';

class UrunKartiSayfasi extends StatefulWidget {
  const UrunKartiSayfasi({super.key, required this.urun});

  final UrunModel urun;

  @override
  State<UrunKartiSayfasi> createState() => _UrunKartiSayfasiState();
}

class _UrunKartiSayfasiState extends State<UrunKartiSayfasi> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late UrunModel _currentUrun;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();
  // bool _isLoading = false; // Unused
  final FocusNode _searchFocusNode = FocusNode();

  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  bool _isInfoCardExpanded = false;
  int? _selectedRowId;
  Map<String, bool> _columnVisibility = {};
  final Map<String, bool> _serialListColumnVisibility = {
    'barkod': true,
    'imei_seri': true,
    'islem': true,
    'tarih': true,
    'alis_fiyati': true,
    'satis_fiyati': true,
    'kdv': true,
    'kdv_oran': true,
    'kdv_tutar': true,
  };

  OverlayEntry? _overlayEntry;

  // bool _isSelectAllActive = false; // Unused
  // final Map<int, Set<int>> _selectedDetailIds = {}; // Unused
  List<Map<String, dynamic>> _cachedTransactions = [];
  List<Map<String, dynamic>> _allTransactions = [];
  int _totalRecords = 0;
  Map<String, Map<String, int>> _filterStats = {};

  // "Sadece Listeyi Göster" (Seri/IMEI ürünler için stoktaki cihaz listesi)
  bool _isSerialListMode = false;
  bool _isSerialNumberedProduct = false;
  bool _isSerialListLoading = false;
  List<Map<String, dynamic>> _cachedSerialRows = [];
  List<Map<String, dynamic>> _allSerialRows = [];
  int _serialTotalRecords = 0;

  // Liste moduna girerken mevcut filtreleri geri yüklemek için sakla
  String? _savedTransactionTypeBeforeSerialList;
  DepoModel? _savedWarehouseBeforeSerialList;
  String? _savedUnitBeforeSerialList;
  String? _savedUserBeforeSerialList;
  bool? _savedAutoKeepDetailsOpenBeforeSerialList;
  bool? _savedIsManuallyClosedDuringFilterBeforeSerialList;

  // Table Selection State
  Set<int> _selectedTransactionIds = {};
  bool _isSelectAllActive = false;

  bool _keepDetailsOpen = false;
  bool _autoKeepDetailsOpen = false;
  bool _isManuallyClosedDuringFilter = false;
  final Set<int> _expandedTransactionIds = {}; // Added for expandable rows
  final Set<int> _searchAutoExpandedTransactionIds = {};

  int? _sortColumnIndex = 1;
  bool _sortAscending = false;
  Timer? _debounce;
  // Transaction Type Filter State
  String? _selectedTransactionType;
  bool _isTransactionFilterExpanded = false;
  final LayerLink _transactionLayerLink = LayerLink();
  List<String> _availableTransactionTypes = [];

  // Unit Filter State
  String? _selectedUnit;
  bool _isUnitFilterExpanded = false;
  final LayerLink _unitLayerLink = LayerLink();
  List<String> _availableUnits = [];

  // Warehouse Filter State
  DepoModel? _selectedWarehouse;
  bool _isWarehouseFilterExpanded = false;
  final LayerLink _warehouseLayerLink = LayerLink();
  List<DepoModel> _warehouses = [];

  // User Filter State
  String? _selectedUser;
  bool _isUserFilterExpanded = false;
  final LayerLink _userLayerLink = LayerLink();
  List<String> _availableUsers = [];

  // Image Cache
  final Map<String, MemoryImage> _imageCache = {};

  MemoryImage? _getCachedMemoryImage(String base64String) {
    if (base64String.isEmpty) return null;
    try {
      String b64 = base64String;
      if (b64.contains(',')) {
        b64 = b64.split(',').last;
      }
      if (_imageCache.containsKey(b64)) {
        return _imageCache[b64];
      }
      final bytes = base64Decode(b64);
      final image = MemoryImage(bytes);
      _imageCache[b64] = image;
      return image;
    } catch (e) {
      debugPrint('Image decode error: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUrun = widget.urun;
    _availableUnits = [
      (_currentUrun.birim.toString().trim().isNotEmpty)
          ? _currentUrun.birim.toString().trim()
          : 'Adet',
    ];

    _columnVisibility = {
      'islem': true,
      'tarih': true,
      'miktar': true,
      'birim': true,
      'fiyat': true,
      'tutar': true,
      'depo': true,
      'aciklama': true,
      'kullanici': true,
      'dev_identity': true,
      'dev_status': true,
      'dev_color': true,
      'dev_capacity': true,
      'dev_warranty': true,
      'dev_box': true,
      'dev_invoice': true,
      'dev_charger': true,
    };

    _loadSettings();
    _loadAvailableFilters();
    _loadAvailableUsers();
    _fetchWarehouses();
    _loadTransactions();

    SayfaSenkronizasyonServisi().addListener(_onGlobalSync);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
    if (mounted) {
      setState(() {
        _keepDetailsOpen =
            prefs.getBool('urun_karti_keep_details_open') ?? false;
        _genelAyarlar = settings;
      });
    }
  }

  Future<void> _loadAvailableFilters() async {
    try {
      final types = await DepolarVeritabaniServisi()
          .getMevcutStokIslemTurleri();

      if (mounted) {
        setState(() {
          _availableTransactionTypes = types;
        });
      }
    } catch (e) {
      debugPrint('Filtre yükleme hatası: $e');
    }
  }

  Future<void> _loadAvailableUsers() async {
    try {
      final users = await AyarlarVeritabaniServisi().kullanicilariGetir(
        sayfa: 1,
        sayfaBasinaKayit: 500,
        aktifMi: true,
      );

      final usernames =
          users
              .map((u) => u.kullaniciAdi)
              .where((u) => u.trim().isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (mounted) {
        setState(() {
          _availableUsers = usernames;
        });
      }
    } catch (e) {
      debugPrint('Kullanıcı filtre yükleme hatası: $e');
    }
  }

  Future<void> _fetchWarehouses() async {
    try {
      final warehouses = await DepolarVeritabaniServisi().tumDepolariGetir();
      if (mounted) {
        setState(() {
          _warehouses = warehouses;
        });
      }
    } catch (e) {
      debugPrint('Error fetching warehouses: $e');
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final depoServis = DepolarVeritabaniServisi();

      final List<int>? selectedWarehouseIds = _selectedWarehouse != null
          ? [_selectedWarehouse!.id]
          : null;

      final transactionsFuture = depoServis.urunHareketleriniGetir(
        _currentUrun.kod,
        kdvOrani: _currentUrun.kdvOrani,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        islemTuru: _selectedTransactionType,
        warehouseIds: selectedWarehouseIds,
        kullanici: _selectedUser,
      );

      final statsFuture = depoServis.urunHareketFiltreIstatistikleriniGetir(
        _currentUrun.kod,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        warehouseIds: selectedWarehouseIds,
        islemTuru: _selectedTransactionType,
        kullanici: _selectedUser,
      );

      final transactions = await transactionsFuture;
      final stats = await statsFuture;

      final mappedTransactions = transactions.map((t) {
        return {
          'id': t['id'],
          'islem_turu': t['customTypeLabel'] ?? t['type'] ?? '',
          'customTypeLabel': t['customTypeLabel'],
          'isIncoming': t['isIncoming'],
          'tarih': t['date'],
          'miktar': t['quantity'],
          'birim': (t['unit'] ?? _currentUrun.birim).toString(),
          'birim_fiyat': t['unitPrice'],
          'unitPriceVat': t['unitPriceVat'],
          'tutar':
              (t['quantity'] is num ? t['quantity'] : 0) *
              (t['unitPrice'] is num ? t['unitPrice'] : 0),
          'depo_adi': t['warehouse'],
          'aciklama': t['description'],
          'kullanici': t['user'],
          'relatedPartyName': t['relatedPartyName'],
          'relatedPartyCode': t['relatedPartyCode'],
          'sourceSuffix': t['sourceSuffix'],
          'devices': t['devices'], // Added devices
        };
      }).toList();

      final bool hasAnyDevice = mappedTransactions.any(
        (tx) => (tx['devices'] as List?)?.isNotEmpty == true,
      );

      final Map<String, int> unitCounts = {};
      for (final tx in mappedTransactions) {
        final String u = (tx['birim'] ?? '').toString().trim();
        if (u.isEmpty) continue;
        unitCounts[u] = (unitCounts[u] ?? 0) + 1;
      }

      final units = unitCounts.keys.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      final filteredTransactions = _selectedUnit == null
          ? mappedTransactions
          : mappedTransactions
                .where((tx) => (tx['birim'] ?? '').toString() == _selectedUnit)
                .toList();

      stats['birimler'] = unitCounts;

      final baseTransactions = filteredTransactions;
      final searchResult = _filterTransactionsForSearch(
        baseTransactions,
        _searchQuery,
      );

      if (mounted) {
        setState(() {
          _isSerialNumberedProduct = _isSerialNumberedProduct || hasAnyDevice;
          _allTransactions = baseTransactions;
          _cachedTransactions = searchResult.filtered;
          _totalRecords = searchResult.filtered.length;
          _filterStats = stats;
          _searchAutoExpandedTransactionIds
            ..clear()
            ..addAll(searchResult.expandedIds);

          final bool isSearchActive = _searchQuery.trim().isNotEmpty;
          final bool hasNonSearchFilters = _hasActiveNonSearchFilters;
          final bool hasExpandableRows = searchResult.filtered.any(
            (tx) => (tx['devices'] as List?)?.isNotEmpty == true,
          );

          if (hasNonSearchFilters &&
              hasExpandableRows &&
              !_isManuallyClosedDuringFilter) {
            _autoKeepDetailsOpen = true;
          } else if (isSearchActive &&
              searchResult.filtered.isNotEmpty &&
              searchResult.expandedIds.isNotEmpty &&
              !_isManuallyClosedDuringFilter) {
            _autoKeepDetailsOpen = true;
          } else if (!isSearchActive && !hasNonSearchFilters) {
            _autoKeepDetailsOpen = false;
            _isManuallyClosedDuringFilter = false;
          }

          _availableUnits = units.isNotEmpty
              ? units
              : [
                  (_currentUrun.birim.toString().trim().isNotEmpty)
                      ? _currentUrun.birim.toString().trim()
                      : 'Adet',
                ];
        });
      }
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    }
  }

  void _refreshCurrentView() {
    if (_isSerialListMode) {
      _loadSerialListRows();
    } else {
      _loadTransactions();
    }
  }

  Future<void> _toggleSerialListMode() async {
    _closeOverlay();

    if (_isSerialListMode) {
      setState(() {
        _isSerialListMode = false;
        _isSerialListLoading = false;
        _cachedSerialRows.clear();
        _allSerialRows.clear();
        _serialTotalRecords = 0;

        // Filtreleri geri yükle
        _selectedTransactionType = _savedTransactionTypeBeforeSerialList;
        _selectedWarehouse = _savedWarehouseBeforeSerialList;
        _selectedUnit = _savedUnitBeforeSerialList;
        _selectedUser = _savedUserBeforeSerialList;
        if (_savedAutoKeepDetailsOpenBeforeSerialList != null) {
          _autoKeepDetailsOpen = _savedAutoKeepDetailsOpenBeforeSerialList!;
        }
        if (_savedIsManuallyClosedDuringFilterBeforeSerialList != null) {
          _isManuallyClosedDuringFilter =
              _savedIsManuallyClosedDuringFilterBeforeSerialList!;
        }

        _savedTransactionTypeBeforeSerialList = null;
        _savedWarehouseBeforeSerialList = null;
        _savedUnitBeforeSerialList = null;
        _savedUserBeforeSerialList = null;
        _savedAutoKeepDetailsOpenBeforeSerialList = null;
        _savedIsManuallyClosedDuringFilterBeforeSerialList = null;

        // Seçimleri temizle
        _selectedTransactionIds.clear();
        _isSelectAllActive = false;
        _selectedRowId = null;
      });

      _loadTransactions();
      return;
    }

    // Liste moduna girerken filtreleri sakla ve tarih filtresi hariç pasif hale getir
    setState(() {
      _savedTransactionTypeBeforeSerialList = _selectedTransactionType;
      _savedWarehouseBeforeSerialList = _selectedWarehouse;
      _savedUnitBeforeSerialList = _selectedUnit;
      _savedUserBeforeSerialList = _selectedUser;
      _savedAutoKeepDetailsOpenBeforeSerialList = _autoKeepDetailsOpen;
      _savedIsManuallyClosedDuringFilterBeforeSerialList =
          _isManuallyClosedDuringFilter;

      _selectedTransactionType = null;
      _selectedWarehouse = null;
      _selectedUnit = null;
      _selectedUser = null;

      _isSerialListMode = true;
      _isSerialListLoading = true;

      // Detay/expand ile ilgili state'i temizle
      _autoKeepDetailsOpen = false;
      _expandedTransactionIds.clear();
      _searchAutoExpandedTransactionIds.clear();

      // Seçimleri temizle
      _selectedTransactionIds.clear();
      _isSelectAllActive = false;
      _selectedRowId = null;
    });

    await _loadSerialListRows();
  }

  DateTime? _parseDeviceRowDateTime(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s == '-') return null;
    try {
      // DepolarVeritabaniServisi: "d.M.yyyy HH:mm"
      return DateFormat('d.M.yyyy HH:mm').parse(s);
    } catch (_) {
      return null;
    }
  }

  bool _isWithinSelectedDateRange(DateTime? dt) {
    if (_startDate == null && _endDate == null) return true;
    if (dt == null) return false;

    final DateTime start = _startDate != null
        ? DateTime(_startDate!.year, _startDate!.month, _startDate!.day)
        : DateTime.fromMillisecondsSinceEpoch(0);

    final DateTime end = _endDate != null
        ? DateTime(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day,
            23,
            59,
            59,
            999,
          )
        : DateTime(9999, 12, 31, 23, 59, 59, 999);

    return !dt.isBefore(start) && !dt.isAfter(end);
  }

  List<Map<String, dynamic>> _filterSerialRowsForSearch(
    List<Map<String, dynamic>> base,
    String query,
  ) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return base;

    final lowerQuery = _turkishToLower(trimmed);
    return base
        .where((row) {
          return _containsSearchAny([
            (row['barkod'] ?? '').toString(),
            (row['imei_seri'] ?? '').toString(),
            (row['islem'] ?? '').toString(),
            (row['tarih'] ?? '').toString(),
            (row['alis_fiyati_text'] ?? '').toString(),
            (row['satis_fiyati_text'] ?? '').toString(),
            (row['kdv_text'] ?? '').toString(),
            (row['kdv_oran_text'] ?? '').toString(),
            (row['kdv_tutar_text'] ?? '').toString(),
          ], lowerQuery);
        })
        .toList(growable: false);
  }

  Future<void> _loadSerialListRows() async {
    if (mounted) {
      setState(() {
        _isSerialListLoading = true;
      });
    }

    try {
      final urunlerServis = UrunlerVeritabaniServisi();
      final depoServis = DepolarVeritabaniServisi();

      // 1) Stoktaki cihazları getir (is_sold = 0)
      List<CihazModel> cihazlar = await urunlerServis.cihazlariGetir(
        _currentUrun.id,
      );

      // Eğer stokta cihaz yoksa (ör: stok 0), yine de "veriler gelmedi" algısını
      // önlemek için ürünün tüm cihazlarını getir (satılmış olanlar dahil).
      if (cihazlar.isEmpty) {
        try {
          final pool = urunlerServis.getPool();
          if (pool != null) {
            final result = await pool.execute(
              Sql.named(
                'SELECT * FROM product_devices WHERE product_id = @id ORDER BY id ASC',
              ),
              parameters: {'id': _currentUrun.id},
            );
            cihazlar = result
                .map((row) => CihazModel.fromMap(row.toColumnMap()))
                .toList(growable: false);
          }
        } catch (_) {
          // ignore fallback errors
        }
      }

      // Ürün seri/IMEI takipli ise buton görünsün
      if (mounted) {
        setState(() {
          _isSerialNumberedProduct =
              _isSerialNumberedProduct || cihazlar.isNotEmpty;
        });
      }

      // 2) Son işlem/tarih bilgisini yakalamak için son stok hareketlerini getir (250 limit)
      final txs = await depoServis.urunHareketleriniGetir(
        _currentUrun.kod,
        kdvOrani: _currentUrun.kdvOrani,
      );

      // identityValue -> (typeLabel, dateText, dateTime)
      final Map<
        String,
        ({String typeLabel, String dateText, DateTime? dateTime})
      >
      latestByIdentity = {};

      for (final t in txs) {
        final String rawDate = (t['date'] ?? '').toString();
        final DateTime? dt = _parseDeviceRowDateTime(rawDate);

        final String rawType = (t['customTypeLabel'] ?? t['type'] ?? '')
            .toString();
        final String typeLabel = rawType.trim().isEmpty
            ? '-'
            : _formatStockTransactionTypeLabel(rawType);

        final rawDevices = t['devices'];
        if (rawDevices is! List || rawDevices.isEmpty) continue;

        for (final raw in rawDevices) {
          if (raw is! Map) continue;
          final device = _normalizeDeviceMap(raw.cast<String, dynamic>());
          final identity = (device['identityValue'] ?? '').toString().trim();
          if (identity.isEmpty) continue;

          // txs zaten DESC geliyor; ilk gördüğümüz en güncel işlem
          if (latestByIdentity.containsKey(identity)) continue;
          latestByIdentity[identity] = (
            typeLabel: typeLabel,
            dateText: rawDate.isNotEmpty ? rawDate : '-',
            dateTime: dt,
          );
        }
      }

      // 3) Satırları hazırla (tarih aralığına göre filtrele)
      final String barkod = _currentUrun.barkod.trim().isNotEmpty
          ? _currentUrun.barkod.trim()
          : '-';

      final String kdvText = tr('common.vat_excluded');
      final double kdvOrani = _currentUrun.kdvOrani;
      final String kdvOranText = FormatYardimcisi.sayiFormatlaOran(
        kdvOrani,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: 2,
      );

      final double alisFiyat = _currentUrun.alisFiyati;
      final double satisFiyat = _currentUrun.satisFiyati1;
      final double kdvTutar = satisFiyat * (kdvOrani / 100);

      final String alisFiyatText =
          '${FormatYardimcisi.sayiFormatlaOndalikli(alisFiyat, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_genelAyarlar.varsayilanParaBirimi}';
      final String satisFiyatText =
          '${FormatYardimcisi.sayiFormatlaOndalikli(satisFiyat, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_genelAyarlar.varsayilanParaBirimi}';
      final String kdvTutarText =
          '${FormatYardimcisi.sayiFormatlaOndalikli(kdvTutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_genelAyarlar.varsayilanParaBirimi}';

      int rowId = 1;
      final rows = <Map<String, dynamic>>[];

      for (final cihaz in cihazlar) {
        final identity = cihaz.identityValue.trim();
        if (identity.isEmpty) continue;

        final latest = latestByIdentity[identity];
        final DateTime? dt = latest?.dateTime;

        if (!_isWithinSelectedDateRange(dt)) {
          continue;
        }

        rows.add({
          'id': rowId++,
          'barkod': barkod,
          'imei_seri': identity,
          'islem': latest?.typeLabel ?? '-',
          'tarih': latest?.dateText ?? '-',
          'tarih_dt': dt,
          'alis_fiyati_text': alisFiyatText,
          'satis_fiyati_text': satisFiyatText,
          'kdv_text': kdvText,
          'kdv_oran_text': kdvOranText,
          'kdv_tutar_text': kdvTutarText,
        });
      }

      final filtered = _filterSerialRowsForSearch(rows, _searchQuery);

      if (mounted) {
        setState(() {
          _allSerialRows = rows;
          _cachedSerialRows = filtered;
          _serialTotalRecords = filtered.length;
          _isSerialListLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Seri liste yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _cachedSerialRows = const [];
          _allSerialRows = const [];
          _serialTotalRecords = 0;
          _isSerialListLoading = false;
        });
      }
    }
  }

  String _turkishToLower(String input) {
    return input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .replaceAll('i̇', 'i');
  }

  bool _containsSearch(String text, String lowerQuery) {
    if (lowerQuery.isEmpty) return true;
    return _turkishToLower(text).contains(lowerQuery);
  }

  bool _containsSearchAny(Iterable<String> texts, String lowerQuery) {
    for (final t in texts) {
      if (t.isEmpty) continue;
      if (_containsSearch(t, lowerQuery)) return true;
    }
    return false;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final raw = value.toString().trim();
    if (raw.isEmpty) return 0.0;
    return double.tryParse(raw.replaceAll(',', '.')) ?? 0.0;
  }

  bool _matchesTransactionMainFieldsForSearch(
    Map<String, dynamic> tx,
    String lowerQuery,
  ) {
    final int? id = tx['id'] is int
        ? tx['id'] as int
        : int.tryParse(tx['id']?.toString() ?? '');

    final String rawType = (tx['customTypeLabel'] ?? tx['islem_turu'] ?? '')
        .toString();
    final String formattedType = rawType.trim().isEmpty
        ? ''
        : _formatStockTransactionTypeLabel(rawType);

    final double qty = _toDouble(tx['miktar']);
    final double unitPrice = _toDouble(tx['birim_fiyat']);
    final double unitPriceVat = tx['unitPriceVat'] != null
        ? _toDouble(tx['unitPriceVat'])
        : unitPrice * (1 + _currentUrun.kdvOrani / 100);
    final double total = _toDouble(tx['tutar']);

    final String qtyFormatted = FormatYardimcisi.sayiFormatla(
      qty,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.miktarOndalik,
    );

    final String unitPriceFormatted = FormatYardimcisi.sayiFormatlaOndalikli(
      unitPrice,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.fiyatOndalik,
    );

    final String unitPriceVatFormatted = FormatYardimcisi.sayiFormatlaOndalikli(
      unitPriceVat,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.fiyatOndalik,
    );

    final String totalFormatted = FormatYardimcisi.sayiFormatlaOndalikli(
      total,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.fiyatOndalik,
    );

    return _containsSearchAny([
      if (id != null) id.toString(),
      rawType,
      formattedType,
      (tx['relatedPartyName'] ?? '').toString(),
      (tx['relatedPartyCode'] ?? '').toString(),
      (tx['tarih'] ?? '').toString(),
      (tx['depo_adi'] ?? '').toString(),
      (tx['birim'] ?? '').toString(),
      (tx['aciklama'] ?? '').toString(),
      (tx['kullanici'] ?? '').toString(),
      qtyFormatted,
      qty.toString(),
      unitPriceFormatted,
      unitPrice.toString(),
      unitPriceVatFormatted,
      unitPriceVat.toString(),
      totalFormatted,
      total.toString(),
    ], lowerQuery);
  }

  bool _matchesTransactionDeviceFieldsForSearch(
    Map<String, dynamic> tx,
    String lowerQuery,
  ) {
    final rawDevices = tx['devices'];
    if (rawDevices is! List || rawDevices.isEmpty) return false;

    for (final raw in rawDevices) {
      if (raw is! Map) continue;
      final device = _normalizeDeviceMap(raw.cast<String, dynamic>());

      final identity = device['identityValue']?.toString() ?? '';
      final condition = device['condition']?.toString() ?? '';
      final color = device['color']?.toString() ?? '';
      final capacity = device['capacity']?.toString() ?? '';
      final warrantyRaw = device['warrantyEndDate']?.toString() ?? '';
      final warrantyFormatted = _formatDateOrDash(device['warrantyEndDate']);

      final hasBox = _toBool(device['hasBox']);
      final hasInvoice = _toBool(device['hasInvoice']);
      final hasCharger = _toBool(device['hasOriginalCharger']);

      final boxText = hasBox ? tr('common.yes') : '-';
      final invoiceText = hasInvoice ? tr('common.yes') : '-';
      final chargerText = hasCharger ? tr('common.yes') : '-';

      if (_containsSearchAny([
        identity,
        condition,
        color,
        capacity,
        warrantyRaw,
        warrantyFormatted,
        boxText,
        invoiceText,
        chargerText,
      ], lowerQuery)) {
        return true;
      }
    }

    return false;
  }

  ({List<Map<String, dynamic>> filtered, Set<int> expandedIds})
  _filterTransactionsForSearch(List<Map<String, dynamic>> base, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return (filtered: base, expandedIds: <int>{});
    }

    final lowerQuery = _turkishToLower(trimmed);

    final filtered = <Map<String, dynamic>>[];
    final expandedIds = <int>{};

    for (final tx in base) {
      final matchMain = _matchesTransactionMainFieldsForSearch(tx, lowerQuery);
      final matchDevices = _matchesTransactionDeviceFieldsForSearch(
        tx,
        lowerQuery,
      );

      if (matchMain || matchDevices) {
        filtered.add(tx);
        if (matchDevices) {
          final int? id = tx['id'] is int
              ? tx['id'] as int
              : int.tryParse(tx['id']?.toString() ?? '');
          if (id != null) expandedIds.add(id);
        }
      }
    }

    return (filtered: filtered, expandedIds: expandedIds);
  }

  void _applySearchQuery(String query) {
    if (_isSerialListMode) {
      final filtered = _filterSerialRowsForSearch(_allSerialRows, query);
      setState(() {
        _searchQuery = query;
        _cachedSerialRows = filtered;
        _serialTotalRecords = filtered.length;
      });
      return;
    }

    final searchResult = _filterTransactionsForSearch(_allTransactions, query);

    setState(() {
      _searchQuery = query;
      _cachedTransactions = searchResult.filtered;
      _totalRecords = searchResult.filtered.length;
      _searchAutoExpandedTransactionIds
        ..clear()
        ..addAll(searchResult.expandedIds);

      final bool isSearchActive = _searchQuery.trim().isNotEmpty;
      final bool hasNonSearchFilters = _hasActiveNonSearchFilters;
      final bool hasExpandableRows = searchResult.filtered.any(
        (tx) => (tx['devices'] as List?)?.isNotEmpty == true,
      );

      if (hasNonSearchFilters &&
          hasExpandableRows &&
          !_isManuallyClosedDuringFilter) {
        _autoKeepDetailsOpen = true;
      } else if (isSearchActive &&
          searchResult.filtered.isNotEmpty &&
          searchResult.expandedIds.isNotEmpty &&
          !_isManuallyClosedDuringFilter) {
        _autoKeepDetailsOpen = true;
      } else if (!isSearchActive && !hasNonSearchFilters) {
        _autoKeepDetailsOpen = false;
        _isManuallyClosedDuringFilter = false;
      }
    });
  }

  void _onGlobalSync() {
    _refreshCurrentView();
  }

  @override
  void dispose() {
    SayfaSenkronizasyonServisi().removeListener(_onGlobalSync);
    _searchController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();

    _searchFocusNode.dispose();
    _overlayEntry?.remove();
    _debounce?.cancel();
    super.dispose();
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _isTransactionFilterExpanded = false;
        _isWarehouseFilterExpanded = false;
        _isUnitFilterExpanded = false;
        _isUserFilterExpanded = false;
      });
    }
  }

  Future<void> _handlePrint() async {
    // Determine which rows to process
    final bool isSerialMode = _isSerialListMode;
    final Set<int> selectedIds = _selectedTransactionIds;
    final source = isSerialMode ? _cachedSerialRows : _cachedTransactions;
    final dataToProcess = selectedIds.isNotEmpty
        ? source.where((t) => selectedIds.contains(t['id'] as int)).toList()
        : source;

    if (dataToProcess.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('purchase.error.no_items')),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // 1) HEADER INFO (Ürün Bilgileri Kartı) - Cari kartı ile aynı mantık
      const String paraBirimi = 'TL';
      final urun = _currentUrun;
      final stokMiktari = FormatYardimcisi.sayiFormatla(
        urun.stok,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: _genelAyarlar.miktarOndalik,
      );

      final Map<String, dynamic> headerInfo = {
        'type': 'product',
        'images': urun.resimler,
        'name': urun.ad,
        'code': urun.kod,
        'group': urun.grubu,
        'barcode': urun.barkod,
        'unit': urun.birim,
        'vatRate': '%${urun.kdvOrani}',
        'stockQty': stokMiktari,
        'stockText': 'Stok: $stokMiktari ${urun.birim}',
        'stockPositive': urun.stok > 0,
        'buyPrice':
            '${FormatYardimcisi.sayiFormatlaOndalikli(urun.alisFiyati, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} $paraBirimi',
        'sellPrice1':
            '${FormatYardimcisi.sayiFormatlaOndalikli(urun.satisFiyati1, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} $paraBirimi',
        'sellPrice2':
            '${FormatYardimcisi.sayiFormatlaOndalikli(urun.satisFiyati2, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} $paraBirimi',
        'features': urun.ozellikler,
        'isExpanded': _isInfoCardExpanded,
      };

      // 2) DATE INTERVAL / FILTER SUMMARY
      String? dateInfo;
      final df = DateFormat('dd.MM.yyyy');

      if (_startDate != null && _endDate != null) {
        dateInfo =
            '${tr('common.date_range')}: ${df.format(_startDate!)} - ${df.format(_endDate!)}';
      } else if (_startDate != null) {
        dateInfo =
            '${tr('common.date_range')}: ${df.format(_startDate!)} - ...';
      }

      if (_selectedWarehouse != null) {
        final whInfo = '${tr('common.warehouse')}: ${_selectedWarehouse!.ad}';
        dateInfo = dateInfo == null ? whInfo : '$dateInfo | $whInfo';
      }

      if (_selectedUnit != null) {
        final unitInfo = '${tr('common.unit')}: $_selectedUnit';
        dateInfo = dateInfo == null ? unitInfo : '$dateInfo | $unitInfo';
      }

      if (_selectedTransactionType != null) {
        final txInfo =
            '${tr('common.transaction_type')}: ${_formatStockTransactionTypeLabel(_selectedTransactionType!)}';
        dateInfo = dateInfo == null ? txInfo : '$dateInfo | $txInfo';
      }

      if (_selectedUser != null) {
        final userInfo = '${tr('common.user')}: $_selectedUser';
        dateInfo = dateInfo == null ? userInfo : '$dateInfo | $userInfo';
      }

      final List<CustomContentToggle> headerToggles = [
        CustomContentToggle(key: 'p_images', label: tr('common.images')),
        CustomContentToggle(key: 'p_name', label: tr('common.name')),
        CustomContentToggle(key: 'p_code', label: tr('common.code')),
        CustomContentToggle(key: 'p_group', label: tr('products.table.group')),
        CustomContentToggle(
          key: 'p_stock_summary',
          label: tr('products.table.stock'),
        ),
        CustomContentToggle(
          key: 'p_prices',
          label: tr('products.card.section.pricing'),
        ),
        CustomContentToggle(
          key: 'p_stock_tax',
          label: tr('products.card.section.stock_tax'),
        ),
        CustomContentToggle(
          key: 'p_features',
          label: tr('products.card.section.features_description'),
        ),
      ];

      if (isSerialMode) {
        final rows = <ExpandableRowData>[];
        int index = 1;

        for (final row in dataToProcess) {
          rows.add(
            ExpandableRowData(
              isExpanded: false,
              mainRow: [
                index.toString(), // Sıra No
                (row['barkod'] ?? '-').toString(), // Barkod
                (row['imei_seri'] ?? '-').toString(), // IMEI / Seri No
                (row['islem'] ?? '-').toString(), // İşlem
                (row['tarih'] ?? '-').toString(), // Tarih
                (row['alis_fiyati_text'] ?? '-').toString(), // Alış Fiyatı
                (row['satis_fiyati_text'] ?? '-').toString(), // Satış Fiyatı
                (row['kdv_text'] ?? '-').toString(), // KDV
                (row['kdv_oran_text'] ?? '-').toString(), // KDV %
                (row['kdv_tutar_text'] ?? '-').toString(), // KDV Tutar
              ],
            ),
          );
          index++;
        }

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GenisletilebilirPrintPreviewScreen(
                title: tr('products.card.title'),
                headers: [
                  tr('common.order_no'),
                  tr('common.barcode'),
                  tr('products.devices.identity'),
                  tr('products.transaction.type'),
                  tr('common.date'),
                  tr('products.table.purchase_price'),
                  tr('products.form.sales_price_item'),
                  tr('common.vat_short'),
                  tr('common.vat_rate'),
                  tr('common.vat_amount'),
                ],
                data: rows,
                dateInterval: dateInfo,
                initialShowDetails: true,
                headerInfo: headerInfo,
                mainTableLabel: tr('products.card.title'),
                headerToggles: headerToggles,
              ),
            ),
          );
        }
        return;
      }

      // Convert transactions to ExpandableRowData
      List<ExpandableRowData> rows = [];
      int index = 1;

      for (var transaction in dataToProcess) {
        final int? txId = transaction['id'] is int
            ? transaction['id'] as int
            : int.tryParse(transaction['id']?.toString() ?? '');

        final mainRow = [
          index.toString(), // Sıra No
          (() {
            final raw =
                (transaction['customTypeLabel'] ??
                        transaction['islem_turu'] ??
                        '')
                    .toString();
            return _formatStockTransactionTypeLabel(raw);
          })(), // İşlem
          (transaction['relatedPartyName'] ?? '-').toString(), // İlgili Hesap
          (transaction['tarih'] ?? '-').toString(), // Tarih
          (transaction['depo_adi'] ?? '-').toString(), // Depo
          FormatYardimcisi.sayiFormatla(
            transaction['miktar'] is num
                ? (transaction['miktar'] as num).toDouble()
                : double.tryParse(transaction['miktar'].toString()) ?? 0.0,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: _genelAyarlar.miktarOndalik,
          ), // Miktar
          (transaction['birim'] ?? _currentUrun.birim).toString(), // Birim
          '${FormatYardimcisi.sayiFormatlaOndalikli(transaction['birim_fiyat'] is num ? (transaction['birim_fiyat'] as num).toDouble() : 0.0, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_genelAyarlar.varsayilanParaBirimi}', // Birim Fiyat
          '${FormatYardimcisi.sayiFormatlaOndalikli(transaction['unitPriceVat'] is num ? (transaction['unitPriceVat'] as num).toDouble() : 0.0, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_genelAyarlar.varsayilanParaBirimi}', // Birim Fiyat (VD)
          '${FormatYardimcisi.sayiFormatlaOndalikli(transaction['tutar'] is num ? (transaction['tutar'] as num).toDouble() : 0.0, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_genelAyarlar.varsayilanParaBirimi}', // Toplam Fiyat
          (transaction['aciklama'] ?? '').toString(), // Açıklama
          (transaction['kullanici'] ?? '-').toString(), // Kullanıcı
        ];

        // Cihaz detaylarını (datatable gibi) alt tablo olarak hazırla
        DetailTable? deviceTable;
        final rawDevices = transaction['devices'];
        if (rawDevices is List && rawDevices.isNotEmpty) {
          final devices = rawDevices
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .map(_normalizeDeviceMap)
              .toList();

          final List<String> deviceHeaders = [];
          if (_columnVisibility['dev_identity'] == true) {
            deviceHeaders.add(tr('products.devices.identity'));
          }
          if (_columnVisibility['dev_status'] == true) {
            deviceHeaders.add(tr('products.table.status'));
          }
          if (_columnVisibility['dev_color'] == true) {
            deviceHeaders.add(tr('products.field.color'));
          }
          if (_columnVisibility['dev_capacity'] == true) {
            deviceHeaders.add(tr('products.field.capacity'));
          }
          if (_columnVisibility['dev_warranty'] == true) {
            deviceHeaders.add(tr('report.warranty'));
          }
          if (_columnVisibility['dev_box'] == true) {
            deviceHeaders.add(tr('common.gadget.box'));
          }
          if (_columnVisibility['dev_invoice'] == true) {
            deviceHeaders.add(tr('common.gadget.invoice'));
          }
          if (_columnVisibility['dev_charger'] == true) {
            deviceHeaders.add(tr('common.gadget.charger'));
          }

          if (deviceHeaders.isNotEmpty) {
            final List<List<String>> deviceRows = devices.map((device) {
              final identity =
                  (device['identityValue']?.toString().trim().isNotEmpty ??
                      false)
                  ? device['identityValue'].toString()
                  : '-';
              final condition =
                  (device['condition']?.toString().trim().isNotEmpty ?? false)
                  ? device['condition'].toString()
                  : '-';
              final color =
                  (device['color']?.toString().trim().isNotEmpty ?? false)
                  ? device['color'].toString()
                  : '-';
              final capacity =
                  (device['capacity']?.toString().trim().isNotEmpty ?? false)
                  ? device['capacity'].toString()
                  : '-';

              final warranty = _formatDateOrDash(device['warrantyEndDate']);

              final hasBox = _toBool(device['hasBox']);
              final hasInvoice = _toBool(device['hasInvoice']);
              final hasCharger = _toBool(device['hasOriginalCharger']);

              final List<String> row = [];
              if (_columnVisibility['dev_identity'] == true) row.add(identity);
              if (_columnVisibility['dev_status'] == true) row.add(condition);
              if (_columnVisibility['dev_color'] == true) row.add(color);
              if (_columnVisibility['dev_capacity'] == true) row.add(capacity);
              if (_columnVisibility['dev_warranty'] == true) row.add(warranty);
              if (_columnVisibility['dev_box'] == true) {
                row.add(hasBox ? tr('common.yes') : '-');
              }
              if (_columnVisibility['dev_invoice'] == true) {
                row.add(hasInvoice ? tr('common.yes') : '-');
              }
              if (_columnVisibility['dev_charger'] == true) {
                row.add(hasCharger ? tr('common.yes') : '-');
              }
              return row;
            }).toList();

            deviceTable = DetailTable(
              title: tr('products.card.section.device_details'),
              headers: deviceHeaders,
              data: deviceRows,
            );
          }
        }

        final bool isExpanded =
            _effectiveKeepDetailsOpen ||
            (txId != null && _expandedTransactionIds.contains(txId));

        rows.add(
          ExpandableRowData(
            mainRow: mainRow,
            transactions: deviceTable,
            isExpanded: isExpanded,
          ),
        );
        index++;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GenisletilebilirPrintPreviewScreen(
              title: tr('products.card.title'),
              headers: [
                tr('common.order_no'), // Sıra No
                tr('products.transaction.type'), // İşlem
                tr('common.account_name'), // İlgili Hesap
                tr('common.date'), // Tarih
                tr('common.warehouse'), // Depo
                tr('common.quantity'), // Miktar
                tr('common.unit'), // Birim
                tr('products.transaction.unit_price'), // Birim Fiyat
                tr('products.transaction.unit_price_vd'), // Birim Fiyat (VD)
                tr('products.transaction.total_price'), // Toplam Fiyat
                tr('common.description'), // Açıklama
                tr('common.user'), // Kullanıcı
              ],
              data: rows,
              dateInterval: dateInfo,
              initialShowDetails: true,
              headerInfo: headerInfo,
              mainTableLabel: tr('products.detail.transactions'),
              headerToggles: headerToggles,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Print error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'print.error.during_print',
                args: {'error': e.toString()},
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
    // Sort implementation:
    _cachedTransactions.sort((a, b) {
      dynamic aValue;
      dynamic bValue;

      switch (columnIndex) {
        case 0:
          aValue = a['islem_turu'];
          bValue = b['islem_turu'];
          break;
        case 1:
          aValue = a['tarih'];
          bValue = b['tarih'];
          break;
        case 2:
          aValue = (a['miktar'] ?? 0);
          bValue = (b['miktar'] ?? 0);
          break;
        case 4:
          aValue = (a['birim_fiyat'] ?? 0);
          bValue = (b['birim_fiyat'] ?? 0);
          break; // Fiyat
        case 5:
          aValue = (a['tutar'] ?? 0);
          bValue = (b['tutar'] ?? 0);
          break; // Tutar
        default:
          return 0;
      }

      if (aValue is String && bValue is String) {
        return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      } else if (aValue is num && bValue is num) {
        return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      }
      return 0;
    });
  }

  void _clearAllTableSelections() {
    setState(() {
      _isSelectAllActive = false;
      _selectedTransactionIds.clear();
      _selectedRowId = null;
    });
  }

  bool get _hasActiveFilters =>
      _searchQuery.trim().isNotEmpty ||
      _selectedTransactionType != null ||
      _selectedWarehouse != null ||
      _selectedUnit != null ||
      _selectedUser != null ||
      _startDate != null ||
      _endDate != null;

  bool get _hasActiveNonSearchFilters =>
      _selectedTransactionType != null ||
      _selectedWarehouse != null ||
      _selectedUnit != null ||
      _selectedUser != null ||
      _startDate != null ||
      _endDate != null;

  bool get _effectiveKeepDetailsOpen =>
      _keepDetailsOpen || _autoKeepDetailsOpen;

  void _toggleKeepDetailsOpen() async {
    // Filtre aktifken "Detaylar Açık Tut" sadece o anki görünüm için toggle edilir,
    // kullanıcı tercihi (prefs) bozulmaz.
    if (_hasActiveFilters) {
      setState(() {
        _autoKeepDetailsOpen = !_autoKeepDetailsOpen;
        _isManuallyClosedDuringFilter = !_autoKeepDetailsOpen;
      });
      return;
    }

    final newValue = !_keepDetailsOpen;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('urun_karti_keep_details_open', newValue);
    setState(() {
      _keepDetailsOpen = newValue;
    });
  }

  // -- Helper Widgets Replicated from CariKartiSayfasi --

  Widget _buildFilters() {
    final filtersRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildDateRangeFilter(width: double.infinity)),
        const SizedBox(width: 24),
        Expanded(child: _buildWarehouseFilter(width: double.infinity)),
        const SizedBox(width: 24),
        Expanded(child: _buildUnitFilter(width: double.infinity)),
        const SizedBox(width: 24),
        Expanded(child: _buildTransactionFilter(width: double.infinity)),
        const SizedBox(width: 24),
        Expanded(child: _buildUserFilter(width: double.infinity)),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: !_isSerialListMode
          ? filtersRow
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                filtersRow,
                if (_isSerialListLoading) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF2C3E50),
                  ),
                ] else if (_cachedSerialRows.isEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    tr('common.no_records_found'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildTransactionFilter({double? width}) {
    final content = CompositedTransformTarget(
      link: _transactionLayerLink,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: _isSerialListMode
            ? null
            : () {
                if (_isTransactionFilterExpanded) {
                  _closeOverlay();
                } else {
                  _showTransactionOverlay();
                }
              },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 160,
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            _isTransactionFilterExpanded ? 7 : 8,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isTransactionFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade300,
                width: _isTransactionFilterExpanded ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 20,
                color: _isTransactionFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedTransactionType == null
                      ? tr('common.transaction_type')
                      : (() {
                          final label = _formatStockTransactionTypeLabel(
                            _selectedTransactionType!,
                          );
                          if (_filterStats.isEmpty) return label;
                          final count =
                              _filterStats['islem_turleri']?[_selectedTransactionType!] ??
                              0;
                          return '$label ($count)';
                        })(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isTransactionFilterExpanded
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedTransactionType != null)
                InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: _isSerialListMode
                      ? null
                      : () {
                          setState(() {
                            _selectedTransactionType = null;
                            if (!_hasActiveFilters) {
                              _autoKeepDetailsOpen = false;
                            }
                          });
                          _refreshCurrentView();
                        },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isTransactionFilterExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: _isTransactionFilterExpanded
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return _isSerialListMode ? Opacity(opacity: 0.45, child: content) : content;
  }

  String _formatStockTransactionTypeLabel(String raw) {
    return IslemCeviriYardimcisi.cevir(
      IslemTuruRenkleri.getProfessionalLabel(raw, context: 'stock'),
    );
  }

  Widget _buildWarehouseFilter({double? width}) {
    final content = CompositedTransformTarget(
      link: _warehouseLayerLink,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: _isSerialListMode
            ? null
            : () {
                if (_isWarehouseFilterExpanded) {
                  _closeOverlay();
                } else {
                  _showWarehouseOverlay();
                }
              },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 160,
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            _isWarehouseFilterExpanded ? 7 : 8,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isWarehouseFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade300,
                width: _isWarehouseFilterExpanded ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warehouse_outlined,
                size: 20,
                color: _isWarehouseFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedWarehouse == null
                      ? tr('common.warehouse')
                      : (() {
                          final label = _selectedWarehouse!.ad;
                          if (_filterStats.isEmpty) return label;
                          final count =
                              _filterStats['depolar']?['${_selectedWarehouse!.id}'] ??
                              0;
                          return '$label ($count)';
                        })(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isWarehouseFilterExpanded
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedWarehouse != null)
                InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: _isSerialListMode
                      ? null
                      : () {
                          setState(() {
                            _selectedWarehouse = null;
                            if (!_hasActiveFilters) {
                              _autoKeepDetailsOpen = false;
                            }
                          });
                          _refreshCurrentView();
                        },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isWarehouseFilterExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: _isWarehouseFilterExpanded
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return _isSerialListMode ? Opacity(opacity: 0.45, child: content) : content;
  }

  Widget _buildUnitFilter({double? width}) {
    final content = CompositedTransformTarget(
      link: _unitLayerLink,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: _isSerialListMode
            ? null
            : () {
                if (_isUnitFilterExpanded) {
                  _closeOverlay();
                } else {
                  _showUnitOverlay();
                }
              },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 160,
          padding: EdgeInsets.fromLTRB(0, 8, 0, _isUnitFilterExpanded ? 7 : 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isUnitFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade300,
                width: _isUnitFilterExpanded ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.straighten_outlined,
                size: 20,
                color: _isUnitFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedUnit == null
                      ? tr('products.table.unit')
                      : '$_selectedUnit (${_filterStats['birimler']?[_selectedUnit] ?? 0})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isUnitFilterExpanded
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedUnit != null)
                InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: _isSerialListMode
                      ? null
                      : () {
                          setState(() {
                            _selectedUnit = null;
                            if (!_hasActiveFilters) {
                              _autoKeepDetailsOpen = false;
                            }
                          });
                          _refreshCurrentView();
                        },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isUnitFilterExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: _isUnitFilterExpanded
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return _isSerialListMode ? Opacity(opacity: 0.45, child: content) : content;
  }

  Widget _buildUserFilter({double? width}) {
    final content = CompositedTransformTarget(
      link: _userLayerLink,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: _isSerialListMode
            ? null
            : () {
                if (_isUserFilterExpanded) {
                  _closeOverlay();
                } else {
                  _showUserOverlay();
                }
              },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 160,
          padding: EdgeInsets.fromLTRB(0, 8, 0, _isUserFilterExpanded ? 7 : 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isUserFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade300,
                width: _isUserFilterExpanded ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_outline,
                size: 20,
                color: _isUserFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedUser == null
                      ? tr('warehouses.detail.user')
                      : (() {
                          final label = _selectedUser!;
                          if (_filterStats.isEmpty) return label;
                          final count =
                              _filterStats['kullanicilar']?[_selectedUser!] ??
                              0;
                          return '$label ($count)';
                        })(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isUserFilterExpanded
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedUser != null)
                InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: _isSerialListMode
                      ? null
                      : () {
                          setState(() {
                            _selectedUser = null;
                            if (!_hasActiveFilters) {
                              _autoKeepDetailsOpen = false;
                            }
                          });
                          _refreshCurrentView();
                        },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isUserFilterExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: _isUserFilterExpanded
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return _isSerialListMode ? Opacity(opacity: 0.45, child: content) : content;
  }

  void _showTransactionOverlay() {
    _closeOverlay();
    setState(() => _isTransactionFilterExpanded = true);

    // Filter items based on availability
    final items = _availableTransactionTypes;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          ModalBarrier(onDismiss: _closeOverlay),
          Positioned(
            width: 220,
            child: CompositedTransformFollower(
              link: _transactionLayerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 42),
              child: Material(
                elevation: 4,
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    children: [
                      InkWell(
                        mouseCursor: WidgetStateMouseCursor.clickable,
                        onTap: () {
                          setState(() {
                            _selectedTransactionType = null;
                            _isTransactionFilterExpanded = false;
                            if (!_hasActiveFilters) {
                              _autoKeepDetailsOpen = false;
                            }
                            _loadTransactions();
                          });
                          _closeOverlay();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          color: _selectedTransactionType == null
                              ? const Color(0xFFE0E7EF)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${tr('settings.general.option.documents.all')} (${_filterStats['ozet']?['toplam'] ?? _totalRecords})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _selectedTransactionType == null
                                        ? const Color(0xFF2C3E50)
                                        : Colors.grey.shade800,
                                    fontWeight: _selectedTransactionType == null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (_selectedTransactionType == null)
                                const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Color(0xFF2C3E50),
                                ),
                            ],
                          ),
                        ),
                      ),
                      ...items.map((type) {
                        final isSelected = _selectedTransactionType == type;
                        final int count =
                            _filterStats['islem_turleri']?[type] ?? 0;

                        if (count == 0 && !isSelected) {
                          return const SizedBox.shrink();
                        }

                        return InkWell(
                          mouseCursor: WidgetStateMouseCursor.clickable,
                          onTap: () {
                            setState(() {
                              _selectedTransactionType = type;
                              _autoKeepDetailsOpen = true;
                              _isTransactionFilterExpanded = false;
                              _loadTransactions();
                            });
                            _closeOverlay();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            color: isSelected
                                ? const Color(0xFFE0E7EF)
                                : Colors.transparent,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_formatStockTransactionTypeLabel(type)} ($count)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isSelected
                                          ? const Color(0xFF2C3E50)
                                          : Colors.grey.shade800,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Color(0xFF2C3E50),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _showWarehouseOverlay() {
    _closeOverlay();
    setState(() => _isWarehouseFilterExpanded = true);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          ModalBarrier(onDismiss: _closeOverlay),
          Positioned(
            width: 220,
            child: CompositedTransformFollower(
              link: _warehouseLayerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 42),
              child: Material(
                elevation: 4,
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    children: [
                      InkWell(
                        mouseCursor: WidgetStateMouseCursor.clickable,
                        onTap: () {
                          setState(() {
                            _selectedWarehouse = null;
                            _isWarehouseFilterExpanded = false;
                            if (!_hasActiveFilters) {
                              _autoKeepDetailsOpen = false;
                            }
                            _loadTransactions();
                          });
                          _closeOverlay();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          color: _selectedWarehouse == null
                              ? const Color(0xFFE0E7EF)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${tr('settings.general.option.documents.all')} (${_filterStats['ozet']?['toplam'] ?? _totalRecords})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _selectedWarehouse == null
                                        ? const Color(0xFF2C3E50)
                                        : Colors.grey.shade800,
                                    fontWeight: _selectedWarehouse == null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (_selectedWarehouse == null)
                                const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Color(0xFF2C3E50),
                                ),
                            ],
                          ),
                        ),
                      ),
                      ..._warehouses.map((warehouse) {
                        final isSelected =
                            _selectedWarehouse?.id == warehouse.id;
                        final int count =
                            _filterStats['depolar']?['${warehouse.id}'] ?? 0;

                        if (count == 0 && !isSelected) {
                          return const SizedBox.shrink();
                        }
                        return InkWell(
                          mouseCursor: WidgetStateMouseCursor.clickable,
                          onTap: () {
                            setState(() {
                              _selectedWarehouse = warehouse;
                              _autoKeepDetailsOpen = true;
                              _isWarehouseFilterExpanded = false;
                              _loadTransactions();
                            });
                            _closeOverlay();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            color: isSelected
                                ? const Color(0xFFE0E7EF)
                                : Colors.transparent,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${warehouse.ad} ($count)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isSelected
                                          ? const Color(0xFF2C3E50)
                                          : Colors.grey.shade800,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Color(0xFF2C3E50),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _showUnitOverlay() {
    _closeOverlay();
    setState(() => _isUnitFilterExpanded = true);

    final items = _availableUnits;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          ModalBarrier(onDismiss: _closeOverlay),
          Positioned(
            width: 200,
            child: CompositedTransformFollower(
              link: _unitLayerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 42),
              child: Material(
                elevation: 4,
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    children: [
                      InkWell(
                        mouseCursor: WidgetStateMouseCursor.clickable,
                        onTap: () {
                          setState(() {
                            _selectedUnit = null;
                            _isUnitFilterExpanded = false;
                            if (!_hasActiveFilters) {
                              _autoKeepDetailsOpen = false;
                            }
                            _loadTransactions();
                          });
                          _closeOverlay();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          color: _selectedUnit == null
                              ? const Color(0xFFE0E7EF)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${tr('settings.general.option.documents.all')} (${_filterStats['ozet']?['toplam'] ?? _totalRecords})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _selectedUnit == null
                                        ? const Color(0xFF2C3E50)
                                        : Colors.grey.shade800,
                                    fontWeight: _selectedUnit == null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (_selectedUnit == null)
                                const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Color(0xFF2C3E50),
                                ),
                            ],
                          ),
                        ),
                      ),
                      ...items.map((unit) {
                        final isSelected = _selectedUnit == unit;
                        final int count = _filterStats['birimler']?[unit] ?? 0;

                        if (count == 0 && !isSelected) {
                          return const SizedBox.shrink();
                        }

                        return InkWell(
                          mouseCursor: WidgetStateMouseCursor.clickable,
                          onTap: () {
                            setState(() {
                              _selectedUnit = unit;
                              _autoKeepDetailsOpen = true;
                              _isUnitFilterExpanded = false;
                              _loadTransactions();
                            });
                            _closeOverlay();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            color: isSelected
                                ? const Color(0xFFE0E7EF)
                                : Colors.transparent,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$unit ($count)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isSelected
                                          ? const Color(0xFF2C3E50)
                                          : Colors.grey.shade800,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Color(0xFF2C3E50),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _showUserOverlay() {
    _closeOverlay();
    setState(() => _isUserFilterExpanded = true);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          ModalBarrier(onDismiss: _closeOverlay),
          Positioned(
            width: 200,
            child: CompositedTransformFollower(
              link: _userLayerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 42),
              child: Material(
                elevation: 4,
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    children: [
                      InkWell(
                        mouseCursor: WidgetStateMouseCursor.clickable,
                        onTap: () {
                          setState(() {
                            _selectedUser = null;
                            _isUserFilterExpanded = false;
                            if (!_hasActiveFilters) {
                              _autoKeepDetailsOpen = false;
                            }
                            _loadTransactions();
                          });
                          _closeOverlay();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          color: _selectedUser == null
                              ? const Color(0xFFE0E7EF)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${tr('settings.general.option.documents.all')} (${_filterStats['ozet']?['toplam'] ?? _totalRecords})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _selectedUser == null
                                        ? const Color(0xFF2C3E50)
                                        : Colors.grey.shade800,
                                    fontWeight: _selectedUser == null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (_selectedUser == null)
                                const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Color(0xFF2C3E50),
                                ),
                            ],
                          ),
                        ),
                      ),
                      ..._availableUsers.map((user) {
                        final isSelected = _selectedUser == user;
                        final int count =
                            _filterStats['kullanicilar']?[user] ?? 0;

                        if (count == 0 && !isSelected) {
                          return const SizedBox.shrink();
                        }
                        return InkWell(
                          mouseCursor: WidgetStateMouseCursor.clickable,
                          onTap: () {
                            setState(() {
                              _selectedUser = user;
                              _autoKeepDetailsOpen = true;
                              _isUserFilterExpanded = false;
                              _loadTransactions();
                            });
                            _closeOverlay();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            color: isSelected
                                ? const Color(0xFFE0E7EF)
                                : Colors.transparent,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$user ($count)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isSelected
                                          ? const Color(0xFF2C3E50)
                                          : Colors.grey.shade800,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Color(0xFF2C3E50),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildDetailColumn({
    required IconData icon,
    required String title,
    required List<(String, String)> items,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF2C3E50)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      item.$1,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  if (item.$2.isNotEmpty && item.$2 != '-')
                    InkWell(
                      mouseCursor: WidgetStateMouseCursor.clickable,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: item.$2));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${item.$1} ${tr('common.copied')}'),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    _closeOverlay();

    final result = await showDialog<List<DateTime?>>(
      context: context,
      builder: (context) => TarihAraligiSeciciDialog(
        initialStartDate: _startDate,
        initialEndDate: _endDate,
      ),
    );

    if (result != null) {
      setState(() {
        _startDate = result[0];
        _endDate = result[1];
        if (_startDate != null) {
          _startDateController.text = DateFormat(
            'dd.MM.yyyy',
          ).format(_startDate!);
        } else {
          _startDateController.clear();
        }
        if (_endDate != null) {
          _endDateController.text = DateFormat('dd.MM.yyyy').format(_endDate!);
        } else {
          _endDateController.clear();
        }

        if (_startDate != null || _endDate != null) {
          _autoKeepDetailsOpen = true;
        } else if (!_hasActiveFilters) {
          _autoKeepDetailsOpen = false;
        }
      });
      _refreshCurrentView();
    }
  }

  Widget _buildDateRangeFilter({double? width}) {
    final hasSelection = _startDate != null || _endDate != null;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: _showDateRangePicker,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: width ?? 240,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: hasSelection
                  ? const Color(0xFF2C3E50) // Patisyo Dark Blue
                  : Colors.grey.shade300,
              width: hasSelection ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 20,
              color: hasSelection
                  ? const Color(0xFF2C3E50)
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasSelection
                    ? '${_startDateController.text} - ${_endDateController.text}'
                    : tr('common.date_range_select'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: hasSelection ? FontWeight.w600 : FontWeight.w500,
                  color: hasSelection
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasSelection)
              InkWell(
                mouseCursor: WidgetStateMouseCursor.clickable,
                onTap: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                    _startDateController.clear();
                    _endDateController.clear();
                    if (!_hasActiveFilters) _autoKeepDetailsOpen = false;
                  });
                  _refreshCurrentView();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // Column Width Calculation
  double _calculateHeaderWidth(
    String text, {
    bool sortable = false,
    double minWidth = 60.0,
  }) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black54,
          fontSize: 15,
        ),
      ),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout();

    double width = textPainter.width + 32;
    if (sortable) {
      width += 22;
    }
    if (width < minWidth) return minWidth;
    return width;
  }

  int _flexFromWidth(double width, {int minFlex = 1}) {
    final flex = (width / 35).ceil();
    return flex < minFlex ? minFlex : flex;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Focus(
        autofocus: false,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (_overlayEntry != null) {
                _closeOverlay();
                return;
              }
              if (_searchController.text.isNotEmpty) {
                _searchController.clear();
                return;
              }
            },
            const SingleActivator(LogicalKeyboardKey.f3): () {
              _searchFocusNode.requestFocus();
            },
            const SingleActivator(LogicalKeyboardKey.f5): () {
              _refreshCurrentView();
            },
          },
          child: Column(
            children: [
              _buildUrunInfoCard(theme),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildDesktopView(constraints);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockBox(UrunModel urun) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('products.table.stock'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${FormatYardimcisi.sayiFormatlaOran(urun.stok, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.miktarOndalik)} ${urun.birim}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: urun.stok >= 0
                  ? const Color(0xFF059669)
                  : const Color(0xFFC62828),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrunInfoCard(ThemeData theme) {
    final urun = _currentUrun;

    Widget buildMainImage() {
      ImageProvider? img;
      if (urun.resimler.isNotEmpty) {
        img = _getCachedMemoryImage(urun.resimler.first);
      } else if (urun.resimUrl != null && urun.resimUrl!.isNotEmpty) {
        // Placeholder for URL
      }

      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          image: img != null
              ? DecorationImage(image: img, fit: BoxFit.contain)
              : null,
        ),
        child: img == null
            ? Center(
                child: Text(
                  urun.ad.isNotEmpty ? urun.ad[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              )
            : null,
      );
    }

    Widget buildThumbnails() {
      if (urun.resimler.length <= 1) return const SizedBox.shrink();
      return Row(
        children: urun.resimler.skip(1).take(4).map((imgStr) {
          final thumbImg = _getCachedMemoryImage(imgStr);
          if (thumbImg == null) return const SizedBox.shrink();
          return Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              image: DecorationImage(image: thumbImg, fit: BoxFit.contain),
            ),
          );
        }).toList(),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============ TOGGLE HEADER ============
          InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: () =>
                setState(() => _isInfoCardExpanded = !_isInfoCardExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: _isInfoCardExpanded ? 8 : 12,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: _isInfoCardExpanded
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      )
                    : BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // LEFT SIDE CONTENT (Conditional)
                  if (!_isInfoCardExpanded) ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        image: urun.resimler.isNotEmpty
                            ? DecorationImage(
                                image:
                                    _getCachedMemoryImage(
                                      urun.resimler.first,
                                    ) ??
                                    const AssetImage('assets/placeholder.png')
                                        as ImageProvider,
                                fit: BoxFit.contain,
                              )
                            : null,
                      ),
                      child: urun.resimler.isEmpty
                          ? Center(
                              child: Text(
                                urun.ad.isNotEmpty
                                    ? urun.ad[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            urun.ad,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2C3E50,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  urun.kod,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                urun.grubu,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildStockBox(urun),
                    const SizedBox(width: 12),
                  ] else ...[
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr('products.card.details_title'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],

                  // RIGHT SIDE COLUMN (Toggle Button Only)
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Toggle Button (Text + Arrow)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isInfoCardExpanded
                                ? tr('products.card.close')
                                : tr('products.card.open'),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _isInfoCardExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildMainImage(),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      urun.ad,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF2C3E50,
                                            ).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            urun.kod,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2C3E50),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            urun.grubu,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    buildThumbnails(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              _buildStockBox(urun),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    color: const Color(0xFFE2E8F0),
                  ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDetailColumn(
                          icon: Icons.percent_rounded,
                          title: tr('products.card.section.stock_tax_details'),
                          items: [
                            (
                              tr('common.vat_rate'),
                              '%${FormatYardimcisi.sayiFormatlaOran(urun.kdvOrani)}',
                            ),
                            (tr('common.unit'), urun.birim),
                            (
                              tr('common.barcode'),
                              urun.barkod.isNotEmpty ? urun.barkod : '-',
                            ),
                            (
                              tr('products.table.alert_qty'), // Kritik Stok
                              FormatYardimcisi.sayiFormatlaOran(
                                urun.erkenUyariMiktari,
                                binlik: _genelAyarlar.binlikAyiraci,
                                ondalik: _genelAyarlar.ondalikAyiraci,
                                decimalDigits: _genelAyarlar.miktarOndalik,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 100,
                        color: const Color(0xFFE2E8F0),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      // FIYAT BILGILERI SUTUNU
                      Expanded(
                        child: _buildDetailColumn(
                          icon: Icons.payments_outlined,
                          title: tr('products.card.section.pricing'),
                          items: [
                            (
                              tr('products.table.purchase_price'),
                              '${FormatYardimcisi.sayiFormatlaOran(urun.alisFiyati, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_genelAyarlar.varsayilanParaBirimi}',
                            ),
                            (
                              tr('products.table.sales_price_1'),
                              '${FormatYardimcisi.sayiFormatlaOran(urun.satisFiyati1, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_genelAyarlar.varsayilanParaBirimi}',
                            ),
                            (
                              tr('products.table.sales_price_2'),
                              '${FormatYardimcisi.sayiFormatlaOran(urun.satisFiyati2, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_genelAyarlar.varsayilanParaBirimi}',
                            ),
                            (
                              tr('products.table.sales_price_3'),
                              '${FormatYardimcisi.sayiFormatlaOran(urun.satisFiyati3, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_genelAyarlar.varsayilanParaBirimi}',
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 100,
                        color: const Color(0xFFE2E8F0),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: Color(0xFF2C3E50),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    tr('accounts.detail.other_title'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildSimpleDetailItem(tr('common.code'), urun.kod),
                              const SizedBox(height: 6),
                              _buildSimpleDetailItem(
                                tr('products.table.group'),
                                urun.grubu,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 100,
                        color: const Color(0xFFE2E8F0),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.list_alt_rounded,
                                    size: 16,
                                    color: Color(0xFF2C3E50),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    tr('products.table.features'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildFeaturesContent(urun.ozellikler),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _isInfoCardExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  void _showColumnVisibilityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Map<String, bool> localVisibility = Map.from(_columnVisibility);

        bool isAllMainSelected() {
          return localVisibility.entries
              .where((e) => !e.key.startsWith('dev_'))
              .every((e) => e.value);
        }

        bool isAllDetailSelected() {
          return localVisibility.entries
              .where((e) => e.key.startsWith('dev_'))
              .every((e) => e.value);
        }

        void toggleAllMain(bool? value) {
          for (var key in localVisibility.keys) {
            if (!key.startsWith('dev_')) {
              localVisibility[key] = value ?? false;
            }
          }
        }

        void toggleAllDetail(bool? value) {
          for (var key in localVisibility.keys) {
            if (key.startsWith('dev_')) {
              localVisibility[key] = value ?? false;
            }
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.view_column_outlined,
                    color: Color(0xFF2C3E50),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('common.column_settings'),
                    style: const TextStyle(
                      color: Color(0xFF2C3E50),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- MAIN TABLE ---
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tr('common.main_table'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                                fontSize: 14,
                              ),
                            ),
                            Transform.scale(
                              scale: 0.9,
                              child: Row(
                                children: [
                                  Text(
                                    tr('common.select_all'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Checkbox(
                                    value: isAllMainSelected(),
                                    activeColor: const Color(0xFF2C3E50),
                                    onChanged: (val) {
                                      setDialogState(() {
                                        toggleAllMain(val);
                                      });
                                    },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'islem',
                            tr('common.transaction_type'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'tarih',
                            tr('common.date'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'miktar',
                            tr('common.quantity'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'birim',
                            tr('common.unit'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'fiyat',
                            tr('products.transaction.unit_price'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'tutar',
                            tr('products.transaction.total_price'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'depo',
                            tr('common.warehouse'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'aciklama',
                            tr('common.description'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'kullanici',
                            tr('common.user'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // --- DEVICES TABLE ---
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tr('common.gadget.devices'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                                fontSize: 14,
                              ),
                            ),
                            Transform.scale(
                              scale: 0.9,
                              child: Row(
                                children: [
                                  Text(
                                    tr('common.select_all'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Checkbox(
                                    value: isAllDetailSelected(),
                                    activeColor: const Color(0xFF2C3E50),
                                    onChanged: (val) {
                                      setDialogState(() {
                                        toggleAllDetail(val);
                                      });
                                    },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dev_identity',
                            tr('products.devices.identity'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dev_status',
                            tr('products.table.status'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dev_color',
                            tr('products.field.color'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dev_capacity',
                            tr('products.field.capacity'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dev_warranty',
                            tr('report.warranty'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dev_box',
                            tr('common.gadget.box'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dev_invoice',
                            tr('common.gadget.invoice'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dev_charger',
                            tr('common.gadget.charger'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    tr('common.cancel'),
                    style: const TextStyle(color: Color(0xFF2C3E50)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _columnVisibility = localVisibility;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA4335),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    tr('common.save'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSerialListColumnVisibilityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Map<String, bool> localVisibility = Map.from(
          _serialListColumnVisibility,
        );

        bool isAllSelected() {
          return localVisibility.values.every((v) => v == true);
        }

        void toggleAll(bool? value) {
          for (final key in localVisibility.keys) {
            localVisibility[key] = value ?? false;
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.view_column_outlined,
                    color: Color(0xFF2C3E50),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('common.column_settings'),
                    style: const TextStyle(
                      color: Color(0xFF2C3E50),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tr('common.main_table'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                                fontSize: 14,
                              ),
                            ),
                            Transform.scale(
                              scale: 0.9,
                              child: Row(
                                children: [
                                  Text(
                                    tr('common.select_all'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Checkbox(
                                    value: isAllSelected(),
                                    activeColor: const Color(0xFF2C3E50),
                                    onChanged: (val) {
                                      setDialogState(() {
                                        toggleAll(val);
                                      });
                                    },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'barkod',
                            tr('common.barcode'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'imei_seri',
                            tr('products.devices.identity'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'islem',
                            tr('products.transaction.type'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'tarih',
                            tr('common.date'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'alis_fiyati',
                            tr('products.table.purchase_price'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'satis_fiyati',
                            tr('products.form.sales_price_item'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'kdv',
                            tr('common.vat_short'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'kdv_oran',
                            tr('common.vat_rate'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'kdv_tutar',
                            tr('common.vat_amount'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    tr('common.cancel'),
                    style: const TextStyle(color: Color(0xFF2C3E50)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!localVisibility.values.any((v) => v == true)) {
                      localVisibility['imei_seri'] = true;
                    }
                    setState(() {
                      _serialListColumnVisibility
                        ..clear()
                        ..addAll(localVisibility);
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA4335),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    tr('common.save'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildConfigCheckbox(
    StateSetter setDialogState,
    Map<String, bool> localMap,
    String key,
    String label,
  ) {
    return SizedBox(
      width: 170,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () {
          setDialogState(() {
            localMap[key] = !(localMap[key] ?? true);
          });
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: localMap[key] ?? true,
                  activeColor: const Color(0xFF2C3E50),
                  onChanged: (val) {
                    setDialogState(() {
                      localMap[key] = val ?? true;
                    });
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                  side: const BorderSide(color: Color(0xFFD1D1D1), width: 1.5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF455A64),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopView(BoxConstraints constraints) {
    if (_isSerialListMode) {
      return _buildSerialListDesktopView(constraints);
    }

    final colIslemWidth = _calculateHeaderWidth(
      'İşlem Türü',
      sortable: true,
      minWidth: 150.0,
    );
    final colTarihWidth = _calculateHeaderWidth(
      'Tarih',
      sortable: true,
      minWidth: 140.0,
    );
    final colMiktarWidth = _calculateHeaderWidth(
      'Miktar',
      sortable: true,
      minWidth: 100.0,
    );
    final colBirimWidth = _calculateHeaderWidth(
      'Birim',
      sortable: false,
      minWidth: 80.0,
    );
    final colFiyatWidth = _calculateHeaderWidth(
      'Birim Fiyat',
      sortable: true,
      minWidth: 140.0,
    );
    final colTutarWidth = _calculateHeaderWidth(
      'Tutar',
      sortable: true,
      minWidth: 130.0,
    );
    final colDepoWidth = _calculateHeaderWidth(
      'Depo',
      sortable: true,
      minWidth: 100.0,
    );
    final colAciklamaWidth = _calculateHeaderWidth(
      'Açıklama',
      sortable: false,
      minWidth: 150.0,
    );
    final colKullaniciWidth = _calculateHeaderWidth(
      'Kullanıcı',
      sortable: false,
      minWidth: 100.0,
    );

    final colIslemFlex = _flexFromWidth(colIslemWidth, minFlex: 3);
    final colTarihFlex = _flexFromWidth(colTarihWidth, minFlex: 3);
    final colMiktarFlex = _flexFromWidth(
      colMiktarWidth + colBirimWidth,
      minFlex: 3,
    );
    final colBirimFlex = _flexFromWidth(colBirimWidth, minFlex: 1);
    final colFiyatFlex = _flexFromWidth(colFiyatWidth, minFlex: 3);
    final colTutarFlex = _flexFromWidth(colTutarWidth, minFlex: 3);
    final colDepoFlex = _flexFromWidth(colDepoWidth, minFlex: 3);
    final colAciklamaFlex = _flexFromWidth(colAciklamaWidth, minFlex: 4);
    final colKullaniciFlex = _flexFromWidth(colKullaniciWidth, minFlex: 2);

    final displayTransactions = _cachedTransactions;

    return GenisletilebilirTablo<Map<String, dynamic>>(
      key: const ValueKey('urun_karti_transactions_table'),
      title: '',
      totalRecords: _totalRecords,
      searchFocusNode: _searchFocusNode,
      onClearSelection: _clearAllTableSelections,
      onFocusedRowChanged: (item, index) {
        if (item != null) {
          setState(() => _selectedRowId = item['id'] as int?);
        }
      },
      headerTextStyle: const TextStyle(fontSize: 13),
      headerPadding: const EdgeInsets.symmetric(
        horizontal: 4,
      ), // Tight padding for sticking columns
      headerMaxLines: 1,
      headerOverflow: TextOverflow.ellipsis,
      onSort: _onSort,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      onPageChanged: (page, rowsPerPage) => _loadTransactions(),
      onSearch: (query) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          _applySearchQuery(query);
        });
      },
      selectionWidget: null,
      expandAll: _effectiveKeepDetailsOpen,

      extraWidgets: [
        Tooltip(
          message: tr('warehouses.keep_details_open'),
          child: InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: _toggleKeepDetailsOpen,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: _effectiveKeepDetailsOpen
                    ? const Color(0xFF2C3E50).withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _effectiveKeepDetailsOpen
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade300,
                ),
              ),
              child: Icon(
                _effectiveKeepDetailsOpen
                    ? Icons.unfold_less_rounded
                    : Icons.unfold_more_rounded,
                color: _effectiveKeepDetailsOpen
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (_columnVisibility.isNotEmpty)
          Tooltip(
            message: tr('common.column_settings'),
            child: InkWell(
              mouseCursor: WidgetStateMouseCursor.clickable,
              onTap: () => _showColumnVisibilityDialog(context),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Icon(
                  Icons.view_column_outlined,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ),
            ),
          ),
        const SizedBox(width: 8),
        if (_isSerialNumberedProduct)
          Tooltip(
            message: tr('common.show_only_list'),
            child: InkWell(
              mouseCursor: WidgetStateMouseCursor.clickable,
              onTap: _toggleSerialListMode,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Icon(
                  Icons.format_list_bulleted_rounded,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
      actionButton: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
              onTap: _handlePrint,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.print_outlined,
                      size: 18,
                      color: Colors.black87,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedRowId != null
                          ? tr('common.print_selected')
                          : tr('common.print_list'),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr('common.key.f7'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ),
        ],
      ),
      headerWidget: _buildFilters(),
      columns: [
        GenisletilebilirTabloKolon(
          label: '',
          width: 50,
          alignment: Alignment.center,
          header: SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _isSelectAllActive,
              onChanged: _onSelectAll,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
            ),
          ),
        ),
        GenisletilebilirTabloKolon(
          label: tr('common.order_no'),
          width: 130,
          alignment: Alignment.centerLeft,
        ),
        if (_columnVisibility['islem'] == true)
          GenisletilebilirTabloKolon(
            label: tr('products.transaction.type'),
            width: colIslemWidth,
            flex: colIslemFlex,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        GenisletilebilirTabloKolon(
          label: tr('common.related_account'),
          width: 220,
          flex: 5,
          alignment: Alignment.centerLeft,
          allowSorting: false, // For now
        ),
        if (_columnVisibility['tarih'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.date'),
            width: colTarihWidth,
            flex: colTarihFlex,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['depo'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.warehouse'),
            width: colDepoWidth,
            flex: colDepoFlex,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['miktar'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.quantity'),
            width: colMiktarWidth,
            flex: colMiktarFlex,
            alignment: Alignment.centerRight,
            allowSorting: true,
          ),
        if (_columnVisibility['birim'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.unit'),
            width: colBirimWidth,
            flex: colBirimFlex,
            alignment: Alignment.centerLeft,
            allowSorting: false,
          ),
        if (_columnVisibility['fiyat'] == true)
          GenisletilebilirTabloKolon(
            label: tr('products.transaction.unit_price'),
            width: colFiyatWidth,
            flex: colFiyatFlex,
            alignment: Alignment.centerRight,
            allowSorting: true,
          ),
        if (_columnVisibility['fiyat'] == true)
          GenisletilebilirTabloKolon(
            label: tr('products.transaction.unit_price_vd'),
            width: colFiyatWidth,
            flex: colFiyatFlex,
            alignment: Alignment.centerRight,
            allowSorting: false,
          ),
        if (_columnVisibility['tutar'] == true)
          GenisletilebilirTabloKolon(
            label: tr('products.transaction.total_price'),
            width: colTutarWidth,
            flex: colTutarFlex,
            alignment: Alignment.centerRight,
            allowSorting: true,
          ),
        if (_columnVisibility['aciklama'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.description'),
            width: colAciklamaWidth,
            flex: colAciklamaFlex,
            alignment: Alignment.centerLeft,
            allowSorting: false,
          ),
        if (_columnVisibility['kullanici'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.user'),
            width: colKullaniciWidth,
            flex: colKullaniciFlex,
            alignment: Alignment.centerLeft,
            allowSorting: false,
          ),
        GenisletilebilirTabloKolon(
          label: tr('common.actions'),
          width: 110,
          alignment: Alignment.centerLeft,
        ),
      ],
      data: displayTransactions,
      isRowSelected: (tx, index) => _selectedRowId == tx['id'],
      expandOnRowTap: true,
      onRowTap: (tx) => setState(() => _selectedRowId = tx['id'] as int?),
      rowBuilder: (context, tx, index, isExpanded, toggleExpand) {
        return _buildTransactionMainRow(
          tx: tx,
          index: index,
          colIslemWidth: colIslemWidth,
          colIslemFlex: colIslemFlex,
          colTarihWidth: colTarihWidth,
          colTarihFlex: colTarihFlex,
          colMiktarWidth: colMiktarWidth,
          colMiktarFlex: colMiktarFlex,
          colBirimWidth: colBirimWidth,
          colBirimFlex: colBirimFlex,
          colFiyatWidth: colFiyatWidth,
          colFiyatFlex: colFiyatFlex,
          colTutarWidth: colTutarWidth,
          colTutarFlex: colTutarFlex,
          colDepoWidth: colDepoWidth,
          colDepoFlex: colDepoFlex,
          colAciklamaWidth: colAciklamaWidth,
          colAciklamaFlex: colAciklamaFlex,
          colKullaniciWidth: colKullaniciWidth,
          colKullaniciFlex: colKullaniciFlex,
          isExpanded: isExpanded,

          toggleExpand: toggleExpand,
        );
      },
      expandedIndices: _getEffectiveTransactionExpandedIndices(),
      onExpansionChanged: (index, isExpanded) {
        if (_effectiveKeepDetailsOpen) return;

        if (index < 0 || index >= _cachedTransactions.length) return;
        final tx = _cachedTransactions[index];
        final int? id = tx['id'] is int
            ? tx['id'] as int
            : int.tryParse(tx['id']?.toString() ?? '');
        if (id == null) return;

        setState(() {
          if (isExpanded) {
            if (!_keepDetailsOpen) {
              _expandedTransactionIds.clear();
            }
            _expandedTransactionIds.add(id);
          } else {
            _expandedTransactionIds.remove(id);
            _searchAutoExpandedTransactionIds.remove(id);
          }
        });
      },
      getDetailItemCount: (tx) {
        final devices = tx['devices'] as List?;
        return (devices != null && devices.isNotEmpty) ? 1 : 0;
      },
      detailBuilder: (context, tx) {
        final devices = tx['devices'] as List?;
        if (devices == null || devices.isEmpty) return const SizedBox.shrink();
        return _buildDevicesDetailView(devices);
      },
    );
  }

  Widget _buildSerialListDesktopView(BoxConstraints constraints) {
    final colBarkodWidth =
        _calculateHeaderWidth(tr('common.barcode'), minWidth: 140.0);
    final colImeiWidth = _calculateHeaderWidth(
      tr('products.devices.identity'),
      minWidth: 320.0,
    );
    final colIslemWidth =
        _calculateHeaderWidth(tr('products.transaction.type'), minWidth: 110.0);
    final colTarihWidth =
        _calculateHeaderWidth(tr('common.date'), minWidth: 140.0);
    final colAlisFiyatWidth = _calculateHeaderWidth(
      tr('products.table.purchase_price'),
      minWidth: 140.0,
    );
    final colSatisFiyatWidth = _calculateHeaderWidth(
      tr('products.form.sales_price_item'),
      minWidth: 170.0,
    );
    final colKdvWidth =
        _calculateHeaderWidth(tr('common.vat_short'), minWidth: 150.0);
    final colKdvOranWidth =
        _calculateHeaderWidth(tr('common.vat_rate'), minWidth: 90.0);
    final colKdvTutarWidth = _calculateHeaderWidth(
      tr('common.vat_amount'),
      minWidth: 160.0,
    );

    final colBarkodFlex = _flexFromWidth(colBarkodWidth, minFlex: 3);
    final colImeiFlex = _flexFromWidth(colImeiWidth, minFlex: 7);
    final colIslemFlex = _flexFromWidth(colIslemWidth, minFlex: 2);
    final colTarihFlex = _flexFromWidth(colTarihWidth, minFlex: 3);
    final colAlisFiyatFlex = _flexFromWidth(colAlisFiyatWidth, minFlex: 3);
    final colSatisFiyatFlex = _flexFromWidth(colSatisFiyatWidth, minFlex: 3);
    final colKdvFlex = _flexFromWidth(colKdvWidth, minFlex: 2);
    final colKdvOranFlex = _flexFromWidth(colKdvOranWidth, minFlex: 2);
    final colKdvTutarFlex = _flexFromWidth(colKdvTutarWidth, minFlex: 3);

    return GenisletilebilirTablo<Map<String, dynamic>>(
      key: const ValueKey('urun_karti_serial_list_table'),
      title: '',
      totalRecords: _serialTotalRecords,
      searchFocusNode: _searchFocusNode,
      onClearSelection: _clearAllTableSelections,
      onFocusedRowChanged: (item, index) {
        if (item != null) {
          setState(() => _selectedRowId = item['id'] as int?);
        }
      },
      headerTextStyle: const TextStyle(fontSize: 13),
      headerPadding: const EdgeInsets.symmetric(horizontal: 4),
      headerMaxLines: 1,
      headerOverflow: TextOverflow.ellipsis,
      onSort: null,
      sortColumnIndex: null,
      sortAscending: true,
      onPageChanged: (page, rowsPerPage) => _loadSerialListRows(),
      onSearch: (query) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          _applySearchQuery(query);
        });
      },
      selectionWidget: null,
      expandAll: false,
      extraWidgets: [
        Tooltip(
          message: tr('warehouses.keep_details_open'),
          child: InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: null, // Liste modunda genişleyen satır yok
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(
                Icons.unfold_more_rounded,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (_serialListColumnVisibility.isNotEmpty)
          Tooltip(
            message: tr('common.column_settings'),
            child: InkWell(
              mouseCursor: WidgetStateMouseCursor.clickable,
              onTap: () => _showSerialListColumnVisibilityDialog(context),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Icon(
                  Icons.view_column_outlined,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Tooltip(
          message: tr('common.show_only_list'),
          child: InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: _toggleSerialListMode,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF2C3E50)),
              ),
              child: const Icon(
                Icons.format_list_bulleted_rounded,
                color: Color(0xFF2C3E50),
                size: 20,
              ),
            ),
          ),
        ),
      ],
      actionButton: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
              onTap: _handlePrint,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.print_outlined,
                      size: 18,
                      color: Colors.black87,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedRowId != null
                          ? tr('common.print_selected')
                          : tr('common.print_list'),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr('common.key.f7'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ),
        ],
      ),
      headerWidget: _buildFilters(),
      columns: [
        GenisletilebilirTabloKolon(
          label: '',
          width: 50,
          alignment: Alignment.center,
          header: SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _isSelectAllActive,
              onChanged: _onSelectAll,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
            ),
          ),
        ),
        GenisletilebilirTabloKolon(
          label: tr('common.order_no'),
          width: 130,
          alignment: Alignment.centerLeft,
        ),
        if (_serialListColumnVisibility['barkod'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.barcode'),
            width: colBarkodWidth,
            flex: colBarkodFlex,
            alignment: Alignment.centerLeft,
          ),
        if (_serialListColumnVisibility['imei_seri'] == true)
          GenisletilebilirTabloKolon(
            label: tr('products.devices.identity'),
            width: colImeiWidth,
            flex: colImeiFlex,
            alignment: Alignment.centerLeft,
          ),
        if (_serialListColumnVisibility['islem'] == true)
          GenisletilebilirTabloKolon(
            label: tr('products.transaction.type'),
            width: colIslemWidth,
            flex: colIslemFlex,
            alignment: Alignment.centerLeft,
          ),
        if (_serialListColumnVisibility['tarih'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.date'),
            width: colTarihWidth,
            flex: colTarihFlex,
            alignment: Alignment.centerLeft,
          ),
        if (_serialListColumnVisibility['alis_fiyati'] == true)
          GenisletilebilirTabloKolon(
            label: tr('products.table.purchase_price'),
            width: colAlisFiyatWidth,
            flex: colAlisFiyatFlex,
            alignment: Alignment.centerRight,
          ),
        if (_serialListColumnVisibility['satis_fiyati'] == true)
          GenisletilebilirTabloKolon(
            label: tr('products.form.sales_price_item'),
            width: colSatisFiyatWidth,
            flex: colSatisFiyatFlex,
            alignment: Alignment.centerRight,
          ),
        if (_serialListColumnVisibility['kdv'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.vat_short'),
            header: Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                tr('common.vat_short'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),
            ),
            width: colKdvWidth,
            flex: colKdvFlex,
            alignment: Alignment.centerLeft,
          ),
        if (_serialListColumnVisibility['kdv_oran'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.vat_rate'),
            width: colKdvOranWidth,
            flex: colKdvOranFlex,
            alignment: Alignment.centerLeft,
          ),
        if (_serialListColumnVisibility['kdv_tutar'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.vat_amount'),
            width: colKdvTutarWidth,
            flex: colKdvTutarFlex,
            alignment: Alignment.centerRight,
          ),
      ],
      data: _cachedSerialRows,
      isRowSelected: (row, index) => _selectedRowId == row['id'],
      expandOnRowTap: false,
      onRowTap: (row) => setState(() => _selectedRowId = row['id'] as int?),
      rowBuilder: (context, row, index, isExpanded, toggleExpand) {
        return _buildSerialListMainRow(
          row: row,
          index: index,
          colBarkodWidth: colBarkodWidth,
          colBarkodFlex: colBarkodFlex,
          colImeiWidth: colImeiWidth,
          colImeiFlex: colImeiFlex,
          colIslemWidth: colIslemWidth,
          colIslemFlex: colIslemFlex,
          colTarihWidth: colTarihWidth,
          colTarihFlex: colTarihFlex,
          colAlisFiyatWidth: colAlisFiyatWidth,
          colAlisFiyatFlex: colAlisFiyatFlex,
          colSatisFiyatWidth: colSatisFiyatWidth,
          colSatisFiyatFlex: colSatisFiyatFlex,
          colKdvWidth: colKdvWidth,
          colKdvFlex: colKdvFlex,
          colKdvOranWidth: colKdvOranWidth,
          colKdvOranFlex: colKdvOranFlex,
          colKdvTutarWidth: colKdvTutarWidth,
          colKdvTutarFlex: colKdvTutarFlex,
        );
      },
      expandedIndices: const <int>{},
      getDetailItemCount: (row) => 0,
      detailBuilder: (context, row) => const SizedBox.shrink(),
    );
  }

  Widget _buildSerialListMainRow({
    required Map<String, dynamic> row,
    required int index,
    required double colBarkodWidth,
    required int colBarkodFlex,
    required double colImeiWidth,
    required int colImeiFlex,
    required double colIslemWidth,
    required int colIslemFlex,
    required double colTarihWidth,
    required int colTarihFlex,
    required double colAlisFiyatWidth,
    required int colAlisFiyatFlex,
    required double colSatisFiyatWidth,
    required int colSatisFiyatFlex,
    required double colKdvWidth,
    required int colKdvFlex,
    required double colKdvOranWidth,
    required int colKdvOranFlex,
    required double colKdvTutarWidth,
    required int colKdvTutarFlex,
  }) {
    final query = _searchQuery.trim();

    final String barkod = (row['barkod'] ?? '-').toString();
    final String imeiSeri = (row['imei_seri'] ?? '-').toString();
    final String islem = (row['islem'] ?? '-').toString();
    final String tarih = (row['tarih'] ?? '-').toString();
    final String alisFiyat = (row['alis_fiyati_text'] ?? '-').toString();
    final String satisFiyat = (row['satis_fiyati_text'] ?? '-').toString();
    final String kdvText = (row['kdv_text'] ?? '-').toString();
    final String kdvOranText = (row['kdv_oran_text'] ?? '-').toString();
    final String kdvTutarText = (row['kdv_tutar_text'] ?? '-').toString();

    return Row(
      children: [
        Container(
          width: 50,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value:
                  _isSelectAllActive ||
                  _selectedTransactionIds.contains(row['id']),
              onChanged: (val) => _onSelectRow(val, row['id'] as int),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
            ),
          ),
        ),
        Container(
          width: 130,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 4),
          child: HighlightText(
            text: '${index + 1}',
            query: query,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
          ),
        ),
        if (_serialListColumnVisibility['barkod'] == true)
          Expanded(
            flex: colBarkodFlex,
            child: Container(
              width: colBarkodWidth,
              padding: const EdgeInsets.only(left: 4),
              alignment: Alignment.centerLeft,
              child: HighlightText(
                text: barkod,
                query: query,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                maxLines: 1,
              ),
            ),
          ),
        if (_serialListColumnVisibility['imei_seri'] == true)
          Expanded(
            flex: colImeiFlex,
            child: Container(
              width: colImeiWidth,
              padding: const EdgeInsets.only(left: 4),
              alignment: Alignment.centerLeft,
              child: HighlightText(
                text: imeiSeri,
                query: query,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 1,
              ),
            ),
          ),
        if (_serialListColumnVisibility['islem'] == true)
          Expanded(
            flex: colIslemFlex,
            child: Container(
              width: colIslemWidth,
              padding: const EdgeInsets.only(left: 4),
              alignment: Alignment.centerLeft,
              child: HighlightText(
                text: islem,
                query: query,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                maxLines: 1,
              ),
            ),
          ),
        if (_serialListColumnVisibility['tarih'] == true)
          Expanded(
            flex: colTarihFlex,
            child: Container(
              width: colTarihWidth,
              padding: const EdgeInsets.only(left: 4),
              alignment: Alignment.centerLeft,
              child: HighlightText(
                text: tarih,
                query: query,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                maxLines: 1,
              ),
            ),
          ),
        if (_serialListColumnVisibility['alis_fiyati'] == true)
          Expanded(
            flex: colAlisFiyatFlex,
            child: Container(
              width: colAlisFiyatWidth,
              padding: const EdgeInsets.only(right: 4),
              alignment: Alignment.centerRight,
              child: HighlightText(
                text: alisFiyat,
                query: query,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                maxLines: 1,
                textAlign: TextAlign.right,
              ),
            ),
          ),
        if (_serialListColumnVisibility['satis_fiyati'] == true)
          Expanded(
            flex: colSatisFiyatFlex,
            child: Container(
              width: colSatisFiyatWidth,
              padding: const EdgeInsets.only(right: 4),
              alignment: Alignment.centerRight,
              child: HighlightText(
                text: satisFiyat,
                query: query,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                maxLines: 1,
                textAlign: TextAlign.right,
              ),
            ),
          ),
        if (_serialListColumnVisibility['kdv'] == true)
          Expanded(
            flex: colKdvFlex,
            child: Container(
              width: colKdvWidth,
              padding: const EdgeInsets.only(left: 30),
              alignment: Alignment.centerLeft,
              child: HighlightText(
                text: kdvText,
                query: query,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                maxLines: 1,
              ),
            ),
          ),
        if (_serialListColumnVisibility['kdv_oran'] == true)
          Expanded(
            flex: colKdvOranFlex,
            child: Container(
              width: colKdvOranWidth,
              padding: const EdgeInsets.only(left: 4),
              alignment: Alignment.centerLeft,
              child: HighlightText(
                text: kdvOranText,
                query: query,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                maxLines: 1,
              ),
            ),
          ),
        if (_serialListColumnVisibility['kdv_tutar'] == true)
          Expanded(
            flex: colKdvTutarFlex,
            child: Container(
              width: colKdvTutarWidth,
              padding: const EdgeInsets.only(right: 4),
              alignment: Alignment.centerRight,
              child: HighlightText(
                text: kdvTutarText,
                query: query,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 1,
                textAlign: TextAlign.right,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDevicesDetailView(List devices) {
    final deviceMaps = devices
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .map(_normalizeDeviceMap)
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildDevicesSubTable(deviceMaps)],
      ),
    );
  }

  Widget _buildDevicesSubTable(List<Map<String, dynamic>> devices) {
    return Column(
      children: [
        _buildDevicesSubTableHeader(),
        ...devices.asMap().entries.map((entry) {
          final i = entry.key;
          final device = entry.value;

          return Column(
            children: [
              _buildDevicesSubTableRow(device),
              if (i != devices.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFEEEEEE),
                ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildDevicesSubTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          if (_columnVisibility['dev_identity'] == true)
            _buildDeviceHeader(tr('products.devices.identity'), flex: 10),
          if (_columnVisibility['dev_identity'] == true)
            const SizedBox(width: 12),
          if (_columnVisibility['dev_status'] == true)
            _buildDeviceHeader(tr('products.table.status'), flex: 5),
          if (_columnVisibility['dev_status'] == true)
            const SizedBox(width: 12),
          if (_columnVisibility['dev_color'] == true)
            _buildDeviceHeader(tr('products.field.color'), flex: 6),
          if (_columnVisibility['dev_color'] == true) const SizedBox(width: 12),
          if (_columnVisibility['dev_capacity'] == true)
            _buildDeviceHeader(tr('products.field.capacity'), flex: 5),
          if (_columnVisibility['dev_capacity'] == true)
            const SizedBox(width: 12),
          if (_columnVisibility['dev_warranty'] == true)
            _buildDeviceHeader(tr('report.warranty'), flex: 6),
          if (_columnVisibility['dev_warranty'] == true)
            const SizedBox(width: 12),
          if (_columnVisibility['dev_box'] == true)
            _buildDeviceHeader(tr('common.gadget.box'), flex: 3),
          if (_columnVisibility['dev_box'] == true) const SizedBox(width: 12),
          if (_columnVisibility['dev_invoice'] == true)
            _buildDeviceHeader(tr('common.gadget.invoice'), flex: 3),
          if (_columnVisibility['dev_invoice'] == true)
            const SizedBox(width: 12),
          if (_columnVisibility['dev_charger'] == true)
            _buildDeviceHeader(tr('common.gadget.charger'), flex: 4),
        ],
      ),
    );
  }

  Widget _buildDeviceHeader(
    String label, {
    int flex = 1,
    bool alignRight = false,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
      ),
    );
  }

  Widget _buildDevicesSubTableRow(Map<String, dynamic> device) {
    final query = _searchQuery.trim();
    final identity =
        (device['identityValue']?.toString().trim().isNotEmpty ?? false)
        ? device['identityValue'].toString()
        : '-';

    final condition =
        (device['condition']?.toString().trim().isNotEmpty ?? false)
        ? device['condition'].toString()
        : '-';

    final color = (device['color']?.toString().trim().isNotEmpty ?? false)
        ? device['color'].toString()
        : '-';

    final capacity = (device['capacity']?.toString().trim().isNotEmpty ?? false)
        ? device['capacity'].toString()
        : '-';

    final warranty = _formatDateOrDash(device['warrantyEndDate']);

    final hasBox = _toBool(device['hasBox']);
    final hasInvoice = _toBool(device['hasInvoice']);
    final hasCharger = _toBool(device['hasOriginalCharger']);

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        children: [
          if (_columnVisibility['dev_identity'] == true)
            Expanded(
              flex: 10,
              child: HighlightText(
                text: identity,
                query: query,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          if (_columnVisibility['dev_identity'] == true)
            const SizedBox(width: 12),
          if (_columnVisibility['dev_status'] == true)
            Expanded(
              flex: 5,
              child: HighlightText(
                text: condition,
                query: query,
                maxLines: 1,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          if (_columnVisibility['dev_status'] == true)
            const SizedBox(width: 12),
          if (_columnVisibility['dev_color'] == true)
            Expanded(
              flex: 6,
              child: HighlightText(
                text: color,
                query: query,
                maxLines: 1,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          if (_columnVisibility['dev_color'] == true) const SizedBox(width: 12),
          if (_columnVisibility['dev_capacity'] == true)
            Expanded(
              flex: 5,
              child: HighlightText(
                text: capacity,
                query: query,
                maxLines: 1,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          if (_columnVisibility['dev_capacity'] == true)
            const SizedBox(width: 12),
          if (_columnVisibility['dev_warranty'] == true)
            Expanded(
              flex: 6,
              child: HighlightText(
                text: warranty,
                query: query,
                maxLines: 1,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          if (_columnVisibility['dev_warranty'] == true)
            const SizedBox(width: 12),
          if (_columnVisibility['dev_box'] == true)
            Expanded(
              flex: 3,
              child: HighlightText(
                text: hasBox ? tr('common.yes') : '-',
                query: query,
                maxLines: 1,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          if (_columnVisibility['dev_box'] == true) const SizedBox(width: 12),
          if (_columnVisibility['dev_invoice'] == true)
            Expanded(
              flex: 3,
              child: HighlightText(
                text: hasInvoice ? tr('common.yes') : '-',
                query: query,
                maxLines: 1,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          if (_columnVisibility['dev_invoice'] == true)
            const SizedBox(width: 12),
          if (_columnVisibility['dev_charger'] == true)
            Expanded(
              flex: 4,
              child: HighlightText(
                text: hasCharger ? tr('common.yes') : '-',
                query: query,
                maxLines: 1,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> _normalizeDeviceMap(Map<String, dynamic> raw) {
    final String identityValue =
        (raw['identity_value'] ??
                raw['identityValue'] ??
                raw['serial_number'] ??
                raw['serial'] ??
                raw['imei'] ??
                raw['identity_value'] ??
                '')
            .toString()
            .trim();

    final String condition = (raw['condition'] ?? '').toString();
    final String color = (raw['color'] ?? raw['renk'] ?? '').toString();
    final String capacity = (raw['capacity'] ?? raw['kapasite'] ?? '')
        .toString();

    final dynamic warrantyEndDate =
        raw['warranty_end_date'] ?? raw['warranty'] ?? raw['warrantyEndDate'];

    return {
      'identityValue': identityValue,
      'condition': condition,
      'color': color,
      'capacity': capacity,
      'warrantyEndDate': warrantyEndDate,
      'hasBox': raw['has_box'] ?? raw['hasBox'],
      'hasInvoice': raw['has_invoice'] ?? raw['hasInvoice'],
      'hasOriginalCharger':
          raw['has_original_charger'] ?? raw['hasOriginalCharger'],
    };
  }

  bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final v = value.toString().trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes' || v == 'evet';
  }

  String _formatDateOrDash(dynamic value) {
    if (value == null) return '-';
    final raw = value.toString().trim();
    if (raw.isEmpty) return '-';

    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;

    return DateFormat('dd.MM.yyyy').format(dt);
  }

  Set<int> _getEffectiveTransactionExpandedIndices() {
    final indices = <int>{};
    for (int i = 0; i < _cachedTransactions.length; i++) {
      final tx = _cachedTransactions[i];
      final devices = tx['devices'] as List?;
      final bool isExpandable = devices != null && devices.isNotEmpty;
      if (!isExpandable) continue;

      final int? id = tx['id'] is int
          ? tx['id'] as int
          : int.tryParse(tx['id']?.toString() ?? '');

      if (_effectiveKeepDetailsOpen) {
        indices.add(i);
        continue;
      }

      if (id != null &&
          (_expandedTransactionIds.contains(id) ||
              _searchAutoExpandedTransactionIds.contains(id))) {
        indices.add(i);
      }
    }
    return indices;
  }

  Widget _buildTransactionMainRow({
    required Map<String, dynamic> tx,
    required int index,
    required double colIslemWidth,
    required int colIslemFlex,
    required double colTarihWidth,
    required int colTarihFlex,
    required double colMiktarWidth,
    required int colMiktarFlex,
    required double colBirimWidth,
    required int colBirimFlex,
    required double colFiyatWidth,
    required int colFiyatFlex,
    required double colTutarWidth,
    required int colTutarFlex,
    required double colDepoWidth,
    required int colDepoFlex,
    required double colAciklamaWidth,
    required int colAciklamaFlex,
    required double colKullaniciWidth,
    required int colKullaniciFlex,
    required bool isExpanded,
    required VoidCallback toggleExpand,
  }) {
    final query = _searchQuery.trim();
    // Extract values
    // final islemTuru = tx['islem_turu'] ?? ''; // used for raw type
    final customTypeLabel = tx['customTypeLabel']; // specific label if any
    final tarih = tx['tarih'] ?? ''; // or 'date' depending on service map
    final miktar = (tx['miktar'] as num?)?.toDouble() ?? 0.0; // or 'quantity'
    final birim = (tx['birim'] ?? _currentUrun.birim).toString();
    final birimFiyat = (tx['birim_fiyat'] as num?)?.toDouble() ?? 0.0;
    final tutar = (tx['tutar'] as num?)?.toDouble() ?? 0.0;
    final depo = tx['depo_adi'] ?? '';
    final aciklama = tx['aciklama'] ?? '';
    final kullanici = tx['kullanici'] ?? '';
    final relatedAccount = tx['relatedPartyName'] as String?;
    final String sourceSuffix = tx['sourceSuffix']?.toString() ?? '';

    // Check if 'date' key is used instead of 'tarih' by service
    final displayDate = tx['date'] ?? tarih;
    final displayWarehouse = tx['warehouse'] ?? depo;

    final bool isGiris = (tx['isIncoming'] as bool?) ?? (miktar > 0);

    // Calculate Vat included if not provided
    final kdvDahilBirimFiyat = tx['unitPriceVat'] != null
        ? (tx['unitPriceVat'] as num).toDouble()
        : birimFiyat * (1 + _currentUrun.kdvOrani / 100);

    final bool hasDevices = (tx['devices'] as List?)?.isNotEmpty == true;
    final String typeLabel = IslemCeviriYardimcisi.cevir(
      IslemTuruRenkleri.getProfessionalLabel(
        customTypeLabel ??
            (isGiris
                ? tr('warehouses.detail.type_in')
                : tr('warehouses.detail.type_out')),
        context: 'stock',
      ),
    );
    final String qtyText = FormatYardimcisi.sayiFormatla(
      miktar.abs(),
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.miktarOndalik,
    );
    final String unitPriceText =
        '${FormatYardimcisi.sayiFormatlaOndalikli(birimFiyat, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_genelAyarlar.varsayilanParaBirimi}';
    final String unitPriceVatText =
        '${FormatYardimcisi.sayiFormatlaOndalikli(kdvDahilBirimFiyat, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_genelAyarlar.varsayilanParaBirimi}';
    final String totalText =
        '${FormatYardimcisi.sayiFormatlaOndalikli(tutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_genelAyarlar.varsayilanParaBirimi}';

    return Row(
      children: [
        // Checkbox
        Container(
          width: 50,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value:
                  _isSelectAllActive ||
                  _selectedTransactionIds.contains(tx['id']),
              onChanged: (val) => _onSelectRow(val, tx['id']),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
            ),
          ),
        ),
        // Row Number & Expand Icon
        Container(
          width: 130,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              if (!hasDevices)
                const SizedBox(width: 20, height: 20)
              else
                InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: () {
                    toggleExpand();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              HighlightText(
                text: '${index + 1}',
                query: query,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ],
          ),
        ),
        if (_columnVisibility['islem'] == true)
          Expanded(
            flex: colIslemFlex,
            child: Container(
              width: colIslemWidth,
              padding: EdgeInsets.only(left: 4),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: IslemTuruRenkleri.arkaplanRengiGetir(
                        customTypeLabel,
                        isGiris,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      isGiris
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: IslemTuruRenkleri.ikonRengiGetir(
                        customTypeLabel,
                        isGiris,
                      ),
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        HighlightText(
                          text: typeLabel,
                          query: query,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: IslemTuruRenkleri.metinRengiGetir(
                              customTypeLabel,
                              isGiris,
                            ),
                          ),
                        ),
                        if (sourceSuffix.trim().isNotEmpty)
                          Text(
                            ' ${IslemCeviriYardimcisi.parantezliKaynakKisaltma(sourceSuffix.trim())}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        // İlgili Hesap
        Expanded(
          flex: 5,
          child: Container(
            width: 220,
            padding: EdgeInsets.only(left: 4),
            alignment: Alignment.centerLeft,
            child: HighlightText(
              text: relatedAccount ?? '-',
              query: query,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        if (_columnVisibility['tarih'] == true)
          Expanded(
            flex: colTarihFlex,
            child: Container(
              width: colTarihWidth,
              padding: EdgeInsets.only(left: 4),
              alignment: Alignment.centerLeft,
              child: HighlightText(
                text: displayDate.toString(),
                query: query,
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        if (_columnVisibility['depo'] == true)
          Expanded(
            flex: colDepoFlex,
            child: Container(
              width: colDepoWidth,
              padding: EdgeInsets.only(left: 4),
              alignment: Alignment.centerLeft,
              child: HighlightText(
                text: displayWarehouse.toString(),
                query: query,
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        if (_columnVisibility['miktar'] == true)
          Expanded(
            flex: colMiktarFlex,
            child: Container(
              width: colMiktarWidth,
              padding: EdgeInsets.only(right: 4),
              alignment: Alignment.centerRight,
              child: HighlightText(
                text: qtyText,
                query: query,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isGiris ? Colors.green : Colors.red,
                ),
              ),
            ),
          ),
        if (_columnVisibility['birim'] == true)
          Expanded(
            flex: colBirimFlex,
            child: Container(
              width: colBirimWidth,
              padding: EdgeInsets.only(left: 4),
              alignment: Alignment.centerLeft,
              child: HighlightText(
                text: birim,
                query: query,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ),
        if (_columnVisibility['fiyat'] == true)
          Expanded(
            flex: colFiyatFlex,
            child: Container(
              width: colFiyatWidth,
              padding: EdgeInsets.only(right: 4), // Matching 4px
              alignment: Alignment.centerRight,
              child: HighlightText(
                text: unitPriceText,
                query: query,
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        // Birim Fiyat (VD)
        if (_columnVisibility['fiyat'] == true)
          Expanded(
            flex: colFiyatFlex,
            child: Container(
              width: colFiyatWidth,
              padding: EdgeInsets.only(right: 4), // Matching 4px
              alignment: Alignment.centerRight,
              child: HighlightText(
                text: unitPriceVatText,
                query: query,
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        if (_columnVisibility['tutar'] == true)
          Expanded(
            flex: colTutarFlex,
            child: Container(
              width: colTutarWidth,
              padding: EdgeInsets.only(right: 4),
              alignment: Alignment.centerRight,
              child: HighlightText(
                text: totalText,
                query: query,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        if (_columnVisibility['aciklama'] == true)
          Expanded(
            flex: colAciklamaFlex,
            child: Container(
              width: colAciklamaWidth,
              padding: EdgeInsets.only(left: 4),
              alignment: Alignment.centerLeft,
              child: HighlightText(
                text: aciklama.toString(),
                query: query,
                maxLines: 1,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          ),
        if (_columnVisibility['kullanici'] == true)
          Expanded(
            flex: colKullaniciFlex,
            child: Container(
              width: colKullaniciWidth,
              padding: EdgeInsets.only(left: 4),
              alignment: Alignment.centerLeft,
              child: HighlightText(
                text: kullanici.toString(),
                query: query,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          ),
        // Actions
        Container(
          width: 110,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 4),
          child: _buildPopupMenu(tx),
        ),
      ],
    );
  }

  Widget _buildSimpleDetailItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value.isNotEmpty ? value : '-',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesContent(String ozellikler) {
    if (ozellikler.isEmpty) return const Text('-');

    try {
      final decoded = jsonDecode(ozellikler);
      if (decoded is List) {
        if (decoded.isEmpty) return const Text('-');
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: decoded.map<Widget>((item) {
            final name = item['name']?.toString() ?? '';
            final colorValue = item['color'];
            Color? color;
            if (colorValue != null) {
              if (colorValue is int) {
                color = Color(colorValue);
              }
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color ?? Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: color != null
                      ? color.withValues(alpha: 0.2)
                      : Colors.grey.shade300,
                ),
                boxShadow: color != null
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                name,
                style: TextStyle(
                  color: color != null
                      ? (ThemeData.estimateBrightnessForColor(color) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black87)
                      : Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        );
      }
    } catch (e) {
      // Ignore error, treat as string
    }

    return Text(
      ozellikler,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF1E293B),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _onSelectRow(bool? value, int id) {
    setState(() {
      if (value == true) {
        _selectedTransactionIds.add(id);
      } else {
        _selectedTransactionIds.remove(id);
        _isSelectAllActive = false;
      }
    });
  }

  void _onSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _isSelectAllActive = true;
        final source = _isSerialListMode
            ? _cachedSerialRows
            : _cachedTransactions;
        _selectedTransactionIds = source.map((e) => e['id'] as int).toSet();
      } else {
        _isSelectAllActive = false;
        _selectedTransactionIds.clear();
      }
    });
  }

  Widget _buildPopupMenu(Map<String, dynamic> tx) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, size: 20, color: Colors.grey),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18),
              SizedBox(width: 8),
              Text(tr('common.view')),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        // Handle actions
      },
    );
  }
}
