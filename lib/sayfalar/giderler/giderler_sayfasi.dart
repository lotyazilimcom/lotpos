import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../bilesenler/genisletilebilir_tablo.dart';
import '../../bilesenler/highlight_text.dart';
import '../../bilesenler/onay_dialog.dart';
import '../../bilesenler/tarih_araligi_secici_dialog.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/responsive_yardimcisi.dart';
import 'modeller/gider_model.dart';
import 'gider_ekle_sayfasi.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../../servisler/giderler_veritabani_servisi.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../bilesenler/akilli_aciklama_input.dart';
import '../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../ortak/genisletilebilir_print_preview_screen.dart';

class GiderlerSayfasi extends StatefulWidget {
  const GiderlerSayfasi({super.key});

  @override
  State<GiderlerSayfasi> createState() => _GiderlerSayfasiState();
}

class _GiderlerSayfasiState extends State<GiderlerSayfasi> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<GiderModel> _cachedGiderler = [];
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  bool _isLoading = true;
  int _totalRecords = 0;
  final Set<int> _selectedIds = {};
  final Set<int> _expandedMobileIds = {};
  int? _selectedMobileCardId;
  bool _isMobileToolbarExpanded = false;
  int? _selectedRowId;

  int _rowsPerPage = 25;
  int _currentPage = 1;
  final Map<int, int> _pageCursors = {};

  // Expanded rows
  final Set<int> _expandedIndices = {};

  // Date Filter State
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  // Status Filter State
  String? _selectedStatus;

  // Payment Status Filter State
  String? _selectedPaymentStatus;

  // Category Filter State
  String? _selectedCategory;

  // User Filter State
  String? _selectedUser;
  List<String> _availableUsers = [];

  // Overlay State
  final LayerLink _statusLayerLink = LayerLink();
  final LayerLink _paymentLayerLink = LayerLink();
  final LayerLink _categoryLayerLink = LayerLink();
  final LayerLink _userLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  // Sorting State
  int? _sortColumnIndex = 1;
  bool _sortAscending = false;
  String? _sortBy = 'id';
  Timer? _debounce;
  int _aktifSorguNo = 0;

  Map<String, Map<String, int>> _filterStats = {};

  // Keep details open toggle
  bool _keepDetailsOpen = false;

  List<String> _availableCategories = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAvailableFilters();
    _loadAvailableUsers();
    _fetchGiderler();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.toLowerCase();
      if (query != _searchQuery) {
        setState(() {
          _searchQuery = query;
          _resetPagination();
        });
        _fetchGiderler(showLoading: false);
      }
    });
  }

  void _resetPagination() {
    _pageCursors.clear();
    _currentPage = 1;
  }

  Future<void> _fetchGiderler({bool showLoading = true}) async {
    final int sorguNo = ++_aktifSorguNo;

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final bool? aktifMi = _selectedStatus == 'active'
          ? true
          : (_selectedStatus == 'passive' ? false : null);

      final giderler = await GiderlerVeritabaniServisi().giderleriGetir(
        sayfa: _currentPage,
        sayfaBasinaKayit: _rowsPerPage,
        aramaTerimi: _searchQuery,
        sortBy: _sortBy,
        sortAscending: _sortAscending,
        aktifMi: aktifMi,
        odemeDurumu: _selectedPaymentStatus,
        kategori: _selectedCategory,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        kullanici: _selectedUser,
        lastId: _currentPage > 1 ? _pageCursors[_currentPage - 1] : null,
      );

      if (giderler.isNotEmpty) {
        _pageCursors[_currentPage] = giderler.last.id;
      }

      if (!mounted || sorguNo != _aktifSorguNo) return;

      final totalFuture = GiderlerVeritabaniServisi().giderSayisiGetir(
        aramaTerimi: _searchQuery,
        aktifMi: aktifMi,
        odemeDurumu: _selectedPaymentStatus,
        kategori: _selectedCategory,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
        kullanici: _selectedUser,
      );

      final statsFuture = GiderlerVeritabaniServisi()
          .giderFiltreIstatistikleriniGetir(
            aramaTerimi: _searchQuery,
            baslangicTarihi: _startDate,
            bitisTarihi: _endDate,
            aktifMi: aktifMi,
            kategori: _selectedCategory,
            odemeDurumu: _selectedPaymentStatus,
            kullanici: _selectedUser,
          );

      if (mounted) {
        final indices = <int>{};
        final hasFacetFilters =
            _selectedCategory != null ||
            _selectedPaymentStatus != null ||
            _selectedUser != null ||
            _startDate != null ||
            _endDate != null;

        if (_keepDetailsOpen || hasFacetFilters) {
          indices.addAll(List.generate(giderler.length, (i) => i));
        } else if (_searchQuery.trim().isNotEmpty) {
          for (int i = 0; i < giderler.length; i++) {
            if (giderler[i].matchedInHidden) {
              indices.add(i);
            }
          }
        }

        setState(() {
          _isLoading = false;
          _cachedGiderler = giderler;
          _expandedIndices
            ..clear()
            ..addAll(indices);
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
              debugPrint('Gider toplam sayısı güncellenemedi: $e');
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
              debugPrint('Gider filtre istatistikleri güncellenemedi: $e');
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
    final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
    if (mounted) {
      setState(() {
        _genelAyarlar = settings;
      });
    }
  }

  Future<void> _loadAvailableFilters() async {
    try {
      final dbCategories = await GiderlerVeritabaniServisi()
          .giderKategorileriniGetir();

      final merged = {
        ...GiderModel.varsayilanKategoriler(),
        ...dbCategories,
      }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (mounted) {
        setState(() {
          _availableCategories = merged;
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _debounce?.cancel();
    super.dispose();
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _startDateController.clear();
      _endDateController.clear();
      _resetPagination();
    });
    _fetchGiderler();
  }

  Future<void> _showAddDialog({bool autoStartAiScan = false}) async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GiderEkleSayfasi(autoStartAiScan: autoStartAiScan),
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
      await _loadAvailableFilters();
      _fetchGiderler();
    }
  }

  Future<void> _showEditDialog(GiderModel gider) async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GiderEkleSayfasi(gider: gider),
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
      await _loadAvailableFilters();
      _fetchGiderler();
    }
  }

  Future<void> _deleteGider(GiderModel gider) async {
    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr(
          'common.confirm_delete_named',
        ).replaceAll('{name}', gider.baslik),
        onOnay: () {},
        isDestructive: true,
        onayButonMetni: tr('common.delete'),
      ),
    );

    if (onay == true) {
      try {
        await GiderlerVeritabaniServisi().giderSil(gider.id);
        if (!mounted) return;
        MesajYardimcisi.basariGoster(
          context,
          tr('common.deleted_successfully'),
        );
        _fetchGiderler(showLoading: false);
      } catch (e) {
        if (!mounted) return;
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    }
  }

  Future<void> _deleteSelectedGiderler() async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;

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

    if (onay != true) return;

    try {
      for (final id in _selectedIds.toList()) {
        await GiderlerVeritabaniServisi().giderSil(id);
      }

      if (!mounted) return;

      setState(() {
        _selectedIds.clear();
        _selectedRowId = null;
        _selectedMobileCardId = null;
      });

      MesajYardimcisi.basariGoster(context, tr('common.deleted_successfully'));
      _fetchGiderler(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  Future<void> _giderDurumDegistir(GiderModel gider, bool aktifMi) async {
    try {
      await GiderlerVeritabaniServisi().giderDurumGuncelle(
        id: gider.id,
        aktifMi: aktifMi,
      );
      await _fetchGiderler(showLoading: false);
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

  void _onSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedIds
          ..clear()
          ..addAll(_cachedGiderler.map((g) => g.id));
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
    String sortField = 'id';
    switch (columnIndex) {
      case 1:
        sortField = 'id';
        break;
      case 2:
        sortField = 'kod';
        break;
      case 3:
        sortField = 'baslik';
        break;
      case 4:
        sortField = 'tutar';
        break;
      case 5:
        sortField = 'kategori';
        break;
      case 6:
        sortField = 'tarih';
        break;
      case 8:
        sortField = 'aktif_mi';
        break;
      case 9:
        sortField = 'aciklama';
        break;
    }
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _sortBy = sortField;
      _resetPagination();
    });
    _fetchGiderler();
  }

  void _clearAllTableSelections() {
    setState(() {
      _selectedRowId = null;
      _selectedMobileCardId = null;
      _selectedIds.clear();
    });
  }

  void _toggleKeepDetailsOpen() {
    setState(() {
      _keepDetailsOpen = !_keepDetailsOpen;
      if (_keepDetailsOpen) {
        // Expand all rows
        for (int i = 0; i < _cachedGiderler.length; i++) {
          _expandedIndices.add(i);
        }
      } else {
        _expandedIndices.clear();
      }
    });
  }

  Future<void> _handlePrint() async {
    try {
      if (_cachedGiderler.isEmpty) return;

      final bool hasSelection = _selectedIds.isNotEmpty;

      final expandedExpenseIds = _expandedIndices
          .where((i) => i >= 0 && i < _cachedGiderler.length)
          .map((i) => _cachedGiderler[i].id)
          .toSet();

      final List<GiderModel> dataToProcess;
      if (!hasSelection) {
        dataToProcess = _cachedGiderler;
      } else {
        dataToProcess = await GiderlerVeritabaniServisi().giderleriGetirByIds(
          _selectedIds.toList(),
        );
      }

      final List<ExpandableRowData> rows = [];
      var rowNo = 1;
      for (final gider in dataToProcess) {
        final bool isExpanded =
            _keepDetailsOpen || expandedExpenseIds.contains(gider.id);

        final String amountText =
            '${FormatYardimcisi.sayiFormatlaOndalikli(gider.tutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${gider.paraBirimi}';
        final String dateText = DateFormat(
          'dd.MM.yyyy HH:mm',
        ).format(gider.tarih);

        final details = <String, String>{};
        if (gider.not.trim().isNotEmpty) {
          details[tr('expenses.table.note')] = gider.not;
        }

        DetailTable? subTable;
        if (gider.kalemler.isNotEmpty) {
          subTable = DetailTable(
            title: tr('expenses.recent_transactions'),
            headers: [
              tr('language.table.orderNo'),
              tr('expenses.table.expense_item'),
              tr('expenses.table.date'),
              tr('expenses.table.amount'),
              tr('expenses.table.description'),
              tr('expenses.table.user'),
            ],
            data: gider.kalemler.asMap().entries.map((entry) {
              final kalem = entry.value;
              final kalemAmount =
                  '${FormatYardimcisi.sayiFormatlaOndalikli(kalem.tutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${gider.paraBirimi}';
              return [
                '${entry.key + 1}',
                kalem.aciklama,
                dateText,
                kalemAmount,
                kalem.not,
                gider.kullanici,
              ];
            }).toList(),
          );
        }

        rows.add(
          ExpandableRowData(
            mainRow: [
              '${rowNo++}',
              gider.kod,
              gider.baslik,
              amountText,
              gider.kategori,
              dateText,
              gider.odemeDurumu == 'Ödendi'
                  ? tr('expenses.payment.paid')
                  : tr('expenses.payment.pending'),
              gider.aktifMi ? tr('common.active') : tr('common.passive'),
              gider.aciklama,
            ],
            details: details,
            transactions: subTable,
            imageUrls: gider.resimler,
            isExpanded: isExpanded,
          ),
        );
      }

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

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GenisletilebilirPrintPreviewScreen(
            title: tr('expenses.title'),
            headers: [
              tr('language.table.orderNo'),
              tr('expenses.table.code'),
              tr('expenses.table.title'),
              tr('expenses.table.amount'),
              tr('expenses.table.category'),
              tr('expenses.table.date'),
              tr('expenses.table.payment_status'),
              tr('common.status'),
              tr('expenses.table.description'),
            ],
            data: rows,
            dateInterval: dateInfo,
            initialShowDetails: _keepDetailsOpen || _expandedIndices.isNotEmpty,
            hideFeaturesCheckbox: true,
          ),
        ),
      );
    } catch (e) {
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  void _showStatusOverlay() {
    _closeOverlay();

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
          _resetPagination();
        });
        _closeOverlay();
        _fetchGiderler();
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

  void _showPaymentOverlay() {
    _closeOverlay();

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
            link: _paymentLayerLink,
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
                    _buildPaymentOption(
                      null,
                      tr('settings.general.option.documents.all'),
                    ),
                    _buildPaymentOption(
                      'Beklemede',
                      tr('expenses.payment.pending'),
                    ),
                    _buildPaymentOption('Ödendi', tr('expenses.payment.paid')),
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

  Widget _buildPaymentOption(String? value, String label) {
    final isSelected = _selectedPaymentStatus == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['odeme_durumlari']?[value] ?? 0);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentStatus = value;
          _resetPagination();
        });
        _closeOverlay();
        _fetchGiderler();
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

  void _showCategoryOverlay() {
    _closeOverlay();

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
            link: _categoryLayerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 42),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Container(
                width: 200,
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
                      _buildCategoryOption(
                        null,
                        tr('settings.general.option.documents.all'),
                      ),
                      ..._availableCategories.map(
                        (c) => _buildCategoryOption(c, c),
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

  Widget _buildCategoryOption(String? value, String label) {
    final isSelected = _selectedCategory == value;
    final int count = value == null
        ? (_filterStats['ozet']?['toplam'] ?? 0)
        : (_filterStats['kategoriler']?[value] ?? 0);

    if (value != null && count == 0 && !isSelected) {
      return const SizedBox.shrink();
    }
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = value;
          _resetPagination();
        });
        _closeOverlay();
        _fetchGiderler();
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

  void _showUserOverlay() {
    _closeOverlay();

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
          _resetPagination();
        });
        _closeOverlay();
        _fetchGiderler();
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
        _resetPagination();
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
      });
      _fetchGiderler();
    }
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Range Filter
          Expanded(child: _buildDateRangeFilter()),
          const SizedBox(width: 24),
          // Status Filter
          Expanded(
            child: CompositedTransformTarget(
              link: _statusLayerLink,
              child: _buildStatusFilterWidget(),
            ),
          ),
          const SizedBox(width: 24),
          // Payment Status Filter
          Expanded(
            child: CompositedTransformTarget(
              link: _paymentLayerLink,
              child: _buildPaymentFilterWidget(),
            ),
          ),
          const SizedBox(width: 24),
          // Category Filter
          Expanded(
            child: CompositedTransformTarget(
              link: _categoryLayerLink,
              child: _buildCategoryFilterWidget(),
            ),
          ),
          const SizedBox(width: 24),
          // User Filter
          Expanded(
            child: CompositedTransformTarget(
              link: _userLayerLink,
              child: _buildUserFilterWidget(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeFilter() {
    final hasSelection = _startDate != null || _endDate != null;
    return InkWell(
      onTap: _showDateRangePicker,
      borderRadius: BorderRadius.circular(4),
      child: Container(
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

  Widget _buildStatusFilterWidget() {
    final hasSelection = _selectedStatus != null;
    return InkWell(
      onTap: _showStatusOverlay,
      borderRadius: BorderRadius.circular(4),
      child: Container(
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
              Icons.toggle_on_outlined,
              size: 20,
              color: hasSelection
                  ? const Color(0xFF2C3E50)
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasSelection
                    ? (_selectedStatus == 'active'
                          ? '${tr('common.active')} (${_filterStats['durumlar']?['active'] ?? 0})'
                          : '${tr('common.passive')} (${_filterStats['durumlar']?['passive'] ?? 0})')
                    : tr('common.status'),
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
                    _selectedStatus = null;
                    _resetPagination();
                  });
                  _fetchGiderler();
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

  Widget _buildPaymentFilterWidget() {
    final hasSelection = _selectedPaymentStatus != null;
    return InkWell(
      onTap: _showPaymentOverlay,
      borderRadius: BorderRadius.circular(4),
      child: Container(
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
              Icons.payment,
              size: 20,
              color: hasSelection
                  ? const Color(0xFF2C3E50)
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasSelection
                    ? '${_selectedPaymentStatus == 'Beklemede' ? tr('expenses.payment.pending') : tr('expenses.payment.paid')} (${_filterStats['odeme_durumlari']?[_selectedPaymentStatus] ?? 0})'
                    : tr('expenses.filter.payment_status'),
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
                    _selectedPaymentStatus = null;
                    _resetPagination();
                  });
                  _fetchGiderler();
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

  Widget _buildCategoryFilterWidget() {
    final hasSelection = _selectedCategory != null;
    return InkWell(
      onTap: _showCategoryOverlay,
      borderRadius: BorderRadius.circular(4),
      child: Container(
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
              Icons.category,
              size: 20,
              color: hasSelection
                  ? const Color(0xFF2C3E50)
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasSelection
                    ? '${_selectedCategory!} (${_filterStats['kategoriler']?[_selectedCategory] ?? 0})'
                    : tr('expenses.filter.category'),
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
                    _selectedCategory = null;
                    _resetPagination();
                  });
                  _fetchGiderler();
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

  Widget _buildUserFilterWidget() {
    final hasSelection = _selectedUser != null;
    return InkWell(
      onTap: _showUserOverlay,
      borderRadius: BorderRadius.circular(4),
      child: Container(
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
              Icons.person,
              size: 20,
              color: hasSelection
                  ? const Color(0xFF2C3E50)
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasSelection
                    ? '${_selectedUser!} (${_filterStats['kullanicilar']?[_selectedUser] ?? 0})'
                    : tr('common.user'),
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
                    _selectedUser = null;
                    _resetPagination();
                  });
                  _fetchGiderler();
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

  Widget _buildCell({
    double? width,
    int? flex,
    Alignment alignment = Alignment.centerLeft,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16),
    required Widget child,
  }) {
    final content = Container(
      padding: padding,
      alignment: alignment,
      child: child,
    );

    if (flex != null) {
      return Expanded(flex: flex, child: content);
    }
    return SizedBox(width: width, child: content);
  }

  Widget _buildPopupMenu(GiderModel gider) {
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
            value: gider.aktifMi ? 'deactivate' : 'activate',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  gider.aktifMi
                      ? Icons.toggle_on_outlined
                      : Icons.toggle_off_outlined,
                  size: 20,
                  color: const Color(0xFF2C3E50),
                ),
                const SizedBox(width: 12),
                Text(
                  gider.aktifMi
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
                  tr('common.key.f8'),
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
            _showEditDialog(gider);
          } else if (value == 'activate') {
            _giderDurumDegistir(gider, true);
          } else if (value == 'deactivate') {
            _giderDurumDegistir(gider, false);
          } else if (value == 'delete') {
            _deleteGider(gider);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredGiderler = _cachedGiderler;

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

              // Priority 2: Clear Search if active (mobile toolbar)
              if (_searchController.text.isNotEmpty) {
                _searchController.clear();
                return;
              }

              // Priority 3: Clear Filters if active
              if (_startDate != null ||
                  _endDate != null ||
                  _selectedStatus != null ||
                  _selectedPaymentStatus != null ||
                  _selectedCategory != null ||
                  _selectedUser != null) {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _startDateController.clear();
                  _endDateController.clear();
                  _selectedStatus = null;
                  _selectedPaymentStatus = null;
                  _selectedCategory = null;
                  _selectedUser = null;
                  _resetPagination();
                });
                _fetchGiderler(showLoading: false);
                return;
              }
            },
            const SingleActivator(LogicalKeyboardKey.f1): () =>
                _showAddDialog(),
            const SingleActivator(LogicalKeyboardKey.f2): () {
              if (_selectedRowId == null) return;
              final int index = _cachedGiderler.indexWhere(
                (g) => g.id == _selectedRowId,
              );
              if (index == -1) return;
              _showEditDialog(_cachedGiderler[index]);
            },
            const SingleActivator(LogicalKeyboardKey.f3): () {
              _searchFocusNode.requestFocus();
            },
            const SingleActivator(LogicalKeyboardKey.f5): () {
              _fetchGiderler();
            },
            const SingleActivator(LogicalKeyboardKey.f6): () {
              if (_selectedRowId == null) return;
              final int index = _cachedGiderler.indexWhere(
                (g) => g.id == _selectedRowId,
              );
              if (index == -1) return;
              final gider = _cachedGiderler[index];
              _giderDurumDegistir(gider, !gider.aktifMi);
            },
            const SingleActivator(LogicalKeyboardKey.f7): _handlePrint,
            const SingleActivator(LogicalKeyboardKey.f8): () {
              if (_selectedIds.isNotEmpty) {
                _deleteSelectedGiderler();
                return;
              }
              if (_selectedRowId == null) return;
              final int index = _cachedGiderler.indexWhere(
                (g) => g.id == _selectedRowId,
              );
              if (index == -1) return;
              _deleteGider(_cachedGiderler[index]);
            },
            const SingleActivator(LogicalKeyboardKey.f9): () {
              if (_selectedRowId == null) return;
              final int index = _cachedGiderler.indexWhere(
                (g) => g.id == _selectedRowId,
              );
              if (index == -1) return;
              _showQuickAddDrawer(_cachedGiderler[index]);
            },
            const SingleActivator(LogicalKeyboardKey.delete): () {
              if (_selectedIds.isNotEmpty) {
                _deleteSelectedGiderler();
                return;
              }
              if (_selectedRowId == null) return;
              final int index = _cachedGiderler.indexWhere(
                (g) => g.id == _selectedRowId,
              );
              if (index == -1) return;
              _deleteGider(_cachedGiderler[index]);
            },
            const SingleActivator(LogicalKeyboardKey.numpadDecimal): () {
              if (_selectedIds.isNotEmpty) {
                _deleteSelectedGiderler();
                return;
              }
              if (_selectedRowId == null) return;
              final int index = _cachedGiderler.indexWhere(
                (g) => g.id == _selectedRowId,
              );
              if (index == -1) return;
              _deleteGider(_cachedGiderler[index]);
            },
          },
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool forceMobile =
                      ResponsiveYardimcisi.tabletMi(context);
                  if (forceMobile || constraints.maxWidth < 1000) {
                    return _buildMobileView(filteredGiderler);
                  }
                  return _buildDesktopView(filteredGiderler);
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

  Widget _buildDesktopView(List<GiderModel> giderler) {
    final bool allSelected =
        (giderler.isNotEmpty &&
        giderler.every((g) => _selectedIds.contains(g.id)));

    return GenisletilebilirTablo<GiderModel>(
      title: tr('expenses.title'),
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
          final rowsChanged = _rowsPerPage != rowsPerPage;
          _rowsPerPage = rowsPerPage;
          if (rowsChanged) {
            _resetPagination();
          } else {
            _currentPage = page;
          }
        });
        _fetchGiderler(showLoading: false);
      },
      onSearch: (query) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          setState(() {
            _searchQuery = query.toLowerCase();
            _resetPagination();
          });
          _fetchGiderler(showLoading: false);
        });
      },
      selectionWidget: _selectedIds.isNotEmpty
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _deleteSelectedGiderler,
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
      extraWidgets: [
        Tooltip(
          message: tr('expenses.keep_details_open'),
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
      ],
      actionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Print Button
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
          // Add Button
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
                      tr('expenses.add'),
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
        GenisletilebilirTabloKolon(
          label: tr('language.table.orderNo'),
          width: 130,
          alignment: Alignment.centerLeft,
          allowSorting: true,
        ),
        GenisletilebilirTabloKolon(
          label: tr('expenses.table.code'),
          width: 140,
          alignment: Alignment.centerLeft,
          allowSorting: true,
        ),
        GenisletilebilirTabloKolon(
          label: tr('expenses.table.title'),
          width: 200,
          alignment: Alignment.centerLeft,
          allowSorting: true,
          flex: 2,
        ),
        GenisletilebilirTabloKolon(
          label: tr('expenses.table.amount'),
          width: 150,
          alignment: Alignment.centerRight,
          allowSorting: true,
        ),
        GenisletilebilirTabloKolon(
          label: tr('expenses.table.category'),
          width: 130,
          alignment: Alignment.centerLeft,
          allowSorting: true,
        ),
        GenisletilebilirTabloKolon(
          label: tr('expenses.table.date'),
          width: 160,
          alignment: Alignment.centerLeft,
          allowSorting: true,
        ),
        GenisletilebilirTabloKolon(
          label: tr('expenses.table.payment_status'),
          width: 180,
          alignment: Alignment.centerLeft,
        ),
        GenisletilebilirTabloKolon(
          label: tr('common.status'),
          width: 110,
          alignment: Alignment.centerLeft,
          allowSorting: true,
        ),
        GenisletilebilirTabloKolon(
          label: tr('expenses.table.description'),
          width: 200,
          alignment: Alignment.centerLeft,
          allowSorting: true,
          flex: 2,
        ),
        GenisletilebilirTabloKolon(
          label: tr('common.actions'),
          width: 110,
          alignment: Alignment.centerLeft,
        ),
      ],
      data: giderler,
      isRowSelected: (gider, index) => _selectedRowId == gider.id,
      expandOnRowTap: false,
      expandedIndices: _expandedIndices,
      onExpansionChanged: (index, isExpanded) {
        setState(() {
          if (isExpanded) {
            _expandedIndices.add(index);
          } else {
            _expandedIndices.remove(index);
          }
        });
      },
      onRowTap: (gider) {
        setState(() {
          _selectedRowId = gider.id;
        });
      },
      rowBuilder: (context, gider, index, isExpanded, toggleExpand) {
        final query = _searchQuery.trim();
        final amountText =
            '${FormatYardimcisi.sayiFormatlaOndalikli(gider.tutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${gider.paraBirimi}';
        final dateText = DateFormat('dd.MM.yyyy HH:mm').format(gider.tarih);

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
                  value: _selectedIds.contains(gider.id),
                  onChanged: (val) => _onSelectRow(val, gider.id),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
                ),
              ),
            ),
            _buildCell(
              width: 130,
              child: Row(
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: toggleExpand,
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        color: Colors.grey.shade600,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  HighlightText(
                    text: '${index + 1}',
                    query: query,
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                ],
              ),
            ),
            _buildCell(
              width: 140,
              child: HighlightText(
                text: gider.kod,
                query: query,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ),
            _buildCell(
              flex: 2,
              child: HighlightText(
                text: gider.baslik,
                query: query,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _buildCell(
              width: 150,
              alignment: Alignment.centerRight,
              child: HighlightText(
                text: amountText,
                query: query,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFFEA4335),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _buildCell(
              width: 130,
              child: HighlightText(
                text: gider.kategori,
                query: query,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ),
            _buildCell(
              width: 160,
              child: HighlightText(
                text: dateText,
                query: query,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ),
            _buildCell(
              width: 180,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: gider.odemeDurumu == 'Ödendi'
                      ? const Color(0xFFE6F4EA)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: HighlightText(
                  text: gider.odemeDurumu == 'Ödendi'
                      ? tr('expenses.payment.paid')
                      : tr('expenses.payment.pending'),
                  query: query,
                  style: TextStyle(
                    color: gider.odemeDurumu == 'Ödendi'
                        ? const Color(0xFF1E7E34)
                        : const Color(0xFFF39C12),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            _buildCell(
              width: 110,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: gider.aktifMi
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
                        color: gider.aktifMi
                            ? const Color(0xFF28A745)
                            : const Color(0xFF757575),
                      ),
                      const SizedBox(width: 6),
                      HighlightText(
                        text: gider.aktifMi
                            ? tr('common.active')
                            : tr('common.passive'),
                        query: query,
                        style: TextStyle(
                          color: gider.aktifMi
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
              flex: 2,
              child: HighlightText(
                text: gider.aciklama,
                query: query,
                maxLines: 1,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ),
            _buildCell(width: 110, child: _buildPopupMenu(gider)),
          ],
        );
      },
      detailBuilder: (context, gider) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: Colors.grey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildDetailHeaderRow(tr('expenses.recent_transactions')),
                  const Spacer(),
                  _buildAddTransactionButton(gider),
                ],
              ),
              const SizedBox(height: 12),
              _buildTransactionsSubTable(gider),
            ],
          ),
        );
      },
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
    if (_selectedPaymentStatus != null) count++;
    if (_selectedCategory != null) count++;
    if (_selectedUser != null) count++;
    return count;
  }

  Future<void> _handleMobileActionMenuSelection(String value) async {
    final int? selectedId = _selectedMobileCardId;
    GiderModel? selectedGider;
    if (selectedId != null) {
      final int index = _cachedGiderler.indexWhere((g) => g.id == selectedId);
      if (index != -1) {
        selectedGider = _cachedGiderler[index];
      }
    }

    switch (value) {
      case 'edit':
        if (selectedGider == null) return;
        await _showEditDialog(selectedGider);
        return;
      case 'add_item':
        if (selectedGider == null) return;
        _showQuickAddDrawer(selectedGider);
        return;
      case 'toggle_active':
        if (selectedGider == null) return;
        _giderDurumDegistir(selectedGider, !selectedGider.aktifMi);
        return;
      case 'delete':
        if (selectedGider == null) return;
        await _deleteGider(selectedGider);
        return;
      case 'delete_selected':
        await _deleteSelectedGiderler();
        return;
      case 'print':
        await _handlePrint();
        return;
      case 'clear_selection':
        _clearAllTableSelections();
        return;
    }
  }

  Widget _buildMobileActionsMenuButton({double size = 48}) {
    final bool hasFocused = _selectedMobileCardId != null;
    final bool hasMultiSelection = _selectedIds.isNotEmpty;
    GiderModel? focusedGider;
    if (hasFocused) {
      final int index = _cachedGiderler.indexWhere(
        (g) => g.id == _selectedMobileCardId,
      );
      if (index != -1) {
        focusedGider = _cachedGiderler[index];
      }
    }
    final String toggleStatusLabel = focusedGider == null
        ? tr('common.status')
        : (focusedGider.aktifMi
              ? tr('common.deactivate')
              : tr('common.activate'));
    final IconData toggleStatusIcon = focusedGider == null
        ? Icons.toggle_on_outlined
        : (focusedGider.aktifMi
              ? Icons.toggle_on_outlined
              : Icons.toggle_off_outlined);

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
            enabled: hasFocused,
            value: 'edit',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: hasFocused
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 12),
                Text(
                  tr('common.edit'),
                  style: TextStyle(
                    color: hasFocused
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            enabled: hasFocused,
            value: 'add_item',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 20,
                  color: hasFocused
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 12),
                Text(
                  tr('expenses.add_transaction'),
                  style: TextStyle(
                    color: hasFocused
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            enabled: hasFocused,
            value: 'toggle_active',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  toggleStatusIcon,
                  size: 20,
                  color: hasFocused
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 12),
                Text(
                  toggleStatusLabel,
                  style: TextStyle(
                    color: hasFocused
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade400,
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
            value: 'print',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.print_outlined,
                  size: 20,
                  color: Color(0xFF4A4A4A),
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedIds.isNotEmpty
                      ? tr('common.print_selected')
                      : tr('common.print_list'),
                  style: const TextStyle(
                    color: Color(0xFF4A4A4A),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (_selectedIds.isNotEmpty)
            PopupMenuItem<String>(
              enabled: hasMultiSelection,
              value: 'delete_selected',
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
                    tr(
                      'common.delete_selected',
                    ).replaceAll('{count}', _selectedIds.length.toString()),
                    style: const TextStyle(
                      color: Color(0xFFEA4335),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            PopupMenuItem<String>(
              enabled: hasFocused,
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
                    style: TextStyle(
                      color: hasFocused
                          ? const Color(0xFFEA4335)
                          : Colors.grey.shade400,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          PopupMenuItem<String>(
            enabled: hasFocused || hasMultiSelection,
            value: 'clear_selection',
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.clear_all,
                  size: 20,
                  color: (hasFocused || hasMultiSelection)
                      ? const Color(0xFF4A4A4A)
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 12),
                Text(
                  tr('common.clear'),
                  style: TextStyle(
                    color: (hasFocused || hasMultiSelection)
                        ? const Color(0xFF4A4A4A)
                        : Colors.grey.shade400,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(
            Icons.more_horiz,
            size: size < 44 ? 20 : 22,
            color: const Color(0xFF2C3E50),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileTopActionRow() {
    final double width = MediaQuery.of(context).size.width;
    final bool isNarrow = width < 360;

    final String addLabel = isNarrow ? 'Ekle' : tr('expenses.add');
    final String printTooltip = _selectedIds.isNotEmpty
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
            onTap: () => _showAddDialog(),
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

        final dateFilter = _buildDateRangeFilter();
        final statusFilter = CompositedTransformTarget(
          link: _statusLayerLink,
          child: _buildStatusFilterWidget(),
        );
        final paymentFilter = CompositedTransformTarget(
          link: _paymentLayerLink,
          child: _buildPaymentFilterWidget(),
        );
        final categoryFilter = CompositedTransformTarget(
          link: _categoryLayerLink,
          child: _buildCategoryFilterWidget(),
        );
        final userFilter = CompositedTransformTarget(
          link: _userLayerLink,
          child: _buildUserFilterWidget(),
        );

        if (singleColumn) {
          return Column(
            children: [
              dateFilter,
              const SizedBox(height: 12),
              statusFilter,
              const SizedBox(height: 12),
              paymentFilter,
              const SizedBox(height: 12),
              categoryFilter,
              const SizedBox(height: 12),
              userFilter,
            ],
          );
        }

        return Column(
          children: [
            Row(children: [Expanded(child: dateFilter)]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: statusFilter),
                const SizedBox(width: 12),
                Expanded(child: paymentFilter),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: categoryFilter),
                const SizedBox(width: 12),
                Expanded(child: userFilter),
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
                                          _fetchGiderler(showLoading: false);
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
                                        onTap: _deleteSelectedGiderler,
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

  Widget _buildMobileView(List<GiderModel> giderler) {
    final int totalRecords = _totalRecords > 0
        ? _totalRecords
        : giderler.length;
    final int safeRowsPerPage = _rowsPerPage <= 0 ? 25 : _rowsPerPage;
    final int totalPages = totalRecords == 0
        ? 1
        : (totalRecords / safeRowsPerPage).ceil();
    final int effectivePage = _currentPage.clamp(1, totalPages);
    if (effectivePage != _currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _currentPage = effectivePage;
        });
        _fetchGiderler(showLoading: false);
      });
    }

    final int startRecordIndex = (effectivePage - 1) * safeRowsPerPage;
    final int endRecord = totalRecords == 0
        ? 0
        : (startRecordIndex + giderler.length).clamp(0, totalRecords);
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
                    tr('expenses.title'),
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
                itemCount: giderler.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildGiderCard(giderler[index]);
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
                              _fetchGiderler(showLoading: false);
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
                              _fetchGiderler(showLoading: false);
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

  Widget _buildGiderCard(GiderModel gider) {
    final isExpanded = _expandedMobileIds.contains(gider.id);
    final isFocused = _selectedMobileCardId == gider.id;

    final query = _searchQuery.trim();
    final amountText =
        '${FormatYardimcisi.sayiFormatlaOndalikli(gider.tutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${gider.paraBirimi}';
    final dateText = DateFormat('dd.MM.yyyy HH:mm').format(gider.tarih);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedMobileCardId == gider.id) {
            _selectedMobileCardId = null;
          } else {
            _selectedMobileCardId = gider.id;
          }
          _selectedRowId = gider.id;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isFocused
              ? const Color(0xFF2C3E50).withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFocused
                ? const Color(0xFF2C3E50).withValues(alpha: 0.3)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: isFocused
                  ? const Color(0xFF2C3E50).withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: isFocused ? 12 : 10,
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
                    value: _selectedIds.contains(gider.id),
                    onChanged: (v) => _onSelectRow(v, gider.id),
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
                      HighlightText(
                        text: gider.baslik,
                        query: query,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${gider.kod} • ${gider.kategori}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    HighlightText(
                      text: amountText,
                      query: query,
                      style: const TextStyle(
                        color: Color(0xFFEA4335),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildPopupMenu(gider),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status row + expand
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: gider.odemeDurumu == 'Ödendi'
                              ? const Color(0xFFE6F4EA)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          gider.odemeDurumu == 'Ödendi'
                              ? tr('expenses.payment.paid')
                              : tr('expenses.payment.pending'),
                          style: TextStyle(
                            color: gider.odemeDurumu == 'Ödendi'
                                ? const Color(0xFF1E7E34)
                                : const Color(0xFFF39C12),
                            fontWeight: FontWeight.bold,
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
                          color: gider.aktifMi
                              ? const Color(0xFFE6F4EA)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          gider.aktifMi
                              ? tr('common.active')
                              : tr('common.passive'),
                          style: TextStyle(
                            color: gider.aktifMi
                                ? const Color(0xFF1E7E34)
                                : const Color(0xFF757575),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (gider.aiIslenmisMi)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'AI',
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      if (gider.resimler.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.attachment_rounded,
                                size: 14,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${gider.resimler.length}',
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF2C3E50),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedMobileCardId = gider.id;
                      _selectedRowId = gider.id;
                      if (isExpanded) {
                        _expandedMobileIds.remove(gider.id);
                      } else {
                        _expandedMobileIds.add(gider.id);
                      }
                    });
                  },
                ),
              ],
            ),

            // Details
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Column(
                      children: [
                        const Divider(height: 24),
                        _buildMobileDetails(gider),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDetails(GiderModel gider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (gider.aciklama.trim().isNotEmpty) ...[
          Text(
            tr('expenses.table.description'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            gider.aciklama,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            _buildDetailHeaderRow(tr('expenses.recent_transactions')),
            const Spacer(),
            _buildAddTransactionButton(gider),
          ],
        ),
        const SizedBox(height: 12),
        _buildMobileTransactionsList(gider),
      ],
    );
  }

  Widget _buildMobileTransactionsList(GiderModel gider) {
    if (gider.kalemler.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          tr('expenses.items.sub_item_not_found'),
          style: TextStyle(
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final total = gider.kalemler.fold<double>(0.0, (sum, k) => sum + k.tutar);

    return Column(
      children: [
        ...gider.kalemler.asMap().entries.map((entry) {
          final kalem = entry.value;
          final amountText =
              '${FormatYardimcisi.sayiFormatlaOndalikli(kalem.tutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${gider.paraBirimi}';

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade100, width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    '${entry.key + 1}.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kalem.aciklama,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (kalem.not.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          kalem.not,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  amountText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${tr('common.total')}: ${FormatYardimcisi.sayiFormatlaOndalikli(total, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${gider.paraBirimi}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailHeaderRow(String title) {
    return Row(
      children: [
        const Icon(
          Icons.receipt_long_outlined,
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

  Widget _buildAddTransactionButton(GiderModel gider) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showQuickAddDrawer(gider),
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
                Icons.add_circle_outline,
                size: 16,
                color: Color(0xFF2C3E50),
              ),
              const SizedBox(width: 8),
              Text(
                tr('expenses.add_transaction'),
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
                  tr('common.key.f9'),
                  style: const TextStyle(
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

  void _showQuickAddDrawer(GiderModel gider) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final bool isNarrow = size.width < 700;
    final double panelWidth = isNarrow ? size.width : 500;
    final double panelHeight = isNarrow
        ? (size.height * 0.85).clamp(420.0, size.height)
        : double.infinity;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: tr('common.close'),
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: isNarrow ? Alignment.bottomCenter : Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: panelWidth,
              height: panelHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: isNarrow
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : BorderRadius.zero,
              ),
              child: SafeArea(
                top: !isNarrow,
                child: _QuickExpenseAddPanel(
                  gider: gider,
                  genelAyarlar: _genelAyarlar,
                  onSuccess: () {
                    Navigator.pop(context);
                    _fetchGiderler(showLoading: false);
                  },
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: isNarrow ? const Offset(0, 1) : const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }

  Widget _buildTransactionsSubTable(GiderModel gider) {
    if (gider.kalemler.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          tr('expenses.items.sub_item_not_found'),
          style: TextStyle(
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSubTableHeader(),
        ...gider.kalemler.asMap().entries.map(
          (entry) => _buildSubTableRow(entry.value, entry.key, gider),
        ),
        const Divider(),
        // Total row for confirmation
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${tr('common.total')}: ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              HighlightText(
                text:
                    '${FormatYardimcisi.sayiFormatlaOndalikli(gider.kalemler.fold(0.0, (sum, item) => sum + item.tutar), binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${gider.paraBirimi}',
                query: _searchQuery.trim(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
        ),
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
          SizedBox(
            width: 80,
            child: _buildDetailHeaderLabel(tr('language.table.orderNo')),
          ),
          SizedBox(
            width: 300,
            child: _buildDetailHeaderLabel(tr('expenses.table.expense_item')),
          ),
          SizedBox(
            width: 160,
            child: _buildDetailHeaderLabel(tr('expenses.table.date')),
          ),
          SizedBox(
            width: 150,
            child: _buildDetailHeaderLabel(
              tr('expenses.table.amount'),
              alignRight: false,
            ),
          ),
          const SizedBox(width: 60),
          Expanded(
            child: _buildDetailHeaderLabel(tr('expenses.table.description')),
          ),
          SizedBox(
            width: 140,
            child: _buildDetailHeaderLabel(tr('expenses.table.user')),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailHeaderLabel(String label, {bool alignRight = false}) {
    return Text(
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
    );
  }

  Widget _buildSubTableRow(GiderKalemi kalem, int index, GiderModel gider) {
    final query = _searchQuery.trim();
    final dateText = DateFormat('dd.MM.yyyy HH:mm').format(gider.tarih);
    final amountText =
        '${FormatYardimcisi.sayiFormatlaOndalikli(kalem.tutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${gider.paraBirimi}';

    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: HighlightText(
              text: '${index + 1}',
              query: query,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          SizedBox(
            width: 300,
            child: HighlightText(
              text: kalem.aciklama,
              query: query,
              maxLines: 1,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          SizedBox(
            width: 160,
            child: HighlightText(
              text: dateText,
              query: query,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          SizedBox(
            width: 150,
            child: Align(
              alignment: Alignment.centerLeft,
              child: HighlightText(
                text: amountText,
                query: query,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
          ),
          const SizedBox(width: 60),
          Expanded(
            child: HighlightText(
              text: kalem.not,
              query: query,
              maxLines: 1,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          SizedBox(
            width: 140,
            child: HighlightText(
              text: gider.kullanici,
              query: query,
              maxLines: 1,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// Quick Add Expense Panel
class _QuickExpenseAddPanel extends StatefulWidget {
  final GiderModel gider;
  final GenelAyarlarModel genelAyarlar;
  final VoidCallback onSuccess;

  const _QuickExpenseAddPanel({
    required this.gider,
    required this.genelAyarlar,
    required this.onSuccess,
  });

  @override
  State<_QuickExpenseAddPanel> createState() => _QuickExpenseAddPanelState();
}

class _QuickExpenseAddPanelState extends State<_QuickExpenseAddPanel> {
  final _formKey = GlobalKey<FormState>();
  final _itemDescController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountFocusNode = FocusNode();
  String _selectedCurrency = 'TRY';

  static const Color _primaryColor = Color(0xFF2C3E50);
  static const Color _textColor = Color(0xFF202124);

  final List<String> _currencies = ['TRY', 'USD', 'EUR', 'GBP'];

  @override
  void initState() {
    super.initState();
    // Use the currency from the generic settings unless we want row specific defaults
    _selectedCurrency = widget.genelAyarlar.varsayilanParaBirimi;
    if (_selectedCurrency == 'TL') _selectedCurrency = 'TRY';

    // Initialize main description - REMOVED as per user request to start empty
    // _descriptionController.text = widget.gider.aciklama;

    _attachPriceFormatter(_amountFocusNode, _amountController);
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
    _itemDescController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            unawaited(_submitForm());
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
                    Icons.receipt_long_outlined,
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
                        tr('expenses.quick_add.title'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      Text(
                        tr('expenses.quick_add.subtitle'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
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

          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gider Kalemi Açıklaması (Top, Mandatory)
                    _buildTextField(
                      controller: _itemDescController,
                      label: tr('expenses.items.description'),
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),

                    // Tutar & Para Birimi
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            controller: _amountController,
                            label: tr('expenses.form.amount.label'),
                            hint: '0.00',
                            isRequired: true,
                            isNumeric: true,
                            focusNode: _amountFocusNode,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdown<String>(
                            value: _selectedCurrency,
                            label: tr('expenses.form.currency.label'),
                            items: _currencies,
                            itemLabel: (s) => s,
                            onChanged: (val) =>
                                setState(() => _selectedCurrency = val!),
                            isRequired: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Açıklama (Smart Input) - Expense Item Note
                    AkilliAciklamaInput(
                      controller: _descriptionController,
                      label: tr('expenses.form.description.label'),
                      category: 'expense_item_note',
                      color: _primaryColor,
                      defaultItems: [
                        tr('expenses.items.default_note.part'),
                        tr('expenses.items.default_note.labor'),
                        tr('expenses.items.default_note.shipping'),
                        tr('expenses.items.default_note.tax'),
                        tr('common.other'),
                      ],
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
                      style: const TextStyle(
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
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: Text(
                      tr('expenses.add_transaction'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
    bool isRequired = false,
    bool isNumeric = false,
    String? hint,
    int maxLines = 1,
    FocusNode? focusNode,
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
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          maxLines: maxLines,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          inputFormatters: isNumeric
              ? [
                  CurrencyInputFormatter(
                    binlik: widget.genelAyarlar.binlikAyiraci,
                    ondalik: widget.genelAyarlar.ondalikAyiraci,
                    maxDecimalDigits: widget.genelAyarlar.fiyatOndalik,
                  ),
                  LengthLimitingTextInputFormatter(20),
                ]
              : null,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            hintStyle: TextStyle(
              color: Colors.grey.withValues(alpha: 0.4),
              fontSize: 14,
            ),
            contentPadding: EdgeInsets.symmetric(
              vertical: maxLines > 1 ? 8 : 12,
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFEEEEEE)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          validator: isRequired
              ? (val) =>
                    val?.isEmpty ?? true ? tr('common.required_field') : null
              : null,
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

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      final amount = FormatYardimcisi.parseDouble(
        _amountController.text,
        binlik: widget.genelAyarlar.binlikAyiraci,
        ondalik: widget.genelAyarlar.ondalikAyiraci,
      );

      final newItem = GiderKalemi(
        aciklama: _itemDescController.text,
        tutar: amount,
        not: _descriptionController.text,
      );

      await GiderlerVeritabaniServisi().giderKalemiEkle(
        giderId: widget.gider.id,
        kalem: newItem,
        paraBirimi: _selectedCurrency,
        // yeniAciklama gönderilmiyor, böylece ana açıklama değişmez
      );

      if (!mounted) return;

      MesajYardimcisi.basariGoster(context, tr('common.saved_successfully'));
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }
}
