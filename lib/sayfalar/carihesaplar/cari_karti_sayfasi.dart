import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'cari_para_al_ver_sayfasi.dart';
import 'borc_alacak_dekontu_isle_sayfasi.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../bilesenler/genisletilebilir_tablo.dart';
import '../../bilesenler/onay_dialog.dart';
import '../../bilesenler/tab_acici_scope.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/ceviri/islem_ceviri_yardimcisi.dart';
import '../../yardimcilar/responsive_yardimcisi.dart';
import '../../bilesenler/tarih_araligi_secici_dialog.dart';
import 'modeller/cari_hesap_model.dart';
import '../../../bilesenler/highlight_text.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../../servisler/satisyap_veritabani_servisleri.dart';
import '../../servisler/alisyap_veritabani_servisleri.dart';
import '../../servisler/depolar_veritabani_servisi.dart';
import '../../servisler/taksit_veritabani_servisi.dart';
import '../../servisler/urunler_veritabani_servisi.dart';
import '../alimsatimislemleri/alis_yap_sayfasi.dart';
import '../alimsatimislemleri/modeller/transaction_item.dart';
import '../alimsatimislemleri/satis_yap_sayfasi.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../../servisler/sayfa_senkronizasyon_servisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../alimsatimislemleri/satis_sonrasi_yazdir_sayfasi.dart';
import '../ortak/genisletilebilir_print_preview_screen.dart';
import 'cari_hesap_ekle_sayfasi.dart';
import 'cari_acilis_devri_duzenle_sayfasi.dart';
import '../../yardimcilar/islem_turu_renkleri.dart';
import '../urunler_ve_depolar/depolar/modeller/depo_model.dart';
import '../../bilesenler/taksit_izleme_diyalogu.dart';

class CariKartiSayfasi extends StatefulWidget {
  const CariKartiSayfasi({super.key, required this.cariHesap});

  final CariHesapModel cariHesap;

  @override
  State<CariKartiSayfasi> createState() => _CariKartiSayfasiState();
}

class _CariKartiSayfasiState extends State<CariKartiSayfasi> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late CariHesapModel _currentCari;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();
  bool _isLoading = false;
  final int _totalRecords = 0;
  final Set<int> _selectedIds = {};
  int? _selectedRowId;
  final FocusNode _searchFocusNode = FocusNode();

  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  late final TextEditingController _notController;

  bool _isInfoCardExpanded = false;
  // final Set<int> _autoExpandedIndices = {};
  int? _manualExpandedIndex;
  int? _singleViewRowId;
  Map<String, bool> _columnVisibility = {};

  OverlayEntry? _overlayEntry;

  bool _isSelectAllActive = false;
  String? _selectedStatus;
  String? _selectedAccountType;
  String? _selectedCity;
  final Map<int, List<int>> _visibleTransactionIds = {};
  final Key _refreshKey = UniqueKey();
  final Map<int, Set<int>> _selectedDetailIds = {};
  final Map<int, Set<int>> _selectedInstallmentIds = {};
  int? _selectedInstallmentRowId;
  final Map<int, Future<List<Map<String, dynamic>>>> _detailFutures = {};
  List<Map<String, dynamic>> _cachedTransactions = [];
  bool _hasInstallments = false;
  bool _isInstallmentsMode = false;
  List<Map<String, dynamic>> _cachedInstallments = [];
  Map<String, bool> _installmentColumnVisibility = {};
  final Map<String, String?> _urunBarkodCache = {};
  final Set<String> _urunBarkodFetchInProgress = {};

  bool _keepDetailsOpen = false;
  bool _isManuallyClosedDuringFilter = false;
  final Set<int> _transactionAutoExpandedIndices = {};
  int? _sortColumnIndex = 1;
  bool _sortAscending = false;
  Timer? _debounce;
  int _selectedEkstreType = 1;
  final ScrollController _ekstreHorizontalScrollController = ScrollController();
  String? _selectedTransactionType;
  bool _isTransactionTypeFilterExpanded = false;
  final LayerLink _transactionTypeLayerLink = LayerLink();
  String? _selectedUser;
  bool _isUserFilterExpanded = false;
  final LayerLink _userLayerLink = LayerLink();
  Map<String, Map<String, int>> _filterStats = {};

  double _odemeAlindiSum = 0;
  double _odemeYapildiSum = 0;
  double _alacakDekontuSum = 0;
  double _borcDekontuSum = 0;

  // [2026 FIX] Image Cache to prevent flickering/re-decoding
  final Map<String, MemoryImage> _imageCache = {};

  MemoryImage? _getCachedMemoryImage(String base64String) {
    if (base64String.isEmpty) return null;

    try {
      // Normalize string (handle data:image/...;base64, prefix if present)
      String b64 = base64String;
      if (b64.contains(',')) {
        b64 = b64.split(',').last;
      }

      // Check cache first
      if (_imageCache.containsKey(b64)) {
        return _imageCache[b64];
      }

      // Decode and cache
      final bytes = base64Decode(b64);
      final image = MemoryImage(bytes);
      _imageCache[b64] = image;
      return image;
    } catch (e) {
      debugPrint('Image decode error: $e');
      return null;
    }
  }

  Future<void> _loadTransactions() async {
    if (_isLoading) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      // Ensure current account info is fresh for balance calculation
      final updatedCari = await CariHesaplarVeritabaniServisi().cariHesapGetir(
        _currentCari.id,
      );
      if (updatedCari != null && mounted) {
        setState(() {
          _currentCari = updatedCari;
        });
      }

      final transactions = await CariHesaplarVeritabaniServisi()
          .cariIslemleriniGetir(_currentCari.id);

      // [2026 HYPER-SPEED] Filtre İstatistiklerini Getir
      final stats = await CariHesaplarVeritabaniServisi()
          .cariIslemFiltreIstatistikleriniGetir(
            cariId: _currentCari.id,
            aramaTerimi: _searchQuery,
            baslangicTarihi: _startDate,
            bitisTarihi: _endDate,
            islemTuru: _selectedTransactionType,
            kullanici: _selectedUser,
          );

      // Calculate running balance going backwards from CURRENT balance
      double currentTotalBalance =
          _currentCari.bakiyeBorc - _currentCari.bakiyeAlacak;

      double odemeAlindi = 0;
      double odemeYapildi = 0;
      double alacakDekontu = 0;
      double borcDekontu = 0;

      for (int i = 0; i < transactions.length; i++) {
        final tx = transactions[i];

        final double tutar =
            double.tryParse(tx['tutar']?.toString() ?? '') ?? 0.0;
        final String rawIslemTuru = tx['islem_turu']?.toString() ?? '';
        final String yonRaw = tx['yon']?.toString().toLowerCase() ?? '';

        final bool isIncoming =
            yonRaw.contains('alacak') ||
            rawIslemTuru.toLowerCase().contains('tahsilat') ||
            rawIslemTuru.toLowerCase().contains('alış');

        // Summary Calculations (For top right box breakdown)
        final String label = IslemTuruRenkleri.getProfessionalLabel(
          rawIslemTuru,
          context: 'cari',
          yon: tx['yon']?.toString(),
        );

        if (isIncoming) {
          if (label == 'Alacak Dekontu') {
            alacakDekontu += tutar;
          } else {
            odemeAlindi += tutar;
          }
        } else {
          if (label == 'Borç Dekontu') {
            borcDekontu += tutar;
          } else {
            odemeYapildi += tutar;
          }
        }

        tx['running_balance'] = currentTotalBalance;

        if (isIncoming) {
          currentTotalBalance += tutar;
        } else {
          currentTotalBalance -= tutar;
        }
      }

      // Apply Local Filters
      final filteredResult = transactions.where((tx) {
        final String rawIslemTuru = tx['islem_turu']?.toString() ?? '';
        final String type = tx['yon']?.toString() ?? '';

        // Transaction Type Filter
        if (_selectedTransactionType != null) {
          final label = IslemTuruRenkleri.getProfessionalLabel(
            rawIslemTuru,
            context: 'cari',
            yon: type,
          );
          if (label != _selectedTransactionType) {
            return false;
          }
        }

        // User Filter
        if (_selectedUser != null) {
          final userName = tx['kullanici']?.toString() ?? '';
          if (userName != _selectedUser) {
            return false;
          }
        }

        // Search filter
        if (_searchQuery.isNotEmpty) {
          if (!_matchesSearchQuery(tx, _searchQuery)) {
            return false;
          }
        }

        // Date range filter
        final rawTarih = tx['tarih'];
        if (rawTarih != null) {
          DateTime? dt;
          if (rawTarih is DateTime) {
            dt = rawTarih;
          } else if (rawTarih is String) {
            final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
            try {
              dt = dateFormat.parse(rawTarih);
            } catch (_) {
              dt = DateTime.tryParse(rawTarih);
            }
          }

          if (dt != null) {
            if (_startDate != null && dt.isBefore(_startDate!)) {
              return false;
            }
            if (_endDate != null &&
                dt.isAfter(_endDate!.add(const Duration(days: 1)))) {
              return false;
            }
          }
        }
        return true;
      }).toList();

      // UI Labels Modification (Applied only to filtered results for performance/correctness)
      for (var tx in filteredResult) {
        final String rawIslemTuru = tx['islem_turu']?.toString() ?? '';
        final String yon = tx['yon']?.toString().toLowerCase() ?? '';
        final bool isIncoming =
            yon.contains('alacak') ||
            rawIslemTuru.toLowerCase().contains('tahsilat') ||
            rawIslemTuru.toLowerCase().contains('alış');

        if (_searchQuery.isEmpty) {
          String islemTuru = rawIslemTuru;
          final String realStatus = tx['guncel_durum']?.toString() ?? '';

          if (realStatus == 'Ciro Edildi' || rawIslemTuru.contains('Ciro')) {
            if (islemTuru.toLowerCase().contains('çek')) {
              islemTuru = 'Çek Alındı (Ciro Edildi)';
            } else if (islemTuru.toLowerCase().contains('senet')) {
              islemTuru = 'Senet Alındı (Ciro Edildi)';
            }
          } else if (realStatus == 'Tahsil Edildi' || realStatus == 'Ödendi') {
            if (islemTuru.toLowerCase().contains('çek')) {
              islemTuru =
                  'Çek ${isIncoming ? 'Alındı' : 'Verildi'} ($realStatus)';
            } else if (islemTuru.toLowerCase().contains('senet')) {
              islemTuru =
                  'Senet ${isIncoming ? 'Alındı' : 'Verildi'} ($realStatus)';
            }
          }

          if (islemTuru == 'Girdi' || islemTuru == 'Tahsilat') {
            islemTuru = 'Para Alındı';
          } else if (islemTuru == 'Çıktı' || islemTuru == 'Ödeme') {
            islemTuru = 'Para Verildi';
          }

          tx['islem_turu'] = islemTuru;
        }
      }

      // [2026 FIX] Auto-expand rows if search match is in details
      _transactionAutoExpandedIndices.clear();
      if (_searchQuery.isNotEmpty) {
        for (int i = 0; i < filteredResult.length; i++) {
          if (_shouldExpandForSearch(filteredResult[i], _searchQuery)) {
            _transactionAutoExpandedIndices.add(i);
          }
        }
      }

      if (mounted) {
        setState(() {
          _cachedTransactions = filteredResult;
          _visibleTransactionIds[_currentCari.id] = filteredResult
              .map((e) => int.tryParse(e['id']?.toString() ?? '') ?? 0)
              .toList();
          _filterStats = stats;
          _odemeAlindiSum = odemeAlindi;
          _odemeYapildiSum = odemeYapildi;
          _alacakDekontuSum = alacakDekontu;
          _borcDekontuSum = borcDekontu;
          _isLoading = false;

          final bool hasFilter =
              _searchQuery.isNotEmpty ||
              _startDate != null ||
              _endDate != null ||
              _selectedTransactionType != null ||
              _selectedUser != null;

          if (hasFilter) {
            if (filteredResult.isNotEmpty && !_isManuallyClosedDuringFilter) {
              _keepDetailsOpen = true;
            }
          } else {
            _isManuallyClosedDuringFilter = false;
            _loadSettings();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reloadActiveList() async {
    if (_isInstallmentsMode) {
      await _loadInstallments();
      return;
    }
    await _loadTransactions();
  }

  Future<void> _refreshInstallmentAvailability() async {
    try {
      final has = await TaksitVeritabaniServisi().cariIcinTaksitVarMi(
        _currentCari.id,
      );
      if (!mounted) return;
      setState(() {
        _hasInstallments = has;
        if (!has && _isInstallmentsMode) {
          _isInstallmentsMode = false;
        }
      });
    } catch (e) {
      debugPrint('Error checking installments: $e');
    }
  }

  void _toggleInstallmentsMode() {
    _closeOverlay();
    final nextMode = !_isInstallmentsMode;
    setState(() {
      _isInstallmentsMode = nextMode;
      _selectedInstallmentRowId = null;
      if (nextMode) {
        _selectedRowId = null;
        _singleViewRowId = null;
        _manualExpandedIndex = null;
        _selectedDetailIds[_currentCari.id]?.clear();
        _selectedInstallmentIds[_currentCari.id]?.clear();
        _transactionAutoExpandedIndices.clear();
      } else {
        _selectedInstallmentIds[_currentCari.id]?.clear();
      }
    });
    if (nextMode) {
      _loadInstallments();
    }
  }

  bool _matchesInstallmentSearch(Map<String, dynamic> row, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final fields = <dynamic>[
      row['integration_ref'],
      row['aciklama'],
      row['durum'],
      row['tutar'],
      row['satis_fatura_no'],
      row['satis_tutar'],
      row['satis_aciklama'],
      row['satis_kullanici'],
      row['odeme_tarihi'],
      row['odeme_kaynak_turu'],
      row['odeme_kaynak_adi'],
      row['odeme_kaynak_kodu'],
      row['odeme_kullanici'],
    ];

    for (final value in fields) {
      if (value == null) continue;
      if (value.toString().toLowerCase().contains(q)) return true;
    }
    return false;
  }

  Future<void> _loadInstallments() async {
    if (_isLoading) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      DateTime? parseDate(dynamic value) {
        if (value == null) return null;
        if (value is DateTime) return value;
        return DateTime.tryParse(value.toString());
      }

      final res = await TaksitVeritabaniServisi().cariTaksitleriniGetir(
        _currentCari.id,
        baslangicTarihi: _startDate,
        bitisTarihi: _endDate,
      );

      final all = res.map((e) => Map<String, dynamic>.from(e)).toList();

      final Map<String, List<Map<String, dynamic>>> byRef = {};
      for (final row in all) {
        final ref = row['integration_ref']?.toString() ?? '';
        byRef.putIfAbsent(ref, () => []).add(row);
      }
      for (final entry in byRef.entries) {
        entry.value.sort((a, b) {
          final da = parseDate(a['vade_tarihi']) ?? DateTime(1970);
          final db = parseDate(b['vade_tarihi']) ?? DateTime(1970);
          return da.compareTo(db);
        });
        for (int i = 0; i < entry.value.length; i++) {
          entry.value[i]['taksit_sira'] = i + 1;
          entry.value[i]['taksit_toplam'] = entry.value.length;
        }
      }

      final filtered = _searchQuery.isEmpty
          ? all
          : all
                .where((row) => _matchesInstallmentSearch(row, _searchQuery))
                .toList();

      if (mounted) {
        setState(() {
          _cachedInstallments = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading installments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _currentCari = widget.cariHesap;
    _notController = TextEditingController(text: _currentCari.bilgi1);

    // Initialize all columns as visible
    _columnVisibility = {
      // Main Table
      'islem': true,
      'tarih': true,
      'tutar': true,
      'bakiye_borc': true,
      'bakiye_alacak': true,
      'ilgili_hesap': true,
      'aciklama': true,
      'vade_tarihi': true,
      'kullanici': true,
      // Detail Table
      'dt_urun_kodu': true,
      'dt_urun_adi': true,
      'dt_tarih': true,
      'dt_miktar': true,
      'dt_birim': true,
      'dt_iskonto': true,
      'dt_ham_fiyat': true,
      'dt_aciklama': true,
      'dt_fiyat': true,
      'dt_kdv': true,
      'dt_otv': true,
      'dt_oiv': true,
      'dt_tevkifat': true,
      'dt_borc': true,
      'dt_alacak': true,
      'dt_belge': true,
      'dt_e_belge': true,
      'dt_irsaliye': true,
      'dt_fatura': true,
      'dt_aciklama2': true,
    };
    _installmentColumnVisibility = {
      'islem': true,
      'satis_tarihi': true,
      'fatura_no': true,
      'vade_tarihi': true,
      'tutar': true,
      'durum': true,
      'odeme_tarihi': true,
      'odeme_hesap': true,
      'aciklama': true,
      'kullanici': true,
    };
    _loadSettings();
    _loadAvailableFilters();
    _loadTransactions();
    _refreshInstallmentAvailability();

    SayfaSenkronizasyonServisi().addListener(_onGlobalSync);

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (_searchController.text != _searchQuery) {
          setState(() {
            _searchQuery = _searchController.text.toLowerCase();
          });
          _reloadActiveList();
        }
      });
    });
  }

  void _onGlobalSync() {
    _refreshCariDetails();
    _refreshInstallmentAvailability();
    _reloadActiveList();
  }

  /// Cari hesap detaylarını ve bakiyesini veritabanından yenile
  Future<CariHesapModel?> _refreshCariDetails() async {
    try {
      final updatedCari = await CariHesaplarVeritabaniServisi().cariHesapGetir(
        _currentCari.id,
      );
      if (updatedCari != null) {
        if (mounted) {
          setState(() {
            _currentCari = updatedCari;
          });
        }
        return updatedCari;
      }
    } catch (e) {
      debugPrint('Cari detayları yenilenirken hata: $e');
    }
    return null;
  }

  void _resetPagination() {
    setState(() {
      // Pagination reset if it was active
    });
  }

  Future<void> _fetchCariHesaplar() async {
    await _refreshCariDetails();
    await _reloadActiveList();
  }

  Future<void> _cariDurumDegistir(CariHesapModel cari, bool aktifMi) async {
    try {
      final updatedCari = cari.copyWith(aktifMi: aktifMi);
      await CariHesaplarVeritabaniServisi().cariHesapGuncelle(updatedCari);
      await _refreshCariDetails();
      if (mounted) {
        MesajYardimcisi.basariGoster(
          context,
          aktifMi ? tr('common.active_success') : tr('common.passive_success'),
        );
      }
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    }
  }

  int _getTransactionDetailItemCount(Map<String, dynamic> tx) {
    final iTur = tx['islem_turu']?.toString() ?? '';
    final yon = tx['yon']?.toString().toLowerCase() ?? '';
    final integrationRef = tx['integration_ref']?.toString() ?? '';
    final label = IslemTuruRenkleri.getProfessionalLabel(iTur, context: 'cari');

    // Ödeme Alındı / Ödeme Yapıldı satırlarında detay satırı olmasın (Para Alındı gibi)
    final lowerTur = iTur.toLowerCase();
    final bool isOdemeAlindi =
        lowerTur.contains('ödeme alındı') || lowerTur.contains('odeme alindi');
    final bool isOdemeYapildi =
        lowerTur.contains('ödeme yapıldı') ||
        lowerTur.contains('odeme yapildi');
    final bool isSalePayment =
        integrationRef.startsWith('SALE-') && yon.contains('alacak');
    final bool isPurchasePayment =
        integrationRef.startsWith('PURCHASE-') &&
        (yon.contains('borç') || yon.contains('borc'));

    if (isOdemeAlindi || isOdemeYapildi || isSalePayment || isPurchasePayment) {
      return 0;
    }

    if (iTur.contains('Açılış') ||
        iTur == 'Cari İşlem' ||
        label == 'Cari İşlem' ||
        label == 'Para Alındı' ||
        label == 'Para Verildi' ||
        label == 'Borç Dekontu' ||
        label == 'Alacak Dekontu' ||
        iTur.contains('Dekont') ||
        label.contains('Çek') ||
        label.contains('Senet')) {
      return 0;
    }
    return 1;
  }

  bool _isTransactionExpandable(Map<String, dynamic> tx) =>
      _getTransactionDetailItemCount(tx) > 0;

  Set<int> _getAllExpandableTransactionIndices() {
    final indices = <int>{};
    for (int i = 0; i < _cachedTransactions.length; i++) {
      if (_isTransactionExpandable(_cachedTransactions[i])) {
        indices.add(i);
      }
    }
    return indices;
  }

  Set<int> _getEffectiveTransactionExpandedIndices() {
    final base = _keepDetailsOpen
        ? _getAllExpandableTransactionIndices()
        : _transactionAutoExpandedIndices;

    if (base.isEmpty) return base;

    final filtered = <int>{};
    for (final index in base) {
      if (index >= 0 &&
          index < _cachedTransactions.length &&
          _isTransactionExpandable(_cachedTransactions[index])) {
        filtered.add(index);
      }
    }
    return filtered;
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
      if (mounted) {
        MesajYardimcisi.basariGoster(
          context,
          tr('common.deleted_successfully'),
        );
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
    if (mounted) {
      setState(() {
        _keepDetailsOpen =
            prefs.getBool('cari_karti_keep_details_open') ?? false;
        _genelAyarlar = settings;
      });
    }
  }

  Future<void> _toggleKeepDetailsOpen() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _keepDetailsOpen = !_keepDetailsOpen;

      final bool hasFilter =
          _searchQuery.isNotEmpty ||
          _startDate != null ||
          _endDate != null ||
          _selectedTransactionType != null ||
          _selectedUser != null;

      if (!_keepDetailsOpen) {
        if (hasFilter) {
          _isManuallyClosedDuringFilter = true;
        }
        _transactionAutoExpandedIndices.clear();
      } else {
        _isManuallyClosedDuringFilter = false;
      }
    });
    await prefs.setBool('cari_karti_keep_details_open', _keepDetailsOpen);
  }

  Future<void> _loadAvailableFilters() async {
    // Cari Kartı'nda sadece tarih filtresi aktif kalacak
  }

  @override
  void dispose() {
    SayfaSenkronizasyonServisi().removeListener(_onGlobalSync);
    _searchController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _notController.dispose();
    _ekstreHorizontalScrollController.dispose();
    _searchFocusNode.dispose();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _debounce?.cancel();
    super.dispose();
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _isTransactionTypeFilterExpanded = false;
        _isUserFilterExpanded = false;
      });
    }
  }

  /// Tablo seçimlerini temizler (Enter ile genişletme için gerekli)
  void _clearAllTableSelections() {
    setState(() {
      _selectedRowId = null;
      _selectedInstallmentRowId = null;
      _selectedDetailIds[_currentCari.id]?.clear();
      _selectedInstallmentIds[_currentCari.id]?.clear();
    });
  }

  String _formatPrintDate(dynamic value, {bool includeTime = true}) {
    if (value == null) return '';
    try {
      DateTime? dt;
      if (value is DateTime) {
        dt = value;
      } else if (value is String) {
        dt = DateTime.tryParse(value);
      }
      if (dt == null) return value.toString();
      final format = includeTime ? 'dd.MM.yyyy HH:mm' : 'dd.MM.yyyy';
      return DateFormat(format).format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  Future<void> _handlePrint() async {
    setState(() => _isLoading = true);
    try {
      // 1. HEADER INFO: Cari Bilgilerini Başlık Kartı olarak hazırla
      final cari = _currentCari;
      final Map<String, dynamic> headerInfo = {
        'images': cari.resimler,
        'name': cari.adi,
        'code': cari.kodNo,
        'phone1': cari.telefon1,
        'phone2': cari.telefon2,
        'email': cari.eposta,
        'website': cari.webAdresi,
        'fatUnvani': cari.fatUnvani,
        'fatAdresi': cari.fatAdresi,
        'postaKodu': cari.postaKodu,
        'fatSehir': cari.fatSehir,
        'taxOffice': cari.vDairesi,
        'taxNo': cari.vNumarasi,
        'riskLimit': cari.riskLimiti,
        'ozelBilgi1': cari.bilgi1,
        'ozelBilgi2': cari.bilgi2,
        'ozelBilgi3': cari.bilgi3,
        'ozelBilgi4': cari.bilgi4,
        'ozelBilgi5': cari.bilgi5,
        'isExpanded': _isInfoCardExpanded,
        'currency': cari.paraBirimi,
        'totalStock': FormatYardimcisi.sayiFormatlaOndalikli(
          (cari.bakiyeBorc - cari.bakiyeAlacak).abs(),
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.fiyatOndalik,
        ),
        'totalStockLabel':
            '${(cari.bakiyeBorc - cari.bakiyeAlacak) >= 0 ? tr('accounts.table.type_debit') : tr('accounts.table.type_credit')} ${cari.paraBirimi}',
        'odemeYapildiSum': _odemeYapildiSum,
        'borcDekontuSum': _borcDekontuSum,
        'odemeAlindiSum': _odemeAlindiSum,
        'alacakDekontuSum': _alacakDekontuSum,
        'netBalance': (cari.bakiyeBorc - cari.bakiyeAlacak),
      };

      if (_isInstallmentsMode) {
        final selectedInstallmentIds =
            _selectedInstallmentIds[_currentCari.id] ?? <int>{};

        final List<String> headers = [
          tr('products.transaction.type'),
          tr('accounts.card.installments.col.sale_date'),
          tr('sale.complete.field.invoice_no'),
          tr('common.due_date_short'),
          tr('accounts.card.installments.col.installment_amount'),
          tr('common.status'),
          tr('accounts.card.installments.col.payment_date'),
          tr('accounts.card.installments.col.payment_account'),
          tr('common.description'),
          tr('common.user'),
        ];

        final List<ExpandableRowData> rows = [];

        for (final row in _cachedInstallments) {
          if (selectedInstallmentIds.isNotEmpty) {
            final int? installmentId = row['id'] is int
                ? row['id'] as int
                : int.tryParse(row['id']?.toString() ?? '');
            if (installmentId == null ||
                !selectedInstallmentIds.contains(installmentId)) {
              continue;
            }
          }

          final int sira =
              int.tryParse(row['taksit_sira']?.toString() ?? '') ?? 0;
          final int toplam =
              int.tryParse(row['taksit_toplam']?.toString() ?? '') ?? 0;

          final String taksitLabel = sira > 0 && toplam > 0
              ? '${tr('accounts.card.installments.installment')} $sira/$toplam'
              : tr('accounts.card.installments.installment');

          final String satisTarihi = _formatPrintDate(
            row['satis_tarihi'],
            includeTime: true,
          );
          final String faturaNo = row['satis_fatura_no']?.toString() ?? '-';
          final String vadeTarihi = _formatPrintDate(
            row['vade_tarihi'],
            includeTime: false,
          );

          final double tutar =
              double.tryParse(row['tutar']?.toString() ?? '') ?? 0.0;
          final String tutarStr =
              '${FormatYardimcisi.sayiFormatlaOndalikli(tutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_currentCari.paraBirimi}';

          final String durum = row['durum']?.toString() ?? '';

          final String odemeTarihiRaw = row['odeme_tarihi']?.toString() ?? '';
          final String odemeTarihi = odemeTarihiRaw.isNotEmpty
              ? _formatPrintDate(row['odeme_tarihi'], includeTime: true)
              : '-';

          final String odemeKaynakAdi =
              row['odeme_kaynak_adi']?.toString() ?? '';
          final String odemeKaynakKodu =
              row['odeme_kaynak_kodu']?.toString() ?? '';
          final String odemeKaynakTuru =
              row['odeme_kaynak_turu']?.toString() ?? '';

          String odemeHesap = '-';
          if (odemeKaynakAdi.isNotEmpty || odemeKaynakTuru.isNotEmpty) {
            odemeHesap = odemeKaynakAdi.isNotEmpty
                ? odemeKaynakAdi
                : IslemCeviriYardimcisi.cevir(odemeKaynakTuru);
            if (odemeKaynakKodu.isNotEmpty) odemeHesap += ' $odemeKaynakKodu';
            if (odemeKaynakTuru.isNotEmpty && odemeKaynakAdi.isNotEmpty) {
              odemeHesap +=
                  ' (${IslemCeviriYardimcisi.cevir(odemeKaynakTuru)})';
            }
          }

          final String aciklama = row['aciklama']?.toString() ?? '';
          final String kullanici =
              (row['odeme_kullanici']?.toString() ?? '').isNotEmpty
              ? row['odeme_kullanici']?.toString() ?? ''
              : (row['satis_kullanici']?.toString() ?? '');

          rows.add(
            ExpandableRowData(
              mainRow: [
                taksitLabel,
                satisTarihi,
                faturaNo,
                vadeTarihi,
                tutarStr,
                durum,
                odemeTarihi,
                odemeHesap,
                aciklama,
                kullanici,
              ],
              details: {},
              transactions: null,
              isExpanded: false,
            ),
          );
        }

        if (mounted) setState(() => _isLoading = false);
        if (!mounted) return;

        String? dateInfo;
        final df = DateFormat('dd.MM.yyyy');
        if (_startDate != null && _endDate != null) {
          dateInfo =
              '${tr('common.date_range')}: ${df.format(_startDate!)} - ${df.format(_endDate!)}';
        } else if (_startDate != null) {
          dateInfo =
              '${tr('common.date_range')}: ${df.format(_startDate!)} - ...';
        }

        final List<CustomContentToggle> headerToggles = [
          CustomContentToggle(key: 'h_logo', label: tr('accounts.column.logo')),
          CustomContentToggle(key: 'h_name', label: tr('common.name')),
          CustomContentToggle(key: 'h_code', label: tr('common.code')),
          CustomContentToggle(key: 'h_phone', label: tr('common.phone')),
          CustomContentToggle(
            key: 'h_email',
            label: tr('accounts.card.email_web'),
          ),
          CustomContentToggle(
            key: 'h_invoice',
            label: tr('accounts.card.invoice_tax_info'),
          ),
          CustomContentToggle(
            key: 'h_special',
            label: tr('accounts.card.special_info_fields'),
          ),
          CustomContentToggle(
            key: 'h_balance',
            label: tr('accounts.table.balance'),
          ),
          CustomContentToggle(
            key: 'h_bal_pay_made',
            label: tr('accounts.card.summary.payment_made'),
          ),
          CustomContentToggle(
            key: 'h_bal_deb_note',
            label: tr('accounts.card.summary.debit_note'),
          ),
          CustomContentToggle(
            key: 'h_bal_pay_rec',
            label: tr('accounts.card.summary.payment_received'),
          ),
          CustomContentToggle(
            key: 'h_bal_cre_note',
            label: tr('accounts.card.summary.credit_note'),
          ),
          CustomContentToggle(
            key: 'h_bal_net',
            label: tr('accounts.card.summary.net_balance'),
          ),
        ];

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GenisletilebilirPrintPreviewScreen(
              title: tr('accounts.title'),
              headers: headers,
              data: rows,
              dateInterval: dateInfo,
              initialShowDetails: false,
              headerInfo: headerInfo,
              mainTableLabel: tr('accounts.card.installments'),
              detailTableLabel: tr('common.products'),
              headerToggles: headerToggles,
            ),
          ),
        );
        return;
      }

      // 2. MAIN TABLE = TRANSACTIONS
      // Datatable'da ne görüyorsak (filtrelenmiş _cachedTransactions) onu basacağız.
      // Sütunlar Datatable ile birebir aynı olmalı (İşlemler hariç).
      final List<String> headers = [
        'İşlem',
        tr('common.date'),
        tr('common.amount'),
        'Bakiye Borç', // Screen matches exactly
        'Bakiye Alacak', // Screen matches exactly
        'İlgili Hesap', // Explicitly requested "İlgili Hesap"
        'Vad. Tarihi', // Screen matches exactly
        'Kul.',
        tr('common.description'), // Açıklama
      ];

      List<ExpandableRowData> rows = [];

      final Set<int> selectedIds = _selectedDetailIds[_currentCari.id] ?? {};
      final expandedIndices = _getEffectiveTransactionExpandedIndices();

      for (int i = 0; i < _cachedTransactions.length; i++) {
        final tx = _cachedTransactions[i];

        // [2026 FIX] Filter if specific rows are selected
        if (selectedIds.isNotEmpty) {
          final int? id = tx['id'] is int
              ? tx['id'] as int
              : int.tryParse(tx['id']?.toString() ?? '');
          if (id != null && !selectedIds.contains(id)) {
            continue;
          }
        }

        // 1. Temel Veriler
        final rawIslemTuru = tx['islem_turu']?.toString() ?? '';
        final String aciklamaRaw = rawIslemTuru.contains('Açılış')
            ? ''
            : (tx['aciklama']?.toString() ?? '');

        final double tutar =
            double.tryParse(tx['tutar']?.toString() ?? '') ?? 0.0;
        final String yon = tx['yon']?.toString().toLowerCase() ?? '';
        final bool isBorc =
            yon.contains('borç') || yon.contains('borc') || yon == 'borc';

        final double runningBalance =
            double.tryParse(tx['running_balance']?.toString() ?? '') ?? 0.0;

        final String borcStr = runningBalance > 0
            ? '${FormatYardimcisi.sayiFormatlaOndalikli(runningBalance.abs(), binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_currentCari.paraBirimi}'
            : '-';

        final String alacakStr = runningBalance < 0
            ? '${FormatYardimcisi.sayiFormatlaOndalikli(runningBalance.abs(), binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_currentCari.paraBirimi}'
            : '-';

        // 2. İşlem Türü Label & Suffix
        final String islemLabel = IslemCeviriYardimcisi.cevir(
          IslemTuruRenkleri.getProfessionalLabel(
            rawIslemTuru,
            context: 'cari',
            yon: tx['yon']?.toString(),
          ),
        );

        // Kaynak bilgilerini hazırla
        String locationName =
            tx['kaynak_adi']?.toString() ?? tx['yer']?.toString() ?? '';
        String locationCode = tx['kaynak_kodu']?.toString() ?? '';
        final sourceId = tx['source_id'] is int
            ? tx['source_id'] as int
            : int.tryParse(tx['source_id']?.toString() ?? '');

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
          tx['integration_ref']?.toString(),
          locationName,
        );
        if (sourceSuffix.isNotEmpty) {
          suffixLabel =
              ' ${IslemCeviriYardimcisi.parantezliKaynakKisaltma(sourceSuffix)}';
        }

        // 3. İlgili Hesap İnşası
        String ilgiliHesapGosterim = '';
        if (rawIslemTuru.contains('Çek') || rawIslemTuru.contains('Senet')) {
          ilgiliHesapGosterim = locationName.contains('\n')
              ? locationName.split('\n').first
              : locationName;
        } else if (locationName.isNotEmpty) {
          ilgiliHesapGosterim = locationName;
        } else if (rawIslemTuru == 'Kasa' ||
            rawIslemTuru == 'Banka' ||
            rawIslemTuru == 'Kredi Kartı') {
          ilgiliHesapGosterim = IslemCeviriYardimcisi.cevir(rawIslemTuru);
        } else {
          ilgiliHesapGosterim = '-';
        }

        String suffixDetails = '';
        if (rawIslemTuru.contains('Çek') || rawIslemTuru.contains('Senet')) {
          final badgeParts = locationName
              .split('\n')
              .map((s) => s.trim())
              .where(
                (s) =>
                    s.isNotEmpty &&
                    !s.toLowerCase().contains(_currentCari.adi.toLowerCase()),
              )
              .toSet();
          if (badgeParts.isNotEmpty) {
            suffixDetails = ' (${badgeParts.join(', ')})';
          }
        } else if (locationName.isNotEmpty || locationCode.isNotEmpty) {
          final typeLabel = IslemCeviriYardimcisi.cevir(
            (rawIslemTuru == 'Kasa' ||
                    rawIslemTuru == 'Banka' ||
                    rawIslemTuru == 'Kredi Kartı')
                ? (isBorc ? 'Para Verildi' : 'Para Alındı')
                : rawIslemTuru,
          );
          suffixDetails =
              ' ($typeLabel${locationCode.isNotEmpty ? " $locationCode" : ""})';
        }
        ilgiliHesapGosterim += suffixDetails;

        // 4. Vade Tarihi İnşası
        final vt =
            rawIslemTuru.contains('Çek') || rawIslemTuru.contains('Senet')
            ? tx['tarih']
            : tx['vade_tarihi'];
        String vtStr = '-';
        if (vt != null && vt.toString().isNotEmpty) {
          try {
            DateTime? dtVt;
            if (vt is DateTime) {
              dtVt = vt;
            } else {
              dtVt = DateTime.tryParse(vt.toString());
            }

            if (dtVt != null) {
              vtStr = DateFormat('dd.MM.yyyy').format(dtVt);
              if (rawIslemTuru.contains('Çek') ||
                  rawIslemTuru.contains('Senet')) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final vade = DateTime(dtVt.year, dtVt.month, dtVt.day);
                final diff = vade.difference(today).inDays;

                if (diff < 0) {
                  vtStr += ' (${diff.abs()} Gün Geçti)';
                } else if (diff == 0) {
                  vtStr += ' (Bugün)';
                } else {
                  vtStr += ' ($diff Gün Kaldı)';
                }
              }
            }
          } catch (_) {}
        }

        final mainRow = [
          islemLabel + suffixLabel,
          _formatPrintDate(tx['tarih']),
          '${FormatYardimcisi.sayiFormatlaOndalikli(tutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_currentCari.paraBirimi}',
          borcStr,
          alacakStr,
          ilgiliHesapGosterim,
          vtStr,
          tx['kullanici']?.toString() ?? '',
          tx['aciklama']?.toString() ?? '', // Açıklama
        ];

        // 3. SUB-DETAILS (Products / Items)
        // Eğer işlem detaylı bir işlemse (Satış, Alış, Sipariş vb.) kalemleri çek.
        DetailTable? subTable;
        if (_isTransactionExpandable(tx)) {
          final String ref = tx['integration_ref']?.toString() ?? '';
          if (ref.isNotEmpty) {
            try {
              final items = await _entegrasyonKalemleriniYukle(ref);
              if (items.isNotEmpty) {
                subTable = DetailTable(
                  title: tr('common.last_movements'), // "Son Hareketler"
                  headers: [
                    tr('accounts.statement.col.product_code_short'), // Ü.Kod
                    tr('shipment.field.name'), // Ürün Adı
                    tr('common.date'), // Tarih
                    '${tr('common.quantity')} ${tr('common.unit')}', // Miktar Birim
                    tr('common.discount_percent_short'), // İsk %
                    tr('common.raw_price_short'), // Ham Fiyat
                    tr('common.description'), // Açıklama
                    tr('shipment.field.price'), // Birim Fiyat
                    'KDV', // KDV
                    tr('accounts.table.type_debit'), // Borç
                    tr('accounts.table.type_credit'), // Alacak
                    tr('purchase.complete.field.document'), // Belge
                    tr(
                      'settings.general.option.documents.eDocument',
                    ), // E-Belge
                    tr('purchase.complete.field.waybill_no'), // İrsaliye No
                    tr('purchase.complete.field.invoice_no'), // Fatura No
                    tr('common.description2'), // Açıklama 2
                  ],
                  data: items.map((item) {
                    final double dMiktar = item.quantity;
                    final double dBirimFiyat = item.unitPrice;
                    final double dIskonto = item.discountRate;

                    final double vatAmount = item.vatAmount;
                    final double lineTotal = item.total;

                    final bool isBorc =
                        yon.contains('borç') ||
                        yon.contains('borc') ||
                        yon == 'borc';

                    return [
                      item.code,
                      item.name,
                      _formatPrintDate(tx['tarih'], includeTime: false),
                      '${FormatYardimcisi.sayiFormatla(dMiktar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.miktarOndalik)} ${item.unit}',
                      '%${FormatYardimcisi.sayiFormatlaOndalikli(dIskonto)}',
                      (FormatYardimcisi.sayiFormatlaOndalikli(
                        item.netUnitPrice,
                      )),
                      tx['aciklama']?.toString() ?? '',
                      (FormatYardimcisi.sayiFormatlaOndalikli(dBirimFiyat)),
                      '${FormatYardimcisi.sayiFormatlaOndalikli(vatAmount)} (%${FormatYardimcisi.sayiFormatlaOndalikli(item.vatRate, decimalDigits: 0)})',
                      isBorc
                          ? '${FormatYardimcisi.sayiFormatlaOndalikli(lineTotal)} ${_currentCari.paraBirimi}'
                          : '-',
                      !isBorc
                          ? '${FormatYardimcisi.sayiFormatlaOndalikli(lineTotal)} ${_currentCari.paraBirimi}'
                          : '-',
                      tx['belge_no']?.toString() ?? '',
                      tx['e_belge_no']?.toString() ?? '',
                      tx['irsaliye_no']?.toString() ?? '',
                      tx['fatura_no']?.toString() ?? '',
                      tx['aciklama2']?.toString() ?? '',
                    ];
                  }).toList(),
                );
              }
            } catch (e) {
              debugPrint('Error loading print details for $ref: $e');
            }
          }
        }

        rows.add(
          ExpandableRowData(
            mainRow: mainRow,
            details:
                {}, // Cari kartında işlem satırının "key-value" detayı genelde yoktur, alt tablosu vardır.
            transactions: subTable, // Ürün listesi buraya
            isExpanded: expandedIndices.contains(i),
          ),
        );
      }

      if (mounted) setState(() => _isLoading = false);

      if (!mounted) return;

      String? dateInfo;
      final df = DateFormat('dd.MM.yyyy');
      if (_startDate != null && _endDate != null) {
        dateInfo =
            '${tr('common.date_range')}: ${df.format(_startDate!)} - ${df.format(_endDate!)}';
      } else if (_startDate != null) {
        dateInfo =
            '${tr('common.date_range')}: ${df.format(_startDate!)} - ...';
      }

      if (_selectedTransactionType != null) {
        final txInfo =
            '${tr('accounts.table.transaction_type')}: ${IslemCeviriYardimcisi.cevir(_selectedTransactionType!)}';
        dateInfo = dateInfo == null ? txInfo : '$dateInfo | $txInfo';
      }

      if (_selectedUser != null) {
        final userInfo = '${tr('common.user')}: $_selectedUser';
        dateInfo = dateInfo == null ? userInfo : '$dateInfo | $userInfo';
      }

      final List<CustomContentToggle> headerToggles = [
        CustomContentToggle(key: 'h_logo', label: tr('accounts.column.logo')),
        CustomContentToggle(key: 'h_name', label: tr('common.name')),
        CustomContentToggle(key: 'h_code', label: tr('common.code')),
        CustomContentToggle(key: 'h_phone', label: tr('common.phone')),
        CustomContentToggle(
          key: 'h_email',
          label: tr('accounts.card.email_web'),
        ),
        CustomContentToggle(
          key: 'h_invoice',
          label: tr('accounts.card.invoice_tax_info'),
        ),
        CustomContentToggle(
          key: 'h_special',
          label: tr('accounts.card.special_info_fields'),
        ),
        CustomContentToggle(
          key: 'h_balance',
          label: tr('accounts.table.balance'),
        ),
        // Granular Balance Toggles
        CustomContentToggle(
          key: 'h_bal_pay_made',
          label: tr('accounts.card.summary.payment_made'),
        ),
        CustomContentToggle(
          key: 'h_bal_deb_note',
          label: tr('accounts.card.summary.debit_note'),
        ),
        CustomContentToggle(
          key: 'h_bal_pay_rec',
          label: tr('accounts.card.summary.payment_received'),
        ),
        CustomContentToggle(
          key: 'h_bal_cre_note',
          label: tr('accounts.card.summary.credit_note'),
        ),
        CustomContentToggle(
          key: 'h_bal_net',
          label: tr('accounts.card.summary.net_balance'),
        ),
      ];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GenisletilebilirPrintPreviewScreen(
            title: tr('accounts.title'), // "Cari Hesaplar"
            headers: headers,
            data: rows,
            dateInterval: dateInfo,
            initialShowDetails: true,
            headerInfo: headerInfo,
            mainTableLabel: tr('common.last_movements'),
            detailTableLabel: tr('common.products'),
            headerToggles: headerToggles,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  /// Tek bir işlemi siler
  Future<void> _deleteTransaction(int transactionId) async {
    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr(
          'common.confirm_delete_named',
        ).replaceAll('{name}', 'Bu işlem'),
        onOnay: () {},
        isDestructive: true,
        onayButonMetni: tr('common.delete'),
      ),
    );

    if (onay == true) {
      try {
        // Önce işlem bilgilerini al
        final transactions = await CariHesaplarVeritabaniServisi()
            .cariIslemleriniGetir(_currentCari.id);
        final tx = transactions.firstWhere(
          (t) => t['id'] == transactionId,
          orElse: () => <String, dynamic>{},
        );

        if (tx.isEmpty) {
          if (!mounted) return;
          MesajYardimcisi.hataGoster(
            context,
            tr('accounts.card.error.transaction_not_found'),
          );
          return;
        }

        final String islemTuru = tx['islem_turu']?.toString() ?? '';
        final String integrationRef = tx['integration_ref']?.toString() ?? '';

        final String islemTuruLower = islemTuru.toLowerCase();
        final bool isSaleMasterTx =
            integrationRef.startsWith('SALE-') &&
            (islemTuruLower.contains('satış yapıldı') ||
                islemTuruLower.contains('satis yapildi'));
        final bool isPurchaseMasterTx =
            integrationRef.startsWith('PURCHASE-') &&
            (islemTuruLower.contains('alış yapıldı') ||
                islemTuruLower.contains('alis yapildi'));

        // Satış/Alış işlemlerinde sadece cari kaydını silmek yetmez;
        // stok/depodaki hareketler (Ürünler/Üretimler ekranı) de entegrasyon ref ile temizlenmeli.
        if (integrationRef.isNotEmpty && isSaleMasterTx) {
          await SatisYapVeritabaniServisi().satisIsleminiSil(integrationRef);
        } else if (integrationRef.isNotEmpty && isPurchaseMasterTx) {
          await AlisYapVeritabaniServisi().alisIsleminiSil(integrationRef);
        } else {
          final double tutar =
              double.tryParse(tx['tutar']?.toString() ?? '') ?? 0.0;
          final String yonRaw = tx['yon']?.toString().toLowerCase() ?? '';
          final bool isBorc =
              yonRaw.contains('borç') || yonRaw.contains('borc');
          final int? sourceId = tx['source_id'] as int?;

          await CariHesaplarVeritabaniServisi().cariIslemSil(
            _currentCari.id,
            tutar,
            isBorc,
            kaynakTur: islemTuru,
            kaynakId: sourceId,
            transactionId: transactionId, // ID eklendi
          );
        }

        if (!mounted) return;
        SayfaSenkronizasyonServisi().veriDegisti('cari');
        await _refreshCariDetails();
        await _loadTransactions();
      } catch (e) {
        if (!mounted) return;
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    }
  }

  /// Seçili işlemleri toplu siler
  Future<void> _deleteSelectedTransactions() async {
    final selectedIds = _selectedDetailIds[_currentCari.id] ?? <int>{};
    if (selectedIds.isEmpty && !_isSelectAllActive) return;

    final count = _isSelectAllActive ? _totalRecords : selectedIds.length;

    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (context) => OnayDialog(
        baslik: tr('common.confirmation'),
        mesaj: tr(
          'common.confirm_delete_named',
        ).replaceAll('{name}', '$count işlem'),
        onOnay: () {},
        isDestructive: true,
        onayButonMetni: tr('common.delete'),
      ),
    );

    if (onay == true) {
      try {
        // Satış/Alış entegrasyonları varsa önce ref bazlı tam sil (stok/depodaki kayıtlar dahil)
        final txById = <int, Map<String, dynamic>>{};
        for (final tx in _cachedTransactions) {
          final int? id = tx['id'] is int
              ? tx['id'] as int
              : int.tryParse(tx['id']?.toString() ?? '');
          if (id != null) {
            txById[id] = tx;
          }
        }

        final saleRefsToDelete = <String>{};
        final purchaseRefsToDelete = <String>{};
        for (final id in selectedIds) {
          final tx = txById[id];
          if (tx == null) continue;
          final String islemTuru = tx['islem_turu']?.toString() ?? '';
          final String integrationRef = tx['integration_ref']?.toString() ?? '';
          if (integrationRef.isEmpty) continue;

          final String islemTuruLower = islemTuru.toLowerCase();
          final bool isSaleMasterTx =
              integrationRef.startsWith('SALE-') &&
              (islemTuruLower.contains('satış yapıldı') ||
                  islemTuruLower.contains('satis yapildi'));
          final bool isPurchaseMasterTx =
              integrationRef.startsWith('PURCHASE-') &&
              (islemTuruLower.contains('alış yapıldı') ||
                  islemTuruLower.contains('alis yapildi'));

          if (isSaleMasterTx) {
            saleRefsToDelete.add(integrationRef);
          } else if (isPurchaseMasterTx) {
            purchaseRefsToDelete.add(integrationRef);
          }
        }

        for (final ref in saleRefsToDelete) {
          await SatisYapVeritabaniServisi().satisIsleminiSil(ref);
        }
        for (final ref in purchaseRefsToDelete) {
          await AlisYapVeritabaniServisi().alisIsleminiSil(ref);
        }

        // F-L-D-U: Field-Level Delta Update Optimization
        // Tek tek silmek yerine, toplu silme servisini kullanıyoruz.
        await CariHesaplarVeritabaniServisi().topluCariIslemSil(
          cariId: _currentCari.id,
          transactionIds: selectedIds.toList(),
        );

        setState(() {
          _selectedDetailIds[_currentCari.id]?.clear();
          _isSelectAllActive = false;
        });

        if (!mounted) return;
        SayfaSenkronizasyonServisi().veriDegisti('cari');
        MesajYardimcisi.basariGoster(
          context,
          tr('common.deleted_successfully'),
        );
        _loadTransactions();
        _refreshCariDetails();
      } catch (e) {
        if (!mounted) return;
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    }
  }

  void _onActionSelected(String value, Map<String, dynamic> tx) async {
    if (value == 'edit') {
      final islemTuru = tx['islem_turu']?.toString() ?? '';
      final integrationRef = tx['integration_ref']?.toString() ?? '';
      final String yonLower = (tx['yon']?.toString() ?? '').toLowerCase();
      final islemTuruLower = islemTuru.toLowerCase();
      final bool isSaleMasterTx =
          integrationRef.startsWith('SALE-') &&
          (islemTuruLower.contains('satış yapıldı') ||
              islemTuruLower.contains('satis yapildi'));
      final bool isPurchaseMasterTx =
          integrationRef.startsWith('PURCHASE-') &&
          (islemTuruLower.contains('alış yapıldı') ||
              islemTuruLower.contains('alis yapildi'));

      // Sadece Açılış Devri işlemleri için özel düzenleme sayfasını aç
      if (islemTuru.contains('Açılış')) {
        final double tutar =
            double.tryParse(tx['tutar']?.toString() ?? '') ?? 0.0;
        final String yonRaw = tx['yon']?.toString().toLowerCase() ?? '';
        final bool isBorc = yonRaw.contains('borç') || yonRaw.contains('borc');
        final double kur = double.tryParse(tx['kur']?.toString() ?? '') ?? 1.0;
        final String aciklama = tx['aciklama']?.toString() ?? '';

        final result = await showDialog<bool>(
          context: context,
          builder: (context) => CariAcilisDevriDuzenleSayfasi(
            transactionId: tx['id'] as int,
            cariHesap: _currentCari,
            currentAmount: tutar,
            isBorc: isBorc,
            currentKur: kur,
            description: aciklama,
          ),
        );

        if (result == true) {
          await _refreshCariDetails();
          await _loadTransactions();
          _fetchCariHesaplar();
        }
      } else if (isSaleMasterTx || isPurchaseMasterTx) {
        final bool isSale = isSaleMasterTx;
        final String ref = integrationRef.trim();
        if (ref.isEmpty) {
          MesajYardimcisi.hataGoster(context, tr('common.error'));
          return;
        }

        // Loading overlay (short) to avoid "dondu" hissi
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
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

        List<TransactionItem> items = [];
        try {
          items = await _entegrasyonKalemleriniYukle(ref);
        } finally {
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }

        if (!mounted) return;

        if (items.isEmpty) {
          MesajYardimcisi.hataGoster(context, tr('common.no_data'));
          return;
        }

        final String initialCurrency = (items.first.currency == 'TL')
            ? 'TRY'
            : items.first.currency;
        final double initialRate = items.first.exchangeRate;

        final Map<String, dynamic> duzenlemeIslemi = Map<String, dynamic>.from(
          tx,
        );

        final tabScope = TabAciciScope.of(context);
        if (tabScope != null) {
          tabScope.tabAc(
            menuIndex: isSale ? 11 : 10,
            initialCari: _currentCari,
            initialItems: items,
            initialCurrency: initialCurrency,
            initialDescription: tx['aciklama']?.toString(),
            initialRate: initialRate,
            duzenlenecekIslem: duzenlemeIslemi,
          );
          return;
        }

        final Widget page = isSale
            ? SatisYapSayfasi(
                initialCari: _currentCari,
                initialItems: items,
                initialCurrency: initialCurrency,
                initialDescription: tx['aciklama']?.toString(),
                initialRate: initialRate,
                duzenlenecekIslem: duzenlemeIslemi,
              )
            : AlisYapSayfasi(
                initialCari: _currentCari,
                initialItems: items,
                initialCurrency: initialCurrency,
                initialDescription: tx['aciklama']?.toString(),
                initialRate: initialRate,
                duzenlenecekIslem: duzenlemeIslemi,
              );

        if (!mounted) return;

        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (context) => page),
        );

        if (!mounted) return;

        if (result == true) {
          await _refreshCariDetails();
          await _loadTransactions();
        }
      } else if (islemTuru == 'Para Alındı' ||
          islemTuru == 'Para Verildi' ||
          islemTuru == 'Borç Dekontu' ||
          islemTuru == 'Alacak Dekontu' ||
          (integrationRef.startsWith('SALE-') &&
              yonLower.contains('alacak') &&
              ((tx['aciklama']?.toString().toLowerCase() ?? '').contains(
                    'peşinat',
                  ) ||
                  (tx['aciklama']?.toString().toLowerCase() ?? '').contains(
                    'pesinat',
                  )))) {
        // [2025 FIX] Unique key ile her düzenleme için yeni State oluştur
        final int txId =
            tx['id'] as int? ?? DateTime.now().millisecondsSinceEpoch;

        Widget page;
        if (islemTuru == 'Borç Dekontu' || islemTuru == 'Alacak Dekontu') {
          page = BorcAlacakDekontuIsleSayfasi(
            key: ValueKey('dekont_edit_$txId'),
            cari: _currentCari,
            duzenlenecekIslem: Map<String, dynamic>.from(tx),
          );
        } else {
          page = CariParaAlVerSayfasi(
            key: ValueKey('para_al_ver_edit_$txId'),
            cari: _currentCari,
            duzenlenecekIslem: Map<String, dynamic>.from(tx), // Deep copy
          );
        }

        final result = await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => page,
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
          await _refreshCariDetails();
          await _loadTransactions();
          _fetchCariHesaplar();
        }
      } else {
        // Diğer işlemler için
        MesajYardimcisi.bilgiGoster(
          context,
          tr('accounts.card.info.edit_from_source_module'),
        );
      }
    } else if (value == 'delete') {
      _deleteTransaction(tx['id'] as int);
    }
  }

  Future<List<TransactionItem>> _entegrasyonKalemleriniYukle(String ref) async {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      final text = value.toString().trim();
      if (text.isEmpty) return 0.0;
      final normalized = text
          .replaceAll(',', '.')
          .replaceAll('%', '')
          .replaceAll(RegExp(r'\s+'), '');
      return double.tryParse(normalized) ?? 0.0;
    }

    double parseRatio(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      final text = value.toString().trim();
      if (text.isEmpty) return 0.0;
      if (text.contains('/')) {
        final parts = text.split('/');
        if (parts.length == 2) {
          final num = parseDouble(parts[0]);
          final den = parseDouble(parts[1]);
          if (den != 0) return num / den;
        }
      }
      final parsed = parseDouble(text);
      if (parsed > 1 && parsed <= 100) return parsed / 100.0;
      return parsed;
    }

    final shipments = await CariHesaplarVeritabaniServisi()
        .entegrasyonShipmentsGetir(ref);

    if (shipments.isEmpty) return [];

    final List<DepoModel> depolar = await DepolarVeritabaniServisi()
        .tumDepolariGetir();
    final Map<int, DepoModel> depoById = {for (final d in depolar) d.id: d};
    final int fallbackWarehouseId = depolar.isNotEmpty ? depolar.first.id : 0;
    final String fallbackWarehouseName = depolar.isNotEmpty
        ? depolar.first.ad
        : '';

    final List<TransactionItem> items = [];
    for (final s in shipments) {
      final int? warehouseId =
          (s['source_warehouse_id'] as int?) ??
          (s['dest_warehouse_id'] as int?);
      final int safeWarehouseId = warehouseId ?? fallbackWarehouseId;
      final String warehouseName =
          depoById[safeWarehouseId]?.ad ?? fallbackWarehouseName;

      final rawItems = s['items'];
      if (rawItems is! List) continue;

      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final code = raw['code']?.toString() ?? '';
        if (code.isEmpty) continue;

        String currency = raw['currency']?.toString() ?? 'TRY';
        if (currency == 'TL') currency = 'TRY';

        final double rate = parseDouble(raw['exchangeRate'] ?? 1.0);
        final double unitCostLocal = parseDouble(
          raw['unitCost'] ??
              raw['unit_cost'] ??
              raw['unitPrice'] ??
              raw['unit_price'] ??
              raw['price'] ??
              raw['birim_fiyat'] ??
              raw['birimFiyat'] ??
              raw['ham_fiyat'] ??
              raw['hamFiyat'],
        );
        final double unitPrice = (currency != 'TRY' && rate > 0)
            ? (unitCostLocal / rate)
            : unitCostLocal;

        final double quantity = parseDouble(
          raw['quantity'] ?? raw['miktar'] ?? raw['qty'],
        );
        final double discountRate = parseDouble(
          raw['discountRate'] ??
              raw['discount_rate'] ??
              raw['discount'] ??
              raw['iskonto'] ??
              raw['iskontoOrani'] ??
              raw['iskonto_orani'],
        );
        final double vatRate = parseDouble(
          raw['vatRate'] ??
              raw['vat_rate'] ??
              raw['kdvOrani'] ??
              raw['kdv_orani'] ??
              raw['kdvRate'] ??
              raw['kdv_rate'] ??
              raw['kdv'],
        );
        final double otvRate = parseDouble(
          raw['otvRate'] ??
              raw['otv_rate'] ??
              raw['otvOrani'] ??
              raw['otv_orani'] ??
              raw['otv'],
        );
        final double oivRate = parseDouble(
          raw['oivRate'] ??
              raw['oiv_rate'] ??
              raw['oivOrani'] ??
              raw['oiv_orani'] ??
              raw['oiv'],
        );
        final double tevkifatOrani = parseRatio(
          raw['kdvTevkifatOrani'] ??
              raw['kdv_tevkifat_orani'] ??
              raw['tevkifatOrani'] ??
              raw['tevkifat_orani'] ??
              raw['kdvTevkifat'] ??
              raw['kdv_tevkifat'] ??
              raw['kdvTevkifatValue'] ??
              raw['kdv_tevkifat_value'] ??
              raw['tevkifat'],
        );

        // Bazı eski kayıtlarda vergi oranları items JSON'una yazılmamış olabiliyor.
        // Bu durumda satır toplamından (total) geriye doğru oranı çıkar.
        final double lineTotalLocal = parseDouble(
          raw['total'] ?? raw['lineTotal'] ?? raw['line_total'],
        );
        final double lineTotal = (currency != 'TRY' && rate > 0)
            ? (lineTotalLocal / rate)
            : lineTotalLocal;

        double resolvedVatRate = vatRate;
        if (resolvedVatRate <= 0 && lineTotal > 0 && quantity > 0) {
          final double base = quantity * unitPrice;
          final double otvAmount = base * (otvRate / 100);
          final double oivAmount = base * (oivRate / 100);

          final double subtotal = base + otvAmount + oivAmount;
          final double discountAmount = subtotal * (discountRate / 100);
          final double vatBase = subtotal - discountAmount;

          if (vatBase > 0) {
            final double netVatAmount = (lineTotal - vatBase).clamp(
              0,
              double.infinity,
            );

            if (netVatAmount > 0) {
              final double divisor = (1.0 - tevkifatOrani);
              final double inferredVatAmount = (divisor > 0)
                  ? (netVatAmount / divisor)
                  : netVatAmount;
              resolvedVatRate = (inferredVatAmount / vatBase) * 100.0;

              // Kullanıcı arayüzünde genelde tam sayı KDV oranı beklenir (örn: 18).
              // Yuvarlamadan kaynaklı 18,02 gibi değerleri stabilize et.
              if (resolvedVatRate.isFinite) {
                final rounded = resolvedVatRate.roundToDouble();
                if ((resolvedVatRate - rounded).abs() < 0.05) {
                  resolvedVatRate = rounded;
                }
              }
            }
          }
        }

        items.add(
          TransactionItem(
            code: code,
            name: raw['name']?.toString() ?? code,
            barcode: raw['barcode']?.toString() ?? '',
            unit: raw['unit']?.toString() ?? '',
            quantity: quantity,
            unitPrice: unitPrice,
            currency: currency,
            exchangeRate: rate,
            vatRate: resolvedVatRate,
            discountRate: discountRate,
            warehouseId: safeWarehouseId,
            warehouseName: warehouseName,
            vatIncluded: false,
            otvRate: otvRate,
            otvIncluded: false,
            oivRate: oivRate,
            oivIncluded: false,
            kdvTevkifatOrani: tevkifatOrani,
          ),
        );
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar kaldırıldı - sayfa artık tab içinde açılıyor
      body: Focus(
        autofocus: false,
        child: CallbackShortcuts(
          bindings: {
            // ESC: Overlay kapat / Arama temizle / Filtre sıfırla
            // Not: Tab kapatma tab_yonetici tarafından yönetiliyor
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (_overlayEntry != null) {
                _closeOverlay();
                return;
              }
              if (_searchController.text.isNotEmpty) {
                _searchController.clear();
                return;
              }
              if (_startDate != null ||
                  _endDate != null ||
                  _selectedStatus != null ||
                  _selectedAccountType != null ||
                  _selectedCity != null ||
                  _selectedTransactionType != null ||
                  _selectedUser != null) {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _startDateController.clear();
                  _endDateController.clear();
                  _selectedStatus = null;
                  _selectedAccountType = null;
                  _selectedCity = null;
                  _selectedTransactionType = null;
                  _selectedUser = null;
                  _resetPagination();
                });
                _loadTransactions();
                return;
              }
              // ESC ile sayfa kapatma desteği: sadece overlay, arama ve filtre yoksa
              // Tab kapatma işlemi tab yöneticisi tarafından yapılacak
            },
            // F2: Cariyi Düzenle
            const SingleActivator(LogicalKeyboardKey.f2): () async {
              final result = await Navigator.push<bool>(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      CariHesapEkleSayfasi(cariHesap: _currentCari),
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
                await _refreshCariDetails();
                await _loadTransactions();
              }
            },
            // F3: Arama kutusuna odaklan
            const SingleActivator(LogicalKeyboardKey.f3): () {
              _searchFocusNode.requestFocus();
            },
            // F5: Yenile veya Tek Satır Modu
            const SingleActivator(LogicalKeyboardKey.f5): () {
              // 1. Eğer zaten tek satır modundaysak, moddan çık
              if (_singleViewRowId != null) {
                _toggleSingleView(_singleViewRowId!);
                return;
              }
              // 2. Bir satır seçiliyse, o satırı tek satır moduna al
              if (_selectedRowId != null) {
                _toggleSingleView(_selectedRowId!);
                return;
              }
              // 3. Hiçbiri değilse normal yenileme yap
              _loadTransactions();
            },
            const SingleActivator(LogicalKeyboardKey.f6): () async {
              await _cariDurumDegistir(_currentCari, !_currentCari.aktifMi);
              await _refreshCariDetails();
            },
            // F7: Yazdır
            const SingleActivator(LogicalKeyboardKey.f7): _handlePrint,
            // F8: Seçilileri Toplu Sil
            const SingleActivator(LogicalKeyboardKey.f8): () {
              final selectedIds =
                  _selectedDetailIds[_currentCari.id] ?? <int>{};
              if (selectedIds.isEmpty && !_isSelectAllActive) return;
              _deleteSelectedTransactions();
            },
            // F1: Para Al / Ver
            const SingleActivator(LogicalKeyboardKey.f1): () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      CariParaAlVerSayfasi(cari: _currentCari),
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
              ).then((result) async {
                if (result == true) {
                  await _refreshCariDetails();
                  await _loadTransactions();
                }
              });
            },
            // Delete: Seçili işlemi sil
            const SingleActivator(LogicalKeyboardKey.delete): () {
              if (_isInstallmentsMode) return;
              if (_selectedRowId == null) return;
              _deleteTransaction(_selectedRowId!);
            },
            // Numpad Delete: Seçili işlemi sil
            const SingleActivator(LogicalKeyboardKey.numpadDecimal): () {
              if (_isInstallmentsMode) return;
              if (_selectedRowId == null) return;
              _deleteTransaction(_selectedRowId!);
            },
          },
          child: Column(
            children: [
              // Cari Hesap Bilgi Kartı
              _buildCariHesapInfoCard(theme),
              // Ana İçerik
              Expanded(
                child: Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final bool forceMobile =
                            ResponsiveYardimcisi.tabletMi(context);
                        if (forceMobile || constraints.maxWidth < 800) {
                          return _buildMobileView();
                        } else {
                          return _buildDesktopView(constraints);
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCariHesapInfoCard(ThemeData theme) {
    final cari = _currentCari;
    final bakiye = cari.bakiyeBorc - cari.bakiyeAlacak;

    // Ana resim widget'ı
    Widget buildMainImage() {
      ImageProvider? img;
      if (cari.resimler.isNotEmpty) {
        // [2026 FIX] Use cached image method
        img = _getCachedMemoryImage(cari.resimler.first);
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
                  cari.adi.isNotEmpty ? cari.adi[0].toUpperCase() : '?',
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

    // Küçük resimler
    Widget buildThumbnails() {
      if (cari.resimler.length <= 1) return const SizedBox.shrink();
      return Row(
        children: cari.resimler.skip(1).take(4).map((imgStr) {
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
                  // Kapandığında görünen bilgiler
                  if (!_isInfoCardExpanded) ...[
                    // Ana resim küçük
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        image: cari.resimler.isNotEmpty
                            ? DecorationImage(
                                image:
                                    _getCachedMemoryImage(
                                      cari.resimler.first,
                                    ) ??
                                    const AssetImage('assets/placeholder.png')
                                        as ImageProvider,
                                fit: BoxFit.contain,
                              )
                            : null,
                      ),
                      child: cari.resimler.isEmpty
                          ? Center(
                              child: Text(
                                cari.adi.isNotEmpty
                                    ? cari.adi[0].toUpperCase()
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
                    // Cari adı ve kodu
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cari.adi,
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
                                  cari.kodNo,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                IslemCeviriYardimcisi.cevir(cari.hesapTuru),
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
                    // Bakiye özeti
                    Text(
                      '${bakiye >= 0 ? tr('accounts.table.type_debit') : tr('accounts.table.type_credit')}: ${FormatYardimcisi.sayiFormatlaOndalikli(bakiye.abs(), binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${cari.paraBirimi}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: bakiye >= 0
                            ? Colors.red.shade600
                            : Colors.green.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      tr('accounts.card.open'),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Açıkken sadece "Cari Bilgileri" yazısı ve ok
                  if (_isInfoCardExpanded) ...[
                    Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr('accounts.card.details_title'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Text(
                      tr('accounts.card.close'),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Toggle icon (her zaman görünür)
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
            ),
          ),
          // ============ EXPANDABLE CONTENT ============
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ============ HEADER ROW ============
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sol: Resim + Bilgiler
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
                                    // Cari Adı
                                    Text(
                                      cari.adi,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // Kod + Tür badge'leri
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
                                            cari.kodNo,
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
                                            IslemCeviriYardimcisi.cevir(
                                              cari.hesapTuru,
                                            ),
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
                                    // Küçük resimler
                                    buildThumbnails(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Orta: Bakiye Bölümü
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Header satırı
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      tr('common.total'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      tr('common.amount'),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      tr('common.currency_short'),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Ödeme Yapıldı (Borç)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      tr('accounts.card.summary.payment_made'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      FormatYardimcisi.sayiFormatlaOndalikli(
                                        _odemeYapildiSum,
                                        binlik: _genelAyarlar.binlikAyiraci,
                                        ondalik: _genelAyarlar.ondalikAyiraci,
                                        decimalDigits:
                                            _genelAyarlar.fiyatOndalik,
                                      ),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      cari.paraBirimi,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              // Borç Dekontu
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      tr('accounts.card.summary.debit_note'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red.shade400,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      FormatYardimcisi.sayiFormatlaOndalikli(
                                        _borcDekontuSum,
                                        binlik: _genelAyarlar.binlikAyiraci,
                                        ondalik: _genelAyarlar.ondalikAyiraci,
                                        decimalDigits:
                                            _genelAyarlar.fiyatOndalik,
                                      ),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade500,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      cari.paraBirimi,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              // Ödeme Alındı (Alacak)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      tr(
                                        'accounts.card.summary.payment_received',
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      FormatYardimcisi.sayiFormatlaOndalikli(
                                        _odemeAlindiSum,
                                        binlik: _genelAyarlar.binlikAyiraci,
                                        ondalik: _genelAyarlar.ondalikAyiraci,
                                        decimalDigits:
                                            _genelAyarlar.fiyatOndalik,
                                      ),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      cari.paraBirimi,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              // Alacak Dekontu
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      tr('accounts.card.summary.credit_note'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      FormatYardimcisi.sayiFormatlaOndalikli(
                                        _alacakDekontuSum,
                                        binlik: _genelAyarlar.binlikAyiraci,
                                        ondalik: _genelAyarlar.ondalikAyiraci,
                                        decimalDigits:
                                            _genelAyarlar.fiyatOndalik,
                                      ),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      cari.paraBirimi,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                height: 1,
                                width: 220,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                color: const Color(0xFFE2E8F0),
                              ),
                              // Fark
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      bakiye >= 0
                                          ? '${tr('common.difference')} (${tr('accounts.table.type_debit')})'
                                          : '${tr('common.difference')} (${tr('accounts.table.type_credit')})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF1E293B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      FormatYardimcisi.sayiFormatlaOndalikli(
                                        bakiye.abs(),
                                        binlik: _genelAyarlar.binlikAyiraci,
                                        ondalik: _genelAyarlar.ondalikAyiraci,
                                        decimalDigits:
                                            _genelAyarlar.fiyatOndalik,
                                      ),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      cari.paraBirimi,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Sağ: Not Alanı
                        Container(
                          width: 200,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.edit_note_rounded,
                                    size: 18,
                                    color: Colors.amber.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    tr('accounts.detail.note_label'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: TextField(
                                  controller: _notController,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1E293B),
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.all(10),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(
                                        color: Colors.amber.shade200,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(
                                        color: Colors.amber.shade200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide(
                                        color: Colors.amber.shade400,
                                        width: 2,
                                      ),
                                    ),
                                    hintText: tr(
                                      'accounts.detail.note_placeholder',
                                    ),
                                    hintStyle: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  onSubmitted: (_) => _saveNote(),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  tr('accounts.detail.save_with_enter'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.amber.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ============ SEPARATOR ============
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    color: const Color(0xFFE2E8F0),
                  ),
                  // ============ DETAY SATIR - 5 SÜTUN ============
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. İletişim Bilgileri
                      Expanded(
                        child: _buildDetailColumn(
                          icon: Icons.contact_phone_outlined,
                          title: tr('accounts.form.section.contact'),
                          items: [
                            (
                              'Telefon 1',
                              cari.telefon1.isNotEmpty ? cari.telefon1 : '-',
                            ),
                            (
                              'Telefon 2',
                              cari.telefon2.isNotEmpty ? cari.telefon2 : '-',
                            ),
                            (
                              'E-Posta',
                              cari.eposta.isNotEmpty ? cari.eposta : '-',
                            ),
                            (
                              'Web Adresi',
                              cari.webAdresi.isNotEmpty ? cari.webAdresi : '-',
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 100,
                        color: const Color(0xFFE2E8F0),
                      ),
                      // 2. Fatura ve Vergi Bilgileri
                      Expanded(
                        child: _buildDetailColumn(
                          icon: Icons.receipt_long_outlined,
                          title: tr('accounts.form.section.invoice'),
                          items: [
                            (
                              'Fat. Ünvanı',
                              cari.fatUnvani.isNotEmpty ? cari.fatUnvani : '-',
                            ),
                            (
                              'Fat. Adresi',
                              '${cari.fatIlce}${cari.fatIlce.isNotEmpty && cari.fatSehir.isNotEmpty ? '/' : ''}${cari.fatSehir}'
                                      .isNotEmpty
                                  ? '${cari.fatIlce}${cari.fatIlce.isNotEmpty && cari.fatSehir.isNotEmpty ? '/' : ''}${cari.fatSehir}'
                                  : '-',
                            ),
                            (
                              'Posta Kodu',
                              cari.postaKodu.isNotEmpty ? cari.postaKodu : '-',
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 100,
                        color: const Color(0xFFE2E8F0),
                      ),
                      // 3. Sevk Adresleri
                      Expanded(
                        child: _buildSevkAdresleriSection(cari.sevkAdresleri),
                      ),
                      Container(
                        width: 1,
                        height: 100,
                        color: const Color(0xFFE2E8F0),
                      ),
                      // 4. Ticari Bilgiler
                      Expanded(
                        child: _buildDetailColumn(
                          icon: Icons.business_center_outlined,
                          title: tr('accounts.detail.commercial_title'),
                          items: [
                            (
                              'V. Dairesi',
                              '${cari.vDairesi}${cari.vDairesi.isNotEmpty && cari.vNumarasi.isNotEmpty ? ' / ' : ''}${cari.vNumarasi}'
                                      .isNotEmpty
                                  ? '${cari.vDairesi}${cari.vDairesi.isNotEmpty && cari.vNumarasi.isNotEmpty ? ' / ' : ''}${cari.vNumarasi}'
                                  : '-',
                            ),
                            (
                              'Risk Limiti',
                              '${FormatYardimcisi.sayiFormatlaOndalikli(cari.riskLimiti, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ₺',
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 100,
                        color: const Color(0xFFE2E8F0),
                      ),
                      // 5. Özel Bilgi Alanları - Alt Alta
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Color(0xFF2C3E50),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    tr('accounts.form.section.info'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildOzelBilgiItem('Bilgi 1', cari.bilgi1),
                              _buildOzelBilgiItem('Bilgi 2', cari.bilgi2),
                              _buildOzelBilgiItem('Bilgi 3', cari.bilgi3),
                              _buildOzelBilgiItem('Bilgi 4', cari.bilgi4),
                              _buildOzelBilgiItem('Bilgi 5', cari.bilgi5),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _isInfoCardExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildOzelBilgiItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: value.isNotEmpty
                    ? Colors.grey.shade800
                    : Colors.grey.shade400,
              ),
            ),
          ),
          if (value.isNotEmpty)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label ${tr('common.copied')}'),
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
    );
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
                    width: 75,
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

  Widget _buildSevkAdresleriSection(String sevkJson) {
    List<Map<String, dynamic>> adresler = [];
    if (sevkJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(sevkJson);
        if (decoded is List) {
          adresler = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                size: 14,
                color: Color(0xFF2C3E50),
              ),
              const SizedBox(width: 4),
              Text(
                tr('accounts.form.section.shipment'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (adresler.isEmpty)
            Text(
              '-',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            )
          else
            ...adresler.take(2).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final addr = entry.value;
              final adres = addr['adres']?.toString() ?? '';
              final ilce = addr['ilce']?.toString() ?? '';
              final sehir = addr['sehir']?.toString() ?? '';
              final fullAdres = '$adres $ilce/$sehir'.trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        '${tr('accounts.form.shipment_address')} ${i + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        fullAdres,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    if (fullAdres.isNotEmpty && fullAdres != '/')
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: fullAdres));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${tr('accounts.form.shipment_address')} ${i + 1} ${tr('common.copied')}',
                              ),
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
              );
            }),
        ],
      ),
    );
  }

  Future<void> _saveNote() async {
    // Not kaydetme işlemi
    try {
      final updatedCari = _currentCari.copyWith(
        bilgi1: _notController.text.trim(),
      );
      await CariHesaplarVeritabaniServisi().cariHesapGuncelle(updatedCari);
      if (mounted) {
        MesajYardimcisi.basariGoster(context, tr('accounts.detail.note_saved'));
      }
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(
          context,
          '${tr('accounts.detail.note_save_failed')}: $e',
        );
      }
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
      });
      _reloadActiveList();
    }
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
                  ? const Color(0xFFE8F5E9)
                  : Colors.transparent,
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

  // Devamı ayrı dosyada - part directive ile birleştirilebilir
  // Åimdilik basitleÅŸtirilmiÅŸ placeholder metodlar

  // ignore: unused_element
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

  Widget _buildTransactionTypeOption(String? value, String label) {
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
          _isTransactionTypeFilterExpanded = false;
        });
        _closeOverlay();
        _reloadActiveList();
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
                    : Colors.transparent,
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
                      : IslemCeviriYardimcisi.cevir(_selectedTransactionType!),
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
                    });
                    _reloadActiveList();
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
        });
        _closeOverlay();
        _reloadActiveList();
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
                    : Colors.transparent,
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
                    _reloadActiveList();
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

  Widget _buildMobileView() {
    return Column(
      children: [
        // Search & Filters for Transactions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
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
          ),
        ),

        // Transactions List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _cachedTransactions.isEmpty
              ? Center(
                  child: Text(
                    tr('common.no_records_found'),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cachedTransactions.length,
                  itemBuilder: (context, index) {
                    final tx = _cachedTransactions[index];
                    return _buildMobileTransactionCard(tx);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMobileTransactionCard(Map<String, dynamic> tx) {
    // [TODO] Implement a nice transaction card for mobile
    final String islemTuru = tx['islem_turu']?.toString() ?? '';
    final String yon = tx['yon']?.toString().toLowerCase() ?? '';
    final bool isIncoming =
        yon.contains('alacak') ||
        islemTuru.toLowerCase().contains('tahsilat') ||
        islemTuru.toLowerCase().contains('alış');

    final double tutar = double.tryParse(tx['tutar']?.toString() ?? '') ?? 0.0;
    final String tarihStr = tx['tarih']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncoming
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          child: Icon(
            isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIncoming ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
        title: Text(
          islemTuru,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          tarihStr,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIncoming ? '+' : '-'}${FormatYardimcisi.sayiFormatlaOndalikli(tutar)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isIncoming ? Colors.green : Colors.red,
                fontSize: 14,
              ),
            ),
            if (tx['running_balance'] != null)
              Text(
                FormatYardimcisi.sayiFormatlaOndalikli(tx['running_balance']),
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  void _showColumnVisibilityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Local copy of visibility map
        Map<String, bool> localVisibility = Map.from(_columnVisibility);

        // Helper to check 'Select All' state
        bool isAllMainSelected() {
          final mainKeys = [
            'islem',
            'tarih',
            'tutar',
            'bakiye_borc',
            'bakiye_alacak',
            'ilgili_hesap',
            'aciklama',
            'vade_tarihi',
          ];
          return mainKeys.every((key) => localVisibility[key] == true);
        }

        bool isAllDetailSelected() {
          final detailKeys = [
            'dt_urun_kodu',
            'dt_urun_adi',
            'dt_tarih',
            'dt_miktar',
            'dt_birim',
            'dt_iskonto',
            'dt_ham_fiyat',
            'dt_aciklama',
            'dt_fiyat',
            'dt_kdv',
            'dt_otv',
            'dt_oiv',
            'dt_tevkifat',
            'dt_borc',
            'dt_alacak',
            'dt_belge',
            'dt_e_belge',
            'dt_irsaliye',
            'dt_fatura',
            'dt_aciklama2',
          ];
          return detailKeys.every((key) => localVisibility[key] == true);
        }

        void toggleAllMain(bool? value) {
          final mainKeys = [
            'islem',
            'tarih',
            'tutar',
            'bakiye_borc',
            'bakiye_alacak',
            'ilgili_hesap',
            'aciklama',
            'vade_tarihi',
          ];
          for (var key in mainKeys) {
            localVisibility[key] = value ?? false;
          }
        }

        void toggleAllDetail(bool? value) {
          final detailKeys = [
            'dt_urun_kodu',
            'dt_urun_adi',
            'dt_tarih',
            'dt_miktar',
            'dt_birim',
            'dt_iskonto',
            'dt_ham_fiyat',
            'dt_aciklama',
            'dt_fiyat',
            'dt_kdv',
            'dt_otv',
            'dt_oiv',
            'dt_tevkifat',
            'dt_borc',
            'dt_alacak',
            'dt_belge',
            'dt_e_belge',
            'dt_irsaliye',
            'dt_fatura',
            'dt_aciklama2',
          ];
          for (var key in detailKeys) {
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
                  Icon(Icons.view_column_outlined, color: Color(0xFF2C3E50)),
                  const SizedBox(width: 8),
                  Text(
                    tr(
                      'common.column_settings',
                    ), // Çeviri anahtarı yoksa "Sütun Ayarları"
                    style: TextStyle(
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
                              tr('common.main_table'), // "Ana Tablo"
                              style: TextStyle(
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
                                    tr('common.select_all'), // "Tümünü Seç"
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
                      // Main Columns Grid
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
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
                            'tutar',
                            tr('common.amount'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'bakiye_borc',
                            tr('accounts.balance.debit_label'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'bakiye_alacak',
                            tr('accounts.balance.credit_label'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'ilgili_hesap',
                            tr('common.related_account'),
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
                            'vade_tarihi',
                            tr('common.due_date_short'),
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
                              tr('common.last_movements'), // "Son Hareketler"
                              style: TextStyle(
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
                            'dt_urun_kodu',
                            tr('accounts.statement.col.product_code_short'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_urun_adi',
                            tr('shipment.field.name'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_tarih',
                            tr('common.date'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_miktar',
                            tr('common.quantity'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_birim',
                            tr('common.unit'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_iskonto',
                            tr('common.discount_percent_short'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_ham_fiyat',
                            tr('common.raw_price_short'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_aciklama',
                            tr('common.description'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_fiyat',
                            tr('shipment.field.price'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_kdv',
                            'KDV',
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_otv',
                            'ÖTV',
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_oiv',
                            'ÖİV',
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_tevkifat',
                            'Tevkifat',
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_borc',
                            tr('accounts.table.type_debit'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_alacak',
                            tr('accounts.table.type_credit'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_belge',
                            tr('purchase.complete.field.document'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_e_belge',
                            tr('settings.general.option.documents.eDocument'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_irsaliye',
                            tr('purchase.complete.field.waybill_no'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_fatura',
                            tr('purchase.complete.field.invoice_no'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'dt_aciklama2',
                            tr('common.description2'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    tr('common.cancel'),
                    style: TextStyle(
                      color: const Color(0xFF2C3E50),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Update main state
                    setState(() {
                      _columnVisibility = localVisibility;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA4335),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    tr('common.save'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInstallmentColumnVisibilityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Map<String, bool> localVisibility = Map.from(
          _installmentColumnVisibility,
        );

        bool isAllSelected() {
          final keys = [
            'islem',
            'satis_tarihi',
            'fatura_no',
            'vade_tarihi',
            'tutar',
            'durum',
            'odeme_tarihi',
            'odeme_hesap',
            'aciklama',
            'kullanici',
          ];
          return keys.every((key) => localVisibility[key] == true);
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
                              tr('accounts.card.installments'),
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
                            'islem',
                            tr('products.transaction.type'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'satis_tarihi',
                            tr('accounts.card.installments.col.sale_date'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'fatura_no',
                            tr('sale.complete.field.invoice_no'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'vade_tarihi',
                            tr('common.due_date_short'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'tutar',
                            tr(
                              'accounts.card.installments.col.installment_amount',
                            ),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'durum',
                            tr('common.status'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'odeme_tarihi',
                            tr('accounts.card.installments.col.payment_date'),
                          ),
                          _buildConfigCheckbox(
                            setDialogState,
                            localVisibility,
                            'odeme_hesap',
                            tr(
                              'accounts.card.installments.col.payment_account',
                            ),
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
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    tr('common.cancel'),
                    style: TextStyle(
                      color: const Color(0xFF2C3E50),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _installmentColumnVisibility = localVisibility;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA4335),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    tr('common.save'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
      width: 170, // Slightly wider for better text fit
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

  void _toggleSingleView(int rowId) {
    setState(() {
      if (_singleViewRowId == rowId) {
        _singleViewRowId = null;
      } else {
        _singleViewRowId = rowId;
        // Single view'e geçince o satırı seçili yapalım ki F5 ile çıkılabilsin
        _selectedRowId = rowId;
      }
    });
  }

  Widget _buildDesktopView(BoxConstraints constraints) {
    if (_isInstallmentsMode) {
      return _buildDesktopInstallmentsView(constraints);
    }
    // Single View Filtresi
    final List<Map<String, dynamic>> displayTransactions;
    if (_singleViewRowId != null) {
      displayTransactions = _cachedTransactions
          .where((tx) => tx['id'] == _singleViewRowId)
          .toList();
    } else {
      displayTransactions = _cachedTransactions;
    }

    // Tüm işlemler seçili mi kontrolü
    final selectedIds = _selectedDetailIds[_currentCari.id] ?? <int>{};
    final bool allSelected =
        displayTransactions.isNotEmpty &&
        displayTransactions.every((tx) => selectedIds.contains(tx['id']));

    // Sütun genişliklerini başlık metnine göre hesapla
    const double headerFontSize = 15.0;

    double calculateHeaderWidth(
      String text, {
      bool sortable = false,
      double minWidth = 60.0,
    }) {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black54,
            fontSize: headerFontSize,
          ),
        ),
        maxLines: 1,
        textDirection: ui.TextDirection.ltr,
      )..layout();

      double width = textPainter.width + 32;
      if (sortable) {
        width += 22;
      }
      if (width < minWidth) {
        width = minWidth;
      }
      return width;
    }

    int flexFromWidth(double width, {int minFlex = 1}) {
      final flex = (width / 35).ceil();
      return flex < minFlex ? minFlex : flex;
    }

    const colCheckboxWidth = 50.0;
    final colIslemWidth = calculateHeaderWidth(
      tr('products.transaction.type'),
      sortable: true,
      minWidth: 200.0,
    );
    final colIslemFlex = flexFromWidth(colIslemWidth, minFlex: 6);
    final colTarihWidth = calculateHeaderWidth(
      tr('common.date'),
      sortable: true,
      minWidth: 150.0,
    );
    final colTarihFlex = flexFromWidth(colTarihWidth, minFlex: 4);

    final colTutarWidth = calculateHeaderWidth(
      tr('common.amount'),
      sortable: true,
      minWidth: 110.0,
    );
    final colTutarFlex = flexFromWidth(colTutarWidth, minFlex: 3);

    final colBakiyeBorcWidth = calculateHeaderWidth(
      tr('accounts.balance.debit_label'),
      sortable: true,
      minWidth: 120.0,
    );
    final colBakiyeBorcFlex = flexFromWidth(colBakiyeBorcWidth, minFlex: 3);

    final colBakiyeAlacakWidth = calculateHeaderWidth(
      tr('accounts.balance.credit_label'),
      sortable: true,
      minWidth: 120.0,
    );
    final colBakiyeAlacakFlex = flexFromWidth(colBakiyeAlacakWidth, minFlex: 3);

    final colYerWidth = calculateHeaderWidth(
      tr('common.related_account'),
      sortable: true,
      minWidth: 160.0,
    );
    final colYerFlex = flexFromWidth(colYerWidth, minFlex: 5);
    final colAciklamaWidth = calculateHeaderWidth(
      tr('common.description'),
      minWidth: 110.0,
    );
    final colAciklamaFlex = flexFromWidth(colAciklamaWidth, minFlex: 3);
    final colVadeTarihiWidth = calculateHeaderWidth(
      tr('common.due_date_short'),
      minWidth: 100.0,
    );
    final colVadeTarihiFlex = flexFromWidth(colVadeTarihiWidth, minFlex: 2);

    final colKullaniciWidth = calculateHeaderWidth(
      tr('common.user'),
      minWidth: 100.0,
    );
    final colKullaniciFlex = flexFromWidth(colKullaniciWidth, minFlex: 2);

    final colActionsWidth = calculateHeaderWidth(
      tr('common.actions'),
      minWidth: 90.0,
    );

    return GenisletilebilirTablo<Map<String, dynamic>>(
      title: '',
      totalRecords: _totalRecords,
      searchFocusNode: _searchFocusNode,
      onClearSelection: _clearAllTableSelections,
      onFocusedRowChanged: (item, index) {
        if (item != null) {
          setState(() => _selectedRowId = item['id'] as int?);
        }
      },
      headerWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDateRangeFilter(),
          const SizedBox(width: 24),
          _buildTransactionTypeFilter(width: 200),
          const SizedBox(width: 24),
          _buildUserFilter(width: 200),
        ],
      ),
      headerTextStyle: const TextStyle(fontSize: 14),
      headerMaxLines: 1,
      headerOverflow: TextOverflow.ellipsis,
      onSort: _onSort,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      onPageChanged: (page, rowsPerPage) {
        // [TODO] Implement transactional pagination if needed
        _reloadActiveList();
      },
      onSearch: (query) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          setState(() {
            _searchQuery = query;
          });
          _reloadActiveList();
        });
      },
      selectionWidget: (selectedIds.isNotEmpty)
          ? MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  // Seçilileri sil (Fonksiyonu çağır)
                  _deleteSelectedTransactions();
                },
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
                              : selectedIds.length.toString(),
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
      expandAll: false,
      expandedIndices: _getEffectiveTransactionExpandedIndices(),
      onExpansionChanged: (index, isExpanded) {
        if (index < 0 || index >= _cachedTransactions.length) return;
        if (!_isTransactionExpandable(_cachedTransactions[index])) return;
        setState(() {
          if (isExpanded) {
            _manualExpandedIndex = index;
            _transactionAutoExpandedIndices.add(index);
          } else {
            if (_manualExpandedIndex == index) {
              _manualExpandedIndex = null;
            }
            _transactionAutoExpandedIndices.remove(index);
          }
        });
      },
      extraWidgets: [
        // Detayları Açık Tut Butonu
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
        // Sütun Görünümü Seçici
        Tooltip(
          message: tr('common.column_settings'),
          child: InkWell(
            onTap: () => _isInstallmentsMode
                ? _showInstallmentColumnVisibilityDialog(context)
                : _showColumnVisibilityDialog(context),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(
                Icons.view_column_outlined,
                color: Color(0xFF2C3E50),
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (_hasInstallments)
          Tooltip(
            message: tr('accounts.card.show_installments'),
            child: InkWell(
              onTap: _toggleInstallmentsMode,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: _isInstallmentsMode
                      ? const Color(0xFF2C3E50).withValues(alpha: 0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _isInstallmentsMode
                        ? const Color(0xFF2C3E50)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Icon(
                  Icons.schedule_outlined,
                  color: _isInstallmentsMode
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade600,
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
                      selectedIds.isNotEmpty
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
          // Belge Yazdır (Sadece Satış için)
          Builder(
            builder: (context) {
              final selectedTx = _cachedTransactions.firstWhere(
                (tx) => tx['id'] == _selectedRowId,
                orElse: () => {},
              );
              final String rawIslemTuru =
                  selectedTx['islem_turu']?.toString() ?? '';
              final String label = IslemTuruRenkleri.getProfessionalLabel(
                rawIslemTuru,
                context: 'cari',
                yon: selectedTx['yon']?.toString(),
              );
              final bool isSatis = label == 'Satış Yapıldı';

              return MouseRegion(
                cursor: isSatis
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: GestureDetector(
                  onTap: isSatis
                      ? () async {
                          final List<dynamic> rawElements =
                              selectedTx['hareket_detaylari'] is List
                              ? selectedTx['hareket_detaylari'] as List
                              : (selectedTx['hareket_detaylari'] != null
                                    ? jsonDecode(
                                            selectedTx['hareket_detaylari']
                                                .toString(),
                                          )
                                          as List
                                    : []);

                          // Flatten nested lists if any (due to json_agg of JSONB arrays)
                          final List<dynamic> rawItems = [];
                          for (var elem in rawElements) {
                            if (elem is List) {
                              rawItems.addAll(elem);
                            } else {
                              rawItems.add(elem);
                            }
                          }

                          final List<Map<String, dynamic>> items = rawItems.map(
                            (e) {
                              final map = Map<String, dynamic>.from(
                                e is Map ? e : {},
                              );
                              return {
                                'name': map['name'] ?? map['code'] ?? '',
                                'code': map['code'] ?? '',
                                'quantity':
                                    double.tryParse(
                                      map['quantity']?.toString() ?? '',
                                    ) ??
                                    0.0,
                                'unit': map['unit'] ?? '',
                                'price':
                                    double.tryParse(
                                      map['unitCost']?.toString() ??
                                          map['price']?.toString() ??
                                          '',
                                    ) ??
                                    0.0,
                                'total':
                                    double.tryParse(
                                      map['total']?.toString() ?? '',
                                    ) ??
                                    0.0,
                              };
                            },
                          ).toList();

                          DateTime initialDate = DateTime.now();
                          final rawTarih = selectedTx['tarih'];
                          if (rawTarih is DateTime) {
                            initialDate = rawTarih;
                          } else if (rawTarih != null) {
                            initialDate =
                                DateTime.tryParse(rawTarih.toString()) ??
                                DateTime.now();
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SatisSonrasiYazdirSayfasi(
                                entegrasyonRef:
                                    selectedTx['integration_ref']?.toString() ??
                                    '',
                                cariAdi: _currentCari.adi,
                                cariKodu: _currentCari.kodNo,
                                genelToplam:
                                    double.tryParse(
                                      selectedTx['tutar']?.toString() ?? '',
                                    ) ??
                                    0.0,
                                paraBirimi:
                                    selectedTx['para_birimi']?.toString() ??
                                    'TRY',
                                initialFaturaNo:
                                    selectedTx['fatura_no']?.toString() ?? '',
                                initialIrsaliyeNo:
                                    selectedTx['irsaliye_no']?.toString() ?? '',
                                initialTarih: initialDate,
                                items: items,
                              ),
                            ),
                          ).then((result) {
                            if (result == true) {
                              _loadTransactions();
                            }
                          });
                        }
                      : null,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSatis
                          ? const Color(0xFF2C3E50)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSatis
                            ? const Color(0xFF2C3E50)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 18,
                          color: isSatis ? Colors.white : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr('common.print_document'),
                          style: TextStyle(
                            color: isSatis
                                ? Colors.white
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                // İade Et işlemi
                MesajYardimcisi.bilgiGoster(
                  context,
                  tr('accounts.card.return_coming_soon'),
                );
              },
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF39C12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.transparent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.assignment_return_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('accounts.card.return_action'),
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
                        tr('common.key.f4'),
                        style: const TextStyle(
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
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        CariParaAlVerSayfasi(cari: _currentCari),
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
                ).then((result) async {
                  if (result == true) {
                    await _refreshCariDetails();
                    await _loadTransactions();
                    _fetchCariHesaplar();
                  }
                });
              },
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3E50),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('accounts.card.cash_in_out'),
                      style: TextStyle(
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
        // 1. Checkbox sütunu
        GenisletilebilirTabloKolon(
          label: '',
          width: colCheckboxWidth,
          alignment: Alignment.center,
          header: SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: allSelected,
              onChanged: (val) => _onSelectAllDetails(_currentCari.id, val),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
            ),
          ),
        ),
        // 2. İşlem
        if (_columnVisibility['islem'] == true)
          GenisletilebilirTabloKolon(
            label: tr('products.transaction.type'),
            width: colIslemWidth,
            alignment: Alignment.centerLeft,
            allowSorting: true,
            flex: colIslemFlex,
          ),
        // 3. Tarih
        if (_columnVisibility['tarih'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.date'),
            width: colTarihWidth,
            alignment: Alignment.centerLeft,
            allowSorting: true,
            flex: colTarihFlex,
          ),
        // 4. Tutar
        if (_columnVisibility['tutar'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.amount'),
            width: colTutarWidth,
            alignment: Alignment.centerRight,
            allowSorting: true,
            flex: colTutarFlex,
          ),
        // 5. Bakiye Borç
        if (_columnVisibility['bakiye_borc'] == true)
          GenisletilebilirTabloKolon(
            label: tr('accounts.balance.debit_label'),
            width: colBakiyeBorcWidth,
            alignment: Alignment.centerRight,
            allowSorting: true,
            flex: colBakiyeBorcFlex,
          ),
        // 6. Bakiye Alacak
        if (_columnVisibility['bakiye_alacak'] == true)
          GenisletilebilirTabloKolon(
            label: tr('accounts.balance.credit_label'),
            width: colBakiyeAlacakWidth,
            alignment: Alignment.centerRight,
            allowSorting: true,
            flex: colBakiyeAlacakFlex,
          ),
        // 7. İlgili Hesap
        if (_columnVisibility['ilgili_hesap'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.related_account'),
            width: colYerWidth,
            alignment: Alignment.centerLeft,
            allowSorting: true,
            flex: colYerFlex,
          ),
        // 8. Açıklama
        if (_columnVisibility['aciklama'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.description'),
            width: colAciklamaWidth,
            alignment: Alignment.centerLeft,
            flex: colAciklamaFlex,
          ),
        // 9. Vade Tarihi
        if (_columnVisibility['vade_tarihi'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.due_date_short'),
            width: colVadeTarihiWidth,
            alignment: Alignment.centerLeft,
            flex: colVadeTarihiFlex,
          ),
        // 10. Kullanıcı
        if (_columnVisibility['kullanici'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.user'),
            width: colKullaniciWidth,
            alignment: Alignment.centerLeft,
            flex: colKullaniciFlex,
          ),
        // 11. İşlemler
        GenisletilebilirTabloKolon(
          label: tr('common.actions'),
          width: colActionsWidth,
          alignment: Alignment.center,
        ),
      ],
      data: displayTransactions,
      isRowSelected: (tx, index) => _selectedRowId == tx['id'],
      expandOnRowTap: false,
      onRowTap: (tx) {
        setState(() {
          _selectedRowId = tx['id'] as int?;
        });
      },
      getDetailItemCount: _getTransactionDetailItemCount,
      rowBuilder: (context, tx, index, isExpanded, toggleExpand) {
        return _buildTransactionMainRow(
          tx: tx,
          index: index,
          isExpanded: isExpanded,
          toggleExpand: toggleExpand,
          colCheckboxWidth: colCheckboxWidth,
          colIslemWidth: colIslemWidth,
          colIslemFlex: colIslemFlex,
          colTarihWidth: colTarihWidth,
          colTarihFlex: colTarihFlex,
          colTutarWidth: colTutarWidth,
          colTutarFlex: colTutarFlex,
          colBakiyeBorcWidth: colBakiyeBorcWidth,
          colBakiyeBorcFlex: colBakiyeBorcFlex,
          colBakiyeAlacakWidth: colBakiyeAlacakWidth,
          colBakiyeAlacakFlex: colBakiyeAlacakFlex,
          colYerWidth: colYerWidth,
          colYerFlex: colYerFlex,
          colAciklamaWidth: colAciklamaWidth,
          colAciklamaFlex: colAciklamaFlex,
          colVadeTarihiWidth: colVadeTarihiWidth,
          colVadeTarihiFlex: colVadeTarihiFlex,
          colKullaniciWidth: colKullaniciWidth,
          colKullaniciFlex: colKullaniciFlex,
          colActionsWidth: colActionsWidth,
        );
      },
      detailBuilder: (context, tx) {
        return _buildTransactionDetailRow(tx);
      },
    );
  }

  Widget _buildDesktopInstallmentsView(BoxConstraints constraints) {
    // Keep existing action bar behavior (print/para al-ver/etc.)
    final selectedIds = _selectedInstallmentIds[_currentCari.id] ?? <int>{};

    int? parseIntId(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '');
    }

    final visibleInstallmentIds = _cachedInstallments
        .map((e) => parseIntId(e['id']))
        .whereType<int>()
        .toList();

    final bool allSelected =
        visibleInstallmentIds.isNotEmpty &&
        visibleInstallmentIds.every(selectedIds.contains);

    const double headerFontSize = 15.0;

    double calculateHeaderWidth(
      String text, {
      bool sortable = false,
      double minWidth = 60.0,
    }) {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black54,
            fontSize: headerFontSize,
          ),
        ),
        maxLines: 1,
        textDirection: ui.TextDirection.ltr,
      )..layout();

      double width = textPainter.width + 32;
      if (sortable) width += 22;
      if (width < minWidth) width = minWidth;
      return width;
    }

    int flexFromWidth(double width, {int minFlex = 1}) {
      final flex = (width / 35).ceil();
      return flex < minFlex ? minFlex : flex;
    }

    const colCheckboxWidth = 50.0;
    final colIslemWidth = calculateHeaderWidth(
      tr('products.transaction.type'),
      minWidth: 170,
    );
    final colIslemFlex = flexFromWidth(colIslemWidth, minFlex: 5);

    final colSatisTarihWidth = calculateHeaderWidth(
      tr('accounts.card.installments.col.sale_date'),
      minWidth: 150,
    );
    final colSatisTarihFlex = flexFromWidth(colSatisTarihWidth, minFlex: 4);

    final colFaturaWidth = calculateHeaderWidth(
      tr('sale.complete.field.invoice_no'),
      minWidth: 110,
    );
    final colFaturaFlex = flexFromWidth(colFaturaWidth, minFlex: 3);

    final colVadeWidth = calculateHeaderWidth(
      tr('common.due_date_short'),
      minWidth: 120,
    );
    final colVadeFlex = flexFromWidth(colVadeWidth, minFlex: 3);

    final colTutarWidth = calculateHeaderWidth(
      tr('accounts.card.installments.col.installment_amount'),
      minWidth: 120,
    );
    final colTutarFlex = flexFromWidth(colTutarWidth, minFlex: 3);

    final colDurumWidth = calculateHeaderWidth(
      tr('common.status'),
      minWidth: 100,
    );
    final colDurumFlex = flexFromWidth(colDurumWidth, minFlex: 2);

    final colOdemeTarihWidth = calculateHeaderWidth(
      tr('accounts.card.installments.col.payment_date'),
      minWidth: 150,
    );
    final colOdemeTarihFlex = flexFromWidth(colOdemeTarihWidth, minFlex: 4);

    final colOdemeHesapWidth = calculateHeaderWidth(
      tr('accounts.card.installments.col.payment_account'),
      minWidth: 170,
    );
    final colOdemeHesapFlex = flexFromWidth(colOdemeHesapWidth, minFlex: 4);

    final colAciklamaWidth = calculateHeaderWidth(
      tr('common.description'),
      minWidth: 140,
    );
    final colAciklamaFlex = flexFromWidth(colAciklamaWidth, minFlex: 4);

    final colKullaniciWidth = calculateHeaderWidth(
      tr('common.user'),
      minWidth: 100,
    );
    final colKullaniciFlex = flexFromWidth(colKullaniciWidth, minFlex: 2);

    final colActionsWidth = calculateHeaderWidth(
      tr('common.actions'),
      minWidth: 90,
    );

    return GenisletilebilirTablo<Map<String, dynamic>>(
      title: '',
      totalRecords: _cachedInstallments.length,
      searchFocusNode: _searchFocusNode,
      onClearSelection: _clearAllTableSelections,
      headerWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [_buildDateRangeFilter()],
      ),
      headerTextStyle: const TextStyle(fontSize: 14),
      headerMaxLines: 1,
      headerOverflow: TextOverflow.ellipsis,
      onPageChanged: (page, rowsPerPage) {
        _loadInstallments();
      },
      onSearch: (query) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          setState(() {
            _searchQuery = query;
          });
          _loadInstallments();
        });
      },
      expandAll: false,
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
        Tooltip(
          message: tr('common.column_settings'),
          child: InkWell(
            onTap: () => _showInstallmentColumnVisibilityDialog(context),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(
                Icons.view_column_outlined,
                color: Color(0xFF2C3E50),
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (_hasInstallments)
          Tooltip(
            message: tr('accounts.card.show_installments'),
            child: InkWell(
              onTap: _toggleInstallmentsMode,
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
                  Icons.schedule_outlined,
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
                      selectedIds.isNotEmpty
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
          Builder(
            builder: (context) {
              final selectedTx = _cachedTransactions.firstWhere(
                (tx) => tx['id'] == _selectedRowId,
                orElse: () => {},
              );
              final String rawIslemTuru =
                  selectedTx['islem_turu']?.toString() ?? '';
              final String label = IslemTuruRenkleri.getProfessionalLabel(
                rawIslemTuru,
                context: 'cari',
                yon: selectedTx['yon']?.toString(),
              );
              final bool isSatis = label == 'Satış Yapıldı';

              return MouseRegion(
                cursor: isSatis
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: GestureDetector(
                  onTap: isSatis
                      ? () async {
                          final List<dynamic> rawElements =
                              selectedTx['hareket_detaylari'] is List
                              ? selectedTx['hareket_detaylari'] as List
                              : (selectedTx['hareket_detaylari'] != null
                                    ? jsonDecode(
                                            selectedTx['hareket_detaylari']
                                                .toString(),
                                          )
                                          as List
                                    : []);

                          final List<dynamic> rawItems = [];
                          for (var elem in rawElements) {
                            if (elem is List) {
                              rawItems.addAll(elem);
                            } else {
                              rawItems.add(elem);
                            }
                          }

                          final List<Map<String, dynamic>> items = rawItems.map(
                            (e) {
                              final map = Map<String, dynamic>.from(
                                e is Map ? e : {},
                              );
                              return {
                                'name': map['name'] ?? map['code'] ?? '',
                                'code': map['code'] ?? '',
                                'quantity':
                                    double.tryParse(
                                      map['quantity']?.toString() ?? '',
                                    ) ??
                                    0.0,
                                'unit': map['unit'] ?? '',
                                'price':
                                    double.tryParse(
                                      map['unitCost']?.toString() ??
                                          map['price']?.toString() ??
                                          '',
                                    ) ??
                                    0.0,
                                'total':
                                    double.tryParse(
                                      map['total']?.toString() ?? '',
                                    ) ??
                                    0.0,
                              };
                            },
                          ).toList();

                          DateTime initialDate = DateTime.now();
                          final rawTarih = selectedTx['tarih'];
                          if (rawTarih is DateTime) {
                            initialDate = rawTarih;
                          } else if (rawTarih != null) {
                            initialDate =
                                DateTime.tryParse(rawTarih.toString()) ??
                                DateTime.now();
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SatisSonrasiYazdirSayfasi(
                                entegrasyonRef:
                                    selectedTx['integration_ref']?.toString() ??
                                    '',
                                cariAdi: _currentCari.adi,
                                cariKodu: _currentCari.kodNo,
                                genelToplam:
                                    double.tryParse(
                                      selectedTx['tutar']?.toString() ?? '',
                                    ) ??
                                    0.0,
                                paraBirimi:
                                    selectedTx['para_birimi']?.toString() ??
                                    'TRY',
                                initialFaturaNo:
                                    selectedTx['fatura_no']?.toString() ?? '',
                                initialIrsaliyeNo:
                                    selectedTx['irsaliye_no']?.toString() ?? '',
                                initialTarih: initialDate,
                                items: items,
                              ),
                            ),
                          ).then((result) {
                            if (result == true) {
                              _reloadActiveList();
                            }
                          });
                        }
                      : null,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSatis
                          ? const Color(0xFF2C3E50)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSatis
                            ? const Color(0xFF2C3E50)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 18,
                          color: isSatis ? Colors.white : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr('common.print_document'),
                          style: TextStyle(
                            color: isSatis
                                ? Colors.white
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                MesajYardimcisi.bilgiGoster(
                  context,
                  tr('accounts.card.return_coming_soon'),
                );
              },
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.assignment_return_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('accounts.card.return'),
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
                        tr('common.key.f4'),
                        style: const TextStyle(
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
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        CariParaAlVerSayfasi(cari: _currentCari),
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
                ).then((result) async {
                  if (result == true) {
                    await _refreshCariDetails();
                    await _reloadActiveList();
                    _fetchCariHesaplar();
                  }
                });
              },
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3E50),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('accounts.card.cash_in_out'),
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
                        style: const TextStyle(
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
          width: colCheckboxWidth,
          alignment: Alignment.center,
          header: SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: allSelected,
              onChanged: (val) =>
                  _onSelectAllInstallments(_currentCari.id, val),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
            ),
          ),
        ),
        if (_installmentColumnVisibility['islem'] == true)
          GenisletilebilirTabloKolon(
            label: tr('products.transaction.type'),
            width: colIslemWidth,
            alignment: Alignment.centerLeft,
            flex: colIslemFlex,
          ),
        if (_installmentColumnVisibility['satis_tarihi'] == true)
          GenisletilebilirTabloKolon(
            label: tr('accounts.card.installments.col.sale_date'),
            width: colSatisTarihWidth,
            alignment: Alignment.centerLeft,
            flex: colSatisTarihFlex,
          ),
        if (_installmentColumnVisibility['fatura_no'] == true)
          GenisletilebilirTabloKolon(
            label: tr('sale.complete.field.invoice_no'),
            width: colFaturaWidth,
            alignment: Alignment.centerLeft,
            flex: colFaturaFlex,
          ),
        if (_installmentColumnVisibility['vade_tarihi'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.due_date_short'),
            width: colVadeWidth,
            alignment: Alignment.centerLeft,
            flex: colVadeFlex,
          ),
        if (_installmentColumnVisibility['tutar'] == true)
          GenisletilebilirTabloKolon(
            label: tr('accounts.card.installments.col.installment_amount'),
            width: colTutarWidth,
            alignment: Alignment.centerRight,
            flex: colTutarFlex,
          ),
        if (_installmentColumnVisibility['durum'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.status'),
            width: colDurumWidth,
            alignment: Alignment.centerLeft,
            flex: colDurumFlex,
          ),
        if (_installmentColumnVisibility['odeme_tarihi'] == true)
          GenisletilebilirTabloKolon(
            label: tr('accounts.card.installments.col.payment_date'),
            width: colOdemeTarihWidth,
            alignment: Alignment.centerLeft,
            flex: colOdemeTarihFlex,
          ),
        if (_installmentColumnVisibility['odeme_hesap'] == true)
          GenisletilebilirTabloKolon(
            label: tr('accounts.card.installments.col.payment_account'),
            width: colOdemeHesapWidth,
            alignment: Alignment.centerLeft,
            flex: colOdemeHesapFlex,
          ),
        if (_installmentColumnVisibility['aciklama'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.description'),
            width: colAciklamaWidth,
            alignment: Alignment.centerLeft,
            flex: colAciklamaFlex,
          ),
        if (_installmentColumnVisibility['kullanici'] == true)
          GenisletilebilirTabloKolon(
            label: tr('common.user'),
            width: colKullaniciWidth,
            alignment: Alignment.centerLeft,
            flex: colKullaniciFlex,
          ),
        GenisletilebilirTabloKolon(
          label: tr('common.actions'),
          width: colActionsWidth,
          alignment: Alignment.center,
        ),
      ],
      data: _cachedInstallments,
      expandOnRowTap: false,
      onFocusedRowChanged: (item, index) {
        final id = item == null ? null : parseIntId(item['id']);
        if (id == null) return;
        setState(() => _selectedInstallmentRowId = id);
      },
      isRowSelected: (row, index) =>
          parseIntId(row['id']) == _selectedInstallmentRowId,
      onRowTap: (row) {
        final id = parseIntId(row['id']);
        if (id == null) return;
        setState(() => _selectedInstallmentRowId = id);
      },
      onRowDoubleTap: (row) async {
        final ref = row['integration_ref']?.toString() ?? '';
        if (ref.isEmpty) return;
        final bool? res = await showDialog<bool>(
          context: context,
          builder: (context) => TaksitIzlemeDiyalogu(
            integrationRef: ref,
            cariAdi: _currentCari.adi,
          ),
        );
        if (res == true) {
          _refreshCariDetails();
          _refreshInstallmentAvailability();
          _loadInstallments();
        }
      },
      rowBuilder: (context, row, index, isExpanded, toggleExpand) {
        return _buildInstallmentMainRow(
          row: row,
          index: index,
          colCheckboxWidth: colCheckboxWidth,
          colIslemWidth: colIslemWidth,
          colIslemFlex: colIslemFlex,
          colSatisTarihWidth: colSatisTarihWidth,
          colSatisTarihFlex: colSatisTarihFlex,
          colFaturaWidth: colFaturaWidth,
          colFaturaFlex: colFaturaFlex,
          colVadeWidth: colVadeWidth,
          colVadeFlex: colVadeFlex,
          colTutarWidth: colTutarWidth,
          colTutarFlex: colTutarFlex,
          colDurumWidth: colDurumWidth,
          colDurumFlex: colDurumFlex,
          colOdemeTarihWidth: colOdemeTarihWidth,
          colOdemeTarihFlex: colOdemeTarihFlex,
          colOdemeHesapWidth: colOdemeHesapWidth,
          colOdemeHesapFlex: colOdemeHesapFlex,
          colAciklamaWidth: colAciklamaWidth,
          colAciklamaFlex: colAciklamaFlex,
          colKullaniciWidth: colKullaniciWidth,
          colKullaniciFlex: colKullaniciFlex,
          colActionsWidth: colActionsWidth,
        );
      },
      detailBuilder: (context, row) => const SizedBox.shrink(),
    );
  }

  Widget _buildInstallmentMainRow({
    required Map<String, dynamic> row,
    required int index,
    required double colCheckboxWidth,
    required double colIslemWidth,
    required int colIslemFlex,
    required double colSatisTarihWidth,
    required int colSatisTarihFlex,
    required double colFaturaWidth,
    required int colFaturaFlex,
    required double colVadeWidth,
    required int colVadeFlex,
    required double colTutarWidth,
    required int colTutarFlex,
    required double colDurumWidth,
    required int colDurumFlex,
    required double colOdemeTarihWidth,
    required int colOdemeTarihFlex,
    required double colOdemeHesapWidth,
    required int colOdemeHesapFlex,
    required double colAciklamaWidth,
    required int colAciklamaFlex,
    required double colKullaniciWidth,
    required int colKullaniciFlex,
    required double colActionsWidth,
  }) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    final selectedIds = _selectedInstallmentIds[_currentCari.id] ?? <int>{};
    final int? installmentId = row['id'] is int
        ? row['id'] as int
        : int.tryParse(row['id']?.toString() ?? '');
    final bool isChecked =
        installmentId != null && selectedIds.contains(installmentId);

    final int sira = int.tryParse(row['taksit_sira']?.toString() ?? '') ?? 0;
    final int toplam =
        int.tryParse(row['taksit_toplam']?.toString() ?? '') ?? 0;
    final String taksitLabel = sira > 0 && toplam > 0
        ? '${tr('accounts.card.installments.installment')} $sira/$toplam'
        : tr('accounts.card.installments.installment');

    final String durum = row['durum']?.toString() ?? '';
    final bool isPaid =
        durum.toLowerCase().contains('ödendi') ||
        durum.toLowerCase().contains('odendi');

    final satisTarihiRaw = row['satis_tarihi'];
    final satisTarihiDt = parseDate(satisTarihiRaw);
    final satisTarihStr = satisTarihiDt != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(satisTarihiDt)
        : '-';

    final vadeDt = parseDate(row['vade_tarihi']);
    final vtStr = vadeDt != null
        ? DateFormat('dd.MM.yyyy').format(vadeDt)
        : '-';

    final faturaNo = row['satis_fatura_no']?.toString() ?? '';

    final double taksitTutar = parseDouble(row['tutar']);
    final double satisTutar = parseDouble(row['satis_tutar']);

    final odemeTarihiDt = parseDate(row['odeme_tarihi']);
    final odemeTarihStr = odemeTarihiDt != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(odemeTarihiDt)
        : '-';

    final String odemeKaynakAdi = row['odeme_kaynak_adi']?.toString() ?? '';
    final String odemeKaynakKodu = row['odeme_kaynak_kodu']?.toString() ?? '';
    final String odemeKaynakTuru = row['odeme_kaynak_turu']?.toString() ?? '';
    String odemeHesapStr = '-';
    if (odemeKaynakAdi.isNotEmpty || odemeKaynakTuru.isNotEmpty) {
      odemeHesapStr = odemeKaynakAdi.isNotEmpty
          ? odemeKaynakAdi
          : IslemCeviriYardimcisi.cevir(odemeKaynakTuru);
      if (odemeKaynakKodu.isNotEmpty) {
        odemeHesapStr += ' $odemeKaynakKodu';
      }
      if (odemeKaynakTuru.isNotEmpty && odemeKaynakAdi.isNotEmpty) {
        odemeHesapStr += ' (${IslemCeviriYardimcisi.cevir(odemeKaynakTuru)})';
      }
    }

    final String aciklama = row['aciklama']?.toString() ?? '';
    final String kullanici =
        (row['odeme_kullanici']?.toString() ?? '').isNotEmpty
        ? row['odeme_kullanici']?.toString() ?? ''
        : (row['satis_kullanici']?.toString() ?? '');

    Color statusBg = Colors.orange.withValues(alpha: 0.12);
    Color statusBorder = Colors.orange.withValues(alpha: 0.35);
    Color statusFg = Colors.orange.shade800;
    if (isPaid) {
      statusBg = Colors.green.withValues(alpha: 0.12);
      statusBorder = Colors.green.withValues(alpha: 0.35);
      statusFg = Colors.green.shade800;
    }

    Widget buildVadeCell() {
      if (vadeDt == null) {
        return const Text('-', style: TextStyle(fontSize: 13));
      }
      if (isPaid) {
        return Text(vtStr, style: const TextStyle(fontSize: 13));
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final vade = DateTime(vadeDt.year, vadeDt.month, vadeDt.day);
      final diff = vade.difference(today).inDays;

      Color color = Colors.black87;
      String suffix = '';
      if (diff < 0) {
        color = Colors.red.shade700;
        suffix = ' (${diff.abs()} Gün Geçti)';
      } else if (diff == 0) {
        color = Colors.orange.shade800;
        suffix = ' (Bugün)';
      } else {
        color = Colors.green.shade700;
        suffix = ' ($diff Gün Kaldı)';
      }

      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: vtStr,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            TextSpan(
              text: suffix,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 52,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          _buildCell(
            width: colCheckboxWidth,
            alignment: Alignment.center,
            child: SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: isChecked,
                onChanged: (val) {
                  if (installmentId != null) {
                    _onSelectInstallmentRow(
                      _currentCari.id,
                      installmentId,
                      val,
                    );
                  }
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
                side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
              ),
            ),
          ),
          if (_installmentColumnVisibility['islem'] == true)
            _buildCell(
              width: colIslemWidth,
              flex: colIslemFlex,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HighlightText(
                    text: taksitLabel,
                    query: _searchQuery,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (satisTutar > 0)
                    Text(
                      '${tr('common.total_amount')}: ${FormatYardimcisi.sayiFormatlaOndalikli(satisTutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_currentCari.paraBirimi}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          if (_installmentColumnVisibility['satis_tarihi'] == true)
            _buildCell(
              width: colSatisTarihWidth,
              flex: colSatisTarihFlex,
              child: Text(satisTarihStr, style: const TextStyle(fontSize: 13)),
            ),
          if (_installmentColumnVisibility['fatura_no'] == true)
            _buildCell(
              width: colFaturaWidth,
              flex: colFaturaFlex,
              child: HighlightText(
                text: faturaNo.isNotEmpty ? faturaNo : '-',
                query: _searchQuery,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          if (_installmentColumnVisibility['vade_tarihi'] == true)
            _buildCell(
              width: colVadeWidth,
              flex: colVadeFlex,
              child: buildVadeCell(),
            ),
          if (_installmentColumnVisibility['tutar'] == true)
            _buildCell(
              width: colTutarWidth,
              flex: colTutarFlex,
              alignment: Alignment.centerRight,
              child: Text(
                '${FormatYardimcisi.sayiFormatlaOndalikli(taksitTutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_currentCari.paraBirimi}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isPaid ? Colors.green.shade800 : Colors.black87,
                ),
              ),
            ),
          if (_installmentColumnVisibility['durum'] == true)
            _buildCell(
              width: colDurumWidth,
              flex: colDurumFlex,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusBorder),
                ),
                child: Text(
                  durum.isNotEmpty ? durum : '-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusFg,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          if (_installmentColumnVisibility['odeme_tarihi'] == true)
            _buildCell(
              width: colOdemeTarihWidth,
              flex: colOdemeTarihFlex,
              child: Text(odemeTarihStr, style: const TextStyle(fontSize: 13)),
            ),
          if (_installmentColumnVisibility['odeme_hesap'] == true)
            _buildCell(
              width: colOdemeHesapWidth,
              flex: colOdemeHesapFlex,
              child: HighlightText(
                text: odemeHesapStr,
                query: _searchQuery,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          if (_installmentColumnVisibility['aciklama'] == true)
            _buildCell(
              width: colAciklamaWidth,
              flex: colAciklamaFlex,
              child: HighlightText(
                text: aciklama.isNotEmpty ? aciklama : '-',
                query: _searchQuery,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          if (_installmentColumnVisibility['kullanici'] == true)
            _buildCell(
              width: colKullaniciWidth,
              flex: colKullaniciFlex,
              child: HighlightText(
                text: kullanici,
                query: _searchQuery,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          _buildCell(
            width: colActionsWidth,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Tooltip(
              message: tr('sale.complete.installments_title'),
              child: InkWell(
                onTap: () async {
                  final ref = row['integration_ref']?.toString() ?? '';
                  if (ref.isEmpty) return;
                  final bool? res = await showDialog<bool>(
                    context: context,
                    builder: (context) => TaksitIzlemeDiyalogu(
                      integrationRef: ref,
                      cariAdi: _currentCari.adi,
                    ),
                  );
                  if (res == true) {
                    _refreshCariDetails();
                    _refreshInstallmentAvailability();
                    _loadInstallments();
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF2C3E50).withValues(alpha: 0.15),
                    ),
                  ),
                  child: const Icon(
                    Icons.analytics_rounded,
                    size: 16,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ana satır - temel bilgiler (11 sütun)
  Widget _buildTransactionMainRow({
    required Map<String, dynamic> tx,
    required int index,
    required bool isExpanded,
    required VoidCallback toggleExpand,
    required double colCheckboxWidth,
    required double colIslemWidth,
    required int colIslemFlex,
    required double colTarihWidth,
    required int colTarihFlex,
    required double colTutarWidth,
    required int colTutarFlex,
    required double colBakiyeBorcWidth,
    required int colBakiyeBorcFlex,
    required double colBakiyeAlacakWidth,
    required int colBakiyeAlacakFlex,
    required double colYerWidth,
    required int colYerFlex,
    required double colAciklamaWidth,
    required int colAciklamaFlex,
    required double colVadeTarihiWidth,
    required int colVadeTarihiFlex,
    required double colKullaniciWidth,
    required int colKullaniciFlex,
    required double colActionsWidth,
  }) {
    final selectedIds = _selectedDetailIds[_currentCari.id] ?? <int>{};
    final txId = tx['id'] as int?;
    final isSelected = txId != null && selectedIds.contains(txId);
    const primaryColor = Color(0xFF2C3E50);

    // Değerleri al
    final rawIslemTuru = tx['islem_turu']?.toString() ?? '';
    String islemTuru = rawIslemTuru.contains('Açılış')
        ? rawIslemTuru
        : IslemTuruRenkleri.getProfessionalLabel(rawIslemTuru, context: 'cari');

    // Yön belirleme (Erken Tanımlama ve Override)
    final yon = tx['yon']?.toString() ?? '';
    final String integrationRef = tx['integration_ref']?.toString() ?? '';
    bool isIncoming =
        yon.toLowerCase().contains('alacak') ||
        islemTuru.toLowerCase().contains('tahsilat') ||
        islemTuru.toLowerCase().contains('alındı') ||
        islemTuru.toLowerCase().contains('alindi') ||
        islemTuru.toLowerCase().contains('alış');

    // [CUSTOM] Para Al/Ver Etiket Override
    if (rawIslemTuru == 'Cari İşlem' || islemTuru == 'Cari İşlem') {
      if (yon == 'Alacak') {
        // Satış tahsilatı da dahil: Para Alındı
        islemTuru = 'Para Alındı';
        isIncoming = true; // Girdi (Yeşil)
      } else if (yon == 'Borç') {
        // Alış ödemesi de dahil: Para Verildi
        islemTuru = 'Para Verildi';
        isIncoming = false; // Çıktı (Kırmızı)
      }
    }

    // Tarih formatla
    String tarihStr = '';
    final rawTarih = tx['tarih'];
    final createdAt = tx['created_at'];
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    DateTime? parseDate(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is DateTime) {
        return value;
      }
      final text = value.toString();
      for (final format in [
        DateFormat('dd.MM.yyyy HH:mm'),
        DateFormat('dd.MM.yyyy HH:mm:ss'),
        DateFormat('dd.MM.yyyy'),
      ]) {
        try {
          return format.parse(text);
        } catch (_) {}
      }
      return DateTime.tryParse(text);
    }

    if (rawTarih != null && rawTarih.toString().isNotEmpty) {
      final dt = parseDate(rawTarih);
      tarihStr = dt != null ? dateFormat.format(dt) : rawTarih.toString();
    } else if (createdAt != null) {
      final dt = parseDate(createdAt);
      if (dt != null) {
        tarihStr = dateFormat.format(dt);
      } else {
        tarihStr = createdAt.toString();
      }
    }

    // Helper for safe double parsing
    double parseDouble(dynamic value) {
      if (value == null) {
        return 0.0;
      }
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    // Tutar değerleri
    final tutar = parseDouble(tx['tutar']);
    final bool hasRunningBalance = tx['running_balance'] != null;
    final runningBalance = hasRunningBalance
        ? parseDouble(tx['running_balance'])
        : 0.0;
    final bakiyeBorcDb = parseDouble(tx['bakiye_borc']);
    final bakiyeAlacakDb = parseDouble(tx['bakiye_alacak']);

    final bakiyeBorcGosterim = hasRunningBalance
        ? (runningBalance > 0 ? runningBalance : 0.0)
        : bakiyeBorcDb;
    final bakiyeAlacakGosterim = hasRunningBalance
        ? (runningBalance < 0 ? runningBalance.abs() : 0.0)
        : bakiyeAlacakDb;

    // Diğer alanlar
    final aciklama = rawIslemTuru.contains('Açılış')
        ? ''
        : (tx['aciklama']?.toString() ?? '');

    // Kaynak bilgilerini hazırla (CariHesaplarSayfasi ile aynı mantık)
    String locationName =
        tx['kaynak_adi']?.toString() ?? tx['yer']?.toString() ?? '';
    String locationCode = tx['kaynak_kodu']?.toString() ?? '';
    final sourceId = tx['source_id'] is int
        ? tx['source_id'] as int
        : int.tryParse(tx['source_id']?.toString() ?? '');

    // Eğer veritabanında kaynak bilgisi yoksa, açıklamadan çıkarmaya çalış
    if (locationName.isEmpty && aciklama.isNotEmpty) {
      if (aciklama.contains(' - ')) {
        final parts = aciklama.split(' - ');
        if (parts.length >= 2) {
          locationName = parts.sublist(1).join(' - ').trim();
        }
      }
    }

    // Source ID varsa ve kod boşsa, ID'yi kod olarak kullan
    if (locationCode.isEmpty && sourceId != null && sourceId > 0) {
      locationCode = '#$sourceId';
    }

    final locationType = islemTuru;

    // Yön belirleme (Removed duplicate declarations)

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          // 1. Checkbox (Always visible)
          _buildCell(
            width: colCheckboxWidth,
            alignment: Alignment.center,
            child: SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: isSelected,
                onChanged: (val) {
                  if (txId != null) {
                    _onSelectDetailRow(_currentCari.id, txId, val);
                  }
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
                side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
              ),
            ),
          ),
          // 2. İşlem
          if (_columnVisibility['islem'] == true)
            _buildCell(
              width: colIslemWidth,
              flex: colIslemFlex,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  if (rawIslemTuru.contains('Açılış') ||
                      rawIslemTuru == 'Cari İşlem' ||
                      islemTuru == 'Para Alındı' ||
                      islemTuru == 'Para Verildi' ||
                      islemTuru.startsWith('Ödeme Alındı') ||
                      islemTuru.startsWith('Ödeme Yapıldı') ||
                      islemTuru == 'Borç Dekontu' ||
                      islemTuru == 'Alacak Dekontu' ||
                      rawIslemTuru.contains('Dekont') ||
                      islemTuru.contains('Çek') ||
                      islemTuru.contains('Senet'))
                    const SizedBox(width: 20, height: 20)
                  else
                    InkWell(
                      onTap: toggleExpand,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: AnimatedRotation(
                          turns: isExpanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: IslemTuruRenkleri.arkaplanRengiGetir(
                        islemTuru,
                        isIncoming,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      isIncoming
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: IslemTuruRenkleri.ikonRengiGetir(
                        islemTuru,
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
                        Row(
                          children: [
                            Flexible(
                              child: HighlightText(
                                text: IslemCeviriYardimcisi.cevir(islemTuru),
                                query: _searchQuery,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: IslemTuruRenkleri.metinRengiGetir(
                                    islemTuru,
                                    isIncoming,
                                  ),
                                ),
                              ),
                            ),
                            if (aciklama.contains('Taksitli Satış') &&
                                (rawIslemTuru.toLowerCase().contains('satış') ||
                                    rawIslemTuru.toLowerCase().contains(
                                      'satis',
                                    )))
                              Padding(
                                padding: const EdgeInsets.only(left: 6.0),
                                child: InkWell(
                                  onTap: () async {
                                    final bool? res = await showDialog<bool>(
                                      context: context,
                                      builder: (context) =>
                                          TaksitIzlemeDiyalogu(
                                            integrationRef: integrationRef,
                                            cariAdi: _currentCari.adi,
                                          ),
                                    );
                                    if (res == true) {
                                      _refreshCariDetails();
                                      _loadTransactions();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: primaryColor.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.analytics_rounded,
                                          size: 10,
                                          color: primaryColor,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          tr('accounts.card.installments'),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_getSourceSuffix(
                          rawIslemTuru, // Use raw type for suffix check
                          tx['integration_ref']?.toString(),
                          locationName,
                        ).isNotEmpty)
                          HighlightText(
                            text:
                                IslemCeviriYardimcisi.parantezliKaynakKisaltma(
                                  _getSourceSuffix(
                                    rawIslemTuru,
                                    tx['integration_ref']?.toString(),
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // 3. Tarih
          if (_columnVisibility['tarih'] == true)
            _buildCell(
              width: colTarihWidth,
              flex: colTarihFlex,
              child: HighlightText(
                text: tarihStr,
                query: _searchQuery,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          // 4. Tutar
          if (_columnVisibility['tutar'] == true)
            _buildCell(
              width: colTutarWidth,
              flex: colTutarFlex,
              alignment: Alignment.centerRight,
              child: HighlightText(
                text:
                    '${FormatYardimcisi.sayiFormatlaOndalikli(tutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_currentCari.paraBirimi}',
                query: _searchQuery,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isIncoming
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
            ),
          // 5. Bakiye Borç
          if (_columnVisibility['bakiye_borc'] == true)
            _buildCell(
              width: colBakiyeBorcWidth,
              flex: colBakiyeBorcFlex,
              alignment: Alignment.centerRight,
              child: HighlightText(
                text: bakiyeBorcGosterim > 0
                    ? '${FormatYardimcisi.sayiFormatlaOndalikli(bakiyeBorcGosterim, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_currentCari.paraBirimi}'
                    : '-',
                query: _searchQuery,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          // 6. Bakiye Alacak
          if (_columnVisibility['bakiye_alacak'] == true)
            _buildCell(
              width: colBakiyeAlacakWidth,
              flex: colBakiyeAlacakFlex,
              alignment: Alignment.centerRight,
              child: HighlightText(
                text: bakiyeAlacakGosterim > 0
                    ? '${FormatYardimcisi.sayiFormatlaOndalikli(bakiyeAlacakGosterim, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_currentCari.paraBirimi}'
                    : '-',
                query: _searchQuery,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          // 7. İlgili Hesap
          if (_columnVisibility['ilgili_hesap'] == true)
            _buildCell(
              width: colYerWidth,
              flex: colYerFlex,
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
                                    ? IslemCeviriYardimcisi.cevir(locationType)
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
                                  _currentCari.adi.toLowerCase(),
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
                                  borderRadius: BorderRadius.circular(3),
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
                  else if (locationType.isNotEmpty || locationCode.isNotEmpty)
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
                          border: Border.all(color: Colors.grey.shade300),
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
          // 8. Açıklama
          if (_columnVisibility['aciklama'] == true)
            _buildCell(
              width: colAciklamaWidth,
              flex: colAciklamaFlex,
              child: HighlightText(
                text: aciklama,
                query: _searchQuery,
                maxLines: 3,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
              ),
            ),
          // 9. Vade Tarihi
          if (_columnVisibility['vade_tarihi'] == true)
            _buildCell(
              width: colVadeTarihiWidth,
              flex: colVadeTarihiFlex,
              child: Builder(
                builder: (context) {
                  final vt =
                      (tx['islem_turu']?.toString() ?? '').contains('Çek') ||
                          (tx['islem_turu']?.toString() ?? '').contains('Senet')
                      ? tx['tarih']
                      : tx['vade_tarihi'];
                  String vtStr = '-';
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

                  final bool isCheckOrNote =
                      (tx['islem_turu']?.toString() ?? '').contains('Çek') ||
                      (tx['islem_turu']?.toString() ?? '').contains('Senet');

                  if (vtStr == '-' || !isCheckOrNote) {
                    return Text(vtStr, style: const TextStyle(fontSize: 13));
                  }

                  // Compare with today
                  DateTime? dtVt;
                  try {
                    if (vt is DateTime) {
                      dtVt = vt;
                    } else {
                      dtVt = DateTime.tryParse(vt.toString());
                    }
                  } catch (_) {}

                  if (dtVt == null) {
                    return Text(vtStr, style: const TextStyle(fontSize: 13));
                  }

                  // Normalize to date only
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final vade = DateTime(dtVt.year, dtVt.month, dtVt.day);

                  final diff = vade.difference(today).inDays;
                  Color color = Colors.black87;
                  String suffix = '';

                  if (diff < 0) {
                    // Passed
                    color = Colors.red.shade700;
                    suffix = ' (${diff.abs()} Gün Geçti)';
                  } else if (diff == 0) {
                    // Today
                    color = Colors.orange.shade800;
                    suffix = ' (Bugün)';
                  } else {
                    // Future
                    color = Colors.green.shade700;
                    suffix = ' ($diff Gün Kaldı)';
                  }

                  return RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: vtStr,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        TextSpan(
                          text: suffix,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          // 10. Kullanıcı
          if (_columnVisibility['kullanici'] == true)
            _buildCell(
              width: colKullaniciWidth,
              flex: colKullaniciFlex,
              child: HighlightText(
                text: tx['kullanici']?.toString() ?? '',
                query: _searchQuery,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          // 11. İşlemler
          _buildCell(
            width: colActionsWidth,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildTransactionPopupMenu(
              tx,
              _getSourceSuffix(
                rawIslemTuru,
                tx['integration_ref']?.toString(),
                locationName,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Transaction için popup menü
  Widget _buildTransactionPopupMenu(
    Map<String, dynamic> tx,
    String sourceSuffix,
  ) {
    final String integrationRef = tx['integration_ref']?.toString() ?? '';
    final String yonLower = (tx['yon']?.toString() ?? '').toLowerCase();
    final String aciklamaLower = (tx['aciklama']?.toString() ?? '')
        .toLowerCase();
    final bool isSaleDownPaymentTx =
        integrationRef.startsWith('SALE-') &&
        yonLower.contains('alacak') &&
        (aciklamaLower.contains('peşinat') ||
            aciklamaLower.contains('pesinat'));

    // Hedef sayfa indexini belirle
    int? targetIndex;

    // 1. Kaynak Modül Kontrolü (Suffix)
    if (!isSaleDownPaymentTx && sourceSuffix == '(Kasa)') {
      targetIndex = 13;
    } else if (!isSaleDownPaymentTx && sourceSuffix == '(Banka)') {
      targetIndex = 15;
    } else if (!isSaleDownPaymentTx && sourceSuffix == '(K.Kartı)') {
      targetIndex = 16;
    }

    // 2. İşlem Türü Kontrolü (Çek/Senet)
    if (targetIndex == null) {
      final String islemTuruLower = (tx['islem_turu']?.toString() ?? '')
          .toLowerCase();
      if (islemTuruLower.contains('senet')) {
        targetIndex = 17; // Senetler
      } else if (islemTuruLower.contains('çek') ||
          islemTuruLower.contains('cek')) {
        targetIndex = 14; // Çekler
      }
    }

    Widget mainActionWidget;

    // Eğer bir hedef sayfa belirlendiyse, yönlendirme butonu göster
    if (targetIndex != null) {
      mainActionWidget = Tooltip(
        message: tr('common.go_to_related_page'),
        child: InkWell(
          onTap: () {
            final tabScope = TabAciciScope.of(context);
            if (tabScope == null) {
              return;
            }

            // Akıllı Arama Sorgusu Oluştur
            String searchQuery = '';
            final belgeNo = tx['belge']?.toString() ?? '';
            final evrakNo = tx['evrak_no']?.toString() ?? '';
            final aciklama = tx['aciklama']?.toString() ?? '';
            final tutar = tx['tutar']?.toString() ?? '';

            if (belgeNo.isNotEmpty) {
              searchQuery = belgeNo;
            } else if (evrakNo.isNotEmpty) {
              searchQuery = evrakNo;
            } else if (aciklama.isNotEmpty) {
              searchQuery = aciklama;
            } else if (tutar.isNotEmpty) {
              searchQuery = tutar;
            }

            tabScope.tabAc(
              menuIndex: targetIndex!,
              initialSearchQuery: searchQuery,
            );
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.blue.shade100.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: Colors.blue.shade700,
            ),
          ),
        ),
      );
    } else {
      mainActionWidget = Theme(
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
          onSelected: (value) => _onActionSelected(value, tx),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 22),
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
                  Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: const Color(0xFF4A4A4A),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tr('common.edit'),
                    style: TextStyle(
                      color: Color(0xFF4A4A4A),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem<String>(
              value: 'delete',
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: const Color(0xFFEA4335),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tr('common.delete'),
                    style: TextStyle(
                      color: Color(0xFFEA4335),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final bool isSingleViewActive = _singleViewRowId == tx['id'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Single View Toggle Icon
        Tooltip(
          message: isSingleViewActive
              ? tr('common.show_all_rows') // "Tümünü Göster"
              : tr('common.show_single_row'), // "Sadece Bu Satırı Göster"
          child: InkWell(
            onTap: () => _toggleSingleView(tx['id'] as int),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSingleViewActive
                    ? const Color(0xFFE0F2F1) // Teal shade for active
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isSingleViewActive
                    ? Border.all(color: const Color(0xFFB2DFDB))
                    : null,
              ),
              child: Icon(
                isSingleViewActive
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 12,
                color: isSingleViewActive
                    ? const Color(0xFF00695C)
                    : Colors.grey.shade500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        mainActionWidget,
      ],
    );
  }

  Future<void> _urunBarkodlariniYukle(Set<String> kodlar) async {
    final toFetch = kodlar
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .where((k) => !_urunBarkodCache.containsKey(k))
        .where((k) => !_urunBarkodFetchInProgress.contains(k))
        .toSet();

    if (toFetch.isEmpty) {
      return;
    }

    _urunBarkodFetchInProgress.addAll(toFetch);
    try {
      final fetched = await UrunlerVeritabaniServisi().urunBarkodlariniGetir(
        toFetch.toList(),
      );

      final Map<String, String?> updates = {
        for (final code in toFetch) code: fetched[code],
      };

      _urunBarkodCache.addAll(updates);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Barkodlar alınamadı: $e');
    } finally {
      _urunBarkodFetchInProgress.removeAll(toFetch);
    }
  }

  String _normalizeTurkish(String text) {
    if (text.isEmpty) {
      return '';
    }
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

  bool _matchesSearchQuery(Map<String, dynamic> tx, String query) {
    if (query.isEmpty) {
      return true;
    }
    final normalizedQuery = _normalizeTurkish(query);
    final parts = normalizedQuery
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();

    // 1. Veri Hazırlığı
    final rawIslemTuru = tx['islem_turu']?.toString() ?? '';
    final String islemLabel = IslemTuruRenkleri.getProfessionalLabel(
      rawIslemTuru,
      context: 'cari',
      yon: tx['yon']?.toString(),
    );
    final String yon = tx['yon']?.toString() ?? '';
    final String entRef = tx['integration_ref']?.toString() ?? '';

    // Tarih
    String tarihStr = '';
    final rawTarih = tx['tarih'];
    final createdAt = tx['created_at'];
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    DateTime? parseDate(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is DateTime) {
        return value;
      }
      final text = value.toString();
      for (final format in [
        DateFormat('dd.MM.yyyy HH:mm'),
        DateFormat('dd.MM.yyyy HH:mm:ss'),
        DateFormat('dd.MM.yyyy'),
      ]) {
        try {
          return format.parse(text);
        } catch (_) {}
      }
      return DateTime.tryParse(text);
    }

    if (rawTarih != null) {
      final dt = parseDate(rawTarih);
      if (dt != null) {
        tarihStr = dateFormat.format(dt);
      }
    } else if (createdAt != null) {
      final dt = parseDate(createdAt);
      if (dt != null) {
        tarihStr = dateFormat.format(dt);
      } else {
        tarihStr = createdAt.toString();
      }
    }

    // Stok Hareketleri Detay Metni (JSON'dan çıkarılacak veya direkt varsa)
    String detailText = '';
    // Eğer hareket_detaylari alanı varsa:
    if (tx['hareket_detaylari'] != null) {
      final details = tx['hareket_detaylari']; // dynamic (String veya List)
      if (details is String && details.isNotEmpty) {
        detailText += ' $details';
      } else if (details is List && details.isNotEmpty) {
        // Basitçe flatten et
        detailText += ' ${details.toString()}';
      }
    }
    // Ayrıca urun_adi, aciklama2 vs.
    final urunAdi = tx['urun_adi']?.toString() ?? '';
    final aciklama2 = tx['aciklama2']?.toString() ?? '';
    final belge = tx['belge']?.toString() ?? '';
    final eBelge = tx['e_belge']?.toString() ?? '';
    final irsaliye = tx['irsaliye_no']?.toString() ?? '';
    final fatura = tx['fatura_no']?.toString() ?? '';

    // Birleşik Arama Metni
    final fullText = _normalizeTurkish('''
      $rawIslemTuru 
      $islemLabel 
      $yon 
      $entRef 
      $tarihStr
      ${tx['aciklama'] ?? ''} 
      ${tx['kaynak_adi'] ?? ''}
      ${tx['kaynak_kodu'] ?? ''}
      ${tx['user_name'] ?? ''}
      ${tx['kullanici'] ?? ''}
      ${tx['tutar'] ?? ''}
      ${tx['bakiye_borc'] ?? ''}
      ${tx['bakiye_alacak'] ?? ''}
      $urunAdi
      $aciklama2
      $belge
      $eBelge
      $irsaliye
      $fatura
      $detailText
    ''');

    // [2026 FIX] Manuel Joker Kelimeler (Client-Side)
    String jokerText = '';
    final isIncoming =
        yon.toLowerCase().contains('alacak') ||
        rawIslemTuru.toLowerCase().contains('tahsilat') ||
        rawIslemTuru.toLowerCase().contains('alış');

    if (isIncoming) {
      jokerText +=
          ' para alindi cek alindi senet alindi tahsilat giris girdi odeme alindi';
      if (entRef.startsWith('SALE-')) {
        jokerText += ' satis satıs satış';
      }
    } else {
      jokerText +=
          ' para verildi cek verildi senet verildi odeme cikis cikti odeme yapildi';
      if (entRef.startsWith('PURCHASE-')) {
        jokerText += ' alis alıs alış';
      }
    }

    final searchableText = '$fullText $jokerText';

    // Tüm parçalar eşleşmeli (AND mantığı)
    for (final part in parts) {
      if (!searchableText.contains(part)) {
        return false;
      }
    }
    return true;
  }

  // [2026 FIX] Genişleyen satırda arama yapıldığında otomatik açılması için detay kontrolü
  bool _shouldExpandForSearch(Map<String, dynamic> tx, String query) {
    if (query.isEmpty) {
      return false;
    }
    final normalizedQuery = _normalizeTurkish(query);
    final parts = normalizedQuery
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();

    // Stok Hareketleri Detay Metni (JSON'dan çıkarılacak veya direkt varsa)
    String detailText = '';
    // Eğer hareket_detaylari alanı varsa:
    if (tx['hareket_detaylari'] != null) {
      final details = tx['hareket_detaylari']; // dynamic (String veya List)
      if (details is String && details.isNotEmpty) {
        detailText += ' $details';
      } else if (details is List && details.isNotEmpty) {
        // Basitçe flatten et
        detailText += ' ${details.toString()}';
      }
    }
    // Ayrıca urun_adi, aciklama2 vs.
    final urunAdi = tx['urun_adi']?.toString() ?? '';
    final aciklama2 = tx['aciklama2']?.toString() ?? '';
    final belge = tx['belge']?.toString() ?? '';
    final eBelge = tx['e_belge']?.toString() ?? '';
    final irsaliye = tx['irsaliye_no']?.toString() ?? '';
    final fatura = tx['fatura_no']?.toString() ?? '';

    // Sadece detay alanlarını birleştir
    final fullDetailText = _normalizeTurkish('''
      $urunAdi
      $aciklama2
      $belge
      $eBelge
      $irsaliye
      $fatura
      $detailText
    ''');

    // Eğer arama terimlerinden herhangi biri detay alanında geçiyorsa genişlet
    for (final part in parts) {
      if (fullDetailText.contains(part)) {
        return true;
      }
    }
    return false;
  }

  Widget _buildTransactionDetailRow(Map<String, dynamic> tx) {
    final txId = tx['id'] as int?;
    final selectedIds = _selectedDetailIds[_currentCari.id] ?? <int>{};
    final isSelected = txId != null && selectedIds.contains(txId);

    // Değerleri al
    final islemTuru = tx['islem_turu']?.toString() ?? '';
    final urunAdi = tx['urun_adi']?.toString() ?? '';
    // Helper for safe double parsing
    double parseDouble(dynamic value) {
      if (value == null) {
        return 0.0;
      }
      if (value is num) {
        return value.toDouble();
      }
      final text = value.toString().trim();
      if (text.isEmpty) {
        return 0.0;
      }
      return double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
    }

    double parseRatio(dynamic value) {
      if (value == null) {
        return 0.0;
      }
      if (value is num) {
        return value.toDouble();
      }
      final text = value.toString().trim();
      if (text.isEmpty) {
        return 0.0;
      }
      if (text.contains('/')) {
        final parts = text.split('/');
        if (parts.length == 2) {
          final num = parseDouble(parts[0]);
          final den = parseDouble(parts[1]);
          if (den != 0) {
            return num / den;
          }
        }
      }
      final parsed = parseDouble(text);
      // If user passed as percentage (e.g., "50"), normalize to ratio
      if (parsed > 1 && parsed <= 100) {
        return parsed / 100.0;
      }
      return parsed;
    }

    String fmtAmount(double value) => FormatYardimcisi.sayiFormatlaOndalikli(
      value,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.fiyatOndalik,
    );

    String fmtPercent(double value) {
      if (!value.isFinite) {
        return '0';
      }
      final rounded = value.roundToDouble();
      final isInt = (value - rounded).abs() < 0.01;
      return isInt ? value.round().toString() : value.toStringAsFixed(2);
    }

    Widget buildTaxCell({required double amount, required double ratePercent}) {
      if (amount <= 0 || ratePercent <= 0) {
        return Text(
          '-',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${fmtAmount(amount)} ${_currentCari.paraBirimi}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 8.5,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
          Text(
            '(${fmtPercent(ratePercent)}%)',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 6.5,
              color: Colors.grey.shade600,
              height: 1.0,
            ),
          ),
        ],
      );
    }

    final belge = tx['belge']?.toString() ?? '';
    final eBelge = tx['e_belge']?.toString() ?? '';
    final irsaliyeNo = tx['irsaliye_no']?.toString() ?? '';
    final faturaNo = tx['fatura_no']?.toString() ?? '';
    final aciklama2 = tx['aciklama2']?.toString() ?? '';

    // Tarih formatla
    String tarihStr = '';
    final rawTarih = tx['tarih'];
    final createdAt = tx['created_at'];
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    DateTime? parseDate(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is DateTime) {
        return value;
      }
      final text = value.toString();
      for (final format in [
        DateFormat('dd.MM.yyyy HH:mm'),
        DateFormat('dd.MM.yyyy HH:mm:ss'),
        DateFormat('dd.MM.yyyy'),
      ]) {
        try {
          return format.parse(text);
        } catch (_) {}
      }
      return DateTime.tryParse(text);
    }

    if (rawTarih != null && rawTarih.toString().isNotEmpty) {
      final dt = parseDate(rawTarih);
      tarihStr = dt != null ? dateFormat.format(dt) : rawTarih.toString();
    } else if (createdAt != null) {
      final dt = parseDate(createdAt);
      if (dt != null) {
        tarihStr = dateFormat.format(dt);
      } else {
        tarihStr = createdAt.toString();
      }
    }

    // Yön belirleme
    final yon = tx['yon']?.toString() ?? '';
    final bool isBorc =
        yon.toLowerCase().contains('borç') ||
        yon.toLowerCase().contains('debit') ||
        (islemTuru.toLowerCase().contains('satış') &&
            !islemTuru.toLowerCase().contains('iade'));

    // Ayarlara göre ekstra vergi sütunlarını sadece değer varsa göster
    final List<dynamic> detailProbe = [];
    void addProbe(dynamic value) {
      if (value == null) {
        return;
      }
      if (value is List) {
        for (final v in value) {
          addProbe(v);
        }
        return;
      }
      if (value is Map) {
        detailProbe.add(value);
        return;
      }
      if (value is String) {
        try {
          addProbe(jsonDecode(value));
        } catch (_) {}
      }
    }

    addProbe(tx['hareket_detaylari']);
    if (detailProbe.isEmpty) {
      detailProbe.add(tx);
    }

    final bool showOtvColumn =
        _genelAyarlar.otvKullanimi &&
        detailProbe.any((d) {
          if (d is! Map) {
            return false;
          }
          return parseDouble(d['otvRate'] ?? d['otv_rate']) > 0;
        });
    final bool showOivColumn =
        _genelAyarlar.oivKullanimi &&
        detailProbe.any((d) {
          if (d is! Map) {
            return false;
          }
          return parseDouble(d['oivRate'] ?? d['oiv_rate']) > 0;
        });
    final bool showTevkifatColumn =
        _genelAyarlar.kdvTevkifati &&
        detailProbe.any((d) {
          if (d is! Map) {
            return false;
          }
          return parseRatio(
                d['kdvTevkifatOrani'] ??
                    d['kdv_tevkifat_orani'] ??
                    d['tevkifatOrani'] ??
                    d['tevkifat'],
              ) >
              0;
        });

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Son Hareketler Başlığı with all checkbox
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (val) {
                    if (txId != null) {
                      _onSelectDetailRow(_currentCari.id, txId, val);
                    }
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFFD1D1D1), width: 1),
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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 44),
                // 1. Ürün Kodu
                if (_columnVisibility['dt_urun_kodu'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('accounts.statement.col.product_code_short'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 2. Ürün Adı
                if (_columnVisibility['dt_urun_adi'] == true) ...[
                  Expanded(
                    flex: 4,
                    child: Text(
                      tr('shipment.field.name'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 3. Tarih
                if (_columnVisibility['dt_tarih'] == true) ...[
                  Expanded(
                    flex: 3,
                    child: Text(
                      tr('common.date'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 4. Miktar
                if (_columnVisibility['dt_miktar'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('common.quantity'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                // 5. Birim
                if (_columnVisibility['dt_birim'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('common.unit'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 6. İskonto
                if (_columnVisibility['dt_iskonto'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('common.discount_percent_short'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 7. Ham Fiyat
                if (_columnVisibility['dt_ham_fiyat'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('common.raw_price_short'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 8. Açıklama
                if (_columnVisibility['dt_aciklama'] == true) ...[
                  Expanded(
                    flex: 3,
                    child: Text(
                      tr('common.description'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 9. Birim Fiyat
                if (_columnVisibility['dt_fiyat'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('shipment.field.price'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 10. KDV
                if (_columnVisibility['dt_kdv'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('tax.vat'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 11. ÖTV
                if (showOtvColumn && _columnVisibility['dt_otv'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('sale.grid.otv'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 12. ÖİV
                if (showOivColumn && _columnVisibility['dt_oiv'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('sale.grid.oiv'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 13. Tevkifat
                if (showTevkifatColumn &&
                    _columnVisibility['dt_tevkifat'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('sale.grid.tevkifat'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 14. Borç
                if (_columnVisibility['dt_borc'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('accounts.table.type_debit'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 15. Alacak
                if (_columnVisibility['dt_alacak'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('accounts.table.type_credit'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 16. Belge No
                if (_columnVisibility['dt_belge'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('purchase.complete.field.document'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 17. E-Belge No
                if (_columnVisibility['dt_e_belge'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('settings.general.option.documents.eDocument'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 18. İrsaliye No
                if (_columnVisibility['dt_irsaliye'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('purchase.complete.field.waybill_no'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 19. Fatura No
                if (_columnVisibility['dt_fatura'] == true) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      tr('purchase.complete.field.invoice_no'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // 20. Açıklama 2
                if (_columnVisibility['dt_aciklama2'] == true) ...[
                  Expanded(
                    flex: 3,
                    child: Text(
                      tr('common.description2'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Transaction Rows
          ...(() {
            final List<dynamic> details = [];
            final rawDetaylar = tx['hareket_detaylari'];

            if (rawDetaylar != null) {
              if (rawDetaylar is List) {
                for (var row in rawDetaylar) {
                  if (row == null) {
                    continue;
                  }
                  if (row is List) {
                    details.addAll(row);
                  } else if (row is Map) {
                    details.add(row);
                  } else if (row is String) {
                    try {
                      final decoded = jsonDecode(row);
                      if (decoded is List) {
                        details.addAll(decoded);
                      } else if (decoded is Map) {
                        details.add(decoded);
                      }
                    } catch (_) {}
                  }
                }
              }
            }

            // Geriye dönük uyum veya eksik detay durumunda main row'u kullan
            if (details.isEmpty) {
              details.add(tx);
            }

            // Ürün barkodları shipments.items içinde yoksa products tablosundan yükle
            final Set<String> barkodKods = {};
            for (final raw in details) {
              if (raw is! Map) {
                continue;
              }
              final String kod =
                  raw['urun_kodu']?.toString() ??
                  raw['urunKodu']?.toString() ??
                  raw['code']?.toString() ??
                  raw['productCode']?.toString() ??
                  raw['product_code']?.toString() ??
                  '';

              final trimmed = kod.trim();
              if (trimmed.isEmpty) {
                continue;
              }
              if (!_urunBarkodCache.containsKey(trimmed) &&
                  !_urunBarkodFetchInProgress.contains(trimmed)) {
                barkodKods.add(trimmed);
              }
            }
            if (barkodKods.isNotEmpty) {
              unawaited(_urunBarkodlariniYukle(barkodKods));
            }

            final double txTutarAbs = parseDouble(tx['tutar']).abs();
            double baseSum = 0.0;

            for (final raw in details) {
              if (raw is! Map) {
                continue;
              }
              final qty = parseDouble(raw['miktar'] ?? raw['quantity']);
              final unitPrice = parseDouble(
                raw['birim_fiyat'] ?? raw['price'] ?? raw['unitCost'],
              );
              final discountRate = parseDouble(
                raw['iskonto'] ?? raw['discount'] ?? raw['discountRate'],
              );
              final base = qty * unitPrice;
              final discounted = base * (1 - (discountRate / 100));
              if (discounted.isFinite && discounted > 0) {
                baseSum += discounted;
              }
            }

            final double inferredVatRatio = (txTutarAbs > 0 && baseSum > 0)
                ? (txTutarAbs / baseSum) - 1.0
                : 0.0;
            final double effectiveVatRatio =
                inferredVatRatio.isFinite && inferredVatRatio > 0
                ? inferredVatRatio
                : 0.0;

            return details.map((detail) {
              final dUrunKodu =
                  detail['urun_kodu']?.toString() ??
                  detail['urunKodu']?.toString() ??
                  detail['code']?.toString() ??
                  detail['productCode']?.toString() ??
                  detail['product_code']?.toString() ??
                  (detail == tx ? tx['urun_kodu']?.toString() ?? '' : '');
              final dBarkod =
                  detail['barkod']?.toString() ??
                  detail['barcode']?.toString() ??
                  detail['urun_barkod']?.toString() ??
                  detail['barkod_no']?.toString() ??
                  detail['barkodNo']?.toString() ??
                  detail['productBarcode']?.toString() ??
                  detail['product_barcode']?.toString() ??
                  (detail == tx ? tx['barkod']?.toString() ?? '' : '');
              final String dUrunKoduTrim = dUrunKodu.trim();
              final String resolvedBarkod = dBarkod.trim().isNotEmpty
                  ? dBarkod.trim()
                  : (dUrunKoduTrim.isNotEmpty
                        ? (_urunBarkodCache[dUrunKoduTrim] ?? '').trim()
                        : '');
              final dUrunAdi =
                  detail['urun_adi']?.toString() ??
                  detail['name']?.toString() ??
                  detail['ad']?.toString() ??
                  (detail == tx ? urunAdi : '');
              final dMiktar =
                  double.tryParse(
                    (detail['miktar'] ?? detail['quantity'] ?? '0').toString(),
                  ) ??
                  (detail == tx ? parseDouble(tx['miktar']) : 0.0);
              final dBirim =
                  detail['birim']?.toString() ??
                  detail['unit']?.toString() ??
                  (detail == tx ? tx['birim']?.toString() ?? '' : '');
              final dIskonto =
                  double.tryParse(
                    (detail['iskonto'] ??
                            detail['discount'] ??
                            detail['discountRate'] ??
                            '0')
                        .toString(),
                  ) ??
                  (detail == tx ? parseDouble(tx['iskonto']) : 0.0);
              final dHamFiyat =
                  double.tryParse(
                    (detail['ham_fiyat'] ??
                            detail['unitCost'] ??
                            detail['price'] ??
                            '0')
                        .toString(),
                  ) ??
                  (detail == tx ? parseDouble(tx['ham_fiyat']) : 0.0);
              final dBirimFiyat =
                  double.tryParse(
                    (detail['birim_fiyat'] ??
                            detail['price'] ??
                            detail['unitCost'] ??
                            '0')
                        .toString(),
                  ) ??
                  (detail == tx ? parseDouble(tx['birim_fiyat']) : 0.0);
              final dAciklama =
                  detail['aciklama']?.toString() ??
                  detail['description']?.toString() ??
                  (detail == tx ? tx['aciklama']?.toString() ?? '' : '');

              final bool isSummaryRow = detail == tx;

              final double dLineBase = dMiktar * dBirimFiyat;
              final double dDiscountRate = dIskonto;
              final double dLineBaseAfterDiscount =
                  dLineBase * (1 - (dDiscountRate / 100));

              final double vatRate = parseDouble(
                detail['vatRate'] ??
                    detail['kdvOrani'] ??
                    detail['kdv'] ??
                    detail['vat_rate'],
              );
              final double otvRate = parseDouble(
                detail['otvRate'] ?? detail['otv_rate'],
              );
              final double oivRate = parseDouble(
                detail['oivRate'] ?? detail['oiv_rate'],
              );
              final double tevkifatOrani = parseRatio(
                detail['kdvTevkifatOrani'] ??
                    detail['kdv_tevkifat_orani'] ??
                    detail['tevkifatOrani'] ??
                    detail['tevkifat'],
              );
              final double lineTotalFromDetail = parseDouble(
                detail['total'] ?? detail['lineTotal'] ?? detail['line_total'],
              );

              final bool hasExplicitTaxes =
                  vatRate > 0 ||
                  otvRate > 0 ||
                  oivRate > 0 ||
                  tevkifatOrani > 0;

              double kdvAmount = 0;
              double kdvRatePercent = 0;
              double otvAmount = 0;
              double otvRatePercent = 0;
              double oivAmount = 0;
              double oivRatePercent = 0;
              double tevkifatAmount = 0;
              double tevkifatPercent = 0;
              double displayTotal = 0;

              if (isSummaryRow) {
                // No item breakdown available; show transaction total only
                displayTotal = txTutarAbs;
              } else if (hasExplicitTaxes) {
                otvAmount = dLineBase * (otvRate / 100);
                oivAmount = dLineBase * (oivRate / 100);

                final subtotal = dLineBase + otvAmount + oivAmount;
                final discountAmount = subtotal * (dDiscountRate / 100);
                final vatBase = subtotal - discountAmount;

                kdvAmount = vatBase * (vatRate / 100);
                tevkifatAmount = kdvAmount * tevkifatOrani;
                displayTotal = vatBase + (kdvAmount - tevkifatAmount);

                kdvRatePercent = vatRate;
                otvRatePercent = otvRate;
                oivRatePercent = oivRate;
                tevkifatPercent = tevkifatOrani * 100;
              } else if (lineTotalFromDetail > 0 &&
                  dLineBaseAfterDiscount > 0) {
                displayTotal = lineTotalFromDetail;
                kdvAmount = (displayTotal - dLineBaseAfterDiscount).clamp(
                  0,
                  double.infinity,
                );
                kdvRatePercent = (kdvAmount / dLineBaseAfterDiscount) * 100.0;
              } else {
                // Legacy fallback: infer VAT from transaction total vs line bases
                final inferredVatAmount =
                    dLineBaseAfterDiscount *
                    (effectiveVatRatio.isFinite ? effectiveVatRatio : 0.0);
                kdvAmount = inferredVatAmount.clamp(0, double.infinity);
                kdvRatePercent = effectiveVatRatio * 100.0;
                displayTotal = dLineBaseAfterDiscount + kdvAmount;
              }

              // Prefer persisted total if present
              if (!isSummaryRow && lineTotalFromDetail > 0) {
                displayTotal = lineTotalFromDetail;
              }

              final double dBorcVal = isBorc ? displayTotal : 0.0;
              final double dAlacakVal = isBorc ? 0.0 : displayTotal;

              return GestureDetector(
                onTap: () {
                  if (txId != null) {
                    _onSelectDetailRow(_currentCari.id, txId, !isSelected);
                  }
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFC8E6C9)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade100,
                          width: 0.5,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: ExcludeFocus(
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (val) {
                                  if (txId != null) {
                                    _onSelectDetailRow(
                                      _currentCari.id,
                                      txId,
                                      val,
                                    );
                                  }
                                },
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
                        // 1. Ürün Kodu
                        if (_columnVisibility['dt_urun_kodu'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HighlightText(
                                  text: dUrunKoduTrim.isNotEmpty
                                      ? dUrunKoduTrim
                                      : '-',
                                  query: _searchQuery,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: dUrunKoduTrim.isNotEmpty
                                        ? Colors.black87
                                        : Colors.grey.shade400,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (resolvedBarkod.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  HighlightText(
                                    text: resolvedBarkod,
                                    query: _searchQuery,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.grey.shade600,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 2. Ürün Adı
                        if (_columnVisibility['dt_urun_adi'] == true) ...[
                          Expanded(
                            flex: 4,
                            child: HighlightText(
                              text: dUrunAdi.isNotEmpty ? dUrunAdi : '-',
                              query: _searchQuery,
                              style: TextStyle(
                                fontSize: 11,
                                color: dUrunAdi.isNotEmpty
                                    ? Colors.black87
                                    : Colors.grey.shade400,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 3. Tarih
                        if (_columnVisibility['dt_tarih'] == true) ...[
                          Expanded(
                            flex: 3,
                            child: HighlightText(
                              text: tarihStr,
                              query: _searchQuery,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 4. Miktar
                        if (_columnVisibility['dt_miktar'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: HighlightText(
                              text: dMiktar > 0
                                  ? FormatYardimcisi.sayiFormatla(
                                      dMiktar,
                                      binlik: _genelAyarlar.binlikAyiraci,
                                      ondalik: _genelAyarlar.ondalikAyiraci,
                                    )
                                  : '-',
                              query: _searchQuery,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                color: dMiktar > 0
                                    ? Colors.blue.shade800
                                    : Colors.grey.shade400,
                                fontWeight: dMiktar > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        // 5. Birim
                        if (_columnVisibility['dt_birim'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: HighlightText(
                              text: dBirim.isNotEmpty ? dBirim : '-',
                              query: _searchQuery,
                              style: TextStyle(
                                fontSize: 11,
                                color: dBirim.isNotEmpty
                                    ? Colors.black87
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 6. İskonto
                        if (_columnVisibility['dt_iskonto'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: HighlightText(
                              text: dIskonto > 0
                                  ? '%${dIskonto.toStringAsFixed(2)}'
                                  : '-',
                              query: _searchQuery,
                              style: TextStyle(
                                fontSize: 11,
                                color: dIskonto > 0
                                    ? Colors.orange.shade700
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 7. Ham Fiyat
                        if (_columnVisibility['dt_ham_fiyat'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: HighlightText(
                              text:
                                  '${FormatYardimcisi.sayiFormatlaOndalikli(dHamFiyat, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_currentCari.paraBirimi}',
                              query: _searchQuery,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                color: dHamFiyat > 0
                                    ? Colors.indigo.shade700
                                    : Colors.grey.shade400,
                                fontWeight: dHamFiyat > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 8. Açıklama
                        if (_columnVisibility['dt_aciklama'] == true) ...[
                          Expanded(
                            flex: 3,
                            child: HighlightText(
                              text: dAciklama.isNotEmpty ? dAciklama : '-',
                              query: _searchQuery,
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: 10,
                                color: dAciklama.isNotEmpty
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 9. Birim Fiyat
                        if (_columnVisibility['dt_fiyat'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: HighlightText(
                              text:
                                  '${FormatYardimcisi.sayiFormatlaOndalikli(dBirimFiyat, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_currentCari.paraBirimi}',
                              query: _searchQuery,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: dBirimFiyat > 0
                                    ? Colors.black87
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 10. KDV
                        if (_columnVisibility['dt_kdv'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: buildTaxCell(
                              amount: kdvAmount,
                              ratePercent: kdvRatePercent,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 11. ÖTV
                        if (showOtvColumn &&
                            _columnVisibility['dt_otv'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: buildTaxCell(
                              amount: otvAmount,
                              ratePercent: otvRatePercent,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 12. ÖİV
                        if (showOivColumn &&
                            _columnVisibility['dt_oiv'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: buildTaxCell(
                              amount: oivAmount,
                              ratePercent: oivRatePercent,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 13. Tevkifat
                        if (showTevkifatColumn &&
                            _columnVisibility['dt_tevkifat'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: buildTaxCell(
                              amount: tevkifatAmount,
                              ratePercent: tevkifatPercent,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 14. Borç
                        if (_columnVisibility['dt_borc'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: HighlightText(
                              text: dBorcVal > 0
                                  ? '${FormatYardimcisi.sayiFormatlaOndalikli(dBorcVal, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_currentCari.paraBirimi}'
                                  : '-',
                              query: _searchQuery,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: dBorcVal > 0
                                    ? Colors.red.shade700
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 15. Alacak
                        if (_columnVisibility['dt_alacak'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: HighlightText(
                              text: dAlacakVal > 0
                                  ? '${FormatYardimcisi.sayiFormatlaOndalikli(dAlacakVal, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${_currentCari.paraBirimi}'
                                  : '-',
                              query: _searchQuery,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: dAlacakVal > 0
                                    ? Colors.green.shade700
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 16. Belge No
                        if (_columnVisibility['dt_belge'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: HighlightText(
                              text: belge.isNotEmpty ? belge : '-',
                              query: _searchQuery,
                              style: TextStyle(
                                fontSize: 10,
                                color: belge.isNotEmpty
                                    ? Colors.black87
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 17. E-Belge No
                        if (_columnVisibility['dt_e_belge'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: HighlightText(
                              text: eBelge.isNotEmpty ? eBelge : '-',
                              query: _searchQuery,
                              style: TextStyle(
                                fontSize: 10,
                                color: eBelge.isNotEmpty
                                    ? Colors.black87
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 18. İrsaliye No
                        if (_columnVisibility['dt_irsaliye'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: HighlightText(
                              text: irsaliyeNo.isNotEmpty ? irsaliyeNo : '-',
                              query: _searchQuery,
                              style: TextStyle(
                                fontSize: 10,
                                color: irsaliyeNo.isNotEmpty
                                    ? Colors.black87
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 19. Fatura No
                        if (_columnVisibility['dt_fatura'] == true) ...[
                          Expanded(
                            flex: 2,
                            child: HighlightText(
                              text: faturaNo.isNotEmpty ? faturaNo : '-',
                              query: _searchQuery,
                              style: TextStyle(
                                fontSize: 10,
                                color: faturaNo.isNotEmpty
                                    ? Colors.black87
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 20. Açıklama 2
                        if (_columnVisibility['dt_aciklama2'] == true) ...[
                          Expanded(
                            flex: 3,
                            child: HighlightText(
                              text: aciklama2.isNotEmpty ? aciklama2 : '-',
                              query: _searchQuery,
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: 10,
                                color: aciklama2.isNotEmpty
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList();
          })(),
        ],
      ),
    );
  }

  /// Sütun sayısına göre dinamik font boyutu hesaplar
  double _getResponsiveFontSize(int columnCount) {
    // Az sütun = büyük font, çok sütun = küçük font
    if (columnCount <= 10) {
      return 12.0;
    }
    if (columnCount <= 15) {
      return 11.0;
    }
    if (columnCount <= 20) {
      return 10.0;
    }
    if (columnCount <= 25) {
      return 9.0;
    }
    return 8.0;
  }

  /// Sütun sayısına göre dinamik padding hesaplar
  EdgeInsets _getResponsivePadding(int columnCount) {
    if (columnCount <= 10) {
      return const EdgeInsets.symmetric(horizontal: 8, vertical: 10);
    }
    if (columnCount <= 15) {
      return const EdgeInsets.symmetric(horizontal: 6, vertical: 8);
    }
    if (columnCount <= 20) {
      return const EdgeInsets.symmetric(horizontal: 4, vertical: 6);
    }
    return const EdgeInsets.symmetric(horizontal: 3, vertical: 5);
  }

  /// GenisletilebilirTablo iÃ§in dinamik sÃ¼tunlarÄ± oluÅŸturur (OTOMATÄ°K GENÄ°ÅLÄ°K)
  // ignore: unused_element
  List<GenisletilebilirTabloKolon> _buildEkstreTableColumns(
    int type,
    double availableWidth,
  ) {
    final columnDefs = _getEkstreColumns(type);
    final columnCount = columnDefs.length;

    // Dinamik genişlik: Toplam genişliği sütun sayısına böl
    // Minimum genişlik kontrolü ile
    final baseWidth = (availableWidth - 50) / columnCount; // 50px margin
    final minWidth = columnCount <= 15
        ? 60.0
        : (columnCount <= 20 ? 50.0 : 45.0);
    final calculatedWidth = baseWidth.clamp(minWidth, 150.0);

    return columnDefs.map((col) {
      // Sayısal sütunlar biraz daha geniş olabilir
      final isNumeric = (col['isNumeric'] as bool?) ?? false;
      final width = isNumeric ? calculatedWidth * 1.1 : calculatedWidth;

      return GenisletilebilirTabloKolon(
        label: col['label'] as String,
        width: width,
        alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
        allowSorting: true,
      );
    }).toList();
  }

  /// Ekstre tablosu için satır oluşturur (OTOMATİK RESPONSIVE)
  // ignore: unused_element
  Widget _buildEkstreTableRow(
    Map<String, dynamic> tx,
    int index,
    int ekstreType,
    double availableWidth,
  ) {
    final columnDefs = _getEkstreColumns(ekstreType);
    final columnCount = columnDefs.length;
    final isEven = index % 2 == 0;

    // Dinamik değerler
    final fontSize = _getResponsiveFontSize(columnCount);
    final padding = _getResponsivePadding(columnCount);

    // Dinamik genişlik hesapla
    final baseWidth = (availableWidth - 50) / columnCount;
    final minWidth = columnCount <= 15
        ? 60.0
        : (columnCount <= 20 ? 50.0 : 45.0);
    final calculatedWidth = baseWidth.clamp(minWidth, 150.0);

    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFFAFAFA),
      ),
      child: Row(
        children: columnDefs.map((col) {
          final key = col['key'] as String;
          final isNumeric = (col['isNumeric'] as bool?) ?? false;
          final isAmount = (col['isAmount'] as bool?) ?? false;
          final width = isNumeric ? calculatedWidth * 1.1 : calculatedWidth;

          String value = _getTransactionValue(tx, key);

          // Tutar formatlaması
          if (isAmount && value.isNotEmpty) {
            final numValue = double.tryParse(value) ?? 0.0;
            value = FormatYardimcisi.sayiFormatlaOndalikli(
              numValue,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
              decimalDigits: _genelAyarlar.fiyatOndalik,
            );
          }

          return Container(
            width: width,
            padding: padding,
            child: Text(
              value,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isNumeric ? FontWeight.w600 : FontWeight.w400,
                color: _getValueColor(key, tx),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: isNumeric ? TextAlign.right : TextAlign.left,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Ekstre Tab Bar - 4 farklı ekstre tipi arasında seçim yapmak için
  // ignore: unused_element
  Widget _buildEkstreTabBar() {
    return Row(
      children: [
        // Ekstre Tab Seçici
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEkstreTab(1, 'E1'),
              const SizedBox(width: 2),
              _buildEkstreTab(2, 'E2'),
              const SizedBox(width: 2),
              _buildEkstreTab(3, 'E3'),
              const SizedBox(width: 2),
              _buildEkstreTab(4, 'E4'),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Detayları Açık Tut Butonu
        Tooltip(
          message: tr('warehouses.keep_details_open'),
          child: InkWell(
            onTap: _toggleKeepDetailsOpen,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: _keepDetailsOpen
                    ? const Color(0xFF2C3E50).withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(6),
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
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEkstreTab(int type, String label) {
    final isSelected = _selectedEkstreType == type;
    return Tooltip(
      message: '${tr('accounts.statement')} $type',
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedEkstreType = type;
          });
        },
        borderRadius: BorderRadius.circular(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2C3E50) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2C3E50).withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  /// Ekstre DataTable - Seçilen ekstre tipine göre sütunları döndürür
  // ignore: unused_element
  Widget _buildEkstreDataTable() {
    final columns = _getEkstreColumns(_selectedEkstreType);

    // Toplam tablo genişliğini hesapla
    final totalWidth = columns.fold<double>(
      0.0,
      (sum, col) => sum + (col['width'] as double),
    );

    // Örnek transaction verileri (gerçek veriler veritabanından gelecek)
    // Åimdilik boÅŸ bir tablo gÃ¶steriyoruz
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // DataTable Body (Header dahil, içeride)
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: CariHesaplarVeritabaniServisi().cariIslemleriniGetir(
                _currentCari.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      '${tr('common.error')}: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final transactions = snapshot.data ?? [];

                if (transactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('common.no_data'),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('accounts.card.transactions.empty_subtitle'),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Scrollbar ile yatay kaydırma
                return Scrollbar(
                  controller: _ekstreHorizontalScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _ekstreHorizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: totalWidth + 16, // +16 for padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // DataTable Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: columns.map((col) {
                                return Container(
                                  width: col['width'] as double,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    col['label'] as String,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF475569),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          // DataTable Body (İşlemler listesi)
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: transactions.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final tx = entry.value;
                                  final isEven = index % 2 == 0;

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isEven
                                          ? Colors.white
                                          : const Color(0xFFFAFAFA),
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: _buildEkstreRow(tx, columns),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Ekstre satırı oluşturur
  Widget _buildEkstreRow(
    Map<String, dynamic> tx,
    List<Map<String, dynamic>> columns,
  ) {
    return InkWell(
      onTap: () {
        // Satır seçim işlemi
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: columns.map((col) {
            final key = col['key'] as String;
            final width = col['width'] as double;
            final isNumeric = (col['isNumeric'] as bool?) ?? false;
            final isAmount = (col['isAmount'] as bool?) ?? false;

            String value = _getTransactionValue(tx, key);

            // Tutar formatlaması
            if (isAmount && value.isNotEmpty) {
              final numValue = double.tryParse(value) ?? 0.0;
              value = FormatYardimcisi.sayiFormatlaOndalikli(
                numValue,
                binlik: _genelAyarlar.binlikAyiraci,
                ondalik: _genelAyarlar.ondalikAyiraci,
                decimalDigits: _genelAyarlar.fiyatOndalik,
              );
            }

            return Container(
              width: width,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isNumeric ? FontWeight.w600 : FontWeight.w400,
                  color: _getValueColor(key, tx),
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: isNumeric ? TextAlign.right : TextAlign.left,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Transaction'dan belirli bir değeri alır
  String _getTransactionValue(Map<String, dynamic> tx, String key) {
    switch (key) {
      case 'islem':
        return tx['islem_turu']?.toString() ?? '';
      case 'tarih':
        final rawDate = tx['tarih'] ?? tx['created_at'];
        if (rawDate != null) {
          try {
            DateTime? dt;
            if (rawDate is DateTime) {
              dt = rawDate;
            } else {
              dt = DateTime.tryParse(rawDate.toString());
            }
            if (dt != null) {
              return DateFormat('dd.MM.yyyy').format(dt);
            }
          } catch (_) {}
          return rawDate.toString();
        }
        return '';
      case 'tutar':
        final double t = double.tryParse(tx['tutar']?.toString() ?? '') ?? 0.0;
        return FormatYardimcisi.sayiFormatlaOndalikli(
          t,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.fiyatOndalik,
        );
      case 'bakiye_borc':
        // [2025 SYNC] DB kolonu yerine bellekte hesaplanan ve güncel modelle senkronize 'running_balance' kullan
        final rb = tx['running_balance'];
        if (rb != null && rb is double && rb > 0) {
          return FormatYardimcisi.sayiFormatlaOndalikli(
            rb,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: _genelAyarlar.fiyatOndalik,
          );
        }
        return '';
      case 'bakiye_alacak':
        // [2025 SYNC] Alacak bakiye (negatif bakiye) gösterimi
        final rb = tx['running_balance'];
        if (rb != null && rb is double && rb < 0) {
          return FormatYardimcisi.sayiFormatlaOndalikli(
            rb.abs(),
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: _genelAyarlar.fiyatOndalik,
          );
        }
        return '';
      case 'borc':
        final yon = tx['yon']?.toString() ?? '';
        if (yon.toLowerCase().contains('borç')) {
          final double t =
              double.tryParse(tx['tutar']?.toString() ?? '') ?? 0.0;
          return FormatYardimcisi.sayiFormatlaOndalikli(
            t,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: _genelAyarlar.fiyatOndalik,
          );
        }
        return '';
      case 'alacak':
        final yon = tx['yon']?.toString() ?? '';
        if (yon.toLowerCase().contains('alacak')) {
          final double t =
              double.tryParse(tx['tutar']?.toString() ?? '') ?? 0.0;
          return FormatYardimcisi.sayiFormatlaOndalikli(
            t,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: _genelAyarlar.fiyatOndalik,
          );
        }
        return '';
      case 'kur':
        final double k = double.tryParse(tx['kur']?.toString() ?? '') ?? 1.0;
        return FormatYardimcisi.sayiFormatlaOndalikli(
          k,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: 2,
        );
      case 'ilgili_hesap':
        final String? iRef = tx['integration_ref']?.toString().toLowerCase();
        final bool isCheckNote =
            iRef != null &&
            (iRef.contains('cek') ||
                iRef.contains('cheque') ||
                iRef.contains('note') ||
                iRef.contains('senet'));

        if (isCheckNote) {
          final String qAdi = tx['kaynak_adi']?.toString() ?? '';
          final String qKodu = tx['kaynak_kodu']?.toString() ?? '';
          final String label = (iRef.contains('note') || iRef.contains('senet'))
              ? 'Senet'
              : 'Çek';

          // [2026 FIX] Öncelik: kaynak_adi (alt sorgudan gelen çek no)
          // kaynak_adi temizse (not: bazen banka adı gelebilir ama alt sorgu başarılıysa çek no gelir)
          if (qAdi.isNotEmpty &&
              !qAdi.contains('\n') &&
              !qAdi.contains(' - ')) {
            return '$label $qAdi';
          }
          // İkinci öncelik: kaynak_kodu (ciro işleminde buraya çek no yazılır)
          if (qKodu.isNotEmpty && !qKodu.startsWith('#')) {
            return '$label $qKodu';
          }
          return '$label ${qAdi.isNotEmpty ? qAdi : qKodu}';
        }
        return tx['kaynak_adi']?.toString() ??
            tx['source_name']?.toString() ??
            '';
      case 'belge':
        return tx['belge_no']?.toString() ?? '';
      case 'e_belge':
        return tx['e_belge_no']?.toString() ?? '';
      case 'irsaliye_no':
        return tx['irsaliye_no']?.toString() ?? '';
      case 'fatura_no':
        return tx['fatura_no']?.toString() ?? '';
      case 'aciklama':
        return tx['aciklama']?.toString() ?? '';
      case 'aciklama2':
        return tx['aciklama2']?.toString() ?? '';
      case 'vade_tarihi':
        final vade = tx['vade_tarihi'];
        if (vade != null) {
          try {
            DateTime? dt;
            if (vade is DateTime) {
              dt = vade;
            } else {
              dt = DateTime.tryParse(vade.toString());
            }
            if (dt != null) {
              return DateFormat('dd.MM.yyyy').format(dt);
            }
          } catch (_) {}
          return vade.toString();
        }
        return '';
      case 'kullanici':
        return tx['kullanici']?.toString() ??
            tx['user_name']?.toString() ??
            'Sistem';
      case 'urun_kodu':
        return tx['urun_kodu']?.toString() ?? '';
      case 'urun_adi':
        return tx['urun_adi']?.toString() ?? '';
      case 'miktar':
        return tx['miktar']?.toString() ?? '';
      case 'birim':
        return tx['birim']?.toString() ?? '';
      case 'iskonto':
        final isk = tx['iskonto']?.toString() ?? '';
        return isk.isNotEmpty ? '%$isk' : '';
      case 'ham_fiyat':
        return tx['ham_fiyat']?.toString() ?? '';
      case 'birim_fiyat':
        return tx['birim_fiyat']?.toString() ?? '';
      default:
        return '';
    }
  }

  /// Değer için renk belirler
  Color _getValueColor(String key, Map<String, dynamic> tx) {
    switch (key) {
      case 'tutar':
      case 'bakiye_borc':
      case 'borc':
        final yon = tx['yon']?.toString() ?? '';
        if (yon.toLowerCase().contains('borç') ||
            key == 'bakiye_borc' ||
            key == 'borc') {
          return Colors.red.shade700;
        }
        return Colors.green.shade700;
      case 'bakiye_alacak':
      case 'alacak':
        return Colors.green.shade700;
      case 'borc_alacak':
        final yon = tx['yon']?.toString() ?? '';
        if (yon.toLowerCase().contains('borç')) {
          return Colors.red.shade700;
        }
        return Colors.green.shade700;
      default:
        return const Color(0xFF334155);
    }
  }

  /// Seçilen ekstre tipine göre sütunları döndürür (başlık genişliğine göre ayarlanmış)
  List<Map<String, dynamic>> _getEkstreColumns(int type) {
    // Başlık metninin genişliğini hesapla: (karakterSayısı * 8) + 24 (padding)
    // Font 12px bold için karakter genişliği yaklaşık 8px
    double calculateWidth(String label, {double minWidth = 50.0}) {
      final calculated = (label.length * 8.0) + 24.0;
      return calculated > minWidth ? calculated : minWidth;
    }

    final labelIslem = tr('products.transaction.type');
    final labelTarih = tr('common.date');
    final labelTutar = tr('common.amount');
    final labelBakiyeBorcShort = tr('accounts.balance.debit_short');
    final labelBakiyeAlacakShort = tr('accounts.balance.credit_short');
    final labelKur = tr('common.rate');
    final labelIlgiliH = tr('accounts.statement.col.related_account_short');
    final labelBelge = tr('accounts.statement.col.document');
    final labelEBelge = tr('accounts.statement.col.e_document_short');
    final labelIrsNo = tr('accounts.statement.col.waybill_no_short');
    final labelFtrNo = tr('accounts.statement.col.invoice_no_short');
    final labelAciklama = tr('common.description');
    final labelAciklama2Short = tr(
      'accounts.statement.col.description2_short1',
    );
    final labelVade = tr('accounts.statement.col.due');
    final labelKullanici = tr('common.user');
    final labelBorcAlacak = tr('accounts.statement.col.debit_credit_short');

    final labelUrunKodShort = tr('accounts.statement.col.product_code_short');
    final labelUrunAdi = tr('products.table.name');
    final labelMiktarShortDot = tr('accounts.statement.col.quantity_short1');
    final labelMiktarShort = tr('accounts.statement.col.quantity_short2');
    final labelBirimShort = tr('accounts.statement.col.unit_short');
    final labelIskontoShort = tr('accounts.statement.col.discount_short');
    final labelHamFiyatShort = tr('accounts.statement.col.raw_price_short1');
    final labelHamShort = tr('accounts.statement.col.raw_price_short2');
    final labelAciklamaShortDot = tr(
      'accounts.statement.col.description_short1',
    );
    final labelAciklamaShort = tr('accounts.statement.col.description_short2');
    final labelBirimFiyatShortDot = tr(
      'accounts.statement.col.unit_price_short1',
    );
    final labelBirimFiyatShort = tr('accounts.statement.col.unit_price_short2');
    final labelBakiyeAlacakShortAlt = tr('accounts.balance.credit_short_alt');
    final labelIlgiliHAlt = tr(
      'accounts.statement.col.related_account_short_alt',
    );
    final labelIlgiliHAlt2 = tr(
      'accounts.statement.col.related_account_short_alt2',
    );
    final labelBelgeShort = tr('accounts.statement.col.document_short');
    final labelEBelgeShortAlt = tr(
      'accounts.statement.col.e_document_short_alt',
    );
    final labelIrsShort = tr('accounts.statement.col.waybill_short');
    final labelFtrShort = tr('accounts.statement.col.invoice_short');
    final labelAciklama2ShortAlt = tr(
      'accounts.statement.col.description2_short2',
    );
    final labelAciklama2ShortAlt2 = tr(
      'accounts.statement.col.description2_short3',
    );
    final labelKullaniciShortDot = tr('accounts.statement.col.user_short1');
    final labelKullaniciShort = tr('accounts.statement.col.user_short2');
    final labelBakiyeBorcShortMin = tr('accounts.balance.debit_short_min');
    final labelBakiyeAlacakShortMin = tr('accounts.balance.credit_short_min');
    final labelAlacakShort = tr('accounts.statement.col.credit_short');

    switch (type) {
      case 1:
        // Ekstre 1: 15 sütun
        return [
          {
            'key': 'islem',
            'label': labelIslem,
            'width': calculateWidth(labelIslem),
          },
          {
            'key': 'tarih',
            'label': labelTarih,
            'width': calculateWidth(labelTarih),
          },
          {
            'key': 'tutar',
            'label': labelTutar,
            'width': calculateWidth(labelTutar, minWidth: 80.0),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'bakiye_borc',
            'label': labelBakiyeBorcShort,
            'width': calculateWidth(labelBakiyeBorcShort, minWidth: 80.0),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'bakiye_alacak',
            'label': labelBakiyeAlacakShort,
            'width': calculateWidth(labelBakiyeAlacakShort, minWidth: 80.0),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'kur',
            'label': labelKur,
            'width': calculateWidth(labelKur),
            'isNumeric': true,
          },
          {
            'key': 'ilgili_hesap',
            'label': labelIlgiliH,
            'width': calculateWidth(labelIlgiliH),
          },
          {
            'key': 'belge',
            'label': labelBelge,
            'width': calculateWidth(labelBelge),
          },
          {
            'key': 'e_belge',
            'label': labelEBelge,
            'width': calculateWidth(labelEBelge),
          },
          {
            'key': 'irsaliye_no',
            'label': labelIrsNo,
            'width': calculateWidth(labelIrsNo),
          },
          {
            'key': 'fatura_no',
            'label': labelFtrNo,
            'width': calculateWidth(labelFtrNo),
          },
          {
            'key': 'aciklama',
            'label': labelAciklama,
            'width': calculateWidth(labelAciklama, minWidth: 100.0),
          },
          {
            'key': 'aciklama2',
            'label': labelAciklama2Short,
            'width': calculateWidth(labelAciklama2Short),
          },
          {
            'key': 'vade_tarihi',
            'label': labelVade,
            'width': calculateWidth(labelVade),
          },
          {
            'key': 'kullanici',
            'label': labelKullanici,
            'width': calculateWidth(labelKullanici),
          },
        ];
      case 2:
        // Ekstre 2: 15 sütun
        return [
          {
            'key': 'islem',
            'label': labelIslem,
            'width': calculateWidth(labelIslem),
          },
          {
            'key': 'tarih',
            'label': labelTarih,
            'width': calculateWidth(labelTarih),
          },
          {
            'key': 'borc_alacak',
            'label': labelBorcAlacak,
            'width': calculateWidth(labelBorcAlacak, minWidth: 70.0),
            'isNumeric': true,
          },
          {
            'key': 'bakiye_borc',
            'label': labelBakiyeBorcShort,
            'width': calculateWidth(labelBakiyeBorcShort, minWidth: 80.0),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'bakiye_alacak',
            'label': labelBakiyeAlacakShort,
            'width': calculateWidth(labelBakiyeAlacakShort, minWidth: 80.0),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'kur',
            'label': labelKur,
            'width': calculateWidth(labelKur),
            'isNumeric': true,
          },
          {
            'key': 'ilgili_hesap',
            'label': labelIlgiliH,
            'width': calculateWidth(labelIlgiliH),
          },
          {
            'key': 'belge',
            'label': labelBelge,
            'width': calculateWidth(labelBelge),
          },
          {
            'key': 'e_belge',
            'label': labelEBelge,
            'width': calculateWidth(labelEBelge),
          },
          {
            'key': 'irsaliye_no',
            'label': labelIrsNo,
            'width': calculateWidth(labelIrsNo),
          },
          {
            'key': 'fatura_no',
            'label': labelFtrNo,
            'width': calculateWidth(labelFtrNo),
          },
          {
            'key': 'aciklama',
            'label': labelAciklama,
            'width': calculateWidth(labelAciklama, minWidth: 100.0),
          },
          {
            'key': 'aciklama2',
            'label': labelAciklama2Short,
            'width': calculateWidth(labelAciklama2Short),
          },
          {
            'key': 'vade_tarihi',
            'label': labelVade,
            'width': calculateWidth(labelVade),
          },
          {
            'key': 'kullanici',
            'label': labelKullanici,
            'width': calculateWidth(labelKullanici),
          },
        ];
      case 3:
        // Ekstre 3: 22 sütun
        return [
          {
            'key': 'islem',
            'label': labelIslem,
            'width': calculateWidth(labelIslem),
          },
          {
            'key': 'tarih',
            'label': labelTarih,
            'width': calculateWidth(labelTarih),
          },
          {
            'key': 'urun_kodu',
            'label': labelUrunKodShort,
            'width': calculateWidth(labelUrunKodShort),
          },
          {
            'key': 'urun_adi',
            'label': labelUrunAdi,
            'width': calculateWidth(labelUrunAdi, minWidth: 80.0),
          },
          {
            'key': 'miktar',
            'label': labelMiktarShortDot,
            'width': calculateWidth(labelMiktarShortDot),
            'isNumeric': true,
          },
          {
            'key': 'birim',
            'label': labelBirimShort,
            'width': calculateWidth(labelBirimShort),
          },
          {
            'key': 'iskonto',
            'label': labelIskontoShort,
            'width': calculateWidth(labelIskontoShort),
            'isNumeric': true,
          },
          {
            'key': 'ham_fiyat',
            'label': labelHamFiyatShort,
            'width': calculateWidth(labelHamFiyatShort, minWidth: 70.0),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'aciklama',
            'label': labelAciklamaShortDot,
            'width': calculateWidth(labelAciklamaShortDot),
          },
          {
            'key': 'birim_fiyat',
            'label': labelBirimFiyatShortDot,
            'width': calculateWidth(labelBirimFiyatShortDot, minWidth: 70.0),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'tutar',
            'label': labelTutar,
            'width': calculateWidth(labelTutar, minWidth: 70.0),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'bakiye_borc',
            'label': labelBakiyeBorcShort,
            'width': calculateWidth(labelBakiyeBorcShort, minWidth: 70.0),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'bakiye_alacak',
            'label': labelBakiyeAlacakShortAlt,
            'width': calculateWidth(labelBakiyeAlacakShortAlt, minWidth: 70.0),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'kur',
            'label': labelKur,
            'width': calculateWidth(labelKur),
            'isNumeric': true,
          },
          {
            'key': 'ilgili_hesap',
            'label': labelIlgiliHAlt,
            'width': calculateWidth(labelIlgiliHAlt),
          },
          {
            'key': 'belge',
            'label': labelBelgeShort,
            'width': calculateWidth(labelBelgeShort),
          },
          {
            'key': 'e_belge',
            'label': labelEBelgeShortAlt,
            'width': calculateWidth(labelEBelgeShortAlt),
          },
          {
            'key': 'irsaliye_no',
            'label': labelIrsShort,
            'width': calculateWidth(labelIrsShort),
          },
          {
            'key': 'fatura_no',
            'label': labelFtrShort,
            'width': calculateWidth(labelFtrShort),
          },
          {
            'key': 'aciklama2',
            'label': labelAciklama2ShortAlt,
            'width': calculateWidth(labelAciklama2ShortAlt),
          },
          {
            'key': 'vade_tarihi',
            'label': labelVade,
            'width': calculateWidth(labelVade),
          },
          {
            'key': 'kullanici',
            'label': labelKullaniciShortDot,
            'width': calculateWidth(labelKullaniciShortDot),
          },
        ];
      case 4:
        // Ekstre 4: 24 sütun
        return [
          {
            'key': 'islem',
            'label': labelIslem,
            'width': calculateWidth(labelIslem),
          },
          {
            'key': 'tarih',
            'label': labelTarih,
            'width': calculateWidth(labelTarih),
          },
          {
            'key': 'urun_kodu',
            'label': labelUrunKodShort,
            'width': calculateWidth(labelUrunKodShort),
          },
          {
            'key': 'urun_adi',
            'label': tr('common.product'),
            'width': calculateWidth(tr('common.product'), minWidth: 70.0),
          },
          {
            'key': 'miktar',
            'label': labelMiktarShort,
            'width': calculateWidth(labelMiktarShort),
            'isNumeric': true,
          },
          {
            'key': 'birim',
            'label': labelBirimShort,
            'width': calculateWidth(labelBirimShort),
          },
          {
            'key': 'iskonto',
            'label': labelIskontoShort,
            'width': calculateWidth(labelIskontoShort),
            'isNumeric': true,
          },
          {
            'key': 'ham_fiyat',
            'label': labelHamShort,
            'width': calculateWidth(labelHamShort, minWidth: 60.0),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'aciklama',
            'label': labelAciklamaShort,
            'width': calculateWidth(labelAciklamaShort),
          },
          {
            'key': 'birim_fiyat',
            'label': labelBirimFiyatShort,
            'width': calculateWidth(labelBirimFiyatShort, minWidth: 60.0),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'borc',
            'label': tr('accounts.table.type_debit'),
            'width': calculateWidth(
              tr('accounts.table.type_debit'),
              minWidth: 70.0,
            ),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'alacak',
            'label': labelAlacakShort,
            'width': calculateWidth(labelAlacakShort, minWidth: 70.0),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'bakiye_borc',
            'label': labelBakiyeBorcShortMin,
            'width': calculateWidth(labelBakiyeBorcShortMin, minWidth: 60.0),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'bakiye_alacak',
            'label': labelBakiyeAlacakShortMin,
            'width': calculateWidth(labelBakiyeAlacakShortMin, minWidth: 60.0),
            'isNumeric': true,
            'isAmount': true,
          },
          {
            'key': 'kur',
            'label': labelKur,
            'width': calculateWidth(labelKur),
            'isNumeric': true,
          },
          {
            'key': 'ilgili_hesap',
            'label': labelIlgiliHAlt2,
            'width': calculateWidth(labelIlgiliHAlt2),
          },
          {
            'key': 'belge',
            'label': labelBelgeShort,
            'width': calculateWidth(labelBelgeShort),
          },
          {
            'key': 'e_belge',
            'label': labelEBelgeShortAlt,
            'width': calculateWidth(labelEBelgeShortAlt),
          },
          {
            'key': 'irsaliye_no',
            'label': labelIrsShort,
            'width': calculateWidth(labelIrsShort),
          },
          {
            'key': 'fatura_no',
            'label': labelFtrShort,
            'width': calculateWidth(labelFtrShort),
          },
          {
            'key': 'aciklama2',
            'label': labelAciklama2ShortAlt2,
            'width': calculateWidth(labelAciklama2ShortAlt2),
          },
          {
            'key': 'vade_tarihi',
            'label': labelVade,
            'width': calculateWidth(labelVade),
          },
          {
            'key': 'kullanici',
            'label': labelKullaniciShort,
            'width': calculateWidth(labelKullaniciShort),
          },
        ];
      default:
        return [];
    }
  }

  // ignore: unused_element
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
          _buildCell(
            width: 200,
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
          _buildCell(
            width: colTypeWidth,
            child: Text(
              IslemCeviriYardimcisi.cevir(cari.hesapTuru),
              style: TextStyle(fontSize: 14, color: textColor),
            ),
          ),
          _buildCell(
            width: colDebtWidth,
            alignment: Alignment.centerRight,
            child: Text(
              '${FormatYardimcisi.sayiFormatlaOndalikli(cari.bakiyeBorc, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${cari.paraBirimi}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
          ),
          _buildCell(
            width: colCreditWidth,
            alignment: Alignment.centerRight,
            child: Text(
              '${FormatYardimcisi.sayiFormatlaOndalikli(cari.bakiyeAlacak, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${cari.paraBirimi}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
          ),
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
                      cari.aktifMi ? tr('common.active') : tr('common.passive'),
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
          _buildCell(width: colActionsWidth, child: _buildPopupMenu(cari)),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDetailView(CariHesapModel cari) {
    // 1. Görsel Hazırlığı
    // 1. Görsel Hazırlığı
    Widget buildMainImage() {
      ImageProvider? img;
      if (cari.resimler.isNotEmpty) {
        // [2026 FIX] Use cached image
        img = _getCachedMemoryImage(cari.resimler.first);
      }

      return Container(
        width: 60, // KÜÇÜLTÜLDÜ
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC), // Daha açık bir arka plan
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          image: img != null
              ? DecorationImage(
                  image: img,
                  fit: BoxFit.contain, // RESİMLERİN TAMAMI GÖRÜNSÜN
                )
              : null,
        ),
        child: img == null
            ? Center(
                child: Text(
                  cari.adi.isNotEmpty ? cari.adi[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 24, // Font küçüldü
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              )
            : null,
      );
    }

    Widget buildThumbnails() {
      if (cari.resimler.length <= 1) return const SizedBox.shrink();
      return SizedBox(
        height: 32, // Küçüldü
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemCount: cari.resimler.length > 5 ? 5 : cari.resimler.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (ctx, idx) {
            if (idx == 0) return const SizedBox.shrink();

            final thumbImg = _getCachedMemoryImage(cari.resimler[idx]);

            if (thumbImg == null) return const SizedBox.shrink();

            return Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                image: DecorationImage(
                  image: thumbImg,
                  fit: BoxFit.contain, // THUMBNAIL'LER DE KESİLMESİN
                ),
              ),
            );
          },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========================================
          // ÖZELLİKLER KARTI (ÜRÜNLER SAYFASI GİBİ)
          // ========================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER ROW: Resim + Cari Bilgileri + Bakiye
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resim
                    buildMainImage(),
                    const SizedBox(width: 14),
                    // Cari Bilgileri
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [buildThumbnails()],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tr('accounts.detail.properties'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cari.adi,
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
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Bakiye Tablosu
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
                          // Borç Row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr('accounts.table.balance_debit'),
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
                                    cari.bakiyeBorc,
                                    binlik: _genelAyarlar.binlikAyiraci,
                                    ondalik: _genelAyarlar.ondalikAyiraci,
                                    decimalDigits: _genelAyarlar.fiyatOndalik,
                                  ),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFC62828),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  cari.paraBirimi,
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
                          // Alacak Row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr('accounts.table.balance_credit'),
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
                                    cari.bakiyeAlacak,
                                    binlik: _genelAyarlar.binlikAyiraci,
                                    ondalik: _genelAyarlar.ondalikAyiraci,
                                    decimalDigits: _genelAyarlar.fiyatOndalik,
                                  ),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  cari.paraBirimi,
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
                          // Fark Row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${tr('common.difference')} (${(cari.bakiyeAlacak - cari.bakiyeBorc) >= 0 ? tr('accounts.table.type_credit') : tr('accounts.table.type_debit')})',
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
                                    (cari.bakiyeAlacak - cari.bakiyeBorc).abs(),
                                    binlik: _genelAyarlar.binlikAyiraci,
                                    ondalik: _genelAyarlar.ondalikAyiraci,
                                    decimalDigits: _genelAyarlar.fiyatOndalik,
                                  ),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const SizedBox(width: 30),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ÖZELLİKLER DETAYLARI - WRAP İÇİNDE
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _buildDetailItem(
                      tr('accounts.table.phone1'),
                      cari.telefon1,
                    ),
                    _buildDetailItem(
                      tr('accounts.table.phone2'),
                      cari.telefon2,
                    ),
                    _buildDetailItem(tr('accounts.table.email'), cari.eposta),
                    _buildDetailItem(
                      tr('accounts.table.website'),
                      cari.webAdresi,
                    ),
                    _buildDetailItem(
                      tr('accounts.table.tax_office'),
                      '${cari.vDairesi} / ${cari.vNumarasi}',
                    ),
                    _buildDetailItem(
                      tr('accounts.table.risk_limit'),
                      '${FormatYardimcisi.sayiFormatlaOndalikli(cari.riskLimiti)} ₺',
                    ),
                    _buildDetailItem(
                      tr('accounts.table.invoice_title'),
                      cari.fatUnvani,
                    ),
                    _buildDetailItem(
                      tr('accounts.table.invoice_address'),
                      '${cari.fatAdresi} ${cari.fatIlce}/${cari.fatSehir}'
                          .trim(),
                    ),
                    if (cari.bilgi1.isNotEmpty)
                      _buildDetailItem(tr('accounts.table.info1'), cari.bilgi1),
                    if (cari.bilgi2.isNotEmpty)
                      _buildDetailItem(tr('accounts.table.info2'), cari.bilgi2),
                    if (cari.bilgi3.isNotEmpty)
                      _buildDetailItem(tr('accounts.table.info3'), cari.bilgi3),
                    // Note: The original note section was a separate column.
                    // If it needs to be part of the Wrap, it would be a custom _buildDetailItem.
                    // For now, it's removed as per the provided replacement structure.
                    // The shipment addresses were also a separate column.
                    // If they need to be part of the Wrap, they would also be custom _buildDetailItems.
                    // For now, they are removed as per the provided replacement structure.
                  ],
                ),
              ],
            ),
          ),
          // ========================================
          // SON HAREKETLER - KARTIN DIŞINDA!
          // (ÜRÜNLER SAYFASI İLE BİREBİR AYNI YAPI)
          // ========================================
          const SizedBox(height: 24),
          _buildTransactionsSection(cari),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    if (value is String && value.isEmpty) return const SizedBox.shrink();

    // If widget (e.g. special widgets), render as is
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
        () => CariHesaplarVeritabaniServisi().cariIslemleriniGetir(cari.id),
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
                    Expanded(
                      flex: 2,
                      child: _buildDetailHeader(
                        tr('cashregisters.detail.transaction'), // İşlem
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildDetailHeader(
                        tr('cashregisters.detail.date'), // Tarih
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _buildDetailHeader(
                        tr('cashregisters.detail.party'), // İlgili Hesap
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildDetailHeader(
                        tr('common.amount'), // Tutar
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _buildDetailHeader(
                        tr('cashregisters.detail.description'), // Açıklama
                      ),
                    ),
                    const SizedBox(width: 12),
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

                  // Map raw internal types to user-friendly labels for display
                  if (islemTuru == 'Girdi' || islemTuru == 'Tahsilat') {
                    islemTuru = 'Para Alındı';
                  } else if (islemTuru == 'Çıktı' || islemTuru == 'Ödeme') {
                    islemTuru = 'Para Verildi';
                  }

                  final String yon = tx['yon']?.toString() ?? '';
                  final sourceId = tx['source_id'] as int?;
                  final aciklama = tx['aciklama']?.toString() ?? '';

                  final String? iRef = tx['integration_ref']?.toString();
                  final String lowRef = iRef?.toLowerCase() ?? '';
                  final bool isSale = lowRef.startsWith('sale-');
                  final bool isPurchase = lowRef.startsWith('purchase-');
                  final bool isCheckNote =
                      lowRef.contains('cheque') ||
                      lowRef.contains('cek') ||
                      lowRef.contains('note') ||
                      lowRef.contains('senet') ||
                      lowRef.contains('promissory') ||
                      rawIslemTuru.contains('Çek') ||
                      rawIslemTuru.contains('Senet');

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

                  // Label Mapping (Girdi/Çıktı to Para Alındı/Verildi)
                  if (islemTuru == 'Girdi' || islemTuru == 'Tahsilat') {
                    islemTuru = 'Para Alındı';
                  } else if (islemTuru == 'Çıktı' || islemTuru == 'Ödeme') {
                    islemTuru = 'Para Verildi';
                  }

                  // Tarih formatlaması - date + created_at'den saat
                  String tarihStr = '';
                  final rawTarih = tx['tarih'];
                  final createdAt = tx['created_at'];

                  if (rawTarih != null) {
                    DateTime? dt;
                    if (rawTarih is DateTime) {
                      dt = rawTarih;
                    } else if (rawTarih is String) {
                      dt = DateTime.tryParse(rawTarih);
                    }

                    if (dt != null) {
                      // [2025 FIX] Eğer saat 00:00 ise ve created_at varsa, saati created_at'den al
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
                  } else if (createdAt != null) {
                    try {
                      DateTime? cdt;
                      if (createdAt is DateTime) {
                        cdt = createdAt;
                      } else {
                        cdt = DateTime.tryParse(createdAt.toString());
                      }
                      if (cdt != null) {
                        tarihStr = DateFormat('dd.MM.yyyy HH:mm').format(cdt);
                      }
                    } catch (_) {
                      tarihStr = createdAt.toString();
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

                  // [2026 FIX] For check/note, ensure we use the actual number if available
                  if (isCheckNote) {
                    // Title for check/note should be the account holder (Style consistency)
                    locationName = cari.adi;

                    final String dbKaynakAdi =
                        tx['kaynak_adi']?.toString() ?? '';
                    if (dbKaynakAdi.isNotEmpty &&
                        !dbKaynakAdi.contains('\n') &&
                        !dbKaynakAdi.contains(' - ')) {
                      // SQL subquery returned the actual number
                      locationCode = dbKaynakAdi;
                    } else if (dbKaynakAdi.contains('\n')) {
                      // Extraction fallback
                      final parts = dbKaynakAdi.split('\n');
                      if (parts.length > 1) {
                        String potentialNo = parts[1].trim();
                        locationCode = potentialNo
                            .replaceAll('Çek ', '')
                            .replaceAll('Senet ', '')
                            .trim();
                      }
                    }
                  }

                  // Source ID varsa ve kod hala boşsa, ID'yi kod olarak kullan
                  if (locationCode.isEmpty &&
                      sourceId != null &&
                      sourceId > 0) {
                    locationCode = '#$sourceId';
                  }

                  final focusScope = TableDetailFocusScope.of(context);
                  final isFocused = focusScope?.focusedDetailIndex == index;

                  String displayName = islemTuru;
                  if (isSale) {
                    displayName = 'Satış Yapıldı';
                  } else if (isPurchase) {
                    displayName = 'Alış Yapıldı';
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
                          (islemTuru == 'Tahsilat' ||
                              islemTuru == 'Girdi' ||
                              islemTuru == 'Para Alındı')
                          ? 'Para Alındı'
                          : (islemTuru == 'Ödeme' ||
                                islemTuru == 'Çıktı' ||
                                islemTuru == 'Para Verildi')
                          ? 'Para Verildi'
                          : islemTuru;
                    }
                  }

                  // Clear description for check/note transactions if automated
                  String displayDescription = aciklama;
                  if (isCheckNote) {
                    final lowDesc = aciklama.toLowerCase();
                    if (lowDesc.contains('tahsilat') ||
                        lowDesc.contains('ödeme') ||
                        lowDesc.contains('no:')) {
                      displayDescription = '';
                    }
                  }

                  // Rozet metnini temizle (locationType)
                  String displayLocationType = islemTuru;
                  if (isSale) {
                    displayLocationType = 'Satış Yapıldı';
                  } else if (isPurchase) {
                    displayLocationType = 'Alış Yapıldı';
                  } else if (isCheckNote) {
                    if (lowRef.contains('cheque') || lowRef.contains('cek-')) {
                      displayLocationType = 'Çek';
                    } else if (lowRef.contains('note') ||
                        lowRef.contains('senet-')) {
                      displayLocationType = 'Senet';
                    }
                  } else if (rawIslemTuru.contains('Çek') ||
                      rawIslemTuru.contains('Senet')) {
                    displayLocationType = rawIslemTuru;
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
                        amount: tx['tutar'] is num
                            ? (tx['tutar'] as num).toDouble()
                            : 0.0,
                        currency: cari.paraBirimi,
                        locationType: displayLocationType,
                        integrationRef: iRef,
                        locationName: locationName,
                        locationCode: locationCode,
                        description: displayDescription,
                        user: (createdBy ?? '').isEmpty ? 'Sistem' : createdBy!,
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
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: IslemTuruRenkleri.arkaplanRengiGetir(
                              name,
                              isIncoming,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            isIncoming
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: IslemTuruRenkleri.ikonRengiGetir(
                              name,
                              isIncoming,
                            ),
                            size: 14,
                          ),
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: IslemCeviriYardimcisi.cevir(name),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: IslemTuruRenkleri.metinRengiGetir(
                                      name,
                                      isIncoming,
                                    ),
                                  ),
                                ),
                                if (_getSourceSuffix(
                                  locationType,
                                  integrationRef,
                                  locationName,
                                ).isNotEmpty)
                                  TextSpan(
                                    text:
                                        ' ${IslemCeviriYardimcisi.parantezliKaynakKisaltma(_getSourceSuffix(locationType, integrationRef, locationName))}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  const SizedBox(width: 12),
                  // RELATED ACCOUNT (İlgili Hesap - Unified Column)
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (locationName.isNotEmpty)
                          HighlightText(
                            text: locationName,
                            query: _searchQuery,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        if (locationType.isNotEmpty || locationCode.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                if (locationType.isNotEmpty)
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
                                      text: locationType,
                                      query: _searchQuery,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                if (locationType.isNotEmpty &&
                                    locationCode.isNotEmpty)
                                  const SizedBox(width: 6),
                                if (locationCode.isNotEmpty)
                                  HighlightText(
                                    text: locationCode,
                                    query: _searchQuery,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                              ],
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
              ),
            ),
          ),
        );
      },
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
        locationType.contains('Dekont');

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
    if (integrationRef != null ||
        locationType.contains('Çek') ||
        locationType.contains('Senet')) {
      final String lowRef = integrationRef?.toLowerCase() ?? '';
      if (lowRef.startsWith('cheque') ||
          lowRef.startsWith('cek-') ||
          lowRef.startsWith('note') ||
          lowRef.startsWith('senet-') ||
          locationType.contains('Çek') ||
          locationType.contains('Senet')) {
        return '';
      }
    }

    return '';
  }

  void _onSelectAllDetails(int cariId, bool? value) {
    setState(() {
      _isSelectAllActive = value == true;
      if (value == true) {
        // Görünür işlemlerin hepsini seç
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

  void _onSelectAllInstallments(int cariId, bool? value) {
    setState(() {
      if (value == true) {
        final ids = _cachedInstallments
            .map(
              (e) => e['id'] is int
                  ? e['id'] as int
                  : int.tryParse(e['id']?.toString() ?? ''),
            )
            .whereType<int>()
            .toSet();
        _selectedInstallmentIds[cariId] = ids;
      } else {
        _selectedInstallmentIds[cariId]?.clear();
      }
    });
  }

  void _onSelectInstallmentRow(int cariId, int installmentId, bool? value) {
    setState(() {
      _selectedInstallmentIds.putIfAbsent(cariId, () => {});
      if (value == true) {
        _selectedInstallmentIds[cariId]!.add(installmentId);
      } else {
        _selectedInstallmentIds[cariId]!.remove(installmentId);
      }
    });
  }

  // ignore: unused_element
  Future<void> _addDemoAccount() async {
    final demoCari = CariHesapModel(
      // ID'yi int convert problemi olmasın diye timestamp'in 32bit kısmı olarak alalım veya backend auto-increment ise 0 verelim.
      // Mevcut model `final int id` istiyor.
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      kodNo: 'D-2024-${DateTime.now().millisecond}',
      adi: 'Patisyo Teknoloji A.Ş.',
      hesapTuru: 'Alıcı',
      aktifMi: true,
      bakiyeBorc: 15450.75,
      bakiyeAlacak: 0,
      bakiyeDurumu: 'Borç',
      paraBirimi: 'TL',
      riskLimiti: 50000,
      sfGrubu: 'Bayi A',
      sIskonto: 10,
      vadeGun: 45,
      telefon1: '0212 555 10 20',
      telefon2: '0532 555 30 40',
      eposta: 'muhasebe@patisyo.com',
      webAdresi: 'www.patisyo.com',
      fatUnvani: 'Patisyo Teknoloji ve Yazılım Hizmetleri A.Ş.',
      fatAdresi: 'Teknopark İstanbul, Sanayi Mah. Teknoloji Bulvarı No:1/1A',
      fatIlce: 'Pendik',
      fatSehir: 'İstanbul',
      postaKodu: '34906',
      vDairesi: 'Pendik V.D.',
      vNumarasi: '1234567890',
      // 'ozelKod1' ve 'ozelKod2' modelde yoktu, kaldırıldı.
      // Eksik olan bilgileri bilgi alanlarına ekleyelim.
      bilgi1: 'Demo hesabı - Detaylı test verisi. Özel Kod1: BY-IST',
      bilgi2: 'Haftalık sevkiyat günü Çarşamba. Özel Kod2: KURUMSAL',
      bilgi3: 'Ödeme vadesi fatura tarihinden itibaren 45 gündür.',
      bilgi4: 'Satınalma sorumlusu: Ahmet Bey',
      bilgi5: 'Depo giriş saati 09:00 - 17:00',
      resimler: [], // Kullanıcı ekleyecek
    );

    try {
      await CariHesaplarVeritabaniServisi().cariHesapEkle(demoCari);
      if (mounted) {
        MesajYardimcisi.basariGoster(
          context,
          tr('accounts.card.demo_account_added'),
        );
        _fetchCariHesaplar();
      }
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    }
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
          } else if (value == 'mark') {
            _showColorPickerDialog(cari);
          } else if (value == 'toggle_status') {
            await _cariDurumDegistir(cari, !cari.aktifMi);
            _refreshCariDetails();
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
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
}
