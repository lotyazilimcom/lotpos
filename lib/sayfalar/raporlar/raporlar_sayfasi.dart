import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../bilesenler/genisletilebilir_tablo.dart';
import '../../bilesenler/highlight_text.dart';
import '../../bilesenler/tab_acici_scope.dart';
import '../../bilesenler/tarih_araligi_secici_dialog.dart';
import '../../sayfalar/ortak/genisletilebilir_print_preview_screen.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../temalar/app_theme.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../../yardimcilar/islem_turu_renkleri.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../yardimcilar/yazdirma/yazdirma_erisim_kontrolu.dart';
import '../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../alimsatimislemleri/satis_sonrasi_yazdir_sayfasi.dart';
import '../carihesaplar/modeller/cari_hesap_model.dart';
import '../urunler_ve_depolar/urunler/modeller/urun_model.dart';
import 'modeller/rapor_modelleri.dart';
import '../../servisler/raporlar_servisi.dart';

class RaporlarSayfasi extends StatefulWidget {
  const RaporlarSayfasi({super.key});

  @override
  State<RaporlarSayfasi> createState() => _RaporlarSayfasiState();
}

class _RaporlarSayfasiState extends State<RaporlarSayfasi> {
  static const String _prefsColumnVisibilityPrefix =
      'reports_column_visibility_';
  static const String _prefsHideEmptyColumnsPrefix =
      'reports_hide_empty_columns_';
  static const bool _defaultHideEmptyColumns = true;

  static const Set<String> _amountKeys = <String>{
    'tutar',
    'ara_toplam',
    'kdv',
    'genel_toplam',
    'bakiye_borc',
    'bakiye_alacak',
    'son_islem_tutar',
    // KDV Hesabı
    'birim_fiyati',
    'matrah',
    'otv_tutari',
    'oiv_tutari',
    'borc',
    'alacak',
    'net_bakiye',
    'stok_degeri',
    'maliyet',
    'alis',
    'satis1',
    'satis2',
    'satis3',
    'ciro',
    'gider',
    'brut_kar',
    'net_kar',
    'tutar_etkisi',
    'vergi',
    'fark',
    // Kar/Zarar (Ürün bazlı)
    'dev_ekl_stok_degeri',
    'sat_mal_top_alis_degeri',
    'toplam_satis_degeri',
    'kalan_stok_degeri',
    // BA-BS
    'alis_fatura_matrah',
    'satis_fatura_matrah',
  };

  static const Set<String> _quantityKeys = <String>{
    'giris',
    'cikis',
    'miktar',
    'stok',
    'mevcut_stok',
    'kritik_stok',
    'kalem_sayisi',
    'toplam_miktar',
    'kayit_sayisi',
    // Kar/Zarar (Ürün bazlı)
    'devreden',
    'eklenen',
    'devreden_eklenen',
    'satilan',
    'kalan',
    // BA-BS
    'alis_fatura_adet',
    'satis_fatura_adet',
  };

  static const Set<String> _badgeKeys = <String>{
    'durum',
    'tur',
    'odeme_turu',
    'odeme_tipi',
    'modul',
    'belge',
    'portfoy',
  };

  static const Set<String> _entityKeys = <String>{
    'cari',
    'hesap',
    'ilgili_hesap',
    'urun',
    'urun_adi',
    'kalem',
    'yer_adi',
    'depo',
    'kaynak',
    'hedef',
    'kategori',
    'grup',
    'ad',
  };

  static const Set<String> _secondaryTextKeys = <String>{
    'kod',
    'urun_kodu',
    'yer_kodu',
    'belge_no',
    'belge_ref',
    'fatura_no',
    'irsaliye_no',
    'ref',
    'no',
    'kur',
    'kullanici',
    'son_islem',
    'son_hareket',
    'son_islem_turu',
    'son_islem_tarihi',
    'termin',
    'donusum',
  };

  static const Set<String> _dateKeys = <String>{
    'tarih',
    'vade',
    'vade_tarihi',
    'donem',
  };

  static const Set<String> _descriptionKeys = <String>{
    'aciklama',
    'aciklama_2',
  };

  final RaporlarServisi _raporlarServisi = RaporlarServisi();

  final TextEditingController _belgeNoController = TextEditingController();
  final TextEditingController _referansNoController = TextEditingController();
  final TextEditingController _minTutarController = TextEditingController();
  final TextEditingController _maxTutarController = TextEditingController();
  final TextEditingController _minMiktarController = TextEditingController();
  final TextEditingController _maxMiktarController = TextEditingController();
  final FocusNode _tableSearchFocusNode = FocusNode();

  RaporFiltreKaynaklari _filtreKaynaklari = const RaporFiltreKaynaklari();
  RaporFiltreleri _filtreler = RaporFiltreleri.empty;
  RaporFiltreleri _aktifFiltreler = RaporFiltreleri.empty;

  late final List<RaporSecenegi> _tumRaporlar;
  late RaporKategori _seciliKategori;
  RaporSecenegi? _seciliRapor;
  RaporSonucu? _sonuc;

  bool _filtreKaynaklariYukleniyor = true;
  bool _raporYukleniyor = true;
  bool _mobilFiltrelerAcik = false;

  String? _seciliCariLabel;
  String? _seciliUrunLabel;
  bool _cariLabelResolving = false;
  bool _urunLabelResolving = false;

  String _arama = '';
  int _mevcutSayfa = 1;
  int _satirSayisi = 25;
  int _paginationRevision = 0;
  final Map<int, String?> _sayfaCursorlari = <int, String?>{1: null};
  bool _sortAscending = false;
  String? _sortKey;
  String _hizliTarihSecimi = 'this_month';
  Timer? _metinFiltreDebounce;
  int _aktifSorguNo = 0;

  final Map<String, Map<String, bool>> _kolonGorunurluklari =
      <String, Map<String, bool>>{};
  final Map<String, bool> _bosSutunlariGizleByReport = <String, bool>{};

  OverlayEntry? _filterDropdownOverlayEntry;
  String? _filterDropdownExpandedKey;
  final Map<String, LayerLink> _filterDropdownLayerLinks =
      <String, LayerLink>{};

  bool _keepDetailsOpen = false;
  final Set<String> _expandedRowIds = <String>{};
  final Set<String> _autoExpandedRowIds = <String>{};
  final Map<String, Future<DetailTable?>> _integrationDetailFutures =
      <String, Future<DetailTable?>>{};
  String? _selectedRowId;

  @override
  void initState() {
    super.initState();
    _tumRaporlar = _raporlarServisi.raporlar;
    _seciliKategori = RaporKategori.genel;
    _seciliRapor = _tumRaporlar.firstWhere(
      (rapor) => rapor.id == 'all_movements',
      orElse: () => _tumRaporlar.first,
    );
    _hizliTarihSeciminiUygula(_hizliTarihSecimi, yukle: false);
    _kolonDurumunuHazirla();
    _verileriHazirla();
  }

  @override
  void dispose() {
    _closeFilterDropdownOverlay(rebuild: false);
    _metinFiltreDebounce?.cancel();
    _belgeNoController.dispose();
    _referansNoController.dispose();
    _minTutarController.dispose();
    _maxTutarController.dispose();
    _minMiktarController.dispose();
    _maxMiktarController.dispose();
    _tableSearchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _verileriHazirla() async {
    await _filtreKaynaklariniYukle();
    await _raporuYukle();
  }

  Future<void> _filtreKaynaklariniYukle() async {
    setState(() => _filtreKaynaklariYukleniyor = true);
    try {
      final kaynaklar = await _raporlarServisi.filtreKaynaklariniGetir();
      if (!mounted) return;
      setState(() {
        _filtreKaynaklari = kaynaklar;
        _filtreKaynaklariYukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _filtreKaynaklariYukleniyor = false);
      MesajYardimcisi.hataGoster(
        context,
        tr(
          'reports.messages.filter_sources_failed',
        ).replaceAll('{error}', e.toString()),
      );
    }
  }

  Future<void> _raporuYukle({bool showLoading = true}) async {
    final rapor = _seciliRapor;
    if (rapor == null) return;
    final String aramaTerimi = _arama;

    final int sorguNo = ++_aktifSorguNo;
    final bool shouldShowLoading = showLoading || _sonuc == null;
    setState(() {
      _raporYukleniyor = shouldShowLoading;
      _aktifFiltreler = _aktifFiltreleriOlustur();
    });

    final String? cursor = _mevcutSayfa <= 1
        ? null
        : _sayfaCursorlari[_mevcutSayfa];
    try {
      final sonuc = await _raporlarServisi.raporuGetir(
        rapor: rapor,
        filtreler: _aktifFiltreler,
        page: _mevcutSayfa,
        pageSize: _satirSayisi,
        arama: aramaTerimi,
        cursor: cursor,
        sortKey: _sortKey,
        sortAscending: _sortAscending,
      );

      if (!mounted || sorguNo != _aktifSorguNo) return;

      final columnSettings = await _loadColumnSettingsFromPrefs(
        reportId: rapor.id,
        columns: sonuc.columns,
      );

      final Set<String> autoExpandedRowIds = <String>{};
      if ((rapor.id == 'all_movements' ||
              rapor.id == 'vat_accounting' ||
              rapor.id == 'warehouse_shipment_list') &&
          aramaTerimi.trim().isNotEmpty) {
        for (final row in sonuc.rows) {
          if (!row.expandable) continue;
          if (row.extra['matchedInHidden'] == true) {
            autoExpandedRowIds.add(row.id);
          }
        }
      }

      if (!mounted || sorguNo != _aktifSorguNo) return;
      setState(() {
        _kolonGorunurluklari[rapor.id] = columnSettings.visibility;
        _bosSutunlariGizleByReport[rapor.id] = columnSettings.hideEmptyColumns;
        _sonuc = sonuc;
        _raporYukleniyor = false;
        _mevcutSayfa = sonuc.page;
        _satirSayisi = sonuc.pageSize;
        _autoExpandedRowIds
          ..clear()
          ..addAll(autoExpandedRowIds);
        final selectedId = _selectedRowId;
        if (selectedId != null &&
            !sonuc.rows.any((row) => row.id == selectedId)) {
          _selectedRowId = null;
        }
        if (!_keepDetailsOpen &&
            _expandedRowIds.isNotEmpty &&
            !sonuc.rows.any((row) => _expandedRowIds.contains(row.id))) {
          _expandedRowIds.clear();
        }
        if (sonuc.cursorPagination) {
          _sayfaCursorlari[1] = null;
          if (sonuc.hasNextPage && sonuc.nextCursor != null) {
            _sayfaCursorlari[sonuc.page + 1] = sonuc.nextCursor;
          }
        }
      });
    } catch (e) {
      if (mounted && sorguNo == _aktifSorguNo) {
        setState(() => _raporYukleniyor = false);
        MesajYardimcisi.hataGoster(
          context,
          tr(
            'reports.messages.load_failed',
          ).replaceAll('{error}', e.toString()),
        );
      }
    }
  }

  RaporFiltreleri _aktifFiltreleriOlustur() {
    final rapor = _seciliRapor;
    if (rapor == null) return RaporFiltreleri.empty;

    bool destekler(RaporFiltreTuru tur) => rapor.supportedFilters.contains(tur);
    final bool isTumHareketler =
        rapor.id == 'all_movements' ||
        rapor.id == 'vat_accounting' ||
        rapor.id == 'purchase_sales_movements';

    return RaporFiltreleri(
      baslangicTarihi: destekler(RaporFiltreTuru.tarihAraligi)
          ? _filtreler.baslangicTarihi
          : null,
      bitisTarihi: destekler(RaporFiltreTuru.tarihAraligi)
          ? _filtreler.bitisTarihi
          : null,
      cariId: destekler(RaporFiltreTuru.cari) ? _filtreler.cariId : null,
      urunKodu: destekler(RaporFiltreTuru.urun) ? _filtreler.urunKodu : null,
      urunGrubu: destekler(RaporFiltreTuru.urunGrubu)
          ? _filtreler.urunGrubu
          : null,
      kdvOrani: destekler(RaporFiltreTuru.kdvOrani)
          ? _filtreler.kdvOrani
          : null,
      depoId: destekler(RaporFiltreTuru.depo) ? _filtreler.depoId : null,
      cikisDepoId: destekler(RaporFiltreTuru.cikisDepo)
          ? _filtreler.cikisDepoId
          : null,
      girisDepoId: destekler(RaporFiltreTuru.girisDepo)
          ? _filtreler.girisDepoId
          : null,
      hesapTuru: destekler(RaporFiltreTuru.hesapTuru)
          ? _sanitizeHesapTuru(_filtreler.hesapTuru)
          : null,
      bakiyeDurumu: destekler(RaporFiltreTuru.bakiyeDurumu)
          ? _filtreler.bakiyeDurumu
          : null,
      islemTuru: destekler(RaporFiltreTuru.islemTuru)
          ? _filtreler.islemTuru
          : null,
      durum: destekler(RaporFiltreTuru.durum) ? _filtreler.durum : null,
      odemeYontemi: destekler(RaporFiltreTuru.odemeYontemi)
          ? _filtreler.odemeYontemi
          : null,
      kasaId: destekler(RaporFiltreTuru.kasa) ? _filtreler.kasaId : null,
      bankaId: destekler(RaporFiltreTuru.banka) ? _filtreler.bankaId : null,
      krediKartiId: destekler(RaporFiltreTuru.krediKarti)
          ? _filtreler.krediKartiId
          : null,
      kullaniciId: destekler(RaporFiltreTuru.kullanici)
          ? _filtreler.kullaniciId
          : null,
      belgeNo: destekler(RaporFiltreTuru.belgeNo)
          ? (isTumHareketler
                ? _bosIseNull(_filtreler.belgeNo)
                : _bosIseNull(_belgeNoController.text))
          : null,
      referansNo: destekler(RaporFiltreTuru.referansNo)
          ? (isTumHareketler
                ? _bosIseNull(_filtreler.referansNo)
                : _bosIseNull(_referansNoController.text))
          : null,
      minTutar: destekler(RaporFiltreTuru.minTutar)
          ? _parseDouble(_minTutarController.text)
          : null,
      maxTutar: destekler(RaporFiltreTuru.maxTutar)
          ? _parseDouble(_maxTutarController.text)
          : null,
      minMiktar: destekler(RaporFiltreTuru.minMiktar)
          ? _parseDouble(_minMiktarController.text)
          : null,
      maxMiktar: destekler(RaporFiltreTuru.maxMiktar)
          ? _parseDouble(_maxMiktarController.text)
          : null,
    );
  }

  void _kolonDurumunuHazirla() {
    final rapor = _seciliRapor;
    if (rapor == null) return;
    final mevcutSonuc = _sonuc;
    final kaynakKolonlar = mevcutSonuc?.report.id == rapor.id
        ? mevcutSonuc!.columns
        : const <RaporKolonTanimi>[];

    if (kaynakKolonlar.isNotEmpty &&
        !_kolonGorunurluklari.containsKey(rapor.id)) {
      final Map<String, bool> visibility = <String, bool>{};
      for (final kolon in kaynakKolonlar) {
        visibility[kolon.key] = kolon.visibleByDefault;
      }
      _kolonGorunurluklari[rapor.id] = visibility;
    }

    _bosSutunlariGizleByReport.putIfAbsent(
      rapor.id,
      () => _defaultHideEmptyColumns,
    );
  }

  List<RaporSecenegi> get _kategoriRaporlari =>
      _tumRaporlar.where((rapor) => rapor.category == _seciliKategori).toList();

  Future<({Map<String, bool> visibility, bool hideEmptyColumns})>
  _loadColumnSettingsFromPrefs({
    required String reportId,
    required List<RaporKolonTanimi> columns,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final Map<String, bool> defaults = <String, bool>{
      for (final column in columns) column.key: column.visibleByDefault,
    };

    final Map<String, bool> visibility = Map<String, bool>.from(defaults);
    final rawVisibility = prefs.getString(
      '$_prefsColumnVisibilityPrefix$reportId',
    );
    if (rawVisibility != null && rawVisibility.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawVisibility);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final key = entry.key?.toString();
            if (key == null || !visibility.containsKey(key)) continue;
            final value = entry.value;
            if (value is bool) {
              visibility[key] = value;
            } else if (value is num) {
              visibility[key] = value != 0;
            }
          }
        }
      } catch (_) {}
    }

    final bool hideEmptyColumns =
        prefs.getBool('$_prefsHideEmptyColumnsPrefix$reportId') ??
        _defaultHideEmptyColumns;

    return (visibility: visibility, hideEmptyColumns: hideEmptyColumns);
  }

  Future<void> _saveColumnSettingsToPrefs({
    required String reportId,
    required Map<String, bool> visibility,
    required bool hideEmptyColumns,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefsColumnVisibilityPrefix$reportId',
      jsonEncode(visibility),
    );
    await prefs.setBool(
      '$_prefsHideEmptyColumnsPrefix$reportId',
      hideEmptyColumns,
    );
  }

  String _toTurkishLower(String text) {
    return text
        .replaceAll('I', 'ı')
        .replaceAll('İ', 'i')
        .toLowerCase()
        .replaceAll('i̇', 'i');
  }

  String _toTurkishUpper(String text) {
    return text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  }

  String _toTitleCaseTr(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return text;
    return normalized
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          final lower = _toTurkishLower(word);
          final match = RegExp(r'[a-zA-ZçğıöşüÇĞİIÖŞÜ]').firstMatch(lower);
          if (match == null) return lower;
          final index = match.start;
          return lower.substring(0, index) +
              _toTurkishUpper(lower.substring(index, index + 1)) +
              lower.substring(index + 1);
        })
        .join(' ');
  }

  void _sayfalamayiSifirla() {
    _mevcutSayfa = 1;
    _paginationRevision++;
    _sayfaCursorlari
      ..clear()
      ..[1] = null;
    _expandedRowIds.clear();
    _autoExpandedRowIds.clear();
    _selectedRowId = null;
  }

  List<RaporKolonTanimi> get _gorunurKolonlar {
    final sonuc = _sonuc;
    if (sonuc == null) return const <RaporKolonTanimi>[];
    final raporId = sonuc.report.id;
    final visibility = _kolonGorunurluklari[raporId];
    final columns = sonuc.columns.where((kolon) {
      return (visibility?[kolon.key]) ?? kolon.visibleByDefault;
    }).toList();

    final bool hideEmptyColumns =
        _bosSutunlariGizleByReport[raporId] ?? _defaultHideEmptyColumns;

    if (!hideEmptyColumns || sonuc.rows.isEmpty) {
      return columns;
    }

    bool isEmptyCellValue(String? raw) {
      final value = (raw ?? '').trim();
      return value.isEmpty || value == '-' || value.toLowerCase() == 'null';
    }

    bool columnHasAnyValue(String key) {
      for (final row in sonuc.rows) {
        if (!isEmptyCellValue(row.cells[key])) return true;
      }
      return false;
    }

    return columns.where((kolon) {
      if (kolon.key.startsWith('_')) return true;
      return columnHasAnyValue(kolon.key);
    }).toList();
  }

  List<RaporSatiri> get _sayfaSatirlari {
    return _sonuc?.rows ?? const <RaporSatiri>[];
  }

  List<RaporSatiri> get _aktarimSatirlari {
    return _sonuc?.rows ?? const <RaporSatiri>[];
  }

  void _kategoriSec(RaporKategori kategori) {
    if (_seciliKategori == kategori) return;
    final yeniRaporlar = _tumRaporlar
        .where((rapor) => rapor.category == kategori)
        .toList();
    final yeniRapor = yeniRaporlar.firstWhere(
      (rapor) => rapor.supported,
      orElse: () => yeniRaporlar.first,
    );
    setState(() {
      _seciliKategori = kategori;
      _seciliRapor = yeniRapor;
      _sortKey = null;
      _sortAscending = false;
      _arama = '';
      _sayfalamayiSifirla();
      _kolonDurumunuHazirla();
    });
    _raporuYukle();
  }

  void _raporSec(RaporSecenegi rapor) {
    if (_seciliRapor?.id == rapor.id) return;
    setState(() {
      _seciliKategori = rapor.category;
      _seciliRapor = rapor;
      _sortKey = null;
      _sortAscending = false;
      _arama = '';
      _sayfalamayiSifirla();
      _kolonDurumunuHazirla();
    });
    _raporuYukle();
  }

  void _hizliTarihSeciminiUygula(String secim, {required bool yukle}) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    switch (secim) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'this_week':
        final int diff = now.weekday - DateTime.monday;
        start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: diff));
        end = start.add(
          const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        );
        break;
      case 'this_month':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'custom':
        start = _filtreler.baslangicTarihi;
        end = _filtreler.bitisTarihi;
        break;
      default:
        break;
    }

    setState(() {
      _hizliTarihSecimi = secim;
      _filtreler = _filtreler.copyWith(
        baslangicTarihi: start,
        bitisTarihi: end,
        clearDates: start == null && end == null,
      );
      _sayfalamayiSifirla();
    });

    if (yukle) {
      _raporuYukle();
    }
  }

  Future<void> _ozelTarihAraligiSec() async {
    final result = await showDialog<List<DateTime?>>(
      context: context,
      builder: (context) => TarihAraligiSeciciDialog(
        initialStartDate: _filtreler.baslangicTarihi,
        initialEndDate: _filtreler.bitisTarihi,
      ),
    );

    if (result == null || result.length < 2) return;

    setState(() {
      _hizliTarihSecimi = 'custom';
      _filtreler = _filtreler.copyWith(
        baslangicTarihi: result[0],
        bitisTarihi: result[1],
      );
      _sayfalamayiSifirla();
    });
    _raporuYukle();
  }

  void _secimGuncelle({
    int? cariId,
    String? urunKodu,
    String? urunGrubu,
    double? kdvOrani,
    int? depoId,
    int? cikisDepoId,
    int? girisDepoId,
    String? hesapTuru,
    String? bakiyeDurumu,
    String? islemTuru,
    String? durum,
    String? odemeYontemi,
    int? kasaId,
    int? bankaId,
    int? krediKartiId,
    String? kullaniciId,
    String? belgeNo,
    String? referansNo,
    bool clearCari = false,
    bool clearUrun = false,
    bool clearUrunGrubu = false,
    bool clearKdvOrani = false,
    bool clearDepo = false,
    bool clearCikisDepo = false,
    bool clearGirisDepo = false,
    bool clearHesapTuru = false,
    bool clearBakiyeDurumu = false,
    bool clearIslemTuru = false,
    bool clearDurum = false,
    bool clearOdemeYontemi = false,
    bool clearKasa = false,
    bool clearBanka = false,
    bool clearKrediKarti = false,
    bool clearKullanici = false,
    bool clearBelgeNo = false,
    bool clearReferansNo = false,
  }) {
    setState(() {
      _filtreler = _filtreler.copyWith(
        cariId: cariId,
        urunKodu: urunKodu,
        urunGrubu: urunGrubu,
        kdvOrani: kdvOrani,
        depoId: depoId,
        cikisDepoId: cikisDepoId,
        girisDepoId: girisDepoId,
        hesapTuru: hesapTuru,
        bakiyeDurumu: bakiyeDurumu,
        islemTuru: islemTuru,
        durum: durum,
        odemeYontemi: odemeYontemi,
        kasaId: kasaId,
        bankaId: bankaId,
        krediKartiId: krediKartiId,
        kullaniciId: kullaniciId,
        belgeNo: belgeNo,
        referansNo: referansNo,
        clearCari: clearCari,
        clearUrun: clearUrun,
        clearUrunGrubu: clearUrunGrubu,
        clearKdvOrani: clearKdvOrani,
        clearDepo: clearDepo,
        clearCikisDepo: clearCikisDepo,
        clearGirisDepo: clearGirisDepo,
        clearHesapTuru: clearHesapTuru,
        clearBakiyeDurumu: clearBakiyeDurumu,
        clearIslemTuru: clearIslemTuru,
        clearDurum: clearDurum,
        clearOdemeYontemi: clearOdemeYontemi,
        clearKasa: clearKasa,
        clearBanka: clearBanka,
        clearKrediKarti: clearKrediKarti,
        clearKullanici: clearKullanici,
        clearBelgeNo: clearBelgeNo,
        clearReferansNo: clearReferansNo,
      );
      _sayfalamayiSifirla();
    });
    _raporuYukle();
  }

  void _ensureTypeaheadLabelsLoaded() {
    final int? cariId = _filtreler.cariId;
    if (cariId != null &&
        (_seciliCariLabel == null || _seciliCariLabel!.trim().isEmpty) &&
        !_cariLabelResolving) {
      _cariLabelResolving = true;
      unawaited(() async {
        try {
          final secenek = await _raporlarServisi.cariSecenegiGetir(cariId);
          if (!mounted) return;
          setState(() {
            _seciliCariLabel = secenek?.label;
            _cariLabelResolving = false;
          });
        } catch (_) {
          if (!mounted) return;
          setState(() => _cariLabelResolving = false);
        }
      }());
    }

    final String? urunKodu = _filtreler.urunKodu;
    if (urunKodu != null &&
        urunKodu.trim().isNotEmpty &&
        (_seciliUrunLabel == null || _seciliUrunLabel!.trim().isEmpty) &&
        !_urunLabelResolving) {
      _urunLabelResolving = true;
      unawaited(() async {
        try {
          final secenek = await _raporlarServisi.urunSecenegiGetir(urunKodu);
          if (!mounted) return;
          setState(() {
            _seciliUrunLabel = secenek?.label;
            _urunLabelResolving = false;
          });
        } catch (_) {
          if (!mounted) return;
          setState(() => _urunLabelResolving = false);
        }
      }());
    }
  }

  Future<void> _cariSecimDialogAc() async {
    final secenek = await _showTypeaheadDialog(
      title: tr('reports.filters.current_account'),
      icon: Icons.people_alt_outlined,
      searcher: _raporlarServisi.cariSecenekleriAra,
    );
    if (!mounted || secenek == null) return;
    final int? id = int.tryParse(secenek.value);
    if (id == null) return;
    setState(() => _seciliCariLabel = secenek.label);
    _secimGuncelle(cariId: id, clearCari: false);
  }

  Future<void> _urunSecimDialogAc() async {
    final secenek = await _showTypeaheadDialog(
      title: tr('reports.filters.product'),
      icon: Icons.inventory_2_outlined,
      searcher: _raporlarServisi.urunSecenekleriAra,
    );
    if (!mounted || secenek == null) return;
    final String kod = secenek.value.trim();
    if (kod.isEmpty) return;
    setState(() => _seciliUrunLabel = secenek.label);
    _secimGuncelle(urunKodu: kod, clearUrun: false);
  }

  Future<RaporSecimSecenegi?> _showTypeaheadDialog({
    required String title,
    required IconData icon,
    required Future<List<RaporSecimSecenegi>> Function(String query) searcher,
  }) async {
    final controller = TextEditingController();
    Timer? debounce;
    int revision = 0;
    bool loading = false;
    List<RaporSecimSecenegi> results = const <RaporSecimSecenegi>[];

    Future<void> runSearch(
      String query,
      void Function(VoidCallback fn) setStateDialog,
    ) async {
      final trimmed = query.trim();
      if (trimmed.length < 2) {
        setStateDialog(() {
          loading = false;
          results = const <RaporSecimSecenegi>[];
        });
        return;
      }

      final int myRev = ++revision;
      setStateDialog(() => loading = true);
      try {
        final list = await searcher(trimmed);
        if (!mounted || myRev != revision) return;
        setStateDialog(() => results = list);
      } finally {
        if (mounted && myRev == revision) {
          setStateDialog(() => loading = false);
        }
      }
    }

    final selected = await showDialog<RaporSecimSecenegi>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 520,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: Icon(icon),
                        hintText: tr('common.search'),
                      ),
                      onChanged: (value) {
                        debounce?.cancel();
                        debounce = Timer(
                          const Duration(milliseconds: 250),
                          () => runSearch(value, setStateDialog),
                        );
                      },
                      onSubmitted: (value) => runSearch(value, setStateDialog),
                    ),
                    const SizedBox(height: 10),
                    if (loading)
                      const LinearProgressIndicator(minHeight: 2)
                    else
                      const SizedBox(height: 2),
                    const SizedBox(height: 10),
                    Expanded(
                      child: results.isEmpty
                          ? Center(
                              child: Text(
                                controller.text.trim().length < 2
                                    ? '${tr('common.search')}...'
                                    : tr('common.no_results'),
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : ListView.separated(
                              itemCount: results.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = results[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => Navigator.of(context).pop(item),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('common.cancel')),
                ),
              ],
            );
          },
        );
      },
    );

    debounce?.cancel();
    controller.dispose();
    return selected;
  }

  void _uygulaMetinFiltreleri() {
    _metinFiltreDebounce?.cancel();
    _raporuYukle();
  }

  void _metinFiltreDegisti() {
    _metinFiltreDebounce?.cancel();
    setState(_sayfalamayiSifirla);
    _metinFiltreDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      _raporuYukle();
    });
  }

  void _aramaDegisti(String value) {
    if (value == _arama) return;

    setState(() {
      _arama = value;
      _sayfalamayiSifirla();
    });
    _metinFiltreDebounce?.cancel();
    _metinFiltreDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _raporuYukle(showLoading: false);
    });
  }

  void _sortGuncelle(String key, bool ascending) {
    setState(() {
      _sortKey = key;
      _sortAscending = ascending;
      _sayfalamayiSifirla();
    });
    _raporuYukle();
  }

  void _showColumnVisibilityDialog() {
    final sonuc = _sonuc;
    final rapor = _seciliRapor;
    if (sonuc == null || rapor == null) return;

    final Map<String, bool> localVisibility = Map<String, bool>.from(
      _kolonGorunurluklari[rapor.id] ??
          {
            for (final kolon in sonuc.columns)
              kolon.key: kolon.visibleByDefault,
          },
    );
    bool localBosSutunlariGizle =
        _bosSutunlariGizleByReport[rapor.id] ?? _defaultHideEmptyColumns;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool allSelected = sonuc.columns.every(
              (kolon) => localVisibility[kolon.key] ?? kolon.visibleByDefault,
            );
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
                    color: AppPalette.slate,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('common.column_settings'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppPalette.slate,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr(rapor.labelKey),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppPalette.lightText,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                tr('common.select_all'),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Checkbox(
                                value: allSelected,
                                activeColor: AppPalette.slate,
                                onChanged: (value) {
                                  setDialogState(() {
                                    for (final kolon in sonuc.columns) {
                                      localVisibility[kolon.key] =
                                          value ?? false;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: sonuc.columns.map((kolon) {
                          return SizedBox(
                            width: 180,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              mouseCursor: SystemMouseCursors.click,
                              onTap: () {
                                setDialogState(() {
                                  localVisibility[kolon.key] =
                                      !(localVisibility[kolon.key] ??
                                          kolon.visibleByDefault);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value:
                                          localVisibility[kolon.key] ??
                                          kolon.visibleByDefault,
                                      activeColor: AppPalette.slate,
                                      onChanged: (value) {
                                        setDialogState(() {
                                          localVisibility[kolon.key] =
                                              value ?? kolon.visibleByDefault;
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: Text(
                                        _toTitleCaseTr(tr(kolon.labelKey)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppPalette.lightText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        mouseCursor: SystemMouseCursors.click,
                        onTap: () {
                          setDialogState(() {
                            localBosSutunlariGizle = !localBosSutunlariGizle;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: localBosSutunlariGizle,
                                activeColor: AppPalette.slate,
                                onChanged: (value) {
                                  setDialogState(() {
                                    localBosSutunlariGizle = value ?? false;
                                  });
                                },
                              ),
                              const Expanded(
                                child: Text(
                                  'Boş olan sütunlar görünmesin',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppPalette.lightText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                    style: const TextStyle(color: AppPalette.slate),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    setState(() {
                      _kolonGorunurluklari[rapor.id] = localVisibility;
                      _bosSutunlariGizleByReport[rapor.id] =
                          localBosSutunlariGizle;
                    });
                    await _saveColumnSettingsToPrefs(
                      reportId: rapor.id,
                      visibility: localVisibility,
                      hideEmptyColumns: localBosSutunlariGizle,
                    );
                    if (!mounted) return;
                    navigator.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(tr('common.save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openPrintPreview() async {
    await _openPrintPreviewInternal(selectedOnly: false);
  }

  Future<void> _openSelectedPrintPreview() async {
    await _openPrintPreviewInternal(selectedOnly: true);
  }

  bool _isSaleIntegrationRef(String integrationRef) {
    final String lowRef = integrationRef.trim().toLowerCase();
    return lowRef.startsWith('sale-') || lowRef.startsWith('retail-');
  }

  Future<void> _openSelectedDocumentPrint() async {
    final String? selectedRowId = _selectedRowId;
    if (selectedRowId == null) return;

    RaporSatiri? selectedRow;
    for (final row in _sayfaSatirlari) {
      if (row.id == selectedRowId) {
        selectedRow = row;
        break;
      }
    }
    if (selectedRow == null) return;

    final String integrationRef =
        selectedRow.extra['integrationRef']?.toString().trim() ?? '';
    if (integrationRef.isEmpty) return;
    if (!_isSaleIntegrationRef(integrationRef)) return;

    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    DateTime? parseDateTime(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value.trim());
      }
      return null;
    }

    final cariServisi = CariHesaplarVeritabaniServisi();

    Map<String, dynamic>? cariIslem;
    try {
      cariIslem = await cariServisi.cariIslemGetirByRef(integrationRef);
    } catch (e) {
      debugPrint('Rapor belge yazdır cari işlemi alınamadı: $e');
    }

    CariHesapModel? cari;
    final int? cariId = parseInt(cariIslem?['current_account_id']);
    if (cariId != null) {
      try {
        cari = await cariServisi.cariHesapGetir(cariId);
      } catch (e) {
        debugPrint('Rapor belge yazdır cari bilgisi alınamadı: $e');
      }
    }

    final String paraBirimi = () {
      final raw = cariIslem?['para_birimi']?.toString().trim() ?? '';
      if (raw.isNotEmpty) return raw;
      return (cari?.paraBirimi.trim().isNotEmpty ?? false)
          ? cari!.paraBirimi
          : 'TRY';
    }();

    final double genelToplam =
        (cariIslem == null
                ? selectedRow.amountValue
                : parseDouble(cariIslem['amount'] ?? cariIslem['tutar']))
            ?.abs() ??
        0.0;

    final DateTime initialTarih =
        (parseDateTime(cariIslem?['date'] ?? cariIslem?['tarih']) ??
                (selectedRow.sortValues['tarih'] is DateTime
                    ? selectedRow.sortValues['tarih'] as DateTime
                    : null) ??
                DateTime.now())
            .toLocal();

    final String initialFaturaNo =
        (cariIslem?['fatura_no']?.toString() ??
                selectedRow.cells['fatura_no'] ??
                '')
            .trim();
    final String initialIrsaliyeNo =
        (cariIslem?['irsaliye_no']?.toString() ??
                selectedRow.cells['irsaliye_no'] ??
                '')
            .trim();

    final String cariAdi = (cari?.adi.trim().isNotEmpty ?? false)
        ? cari!.adi
        : ((selectedRow.cells['yer_adi'] ?? '').trim().isNotEmpty
              ? selectedRow.cells['yer_adi']!.trim()
              : ((selectedRow.cells['yer'] ?? '').trim().isNotEmpty
                    ? selectedRow.cells['yer']!.trim()
                    : '-'));

    final String cariKodu = (cari?.kodNo.trim().isNotEmpty ?? false)
        ? cari!.kodNo
        : ((selectedRow.cells['yer_kodu'] ?? '').trim() == '-' ||
                  (selectedRow.cells['yer_kodu'] ?? '').trim().isEmpty
              ? ''
              : selectedRow.cells['yer_kodu']!.trim());

    final List<Map<String, dynamic>> itemsForPrint = [];
    try {
      final shipments = await cariServisi.entegrasyonShipmentsGetir(
        integrationRef,
      );
      for (final shipment in shipments) {
        final raw = shipment['items'];
        final List<dynamic> rawItems = raw is List
            ? raw
            : (raw is Map ? <dynamic>[raw] : const <dynamic>[]);

        for (final it in rawItems) {
          if (it is! Map) continue;
          final map = Map<String, dynamic>.from(it);
          itemsForPrint.add({
            'name': map['name'] ?? map['code'] ?? '',
            'code': map['code'] ?? '',
            'barcode': map['barcode'] ?? '',
            'quantity': parseDouble(map['quantity']),
            'unit': map['unit'] ?? '',
            'unitCost': parseDouble(
              map['unitCost'] ??
                  map['unit_cost'] ??
                  map['price'] ??
                  map['unitPrice'] ??
                  map['unit_price'],
            ),
            'total': parseDouble(
              map['total'] ??
                  map['lineTotal'] ??
                  map['line_total'] ??
                  map['tutar'],
            ),
            'discountRate': map['discountRate'] ?? map['discount_rate'],
            'vatRate': map['vatRate'] ?? map['vat_rate'],
            'currency': map['currency'] ?? paraBirimi,
            'exchangeRate': map['exchangeRate'] ?? map['exchange_rate'] ?? 1,
            'warehouseId': map['warehouseId'] ?? map['warehouse_id'],
            'warehouseName': map['warehouseName'] ?? map['warehouse_name'],
            'serialNumber': map['serialNumber'] ?? map['serial_number'],
          });
        }
      }
    } catch (e) {
      debugPrint('Rapor belge yazdır ürünleri alınamadı: $e');
    }

    if (!mounted) return;
    final bool? res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SatisSonrasiYazdirSayfasi(
          entegrasyonRef: integrationRef,
          cariAdi: cariAdi,
          cariKodu: cariKodu,
          genelToplam: genelToplam,
          paraBirimi: paraBirimi,
          initialFaturaNo: initialFaturaNo,
          initialIrsaliyeNo: initialIrsaliyeNo,
          initialTarih: initialTarih,
          items: itemsForPrint,
        ),
      ),
    );

    if (res == true && mounted) {
      await _raporuYukle(showLoading: false);
    }
  }

  Future<DetailTable?> _resolveIntegrationDetailTable(RaporSatiri row) async {
    final String integrationRef =
        row.extra['integrationRef']?.toString().trim() ?? '';
    if (integrationRef.isEmpty) return null;

    final String aciklamaRaw = (row.cells['aciklama'] ?? '').trim();
    final String? aciklama = (aciklamaRaw.isEmpty || aciklamaRaw == '-')
        ? null
        : aciklamaRaw;

    final future = _integrationDetailFutures.putIfAbsent(
      integrationRef,
      () => _raporlarServisi.entegrasyonUrunDetayTablosuGetir(
        integrationRef,
        aciklama: aciklama,
      ),
    );

    try {
      return await future;
    } catch (e) {
      debugPrint('Rapor yazdırma detay yüklenemedi ($integrationRef): $e');
      return null;
    }
  }

  Future<List<ExpandableRowData>> _buildPrintableRows({
    required List<RaporSatiri> rows,
    required List<RaporKolonTanimi> visibleColumns,
    required Set<String> expandedIds,
    required bool keepDetailsOpen,
  }) async {
    bool shouldExpand(RaporSatiri row) =>
        row.expandable && (keepDetailsOpen || expandedIds.contains(row.id));

    final Map<String, DetailTable?> resolvedTablesByRowId =
        <String, DetailTable?>{};

    final loaders = <Future<void> Function()>[];
    for (final row in rows) {
      if (!shouldExpand(row)) continue;
      if (row.detailTable != null) continue;
      final String integrationRef =
          row.extra['integrationRef']?.toString().trim() ?? '';
      if (integrationRef.isEmpty) continue;
      loaders.add(() async {
        final table = await _resolveIntegrationDetailTable(row);
        resolvedTablesByRowId[row.id] = table;
      });
    }

    const int chunkSize = 6;
    for (int i = 0; i < loaders.length; i += chunkSize) {
      final chunk = loaders.sublist(i, math.min(i + chunkSize, loaders.length));
      await Future.wait(chunk.map((fn) => fn()));
    }

    return rows.map((row) {
      final List<String> mainRow = visibleColumns
          .map((column) => row.cells[column.key] ?? '-')
          .toList();

      final bool expanded = shouldExpand(row);
      final table = row.detailTable ?? resolvedTablesByRowId[row.id];

      return ExpandableRowData(
        mainRow: mainRow,
        details: row.details,
        transactions: table,
        isExpanded: expanded,
        isSourceExpanded: expanded,
      );
    }).toList();
  }

  Future<void> _openPrintPreviewInternal({required bool selectedOnly}) async {
    final sonuc = _sonuc;
    final rapor = _seciliRapor;
    if (sonuc == null || rapor == null || sonuc.isDisabled) return;

    final Set<String> expandedIds = Set<String>.from(_expandedRowIds)
      ..addAll(_autoExpandedRowIds);
    final bool keepDetailsOpen = _keepDetailsOpen;
    final bool isAllMovementsPrint = rapor.id == 'all_movements';
    final bool isProfitLossPrint = rapor.id == 'profit_loss';
    final bool isBalanceListPrint = rapor.id == 'balance_list';
    final bool isBaBsPrint = rapor.id == 'ba_bs_list';
    final bool isReceivablesPayablesPrint = rapor.id == 'receivables_payables';
    final bool isVatAccountingPrint = rapor.id == 'vat_accounting';
    final bool isLastTransactionDatePrint = rapor.id == 'last_transaction_date';
    final bool isPurchaseSalesMovementsPrint =
        rapor.id == 'purchase_sales_movements';
    final bool isProductMovementsPrint = rapor.id == 'product_movements';
    final bool isProductShipmentMovementsPrint =
        rapor.id == 'product_shipment_movements';
    final bool isWarehouseStockListPrint = rapor.id == 'warehouse_stock_list';
    final bool isWarehouseShipmentListPrint =
        rapor.id == 'warehouse_shipment_list';

    late final RaporSonucu printSourceSonuc;
    late final List<RaporSatiri> rows;
    if (selectedOnly) {
      final String? selectedRowId = _selectedRowId;
      if (selectedRowId == null) return;

      RaporSatiri? selectedRow;
      for (final item in _sayfaSatirlari) {
        if (item.id == selectedRowId) {
          selectedRow = item;
          break;
        }
      }
      if (selectedRow == null) {
        MesajYardimcisi.bilgiGoster(context, tr('common.no_data'));
        return;
      }
      rows = <RaporSatiri>[selectedRow];
      printSourceSonuc = sonuc;
    } else {
      final int printLimit = math.min(
        math.max(sonuc.totalCount, _satirSayisi).clamp(1, 5000),
        5000,
      );
      final fullResult = await _raporlarServisi.raporuGetir(
        rapor: rapor,
        filtreler: _aktifFiltreler,
        page: 1,
        pageSize: printLimit,
        arama: _arama,
        sortKey: _sortKey,
        sortAscending: _sortAscending,
      );
      if (!mounted) return;
      rows = fullResult.rows;
      printSourceSonuc = fullResult;
    }

    if (rows.isEmpty) {
      MesajYardimcisi.bilgiGoster(context, tr('common.no_data'));
      return;
    }

    final List<RaporKolonTanimi> printColumns = isProductShipmentMovementsPrint
        ? const <RaporKolonTanimi>[
            RaporKolonTanimi(key: 'tarih', labelKey: 'Tarih', width: 120),
            RaporKolonTanimi(
              key: 'kaynak',
              labelKey: 'Çıkış Yapılan Depo',
              width: 170,
            ),
            RaporKolonTanimi(
              key: 'hedef',
              labelKey: 'Giriş Yapılan Depo',
              width: 170,
            ),
            RaporKolonTanimi(key: 'kod', labelKey: 'Kod No', width: 110),
            RaporKolonTanimi(key: 'ad', labelKey: 'Adı', width: 200),
            RaporKolonTanimi(
              key: 'miktar_olcu',
              labelKey: 'Miktar Ölçü',
              width: 150,
            ),
            RaporKolonTanimi(key: 'aciklama', labelKey: 'Açıklama', width: 220),
          ]
        : isWarehouseStockListPrint
        ? const <RaporKolonTanimi>[
            RaporKolonTanimi(key: 'kod', labelKey: 'KOD NO', width: 110),
            RaporKolonTanimi(key: 'ad', labelKey: 'ADI', width: 200),
            RaporKolonTanimi(key: 'barkod', labelKey: 'BARKOD NO', width: 140),
            RaporKolonTanimi(key: 'grup', labelKey: 'GRUBU', width: 140),
            RaporKolonTanimi(
              key: 'miktar_olcu',
              labelKey: 'MİKTAR ÖLÇÜ',
              width: 150,
            ),
          ]
        : (isProfitLossPrint ||
              isBalanceListPrint ||
              isBaBsPrint ||
              isReceivablesPayablesPrint ||
              isVatAccountingPrint ||
              isLastTransactionDatePrint ||
              isPurchaseSalesMovementsPrint ||
              isProductMovementsPrint ||
              isWarehouseShipmentListPrint)
        ? printSourceSonuc.columns
        : _gorunurKolonlar;

    final List<bool> defaultPrintVisibility = () {
      if (isAllMovementsPrint) {
        const keys = <String>{
          'islem',
          'yer',
          'yer_kodu',
          'yer_adi',
          'tarih',
          'tutar',
          'kur',
          'yer_2',
          'belge',
        };
        return printColumns.map((col) => keys.contains(col.key)).toList();
      }

      if (isPurchaseSalesMovementsPrint) {
        const keys = <String>{
          'tarih',
          'islem',
          'yer_kodu',
          'yer_adi',
          'vkn_tckn',
          'matrah',
          'toplam_vergi',
          'genel_toplam',
          'aciklama',
        };
        return printColumns.map((col) => keys.contains(col.key)).toList();
      }

      if (isProfitLossPrint) {
        const keys = <String>{
          'kod',
          'ad',
          'devreden_eklenen',
          'satilan',
          'kalan',
          'birim',
          'sat_mal_top_alis_degeri',
          'toplam_satis_degeri',
          'kalan_stok_degeri',
          'brut_kar',
        };
        return printColumns.map((col) => keys.contains(col.key)).toList();
      }

      if (isBalanceListPrint) {
        return List<bool>.filled(printColumns.length, true);
      }

      if (isBaBsPrint) {
        return List<bool>.filled(printColumns.length, true);
      }

      if (isReceivablesPayablesPrint) {
        return List<bool>.filled(printColumns.length, true);
      }

      if (isVatAccountingPrint) {
        const keys = <String>{
          'islem',
          'tarih',
          'kod',
          'ad',
          'miktar',
          'birim',
          'kdv_orani',
          'birim_fiyati',
          'kdv',
        };
        return printColumns.map((col) => keys.contains(col.key)).toList();
      }

      if (isLastTransactionDatePrint) {
        const keys = <String>{
          'kod',
          'ad',
          'tur',
          'bakiye_borc',
          'bakiye_alacak',
          'son_islem',
          'son_islem_tutar',
          'son_islem_tarihi',
          'gecen_gun',
        };
        return printColumns.map((col) => keys.contains(col.key)).toList();
      }

      if (isProductMovementsPrint) {
        const keys = <String>{
          'islem',
          'tarih',
          'kod',
          'ad',
          'depo',
          'miktar',
          'olcu',
          'birim_fiyat_vd',
          'yer_kodu',
          'yer_adi',
        };
        return printColumns.map((col) => keys.contains(col.key)).toList();
      }

      if (isProductShipmentMovementsPrint) {
        return List<bool>.filled(printColumns.length, true);
      }

      if (isWarehouseStockListPrint) {
        return List<bool>.filled(printColumns.length, true);
      }

      if (isWarehouseShipmentListPrint) {
        return List<bool>.filled(printColumns.length, true);
      }

      const keys = <String>{
        'islem',
        'yer',
        'yer_kodu',
        'yer_adi',
        'tarih',
        'tutar',
        'kur',
        'yer_2',
        'belge',
      };
      return printColumns.map((col) => keys.contains(col.key)).toList();
    }();

    final List<double>? mainColumnFlexes = () {
      if (isAllMovementsPrint) {
        return printColumns.map((col) {
          switch (col.key) {
            case 'islem':
              return 2.1;
            case 'yer':
              return 1.7;
            case 'yer_kodu':
              return 0.6;
            case 'yer_adi':
              return 3.2;
            case 'tarih':
              return 1.8;
            case 'tutar':
              return 1.1;
            case 'kur':
              return 0.75;
            case 'yer_2':
              return 0.85;
            case 'belge':
              return 0.75;
            case 'aciklama':
            case 'aciklama_2':
              return 2.2;
            case 'e_belge':
            case 'irsaliye_no':
            case 'fatura_no':
            case 'vade_tarihi':
            case 'kullanici':
              return 1.2;
            default:
              return 1.0;
          }
        }).toList();
      }

      if (isBalanceListPrint) {
        return printColumns.map((col) {
          switch (col.key) {
            case 'kod':
              return 0.75;
            case 'hesap':
              return 2.8;
            case 'tur':
              return 1.1;
            default:
              return 1.0;
          }
        }).toList();
      }

      if (isLastTransactionDatePrint) {
        return printColumns.map((col) {
          switch (col.key) {
            case 'kod':
              return 0.9;
            case 'ad':
              return 2.4;
            case 'tur':
              return 1.2;
            case 'bakiye_borc':
            case 'bakiye_alacak':
              return 1.15;
            case 'son_islem':
              return 1.6;
            case 'son_islem_tutar':
              return 1.2;
            case 'son_islem_tarihi':
              return 1.2;
            case 'gecen_gun':
              return 0.85;
            default:
              return 1.0;
          }
        }).toList();
      }

      return null;
    }();

    final Set<int>? rightAlignedMainColumnIndices = () {
      if (isAllMovementsPrint) {
        const keys = <String>{
          'tutar',
          'kur',
          'ara_toplam',
          'kdv',
          'genel_toplam',
          'borc',
          'alacak',
          'net_bakiye',
          'stok_degeri',
          'maliyet',
          'alis',
          'satis1',
          'satis2',
          'satis3',
          'ciro',
          'gider',
          'brut_kar',
          'net_kar',
          'tutar_etkisi',
          'vergi',
          'fark',
        };
        final indices = <int>{};
        for (int i = 0; i < printColumns.length; i++) {
          if (keys.contains(printColumns[i].key)) {
            indices.add(i);
          }
        }
        return indices;
      }

      if (isProfitLossPrint) {
        const keys = <String>{
          'devreden',
          'eklenen',
          'devreden_eklenen',
          'satilan',
          'kalan',
          'dev_ekl_stok_degeri',
          'sat_mal_top_alis_degeri',
          'toplam_satis_degeri',
          'kalan_stok_degeri',
          'brut_kar',
        };
        final indices = <int>{};
        for (int i = 0; i < printColumns.length; i++) {
          if (keys.contains(printColumns[i].key)) {
            indices.add(i);
          }
        }
        return indices.isEmpty ? null : indices;
      }

      if (isBalanceListPrint) {
        const keys = <String>{'borc', 'alacak', 'bakiye_borc', 'bakiye_alacak'};
        final indices = <int>{};
        for (int i = 0; i < printColumns.length; i++) {
          if (keys.contains(printColumns[i].key)) {
            indices.add(i);
          }
        }
        return indices.isEmpty ? null : indices;
      }

      if (isBaBsPrint) {
        const keys = <String>{
          'alis_fatura_matrah',
          'satis_fatura_matrah',
          'alis_fatura_adet',
          'satis_fatura_adet',
        };
        final indices = <int>{};
        for (int i = 0; i < printColumns.length; i++) {
          if (keys.contains(printColumns[i].key)) {
            indices.add(i);
          }
        }
        return indices.isEmpty ? null : indices;
      }

      if (isReceivablesPayablesPrint) {
        const keys = <String>{'tutar'};
        final indices = <int>{};
        for (int i = 0; i < printColumns.length; i++) {
          if (keys.contains(printColumns[i].key)) {
            indices.add(i);
          }
        }
        return indices.isEmpty ? null : indices;
      }

      if (isVatAccountingPrint) {
        const keys = <String>{
          'miktar',
          'kdv_orani',
          'otv_orani',
          'oiv_orani',
          'tevkifat',
          'isk_orani',
          'birim_fiyati',
          'matrah',
          'kdv',
          'otv_tutari',
          'oiv_tutari',
          'genel_toplam',
        };
        final indices = <int>{};
        for (int i = 0; i < printColumns.length; i++) {
          if (keys.contains(printColumns[i].key)) {
            indices.add(i);
          }
        }
        return indices.isEmpty ? null : indices;
      }

      if (isPurchaseSalesMovementsPrint) {
        const keys = <String>{
          'matrah',
          'kdv',
          'toplam_vergi',
          'genel_toplam',
          'kur',
        };
        final indices = <int>{};
        for (int i = 0; i < printColumns.length; i++) {
          if (keys.contains(printColumns[i].key)) {
            indices.add(i);
          }
        }
        return indices.isEmpty ? null : indices;
      }

      if (isLastTransactionDatePrint) {
        const keys = <String>{
          'bakiye_borc',
          'bakiye_alacak',
          'son_islem_tutar',
          'gecen_gun',
        };
        final indices = <int>{};
        for (int i = 0; i < printColumns.length; i++) {
          if (keys.contains(printColumns[i].key)) {
            indices.add(i);
          }
        }
        return indices.isEmpty ? null : indices;
      }

      if (isProductMovementsPrint) {
        const keys = <String>{'miktar', 'birim_fiyat', 'birim_fiyat_vd'};
        final indices = <int>{};
        for (int i = 0; i < printColumns.length; i++) {
          if (keys.contains(printColumns[i].key)) {
            indices.add(i);
          }
        }
        return indices.isEmpty ? null : indices;
      }

      if (isProductShipmentMovementsPrint) {
        const keys = <String>{'miktar_olcu'};
        final indices = <int>{};
        for (int i = 0; i < printColumns.length; i++) {
          if (keys.contains(printColumns[i].key)) {
            indices.add(i);
          }
        }
        return indices.isEmpty ? null : indices;
      }

      if (isWarehouseStockListPrint) {
        const keys = <String>{'miktar_olcu'};
        final indices = <int>{};
        for (int i = 0; i < printColumns.length; i++) {
          if (keys.contains(printColumns[i].key)) {
            indices.add(i);
          }
        }
        return indices.isEmpty ? null : indices;
      }

      return null;
    }();

    Map<String, String>? footerTotals;
    String? footerTotalsTitle;
    if (rapor.id == 'all_movements' || rapor.id == 'vat_accounting') {
      final Map<String, double> totalsByProcess = <String, double>{};
      for (final row in rows) {
        final String label = (row.cells['islem'] ?? '').trim();
        if (label.isEmpty || label == '-') continue;
        final double amount = (row.amountValue ?? 0).abs();
        if (amount == 0) continue;
        totalsByProcess[label] = (totalsByProcess[label] ?? 0) + amount;
      }

      String currencySuffix = '';
      for (final row in rows) {
        final String raw = (row.cells['tutar'] ?? '').trim();
        if (raw.isEmpty || raw == '-') continue;
        final int lastSpace = raw.lastIndexOf(' ');
        if (lastSpace != -1 && lastSpace < raw.length - 1) {
          currencySuffix = raw.substring(lastSpace + 1).trim();
        }
        break;
      }

      if (totalsByProcess.isNotEmpty) {
        final sortedKeys = totalsByProcess.keys.toList()..sort();
        final Map<String, String> formattedTotals = <String, String>{};
        for (final key in sortedKeys) {
          final String formattedValue = FormatYardimcisi.sayiFormatlaOndalikli(
            totalsByProcess[key] ?? 0,
            decimalDigits: 2,
          );
          formattedTotals[key] = currencySuffix.isEmpty
              ? formattedValue
              : '$formattedValue $currencySuffix';
        }
        footerTotals = formattedTotals;
        footerTotalsTitle = 'İŞLEM TOPLAMLARI';
      }
    }

    if (!selectedOnly && isProfitLossPrint) {
      final dynamic totalsList =
          printSourceSonuc.headerInfo['profit_loss_totals'];
      if (totalsList is List) {
        final Map<String, String> formattedTotals = <String, String>{};
        for (final entry in totalsList) {
          if (entry is! Map) continue;
          final String label = entry['label']?.toString().trim() ?? '';
          final String value = entry['value']?.toString().trim() ?? '';
          final String unit = entry['unit']?.toString().trim() ?? '';
          if (label.isEmpty) continue;
          if (value.isEmpty || value == '-') continue;
          formattedTotals[label] = unit.isEmpty ? value : '$value $unit';
        }
        if (formattedTotals.isNotEmpty) {
          footerTotals = formattedTotals;
          footerTotalsTitle = 'LİSTE TOPLAMLARI';
        }
      }
    }

    if (!selectedOnly && isBalanceListPrint) {
      final cards = printSourceSonuc.summaryCards;
      if (cards.isNotEmpty) {
        final Map<String, String> formattedTotals = <String, String>{};
        for (final card in cards) {
          final String label = tr(card.labelKey).trim();
          final String value = card.value.trim();
          if (label.isEmpty) continue;
          if (value.isEmpty || value == '-') continue;
          formattedTotals[label] = value;
        }
        if (formattedTotals.isNotEmpty) {
          footerTotals = formattedTotals;
          footerTotalsTitle = 'LİSTE TOPLAMLARI';
        }
      }
    }

    if (!selectedOnly && isBaBsPrint) {
      final cards = printSourceSonuc.summaryCards;
      if (cards.isNotEmpty) {
        final Map<String, String> formattedTotals = <String, String>{};
        for (final card in cards) {
          final String label = tr(card.labelKey).trim();
          final String value = card.value.trim();
          if (label.isEmpty) continue;
          if (value.isEmpty || value == '-') continue;
          formattedTotals[label] = value;
        }
        if (formattedTotals.isNotEmpty) {
          footerTotals = formattedTotals;
          footerTotalsTitle = 'LİSTE TOPLAMLARI';
        }
      }
    }

    if (!selectedOnly && isReceivablesPayablesPrint) {
      final cards = printSourceSonuc.summaryCards;
      if (cards.isNotEmpty) {
        final Map<String, String> formattedTotals = <String, String>{};
        for (final card in cards) {
          final String label = tr(card.labelKey).trim();
          final String value = card.value.trim();
          if (label.isEmpty) continue;
          if (value.isEmpty || value == '-') continue;
          formattedTotals[label] = value;
        }
        if (formattedTotals.isNotEmpty) {
          footerTotals = formattedTotals;
          footerTotalsTitle = 'LİSTE TOPLAMLARI';
        }
      }
    }

    if (!selectedOnly && isVatAccountingPrint) {
      final cards = printSourceSonuc.summaryCards;
      if (cards.isNotEmpty) {
        final Map<String, String> formattedTotals = <String, String>{};
        for (final card in cards) {
          final String label = tr(card.labelKey).trim();
          final String value = card.value.trim();
          if (label.isEmpty) continue;
          if (value.isEmpty || value == '-') continue;
          formattedTotals[label] = value;
        }
        if (formattedTotals.isNotEmpty) {
          footerTotals = formattedTotals;
          footerTotalsTitle = 'LİSTE TOPLAMLARI';
        }
      }
    }

    if (!selectedOnly && isPurchaseSalesMovementsPrint) {
      final cards = printSourceSonuc.summaryCards;
      if (cards.isNotEmpty) {
        final Map<String, String> formattedTotals = <String, String>{};
        for (final card in cards) {
          final String label = tr(card.labelKey).trim();
          final String value = card.value.trim();
          if (label.isEmpty) continue;
          if (value.isEmpty || value == '-') continue;
          formattedTotals[label] = value;
        }
        if (formattedTotals.isNotEmpty) {
          footerTotals = formattedTotals;
          footerTotalsTitle = 'LİSTE TOPLAMLARI';
        }
      }
    }

    if (!selectedOnly && isProductMovementsPrint) {
      final cards = printSourceSonuc.summaryCards;
      if (cards.isNotEmpty) {
        final Map<String, String> formattedTotals = <String, String>{};
        for (final card in cards) {
          final String label = tr(card.labelKey).trim();
          final String value = card.value.trim();
          if (label.isEmpty) continue;
          if (value.isEmpty || value == '-') continue;
          formattedTotals[label] = value;
        }
        if (formattedTotals.isNotEmpty) {
          footerTotals = formattedTotals;
          footerTotalsTitle = 'İŞLEM TOPLAMLARI';
        }
      }
    }

    if (!selectedOnly && isWarehouseStockListPrint) {
      final cards = printSourceSonuc.summaryCards;
      if (cards.isNotEmpty) {
        String? toplam;
        String? olcu;
        for (final card in cards) {
          switch (card.labelKey) {
            case 'Toplam':
              toplam = card.value.trim();
              break;
            case 'Ölçü':
              olcu = card.value.trim();
              break;
          }
        }

        final String toplamVal = (toplam ?? '').trim();
        final String olcuVal = (olcu ?? '').trim();
        final String combined = () {
          final bool hasTotal = toplamVal.isNotEmpty && toplamVal != '-';
          final bool hasUnit =
              olcuVal.isNotEmpty &&
              olcuVal != '-' &&
              olcuVal.toLowerCase() != 'çoklu';
          if (hasTotal && hasUnit) return '$toplamVal $olcuVal';
          if (hasTotal) return toplamVal;
          if (hasUnit) return olcuVal;
          return '';
        }();

        if (combined.isNotEmpty) {
          footerTotals = <String, String>{'': combined};
          footerTotalsTitle = 'MİKTAR TOPLAMLARI';
        }
      }
    }

    final List<RaporSatiri> printableRowsSource =
        (isProductShipmentMovementsPrint || isWarehouseStockListPrint)
        ? rows
              .map((row) {
                final String miktar = (row.cells['miktar'] ?? '-').trim();
                final String olcu = (row.cells['olcu'] ?? '-').trim();
                final String combined = () {
                  final bool hasQty = miktar.isNotEmpty && miktar != '-';
                  final bool hasUnit = olcu.isNotEmpty && olcu != '-';
                  if (hasQty && hasUnit) return '$miktar $olcu';
                  if (hasQty) return miktar;
                  if (hasUnit) return olcu;
                  return '-';
                }();
                return RaporSatiri(
                  id: row.id,
                  cells: <String, String>{
                    ...row.cells,
                    'miktar_olcu': combined,
                  },
                  details: row.details,
                  detailTable: row.detailTable,
                  expandable: row.expandable,
                  sourceMenuIndex: row.sourceMenuIndex,
                  sourceSearchQuery: row.sourceSearchQuery,
                  amountValue: row.amountValue,
                  sortValues: row.sortValues,
                  extra: row.extra,
                );
              })
              .toList(growable: false)
        : rows;

    final printRows = await _buildPrintableRows(
      rows: printableRowsSource,
      visibleColumns: printColumns,
      expandedIds: expandedIds,
      keepDetailsOpen: keepDetailsOpen,
    );

    final filtreOzeti = _raporlarServisi.filtreOzetiniOlustur(_aktifFiltreler);
    final headerInfo = <String, dynamic>{
      tr('reports.columns.report_name'): tr(rapor.labelKey),
      tr('common.date_range'): filtreOzeti.isEmpty
          ? tr('common.all')
          : filtreOzeti,
      tr('reports.summary.record'): rows.length.toString(),
    };

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => GenisletilebilirPrintPreviewScreen(
          title: tr(rapor.labelKey),
          headers: printColumns.map((col) => tr(col.labelKey)).toList(),
          data: printRows,
          dateInterval: filtreOzeti,
          initialShowDetails: false,
          initialMainColumnVisibility: isProfitLossPrint
              ? defaultPrintVisibility
              : null,
          defaultMainColumnVisibility: defaultPrintVisibility,
          mainColumnFlexes: mainColumnFlexes,
          rightAlignedMainColumnIndices: rightAlignedMainColumnIndices,
          forceMainSingleLine: isAllMovementsPrint,
          headerInfo: headerInfo,
          mainTableLabel: printSourceSonuc.mainTableLabel,
          detailTableLabel: printSourceSonuc.detailTableLabel,
          footerTotals: footerTotals,
          footerTotalsTitle: footerTotalsTitle,
        ),
      ),
    );
  }

  void _openSource(RaporSatiri row) {
    final opener = TabAciciScope.of(context);
    if (opener == null) return;

    final dynamic cari = row.extra['cariModel'];
    if (cari is CariHesapModel) {
      opener.tabAc(menuIndex: TabAciciScope.cariKartiIndex, initialCari: cari);
      return;
    }

    final dynamic urun = row.extra['urunModel'];
    if (urun is UrunModel) {
      opener.tabAc(menuIndex: TabAciciScope.urunKartiIndex, initialUrun: urun);
      return;
    }

    if (row.sourceMenuIndex != null) {
      opener.tabAc(
        menuIndex: row.sourceMenuIndex!,
        initialSearchQuery: row.sourceSearchQuery,
      );
    }
  }

  String? _bosIseNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  String? _sanitizeHesapTuru(String? value) {
    final raw = _bosIseNull(value);
    if (raw == null) return null;
    const allowed = <String>{'Alıcı', 'Satıcı', 'Alıcı/Satıcı'};
    return allowed.contains(raw) ? raw : null;
  }

  double? _parseDouble(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.replaceAll('.', '').replaceAll(',', '.')) ??
        double.tryParse(value.replaceAll(',', '.'));
  }

  bool _supports(RaporFiltreTuru tur) =>
      _seciliRapor?.supportedFilters.contains(tur) ?? false;

  @override
  Widget build(BuildContext context) {
    final bool isLoading =
        _filtreKaynaklariYukleniyor || (_raporYukleniyor && _sonuc == null);
    if (isLoading) {
      return const _RaporlarShimmer();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth >= 1200;
          final bool isTablet = constraints.maxWidth >= 800 && !isDesktop;
          final bool isMobile = !isDesktop && !isTablet;

          return _buildWorkspace(
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
          );
        },
      ),
    );
  }

  Widget _buildWorkspace({
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    final sonuc = _sonuc;
    final rapor = _seciliRapor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(isMobile: isMobile),
        const SizedBox(height: 8),
        _buildSelectorSummaryBand(isTablet: isTablet, isMobile: isMobile),
        const SizedBox(height: 8),
        Expanded(
          child: _buildReportCard(
            sonuc: sonuc,
            rapor: rapor,
            isMobile: isMobile,
            isTablet: isTablet,
          ),
        ),
      ],
    );
  }

  Widget _buildPageHeader({required bool isMobile}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('reports.title'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.slate,
                  ),
                ),
                if (isMobile) ...[
                  const SizedBox(height: 4),
                  Text(
                    tr('reports.subtitle'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppPalette.grey,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeaderCategorySelect(isMobile: isMobile),
              _buildHeaderReportSelect(isMobile: isMobile),
              if (isMobile)
                _buildHeaderButton(
                  label: _mobilFiltrelerAcik
                      ? tr('reports.actions.hide_filters')
                      : tr('reports.actions.show_filters'),
                  icon: _mobilFiltrelerAcik
                      ? Icons.expand_less_rounded
                      : Icons.tune_rounded,
                  onTap: () {
                    setState(() {
                      _mobilFiltrelerAcik = !_mobilFiltrelerAcik;
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCategorySelect({required bool isMobile}) {
    final kategori = _seciliKategori;
    return _buildHeaderPopupSelect<RaporKategori>(
      isMobile: isMobile,
      tooltip: tr('reports.sections.categories'),
      title: tr('reports.sections.categories'),
      valueText: tr(kategori.labelKey),
      icon: _kategoriIcon(kategori),
      accentColor: _accentColorForCategory(kategori),
      initialValue: kategori,
      onSelected: _kategoriSec,
      itemBuilder: (currentValue) {
        return RaporKategori.values
            .where(
              (item) =>
                  item == RaporKategori.genel || item == RaporKategori.stokDepo,
            )
            .map((item) {
              final bool secili = item == currentValue;
              return PopupMenuItem<RaporKategori>(
                value: item,
                mouseCursor: SystemMouseCursors.click,
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _accentColorForCategory(
                          item,
                        ).withValues(alpha: secili ? 0.16 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _kategoriIcon(item),
                        size: 15,
                        color: _accentColorForCategory(item),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr(item.labelKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.slate,
                        ),
                      ),
                    ),
                    if (secili)
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppPalette.slate,
                      ),
                  ],
                ),
              );
            })
            .toList();
      },
    );
  }

  Widget _buildHeaderReportSelect({required bool isMobile}) {
    final rapor = _seciliRapor;
    if (rapor == null) {
      return const SizedBox.shrink();
    }

    return _buildHeaderPopupSelect<RaporSecenegi>(
      isMobile: isMobile,
      tooltip: tr('reports.sections.report_types'),
      title: tr('reports.sections.report_types'),
      valueText: tr(rapor.labelKey),
      icon: rapor.icon,
      accentColor: _accentColorForCategory(rapor.category),
      initialValue: rapor,
      minWidth: isMobile ? 220 : 250,
      maxWidth: isMobile ? 280 : 330,
      onSelected: (selected) {
        if (!selected.supported) {
          MesajYardimcisi.uyariGoster(
            context,
            tr(selected.disabledReasonKey ?? 'reports.disabled.unknown'),
          );
          return;
        }
        _raporSec(selected);
      },
      itemBuilder: (currentValue) {
        return _kategoriRaporlari.map((item) {
          final bool secili = item.id == currentValue.id;
          final bool disabled = !item.supported;
          return PopupMenuItem<RaporSecenegi>(
            value: item,
            mouseCursor: disabled
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color:
                        (disabled
                                ? Colors.grey
                                : _accentColorForCategory(item.category))
                            .withValues(alpha: secili ? 0.16 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.icon,
                    size: 15,
                    color: disabled
                        ? Colors.grey
                        : _accentColorForCategory(item.category),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(item.labelKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: disabled ? Colors.grey : AppPalette.slate,
                        ),
                      ),
                      Text(
                        tr(item.category.labelKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: disabled ? Colors.grey : AppPalette.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (secili)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppPalette.slate,
                  ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildHeaderPopupSelect<T>({
    required bool isMobile,
    required String tooltip,
    required String title,
    required String valueText,
    required IconData icon,
    required Color accentColor,
    required T initialValue,
    required ValueChanged<T> onSelected,
    required List<PopupMenuEntry<T>> Function(T currentValue) itemBuilder,
    double? minWidth,
    double? maxWidth,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        constraints: BoxConstraints(
          minWidth: minWidth ?? (isMobile ? 180 : 220),
          maxWidth: maxWidth ?? (isMobile ? 240 : 290),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.grey.withValues(alpha: 0.18)),
        ),
        child: PopupMenuButton<T>(
          tooltip: tooltip,
          initialValue: initialValue,
          onSelected: onSelected,
          offset: const Offset(0, 42),
          itemBuilder: (context) => itemBuilder(initialValue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          color: Colors.white,
          padding: EdgeInsets.zero,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 16, color: accentColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          valueText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppPalette.slate,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorSummaryBand({
    required bool isTablet,
    required bool isMobile,
  }) {
    final sonuc = _sonuc;
    if (sonuc == null) {
      return const SizedBox.shrink();
    }

    final profitLossBand = _buildProfitLossSummaryBand(
      sonuc: sonuc,
      isTablet: isTablet,
      isMobile: isMobile,
    );
    if (profitLossBand != null) {
      return profitLossBand;
    }

    final cards = sonuc.summaryCards;
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool showIslemToplamlari =
        sonuc.report.id == 'all_movements' && sonuc.islemToplamlari.isNotEmpty;

    final String? seciliIslemTuru = _bosIseNull(_filtreler.islemTuru);
    final List<RaporIslemToplami> islemToplamlariForCards = !showIslemToplamlari
        ? const <RaporIslemToplami>[]
        : (seciliIslemTuru == null
              ? sonuc.islemToplamlari
              : sonuc.islemToplamlari
                    .where((item) => item.rawIslem == seciliIslemTuru)
                    .toList(growable: false));

    final bool showFilteredIslemToplamlari = islemToplamlariForCards.isNotEmpty;

    final List<RaporOzetKarti> mergedCards = showFilteredIslemToplamlari
        ? <RaporOzetKarti>[
            ...cards,
            ...islemToplamlariForCards.map(_islemToplaminiOzetKartinaCevir),
          ]
        : cards;

    return _buildSummaryCards(
      isMobile: isMobile,
      isTablet: isTablet,
      compact: !isMobile,
      cards: mergedCards,
    );
  }

  Widget? _buildProfitLossSummaryBand({
    required RaporSonucu sonuc,
    required bool isTablet,
    required bool isMobile,
  }) {
    if (sonuc.report.id != 'profit_loss') return null;

    final rawTotals = sonuc.headerInfo['profit_loss_totals'];
    if (rawTotals is! List) return null;

    ({IconData icon, Color accentColor}) styleForLabel(String label) {
      final String low = label.toLowerCase();

      if (low.contains('brüt') && low.contains('kar')) {
        return (
          icon: Icons.trending_up_rounded,
          accentColor: const Color(0xFF27AE60),
        );
      }
      if (low.contains('satış') && low.contains('değer')) {
        return (icon: Icons.payments_outlined, accentColor: AppPalette.red);
      }
      if (low.contains('alış') && low.contains('değer')) {
        return (
          icon: Icons.shopping_bag_outlined,
          accentColor: AppPalette.amber,
        );
      }
      if (low.contains('stok') && low.contains('değer')) {
        return (
          icon: Icons.inventory_2_outlined,
          accentColor: AppPalette.amber,
        );
      }
      if (low.contains('eklenen')) {
        return (icon: Icons.add_circle_outline, accentColor: AppPalette.slate);
      }
      if (low.contains('satılan')) {
        return (
          icon: Icons.shopping_cart_outlined,
          accentColor: AppPalette.slate,
        );
      }
      if (low.contains('kalan')) {
        return (icon: Icons.inventory_outlined, accentColor: AppPalette.slate);
      }
      if (low.contains('devreden')) {
        return (icon: Icons.history_rounded, accentColor: AppPalette.slate);
      }

      return (icon: Icons.summarize_outlined, accentColor: AppPalette.slate);
    }

    final List<RaporOzetKarti> cards = [];
    for (final item in rawTotals) {
      if (item is! Map) continue;
      final label = item['label']?.toString() ?? '';
      final value = item['value']?.toString() ?? '';
      final unit = item['unit']?.toString() ?? '';
      if (label.trim().isEmpty || value.trim().isEmpty) continue;

      final style = styleForLabel(label);
      final String valueText = unit.trim().isEmpty ? value : '$value $unit';

      cards.add(
        RaporOzetKarti(
          labelKey: label, // tr() fallback shows label as-is
          value: valueText,
          icon: style.icon,
          accentColor: style.accentColor,
        ),
      );
    }

    if (cards.isEmpty && sonuc.summaryCards.isEmpty) return null;
    cards.addAll(sonuc.summaryCards);

    const double spacing = 8;
    const double minSingleRowCardWidth = 110;
    const double minWrapCardWidth = 220;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final double perCardWidth = cards.length <= 1
            ? maxWidth
            : (maxWidth - (spacing * (cards.length - 1))) / cards.length;

        if (!isMobile && perCardWidth >= minSingleRowCardWidth) {
          return SizedBox(
            height: 72,
            child: Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  Expanded(child: _buildCompactSummaryCard(cards[i])),
                  if (i != cards.length - 1) const SizedBox(width: spacing),
                ],
              ],
            ),
          );
        }

        final int columns = math
            .max(
              1,
              ((maxWidth + spacing) / (minWrapCardWidth + spacing)).floor(),
            )
            .clamp(1, cards.length);

        final double cardWidth =
            (maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(width: cardWidth, child: _buildCompactSummaryCard(card)),
          ],
        );
      },
    );
  }

  Widget _buildCompactSummaryCard(RaporOzetKarti card) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: card.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(card.icon, color: card.accentColor, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 28,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr(card.labelKey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 20,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      card.value,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.slate,
                      ),
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

  Widget _buildSummaryCards({
    required bool isMobile,
    required bool isTablet,
    bool compact = false,
    List<RaporOzetKarti>? cards,
  }) {
    final cardsSource =
        cards ?? _sonuc?.summaryCards ?? const <RaporOzetKarti>[];
    if (cardsSource.isEmpty) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return Row(
        children: [
          for (int index = 0; index < cardsSource.length; index++) ...[
            Expanded(
              child: Container(
                height: 72,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: _cardDecoration(),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: cardsSource[index].accentColor.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        cardsSource[index].icon,
                        color: cardsSource[index].accentColor,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 13,
                            child: FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                tr(cardsSource[index].labelKey),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 20,
                            child: FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                cardsSource[index].value,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.slate,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (index != cardsSource.length - 1) const SizedBox(width: 8),
          ],
        ],
      );
    }

    final double width = isMobile
        ? double.infinity
        : isTablet
        ? 210
        : 200;

    final rowChildren = cardsSource.map((card) {
      return Container(
        width: width,
        height: 94,
        margin: EdgeInsets.only(right: isMobile ? 0 : 12),
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: card.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(card.icon, color: card.accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(card.labelKey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 30,
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        card.value,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.slate,
                        ),
                      ),
                    ),
                  ),
                  if (card.subtitle != null && card.subtitle!.isNotEmpty)
                    Text(
                      card.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppPalette.grey,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();

    if (isMobile) {
      return Column(
        children: rowChildren
            .map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: child,
              ),
            )
            .toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: rowChildren),
    );
  }

  RaporOzetKarti _islemToplaminiOzetKartinaCevir(RaporIslemToplami toplam) {
    final style = _islemToplamKartiStili(toplam.islem);
    return RaporOzetKarti(
      labelKey: toplam.islem, // tr() fallback shows label as-is
      value: toplam.tutar,
      icon: style.icon,
      accentColor: style.accentColor,
    );
  }

  ({IconData icon, Color accentColor}) _islemToplamKartiStili(String islem) {
    final String low = islem.toLowerCase();

    if (low.contains('para al')) {
      return (
        icon: Icons.south_west_rounded,
        accentColor: const Color(0xFF27AE60),
      );
    }
    if (low.contains('para ver')) {
      return (icon: Icons.north_east_rounded, accentColor: AppPalette.red);
    }
    if (low.contains('satış') || low.contains('satis')) {
      return (icon: Icons.point_of_sale_rounded, accentColor: AppPalette.red);
    }
    if (low.contains('alış') || low.contains('alis')) {
      return (
        icon: Icons.shopping_cart_checkout_rounded,
        accentColor: AppPalette.amber,
      );
    }
    if (low.contains('tahsil')) {
      return (
        icon: Icons.payments_outlined,
        accentColor: const Color(0xFF27AE60),
      );
    }
    if (low.contains('ödeme') || low.contains('odeme')) {
      return (icon: Icons.payments_outlined, accentColor: AppPalette.red);
    }
    if (low.contains('alacak')) {
      return (
        icon: Icons.receipt_long_outlined,
        accentColor: const Color(0xFF27AE60),
      );
    }
    if (low.contains('borç') || low.contains('borc')) {
      return (icon: Icons.receipt_long_outlined, accentColor: AppPalette.red);
    }
    if (low.contains('çek') || low.contains('cek') || low.contains('senet')) {
      return (icon: Icons.receipt_long_rounded, accentColor: AppPalette.slate);
    }
    if (low.contains('açılış') ||
        low.contains('acilis') ||
        low.contains('devir') ||
        low.contains('transfer')) {
      return (icon: Icons.history_rounded, accentColor: AppPalette.slate);
    }

    return (icon: Icons.alt_route_rounded, accentColor: AppPalette.slate);
  }

  Widget _buildReportCard({
    required RaporSonucu? sonuc,
    required RaporSecenegi? rapor,
    required bool isMobile,
    required bool isTablet,
  }) {
    if (_raporYukleniyor && sonuc == null) {
      return const _RaporlarShimmer();
    }

    if (rapor == null || sonuc == null) {
      return _buildEmptyState(
        title: tr('reports.empty.title'),
        description: tr('reports.empty.description'),
      );
    }

    if (sonuc.isDisabled) {
      return _buildEmptyState(
        title: tr(rapor.labelKey),
        description: tr(sonuc.disabledReasonKey ?? 'reports.disabled.unknown'),
        icon: Icons.lock_outline_rounded,
      );
    }

    final visibleColumns = _gorunurKolonlar;
    if (visibleColumns.isEmpty) {
      return _buildEmptyState(
        title: tr('common.column_settings'),
        description: tr('reports.empty.no_visible_columns'),
        icon: Icons.view_column_outlined,
      );
    }

    final List<_TableColumnDefinition> tableColumns = [
      ...visibleColumns.map(
        (kolon) => _TableColumnDefinition(
          key: kolon.key,
          label: tr(kolon.labelKey),
          width: kolon.width,
          flex: isMobile || kolon.key == 'kur'
              ? null
              : () {
                  final baseFlex = _flexFromWidth(kolon.width);
                  if (rapor.id == 'all_movements' && kolon.key == 'aciklama') {
                    // All movements: "Açıklama" kolonunu biraz daralt,
                    // boşluğu diğer kolonlara dağıt (tasarımı bozmadan).
                    return math.max(2, (baseFlex * 0.6).round());
                  }
                  if (rapor.id == 'all_movements' && kolon.key == 'tarih') {
                    // Raporlar: Tarih kolonu biraz daralsın (diğer kolonlara alan kalsın).
                    return math.max(2, (baseFlex * 0.85).round());
                  }
                  if (rapor.id == 'all_movements' && kolon.key == 'yer') {
                    // Raporlar: Yer kolonu biraz daralsın.
                    return math.max(2, (baseFlex * 0.85).round());
                  }
                  if (rapor.id == 'all_movements' && kolon.key == 'yer_2') {
                    // Raporlar: (Kasa vb.) kısa değerler için ikinci Yer kolonu daha dar olsun.
                    return math.max(2, (baseFlex * 0.7).round());
                  }
                  return baseFlex;
                }(),
          alignment: kolon.alignment,
          allowSorting: kolon.allowSorting,
        ),
      ),
    ];

    final int? sortColumnIndex = _sortKey == null
        ? null
        : tableColumns.indexWhere((column) => column.key == _sortKey);
    final String expanderColumnKey = _resolveExpanderColumnKey(tableColumns);
    final Set<int> expandedIndices = _getEffectiveExpandedIndices(
      _sayfaSatirlari,
    );
    final bool hasExpandableRows = _sayfaSatirlari.any((row) => row.expandable);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: (!isMobile || _mobilFiltrelerAcik)
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                _buildFilterPanel(isMobile: isMobile, isTablet: isTablet),
                const SizedBox(height: 12),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
          if (_raporYukleniyor)
            const Expanded(child: _RaporTabloShimmer())
          else
            Expanded(
              child: GenisletilebilirTablo<RaporSatiri>(
                key: ValueKey('reports_table_${rapor.id}'),
                title: '',
                totalRecords: sonuc.totalCount,
                autofocusTable: false,
                paginationResetKey: _paginationRevision,
                searchFocusNode: _tableSearchFocusNode,
                headerWidget: const SizedBox.shrink(),
                headerPadding: const EdgeInsets.symmetric(horizontal: 12),
                rowPadding: const EdgeInsets.symmetric(vertical: 9),
                expandedContentPadding: const EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  24,
                ),
                headerTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5F6670),
                  letterSpacing: 0.18,
                ),
                headerMaxLines: 2,
                headerOverflow: TextOverflow.ellipsis,
                onSearch: _aramaDegisti,
                onPageChanged: (page, rowsPerPage) {
                  setState(() {
                    _mevcutSayfa = page;
                    _satirSayisi = rowsPerPage;
                    _selectedRowId = null;
                    _expandedRowIds.clear();
                    _autoExpandedRowIds.clear();
                  });
                  unawaited(_raporuYukle());
                },
                extraWidgets: [
                  if (hasExpandableRows) ...[
                    _buildIconToolbarButton(
                      tooltip: tr('warehouses.keep_details_open'),
                      icon: _keepDetailsOpen
                          ? Icons.unfold_less_rounded
                          : Icons.unfold_more_rounded,
                      onTap: _toggleKeepDetailsOpen,
                      active: _keepDetailsOpen,
                    ),
                    const SizedBox(width: 8),
                  ],
                  _buildIconToolbarButton(
                    tooltip: tr('common.column_settings'),
                    icon: Icons.view_column_outlined,
                    onTap: _showColumnVisibilityDialog,
                  ),
                ],
                actionButton: _buildTableActionRow(),
                columns: tableColumns
                    .map(
                      (column) => GenisletilebilirTabloKolon(
                        label: column.label,
                        width: column.width,
                        flex: column.flex,
                        alignment: column.alignment,
                        allowSorting: column.allowSorting,
                      ),
                    )
                    .toList(),
                cursorPagination: sonuc.cursorPagination,
                hasNextPage: sonuc.hasNextPage,
                data: _sayfaSatirlari,
                expandOnRowTap: false,
                deselectOnRepeatedRowTap: true,
                focusRowOnExpand: false,
                expandedIndices: expandedIndices,
                onExpansionChanged: _onRowExpansionChanged,
                onRowDoubleTap: _openSource,
                onFocusedRowChanged: (item, index) {
                  if (!mounted) return;
                  setState(() => _selectedRowId = item?.id);
                },
                onClearSelection: () {
                  if (!mounted) return;
                  setState(() => _selectedRowId = null);
                },
                getDetailItemCount: (row) => row.detailTable?.data.length ?? 0,
                onSort: (columnIndex, ascending) {
                  final key = tableColumns[columnIndex].key;
                  if (key.startsWith('_')) return;
                  _sortGuncelle(key, ascending);
                },
                sortColumnIndex: sortColumnIndex != -1 ? sortColumnIndex : null,
                sortAscending: _sortAscending,
                rowBuilder: (context, row, index, isExpanded, toggleExpand) {
                  return _buildTableRow(
                    row: row,
                    columns: tableColumns,
                    expanderColumnKey: expanderColumnKey,
                    isExpanded: isExpanded,
                    toggleExpand: toggleExpand,
                  );
                },
                detailBuilder: (context, row) => _buildRowDetail(row),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel({required bool isMobile, required bool isTablet}) {
    final rapor = _seciliRapor;
    if (rapor == null) {
      return const SizedBox.shrink();
    }

    _ensureTypeaheadLabelsLoaded();

    final List<
      ({
        Widget child,
        double desktopWidth,
        double tabletWidth,
        double mobileWidth,
        double minWidth,
      })
    >
    filterItems = [];

    void addFilter(
      Widget child, {
      required double desktopWidth,
      required double tabletWidth,
      double mobileWidth = double.infinity,
      double? minWidth,
    }) {
      filterItems.add((
        child: child,
        desktopWidth: desktopWidth,
        tabletWidth: tabletWidth,
        mobileWidth: mobileWidth.isFinite ? mobileWidth : tabletWidth,
        minWidth:
            minWidth ??
            math.min(desktopWidth, tabletWidth) * (isTablet ? 0.9 : 0.82),
      ));
    }

    Widget buildFilterRow(List<double> widths, {required bool scrollable}) {
      final row = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int index = 0; index < filterItems.length; index++) ...[
            SizedBox(width: widths[index], child: filterItems[index].child),
            if (index != filterItems.length - 1) const SizedBox(width: 14),
          ],
        ],
      );

      if (scrollable) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: row,
        );
      }

      return row;
    }

    List<double>? resolveResponsiveWidths(double maxWidth) {
      if (filterItems.isEmpty || maxWidth <= 0) return null;
      const double spacing = 14;
      final List<double> baseWidths = filterItems
          .map((item) => isTablet ? item.tabletWidth : item.desktopWidth)
          .toList();
      final List<double> minWidths = filterItems
          .map((item) => item.minWidth)
          .toList();

      final double spacingTotal = spacing * math.max(0, filterItems.length - 1);
      final double minTotal =
          minWidths.fold<double>(0, (sum, width) => sum + width) + spacingTotal;
      if (minTotal > maxWidth) {
        return null;
      }

      final double baseTotal =
          baseWidths.fold<double>(0, (sum, width) => sum + width) +
          spacingTotal;
      final double usableWidth = maxWidth - spacingTotal;
      final double baseWidthSum = baseWidths.fold<double>(
        0,
        (sum, width) => sum + width,
      );

      if (baseTotal <= maxWidth) {
        final double extraPerItem =
            (usableWidth - baseWidthSum) / filterItems.length;
        return baseWidths.map((width) => width + extraPerItem).toList();
      }

      final double minWidthSum = minWidths.fold<double>(
        0,
        (sum, width) => sum + width,
      );
      final bool prioritizeDateFilter =
          filterItems.length > 1 && _supports(RaporFiltreTuru.tarihAraligi);
      if (!prioritizeDateFilter) {
        final double ratio =
            ((usableWidth - minWidthSum) / (baseWidthSum - minWidthSum)).clamp(
              0.0,
              1.0,
            );

        return List<double>.generate(filterItems.length, (index) {
          return minWidths[index] +
              (baseWidths[index] - minWidths[index]) * ratio;
        });
      }

      // Tarih aralığı filtresinin (ilk filtre) tam görünmesi için önce onu büyüt,
      // kalan alanı diğer filtrelere orantılı dağıt.
      final List<double> widths = List<double>.from(minWidths);
      double remaining = usableWidth - minWidthSum;
      if (remaining <= 0) return widths;

      final double primaryCapacity = math.max(0, baseWidths[0] - minWidths[0]);
      final double primaryAdd = math.min(remaining, primaryCapacity);
      widths[0] += primaryAdd;
      remaining -= primaryAdd;
      if (remaining <= 0) return widths;

      double othersCapacity = 0;
      for (int i = 1; i < widths.length; i++) {
        othersCapacity += math.max(0, baseWidths[i] - minWidths[i]);
      }
      if (othersCapacity <= 0) return widths;

      final double ratio = (remaining / othersCapacity).clamp(0.0, 1.0);
      for (int i = 1; i < widths.length; i++) {
        widths[i] += math.max(0, baseWidths[i] - minWidths[i]) * ratio;
      }

      return widths;
    }

    if (rapor.id == 'all_movements' ||
        rapor.id == 'vat_accounting' ||
        rapor.id == 'purchase_sales_movements' ||
        rapor.id == 'product_movements' ||
        rapor.id == 'product_shipment_movements') {
      if (_supports(RaporFiltreTuru.tarihAraligi)) {
        addFilter(
          _buildQuickDateFilter(compact: true),
          desktopWidth: 480,
          tabletWidth: 450,
          mobileWidth: 450,
          minWidth: 320,
        );
      }

      final sonuc = _sonuc;
      final List<RaporIslemToplami> islemKaynak =
          sonuc != null && sonuc.report.id == rapor.id
          ? sonuc.islemToplamlari
          : const <RaporIslemToplami>[];

      if (_supports(RaporFiltreTuru.islemTuru)) {
        final Map<String, int> islemAdetleri = <String, int>{
          for (final item in islemKaynak) item.rawIslem: item.adet,
        };
        final int toplamIslemAdedi = islemKaynak.fold<int>(
          0,
          (sum, item) => sum + item.adet,
        );

        final List<DropdownMenuItem<String>> islemItems =
            <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: null,
                child: Text(tr('common.all'), overflow: TextOverflow.ellipsis),
              ),
              ...islemKaynak.map(
                (item) => DropdownMenuItem<String>(
                  value: item.rawIslem,
                  child: Text(item.islem, overflow: TextOverflow.ellipsis),
                ),
              ),
            ];

        final String? seciliIslem = _bosIseNull(_filtreler.islemTuru);
        if (seciliIslem != null &&
            !islemItems.any((item) => item.value == seciliIslem)) {
          islemItems.add(
            DropdownMenuItem<String>(
              value: seciliIslem,
              child: Text(seciliIslem, overflow: TextOverflow.ellipsis),
            ),
          );
        }

        addFilter(
          _buildDropdownField<String>(
            label: tr('common.operation'),
            icon: Icons.swap_horiz_rounded,
            value: _filtreler.islemTuru,
            items: islemItems,
            overlayLabelBuilder: (item) {
              final String baseLabel = _extractDropdownItemText(item.child);
              final String? value = item.value;
              if (value == null) {
                return '$baseLabel ($toplamIslemAdedi)';
              }
              final int? adet = islemAdetleri[value];
              return adet == null ? baseLabel : '$baseLabel ($adet)';
            },
            onChanged: (value) =>
                _secimGuncelle(islemTuru: value, clearIslemTuru: value == null),
          ),
          desktopWidth: 190,
          tabletWidth: 180,
          minWidth: 150,
        );
      }

      if (_supports(RaporFiltreTuru.urunGrubu)) {
        addFilter(
          _buildDropdownField<String>(
            label: tr('reports.filters.product_group'),
            icon: Icons.category_outlined,
            value: _filtreler.urunGrubu,
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: null,
                child: Text(tr('common.all'), overflow: TextOverflow.ellipsis),
              ),
              ..._filtreKaynaklari.urunGruplari.map(
                (item) => DropdownMenuItem<String>(
                  value: item.value,
                  child: Text(item.label, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) =>
                _secimGuncelle(urunGrubu: value, clearUrunGrubu: value == null),
          ),
          desktopWidth: 190,
          tabletWidth: 180,
          minWidth: 150,
        );
      }

      if (_supports(RaporFiltreTuru.durum)) {
        final kaynak = _filtreKaynaklari.durumlar[rapor.id] ?? const [];
        addFilter(
          _buildDropdownField<String>(
            label: tr('common.type'),
            icon: Icons.category_outlined,
            value: _filtreler.durum,
            items:
                (kaynak.isEmpty
                        ? <RaporSecimSecenegi>[
                            RaporSecimSecenegi(
                              value: tr('common.all'),
                              label: tr('common.all'),
                            ),
                          ]
                        : kaynak)
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.value == tr('common.all')
                            ? null
                            : item.value,
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (value) =>
                _secimGuncelle(durum: value, clearDurum: value == null),
          ),
          desktopWidth: 160,
          tabletWidth: 150,
          minWidth: 136,
        );
      }

      if (_supports(RaporFiltreTuru.belgeNo)) {
        addFilter(
          _buildDropdownField<String>(
            label: tr('reports.columns.document_exact'),
            icon: Icons.receipt_long_outlined,
            value: _filtreler.belgeNo,
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: null,
                child: Text(tr('common.all')),
              ),
              ...const <String>[
                'Fatura',
                'İrsaliye',
                'İrsaliyeli Fatura',
                '-',
              ].map(
                (value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) =>
                _secimGuncelle(belgeNo: value, clearBelgeNo: value == null),
          ),
          desktopWidth: 170,
          tabletWidth: 160,
          minWidth: 140,
        );
      }

      const String eBelgeVarSentinel = '__HAS_EBELGE__';
      if (_supports(RaporFiltreTuru.referansNo)) {
        addFilter(
          _buildDropdownField<String>(
            label: tr('reports.columns.e_document_exact'),
            icon: Icons.qr_code_2_outlined,
            value: _filtreler.referansNo,
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: null,
                child: Text(tr('common.all')),
              ),
              DropdownMenuItem<String>(
                value: eBelgeVarSentinel,
                child: Text(tr('common.exists')),
              ),
              DropdownMenuItem<String>(value: '-', child: const Text('-')),
            ],
            onChanged: (value) => _secimGuncelle(
              referansNo: value,
              clearReferansNo: value == null,
            ),
          ),
          desktopWidth: 170,
          tabletWidth: 160,
          minWidth: 140,
        );
      }

      if (_supports(RaporFiltreTuru.kullanici)) {
        addFilter(
          _buildDropdownField<String>(
            label: tr('common.user'),
            icon: Icons.person_rounded,
            value: _filtreler.kullaniciId,
            items: _filtreKaynaklari.kullanicilar
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.value,
                    child: Text(item.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) => _secimGuncelle(
              kullaniciId: value,
              clearKullanici: value == null,
            ),
          ),
          desktopWidth: 170,
          tabletWidth: 160,
          minWidth: 140,
        );
      }

      if (_supports(RaporFiltreTuru.minTutar)) {
        addFilter(
          _buildTextFilter(
            controller: _minTutarController,
            label: tr('reports.filters.min_amount'),
            icon: Icons.south_west_rounded,
            isNumber: true,
          ),
          desktopWidth: 150,
          tabletWidth: 145,
          minWidth: 125,
        );
      }

      if (_supports(RaporFiltreTuru.maxTutar)) {
        addFilter(
          _buildTextFilter(
            controller: _maxTutarController,
            label: tr('reports.filters.max_amount'),
            icon: Icons.north_east_rounded,
            isNumber: true,
          ),
          desktopWidth: 150,
          tabletWidth: 145,
          minWidth: 125,
        );
      }
    } else {
      [
        if (_supports(RaporFiltreTuru.tarihAraligi))
          addFilter(
            _buildQuickDateFilter(compact: true),
            desktopWidth: 480,
            tabletWidth: 450,
            mobileWidth: 450,
            minWidth: 320,
          ),
        if (_supports(RaporFiltreTuru.cari))
          addFilter(
            _buildTypeaheadField(
              label: tr('reports.filters.current_account'),
              icon: Icons.people_alt_outlined,
              valueLabel: _seciliCariLabel,
              loading: _cariLabelResolving,
              onTap: _cariSecimDialogAc,
              onClear: () {
                if (_filtreler.cariId == null) return;
                setState(() => _seciliCariLabel = null);
                _secimGuncelle(clearCari: true);
              },
            ),
            desktopWidth: 190,
            tabletWidth: 180,
            minWidth: 150,
          ),
        if (_supports(RaporFiltreTuru.hesapTuru))
          addFilter(
            _buildDropdownField<String>(
              label: tr('accounts.table.account_type'),
              icon: Icons.manage_accounts_outlined,
              value: _sanitizeHesapTuru(_filtreler.hesapTuru),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(tr('common.all')),
                ),
                DropdownMenuItem<String>(
                  value: 'Alıcı',
                  child: Text(
                    tr('accounts.type.buyer'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem<String>(
                  value: 'Satıcı',
                  child: Text(
                    tr('accounts.type.seller'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem<String>(
                  value: 'Alıcı/Satıcı',
                  child: Text(
                    tr('accounts.type.buyer_seller'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (value) => _secimGuncelle(
                hesapTuru: value,
                clearHesapTuru: value == null,
              ),
            ),
            desktopWidth: 180,
            tabletWidth: 170,
            minWidth: 145,
          ),
        if (_supports(RaporFiltreTuru.bakiyeDurumu))
          addFilter(
            _buildDropdownField<String>(
              label: tr('reports.filters.balance_status'),
              icon: Icons.balance_rounded,
              value: _filtreler.bakiyeDurumu,
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(tr('common.all')),
                ),
                DropdownMenuItem<String>(
                  value: 'borc',
                  child: Text(
                    tr('reports.filters.balance_debtors'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem<String>(
                  value: 'alacak',
                  child: Text(
                    tr('reports.filters.balance_creditors'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (value) => _secimGuncelle(
                bakiyeDurumu: value,
                clearBakiyeDurumu: value == null,
              ),
            ),
            desktopWidth: 160,
            tabletWidth: 150,
            minWidth: 136,
          ),
        if (_supports(RaporFiltreTuru.urun))
          addFilter(
            _buildTypeaheadField(
              label: tr('reports.filters.product'),
              icon: Icons.inventory_2_outlined,
              valueLabel: _seciliUrunLabel,
              loading: _urunLabelResolving,
              onTap: _urunSecimDialogAc,
              onClear: () {
                if (_filtreler.urunKodu == null) return;
                setState(() => _seciliUrunLabel = null);
                _secimGuncelle(clearUrun: true);
              },
            ),
            desktopWidth: 180,
            tabletWidth: 170,
            minWidth: 145,
          ),
        if (_supports(RaporFiltreTuru.urunGrubu))
          addFilter(
            _buildDropdownField<String>(
              label: tr('reports.filters.product_group'),
              icon: Icons.category_outlined,
              value: _filtreler.urunGrubu,
              items: <DropdownMenuItem<String>>[
                if (rapor.id == 'profit_loss')
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(tr('common.all')),
                  ),
                ..._filtreKaynaklari.urunGruplari.map(
                  (item) => DropdownMenuItem<String>(
                    value: item.value,
                    child: Text(item.label, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) => _secimGuncelle(
                urunGrubu: value,
                clearUrunGrubu: value == null,
              ),
            ),
            desktopWidth: 180,
            tabletWidth: 170,
            minWidth: 145,
          ),
        if (_supports(RaporFiltreTuru.kdvOrani))
          addFilter(
            _buildDropdownField<double>(
              label: tr('products.form.vat.label'),
              icon: Icons.percent_rounded,
              value: _filtreler.kdvOrani,
              items: <DropdownMenuItem<double>>[
                DropdownMenuItem<double>(
                  value: null,
                  child: Text(tr('common.all')),
                ),
                ..._filtreKaynaklari.kdvOranlari.map(
                  (rate) => DropdownMenuItem<double>(
                    value: rate,
                    child: Text(
                      '%${FormatYardimcisi.sayiFormatlaOran(rate, decimalDigits: 2)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) =>
                  _secimGuncelle(kdvOrani: value, clearKdvOrani: value == null),
            ),
            desktopWidth: 155,
            tabletWidth: 145,
            minWidth: 130,
          ),
        if (_supports(RaporFiltreTuru.depo))
          addFilter(
            _buildDropdownField<int>(
              label: tr('reports.filters.warehouse'),
              icon: Icons.warehouse_outlined,
              value: _filtreler.depoId,
              items: _filtreKaynaklari.depolar
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: int.tryParse(item.value),
                      child: Text(item.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  _secimGuncelle(depoId: value, clearDepo: value == null),
            ),
            desktopWidth: 170,
            tabletWidth: 160,
            minWidth: 140,
          ),
        if (_supports(RaporFiltreTuru.cikisDepo))
          addFilter(
            _buildDropdownField<int>(
              label: tr('warehouses.detail.source_warehouse'),
              icon: Icons.warehouse_outlined,
              value: _filtreler.cikisDepoId,
              items: _filtreKaynaklari.depolar
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: int.tryParse(item.value),
                      child: Text(item.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) => _secimGuncelle(
                cikisDepoId: value,
                clearCikisDepo: value == null,
              ),
            ),
            desktopWidth: 190,
            tabletWidth: 180,
            minWidth: 155,
          ),
        if (_supports(RaporFiltreTuru.girisDepo))
          addFilter(
            _buildDropdownField<int>(
              label: tr('warehouses.detail.target_warehouse'),
              icon: Icons.warehouse_outlined,
              value: _filtreler.girisDepoId,
              items: _filtreKaynaklari.depolar
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: int.tryParse(item.value),
                      child: Text(item.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) => _secimGuncelle(
                girisDepoId: value,
                clearGirisDepo: value == null,
              ),
            ),
            desktopWidth: 190,
            tabletWidth: 180,
            minWidth: 155,
          ),
        if (_supports(RaporFiltreTuru.islemTuru))
          addFilter(
            _buildDropdownField<String>(
              label: tr('common.transaction_type'),
              icon: Icons.swap_horiz_rounded,
              value: _filtreler.islemTuru,
              items: (_filtreKaynaklari.islemTurleri[rapor.id] ?? const [])
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.value == tr('common.all') ? null : item.value,
                      child: Text(item.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) => _secimGuncelle(
                islemTuru: value,
                clearIslemTuru: value == null,
              ),
            ),
            desktopWidth: 170,
            tabletWidth: 160,
            minWidth: 140,
          ),
        if (_supports(RaporFiltreTuru.durum))
          addFilter(
            _buildDropdownField<String>(
              label: tr('common.status'),
              icon: Icons.filter_list_rounded,
              value: _filtreler.durum,
              items: (_filtreKaynaklari.durumlar[rapor.id] ?? const [])
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.value == tr('common.all') ? null : item.value,
                      child: Text(item.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  _secimGuncelle(durum: value, clearDurum: value == null),
            ),
            desktopWidth: 160,
            tabletWidth: 150,
            minWidth: 136,
          ),
        if (_supports(RaporFiltreTuru.odemeYontemi))
          addFilter(
            _buildDropdownField<String>(
              label: tr('reports.filters.payment_method'),
              icon: Icons.payments_outlined,
              value: _filtreler.odemeYontemi,
              items: (_filtreKaynaklari.odemeYontemleri[rapor.id] ?? const [])
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.value == tr('common.all') ? null : item.value,
                      child: Text(item.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) => _secimGuncelle(
                odemeYontemi: value,
                clearOdemeYontemi: value == null,
              ),
            ),
            desktopWidth: 180,
            tabletWidth: 170,
            minWidth: 145,
          ),
        if (_supports(RaporFiltreTuru.kasa))
          addFilter(
            _buildDropdownField<int>(
              label: tr('reports.filters.cash'),
              icon: Icons.point_of_sale_outlined,
              value: _filtreler.kasaId,
              items: _filtreKaynaklari.kasalar
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: int.tryParse(item.value),
                      child: Text(item.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  _secimGuncelle(kasaId: value, clearKasa: value == null),
            ),
            desktopWidth: 170,
            tabletWidth: 160,
            minWidth: 140,
          ),
        if (_supports(RaporFiltreTuru.banka))
          addFilter(
            _buildDropdownField<int>(
              label: tr('reports.filters.bank'),
              icon: Icons.account_balance_outlined,
              value: _filtreler.bankaId,
              items: _filtreKaynaklari.bankalar
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: int.tryParse(item.value),
                      child: Text(item.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  _secimGuncelle(bankaId: value, clearBanka: value == null),
            ),
            desktopWidth: 170,
            tabletWidth: 160,
            minWidth: 140,
          ),
        if (_supports(RaporFiltreTuru.krediKarti))
          addFilter(
            _buildDropdownField<int>(
              label: tr('reports.filters.credit_card'),
              icon: Icons.credit_card_outlined,
              value: _filtreler.krediKartiId,
              items: _filtreKaynaklari.krediKartlari
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: int.tryParse(item.value),
                      child: Text(item.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) => _secimGuncelle(
                krediKartiId: value,
                clearKrediKarti: value == null,
              ),
            ),
            desktopWidth: 180,
            tabletWidth: 170,
            minWidth: 145,
          ),
        if (_supports(RaporFiltreTuru.kullanici))
          addFilter(
            _buildDropdownField<String>(
              label: tr('common.user'),
              icon: Icons.person_rounded,
              value: _filtreler.kullaniciId,
              items: _filtreKaynaklari.kullanicilar
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.value,
                      child: Text(item.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) => _secimGuncelle(
                kullaniciId: value,
                clearKullanici: value == null,
              ),
            ),
            desktopWidth: 170,
            tabletWidth: 160,
            minWidth: 140,
          ),
        if (_supports(RaporFiltreTuru.belgeNo))
          addFilter(
            _buildTextFilter(
              controller: _belgeNoController,
              label: tr('reports.filters.document_no'),
              icon: Icons.receipt_long_outlined,
            ),
            desktopWidth: 170,
            tabletWidth: 160,
            minWidth: 140,
          ),
        if (_supports(RaporFiltreTuru.referansNo))
          addFilter(
            _buildTextFilter(
              controller: _referansNoController,
              label: tr('reports.filters.reference_no'),
              icon: Icons.tag_outlined,
            ),
            desktopWidth: 170,
            tabletWidth: 160,
            minWidth: 140,
          ),
        if (_supports(RaporFiltreTuru.minTutar))
          addFilter(
            _buildTextFilter(
              controller: _minTutarController,
              label: tr('reports.filters.min_amount'),
              icon: Icons.south_west_rounded,
              isNumber: true,
            ),
            desktopWidth: 150,
            tabletWidth: 145,
            minWidth: 125,
          ),
        if (_supports(RaporFiltreTuru.maxTutar))
          addFilter(
            _buildTextFilter(
              controller: _maxTutarController,
              label: tr('reports.filters.max_amount'),
              icon: Icons.north_east_rounded,
              isNumber: true,
            ),
            desktopWidth: 150,
            tabletWidth: 145,
            minWidth: 125,
          ),
        if (_supports(RaporFiltreTuru.minMiktar))
          addFilter(
            _buildTextFilter(
              controller: _minMiktarController,
              label: tr('reports.filters.min_quantity'),
              icon: Icons.remove_rounded,
              isNumber: true,
            ),
            desktopWidth: 150,
            tabletWidth: 145,
            minWidth: 125,
          ),
        if (_supports(RaporFiltreTuru.maxMiktar))
          addFilter(
            _buildTextFilter(
              controller: _maxMiktarController,
              label: tr('reports.filters.max_quantity'),
              icon: Icons.add_rounded,
              isNumber: true,
            ),
            desktopWidth: 150,
            tabletWidth: 145,
            minWidth: 125,
          ),
      ];
    }

    if (filterItems.isEmpty) {
      return Text(
        tr('reports.empty.no_filters'),
        style: const TextStyle(color: AppPalette.grey),
      );
    }

    if (isMobile) {
      return buildFilterRow(
        filterItems.map((item) => item.mobileWidth).toList(),
        scrollable: true,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = resolveResponsiveWidths(constraints.maxWidth);
        if (widths == null) {
          return buildFilterRow(
            filterItems
                .map((item) => isTablet ? item.tabletWidth : item.desktopWidth)
                .toList(),
            scrollable: true,
          );
        }
        return buildFilterRow(widths, scrollable: false);
      },
    );
  }

  Widget _buildQuickDateFilter({bool compact = false}) {
    final items = <MapEntry<String, String>>[
      MapEntry('all', tr('common.all')),
      MapEntry('today', tr('reports.presets.today')),
      MapEntry('this_week', tr('reports.presets.this_week')),
      MapEntry('this_month', tr('reports.presets.this_month')),
      MapEntry('custom', tr('reports.presets.custom')),
    ];

    final String summaryText =
        _raporlarServisi.filtreOzetiniOlustur(_aktifFiltreler).isEmpty
        ? tr('common.all')
        : _raporlarServisi.filtreOzetiniOlustur(_aktifFiltreler);

    if (compact) {
      return Container(
        height: 46,
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              tr('common.date_range'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...items.map((item) {
                      final bool selected = _hizliTarihSecimi == item.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          mouseCursor: SystemMouseCursors.click,
                          onTap: () {
                            if (item.key == 'custom') {
                              _ozelTarihAraligiSec();
                              return;
                            }
                            _hizliTarihSeciminiUygula(item.key, yukle: true);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppPalette.slate
                                  : const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? AppPalette.slate
                                    : Colors.grey.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              item.value,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : AppPalette.slate,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_hizliTarihSecimi == 'custom' &&
                        summaryText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: Text(
                          summaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppPalette.grey,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('common.date_range'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppPalette.grey,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              final bool selected = _hizliTarihSecimi == item.key;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                mouseCursor: SystemMouseCursors.click,
                onTap: () {
                  if (item.key == 'custom') {
                    _ozelTarihAraligiSec();
                    return;
                  }
                  _hizliTarihSeciminiUygula(item.key, yukle: true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppPalette.slate
                        : const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? AppPalette.slate
                          : Colors.grey.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppPalette.slate,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            summaryText,
            style: const TextStyle(
              fontSize: 12,
              color: AppPalette.grey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeaheadField({
    required String label,
    required IconData icon,
    required String? valueLabel,
    required VoidCallback onTap,
    required VoidCallback onClear,
    bool loading = false,
  }) {
    final bool hasSelected = valueLabel != null && valueLabel.trim().isNotEmpty;
    final String text = hasSelected ? valueLabel : label;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        height: 46,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: hasSelected
                          ? AppPalette.slate
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                if (hasSelected)
                  IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(minWidth: 32),
                    splashRadius: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _closeFilterDropdownOverlay({required bool rebuild}) {
    _filterDropdownOverlayEntry?.remove();
    _filterDropdownOverlayEntry = null;
    if (rebuild && mounted) {
      setState(() => _filterDropdownExpandedKey = null);
    } else {
      _filterDropdownExpandedKey = null;
    }
  }

  String _extractDropdownItemText(Widget child) {
    if (child is Text) {
      final String text =
          child.data ??
          child.textSpan?.toPlainText(includeSemanticsLabels: true) ??
          '';
      return text.trim();
    }
    return child.toStringShort();
  }

  void _showFilterDropdownOverlay<T>({
    required String overlayKey,
    required LayerLink link,
    required double targetWidth,
    required T? currentValue,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String Function(DropdownMenuItem<T> item)? overlayLabelBuilder,
  }) {
    _closeFilterDropdownOverlay(rebuild: false);

    setState(() => _filterDropdownExpandedKey = overlayKey);

    final overlay = Overlay.of(context);
    final double width = math.max(targetWidth, 220);

    _filterDropdownOverlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _closeFilterDropdownOverlay(rebuild: true),
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),
            CompositedTransformFollower(
              link: link,
              showWhenUnlinked: false,
              offset: const Offset(0, 42),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                child: Container(
                  width: width,
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
                      children: items.map((item) {
                        final bool selected = item.value == currentValue;
                        final bool enabled = item.enabled;

                        final Color background = selected
                            ? const Color(0xFFE6F4EA)
                            : Colors.transparent;
                        final Color textColor = selected
                            ? const Color(0xFF1E7E34)
                            : (enabled ? Colors.black87 : Colors.grey.shade400);

                        final FontWeight weight = selected
                            ? FontWeight.bold
                            : FontWeight.w500;

                        final String label =
                            (overlayLabelBuilder?.call(item) ??
                                    _extractDropdownItemText(item.child))
                                .trim();

                        return InkWell(
                          mouseCursor: enabled
                              ? WidgetStateMouseCursor.clickable
                              : SystemMouseCursors.basic,
                          onTap: enabled
                              ? () {
                                  _closeFilterDropdownOverlay(rebuild: true);
                                  onChanged(item.value);
                                }
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            color: background,
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: weight,
                                color: textColor,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_filterDropdownOverlayEntry!);
  }

  Widget _buildDropdownField<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String Function(DropdownMenuItem<T> item)? overlayLabelBuilder,
  }) {
    final bool hasSelectedValue = value != null;
    final T? safeValue = items.any((item) => item.value == value)
        ? value
        : null;

    final String overlayKey = 'reports_filter_${icon.codePoint}_$label';
    final LayerLink link = _filterDropdownLayerLinks.putIfAbsent(
      overlayKey,
      () => LayerLink(),
    );
    final bool isExpanded = _filterDropdownExpandedKey == overlayKey;

    DropdownMenuItem<T>? selectedItem;
    // Null değer (genelde "Tümü") seçili olsa bile filter bar'da başlık
    // gösterilsin (Kullanıcı filtresi gibi).
    if (safeValue != null) {
      for (final item in items) {
        if (item.value == safeValue) {
          selectedItem = item;
          break;
        }
      }
    }

    final String displayText = selectedItem != null
        ? _extractDropdownItemText(selectedItem.child)
        : label;

    return Builder(
      builder: (fieldContext) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: CompositedTransformTarget(
            link: link,
            child: SizedBox(
              height: 46,
              child: InkWell(
                mouseCursor: WidgetStateMouseCursor.clickable,
                onTap: () {
                  if (isExpanded) {
                    _closeFilterDropdownOverlay(rebuild: true);
                    return;
                  }

                  final RenderBox? box =
                      fieldContext.findRenderObject() as RenderBox?;
                  final double width = box?.size.width ?? 220;

                  _showFilterDropdownOverlay<T>(
                    overlayKey: overlayKey,
                    link: link,
                    targetWidth: width,
                    currentValue: safeValue,
                    items: items,
                    onChanged: onChanged,
                    overlayLabelBuilder: overlayLabelBuilder,
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: EdgeInsets.fromLTRB(0, 6, 0, isExpanded ? 5 : 6),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isExpanded
                            ? const Color(0xFF2C3E50)
                            : Colors.grey.shade300,
                        width: isExpanded ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: isExpanded
                            ? const Color(0xFF2C3E50)
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          displayText,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isExpanded
                                ? const Color(0xFF2C3E50)
                                : (safeValue == null
                                      ? Colors.grey.shade700
                                      : AppPalette.slate),
                          ),
                        ),
                      ),
                      if (hasSelectedValue)
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          mouseCursor: WidgetStateMouseCursor.clickable,
                          onTap: () => onChanged(null),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: isExpanded
                              ? const Color(0xFF2C3E50)
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextFilter({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
  }) {
    return SizedBox(
      height: 46,
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: isNumber
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: label,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
                onChanged: (_) => _metinFiltreDegisti(),
                onSubmitted: (_) => _uygulaMetinFiltreleri(),
              ),
            ),
            if (controller.text.isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                mouseCursor: SystemMouseCursors.click,
                onTap: () {
                  controller.clear();
                  _metinFiltreDegisti();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableActionRow() {
    final bool disabled =
        (_sonuc?.isDisabled ?? false) || _aktarimSatirlari.isEmpty;
    final String reportId = _seciliRapor?.id ?? '';
    final bool showDocumentButton = reportId == 'all_movements';
    final String? selectedRowId = _selectedRowId;
    RaporSatiri? selectedRow;
    if (selectedRowId != null) {
      for (final row in _sayfaSatirlari) {
        if (row.id == selectedRowId) {
          selectedRow = row;
          break;
        }
      }
    }

    final bool hasSelection = selectedRow != null;
    final String printLabel = hasSelection
        ? tr('common.print_selected')
        : tr('common.print_list');
    final String integrationRef =
        selectedRow?.extra['integrationRef']?.toString().trim() ?? '';
    final bool documentEnabled =
        !disabled &&
        hasSelection &&
        integrationRef.isNotEmpty &&
        _isSaleIntegrationRef(integrationRef);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: YazdirmaErisimKontrolu.tooltip(printLabel),
          child: _buildActionButton(
            icon: Icons.print_outlined,
            label: printLabel,
            disabled:
                disabled || !YazdirmaErisimKontrolu.yazdirmaKullanilabilir,
            onTap: hasSelection ? _openSelectedPrintPreview : _openPrintPreview,
          ),
        ),
        if (showDocumentButton) ...[
          const SizedBox(width: 12),
          _buildDocumentActionButton(
            enabled: documentEnabled,
            onTap: () => unawaited(_openSelectedDocumentPrint()),
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentActionButton({
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onTap: enabled ? onTap : null,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF2C3E50) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? const Color(0xFF2C3E50) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 18,
              color: enabled ? Colors.white : Colors.grey.shade500,
            ),
            const SizedBox(width: 8),
            Text(
              tr('common.print_document'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: enabled ? Colors.white : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      mouseCursor: disabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onTap: disabled ? null : onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade100 : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: disabled ? Colors.grey.shade300 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: disabled ? Colors.grey.shade400 : AppPalette.slate,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: disabled ? Colors.grey.shade400 : AppPalette.slate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconToolbarButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: active
                ? AppPalette.slate.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? AppPalette.slate : Colors.grey.shade300,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: active ? AppPalette.slate : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  void _toggleKeepDetailsOpen() {
    setState(() {
      _keepDetailsOpen = !_keepDetailsOpen;
      if (!_keepDetailsOpen) {
        _expandedRowIds.clear();
      }
    });
  }

  void _onRowExpansionChanged(int index, bool isExpanded) {
    final rows = _sayfaSatirlari;
    if (index < 0 || index >= rows.length) return;
    final row = rows[index];
    if (!row.expandable) return;
    if (_keepDetailsOpen) return;

    setState(() {
      if (isExpanded) {
        _expandedRowIds
          ..clear()
          ..add(row.id);
      } else {
        _expandedRowIds.remove(row.id);
        _autoExpandedRowIds.remove(row.id);
      }
    });
  }

  Set<int> _getEffectiveExpandedIndices(List<RaporSatiri> rows) {
    final indices = <int>{};
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (!row.expandable) continue;
      if (_keepDetailsOpen ||
          _expandedRowIds.contains(row.id) ||
          _autoExpandedRowIds.contains(row.id)) {
        indices.add(i);
      }
    }
    return indices;
  }

  String _resolveExpanderColumnKey(List<_TableColumnDefinition> columns) {
    if (columns.any((c) => c.key == 'islem')) return 'islem';
    if (columns.isEmpty) return 'islem';
    return columns
        .firstWhere((c) => c.key != '_actions', orElse: () => columns.first)
        .key;
  }

  Widget _buildRowDetail(RaporSatiri row) {
    if (!row.expandable) return const SizedBox.shrink();

    final table = row.detailTable;
    if (table != null) {
      return _buildDetailTableCard(table);
    }

    final String integrationRef =
        row.extra['integrationRef']?.toString().trim() ?? '';
    if (integrationRef.isEmpty) return const SizedBox.shrink();

    final String aciklamaRaw = (row.cells['aciklama'] ?? '').trim();
    final String? aciklama = (aciklamaRaw.isEmpty || aciklamaRaw == '-')
        ? null
        : aciklamaRaw;

    final future = _integrationDetailFutures.putIfAbsent(
      integrationRef,
      () => _raporlarServisi.entegrasyonUrunDetayTablosuGetir(
        integrationRef,
        aciklama: aciklama,
      ),
    );

    return FutureBuilder<DetailTable?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              '${tr('common.error')}: ${snapshot.error}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }
        final table = snapshot.data;
        if (table == null || table.data.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              tr('common.no_data'),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }
        return _buildDetailTableCard(table);
      },
    );
  }

  Widget _buildDetailTableCard(DetailTable table) {
    final bool isProductDetail =
        table.headers.length == 8 &&
        table.headers[0] == tr('common.code_no') &&
        table.headers[1] == tr('shipment.field.name');

    final List<int> flexes = isProductDetail
        ? const <int>[2, 5, 2, 2, 3, 3, 3, 5]
        : List<int>.filled(table.headers.length, 3);

    Alignment cellAlignment(int index) {
      if (isProductDetail) {
        if (index == 3) return Alignment.center;
        if (index == 2 || index == 4 || index == 5 || index == 6) {
          return Alignment.centerRight;
        }
      }
      return Alignment.centerLeft;
    }

    final double minWidth = math.max(560, table.headers.length * 120.0);

    TextAlign cellTextAlign(int index) {
      final alignment = cellAlignment(index);
      if (alignment == Alignment.centerRight) return TextAlign.right;
      if (alignment == Alignment.center) return TextAlign.center;
      return TextAlign.left;
    }

    Widget buildHeaderRow() {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < table.headers.length; i++) ...[
              Expanded(
                flex: i < flexes.length ? flexes[i] : 3,
                child: Text(
                  table.headers[i],
                  textAlign: cellTextAlign(i),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              if (i != table.headers.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      );
    }

    Widget buildDataRow(List<String> values) {
      return Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < table.headers.length; i++) ...[
              Expanded(
                flex: i < flexes.length ? flexes[i] : 3,
                child: _buildHighlightedValue(
                  i < values.length ? values[i] : '-',
                  maxLines: 2,
                  textAlign: cellTextAlign(i),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == 1 ? FontWeight.bold : FontWeight.w600,
                    color: const Color(0xFF2C3E50),
                    height: 1.25,
                  ),
                ),
              ),
              if (i != table.headers.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      );
    }

    final String titleRaw = table.title.trim();
    // Raporlar'da genişleyen detayda "Son Hareketler" başlığı istenmiyor.
    final String title = titleRaw == tr('common.last_movements')
        ? ''
        : titleRaw;

    final EdgeInsetsGeometry outerPadding = EdgeInsets.fromLTRB(
      0,
      title.isEmpty ? 6 : 16,
      0,
      20,
    );

    return Padding(
      padding: outerPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          if (title.isNotEmpty) const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final double viewportWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : minWidth;
              final bool needsScroll = viewportWidth < minWidth;
              final double tableWidth = needsScroll ? minWidth : viewportWidth;

              final content = SizedBox(
                width: tableWidth,
                child: Column(
                  children: [
                    buildHeaderRow(),
                    for (final row in table.data) buildDataRow(row),
                  ],
                ),
              );

              if (!needsScroll) return content;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: content,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      mouseCursor: SystemMouseCursors.click,
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppPalette.slate),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppPalette.slate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow({
    required RaporSatiri row,
    required List<_TableColumnDefinition> columns,
    required String expanderColumnKey,
    required bool isExpanded,
    required VoidCallback toggleExpand,
  }) {
    return Row(
      children: columns.map((column) {
        Widget child;
        if (column.key == '_actions') {
          child = Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Tooltip(
                message: tr('common.go_to_related_page'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  mouseCursor: SystemMouseCursors.click,
                  onTap: () => _openSource(row),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6F8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: AppPalette.slate,
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          final bool showExpander = column.key == expanderColumnKey;
          child = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: column.alignment,
            child: showExpander
                ? (row.expandable
                      ? Row(
                          children: [
                            InkWell(
                              mouseCursor: WidgetStateMouseCursor.clickable,
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
                            Expanded(child: _buildValueCell(row, column.key)),
                          ],
                        )
                      : _buildValueCell(row, column.key))
                : _buildValueCell(row, column.key),
          );
        }

        if (column.flex != null) {
          return Expanded(flex: column.flex!, child: child);
        }
        return SizedBox(width: column.width, child: child);
      }).toList(),
    );
  }

  Widget _buildValueCell(RaporSatiri row, String key) {
    final String value = row.cells[key] ?? '-';
    if (key == 'islem') {
      return _buildProcessCell(row, value);
    }
    if (key == 'ozellik' &&
        (_sonuc?.report.id == 'profit_loss' ||
            _sonuc?.report.id == 'product_movements')) {
      return _buildFeatureBadgesCell(row, value);
    }
    if ((key == 'bakiye_borc' || key == 'bakiye_alacak') &&
        _sonuc?.report.id == 'balance_list') {
      return _buildAmountCell(row, key, value);
    }
    if (_badgeKeys.contains(key) && value != '-') {
      return _buildBadgeCell(key, value);
    }
    if (_descriptionKeys.contains(key)) {
      return _buildDescriptionCell(key, value);
    }
    if (_amountKeys.contains(key)) {
      return _buildAmountCell(row, key, value);
    }
    if (_quantityKeys.contains(key)) {
      return _buildQuantityCell(row, key, value);
    }
    if (_dateKeys.contains(key)) {
      return _buildHighlightedValue(
        value,
        style: const TextStyle(
          fontSize: 11,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: AppPalette.slate,
        ),
      );
    }
    if (_entityKeys.contains(key)) {
      final split = _trySplitCodeAndName(value);
      if (split != null) {
        return _buildCodeNameCell(code: split.code, name: split.name);
      }
      return _buildHighlightedValue(
        value,
        style: const TextStyle(
          fontSize: 11,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: AppPalette.slate,
        ),
      );
    }
    if (_secondaryTextKeys.contains(key)) {
      return _buildHighlightedValue(
        value,
        style: TextStyle(
          fontSize: 11,
          height: 1.35,
          fontWeight: key == 'kullanici' ? FontWeight.w600 : FontWeight.w500,
          color: key == 'kullanici'
              ? const Color(0xFF475467)
              : AppPalette.lightText,
        ),
      );
    }

    return _buildHighlightedValue(
      value,
      style: const TextStyle(
        fontSize: 11,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: AppPalette.slate,
      ),
    );
  }

  Widget _buildFeatureBadgesCell(RaporSatiri row, String value) {
    final dynamic raw = row.extra['features'];
    final List<({String name, Color? color})> features = [];

    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final String name = item['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final dynamic rawColor = item['color'];
        Color? color;
        if (rawColor is int) {
          color = Color(rawColor);
        } else if (rawColor is num) {
          color = Color(rawColor.toInt());
        } else if (rawColor is String) {
          final parsed = int.tryParse(rawColor);
          if (parsed != null) color = Color(parsed);
        }
        features.add((name: name, color: color));
        if (features.length >= 3) break;
      }
    }

    if (features.isEmpty) {
      return _buildHighlightedValue(
        value == '[]' || value.trim().isEmpty ? '-' : value,
        style: const TextStyle(
          fontSize: 11,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: AppPalette.slate,
        ),
      );
    }

    Widget badgeFor(({String name, Color? color}) feature) {
      final Color? color = feature.color;
      final Color background = color ?? Colors.grey.shade100;
      final Color borderColor = color != null
          ? color.withValues(alpha: 0.2)
          : Colors.grey.shade300;
      final Color textColor = color != null
          ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                ? Colors.white
                : Colors.black87)
          : Colors.black87;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: borderColor),
        ),
        child: HighlightText(
          text: feature.name,
          query: _arama,
          maxLines: 1,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
          highlightStyle: TextStyle(
            color: textColor,
            decoration: TextDecoration.underline,
            decorationColor: textColor,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < features.length; i++) ...[
          badgeFor(features[i]),
          if (i != features.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildProcessCell(RaporSatiri row, String value) {
    final bool incoming = _isIncomingLikeRow(row);
    final Color background = IslemTuruRenkleri.arkaplanRengiGetir(
      value,
      incoming,
    );
    final Color iconColor = IslemTuruRenkleri.ikonRengiGetir(value, incoming);
    final Color textColor = IslemTuruRenkleri.metinRengiGetir(value, incoming);

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            incoming
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            size: 14,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildHighlightedValue(
            value,
            style: TextStyle(
              fontSize: 11,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeCell(String key, String value) {
    final Color badgeColor = _badgeColor(value);
    final bool statusLike = key == 'durum';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: statusLike ? 8 : 7,
        vertical: statusLike ? 5 : 4,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(statusLike ? 999 : 8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statusLike) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCell(String key, String value) {
    return _buildHighlightedValue(
      value,
      style: TextStyle(
        fontSize: 11,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade600,
      ),
    );
  }

  Widget _buildAmountCell(RaporSatiri row, String key, String value) {
    final Color color = _amountColor(row, key, value);
    return _buildHighlightedValue(
      value,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 11,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }

  Widget _buildQuantityCell(RaporSatiri row, String key, String value) {
    final Color color;
    if (key == 'giris') {
      color = const Color(0xFF2E7D32);
    } else if (key == 'cikis') {
      color = const Color(0xFFC62828);
    } else if (key == 'miktar' && !_isIncomingLikeRow(row) && value != '-') {
      color = const Color(0xFFC62828);
    } else {
      color = AppPalette.slate;
    }

    return _buildHighlightedValue(
      value,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 11,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }

  Widget _buildCodeNameCell({required String code, required String name}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildHighlightedValue(
          name,
          style: const TextStyle(
            fontSize: 11,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: AppPalette.slate,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: _buildHighlightedValue(
            code,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: AppPalette.lightText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightedValue(
    String value, {
    required TextStyle style,
    int? maxLines,
    TextAlign textAlign = TextAlign.left,
  }) {
    return HighlightText(
      text: value,
      query: _arama,
      maxLines: maxLines,
      textAlign: textAlign,
      style: style,
    );
  }

  ({String code, String name})? _trySplitCodeAndName(String value) {
    if (value == '-' || !value.contains(' - ')) return null;
    final parts = value.split(' - ');
    if (parts.length < 2) return null;
    final code = parts.first.trim();
    final name = parts.sublist(1).join(' - ').trim();
    if (code.isEmpty ||
        name.isEmpty ||
        code.contains(' ') ||
        code.length > 18) {
      return null;
    }
    return (code: code, name: name);
  }

  bool _isIncomingLikeRow(RaporSatiri row) {
    return _resolveRowDirection(row) ?? true;
  }

  bool? _resolveRowDirection(RaporSatiri row) {
    final dynamic explicitDirection = row.extra['isIncoming'];
    if (explicitDirection is bool) {
      return explicitDirection;
    }

    bool hasValue(String key) {
      final value = row.cells[key]?.trim();
      return value != null && value.isNotEmpty && value != '-';
    }

    if (hasValue('giris') || hasValue('alacak')) {
      return true;
    }
    if (hasValue('cikis') || hasValue('borc')) {
      return false;
    }

    final status = (row.cells['durum'] ?? '').toLowerCase();
    if (status.contains('alacak') ||
        status.contains('credit') ||
        status.contains('receivable') ||
        status.contains('tahsil')) {
      return true;
    }
    if (status.contains('borç') ||
        status.contains('borc') ||
        status.contains('debit') ||
        status.contains('payable') ||
        status.contains('ödeme') ||
        status.contains('odeme')) {
      return false;
    }

    if (row.sourceMenuIndex == 100) {
      return false;
    }

    final String rawText = [
      row.sortValues['islem']?.toString(),
      row.cells['islem'],
      row.cells['son_islem_turu'],
      row.cells['tur'],
      row.cells['odeme_tipi'],
    ].whereType<String>().join(' ').toLowerCase();

    if (rawText.isNotEmpty) {
      if (row.sourceMenuIndex == TabAciciScope.cariKartiIndex) {
        if (rawText.contains('satış yapıldı') ||
            rawText.contains('satis yapildi') ||
            rawText.contains('para verildi') ||
            rawText.contains('ödeme') ||
            rawText.contains('odeme') ||
            rawText.contains('borç') ||
            rawText.contains('borc') ||
            rawText.contains('çek verildi') ||
            rawText.contains('cek verildi') ||
            rawText.contains('senet verildi')) {
          return false;
        }
        if (rawText.contains('alış yapıldı') ||
            rawText.contains('alis yapildi') ||
            rawText.contains('para alındı') ||
            rawText.contains('para alindi') ||
            rawText.contains('tahsilat') ||
            rawText.contains('alacak') ||
            rawText.contains('çek alındı') ||
            rawText.contains('cek alindi') ||
            rawText.contains('senet alındı') ||
            rawText.contains('senet alindi')) {
          return true;
        }
      } else if (row.sourceMenuIndex == 13 ||
          row.sourceMenuIndex == 15 ||
          row.sourceMenuIndex == 16) {
        if (rawText.contains('satış yapıldı') ||
            rawText.contains('satis yapildi') ||
            rawText.contains('para alındı') ||
            rawText.contains('para alindi') ||
            rawText.contains('tahsilat') ||
            rawText.contains('giriş') ||
            rawText.contains('giris') ||
            rawText.contains('çek alındı') ||
            rawText.contains('cek alindi') ||
            rawText.contains('senet alındı') ||
            rawText.contains('senet alindi')) {
          return true;
        }
        if (rawText.contains('alış yapıldı') ||
            rawText.contains('alis yapildi') ||
            rawText.contains('para verildi') ||
            rawText.contains('ödeme') ||
            rawText.contains('odeme') ||
            rawText.contains('çıkış') ||
            rawText.contains('cikis') ||
            rawText.contains('çıktı') ||
            rawText.contains('cikti') ||
            rawText.contains('çek verildi') ||
            rawText.contains('cek verildi') ||
            rawText.contains('senet verildi') ||
            rawText.contains('personel ödemesi')) {
          return false;
        }
      }

      if (rawText.contains('alınan') ||
          rawText.contains('alinan') ||
          rawText.contains('receivable') ||
          rawText.contains('credit') ||
          rawText.contains('alacak') ||
          rawText.contains('tahsil')) {
        return true;
      }
      if (rawText.contains('verilen') ||
          rawText.contains('gider') ||
          rawText.contains('payable') ||
          rawText.contains('debit') ||
          rawText.contains('borç') ||
          rawText.contains('borc') ||
          rawText.contains('ödeme') ||
          rawText.contains('odeme')) {
        return false;
      }
    }

    final amount = row.amountValue;
    if (amount != null && amount < 0) {
      return false;
    }
    return null;
  }

  Color _amountColor(RaporSatiri row, String key, String value) {
    if (value == '-') return AppPalette.lightText;
    if (key == 'alacak') return const Color(0xFF2E7D32);
    if (key == 'borc') return const Color(0xFFC62828);
    if (key == 'bakiye_alacak') return const Color(0xFF2E7D32);
    if (key == 'bakiye_borc') return const Color(0xFFC62828);
    if (key == 'net_bakiye' ||
        key == 'net_kar' ||
        key == 'brut_kar' ||
        key == 'tutar_etkisi' ||
        key == 'fark') {
      if (row.amountValue != null && row.amountValue! < 0) {
        return const Color(0xFFC62828);
      }
      if (row.amountValue != null && row.amountValue! > 0) {
        return const Color(0xFF2E7D32);
      }
      return AppPalette.slate;
    }
    if (key == 'tutar' ||
        key == 'ara_toplam' ||
        key == 'genel_toplam' ||
        key == 'maliyet') {
      final bool? incoming = _resolveRowDirection(row);
      if (incoming == true) {
        return const Color(0xFF2E7D32);
      }
      if (incoming == false) {
        return const Color(0xFFC62828);
      }
      if (row.amountValue != null && row.amountValue! < 0) {
        return const Color(0xFFC62828);
      }
    }
    return AppPalette.slate;
  }

  Widget _buildEmptyState({
    required String title,
    required String description,
    IconData icon = Icons.assessment_outlined,
  }) {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppPalette.slate.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, size: 34, color: AppPalette.slate),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.slate,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppPalette.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppPalette.grey.withValues(alpha: 0.15)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  int _flexFromWidth(double width, {int minFlex = 2}) {
    final int flex = (width / 36).ceil();
    return flex < minFlex ? minFlex : flex;
  }

  IconData _kategoriIcon(RaporKategori kategori) {
    switch (kategori) {
      case RaporKategori.genel:
        return Icons.grid_view_rounded;
      case RaporKategori.satisAlis:
        return Icons.point_of_sale_rounded;
      case RaporKategori.siparisTeklif:
        return Icons.assignment_rounded;
      case RaporKategori.stokDepo:
        return Icons.inventory_2_rounded;
      case RaporKategori.uretim:
        return Icons.precision_manufacturing_rounded;
      case RaporKategori.cari:
        return Icons.account_balance_wallet_rounded;
      case RaporKategori.finans:
        return Icons.account_balance_rounded;
      case RaporKategori.cekSenet:
        return Icons.receipt_long_rounded;
      case RaporKategori.gider:
        return Icons.money_off_rounded;
      case RaporKategori.kullanici:
        return Icons.people_alt_rounded;
    }
  }

  Color _accentColorForCategory(RaporKategori kategori) {
    switch (kategori) {
      case RaporKategori.genel:
        return AppPalette.slate;
      case RaporKategori.satisAlis:
        return AppPalette.red;
      case RaporKategori.siparisTeklif:
        return const Color(0xFF1E5F74);
      case RaporKategori.stokDepo:
        return const Color(0xFF8E44AD);
      case RaporKategori.uretim:
        return AppPalette.amber;
      case RaporKategori.cari:
        return const Color(0xFF16A085);
      case RaporKategori.finans:
        return const Color(0xFF2D89EF);
      case RaporKategori.cekSenet:
        return const Color(0xFFD35400);
      case RaporKategori.gider:
        return AppPalette.red;
      case RaporKategori.kullanici:
        return const Color(0xFF34495E);
    }
  }

  Color _badgeColor(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('aktif') ||
        lower.contains('credit') ||
        lower.contains('receivable') ||
        lower.contains('tahsil')) {
      return const Color(0xFF27AE60);
    }
    if (lower.contains('pasif') ||
        lower.contains('payable') ||
        lower.contains('debit') ||
        lower.contains('ödeme') ||
        lower.contains('odeme')) {
      return AppPalette.red;
    }
    if (lower.contains('çek') ||
        lower.contains('cek') ||
        lower.contains('senet') ||
        lower.contains('banka')) {
      return AppPalette.amber;
    }
    return AppPalette.slate;
  }
}

class _TableColumnDefinition {
  const _TableColumnDefinition({
    required this.key,
    this.label = '',
    required this.width,
    this.flex,
    this.alignment = Alignment.centerLeft,
    this.allowSorting = true,
  });

  final String key;
  final String label;
  final double width;
  final int? flex;
  final Alignment alignment;
  final bool allowSorting;
}

class _RaporlarShimmer extends StatelessWidget {
  const _RaporlarShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaporTabloShimmer extends StatelessWidget {
  const _RaporTabloShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Column(
        children: [
          Container(
            height: 124,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
