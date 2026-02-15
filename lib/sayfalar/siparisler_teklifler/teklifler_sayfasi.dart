import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../../bilesenler/genisletilebilir_tablo.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/ceviri/islem_ceviri_yardimcisi.dart';
import '../../../yardimcilar/responsive_yardimcisi.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import '../../../bilesenler/highlight_text.dart';
import 'modeller/teklif_model.dart';
import 'teklif_ekle_sayfasi.dart';
import '../../../bilesenler/tarih_araligi_secici_dialog.dart';
import 'teklif_donustur_dialog.dart';
import '../alimsatimislemleri/satis_yap_sayfasi.dart';
import '../alimsatimislemleri/modeller/transaction_item.dart';
import '../carihesaplar/modeller/cari_hesap_model.dart';
import '../../../yardimcilar/mesaj_yardimcisi.dart';
import '../../../servisler/teklifler_veritabani_servisi.dart';
import '../../../bilesenler/onay_dialog.dart';
import '../../../bilesenler/tab_acici_scope.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../../servisler/ayarlar_veritabani_servisi.dart';
import '../../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../ortak/genisletilebilir_print_preview_screen.dart';
import '../../../servisler/urunler_veritabani_servisi.dart';
import '../../../servisler/uretimler_veritabani_servisi.dart';
import '../../../servisler/depolar_veritabani_servisi.dart';
import '../urunler_ve_depolar/urunler/modeller/urun_model.dart';
import '../urunler_ve_depolar/uretimler/modeller/uretim_model.dart';
import '../urunler_ve_depolar/depolar/modeller/depo_model.dart';
import '../../../yardimcilar/islem_turu_renkleri.dart';
import '../../../servisler/sayfa_senkronizasyon_servisi.dart';

class TekliflerSayfasi extends StatefulWidget {
  final String tur;
  const TekliflerSayfasi({super.key, required this.tur});

  @override
  State<TekliflerSayfasi> createState() => _TekliflerSayfasiState();
}

class _TekliflerSayfasiState extends State<TekliflerSayfasi> {
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  final TextEditingController _mobileSearchController = TextEditingController();
  bool _isMobileToolbarExpanded = false;
  final Set<int> _mobileExpandedQuoteIds = {};

  bool _isLoading = false;
  int _totalRecords = 0;
  List<TeklifModel> _teklifler = [];

  int? _sortColumnIndex;
  bool _sortAscending = true;
  int? _selectedRowId;
  Set<int> _selectedIds = {};
  bool _isSelectAllActive = false;
  final Set<int> _autoExpandedIndices = {};
  bool _keepDetailsOpen = false;

  // Column Visibility State
  Map<String, bool> _columnVisibility = {};

  // Track selected products inside teklifler
  final Map<int, Set<int>> _selectedDetailIds = {};
  // Track visible product IDs per teklif for "Select All" logic
  final Map<int, List<int>> _visibleProductIds = {};
  // Track specific selection for keyboard/shortcuts
  int? _selectedDetailProductId;
  TeklifModel? _selectedDetailTeklif;

  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  // Inline Editing State
  int? _editingIndex;
  int? _editingQuoteId;
  String? _editingField; // 'price', 'discount', 'quantity'
  DateTime? _startDate;
  DateTime? _endDate;

  // Filtre State (Kasalar ile aynı overlay mantığı)
  OverlayEntry? _overlayEntry;
  final LayerLink _statusLayerLink = LayerLink();
  final LayerLink _typeLayerLink = LayerLink();
  final LayerLink _warehouseLayerLink = LayerLink();
  final LayerLink _unitLayerLink = LayerLink();
  final LayerLink _accountLayerLink = LayerLink();
  final LayerLink _userLayerLink = LayerLink();

  bool _isStatusFilterExpanded = false;
  bool _isTypeFilterExpanded = false;
  bool _isWarehouseFilterExpanded = false;
  bool _isUnitFilterExpanded = false;
  bool _isAccountFilterExpanded = false;
  bool _isUserFilterExpanded = false;

  String? _selectedStatus;
  String? _selectedType;
  DepoModel? _selectedWarehouse;
  String? _selectedUnit;
  String? _selectedAccount;
  String? _selectedUser;

  List<DepoModel> _warehouses = [];
  Map<String, Map<String, int>> _filterStats = {};

  @override
  void initState() {
    super.initState();
    _mobileSearchController.text = _searchQuery;
    _columnVisibility = {
      // Main Table
      'order_no': true,
      'type': true,
      'status': true,
      'date': true,
      'related_account': true,
      'amount': true,
      'rate': true,
      'description': true,
      'description2': true,
      'validity_date': true,
      'user': true,
      // Detail Table (Products)
      'dt_code': true,
      'dt_name': true,
      'dt_barcode': true,
      'dt_warehouse': true,
      'dt_vat_rate': true,
      'dt_vat': true,
      'dt_quantity': true,
      'dt_unit': true,
      'dt_discount': true,
      'dt_unit_price': true,
      'dt_total_amount': true,
    };
    _loadSettings();
    _fetchWarehouses();
    _fetchTeklifler();
    SayfaSenkronizasyonServisi().addListener(_onGlobalSync);
  }

  void _onGlobalSync() {
    _fetchTeklifler(silent: true);
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      if (mounted) {
        setState(() {
          _genelAyarlar = settings;
        });
      }
    } catch (e) {
      debugPrint('Ayarlar yüklenirken hata: $e');
    }
  }

  int _currentPage = 1;
  int _rowsPerPage = 25;
  int _previousPage = 1;
  int _aktifSorguNo = 0;

  Future<void> _fetchTeklifler({
    bool force = false,
    bool silent = false,
  }) async {
    final int sorguNo = ++_aktifSorguNo;
    if (_isLoading && !force) {
      return;
    }
    if (!silent && mounted) setState(() => _isLoading = true);

    try {
      final servis = TekliflerVeritabaniServisi();

      String? sortBy;
      if (_sortColumnIndex != null) {
        switch (_sortColumnIndex) {
          case 4:
            sortBy = 'tarih';
            break;
          case 6:
            sortBy = 'tutar';
            break;
          case 3:
            sortBy = 'durum';
            break;
        }
      }

      final lastId =
          (_currentPage == _previousPage + 1 && _teklifler.isNotEmpty)
          ? _teklifler.last.id
          : null;

      final countFuture = servis.teklifSayisiGetir(
        aramaTerimi: _searchQuery,
        tur: _selectedType,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        durum: _selectedStatus,
        depoId: _selectedWarehouse?.id,
        birim: _selectedUnit,
        ilgiliHesapAdi: _selectedAccount,
        kullanici: _selectedUser,
      );

      final statsFuture = servis.teklifFiltreIstatistikleriniGetir(
        aramaTerimi: _searchQuery,
        tur: _selectedType,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        durum: _selectedStatus,
        depoId: _selectedWarehouse?.id,
        birim: _selectedUnit,
        ilgiliHesapAdi: _selectedAccount,
        kullanici: _selectedUser,
      );

      final results = await servis.teklifleriGetir(
        sayfa: _currentPage,
        sayfaBasinaKayit: _rowsPerPage,
        aramaTerimi: _searchQuery,
        sortBy: sortBy,
        sortAscending: _sortAscending,
        tur: _selectedType,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        durum: _selectedStatus,
        depoId: _selectedWarehouse?.id,
        birim: _selectedUnit,
        ilgiliHesapAdi: _selectedAccount,
        kullanici: _selectedUser,
        lastId: lastId,
      );

      if (!mounted || sorguNo != _aktifSorguNo) return;

      if (mounted) {
        // Find indices that match in hidden fields (sub-table) and should be auto-expanded
        final newAutoExpandedIndices = results
            .asMap()
            .entries
            .where((e) => e.value.matchedInHidden)
            .map((e) => e.key)
            .toSet();

        setState(() {
          _teklifler = results;
          _isLoading = false;
          _autoExpandedIndices.clear();
          _autoExpandedIndices.addAll(newAutoExpandedIndices);
        });
      }

      unawaited(
        countFuture
            .then((count) {
              if (!mounted || sorguNo != _aktifSorguNo) return;
              setState(() {
                _totalRecords = count;
              });
            })
            .catchError((e) {
              debugPrint('Teklif toplam sayısı güncellenemedi: $e');
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
              debugPrint('Teklif filtre istatistikleri güncellenemedi: $e');
            }),
      );
    } catch (e) {
      if (mounted && sorguNo == _aktifSorguNo) {
        setState(() => _isLoading = false);
        MesajYardimcisi.hataGoster(
          context,
          '${tr('quotes.error.load_failed')}: $e',
        );
      }
    }
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  void _onSearch(String query) {
    if (_isLoading) return;
    setState(() {
      _searchQuery = query;
      _currentPage = 1;
    });
    _fetchTeklifler();
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
        _currentPage = 1;
      });
      _fetchTeklifler();
    }
  }

  void _onPageChanged(int page, int rowsPerPage) {
    setState(() {
      _previousPage = _currentPage;
      _currentPage = page;
      _rowsPerPage = rowsPerPage;
    });
    _fetchTeklifler();
  }

  void _onSelectAll(bool? value) {
    setState(() {
      _isSelectAllActive = value == true;
      if (value == true) {
        _selectedIds = _teklifler.map((s) => s.id).toSet();
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
        _isSelectAllActive = false;
      }
    });
  }

  void _onSelectAllDetails(int quoteId, bool? value) {
    setState(() {
      if (value == true) {
        _selectedDetailIds[quoteId] = (_visibleProductIds[quoteId] ?? [])
            .toSet();
      } else {
        _selectedDetailIds[quoteId]?.clear();
      }
    });
  }

  void _onSelectDetailRow(int quoteId, int productId, bool? value) {
    setState(() {
      final selected = _selectedDetailIds[quoteId] ?? {};
      if (value == true) {
        selected.add(productId);
      } else {
        selected.remove(productId);
      }
      _selectedDetailIds[quoteId] = selected;
    });
  }

  Future<void> _teklifOlustur() async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TeklifEkleSayfasi(tur: widget.tur),
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
      _fetchTeklifler();
    }
  }

  Future<void> _teklifSil(TeklifModel teklif) async {
    showDialog(
      context: context,
      builder: (dialogContext) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr(
          'quotes.confirm_delete_quote',
        ).replaceAll('{id}', teklif.id.toString()),
        onayButonMetni: tr('common.delete'),
        isDestructive: true,
        onOnay: () async {
          setState(() => _isLoading = true);
          final basarili = await TekliflerVeritabaniServisi().teklifSil(
            teklif.id,
          );
          if (mounted) {
            setState(() => _isLoading = false);
            if (basarili) {
              SayfaSenkronizasyonServisi().veriDegisti('siparis');
              MesajYardimcisi.basariGoster(
                context,
                tr('common.deleted_successfully'),
              );
              _fetchTeklifler();
            } else {
              MesajYardimcisi.hataGoster(context, tr('common.error'));
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    SayfaSenkronizasyonServisi().removeListener(_onGlobalSync);
    _searchFocusNode.dispose();
    _mobileSearchController.dispose();
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Focus(
        autofocus: false,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.f1): _teklifOlustur,
            const SingleActivator(LogicalKeyboardKey.f2): () {
              if (_selectedRowId != null) {
                final order = _teklifler.firstWhereOrNull(
                  (o) => o.id == _selectedRowId,
                );
                if (order != null) {
                  _teklifDuzenle(order);
                }
              }
            },
            const SingleActivator(LogicalKeyboardKey.f3): () =>
                _searchFocusNode.requestFocus(),
            const SingleActivator(LogicalKeyboardKey.f4): _topluTeklifOnayla,
            const SingleActivator(LogicalKeyboardKey.f5): () {
              if (_selectedDetailProductId != null &&
                  _selectedDetailTeklif != null &&
                  _editingField == null) {
                _startDetailEdit();
              } else {
                _fetchTeklifler();
              }
            },
            const SingleActivator(LogicalKeyboardKey.f6): () {
              if (_selectedRowId != null) {
                final order = _teklifler.firstWhereOrNull(
                  (o) => o.id == _selectedRowId,
                );
                if (order != null) {
                  _showHizliUrunEkleDrawer(order);
                }
              } else {
                MesajYardimcisi.uyariGoster(
                  context,
                  tr('quotes.quick_add.error.select_quote'),
                );
              }
            },
            const SingleActivator(LogicalKeyboardKey.f7): _handlePrint,
            const SingleActivator(LogicalKeyboardKey.f8): () {
              if (_selectedIds.isNotEmpty) {
                _deleteSelectedTeklifler();
              }
            },
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (_editingField != null) {
                setState(() {
                  _editingField = null;
                  _editingIndex = null;
                  _editingQuoteId = null;
                });
              }
            },
            const SingleActivator(LogicalKeyboardKey.f9): () {
              if (_selectedRowId != null) {
                final order = _teklifler.firstWhereOrNull(
                  (o) => o.id == _selectedRowId,
                );
                if (order != null) {
                  _teklifDonustur(order);
                }
              }
            },
            const SingleActivator(LogicalKeyboardKey.delete): () {
              if (_selectedDetailProductId != null &&
                  _selectedDetailTeklif != null) {
                final item = _selectedDetailTeklif!.urunler.firstWhereOrNull(
                  (u) => u.id == _selectedDetailProductId,
                );
                if (item != null) {
                  _deleteTeklifItem(_selectedDetailTeklif!, item);
                }
              } else if (_selectedRowId != null) {
                final order = _teklifler.firstWhereOrNull(
                  (o) => o.id == _selectedRowId,
                );
                if (order != null) {
                  _teklifSil(order);
                }
              }
            },
          },
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool forceMobile =
                      ResponsiveYardimcisi.tabletMi(context);
                  if (forceMobile || constraints.maxWidth < 1000) {
                    return _buildMobileView();
                  }
                  return _buildDesktopView();
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

  int _getActiveMobileFilterCount() {
    int count = 0;
    if (_startDate != null || _endDate != null) count++;
    if (_selectedStatus != null) count++;
    if (_selectedType != null) count++;
    if (_selectedWarehouse != null) count++;
    if (_selectedUnit != null) count++;
    if (_selectedAccount != null) count++;
    if (_selectedUser != null) count++;
    return count;
  }

  Widget _buildMobileView() {
    final mediaQuery = MediaQuery.of(context);
    final bool isKeyboardVisible = mediaQuery.viewInsets.bottom > 0;

    final int safeRowsPerPage = _rowsPerPage <= 0 ? 25 : _rowsPerPage;
    final int totalPages = _totalRecords == 0
        ? 1
        : (_totalRecords / safeRowsPerPage).ceil();
    final int currentPage = _currentPage.clamp(1, totalPages);

    if (currentPage != _currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _currentPage = currentPage);
      });
    }

    final int showingStart = _totalRecords == 0
        ? 0
        : ((currentPage - 1) * safeRowsPerPage) + 1;
    final int showingEnd = _totalRecords == 0
        ? 0
        : (((currentPage - 1) * safeRowsPerPage) + _teklifler.length).clamp(
            0,
            _totalRecords,
          );

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        _closeOverlay();
      },
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('nav.orders_quotes.quotes'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _buildMobileToolbarCard(),
            ),
            if (!isKeyboardVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildMobileTopActionRow(),
              ),
            Expanded(
              child: _teklifler.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 54,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            tr('common.no_records_found'),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _teklifler.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _buildMobileQuoteCard(_teklifler[index]),
                    ),
            ),
            if (!isKeyboardVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: currentPage > 1
                          ? () =>
                                _onPageChanged(currentPage - 1, safeRowsPerPage)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        tr('common.pagination.showing')
                            .replaceAll('{start}', showingStart.toString())
                            .replaceAll('{end}', showingEnd.toString())
                            .replaceAll('{total}', _totalRecords.toString()),
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
                      onPressed: currentPage < totalPages
                          ? () =>
                                _onPageChanged(currentPage + 1, safeRowsPerPage)
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

  Widget _buildMobileToolbarCard() {
    final int activeFilterCount = _getActiveMobileFilterCount();

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
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C3E50).withValues(alpha: 0.08),
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
                          '$_totalRecords kayıt',
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
                    _isMobileToolbarExpanded
                        ? 'Filtreleri Gizle'
                        : 'Filtreleri Göster',
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
                      Padding(
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
                                          _currentPage = 1;
                                        });
                                        _fetchTeklifler();
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _mobileSearchController,
                                    focusNode: _searchFocusNode,
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: _onSearch,
                                    onChanged: (value) {
                                      if (mounted) setState(() {});
                                      if (value.trim().isEmpty) {
                                        _onSearch('');
                                      }
                                    },
                                    decoration: InputDecoration(
                                      hintText: tr('common.search'),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        color: Colors.grey,
                                      ),
                                      suffixIcon:
                                          _mobileSearchController.text.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: tr('common.clear'),
                                              onPressed: () {
                                                _mobileSearchController.clear();
                                                _onSearch('');
                                              },
                                              icon: const Icon(
                                                Icons.close,
                                                size: 18,
                                              ),
                                            ),
                                      border: const UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      enabledBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
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
                            if (_selectedIds.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: GestureDetector(
                                    onTap: _deleteSelectedTeklifler,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEA4335),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        tr('common.delete_selected').replaceAll(
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
                            const SizedBox(height: 12),
                            _buildMobileFilterGrid(),
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

  Widget _buildMobileFilterGrid() {
    final filters = <Widget>[
      _buildDateRangeFilter(width: double.infinity),
      _buildStatusFilter(width: double.infinity),
      _buildTypeFilter(width: double.infinity),
      _buildWarehouseFilter(width: double.infinity),
      _buildUnitFilter(width: double.infinity),
      _buildAccountFilter(width: double.infinity),
      _buildUserFilter(width: double.infinity),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: List.generate(filters.length * 2 - 1, (index) {
              if (index.isOdd) return const SizedBox(height: 12);
              return filters[index ~/ 2];
            }),
          );
        }

        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: filters
              .map((filter) => SizedBox(width: itemWidth, child: filter))
              .toList(),
        );
      },
    );
  }

  Widget _buildMobileTopActionRow() {
    final bool isActionEnabled =
        _selectedRowId != null || _selectedIds.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: _buildMobileActionButton(
            label: tr('quotes.create'),
            icon: Icons.add,
            color: const Color(0xFFEA4335),
            textColor: Colors.white,
            borderColor: Colors.transparent,
            onTap: _teklifOlustur,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMobileActionButton(
            label: tr('quotes.sell_quote'),
            icon: Icons.bolt_rounded,
            color: const Color(0xFFF39C12),
            textColor: Colors.white,
            borderColor: Colors.transparent,
            onTap: _topluTeklifOnayla,
            enabled: isActionEnabled,
          ),
        ),
        const SizedBox(width: 8),
        _buildMobileSquareActionButton(
          icon: Icons.print_outlined,
          onTap: _handlePrint,
          color: const Color(0xFFF8F9FA),
          iconColor: Colors.black87,
          borderColor: Colors.grey.shade300,
          tooltip:
              _selectedIds.isNotEmpty ||
                  _selectedDetailIds.values.any((s) => s.isNotEmpty)
              ? tr('common.print_selected')
              : tr('common.print_list'),
          size: 40,
        ),
      ],
    );
  }

  Widget _buildMobileActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required Color borderColor,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final Color effectiveColor = enabled
        ? color
        : color.withValues(alpha: 0.45);
    final Color effectiveTextColor = enabled
        ? textColor
        : textColor.withValues(alpha: 0.7);

    return Material(
      color: effectiveColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: effectiveTextColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: effectiveTextColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
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

  Widget _buildMobileQuoteCard(TeklifModel order) {
    final bool isSelected =
        _selectedRowId == order.id || _selectedIds.contains(order.id);
    final bool isExpanded = _mobileExpandedQuoteIds.contains(order.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF2C3E50) : const Color(0xFFE5E7EB),
          width: isSelected ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedRowId = order.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _selectedIds.contains(order.id),
                      onChanged: (val) => _onSelectRow(val, order.id),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: const BorderSide(
                        color: Color(0xFFD1D1D1),
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${tr('quotes.quote_no')} #${order.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF202124),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('products.add'),
                    onPressed: () => _showHizliUrunEkleDrawer(order),
                    icon: const Icon(
                      Icons.add_shopping_cart_rounded,
                      color: Color(0xFF2C3E50),
                      size: 20,
                    ),
                  ),
                  _buildPopupMenu(order),
                ],
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
                      color: IslemTuruRenkleri.getBackgroundColor(order.tur),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      IslemCeviriYardimcisi.cevir(
                        IslemTuruRenkleri.getProfessionalLabel(order.tur),
                      ),
                      style: TextStyle(
                        color: IslemTuruRenkleri.getTextColor(order.tur),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: IslemTuruRenkleri.getBackgroundColor(order.durum),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      IslemCeviriYardimcisi.cevir(
                        IslemTuruRenkleri.getProfessionalLabel(order.durum),
                      ),
                      style: TextStyle(
                        color: IslemTuruRenkleri.getTextColor(order.durum),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildMobileQuoteMeta(
                tr('common.date'),
                DateFormat('dd.MM.yyyy HH:mm').format(order.tarih),
              ),
              const SizedBox(height: 4),
              _buildMobileQuoteMeta(
                tr('common.related_account'),
                order.ilgiliHesapAdi.isEmpty ? '-' : order.ilgiliHesapAdi,
              ),
              const SizedBox(height: 4),
              _buildMobileQuoteMeta(
                tr('common.amount'),
                '${FormatYardimcisi.sayiFormatlaOndalikli(order.tutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${order.paraBirimi}',
                valueColor: order.tutar >= 0
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
              const SizedBox(height: 4),
              _buildMobileQuoteMeta(
                tr('common.rate'),
                FormatYardimcisi.sayiFormatlaOndalikli(
                  order.kur,
                  binlik: _genelAyarlar.binlikAyiraci,
                  ondalik: _genelAyarlar.ondalikAyiraci,
                  decimalDigits: 2,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            _mobileExpandedQuoteIds.remove(order.id);
                          } else {
                            _mobileExpandedQuoteIds.add(order.id);
                          }
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2C3E50),
                        side: BorderSide(color: Colors.grey.shade300),
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                      ),
                      label: Text(
                        tr('quotes.products_in_quote'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _teklifDonustur(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF39C12),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.bolt, size: 16),
                      label: Text(
                        tr('quotes.sell_quote'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: !isExpanded
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _buildMobileQuoteProducts(order),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileQuoteMeta(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF202124),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileQuoteProducts(TeklifModel order) {
    if (order.urunler.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          tr('common.no_records_found'),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: order.urunler.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final item = order.urunler[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.urunAdi,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.urunKodu} • ${item.depoAdi}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tr('common.quantity')}: ${FormatYardimcisi.sayiFormatlaOndalikli(item.miktar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.miktarOndalik)} ${item.birim}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${tr('common.total')}: ${FormatYardimcisi.sayiFormatlaOndalikli(item.toplamFiyati, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${order.paraBirimi}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2C3E50),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr('common.delete'),
                  onPressed: () => _deleteTeklifItem(order, item),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red.shade400,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopView() {
    final bool allSelected =
        _isSelectAllActive ||
        (_teklifler.isNotEmpty &&
            _teklifler.every((u) => _selectedIds.contains(u.id)));

    return GenisletilebilirTablo<TeklifModel>(
      title: tr('nav.orders_quotes.quotes'),
      searchFocusNode: _searchFocusNode,
      onClearSelection: () {
        setState(() {
          _selectedRowId = null;
          _selectedIds.clear();
          _isSelectAllActive = false;
        });
      },
      onFocusedRowChanged: (item, index) {
        if (item != null) setState(() => _selectedRowId = item.id);
      },
      headerWidget: _buildFilters(),
      totalRecords: _totalRecords,
      onSort: _onSort,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      onPageChanged: _onPageChanged,
      onSearch: _onSearch,
      selectionWidget: _selectedIds.isNotEmpty
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _deleteSelectedTeklifler,
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
      expandedIndices: _autoExpandedIndices,
      headerMaxLines: 1,
      headerTextStyle: const TextStyle(fontSize: 14),
      headerPadding: const EdgeInsets.symmetric(horizontal: 8),
      onExpansionChanged: (index, isExpanded) {
        setState(() {
          if (isExpanded) {
            _autoExpandedIndices.add(index);
          } else {
            _autoExpandedIndices.remove(index);
          }
        });
      },
      actionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPrintButton(),
          const SizedBox(width: 12),
          _buildActionsButton(),
          const SizedBox(width: 12),
          _buildteklifOlusturButton(),
        ],
      ),
      extraWidgets: [
        _buildKeepDetailsOpenToggle(),
        const SizedBox(width: 8),
        if (_columnVisibility.isNotEmpty) _buildColumnSettingsButton(),
      ],
      columns: _buildColumns(allSelected),
      data: _teklifler,
      isRowSelected: (order, index) => _selectedRowId == order.id,
      expandOnRowTap: false,
      onRowTap: (order) {
        setState(() {
          _selectedRowId = order.id;
        });
      },
      rowBuilder: (context, order, index, isExpanded, toggleExpand) {
        return _buildRow(order, index, isExpanded, toggleExpand);
      },
      getDetailItemCount: (order) => order.urunler.length,
      detailBuilder: (context, order) => _buildDetailView(order),
    );
  }

  List<GenisletilebilirTabloKolon> _buildColumns(bool allSelected) {
    return [
      GenisletilebilirTabloKolon(
        label: '',
        width: 40,
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
          label: tr('common.order_no'),
          width: 0,
          flex: 3,
          allowSorting: true,
        ),
      if (_columnVisibility['type'] == true)
        GenisletilebilirTabloKolon(
          label: tr('common.type'),
          width: 0,
          flex: 2,
          allowSorting: true,
        ),
      if (_columnVisibility['status'] == true)
        GenisletilebilirTabloKolon(
          label: tr('common.status'),
          width: 0,
          flex: 4,
          allowSorting: true,
        ),
      if (_columnVisibility['date'] == true)
        GenisletilebilirTabloKolon(
          label: tr('common.date'),
          width: 0,
          flex: 3,
          allowSorting: true,
        ),
      if (_columnVisibility['related_account'] == true)
        GenisletilebilirTabloKolon(
          label: tr('common.related_account'),
          width: 0,
          flex: 8,
          allowSorting: true,
        ),
      if (_columnVisibility['amount'] == true)
        GenisletilebilirTabloKolon(
          label: tr('common.amount'),
          width: 0,
          flex: 3,
          alignment: Alignment.centerRight,
          allowSorting: true,
        ),
      if (_columnVisibility['rate'] == true)
        GenisletilebilirTabloKolon(
          label: tr('common.rate'),
          width: 0,
          flex: 2,
          alignment: Alignment.centerRight,
          allowSorting: true,
        ),
      if (_columnVisibility['description'] == true)
        GenisletilebilirTabloKolon(
          label: tr('common.description'),
          width: 0,
          flex: 3,
          allowSorting: true,
        ),
      if (_columnVisibility['description2'] == true)
        GenisletilebilirTabloKolon(
          label: tr('common.description2'),
          width: 0,
          flex: 5,
          allowSorting: true,
        ),
      if (_columnVisibility['validity_date'] == true)
        GenisletilebilirTabloKolon(
          label: tr('common.validity_date_short'),
          width: 0,
          flex: 3,
          allowSorting: true,
        ),
      if (_columnVisibility['user'] == true)
        GenisletilebilirTabloKolon(
          label: tr('common.user'),
          width: 0,
          flex: 3,
          allowSorting: true,
        ),
      GenisletilebilirTabloKolon(
        label: tr('common.actions'),
        width: 120,
        alignment: Alignment.centerLeft,
      ),
    ];
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
          if (entry.value.isNotEmpty) mainRowIdsToProcess.add(entry.key);
        }
      }

      // Filter data based on selection
      final dataToProcess = mainRowIdsToProcess.isNotEmpty
          ? _teklifler.where((u) => mainRowIdsToProcess.contains(u.id)).toList()
          : _teklifler;

      for (var i = 0; i < dataToProcess.length; i++) {
        final order = dataToProcess[i];

        // Determine if row is expanded
        final isExpanded = _keepDetailsOpen || _autoExpandedIndices.contains(i);

        // SubTable data
        DetailTable? subTable;
        final selectedDetails = _selectedDetailIds[order.id];
        final bool hasSpecificDetailSelection =
            selectedDetails != null && selectedDetails.isNotEmpty;

        if (order.urunler.isNotEmpty) {
          // Determine items to show based on selection
          final itemsToShow = order.urunler.where((u) {
            if (hasSpecificDetailSelection) {
              return selectedDetails.contains(u.id);
            }
            return isExpanded;
          }).toList();

          if (itemsToShow.isNotEmpty) {
            subTable = DetailTable(
              title: tr('quotes.products_in_quote'),
              headers: [
                tr('products.table.code'),
                tr('products.table.name'),
                tr('products.table.barcode'),
                tr('depolar.title'),
                tr('common.vat_rate'),
                tr('common.vat_short'),
                tr('common.quantity'),
                tr('products.table.unit'),
                tr('common.discount_percent_short'),
                tr('products.table.unit_price'),
                tr('common.total_amount'),
              ],
              data: itemsToShow.map((u) {
                return [
                  u.urunKodu,
                  u.urunAdi,
                  u.barkod,
                  u.depoAdi,
                  '%${u.kdvOrani.toInt()}',
                  (u.kdvDurumu.toLowerCase() == 'included' ||
                          u.kdvDurumu.toLowerCase() == 'dahil')
                      ? tr('common.included')
                      : tr('common.excluded'),
                  FormatYardimcisi.sayiFormatlaOndalikli(u.miktar),
                  u.birim,
                  '%${FormatYardimcisi.sayiFormatlaOndalikli(u.iskonto)}',
                  '${FormatYardimcisi.sayiFormatlaOndalikli(u.birimFiyati)} ${order.paraBirimi}',
                  '${FormatYardimcisi.sayiFormatlaOndalikli(u.toplamFiyati)} ${order.paraBirimi}',
                ];
              }).toList(),
            );
          }
        }

        final mainRow = [
          order.id.toString(),
          order.tur,
          order.durum,
          DateFormat('dd.MM.yyyy HH:mm').format(order.tarih),
          order.cariAdi ?? '-',
          '${FormatYardimcisi.sayiFormatlaOndalikli(order.tutar)} ${order.paraBirimi}',
          "${order.kur} ${order.paraBirimi}",
          order.aciklama,
          order.aciklama2,
          order.gecerlilikTarihi != null
              ? DateFormat('dd.MM.yyyy').format(order.gecerlilikTarihi!)
              : '-',
          order.kullanici,
        ];

        // Açıklama ve Açıklama 2'yi genişleyen bölüme taşı
        final details = <String, String>{};
        if (order.aciklama.isNotEmpty) {
          details[tr('common.description')] = order.aciklama;
        }
        if (order.aciklama2.isNotEmpty) {
          details[tr('common.description2')] = order.aciklama2;
        }

        rows.add(
          ExpandableRowData(
            mainRow: mainRow,
            details: details,
            transactions: subTable,
          ),
        );
      }

      if (mounted) setState(() => _isLoading = false);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GenisletilebilirPrintPreviewScreen(
            title: tr('nav.orders_quotes.quotes'),
            headers: [
              tr('quotes.quote_no'),
              tr('common.type'),
              tr('common.status'),
              tr('common.date'),
              tr('common.related_account'),
              tr('common.amount'),
              tr('common.rate'),
              tr('common.description'),
              tr('common.description2'),
              tr('common.validity_date'),
              tr('common.user'),
            ],
            data: rows,
            initialShowDetails:
                _keepDetailsOpen || _autoExpandedIndices.isNotEmpty,
            hideFeaturesCheckbox: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  Widget _buildPrintButton() {
    return MouseRegion(
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
              const Icon(Icons.print_outlined, size: 18, color: Colors.black87),
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
    );
  }

  Widget _buildRow(
    TeklifModel order,
    int index,
    bool isExpanded,
    VoidCallback toggleExpand,
  ) {
    final bool isSelected = _selectedIds.contains(order.id);

    return Row(
      children: [
        _buildCell(
          width: 40,
          alignment: Alignment.center,
          child: SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: isSelected,
              onChanged: (val) => _onSelectRow(val, order.id),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
            ),
          ),
        ),
        if (_columnVisibility['order_no'] == true)
          _buildCell(
            width: 0,
            flex: 3,
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
                const SizedBox(width: 4),
                Expanded(
                  child: HighlightText(
                    text: order.id.toString(),
                    query: _searchQuery,
                    style: const TextStyle(color: Colors.black87, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        if (_columnVisibility['type'] == true)
          _buildCell(
            width: 0,
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: IslemTuruRenkleri.getBackgroundColor(order.tur),
                borderRadius: BorderRadius.circular(4),
              ),
              child: HighlightText(
                text: IslemCeviriYardimcisi.cevir(
                  IslemTuruRenkleri.getProfessionalLabel(order.tur),
                ),
                query: _searchQuery,
                style: TextStyle(
                  color: IslemTuruRenkleri.getTextColor(order.tur),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        if (_columnVisibility['status'] == true)
          _buildCell(
            width: 0,
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: IslemTuruRenkleri.getBackgroundColor(order.durum),
                borderRadius: BorderRadius.circular(4),
              ),
              child: HighlightText(
                text: IslemCeviriYardimcisi.cevir(
                  IslemTuruRenkleri.getProfessionalLabel(order.durum),
                ),
                query: _searchQuery,
                style: TextStyle(
                  color: IslemTuruRenkleri.getTextColor(order.durum),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        if (_columnVisibility['date'] == true)
          _buildCell(
            width: 0,
            flex: 3,
            child: HighlightText(
              text: DateFormat('dd.MM.yyyy HH:mm').format(order.tarih),
              query: _searchQuery,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        if (_columnVisibility['related_account'] == true)
          _buildCell(
            width: 0,
            flex: 8,
            child: HighlightText(
              text: order.ilgiliHesapAdi,
              query: _searchQuery,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        if (_columnVisibility['amount'] == true)
          _buildCell(
            width: 0,
            flex: 3,
            alignment: Alignment.centerRight,
            child: HighlightText(
              text:
                  '${FormatYardimcisi.sayiFormatlaOndalikli(order.tutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${order.paraBirimi}',
              query: _searchQuery,
              style: TextStyle(
                color: order.tutar >= 0
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (_columnVisibility['rate'] == true)
          _buildCell(
            width: 0,
            flex: 2,
            alignment: Alignment.centerRight,
            child: HighlightText(
              text:
                  '${FormatYardimcisi.sayiFormatlaOndalikli(order.kur, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: 2)} TL',
              query: _searchQuery,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        if (_columnVisibility['description'] == true)
          _buildCell(
            width: 0,
            flex: 3,
            child: HighlightText(
              text: order.aciklama,
              query: _searchQuery,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
        if (_columnVisibility['description2'] == true)
          _buildCell(
            width: 0,
            flex: 5,
            child: HighlightText(
              text: order.aciklama2,
              query: _searchQuery,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
        if (_columnVisibility['validity_date'] == true)
          _buildCell(
            width: 0,
            flex: 3,
            child: HighlightText(
              text: order.gecerlilikTarihi != null
                  ? DateFormat('dd.MM.yyyy').format(order.gecerlilikTarihi!)
                  : '-',
              query: _searchQuery,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        if (_columnVisibility['user'] == true)
          _buildCell(
            width: 0,
            flex: 3,
            child: HighlightText(
              text: order.kullanici,
              query: _searchQuery,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        _buildCell(width: 120, child: _buildPopupMenu(order)),
      ],
    );
  }

  Widget _buildCell({
    required double width,
    int? flex,
    required Widget child,
    Alignment alignment = Alignment.centerLeft,
  }) {
    Widget content = Container(
      width: width > 0 ? width : null,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: alignment,
      child: child,
    );
    if (flex != null) return Expanded(flex: flex, child: content);
    return content;
  }

  Widget _buildDetailView(TeklifModel order) {
    final selectedIds = _selectedDetailIds[order.id] ?? {};
    final visibleIds = _visibleProductIds[order.id] ?? [];
    final allSelected =
        visibleIds.isNotEmpty && selectedIds.length == visibleIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: allSelected,
                  onChanged: (val) => _onSelectAllDetails(order.id, val),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
                ),
              ),
              const SizedBox(width: 16),
              _buildDetailHeaderRow(tr('quotes.products_in_quote')),
              const Spacer(),
              _buildAddProductButton(order),
            ],
          ),
          const SizedBox(height: 8),
          _buildProductsSubTable(order),
        ],
      ),
    );
  }

  Widget _buildDetailHeaderRow(String title) {
    return Row(
      children: [
        const Icon(
          Icons.shopping_cart_outlined,
          size: 20,
          color: Color(0xFF2C3E50),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsSubTable(TeklifModel order) {
    // Update visible IDs for "Select All" logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final ids = order.urunler.map((u) => u.id).toList();
        if (!const ListEquality().equals(_visibleProductIds[order.id], ids)) {
          setState(() {
            _visibleProductIds[order.id] = ids;
          });
        }
      }
    });

    final focusScope = TableDetailFocusScope.of(context);
    final int? focusedIdx = focusScope?.focusedDetailIndex;

    return Column(
      children: [
        _buildSubTableHeader(),
        ...order.urunler.asMap().entries.map((entry) {
          final int i = entry.key;
          final u = entry.value;
          final isSelected =
              _selectedDetailIds[order.id]?.contains(u.id) ?? false;
          final isLibraryFocused = focusedIdx == i;

          return Column(
            children: [
              _buildSubTableRow(
                order,
                u,
                isSelected,
                isLibraryFocused: isLibraryFocused,
              ),
              if (u != order.urunler.last)
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

  Widget _buildSubTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 44,
          ), // Satırdaki checkbox alanı ile hizalama (12+20+12)
          if (_columnVisibility['dt_code'] == true)
            _buildDetailHeader(tr('products.table.code'), flex: 4),
          if (_columnVisibility['dt_name'] == true) ...[
            const SizedBox(width: 12),
            _buildDetailHeader(tr('products.table.name'), flex: 10),
          ],
          if (_columnVisibility['dt_barcode'] == true) ...[
            const SizedBox(width: 12),
            _buildDetailHeader(tr('products.table.barcode'), flex: 6),
          ],
          if (_columnVisibility['dt_warehouse'] == true) ...[
            const SizedBox(width: 12),
            _buildDetailHeader(tr('depolar.title'), flex: 6),
          ],
          if (_columnVisibility['dt_vat_rate'] == true) ...[
            const SizedBox(width: 12),
            _buildDetailHeader(tr('common.vat_rate'), flex: 3),
          ],
          if (_columnVisibility['dt_vat'] == true) ...[
            const SizedBox(width: 12),
            _buildDetailHeader(tr('common.vat_short'), flex: 5),
          ],
          if (_columnVisibility['dt_quantity'] == true) ...[
            const SizedBox(width: 12),
            _buildDetailHeader(
              tr('common.quantity'),
              flex: 6,
              alignRight: true,
            ),
          ],
          if (_columnVisibility['dt_unit'] == true) ...[
            const SizedBox(width: 12),
            _buildDetailHeader(tr('products.table.unit'), flex: 4),
          ],
          if (_columnVisibility['dt_discount'] == true) ...[
            const SizedBox(width: 12),
            _buildDetailHeader(
              tr('common.discount_percent_short'),
              flex: 5,
              alignRight: true,
            ),
          ],
          if (_columnVisibility['dt_unit_price'] == true) ...[
            const SizedBox(width: 12),
            _buildDetailHeader(
              tr('products.table.unit_price'),
              flex: 8,
              alignRight: true,
            ),
          ],
          if (_columnVisibility['dt_total_amount'] == true) ...[
            const SizedBox(width: 12),
            _buildDetailHeader(
              tr('common.total_amount'),
              flex: 9,
              alignRight: true,
            ),
          ],
          const SizedBox(width: 12),
          _buildDetailHeader('', flex: 3, alignRight: true),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(
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

  Widget _buildSubTableRow(
    TeklifModel order,
    TeklifUrunModel u,
    bool isSelected, {
    bool isLibraryFocused = false,
  }) {
    final bool isFocused =
        isLibraryFocused ||
        (_selectedDetailProductId == u.id &&
            _selectedDetailTeklif?.id == order.id);

    // If library focus changed, we should notify the internal state potentially
    // but here we just use it for styling.
    final focusScope = TableDetailFocusScope.of(context);

    // Sync library focus with page state and scroll into view
    if (focusScope != null && isLibraryFocused) {
      if (_selectedDetailProductId != u.id ||
          _selectedDetailTeklif?.id != order.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedDetailProductId = u.id;
              _selectedDetailTeklif = order;
            });
            focusScope.ensureVisibleCallback?.call(context);
          }
        });
      }
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDetailProductId = u.id;
          _selectedDetailTeklif = order;
        });
        // Sinc focus with library
        final index = order.urunler.indexOf(u);
        if (index != -1) {
          focusScope?.setFocusedDetailIndex?.call(index);
        }
      },
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (val) => _onSelectDetailRow(order.id, u.id, val),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
                ),
              ),
            ),
            if (_columnVisibility['dt_code'] == true)
              Expanded(
                flex: 4,
                child: HighlightText(
                  text: u.urunKodu,
                  query: _searchQuery,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  maxLines: 1,
                ),
              ),
            if (_columnVisibility['dt_name'] == true) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 10,
                child: HighlightText(
                  text: u.urunAdi,
                  query: _searchQuery,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                ),
              ),
            ],
            if (_columnVisibility['dt_barcode'] == true) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: HighlightText(
                  text: u.barkod,
                  query: _searchQuery,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  maxLines: 1,
                ),
              ),
            ],
            if (_columnVisibility['dt_warehouse'] == true) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: HighlightText(
                  text: u.depoAdi,
                  query: _searchQuery,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
            if (_columnVisibility['dt_vat_rate'] == true) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: HighlightText(
                  text:
                      '%${FormatYardimcisi.sayiFormatlaOran(u.kdvOrani, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: 2)}',
                  query: _searchQuery,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
            if (_columnVisibility['dt_vat'] == true) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: InkWell(
                  onTap: () {
                    final String current = u.kdvDurumu.toLowerCase();
                    final String next =
                        (current == 'included' || current == 'dahil')
                        ? 'excluded'
                        : 'included';
                    _updateOrderItem(order, u, kdvDurumu: next);
                  },
                  child: HighlightText(
                    text:
                        (u.kdvDurumu.toLowerCase() == 'included' ||
                            u.kdvDurumu.toLowerCase() == 'dahil')
                        ? tr('common.vat_included')
                        : tr('common.vat_excluded'),
                    query: _searchQuery,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
            if (_columnVisibility['dt_quantity'] == true) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildEditableCell(
                    id: u.id,
                    orderId: order.id,
                    field: 'quantity',
                    value: u.miktar,
                    onSubmitted: (val) {
                      _updateOrderItem(order, u, miktar: val);
                    },
                  ),
                ),
              ),
            ],
            if (_columnVisibility['dt_unit'] == true) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: HighlightText(
                  text: u.birim,
                  query: _searchQuery,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
            if (_columnVisibility['dt_discount'] == true) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildEditableCell(
                    id: u.id,
                    orderId: order.id,
                    field: 'discount',
                    value: u.iskonto,
                    prefix: '%',
                    onSubmitted: (val) {
                      _updateOrderItem(order, u, iskonto: val);
                    },
                  ),
                ),
              ),
            ],
            if (_columnVisibility['dt_unit_price'] == true) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 8,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildEditableCell(
                    id: u.id,
                    orderId: order.id,
                    field: 'price',
                    value: u.birimFiyati,
                    onSubmitted: (val) {
                      _updateOrderItem(order, u, birimFiyati: val);
                    },
                  ),
                ),
              ),
            ],
            if (_columnVisibility['dt_total_amount'] == true) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 9,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: HighlightText(
                    text:
                        '${FormatYardimcisi.sayiFormatlaOndalikli(u.toplamFiyati, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${order.paraBirimi}',
                    query: _searchQuery,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2C3E50),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => _deleteTeklifItem(order, u),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
          Expanded(child: _buildTypeFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildWarehouseFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildUnitFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildAccountFilter(width: double.infinity)),
          const SizedBox(width: 24),
          Expanded(child: _buildUserFilter(width: double.infinity)),
        ],
      ),
    );
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
      debugPrint('Depolar yüklenirken hata: $e');
    }
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _isStatusFilterExpanded = false;
        _isTypeFilterExpanded = false;
        _isWarehouseFilterExpanded = false;
        _isUnitFilterExpanded = false;
        _isAccountFilterExpanded = false;
        _isUserFilterExpanded = false;
      });
    }
  }

  void _showStatusOverlay() {
    _closeOverlay();
    setState(() => _isStatusFilterExpanded = true);

    final statuses = (_filterStats['durumlar']?.keys.toList() ?? [])
      ..removeWhere((e) => e.trim().isEmpty)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
                width: 240,
                constraints: const BoxConstraints(maxHeight: 400),
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
                      _buildStatusOption(null, tr('common.all')),
                      ...statuses.map(
                        (s) => _buildStatusOption(
                          s,
                          IslemCeviriYardimcisi.cevir(
                            IslemTuruRenkleri.getProfessionalLabel(s),
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
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _showTypeOverlay() {
    _closeOverlay();
    setState(() => _isTypeFilterExpanded = true);

    final types = (_filterStats['turler']?.keys.toList() ?? [])
      ..removeWhere((e) => e.trim().isEmpty)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
            link: _typeLayerLink,
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTypeOption(null, tr('common.all')),
                      ...types.map(
                        (t) => _buildTypeOption(
                          t,
                          IslemCeviriYardimcisi.cevir(
                            IslemTuruRenkleri.getProfessionalLabel(t),
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
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _showWarehouseOverlay() {
    _closeOverlay();
    setState(() => _isWarehouseFilterExpanded = true);

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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildWarehouseOption(null, tr('common.all')),
                      ..._warehouses.map((w) => _buildWarehouseOption(w, w.ad)),
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

  void _showUnitOverlay() {
    _closeOverlay();
    setState(() => _isUnitFilterExpanded = true);

    final units = (_filterStats['birimler']?.keys.toList() ?? [])
      ..removeWhere((e) => e.trim().isEmpty)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildUnitOption(null, tr('common.all')),
                      ...units.map((u) => _buildUnitOption(u, u)),
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

  void _showAccountOverlay() {
    _closeOverlay();
    setState(() => _isAccountFilterExpanded = true);

    final accounts = (_filterStats['hesaplar']?.keys.toList() ?? [])
      ..removeWhere((e) => e.trim().isEmpty)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
            link: _accountLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 42),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Container(
                width: 280,
                constraints: const BoxConstraints(maxHeight: 400),
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
                      _buildAccountOption(null, tr('common.all')),
                      ...accounts.map((a) => _buildAccountOption(a, a)),
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
    setState(() => _isUserFilterExpanded = true);

    final users = (_filterStats['kullanicilar']?.keys.toList() ?? [])
      ..removeWhere((e) => e.trim().isEmpty)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildUserOption(null, tr('common.all')),
                      ...users.map((u) => _buildUserOption(u, u)),
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

  int _getFacetCount(String facetKey, String valueKey) {
    return _filterStats[facetKey]?[valueKey] ?? 0;
  }

  Widget _buildStatusOption(String? value, String label) {
    final isSelected = _selectedStatus == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : _getFacetCount('durumlar', value);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = value;
          _isStatusFilterExpanded = false;
          _currentPage = 1;
        });
        _closeOverlay();
        _fetchTeklifler();
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

  Widget _buildTypeOption(String? value, String label) {
    final isSelected = _selectedType == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : _getFacetCount('turler', value);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = value;
          _isTypeFilterExpanded = false;
          _currentPage = 1;
        });
        _closeOverlay();
        _fetchTeklifler();
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

  Widget _buildWarehouseOption(DepoModel? value, String label) {
    final isSelected = _selectedWarehouse?.id == value?.id;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : _getFacetCount('depolar', value.id.toString());

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedWarehouse = value;
          _isWarehouseFilterExpanded = false;
          _currentPage = 1;
        });
        _closeOverlay();
        _fetchTeklifler();
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

  Widget _buildUnitOption(String? value, String label) {
    final isSelected = _selectedUnit == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : _getFacetCount('birimler', value);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedUnit = value;
          _isUnitFilterExpanded = false;
          _currentPage = 1;
        });
        _closeOverlay();
        _fetchTeklifler();
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

  Widget _buildAccountOption(String? value, String label) {
    final isSelected = _selectedAccount == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : _getFacetCount('hesaplar', value);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedAccount = value;
          _isAccountFilterExpanded = false;
          _currentPage = 1;
        });
        _closeOverlay();
        _fetchTeklifler();
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

  Widget _buildUserOption(String? value, String label) {
    final isSelected = _selectedUser == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : _getFacetCount('kullanicilar', value);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedUser = value;
          _isUserFilterExpanded = false;
          _currentPage = 1;
        });
        _closeOverlay();
        _fetchTeklifler();
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

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _currentPage = 1;
    });
    _fetchTeklifler();
  }

  Widget _buildDateRangeFilter({double? width}) {
    final hasSelection = _startDate != null || _endDate != null;

    String label = tr('common.date_range_select');
    if (hasSelection) {
      final start = _startDate != null
          ? DateFormat('dd.MM.yyyy').format(_startDate!)
          : '';
      final end = _endDate != null
          ? DateFormat('dd.MM.yyyy').format(_endDate!)
          : '';
      label = '$start - $end';
    }

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
                label,
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
                onTap: _clearDateFilter,
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
                      : IslemCeviriYardimcisi.cevir(
                          IslemTuruRenkleri.getProfessionalLabel(
                            _selectedStatus!,
                          ),
                        ),
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
                      _currentPage = 1;
                    });
                    _fetchTeklifler();
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

  Widget _buildTypeFilter({double? width}) {
    return CompositedTransformTarget(
      link: _typeLayerLink,
      child: InkWell(
        onTap: () {
          if (_isTypeFilterExpanded) {
            _closeOverlay();
          } else {
            _showTypeOverlay();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 200,
          padding: EdgeInsets.fromLTRB(0, 8, 0, _isTypeFilterExpanded ? 7 : 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isTypeFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade300,
                width: _isTypeFilterExpanded ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 20,
                color: _isTypeFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedType == null
                      ? tr('common.type')
                      : IslemCeviriYardimcisi.cevir(
                          IslemTuruRenkleri.getProfessionalLabel(
                            _selectedType!,
                          ),
                        ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isTypeFilterExpanded
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedType != null)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedType = null;
                      _currentPage = 1;
                    });
                    _fetchTeklifler();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isTypeFilterExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: _isTypeFilterExpanded
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
                  _selectedWarehouse?.ad ??
                      tr('products.transaction.warehouse'),
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
                      _currentPage = 1;
                    });
                    _fetchTeklifler();
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
                  _selectedUnit ?? tr('products.table.unit'),
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
                      _currentPage = 1;
                    });
                    _fetchTeklifler();
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

  Widget _buildAccountFilter({double? width}) {
    return CompositedTransformTarget(
      link: _accountLayerLink,
      child: InkWell(
        onTap: () {
          if (_isAccountFilterExpanded) {
            _closeOverlay();
          } else {
            _showAccountOverlay();
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: width ?? 220,
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            _isAccountFilterExpanded ? 7 : 8,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isAccountFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade300,
                width: _isAccountFilterExpanded ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_outline,
                size: 20,
                color: _isAccountFilterExpanded
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedAccount ?? tr('common.account'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isAccountFilterExpanded
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedAccount != null)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedAccount = null;
                      _currentPage = 1;
                    });
                    _fetchTeklifler();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _isAccountFilterExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: _isAccountFilterExpanded
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
                  _selectedUser == null ? tr('common.user') : _selectedUser!,
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
                      _currentPage = 1;
                    });
                    _fetchTeklifler();
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

  Widget _buildActionsButton() {
    final bool isEnabled = _selectedRowId != null || _selectedIds.isNotEmpty;
    final Color buttonColor = const Color(0xFFF39C12);

    return InkWell(
      onTap: isEnabled ? _topluTeklifOnayla : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: buttonColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                tr('quotes.sell_quote'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tr('common.key.f4'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildteklifOlusturButton() {
    return InkWell(
      onTap: _teklifOlustur,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFEA4335),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.add, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              tr('quotes.create'),
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
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeepDetailsOpenToggle() {
    return Tooltip(
      message: tr('quotes.keep_details_open'),
      child: InkWell(
        onTap: () => setState(() => _keepDetailsOpen = !_keepDetailsOpen),
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
            _keepDetailsOpen ? Icons.unfold_less : Icons.unfold_more,
            color: _keepDetailsOpen
                ? const Color(0xFF2C3E50)
                : Colors.grey.shade600,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildColumnSettingsButton() {
    return Tooltip(
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
    );
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
                            tr('common.order_no'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'type',
                            tr('common.type'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'status',
                            tr('common.status'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'date',
                            tr('common.date'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'related_account',
                            tr('common.related_account'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'amount',
                            tr('common.amount'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'rate',
                            tr('common.rate'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'description',
                            tr('common.description'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'description2',
                            tr('common.description2'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'validity_date',
                            tr('common.validity_date_short'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'user',
                            tr('common.user'),
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
                              tr('common.products'),
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
                            'dt_code',
                            tr('products.table.code'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_name',
                            tr('products.table.name'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_barcode',
                            tr('products.table.barcode'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_warehouse',
                            tr('depolar.title'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_vat_rate',
                            tr('common.vat_rate'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_vat',
                            tr('common.vat_short'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_quantity',
                            tr('common.quantity'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_unit',
                            tr('products.table.unit'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_discount',
                            tr('common.discount_percent_short'),
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
                            'dt_total_amount',
                            tr('common.total_amount'),
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

  Widget _buildAddProductButton(TeklifModel order) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showHizliUrunEkleDrawer(order),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF2C3E50), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_shopping_cart,
                size: 16,
                color: Color(0xFF2C3E50),
              ),
              const SizedBox(width: 8),
              Text(
                tr('products.add'),
                style: const TextStyle(
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3E50).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tr('common.key.f6'),
                  style: TextStyle(
                    color: Color(0xFF2C3E50),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHizliUrunEkleDrawer(TeklifModel order) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: tr('common.close'),
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 500,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.zero,
              ),
              child: _QuickProductAddPanel(
                order: order,
                genelAyarlar: _genelAyarlar,
                onSuccess: () {
                  Navigator.pop(context);
                  _fetchTeklifler(force: true, silent: true);
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }

  Widget _buildPopupMenu(TeklifModel order) {
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
        onSelected: (value) {
          if (value == 'edit') {
            _teklifDuzenle(order);
          } else if (value == 'delete') {
            _teklifSil(order);
          }
        },
      ),
    );
  }

  Future<void> _teklifDuzenle(TeklifModel order) async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TeklifEkleSayfasi(tur: widget.tur, initialQuote: order),
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
      _fetchTeklifler();
    }
  }

  void _updateOrderItem(
    TeklifModel order,
    TeklifUrunModel item, {
    double? miktar,
    double? birimFiyati,
    double? iskonto,
    String? kdvDurumu,
  }) async {
    if (_isLoading) return;

    final nMiktar = miktar ?? item.miktar;
    final nBirimFiyati = birimFiyati ?? item.birimFiyati;
    final nIskonto = iskonto ?? item.iskonto;
    final nKdvDurumu = kdvDurumu ?? item.kdvDurumu;

    double araToplam = nMiktar * nBirimFiyati;
    if (nIskonto > 0) {
      araToplam = araToplam * (1 - nIskonto / 100);
    }

    double nToplamFiyati = araToplam;
    // Handle both language variations for robust KDV calculation
    final String kdvStatus = nKdvDurumu.toLowerCase();
    if (kdvStatus == 'excluded' || kdvStatus == 'hariç') {
      nToplamFiyati = araToplam * (1 + item.kdvOrani / 100);
    }

    final List<Map<String, dynamic>> updatedUrunlerJson = order.urunler.map((
      u,
    ) {
      if (u.id == item.id) {
        return {
          'id': u.id, // Preserve item ID
          'urunId': u.urunId,
          'urunKodu': u.urunKodu,
          'urunAdi': u.urunAdi,
          'barkod': u.barkod,
          'depoId': u.depoId,
          'depoAdi': u.depoAdi,
          'kdvOrani': u.kdvOrani,
          'miktar': nMiktar,
          'birim': u.birim,
          'birimFiyati': nBirimFiyati,
          'paraBirimi': u.paraBirimi,
          'kdvDurumu': nKdvDurumu,
          'iskonto': nIskonto,
          'toplamFiyati': nToplamFiyati,
        };
      }
      return {
        'id': u.id, // Preserve item ID
        'urunId': u.urunId,
        'urunKodu': u.urunKodu,
        'urunAdi': u.urunAdi,
        'barkod': u.barkod,
        'depoId': u.depoId,
        'depoAdi': u.depoAdi,
        'kdvOrani': u.kdvOrani,
        'miktar': u.miktar,
        'birim': u.birim,
        'birimFiyati': u.birimFiyati,
        'paraBirimi': u.paraBirimi,
        'kdvDurumu': u.kdvDurumu,
        'iskonto': u.iskonto,
        'toplamFiyati': u.toplamFiyati,
      };
    }).toList();

    double newOrderTotal = 0;
    for (var u in updatedUrunlerJson) {
      newOrderTotal += (u['toplamFiyati'] as num).toDouble();
    }

    setState(() {
      // Optimistic update of local list
      final orderIndex = _teklifler.indexWhere((o) => o.id == order.id);
      if (orderIndex != -1) {
        final List<TeklifUrunModel> newUrunler = updatedUrunlerJson.map((j) {
          return TeklifUrunModel(
            id: j['id'], // Use preserved ID
            urunId: j['urunId'],
            urunKodu: j['urunKodu'],
            urunAdi: j['urunAdi'],
            barkod: j['barkod'],
            depoId: j['depoId'],
            depoAdi: j['depoAdi'],
            kdvOrani: (j['kdvOrani'] as num).toDouble(),
            miktar: (j['miktar'] as num).toDouble(),
            birim: j['birim'],
            birimFiyati: (j['birimFiyati'] as num).toDouble(),
            paraBirimi: j['paraBirimi'],
            kdvDurumu: j['kdvDurumu'],
            iskonto: (j['iskonto'] as num).toDouble(),
            toplamFiyati: (j['toplamFiyati'] as num).toDouble(),
          );
        }).toList();

        final updatedOrder = _teklifler[orderIndex].copyWith(
          tutar: newOrderTotal,
          urunler: newUrunler,
        );
        _teklifler[orderIndex] = updatedOrder;
      }
    });

    try {
      await TekliflerVeritabaniServisi().teklifGuncelle(
        id: order.id,
        tur: order.tur,
        durum: order.durum,
        tarih: order.tarih,
        cariId: order.cariId,
        cariKod: order.cariKod,
        cariAdi: order.cariAdi,
        ilgiliHesapAdi: order.ilgiliHesapAdi,
        tutar: newOrderTotal,
        kur: order.kur,
        aciklama: order.aciklama,
        aciklama2: order.aciklama2,
        gecerlilikTarihi: order.gecerlilikTarihi,
        paraBirimi: order.paraBirimi,
        urunler: updatedUrunlerJson,
      );

      // We already updated _teklifler optimistically.
      // Just fetch the new total count silently to keep sync without losing focus.
      final count = await TekliflerVeritabaniServisi().teklifSayisiGetir(
        aramaTerimi: _searchQuery,
        tur: _selectedType,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        durum: _selectedStatus,
        depoId: _selectedWarehouse?.id,
        birim: _selectedUnit,
        ilgiliHesapAdi: _selectedAccount,
        kullanici: _selectedUser,
      );
      if (mounted) {
        setState(() {
          _totalRecords = count;
        });
      }
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(
          context,
          '${tr('common.error.update_failed')}: $e',
        );
        _fetchTeklifler(
          force: true,
        ); // Revert to correct state if something failed
      }
    }
  }

  void _deleteTeklifItem(TeklifModel order, TeklifUrunModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr(
          'orders.confirm_delete_item',
        ).replaceAll('{product}', item.urunAdi),
        onayButonMetni: tr('common.delete'),
        isDestructive: true,
        onOnay: () async {
          if (_isLoading) return;

          final List<Map<String, dynamic>> updatedUrunlerJson = order.urunler
              .where((u) => u.id != item.id)
              .map((u) {
                return {
                  'id': u.id,
                  'urunId': u.urunId,
                  'urunKodu': u.urunKodu,
                  'urunAdi': u.urunAdi,
                  'barkod': u.barkod,
                  'depoId': u.depoId,
                  'depoAdi': u.depoAdi,
                  'kdvOrani': u.kdvOrani,
                  'miktar': u.miktar,
                  'birim': u.birim,
                  'birimFiyati': u.birimFiyati,
                  'paraBirimi': u.paraBirimi,
                  'kdvDurumu': u.kdvDurumu,
                  'iskonto': u.iskonto,
                  'toplamFiyati': u.toplamFiyati,
                };
              })
              .toList();

          double newOrderTotal = 0;
          for (var u in updatedUrunlerJson) {
            newOrderTotal += (u['toplamFiyati'] as num).toDouble();
          }

          setState(() {
            final orderIndex = _teklifler.indexWhere((o) => o.id == order.id);
            if (orderIndex != -1) {
              final List<TeklifUrunModel> newUrunler = updatedUrunlerJson.map((
                j,
              ) {
                return TeklifUrunModel(
                  id: j['id'],
                  urunId: j['urunId'],
                  urunKodu: j['urunKodu'],
                  urunAdi: j['urunAdi'],
                  barkod: j['barkod'],
                  depoId: j['depoId'],
                  depoAdi: j['depoAdi'],
                  kdvOrani: (j['kdvOrani'] as num).toDouble(),
                  miktar: (j['miktar'] as num).toDouble(),
                  birim: j['birim'],
                  birimFiyati: (j['birimFiyati'] as num).toDouble(),
                  paraBirimi: j['paraBirimi'],
                  kdvDurumu: j['kdvDurumu'],
                  iskonto: (j['iskonto'] as num).toDouble(),
                  toplamFiyati: (j['toplamFiyati'] as num).toDouble(),
                );
              }).toList();

              _teklifler[orderIndex] = _teklifler[orderIndex].copyWith(
                tutar: newOrderTotal,
                urunler: newUrunler,
              );
              // Clear current selection if deleted item was selected
              if (_selectedDetailProductId == item.id) {
                _selectedDetailProductId = null;
                _selectedDetailTeklif = null;
              }
            }
          });

          try {
            await TekliflerVeritabaniServisi().teklifGuncelle(
              id: order.id,
              tur: order.tur,
              durum: order.durum,
              tarih: order.tarih,
              cariId: order.cariId,
              cariKod: order.cariKod,
              cariAdi: order.cariAdi,
              ilgiliHesapAdi: order.ilgiliHesapAdi,
              tutar: newOrderTotal,
              kur: order.kur,
              aciklama: order.aciklama,
              aciklama2: order.aciklama2,
              gecerlilikTarihi: order.gecerlilikTarihi,
              paraBirimi: order.paraBirimi,
              urunler: updatedUrunlerJson,
            );
          } catch (e) {
            if (!mounted) return;
            MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
            _fetchTeklifler(force: true);
          }
        },
      ),
    );
  }

  void _startDetailEdit() {
    if (_selectedDetailProductId == null || _selectedDetailTeklif == null) {
      return;
    }
    setState(() {
      _editingIndex = _selectedDetailProductId;
      _editingQuoteId = _selectedDetailTeklif!.id;
      _editingField = 'quantity';
    });
  }

  void _moveToNextEditField(String current) {
    setState(() {
      if (current == 'quantity') {
        _editingField = 'discount';
      } else if (current == 'discount') {
        _editingField = 'price';
      } else {
        _editingIndex = null;
        _editingQuoteId = null;
        _editingField = null;
      }
    });
  }

  String _fmtPrice(double value) {
    return FormatYardimcisi.sayiFormatlaOndalikli(
      value,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.fiyatOndalik,
    );
  }

  String _fmtQty(double value) {
    return FormatYardimcisi.sayiFormatla(
      value,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.miktarOndalik,
    );
  }

  String _fmtRatio(double value) {
    return FormatYardimcisi.sayiFormatlaOran(
      value,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: 2,
    );
  }

  Widget _buildEditableCell({
    required int id,
    required int orderId,
    required String field,
    required double value,
    required void Function(double) onSubmitted,
    String prefix = '',
  }) {
    final isEditing =
        _editingIndex == id &&
        _editingQuoteId == orderId &&
        _editingField == field;

    int decimals = 2;
    bool isPrice = false;
    if (field == 'price') {
      decimals = _genelAyarlar.fiyatOndalik;
      isPrice = true;
    } else if (field == 'quantity') {
      decimals = _genelAyarlar.miktarOndalik;
    }

    if (isEditing) {
      return _InlineNumberEditor(
        value: value,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: decimals,
        isPrice: isPrice,
        onSubmitted: (val) {
          onSubmitted(val);
          setState(() {
            _editingIndex = null;
            _editingQuoteId = null;
            _editingField = null;
          });
        },
        onNext: (val) {
          onSubmitted(val);
          _moveToNextEditField(field);
        },
        onCancel: () {
          setState(() {
            _editingIndex = null;
            _editingQuoteId = null;
            _editingField = null;
          });
        },
      );
    }

    String formattedValue = '';
    if (field == 'quantity') {
      formattedValue = _fmtQty(value);
    } else if (field == 'discount') {
      formattedValue = _fmtRatio(value);
    } else {
      formattedValue = _fmtPrice(value);
    }

    return InkWell(
      onTap: () {
        if (_isLoading) return;
        setState(() {
          _editingIndex = id;
          _editingQuoteId = orderId;
          _editingField = field;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: isEditing
              ? Colors.transparent
              : Colors.grey.withValues(alpha: 0.03),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit, size: 9),
                  const SizedBox(width: 1),
                  Text(
                    tr('common.key.f5'),
                    style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 3),
            Flexible(
              child: HighlightText(
                text: '$prefix$formattedValue',
                query: _searchQuery,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _teklifDonustur(TeklifModel order) async {
    if (order.durum == tr('quotes.status.converted')) {
      MesajYardimcisi.bilgiGoster(
        context,
        tr('quotes.error.already_converted'),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TeklifDonusturDialog(teklif: order),
    );

    if (result != null) {
      final CariHesapModel? selectedCari = result['cari'];
      final String paraBirimi = result['paraBirimi'];
      final double kur = result['kur'];

      // Ürünleri SaleItem'e dönüştür (Satış sayfası için)
      final List<SaleItem> items = order.urunler.map((u) {
        // Fiyat KDV dahil ise önce KDV'den arındırıyoruz
        double priceWithoutVat = u.birimFiyati;
        final String kdvDurumuStr = u.kdvDurumu.toLowerCase();
        if (kdvDurumuStr == 'dahil' || kdvDurumuStr == 'included') {
          priceWithoutVat = u.birimFiyati / (1 + u.kdvOrani / 100);
        }

        // Eğer ürünün para birimi hedeflenen para biriminden farklıysa çevrim yap
        double finalPrice = priceWithoutVat;
        if (u.paraBirimi != paraBirimi) {
          if (u.paraBirimi == 'TRY' || u.paraBirimi == 'TL') {
            // TRY -> USD için bölüyoruz (100 TRY / 35 = 2.85 USD)
            finalPrice = priceWithoutVat / kur;
          } else {
            // Diğer durumlar (şimdilik TRY üzerinden geçiş varsayıyoruz veya kur 1 ise doğrudan alıyoruz)
            // Not: Bu kısım daha karmaşık çapraz kur desteği gerekirse güncellenebilir.
          }
        }

        return SaleItem(
          code: u.urunKodu,
          name: u.urunAdi,
          barcode: u.barkod,
          unit: u.birim,
          quantity: u.miktar,
          unitPrice: finalPrice,
          currency: paraBirimi,
          exchangeRate: kur,
          vatRate: u.kdvOrani,
          discountRate: u.iskonto,
          warehouseId: u.depoId ?? 0,
          warehouseName: u.depoAdi,
        );
      }).toList();

      // Satış sayfasına sekmede aç
      if (!mounted) return;
      final tabScope = TabAciciScope.of(context);
      if (tabScope != null) {
        tabScope.tabAc(
          menuIndex: 11,
          initialCari: selectedCari,
          initialItems: items,
          initialCurrency: paraBirimi,
          initialDescription: '${tr("quotes.title")} ID: ${order.id}',
          initialOrderRef: order.id.toString(),
          quoteRef: order.id,
          initialRate: kur,
        );

        _fetchTeklifler(force: true);
        return;
      }

      // Tab sistemi bulunamazsa fallback (eski yapı)
      final conversionResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => SatisYapSayfasi(
            initialCari: selectedCari,
            quoteRef: order.id,
            initialItems: items,
            initialCurrency: paraBirimi,
            initialDescription: '${tr("quotes.title")} ID: ${order.id}',
            initialRate: kur,
          ),
        ),
      );

      // Eğer satış tamamlandıysa teklifi "Satış Yapıldı" durumuna getir
      if (conversionResult == true) {
        final servis = TekliflerVeritabaniServisi();
        final success = await servis.teklifDurumGuncelle(
          order.id,
          tr('quotes.status.converted'),
        );

        if (success) {
          _fetchTeklifler(force: true);
          if (mounted) {
            MesajYardimcisi.basariGoster(context, tr('quotes.convert_success'));
          }
        }
      }
    }
  }

  Future<void> _topluTeklifOnayla() async {
    if (_selectedIds.isEmpty) {
      if (_selectedRowId != null) {
        final order = _teklifler.firstWhereOrNull(
          (o) => o.id == _selectedRowId,
        );
        if (order != null) {
          _teklifDonustur(order);
          return;
        }
      }
      MesajYardimcisi.uyariGoster(
        context,
        tr('quotes.error.select_quote_for_action'),
      );
      return;
    }

    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr(
          'quotes.confirm_bulk_approve',
        ).replaceAll('{count}', _selectedIds.length.toString()),
        onayButonMetni: tr('quotes.sell_quote'),
        onOnay: () {},
      ),
    );

    if (onay == true) {
      setState(() => _isLoading = true);
      try {
        final servis = TekliflerVeritabaniServisi();
        int basariliSayisi = 0;

        for (final id in _selectedIds) {
          final order = _teklifler.firstWhereOrNull((o) => o.id == id);
          if (order == null) {
            continue;
          }
          if (order.durum == 'Onaylandı') {
            continue;
          }

          bool basarili = false;
          if (order.tur.contains('Teklif')) {
            final yeniTur = order.tur.replaceAll('Teklif', 'Sipariş');
            basarili = await servis.teklifTurVeDurumGuncelle(
              order.id,
              yeniTur,
              'Onaylandı',
            );
          } else {
            basarili = await servis.teklifDurumGuncelle(order.id, 'Onaylandı');
          }
          if (basarili) {
            basariliSayisi++;
          }
        }

        if (mounted) {
          MesajYardimcisi.basariGoster(
            context,
            tr(
              'quotes.bulk_approve.success',
            ).replaceAll('{count}', basariliSayisi.toString()),
          );
          _selectedIds.clear();
          _fetchTeklifler(force: true);
        }
      } catch (e) {
        if (mounted) {
          MesajYardimcisi.hataGoster(
            context,
            '${tr('common.error.bulk_action_failed')}: $e',
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteSelectedTeklifler() async {
    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr(
          'quotes.confirm_bulk_delete',
        ).replaceAll('{count}', _selectedIds.length.toString()),
        onayButonMetni: tr('common.delete'),
        isDestructive: true,
        onOnay: () {},
      ),
    );

    if (onay == true) {
      setState(() => _isLoading = true);
      try {
        final servis = TekliflerVeritabaniServisi();
        for (final id in _selectedIds) {
          await servis.teklifSil(id);
        }
        if (mounted) {
          MesajYardimcisi.basariGoster(
            context,
            tr('common.deleted_successfully'),
          );
          setState(() {
            _selectedIds.clear();
            _selectedDetailIds.clear();
            _selectedDetailProductId = null;
            _selectedDetailTeklif = null;
            _isSelectAllActive = false;
          });
          _fetchTeklifler(force: true);
        }
      } catch (e) {
        if (mounted) {
          MesajYardimcisi.hataGoster(
            context,
            '${tr('common.error.delete_failed')}: $e',
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}

class _InlineNumberEditor extends StatefulWidget {
  final double value;
  final String binlik;
  final String ondalik;
  final int decimalDigits;
  final void Function(double) onSubmitted;
  final void Function(double)? onNext;
  final VoidCallback? onCancel;

  const _InlineNumberEditor({
    required this.value,
    required this.onSubmitted,
    required this.binlik,
    required this.ondalik,
    required this.decimalDigits,
    this.isPrice = false,
    this.onNext,
    this.onCancel,
  });

  final bool isPrice;

  @override
  State<_InlineNumberEditor> createState() => _InlineNumberEditorState();
}

class _InlineNumberEditorState extends State<_InlineNumberEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    String initialText;
    if (widget.isPrice) {
      initialText = FormatYardimcisi.sayiFormatlaOndalikli(
        widget.value,
        binlik: widget.binlik,
        ondalik: widget.ondalik,
        decimalDigits: widget.decimalDigits,
      );
    } else {
      initialText = FormatYardimcisi.sayiFormatla(
        widget.value,
        binlik: widget.binlik,
        ondalik: widget.ondalik,
        decimalDigits: widget.decimalDigits,
      );
    }
    _controller = TextEditingController(text: initialText);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    _focusNode.requestFocus();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && !_isSaving) {
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
    if (_isSaving) return;
    _isSaving = true;

    final newValue = FormatYardimcisi.parseDouble(
      _controller.text,
      binlik: widget.binlik,
      ondalik: widget.ondalik,
    );
    widget.onSubmitted(newValue);
  }

  void _saveNext() {
    if (_isSaving) return;
    _isSaving = true;

    final newValue = FormatYardimcisi.parseDouble(
      _controller.text,
      binlik: widget.binlik,
      ondalik: widget.ondalik,
    );
    if (widget.onNext != null) {
      widget.onNext!(newValue);
    } else {
      widget.onSubmitted(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2C3E50);
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            _save();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.f5 ||
              event.logicalKey == LogicalKeyboardKey.tab) {
            _saveNext();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _isSaving = true; // Prevent save on focus loss
            widget.onCancel?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        width: 80,
        height: 40,
        child: TextFormField(
          controller: _controller,
          focusNode: _focusNode,
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
          onFieldSubmitted: (_) => _save(),
        ),
      ),
    );
  }
}

class _QuickProductAddPanel extends StatefulWidget {
  final TeklifModel order;
  final GenelAyarlarModel genelAyarlar;
  final VoidCallback onSuccess;

  const _QuickProductAddPanel({
    required this.order,
    required this.genelAyarlar,
    required this.onSuccess,
  });

  @override
  State<_QuickProductAddPanel> createState() => _QuickProductAddPanelState();
}

class _QuickProductAddPanelState extends State<_QuickProductAddPanel> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _urunKodController = TextEditingController();
  final _urunAdiController = TextEditingController();
  final _birimFiyatiController = TextEditingController();
  final _miktarController = TextEditingController();
  final _iskontoController = TextEditingController();
  final _birimController = TextEditingController();

  final FocusNode _urunKodFocusNode = FocusNode();
  final FocusNode _urunAdiFocusNode = FocusNode();
  final FocusNode _miktarFocusNode = FocusNode();
  final FocusNode _birimFiyatiFocusNode = FocusNode();
  Timer? _searchDebounce;

  UrunModel? _selectedUrun;
  List<UrunModel> _lastOptions = [];
  int _highlightedIndex = -1;
  String _selectedParaBirimi = 'TRY';
  String _selectedKdvDurumu = 'excluded';
  double _kdvOrani = 0;

  List<DepoModel> _depolar = [];
  DepoModel? _selectedDepo;

  static const Color _primaryColor = Color(0xFF2C3E50);
  static const Color _textColor = Color(0xFF202124);

  @override
  void initState() {
    super.initState();
    _selectedParaBirimi = widget.order.paraBirimi;
    _selectedKdvDurumu = widget.genelAyarlar.varsayilanKdvDurumu;
    _attachPriceFormatter(_birimFiyatiFocusNode, _birimFiyatiController);
    _loadDepolar();
  }

  Future<void> _loadDepolar() async {
    try {
      final results = await DepolarVeritabaniServisi().depolariGetir();
      if (mounted) {
        setState(() {
          _depolar = results;
          if (_depolar.isNotEmpty) {
            _selectedDepo = _depolar.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Depolar yüklenirken hata: $e');
    }
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
          binlik: widget.genelAyarlar.binlikAyiraci,
          ondalik: widget.genelAyarlar.ondalikAyiraci,
        );
        final formatted = FormatYardimcisi.sayiFormatlaOndalikli(
          value,
          binlik: widget.genelAyarlar.binlikAyiraci,
          ondalik: widget.genelAyarlar.ondalikAyiraci,
          decimalDigits: widget.genelAyarlar.fiyatOndalik,
        );
        controller
          ..text = formatted
          ..selection = TextSelection.collapsed(offset: formatted.length);
      }
    });
  }

  @override
  void dispose() {
    _urunKodController.dispose();
    _urunAdiController.dispose();
    _birimFiyatiController.dispose();
    _miktarController.dispose();
    _iskontoController.dispose();
    _birimController.dispose();
    _urunKodFocusNode.dispose();
    _urunAdiFocusNode.dispose();
    _miktarFocusNode.dispose();
    _birimFiyatiFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Widget _buildProductAutocompleteField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool isRequired,
    required bool isCodeField,
    String? searchHint,
    Widget? suffixIcon,
  }) {
    final effectiveColor = isRequired
        ? Colors.deepOrange.shade700
        : const Color(0xFF2C3E50);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isRequired ? '$label *' : label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: effectiveColor,
                fontSize: 14,
              ),
            ),
            if (isCodeField) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.shade700.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.zero,
                ),
                child: Text(
                  tr('common.key.f3'),
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
            if (searchHint != null) ...[
              const SizedBox(width: 6),
              Text(
                searchHint,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
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

                      final uretimlerAsUrun = uretimler
                          .map(
                            (u) => UrunModel(
                              id: u.id,
                              kod: u.kod,
                              ad: '${u.ad} (Üretim)',
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

                      final combined = [...urunler, ...uretimlerAsUrun];

                      if (mounted) {
                        _lastOptions = combined;
                      }

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
                        borderRadius: BorderRadius.zero,
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
                              final currentHighlight =
                                  AutocompleteHighlightedOption.of(context);

                              // Update tracked highlight index
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted &&
                                    _highlightedIndex != currentHighlight) {
                                  setState(() {
                                    _highlightedIndex = currentHighlight;
                                  });
                                }
                              });

                              final isHighlighted = currentHighlight == index;
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

                              final bool hasStock = option.stok > 0;
                              final Color stockBgColor = hasStock
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE);
                              final Color stockTextColor = hasStock
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828);

                              final Color typeBgColor = isProduction
                                  ? const Color(0xFFFFF3E0)
                                  : const Color(0xFFE3F2FD);
                              final Color typeTextColor = isProduction
                                  ? const Color(0xFFE65100)
                                  : const Color(0xFF1565C0);

                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Container(
                                  color: isHighlighted
                                      ? effectiveColor.withValues(alpha: 0.1)
                                      : Colors.transparent,
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
                                              isProduction ? 'Üretim' : 'Ürün',
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
                                            child: Text(
                                              '${tr('products.table.stock')}: ${FormatYardimcisi.sayiFormatlaOndalikli(option.stok, ondalik: widget.genelAyarlar.ondalikAyiraci, binlik: widget.genelAyarlar.binlikAyiraci, decimalDigits: widget.genelAyarlar.miktarOndalik)}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: stockTextColor,
                                              ),
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
                    void handleEnter() {
                      if (_highlightedIndex == -1 && _lastOptions.isNotEmpty) {
                        _fillProductFields(_lastOptions.first);
                      } else if (_highlightedIndex != -1 &&
                          _highlightedIndex < _lastOptions.length) {
                        _fillProductFields(_lastOptions[_highlightedIndex]);
                      } else {
                        onFieldSubmitted();
                      }
                    }

                    return CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.enter):
                            handleEnter,
                        const SingleActivator(LogicalKeyboardKey.numpadEnter):
                            handleEnter,
                        const SingleActivator(LogicalKeyboardKey.tab): () {
                          focusNode.requestFocus();
                        },
                      },
                      child: TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        style: const TextStyle(fontSize: 17),
                        decoration: InputDecoration(
                          hintText: isCodeField
                              ? tr('common.search_product_hint')
                              : tr('common.selected_product_name'),
                          hintStyle: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.3),
                            fontSize: 16,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_selectedUrun != null)
                                IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey.shade400,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedUrun = null;
                                      _urunKodController.clear();
                                      _urunAdiController.clear();
                                      _birimController.clear();
                                      _birimFiyatiController.clear();
                                      _kdvOrani = 0;
                                    });
                                  },
                                ),
                              suffixIcon ?? const SizedBox.shrink(),
                            ],
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
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
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

  void _fillProductFields(UrunModel p) {
    setState(() {
      _selectedUrun = p;
      _urunKodController.text = p.kod;
      _urunAdiController.text = p.ad;
      _birimController.text = p.birim;
      _birimFiyatiController.text = FormatYardimcisi.sayiFormatlaOndalikli(
        p.satisFiyati1,
        binlik: widget.genelAyarlar.binlikAyiraci,
        ondalik: widget.genelAyarlar.ondalikAyiraci,
        decimalDigits: widget.genelAyarlar.fiyatOndalik,
      );
      _kdvOrani = p.kdvOrani;
    });
    _miktarFocusNode.requestFocus();
  }

  Future<void> _searchUrun() async {
    final selected = await showDialog<UrunModel>(
      context: context,
      builder: (context) => const _ProductSelectionDialog(),
    );

    if (selected != null && mounted) {
      _fillProductFields(selected);
    }
  }

  Future<void> _handleSave() async {
    if (_selectedUrun == null) {
      MesajYardimcisi.uyariGoster(context, tr('quotes.error.product_required'));
      return;
    }

    final miktar = FormatYardimcisi.parseDouble(
      _miktarController.text,
      binlik: widget.genelAyarlar.binlikAyiraci,
      ondalik: widget.genelAyarlar.ondalikAyiraci,
    );

    if (miktar <= 0) {
      MesajYardimcisi.uyariGoster(
        context,
        tr('common.error.enter_valid_amount'),
      );
      return;
    }

    if (_selectedDepo == null) {
      MesajYardimcisi.uyariGoster(context, tr('common.error.select_warehouse'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final birimFiyati = FormatYardimcisi.parseDouble(
        _birimFiyatiController.text,
        binlik: widget.genelAyarlar.binlikAyiraci,
        ondalik: widget.genelAyarlar.ondalikAyiraci,
      );

      final iskonto = FormatYardimcisi.parseDouble(
        _iskontoController.text,
        binlik: widget.genelAyarlar.binlikAyiraci,
        ondalik: widget.genelAyarlar.ondalikAyiraci,
      );

      double araToplam = miktar * birimFiyati;
      if (iskonto > 0) {
        araToplam = araToplam * (1 - iskonto / 100);
      }

      double toplamFiyati = araToplam;
      final String kdvStatus = _selectedKdvDurumu.toLowerCase();
      if (kdvStatus == 'excluded' || kdvStatus == 'hariç') {
        toplamFiyati = araToplam * (1 + _kdvOrani / 100);
      }

      // Mevcut ürünleri al
      final List<Map<String, dynamic>> yeniUrunler = widget.order.urunler.map((
        u,
      ) {
        return {
          'urunId': u.urunId,
          'urunKodu': u.urunKodu,
          'urunAdi': u.urunAdi,
          'barkod': u.barkod,
          'depoId': u.depoId,
          'depoAdi': u.depoAdi,
          'kdvOrani': u.kdvOrani,
          'miktar': u.miktar,
          'birim': u.birim,
          'birimFiyati': u.birimFiyati,
          'paraBirimi': u.paraBirimi,
          'kdvDurumu': u.kdvDurumu,
          'iskonto': u.iskonto,
          'toplamFiyati': u.toplamFiyati,
        };
      }).toList();

      // Yeni ürünü ekle
      yeniUrunler.add({
        'urunId': _selectedUrun!.id,
        'urunKodu': _selectedUrun!.kod,
        'urunAdi': _selectedUrun!.ad,
        'barkod': _selectedUrun!.barkod,
        'depoId': _selectedDepo!.id,
        'depoAdi': _selectedDepo!.ad,
        'kdvOrani': _kdvOrani,
        'miktar': miktar,
        'birim': _birimController.text.isNotEmpty
            ? _birimController.text
            : _selectedUrun!.birim,
        'birimFiyati': birimFiyati,
        'paraBirimi': _selectedParaBirimi,
        'kdvDurumu': _selectedKdvDurumu,
        'iskonto': iskonto,
        'toplamFiyati': toplamFiyati,
      });

      // Toplam tutarı hesapla
      double yeniToplam = 0;
      for (final u in yeniUrunler) {
        yeniToplam += (u['toplamFiyati'] as num).toDouble();
      }

      // Güncelle
      await TekliflerVeritabaniServisi().teklifGuncelle(
        id: widget.order.id,
        tur: widget.order.tur,
        durum: widget.order.durum,
        tarih: widget.order.tarih,
        cariId: widget.order.cariId,
        cariKod: widget.order.cariKod,
        cariAdi: widget.order.cariAdi,
        ilgiliHesapAdi: widget.order.ilgiliHesapAdi,
        tutar: yeniToplam,
        kur: widget.order.kur,
        aciklama: widget.order.aciklama,
        aciklama2: widget.order.aciklama2,
        gecerlilikTarihi: widget.order.gecerlilikTarihi,
        paraBirimi: widget.order.paraBirimi,
        urunler: yeniUrunler,
      );

      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.f3) {
            _searchUrun();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            _handleSave();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: const Icon(
                    Icons.add_shopping_cart,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('orders.quick_add.title'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      Text(
                        tr('orders.quick_add.subtitle'),
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 0: Depo Seçimi
                    _buildDropdown<DepoModel>(
                      value: _selectedDepo,
                      label: tr('common.warehouse_selection'),
                      items: _depolar,
                      itemLabel: (d) => d.ad,
                      onChanged: (val) => setState(() => _selectedDepo = val),
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    // Row 1: Ürün Bul
                    _buildProductAutocompleteField(
                      controller: _urunKodController,
                      focusNode: _urunKodFocusNode,
                      label: tr('quotes.field.find_product'),
                      searchHint: tr('common.search_fields.code_name_barcode'),
                      isRequired: true,
                      isCodeField: true,
                      suffixIcon: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _searchUrun,
                          child: const Icon(
                            Icons.search,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Row 2: Ürün Adı
                    _buildProductAutocompleteField(
                      controller: _urunAdiController,
                      focusNode: _urunAdiFocusNode,
                      label: tr('products.table.name'),
                      searchHint: tr('common.search_fields.name_code'),
                      isRequired: true,
                      isCodeField: false,
                      suffixIcon: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _searchUrun,
                          child: const Icon(
                            Icons.search,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Row 3: Birim Fiyatı
                    _buildTextField(
                      controller: _birimFiyatiController,
                      focusNode: _birimFiyatiFocusNode,
                      label: tr('common.unit_price'),
                      isNumeric: true,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    // Row 4: Para Birimi & KDV Durumu
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown<String>(
                            value: _selectedParaBirimi,
                            label: tr('common.currency'),
                            items: widget.genelAyarlar.kullanilanParaBirimleri,
                            itemLabel: (s) => s,
                            onChanged: (val) =>
                                setState(() => _selectedParaBirimi = val!),
                            isRequired: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdown<String>(
                            value: _selectedKdvDurumu,
                            label: tr('common.vat_status'),
                            items: const ['included', 'excluded'],
                            itemLabel: (s) => s == 'included'
                                ? tr('common.vat_included')
                                : tr('common.vat_excluded'),
                            onChanged: (val) =>
                                setState(() => _selectedKdvDurumu = val!),
                            isRequired: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Row 5: Miktar & Birim
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _miktarController,
                            focusNode: _miktarFocusNode,
                            label: tr('common.quantity'),
                            isNumeric: true,
                            isRequired: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _birimController,
                            label: tr('common.unit'),
                            readOnly: true,
                            isRequired: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Row 6: İskonto %
                    _buildTextField(
                      controller: _iskontoController,
                      label: tr('sale.field.discount_rate'),
                      isNumeric: true,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: Text(
                      tr('common.close'),
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            tr('orders.quick_add.add_button'),
                            style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumeric = false,
    bool isRequired = false,
    String? hint,
    FocusNode? focusNode,
    bool readOnly = false,
    Widget? suffix,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Text(
            isRequired ? '$label *' : label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isRequired ? Colors.red.shade700 : _primaryColor,
              fontSize: 13,
            ),
          ),
        if (label.isNotEmpty) const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          inputFormatters: isNumeric
              ? [
                  CurrencyInputFormatter(
                    binlik: widget.genelAyarlar.binlikAyiraci,
                    ondalik: widget.genelAyarlar.ondalikAyiraci,
                  ),
                ]
              : null,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            isDense: true,
            hintStyle: TextStyle(
              color: Colors.grey.withValues(alpha: 0.3),
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFEEEEEE)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isRequired ? Colors.red.shade700 : _primaryColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFEEEEEE)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemLabel(item),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

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
    _searchProducts('');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchProducts(query),
    );
  }

  Future<void> _searchProducts(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
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
        aktifMi: true,
      );

      final resultsList = await Future.wait([urunlerFuture, uretimlerFuture]);
      final urunler = resultsList[0] as List<UrunModel>;
      final uretimler = resultsList[1] as List<UretimModel>;

      final uretimlerAsUrun = uretimler
          .map(
            (u) => UrunModel(
              id: u.id,
              kod: u.kod,
              ad: '${u.ad} (Üretim)',
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

      final combined = [...urunler, ...uretimlerAsUrun];
      // Sort combined list by name
      combined.sort((a, b) => a.ad.compareTo(b.ad));

      if (mounted) {
        setState(() {
          _products = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('productions.recipe.select_product'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('productions.recipe.search_subtitle'),
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
                    IconButton(
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
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
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
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      itemBuilder: (ctx, i) {
                        final p = _products[i];
                        return InkWell(
                          onTap: () => Navigator.pop(context, p),
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
                                      Text(
                                        p.ad,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF202124),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        p.kod,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF606368),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: p.stok > 0
                                        ? const Color(0xFFE6F4EA)
                                        : const Color(0xFFFCE8E6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${p.stok.toStringAsFixed(0)} ${p.birim}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: p.stok > 0
                                          ? const Color(0xFF1E7E34)
                                          : const Color(0xFFC5221F),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F3F4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    p.birim,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4A4A4A),
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
