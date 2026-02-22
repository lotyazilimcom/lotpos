import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../bilesenler/tab_acici_scope.dart';
import '../../bilesenler/genisletilebilir_tablo.dart';
import '../ayarlar/genel_ayarlar/veri_kaynagi/genel_ayarlar_veri_kaynagi.dart';
import '../../bilesenler/onay_dialog.dart';
import '../../bilesenler/tarih_araligi_secici_dialog.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/ceviri/islem_ceviri_yardimcisi.dart';
import '../../yardimcilar/responsive_yardimcisi.dart';
import 'modeller/kredi_karti_model.dart';

import 'kredi_karti_ekle_dialog.dart';
import 'kredi_karti_para_gir_sayfasi.dart';
import 'kredi_karti_para_cik_sayfasi.dart';
// import 'kasa_hareket_sayfasi.dart';
import '../../servisler/kredi_kartlari_veritabani_servisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../ortak/genisletilebilir_print_preview_screen.dart';
import '../../bilesenler/highlight_text.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../../yardimcilar/islem_turu_renkleri.dart';
import '../carihesaplar/cari_para_al_ver_sayfasi.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../servisler/sayfa_senkronizasyon_servisi.dart';

class KrediKartlariSayfasi extends StatefulWidget {
  final String? initialSearchQuery;
  const KrediKartlariSayfasi({super.key, this.initialSearchQuery});

  @override
  State<KrediKartlariSayfasi> createState() => _KrediKartlariSayfasiState();
}

class _KrediKartlariSayfasiState extends State<KrediKartlariSayfasi> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<KrediKartiModel> _cachedKrediKartlari = [];

  bool _isLoading = true;
  bool _isMobileToolbarExpanded = false;
  int _totalRecords = 0;
  final Set<int> _selectedIds = {};
  int? _selectedRowId; // Currently selected row for keyboard navigation
  int _rowsPerPage = 25;
  int _currentPage = 1;
  final Set<int> _expandedMobileIds = {};
  Set<int> _autoExpandedIndices = {};
  int? _manualExpandedIndex;

  // Date Filter State
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  // Status Filter State
  bool _isStatusFilterExpanded = false;
  String? _selectedStatus;

  // Overlay State
  final LayerLink _statusLayerLink = LayerLink();
  final LayerLink _transactionLayerLink = LayerLink();
  final LayerLink _warehouseLayerLink = LayerLink();
  final LayerLink _defaultLayerLink = LayerLink();
  final LayerLink _userLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  // Transaction Filter State
  bool _isTransactionFilterExpanded = false;
  String? _selectedTransactionType;

  // Warehouse Filter State
  bool _isWarehouseFilterExpanded = false;
  KrediKartiModel? _selectedWarehouse;

  // Default Filter State
  bool _isDefaultFilterExpanded = false;
  bool? _selectedDefault;

  // User Filter State
  bool _isUserFilterExpanded = false;
  String? _selectedUser;

  Map<String, Map<String, int>> _filterStats = {};

  final Map<int, Set<int>> _selectedDetailIds = {};
  final Map<int, List<int>> _visibleTransactionIds = {};

  // Cache for detail futures to prevent reloading on selection changes
  final Map<int, Future<List<Map<String, dynamic>>>> _detailFutures = {};

  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  bool _keepDetailsOpen = false;
  bool _isManuallyClosedDuringFilter = false;

  // Column Visibility State
  Map<String, bool> _columnVisibility = {};

  // Sorting State
  int? _sortColumnIndex = 1; // Default sort by ID
  bool _sortAscending = false;
  String? _sortBy = 'id';
  Timer? _debounce;
  int _aktifSorguNo = 0;

  // Detay satırı seçimi için state değişkenleri (Kısayollar için)
  Map<String, dynamic>? _selectedDetailTransaction;
  KrediKartiModel? _selectedDetailKrediKarti;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null) {
      _searchController.text = widget.initialSearchQuery!;
      _searchQuery = widget.initialSearchQuery!.toLowerCase();
    }
    _columnVisibility = {
      // Main Table
      'order_no': true,
      'code': true,
      'name': true,
      'balance': true,
      'currency': true,
      'status': true,
      'default': true,
      // Detail Table
      'dt_transaction': true,
      'dt_date': true,
      'dt_party': true,
      'dt_amount': true,
      'dt_description': true,
      'dt_user': true,
    };
    _loadSettings();
    // Arama çalışması için mevcut kredi kartlarının search_tags'ını güncelle
    // ve indeksleme tamamlandıktan sonra verileri getir
    _fetchKrediKartlari();

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (_searchController.text != _searchQuery) {
          setState(() {
            _searchQuery = _searchController.text.toLowerCase();
            _currentPage = 1;
          });
          _fetchKrediKartlari();
        }
      });
    });

    SayfaSenkronizasyonServisi().addListener(_onGlobalSync);
  }

  void _resetPagination() {
    _currentPage = 1;
  }

  void _onGlobalSync() {
    _fetchKrediKartlari(showLoading: false);
  }

  // NOT: Arama indekslemesi artık servis içinde arka planda yapılıyor.
  // Bu yüzden sayfa açılışında await etmek gerekmiyor.

  Future<void> _fetchKrediKartlari({bool showLoading = true}) async {
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

      final krediKartlari = await KrediKartlariVeritabaniServisi()
          .krediKartlariniGetir(
            sayfa: _currentPage,
            sayfaBasinaKayit: _rowsPerPage,
            aramaKelimesi: _searchQuery,
            siralama: _sortBy,
            artanSiralama: _sortAscending,
            aktifMi: aktifMi, // Existing status filter
            varsayilan: _selectedDefault,
            kullanici: _selectedUser,
            baslangicTarihi: _startDate,
            bitisTarihi: _endDate,
            islemTuru: _selectedTransactionType,
            krediKartiId: _selectedWarehouse?.id,
          );

      if (!mounted || sorguNo != _aktifSorguNo) return;

      final totalFuture = KrediKartlariVeritabaniServisi()
          .krediKartiSayisiGetir(
            aramaTerimi: _searchQuery,
            aktifMi: aktifMi,
            varsayilan: _selectedDefault,
            kullanici: _selectedUser,
            baslangicTarihi: _startDate,
            bitisTarihi: _endDate,
            islemTuru: _selectedTransactionType,
            krediKartiId: _selectedWarehouse?.id,
          );

      final statsFuture = KrediKartlariVeritabaniServisi()
          .krediKartiFiltreIstatistikleriniGetir(
            aramaTerimi: _searchQuery,
            baslangicTarihi: _startDate,
            bitisTarihi: _endDate,
            aktifMi: aktifMi,
            varsayilan: _selectedDefault,
            kullanici: _selectedUser,
            islemTuru: _selectedTransactionType,
          );

      if (mounted) {
        final indices = <int>{};
        final bool hasNonSearchFilter =
            _selectedStatus != null ||
            _selectedDefault != null ||
            _selectedUser != null ||
            _startDate != null ||
            _endDate != null ||
            _selectedTransactionType != null ||
            _selectedWarehouse != null;

        if (hasNonSearchFilter) {
          indices.addAll(List.generate(krediKartlari.length, (i) => i));
        } else if (_searchQuery.isNotEmpty) {
          for (int i = 0; i < krediKartlari.length; i++) {
            if (krediKartlari[i].matchedInHidden) {
              indices.add(i);
              _expandedMobileIds.add(krediKartlari[i].id);
            }
          }
        }

        setState(() {
          _cachedKrediKartlari = krediKartlari;
          _autoExpandedIndices = indices;
          _isLoading = false;

          // [2026 PROFESYONEL SYNC] Filtre açıkken ve sonuç varsa butonu oto-aktif et
          if (hasNonSearchFilter || _searchQuery.isNotEmpty) {
            if (indices.isNotEmpty && !_isManuallyClosedDuringFilter) {
              _keepDetailsOpen = true;
            }
          } else {
            // Filtre yoksa manuel kapanma bayrağını sıfırla
            _isManuallyClosedDuringFilter = false;
            // SharedPreferences tercihlerine geri dön (Eğer filtre sırasında değiştiyse)
            _loadSettings();
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
              debugPrint('Kredi kartı toplam sayısı güncellenemedi: $e');
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
              debugPrint(
                'Kredi kartı filtre istatistikleri güncellenemedi: $e',
              );
            }),
      );
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
                            tr('creditcards.table.code'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'name',
                            tr('creditcards.table.name'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'balance',
                            tr('creditcards.table.balance'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'currency',
                            tr('creditcards.table.currency'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'status',
                            tr('creditcards.table.status'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'default',
                            tr('creditcards.table.default'),
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
                            tr('creditcards.detail.transaction'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_date',
                            tr('creditcards.detail.date'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_party',
                            tr('creditcards.detail.party'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_amount',
                            tr('common.amount'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_description',
                            tr('creditcards.detail.description'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_user',
                            tr('creditcards.detail.user'),
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

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = await GenelAyarlarVeriKaynagi().ayarlariGetir();
      if (mounted) {
        setState(() {
          _keepDetailsOpen =
              prefs.getBool('kredikartlari_keep_details_open') ?? false;
          _genelAyarlar = settings;
        });
      }
    } catch (e) {
      debugPrint('KrediKartilar ayarlar yüklenirken hata: $e');
    }
  }

  Future<void> _toggleKeepDetailsOpen() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _keepDetailsOpen = !_keepDetailsOpen;

      // [2026 PROFESYONEL] Eğer kapatılıyorsa ve bir filtre aktifse
      final bool hasFilter =
          _searchQuery.isNotEmpty ||
          _selectedStatus != null ||
          _selectedDefault != null ||
          _selectedUser != null ||
          _startDate != null ||
          _endDate != null ||
          _selectedTransactionType != null ||
          _selectedWarehouse != null;

      if (!_keepDetailsOpen) {
        if (hasFilter) {
          _isManuallyClosedDuringFilter = true;
        }
        _autoExpandedIndices.clear();
        _manualExpandedIndex = null;
      } else {
        // Eğer açılıyorsa manuel kapanma isteğini geri al
        _isManuallyClosedDuringFilter = false;
      }
    });
    await prefs.setBool('kredikartlari_keep_details_open', _keepDetailsOpen);
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
        _isTransactionFilterExpanded = false;
        _isWarehouseFilterExpanded = false;
        _isDefaultFilterExpanded = false;
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

        _resetPagination();
      });
      _fetchKrediKartlari();
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
                    _buildStatusOption(null, tr('common.all')),
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
                      _buildTransactionOption(null, tr('common.all')),
                      ...(_filterStats['islem_turleri']?.entries.map((e) {
                            return _buildTransactionOption(e.key, e.key);
                          }) ??
                          []),
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

  void _showDefaultOverlay() {
    _closeOverlay();
    setState(() {
      _isDefaultFilterExpanded = true;
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
            link: _defaultLayerLink,
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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDefaultOption(null, tr('common.all')),
                    _buildDefaultOption(true, tr('common.default')),
                    _buildDefaultOption(false, tr('common.regular')),
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
                      _buildUserOption(null, tr('common.all')),
                      ...(_filterStats['kullanicilar']?.entries.map((e) {
                            return _buildUserOption(e.key, e.key);
                          }) ??
                          []),
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
                onSelect: (krediKarti) {
                  setState(() {
                    _selectedWarehouse = krediKarti;
                    _isWarehouseFilterExpanded = false;
                  });
                  _closeOverlay();
                  _fetchKrediKartlari();
                },
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  String _normalizeTurkish(String text) {
    if (text.isEmpty) return '';
    return text
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll('i̇', 'i');
  }

  List<KrediKartiModel> _filterKrediKartlari(
    List<KrediKartiModel> krediKartlari,
  ) {
    if (_searchQuery.isEmpty) return krediKartlari;

    final q = _normalizeTurkish(_searchQuery);
    return krediKartlari.where((krediKarti) {
      final codeMatch = _normalizeTurkish(krediKarti.kod).contains(q);
      final nameMatch = _normalizeTurkish(krediKarti.ad).contains(q);
      final addressMatch = _normalizeTurkish(krediKarti.bilgi1).contains(q);
      final responsibleMatch = _normalizeTurkish(krediKarti.bilgi2).contains(q);
      final phoneMatch = _normalizeTurkish(krediKarti.paraBirimi).contains(q);
      final tagsMatch = _normalizeTurkish(
        krediKarti.searchTags ?? '',
      ).contains(q);
      final hiddenMatch = krediKarti.matchedInHidden;

      return codeMatch ||
          nameMatch ||
          addressMatch ||
          responsibleMatch ||
          phoneMatch ||
          tagsMatch ||
          hiddenMatch;
    }).toList();
  }

  Future<void> _showAddDialog() async {
    String? initialCode;
    try {
      final settings = await GenelAyarlarVeriKaynagi().ayarlariGetir();
      if (settings.otoKrediKartiKodu) {
        initialCode = await KrediKartlariVeritabaniServisi()
            .siradakiKrediKartiKodunuGetir(
              alfanumerik: settings.otoKrediKartiKoduAlfanumerik,
            );
      }
    } catch (e) {
      debugPrint('Oto kod alma hatası: $e');
    }

    if (!mounted) return;

    final result = await showDialog<KrediKartiModel>(
      context: context,
      builder: (context) => KrediKartiEkleDialog(initialCode: initialCode),
    );

    if (result != null) {
      try {
        await KrediKartlariVeritabaniServisi().krediKartiEkle(result);
        SayfaSenkronizasyonServisi().veriDegisti('kredi_karti');
        await _fetchKrediKartlari();

        if (mounted) {
          MesajYardimcisi.basariGoster(
            context,
            tr('common.saved_successfully'),
          );
        }
      } catch (e) {
        if (mounted) {
          MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
        }
      }
    }
  }

  Future<void> _deleteSelectedKrediKartlari() async {
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
          await KrediKartlariVeritabaniServisi().krediKartiSil(id);
        }

        SayfaSenkronizasyonServisi().veriDegisti('kredi_karti');
        await _fetchKrediKartlari();

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

  @override
  Widget build(BuildContext context) {
    // [REIS MODU] Sıçramayı önlemek için her zaman Scaffold dönüyoruz.
    // Veri yoksa bile yapı değişmiyor, sadece üstte ince bar çıkıyor.

    // Filtreleme mantığı
    List<KrediKartiModel> filteredKrediKartlari = _cachedKrediKartlari;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Focus(
        autofocus: false, // Let GenisletilebilirTablo handle focus
        child: CallbackShortcuts(
          bindings: {
            // ESC: Overlay kapat / Arama temizle / Filtre sıfırla
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
                  _selectedDefault != null ||
                  _selectedUser != null) {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _selectedStatus = null;
                  _selectedTransactionType = null;
                  _selectedWarehouse = null;
                  _selectedDefault = null;
                  _selectedUser = null;
                });
                _fetchKrediKartlari();
                return;
              }
            },
            // F1: Yeni Ekle
            const SingleActivator(LogicalKeyboardKey.f1): _showAddDialog,
            // F2: Seçili Düzenle
            const SingleActivator(LogicalKeyboardKey.f2): () {
              // F2: Düzenle - önce seçili detay transaction varsa onu düzenle
              if (_selectedDetailTransaction != null &&
                  _selectedDetailKrediKarti != null) {
                if (_shouldHideDetailTransactionActions(
                  _selectedDetailTransaction?['integration_ref']?.toString(),
                )) {
                  return;
                }
                _showEditTransactionDialog(
                  _selectedDetailTransaction!,
                  _selectedDetailKrediKarti!,
                );
                return;
              }
              // Yoksa ana satırı düzenle
              if (_selectedRowId == null) return;
              final krediKarti = _cachedKrediKartlari.firstWhere(
                (k) => k.id == _selectedRowId,
                orElse: () => _cachedKrediKartlari.first,
              );
              if (krediKarti.id == _selectedRowId) {
                _showEditDialog(krediKarti);
              }
            },
            // F3: Arama kutusuna odaklan
            const SingleActivator(LogicalKeyboardKey.f3): () {
              _searchFocusNode.requestFocus();
            },
            // F5: Yenile
            const SingleActivator(LogicalKeyboardKey.f5): () {
              _fetchKrediKartlari();
            },
            // F6: Aktif/Pasif Toggle
            const SingleActivator(LogicalKeyboardKey.f6): () {
              if (_selectedRowId == null) return;
              final krediKarti = _cachedKrediKartlari.firstWhere(
                (k) => k.id == _selectedRowId,
                orElse: () => _cachedKrediKartlari.first,
              );
              if (krediKarti.id == _selectedRowId) {
                _krediKartiDurumDegistir(krediKarti, !krediKarti.aktifMi);
              }
            },
            // F7: Yazdır
            const SingleActivator(LogicalKeyboardKey.f7): _handlePrint,
            // F8: Seçilileri Toplu Sil
            const SingleActivator(LogicalKeyboardKey.f8): () {
              if (_selectedIds.isEmpty) return;
              _deleteSelectedKrediKartlari();
            },
            // F9: Para Gir
            const SingleActivator(LogicalKeyboardKey.f9): () {
              if (_selectedRowId == null) return;
              final krediKarti = _cachedKrediKartlari.firstWhere(
                (k) => k.id == _selectedRowId,
                orElse: () => _cachedKrediKartlari.first,
              );
              if (krediKarti.id == _selectedRowId) {
                _showDepositDialog(krediKarti);
              }
            },
            // F10: Para Çık
            const SingleActivator(LogicalKeyboardKey.f10): () {
              if (_selectedRowId == null) return;
              final krediKarti = _cachedKrediKartlari.firstWhere(
                (k) => k.id == _selectedRowId,
                orElse: () => _cachedKrediKartlari.first,
              );
              if (krediKarti.id == _selectedRowId) {
                _showWithdrawDialog(krediKarti);
              }
            },
            // Delete: Seçili Satırı Sil
            const SingleActivator(LogicalKeyboardKey.delete): () {
              // Delete: Önce seçili detay transaction varsa onu sil
              if (_selectedDetailTransaction != null &&
                  _selectedDetailKrediKarti != null) {
                if (_shouldHideDetailTransactionActions(
                  _selectedDetailTransaction?['integration_ref']?.toString(),
                )) {
                  return;
                }
                _handleDetailDelete(
                  _selectedDetailTransaction!['id'],
                  _selectedDetailKrediKarti!,
                );
                return;
              }
              // Yoksa ana satırı sil
              if (_selectedRowId == null) return;
              final krediKarti = _cachedKrediKartlari.firstWhere(
                (k) => k.id == _selectedRowId,
                orElse: () => _cachedKrediKartlari.first,
              );
              if (krediKarti.id == _selectedRowId) {
                _deleteKrediKarti(krediKarti);
              }
            },
            // Numpad Delete
            const SingleActivator(LogicalKeyboardKey.numpadDecimal): () {
              // Delete: Önce seçili detay transaction varsa onu sil
              if (_selectedDetailTransaction != null &&
                  _selectedDetailKrediKarti != null) {
                if (_shouldHideDetailTransactionActions(
                  _selectedDetailTransaction?['integration_ref']?.toString(),
                )) {
                  return;
                }
                _handleDetailDelete(
                  _selectedDetailTransaction!['id'],
                  _selectedDetailKrediKarti!,
                );
                return;
              }
              // Yoksa ana satırı sil
              if (_selectedRowId == null) return;
              final krediKarti = _cachedKrediKartlari.firstWhere(
                (k) => k.id == _selectedRowId,
                orElse: () => _cachedKrediKartlari.first,
              );
              if (krediKarti.id == _selectedRowId) {
                _deleteKrediKarti(krediKarti);
              }
            },
          },
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool forceMobile =
                      ResponsiveYardimcisi.tabletMi(context);
                  if (forceMobile || constraints.maxWidth < 800) {
                    return _buildMobileView(filteredKrediKartlari);
                  } else {
                    return _buildDesktopView(
                      filteredKrediKartlari,
                      constraints,
                    );
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

  void _onSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedIds.addAll(
          _filterKrediKartlari(_cachedKrediKartlari).map((e) => e.id),
        );
      } else {
        _selectedIds.clear();
      }
    });
  }

  /// Clear all selections when tapping outside the table
  void _clearAllTableSelections() {
    setState(() {
      _selectedIds.clear();
      _selectedDetailIds.clear();
      _selectedRowId = null;
      _selectedDetailTransaction = null;
      _selectedDetailKrediKarti = null;
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

  void _onSelectAllDetails(int kasaId, bool? value) {
    setState(() {
      if (value == true) {
        _selectedDetailIds[kasaId] = (_visibleTransactionIds[kasaId] ?? [])
            .toSet();
      } else {
        _selectedDetailIds[kasaId]?.clear();
      }
    });
  }

  void _onSelectDetailRow(int kasaId, int transactionId, bool? value) {
    setState(() {
      if (_selectedDetailIds[kasaId] == null) {
        _selectedDetailIds[kasaId] = {};
      }
      if (value == true) {
        _selectedDetailIds[kasaId]!.add(transactionId);
      } else {
        _selectedDetailIds[kasaId]!.remove(transactionId);
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
    _fetchKrediKartlari(showLoading: false);
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
          ? _cachedKrediKartlari
                .where((k) => mainRowIdsToProcess.contains(k.id))
                .toList()
          : _cachedKrediKartlari;

      for (var i = 0; i < dataToProcess.length; i++) {
        final krediKarti = dataToProcess[i];

        // Determine if row is expanded
        final isExpanded =
            _keepDetailsOpen ||
            _autoExpandedIndices.contains(i) ||
            _manualExpandedIndex == i;

        List<Map<String, dynamic>> transactions = [];
        // 1. Transactions Fetch (Only if expanded or has selected details)
        final hasPrintSelectedDetails =
            _selectedDetailIds[krediKarti.id]?.isNotEmpty ?? false;
        if (isExpanded || hasPrintSelectedDetails) {
          transactions = await KrediKartlariVeritabaniServisi()
              .krediKartiIslemleriniGetir(
                krediKarti.id,
                aramaTerimi: _searchQuery,
                kullanici: _selectedUser,
                baslangicTarihi: _startDate,
                bitisTarihi: _endDate,
                islemTuru: _selectedTransactionType,
              );
        }

        // Filter transactions if detail selection exists for this row
        final selectedDetailIdsForRow = _selectedDetailIds[krediKarti.id];
        if (selectedDetailIdsForRow != null &&
            selectedDetailIdsForRow.isNotEmpty) {
          transactions = transactions.where((t) {
            final txId = t['id'] as int?;
            return txId != null && selectedDetailIdsForRow.contains(txId);
          }).toList();
        }

        // 2. Main Row Data - matches headers: Sıra No, Kart Kodu, Kart Adı, Bakiye, Durum, Varsayılan
        final mainRow = [
          krediKarti.id.toString(),
          krediKarti.kod,
          krediKarti.ad,
          '${FormatYardimcisi.sayiFormatlaOndalikli(krediKarti.bakiye, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${krediKarti.paraBirimi}',
          krediKarti.aktifMi ? tr('common.active') : tr('common.passive'),
          krediKarti.varsayilan ? tr('common.yes') : tr('common.no'),
        ];

        // 3. Details - Bilgi 1, Bilgi 2, Girdi/Çıktı/Toplam
        Map<String, String> details = {};
        final hasSelectedDetails =
            _selectedDetailIds[krediKarti.id]?.isNotEmpty ?? false;
        if (isExpanded || hasSelectedDetails) {
          // Calculate Girdi/Çıktı from transactions
          double totalGirdi = 0;
          double totalCikti = 0;
          for (var t in transactions) {
            final amount = (t['tutar'] is num)
                ? (t['tutar'] as num).toDouble()
                : double.tryParse(t['tutar'].toString()) ?? 0;
            final islem = t['islem']?.toString() ?? '';
            final integrationRef = t['integration_ref']?.toString() ?? '';
            final lowRef = integrationRef.toLowerCase();

            // Determine if incoming or outgoing
            bool isIncoming =
                islem == 'Girdi' ||
                islem == 'Tahsilat' ||
                lowRef.startsWith('sale-') ||
                lowRef.startsWith('retail-');
            if (isIncoming) {
              totalGirdi += amount;
            } else {
              totalCikti += amount;
            }
          }
          final toplam = totalGirdi - totalCikti;

          details = {
            tr('creditcards.table.info1'): krediKarti.bilgi1.isNotEmpty
                ? krediKarti.bilgi1
                : '-',
            tr('creditcards.table.info2'): krediKarti.bilgi2.isNotEmpty
                ? krediKarti.bilgi2
                : '-',
            tr(
              'products.transaction.type.input',
            ): '${FormatYardimcisi.sayiFormatlaOndalikli(totalGirdi, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${krediKarti.paraBirimi}',
            tr(
              'products.transaction.type.output',
            ): '${FormatYardimcisi.sayiFormatlaOndalikli(totalCikti, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${krediKarti.paraBirimi}',
            tr(
              'common.total',
            ): '${FormatYardimcisi.sayiFormatlaOndalikli(toplam, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${krediKarti.paraBirimi}',
          };
        }

        // 4. Transaction Table
        DetailTable? txTable;
        if (transactions.isNotEmpty) {
          txTable = DetailTable(
            title: tr('creditcards.detail.timeline'),
            headers: [
              tr('creditcards.detail.transaction'),
              tr('creditcards.detail.date'),
              tr('creditcards.detail.party'), // İlgili Hesap
              tr('common.amount'),
              tr('creditcards.detail.description'),
              tr('creditcards.detail.user'),
            ],
            data: transactions.map((t) {
              final bool isIncoming = t['isIncoming'] == true;
              final String rawDate = t['tarih']?.toString() ?? '';
              final double amount = t['tutar'] is num
                  ? (t['tutar'] as num).toDouble()
                  : 0.0;
              final String description = t['aciklama']?.toString() ?? '';
              final String user = (t['kullanici']?.toString() ?? '').isEmpty
                  ? tr('common.system')
                  : t['kullanici'].toString();

              // Format date properly (dd.MM.yyyy HH:mm) like DataTable
              String formattedDate = '';
              if (rawDate.isNotEmpty) {
                try {
                  DateTime parsedDate;
                  if (rawDate.contains('T') || rawDate.contains(' ')) {
                    parsedDate = DateTime.parse(rawDate);
                  } else {
                    parsedDate = DateTime.parse(rawDate);
                  }
                  formattedDate = DateFormat(
                    'dd.MM.yyyy HH:mm',
                  ).format(parsedDate);
                } catch (_) {
                  formattedDate = rawDate;
                }
              }

              // Build İlgili Hesap like DataTable using yerAdi and yerKodu
              final String yerAdi = t['yerAdi']?.toString() ?? '';
              final String yerKodu = t['yerKodu']?.toString() ?? '';
              String ilgiliHesap = '-';
              if (yerAdi.isNotEmpty) {
                ilgiliHesap = yerAdi;
                if (yerKodu.isNotEmpty) {
                  ilgiliHesap += '\n${tr('accounts.title')}: $yerKodu';
                }
              }

              // [EXACTLY LIKE DATATABLE] Determine display name based on isIncoming
              String displayName = isIncoming ? 'Para Alındı' : 'Para Verildi';

              final String? integrationRef = t['integration_ref']?.toString();
              if (integrationRef != null) {
                final lowRef = integrationRef.toLowerCase();
                if (lowRef.startsWith('retail-')) {
                  ilgiliHesap = 'Perakende Satış Yapıldı (K.Kartı)';
                }

                if (lowRef.startsWith('sale-') ||
                    lowRef.startsWith('retail-')) {
                  displayName = 'Satış Yapıldı';
                } else if (lowRef.startsWith('purchase-')) {
                  displayName = 'Alış Yapıldı';
                } else if (lowRef.contains('opening_stock')) {
                  displayName = 'Açılış Stoğu';
                } else if (lowRef.contains('production')) {
                  displayName = 'Üretim';
                } else if (lowRef.contains('transfer')) {
                  displayName = 'Devir';
                } else if (lowRef.contains('collection')) {
                  displayName = 'Tahsilat';
                } else if (lowRef.contains('payment')) {
                  displayName = 'Ödeme';
                } else if (lowRef.startsWith('cheque') ||
                    lowRef.startsWith('cek-')) {
                  displayName = isIncoming
                      ? 'Çek Alındı (Tahsil Edildi)'
                      : 'Çek Verildi (Ödendi)';
                } else if (lowRef.startsWith('note') ||
                    lowRef.startsWith('senet-')) {
                  displayName = isIncoming
                      ? 'Senet Alındı (Tahsil Edildi)'
                      : 'Senet Verildi (Ödendi)';
                }
              }

              // [UX] Personel Ödemesi: Sadece personel çıkışlarında "Para Verildi" yerine göster.
              if (!isIncoming &&
                  displayName == 'Para Verildi' &&
                  (t['yer']?.toString() ?? '').toLowerCase().contains(
                    'personel',
                  )) {
                displayName = 'Personel Ödemesi';
              }

              // Add location type suffix like DataTable using _getSourceSuffix
              final String yer = t['yer']?.toString() ?? '';
              final String sourceSuffix = _getSourceSuffix(
                yer,
                integrationRef,
                yerAdi,
              );
              if (sourceSuffix.isNotEmpty) {
                displayName = '$displayName $sourceSuffix';
              }

              return <String>[
                IslemCeviriYardimcisi.cevir(displayName),
                formattedDate,
                ilgiliHesap,
                '${FormatYardimcisi.sayiFormatlaOndalikli(amount, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${krediKarti.paraBirimi}',
                description,
                user,
              ];
            }).toList(),
          );
        }

        rows.add(
          ExpandableRowData(
            mainRow: mainRow,
            details: details,
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
            title: tr('creditcards.title'),
            headers: [
              tr('language.table.orderNo'),
              tr('creditcards.table.code'),
              tr('creditcards.table.name'),
              tr('creditcards.table.balance'),
              tr('creditcards.table.status'),
              tr('creditcards.table.default'),
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildDateRangeFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildStatusFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildDefaultFilter(width: double.infinity)),
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
                    _resetPagination();
                  });
                  _fetchKrediKartlari();
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
                      _currentPage = 1;
                    });
                    _fetchKrediKartlari();
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
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: () {
        setState(() {
          _selectedStatus = value;
          _isStatusFilterExpanded = false;
          _currentPage = 1;
        });
        _closeOverlay();
        _fetchKrediKartlari();
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

  Widget _buildDefaultFilter({double? width}) {
    return CompositedTransformTarget(
      link: _defaultLayerLink,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () {
          if (_isDefaultFilterExpanded) {
            _closeOverlay();
          } else {
            _showDefaultOverlay();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 160,
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            _isDefaultFilterExpanded ? 7 : 8,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isDefaultFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade300,
                width: _isDefaultFilterExpanded ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                size: 20,
                color: _isDefaultFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedDefault == null
                      ? tr('common.all')
                      : (_selectedDefault == true
                            ? '${tr('common.default')} (${_filterStats['varsayilanlar']?['default'] ?? 0})'
                            : '${tr('common.regular')} (${_filterStats['varsayilanlar']?['regular'] ?? 0})'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isDefaultFilterExpanded
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedDefault != null)
                InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: () {
                    setState(() {
                      _selectedDefault = null;
                      _currentPage = 1;
                    });
                    _fetchKrediKartlari();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isDefaultFilterExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: _isDefaultFilterExpanded
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

  Widget _buildDefaultOption(bool? value, String label) {
    final isSelected = _selectedDefault == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (value == true
              ? (_filterStats['varsayilanlar']?['default'] ?? 0)
              : (_filterStats['varsayilanlar']?['regular'] ?? 0));

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: () {
        setState(() {
          _selectedDefault = value;
          _isDefaultFilterExpanded = false;
          _currentPage = 1;
        });
        _closeOverlay();
        _fetchKrediKartlari();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFF0F7FF) : Colors.transparent,
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF2C3E50) : Colors.black87,
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
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: () {
                    setState(() {
                      _selectedUser = null;
                      _currentPage = 1;
                    });
                    _fetchKrediKartlari();
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
          _currentPage = 1;
        });
        _closeOverlay();
        _fetchKrediKartlari();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFFDF2F2) : Colors.transparent,
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFFEA4335) : Colors.black87,
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
                      : '${IslemCeviriYardimcisi.cevir(IslemTuruRenkleri.getProfessionalLabel(_selectedTransactionType!, context: 'cari'))} (${_filterStats['islem_turleri']?[_selectedTransactionType] ?? 0})',
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
                      _currentPage = 1;
                    });
                    _fetchKrediKartlari();
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

  Widget _buildTransactionOption(String? value, String label) {
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
          _currentPage = 1;
        });
        _closeOverlay();
        _fetchKrediKartlari();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFF0F7FF) : Colors.transparent,
        child: Text(
          '${value == null ? label : IslemCeviriYardimcisi.cevir(IslemTuruRenkleri.getProfessionalLabel(value, context: 'cari'))} ($count)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF2C3E50) : Colors.black87,
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
                      ? 'KrediKarti'
                      : _selectedWarehouse!.ad,
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
                    _fetchKrediKartlari();
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

  /// Başlık metnine göre sütun genişliğini hesaplar.
  /// TextPainter kullanarak metnin tam genişliğini ölçer.
  double _calculateColumnWidth(String text, {bool sortable = false}) {
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

    double width = textPainter.width + 32; // 16 padding on each side
    if (sortable) {
      width += 22; // Icon (16) + spacing (6)
    }
    return width + 10; // Extra buffer
  }

  Widget _buildDesktopView(
    List<KrediKartiModel> krediKartlari,
    BoxConstraints constraints,
  ) {
    final bool allSelected =
        krediKartlari.isNotEmpty &&
        krediKartlari.every((d) => _selectedIds.contains(d.id));

    // Calculate column widths
    final colOrderWidth = _calculateColumnWidth(
      tr('language.table.orderNo'),
      sortable: true,
    );
    final colCodeWidth = _calculateColumnWidth(
      tr('creditcards.table.code'),
      sortable: true,
    );
    final colNameWidth = _calculateColumnWidth(
      tr('creditcards.table.name'),
      sortable: true,
    );
    const colBalanceWidth = 150.0;
    final colCurrencyWidth = _calculateColumnWidth(
      tr('creditcards.table.currency'),
      sortable: true,
    );

    final colStatusWidth = _calculateColumnWidth(
      tr('creditcards.table.status'),
      sortable: true,
    );
    final colDefaultWidth = _calculateColumnWidth(
      tr('creditcards.table.default'),
      sortable: true,
    );
    const colActionsWidth = 100.0;

    return GenisletilebilirTablo<KrediKartiModel>(
      title: tr('creditcards.title'),
      searchFocusNode: _searchFocusNode,
      onFocusedRowChanged: (item, index) {
        if (item != null) {
          setState(() => _selectedRowId = item.id);
        }
      },
      headerWidget: _buildFilters(),
      getDetailItemCount: (krediKarti) =>
          _visibleTransactionIds[krediKarti.id]?.length ?? 0,
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
        _fetchKrediKartlari();
      },
      onSearch: (query) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          setState(() {
            _searchQuery = query;
            _currentPage = 1;
          });
          _fetchKrediKartlari(showLoading: false);
        });
      },
      selectionWidget: _selectedIds.isNotEmpty
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                onTap: _deleteSelectedKrediKartlari,
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
      expandedIndices: _autoExpandedIndices,
      onExpansionChanged: (index, isExpanded) {
        setState(() {
          if (isExpanded) {
            _autoExpandedIndices.add(index);
          } else {
            _autoExpandedIndices.remove(index);
          }
        });
      },
      extraWidgets: [
        Tooltip(
          message: tr('creditcards.keep_details_open'),
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
                      tr('creditcards.add'),
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
            width: colOrderWidth,
            flex: 20,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['code'] == true)
          GenisletilebilirTabloKolon(
            label: tr('creditcards.table.code'),
            width: colCodeWidth,
            flex: 20,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['name'] == true)
          GenisletilebilirTabloKolon(
            label: tr('creditcards.table.name'),
            width: colNameWidth,
            flex: 25,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['balance'] == true)
          GenisletilebilirTabloKolon(
            label: tr('creditcards.table.balance'),
            width: colBalanceWidth,
            flex: 30,
            alignment: Alignment.centerRight,
            allowSorting: true,
          ),
        if (_columnVisibility['currency'] == true)
          GenisletilebilirTabloKolon(
            label: tr('creditcards.table.currency'),
            width: colCurrencyWidth,
            flex: 35,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['status'] == true)
          GenisletilebilirTabloKolon(
            label: tr('creditcards.table.status'),
            width: colStatusWidth,
            flex: 20,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['default'] == true)
          GenisletilebilirTabloKolon(
            label: tr('creditcards.table.default'),
            width: colDefaultWidth,
            alignment: Alignment.center,
            allowSorting: true,
          ),
        GenisletilebilirTabloKolon(
          label: tr('creditcards.table.actions'),
          width: colActionsWidth,
          alignment: Alignment.centerLeft,
        ),
      ],
      data: krediKartlari,
      isRowSelected: (krediKarti, index) => _selectedRowId == krediKarti.id,
      expandOnRowTap: false,
      onRowTap: (krediKarti) {
        setState(() {
          _selectedRowId = krediKarti.id;
        });
      },
      onClearSelection: _clearAllTableSelections,
      rowBuilder: (context, krediKarti, index, isExpanded, toggleExpand) {
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
                  value: _selectedIds.contains(krediKarti.id),
                  onChanged: (val) => _onSelectRow(val, krediKarti.id),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
                ),
              ),
            ),
            if (_columnVisibility['order_no'] == true)
              _buildCell(
                width: colOrderWidth,
                flex: 20,
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
                      text: krediKarti.id.toString(),
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
                width: colCodeWidth,
                flex: 20,
                child: HighlightText(
                  text: krediKarti.kod,
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
                width: colNameWidth,
                flex: 25,
                child: HighlightText(
                  text: krediKarti.ad,
                  query: _searchQuery,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),
            if (_columnVisibility['balance'] == true)
              _buildCell(
                width: colBalanceWidth,
                flex: 30,
                alignment: Alignment.centerRight,
                child: Text(
                  FormatYardimcisi.sayiFormatlaOndalikli(
                    krediKarti.bakiye,
                    binlik: _genelAyarlar.binlikAyiraci,
                    ondalik: _genelAyarlar.ondalikAyiraci,
                    decimalDigits: _genelAyarlar.fiyatOndalik,
                  ),
                  style: TextStyle(
                    color: krediKarti.bakiye >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_columnVisibility['currency'] == true)
              _buildCell(
                width: colCurrencyWidth,
                flex: 35,
                child: Text(
                  krediKarti.paraBirimi,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),
            if (_columnVisibility['status'] == true)
              _buildCell(
                width: colStatusWidth,
                flex: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: krediKarti.aktifMi
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
                          color: krediKarti.aktifMi
                              ? const Color(0xFF28A745)
                              : const Color(0xFF757575),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          krediKarti.aktifMi
                              ? tr('common.active')
                              : tr('common.passive'),
                          style: TextStyle(
                            color: krediKarti.aktifMi
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
            if (_columnVisibility['default'] == true)
              _buildCell(
                width: colDefaultWidth,
                alignment: Alignment.center,
                child: InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: () => _krediKartiVarsayilanDegistir(
                    krediKarti,
                    !krediKarti.varsayilan,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: krediKarti.varsayilan
                        ? const Icon(
                            Icons.check_circle,
                            color: Color(0xFF2C3E50),
                            size: 20,
                          )
                        : const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.grey,
                            size: 20,
                          ),
                  ),
                ),
              ),
            _buildCell(
              width: colActionsWidth,
              child: _buildPopupMenu(krediKarti),
            ),
          ],
        );
      },
      detailBuilder: (context, krediKarti) {
        return Container(
          padding: const EdgeInsets.only(
            left: 60,
            right: 24, // Matches Header
            top: 24,
            bottom: 24,
          ),
          color: Colors.grey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Info & Features Box
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildDetailHeaderInfo(krediKarti),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFEEEEEE),
                    ),
                    _buildFeaturesSection(krediKarti),
                  ],
                ),
              ),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: _detailFutures.putIfAbsent(
                  krediKarti.id,
                  () => KrediKartlariVeritabaniServisi()
                      .krediKartiIslemleriniGetir(
                        krediKarti.id,
                        aramaTerimi: _searchQuery,
                        kullanici: _selectedUser,
                        baslangicTarihi: _startDate,
                        bitisTarihi: _endDate,
                        islemTuru: _selectedTransactionType,
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

                  final transactions = snapshot.data ?? [];

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _visibleTransactionIds[krediKarti.id] = transactions
                          .map((t) => t['id'] as int)
                          .toList();
                    }
                  });

                  // Ensure we have a valid map entry
                  if (_selectedDetailIds[krediKarti.id] == null) {
                    _selectedDetailIds[krediKarti.id] = {};
                  }

                  final selectedIds = _selectedDetailIds[krediKarti.id]!;
                  final allSelected =
                      transactions.isNotEmpty &&
                      selectedIds.length == transactions.length;

                  return Container(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                      onChanged: (val) => _onSelectAllDetails(
                                        krediKarti.id,
                                        val,
                                      ),
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
                                    tr('creditcards.detail.timeline'),
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
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
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
                              // Checkbox alanı: Padding(horizontal: 12) + SizedBox(width: 20) = 44px
                              const SizedBox(width: 44),
                              if (_columnVisibility['dt_transaction'] == true)
                                Expanded(
                                  flex: 2,
                                  child: _buildDetailHeader(
                                    tr(
                                      'creditcards.detail.transaction',
                                    ), // İşlem
                                  ),
                                ),
                              if (_columnVisibility['dt_date'] == true) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: _buildDetailHeader(
                                    tr('creditcards.detail.date'),
                                  ),
                                ),
                              ],
                              if (_columnVisibility['dt_party'] == true) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: _buildDetailHeader(
                                    tr(
                                      'creditcards.detail.party',
                                    ), // İlgili Hesap
                                  ),
                                ),
                              ],
                              if (_columnVisibility['dt_amount'] == true) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: _buildDetailHeader(
                                    tr('common.amount'),
                                  ),
                                ),
                              ],
                              if (_columnVisibility['dt_description'] ==
                                  true) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: _buildDetailHeader(
                                    tr('creditcards.detail.description'),
                                  ),
                                ),
                              ],
                              if (_columnVisibility['dt_user'] == true) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: _buildDetailHeader(
                                    tr('creditcards.detail.user'),
                                  ),
                                ),
                              ],
                              // Actions alanı: SizedBox(width: 60) + SizedBox(width: 48) = 108px
                              const SizedBox(width: 108),
                            ],
                          ),
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
                          )
                        else
                          Column(
                            children: transactions.asMap().entries.map((entry) {
                              final index = entry.key;
                              final tx = entry.value;
                              final isLast = index == transactions.length - 1;
                              final bool isIncoming = tx['isIncoming'] == true;

                              final focusScope = TableDetailFocusScope.of(
                                context,
                              );
                              final isFocused =
                                  focusScope?.focusedDetailIndex == index;

                              // Format date properly (dd.MM.yyyy)
                              String formattedDate = '';
                              final rawDate = tx['tarih'];
                              if (rawDate != null) {
                                try {
                                  DateTime parsedDate;
                                  if (rawDate is DateTime) {
                                    parsedDate = rawDate;
                                  } else {
                                    parsedDate = DateTime.parse(
                                      rawDate.toString(),
                                    );
                                  }
                                  formattedDate = DateFormat(
                                    'dd.MM.yyyy HH:mm',
                                  ).format(parsedDate);
                                } catch (_) {
                                  formattedDate = rawDate.toString();
                                }
                              }

                              // [2025 FIX] Determine display name based on transaction source (Check/Note/Bank/etc)
                              String displayName = isIncoming
                                  ? 'Para Alındı'
                                  : 'Para Verildi';

                              final String? integrationRef =
                                  tx['integration_ref']?.toString();
                              final String desc =
                                  (tx['aciklama']?.toString() ?? '')
                                      .toLowerCase();

                              bool isCheckNote = false;
                              if (integrationRef != null) {
                                final lowRef = integrationRef.toLowerCase();
                                if (lowRef.startsWith('sale-') ||
                                    lowRef.startsWith('retail-')) {
                                  displayName = 'Satış Yapıldı';
                                } else if (lowRef.startsWith('purchase-')) {
                                  displayName = 'Alış Yapıldı';
                                } else if (lowRef.contains('opening_stock')) {
                                  displayName = 'Açılış Stoğu';
                                } else if (lowRef.contains('production')) {
                                  displayName = 'Üretim';
                                } else if (lowRef.contains('transfer')) {
                                  displayName = 'Devir';
                                } else if (lowRef.contains('collection')) {
                                  displayName = 'Tahsilat';
                                } else if (lowRef.contains('payment')) {
                                  displayName = 'Ödeme';
                                } else if (lowRef.startsWith('cheque') ||
                                    lowRef.startsWith('cek-')) {
                                  isCheckNote = true;
                                  displayName = isIncoming
                                      ? 'Çek Alındı (Tahsil Edildi)'
                                      : 'Çek Verildi (Ödendi)';
                                } else if (lowRef.startsWith('note') ||
                                    lowRef.startsWith('senet-')) {
                                  isCheckNote = true;
                                  displayName = isIncoming
                                      ? 'Senet Alındı (Tahsil Edildi)'
                                      : 'Senet Verildi (Ödendi)';
                                }
                              }

                              // [UX] Personel Ödemesi: Sadece personel çıkışlarında "Para Verildi" yerine göster.
                              final String txLocationType =
                                  tx['yer']?.toString() ?? '';
                              if (!isIncoming &&
                                  displayName == 'Para Verildi' &&
                                  txLocationType.toLowerCase().contains(
                                    'personel',
                                  )) {
                                displayName = 'Personel Ödemesi';
                              }

                              // If it's a check/note transaction, clear automated descriptions for a cleaner look
                              String displayDescription =
                                  tx['aciklama']?.toString() ?? '';
                              if (isCheckNote) {
                                // Clear if it contains automated keywords
                                if (desc.contains('tahsilat') ||
                                    desc.contains('ödeme') ||
                                    desc.contains('no:')) {
                                  displayDescription = '';
                                }
                              }

                              return Column(
                                children: [
                                  _buildDetailRowCells(
                                    isFocused: isFocused,
                                    krediKarti: krediKarti,
                                    rawTx: tx,
                                    id: tx['id'],
                                    isSelected: selectedIds.contains(tx['id']),
                                    onChanged: (val) => _onSelectDetailRow(
                                      krediKarti.id,
                                      tx['id'],
                                      val,
                                    ),
                                    isIncoming: isIncoming,
                                    name: displayName,
                                    date: formattedDate,
                                    onTap: () {
                                      focusScope?.setFocusedDetailIndex?.call(
                                        index,
                                      );
                                      // Seçili detay transaction bilgisini kaydet
                                      // ve ana satır seçimini temizle (F2 için)
                                      setState(() {
                                        _selectedDetailTransaction = tx;
                                        _selectedDetailKrediKarti = krediKarti;
                                        _selectedRowId = null;
                                      });
                                    },
                                    amount: tx['tutar'] is num
                                        ? (tx['tutar'] as num).toDouble()
                                        : 0.0,
                                    currency: krediKarti.paraBirimi,
                                    locationType: tx['yer']?.toString() ?? '',
                                    locationCode:
                                        tx['yerKodu']?.toString() ?? '',
                                    locationName:
                                        tx['yerAdi']?.toString() ?? '',
                                    description: displayDescription,
                                    user:
                                        (tx['kullanici']?.toString() ?? '')
                                            .isEmpty
                                        ? 'Sistem'
                                        : tx['kullanici'].toString(),
                                    customTypeLabel:
                                        displayName, // Match the visible label for coloring
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
                      ],
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

  Widget _buildDetailHeaderInfo(KrediKartiModel krediKarti) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              krediKarti.kod.isNotEmpty ? krediKarti.kod[0].toUpperCase() : 'K',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      krediKarti.ad,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: krediKarti.aktifMi
                            ? const Color(0xFFE6F4EA)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        krediKarti.aktifMi
                            ? tr('common.active')
                            : tr('common.passive'),
                        style: TextStyle(
                          color: krediKarti.aktifMi
                              ? const Color(0xFF1E7E34)
                              : const Color(0xFF757575),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  krediKarti.kod,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Bakiye Table View
          Container(
            width: 250,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        tr('common.amount'),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 30,
                      child: Text(
                        tr('common.currency_short'),
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
                        tr('products.transaction.type.input'), // Girdi
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
                        FormatYardimcisi.sayiFormatlaOndalikli(
                          0.0, // Placeholder - will be calculated in FutureBuilder
                          binlik: _genelAyarlar.binlikAyiraci,
                          ondalik: _genelAyarlar.ondalikAyiraci,
                          decimalDigits: _genelAyarlar.fiyatOndalik,
                        ),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669), // Yeşil
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 30,
                      child: Text(
                        krediKarti.paraBirimi,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
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
                        tr('products.transaction.type.output'), // Çıktı
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
                        FormatYardimcisi.sayiFormatlaOndalikli(
                          0.0, // Placeholder - will be calculated in FutureBuilder
                          binlik: _genelAyarlar.binlikAyiraci,
                          ondalik: _genelAyarlar.ondalikAyiraci,
                          decimalDigits: _genelAyarlar.fiyatOndalik,
                        ),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFC62828), // Kırmızı
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 30,
                      child: Text(
                        krediKarti.paraBirimi,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
                  child: Divider(height: 1, color: Color(0xFFCBD5E1)),
                ),
                // Toplam (Bakiye) Row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('common.total'),
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
                        FormatYardimcisi.sayiFormatlaOndalikli(
                          krediKarti.bakiye,
                          binlik: _genelAyarlar.binlikAyiraci,
                          ondalik: _genelAyarlar.ondalikAyiraci,
                          decimalDigits: _genelAyarlar.fiyatOndalik,
                        ),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: krediKarti.bakiye >= 0
                              ? const Color(0xFF059669)
                              : const Color(0xFFC62828),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 30,
                      child: Text(
                        krediKarti.paraBirimi,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
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
    );
  }

  Widget _buildFeaturesSection(KrediKartiModel krediKarti) {
    // IBAN formatla (4'lü gruplar halinde)
    String formatIban(String iban) {
      final cleaned = iban.replaceAll(' ', '').toUpperCase();
      final buffer = StringBuffer();
      for (int i = 0; i < cleaned.length; i++) {
        if (i > 0 && i % 4 == 0) {
          buffer.write(' ');
        }
        buffer.write(cleaned[i]);
      }
      return buffer.toString();
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildFeatureItem(
                      tr('creditcards.detail.sube'),
                      '${krediKarti.subeKodu} - ${krediKarti.subeAdi}',
                      icon: Icons.business_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      tr('creditcards.table.info1'), // Banka
                      krediKarti.bilgi1,
                      icon: Icons.info_outline,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  children: [
                    _buildFeatureItem(
                      tr('creditcards.detail.iban'),
                      formatIban(krediKarti.iban),
                      icon: Icons.account_balance_wallet_outlined,
                      copyable: true,
                      copyValue: krediKarti.iban,
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      tr('creditcards.table.info2'), // Hesap No
                      krediKarti.bilgi2,
                      icon: Icons.info_outline,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    String label,
    String value, {
    IconData? icon,
    bool copyable = false,
    String? copyValue,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon ?? Icons.info_outline,
            size: 20,
            color: const Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      value.isEmpty ? '-' : value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (copyable && value.isNotEmpty && value != '-') ...[
                    const SizedBox(width: 6),
                    MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                      onTap: () {
                        final textToCopy =
                            copyValue ?? value.replaceAll(' ', '');
                        Clipboard.setData(ClipboardData(text: textToCopy));
                        MesajYardimcisi.basariGoster(
                          context,
                          tr('common.copied'),
                        );
                      },
                      child: Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                    )),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showEditDialog(KrediKartiModel krediKarti) async {
    final result = await showDialog<KrediKartiModel>(
      context: context,
      builder: (context) => KrediKartiEkleDialog(krediKarti: krediKarti),
    );
    if (result != null) {
      await _fetchKrediKartlari();
      if (mounted) {
        MesajYardimcisi.basariGoster(context, tr('common.saved_successfully'));
      }
    }
  }

  Future<void> _showDepositDialog(KrediKartiModel krediKarti) async {
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            KrediKartiParaGirSayfasi(krediKarti: krediKarti),
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
      await _fetchKrediKartlari();
    }
  }

  Future<void> _showWithdrawDialog(KrediKartiModel krediKarti) async {
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            KrediKartiParaCikSayfasi(krediKarti: krediKarti),
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
      await _fetchKrediKartlari();
    }
  }

  Future<void> _krediKartiDurumDegistir(
    KrediKartiModel krediKarti,
    bool aktifMi,
  ) async {
    try {
      await KrediKartlariVeritabaniServisi().krediKartiGuncelle(
        krediKarti.copyWith(aktifMi: aktifMi),
      );
      _fetchKrediKartlari();
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(context, e.toString());
      }
    }
  }

  Future<void> _krediKartiVarsayilanDegistir(
    KrediKartiModel krediKarti,
    bool varsayilan,
  ) async {
    try {
      await KrediKartlariVeritabaniServisi().krediKartiVarsayilanDegistir(
        krediKarti.id,
        varsayilan,
      );
      await _fetchKrediKartlari(showLoading: false);

      if (!mounted) {
        return;
      }
      MesajYardimcisi.basariGoster(
        context,
        varsayilan
            ? tr('common.success_default_made')
            : tr('common.success_default_removed'),
      );
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(context, e.toString());
      }
    }
  }

  Future<void> _deleteKrediKarti(KrediKartiModel krediKarti) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.delete'),
        mesaj: tr('common.confirm_delete'),
        onayButonMetni: tr('common.delete'),
        iptalButonMetni: tr('common.cancel'),
        isDestructive: true,
        onOnay: () => Navigator.pop(context, true),
      ),
    );

    if (confirm == true) {
      try {
        await KrediKartlariVeritabaniServisi().krediKartiSil(krediKarti.id);
        _fetchKrediKartlari();
        if (mounted) {
          MesajYardimcisi.basariGoster(
            context,
            tr('common.deleted_successfully'),
          );
        }
      } catch (e) {
        if (mounted) {
          MesajYardimcisi.hataGoster(context, e.toString());
        }
      }
    }
  }

  Widget _buildDetailHeader(String text, {bool alignRight = false}) {
    return Text(
      text,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade600,
      ),
    );
  }

  Future<void> _showEditTransactionDialog(
    Map<String, dynamic> tx,
    KrediKartiModel krediKarti,
  ) async {
    final transaction = await KrediKartlariVeritabaniServisi()
        .krediKartiIslemGetir(tx['id']);
    if (transaction == null) {
      return;
    }

    // Determine type: 'isIncoming' is computed in helper.
    // Or we can rely on transaction['isIncoming']?
    // Let's rely on computed helper from service which returns a map.
    // The service returns: 'isIncoming': type == 'Giriş' || type == 'Ödeme' || type == 'Tahsilat'
    // Actually, let's look at the type string directly.

    final isIncoming = transaction['isIncoming'] == true;

    bool? result;
    if (!mounted) {
      return;
    }

    final String? integrationRef = transaction['integration_ref'];
    if (integrationRef != null &&
        (integrationRef.startsWith('CARI-PAV-') ||
            integrationRef.startsWith('TR-'))) {
      final String cariKodu = transaction['yerKodu'] as String? ?? '';
      if (cariKodu.isNotEmpty) {
        final cari = await CariHesaplarVeritabaniServisi().cariHesapGetirByKod(
          cariKodu,
        );
        if (cari != null) {
          final cariIslem = await CariHesaplarVeritabaniServisi()
              .cariIslemGetirByRef(integrationRef);
          if (!mounted) {
            return;
          }
          result = await Navigator.push<bool>(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  CariParaAlVerSayfasi(
                    cari: cari,
                    duzenlenecekIslem: cariIslem ?? transaction,
                  ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
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
        }
      }
    } else {
      if (isIncoming) {
        result = await Navigator.push<bool>(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                KrediKartiParaGirSayfasi(
                  krediKarti: krediKarti,
                  islemId: tx['id'],
                  initialData: transaction,
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
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
      } else {
        result = await Navigator.push<bool>(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                KrediKartiParaCikSayfasi(
                  krediKarti: krediKarti,
                  islemId: tx['id'],
                  initialData: transaction,
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
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
      }
    }

    if (result == true) {
      await _fetchKrediKartlari();
      setState(() {});
    }
  }

  Widget _buildTransactionPopupMenu(
    Map<String, dynamic> tx,
    KrediKartiModel krediKarti,
  ) {
    // 1. Entegrasyon Referans Kontrolü (Kaynak Tespiti)
    final String integrationRef = (tx['integration_ref'] ?? '').toString();
    int? targetIndex;

    if (integrationRef.isNotEmpty) {
      if (integrationRef.startsWith('CARI-') ||
          integrationRef.toLowerCase().startsWith('sale-') ||
          integrationRef.toLowerCase().startsWith('retail-') ||
          integrationRef.toLowerCase().startsWith('purchase-') ||
          integrationRef.toLowerCase().startsWith('invoice-')) {
        targetIndex = 9; // Cari Hesaplar
      } else if (integrationRef.startsWith('AUTO-TR-')) {
        // Kart sayfasındayız (Tab 16)
        // Kaynak Kasa ise Kasa'ya (13), Banka ise Banka'ya (15) gitmeli
        final String kaynakAdi = (tx['kaynak_adi'] ?? '')
            .toString()
            .toLowerCase();
        if (kaynakAdi.contains('kasa')) {
          targetIndex = 13; // Kasalar
        } else if (kaynakAdi.contains('banka')) {
          targetIndex = 15; // Bankalar
        }
      } else if (integrationRef.contains('-CASH-')) {
        targetIndex = 13; // Kasalar
      } else if (integrationRef.contains('-BANK-')) {
        targetIndex = 15; // Bankalar
      } else if (integrationRef.toLowerCase().startsWith('cheque') ||
          integrationRef.toLowerCase().startsWith('cek-')) {
        targetIndex = 14; // Çekler
      } else if (integrationRef.toLowerCase().startsWith('note') ||
          integrationRef.toLowerCase().startsWith('senet-')) {
        targetIndex = 17; // Senetler
      }
    }

    // 2. İşlem Türü Kontrolü (Yedek)
    if (targetIndex == null) {
      final String islemTuru = (tx['islem_turu'] ?? '')
          .toString()
          .toLowerCase();
      if (islemTuru.contains('çek') || islemTuru.contains('cek')) {
        targetIndex = 14;
      } else if (islemTuru.contains('senet')) {
        targetIndex = 17;
      }
    }

    // Eğer hedef sayfa belirlendiyse ve bu sayfa KENDİ sayfamız (Kart) değilse link göster
    // Kart sayfası indexi = 16
    if (targetIndex != null && targetIndex != 16) {
      return Center(
        child: Tooltip(
          message: tr('common.go_to_related_page'),
          child: InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: () {
              final tabScope = TabAciciScope.of(context);
              if (tabScope == null) {
                return;
              }

              // Akıllı Arama Sorgusu
              String q = '';
              final belgeNo = tx['belge']?.toString() ?? '';
              final evrakNo = tx['evrak_no']?.toString() ?? '';
              final aciklama = tx['aciklama']?.toString() ?? '';

              if (belgeNo.isNotEmpty) {
                q = belgeNo;
              } else if (evrakNo.isNotEmpty) {
                q = evrakNo;
              } else if (aciklama.isNotEmpty) {
                q = aciklama;
              }

              tabScope.tabAc(menuIndex: targetIndex!, initialSearchQuery: q);
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.blue.shade100.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                Icons.open_in_new_rounded,
                size: 12,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ),
      );
    }
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
            await _showEditTransactionDialog(tx, krediKarti);
          } else if (value == 'delete') {
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
                  await KrediKartlariVeritabaniServisi().krediKartiIslemSil(
                    tx['id'],
                  );
                  await _fetchKrediKartlari();
                  setState(() {});
                },
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildDetailRowCells({
    required KrediKartiModel krediKarti,
    required Map<String, dynamic> rawTx,
    required int id,
    required bool isSelected,
    required ValueChanged<bool?> onChanged,
    required bool isIncoming,
    required String name,
    required String date,
    required double amount,
    required String currency,
    required String locationType,
    required String locationCode,
    required String locationName,
    required String description,
    required String user,
    String? customTypeLabel, // Add raw type for coloring
    bool isFocused = false,
    VoidCallback? onTap,
  }) {
    return Builder(
      builder: (context) {
        final bool hideActionsMenu = _shouldHideDetailTransactionActions(
          rawTx['integration_ref']?.toString(),
        );

        final String lowRef = (rawTx['integration_ref']?.toString() ?? '')
            .toLowerCase();
        final bool isPerakendeSatis = lowRef.startsWith('retail-');
        final String relatedLocationName = isPerakendeSatis
            ? 'Perakende Satış Yapıldı (K.Kartı)'
            : locationName;
        final String relatedLocationType = isPerakendeSatis ? '' : locationType;
        final String relatedLocationCode = isPerakendeSatis ? '' : locationCode;

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
        return MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFC8E6C9)
                  : (isFocused ? const Color(0xFFE8F5E9) : Colors.transparent),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                  ), // 12+20+12 = 44px
                  child: SizedBox(
                    width: 20,
                    height: 20,
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
                // TRANSACTION TYPE (Girdi/Çıktı Badge)
                if (_columnVisibility['dt_transaction'] == true)
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: IslemTuruRenkleri.arkaplanRengiGetir(
                              customTypeLabel ?? name,
                              isIncoming,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            isIncoming
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: IslemTuruRenkleri.ikonRengiGetir(
                              customTypeLabel ?? name,
                              isIncoming,
                            ),
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HighlightText(
                                text: IslemCeviriYardimcisi.cevir(name),
                                query: _searchQuery,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: IslemTuruRenkleri.metinRengiGetir(
                                    customTypeLabel ?? name,
                                    isIncoming,
                                  ),
                                ),
                              ),
                              if (_getSourceSuffix(
                                locationType,
                                rawTx['integration_ref']?.toString(),
                                locationName,
                              ).isNotEmpty)
                                Text(
                                  IslemCeviriYardimcisi.parantezliKaynakKisaltma(
                                    _getSourceSuffix(
                                      locationType,
                                      rawTx['integration_ref']?.toString(),
                                      locationName,
                                    ),
                                  ),
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
                if (_columnVisibility['dt_date'] == true) ...[
                  const SizedBox(width: 12),
                  // DATE
                  Expanded(
                    flex: 2,
                    child: HighlightText(
                      text: date,
                      query: _searchQuery,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                if (_columnVisibility['dt_party'] == true) ...[
                  const SizedBox(width: 12),
                  // RELATED ACCOUNT (Unified Column)
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (relatedLocationName.isNotEmpty)
                          HighlightText(
                            text: relatedLocationName,
                            query: _searchQuery,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        if (relatedLocationType.isNotEmpty ||
                            relatedLocationCode.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                if (relatedLocationType.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: HighlightText(
                                      text: relatedLocationType,
                                      query: _searchQuery,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                if (relatedLocationType.isNotEmpty &&
                                    relatedLocationCode.isNotEmpty)
                                  const SizedBox(width: 6),
                                if (relatedLocationCode.isNotEmpty)
                                  HighlightText(
                                    text: relatedLocationCode,
                                    query: _searchQuery,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (relatedLocationName.isEmpty &&
                            relatedLocationCode.isEmpty &&
                            relatedLocationType.isEmpty)
                          Text(
                            '-',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (_columnVisibility['dt_amount'] == true) ...[
                  const SizedBox(width: 12),
                  // AMOUNT
                  Expanded(
                    flex: 2,
                    child: HighlightText(
                      text:
                          '${FormatYardimcisi.sayiFormatlaOndalikli(amount, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} $currency',
                      query: _searchQuery,
                      style: TextStyle(
                        color: isIncoming
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                if (_columnVisibility['dt_description'] == true) ...[
                  const SizedBox(width: 12),
                  // DESCRIPTION
                  Expanded(
                    flex: 3,
                    child: HighlightText(
                      text: description.isNotEmpty ? description : '-',
                      query: _searchQuery,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (_columnVisibility['dt_user'] == true) ...[
                  const SizedBox(width: 12),
                  // USER
                  Expanded(
                    flex: 2,
                    child: HighlightText(
                      text: user,
                      query: _searchQuery,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 60),
                SizedBox(
                  width: 48,
                  child: hideActionsMenu
                      ? const SizedBox.shrink()
                      : _buildTransactionPopupMenu(rawTx, krediKarti),
                ),
              ],
            ),
          ),
        ));
      },
    );
  }

  bool _shouldHideDetailTransactionActions(String? integrationRef) {
    final String lowIntegrationRef = (integrationRef ?? '').toLowerCase();
    return lowIntegrationRef.startsWith('cari-') ||
        lowIntegrationRef.startsWith('cheque') ||
        lowIntegrationRef.startsWith('cek-') ||
        lowIntegrationRef.startsWith('note') ||
        lowIntegrationRef.startsWith('senet-');
  }

  void _handleDetailDelete(int id, KrediKartiModel krediKarti) {
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
          await KrediKartlariVeritabaniServisi().krediKartiIslemSil(id);
          SayfaSenkronizasyonServisi().veriDegisti('cari');
          await _fetchKrediKartlari();
          if (mounted) {
            setState(() {
              _selectedDetailTransaction = null;
              _selectedDetailKrediKarti = null;
            });
          }
        },
      ),
    );
  }

  Widget _buildPopupMenu(KrediKartiModel krediKarti) {
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
            value: 'deposit',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.add_circle_outline,
                  size: 20,
                  color: Color(0xFF28A745),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('creditcards.actions.deposit'),
                  style: const TextStyle(
                    color: Color(0xFF28A745),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  tr('common.key.f9'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'withdraw',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.remove_circle_outline,
                  size: 20,
                  color: Color(0xFFDC3545),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('creditcards.actions.withdraw'),
                  style: const TextStyle(
                    color: Color(0xFFDC3545),
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
            value: krediKarti.aktifMi ? 'deactivate' : 'activate',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  krediKarti.aktifMi
                      ? Icons.toggle_on_outlined
                      : Icons.toggle_off_outlined,
                  size: 20,
                  color: const Color(0xFF2C3E50),
                ),
                const SizedBox(width: 12),
                Text(
                  krediKarti.aktifMi
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
          PopupMenuItem<String>(
            value: krediKarti.varsayilan ? 'unmake_default' : 'make_default',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  krediKarti.varsayilan
                      ? Icons.bookmark_remove_outlined
                      : Icons.bookmark_add_outlined,
                  size: 20,
                  color: const Color(0xFF2C3E50),
                ),
                const SizedBox(width: 12),
                Text(
                  krediKarti.varsayilan
                      ? tr('creditcards.actions.unmake_default')
                      : tr('creditcards.actions.make_default'),
                  style: const TextStyle(
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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
            _showEditDialog(krediKarti);
          } else if (value == 'make_default') {
            _krediKartiVarsayilanDegistir(krediKarti, true);
          } else if (value == 'unmake_default') {
            _krediKartiVarsayilanDegistir(krediKarti, false);
          } else if (value == 'deposit') {
            _showDepositDialog(krediKarti);
          } else if (value == 'withdraw') {
            _showWithdrawDialog(krediKarti);
          } else if (value == 'deactivate') {
            _krediKartiDurumDegistir(krediKarti, false);
          } else if (value == 'activate') {
            _krediKartiDurumDegistir(krediKarti, true);
          } else if (value == 'delete') {
            _deleteKrediKarti(krediKarti);
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
    if (_selectedDefault != null) count++;
    if (_selectedTransactionType != null) count++;
    if (_selectedWarehouse != null) count++;
    if (_selectedUser != null) count++;
    return count;
  }

  Widget _buildMobileTopActionRow() {
    final double width = MediaQuery.of(context).size.width;
    final bool isNarrow = width < 360;

    final String addLabel = isNarrow ? 'Ekle' : tr('creditcards.add');
    final String printTooltip =
        _selectedIds.isNotEmpty ||
            _selectedDetailIds.values.any((s) => s.isNotEmpty)
        ? tr('common.print_selected')
        : tr('common.print_list');

    return Row(
      children: [
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
              _buildDefaultFilter(width: double.infinity),
              const SizedBox(height: 12),
              _buildTransactionFilter(width: double.infinity),
              const SizedBox(height: 12),
              _buildWarehouseFilter(width: double.infinity),
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
                Expanded(child: _buildDefaultFilter(width: double.infinity)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTransactionFilter(width: double.infinity),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildWarehouseFilter(width: double.infinity)),
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
                                            _resetPagination();
                                          });
                                          _detailFutures.clear();
                                          _fetchKrediKartlari(
                                            showLoading: false,
                                          );
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
                                        onTap: _deleteSelectedKrediKartlari,
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

  Widget _buildMobileView(List<KrediKartiModel> filteredKrediKartlari) {
    final int totalRecords = _totalRecords > 0
        ? _totalRecords
        : filteredKrediKartlari.length;
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
          _fetchKrediKartlari(showLoading: false);
        }
      });
    }

    final int startRecordIndex = (effectivePage - 1) * safeRowsPerPage;
    final int endRecord = totalRecords == 0
        ? 0
        : (startRecordIndex + filteredKrediKartlari.length).clamp(
            0,
            totalRecords,
          );
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
                    tr('creditcards.title'),
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
                itemCount: filteredKrediKartlari.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildKrediKartiCard(filteredKrediKartlari[index]);
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
                              _fetchKrediKartlari(showLoading: false);
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
                              _fetchKrediKartlari(showLoading: false);
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

  Widget _buildKrediKartiCard(KrediKartiModel krediKarti) {
    final isExpanded = _expandedMobileIds.contains(krediKarti.id);

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
                  value: _selectedIds.contains(krediKarti.id),
                  onChanged: (v) => _onSelectRow(v, krediKarti.id),
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
                      krediKarti.ad,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${krediKarti.kod} • ${krediKarti.bilgi2}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      krediKarti.bilgi1,
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
                children: [_buildPopupMenu(krediKarti)],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status & Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: krediKarti.aktifMi
                      ? const Color(0xFFE6F4EA)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  krediKarti.aktifMi
                      ? tr('common.active')
                      : tr('common.passive'),
                  style: TextStyle(
                    color: krediKarti.aktifMi
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
                          _expandedMobileIds.remove(krediKarti.id);
                        } else {
                          _expandedMobileIds.add(krediKarti.id);
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
                      _buildMobileDetails(krediKarti),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDetails(KrediKartiModel krediKarti) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: KrediKartlariVeritabaniServisi().krediKartiIslemleriniGetir(
        krediKarti.id,
        aramaTerimi: _searchQuery,
        kullanici: _selectedUser,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        islemTuru: _selectedTransactionType,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('${tr('common.error')}: ${snapshot.error}'),
          );
        }

        final transactions = snapshot.data ?? [];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _visibleTransactionIds[krediKarti.id] = transactions
                .map((t) => t['id'] as int)
                .toList();
          }
        });

        if (transactions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              tr('common.no_data'),
              style: TextStyle(color: Colors.grey.shade500),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('creditcards.detail.timeline'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            ...transactions.map((tx) {

              final String yerAdi = tx['yerAdi']?.toString() ?? '';
              final String yerKodu = tx['yerKodu']?.toString() ?? '';
              final String yer = tx['yer']?.toString() ?? '';

              final String? integrationRef = tx['integration_ref']?.toString();
              final String lowRef = integrationRef?.toLowerCase() ?? '';

              bool isIncoming = tx['isIncoming'] == true;
              if (lowRef.startsWith('sale-') || lowRef.startsWith('retail-')) {
                isIncoming = true;
              }

              String relatedName = yerAdi;
              String relatedCode = yerKodu;

              // [EXACTLY LIKE DATATABLE] Determine display name based on isIncoming
              String displayName = isIncoming ? 'Para Alındı' : 'Para Verildi';

              bool isCheckNote = false;
              final String descLower = (tx['aciklama']?.toString() ?? '')
                  .toLowerCase();

              if (integrationRef != null && integrationRef.isNotEmpty) {
                if (lowRef.startsWith('retail-')) {
                  relatedName = 'Perakende Satış Yapıldı (K.Kartı)';
                  relatedCode = '';
                }

                if (lowRef.startsWith('sale-') ||
                    lowRef.startsWith('retail-')) {
                  displayName = 'Satış Yapıldı';
                } else if (lowRef.startsWith('purchase-')) {
                  displayName = 'Alış Yapıldı';
                } else if (lowRef.contains('opening_stock')) {
                  displayName = 'Açılış Stoğu';
                } else if (lowRef.contains('production')) {
                  displayName = 'Üretim';
                } else if (lowRef.contains('transfer')) {
                  displayName = 'Devir';
                } else if (lowRef.contains('collection')) {
                  displayName = 'Tahsilat';
                } else if (lowRef.contains('payment')) {
                  displayName = 'Ödeme';
                } else if (lowRef.startsWith('cheque') ||
                    lowRef.startsWith('cek-')) {
                  isCheckNote = true;
                  displayName = isIncoming
                      ? 'Çek Alındı (Tahsil Edildi)'
                      : 'Çek Verildi (Ödendi)';
                } else if (lowRef.startsWith('note') ||
                    lowRef.startsWith('senet-')) {
                  isCheckNote = true;
                  displayName = isIncoming
                      ? 'Senet Alındı (Tahsil Edildi)'
                      : 'Senet Verildi (Ödendi)';
                }
              }

              // [UX] Personel Ödemesi: Sadece personel çıkışlarında "Para Verildi" yerine göster.
              if (!isIncoming &&
                  displayName == 'Para Verildi' &&
                  yer.toLowerCase().contains('personel')) {
                displayName = 'Personel Ödemesi';
              }

              // Add location type suffix like DataTable using _getSourceSuffix
              final String sourceSuffix = _getSourceSuffix(
                yer,
                integrationRef,
                yerAdi,
              );
              if (sourceSuffix.isNotEmpty) {
                displayName = '$displayName $sourceSuffix';
              }

              // Format date properly (dd.MM.yyyy HH:mm)
              String formattedDate = '';
              final rawDate = tx['tarih'];
              if (rawDate != null) {
                try {
                  final DateTime parsedDate = rawDate is DateTime
                      ? rawDate
                      : DateTime.parse(rawDate.toString());
                  formattedDate = DateFormat(
                    'dd.MM.yyyy HH:mm',
                  ).format(parsedDate);
                } catch (_) {
                  formattedDate = rawDate.toString();
                }
              }

              String description = tx['aciklama']?.toString() ?? '';
              if (isCheckNote) {
                if (descLower.contains('tahsilat') ||
                    descLower.contains('ödeme') ||
                    descLower.contains('no:')) {
                  description = '';
                }
              }

              final double amount = tx['tutar'] is num
                  ? (tx['tutar'] as num).toDouble()
                  : double.tryParse(tx['tutar']?.toString() ?? '') ?? 0.0;
              final String user = (tx['kullanici']?.toString() ?? '').isEmpty
                  ? 'Sistem'
                  : tx['kullanici'].toString();

              return _buildMobileTransactionRow(
                isIncoming: isIncoming,
                title: IslemCeviriYardimcisi.cevir(displayName),
                date: formattedDate,
                relatedName: relatedName,
                relatedCode: relatedCode,
                amount: amount,
                currency: krediKarti.paraBirimi,
                user: user,
                description: description,
                customTypeLabel: displayName,
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildMobileTransactionRow({
    required bool isIncoming,
    required String title,
    required String date,
    required String relatedName,
    required String relatedCode,
    required double amount,
    required String currency,
    required String user,
    required String description,
    String? customTypeLabel,
  }) {
    final String normalizedRelatedName = relatedName.isNotEmpty
        ? relatedName
        : (relatedCode.isNotEmpty ? relatedCode : '-');

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
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: IslemTuruRenkleri.metinRengiGetir(
                            customTypeLabel,
                            isIncoming,
                          ),
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
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.link_outlined,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              normalizedRelatedName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (relatedName.isNotEmpty && relatedCode.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                relatedCode,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${FormatYardimcisi.sayiFormatlaOndalikli(amount, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} $currency',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isIncoming
                            ? Colors.green.shade700
                            : Colors.red.shade700,
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
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
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

  String _getSourceSuffix(
    String locationType,
    String? integrationRef,
    String locationName,
  ) {
    // If it's a direct entry (no destination), default to current page type (K.Kartı)
    if (locationType.isEmpty && locationName.isEmpty) return '(K.Kartı)';

    // Priority 1: Integration Reference check (Origin based)
    if (integrationRef != null) {
      final String lowRef = integrationRef.toLowerCase();
      if (lowRef.startsWith('cheque') || lowRef.startsWith('cek-')) return '';
      if (lowRef.startsWith('note') || lowRef.startsWith('senet-')) return '';
      if (lowRef.startsWith('retail-')) return '(K.Kartı)';

      if (integrationRef.startsWith('CARI-')) return '(Cari)';
      if (integrationRef.startsWith('AUTO-TR-')) {
        // More intelligent check based on internal location codes
        if (locationType == 'current_account' || locationType == 'Cari Hesap') {
          return '(K.Kartı)';
        }
        if (locationType == 'bank') {
          return '(Banka)';
        }
        if (locationType == 'credit_card') {
          return '(K.Kartı)';
        }
        if (locationType == 'cash') {
          return '(Kasa)';
        }

        // Fallback for mapped/localized types
        final lowType = locationType.toLowerCase();
        if (lowType.contains('cari')) return '(Cari)';
        if (lowType.contains('banka')) return '(Banka)';
        if (lowType.contains('kart')) return '(K.Kartı)';

        return '(K.Kartı)'; // Default for KK page
      }

      // Legacy support for older formats
      if (integrationRef.contains('-CASH-')) return '(Kasa)';
      if (integrationRef.contains('-BANK-')) return '(Banka)';
      if (integrationRef.contains('-CREDIT_CARD-')) return '(K.Kartı)';
      if (integrationRef.contains('-CARI-')) return '(Cari)';
    }

    // Money Transactions check
    final bool isMoneyTx =
        locationType == 'Para Alındı' ||
        locationType == 'Para Verildi' ||
        locationType == 'Kasa' ||
        locationType == 'Banka' ||
        locationType == 'Kredi Kartı' ||
        locationType == 'Girdi' ||
        locationType == 'Tahsilat' ||
        locationType == 'Çıktı' ||
        locationType == 'Ödeme' ||
        locationType == 'Cari İşlem' ||
        locationType == 'current_account' ||
        locationType == 'bank' ||
        locationType == 'cash' ||
        locationType == 'credit_card' ||
        locationType.contains('Dekont');

    if (isMoneyTx) {
      final lowName = locationName.toLowerCase();
      final lowType = locationType.toLowerCase();

      if (lowName.contains('kasa') ||
          lowType.contains('kasa') ||
          locationType == 'cash') {
        return '(Kasa)';
      }
      if (lowName.contains('banka') ||
          lowType.contains('banka') ||
          locationType == 'bank') {
        return '(Banka)';
      }
      if (lowName.contains('pos') ||
          lowName.contains('kart') ||
          lowType.contains('kart') ||
          locationType == 'credit_card') {
        return '(K.Kartı)';
      }
      if (lowName.contains('cari') ||
          lowType.contains('cari') ||
          locationType == 'current_account') {
        return '(K.Kartı)';
      }
    }

    // Diğer işlemler için (Fatura, Çek, Senet)
    if (locationType.toLowerCase().contains('satış') ||
        locationType.toLowerCase().contains('alış') ||
        locationType.toLowerCase().contains('fatura')) {
      return '(Cari)';
    }

    // Default for KK page entries
    return '(K.Kartı)';
  }
}

class _WarehouseFilterOverlay extends StatefulWidget {
  final KrediKartiModel? selectedWarehouse;
  final ValueChanged<KrediKartiModel?> onSelect;

  const _WarehouseFilterOverlay({
    required this.selectedWarehouse,
    required this.onSelect,
  });

  @override
  State<_WarehouseFilterOverlay> createState() =>
      _WarehouseFilterOverlayState();
}

class _WarehouseFilterOverlayState extends State<_WarehouseFilterOverlay> {
  final TextEditingController _searchController = TextEditingController();
  List<KrediKartiModel> _krediKartlari = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchKrediKartlari();
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
      _fetchKrediKartlari();
    });
  }

  Future<void> _fetchKrediKartlari() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await KrediKartlariVeritabaniServisi().krediKartiAra(
        _searchController.text,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _krediKartlari = results;
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
                    ..._krediKartlari.map(
                      (krediKarti) => _buildOption(krediKarti, krediKarti.ad),
                    ),
                    if (_krediKartlari.isEmpty &&
                        _searchController.text.isNotEmpty)
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

  Widget _buildOption(KrediKartiModel? value, String label) {
    final isSelected = widget.selectedWarehouse?.id == value?.id;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: () => widget.onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFE6F4EA) : Colors.transparent,
        child: Text(
          label,
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
