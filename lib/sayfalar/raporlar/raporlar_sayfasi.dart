import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../bilesenler/genisletilebilir_tablo.dart';
import '../../bilesenler/tab_acici_scope.dart';
import '../../bilesenler/tarih_araligi_secici_dialog.dart';
import '../../sayfalar/ortak/genisletilebilir_print_preview_screen.dart';
import '../../temalar/app_theme.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../yardimcilar/yazdirma/yazdirma_erisim_kontrolu.dart';
import '../carihesaplar/modeller/cari_hesap_model.dart';
import '../urunler_ve_depolar/urunler/modeller/urun_model.dart';
import 'modeller/rapor_modelleri.dart';
import 'servisler/raporlar_servisi.dart';

class RaporlarSayfasi extends StatefulWidget {
  const RaporlarSayfasi({super.key});

  @override
  State<RaporlarSayfasi> createState() => _RaporlarSayfasiState();
}

class _RaporlarSayfasiState extends State<RaporlarSayfasi> {
  final RaporlarServisi _raporlarServisi = RaporlarServisi();

  final TextEditingController _belgeNoController = TextEditingController();
  final TextEditingController _referansNoController = TextEditingController();
  final TextEditingController _minTutarController = TextEditingController();
  final TextEditingController _maxTutarController = TextEditingController();
  final TextEditingController _minMiktarController = TextEditingController();
  final TextEditingController _maxMiktarController = TextEditingController();

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

  String _arama = '';
  int _mevcutSayfa = 1;
  int _satirSayisi = 25;
  int _paginationRevision = 0;
  bool _sortAscending = true;
  String? _sortKey;
  String _hizliTarihSecimi = 'this_month';
  Timer? _metinFiltreDebounce;

  final Map<String, Map<String, bool>> _kolonGorunurluklari =
      <String, Map<String, bool>>{};

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
    _metinFiltreDebounce?.cancel();
    _belgeNoController.dispose();
    _referansNoController.dispose();
    _minTutarController.dispose();
    _maxTutarController.dispose();
    _minMiktarController.dispose();
    _maxMiktarController.dispose();
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

  Future<void> _raporuYukle() async {
    final rapor = _seciliRapor;
    if (rapor == null) return;

    setState(() {
      _raporYukleniyor = true;
      _aktifFiltreler = _aktifFiltreleriOlustur();
    });

    try {
      final sonuc = await _raporlarServisi.raporuGetir(
        rapor: rapor,
        filtreler: _aktifFiltreler,
        arama: '',
        sortKey: null,
        sortAscending: true,
      );

      if (!mounted) return;
      setState(() {
        _sonuc = sonuc;
        _raporYukleniyor = false;
        _mevcutSayfa = 1;
        _paginationRevision++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _raporYukleniyor = false);
      MesajYardimcisi.hataGoster(
        context,
        tr('reports.messages.load_failed').replaceAll('{error}', e.toString()),
      );
    }
  }

  RaporFiltreleri _aktifFiltreleriOlustur() {
    final rapor = _seciliRapor;
    if (rapor == null) return RaporFiltreleri.empty;

    bool destekler(RaporFiltreTuru tur) => rapor.supportedFilters.contains(tur);

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
      depoId: destekler(RaporFiltreTuru.depo) ? _filtreler.depoId : null,
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
          ? _bosIseNull(_belgeNoController.text)
          : null,
      referansNo: destekler(RaporFiltreTuru.referansNo)
          ? _bosIseNull(_referansNoController.text)
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
    if (_kolonGorunurluklari.containsKey(rapor.id)) return;
    final mevcutSonuc = _sonuc;
    final kaynakKolonlar = mevcutSonuc?.report.id == rapor.id
        ? mevcutSonuc!.columns
        : const <RaporKolonTanimi>[];
    final Map<String, bool> visibility = <String, bool>{};
    for (final kolon in kaynakKolonlar) {
      visibility[kolon.key] = kolon.visibleByDefault;
    }
    _kolonGorunurluklari[rapor.id] = visibility;
  }

  List<RaporSecenegi> get _kategoriRaporlari =>
      _tumRaporlar.where((rapor) => rapor.category == _seciliKategori).toList();

  List<RaporSatiri> get _islenmisSatirlar {
    final rows = [...(_sonuc?.rows ?? const <RaporSatiri>[])];
    final arama = _arama.trim().toLowerCase();
    Iterable<RaporSatiri> sonucRows = rows;

    if (arama.isNotEmpty) {
      sonucRows = sonucRows.where((row) {
        final birlesik = [
          ...row.cells.values,
          ...row.details.keys,
          ...row.details.values,
        ].join(' ').toLowerCase();
        return birlesik.contains(arama);
      });
    }

    final list = sonucRows.toList();
    if (_sortKey == null || _sortKey!.isEmpty) {
      return list;
    }

    list.sort((a, b) {
      final dynamic av = a.sortValues[_sortKey] ?? a.cells[_sortKey] ?? '';
      final dynamic bv = b.sortValues[_sortKey] ?? b.cells[_sortKey] ?? '';
      return _sortAscending ? _compareDynamic(av, bv) : _compareDynamic(bv, av);
    });
    return list;
  }

  int _compareDynamic(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is DateTime && b is DateTime) return a.compareTo(b);
    if (a is num && b is num) return a.compareTo(b);
    return a.toString().toLowerCase().compareTo(b.toString().toLowerCase());
  }

  List<RaporKolonTanimi> get _gorunurKolonlar {
    final sonuc = _sonuc;
    if (sonuc == null) return const <RaporKolonTanimi>[];
    final raporId = sonuc.report.id;
    final visibility =
        _kolonGorunurluklari[raporId] ??
        {for (final kolon in sonuc.columns) kolon.key: kolon.visibleByDefault};
    return sonuc.columns
        .where((kolon) => visibility[kolon.key] ?? true)
        .toList();
  }

  List<RaporSatiri> get _sayfaSatirlari {
    final all = _islenmisSatirlar;
    final int start = (_mevcutSayfa - 1) * _satirSayisi;
    if (start >= all.length) {
      return const <RaporSatiri>[];
    }
    final int end = (start + _satirSayisi).clamp(0, all.length);
    return all.sublist(start, end);
  }

  List<RaporSatiri> get _aktarimSatirlari {
    return _islenmisSatirlar;
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
      _sortAscending = true;
      _arama = '';
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
      _sortAscending = true;
      _arama = '';
      _kolonDurumunuHazirla();
    });
    _raporuYukle();
  }

  void _filtreleriTemizle() {
    _metinFiltreDebounce?.cancel();
    _belgeNoController.clear();
    _referansNoController.clear();
    _minTutarController.clear();
    _maxTutarController.clear();
    _minMiktarController.clear();
    _maxMiktarController.clear();
    _hizliTarihSecimi = 'this_month';
    _filtreler = RaporFiltreleri.empty;
    _hizliTarihSeciminiUygula(_hizliTarihSecimi, yukle: true);
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
    });
    _raporuYukle();
  }

  void _secimGuncelle({
    int? cariId,
    String? urunKodu,
    String? urunGrubu,
    int? depoId,
    String? islemTuru,
    String? durum,
    String? odemeYontemi,
    int? kasaId,
    int? bankaId,
    int? krediKartiId,
    String? kullaniciId,
    bool clearCari = false,
    bool clearUrun = false,
    bool clearUrunGrubu = false,
    bool clearDepo = false,
    bool clearIslemTuru = false,
    bool clearDurum = false,
    bool clearOdemeYontemi = false,
    bool clearKasa = false,
    bool clearBanka = false,
    bool clearKrediKarti = false,
    bool clearKullanici = false,
  }) {
    setState(() {
      _filtreler = _filtreler.copyWith(
        cariId: cariId,
        urunKodu: urunKodu,
        urunGrubu: urunGrubu,
        depoId: depoId,
        islemTuru: islemTuru,
        durum: durum,
        odemeYontemi: odemeYontemi,
        kasaId: kasaId,
        bankaId: bankaId,
        krediKartiId: krediKartiId,
        kullaniciId: kullaniciId,
        clearCari: clearCari,
        clearUrun: clearUrun,
        clearUrunGrubu: clearUrunGrubu,
        clearDepo: clearDepo,
        clearIslemTuru: clearIslemTuru,
        clearDurum: clearDurum,
        clearOdemeYontemi: clearOdemeYontemi,
        clearKasa: clearKasa,
        clearBanka: clearBanka,
        clearKrediKarti: clearKrediKarti,
        clearKullanici: clearKullanici,
      );
    });
    _raporuYukle();
  }

  void _uygulaMetinFiltreleri() {
    _metinFiltreDebounce?.cancel();
    _raporuYukle();
  }

  void _metinFiltreDegisti() {
    _metinFiltreDebounce?.cancel();
    setState(() {});
    _metinFiltreDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      _raporuYukle();
    });
  }

  void _aramaDegisti(String value) {
    setState(() {
      _arama = value;
      _mevcutSayfa = 1;
      _paginationRevision++;
    });
  }

  void _sortGuncelle(String key, bool ascending) {
    setState(() {
      _sortKey = key;
      _sortAscending = ascending;
      _mevcutSayfa = 1;
      _paginationRevision++;
    });
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

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool allSelected = sonuc.columns.every(
              (kolon) => localVisibility[kolon.key] ?? true,
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
                              onTap: () {
                                setDialogState(() {
                                  localVisibility[kolon.key] =
                                      !(localVisibility[kolon.key] ?? true);
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
                                      value: localVisibility[kolon.key] ?? true,
                                      activeColor: AppPalette.slate,
                                      onChanged: (value) {
                                        setDialogState(() {
                                          localVisibility[kolon.key] =
                                              value ?? true;
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: Text(
                                        tr(kolon.labelKey),
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
                  onPressed: () {
                    setState(() {
                      _kolonGorunurluklari[rapor.id] = localVisibility;
                    });
                    Navigator.pop(context);
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
    final sonuc = _sonuc;
    final rapor = _seciliRapor;
    if (sonuc == null || rapor == null || sonuc.isDisabled) return;
    final rows = _aktarimSatirlari;
    if (rows.isEmpty) {
      MesajYardimcisi.bilgiGoster(context, tr('common.no_data'));
      return;
    }

    final visibleColumns = _gorunurKolonlar;
    final printRows = _raporlarServisi.yazdirmaSatirlariniHazirla(
      rows: rows,
      visibleColumns: visibleColumns,
      expandedIds: const <String>{},
      keepDetailsOpen: false,
    );

    final headerInfo = <String, dynamic>{
      tr('reports.columns.report_name'): tr(rapor.labelKey),
      tr(
        'common.date_range',
      ): _raporlarServisi.filtreOzetiniOlustur(_aktifFiltreler).isEmpty
          ? tr('common.all')
          : _raporlarServisi.filtreOzetiniOlustur(_aktifFiltreler),
      tr('reports.summary.record'): rows.length.toString(),
    };

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => GenisletilebilirPrintPreviewScreen(
          title: tr(rapor.labelKey),
          headers: visibleColumns.map((col) => tr(col.labelKey)).toList(),
          data: printRows,
          dateInterval: _raporlarServisi.filtreOzetiniOlustur(_aktifFiltreler),
          initialShowDetails: false,
          headerInfo: headerInfo,
          mainTableLabel: sonuc.mainTableLabel,
          detailTableLabel: sonuc.detailTableLabel,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 1200;
        final bool isTablet = constraints.maxWidth >= 800 && !isDesktop;
        final bool isMobile = !isDesktop && !isTablet;

        return Container(
          color: const Color(0xFFF6F7F9),
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: _buildWorkspace(
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
          ),
        );
      },
    );
  }

  Widget _buildWorkspace({
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    final sonuc = _sonuc;
    final rapor = _seciliRapor;
    final List<RaporSatiri> processedRows = _islenmisSatirlar;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double viewportHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (isMobile ? 900 : 820);
        final double reportCardHeight = isMobile
            ? math.max(900, viewportHeight * 0.9)
            : isTablet
            ? math.max(820, viewportHeight * 0.84)
            : math.max(780, viewportHeight * 0.84);

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewportHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageHeader(isMobile: isMobile),
                const SizedBox(height: 12),
                _buildSelectorSummaryBand(
                  isTablet: isTablet,
                  isMobile: isMobile,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: reportCardHeight,
                  child: _buildReportCard(
                    sonuc: sonuc,
                    rapor: rapor,
                    processedRows: processedRows,
                    isMobile: isMobile,
                    isTablet: isTablet,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageHeader({required bool isMobile}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: _cardDecoration(),
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
            ),
          ),
          const SizedBox(width: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeaderCategorySelect(isMobile: isMobile),
              _buildHeaderButton(
                label: tr('reports.actions.refresh'),
                icon: Icons.refresh_rounded,
                onTap: _raporuYukle,
              ),
              _buildHeaderButton(
                label: tr('reports.actions.clear_filters'),
                icon: Icons.filter_alt_off_outlined,
                onTap: _filtreleriTemizle,
              ),
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
    return Container(
      constraints: BoxConstraints(
        minWidth: isMobile ? 180 : 220,
        maxWidth: isMobile ? 240 : 290,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.grey.withValues(alpha: 0.18)),
      ),
      child: PopupMenuButton<RaporKategori>(
        tooltip: tr('reports.sections.categories'),
        initialValue: kategori,
        onSelected: _kategoriSec,
        offset: const Offset(0, 42),
        itemBuilder: (context) {
          return RaporKategori.values.map((item) {
            final bool secili = item == kategori;
            return PopupMenuItem<RaporKategori>(
              value: item,
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
          }).toList();
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: Colors.white,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _accentColorForCategory(
                    kategori,
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  _kategoriIcon(kategori),
                  size: 16,
                  color: _accentColorForCategory(kategori),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('reports.sections.categories'),
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
                      tr(kategori.labelKey),
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
    );
  }

  Widget _buildSelectorSummaryBand({
    required bool isTablet,
    required bool isMobile,
  }) {
    final cards = _sonuc?.summaryCards ?? const <RaporOzetKarti>[];
    if (isMobile || cards.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportSelector(isTablet: isTablet, isMobile: isMobile),
          if (cards.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildSummaryCards(isMobile: isMobile, isTablet: isTablet),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildReportSelector(isTablet: isTablet, isMobile: isMobile),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: isTablet ? 230 : 280,
          child: _buildSummaryCards(
            isMobile: false,
            isTablet: isTablet,
            compact: true,
          ),
        ),
      ],
    );
  }

  Widget _buildReportSelector({
    required bool isTablet,
    required bool isMobile,
  }) {
    final double tileWidth = isMobile ? 220 : 0;
    final List<Widget> compactTiles = isMobile
        ? const <Widget>[]
        : _buildReportTypeTiles(tileWidth: tileWidth, compact: true);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tr('reports.sections.report_types'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.slate,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_kategoriRaporlari.length} ${tr('reports.summary.record')}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isMobile)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _buildReportTypeTiles(tileWidth: tileWidth)),
            )
          else
            Row(
              children: [
                for (int index = 0; index < compactTiles.length; index++) ...[
                  Expanded(child: compactTiles[index]),
                  if (index != compactTiles.length - 1)
                    const SizedBox(width: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _buildReportTypeTiles({
    required double tileWidth,
    bool compact = false,
  }) {
    return _kategoriRaporlari.map((rapor) {
      final bool selected = _seciliRapor?.id == rapor.id;
      final bool disabled = !rapor.supported;
      return Tooltip(
        message: disabled
            ? tr(rapor.disabledReasonKey ?? 'reports.disabled.unknown')
            : tr(rapor.labelKey),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (disabled) {
              MesajYardimcisi.uyariGoster(
                context,
                tr(rapor.disabledReasonKey ?? 'reports.disabled.unknown'),
              );
              return;
            }
            _raporSec(rapor);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: tileWidth > 0 ? tileWidth : null,
            height: compact ? 64 : 86,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppPalette.slate.withValues(alpha: 0.08)
                  : disabled
                  ? Colors.grey.shade100
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppPalette.slate.withValues(alpha: 0.3)
                    : disabled
                    ? Colors.grey.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: compact ? 28 : 40,
                  height: compact ? 28 : 40,
                  decoration: BoxDecoration(
                    color: disabled
                        ? Colors.grey.withValues(alpha: 0.14)
                        : _accentColorForCategory(
                            rapor.category,
                          ).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    rapor.icon,
                    size: compact ? 15 : 20,
                    color: disabled
                        ? Colors.grey
                        : _accentColorForCategory(rapor.category),
                  ),
                ),
                SizedBox(width: compact ? 8 : 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: compact ? 16 : 34,
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tr(rapor.labelKey),
                            maxLines: 1,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: compact ? 11 : 13,
                              color: disabled ? Colors.grey : AppPalette.slate,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 4),
                      SizedBox(
                        height: compact ? 12 : 28,
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tr(rapor.category.labelKey),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: compact ? 9 : 11,
                              color: disabled ? Colors.grey : AppPalette.grey,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Padding(
                    padding: EdgeInsets.only(left: compact ? 4 : 8),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: compact ? 18 : 24,
                      color: AppPalette.slate,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSummaryCards({
    required bool isMobile,
    required bool isTablet,
    bool compact = false,
  }) {
    final cards = _sonuc?.summaryCards ?? const <RaporOzetKarti>[];
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return Row(
        children: [
          for (int index = 0; index < cards.length; index++) ...[
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
                        color: cards[index].accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        cards[index].icon,
                        color: cards[index].accentColor,
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
                            height: 12,
                            child: FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                tr(cards[index].labelKey),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 18,
                            child: FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                cards[index].value,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 15,
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
            if (index != cards.length - 1) const SizedBox(width: 8),
          ],
        ],
      );
    }

    final double width = isMobile
        ? double.infinity
        : isTablet
        ? 210
        : 200;

    final rowChildren = cards.map((card) {
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

  Widget _buildReportCard({
    required RaporSonucu? sonuc,
    required RaporSecenegi? rapor,
    required List<RaporSatiri> processedRows,
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
          flex: isMobile ? null : _flexFromWidth(kolon.width),
          alignment: kolon.alignment,
          allowSorting: kolon.allowSorting,
        ),
      ),
      _TableColumnDefinition(
        key: '_actions',
        label: tr('common.actions'),
        width: 58,
        alignment: Alignment.center,
        allowSorting: false,
      ),
    ];

    final int? sortColumnIndex = _sortKey == null
        ? null
        : tableColumns.indexWhere((column) => column.key == _sortKey);

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(14),
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
          else if (processedRows.isEmpty)
            Expanded(
              child: _buildEmptyState(
                title: tr('common.no_results'),
                description: tr('reports.empty.no_rows'),
              ),
            )
          else
            Expanded(
              child: GenisletilebilirTablo<RaporSatiri>(
                key: ValueKey('reports_table_${rapor.id}_$_paginationRevision'),
                title: '',
                totalRecords: processedRows.length,
                paginationResetKey: _paginationRevision,
                searchFocusNode: FocusNode(),
                headerWidget: const SizedBox.shrink(),
                headerPadding: const EdgeInsets.symmetric(horizontal: 12),
                rowPadding: const EdgeInsets.symmetric(vertical: 9),
                expandedContentPadding: const EdgeInsets.all(18),
                onSearch: _aramaDegisti,
                onPageChanged: (page, rowsPerPage) {
                  setState(() {
                    _mevcutSayfa = page;
                    _satirSayisi = rowsPerPage;
                  });
                },
                extraWidgets: [
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
                data: _sayfaSatirlari,
                expandOnRowTap: false,
                onRowDoubleTap: _openSource,
                onSort: (columnIndex, ascending) {
                  final key = tableColumns[columnIndex].key;
                  if (key.startsWith('_')) return;
                  _sortGuncelle(key, ascending);
                },
                sortColumnIndex: sortColumnIndex != -1 ? sortColumnIndex : null,
                sortAscending: _sortAscending,
                rowBuilder: (context, row, index, isExpanded, toggleExpand) {
                  return _buildTableRow(row: row, columns: tableColumns);
                },
                detailBuilder: (context, row) => const SizedBox.shrink(),
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

    [
      if (_supports(RaporFiltreTuru.tarihAraligi))
        addFilter(
          _buildQuickDateFilter(compact: true),
          desktopWidth: 410,
          tabletWidth: 380,
          mobileWidth: 390,
          minWidth: 320,
        ),
      if (_supports(RaporFiltreTuru.cari))
        addFilter(
          _buildDropdownField<int>(
            label: tr('reports.filters.current_account'),
            icon: Icons.people_alt_outlined,
            value: _filtreler.cariId,
            items: _filtreKaynaklari.cariler
                .map(
                  (item) => DropdownMenuItem<int>(
                    value: int.tryParse(item.value),
                    child: Text(item.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                _secimGuncelle(cariId: value, clearCari: value == null),
          ),
          desktopWidth: 190,
          tabletWidth: 180,
          minWidth: 150,
        ),
      if (_supports(RaporFiltreTuru.urun))
        addFilter(
          _buildDropdownField<String>(
            label: tr('reports.filters.product'),
            icon: Icons.inventory_2_outlined,
            value: _filtreler.urunKodu,
            items: _filtreKaynaklari.urunler
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.value,
                    child: Text(item.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                _secimGuncelle(urunKodu: value, clearUrun: value == null),
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
            items: _filtreKaynaklari.urunGruplari
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.value,
                    child: Text(item.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                _secimGuncelle(urunGrubu: value, clearUrunGrubu: value == null),
          ),
          desktopWidth: 180,
          tabletWidth: 170,
          minWidth: 145,
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
            onChanged: (value) =>
                _secimGuncelle(islemTuru: value, clearIslemTuru: value == null),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.14)),
      ),
      child: filterItems.isEmpty
          ? Text(
              tr('reports.empty.no_filters'),
              style: const TextStyle(color: AppPalette.grey),
            )
          : isMobile
          ? buildFilterRow(
              filterItems.map((item) => item.mobileWidth).toList(),
              scrollable: true,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final widths = resolveResponsiveWidths(constraints.maxWidth);
                if (widths == null) {
                  return buildFilterRow(
                    filterItems
                        .map(
                          (item) =>
                              isTablet ? item.tabletWidth : item.desktopWidth,
                        )
                        .toList(),
                    scrollable: true,
                  );
                }
                return buildFilterRow(widths, scrollable: false);
              },
            ),
    );
  }

  Widget _buildQuickDateFilter({bool compact = false}) {
    final items = <MapEntry<String, String>>[
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
            ...items.map((item) {
              final bool selected = _hizliTarihSecimi == item.key;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
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
                        color: selected ? Colors.white : AppPalette.slate,
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (_hizliTarihSecimi == 'custom' && summaryText.isNotEmpty) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: Text(
                  summaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppPalette.grey),
                ),
              ),
            ],
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

  Widget _buildDropdownField<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final bool hasSelectedValue = value != null;
    final T? safeValue = items.any((item) => item.value == value)
        ? value
        : null;
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
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  key: ValueKey<String>('dropdown_${label}_${value ?? "null"}'),
                  value: safeValue,
                  isExpanded: true,
                  hint: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppPalette.slate,
                  ),
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                  items: items,
                  onChanged: onChanged,
                ),
              ),
            ),
            if (hasSelectedValue)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(null),
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
    return Row(
      children: [
        Tooltip(
          message: YazdirmaErisimKontrolu.tooltip(tr('common.print_list')),
          child: _buildActionButton(
            icon: Icons.print_outlined,
            label: tr('common.print_list'),
            disabled:
                disabled || !YazdirmaErisimKontrolu.yazdirmaKullanilabilir,
            onTap: _openPrintPreview,
          ),
        ),
      ],
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

  Widget _buildHeaderButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
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
          child = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: column.alignment,
            child: _buildValueCell(row, column.key),
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
    final bool numericAligned = <String>{
      'tutar',
      'ara_toplam',
      'kdv',
      'genel_toplam',
      'giris',
      'cikis',
      'borc',
      'alacak',
      'net_bakiye',
      'stok',
      'stok_degeri',
      'maliyet',
      'alis',
      'satis1',
      'satis2',
      'satis3',
      'ciro',
      'gider',
      'net_kar',
      'brut_kar',
      'tutar_etkisi',
    }.contains(key);

    final bool badgeLike = <String>{
      'durum',
      'tur',
      'odeme_turu',
      'modul',
    }.contains(key);

    Color color = AppPalette.slate;
    if (key == 'giris' || key == 'alacak') {
      color = const Color(0xFF27AE60);
    } else if (key == 'cikis' || key == 'borc') {
      color = AppPalette.red;
    } else if (numericAligned &&
        row.amountValue != null &&
        row.amountValue! < 0) {
      color = AppPalette.red;
    }

    if (badgeLike && value != '-') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _badgeColor(value).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _badgeColor(value),
          ),
        ),
      );
    }

    return Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: numericAligned ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontSize: 14,
        height: 1.35,
        fontWeight: numericAligned ? FontWeight.w700 : FontWeight.w500,
        color: color,
      ),
    );
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
