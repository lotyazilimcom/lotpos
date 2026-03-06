/// Kasa modeli
class KasaModel {
  final int id;
  final String kod;
  final String ad;
  final double bakiye;
  final String paraBirimi;
  final String bilgi1;
  final String bilgi2;
  final bool aktifMi;
  final bool varsayilan;
  final String? searchTags;
  final bool matchedInHidden;

  KasaModel({
    required this.id,
    required this.kod,
    required this.ad,
    this.bakiye = 0.0,
    this.paraBirimi = 'TRY',
    this.bilgi1 = '',
    this.bilgi2 = '',
    this.aktifMi = true,
    this.varsayilan = false,
    this.searchTags,
    this.matchedInHidden = false,
  });

  KasaModel copyWith({
    int? id,
    String? kod,
    String? ad,
    double? bakiye,
    String? paraBirimi,
    String? bilgi1,
    String? bilgi2,
    bool? aktifMi,
    bool? varsayilan,
    String? searchTags,
    bool? matchedInHidden,
  }) {
    return KasaModel(
      id: id ?? this.id,
      kod: kod ?? this.kod,
      ad: ad ?? this.ad,
      bakiye: bakiye ?? this.bakiye,
      paraBirimi: paraBirimi ?? this.paraBirimi,
      bilgi1: bilgi1 ?? this.bilgi1,
      bilgi2: bilgi2 ?? this.bilgi2,
      aktifMi: aktifMi ?? this.aktifMi,
      varsayilan: varsayilan ?? this.varsayilan,
      searchTags: searchTags ?? this.searchTags,
      matchedInHidden: matchedInHidden ?? this.matchedInHidden,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kod': kod,
      'ad': ad,
      'bakiye': bakiye,
      'para_birimi': paraBirimi,
      'bilgi1': bilgi1,
      'bilgi2': bilgi2,
      'aktif_mi': aktifMi ? 1 : 0,
      'varsayilan': varsayilan ? 1 : 0,
    };
  }

  factory KasaModel.fromMap(Map<String, dynamic> map) {
    return KasaModel(
      id: map['id'] as int,
      kod: map['kod'] as String? ?? '',
      ad: map['ad'] as String? ?? '',
      bakiye: double.tryParse(map['bakiye']?.toString() ?? '') ?? 0.0,
      paraBirimi: map['para_birimi'] as String? ?? 'TRY',
      bilgi1: map['bilgi1'] as String? ?? '',
      bilgi2: map['bilgi2'] as String? ?? '',
      aktifMi: (map['aktif_mi'] as int?) == 1,
      varsayilan: (map['varsayilan'] as int?) == 1,
      searchTags: map['search_tags'] as String?,
      matchedInHidden: map['matched_in_hidden'] as bool? ?? false,
    );
  }
}
