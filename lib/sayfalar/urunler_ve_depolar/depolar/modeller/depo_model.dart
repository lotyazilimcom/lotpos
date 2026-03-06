class DepoModel {
  final int id;
  final String kod;
  final String ad;
  final String adres;
  final String sorumlu;
  final String telefon;
  final bool aktifMi;
  final String? createdBy;
  final DateTime? createdAt;
  final bool matchedInHidden;

  const DepoModel({
    required this.id,
    required this.kod,
    required this.ad,
    required this.adres,
    required this.sorumlu,
    required this.telefon,
    required this.aktifMi,
    this.createdBy,
    this.createdAt,
    this.matchedInHidden = false,
  });

  DepoModel copyWith({
    int? id,
    String? kod,
    String? ad,
    String? adres,
    String? sorumlu,
    String? telefon,
    bool? aktifMi,
    String? createdBy,
    DateTime? createdAt,
    bool? matchedInHidden,
  }) {
    return DepoModel(
      id: id ?? this.id,
      kod: kod ?? this.kod,
      ad: ad ?? this.ad,
      adres: adres ?? this.adres,
      sorumlu: sorumlu ?? this.sorumlu,
      telefon: telefon ?? this.telefon,
      aktifMi: aktifMi ?? this.aktifMi,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      matchedInHidden: matchedInHidden ?? this.matchedInHidden,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id == 0 ? null : id, // Serial handling
      'kod': kod,
      'ad': ad,
      'adres': adres,
      'sorumlu': sorumlu,
      'telefon': telefon,
      'aktif_mi': aktifMi ? 1 : 0,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'matched_in_hidden': matchedInHidden ? 1 : 0,
    };
  }

  factory DepoModel.fromMap(Map<String, dynamic> map) {
    return DepoModel(
      id: map['id'] as int,
      kod: map['kod'] as String,
      ad: map['ad'] as String,
      adres: map['adres'] as String? ?? '',
      sorumlu: map['sorumlu'] as String? ?? '',
      telefon: map['telefon'] as String? ?? '',
      aktifMi: (map['aktif_mi'] as int? ?? 1) == 1,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] is DateTime
          ? map['created_at'] as DateTime
          : (map['created_at'] != null
                ? DateTime.tryParse(map['created_at'].toString())
                : null),
      matchedInHidden: map['matched_in_hidden'] == true,
    );
  }

  // Mock data generator
  static List<DepoModel> ornekVeriler() {
    return [
      const DepoModel(
        id: 1,
        kod: 'D001',
        ad: 'Merkez Depo',
        adres: 'Organize Sanayi Bölgesi 1. Cadde No: 5',
        sorumlu: 'Ahmet Yılmaz',
        telefon: '0555 123 45 67',
        aktifMi: true,
      ),
      const DepoModel(
        id: 2,
        kod: 'D002',
        ad: 'Şube Depo',
        adres: 'Atatürk Caddesi No: 12',
        sorumlu: 'Mehmet Demir',
        telefon: '0532 987 65 43',
        aktifMi: true,
      ),
      const DepoModel(
        id: 3,
        kod: 'D003',
        ad: 'Yedek Depo',
        adres: 'Sanayi Sitesi B Blok No: 8',
        sorumlu: 'Ayşe Kaya',
        telefon: '0544 111 22 33',
        aktifMi: false,
      ),
    ];
  }
}
