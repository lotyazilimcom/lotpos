class DovizKuruModel {
  final String kaynakParaBirimi;
  final String hedefParaBirimi;
  final double kur;
  final DateTime guncellemeZamani;

  DovizKuruModel({
    required this.kaynakParaBirimi,
    required this.hedefParaBirimi,
    required this.kur,
    required this.guncellemeZamani,
  });

  Map<String, dynamic> toMap() {
    return {
      'from_code': kaynakParaBirimi,
      'to_code': hedefParaBirimi,
      'rate': kur,
      'update_time': guncellemeZamani.toIso8601String(),
    };
  }

  factory DovizKuruModel.fromMap(Map<String, dynamic> map) {
    return DovizKuruModel(
      kaynakParaBirimi: map['from_code'],
      hedefParaBirimi: map['to_code'],
      kur: (map['rate'] as num).toDouble(),
      guncellemeZamani: DateTime.parse(map['update_time']),
    );
  }
}
