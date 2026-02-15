import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'borc_alacak_dekontu_isle_sayfasi.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../bilesenler/genisletilebilir_tablo.dart';
import '../../bilesenler/onay_dialog.dart';
import '../../bilesenler/tarih_araligi_secici_dialog.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/ceviri/islem_ceviri_yardimcisi.dart';
import '../../yardimcilar/responsive_yardimcisi.dart';
import 'modeller/cari_hesap_model.dart';
import '../../bilesenler/highlight_text.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../ortak/genisletilebilir_print_preview_screen.dart';
import 'cari_hesap_ekle_sayfasi.dart';
import '../../yardimcilar/islem_turu_renkleri.dart';
import '../../bilesenler/tab_acici_scope.dart';
import '../../servisler/sayfa_senkronizasyon_servisi.dart';

class CariHesaplarSayfasi extends StatefulWidget {
  const CariHesaplarSayfasi({super.key});

  @override
  State<CariHesaplarSayfasi> createState() => _CariHesaplarSayfasiState();
}

class _CariHesaplarSayfasiState extends State<CariHesaplarSayfasi> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<CariHesapModel> _cachedCariHesaplar = [];
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  bool _isLoading = true;
  int _totalRecords = 0;
  final Set<int> _selectedIds = {};
  final Set<int> _expandedMobileIds = {};
  int? _selectedRowId;

  void _resetPagination() {
    _pageCursors.clear();
    _currentPage = 1;
    // [2026 PROFESYONEL FIX] Filtre/Arama kriteri değiştiğinde manuel kapatma hafızasını temizle
    _isManuallyClosedDuringFilter = false;
  }

  int _rowsPerPage = 25;
  int _currentPage = 1;
  final Map<int, int> _pageCursors = {};
  bool _isSelectAllActive = false;

  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  String? _selectedStatus;

  String? _selectedAccountType;
  String? _selectedTransactionType;
  String? _selectedUser;

  // ignore: unused_field
  bool _isStatusFilterExpanded = false;
  // ignore: unused_field
  bool _isAccountTypeFilterExpanded = false;
  // ignore: unused_field
  bool _isTransactionTypeFilterExpanded = false;
  // ignore: unused_field
  bool _isCityFilterExpanded = false;
  bool _isUserFilterExpanded = false;

  String? _selectedCity;

  Set<int> _autoExpandedIndices = {};
  int? _manualExpandedIndex;

  // ignore: unused_field
  final LayerLink _statusLayerLink = LayerLink();
  // ignore: unused_field
  final LayerLink _accountTypeLayerLink = LayerLink();
  // ignore: unused_field
  final LayerLink _transactionTypeLayerLink = LayerLink();
  // ignore: unused_field
  final LayerLink _cityLayerLink = LayerLink();
  final LayerLink _userLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  final Map<int, List<int>> _visibleTransactionIds = {};
  final Map<int, Set<int>> _selectedDetailIds = {};
  final int _refreshKey = 0;

  // Cache for detail futures to prevent reloading on selection changes
  final Map<int, Future<List<Map<String, dynamic>>>> _detailFutures = {};

  bool _keepDetailsOpen = false;

  int? _sortColumnIndex = 1;

  // Filtre Seçenekleri
  // ignore: unused_field
  List<String> _availableAccountTypes = ['Alıcı', 'Satıcı', 'Alıcı/Satıcı'];
  // ignore: unused_field
  List<String> _availableCities = [];
  Map<String, Map<String, int>> _filterStats = {};
  bool _sortAscending = false;
  String? _sortBy = 'id';
  Timer? _debounce;
  int _aktifSorguNo = 0;
  bool _isManuallyClosedDuringFilter = false;

  // Column Visibility State
  Map<String, bool> _columnVisibility = {};

  @override
  void initState() {
    super.initState();
    _columnVisibility = {
      // Main Table
      'order_no': true,
      'code': true,
      'name': true,
      'account_type': true,
      'balance_debit': true,
      'balance_credit': true,
      'status': true,
      // Detail Table
      'dt_transaction': true,
      'dt_date': true,
      'dt_party': true,
      'dt_amount': true,
      'dt_description': true,
      'dt_due_date': true,
      'dt_user': true,
    };
    _loadSettings();
    _loadAvailableFilters();
    // Arama çalışması için mevcut cari hesapların search_tags'ını güncelle
    // ve indeksleme tamamlandıktan sonra verileri getir
    _fetchCariHesaplar();

    // Global senkronizasyon dinleyicisi ekle
    SayfaSenkronizasyonServisi().addListener(_onGlobalSync);

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (_searchController.text != _searchQuery) {
          setState(() {
            _searchQuery = _searchController.text.toLowerCase();
            _resetPagination();
          });
          _fetchCariHesaplar();
        }
      });
    });
  }

  // Single View State
  int? _singleViewRowId;

  void _toggleSingleView(int rowId) {
    setState(() {
      if (_singleViewRowId == rowId) {
        _singleViewRowId = null;
      } else {
        _singleViewRowId = rowId;
        // Single view'e geçince o satırı seçili yapalım
        _selectedRowId = rowId;
      }
    });
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
    _debounce?.cancel();
    super.dispose();
  }

  void _onGlobalSync() {
    if (mounted) {
      // Arka planda verileri tazele
      _fetchCariHesaplar(showLoading: false);
    }
  }

  // NOT: Arama indekslemesi artık servis içinde arka planda yapılıyor.
  // Bu yüzden sayfa açılışında await etmek gerekmiyor.

  Future<void> _fetchCariHesaplar({bool showLoading = true}) async {
    // Clear detail cache when refreshing main list
    _detailFutures.clear();

    final int sorguNo = ++_aktifSorguNo;

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final bool? aktifMi = _selectedStatus == 'active'
          ? true
          : (_selectedStatus == 'passive' ? false : null);

      final cariHesaplar = await CariHesaplarVeritabaniServisi()
          .cariHesaplariGetir(
            sayfa: _currentPage,
            sayfaBasinaKayit: _rowsPerPage,
            aramaTerimi: _searchQuery,
            sortBy: _sortBy,
            sortAscending: _sortAscending,
            aktifMi: aktifMi,
            hesapTuru: _selectedAccountType,
            sehir: _selectedCity,
            islemTuru: _selectedTransactionType,
            kullanici: _selectedUser,
            baslangicTarihi: _startDate,
            bitisTarihi: _endDate,
            lastId: _currentPage > 1 ? _pageCursors[_currentPage - 1] : null,
          );

      if (!mounted || sorguNo != _aktifSorguNo) return;

      final totalFuture = CariHesaplarVeritabaniServisi().cariHesapSayisiGetir(
        aramaTerimi: _searchQuery,
        aktifMi: aktifMi,
        hesapTuru: _selectedAccountType,
        sehir: _selectedCity,
        islemTuru: _selectedTransactionType,
        kullanici: _selectedUser,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
      );

      final statsFuture = CariHesaplarVeritabaniServisi()
          .cariHesapFiltreIstatistikleriniGetir(
            aramaTerimi: _searchQuery,
            baslangicTarihi: _startDate,
            bitisTarihi: _endDate,
            aktifMi: aktifMi,
            hesapTuru: _selectedAccountType,
            islemTuru: _selectedTransactionType,
            kullanici: _selectedUser,
          );

      if (mounted) {
        final indices = <int>{};
        if (_selectedAccountType != null ||
            _selectedCity != null ||
            _startDate != null ||
            _endDate != null ||
            _selectedTransactionType != null ||
            _selectedUser != null) {
          indices.addAll(List.generate(cariHesaplar.length, (i) => i));
        } else if (_searchQuery.isNotEmpty) {
          for (int i = 0; i < cariHesaplar.length; i++) {
            if (cariHesaplar[i].matchedInHidden) {
              indices.add(i);
              _expandedMobileIds.add(cariHesaplar[i].id);
            }
          }
        }

        setState(() {
          _isLoading = false;
          _cachedCariHesaplar = cariHesaplar;
          _autoExpandedIndices = indices;

          final bool hasFilter =
              _searchQuery.isNotEmpty ||
              _selectedStatus != null ||
              _selectedAccountType != null ||
              _selectedCity != null ||
              _selectedTransactionType != null ||
              _selectedUser != null ||
              _startDate != null ||
              _endDate != null;

          // [2026 PROFESYONEL SYNC] Filtre açıkken ve sonuç varsa butonu oto-aktif et
          if (hasFilter) {
            if (indices.isNotEmpty && !_isManuallyClosedDuringFilter) {
              _keepDetailsOpen = true;
            }
          } else {
            // Filtre yoksa manuel kapanma bayrağını sıfırla
            _isManuallyClosedDuringFilter = false;
            // SharedPreferences tercihlerine geri dön (Eğer filtre sırasında değiştiyse)
            _loadSettings();
          }

          // [2025 FIX] Keyset Pagination için cursor'u kaydet
          if (cariHesaplar.isNotEmpty) {
            _pageCursors[_currentPage] = cariHesaplar.last.id;
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
              debugPrint('Cari hesap toplam sayısı güncellenemedi: $e');
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
              debugPrint('Cari hesap filtre istatistikleri güncellenemedi: $e');
            }),
      );
    } catch (e) {
      if (mounted && sorguNo == _aktifSorguNo) {
        setState(() => _isLoading = false);
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    }
  }

  void _showColumnVisibilityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Map<String, bool> localVisibility = Map.from(_columnVisibility);

        // Helper helpers
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
                          color: const Color(0xFFF5F7FA), // Soft background
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
                            tr('accounts.table.code'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'name',
                            tr('accounts.table.name'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'account_type',
                            tr('accounts.table.account_type'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'balance_debit',
                            tr('accounts.table.balance_debit'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'balance_credit',
                            tr('accounts.table.balance_credit'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'status',
                            tr('accounts.table.status'),
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
                            tr('cashregisters.detail.transaction'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_date',
                            tr('cashregisters.detail.date'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_party',
                            tr('cashregisters.detail.party'),
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
                            tr('cashregisters.detail.description'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_due_date',
                            'Vad. Tarihi',
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_user',
                            tr('cashregisters.detail.user'),
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
      width: 170, // Consistent width for grid alignment
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

        // Tarih formatlama (Controller'ları güncelle)
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
      _fetchCariHesaplar();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
    if (mounted) {
      setState(() {
        _keepDetailsOpen =
            prefs.getBool('cari_hesaplar_keep_details_open') ?? false;
        _genelAyarlar = settings;
      });
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
          _selectedAccountType != null ||
          _selectedCity != null ||
          _selectedTransactionType != null ||
          _selectedUser != null ||
          _startDate != null ||
          _endDate != null;

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
    await prefs.setBool('cari_hesaplar_keep_details_open', _keepDetailsOpen);
  }

  Future<void> _loadAvailableFilters() async {
    try {
      final accountTypes = await CariHesaplarVeritabaniServisi()
          .hesapTurleriniGetir();
      final cities = await CariHesaplarVeritabaniServisi().sehirleriGetir();
      if (mounted) {
        setState(() {
          _availableAccountTypes = accountTypes;
          _availableCities = cities;
        });
      }
    } catch (e) {
      debugPrint('Filtre yükleme hatası: $e');
    }
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _isStatusFilterExpanded = false;
        _isAccountTypeFilterExpanded = false;
        _isTransactionTypeFilterExpanded = false;
        _isCityFilterExpanded = false;
        _isUserFilterExpanded = false;
      });
    }
  }

  String _formatDate(dynamic value, {bool includeTime = true}) {
    if (value == null || value.toString().isEmpty) return '-';
    try {
      final dt = value is DateTime ? value : DateTime.parse(value.toString());
      final format = includeTime ? 'dd.MM.yyyy HH:mm' : 'dd.MM.yyyy';
      return DateFormat(format).format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  Future<void> _handlePrint() async {
    setState(() => _isLoading = true);
    try {
      List<ExpandableRowData> rows = [];

      // Filter data based on selection
      final dataToProcess = _selectedIds.isNotEmpty
          ? _cachedCariHesaplar
                .where((c) => _selectedIds.contains(c.id))
                .toList()
          : _cachedCariHesaplar;

      for (var i = 0; i < dataToProcess.length; i++) {
        final cari = dataToProcess[i];

        final isExpanded =
            _keepDetailsOpen ||
            _autoExpandedIndices.contains(i) ||
            (_expandedMobileIds.contains(cari.id)) ||
            _manualExpandedIndex == i;

        final mainRow = [
          cari.kodNo,
          cari.adi,
          IslemCeviriYardimcisi.cevir(cari.hesapTuru),
          FormatYardimcisi.sayiFormatlaOndalikli(
            cari.bakiyeBorc,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: _genelAyarlar.fiyatOndalik,
          ),
          FormatYardimcisi.sayiFormatlaOndalikli(
            cari.bakiyeAlacak,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: _genelAyarlar.fiyatOndalik,
          ),
          // Bakiye (Net) eklenebilir ama şu anki yapı korunmalı
          cari.fatSehir.isNotEmpty ? cari.fatSehir : '-',
          cari.aktifMi ? tr('common.active') : tr('common.passive'),
        ];

        Map<String, String> details = {};
        List<Map<String, dynamic>> transactions = [];

        // Genişletilmiş ise detayları doldur
        if (isExpanded) {
          // Details cleared as per user request for professional print output
          details = {};
          // details.removeWhere((key, value) => value.isEmpty || value == '-');

          // Transactions
          transactions = await CariHesaplarVeritabaniServisi()
              .cariIslemleriniGetir(
                cari.id,
                aramaTerimi: _searchController.text,
                baslangicTarihi: _startDate,
                bitisTarihi: _endDate,
                islemTuru: _selectedTransactionType,
              );
        }

        DetailTable? txTable;
        if (transactions.isNotEmpty) {
          // [2026 FIX] Ekran ile birebir aynı sütun yapısı:
          // İşlem | Tarih | İlgili Hesap | Tutar | Vad. Tarihi | Açıklama | Kullanıcı
          txTable = DetailTable(
            title: tr('common.last_movements'),
            headers: [
              'İşlem',
              tr('common.date'),
              'İlgili Hesap',
              tr('common.amount'),
              'Vad. Tarihi',
              tr('common.description'),
              tr('common.user'),
            ],
            data: transactions.map((t) {
              // 1. Temel Veriler
              final rawIslemTuru =
                  t['source_type']?.toString() ??
                  t['islem_turu']?.toString() ??
                  '';
              final String aciklamaRaw = rawIslemTuru.contains('Açılış')
                  ? ''
                  : (t['aciklama']?.toString() ?? '');

              final double tutar =
                  double.tryParse(t['tutar']?.toString() ?? '') ?? 0.0;
              final String yon = t['yon']?.toString().toLowerCase() ?? '';
              final bool isBorc =
                  yon.contains('borç') || yon.contains('borc') || yon == 'borc';

              // 2. İşlem Türü Label & Suffix
              final String islemLabel = IslemCeviriYardimcisi.cevir(
                IslemTuruRenkleri.getProfessionalLabel(
                  rawIslemTuru,
                  context: 'cari',
                  yon: t['yon']?.toString(),
                ),
              );

              // Kaynak bilgilerini hazırla
              String locationName = t['kaynak_adi']?.toString() ?? '';
              String locationCode = t['kaynak_kodu']?.toString() ?? '';
              final sourceId = t['source_id'] is int
                  ? t['source_id'] as int
                  : int.tryParse(t['source_id']?.toString() ?? '');

              if (locationName.isEmpty && aciklamaRaw.isNotEmpty) {
                if (aciklamaRaw.contains(' - ')) {
                  final parts = aciklamaRaw.split(' - ');
                  if (parts.length >= 2) {
                    locationName = parts.sublist(1).join(' - ').trim();
                  }
                }
              }
              if (locationCode.isEmpty && sourceId != null && sourceId > 0) {
                locationCode = '#$sourceId';
              }

              String suffixLabel = '';
              final sourceSuffix = _getSourceSuffix(
                rawIslemTuru,
                t['integration_ref']?.toString(),
                locationName,
              );
              if (sourceSuffix.isNotEmpty) {
                suffixLabel =
                    ' ${IslemCeviriYardimcisi.parantezliKaynakKisaltma(sourceSuffix)}';
              }

              // 3. İlgili Hesap İnşası (Screen: 2 satır - Ana isim + Alt detay)
              String ilgiliHesapGosterim = '';
              String ilgiliHesapAltDetay = '';

              if (rawIslemTuru.contains('Çek') ||
                  rawIslemTuru.contains('Senet')) {
                final parts = locationName.split('\n');
                ilgiliHesapGosterim = parts.isNotEmpty
                    ? parts.first
                    : locationName;
                if (parts.length > 1) {
                  ilgiliHesapAltDetay = parts.sublist(1).join(' ');
                }
              } else if (locationName.isNotEmpty) {
                ilgiliHesapGosterim = locationName;
                // Alt detay: İşlem türü + kod
                if (locationCode.isNotEmpty) {
                  ilgiliHesapAltDetay = '$rawIslemTuru $locationCode';
                }
              } else if (rawIslemTuru == 'Kasa' ||
                  rawIslemTuru == 'Banka' ||
                  rawIslemTuru == 'Kredi Kartı') {
                ilgiliHesapGosterim = IslemCeviriYardimcisi.cevir(rawIslemTuru);
                final typeLabel = IslemCeviriYardimcisi.cevir(
                  isBorc ? 'Para Verildi' : 'Para Alındı',
                );
                ilgiliHesapAltDetay = typeLabel;
              } else {
                ilgiliHesapGosterim = '-';
              }

              // Birleşik format: "Ana İsim\nAlt Detay" (Ekran ile aynı şekilde)
              final String ilgiliHesapFinal = ilgiliHesapAltDetay.isNotEmpty
                  ? '$ilgiliHesapGosterim\n$ilgiliHesapAltDetay'
                  : ilgiliHesapGosterim;

              // 4. Vade Tarihi
              final vt =
                  rawIslemTuru.contains('Çek') || rawIslemTuru.contains('Senet')
                  ? t['tarih']
                  : t['vade_tarihi'];
              String vtStr = '-';
              if (vt != null && vt.toString().isNotEmpty) {
                vtStr = _formatDate(vt, includeTime: false);
              }

              // 5. Kullanıcı
              final String kullanici = t['kullanici']?.toString() ?? '-';

              // Ekran sırası: İşlem | Tarih | İlgili Hesap | Tutar | Vad. Tarihi | Açıklama | Kullanıcı
              return <String>[
                '$islemLabel$suffixLabel', // İşlem
                _formatDate(t['tarih']), // Tarih
                ilgiliHesapFinal, // İlgili Hesap
                '${FormatYardimcisi.sayiFormatlaOndalikli(tutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${t['para_birimi']?.toString() ?? cari.paraBirimi}', // Tutar + Para Birimi
                vtStr, // Vad. Tarihi
                aciklamaRaw, // Açıklama
                kullanici, // Kullanıcı
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
            title: tr('accounts.title'),
            headers: [
              tr('accounts.table.code'),
              tr('accounts.table.name'),
              tr('accounts.table.account_type'),
              tr('accounts.table.balance_debit'),
              tr('accounts.table.balance_credit'),
              tr('accounts.table.invoice_city'),
              tr('accounts.table.status'),
            ],
            data: rows,
            dateInterval: dateInfo,
            initialShowDetails:
                _keepDetailsOpen ||
                _autoExpandedIndices.isNotEmpty ||
                _manualExpandedIndex != null ||
                _expandedMobileIds.isNotEmpty,
            mainTableLabel: tr('common.main_table'),
            detailTableLabel: tr('common.last_movements'),
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  Future<void> _deleteSelectedCariHesaplar() async {
    if (_selectedIds.isEmpty && !_isSelectAllActive) return;

    final count = _isSelectAllActive ? _totalRecords : _selectedIds.length;

    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr(
          'common.confirm_delete_named',
        ).replaceAll('{name}', '$count kayıt'),
        onOnay: () {},
        isDestructive: true,
        onayButonMetni: tr('common.delete'),
      ),
    );

    if (onay == true) {
      if (_isSelectAllActive) {
        await CariHesaplarVeritabaniServisi().topluCariHesapSilByFilter(
          aramaTerimi: _searchQuery,
          aktifMi: _selectedStatus == 'active'
              ? true
              : (_selectedStatus == 'passive' ? false : null),
          hesapTuru: _selectedAccountType,
          sehir: _selectedCity,
          baslangicTarihi: _startDate,
          bitisTarihi: _endDate,
        );
      } else {
        await CariHesaplarVeritabaniServisi().topluCariHesapSil(
          _selectedIds.toList(),
        );
      }

      setState(() {
        _selectedIds.clear();
        _isSelectAllActive = false;
      });
      if (!mounted) return;
      MesajYardimcisi.basariGoster(context, tr('common.deleted_successfully'));
      _fetchCariHesaplar();
    }
  }

  void _deleteCariHesap(CariHesapModel cari) async {
    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr('common.confirm_delete_named').replaceAll('{name}', cari.adi),
        onOnay: () {},
        isDestructive: true,
        onayButonMetni: tr('common.delete'),
      ),
    );

    if (onay == true) {
      await CariHesaplarVeritabaniServisi().cariHesapSil(cari.id);
      if (!mounted) return;
      MesajYardimcisi.basariGoster(context, tr('common.deleted_successfully'));
      _fetchCariHesaplar();
    }
  }

  /// Clear all selections when tapping outside the table
  void _clearAllTableSelections() {
    setState(() {
      _selectedIds.clear();
      _selectedDetailIds.clear();
      _isSelectAllActive = false;
      _selectedRowId = null;
    });
  }

  Future<void> _cariDurumDegistir(CariHesapModel cari, bool aktifMi) async {
    try {
      final yeniCari = cari.copyWith(aktifMi: aktifMi);
      await CariHesaplarVeritabaniServisi().cariHesapGuncelle(yeniCari);
      await _fetchCariHesaplar(showLoading: false);

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
    List<CariHesapModel> filteredCariHesaplar = _cachedCariHesaplar;

    if (_singleViewRowId != null) {
      filteredCariHesaplar = filteredCariHesaplar
          .where((c) => c.id == _singleViewRowId)
          .toList();
    }

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
                  _selectedAccountType != null ||
                  _selectedTransactionType != null || // [2026 FIX] Eksik filtre
                  _selectedUser != null ||
                  _selectedCity != null) {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _startDateController.clear();
                  _endDateController.clear();
                  _selectedStatus = null;
                  _selectedAccountType = null;
                  _selectedTransactionType = null;
                  _selectedUser = null;
                  _selectedCity = null;
                  _resetPagination();
                });
                _fetchCariHesaplar();
                return;
              }
            },
            // F1: Yeni Ekle
            const SingleActivator(LogicalKeyboardKey.f1): () async {
              final result = await Navigator.push<bool>(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const CariHesapEkleSayfasi(),
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
              if (result == true) {
                _fetchCariHesaplar();
              }
            },
            // F2: Seçili Düzenle
            const SingleActivator(LogicalKeyboardKey.f2): () async {
              if (_selectedRowId == null) return;
              final selectedId = _selectedRowId!;
              final cari = _cachedCariHesaplar.firstWhere(
                (c) => c.id == selectedId,
              );
              final result = await Navigator.push<bool>(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      CariHesapEkleSayfasi(cariHesap: cari),
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
              if (result == true) {
                _fetchCariHesaplar();
              }
            },
            // F3: Ara (Arama kutusuna odaklan)
            const SingleActivator(LogicalKeyboardKey.f3): () {
              _searchFocusNode.requestFocus();
            },
            // F5: Yenile
            const SingleActivator(LogicalKeyboardKey.f5): () {
              if (_singleViewRowId != null) {
                _toggleSingleView(_singleViewRowId!);
                return;
              }
              _fetchCariHesaplar();
            },
            // F6: Aktif/Pasif Toggle
            const SingleActivator(LogicalKeyboardKey.f6): () async {
              if (_selectedRowId == null) return;
              final selectedId = _selectedRowId!;
              final cari = _cachedCariHesaplar.firstWhere(
                (c) => c.id == selectedId,
              );
              await _cariDurumDegistir(cari, !cari.aktifMi);
            },
            // F7: Yazdır
            const SingleActivator(LogicalKeyboardKey.f7): _handlePrint,
            // F8: Seçilileri Toplu Sil
            const SingleActivator(LogicalKeyboardKey.f8): () {
              if (_selectedIds.isEmpty && !_isSelectAllActive) return;
              _deleteSelectedCariHesaplar();
            },
            // F9: Cari Kartı Aç (Tab olarak)
            const SingleActivator(LogicalKeyboardKey.f9): () {
              if (_selectedRowId == null) return;
              final selectedId = _selectedRowId!;
              final cari = _cachedCariHesaplar.firstWhere(
                (c) => c.id == selectedId,
              );
              TabAciciScope.of(context)?.tabAc(
                menuIndex: TabAciciScope.cariKartiIndex,
                initialCari: cari,
              );
            },
            // F10: Borç/Alacak Dekontu
            const SingleActivator(LogicalKeyboardKey.f10): () {
              if (_selectedRowId == null) return;
              final selectedId = _selectedRowId!;
              final cari = _cachedCariHesaplar.firstWhere(
                (c) => c.id == selectedId,
              );
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      BorcAlacakDekontuIsleSayfasi(cari: cari),
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
              ).then((result) {
                if (result == true) {
                  _fetchCariHesaplar();
                }
              });
            },
            // F11: Alış Yap
            const SingleActivator(LogicalKeyboardKey.f11): () {
              if (_selectedRowId == null) return;
              final selectedId = _selectedRowId!;
              final cari = _cachedCariHesaplar.firstWhere(
                (c) => c.id == selectedId,
              );
              TabAciciScope.of(
                context,
              )?.tabAc(menuIndex: 10, initialCari: cari);
            },
            // F12: Satış Yap
            const SingleActivator(LogicalKeyboardKey.f12): () {
              if (_selectedRowId == null) return;
              final selectedId = _selectedRowId!;
              final cari = _cachedCariHesaplar.firstWhere(
                (c) => c.id == selectedId,
              );
              TabAciciScope.of(
                context,
              )?.tabAc(menuIndex: 11, initialCari: cari);
            },
            // Delete: Seçili Satırı Sil
            const SingleActivator(LogicalKeyboardKey.delete): () {
              if (_selectedRowId == null) return;
              final selectedId = _selectedRowId!;
              final cari = _cachedCariHesaplar.firstWhere(
                (c) => c.id == selectedId,
              );
              _deleteCariHesap(cari);
            },
            // Numpad Delete: Seçili Satırı Sil
            const SingleActivator(LogicalKeyboardKey.numpadDecimal): () {
              if (_selectedRowId == null) return;
              final selectedId = _selectedRowId!;
              final cari = _cachedCariHesaplar.firstWhere(
                (c) => c.id == selectedId,
              );
              _deleteCariHesap(cari);
            },
          },
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool forceMobile =
                      ResponsiveYardimcisi.tabletMi(context);
                  if (forceMobile || constraints.maxWidth < 800) {
                    return _buildMobileView(filteredCariHesaplar);
                  } else {
                    return _buildDesktopView(filteredCariHesaplar, constraints);
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

  // Devamı ayrı dosyada - part directive ile birleştirilebilir
  // Şimdilik basitleştirilmiş placeholder metodlar

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

  Widget _buildMobileView(List<CariHesapModel> cariHesaplar) {
    return Column(
      children: [
        // Header & Filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    tr('accounts.title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_totalRecords',
                      style: const TextStyle(
                        color: Color(0xFF2C3E50),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle,
                      color: Color(0xFF2C3E50),
                    ),
                    onPressed: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const CariHesapEkleSayfasi(),
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
                      if (result == true) {
                        _fetchCariHesaplar();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: tr('common.search_placeholder'),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    if (_searchController.text != _searchQuery) {
                      setState(() {
                        _searchQuery = _searchController.text.toLowerCase();
                        _resetPagination();
                      });
                      _fetchCariHesaplar();
                    }
                  });
                },
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : cariHesaplar.isEmpty
              ? Center(
                  child: Text(
                    tr('common.no_records_found'),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cariHesaplar.length,
                  itemBuilder: (context, index) {
                    return _buildMobileCard(cariHesaplar[index]);
                  },
                ),
        ),

        // Pagination
        if (_totalRecords > 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${((_currentPage - 1) * _rowsPerPage) + 1} - ${(_currentPage * _rowsPerPage).clamp(0, _totalRecords)} / $_totalRecords',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage > 1
                          ? () {
                              setState(() => _currentPage--);
                              _fetchCariHesaplar();
                            }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: (_currentPage * _rowsPerPage) < _totalRecords
                          ? () {
                              setState(() => _currentPage++);
                              _fetchCariHesaplar();
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMobileCard(CariHesapModel cari) {
    final isExpanded = _expandedMobileIds.contains(cari.id);
    final hasImages = cari.resimler.isNotEmpty;

    ImageProvider? imageProvider;
    if (hasImages) {
      try {
        String base64String = cari.resimler.first;
        if (base64String.contains(',')) {
          base64String = base64String.split(',').last;
        }
        imageProvider = MemoryImage(base64Decode(base64String));
      } catch (e) {
        debugPrint('Image decode error: $e');
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF2C3E50,
            ).withValues(alpha: isExpanded ? 0.08 : 0.04),
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: isExpanded
              ? const Color(0xFF4DB6AC).withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header Section
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedMobileIds.remove(cari.id);
                } else {
                  _expandedMobileIds.add(cari.id);
                }
              });
            },
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: isExpanded ? Radius.zero : const Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  // Avatar / Image
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      image: imageProvider != null
                          ? DecorationImage(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: imageProvider == null
                        ? Center(
                            child: Text(
                              cari.adi.isNotEmpty
                                  ? cari.adi[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),

                  // Main Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HighlightText(
                          text: cari.adi,
                          query: _searchQuery,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
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
                              ),
                              child: Text(
                                cari.kodNo,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              IslemCeviriYardimcisi.cevir(cari.hesapTuru),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Balance & Status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${FormatYardimcisi.sayiFormatlaOndalikli(cari.bakiyeDurumu == 'Borç' ? cari.bakiyeBorc : cari.bakiyeAlacak, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${cari.paraBirimi}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: cari.bakiyeDurumu == 'Borç'
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981), // Emerald Green
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: cari.aktifMi
                              ? const Color(0xFFDCFCE7) // Soft Green
                              : const Color(0xFFFFF7ED), // Soft Orange
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: cari.aktifMi
                                ? const Color(0xFF86EFAC).withValues(alpha: 0.5)
                                : const Color(
                                    0xFFFDBA74,
                                  ).withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          cari.aktifMi
                              ? tr('common.active')
                              : tr('common.passive'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: cari.aktifMi
                                ? const Color(0xFF15803D)
                                : const Color(0xFFC2410C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (isExpanded)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC), // Ultra soft blue-grey
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Quick Note & Gallery Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Note Field
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            initialValue: cari.bilgi1, // Using bilgi1 as note
                            decoration: InputDecoration(
                              hintText: tr('accounts.detail.note_hint'),
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.edit_note_rounded,
                                color: Color(0xFF64748B),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              suffixIcon: const Icon(
                                Icons.keyboard_return_rounded,
                                size: 20,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF334155),
                            ),
                            textInputAction: TextInputAction.send,
                            onFieldSubmitted: (value) =>
                                _updateAccountNote(cari, value),
                          ),
                        ),

                        // Image Gallery (Restored & Improved)
                        if (cari.resimler.length > 1) ...[
                          SizedBox(
                            height: 70,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: cari.resimler.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                ImageProvider? itemImage;
                                try {
                                  String b64 = cari.resimler[index];
                                  if (b64.contains(',')) {
                                    b64 = b64.split(',').last;
                                  }
                                  itemImage = MemoryImage(base64Decode(b64));
                                } catch (_) {}

                                return Container(
                                  width: 70,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                    ),
                                    image: itemImage != null
                                        ? DecorationImage(
                                            image: itemImage,
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Commercial Info
                        _buildMobileSection(
                          title: tr('accounts.detail.commercial_title'),
                          icon: Icons.storefront_rounded,
                          children: [
                            _buildMobileDetailRow(
                              tr('accounts.table.price_group'),
                              cari.sfGrubu,
                            ),
                            _buildMobileDetailRow(
                              tr('accounts.table.discount'),
                              cari.sIskonto > 0 ? '%${cari.sIskonto}' : '',
                            ),
                            _buildMobileDetailRow(
                              tr('accounts.table.risk_limit'),
                              cari.riskLimiti > 0
                                  ? '${FormatYardimcisi.sayiFormatlaOndalikli(cari.riskLimiti, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ₺'
                                  : '',
                            ),
                            _buildMobileDetailRow(
                              tr('accounts.table.payment_term'),
                              cari.vadeGun > 0 ? '${cari.vadeGun} gün' : '',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Contact Info
                        _buildMobileSection(
                          title: tr('accounts.detail.contact_title'),
                          icon: Icons.perm_contact_calendar_rounded,
                          children: [
                            _buildMobileDetailRow(
                              tr('accounts.table.phone1'),
                              cari.telefon1,
                              isPhone: true,
                            ),
                            _buildMobileDetailRow(
                              tr('accounts.table.phone2'),
                              cari.telefon2,
                              isPhone: true,
                            ),
                            _buildMobileDetailRow(
                              tr('accounts.table.email'),
                              cari.eposta,
                              isEmail: true,
                            ),
                            _buildMobileDetailRow(
                              tr('accounts.table.website'),
                              cari.webAdresi,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Address Info
                        _buildMobileSection(
                          title: tr('accounts.table.invoice_address'),
                          icon: Icons.place_rounded,
                          children: [
                            _buildMobileDetailRow(
                              tr('accounts.table.invoice_title'),
                              cari.fatUnvani,
                            ),
                            if (cari.fatAdresi.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  cari.fatAdresi,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            _buildMobileDetailRow(
                              tr('accounts.table.invoice_city'),
                              [cari.fatIlce, cari.fatSehir]
                                  .where((element) => element.isNotEmpty)
                                  .join(' / '),
                            ),
                            _buildMobileDetailRow(
                              tr('accounts.table.tax_office'),
                              '${cari.vDairesi} / ${cari.vNumarasi}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions Footer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            await _cariDurumDegistir(cari, !cari.aktifMi);
                          },
                          icon: Icon(
                            cari.aktifMi
                                ? Icons.pause_circle_outline_rounded
                                : Icons.play_circle_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            cari.aktifMi
                                ? tr('common.deactivate')
                                : tr('common.activate'),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cari.aktifMi
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF2C3E50),
                            side: BorderSide(
                              color: cari.aktifMi
                                  ? const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.3)
                                  : const Color(
                                      0xFF2C3E50,
                                    ).withValues(alpha: 0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push<bool>(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        CariHesapEkleSayfasi(cariHesap: cari),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
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
                              _fetchCariHesaplar();
                            }
                          },
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: Text(tr('common.edit')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2C3E50),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
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
    );
  }

  Future<void> _updateAccountNote(CariHesapModel cari, String note) async {
    try {
      final updatedCari = cari.copyWith(bilgi1: note);
      await CariHesaplarVeritabaniServisi().cariHesapGuncelle(updatedCari);
      if (mounted) {
        MesajYardimcisi.basariGoster(context, tr('accounts.detail.note_saved'));
        _fetchCariHesaplar();
      }
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(context, e.toString());
      }
    }
  }

  Widget _buildMobileSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    // Hide section if all children are empty (SizedBox.shrink)
    final visibleChildren = children
        .where((child) => child is! SizedBox)
        .toList();
    if (visibleChildren.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2C3E50)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: visibleChildren),
        ),
      ],
    );
  }

  Widget _buildMobileDetailRow(
    String label,
    String value, {
    bool isPhone = false,
    bool isEmail = false,
  }) {
    if (value.isEmpty || value == ' / ') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: GestureDetector(
              onTap: () {
                if (isPhone) {
                  // Implement launchUrl for phone
                } else if (isEmail) {
                  // Implement launchUrl for email
                }
              },
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: (isPhone || isEmail)
                      ? Colors.blue.shade700
                      : Colors.black87,
                  decoration: (isPhone || isEmail)
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
          Expanded(child: _buildAccountTypeFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildTransactionTypeFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildUserFilter(width: double.infinity)),
        ],
      ),
    );
  }

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
                onTap: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                    _startDateController.clear();
                    _endDateController.clear();
                    _resetPagination();
                  });
                  _fetchCariHesaplar();
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
                      _resetPagination();
                    });
                    _fetchCariHesaplar();
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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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

  void _showAccountTypeOverlay() {
    _closeOverlay();
    setState(() {
      _isAccountTypeFilterExpanded = true;
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
            link: _accountTypeLayerLink,
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
                    _buildAccountTypeOption(null, tr('common.all')),
                    ...(_filterStats['turler']?.entries.map((e) {
                          return _buildAccountTypeOption(
                            e.key,
                            IslemCeviriYardimcisi.cevir(
                              IslemTuruRenkleri.getProfessionalLabel(e.key),
                            ),
                          );
                        }) ??
                        []),
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

  Widget _buildAccountTypeFilter({double? width}) {
    return CompositedTransformTarget(
      link: _accountTypeLayerLink,
      child: InkWell(
        onTap: () {
          if (_isAccountTypeFilterExpanded) {
            _closeOverlay();
          } else {
            _showAccountTypeOverlay();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 160,
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            _isAccountTypeFilterExpanded ? 7 : 8,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isAccountTypeFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade300,
                width: _isAccountTypeFilterExpanded ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.category_rounded,
                size: 20,
                color: _isAccountTypeFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedAccountType == null
                      ? tr('accounts.table.account_type')
                      : '${IslemCeviriYardimcisi.cevir(IslemTuruRenkleri.getProfessionalLabel(_selectedAccountType!))} (${_filterStats['turler']?[_selectedAccountType] ?? 0})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isAccountTypeFilterExpanded
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedAccountType != null)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedAccountType = null;
                      _resetPagination();
                    });
                    _fetchCariHesaplar();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isAccountTypeFilterExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: _isAccountTypeFilterExpanded
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

  Widget _buildAccountTypeOption(String? value, String label) {
    final isSelected = _selectedAccountType == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['turler']?[value] ?? 0);

    // [FACETED SEARCH 2026] Sıfır olanları gizle (şu an seçili değilse ve Tümü değilse)
    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedAccountType = value;
          _isAccountTypeFilterExpanded = false;
          _resetPagination();
        });
        _closeOverlay();
        _fetchCariHesaplar();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFF0F7FF) : Colors.transparent,
        child: Text(
          '${value == null ? label : () {
                  final parts = value.split('|');
                  return IslemCeviriYardimcisi.cevir(IslemTuruRenkleri.getProfessionalLabel(parts[0], context: 'cari', yon: parts.length > 1 ? parts[1] : null, suffix: parts.length > 2 ? parts[2] : null));
                }()} ($count)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF2C3E50) : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionTypeOption(String? value, String label) {
    final isSelected = _selectedTransactionType == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['islem_turleri']?[value] ?? 0);

    // [FACETED SEARCH 2026] Sıfır olanları gizle (şu an seçili değilse ve Tümü değilse)
    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTransactionType = value;
          _isTransactionTypeFilterExpanded = false;
          _resetPagination();
        });
        _closeOverlay();
        _fetchCariHesaplar();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFF0F7FF) : Colors.transparent,
        child: Text(
          '${value == null ? label : IslemCeviriYardimcisi.cevir(label)} ($count)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF2C3E50) : Colors.black87,
          ),
        ),
      ),
    );
  }

  void _showTransactionTypeOverlay() {
    _closeOverlay();
    setState(() {
      _isTransactionTypeFilterExpanded = true;
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
            link: _transactionTypeLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 42),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Container(
                width: 260,
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
                    _buildTransactionTypeOption(null, tr('common.all')),
                    ...(_filterStats['islem_turleri']?.entries.map((e) {
                          return _buildTransactionTypeOption(e.key, e.key);
                        }) ??
                        []),
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

  Widget _buildTransactionTypeFilter({double? width}) {
    return CompositedTransformTarget(
      link: _transactionTypeLayerLink,
      child: InkWell(
        onTap: () {
          if (_isTransactionTypeFilterExpanded) {
            _closeOverlay();
          } else {
            _showTransactionTypeOverlay();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 180,
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            _isTransactionTypeFilterExpanded ? 7 : 8,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isTransactionTypeFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade300,
                width: _isTransactionTypeFilterExpanded ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 20,
                color: _isTransactionTypeFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedTransactionType == null
                      ? tr('accounts.table.transaction_type')
                      : '${() {
                          final parts = _selectedTransactionType!.split('|');
                          return IslemCeviriYardimcisi.cevir(IslemTuruRenkleri.getProfessionalLabel(parts[0], context: 'cari', yon: parts.length > 1 ? parts[1] : null, suffix: parts.length > 2 ? parts[2] : null));
                        }()} (${_filterStats['islem_turleri']?[_selectedTransactionType] ?? 0})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isTransactionTypeFilterExpanded
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
                      _resetPagination();
                    });
                    _fetchCariHesaplar();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isTransactionTypeFilterExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: _isTransactionTypeFilterExpanded
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

    // [FACETED SEARCH 2026] Sıfır olanları gizle (şu an seçili değilse ve Tümü değilse)
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
        _fetchCariHesaplar();
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
                      _resetPagination();
                    });
                    _fetchCariHesaplar();
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

    // [FACETED SEARCH 2026] Sıfır olanları gizle (şu an seçili değilse ve Tümü değilse)
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
        _fetchCariHesaplar();
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
    List<CariHesapModel> cariHesaplar,
    BoxConstraints constraints,
  ) {
    final bool allSelected =
        _isSelectAllActive ||
        (cariHesaplar.isNotEmpty &&
            cariHesaplar.every((c) => _selectedIds.contains(c.id)));

    // Calculate column widths based on header text
    final colOrderWidth = _calculateColumnWidth(
      tr('language.table.orderNo'),
      sortable: true,
    );
    final colCodeWidth = _calculateColumnWidth(
      tr('accounts.table.code'),
      sortable: true,
    );
    final colTypeWidth = _calculateColumnWidth(
      tr('accounts.table.account_type'),
      sortable: true,
    );
    final colDebtWidth = _calculateColumnWidth(
      tr('accounts.table.balance_debit'),
      sortable: true,
    );
    final colCreditWidth = _calculateColumnWidth(
      tr('accounts.table.balance_credit'),
      sortable: true,
    );
    final colStatusWidth = _calculateColumnWidth(
      tr('accounts.table.status'),
      sortable: true,
    );
    const colActionsWidth = 100.0;

    return GenisletilebilirTablo<CariHesapModel>(
      title: tr('accounts.title'),
      totalRecords: _totalRecords,
      searchFocusNode: _searchFocusNode,
      onClearSelection: _clearAllTableSelections,
      onFocusedRowChanged: (item, index) {
        if (item != null) {
          setState(() => _selectedRowId = item.id);
        }
      },
      headerWidget: _buildFilters(),
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
        _fetchCariHesaplar();
      },
      onSearch: (query) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          setState(() {
            _searchQuery = query;
            _resetPagination();
          });
          _fetchCariHesaplar(showLoading: false);
        });
      },
      selectionWidget: (_selectedIds.isNotEmpty || _isSelectAllActive)
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _deleteSelectedCariHesaplar,
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
                        tr('common.delete_selected').replaceAll(
                          '{count}',
                          _isSelectAllActive
                              ? '$_totalRecords (Tümü)'
                              : _selectedIds.length.toString(),
                        ),
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
      expandedIndices: _autoExpandedIndices,
      onExpansionChanged: (index, isExpanded) {
        setState(() {
          if (isExpanded) {
            _manualExpandedIndex = index;
            _autoExpandedIndices.add(index);
          } else {
            if (_manualExpandedIndex == index) {
              _manualExpandedIndex = null;
            }
            _autoExpandedIndices.remove(index);
          }
        });
      },
      getDetailItemCount: (cari) =>
          _visibleTransactionIds[cari.id]?.length ?? 0,
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
                      _selectedIds.isNotEmpty
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
                        color: Colors.grey.shade400,
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
                  value: 'money_exchange',
                  enabled: _selectedRowId != null,
                  height: 44,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.currency_exchange_rounded,
                        size: 20,
                        color: _selectedRowId != null
                            ? const Color(0xFF4A4A4A)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        tr('accounts.actions.receipt'),
                        style: TextStyle(
                          color: _selectedRowId != null
                              ? const Color(0xFF4A4A4A)
                              : Colors.grey,
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
                  value: 'purchase',
                  enabled: _selectedRowId != null,
                  height: 44,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 20,
                        color: _selectedRowId != null
                            ? const Color(0xFF4A4A4A)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        tr('accounts.actions.purchase'),
                        style: TextStyle(
                          color: _selectedRowId != null
                              ? const Color(0xFF4A4A4A)
                              : Colors.grey,
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
                  value: 'sale',
                  enabled: _selectedRowId != null,
                  height: 44,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sell_outlined,
                        size: 20,
                        color: _selectedRowId != null
                            ? const Color(0xFF4A4A4A)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        tr('accounts.actions.sale'),
                        style: TextStyle(
                          color: _selectedRowId != null
                              ? const Color(0xFF4A4A4A)
                              : Colors.grey,
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
              onSelected: (value) {
                // Seçili cariyi bul
                CariHesapModel? targetCari;
                if (_selectedRowId != null) {
                  targetCari = _cachedCariHesaplar
                      .cast<CariHesapModel?>()
                      .firstWhere(
                        (c) => c?.id == _selectedRowId,
                        orElse: () => null,
                      );
                } else if (_selectedIds.length == 1) {
                  final selectedId = _selectedIds.first;
                  targetCari = _cachedCariHesaplar
                      .cast<CariHesapModel?>()
                      .firstWhere(
                        (c) => c?.id == selectedId,
                        orElse: () => null,
                      );
                }

                if (targetCari == null) {
                  MesajYardimcisi.hataGoster(
                    context,
                    tr('accounts.validation.select_one'),
                  );
                  return;
                }

                if (value == 'money_exchange') {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          BorcAlacakDekontuIsleSayfasi(cari: targetCari!),
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
                  ).then((result) {
                    if (result == true) {
                      _fetchCariHesaplar();
                    }
                  });
                  return;
                }

                if (value == 'purchase') {
                  // Tab olarak aç (menuIndex: 10 = Alış Yap)
                  TabAciciScope.of(
                    context,
                  )?.tabAc(menuIndex: 10, initialCari: targetCari);
                  return;
                }

                if (value == 'sale') {
                  // Tab olarak aç (menuIndex: 11 = Satış Yap)
                  TabAciciScope.of(
                    context,
                  )?.tabAc(menuIndex: 11, initialCari: targetCari);
                  return;
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
              onTap: () async {
                final result = await Navigator.push<bool>(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const CariHesapEkleSayfasi(),
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
                if (result == true) {
                  _fetchCariHesaplar();
                }
              },
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA4335),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('accounts.add'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tr('common.key.f1'),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
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
            width: colOrderWidth,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['code'] == true)
          GenisletilebilirTabloKolon(
            label: tr('accounts.table.code'),
            width: colCodeWidth,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['name'] == true)
          GenisletilebilirTabloKolon(
            label: tr('accounts.table.name'),
            width: 200, // Min width
            alignment: Alignment.centerLeft,
            allowSorting: true,
            flex: 1, // Only this column is flexible
          ),
        if (_columnVisibility['account_type'] == true)
          GenisletilebilirTabloKolon(
            label: tr('accounts.table.account_type'),
            width: colTypeWidth,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        if (_columnVisibility['balance_debit'] == true)
          GenisletilebilirTabloKolon(
            label: tr('accounts.table.balance_debit'),
            width: colDebtWidth,
            alignment: Alignment.centerRight,
            allowSorting: true,
          ),
        if (_columnVisibility['balance_credit'] == true)
          GenisletilebilirTabloKolon(
            label: tr('accounts.table.balance_credit'),
            width: colCreditWidth,
            alignment: Alignment.centerRight,
            allowSorting: true,
          ),
        if (_columnVisibility['status'] == true)
          GenisletilebilirTabloKolon(
            label: tr('accounts.table.status'),
            width: colStatusWidth,
            alignment: Alignment.centerLeft,
            allowSorting: true,
          ),
        GenisletilebilirTabloKolon(
          label: tr('common.actions'),
          width: colActionsWidth,
        ),
      ],
      data: cariHesaplar,
      isRowSelected: (cari, index) => _selectedRowId == cari.id,
      expandOnRowTap: false,
      onRowTap: (cari) {
        setState(() {
          _selectedRowId = cari.id;
        });
      },
      onRowDoubleTap: (cari) {
        TabAciciScope.of(
          context,
        )?.tabAc(menuIndex: TabAciciScope.cariKartiIndex, initialCari: cari);
      },
      rowBuilder: (context, cari, index, isExpanded, toggleExpand) {
        return _buildTableRow(
          cari,
          index,
          isExpanded,
          toggleExpand,
          colOrderWidth,
          colCodeWidth,
          colTypeWidth,
          colDebtWidth,
          colCreditWidth,
          colStatusWidth,
          colActionsWidth,
        );
      },
      detailBuilder: (context, cari) {
        return _buildDetailView(cari);
      },
    );
  }

  Widget _buildTableRow(
    CariHesapModel cari,
    int index,
    bool isExpanded,
    VoidCallback toggleExpand,
    double colOrderWidth,
    double colCodeWidth,
    double colTypeWidth,
    double colDebtWidth,
    double colCreditWidth,
    double colStatusWidth,
    double colActionsWidth,
  ) {
    Color? rowBgColor;
    Color? borderColor;
    Color textColor = Colors.black87;
    Color iconColor = Colors.grey;

    if (cari.renk == 'blue') {
      rowBgColor = Colors.blue.shade700;
      borderColor = Colors.blue.shade900;
      textColor = Colors.white;
      iconColor = Colors.white70;
    } else if (cari.renk == 'red') {
      rowBgColor = Colors.red.shade700;
      borderColor = Colors.red.shade900;
      textColor = Colors.white;
      iconColor = Colors.white70;
    } else if (cari.renk == 'black') {
      rowBgColor = Colors.grey.shade900;
      borderColor = Colors.black;
      textColor = Colors.white;
      iconColor = Colors.white70;
    }

    // RISK LIMIT CHECK
    double netBalance = cari.bakiyeBorc - cari.bakiyeAlacak;
    bool riskExceeded = cari.riskLimiti > 0 && netBalance > cari.riskLimiti;

    return Container(
      decoration: BoxDecoration(
        color: rowBgColor,
        border: borderColor != null
            ? Border(left: BorderSide(color: borderColor, width: 4))
            : null,
      ),
      child: Row(
        children: [
          _buildCell(
            width: 50,
            alignment: Alignment.center,
            child: SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _isSelectAllActive || _selectedIds.contains(cari.id),
                onChanged: (val) => _onSelectRow(val, cari.id),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: BorderSide(
                  color: textColor == Colors.white
                      ? Colors.white70
                      : const Color(0xFFD1D1D1),
                  width: 1,
                ),
                checkColor: textColor == Colors.white
                    ? Colors.black
                    : Colors.white,
                activeColor: textColor == Colors.white
                    ? Colors.white
                    : const Color(0xFF2C3E50),
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
                    onTap: toggleExpand,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  HighlightText(
                    text: cari.id.toString(),
                    query: _searchQuery,
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          if (_columnVisibility['code'] == true)
            _buildCell(
              width: colCodeWidth,
              child: HighlightText(
                text: cari.kodNo,
                query: _searchQuery,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (_columnVisibility['name'] == true)
            _buildCell(
              width: 200,
              flex: 1,
              child: HighlightText(
                text: cari.adi,
                query: _searchQuery,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_columnVisibility['account_type'] == true)
            _buildCell(
              width: colTypeWidth,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: IslemTuruRenkleri.getBackgroundColor(cari.hesapTuru),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: IslemTuruRenkleri.getTextColor(
                      cari.hesapTuru,
                    ).withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    IslemCeviriYardimcisi.cevir(
                      IslemTuruRenkleri.getProfessionalLabel(cari.hesapTuru),
                    ),
                    style: TextStyle(
                      color: IslemTuruRenkleri.getTextColor(cari.hesapTuru),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          if (_columnVisibility['balance_debit'] == true)
            _buildCell(
              width: colDebtWidth,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (riskExceeded) ...[
                    Tooltip(
                      message:
                          '${tr('accounts.error.risk_limit_exceeded')} (${FormatYardimcisi.sayiFormatlaOndalikli(cari.riskLimiti, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci)})',
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.deepOrange,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    netBalance > 0
                        ? '${FormatYardimcisi.sayiFormatlaOndalikli(netBalance, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${cari.paraBirimi}'
                        : '-',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: riskExceeded
                          ? Colors.deepOrange
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          if (_columnVisibility['balance_credit'] == true)
            _buildCell(
              width: colCreditWidth,
              alignment: Alignment.centerRight,
              child: Text(
                netBalance < 0
                    ? '${FormatYardimcisi.sayiFormatlaOndalikli(netBalance.abs(), binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${cari.paraBirimi}'
                    : '-',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          if (_columnVisibility['status'] == true)
            _buildCell(
              width: colStatusWidth,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cari.aktifMi
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
                        color: cari.aktifMi
                            ? const Color(0xFF28A745)
                            : const Color(0xFF757575),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cari.aktifMi
                            ? tr('common.active')
                            : tr('common.passive'),
                        style: TextStyle(
                          color: cari.aktifMi
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
          _buildCell(
            width: colActionsWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Tooltip(
                  message: _singleViewRowId == cari.id
                      ? tr('common.show_all_rows')
                      : tr('common.show_single_row'),
                  child: InkWell(
                    onTap: () => _toggleSingleView(cari.id),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _singleViewRowId == cari.id
                            ? const Color(0xFFE0F2F1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: _singleViewRowId == cari.id
                            ? Border.all(color: const Color(0xFFB2DFDB))
                            : null,
                      ),
                      child: Icon(
                        _singleViewRowId == cari.id
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 12,
                        color: _singleViewRowId == cari.id
                            ? const Color(0xFF00695C)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _buildPopupMenu(cari),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailView(CariHesapModel cari) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.grey.shade50,
      child: _buildTransactionsSection(cari),
    );
  }

  Widget _buildTransactionsSection(CariHesapModel cari) {
    final selectedIds = _selectedDetailIds[cari.id] ?? <int>{};
    final visibleIds = _visibleTransactionIds[cari.id] ?? [];
    final allSelected =
        visibleIds.isNotEmpty &&
        visibleIds.every((id) => selectedIds.contains(id));

    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('${cari.id}_$_refreshKey'),
      future: _detailFutures.putIfAbsent(
        cari.id,
        () => CariHesaplarVeritabaniServisi().cariIslemleriniGetir(
          cari.id,
          aramaTerimi: _searchController.text,
          baslangicTarihi: _startDate,
          bitisTarihi: _endDate,
          islemTuru: _selectedTransactionType,
        ),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '${tr('common.error')}: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final transactions = snapshot.data ?? [];

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _visibleTransactionIds[cari.id] = transactions
                .map((t) => t['id'] as int)
                .toList();
          }
        });

        if (transactions.isEmpty) {
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

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transactions Table Header with checkbox
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: allSelected,
                      onChanged: (val) => _onSelectAllDetails(cari.id, val),
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
                    tr('common.last_movements'),
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
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
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
                          tr('cashregisters.detail.transaction'), // İşlem
                        ),
                      ),
                    if (_columnVisibility['dt_transaction'] == true)
                      const SizedBox(width: 12),
                    if (_columnVisibility['dt_date'] == true)
                      Expanded(
                        flex: 2,
                        child: _buildDetailHeader(
                          tr('cashregisters.detail.date'), // Tarih
                        ),
                      ),
                    if (_columnVisibility['dt_date'] == true)
                      const SizedBox(width: 12),
                    if (_columnVisibility['dt_party'] == true)
                      Expanded(
                        flex: 3,
                        child: _buildDetailHeader(
                          tr('cashregisters.detail.party'), // İlgili Hesap
                        ),
                      ),
                    if (_columnVisibility['dt_party'] == true)
                      const SizedBox(width: 12),
                    if (_columnVisibility['dt_amount'] == true)
                      Expanded(
                        flex: 2,
                        child: _buildDetailHeader(
                          tr('common.amount'), // Tutar
                        ),
                      ),
                    if (_columnVisibility['dt_amount'] == true)
                      const SizedBox(width: 12),
                    if (_columnVisibility['dt_description'] == true)
                      Expanded(
                        flex: 3,
                        child: _buildDetailHeader(
                          tr('cashregisters.detail.description'), // Açıklama
                        ),
                      ),
                    if (_columnVisibility['dt_description'] == true)
                      const SizedBox(width: 12),
                    if (_columnVisibility['dt_due_date'] == true)
                      Expanded(
                        flex: 2,
                        child: _buildDetailHeader('Vad. Tarihi'),
                      ),
                    if (_columnVisibility['dt_due_date'] == true)
                      const SizedBox(width: 12),
                    if (_columnVisibility['dt_user'] == true)
                      Expanded(
                        flex: 2,
                        child: _buildDetailHeader(
                          tr('cashregisters.detail.user'), // Kullanıcı
                        ),
                      ),
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
                  final createdBy = tx['kullanici'] as String?;
                  String rawIslemTuru = tx['islem_turu']?.toString() ?? '';
                  String islemTuru = rawIslemTuru;

                  final String yon = tx['yon']?.toString() ?? '';
                  final sourceId = tx['source_id'] as int?;
                  final aciklama = tx['aciklama']?.toString() ?? '';
                  final isIncoming =
                      yon.toLowerCase().contains('alacak') ||
                      rawIslemTuru.toLowerCase().contains('tahsilat') ||
                      rawIslemTuru.toLowerCase().contains('alış') ||
                      rawIslemTuru.toLowerCase().contains('girdi') ||
                      rawIslemTuru.toLowerCase().contains('alındı') ||
                      rawIslemTuru.toLowerCase().contains('alindi');

                  // [2026 FIX] Self-Healing UI: Check real status from DB
                  final String realStatus =
                      tx['guncel_durum']?.toString() ?? '';
                  if (realStatus == 'Ciro Edildi' ||
                      rawIslemTuru.contains('Ciro')) {
                    if (!islemTuru.contains('Ciro')) {
                      // Status mismatch or needs label correction
                      if (islemTuru.toLowerCase().contains('çek') ||
                          rawIslemTuru.toLowerCase().contains('çek')) {
                        islemTuru = 'Çek Alındı (Ciro Edildi)';
                      } else if (islemTuru.toLowerCase().contains('senet') ||
                          rawIslemTuru.toLowerCase().contains('senet')) {
                        islemTuru = 'Senet Alındı (Ciro Edildi)';
                      }
                    }
                  } else if (realStatus == 'Tahsil Edildi' ||
                      realStatus == 'Ödendi') {
                    if (!islemTuru.contains('Tahsil') &&
                        !islemTuru.contains('Öden')) {
                      if (islemTuru.toLowerCase().contains('çek') ||
                          rawIslemTuru.toLowerCase().contains('çek')) {
                        islemTuru =
                            'Çek ${isIncoming ? 'Alındı' : 'Verildi'} ($realStatus)';
                      } else if (islemTuru.toLowerCase().contains('senet') ||
                          rawIslemTuru.toLowerCase().contains('senet')) {
                        islemTuru =
                            'Senet ${isIncoming ? 'Alındı' : 'Verildi'} ($realStatus)';
                      }
                    }
                  }

                  // Map raw internal types to user-friendly labels for display
                  if (islemTuru == 'Girdi' || islemTuru == 'Tahsilat') {
                    islemTuru = 'Para Alındı';
                  } else if (islemTuru == 'Çıktı' || islemTuru == 'Ödeme') {
                    islemTuru = 'Para Verildi';
                  }

                  // Tarih formatlaması
                  String tarihStr = '';
                  final rawTarih = tx['tarih'];

                  if (rawTarih != null) {
                    DateTime? dt;
                    if (rawTarih is DateTime) {
                      dt = rawTarih;
                    } else if (rawTarih is String) {
                      dt = DateTime.tryParse(rawTarih);
                    }

                    if (dt != null) {
                      // [2025 FIX] Eğer saat 00:00 ise ve created_at varsa, saati created_at'den al
                      final createdAt = tx['created_at'];
                      if (dt.hour == 0 &&
                          dt.minute == 0 &&
                          dt.second == 0 &&
                          createdAt != null) {
                        try {
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
                        } catch (_) {}
                      }
                      tarihStr = DateFormat('dd.MM.yyyy HH:mm').format(dt!);
                    } else {
                      tarihStr = rawTarih.toString();
                    }
                  } else {
                    tarihStr = '-';
                  }

                  // Kaynak bilgilerini veritabanından al (yeni kayıtlar için)
                  // Eski kayıtlar için açıklamadan çıkarmaya çalış
                  String locationName = tx['kaynak_adi']?.toString() ?? '';
                  String locationCode = tx['kaynak_kodu']?.toString() ?? '';

                  // Eğer veritabanında kaynak bilgisi yoksa, açıklamadan çıkarmaya çalış
                  if (locationName.isEmpty && aciklama.isNotEmpty) {
                    // Açıklamadan kaynak adını çıkarmaya çalış
                    // Örnek: "Kasa - Merkez Kasa" -> locationName = "Merkez Kasa"
                    if (aciklama.contains(' - ')) {
                      final parts = aciklama.split(' - ');
                      if (parts.length >= 2) {
                        locationName = parts.sublist(1).join(' - ').trim();
                      }
                    }
                  }

                  // Source ID varsa ve kod boşsa, ID'yi kod olarak kullan
                  if (locationCode.isEmpty &&
                      sourceId != null &&
                      sourceId > 0) {
                    locationCode = '#$sourceId';
                  }

                  // Vade Tarihi formatlaması (Çek/Senet ise Keşide Tarihi olarak işlem tarihini göster)
                  String vtStr = '-';
                  final vt =
                      (rawIslemTuru.contains('Çek') ||
                          rawIslemTuru.contains('Senet'))
                      ? tx['tarih']
                      : tx['vade_tarihi'];
                  if (vt != null && vt.toString().isNotEmpty) {
                    try {
                      DateTime? dt;
                      if (vt is DateTime) {
                        dt = vt;
                      } else {
                        dt = DateTime.tryParse(vt.toString());
                      }
                      if (dt != null) {
                        vtStr = DateFormat('dd.MM.yyyy').format(dt);
                      }
                    } catch (_) {}
                  }

                  final focusScope = TableDetailFocusScope.of(context);
                  final isFocused = focusScope?.focusedDetailIndex == index;

                  final String? iRef = tx['integration_ref']?.toString();
                  final String lowRef = iRef?.toLowerCase() ?? '';
                  final bool isSale = lowRef.startsWith('sale-');
                  final bool isPurchase = lowRef.startsWith('purchase-');
                  final bool isCheckNote =
                      lowRef.startsWith('cheque') ||
                      lowRef.startsWith('cek-') ||
                      lowRef.startsWith('note') ||
                      lowRef.startsWith('senet-') ||
                      lowRef.contains('cek-') ||
                      lowRef.contains('senet-');

                  final String lowRawIslemTuru = rawIslemTuru.toLowerCase();
                  final bool isAcilisDevri =
                      (lowRawIslemTuru.contains('açılış') ||
                          lowRawIslemTuru.contains('acilis')) &&
                      (lowRawIslemTuru.contains('devir') ||
                          lowRawIslemTuru.contains('devri'));

                  final String cariLabel =
                      IslemTuruRenkleri.getProfessionalLabel(
                        rawIslemTuru,
                        context: 'cari',
                        yon: yon,
                      );

                  String displayName = islemTuru;
                  if (isAcilisDevri) {
                    displayName = rawIslemTuru;
                  } else if (isSale) {
                    displayName = cariLabel;
                  } else if (isPurchase) {
                    displayName = cariLabel;
                  } else if (isCheckNote) {
                    // Eğer veritabanındaki islemTuru zaten durum bilgisini içeriyorsa (veya self-healed ise) onu kullan
                    if (islemTuru.contains('Tahsil Edildi') ||
                        islemTuru.contains('Ödendi') ||
                        islemTuru.contains('Karşılıksız') ||
                        islemTuru.contains('Ciro')) {
                      displayName = islemTuru;
                    } else if (lowRef.contains('cheque') ||
                        lowRef.contains('cek-')) {
                      displayName = isIncoming ? 'Çek Alındı' : 'Çek Verildi';
                    } else if (lowRef.contains('note') ||
                        lowRef.contains('senet-')) {
                      displayName = isIncoming
                          ? 'Senet Alındı'
                          : 'Senet Verildi';
                    }
                  } else {
                    // [2025 FIX] Eğer islemTuru zaten zenginleştirilmişse kullan
                    if (islemTuru.contains('(') && islemTuru.contains(')')) {
                      displayName = islemTuru;
                    } else {
                      displayName =
                          (islemTuru.contains('Çek') ||
                              islemTuru.contains('Senet') ||
                              islemTuru.contains('Dekont'))
                          ? islemTuru
                          : (isIncoming ? 'Para Alındı' : 'Para Verildi');
                    }
                  }

                  // Clear description for check/note transactions if automated
                  String displayDescription = rawIslemTuru.contains('Açılış')
                      ? ''
                      : aciklama;
                  if (isCheckNote) {
                    final lowDesc = aciklama.toLowerCase();
                    if (lowDesc.contains('tahsilat') ||
                        lowDesc.contains('ödeme') ||
                        lowDesc.contains('no:')) {
                      displayDescription = '';
                    }
                  }

                  // Rozet metni (locationType) temizle
                  String displayLocationType = islemTuru;
                  if (isAcilisDevri) {
                    displayLocationType = rawIslemTuru;
                  } else if (isSale) {
                    displayLocationType = cariLabel;
                  } else if (isPurchase) {
                    displayLocationType = cariLabel;
                  } else if (isCheckNote) {
                    if (lowRef.contains('cheque') || lowRef.contains('cek-')) {
                      displayLocationType = 'Çek';
                    } else if (lowRef.contains('note') ||
                        lowRef.contains('senet-')) {
                      displayLocationType = 'Senet';
                    }

                    // [2026 FIX] For check/note, ensure we use the actual number if available (from SQL subquery)
                    if (locationName.isNotEmpty &&
                        !locationName.contains('\n') &&
                        !locationName.contains(' - ')) {
                      locationCode = locationName;
                    }
                  } else if (rawIslemTuru.contains('Çek') ||
                      rawIslemTuru.contains('Senet')) {
                    displayLocationType = rawIslemTuru.contains('Çek')
                        ? 'Çek'
                        : 'Senet';

                    if (locationName.isNotEmpty &&
                        !locationName.contains('\n') &&
                        !locationName.contains(' - ')) {
                      locationCode = locationName;
                    }
                  }

                  return Column(
                    children: [
                      _buildTransactionRow(
                        cari: cari,
                        id: tx['id'],
                        isSelected: val,
                        isFocused: isFocused,
                        onChanged: (val) =>
                            _onSelectDetailRow(cari.id, tx['id'], val),
                        onTap: () {
                          focusScope?.setFocusedDetailIndex?.call(index);
                        },
                        isIncoming: isIncoming,
                        name: displayName,
                        date: tarihStr,
                        amount: () {
                          final val = tx['tutar'];
                          if (val is num) return val.toDouble();
                          if (val is String) return double.tryParse(val) ?? 0.0;
                          return 0.0;
                        }(),
                        currency: cari.paraBirimi,
                        locationType: displayLocationType,
                        integrationRef: iRef,
                        locationName: locationName,
                        locationCode: locationCode,
                        description: displayDescription,
                        user: (createdBy ?? '').isEmpty ? 'Sistem' : createdBy!,
                        dueDate: vtStr,
                        customTypeLabel: rawIslemTuru,
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
    );
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

  Widget _buildTransactionRow({
    required CariHesapModel cari,
    required int id,
    required bool isSelected,
    required ValueChanged<bool?> onChanged,
    required bool isIncoming,
    required String name,
    required String date,
    required double amount,
    required String currency,
    required String locationType,
    String? integrationRef,
    required String locationName,
    required String locationCode,
    required String description,
    required String user,
    required String dueDate,
    String? customTypeLabel, // Add raw type for coloring
    bool isFocused = false,
    VoidCallback? onTap,
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
        return GestureDetector(
          onTap: onTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click, // Show pointer on hover
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFC8E6C9)
                    : (isFocused
                          ? const Color(0xFFE8F5E9)
                          : Colors.transparent),
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
                            child: Row(
                              children: [
                                Flexible(
                                  child: HighlightText(
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
                                ),
                                if (_getSourceSuffix(
                                  locationType,
                                  integrationRef,
                                  locationName,
                                ).isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 3.0),
                                    child: HighlightText(
                                      text:
                                          IslemCeviriYardimcisi.parantezliKaynakKisaltma(
                                            _getSourceSuffix(
                                              locationType,
                                              integrationRef,
                                              locationName,
                                            ),
                                          ),
                                      query: _searchQuery,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_columnVisibility['dt_transaction'] == true)
                    const SizedBox(width: 12),
                  // DATE
                  if (_columnVisibility['dt_date'] == true)
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
                  if (_columnVisibility['dt_date'] == true)
                    const SizedBox(width: 12),
                  // PARTY (İlgili Hesap)
                  if (_columnVisibility['dt_party'] == true)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // TOP LINE: Account Name or Category fallback
                          HighlightText(
                            text:
                                (locationType.contains('Çek') ||
                                    locationType.contains('Senet'))
                                ? (locationName.contains('\n')
                                      ? locationName.split('\n').first
                                      : locationName)
                                : (locationName.isNotEmpty
                                      ? locationName
                                      : (locationType == 'Kasa' ||
                                                locationType == 'Banka' ||
                                                locationType == 'Kredi Kartı'
                                            ? IslemCeviriYardimcisi.cevir(
                                                locationType,
                                              )
                                            : '-')),
                            query: _searchQuery,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          // BOTTOM LINE: Vertical list of badges (filtered)
                          if (locationType.contains('Çek') ||
                              locationType.contains('Senet'))
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: (locationName.split('\n'))
                                  .map((s) => s.trim())
                                  .where(
                                    (s) =>
                                        s.isNotEmpty &&
                                        !s.toLowerCase().contains(
                                          cari.adi.toLowerCase(),
                                        ),
                                  )
                                  .toSet() // DEDUPLICATE: Remove same items
                                  .map(
                                    (s) => Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: HighlightText(
                                          text: s,
                                          query: _searchQuery,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            )
                          else if (locationType.isNotEmpty ||
                              locationCode.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Container(
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
                                  text:
                                      '${IslemCeviriYardimcisi.cevir((locationType == 'Kasa' || locationType == 'Banka' || locationType == 'Kredi Kartı') ? (isIncoming ? 'Para Alındı' : 'Para Verildi') : locationType)}${locationCode.isNotEmpty ? ' $locationCode' : ''}',
                                  query: _searchQuery,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          if (locationName.isEmpty &&
                              locationCode.isEmpty &&
                              locationType.isEmpty)
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
                  if (_columnVisibility['dt_party'] == true)
                    const SizedBox(width: 12),
                  // AMOUNT
                  if (_columnVisibility['dt_amount'] == true)
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
                  if (_columnVisibility['dt_amount'] == true)
                    const SizedBox(width: 12),
                  // DESCRIPTION
                  if (_columnVisibility['dt_description'] == true)
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
                  if (_columnVisibility['dt_description'] == true)
                    const SizedBox(width: 12),
                  // DUE DATE
                  if (_columnVisibility['dt_due_date'] == true)
                    Expanded(
                      flex: 2,
                      child: Builder(
                        builder: (context) {
                          final bool isCheckOrNote =
                              locationType.contains('Çek') ||
                              locationType.contains('Senet');
                          if (dueDate == '-' || !isCheckOrNote) {
                            return HighlightText(
                              text: dueDate,
                              query: _searchQuery,
                              style: TextStyle(
                                fontSize: 11,
                                color: dueDate == '-'
                                    ? Colors.grey.shade400
                                    : Colors.blue.shade700,
                                fontWeight: dueDate == '-'
                                    ? FontWeight.normal
                                    : FontWeight.w700,
                              ),
                            );
                          }
                          return RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: dueDate,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '\n${tr('checks.field.issue_date_short')}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (_columnVisibility['dt_due_date'] == true)
                    const SizedBox(width: 12),
                  // USER
                  if (_columnVisibility['dt_user'] == true)
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
              ),
            ),
          ),
        );
      },
    );
  }

  void _onSelectAllDetails(int cariId, bool? value) {
    setState(() {
      if (value == true) {
        final visibleIds = _visibleTransactionIds[cariId] ?? [];
        _selectedDetailIds[cariId] = visibleIds.toSet();
      } else {
        _selectedDetailIds[cariId]?.clear();
      }
    });
  }

  void _onSelectDetailRow(int cariId, int txId, bool? value) {
    setState(() {
      _selectedDetailIds.putIfAbsent(cariId, () => {});
      if (value == true) {
        _selectedDetailIds[cariId]!.add(txId);
      } else {
        _selectedDetailIds[cariId]!.remove(txId);
      }
    });
  }

  Future<void> _updateAccountColor(CariHesapModel cari, String? color) async {
    try {
      final newCari = cari.copyWith(renk: color);
      await CariHesaplarVeritabaniServisi().cariHesapGuncelle(newCari);
      _fetchCariHesaplar();
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(
          context,
          '${tr('common.error.color_update_failed')}: $e',
        );
      }
    }
  }

  void _showColorPickerDialog(CariHesapModel cari) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            tr('common.mark_color'),
            style: const TextStyle(fontSize: 18),
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildColorOption(cari, 'black', Colors.black, 'Siyah'),
              _buildColorOption(cari, 'blue', Colors.blue, 'Mavi'),
              _buildColorOption(cari, 'red', Colors.red, 'Kırmızı'),
              _buildColorOption(
                cari,
                '', // Pass empty string to clear
                Colors.grey.shade300,
                'Temizle',
                isNull: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorOption(
    CariHesapModel cari,
    String? colorVal,
    Color color,
    String label, {
    bool isNull = false,
  }) {
    final bool isSelected = cari.renk == colorVal;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _updateAccountColor(cari, colorVal);
          Navigator.pop(context);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.black, width: 3)
                    : (isNull ? Border.all(color: Colors.grey) : null),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 24)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupMenu(CariHesapModel cari) {
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
        onSelected: (value) async {
          if (value == 'edit') {
            final result = await Navigator.push<bool>(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    CariHesapEkleSayfasi(cariHesap: cari),
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
            if (result == true) {
              _fetchCariHesaplar();
            }
          } else if (value == 'open_card') {
            TabAciciScope.of(context)?.tabAc(
              menuIndex: TabAciciScope.cariKartiIndex,
              initialCari: cari,
            );
          } else if (value == 'mark') {
            _showColorPickerDialog(cari);
          } else if (value == 'toggle_status') {
            await _cariDurumDegistir(cari, !cari.aktifMi);
          } else if (value == 'delete') {
            _deleteCariHesap(cari);
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
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
            value: 'open_card',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.credit_card_outlined,
                  size: 20,
                  color: Color(0xFFF39C12),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('accounts.actions.open_card'),
                  style: const TextStyle(
                    color: Color(0xFFF39C12),
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
            value: 'mark',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.format_paint_outlined,
                  size: 20,
                  color: Color(0xFF4A4A4A),
                ),
                const SizedBox(width: 12),
                Text(
                  tr('common.mark'),
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
            value: 'toggle_status',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  cari.aktifMi
                      ? Icons.toggle_on_outlined
                      : Icons.toggle_off_outlined,
                  size: 20,
                  color: const Color(0xFF2C3E50),
                ),
                const SizedBox(width: 12),
                Text(
                  cari.aktifMi
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
      ),
    );
  }

  void _onSelectAll(bool? value) {
    setState(() {
      _isSelectAllActive = value == true;
      if (value == true) {
        _selectedIds.clear();
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

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      switch (columnIndex) {
        case 1:
          _sortBy = 'id';
          break;
        case 2:
          _sortBy = 'kod_no';
          break;
        case 3:
          _sortBy = 'adi';
          break;
        case 4:
          _sortBy = 'hesap_turu';
          break;
        case 5:
          _sortBy = 'bakiye_borc';
          break;
        case 6:
          _sortBy = 'bakiye_alacak';
          break;
        case 7:
          _sortBy = 'aktif_mi';
          break;
        default:
          _sortBy = 'id';
      }
    });
    _fetchCariHesaplar();
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

  String _getSourceSuffix(
    String locationType,
    String? integrationRef,
    String locationName,
  ) {
    if (locationType.isEmpty && locationName.isEmpty) return '';

    // Priority 1: Integration Reference check (Origin based)
    if (integrationRef != null) {
      if (integrationRef.startsWith('CARI-')) return '(Cari)';
      if (integrationRef.startsWith('AUTO-TR-')) {
        final lowName = locationName.toLowerCase();
        final lowType = locationType.toLowerCase();
        if (lowName.contains('kasa') || lowType.contains('kasa')) {
          return '(Kasa)';
        }
        if (lowName.contains('banka') || lowType.contains('banka')) {
          return '(Banka)';
        }
        if (lowName.contains('pos') ||
            lowName.contains('kart') ||
            lowType.contains('kart')) {
          return '(K.Kartı)';
        }
        return '(Kasa)'; // Default for Kasa-side entries if no specific name
      }

      // Legacy support for older CARI-PAV formats
      if (integrationRef.contains('-CASH-')) return '(Kasa)';
      if (integrationRef.contains('-BANK-')) return '(Banka)';
      if (integrationRef.contains('-CREDIT_CARD-')) return '(K.Kartı)';
    }

    // Money Transactions check
    final String lowLocationType = locationType.toLowerCase();
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
        locationType.contains('Dekont') ||
        lowLocationType.startsWith('ödeme') ||
        lowLocationType.startsWith('odeme');

    if (isMoneyTx) {
      final lowName = locationName.toLowerCase();
      final lowType = locationType.toLowerCase();
      if (lowName.contains('kasa') || lowType.contains('kasa')) return '(Kasa)';
      if (lowName.contains('banka') || lowType.contains('banka')) {
        return '(Banka)';
      }
      if (lowName.contains('pos') ||
          lowName.contains('kart') ||
          lowType.contains('kart')) {
        return '(K.Kartı)';
      }

      // If it's a collection/payment but no specific source found, use fallback
      if (locationName.isEmpty) {
        if (locationType.toLowerCase().contains('tahsilat') ||
            locationType == 'Para Alındı') {
          return '(Kasa)';
        }
        if (locationType.toLowerCase().contains('ödeme') ||
            locationType == 'Para Verildi') {
          return '(Kasa)';
        }
      }
    }

    // Diğer işlemler için (Fatura vb.)
    if (locationType.toLowerCase().contains('satış') ||
        locationType.toLowerCase().contains('alış') ||
        locationType.toLowerCase().contains('fatura')) {
      return '(Cari)';
    }

    // Çek/Senet kontrolü - Etiket gösterilmeyecek
    if (integrationRef != null) {
      final String lowRef = integrationRef.toLowerCase();
      if (lowRef.startsWith('cheque') ||
          lowRef.startsWith('cek-') ||
          lowRef.startsWith('note') ||
          lowRef.startsWith('senet-')) {
        return '';
      }
    }

    return '';
  }
}
