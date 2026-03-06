import 'dart:convert';

class SirketAyarlariModel {
  final int? id;
  final String kod;
  final String ad;
  final List<String> basliklar;
  final List<Map<String, String>> logolar;
  final String adres;
  final String vergiDairesi;
  final String vergiNo;
  final String telefon;
  final String eposta;
  final String webAdresi;
  final bool aktifMi;
  final bool varsayilanMi;
  final bool duzenlenebilirMi;
  final String? ustBilgiLogosu;
  final List<String> ustBilgiSatirlari;

  SirketAyarlariModel({
    this.id,
    required this.kod,
    required this.ad,
    required this.basliklar,
    required this.logolar,
    this.adres = '',
    this.vergiDairesi = '',
    this.vergiNo = '',
    this.telefon = '',
    this.eposta = '',
    this.webAdresi = '',
    this.aktifMi = true,
    this.varsayilanMi = false,
    this.duzenlenebilirMi = true,
    this.ustBilgiLogosu,
    this.ustBilgiSatirlari = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kod': kod,
      'ad': ad,
      'basliklar': jsonEncode(basliklar),
      'logolar': jsonEncode(logolar),
      'adres': adres,
      'vergi_dairesi': vergiDairesi,
      'vergi_no': vergiNo,
      'telefon': telefon,
      'eposta': eposta,
      'web_adresi': webAdresi,
      'aktif_mi': aktifMi ? 1 : 0,
      'varsayilan_mi': varsayilanMi ? 1 : 0,
      'duzenlenebilir_mi': duzenlenebilirMi ? 1 : 0,
      'ust_bilgi_logosu': ustBilgiLogosu,
      'ust_bilgi_satirlari': jsonEncode(ustBilgiSatirlari),
    };
  }

  factory SirketAyarlariModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedHeaderLines = [];
    try {
      if (map['ust_bilgi_satirlari'] != null) {
        parsedHeaderLines = List<String>.from(
          jsonDecode(map['ust_bilgi_satirlari'] as String),
        );
      }
    } catch (_) {}

    return SirketAyarlariModel(
      id: map['id'] as int?,
      kod: map['kod'] as String,
      ad: map['ad'] as String,
      basliklar: List<String>.from(jsonDecode(map['basliklar'] as String)),
      logolar: List<Map<String, String>>.from(
        (jsonDecode(map['logolar'] as String) as List).map(
          (item) => Map<String, String>.from(item),
        ),
      ),
      adres: map['adres']?.toString() ?? '',
      vergiDairesi: map['vergi_dairesi']?.toString() ?? '',
      vergiNo: map['vergi_no']?.toString() ?? '',
      telefon: map['telefon']?.toString() ?? '',
      eposta: map['eposta']?.toString() ?? '',
      webAdresi: map['web_adresi']?.toString() ?? '',
      aktifMi: (map['aktif_mi'] as int? ?? 1) == 1,
      varsayilanMi: (map['varsayilan_mi'] as int? ?? 0) == 1,
      duzenlenebilirMi: (map['duzenlenebilir_mi'] as int? ?? 1) == 1,
      ustBilgiLogosu: map['ust_bilgi_logosu'] as String?,
      ustBilgiSatirlari: parsedHeaderLines,
    );
  }
}
