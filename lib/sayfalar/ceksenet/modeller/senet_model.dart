import 'package:intl/intl.dart';

class SenetModel {
  final int id;
  final String tur; // Alınan Senet / Verilen Senet
  final String tahsilat; // Tahsil / Ödeme / Ciro
  final String cariKod;
  final String cariAdi;
  final String duzenlenmeTarihi;
  final String kesideTarihi;
  final double tutar;
  final String paraBirimi;
  final String senetNo;
  final String banka;
  final String aciklama;
  final String kullanici;
  final bool aktifMi;
  final String? searchTags;
  final bool matchedInHidden;
  final String? integrationRef;

  const SenetModel({
    required this.id,
    required this.tur,
    required this.tahsilat,
    required this.cariKod,
    required this.cariAdi,
    required this.duzenlenmeTarihi,
    required this.kesideTarihi,
    required this.tutar,
    this.paraBirimi = 'TRY',
    required this.senetNo,
    required this.banka,
    this.aciklama = '',
    this.kullanici = '',
    this.aktifMi = true,
    this.searchTags,
    this.matchedInHidden = false,
    this.integrationRef,
  });

  SenetModel copyWith({
    int? id,
    String? tur,
    String? tahsilat,
    String? cariKod,
    String? cariAdi,
    String? duzenlenmeTarihi,
    String? kesideTarihi,
    double? tutar,
    String? paraBirimi,
    String? senetNo,
    String? banka,
    String? aciklama,
    String? kullanici,
    bool? aktifMi,
    String? searchTags,
    bool? matchedInHidden,
    String? integrationRef,
  }) {
    return SenetModel(
      id: id ?? this.id,
      tur: tur ?? this.tur,
      tahsilat: tahsilat ?? this.tahsilat,
      cariKod: cariKod ?? this.cariKod,
      cariAdi: cariAdi ?? this.cariAdi,
      duzenlenmeTarihi: duzenlenmeTarihi ?? this.duzenlenmeTarihi,
      kesideTarihi: kesideTarihi ?? this.kesideTarihi,
      tutar: tutar ?? this.tutar,
      paraBirimi: paraBirimi ?? this.paraBirimi,
      senetNo: senetNo ?? this.senetNo,
      banka: banka ?? this.banka,
      aciklama: aciklama ?? this.aciklama,
      kullanici: kullanici ?? this.kullanici,
      aktifMi: aktifMi ?? this.aktifMi,
      searchTags: searchTags ?? this.searchTags,
      matchedInHidden: matchedInHidden ?? this.matchedInHidden,
      integrationRef: integrationRef ?? this.integrationRef,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': tur,
      'collection_status': tahsilat,
      'customer_code': cariKod,
      'customer_name': cariAdi,
      'issue_date': duzenlenmeTarihi,
      'due_date': kesideTarihi,
      'amount': tutar,
      'currency': paraBirimi,
      'note_no': senetNo,
      'bank': banka,
      'description': aciklama,
      'user_name': kullanici,
      'is_active': aktifMi ? 1 : 0,
      'search_tags': searchTags,
      'matched_in_hidden': matchedInHidden ? 1 : 0,
      'integration_ref': integrationRef,
    };
  }

  factory SenetModel.fromMap(Map<String, dynamic> map) {
    return SenetModel(
      id: map['id'] as int? ?? 0,
      tur: map['type'] as String? ?? '',
      tahsilat: map['collection_status'] as String? ?? '',
      cariKod: map['customer_code'] as String? ?? '',
      cariAdi: map['customer_name'] as String? ?? '',
      duzenlenmeTarihi: map['issue_date'] is DateTime
          ? DateFormat('dd.MM.yyyy').format(map['issue_date'] as DateTime)
          : (map['issue_date']?.toString() ?? ''),
      kesideTarihi: map['due_date'] is DateTime
          ? DateFormat('dd.MM.yyyy').format(map['due_date'] as DateTime)
          : (map['due_date']?.toString() ?? ''),
      tutar: double.tryParse(map['amount']?.toString() ?? '') ?? 0.0,
      paraBirimi: map['currency'] as String? ?? 'TRY',
      senetNo: map['note_no'] as String? ?? '',
      banka: map['bank'] as String? ?? '',
      aciklama: map['description'] as String? ?? '',
      kullanici: map['user_name'] as String? ?? '',
      aktifMi: (map['is_active'] as int?) == 1,
      searchTags: map['search_tags'] as String?,
      matchedInHidden:
          (map['matched_in_hidden'] as int?) == 1 ||
          (map['matched_in_hidden_calc'] as int?) == 1,
      integrationRef: map['integration_ref'] as String?,
    );
  }
}
