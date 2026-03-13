// ignore_for_file: unused_element
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:postgres/postgres.dart';

import '../../../bilesenler/tab_acici_scope.dart';
import '../../../servisler/ayarlar_veritabani_servisi.dart';
import '../../../servisler/bankalar_veritabani_servisi.dart';
import '../../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../../servisler/cekler_veritabani_servisi.dart';
import '../../../servisler/depolar_veritabani_servisi.dart';
import '../../../servisler/giderler_veritabani_servisi.dart';
import '../../../servisler/kasalar_veritabani_servisi.dart';
import '../../../servisler/kredi_kartlari_veritabani_servisi.dart';
import '../../../servisler/senetler_veritabani_servisi.dart';
import '../../../servisler/veritabani_havuzu.dart';
import '../../../servisler/uretimler_veritabani_servisi.dart';
import '../../../servisler/urunler_veritabani_servisi.dart';
import '../../../servisler/oturum_servisi.dart';
import '../../../temalar/app_theme.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/ceviri/islem_ceviri_yardimcisi.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import '../../../yardimcilar/islem_turu_renkleri.dart';
import '../../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../../ayarlar/kullanicilar/modeller/kullanici_hareket_model.dart';
import '../../ayarlar/kullanicilar/modeller/kullanici_model.dart';
import '../../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../bankalar/modeller/banka_model.dart';
import '../../carihesaplar/modeller/cari_hesap_model.dart';
import '../../giderler/modeller/gider_model.dart';
import '../../kasalar/modeller/kasa_model.dart';
import '../../kredikartlari/modeller/kredi_karti_model.dart';
import '../../urunler_ve_depolar/depolar/modeller/depo_model.dart';
import '../../urunler_ve_depolar/uretimler/modeller/uretim_model.dart';
import '../../urunler_ve_depolar/urunler/modeller/urun_model.dart';
import '../modeller/rapor_modelleri.dart';

class RaporlarServisi {
  RaporlarServisi._internal();

  static final RaporlarServisi _instance = RaporlarServisi._internal();
  factory RaporlarServisi() => _instance;

  final CariHesaplarVeritabaniServisi _cariServisi =
      CariHesaplarVeritabaniServisi();
  final UrunlerVeritabaniServisi _urunServisi = UrunlerVeritabaniServisi();
  final DepolarVeritabaniServisi _depoServisi = DepolarVeritabaniServisi();
  final KasalarVeritabaniServisi _kasaServisi = KasalarVeritabaniServisi();
  final BankalarVeritabaniServisi _bankaServisi = BankalarVeritabaniServisi();
  final KrediKartlariVeritabaniServisi _krediKartiServisi =
      KrediKartlariVeritabaniServisi();
  final CeklerVeritabaniServisi _cekServisi = CeklerVeritabaniServisi();
  final SenetlerVeritabaniServisi _senetServisi = SenetlerVeritabaniServisi();
  final GiderlerVeritabaniServisi _giderServisi = GiderlerVeritabaniServisi();
  final UretimlerVeritabaniServisi _uretimServisi =
      UretimlerVeritabaniServisi();
  final AyarlarVeritabaniServisi _ayarlarServisi = AyarlarVeritabaniServisi();
  GenelAyarlarModel? _guncelAyarlar;
  RaporFiltreKaynaklari? _cachedFilterKaynaklari;
  Future<RaporFiltreKaynaklari>? _filtreKaynaklariFuture;
  DateTime? _filtreKaynaklariAt;

  static const String _defaultCompanyId = 'patisyo2025';
  String get _companyId => OturumServisi().aktifVeritabaniAdi;

  static const Duration _summaryCacheTtl = Duration(minutes: 2);
  static const int _summaryCacheMaxEntries = 180;
  final Map<String, ({DateTime at, List<RaporOzetKarti> cards})>
  _summaryCardsCache = <String, ({DateTime at, List<RaporOzetKarti> cards})>{};
  final Map<String, Future<List<RaporOzetKarti>>> _summaryCardsInFlight =
      <String, Future<List<RaporOzetKarti>>>{};
  final Map<String, ({DateTime at, List<RaporIslemToplami> totals})>
  _islemToplamlariCache =
      <String, ({DateTime at, List<RaporIslemToplami> totals})>{};
  final Map<String, Future<List<RaporIslemToplami>>> _islemToplamlariInFlight =
      <String, Future<List<RaporIslemToplami>>>{};
  final Map<
    String,
    ({
      DateTime at,
      ({List<RaporOzetKarti> cards, Map<String, dynamic> headerInfo}) data,
    })
  >
  _profitLossTopSummaryCache =
      <
        String,
        ({
          DateTime at,
          ({List<RaporOzetKarti> cards, Map<String, dynamic> headerInfo}) data,
        })
      >{};
  final Map<
    String,
    Future<({List<RaporOzetKarti> cards, Map<String, dynamic> headerInfo})>
  >
  _profitLossTopSummaryInFlight =
      <
        String,
        Future<({List<RaporOzetKarti> cards, Map<String, dynamic> headerInfo})>
      >{};
  final Map<
    String,
    ({DateTime at, ({int totalCount, List<RaporOzetKarti> cards}) data})
  >
  _baBsSummaryCache =
      <
        String,
        ({DateTime at, ({int totalCount, List<RaporOzetKarti> cards}) data})
      >{};
  final Map<String, Future<({int totalCount, List<RaporOzetKarti> cards})>>
  _baBsSummaryInFlight =
      <String, Future<({int totalCount, List<RaporOzetKarti> cards})>>{};
  final Map<
    String,
    ({DateTime at, ({int totalCount, List<RaporOzetKarti> cards}) data})
  >
  _receivablesPayablesSummaryCache =
      <
        String,
        ({DateTime at, ({int totalCount, List<RaporOzetKarti> cards}) data})
      >{};
  final Map<String, Future<({int totalCount, List<RaporOzetKarti> cards})>>
  _receivablesPayablesSummaryInFlight =
      <String, Future<({int totalCount, List<RaporOzetKarti> cards})>>{};

  static final List<RaporSecenegi> _raporlar = <RaporSecenegi>[
    RaporSecenegi(
      id: 'all_movements',
      labelKey: 'reports.items.all_movements',
      category: RaporKategori.genel,
      icon: Icons.alt_route_rounded,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.islemTuru,
        RaporFiltreTuru.belgeNo,
        RaporFiltreTuru.referansNo,
        RaporFiltreTuru.kullanici,
      },
    ),
    RaporSecenegi(
      id: 'purchase_sales_movements',
      labelKey: 'reports.items.purchase_sales_movements',
      category: RaporKategori.genel,
      icon: Icons.compare_arrows_rounded,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.islemTuru,
        RaporFiltreTuru.belgeNo,
        RaporFiltreTuru.referansNo,
      },
    ),
    RaporSecenegi(
      id: 'product_movements',
      labelKey: 'reports.items.product_movements',
      category: RaporKategori.stokDepo,
      icon: Icons.inventory_2_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.islemTuru,
        RaporFiltreTuru.urunGrubu,
        // "Tür" filtresi için `durum` alanını kullanıyoruz.
        RaporFiltreTuru.durum,
      },
    ),
    RaporSecenegi(
      id: 'product_shipment_movements',
      labelKey: 'reports.items.product_shipment_movements',
      category: RaporKategori.stokDepo,
      icon: Icons.local_shipping_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        // "Tür" filtresi için `durum` alanını kullanıyoruz.
        RaporFiltreTuru.durum,
      },
    ),
    RaporSecenegi(
      id: 'profit_loss',
      labelKey: 'reports.items.profit_loss',
      category: RaporKategori.genel,
      icon: Icons.show_chart_rounded,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.urunGrubu,
        RaporFiltreTuru.kdvOrani,
      },
    ),
    RaporSecenegi(
      id: 'balance_list',
      labelKey: 'reports.items.balance_list',
      category: RaporKategori.genel,
      icon: Icons.account_balance_wallet_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.hesapTuru,
        RaporFiltreTuru.bakiyeDurumu,
      },
    ),
    RaporSecenegi(
      id: 'ba_bs_list',
      labelKey: 'reports.items.ba_bs_list',
      category: RaporKategori.genel,
      icon: Icons.receipt_long_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.hesapTuru,
      },
    ),
    RaporSecenegi(
      id: 'receivables_payables',
      labelKey: 'reports.items.receivables_payables',
      category: RaporKategori.genel,
      icon: Icons.payments_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.hesapTuru,
        RaporFiltreTuru.islemTuru,
      },
    ),
    RaporSecenegi(
      id: 'vat_accounting',
      labelKey: 'reports.items.vat_accounting',
      category: RaporKategori.genel,
      icon: Icons.percent_rounded,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.islemTuru,
        RaporFiltreTuru.belgeNo,
        RaporFiltreTuru.referansNo,
      },
    ),
    RaporSecenegi(
      id: 'last_transaction_date',
      labelKey: 'reports.items.last_transaction_date',
      category: RaporKategori.genel,
      icon: Icons.event_repeat_outlined,
      supportedFilters: {RaporFiltreTuru.tarihAraligi},
    ),
    RaporSecenegi(
      id: 'warehouse_stock_list',
      labelKey: 'reports.items.warehouse_stock_list',
      category: RaporKategori.stokDepo,
      icon: Icons.warehouse_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.depo,
      },
    ),
    RaporSecenegi(
      id: 'warehouse_shipment_list',
      labelKey: 'reports.items.warehouse_shipment_list',
      category: RaporKategori.stokDepo,
      icon: Icons.move_down_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.cikisDepo,
        RaporFiltreTuru.girisDepo,
      },
    ),
    RaporSecenegi(
      id: 'sales_report',
      labelKey: 'reports.items.sales_report',
      category: RaporKategori.satisAlis,
      icon: Icons.point_of_sale_rounded,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.cari,
        RaporFiltreTuru.kullanici,
        RaporFiltreTuru.minTutar,
        RaporFiltreTuru.maxTutar,
      },
    ),
    RaporSecenegi(
      id: 'purchase_report',
      labelKey: 'reports.items.purchase_report',
      category: RaporKategori.satisAlis,
      icon: Icons.shopping_cart_checkout_rounded,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.cari,
        RaporFiltreTuru.kullanici,
        RaporFiltreTuru.minTutar,
        RaporFiltreTuru.maxTutar,
      },
    ),
    RaporSecenegi(
      id: 'order_report',
      labelKey: 'reports.items.order_report',
      category: RaporKategori.siparisTeklif,
      icon: Icons.shopping_bag_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.cari,
        RaporFiltreTuru.kullanici,
        RaporFiltreTuru.durum,
        RaporFiltreTuru.belgeNo,
      },
    ),
    RaporSecenegi(
      id: 'quote_report',
      labelKey: 'reports.items.quote_report',
      category: RaporKategori.siparisTeklif,
      icon: Icons.request_quote_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.cari,
        RaporFiltreTuru.kullanici,
        RaporFiltreTuru.durum,
        RaporFiltreTuru.belgeNo,
      },
    ),
    RaporSecenegi(
      id: 'account_statement',
      labelKey: 'reports.items.account_statement',
      category: RaporKategori.cari,
      icon: Icons.account_balance_wallet_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.cari,
        RaporFiltreTuru.islemTuru,
        RaporFiltreTuru.kullanici,
      },
    ),
    RaporSecenegi(
      id: 'cash_movement_report',
      labelKey: 'reports.items.cash_movement_report',
      category: RaporKategori.finans,
      icon: Icons.payments_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.kasa,
        RaporFiltreTuru.islemTuru,
        RaporFiltreTuru.kullanici,
      },
    ),
    RaporSecenegi(
      id: 'bank_movement_report',
      labelKey: 'reports.items.bank_movement_report',
      category: RaporKategori.finans,
      icon: Icons.account_balance_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.banka,
        RaporFiltreTuru.islemTuru,
        RaporFiltreTuru.kullanici,
      },
    ),
    RaporSecenegi(
      id: 'credit_card_movement_report',
      labelKey: 'reports.items.credit_card_movement_report',
      category: RaporKategori.finans,
      icon: Icons.credit_card_rounded,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.krediKarti,
        RaporFiltreTuru.islemTuru,
        RaporFiltreTuru.kullanici,
      },
    ),
    RaporSecenegi(
      id: 'check_report',
      labelKey: 'reports.items.check_report',
      category: RaporKategori.cekSenet,
      icon: Icons.description_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.cari,
        RaporFiltreTuru.durum,
        RaporFiltreTuru.belgeNo,
      },
    ),
    RaporSecenegi(
      id: 'note_report',
      labelKey: 'reports.items.note_report',
      category: RaporKategori.cekSenet,
      icon: Icons.note_alt_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.cari,
        RaporFiltreTuru.durum,
        RaporFiltreTuru.belgeNo,
      },
    ),
    RaporSecenegi(
      id: 'expense_report',
      labelKey: 'reports.items.expense_report',
      category: RaporKategori.gider,
      icon: Icons.money_off_csred_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.durum,
        RaporFiltreTuru.kullanici,
        RaporFiltreTuru.minTutar,
        RaporFiltreTuru.maxTutar,
      },
    ),
    RaporSecenegi(
      id: 'production_report',
      labelKey: 'reports.items.production_report',
      category: RaporKategori.uretim,
      icon: Icons.precision_manufacturing_outlined,
      supportedFilters: {
        RaporFiltreTuru.urun,
        RaporFiltreTuru.urunGrubu,
        RaporFiltreTuru.durum,
      },
    ),
    RaporSecenegi(
      id: 'user_activity_report',
      labelKey: 'reports.items.user_activity_report',
      category: RaporKategori.kullanici,
      icon: Icons.groups_rounded,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.kullanici,
        RaporFiltreTuru.islemTuru,
      },
    ),
  ];

  List<RaporSecenegi> get raporlar => _raporlar;

  String _summaryCacheKey({
    required String reportId,
    required RaporFiltreleri filtreler,
    required String arama,
    String? extra,
  }) {
    // Keep key stable (avoid DateTime.toString locale surprises).
    final payload = <String, dynamic>{
      'r': reportId,
      'a': _normalizeArama(arama),
      'bs': filtreler.baslangicTarihi?.toIso8601String(),
      'bt': filtreler.bitisTarihi?.toIso8601String(),
      'cari': filtreler.cariId,
      'urun': filtreler.urunKodu,
      'grup': filtreler.urunGrubu,
      'kdv': filtreler.kdvOrani,
      'depo': filtreler.depoId,
      'hesapTuru': filtreler.hesapTuru,
      'bakiyeDurumu': filtreler.bakiyeDurumu,
      'islem': filtreler.islemTuru,
      'durum': filtreler.durum,
      'odeme': filtreler.odemeYontemi,
      'kasa': filtreler.kasaId,
      'banka': filtreler.bankaId,
      'kk': filtreler.krediKartiId,
      'kul': filtreler.kullaniciId,
      'belgeNo': filtreler.belgeNo,
      'refNo': filtreler.referansNo,
      'minTutar': filtreler.minTutar,
      'maxTutar': filtreler.maxTutar,
      'minMiktar': filtreler.minMiktar,
      'maxMiktar': filtreler.maxMiktar,
      'x': extra,
    };
    return jsonEncode(payload);
  }

  Future<List<RaporOzetKarti>> _getOrComputeSummaryCards({
    required String cacheKey,
    required Future<List<RaporOzetKarti>> Function() loader,
  }) async {
    final now = DateTime.now();
    final cached = _summaryCardsCache[cacheKey];
    if (cached != null && now.difference(cached.at) < _summaryCacheTtl) {
      return cached.cards;
    }

    final inFlight = _summaryCardsInFlight[cacheKey];
    if (inFlight != null) return inFlight;

    final future = loader();
    _summaryCardsInFlight[cacheKey] = future;
    try {
      final cards = await future;
      _summaryCardsCache[cacheKey] = (at: now, cards: cards);
      // Best-effort prune (avoid unbounded growth).
      if (_summaryCardsCache.length > _summaryCacheMaxEntries) {
        final entries = _summaryCardsCache.entries.toList()
          ..sort((a, b) => a.value.at.compareTo(b.value.at));
        final removeCount = math.max(
          0,
          entries.length - _summaryCacheMaxEntries,
        );
        for (int i = 0; i < removeCount; i++) {
          _summaryCardsCache.remove(entries[i].key);
        }
      }
      return cards;
    } finally {
      if (identical(_summaryCardsInFlight[cacheKey], future)) {
        _summaryCardsInFlight.remove(cacheKey);
      }
    }
  }

  Future<({List<RaporOzetKarti> cards, Map<String, dynamic> headerInfo})>
  _getOrComputeProfitLossTopSummary({
    required String cacheKey,
    required Future<
      ({List<RaporOzetKarti> cards, Map<String, dynamic> headerInfo})
    >
    Function()
    loader,
  }) async {
    final now = DateTime.now();
    final cached = _profitLossTopSummaryCache[cacheKey];
    if (cached != null && now.difference(cached.at) < _summaryCacheTtl) {
      return cached.data;
    }

    final inFlight = _profitLossTopSummaryInFlight[cacheKey];
    if (inFlight != null) return await inFlight;

    final future = loader();
    _profitLossTopSummaryInFlight[cacheKey] = future;
    try {
      final data = await future;
      _profitLossTopSummaryCache[cacheKey] = (at: now, data: data);
      if (_profitLossTopSummaryCache.length > _summaryCacheMaxEntries) {
        final entries = _profitLossTopSummaryCache.entries.toList()
          ..sort((a, b) => a.value.at.compareTo(b.value.at));
        final removeCount = math.max(
          0,
          entries.length - _summaryCacheMaxEntries,
        );
        for (int i = 0; i < removeCount; i++) {
          _profitLossTopSummaryCache.remove(entries[i].key);
        }
      }
      return data;
    } finally {
      if (identical(_profitLossTopSummaryInFlight[cacheKey], future)) {
        _profitLossTopSummaryInFlight.remove(cacheKey);
      }
    }
  }

  Future<({int totalCount, List<RaporOzetKarti> cards})>
  _getOrComputeBaBsSummary({
    required String cacheKey,
    required Future<({int totalCount, List<RaporOzetKarti> cards})> Function()
    loader,
  }) async {
    final now = DateTime.now();
    final cached = _baBsSummaryCache[cacheKey];
    if (cached != null && now.difference(cached.at) < _summaryCacheTtl) {
      return cached.data;
    }

    final inFlight = _baBsSummaryInFlight[cacheKey];
    if (inFlight != null) return await inFlight;

    final future = loader();
    _baBsSummaryInFlight[cacheKey] = future;
    try {
      final data = await future;
      _baBsSummaryCache[cacheKey] = (at: now, data: data);
      if (_baBsSummaryCache.length > _summaryCacheMaxEntries) {
        final entries = _baBsSummaryCache.entries.toList()
          ..sort((a, b) => a.value.at.compareTo(b.value.at));
        final removeCount = math.max(
          0,
          entries.length - _summaryCacheMaxEntries,
        );
        for (int i = 0; i < removeCount; i++) {
          _baBsSummaryCache.remove(entries[i].key);
        }
      }
      return data;
    } finally {
      if (identical(_baBsSummaryInFlight[cacheKey], future)) {
        _baBsSummaryInFlight.remove(cacheKey);
      }
    }
  }

  Future<({int totalCount, List<RaporOzetKarti> cards})>
  _getOrComputeReceivablesPayablesSummary({
    required String cacheKey,
    required Future<({int totalCount, List<RaporOzetKarti> cards})> Function()
    loader,
  }) async {
    final now = DateTime.now();
    final cached = _receivablesPayablesSummaryCache[cacheKey];
    if (cached != null && now.difference(cached.at) < _summaryCacheTtl) {
      return cached.data;
    }

    final inFlight = _receivablesPayablesSummaryInFlight[cacheKey];
    if (inFlight != null) return await inFlight;

    final future = loader();
    _receivablesPayablesSummaryInFlight[cacheKey] = future;
    try {
      final data = await future;
      _receivablesPayablesSummaryCache[cacheKey] = (at: now, data: data);
      if (_receivablesPayablesSummaryCache.length > _summaryCacheMaxEntries) {
        final entries = _receivablesPayablesSummaryCache.entries.toList()
          ..sort((a, b) => a.value.at.compareTo(b.value.at));
        final removeCount = math.max(
          0,
          entries.length - _summaryCacheMaxEntries,
        );
        for (int i = 0; i < removeCount; i++) {
          _receivablesPayablesSummaryCache.remove(entries[i].key);
        }
      }
      return data;
    } finally {
      if (identical(_receivablesPayablesSummaryInFlight[cacheKey], future)) {
        _receivablesPayablesSummaryInFlight.remove(cacheKey);
      }
    }
  }

  Future<List<RaporIslemToplami>> _getOrComputeIslemToplamlari({
    required String cacheKey,
    required Future<List<RaporIslemToplami>> Function() loader,
  }) async {
    final now = DateTime.now();
    final cached = _islemToplamlariCache[cacheKey];
    if (cached != null && now.difference(cached.at) < _summaryCacheTtl) {
      return cached.totals;
    }

    final inFlight = _islemToplamlariInFlight[cacheKey];
    if (inFlight != null) return inFlight;

    final future = loader();
    _islemToplamlariInFlight[cacheKey] = future;
    try {
      final totals = await future;
      _islemToplamlariCache[cacheKey] = (at: now, totals: totals);
      if (_islemToplamlariCache.length > _summaryCacheMaxEntries) {
        final entries = _islemToplamlariCache.entries.toList()
          ..sort((a, b) => a.value.at.compareTo(b.value.at));
        final removeCount = math.max(
          0,
          entries.length - _summaryCacheMaxEntries,
        );
        for (int i = 0; i < removeCount; i++) {
          _islemToplamlariCache.remove(entries[i].key);
        }
      }
      return totals;
    } finally {
      if (identical(_islemToplamlariInFlight[cacheKey], future)) {
        _islemToplamlariInFlight.remove(cacheKey);
      }
    }
  }

  Future<RaporFiltreKaynaklari> filtreKaynaklariniGetir({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedFilterKaynaklari != null &&
        _filtreKaynaklariAt != null &&
        now.difference(_filtreKaynaklariAt!) < const Duration(minutes: 5)) {
      return _cachedFilterKaynaklari!;
    }

    final inflight = _filtreKaynaklariFuture;
    if (!forceRefresh && inflight != null) {
      return inflight;
    }

    final future = () async {
      final pool = await _havuzAl();
      final results = await Future.wait([
        _depoServisi.tumDepolariGetir(),
        _kasaServisi.tumKasalariGetir(),
        _bankaServisi.tumBankalariGetir(),
        _krediKartiServisi.tumKrediKartlariniGetir(sadeceAktif: false),
        _ayarlarServisi.kullanicilariGetir(sayfaBasinaKayit: 2000),
      ]);

      final depolar = results[0] as List<DepoModel>;
      final kasalar = results[1] as List<KasaModel>;
      final bankalar = results[2] as List<BankaModel>;
      final kartlar = results[3] as List<KrediKartiModel>;
      final kullanicilar = results[4] as List<KullaniciModel>;

      final List<RaporSecimSecenegi> urunGruplari = <RaporSecimSecenegi>[];
      try {
        final groupRows = await _queryMaps(
          pool,
          '''
          SELECT DISTINCT TRIM(grubu) AS grup
          FROM products
          WHERE grubu IS NOT NULL AND TRIM(grubu) <> ''
          ORDER BY TRIM(grubu) ASC
          LIMIT @limit
          ''',
          {'limit': 5000},
        );
        for (final row in groupRows) {
          final group = row['grup']?.toString().trim() ?? '';
          if (group.isEmpty) continue;
          urunGruplari.add(RaporSecimSecenegi(value: group, label: group));
        }
      } catch (_) {
        // ignore: optional source
      }

      final List<double> kdvOranlari = <double>[];
      try {
        final vatRows = await _queryMaps(
          pool,
          '''
          SELECT DISTINCT COALESCE(kdv_orani, 0) AS kdv_orani
          FROM products
          ORDER BY COALESCE(kdv_orani, 0) ASC
          LIMIT @limit
          ''',
          {'limit': 500},
        );
        for (final row in vatRows) {
          kdvOranlari.add(_toDouble(row['kdv_orani']));
        }
      } catch (_) {
        // ignore: optional source
      }

      final kaynaklar = RaporFiltreKaynaklari(
        // Büyük DB için preload yerine typeahead kullanıyoruz.
        cariler: const <RaporSecimSecenegi>[],
        urunler: const <RaporSecimSecenegi>[],
        urunGruplari: urunGruplari,
        kdvOranlari: kdvOranlari,
        depolar: depolar
            .map(
              (e) => RaporSecimSecenegi(
                value: e.id.toString(),
                label: '${e.kod} - ${e.ad}',
                extra: {'model': e},
              ),
            )
            .toList(),
        kasalar: kasalar
            .map(
              (e) => RaporSecimSecenegi(
                value: e.id.toString(),
                label: '${e.kod} - ${e.ad}',
                extra: {'model': e},
              ),
            )
            .toList(),
        bankalar: bankalar
            .map(
              (e) => RaporSecimSecenegi(
                value: e.id.toString(),
                label: '${e.kod} - ${e.ad}',
                extra: {'model': e},
              ),
            )
            .toList(),
        krediKartlari: kartlar
            .map(
              (e) => RaporSecimSecenegi(
                value: e.id.toString(),
                label: '${e.kod} - ${e.ad}',
                extra: {'model': e},
              ),
            )
            .toList(),
        kullanicilar: kullanicilar
            .map(
              (e) => RaporSecimSecenegi(
                value: e.id,
                label: '${e.kullaniciAdi} (${e.ad} ${e.soyad})'.trim(),
                extra: {'model': e},
              ),
            )
            .toList(),
        durumlar: <String, List<RaporSecimSecenegi>>{
          'order_report': _options([
            tr('common.all'),
            'Beklemede',
            'Onaylandı',
            'Tamamlandı',
            'İptal Edildi',
          ]),
          'quote_report': _options([
            tr('common.all'),
            'Beklemede',
            'Onaylandı',
            'Tamamlandı',
            'İptal Edildi',
          ]),
          'check_report': _options([
            tr('common.all'),
            'Aktif',
            'Pasif',
            'Tahsil',
            'Ödendi',
          ]),
          'note_report': _options([
            tr('common.all'),
            'Aktif',
            'Pasif',
            'Tahsil',
            'Ödendi',
          ]),
          'expense_report': _options([
            tr('common.all'),
            'Ödendi',
            'Beklemede',
            'Kısmi',
          ]),
          'stock_definition_values': _options([
            tr('common.all'),
            tr('common.active'),
            tr('common.passive'),
          ]),
          'production_report': _options([
            tr('common.all'),
            tr('common.active'),
            tr('common.passive'),
          ]),
          // Ürün Hareketleri raporunda "Tür" filtresi için kullanılır.
          'product_movements': _options([tr('common.all'), 'Ürün']),
          // Ürün Sevkiyat Hareketleri raporunda "Tür" filtresi için kullanılır.
          'product_shipment_movements': _options([tr('common.all'), 'Ürün']),
        },
        islemTurleri: <String, List<RaporSecimSecenegi>>{
          'account_statement': _options([
            tr('common.all'),
            'Satış Yapıldı',
            'Alış Yapıldı',
            'Para Alındı',
            'Para Verildi',
            'Tahsilat',
            'Ödeme',
          ]),
          'receivables_payables': _options([
            tr('common.all'),
            'Alınacak',
            'Verilecek',
          ]),
          'cash_movement_report': _options([
            tr('common.all'),
            'Kasa Tahsilat',
            'Kasa Ödeme',
          ]),
          'bank_movement_report': _options([
            tr('common.all'),
            'Banka Tahsilat',
            'Banka Ödeme',
            'Banka Transfer',
          ]),
          'credit_card_movement_report': _options([
            tr('common.all'),
            'Kredi Kartı Tahsilat',
            'Kredi Kartı Harcama',
          ]),
          'user_activity_report': _options([
            tr('common.all'),
            'tahsilat',
            'odeme',
            'maas',
            'alacak',
          ]),
          'product_movements': _options([
            tr('common.all'),
            'Açılış Stoğu (Girdi)',
            'Devir Giriş',
            'Devir Çıkış',
            'Satış Yapıldı',
            'Alış Yapıldı',
            'Sevkiyat',
            'Üretim Girişi',
            'Üretim Çıkışı',
          ]),
        },
        odemeYontemleri: <String, List<RaporSecimSecenegi>>{
          'sales_report': _options([
            tr('common.all'),
            'Nakit',
            'Banka',
            'Kredi Kartı',
            'Cari',
          ]),
          'purchase_report': _options([
            tr('common.all'),
            'Nakit',
            'Banka',
            'Kredi Kartı',
            'Cari',
          ]),
          'expense_report': _options([
            tr('common.all'),
            'Nakit',
            'Banka',
            'Kredi Kartı',
            'Cari',
          ]),
        },
      );
      _cachedFilterKaynaklari = kaynaklar;
      _filtreKaynaklariAt = DateTime.now();
      return kaynaklar;
    }();

    _filtreKaynaklariFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_filtreKaynaklariFuture, future)) {
        _filtreKaynaklariFuture = null;
      }
    }
  }

  Future<List<RaporSecimSecenegi>> cariSecenekleriAra(
    String aramaTerimi, {
    int limit = 20,
  }) async {
    final tokens = _searchTokens(aramaTerimi);
    if (tokens.isEmpty) return const <RaporSecimSecenegi>[];

    final pool = await _havuzAl();
    final params = <String, dynamic>{'limit': limit.clamp(1, 50)};
    _bindSearchTokenParams(params, tokens);
    final where = _tokenLikeClause('ca.search_tags', tokens.length);

    final rows = await _queryMaps(pool, '''
      SELECT ca.id, ca.kod_no, ca.adi
      FROM current_accounts ca
      WHERE $where
      ORDER BY ca.adi ASC, ca.id ASC
      LIMIT @limit
      ''', params);

    return rows
        .map((row) {
          final int id = _toInt(row['id']) ?? 0;
          final String kod = row['kod_no']?.toString() ?? '-';
          final String ad = row['adi']?.toString() ?? '-';
          return RaporSecimSecenegi(
            value: id.toString(),
            label: '$kod - $ad',
            extra: row,
          );
        })
        .toList(growable: false);
  }

  Future<RaporSecimSecenegi?> cariSecenegiGetir(int cariId) async {
    final pool = await _havuzAl();
    final rows = await _queryMaps(
      pool,
      'SELECT id, kod_no, adi FROM current_accounts WHERE id = @id LIMIT 1',
      {'id': cariId},
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final int id = _toInt(row['id']) ?? cariId;
    final String kod = row['kod_no']?.toString() ?? '-';
    final String ad = row['adi']?.toString() ?? '-';
    return RaporSecimSecenegi(value: id.toString(), label: '$kod - $ad');
  }

  Future<List<RaporSecimSecenegi>> urunSecenekleriAra(
    String aramaTerimi, {
    int limit = 20,
  }) async {
    final tokens = _searchTokens(aramaTerimi);
    if (tokens.isEmpty) return const <RaporSecimSecenegi>[];

    final pool = await _havuzAl();
    final params = <String, dynamic>{'limit': limit.clamp(1, 50)};
    _bindSearchTokenParams(params, tokens);
    final where = _tokenLikeClause('p.search_tags', tokens.length);

    final rows = await _queryMaps(pool, '''
      SELECT p.kod, p.ad, p.grubu
      FROM products p
      WHERE $where
      ORDER BY p.ad ASC NULLS LAST, p.kod ASC
      LIMIT @limit
      ''', params);

    return rows
        .map((row) {
          final String kod = row['kod']?.toString() ?? '';
          final String ad = row['ad']?.toString() ?? '-';
          return RaporSecimSecenegi(
            value: kod,
            label: kod.isEmpty ? ad : '$kod - $ad',
            extra: row,
          );
        })
        .toList(growable: false);
  }

  Future<RaporSecimSecenegi?> urunSecenegiGetir(String urunKodu) async {
    final trimmed = urunKodu.trim();
    if (trimmed.isEmpty) return null;
    final pool = await _havuzAl();
    final rows = await _queryMaps(
      pool,
      'SELECT kod, ad FROM products WHERE kod = @kod LIMIT 1',
      {'kod': trimmed},
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final String kod = row['kod']?.toString() ?? trimmed;
    final String ad = row['ad']?.toString() ?? '-';
    return RaporSecimSecenegi(value: kod, label: '$kod - $ad');
  }

  Future<RaporSonucu> raporuGetir({
    required RaporSecenegi rapor,
    required RaporFiltreleri filtreler,
    required int page,
    required int pageSize,
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
  }) async {
    try {
      _guncelAyarlar = await _ayarlarServisi.genelAyarlariGetir();
    } catch (e) {
      // Hata durumunda yoksay
    }

    if (!rapor.supported) {
      return RaporSonucu(
        report: rapor,
        columns: const <RaporKolonTanimi>[],
        rows: const <RaporSatiri>[],
        disabledReasonKey: rapor.disabledReasonKey,
      );
    }

    switch (rapor.id) {
      case 'all_movements':
        return _buildOptimizedTumHareketler(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'purchase_sales_movements':
        return _buildOptimizedAlisSatisHareketleri(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'sales_report':
        return _buildOptimizedCariRapor(
          rapor,
          filtreler,
          mod: _CariRaporModu.satis,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'purchase_report':
        return _buildOptimizedCariRapor(
          rapor,
          filtreler,
          mod: _CariRaporModu.alis,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'account_statement':
        return _buildOptimizedCariRapor(
          rapor,
          filtreler,
          mod: _CariRaporModu.ekstre,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'cash_movement_report':
        return _buildOptimizedFinansRaporu(
          rapor,
          filtreler,
          mod: _FinansRaporModu.kasa,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'bank_movement_report':
        return _buildOptimizedFinansRaporu(
          rapor,
          filtreler,
          mod: _FinansRaporModu.banka,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'credit_card_movement_report':
        return _buildOptimizedFinansRaporu(
          rapor,
          filtreler,
          mod: _FinansRaporModu.krediKarti,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'product_movements':
        return _buildOptimizedUrunHareketleri(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'product_shipment_movements':
        return _buildOptimizedUrunSevkiyatHareketleri(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'warehouse_stock_list':
        return _buildOptimizedDepoStokListesi(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'warehouse_shipment_list':
        return _buildOptimizedDepoSevkiyatListesi(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'stock_early_warning':
        return _buildOptimizedStokErkenUyari(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'stock_definition_values':
        return _buildOptimizedStokTanimDegerleri(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'order_report':
        return _buildOptimizedSiparisTeklifRaporu(
          rapor,
          filtreler,
          siparisMi: true,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'quote_report':
        return _buildOptimizedSiparisTeklifRaporu(
          rapor,
          filtreler,
          siparisMi: false,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'check_report':
        return _buildOptimizedCekSenetRaporu(
          rapor,
          filtreler,
          cekMi: true,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'note_report':
        return _buildOptimizedCekSenetRaporu(
          rapor,
          filtreler,
          cekMi: false,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'expense_report':
        return _buildOptimizedGiderRaporu(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'production_report':
        return _buildOptimizedUretimRaporu(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'balance_list':
        return _buildOptimizedBakiyeListesi(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'ba_bs_list':
        return _buildOptimizedBaBsListesi(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'receivables_payables':
        return _buildOptimizedAlinacakVerilecekler(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'vat_accounting':
        return _buildOptimizedKdvHesabi(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'last_transaction_date':
        return _buildOptimizedSonIslemTarihi(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'profit_loss':
        return _buildOptimizedKarZarar(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      case 'user_activity_report':
        return _buildOptimizedKullaniciIslemRaporu(
          rapor,
          filtreler,
          arama: arama,
          cursor: cursor,
          sortKey: sortKey,
          sortAscending: sortAscending,
          page: page,
          pageSize: pageSize,
        );
      default:
        break;
    }

    return RaporSonucu(
      report: rapor,
      columns: const <RaporKolonTanimi>[],
      rows: const <RaporSatiri>[],
      disabledReasonKey: 'reports.disabled.unknown',
    );
  }

  Future<RaporSonucu> _buildOptimizedBaBsListesi(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final effectiveArama = _normalizeNumericSearchForReports(arama);

    String sortExpr(String? key) {
      switch (key) {
        case 'kod':
          return "COALESCE(base.kod, '')";
        case 'ad':
          return "COALESCE(base.ad, '')";
        case 'tur':
          return "COALESCE(base.hesap_turu, '')";
        case 'alis_fatura_matrah':
          return 'base.alis_fatura_matrah';
        case 'satis_fatura_matrah':
          return 'base.satis_fatura_matrah';
        case 'alis_fatura_adet':
          return 'base.alis_fatura_adet';
        case 'satis_fatura_adet':
          return 'base.satis_fatura_adet';
        default:
          return "COALESCE(base.kod, '')";
      }
    }

    final params = <String, dynamic>{};

    final txWhere = <String>[
      'cat.integration_ref IS NOT NULL',
      '('
          '('
          "COALESCE(cat.integration_ref, '') LIKE 'PURCHASE-%'"
          ' AND normalize_text(COALESCE(cat.source_type, \'\')) = normalize_text(\'Alış Yapıldı\')'
          ')'
          ' OR '
          '('
          '('
          "COALESCE(cat.integration_ref, '') LIKE 'SALE-%'"
          " OR COALESCE(cat.integration_ref, '') LIKE 'RETAIL-%'"
          ')'
          ' AND normalize_text(COALESCE(cat.source_type, \'\')) IN ('
          'normalize_text(\'Satış Yapıldı\'), '
          'normalize_text(\'Perakende Satış\')'
          ')'
          ')'
          ')',
    ];

    if (filtreler.baslangicTarihi != null) {
      params['baslangic'] = DateTime(
        filtreler.baslangicTarihi!.year,
        filtreler.baslangicTarihi!.month,
        filtreler.baslangicTarihi!.day,
      ).toIso8601String();
      txWhere.add('cat.date >= @baslangic');
    }

    if (filtreler.bitisTarihi != null) {
      params['bitis'] = DateTime(
        filtreler.bitisTarihi!.year,
        filtreler.bitisTarihi!.month,
        filtreler.bitisTarihi!.day,
      ).add(const Duration(days: 1)).toIso8601String();
      txWhere.add('cat.date < @bitis');
    }

    final String txWhereSql = txWhere.isEmpty
        ? ''
        : 'WHERE ${txWhere.join(' AND ')}';

    final baseSelect =
        '''
      WITH invoice_tx AS (
        SELECT
          cat.current_account_id,
          cat.integration_ref,
          cat.amount,
          cat.para_birimi,
          cat.source_type
        FROM current_account_transactions cat
        $txWhereSql
      )
      SELECT
        ca.id::bigint AS gid,
        ca.kod_no AS kod,
        ca.adi AS ad,
        COALESCE(ca.hesap_turu, '') AS hesap_turu,
        COALESCE(ca.para_birimi, 'TRY') AS para_birimi,
        MIN(ca.search_tags) AS search_tags,
        COALESCE(
          SUM(
            CASE
              WHEN COALESCE(it.integration_ref, '') LIKE 'PURCHASE-%' THEN COALESCE(it.amount, 0)
              ELSE 0
            END
          ),
          0
        ) AS alis_fatura_matrah,
        COALESCE(
          SUM(
            CASE
              WHEN COALESCE(it.integration_ref, '') LIKE 'SALE-%'
                OR COALESCE(it.integration_ref, '') LIKE 'RETAIL-%'
              THEN COALESCE(it.amount, 0)
              ELSE 0
            END
          ),
          0
        ) AS satis_fatura_matrah,
        COUNT(
          DISTINCT CASE
            WHEN COALESCE(it.integration_ref, '') LIKE 'PURCHASE-%' THEN it.integration_ref
            ELSE NULL
          END
        )::bigint AS alis_fatura_adet,
        COUNT(
          DISTINCT CASE
            WHEN COALESCE(it.integration_ref, '') LIKE 'SALE-%'
              OR COALESCE(it.integration_ref, '') LIKE 'RETAIL-%'
            THEN it.integration_ref
            ELSE NULL
          END
        )::bigint AS satis_fatura_adet
      FROM current_accounts ca
      LEFT JOIN invoice_tx it ON it.current_account_id = ca.id
      GROUP BY ca.id, ca.kod_no, ca.adi, ca.hesap_turu, ca.para_birimi
    ''';

    final outerWhere = <String>[
      '('
          'COALESCE(base.alis_fatura_matrah, 0) <> 0'
          ' OR COALESCE(base.satis_fatura_matrah, 0) <> 0'
          ' OR COALESCE(base.alis_fatura_adet, 0) <> 0'
          ' OR COALESCE(base.satis_fatura_adet, 0) <> 0'
          ')',
    ];

    final String? hesapTuru = _emptyToNull(filtreler.hesapTuru);
    if (hesapTuru != null) {
      params['hesapTuru'] = hesapTuru;
      outerWhere.add(
        "normalize_text(COALESCE(base.hesap_turu, '')) = normalize_text(@hesapTuru)",
      );
    }

    _addSearchConditionAny(outerWhere, params, [
      'COALESCE(base.search_tags, \'\')',
      "normalize_text(COALESCE(base.kod, ''))",
      "normalize_text(COALESCE(base.ad, ''))",
      "normalize_text(COALESCE(base.hesap_turu, ''))",
      // Numeric columns (best-effort, matches raw DB representation)
      'COALESCE(base.alis_fatura_matrah, 0)::text',
      'COALESCE(base.satis_fatura_matrah, 0)::text',
      'COALESCE(base.alis_fatura_adet, 0)::text',
      'COALESCE(base.satis_fatura_adet, 0)::text',
    ], effectiveArama);

    final String whereSql = outerWhere.isEmpty
        ? ''
        : 'WHERE ${outerWhere.join(' AND ')}';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
      $whereSql
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'gid',
    );

    final mappedRows = pageResult.rows
        .map((row) {
          final int id = _toInt(row['gid']) ?? 0;
          final String kod = row['kod']?.toString() ?? '-';
          final String ad = row['ad']?.toString() ?? '-';
          final String hesapTuruRaw = row['hesap_turu']?.toString() ?? '';
          final String paraBirimi = row['para_birimi']?.toString() ?? 'TRY';
          final double alisMatrah = _toDouble(row['alis_fatura_matrah']);
          final double satisMatrah = _toDouble(row['satis_fatura_matrah']);
          final int alisAdet = _toInt(row['alis_fatura_adet']) ?? 0;
          final int satisAdet = _toInt(row['satis_fatura_adet']) ?? 0;

          return RaporSatiri(
            id: 'ba_bs_$id',
            cells: {
              'kod': kod,
              'ad': ad,
              'tur': IslemCeviriYardimcisi.cevir(hesapTuruRaw),
              'alis_fatura_matrah': _formatMoney(
                alisMatrah,
                currency: paraBirimi,
              ),
              'satis_fatura_matrah': _formatMoney(
                satisMatrah,
                currency: paraBirimi,
              ),
              'alis_fatura_adet': '$alisAdet',
              'satis_fatura_adet': '$satisAdet',
            },
            sourceMenuIndex: TabAciciScope.cariKartiIndex,
            sourceSearchQuery: ad,
            amountValue: satisMatrah - alisMatrah,
            sortValues: {
              'kod': kod,
              'ad': ad,
              'tur': hesapTuruRaw,
              'alis_fatura_matrah': alisMatrah,
              'satis_fatura_matrah': satisMatrah,
              'alis_fatura_adet': alisAdet,
              'satis_fatura_adet': satisAdet,
            },
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summary = await _getOrComputeBaBsSummary(
      cacheKey: summaryKey,
      loader: () async {
        final rows = await _queryMaps(pool, '''
          SELECT
            COUNT(*) AS kayit,
            COUNT(DISTINCT base.para_birimi) AS currency_count,
            MIN(base.para_birimi) AS currency_one,
            COALESCE(SUM(base.alis_fatura_matrah), 0) AS alis_fatura_matrah,
            COALESCE(SUM(base.satis_fatura_matrah), 0) AS satis_fatura_matrah,
            COALESCE(SUM(base.alis_fatura_adet), 0) AS alis_fatura_adet,
            COALESCE(SUM(base.satis_fatura_adet), 0) AS satis_fatura_adet
          FROM ($baseSelect) base
          $whereSql
          ''', params);
        final data = rows.isEmpty ? const <String, dynamic>{} : rows.first;

        final int kayit = _toInt(data['kayit']) ?? 0;
        final int currencyCount = _toInt(data['currency_count']) ?? 0;
        final String currency = currencyCount == 1
            ? (data['currency_one']?.toString() ?? '')
            : '';

        final double toplamAlisMatrah = _toDouble(data['alis_fatura_matrah']);
        final double toplamSatisMatrah = _toDouble(data['satis_fatura_matrah']);
        final int toplamAlisAdet = _toInt(data['alis_fatura_adet']) ?? 0;
        final int toplamSatisAdet = _toInt(data['satis_fatura_adet']) ?? 0;

        final cards = <RaporOzetKarti>[
          RaporOzetKarti(
            labelKey: 'Alış Fatura Matrah',
            value: _formatMoney(toplamAlisMatrah, currency: currency),
            icon: Icons.shopping_cart_checkout_rounded,
            accentColor: AppPalette.amber,
          ),
          RaporOzetKarti(
            labelKey: 'Satış Fatura Matrah',
            value: _formatMoney(toplamSatisMatrah, currency: currency),
            icon: Icons.point_of_sale_rounded,
            accentColor: AppPalette.red,
          ),
          RaporOzetKarti(
            labelKey: 'Alış Fatura Adet',
            value: '$toplamAlisAdet',
            icon: Icons.receipt_long_outlined,
            accentColor: AppPalette.slate,
          ),
          RaporOzetKarti(
            labelKey: 'Satış Fatura Adet',
            value: '$toplamSatisAdet',
            icon: Icons.receipt_long_outlined,
            accentColor: AppPalette.slate,
          ),
        ];
        return (totalCount: kayit, cards: cards);
      },
    );
    final summaryCards = summary.cards;
    final int totalCount = summary.totalCount;

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('kod', 'Kod no', 110),
        _column('ad', 'Adı', 220),
        _column('tur', 'Hesap Türü', 140),
        _column(
          'alis_fatura_matrah',
          'Alış Fatura Matrah',
          150,
          alignment: Alignment.centerRight,
        ),
        _column(
          'satis_fatura_matrah',
          'Satış Fatura Matrah',
          150,
          alignment: Alignment.centerRight,
        ),
        _column(
          'alis_fatura_adet',
          'Alış Fatura Adet',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'satis_fatura_adet',
          'Satış Fatura Adet',
          130,
          alignment: Alignment.centerRight,
        ),
      ],
      rows: mappedRows,
      summaryCards: summaryCards,
      totalCount: totalCount,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  /// Satış/Alış entegrasyon referansı (SALE-/PURCHASE-/RETAIL-) üzerinden
  /// sevkiyat kalemlerini çekip raporlarda genişleyen "Ürünler" tablosu olarak döndürür.
  ///
  /// Not: Kalemler `shipments.items` JSON alanından gelir.
  Future<DetailTable?> entegrasyonUrunDetayTablosuGetir(
    String integrationRef, {
    String? aciklama,
  }) async {
    final ref = integrationRef.trim();
    if (ref.isEmpty) return null;

    final pool = await _havuzAl();
    final rows = await _queryMaps(
      pool,
      '''
      SELECT COALESCE(json_agg(items), '[]'::json) AS items
      FROM shipments
      WHERE integration_ref = @ref
    ''',
      {'ref': ref},
    );

    if (rows.isEmpty) return null;

    final List<Map<String, dynamic>> items = _extractDetailItems(
      rows.first['items'],
    );
    if (items.isEmpty) return null;

    final String safeAciklama = (aciklama ?? '').trim();
    final List<Map<String, dynamic>> enriched = safeAciklama.isEmpty
        ? items
        : items
              .map((e) => <String, dynamic>{...e, 'aciklama': safeAciklama})
              .toList(growable: false);

    return _detailTableFromItems(enriched, title: tr('common.last_movements'));
  }

  List<ExpandableRowData> yazdirmaSatirlariniHazirla({
    required List<RaporSatiri> rows,
    required List<RaporKolonTanimi> visibleColumns,
    required Set<String> expandedIds,
    required bool keepDetailsOpen,
  }) {
    return rows.map((row) {
      final List<String> mainRow = visibleColumns
          .map((column) => row.cells[column.key] ?? '-')
          .toList();

      return ExpandableRowData(
        mainRow: mainRow,
        details: row.details,
        transactions: row.detailTable,
        isExpanded:
            row.expandable && (keepDetailsOpen || expandedIds.contains(row.id)),
        isSourceExpanded:
            row.expandable && (keepDetailsOpen || expandedIds.contains(row.id)),
      );
    }).toList();
  }

  String filtreOzetiniOlustur(RaporFiltreleri filtreler) {
    final List<String> parcalar = <String>[];
    final DateFormat format = DateFormat('dd.MM.yyyy');

    if (filtreler.baslangicTarihi != null || filtreler.bitisTarihi != null) {
      final String baslangic = filtreler.baslangicTarihi != null
          ? format.format(filtreler.baslangicTarihi!)
          : '...';
      final String bitis = filtreler.bitisTarihi != null
          ? format.format(filtreler.bitisTarihi!)
          : '...';
      parcalar.add('${tr('common.date_range')}: $baslangic - $bitis');
    }
    if (filtreler.belgeNo != null && filtreler.belgeNo!.trim().isNotEmpty) {
      parcalar.add(
        '${tr('reports.filters.document_no')}: ${filtreler.belgeNo}',
      );
    }
    if (filtreler.referansNo != null &&
        filtreler.referansNo!.trim().isNotEmpty) {
      parcalar.add(
        '${tr('reports.filters.reference_no')}: ${filtreler.referansNo}',
      );
    }
    if (filtreler.islemTuru != null && filtreler.islemTuru!.trim().isNotEmpty) {
      parcalar.add('${tr('common.transaction_type')}: ${filtreler.islemTuru}');
    }
    if (filtreler.durum != null && filtreler.durum!.trim().isNotEmpty) {
      parcalar.add('${tr('common.status')}: ${filtreler.durum}');
    }

    return parcalar.join(' | ');
  }

  String dosyaAdiOlustur(RaporSecenegi rapor) {
    final now = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final raw = tr(rapor.labelKey)
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll('/', '_')
        .replaceAll(RegExp(r'[^a-z0-9ğüşöçıİĞÜŞÖÇ_]'), '');
    return '${raw}_$now';
  }

  Future<Pool<void>> _havuzAl() {
    return VeritabaniHavuzu().havuzAl(
      database: OturumServisi().aktifVeritabaniAdi,
    );
  }

  Future<List<Map<String, dynamic>>> _queryMaps(
    Pool<void> pool,
    String query,
    Map<String, dynamic> params,
  ) async {
    final result = await pool.execute(
      Sql.named(query),
      parameters: _filteredSqlParams(query, params),
    );
    return result.map((row) => row.toColumnMap()).toList(growable: false);
  }

  Map<String, dynamic> _filteredSqlParams(
    String query,
    Map<String, dynamic> params,
  ) {
    final used = RegExp(
      r'@([A-Za-z_][A-Za-z0-9_]*)',
    ).allMatches(query).map((match) => match.group(1)!).toSet();
    return <String, dynamic>{
      for (final entry in params.entries)
        if (used.contains(entry.key)) entry.key: entry.value,
    };
  }

  Future<int> _queryCount(
    Pool<void> pool,
    String query,
    Map<String, dynamic> params,
  ) async {
    final rows = await _queryMaps(pool, query, params);
    if (rows.isEmpty) return 0;
    return (rows.first.values.first as num?)?.toInt() ?? 0;
  }

  Future<
    ({List<Map<String, dynamic>> rows, bool hasNextPage, String? nextCursor})
  >
  _fetchKeysetPageById({
    required Pool<void> pool,
    required String baseQuery,
    required Map<String, dynamic> paramsBase,
    required String sortAlias,
    required bool sortAscending,
    required int pageSize,
    String? cursor,
    String idColumn = 'id',
  }) async {
    final int safePageSize = pageSize.clamp(1, 5000);
    final int limit = safePageSize + 1;

    final pagingWhere = <String>[];
    final paramsPaging = <String, dynamic>{...paramsBase, 'limit': limit};

    final int? lastId = _decodeCursorLastId(cursor);
    if (lastId != null && lastId > 0) {
      bool? lastIsNull;
      dynamic lastSort;

      try {
        final cursorRows = await _queryMaps(
          pool,
          '''
          SELECT (q.$sortAlias IS NULL) AS is_null, q.$sortAlias AS sort_val
          FROM ($baseQuery) q
          WHERE q.$idColumn = @cursorId
          LIMIT 1
          ''',
          <String, dynamic>{...paramsBase, 'cursorId': lastId},
        );
        if (cursorRows.isNotEmpty) {
          lastIsNull = cursorRows.first['is_null'] as bool?;
          lastSort = cursorRows.first['sort_val'];
        }
      } catch (_) {
        // ignore: fall back to id cursor
      }

      final String op = sortAscending ? '>' : '<';
      if (lastIsNull != null && lastSort != null) {
        pagingWhere.add(
          '((q.$sortAlias IS NULL), q.$sortAlias, q.$idColumn) $op (@lastIsNull, @lastSort, @lastId)',
        );
        paramsPaging['lastIsNull'] = lastIsNull;
        paramsPaging['lastSort'] = lastSort;
        paramsPaging['lastId'] = lastId;
      } else if (lastSort != null) {
        pagingWhere.add(
          '(q.$sortAlias $op @lastSort OR (q.$sortAlias = @lastSort AND q.$idColumn $op @lastId))',
        );
        paramsPaging['lastSort'] = lastSort;
        paramsPaging['lastId'] = lastId;
      } else {
        pagingWhere.add('q.$idColumn $op @lastId');
        paramsPaging['lastId'] = lastId;
      }
    }

    final String whereSql = pagingWhere.isEmpty
        ? ''
        : 'WHERE ${pagingWhere.join(' AND ')}';

    final String direction = sortAscending ? 'ASC' : 'DESC';
    final String query =
        '''
      SELECT q.*
      FROM ($baseQuery) q
      $whereSql
      ORDER BY (q.$sortAlias IS NULL) $direction, q.$sortAlias $direction, q.$idColumn $direction
      LIMIT @limit
    ''';

    final fetched = await _queryMaps(pool, query, paramsPaging);

    final bool hasNext = fetched.length > safePageSize;
    final pageRows = hasNext ? fetched.take(safePageSize).toList() : fetched;

    final int? nextId = hasNext && pageRows.isNotEmpty
        ? _toInt(pageRows.last[idColumn])
        : null;
    final String? nextCursor = nextId != null && nextId > 0
        ? _encodeCursorLastId(nextId)
        : null;

    return (rows: pageRows, hasNextPage: hasNext, nextCursor: nextCursor);
  }

  void _addSearchCondition(
    List<String> conditions,
    Map<String, dynamic> params,
    String expression,
    String arama,
  ) {
    final tokens = _searchTokens(arama);
    if (tokens.isEmpty) return;
    _bindSearchTokenParams(params, tokens);
    conditions.add(_tokenLikeClause(expression, tokens.length));
  }

  /// [2026 PERF] Raporlar araması tamamen index-dostu (GIN+trgm) LIKE üzerinden akar.
  ///
  /// - `to_tsvector(...)` OR koşulu büyük tablolarda planı bozup seq-scan'a iter.
  /// - Bunun yerine token'ları AND'leyerek FTS benzeri davranışı koruruz:
  ///   `col LIKE %t1% AND col LIKE %t2% ...`
  /// - Tokenlar en az 2 karakter olmalı (1 harf araması 100B'de patlar).
  List<String> _searchTokens(String arama) {
    final normalized = _normalizeArama(arama);
    if (normalized.isEmpty) return const <String>[];
    final raw = normalized
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.length >= 2)
        .toList(growable: false);
    if (raw.isEmpty) return const <String>[];
    // Güvenlik üst sınırı: çok uzun sorgu AND zinciri üretmesin.
    return raw.length <= 8 ? raw : raw.take(8).toList(growable: false);
  }

  /// Rapor aramasında sayısal değerler formatlı görünebilir (örn: `2.500,32`)
  /// ama arama kutusunda kullanıcı ayıraçsız yazabilir (örn: `250032`).
  ///
  /// Rapor sorgularında sayılar DB'den çoğunlukla `2500.32` (noktalı) olarak
  /// gelir. Bu nedenle sadece rakam içeren aramaları (>= 5 hane) iki parçaya
  /// bölerek eşleşmeyi kolaylaştırır:
  /// - `250032` -> `2500 32`  (hem `250032` hem `2500.32` ile eşleşir)
  /// - `150000` -> `1500 00`  (hem `150000` hem `1500.00` ile eşleşir)
  String _normalizeNumericSearchForReports(String arama) {
    final raw = arama.trim();
    if (raw.isEmpty) return arama;
    if (!RegExp(r'^[0-9]+$').hasMatch(raw)) return arama;
    // 4 hane ve altı (örn: 2500) doğrudan aranabilir.
    // (Tokenlara bölmek aşırı geniş eşleşme üretebilir.)
    if (raw.length <= 4) return arama;

    final int splitIndex = raw.length - 2;
    final String intPart = raw.substring(0, splitIndex);
    final String fracPart = raw.substring(splitIndex);

    return '$intPart $fracPart';
  }

  void _bindSearchTokenParams(
    Map<String, dynamic> params,
    List<String> tokens,
  ) {
    for (var i = 0; i < tokens.length; i++) {
      params['search$i'] = '%${tokens[i]}%';
    }
  }

  String _tokenLikeClause(String expression, int tokenCount) {
    final parts = <String>[];
    for (var i = 0; i < tokenCount; i++) {
      parts.add('$expression LIKE @search$i');
    }
    return '(${parts.join(' AND ')})';
  }

  void _addSearchConditionAny(
    List<String> conditions,
    Map<String, dynamic> params,
    List<String> expressions,
    String arama,
  ) {
    final tokens = _searchTokens(arama);
    if (tokens.isEmpty) return;
    _bindSearchTokenParams(params, tokens);
    final tokenCount = tokens.length;

    final parts = expressions
        .map((expr) => _tokenLikeClause(expr, tokenCount))
        .toList(growable: false);
    if (parts.isEmpty) return;
    conditions.add('(${parts.join(' OR ')})');
  }

  String _normalizeArama(String text) {
    if (text.trim().isEmpty) return '';
    return text
        .toLowerCase()
        .replaceAll('i̇', 'i')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Map<String, dynamic>? _decodeCursorPayload(String? cursor) {
    final raw = _emptyToNull(cursor);
    if (raw == null) return null;
    try {
      final decoded = utf8.decode(base64Url.decode(raw));
      final dynamic json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) return json;
      return null;
    } catch (_) {
      return null;
    }
  }

  String _encodeCursorPayload(Map<String, dynamic> payload) {
    return base64Url.encode(utf8.encode(jsonEncode(payload)));
  }

  int? _decodeCursorLastId(String? cursor) {
    final payload = _decodeCursorPayload(cursor);
    if (payload == null) return null;
    final dynamic id = payload['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    if (id is String) return int.tryParse(id);
    return null;
  }

  String _encodeCursorLastId(int id) {
    return _encodeCursorPayload(<String, dynamic>{'id': id});
  }

  Future<String?> _resolveKullaniciAdi(String? kullaniciId) async {
    final id = _emptyToNull(kullaniciId);
    if (id == null) return null;
    final kaynaklar = await filtreKaynaklariniGetir();
    for (final secenek in kaynaklar.kullanicilar) {
      if (secenek.value != id) continue;
      final model = secenek.extra['model'];
      if (model is KullaniciModel) {
        return model.kullaniciAdi.trim().isEmpty ? null : model.kullaniciAdi;
      }
      final label = secenek.label.trim();
      if (label.isEmpty) return null;
      final splitIndex = label.indexOf(' (');
      return splitIndex > 0 ? label.substring(0, splitIndex) : label;
    }
    return null;
  }

  Future<RaporSonucu> _buildOptimizedSiparisTeklifRaporu(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required bool siparisMi,
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final kullaniciAdi = await _resolveKullaniciAdi(filtreler.kullaniciId);
    final String table = siparisMi ? 'orders' : 'quotes';
    final String docCol = siparisMi ? 'order_no' : 'quote_no';

    String sortColumn(String? key) {
      switch (key) {
        case 'tarih':
          return 't.tarih';
        case 'belge_no':
          return "COALESCE(t.$docCol, COALESCE(t.integration_ref, ''))";
        case 'cari':
          return "COALESCE(t.cari_adi, '')";
        case 'tutar':
          return 't.tutar';
        case 'durum':
          return "COALESCE(t.durum, '')";
        case 'termin':
          return 't.gecerlilik_tarihi';
        case 'donusum':
          return "COALESCE(t.tur, '')";
        case 'kullanici':
          return "COALESCE(t.kullanici, '')";
        default:
          return 't.tarih';
      }
    }

    final whereBase = <String>[];
    final paramsBase = <String, dynamic>{};

    if (filtreler.baslangicTarihi != null) {
      paramsBase['baslangic'] = DateTime(
        filtreler.baslangicTarihi!.year,
        filtreler.baslangicTarihi!.month,
        filtreler.baslangicTarihi!.day,
      ).toIso8601String();
      whereBase.add('t.tarih >= @baslangic');
    }
    if (filtreler.bitisTarihi != null) {
      paramsBase['bitis'] = DateTime(
        filtreler.bitisTarihi!.year,
        filtreler.bitisTarihi!.month,
        filtreler.bitisTarihi!.day,
      ).add(const Duration(days: 1)).toIso8601String();
      whereBase.add('t.tarih < @bitis');
    }
    if (filtreler.cariId != null) {
      paramsBase['cariId'] = filtreler.cariId;
      whereBase.add('t.cari_id = @cariId');
    }
    if (_emptyToNull(kullaniciAdi) != null) {
      paramsBase['kullanici'] = _emptyToNull(kullaniciAdi);
      whereBase.add("COALESCE(t.kullanici, '') = @kullanici");
    }
    if (_normalizedSelection(filtreler.durum).isNotEmpty) {
      paramsBase['durum'] = _normalizedSelection(filtreler.durum);
      whereBase.add("COALESCE(t.durum, '') = @durum");
    }
    if (_emptyToNull(filtreler.belgeNo) != null) {
      paramsBase['belgeNo'] = '%${_normalizeArama(filtreler.belgeNo!)}%';
      whereBase.add(
        "LOWER(COALESCE(t.$docCol, COALESCE(t.integration_ref, ''))) LIKE @belgeNo",
      );
    }
    if (filtreler.minTutar != null) {
      paramsBase['minTutar'] = filtreler.minTutar;
      whereBase.add('t.tutar >= @minTutar');
    }
    if (filtreler.maxTutar != null) {
      paramsBase['maxTutar'] = filtreler.maxTutar;
      whereBase.add('t.tutar <= @maxTutar');
    }

    _addSearchCondition(
      whereBase,
      paramsBase,
      "COALESCE(t.search_tags, '')",
      arama,
    );

    final wherePaging = <String>[...whereBase];
    final paramsPaging = <String, dynamic>{...paramsBase};

    final String direction = sortAscending ? 'ASC' : 'DESC';
    final String orderBy = sortColumn(sortKey);
    final int limit = pageSize.clamp(1, 5000) + 1;
    paramsPaging['limit'] = limit;

    final int? lastId = _decodeCursorLastId(cursor);
    if (lastId != null && lastId > 0) {
      dynamic lastSortValue;
      if (orderBy != 't.id') {
        try {
          final cursorRow = await _queryMaps(
            pool,
            'SELECT $orderBy AS sort_val FROM $table t WHERE t.id = @id LIMIT 1',
            {'id': lastId},
          );
          if (cursorRow.isNotEmpty) {
            lastSortValue = cursorRow.first['sort_val'];
          }
        } catch (_) {}
      }

      final String op = sortAscending ? '>' : '<';
      if (orderBy == 't.id' || lastSortValue == null) {
        wherePaging.add('t.id $op @lastId');
        paramsPaging['lastId'] = lastId;
      } else {
        wherePaging.add(
          '($orderBy $op @lastSort OR ($orderBy = @lastSort AND t.id $op @lastId))',
        );
        paramsPaging['lastSort'] = lastSortValue;
        paramsPaging['lastId'] = lastId;
      }
    }

    final String whereSqlPaging = wherePaging.isEmpty
        ? ''
        : 'WHERE ${wherePaging.join(' AND ')}';
    final String whereSqlBase = whereBase.isEmpty
        ? ''
        : 'WHERE ${whereBase.join(' AND ')}';

    final rows = await _queryMaps(pool, '''
      SELECT
        t.id,
        t.tarih,
        t.$docCol AS belge_no,
        t.integration_ref,
        t.cari_kod,
        t.cari_adi,
        t.ilgili_hesap_adi,
        t.tutar,
        t.durum,
        t.tur,
        t.gecerlilik_tarihi,
        t.para_birimi,
        t.kullanici
      FROM $table t
      $whereSqlPaging
      ORDER BY $orderBy $direction, t.id $direction
      LIMIT @limit
      ''', paramsPaging);

    final bool hasNext = rows.length > pageSize;
    final pageRows = hasNext ? rows.take(pageSize).toList() : rows;
    final String? nextCursor = hasNext && pageRows.isNotEmpty
        ? _encodeCursorLastId((pageRows.last['id'] as num).toInt())
        : null;

    final mapped = pageRows
        .map((tx) {
          final DateTime? tarih = _toDateTime(tx['tarih']);
          final DateTime? termin =
              _toDateTime(tx['gecerlilik_tarihi']) ?? tarih;
          final String paraBirimi = tx['para_birimi']?.toString() ?? 'TRY';
          final String belgeNo =
              (tx['belge_no']?.toString().trim() ?? '').isEmpty
              ? (tx['integration_ref']?.toString() ?? '-')
              : tx['belge_no']?.toString() ?? '-';
          final double tutar = _toDouble(tx['tutar']);
          final String cariKod = tx['cari_kod']?.toString() ?? '-';
          final String cariAdi = tx['cari_adi']?.toString() ?? '-';

          return RaporSatiri(
            id: '${siparisMi ? 'sip' : 'tek'}_${tx['id']}',
            cells: {
              'tarih': _formatDate(tarih, includeTime: true),
              'belge_no': belgeNo,
              'cari': '$cariKod - $cariAdi'.trim(),
              'tutar': _formatMoney(tutar, currency: paraBirimi),
              'durum': tx['durum']?.toString() ?? '-',
              'termin': _formatDate(termin),
              'donusum': tx['tur']?.toString() ?? '-',
              'kullanici': tx['kullanici']?.toString() ?? '-',
            },
            sourceMenuIndex: siparisMi ? 18 : 19,
            sourceSearchQuery: tx['cari_adi']?.toString(),
            amountValue: tutar,
            sortValues: {
              'tarih': tarih,
              'belge_no': belgeNo,
              'cari': cariAdi,
              'tutar': tutar,
              'durum': tx['durum'],
              'termin': termin,
              'donusum': tx['tur'],
              'kullanici': tx['kullanici'],
            },
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
      extra: siparisMi ? 'sip' : 'tek',
    );
    final summaryCards = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final summaryRows = await _queryMaps(pool, '''
          SELECT
            COUNT(*) AS kayit,
            COALESCE(SUM(t.tutar), 0) AS toplam
          FROM $table t
          $whereSqlBase
          ''', paramsBase);
        final data = summaryRows.isEmpty
            ? const <String, dynamic>{}
            : summaryRows.first;
        final int kayit = (data['kayit'] as num?)?.toInt() ?? 0;
        final double toplam = _toDouble(data['toplam']);
        return [
          RaporOzetKarti(
            labelKey: siparisMi
                ? 'reports.summary.active_orders'
                : 'reports.summary.active_quotes',
            value: '$kayit',
            icon: siparisMi
                ? Icons.shopping_bag_outlined
                : Icons.request_quote_outlined,
            accentColor: siparisMi ? AppPalette.slate : AppPalette.amber,
          ),
          RaporOzetKarti(
            labelKey: 'reports.summary.total_amount',
            value: _formatMoney(toplam),
            icon: Icons.payments_outlined,
            accentColor: AppPalette.red,
          ),
        ];
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tarih', 'common.date', 150),
        _column('belge_no', 'reports.columns.document_no', 130),
        _column('cari', 'reports.columns.current_account', 220),
        _column(
          'tutar',
          'common.amount',
          130,
          alignment: Alignment.centerRight,
        ),
        _column('durum', 'common.status', 110),
        _column('termin', 'reports.columns.termin', 120),
        _column('donusum', 'reports.columns.conversion', 120),
        _column('kullanici', 'common.user', 100),
      ],
      rows: mapped,
      summaryCards: summaryCards,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: hasNext,
      cursorPagination: true,
      nextCursor: nextCursor,
      mainTableLabel: tr(rapor.labelKey),
      detailTableLabel: tr('common.products'),
    );
  }

  Future<RaporSonucu> _buildOptimizedCekSenetRaporu(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required bool cekMi,
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();

    final String table = cekMi ? 'cheques' : 'promissory_notes';
    final String txTable = cekMi ? 'cheque_transactions' : 'note_transactions';
    final String txIdColumn = cekMi ? 'cheque_id' : 'note_id';
    final String docCol = cekMi ? 'check_no' : 'note_no';

    String sortExpr(String? key) {
      switch (key) {
        case 'tur':
          return "COALESCE(base.tur, '')";
        case 'belge_no':
          return "COALESCE(base.belge_no, COALESCE(base.integration_ref, ''))";
        case 'cari':
          return "COALESCE(base.cari_adi, '')";
        case 'vade':
          return 'base.vade';
        case 'tutar':
          return 'base.tutar';
        case 'durum':
          return 'base.aktif_mi';
        case 'portfoy':
          return "COALESCE(base.portfoy, '')";
        case 'kullanici':
          return "COALESCE(base.kullanici, '')";
        default:
          return 'base.vade';
      }
    }

    final where = <String>[
      "COALESCE(t.company_id, '$_defaultCompanyId') = @companyId",
    ];
    final params = <String, dynamic>{'companyId': _companyId};

    if (filtreler.baslangicTarihi != null || filtreler.bitisTarihi != null) {
      final existsConds = <String>[
        'ct.$txIdColumn = t.id',
        "COALESCE(ct.company_id, '$_defaultCompanyId') = @companyId",
      ];
      if (filtreler.baslangicTarihi != null) {
        params['startDate'] = DateTime(
          filtreler.baslangicTarihi!.year,
          filtreler.baslangicTarihi!.month,
          filtreler.baslangicTarihi!.day,
        ).toIso8601String();
        existsConds.add('ct.date >= @startDate');
      }
      if (filtreler.bitisTarihi != null) {
        params['endDate'] = DateTime(
          filtreler.bitisTarihi!.year,
          filtreler.bitisTarihi!.month,
          filtreler.bitisTarihi!.day,
        ).add(const Duration(days: 1)).toIso8601String();
        existsConds.add('ct.date < @endDate');
      }
      where.add(
        'EXISTS (SELECT 1 FROM $txTable ct WHERE ${existsConds.join(' AND ')})',
      );
    }

    if (filtreler.cariId != null) {
      final cariRows = await _queryMaps(
        pool,
        'SELECT kod_no FROM current_accounts WHERE id = @id LIMIT 1',
        {'id': filtreler.cariId},
      );
      final String cariKod = cariRows.isEmpty
          ? ''
          : (cariRows.first['kod_no']?.toString() ?? '');
      if (cariKod.trim().isEmpty) {
        return RaporSonucu(
          report: rapor,
          columns: [
            _column('tur', 'common.type', 120),
            _column('belge_no', 'reports.columns.document_no', 140),
            _column('cari', 'reports.columns.current_account', 220),
            _column('vade', 'common.due_date_short', 120),
            _column(
              'tutar',
              'common.amount',
              130,
              alignment: Alignment.centerRight,
            ),
            _column('durum', 'common.status', 100),
            _column('portfoy', 'reports.columns.portfolio', 140),
            _column('kullanici', 'common.user', 100),
          ],
          rows: const <RaporSatiri>[],
          totalCount: 0,
          page: page,
          pageSize: pageSize,
          hasNextPage: false,
          cursorPagination: true,
          nextCursor: null,
          mainTableLabel: tr(rapor.labelKey),
        );
      }
      params['cariKod'] = cariKod;
      where.add("COALESCE(t.customer_code, '') = @cariKod");
    }

    final String durum = _normalizedSelection(filtreler.durum);
    if (durum.isNotEmpty) {
      final norm = _normalizeArama(durum);
      if (norm == 'aktif') {
        where.add('t.is_active = 1');
      } else if (norm == 'pasif') {
        where.add('t.is_active = 0');
      } else {
        params['durumSearch'] = '%$norm%';
        where.add(
          "normalize_text(COALESCE(t.collection_status, '')) LIKE @durumSearch",
        );
      }
    }

    if (_emptyToNull(filtreler.belgeNo) != null) {
      params['belgeNo'] = '%${_normalizeArama(filtreler.belgeNo!)}%';
      where.add(
        "normalize_text(COALESCE(t.$docCol, COALESCE(t.integration_ref, ''))) LIKE @belgeNo",
      );
    }

    _addSearchCondition(where, params, 't.search_tags', arama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final baseSelect =
        '''
      SELECT
        t.id,
        t.type AS tur,
        t.$docCol AS belge_no,
        t.integration_ref,
        t.customer_name AS cari_adi,
        t.due_date AS vade,
        t.issue_date AS issue_date,
        t.amount AS tutar,
        t.currency AS para_birimi,
        t.is_active AS aktif_mi,
        t.collection_status AS tahsilat,
        t.bank AS portfoy,
        t.user_name AS kullanici,
        t.description AS aciklama
      FROM $table t
      $whereSql
    ''';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'id',
    );

    final mapped = pageResult.rows
        .map((item) {
          final DateTime? vade = _toDateTime(item['vade']);
          final DateTime? issueDate = _toDateTime(item['issue_date']);
          final bool aktif = item['aktif_mi'] == true || item['aktif_mi'] == 1;
          final double tutar = _toDouble(item['tutar']);
          final String paraBirimi = item['para_birimi']?.toString() ?? 'TRY';
          final String belgeNo =
              (item['belge_no']?.toString().trim() ?? '').isEmpty
              ? (item['integration_ref']?.toString() ?? '-')
              : item['belge_no']?.toString() ?? '-';

          return RaporSatiri(
            id: '${cekMi ? 'cek' : 'senet'}_${item['id']}',
            cells: {
              'tur': IslemCeviriYardimcisi.cevir(
                item['tur']?.toString() ?? '-',
              ),
              'belge_no': belgeNo,
              'cari': item['cari_adi']?.toString() ?? '-',
              'vade': _formatDate(vade),
              'tutar': _formatMoney(tutar, currency: paraBirimi),
              'durum': aktif ? tr('common.active') : tr('common.passive'),
              'portfoy': item['portfoy']?.toString() ?? '-',
              'kullanici': item['kullanici']?.toString() ?? '-',
            },
            details: {
              tr('common.description'): item['aciklama']?.toString() ?? '-',
              tr('reports.columns.collection_type'):
                  item['tahsilat']?.toString() ?? '-',
              tr('reports.columns.issue_date'): _formatDate(issueDate),
            },
            sourceMenuIndex: cekMi ? 14 : 17,
            sourceSearchQuery: belgeNo,
            amountValue: tutar,
            sortValues: {
              'tur': item['tur']?.toString(),
              'belge_no': belgeNo,
              'cari': item['cari_adi']?.toString(),
              'vade': vade,
              'tutar': tutar,
              'durum': aktif ? 1 : 0,
              'portfoy': item['portfoy']?.toString(),
              'kullanici': item['kullanici']?.toString(),
            },
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
      extra: cekMi ? 'cek' : 'senet',
    );
    final summary = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final sumRows = await _queryMaps(pool, '''
          SELECT COALESCE(SUM(t.amount), 0) AS toplam
          FROM $table t
          $whereSql
          ''', params);
        final toplam = sumRows.isEmpty
            ? 0.0
            : _toDouble(sumRows.first['toplam']);
        return [
          RaporOzetKarti(
            labelKey: 'reports.summary.portfolio_total',
            value: _formatMoney(toplam),
            icon: Icons.receipt_long_outlined,
            accentColor: cekMi ? AppPalette.slate : AppPalette.amber,
          ),
        ];
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tur', 'common.type', 120),
        _column('belge_no', 'reports.columns.document_no', 140),
        _column('cari', 'reports.columns.current_account', 220),
        _column('vade', 'common.due_date_short', 120),
        _column(
          'tutar',
          'common.amount',
          130,
          alignment: Alignment.centerRight,
        ),
        _column('durum', 'common.status', 100),
        _column('portfoy', 'reports.columns.portfolio', 140),
        _column('kullanici', 'common.user', 100),
      ],
      rows: mapped,
      summaryCards: summary,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildOptimizedGiderRaporu(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final kullaniciAdi = await _resolveKullaniciAdi(filtreler.kullaniciId);

    String sortExpr(String? key) {
      switch (key) {
        case 'tarih':
          return 'base.tarih';
        case 'kod':
          return "COALESCE(base.kod, '')";
        case 'kalem':
          return "COALESCE(base.baslik, '')";
        case 'kategori':
          return "COALESCE(base.kategori, '')";
        case 'tutar':
          return 'base.tutar';
        case 'odeme_tipi':
          return "COALESCE(base.odeme_durumu, '')";
        case 'aciklama':
          return "COALESCE(base.aciklama, '')";
        case 'kullanici':
          return "COALESCE(base.kullanici, '')";
        default:
          return 'base.tarih';
      }
    }

    final where = <String>[];
    final params = <String, dynamic>{};

    if (filtreler.baslangicTarihi != null) {
      params['baslangic'] = DateTime(
        filtreler.baslangicTarihi!.year,
        filtreler.baslangicTarihi!.month,
        filtreler.baslangicTarihi!.day,
      ).toIso8601String();
      where.add('e.tarih >= @baslangic');
    }
    if (filtreler.bitisTarihi != null) {
      params['bitis'] = DateTime(
        filtreler.bitisTarihi!.year,
        filtreler.bitisTarihi!.month,
        filtreler.bitisTarihi!.day,
      ).add(const Duration(days: 1)).toIso8601String();
      where.add('e.tarih < @bitis');
    }

    if (_normalizedSelection(filtreler.durum).isNotEmpty) {
      params['durum'] = _normalizedSelection(filtreler.durum);
      where.add("COALESCE(e.odeme_durumu, '') = @durum");
    }

    if (_emptyToNull(kullaniciAdi) != null) {
      params['kullanici'] = _emptyToNull(kullaniciAdi);
      where.add("COALESCE(e.kullanici, '') = @kullanici");
    }

    if (filtreler.minTutar != null) {
      params['minTutar'] = filtreler.minTutar;
      where.add('e.tutar >= @minTutar');
    }
    if (filtreler.maxTutar != null) {
      params['maxTutar'] = filtreler.maxTutar;
      where.add('e.tutar <= @maxTutar');
    }

    _addSearchCondition(where, params, 'e.search_tags', arama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final baseSelect =
        '''
      SELECT
        e.id,
        e.tarih,
        e.kod,
        e.baslik,
        e.kategori,
        e.tutar,
        e.para_birimi,
        e.odeme_durumu,
        e.aciklama,
        e.not_metni,
        e.kullanici
      FROM expenses e
      $whereSql
    ''';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'id',
    );

    final ids = pageResult.rows
        .map((row) => _toInt(row['id']) ?? 0)
        .where((id) => id > 0)
        .toList(growable: false);

    final Map<int, List<Map<String, dynamic>>> kalemlerByGider =
        <int, List<Map<String, dynamic>>>{};
    if (ids.isNotEmpty) {
      final items = await _queryMaps(
        pool,
        '''
        SELECT expense_id, aciklama, tutar, not_metni
        FROM expense_items
        WHERE expense_id = ANY(@ids)
        ORDER BY expense_id ASC, id ASC
        ''',
        {'ids': ids},
      );
      for (final item in items) {
        final int expenseId = _toInt(item['expense_id']) ?? 0;
        if (expenseId <= 0) continue;
        kalemlerByGider.putIfAbsent(expenseId, () => <Map<String, dynamic>>[]);
        kalemlerByGider[expenseId]!.add(item);
      }
    }

    final mappedRows = pageResult.rows
        .map((gider) {
          final int id = _toInt(gider['id']) ?? 0;
          final DateTime? tarih = _toDateTime(gider['tarih']);
          final String paraBirimi = gider['para_birimi']?.toString() ?? 'TRY';
          final double tutar = _toDouble(gider['tutar']);
          final String kategori = gider['kategori']?.toString() ?? '-';
          final String aciklama = gider['aciklama']?.toString() ?? '';
          final String notMetni = gider['not_metni']?.toString() ?? '';
          final String odemeDurumu = gider['odeme_durumu']?.toString() ?? '-';
          final String kullanici = gider['kullanici']?.toString() ?? '-';

          final kalemler =
              kalemlerByGider[id] ?? const <Map<String, dynamic>>[];
          final detailTable = kalemler.isEmpty
              ? null
              : DetailTable(
                  title: tr('reports.detail.expense_items'),
                  headers: [
                    tr('common.name'),
                    tr('common.quantity'),
                    tr('common.unit_price'),
                    tr('common.amount'),
                  ],
                  data: kalemler.map((e) {
                    final double kalemTutar = _toDouble(e['tutar']);
                    return [
                      e['aciklama']?.toString() ?? '-',
                      '1',
                      _formatMoney(kalemTutar, currency: paraBirimi),
                      _formatMoney(kalemTutar, currency: paraBirimi),
                    ];
                  }).toList(),
                );

          return RaporSatiri(
            id: 'gider_${id <= 0 ? gider['id'] : id}',
            cells: {
              'tarih': _formatDate(tarih, includeTime: true),
              'kod': gider['kod']?.toString() ?? '-',
              'kalem': gider['baslik']?.toString() ?? '-',
              'kategori': kategori.isNotEmpty ? kategori : '-',
              'tutar': _formatMoney(tutar, currency: paraBirimi),
              'odeme_tipi': odemeDurumu,
              'cari': '-',
              'aciklama': aciklama.trim().isNotEmpty ? aciklama : '-',
              'kullanici': kullanici.trim().isNotEmpty ? kullanici : '-',
            },
            details: {
              tr('common.description'): aciklama.trim().isNotEmpty
                  ? aciklama
                  : '-',
              tr('reports.columns.notes'): notMetni.trim().isNotEmpty
                  ? notMetni
                  : '-',
              tr('reports.columns.item_count'): kalemler.length.toString(),
            },
            detailTable: detailTable,
            expandable: kalemler.isNotEmpty,
            sourceMenuIndex: 100,
            amountValue: tutar,
            sortValues: {
              'tarih': tarih,
              'kod': gider['kod'],
              'kalem': gider['baslik'],
              'kategori': kategori,
              'tutar': tutar,
              'odeme_tipi': odemeDurumu,
              'kullanici': kullanici,
            },
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summary = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final rows = await _queryMaps(pool, '''
          SELECT
            COALESCE(SUM(e.tutar), 0) AS toplam,
            COUNT(DISTINCT NULLIF(TRIM(COALESCE(e.kategori, '')), '')) AS kategori_sayisi
          FROM expenses e
          $whereSql
          ''', params);
        final data = rows.isEmpty ? const <String, dynamic>{} : rows.first;
        final toplam = _toDouble(data['toplam']);
        final int kategoriSayisi =
            (data['kategori_sayisi'] as num?)?.toInt() ?? 0;
        return [
          RaporOzetKarti(
            labelKey: 'reports.summary.total_expense',
            value: _formatMoney(toplam),
            icon: Icons.money_off_csred_outlined,
            accentColor: AppPalette.red,
          ),
          RaporOzetKarti(
            labelKey: 'reports.summary.category_count',
            value: kategoriSayisi.toString(),
            icon: Icons.category_outlined,
            accentColor: AppPalette.amber,
          ),
        ];
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tarih', 'common.date', 150),
        _column('kod', 'common.code', 120),
        _column('kalem', 'reports.columns.expense_item', 220),
        _column('kategori', 'reports.columns.category', 160),
        _column(
          'tutar',
          'common.amount',
          130,
          alignment: Alignment.centerRight,
        ),
        _column('odeme_tipi', 'reports.columns.payment_type', 130),
        _column('cari', 'reports.columns.current_account', 180),
        _column('aciklama', 'common.description', 220),
        _column('kullanici', 'common.user', 100),
      ],
      rows: mappedRows,
      summaryCards: summary,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
      detailTableLabel: tr('reports.detail.expense_items'),
    );
  }

  Future<RaporSonucu> _buildOptimizedUretimRaporu(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();

    String sortExpr(String? key) {
      switch (key) {
        case 'tarih':
          return 'base.created_at';
        case 'belge_no':
          return "COALESCE(base.kod, '')";
        case 'urun':
          return "COALESCE(base.ad, '')";
        case 'miktar':
          return 'base.stok';
        case 'maliyet':
          return 'base.alis_fiyati';
        case 'durum':
          return 'base.aktif_mi';
        case 'kullanici':
          return "COALESCE(base.kullanici, '')";
        default:
          return 'base.created_at';
      }
    }

    final where = <String>[];
    final params = <String, dynamic>{};

    if (_emptyToNull(filtreler.urunKodu) != null) {
      params['kod'] = filtreler.urunKodu;
      where.add('p.kod = @kod');
    }
    if (_emptyToNull(filtreler.urunGrubu) != null) {
      params['grup'] = filtreler.urunGrubu;
      where.add("COALESCE(p.grubu, '') = @grup");
    }
    final durum = _normalizedSelection(filtreler.durum);
    if (durum.isNotEmpty) {
      final norm = _normalizeArama(durum);
      if (norm == _normalizeArama(tr('common.active')) || norm == 'aktif') {
        where.add('p.aktif_mi = 1');
      } else if (norm == _normalizeArama(tr('common.passive')) ||
          norm == 'pasif') {
        where.add('p.aktif_mi = 0');
      }
    }

    _addSearchCondition(where, params, 'p.search_tags', arama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final baseSelect =
        '''
      SELECT
        p.id,
        p.created_at,
        p.kod,
        p.ad,
        p.stok,
        p.alis_fiyati,
        p.aktif_mi,
        p.kullanici,
        p.barkod,
        p.grubu,
        p.ozellikler
      FROM productions p
      $whereSql
    ''';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'id',
    );

    final mappedRows = pageResult.rows
        .map((item) {
          final DateTime? tarih = _toDateTime(item['created_at']);
          final bool aktif = item['aktif_mi'] == true || item['aktif_mi'] == 1;
          final double stok = _toDouble(item['stok']);
          final double maliyet = _toDouble(item['alis_fiyati']);
          return RaporSatiri(
            id: 'uretim_${item['id']}',
            cells: {
              'tarih': _formatDate(tarih, includeTime: true),
              'belge_no': item['kod']?.toString() ?? '-',
              'urun': item['ad']?.toString() ?? '-',
              'miktar': _formatNumber(stok),
              'maliyet': _formatMoney(maliyet),
              'depo': '-',
              'durum': aktif ? tr('common.active') : tr('common.passive'),
              'kullanici': item['kullanici']?.toString() ?? '-',
            },
            details: {
              tr('common.barcode'): (item['barkod']?.toString() ?? '').isEmpty
                  ? '-'
                  : item['barkod']?.toString() ?? '-',
              tr('reports.columns.group'): item['grubu']?.toString() ?? '-',
              tr(
                'reports.columns.features',
              ): (item['ozellikler']?.toString() ?? '').trim().isEmpty
                  ? '-'
                  : item['ozellikler']?.toString() ?? '-',
            },
            sourceMenuIndex: 8,
            sourceSearchQuery: item['ad']?.toString(),
            amountValue: maliyet,
            sortValues: {
              'tarih': tarih,
              'belge_no': item['kod'],
              'urun': item['ad'],
              'miktar': stok,
              'maliyet': maliyet,
              'durum': aktif ? 1 : 0,
              'kullanici': item['kullanici'],
            },
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summary = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final rows = await _queryMaps(pool, '''
          SELECT
            COUNT(*) AS kayit,
            COALESCE(SUM(p.stok), 0) AS stok_toplam
          FROM productions p
          $whereSql
          ''', params);
        final data = rows.isEmpty ? const <String, dynamic>{} : rows.first;
        final int kayit = (data['kayit'] as num?)?.toInt() ?? 0;
        final double stokToplam = _toDouble(data['stok_toplam']);
        return [
          RaporOzetKarti(
            labelKey: 'reports.summary.total_products',
            value: kayit.toString(),
            icon: Icons.precision_manufacturing_outlined,
            accentColor: AppPalette.slate,
          ),
          RaporOzetKarti(
            labelKey: 'reports.summary.stock_total',
            value: _formatNumber(stokToplam),
            icon: Icons.inventory_rounded,
            accentColor: AppPalette.amber,
          ),
        ];
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tarih', 'common.date', 150),
        _column('belge_no', 'reports.columns.production_no', 130),
        _column('urun', 'common.product', 220),
        _column(
          'miktar',
          'common.quantity',
          100,
          alignment: Alignment.centerRight,
        ),
        _column(
          'maliyet',
          'reports.columns.cost_output',
          130,
          alignment: Alignment.centerRight,
        ),
        _column('depo', 'common.warehouse', 120),
        _column('durum', 'common.status', 100),
        _column('kullanici', 'common.user', 100),
      ],
      rows: mappedRows,
      summaryCards: summary,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildOptimizedUrunSevkiyatHareketleri(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final effectiveArama = _normalizeNumericSearchForReports(arama);

    String sortExpr(String? key) {
      switch (key) {
        case 'tarih':
          return 'base.tarih';
        case 'kaynak':
          return "COALESCE(base.kaynak, '')";
        case 'hedef':
          return "COALESCE(base.hedef, '')";
        case 'tur':
          return "COALESCE(base.tur, '')";
        case 'kod':
          return "COALESCE(base.kod, '')";
        case 'ad':
          return "COALESCE(base.ad, '')";
        case 'miktar':
          return 'base.miktar';
        case 'olcu':
          return "COALESCE(base.olcu, '')";
        case 'aciklama':
          return "COALESCE(base.aciklama, '')";
        default:
          return 'base.tarih';
      }
    }

    final where = <String>[];
    final params = <String, dynamic>{};

    if (filtreler.baslangicTarihi != null) {
      params['baslangic'] = DateTime(
        filtreler.baslangicTarihi!.year,
        filtreler.baslangicTarihi!.month,
        filtreler.baslangicTarihi!.day,
      ).toIso8601String();
      where.add('s.date >= @baslangic');
    }
    if (filtreler.bitisTarihi != null) {
      params['bitis'] = DateTime(
        filtreler.bitisTarihi!.year,
        filtreler.bitisTarihi!.month,
        filtreler.bitisTarihi!.day,
      ).add(const Duration(days: 1)).toIso8601String();
      where.add('s.date < @bitis');
    }
    if (_emptyToNull(filtreler.durum) != null) {
      params['tur'] = _emptyToNull(filtreler.durum);
      where.add(
        "COALESCE(NULLIF(TRIM(it.item->>'type'), ''), NULLIF(TRIM(it.item->>'tur'), ''), 'Ürün') = @tur",
      );
    }

    _addSearchConditionAny(where, params, [
      "normalize_text(COALESCE(s.integration_ref, ''))",
      "normalize_text(COALESCE(s.description, ''))",
      "normalize_text(COALESCE(d1.ad, ''))",
      "normalize_text(COALESCE(d2.ad, ''))",
      "normalize_text(COALESCE(it.item->>'code', ''))",
      "normalize_text(COALESCE(it.item->>'kod', ''))",
      "normalize_text(COALESCE(it.item->>'product_code', ''))",
      "normalize_text(COALESCE(it.item->>'urun_kodu', ''))",
      "normalize_text(COALESCE(it.item->>'name', ''))",
      "normalize_text(COALESCE(it.item->>'urun_adi', ''))",
      "normalize_text(COALESCE(it.item->>'product_name', ''))",
      "normalize_text(COALESCE(it.item->>'urunAdi', ''))",
    ], effectiveArama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final baseSelect =
        '''
      SELECT
        ((s.id::bigint << 32) + it.idx::bigint) AS gid,
        s.id AS shipment_id,
        s.date AS tarih,
        d1.ad AS kaynak,
        d2.ad AS hedef,
        COALESCE(NULLIF(TRIM(it.item->>'type'), ''), NULLIF(TRIM(it.item->>'tur'), ''), 'Ürün') AS tur,
        COALESCE(
          NULLIF(TRIM(it.item->>'code'), ''),
          NULLIF(TRIM(it.item->>'kod'), ''),
          NULLIF(TRIM(it.item->>'product_code'), ''),
          NULLIF(TRIM(it.item->>'urun_kodu'), ''),
          '-'
        ) AS kod,
        COALESCE(
          NULLIF(TRIM(it.item->>'name'), ''),
          NULLIF(TRIM(it.item->>'urun_adi'), ''),
          NULLIF(TRIM(it.item->>'product_name'), ''),
          NULLIF(TRIM(it.item->>'urunAdi'), ''),
          '-'
        ) AS ad,
        COALESCE(
          NULLIF(it.item->>'quantity', '')::numeric,
          NULLIF(it.item->>'miktar', '')::numeric,
          NULLIF(it.item->>'qty', '')::numeric,
          0
        ) AS miktar,
        COALESCE(
          NULLIF(TRIM(it.item->>'unit'), ''),
          NULLIF(TRIM(it.item->>'birim'), ''),
          '-'
        ) AS olcu,
        COALESCE(
          NULLIF(TRIM(it.item->>'description'), ''),
          NULLIF(TRIM(it.item->>'aciklama'), ''),
          NULLIF(TRIM(it.item->>'not'), ''),
          NULLIF(TRIM(it.item->>'note'), ''),
          NULLIF(TRIM(s.description), ''),
          ''
        ) AS aciklama,
        s.integration_ref
      FROM shipments s
      LEFT JOIN depots d1 ON s.source_warehouse_id = d1.id
      LEFT JOIN depots d2 ON s.dest_warehouse_id = d2.id
      CROSS JOIN LATERAL jsonb_array_elements(COALESCE(s.items, '[]'::jsonb))
        WITH ORDINALITY AS it(item, idx)
      $whereSql
    ''';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'gid',
    );

    final mappedRows = pageResult.rows
        .map((item) {
          final DateTime? tarih = _toDateTime(item['tarih']);
          final double miktar = _toDouble(item['miktar']);
          final String aciklamaRaw = item['aciklama']?.toString() ?? '';
          final String aciklama = aciklamaRaw.trim().isEmpty ? '-' : aciklamaRaw;
          final String olcuRaw = item['olcu']?.toString() ?? '';
          final String olcu = olcuRaw.trim().isEmpty ? '-' : olcuRaw;

          return RaporSatiri(
            id: 'sevkiyat_item_${item['gid']}',
            cells: {
              'kaynak': item['kaynak']?.toString() ?? '-',
              'hedef': item['hedef']?.toString() ?? '-',
              'tarih': _formatDate(tarih, includeTime: true),
              'tur': item['tur']?.toString() ?? 'Ürün',
              'kod': item['kod']?.toString() ?? '-',
              'ad': item['ad']?.toString() ?? '-',
              'miktar': _formatNumber(miktar),
              'olcu': olcu,
              'aciklama': aciklama,
            },
            sourceMenuIndex: 6,
            sourceSearchQuery: item['integration_ref']?.toString(),
            sortValues: {
              'tarih': tarih,
              'kaynak': item['kaynak']?.toString(),
              'hedef': item['hedef']?.toString(),
              'tur': item['tur']?.toString(),
              'kod': item['kod']?.toString(),
              'ad': item['ad']?.toString(),
              'miktar': miktar,
              'olcu': olcu,
              'aciklama': aciklama,
            },
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summary = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final rows = await _queryMaps(pool, '''
          SELECT COUNT(DISTINCT s.id) AS kayit
          FROM shipments s
          LEFT JOIN depots d1 ON s.source_warehouse_id = d1.id
          LEFT JOIN depots d2 ON s.dest_warehouse_id = d2.id
          CROSS JOIN LATERAL jsonb_array_elements(COALESCE(s.items, '[]'::jsonb))
            WITH ORDINALITY AS it(item, idx)
          $whereSql
          ''', params);
        final int kayit = rows.isEmpty
            ? 0
            : (rows.first['kayit'] as num?)?.toInt() ?? 0;
        return [
          RaporOzetKarti(
            labelKey: 'reports.summary.shipment_count',
            value: kayit.toString(),
            icon: Icons.local_shipping_outlined,
            accentColor: AppPalette.slate,
          ),
        ];
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tarih', 'Tarih', 150),
        _column('kaynak', 'Çıkış Yapılan Depo', 170),
        _column('hedef', 'Giriş Yapılan Depo', 170),
        _column('tur', 'Tür', 110),
        _column('kod', 'Kod No', 110),
        _column('ad', 'Adı', 200),
        _column(
          'miktar',
          'Miktar',
          110,
          alignment: Alignment.centerRight,
        ),
        _column('olcu', 'Ölçü', 120),
        _column('aciklama', 'Açıklama', 220),
      ],
      rows: mappedRows,
      summaryCards: summary,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildOptimizedDepoStokListesi(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final effectiveArama = _normalizeNumericSearchForReports(arama);

    String sortExpr(String? key) {
      switch (key) {
        case 'tur':
          return "COALESCE(base.tur, '')";
        case 'kod':
          return "COALESCE(base.kod, '')";
        case 'ad':
          return "COALESCE(base.ad, '')";
        case 'miktar':
          return 'base.miktar';
        case 'olcu':
          return "COALESCE(base.olcu, '')";
        case 'barkod':
          return "COALESCE(base.barkod, '')";
        case 'grup':
          return "COALESCE(base.grup, '')";
        case 'ozellik':
        case 'ozellik1':
        case 'ozellik2':
        case 'ozellik3':
        case 'ozellik4':
        case 'ozellik5':
          return "COALESCE(base.ozellikler, '')";
        default:
          return "COALESCE(base.ad, '')";
      }
    }

    final where = <String>['ws.quantity > 0'];
    final params = <String, dynamic>{};

    if (filtreler.depoId != null) {
      params['depoId'] = filtreler.depoId;
      where.add('ws.warehouse_id = @depoId');
    }

    _addSearchConditionAny(where, params, [
      'p.search_tags',
      'd.search_tags',
      "normalize_text(COALESCE(ws.product_code, ''))",
      "normalize_text(COALESCE(p.kod, ''))",
      "normalize_text(COALESCE(p.ad, ''))",
      "normalize_text(COALESCE(p.barkod, ''))",
      "normalize_text(COALESCE(p.grubu, ''))",
      "normalize_text(COALESCE(p.ozellikler::text, ''))",
      'COALESCE(ws.quantity, 0)::text',
    ], effectiveArama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final baseSelect =
        '''
      SELECT
        ((ws.warehouse_id::bigint << 32) + COALESCE(p.id::bigint, ABS(hashtext(ws.product_code))::bigint)) AS gid,
        ws.warehouse_id,
        d.ad AS depo_ad,
        'Ürün' AS tur,
        ws.product_code AS kod,
        COALESCE(p.ad, ws.product_code) AS ad,
        COALESCE(p.birim, 'Adet') AS olcu,
        ws.quantity AS miktar,
        COALESCE(p.barkod, '') AS barkod,
        COALESCE(p.grubu, '') AS grup,
        COALESCE(p.ozellikler, '') AS ozellikler
      FROM warehouse_stocks ws
      INNER JOIN depots d ON d.id = ws.warehouse_id
      LEFT JOIN products p ON p.kod = ws.product_code
      $whereSql
    ''';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'gid',
    );

    final mappedRows = pageResult.rows
        .map((item) {
          List<String> splitFirstFiveFeatures(dynamic raw) {
            final String text = (raw?.toString() ?? '').trim();
            if (text.isEmpty) return const <String>[];
            if (text == '[]') return const <String>[];
 
            try {
              final decoded = jsonDecode(text);
              if (decoded is List) {
                return decoded
                    .map((e) {
                      if (e is Map) return e['name']?.toString() ?? '';
                      return e?.toString() ?? '';
                    })
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty && s != 'null')
                    .take(5)
                    .toList(growable: false);
              }
            } catch (_) {
              // ignore
            }
 
            // JSON benzeri bir format varsa parçalayıp ham JSON göstermeyelim.
            if (text.startsWith('[') || text.startsWith('{')) {
              return const <String>[];
            }
 
            final String normalized =
                text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
            List<String> parts;
            if (normalized.contains('|')) {
              parts = normalized.split('|');
            } else if (normalized.contains('\n')) {
              parts = normalized.split('\n');
            } else if (normalized.contains(';')) {
              parts = normalized.split(';');
            } else if (normalized.contains(',')) {
              parts = normalized.split(',');
            } else {
              parts = <String>[normalized];
            }
            return parts
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .take(5)
                .toList(growable: false);
          }
 
          final double miktar = _toDouble(item['miktar']);
          final String olcuRaw = item['olcu']?.toString() ?? '';
          final String olcu = olcuRaw.trim().isEmpty ? '-' : olcuRaw;
          final String barkodRaw = item['barkod']?.toString() ?? '';
          final String barkod = barkodRaw.trim().isEmpty ? '-' : barkodRaw;
          final String grupRaw = item['grup']?.toString() ?? '';
          final String grup = grupRaw.trim().isEmpty ? '-' : grupRaw;
 
          final features = splitFirstFiveFeatures(item['ozellikler']);
          String featureAt(int index) =>
              index < features.length ? features[index] : '-';
          return RaporSatiri(
            id: 'depo_stok_${item['warehouse_id']}_${item['kod']}',
            cells: {
              'tur': item['tur']?.toString() ?? 'Ürün',
              'kod': item['kod']?.toString() ?? '-',
              'ad': item['ad']?.toString() ?? '-',
              'miktar': _formatNumber(miktar),
              'olcu': olcu,
              'barkod': barkod,
              'grup': grup,
              'ozellik1': featureAt(0),
              'ozellik2': featureAt(1),
              'ozellik3': featureAt(2),
              'ozellik4': featureAt(3),
              'ozellik5': featureAt(4),
            },
            sourceMenuIndex: 6,
            sourceSearchQuery: item['depo_ad']?.toString(),
            sortValues: {
              'tur': item['tur'],
              'kod': item['kod'],
              'ad': item['ad'],
              'miktar': miktar,
              'olcu': item['olcu'],
              'barkod': item['barkod'],
              'grup': item['grup'],
              'ozellik': item['ozellikler'],
            },
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summary = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final rows = await _queryMaps(pool, '''
          SELECT
            COALESCE(SUM(ws.quantity), 0) AS toplam,
            COUNT(DISTINCT COALESCE(p.birim, 'Adet')) AS birim_sayisi,
            MIN(COALESCE(p.birim, 'Adet')) AS birim_tek
          FROM warehouse_stocks ws
          INNER JOIN depots d ON d.id = ws.warehouse_id
          LEFT JOIN products p ON p.kod = ws.product_code
          $whereSql
          ''', params);
        final first = rows.isEmpty ? const <String, dynamic>{} : rows.first;
        final double toplam = _toDouble(first['toplam']);
        final int birimSayisi = _toInt(first['birim_sayisi']) ?? 0;
        final String birimTek = first['birim_tek']?.toString() ?? '';
        final String olcu = birimSayisi == 1
            ? (birimTek.trim().isEmpty ? '-' : birimTek)
            : 'Çoklu';
        return [
          RaporOzetKarti(
            labelKey: 'Toplam',
            value: _formatNumber(toplam),
            icon: Icons.summarize_outlined,
            accentColor: AppPalette.slate,
          ),
          RaporOzetKarti(
            labelKey: 'Ölçü',
            value: olcu,
            icon: Icons.straighten_outlined,
            accentColor: AppPalette.slate,
          ),
        ];
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tur', 'TÜR', 90, allowSorting: false),
        _column('kod', 'KOD NO', 110),
        _column('ad', 'ADI', 200),
        _column(
          'miktar',
          'MİKTAR',
          110,
          alignment: Alignment.centerRight,
        ),
        _column('olcu', 'ÖLÇÜ', 120),
        _column('barkod', 'BARKOD NO', 140, allowSorting: false),
        _column('grup', 'GRUBU', 140),
        _column('ozellik1', 'ÖZELLİK1', 120, allowSorting: false),
        _column('ozellik2', 'ÖZELLİK2', 120, allowSorting: false),
        _column('ozellik3', 'ÖZELLİK3', 120, allowSorting: false),
        _column('ozellik4', 'ÖZELLİK4', 120, allowSorting: false),
        _column('ozellik5', 'ÖZELLİK5', 120, allowSorting: false),
      ],
      rows: mappedRows,
      summaryCards: summary,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildOptimizedDepoSevkiyatListesi(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final effectiveArama = _normalizeNumericSearchForReports(arama);
    final searchTokens = _searchTokens(effectiveArama);

    String sortExpr(String? key) {
      switch (key) {
        case 'tarih':
          return 'base.tarih';
        case 'kaynak':
          return "COALESCE(base.kaynak, '')";
        case 'hedef':
          return "COALESCE(base.hedef, '')";
        case 'aciklama':
          return "COALESCE(base.aciklama, '')";
        case 'kullanici':
          return "COALESCE(base.kullanici, '')";
        default:
          return 'base.tarih';
      }
    }

    final where = <String>[];
    final params = <String, dynamic>{};

    if (filtreler.baslangicTarihi != null) {
      params['baslangic'] = DateTime(
        filtreler.baslangicTarihi!.year,
        filtreler.baslangicTarihi!.month,
        filtreler.baslangicTarihi!.day,
      ).toIso8601String();
      where.add('s.date >= @baslangic');
    }
    if (filtreler.bitisTarihi != null) {
      params['bitis'] = DateTime(
        filtreler.bitisTarihi!.year,
        filtreler.bitisTarihi!.month,
        filtreler.bitisTarihi!.day,
      ).add(const Duration(days: 1)).toIso8601String();
      where.add('s.date < @bitis');
    }

    if (filtreler.cikisDepoId != null) {
      params['cikisDepoId'] = filtreler.cikisDepoId;
      where.add('s.source_warehouse_id = @cikisDepoId');
    }

    if (filtreler.girisDepoId != null) {
      params['girisDepoId'] = filtreler.girisDepoId;
      where.add('s.dest_warehouse_id = @girisDepoId');
    }

    _addSearchConditionAny(where, params, [
      's.search_tags',
      "normalize_text(COALESCE(s.integration_ref, ''))",
      "normalize_text(COALESCE(s.description, ''))",
      "normalize_text(COALESCE(d1.ad, ''))",
      "normalize_text(COALESCE(d2.ad, ''))",
      "normalize_text(COALESCE(s.created_by, ''))",
    ], effectiveArama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final baseSelect =
        '''
      SELECT
        s.id,
        s.date AS tarih,
        s.description AS aciklama,
        s.items,
        s.integration_ref,
        d1.ad AS kaynak,
        d2.ad AS hedef,
        s.created_by AS kullanici,
        (
          SELECT ca.adi
          FROM current_account_transactions cat
          JOIN current_accounts ca ON ca.id = cat.current_account_id
          WHERE cat.integration_ref = s.integration_ref
             OR cat.integration_ref = (
               SELECT MAX(sm.integration_ref)
               FROM stock_movements sm
               WHERE sm.shipment_id = s.id
             )
          LIMIT 1
        ) AS related_party_name
      FROM shipments s
      LEFT JOIN depots d1 ON s.source_warehouse_id = d1.id
      LEFT JOIN depots d2 ON s.dest_warehouse_id = d2.id
      $whereSql
    ''';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'id',
    );

    final mappedRows = pageResult.rows
        .map((item) {
          final DateTime? tarih = _toDateTime(item['tarih']);
          final List<Map<String, dynamic>> detailItems = _extractDetailItems(
            item['items'],
          );
          final String aciklamaRaw = item['aciklama']?.toString() ?? '';
          final String aciklama = aciklamaRaw.trim().isEmpty ? '-' : aciklamaRaw;
          final Map<String, String> cells = {
            'kaynak': item['kaynak']?.toString() ?? '-',
            'hedef': item['hedef']?.toString() ?? '-',
            'tarih': _formatDate(tarih, includeTime: true),
            'aciklama': aciklama,
            'kullanici': item['kullanici']?.toString() ?? '-',
          };

          final Map<String, dynamic> extra = <String, dynamic>{};

          if (detailItems.isNotEmpty && searchTokens.isNotEmpty) {
            final mainHaystack = _normalizeArama(cells.values.join(' '));
            final hiddenHaystack = _normalizeArama(
              [
                item['related_party_name']?.toString() ?? '',
                for (final detail in detailItems)
                  ...detail.values.map((v) => v?.toString() ?? ''),
              ].join(' '),
            );

            final bool matchesInMain = searchTokens.every(
              (token) => mainHaystack.contains(token),
            );
            final bool matchesInHidden = searchTokens.every(
              (token) => hiddenHaystack.contains(token),
            );
            if (!matchesInMain && matchesInHidden) {
              extra['matchedInHidden'] = true;
            }
          }
          return RaporSatiri(
            id: 'depo_sevkiyat_${item['id']}',
            cells: cells,
            details: {
              tr('reports.columns.related_party'): _firstNonEmpty([
                item['related_party_name']?.toString(),
                '-',
              ]),
            },
            detailTable: detailItems.isEmpty
                ? null
                : _detailTableFromItems(
                    detailItems,
                    title: tr('common.products'),
                  ),
            expandable: detailItems.isNotEmpty,
            sourceMenuIndex: 6,
            sourceSearchQuery: item['integration_ref']?.toString(),
            sortValues: {
              'tarih': tarih,
              'kaynak': item['kaynak']?.toString(),
              'hedef': item['hedef']?.toString(),
              'aciklama': aciklamaRaw,
              'kullanici': item['kullanici']?.toString(),
            },
            extra: extra.isEmpty ? const <String, dynamic>{} : extra,
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summary = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final rows = await _queryMaps(pool, '''
          SELECT COUNT(*) AS kayit
          FROM shipments s
          LEFT JOIN depots d1 ON s.source_warehouse_id = d1.id
          LEFT JOIN depots d2 ON s.dest_warehouse_id = d2.id
          $whereSql
          ''', params);
        final int kayit = rows.isEmpty
            ? 0
            : (rows.first['kayit'] as num?)?.toInt() ?? 0;
        return [
          RaporOzetKarti(
            labelKey: 'reports.summary.shipment_count',
            value: kayit.toString(),
            icon: Icons.move_down_outlined,
            accentColor: AppPalette.amber,
          ),
        ];
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('kaynak', 'ÇIKIŞ YAPILAN DEPO', 170),
        _column('hedef', 'GİRİŞ YAPILAN DEPO', 170),
        _column('tarih', 'TARİH', 150),
        _column('aciklama', 'AÇIKLAMA', 220),
        _column('kullanici', 'KULLANICI', 120),
      ],
      rows: mappedRows,
      summaryCards: summary,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
      detailTableLabel: tr('common.products'),
    );
  }

  Future<RaporSonucu> _buildOptimizedStokErkenUyari(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();

    String sortExpr(String? key) {
      switch (key) {
        case 'urun_kodu':
          return "COALESCE(base.kod, '')";
        case 'urun':
          return "COALESCE(base.ad, '')";
        case 'mevcut_stok':
          return 'base.stok';
        case 'kritik_stok':
          return 'base.erken_uyari_miktari';
        case 'fark':
          return '(base.stok - base.erken_uyari_miktari)';
        default:
          return '(base.stok - base.erken_uyari_miktari)';
      }
    }

    final where = <String>['p.stok <= p.erken_uyari_miktari'];
    final params = <String, dynamic>{};

    if (_emptyToNull(filtreler.urunGrubu) != null) {
      params['grup'] = filtreler.urunGrubu;
      where.add("COALESCE(p.grubu, '') = @grup");
    }

    _addSearchCondition(where, params, 'p.search_tags', arama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final baseSelect =
        '''
      SELECT
        p.id,
        p.kod,
        p.ad,
        p.stok,
        p.erken_uyari_miktari,
        p.grubu,
        p.ozellikler
      FROM products p
      $whereSql
    ''';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'id',
    );

    final mappedRows = pageResult.rows
        .map((urun) {
          final double stok = _toDouble(urun['stok']);
          final double kritik = _toDouble(urun['erken_uyari_miktari']);
          final double fark = stok - kritik;
          final String ozellikler = urun['ozellikler']?.toString() ?? '';
          return RaporSatiri(
            id: 'stok_uyari_${urun['id']}',
            cells: {
              'urun_kodu': urun['kod']?.toString() ?? '-',
              'urun': urun['ad']?.toString() ?? '-',
              'depo': '-',
              'mevcut_stok': _formatNumber(stok),
              'kritik_stok': _formatNumber(kritik),
              'fark': _formatNumber(fark),
              'son_hareket': '-',
            },
            details: {
              tr('reports.columns.group'): urun['grubu']?.toString() ?? '-',
              tr('reports.columns.features'): ozellikler.trim().isEmpty
                  ? '-'
                  : ozellikler,
            },
            sourceMenuIndex: TabAciciScope.urunKartiIndex,
            sourceSearchQuery: urun['ad']?.toString(),
            sortValues: {
              'urun_kodu': urun['kod'],
              'urun': urun['ad'],
              'mevcut_stok': stok,
              'kritik_stok': kritik,
              'fark': fark,
            },
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summary = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final rows = await _queryMaps(pool, '''
          SELECT COUNT(*) AS kayit
          FROM products p
          $whereSql
          ''', params);
        final int kayit = rows.isEmpty
            ? 0
            : (rows.first['kayit'] as num?)?.toInt() ?? 0;
        return [
          RaporOzetKarti(
            labelKey: 'reports.summary.critical_count',
            value: kayit.toString(),
            icon: Icons.warning_amber_rounded,
            accentColor: AppPalette.red,
          ),
        ];
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('urun_kodu', 'common.code', 120),
        _column('urun', 'common.product', 220),
        _column('depo', 'common.warehouse', 140),
        _column(
          'mevcut_stok',
          'reports.columns.current_stock',
          110,
          alignment: Alignment.centerRight,
        ),
        _column(
          'kritik_stok',
          'reports.columns.critical_stock',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'fark',
          'common.difference',
          100,
          alignment: Alignment.centerRight,
        ),
        _column('son_hareket', 'reports.columns.last_movement', 140),
      ],
      rows: mappedRows,
      summaryCards: summary,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildOptimizedStokTanimDegerleri(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();

    String sortExpr(String? key) {
      switch (key) {
        case 'kod':
          return "COALESCE(base.kod, '')";
        case 'urun':
          return "COALESCE(base.ad, '')";
        case 'grup':
          return "COALESCE(base.grubu, '')";
        case 'birim':
          return "COALESCE(base.birim, '')";
        case 'alis':
          return 'base.alis_fiyati';
        case 'satis1':
          return 'base.satis_fiyati_1';
        case 'satis2':
          return 'base.satis_fiyati_2';
        case 'satis3':
          return 'base.satis_fiyati_3';
        case 'vergi':
          return 'base.kdv_orani';
        case 'durum':
          return 'base.aktif_mi';
        default:
          return "COALESCE(base.kod, '')";
      }
    }

    final where = <String>[];
    final params = <String, dynamic>{};

    if (_emptyToNull(filtreler.urunKodu) != null) {
      params['kod'] = filtreler.urunKodu;
      where.add('p.kod = @kod');
    }
    if (_emptyToNull(filtreler.urunGrubu) != null) {
      params['grup'] = filtreler.urunGrubu;
      where.add("COALESCE(p.grubu, '') = @grup");
    }

    final durum = _normalizedSelection(filtreler.durum);
    if (durum.isNotEmpty) {
      final norm = _normalizeArama(durum);
      if (norm == _normalizeArama(tr('common.active')) || norm == 'aktif') {
        where.add('p.aktif_mi = 1');
      } else if (norm == _normalizeArama(tr('common.passive')) ||
          norm == 'pasif') {
        where.add('p.aktif_mi = 0');
      }
    }

    _addSearchCondition(where, params, 'p.search_tags', arama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final baseSelect =
        '''
      SELECT
        p.id,
        p.kod,
        p.ad,
        p.grubu,
        p.birim,
        p.alis_fiyati,
        p.satis_fiyati_1,
        p.satis_fiyati_2,
        p.satis_fiyati_3,
        p.kdv_orani,
        p.aktif_mi,
        p.barkod,
        p.ozellikler
      FROM products p
      $whereSql
    ''';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'id',
    );

    final mappedRows = pageResult.rows
        .map((urun) {
          final bool aktif = urun['aktif_mi'] == true || urun['aktif_mi'] == 1;
          final double alis = _toDouble(urun['alis_fiyati']);
          final double satis1 = _toDouble(urun['satis_fiyati_1']);
          final double satis2 = _toDouble(urun['satis_fiyati_2']);
          final double satis3 = _toDouble(urun['satis_fiyati_3']);
          final double vergi = _toDouble(urun['kdv_orani']);
          final String ozellikler = urun['ozellikler']?.toString() ?? '';
          return RaporSatiri(
            id: 'stok_tanim_${urun['id']}',
            cells: {
              'kod': urun['kod']?.toString() ?? '-',
              'urun': urun['ad']?.toString() ?? '-',
              'grup': urun['grubu']?.toString() ?? '-',
              'birim': urun['birim']?.toString() ?? '-',
              'alis': _formatMoney(alis),
              'satis1': _formatMoney(satis1),
              'satis2': _formatMoney(satis2),
              'satis3': _formatMoney(satis3),
              'vergi': '${_formatNumber(vergi)}%',
              'durum': aktif ? tr('common.active') : tr('common.passive'),
            },
            details: {
              tr('common.barcode'): (urun['barkod']?.toString() ?? '').isEmpty
                  ? '-'
                  : urun['barkod']?.toString() ?? '-',
              tr('reports.columns.features'): ozellikler.trim().isEmpty
                  ? '-'
                  : ozellikler,
            },
            sourceMenuIndex: TabAciciScope.urunKartiIndex,
            sourceSearchQuery: urun['ad']?.toString(),
            sortValues: {
              'kod': urun['kod'],
              'urun': urun['ad'],
              'grup': urun['grubu'],
              'alis': alis,
              'satis1': satis1,
              'satis2': satis2,
              'satis3': satis3,
              'vergi': vergi,
              'durum': aktif ? 1 : 0,
            },
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summary = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final rows = await _queryMaps(
          pool,
          'SELECT COUNT(*) AS kayit FROM products p $whereSql',
          params,
        );
        final int kayit = rows.isEmpty
            ? 0
            : (rows.first['kayit'] as num?)?.toInt() ?? 0;
        return [
          RaporOzetKarti(
            labelKey: 'reports.summary.total_products',
            value: kayit.toString(),
            icon: Icons.dataset_outlined,
            accentColor: AppPalette.slate,
          ),
        ];
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('kod', 'common.code', 120),
        _column('urun', 'common.product', 220),
        _column('grup', 'reports.columns.group', 160),
        _column('birim', 'common.unit', 90),
        _column(
          'alis',
          'reports.columns.purchase_price',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'satis1',
          'reports.columns.sales_price_1',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'satis2',
          'reports.columns.sales_price_2',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'satis3',
          'reports.columns.sales_price_3',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'vergi',
          'reports.columns.tax',
          90,
          alignment: Alignment.centerRight,
        ),
        _column('durum', 'common.status', 100),
      ],
      rows: mappedRows,
      summaryCards: summary,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildOptimizedBakiyeListesi(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final effectiveArama = _normalizeNumericSearchForReports(arama);

    String sortExpr(String? key) {
      switch (key) {
        case 'kod':
          return "COALESCE(base.kod, '')";
        case 'hesap':
          return "COALESCE(base.hesap, '')";
        case 'tur':
          return "COALESCE(base.tur_sort, '')";
        case 'borc':
          return 'base.borc';
        case 'alacak':
          return 'base.alacak';
        case 'bakiye_borc':
          return 'GREATEST(COALESCE(base.borc, 0) - COALESCE(base.alacak, 0), 0)';
        case 'bakiye_alacak':
          return 'GREATEST(COALESCE(base.alacak, 0) - COALESCE(base.borc, 0), 0)';
        default:
          return "COALESCE(base.hesap, '')";
      }
    }

    final params = <String, dynamic>{};

    final bool hasDateFilter =
        filtreler.baslangicTarihi != null || filtreler.bitisTarihi != null;

    final String baseSelect = () {
      if (!hasDateFilter) {
        return '''
      SELECT
        ca.id::bigint AS gid,
        ca.kod_no AS kod,
        ca.adi AS hesap,
        COALESCE(ca.hesap_turu, '') AS tur_sort,
        COALESCE(ca.para_birimi, 'TRY') AS para_birimi,
        COALESCE(ca.search_tags, '') AS search_tags,
        COALESCE(ca.bakiye_borc, 0) AS borc,
        COALESCE(ca.bakiye_alacak, 0) AS alacak
      FROM current_accounts ca
    ''';
      }

      final txWhere = <String>[];
      if (filtreler.baslangicTarihi != null) {
        params['baslangic'] = DateTime(
          filtreler.baslangicTarihi!.year,
          filtreler.baslangicTarihi!.month,
          filtreler.baslangicTarihi!.day,
        ).toIso8601String();
        txWhere.add('cat.date >= @baslangic');
      }
      if (filtreler.bitisTarihi != null) {
        params['bitis'] = DateTime(
          filtreler.bitisTarihi!.year,
          filtreler.bitisTarihi!.month,
          filtreler.bitisTarihi!.day,
        ).add(const Duration(days: 1)).toIso8601String();
        txWhere.add('cat.date < @bitis');
      }
      final String txWhereSql = txWhere.isEmpty
          ? ''
          : 'WHERE ${txWhere.join(' AND ')}';

      return '''
      WITH tx AS (
        SELECT
          cat.current_account_id,
          COALESCE(
            SUM(
              CASE
                WHEN LOWER(COALESCE(cat.type, '')) LIKE '%borç%'
                  OR LOWER(COALESCE(cat.type, '')) LIKE '%borc%'
                THEN COALESCE(cat.amount, 0)
                ELSE 0
              END
            ),
            0
          ) AS borc,
          COALESCE(
            SUM(
              CASE
                WHEN LOWER(COALESCE(cat.type, '')) LIKE '%alacak%'
                THEN COALESCE(cat.amount, 0)
                ELSE 0
              END
            ),
            0
          ) AS alacak
        FROM current_account_transactions cat
        $txWhereSql
        GROUP BY cat.current_account_id
      )
      SELECT
        ca.id::bigint AS gid,
        ca.kod_no AS kod,
        ca.adi AS hesap,
        COALESCE(ca.hesap_turu, '') AS tur_sort,
        COALESCE(ca.para_birimi, 'TRY') AS para_birimi,
        COALESCE(ca.search_tags, '') AS search_tags,
        COALESCE(tx.borc, 0) AS borc,
        COALESCE(tx.alacak, 0) AS alacak
      FROM current_accounts ca
      LEFT JOIN tx ON tx.current_account_id = ca.id
    ''';
    }();

    final outerWhere = <String>[
      if (hasDateFilter)
        '(COALESCE(base.borc, 0) <> 0 OR COALESCE(base.alacak, 0) <> 0)',
    ];
    final String? hesapTuru = _emptyToNull(filtreler.hesapTuru);
    if (hesapTuru != null) {
      params['hesapTuru'] = hesapTuru;
      outerWhere.add(
        "normalize_text(COALESCE(base.tur_sort, '')) = normalize_text(@hesapTuru)",
      );
    }
    final String? bakiyeDurumu = _emptyToNull(filtreler.bakiyeDurumu);
    if (bakiyeDurumu == 'borc') {
      outerWhere.add('COALESCE(base.borc, 0) > COALESCE(base.alacak, 0)');
    } else if (bakiyeDurumu == 'alacak') {
      outerWhere.add('COALESCE(base.alacak, 0) > COALESCE(base.borc, 0)');
    }
    _addSearchConditionAny(outerWhere, params, [
      'COALESCE(base.search_tags, \'\')',
      "normalize_text(COALESCE(base.kod, ''))",
      "normalize_text(COALESCE(base.hesap, ''))",
      "normalize_text(COALESCE(base.tur_sort, ''))",
      // Numeric columns (best-effort, matches raw DB representation)
      'COALESCE(base.borc, 0)::text',
      'COALESCE(base.alacak, 0)::text',
      'GREATEST(COALESCE(base.borc, 0) - COALESCE(base.alacak, 0), 0)::text',
      'GREATEST(COALESCE(base.alacak, 0) - COALESCE(base.borc, 0), 0)::text',
    ], effectiveArama);

    final String outerWhereSql = outerWhere.isEmpty
        ? ''
        : 'WHERE ${outerWhere.join(' AND ')}';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
      $outerWhereSql
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'gid',
    );

    final mappedRows = pageResult.rows
        .map((item) {
          final String kod = item['kod']?.toString() ?? '-';
          final String hesap = item['hesap']?.toString() ?? '-';
          final String paraBirimi = item['para_birimi']?.toString() ?? 'TRY';
          final double borc = _toDouble(item['borc']);
          final double alacak = _toDouble(item['alacak']);
          final double bakiyeBorc = borc > alacak ? (borc - alacak) : 0.0;
          final double bakiyeAlacak = alacak > borc ? (alacak - borc) : 0.0;
          final int cariId = _toInt(item['gid']) ?? 0;
          final String turLabel = IslemCeviriYardimcisi.cevir(
            item['tur_sort']?.toString() ?? '',
          );

          return RaporSatiri(
            id: 'bakiye_cari_$cariId',
            cells: {
              'kod': kod,
              'hesap': hesap,
              'tur': turLabel,
              'borc': _formatMoney(borc, currency: paraBirimi),
              'alacak': _formatMoney(alacak, currency: paraBirimi),
              'bakiye_borc': _formatMoney(bakiyeBorc, currency: paraBirimi),
              'bakiye_alacak': _formatMoney(bakiyeAlacak, currency: paraBirimi),
            },
            sourceMenuIndex: TabAciciScope.cariKartiIndex,
            sourceSearchQuery: hesap,
            amountValue: bakiyeAlacak - bakiyeBorc,
            sortValues: {
              'kod': kod,
              'hesap': hesap,
              'tur': item['tur_sort']?.toString(),
              'borc': borc,
              'alacak': alacak,
              'bakiye_borc': bakiyeBorc,
              'bakiye_alacak': bakiyeAlacak,
            },
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summary = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final rows = await _queryMaps(pool, '''
          SELECT
            COUNT(DISTINCT base.para_birimi) AS currency_count,
            MIN(base.para_birimi) AS currency_one,
            COALESCE(SUM(base.borc), 0) AS borc,
            COALESCE(SUM(base.alacak), 0) AS alacak
          FROM ($baseSelect) base
          $outerWhereSql
          ''', params);
        final data = rows.isEmpty ? const <String, dynamic>{} : rows.first;
        final int currencyCount = _toInt(data['currency_count']) ?? 0;
        final String currency = currencyCount == 1
            ? (data['currency_one']?.toString() ?? '')
            : '';
        final double toplamBorc = _toDouble(data['borc']);
        final double toplamAlacak = _toDouble(data['alacak']);
        final double toplamBakiyeBorc = toplamBorc > toplamAlacak
            ? (toplamBorc - toplamAlacak)
            : 0.0;
        final double toplamBakiyeAlacak = toplamAlacak > toplamBorc
            ? (toplamAlacak - toplamBorc)
            : 0.0;
        return [
          RaporOzetKarti(
            labelKey: 'Borç',
            value: _formatMoney(toplamBorc, currency: currency),
            icon: Icons.south_west_rounded,
            accentColor: AppPalette.red,
          ),
          RaporOzetKarti(
            labelKey: 'Alacak',
            value: _formatMoney(toplamAlacak, currency: currency),
            icon: Icons.north_east_rounded,
            accentColor: const Color(0xFF27AE60),
          ),
          RaporOzetKarti(
            labelKey: 'Bakiye Borç',
            value: _formatMoney(toplamBakiyeBorc, currency: currency),
            icon: Icons.trending_down_rounded,
            accentColor: AppPalette.red,
          ),
          RaporOzetKarti(
            labelKey: 'Bakiye Alacak',
            value: _formatMoney(toplamBakiyeAlacak, currency: currency),
            icon: Icons.trending_up_rounded,
            accentColor: const Color(0xFF27AE60),
          ),
        ];
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('kod', 'Kod no', 120),
        _column('hesap', 'Adı', 220),
        _column('tur', 'Hesap Türü', 140),
        _column('borc', 'Borç', 120, alignment: Alignment.centerRight),
        _column('alacak', 'Alacak', 120, alignment: Alignment.centerRight),
        _column(
          'bakiye_borc',
          'Bakiye Borç',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'bakiye_alacak',
          'Bakiye Alacak',
          130,
          alignment: Alignment.centerRight,
        ),
      ],
      rows: mappedRows,
      summaryCards: summary,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildOptimizedAlinacakVerilecekler(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final effectiveArama = _normalizeNumericSearchForReports(arama);

    String sortExpr(String? key) {
      switch (key) {
        case 'islem':
          return "COALESCE(base.islem, '')";
        case 'kod':
          return "COALESCE(base.kod, '')";
        case 'ad':
          return "COALESCE(base.ad, '')";
        case 'tur':
          return "COALESCE(base.hesap_turu, '')";
        case 'tarih':
          return 'base.tarih';
        case 'tutar':
          return 'base.tutar';
        case 'tip':
          return "COALESCE(base.tip, '')";
        case 'aciklama':
          return "COALESCE(base.aciklama, '')";
        default:
          return 'base.tarih';
      }
    }

    final params = <String, dynamic>{'companyId': _companyId};
    final where = <String>[];

    if (filtreler.baslangicTarihi != null) {
      params['baslangic'] = DateTime(
        filtreler.baslangicTarihi!.year,
        filtreler.baslangicTarihi!.month,
        filtreler.baslangicTarihi!.day,
      ).toIso8601String();
      where.add('base.tarih >= @baslangic');
    }
    if (filtreler.bitisTarihi != null) {
      params['bitis'] = DateTime(
        filtreler.bitisTarihi!.year,
        filtreler.bitisTarihi!.month,
        filtreler.bitisTarihi!.day,
      ).add(const Duration(days: 1)).toIso8601String();
      where.add('base.tarih < @bitis');
    }

    final String? hesapTuru = _emptyToNull(filtreler.hesapTuru);
    if (hesapTuru != null) {
      params['hesapTuru'] = hesapTuru;
      where.add(
        "normalize_text(COALESCE(base.hesap_turu, '')) = normalize_text(@hesapTuru)",
      );
    }

    final String? islemTuru = _emptyToNull(filtreler.islemTuru);
    if (islemTuru != null) {
      params['islemTuru'] = islemTuru;
      where.add(
        "normalize_text(COALESCE(base.islem, '')) = normalize_text(@islemTuru)",
      );
    }

    _addSearchConditionAny(where, params, [
      'COALESCE(base.search_tags, \'\')',
      "normalize_text(COALESCE(base.islem, ''))",
      "normalize_text(COALESCE(base.kod, ''))",
      "normalize_text(COALESCE(base.ad, ''))",
      "normalize_text(COALESCE(base.hesap_turu, ''))",
      "normalize_text(COALESCE(base.tip, ''))",
      "normalize_text(COALESCE(base.aciklama, ''))",
      // Numeric columns (best-effort, matches raw DB representation)
      'COALESCE(base.tutar, 0)::text',
    ], effectiveArama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final baseSelect =
        '''
      WITH docs AS (
        SELECT
          ((14::bigint << 48) + c.id::bigint) AS gid,
          'Çek'::text AS tip,
          c.type AS direction_raw,
          COALESCE(c.customer_code, '') AS kod,
          COALESCE(c.customer_name, '') AS ad,
          c.due_date AS tarih,
          COALESCE(c.amount, 0) AS tutar,
          COALESCE(c.currency, 'TRY') AS para_birimi,
          COALESCE(c.description, '') AS aciklama,
          COALESCE(c.search_tags, '') AS search_tags,
          COALESCE(c.integration_ref, '') AS integration_ref,
          14::int AS source_menu_index
        FROM cheques c
        WHERE COALESCE(c.company_id, '$_defaultCompanyId') = @companyId
          AND COALESCE(c.is_active, 1) = 1

        UNION ALL

        SELECT
          ((17::bigint << 48) + n.id::bigint) AS gid,
          'Senet'::text AS tip,
          n.type AS direction_raw,
          COALESCE(n.customer_code, '') AS kod,
          COALESCE(n.customer_name, '') AS ad,
          n.due_date AS tarih,
          COALESCE(n.amount, 0) AS tutar,
          COALESCE(n.currency, 'TRY') AS para_birimi,
          COALESCE(n.description, '') AS aciklama,
          COALESCE(n.search_tags, '') AS search_tags,
          COALESCE(n.integration_ref, '') AS integration_ref,
          17::int AS source_menu_index
        FROM promissory_notes n
        WHERE COALESCE(n.company_id, '$_defaultCompanyId') = @companyId
          AND COALESCE(n.is_active, 1) = 1
      )
      SELECT
        d.gid,
        d.tip,
        d.kod,
        d.ad,
        ca.hesap_turu,
        d.tarih,
        d.tutar,
        d.para_birimi,
        d.aciklama,
        d.search_tags,
        d.integration_ref,
        d.source_menu_index,
        CASE
          WHEN normalize_text(COALESCE(d.direction_raw, '')) LIKE '%alinan%'
          THEN 'Alınacak'
          WHEN normalize_text(COALESCE(d.direction_raw, '')) LIKE '%verilen%'
          THEN 'Verilecek'
          WHEN normalize_text(COALESCE(d.direction_raw, '')) LIKE '%alacak%'
          THEN 'Alınacak'
          WHEN normalize_text(COALESCE(d.direction_raw, '')) LIKE '%borc%'
          THEN 'Verilecek'
          ELSE 'Alınacak'
        END AS islem,
        CASE
          WHEN normalize_text(COALESCE(d.direction_raw, '')) LIKE '%alinan%'
            OR normalize_text(COALESCE(d.direction_raw, '')) LIKE '%alacak%'
          THEN 1
          ELSE 0
        END AS is_incoming
      FROM docs d
      LEFT JOIN current_accounts ca
        ON TRIM(COALESCE(ca.kod_no, '')) = TRIM(COALESCE(d.kod, ''))
    ''';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
      $whereSql
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'gid',
    );

    final mappedRows = pageResult.rows
        .map((item) {
          final int gid = _toInt(item['gid']) ?? 0;
          final String islem = item['islem']?.toString() ?? '-';
          final bool incoming = _toInt(item['is_incoming']) == 1;
          final String kod = item['kod']?.toString() ?? '-';
          final String ad = item['ad']?.toString() ?? '-';
          final String hesapTuruRaw = item['hesap_turu']?.toString() ?? '';
          final DateTime? tarih = _toDateTime(item['tarih']);
          final double tutar = _toDouble(item['tutar']);
          final String paraBirimi = item['para_birimi']?.toString() ?? 'TRY';
          final String tip = item['tip']?.toString() ?? '-';
          final String aciklamaRaw = item['aciklama']?.toString() ?? '';
          final String aciklama = aciklamaRaw.trim().isEmpty
              ? '-'
              : aciklamaRaw.trim();
          final int menuIndex = _toInt(item['source_menu_index']) ?? -1;
          final String integrationRef =
              item['integration_ref']?.toString().trim() ?? '';
          return RaporSatiri(
            id: 'av_$gid',
            cells: {
              'islem': islem,
              'kod': kod,
              'ad': ad,
              'tur': IslemCeviriYardimcisi.cevir(hesapTuruRaw),
              'tarih': _formatDate(tarih, includeTime: true),
              'tutar': _formatMoney(tutar, currency: paraBirimi),
              'tip': tip,
              'aciklama': aciklama,
            },
            extra: {
              if (integrationRef.isNotEmpty) 'integrationRef': integrationRef,
              'isIncoming': incoming,
            },
            sourceMenuIndex: menuIndex > 0 ? menuIndex : null,
            sourceSearchQuery: [
              integrationRef,
              kod,
              ad,
            ].firstWhere((e) => e.trim().isNotEmpty, orElse: () => ''),
            amountValue: incoming ? tutar : -tutar,
            sortValues: {
              'islem': islem,
              'kod': kod,
              'ad': ad,
              'tur': hesapTuruRaw,
              'tarih': tarih,
              'tutar': tutar,
              'tip': tip,
              'aciklama': aciklama,
            },
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summary = await _getOrComputeReceivablesPayablesSummary(
      cacheKey: summaryKey,
      loader: () async {
        final rows = await _queryMaps(pool, '''
          SELECT
            COUNT(*) AS kayit,
            COUNT(DISTINCT base.para_birimi) AS currency_count,
            MIN(base.para_birimi) AS currency_one,
            COALESCE(
              SUM(CASE WHEN normalize_text(COALESCE(base.islem, '')) = normalize_text('Alınacak') THEN COALESCE(base.tutar, 0) ELSE 0 END),
              0
            ) AS alinacak,
            COALESCE(
              SUM(CASE WHEN normalize_text(COALESCE(base.islem, '')) = normalize_text('Verilecek') THEN COALESCE(base.tutar, 0) ELSE 0 END),
              0
            ) AS verilecek
          FROM ($baseSelect) base
          $whereSql
          ''', params);
        final data = rows.isEmpty ? const <String, dynamic>{} : rows.first;
        final int kayit = _toInt(data['kayit']) ?? 0;
        final int currencyCount = _toInt(data['currency_count']) ?? 0;
        final String currency = currencyCount == 1
            ? (data['currency_one']?.toString() ?? '')
            : '';
        final double alinacak = _toDouble(data['alinacak']);
        final double verilecek = _toDouble(data['verilecek']);
        final cards = <RaporOzetKarti>[
          RaporOzetKarti(
            labelKey: 'Alınacak',
            value: _formatMoney(alinacak, currency: currency),
            icon: Icons.trending_up_rounded,
            accentColor: const Color(0xFF27AE60),
          ),
          RaporOzetKarti(
            labelKey: 'Verilecek',
            value: _formatMoney(verilecek, currency: currency),
            icon: Icons.trending_down_rounded,
            accentColor: AppPalette.red,
          ),
        ];
        return (totalCount: kayit, cards: cards);
      },
    );
    final summaryCards = summary.cards;
    final int totalCount = summary.totalCount;

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('islem', 'İşlem', 140),
        _column('kod', 'Kod no', 110),
        _column('ad', 'Adı', 220),
        _column('tur', 'Hesap Türü', 140),
        _column('tarih', 'Tarih', 150),
        _column('tutar', 'Tutar', 130, alignment: Alignment.centerRight),
        _column('tip', 'Tür', 110),
        _column('aciklama', 'Açıklama', 220),
      ],
      rows: mappedRows,
      summaryCards: summaryCards,
      totalCount: totalCount,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildOptimizedKdvHesabi(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final effectiveArama = _normalizeNumericSearchForReports(arama);
    final List<String> searchTokens = _searchTokens(effectiveArama);

    String sortExpr(String? key) {
      switch (key) {
        case 'islem':
          return "COALESCE(base.islem, '')";
        case 'tarih':
          return 'base.tarih';
        case 'kod':
          return "COALESCE(base.kod, '')";
        case 'ad':
          return "COALESCE(base.ad, '')";
        case 'miktar':
          return 'base.miktar';
        case 'birim':
          return "COALESCE(base.birim, '')";
        case 'kdv_orani':
          return 'base.kdv_orani';
        case 'otv_orani':
          return 'base.otv_orani';
        case 'oiv_orani':
          return 'base.oiv_orani';
        case 'tevkifat':
          return 'base.kdv_tevkifat_orani';
        case 'isk_orani':
          return 'base.isk_orani';
        case 'birim_fiyati':
          return 'base.birim_fiyati';
        case 'matrah':
          return 'base.matrah';
        case 'kdv':
          return 'base.kdv_tutari';
        case 'otv_tutari':
          return 'base.otv_tutari';
        case 'oiv_tutari':
          return 'base.oiv_tutari';
        case 'genel_toplam':
          return 'base.genel_toplam';
        default:
          return 'base.tarih';
      }
    }

    final params = <String, dynamic>{};
    final where = <String>[];

    if (filtreler.baslangicTarihi != null) {
      params['baslangic'] = DateTime(
        filtreler.baslangicTarihi!.year,
        filtreler.baslangicTarihi!.month,
        filtreler.baslangicTarihi!.day,
      ).toIso8601String();
      where.add('base.tarih >= @baslangic');
    }
    if (filtreler.bitisTarihi != null) {
      params['bitis'] = DateTime(
        filtreler.bitisTarihi!.year,
        filtreler.bitisTarihi!.month,
        filtreler.bitisTarihi!.day,
      ).add(const Duration(days: 1)).toIso8601String();
      where.add('base.tarih < @bitis');
    }

    final String? islemTuruFilter = _emptyToNull(filtreler.islemTuru);
    if (islemTuruFilter != null) {
      params['islemTuru'] = islemTuruFilter;
      where.add(
        "normalize_text(COALESCE(base.islem, '')) = normalize_text(@islemTuru)",
      );
    }

    final String? belgeFilter = _emptyToNull(filtreler.belgeNo);
    if (belgeFilter != null) {
      final faturaClean =
          "TRIM(REPLACE(COALESCE(base.fatura_no, ''), '-', ''))";
      final irsaliyeClean =
          "TRIM(REPLACE(COALESCE(base.irsaliye_no, ''), '-', ''))";

      switch (belgeFilter) {
        case 'Fatura':
          where.add("($faturaClean <> '' AND $irsaliyeClean = '')");
          break;
        case 'İrsaliye':
          where.add("($irsaliyeClean <> '' AND $faturaClean = '')");
          break;
        case 'İrsaliyeli Fatura':
          where.add("($faturaClean <> '' AND $irsaliyeClean <> '')");
          break;
        case '-':
          where.add("($faturaClean = '' AND $irsaliyeClean = '')");
          break;
        default:
          break;
      }
    }

    const String eBelgeVarSentinel = '__HAS_EBELGE__';
    final String? eBelgeFilter = _emptyToNull(filtreler.referansNo);
    if (eBelgeFilter != null) {
      if (eBelgeFilter == eBelgeVarSentinel) {
        where.add(
          "COALESCE(NULLIF(TRIM(COALESCE(base.e_belge, '')), ''), '-') <> '-'",
        );
      } else {
        params['eBelgeFiltre'] = eBelgeFilter;
        where.add(
          "normalize_text(COALESCE(NULLIF(base.e_belge, ''), '-')) = normalize_text(@eBelgeFiltre)",
        );
      }
    }

    _addSearchConditionAny(where, params, [
      'COALESCE(base.search_tags_sm, \'\')',
      'COALESCE(base.search_tags_p, \'\')',
      "normalize_text(COALESCE(base.islem, ''))",
      "normalize_text(COALESCE(base.kod, ''))",
      "normalize_text(COALESCE(base.ad, ''))",
      "normalize_text(COALESCE(base.birim, ''))",
      "normalize_text(COALESCE(base.yer_kodu, ''))",
      "normalize_text(COALESCE(base.yer_adi, ''))",
      "normalize_text(COALESCE(base.vkn_tckn, ''))",
      "normalize_text(COALESCE(base.belge, ''))",
      "normalize_text(COALESCE(base.integration_ref, ''))",
      "normalize_text(COALESCE(base.fatura_no, ''))",
      "normalize_text(COALESCE(base.irsaliye_no, ''))",
      "normalize_text(COALESCE(base.e_belge, ''))",
      // Numeric columns (best-effort, matches raw DB representation)
      'COALESCE(base.miktar, 0)::text',
      'COALESCE(base.birim_fiyati, 0)::text',
      'COALESCE(base.isk_orani, 0)::text',
      'COALESCE(base.kdv_orani, 0)::text',
      'COALESCE(base.otv_orani, 0)::text',
      'COALESCE(base.oiv_orani, 0)::text',
      'COALESCE(base.kdv_tevkifat_orani, 0)::text',
      'COALESCE(base.matrah, 0)::text',
      'COALESCE(base.kdv_tutari, 0)::text',
      'COALESCE(base.otv_tutari, 0)::text',
      'COALESCE(base.oiv_tutari, 0)::text',
      'COALESCE(base.kdv_tevkifat_tutari, 0)::text',
      'COALESCE(base.genel_toplam, 0)::text',
    ], effectiveArama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final String baseSelect = '''
      SELECT
        sm.id::bigint AS gid,
        sm.movement_date AS tarih,
        sm.is_giris,
        sm.movement_type,
        sm.description AS aciklama,
        COALESCE(sm.integration_ref, '') AS integration_ref,
        CASE
          WHEN COALESCE(sm.integration_ref, '') = 'opening_stock'
            OR COALESCE(sm.description, '') ILIKE '%Açılış%'
            OR COALESCE(sm.description, '') ILIKE '%Acilis%'
          THEN 'Açılış Stoğu'
          WHEN COALESCE(sm.integration_ref, '') ILIKE 'PURCHASE-%' THEN 'Alış Yapıldı'
          WHEN COALESCE(sm.integration_ref, '') ILIKE 'SALE-%'
            OR COALESCE(sm.integration_ref, '') ILIKE 'RETAIL-%'
          THEN 'Satış Yapıldı'
          WHEN LOWER(COALESCE(sm.integration_ref, '')) = 'production_output'
            OR COALESCE(sm.description, '') ILIKE '%Üretim (Çıktı)%'
            OR COALESCE(sm.description, '') ILIKE '%Uretim (Cikti)%'
          THEN 'Üretim Çıkışı'
          WHEN LOWER(TRIM(COALESCE(sm.movement_type, ''))) LIKE '%devir%'
          THEN CASE WHEN sm.is_giris THEN 'Devir Giriş' ELSE 'Devir Çıkış' END
          WHEN LOWER(TRIM(COALESCE(sm.movement_type, ''))) LIKE '%sevkiyat%'
            OR LOWER(TRIM(COALESCE(sm.movement_type, ''))) LIKE '%transfer%'
          THEN 'Sevkiyat'
          WHEN LOWER(TRIM(COALESCE(sm.movement_type, ''))) LIKE '%uretim%'
            OR LOWER(TRIM(COALESCE(sm.movement_type, ''))) LIKE '%üretim%'
          THEN CASE WHEN sm.is_giris THEN 'Üretim Girişi' ELSE 'Üretim Çıkışı' END
          WHEN LOWER(TRIM(COALESCE(sm.movement_type, ''))) IN ('giriş', 'giris', 'girdi')
          THEN 'Stok Giriş'
          WHEN LOWER(TRIM(COALESCE(sm.movement_type, ''))) IN ('çıkış', 'cikis', 'çıktı', 'cikti')
          THEN 'Stok Çıkış'
          ELSE COALESCE(
            NULLIF(TRIM(sm.movement_type), ''),
            CASE WHEN sm.is_giris THEN 'Stok Giriş' ELSE 'Stok Çıkış' END
          )
        END AS islem,
        p.kod AS kod,
        p.ad AS ad,
        COALESCE(p.birim, 'Adet') AS birim,
        ABS(COALESCE(sm.quantity, 0)) AS miktar,
        COALESCE(sm.unit_price, 0) AS birim_fiyati,
        COALESCE(
          NULLIF(it.item->>'discountRate', '')::numeric,
          0
        ) AS isk_orani,
        COALESCE(
          NULLIF(it.item->>'vatRate', '')::numeric,
          COALESCE(p.kdv_orani, 0),
          0
        ) AS kdv_orani,
        COALESCE(NULLIF(it.item->>'otvRate', '')::numeric, 0) AS otv_orani,
        COALESCE(NULLIF(it.item->>'oivRate', '')::numeric, 0) AS oiv_orani,
        COALESCE(
          NULLIF(it.item->>'kdvTevkifatOrani', '')::numeric,
          0
        ) AS kdv_tevkifat_orani,
        COALESCE(doc.yer, '') AS yer,
        COALESCE(doc.yer_kodu, '') AS yer_kodu,
        COALESCE(doc.yer_adi, '') AS yer_adi,
        COALESCE(doc.vkn_tckn, '') AS vkn_tckn,
        COALESCE(doc.fatura_no, '') AS fatura_no,
        COALESCE(doc.irsaliye_no, '') AS irsaliye_no,
        COALESCE(doc.belge, '') AS belge,
        COALESCE(doc.e_belge, '') AS e_belge,
        COALESCE(sm.search_tags, '') AS search_tags_sm,
        COALESCE(p.search_tags, '') AS search_tags_p,
        (
          ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
        ) * (1 -
          (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
        ) AS matrah,
        (
          (
            ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
          ) * (1 -
            (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
          )
        ) * (
          COALESCE(
            NULLIF(it.item->>'vatRate', '')::numeric,
            COALESCE(p.kdv_orani, 0),
            0
          ) / 100.0
        ) AS kdv_tutari,
        (
          (
            ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
          ) * (1 -
            (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
          )
        ) * (COALESCE(NULLIF(it.item->>'otvRate', '')::numeric, 0) / 100.0) AS otv_tutari,
        (
          (
            ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
          ) * (1 -
            (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
          )
        ) * (COALESCE(NULLIF(it.item->>'oivRate', '')::numeric, 0) / 100.0) AS oiv_tutari,
        (
          (
            (
              ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
            ) * (1 -
              (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
            )
          ) * (
            COALESCE(
              NULLIF(it.item->>'vatRate', '')::numeric,
              COALESCE(p.kdv_orani, 0),
              0
            ) / 100.0
          )
        ) * COALESCE(
          NULLIF(it.item->>'kdvTevkifatOrani', '')::numeric,
          0
        ) AS kdv_tevkifat_tutari,
        (
          (
            ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
          ) * (1 -
            (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
          )
        )
        + (
          (
            (
              ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
            ) * (1 -
              (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
            )
          ) * (
            COALESCE(
              NULLIF(it.item->>'vatRate', '')::numeric,
              COALESCE(p.kdv_orani, 0),
              0
            ) / 100.0
          )
        )
        + (
          (
            (
              ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
            ) * (1 -
              (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
            )
          ) * (COALESCE(NULLIF(it.item->>'otvRate', '')::numeric, 0) / 100.0)
        )
        + (
          (
            (
              ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
            ) * (1 -
              (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
            )
          ) * (COALESCE(NULLIF(it.item->>'oivRate', '')::numeric, 0) / 100.0)
        ) AS genel_toplam
      FROM stock_movements sm
      INNER JOIN products p ON p.id = sm.product_id
      LEFT JOIN shipments s ON s.id = sm.shipment_id
      LEFT JOIN LATERAL (
        SELECT elem AS item
        FROM jsonb_array_elements(COALESCE(s.items, '[]'::jsonb)) elem
        WHERE COALESCE(elem->>'code', '') = COALESCE(p.kod, '')
        LIMIT 1
      ) it ON TRUE
       LEFT JOIN LATERAL (
         SELECT
           MAX(NULLIF(TRIM(cat.fatura_no), '')) AS fatura_no,
           MAX(NULLIF(TRIM(cat.irsaliye_no), '')) AS irsaliye_no,
           MAX(NULLIF(TRIM(cat.belge), '')) AS belge,
           MAX(NULLIF(TRIM(cat.e_belge), '')) AS e_belge,
           '' AS yer,
           MAX(NULLIF(TRIM(ca.kod_no), '')) AS yer_kodu,
           MAX(NULLIF(TRIM(ca.adi), '')) AS yer_adi,
           MAX(NULLIF(TRIM(ca.v_numarasi), '')) AS vkn_tckn
         FROM current_account_transactions cat
         LEFT JOIN current_accounts ca ON ca.id = cat.current_account_id
         WHERE cat.integration_ref = sm.integration_ref
       ) doc ON TRUE
    ''';

    final String baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
      $whereSql
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'gid',
    );

    String fmtRate(dynamic value) {
      final rate = _toDouble(value);
      if (rate == 0) return '-';
      return FormatYardimcisi.sayiFormatlaOran(
        rate,
        binlik: _guncelAyarlar?.binlikAyiraci ?? '.',
        ondalik: _guncelAyarlar?.ondalikAyiraci ?? ',',
        decimalDigits: 2,
      );
    }

    String fmtTevkifat(dynamic value) {
      final rate = _toDouble(value);
      if (rate == 0) return '-';
      final int numerator = (rate * 10).round().clamp(0, 10);
      return '$numerator/10';
    }

    String dashIfEmpty(String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? '-' : trimmed;
    }

    String resolveBelgeDurumu({
      required String faturaNo,
      required String irsaliyeNo,
      required String belge,
    }) {
      final rawBelge = belge.trim();
      if (rawBelge.isNotEmpty && rawBelge != '-') return rawBelge;

      final faturaClean = faturaNo.replaceAll('-', '').trim();
      final irsaliyeClean = irsaliyeNo.replaceAll('-', '').trim();
      if (faturaClean.isNotEmpty && irsaliyeClean.isNotEmpty) {
        return 'İrsaliyeli Fatura';
      }
      if (faturaClean.isNotEmpty) return 'Fatura';
      if (irsaliyeClean.isNotEmpty) return 'İrsaliye';
      return 'Yok';
    }

    String resolveYer(String yer, String integrationRef) {
      final trimmed = yer.trim();
      if (trimmed.isNotEmpty) return trimmed;

      final upperRef = integrationRef.trim().toUpperCase();
      if (upperRef.startsWith('RETAIL-')) {
        return tr('reports.payment_types.retail');
      }
      if (upperRef.startsWith('SALE-') || upperRef.startsWith('PURCHASE-')) {
        return tr('cashregisters.transaction.type.current_account');
      }
      return '-';
    }

    final mappedRows = pageResult.rows
        .map((item) {
          final DateTime? tarih = _toDateTime(item['tarih']);
          final bool incoming = item['is_giris'] == true;
          final String islemRaw = item['islem']?.toString() ?? '-';
          final String kod = item['kod']?.toString() ?? '-';
          final String ad = item['ad']?.toString() ?? '-';
          final String birim = item['birim']?.toString() ?? '-';
          final String integrationRef =
              item['integration_ref']?.toString() ?? '';
          final String yer = item['yer']?.toString() ?? '';
          final String yerKodu = item['yer_kodu']?.toString() ?? '';
          final String yerAdi = item['yer_adi']?.toString() ?? '';
          final String vknTckn = item['vkn_tckn']?.toString() ?? '';
          final String faturaNo = item['fatura_no']?.toString() ?? '';
          final String irsaliyeNo = item['irsaliye_no']?.toString() ?? '';
          final String belge = item['belge']?.toString() ?? '';
          final String eBelge = item['e_belge']?.toString() ?? '';
          final String resolvedYer = resolveYer(yer, integrationRef);
          final String belgeDurumu = resolveBelgeDurumu(
            faturaNo: faturaNo,
            irsaliyeNo: irsaliyeNo,
            belge: belge,
          );

          final DetailTable detailTable = DetailTable(
            title: '',
            headers: [
              tr('reports.columns.place_exact'),
              tr('reports.columns.place_code_exact'),
              tr('reports.columns.place_name_exact'),
              'VKN/TCKN',
              tr('reports.columns.invoice_no_exact'),
              tr('reports.columns.document_exact'),
              tr('reports.columns.e_document_exact'),
            ],
            data: [
              [
                dashIfEmpty(resolvedYer),
                dashIfEmpty(yerKodu),
                dashIfEmpty(yerAdi),
                dashIfEmpty(vknTckn),
                dashIfEmpty(faturaNo),
                belgeDurumu,
                dashIfEmpty(eBelge),
              ],
            ],
          );
          final double miktar = _toDouble(item['miktar']);
          final double birimFiyati = _toDouble(item['birim_fiyati']);
          final double matrah = _toDouble(item['matrah']);
          final double kdvTutari = _toDouble(item['kdv_tutari']);
          final double otvTutari = _toDouble(item['otv_tutari']);
          final double oivTutari = _toDouble(item['oiv_tutari']);
          final double genelToplam = _toDouble(item['genel_toplam']);
          final double iskOrani = _toDouble(item['isk_orani']);

          final Map<String, String> cells = {
            'islem': IslemCeviriYardimcisi.cevir(islemRaw),
            'tarih': _formatDate(tarih, includeTime: true),
            'kod': kod,
            'ad': ad,
            'miktar': miktar == 0 ? '-' : _formatQuantity(miktar),
            'birim': birim,
            'kdv_orani': fmtRate(item['kdv_orani']),
            'otv_orani': fmtRate(item['otv_orani']),
            'oiv_orani': fmtRate(item['oiv_orani']),
            'tevkifat': fmtTevkifat(item['kdv_tevkifat_orani']),
            'isk_orani': iskOrani == 0 ? '-' : fmtRate(iskOrani),
            'birim_fiyati': birimFiyati == 0 ? '-' : _formatMoney(birimFiyati),
            'matrah': matrah == 0 ? '-' : _formatMoney(matrah),
            'kdv': kdvTutari == 0 ? '-' : _formatMoney(kdvTutari),
            'otv_tutari': otvTutari == 0 ? '-' : _formatMoney(otvTutari),
            'oiv_tutari': oivTutari == 0 ? '-' : _formatMoney(oivTutari),
            'genel_toplam': genelToplam == 0 ? '-' : _formatMoney(genelToplam),
          };

          final Map<String, dynamic> extra = <String, dynamic>{
            'integrationRef': integrationRef,
            'isIncoming': incoming,
          };

          if (searchTokens.isNotEmpty) {
            final mainHaystack = _normalizeArama(
              [
                ...cells.values,
                miktar.toString(),
                birimFiyati.toString(),
                matrah.toString(),
                kdvTutari.toString(),
                otvTutari.toString(),
                oivTutari.toString(),
                genelToplam.toString(),
                iskOrani.toString(),
                _toDouble(item['kdv_orani']).toString(),
                _toDouble(item['otv_orani']).toString(),
                _toDouble(item['oiv_orani']).toString(),
                _toDouble(item['kdv_tevkifat_orani']).toString(),
              ].join(' '),
            );
            final hiddenHaystack = _normalizeArama(
              [
                resolvedYer,
                yerKodu,
                yerAdi,
                vknTckn,
                faturaNo,
                irsaliyeNo,
                belge,
                belgeDurumu,
                eBelge,
                integrationRef,
              ].join(' '),
            );

            final bool matchesInMain = searchTokens.every(
              (token) => mainHaystack.contains(token),
            );
            final bool matchesInHidden = searchTokens.every(
              (token) => hiddenHaystack.contains(token),
            );
            if (!matchesInMain && matchesInHidden) {
              extra['matchedInHidden'] = true;
            }
          }

          return RaporSatiri(
            id: 'kdv_${item['gid']}',
            cells: cells,
            detailTable: detailTable,
            expandable: true,
            sourceMenuIndex: TabAciciScope.urunKartiIndex,
            sourceSearchQuery: ad,
            amountValue: incoming ? genelToplam : -genelToplam,
            sortValues: {
              'islem': islemRaw,
              'tarih': tarih,
              'kod': kod,
              'ad': ad,
              'miktar': miktar,
              'birim': birim,
              'kdv_orani': _toDouble(item['kdv_orani']),
              'otv_orani': _toDouble(item['otv_orani']),
              'oiv_orani': _toDouble(item['oiv_orani']),
              'tevkifat': _toDouble(item['kdv_tevkifat_orani']),
              'isk_orani': iskOrani,
              'birim_fiyati': birimFiyati,
              'matrah': matrah,
              'kdv': kdvTutari,
              'otv_tutari': otvTutari,
              'oiv_tutari': oivTutari,
              'genel_toplam': genelToplam,
            },
            extra: extra,
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summaryCards = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final rows = await _queryMaps(pool, '''
          SELECT
            COALESCE(SUM(CASE WHEN base.is_giris THEN COALESCE(base.kdv_tutari, 0) ELSE 0 END), 0) AS girdi_kdv,
            COALESCE(SUM(CASE WHEN base.is_giris THEN 0 ELSE COALESCE(base.kdv_tutari, 0) END), 0) AS cikti_kdv,
            COALESCE(SUM(COALESCE(base.otv_tutari, 0)), 0) AS otv_tutari,
            COALESCE(SUM(COALESCE(base.oiv_tutari, 0)), 0) AS oiv_tutari,
            COALESCE(SUM(COALESCE(base.kdv_tevkifat_tutari, 0)), 0) AS tevkifat_tutari
          FROM ($baseSelect) base
          $whereSql
          ''', params);
        final data = rows.isEmpty ? const <String, dynamic>{} : rows.first;

        final double girdiKdv = _toDouble(data['girdi_kdv']);
        final double ciktiKdv = _toDouble(data['cikti_kdv']);
        final double otvTutari = _toDouble(data['otv_tutari']);
        final double oivTutari = _toDouble(data['oiv_tutari']);
        final double tevkifatTutari = _toDouble(data['tevkifat_tutari']);

        final cards = <RaporOzetKarti>[
          RaporOzetKarti(
            labelKey: 'Girdi Kdv',
            value: _formatMoney(girdiKdv),
            icon: Icons.south_west_rounded,
            accentColor: const Color(0xFF27AE60),
          ),
          RaporOzetKarti(
            labelKey: 'Çıktı Kdv',
            value: _formatMoney(ciktiKdv),
            icon: Icons.north_east_rounded,
            accentColor: AppPalette.red,
          ),
        ];

        if (otvTutari != 0) {
          cards.add(
            RaporOzetKarti(
              labelKey: 'ÖTV Tutarı',
              value: _formatMoney(otvTutari),
              icon: Icons.percent_rounded,
              accentColor: AppPalette.amber,
            ),
          );
        }
        if (oivTutari != 0) {
          cards.add(
            RaporOzetKarti(
              labelKey: 'ÖİV Tutarı',
              value: _formatMoney(oivTutari),
              icon: Icons.percent_rounded,
              accentColor: AppPalette.amber,
            ),
          );
        }
        if (tevkifatTutari != 0) {
          cards.add(
            RaporOzetKarti(
              labelKey: 'Tevkifat Tutarı',
              value: _formatMoney(tevkifatTutari),
              icon: Icons.percent_rounded,
              accentColor: AppPalette.slate,
            ),
          );
        }

        return cards;
      },
    );

    // İşlem toplamları (filtre dropdown'ı için) - işlem filtresi hariç.
    final islemTotalsKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler.copyWith(clearIslemTuru: true),
      arama: arama,
      extra: 'islem_totals',
    );
    final islemToplamlari = await _getOrComputeIslemToplamlari(
      cacheKey: islemTotalsKey,
      loader: () async {
        final paramsTotals = <String, dynamic>{...params};
        final whereTotals = <String>[];

        if (filtreler.baslangicTarihi != null) {
          whereTotals.add('base.tarih >= @baslangic');
        }
        if (filtreler.bitisTarihi != null) {
          whereTotals.add('base.tarih < @bitis');
        }

        if (belgeFilter != null) {
          final faturaClean =
              "TRIM(REPLACE(COALESCE(base.fatura_no, ''), '-', ''))";
          final irsaliyeClean =
              "TRIM(REPLACE(COALESCE(base.irsaliye_no, ''), '-', ''))";
          switch (belgeFilter) {
            case 'Fatura':
              whereTotals.add("($faturaClean <> '' AND $irsaliyeClean = '')");
              break;
            case 'İrsaliye':
              whereTotals.add("($irsaliyeClean <> '' AND $faturaClean = '')");
              break;
            case 'İrsaliyeli Fatura':
              whereTotals.add("($faturaClean <> '' AND $irsaliyeClean <> '')");
              break;
            case '-':
              whereTotals.add("($faturaClean = '' AND $irsaliyeClean = '')");
              break;
            default:
              break;
          }
        }

        if (eBelgeFilter != null) {
          if (eBelgeFilter == eBelgeVarSentinel) {
            whereTotals.add(
              "COALESCE(NULLIF(TRIM(COALESCE(base.e_belge, '')), ''), '-') <> '-'",
            );
          } else {
            paramsTotals['eBelgeFiltre'] = eBelgeFilter;
            whereTotals.add(
              "normalize_text(COALESCE(NULLIF(base.e_belge, ''), '-')) = normalize_text(@eBelgeFiltre)",
            );
          }
        }

        _addSearchConditionAny(whereTotals, paramsTotals, [
          'COALESCE(base.search_tags_sm, \'\')',
          'COALESCE(base.search_tags_p, \'\')',
          "normalize_text(COALESCE(base.islem, ''))",
          "normalize_text(COALESCE(base.kod, ''))",
          "normalize_text(COALESCE(base.ad, ''))",
          "normalize_text(COALESCE(base.birim, ''))",
          "normalize_text(COALESCE(base.fatura_no, ''))",
          "normalize_text(COALESCE(base.irsaliye_no, ''))",
          "normalize_text(COALESCE(base.e_belge, ''))",
          'COALESCE(base.miktar, 0)::text',
          'COALESCE(base.birim_fiyati, 0)::text',
          'COALESCE(base.matrah, 0)::text',
          'COALESCE(base.kdv_tutari, 0)::text',
          'COALESCE(base.genel_toplam, 0)::text',
        ], effectiveArama);

        final String whereSqlTotals = whereTotals.isEmpty
            ? ''
            : 'WHERE ${whereTotals.join(' AND ')}';

        final totals = await _queryMaps(pool, '''
          SELECT
            base.islem,
            COUNT(*) AS adet,
            COALESCE(SUM(COALESCE(base.kdv_tutari, 0)), 0) AS toplam
          FROM ($baseSelect) base
          $whereSqlTotals
          GROUP BY base.islem
          ORDER BY normalize_text(COALESCE(base.islem, ''))
        ''', paramsTotals);

        return totals
            .map((row) {
              final String rawIslem = row['islem']?.toString() ?? '-';
              final int adet = _toInt(row['adet']) ?? 0;
              final double toplam = _toDouble(row['toplam']);
              return RaporIslemToplami(
                rawIslem: rawIslem,
                islem: IslemCeviriYardimcisi.cevir(rawIslem),
                tutar: _formatMoney(toplam),
                adet: adet,
              );
            })
            .where((item) => item.islem.trim().isNotEmpty && item.islem != '-')
            .toList(growable: false);
      },
    );

    final bool hasOtv = summaryCards.any(
      (card) => card.labelKey == 'ÖTV Tutarı',
    );
    final bool hasOiv = summaryCards.any(
      (card) => card.labelKey == 'ÖİV Tutarı',
    );
    final bool hasTevkifat = summaryCards.any(
      (card) => card.labelKey == 'Tevkifat Tutarı',
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('islem', 'İşlem', 150),
        _column('tarih', 'Tarih', 150),
        _column('kod', 'Kod no', 110),
        _column('ad', 'Adı', 220),
        _column('miktar', 'Miktar', 110, alignment: Alignment.centerRight),
        _column('birim', 'Ölçü', 90),
        _column('kdv_orani', 'KDV%', 80, alignment: Alignment.center),
        if (hasOtv)
          _column('otv_orani', 'ÖTV%', 80, alignment: Alignment.centerRight),
        if (hasOiv)
          _column('oiv_orani', 'ÖİV%', 80, alignment: Alignment.centerRight),
        if (hasTevkifat)
          _column('tevkifat', 'Tevkifat', 90, alignment: Alignment.centerRight),
        _column('isk_orani', 'İsk%', 90, alignment: Alignment.center),
        _column(
          'birim_fiyati',
          'Birim Fiyatı',
          120,
          alignment: Alignment.centerRight,
        ),
        _column('matrah', 'Matrah', 120, alignment: Alignment.centerRight),
        _column('kdv', 'KDV Tutarı', 120, alignment: Alignment.centerRight),
        if (hasOtv)
          _column(
            'otv_tutari',
            'ÖTV Tutarı',
            120,
            alignment: Alignment.centerRight,
          ),
        if (hasOiv)
          _column(
            'oiv_tutari',
            'ÖİV Tutarı',
            120,
            alignment: Alignment.centerRight,
          ),
        _column(
          'genel_toplam',
          'Genel Toplam',
          130,
          alignment: Alignment.centerRight,
        ),
      ],
      rows: mappedRows,
      summaryCards: summaryCards,
      islemToplamlari: islemToplamlari,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildOptimizedAlisSatisHareketleri(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final effectiveArama = _normalizeNumericSearchForReports(arama);

    String sortExpr(String? key) {
      switch (key) {
        case 'tarih':
          return 'base.tarih';
        case 'islem':
          return "COALESCE(base.islem, '')";
        case 'yer':
          return "COALESCE(base.yer, '')";
        case 'yer_kodu':
          return "COALESCE(base.yer_kodu, '')";
        case 'yer_adi':
          return "COALESCE(base.yer_adi, '')";
        case 'vkn_tckn':
          return "COALESCE(base.vkn_tckn, '')";
        case 'matrah':
          return 'base.matrah';
        case 'kdv':
          return 'base.kdv';
        case 'toplam_vergi':
          return 'base.toplam_vergi';
        case 'genel_toplam':
          return 'base.genel_toplam';
        case 'kur':
          return 'base.kur';
        case 'belge':
          return "COALESCE(base.belge, '')";
        case 'e_belge':
          return "COALESCE(base.e_belge, '')";
        case 'irsaliye_no':
          return "COALESCE(base.irsaliye_no, '')";
        case 'fatura_no':
          return "COALESCE(base.fatura_no, '')";
        case 'aciklama':
          return "COALESCE(base.aciklama, '')";
        case 'kullanici':
          return "COALESCE(base.kullanici, '')";
        default:
          return 'base.tarih';
      }
    }

    final params = <String, dynamic>{};
    final where = <String>[];

    if (filtreler.baslangicTarihi != null) {
      params['baslangic'] = DateTime(
        filtreler.baslangicTarihi!.year,
        filtreler.baslangicTarihi!.month,
        filtreler.baslangicTarihi!.day,
      ).toIso8601String();
      where.add('base.tarih >= @baslangic');
    }
    if (filtreler.bitisTarihi != null) {
      params['bitis'] = DateTime(
        filtreler.bitisTarihi!.year,
        filtreler.bitisTarihi!.month,
        filtreler.bitisTarihi!.day,
      ).add(const Duration(days: 1)).toIso8601String();
      where.add('base.tarih < @bitis');
    }

    final String? islemTuruFilter = _emptyToNull(filtreler.islemTuru);
    if (islemTuruFilter != null) {
      params['islemTuru'] = islemTuruFilter;
      where.add(
        "normalize_text(COALESCE(base.islem, '')) = normalize_text(@islemTuru)",
      );
    }

    final String? belgeFilter = _emptyToNull(filtreler.belgeNo);
    if (belgeFilter != null) {
      final faturaClean =
          "TRIM(REPLACE(COALESCE(base.fatura_no, ''), '-', ''))";
      final irsaliyeClean =
          "TRIM(REPLACE(COALESCE(base.irsaliye_no, ''), '-', ''))";

      switch (belgeFilter) {
        case 'Fatura':
          where.add("($faturaClean <> '' AND $irsaliyeClean = '')");
          break;
        case 'İrsaliye':
          where.add("($irsaliyeClean <> '' AND $faturaClean = '')");
          break;
        case 'İrsaliyeli Fatura':
          where.add("($faturaClean <> '' AND $irsaliyeClean <> '')");
          break;
        case '-':
          where.add("($faturaClean = '' AND $irsaliyeClean = '')");
          break;
        default:
          break;
      }
    }

    const String eBelgeVarSentinel = '__HAS_EBELGE__';
    final String? eBelgeFilter = _emptyToNull(filtreler.referansNo);
    if (eBelgeFilter != null) {
      if (eBelgeFilter == eBelgeVarSentinel) {
        where.add(
          "COALESCE(NULLIF(TRIM(COALESCE(base.e_belge, '')), ''), '-') <> '-'",
        );
      } else {
        params['eBelgeFiltre'] = eBelgeFilter;
        where.add(
          "normalize_text(COALESCE(NULLIF(base.e_belge, ''), '-')) = normalize_text(@eBelgeFiltre)",
        );
      }
    }

    _addSearchConditionAny(where, params, [
      'COALESCE(base.search_tags_sm, \'\')',
      'COALESCE(base.search_tags_cat, \'\')',
      'COALESCE(base.search_tags_ca, \'\')',
      "normalize_text(COALESCE(base.islem, ''))",
      "normalize_text(COALESCE(base.yer, ''))",
      "normalize_text(COALESCE(base.yer_kodu, ''))",
      "normalize_text(COALESCE(base.yer_adi, ''))",
      "normalize_text(COALESCE(base.vkn_tckn, ''))",
      "normalize_text(COALESCE(base.belge, ''))",
      "normalize_text(COALESCE(base.fatura_no, ''))",
      "normalize_text(COALESCE(base.irsaliye_no, ''))",
      "normalize_text(COALESCE(base.e_belge, ''))",
      "normalize_text(COALESCE(base.aciklama, ''))",
      "normalize_text(COALESCE(base.kullanici, ''))",
      // Numeric columns (best-effort, matches raw DB representation)
      'COALESCE(base.matrah, 0)::text',
      'COALESCE(base.kdv, 0)::text',
      'COALESCE(base.toplam_vergi, 0)::text',
      'COALESCE(base.genel_toplam, 0)::text',
      'COALESCE(base.kur, 0)::text',
    ], effectiveArama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final yerCariHesapLabel = tr(
      'cashregisters.transaction.type.current_account',
    ).replaceAll("'", "''");
    final yerPerakendeLabel = tr(
      'reports.payment_types.retail',
    ).replaceAll("'", "''");

    final String baseSelect =
        '''
      WITH lines AS (
        SELECT
          sm.id,
          sm.movement_date AS tarih,
          COALESCE(sm.integration_ref, '') AS integration_ref,
          COALESCE(sm.description, '') AS aciklama_sm,
          COALESCE(sm.created_by, '') AS kullanici_sm,
          CASE
            WHEN COALESCE(sm.integration_ref, '') ILIKE 'PURCHASE-%'
            THEN 'Alış Yapıldı'
            WHEN COALESCE(sm.integration_ref, '') ILIKE 'SALE-%'
              OR COALESCE(sm.integration_ref, '') ILIKE 'RETAIL-%'
            THEN 'Satış Yapıldı'
            ELSE COALESCE(NULLIF(TRIM(sm.movement_type), ''), 'Satış Yapıldı')
          END AS islem,
          COALESCE(sm.search_tags, '') AS search_tags_sm,
          (
            ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
          ) * (1 -
            (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
          ) AS matrah,
          (
            (
              ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
            ) * (1 -
              (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
            )
          ) * (
            COALESCE(
              NULLIF(it.item->>'vatRate', '')::numeric,
              COALESCE(p.kdv_orani, 0),
              0
            ) / 100.0
          ) AS kdv_tutari,
          (
            (
              ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
            ) * (1 -
              (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
            )
          ) * (COALESCE(NULLIF(it.item->>'otvRate', '')::numeric, 0) / 100.0) AS otv_tutari,
          (
            (
              ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
            ) * (1 -
              (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
            )
          ) * (COALESCE(NULLIF(it.item->>'oivRate', '')::numeric, 0) / 100.0) AS oiv_tutari,
          (
            (
              (
                ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
              ) * (1 -
                (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
              )
            ) * (
              COALESCE(
                NULLIF(it.item->>'vatRate', '')::numeric,
                COALESCE(p.kdv_orani, 0),
                0
              ) / 100.0
            )
          ) * COALESCE(
            NULLIF(it.item->>'kdvTevkifatOrani', '')::numeric,
            0
          ) AS tevkifat_tutari,
          (
            (
              ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
            ) * (1 -
              (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
            )
          )
          + (
            (
              (
                ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
              ) * (1 -
                (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
              )
            ) * (
              COALESCE(
                NULLIF(it.item->>'vatRate', '')::numeric,
                COALESCE(p.kdv_orani, 0),
                0
              ) / 100.0
            )
          )
          + (
            (
              (
                ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
              ) * (1 -
                (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
              )
            ) * (COALESCE(NULLIF(it.item->>'otvRate', '')::numeric, 0) / 100.0)
          )
          + (
            (
              (
                ABS(COALESCE(sm.quantity, 0)) * COALESCE(sm.unit_price, 0)
              ) * (1 -
                (COALESCE(NULLIF(it.item->>'discountRate', '')::numeric, 0) / 100.0)
              )
            ) * (COALESCE(NULLIF(it.item->>'oivRate', '')::numeric, 0) / 100.0)
          ) AS genel_toplam
        FROM stock_movements sm
        INNER JOIN products p ON p.id = sm.product_id
        LEFT JOIN shipments s ON s.id = sm.shipment_id
        LEFT JOIN LATERAL (
          SELECT elem AS item
          FROM jsonb_array_elements(COALESCE(s.items, '[]'::jsonb)) elem
          WHERE COALESCE(elem->>'code', '') = COALESCE(p.kod, '')
          LIMIT 1
        ) it ON TRUE
        WHERE (
          COALESCE(sm.integration_ref, '') ILIKE 'PURCHASE-%'
          OR COALESCE(sm.integration_ref, '') ILIKE 'SALE-%'
          OR COALESCE(sm.integration_ref, '') ILIKE 'RETAIL-%'
        )
      ),
      grouped AS (
        SELECT
          MIN(id)::bigint AS gid,
          MAX(tarih) AS tarih,
          MAX(islem) AS islem,
          integration_ref,
          MAX(NULLIF(TRIM(aciklama_sm), '')) AS aciklama_sm,
          MAX(NULLIF(TRIM(kullanici_sm), '')) AS kullanici_sm,
          MAX(search_tags_sm) AS search_tags_sm,
          COALESCE(SUM(matrah), 0) AS matrah,
          COALESCE(SUM(kdv_tutari), 0) AS kdv,
          COALESCE(SUM(otv_tutari), 0) AS otv_tutari,
          COALESCE(SUM(oiv_tutari), 0) AS oiv_tutari,
          COALESCE(SUM(tevkifat_tutari), 0) AS tevkifat_tutari,
          COALESCE(SUM(genel_toplam), 0) AS genel_toplam
        FROM lines
        GROUP BY integration_ref
      )
      SELECT
        g.gid,
        g.tarih,
        g.islem,
        g.integration_ref,
        CASE
          WHEN COALESCE(g.integration_ref, '') ILIKE 'RETAIL-%' THEN '$yerPerakendeLabel'
          WHEN COALESCE(g.integration_ref, '') ILIKE 'SALE-%'
            OR COALESCE(g.integration_ref, '') ILIKE 'PURCHASE-%'
          THEN '$yerCariHesapLabel'
          ELSE ''
        END AS yer,
        COALESCE(doc.yer_kodu, '') AS yer_kodu,
        COALESCE(doc.yer_adi, '') AS yer_adi,
        COALESCE(doc.vkn_tckn, '') AS vkn_tckn,
        COALESCE(doc.fatura_no, '') AS fatura_no,
        COALESCE(doc.irsaliye_no, '') AS irsaliye_no,
        COALESCE(doc.e_belge, '') AS e_belge,
        COALESCE(doc.para_birimi, '') AS para_birimi,
        COALESCE(doc.kur, 1) AS kur,
        CASE
          WHEN TRIM(COALESCE(doc.fatura_no, '')) <> '' AND TRIM(COALESCE(doc.irsaliye_no, '')) <> '' THEN 'İrsaliyeli Fatura'
          WHEN TRIM(COALESCE(doc.fatura_no, '')) <> '' AND TRIM(COALESCE(doc.irsaliye_no, '')) = '' THEN 'Fatura'
          WHEN TRIM(COALESCE(doc.irsaliye_no, '')) <> '' AND TRIM(COALESCE(doc.fatura_no, '')) = '' THEN 'İrsaliye'
          ELSE 'Yok'
        END AS belge,
        COALESCE(
          NULLIF(TRIM(COALESCE(doc.aciklama, '')), ''),
          COALESCE(g.aciklama_sm, ''),
          ''
        ) AS aciklama,
        COALESCE(
          NULLIF(TRIM(COALESCE(doc.kullanici, '')), ''),
          COALESCE(g.kullanici_sm, ''),
          ''
        ) AS kullanici,
        COALESCE(doc.search_tags_cat, '') AS search_tags_cat,
        COALESCE(doc.search_tags_ca, '') AS search_tags_ca,
        COALESCE(g.search_tags_sm, '') AS search_tags_sm,
        g.matrah,
        g.kdv,
        g.otv_tutari,
        g.oiv_tutari,
        g.tevkifat_tutari,
        (g.kdv + g.otv_tutari + g.oiv_tutari) AS toplam_vergi,
        g.genel_toplam
      FROM grouped g
      LEFT JOIN LATERAL (
        SELECT
          MAX(NULLIF(TRIM(cat.fatura_no), '')) AS fatura_no,
          MAX(NULLIF(TRIM(cat.irsaliye_no), '')) AS irsaliye_no,
          MAX(NULLIF(TRIM(cat.e_belge), '')) AS e_belge,
          MAX(NULLIF(TRIM(cat.para_birimi), '')) AS para_birimi,
          MAX(COALESCE(cat.kur, 1)) AS kur,
          MAX(NULLIF(TRIM(cat.user_name), '')) AS kullanici,
          MAX(NULLIF(TRIM(cat.description), '')) AS aciklama,
          MAX(COALESCE(cat.search_tags, '')) AS search_tags_cat,
          MAX(NULLIF(TRIM(ca.kod_no), '')) AS yer_kodu,
          MAX(NULLIF(TRIM(ca.adi), '')) AS yer_adi,
          MAX(NULLIF(TRIM(ca.v_numarasi), '')) AS vkn_tckn,
          MAX(COALESCE(ca.search_tags, '')) AS search_tags_ca
        FROM current_account_transactions cat
        LEFT JOIN current_accounts ca ON ca.id = cat.current_account_id
        WHERE cat.integration_ref = g.integration_ref
      ) doc ON TRUE
    ''';

    final String baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
      $whereSql
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'gid',
    );

    String dashIfEmpty(String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? '-' : trimmed;
    }

    final mappedRows = pageResult.rows
        .map((item) {
          final DateTime? tarih = _toDateTime(item['tarih']);
          final String islemRaw = item['islem']?.toString() ?? '-';
          final String integrationRef =
              item['integration_ref']?.toString() ?? '';
          final double matrah = _toDouble(item['matrah']);
          final double kdv = _toDouble(item['kdv']);
          final double toplamVergi = _toDouble(item['toplam_vergi']);
          final double genelToplam = _toDouble(item['genel_toplam']);

          final Map<String, dynamic> extra = <String, dynamic>{};
          if (integrationRef.trim().isNotEmpty) {
            extra['integrationRef'] = integrationRef.trim();
          }

          return RaporSatiri(
            id: 'purchase_sales_${item['gid']}',
            cells: {
              'tarih': _formatDate(tarih, includeTime: true),
              'islem': IslemCeviriYardimcisi.cevir(islemRaw),
              'yer': dashIfEmpty(item['yer']?.toString() ?? ''),
              'yer_kodu': dashIfEmpty(item['yer_kodu']?.toString() ?? ''),
              'yer_adi': dashIfEmpty(item['yer_adi']?.toString() ?? ''),
              'vkn_tckn': dashIfEmpty(item['vkn_tckn']?.toString() ?? ''),
              'matrah': matrah == 0 ? '-' : _formatMoney(matrah),
              'kdv': kdv == 0 ? '-' : _formatMoney(kdv),
              'toplam_vergi': toplamVergi == 0
                  ? '-'
                  : _formatMoney(toplamVergi),
              'genel_toplam': genelToplam == 0
                  ? '-'
                  : _formatMoney(genelToplam),
              'kur': _formatExchangeRate(item['kur']),
              'belge': dashIfEmpty(item['belge']?.toString() ?? ''),
              'e_belge': dashIfEmpty(item['e_belge']?.toString() ?? ''),
              'irsaliye_no': dashIfEmpty(item['irsaliye_no']?.toString() ?? ''),
              'fatura_no': dashIfEmpty(item['fatura_no']?.toString() ?? ''),
              'aciklama': dashIfEmpty(item['aciklama']?.toString() ?? ''),
              'kullanici': dashIfEmpty(item['kullanici']?.toString() ?? ''),
            },
            amountValue: genelToplam,
            sortValues: {
              'tarih': tarih,
              'islem': islemRaw,
              'yer': item['yer'],
              'yer_kodu': item['yer_kodu'],
              'yer_adi': item['yer_adi'],
              'vkn_tckn': item['vkn_tckn'],
              'matrah': matrah,
              'kdv': kdv,
              'toplam_vergi': toplamVergi,
              'genel_toplam': genelToplam,
              'kur': _toDouble(item['kur']),
              'belge': item['belge'],
              'e_belge': item['e_belge'],
              'irsaliye_no': item['irsaliye_no'],
              'fatura_no': item['fatura_no'],
              'aciklama': item['aciklama'],
              'kullanici': item['kullanici'],
            },
            extra: extra.isEmpty ? const <String, dynamic>{} : extra,
          );
        })
        .toList(growable: false);

    bool hasAnyValue(String key) {
      for (final row in mappedRows) {
        final String raw = row.cells[key] ?? '';
        final String trimmed = raw.trim();
        if (trimmed.isEmpty || trimmed == '-') continue;
        return true;
      }
      return false;
    }

    final bool hasYerKodu = hasAnyValue('yer_kodu');
    final bool hasYerAdi = hasAnyValue('yer_adi');
    final bool hasVknTckn = hasAnyValue('vkn_tckn');
    final bool hasKur = hasAnyValue('kur');
    final bool hasBelge = hasAnyValue('belge');
    final bool hasEBelge = hasAnyValue('e_belge');
    final bool hasIrsaliyeNo = hasAnyValue('irsaliye_no');
    final bool hasFaturaNo = hasAnyValue('fatura_no');
    final bool hasAciklama = hasAnyValue('aciklama');
    final bool hasKullanici = hasAnyValue('kullanici');

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summaryCardsFuture = _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final rows = await _queryMaps(pool, '''
          SELECT
            COALESCE(SUM(COALESCE(base.matrah, 0)), 0) AS matrah,
            COALESCE(SUM(COALESCE(base.kdv, 0)), 0) AS kdv,
            COALESCE(SUM(COALESCE(base.toplam_vergi, 0)), 0) AS toplam_vergi,
            COALESCE(SUM(COALESCE(base.genel_toplam, 0)), 0) AS genel_toplam,
            COALESCE(SUM(COALESCE(base.otv_tutari, 0)), 0) AS otv_tutari,
            COALESCE(SUM(COALESCE(base.oiv_tutari, 0)), 0) AS oiv_tutari,
            COALESCE(SUM(COALESCE(base.tevkifat_tutari, 0)), 0) AS tevkifat_tutari
          FROM ($baseSelect) base
          $whereSql
          ''', params);
        final data = rows.isEmpty ? const <String, dynamic>{} : rows.first;

        final double matrah = _toDouble(data['matrah']);
        final double kdv = _toDouble(data['kdv']);
        final double toplamVergi = _toDouble(data['toplam_vergi']);
        final double genelToplam = _toDouble(data['genel_toplam']);
        final double otvTutari = _toDouble(data['otv_tutari']);
        final double oivTutari = _toDouble(data['oiv_tutari']);
        final double tevkifatTutari = _toDouble(data['tevkifat_tutari']);

        final cards = <RaporOzetKarti>[
          RaporOzetKarti(
            labelKey: 'Matrah',
            value: _formatMoney(matrah),
            icon: Icons.calculate_outlined,
            accentColor: AppPalette.slate,
          ),
          RaporOzetKarti(
            labelKey: 'KDV %18',
            value: _formatMoney(kdv),
            icon: Icons.percent_rounded,
            accentColor: AppPalette.amber,
          ),
          RaporOzetKarti(
            labelKey: 'Toplam Vergi',
            value: _formatMoney(toplamVergi),
            icon: Icons.receipt_long_outlined,
            accentColor: AppPalette.slate,
          ),
          RaporOzetKarti(
            labelKey: 'Genel Toplam',
            value: _formatMoney(genelToplam),
            icon: Icons.summarize_outlined,
            accentColor: AppPalette.slate,
          ),
        ];

        if (otvTutari != 0) {
          cards.add(
            RaporOzetKarti(
              labelKey: 'ÖTV Tutarı',
              value: _formatMoney(otvTutari),
              icon: Icons.percent_rounded,
              accentColor: AppPalette.amber,
            ),
          );
        }
        if (oivTutari != 0) {
          cards.add(
            RaporOzetKarti(
              labelKey: 'ÖİV Tutarı',
              value: _formatMoney(oivTutari),
              icon: Icons.percent_rounded,
              accentColor: AppPalette.amber,
            ),
          );
        }
        if (tevkifatTutari != 0) {
          cards.add(
            RaporOzetKarti(
              labelKey: 'Tevkifat Tutarı',
              value: _formatMoney(tevkifatTutari),
              icon: Icons.percent_rounded,
              accentColor: AppPalette.slate,
            ),
          );
        }

        return cards;
      },
    );

    // İşlem toplamları (filtre dropdown'ı için) - işlem filtresi hariç.
    final islemTotalsKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler.copyWith(clearIslemTuru: true),
      arama: arama,
      extra: 'islem_totals',
    );
    final islemToplamlariFuture = _getOrComputeIslemToplamlari(
      cacheKey: islemTotalsKey,
      loader: () async {
        final paramsTotals = <String, dynamic>{...params};
        final whereTotals = <String>[];

        if (filtreler.baslangicTarihi != null) {
          whereTotals.add('base.tarih >= @baslangic');
        }
        if (filtreler.bitisTarihi != null) {
          whereTotals.add('base.tarih < @bitis');
        }

        if (belgeFilter != null) {
          final faturaClean =
              "TRIM(REPLACE(COALESCE(base.fatura_no, ''), '-', ''))";
          final irsaliyeClean =
              "TRIM(REPLACE(COALESCE(base.irsaliye_no, ''), '-', ''))";

          switch (belgeFilter) {
            case 'Fatura':
              whereTotals.add("($faturaClean <> '' AND $irsaliyeClean = '')");
              break;
            case 'İrsaliye':
              whereTotals.add("($irsaliyeClean <> '' AND $faturaClean = '')");
              break;
            case 'İrsaliyeli Fatura':
              whereTotals.add("($faturaClean <> '' AND $irsaliyeClean <> '')");
              break;
            case '-':
              whereTotals.add("($faturaClean = '' AND $irsaliyeClean = '')");
              break;
            default:
              break;
          }
        }

        if (eBelgeFilter != null) {
          if (eBelgeFilter == eBelgeVarSentinel) {
            whereTotals.add(
              "COALESCE(NULLIF(TRIM(COALESCE(base.e_belge, '')), ''), '-') <> '-'",
            );
          } else {
            paramsTotals['eBelgeFiltre'] = eBelgeFilter;
            whereTotals.add(
              "normalize_text(COALESCE(NULLIF(base.e_belge, ''), '-')) = normalize_text(@eBelgeFiltre)",
            );
          }
        }

        _addSearchConditionAny(whereTotals, paramsTotals, [
          'COALESCE(base.search_tags_sm, \'\')',
          'COALESCE(base.search_tags_cat, \'\')',
          'COALESCE(base.search_tags_ca, \'\')',
          "normalize_text(COALESCE(base.islem, ''))",
          "normalize_text(COALESCE(base.yer, ''))",
          "normalize_text(COALESCE(base.yer_kodu, ''))",
          "normalize_text(COALESCE(base.yer_adi, ''))",
          "normalize_text(COALESCE(base.vkn_tckn, ''))",
          "normalize_text(COALESCE(base.belge, ''))",
          "normalize_text(COALESCE(base.fatura_no, ''))",
          "normalize_text(COALESCE(base.irsaliye_no, ''))",
          "normalize_text(COALESCE(base.e_belge, ''))",
          "normalize_text(COALESCE(base.aciklama, ''))",
          // Numeric columns (best-effort, matches raw DB representation)
          'COALESCE(base.matrah, 0)::text',
          'COALESCE(base.kdv, 0)::text',
          'COALESCE(base.genel_toplam, 0)::text',
        ], effectiveArama);

        final String whereSqlTotals = whereTotals.isEmpty
            ? ''
            : 'WHERE ${whereTotals.join(' AND ')}';

        final totals = await _queryMaps(pool, '''
          SELECT
            base.islem,
            COUNT(*) AS adet,
            COALESCE(SUM(COALESCE(base.genel_toplam, 0)), 0) AS toplam
          FROM ($baseSelect) base
          $whereSqlTotals
          GROUP BY base.islem
          ORDER BY normalize_text(COALESCE(base.islem, ''))
        ''', paramsTotals);

        return totals
            .map((row) {
              final String rawIslem = row['islem']?.toString() ?? '-';
              final int adet = _toInt(row['adet']) ?? 0;
              final double toplam = _toDouble(row['toplam']);
              return RaporIslemToplami(
                rawIslem: rawIslem,
                islem: IslemCeviriYardimcisi.cevir(rawIslem),
                tutar: _formatMoney(toplam),
                adet: adet,
              );
            })
            .where((item) => item.islem.trim().isNotEmpty && item.islem != '-')
            .toList(growable: false);
      },
    );

    final summaryCards = await summaryCardsFuture;
    final islemToplamlari = await islemToplamlariFuture;

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tarih', 'Tarih', 150),
        _column('islem', 'İşlem', 150),
        _column('yer', 'Yer', 130),
        if (hasYerKodu) _column('yer_kodu', 'Yer Kodu', 110),
        if (hasYerAdi) _column('yer_adi', 'Yer Adı', 220),
        if (hasVknTckn) _column('vkn_tckn', 'VKN/TCKN', 150),
        _column('matrah', 'Matrah', 130, alignment: Alignment.centerRight),
        _column('kdv', 'KDV %18', 120, alignment: Alignment.centerRight),
        _column(
          'toplam_vergi',
          'Toplam Vergi',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'genel_toplam',
          'Genel Toplam',
          140,
          alignment: Alignment.centerRight,
        ),
        if (hasKur) _column('kur', 'Kur', 90, alignment: Alignment.centerRight),
        if (hasBelge) _column('belge', 'Belge', 150),
        if (hasEBelge) _column('e_belge', 'E-belge', 130),
        if (hasIrsaliyeNo) _column('irsaliye_no', 'İrsaliye No', 150),
        if (hasFaturaNo) _column('fatura_no', 'Fatura No', 150),
        if (hasAciklama) _column('aciklama', 'Açıklama', 240),
        if (hasKullanici) _column('kullanici', 'Kullanıcı', 110),
      ],
      rows: mappedRows,
      summaryCards: summaryCards,
      islemToplamlari: islemToplamlari,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildOptimizedSonIslemTarihi(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final effectiveArama = _normalizeNumericSearchForReports(arama);
    final bool hasSearchTokens = _searchTokens(effectiveArama).isNotEmpty;

    String sortExpr(String? key) {
      switch (key) {
        case 'kod':
          return "COALESCE(base.kod_no, '')";
        case 'ad':
          return "COALESCE(base.adi, '')";
        case 'tur':
          return "COALESCE(base.hesap_turu, '')";
        case 'bakiye_borc':
          return 'base.bakiye_borc';
        case 'bakiye_alacak':
          return 'base.bakiye_alacak';
        case 'son_islem':
          return "COALESCE(base.son_islem, '')";
        case 'son_islem_tutar':
          return 'base.son_islem_tutar';
        case 'son_islem_tarihi':
          return 'base.son_islem_tarihi';
        case 'gecen_gun':
          return 'base.gecen_gun';
        default:
          return 'base.son_islem_tarihi';
      }
    }

    final where = <String>[];
    final params = <String, dynamic>{};

    _addSearchConditionAny(where, params, [
      'COALESCE(ca.search_tags, \'\')',
      "normalize_text(COALESCE(ca.kod_no, ''))",
      "normalize_text(COALESCE(ca.adi, ''))",
      "normalize_text(COALESCE(ca.hesap_turu, ''))",
      "normalize_text(COALESCE(tx.son_islem_turu, ''))",
      // Numeric columns (best-effort, matches raw DB representation)
      'COALESCE(ca.bakiye_borc, 0)::text',
      'COALESCE(ca.bakiye_alacak, 0)::text',
      'COALESCE(tx.son_islem_tutar, 0)::text',
    ], effectiveArama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final txDateConds = <String>['cat.current_account_id = ca.id'];
    if (filtreler.baslangicTarihi != null) {
      params['startDate'] = DateTime(
        filtreler.baslangicTarihi!.year,
        filtreler.baslangicTarihi!.month,
        filtreler.baslangicTarihi!.day,
      ).toIso8601String();
      txDateConds.add('cat.date >= @startDate');
    }
    if (filtreler.bitisTarihi != null) {
      params['endDate'] = DateTime(
        filtreler.bitisTarihi!.year,
        filtreler.bitisTarihi!.month,
        filtreler.bitisTarihi!.day,
      ).add(const Duration(days: 1)).toIso8601String();
      txDateConds.add('cat.date < @endDate');
    }
    final String txDateWhere = txDateConds.join(' AND ');

    final baseSelect =
        '''
      SELECT
        ca.id,
        ca.kod_no,
        ca.adi,
        ca.hesap_turu,
        ca.para_birimi,
        COALESCE(ca.bakiye_borc, 0) AS bakiye_borc,
        COALESCE(ca.bakiye_alacak, 0) AS bakiye_alacak,
        tx.son_islem_tarihi,
        tx.son_islem_turu AS son_islem,
        tx.son_islem_para_birimi,
        tx.son_islem_tutar,
        CASE
          WHEN tx.son_islem_tarihi IS NULL THEN NULL
          ELSE (CURRENT_DATE - tx.son_islem_tarihi::date)
        END AS gecen_gun
      FROM current_accounts ca
      LEFT JOIN LATERAL (
        SELECT
          cat.date AS son_islem_tarihi,
          cat.source_type AS son_islem_turu,
          cat.para_birimi AS son_islem_para_birimi,
          cat.amount AS son_islem_tutar
        FROM current_account_transactions cat
        WHERE $txDateWhere
        ORDER BY cat.date DESC, cat.id DESC
        LIMIT 1
      ) tx ON true
      $whereSql
    ''';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'id',
    );

    final mappedRows = pageResult.rows
        .map((cari) {
          final DateTime? tarih = _toDateTime(cari['son_islem_tarihi']);
          final bool hasTx = tarih != null;
          final double sonIslemTutar = _toDouble(cari['son_islem_tutar']);
          final double bakiyeBorc = _toDouble(cari['bakiye_borc']);
          final double bakiyeAlacak = _toDouble(cari['bakiye_alacak']);
          final String paraBirimi = cari['para_birimi']?.toString() ?? 'TRY';
          final String islemParaBirimi =
              cari['son_islem_para_birimi']?.toString() ?? '';
          final String effectiveIslemParaBirimi = islemParaBirimi.trim().isEmpty
              ? paraBirimi
              : islemParaBirimi;
          final int? gecenGun = _toInt(cari['gecen_gun']);
          return RaporSatiri(
            id: 'son_islem_${cari['id']}',
            cells: {
              'kod': cari['kod_no']?.toString() ?? '-',
              'ad': cari['adi']?.toString() ?? '-',
              'tur': IslemCeviriYardimcisi.cevir(
                cari['hesap_turu']?.toString() ?? '-',
              ),
              'bakiye_borc': _formatMoney(bakiyeBorc, currency: paraBirimi),
              'bakiye_alacak': _formatMoney(bakiyeAlacak, currency: paraBirimi),
              'son_islem': hasTx
                  ? IslemCeviriYardimcisi.cevir(
                      cari['son_islem']?.toString() ?? '-',
                    )
                  : '-',
              'son_islem_tutar': hasTx
                  ? _formatMoney(
                      sonIslemTutar,
                      currency: effectiveIslemParaBirimi,
                    )
                  : '-',
              'son_islem_tarihi':
                  hasTx ? _formatDate(tarih, includeTime: true) : '-',
              'gecen_gun': hasTx ? (gecenGun ?? 0).toString() : '-',
            },
            sourceMenuIndex: TabAciciScope.cariKartiIndex,
            sourceSearchQuery: cari['adi']?.toString(),
            amountValue: sonIslemTutar,
            sortValues: {
              'kod': cari['kod_no'],
              'ad': cari['adi'],
              'tur': cari['hesap_turu'],
              'bakiye_borc': bakiyeBorc,
              'bakiye_alacak': bakiyeAlacak,
              'son_islem': cari['son_islem'],
              'son_islem_tutar': sonIslemTutar,
              'son_islem_tarihi': tarih,
              'gecen_gun': gecenGun,
            },
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summary = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final String query = hasSearchTokens
            ? 'SELECT COUNT(*) AS kayit FROM ($baseSelect) base'
            : 'SELECT COUNT(*) AS kayit FROM current_accounts ca';
        final rows = await _queryMaps(pool, query, params);
        final int kayit = rows.isEmpty
            ? 0
            : (rows.first['kayit'] as num?)?.toInt() ?? 0;
        return [
          RaporOzetKarti(
            labelKey: 'reports.summary.record',
            value: kayit.toString(),
            icon: Icons.event_repeat_outlined,
            accentColor: AppPalette.slate,
          ),
        ];
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('kod', 'common.code_no', 120),
        _column('ad', 'common.name', 220),
        _column('tur', 'accounts.table.account_type', 140),
        _column(
          'bakiye_borc',
          'accounts.balance.debit_label',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'bakiye_alacak',
          'accounts.balance.credit_label',
          130,
          alignment: Alignment.centerRight,
        ),
        _column('son_islem', 'reports.columns.last_transaction', 140),
        _column(
          'son_islem_tutar',
          'reports.columns.last_transaction_amount',
          140,
          alignment: Alignment.centerRight,
        ),
        _column(
          'son_islem_tarihi',
          'reports.columns.last_transaction_date',
          140,
        ),
        _column(
          'gecen_gun',
          'reports.columns.days_passed',
          110,
          alignment: Alignment.centerRight,
        ),
      ],
      rows: mappedRows,
      summaryCards: summary,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildOptimizedKarZarar(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final effectiveArama = _normalizeNumericSearchForReports(arama);

    String sortExpr(String? key) {
      switch (key) {
        case 'kod':
          return "COALESCE(base.kod, '')";
        case 'ad':
          return "COALESCE(base.ad, '')";
        case 'grup':
          return "COALESCE(base.grup, '')";
        case 'devreden':
          return 'base.devreden';
        case 'eklenen':
          return 'base.eklenen';
        case 'devreden_eklenen':
          return 'base.devreden_eklenen';
        case 'satilan':
          return 'base.satilan';
        case 'kalan':
          return 'base.kalan';
        case 'birim':
          return "COALESCE(base.birim, '')";
        case 'dev_ekl_stok_degeri':
          return 'base.dev_ekl_stok_degeri';
        case 'sat_mal_top_alis_degeri':
          return 'base.sat_mal_top_alis_degeri';
        case 'toplam_satis_degeri':
          return 'base.toplam_satis_degeri';
        case 'kalan_stok_degeri':
          return 'base.kalan_stok_degeri';
        case 'brut_kar':
          return 'base.brut_kar';
        default:
          return "COALESCE(base.ad, '')";
      }
    }

    final params = <String, dynamic>{};

    final purchaseWhere = <String>[
      'sm.is_giris = true',
      '('
          "COALESCE(sm.integration_ref, '') LIKE 'PURCHASE-%'"
          " OR COALESCE(sm.integration_ref, '') = 'opening_stock'"
          ')',
    ];
    final saleWhere = <String>[
      'sm.is_giris = false',
      '('
          "COALESCE(sm.integration_ref, '') LIKE 'SALE-%'"
          " OR COALESCE(sm.integration_ref, '') LIKE 'RETAIL-%'"
          ')',
    ];

    if (filtreler.baslangicTarihi != null) {
      params['baslangic'] = DateTime(
        filtreler.baslangicTarihi!.year,
        filtreler.baslangicTarihi!.month,
        filtreler.baslangicTarihi!.day,
      ).toIso8601String();
      purchaseWhere.add('sm.movement_date >= @baslangic');
      saleWhere.add('sm.movement_date >= @baslangic');
    }

    if (filtreler.bitisTarihi != null) {
      params['bitis'] = DateTime(
        filtreler.bitisTarihi!.year,
        filtreler.bitisTarihi!.month,
        filtreler.bitisTarihi!.day,
      ).add(const Duration(days: 1)).toIso8601String();
      purchaseWhere.add('sm.movement_date < @bitis');
      saleWhere.add('sm.movement_date < @bitis');
    }

    final startSnapshotCte = filtreler.baslangicTarihi == null
        ? '''
      start_snapshot AS (
        SELECT NULL::bigint AS product_id,
               0::numeric AS devreden_qty,
               0::numeric AS devreden_cost
        WHERE FALSE
      )
      '''
        : '''
      start_snapshot AS (
        SELECT DISTINCT ON (sm.product_id)
          sm.product_id,
          COALESCE(sm.running_stock, 0) AS devreden_qty,
          COALESCE(sm.running_cost, 0) AS devreden_cost
        FROM stock_movements sm
        WHERE sm.movement_date < @baslangic
        ORDER BY sm.product_id, sm.movement_date DESC, sm.id DESC
      )
      ''';

    final where = <String>[
      '(COALESCE(ss.devreden_qty, 0) <> 0 '
          'OR COALESCE(pur.eklenen_qty, 0) <> 0 '
          'OR COALESCE(sal.satilan_qty, 0) <> 0)',
    ];

    final String? selectedGroup = filtreler.urunGrubu?.trim();
    if (selectedGroup != null && selectedGroup.isNotEmpty) {
      params['urunGrubu'] = selectedGroup;
      where.add("TRIM(COALESCE(p.grubu, '')) = @urunGrubu");
    }

    final double? selectedVat = filtreler.kdvOrani;
    if (selectedVat != null) {
      params['kdvOrani'] = selectedVat;
      where.add('COALESCE(p.kdv_orani, 0) = @kdvOrani');
    }
    _addSearchConditionAny(where, params, [
      'p.search_tags',
      "normalize_text(COALESCE(p.kod, ''))",
      "normalize_text(COALESCE(p.ad, ''))",
      "normalize_text(COALESCE(p.grubu, ''))",
      "normalize_text(COALESCE(p.birim, ''))",
      "normalize_text(COALESCE(p.ozellikler::text, ''))",
      // Numeric columns (best-effort, matches raw DB representation)
      'COALESCE(ss.devreden_qty, 0)::text',
      'COALESCE(pur.eklenen_qty, 0)::text',
      '(COALESCE(ss.devreden_qty, 0) + COALESCE(pur.eklenen_qty, 0))::text',
      'COALESCE(sal.satilan_qty, 0)::text',
      '(COALESCE(ss.devreden_qty, 0) + COALESCE(pur.eklenen_qty, 0) - COALESCE(sal.satilan_qty, 0))::text',
      'COALESCE(sal.cogs_value, 0)::text',
      'COALESCE(sal.satis_value, 0)::text',
      '(COALESCE(sal.satis_value, 0) - COALESCE(sal.cogs_value, 0))::text',
    ], effectiveArama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final baseSelect =
        '''
      WITH
      $startSnapshotCte,
      purchases AS (
        SELECT
          sm.product_id,
          COALESCE(SUM(sm.quantity), 0) AS eklenen_qty,
          COALESCE(
            SUM(
              sm.quantity
              * COALESCE(sm.unit_price, 0)
              * COALESCE(sm.currency_rate, 1)
            ),
            0
          ) AS eklenen_value
        FROM stock_movements sm
        WHERE ${purchaseWhere.join(' AND ')}
        GROUP BY sm.product_id
      ),
      sales AS (
        SELECT
          sm.product_id,
          COALESCE(SUM(sm.quantity), 0) AS satilan_qty,
          COALESCE(
            SUM(
              sm.quantity
              * COALESCE(sm.unit_price, 0)
              * COALESCE(sm.currency_rate, 1)
            ),
            0
          ) AS satis_value,
          COALESCE(
            SUM(sm.quantity * COALESCE(sm.running_cost, 0)),
            0
          ) AS cogs_value
        FROM stock_movements sm
        WHERE ${saleWhere.join(' AND ')}
        GROUP BY sm.product_id
      )
      SELECT
        p.id,
        p.kod,
        p.ad,
        COALESCE(p.grubu, '') AS grup,
        p.ozellikler,
        COALESCE(p.birim, 'Adet') AS birim,
        COALESCE(ss.devreden_qty, 0) AS devreden,
        COALESCE(pur.eklenen_qty, 0) AS eklenen,
        (COALESCE(ss.devreden_qty, 0) + COALESCE(pur.eklenen_qty, 0)) AS devreden_eklenen,
        COALESCE(sal.satilan_qty, 0) AS satilan,
        (COALESCE(ss.devreden_qty, 0) + COALESCE(pur.eklenen_qty, 0) - COALESCE(sal.satilan_qty, 0)) AS kalan,
        (
          (COALESCE(ss.devreden_qty, 0) * COALESCE(ss.devreden_cost, 0))
          + COALESCE(pur.eklenen_value, 0)
        ) AS dev_ekl_stok_degeri,
        COALESCE(sal.cogs_value, 0) AS sat_mal_top_alis_degeri,
        COALESCE(sal.satis_value, 0) AS toplam_satis_degeri,
        (
          (
            (COALESCE(ss.devreden_qty, 0) * COALESCE(ss.devreden_cost, 0))
            + COALESCE(pur.eklenen_value, 0)
          )
          - COALESCE(sal.cogs_value, 0)
        ) AS kalan_stok_degeri,
        (COALESCE(sal.satis_value, 0) - COALESCE(sal.cogs_value, 0)) AS brut_kar
      FROM products p
      LEFT JOIN start_snapshot ss ON ss.product_id = p.id
      LEFT JOIN purchases pur ON pur.product_id = p.id
      LEFT JOIN sales sal ON sal.product_id = p.id
      $whereSql
    ''';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'id',
    );

    final mappedRows = pageResult.rows
        .map((item) {
          final features = _parseFirstThreeFeatureBadges(item['ozellikler']);
          final String featuresText = features.isEmpty
              ? '-'
              : features.map((item) => item.name).join('\n');

          final devreden = _toDouble(item['devreden']);
          final eklenen = _toDouble(item['eklenen']);
          final devredenEklenen = _toDouble(item['devreden_eklenen']);
          final satilan = _toDouble(item['satilan']);
          final kalan = _toDouble(item['kalan']);

          final devEklStokDegeri = _toDouble(item['dev_ekl_stok_degeri']);
          final satMalTopAlisDegeri = _toDouble(
            item['sat_mal_top_alis_degeri'],
          );
          final toplamSatisDegeri = _toDouble(item['toplam_satis_degeri']);
          final kalanStokDegeri = _toDouble(item['kalan_stok_degeri']);
          final brutKar = _toDouble(item['brut_kar']);

          return RaporSatiri(
            id: 'profit_loss_${item['id']}',
            cells: {
              'kod': item['kod']?.toString() ?? '-',
              'ad': item['ad']?.toString() ?? '-',
              'grup': item['grup']?.toString() ?? '-',
              'ozellik': featuresText,
              'devreden': _formatQuantity(devreden),
              'eklenen': _formatQuantity(eklenen),
              'devreden_eklenen': _formatQuantity(devredenEklenen),
              'satilan': _formatQuantity(satilan),
              'kalan': _formatQuantity(kalan),
              'birim': item['birim']?.toString() ?? '-',
              'dev_ekl_stok_degeri': _formatMoney(devEklStokDegeri),
              'sat_mal_top_alis_degeri': _formatMoney(satMalTopAlisDegeri),
              'toplam_satis_degeri': _formatMoney(toplamSatisDegeri),
              'kalan_stok_degeri': _formatMoney(kalanStokDegeri),
              'brut_kar': _formatMoney(brutKar),
            },
            extra: {
              'features': features
                  .map(
                    (item) => <String, dynamic>{
                      'name': item.name,
                      'color': item.color,
                    },
                  )
                  .toList(growable: false),
            },
            amountValue: brutKar,
            sortValues: {
              'kod': item['kod'],
              'ad': item['ad'],
              'grup': item['grup'],
              'devreden': devreden,
              'eklenen': eklenen,
              'devreden_eklenen': devredenEklenen,
              'satilan': satilan,
              'kalan': kalan,
              'birim': item['birim'],
              'dev_ekl_stok_degeri': devEklStokDegeri,
              'sat_mal_top_alis_degeri': satMalTopAlisDegeri,
              'toplam_satis_degeri': toplamSatisDegeri,
              'kalan_stok_degeri': kalanStokDegeri,
              'brut_kar': brutKar,
            },
          );
        })
        .toList(growable: false);

    final topSummaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
      extra: 'profit_loss_top',
    );
    final topSummary = await _getOrComputeProfitLossTopSummary(
      cacheKey: topSummaryKey,
      loader: () async {
        final summaryRows = await _queryMaps(pool, '''
          SELECT
            COUNT(*) AS kayit,
            COUNT(DISTINCT base.birim) AS birim_sayisi,
            MIN(base.birim) AS birim_tek,
            COALESCE(SUM(base.devreden), 0) AS devreden,
            COALESCE(SUM(base.eklenen), 0) AS eklenen,
            COALESCE(SUM(base.devreden_eklenen), 0) AS devreden_eklenen,
            COALESCE(SUM(base.satilan), 0) AS satilan,
            COALESCE(SUM(base.kalan), 0) AS kalan,
            COALESCE(SUM(base.dev_ekl_stok_degeri), 0) AS dev_ekl_stok_degeri,
            COALESCE(SUM(base.sat_mal_top_alis_degeri), 0) AS sat_mal_top_alis_degeri,
            COALESCE(SUM(base.toplam_satis_degeri), 0) AS toplam_satis_degeri,
            COALESCE(SUM(base.kalan_stok_degeri), 0) AS kalan_stok_degeri,
            COALESCE(SUM(base.brut_kar), 0) AS brut_kar
          FROM ($baseSelect) base
          ''', params);

        final data = summaryRows.isEmpty
            ? const <String, dynamic>{}
            : summaryRows.first;
        final birimSayisi = _toInt(data['birim_sayisi']) ?? 0;
        final String birim = birimSayisi == 1
            ? (data['birim_tek']?.toString() ?? '')
            : '';

        final devreden = _toDouble(data['devreden']);
        final eklenen = _toDouble(data['eklenen']);
        final devredenEklenen = _toDouble(data['devreden_eklenen']);
        final satilan = _toDouble(data['satilan']);
        final kalan = _toDouble(data['kalan']);
        final devEklStokDegeri = _toDouble(data['dev_ekl_stok_degeri']);
        final satMalTopAlisDegeri = _toDouble(data['sat_mal_top_alis_degeri']);
        final toplamSatisDegeri = _toDouble(data['toplam_satis_degeri']);
        final kalanStokDegeri = _toDouble(data['kalan_stok_degeri']);
        final brutKar = _toDouble(data['brut_kar']);

        final expWhere = <String>[];
        if (filtreler.baslangicTarihi != null) {
          expWhere.add('e.tarih >= @baslangic');
        }
        if (filtreler.bitisTarihi != null) {
          expWhere.add('e.tarih < @bitis');
        }
        final String expWhereSql = expWhere.isEmpty
            ? ''
            : 'WHERE ${expWhere.join(' AND ')}';
        final expRows = await _queryMaps(pool, '''
          SELECT COALESCE(SUM(e.tutar), 0) AS gider
          FROM expenses e
          $expWhereSql
          ''', params);
        final gider = expRows.isEmpty ? 0.0 : _toDouble(expRows.first['gider']);
        final netKar = brutKar - gider;

        final headerInfo = <String, dynamic>{
          'profit_loss_totals': <Map<String, String>>[
            {
              'label': 'Devreden',
              'value': _formatQuantity(devreden),
              'unit': birim,
            },
            {
              'label': 'Eklenen',
              'value': _formatQuantity(eklenen),
              'unit': birim,
            },
            {
              'label': 'Devreden + Eklenen',
              'value': _formatQuantity(devredenEklenen),
              'unit': birim,
            },
            {
              'label': 'Satılan',
              'value': _formatQuantity(satilan),
              'unit': birim,
            },
            {'label': 'Kalan', 'value': _formatQuantity(kalan), 'unit': birim},
            {
              'label': 'Dev. + Ekl. Stok Değeri',
              'value': _formatMoney(devEklStokDegeri),
              'unit': '',
            },
            {
              'label': 'Sat. Mal. Top. Alış Değeri',
              'value': _formatMoney(satMalTopAlisDegeri),
              'unit': '',
            },
            {
              'label': 'Toplam Satış Değeri',
              'value': _formatMoney(toplamSatisDegeri),
              'unit': '',
            },
            {
              'label': 'Kalan Stok Değeri',
              'value': _formatMoney(kalanStokDegeri),
              'unit': '',
            },
            {'label': 'Brüt Kar', 'value': _formatMoney(brutKar), 'unit': ''},
          ],
        };

        return (
          cards: <RaporOzetKarti>[
            RaporOzetKarti(
              labelKey: 'reports.summary.net_profit',
              value: _formatMoney(netKar),
              icon: Icons.analytics_outlined,
              accentColor: AppPalette.slate,
            ),
          ],
          headerInfo: headerInfo,
        );
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('kod', 'Kod no', 110),
        _column('ad', 'Adı', 220),
        _column('grup', 'Grubu', 120),
        _column('ozellik', 'Özellik', 140, allowSorting: false),
        _column('devreden', 'Devreden', 145, alignment: Alignment.centerRight),
        _column('eklenen', 'Eklenen', 110, alignment: Alignment.centerRight),
        _column(
          'devreden_eklenen',
          'Devreden + eklenen',
          140,
          alignment: Alignment.centerRight,
        ),
        _column('satilan', 'Satılan', 110, alignment: Alignment.centerRight),
        _column('kalan', 'Kalan', 110, alignment: Alignment.centerRight),
        _column('birim', 'Ölçü', 90),
        _column(
          'dev_ekl_stok_degeri',
          'Dev. + ekl. stok değeri',
          170,
          alignment: Alignment.centerRight,
        ),
        _column(
          'sat_mal_top_alis_degeri',
          'Sat. mal. top. alış değeri',
          190,
          alignment: Alignment.centerRight,
        ),
        _column(
          'toplam_satis_degeri',
          'Toplam satış değeri',
          170,
          alignment: Alignment.centerRight,
        ),
        _column(
          'kalan_stok_degeri',
          'Kalan stok değeri',
          170,
          alignment: Alignment.centerRight,
        ),
        _column('brut_kar', 'Brüt kar', 140, alignment: Alignment.centerRight),
      ],
      rows: mappedRows,
      summaryCards: topSummary.cards,
      headerInfo: topSummary.headerInfo,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  List<({String name, int? color})> _parseFirstThreeFeatureBadges(dynamic raw) {
    final String text = (raw?.toString() ?? '').trim();
    if (text.isEmpty) return const <({String name, int? color})>[];
    if (text == '[]') return const <({String name, int? color})>[];

    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        if (decoded.isEmpty) return const <({String name, int? color})>[];

        final result = <({String name, int? color})>[];
        for (final item in decoded) {
          if (item is! Map) continue;
          final name = item['name']?.toString().trim() ?? '';
          if (name.isEmpty) continue;

          final dynamic rawColor = item['color'];
          int? color;
          if (rawColor is int) {
            color = rawColor;
          } else if (rawColor is num) {
            color = rawColor.toInt();
          } else if (rawColor is String) {
            color = int.tryParse(rawColor);
          }

          result.add((name: name, color: color));
          if (result.length >= 3) break;
        }
        return result;
      }
    } catch (_) {
      // ignore
    }

    // JSON benzeri bir format varsa parçalamayalım (UI'de ham JSON görünmesin).
    if (text.startsWith('[') || text.startsWith('{')) {
      return const <({String name, int? color})>[];
    }

    final String normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    List<String> parts;
    if (normalized.contains('|')) {
      parts = normalized.split('|');
    } else if (normalized.contains('\n')) {
      parts = normalized.split('\n');
    } else if (normalized.contains(';')) {
      parts = normalized.split(';');
    } else if (normalized.contains(',')) {
      parts = normalized.split(',');
    } else {
      parts = <String>[normalized];
    }

    final cleaned = parts
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    return cleaned
        .take(3)
        .map((name) => (name: name, color: null))
        .toList(growable: false);
  }

  (String, String, String) _splitFirstThreeFeatures(dynamic raw) {
    final String text = (raw?.toString() ?? '').trim();
    if (text.isEmpty) return ('-', '-', '-');

    final String normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    List<String> parts;
    if (normalized.contains('|')) {
      parts = normalized.split('|');
    } else if (normalized.contains('\n')) {
      parts = normalized.split('\n');
    } else if (normalized.contains(',')) {
      parts = normalized.split(',');
    } else if (normalized.contains(';')) {
      parts = normalized.split(';');
    } else {
      parts = <String>[normalized];
    }

    final cleaned = parts
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    final String a = cleaned.isNotEmpty ? cleaned[0] : '-';
    final String b = cleaned.length > 1 ? cleaned[1] : '-';
    final String c = cleaned.length > 2 ? cleaned[2] : '-';
    return (a, b, c);
  }

  Future<RaporSonucu> _buildOptimizedKullaniciIslemRaporu(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();

    final where = <String>[
      "COALESCE(ut.company_id, '$_defaultCompanyId') = @companyId",
    ];
    final params = <String, dynamic>{'companyId': _companyId};

    if (filtreler.baslangicTarihi != null) {
      params['baslangic'] = DateTime(
        filtreler.baslangicTarihi!.year,
        filtreler.baslangicTarihi!.month,
        filtreler.baslangicTarihi!.day,
      ).toIso8601String();
      where.add('ut.date >= @baslangic');
    }
    if (filtreler.bitisTarihi != null) {
      params['bitis'] = DateTime(
        filtreler.bitisTarihi!.year,
        filtreler.bitisTarihi!.month,
        filtreler.bitisTarihi!.day,
      ).add(const Duration(days: 1)).toIso8601String();
      where.add('ut.date < @bitis');
    }

    if (_emptyToNull(filtreler.kullaniciId) != null) {
      params['userId'] = filtreler.kullaniciId;
      where.add('ut.user_id = @userId');
    }

    final String typeSelection = _normalizedSelection(filtreler.islemTuru);
    if (typeSelection.isNotEmpty) {
      params['type'] = typeSelection;
      where.add("LOWER(COALESCE(ut.type, '')) = LOWER(@type)");
    }

    final normalizedSearch = _normalizeArama(arama);
    if (normalizedSearch.isNotEmpty) {
      params['search'] = '%$normalizedSearch%';
      where.add('''
        (
          normalize_text(COALESCE(ut.description, '')) LIKE @search
          OR normalize_text(COALESCE(ut.type, '')) LIKE @search
          OR normalize_text(COALESCE(ut.id, '')) LIKE @search
          OR normalize_text(COALESCE(u.username, '')) LIKE @search
          OR normalize_text(COALESCE(u.role, '')) LIKE @search
        )
      ''');
    }

    final whereBase = <String>[...where];
    final paramsBase = <String, dynamic>{...params};
    final wherePaging = <String>[...whereBase];
    final paramsPaging = <String, dynamic>{...paramsBase};

    // Cursor (date + id) for deep history without OFFSET.
    final payload = _decodeCursorPayload(cursor);
    final DateTime? lastDate = payload == null
        ? null
        : DateTime.tryParse(payload['d']?.toString() ?? '');
    final String? lastId = payload?['id']?.toString();
    if (lastDate != null && lastId != null && lastId.trim().isNotEmpty) {
      final String op = sortAscending ? '>' : '<';
      wherePaging.add('''
        (
          ut.date $op @lastDate
          OR (ut.date = @lastDate AND ut.id $op @lastId)
        )
      ''');
      paramsPaging['lastDate'] = lastDate.toIso8601String();
      paramsPaging['lastId'] = lastId;
    }

    final String whereSqlBase = whereBase.isEmpty
        ? ''
        : 'WHERE ${whereBase.join(' AND ')}';
    final String whereSqlPaging = wherePaging.isEmpty
        ? ''
        : 'WHERE ${wherePaging.join(' AND ')}';
    final String direction = sortAscending ? 'ASC' : 'DESC';

    final int limit = pageSize.clamp(1, 5000) + 1;
    paramsPaging['limit'] = limit;

    final rows = await _queryMaps(pool, '''
      SELECT
        ut.id AS tx_id,
        ut.date AS tarih,
        ut.description AS aciklama,
        ut.debt AS borc,
        ut.credit AS alacak,
        ut.type AS islem_turu,
        u.username AS kullanici_adi,
        u.role AS rol,
        u.name AS ad,
        u.surname AS soyad
      FROM user_transactions ut
      LEFT JOIN users u ON u.id = ut.user_id
      $whereSqlPaging
      ORDER BY ut.date $direction, ut.id $direction
      LIMIT @limit
      ''', paramsPaging);

    final bool hasNext = rows.length > pageSize;
    final pageRows = hasNext ? rows.take(pageSize).toList() : rows;
    final String? nextCursor = hasNext && pageRows.isNotEmpty
        ? _encodeCursorPayload({
            'd': (_toDateTime(pageRows.last['tarih']) ?? DateTime.now())
                .toIso8601String(),
            'id': pageRows.last['tx_id']?.toString() ?? '',
          })
        : null;

    final mappedRows = pageRows
        .map((row) {
          final DateTime? tarih = _toDateTime(row['tarih']);
          final double borc = _toDouble(row['borc']);
          final double alacak = _toDouble(row['alacak']);
          final double tutarEtkisi = alacak - borc;
          final String kullaniciAdi = row['kullanici_adi']?.toString() ?? '-';
          final String rol = row['rol']?.toString() ?? '-';
          final String islem = row['islem_turu']?.toString() ?? '-';
          final String belgeRef = row['tx_id']?.toString() ?? '-';
          final String aciklama = row['aciklama']?.toString() ?? '';
          final String tamAd = [
            row['ad']?.toString(),
            row['soyad']?.toString(),
          ].where((e) => e != null && e.trim().isNotEmpty).join(' ');

          return RaporSatiri(
            id: 'kullanici_tx_$belgeRef',
            cells: {
              'kullanici': kullaniciAdi,
              'modul': rol,
              'islem': islem,
              'tarih': _formatDate(tarih, includeTime: true),
              'belge_ref': belgeRef,
              'tutar_etkisi': _formatMoney(tutarEtkisi),
              'kayit_sayisi': '1',
            },
            details: {
              tr('common.description'): aciklama.trim().isNotEmpty
                  ? aciklama
                  : '-',
              tr('reports.columns.user_full_name'): tamAd.trim().isEmpty
                  ? '-'
                  : tamAd,
            },
            sourceMenuIndex: 1,
            sourceSearchQuery: kullaniciAdi,
            amountValue: tutarEtkisi,
            sortValues: {
              'kullanici': kullaniciAdi,
              'modul': rol,
              'islem': islem,
              'tarih': tarih,
              'tutar_etkisi': tutarEtkisi,
              'kayit_sayisi': 1,
            },
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summary = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final countRows = await _queryMaps(pool, '''
          SELECT COUNT(*) AS kayit
          FROM user_transactions ut
          LEFT JOIN users u ON u.id = ut.user_id
          $whereSqlBase
          ''', paramsBase);
        final int kayit = countRows.isEmpty
            ? 0
            : (countRows.first['kayit'] as num?)?.toInt() ?? 0;
        return [
          RaporOzetKarti(
            labelKey: 'reports.summary.record',
            value: kayit.toString(),
            icon: Icons.groups_rounded,
            accentColor: AppPalette.slate,
          ),
        ];
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('kullanici', 'common.user', 160),
        _column('modul', 'reports.columns.module', 140),
        _column('islem', 'common.transaction_type', 150),
        _column('tarih', 'common.date', 150),
        _column('belge_ref', 'reports.columns.document_ref', 140),
        _column(
          'tutar_etkisi',
          'reports.columns.amount_effect',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'kayit_sayisi',
          'reports.columns.record_count',
          100,
          alignment: Alignment.centerRight,
        ),
      ],
      rows: mappedRows,
      summaryCards: summary,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: hasNext,
      cursorPagination: true,
      nextCursor: nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  String _cariSortColumn(String? key, _CariRaporModu mod) {
    switch (key) {
      case 'tarih':
        return 'cat.date';
      case 'belge_no':
        return 'belge_no';
      case 'cari':
        return 'ca.adi';
      case 'kalem_sayisi':
        return 'kalem_sayisi';
      case 'ara_toplam':
      case 'genel_toplam':
      case 'tutar':
        return 'cat.amount';
      case 'bakiye_borc':
        return 'cat.bakiye_borc';
      case 'bakiye_alacak':
        return 'cat.bakiye_alacak';
      case 'ilgili_hesap':
        return 'ilgili_hesap';
      case 'aciklama':
        return 'cat.description';
      case 'vade':
        return 'cat.vade_tarihi';
      case 'kullanici':
        return 'cat.user_name';
      default:
        return mod == _CariRaporModu.ekstre ? 'cat.date' : 'cat.amount';
    }
  }

  String _finansSortColumn(String? key) {
    switch (key) {
      case 'tarih':
        return 't.date';
      case 'hesap':
        return 'hesap';
      case 'islem':
        return 't.type';
      case 'ilgili_hesap':
        return 'ilgili_hesap';
      case 'giris':
      case 'cikis':
      case 'tutar':
        return 't.amount';
      case 'aciklama':
        return 't.description';
      case 'kullanici':
        return 't.user_name';
      default:
        return 't.date';
    }
  }

  String _hareketSortColumn(String? key) {
    switch (key) {
      case 'tarih':
        return 'tarih';
      case 'modul':
        return 'modul';
      case 'islem':
        return 'islem';
      case 'belge_no':
        return 'belge_no';
      case 'hesap':
        return 'hesap';
      case 'aciklama':
        return 'aciklama';
      case 'borc':
      case 'alacak':
      case 'tutar':
        return 'tutar_num';
      case 'kullanici':
        return 'kullanici';
      default:
        return 'tarih';
    }
  }

  String _urunHareketSortColumn(String? key) {
    switch (key) {
      case 'tarih':
        return 'sm.movement_date';
      case 'urun_kodu':
        return 'p.kod';
      case 'urun_adi':
        return 'p.ad';
      case 'islem':
        return 'sm.movement_type';
      case 'depo':
        return 'depo_adi';
      case 'giris':
      case 'cikis':
        return 'sm.quantity';
      case 'maliyet':
        return 'sm.unit_price';
      case 'kullanici':
        return 'sm.created_by';
      default:
        return 'sm.movement_date';
    }
  }

  Future<RaporSonucu> _buildOptimizedCariRapor(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required _CariRaporModu mod,
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final kullaniciAdi = await _resolveKullaniciAdi(filtreler.kullaniciId);
    final params = <String, dynamic>{};
    final where = <String>[];

    if (filtreler.baslangicTarihi != null) {
      params['baslangic'] = DateTime(
        filtreler.baslangicTarihi!.year,
        filtreler.baslangicTarihi!.month,
        filtreler.baslangicTarihi!.day,
      ).toIso8601String();
      where.add('cat.date >= @baslangic');
    }
    if (filtreler.bitisTarihi != null) {
      params['bitis'] = DateTime(
        filtreler.bitisTarihi!.year,
        filtreler.bitisTarihi!.month,
        filtreler.bitisTarihi!.day,
      ).add(const Duration(days: 1)).toIso8601String();
      where.add('cat.date < @bitis');
    }
    if (filtreler.cariId != null) {
      params['cariId'] = filtreler.cariId;
      where.add('cat.current_account_id = @cariId');
    }
    if (_emptyToNull(kullaniciAdi) != null) {
      params['kullanici'] = _emptyToNull(kullaniciAdi);
      where.add("COALESCE(cat.user_name, '') = @kullanici");
    }
    if (_emptyToNull(filtreler.belgeNo) != null) {
      params['belgeNo'] = '%${_normalizeArama(filtreler.belgeNo!)}%';
      where.add(
        "LOWER(COALESCE(cat.fatura_no, COALESCE(cat.irsaliye_no, COALESCE(cat.belge, COALESCE(cat.integration_ref, ''))))) LIKE @belgeNo",
      );
    }
    if (filtreler.minTutar != null) {
      params['minTutar'] = filtreler.minTutar;
      where.add('cat.amount >= @minTutar');
    }
    if (filtreler.maxTutar != null) {
      params['maxTutar'] = filtreler.maxTutar;
      where.add('cat.amount <= @maxTutar');
    }
    if (_normalizedSelection(filtreler.islemTuru).isNotEmpty) {
      params['islemTuru'] = _normalizedSelection(filtreler.islemTuru);
      where.add("LOWER(COALESCE(cat.source_type, '')) = LOWER(@islemTuru)");
    }
    switch (mod) {
      case _CariRaporModu.satis:
        where.add(
          "(LOWER(COALESCE(cat.source_type, '')) LIKE '%satis%' OR LOWER(COALESCE(cat.source_type, '')) LIKE '%satış%')",
        );
        break;
      case _CariRaporModu.alis:
        where.add(
          "(LOWER(COALESCE(cat.source_type, '')) LIKE '%alis%' OR LOWER(COALESCE(cat.source_type, '')) LIKE '%alış%')",
        );
        break;
      case _CariRaporModu.karma:
        where.add(
          "((LOWER(COALESCE(cat.source_type, '')) LIKE '%alis%' OR LOWER(COALESCE(cat.source_type, '')) LIKE '%alış%') OR (LOWER(COALESCE(cat.source_type, '')) LIKE '%satis%' OR LOWER(COALESCE(cat.source_type, '')) LIKE '%satış%'))",
        );
        break;
      case _CariRaporModu.ekstre:
        break;
    }
    _addSearchCondition(where, params, 'cat.search_tags', arama);

    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    String sortExpr(String? key) {
      switch (key) {
        case 'tarih':
          return 'base.tarih';
        case 'belge_no':
          return "COALESCE(base.belge_no, '')";
        case 'cari':
          return "COALESCE(base.cari_adi, '')";
        case 'kalem_sayisi':
          return 'base.kalem_sayisi';
        case 'ara_toplam':
        case 'genel_toplam':
        case 'tutar':
          return 'base.tutar';
        case 'bakiye_borc':
          return 'base.bakiye_borc';
        case 'bakiye_alacak':
          return 'base.bakiye_alacak';
        case 'ilgili_hesap':
          return "COALESCE(base.ilgili_hesap, '')";
        case 'aciklama':
          return "COALESCE(base.aciklama, '')";
        case 'vade':
          return 'base.vade_tarihi';
        case 'kullanici':
          return "COALESCE(base.kullanici, '')";
        default:
          return mod == _CariRaporModu.ekstre ? 'base.tarih' : 'base.tutar';
      }
    }

    final baseSelect =
        '''
      SELECT
        cat.id,
        cat.date AS tarih,
        cat.amount AS tutar,
        cat.type AS yon,
        cat.source_type AS islem_turu,
        cat.source_name AS kaynak_adi,
        cat.source_code AS kaynak_kodu,
        cat.user_name AS kullanici,
        cat.integration_ref,
        cat.fatura_no,
        cat.irsaliye_no,
        cat.belge,
        cat.vade_tarihi,
        cat.description AS aciklama,
        cat.aciklama2,
        CASE
          WHEN cat.source_type ILIKE '%Çek%' THEN (
            SELECT collection_status
            FROM cheques
            WHERE id = cat.source_id
            LIMIT 1
          )
          WHEN cat.source_type ILIKE '%Senet%' THEN (
            SELECT collection_status
            FROM promissory_notes
            WHERE id = cat.source_id
            LIMIT 1
          )
          ELSE NULL
        END AS guncel_durum,
        cat.bakiye_borc,
        cat.bakiye_alacak,
        ca.id AS cari_id,
        ca.kod_no AS cari_kod,
        ca.adi AS cari_adi,
        ca.para_birimi AS para_birimi,
        0::bigint AS kalem_sayisi,
        COALESCE(cat.source_name, COALESCE(cat.source_code, '-')) AS ilgili_hesap,
        COALESCE(cat.fatura_no, COALESCE(cat.irsaliye_no, COALESCE(cat.belge, COALESCE(cat.integration_ref, '-')))) AS belge_no
      FROM current_account_transactions cat
      INNER JOIN current_accounts ca ON ca.id = cat.current_account_id
      $whereSql
    ''';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'id',
    );

    final rows = pageResult.rows;

    final List<RaporSatiri> mappedRows = rows
        .map((tx) {
          final double tutar = _toDouble(tx['tutar']);
          final bool isBorc = _isDebit(tx['yon']?.toString());
          final double bakiyeBorc = _toDouble(tx['bakiye_borc']);
          final double bakiyeAlacak = _toDouble(tx['bakiye_alacak']);
          final String paraBirimi = tx['para_birimi']?.toString() ?? 'TRY';
          final DateTime? tarih = _toDateTime(tx['tarih']);
          final DateTime? vade = _toDateTime(tx['vade_tarihi']);
          final sunum = _cariIslemSunumunuHazirla(tx);

          if (mod == _CariRaporModu.ekstre) {
            return RaporSatiri(
              id: 'cari_tx_${tx['id']}',
              cells: {
                'islem': IslemCeviriYardimcisi.cevir(sunum.islem),
                'tarih': _formatDate(tarih, includeTime: true),
                'tutar': _formatMoney(tutar, currency: paraBirimi),
                'bakiye_borc': bakiyeBorc > 0
                    ? _formatMoney(bakiyeBorc, currency: paraBirimi)
                    : '-',
                'bakiye_alacak': bakiyeAlacak > 0
                    ? _formatMoney(bakiyeAlacak, currency: paraBirimi)
                    : '-',
                'ilgili_hesap': tx['ilgili_hesap']?.toString() ?? '-',
                'aciklama': sunum.aciklama,
                'vade': _formatDate(vade),
                'kullanici': tx['kullanici']?.toString() ?? '-',
              },
              sourceMenuIndex: TabAciciScope.cariKartiIndex,
              sourceSearchQuery: tx['cari_adi']?.toString(),
              amountValue: tutar,
              sortValues: {
                'tarih': tarih,
                'tutar': tutar,
                'bakiye_borc': bakiyeBorc,
                'bakiye_alacak': bakiyeAlacak,
                'islem': sunum.islem,
                'aciklama': sunum.aciklama,
                'kullanici': tx['kullanici'],
              },
            );
          }

          return RaporSatiri(
            id: 'cari_tx_${tx['id']}',
            cells: {
              'tarih': _formatDate(tarih, includeTime: true),
              'belge_no': tx['belge_no']?.toString() ?? '-',
              'cari': '${tx['cari_kod'] ?? '-'} - ${tx['cari_adi'] ?? '-'}',
              'kalem_sayisi': (tx['kalem_sayisi'] ?? 0).toString(),
              'ara_toplam': _formatMoney(tutar, currency: paraBirimi),
              'kdv': '-',
              'genel_toplam': _formatMoney(tutar, currency: paraBirimi),
              'odeme_turu': _detectPaymentType(tx),
              'durum': isBorc
                  ? tr('reports.badges.debit')
                  : tr('reports.badges.credit'),
              'kullanici': tx['kullanici']?.toString() ?? '-',
            },
            sourceMenuIndex: 9,
            sourceSearchQuery: tx['cari_adi']?.toString(),
            amountValue: tutar,
            sortValues: {
              'tarih': tarih,
              'belge_no': tx['belge_no'],
              'cari': tx['cari_adi'],
              'genel_toplam': tutar,
              'tutar': tutar,
              'kullanici': tx['kullanici'],
            },
          );
        })
        .toList(growable: false);

    final columns = switch (mod) {
      _CariRaporModu.satis ||
      _CariRaporModu.alis ||
      _CariRaporModu.karma => <RaporKolonTanimi>[
        _column('tarih', 'common.date', 150),
        _column('belge_no', 'reports.columns.document_no', 130),
        _column('cari', 'reports.columns.current_account', 220),
        _column(
          'kalem_sayisi',
          'reports.columns.item_count',
          90,
          alignment: Alignment.centerRight,
        ),
        _column(
          'ara_toplam',
          'common.subtotal',
          140,
          alignment: Alignment.centerRight,
        ),
        _column(
          'kdv',
          'common.vat_amount',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'genel_toplam',
          'reports.columns.grand_total',
          140,
          alignment: Alignment.centerRight,
        ),
        _column('odeme_turu', 'reports.columns.payment_type', 120),
        _column('durum', 'common.status', 110),
        _column('kullanici', 'common.user', 110),
      ],
      _CariRaporModu.ekstre => <RaporKolonTanimi>[
        _column('islem', 'common.operation', 180),
        _column('tarih', 'common.date', 150),
        _column(
          'tutar',
          'common.amount',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'bakiye_borc',
          'accounts.balance.debit_label',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'bakiye_alacak',
          'accounts.balance.credit_label',
          130,
          alignment: Alignment.centerRight,
        ),
        _column('ilgili_hesap', 'common.related_account', 180),
        _column('aciklama', 'common.description', 220),
        _column('vade', 'common.due_date_short', 110),
        _column('kullanici', 'common.user', 100),
      ],
    };

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summary = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        String paraBirimi = 'TRY';
        if (filtreler.cariId != null) {
          final currencyRows = await _queryMaps(
            pool,
            'SELECT para_birimi FROM current_accounts WHERE id = @cariId LIMIT 1',
            <String, dynamic>{'cariId': filtreler.cariId},
          );
          if (currencyRows.isNotEmpty) {
            final raw = currencyRows.first['para_birimi']?.toString() ?? '';
            paraBirimi = raw.trim().isEmpty ? 'TRY' : raw;
          }
        }

        final summaryRows = await _queryMaps(pool, '''
          SELECT
            COUNT(*) AS kayit,
            COALESCE(SUM(cat.amount), 0) AS toplam,
            COALESCE(AVG(cat.amount), 0) AS ortalama,
            COALESCE(SUM(cat.bakiye_borc - cat.bakiye_alacak), 0) AS net_bakiye
          FROM current_account_transactions cat
          INNER JOIN current_accounts ca ON ca.id = cat.current_account_id
          $whereSql
        ''', params);
        final summaryData = summaryRows.isEmpty
            ? const <String, dynamic>{}
            : summaryRows.first;

        final int kayit = (summaryData['kayit'] as num?)?.toInt() ?? 0;
        final toplam = _toDouble(summaryData['toplam']);
        final ortalama = _toDouble(summaryData['ortalama']);
        final netBakiye = _toDouble(summaryData['net_bakiye']);

        return <RaporOzetKarti>[
          RaporOzetKarti(
            labelKey: mod == _CariRaporModu.satis
                ? 'reports.summary.total_sales'
                : mod == _CariRaporModu.alis
                ? 'reports.summary.total_purchases'
                : mod == _CariRaporModu.karma
                ? 'reports.summary.total_movements'
                : 'reports.summary.total_movements',
            value: _formatMoney(toplam, currency: paraBirimi),
            icon: mod == _CariRaporModu.alis
                ? Icons.shopping_cart_checkout_rounded
                : Icons.point_of_sale_rounded,
            accentColor: mod == _CariRaporModu.alis
                ? AppPalette.amber
                : AppPalette.red,
            subtitle: '$kayit ${tr('reports.summary.record')}',
          ),
          if (mod == _CariRaporModu.ekstre)
            RaporOzetKarti(
              labelKey: 'reports.summary.net_balance',
              value: _formatMoney(netBakiye, currency: paraBirimi),
              icon: Icons.account_balance_wallet_outlined,
              accentColor: AppPalette.slate,
            )
          else
            RaporOzetKarti(
              labelKey: 'reports.summary.average_receipt',
              value: _formatMoney(ortalama, currency: paraBirimi),
              icon: Icons.receipt_long_outlined,
              accentColor: AppPalette.slate,
            ),
        ];
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: columns,
      rows: mappedRows,
      summaryCards: summary,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
      detailTableLabel: tr('common.products'),
    );
  }

  Future<RaporSonucu> _buildOptimizedFinansRaporu(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required _FinansRaporModu mod,
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final kullaniciAdi = await _resolveKullaniciAdi(filtreler.kullaniciId);
    final params = <String, dynamic>{};
    final where = <String>[];
    late final String txTable;
    late final String accountJoin;
    late final String hesapExpr;
    late final int menuIndex;
    late final String modulLabel;
    switch (mod) {
      case _FinansRaporModu.kasa:
        txTable = 'cash_register_transactions';
        accountJoin = 'LEFT JOIN cash_registers a ON a.id = t.cash_register_id';
        hesapExpr = "COALESCE(a.code || ' - ' || a.name, a.name, '-')";
        menuIndex = 13;
        modulLabel = tr('transactions.source.cash');
        if (filtreler.kasaId != null) {
          params['hesapId'] = filtreler.kasaId;
          where.add('t.cash_register_id = @hesapId');
        }
        break;
      case _FinansRaporModu.banka:
        txTable = 'bank_transactions';
        accountJoin = 'LEFT JOIN banks a ON a.id = t.bank_id';
        hesapExpr = "COALESCE(a.code || ' - ' || a.name, a.name, '-')";
        menuIndex = 15;
        modulLabel = tr('transactions.source.bank');
        if (filtreler.bankaId != null) {
          params['hesapId'] = filtreler.bankaId;
          where.add('t.bank_id = @hesapId');
        }
        break;
      case _FinansRaporModu.krediKarti:
        txTable = 'credit_card_transactions';
        accountJoin = 'LEFT JOIN credit_cards a ON a.id = t.credit_card_id';
        hesapExpr = "COALESCE(a.code || ' - ' || a.name, a.name, '-')";
        menuIndex = 16;
        modulLabel = tr('transactions.source.credit_card');
        if (filtreler.krediKartiId != null) {
          params['hesapId'] = filtreler.krediKartiId;
          where.add('t.credit_card_id = @hesapId');
        }
        break;
    }

    if (filtreler.baslangicTarihi != null) {
      params['baslangic'] = DateTime(
        filtreler.baslangicTarihi!.year,
        filtreler.baslangicTarihi!.month,
        filtreler.baslangicTarihi!.day,
      ).toIso8601String();
      where.add('t.date >= @baslangic');
    }
    if (filtreler.bitisTarihi != null) {
      params['bitis'] = DateTime(
        filtreler.bitisTarihi!.year,
        filtreler.bitisTarihi!.month,
        filtreler.bitisTarihi!.day,
      ).add(const Duration(days: 1)).toIso8601String();
      where.add('t.date < @bitis');
    }
    if (_emptyToNull(kullaniciAdi) != null) {
      params['kullanici'] = _emptyToNull(kullaniciAdi);
      where.add("COALESCE(t.user_name, '') = @kullanici");
    }
    if (_normalizedSelection(filtreler.islemTuru).isNotEmpty) {
      params['islemTuru'] = _normalizedSelection(filtreler.islemTuru);
      where.add("LOWER(COALESCE(t.type, '')) = LOWER(@islemTuru)");
    }
    if (filtreler.minTutar != null) {
      params['minTutar'] = filtreler.minTutar;
      where.add('t.amount >= @minTutar');
    }
    if (filtreler.maxTutar != null) {
      params['maxTutar'] = filtreler.maxTutar;
      where.add('t.amount <= @maxTutar');
    }
    _addSearchCondition(where, params, 't.search_tags', arama);
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    const incomingCase =
        "(LOWER(COALESCE(t.type, '')) LIKE '%tahsil%' OR LOWER(COALESCE(t.type, '')) LIKE '%giris%' OR LOWER(COALESCE(t.type, '')) LIKE '%giriş%')";

    String sortExpr(String? key) {
      switch (key) {
        case 'tarih':
          return 'base.tarih';
        case 'hesap':
          return "COALESCE(base.hesap, '')";
        case 'islem':
          return "COALESCE(base.islem_turu, '')";
        case 'ilgili_hesap':
          return "COALESCE(base.ilgili_hesap, '')";
        case 'giris':
        case 'cikis':
        case 'tutar':
          return 'base.tutar';
        case 'aciklama':
          return "COALESCE(base.aciklama, '')";
        case 'kullanici':
          return "COALESCE(base.kullanici, '')";
        default:
          return 'base.tarih';
      }
    }

    final baseSelect =
        '''
      SELECT
        t.id,
        t.date AS tarih,
        t.amount AS tutar,
        t.type AS islem_turu,
        t.description AS aciklama,
        t.user_name AS kullanici,
        t.integration_ref,
        $hesapExpr AS hesap,
        COALESCE(
          t.location_name,
          COALESCE(t.location_code, COALESCE(t.location, '-'))
        ) AS ilgili_hesap,
        CASE WHEN $incomingCase THEN t.amount ELSE 0 END AS giris_num,
        CASE WHEN $incomingCase THEN 0 ELSE t.amount END AS cikis_num
      FROM $txTable t
      $accountJoin
      $whereSql
    ''';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
    ''';

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'id',
    );
    final rows = pageResult.rows;

    final mappedRows = rows
        .map((tx) {
          final tarih = _toDateTime(tx['tarih']);
          final tutar = _toDouble(tx['tutar']);
          final giris = _toDouble(tx['giris_num']);
          final cikis = _toDouble(tx['cikis_num']);
          final sunum = _finansIslemSunumunuHazirla(tx, mod: mod);
          return RaporSatiri(
            id: '${mod.name}_${tx['id']}',
            cells: {
              'tarih': _formatDate(tarih, includeTime: true),
              'hesap': tx['hesap']?.toString() ?? '-',
              'islem': IslemCeviriYardimcisi.cevir(sunum.islem),
              'ilgili_hesap': tx['ilgili_hesap']?.toString() ?? '-',
              'giris': giris > 0 ? _formatMoney(giris) : '-',
              'cikis': cikis > 0 ? _formatMoney(cikis) : '-',
              'aciklama': sunum.aciklama,
              'kullanici': tx['kullanici']?.toString() ?? '-',
            },
            sourceMenuIndex: menuIndex,
            sourceSearchQuery: tx['hesap']?.toString(),
            amountValue: tutar,
            sortValues: {
              'tarih': tarih,
              'hesap': tx['hesap'],
              'islem': sunum.islem,
              'giris': giris,
              'cikis': cikis,
              'aciklama': sunum.aciklama,
              'kullanici': tx['kullanici'],
            },
            extra: {'modul': modulLabel},
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summaryCards = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final summaryRows = await _queryMaps(pool, '''
          SELECT
            COUNT(*) AS kayit,
            COALESCE(SUM(CASE WHEN $incomingCase THEN t.amount ELSE 0 END), 0) AS toplam_giris,
            COALESCE(SUM(CASE WHEN $incomingCase THEN 0 ELSE t.amount END), 0) AS toplam_cikis
          FROM $txTable t
          $accountJoin
          $whereSql
        ''', params);
        final summaryData = summaryRows.isEmpty
            ? const <String, dynamic>{}
            : summaryRows.first;

        return <RaporOzetKarti>[
          RaporOzetKarti(
            labelKey: 'reports.summary.total_incoming',
            value: _formatMoney(summaryData['toplam_giris']),
            icon: Icons.arrow_downward_rounded,
            accentColor: const Color(0xFF27AE60),
          ),
          RaporOzetKarti(
            labelKey: 'reports.summary.total_outgoing',
            value: _formatMoney(summaryData['toplam_cikis']),
            icon: Icons.arrow_upward_rounded,
            accentColor: AppPalette.red,
          ),
        ];
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tarih', 'common.date', 150),
        _column('hesap', 'reports.columns.account', 180),
        _column('islem', 'common.transaction_type', 160),
        _column('ilgili_hesap', 'common.related_account', 170),
        _column(
          'giris',
          'common.incoming',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'cikis',
          'common.outgoing',
          130,
          alignment: Alignment.centerRight,
        ),
        _column('aciklama', 'common.description', 220),
        _column('kullanici', 'common.user', 110),
      ],
      rows: mappedRows,
      summaryCards: summaryCards,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildOptimizedUrunHareketleri(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final effectiveArama = _normalizeNumericSearchForReports(arama);

    String sortExpr(String? key) {
      switch (key) {
        case 'islem':
          return "COALESCE(base.islem, '')";
        case 'tarih':
          return 'base.tarih';
        case 'tur':
          return "COALESCE(base.tur, '')";
        case 'kod':
          return "COALESCE(base.kod, '')";
        case 'ad':
          return "COALESCE(base.ad, '')";
        case 'grubu':
          return "COALESCE(base.grubu, '')";
        case 'ozellik':
        case 'ozellik1':
        case 'ozellik2':
        case 'ozellik3':
          return "COALESCE(base.ozellikler, '')";
        case 'depo':
          return "COALESCE(base.depo, '')";
        case 'miktar':
          return 'base.miktar';
        case 'olcu':
          return "COALESCE(base.olcu, '')";
        case 'birim_fiyat':
          return 'base.birim_fiyat';
        case 'birim_fiyat_vd':
          return 'base.birim_fiyat_vd';
        case 'yer_kodu':
          return "COALESCE(base.yer_kodu, '')";
        case 'yer_adi':
          return "COALESCE(base.yer_adi, '')";
        case 'aciklama':
          return "COALESCE(base.aciklama, '')";
        default:
          return 'base.tarih';
      }
    }

    String formatQuantityTotalsByUnit(Map<String, double> totalsByUnit) {
      if (totalsByUnit.isEmpty) return '-';
      final entries = totalsByUnit.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return entries
          .map((e) => '${_formatNumber(e.value)} ${e.key}'.trim())
          .join(', ');
    }

    final String vatMultiplier =
        '(1 + COALESCE(p.kdv_orani, 0) / 100.0)::numeric';

    final String netUnitPriceExpr =
        '''
      CASE
        WHEN COALESCE(sm.vat_status, 'excluded') ILIKE 'included' THEN
          CASE
            WHEN COALESCE(p.kdv_orani, 0) = 0 THEN COALESCE(sm.unit_price, 0)
            ELSE COALESCE(sm.unit_price, 0) / $vatMultiplier
          END
        ELSE COALESCE(sm.unit_price, 0)
      END
    ''';

    final String grossUnitPriceExpr =
        '''
      CASE
        WHEN COALESCE(sm.vat_status, 'excluded') ILIKE 'included'
        THEN COALESCE(sm.unit_price, 0)
        ELSE COALESCE(sm.unit_price, 0) * $vatMultiplier
      END
    ''';

    final String islemExpr = '''
      CASE
        WHEN COALESCE(sm.integration_ref, '') = 'opening_stock'
          OR COALESCE(sm.description, '') ILIKE '%Açılış%'
          OR COALESCE(sm.description, '') ILIKE '%Acilis%'
        THEN 'Açılış Stoğu'
        WHEN COALESCE(sm.integration_ref, '') ILIKE 'PURCHASE-%'
        THEN 'Alış Yapıldı'
        WHEN COALESCE(sm.integration_ref, '') ILIKE 'SALE-%'
          OR COALESCE(sm.integration_ref, '') ILIKE 'RETAIL-%'
        THEN 'Satış Yapıldı'
        WHEN LOWER(COALESCE(sm.integration_ref, '')) = 'production_output'
          OR COALESCE(sm.description, '') ILIKE '%Üretim (Çıktı)%'
          OR COALESCE(sm.description, '') ILIKE '%Uretim (Cikti)%'
        THEN 'Üretim Çıkışı'
        WHEN LOWER(TRIM(COALESCE(sm.movement_type, ''))) LIKE '%devir%'
        THEN CASE WHEN sm.is_giris THEN 'Devir Giriş' ELSE 'Devir Çıkış' END
        WHEN LOWER(TRIM(COALESCE(sm.movement_type, ''))) LIKE '%sevkiyat%'
          OR LOWER(TRIM(COALESCE(sm.movement_type, ''))) LIKE '%transfer%'
        THEN 'Sevkiyat'
        WHEN LOWER(TRIM(COALESCE(sm.movement_type, ''))) LIKE '%uretim%'
          OR LOWER(TRIM(COALESCE(sm.movement_type, ''))) LIKE '%üretim%'
        THEN CASE
          WHEN sm.is_giris THEN 'Üretim Girişi'
          ELSE 'Üretim Çıkışı'
        END
        WHEN LOWER(TRIM(COALESCE(sm.movement_type, ''))) IN ('giriş', 'giris', 'girdi')
        THEN 'Stok Giriş'
        WHEN LOWER(TRIM(COALESCE(sm.movement_type, ''))) IN ('çıkış', 'cikis', 'çıktı', 'cikti')
        THEN 'Stok Çıkış'
        ELSE COALESCE(
          NULLIF(TRIM(sm.movement_type), ''),
          CASE WHEN sm.is_giris THEN 'Stok Giriş' ELSE 'Stok Çıkış' END
        )
      END
    ''';

    final String baseSelect =
        '''
      SELECT
        sm.id,
        sm.movement_date AS tarih,
        $islemExpr AS islem,
        'Ürün' AS tur,
        COALESCE(p.kod, '-') AS kod,
        COALESCE(p.ad, '-') AS ad,
        COALESCE(p.grubu, '') AS grubu,
        COALESCE(p.ozellikler, '') AS ozellikler,
        COALESCE(d.ad, '-') AS depo,
        COALESCE(p.birim, 'Adet') AS olcu,
        ABS(COALESCE(sm.quantity, 0)) AS miktar,
        (
          ($netUnitPriceExpr) * COALESCE(sm.currency_rate, 1)
        ) AS birim_fiyat,
        (
          ($grossUnitPriceExpr) * COALESCE(sm.currency_rate, 1)
        ) AS birim_fiyat_vd,
        (
          ABS(COALESCE(sm.quantity, 0))
          * ($grossUnitPriceExpr)
          * COALESCE(sm.currency_rate, 1)
        ) AS toplam_vd,
        COALESCE(NULLIF(TRIM(COALESCE(ca.kod_no::text, '')), ''), '-') AS yer_kodu,
        COALESCE(NULLIF(TRIM(COALESCE(ca.adi::text, '')), ''), '-') AS yer_adi,
        COALESCE(NULLIF(TRIM(COALESCE(sm.description, '')), ''), '-') AS aciklama,
        COALESCE(sm.search_tags, '') AS search_tags_sm,
        COALESCE(p.search_tags, '') AS search_tags_p,
        COALESCE(ca.search_tags, '') AS search_tags_ca
      FROM stock_movements sm
      INNER JOIN products p ON p.id = sm.product_id
      LEFT JOIN depots d ON d.id = sm.warehouse_id
      LEFT JOIN LATERAL (
        SELECT cat.current_account_id
        FROM current_account_transactions cat
        WHERE COALESCE(cat.integration_ref, '') <> ''
          AND cat.integration_ref = sm.integration_ref
        ORDER BY cat.date DESC, cat.id DESC
        LIMIT 1
      ) cat_pick ON TRUE
      LEFT JOIN current_accounts ca ON ca.id = cat_pick.current_account_id
    ''';

    ({Map<String, dynamic> params, List<String> where}) buildWhere(
      RaporFiltreleri f,
    ) {
      final params = <String, dynamic>{};
      final where = <String>[];

      if (f.baslangicTarihi != null) {
        params['baslangic'] = DateTime(
          f.baslangicTarihi!.year,
          f.baslangicTarihi!.month,
          f.baslangicTarihi!.day,
        ).toIso8601String();
        where.add('base.tarih >= @baslangic');
      }
      if (f.bitisTarihi != null) {
        params['bitis'] = DateTime(
          f.bitisTarihi!.year,
          f.bitisTarihi!.month,
          f.bitisTarihi!.day,
        ).add(const Duration(days: 1)).toIso8601String();
        where.add('base.tarih < @bitis');
      }

      final String? islemFilter = _emptyToNull(f.islemTuru);
      if (islemFilter != null) {
        params['islemTuru'] = islemFilter;
        where.add(
          "normalize_text(COALESCE(base.islem, '')) = normalize_text(@islemTuru)",
        );
      }

      final String? groupFilter = _emptyToNull(f.urunGrubu);
      if (groupFilter != null) {
        params['urunGrubu'] = groupFilter;
        where.add(
          "normalize_text(COALESCE(base.grubu, '')) = normalize_text(@urunGrubu)",
        );
      }

      final String? turFilter = _emptyToNull(f.durum);
      if (turFilter != null) {
        params['tur'] = turFilter;
        where.add(
          "normalize_text(COALESCE(base.tur, '')) = normalize_text(@tur)",
        );
      }

      _addSearchConditionAny(where, params, [
        'COALESCE(base.search_tags_sm, \'\')',
        'COALESCE(base.search_tags_p, \'\')',
        'COALESCE(base.search_tags_ca, \'\')',
        "normalize_text(COALESCE(base.islem, ''))",
        "normalize_text(COALESCE(base.tur, ''))",
        "normalize_text(COALESCE(base.kod, ''))",
        "normalize_text(COALESCE(base.ad, ''))",
        "normalize_text(COALESCE(base.grubu, ''))",
        "normalize_text(COALESCE(base.ozellikler, ''))",
        "normalize_text(COALESCE(base.depo, ''))",
        "normalize_text(COALESCE(base.olcu, ''))",
        "normalize_text(COALESCE(base.yer_kodu, ''))",
        "normalize_text(COALESCE(base.yer_adi, ''))",
        "normalize_text(COALESCE(base.aciklama, ''))",
        // Numeric columns (best-effort, matches raw DB representation)
        'COALESCE(base.miktar, 0)::text',
        'COALESCE(base.birim_fiyat, 0)::text',
        'COALESCE(base.birim_fiyat_vd, 0)::text',
        'COALESCE(base.toplam_vd, 0)::text',
      ], effectiveArama);

      return (params: params, where: where);
    }

    final mainWhere = buildWhere(filtreler);
    final params = mainWhere.params;
    final whereSql = mainWhere.where.isEmpty
        ? ''
        : 'WHERE ${mainWhere.where.join(' AND ')}';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($baseSelect) base
      $whereSql
    ''';

    // "İşlem" filter dropdown seçenekleri seçimden bağımsız olmalı:
    // Seçilen işlem sadece tabloyu filtrelesin, dropdown tüm işlem türlerini
    // ve adetlerini göstermeye devam etsin.
    final islemToplamlariKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler.copyWith(clearIslemTuru: true),
      arama: arama,
    );
    final islemToplamlariFuture = _getOrComputeIslemToplamlari(
      cacheKey: islemToplamlariKey,
      loader: () async {
        final totalsWhere = buildWhere(
          filtreler.copyWith(clearIslemTuru: true),
        );
        final String whereSqlTotals = totalsWhere.where.isEmpty
            ? ''
            : 'WHERE ${totalsWhere.where.join(' AND ')}';

        final rows = await _queryMaps(pool, '''
          SELECT
            base.islem,
            COUNT(*) AS adet,
            COALESCE(SUM(COALESCE(base.toplam_vd, 0)), 0) AS toplam
          FROM ($baseSelect) base
          $whereSqlTotals
          GROUP BY base.islem
          ORDER BY normalize_text(COALESCE(base.islem, ''))
        ''', totalsWhere.params);

        return rows
            .map((row) {
              final String rawIslem = row['islem']?.toString() ?? '-';
              final int adet = _toInt(row['adet']) ?? 0;
              final double toplam = _toDouble(row['toplam']);
              return RaporIslemToplami(
                rawIslem: rawIslem,
                islem: IslemCeviriYardimcisi.cevir(rawIslem),
                tutar: _formatMoney(toplam),
                adet: adet,
              );
            })
            .where((item) => item.islem.trim().isNotEmpty && item.islem != '-')
            .toList(growable: false);
      },
    );

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summaryCardsFuture = _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final totals = await _queryMaps(pool, '''
          SELECT
            base.islem,
            base.olcu,
            COALESCE(SUM(COALESCE(base.miktar, 0)), 0) AS toplam_miktar,
            COALESCE(SUM(COALESCE(base.toplam_vd, 0)), 0) AS toplam_vd
          FROM ($baseSelect) base
          $whereSql
          GROUP BY base.islem, base.olcu
          ORDER BY
            normalize_text(COALESCE(base.islem, '')),
            normalize_text(COALESCE(base.olcu, ''))
        ''', params);

        final Map<String, Map<String, double>> qtyByIslemUnit =
            <String, Map<String, double>>{};
        final Map<String, double> vdByIslem = <String, double>{};

        for (final row in totals) {
          final String islem = row['islem']?.toString() ?? '-';
          if (islem.trim().isEmpty || islem == '-') continue;
          final String unit = row['olcu']?.toString() ?? '';
          final double qty = _toDouble(row['toplam_miktar']);
          final double vd = _toDouble(row['toplam_vd']);

          qtyByIslemUnit.putIfAbsent(islem, () => <String, double>{});
          if (unit.trim().isNotEmpty) {
            qtyByIslemUnit[islem]![unit] =
                (qtyByIslemUnit[islem]![unit] ?? 0) + qty;
          }
          vdByIslem[islem] = (vdByIslem[islem] ?? 0) + vd;
        }

        const preferredOrder = <String>[
          'Satış Yapıldı',
          'Stok Çıkış',
          'Üretim Çıkışı',
          'Devir Çıkış',
          'Sevkiyat',
          'Alış Yapıldı',
          'Stok Giriş',
          'Üretim Girişi',
          'Devir Giriş',
          'Açılış Stoğu',
        ];

        ({IconData icon, Color color}) styleFor(String islem) {
          final String low = islem.toLowerCase();
          if (low.contains('çık') || low.contains('cik')) {
            return (icon: Icons.north_east_rounded, color: AppPalette.red);
          }
          if (low.contains('gir')) {
            return (
              icon: Icons.south_west_rounded,
              color: const Color(0xFF27AE60),
            );
          }
          if (low.contains('devir')) {
            return (icon: Icons.swap_horiz_rounded, color: AppPalette.amber);
          }
          if (low.contains('üretim') || low.contains('uretim')) {
            return (
              icon: Icons.precision_manufacturing_rounded,
              color: AppPalette.slate,
            );
          }
          return (icon: Icons.bar_chart_rounded, color: AppPalette.slate);
        }

        final Set<String> remaining = Set<String>.from(qtyByIslemUnit.keys);
        final List<String> ordered = <String>[
          ...preferredOrder.where(remaining.remove),
          ...remaining.toList()..sort(),
        ];

        final List<RaporOzetKarti> cards = <RaporOzetKarti>[];
        for (final islem in ordered) {
          final qtyUnits = qtyByIslemUnit[islem] ?? const <String, double>{};
          final double totalVd = vdByIslem[islem] ?? 0;
          final qtyValue = formatQuantityTotalsByUnit(qtyUnits);
          final style = styleFor(islem);

          if (qtyValue.trim().isNotEmpty && qtyValue.trim() != '-') {
            cards.add(
              RaporOzetKarti(
                labelKey: islem,
                value: qtyValue,
                icon: style.icon,
                accentColor: style.color,
              ),
            );
          }

          if (totalVd != 0) {
            cards.add(
              RaporOzetKarti(
                labelKey: '$islem VD',
                value: _formatMoney(totalVd),
                icon: Icons.payments_outlined,
                accentColor: style.color,
              ),
            );
          }
        }

        return cards;
      },
    );

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'id',
    );

    final islemToplamlari = await islemToplamlariFuture;
    final summaryCards = await summaryCardsFuture;

    int resolveTotalCount() {
      final String? selectedIslem = _emptyToNull(filtreler.islemTuru);
      if (selectedIslem == null) {
        return islemToplamlari.fold<int>(0, (sum, item) => sum + item.adet);
      }
      final String selectedNorm = _normalizeArama(selectedIslem);
      for (final item in islemToplamlari) {
        if (_normalizeArama(item.rawIslem) == selectedNorm) return item.adet;
      }
      return 0;
    }

    final mappedRows = pageResult.rows
        .map((tx) {
          final tarih = _toDateTime(tx['tarih']);
          final features = _parseFirstThreeFeatureBadges(tx['ozellikler']);
          final String featuresText = features.isEmpty
              ? '-'
              : features.map((item) => item.name).join('\n');

          final double miktar = _toDouble(tx['miktar']);
          final double birimFiyat = _toDouble(tx['birim_fiyat']);
          final double birimFiyatVd = _toDouble(tx['birim_fiyat_vd']);
          final double toplamVd = _toDouble(tx['toplam_vd']);

          return RaporSatiri(
            id: 'urun_hareket_${tx['id']}',
            cells: {
              'islem': tx['islem']?.toString() ?? '-',
              'tarih': _formatDate(tarih, includeTime: true),
              'tur': tx['tur']?.toString() ?? 'Ürün',
              'kod': tx['kod']?.toString() ?? '-',
              'ad': tx['ad']?.toString() ?? '-',
              'grubu': tx['grubu']?.toString() ?? '-',
              'ozellik': featuresText,
              'depo': tx['depo']?.toString() ?? '-',
              'miktar': _formatNumber(miktar),
              'olcu': tx['olcu']?.toString() ?? '-',
              'birim_fiyat': _formatMoney(birimFiyat),
              'birim_fiyat_vd': _formatMoney(birimFiyatVd),
              'yer_kodu': tx['yer_kodu']?.toString() ?? '-',
              'yer_adi': tx['yer_adi']?.toString() ?? '-',
              'aciklama': tx['aciklama']?.toString() ?? '-',
            },
            extra: {
              'features': features
                  .map(
                    (item) => <String, dynamic>{
                      'name': item.name,
                      'color': item.color,
                    },
                  )
                  .toList(growable: false),
            },
            sourceMenuIndex: 7,
            sourceSearchQuery: tx['ad']?.toString(),
            amountValue: toplamVd.abs(),
            sortValues: {
              'islem': tx['islem'],
              'tarih': tarih,
              'tur': tx['tur'],
              'kod': tx['kod'],
              'ad': tx['ad'],
              'grubu': tx['grubu'],
              'ozellik': featuresText,
              'depo': tx['depo'],
              'miktar': miktar,
              'olcu': tx['olcu'],
              'birim_fiyat': birimFiyat,
              'birim_fiyat_vd': birimFiyatVd,
              'yer_kodu': tx['yer_kodu'],
              'yer_adi': tx['yer_adi'],
              'aciklama': tx['aciklama'],
            },
          );
        })
        .toList(growable: false);

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('islem', 'reports.columns.process_exact', 150),
        _column('tarih', 'reports.columns.date_exact', 150),
        _column('tur', 'common.type', 100),
        _column('kod', 'common.code_no', 90),
        _column('ad', 'common.name', 180),
        _column('grubu', 'products.table.group', 120),
        _column('ozellik', 'Özellik', 140, allowSorting: false),
        _column('depo', 'common.warehouse', 140),
        _column(
          'miktar',
          'common.quantity',
          110,
          alignment: Alignment.centerRight,
        ),
        _column('olcu', 'productions.make.table.unit', 100),
        _column(
          'birim_fiyat',
          'products.table.unit_price',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'birim_fiyat_vd',
          'products.table.unit_price_vat',
          140,
          alignment: Alignment.centerRight,
        ),
        _column('yer_kodu', 'reports.columns.place_code_exact', 90),
        _column('yer_adi', 'reports.columns.place_name_exact', 160),
        _column('aciklama', 'reports.columns.description_exact', 220),
      ],
      rows: mappedRows,
      summaryCards: summaryCards,
      islemToplamlari: islemToplamlari,
      totalCount: resolveTotalCount(),
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildOptimizedTumHareketler(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required String arama,
    String? cursor,
    String? sortKey,
    required bool sortAscending,
    required int page,
    required int pageSize,
  }) async {
    final pool = await _havuzAl();
    final effectiveArama = _normalizeNumericSearchForReports(arama);
    final List<String> searchTokens = _searchTokens(effectiveArama);
    final kullaniciAdi = await _resolveKullaniciAdi(filtreler.kullaniciId);
    final params = <String, dynamic>{};
    void applyCommonDateUser(
      List<String> target,
      String aliasDate,
      String aliasUser,
    ) {
      if (filtreler.baslangicTarihi != null) {
        params['baslangic'] = DateTime(
          filtreler.baslangicTarihi!.year,
          filtreler.baslangicTarihi!.month,
          filtreler.baslangicTarihi!.day,
        ).toIso8601String();
        target.add('$aliasDate >= @baslangic');
      }
      if (filtreler.bitisTarihi != null) {
        params['bitis'] = DateTime(
          filtreler.bitisTarihi!.year,
          filtreler.bitisTarihi!.month,
          filtreler.bitisTarihi!.day,
        ).add(const Duration(days: 1)).toIso8601String();
        target.add('$aliasDate < @bitis');
      }
      if (_emptyToNull(kullaniciAdi) != null) {
        params['kullanici'] = _emptyToNull(kullaniciAdi);
        target.add("COALESCE($aliasUser, '') = @kullanici");
      }
      if (filtreler.minTutar != null) {
        params['minTutar'] = filtreler.minTutar;
        target.add('amount >= @minTutar');
      }
      if (filtreler.maxTutar != null) {
        params['maxTutar'] = filtreler.maxTutar;
        target.add('amount <= @maxTutar');
      }
    }

    final yerCariHesapLabel = tr(
      'cashregisters.transaction.type.current_account',
    ).replaceAll("'", "''");
    final yerPerakendeLabel = tr(
      'reports.payment_types.retail',
    ).replaceAll("'", "''");
    final yerKasaLabel = tr('transactions.source.cash').replaceAll("'", "''");
    final yerBankaLabel = tr('transactions.source.bank').replaceAll("'", "''");
    final yerKrediKartiLabel = tr(
      'transactions.source.credit_card',
    ).replaceAll("'", "''");

    final cariYerExpr = "normalize_text('$yerCariHesapLabel')";
    const cariMirrorYerSql =
        "normalize_text(COALESCE(t.location, '')) NOT IN ("
        "normalize_text('Cari Hesap'), "
        "normalize_text('Cari İşlem'), "
        "normalize_text('current_account'))";
    // Perakende satış ödemeleri bazı eski kayıtlarda location='Cari Hesap' olarak
    // kaydedilmiş olabiliyor. Cari entegrasyonu yoksa (integration_ref: RETAIL-*)
    // bunları "cari mirror" filtresine takmadan rapora dahil et.
    const retailRefSql = "COALESCE(t.integration_ref, '') ILIKE 'RETAIL-%'";
    final kasaYer2Expr = "normalize_text('$yerKasaLabel')";
    final bankaYer2Expr = "normalize_text('$yerBankaLabel')";
    final krediKartiYer2Expr = "normalize_text('$yerKrediKartiLabel')";

    final cariWhere = <String>[];
    applyCommonDateUser(cariWhere, 'cat.date', 'cat.user_name');
    _addSearchConditionAny(cariWhere, params, [
      'cat.search_tags',
      'ca.search_tags',
      cariYerExpr,
    ], effectiveArama);

    final kasaWhere = <String>[];
    applyCommonDateUser(kasaWhere, 't.date', 't.user_name');
    kasaWhere.add("COALESCE(t.integration_ref, '') NOT ILIKE 'CARI-PAV-%'");
    kasaWhere.add('($cariMirrorYerSql OR $retailRefSql)');
    _addSearchConditionAny(kasaWhere, params, [
      't.search_tags',
      kasaYer2Expr,
    ], effectiveArama);

    final bankaWhere = <String>[];
    applyCommonDateUser(bankaWhere, 't.date', 't.user_name');
    bankaWhere.add("COALESCE(t.integration_ref, '') NOT ILIKE 'CARI-PAV-%'");
    bankaWhere.add('($cariMirrorYerSql OR $retailRefSql)');
    _addSearchConditionAny(bankaWhere, params, [
      't.search_tags',
      bankaYer2Expr,
    ], effectiveArama);

    final kartWhere = <String>[];
    applyCommonDateUser(kartWhere, 't.date', 't.user_name');
    kartWhere.add("COALESCE(t.integration_ref, '') NOT ILIKE 'CARI-PAV-%'");
    kartWhere.add('($cariMirrorYerSql OR $retailRefSql)');
    _addSearchConditionAny(kartWhere, params, [
      't.search_tags',
      krediKartiYer2Expr,
    ], effectiveArama);

    final retailWhere = <String>[];
    applyCommonDateUser(retailWhere, 'rs.tarih', 'rs.kullanici');
    _addSearchConditionAny(retailWhere, params, [
      "normalize_text(COALESCE(rs.integration_ref, ''))",
      "normalize_text(COALESCE(rs.aciklama, ''))",
      "normalize_text('$yerPerakendeLabel')",
    ], effectiveArama);

    // Agregasyon öncesi filtreleme: bu ay gibi tarihe göre raporda
    // shipments tablosunu komple tarayıp gruplayarak yavaşlamasın.
    final retailSourceWhere = <String>[
      "COALESCE(s.integration_ref, '') ILIKE 'RETAIL-%'",
    ];
    if (filtreler.baslangicTarihi != null) {
      retailSourceWhere.add('s.date >= @baslangic');
    }
    if (filtreler.bitisTarihi != null) {
      retailSourceWhere.add('s.date < @bitis');
    }
    if (_emptyToNull(kullaniciAdi) != null) {
      retailSourceWhere.add("COALESCE(s.created_by, '') = @kullanici");
    }

    final unionQuery =
        '''
      SELECT *
      FROM (
        SELECT
          ((12::bigint << 48) + rs.id::bigint) AS gid,
          rs.id,
          rs.tarih,
          'Satış Yapıldı' AS islem,
          NULL AS yon,
          rs.integration_ref,
          NULL AS guncel_durum,
          '$yerPerakendeLabel' AS yer,
          '' AS yer_kodu,
          '' AS yer_adi,
          rs.amount AS tutar_num,
          'TRY' AS para_birimi,
          1 AS kur,
          '' AS yer_2,
          COALESCE(rs.integration_ref, '-') AS belge_no,
          '-' AS e_belge,
          '-' AS irsaliye_no,
          '-' AS fatura_no,
          rs.aciklama AS aciklama,
          '' AS aciklama_2,
          NULL AS vade_tarihi,
          COALESCE(rs.kullanici, '-') AS kullanici,
          NULL AS source_menu_index,
          rs.integration_ref AS source_search_query,
          FALSE AS is_incoming
        FROM (
          SELECT
            MIN(s.id) AS id,
            MAX(s.date) AS tarih,
            MAX(s.integration_ref) AS integration_ref,
            MAX(s.created_by) AS kullanici,
            MAX(COALESCE(NULLIF(s.description, ''), 'Perakende Satış')) AS aciklama,
            SUM(
              COALESCE(
                CASE
                  WHEN COALESCE(item->>'total', '') ~ '^-?[0-9]+([.,][0-9]+)?\$' THEN
                    REPLACE(item->>'total', ',', '.')::numeric
                  ELSE NULL
                END,
                COALESCE(
                  CASE
                    WHEN COALESCE(item->>'quantity', '') ~ '^-?[0-9]+([.,][0-9]+)?\$' THEN
                      REPLACE(item->>'quantity', ',', '.')::numeric
                    ELSE NULL
                  END,
                  0
                ) *
                    COALESCE(
                      CASE
                        WHEN COALESCE(item->>'unitCost', '') ~ '^-?[0-9]+([.,][0-9]+)?\$' THEN
                          REPLACE(item->>'unitCost', ',', '.')::numeric
                        ELSE NULL
                      END,
                      CASE
                        WHEN COALESCE(item->>'price', '') ~ '^-?[0-9]+([.,][0-9]+)?\$' THEN
                          REPLACE(item->>'price', ',', '.')::numeric
                        ELSE NULL
                      END,
                      0
                    )
              )
            ) AS amount
          FROM shipments s
          CROSS JOIN LATERAL jsonb_array_elements(COALESCE(s.items, '[]'::jsonb)) item
          WHERE ${retailSourceWhere.join(' AND ')}
          GROUP BY s.integration_ref
        ) rs
        ${retailWhere.isEmpty ? '' : 'WHERE ${retailWhere.join(' AND ')}'}
        UNION ALL
        SELECT
          ((${TabAciciScope.cariKartiIndex}::bigint << 48) + cat.id::bigint) AS gid,
          cat.id,
          cat.date AS tarih,
          cat.source_type AS islem,
          cat.type AS yon,
          cat.integration_ref,
          CASE
            WHEN cat.source_type ILIKE '%Çek%' THEN (
              SELECT collection_status
              FROM cheques
              WHERE id = cat.source_id
              LIMIT 1
            )
            WHEN cat.source_type ILIKE '%Senet%' THEN (
              SELECT collection_status
              FROM promissory_notes
              WHERE id = cat.source_id
              LIMIT 1
            )
            ELSE NULL
          END AS guncel_durum,
          '$yerCariHesapLabel' AS yer,
          ca.kod_no AS yer_kodu,
          ca.adi AS yer_adi,
          cat.amount AS tutar_num,
          cat.para_birimi AS para_birimi,
          cat.kur AS kur,
          CASE
            WHEN cat.integration_ref ILIKE 'CARI-PAV-CASH-%' THEN '$yerKasaLabel'
            WHEN cat.integration_ref ILIKE 'CARI-PAV-BANK-%' THEN '$yerBankaLabel'
            WHEN cat.integration_ref ILIKE 'CARI-PAV-CREDIT_CARD-%' THEN '$yerKrediKartiLabel'
            WHEN LOWER(TRIM(COALESCE(cat.source_type, ''))) IN ('kasa', 'banka', 'kredi kartı', 'kredi karti') THEN
              CASE LOWER(TRIM(COALESCE(cat.source_type, '')))
                WHEN 'kasa' THEN '$yerKasaLabel'
                WHEN 'banka' THEN '$yerBankaLabel'
                ELSE '$yerKrediKartiLabel'
              END
            ELSE ''
          END AS yer_2,
          COALESCE(cat.fatura_no, COALESCE(cat.irsaliye_no, COALESCE(cat.belge, COALESCE(cat.integration_ref, '-')))) AS belge_no,
          cat.e_belge AS e_belge,
          cat.irsaliye_no AS irsaliye_no,
          cat.fatura_no AS fatura_no,
          cat.description AS aciklama,
          COALESCE(cat.aciklama2, '') AS aciklama_2,
          NULL AS vade_tarihi,
          COALESCE(cat.user_name, '-') AS kullanici,
          ${TabAciciScope.cariKartiIndex} AS source_menu_index,
          ca.adi AS source_search_query,
          NULL AS is_incoming
        FROM current_account_transactions cat
        INNER JOIN current_accounts ca ON ca.id = cat.current_account_id
        ${cariWhere.isEmpty ? '' : 'WHERE ${cariWhere.join(' AND ')}'}
        UNION ALL
        SELECT
          ((13::bigint << 48) + t.id::bigint) AS gid,
          t.id,
          t.date AS tarih,
          t.type AS islem,
          NULL AS yon,
          t.integration_ref,
          NULL AS guncel_durum,
          CASE
            WHEN $retailRefSql THEN '$yerPerakendeLabel'
            ELSE COALESCE(NULLIF(t.location, ''), '$yerPerakendeLabel')
          END AS yer,
          CASE WHEN $retailRefSql THEN '' ELSE COALESCE(t.location_code, '') END AS yer_kodu,
          CASE WHEN $retailRefSql THEN '' ELSE COALESCE(t.location_name, '') END AS yer_adi,
          t.amount AS tutar_num,
          'TRY' AS para_birimi,
          1 AS kur,
          '$yerKasaLabel' AS yer_2,
          COALESCE(t.integration_ref, '-') AS belge_no,
          '-' AS e_belge,
          '-' AS irsaliye_no,
          '-' AS fatura_no,
          t.description AS aciklama,
          '' AS aciklama_2,
          NULL AS vade_tarihi,
          COALESCE(t.user_name, '-') AS kullanici,
          13 AS source_menu_index,
          a.name AS source_search_query,
          NULL AS is_incoming
        FROM cash_register_transactions t
        LEFT JOIN cash_registers a ON a.id = t.cash_register_id
        ${kasaWhere.isEmpty ? '' : 'WHERE ${kasaWhere.join(' AND ')}'}
        UNION ALL
        SELECT
          ((15::bigint << 48) + t.id::bigint) AS gid,
          t.id,
          t.date AS tarih,
          t.type AS islem,
          NULL AS yon,
          t.integration_ref,
          NULL AS guncel_durum,
          CASE
            WHEN $retailRefSql THEN '$yerPerakendeLabel'
            ELSE COALESCE(NULLIF(t.location, ''), '$yerPerakendeLabel')
          END AS yer,
          CASE WHEN $retailRefSql THEN '' ELSE COALESCE(t.location_code, '') END AS yer_kodu,
          CASE WHEN $retailRefSql THEN '' ELSE COALESCE(t.location_name, '') END AS yer_adi,
          t.amount AS tutar_num,
          'TRY' AS para_birimi,
          1 AS kur,
          '$yerBankaLabel' AS yer_2,
          COALESCE(t.integration_ref, '-') AS belge_no,
          '-' AS e_belge,
          '-' AS irsaliye_no,
          '-' AS fatura_no,
          t.description AS aciklama,
          '' AS aciklama_2,
          NULL AS vade_tarihi,
          COALESCE(t.user_name, '-') AS kullanici,
          15 AS source_menu_index,
          a.name AS source_search_query,
          NULL AS is_incoming
        FROM bank_transactions t
        LEFT JOIN banks a ON a.id = t.bank_id
        ${bankaWhere.isEmpty ? '' : 'WHERE ${bankaWhere.join(' AND ')}'}
        UNION ALL
        SELECT
          ((16::bigint << 48) + t.id::bigint) AS gid,
          t.id,
          t.date AS tarih,
          t.type AS islem,
          NULL AS yon,
          t.integration_ref,
          NULL AS guncel_durum,
          CASE
            WHEN $retailRefSql THEN '$yerPerakendeLabel'
            ELSE COALESCE(NULLIF(t.location, ''), '$yerPerakendeLabel')
          END AS yer,
          CASE WHEN $retailRefSql THEN '' ELSE COALESCE(t.location_code, '') END AS yer_kodu,
          CASE WHEN $retailRefSql THEN '' ELSE COALESCE(t.location_name, '') END AS yer_adi,
          t.amount AS tutar_num,
          'TRY' AS para_birimi,
          1 AS kur,
          '$yerKrediKartiLabel' AS yer_2,
          COALESCE(t.integration_ref, '-') AS belge_no,
          '-' AS e_belge,
          '-' AS irsaliye_no,
          '-' AS fatura_no,
          t.description AS aciklama,
          '' AS aciklama_2,
          NULL AS vade_tarihi,
          COALESCE(t.user_name, '-') AS kullanici,
          16 AS source_menu_index,
          a.name AS source_search_query,
          NULL AS is_incoming
        FROM credit_card_transactions t
        LEFT JOIN credit_cards a ON a.id = t.credit_card_id
        ${kartWhere.isEmpty ? '' : 'WHERE ${kartWhere.join(' AND ')}'}
      ) hareketler
    ''';

    const String eBelgeVarSentinel = '__HAS_EBELGE__';
    final String? islemTuruFilter = _emptyToNull(filtreler.islemTuru);
    final String? belgeFilter = _emptyToNull(filtreler.belgeNo);
    final String? eBelgeFilter = _emptyToNull(filtreler.referansNo);

    String? belgeWhere({required String alias}) {
      if (belgeFilter == null) return null;

      final faturaClean =
          "TRIM(REPLACE(COALESCE($alias.fatura_no, ''), '-', ''))";
      final irsaliyeClean =
          "TRIM(REPLACE(COALESCE($alias.irsaliye_no, ''), '-', ''))";

      switch (belgeFilter) {
        case 'Fatura':
          return "($faturaClean <> '' AND $irsaliyeClean = '')";
        case 'İrsaliye':
          return "($irsaliyeClean <> '' AND $faturaClean = '')";
        case 'İrsaliyeli Fatura':
          return "($faturaClean <> '' AND $irsaliyeClean <> '')";
        case '-':
          return "($faturaClean = '' AND $irsaliyeClean = '')";
        default:
          return null;
      }
    }

    String? eBelgeWhere({required String alias}) {
      if (eBelgeFilter == null) return null;
      if (eBelgeFilter == eBelgeVarSentinel) {
        return "COALESCE(NULLIF(TRIM(COALESCE($alias.e_belge, '')), ''), '-') <> '-'";
      }
      params['eBelgeFiltre'] = eBelgeFilter;
      return "normalize_text(COALESCE(NULLIF($alias.e_belge, ''), '-')) = normalize_text(@eBelgeFiltre)";
    }

    String sortExpr(String? key, {required String alias}) {
      switch (key) {
        case 'islem':
          return "COALESCE($alias.islem, '')";
        case 'yer':
          return "COALESCE($alias.yer, '')";
        case 'yer_kodu':
          return "COALESCE($alias.yer_kodu, '')";
        case 'yer_adi':
          return "COALESCE($alias.yer_adi, '')";
        case 'yer_2':
          return "COALESCE($alias.yer_2, '')";
        case 'tarih':
          return '$alias.tarih';
        case 'tutar':
          return '$alias.tutar_num';
        case 'kur':
          return '$alias.kur';
        case 'belge':
          return "COALESCE($alias.belge_no, '')";
        case 'e_belge':
          return "COALESCE($alias.e_belge, '')";
        case 'irsaliye_no':
          return "COALESCE($alias.irsaliye_no, '')";
        case 'fatura_no':
          return "COALESCE($alias.fatura_no, '')";
        case 'aciklama':
          return "COALESCE($alias.aciklama, '')";
        case 'aciklama_2':
          return "COALESCE($alias.aciklama_2, '')";
        case 'vade_tarihi':
          return '$alias.vade_tarihi';
        case 'kullanici':
          return "COALESCE($alias.kullanici, '')";
        default:
          return '$alias.tarih';
      }
    }

    final List<String> outerWhereBase = <String>[
      if (belgeWhere(alias: 'base') != null) belgeWhere(alias: 'base')!,
      if (eBelgeWhere(alias: 'base') != null) eBelgeWhere(alias: 'base')!,
    ];

    final String outerWhereBaseSql = outerWhereBase.isEmpty
        ? ''
        : 'WHERE ${outerWhereBase.join(' AND ')}';

    final String baseQuery = islemTuruFilter == null
        ? '''
      SELECT base.*, ${sortExpr(sortKey, alias: 'base')} AS sort_val
      FROM ($unionQuery) base
      $outerWhereBaseSql
    '''
        : () {
            params['islemTuruFiltre'] = islemTuruFilter;
            final List<String> outerWhereLabeled = <String>[
              "normalize_text(COALESCE(l.display_islem, '')) = normalize_text(@islemTuruFiltre)",
              if (belgeWhere(alias: 'l') != null) belgeWhere(alias: 'l')!,
              if (eBelgeWhere(alias: 'l') != null) eBelgeWhere(alias: 'l')!,
            ];
            final String outerWhereLabeledSql =
                'WHERE ${outerWhereLabeled.join(' AND ')}';

            return '''
      WITH base AS (
        SELECT
          u.*,
          LOWER(COALESCE(u.islem, '')) AS low_islem,
          LOWER(COALESCE(u.integration_ref, '')) AS low_ref,
          LOWER(COALESCE(u.yon, '')) AS low_yon,
          LOWER(COALESCE(u.aciklama, '')) AS low_aciklama,
          LOWER(COALESCE(u.yer, '')) AS low_yer
        FROM ($unionQuery) u
      ),
      flags AS (
        SELECT
          base.*,
          (
            base.low_islem LIKE '%çek%' OR
            base.low_islem LIKE '%cek%' OR
            base.low_ref LIKE 'cheque%' OR
            base.low_ref LIKE 'cek-%'
          ) AS is_check,
          (
            base.low_islem LIKE '%senet%' OR
            base.low_ref LIKE 'note%' OR
            base.low_ref LIKE 'senet-%' OR
            base.low_ref LIKE '%promissory%'
          ) AS is_note,
          (
            base.low_ref LIKE 'sale-%' OR
            base.low_ref LIKE 'retail-%'
          ) AS is_sale_ref,
          (base.low_ref LIKE 'purchase-%') AS is_purchase_ref,
          (
            base.low_ref LIKE 'cari-pav-cash-%' OR
            base.low_ref LIKE 'cari-pav-bank-%' OR
            base.low_ref LIKE 'cari-pav-credit_card-%'
          ) AS is_cari_payment_ref,
          (
            TRIM(base.low_islem) IN ('kasa', 'banka', 'kredi kartı', 'kredi karti')
          ) AS is_cari_finans_source_type,
          (base.low_ref LIKE 'retail-%') AS is_retail_ref,
          (
            base.low_yon LIKE '%alacak%' OR
            base.low_islem LIKE '%tahsilat%' OR
            base.low_islem LIKE '%alış%' OR
            base.low_islem LIKE '%alis%' OR
            base.low_islem LIKE '%girdi%' OR
            base.low_islem LIKE '%giriş%' OR
            base.low_islem LIKE '%giris%' OR
            base.low_islem LIKE '%alındı%' OR
            base.low_islem LIKE '%alindi%' OR
            base.low_islem LIKE '%alınan%' OR
            base.low_islem LIKE '%alinan%'
          ) AS cari_is_incoming,
          (
            base.low_islem LIKE '%tahsil%' OR
            base.low_islem LIKE '%girdi%' OR
            base.low_islem LIKE '%giriş%' OR
            base.low_islem LIKE '%giris%' OR
            base.low_islem LIKE '%havale%' OR
            base.low_islem LIKE '%eft%'
          ) AS finans_is_incoming,
          (
            base.low_islem LIKE '%ödeme%' OR
            base.low_islem LIKE '%odeme%' OR
            base.low_islem LIKE '%harcama%' OR
            base.low_islem LIKE '%çıktı%' OR
            base.low_islem LIKE '%cikti%' OR
            base.low_islem LIKE '%çıkış%' OR
            base.low_islem LIKE '%cikis%'
          ) AS finans_is_outgoing
        FROM base
      ),
      labeled AS (
        SELECT
          flags.*,
          CASE
            WHEN flags.source_menu_index = ${TabAciciScope.cariKartiIndex} THEN
              CASE
                WHEN flags.is_cari_payment_ref OR flags.is_cari_finans_source_type THEN
                  CASE WHEN flags.cari_is_incoming THEN 'Para Alındı' ELSE 'Para Verildi' END
                WHEN flags.is_sale_ref THEN 'Satış Yapıldı'
                WHEN flags.is_purchase_ref THEN 'Alış Yapıldı'
                WHEN flags.is_check OR flags.is_note THEN
                  CASE
                    WHEN flags.guncel_durum = 'Ciro Edildi' THEN
                      CASE
                        WHEN flags.is_check THEN 'Çek Alındı (Ciro Edildi)'
                        ELSE 'Senet Alındı (Ciro Edildi)'
                      END
                    WHEN flags.guncel_durum IN ('Tahsil Edildi', 'Ödendi') THEN
                      CASE
                        WHEN flags.is_check THEN
                          CASE
                            WHEN flags.cari_is_incoming THEN 'Çek Alındı (' || flags.guncel_durum || ')'
                            ELSE 'Çek Verildi (' || flags.guncel_durum || ')'
                          END
                        ELSE
                          CASE
                            WHEN flags.cari_is_incoming THEN 'Senet Alındı (' || flags.guncel_durum || ')'
                            ELSE 'Senet Verildi (' || flags.guncel_durum || ')'
                          END
                      END
                    WHEN flags.is_check THEN
                      CASE WHEN flags.cari_is_incoming THEN 'Çek Alındı' ELSE 'Çek Verildi' END
                    ELSE
                      CASE WHEN flags.cari_is_incoming THEN 'Senet Alındı' ELSE 'Senet Verildi' END
                  END
                ELSE
                  CASE
                    WHEN TRIM(flags.low_islem) IN ('borç', 'borc') THEN 'Cari Borç'
                    WHEN TRIM(flags.low_islem) = 'alacak' THEN 'Cari Alacak'
                    WHEN (
                      (flags.low_islem LIKE '%açılış%' OR flags.low_islem LIKE '%acilis%') AND
                      (flags.low_islem LIKE '%devir%' OR flags.low_islem LIKE '%devri%')
                    ) THEN
                      CASE
                        WHEN flags.low_islem LIKE '%alacak%' THEN 'Açılış Alacak Devri'
                        WHEN flags.low_islem LIKE '%borç%' OR flags.low_islem LIKE '%borc%' THEN 'Açılış Borç Devri'
                        ELSE COALESCE(flags.islem, '-')
                      END
                    WHEN (
                      flags.low_islem LIKE '%tahsilat%' OR
                      flags.low_islem LIKE '%girdi%' OR
                      flags.low_islem LIKE '%giriş%' OR
                      flags.low_islem LIKE '%giris%' OR
                      flags.low_islem = 'para alındı' OR
                      flags.low_islem = 'para alindi'
                    ) THEN 'Para Alındı'
                    WHEN (
                      flags.low_islem LIKE '%ödeme%' OR
                      flags.low_islem LIKE '%odeme%' OR
                      flags.low_islem LIKE '%çıktı%' OR
                      flags.low_islem LIKE '%çıkış%' OR
                      flags.low_islem = 'para verildi'
                    ) THEN 'Para Verildi'
                    WHEN flags.low_islem LIKE '%borç dekontu%' OR flags.low_islem LIKE '%borc dekontu%' THEN 'Borç Dekontu'
                    WHEN flags.low_islem LIKE '%alacak dekontu%' THEN 'Alacak Dekontu'
                    WHEN flags.low_islem LIKE '%satış yapıldı%' OR flags.low_islem LIKE '%satis yapildi%' THEN 'Satış Yapıldı'
                    WHEN flags.low_islem LIKE '%alış yapıldı%' OR flags.low_islem LIKE '%alis yapildi%' THEN 'Alış Yapıldı'
                    WHEN flags.low_islem LIKE '%satış%' OR flags.low_islem LIKE '%satis%' THEN 'Satış Faturası'
                    WHEN flags.low_islem LIKE '%alış%' OR flags.low_islem LIKE '%alis%' THEN 'Alış Faturası'
                    WHEN COALESCE(TRIM(flags.yon), '-') <> '' THEN
                      CASE WHEN flags.cari_is_incoming THEN 'Para Alındı' ELSE 'Para Verildi' END
                    ELSE COALESCE(flags.islem, '-')
                  END
              END
            WHEN flags.source_menu_index IN (13, 15, 16) THEN
              CASE
                WHEN flags.is_sale_ref AND NOT flags.is_retail_ref THEN 'Satış Yapıldı'
                WHEN flags.is_purchase_ref THEN 'Alış Yapıldı'
                WHEN (
                  flags.low_ref = 'opening_stock' OR
                  flags.low_ref LIKE '%opening_stock%' OR
                  flags.low_aciklama LIKE '%açılış%' OR
                  flags.low_aciklama LIKE '%acilis%'
                ) THEN 'Açılış Stoğu'
                WHEN (
                  flags.low_ref LIKE '%production%' OR
                  flags.low_aciklama LIKE '%üretim%' OR
                  flags.low_aciklama LIKE '%uretim%'
                ) THEN 'Üretim'
                WHEN (
                  flags.low_ref LIKE '%transfer%' OR
                  flags.low_aciklama LIKE '%devir%'
                ) THEN 'Devir'
                WHEN flags.source_menu_index <> 13 AND flags.low_ref LIKE '%collection%' THEN 'Tahsilat'
                WHEN flags.source_menu_index <> 13 AND flags.low_ref LIKE '%payment%' THEN 'Ödeme'
                WHEN flags.is_check THEN
                  CASE
                    WHEN (
                      CASE
                        WHEN flags.finans_is_incoming THEN TRUE
                        WHEN flags.finans_is_outgoing THEN FALSE
                        ELSE FALSE
                      END
                    ) THEN 'Çek Alındı (Tahsil Edildi)'
                    ELSE 'Çek Verildi (Ödendi)'
                  END
                WHEN flags.is_note THEN
                  CASE
                    WHEN (
                      CASE
                        WHEN flags.finans_is_incoming THEN TRUE
                        WHEN flags.finans_is_outgoing THEN FALSE
                        ELSE FALSE
                      END
                    ) THEN 'Senet Alındı (Tahsil Edildi)'
                    ELSE 'Senet Verildi (Ödendi)'
                  END
                ELSE
                  CASE
                    WHEN (
                      NOT (
                        CASE
                          WHEN flags.finans_is_incoming THEN TRUE
                          WHEN flags.finans_is_outgoing THEN FALSE
                          ELSE FALSE
                        END
                      ) AND flags.low_yer LIKE '%personel%'
                    ) THEN 'Personel Ödemesi'
                    WHEN (
                      CASE
                        WHEN flags.finans_is_incoming THEN TRUE
                        WHEN flags.finans_is_outgoing THEN FALSE
                        ELSE FALSE
                      END
                    ) THEN 'Para Alındı'
                    ELSE 'Para Verildi'
                  END
              END
            ELSE COALESCE(flags.islem, '-')
          END AS display_islem,
          ${sortExpr(sortKey, alias: 'flags')} AS sort_val
        FROM flags
      )
      SELECT l.*
      FROM labeled l
      $outerWhereLabeledSql
    ''';
          }();

    final pageResult = await _fetchKeysetPageById(
      pool: pool,
      baseQuery: baseQuery,
      paramsBase: params,
      sortAlias: 'sort_val',
      sortAscending: sortAscending,
      pageSize: pageSize,
      cursor: cursor,
      idColumn: 'gid',
    );

    final rows = pageResult.rows;

    final mappedRows = rows
        .map((tx) {
          final tarih = _toDateTime(tx['tarih']);
          final vade = _toDateTime(tx['vade_tarihi']);
          final tutar = _toDouble(tx['tutar_num']);
          final sunum = _genelHareketSunumunuHazirla(tx);
          final dynamic incoming = tx['is_incoming'];
          final Map<String, dynamic> extra = <String, dynamic>{};
          if (incoming is bool) {
            extra['isIncoming'] = incoming;
          }

          final String integrationRef = tx['integration_ref']?.toString() ?? '';
          if (integrationRef.trim().isNotEmpty) {
            extra['integrationRef'] = integrationRef;
          }

          final bool isSaleOrPurchaseRow =
              _isSaleTransaction(sunum.islem) ||
              _isPurchaseTransaction(sunum.islem);
          final bool expandable =
              isSaleOrPurchaseRow && integrationRef.trim().isNotEmpty;
          final faturaNo =
              tx['fatura_no']?.toString().replaceAll('-', '').trim() ?? '';
          final irsaliyeNo =
              tx['irsaliye_no']?.toString().replaceAll('-', '').trim() ?? '';
          String belgeDurumu = '-';
          if (faturaNo.isNotEmpty && irsaliyeNo.isNotEmpty) {
            belgeDurumu = 'İrsaliyeli Fatura';
          } else if (faturaNo.isNotEmpty) {
            belgeDurumu = 'Fatura';
          } else if (irsaliyeNo.isNotEmpty) {
            belgeDurumu = 'İrsaliye';
          }

          final Map<String, String> cells = {
            'islem': IslemCeviriYardimcisi.cevir(sunum.islem),
            'yer': tx['yer']?.toString() ?? '-',
            'yer_kodu': tx['yer_kodu']?.toString() ?? '-',
            'yer_adi': tx['yer_adi']?.toString() ?? '-',
            'tarih': tarih != null
                ? DateFormat('dd.MM.yyyy HH:mm').format(tarih)
                : '-',
            'tutar': _formatMoney(tutar),
            'kur': _formatExchangeRate(tx['kur']),
            'yer_2': tx['yer_2']?.toString() ?? '',
            'belge': belgeDurumu,
            'e_belge': tx['e_belge']?.toString() ?? '-',
            'irsaliye_no': tx['irsaliye_no']?.toString() ?? '',
            'fatura_no': tx['fatura_no']?.toString() ?? '',
            'aciklama': sunum.aciklama,
            'aciklama_2': sunum.aciklama2,
            'vade_tarihi': vade != null
                ? DateFormat('dd.MM.yyyy').format(vade)
                : '',
            'kullanici': tx['kullanici']?.toString() ?? '-',
          };

          if (expandable && searchTokens.isNotEmpty) {
            final haystack = _normalizeArama(
              [
                ...cells.values,
                tx['tutar_num']?.toString() ?? '',
                tx['kur']?.toString() ?? '',
                tx['belge_no']?.toString() ?? '',
                integrationRef,
              ].join(' '),
            );
            final bool matchesInMain = searchTokens.every(
              (token) => haystack.contains(token),
            );
            if (!matchesInMain) {
              extra['matchedInHidden'] = true;
            }
          }

          return RaporSatiri(
            id: 'hareket_${tx['source_menu_index']}_${tx['id']}',
            cells: cells,
            expandable: expandable,
            sourceMenuIndex: (tx['source_menu_index'] as num?)?.toInt(),
            sourceSearchQuery: tx['source_search_query']?.toString(),
            amountValue: tutar,
            extra: extra.isEmpty ? const <String, dynamic>{} : extra,
            sortValues: {
              'islem': sunum.islem,
              'yer': tx['yer'],
              'yer_kodu': tx['yer_kodu'],
              'yer_adi': tx['yer_adi'],
              'tarih': tarih,
              'tutar': tutar,
              'belge': tx['belge_no'],
              'e_belge': tx['e_belge'],
              'irsaliye_no': tx['irsaliye_no'],
              'fatura_no': tx['fatura_no'],
              'aciklama': sunum.aciklama,
              'aciklama_2': sunum.aciklama2,
              'vade_tarihi': vade,
              'kullanici': tx['kullanici'],
              'yer_2': tx['yer_2'],
            },
          );
        })
        .toList(growable: false);

    final summaryKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler,
      arama: arama,
    );
    final summaryCardsFuture = _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final totalCount = await _queryCount(
          pool,
          'SELECT COUNT(*) FROM ($baseQuery) sayim',
          params,
        );
        return <RaporOzetKarti>[
          RaporOzetKarti(
            labelKey: 'reports.summary.record',
            value: totalCount.toString(),
            icon: Icons.alt_route_rounded,
            accentColor: AppPalette.slate,
          ),
        ];
      },
    );

    // "İşlem" filter dropdown seçenekleri seçimden bağımsız olmalı (Cari Kart gibi):
    // Seçilen işlem sadece tabloyu filtrelesin, dropdown tüm işlem türlerini ve adetlerini
    // göstermeye devam etsin. Bu yüzden cacheKey'de işlem filtresini yok sayıyoruz.
    final islemToplamlariKey = _summaryCacheKey(
      reportId: rapor.id,
      filtreler: filtreler.copyWith(clearIslemTuru: true),
      arama: arama,
    );
    final islemToplamlariFuture = _getOrComputeIslemToplamlari(
      cacheKey: islemToplamlariKey,
      loader: () async {
        final List<String> totalsBaseWhere = <String>[
          if (belgeWhere(alias: 'u') != null) belgeWhere(alias: 'u')!,
          if (eBelgeWhere(alias: 'u') != null) eBelgeWhere(alias: 'u')!,
        ];
        final String totalsBaseWhereSql = totalsBaseWhere.isEmpty
            ? ''
            : 'WHERE ${totalsBaseWhere.join(' AND ')}';

        final List<String> totalsOuterWhere = <String>[
          'display_islem IS NOT NULL',
          'TRIM(display_islem) <> \'\'',
          'display_islem <> \'-\'',
        ];
        final String totalsOuterWhereSql =
            'WHERE ${totalsOuterWhere.join(' AND ')}';

        final rows = await _queryMaps(pool, '''
          WITH base AS (
            SELECT
              u.*,
              LOWER(COALESCE(u.islem, '')) AS low_islem,
              LOWER(COALESCE(u.integration_ref, '')) AS low_ref,
              LOWER(COALESCE(u.yon, '')) AS low_yon,
              LOWER(COALESCE(u.aciklama, '')) AS low_aciklama,
              LOWER(COALESCE(u.yer, '')) AS low_yer
            FROM ($unionQuery) u
            $totalsBaseWhereSql
          ),
          flags AS (
            SELECT
              base.*,
              (
                base.low_islem LIKE '%çek%' OR
                base.low_islem LIKE '%cek%' OR
                base.low_ref LIKE 'cheque%' OR
                base.low_ref LIKE 'cek-%'
              ) AS is_check,
              (
                base.low_islem LIKE '%senet%' OR
                base.low_ref LIKE 'note%' OR
                base.low_ref LIKE 'senet-%' OR
                base.low_ref LIKE '%promissory%'
              ) AS is_note,
              (
                base.low_ref LIKE 'sale-%' OR
                base.low_ref LIKE 'retail-%'
              ) AS is_sale_ref,
              (base.low_ref LIKE 'purchase-%') AS is_purchase_ref,
              (
                base.low_ref LIKE 'cari-pav-cash-%' OR
                base.low_ref LIKE 'cari-pav-bank-%' OR
                base.low_ref LIKE 'cari-pav-credit_card-%'
              ) AS is_cari_payment_ref,
              (
                TRIM(base.low_islem) IN (
                  'kasa',
                  'banka',
                  'kredi kartı',
                  'kredi karti'
                )
              ) AS is_cari_finans_source_type,
              (base.low_ref LIKE 'retail-%') AS is_retail_ref,
              (
                base.low_yon LIKE '%alacak%' OR
                base.low_islem LIKE '%tahsilat%' OR
                base.low_islem LIKE '%alış%' OR
                base.low_islem LIKE '%alis%' OR
                base.low_islem LIKE '%girdi%' OR
                base.low_islem LIKE '%giriş%' OR
                base.low_islem LIKE '%giris%' OR
                base.low_islem LIKE '%alındı%' OR
                base.low_islem LIKE '%alindi%' OR
                base.low_islem LIKE '%alınan%' OR
                base.low_islem LIKE '%alinan%'
              ) AS cari_is_incoming,
              (
                base.low_islem LIKE '%tahsil%' OR
                base.low_islem LIKE '%girdi%' OR
                base.low_islem LIKE '%giriş%' OR
                base.low_islem LIKE '%giris%' OR
                base.low_islem LIKE '%havale%' OR
                base.low_islem LIKE '%eft%'
              ) AS finans_is_incoming,
              (
                base.low_islem LIKE '%ödeme%' OR
                base.low_islem LIKE '%odeme%' OR
                base.low_islem LIKE '%harcama%' OR
                base.low_islem LIKE '%çıktı%' OR
                base.low_islem LIKE '%cikti%' OR
                base.low_islem LIKE '%çıkış%' OR
                base.low_islem LIKE '%cikis%'
              ) AS finans_is_outgoing
            FROM base
          )
          SELECT
            display_islem,
            COUNT(*) AS adet,
            SUM(tutar_num) AS toplam
          FROM (
            SELECT
              CASE
                WHEN flags.source_menu_index = ${TabAciciScope.cariKartiIndex} THEN
                  CASE
                    WHEN flags.is_cari_payment_ref OR flags.is_cari_finans_source_type THEN
                      CASE WHEN flags.cari_is_incoming THEN 'Para Alındı' ELSE 'Para Verildi' END
                    WHEN flags.is_sale_ref THEN 'Satış Yapıldı'
                    WHEN flags.is_purchase_ref THEN 'Alış Yapıldı'
                    WHEN flags.is_check OR flags.is_note THEN
                      CASE
                        WHEN flags.guncel_durum = 'Ciro Edildi' THEN
                          CASE
                            WHEN flags.is_check THEN 'Çek Alındı (Ciro Edildi)'
                            ELSE 'Senet Alındı (Ciro Edildi)'
                          END
                        WHEN flags.guncel_durum IN ('Tahsil Edildi', 'Ödendi') THEN
                          CASE
                            WHEN flags.is_check THEN
                              CASE
                                WHEN flags.cari_is_incoming THEN 'Çek Alındı (' || flags.guncel_durum || ')'
                                ELSE 'Çek Verildi (' || flags.guncel_durum || ')'
                              END
                            ELSE
                              CASE
                                WHEN flags.cari_is_incoming THEN 'Senet Alındı (' || flags.guncel_durum || ')'
                                ELSE 'Senet Verildi (' || flags.guncel_durum || ')'
                              END
                          END
                        WHEN flags.is_check THEN
                          CASE WHEN flags.cari_is_incoming THEN 'Çek Alındı' ELSE 'Çek Verildi' END
                        ELSE
                          CASE WHEN flags.cari_is_incoming THEN 'Senet Alındı' ELSE 'Senet Verildi' END
                      END
                    ELSE
                      CASE
                        WHEN TRIM(flags.low_islem) IN ('borç', 'borc') THEN 'Cari Borç'
                        WHEN TRIM(flags.low_islem) = 'alacak' THEN 'Cari Alacak'
                        WHEN (
                          (flags.low_islem LIKE '%açılış%' OR flags.low_islem LIKE '%acilis%') AND
                          (flags.low_islem LIKE '%devir%' OR flags.low_islem LIKE '%devri%')
                        ) THEN
                          CASE
                            WHEN flags.low_islem LIKE '%alacak%' THEN 'Açılış Alacak Devri'
                            WHEN flags.low_islem LIKE '%borç%' OR flags.low_islem LIKE '%borc%' THEN 'Açılış Borç Devri'
                            ELSE COALESCE(flags.islem, '-')
                          END
                        WHEN (
                          flags.low_islem LIKE '%tahsilat%' OR
                          flags.low_islem LIKE '%girdi%' OR
                          flags.low_islem LIKE '%giriş%' OR
                          flags.low_islem LIKE '%giris%' OR
                          flags.low_islem = 'para alındı' OR
                          flags.low_islem = 'para alindi'
                        ) THEN 'Para Alındı'
                        WHEN (
                          flags.low_islem LIKE '%ödeme%' OR
                          flags.low_islem LIKE '%odeme%' OR
                          flags.low_islem LIKE '%çıktı%' OR
                          flags.low_islem LIKE '%çıkış%' OR
                          flags.low_islem = 'para verildi'
                        ) THEN 'Para Verildi'
                        WHEN flags.low_islem LIKE '%borç dekontu%' OR flags.low_islem LIKE '%borc dekontu%' THEN 'Borç Dekontu'
                        WHEN flags.low_islem LIKE '%alacak dekontu%' THEN 'Alacak Dekontu'
                        WHEN flags.low_islem LIKE '%satış yapıldı%' OR flags.low_islem LIKE '%satis yapildi%' THEN 'Satış Yapıldı'
                        WHEN flags.low_islem LIKE '%alış yapıldı%' OR flags.low_islem LIKE '%alis yapildi%' THEN 'Alış Yapıldı'
                        WHEN flags.low_islem LIKE '%satış%' OR flags.low_islem LIKE '%satis%' THEN 'Satış Faturası'
                        WHEN flags.low_islem LIKE '%alış%' OR flags.low_islem LIKE '%alis%' THEN 'Alış Faturası'
                        WHEN COALESCE(TRIM(flags.yon), '-') <> '' THEN
                          CASE WHEN flags.cari_is_incoming THEN 'Para Alındı' ELSE 'Para Verildi' END
                        ELSE COALESCE(flags.islem, '-')
                      END
                  END
                WHEN flags.source_menu_index IN (13, 15, 16) THEN
                  CASE
                    WHEN flags.is_sale_ref AND NOT flags.is_retail_ref THEN 'Satış Yapıldı'
                    WHEN flags.is_purchase_ref THEN 'Alış Yapıldı'
                    WHEN (
                      flags.low_ref = 'opening_stock' OR
                      flags.low_ref LIKE '%opening_stock%' OR
                      flags.low_aciklama LIKE '%açılış%' OR
                      flags.low_aciklama LIKE '%acilis%'
                    ) THEN 'Açılış Stoğu'
                    WHEN (
                      flags.low_ref LIKE '%production%' OR
                      flags.low_aciklama LIKE '%üretim%' OR
                      flags.low_aciklama LIKE '%uretim%'
                    ) THEN 'Üretim'
                    WHEN (
                      flags.low_ref LIKE '%transfer%' OR
                      flags.low_aciklama LIKE '%devir%'
                    ) THEN 'Devir'
                    WHEN flags.source_menu_index <> 13 AND flags.low_ref LIKE '%collection%' THEN 'Tahsilat'
                    WHEN flags.source_menu_index <> 13 AND flags.low_ref LIKE '%payment%' THEN 'Ödeme'
                    WHEN flags.is_check THEN
                      CASE
                        WHEN (
                          CASE
                            WHEN flags.finans_is_incoming THEN TRUE
                            WHEN flags.finans_is_outgoing THEN FALSE
                            ELSE FALSE
                          END
                        ) THEN 'Çek Alındı (Tahsil Edildi)'
                        ELSE 'Çek Verildi (Ödendi)'
                      END
                    WHEN flags.is_note THEN
                      CASE
                        WHEN (
                          CASE
                            WHEN flags.finans_is_incoming THEN TRUE
                            WHEN flags.finans_is_outgoing THEN FALSE
                            ELSE FALSE
                          END
                        ) THEN 'Senet Alındı (Tahsil Edildi)'
                        ELSE 'Senet Verildi (Ödendi)'
                      END
                    ELSE
                      CASE
                        WHEN (
                          NOT (
                            CASE
                              WHEN flags.finans_is_incoming THEN TRUE
                              WHEN flags.finans_is_outgoing THEN FALSE
                              ELSE FALSE
                            END
                          ) AND flags.low_yer LIKE '%personel%'
                        ) THEN 'Personel Ödemesi'
                        WHEN (
                          CASE
                            WHEN flags.finans_is_incoming THEN TRUE
                            WHEN flags.finans_is_outgoing THEN FALSE
                            ELSE FALSE
                          END
                        ) THEN 'Para Alındı'
                        ELSE 'Para Verildi'
                      END
                  END
                ELSE COALESCE(flags.islem, '-')
              END AS display_islem,
              flags.tutar_num
            FROM flags
          ) grouped
          $totalsOuterWhereSql
          GROUP BY display_islem
          HAVING SUM(tutar_num) <> 0
          ORDER BY normalize_text(display_islem)
        ''', params);

        return rows
            .map((row) {
              final rawLabel = row['display_islem']?.toString() ?? '-';
              final toplam = _toDouble(row['toplam']);
              final adet = _toInt(row['adet']) ?? 0;
              return RaporIslemToplami(
                rawIslem: rawLabel,
                islem: IslemCeviriYardimcisi.cevir(rawLabel),
                tutar: _formatMoney(toplam),
                adet: adet,
              );
            })
            .where((item) => item.islem.trim().isNotEmpty && item.islem != '-')
            .toList(growable: false);
      },
    );

    final summaryCards = await summaryCardsFuture;
    final islemToplamlari = await islemToplamlariFuture;

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('islem', 'reports.columns.process_exact', 260),
        _column('yer', 'reports.columns.place_exact', 60),
        _column('yer_kodu', 'reports.columns.place_code_exact', 80),
        _column('yer_adi', 'reports.columns.place_name_exact', 100),
        _column('tarih', 'reports.columns.date_exact', 150),
        _column(
          'tutar',
          'reports.columns.amount_exact',
          80,
          alignment: Alignment.centerRight,
        ),
        _column('kur', 'reports.columns.exchange_rate_exact', 50),
        _column('yer_2', 'reports.columns.place_exact', 50),
        _column('belge', 'reports.columns.document_exact', 80),
        _column('e_belge', 'reports.columns.e_document_exact', 80),
        _column('irsaliye_no', 'reports.columns.waybill_no_exact', 80),
        _column('fatura_no', 'reports.columns.invoice_no_exact', 80),
        _column('aciklama', 'reports.columns.description_exact', 60),
        _column('aciklama_2', 'reports.columns.description_2_exact', 80),
        _column('vade_tarihi', 'reports.columns.due_date_exact', 70),
        _column('kullanici', 'reports.columns.user_exact', 60),
      ],
      rows: mappedRows,
      summaryCards: summaryCards,
      islemToplamlari: islemToplamlari,
      totalCount: 0,
      page: page,
      pageSize: pageSize,
      hasNextPage: pageResult.hasNextPage,
      cursorPagination: true,
      nextCursor: pageResult.nextCursor,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildCariTabanliRapor(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required _CariRaporModu mod,
  }) async {
    final List<Map<String, dynamic>> islemler = await _tumCariIslemleriniGetir(
      filtreler,
    );
    final List<Map<String, dynamic>> filtreli = islemler.where((item) {
      final rawType = item['islem_turu']?.toString() ?? '';
      final bool isSale = _isSaleTransaction(rawType);
      final bool isPurchase = _isPurchaseTransaction(rawType);
      switch (mod) {
        case _CariRaporModu.satis:
          return isSale;
        case _CariRaporModu.alis:
          return isPurchase;
        case _CariRaporModu.karma:
          return isSale || isPurchase;
        case _CariRaporModu.ekstre:
          return true;
      }
    }).toList();

    final List<RaporSatiri> rows = filtreli.map((tx) {
      final cari = tx['__cari'] as CariHesapModel?;
      final double tutar = _toDouble(tx['tutar']);
      final bool isBorc = _isDebit(tx['yon']?.toString());
      final double runningBalance = _toDouble(tx['running_balance']);
      final detailItems = _extractDetailItems(tx['hareket_detaylari']);
      final sunum = _cariIslemSunumunuHazirla(tx);
      final String rawFaturaNo =
          tx['fatura_no']?.toString().replaceAll('-', '').trim() ?? '';
      final String rawIrsaliyeNo =
          tx['irsaliye_no']?.toString().replaceAll('-', '').trim() ?? '';
      String belgeNo = '-';
      if (rawFaturaNo.isNotEmpty && rawIrsaliyeNo.isNotEmpty) {
        belgeNo = 'İrsaliyeli Fatura';
      } else if (rawFaturaNo.isNotEmpty) {
        belgeNo = 'Fatura';
      } else if (rawIrsaliyeNo.isNotEmpty) {
        belgeNo = 'İrsaliye';
      }
      final String odemeTipi = _detectPaymentType(tx);
      final DateTime? tarih = _toDateTime(tx['tarih']);
      final DateTime? vade = _toDateTime(tx['vade_tarihi']);

      return RaporSatiri(
        id: 'cari_tx_${tx['id']}',
        cells: {
          'tarih': _formatDate(tarih, includeTime: true),
          'belge_no': belgeNo,
          'cari': cari == null ? '-' : '${cari.kodNo} - ${cari.adi}',
          'kalem_sayisi': detailItems.length.toString(),
          'ara_toplam': _formatMoney(
            tutar,
            currency: cari?.paraBirimi ?? 'TRY',
          ),
          'kdv': detailItems.isEmpty
              ? '-'
              : _formatMoney(
                  _sumKdv(detailItems),
                  currency: cari?.paraBirimi ?? 'TRY',
                ),
          'genel_toplam': _formatMoney(
            tutar,
            currency: cari?.paraBirimi ?? 'TRY',
          ),
          'odeme_turu': odemeTipi,
          'durum': isBorc
              ? tr('reports.badges.debit')
              : tr('reports.badges.credit'),
          'kullanici': tx['kullanici']?.toString() ?? '-',
          'islem': IslemCeviriYardimcisi.cevir(sunum.islem),
          'tutar': _formatMoney(tutar, currency: cari?.paraBirimi ?? 'TRY'),
          'bakiye_borc': runningBalance > 0
              ? _formatMoney(
                  runningBalance,
                  currency: cari?.paraBirimi ?? 'TRY',
                )
              : '-',
          'bakiye_alacak': runningBalance < 0
              ? _formatMoney(
                  runningBalance.abs(),
                  currency: cari?.paraBirimi ?? 'TRY',
                )
              : '-',
          'ilgili_hesap': _firstNonEmpty([
            tx['kaynak_adi']?.toString(),
            tx['kaynak_kodu']?.toString(),
            '-',
          ]),
          'aciklama': sunum.aciklama,
          'vade': _formatDate(vade),
        },
        details: {
          tr('common.description'): sunum.aciklama,
          tr('common.transaction_type'): IslemCeviriYardimcisi.cevir(
            sunum.islem,
          ),
          tr('common.related_account'): _firstNonEmpty([
            tx['kaynak_adi']?.toString(),
            tx['kaynak_kodu']?.toString(),
            '-',
          ]),
        },
        detailTable: detailItems.isEmpty
            ? null
            : _detailTableFromItems(detailItems, title: tr('common.products')),
        expandable: detailItems.isNotEmpty,
        sourceMenuIndex: mod == _CariRaporModu.ekstre
            ? TabAciciScope.cariKartiIndex
            : 9,
        sourceSearchQuery: cari?.adi,
        amountValue: tutar,
        sortValues: {
          'tarih': tarih,
          'belge_no': belgeNo,
          'cari': cari?.adi,
          'genel_toplam': tutar,
          'tutar': tutar,
          'bakiye_borc': runningBalance > 0 ? runningBalance : 0.0,
          'bakiye_alacak': runningBalance < 0 ? runningBalance.abs() : 0.0,
          'islem': sunum.islem,
          'aciklama': sunum.aciklama,
        },
        extra: {
          'cariModel': cari,
          'integrationRef': tx['integration_ref'],
          'vadeTarihi': vade,
        },
      );
    }).toList();

    final columns = switch (mod) {
      _CariRaporModu.satis ||
      _CariRaporModu.alis ||
      _CariRaporModu.karma => <RaporKolonTanimi>[
        _column('tarih', 'common.date', 150),
        _column('belge_no', 'reports.columns.document_no', 130),
        _column('cari', 'reports.columns.current_account', 220),
        _column(
          'kalem_sayisi',
          'reports.columns.item_count',
          90,
          alignment: Alignment.centerRight,
        ),
        _column(
          'ara_toplam',
          'common.subtotal',
          140,
          alignment: Alignment.centerRight,
        ),
        _column(
          'kdv',
          'common.vat_amount',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'genel_toplam',
          'reports.columns.grand_total',
          140,
          alignment: Alignment.centerRight,
        ),
        _column('odeme_turu', 'reports.columns.payment_type', 120),
        _column('durum', 'common.status', 110),
        _column('kullanici', 'common.user', 110),
      ],
      _CariRaporModu.ekstre => <RaporKolonTanimi>[
        _column('islem', 'common.operation', 180),
        _column('tarih', 'common.date', 150),
        _column(
          'tutar',
          'common.amount',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'bakiye_borc',
          'accounts.balance.debit_label',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'bakiye_alacak',
          'accounts.balance.credit_label',
          130,
          alignment: Alignment.centerRight,
        ),
        _column('ilgili_hesap', 'common.related_account', 180),
        _column('aciklama', 'common.description', 220),
        _column('vade', 'common.due_date_short', 110),
        _column('kullanici', 'common.user', 100),
      ],
    };

    final String paraBirimi =
        (filtreli.firstOrNull?['__cari'] as CariHesapModel?)?.paraBirimi ??
        'TRY';

    final double toplam = filtreli.fold<double>(
      0.0,
      (sum, item) => sum + _toDouble(item['tutar']),
    );

    final summary = <RaporOzetKarti>[
      RaporOzetKarti(
        labelKey: mod == _CariRaporModu.satis
            ? 'reports.summary.total_sales'
            : mod == _CariRaporModu.alis
            ? 'reports.summary.total_purchases'
            : mod == _CariRaporModu.karma
            ? 'reports.summary.total_movements'
            : 'reports.summary.total_movements',
        value: _formatMoney(toplam, currency: paraBirimi),
        icon: mod == _CariRaporModu.alis
            ? Icons.shopping_cart_checkout_rounded
            : Icons.point_of_sale_rounded,
        accentColor: mod == _CariRaporModu.alis
            ? AppPalette.amber
            : AppPalette.red,
        subtitle: '${rows.length} ${tr('reports.summary.record')}',
      ),
      if (mod == _CariRaporModu.satis ||
          mod == _CariRaporModu.alis ||
          mod == _CariRaporModu.karma)
        RaporOzetKarti(
          labelKey: 'reports.summary.average_receipt',
          value: rows.isEmpty
              ? _formatMoney(0, currency: paraBirimi)
              : _formatMoney(toplam / rows.length, currency: paraBirimi),
          icon: Icons.receipt_long_outlined,
          accentColor: AppPalette.slate,
        ),
      if (mod == _CariRaporModu.ekstre)
        RaporOzetKarti(
          labelKey: 'reports.summary.net_balance',
          value: _formatMoney(
            rows.fold<double>(
              0.0,
              (sum, row) =>
                  sum +
                  _toDouble(row.sortValues['bakiye_borc']) -
                  _toDouble(row.sortValues['bakiye_alacak']),
            ),
            currency: paraBirimi,
          ),
          icon: Icons.account_balance_wallet_outlined,
          accentColor: AppPalette.slate,
        ),
    ];

    return RaporSonucu(
      report: rapor,
      columns: columns,
      rows: rows,
      summaryCards: summary,
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
      detailTableLabel: tr('common.products'),
    );
  }

  Future<RaporSonucu> _buildFinansHareketRaporu(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required _FinansRaporModu mod,
  }) async {
    final List<Map<String, dynamic>> hareketler = switch (mod) {
      _FinansRaporModu.kasa => await _tumKasaIslemleriniGetir(filtreler),
      _FinansRaporModu.banka => await _tumBankaIslemleriniGetir(filtreler),
      _FinansRaporModu.krediKarti => await _tumKrediKartiIslemleriniGetir(
        filtreler,
      ),
    };

    final List<RaporSatiri> rows = hareketler.map((tx) {
      final String hesapAdi = switch (mod) {
        _FinansRaporModu.kasa =>
          (tx['__kasa'] as KasaModel?)?.ad ?? tx['kasaAdi']?.toString() ?? '-',
        _FinansRaporModu.banka =>
          (tx['__banka'] as BankaModel?)?.ad ??
              tx['bankaAdi']?.toString() ??
              '-',
        _FinansRaporModu.krediKarti =>
          (tx['__kart'] as KrediKartiModel?)?.ad ??
              tx['krediKartiAdi']?.toString() ??
              '-',
      };
      final String hesapKod = switch (mod) {
        _FinansRaporModu.kasa =>
          (tx['__kasa'] as KasaModel?)?.kod ?? tx['kasaKodu']?.toString() ?? '',
        _FinansRaporModu.banka =>
          (tx['__banka'] as BankaModel?)?.kod ??
              tx['bankaKodu']?.toString() ??
              '',
        _FinansRaporModu.krediKarti =>
          (tx['__kart'] as KrediKartiModel?)?.kod ??
              tx['krediKartiKodu']?.toString() ??
              '',
      };
      final DateTime? tarih = _toDateTime(tx['tarih']);
      final double tutar = _toDouble(tx['tutar']);
      final bool incoming = tx['isIncoming'] == true;
      final sunum = _finansIslemSunumunuHazirla(tx, mod: mod);

      return RaporSatiri(
        id: 'fin_${tx['id']}_${mod.name}',
        cells: {
          'tarih': _formatDate(tarih, includeTime: true),
          'hesap': '$hesapKod - $hesapAdi'.trim(),
          'islem': IslemCeviriYardimcisi.cevir(sunum.islem),
          'ilgili_hesap': _firstNonEmpty([
            tx['yerAdi']?.toString(),
            tx['yerKodu']?.toString(),
            tx['yer']?.toString(),
            '-',
          ]),
          'giris': incoming ? _formatMoney(tutar) : '-',
          'cikis': incoming ? '-' : _formatMoney(tutar),
          'aciklama': sunum.aciklama,
          'kullanici': tx['kullanici']?.toString() ?? '-',
        },
        details: {
          tr('reports.columns.account_name'): hesapAdi,
          tr('reports.columns.account_code'): hesapKod,
          tr('reports.columns.reference'):
              tx['integration_ref']?.toString() ?? '-',
        },
        sourceMenuIndex: switch (mod) {
          _FinansRaporModu.kasa => 13,
          _FinansRaporModu.banka => 15,
          _FinansRaporModu.krediKarti => 16,
        },
        sourceSearchQuery: hesapAdi,
        amountValue: incoming ? tutar : -tutar,
        sortValues: {
          'tarih': tarih,
          'hesap': hesapAdi,
          'islem': sunum.islem,
          'giris': incoming ? tutar : 0.0,
          'cikis': incoming ? 0.0 : tutar,
          'aciklama': sunum.aciklama,
        },
      );
    }).toList();

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tarih', 'common.date', 150),
        _column('hesap', 'reports.columns.account_name', 220),
        _column('islem', 'common.transaction_type', 180),
        _column('ilgili_hesap', 'common.related_account', 180),
        _column(
          'giris',
          'reports.columns.incoming',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'cikis',
          'reports.columns.outgoing',
          120,
          alignment: Alignment.centerRight,
        ),
        _column('aciklama', 'common.description', 220),
        _column('kullanici', 'common.user', 100),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.total_incoming',
          value: _formatMoney(
            rows.fold<double>(
              0.0,
              (sum, row) => sum + _toDouble(row.sortValues['giris']),
            ),
          ),
          icon: Icons.call_received_rounded,
          accentColor: const Color(0xFF27AE60),
        ),
        RaporOzetKarti(
          labelKey: 'reports.summary.total_outgoing',
          value: _formatMoney(
            rows.fold<double>(
              0.0,
              (sum, row) => sum + _toDouble(row.sortValues['cikis']),
            ),
          ),
          icon: Icons.call_made_rounded,
          accentColor: AppPalette.red,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildCekSenetRaporu(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required bool cekMi,
  }) async {
    final List<dynamic> liste = cekMi
        ? await _cekServisi.cekleriGetir(
            sayfaBasinaKayit: 5000,
            baslangicTarihi: filtreler.baslangicTarihi,
            bitisTarihi: filtreler.bitisTarihi,
          )
        : await _senetServisi.senetleriGetir(
            sayfaBasinaKayit: 5000,
            baslangicTarihi: filtreler.baslangicTarihi,
            bitisTarihi: filtreler.bitisTarihi,
          );

    final List<dynamic> filtreli = liste.where((item) {
      final bool durumOk =
          filtreler.durum == null ||
          filtreler.durum!.trim().isEmpty ||
          filtreler.durum == tr('common.all') ||
          _statusText(
            item,
          ).toLowerCase().contains(filtreler.durum!.toLowerCase());
      final bool belgeOk =
          filtreler.belgeNo == null ||
          filtreler.belgeNo!.trim().isEmpty ||
          _documentNo(
            item,
            cekMi: cekMi,
          ).toLowerCase().contains(filtreler.belgeNo!.toLowerCase());
      return durumOk && belgeOk;
    }).toList();

    final List<RaporSatiri> rows = filtreli.map((item) {
      final DateTime? vade = _toDateTime(item.kesideTarihi);
      final String belgeNo = _documentNo(item, cekMi: cekMi);
      final bool aktif = item.aktifMi == true;

      return RaporSatiri(
        id: '${cekMi ? 'cek' : 'senet'}_${item.id}',
        cells: {
          'tur': IslemCeviriYardimcisi.cevir(item.tur?.toString() ?? '-'),
          'belge_no': belgeNo,
          'cari': item.cariAdi?.toString() ?? '-',
          'vade': _formatDate(vade),
          'tutar': _formatMoney(item.tutar, currency: item.paraBirimi ?? 'TRY'),
          'durum': aktif ? tr('common.active') : tr('common.passive'),
          'portfoy': item.banka?.toString() ?? '-',
          'kullanici': item.kullanici?.toString() ?? '-',
        },
        details: {
          tr('common.description'): item.aciklama?.toString() ?? '-',
          tr('reports.columns.collection_type'):
              item.tahsilat?.toString() ?? '-',
          tr('reports.columns.issue_date'): _formatDate(
            _toDateTime(item.duzenlenmeTarihi),
          ),
        },
        sourceMenuIndex: cekMi ? 14 : 17,
        sourceSearchQuery: belgeNo,
        amountValue: _toDouble(item.tutar),
        sortValues: {
          'tur': item.tur?.toString(),
          'belge_no': belgeNo,
          'cari': item.cariAdi?.toString(),
          'vade': vade,
          'tutar': _toDouble(item.tutar),
          'durum': aktif ? 1 : 0,
        },
      );
    }).toList();

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tur', 'common.type', 120),
        _column('belge_no', 'reports.columns.document_no', 140),
        _column('cari', 'reports.columns.current_account', 220),
        _column('vade', 'common.due_date_short', 120),
        _column(
          'tutar',
          'common.amount',
          130,
          alignment: Alignment.centerRight,
        ),
        _column('durum', 'common.status', 100),
        _column('portfoy', 'reports.columns.portfolio', 140),
        _column('kullanici', 'common.user', 100),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.portfolio_total',
          value: _formatMoney(
            rows.fold<double>(0.0, (sum, row) => sum + (row.amountValue ?? 0)),
          ),
          icon: Icons.receipt_long_outlined,
          accentColor: cekMi ? AppPalette.slate : AppPalette.amber,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildGiderRaporu(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler,
  ) async {
    final List<GiderModel> giderler = await _giderServisi.giderleriGetir(
      sayfaBasinaKayit: 5000,
      kategori: _emptyToNull(filtreler.referansNo),
      odemeDurumu: _normalizedSelection(filtreler.durum),
      baslangicTarihi: filtreler.baslangicTarihi,
      bitisTarihi: filtreler.bitisTarihi,
      kullanici: _emptyToNull(filtreler.kullaniciId),
    );

    final List<GiderModel> filtreli = giderler.where((gider) {
      final bool amountOk = _matchesDoubleRange(
        _toDouble(gider.tutar),
        min: filtreler.minTutar,
        max: filtreler.maxTutar,
      );
      return amountOk;
    }).toList();

    final List<RaporSatiri> rows = filtreli.map((gider) {
      return RaporSatiri(
        id: 'gider_${gider.id}',
        cells: {
          'tarih': _formatDate(gider.tarih, includeTime: true),
          'kod': gider.kod,
          'kalem': gider.baslik,
          'kategori': gider.kategori,
          'tutar': _formatMoney(gider.tutar, currency: gider.paraBirimi),
          'odeme_tipi': gider.odemeDurumu,
          'cari': '-',
          'aciklama': gider.aciklama.isNotEmpty ? gider.aciklama : '-',
          'kullanici': gider.kullanici,
        },
        details: {
          tr('common.description'): gider.aciklama.isNotEmpty
              ? gider.aciklama
              : '-',
          tr('reports.columns.notes'): gider.not.isNotEmpty ? gider.not : '-',
          tr('reports.columns.item_count'): gider.kalemler.length.toString(),
        },
        detailTable: gider.kalemler.isEmpty
            ? null
            : DetailTable(
                title: tr('reports.detail.expense_items'),
                headers: [
                  tr('common.name'),
                  tr('common.quantity'),
                  tr('common.unit_price'),
                  tr('common.amount'),
                ],
                data: gider.kalemler
                    .map(
                      (e) => [
                        e.aciklama,
                        '1',
                        _formatMoney(e.tutar, currency: gider.paraBirimi),
                        _formatMoney(e.tutar, currency: gider.paraBirimi),
                      ],
                    )
                    .toList(),
              ),
        expandable: gider.kalemler.isNotEmpty,
        sourceMenuIndex: 100,
        amountValue: gider.tutar,
        sortValues: {
          'tarih': gider.tarih,
          'kod': gider.kod,
          'kalem': gider.baslik,
          'kategori': gider.kategori,
          'tutar': gider.tutar,
        },
      );
    }).toList();

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tarih', 'common.date', 150),
        _column('kod', 'common.code', 120),
        _column('kalem', 'reports.columns.expense_item', 220),
        _column('kategori', 'reports.columns.category', 160),
        _column(
          'tutar',
          'common.amount',
          130,
          alignment: Alignment.centerRight,
        ),
        _column('odeme_tipi', 'reports.columns.payment_type', 130),
        _column('cari', 'reports.columns.current_account', 180),
        _column('aciklama', 'common.description', 220),
        _column('kullanici', 'common.user', 100),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.total_expense',
          value: _formatMoney(
            rows.fold<double>(0.0, (sum, row) => sum + (row.amountValue ?? 0)),
          ),
          icon: Icons.money_off_csred_outlined,
          accentColor: AppPalette.red,
        ),
        RaporOzetKarti(
          labelKey: 'reports.summary.category_count',
          value: filtreli
              .map((e) => e.kategori.trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .length
              .toString(),
          icon: Icons.category_outlined,
          accentColor: AppPalette.amber,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
      detailTableLabel: tr('reports.detail.expense_items'),
    );
  }

  Future<RaporSonucu> _buildUretimRaporu(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler,
  ) async {
    final List<UretimModel> uretimler = await _uretimServisi.uretimleriGetir(
      sayfaBasinaKayit: 5000,
    );
    final List<UretimModel> filtreli = uretimler.where((item) {
      final bool urunOk =
          filtreler.urunKodu == null ||
          filtreler.urunKodu!.isEmpty ||
          item.kod == filtreler.urunKodu;
      final bool grupOk =
          filtreler.urunGrubu == null ||
          filtreler.urunGrubu!.isEmpty ||
          item.grubu == filtreler.urunGrubu;
      final bool durumOk =
          filtreler.durum == null ||
          filtreler.durum == tr('common.all') ||
          (filtreler.durum == tr('common.active') && item.aktifMi) ||
          (filtreler.durum == tr('common.passive') && !item.aktifMi);
      return urunOk && grupOk && durumOk;
    }).toList();

    final List<RaporSatiri> rows = filtreli.map((item) {
      return RaporSatiri(
        id: 'uretim_${item.id}',
        cells: {
          'tarih': _formatDate(item.createdAt, includeTime: true),
          'belge_no': item.kod,
          'urun': item.ad,
          'miktar': _formatNumber(item.stok),
          'maliyet': _formatMoney(item.alisFiyati),
          'depo': '-',
          'durum': item.aktifMi ? tr('common.active') : tr('common.passive'),
          'kullanici': item.kullanici,
        },
        details: {
          tr('common.barcode'): item.barkod.isEmpty ? '-' : item.barkod,
          tr('reports.columns.group'): item.grubu,
          tr('reports.columns.features'): item.ozellikler.isEmpty
              ? '-'
              : item.ozellikler,
        },
        sourceMenuIndex: 8,
        sourceSearchQuery: item.ad,
        amountValue: item.alisFiyati,
        sortValues: {
          'tarih': item.createdAt,
          'belge_no': item.kod,
          'urun': item.ad,
          'miktar': item.stok,
          'maliyet': item.alisFiyati,
          'durum': item.aktifMi ? 1 : 0,
        },
      );
    }).toList();

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tarih', 'common.date', 150),
        _column('belge_no', 'reports.columns.production_no', 130),
        _column('urun', 'common.product', 220),
        _column(
          'miktar',
          'common.quantity',
          100,
          alignment: Alignment.centerRight,
        ),
        _column(
          'maliyet',
          'reports.columns.cost_output',
          130,
          alignment: Alignment.centerRight,
        ),
        _column('depo', 'common.warehouse', 120),
        _column('durum', 'common.status', 100),
        _column('kullanici', 'common.user', 100),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.total_products',
          value: rows.length.toString(),
          icon: Icons.precision_manufacturing_outlined,
          accentColor: AppPalette.slate,
        ),
        RaporOzetKarti(
          labelKey: 'reports.summary.stock_total',
          value: _formatNumber(
            filtreli.fold<double>(0.0, (sum, row) => sum + row.stok),
          ),
          icon: Icons.inventory_rounded,
          accentColor: AppPalette.amber,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildUrunHareketleri(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler,
  ) async {
    final List<UrunModel> urunler = await _filteredProducts(filtreler);
    final List<Map<String, dynamic>> rawRows =
        await _collectInBatches<UrunModel, Map<String, dynamic>>(urunler, (
          urun,
        ) async {
          final txs = await _urunServisi.urunHareketleriniGetir(
            urunId: urun.id,
            baslangicTarihi: filtreler.baslangicTarihi,
            bitisTarihi: filtreler.bitisTarihi,
            arama: _emptyToNull(filtreler.belgeNo),
          );
          return txs.map((tx) => {...tx, '__urun': urun}).toList();
        });

    final List<Map<String, dynamic>> filtreli = rawRows.where((tx) {
      final bool depoOk =
          filtreler.depoId == null ||
          tx['warehouse_id'] == filtreler.depoId ||
          tx['depo_id'] == filtreler.depoId ||
          true;
      final bool miktarOk = _matchesDoubleRange(
        _toDouble(tx['miktar']),
        min: filtreler.minMiktar,
        max: filtreler.maxMiktar,
      );
      return depoOk && miktarOk;
    }).toList();

    final List<RaporSatiri> rows = filtreli.map((tx) {
      final urun = tx['__urun'] as UrunModel?;
      final DateTime? tarih = _toDateTime(tx['tarih']);
      final double miktar = _toDouble(tx['miktar']);
      final double fiyat = _toDouble(tx['birim_fiyat']);
      final double tutar = _toDouble(tx['tutar']);
      final sunum = _stokIslemSunumunuHazirla(tx);

      return RaporSatiri(
        id: 'urun_hareket_${tx['id']}',
        cells: {
          'tarih': _formatDate(tarih, includeTime: true),
          'urun_kodu': urun?.kod ?? '-',
          'urun_adi': urun?.ad ?? '-',
          'islem': IslemCeviriYardimcisi.cevir(sunum.islem),
          'depo': tx['depo_adi']?.toString() ?? '-',
          'giris': miktar > 0 ? _formatNumber(miktar) : '-',
          'cikis': miktar < 0 ? _formatNumber(miktar.abs()) : '-',
          'birim': urun?.birim ?? '-',
          'maliyet': _formatMoney(fiyat),
          'ref': tx['integration_ref']?.toString() ?? '-',
          'kullanici': tx['kullanici']?.toString() ?? '-',
        },
        details: {
          tr('common.description'): sunum.aciklama,
          tr('reports.columns.running_total'): _formatMoney(tutar),
        },
        sourceMenuIndex: TabAciciScope.urunKartiIndex,
        sourceSearchQuery: urun?.ad,
        amountValue: tutar,
        sortValues: {
          'tarih': tarih,
          'urun_kodu': urun?.kod,
          'urun_adi': urun?.ad,
          'islem': sunum.islem,
          'giris': miktar > 0 ? miktar : 0.0,
          'cikis': miktar < 0 ? miktar.abs() : 0.0,
          'maliyet': fiyat,
        },
        extra: {'urunModel': urun},
      );
    }).toList();

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tarih', 'common.date', 150),
        _column('urun_kodu', 'common.code', 120),
        _column('urun_adi', 'common.product', 220),
        _column('islem', 'common.transaction_type', 180),
        _column('depo', 'common.warehouse', 120),
        _column(
          'giris',
          'reports.columns.incoming',
          100,
          alignment: Alignment.centerRight,
        ),
        _column(
          'cikis',
          'reports.columns.outgoing',
          100,
          alignment: Alignment.centerRight,
        ),
        _column('birim', 'common.unit', 90),
        _column(
          'maliyet',
          'reports.columns.cost',
          120,
          alignment: Alignment.centerRight,
        ),
        _column('ref', 'reports.columns.reference', 150),
        _column('kullanici', 'common.user', 100),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.total_incoming',
          value: _formatNumber(
            rows.fold<double>(
              0.0,
              (sum, row) => sum + _toDouble(row.sortValues['giris']),
            ),
          ),
          icon: Icons.call_received_rounded,
          accentColor: const Color(0xFF27AE60),
        ),
        RaporOzetKarti(
          labelKey: 'reports.summary.total_outgoing',
          value: _formatNumber(
            rows.fold<double>(
              0.0,
              (sum, row) => sum + _toDouble(row.sortValues['cikis']),
            ),
          ),
          icon: Icons.call_made_rounded,
          accentColor: AppPalette.red,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildUrunSevkiyatHareketleri(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler,
  ) async {
    final List<Map<String, dynamic>> sevkiyatlar =
        await _tumDepoIslemleriniGetir(filtreler);
    final List<RaporSatiri> rows = sevkiyatlar.map((item) {
      final DateTime? tarih = _toDateTime(item['date']);
      final List<Map<String, dynamic>> detailItems = _extractDetailItems(
        item['items'],
      );
      final double toplamMiktar = detailItems.fold<double>(
        0.0,
        (sum, e) => sum + _toDouble(e['quantity']),
      );

      return RaporSatiri(
        id: 'sevkiyat_${item['id']}',
        cells: {
          'tarih': _formatDate(tarih, includeTime: true),
          'no': item['integration_ref']?.toString() ?? '#${item['id']}',
          'kaynak': item['source_name']?.toString() ?? '-',
          'hedef': item['dest_name']?.toString() ?? '-',
          'urun': detailItems.isEmpty
              ? '-'
              : detailItems.first['name']?.toString() ?? '-',
          'miktar': _formatNumber(toplamMiktar),
          'durum': tr('common.active'),
          'kullanici': item['created_by']?.toString() ?? '-',
        },
        details: {
          tr('common.description'): item['description']?.toString() ?? '-',
          tr('reports.columns.item_count'): detailItems.length.toString(),
        },
        detailTable: detailItems.isEmpty
            ? null
            : _detailTableFromItems(detailItems, title: tr('common.products')),
        expandable: detailItems.isNotEmpty,
        sourceMenuIndex: 6,
        sourceSearchQuery: item['integration_ref']?.toString(),
        sortValues: {
          'tarih': tarih,
          'no': item['integration_ref']?.toString(),
          'kaynak': item['source_name']?.toString(),
          'hedef': item['dest_name']?.toString(),
          'miktar': toplamMiktar,
        },
      );
    }).toList();

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tarih', 'common.date', 150),
        _column('no', 'reports.columns.document_no', 140),
        _column('kaynak', 'reports.columns.source_warehouse', 160),
        _column('hedef', 'reports.columns.target_warehouse', 160),
        _column('urun', 'common.product', 220),
        _column(
          'miktar',
          'common.quantity',
          100,
          alignment: Alignment.centerRight,
        ),
        _column('durum', 'common.status', 100),
        _column('kullanici', 'common.user', 100),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.shipment_count',
          value: rows.length.toString(),
          icon: Icons.local_shipping_outlined,
          accentColor: AppPalette.slate,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
      detailTableLabel: tr('common.products'),
    );
  }

  Future<RaporSonucu> _buildDepoStokListesi(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler,
  ) async {
    final List<DepoModel> depolar = await _filteredDepolar(filtreler);
    final List<Map<String, dynamic>> rawRows =
        await _collectInBatches<DepoModel, Map<String, dynamic>>(depolar, (
          depo,
        ) async {
          final list = await _depoServisi.depoStoklariniListele(
            depo.id,
            aramaTerimi: _emptyToNull(filtreler.urunKodu),
            limit: 1000,
          );
          return list.map((item) => {...item, '__depo': depo}).toList();
        });

    final List<RaporSatiri> rows = rawRows
        .where((item) {
          final bool grupOk =
              filtreler.urunGrubu == null ||
              filtreler.urunGrubu!.isEmpty ||
              item['group']?.toString() == filtreler.urunGrubu;
          return grupOk;
        })
        .map((item) {
          final depo = item['__depo'] as DepoModel?;
          final double miktar = _toDouble(item['quantity']);
          return RaporSatiri(
            id: 'depo_stok_${depo?.id}_${item['product_code']}',
            cells: {
              'depo': depo == null ? '-' : '${depo.kod} - ${depo.ad}',
              'urun_kodu': item['product_code']?.toString() ?? '-',
              'urun_adi': item['product_name']?.toString() ?? '-',
              'birim': item['unit']?.toString() ?? '-',
              'stok': _formatNumber(miktar),
              'kritik_stok': '-',
              'durum': tr('common.active'),
              'maliyet': '-',
              'stok_degeri': '-',
            },
            details: {
              tr('reports.columns.group'): item['group']?.toString() ?? '-',
              tr('reports.columns.features'):
                  (item['features'] as List?)?.join(', ') ?? '-',
              tr('common.barcode'): item['barcode']?.toString() ?? '-',
            },
            sourceMenuIndex: 6,
            sourceSearchQuery: depo?.ad,
            sortValues: {
              'depo': depo?.ad,
              'urun_kodu': item['product_code']?.toString(),
              'urun_adi': item['product_name']?.toString(),
              'stok': miktar,
            },
          );
        })
        .toList();

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('depo', 'common.warehouse', 180),
        _column('urun_kodu', 'common.code', 120),
        _column('urun_adi', 'common.product', 220),
        _column('birim', 'common.unit', 90),
        _column(
          'stok',
          'reports.columns.stock',
          100,
          alignment: Alignment.centerRight,
        ),
        _column(
          'kritik_stok',
          'reports.columns.critical_stock',
          120,
          alignment: Alignment.centerRight,
        ),
        _column('durum', 'common.status', 100),
        _column(
          'maliyet',
          'reports.columns.cost',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'stok_degeri',
          'reports.columns.stock_value',
          130,
          alignment: Alignment.centerRight,
        ),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.total_stock_rows',
          value: rows.length.toString(),
          icon: Icons.warehouse_outlined,
          accentColor: AppPalette.slate,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildDepoSevkiyatListesi(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler,
  ) async {
    final List<Map<String, dynamic>> sevkiyatlar =
        await _tumDepoIslemleriniGetir(filtreler);
    final List<RaporSatiri> rows = sevkiyatlar.map((item) {
      final DateTime? tarih = _toDateTime(item['date']);
      final List<Map<String, dynamic>> detailItems = _extractDetailItems(
        item['items'],
      );
      final double toplamMiktar = detailItems.fold<double>(
        0.0,
        (sum, e) => sum + _toDouble(e['quantity']),
      );
      return RaporSatiri(
        id: 'depo_sevkiyat_${item['id']}',
        cells: {
          'tarih': _formatDate(tarih, includeTime: true),
          'no': item['integration_ref']?.toString() ?? '#${item['id']}',
          'depo': item['source_name']?.toString() ?? '-',
          'hedef': item['dest_name']?.toString() ?? '-',
          'kalem_sayisi': detailItems.length.toString(),
          'toplam_miktar': _formatNumber(toplamMiktar),
          'durum': tr('common.active'),
          'kullanici': item['created_by']?.toString() ?? '-',
        },
        details: {
          tr('common.description'): item['description']?.toString() ?? '-',
          tr('reports.columns.related_party'): _firstNonEmpty([
            item['related_party_name']?.toString(),
            '-',
          ]),
        },
        detailTable: detailItems.isEmpty
            ? null
            : _detailTableFromItems(detailItems, title: tr('common.products')),
        expandable: detailItems.isNotEmpty,
        sourceMenuIndex: 6,
        sourceSearchQuery: item['integration_ref']?.toString(),
        sortValues: {
          'tarih': tarih,
          'no': item['integration_ref']?.toString(),
          'depo': item['source_name']?.toString(),
          'hedef': item['dest_name']?.toString(),
          'kalem_sayisi': detailItems.length,
          'toplam_miktar': toplamMiktar,
        },
      );
    }).toList();

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tarih', 'common.date', 150),
        _column('no', 'reports.columns.document_no', 140),
        _column('depo', 'common.warehouse', 160),
        _column('hedef', 'reports.columns.target_warehouse', 160),
        _column(
          'kalem_sayisi',
          'reports.columns.item_count',
          100,
          alignment: Alignment.centerRight,
        ),
        _column(
          'toplam_miktar',
          'reports.columns.total_quantity',
          120,
          alignment: Alignment.centerRight,
        ),
        _column('durum', 'common.status', 100),
        _column('kullanici', 'common.user', 100),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.shipment_count',
          value: rows.length.toString(),
          icon: Icons.move_down_outlined,
          accentColor: AppPalette.amber,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
      detailTableLabel: tr('common.products'),
    );
  }

  Future<RaporSonucu> _buildStokErkenUyari(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler,
  ) async {
    final List<UrunModel> urunler = await _filteredProducts(filtreler);
    final List<UrunModel> filtreli = urunler
        .where((urun) => urun.stok <= urun.erkenUyariMiktari)
        .toList();

    final List<RaporSatiri> rows = filtreli.map((urun) {
      return RaporSatiri(
        id: 'stok_uyari_${urun.id}',
        cells: {
          'urun_kodu': urun.kod,
          'urun': urun.ad,
          'depo': '-',
          'mevcut_stok': _formatNumber(urun.stok),
          'kritik_stok': _formatNumber(urun.erkenUyariMiktari),
          'fark': _formatNumber(urun.stok - urun.erkenUyariMiktari),
          'son_hareket': '-',
        },
        details: {
          tr('reports.columns.group'): urun.grubu,
          tr('reports.columns.features'): urun.ozellikler.isEmpty
              ? '-'
              : urun.ozellikler,
        },
        sourceMenuIndex: TabAciciScope.urunKartiIndex,
        sourceSearchQuery: urun.ad,
        sortValues: {
          'urun_kodu': urun.kod,
          'urun': urun.ad,
          'mevcut_stok': urun.stok,
          'kritik_stok': urun.erkenUyariMiktari,
          'fark': urun.stok - urun.erkenUyariMiktari,
        },
        extra: {'urunModel': urun},
      );
    }).toList();

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('urun_kodu', 'common.code', 120),
        _column('urun', 'common.product', 220),
        _column('depo', 'common.warehouse', 140),
        _column(
          'mevcut_stok',
          'reports.columns.current_stock',
          110,
          alignment: Alignment.centerRight,
        ),
        _column(
          'kritik_stok',
          'reports.columns.critical_stock',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'fark',
          'common.difference',
          100,
          alignment: Alignment.centerRight,
        ),
        _column('son_hareket', 'reports.columns.last_movement', 140),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.critical_count',
          value: rows.length.toString(),
          icon: Icons.warning_amber_rounded,
          accentColor: AppPalette.red,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildStokTanimDegerleri(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler,
  ) async {
    final List<UrunModel> urunler = await _filteredProducts(filtreler);
    final List<RaporSatiri> rows = urunler.map((urun) {
      return RaporSatiri(
        id: 'stok_tanim_${urun.id}',
        cells: {
          'kod': urun.kod,
          'urun': urun.ad,
          'grup': urun.grubu,
          'birim': urun.birim,
          'alis': _formatMoney(urun.alisFiyati),
          'satis1': _formatMoney(urun.satisFiyati1),
          'satis2': _formatMoney(urun.satisFiyati2),
          'satis3': _formatMoney(urun.satisFiyati3),
          'vergi': '${_formatNumber(urun.kdvOrani)}%',
          'durum': urun.aktifMi ? tr('common.active') : tr('common.passive'),
        },
        details: {
          tr('common.barcode'): urun.barkod.isEmpty ? '-' : urun.barkod,
          tr('reports.columns.features'): urun.ozellikler.isEmpty
              ? '-'
              : urun.ozellikler,
        },
        sourceMenuIndex: TabAciciScope.urunKartiIndex,
        sourceSearchQuery: urun.ad,
        sortValues: {
          'kod': urun.kod,
          'urun': urun.ad,
          'grup': urun.grubu,
          'alis': urun.alisFiyati,
          'satis1': urun.satisFiyati1,
          'satis2': urun.satisFiyati2,
          'satis3': urun.satisFiyati3,
          'vergi': urun.kdvOrani,
          'durum': urun.aktifMi ? 1 : 0,
        },
        extra: {'urunModel': urun},
      );
    }).toList();

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('kod', 'common.code', 120),
        _column('urun', 'common.product', 220),
        _column('grup', 'reports.columns.group', 160),
        _column('birim', 'common.unit', 90),
        _column(
          'alis',
          'reports.columns.purchase_price',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'satis1',
          'reports.columns.sales_price_1',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'satis2',
          'reports.columns.sales_price_2',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'satis3',
          'reports.columns.sales_price_3',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'vergi',
          'reports.columns.tax',
          90,
          alignment: Alignment.centerRight,
        ),
        _column('durum', 'common.status', 100),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.total_products',
          value: rows.length.toString(),
          icon: Icons.dataset_outlined,
          accentColor: AppPalette.slate,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildBakiyeListesi(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler,
  ) async {
    final cariler = await _filteredAccounts(filtreler);
    final kasalar = await _filteredCashes(filtreler);
    final bankalar = await _filteredBanks(filtreler);
    final kartlar = await _filteredCards(filtreler);

    final List<RaporSatiri> rows = <RaporSatiri>[
      ...cariler.map((cari) {
        final double net = cari.bakiyeBorc - cari.bakiyeAlacak;
        return RaporSatiri(
          id: 'bakiye_cari_${cari.id}',
          cells: {
            'kod': cari.kodNo,
            'hesap': cari.adi,
            'tur': IslemCeviriYardimcisi.cevir(cari.hesapTuru),
            'borc': _formatMoney(cari.bakiyeBorc, currency: cari.paraBirimi),
            'alacak': _formatMoney(
              cari.bakiyeAlacak,
              currency: cari.paraBirimi,
            ),
            'net_bakiye': _formatMoney(net, currency: cari.paraBirimi),
            'vade_ozeti': cari.vadeGun > 0
                ? '${cari.vadeGun} ${tr('reports.days')}'
                : '-',
            'son_islem': '-',
          },
          sourceMenuIndex: TabAciciScope.cariKartiIndex,
          sourceSearchQuery: cari.adi,
          amountValue: net,
          sortValues: {
            'kod': cari.kodNo,
            'hesap': cari.adi,
            'tur': cari.hesapTuru,
            'borc': cari.bakiyeBorc,
            'alacak': cari.bakiyeAlacak,
            'net_bakiye': net,
          },
          extra: {'cariModel': cari},
        );
      }),
      ...kasalar.map(
        (kasa) => _financialBalanceRow(
          id: 'bakiye_kasa_${kasa.id}',
          kod: kasa.kod,
          ad: kasa.ad,
          tur: tr('transactions.source.cash'),
          bakiye: kasa.bakiye,
          paraBirimi: kasa.paraBirimi,
          menuIndex: 13,
        ),
      ),
      ...bankalar.map(
        (banka) => _financialBalanceRow(
          id: 'bakiye_banka_${banka.id}',
          kod: banka.kod,
          ad: banka.ad,
          tur: tr('transactions.source.bank'),
          bakiye: banka.bakiye,
          paraBirimi: banka.paraBirimi,
          menuIndex: 15,
        ),
      ),
      ...kartlar.map(
        (kart) => _financialBalanceRow(
          id: 'bakiye_kart_${kart.id}',
          kod: kart.kod,
          ad: kart.ad,
          tur: tr('transactions.source.credit_card'),
          bakiye: kart.bakiye,
          paraBirimi: kart.paraBirimi,
          menuIndex: 16,
        ),
      ),
    ];

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('kod', 'common.code', 120),
        _column('hesap', 'reports.columns.account_name', 220),
        _column('tur', 'common.type', 140),
        _column(
          'borc',
          'accounts.balance.debit_label',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'alacak',
          'accounts.balance.credit_label',
          120,
          alignment: Alignment.centerRight,
        ),
        _column(
          'net_bakiye',
          'reports.columns.net_balance',
          130,
          alignment: Alignment.centerRight,
        ),
        _column('vade_ozeti', 'reports.columns.maturity_summary', 120),
        _column('son_islem', 'reports.columns.last_movement', 140),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.total_balance',
          value: _formatMoney(
            rows.fold<double>(0.0, (sum, row) => sum + (row.amountValue ?? 0)),
          ),
          icon: Icons.account_balance_wallet_outlined,
          accentColor: AppPalette.slate,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildAlinacakVerilecekler(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler,
  ) async {
    final List<CariHesapModel> cariler = await _filteredAccounts(filtreler);
    final List<RaporSatiri> rows = cariler
        .where((cari) => cari.bakiyeBorc > 0 || cari.bakiyeAlacak > 0)
        .map((cari) {
          final bool alacak = cari.bakiyeAlacak > cari.bakiyeBorc;
          final double tutar = alacak ? cari.bakiyeAlacak : cari.bakiyeBorc;
          return RaporSatiri(
            id: 'av_${cari.id}',
            cells: {
              'cari': '${cari.kodNo} - ${cari.adi}',
              'tur': alacak
                  ? tr('reports.badges.receivable')
                  : tr('reports.badges.payable'),
              'vade': cari.vadeGun > 0
                  ? '${cari.vadeGun} ${tr('reports.days')}'
                  : '-',
              'gun_farki': cari.vadeGun.toString(),
              'tutar': _formatMoney(tutar, currency: cari.paraBirimi),
              'durum': cari.aktifMi
                  ? tr('common.active')
                  : tr('common.passive'),
              'kullanici': cari.kullanici,
            },
            sourceMenuIndex: TabAciciScope.cariKartiIndex,
            sourceSearchQuery: cari.adi,
            amountValue: alacak ? tutar : -tutar,
            sortValues: {
              'cari': cari.adi,
              'tur': alacak ? 1 : 0,
              'vade': cari.vadeGun,
              'gun_farki': cari.vadeGun,
              'tutar': tutar,
            },
            extra: {'cariModel': cari},
          );
        })
        .toList();

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('cari', 'reports.columns.current_account', 240),
        _column('tur', 'common.type', 120),
        _column('vade', 'common.due_date_short', 120),
        _column(
          'gun_farki',
          'reports.columns.day_diff',
          100,
          alignment: Alignment.centerRight,
        ),
        _column(
          'tutar',
          'common.amount',
          130,
          alignment: Alignment.centerRight,
        ),
        _column('durum', 'common.status', 100),
        _column('kullanici', 'common.user', 100),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.receivables_total',
          value: _formatMoney(
            rows
                .where((e) => (e.amountValue ?? 0) > 0)
                .fold<double>(0.0, (sum, row) => sum + (row.amountValue ?? 0)),
          ),
          icon: Icons.trending_up_rounded,
          accentColor: const Color(0xFF27AE60),
        ),
        RaporOzetKarti(
          labelKey: 'reports.summary.payables_total',
          value: _formatMoney(
            rows
                .where((e) => (e.amountValue ?? 0) < 0)
                .fold<double>(
                  0.0,
                  (sum, row) => sum + (row.amountValue ?? 0).abs(),
                ),
          ),
          icon: Icons.trending_down_rounded,
          accentColor: AppPalette.red,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildSonIslemTarihi(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler,
  ) async {
    final List<CariHesapModel> cariler = await _filteredAccounts(filtreler);
    final List<Map<String, dynamic>> cariIslemleri =
        await _tumCariIslemleriniGetir(filtreler);
    final Map<int, Map<String, dynamic>> cariSonHareket =
        <int, Map<String, dynamic>>{};
    for (final item in cariIslemleri) {
      final cari = item['__cari'] as CariHesapModel?;
      if (cari == null) continue;
      final current = cariSonHareket[cari.id];
      final currentDate = current == null
          ? null
          : _toDateTime(current['tarih']);
      final newDate = _toDateTime(item['tarih']);
      if (currentDate == null ||
          (newDate != null && newDate.isAfter(currentDate))) {
        cariSonHareket[cari.id] = item;
      }
    }

    final List<RaporSatiri> rows = cariler.map((cari) {
      final son = cariSonHareket[cari.id];
      final DateTime? tarih = son == null ? null : _toDateTime(son['tarih']);
      final double tutar = son == null ? 0.0 : _toDouble(son['tutar']);
      return RaporSatiri(
        id: 'son_islem_${cari.id}',
        cells: {
          'kod': cari.kodNo,
          'ad': cari.adi,
          'tur': IslemCeviriYardimcisi.cevir(cari.hesapTuru),
          'son_islem_tarihi': _formatDate(tarih, includeTime: true),
          'son_islem_turu': son == null
              ? '-'
              : IslemCeviriYardimcisi.cevir(
                  son['islem_turu']?.toString() ?? '-',
                ),
          'tutar': son == null
              ? '-'
              : _formatMoney(tutar, currency: cari.paraBirimi),
        },
        sourceMenuIndex: TabAciciScope.cariKartiIndex,
        sourceSearchQuery: cari.adi,
        amountValue: tutar,
        sortValues: {
          'kod': cari.kodNo,
          'ad': cari.adi,
          'tur': cari.hesapTuru,
          'son_islem_tarihi': tarih,
          'tutar': tutar,
        },
        extra: {'cariModel': cari},
      );
    }).toList();

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('kod', 'common.code', 120),
        _column('ad', 'common.name', 220),
        _column('tur', 'common.type', 140),
        _column(
          'son_islem_tarihi',
          'reports.columns.last_transaction_date',
          170,
        ),
        _column('son_islem_turu', 'reports.columns.last_transaction_type', 180),
        _column(
          'tutar',
          'common.amount',
          130,
          alignment: Alignment.centerRight,
        ),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.record',
          value: rows.length.toString(),
          icon: Icons.event_repeat_outlined,
          accentColor: AppPalette.slate,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildKarZarar(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler,
  ) async {
    final satis = await _buildCariTabanliRapor(
      _raporlar.firstWhere((e) => e.id == 'sales_report'),
      filtreler,
      mod: _CariRaporModu.satis,
    );
    final alis = await _buildCariTabanliRapor(
      _raporlar.firstWhere((e) => e.id == 'purchase_report'),
      filtreler,
      mod: _CariRaporModu.alis,
    );
    final gider = await _buildGiderRaporu(
      _raporlar.firstWhere((e) => e.id == 'expense_report'),
      filtreler,
    );

    final double ciro = satis.rows.fold<double>(
      0.0,
      (sum, row) => sum + (row.amountValue ?? 0),
    );
    final double maliyet = alis.rows.fold<double>(
      0.0,
      (sum, row) => sum + (row.amountValue ?? 0),
    );
    final double giderToplam = gider.rows.fold<double>(
      0.0,
      (sum, row) => sum + (row.amountValue ?? 0),
    );
    final double brutKar = ciro - maliyet;
    final double netKar = brutKar - giderToplam;

    final List<RaporSatiri> rows = [
      RaporSatiri(
        id: 'kar_zarar_ciro',
        cells: {
          'donem': filtreOzetiniOlustur(filtreler).isEmpty
              ? tr('common.all')
              : filtreOzetiniOlustur(filtreler),
          'ciro': _formatMoney(ciro),
          'maliyet': _formatMoney(maliyet),
          'brut_kar': _formatMoney(brutKar),
          'gider': _formatMoney(giderToplam),
          'net_kar': _formatMoney(netKar),
        },
        amountValue: netKar,
        sortValues: {
          'ciro': ciro,
          'maliyet': maliyet,
          'brut_kar': brutKar,
          'gider': giderToplam,
          'net_kar': netKar,
        },
      ),
    ];

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('donem', 'common.date_range', 280),
        _column(
          'ciro',
          'reports.columns.turnover',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'maliyet',
          'reports.columns.cost',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'brut_kar',
          'reports.columns.gross_profit',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'gider',
          'reports.columns.expense',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'net_kar',
          'reports.columns.net_profit',
          130,
          alignment: Alignment.centerRight,
        ),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.turnover',
          value: _formatMoney(ciro),
          icon: Icons.point_of_sale_rounded,
          accentColor: AppPalette.red,
        ),
        RaporOzetKarti(
          labelKey: 'reports.summary.gross_profit',
          value: _formatMoney(brutKar),
          icon: Icons.show_chart_rounded,
          accentColor: const Color(0xFF27AE60),
        ),
        RaporOzetKarti(
          labelKey: 'reports.summary.net_profit',
          value: _formatMoney(netKar),
          icon: Icons.analytics_outlined,
          accentColor: AppPalette.slate,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildKullaniciIslemRaporu(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler,
  ) async {
    final List<KullaniciModel> kullanicilar = await _filteredUsers(filtreler);
    final List<Map<String, dynamic>> hareketler =
        await _collectInBatches<KullaniciModel, Map<String, dynamic>>(
          kullanicilar,
          (kullanici) async {
            final List<KullaniciHareketModel> txs = await _ayarlarServisi
                .kullaniciHareketleriniGetir(kullanici.id);
            return txs
                .where((tx) => _matchDate(tx.tarih, filtreler))
                .map((tx) => {'__user': kullanici, '__tx': tx})
                .toList();
          },
        );

    final List<RaporSatiri> rows = hareketler
        .where((item) {
          final tx = item['__tx'] as KullaniciHareketModel;
          final bool typeOk =
              filtreler.islemTuru == null ||
              filtreler.islemTuru == tr('common.all') ||
              tx.islemTuru.toLowerCase() == filtreler.islemTuru!.toLowerCase();
          return typeOk;
        })
        .map((item) {
          final user = item['__user'] as KullaniciModel;
          final tx = item['__tx'] as KullaniciHareketModel;
          final double tutarEtkisi = tx.alacak - tx.borc;
          return RaporSatiri(
            id: 'kullanici_tx_${tx.id}',
            cells: {
              'kullanici': user.kullaniciAdi,
              'modul': user.rol,
              'islem': tx.islemTuru,
              'tarih': _formatDate(tx.tarih, includeTime: true),
              'belge_ref': tx.id,
              'tutar_etkisi': _formatMoney(tutarEtkisi),
              'kayit_sayisi': '1',
            },
            details: {
              tr('common.description'): tx.aciklama,
              tr('reports.columns.user_full_name'): '${user.ad} ${user.soyad}'
                  .trim(),
            },
            sourceMenuIndex: 1,
            sourceSearchQuery: user.kullaniciAdi,
            amountValue: tutarEtkisi,
            sortValues: {
              'kullanici': user.kullaniciAdi,
              'modul': user.rol,
              'islem': tx.islemTuru,
              'tarih': tx.tarih,
              'tutar_etkisi': tutarEtkisi,
              'kayit_sayisi': 1,
            },
          );
        })
        .toList();

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('kullanici', 'common.user', 160),
        _column('modul', 'reports.columns.module', 140),
        _column('islem', 'common.transaction_type', 150),
        _column('tarih', 'common.date', 150),
        _column('belge_ref', 'reports.columns.document_ref', 140),
        _column(
          'tutar_etkisi',
          'reports.columns.amount_effect',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'kayit_sayisi',
          'reports.columns.record_count',
          100,
          alignment: Alignment.centerRight,
        ),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.record',
          value: rows.length.toString(),
          icon: Icons.groups_rounded,
          accentColor: AppPalette.slate,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildTumHareketler(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler,
  ) async {
    bool mirroredFinanceRow(Map<String, dynamic> tx) {
      final String integrationRef = tx['integration_ref']?.toString() ?? '';
      final String locationType = _firstNonEmpty([
        tx['yer']?.toString(),
        tx['location']?.toString(),
        '',
      ]);
      return integrationRef.toUpperCase().startsWith('CARI-PAV-') ||
          _isCurrentAccountFinanceLocation(locationType);
    }

    final List<Map<String, dynamic>> cariRows = await _tumCariIslemleriniGetir(
      filtreler,
    );
    final List<Map<String, dynamic>> kasaRows = await _tumKasaIslemleriniGetir(
      filtreler,
    ).then((rows) => rows.where((tx) => !mirroredFinanceRow(tx)).toList());
    final List<Map<String, dynamic>> bankaRows =
        await _tumBankaIslemleriniGetir(
          filtreler,
        ).then((rows) => rows.where((tx) => !mirroredFinanceRow(tx)).toList());
    final List<Map<String, dynamic>> krediKartiRows =
        await _tumKrediKartiIslemleriniGetir(
          filtreler,
        ).then((rows) => rows.where((tx) => !mirroredFinanceRow(tx)).toList());

    final List<RaporSatiri> rows = <RaporSatiri>[
      ...cariRows.map(_rowFromAnyCariMovement),
      ...kasaRows.map(
        (e) => _rowFromFinanceMovement(
          e,
          type: tr('transactions.source.cash'),
          menuIndex: 13,
        ),
      ),
      ...bankaRows.map(
        (e) => _rowFromFinanceMovement(
          e,
          type: tr('transactions.source.bank'),
          menuIndex: 15,
        ),
      ),
      ...krediKartiRows.map(
        (e) => _rowFromFinanceMovement(
          e,
          type: tr('transactions.source.credit_card'),
          menuIndex: 16,
        ),
      ),
    ];

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tarih', 'common.date', 150),
        _column('modul', 'reports.columns.module', 140),
        _column('islem', 'common.transaction_type', 180),
        _column('belge_no', 'reports.columns.document_no', 150),
        _column('hesap', 'reports.columns.current_account', 220),
        _column('aciklama', 'common.description', 240),
        _column(
          'borc',
          'accounts.balance.debit_label',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'alacak',
          'accounts.balance.credit_label',
          130,
          alignment: Alignment.centerRight,
        ),
        _column(
          'tutar',
          'common.amount',
          130,
          alignment: Alignment.centerRight,
        ),
        _column('kullanici', 'common.user', 100),
      ],
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.record',
          value: rows.length.toString(),
          icon: Icons.alt_route_rounded,
          accentColor: AppPalette.slate,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
    );
  }

  Future<RaporSonucu> _buildAlisSatisHareketleri(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler,
  ) async {
    final satis = await _buildCariTabanliRapor(
      _raporlar.firstWhere((e) => e.id == 'sales_report'),
      filtreler,
      mod: _CariRaporModu.satis,
    );
    final alis = await _buildCariTabanliRapor(
      _raporlar.firstWhere((e) => e.id == 'purchase_report'),
      filtreler,
      mod: _CariRaporModu.alis,
    );

    final List<RaporSatiri> rows = [...satis.rows, ...alis.rows];

    return RaporSonucu(
      report: rapor,
      columns: satis.columns,
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: 'reports.summary.total_sales',
          value: _formatMoney(
            satis.rows.fold<double>(
              0.0,
              (sum, row) => sum + (row.amountValue ?? 0),
            ),
          ),
          icon: Icons.point_of_sale_rounded,
          accentColor: AppPalette.red,
        ),
        RaporOzetKarti(
          labelKey: 'reports.summary.total_purchases',
          value: _formatMoney(
            alis.rows.fold<double>(
              0.0,
              (sum, row) => sum + (row.amountValue ?? 0),
            ),
          ),
          icon: Icons.shopping_cart_checkout_rounded,
          accentColor: AppPalette.amber,
        ),
      ],
      totalCount: rows.length,
      mainTableLabel: tr(rapor.labelKey),
      detailTableLabel: tr('common.products'),
    );
  }

  RaporSatiri _rowFromAnyCariMovement(Map<String, dynamic> tx) {
    final cari = tx['__cari'] as CariHesapModel?;
    final DateTime? tarih = _toDateTime(tx['tarih']);
    final double tutar = _toDouble(tx['tutar']);
    final bool debit = _isDebit(tx['yon']?.toString());
    final sunum = _cariIslemSunumunuHazirla(tx);
    return RaporSatiri(
      id: 'all_cari_${tx['id']}',
      cells: {
        'tarih': _formatDate(tarih, includeTime: true),
        'modul': tr('nav.accounts'),
        'islem': IslemCeviriYardimcisi.cevir(sunum.islem),
        'belge_no': _firstNonEmpty([
          tx['fatura_no']?.toString(),
          tx['irsaliye_no']?.toString(),
          tx['integration_ref']?.toString(),
          '-',
        ]),
        'hesap': cari == null ? '-' : '${cari.kodNo} - ${cari.adi}',
        'aciklama': sunum.aciklama,
        'borc': debit
            ? _formatMoney(tutar, currency: cari?.paraBirimi ?? 'TRY')
            : '-',
        'alacak': debit
            ? '-'
            : _formatMoney(tutar, currency: cari?.paraBirimi ?? 'TRY'),
        'tutar': _formatMoney(tutar, currency: cari?.paraBirimi ?? 'TRY'),
        'kullanici': tx['kullanici']?.toString() ?? '-',
      },
      sourceMenuIndex: TabAciciScope.cariKartiIndex,
      sourceSearchQuery: cari?.adi,
      amountValue: debit ? -tutar : tutar,
      sortValues: {
        'tarih': tarih,
        'modul': tr('nav.accounts'),
        'islem': sunum.islem,
        'hesap': cari?.adi,
        'tutar': tutar,
        'aciklama': sunum.aciklama,
      },
      extra: {'cariModel': cari},
    );
  }

  RaporSatiri _rowFromFinanceMovement(
    Map<String, dynamic> tx, {
    required String type,
    required int menuIndex,
  }) {
    final DateTime? tarih = _toDateTime(tx['tarih']);
    final double tutar = _toDouble(tx['tutar']);
    final bool incoming = tx['isIncoming'] == true;
    final String hesapAdi = _firstNonEmpty([
      tx['kasaAdi']?.toString(),
      tx['bankaAdi']?.toString(),
      tx['krediKartiAdi']?.toString(),
      '-',
    ]);
    final sunum = switch (menuIndex) {
      13 => _finansIslemSunumunuHazirla(tx, mod: _FinansRaporModu.kasa),
      15 => _finansIslemSunumunuHazirla(tx, mod: _FinansRaporModu.banka),
      16 => _finansIslemSunumunuHazirla(tx, mod: _FinansRaporModu.krediKarti),
      _ => _RaporIslemSunumu(
        islem: tx['islem']?.toString() ?? '-',
        aciklama: tx['aciklama']?.toString() ?? '-',
      ),
    };
    return RaporSatiri(
      id: 'all_fin_${menuIndex}_${tx['id']}',
      cells: {
        'tarih': _formatDate(tarih, includeTime: true),
        'modul': type,
        'islem': IslemCeviriYardimcisi.cevir(sunum.islem),
        'belge_no': tx['integration_ref']?.toString() ?? '#${tx['id']}',
        'hesap': hesapAdi,
        'aciklama': sunum.aciklama,
        'borc': incoming ? '-' : _formatMoney(tutar),
        'alacak': incoming ? _formatMoney(tutar) : '-',
        'tutar': _formatMoney(tutar),
        'kullanici': tx['kullanici']?.toString() ?? '-',
      },
      sourceMenuIndex: menuIndex,
      sourceSearchQuery: hesapAdi,
      amountValue: incoming ? tutar : -tutar,
      sortValues: {
        'tarih': tarih,
        'modul': type,
        'islem': sunum.islem,
        'hesap': hesapAdi,
        'tutar': tutar,
        'aciklama': sunum.aciklama,
      },
    );
  }

  Future<List<CariHesapModel>> _filteredAccounts(
    RaporFiltreleri filtreler,
  ) async {
    if (filtreler.cariId != null) {
      return _cariServisi.cariHesaplariGetir(
        sayfaBasinaKayit: 1,
        sadeceIdler: [filtreler.cariId!],
      );
    }
    return _cariServisi.cariHesaplariGetir(sayfaBasinaKayit: 5000);
  }

  Future<List<UrunModel>> _filteredProducts(RaporFiltreleri filtreler) async {
    final products = await _urunServisi.urunleriGetir(sayfaBasinaKayit: 5000);
    return products.where((urun) {
      final bool urunOk =
          filtreler.urunKodu == null ||
          filtreler.urunKodu!.isEmpty ||
          urun.kod == filtreler.urunKodu;
      final bool grupOk =
          filtreler.urunGrubu == null ||
          filtreler.urunGrubu!.isEmpty ||
          urun.grubu == filtreler.urunGrubu;
      final bool durumOk =
          filtreler.durum == null ||
          filtreler.durum == tr('common.all') ||
          (filtreler.durum == tr('common.active') && urun.aktifMi) ||
          (filtreler.durum == tr('common.passive') && !urun.aktifMi);
      return urunOk && grupOk && durumOk;
    }).toList();
  }

  Future<List<DepoModel>> _filteredDepolar(RaporFiltreleri filtreler) async {
    final depolar = await _depoServisi.tumDepolariGetir();
    if (filtreler.depoId == null) return depolar;
    return depolar.where((e) => e.id == filtreler.depoId).toList();
  }

  Future<List<KasaModel>> _filteredCashes(RaporFiltreleri filtreler) async {
    final list = await _kasaServisi.tumKasalariGetir();
    if (filtreler.kasaId == null) return list;
    return list.where((e) => e.id == filtreler.kasaId).toList();
  }

  Future<List<BankaModel>> _filteredBanks(RaporFiltreleri filtreler) async {
    final list = await _bankaServisi.tumBankalariGetir();
    if (filtreler.bankaId == null) return list;
    return list.where((e) => e.id == filtreler.bankaId).toList();
  }

  Future<List<KrediKartiModel>> _filteredCards(
    RaporFiltreleri filtreler,
  ) async {
    final list = await _krediKartiServisi.tumKrediKartlariniGetir(
      sadeceAktif: false,
    );
    if (filtreler.krediKartiId == null) return list;
    return list.where((e) => e.id == filtreler.krediKartiId).toList();
  }

  Future<List<KullaniciModel>> _filteredUsers(RaporFiltreleri filtreler) async {
    final list = await _ayarlarServisi.kullanicilariGetir(
      sayfaBasinaKayit: 2000,
    );
    if (filtreler.kullaniciId == null) return list;
    return list.where((e) => e.id == filtreler.kullaniciId).toList();
  }

  Future<List<Map<String, dynamic>>> _tumCariIslemleriniGetir(
    RaporFiltreleri filtreler,
  ) async {
    final cariler = await _filteredAccounts(filtreler);
    return _collectInBatches<CariHesapModel, Map<String, dynamic>>(cariler, (
      cari,
    ) async {
      final txs = await _cariServisi.cariIslemleriniGetir(
        cari.id,
        baslangicTarihi: filtreler.baslangicTarihi,
        bitisTarihi: filtreler.bitisTarihi,
        islemTuru: _normalizedSelection(filtreler.islemTuru),
        kullanici: _emptyToNull(filtreler.kullaniciId),
        limit: 1000,
      );
      return txs
          .where((tx) {
            final bool tutarOk = _matchesDoubleRange(
              _toDouble(tx['tutar']),
              min: filtreler.minTutar,
              max: filtreler.maxTutar,
            );
            return tutarOk;
          })
          .map((tx) => {...tx, '__cari': cari})
          .toList();
    });
  }

  Future<List<Map<String, dynamic>>> _tumKasaIslemleriniGetir(
    RaporFiltreleri filtreler,
  ) async {
    final kasalar = await _filteredCashes(filtreler);
    return _collectInBatches<KasaModel, Map<String, dynamic>>(kasalar, (
      kasa,
    ) async {
      final txs = await _kasaServisi.kasaIslemleriniGetir(
        kasa.id,
        baslangicTarihi: filtreler.baslangicTarihi,
        bitisTarihi: filtreler.bitisTarihi,
        islemTuru: _normalizedSelection(filtreler.islemTuru),
        kullanici: _emptyToNull(filtreler.kullaniciId),
        limit: 1000,
      );
      return txs
          .where(
            (tx) => _matchesDoubleRange(
              _toDouble(tx['tutar']),
              min: filtreler.minTutar,
              max: filtreler.maxTutar,
            ),
          )
          .map((tx) => {...tx, '__kasa': kasa})
          .toList();
    });
  }

  Future<List<Map<String, dynamic>>> _tumBankaIslemleriniGetir(
    RaporFiltreleri filtreler,
  ) async {
    final bankalar = await _filteredBanks(filtreler);
    return _collectInBatches<BankaModel, Map<String, dynamic>>(bankalar, (
      banka,
    ) async {
      final txs = await _bankaServisi.bankaIslemleriniGetir(
        banka.id,
        baslangicTarihi: filtreler.baslangicTarihi,
        bitisTarihi: filtreler.bitisTarihi,
        islemTuru: _normalizedSelection(filtreler.islemTuru),
        kullanici: _emptyToNull(filtreler.kullaniciId),
        limit: 1000,
      );
      return txs
          .where(
            (tx) => _matchesDoubleRange(
              _toDouble(tx['tutar']),
              min: filtreler.minTutar,
              max: filtreler.maxTutar,
            ),
          )
          .map((tx) => {...tx, '__banka': banka})
          .toList();
    });
  }

  Future<List<Map<String, dynamic>>> _tumKrediKartiIslemleriniGetir(
    RaporFiltreleri filtreler,
  ) async {
    final kartlar = await _filteredCards(filtreler);
    return _collectInBatches<KrediKartiModel, Map<String, dynamic>>(kartlar, (
      kart,
    ) async {
      final txs = await _krediKartiServisi.krediKartiIslemleriniGetir(
        kart.id,
        baslangicTarihi: filtreler.baslangicTarihi,
        bitisTarihi: filtreler.bitisTarihi,
        islemTuru: _normalizedSelection(filtreler.islemTuru),
        kullanici: _emptyToNull(filtreler.kullaniciId),
        limit: 1000,
      );
      return txs
          .where(
            (tx) => _matchesDoubleRange(
              _toDouble(tx['tutar']),
              min: filtreler.minTutar,
              max: filtreler.maxTutar,
            ),
          )
          .map((tx) => {...tx, '__kart': kart})
          .toList();
    });
  }

  Future<List<Map<String, dynamic>>> _tumDepoIslemleriniGetir(
    RaporFiltreleri filtreler,
  ) async {
    final depolar = await _filteredDepolar(filtreler);
    final List<Map<String, dynamic>> all =
        await _collectInBatches<DepoModel, Map<String, dynamic>>(depolar, (
          depo,
        ) async {
          final txs = await _depoServisi.depoIslemleriniGetir(
            depo.id,
            baslangicTarihi: filtreler.baslangicTarihi,
            bitisTarihi: filtreler.bitisTarihi,
            kullanici: _emptyToNull(filtreler.kullaniciId),
            limit: 1000,
          );
          return txs.map((tx) => {...tx, '__depo': depo}).toList();
        });

    final Map<int, Map<String, dynamic>> byId = <int, Map<String, dynamic>>{};
    for (final item in all) {
      final int id = (item['id'] as int?) ?? -1;
      if (id == -1 || byId.containsKey(id)) continue;
      byId[id] = item;
    }
    return byId.values.toList();
  }

  Future<List<TOut>> _collectInBatches<TIn, TOut>(
    List<TIn> source,
    Future<List<TOut>> Function(TIn item) loader, {
    int batchSize = 8,
  }) async {
    final List<TOut> all = <TOut>[];
    for (int i = 0; i < source.length; i += batchSize) {
      final batch = source.skip(i).take(batchSize).toList();
      final result = await Future.wait(
        batch.map((item) async {
          try {
            return await loader(item);
          } catch (e) {
            debugPrint('Rapor veri batch hatası: $e');
            return <TOut>[];
          }
        }),
      );
      for (final list in result) {
        all.addAll(list);
      }
    }
    return all;
  }

  List<RaporSecimSecenegi> _options(List<String> labels) {
    return labels
        .map((label) => RaporSecimSecenegi(value: label, label: label))
        .toList();
  }

  List<RaporSatiri> _applySearch(List<RaporSatiri> rows, String search) {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows.where((row) {
      final haystack = [
        ...row.cells.values,
        ...row.details.keys,
        ...row.details.values,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  List<RaporSatiri> _sortRows(
    List<RaporSatiri> rows, {
    String? sortKey,
    required bool ascending,
  }) {
    if (sortKey == null || sortKey.isEmpty) return rows;
    final copy = [...rows];
    copy.sort((a, b) {
      final av = a.sortValues[sortKey] ?? a.cells[sortKey] ?? '';
      final bv = b.sortValues[sortKey] ?? b.cells[sortKey] ?? '';
      final result = _compareDynamic(av, bv);
      return ascending ? result : -result;
    });
    return copy;
  }

  int _compareDynamic(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is DateTime && b is DateTime) return a.compareTo(b);
    if (a is num && b is num) return a.compareTo(b);
    return a.toString().toLowerCase().compareTo(b.toString().toLowerCase());
  }

  RaporKolonTanimi _column(
    String key,
    String labelKey,
    double width, {
    Alignment alignment = Alignment.centerLeft,
    bool allowSorting = true,
    bool visibleByDefault = true,
  }) {
    final spec = _kolonStandartlari[key];
    final resolvedWidth = spec == null
        ? width
        : math.max(width, spec.minWidth).toDouble();
    return RaporKolonTanimi(
      key: key,
      labelKey: labelKey,
      width: resolvedWidth,
      alignment: spec?.alignment ?? alignment,
      allowSorting: allowSorting,
      visibleByDefault: visibleByDefault,
    );
  }

  RaporSatiri _financialBalanceRow({
    required String id,
    required String kod,
    required String ad,
    required String tur,
    required double bakiye,
    required String paraBirimi,
    required int menuIndex,
  }) {
    final bool alacak = bakiye >= 0;
    return RaporSatiri(
      id: id,
      cells: {
        'kod': kod,
        'hesap': ad,
        'tur': tur,
        'borc': alacak ? '-' : _formatMoney(bakiye.abs(), currency: paraBirimi),
        'alacak': alacak
            ? _formatMoney(bakiye.abs(), currency: paraBirimi)
            : '-',
        'net_bakiye': _formatMoney(bakiye, currency: paraBirimi),
        'vade_ozeti': '-',
        'son_islem': '-',
      },
      sourceMenuIndex: menuIndex,
      sourceSearchQuery: ad,
      amountValue: bakiye,
      sortValues: {
        'kod': kod,
        'hesap': ad,
        'tur': tur,
        'borc': alacak ? 0.0 : bakiye.abs(),
        'alacak': alacak ? bakiye.abs() : 0.0,
        'net_bakiye': bakiye,
      },
    );
  }

  DetailTable _detailTableFromItems(
    List<Map<String, dynamic>> items, {
    required String title,
  }) {
    double pickFirstNonZero(List<dynamic> values) {
      for (final value in values) {
        final v = _toDouble(value);
        if (v != 0.0) return v;
      }
      return 0.0;
    }

    String pickFirstNonEmpty(List<dynamic> values, {String fallback = '-'}) {
      for (final value in values) {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty && text != '-') return text;
      }
      return fallback;
    }

    return DetailTable(
      title: title,
      headers: [
        tr('common.code_no'),
        tr('shipment.field.name'),
        tr('common.quantity'),
        tr('common.unit'),
        tr('common.unit_price'),
        tr('common.total_amount'),
        tr('common.raw_price'),
        tr('common.description'),
      ],
      data: items.map((item) {
        final double quantity = pickFirstNonZero([
          item['quantity'],
          item['miktar'],
          item['qty'],
        ]);
        final double unitPrice = pickFirstNonZero([
          item['price'],
          item['unitCost'],
          item['unit_cost'],
          item['unitPrice'],
          item['unit_price'],
          item['birim_fiyat'],
          item['birimFiyat'],
        ]);
        final double total = pickFirstNonZero([
          item['total'],
          item['lineTotal'],
          item['line_total'],
          item['tutar'],
        ]);
        final double safeTotal = total != 0.0 ? total : quantity * unitPrice;
        final double rawPrice = pickFirstNonZero([
          item['ham_fiyat'],
          item['hamFiyat'],
          item['rawPrice'],
          item['raw_price'],
          item['raw'],
          item['unitCost'],
          item['price'],
        ]);
        final String description = pickFirstNonEmpty([
          item['description'],
          item['aciklama'],
          item['not'],
          item['note'],
        ]);
        return [
          pickFirstNonEmpty([
            item['code'],
            item['kod'],
            item['product_code'],
            item['urun_kodu'],
          ]),
          pickFirstNonEmpty([
            item['name'],
            item['urun_adi'],
            item['product_name'],
            item['urunAdi'],
          ]),
          _formatNumber(quantity),
          pickFirstNonEmpty([item['unit'], item['birim']]),
          _formatMoney(unitPrice),
          _formatMoney(safeTotal),
          _formatMoney(rawPrice),
          description,
        ];
      }).toList(),
    );
  }

  List<Map<String, dynamic>> _extractDetailItems(dynamic raw) {
    if (raw == null) return const <Map<String, dynamic>>[];
    dynamic parsed = raw;
    if (raw is String) {
      try {
        parsed = jsonDecode(raw);
      } catch (_) {
        return const <Map<String, dynamic>>[];
      }
    }
    final List<dynamic> flattened = <dynamic>[];
    if (parsed is List) {
      for (final item in parsed) {
        if (item is List) {
          flattened.addAll(item);
        } else {
          flattened.add(item);
        }
      }
    } else {
      return const <Map<String, dynamic>>[];
    }
    return flattened
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  double _sumKdv(List<Map<String, dynamic>> items) {
    double sum = 0.0;
    for (final item in items) {
      final double quantity = _toDouble(item['quantity']);
      final double price = _toDouble(item['price']) != 0.0
          ? _toDouble(item['price'])
          : _toDouble(item['unitCost']);
      final double rate = _toDouble(item['vatRate']) != 0.0
          ? _toDouble(item['vatRate'])
          : _toDouble(item['kdv']);
      sum += (quantity * price) * rate / 100;
    }
    return sum;
  }

  String _detectPaymentType(Map<String, dynamic> tx) {
    final ref = tx['integration_ref']?.toString() ?? '';
    final raw = tx['kaynak_adi']?.toString() ?? '';
    if (raw.isNotEmpty) return raw;
    if (ref.startsWith('RETAIL-')) return tr('reports.payment_types.retail');
    return _firstNonEmpty([tx['kaynak_kodu']?.toString(), tr('common.none')]);
  }

  bool _isSaleTransaction(String value) {
    final lower = value.toLowerCase();
    return lower.contains('satış') || lower.contains('satis');
  }

  bool _isPurchaseTransaction(String value) {
    final lower = value.toLowerCase();
    return lower.contains('alış') || lower.contains('alis');
  }

  bool _isDebit(String? raw) {
    final lower = (raw ?? '').toLowerCase();
    return lower.contains('borç') || lower.contains('borc');
  }

  bool _matchDate(DateTime? date, RaporFiltreleri filtreler) {
    if (date == null) return false;
    if (filtreler.baslangicTarihi != null &&
        date.isBefore(
          DateTime(
            filtreler.baslangicTarihi!.year,
            filtreler.baslangicTarihi!.month,
            filtreler.baslangicTarihi!.day,
          ),
        )) {
      return false;
    }
    if (filtreler.bitisTarihi != null &&
        date.isAfter(
          DateTime(
            filtreler.bitisTarihi!.year,
            filtreler.bitisTarihi!.month,
            filtreler.bitisTarihi!.day,
            23,
            59,
            59,
          ),
        )) {
      return false;
    }
    return true;
  }

  bool _matchesDoubleRange(double value, {double? min, double? max}) {
    if (min != null && value < min) return false;
    if (max != null && value > max) return false;
    return true;
  }

  String _normalizedSelection(String? value) {
    if (value == null || value.trim().isEmpty || value == tr('common.all')) {
      return '';
    }
    return value.trim();
  }

  String? _emptyToNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return '-';
  }

  String _documentNo(dynamic item, {required bool cekMi}) {
    return cekMi
        ? item.cekNo?.toString() ?? '-'
        : item.senetNo?.toString() ?? '-';
  }

  String _statusText(dynamic item) {
    if (item.aktifMi == true) return tr('common.active');
    return tr('common.passive');
  }

  _RaporIslemSunumu _cariIslemSunumunuHazirla(Map<String, dynamic> tx) {
    final String rawType = _firstNonEmpty([
      tx['islem_turu']?.toString(),
      tx['islem']?.toString(),
      '-',
    ]);
    final String yon = _firstNonEmpty([
      tx['yon']?.toString(),
      tx['type']?.toString(),
      '',
    ]);
    final String integrationRef = tx['integration_ref']?.toString() ?? '';
    final String lowType = rawType.toLowerCase();
    final String guncelDurum = tx['guncel_durum']?.toString() ?? '';
    final bool isCheck = _isCheckReference(rawType, integrationRef);
    final bool isNote = _isNoteReference(rawType, integrationRef);
    final bool isCheckNote = isCheck || isNote;
    final bool isIncoming = _cariIslemGirisMi(rawType, yon);

    String displayType = IslemTuruRenkleri.getProfessionalLabel(
      rawType,
      context: 'cari',
      yon: yon,
      fallback: rawType,
    );

    if (_isCurrentAccountPaymentReference(integrationRef) ||
        _isCurrentAccountFinanceSourceType(lowType)) {
      displayType = isIncoming ? 'Para Alındı' : 'Para Verildi';
    } else if (_isSaleReference(integrationRef)) {
      displayType = 'Satış Yapıldı';
    } else if (_isPurchaseReference(integrationRef)) {
      displayType = 'Alış Yapıldı';
    } else if (isCheckNote) {
      if (guncelDurum == 'Ciro Edildi') {
        displayType = isCheck
            ? 'Çek Alındı (Ciro Edildi)'
            : 'Senet Alındı (Ciro Edildi)';
      } else if (guncelDurum == 'Tahsil Edildi' || guncelDurum == 'Ödendi') {
        final String statusLabel = guncelDurum;
        displayType = isCheck
            ? 'Çek ${isIncoming ? 'Alındı' : 'Verildi'} ($statusLabel)'
            : 'Senet ${isIncoming ? 'Alındı' : 'Verildi'} ($statusLabel)';
      } else if (isCheck) {
        displayType = isIncoming ? 'Çek Alındı' : 'Çek Verildi';
      } else if (isNote) {
        displayType = isIncoming ? 'Senet Alındı' : 'Senet Verildi';
      }
    }

    String displayDescription = tx['aciklama']?.toString() ?? '';
    if (isCheckNote && _isAutomatedCheckNoteDescription(displayDescription)) {
      displayDescription = '';
    }

    return _RaporIslemSunumu(
      islem: displayType,
      aciklama: displayDescription.trim().isEmpty ? '-' : displayDescription,
      aciklama2:
          tx['aciklama2']?.toString() ?? tx['aciklama_2']?.toString() ?? '',
    );
  }

  _RaporIslemSunumu _finansIslemSunumunuHazirla(
    Map<String, dynamic> tx, {
    required _FinansRaporModu mod,
  }) {
    final String rawType = _firstNonEmpty([
      tx['islem_turu']?.toString(),
      tx['islem']?.toString(),
      '-',
    ]);
    final String integrationRef = tx['integration_ref']?.toString() ?? '';
    final String locationType = tx['yer']?.toString() ?? '';
    final String lowType = rawType.toLowerCase();
    final String lowDescription = (tx['aciklama']?.toString() ?? '')
        .toLowerCase();
    final String lowRef = integrationRef.toLowerCase();
    final bool isRetailRef = lowRef.startsWith('retail-');
    bool isIncoming = tx['isIncoming'] == true;
    if (_isIncomingFinanceType(lowType)) {
      isIncoming = true;
    } else if (_isOutgoingFinanceType(lowType)) {
      isIncoming = false;
    }

    String displayType = isIncoming ? 'Para Alındı' : 'Para Verildi';
    final bool isCheck = _isCheckReference(rawType, integrationRef);
    final bool isNote = _isNoteReference(rawType, integrationRef);
    final bool isCheckNote = isCheck || isNote;

    // Perakende satış (RETAIL-*) finans hareketleri raporlarda ödeme hareketi gibi
    // listelenmeli: "Para Alındı/Verildi". Satış kaydı ayrı rapor satırı olarak
    // üretildiği için burada "Satış Yapıldı" etiketiyle üzerine yazma.
    if (_isSaleReference(integrationRef) && !isRetailRef) {
      displayType = 'Satış Yapıldı';
    } else if (_isPurchaseReference(integrationRef)) {
      displayType = 'Alış Yapıldı';
    } else if (_isOpeningStockReference(integrationRef, lowDescription)) {
      displayType = 'Açılış Stoğu';
    } else if (_isProductionReference(integrationRef, lowDescription)) {
      displayType = 'Üretim';
    } else if (_isTransferReference(integrationRef, lowDescription)) {
      displayType = 'Devir';
    } else if (mod != _FinansRaporModu.kasa &&
        integrationRef.toLowerCase().contains('collection')) {
      displayType = 'Tahsilat';
    } else if (mod != _FinansRaporModu.kasa &&
        integrationRef.toLowerCase().contains('payment')) {
      displayType = 'Ödeme';
    } else if (isCheck) {
      displayType = isIncoming
          ? 'Çek Alındı (Tahsil Edildi)'
          : 'Çek Verildi (Ödendi)';
    } else if (isNote) {
      displayType = isIncoming
          ? 'Senet Alındı (Tahsil Edildi)'
          : 'Senet Verildi (Ödendi)';
    }

    if (!isIncoming &&
        displayType == 'Para Verildi' &&
        locationType.toLowerCase().contains('personel')) {
      displayType = 'Personel Ödemesi';
    }

    String displayDescription = tx['aciklama']?.toString() ?? '';
    if (isCheckNote && _isAutomatedCheckNoteDescription(displayDescription)) {
      displayDescription = '';
    }

    return _RaporIslemSunumu(
      islem: displayType,
      aciklama: displayDescription.trim().isEmpty ? '-' : displayDescription,
      aciklama2:
          tx['aciklama2']?.toString() ?? tx['aciklama_2']?.toString() ?? '',
    );
  }

  _RaporIslemSunumu _stokIslemSunumunuHazirla(Map<String, dynamic> tx) {
    final String rawType = _firstNonEmpty([
      tx['customTypeLabel']?.toString(),
      tx['islem_turu']?.toString(),
      tx['islem']?.toString(),
      '',
    ]);
    final String integrationRef = tx['integration_ref']?.toString() ?? '';
    final String lowDescription =
        (tx['aciklama']?.toString() ?? tx['description']?.toString() ?? '')
            .toLowerCase();
    final bool isIncoming =
        tx['is_giris'] == true ||
        tx['isIncoming'] == true ||
        _toDouble(tx['miktar']) >= 0;
    final String fallbackType = rawType.trim().isEmpty
        ? (isIncoming ? 'Giriş' : 'Çıkış')
        : rawType;

    String displayType = IslemTuruRenkleri.getProfessionalLabel(
      fallbackType,
      context: 'stock',
      fallback: fallbackType,
    );

    if (_isOpeningStockReference(integrationRef, lowDescription)) {
      displayType = 'Açılış Stoğu';
    } else if (_isSaleReference(integrationRef)) {
      displayType = 'Satış Yapıldı';
    } else if (_isPurchaseReference(integrationRef)) {
      displayType = 'Alış Yapıldı';
    } else if (_isProductionOutputReference(integrationRef, lowDescription)) {
      displayType = 'Üretim Çıkışı';
    } else if (_isProductionInputReference(fallbackType, lowDescription)) {
      displayType = 'Üretim Girişi';
    } else if (_isWarehouseTransferType(fallbackType)) {
      displayType = isIncoming ? 'Devir Giriş' : 'Devir Çıkış';
    } else if (_isShipmentType(fallbackType)) {
      displayType = 'Sevkiyat';
    }

    final String description =
        tx['aciklama']?.toString() ?? tx['description']?.toString() ?? '';
    return _RaporIslemSunumu(
      islem: displayType,
      aciklama: description.trim().isEmpty ? '-' : description,
      aciklama2:
          tx['aciklama2']?.toString() ?? tx['aciklama_2']?.toString() ?? '',
    );
  }

  _RaporIslemSunumu _genelHareketSunumunuHazirla(Map<String, dynamic> tx) {
    final int sourceMenuIndex = _toInt(tx['source_menu_index']) ?? -1;
    final Map<String, dynamic> normalized = <String, dynamic>{
      ...tx,
      'islem_turu': tx['islem_turu'] ?? tx['islem'],
      'aciklama2': tx['aciklama2'] ?? tx['aciklama_2'],
    };
    switch (sourceMenuIndex) {
      case TabAciciScope.cariKartiIndex:
        return _cariIslemSunumunuHazirla(normalized);
      case 13:
        return _finansIslemSunumunuHazirla(
          normalized,
          mod: _FinansRaporModu.kasa,
        );
      case 15:
        return _finansIslemSunumunuHazirla(
          normalized,
          mod: _FinansRaporModu.banka,
        );
      case 16:
        return _finansIslemSunumunuHazirla(
          normalized,
          mod: _FinansRaporModu.krediKarti,
        );
      default:
        final String islem = normalized['islem_turu']?.toString() ?? '-';
        final String aciklama = normalized['aciklama']?.toString() ?? '-';
        return _RaporIslemSunumu(
          islem: islem,
          aciklama: aciklama.trim().isEmpty ? '-' : aciklama,
          aciklama2: normalized['aciklama2']?.toString() ?? '',
        );
    }
  }

  bool _cariIslemGirisMi(String rawType, String yon) {
    final String lowType = rawType.toLowerCase();
    final String lowYon = yon.toLowerCase();
    return lowYon.contains('alacak') ||
        lowType.contains('tahsilat') ||
        lowType.contains('alış') ||
        lowType.contains('alis') ||
        lowType.contains('girdi') ||
        lowType.contains('giriş') ||
        lowType.contains('giris') ||
        lowType.contains('alındı') ||
        lowType.contains('alindi') ||
        lowType.contains('alınan') ||
        lowType.contains('alinan');
  }

  bool _isIncomingFinanceType(String lowType) {
    return lowType.contains('tahsil') ||
        lowType.contains('girdi') ||
        lowType.contains('giriş') ||
        lowType.contains('giris') ||
        lowType.contains('havale') ||
        lowType.contains('eft');
  }

  bool _isOutgoingFinanceType(String lowType) {
    return lowType.contains('ödeme') ||
        lowType.contains('odeme') ||
        lowType.contains('harcama') ||
        lowType.contains('çıktı') ||
        lowType.contains('cikti') ||
        lowType.contains('çıkış') ||
        lowType.contains('cikis');
  }

  bool _isSaleReference(String integrationRef) {
    final String lowRef = integrationRef.toLowerCase();
    return lowRef.startsWith('sale-') || lowRef.startsWith('retail-');
  }

  bool _isPurchaseReference(String integrationRef) {
    return integrationRef.toLowerCase().startsWith('purchase-');
  }

  bool _isCurrentAccountPaymentReference(String integrationRef) {
    final String lowRef = integrationRef.toLowerCase();
    return lowRef.startsWith('cari-pav-cash-') ||
        lowRef.startsWith('cari-pav-bank-') ||
        lowRef.startsWith('cari-pav-credit_card-');
  }

  bool _isCurrentAccountFinanceSourceType(String lowType) {
    return lowType == 'kasa' ||
        lowType == 'banka' ||
        lowType == 'kredi kartı' ||
        lowType == 'kredi karti';
  }

  bool _isCurrentAccountFinanceLocation(String rawLocation) {
    final String lowLocation = rawLocation.trim().toLowerCase();
    return lowLocation == 'cari hesap' ||
        lowLocation == 'current_account' ||
        lowLocation == 'cari işlem' ||
        lowLocation == 'cari islem';
  }

  bool _isCheckReference(String rawType, String integrationRef) {
    final String lowType = rawType.toLowerCase();
    final String lowRef = integrationRef.toLowerCase();
    return lowType.contains('çek') ||
        lowType.contains('cek') ||
        lowRef.startsWith('cheque') ||
        lowRef.startsWith('cek-');
  }

  bool _isNoteReference(String rawType, String integrationRef) {
    final String lowType = rawType.toLowerCase();
    final String lowRef = integrationRef.toLowerCase();
    return lowType.contains('senet') ||
        lowRef.startsWith('note') ||
        lowRef.startsWith('senet-') ||
        lowRef.contains('promissory');
  }

  bool _isAutomatedCheckNoteDescription(String description) {
    final String lowDescription = description.toLowerCase();
    return lowDescription.contains('tahsilat') ||
        lowDescription.contains('ödeme') ||
        lowDescription.contains('odeme') ||
        lowDescription.contains('no:');
  }

  bool _isOpeningStockReference(String integrationRef, String lowDescription) {
    final String lowRef = integrationRef.toLowerCase();
    return lowRef == 'opening_stock' ||
        lowRef.contains('opening_stock') ||
        lowDescription.contains('açılış') ||
        lowDescription.contains('acilis');
  }

  bool _isProductionReference(String integrationRef, String lowDescription) {
    final String lowRef = integrationRef.toLowerCase();
    return lowRef.contains('production') ||
        lowDescription.contains('üretim') ||
        lowDescription.contains('uretim');
  }

  bool _isTransferReference(String integrationRef, String lowDescription) {
    final String lowRef = integrationRef.toLowerCase();
    return lowRef.contains('transfer') || lowDescription.contains('devir');
  }

  bool _isProductionOutputReference(
    String integrationRef,
    String lowDescription,
  ) {
    final String lowRef = integrationRef.toLowerCase();
    return lowRef == 'production_output' ||
        lowDescription.contains('üretim (çıktı)') ||
        lowDescription.contains('uretim (cikti)');
  }

  bool _isProductionInputReference(String rawType, String lowDescription) {
    final String lowType = rawType.toLowerCase();
    return lowType.contains('uretim_giris') ||
        lowType.contains('üretim (girdi)') ||
        lowType.contains('uretim (girdi)') ||
        lowDescription.contains('üretim (girdi)') ||
        lowDescription.contains('üretim (giriş)') ||
        lowDescription.contains('uretim (girdi)') ||
        lowDescription.contains('uretim (giris)');
  }

  bool _isWarehouseTransferType(String rawType) {
    final String lowType = rawType.toLowerCase();
    return lowType.contains('devir');
  }

  bool _isShipmentType(String rawType) {
    final String lowType = rawType.toLowerCase();
    return lowType.contains('sevkiyat') || lowType.contains('transfer');
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String _formatDate(DateTime? date, {bool includeTime = false}) {
    if (date == null) return '-';
    return DateFormat(
      includeTime ? 'dd.MM.yyyy HH:mm' : 'dd.MM.yyyy',
    ).format(date);
  }

  String _formatMoney(dynamic amount, {String currency = 'TRY'}) {
    final value = _toDouble(amount);
    final int decimalDigits = _guncelAyarlar?.fiyatOndalik ?? 2;
    final String formatted = FormatYardimcisi.sayiFormatlaOndalikli(
      value,
      binlik: _guncelAyarlar?.binlikAyiraci ?? '.',
      ondalik: _guncelAyarlar?.ondalikAyiraci ?? ',',
      decimalDigits: decimalDigits,
    );
    final String currencyText = _formatCurrencySuffix(currency);
    return currencyText.isEmpty ? formatted : '$formatted $currencyText';
  }

  String _formatNumber(dynamic amount) {
    final int decimalDigits = _guncelAyarlar?.miktarOndalik ?? 2;
    return FormatYardimcisi.sayiFormatlaOran(
      amount,
      binlik: _guncelAyarlar?.binlikAyiraci ?? '.',
      ondalik: _guncelAyarlar?.ondalikAyiraci ?? ',',
      decimalDigits: decimalDigits,
    );
  }

  String _formatQuantity(dynamic amount) {
    final int decimalDigits = _guncelAyarlar?.miktarOndalik ?? 2;
    return FormatYardimcisi.sayiFormatlaOran(
      amount,
      binlik: _guncelAyarlar?.binlikAyiraci ?? '.',
      ondalik: _guncelAyarlar?.ondalikAyiraci ?? ',',
      decimalDigits: decimalDigits,
    );
  }

  String _formatExchangeRate(dynamic rate) {
    if (rate == null || rate.toString().isEmpty) return '';
    final value = _toDouble(rate);
    final int decimalDigits = _guncelAyarlar?.kurOndalik ?? 4;
    return FormatYardimcisi.sayiFormatlaOndalikli(
      value,
      binlik: _guncelAyarlar?.binlikAyiraci ?? '.',
      ondalik: _guncelAyarlar?.ondalikAyiraci ?? ',',
      decimalDigits: decimalDigits,
    );
  }

  String _formatCurrencySuffix(String currency) {
    final String normalized = currency.trim().toUpperCase();
    if (normalized.isEmpty) return '';
    if (_guncelAyarlar?.sembolGoster ?? true) {
      return FormatYardimcisi.paraBirimiSembol(normalized);
    }
    return normalized;
  }
}

class _RaporKolonStandardi {
  const _RaporKolonStandardi({required this.minWidth, this.alignment});

  final double minWidth;
  final Alignment? alignment;
}

const Map<String, _RaporKolonStandardi>
_kolonStandartlari = <String, _RaporKolonStandardi>{
  'islem': _RaporKolonStandardi(minWidth: 160),
  'tur': _RaporKolonStandardi(minWidth: 130),
  'durum': _RaporKolonStandardi(minWidth: 120),
  'modul': _RaporKolonStandardi(minWidth: 140),
  'kategori': _RaporKolonStandardi(minWidth: 150),
  'grup': _RaporKolonStandardi(minWidth: 150),
  'cari': _RaporKolonStandardi(minWidth: 220),
  'hesap': _RaporKolonStandardi(minWidth: 220),
  'ilgili_hesap': _RaporKolonStandardi(minWidth: 220),
  'urun': _RaporKolonStandardi(minWidth: 220),
  'urun_adi': _RaporKolonStandardi(minWidth: 220),
  'kalem': _RaporKolonStandardi(minWidth: 220),
  'yer_adi': _RaporKolonStandardi(minWidth: 190),
  'depo': _RaporKolonStandardi(minWidth: 160),
  'kaynak': _RaporKolonStandardi(minWidth: 160),
  'hedef': _RaporKolonStandardi(minWidth: 160),
  'yer': _RaporKolonStandardi(minWidth: 120),
  'yer_2': _RaporKolonStandardi(minWidth: 120),
  'kod': _RaporKolonStandardi(minWidth: 120),
  'urun_kodu': _RaporKolonStandardi(minWidth: 120),
  'yer_kodu': _RaporKolonStandardi(minWidth: 110),
  'belge_no': _RaporKolonStandardi(minWidth: 130),
  'belge_ref': _RaporKolonStandardi(minWidth: 130),
  'fatura_no': _RaporKolonStandardi(minWidth: 130),
  'irsaliye_no': _RaporKolonStandardi(minWidth: 130),
  'e_belge': _RaporKolonStandardi(minWidth: 120),
  'ref': _RaporKolonStandardi(minWidth: 130),
  'no': _RaporKolonStandardi(minWidth: 120),
  'portfoy': _RaporKolonStandardi(minWidth: 130),
  'termin': _RaporKolonStandardi(minWidth: 120),
  'donusum': _RaporKolonStandardi(minWidth: 120),
  'kur': _RaporKolonStandardi(minWidth: 70, alignment: Alignment.centerRight),
  'tarih': _RaporKolonStandardi(minWidth: 150),
  'vade': _RaporKolonStandardi(minWidth: 120),
  'vade_tarihi': _RaporKolonStandardi(minWidth: 120),
  'donem': _RaporKolonStandardi(minWidth: 220),
  'son_islem': _RaporKolonStandardi(minWidth: 140),
  'son_hareket': _RaporKolonStandardi(minWidth: 140),
  'son_islem_tarihi': _RaporKolonStandardi(minWidth: 140),
  'son_islem_turu': _RaporKolonStandardi(minWidth: 170),
  'tutar': _RaporKolonStandardi(
    minWidth: 130,
    alignment: Alignment.centerRight,
  ),
  'ara_toplam': _RaporKolonStandardi(
    minWidth: 130,
    alignment: Alignment.centerRight,
  ),
  'kdv': _RaporKolonStandardi(minWidth: 120, alignment: Alignment.centerRight),
  'vergi': _RaporKolonStandardi(
    minWidth: 120,
    alignment: Alignment.centerRight,
  ),
  'genel_toplam': _RaporKolonStandardi(
    minWidth: 140,
    alignment: Alignment.centerRight,
  ),
  'borc': _RaporKolonStandardi(minWidth: 130, alignment: Alignment.centerRight),
  'alacak': _RaporKolonStandardi(
    minWidth: 130,
    alignment: Alignment.centerRight,
  ),
  'net_bakiye': _RaporKolonStandardi(
    minWidth: 140,
    alignment: Alignment.centerRight,
  ),
  'maliyet': _RaporKolonStandardi(
    minWidth: 120,
    alignment: Alignment.centerRight,
  ),
  'stok_degeri': _RaporKolonStandardi(
    minWidth: 130,
    alignment: Alignment.centerRight,
  ),
  'alis': _RaporKolonStandardi(minWidth: 120, alignment: Alignment.centerRight),
  'satis1': _RaporKolonStandardi(
    minWidth: 120,
    alignment: Alignment.centerRight,
  ),
  'satis2': _RaporKolonStandardi(
    minWidth: 120,
    alignment: Alignment.centerRight,
  ),
  'satis3': _RaporKolonStandardi(
    minWidth: 120,
    alignment: Alignment.centerRight,
  ),
  'ciro': _RaporKolonStandardi(minWidth: 130, alignment: Alignment.centerRight),
  'gider': _RaporKolonStandardi(
    minWidth: 130,
    alignment: Alignment.centerRight,
  ),
  'brut_kar': _RaporKolonStandardi(
    minWidth: 130,
    alignment: Alignment.centerRight,
  ),
  'net_kar': _RaporKolonStandardi(
    minWidth: 130,
    alignment: Alignment.centerRight,
  ),
  'tutar_etkisi': _RaporKolonStandardi(
    minWidth: 130,
    alignment: Alignment.centerRight,
  ),
  'fark': _RaporKolonStandardi(minWidth: 120, alignment: Alignment.centerRight),
  'giris': _RaporKolonStandardi(
    minWidth: 105,
    alignment: Alignment.centerRight,
  ),
  'cikis': _RaporKolonStandardi(
    minWidth: 105,
    alignment: Alignment.centerRight,
  ),
  'miktar': _RaporKolonStandardi(
    minWidth: 100,
    alignment: Alignment.centerRight,
  ),
  'stok': _RaporKolonStandardi(minWidth: 100, alignment: Alignment.centerRight),
  'mevcut_stok': _RaporKolonStandardi(
    minWidth: 100,
    alignment: Alignment.centerRight,
  ),
  'kritik_stok': _RaporKolonStandardi(
    minWidth: 100,
    alignment: Alignment.centerRight,
  ),
  'kalem_sayisi': _RaporKolonStandardi(
    minWidth: 100,
    alignment: Alignment.centerRight,
  ),
  'kayit_sayisi': _RaporKolonStandardi(
    minWidth: 110,
    alignment: Alignment.centerRight,
  ),
  'toplam_miktar': _RaporKolonStandardi(
    minWidth: 120,
    alignment: Alignment.centerRight,
  ),
  // Kar/Zarar (Ürün bazlı)
  'ozellik1': _RaporKolonStandardi(minWidth: 120),
  'ozellik2': _RaporKolonStandardi(minWidth: 120),
  'ozellik3': _RaporKolonStandardi(minWidth: 120),
  'devreden': _RaporKolonStandardi(
    minWidth: 110,
    alignment: Alignment.centerRight,
  ),
  'eklenen': _RaporKolonStandardi(
    minWidth: 110,
    alignment: Alignment.centerRight,
  ),
  'devreden_eklenen': _RaporKolonStandardi(
    minWidth: 140,
    alignment: Alignment.centerRight,
  ),
  'satilan': _RaporKolonStandardi(
    minWidth: 110,
    alignment: Alignment.centerRight,
  ),
  'kalan': _RaporKolonStandardi(
    minWidth: 110,
    alignment: Alignment.centerRight,
  ),
  'dev_ekl_stok_degeri': _RaporKolonStandardi(
    minWidth: 170,
    alignment: Alignment.centerRight,
  ),
  'sat_mal_top_alis_degeri': _RaporKolonStandardi(
    minWidth: 190,
    alignment: Alignment.centerRight,
  ),
  'toplam_satis_degeri': _RaporKolonStandardi(
    minWidth: 170,
    alignment: Alignment.centerRight,
  ),
  'kalan_stok_degeri': _RaporKolonStandardi(
    minWidth: 170,
    alignment: Alignment.centerRight,
  ),
  'birim': _RaporKolonStandardi(minWidth: 90),
  'odeme_turu': _RaporKolonStandardi(minWidth: 130),
  'odeme_tipi': _RaporKolonStandardi(minWidth: 130),
  'aciklama': _RaporKolonStandardi(minWidth: 220),
  'aciklama_2': _RaporKolonStandardi(minWidth: 180),
  'kullanici': _RaporKolonStandardi(minWidth: 110),
};

enum _CariRaporModu { satis, alis, karma, ekstre }

enum _FinansRaporModu { kasa, banka, krediKarti }

class _RaporIslemSunumu {
  const _RaporIslemSunumu({
    required this.islem,
    required this.aciklama,
    this.aciklama2 = '',
  });

  final String islem;
  final String aciklama;
  final String aciklama2;
}
