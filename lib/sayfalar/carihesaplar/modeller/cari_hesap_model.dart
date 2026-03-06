/// Cari Hesap veri modeli.
/// 50 Milyon+ kayıt için optimize edilmiş, null-safe yapıda.
class CariHesapModel {
  final int id;
  final String kodNo;
  final String adi;
  final String hesapTuru; // Alıcı, Satıcı, Alıcı/Satıcı vb.
  final String paraBirimi; // TRY, USD, EUR vb.
  final double bakiyeBorc;
  final double bakiyeAlacak;
  final String bakiyeDurumu; // Borç veya Alacak
  final String telefon1;
  final String fatSehir;
  final bool aktifMi;

  // Genişletilebilir Detay Alanları
  final String fatUnvani;
  final String fatAdresi;
  final String fatIlce;
  final String postaKodu;
  final String vDairesi;
  final String vNumarasi;
  final String sfGrubu; // Satış Fiyatı Grubu
  final double sIskonto;
  final int vadeGun;
  final double riskLimiti;
  final String telefon2;
  final String eposta;
  final String webAdresi;
  final String bilgi1;
  final String bilgi2;
  final String bilgi3;
  final String bilgi4;
  final String bilgi5;

  // Sevk Adresleri (JSON array olarak tutulacak)
  final String sevkAdresleri;

  // Resimler (base64 encoded, JSON array olarak tutulacak)
  final List<String> resimler;

  // Renk Etiketi (siyah, mavi, kirmizi)
  final String? renk;

  // Veritabanı arama optimizasyonu için
  final bool matchedInHidden;

  // Metadata
  final DateTime? olusturmaTarihi;
  final DateTime? guncellemeTarihi;
  final String kullanici;

  const CariHesapModel({
    required this.id,
    required this.kodNo,
    required this.adi,
    this.hesapTuru = '',
    this.paraBirimi = 'TRY',
    this.bakiyeBorc = 0.0,
    this.bakiyeAlacak = 0.0,
    this.bakiyeDurumu = 'Borç',
    this.telefon1 = '',
    this.fatSehir = '',
    this.aktifMi = true,
    this.fatUnvani = '',
    this.fatAdresi = '',
    this.fatIlce = '',
    this.postaKodu = '',
    this.vDairesi = '',
    this.vNumarasi = '',
    this.sfGrubu = '',
    this.sIskonto = 0.0,
    this.vadeGun = 0,
    this.riskLimiti = 0.0,
    this.telefon2 = '',
    this.eposta = '',
    this.webAdresi = '',
    this.bilgi1 = '',
    this.bilgi2 = '',
    this.bilgi3 = '',
    this.bilgi4 = '',
    this.bilgi5 = '',
    this.sevkAdresleri = '',
    this.resimler = const [],
    this.renk,
    this.matchedInHidden = false,
    this.olusturmaTarihi,
    this.guncellemeTarihi,
    this.kullanici = '',
  });

  /// Factory constructor: Map'ten CariHesapModel oluşturur.
  factory CariHesapModel.fromMap(Map<String, dynamic> map) {
    // Resimleri parse et
    List<String> resimListesi = [];
    if (map['resimler'] != null) {
      if (map['resimler'] is List) {
        resimListesi = (map['resimler'] as List)
            .map((e) => e.toString())
            .toList();
      } else if (map['resimler'] is String && map['resimler'].isNotEmpty) {
        try {
          final decoded = map['resimler'];
          if (decoded is List) {
            resimListesi = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return CariHesapModel(
      id: parseInt(map['id']),
      kodNo: map['kod_no']?.toString() ?? '',
      adi: map['adi']?.toString() ?? '',
      hesapTuru: map['hesap_turu']?.toString() ?? '',
      paraBirimi: map['para_birimi']?.toString() ?? 'TRY',
      bakiyeBorc: parseDouble(map['bakiye_borc']),
      bakiyeAlacak: parseDouble(map['bakiye_alacak']),
      bakiyeDurumu: map['bakiye_durumu']?.toString() ?? 'Borç',
      telefon1: map['telefon1']?.toString() ?? '',
      fatSehir: map['fat_sehir']?.toString() ?? '',
      aktifMi: map['aktif_mi'] is bool
          ? map['aktif_mi']
          : (map['aktif_mi'] == 1 || map['aktif_mi'] == '1'),
      fatUnvani: map['fat_unvani']?.toString() ?? '',
      fatAdresi: map['fat_adresi']?.toString() ?? '',
      fatIlce: map['fat_ilce']?.toString() ?? '',
      postaKodu: map['posta_kodu']?.toString() ?? '',
      vDairesi: map['v_dairesi']?.toString() ?? '',
      vNumarasi: map['v_numarasi']?.toString() ?? '',
      sfGrubu: map['sf_grubu']?.toString() ?? '',
      sIskonto: parseDouble(map['s_iskonto']),
      vadeGun: parseInt(map['vade_gun']),
      riskLimiti: parseDouble(map['risk_limiti']),
      telefon2: map['telefon2']?.toString() ?? '',
      eposta: map['eposta']?.toString() ?? '',
      webAdresi: map['web_adresi']?.toString() ?? '',
      bilgi1: map['bilgi1']?.toString() ?? '',
      bilgi2: map['bilgi2']?.toString() ?? '',
      bilgi3: map['bilgi3']?.toString() ?? '',
      bilgi4: map['bilgi4']?.toString() ?? '',
      bilgi5: map['bilgi5']?.toString() ?? '',
      sevkAdresleri: map['sevk_adresleri']?.toString() ?? '',
      resimler: resimListesi,
      renk: map['renk']?.toString(),
      matchedInHidden: map['matched_in_hidden'] is bool
          ? map['matched_in_hidden']
          : (map['matched_in_hidden'] == 1 ||
                map['matched_in_hidden'] == 'true'),
      olusturmaTarihi: map['olusturma_tarihi'] != null
          ? DateTime.tryParse(map['olusturma_tarihi'].toString())
          : null,
      guncellemeTarihi: map['guncelleme_tarihi'] != null
          ? DateTime.tryParse(map['guncelleme_tarihi'].toString())
          : null,
      kullanici: map['kullanici']?.toString() ?? '',
    );
  }

  /// Model'i Map'e dönüştürür (veritabanı işlemleri için).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kod_no': kodNo,
      'adi': adi,
      'hesap_turu': hesapTuru,
      'para_birimi': paraBirimi,
      'bakiye_borc': bakiyeBorc,
      'bakiye_alacak': bakiyeAlacak,
      'bakiye_durumu': bakiyeDurumu,
      'telefon1': telefon1,
      'fat_sehir': fatSehir,
      'aktif_mi': aktifMi,
      'fat_unvani': fatUnvani,
      'fat_adresi': fatAdresi,
      'fat_ilce': fatIlce,
      'posta_kodu': postaKodu,
      'v_dairesi': vDairesi,
      'v_numarasi': vNumarasi,
      'sf_grubu': sfGrubu,
      's_iskonto': sIskonto,
      'vade_gun': vadeGun,
      'risk_limiti': riskLimiti,
      'telefon2': telefon2,
      'eposta': eposta,
      'web_adresi': webAdresi,
      'bilgi1': bilgi1,
      'bilgi2': bilgi2,
      'bilgi3': bilgi3,
      'bilgi4': bilgi4,
      'bilgi5': bilgi5,
      'sevk_adresleri': sevkAdresleri,
      'resimler': resimler,
      'renk': renk,
      'kullanici': kullanici,
    };
  }

  /// copyWith metodu - immutable state yönetimi için.
  CariHesapModel copyWith({
    int? id,
    String? kodNo,
    String? adi,
    String? hesapTuru,
    String? paraBirimi,
    double? bakiyeBorc,
    double? bakiyeAlacak,
    String? bakiyeDurumu,
    String? telefon1,
    String? fatSehir,
    bool? aktifMi,
    String? fatUnvani,
    String? fatAdresi,
    String? fatIlce,
    String? postaKodu,
    String? vDairesi,
    String? vNumarasi,
    String? sfGrubu,
    double? sIskonto,
    int? vadeGun,
    double? riskLimiti,
    String? telefon2,
    String? eposta,
    String? webAdresi,
    String? bilgi1,
    String? bilgi2,
    String? bilgi3,
    String? bilgi4,
    String? bilgi5,
    String? sevkAdresleri,
    List<String>? resimler,
    String? renk,
    bool? matchedInHidden,
    DateTime? olusturmaTarihi,
    DateTime? guncellemeTarihi,
    String? kullanici,
  }) {
    return CariHesapModel(
      id: id ?? this.id,
      kodNo: kodNo ?? this.kodNo,
      adi: adi ?? this.adi,
      hesapTuru: hesapTuru ?? this.hesapTuru,
      paraBirimi: paraBirimi ?? this.paraBirimi,
      bakiyeBorc: bakiyeBorc ?? this.bakiyeBorc,
      bakiyeAlacak: bakiyeAlacak ?? this.bakiyeAlacak,
      bakiyeDurumu: bakiyeDurumu ?? this.bakiyeDurumu,
      telefon1: telefon1 ?? this.telefon1,
      fatSehir: fatSehir ?? this.fatSehir,
      aktifMi: aktifMi ?? this.aktifMi,
      fatUnvani: fatUnvani ?? this.fatUnvani,
      fatAdresi: fatAdresi ?? this.fatAdresi,
      fatIlce: fatIlce ?? this.fatIlce,
      postaKodu: postaKodu ?? this.postaKodu,
      vDairesi: vDairesi ?? this.vDairesi,
      vNumarasi: vNumarasi ?? this.vNumarasi,
      sfGrubu: sfGrubu ?? this.sfGrubu,
      sIskonto: sIskonto ?? this.sIskonto,
      vadeGun: vadeGun ?? this.vadeGun,
      riskLimiti: riskLimiti ?? this.riskLimiti,
      telefon2: telefon2 ?? this.telefon2,
      eposta: eposta ?? this.eposta,
      webAdresi: webAdresi ?? this.webAdresi,
      bilgi1: bilgi1 ?? this.bilgi1,
      bilgi2: bilgi2 ?? this.bilgi2,
      bilgi3: bilgi3 ?? this.bilgi3,
      bilgi4: bilgi4 ?? this.bilgi4,
      bilgi5: bilgi5 ?? this.bilgi5,
      sevkAdresleri: sevkAdresleri ?? this.sevkAdresleri,
      resimler: resimler ?? this.resimler,
      renk: renk ?? this.renk,
      matchedInHidden: matchedInHidden ?? this.matchedInHidden,
      olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
      guncellemeTarihi: guncellemeTarihi ?? this.guncellemeTarihi,
      kullanici: kullanici ?? this.kullanici,
    );
  }

  /// Test/Demo verisi oluşturucu.
  static List<CariHesapModel> ornekVeriler() {
    return [
      const CariHesapModel(
        id: 1,
        kodNo: 'C001',
        adi: 'ABC Ticaret Ltd. Şti.',
        hesapTuru: 'Alıcı',
        bakiyeBorc: 15000.00,
        bakiyeAlacak: 5000.00,
        telefon1: '0532 123 45 67',
        fatSehir: 'İstanbul',
        aktifMi: true,
        fatUnvani: 'ABC Tic. Ltd. Şti.',
        fatAdresi: 'Atatürk Cad. No:123',
        fatIlce: 'Kadıköy',
        postaKodu: '34710',
        vDairesi: 'Kadıköy',
        vNumarasi: '1234567890',
        sfGrubu: 'Toptan',
        sIskonto: 5.0,
        vadeGun: 30,
        riskLimiti: 50000.00,
        telefon2: '0216 123 45 67',
        eposta: 'info@abcticaret.com',
        webAdresi: 'www.abcticaret.com',
        bilgi1: 'Düzenli müşteri',
        kullanici: 'admin',
      ),
      const CariHesapModel(
        id: 2,
        kodNo: 'C002',
        adi: 'XYZ Gıda A.Ş.',
        hesapTuru: 'Satıcı',
        bakiyeBorc: 0.00,
        bakiyeAlacak: 25000.00,
        telefon1: '0533 987 65 43',
        fatSehir: 'Ankara',
        aktifMi: true,
        fatUnvani: 'XYZ Gıda Anonim Şirketi',
        fatAdresi: 'Sanayi Mah. 1. Sok No:45',
        fatIlce: 'Çankaya',
        postaKodu: '06520',
        vDairesi: 'Maltepe',
        vNumarasi: '9876543210',
        sfGrubu: 'Perakende',
        sIskonto: 3.0,
        vadeGun: 45,
        riskLimiti: 100000.00,
        eposta: 'satis@xyzgida.com',
        kullanici: 'admin',
      ),
      const CariHesapModel(
        id: 3,
        kodNo: 'C003',
        adi: 'Mehmet Yılmaz',
        hesapTuru: 'Alıcı/Satıcı',
        bakiyeBorc: 3500.00,
        bakiyeAlacak: 3500.00,
        telefon1: '0544 111 22 33',
        fatSehir: 'İzmir',
        aktifMi: false,
        fatUnvani: 'Mehmet Yılmaz',
        fatAdresi: 'Kordon Boyu No:78',
        fatIlce: 'Konak',
        postaKodu: '35210',
        vDairesi: 'Konak',
        vNumarasi: '11122233344',
        sfGrubu: 'Bireysel',
        vadeGun: 15,
        riskLimiti: 10000.00,
        eposta: 'mehmet.yilmaz@email.com',
        kullanici: 'admin',
      ),
    ];
  }
}
