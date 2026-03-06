class KullaniciModel {
  final String id;
  final String kullaniciAdi;
  final String ad;
  final String soyad;
  final String eposta;
  final String rol;
  final bool aktifMi;
  final String telefon;
  final String? profilResmi;
  final String? sifre;
  // Yeni alanlar
  final DateTime? iseGirisTarihi;
  final String? gorevi;
  final double? maasi;
  final String? paraBirimi;
  final String? adresi;
  final String? bilgi1;
  final String? bilgi2;
  // Bakiye alanları
  final double bakiyeBorc;
  final double bakiyeAlacak;
  // Derin arama için: işlemlerde eşleşme bulundu mu?
  final bool matchedInHidden;

  KullaniciModel({
    required this.id,
    required this.kullaniciAdi,
    required this.ad,
    required this.soyad,
    required this.eposta,
    required this.rol,
    required this.aktifMi,
    required this.telefon,
    this.profilResmi,
    this.sifre,
    this.iseGirisTarihi,
    this.gorevi,
    this.maasi,
    this.paraBirimi,
    this.adresi,
    this.bilgi1,
    this.bilgi2,
    this.bakiyeBorc = 0.0,
    this.bakiyeAlacak = 0.0,
    this.matchedInHidden = false,
  });

  KullaniciModel copyWith({
    String? id,
    String? kullaniciAdi,
    String? ad,
    String? soyad,
    String? eposta,
    String? rol,
    bool? aktifMi,
    String? telefon,
    String? profilResmi,
    String? sifre,
    DateTime? iseGirisTarihi,
    String? gorevi,
    double? maasi,
    String? paraBirimi,
    String? adresi,
    String? bilgi1,
    String? bilgi2,
    double? bakiyeBorc,
    double? bakiyeAlacak,
    bool? matchedInHidden,
  }) {
    return KullaniciModel(
      id: id ?? this.id,
      kullaniciAdi: kullaniciAdi ?? this.kullaniciAdi,
      ad: ad ?? this.ad,
      soyad: soyad ?? this.soyad,
      eposta: eposta ?? this.eposta,
      rol: rol ?? this.rol,
      aktifMi: aktifMi ?? this.aktifMi,
      telefon: telefon ?? this.telefon,
      profilResmi: profilResmi ?? this.profilResmi,
      sifre: sifre ?? this.sifre,
      iseGirisTarihi: iseGirisTarihi ?? this.iseGirisTarihi,
      gorevi: gorevi ?? this.gorevi,
      maasi: maasi ?? this.maasi,
      paraBirimi: paraBirimi ?? this.paraBirimi,
      adresi: adresi ?? this.adresi,
      bilgi1: bilgi1 ?? this.bilgi1,
      bilgi2: bilgi2 ?? this.bilgi2,
      bakiyeBorc: bakiyeBorc ?? this.bakiyeBorc,
      bakiyeAlacak: bakiyeAlacak ?? this.bakiyeAlacak,
      matchedInHidden: matchedInHidden ?? this.matchedInHidden,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': kullaniciAdi,
      'name': ad,
      'surname': soyad,
      'email': eposta,
      'role': rol,
      'is_active': aktifMi ? 1 : 0,
      'phone': telefon,
      'profile_image': profilResmi,
      'password': sifre,
      'hire_date': iseGirisTarihi?.toIso8601String(),
      'position': gorevi,
      'salary': maasi,
      'salary_currency': paraBirimi,
      'address': adresi,
      'info1': bilgi1,
      'info2': bilgi2,
      'balance_debt': bakiyeBorc,
      'balance_credit': bakiyeAlacak,
    };
  }

  factory KullaniciModel.fromMap(Map<String, dynamic> map) {
    return KullaniciModel(
      id: map['id'] as String,
      kullaniciAdi: map['username'] as String,
      ad: (map['name'] as String?) ?? '',
      soyad: (map['surname'] as String?) ?? '',
      eposta: map['email'] as String,
      rol: map['role'] as String,
      aktifMi: (map['is_active'] as int) == 1,
      telefon: (map['phone'] as String?) ?? '',
      profilResmi: map['profile_image'] as String?,
      sifre: map['password'] as String?,
      iseGirisTarihi: map['hire_date'] != null
          ? DateTime.tryParse(map['hire_date'] as String)
          : null,
      gorevi: map['position'] as String?,
      maasi: map['salary'] != null
          ? (map['salary'] is int
                ? (map['salary'] as int).toDouble()
                : map['salary'] as double?)
          : null,
      paraBirimi: map['salary_currency'] as String?,
      adresi: map['address'] as String?,
      bilgi1: map['info1'] as String?,
      bilgi2: map['info2'] as String?,
      bakiyeBorc: (map['balance_debt'] as num?)?.toDouble() ?? 0.0,
      bakiyeAlacak: (map['balance_credit'] as num?)?.toDouble() ?? 0.0,
      matchedInHidden: (map['matched_in_hidden_calc'] as num?)?.toInt() == 1,
    );
  }
}
