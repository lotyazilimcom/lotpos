import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../bilesenler/genisletilebilir_tablo.dart';
import '../ayarlar/genel_ayarlar/veri_kaynagi/genel_ayarlar_veri_kaynagi.dart';
import '../../bilesenler/onay_dialog.dart';
import '../../bilesenler/tarih_araligi_secici_dialog.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/ceviri/islem_ceviri_yardimcisi.dart';
import '../../yardimcilar/responsive_yardimcisi.dart';
import 'modeller/senet_model.dart';

// import 'cek_ekle_dialog.dart'; // Sonra yapılacak
import 'senet_al_dialog.dart';
import 'senet_ver_dialog.dart';
import 'senet_tahsil_sayfasi.dart';
import 'senet_ciro_sayfasi.dart';
// import 'banka_hareket_sayfasi.dart';
import '../../servisler/senetler_veritabani_servisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../ortak/genisletilebilir_print_preview_screen.dart';
import '../../bilesenler/highlight_text.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../../yardimcilar/islem_turu_renkleri.dart';
import '../../servisler/sayfa_senkronizasyon_servisi.dart';

class SenetlerSayfasi extends StatefulWidget {
  final String? initialSearchQuery;
  const SenetlerSayfasi({super.key, this.initialSearchQuery});

  @override
  State<SenetlerSayfasi> createState() => _SenetlerSayfasiState();
}

class _SenetlerSayfasiState extends State<SenetlerSayfasi> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<SenetModel> _cachedCekler = [];

  bool _isLoading = false;
  bool _isMobileToolbarExpanded = false;
  int _totalRecords = 0;
  final Set<int> _selectedIds = {};
  int _rowsPerPage = 25;
  int _currentPage = 1;
  final Set<int> _expandedMobileIds = {};
  Set<int> _autoExpandedIndices = {};
  int? _manualExpandedIndex;

  // Date Filter State
  DateTime? _startDate;
  DateTime? _endDate;

  Map<String, Map<String, int>> _filterStats = {};

  // Overlay State
  final LayerLink _transactionLayerLink = LayerLink();
  final LayerLink _bankLayerLink = LayerLink();
  final LayerLink _userLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  // Transaction Filter State
  bool _isTransactionFilterExpanded = false;
  String? _selectedTransactionType;

  // Bank Filter State
  bool _isBankFilterExpanded = false;
  String? _selectedBank;

  // User Filter State
  bool _isUserFilterExpanded = false;
  String? _selectedUser;

  // Mock transactions for detail view
  // Transactions

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

  // ─────────────────────────────────────────────────────────────────
  // Klavye Navigasyonu State Değişkenleri
  // ─────────────────────────────────────────────────────────────────
  /// Klavye navigasyonu ile seçilen ana satırın ID'sini tutar
  int? _selectedRowId;

  /// Klavye navigasyonu ile seçilen detay satırının ID'sini tutar
  int? _selectedDetailTransactionId;

  /// Seçili detay satırının ait olduğu senet modelini tutar
  SenetModel? _selectedDetailSenet;

  @override
  void initState() {
    super.initState();
    _columnVisibility = {
      // Main Table
      'order_no': true,
      'code': true,
      'name': true,
      'amount': true,
      'currency': true,
      'bank': true,
      'issue_date': true,
      'due_date': true,
      // Detail Table
      'dt_transaction': true,
      'dt_date': true,
      'dt_contact': true,
      'dt_amount': true,
      'dt_description': true,
      'dt_user': true,
    };
    if (widget.initialSearchQuery != null) {
      _searchController.text = widget.initialSearchQuery!;
      _searchQuery = widget.initialSearchQuery!.toLowerCase();
    }
    _loadSettings();
    _fetchSenetler();

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (_searchController.text != _searchQuery) {
          setState(() {
            _searchQuery = _searchController.text.toLowerCase();
            _currentPage = 1;
          });
          _fetchSenetler();
        }
      });
    });

    SayfaSenkronizasyonServisi().addListener(_onGlobalSync);
  }

  void _onGlobalSync() {
    _fetchSenetler(showLoading: false);
  }

  void _resetPagination() {
    _currentPage = 1;
  }

  Future<void> _fetchSenetler({bool showLoading = true}) async {
    // Clear detail cache when refreshing main list
    _detailFutures.clear();

    final int sorguNo = ++_aktifSorguNo;

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final depolar = await SenetlerVeritabaniServisi().senetleriGetir(
        sayfa: _currentPage,
        sayfaBasinaKayit: _rowsPerPage,
        aramaKelimesi: _searchQuery,
        siralama: _sortBy,
        artanSiralama: _sortAscending,
        aktifMi: null, // Filter removed
        banka: _selectedBank,
        kullanici: _selectedUser,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        islemTuru: _selectedTransactionType,
      );

      if (!mounted || sorguNo != _aktifSorguNo) return;

      final totalFuture = SenetlerVeritabaniServisi().senetSayisiGetir(
        aramaTerimi: _searchQuery,
        aktifMi: null,
        banka: _selectedBank,
        kullanici: _selectedUser,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        islemTuru: _selectedTransactionType,
      );

      final statsFuture = SenetlerVeritabaniServisi()
          .senetFiltreIstatistikleriniGetir(
            aramaTerimi: _searchQuery,
            baslangicTarihi: _startDate,
            bitisTarihi: _endDate,
            banka: _selectedBank,
            islemTuru: _selectedTransactionType,
            kullanici: _selectedUser,
          );

      if (mounted) {
        final indices = <int>{};
        final bool hasNonSearchFilter =
            _selectedBank != null ||
            _startDate != null ||
            _endDate != null ||
            _selectedTransactionType != null ||
            _selectedUser != null;

        if (hasNonSearchFilter) {
          indices.addAll(List.generate(depolar.length, (i) => i));
        } else if (_searchQuery.isNotEmpty) {
          for (int i = 0; i < depolar.length; i++) {
            if (depolar[i].matchedInHidden) {
              indices.add(i);
              _expandedMobileIds.add(depolar[i].id);
            }
          }
        }

        setState(() {
          _cachedCekler = depolar;
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
              debugPrint('Senet toplam sayısı güncellenemedi: $e');
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
              debugPrint('Senet filtre istatistikleri güncellenemedi: $e');
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

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = await GenelAyarlarVeriKaynagi().ayarlariGetir();
      if (mounted) {
        setState(() {
          _keepDetailsOpen = prefs.getBool('cekler_keep_details_open') ?? false;
          _genelAyarlar = settings;
        });
      }
    } catch (e) {
      debugPrint('Depolar ayarlar yüklenirken hata: $e');
    }
  }

  Future<void> _toggleKeepDetailsOpen() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _keepDetailsOpen = !_keepDetailsOpen;

      // [2026 PROFESYONEL] Eğer kapatılıyorsa ve bir filtre aktifse
      final bool hasFilter =
          _searchQuery.isNotEmpty ||
          _selectedBank != null ||
          _startDate != null ||
          _endDate != null ||
          _selectedTransactionType != null ||
          _selectedUser != null;

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
    await prefs.setBool('cekler_keep_details_open', _keepDetailsOpen);
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
                            tr('notes.table.code'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'name',
                            tr('notes.table.name'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'amount',
                            tr('notes.table.amount'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'currency',
                            tr('notes.table.currency'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'bank',
                            tr('notes.table.bank'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'issue_date',
                            tr('notes.table.issue_date'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'due_date',
                            tr('notes.table.due_date'),
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
                            tr('notes.detail.transaction'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_date',
                            tr('notes.detail.date'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_contact',
                            tr('notes.detail.contact'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_amount',
                            tr('notes.detail.amount'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_description',
                            tr('notes.detail.description'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_user',
                            tr('notes.detail.user'),
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
    _startDateController.dispose();
    _endDateController.dispose();
    _searchFocusNode.dispose();
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _isTransactionFilterExpanded = false;
        _isBankFilterExpanded = false;
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
      _fetchSenetler();
    }
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

  void _showBankOverlay() {
    _closeOverlay();
    setState(() {
      _isBankFilterExpanded = true;
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
            link: _bankLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 42),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Container(
                width: 260,
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
                      _buildBankOption(null, tr('common.all')),
                      ...(_filterStats['bankalar']?.entries.map((e) {
                            return _buildBankOption(e.key, e.key);
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

  List<SenetModel> _filterSenetler(List<SenetModel> depolar) {
    if (_searchQuery.isEmpty) return depolar;

    final q = _normalizeTurkish(_searchQuery);
    return depolar.where((depo) {
      final codeMatch = _normalizeTurkish(depo.senetNo).contains(q);
      final nameMatch = _normalizeTurkish(depo.cariAdi).contains(q);
      final addressMatch = _normalizeTurkish(depo.banka).contains(q);
      final responsibleMatch = _normalizeTurkish(depo.aciklama).contains(q);
      final phoneMatch = _normalizeTurkish(depo.paraBirimi).contains(q);
      final tagsMatch = _normalizeTurkish(depo.searchTags ?? '').contains(q);
      final hiddenMatch = depo.matchedInHidden;

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
    final result = await showDialog<SenetModel>(
      context: context,
      builder: (context) => const SenetAlDialog(),
    );

    if (result != null) {
      try {
        await SenetlerVeritabaniServisi().senetEkle(result);
        SayfaSenkronizasyonServisi().veriDegisti('cari');
        await _fetchSenetler();

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

  Future<void> _showEditDialog(SenetModel senet) async {
    final result = await showDialog<SenetModel>(
      context: context,
      builder: (context) => SenetAlDialog(senet: senet),
    );

    if (result != null) {
      try {
        await SenetlerVeritabaniServisi().senetGuncelle(result);
        SayfaSenkronizasyonServisi().veriDegisti('cari');
        await _fetchSenetler();

        if (mounted) {
          MesajYardimcisi.basariGoster(
            context,
            tr('common.updated_successfully'),
          );
          SayfaSenkronizasyonServisi().veriDegisti('cari');
        }
      } catch (e) {
        if (mounted) {
          MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
        }
      }
    }
  }

  Future<void> _deleteSelectedSenetler() async {
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
          await SenetlerVeritabaniServisi().senetSil(id);
        }

        SayfaSenkronizasyonServisi().veriDegisti('cari');
        await _fetchSenetler();

        setState(() {
          _selectedIds.clear();
        });

        if (mounted) {
          MesajYardimcisi.basariGoster(
            context,
            tr('common.deleted_successfully'),
          );
          SayfaSenkronizasyonServisi().veriDegisti('cari');
          SayfaSenkronizasyonServisi().veriDegisti('kasalar');
          SayfaSenkronizasyonServisi().veriDegisti('bankalar');
          SayfaSenkronizasyonServisi().veriDegisti('krediKartlari');
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

  Future<void> _showCollectDialog(SenetModel senet) async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SenetTahsilSayfasi(senet: senet),
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
      SayfaSenkronizasyonServisi().veriDegisti('cari');
      await _fetchSenetler();
    }
  }

  Future<void> _showEndorseDialog(SenetModel senet) async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SenetCiroSayfasi(senet: senet),
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
      SayfaSenkronizasyonServisi().veriDegisti('cari');
      await _fetchSenetler();
    }
  }

  void _deleteSenet(SenetModel depo) async {
    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr(
          'common.confirm_delete_named',
        ).replaceAll('{name}', depo.cariAdi),
        onOnay: () {},
        isDestructive: true,
        onayButonMetni: tr('common.delete'),
      ),
    );

    if (onay == true) {
      try {
        await SenetlerVeritabaniServisi().senetSil(depo.id);
        SayfaSenkronizasyonServisi().veriDegisti('cari');
        await _fetchSenetler();

        if (mounted) {
          MesajYardimcisi.basariGoster(
            context,
            tr('common.deleted_successfully'),
          );
          SayfaSenkronizasyonServisi().veriDegisti('cari');
          SayfaSenkronizasyonServisi().veriDegisti('kasalar');
          SayfaSenkronizasyonServisi().veriDegisti('bankalar');
          SayfaSenkronizasyonServisi().veriDegisti('krediKartlari');
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

  Future<void> _showGiveNoteDialog() async {
    final result = await showDialog<SenetModel>(
      context: context,
      builder: (context) => const SenetVerDialog(),
    );

    if (result != null) {
      try {
        await SenetlerVeritabaniServisi().senetEkle(result);
        SayfaSenkronizasyonServisi().veriDegisti('cari');
        await _fetchSenetler();

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _cachedCekler.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filtreleme mantığı
    List<SenetModel> filteredCekler = _cachedCekler;

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
                  _selectedBank != null ||
                  _selectedUser != null ||
                  _selectedTransactionType != null) {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _startDateController.clear();
                  _endDateController.clear();
                  _selectedBank = null;
                  _selectedUser = null;
                  _selectedTransactionType = null;
                  _resetPagination();
                });
                _fetchSenetler();
                return;
              }
            },
            // F1: Senet Al (Yeni Ekle)
            const SingleActivator(LogicalKeyboardKey.f1): _showAddDialog,
            // F2: Seçili Düzenle
            const SingleActivator(LogicalKeyboardKey.f2): () {
              if (_selectedRowId == null) return;
              final senet = _cachedCekler.firstWhere(
                (s) => s.id == _selectedRowId,
                orElse: () => _cachedCekler.first,
              );
              if (senet.id == _selectedRowId) {
                _showEditDialog(senet);
              }
            },
            // F3: Arama kutusuna odaklan
            const SingleActivator(LogicalKeyboardKey.f3): () {
              _searchFocusNode.requestFocus();
            },
            // F5: Yenile
            const SingleActivator(LogicalKeyboardKey.f5): () {
              _fetchSenetler();
            },

            // F7: Yazdır
            const SingleActivator(LogicalKeyboardKey.f7): _handlePrint,
            // F8: Seçilileri Toplu Sil
            const SingleActivator(LogicalKeyboardKey.f8): () {
              if (_selectedIds.isEmpty) return;
              _deleteSelectedSenetler();
            },
            // F4: Senet Ver
            const SingleActivator(LogicalKeyboardKey.f4): _showGiveNoteDialog,
            // F9: Tahsil Et
            const SingleActivator(LogicalKeyboardKey.f9): () {
              if (_selectedRowId == null) return;
              final senet = _cachedCekler.firstWhere(
                (s) => s.id == _selectedRowId,
                orElse: () => _cachedCekler.first,
              );
              if (senet.id == _selectedRowId) {
                _showCollectDialog(senet);
              }
            },
            // F10: Ciro Et
            const SingleActivator(LogicalKeyboardKey.f10): () {
              if (_selectedRowId == null) return;
              final senet = _cachedCekler.firstWhere(
                (s) => s.id == _selectedRowId,
                orElse: () => _cachedCekler.first,
              );
              if (senet.id == _selectedRowId) {
                _showEndorseDialog(senet);
              }
            },
            // Delete: Seçili Satırı Sil veya Detay Satırı Sil
            const SingleActivator(LogicalKeyboardKey.delete): () {
              // Priority 1: Detay satırı seçiliyse detay sil
              if (_selectedDetailTransactionId != null &&
                  _selectedDetailSenet != null) {
                _handleDetailDelete(
                  _selectedDetailSenet!.id,
                  _selectedDetailTransactionId!,
                );
                return;
              }
              // Priority 2: Ana satırı sil
              if (_selectedRowId == null) return;
              final senet = _cachedCekler.firstWhere(
                (s) => s.id == _selectedRowId,
                orElse: () => _cachedCekler.first,
              );
              if (senet.id == _selectedRowId) {
                _deleteSenet(senet);
              }
            },
            // Numpad Delete
            const SingleActivator(LogicalKeyboardKey.numpadDecimal): () {
              // Priority 1: Detay satırı seçiliyse detay sil
              if (_selectedDetailTransactionId != null &&
                  _selectedDetailSenet != null) {
                _handleDetailDelete(
                  _selectedDetailSenet!.id,
                  _selectedDetailTransactionId!,
                );
                return;
              }
              // Priority 2: Ana satırı sil
              if (_selectedRowId == null) return;
              final senet = _cachedCekler.firstWhere(
                (s) => s.id == _selectedRowId,
                orElse: () => _cachedCekler.first,
              );
              if (senet.id == _selectedRowId) {
                _deleteSenet(senet);
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
                    return _buildMobileView(filteredCekler);
                  } else {
                    return _buildDesktopView(filteredCekler, constraints);
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
        _selectedIds.addAll(_filterSenetler(_cachedCekler).map((e) => e.id));
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

  /// Tablo dışına tıklandığında veya ESC tuşuna basıldığında
  /// tüm seçimleri temizler
  void _clearAllTableSelections() {
    setState(() {
      _selectedIds.clear();
      _selectedDetailIds.clear();
      _selectedRowId = null;
      _selectedDetailTransactionId = null;
      _selectedDetailSenet = null;
    });
  }

  void _handleDetailDelete(int senetId, int transactionId) {
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
          await SenetlerVeritabaniServisi().senetIsleminiSil(transactionId);
          SayfaSenkronizasyonServisi().veriDegisti('cari');
          SayfaSenkronizasyonServisi().veriDegisti('kasalar');
          SayfaSenkronizasyonServisi().veriDegisti('bankalar');
          SayfaSenkronizasyonServisi().veriDegisti('krediKartlari');
          _detailFutures.remove(senetId);
          await _fetchSenetler();
          if (mounted) {
            setState(() {
              _selectedDetailTransactionId = null;
              _selectedDetailSenet = null;
            });
          }
        },
      ),
    );
  }

  void _onSelectAllDetails(int senetId, bool? value) {
    setState(() {
      if (value == true) {
        _selectedDetailIds[senetId] = (_visibleTransactionIds[senetId] ?? [])
            .toSet();
      } else {
        _selectedDetailIds[senetId]?.clear();
      }
    });
  }

  void _onSelectDetailRow(int senetId, int transactionId, bool? value) {
    setState(() {
      if (_selectedDetailIds[senetId] == null) {
        _selectedDetailIds[senetId] = {};
      }
      if (value == true) {
        _selectedDetailIds[senetId]!.add(transactionId);
      } else {
        _selectedDetailIds[senetId]!.remove(transactionId);
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
        case 7: // Düzenlenme Tarihi
          _sortBy = 'duzenlenme_tarihi';
          break;
        case 8: // Keşide Tarihi
          _sortBy = 'keside_tarihi';
          break;
        default:
          _sortBy = 'id';
      }
    });
    _fetchSenetler(showLoading: false);
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
          ? _cachedCekler
                .where((s) => mainRowIdsToProcess.contains(s.id))
                .toList()
          : _cachedCekler;

      for (var i = 0; i < dataToProcess.length; i++) {
        final depo = dataToProcess[i];

        // Determine if row is expanded
        final originalIndex = _cachedCekler.indexOf(depo);
        final isExpanded =
            _keepDetailsOpen ||
            _autoExpandedIndices.contains(originalIndex) ||
            _manualExpandedIndex == originalIndex;

        List<Map<String, dynamic>> transactions = [];
        // 1. Transactions Fetch (Only if expanded or has selected details)
        final hasPrintSelectedDetails =
            _selectedDetailIds[depo.id]?.isNotEmpty ?? false;
        if (isExpanded || hasPrintSelectedDetails) {
          transactions = await SenetlerVeritabaniServisi()
              .senetIslemleriniGetir(depo.id);
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

        // 2. Main Row Data - Datatable ile aynı sırada
        final String typeStr = depo.tur == 'Alınan Senet'
            ? '(${tr('notes.type.received_short')})'
            : '(${tr('notes.type.given_short')})';
        final String statusStr =
            (depo.tahsilat == 'Tahsil Edildi' ||
                depo.tahsilat == 'Ödendi' ||
                depo.tahsilat == 'Ciro Edildi' ||
                depo.tahsilat == 'Karşılıksız')
            ? '\n($typeStr ${IslemCeviriYardimcisi.cevirDurum(depo.tahsilat)})'
            : '\n$typeStr';

        final mainRow = [
          depo.id.toString(),
          '${depo.senetNo}$statusStr', // Merged like Screen
          depo.cariAdi,
          '${FormatYardimcisi.sayiFormatlaOndalikli(depo.tutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${depo.paraBirimi}',
          depo.banka.isNotEmpty ? depo.banka : '-',
          depo.duzenlenmeTarihi,
          depo.kesideTarihi,
        ];

        // 3. Details (Sadece genişletilmiş satırlar için)
        Map<String, String> details = {};
        if (isExpanded || hasPrintSelectedDetails) {
          details = {};
        }

        // 4. Transaction Table
        DetailTable? txTable;
        if (transactions.isNotEmpty) {
          txTable = DetailTable(
            title: tr('notes.detail.movements'),
            headers: [
              tr('notes.detail.type'),
              tr('notes.detail.date'),
              tr('notes.detail.contact'),
              tr('notes.detail.amount'),
              tr('notes.detail.description'),
              tr('notes.detail.user'),
            ],
            data: transactions.map((t) {
              // Format date properly like DataTable
              final String rawDate = t['date']?.toString() ?? '';
              String formattedDate = rawDate;
              if (rawDate.isNotEmpty) {
                try {
                  DateTime parsedDate = DateTime.parse(rawDate);
                  formattedDate = DateFormat(
                    'dd.MM.yyyy HH:mm',
                  ).format(parsedDate);
                } catch (_) {}
              }

              return <String>[
                t['type']?.toString() ?? '',
                formattedDate,
                t['source_dest']?.toString() ?? '',
                '${FormatYardimcisi.sayiFormatla(t['amount'], binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${depo.paraBirimi}',
                t['description']?.toString() ?? '',
                t['user_name']?.toString() ?? tr('common.system'),
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
            title: tr('notes.title'),
            headers: [
              tr('language.table.orderNo'),
              tr('notes.table.note_no'),
              tr('notes.table.customer_name'),
              tr('notes.table.amount'), // Para birimi tutar içinde
              tr('notes.table.bank'),
              tr('notes.table.issue_date'),
              tr('notes.table.due_date'),
            ],
            data: rows,
            dateInterval: dateInfo,
            hideFeaturesCheckbox: true,
            initialShowDetails:
                _keepDetailsOpen ||
                _autoExpandedIndices.isNotEmpty ||
                _manualExpandedIndex != null,
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
          Expanded(child: _buildBankFilter(width: double.infinity)),
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
                  _fetchSenetler();
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

  Widget _buildBankFilter({double? width}) {
    return CompositedTransformTarget(
      link: _bankLayerLink,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () {
          if (_isBankFilterExpanded) {
            _closeOverlay();
          } else {
            _showBankOverlay();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 200,
          padding: EdgeInsets.fromLTRB(0, 8, 0, _isBankFilterExpanded ? 7 : 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isBankFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade300,
                width: _isBankFilterExpanded ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_rounded,
                size: 20,
                color: _isBankFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedBank == null
                      ? tr('notes.table.bank')
                      : '$_selectedBank (${_filterStats['bankalar']?[_selectedBank] ?? 0})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isBankFilterExpanded
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedBank != null)
                InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: () {
                    setState(() {
                      _selectedBank = null;
                      _currentPage = 1;
                    });
                    _fetchSenetler();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isBankFilterExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: _isBankFilterExpanded
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
                      : '${IslemCeviriYardimcisi.cevir(IslemTuruRenkleri.getProfessionalLabel(_selectedTransactionType!, context: 'promissory_note'))} (${_filterStats['islem_turleri']?[_selectedTransactionType] ?? 0})',
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
                    _fetchSenetler();
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
                    _fetchSenetler();
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
        _fetchSenetler();
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

  Widget _buildBankOption(String? value, String label) {
    final isSelected = _selectedBank == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['bankalar']?[value] ?? 0);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: () {
        setState(() {
          _selectedBank = value;
          _isBankFilterExpanded = false;
          _currentPage = 1;
        });
        _closeOverlay();
        _fetchSenetler();
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
        _fetchSenetler();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFF0F7FF) : Colors.transparent,
        child: Text(
          '${value == null ? label : IslemCeviriYardimcisi.cevir(IslemTuruRenkleri.getProfessionalLabel(value, context: 'promissory_note'))} ($count)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF2C3E50) : Colors.black87,
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
    List<SenetModel> depolar,
    BoxConstraints constraints,
  ) {
    final bool allSelected =
        depolar.isNotEmpty && depolar.every((d) => _selectedIds.contains(d.id));

    // Calculate column widths based on header text for single-line display
    final colOrderWidth = _calculateColumnWidth(
      tr('language.table.orderNo'),
      sortable: true,
    );
    final colCodeWidth = _calculateColumnWidth(
      tr('notes.table.code'),
      sortable: true,
    );
    final colBranchCodeWidth = _calculateColumnWidth(
      tr('notes.table.issue_date'),
      sortable: true,
    );
    final colBranchNameWidth = _calculateColumnWidth(
      tr('notes.table.due_date'),
      sortable: true,
    );
    const colActionsWidth = 100.0;

    return GenisletilebilirTablo<SenetModel>(
      title: tr('notes.title'),
      headerWidget: _buildFilters(),
      getDetailItemCount: (senet) =>
          _visibleTransactionIds[senet.id]?.length ?? 0,
      searchFocusNode: _searchFocusNode,
      onFocusedRowChanged: (item, index) {
        if (item != null) {
          setState(() => _selectedRowId = item.id);
        }
      },
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
        _fetchSenetler();
      },
      onSearch: (query) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          setState(() {
            _searchQuery = query;
            _currentPage = 1;
          });
          _fetchSenetler(showLoading: false);
        });
      },
      selectionWidget: _selectedIds.isNotEmpty
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
                onTap: _deleteSelectedSenetler,
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
              onTap: _showGiveNoteDialog,
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
                      Icons.call_made_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('notes.give'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr('common.key.f4'),
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
                    const Icon(
                      Icons.call_received_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('notes.receive'),
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
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['code'] == true)
          GenisletilebilirTabloKolon(
            label: tr('notes.table.code'),
            width: colCodeWidth,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['name'] == true)
          GenisletilebilirTabloKolon(
            label: tr('notes.table.name'),
            width: 200,
            alignment: Alignment.centerLeft,
            allowSorting: true,
            flex: 30,
          ),
        if (_columnVisibility['amount'] == true)
          GenisletilebilirTabloKolon(
            label: tr('notes.table.amount'),
            width: 150,
            alignment: Alignment.centerRight,
            allowSorting: true,
          ),
        if (_columnVisibility['currency'] == true)
          GenisletilebilirTabloKolon(
            label: tr('notes.table.currency'),
            width: 100,
            alignment: Alignment.centerLeft,
            allowSorting: false,
            flex: 20,
          ),
        if (_columnVisibility['bank'] == true)
          GenisletilebilirTabloKolon(
            label: tr('notes.table.bank'),
            width: 150,
            alignment: Alignment.centerLeft,
            allowSorting: false,
          ),
        if (_columnVisibility['issue_date'] == true)
          GenisletilebilirTabloKolon(
            label: tr('notes.table.issue_date'),
            width: colBranchCodeWidth,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['due_date'] == true)
          GenisletilebilirTabloKolon(
            label: tr('notes.table.due_date'),
            width: colBranchNameWidth,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        GenisletilebilirTabloKolon(
          label: tr('notes.table.actions'),
          width: colActionsWidth,
          alignment: Alignment.centerLeft,
        ),
      ],
      expandOnRowTap: false,
      isRowSelected: (senet, index) => _selectedRowId == senet.id,
      onRowTap: (senet) {
        setState(() => _selectedRowId = senet.id);
      },
      onClearSelection: _clearAllTableSelections,
      data: depolar,
      rowBuilder: (context, senet, index, isExpanded, toggleExpand) {
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
                  value: _selectedIds.contains(senet.id),
                  onChanged: (val) => _onSelectRow(val, senet.id),
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
                      text: senet.id.toString(),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HighlightText(
                      text: senet.senetNo,
                      query: _searchQuery,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    HighlightText(
                      text: () {
                        final String typeText = senet.tur == 'Alınan Senet'
                            ? '(${tr('notes.type.received_short')})'
                            : '(${tr('notes.type.given_short')})';
                        if (senet.tahsilat == 'Tahsil Edildi' ||
                            senet.tahsilat == 'Ödendi' ||
                            senet.tahsilat == 'Ciro Edildi' ||
                            senet.tahsilat == 'Karşılıksız') {
                          return '$typeText (${IslemCeviriYardimcisi.cevirDurum(senet.tahsilat)})';
                        }
                        return typeText;
                      }(),
                      query: _searchQuery,
                      style: TextStyle(
                        fontSize: 10,
                        color: senet.tahsilat == 'Karşılıksız'
                            ? Colors.orange.shade700
                            : (senet.tur == 'Alınan Senet'
                                  ? Colors.green.shade600
                                  : Colors.red.shade600),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            if (_columnVisibility['name'] == true)
              _buildCell(
                width: 200,
                flex: 30,
                child: HighlightText(
                  text: senet.cariAdi,
                  query: _searchQuery,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),
            if (_columnVisibility['amount'] == true)
              _buildCell(
                width: 150,
                alignment: Alignment.centerRight,
                child: HighlightText(
                  text: FormatYardimcisi.sayiFormatlaOndalikli(
                    senet.tutar,
                    binlik: _genelAyarlar.binlikAyiraci,
                    ondalik: _genelAyarlar.ondalikAyiraci,
                    decimalDigits: _genelAyarlar.fiyatOndalik,
                  ),
                  query: _searchQuery,
                  style: TextStyle(
                    color: senet.tutar >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_columnVisibility['currency'] == true)
              _buildCell(
                width: 100,
                flex: 20,
                child: HighlightText(
                  text: senet.paraBirimi,
                  query: _searchQuery,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),
            if (_columnVisibility['bank'] == true)
              _buildCell(
                width: 150,
                child: HighlightText(
                  text: senet.banka.isNotEmpty ? senet.banka : '-',
                  query: _searchQuery,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),
            if (_columnVisibility['issue_date'] == true)
              _buildCell(
                width: colBranchCodeWidth,
                child: HighlightText(
                  text: senet.duzenlenmeTarihi,
                  query: _searchQuery,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),
            if (_columnVisibility['due_date'] == true)
              _buildCell(
                width: colBranchNameWidth,
                child: HighlightText(
                  text: senet.kesideTarihi,
                  query: _searchQuery,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),
            // İşlemler
            _buildCell(width: colActionsWidth, child: _buildPopupMenu(senet)),
          ],
        );
      },
      detailBuilder: (context, senet) {
        return _buildDetailView(senet);
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

  Widget _buildDetailView(SenetModel senet) {
    final selectedIds = _selectedDetailIds[senet.id] ?? {};
    final visibleIds = _visibleTransactionIds[senet.id] ?? [];
    final allSelected =
        visibleIds.isNotEmpty && selectedIds.length == visibleIds.length;

    // Get first character for icon
    final firstChar = senet.cariAdi.isNotEmpty
        ? senet.cariAdi[0].toUpperCase()
        : 'S';

    // Calculate Alınan/Verilen totals from all notes (for demo, using current note)
    final double alinanToplam = senet.tur == 'Alınan Senet' ? senet.tutar : 0.0;
    final double verilenToplam = senet.tur == 'Verilen Senet'
        ? senet.tutar
        : 0.0;
    final double genelToplam = alinanToplam - verilenToplam;

    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. White Box: Header Info + Balance + Features
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
                // HEADER: Image + Info + Balance
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Senet Icon/Image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            text: senet.cariAdi,
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
                                  text: senet.senetNo,
                                  query: _searchQuery,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              HighlightText(
                                text: senet.paraBirimi,
                                query: _searchQuery,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          // Açıklama - Cari Hesap altına eklendi (border yok)
                          if (senet.aciklama.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.notes,
                                  size: 14,
                                  color: const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: HighlightText(
                                    text: senet.aciklama,
                                    query: _searchQuery,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Bakiye Table View
                    Container(
                      width: 250,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
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
                          // Alınan Senet Row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr('notes.received'), // Alınan Senet
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: HighlightText(
                                  text: FormatYardimcisi.sayiFormatlaOndalikli(
                                    alinanToplam,
                                    binlik: _genelAyarlar.binlikAyiraci,
                                    ondalik: _genelAyarlar.ondalikAyiraci,
                                    decimalDigits: _genelAyarlar.fiyatOndalik,
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
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 30,
                                child: HighlightText(
                                  text: senet.paraBirimi,
                                  query: _searchQuery,
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
                          // Verilen Senet Row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr('notes.given'), // Verilen Senet
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: HighlightText(
                                  text: FormatYardimcisi.sayiFormatlaOndalikli(
                                    verilenToplam,
                                    binlik: _genelAyarlar.binlikAyiraci,
                                    ondalik: _genelAyarlar.ondalikAyiraci,
                                    decimalDigits: _genelAyarlar.fiyatOndalik,
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
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 30,
                                child: HighlightText(
                                  text: senet.paraBirimi,
                                  query: _searchQuery,
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
                                child: HighlightText(
                                  text: FormatYardimcisi.sayiFormatlaOndalikli(
                                    genelToplam,
                                    binlik: _genelAyarlar.binlikAyiraci,
                                    ondalik: _genelAyarlar.ondalikAyiraci,
                                    decimalDigits: _genelAyarlar.fiyatOndalik,
                                  ),
                                  query: _searchQuery,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: genelToplam >= 0
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFC62828),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 30,
                                child: HighlightText(
                                  text: senet.paraBirimi,
                                  query: _searchQuery,
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
                  onChanged: (val) => _onSelectAllDetails(senet.id, val),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                tr('notes.detail.timeline'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Transactions Header Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 44), // Checkbox space (12 + 20 + 12)
                if (_columnVisibility['dt_transaction'] == true)
                  Expanded(
                    flex: 5, // Type column
                    child: _buildDetailHeader(tr('notes.detail.transaction')),
                  ),
                if (_columnVisibility['dt_date'] == true) ...[
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 7, // Date column
                    child: _buildDetailHeader(tr('notes.detail.date')),
                  ),
                ],
                if (_columnVisibility['dt_contact'] == true)
                  Expanded(
                    flex: 7, // Contact column
                    child: _buildDetailHeader(tr('notes.detail.contact')),
                  ),
                if (_columnVisibility['dt_amount'] == true) ...[
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 4, // Amount column (increased flex)
                    child: _buildDetailHeader(
                      tr('notes.detail.amount'),
                      alignRight: true,
                    ),
                  ),
                ],
                if (_columnVisibility['dt_description'] == true) ...[
                  const SizedBox(width: 48),
                  Expanded(
                    flex: 8, // Description column
                    child: _buildDetailHeader(tr('notes.detail.description')),
                  ),
                ],
                if (_columnVisibility['dt_user'] == true) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3, // User column
                    child: _buildDetailHeader(tr('notes.detail.user')),
                  ),
                ],
                const SizedBox(width: 24),
                const SizedBox(width: 120), // Actions space
              ],
            ),
          ),

          // Transactions List
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _detailFutures.putIfAbsent(
              senet.id,
              () => SenetlerVeritabaniServisi().senetIslemleriniGetir(
                senet.id,
                aramaTerimi: _searchQuery,
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
                  _visibleTransactionIds[senet.id] = transactions
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

                  final focusScope = TableDetailFocusScope.of(context);
                  final isFocused = focusScope?.focusedDetailIndex == index;
                  // Detay satırı seçili mi kontrol et (yeşil görünüm için)
                  final isDetailSelected =
                      _selectedDetailTransactionId == tx['id'] &&
                      _selectedDetailSenet?.id == senet.id;

                  return Column(
                    children: [
                      _buildDetailRowCells(
                        isFocused: isFocused || isDetailSelected,
                        senet: senet,
                        tx: tx,
                        id: tx['id'],
                        isSelected: val,
                        onChanged: (val) =>
                            _onSelectDetailRow(senet.id, tx['id'], val),
                        onTap: () {
                          focusScope?.setFocusedDetailIndex?.call(index);
                          // Seçili detay transaction bilgisini kaydet
                          // ve ana satır seçimini temizle (F2 için)
                          setState(() {
                            _selectedDetailTransactionId = tx['id'] as int?;
                            _selectedDetailSenet = senet;
                            _selectedRowId = null;
                          });
                        },
                        transactionType: tx['type']?.toString() ?? '',
                        tahsilat: senet.tahsilat,

                        cariKod: senet.cariKod,
                        cariAdi: tx['source_dest']?.toString() ?? senet.cariAdi,
                        duzTarih: () {
                          final date = tx['date'];
                          final createdAt = tx['created_at'];
                          DateTime? dt;
                          if (date is DateTime) {
                            dt = date;
                          } else if (date is String) {
                            dt = DateTime.tryParse(date);
                          }

                          if (dt != null) {
                            if (dt.hour == 0 &&
                                dt.minute == 0 &&
                                dt.second == 0 &&
                                createdAt != null) {
                              DateTime? cdt;
                              if (createdAt is DateTime) {
                                cdt = createdAt;
                              } else {
                                cdt = DateTime.tryParse(createdAt.toString());
                              }
                              if (cdt != null) {
                                dt = DateTime(
                                  dt.year,
                                  dt.month,
                                  dt.day,
                                  cdt.hour,
                                  cdt.minute,
                                  cdt.second,
                                );
                              }
                            }
                            return DateFormat('dd.MM.yyyy HH:mm').format(dt);
                          }
                          return date?.toString() ?? '-';
                        }(),
                        kesTarih: '',
                        amount:
                            double.tryParse(tx['amount']?.toString() ?? '') ??
                            0.0,
                        currency: senet.paraBirimi,
                        description: tx['description']?.toString() ?? '',
                        user: (tx['user_name']?.toString() ?? '').isEmpty
                            ? 'Sistem'
                            : tx['user_name'].toString(),
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
  }

  Widget _buildDetailRowCells({
    required SenetModel senet,
    required Map<String, dynamic> tx,
    required int id,
    required bool isSelected,
    required ValueChanged<bool?> onChanged,
    required String transactionType,
    required String tahsilat,
    required String cariKod,
    required String cariAdi,
    required String duzTarih,
    required String kesTarih,
    required double amount,
    required String currency,
    required String description,
    required String user,
    required VoidCallback onTap,
    required bool isFocused,
  }) {
    // Determine if incoming based on transaction type and label
    final String typeLower = transactionType.toLowerCase();
    final String descLower = description.toLowerCase();

    final bool isIncoming =
        typeLower.contains('giriş') ||
        typeLower.contains('alinan') ||
        typeLower.contains('alınan') ||
        typeLower.contains('tahsil') ||
        descLower.contains('girdi') ||
        descLower.contains('alındı') ||
        descLower.contains('tahsil');

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
        return MouseRegion(cursor: SystemMouseCursors.click, hitTestBehavior: HitTestBehavior.deferToChild, child: GestureDetector(
          onTap: onTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
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
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Row(
                children: [
                  // Checkbox - NOT focusable via keyboard
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ), // 12+20+12 = 44px
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
                  if (_columnVisibility['dt_transaction'] == true)
                    Expanded(
                      flex: 5,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: IslemTuruRenkleri.arkaplanRengiGetir(
                                transactionType,
                                isIncoming,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              isIncoming
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: IslemTuruRenkleri.ikonRengiGetir(
                                transactionType,
                                isIncoming,
                              ),
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: HighlightText(
                              text: () {
                                String label = IslemCeviriYardimcisi.cevir(
                                  IslemTuruRenkleri.getProfessionalLabel(
                                    transactionType,
                                    context: 'promissory_note',
                                  ),
                                );
                                final String lowerType = transactionType
                                    .toLowerCase();
                                if ((lowerType.contains('alındı') ||
                                        lowerType.contains('verildi') ||
                                        lowerType.contains('alinan') ||
                                        lowerType.contains('verilen')) &&
                                    tahsilat.isNotEmpty &&
                                    tahsilat != 'Portföyde' &&
                                    tahsilat != 'Ödeme' &&
                                    tahsilat != 'Tahsil') {
                                  return '$label (${IslemCeviriYardimcisi.cevirDurum(tahsilat)})';
                                }
                                return label;
                              }(),
                              query: _searchQuery,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: IslemTuruRenkleri.metinRengiGetir(
                                  transactionType,
                                  isIncoming,
                                ),
                              ),
                              maxLines: null,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_columnVisibility['dt_date'] == true) ...[
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 7,
                      child: HighlightText(
                        text: duzTarih,
                        query: _searchQuery,
                        maxLines: null,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],

                  if (_columnVisibility['dt_contact'] == true)
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (cariAdi.isNotEmpty)
                            HighlightText(
                              text: cariAdi,
                              query: _searchQuery,
                              maxLines: null,
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          if (cariAdi.isNotEmpty || cariKod.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
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
                                    child: Text(
                                      tr('purchase.complete.location.customer'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (cariKod.isNotEmpty)
                                    const SizedBox(width: 6),
                                  if (cariKod.isNotEmpty)
                                    HighlightText(
                                      text: cariKod,
                                      query: _searchQuery,
                                      maxLines: null,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          if (cariAdi.isEmpty && cariKod.isEmpty)
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

                  if (_columnVisibility['dt_amount'] == true) ...[
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 4,
                      child: HighlightText(
                        text:
                            '${FormatYardimcisi.sayiFormatlaOndalikli(amount, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} $currency',
                        query: _searchQuery,
                        textAlign: TextAlign.right,
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
                    const SizedBox(width: 48),
                    Expanded(
                      flex: 8,
                      child: HighlightText(
                        text: description.isNotEmpty ? description : '-',
                        query: _searchQuery,
                        maxLines: null,
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
                    Expanded(
                      flex: 3,
                      child: HighlightText(
                        text: user,
                        query: _searchQuery,
                        maxLines: null,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  // Action Menu
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 120,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildTransactionPopupMenu(tx, senet),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
      },
    );
  }

  Widget _buildTransactionPopupMenu(Map<String, dynamic> tx, SenetModel senet) {
    final int id = tx['id'];
    final String type = (tx['type'] ?? '').toString().toLowerCase();
    final String desc = (tx['description'] ?? '').toString().toLowerCase();

    final bool isEditable =
        type.contains('tahsil') ||
        type.contains('ödeme') ||
        type.contains('odeme') ||
        type.contains('ciro') ||
        type.contains('giriş') ||
        type.contains('giris') ||
        type.contains('çıkış') ||
        type.contains('cikis') ||
        type.contains('karşılıksız') ||
        type.contains('karsiliksiz') ||
        type.contains('öden') ||
        type.contains('oden') ||
        desc.contains('tahsil') ||
        desc.contains('ödeme') ||
        desc.contains('odeme') ||
        desc.contains('öden') ||
        desc.contains('oden') ||
        desc.contains('ciro');

    if (!isEditable) {
      return const SizedBox();
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
            _handleDetailEdit(tx, senet);
          } else if (value == 'delete') {
            _handleDetailDelete(senet.id, id);
          }
        },
      ),
    );
  }

  Future<void> _handleDetailEdit(
    Map<String, dynamic> tx,
    SenetModel senet,
  ) async {
    // Veritabanından gelen kolon isimleri 'type' ve 'description'dır.
    final String type = (tx['type'] ?? '').toString().toLowerCase();
    final String desc = (tx['description'] ?? '').toString().toLowerCase();

    debugPrint('Editing Note Transaction - Type: $type, Desc: $desc');

    bool? result;

    if (type.contains('tahsil') ||
        type.contains('ödeme') ||
        type.contains('odeme') ||
        type.contains('giriş') ||
        type.contains('giris') ||
        (type.contains('çıkış') && senet.tur == 'Verilen Senet') ||
        (type.contains('cikis') && senet.tur == 'Verilen Senet') ||
        desc.contains('tahsil') ||
        desc.contains('ödeme') ||
        desc.contains('odeme')) {
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              SenetTahsilSayfasi(senet: senet, transaction: tx),
        ),
      );
    } else if (type.contains('ciro') ||
        (type.contains('çıkış') && senet.tur == 'Alınan Senet') ||
        (type.contains('cikis') && senet.tur == 'Alınan Senet') ||
        desc.contains('ciro')) {
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SenetCiroSayfasi(senet: senet, transaction: tx),
        ),
      );
    } else {
      MesajYardimcisi.bilgiGoster(
        context,
        tr(
          'notes.messages.transaction_not_editable',
        ).replaceAll('{type}', tx['type']?.toString() ?? ''),
      );
    }

    if (result == true) {
      SayfaSenkronizasyonServisi().veriDegisti('cari');
      SayfaSenkronizasyonServisi().veriDegisti('kasalar');
      SayfaSenkronizasyonServisi().veriDegisti('bankalar');
      SayfaSenkronizasyonServisi().veriDegisti('krediKartlari');
      _detailFutures.remove(senet.id);
      await _fetchSenetler();
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

  Widget _buildPopupMenu(SenetModel depo) {
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
            value: 'collect',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 12),
                Text(
                  tr(
                    depo.tur == 'Verilen Senet'
                        ? 'notes.actions.make_payment'
                        : 'notes.actions.collect',
                  ),
                  style: TextStyle(
                    color: Colors.green.shade600,
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
            value: 'endorse',
            enabled: depo.tur != 'Verilen Senet', // Disable for issued notes
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 20,
                  color: depo.tur != 'Verilen Senet'
                      ? Colors.blue.shade600
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 12),
                Text(
                  tr('notes.actions.endorse'),
                  style: TextStyle(
                    color: depo.tur != 'Verilen Senet'
                        ? Colors.blue.shade600
                        : Colors.grey.shade400,
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
          } else if (value == 'collect') {
            _showCollectDialog(depo);
          } else if (value == 'endorse') {
            _showEndorseDialog(depo);
          } else if (value == 'delete') {
            _deleteSenet(depo);
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
    if (_selectedTransactionType != null) count++;
    if (_selectedBank != null) count++;
    if (_selectedUser != null) count++;
    return count;
  }

  Widget _buildMobileTopActionRow() {
    final double width = MediaQuery.of(context).size.width;
    final String printTooltip =
        _selectedIds.isNotEmpty ||
            _selectedDetailIds.values.any((s) => s.isNotEmpty)
        ? tr('common.print_selected')
        : tr('common.print_list');

    final giveButton = _buildMobileActionButton(
      label: tr('notes.give'),
      icon: Icons.call_made_rounded,
      color: const Color(0xFFF39C12),
      textColor: Colors.white,
      borderColor: Colors.transparent,
      onTap: _showGiveNoteDialog,
      height: 40,
      iconSize: 16,
      fontSize: 12,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );

    final receiveButton = _buildMobileActionButton(
      label: tr('notes.receive'),
      icon: Icons.call_received_rounded,
      color: const Color(0xFFEA4335),
      textColor: Colors.white,
      borderColor: Colors.transparent,
      onTap: _showAddDialog,
      height: 40,
      iconSize: 16,
      fontSize: 12,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );

    final printButton = _buildMobileSquareActionButton(
      icon: Icons.print_outlined,
      onTap: _handlePrint,
      color: const Color(0xFFF8F9FA),
      iconColor: Colors.black87,
      borderColor: Colors.grey.shade300,
      tooltip: printTooltip,
      size: 40,
    );

    if (width < 430) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: giveButton),
              const SizedBox(width: 8),
              Expanded(child: receiveButton),
            ],
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: printButton),
        ],
      );
    }

    return Row(
      children: [
        printButton,
        const SizedBox(width: 8),
        Expanded(child: giveButton),
        const SizedBox(width: 8),
        Expanded(child: receiveButton),
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
              _buildBankFilter(width: double.infinity),
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
                Expanded(child: _buildBankFilter(width: double.infinity)),
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
                                          _fetchSenetler(showLoading: false);
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
                                        onTap: _deleteSelectedSenetler,
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

  Widget _buildMobileView(List<SenetModel> filteredCekler) {
    final int totalRecords = _totalRecords > 0
        ? _totalRecords
        : filteredCekler.length;
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
          _fetchSenetler(showLoading: false);
        }
      });
    }

    final int startRecordIndex = (effectivePage - 1) * safeRowsPerPage;
    final int endRecord = totalRecords == 0
        ? 0
        : (startRecordIndex + filteredCekler.length).clamp(0, totalRecords);
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
                    tr('notes.title'),
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
                itemCount: filteredCekler.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildDepoCard(filteredCekler[index]);
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
                              _fetchSenetler(showLoading: false);
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
                              _fetchSenetler(showLoading: false);
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

  Widget _buildDepoCard(SenetModel depo) {
    final isExpanded = _expandedMobileIds.contains(depo.id);

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
                      depo.cariAdi,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${depo.senetNo} • ${depo.aciklama}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      depo.banka,
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

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
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
    );
  }

  Widget _buildMobileDetails(SenetModel depo) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _detailFutures.putIfAbsent(
        depo.id,
        () => SenetlerVeritabaniServisi().senetIslemleriniGetir(
          depo.id,
          aramaTerimi: _searchQuery,
          baslangicTarihi: _startDate,
          bitisTarihi: _endDate,
          islemTuru: _selectedTransactionType,
        ),
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
            child: Text(
              '${tr('common.error')}: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final transactions = snapshot.data ?? [];
        if (transactions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              tr('common.no_data'),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('checks.detail.timeline'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            ...transactions.map((tx) {

              final transactionType = tx['type']?.toString() ?? '';
              final typeLower = transactionType.toLowerCase();
              final description = tx['description']?.toString() ?? '';
              final descLower = description.toLowerCase();

              final bool isIncoming =
                  typeLower.contains('giriş') ||
                  typeLower.contains('alinan') ||
                  typeLower.contains('alınan') ||
                  typeLower.contains('tahsil') ||
                  descLower.contains('girdi') ||
                  descLower.contains('alındı') ||
                  descLower.contains('tahsil');

              final dynamic rawAmount = tx['amount'];
              final String rawAmountText = rawAmount?.toString().trim() ?? '';
              final double amount = rawAmount is num
                  ? rawAmount.toDouble()
                  : (() {
                      if (rawAmountText.isEmpty) return 0.0;
                      final int lastDot = rawAmountText.lastIndexOf('.');
                      final int lastComma = rawAmountText.lastIndexOf(',');
                      if (lastDot != -1 && lastComma != -1) {
                        if (lastDot > lastComma) {
                          return double.tryParse(
                                rawAmountText.replaceAll(',', ''),
                              ) ??
                              0.0;
                        }
                        return double.tryParse(
                              rawAmountText
                                  .replaceAll('.', '')
                                  .replaceAll(',', '.'),
                            ) ??
                            0.0;
                      }
                      if (lastComma != -1) {
                        return double.tryParse(
                              rawAmountText
                                  .replaceAll('.', '')
                                  .replaceAll(',', '.'),
                            ) ??
                            0.0;
                      }
                      if (rawAmountText.indexOf('.') != lastDot &&
                          lastDot != -1) {
                        final int digitsAfterLastDot =
                            rawAmountText.length - lastDot - 1;
                        if (digitsAfterLastDot == 3) {
                          return double.tryParse(
                                rawAmountText.replaceAll('.', ''),
                              ) ??
                              0.0;
                        }
                      }
                      return double.tryParse(rawAmountText) ?? 0.0;
                    })();

              return _buildMobileTransactionRow(
                isIncoming: isIncoming,
                contact: tx['source_dest']?.toString() ?? '-',
                amount: amount,
                currency: depo.paraBirimi,
                date: tx['date']?.toString() ?? '',
                user: tx['user_name']?.toString() ?? '-',
                description: description,
                customTypeLabel: transactionType,
                tahsilat: depo.tahsilat,
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildMobileTransactionRow({
    required bool isIncoming,
    required String contact,
    required double amount,
    required String currency,
    required String date,
    required String user,
    required String description,
    String? customTypeLabel,
    String tahsilat = '',
  }) {
    final String trimmedDescription = description.trim();

    final String title = () {
      final String label = IslemCeviriYardimcisi.cevir(
        IslemTuruRenkleri.getProfessionalLabel(
          customTypeLabel,
          context: 'promissory_note',
        ),
      );
      final String lowerType = (customTypeLabel ?? '').toLowerCase();
      if ((lowerType.contains('alındı') ||
              lowerType.contains('verildi') ||
              lowerType.contains('alinan') ||
              lowerType.contains('verilen')) &&
          tahsilat.isNotEmpty &&
          tahsilat != 'Portföyde' &&
          tahsilat != 'Ödeme' &&
          tahsilat != 'Tahsil') {
        return '$label (${IslemCeviriYardimcisi.cevirDurum(tahsilat)})';
      }
      return label;
    }();

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
                    Icon(
                      Icons.contact_mail_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        contact,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.attach_money_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${FormatYardimcisi.sayiFormatlaOndalikli(amount, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} $currency',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
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
}

class _WarehouseFilterOverlay extends StatefulWidget {
  final SenetModel? selectedWarehouse;
  final ValueChanged<SenetModel?> onSelect;

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
  List<SenetModel> _depolar = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchSenetler();
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
      _fetchSenetler();
    });
  }

  Future<void> _fetchSenetler() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await SenetlerVeritabaniServisi().senetleriGetir(
        aramaKelimesi: _searchController.text,
        sayfaBasinaKayit: 100,
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
                    ..._depolar.map((depo) => _buildOption(depo, depo.cariAdi)),
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

  Widget _buildOption(SenetModel? value, String label) {
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
