import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../bilesenler/genisletilebilir_tablo.dart';
import '../../../bilesenler/onay_dialog.dart';
import '../../../bilesenler/tab_acici_scope.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/ceviri/islem_ceviri_yardimcisi.dart';
import '../../../yardimcilar/responsive_yardimcisi.dart';
import 'uretim_yap_sayfasi.dart';
import '../../../bilesenler/tarih_araligi_secici_dialog.dart';
import 'fiyatlari_degistir_dialog.dart';
import 'kdvleri_degistir_dialog.dart';
import 'modeller/uretim_model.dart';
import '../depolar/modeller/depo_model.dart';
import '../../../../bilesenler/highlight_text.dart';
import 'uretim_ekle_sayfasi.dart';
import '../../../servisler/uretimler_veritabani_servisi.dart';
import '../../../servisler/depolar_veritabani_servisi.dart';
import '../../../servisler/ayarlar_veritabani_servisi.dart';
import '../../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import '../../alimsatimislemleri/alis_yap_sayfasi.dart';
import '../../alimsatimislemleri/modeller/transaction_item.dart';
import '../../alimsatimislemleri/satis_yap_sayfasi.dart';
import '../../carihesaplar/modeller/cari_hesap_model.dart';

import '../../../yardimcilar/mesaj_yardimcisi.dart';
import '../../../yardimcilar/entegrasyon_islem_yardimcisi.dart';
import '../../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../../ortak/genisletilebilir_print_preview_screen.dart';
import 'uretimler_sayfasi_dialogs.dart';
import '../../../yardimcilar/islem_turu_renkleri.dart';
import '../../../servisler/sayfa_senkronizasyon_servisi.dart';

class UretimlerSayfasi extends StatefulWidget {
  const UretimlerSayfasi({super.key});

  @override
  State<UretimlerSayfasi> createState() => _UretimlerSayfasiState();
}

class _UretimlerSayfasiState extends State<UretimlerSayfasi> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<UretimModel> _cachedUretimler = [];
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  bool _isLoading = false;
  int _totalRecords = 0;
  Map<String, Map<String, int>> _filterStats = {};
  final Set<int> _selectedIds = {};
  final Set<int> _expandedMobileIds = {};
  int? _selectedRowId;
  bool _isMobileToolbarExpanded = false;

  // Seçili detay transaction bilgisi (Son Hareketler için F2/Del kısayolları)
  int? _selectedDetailTransactionId;
  String? _selectedDetailCustomTypeLabel;
  UretimModel? _selectedDetailUretim;

  int _rowsPerPage = 25;
  int _currentPage = 1;

  // Date Filter State

  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  // Status Filter State
  bool _isStatusFilterExpanded = false;
  String? _selectedStatus;

  // Group Filter State
  bool _isGroupFilterExpanded = false;
  String? _selectedGroup;

  // Unit Filter State
  bool _isUnitFilterExpanded = false;
  String? _selectedUnit;

  // VAT Filter State
  bool _isVatFilterExpanded = false;
  double? _selectedVat;

  // Warehouse Filter State
  bool _isWarehouseFilterExpanded = false;
  DepoModel? _selectedWarehouse;
  List<DepoModel> _warehouses = [];

  // Transaction Type Filter State
  bool _isTransactionFilterExpanded = false;
  String? _selectedTransactionType;

  // User Filter State
  bool _isUserFilterExpanded = false;
  String? _selectedUser;
  List<String> _availableUsers = [];

  // Overlay State

  final Map<int, Set<int>> _selectedDetailIds = {};
  // Tracks visible transaction IDs per product for "Select All" and keyboard nav
  final Map<int, int> _pageCursors = {}; // [2025 OPTIMIZATION] Keyser cursors
  final Map<int, List<int>> _visibleTransactionIds = {};
  Set<int> _autoExpandedIndices = {}; // Auto-expanded rows based on deep search
  int? _manualExpandedIndex;
  final LayerLink _statusLayerLink = LayerLink();
  final LayerLink _groupLayerLink = LayerLink();
  final LayerLink _unitLayerLink = LayerLink();
  final LayerLink _vatLayerLink = LayerLink();
  final LayerLink _warehouseLayerLink = LayerLink();
  final LayerLink _transactionLayerLink = LayerLink();
  final LayerLink _userLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  // Mock transactions for detail view

  // Cache for detail futures to prevent reloading on selection changes
  final Map<int, Future<List<Map<String, dynamic>>>> _detailFutures = {};
  final Map<int, Future<double>> _costFutures = {}; // Cache for estimated cost
  final Map<String, ImageProvider> _imageCache = {}; // Cache for decoded images
  int _refreshKey = 0; // Key to force rebuild detail views

  bool _keepDetailsOpen = false;

  // Column Visibility State
  Map<String, bool> _columnVisibility = {};

  // Sorting State
  int? _sortColumnIndex = 1; // Default sort by ID
  bool _sortAscending = false;
  String? _sortBy = 'id';
  Timer? _debounce;
  int _aktifSorguNo = 0;

  List<String> _availableGroups = [];
  List<String> _availableUnits = [];
  List<double> _availableVats = [];
  List<String> _availableTransactionTypes = [];

  @override
  void initState() {
    super.initState();
    _columnVisibility = {
      // Main Table
      'order_no': true,
      'code': true,
      'name': true,
      'stock': true,
      'unit': true,
      'cost_price': true,
      'vat': true,
      'status': true,
      // Detail Table
      'dt_type': true,
      'dt_related_account': true,
      'dt_date': true,
      'dt_warehouse': true,
      'dt_quantity': true,
      'dt_unit': true,
      'dt_unit_price': true,
      'dt_unit_price_vd': true,
      'dt_total_price': true,
      'dt_description': true,
      'dt_user': true,
    };
    _loadSettings();
    _loadAvailableFilters();
    _loadAvailableUsers();
    _fetchWarehouses();
    _fetchUretimler();

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (_searchController.text != _searchQuery) {
          setState(() {
            _searchQuery = _searchController.text.toLowerCase();
            _resetPagination();
          });
          _fetchUretimler();
        }
      });
    });

    SayfaSenkronizasyonServisi().addListener(_onGlobalSync);
  }

  void _onGlobalSync() {
    _fetchUretimler(showLoading: false);
  }

  void _resetPagination() {
    _pageCursors.clear();
    _currentPage = 1;
  }

  Future<void> _fetchUretimler({bool showLoading = true}) async {
    // Clear detail cache when refreshing main list
    _detailFutures.clear();
    _costFutures.clear();
    _imageCache.clear();

    final int sorguNo = ++_aktifSorguNo;

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final bool? aktifMi = _selectedStatus == 'active'
          ? true
          : (_selectedStatus == 'passive' ? false : null);

      final urunler = await UretimlerVeritabaniServisi().uretimleriGetir(
        sayfa: _currentPage,
        sayfaBasinaKayit: _rowsPerPage,
        aramaTerimi: _searchQuery,
        sortBy: _sortBy,
        sortAscending: _sortAscending,
        aktifMi: aktifMi,
        grup: _selectedGroup,
        birim: _selectedUnit,
        kdvOrani: _selectedVat,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        depoIds: _selectedWarehouse != null ? [_selectedWarehouse!.id] : null,
        islemTuru: _selectedTransactionType,
        kullanici: _selectedUser,
        lastId: _currentPage > 1 ? _pageCursors[_currentPage - 1] : null,
      );

      if (!mounted || sorguNo != _aktifSorguNo) return;

      final totalFuture = UretimlerVeritabaniServisi().uretimSayisiGetir(
        aramaTerimi: _searchQuery,
        aktifMi: aktifMi,
        grup: _selectedGroup,
        birim: _selectedUnit,
        kdvOrani: _selectedVat,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        depoIds: _selectedWarehouse != null ? [_selectedWarehouse!.id] : null,
        islemTuru: _selectedTransactionType,
        kullanici: _selectedUser,
      );

      final statsFuture = UretimlerVeritabaniServisi()
          .uretimFiltreIstatistikleriniGetir(
            aramaTerimi: _searchQuery,
            baslangicTarihi: _startDate,
            bitisTarihi: _endDate,
            aktifMi: aktifMi,
            grup: _selectedGroup,
            birim: _selectedUnit,
            kdvOrani: _selectedVat,
            depoIds: _selectedWarehouse != null
                ? [_selectedWarehouse!.id]
                : null,
            islemTuru: _selectedTransactionType,
            kullanici: _selectedUser,
          );

      if (mounted) {
        final indices = <int>{};
        if (_selectedWarehouse != null ||
            _selectedGroup != null ||
            _selectedUnit != null ||
            _selectedTransactionType != null ||
            _selectedUser != null ||
            _startDate != null ||
            _endDate != null) {
          // Depo, Grup, Birim veya Tarih filtresi aktifse detayları görmek için hepsini aç
          indices.addAll(List.generate(urunler.length, (i) => i));
        } else if (_searchQuery.isNotEmpty) {
          // Derin arama sonucu sadece gizli/detay alanlarda eşleşen satırlar için
          // veritabanından gelen matchedInHidden bayrağını kullan.
          // Böylece kullanıcı aradığı kelimeyi sadece hareket/detay kısmında
          // bulduğunda ilgili satır otomatik olarak genişler.
          for (int i = 0; i < urunler.length; i++) {
            if (urunler[i].matchedInHidden) {
              indices.add(i);
              _expandedMobileIds.add(urunler[i].id);
            }
          }
        }

        setState(() {
          _isLoading = false;
          _cachedUretimler = urunler;
          _autoExpandedIndices = indices;

          // Store last ID for next page cursor
          if (urunler.isNotEmpty) {
            _pageCursors[_currentPage] = urunler.last.id;
          }
        });
      }

      unawaited(
        totalFuture
            .then((total) {
              if (!mounted || sorguNo != _aktifSorguNo) return;
              setState(() {
                _totalRecords = total;
              });
            })
            .catchError((e) {
              debugPrint('Üretim toplam sayısı güncellenemedi: $e');
            }),
      );

      unawaited(
        statsFuture
            .then((stats) {
              if (!mounted || sorguNo != _aktifSorguNo) return;
              setState(() {
                _filterStats = stats;
              });
            })
            .catchError((e) {
              debugPrint('Üretim filtre istatistikleri güncellenemedi: $e');
            }),
      );
    } catch (e) {
      if (mounted && sorguNo == _aktifSorguNo) {
        setState(() => _isLoading = false);
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
    if (mounted) {
      setState(() {
        _keepDetailsOpen =
            prefs.getBool('uretimler_keep_details_open') ?? false;
        _genelAyarlar = settings;
      });
    }
  }

  Future<void> _toggleKeepDetailsOpen() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _keepDetailsOpen = !_keepDetailsOpen;
    });
    await prefs.setBool('uretimler_keep_details_open', _keepDetailsOpen);
  }

  void _showColumnVisibilityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Map<String, bool> localVisibility = Map.from(_columnVisibility);

        bool isAllMainSelected() {
          return localVisibility.entries
              .where((e) => !e.key.startsWith('dt_'))
              .every((e) => e.value);
        }

        bool isAllDetailSelected() {
          return localVisibility.entries
              .where((e) => e.key.startsWith('dt_'))
              .every((e) => e.value);
        }

        void toggleAllMain(bool? value) {
          for (var key in localVisibility.keys) {
            if (!key.startsWith('dt_')) {
              localVisibility[key] = value ?? false;
            }
          }
        }

        void toggleAllDetail(bool? value) {
          for (var key in localVisibility.keys) {
            if (key.startsWith('dt_')) {
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
                      // --- MAIN TABLE SECTION ---
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
                            'order_no',
                            tr('language.table.orderNo'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'code',
                            tr('productions.table.code'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'name',
                            tr('productions.table.name'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'stock',
                            tr('productions.table.stock'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'unit',
                            tr('productions.table.unit'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'cost_price',
                            tr('productions.table.cost_price'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'vat',
                            tr('productions.table.vat'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'status',
                            tr('productions.table.status'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // --- DETAIL TABLE SECTION ---
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
                              tr('common.last_movements'),
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
                            'dt_type',
                            tr('productions.transaction.type'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_related_account',
                            tr('warehouses.detail.related_account'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_date',
                            tr('productions.transaction.date'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_warehouse',
                            tr('productions.transaction.warehouse'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_quantity',
                            tr('productions.transaction.quantity'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_unit',
                            tr('productions.table.unit'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_unit_price',
                            tr('productions.transaction.unit_price'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_unit_price_vd',
                            tr('productions.transaction.unit_price_vd'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_total_price',
                            tr('common.total'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_description',
                            tr('common.description'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_user',
                            tr('warehouses.detail.user'),
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

  Widget _buildConfigCheckbox(
    StateSetter setDialogState,
    Map<String, bool> localMap,
    String key,
    String label,
  ) {
    return SizedBox(
      width: 170,
      child: InkWell(
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

  Future<void> _loadAvailableFilters() async {
    try {
      final groups = await UretimlerVeritabaniServisi().uretimGruplariniGetir();
      final units = await UretimlerVeritabaniServisi().uretimBirimleriniGetir();
      final vats = await UretimlerVeritabaniServisi()
          .uretimKdvOranlariniGetir();
      final types = await UretimlerVeritabaniServisi()
          .getUretimStokIslemTurleri();

      if (mounted) {
        setState(() {
          _availableGroups = groups;
          _availableUnits = units;
          _availableVats = vats;
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

  @override
  void dispose() {
    SayfaSenkronizasyonServisi().removeListener(_onGlobalSync);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _isStatusFilterExpanded = false;
        _isGroupFilterExpanded = false;
        _isUnitFilterExpanded = false;
        _isVatFilterExpanded = false;
        _isWarehouseFilterExpanded = false;
        _isTransactionFilterExpanded = false;
        _isUserFilterExpanded = false;
      });
    }
  }

  void _showStatusOverlay() {
    _closeOverlay();
    setState(() {
      _isStatusFilterExpanded = true;
    });

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _statusLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 42),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Container(
                width: 200,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusOption(
                      null,
                      tr('settings.general.option.documents.all'),
                    ),
                    _buildStatusOption('active', tr('common.active')),
                    _buildStatusOption('passive', tr('common.passive')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _showGroupOverlay() {
    _closeOverlay();
    setState(() {
      _isGroupFilterExpanded = true;
    });

    // Get distinct groups from DB
    // Get distinct groups from DB
    // [FIX] User Request: Only show groups if they exist in data
    final groups = _availableGroups;
    if (_availableGroups.isEmpty) {
      groups.sort();
    }

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _groupLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 42),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Container(
                width: 200,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGroupOption(
                      null,
                      tr('settings.general.option.documents.all'),
                    ),
                    ...groups.map((g) => _buildGroupOption(g, g)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _showUnitOverlay() {
    _closeOverlay();
    setState(() {
      _isUnitFilterExpanded = true;
    });

    // Get distinct units from DB
    final units = _availableUnits.isNotEmpty
        ? _availableUnits
        : _genelAyarlar.urunBirimleri.map((u) => u['name'].toString()).toList();
    if (_availableUnits.isEmpty) {
      units.sort();
    }
    units.sort();

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _unitLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 42),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Container(
                width: 150,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildUnitOption(
                      null,
                      tr('settings.general.option.documents.all'),
                    ),
                    ...units.map((u) => _buildUnitOption(u, u)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _showVatOverlay() {
    _closeOverlay();
    setState(() {
      _isVatFilterExpanded = true;
    });

    // Get distinct VAT rates from DB
    final vats = _availableVats.isNotEmpty
        ? _availableVats
        : UretimModel.ornekVeriler().map((u) => u.kdvOrani).toSet().toList();
    vats.sort();

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _vatLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 42),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Container(
                width: 150,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildVatOption(
                      null,
                      tr('settings.general.option.documents.all'),
                    ),
                    ...vats.map(
                      (v) =>
                          _buildVatOption(v, '%${v % 1 == 0 ? v.toInt() : v}'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _showTransactionOverlay() {
    _closeOverlay();
    setState(() {
      _isTransactionFilterExpanded = true;
    });

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _transactionLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 42),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Container(
                width: 260,
                constraints: const BoxConstraints(maxHeight: 300),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTransactionOption(
                        null,
                        tr('settings.general.option.documents.all'),
                      ),
                      ..._availableTransactionTypes.map(
                        (t) => _buildTransactionOption(t, t),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _showUserOverlay() {
    _closeOverlay();
    setState(() {
      _isUserFilterExpanded = true;
    });

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _userLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 42),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Container(
                width: 220,
                constraints: const BoxConstraints(maxHeight: 400),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildUserOption(
                        null,
                        tr('settings.general.option.documents.all'),
                      ),
                      ..._availableUsers.map((u) => _buildUserOption(u, u)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  Future<void> _showAddDialog() async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const UretimEkleSayfasi(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );

    if (result == true) {
      SayfaSenkronizasyonServisi().veriDegisti('urun');
      _fetchUretimler();
    }
  }

  Future<void> _showEditDialog(
    UretimModel urun, {
    bool focusOnStock = false,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            UretimEkleSayfasi(urun: urun, focusOnStock: focusOnStock),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );

    if (result == true) {
      SayfaSenkronizasyonServisi().veriDegisti('urun');
      _fetchUretimler();
    }
  }

  Future<void> _deleteSelectedUrunler() async {
    if (_selectedIds.isEmpty) return;

    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr(
          'common.confirm_delete_named',
        ).replaceAll('{name}', '${_selectedIds.length} kayıt'),
        onOnay: () {},
        isDestructive: true,
        onayButonMetni: tr('common.delete'),
      ),
    );

    if (onay == true) {
      await UretimlerVeritabaniServisi().topluUretimSil(_selectedIds.toList());
      setState(() {
        _selectedIds.clear();
      });
      if (!mounted) return;
      SayfaSenkronizasyonServisi().veriDegisti('urun');
      MesajYardimcisi.basariGoster(context, tr('common.deleted_successfully'));
      _fetchUretimler();
    }
  }

  void _deleteUrun(UretimModel urun) async {
    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr('common.confirm_delete_named').replaceAll('{name}', urun.ad),
        onOnay: () {},
        isDestructive: true,
        onayButonMetni: tr('common.delete'),
      ),
    );

    if (onay == true) {
      await UretimlerVeritabaniServisi().uretimSil(urun.id);
      if (!mounted) return;
      SayfaSenkronizasyonServisi().veriDegisti('urun');
      MesajYardimcisi.basariGoster(context, tr('common.deleted_successfully'));
      _fetchUretimler();
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Future<bool> _openAlisSatisDuzenlemeFromShipment(int shipmentId) async {
    try {
      final shipmentData = await DepolarVeritabaniServisi().sevkiyatGetir(
        shipmentId,
      );
      final String ref =
          shipmentData?['integration_ref']?.toString().trim() ?? '';
      final bool isSale = ref.startsWith('SALE-');
      final bool isPurchase = ref.startsWith('PURCHASE-');
      if (!isSale && !isPurchase) return false;

      if (!mounted) return true;

      bool overlayShown = false;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          overlayShown = true;
          return const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );

      Map<String, dynamic>? editTx;
      CariHesapModel? cari;
      List<TransactionItem> items = const [];
      Object? error;

      try {
        editTx = await CariHesaplarVeritabaniServisi().cariIslemGetirByRef(ref);
        final cariId = _parseInt(editTx?['current_account_id']);
        if (cariId != null) {
          cari = await CariHesaplarVeritabaniServisi().cariHesapGetir(cariId);
        }
        items = await EntegrasyonIslemYardimcisi.entegrasyonKalemleriniYukle(
          ref,
        );
      } catch (e) {
        error = e;
      } finally {
        if (overlayShown && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }

      if (!mounted) return true;

      if (error != null) {
        EntegrasyonIslemYardimcisi.logError(error);
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $error');
        return true;
      }

      if (editTx == null || cari == null || items.isEmpty) {
        MesajYardimcisi.hataGoster(context, tr('common.no_data'));
        return true;
      }

      final String initialCurrency = (items.first.currency == 'TL')
          ? 'TRY'
          : items.first.currency;
      final double initialRate = items.first.exchangeRate;

      final String? initialDescription =
          (editTx['description'] ?? shipmentData?['description'])?.toString();

      final Map<String, dynamic> duzenlenecekIslem = Map<String, dynamic>.from(
        editTx,
      );

      final tabScope = TabAciciScope.of(context);
      if (tabScope != null) {
        tabScope.tabAc(
          menuIndex: isSale ? 11 : 10,
          initialCari: cari,
          initialItems: items,
          initialCurrency: initialCurrency,
          initialDescription: initialDescription,
          initialRate: initialRate,
          duzenlenecekIslem: duzenlenecekIslem,
        );
        return true;
      }

      final Widget page = isSale
          ? SatisYapSayfasi(
              initialCari: cari,
              initialItems: items,
              initialCurrency: initialCurrency,
              initialDescription: initialDescription,
              initialRate: initialRate,
              duzenlenecekIslem: duzenlenecekIslem,
            )
          : AlisYapSayfasi(
              initialCari: cari,
              initialItems: items,
              initialCurrency: initialCurrency,
              initialDescription: initialDescription,
              initialRate: initialRate,
              duzenlenecekIslem: duzenlenecekIslem,
            );

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => page),
      );

      if (result == true && mounted) {
        SayfaSenkronizasyonServisi().veriDegisti('urun');
        setState(() {
          _detailFutures.clear();
          _refreshKey++;
        });
        _fetchUretimler();
      }

      return true;
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
      return true;
    }
  }

  /// Detay transaction düzenleme (F2 kısayolu için)
  void _handleDetailEdit(
    int id,
    String? customTypeLabel,
    UretimModel urun,
  ) async {
    if (customTypeLabel == 'Açılış Stoğu (Girdi)') {
      _showEditDialog(urun, focusOnStock: true);
    } else if (customTypeLabel == 'Üretim (Girdi)' ||
        customTypeLabel == 'Üretim (Çıktı)') {
      DepolarVeritabaniServisi().sevkiyatGetir(id).then((data) async {
        if (data != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UretimYapSayfasi(
                initialModel: urun,
                editingTransactionId: id,
                initialData: data,
              ),
            ),
          ).then((result) {
            if (result == true) {
              SayfaSenkronizasyonServisi().veriDegisti('urun');
              _detailFutures.clear();
              _refreshKey++;
              _fetchUretimler();
            }
          });
        }
      });
    } else {
      await _openAlisSatisDuzenlemeFromShipment(id);
    }
    // Seçimi temizle
    setState(() {
      _selectedDetailTransactionId = null;
      _selectedDetailCustomTypeLabel = null;
      _selectedDetailUretim = null;
    });
  }

  /// Detay transaction silme (Del kısayolu için)
  void _handleDetailDelete(int id) {
    _deleteTransaction(id);
    // Seçimi temizle
    setState(() {
      _selectedDetailTransactionId = null;
      _selectedDetailCustomTypeLabel = null;
      _selectedDetailUretim = null;
    });
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _startDateController.clear();
      _endDateController.clear();
      _resetPagination();
    });
    _fetchUretimler();
  }

  Future<void> _handlePrint() async {
    setState(() => _isLoading = true);
    try {
      List<ExpandableRowData> rows = [];

      // Check if any selections exist
      final hasMainSelection = _selectedIds.isNotEmpty;
      final hasDetailSelection = _selectedDetailIds.values.any(
        (s) => s.isNotEmpty,
      );

      // Determine which main rows to process
      Set<int> mainRowIdsToProcess = {};

      if (hasMainSelection) {
        mainRowIdsToProcess.addAll(_selectedIds);
      }

      if (hasDetailSelection) {
        for (var entry in _selectedDetailIds.entries) {
          if (entry.value.isNotEmpty) {
            mainRowIdsToProcess.add(entry.key);
          }
        }
      }

      // Filter data based on selection
      final dataToProcess = mainRowIdsToProcess.isNotEmpty
          ? _cachedUretimler
                .where((u) => mainRowIdsToProcess.contains(u.id))
                .toList()
          : _cachedUretimler;

      for (var i = 0; i < dataToProcess.length; i++) {
        final urun = dataToProcess[i];

        // Determine if row is expanded
        final isExpanded =
            _keepDetailsOpen ||
            _autoExpandedIndices.contains(i) ||
            _manualExpandedIndex == i;

        List<Map<String, dynamic>> transactions = [];
        // 1. Transactions Fetch (Only if expanded or has selected details)
        final hasPrintSelectedDetails =
            _selectedDetailIds[urun.id]?.isNotEmpty ?? false;
        if (isExpanded || hasPrintSelectedDetails) {
          transactions = await DepolarVeritabaniServisi()
              .urunHareketleriniGetir(
                urun.kod,
                kdvOrani: urun.kdvOrani,
                baslangicTarihi: _startDate,
                bitisTarihi: _endDate,
                warehouseIds: _selectedWarehouse != null
                    ? [_selectedWarehouse!.id]
                    : null,
                islemTuru: _selectedTransactionType,
                kullanici: _selectedUser,
              );
        }

        // Filter transactions if detail selection exists for this row
        final selectedDetailIdsForRow = _selectedDetailIds[urun.id];
        if (selectedDetailIdsForRow != null &&
            selectedDetailIdsForRow.isNotEmpty) {
          transactions = transactions.where((t) {
            final txId = t['id'] as int?;
            return txId != null && selectedDetailIdsForRow.contains(txId);
          }).toList();
        }

        // Calculate Cost Price
        double cost = 0.0;
        if (urun.alisFiyati > 0) {
          cost = urun.alisFiyati;
        } else {
          cost = await UretimlerVeritabaniServisi().calculateEstimatedUnitCost(
            urun.id,
          );
        }
        String formattedCost = FormatYardimcisi.sayiFormatlaOndalikli(
          cost,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.fiyatOndalik,
        );
        if (_genelAyarlar.sembolGoster) {
          formattedCost += ' ${_genelAyarlar.varsayilanParaBirimi}';
        }

        // 2. Main Row Data
        final mainRow = [
          urun.id.toString(),
          urun.kod,
          urun.ad,
          FormatYardimcisi.sayiFormatla(
            urun.stok,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: _genelAyarlar.miktarOndalik,
          ),
          urun.birim,
          formattedCost,
          '%${FormatYardimcisi.sayiFormatlaOran(urun.kdvOrani, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: 2)}',
          urun.aktifMi ? tr('common.active') : tr('common.passive'),
        ];

        // 3. Details (Key-Value) - Only if row is expanded or has selected detail items
        Map<String, String> details = {};
        final hasSelectedDetails =
            _selectedDetailIds[urun.id]?.isNotEmpty ?? false;
        if (isExpanded || hasSelectedDetails) {
          // Calculate Girdi/Çıktı from transactions
          double totalGirdi = 0;
          double totalCikti = 0;
          for (var t in transactions) {
            final qty = (t['quantity'] is num)
                ? (t['quantity'] as num).toDouble()
                : double.tryParse(t['quantity'].toString()) ?? 0;
            final isIncoming = t['isIncoming'] == true;
            if (isIncoming) {
              totalGirdi += qty;
            } else {
              totalCikti += qty;
            }
          }

          // Format Satış Fiyatları
          String formatPrice(double price) {
            if (price <= 0) return '-';
            String formatted = FormatYardimcisi.sayiFormatlaOndalikli(
              price,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
              decimalDigits: _genelAyarlar.fiyatOndalik,
            );
            if (_genelAyarlar.sembolGoster) {
              formatted += ' ${_genelAyarlar.varsayilanParaBirimi}';
            }
            return '$formatted (${tr('common.vat_excluded')})';
          }

          details = {
            tr('products.table.barcode'): urun.barkod.isNotEmpty
                ? urun.barkod
                : '-',
            tr(
              'products.table.alert_qty',
            ): '${FormatYardimcisi.sayiFormatla(urun.erkenUyariMiktari, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.miktarOndalik)} ${urun.birim}',
            tr('products.table.sales_price_1'): formatPrice(urun.satisFiyati1),
            tr('products.table.sales_price_2'): formatPrice(urun.satisFiyati2),
            tr('products.table.sales_price_3'): formatPrice(urun.satisFiyati3),
            tr('products.table.features'): urun.ozellikler.isNotEmpty
                ? urun.ozellikler
                : '-',
            tr(
              'products.transaction.type.input',
            ): FormatYardimcisi.sayiFormatla(
              totalGirdi,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
              decimalDigits: _genelAyarlar.miktarOndalik,
            ),
            tr(
              'products.transaction.type.output',
            ): FormatYardimcisi.sayiFormatla(
              totalCikti,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
              decimalDigits: _genelAyarlar.miktarOndalik,
            ),
          };
        }

        // 4. Transaction Table
        DetailTable? txTable;
        if (transactions.isNotEmpty) {
          txTable = DetailTable(
            title: tr('productions.detail.transactions'),
            headers: [
              tr('productions.transaction.type'),
              tr('warehouses.detail.related_account'), // İlgili Hesap
              tr('productions.transaction.date'),
              tr('productions.transaction.warehouse'),
              tr('productions.transaction.quantity'),
              tr('productions.table.unit'),
              tr('productions.transaction.unit_price'),
              tr('productions.transaction.unit_price_vd'),
              tr('common.total'),
              tr('warehouses.detail.user'),
            ],
            data: transactions.map((t) {
              final relatedPartyName = t['relatedPartyName'] as String?;
              // Fiyat formatlaması - tablodaki görünümle aynı
              String formattedUnitPrice = '-';
              final unitPriceVal = t['unitPrice'];
              if (unitPriceVal is num && unitPriceVal > 0) {
                formattedUnitPrice = FormatYardimcisi.sayiFormatlaOndalikli(
                  unitPriceVal,
                  binlik: _genelAyarlar.binlikAyiraci,
                  ondalik: _genelAyarlar.ondalikAyiraci,
                  decimalDigits: _genelAyarlar.fiyatOndalik,
                );
                if (_genelAyarlar.sembolGoster) {
                  formattedUnitPrice +=
                      ' ${_genelAyarlar.varsayilanParaBirimi}';
                }
              }

              String formattedUnitPriceVat = '-';
              final unitPriceVatVal = t['unitPriceVat'];
              if (unitPriceVatVal is num && unitPriceVatVal > 0) {
                formattedUnitPriceVat = FormatYardimcisi.sayiFormatlaOndalikli(
                  unitPriceVatVal,
                  binlik: _genelAyarlar.binlikAyiraci,
                  ondalik: _genelAyarlar.ondalikAyiraci,
                  decimalDigits: _genelAyarlar.fiyatOndalik,
                );
                if (_genelAyarlar.sembolGoster) {
                  formattedUnitPriceVat +=
                      ' ${_genelAyarlar.varsayilanParaBirimi}';
                }
              }

              String formattedTotalPrice = '-';
              final quantity = t['quantity'];
              dynamic totalVal;
              if (quantity is num && unitPriceVatVal is num) {
                totalVal = quantity * unitPriceVatVal;
              } else {
                final q = double.tryParse(quantity.toString()) ?? 0.0;
                final p = double.tryParse(unitPriceVatVal.toString()) ?? 0.0;
                if (q > 0 || p > 0) totalVal = q * p;
              }

              if (totalVal != null && totalVal > 0) {
                formattedTotalPrice = FormatYardimcisi.sayiFormatlaOndalikli(
                  totalVal,
                  binlik: _genelAyarlar.binlikAyiraci,
                  ondalik: _genelAyarlar.ondalikAyiraci,
                  decimalDigits: _genelAyarlar.fiyatOndalik,
                );
                if (_genelAyarlar.sembolGoster) {
                  formattedTotalPrice +=
                      ' ${_genelAyarlar.varsayilanParaBirimi}';
                }
              }

              // Use the same label logic as the screen
              final String rawTypeLabel =
                  t['customTypeLabel']?.toString() ??
                  (t['isIncoming'] == true
                      ? tr('warehouses.detail.type_in')
                      : tr('warehouses.detail.type_out'));
              final String displayTypeLabel =
                  IslemTuruRenkleri.getProfessionalLabel(
                    rawTypeLabel,
                    context: 'stock',
                  );

              final translatedTypeLabel = IslemCeviriYardimcisi.cevir(
                displayTypeLabel,
              );

              final String transactionSourceSuffix =
                  t['sourceSuffix']?.toString() ?? '';
              final String transactionSourceText =
                  transactionSourceSuffix.trim().isNotEmpty
                  ? ' ${IslemCeviriYardimcisi.parantezliKaynakKisaltma(transactionSourceSuffix.trim())}'
                  : '';

              return <String>[
                '$translatedTypeLabel$transactionSourceText', // Uses translated label
                relatedPartyName ?? '-', // Related Account
                t['date']?.toString() ?? '',
                t['warehouse']?.toString() ?? '',

                FormatYardimcisi.sayiFormatla(
                  t['quantity'] is num
                      ? t['quantity']
                      : double.tryParse(t['quantity'].toString()) ?? 0,
                  binlik: _genelAyarlar.binlikAyiraci,
                  ondalik: _genelAyarlar.ondalikAyiraci,
                  decimalDigits: _genelAyarlar.miktarOndalik,
                ),
                urun.birim,
                formattedUnitPrice,
                formattedUnitPriceVat,
                formattedTotalPrice,
                t['user']?.toString() ?? tr('common.system'),
              ];
            }).toList(),
          );
        }

        final List<String> imageUrls;
        if (urun.resimler.isNotEmpty) {
          imageUrls = urun.resimler;
        } else if (urun.resimUrl != null && urun.resimUrl!.isNotEmpty) {
          imageUrls = [urun.resimUrl!];
        } else {
          imageUrls = const <String>[];
        }

        rows.add(
          ExpandableRowData(
            mainRow: mainRow,
            details: details,
            transactions: txTable,
            imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
          ),
        );
      }

      if (mounted) setState(() => _isLoading = false);

      if (!mounted) return;

      String? dateInfo;
      if (_startDate != null && _endDate != null) {
        final df = DateFormat('dd.MM.yyyy');
        dateInfo =
            '${tr('common.date_range')}: ${df.format(_startDate!)} - ${df.format(_endDate!)}';
      } else if (_startDate != null) {
        final df = DateFormat('dd.MM.yyyy');
        dateInfo =
            '${tr('common.date_range')}: ${df.format(_startDate!)} - ...';
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GenisletilebilirPrintPreviewScreen(
            title: tr('productions.title'),
            headers: [
              tr('language.table.orderNo'),
              tr('productions.table.code'),
              tr('productions.table.name'),
              tr('productions.table.stock'),
              tr('productions.table.unit'),
              tr('productions.table.cost_price'),
              tr('productions.table.vat'),
              tr('productions.table.status'),
            ],
            data: rows,
            dateInterval: dateInfo,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  Future<void> _uretimDurumDegistir(UretimModel urun, bool aktifMi) async {
    try {
      final yeniUretim = urun.copyWith(aktifMi: aktifMi);
      await UretimlerVeritabaniServisi().uretimGuncelle(yeniUretim);
      if (mounted) {
        setState(() {
          _detailFutures.clear();
          _refreshKey++;
        });
      }
      await _fetchUretimler(showLoading: false);

      if (!mounted) return;
      MesajYardimcisi.basariGoster(
        context,
        aktifMi ? tr('common.active_success') : tr('common.passive_success'),
      );
    } catch (e) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    List<UretimModel> filteredUrunler = _cachedUretimler;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Focus(
        autofocus: false, // Let GenisletilebilirTablo handle focus
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              // Priority 1: Close Overlay if open
              if (_overlayEntry != null) {
                _closeOverlay();
                return;
              }

              // Priority 2: Clear Search if active
              if (_searchController.text.isNotEmpty) {
                _searchController.clear();
                // Listener will handle state update
                return;
              }

              // Priority 3: Clear Filters if active
              if (_startDate != null ||
                  _endDate != null ||
                  _selectedStatus != null ||
                  _selectedUnit != null ||
                  _selectedWarehouse != null ||
                  _selectedGroup != null ||
                  _selectedVat != null ||
                  _selectedTransactionType != null ||
                  _selectedUser != null) {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _startDateController.clear();
                  _endDateController.clear(); // Reset date controllers too
                  _selectedStatus = null;
                  _selectedUnit = null;
                  _selectedWarehouse = null;
                  _selectedGroup = null;
                  _selectedVat = null;
                  _selectedTransactionType = null;
                  _selectedUser = null;
                });
                _fetchUretimler();
                return;
              }
            },
            const SingleActivator(LogicalKeyboardKey.f1): _showAddDialog,
            const SingleActivator(LogicalKeyboardKey.f2): () {
              // F2: Düzenle - önce seçili detay transaction varsa onu düzenle
              if (_selectedDetailTransactionId != null &&
                  _selectedDetailUretim != null) {
                _handleDetailEdit(
                  _selectedDetailTransactionId!,
                  _selectedDetailCustomTypeLabel,
                  _selectedDetailUretim!,
                );
                return;
              }
              // Yoksa ana satırı düzenle
              if (_selectedRowId == null) return;
              final selectedId = _selectedRowId!;
              final urun = _cachedUretimler.firstWhere(
                (u) => u.id == selectedId,
              );
              _showEditDialog(urun);
            },
            const SingleActivator(LogicalKeyboardKey.f3): () {
              // F3: Ara - arama kutusuna odaklan
              _searchFocusNode.requestFocus();
            },
            const SingleActivator(LogicalKeyboardKey.f5): () =>
                _fetchUretimler(),
            const SingleActivator(LogicalKeyboardKey.f6): () {
              // F6: Aktif/Pasif Toggle - seçili satır varsa
              if (_selectedRowId == null) return;
              final selectedId = _selectedRowId!;
              final urun = _cachedUretimler.firstWhere(
                (u) => u.id == selectedId,
              );
              _uretimDurumDegistir(urun, !urun.aktifMi);
            },
            const SingleActivator(LogicalKeyboardKey.f7): _handlePrint,
            const SingleActivator(LogicalKeyboardKey.f8): () {
              // F8: Seçilileri Sil
              if (_selectedIds.isEmpty) return;
              _deleteSelectedUrunler();
            },
            const SingleActivator(LogicalKeyboardKey.delete): () {
              // Delete: Önce seçili detay transaction varsa onu sil
              if (_selectedDetailTransactionId != null) {
                _handleDetailDelete(_selectedDetailTransactionId!);
                return;
              }
              // Yoksa ana satırı sil
              if (_selectedRowId == null) return;
              final selectedId = _selectedRowId!;
              final urun = _cachedUretimler.firstWhere(
                (u) => u.id == selectedId,
              );
              _deleteUrun(urun);
            },
            const SingleActivator(LogicalKeyboardKey.numpadDecimal): () {
              // Numpad Delete: Önce seçili detay transaction varsa onu sil
              if (_selectedDetailTransactionId != null) {
                _handleDetailDelete(_selectedDetailTransactionId!);
                return;
              }
              // Yoksa ana satırı sil
              if (_selectedRowId == null) return;
              final selectedId = _selectedRowId!;
              final urun = _cachedUretimler.firstWhere(
                (u) => u.id == selectedId,
              );
              _deleteUrun(urun);
            },
            const SingleActivator(LogicalKeyboardKey.f10): () async {
              // F10: Üretim Yap
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => const UretimYapSayfasi(),
                ),
              );
              if (result == true) _fetchUretimler();
            },
            const SingleActivator(LogicalKeyboardKey.f11): () async {
              // F11: Fiyat Değiştir
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => const FiyatlariDegistirDialog(),
              );
              if (result == true) _fetchUretimler();
            },
            const SingleActivator(LogicalKeyboardKey.f12): () async {
              // F12: KDV Değiştir
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => const KdvleriDegistirDialog(),
              );
              if (result == true) _fetchUretimler();
            },
          },
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool forceMobile =
                      ResponsiveYardimcisi.tabletMi(context);
                  if (forceMobile || constraints.maxWidth < 1000) {
                    return _buildMobileView(filteredUrunler);
                  } else {
                    return _buildDesktopView(filteredUrunler, constraints);
                  }
                },
              ),
              if (_isLoading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: Colors.transparent,
                    color: Color(0xFF2C3E50),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Clear all selections when tapping outside the table
  void _clearAllTableSelections() {
    setState(() {
      _selectedIds.clear();
      _selectedDetailIds.clear();
      _selectedRowId = null;
      _selectedDetailTransactionId = null;
      _selectedDetailCustomTypeLabel = null;
      _selectedDetailUretim = null;
    });
  }

  void _onSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedIds.addAll(_cachedUretimler.map((e) => e.id));
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _onSelectRow(bool? value, int id) {
    setState(() {
      if (value == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _onSelectAllDetails(int urunId, bool? value) {
    setState(() {
      if (value == true) {
        _selectedDetailIds[urunId] = (_visibleTransactionIds[urunId] ?? [])
            .toSet();
      } else {
        _selectedDetailIds[urunId]?.clear();
      }
    });
  }

  void _onSelectDetailRow(int urunId, int txId, bool? value) {
    setState(() {
      final selected = _selectedDetailIds[urunId] ?? {};
      if (value == true) {
        selected.add(txId);
      } else {
        selected.remove(txId);
      }
      _selectedDetailIds[urunId] = selected;
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;

      // Map column index to field name
      switch (columnIndex) {
        case 1:
          _sortBy = 'id';
          break;
        case 3:
          _sortBy = 'kod';
          break;
        case 4:
          _sortBy = 'ad';
          break;
        case 5:
          _sortBy = 'stok';
          break;
        case 6:
          _sortBy = 'birim';
          break;
        case 7:
          _sortBy = 'fiyat';
          break;
        case 8:
          _sortBy = 'fiyat'; // This was 7 before, keeping 7 as price.
          // Wait, Price is 6. Index 6 -> Case 7.
          // New column is Index 7. So Case 8 is the new column (if I enabled sorting).
          // But I am disabling sorting for new column.
          // Old VAT was Index 7 -> Case 8.
          // New VAT is Index 8 -> Case 9.
          // Old Status was Index 8 -> Case 9.
          // New Status is Index 9 -> Case 10.

          // Re-evaluating indices:
          // Index 6 (Price) -> Case 7.
          // Index 7 (New Column) -> Case 8 (Sorting Disabled -> No Case needed, but subsequent indices shift).
          // Index 8 (Old VAT) -> Case 9.
          // Index 9 (Status) -> Case 10.
          break;
        case 9:
          _sortBy = 'satis_fiyati_1';
          break;
        case 10:
          _sortBy = 'aktif_mi';
          break;
        default:
          _sortBy = 'id';
      }
      _resetPagination();
    });
    _fetchUretimler();
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildDateRangeFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildStatusFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildWarehouseFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildUnitFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildGroupFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildVatFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildTransactionFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildUserFilter(width: double.infinity)),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    _closeOverlay(); // Close other overlays if any

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
        _resetPagination();
      });
      _fetchUretimler();
    }
  }

  // Old _showDateOverlay removed and replaced by _showDateRangePicker usage in _buildFilters
  // ...

  Widget _buildDateRangeFilter({double? width}) {
    final hasSelection = _startDate != null || _endDate != null;
    return InkWell(
      onTap: _showDateRangePicker,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: width ?? 240,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: hasSelection
                  ? const Color(0xFFE8F5E9)
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
                    ? '${_startDate != null ? DateFormat('dd.MM.yyyy').format(_startDate!) : ''} - ${_endDate != null ? DateFormat('dd.MM.yyyy').format(_endDate!) : ''}'
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
                onTap: () {
                  _clearDateFilter();
                  // Prevent dialog opening when clearing
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

  // ... (Keep other filter builds)

  // Add at the end of class or file (but inside class usually implies method,
  // so I'll put the class definition at the bottom of the file outside _UretimlerSayfasiState)

  Widget _buildStatusFilter({double? width}) {
    return CompositedTransformTarget(
      link: _statusLayerLink,
      child: InkWell(
        onTap: () {
          if (_isStatusFilterExpanded) {
            _closeOverlay();
          } else {
            _showStatusOverlay();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 160,
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            _isStatusFilterExpanded ? 7 : 8,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isStatusFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade300,
                width: _isStatusFilterExpanded ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list_rounded,
                size: 20,
                color: _isStatusFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedStatus == null
                      ? tr('common.status')
                      : (_selectedStatus == 'active'
                            ? '${tr('common.active')} (${_filterStats['durumlar']?['active'] ?? 0})'
                            : '${tr('common.passive')} (${_filterStats['durumlar']?['passive'] ?? 0})'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isStatusFilterExpanded
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedStatus != null)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedStatus = null;
                    });
                    _fetchUretimler();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isStatusFilterExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: _isStatusFilterExpanded
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupFilter({double? width}) {
    return CompositedTransformTarget(
      link: _groupLayerLink,
      child: InkWell(
        onTap: () {
          if (_isGroupFilterExpanded) {
            _closeOverlay();
          } else {
            _showGroupOverlay();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 160,
          padding: EdgeInsets.fromLTRB(0, 8, 0, _isGroupFilterExpanded ? 7 : 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isGroupFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade300,
                width: _isGroupFilterExpanded ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.category_outlined,
                size: 20,
                color: _isGroupFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedGroup == null
                      ? tr('productions.table.group')
                      : '${_selectedGroup!} (${_filterStats['gruplar']?[_selectedGroup] ?? 0})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isGroupFilterExpanded
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedGroup != null)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedGroup = null;
                    });
                    _fetchUretimler();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isGroupFilterExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: _isGroupFilterExpanded
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitFilter({double? width}) {
    return CompositedTransformTarget(
      link: _unitLayerLink,
      child: InkWell(
        onTap: () {
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
                      ? tr('productions.table.unit')
                      : '${_selectedUnit!} (${_filterStats['birimler']?[_selectedUnit] ?? 0})',
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
                  onTap: () {
                    setState(() {
                      _selectedUnit = null;
                    });
                    _fetchUretimler();
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
  }

  Widget _buildVatFilter({double? width}) {
    return CompositedTransformTarget(
      link: _vatLayerLink,
      child: InkWell(
        onTap: () {
          if (_isVatFilterExpanded) {
            _closeOverlay();
          } else {
            _showVatOverlay();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 160,
          padding: EdgeInsets.fromLTRB(0, 8, 0, _isVatFilterExpanded ? 7 : 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isVatFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade300,
                width: _isVatFilterExpanded ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.percent,
                size: 20,
                color: _isVatFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedVat != null
                      ? '${_formatVatLabel(_selectedVat!)} (${_vatCount(_selectedVat!)})'
                      : tr('productions.table.vat'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isVatFilterExpanded
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedVat != null)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedVat = null;
                    });
                    _fetchUretimler();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isVatFilterExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: _isVatFilterExpanded
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionFilter({double? width}) {
    return CompositedTransformTarget(
      link: _transactionLayerLink,
      child: InkWell(
        onTap: () {
          if (_isTransactionFilterExpanded) {
            _closeOverlay();
          } else {
            _showTransactionOverlay();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 180,
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
                      ? tr('accounts.table.transaction_type')
                      : '${_formatStockTransactionTypeLabel(_selectedTransactionType!)} (${_filterStats['islem_turleri']?[_selectedTransactionType] ?? 0})',
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
                  onTap: () {
                    setState(() {
                      _selectedTransactionType = null;
                    });
                    _fetchUretimler();
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
  }

  String _formatStockTransactionTypeLabel(String raw) {
    return IslemCeviriYardimcisi.cevir(
      IslemTuruRenkleri.getProfessionalLabel(raw, context: 'stock'),
    );
  }

  String _formatVatLabel(double vat) {
    final String label = vat % 1 == 0 ? vat.toInt().toString() : vat.toString();
    return '%$label';
  }

  int _vatCount(double vat) {
    final Map<String, int>? vats = _filterStats['kdvler'];
    if (vats == null || vats.isEmpty) return 0;

    final String normalizedKey = vat % 1 == 0
        ? vat.toInt().toString()
        : vat.toString();
    final int? direct = vats[normalizedKey] ?? vats[vat.toString()];
    if (direct != null) return direct;

    for (final entry in vats.entries) {
      final parsed = double.tryParse(entry.key.replaceAll(',', '.'));
      if (parsed != null && (parsed - vat).abs() < 0.000001) {
        return entry.value;
      }
    }

    return 0;
  }

  Widget _buildUserFilter({double? width}) {
    return CompositedTransformTarget(
      link: _userLayerLink,
      child: InkWell(
        onTap: () {
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
                Icons.person_rounded,
                size: 20,
                color: _isUserFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedUser == null
                      ? tr('common.user')
                      : '$_selectedUser (${_filterStats['kullanicilar']?[_selectedUser] ?? 0})',
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
                  onTap: () {
                    setState(() {
                      _selectedUser = null;
                    });
                    _fetchUretimler();
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
  }

  Widget _buildStatusOption(String? value, String label) {
    final isSelected = _selectedStatus == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (value == 'active'
              ? (_filterStats['durumlar']?['active'] ?? 0)
              : (_filterStats['durumlar']?['passive'] ?? 0));

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = value;
          _isStatusFilterExpanded = false;
          _resetPagination();
        });
        _closeOverlay();
        _fetchUretimler();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFE6F4EA) : Colors.transparent,
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF1E7E34) : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupOption(String? value, String label) {
    final isSelected = _selectedGroup == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['gruplar']?[value] ?? 0);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedGroup = value;
          _isGroupFilterExpanded = false;
          _resetPagination();
        });
        _closeOverlay();
        _fetchUretimler();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFE6F4EA) : Colors.transparent,
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF1E7E34) : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildUnitOption(String? value, String label) {
    final isSelected = _selectedUnit == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['birimler']?[value] ?? 0);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedUnit = value;
          _isUnitFilterExpanded = false;
          _resetPagination();
        });
        _closeOverlay();
        _fetchUretimler();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFE6F4EA) : Colors.transparent,
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF1E7E34) : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildVatOption(double? value, String label) {
    final isSelected = _selectedVat == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : _vatCount(value);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedVat = value;
          _isVatFilterExpanded = false;
          _resetPagination();
        });
        _closeOverlay();
        _fetchUretimler();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFE6F4EA) : Colors.transparent,
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF1E7E34) : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionOption(String? value, String label) {
    final isSelected = _selectedTransactionType == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['islem_turleri']?[value] ?? 0);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTransactionType = value;
          _isTransactionFilterExpanded = false;
          _resetPagination();
        });
        _closeOverlay();
        _fetchUretimler();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFE6F4EA) : Colors.transparent,
        child: Text(
          '${value == null ? label : _formatStockTransactionTypeLabel(value)} ($count)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF1E7E34) : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildUserOption(String? value, String label) {
    final isSelected = _selectedUser == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['kullanicilar']?[value] ?? 0);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedUser = value;
          _isUserFilterExpanded = false;
          _resetPagination();
        });
        _closeOverlay();
        _fetchUretimler();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFE6F4EA) : Colors.transparent,
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF1E7E34) : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopView(
    List<UretimModel> urunler,
    BoxConstraints constraints,
  ) {
    final bool allSelected =
        urunler.isNotEmpty && urunler.every((u) => _selectedIds.contains(u.id));

    // Calculate indices to expand based on search (matchedInHidden)
    final expandedIndices = <int>{};
    if (_searchQuery.isNotEmpty) {
      for (int i = 0; i < urunler.length; i++) {
        if (urunler[i].matchedInHidden) {
          expandedIndices.add(i);
        }
      }
    }

    // Determine if we should use flex layout or scrollable layout
    // Threshold based on sum of minimum comfortable widths
    const double minRequiredWidth = 1000;
    final bool useFlex = constraints.maxWidth >= minRequiredWidth;

    return GenisletilebilirTablo<UretimModel>(
      title: tr('productions.title'),
      searchFocusNode: _searchFocusNode,
      onClearSelection: _clearAllTableSelections,
      onFocusedRowChanged: (item, index) {
        if (item != null) {
          setState(() => _selectedRowId = item.id);
        }
      },
      headerWidget: _buildFilters(),
      totalRecords: _totalRecords,
      getDetailItemCount: (urun) =>
          _visibleTransactionIds[urun.id]?.length ?? 0,
      expandedContentPadding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 0,
      ),
      onSort: _onSort,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      onPageChanged: (page, rowsPerPage) {
        setState(() {
          _currentPage = page;
          _rowsPerPage = rowsPerPage;
        });
        _fetchUretimler();
      },
      onSearch: (query) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          setState(() {
            _searchQuery = query;
            _resetPagination();
          });
          _fetchUretimler(showLoading: false);
        });
      },
      selectionWidget: _selectedIds.isNotEmpty
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _deleteSelectedUrunler,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                      const SizedBox(width: 4),
                      Text(
                        tr(
                          'common.delete_selected',
                        ).replaceAll('{count}', _selectedIds.length.toString()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
      expandAll: _keepDetailsOpen,
      expandedIndices: expandedIndices,
      onExpansionChanged: (index, isExpanded) {
        setState(() {
          if (isExpanded) {
            _manualExpandedIndex = index;
          } else if (_manualExpandedIndex == index) {
            _manualExpandedIndex = null;
          }
        });
      },
      extraWidgets: [
        Tooltip(
          message: tr('warehouses.keep_details_open'),
          child: InkWell(
            onTap: _toggleKeepDetailsOpen,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: _keepDetailsOpen
                    ? const Color(0xFF2C3E50).withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _keepDetailsOpen
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade300,
                ),
              ),
              child: Icon(
                _keepDetailsOpen
                    ? Icons.unfold_less_rounded
                    : Icons.unfold_more_rounded,
                color: _keepDetailsOpen
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
      ],
      actionButton: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
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
                      _selectedIds.isNotEmpty ||
                              _selectedDetailIds.values.any((s) => s.isNotEmpty)
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
            ),
          ),
          const SizedBox(width: 12),
          Theme(
            data: Theme.of(context).copyWith(
              dividerTheme: const DividerThemeData(
                color: Color(0xFFEEEEEE),
                thickness: 1,
              ),
              popupMenuTheme: PopupMenuThemeData(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                elevation: 6,
              ),
            ),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 45),
              tooltip: tr('common.actions'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: true,
                  value: 'make_production',
                  height: 44,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.precision_manufacturing_rounded,
                        size: 20,
                        color: const Color(0xFF4A4A4A),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        tr('productions.actions.make_production'),
                        style: TextStyle(
                          color: const Color(0xFF4A4A4A),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        tr('common.key.f10'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  enabled: false,
                  height: 1,
                  padding: EdgeInsets.zero,
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFEEEEEE),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'change_prices',
                  height: 44,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.price_change_outlined,
                        size: 20,
                        color: Color(0xFF4A4A4A),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        tr('productions.actions.change_prices'),
                        style: const TextStyle(
                          color: Color(0xFF4A4A4A),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        tr('common.key.f11'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  enabled: false,
                  height: 1,
                  padding: EdgeInsets.zero,
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFEEEEEE),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'change_vat',
                  height: 44,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.percent_rounded,
                        size: 20,
                        color: Color(0xFF4A4A4A),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        tr('productions.actions.change_vat'),
                        style: const TextStyle(
                          color: Color(0xFF4A4A4A),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        tr('common.key.f12'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'make_production') {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UretimYapSayfasi(),
                    ),
                  );

                  if (result == true) {
                    _fetchUretimler();
                  }
                } else if (value == 'change_prices') {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => const FiyatlariDegistirDialog(),
                  );
                  if (result == true) {
                    _fetchUretimler();
                  }
                } else if (value == 'change_vat') {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => const KdvleriDegistirDialog(),
                  );
                  if (result == true) {
                    _fetchUretimler();
                  }
                } else {
                  MesajYardimcisi.bilgiGoster(
                    context,
                    '$value ${tr('common.feature_coming_soon_suffix')}',
                  );
                }
              },
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF39C12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.transparent),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('common.actions'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _showAddDialog,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA4335),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.transparent),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      tr('productions.add'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr('common.key.f1'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      columns: [
        GenisletilebilirTabloKolon(
          label: '',
          width: 50,
          alignment: Alignment.center,
          header: SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: allSelected,
              onChanged: _onSelectAll,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
            ),
          ),
        ),
        if (_columnVisibility['order_no'] == true)
          GenisletilebilirTabloKolon(
            label: tr('language.table.orderNo'),
            width: 130,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['code'] == true)
          GenisletilebilirTabloKolon(
            label: tr('productions.table.code'),
            width: 180,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['name'] == true)
          GenisletilebilirTabloKolon(
            label: tr('productions.table.name'),
            width: 160,
            alignment: Alignment.centerLeft,
            allowSorting: true,
            flex: useFlex ? 2 : null,
          ),
        if (_columnVisibility['stock'] == true)
          GenisletilebilirTabloKolon(
            label: tr('productions.table.stock'),
            width: 70,
            alignment: Alignment.centerRight,
            allowSorting: true,
            flex: useFlex ? 1 : null,
          ),
        if (_columnVisibility['unit'] == true)
          GenisletilebilirTabloKolon(
            label: tr('productions.table.unit'),
            width: 50,
            alignment: Alignment.centerLeft,
            allowSorting: true,
            flex: useFlex ? 1 : null,
          ),
        if (_columnVisibility['cost_price'] == true)
          GenisletilebilirTabloKolon(
            label: tr('productions.table.cost_price'),
            width: 160,
            alignment: Alignment.centerRight,
            allowSorting: true,
          ),
        if (_columnVisibility['vat'] == true)
          GenisletilebilirTabloKolon(
            label: tr('productions.table.vat'),
            width: 120,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['status'] == true)
          GenisletilebilirTabloKolon(
            label: tr('productions.table.status'),
            width: 130,
            alignment: Alignment.centerLeft,
            allowSorting: true,
            flex: useFlex ? 1 : null,
          ),
        GenisletilebilirTabloKolon(
          label: tr('productions.table.actions'),
          width: 110,
          alignment: Alignment.centerLeft,
        ),
      ],

      data: urunler,
      isRowSelected: (urun, index) => _selectedRowId == urun.id,

      expandOnRowTap: false,
      onRowTap: (urun) {
        setState(() {
          _selectedRowId = urun.id;
        });
      },
      rowBuilder: (context, urun, index, isExpanded, toggleExpand) {
        return Row(
          children: [
            _buildCell(
              width: 50,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _selectedIds.contains(urun.id),
                  onChanged: (val) => _onSelectRow(val, urun.id),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
                ),
              ),
            ),
            if (_columnVisibility['order_no'] == true)
              _buildCell(
                width: 130,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    InkWell(
                      onTap: toggleExpand,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: AnimatedRotation(
                          turns: isExpanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    HighlightText(
                      text: urun.id.toString(),
                      query: _searchQuery,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            if (_columnVisibility['code'] == true)
              _buildCell(
                width: 180,
                child: HighlightText(
                  text: urun.kod,
                  query: _searchQuery,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (_columnVisibility['name'] == true)
              _buildCell(
                width: 160,
                flex: useFlex ? 2 : null,
                child: HighlightText(
                  text: urun.ad,
                  query: _searchQuery,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_columnVisibility['stock'] == true)
              _buildCell(
                width: 80,
                flex: useFlex ? 1 : null,
                alignment: Alignment.centerRight,
                child: HighlightText(
                  text: FormatYardimcisi.sayiFormatla(
                    urun.stok,
                    binlik: _genelAyarlar.binlikAyiraci,
                    ondalik: _genelAyarlar.ondalikAyiraci,
                    decimalDigits: _genelAyarlar.miktarOndalik,
                  ),
                  query: _searchQuery,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (_columnVisibility['unit'] == true)
              _buildCell(
                width: 50,
                flex: useFlex ? 1 : null,
                child: Text(
                  urun.birim,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),
            if (_columnVisibility['cost_price'] == true)
              _buildCell(
                width: 160,
                alignment: Alignment.centerRight,
                child: FutureBuilder<double>(
                  future: urun.alisFiyati > 0
                      ? Future.value(urun.alisFiyati)
                      : _costFutures.putIfAbsent(
                          urun.id,
                          () => UretimlerVeritabaniServisi()
                              .calculateEstimatedUnitCost(urun.id),
                        ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    final cost = snapshot.data ?? 0.0;
                    String formatted = FormatYardimcisi.sayiFormatlaOndalikli(
                      cost,
                      binlik: _genelAyarlar.binlikAyiraci,
                      ondalik: _genelAyarlar.ondalikAyiraci,
                      decimalDigits: _genelAyarlar.fiyatOndalik,
                    );
                    if (_genelAyarlar.sembolGoster) {
                      formatted += ' ${_genelAyarlar.varsayilanParaBirimi}';
                    }

                    return HighlightText(
                      text: formatted,
                      query: _searchQuery,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                    );
                  },
                ),
              ),
            if (_columnVisibility['vat'] == true)
              _buildCell(
                width: 120,
                alignment: Alignment.centerLeft,
                child: HighlightText(
                  text:
                      '%${FormatYardimcisi.sayiFormatlaOran(urun.kdvOrani, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: 2)}',
                  query: _searchQuery,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),

            if (_columnVisibility['status'] == true)
              _buildCell(
                width: 130,
                flex: useFlex ? 1 : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: urun.aktifMi
                        ? const Color(0xFFE6F4EA)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: urun.aktifMi
                              ? const Color(0xFF28A745)
                              : const Color(0xFF757575),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          urun.aktifMi
                              ? tr('common.active')
                              : tr('common.passive'),
                          style: TextStyle(
                            color: urun.aktifMi
                                ? const Color(0xFF1E7E34)
                                : const Color(0xFF757575),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            _buildCell(width: 110, child: _buildPopupMenu(urun)),
          ],
        );
      },
      detailBuilder: (context, urun) {
        final selectedIds = _selectedDetailIds[urun.id] ?? {};
        final visibleIds = _visibleTransactionIds[urun.id] ?? [];
        final allSelected =
            visibleIds.isNotEmpty && selectedIds.length == visibleIds.length;

        // Üretim ilk harfi (depolar gibi avatar için)
        final String firstChar = urun.ad.isNotEmpty
            ? urun.ad[0].toUpperCase()
            : '?';

        return Container(
          padding: const EdgeInsets.only(
            left: 60,
            right: 24,
            top: 24,
            bottom: 24,
          ),
          color: Colors.grey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. White Box: Header Info + Stock Summary + Features
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER: Image + Info + Stock Summary
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Üretim Resimleri veya Avatar
                        if (urun.resimler.isNotEmpty)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: urun.resimler.map((img) {
                                final imageProvider = _resolveImageProvider(
                                  img,
                                );
                                return Container(
                                  width: 60,
                                  height: 60,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                    image: DecorationImage(
                                      image: imageProvider,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          )
                        else if (urun.resimUrl != null)
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                              image: DecorationImage(
                                image: _resolveImageProvider(urun.resimUrl!),
                                fit: BoxFit.contain,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                firstChar,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 14),
                        // Info Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              HighlightText(
                                text: urun.ad,
                                query: _searchQuery,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: HighlightText(
                                      text: urun.kod,
                                      query: _searchQuery,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (urun.grubu.isNotEmpty) ...[
                                    Icon(
                                      Icons.category_outlined,
                                      size: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    HighlightText(
                                      text: urun.grubu,
                                      query: _searchQuery,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Toplam Stok Chip
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: urun.stok >= 0
                                          ? const Color(0xFFE6F4EA)
                                          : const Color(0xFFF8D7DA),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          tr('warehouses.detail.total_stock'),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        HighlightText(
                                          text: FormatYardimcisi.sayiFormatla(
                                            urun.stok,
                                            binlik: _genelAyarlar.binlikAyiraci,
                                            ondalik:
                                                _genelAyarlar.ondalikAyiraci,
                                            decimalDigits:
                                                _genelAyarlar.miktarOndalik,
                                          ),
                                          query: _searchQuery,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: urun.stok >= 0
                                                ? const Color(0xFF059669)
                                                : const Color(0xFFC62828),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          urun.birim,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF64748B),
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
                        // Stok Özet Table View (Sağ Üst Köşe) - FutureBuilder ile
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _detailFutures.putIfAbsent(
                            urun.id,
                            () => DepolarVeritabaniServisi()
                                .urunHareketleriniGetir(
                                  urun.kod,
                                  kdvOrani: urun.kdvOrani,
                                  baslangicTarihi: _startDate,
                                  bitisTarihi: _endDate,
                                  warehouseIds: _selectedWarehouse != null
                                      ? [_selectedWarehouse!.id]
                                      : null,
                                  islemTuru: _selectedTransactionType,
                                  kullanici: _selectedUser,
                                ),
                          ),
                          builder: (context, snapshot) {
                            double toplamGirdi = 0;
                            double toplamCikti = 0;

                            if (snapshot.hasData) {
                              for (final tx in snapshot.data!) {
                                final qty = (tx['quantity'] is num)
                                    ? (tx['quantity'] as num).toDouble()
                                    : double.tryParse(
                                            tx['quantity'].toString(),
                                          ) ??
                                          0.0;
                                if (tx['isIncoming'] == true) {
                                  toplamGirdi += qty;
                                } else {
                                  toplamCikti += qty;
                                }
                              }
                            }

                            // [FIX] User Request: Widen summary box to prevent text wrapping
                            return Container(
                              width: 220,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          tr('common.total'),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 70,
                                        child: Text(
                                          tr('warehouses.detail.quantity'),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Girdi Row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          tr('products.transaction.type.input'),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 70,
                                        child: Text(
                                          FormatYardimcisi.sayiFormatla(
                                            toplamGirdi,
                                            binlik: _genelAyarlar.binlikAyiraci,
                                            ondalik:
                                                _genelAyarlar.ondalikAyiraci,
                                            decimalDigits:
                                                _genelAyarlar.miktarOndalik,
                                          ),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  // Çıktı Row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          tr(
                                            'products.transaction.type.output',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 70,
                                        child: Text(
                                          FormatYardimcisi.sayiFormatla(
                                            toplamCikti,
                                            binlik: _genelAyarlar.binlikAyiraci,
                                            ondalik:
                                                _genelAyarlar.ondalikAyiraci,
                                            decimalDigits:
                                                _genelAyarlar.miktarOndalik,
                                          ),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFC62828),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 4.0,
                                    ),
                                    child: Divider(
                                      height: 1,
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  // Toplam Row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          tr('warehouses.detail.total_stock'),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 70,
                                        child: Text(
                                          FormatYardimcisi.sayiFormatla(
                                            urun.stok,
                                            binlik: _genelAyarlar.binlikAyiraci,
                                            ondalik:
                                                _genelAyarlar.ondalikAyiraci,
                                            decimalDigits:
                                                _genelAyarlar.miktarOndalik,
                                          ),
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: urun.stok >= 0
                                                ? const Color(0xFF059669)
                                                : const Color(0xFFC62828),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),
                    // FEATURES Section (Özellikler)
                    Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        _buildDetailItem(
                          tr('productions.table.barcode'),
                          urun.barkod.isNotEmpty ? urun.barkod : '-',
                        ),
                        _buildDetailItem(
                          tr('productions.table.alert_qty'),
                          '${FormatYardimcisi.sayiFormatla(urun.erkenUyariMiktari, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.miktarOndalik)} ${urun.birim}',
                        ),
                        _buildDetailItem(
                          tr('productions.table.sales_price_1'),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              HighlightText(
                                text:
                                    '${FormatYardimcisi.sayiFormatlaOndalikli(urun.satisFiyati1, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ₺',
                                query: _searchQuery,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${tr('common.vat_excluded')})',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildDetailItem(
                          tr('productions.table.sales_price_2'),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              HighlightText(
                                text:
                                    '${FormatYardimcisi.sayiFormatlaOndalikli(urun.satisFiyati2, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ₺',
                                query: _searchQuery,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${tr('common.vat_excluded')})',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildDetailItem(
                          tr('productions.table.sales_price_3'),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              HighlightText(
                                text:
                                    '${FormatYardimcisi.sayiFormatlaOndalikli(urun.satisFiyati3, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ₺',
                                query: _searchQuery,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${tr('common.vat_excluded')})',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildDetailItem(
                          'Maliyet fiyatı',
                          FutureBuilder<double>(
                            future: urun.alisFiyati > 0
                                ? Future.value(urun.alisFiyati)
                                : UretimlerVeritabaniServisi()
                                      .calculateEstimatedUnitCost(urun.id),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              }
                              final cost = snapshot.data ?? 0.0;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${FormatYardimcisi.sayiFormatlaOndalikli(cost, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ₺',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (urun.alisFiyati <= 0)
                                    Text(
                                      tr('productions.cost_method.fifo_short'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  else
                                    Text(
                                      tr(
                                        'productions.cost_method.manual_short',
                                      ),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                        _buildDetailItem(
                          tr('productions.table.user'),
                          urun.kullanici.isNotEmpty ? urun.kullanici : '-',
                        ),
                        _buildDetailItem(
                          tr('productions.table.features'),
                          _buildFeaturesContent(urun.ozellikler),
                        ),
                        // Reçete Butonu
                        SizedBox(
                          width: 200,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('productions.recipe.title'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () => _showRecipeDialog(urun),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFFFE0B2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.visibility_outlined,
                                        size: 14,
                                        color: Color(0xFFE65100),
                                      ),
                                      const SizedBox(width: 6),
                                      FutureBuilder<List<Map<String, dynamic>>>(
                                        future: UretimlerVeritabaniServisi()
                                            .receteGetir(urun.id),
                                        builder: (context, snapshot) {
                                          final count =
                                              snapshot.data?.length ?? 0;
                                          return Text(
                                            '($count ${tr('common.product')})',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFFE65100),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
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
              ),
              const SizedBox(height: 24),

              // Transactions Table Header
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: allSelected,
                      onChanged: (val) => _onSelectAllDetails(urun.id, val),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: const BorderSide(
                        color: Color(0xFFD1D1D1),
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    tr('productions.detail.transactions'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Transactions Table Header Row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 36), // Checkbox space
                    if (_columnVisibility['dt_type'] == true)
                      Expanded(
                        flex: 6, // 5 -> 6
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 22,
                            ), // Align with text in row (Icon width + spacing)
                            Expanded(
                              child: _buildDetailHeader(
                                tr('productions.transaction.type'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_columnVisibility['dt_related_account'] == true) ...[
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 6, // Related Account
                        child: _buildDetailHeader(
                          tr('warehouses.detail.related_account'),
                        ),
                      ),
                    ],
                    if (_columnVisibility['dt_date'] == true)
                      Expanded(
                        flex: 5,
                        child: _buildDetailHeader(
                          tr('productions.transaction.date'),
                        ),
                      ),
                    if (_columnVisibility['dt_warehouse'] == true)
                      Expanded(
                        flex: 3,
                        child: _buildDetailHeader(
                          tr('productions.transaction.warehouse'),
                        ),
                      ),
                    if (_columnVisibility['dt_quantity'] == true)
                      Expanded(
                        flex: 2,
                        child: _buildDetailHeader(
                          tr('productions.transaction.quantity'),
                          alignRight: true,
                        ),
                      ),
                    if (_columnVisibility['dt_unit'] == true) ...[
                      const SizedBox(
                        width: 12,
                      ), // Space between Quantity and Unit
                      Expanded(
                        flex: 2,
                        child: _buildDetailHeader(tr('productions.table.unit')),
                      ),
                    ],
                    if (_columnVisibility['dt_unit_price'] == true)
                      Expanded(
                        flex: 7,
                        child: _buildDetailHeader(
                          tr('productions.transaction.unit_price'),
                          alignRight: true,
                        ),
                      ),
                    if (_columnVisibility['dt_unit_price_vd'] == true) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 6,
                        child: _buildDetailHeader(
                          tr('productions.transaction.unit_price_vd'),
                          alignRight: true,
                        ),
                      ),
                    ],
                    if (_columnVisibility['dt_total_price'] == true) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 7,
                        child: _buildDetailHeader(
                          tr('common.total'),
                          alignRight: true,
                        ),
                      ),
                    ],
                    if (_columnVisibility['dt_description'] == true) ...[
                      const SizedBox(
                        width: 48,
                      ), // Space between Unit and Description
                      Expanded(
                        flex: 8,
                        child: _buildDetailHeader(tr('common.description')),
                      ),
                    ],
                    if (_columnVisibility['dt_user'] == true) ...[
                      const SizedBox(
                        width: 24,
                      ), // Spacing between Description and User
                      Expanded(
                        flex: 3,
                        child: _buildDetailHeader(tr('warehouses.detail.user')),
                      ),
                    ],
                    const SizedBox(width: 80), // Extra spacing before Actions
                    const SizedBox(width: 120), // Actions space
                  ],
                ),
              ),

              // Transactions List
              FutureBuilder<List<Map<String, dynamic>>>(
                key: ValueKey(
                  '${urun.id}_$_refreshKey',
                ), // Force rebuild on refresh
                future: _detailFutures.putIfAbsent(
                  urun.id,
                  () => DepolarVeritabaniServisi().urunHareketleriniGetir(
                    urun.kod,
                    kdvOrani: urun.kdvOrani,
                    baslangicTarihi: _startDate,
                    bitisTarihi: _endDate,
                    warehouseIds: _selectedWarehouse != null
                        ? [_selectedWarehouse!.id]
                        : null,
                    islemTuru: _selectedTransactionType,
                    kullanici: _selectedUser,
                  ),
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text('${tr('common.error')}: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Text(
                          tr('common.no_data'),
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    );
                  }

                  final transactions = snapshot.data!;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _visibleTransactionIds[urun.id] = transactions
                          .map((t) => t['id'] as int)
                          .toList();
                    }
                  });

                  return Column(
                    children: transactions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final tx = entry.value;
                      final isLast = index == transactions.length - 1;
                      final val = selectedIds.contains(tx['id']);
                      final createdBy = tx['user'] as String?;

                      final focusScope = TableDetailFocusScope.of(context);
                      final isFocused = focusScope?.focusedDetailIndex == index;

                      return Column(
                        children: [
                          _buildTransactionRow(
                            id: tx['id'],
                            isSelected: val,
                            isFocused: isFocused,
                            onChanged: (val) =>
                                _onSelectDetailRow(urun.id, tx['id'], val),
                            onTap: () {
                              focusScope?.setFocusedDetailIndex?.call(index);
                              // Seçili detay transaction bilgisini kaydet
                              setState(() {
                                _selectedDetailTransactionId = tx['id'];
                                _selectedDetailCustomTypeLabel =
                                    tx['customTypeLabel'];
                                _selectedDetailUretim = urun;
                              });
                            },
                            isIncoming: tx['isIncoming'],
                            date: tx['date'],
                            warehouse: tx['warehouse'],
                            quantity: tx['quantity'] ?? 0,
                            unit: urun.birim,
                            unitPrice: tx['unitPrice'],
                            unitPriceVat: tx['unitPriceVat'],
                            description: tx['description']?.toString() ?? '',
                            user: (createdBy ?? '').isEmpty
                                ? 'Sistem'
                                : createdBy!,
                            customTypeLabel: tx['customTypeLabel'],
                            sourceSuffix: tx['sourceSuffix']?.toString(),
                            showActions: true,
                            urun: urun,
                            relatedAccount: tx['relatedPartyName'] as String?,
                          ),
                          if (!isLast)
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFEEEEEE),
                            ),
                        ],
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    if (value is String && value.isEmpty) return const SizedBox.shrink();

    // If widget (e.g. Color chips in Features), render as is
    if (value is Widget) {
      return SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            value,
          ],
        ),
      );
    }

    String displayValue = value.toString();

    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          HighlightText(
            text: displayValue,
            query: _searchQuery,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider _resolveImageProvider(String raw) {
    if (_imageCache.containsKey(raw)) {
      return _imageCache[raw]!;
    }

    final img = raw.trim();
    if (img.isEmpty) {
      final provider = const AssetImage('assets/images/placeholder.png');
      _imageCache[raw] = provider;
      return provider;
    }

    if (img.startsWith('http')) {
      final provider = NetworkImage(img);
      _imageCache[raw] = provider;
      return provider;
    }

    final normalized = _stripDataUriPrefix(img).replaceAll(RegExp(r'\s'), '');
    try {
      final provider = MemoryImage(base64Decode(normalized));
      _imageCache[raw] = provider;
      return provider;
    } catch (_) {
      try {
        final provider = MemoryImage(base64Url.decode(normalized));
        _imageCache[raw] = provider;
        return provider;
      } catch (_) {
        final provider = const AssetImage('assets/images/placeholder.png');
        _imageCache[raw] = provider;
        return provider;
      }
    }
  }

  String _stripDataUriPrefix(String value) {
    if (!value.startsWith('data:image')) return value;
    final commaIndex = value.indexOf(',');
    if (commaIndex == -1) return value;
    return value.substring(commaIndex + 1);
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
              child: HighlightText(
                text: name,
                query: _searchQuery,
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
        fontSize: 14,
        color: Colors.black87,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildDetailHeader(String text, {bool alignRight = false}) {
    return Text(
      text,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Future<void> _showRecipeDialog(UretimModel urun) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) =>
          ProductionRecipeDialog(uretim: urun, genelAyarlar: _genelAyarlar),
    );
  }

  Widget _buildMobileActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required Color borderColor,
    required VoidCallback onTap,
    bool hasDropdown = false,
    double height = 48,
    double iconSize = 20,
    double fontSize = 14,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16),
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: textColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize,
                  ),
                ),
              ),
              if (hasDropdown) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: iconSize > 4 ? iconSize - 2 : iconSize,
                  color: textColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileSquareActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required Color iconColor,
    Color borderColor = Colors.transparent,
    double size = 40,
    String? tooltip,
  }) {
    Widget child = Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );

    if (tooltip == null || tooltip.isEmpty) {
      return child;
    }

    return Tooltip(message: tooltip, child: child);
  }

  int _getActiveMobileFilterCount() {
    int count = 0;
    if (_searchController.text.trim().isNotEmpty) count++;
    if (_startDate != null || _endDate != null) count++;
    if (_selectedStatus != null) count++;
    if (_selectedWarehouse != null) count++;
    if (_selectedUnit != null) count++;
    if (_selectedGroup != null) count++;
    if (_selectedVat != null) count++;
    if (_selectedTransactionType != null) count++;
    if (_selectedUser != null) count++;
    return count;
  }

  Future<void> _handleMobileActionMenuSelection(String value) async {
    if (value == 'make_production') {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const UretimYapSayfasi()),
      );
      if (result == true) {
        _fetchUretimler();
      }
      return;
    }

    if (value == 'change_prices') {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => const FiyatlariDegistirDialog(),
      );
      if (result == true) {
        _fetchUretimler();
      }
      return;
    }

    if (value == 'change_vat') {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => const KdvleriDegistirDialog(),
      );
      if (result == true) {
        _fetchUretimler();
      }
      return;
    }

    MesajYardimcisi.bilgiGoster(
      context,
      '$value ${tr('common.feature_coming_soon_suffix')}',
    );
  }

  Widget _buildMobileActionsMenuButton({double size = 48}) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEEEEEE),
          thickness: 1,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          elevation: 6,
        ),
      ),
      child: PopupMenuButton<String>(
        offset: Offset(0, size),
        tooltip: tr('common.actions'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: true,
            value: 'make_production',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.precision_manufacturing_rounded,
                  size: 20,
                  color: Color(0xFF4A4A4A),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('productions.actions.make_production'),
                  style: const TextStyle(
                    color: Color(0xFF4A4A4A),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            enabled: false,
            height: 1,
            padding: EdgeInsets.zero,
            child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          ),
          PopupMenuItem<String>(
            value: 'change_prices',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.price_change_outlined,
                  size: 20,
                  color: Color(0xFF4A4A4A),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('productions.actions.change_prices'),
                  style: const TextStyle(
                    color: Color(0xFF4A4A4A),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            enabled: false,
            height: 1,
            padding: EdgeInsets.zero,
            child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          ),
          PopupMenuItem<String>(
            value: 'change_vat',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.percent_rounded,
                  size: 20,
                  color: Color(0xFF4A4A4A),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('productions.actions.change_vat'),
                  style: const TextStyle(
                    color: Color(0xFF4A4A4A),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
        onSelected: (value) =>
            unawaited(_handleMobileActionMenuSelection(value)),
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: const Color(0xFFF39C12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.bolt_rounded,
            size: size < 44 ? 20 : 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileTopActionRow() {
    final double width = MediaQuery.of(context).size.width;
    final bool isNarrow = width < 360;

    final String addLabel = isNarrow ? 'Ekle' : tr('products.add');
    final String printTooltip =
        _selectedIds.isNotEmpty ||
            _selectedDetailIds.values.any((s) => s.isNotEmpty)
        ? tr('common.print_selected')
        : tr('common.print_list');

    return Row(
      children: [
        _buildMobileActionsMenuButton(size: 40),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMobileActionButton(
            label: addLabel,
            icon: Icons.add,
            color: const Color(0xFFEA4335),
            textColor: Colors.white,
            borderColor: Colors.transparent,
            onTap: _showAddDialog,
            height: 40,
            iconSize: 16,
            fontSize: 12,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        const SizedBox(width: 8),
        _buildMobileSquareActionButton(
          icon: Icons.print_outlined,
          onTap: _handlePrint,
          color: const Color(0xFFF8F9FA),
          iconColor: Colors.black87,
          borderColor: Colors.grey.shade300,
          tooltip: printTooltip,
          size: 40,
        ),
      ],
    );
  }

  Widget _buildMobileFilterGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool singleColumn = constraints.maxWidth < 360;

        if (singleColumn) {
          return Column(
            children: [
              _buildDateRangeFilter(width: double.infinity),
              const SizedBox(height: 12),
              _buildStatusFilter(width: double.infinity),
              const SizedBox(height: 12),
              _buildWarehouseFilter(width: double.infinity),
              const SizedBox(height: 12),
              _buildUnitFilter(width: double.infinity),
              const SizedBox(height: 12),
              _buildGroupFilter(width: double.infinity),
              const SizedBox(height: 12),
              _buildVatFilter(width: double.infinity),
              const SizedBox(height: 12),
              _buildTransactionFilter(width: double.infinity),
              const SizedBox(height: 12),
              _buildUserFilter(width: double.infinity),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildDateRangeFilter(width: double.infinity)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatusFilter(width: double.infinity)),
                const SizedBox(width: 12),
                Expanded(child: _buildWarehouseFilter(width: double.infinity)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildUnitFilter(width: double.infinity)),
                const SizedBox(width: 12),
                Expanded(child: _buildGroupFilter(width: double.infinity)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildVatFilter(width: double.infinity)),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTransactionFilter(width: double.infinity),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildUserFilter(width: double.infinity)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileToolbarCard({
    required int totalRecords,
    required double maxExpandedHeight,
  }) {
    final int activeFilterCount = _getActiveMobileFilterCount();
    final bool hasSelection = _selectedIds.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() {
                _isMobileToolbarExpanded = !_isMobileToolbarExpanded;
              });
              if (!_isMobileToolbarExpanded) {
                _closeOverlay();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool compact = constraints.maxWidth < 330;
                  final String toggleLabel = compact
                      ? (_isMobileToolbarExpanded ? 'Gizle' : 'Göster')
                      : (_isMobileToolbarExpanded
                            ? 'Filtreleri Gizle'
                            : 'Filtreleri Göster');

                  return Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2C3E50,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalRecords kayıt',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeFilterCount == 0
                                  ? 'Filtre yok'
                                  : '$activeFilterCount filtre aktif',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        toggleLabel,
                        style: const TextStyle(
                          color: Color(0xFF2C3E50),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _isMobileToolbarExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            child: !_isMobileToolbarExpanded
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      Divider(height: 1, color: Colors.grey.shade200),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: maxExpandedHeight,
                        ),
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: _rowsPerPage,
                                        items: [10, 25, 50, 100]
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(e.toString()),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) {
                                          if (val == null) return;
                                          setState(() {
                                            _rowsPerPage = val;
                                            _resetPagination();
                                          });
                                          _fetchUretimler(showLoading: false);
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      textInputAction: TextInputAction.search,
                                      decoration: InputDecoration(
                                        hintText: tr('common.search'),
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          color: Colors.grey,
                                        ),
                                        border: const UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.grey,
                                          ),
                                        ),
                                        enabledBorder:
                                            const UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Colors.grey,
                                              ),
                                            ),
                                        focusedBorder:
                                            const UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Color(0xFF2C3E50),
                                              ),
                                            ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                        filled: false,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (hasSelection)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: _deleteSelectedUrunler,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEA4335),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            tr(
                                              'common.delete_selected',
                                            ).replaceAll(
                                              '{count}',
                                              _selectedIds.length.toString(),
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              _buildMobileFilterGrid(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView(List<UretimModel> filteredUrunler) {
    final int totalRecords = _totalRecords > 0
        ? _totalRecords
        : filteredUrunler.length;
    final int safeRowsPerPage = _rowsPerPage <= 0 ? 25 : _rowsPerPage;
    final int totalPages = totalRecords == 0
        ? 1
        : (totalRecords / safeRowsPerPage).ceil();
    final int effectivePage = _currentPage.clamp(1, totalPages);
    if (effectivePage != _currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentPage = effectivePage;
          });
          _fetchUretimler(showLoading: false);
        }
      });
    }

    final int startRecordIndex = (effectivePage - 1) * safeRowsPerPage;
    final int endRecord = totalRecords == 0
        ? 0
        : (startRecordIndex + filteredUrunler.length).clamp(0, totalRecords);
    final int showingStart = totalRecords == 0 ? 0 : startRecordIndex + 1;

    final mediaQuery = MediaQuery.of(context);
    final bool isKeyboardVisible = mediaQuery.viewInsets.bottom > 0;
    final double availableHeight =
        mediaQuery.size.height -
        mediaQuery.padding.vertical -
        mediaQuery.viewInsets.bottom;
    final double maxExpandedHeight = (availableHeight * 0.5).clamp(
      180.0,
      420.0,
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    tr('productions.title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _buildMobileToolbarCard(
                totalRecords: totalRecords,
                maxExpandedHeight: maxExpandedHeight,
              ),
            ),
            if (!isKeyboardVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildMobileTopActionRow(),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: filteredUrunler.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildUretimCard(filteredUrunler[index]);
                },
              ),
            ),
            if (!isKeyboardVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: effectivePage > 1
                          ? () {
                              setState(() => _currentPage = effectivePage - 1);
                              _fetchUretimler(showLoading: false);
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        tr('common.pagination.showing')
                            .replaceAll('{start}', showingStart.toString())
                            .replaceAll('{end}', endRecord.toString())
                            .replaceAll('{total}', totalRecords.toString()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: effectivePage < totalPages
                          ? () {
                              setState(() => _currentPage = effectivePage + 1);
                              _fetchUretimler(showLoading: false);
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUretimCard(UretimModel urun) {
    final isExpanded = _expandedMobileIds.contains(urun.id);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _selectedIds.contains(urun.id),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedIds.add(urun.id);
                      } else {
                        _selectedIds.remove(urun.id);
                      }
                    });
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFFD1D1D1)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      urun.ad,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${urun.kod} • ${urun.grubu}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Price and Stock
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${FormatYardimcisi.sayiFormatlaOndalikli(urun.satisFiyati1, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ₺',
                          style: const TextStyle(
                            color: Color(0xFF2C3E50),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${FormatYardimcisi.sayiFormatla(urun.stok, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.miktarOndalik)} ${urun.birim}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [_buildPopupMenu(urun)],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status & Expand
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: urun.aktifMi
                      ? const Color(0xFFE6F4EA)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  urun.aktifMi ? tr('common.active') : tr('common.passive'),
                  style: TextStyle(
                    color: urun.aktifMi
                        ? const Color(0xFF1E7E34)
                        : const Color(0xFF757575),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF2C3E50),
                ),
                onPressed: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedMobileIds.remove(urun.id);
                    } else {
                      _expandedMobileIds.add(urun.id);
                    }
                  });
                },
              ),
            ],
          ),
          // Details
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    children: [
                      const Divider(height: 24),
                      _buildMobileDetails(urun),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDetails(UretimModel urun) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Images
        if (urun.resimler.isNotEmpty || urun.resimUrl != null) ...[
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (urun.resimler.isNotEmpty)
                  ...urun.resimler.map((img) {
                    final imageProvider = _resolveImageProvider(img);
                    return Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                        image: DecorationImage(
                          image: imageProvider,
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  })
                else if (urun.resimUrl != null)
                  Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                      image: DecorationImage(
                        image: _resolveImageProvider(urun.resimUrl!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Properties
        _buildMobileProperty(
          tr('productions.table.group'),
          urun.grubu.isNotEmpty ? urun.grubu : '-',
        ),
        _buildMobileProperty(tr('products.table.barcode'), urun.barkod),
        _buildMobileProperty(
          tr('products.table.purchase_price'),
          '${FormatYardimcisi.sayiFormatlaOndalikli(urun.alisFiyati, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ₺',
        ),
        _buildMobileProperty(
          tr('products.table.sales_price_1'),
          '${FormatYardimcisi.sayiFormatlaOndalikli(urun.satisFiyati1, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ₺',
        ),
        _buildMobileProperty(
          tr('products.table.sales_price_2'),
          '${FormatYardimcisi.sayiFormatlaOndalikli(urun.satisFiyati2, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ₺',
        ),
        _buildMobileProperty(
          tr('products.table.sales_price_3'),
          '${FormatYardimcisi.sayiFormatlaOndalikli(urun.satisFiyati3, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ₺',
        ),
        _buildMobileProperty(
          tr('products.table.alert_qty'),
          '${FormatYardimcisi.sayiFormatla(urun.erkenUyariMiktari, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.miktarOndalik)} ${urun.birim}',
        ),
        _buildMobileProperty(tr('productions.table.user'), urun.kullanici),

        // Features
        if (urun.ozellikler.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            tr('productions.table.features'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          _buildFeaturesContent(urun.ozellikler),
        ],
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          tr('products.detail.transactions'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: DepolarVeritabaniServisi().urunHareketleriniGetir(
            urun.kod,
            kdvOrani: urun.kdvOrani,
            baslangicTarihi: _startDate,
            bitisTarihi: _endDate,
            warehouseIds: _selectedWarehouse != null
                ? [_selectedWarehouse!.id]
                : null,
            islemTuru: _selectedTransactionType,
            kullanici: _selectedUser,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('${tr('common.error')}: ${snapshot.error}');
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Text(
                tr('common.no_data'),
                style: TextStyle(color: Colors.grey.shade500),
              );
            }

            return Column(
              children: snapshot.data!.map((tx) {
                return _buildMobileTransactionRow(
                  id: tx['id'],
                  customTypeLabel: tx['customTypeLabel']?.toString(),
                  sourceSuffix: tx['sourceSuffix']?.toString(),
                  isIncoming: tx['isIncoming'] == true,
                  date: tx['date']?.toString() ?? '',
                  warehouse: tx['warehouse']?.toString() ?? '',
                  quantity: tx['quantity']?.toString() ?? '',
                  unit: urun.birim,
                  unitPrice: tx['unitPrice']?.toString() ?? '',
                  unitPriceVat: tx['unitPriceVat']?.toString() ?? '',
                  user: tx['user']?.toString() ?? '',
                  showActions: true,
                  urun: urun,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileProperty(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTransactionRow({
    required int id,
    String? customTypeLabel,
    String? sourceSuffix,
    required bool isIncoming,
    required String date,
    required String warehouse,
    required String quantity,
    required String unit,
    required String unitPrice,
    required String unitPriceVat,
    required String user,
    bool showActions = false,
    UretimModel? urun,
  }) {
    final String rawTypeLabel =
        customTypeLabel ??
        (isIncoming
            ? tr('warehouses.detail.type_in')
            : tr('warehouses.detail.type_out'));
    final lowerTypeLabel = rawTypeLabel.toLowerCase();
    final String displayTypeLabel =
        (lowerTypeLabel.contains('satış') ||
            lowerTypeLabel.contains('satis') ||
            lowerTypeLabel.contains('alış') ||
            lowerTypeLabel.contains('alis') ||
            lowerTypeLabel.contains('uretim') ||
            lowerTypeLabel.contains('üretim') ||
            lowerTypeLabel.contains('devir'))
        ? IslemTuruRenkleri.getProfessionalLabel(rawTypeLabel, context: 'stock')
        : rawTypeLabel;

    final String typeLabel = IslemCeviriYardimcisi.cevir(displayTypeLabel);
    final String normalizedSourceSuffix = (sourceSuffix ?? '').trim();
    final String translatedSourceSuffix = normalizedSourceSuffix.isNotEmpty
        ? IslemCeviriYardimcisi.parantezliKaynakKisaltma(normalizedSourceSuffix)
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: IslemTuruRenkleri.arkaplanRengiGetir(
                customTypeLabel,
                isIncoming,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              isIncoming
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: IslemTuruRenkleri.ikonRengiGetir(
                customTypeLabel,
                isIncoming,
              ),
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: typeLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: IslemTuruRenkleri.metinRengiGetir(
                                  customTypeLabel,
                                  isIncoming,
                                ),
                              ),
                            ),
                            if (translatedSourceSuffix.isNotEmpty)
                              TextSpan(
                                text: ' $translatedSourceSuffix',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      warehouse,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$quantity $unit',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '$unitPrice (${tr('common.vat_short')}: $unitPriceVat)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const Spacer(),
                    if (showActions)
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: _buildTransactionPopupMenu(
                          id,
                          customTypeLabel,
                          urun,
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

  Widget _buildCell({
    required double width,
    required Widget child,
    Alignment alignment = Alignment.centerLeft,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16),
    int? flex,
  }) {
    if (flex != null) {
      return Expanded(
        flex: flex,
        child: Container(padding: padding, alignment: alignment, child: child),
      );
    }
    return SizedBox(
      width: width,
      child: Container(padding: padding, alignment: alignment, child: child),
    );
  }

  Widget _buildTransactionRow({
    required int id,
    required bool isSelected,
    required ValueChanged<bool?> onChanged,
    required bool isIncoming,
    required String date,
    required String warehouse,
    required dynamic quantity,
    required String unit,
    dynamic unitPrice,
    dynamic unitPriceVat,
    required String description,
    required String user,
    String? customTypeLabel,
    String? sourceSuffix,
    bool showActions = false,
    UretimModel? urun,
    bool isFocused = false,
    VoidCallback? onTap,
    String? relatedAccount,
  }) {
    return Builder(
      builder: (context) {
        // Auto-scroll when focused
        if (isFocused) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
              );
            }
          });
        }

        final String rawTypeLabel =
            customTypeLabel ??
            (isIncoming
                ? tr('warehouses.detail.type_in')
                : tr('warehouses.detail.type_out'));
        final lowerTypeLabel = rawTypeLabel.toLowerCase();
        final String displayTypeLabel =
            (lowerTypeLabel.contains('satış') ||
                lowerTypeLabel.contains('satis') ||
                lowerTypeLabel.contains('alış') ||
                lowerTypeLabel.contains('alis') ||
                lowerTypeLabel.contains('uretim') ||
                lowerTypeLabel.contains('üretim') ||
                lowerTypeLabel.contains('devir'))
            ? IslemTuruRenkleri.getProfessionalLabel(
                rawTypeLabel,
                context: 'stock',
              )
            : rawTypeLabel;

        return GestureDetector(
          onTap: onTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click, // Show pointer on hover
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFC8E6C9) // Soft Green 100 for selection
                    : (isFocused
                          ? const Color(
                              0xFFE8F5E9,
                            ) // Soft Green 50 - focus color
                          : Colors.transparent),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Checkbox - NOT focusable via keyboard
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: ExcludeFocus(
                      child: Checkbox(
                        value: isSelected,
                        onChanged: onChanged,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: const BorderSide(
                          color: Color(0xFFD1D1D1),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Type
                  if (_columnVisibility['dt_type'] == true)
                    Expanded(
                      flex: 6,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: IslemTuruRenkleri.arkaplanRengiGetir(
                                customTypeLabel,
                                isIncoming,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              isIncoming
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: IslemTuruRenkleri.ikonRengiGetir(
                                customTypeLabel,
                                isIncoming,
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
                                  text: IslemCeviriYardimcisi.cevir(
                                    displayTypeLabel,
                                  ),
                                  query: _searchQuery,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: IslemTuruRenkleri.metinRengiGetir(
                                      customTypeLabel,
                                      isIncoming,
                                    ),
                                  ),
                                ),
                                if ((sourceSuffix ?? '').trim().isNotEmpty)
                                  Text(
                                    ' ${IslemCeviriYardimcisi.parantezliKaynakKisaltma((sourceSuffix ?? '').trim())}',
                                    style: TextStyle(
                                      fontSize: 9,
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
                  if (_columnVisibility['dt_related_account'] == true) ...[
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 6,
                      child: HighlightText(
                        text: relatedAccount ?? '-',
                        query: _searchQuery,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (_columnVisibility['dt_date'] == true)
                    Expanded(
                      flex: 5,
                      child: HighlightText(
                        text: date,
                        query: _searchQuery,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (_columnVisibility['dt_warehouse'] == true)
                    Expanded(
                      flex: 3,
                      child: HighlightText(
                        text: warehouse,
                        query: _searchQuery,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (_columnVisibility['dt_quantity'] == true)
                    Expanded(
                      flex: 2,
                      child: HighlightText(
                        text: FormatYardimcisi.sayiFormatla(
                          quantity,
                          binlik: _genelAyarlar.binlikAyiraci,
                          ondalik: _genelAyarlar.ondalikAyiraci,
                          decimalDigits: _genelAyarlar.miktarOndalik,
                        ),
                        query: _searchQuery,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFF39C12),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (_columnVisibility['dt_unit'] == true) ...[
                    const SizedBox(
                      width: 12,
                    ), // Space between Quantity and Unit
                    Expanded(
                      flex: 2,
                      child: Text(
                        unit,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (_columnVisibility['dt_unit_price'] == true)
                    Expanded(
                      flex: 7,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Builder(
                          builder: (context) {
                            if (unitPrice is num && unitPrice > 0) {
                              String formatted =
                                  FormatYardimcisi.sayiFormatlaOndalikli(
                                    unitPrice,
                                    binlik: _genelAyarlar.binlikAyiraci,
                                    ondalik: _genelAyarlar.ondalikAyiraci,
                                    decimalDigits: _genelAyarlar.fiyatOndalik,
                                  );
                              if (_genelAyarlar.sembolGoster) {
                                formatted +=
                                    ' ${_genelAyarlar.varsayilanParaBirimi}';
                              }
                              return HighlightText(
                                text: formatted,
                                query: _searchQuery,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF2C3E50),
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            }
                            return HighlightText(
                              text: '-',
                              query: _searchQuery,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF2C3E50),
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  if (_columnVisibility['dt_unit_price_vd'] == true) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Builder(
                          builder: (context) {
                            if (unitPriceVat is num && unitPriceVat > 0) {
                              String formatted =
                                  FormatYardimcisi.sayiFormatlaOndalikli(
                                    unitPriceVat,
                                    binlik: _genelAyarlar.binlikAyiraci,
                                    ondalik: _genelAyarlar.ondalikAyiraci,
                                    decimalDigits: _genelAyarlar.fiyatOndalik,
                                  );
                              if (_genelAyarlar.sembolGoster) {
                                formatted +=
                                    ' ${_genelAyarlar.varsayilanParaBirimi}';
                              }
                              return HighlightText(
                                text: formatted,
                                query: _searchQuery,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF2C3E50),
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            }
                            return HighlightText(
                              text: '-',
                              query: _searchQuery,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF2C3E50),
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  if (_columnVisibility['dt_total_price'] == true) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 7,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Builder(
                          builder: (context) {
                            dynamic totalVal;
                            dynamic totalValExcluded;
                            if (quantity is num && unitPriceVat is num) {
                              totalVal = quantity * unitPriceVat;
                            } else {
                              final q =
                                  double.tryParse(quantity.toString()) ?? 0.0;
                              final p =
                                  double.tryParse(unitPriceVat.toString()) ??
                                  0.0;
                              if (q > 0 || p > 0) totalVal = q * p;
                            }

                            if (quantity is num && unitPrice is num) {
                              totalValExcluded = quantity * unitPrice;
                            } else {
                              final q =
                                  double.tryParse(quantity.toString()) ?? 0.0;
                              final p =
                                  double.tryParse(unitPrice.toString()) ?? 0.0;
                              if (q > 0 || p > 0) totalValExcluded = q * p;
                            }

                            if (totalVal != null && totalVal > 0) {
                              String formatted =
                                  FormatYardimcisi.sayiFormatlaOndalikli(
                                    totalVal,
                                    binlik: _genelAyarlar.binlikAyiraci,
                                    ondalik: _genelAyarlar.ondalikAyiraci,
                                    decimalDigits: _genelAyarlar.fiyatOndalik,
                                  );

                              String formattedExcluded = '';
                              if (totalValExcluded != null &&
                                  totalValExcluded > 0) {
                                formattedExcluded =
                                    FormatYardimcisi.sayiFormatlaOndalikli(
                                      totalValExcluded,
                                      binlik: _genelAyarlar.binlikAyiraci,
                                      ondalik: _genelAyarlar.ondalikAyiraci,
                                      decimalDigits: _genelAyarlar.fiyatOndalik,
                                    );
                                if (_genelAyarlar.sembolGoster) {
                                  formattedExcluded +=
                                      ' ${_genelAyarlar.varsayilanParaBirimi}';
                                }
                              }

                              if (_genelAyarlar.sembolGoster) {
                                formatted +=
                                    ' ${_genelAyarlar.varsayilanParaBirimi}';
                              }

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  HighlightText(
                                    text: formatted,
                                    query: _searchQuery,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFF39C12),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (formattedExcluded.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: HighlightText(
                                        text: formattedExcluded,
                                        query: _searchQuery,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }
                            return HighlightText(
                              text: '-',
                              query: _searchQuery,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFF39C12),
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  if (_columnVisibility['dt_description'] == true) ...[
                    const SizedBox(
                      width: 48,
                    ), // Space between Unit and Description
                    Expanded(
                      flex: 8,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: HighlightText(
                          text: description,
                          query: _searchQuery,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_columnVisibility['dt_user'] == true) ...[
                    const SizedBox(
                      width: 24,
                    ), // Spacing between Description and User
                    Expanded(
                      flex: 3,
                      child: HighlightText(
                        text: user,
                        query: _searchQuery,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],

                  // Action Menu
                  const SizedBox(width: 80), // Extra spacing before Actions
                  SizedBox(
                    width: 120,
                    child:
                        showActions &&
                            (customTypeLabel == null ||
                                !customTypeLabel.contains('Sevkiyat'))
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: _buildTransactionPopupMenu(
                              id,
                              customTypeLabel,
                              urun,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionPopupMenu(
    int id,
    String? customTypeLabel,
    UretimModel? urun,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEEEEEE),
          thickness: 1,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          elevation: 6,
        ),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 22),
        iconSize: 22,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 140),
        splashRadius: 20,
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(40, 40)),
          padding: WidgetStateProperty.all(EdgeInsets.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        offset: const Offset(0, 8),
        tooltip: tr('common.actions'),
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'edit',
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Color(0xFF2C3E50),
                ),
                const SizedBox(width: 8),
                Text(
                  tr('common.edit'),
                  style: const TextStyle(
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  tr('common.key.f2'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            enabled: false,
            height: 8,
            padding: EdgeInsets.zero,
            child: Divider(
              height: 1,
              thickness: 1,
              indent: 8,
              endIndent: 8,
              color: Color(0xFFEEEEEE),
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Color(0xFFEA4335),
                ),
                const SizedBox(width: 8),
                Text(
                  tr('common.delete'),
                  style: const TextStyle(
                    color: Color(0xFFEA4335),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  tr('common.key.del'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == 'edit') {
            if (urun != null) {
              _handleDetailEdit(id, customTypeLabel, urun);
            }
          } else if (value == 'delete') {
            _deleteTransaction(id);
          }
        },
      ),
    );
  }

  Widget _buildPopupMenu(UretimModel urun) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEEEEEE),
          thickness: 1,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          elevation: 6,
        ),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 22),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 160),
        splashRadius: 20,
        offset: const Offset(0, 8),
        tooltip: tr('common.actions'),
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'edit',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Color(0xFF2C3E50),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('common.edit'),
                  style: const TextStyle(
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  tr('common.key.f2'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            enabled: false,
            height: 12,
            padding: EdgeInsets.zero,
            child: Divider(
              height: 1,
              thickness: 1,
              indent: 10,
              endIndent: 10,
              color: Color(0xFFEEEEEE),
            ),
          ),
          PopupMenuItem<String>(
            value: urun.aktifMi ? 'deactivate' : 'activate',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  urun.aktifMi
                      ? Icons.toggle_on_outlined
                      : Icons.toggle_off_outlined,
                  size: 20,
                  color: const Color(0xFF2C3E50),
                ),
                const SizedBox(width: 12),
                Text(
                  urun.aktifMi
                      ? tr('common.deactivate')
                      : tr('common.activate'),
                  style: const TextStyle(
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  tr('common.key.f6'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            enabled: false,
            height: 12,
            padding: EdgeInsets.zero,
            child: Divider(
              height: 1,
              thickness: 1,
              indent: 10,
              endIndent: 10,
              color: Color(0xFFEEEEEE),
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Color(0xFFEA4335),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('common.delete'),
                  style: const TextStyle(
                    color: Color(0xFFEA4335),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  tr('common.key.del'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == 'edit') {
            _showEditDialog(urun);
          } else if (value == 'deactivate') {
            _uretimDurumDegistir(urun, false);
          } else if (value == 'activate') {
            _uretimDurumDegistir(urun, true);
          } else if (value == 'delete') {
            _deleteUrun(urun);
          }
        },
      ),
    );
  }

  Future<void> _deleteTransaction(int id) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr('common.confirm_delete'),
        onOnay: () {
          // Logic handled after await
        },
        isDestructive: true,
        onayButonMetni: tr('common.delete'),
      ),
    );

    if (result == true) {
      if (!mounted) return;

      try {
        final isProductionMovement = await UretimlerVeritabaniServisi()
            .uretimHareketiVarMi(id);

        if (isProductionMovement) {
          await UretimlerVeritabaniServisi().uretimHareketiSil(id);
        } else {
          await DepolarVeritabaniServisi().sevkiyatSil(id);
        }

        if (mounted) {
          setState(() {
            _detailFutures.clear(); // Clear cache to refresh all expanded rows
            _refreshKey++;
          });
          _fetchUretimler();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('common.deleted_successfully')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${tr('common.error')}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // --- Warehouse Filter Methods ---

  void _showWarehouseOverlay() {
    _closeOverlay();
    setState(() {
      _isWarehouseFilterExpanded = true;
    });

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _warehouseLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 42),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Container(
                width: 250,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildWarehouseOption(
                      null,
                      tr('settings.general.option.documents.all'),
                    ),
                    ..._warehouses.map((w) => _buildWarehouseOption(w, w.ad)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  Widget _buildWarehouseFilter({double? width}) {
    return CompositedTransformTarget(
      link: _warehouseLayerLink,
      child: InkWell(
        onTap: () {
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
                Icons.store_rounded,
                size: 20,
                color: _isWarehouseFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedWarehouse == null
                      ? tr('productions.transaction.warehouse')
                      : '${_selectedWarehouse!.ad} (${_filterStats['depolar']?['${_selectedWarehouse!.id}'] ?? 0})',
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
                  onTap: () {
                    setState(() {
                      _selectedWarehouse = null;
                    });
                    _fetchUretimler();
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
  }

  Widget _buildWarehouseOption(DepoModel? value, String label) {
    final isSelected = _selectedWarehouse?.id == value?.id;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['depolar']?['${value.id}'] ?? 0);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedWarehouse = value;
          _isWarehouseFilterExpanded = false;
          _resetPagination();
        });
        _closeOverlay();
        _fetchUretimler();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFE6F4EA) : Colors.transparent,
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF1E7E34) : Colors.black87,
          ),
        ),
      ),
    );
  }
}
