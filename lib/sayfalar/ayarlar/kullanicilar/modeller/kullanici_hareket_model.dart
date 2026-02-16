class KullaniciHareketModel {
  final String id;
  final String kullaniciId;
  final DateTime tarih;
  final String aciklama;
  final double borc;
  final double alacak;
  final String islemTuru; // 'odeme', 'alacak', 'maas' vb.

  KullaniciHareketModel({
    required this.id,
    required this.kullaniciId,
    required this.tarih,
    required this.aciklama,
    required this.borc,
    required this.alacak,
    required this.islemTuru,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': kullaniciId,
      'date': tarih.toIso8601String(),
      'description': aciklama,
      'debt': borc,
      'credit': alacak,
      'type': islemTuru,
    };
  }

  factory KullaniciHareketModel.fromMap(Map<String, dynamic> map) {
    final dateRaw = map['date'];
    return KullaniciHareketModel(
      id: map['id'] as String,
      kullaniciId: map['user_id'] as String,
      tarih: dateRaw is DateTime
          ? dateRaw
          : DateTime.parse((dateRaw ?? '').toString()),
      aciklama: (map['description'] as String?) ?? '',
      borc: double.tryParse(map['debt']?.toString() ?? '') ?? 0.0,
      alacak: double.tryParse(map['credit']?.toString() ?? '') ?? 0.0,
      islemTuru: (map['type'] as String?) ?? '',
    );
  }
}
