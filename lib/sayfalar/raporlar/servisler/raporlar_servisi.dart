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

  static final List<RaporSecenegi> _raporlar = <RaporSecenegi>[
    RaporSecenegi(
      id: 'all_movements',
      labelKey: 'reports.items.all_movements',
      category: RaporKategori.genel,
      icon: Icons.alt_route_rounded,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.kullanici,
        RaporFiltreTuru.minTutar,
        RaporFiltreTuru.maxTutar,
      },
    ),
    RaporSecenegi(
      id: 'purchase_sales_movements',
      labelKey: 'reports.items.purchase_sales_movements',
      category: RaporKategori.satisAlis,
      icon: Icons.compare_arrows_rounded,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.cari,
        RaporFiltreTuru.kullanici,
        RaporFiltreTuru.minTutar,
        RaporFiltreTuru.maxTutar,
      },
    ),
    RaporSecenegi(
      id: 'product_movements',
      labelKey: 'reports.items.product_movements',
      category: RaporKategori.stokDepo,
      icon: Icons.inventory_2_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.urun,
        RaporFiltreTuru.depo,
        RaporFiltreTuru.kullanici,
        RaporFiltreTuru.minMiktar,
        RaporFiltreTuru.maxMiktar,
      },
    ),
    RaporSecenegi(
      id: 'product_shipment_movements',
      labelKey: 'reports.items.product_shipment_movements',
      category: RaporKategori.stokDepo,
      icon: Icons.local_shipping_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.depo,
        RaporFiltreTuru.kullanici,
      },
    ),
    RaporSecenegi(
      id: 'profit_loss',
      labelKey: 'reports.items.profit_loss',
      category: RaporKategori.genel,
      icon: Icons.show_chart_rounded,
      supportedFilters: {RaporFiltreTuru.tarihAraligi},
    ),
    RaporSecenegi(
      id: 'balance_list',
      labelKey: 'reports.items.balance_list',
      category: RaporKategori.genel,
      icon: Icons.account_balance_wallet_outlined,
      supportedFilters: {
        RaporFiltreTuru.cari,
        RaporFiltreTuru.kasa,
        RaporFiltreTuru.banka,
        RaporFiltreTuru.krediKarti,
      },
    ),
    RaporSecenegi(
      id: 'ba_bs_list',
      labelKey: 'reports.items.ba_bs_list',
      category: RaporKategori.genel,
      icon: Icons.receipt_long_outlined,
      supported: false,
      disabledReasonKey: 'reports.disabled.ba_bs',
    ),
    RaporSecenegi(
      id: 'receivables_payables',
      labelKey: 'reports.items.receivables_payables',
      category: RaporKategori.genel,
      icon: Icons.payments_outlined,
      supportedFilters: {
        RaporFiltreTuru.cari,
        RaporFiltreTuru.minTutar,
        RaporFiltreTuru.maxTutar,
      },
    ),
    RaporSecenegi(
      id: 'vat_accounting',
      labelKey: 'reports.items.vat_accounting',
      category: RaporKategori.genel,
      icon: Icons.percent_rounded,
      supported: false,
      disabledReasonKey: 'reports.disabled.vat',
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
        RaporFiltreTuru.depo,
        RaporFiltreTuru.urun,
        RaporFiltreTuru.urunGrubu,
      },
    ),
    RaporSecenegi(
      id: 'warehouse_shipment_list',
      labelKey: 'reports.items.warehouse_shipment_list',
      category: RaporKategori.stokDepo,
      icon: Icons.move_down_outlined,
      supportedFilters: {
        RaporFiltreTuru.tarihAraligi,
        RaporFiltreTuru.depo,
        RaporFiltreTuru.kullanici,
      },
    ),
    RaporSecenegi(
      id: 'stock_early_warning',
      labelKey: 'reports.items.stock_early_warning',
      category: RaporKategori.stokDepo,
      icon: Icons.warning_amber_rounded,
      supportedFilters: {RaporFiltreTuru.urunGrubu, RaporFiltreTuru.depo},
    ),
    RaporSecenegi(
      id: 'stock_definition_values',
      labelKey: 'reports.items.stock_definition_values',
      category: RaporKategori.stokDepo,
      icon: Icons.dataset_outlined,
      supportedFilters: {
        RaporFiltreTuru.urun,
        RaporFiltreTuru.urunGrubu,
        RaporFiltreTuru.durum,
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
      'depo': filtreler.depoId,
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

      final kaynaklar = RaporFiltreKaynaklari(
        // Büyük DB için preload yerine typeahead kullanıyoruz.
        cariler: const <RaporSecimSecenegi>[],
        urunler: const <RaporSecimSecenegi>[],
        urunGruplari: urunGruplari,
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
        return _buildOptimizedCariRapor(
          rapor,
          filtreler,
          mod: _CariRaporModu.karma,
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
              'tarih': _formatDate(tarih),
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
        _column('tarih', 'common.date', 120),
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
    final kullaniciAdi = await _resolveKullaniciAdi(filtreler.kullaniciId);

    String sortExpr(String? key) {
      switch (key) {
        case 'tarih':
          return 'base.tarih';
        case 'no':
          return "COALESCE(base.integration_ref, '')";
        case 'kaynak':
          return "COALESCE(base.kaynak, '')";
        case 'hedef':
          return "COALESCE(base.hedef, '')";
        case 'urun':
          return "COALESCE((SELECT item->>'name' FROM jsonb_array_elements(COALESCE(base.items, '[]'::jsonb)) item LIMIT 1), '')";
        case 'miktar':
          return "(SELECT COALESCE(SUM((COALESCE(item->>'quantity','0'))::numeric), 0) FROM jsonb_array_elements(COALESCE(base.items, '[]'::jsonb)) item)";
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
    if (filtreler.depoId != null) {
      params['depoId'] = filtreler.depoId;
      where.add(
        '(s.source_warehouse_id = @depoId OR s.dest_warehouse_id = @depoId)',
      );
    }
    if (_emptyToNull(kullaniciAdi) != null) {
      params['kullanici'] = _emptyToNull(kullaniciAdi);
      where.add("COALESCE(s.created_by, '') = @kullanici");
    }

    _addSearchCondition(where, params, 's.search_tags', arama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final baseSelect =
        '''
      SELECT
        s.id,
        s.date AS tarih,
        s.description,
        s.items,
        s.integration_ref,
        d1.ad AS kaynak,
        d2.ad AS hedef,
        s.created_by AS kullanici
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
          final double toplamMiktar = detailItems.fold<double>(
            0.0,
            (sum, e) => sum + _toDouble(e['quantity']),
          );

          return RaporSatiri(
            id: 'sevkiyat_${item['id']}',
            cells: {
              'tarih': _formatDate(tarih, includeTime: true),
              'no': item['integration_ref']?.toString() ?? '#${item['id']}',
              'kaynak': item['kaynak']?.toString() ?? '-',
              'hedef': item['hedef']?.toString() ?? '-',
              'urun': detailItems.isEmpty
                  ? '-'
                  : detailItems.first['name']?.toString() ?? '-',
              'miktar': _formatNumber(toplamMiktar),
              'durum': tr('common.active'),
              'kullanici': item['kullanici']?.toString() ?? '-',
            },
            details: {
              tr('common.description'): item['description']?.toString() ?? '-',
              tr('reports.columns.item_count'): detailItems.length.toString(),
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
              'no': item['integration_ref']?.toString(),
              'kaynak': item['kaynak']?.toString(),
              'hedef': item['hedef']?.toString(),
              'miktar': toplamMiktar,
              'kullanici': item['kullanici']?.toString(),
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
          FROM shipments s
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

    String sortExpr(String? key) {
      switch (key) {
        case 'depo':
          return "COALESCE(base.depo_ad, '')";
        case 'urun_kodu':
          return "COALESCE(base.urun_kodu, '')";
        case 'urun_adi':
          return "COALESCE(base.urun_adi, '')";
        case 'birim':
          return "COALESCE(base.birim, '')";
        case 'stok':
          return 'base.stok';
        default:
          return "COALESCE(base.urun_adi, '')";
      }
    }

    final where = <String>['ws.quantity > 0'];
    final params = <String, dynamic>{};

    if (filtreler.depoId != null) {
      params['depoId'] = filtreler.depoId;
      where.add('ws.warehouse_id = @depoId');
    }
    if (_emptyToNull(filtreler.urunKodu) != null) {
      params['urunKodu'] = filtreler.urunKodu;
      where.add('ws.product_code = @urunKodu');
    }
    if (_emptyToNull(filtreler.urunGrubu) != null) {
      params['grup'] = filtreler.urunGrubu;
      where.add("COALESCE(p.grubu, '') = @grup");
    }

    _addSearchConditionAny(where, params, [
      'p.search_tags',
      'd.search_tags',
    ], arama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final baseSelect =
        '''
      SELECT
        ((ws.warehouse_id::bigint << 32) + COALESCE(p.id::bigint, ABS(hashtext(ws.product_code))::bigint)) AS gid,
        ws.warehouse_id,
        d.kod AS depo_kod,
        d.ad AS depo_ad,
        ws.product_code AS urun_kodu,
        COALESCE(p.ad, ws.product_code) AS urun_adi,
        COALESCE(p.birim, 'Adet') AS birim,
        ws.quantity AS stok,
        p.barkod,
        p.grubu,
        p.ozellikler
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
          final double miktar = _toDouble(item['stok']);
          final String depoLabel =
              '${item['depo_kod'] ?? '-'} - ${item['depo_ad'] ?? '-'}';
          final String ozellikler = item['ozellikler']?.toString() ?? '';
          return RaporSatiri(
            id: 'depo_stok_${item['warehouse_id']}_${item['urun_kodu']}',
            cells: {
              'depo': depoLabel,
              'urun_kodu': item['urun_kodu']?.toString() ?? '-',
              'urun_adi': item['urun_adi']?.toString() ?? '-',
              'birim': item['birim']?.toString() ?? '-',
              'stok': _formatNumber(miktar),
              'kritik_stok': '-',
              'durum': tr('common.active'),
              'maliyet': '-',
              'stok_degeri': '-',
            },
            details: {
              tr('reports.columns.group'): item['grubu']?.toString() ?? '-',
              tr('reports.columns.features'): ozellikler.trim().isEmpty
                  ? '-'
                  : ozellikler,
              tr('common.barcode'): item['barkod']?.toString() ?? '-',
            },
            sourceMenuIndex: 6,
            sourceSearchQuery: item['depo_ad']?.toString(),
            sortValues: {
              'depo': item['depo_ad'],
              'urun_kodu': item['urun_kodu'],
              'urun_adi': item['urun_adi'],
              'stok': miktar,
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
          FROM warehouse_stocks ws
          INNER JOIN depots d ON d.id = ws.warehouse_id
          LEFT JOIN products p ON p.kod = ws.product_code
          $whereSql
          ''', params);
        final int kayit = rows.isEmpty
            ? 0
            : (rows.first['kayit'] as num?)?.toInt() ?? 0;
        return [
          RaporOzetKarti(
            labelKey: 'reports.summary.total_stock_rows',
            value: kayit.toString(),
            icon: Icons.warehouse_outlined,
            accentColor: AppPalette.slate,
          ),
        ];
      },
    );

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
    final kullaniciAdi = await _resolveKullaniciAdi(filtreler.kullaniciId);

    String sortExpr(String? key) {
      switch (key) {
        case 'tarih':
          return 'base.tarih';
        case 'no':
          return "COALESCE(base.integration_ref, '')";
        case 'depo':
          return "COALESCE(base.depo, '')";
        case 'hedef':
          return "COALESCE(base.hedef, '')";
        case 'kalem_sayisi':
          return "jsonb_array_length(COALESCE(base.items, '[]'::jsonb))";
        case 'toplam_miktar':
          return "(SELECT COALESCE(SUM((COALESCE(item->>'quantity','0'))::numeric), 0) FROM jsonb_array_elements(COALESCE(base.items, '[]'::jsonb)) item)";
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
    if (filtreler.depoId != null) {
      params['depoId'] = filtreler.depoId;
      where.add(
        '(s.source_warehouse_id = @depoId OR s.dest_warehouse_id = @depoId)',
      );
    }
    if (_emptyToNull(kullaniciAdi) != null) {
      params['kullanici'] = _emptyToNull(kullaniciAdi);
      where.add("COALESCE(s.created_by, '') = @kullanici");
    }

    _addSearchCondition(where, params, 's.search_tags', arama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final baseSelect =
        '''
      SELECT
        s.id,
        s.date AS tarih,
        s.description,
        s.items,
        s.integration_ref,
        d1.ad AS depo,
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
          final double toplamMiktar = detailItems.fold<double>(
            0.0,
            (sum, e) => sum + _toDouble(e['quantity']),
          );
          return RaporSatiri(
            id: 'depo_sevkiyat_${item['id']}',
            cells: {
              'tarih': _formatDate(tarih, includeTime: true),
              'no': item['integration_ref']?.toString() ?? '#${item['id']}',
              'depo': item['depo']?.toString() ?? '-',
              'hedef': item['hedef']?.toString() ?? '-',
              'kalem_sayisi': detailItems.length.toString(),
              'toplam_miktar': _formatNumber(toplamMiktar),
              'durum': tr('common.active'),
              'kullanici': item['kullanici']?.toString() ?? '-',
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
                : _detailTableFromItems(
                    detailItems,
                    title: tr('common.products'),
                  ),
            expandable: detailItems.isNotEmpty,
            sourceMenuIndex: 6,
            sourceSearchQuery: item['integration_ref']?.toString(),
            sortValues: {
              'tarih': tarih,
              'no': item['integration_ref']?.toString(),
              'depo': item['depo']?.toString(),
              'hedef': item['hedef']?.toString(),
              'kalem_sayisi': detailItems.length,
              'toplam_miktar': toplamMiktar,
              'kullanici': item['kullanici']?.toString(),
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
          FROM shipments s
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
        case 'net_bakiye':
          return 'base.net_bakiye';
        default:
          return 'base.net_bakiye';
      }
    }

    final params = <String, dynamic>{'companyId': _companyId};

    final cariWhere = <String>[];
    if (filtreler.cariId != null) {
      cariWhere.add('ca.id = @cariId');
      params['cariId'] = filtreler.cariId;
    }
    _addSearchCondition(cariWhere, params, 'ca.search_tags', arama);

    final kasaWhere = <String>[
      "COALESCE(cr.company_id, '$_defaultCompanyId') = @companyId",
    ];
    if (filtreler.kasaId != null) {
      kasaWhere.add('cr.id = @kasaId');
      params['kasaId'] = filtreler.kasaId;
    }
    _addSearchCondition(kasaWhere, params, 'cr.search_tags', arama);

    final bankaWhere = <String>[
      "COALESCE(b.company_id, '$_defaultCompanyId') = @companyId",
    ];
    if (filtreler.bankaId != null) {
      bankaWhere.add('b.id = @bankaId');
      params['bankaId'] = filtreler.bankaId;
    }
    _addSearchCondition(bankaWhere, params, 'b.search_tags', arama);

    final kartWhere = <String>[
      "COALESCE(cc.company_id, '$_defaultCompanyId') = @companyId",
    ];
    if (filtreler.krediKartiId != null) {
      kartWhere.add('cc.id = @krediKartiId');
      params['krediKartiId'] = filtreler.krediKartiId;
    }
    _addSearchCondition(kartWhere, params, 'cc.search_tags', arama);

    final String cariWhereSql = cariWhere.isEmpty
        ? ''
        : 'WHERE ${cariWhere.join(' AND ')}';
    final String kasaWhereSql = kasaWhere.isEmpty
        ? ''
        : 'WHERE ${kasaWhere.join(' AND ')}';
    final String bankaWhereSql = bankaWhere.isEmpty
        ? ''
        : 'WHERE ${bankaWhere.join(' AND ')}';
    final String kartWhereSql = kartWhere.isEmpty
        ? ''
        : 'WHERE ${kartWhere.join(' AND ')}';

    final unionSelect =
        '''
      SELECT
        ((0::bigint << 48) + ca.id::bigint) AS gid,
        'cari'::text AS kaynak,
        ca.id::bigint AS kaynak_id,
        ca.kod_no AS kod,
        ca.adi AS hesap,
        COALESCE(ca.hesap_turu, '') AS tur_sort,
        COALESCE(ca.para_birimi, 'TRY') AS para_birimi,
        COALESCE(ca.bakiye_borc, 0) AS borc,
        COALESCE(ca.bakiye_alacak, 0) AS alacak,
        (COALESCE(ca.bakiye_borc, 0) - COALESCE(ca.bakiye_alacak, 0)) AS net_bakiye,
        COALESCE(ca.vade_gun, 0) AS vade_gun
      FROM current_accounts ca
      $cariWhereSql

      UNION ALL

      SELECT
        ((13::bigint << 48) + cr.id::bigint) AS gid,
        'kasa'::text AS kaynak,
        cr.id::bigint AS kaynak_id,
        COALESCE(cr.code, '') AS kod,
        COALESCE(cr.name, '') AS hesap,
        'cash'::text AS tur_sort,
        COALESCE(cr.currency, 'TRY') AS para_birimi,
        CASE WHEN COALESCE(cr.balance, 0) < 0 THEN ABS(cr.balance) ELSE 0 END AS borc,
        CASE WHEN COALESCE(cr.balance, 0) >= 0 THEN ABS(cr.balance) ELSE 0 END AS alacak,
        COALESCE(cr.balance, 0) AS net_bakiye,
        0::int AS vade_gun
      FROM cash_registers cr
      $kasaWhereSql

      UNION ALL

      SELECT
        ((15::bigint << 48) + b.id::bigint) AS gid,
        'banka'::text AS kaynak,
        b.id::bigint AS kaynak_id,
        COALESCE(b.code, '') AS kod,
        COALESCE(b.name, '') AS hesap,
        'bank'::text AS tur_sort,
        COALESCE(b.currency, 'TRY') AS para_birimi,
        CASE WHEN COALESCE(b.balance, 0) < 0 THEN ABS(b.balance) ELSE 0 END AS borc,
        CASE WHEN COALESCE(b.balance, 0) >= 0 THEN ABS(b.balance) ELSE 0 END AS alacak,
        COALESCE(b.balance, 0) AS net_bakiye,
        0::int AS vade_gun
      FROM banks b
      $bankaWhereSql

      UNION ALL

      SELECT
        ((16::bigint << 48) + cc.id::bigint) AS gid,
        'kart'::text AS kaynak,
        cc.id::bigint AS kaynak_id,
        COALESCE(cc.code, '') AS kod,
        COALESCE(cc.name, '') AS hesap,
        'card'::text AS tur_sort,
        COALESCE(cc.currency, 'TRY') AS para_birimi,
        CASE WHEN COALESCE(cc.balance, 0) < 0 THEN ABS(cc.balance) ELSE 0 END AS borc,
        CASE WHEN COALESCE(cc.balance, 0) >= 0 THEN ABS(cc.balance) ELSE 0 END AS alacak,
        COALESCE(cc.balance, 0) AS net_bakiye,
        0::int AS vade_gun
      FROM credit_cards cc
      $kartWhereSql
    ''';

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($unionSelect) base
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
          final String kaynak = item['kaynak']?.toString() ?? '';
          final int kaynakId = _toInt(item['kaynak_id']) ?? 0;
          final String kod = item['kod']?.toString() ?? '-';
          final String hesap = item['hesap']?.toString() ?? '-';
          final String paraBirimi = item['para_birimi']?.toString() ?? 'TRY';
          final double borc = _toDouble(item['borc']);
          final double alacak = _toDouble(item['alacak']);
          final double net = _toDouble(item['net_bakiye']);
          final int vadeGun = (item['vade_gun'] as num?)?.toInt() ?? 0;

          String turLabel;
          int menuIndex;
          String rowId;
          switch (kaynak) {
            case 'kasa':
              turLabel = tr('transactions.source.cash');
              menuIndex = 13;
              rowId = 'bakiye_kasa_$kaynakId';
              break;
            case 'banka':
              turLabel = tr('transactions.source.bank');
              menuIndex = 15;
              rowId = 'bakiye_banka_$kaynakId';
              break;
            case 'kart':
              turLabel = tr('transactions.source.credit_card');
              menuIndex = 16;
              rowId = 'bakiye_kart_$kaynakId';
              break;
            case 'cari':
            default:
              turLabel = IslemCeviriYardimcisi.cevir(
                item['tur_sort']?.toString() ?? '',
              );
              menuIndex = TabAciciScope.cariKartiIndex;
              rowId = 'bakiye_cari_$kaynakId';
          }

          return RaporSatiri(
            id: rowId,
            cells: {
              'kod': kod,
              'hesap': hesap,
              'tur': turLabel,
              'borc': borc > 0 ? _formatMoney(borc, currency: paraBirimi) : '-',
              'alacak': alacak > 0
                  ? _formatMoney(alacak, currency: paraBirimi)
                  : '-',
              'net_bakiye': _formatMoney(net, currency: paraBirimi),
              'vade_ozeti': kaynak == 'cari' && vadeGun > 0
                  ? '$vadeGun ${tr('reports.days')}'
                  : '-',
              'son_islem': '-',
            },
            sourceMenuIndex: menuIndex,
            sourceSearchQuery: hesap,
            amountValue: net,
            sortValues: {
              'kod': kod,
              'hesap': hesap,
              'tur': item['tur_sort']?.toString(),
              'borc': borc,
              'alacak': alacak,
              'net_bakiye': net,
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
          SELECT COALESCE(SUM(base.net_bakiye), 0) AS toplam
          FROM ($unionSelect) base
          ''', params);
        final toplam = rows.isEmpty ? 0.0 : _toDouble(rows.first['toplam']);
        return [
          RaporOzetKarti(
            labelKey: 'reports.summary.total_balance',
            value: _formatMoney(toplam),
            icon: Icons.account_balance_wallet_outlined,
            accentColor: AppPalette.slate,
          ),
        ];
      },
    );

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

    String sortExpr(String? key) {
      switch (key) {
        case 'cari':
          return "COALESCE(base.adi, '')";
        case 'tur':
          return 'base.tur_sort';
        case 'vade':
        case 'gun_farki':
          return 'base.vade_gun';
        case 'tutar':
          return 'base.tutar_abs';
        case 'durum':
          return 'base.aktif_mi';
        case 'kullanici':
          return "COALESCE(base.kullanici, '')";
        default:
          return 'base.tutar_abs';
      }
    }

    final where = <String>[
      '(COALESCE(ca.bakiye_borc, 0) <> 0 OR COALESCE(ca.bakiye_alacak, 0) <> 0)',
    ];
    final params = <String, dynamic>{};

    if (filtreler.cariId != null) {
      params['cariId'] = filtreler.cariId;
      where.add('ca.id = @cariId');
    }
    if (filtreler.minTutar != null) {
      params['minTutar'] = filtreler.minTutar;
      where.add(
        'ABS(COALESCE(ca.bakiye_alacak, 0) - COALESCE(ca.bakiye_borc, 0)) >= @minTutar',
      );
    }
    if (filtreler.maxTutar != null) {
      params['maxTutar'] = filtreler.maxTutar;
      where.add(
        'ABS(COALESCE(ca.bakiye_alacak, 0) - COALESCE(ca.bakiye_borc, 0)) <= @maxTutar',
      );
    }

    _addSearchCondition(where, params, 'ca.search_tags', arama);

    final String whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final baseSelect =
        '''
      SELECT
        ca.id,
        ca.kod_no,
        ca.adi,
        ca.para_birimi,
        ca.vade_gun,
        ca.aktif_mi,
        COALESCE(ca.created_by, '') AS kullanici,
        (COALESCE(ca.bakiye_alacak, 0) - COALESCE(ca.bakiye_borc, 0)) AS net,
        ABS(COALESCE(ca.bakiye_alacak, 0) - COALESCE(ca.bakiye_borc, 0)) AS tutar_abs,
        CASE
          WHEN COALESCE(ca.bakiye_alacak, 0) >= COALESCE(ca.bakiye_borc, 0)
          THEN 1
          ELSE 0
        END AS tur_sort
      FROM current_accounts ca
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
          final double net = _toDouble(cari['net']);
          final bool alacak = net >= 0;
          final double tutar = net.abs();
          final String paraBirimi = cari['para_birimi']?.toString() ?? 'TRY';
          final int vadeGun = (cari['vade_gun'] as num?)?.toInt() ?? 0;
          final bool aktif = cari['aktif_mi'] == true || cari['aktif_mi'] == 1;
          return RaporSatiri(
            id: 'av_${cari['id']}',
            cells: {
              'cari': '${cari['kod_no'] ?? '-'} - ${cari['adi'] ?? '-'}',
              'tur': alacak
                  ? tr('reports.badges.receivable')
                  : tr('reports.badges.payable'),
              'vade': vadeGun > 0 ? '$vadeGun ${tr('reports.days')}' : '-',
              'gun_farki': vadeGun.toString(),
              'tutar': _formatMoney(tutar, currency: paraBirimi),
              'durum': aktif ? tr('common.active') : tr('common.passive'),
              'kullanici': cari['kullanici']?.toString() ?? '-',
            },
            sourceMenuIndex: TabAciciScope.cariKartiIndex,
            sourceSearchQuery: cari['adi']?.toString(),
            amountValue: alacak ? tutar : -tutar,
            sortValues: {
              'cari': cari['adi'],
              'tur': alacak ? 1 : 0,
              'vade': vadeGun,
              'gun_farki': vadeGun,
              'tutar': tutar,
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
            COALESCE(SUM(GREATEST((COALESCE(ca.bakiye_alacak, 0) - COALESCE(ca.bakiye_borc, 0)), 0)), 0) AS receivable,
            COALESCE(SUM(GREATEST((COALESCE(ca.bakiye_borc, 0) - COALESCE(ca.bakiye_alacak, 0)), 0)), 0) AS payable
          FROM current_accounts ca
          $whereSql
          ''', params);
        final data = rows.isEmpty ? const <String, dynamic>{} : rows.first;
        final double receivable = _toDouble(data['receivable']);
        final double payable = _toDouble(data['payable']);
        return [
          RaporOzetKarti(
            labelKey: 'reports.summary.receivables_total',
            value: _formatMoney(receivable),
            icon: Icons.trending_up_rounded,
            accentColor: const Color(0xFF27AE60),
          ),
          RaporOzetKarti(
            labelKey: 'reports.summary.payables_total',
            value: _formatMoney(payable),
            icon: Icons.trending_down_rounded,
            accentColor: AppPalette.red,
          ),
        ];
      },
    );

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

    String sortExpr(String? key) {
      switch (key) {
        case 'kod':
          return "COALESCE(base.kod_no, '')";
        case 'ad':
          return "COALESCE(base.adi, '')";
        case 'tur':
          return "COALESCE(base.hesap_turu, '')";
        case 'son_islem_tarihi':
          return 'base.son_islem_tarihi';
        case 'son_islem_turu':
          return "COALESCE(base.son_islem_turu, '')";
        case 'tutar':
          return 'base.tutar';
        default:
          return 'base.son_islem_tarihi';
      }
    }

    final where = <String>[];
    final params = <String, dynamic>{};

    _addSearchCondition(where, params, 'ca.search_tags', arama);

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
        tx.son_islem_tarihi,
        tx.son_islem_turu,
        tx.tutar
      FROM current_accounts ca
      LEFT JOIN LATERAL (
        SELECT
          cat.date AS son_islem_tarihi,
          cat.source_type AS son_islem_turu,
          cat.amount AS tutar
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
          final double tutar = _toDouble(cari['tutar']);
          final String paraBirimi = cari['para_birimi']?.toString() ?? 'TRY';
          return RaporSatiri(
            id: 'son_islem_${cari['id']}',
            cells: {
              'kod': cari['kod_no']?.toString() ?? '-',
              'ad': cari['adi']?.toString() ?? '-',
              'tur': IslemCeviriYardimcisi.cevir(
                cari['hesap_turu']?.toString() ?? '-',
              ),
              'son_islem_tarihi': _formatDate(tarih, includeTime: true),
              'son_islem_turu': hasTx
                  ? IslemCeviriYardimcisi.cevir(
                      cari['son_islem_turu']?.toString() ?? '-',
                    )
                  : '-',
              'tutar': hasTx ? _formatMoney(tutar, currency: paraBirimi) : '-',
            },
            sourceMenuIndex: TabAciciScope.cariKartiIndex,
            sourceSearchQuery: cari['adi']?.toString(),
            amountValue: tutar,
            sortValues: {
              'kod': cari['kod_no'],
              'ad': cari['adi'],
              'tur': cari['hesap_turu'],
              'son_islem_tarihi': tarih,
              'tutar': tutar,
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
          'SELECT COUNT(*) AS kayit FROM current_accounts ca $whereSql',
          params,
        );
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

    final params = <String, dynamic>{};
    final catWhere = <String>[];
    final expWhere = <String>[];

    if (filtreler.baslangicTarihi != null) {
      params['baslangic'] = DateTime(
        filtreler.baslangicTarihi!.year,
        filtreler.baslangicTarihi!.month,
        filtreler.baslangicTarihi!.day,
      ).toIso8601String();
      catWhere.add('cat.date >= @baslangic');
      expWhere.add('e.tarih >= @baslangic');
    }
    if (filtreler.bitisTarihi != null) {
      params['bitis'] = DateTime(
        filtreler.bitisTarihi!.year,
        filtreler.bitisTarihi!.month,
        filtreler.bitisTarihi!.day,
      ).add(const Duration(days: 1)).toIso8601String();
      catWhere.add('cat.date < @bitis');
      expWhere.add('e.tarih < @bitis');
    }

    final String catWhereSql = catWhere.isEmpty
        ? ''
        : 'AND ${catWhere.join(' AND ')}';
    final String expWhereSql = expWhere.isEmpty
        ? ''
        : 'WHERE ${expWhere.join(' AND ')}';

    final rows = await _queryMaps(pool, '''
      SELECT
        (
          SELECT COALESCE(SUM(cat.amount), 0)
          FROM current_account_transactions cat
          WHERE
            (
              LOWER(COALESCE(cat.source_type, '')) LIKE '%satis%'
              OR LOWER(COALESCE(cat.source_type, '')) LIKE '%satış%'
            )
            $catWhereSql
        ) AS ciro,
        (
          SELECT COALESCE(SUM(cat.amount), 0)
          FROM current_account_transactions cat
          WHERE
            (
              LOWER(COALESCE(cat.source_type, '')) LIKE '%alis%'
              OR LOWER(COALESCE(cat.source_type, '')) LIKE '%alış%'
            )
            $catWhereSql
        ) AS maliyet,
        (
          SELECT COALESCE(SUM(e.tutar), 0)
          FROM expenses e
          $expWhereSql
        ) AS gider
      ''', params);

    final data = rows.isEmpty ? const <String, dynamic>{} : rows.first;
    final double ciro = _toDouble(data['ciro']);
    final double maliyet = _toDouble(data['maliyet']);
    final double giderToplam = _toDouble(data['gider']);

    final double brutKar = ciro - maliyet;
    final double netKar = brutKar - giderToplam;

    final String donem = filtreOzetiniOlustur(filtreler).isEmpty
        ? tr('common.all')
        : filtreOzetiniOlustur(filtreler);

    final List<RaporSatiri> allRows = [
      RaporSatiri(
        id: 'kar_zarar_ciro',
        cells: {
          'donem': donem,
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

    final filteredRows = _applySearch(allRows, arama);

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
      rows: filteredRows,
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
      totalCount: filteredRows.length,
      page: 1,
      pageSize: pageSize,
      hasNextPage: false,
      cursorPagination: false,
      mainTableLabel: tr(rapor.labelKey),
    );
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

          if (mod == _CariRaporModu.ekstre) {
            return RaporSatiri(
              id: 'cari_tx_${tx['id']}',
              cells: {
                'islem': IslemCeviriYardimcisi.cevir(
                  tx['islem_turu']?.toString() ?? '-',
                ),
                'tarih': _formatDate(tarih, includeTime: true),
                'tutar': _formatMoney(tutar, currency: paraBirimi),
                'bakiye_borc': bakiyeBorc > 0
                    ? _formatMoney(bakiyeBorc, currency: paraBirimi)
                    : '-',
                'bakiye_alacak': bakiyeAlacak > 0
                    ? _formatMoney(bakiyeAlacak, currency: paraBirimi)
                    : '-',
                'ilgili_hesap': tx['ilgili_hesap']?.toString() ?? '-',
                'aciklama': tx['aciklama']?.toString() ?? '-',
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
          return RaporSatiri(
            id: '${mod.name}_${tx['id']}',
            cells: {
              'tarih': _formatDate(tarih, includeTime: true),
              'hesap': tx['hesap']?.toString() ?? '-',
              'islem': tx['islem_turu']?.toString() ?? '-',
              'ilgili_hesap': tx['ilgili_hesap']?.toString() ?? '-',
              'giris': giris > 0 ? _formatMoney(giris) : '-',
              'cikis': cikis > 0 ? _formatMoney(cikis) : '-',
              'aciklama': tx['aciklama']?.toString() ?? '-',
              'kullanici': tx['kullanici']?.toString() ?? '-',
            },
            sourceMenuIndex: menuIndex,
            sourceSearchQuery: tx['hesap']?.toString(),
            amountValue: tutar,
            sortValues: {
              'tarih': tarih,
              'hesap': tx['hesap'],
              'islem': tx['islem_turu'],
              'giris': giris,
              'cikis': cikis,
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
    final kullaniciAdi = await _resolveKullaniciAdi(filtreler.kullaniciId);
    final params = <String, dynamic>{};
    final where = <String>[];

    if (filtreler.baslangicTarihi != null) {
      params['baslangic'] = DateTime(
        filtreler.baslangicTarihi!.year,
        filtreler.baslangicTarihi!.month,
        filtreler.baslangicTarihi!.day,
      ).toIso8601String();
      where.add('sm.movement_date >= @baslangic');
    }
    if (filtreler.bitisTarihi != null) {
      params['bitis'] = DateTime(
        filtreler.bitisTarihi!.year,
        filtreler.bitisTarihi!.month,
        filtreler.bitisTarihi!.day,
      ).add(const Duration(days: 1)).toIso8601String();
      where.add('sm.movement_date < @bitis');
    }
    if (_emptyToNull(filtreler.urunKodu) != null) {
      params['urunKodu'] = filtreler.urunKodu;
      where.add('p.kod = @urunKodu');
    }
    if (_emptyToNull(filtreler.urunGrubu) != null) {
      params['urunGrubu'] = filtreler.urunGrubu;
      where.add("COALESCE(p.grubu, '') = @urunGrubu");
    }
    if (filtreler.depoId != null) {
      params['depoId'] = filtreler.depoId;
      where.add('sm.warehouse_id = @depoId');
    }
    if (_emptyToNull(kullaniciAdi) != null) {
      params['kullanici'] = _emptyToNull(kullaniciAdi);
      where.add("COALESCE(sm.created_by, '') = @kullanici");
    }
    if (filtreler.minMiktar != null) {
      params['minMiktar'] = filtreler.minMiktar;
      where.add('sm.quantity >= @minMiktar');
    }
    if (filtreler.maxMiktar != null) {
      params['maxMiktar'] = filtreler.maxMiktar;
      where.add('sm.quantity <= @maxMiktar');
    }
    _addSearchConditionAny(where, params, const <String>[
      'sm.search_tags',
      'p.search_tags',
    ], arama);

    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    String sortExpr(String? key) {
      switch (key) {
        case 'tarih':
          return 'base.tarih';
        case 'urun_kodu':
          return "COALESCE(base.urun_kodu, '')";
        case 'urun_adi':
          return "COALESCE(base.urun_adi, '')";
        case 'islem':
          return "COALESCE(base.islem_turu, '')";
        case 'depo':
          return "COALESCE(base.depo_adi, '')";
        case 'giris':
        case 'cikis':
          return 'base.miktar';
        case 'maliyet':
          return 'base.birim_fiyat';
        case 'kullanici':
          return "COALESCE(base.kullanici, '')";
        default:
          return 'base.tarih';
      }
    }

    final baseSelect =
        '''
      SELECT
        sm.id,
        sm.movement_date AS tarih,
        sm.quantity AS miktar,
        sm.is_giris,
        sm.unit_price AS birim_fiyat,
        sm.description AS aciklama,
        sm.movement_type AS islem_turu,
        sm.created_by AS kullanici,
        sm.integration_ref,
        p.kod AS urun_kodu,
        p.ad AS urun_adi,
        p.birim,
        COALESCE(d.ad, '-') AS depo_adi
      FROM stock_movements sm
      INNER JOIN products p ON p.id = sm.product_id
      LEFT JOIN depots d ON d.id = sm.warehouse_id
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
          final miktar = _toDouble(tx['miktar']);
          final fiyat = _toDouble(tx['birim_fiyat']);
          final toplam = miktar * fiyat;
          final bool giris = tx['is_giris'] == true;
          return RaporSatiri(
            id: 'urun_hareket_${tx['id']}',
            cells: {
              'tarih': _formatDate(tarih, includeTime: true),
              'urun_kodu': tx['urun_kodu']?.toString() ?? '-',
              'urun_adi': tx['urun_adi']?.toString() ?? '-',
              'islem': tx['islem_turu']?.toString() ?? '-',
              'depo': tx['depo_adi']?.toString() ?? '-',
              'giris': giris ? _formatNumber(miktar) : '-',
              'cikis': giris ? '-' : _formatNumber(miktar),
              'birim': tx['birim']?.toString() ?? '-',
              'maliyet': _formatMoney(fiyat),
              'ref': tx['integration_ref']?.toString() ?? '-',
              'kullanici': tx['kullanici']?.toString() ?? '-',
            },
            sourceMenuIndex: 7,
            sourceSearchQuery: tx['urun_adi']?.toString(),
            amountValue: toplam,
            sortValues: {
              'tarih': tarih,
              'urun_kodu': tx['urun_kodu'],
              'urun_adi': tx['urun_adi'],
              'depo': tx['depo_adi'],
              'giris': giris ? miktar : 0.0,
              'cikis': giris ? 0.0 : miktar,
              'maliyet': fiyat,
              'kullanici': tx['kullanici'],
            },
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
            COALESCE(SUM(CASE WHEN sm.is_giris THEN sm.quantity ELSE 0 END), 0) AS toplam_giris,
            COALESCE(SUM(CASE WHEN sm.is_giris THEN 0 ELSE sm.quantity END), 0) AS toplam_cikis
          FROM stock_movements sm
          INNER JOIN products p ON p.id = sm.product_id
          LEFT JOIN depots d ON d.id = sm.warehouse_id
          $whereSql
        ''', params);
        final summaryData = summaryRows.isEmpty
            ? const <String, dynamic>{}
            : summaryRows.first;
        return <RaporOzetKarti>[
          RaporOzetKarti(
            labelKey: 'reports.summary.total_incoming',
            value: _formatNumber(summaryData['toplam_giris']),
            icon: Icons.south_west_rounded,
            accentColor: const Color(0xFF27AE60),
          ),
          RaporOzetKarti(
            labelKey: 'reports.summary.total_outgoing',
            value: _formatNumber(summaryData['toplam_cikis']),
            icon: Icons.north_east_rounded,
            accentColor: AppPalette.red,
          ),
        ];
      },
    );

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('tarih', 'common.date', 150),
        _column('urun_kodu', 'common.product_code', 120),
        _column('urun_adi', 'common.product_name', 220),
        _column('islem', 'common.transaction_type', 170),
        _column('depo', 'common.warehouse', 150),
        _column(
          'giris',
          'common.incoming',
          100,
          alignment: Alignment.centerRight,
        ),
        _column(
          'cikis',
          'common.outgoing',
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
        _column('ref', 'reports.columns.reference', 130),
        _column('kullanici', 'common.user', 100),
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
    final kasaYer2Expr = "normalize_text('$yerKasaLabel')";
    final bankaYer2Expr = "normalize_text('$yerBankaLabel')";
    final krediKartiYer2Expr = "normalize_text('$yerKrediKartiLabel')";

    final cariWhere = <String>[];
    applyCommonDateUser(cariWhere, 'cat.date', 'cat.user_name');
    _addSearchConditionAny(cariWhere, params, [
      'cat.search_tags',
      'ca.search_tags',
      cariYerExpr,
    ], arama);

    final kasaWhere = <String>[];
    applyCommonDateUser(kasaWhere, 't.date', 't.user_name');
    _addSearchConditionAny(kasaWhere, params, [
      't.search_tags',
      kasaYer2Expr,
    ], arama);

    final bankaWhere = <String>[];
    applyCommonDateUser(bankaWhere, 't.date', 't.user_name');
    _addSearchConditionAny(bankaWhere, params, [
      't.search_tags',
      bankaYer2Expr,
    ], arama);

    final kartWhere = <String>[];
    applyCommonDateUser(kartWhere, 't.date', 't.user_name');
    _addSearchConditionAny(kartWhere, params, [
      't.search_tags',
      krediKartiYer2Expr,
    ], arama);

    final unionQuery =
        '''
      SELECT *
      FROM (
        SELECT
          ((${TabAciciScope.cariKartiIndex}::bigint << 48) + cat.id::bigint) AS gid,
          cat.id,
          cat.date AS tarih,
          cat.source_type AS islem,
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
          '' AS aciklama_2,
          NULL AS vade_tarihi,
          COALESCE(cat.user_name, '-') AS kullanici,
          ${TabAciciScope.cariKartiIndex} AS source_menu_index,
          ca.adi AS source_search_query
        FROM current_account_transactions cat
        INNER JOIN current_accounts ca ON ca.id = cat.current_account_id
        ${cariWhere.isEmpty ? '' : 'WHERE ${cariWhere.join(' AND ')}'}
        UNION ALL
        SELECT
          ((13::bigint << 48) + t.id::bigint) AS gid,
          t.id,
          t.date AS tarih,
          t.type AS islem,
          COALESCE(NULLIF(t.location, ''), '$yerPerakendeLabel') AS yer,
          COALESCE(t.location_code, '') AS yer_kodu,
          COALESCE(t.location_name, '') AS yer_adi,
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
          a.name AS source_search_query
        FROM cash_register_transactions t
        LEFT JOIN cash_registers a ON a.id = t.cash_register_id
        ${kasaWhere.isEmpty ? '' : 'WHERE ${kasaWhere.join(' AND ')}'}
        UNION ALL
        SELECT
          ((15::bigint << 48) + t.id::bigint) AS gid,
          t.id,
          t.date AS tarih,
          t.type AS islem,
          COALESCE(NULLIF(t.location, ''), '$yerPerakendeLabel') AS yer,
          COALESCE(t.location_code, '') AS yer_kodu,
          COALESCE(t.location_name, '') AS yer_adi,
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
          a.name AS source_search_query
        FROM bank_transactions t
        LEFT JOIN banks a ON a.id = t.bank_id
        ${bankaWhere.isEmpty ? '' : 'WHERE ${bankaWhere.join(' AND ')}'}
        UNION ALL
        SELECT
          ((16::bigint << 48) + t.id::bigint) AS gid,
          t.id,
          t.date AS tarih,
          t.type AS islem,
          COALESCE(NULLIF(t.location, ''), '$yerPerakendeLabel') AS yer,
          COALESCE(t.location_code, '') AS yer_kodu,
          COALESCE(t.location_name, '') AS yer_adi,
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
          a.name AS source_search_query
        FROM credit_card_transactions t
        LEFT JOIN credit_cards a ON a.id = t.credit_card_id
        ${kartWhere.isEmpty ? '' : 'WHERE ${kartWhere.join(' AND ')}'}
      ) hareketler
    ''';

    String sortExpr(String? key) {
      switch (key) {
        case 'islem':
          return "COALESCE(base.islem, '')";
        case 'yer':
          return "COALESCE(base.yer, '')";
        case 'yer_kodu':
          return "COALESCE(base.yer_kodu, '')";
        case 'yer_adi':
          return "COALESCE(base.yer_adi, '')";
        case 'yer_2':
          return "COALESCE(base.yer_2, '')";
        case 'tarih':
          return 'base.tarih';
        case 'tutar':
          return 'base.tutar_num';
        case 'kur':
          return 'base.kur';
        case 'belge':
          return "COALESCE(base.belge_no, '')";
        case 'e_belge':
          return "COALESCE(base.e_belge, '')";
        case 'irsaliye_no':
          return "COALESCE(base.irsaliye_no, '')";
        case 'fatura_no':
          return "COALESCE(base.fatura_no, '')";
        case 'aciklama':
          return "COALESCE(base.aciklama, '')";
        case 'aciklama_2':
          return "COALESCE(base.aciklama_2, '')";
        case 'vade_tarihi':
          return 'base.vade_tarihi';
        case 'kullanici':
          return "COALESCE(base.kullanici, '')";
        default:
          return 'base.tarih';
      }
    }

    final baseQuery =
        '''
      SELECT base.*, ${sortExpr(sortKey)} AS sort_val
      FROM ($unionQuery) base
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

    final rows = pageResult.rows;

    final mappedRows = rows
        .map((tx) {
          final tarih = _toDateTime(tx['tarih']);
          final vade = _toDateTime(tx['vade_tarihi']);
          final tutar = _toDouble(tx['tutar_num']);
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

          return RaporSatiri(
            id: 'hareket_${tx['source_menu_index']}_${tx['id']}',
            cells: {
              'islem': IslemCeviriYardimcisi.cevir(
                tx['islem']?.toString() ?? '-',
              ),
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
              'aciklama': tx['aciklama']?.toString() ?? '-',
              'aciklama_2': tx['aciklama_2']?.toString() ?? '',
              'vade_tarihi': vade != null
                  ? DateFormat('dd.MM.yyyy').format(vade)
                  : '',
              'kullanici': tx['kullanici']?.toString() ?? '-',
            },
            sourceMenuIndex: (tx['source_menu_index'] as num?)?.toInt(),
            sourceSearchQuery: tx['source_search_query']?.toString(),
            amountValue: tutar,
            sortValues: {
              'islem': tx['islem'],
              'yer': tx['yer'],
              'yer_kodu': tx['yer_kodu'],
              'yer_adi': tx['yer_adi'],
              'tarih': tarih,
              'tutar': tutar,
              'belge': tx['belge_no'],
              'e_belge': tx['e_belge'],
              'irsaliye_no': tx['irsaliye_no'],
              'fatura_no': tx['fatura_no'],
              'aciklama': tx['aciklama'],
              'aciklama_2': tx['aciklama_2'],
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
    final summaryCards = await _getOrComputeSummaryCards(
      cacheKey: summaryKey,
      loader: () async {
        final totalCount = await _queryCount(
          pool,
          'SELECT COUNT(*) FROM ($unionQuery) sayim',
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

    return RaporSonucu(
      report: rapor,
      columns: [
        _column('islem', 'reports.columns.process_exact', 100),
        _column('yer', 'reports.columns.place_exact', 60),
        _column('yer_kodu', 'reports.columns.place_code_exact', 80),
        _column('yer_adi', 'reports.columns.place_name_exact', 100),
        _column('tarih', 'reports.columns.date_exact', 100),
        _column(
          'tutar',
          'reports.columns.amount_exact',
          80,
          alignment: Alignment.centerRight,
        ),
        _column('kur', 'reports.columns.exchange_rate_exact', 50),
        _column('yer_2', 'reports.columns.place_exact', 60),
        _column('belge', 'reports.columns.document_exact', 80),
        _column('e_belge', 'reports.columns.e_document_exact', 80),
        _column('irsaliye_no', 'reports.columns.waybill_no_exact', 80),
        _column('fatura_no', 'reports.columns.invoice_no_exact', 80),
        _column('aciklama', 'reports.columns.description_exact', 100),
        _column('aciklama_2', 'reports.columns.description_2_exact', 100),
        _column('vade_tarihi', 'reports.columns.due_date_exact', 70),
        _column('kullanici', 'reports.columns.user_exact', 70),
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
      final rawType = tx['islem_turu']?.toString() ?? '';
      final double tutar = _toDouble(tx['tutar']);
      final bool isBorc = _isDebit(tx['yon']?.toString());
      final double runningBalance = _toDouble(tx['running_balance']);
      final detailItems = _extractDetailItems(tx['hareket_detaylari']);
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
      final String aciklama =
          tx['aciklama']?.toString().trim().isNotEmpty == true
          ? tx['aciklama'].toString()
          : IslemCeviriYardimcisi.cevir(rawType);
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
          'islem': IslemCeviriYardimcisi.cevir(rawType),
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
          'aciklama': aciklama,
          'vade': _formatDate(vade),
        },
        details: {
          tr('common.description'): aciklama,
          tr('common.transaction_type'): IslemCeviriYardimcisi.cevir(rawType),
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

      return RaporSatiri(
        id: 'fin_${tx['id']}_${mod.name}',
        cells: {
          'tarih': _formatDate(tarih, includeTime: true),
          'hesap': '$hesapKod - $hesapAdi'.trim(),
          'islem': IslemCeviriYardimcisi.cevir(tx['islem']?.toString() ?? '-'),
          'ilgili_hesap': _firstNonEmpty([
            tx['yerAdi']?.toString(),
            tx['yerKodu']?.toString(),
            tx['yer']?.toString(),
            '-',
          ]),
          'giris': incoming ? _formatMoney(tutar) : '-',
          'cikis': incoming ? '-' : _formatMoney(tutar),
          'aciklama': tx['aciklama']?.toString() ?? '-',
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
          'islem': tx['islem']?.toString(),
          'giris': incoming ? tutar : 0.0,
          'cikis': incoming ? 0.0 : tutar,
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
          'tarih': _formatDate(item.createdAt),
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
        _column('tarih', 'common.date', 120),
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

      return RaporSatiri(
        id: 'urun_hareket_${tx['id']}',
        cells: {
          'tarih': _formatDate(tarih, includeTime: true),
          'urun_kodu': urun?.kod ?? '-',
          'urun_adi': urun?.ad ?? '-',
          'islem': IslemCeviriYardimcisi.cevir(
            tx['islem_turu']?.toString() ?? '-',
          ),
          'depo': tx['depo_adi']?.toString() ?? '-',
          'giris': miktar > 0 ? _formatNumber(miktar) : '-',
          'cikis': miktar < 0 ? _formatNumber(miktar.abs()) : '-',
          'birim': urun?.birim ?? '-',
          'maliyet': _formatMoney(fiyat),
          'ref': tx['integration_ref']?.toString() ?? '-',
          'kullanici': tx['kullanici']?.toString() ?? '-',
        },
        details: {
          tr('common.description'): tx['aciklama']?.toString() ?? '-',
          tr('reports.columns.running_total'): _formatMoney(tutar),
        },
        sourceMenuIndex: TabAciciScope.urunKartiIndex,
        sourceSearchQuery: urun?.ad,
        amountValue: tutar,
        sortValues: {
          'tarih': tarih,
          'urun_kodu': urun?.kod,
          'urun_adi': urun?.ad,
          'islem': tx['islem_turu']?.toString(),
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
    final List<Map<String, dynamic>> cariRows = await _tumCariIslemleriniGetir(
      filtreler,
    );
    final List<Map<String, dynamic>> kasaRows = await _tumKasaIslemleriniGetir(
      filtreler,
    );
    final List<Map<String, dynamic>> bankaRows =
        await _tumBankaIslemleriniGetir(filtreler);
    final List<Map<String, dynamic>> krediKartiRows =
        await _tumKrediKartiIslemleriniGetir(filtreler);

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
    return RaporSatiri(
      id: 'all_cari_${tx['id']}',
      cells: {
        'tarih': _formatDate(tarih, includeTime: true),
        'modul': tr('nav.accounts'),
        'islem': IslemCeviriYardimcisi.cevir(
          tx['islem_turu']?.toString() ?? '-',
        ),
        'belge_no': _firstNonEmpty([
          tx['fatura_no']?.toString(),
          tx['irsaliye_no']?.toString(),
          tx['integration_ref']?.toString(),
          '-',
        ]),
        'hesap': cari == null ? '-' : '${cari.kodNo} - ${cari.adi}',
        'aciklama': tx['aciklama']?.toString() ?? '-',
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
        'islem': tx['islem_turu']?.toString(),
        'hesap': cari?.adi,
        'tutar': tutar,
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
    return RaporSatiri(
      id: 'all_fin_${menuIndex}_${tx['id']}',
      cells: {
        'tarih': _formatDate(tarih, includeTime: true),
        'modul': type,
        'islem': IslemCeviriYardimcisi.cevir(tx['islem']?.toString() ?? '-'),
        'belge_no': tx['integration_ref']?.toString() ?? '#${tx['id']}',
        'hesap': hesapAdi,
        'aciklama': tx['aciklama']?.toString() ?? '-',
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
        'islem': tx['islem']?.toString(),
        'hesap': hesapAdi,
        'tutar': tutar,
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
    return DetailTable(
      title: title,
      headers: [
        tr('common.code'),
        tr('common.product'),
        tr('common.quantity'),
        tr('common.unit'),
        tr('common.unit_price'),
        tr('common.amount'),
      ],
      data: items.map((item) {
        final double quantity = _toDouble(item['quantity']);
        final double unitPrice = _toDouble(item['unitCost']) != 0.0
            ? _toDouble(item['unitCost'])
            : _toDouble(item['price']);
        final double total = _toDouble(item['total']) != 0.0
            ? _toDouble(item['total'])
            : quantity * unitPrice;
        return [
          item['code']?.toString() ?? '-',
          item['name']?.toString() ?? '-',
          _formatNumber(quantity),
          item['unit']?.toString() ?? '-',
          _formatMoney(unitPrice),
          _formatMoney(total),
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
    final int decimalDigits = _guncelAyarlar?.kurOndalik ?? 2;
    return '${FormatYardimcisi.sayiFormatlaOndalikli(value, decimalDigits: decimalDigits)} ${FormatYardimcisi.paraBirimiSembol(currency)}';
  }

  String _formatNumber(dynamic amount) {
    final int decimalDigits = _guncelAyarlar?.miktarOndalik ?? 2;
    return FormatYardimcisi.sayiFormatlaOndalikli(
      amount,
      decimalDigits: decimalDigits,
    );
  }

  String _formatExchangeRate(dynamic rate) {
    if (rate == null || rate.toString().isEmpty) return '';
    final value = _toDouble(rate);
    final int decimalDigits = _guncelAyarlar?.kurOndalik ?? 4;
    return FormatYardimcisi.sayiFormatlaOndalikli(
      value,
      decimalDigits: decimalDigits,
    );
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
  'birim': _RaporKolonStandardi(minWidth: 90),
  'odeme_turu': _RaporKolonStandardi(minWidth: 130),
  'odeme_tipi': _RaporKolonStandardi(minWidth: 130),
  'aciklama': _RaporKolonStandardi(minWidth: 220),
  'aciklama_2': _RaporKolonStandardi(minWidth: 180),
  'kullanici': _RaporKolonStandardi(minWidth: 110),
};

enum _CariRaporModu { satis, alis, karma, ekstre }

enum _FinansRaporModu { kasa, banka, krediKarti }
