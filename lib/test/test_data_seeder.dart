// ignore_for_file: avoid_print
// PATISYO TEST DATA SEEDER
//
// Bu araç, uygulamanın tüm modüllerini test etmek için
// gerçekçi test verileri oluşturur.
//
// Kullanım (Terminal):
// ```
// cd /Users/pateez/Desktop/patisyov10
// dart run lib/test/test_data_seeder.dart
// ```
//
// ⚠️ DİKKAT: Bu araç yalnızca TEST amaçlıdır.
// Production veritabanında KULLANMAYIN!

import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

// Servisler
import '../servisler/urunler_veritabani_servisi.dart';
import '../servisler/depolar_veritabani_servisi.dart';
import '../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../servisler/kasalar_veritabani_servisi.dart';
import '../servisler/bankalar_veritabani_servisi.dart';
import '../servisler/cekler_veritabani_servisi.dart';
import '../servisler/senetler_veritabani_servisi.dart';
import '../servisler/kredi_kartlari_veritabani_servisi.dart';
import '../servisler/ayarlar_veritabani_servisi.dart';

// Modeller
import '../sayfalar/urunler_ve_depolar/urunler/modeller/urun_model.dart';
import '../sayfalar/urunler_ve_depolar/depolar/modeller/depo_model.dart';
import '../sayfalar/carihesaplar/modeller/cari_hesap_model.dart';
import '../sayfalar/kasalar/modeller/kasa_model.dart';
import '../sayfalar/bankalar/modeller/banka_model.dart';
import '../sayfalar/ceksenet/modeller/cek_model.dart';
import '../sayfalar/ceksenet/modeller/senet_model.dart';
import '../sayfalar/kredikartlari/modeller/kredi_karti_model.dart';
import '../sayfalar/ayarlar/kullanicilar/modeller/kullanici_model.dart';
import '../sayfalar/ayarlar/roller_ve_izinler/modeller/rol_model.dart';

/// Ana seeder sınıfı
class TestDataSeeder {
  final Random _random = Random();

  // Test veri sayıları
  static const int urunSayisi = 100;
  static const int cariHesapSayisi = 100;
  static const int depoSayisi = 5;
  static const int kasaSayisi = 3;
  static const int bankaSayisi = 5;
  static const int cekSayisi = 100; // 50 alınan + 50 verilen
  static const int senetSayisi = 100; // 50 alınan + 50 verilen
  static const int krediKartiSayisi = 3;
  static const int kullaniciSayisi = 10;
  static const int rolSayisi = 5;

  // Gerçekçi veri listeleri
  final List<String> _urunAdlari = [
    'Salkım Domates',
    'Çengelköy Salatalık',
    'Köy Biberi',
    'Kemer Patlıcan',
    'Kuru Soğan',
    'Sarımsak',
    'Havuç',
    'Patates',
    'Kabak',
    'Ispanak',
    'Marul',
    'Lahana',
    'Brokoli',
    'Karnabahar',
    'Pırasa',
    'Kereviz',
    'Turp',
    'Pancar',
    'Mantar',
    'Bezelye',
    'Fasulye',
    'Bamya',
    'Enginar',
    'Kuşkonmaz',
    'Semizotu',
    'Elma',
    'Armut',
    'Üzüm',
    'Şeftali',
    'Erik',
    'Kayısı',
    'Kiraz',
    'Vişne',
    'Çilek',
    'Muz',
    'Portakal',
    'Mandalina',
    'Limon',
    'Greyfurt',
    'Kivi',
    'Ananas',
    'Mango',
    'Avokado',
    'Nar',
    'İncir',
    'Karpuz',
    'Kavun',
    'Hurma',
    'Ceviz',
    'Fındık',
    'Badem',
    'Antep Fıstığı',
    'Kaju',
    'Zeytinyağı (1L)',
    'Ayçiçek Yağı (2L)',
    'Tereyağı (500g)',
    'Süt (1L)',
    'Yoğurt (1kg)',
    'Peynir (500g)',
    'Yumurta (30lu)',
    'Bal (500g)',
    'Reçel (380g)',
    'Makarna (500g)',
    'Pirinç (1kg)',
    'Bulgur (1kg)',
    'Un (2kg)',
    'Şeker (1kg)',
    'Tuz (750g)',
    'Çay (500g)',
    'Kahve (250g)',
    'Bisküvi',
    'Çikolata',
    'Dondurma (1L)',
    'Su (5L)',
    'Meyve Suyu (1L)',
    'Gazlı İçecek (2.5L)',
    'Ekmek',
    'Simit',
    'Poğaça',
    'Börek',
    'Tavuk Göğsü (1kg)',
    'Dana Kıyma (1kg)',
    'Kuzu Pirzola (1kg)',
    'Balık Fileto (500g)',
    'Karides (500g)',
    'Sosis (200g)',
    'Sucuk (250g)',
    'Pastırma (150g)',
    'Salam (200g)',
    'Zeytin (500g)',
    'Turşu (660g)',
    'Ketçap (400g)',
    'Mayonez (450g)',
    'Hardal (200g)',
    'Deterjan (4kg)',
    'Yumuşatıcı (2L)',
    'Bulaşık Deterjanı (1L)',
    'Cam Temizleyici (750ml)',
    'Tuvalet Kağıdı (32li)',
    'Kağıt Havlu (12li)',
  ];

  final List<String> _gruplar = [
    'Sebze',
    'Meyve',
    'Baklagil',
    'Kuruyemiş',
    'Süt Ürünleri',
    'Et Ürünleri',
    'Deniz Ürünleri',
    'Şarküteri',
    'Temel Gıda',
    'İçecek',
    'Fırın Ürünleri',
    'Temizlik',
    'Kişisel Bakım',
    'Dondurulmuş',
  ];

  final List<String> _birimler = [
    'Adet',
    'Kg',
    'Litre',
    'Paket',
    'Kutu',
    'Koli',
  ];

  final List<double> _kdvOranlari = [0, 1, 8, 10, 18, 20];

  final List<String> _firmaAdlari = [
    'ABC Ticaret Ltd. Şti.',
    'XYZ Gıda A.Ş.',
    'Özgür Market',
    'Yıldız Pazarlama',
    'Güneş Tarım Ürünleri',
    'Ay Gıda San. Tic.',
    'Deniz Su Ürünleri',
    'Kaya İnşaat Malz.',
    'Şahin Nakliyat',
    'Aslan Otomotiv',
    'Kartal Elektronik',
    'Doğan Tekstil',
    'Yılmaz Mobilya',
    'Demir Hırdavat',
    'Altın Kuyumculuk',
    'Gümüş Aksesuar',
    'Bakır Mutfak',
    'Çelik Kapı',
    'Tunç Metal',
    'Bronz Dekorasyon',
  ];

  final List<String> _isimler = [
    'Ahmet',
    'Mehmet',
    'Ali',
    'Hasan',
    'Hüseyin',
    'Mustafa',
    'İbrahim',
    'Ömer',
    'Yusuf',
    'Kemal',
    'Fatma',
    'Ayşe',
    'Zeynep',
    'Hatice',
    'Emine',
    'Elif',
    'Merve',
    'Büşra',
    'Selin',
    'Ceren',
  ];

  final List<String> _soyisimler = [
    'Yılmaz',
    'Kaya',
    'Demir',
    'Çelik',
    'Şahin',
    'Yıldız',
    'Öztürk',
    'Aydın',
    'Özdemir',
    'Arslan',
    'Koç',
    'Kurt',
    'Aslan',
    'Acar',
    'Kara',
    'Ak',
    'Güneş',
    'Korkmaz',
    'Polat',
    'Keskin',
  ];

  final List<String> _sehirler = [
    'İstanbul',
    'Ankara',
    'İzmir',
    'Bursa',
    'Antalya',
    'Konya',
    'Adana',
    'Gaziantep',
    'Mersin',
    'Kayseri',
  ];

  final List<String> _bankalar = [
    'Akbank',
    'Garanti BBVA',
    'İş Bankası',
    'Yapı Kredi',
    'Ziraat Bankası',
    'Halkbank',
    'Vakıfbank',
    'QNB Finansbank',
    'Denizbank',
    'TEB',
  ];

  // Yardımcı metodlar
  String _randomElement<T>(List<T> list) =>
      list[_random.nextInt(list.length)].toString();

  double _randomDouble(double min, double max) =>
      min + _random.nextDouble() * (max - min);

  int _randomInt(int min, int max) => min + _random.nextInt(max - min + 1);

  String _randomPhone() =>
      '05${_randomInt(30, 59).toString().padLeft(2, '0')} ${_randomInt(100, 999)} ${_randomInt(10, 99)} ${_randomInt(10, 99)}';

  String _randomIban() =>
      'TR${_randomInt(10, 99)}${_randomInt(1000, 9999)}${_randomInt(1000, 9999)}${_randomInt(1000, 9999)}${_randomInt(1000, 9999)}${_randomInt(10, 99)}';

  String _randomDate({int daysBack = 365}) {
    final date = DateTime.now().subtract(
      Duration(days: _randomInt(0, daysBack)),
    );
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String _randomFutureDate({int daysForward = 180}) {
    final date = DateTime.now().add(
      Duration(days: _randomInt(30, daysForward)),
    );
    return DateFormat('dd.MM.yyyy').format(date);
  }

  // ==================== SEEDER METODLARI ====================

  /// 1. Depolar (5 adet)
  Future<List<int>> seedDepolar() async {
    print('\n📦 Depolar oluşturuluyor...');
    final servis = DepolarVeritabaniServisi();
    await servis.baslat();

    final depoIds = <int>[];
    final depoAdlari = [
      'Merkez Depo',
      'Şube Depo',
      'Soğuk Hava Deposu',
      'Hammadde Deposu',
      'Yedek Depo',
    ];

    for (int i = 0; i < depoSayisi; i++) {
      final depo = DepoModel(
        id: 0,
        kod: 'D${(i + 1).toString().padLeft(3, '0')}',
        ad: depoAdlari[i],
        adres:
            '${_randomElement(_sehirler)} - ${_randomElement(['Organize Sanayi', 'Serbest Bölge', 'Merkez', 'Şube'])} No: ${_randomInt(1, 100)}',
        sorumlu: '${_randomElement(_isimler)} ${_randomElement(_soyisimler)}',
        telefon: _randomPhone(),
        aktifMi: i < 4, // Son depo pasif
        createdBy: 'TestSeeder',
      );

      await servis.depoEkle(depo);
      depoIds.add(i + 1);
      print('   ✅ Depo ${i + 1}/$depoSayisi: ${depo.ad}');
    }

    return depoIds;
  }

  /// 2. Ürünler (100 adet)
  Future<void> seedUrunler(List<int> depoIds) async {
    print('\n🛒 Ürünler oluşturuluyor...');
    final servis = UrunlerVeritabaniServisi();
    await servis.baslat();

    for (int i = 0; i < urunSayisi; i++) {
      final alisFiyati = _randomDouble(5, 500);
      final karMarji = _randomDouble(1.1, 1.5);

      final urun = UrunModel(
        id: 0,
        kod: 'U${(i + 1).toString().padLeft(4, '0')}',
        ad: i < _urunAdlari.length ? _urunAdlari[i] : 'Ürün ${i + 1}',
        birim: _randomElement(_birimler),
        alisFiyati: alisFiyati,
        satisFiyati1: alisFiyati * karMarji,
        satisFiyati2: alisFiyati * (karMarji - 0.05),
        satisFiyati3: alisFiyati * (karMarji - 0.1),
        kdvOrani: _randomElement(_kdvOranlari) as double,
        stok: _randomDouble(10, 1000),
        erkenUyariMiktari: _randomDouble(5, 50),
        grubu: _randomElement(_gruplar),
        ozellikler: 'Test ürünü ${i + 1}',
        barkod: '869${_randomInt(100000000, 999999999)}',
        kullanici: 'TestSeeder',
        aktifMi: _random.nextDouble() > 0.1, // %90 aktif
        createdBy: 'TestSeeder',
      );

      await servis.urunEkle(
        urun,
        initialStockWarehouseId: depoIds[_random.nextInt(depoIds.length)],
        initialStockUnitCost: alisFiyati,
        createdBy: 'TestSeeder',
      );

      if ((i + 1) % 10 == 0) {
        print('   ✅ Ürün ${i + 1}/$urunSayisi oluşturuldu');
      }
    }
  }

  /// 3. Cari Hesaplar (100 adet)
  Future<List<CariHesapModel>> seedCariHesaplar() async {
    print('\n👥 Cari Hesaplar oluşturuluyor...');
    final servis = CariHesaplarVeritabaniServisi();
    await servis.baslat();

    final hesaplar = <CariHesapModel>[];
    final hesapTurleri = ['Alıcı', 'Satıcı', 'Alıcı/Satıcı'];

    for (int i = 0; i < cariHesapSayisi; i++) {
      final isFirma = _random.nextDouble() > 0.3; // %70 firma
      final ad = isFirma
          ? _randomElement(_firmaAdlari)
          : '${_randomElement(_isimler)} ${_randomElement(_soyisimler)}';

      final cari = CariHesapModel(
        id: 0,
        kodNo: 'C${(i + 1).toString().padLeft(4, '0')}',
        adi: ad,
        hesapTuru: hesapTurleri[i % 3],
        paraBirimi: _random.nextDouble() > 0.8 ? 'USD' : 'TRY',
        bakiyeBorc: _randomDouble(0, 50000),
        bakiyeAlacak: _randomDouble(0, 30000),
        telefon1: _randomPhone(),
        fatSehir: _randomElement(_sehirler),
        aktifMi: _random.nextDouble() > 0.05,
        fatUnvani: ad,
        fatAdresi:
            '${_randomElement(['Atatürk', 'İstiklal', 'Cumhuriyet', 'Gazi'])} Cad. No: ${_randomInt(1, 200)}',
        fatIlce: _randomElement([
          'Merkez',
          'Kadıköy',
          'Beşiktaş',
          'Şişli',
          'Üsküdar',
        ]),
        postaKodu: '${_randomInt(10000, 99999)}',
        vDairesi: '${_randomElement(_sehirler)} Vergi Dairesi',
        vNumarasi: '${_randomInt(1000000000, 9999999999)}',
        sfGrubu: _randomElement([
          'Toptan',
          'Perakende',
          'Bireysel',
          'Kurumsal',
        ]),
        sIskonto: _randomDouble(0, 15),
        vadeGun: _randomInt(0, 90),
        riskLimiti: _randomDouble(10000, 500000),
        telefon2: _randomPhone(),
        eposta:
            '${ad.toLowerCase().replaceAll(' ', '').replaceAll('.', '')}@email.com',
        kullanici: 'TestSeeder',
      );

      await servis.cariHesapEkle(cari);
      hesaplar.add(cari.copyWith(id: i + 1));

      if ((i + 1) % 10 == 0) {
        print('   ✅ Cari Hesap ${i + 1}/$cariHesapSayisi oluşturuldu');
      }
    }

    return hesaplar;
  }

  /// 4. Kasalar (3 adet)
  Future<List<int>> seedKasalar() async {
    print('\n💰 Kasalar oluşturuluyor...');
    final servis = KasalarVeritabaniServisi();
    await servis.baslat();

    final kasaIds = <int>[];
    final kasaAdlari = ['Ana Kasa (TL)', 'Döviz Kasa (USD)', 'Mağaza Kasası'];
    final paraBirimleri = ['TRY', 'USD', 'TRY'];

    for (int i = 0; i < kasaSayisi; i++) {
      final kasa = KasaModel(
        id: 0,
        kod: 'K${(i + 1).toString().padLeft(3, '0')}',
        ad: kasaAdlari[i],
        bakiye: _randomDouble(1000, 100000),
        paraBirimi: paraBirimleri[i],
        bilgi1: 'Test kasası ${i + 1}',
        aktifMi: true,
        varsayilan: i == 0,
      );

      await servis.kasaEkle(kasa);
      kasaIds.add(i + 1);
      print('   ✅ Kasa ${i + 1}/$kasaSayisi: ${kasa.ad}');
    }

    return kasaIds;
  }

  /// 5. Bankalar (5 adet)
  Future<List<int>> seedBankalar() async {
    print('\n🏦 Bankalar oluşturuluyor...');
    final servis = BankalarVeritabaniServisi();
    await servis.baslat();

    final bankaIds = <int>[];

    for (int i = 0; i < bankaSayisi; i++) {
      final bankaAdi = _bankalar[i];
      final banka = BankaModel(
        id: 0,
        kod: 'B${(i + 1).toString().padLeft(3, '0')}',
        ad: bankaAdi,
        bakiye: _randomDouble(10000, 500000),
        paraBirimi: i == 1 ? 'USD' : 'TRY',
        subeKodu: '${_randomInt(1000, 9999)}',
        subeAdi: '${_randomElement(_sehirler)} Şubesi',
        hesapNo: '${_randomInt(10000000, 99999999)}',
        iban: _randomIban(),
        bilgi1: 'Test banka hesabı',
        aktifMi: true,
        varsayilan: i == 0,
      );

      await servis.bankaEkle(banka);
      bankaIds.add(i + 1);
      print('   ✅ Banka ${i + 1}/$bankaSayisi: ${banka.ad}');
    }

    return bankaIds;
  }

  /// 6. Çekler (100 adet - 50 alınan, 50 verilen)
  Future<void> seedCekler(List<CariHesapModel> cariler) async {
    print('\n📝 Çekler oluşturuluyor...');
    final servis = CeklerVeritabaniServisi();
    await servis.baslat();

    final turler = ['Alınan Çek', 'Verilen Çek'];
    final tahsilatlar = ['Beklemede', 'Tahsil Edildi', 'Ciro Edildi'];

    for (int i = 0; i < cekSayisi; i++) {
      final cari = cariler[_random.nextInt(cariler.length)];
      final cek = CekModel(
        id: 0,
        tur: turler[i < 50 ? 0 : 1],
        tahsilat: tahsilatlar[_random.nextInt(tahsilatlar.length)],
        cariKod: cari.kodNo,
        cariAdi: cari.adi,
        duzenlenmeTarihi: _randomDate(daysBack: 180),
        kesideTarihi: _randomFutureDate(daysForward: 180),
        tutar: _randomDouble(1000, 50000),
        paraBirimi: 'TRY',
        cekNo: 'CK${(i + 1).toString().padLeft(6, '0')}',
        banka: _randomElement(_bankalar),
        aciklama: 'Test çeki ${i + 1}',
        kullanici: 'TestSeeder',
        aktifMi: true,
      );

      await servis.cekEkle(cek);

      if ((i + 1) % 20 == 0) {
        print('   ✅ Çek ${i + 1}/$cekSayisi oluşturuldu');
      }
    }
  }

  /// 7. Senetler (100 adet - 50 alınan, 50 verilen)
  Future<void> seedSenetler(List<CariHesapModel> cariler) async {
    print('\n📄 Senetler oluşturuluyor...');
    final servis = SenetlerVeritabaniServisi();
    await servis.baslat();

    final turler = ['Alınan Senet', 'Verilen Senet'];
    final tahsilatlar = ['Beklemede', 'Tahsil Edildi', 'Ciro Edildi'];

    for (int i = 0; i < senetSayisi; i++) {
      final cari = cariler[_random.nextInt(cariler.length)];
      final senet = SenetModel(
        id: 0,
        tur: turler[i < 50 ? 0 : 1],
        tahsilat: tahsilatlar[_random.nextInt(tahsilatlar.length)],
        cariKod: cari.kodNo,
        cariAdi: cari.adi,
        duzenlenmeTarihi: _randomDate(daysBack: 180),
        kesideTarihi: _randomFutureDate(daysForward: 180),
        tutar: _randomDouble(5000, 100000),
        paraBirimi: 'TRY',
        senetNo: 'SN${(i + 1).toString().padLeft(6, '0')}',
        banka: _randomElement(_bankalar),
        aciklama: 'Test senedi ${i + 1}',
        kullanici: 'TestSeeder',
        aktifMi: true,
      );

      await servis.senetEkle(senet);

      if ((i + 1) % 20 == 0) {
        print('   ✅ Senet ${i + 1}/$senetSayisi oluşturuldu');
      }
    }
  }

  /// 8. Kredi Kartları / POS (3 adet)
  Future<void> seedKrediKartlari() async {
    print('\n💳 Kredi Kartları/POS oluşturuluyor...');
    final servis = KrediKartlariVeritabaniServisi();
    await servis.baslat();

    final posAdlari = ['Akbank POS', 'Garanti POS', 'YKB POS'];

    for (int i = 0; i < krediKartiSayisi; i++) {
      final krediKarti = KrediKartiModel(
        id: 0,
        kod: 'POS${(i + 1).toString().padLeft(3, '0')}',
        ad: posAdlari[i],
        bakiye: _randomDouble(5000, 50000),
        paraBirimi: 'TRY',
        subeKodu: '${_randomInt(1000, 9999)}',
        subeAdi: '${_randomElement(_sehirler)} Şubesi',
        hesapNo: '${_randomInt(10000000, 99999999)}',
        iban: _randomIban(),
        bilgi1: 'Test POS cihazı',
        aktifMi: true,
        varsayilan: i == 0,
      );

      await servis.krediKartiEkle(krediKarti);
      print('   ✅ POS ${i + 1}/$krediKartiSayisi: ${krediKarti.ad}');
    }
  }

  /// 9. Kullanıcılar (10 adet)
  Future<void> seedKullanicilar() async {
    print('\n👤 Kullanıcılar oluşturuluyor...');
    final servis = AyarlarVeritabaniServisi();
    await servis.baslat();

    final roller = ['Admin', 'Satış', 'Depo', 'Muhasebe', 'Kasa'];
    final gorevler = ['Müdür', 'Uzman', 'Personel', 'Stajyer'];

    for (int i = 0; i < kullaniciSayisi; i++) {
      final isim = _randomElement(_isimler);
      final soyisim = _randomElement(_soyisimler);

      final kullanici = KullaniciModel(
        id: 'user_${i + 1}',
        kullaniciAdi: '${isim.toLowerCase()}${soyisim.toLowerCase()}',
        ad: isim,
        soyad: soyisim,
        eposta: '${isim.toLowerCase()}.${soyisim.toLowerCase()}@patisyo.com',
        rol: roller[i % roller.length],
        aktifMi: i < 9, // Son kullanıcı pasif
        telefon: _randomPhone(),
        sifre: servis.sifreHashle('Test1234!'),
        iseGirisTarihi: DateTime.now().subtract(
          Duration(days: _randomInt(30, 1000)),
        ),
        gorevi: gorevler[i % gorevler.length],
        maasi: _randomDouble(15000, 80000),
        paraBirimi: 'TRY',
        adresi: '${_randomElement(_sehirler)}, Türkiye',
      );

      await servis.kullaniciEkle(kullanici);
      print(
        '   ✅ Kullanıcı ${i + 1}/$kullaniciSayisi: ${kullanici.kullaniciAdi}',
      );
    }
  }

  /// 10. Roller (5 adet)
  Future<void> seedRoller() async {
    print('\n🔐 Roller oluşturuluyor...');
    final servis = AyarlarVeritabaniServisi();
    await servis.baslat();

    final rolBilgileri = [
      {
        'ad': 'Yönetici',
        'izinler': ['all'],
      },
      {
        'ad': 'Satış Temsilcisi',
        'izinler': ['sales', 'customers', 'products'],
      },
      {
        'ad': 'Depo Görevlisi',
        'izinler': ['warehouse', 'products', 'shipments'],
      },
      {
        'ad': 'Muhasebe Uzmanı',
        'izinler': ['finance', 'cashbox', 'banks', 'checks', 'notes'],
      },
      {
        'ad': 'Kasa Görevlisi',
        'izinler': ['cashbox', 'retail'],
      },
    ];

    for (int i = 0; i < rolSayisi; i++) {
      final rol = RolModel(
        id: 'rol_${i + 1}',
        ad: rolBilgileri[i]['ad'] as String,
        izinler: rolBilgileri[i]['izinler'] as List<String>,
        sistemRoluMu: i == 0,
        aktifMi: true,
      );

      await servis.rolEkle(rol);
      print('   ✅ Rol ${i + 1}/$rolSayisi: ${rol.ad}');
    }
  }

  /// ANA SEED METODU
  Future<void> runFullSeed() async {
    print('''
╔══════════════════════════════════════════════════════════════════════╗
║                    🧪 PATISYO TEST DATA SEEDER                       ║
║                                                                      ║
║  Bu araç tüm modüller için test verisi oluşturur.                    ║
║                                                                      ║
║  📦 Depolar: $depoSayisi adet                                              ║
║  🛒 Ürünler: $urunSayisi adet                                            ║
║  👥 Cari Hesaplar: $cariHesapSayisi adet                                     ║
║  💰 Kasalar: $kasaSayisi adet                                              ║
║  🏦 Bankalar: $bankaSayisi adet                                             ║
║  📝 Çekler: $cekSayisi adet (50 alınan + 50 verilen)                     ║
║  📄 Senetler: $senetSayisi adet (50 alınan + 50 verilen)                   ║
║  💳 POS/Kredi Kartları: $krediKartiSayisi adet                                   ║
║  👤 Kullanıcılar: $kullaniciSayisi adet                                       ║
║  🔐 Roller: $rolSayisi adet                                                ║
╚══════════════════════════════════════════════════════════════════════╝
''');

    final stopwatch = Stopwatch()..start();

    try {
      // 1. Depolar
      final depoIds = await seedDepolar();

      // 2. Ürünler (depolar gerekli)
      await seedUrunler(depoIds);

      // 3. Cari Hesaplar
      final cariler = await seedCariHesaplar();

      // 4. Kasalar
      await seedKasalar();

      // 5. Bankalar
      await seedBankalar();

      // 6. Çekler (cariler gerekli)
      await seedCekler(cariler);

      // 7. Senetler (cariler gerekli)
      await seedSenetler(cariler);

      // 8. Kredi Kartları
      await seedKrediKartlari();

      // 9. Kullanıcılar
      await seedKullanicilar();

      // 10. Roller
      await seedRoller();

      stopwatch.stop();

      print('''

╔══════════════════════════════════════════════════════════════════════╗
║                     ✅ SEED İŞLEMİ TAMAMLANDI!                       ║
║                                                                      ║
║  Toplam Süre: ${stopwatch.elapsed.inSeconds} saniye                                        ║
║                                                                      ║
║  Şimdi uygulamayı açıp tüm modülleri test edebilirsiniz!             ║
║                                                                      ║
║  📋 TEST CHECKLIST:                                                  ║
║  □ Ürünler listesini kontrol et (100 kayıt)                          ║
║  □ Cari Hesapları kontrol et (100 kayıt)                             ║
║  □ Kasaları kontrol et (3 kayıt)                                     ║
║  □ Bankaları kontrol et (5 kayıt)                                    ║
║  □ Çekleri kontrol et (100 kayıt)                                    ║
║  □ Senetleri kontrol et (100 kayıt)                                  ║
║  □ Alış/Satış işlemi dene                                            ║
║  □ Kasa para giriş/çıkış dene                                        ║
║  □ Arama ve filtreleme dene                                          ║
║  □ Düzenleme ve silme dene                                           ║
╚══════════════════════════════════════════════════════════════════════╝
''');
    } catch (e, stack) {
      print('\n❌ HATA: $e');
      print('Stack: $stack');
    }
  }
}

/// Main entry point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final seeder = TestDataSeeder();
  await seeder.runFullSeed();
}
