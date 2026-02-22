import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../bilesenler/genisletilebilir_tablo.dart';
import '../../ayarlar/genel_ayarlar/veri_kaynagi/genel_ayarlar_veri_kaynagi.dart';
import '../../../bilesenler/onay_dialog.dart';
import '../../../bilesenler/tab_acici_scope.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/ceviri/islem_ceviri_yardimcisi.dart';
import '../../../yardimcilar/responsive_yardimcisi.dart';
import '../../../bilesenler/tarih_araligi_secici_dialog.dart';
import 'modeller/depo_model.dart';

import 'depo_ekle_dialog.dart';
import 'depolar_sayfasi_dialogs.dart';
import 'sevkiyat_olustur_sayfasi.dart';
import '../../../servisler/depolar_veritabani_servisi.dart';
import '../../../servisler/ayarlar_veritabani_servisi.dart';
import '../../../servisler/urunler_veritabani_servisi.dart';
import '../../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../../yardimcilar/mesaj_yardimcisi.dart';
import '../urunler/acilis_stogu_duzenle_sayfasi.dart';
import '../urunler/devir_yap_sayfasi.dart';
import '../../alimsatimislemleri/alis_yap_sayfasi.dart';
import '../../alimsatimislemleri/modeller/transaction_item.dart';
import '../../alimsatimislemleri/satis_yap_sayfasi.dart';
import '../../carihesaplar/modeller/cari_hesap_model.dart';
import '../../../yardimcilar/entegrasyon_islem_yardimcisi.dart';
import '../../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../../ortak/genisletilebilir_print_preview_screen.dart';
import '../../../bilesenler/highlight_text.dart';
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import '../../../yardimcilar/islem_turu_renkleri.dart';
import '../../../servisler/uretimler_veritabani_servisi.dart';
import '../uretimler/uretim_yap_sayfasi.dart';
import '../../../servisler/sayfa_senkronizasyon_servisi.dart';

class DepolarSayfasi extends StatefulWidget {
  const DepolarSayfasi({super.key});

  @override
  State<DepolarSayfasi> createState() => _DepolarSayfasiState();
}

class _DepolarSayfasiState extends State<DepolarSayfasi> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<DepoModel> _cachedDepolar = [];

  bool _isLoading = true;
  bool _isMobileToolbarExpanded = false;
  int _totalRecords = 0;
  Map<String, Map<String, int>> _filterStats = {};
  final Set<int> _selectedIds = {};
  int _rowsPerPage = 25;
  int _currentPage = 1;
  final Set<int> _expandedMobileIds = {};
  /* Set<int> _autoExpandedIndices = {};  -- Keeping original name if needed, but managing manually now */
  Set<int> _autoExpandedIndices = {};
  final Set<int> _expandedIndices =
      {}; // Replaces _manualExpandedIndex for multiple selection support

  // Satır seçimi için (ok tuşları ile navigasyon)
  int? _selectedRowId;
  int? _selectedMobileCardId;

  // Seçili detay transaction bilgisi (Son Hareketler için F2/Del kısayolları)
  int? _selectedDetailTransactionId;
  String? _selectedDetailCustomTypeLabel;
  String? _selectedDetailProductCode;
  String? _selectedDetailProductName;
  String? _selectedDetailWarehouse;

  // Date Filter State
  DateTime? _startDate;
  DateTime? _endDate;

  // Status Filter State
  bool _isStatusFilterExpanded = false;
  String? _selectedStatus;

  // Overlay State
  final LayerLink _statusLayerLink = LayerLink();
  final LayerLink _transactionLayerLink = LayerLink();
  final LayerLink _warehouseLayerLink = LayerLink();
  final LayerLink _userLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  // Transaction Filter State
  bool _isTransactionFilterExpanded = false;
  String? _selectedTransactionType;

  // Warehouse Filter State
  bool _isWarehouseFilterExpanded = false;
  DepoModel? _selectedWarehouse;

  // User Filter State
  bool _isUserFilterExpanded = false;
  String? _selectedUser;
  List<String> _availableUsers = [];

  final Map<int, List<int>> _visibleTransactionIds = {}; // depoId -> [id]
  final Map<int, Set<int>> _selectedDetailIds = {};
  // Cache for detail futures to prevent reloading on selection changes
  final Map<int, Future<List<dynamic>>> _detailFutures = {};
  // _focusedDetailIds removed - handled by GenisletilebilirTablo

  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  bool _keepDetailsOpen = false;

  // Column Visibility State
  Map<String, bool> _columnVisibility = {};

  // Sorting State
  int? _sortColumnIndex = 1; // Default sort by ID
  bool _sortAscending = false;
  String? _sortBy = 'id';
  Timer? _debounce;
  int _aktifSorguNo = 0;

  // Refresh Key for FutureBuilder (Forces rebuild on data change)
  int _detailRefreshKey = 0;

  List<String> _availableTransactionTypes = [];

  @override
  void initState() {
    super.initState();
    _columnVisibility = {
      // Main Table
      'order_no': true,
      'code': true,
      'name': true,
      'address': true,
      'responsible': true,
      'phone': true,
      'status': true,
      // Detail Table
      'dt_transaction': true,
      'dt_related_account': true,
      'dt_date': true,
      'dt_warehouse': true,
      'dt_quantity': true,
      'dt_unit': true,
      'dt_unit_price': true,
      'dt_unit_price_vat': true,
      'dt_total_price': true,
      'dt_description': true,
      'dt_user': true,
    };
    _loadSettings();
    _loadAvailableUsers();
    _loadAvailableTransactionTypes();
    _fetchDepolar();
    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (_searchController.text != _searchQuery) {
          setState(() {
            _searchQuery = _searchController.text.toLowerCase();
            _currentPage = 1;
          });
          _fetchDepolar();
        }
      });
    });

    SayfaSenkronizasyonServisi().addListener(_onGlobalSync);
  }

  Future<void> _loadAvailableTransactionTypes() async {
    try {
      final types = await DepolarVeritabaniServisi()
          .getMevcutStokIslemTurleri();
      if (mounted) {
        setState(() {
          _availableTransactionTypes = types;
        });
      }
    } catch (e) {
      debugPrint('İşlem türleri yüklenirken hata: $e');
    }
  }

  void _onGlobalSync() {
    _fetchDepolar(showLoading: false);
  }

  Future<void> _fetchDepolar({bool showLoading = true}) async {
    // Clear detail cache when refreshing main list
    _detailFutures.clear();

    final int sorguNo = ++_aktifSorguNo;

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      bool? aktifMi;
      if (_selectedStatus == 'active') {
        aktifMi = true;
      } else if (_selectedStatus == 'passive') {
        aktifMi = false;
      }

      final depolar = await DepolarVeritabaniServisi().depolariGetir(
        sayfa: _currentPage,
        sayfaBasinaKayit: _rowsPerPage,
        aramaKelimesi: _searchQuery,
        siralama: _sortBy,
        artanSiralama: _sortAscending,
        aktifMi: aktifMi, // Existing status filter
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        islemTuru: _selectedTransactionType,
        depoId: _selectedWarehouse?.id,
        kullanici: _selectedUser,
      );

      if (!mounted || sorguNo != _aktifSorguNo) return;

      final totalFuture = DepolarVeritabaniServisi().depoSayisiGetir(
        aramaTerimi: _searchQuery,
        aktifMi: aktifMi,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        islemTuru: _selectedTransactionType,
        depoId: _selectedWarehouse?.id,
        kullanici: _selectedUser,
      );

      if (mounted) {
        final indices = <int>{};
        if (_searchQuery.isNotEmpty) {
          for (int i = 0; i < depolar.length; i++) {
            if (depolar[i].matchedInHidden) {
              indices.add(i);
            }
          }
        }

        // Auto-expand all result rows if a specific transaction type is selected
        if (_selectedTransactionType != null || _selectedUser != null) {
          for (int i = 0; i < depolar.length; i++) {
            indices.add(i);
          }
        }

        final statsFuture = DepolarVeritabaniServisi()
            .depoFiltreIstatistikleriniGetir(
              aramaTerimi: _searchQuery,
              baslangicTarihi: _startDate,
              bitisTarihi: _endDate,
              aktifMi: aktifMi,
              islemTuru: _selectedTransactionType,
              kullanici: _selectedUser,
              depoId: _selectedWarehouse?.id,
            );

        setState(() {
          _cachedDepolar = depolar;
          _autoExpandedIndices = indices;
          _isLoading = false;
        });

        unawaited(
          totalFuture
              .then((total) {
                if (!mounted || sorguNo != _aktifSorguNo) return;
                setState(() {
                  _totalRecords = total;
                });
              })
              .catchError((e) {
                debugPrint('Depo toplam sayısı güncellenemedi: $e');
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
                debugPrint('Depo filtre istatistikleri güncellenemedi: $e');
              }),
        );
      }
    } catch (e) {
      if (mounted && sorguNo == _aktifSorguNo) {
        setState(() => _isLoading = false);
        if (mounted) {
          setState(() => _isLoading = false);
          MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
        }
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = await GenelAyarlarVeriKaynagi().ayarlariGetir();
      if (mounted) {
        setState(() {
          _keepDetailsOpen =
              prefs.getBool('depolar_keep_details_open') ?? false;
          _genelAyarlar = settings;
        });
      }
    } catch (e) {
      debugPrint('Depolar ayarlar yüklenirken hata: $e');
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

  Future<void> _toggleKeepDetailsOpen() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _keepDetailsOpen = !_keepDetailsOpen;
    });
    await prefs.setBool('depolar_keep_details_open', _keepDetailsOpen);
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
                            tr('warehouses.table.code'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'name',
                            tr('warehouses.table.name'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'address',
                            tr('warehouses.table.address'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'responsible',
                            tr('warehouses.table.responsible'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'phone',
                            tr('warehouses.table.phone'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'status',
                            tr('warehouses.table.status'),
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
                            'dt_transaction',
                            tr('warehouses.detail.transaction'),
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
                            tr('warehouses.detail.date'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_warehouse',
                            tr('warehouses.detail.warehouse'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_quantity',
                            tr('warehouses.detail.quantity'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_unit',
                            tr('warehouses.detail.unit'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_unit_price',
                            tr('products.table.unit_price'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_unit_price_vat',
                            tr('products.table.unit_price_vat'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_total_price',
                            tr('products.table.total_price'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_description',
                            tr('warehouses.detail.description'),
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

  @override
  void dispose() {
    SayfaSenkronizasyonServisi().removeListener(_onGlobalSync);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
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
        _isTransactionFilterExpanded = false;
        _isWarehouseFilterExpanded = false;
        _isUserFilterExpanded = false;
      });
    }
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
      });
      _detailFutures.clear();
      _fetchDepolar();
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
                width: 260, // Wider for long texts
                constraints: const BoxConstraints(maxHeight: 300),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
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
              child: _WarehouseFilterOverlay(
                selectedWarehouse: _selectedWarehouse,
                depotCounts: _filterStats['depolar'] ?? const {},
                totalCount: _filterStats['ozet']?['toplam'] ?? 0,
                onSelect: (depo) {
                  setState(() {
                    _selectedWarehouse = depo;
                    _isWarehouseFilterExpanded = false;
                  });
                  _closeOverlay();
                  _detailFutures.clear(); // Clear cache on filter change
                  _fetchDepolar();
                },
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  List<DepoModel> _filterDepolar(List<DepoModel> depolar) {
    if (_searchQuery.isEmpty) return depolar;

    return depolar.where((depo) {
      final codeMatch = depo.kod.toLowerCase().contains(_searchQuery);
      final nameMatch = depo.ad.toLowerCase().contains(_searchQuery);
      final addressMatch = depo.adres.toLowerCase().contains(_searchQuery);
      final responsibleMatch = depo.sorumlu.toLowerCase().contains(
        _searchQuery,
      );
      final phoneMatch = depo.telefon.toLowerCase().contains(_searchQuery);

      return codeMatch ||
          nameMatch ||
          addressMatch ||
          responsibleMatch ||
          phoneMatch;
    }).toList();
  }

  Future<void> _showAddDialog() async {
    String? initialCode;
    try {
      final settings = await GenelAyarlarVeriKaynagi().ayarlariGetir();
      if (settings.otoDepoKodu) {
        initialCode = await DepolarVeritabaniServisi().siradakiDepoKodunuGetir(
          alfanumerik: settings.otoDepoKoduAlfanumerik,
        );
      }
    } catch (e) {
      debugPrint('Oto kod alma hatası: $e');
    }

    if (!mounted) return;

    final result = await showDialog<DepoModel>(
      context: context,
      builder: (context) => DepoEkleDialog(initialCode: initialCode),
    );

    if (result != null) {
      try {
        await DepolarVeritabaniServisi().depoEkle(result);
        SayfaSenkronizasyonServisi().veriDegisti('urun');
        _detailFutures.clear(); // Clear cache on data change
        await _fetchDepolar();

        if (mounted) {
          if (mounted) {
            MesajYardimcisi.basariGoster(
              context,
              tr('common.saved_successfully'),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          if (mounted) {
            MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
          }
        }
      }
    }
  }

  Future<void> _showEditDialog(DepoModel depo) async {
    final result = await showDialog<DepoModel>(
      context: context,
      builder: (context) => DepoEkleDialog(depo: depo),
    );

    if (result != null) {
      try {
        await DepolarVeritabaniServisi().depoGuncelle(result);
        SayfaSenkronizasyonServisi().veriDegisti('urun');
        _detailFutures.clear(); // Clear cache on data change
        await _fetchDepolar();

        if (mounted) {
          if (mounted) {
            MesajYardimcisi.basariGoster(
              context,
              tr('common.updated_successfully'),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          if (mounted) {
            MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
          }
        }
      }
    }
  }

  Future<void> _deleteSelectedDepolar() async {
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
      try {
        for (final id in _selectedIds) {
          await DepolarVeritabaniServisi().depoSil(id);
        }

        SayfaSenkronizasyonServisi().veriDegisti('urun');
        _detailFutures.clear(); // Clear cache on data change
        await _fetchDepolar();

        setState(() {
          _selectedIds.clear();
        });

        if (mounted) {
          if (mounted) {
            MesajYardimcisi.basariGoster(
              context,
              tr('common.deleted_successfully'),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          if (mounted) {
            MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
          }
        }
      }
    }
  }

  void _deleteDepo(DepoModel depo) async {
    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr('common.confirm_delete_named').replaceAll('{name}', depo.ad),
        onOnay: () {},
        isDestructive: true,
        onayButonMetni: tr('common.delete'),
      ),
    );

    if (onay == true) {
      try {
        await DepolarVeritabaniServisi().depoSil(depo.id);
        SayfaSenkronizasyonServisi().veriDegisti('urun');
        _detailFutures.clear(); // Clear cache on data change
        await _fetchDepolar();

        if (mounted) {
          if (mounted) {
            MesajYardimcisi.basariGoster(
              context,
              tr('common.deleted_successfully'),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          if (mounted) {
            MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
          }
        }
      }
    }
  }

  Future<void> _showShipmentPage() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SevkiyatOlusturSayfasi(depolar: _cachedDepolar),
      ),
    );

    if (result == true) {
      SayfaSenkronizasyonServisi().veriDegisti('urun');
      setState(() => _detailRefreshKey++);
      _detailFutures.clear(); // Clear cache on data change
      _fetchDepolar();
    }
  }

  Future<void> _showWarehouseStockDialog(DepoModel depo) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) =>
          WarehouseStockDialog(depo: depo, genelAyarlar: _genelAyarlar),
    );
  }

  @override
  Widget build(BuildContext context) {
    // [REIS MODU] Sıçramayı önlemek için her zaman Scaffold dönüyoruz.
    // Veri yoksa bile yapı değişmiyor, sadece üstte ince bar çıkıyor.

    // Filtreleme mantığı
    List<DepoModel> filteredDepolar = _cachedDepolar;

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
                return;
              }

              // Priority 3: Clear Filters if active
              if (_startDate != null ||
                  _endDate != null ||
                  _selectedStatus != null ||
                  _selectedTransactionType != null ||
                  _selectedWarehouse != null ||
                  _selectedUser != null) {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _selectedStatus = null;
                  _selectedTransactionType = null;
                  _selectedWarehouse = null;
                  _selectedUser = null;
                });
                _detailFutures.clear(); // Clear cache on filter change
                _fetchDepolar();
                return;
              }
            },
            const SingleActivator(LogicalKeyboardKey.f1): _showAddDialog,
            const SingleActivator(LogicalKeyboardKey.f2): () {
              // F2: Düzenle - önce seçili detay transaction varsa onu düzenle
              if (_selectedDetailTransactionId != null) {
                _handleDetailEdit(
                  _selectedDetailTransactionId!,
                  _selectedDetailCustomTypeLabel,
                  _selectedDetailProductCode,
                  _selectedDetailProductName,
                  _selectedDetailWarehouse,
                );
                return;
              }
              // Yoksa ana satırı düzenle
              if (_selectedRowId == null) return;
              final depo = _cachedDepolar.firstWhere(
                (d) => d.id == _selectedRowId,
              );
              _showEditDialog(depo);
            },
            const SingleActivator(LogicalKeyboardKey.f3): () {
              // F3: Ara - arama kutusuna odaklan
              _searchFocusNode.requestFocus();
            },
            const SingleActivator(LogicalKeyboardKey.f5): () => _fetchDepolar(),
            const SingleActivator(LogicalKeyboardKey.f6): () {
              // F6: Aktif/Pasif Toggle - seçili satır varsa
              if (_selectedRowId == null) return;
              final depo = _cachedDepolar.firstWhere(
                (d) => d.id == _selectedRowId,
              );
              _depoDurumDegistir(depo, !depo.aktifMi);
            },
            const SingleActivator(LogicalKeyboardKey.f7): _handlePrint,
            const SingleActivator(LogicalKeyboardKey.f8): () {
              // F8: Seçilileri Sil
              if (_selectedIds.isEmpty) return;
              _deleteSelectedDepolar();
            },
            const SingleActivator(LogicalKeyboardKey.f10): _showShipmentPage,
            const SingleActivator(LogicalKeyboardKey.delete): () {
              // Delete: Önce seçili detay transaction varsa onu sil
              if (_selectedDetailTransactionId != null) {
                _handleDetailDelete(_selectedDetailTransactionId!);
                return;
              }
              // Yoksa ana satırı sil
              if (_selectedRowId == null) return;
              final depo = _cachedDepolar.firstWhere(
                (d) => d.id == _selectedRowId,
              );
              _deleteDepo(depo);
            },
            const SingleActivator(LogicalKeyboardKey.numpadDecimal): () {
              // Numpad Delete: Önce seçili detay transaction varsa onu sil
              if (_selectedDetailTransactionId != null) {
                _handleDetailDelete(_selectedDetailTransactionId!);
                return;
              }
              // Yoksa ana satırı sil
              if (_selectedRowId == null) return;
              final depo = _cachedDepolar.firstWhere(
                (d) => d.id == _selectedRowId,
              );
              _deleteDepo(depo);
            },
          },
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool forceMobile = ResponsiveYardimcisi.tabletMi(
                    context,
                  );
                  if (forceMobile || constraints.maxWidth < 800) {
                    return _buildMobileView(filteredDepolar);
                  } else {
                    return _buildDesktopView(filteredDepolar, constraints);
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
      _selectedMobileCardId = null;
      _selectedDetailTransactionId = null;
      _selectedDetailCustomTypeLabel = null;
      _selectedDetailProductCode = null;
      _selectedDetailProductName = null;
      _selectedDetailWarehouse = null;
    });
  }

  void _onSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedIds.addAll(_filterDepolar(_cachedDepolar).map((e) => e.id));
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

  void _onSelectAllDetails(int depoId, bool? value) {
    setState(() {
      if (value == true) {
        _selectedDetailIds[depoId] = (_visibleTransactionIds[depoId] ?? [])
            .toSet();
      } else {
        _selectedDetailIds[depoId]?.clear();
      }
    });
  }

  void _onSelectDetailRow(int depoId, int transactionId, bool? value) {
    setState(() {
      if (_selectedDetailIds[depoId] == null) {
        _selectedDetailIds[depoId] = {};
      }
      if (value == true) {
        _selectedDetailIds[depoId]!.add(transactionId);
      } else {
        _selectedDetailIds[depoId]!.remove(transactionId);
      }
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;

      switch (columnIndex) {
        case 1: // ID
          _sortBy = 'id';
          break;
        case 2: // Code
          _sortBy = 'kod';
          break;
        case 3: // Name
          _sortBy = 'ad';
          break;
        case 4: // Address
          _sortBy = 'adres';
          break;
        case 5: // Responsible
          _sortBy = 'sorumlu';
          break;
        case 6: // Phone
          _sortBy = 'telefon';
          break;
        case 7: // Status
          _sortBy = 'aktif_mi';
          break;
        default:
          _sortBy = 'id';
      }
    });
    _detailFutures.clear(); // Clear cache on sort change
    _fetchDepolar(showLoading: false);
  }

  Future<void> _depoDurumDegistir(DepoModel depo, bool aktifMi) async {
    try {
      final yeniDepo = depo.copyWith(aktifMi: aktifMi);
      await DepolarVeritabaniServisi().depoGuncelle(yeniDepo);
      _detailFutures.clear(); // Clear cache on data change
      await _fetchDepolar(showLoading: false);

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
        setState(() {
          _detailRefreshKey++;
          _detailFutures.clear();
        });
        await _fetchDepolar(showLoading: false);
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
    String? productCode,
    String? productName,
    String? warehouse,
  ) async {
    final handled = await _openAlisSatisDuzenlemeFromShipment(id);
    if (handled) {
      // Satış / Alış işlemleri entegrasyon ref ile düzenlenir.
    } else if (customTypeLabel?.contains('Sevkiyat') == true) {
      _showEditSevkiyatDialog(id);
    } else if (customTypeLabel?.contains('Açılış Stoğu') == true) {
      if (productCode != null) {
        UrunlerVeritabaniServisi().urunGetir(kod: productCode).then((urun) {
          if (urun != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AcilisStoguDuzenleSayfasi(
                  transactionId: id,
                  urun: urun,
                  warehouseName: warehouse ?? '',
                ),
              ),
            ).then((result) {
              if (result == true) {
                _detailRefreshKey++;
                _detailFutures.clear();
                _fetchDepolar();
              }
            });
          } else if (mounted) {
            MesajYardimcisi.hataGoster(
              context,
              tr('shipment.form.error.product_not_found'),
            );
          }
        });
      }
    } else if (customTypeLabel != null &&
        (customTypeLabel.contains('Giriş') ||
            customTypeLabel.contains('Çıkış') ||
            customTypeLabel.contains('Devir'))) {
      // Giriş, Çıkış, Devir işlemleri için DevirYapSayfasi
      DepolarVeritabaniServisi().sevkiyatGetir(id).then((shipmentData) async {
        if (shipmentData == null) {
          if (mounted) {
            MesajYardimcisi.hataGoster(context, tr('common.error.generic'));
          }
          return;
        }

        // Ürün kodunu bul
        String? targetProductCode = productCode;
        if (targetProductCode == null || targetProductCode.isEmpty) {
          final items = shipmentData['items'] as List?;
          if (items != null && items.isNotEmpty) {
            final firstItem = items.first as Map<String, dynamic>;
            targetProductCode = firstItem['code']?.toString();
          }
        }

        if (targetProductCode == null || targetProductCode.isEmpty) {
          if (mounted) {
            MesajYardimcisi.hataGoster(
              context,
              tr('productions.make.enter_code'),
            );
          }
          return;
        }

        // UrunModel'i getir
        final urun = await UrunlerVeritabaniServisi().urunGetir(
          kod: targetProductCode,
        );

        if (urun != null && mounted) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DevirYapSayfasi(
                urun: urun,
                editingShipmentId: id,
                initialData: shipmentData,
              ),
            ),
          );
          if (result == true) {
            _detailRefreshKey++;
            _detailFutures.clear();
            _fetchDepolar();
          }
        } else if (mounted) {
          MesajYardimcisi.hataGoster(
            context,
            tr('shipment.form.error.product_not_found'),
          );
        }
      });
    } else if (customTypeLabel != null && customTypeLabel.contains('Üretim')) {
      // Üretim işlemi için düzenleme (F2 kısayolu)
      DepolarVeritabaniServisi().sevkiyatGetir(id).then((shipmentData) async {
        if (shipmentData == null) {
          if (mounted) {
            MesajYardimcisi.hataGoster(context, tr('common.error.generic'));
          }
          return;
        }

        // Ürün kodunu bul
        String? targetProductCode = productCode;
        if (targetProductCode == null || targetProductCode.isEmpty) {
          final items = shipmentData['items'] as List?;
          if (items != null && items.isNotEmpty) {
            final firstItem = items.first as Map<String, dynamic>;
            targetProductCode = firstItem['code']?.toString();
          }
        }

        if (targetProductCode == null || targetProductCode.isEmpty) {
          if (mounted) {
            MesajYardimcisi.hataGoster(
              context,
              tr('productions.make.enter_code'),
            );
          }
          return;
        }

        // UretimModel'i bul
        final uretimler = await UretimlerVeritabaniServisi().uretimleriGetir(
          aramaTerimi: targetProductCode,
          sayfaBasinaKayit: 10,
        );

        if (uretimler.isNotEmpty && mounted) {
          final uretimModel = uretimler.firstWhere(
            (u) => u.kod == targetProductCode,
            orElse: () => uretimler.first,
          );
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UretimYapSayfasi(
                initialModel: uretimModel,
                editingTransactionId: id,
                initialData: shipmentData,
              ),
            ),
          );
          if (result == true) {
            _detailRefreshKey++;
            _detailFutures.clear();
            _fetchDepolar();
          }
        } else if (mounted) {
          MesajYardimcisi.hataGoster(
            context,
            tr('shipment.form.error.product_not_found'),
          );
        }
      });
    }
    // Seçimi temizle
    setState(() {
      _selectedDetailTransactionId = null;
      _selectedDetailCustomTypeLabel = null;
      _selectedDetailProductCode = null;
      _selectedDetailProductName = null;
      _selectedDetailWarehouse = null;
    });
  }

  /// Detay transaction silme (Del kısayolu için)
  void _handleDetailDelete(int id) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => OnayDialog(
        baslik: tr('common.delete'),
        mesaj: tr('common.confirm_delete'),
        onayButonMetni: tr('common.delete'),
        iptalButonMetni: tr('common.cancel'),
        isDestructive: true,
        onOnay: () async {
          await DepolarVeritabaniServisi().sevkiyatSil(id);
          setState(() {
            _detailRefreshKey++;
            _detailFutures.clear();
          });
          _fetchDepolar();
        },
      ),
    );
    // Seçimi temizle
    setState(() {
      _selectedDetailTransactionId = null;
      _selectedDetailCustomTypeLabel = null;
      _selectedDetailProductCode = null;
      _selectedDetailProductName = null;
      _selectedDetailWarehouse = null;
    });
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
          ? _cachedDepolar
                .where((d) => mainRowIdsToProcess.contains(d.id))
                .toList()
          : _cachedDepolar;

      for (var i = 0; i < dataToProcess.length; i++) {
        final depo = dataToProcess[i];

        // Determine if row is expanded
        final isExpanded =
            _keepDetailsOpen ||
            _autoExpandedIndices.contains(i) ||
            _expandedIndices.contains(i);

        List<Map<String, dynamic>> transactions = [];
        // 1. Transactions Fetch (Only if expanded or has selected details)
        final hasPrintSelectedDetails =
            _selectedDetailIds[depo.id]?.isNotEmpty ?? false;
        if (isExpanded || hasPrintSelectedDetails) {
          final results = await Future.wait([
            DepolarVeritabaniServisi().depoIslemleriniGetir(
              depo.id,
              aramaTerimi: _searchQuery,
              baslangicTarihi: _startDate,
              bitisTarihi: _endDate,
              islemTuru: _selectedTransactionType,
              kullanici: _selectedUser,
            ),
          ]);
          transactions = results[0];
        }

        // Filter transactions if detail selection exists for this row
        final selectedDetailIdsForRow = _selectedDetailIds[depo.id];
        if (selectedDetailIdsForRow != null &&
            selectedDetailIdsForRow.isNotEmpty) {
          transactions = transactions.where((t) {
            final txId = t['id'] as int?;
            return txId != null && selectedDetailIdsForRow.contains(txId);
          }).toList();
        }

        // 2. Main Row Data
        final mainRow = [
          depo.id.toString(),
          depo.kod,
          depo.ad,
          depo.adres,
          depo.sorumlu,
          depo.telefon,
          depo.aktifMi ? tr('common.active') : tr('common.passive'),
        ];

        // 3. Details (Info Card Content) - Telefon, Durum, Girdi/Çıktı/Toplam
        Map<String, String> details = {};
        final hasSelectedDetails =
            _selectedDetailIds[depo.id]?.isNotEmpty ?? false;
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
          final toplamStok = totalGirdi - totalCikti;

          details = {
            tr('warehouses.table.phone'): depo.telefon.isNotEmpty
                ? depo.telefon
                : '-',
            tr('warehouses.table.status'): depo.aktifMi
                ? tr('common.active')
                : tr('common.passive'),
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
            tr('warehouses.detail.total_stock'): FormatYardimcisi.sayiFormatla(
              toplamStok,
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
            title: tr('warehouses.detail.timeline'),
            headers: [
              tr('warehouses.detail.transaction'), // İşlem
              tr('warehouses.detail.related_account'), // İlgili Hesap
              tr('warehouses.detail.date'), // Tarih
              tr('warehouses.detail.warehouse'), // Depo
              tr('warehouses.detail.quantity'), // Miktar
              tr('warehouses.detail.unit'), // Birim
              tr('products.table.unit_price'), // Birim Fiyat
              tr('products.table.unit_price_vat'), // Birim Fiyat (VD)
              tr('products.table.total_price'), // Toplam Fiyat
              tr('warehouses.detail.description'), // Açıklama
              tr('warehouses.detail.user'), // Kullanıcı
            ],
            // Adjusted flex to accommodate "Related Account"
            // Previous: [3, 3, 3, 2, 2, 4, 2]
            // New: [3, 4, 3, 3, 2, 2, 4, 2]
            // columnFlex: [3, 4, 3, 3, 2, 2, 4, 2], // Handled by header name in print service
            data: transactions.map((t) {
              final customType = t['customTypeLabel'] as String?;
              final sourceId = t['source_warehouse_id'] as int?;
              final destId = t['dest_warehouse_id'] as int?;
              final relatedPartyName = t['relatedPartyName'] as String?;

              // Exact UI Logic Replication
              // 1. Get raw professional label
              String displayLabel = IslemTuruRenkleri.getProfessionalLabel(
                customType ?? '',
                context: 'stock',
              );

              // 2. Logic Override for Sevkiyat
              if (customType == 'Sevkiyat') {
                if (destId == depo.id) {
                  displayLabel = tr('warehouses.detail.type_in');
                } else if (sourceId == depo.id) {
                  displayLabel = tr('warehouses.detail.type_out');
                }
              }

              // 3. Final Translation (IslemCeviriYardimcisi.cevir)
              // This handles cases like 'Satış Yapıldı' which comes from getProfessionalLabel
              final finalLabel = IslemCeviriYardimcisi.cevir(displayLabel);

              final String transactionSourceSuffix =
                  t['sourceSuffix']?.toString() ?? '';
              final String transactionSourceText =
                  transactionSourceSuffix.trim().isNotEmpty
                  ? ' ${IslemCeviriYardimcisi.parantezliKaynakKisaltma(transactionSourceSuffix.trim())}'
                  : '';

              final unitPrice = (t['unitPrice'] as num? ?? 0.0).toDouble();
              final unitPriceVat = (t['unitPriceVat'] as num? ?? 0.0)
                  .toDouble();
              final quantity =
                  double.tryParse(t['quantity']?.toString() ?? '0') ?? 0.0;
              final totalPriceVat = quantity * unitPriceVat;

              return <String>[
                '$finalLabel$transactionSourceText',
                relatedPartyName ?? '-',
                t['date']?.toString() ?? '',
                depo.ad,
                FormatYardimcisi.sayiFormatla(
                  t['quantity']?.toString(),
                  binlik: _genelAyarlar.binlikAyiraci,
                  ondalik: _genelAyarlar.ondalikAyiraci,
                  decimalDigits: _genelAyarlar.miktarOndalik,
                ),
                t['unit']?.toString() ?? '',
                '${FormatYardimcisi.sayiFormatla(unitPrice, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} TRY',
                '${FormatYardimcisi.sayiFormatla(unitPriceVat, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} TRY',
                '${FormatYardimcisi.sayiFormatla(totalPriceVat, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} TRY',
                t['description']?.toString() ?? '',
                t['user']?.toString() ?? '',
              ];
            }).toList(),
          );
        }

        rows.add(
          ExpandableRowData(
            mainRow: mainRow,
            details: details, // Empty map = No info card
            transactions: txTable,
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
            title: tr('warehouses.title'),
            headers: [
              tr('language.table.orderNo'),
              tr('warehouses.table.code'),
              tr('warehouses.table.name'),
              tr('warehouses.table.address'),
              tr('warehouses.table.responsible'),
              tr('warehouses.table.phone'),
              tr('warehouses.table.status'),
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
          Expanded(child: _buildTransactionFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildUserFilter(width: double.infinity)),
        ],
      ),
    );
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
                  ? const Color(0xFF2C3E50)
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
                    ? '${DateFormat('dd.MM.yyyy').format(_startDate!)} - ${DateFormat('dd.MM.yyyy').format(_endDate!)}'
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
                  });
                  _detailFutures.clear(); // Clear cache on filter change
                  _fetchDepolar();
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

  Widget _buildStatusFilter({double? width}) {
    return CompositedTransformTarget(
      link: _statusLayerLink,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
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
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: () {
                    setState(() {
                      _selectedStatus = null;
                    });
                    _detailFutures.clear(); // Clear cache on filter change
                    _fetchDepolar();
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

    final String displayLabel = value == null
        ? label
        : IslemCeviriYardimcisi.cevir(label);
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: () {
        setState(() {
          _selectedStatus = value;
          _isStatusFilterExpanded = false;
        });
        _closeOverlay();
        _detailFutures.clear(); // Clear cache on filter change
        _fetchDepolar();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFE6F4EA) : Colors.transparent,
        child: Text(
          '$displayLabel ($count)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF1E7E34) : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionFilter({double? width}) {
    return CompositedTransformTarget(
      link: _transactionLayerLink,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
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
                Icons.swap_vert_rounded,
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
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: () {
                    setState(() {
                      _selectedTransactionType = null;
                    });
                    _detailFutures.clear(); // Clear cache on filter change
                    _fetchDepolar();
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

  Widget _buildTransactionOption(String? value, String label) {
    // Only highlight if value matches exactly
    final isSelected = _selectedTransactionType == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['islem_turleri']?[value] ?? 0);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: () {
        setState(() {
          _selectedTransactionType = value;
          _isTransactionFilterExpanded = false;
        });
        _closeOverlay();
        _detailFutures.clear(); // Clear cache on filter change
        _fetchDepolar();
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

  Widget _buildUserFilter({double? width}) {
    return CompositedTransformTarget(
      link: _userLayerLink,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () {
          if (_isUserFilterExpanded) {
            _closeOverlay();
          } else {
            _showUserOverlay();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 180,
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
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: () {
                    setState(() {
                      _selectedUser = null;
                    });
                    _detailFutures.clear(); // Clear cache on filter change
                    _fetchDepolar();
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

  Widget _buildUserOption(String? value, String label) {
    final isSelected = _selectedUser == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['kullanicilar']?[value] ?? 0);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: () {
        setState(() {
          _selectedUser = value;
          _isUserFilterExpanded = false;
        });
        _closeOverlay();
        _detailFutures.clear(); // Clear cache on filter change
        _fetchDepolar();
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

  Widget _buildWarehouseFilter({double? width}) {
    return CompositedTransformTarget(
      link: _warehouseLayerLink,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () {
          if (_isWarehouseFilterExpanded) {
            _closeOverlay();
          } else {
            _showWarehouseOverlay();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 200,
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
                      ? 'Depo'
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
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: () {
                    setState(() {
                      _selectedWarehouse = null;
                    });
                    _detailFutures.clear(); // Clear cache on filter change
                    _fetchDepolar();
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

  Widget _buildDesktopView(
    List<DepoModel> depolar,
    BoxConstraints constraints,
  ) {
    final bool allSelected =
        depolar.isNotEmpty && depolar.every((d) => _selectedIds.contains(d.id));

    // Determine if we should use flex layout or scrollable layout
    // Threshold based on sum of minimum comfortable widths
    const double minRequiredWidth = 1000;
    final bool useFlex = constraints.maxWidth >= minRequiredWidth;

    return GenisletilebilirTablo<DepoModel>(
      expandOnRowTap: false,
      isRowSelected: (item, index) => _selectedIds.contains(item.id),
      getDetailItemCount: (depo) =>
          _visibleTransactionIds[depo.id]?.length ?? 0,
      onRowTap: null, // Focus handled by table
      title: tr('warehouses.title'),
      searchFocusNode: _searchFocusNode,
      onClearSelection: _clearAllTableSelections,
      onFocusedRowChanged: (item, index) {
        if (item != null) {
          setState(() => _selectedRowId = item.id);
        }
      },
      headerWidget: _buildFilters(),
      totalRecords: _totalRecords,
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
        _detailFutures.clear(); // Clear cache on page change
        _fetchDepolar();
      },
      onSearch: (query) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          setState(() {
            _searchQuery = query;
            _currentPage = 1;
          });
          _detailFutures.clear(); // Clear cache on search change
          _fetchDepolar(showLoading: false);
        });
      },
      selectionWidget: _selectedIds.isNotEmpty
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                onTap: _deleteSelectedDepolar,
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
              )),
            )
          : null,
      expandAll: _keepDetailsOpen,
      expandedIndices: {..._autoExpandedIndices, ..._expandedIndices},
      onExpansionChanged: (index, isExpanded) {
        setState(() {
          if (isExpanded) {
            _expandedIndices.add(index);
          } else {
            _expandedIndices.remove(index);
          }
        });
      },
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
                    const SizedBox(width: 8),
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
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
              onTap: _showShipmentPage,
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
                      Icons.local_shipping_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('warehouses.shipment'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('common.key.f10'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
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
                      tr('warehouses.add'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
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
            )),
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
            width: 120,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['code'] == true)
          GenisletilebilirTabloKolon(
            label: tr('warehouses.table.code'),
            width: 150,
            alignment: Alignment.center,
            allowSorting: true,
          ),
        if (_columnVisibility['name'] == true)
          GenisletilebilirTabloKolon(
            label: tr('warehouses.table.name'),
            width: 180,
            alignment: Alignment.centerLeft,
            allowSorting: true,
            flex: useFlex ? 2 : null,
          ),
        if (_columnVisibility['address'] == true)
          GenisletilebilirTabloKolon(
            label: tr('warehouses.table.address'),
            width: 250,
            alignment: Alignment.centerLeft,
            allowSorting: true,
            flex: useFlex ? 3 : null,
          ),
        if (_columnVisibility['responsible'] == true)
          GenisletilebilirTabloKolon(
            label: tr('warehouses.table.responsible'),
            width: 120,
            alignment: Alignment.centerLeft,
            allowSorting: true,
            flex: useFlex ? 2 : null,
          ),
        if (_columnVisibility['phone'] == true)
          GenisletilebilirTabloKolon(
            label: tr('warehouses.table.phone'),
            width: 120,
            alignment: Alignment.centerLeft,
            allowSorting: true,
            flex: useFlex ? 2 : null,
          ),
        if (_columnVisibility['status'] == true)
          GenisletilebilirTabloKolon(
            label: tr('warehouses.table.status'),
            width: 120,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        GenisletilebilirTabloKolon(
          label: tr('warehouses.table.actions'),
          width: 120,
          alignment: Alignment.centerLeft,
        ),
      ],

      data: depolar,
      rowBuilder: (context, depo, index, isExpanded, toggleExpand) {
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
                  value: _selectedIds.contains(depo.id),
                  onChanged: (val) => _onSelectRow(val, depo.id),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
                ),
              ),
            ),
            if (_columnVisibility['order_no'] == true)
              _buildCell(
                width: 120,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    InkWell(
                      mouseCursor: WidgetStateMouseCursor.clickable,
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
                      text: depo.id.toString(),
                      query: _searchQuery,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            if (_columnVisibility['code'] == true)
              _buildCell(
                width: 150,
                alignment: Alignment.center,
                child: HighlightText(
                  text: depo.kod,
                  query: _searchQuery,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
              ),
            if (_columnVisibility['name'] == true)
              _buildCell(
                width: 180,
                flex: useFlex ? 2 : null,
                child: HighlightText(
                  text: depo.ad,
                  query: _searchQuery,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
              ),
            if (_columnVisibility['address'] == true)
              _buildCell(
                width: 250,
                flex: useFlex ? 3 : null,
                child: HighlightText(
                  text: depo.adres,
                  query: _searchQuery,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
              ),
            if (_columnVisibility['responsible'] == true)
              _buildCell(
                width: 150,
                flex: useFlex ? 2 : null,
                child: HighlightText(
                  text: depo.sorumlu,
                  query: _searchQuery,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
              ),
            if (_columnVisibility['phone'] == true)
              _buildCell(
                width: 150,
                flex: useFlex ? 2 : null,
                child: HighlightText(
                  text: depo.telefon,
                  query: _searchQuery,
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                ),
              ),
            if (_columnVisibility['status'] == true)
              _buildCell(
                width: 120,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: depo.aktifMi
                        ? const Color(0xFFE6F4EA)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: depo.aktifMi
                            ? const Color(0xFF28A745)
                            : const Color(0xFF757575),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: HighlightText(
                          text: depo.aktifMi
                              ? tr('common.active')
                              : tr('common.passive'),
                          query: _searchQuery,
                          style: TextStyle(
                            color: depo.aktifMi
                                ? const Color(0xFF1E7E34)
                                : const Color(0xFF757575),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            _buildCell(width: 120, child: _buildPopupMenu(depo)),
          ],
        );
      },
      detailBuilder: (context, depo) {
        final selectedIds = _selectedDetailIds[depo.id] ?? {};
        final visibleIds = _visibleTransactionIds[depo.id] ?? [];
        final allSelected =
            visibleIds.isNotEmpty && selectedIds.length == visibleIds.length;

        // Depo ilk harfi (tıpkı kasalar_sayfasi.dart gibi)
        final String firstChar = depo.ad.isNotEmpty
            ? depo.ad[0].toUpperCase()
            : '?';

        return Container(
          padding: const EdgeInsets.only(
            left: 60,
            right: 24,
            top: 24,
            bottom: 24,
          ),
          color: Colors.grey.shade50,
          child: FutureBuilder<List<dynamic>>(
            key: ValueKey('depo_detail_${depo.id}_$_detailRefreshKey'),
            future: _detailFutures.putIfAbsent(
              depo.id,
              () => Future.wait([
                DepolarVeritabaniServisi().depoIslemleriniGetir(
                  depo.id,
                  aramaTerimi: _searchQuery,
                  baslangicTarihi: _startDate,
                  bitisTarihi: _endDate,
                  islemTuru: _selectedTransactionType,
                  kullanici: _selectedUser,
                ),
                DepolarVeritabaniServisi().depoIstatistikleriniGetir(depo.id),
              ]),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: Text('${tr('common.error')}: ${snapshot.error}'),
                  ),
                );
              }

              final transactions =
                  (snapshot.data?[0] as List<Map<String, dynamic>>?) ?? [];

              // Capture visible transaction IDs for keyboard navigation
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _visibleTransactionIds[depo.id] = transactions
                      .map((t) => t['id'] as int)
                      .toList();
                }
              });

              final stats = (snapshot.data?[1] as Map<String, dynamic>?) ?? {};

              final double toplamMiktar =
                  (stats['toplamUrunMiktari'] as num?)?.toDouble() ?? 0.0;
              final double toplamGirdi =
                  (stats['toplamGirdi'] as num?)?.toDouble() ?? 0.0;
              final double toplamCikti =
                  (stats['toplamCikti'] as num?)?.toDouble() ?? 0.0;
              final int urunSayisi = (stats['urunSayisi'] as int?) ?? 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. White Box: Header Info + Stock Summary + Features
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
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
                            // Depo Icon/Image
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
                                    text: depo.ad,
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
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: HighlightText(
                                          text: depo.kod,
                                          query: _searchQuery,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (depo.sorumlu.isNotEmpty) ...[
                                        Icon(
                                          Icons.person_outline,
                                          size: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        HighlightText(
                                          text: depo.sorumlu,
                                          query: _searchQuery,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (depo.adres.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: HighlightText(
                                            text: depo.adres,
                                            query: _searchQuery,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                            // maxLines/overflow not directly supported in constructor matching exact signature,
                                            // but internal implementation uses them or we can rely on parent.
                                            // Checking HighlightText again: it uses maxLines: 1 internally. Matches usage.
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  // Toplam Stok Chip - Tıklanabilir
                                  InkWell(
                                    mouseCursor: WidgetStateMouseCursor.clickable,
                                    onTap: () =>
                                        _showWarehouseStockDialog(depo),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: toplamMiktar >= 0
                                                ? const Color(0xFFE6F4EA)
                                                : const Color(0xFFF8D7DA),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                tr(
                                                  'warehouses.detail.total_stock',
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              HighlightText(
                                                text:
                                                    FormatYardimcisi.sayiFormatla(
                                                      toplamMiktar,
                                                      binlik: _genelAyarlar
                                                          .binlikAyiraci,
                                                      ondalik: _genelAyarlar
                                                          .ondalikAyiraci,
                                                      decimalDigits:
                                                          _genelAyarlar
                                                              .miktarOndalik,
                                                    ),
                                                query: _searchQuery,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: toplamMiktar >= 0
                                                      ? const Color(0xFF059669)
                                                      : const Color(0xFFC62828),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.visibility_outlined,
                                                size: 12,
                                                color: Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              HighlightText(
                                                text:
                                                    '($urunSayisi ${tr('common.product')})',
                                                query: _searchQuery,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Stok Özet Table View (Sağ Üst Köşe)
                            Container(
                              width: 250,
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
                                        width: 90,
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
                                          tr(
                                            'products.transaction.type.input',
                                          ), // Girdi
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 90,
                                        child: HighlightText(
                                          text: FormatYardimcisi.sayiFormatla(
                                            toplamGirdi,
                                            binlik: _genelAyarlar.binlikAyiraci,
                                            ondalik:
                                                _genelAyarlar.ondalikAyiraci,
                                            decimalDigits:
                                                _genelAyarlar.miktarOndalik,
                                          ),
                                          query: _searchQuery,
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF059669), // Yeşil
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
                                          ), // Çıktı
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 90,
                                        child: HighlightText(
                                          text: FormatYardimcisi.sayiFormatla(
                                            toplamCikti,
                                            binlik: _genelAyarlar.binlikAyiraci,
                                            ondalik:
                                                _genelAyarlar.ondalikAyiraci,
                                            decimalDigits:
                                                _genelAyarlar.miktarOndalik,
                                          ),
                                          query: _searchQuery,
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFC62828), // Kırmızı
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
                                        width: 90,
                                        child: HighlightText(
                                          text: FormatYardimcisi.sayiFormatla(
                                            toplamMiktar,
                                            binlik: _genelAyarlar.binlikAyiraci,
                                            ondalik:
                                                _genelAyarlar.ondalikAyiraci,
                                            decimalDigits:
                                                _genelAyarlar.miktarOndalik,
                                          ),
                                          query: _searchQuery,
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: toplamMiktar >= 0
                                                ? const Color(0xFF059669)
                                                : const Color(0xFFC62828),
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
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 16),
                        // FEATURES Section (Telefon ve Ek Bilgiler)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildFeatureItemWithIcon(
                                tr('warehouses.table.phone'),
                                depo.telefon.isNotEmpty ? depo.telefon : '-',
                                icon: Icons.phone_outlined,
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              child: _buildFeatureItemWithIcon(
                                tr('warehouses.table.status'),
                                depo.aktifMi
                                    ? tr('common.active')
                                    : tr('common.passive'),
                                icon: depo.aktifMi
                                    ? Icons.check_circle_outline
                                    : Icons.cancel_outlined,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Transactions Section Title
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: allSelected,
                                onChanged: (val) =>
                                    _onSelectAllDetails(depo.id, val),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFD1D1D1),
                                  width: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Text(
                              tr('warehouses.detail.timeline'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Transactions Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 20), // Checkbox alanı
                        const SizedBox(width: 24), // Checkbox-sonrası boşluk
                        if (_columnVisibility['dt_transaction'] == true)
                          Expanded(
                            flex: 3, // İşlem column width
                            child: _buildDetailHeader(
                              tr('warehouses.detail.transaction'), // İşlem
                            ),
                          ),
                        if (_columnVisibility['dt_related_account'] ==
                            true) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 4, // İlgili Hesap column width
                            child: _buildDetailHeader(
                              tr('warehouses.detail.related_account'),
                            ),
                          ),
                        ],
                        if (_columnVisibility['dt_date'] == true) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 4, // Tarih column width
                            child: _buildDetailHeader(
                              tr('warehouses.detail.date'), // Tarih
                            ),
                          ),
                        ],
                        if (_columnVisibility['dt_warehouse'] == true) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3, // Depo column width
                            child: _buildDetailHeader(
                              tr('warehouses.detail.warehouse'), // Depo
                            ),
                          ),
                        ],
                        if (_columnVisibility['dt_quantity'] == true) ...[
                          const SizedBox(width: 16), // Spacing
                          Expanded(
                            flex: 2,
                            child: _buildDetailHeader(
                              tr('warehouses.detail.quantity'), // Miktar
                              alignRight: true,
                            ),
                          ),
                        ],
                        if (_columnVisibility['dt_unit'] == true) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2, // Birim column width
                            child: _buildDetailHeader(
                              tr('warehouses.detail.unit'), // Birim
                            ),
                          ),
                        ],
                        if (_columnVisibility['dt_unit_price'] == true) ...[
                          const SizedBox(width: 16), // Spacing
                          Expanded(
                            flex: 3, // Birim Fiyat
                            child: _buildDetailHeader(
                              tr('products.table.unit_price'), // Birim Fiyat
                              alignRight: true,
                            ),
                          ),
                        ],
                        if (_columnVisibility['dt_unit_price_vat'] == true) ...[
                          const SizedBox(width: 16), // Spacing
                          Expanded(
                            flex: 3, // Birim Fiyat (VD)
                            child: _buildDetailHeader(
                              tr(
                                'products.table.unit_price_vat',
                              ), // Birim Fiyat (VD)
                              alignRight: true,
                            ),
                          ),
                        ],
                        if (_columnVisibility['dt_total_price'] == true) ...[
                          const SizedBox(width: 16), // Spacing
                          Expanded(
                            flex: 4, // Toplam Fiyat
                            child: _buildDetailHeader(
                              tr('products.table.total_price'), // Toplam Fiyat
                              alignRight: true,
                            ),
                          ),
                        ],
                        if (_columnVisibility['dt_description'] == true) ...[
                          const SizedBox(width: 32), // Spacing
                          Expanded(
                            flex: 4, // Açıklama column width (Reduced)
                            child: _buildDetailHeader(
                              tr('warehouses.detail.description'), // Açıklama
                            ),
                          ),
                        ],
                        if (_columnVisibility['dt_user'] == true) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: _buildDetailHeader(
                              tr('warehouses.detail.user'), // Kullanıcı
                            ),
                          ),
                        ],
                        const SizedBox(width: 108), // Actions alanı
                      ],
                    ),
                  ),

                  // Transactions List
                  Column(
                    children: transactions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final tx = entry.value;
                      final isLast = index == transactions.length - 1;
                      final val = selectedIds.contains(tx['id']);

                      final sourceId = tx['source_warehouse_id'] as int?;
                      final destId = tx['dest_warehouse_id'] as int?;
                      final customType = tx['customTypeLabel'] as String?;
                      final relatedPartyName =
                          tx['relatedPartyName'] as String?;

                      // Use raw type for coloring to ensure correct color detection by IslemTuruRenkleri
                      final String coloringLabel = customType ?? '';

                      // For display, use professional label
                      String displayLabel =
                          IslemTuruRenkleri.getProfessionalLabel(
                            customType ?? '',
                            context: 'stock',
                          );

                      bool displayIsIncoming = tx['isIncoming'] as bool;

                      // Sevkiyat (Girdi/Çıktı) Logic
                      if (customType == 'Sevkiyat') {
                        if (destId == depo.id) {
                          displayLabel = tr('warehouses.detail.type_in');
                          displayIsIncoming = true;
                        } else if (sourceId == depo.id) {
                          displayLabel = tr('warehouses.detail.type_out');
                          displayIsIncoming = false;
                        }
                      }

                      final focusScope = TableDetailFocusScope.of(context);
                      final isFocused = focusScope?.focusedDetailIndex == index;

                      final unitPrice = (tx['unitPrice'] as num? ?? 0.0)
                          .toDouble();
                      final unitPriceVat = (tx['unitPriceVat'] as num? ?? 0.0)
                          .toDouble();

                      return Column(
                        children: [
                          _buildTransactionRow(
                            id: tx['id'],
                            isSelected: val,
                            isFocused: isFocused,
                            onChanged: (val) =>
                                _onSelectDetailRow(depo.id, tx['id'], val),
                            onFocus: () {
                              // CRITICAL: Call setFocusedDetailIndex to highlight this row
                              focusScope?.setFocusedDetailIndex?.call(index);
                              // Seçili detay transaction bilgisini kaydet
                              setState(() {
                                _selectedDetailTransactionId = tx['id'];
                                _selectedDetailCustomTypeLabel = customType;
                                _selectedDetailProductCode = tx['product_code']
                                    ?.toString();
                                _selectedDetailProductName = tx['product_name']
                                    ?.toString();
                                _selectedDetailWarehouse = depo.ad;
                              });
                            },
                            isIncoming: displayIsIncoming,
                            name: displayLabel,
                            product: tx['product']?.toString() ?? '',
                            quantity: tx['quantity']?.toString() ?? '',
                            unit: tx['unit']?.toString() ?? '',
                            date: tx['date']?.toString() ?? '',
                            user: (tx['user']?.toString() ?? '').isEmpty
                                ? 'Sistem'
                                : tx['user'].toString(),
                            description: tx['description']?.toString() ?? '',
                            customTypeLabel: coloringLabel,
                            sourceSuffix: tx['sourceSuffix']?.toString(),
                            productCode: tx['product_code']?.toString(),
                            productName: tx['product_name']?.toString(),
                            warehouse: depo.ad,
                            relatedAccount: relatedPartyName,
                            unitPrice: unitPrice,
                            unitPriceVat: unitPriceVat,
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
                  ),

                  if (transactions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Text(
                          tr('common.no_data'),
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
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
    required bool isFocused,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onFocus,
    required bool isIncoming,
    required String name,
    required String product,
    required String quantity,
    required String unit,
    required String date,
    required String user,
    required String description,
    String? customTypeLabel,
    String? sourceSuffix,
    String? productCode,
    String? productName,
    required String warehouse,
    String? relatedAccount,
    required double unitPrice,
    required double unitPriceVat,
  }) {
    // Calculate Totals
    final double qty = double.tryParse(quantity) ?? 0.0;
    final double totalPrice = qty * unitPrice;
    final double totalPriceVat = qty * unitPriceVat;

    return Builder(
      builder: (ctx) {
        // Auto-scroll when focused
        if (isFocused) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ctx.mounted) {
              Scrollable.ensureVisible(
                ctx,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
              );
            }
          });
        }
        final bool hideActionMenuForOpeningStock =
            customTypeLabel?.contains('Açılış Stoğu') == true;
        return InkWell(
          onTap: onFocus,
          mouseCursor: SystemMouseCursors.click, // Show pointer on hover
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFC8E6C9) // Soft Green 100 for selection
                  : (isFocused
                        ? const Color(0xFFE8F5E9) // Soft Green 50 - focus color
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 8,
            ), // Added horizontal padding for background
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Checkbox - NOT focusable via keyboard
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SizedBox(
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
                ),
                const SizedBox(
                  width: 16,
                ), // Adjusted width since we added horizontal padding
                if (_columnVisibility['dt_transaction'] == true)
                  Expanded(
                    flex: 3, // İşlem column width
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
                                text: IslemCeviriYardimcisi.cevir(name),
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
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _buildCompactDetailItem(
                      null,
                      relatedAccount ?? '-',
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_columnVisibility['dt_date'] == true) ...[
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: _buildCompactDetailItem(null, date)),
                ],
                if (_columnVisibility['dt_warehouse'] == true) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: _buildCompactDetailItem(null, warehouse),
                  ),
                ],
                if (_columnVisibility['dt_quantity'] == true) ...[
                  const SizedBox(width: 16), // Spacing
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildCompactDetailItem(
                        null,
                        FormatYardimcisi.sayiFormatla(
                          quantity,
                          binlik: _genelAyarlar.binlikAyiraci,
                          ondalik: _genelAyarlar.ondalikAyiraci,
                          decimalDigits: _genelAyarlar.miktarOndalik,
                        ),
                        color: const Color(0xFFF39C12),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (_columnVisibility['dt_unit'] == true) ...[
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _buildCompactDetailItem(null, unit)),
                ],
                if (_columnVisibility['dt_unit_price'] == true) ...[
                  const SizedBox(width: 16), // Spacing
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildCompactDetailItem(
                        null,
                        '${FormatYardimcisi.sayiFormatla(unitPrice, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} TRY',
                        color: const Color(0xFF2C3E50),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (_columnVisibility['dt_unit_price_vat'] == true) ...[
                  const SizedBox(width: 16), // Spacing
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildCompactDetailItem(
                        null,
                        '${FormatYardimcisi.sayiFormatla(unitPriceVat, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} TRY',
                        color: const Color(0xFF2C3E50),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (_columnVisibility['dt_total_price'] == true) ...[
                  const SizedBox(width: 16), // Spacing
                  Expanded(
                    flex: 4,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          HighlightText(
                            text:
                                '${FormatYardimcisi.sayiFormatla(totalPriceVat, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${tr('common.currency.try')}',
                            query: _searchQuery,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF39C12), // Orange
                            ),
                          ),
                          Text(
                            '${FormatYardimcisi.sayiFormatla(totalPrice, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${tr('common.currency.try')}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_columnVisibility['dt_description'] == true) ...[
                  const SizedBox(width: 32), // Spacing
                  Expanded(
                    flex: 4,
                    child: _buildCompactDetailItem(null, description),
                  ),
                ],
                if (_columnVisibility['dt_user'] == true) ...[
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _buildCompactDetailItem(null, user)),
                ],
                // Action Menu
                const SizedBox(width: 60),
                SizedBox(
                  width: 48,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: hideActionMenuForOpeningStock
                        ? const SizedBox.shrink()
                        : _buildTransactionPopupMenu(
                            id,
                            customTypeLabel,
                            productCode,
                            productName,
                            warehouse,
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

  Future<void> _showEditSevkiyatDialog(int id) async {
    try {
      // Veriyi getir
      final data = await DepolarVeritabaniServisi().sevkiyatGetir(id);
      if (data == null) {
        if (!mounted) return;
        MesajYardimcisi.hataGoster(context, tr('common.error.generic'));
        return;
      }

      if (!mounted) return;

      // Sayfayı aç
      final bool? result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SevkiyatOlusturSayfasi(
            depolar: _cachedDepolar,
            editingShipmentId: id,
            initialData: data,
          ),
        ),
      );

      if (result == true) {
        setState(() {
          _detailRefreshKey++;
          _detailFutures.clear();
        });
        await _fetchDepolar();
      }
    } catch (e) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  Widget _buildTransactionPopupMenu(
    int id, [
    String? customTypeLabel,
    String? productCode,
    String? productName,
    String? warehouse,
  ]) {
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
        constraints: const BoxConstraints(minWidth: 160),
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
        onSelected: (value) async {
          if (value == 'edit') {
            final handled = await _openAlisSatisDuzenlemeFromShipment(id);
            if (!mounted) return;
            if (handled) return;
            if (customTypeLabel?.contains('Sevkiyat') == true) {
              _showEditSevkiyatDialog(id);
            } else if (customTypeLabel != null &&
                (customTypeLabel.contains('Giriş') ||
                    customTypeLabel.contains('Çıkış') ||
                    customTypeLabel.contains('Devir'))) {
              try {
                // 1. Fetch Shipment Data First
                final shipmentData = await DepolarVeritabaniServisi()
                    .sevkiyatGetir(id);

                if (shipmentData == null) {
                  if (mounted) {
                    MesajYardimcisi.hataGoster(
                      context,
                      tr('common.error.generic'),
                    );
                  }
                  return;
                }

                // 2. Determine Product Code
                String? targetProductCode = productCode;
                if (targetProductCode == null || targetProductCode.isEmpty) {
                  final items = shipmentData['items'] as List?;
                  if (items != null && items.isNotEmpty) {
                    final firstItem = items.first as Map<String, dynamic>;
                    targetProductCode = firstItem['code']?.toString();
                  }
                }

                if (targetProductCode == null || targetProductCode.isEmpty) {
                  if (mounted) {
                    MesajYardimcisi.hataGoster(
                      context,
                      tr(
                        'productions.make.enter_code',
                      ), // "Please enter code" or similar fallback
                    );
                  }
                  return;
                }

                // 3. Fetch UrunModel
                final urun = await UrunlerVeritabaniServisi().urunGetir(
                  kod: targetProductCode,
                );

                if (urun != null && mounted) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DevirYapSayfasi(
                        urun: urun,
                        editingShipmentId: id,
                        initialData: shipmentData,
                      ),
                    ),
                  );
                  if (result == true) {
                    _detailRefreshKey++;
                    _detailFutures.clear();
                    await _fetchDepolar();
                  }
                } else if (mounted) {
                  MesajYardimcisi.hataGoster(
                    context,
                    tr('shipment.form.error.product_not_found'),
                  );
                }
              } catch (e) {
                if (mounted) {
                  MesajYardimcisi.hataGoster(
                    context,
                    '${tr('common.error')}: $e',
                  );
                }
              }
            } else if (customTypeLabel != null &&
                customTypeLabel.contains('Üretim')) {
              // Üretim işlemi için düzenleme
              try {
                final shipmentData = await DepolarVeritabaniServisi()
                    .sevkiyatGetir(id);

                if (shipmentData == null) {
                  if (mounted) {
                    MesajYardimcisi.hataGoster(
                      context,
                      tr('common.error.generic'),
                    );
                  }
                  return;
                }

                // Ürün kodunu bul
                String? targetProductCode = productCode;
                if (targetProductCode == null || targetProductCode.isEmpty) {
                  final items = shipmentData['items'] as List?;
                  if (items != null && items.isNotEmpty) {
                    final firstItem = items.first as Map<String, dynamic>;
                    targetProductCode = firstItem['code']?.toString();
                  }
                }

                if (targetProductCode == null || targetProductCode.isEmpty) {
                  if (mounted) {
                    MesajYardimcisi.hataGoster(
                      context,
                      tr('productions.make.enter_code'),
                    );
                  }
                  return;
                }

                // UretimModel'i bul
                final uretimler = await UretimlerVeritabaniServisi()
                    .uretimleriGetir(
                      aramaTerimi: targetProductCode,
                      sayfaBasinaKayit: 10,
                    );

                if (uretimler.isNotEmpty && mounted) {
                  final uretimModel = uretimler.firstWhere(
                    (u) => u.kod == targetProductCode,
                    orElse: () => uretimler.first,
                  );
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UretimYapSayfasi(
                        initialModel: uretimModel,
                        editingTransactionId: id,
                        initialData: shipmentData,
                      ),
                    ),
                  );
                  if (result == true) {
                    _detailRefreshKey++;
                    _detailFutures.clear();
                    await _fetchDepolar();
                  }
                } else if (mounted) {
                  MesajYardimcisi.hataGoster(
                    context,
                    tr('shipment.form.error.product_not_found'),
                  );
                }
              } catch (e) {
                if (mounted) {
                  MesajYardimcisi.hataGoster(
                    context,
                    '${tr('common.error')}: $e',
                  );
                }
              }
            } else {
              MesajYardimcisi.bilgiGoster(
                context,
                tr('common.feature_coming_soon'),
              );
            }
          } else if (value == 'delete') {
            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: true,
              barrierColor: Colors.black.withValues(alpha: 0.35),
              builder: (context) => OnayDialog(
                baslik: tr('common.delete'),
                mesaj: tr('common.confirm_delete'),
                onayButonMetni: tr('common.delete'),
                iptalButonMetni: tr('common.cancel'),
                isDestructive: true,
                onOnay: () async {
                  await DepolarVeritabaniServisi().sevkiyatSil(id);
                  setState(() {
                    _detailRefreshKey++;
                    _detailFutures.clear();
                  });
                  _fetchDepolar();
                },
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildCompactDetailItem(
    IconData? icon,
    String text, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: HighlightText(
              text: text,
              query: _searchQuery,
              style: TextStyle(
                fontSize: 11,
                color: color ?? Colors.black87,
                fontWeight: fontWeight ?? FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(String text, {bool alignRight = false}) {
    return HighlightText(
      text: text,
      query: _searchQuery,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade600,
      ),
      maxLines: 1,
    );
  }

  Widget _buildPopupMenu(DepoModel depo) {
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
            value: depo.aktifMi ? 'deactivate' : 'activate',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  depo.aktifMi
                      ? Icons.toggle_on_outlined
                      : Icons.toggle_off_outlined,
                  size: 20,
                  color: const Color(0xFF2C3E50),
                ),
                const SizedBox(width: 12),
                Text(
                  depo.aktifMi
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
            _showEditDialog(depo);
          } else if (value == 'deactivate') {
            _depoDurumDegistir(depo, false);
          } else if (value == 'activate') {
            _depoDurumDegistir(depo, true);
          } else if (value == 'delete') {
            _deleteDepo(depo);
          }
        },
      ),
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
        mouseCursor: WidgetStateMouseCursor.clickable,
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
        mouseCursor: WidgetStateMouseCursor.clickable,
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
    if (_selectedTransactionType != null) count++;
    if (_selectedUser != null) count++;
    return count;
  }

  Widget _buildMobileTopActionRow() {
    final double width = MediaQuery.of(context).size.width;
    final bool isNarrow = width < 360;
    final String shipmentLabel = isNarrow
        ? 'Sevkiyat'
        : tr('warehouses.shipment');
    final String addLabel = isNarrow ? 'Ekle' : tr('warehouses.add');
    final String printTooltip =
        _selectedIds.isNotEmpty ||
            _selectedDetailIds.values.any((s) => s.isNotEmpty)
        ? tr('common.print_selected')
        : tr('common.print_list');

    return Row(
      children: [
        Expanded(
          child: _buildMobileActionButton(
            label: shipmentLabel,
            icon: Icons.local_shipping_outlined,
            color: const Color(0xFFF39C12),
            textColor: Colors.white,
            borderColor: Colors.transparent,
            onTap: _showShipmentPage,
            height: 40,
            iconSize: 16,
            fontSize: 12,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
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
                Expanded(
                  child: _buildTransactionFilter(width: double.infinity),
                ),
                const SizedBox(width: 12),
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
            mouseCursor: WidgetStateMouseCursor.clickable,
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
                                        mouseCursor: WidgetStateMouseCursor.clickable,
                                        dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
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
                                            _currentPage = 1;
                                          });
                                          _detailFutures.clear();
                                          _fetchDepolar(showLoading: false);
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
                                      child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                                        onTap: _deleteSelectedDepolar,
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
                                      )),
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

  Widget _buildMobileView(List<DepoModel> filteredDepolar) {
    final int totalRecords = _totalRecords > 0
        ? _totalRecords
        : filteredDepolar.length;
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
          _fetchDepolar(showLoading: false);
        }
      });
    }

    final int startRecordIndex = (effectivePage - 1) * safeRowsPerPage;
    final int endRecord = totalRecords == 0
        ? 0
        : (startRecordIndex + filteredDepolar.length).clamp(0, totalRecords);
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
                    tr('warehouses.title'),
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
                itemCount: filteredDepolar.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildDepoCard(filteredDepolar[index]);
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
                              _fetchDepolar(showLoading: false);
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
                              _fetchDepolar(showLoading: false);
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

  Widget _buildDepoCard(DepoModel depo) {
    final isExpanded = _expandedMobileIds.contains(depo.id);
    final bool isSelected = _selectedMobileCardId == depo.id;

    return MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedMobileCardId == depo.id) {
            _selectedMobileCardId = null;
          } else {
            _selectedMobileCardId = depo.id;
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2C3E50).withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2C3E50).withValues(alpha: 0.3)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF2C3E50).withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: isSelected ? 12 : 10,
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
                    value: _selectedIds.contains(depo.id),
                    onChanged: (v) => _onSelectRow(v, depo.id),
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
                        depo.ad,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${depo.kod} • ${depo.sorumlu}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        depo.adres,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [_buildPopupMenu(depo)],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status & Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: depo.aktifMi
                        ? const Color(0xFFE6F4EA)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    depo.aktifMi ? tr('common.active') : tr('common.passive'),
                    style: TextStyle(
                      color: depo.aktifMi
                          ? const Color(0xFF1E7E34)
                          : const Color(0xFF757575),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: const Color(0xFF2C3E50),
                      ),
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedMobileIds.remove(depo.id);
                          } else {
                            _expandedMobileIds.add(depo.id);
                          }
                        });
                      },
                    ),
                  ],
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
                        _buildMobileDetails(depo),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildMobileDetails(DepoModel depo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('warehouses.detail.timeline'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<dynamic>>(
          key: ValueKey('depo_mobile_detail_${depo.id}_$_detailRefreshKey'),
          future: _detailFutures.putIfAbsent(
            depo.id,
            () => Future.wait([
              DepolarVeritabaniServisi().depoIslemleriniGetir(
                depo.id,
                aramaTerimi: _searchQuery,
                baslangicTarihi: _startDate,
                bitisTarihi: _endDate,
                islemTuru: _selectedTransactionType,
                kullanici: _selectedUser,
              ),
              DepolarVeritabaniServisi().depoIstatistikleriniGetir(depo.id),
            ]),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text(
                '${tr('common.error')}: ${snapshot.error}',
                style: TextStyle(color: Colors.grey.shade600),
              );
            }

            final depotTransactions =
                (snapshot.data?[0] as List<Map<String, dynamic>>?) ?? [];

            if (depotTransactions.isEmpty) {
              return Text(
                tr('common.no_data'),
                style: TextStyle(color: Colors.grey.shade500),
              );
            }

            return Column(
              children: depotTransactions.map((tx) {
                return _buildMobileTransactionRow(
                  isIncoming: tx['isIncoming'] == true,
                  product: tx['product']?.toString() ?? '',
                  quantity: tx['quantity']?.toString() ?? '',
                  date: tx['date']?.toString() ?? '',
                  user: tx['user']?.toString() ?? '',
                  description: tx['description']?.toString() ?? '',
                  customTypeLabel: tx['customTypeLabel']?.toString(),
                  sourceSuffix: tx['sourceSuffix']?.toString(),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileTransactionRow({
    required bool isIncoming,
    required String product,
    required String quantity,
    required String date,
    required String user,
    required String description,
    String? customTypeLabel,
    String? sourceSuffix,
  }) {
    String displayLabel = IslemTuruRenkleri.getProfessionalLabel(
      customTypeLabel ??
          (isIncoming
              ? tr('warehouses.detail.type_in')
              : tr('warehouses.detail.type_out')),
      context: 'stock',
    );

    if (customTypeLabel == 'Sevkiyat') {
      displayLabel = isIncoming
          ? tr('warehouses.detail.type_in')
          : tr('warehouses.detail.type_out');
    }

    final String typeLabel = IslemCeviriYardimcisi.cevir(displayLabel);

    final String normalizedSourceSuffix = (sourceSuffix ?? '').trim();
    final String translatedSourceSuffix = normalizedSourceSuffix.isNotEmpty
        ? IslemCeviriYardimcisi.parantezliKaynakKisaltma(normalizedSourceSuffix)
        : '';

    final String trimmedDescription = description.trim();

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
                    Expanded(
                      child: Text(
                        product,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.scale_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      FormatYardimcisi.sayiFormatla(
                        quantity,
                        binlik: _genelAyarlar.binlikAyiraci,
                        ondalik: _genelAyarlar.ondalikAyiraci,
                        decimalDigits: _genelAyarlar.miktarOndalik,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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
                    Expanded(
                      child: Text(
                        user,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (trimmedDescription.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    trimmedDescription,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItemWithIcon(
    String label,
    String value, {
    IconData? icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Icon(
            icon ?? Icons.info_outline,
            color: Colors.grey.shade600,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              HighlightText(
                text: value.isEmpty ? '-' : value,
                query: _searchQuery,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WarehouseFilterOverlay extends StatefulWidget {
  final DepoModel? selectedWarehouse;
  final Map<String, int> depotCounts;
  final int totalCount;
  final ValueChanged<DepoModel?> onSelect;

  const _WarehouseFilterOverlay({
    required this.selectedWarehouse,
    required this.depotCounts,
    required this.totalCount,
    required this.onSelect,
  });

  @override
  State<_WarehouseFilterOverlay> createState() =>
      _WarehouseFilterOverlayState();
}

class _WarehouseFilterOverlayState extends State<_WarehouseFilterOverlay> {
  final TextEditingController _searchController = TextEditingController();
  List<DepoModel> _depolar = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchDepolar();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchDepolar();
    });
  }

  Future<void> _fetchDepolar() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await DepolarVeritabaniServisi().depoAra(
        _searchController.text,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _depolar = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: _isLoading
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF2C3E50),
                ),
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildOption(
                      null,
                      tr('settings.general.option.documents.all'),
                    ),
                    ..._depolar.map((depo) => _buildOption(depo, depo.ad)),
                    if (_depolar.isEmpty && _searchController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          tr('common.no_results'),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOption(DepoModel? value, String label) {
    final isSelected = widget.selectedWarehouse?.id == value?.id;
    final int count = value == null
        ? widget.totalCount
        : (widget.depotCounts['${value.id}'] ?? 0);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: () => widget.onSelect(value),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
