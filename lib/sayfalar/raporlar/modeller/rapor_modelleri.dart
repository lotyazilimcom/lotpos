import 'package:flutter/material.dart';
import '../../../yardimcilar/yazdirma/genisletilebilir_print_service.dart';

enum RaporKategori {
  genel('reports.categories.general'),
  satisAlis('reports.categories.sales_purchases'),
  siparisTeklif('reports.categories.orders_quotes'),
  stokDepo('reports.categories.stock_warehouse'),
  uretim('reports.categories.production'),
  cari('reports.categories.accounts'),
  finans('reports.categories.finance'),
  cekSenet('reports.categories.checks_notes'),
  gider('reports.categories.expenses'),
  kullanici('reports.categories.users');

  const RaporKategori(this.labelKey);
  final String labelKey;
}

enum RaporFiltreTuru {
  tarihAraligi,
  cari,
  urun,
  urunGrubu,
  depo,
  islemTuru,
  durum,
  odemeYontemi,
  kasa,
  banka,
  krediKarti,
  kullanici,
  belgeNo,
  referansNo,
  minTutar,
  maxTutar,
  minMiktar,
  maxMiktar,
}

class RaporSecimSecenegi {
  const RaporSecimSecenegi({
    required this.value,
    required this.label,
    this.extra = const {},
  });

  final String value;
  final String label;
  final Map<String, dynamic> extra;
}

class RaporSecenegi {
  const RaporSecenegi({
    required this.id,
    required this.labelKey,
    required this.category,
    required this.icon,
    this.supportedFilters = const <RaporFiltreTuru>{},
    this.supported = true,
    this.disabledReasonKey,
  });

  final String id;
  final String labelKey;
  final RaporKategori category;
  final IconData icon;
  final Set<RaporFiltreTuru> supportedFilters;
  final bool supported;
  final String? disabledReasonKey;
}

class RaporKolonTanimi {
  const RaporKolonTanimi({
    required this.key,
    required this.labelKey,
    required this.width,
    this.alignment = Alignment.centerLeft,
    this.allowSorting = true,
    this.visibleByDefault = true,
  });

  final String key;
  final String labelKey;
  final double width;
  final Alignment alignment;
  final bool allowSorting;
  final bool visibleByDefault;
}

class RaporOzetKarti {
  const RaporOzetKarti({
    required this.labelKey,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.subtitle,
  });

  final String labelKey;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String? subtitle;
}

class RaporSatiri {
  const RaporSatiri({
    required this.id,
    required this.cells,
    this.details = const <String, String>{},
    this.detailTable,
    this.expandable = false,
    this.sourceMenuIndex,
    this.sourceSearchQuery,
    this.amountValue,
    this.sortValues = const <String, dynamic>{},
    this.extra = const <String, dynamic>{},
  });

  final String id;
  final Map<String, String> cells;
  final Map<String, String> details;
  final DetailTable? detailTable;
  final bool expandable;
  final int? sourceMenuIndex;
  final String? sourceSearchQuery;
  final double? amountValue;
  final Map<String, dynamic> sortValues;
  final Map<String, dynamic> extra;
}

class RaporFiltreleri {
  const RaporFiltreleri({
    this.baslangicTarihi,
    this.bitisTarihi,
    this.cariId,
    this.urunKodu,
    this.urunGrubu,
    this.depoId,
    this.islemTuru,
    this.durum,
    this.odemeYontemi,
    this.kasaId,
    this.bankaId,
    this.krediKartiId,
    this.kullaniciId,
    this.belgeNo,
    this.referansNo,
    this.minTutar,
    this.maxTutar,
    this.minMiktar,
    this.maxMiktar,
  });

  final DateTime? baslangicTarihi;
  final DateTime? bitisTarihi;
  final int? cariId;
  final String? urunKodu;
  final String? urunGrubu;
  final int? depoId;
  final String? islemTuru;
  final String? durum;
  final String? odemeYontemi;
  final int? kasaId;
  final int? bankaId;
  final int? krediKartiId;
  final String? kullaniciId;
  final String? belgeNo;
  final String? referansNo;
  final double? minTutar;
  final double? maxTutar;
  final double? minMiktar;
  final double? maxMiktar;

  RaporFiltreleri copyWith({
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
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
    String? belgeNo,
    String? referansNo,
    double? minTutar,
    double? maxTutar,
    double? minMiktar,
    double? maxMiktar,
    bool clearDates = false,
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
    bool clearBelgeNo = false,
    bool clearReferansNo = false,
    bool clearMinTutar = false,
    bool clearMaxTutar = false,
    bool clearMinMiktar = false,
    bool clearMaxMiktar = false,
  }) {
    return RaporFiltreleri(
      baslangicTarihi: clearDates
          ? null
          : (baslangicTarihi ?? this.baslangicTarihi),
      bitisTarihi: clearDates ? null : (bitisTarihi ?? this.bitisTarihi),
      cariId: clearCari ? null : (cariId ?? this.cariId),
      urunKodu: clearUrun ? null : (urunKodu ?? this.urunKodu),
      urunGrubu: clearUrunGrubu ? null : (urunGrubu ?? this.urunGrubu),
      depoId: clearDepo ? null : (depoId ?? this.depoId),
      islemTuru: clearIslemTuru ? null : (islemTuru ?? this.islemTuru),
      durum: clearDurum ? null : (durum ?? this.durum),
      odemeYontemi: clearOdemeYontemi
          ? null
          : (odemeYontemi ?? this.odemeYontemi),
      kasaId: clearKasa ? null : (kasaId ?? this.kasaId),
      bankaId: clearBanka ? null : (bankaId ?? this.bankaId),
      krediKartiId: clearKrediKarti
          ? null
          : (krediKartiId ?? this.krediKartiId),
      kullaniciId: clearKullanici ? null : (kullaniciId ?? this.kullaniciId),
      belgeNo: clearBelgeNo ? null : (belgeNo ?? this.belgeNo),
      referansNo: clearReferansNo ? null : (referansNo ?? this.referansNo),
      minTutar: clearMinTutar ? null : (minTutar ?? this.minTutar),
      maxTutar: clearMaxTutar ? null : (maxTutar ?? this.maxTutar),
      minMiktar: clearMinMiktar ? null : (minMiktar ?? this.minMiktar),
      maxMiktar: clearMaxMiktar ? null : (maxMiktar ?? this.maxMiktar),
    );
  }

  static const RaporFiltreleri empty = RaporFiltreleri();
}

class RaporFiltreKaynaklari {
  const RaporFiltreKaynaklari({
    this.cariler = const <RaporSecimSecenegi>[],
    this.urunler = const <RaporSecimSecenegi>[],
    this.urunGruplari = const <RaporSecimSecenegi>[],
    this.depolar = const <RaporSecimSecenegi>[],
    this.kasalar = const <RaporSecimSecenegi>[],
    this.bankalar = const <RaporSecimSecenegi>[],
    this.krediKartlari = const <RaporSecimSecenegi>[],
    this.kullanicilar = const <RaporSecimSecenegi>[],
    this.durumlar = const <String, List<RaporSecimSecenegi>>{},
    this.islemTurleri = const <String, List<RaporSecimSecenegi>>{},
    this.odemeYontemleri = const <String, List<RaporSecimSecenegi>>{},
  });

  final List<RaporSecimSecenegi> cariler;
  final List<RaporSecimSecenegi> urunler;
  final List<RaporSecimSecenegi> urunGruplari;
  final List<RaporSecimSecenegi> depolar;
  final List<RaporSecimSecenegi> kasalar;
  final List<RaporSecimSecenegi> bankalar;
  final List<RaporSecimSecenegi> krediKartlari;
  final List<RaporSecimSecenegi> kullanicilar;
  final Map<String, List<RaporSecimSecenegi>> durumlar;
  final Map<String, List<RaporSecimSecenegi>> islemTurleri;
  final Map<String, List<RaporSecimSecenegi>> odemeYontemleri;
}

class RaporSonucu {
  const RaporSonucu({
    required this.report,
    required this.columns,
    required this.rows,
    this.summaryCards = const <RaporOzetKarti>[],
    this.totalCount = 0,
    this.headerInfo = const <String, dynamic>{},
    this.mainTableLabel,
    this.detailTableLabel,
    this.disabledReasonKey,
  });

  final RaporSecenegi report;
  final List<RaporKolonTanimi> columns;
  final List<RaporSatiri> rows;
  final List<RaporOzetKarti> summaryCards;
  final int totalCount;
  final Map<String, dynamic> headerInfo;
  final String? mainTableLabel;
  final String? detailTableLabel;
  final String? disabledReasonKey;

  bool get isDisabled => disabledReasonKey != null;
}
