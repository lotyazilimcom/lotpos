class GenelAyarlarModel {
  // Para Birimi
  String varsayilanParaBirimi;
  String binlikAyiraci;
  String ondalikAyiraci;
  bool sembolGoster;

  // Sayısal
  int fiyatOndalik;
  int kurOndalik;
  int miktarOndalik;

  // Vergi
  bool otvKullanimi;
  String otvKdvDurumu; // 'excluded', 'included'
  bool oivKullanimi;
  String oivKdvDurumu;
  bool kdvTevkifati;
  String varsayilanKdvDurumu; // 'excluded' = KDV Hariç, 'included' = KDV Dahil

  // Ürün
  bool satirAciklamasi;
  String karZararYontemi;
  String urunSecimi;
  String aramaYontemi;
  bool siparistenDus;
  bool tekliftenDus;

  // Program
  bool acilistaDashboard;
  bool stokUyarilari;
  bool maliyetDoviziGoster;
  String otomatikKurGuncelleme;
  bool guncellemeBildirimleri;

  // Stok Kontrol
  bool eksiStokSatis;
  bool eksiStokUretim;

  // Muhasebe
  bool eksiBakiyeKontrol; // Kasa/Banka eksi bakiye kontrolü

  // Sistem
  bool loglama;
  bool cihazListesiModuluAktif;
  String sunucuModu; // 'server' or 'terminal'
  Map<String, bool> aktifModuller;

  // Kod Üretimi
  bool otoStokKodu;
  bool otoStokKoduAlfanumerik;
  bool otoStokBarkodu;
  bool otoStokBarkoduAlfanumerik;
  bool otoUretimKodu;
  bool otoUretimKoduAlfanumerik;
  bool otoUretimBarkodu;
  bool otoUretimBarkoduAlfanumerik;
  bool otoDepoKodu;
  bool otoDepoKoduAlfanumerik;
  bool otoCariKodu;
  bool otoCariKoduAlfanumerik;
  bool otoKasaKodu;
  bool otoKasaKoduAlfanumerik;
  bool otoBankaKodu;
  bool otoBankaKoduAlfanumerik;
  bool otoKrediKartiKodu;
  bool otoKrediKartiKoduAlfanumerik;
  bool otoPersonelKodu;
  bool otoPersonelKoduAlfanumerik;

  // Yazdırma
  String nakit1;
  String nakit2;
  String nakit3;
  String nakit4;
  String nakit5;
  String nakit6;
  bool otomatikYazdir;
  String yazdirmaSablonu;
  String yaziciSecimi;
  String kopyaSayisi;
  String iskontoOndalik;
  bool teraziBarkoduTani;

  // Listeler (JSON olarak saklanacak)
  List<Map<String, dynamic>> urunBirimleri;
  List<Map<String, dynamic>> urunGruplari;
  List<String> kullanilanParaBirimleri;

  // Constructor with defaults
  GenelAyarlarModel({
    this.varsayilanParaBirimi = 'TRY',
    this.binlikAyiraci = '.',
    this.ondalikAyiraci = ',',
    this.sembolGoster = true,
    this.fiyatOndalik = 2,
    this.kurOndalik = 4,
    this.miktarOndalik = 2,
    this.otvKullanimi = false,
    this.otvKdvDurumu = 'excluded',
    this.oivKullanimi = false,
    this.oivKdvDurumu = 'excluded',
    this.kdvTevkifati = false,
    this.varsayilanKdvDurumu = 'excluded',
    this.satirAciklamasi = true,
    this.karZararYontemi = 'average',
    this.urunSecimi = 'name',
    this.aramaYontemi = 'instant',
    this.siparistenDus = false,
    this.tekliftenDus = false,
    this.acilistaDashboard = true,
    this.stokUyarilari = true,
    this.maliyetDoviziGoster = true,
    this.otomatikKurGuncelleme = 'sell',
    this.guncellemeBildirimleri = true,
    this.eksiStokSatis = false,
    this.eksiStokUretim = false,
    this.eksiBakiyeKontrol = true,
    this.loglama = true,
    this.cihazListesiModuluAktif = true,
    this.sunucuModu = 'server',
    this.otoStokKodu = true,
    this.otoStokKoduAlfanumerik = false,
    this.otoStokBarkodu = false,
    this.otoStokBarkoduAlfanumerik = false,
    this.otoUretimKodu = true,
    this.otoUretimKoduAlfanumerik = false,
    this.otoUretimBarkodu = false,
    this.otoUretimBarkoduAlfanumerik = false,
    this.otoDepoKodu = true,
    this.otoDepoKoduAlfanumerik = false,
    this.otoCariKodu = true,
    this.otoCariKoduAlfanumerik = false,
    this.otoKasaKodu = true,
    this.otoKasaKoduAlfanumerik = true,
    this.otoBankaKodu = true,
    this.otoBankaKoduAlfanumerik = true,
    this.otoKrediKartiKodu = true,
    this.otoKrediKartiKoduAlfanumerik = true,
    this.otoPersonelKodu = true,
    this.otoPersonelKoduAlfanumerik = false,
    this.nakit1 = '5',
    this.nakit2 = '10',
    this.nakit3 = '20',
    this.nakit4 = '50',
    this.nakit5 = '100',
    this.nakit6 = '200',
    this.otomatikYazdir = false,
    this.yazdirmaSablonu = 'sales',
    this.yaziciSecimi = '',
    this.kopyaSayisi = '1',
    this.iskontoOndalik = '2',
    this.teraziBarkoduTani = false,
    this.urunBirimleri = const [
      {'name': 'Adet', 'isDefault': true},
      {'name': 'Kg', 'isDefault': false},
      {'name': 'Lt', 'isDefault': false},
      {'name': 'Mt', 'isDefault': false},
    ],
    this.urunGruplari = const [
      {'name': 'Genel', 'color': 0xFF2196F3},
      {'name': 'Gıda', 'color': 0xFF4CAF50},
      {'name': 'Elektronik', 'color': 0xFFFF9800},
      {'name': 'Temizlik', 'color': 0xFFF44336},
    ],
    this.kullanilanParaBirimleri = const ['TRY', 'USD', 'EUR', 'GBP'],
    this.aktifModuller = const {
      'trading_operations': true,
      'trading_operations.fast_sale': true,
      'trading_operations.make_purchase': true,
      'trading_operations.make_sale': true,
      'trading_operations.retail_sale': true,
      'orders_quotes': true,
      'orders_quotes.orders': true,
      'orders_quotes.quotes': true,
      'products_warehouses': true,
      'products_warehouses.products': true,
      'products_warehouses.productions': true,
      'products_warehouses.warehouses': true,
      'accounts': true,
      'cash_bank': true,
      'cash_bank.cash': true,
      'cash_bank.banks': true,
      'cash_bank.credit_cards': true,
      'checks_notes': true,
      'checks_notes.checks': true,
      'checks_notes.notes': true,
      'personnel_user': true,
      'expenses': true,
    },
  });

  Map<String, dynamic> toMap() {
    return {
      'varsayilanParaBirimi': varsayilanParaBirimi,
      'binlikAyiraci': binlikAyiraci,
      'ondalikAyiraci': ondalikAyiraci,
      'sembolGoster': sembolGoster ? 1 : 0,
      'fiyatOndalik': fiyatOndalik,
      'kurOndalik': kurOndalik,
      'miktarOndalik': miktarOndalik,
      'otvKullanimi': otvKullanimi ? 1 : 0,
      'otvKdvDurumu': otvKdvDurumu,
      'oivKullanimi': oivKullanimi ? 1 : 0,
      'oivKdvDurumu': oivKdvDurumu,
      'kdvTevkifati': kdvTevkifati ? 1 : 0,
      'varsayilanKdvDurumu': varsayilanKdvDurumu,
      'satirAciklamasi': satirAciklamasi ? 1 : 0,
      'karZararYontemi': karZararYontemi,
      'urunSecimi': urunSecimi,
      'aramaYontemi': aramaYontemi,
      'siparistenDus': siparistenDus ? 1 : 0,
      'tekliftenDus': tekliftenDus ? 1 : 0,
      'acilistaDashboard': acilistaDashboard ? 1 : 0,
      'stokUyarilari': stokUyarilari ? 1 : 0,
      'maliyetDoviziGoster': maliyetDoviziGoster ? 1 : 0,
      'otomatikKurGuncelleme': otomatikKurGuncelleme,
      'guncellemeBildirimleri': guncellemeBildirimleri ? 1 : 0,
      'eksiStokSatis': eksiStokSatis ? 1 : 0,
      'eksiStokUretim': eksiStokUretim ? 1 : 0,
      'eksiBakiyeKontrol': eksiBakiyeKontrol ? 1 : 0,
      'loglama': loglama ? 1 : 0,
      'cihazListesiModuluAktif': cihazListesiModuluAktif ? 1 : 0,
      'sunucuModu': sunucuModu,
      'otoStokKodu': otoStokKodu ? 1 : 0,
      'otoStokKoduAlfanumerik': otoStokKoduAlfanumerik ? 1 : 0,
      'otoStokBarkodu': otoStokBarkodu ? 1 : 0,
      'otoStokBarkoduAlfanumerik': otoStokBarkoduAlfanumerik ? 1 : 0,
      'otoUretimKodu': otoUretimKodu ? 1 : 0,
      'otoUretimKoduAlfanumerik': otoUretimKoduAlfanumerik ? 1 : 0,
      'otoUretimBarkodu': otoUretimBarkodu ? 1 : 0,
      'otoUretimBarkoduAlfanumerik': otoUretimBarkoduAlfanumerik ? 1 : 0,
      'otoDepoKodu': otoDepoKodu ? 1 : 0,
      'otoDepoKoduAlfanumerik': otoDepoKoduAlfanumerik ? 1 : 0,
      'otoCariKodu': otoCariKodu ? 1 : 0,
      'otoCariKoduAlfanumerik': otoCariKoduAlfanumerik ? 1 : 0,
      'otoKasaKodu': otoKasaKodu ? 1 : 0,
      'otoKasaKoduAlfanumerik': otoKasaKoduAlfanumerik ? 1 : 0,
      'otoBankaKodu': otoBankaKodu ? 1 : 0,
      'otoBankaKoduAlfanumerik': otoBankaKoduAlfanumerik ? 1 : 0,
      'otoKrediKartiKodu': otoKrediKartiKodu ? 1 : 0,
      'otoKrediKartiKoduAlfanumerik': otoKrediKartiKoduAlfanumerik ? 1 : 0,
      'otoPersonelKodu': otoPersonelKodu ? 1 : 0,
      'otoPersonelKoduAlfanumerik': otoPersonelKoduAlfanumerik ? 1 : 0,
      'nakit1': nakit1,
      'nakit2': nakit2,
      'nakit3': nakit3,
      'nakit4': nakit4,
      'nakit5': nakit5,
      'nakit6': nakit6,
      'otomatikYazdir': otomatikYazdir ? 1 : 0,
      'yazdirmaSablonu': yazdirmaSablonu,
      'yaziciSecimi': yaziciSecimi,
      'kopyaSayisi': kopyaSayisi,
      'iskontoOndalik': iskontoOndalik,
      'teraziBarkoduTani': teraziBarkoduTani ? 1 : 0,
      'urunBirimleri': urunBirimleri,
      'urunGruplari': urunGruplari,
      'kullanilanParaBirimleri': kullanilanParaBirimleri,
      'aktifModuller': aktifModuller,
    };
  }

  factory GenelAyarlarModel.fromMap(Map<String, dynamic> map) {
    return GenelAyarlarModel(
      varsayilanParaBirimi: map['varsayilanParaBirimi'] ?? 'TRY',
      binlikAyiraci: map['binlikAyiraci'] ?? '.',
      ondalikAyiraci: map['ondalikAyiraci'] ?? ',',
      sembolGoster: (map['sembolGoster'] ?? 1) == 1,
      fiyatOndalik: map['fiyatOndalik'] ?? 2,
      kurOndalik: map['kurOndalik'] ?? 4,
      miktarOndalik: map['miktarOndalik'] ?? 2,
      otvKullanimi: (map['otvKullanimi'] ?? 0) == 1,
      otvKdvDurumu: map['otvKdvDurumu'] ?? 'excluded',
      oivKullanimi: (map['oivKullanimi'] ?? 0) == 1,
      oivKdvDurumu: map['oivKdvDurumu'] ?? 'excluded',
      kdvTevkifati: (map['kdvTevkifati'] ?? 0) == 1,
      varsayilanKdvDurumu: map['varsayilanKdvDurumu'] ?? 'excluded',
      satirAciklamasi: (map['satirAciklamasi'] ?? 1) == 1,
      karZararYontemi: map['karZararYontemi'] ?? 'average',
      urunSecimi: map['urunSecimi'] ?? 'name',
      aramaYontemi: map['aramaYontemi'] ?? 'instant',
      siparistenDus: (map['siparistenDus'] ?? 0) == 1,
      tekliftenDus: (map['tekliftenDus'] ?? 0) == 1,
      acilistaDashboard: (map['acilistaDashboard'] ?? 1) == 1,
      stokUyarilari: (map['stokUyarilari'] ?? 1) == 1,
      maliyetDoviziGoster: (map['maliyetDoviziGoster'] ?? 1) == 1,
      otomatikKurGuncelleme: map['otomatikKurGuncelleme'] ?? 'sell',
      guncellemeBildirimleri: (map['guncellemeBildirimleri'] ?? 1) == 1,
      eksiStokSatis: (map['eksiStokSatis'] ?? 0) == 1,
      eksiStokUretim: (map['eksiStokUretim'] ?? 0) == 1,
      eksiBakiyeKontrol: (map['eksiBakiyeKontrol'] ?? 1) == 1,
      loglama: (map['loglama'] ?? 1) == 1,
      cihazListesiModuluAktif: (map['cihazListesiModuluAktif'] ?? 1) == 1,
      sunucuModu: map['sunucuModu']?.toString() ?? 'server',
      otoStokKodu: (map['otoStokKodu'] ?? 1) == 1,
      otoStokKoduAlfanumerik: (map['otoStokKoduAlfanumerik'] ?? 0) == 1,
      otoStokBarkodu: (map['otoStokBarkodu'] ?? 0) == 1,
      otoStokBarkoduAlfanumerik: (map['otoStokBarkoduAlfanumerik'] ?? 0) == 1,
      otoUretimKodu: (map['otoUretimKodu'] ?? 1) == 1,
      otoUretimKoduAlfanumerik: (map['otoUretimKoduAlfanumerik'] ?? 0) == 1,
      otoUretimBarkodu: (map['otoUretimBarkodu'] ?? 0) == 1,
      otoUretimBarkoduAlfanumerik:
          (map['otoUretimBarkoduAlfanumerik'] ?? 0) == 1,
      otoDepoKodu: (map['otoDepoKodu'] ?? 1) == 1,
      otoDepoKoduAlfanumerik: (map['otoDepoKoduAlfanumerik'] ?? 0) == 1,
      otoCariKodu: (map['otoCariKodu'] ?? 1) == 1,
      otoCariKoduAlfanumerik: (map['otoCariKoduAlfanumerik'] ?? 0) == 1,
      otoKasaKodu: (map['otoKasaKodu'] ?? 1) == 1,
      otoKasaKoduAlfanumerik: (map['otoKasaKoduAlfanumerik'] ?? 1) == 1,
      otoBankaKodu: (map['otoBankaKodu'] ?? 1) == 1,
      otoBankaKoduAlfanumerik: (map['otoBankaKoduAlfanumerik'] ?? 1) == 1,
      otoKrediKartiKodu: (map['otoKrediKartiKodu'] ?? 1) == 1,
      otoKrediKartiKoduAlfanumerik:
          (map['otoKrediKartiKoduAlfanumerik'] ?? 1) == 1,
      otoPersonelKodu: (map['otoPersonelKodu'] ?? 1) == 1,
      otoPersonelKoduAlfanumerik: (map['otoPersonelKoduAlfanumerik'] ?? 0) == 1,
      nakit1: map['nakit1']?.toString() ?? '5',
      nakit2: map['nakit2']?.toString() ?? '10',
      nakit3: map['nakit3']?.toString() ?? '20',
      nakit4: map['nakit4']?.toString() ?? '50',
      nakit5: map['nakit5']?.toString() ?? '100',
      nakit6: map['nakit6']?.toString() ?? '200',
      otomatikYazdir: (map['otomatikYazdir'] ?? 0) == 1,
      yazdirmaSablonu: map['yazdirmaSablonu']?.toString() ?? 'sales',
      yaziciSecimi: map['yaziciSecimi']?.toString() ?? '',
      kopyaSayisi: map['kopyaSayisi']?.toString() ?? '1',
      iskontoOndalik: map['iskontoOndalik']?.toString() ?? '2',
      teraziBarkoduTani: (map['teraziBarkoduTani'] ?? 0) == 1,
      urunBirimleri: List<Map<String, dynamic>>.from(
        map['urunBirimleri'] ??
            [
              {'name': 'Adet', 'isDefault': true},
              {'name': 'Kg', 'isDefault': false},
              {'name': 'Lt', 'isDefault': false},
              {'name': 'Mt', 'isDefault': false},
            ],
      ),
      urunGruplari: List<Map<String, dynamic>>.from(
        map['urunGruplari'] ??
            [
              {'name': 'Genel', 'color': 0xFF2196F3},
              {'name': 'Gıda', 'color': 0xFF4CAF50},
              {'name': 'Elektronik', 'color': 0xFFFF9800},
              {'name': 'Temizlik', 'color': 0xFFF44336},
            ],
      ),
      kullanilanParaBirimleri: List<String>.from(
        map['kullanilanParaBirimleri'] ?? ['TRY', 'USD', 'EUR', 'GBP'],
      ),
      aktifModuller: Map<String, bool>.from(
        map['aktifModuller'] ??
            {
              'trading_operations': true,
              'trading_operations.fast_sale': true,
              'trading_operations.make_purchase': true,
              'trading_operations.make_sale': true,
              'trading_operations.retail_sale': true,
              'orders_quotes': true,
              'orders_quotes.orders': true,
              'orders_quotes.quotes': true,
              'products_warehouses': true,
              'products_warehouses.products': true,
              'products_warehouses.productions': true,
              'products_warehouses.warehouses': true,
              'accounts': true,
              'cash_bank': true,
              'cash_bank.cash': true,
              'cash_bank.banks': true,
              'cash_bank.credit_cards': true,
              'checks_notes': true,
              'checks_notes.checks': true,
              'checks_notes.notes': true,
              'personnel_user': true,
              'expenses': true,
            },
      ),
    );
  }
}
