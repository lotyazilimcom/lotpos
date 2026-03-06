import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
import '../../../servisler/siparisler_veritabani_servisi.dart';
import '../../../servisler/teklifler_veritabani_servisi.dart';
import '../../../servisler/uretimler_veritabani_servisi.dart';
import '../../../servisler/urunler_veritabani_servisi.dart';
import '../../../temalar/app_theme.dart';
import '../../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../../yardimcilar/ceviri/islem_ceviri_yardimcisi.dart';
import '../../../yardimcilar/format_yardimcisi.dart';
import '../../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';
import '../../ayarlar/kullanicilar/modeller/kullanici_hareket_model.dart';
import '../../ayarlar/kullanicilar/modeller/kullanici_model.dart';
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
  final SiparislerVeritabaniServisi _siparisServisi =
      SiparislerVeritabaniServisi();
  final TekliflerVeritabaniServisi _teklifServisi =
      TekliflerVeritabaniServisi();
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

  Future<RaporFiltreKaynaklari> filtreKaynaklariniGetir() async {
    final results = await Future.wait([
      _cariServisi.cariHesaplariGetir(sayfaBasinaKayit: 5000),
      _urunServisi.urunleriGetir(sayfaBasinaKayit: 5000),
      _depoServisi.tumDepolariGetir(),
      _kasaServisi.tumKasalariGetir(),
      _bankaServisi.tumBankalariGetir(),
      _krediKartiServisi.tumKrediKartlariniGetir(sadeceAktif: false),
      _ayarlarServisi.kullanicilariGetir(sayfaBasinaKayit: 2000),
    ]);

    final cariler = results[0] as List<CariHesapModel>;
    final urunler = results[1] as List<UrunModel>;
    final depolar = results[2] as List<DepoModel>;
    final kasalar = results[3] as List<KasaModel>;
    final bankalar = results[4] as List<BankaModel>;
    final kartlar = results[5] as List<KrediKartiModel>;
    final kullanicilar = results[6] as List<KullaniciModel>;

    final Set<String> urunGruplari = urunler
        .map((e) => e.grubu.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    return RaporFiltreKaynaklari(
      cariler: cariler
          .map(
            (e) => RaporSecimSecenegi(
              value: e.id.toString(),
              label: '${e.kodNo} - ${e.adi}',
              extra: {'model': e},
            ),
          )
          .toList(),
      urunler: urunler
          .map(
            (e) => RaporSecimSecenegi(
              value: e.kod,
              label: '${e.kod} - ${e.ad}',
              extra: {'model': e},
            ),
          )
          .toList(),
      urunGruplari:
          urunGruplari
              .map((e) => RaporSecimSecenegi(value: e, label: e))
              .toList()
            ..sort((a, b) => a.label.compareTo(b.label)),
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
  }

  Future<RaporSonucu> raporuGetir({
    required RaporSecenegi rapor,
    required RaporFiltreleri filtreler,
    required String arama,
    String? sortKey,
    required bool sortAscending,
  }) async {
    if (!rapor.supported) {
      return RaporSonucu(
        report: rapor,
        columns: const <RaporKolonTanimi>[],
        rows: const <RaporSatiri>[],
        disabledReasonKey: rapor.disabledReasonKey,
      );
    }

    final RaporSonucu sonuc = switch (rapor.id) {
      'all_movements' => await _buildTumHareketler(rapor, filtreler),
      'purchase_sales_movements' => await _buildAlisSatisHareketleri(
        rapor,
        filtreler,
      ),
      'sales_report' => await _buildCariTabanliRapor(
        rapor,
        filtreler,
        mod: _CariRaporModu.satis,
      ),
      'purchase_report' => await _buildCariTabanliRapor(
        rapor,
        filtreler,
        mod: _CariRaporModu.alis,
      ),
      'account_statement' => await _buildCariTabanliRapor(
        rapor,
        filtreler,
        mod: _CariRaporModu.ekstre,
      ),
      'product_movements' => await _buildUrunHareketleri(rapor, filtreler),
      'product_shipment_movements' => await _buildUrunSevkiyatHareketleri(
        rapor,
        filtreler,
      ),
      'warehouse_stock_list' => await _buildDepoStokListesi(rapor, filtreler),
      'warehouse_shipment_list' => await _buildDepoSevkiyatListesi(
        rapor,
        filtreler,
      ),
      'stock_early_warning' => await _buildStokErkenUyari(rapor, filtreler),
      'stock_definition_values' => await _buildStokTanimDegerleri(
        rapor,
        filtreler,
      ),
      'order_report' => await _buildSiparisTeklifRaporu(
        rapor,
        filtreler,
        siparisMi: true,
      ),
      'quote_report' => await _buildSiparisTeklifRaporu(
        rapor,
        filtreler,
        siparisMi: false,
      ),
      'cash_movement_report' => await _buildFinansHareketRaporu(
        rapor,
        filtreler,
        mod: _FinansRaporModu.kasa,
      ),
      'bank_movement_report' => await _buildFinansHareketRaporu(
        rapor,
        filtreler,
        mod: _FinansRaporModu.banka,
      ),
      'credit_card_movement_report' => await _buildFinansHareketRaporu(
        rapor,
        filtreler,
        mod: _FinansRaporModu.krediKarti,
      ),
      'check_report' => await _buildCekSenetRaporu(
        rapor,
        filtreler,
        cekMi: true,
      ),
      'note_report' => await _buildCekSenetRaporu(
        rapor,
        filtreler,
        cekMi: false,
      ),
      'expense_report' => await _buildGiderRaporu(rapor, filtreler),
      'production_report' => await _buildUretimRaporu(rapor, filtreler),
      'balance_list' => await _buildBakiyeListesi(rapor, filtreler),
      'receivables_payables' => await _buildAlinacakVerilecekler(
        rapor,
        filtreler,
      ),
      'last_transaction_date' => await _buildSonIslemTarihi(rapor, filtreler),
      'profit_loss' => await _buildKarZarar(rapor, filtreler),
      'user_activity_report' => await _buildKullaniciIslemRaporu(
        rapor,
        filtreler,
      ),
      _ => RaporSonucu(
        report: rapor,
        columns: const <RaporKolonTanimi>[],
        rows: const <RaporSatiri>[],
        disabledReasonKey: 'reports.disabled.unknown',
      ),
    };

    final List<RaporSatiri> filteredRows = _applySearch(
      _sortRows(sonuc.rows, sortKey: sortKey, ascending: sortAscending),
      arama,
    );

    return RaporSonucu(
      report: sonuc.report,
      columns: sonuc.columns,
      rows: filteredRows,
      summaryCards: sonuc.summaryCards,
      totalCount: filteredRows.length,
      headerInfo: sonuc.headerInfo,
      mainTableLabel: sonuc.mainTableLabel,
      detailTableLabel: sonuc.detailTableLabel,
      disabledReasonKey: sonuc.disabledReasonKey,
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
      final String belgeNo = _firstNonEmpty([
        tx['fatura_no']?.toString(),
        tx['irsaliye_no']?.toString(),
        tx['belge']?.toString(),
        tx['integration_ref']?.toString(),
        '-',
      ]);
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
      _CariRaporModu.satis || _CariRaporModu.alis => <RaporKolonTanimi>[
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
      if (mod == _CariRaporModu.satis || mod == _CariRaporModu.alis)
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

  Future<RaporSonucu> _buildSiparisTeklifRaporu(
    RaporSecenegi rapor,
    RaporFiltreleri filtreler, {
    required bool siparisMi,
  }) async {
    final dynamic raw = siparisMi
        ? await _siparisServisi.siparisleriGetir(
            sayfaBasinaKayit: 5000,
            durum: _normalizedSelection(filtreler.durum),
            baslangicTarihi: filtreler.baslangicTarihi,
            bitisTarihi: filtreler.bitisTarihi,
            kullanici: _emptyToNull(filtreler.kullaniciId),
          )
        : await _teklifServisi.teklifleriGetir(
            sayfaBasinaKayit: 5000,
            durum: _normalizedSelection(filtreler.durum),
            baslangicTarihi: filtreler.baslangicTarihi,
            bitisTarihi: filtreler.bitisTarihi,
            kullanici: _emptyToNull(filtreler.kullaniciId),
          );

    final List<dynamic> liste = raw as List<dynamic>;
    final List<dynamic> filtreli = liste.where((item) {
      final String cariAdi = (item.cariAdi ?? '').toString();
      final String belgeNo = siparisMi
          ? (item.orderNo ?? '').toString()
          : (item.quoteNo ?? '').toString();
      final bool cariOk = filtreler.cariId == null || cariAdi.isNotEmpty;
      final bool belgeOk =
          filtreler.belgeNo == null ||
          filtreler.belgeNo!.trim().isEmpty ||
          belgeNo.toLowerCase().contains(filtreler.belgeNo!.toLowerCase());
      return cariOk && belgeOk;
    }).toList();

    final List<RaporSatiri> rows = filtreli.map((dynamic item) {
      final DateTime? tarih = item.tarih as DateTime?;
      final String belgeNo = siparisMi
          ? item.orderNo?.toString() ?? '-'
          : item.quoteNo?.toString() ?? '-';
      final List<dynamic> urunler = (item.urunler as List?) ?? const [];

      return RaporSatiri(
        id: '${siparisMi ? 'sip' : 'tek'}_${item.id}',
        cells: {
          'tarih': _formatDate(tarih, includeTime: true),
          'belge_no': belgeNo,
          'cari': item.cariAdi?.toString() ?? '-',
          'tutar': _formatMoney(item.tutar, currency: item.paraBirimi ?? 'TRY'),
          'durum': item.durum?.toString() ?? '-',
          'termin': _formatDate(tarih),
          'donusum': item.tur?.toString() ?? '-',
          'kullanici': item.kullanici?.toString() ?? '-',
        },
        details: {
          tr('reports.columns.current_account'):
              item.ilgiliHesapAdi?.toString() ?? '-',
          tr('reports.columns.item_count'): urunler.length.toString(),
          tr('common.currency'): item.paraBirimi?.toString() ?? 'TRY',
        },
        detailTable: _detailTableFromOrderItems(urunler),
        expandable: urunler.isNotEmpty,
        sourceMenuIndex: siparisMi ? 18 : 19,
        amountValue: _toDouble(item.tutar),
        sortValues: {
          'tarih': tarih,
          'belge_no': belgeNo,
          'cari': item.cariAdi?.toString(),
          'tutar': _toDouble(item.tutar),
          'durum': item.durum?.toString(),
        },
      );
    }).toList();

    final double toplam = rows.fold<double>(
      0.0,
      (sum, row) => sum + (row.amountValue ?? 0),
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
      rows: rows,
      summaryCards: [
        RaporOzetKarti(
          labelKey: siparisMi
              ? 'reports.summary.active_orders'
              : 'reports.summary.active_quotes',
          value: '${rows.length}',
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
      ],
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
    return RaporKolonTanimi(
      key: key,
      labelKey: labelKey,
      width: width,
      alignment: alignment,
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

  DetailTable? _detailTableFromOrderItems(List<dynamic> urunler) {
    if (urunler.isEmpty) return null;
    return DetailTable(
      title: tr('common.products'),
      headers: [
        tr('common.code'),
        tr('common.product'),
        tr('common.quantity'),
        tr('common.unit'),
        tr('common.unit_price'),
        tr('common.amount'),
      ],
      data: urunler.map((item) {
        return [
          item.urunKodu?.toString() ?? '-',
          item.urunAdi?.toString() ?? '-',
          _formatNumber(_toDouble(item.miktar)),
          item.birim?.toString() ?? '-',
          _formatMoney(_toDouble(item.birimFiyati)),
          _formatMoney(_toDouble(item.toplamFiyati)),
        ];
      }).toList(),
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
    return '${FormatYardimcisi.sayiFormatlaOndalikli(value)} ${FormatYardimcisi.paraBirimiSembol(currency)}';
  }

  String _formatNumber(dynamic amount) {
    return FormatYardimcisi.sayiFormatlaOndalikli(amount);
  }
}

enum _CariRaporModu { satis, alis, ekstre }

enum _FinansRaporModu { kasa, banka, krediKarti }
