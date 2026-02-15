import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:patisyov10/servisler/ayarlar_veritabani_servisi.dart';
import 'package:patisyov10/servisler/bankalar_veritabani_servisi.dart';
import 'package:patisyov10/servisler/cari_hesaplar_veritabani_servisi.dart';
import 'package:patisyov10/servisler/depolar_veritabani_servisi.dart';
import 'package:patisyov10/servisler/kasalar_veritabani_servisi.dart';
import 'package:patisyov10/servisler/kredi_kartlari_veritabani_servisi.dart';
import 'package:patisyov10/servisler/urunler_veritabani_servisi.dart';
import 'package:patisyov10/servisler/cekler_veritabani_servisi.dart';
import 'package:patisyov10/servisler/senetler_veritabani_servisi.dart';
import 'package:patisyov10/sayfalar/ceksenet/modeller/cek_model.dart';
import 'package:patisyov10/sayfalar/ceksenet/modeller/senet_model.dart';
import 'package:patisyov10/servisler/siparisler_veritabani_servisi.dart';
import 'package:patisyov10/servisler/maliyet_hesaplama_servisi.dart';
import 'package:patisyov10/servisler/lite_kisitlari.dart';
import 'package:intl/intl.dart';

/// Alış yap işlemleriyle ilgili Entegre Veritabanı Servisi
/// Bu servis; Stok, Cari, Kasa/Banka modülleriyle eşzamanlı konuşur.
class AlisYapVeritabaniServisi {
  static final AlisYapVeritabaniServisi _instance =
      AlisYapVeritabaniServisi._internal();
  factory AlisYapVeritabaniServisi() => _instance;
  AlisYapVeritabaniServisi._internal();

  /// Alış işlemini Tam Entegre şekilde kaydeder.
  Future<void> alisIsleminiKaydet({
    required Map<String, dynamic> alisBilgileri,
    TxSession? session,
  }) async {
    final urunServisi = UrunlerVeritabaniServisi();

    if (session != null) {
      if (LiteKisitlari.isLiteMode) {
        await _ensureGunlukIslemLimiti(
          islemBilgileri: alisBilgileri,
          session: session,
        );
      }
      await _alisIsleminiKaydetInternal(alisBilgileri, session);
    } else {
      await urunServisi.transactionBaslat((s) async {
        if (LiteKisitlari.isLiteMode) {
          await _ensureGunlukIslemLimiti(
            islemBilgileri: alisBilgileri,
            session: s,
          );
        }
        await _alisIsleminiKaydetInternal(alisBilgileri, s);
      }, isolationLevel: IsolationLevel.serializable);
    }
  }

  Future<void> _ensureGunlukIslemLimiti({
    required Map<String, dynamic> islemBilgileri,
    required TxSession session,
  }) async {
    if (!LiteKisitlari.isLiteMode) return;

    final DateTime tarih =
        islemBilgileri['tarih'] as DateTime? ?? DateTime.now();
    final gunBas = DateTime(tarih.year, tarih.month, tarih.day);
    final gunSon = gunBas.add(const Duration(days: 1));

    final cap = LiteKisitlari.maxGunlukSatis;
    final res = await session.execute(
      Sql.named('''
        SELECT COUNT(*) FROM (
          SELECT DISTINCT integration_ref
          FROM stock_movements
          WHERE integration_ref IS NOT NULL
            AND (integration_ref LIKE 'PURCHASE-%' OR integration_ref LIKE 'SALE-%')
            AND movement_date >= @start
            AND movement_date < @end
          LIMIT @cap
        ) AS sub
      '''),
      parameters: {'start': gunBas, 'end': gunSon, 'cap': cap},
    );

    final current = (res.first[0] as int?) ?? 0;
    if (current >= cap) {
      throw LiteLimitHatasi(
        'LITE sürümde günlük en fazla $cap alış/satış işlemi yapılabilir. Pro sürüme geçin.',
      );
    }
  }

  // Performans Arttırıcı Cache
  static final Map<String, int> _accountCache = {};

  Future<void> _alisIsleminiKaydetInternal(
    Map<String, dynamic> alisBilgileri,
    TxSession s, {
    String? existingRef,
  }) async {
    final urunServisi = UrunlerVeritabaniServisi();

    double toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
    }

    final int cariId = int.tryParse(alisBilgileri['cariId'].toString()) ?? 0;
    final DateTime tarih = alisBilgileri['tarih'] as DateTime;
    final String belgeTuru = alisBilgileri['belgeTuru'] ?? 'Fatura';
    final String faturaNo = alisBilgileri['faturaNo'] ?? '';
    final String aciklama = alisBilgileri['aciklama'] ?? '';
    final double genelToplam = toDouble(alisBilgileri['genelToplam']);
    final double verilenTutar = toDouble(alisBilgileri['verilenTutar']);
    final String odemeYeri = alisBilgileri['odemeYeri'] ?? 'Kasa';
    final String odemeHesapKodu = alisBilgileri['odemeHesapKodu'] ?? '';
    final String odemeAciklamaSecimi =
        (alisBilgileri['odemeAciklama'] as String?)?.trim() ?? '';
    final List<dynamic> items = alisBilgileri['items'] ?? [];
    final String kullanici = alisBilgileri['kullanici'] ?? 'Sistem';

    final String cariKodu = alisBilgileri['selectedCariCode'] ?? '';
    final String cariAdi = alisBilgileri['selectedCariName'] ?? '';
    final String paraBirimi = alisBilgileri['paraBirimi'] ?? 'TRY';
    final double kur = toDouble(alisBilgileri['kur'] ?? 1.0);

    // ENTEGRASYON REF (SAĞLAM SİLME VE GÜNCELLEME İÇİN)
    // Güncelleme işleminde eski referansı koruyarak zinciri sürdürüyoruz.
    final String integrationRef =
        existingRef ??
        'PURCHASE-${DateTime.now().millisecondsSinceEpoch}-${(1000 + (DateTime.now().microsecond % 9000))}';

    // [PERFORMANCE FIX] Batch Fetch IDs
    final List<String> urunKodlari = items
        .map<String>((e) => e['code'].toString())
        .toList();
    final Map<String, int> urunIdMap = await urunServisi.urunIdleriniGetir(
      urunKodlari,
    );

    // 1.1 ADIM: SHIPMENTS KAYDI OLUŞTUR (Ürün/Üretim/Depo ekranlarında görünmesi için)
    final shipmentIdByWarehouse = await _stokHareketiShipmentleriOlustur(
      items: items,
      tarih: tarih,
      belgeTuru: belgeTuru,
      belgeNo: faturaNo,
      aciklama: aciklama,
      cariAdi: cariAdi,
      cariKodu: cariKodu,
      kullanici: kullanici,
      entegrasyonRef: integrationRef,
      session: s,
    );
    DepolarVeritabaniServisi().islemTurleriCacheTemizle();

    // 1. ADIM: STOK HAREKETLERİNİ İŞLE (HELPER KULLANIMI)
    await _stokItemsIsle(
      items: items,
      urunIdMap: urunIdMap,
      tarih: tarih,
      aciklama: aciklama,
      kullanici: kullanici,
      integrationRef: integrationRef,
      shipmentIdByWarehouse: shipmentIdByWarehouse,
      session: s,
    );

    // [FIX] İrsaliye ise Cari ve Finans hareketleri oluşmaz
    if (belgeTuru != 'İrsaliye') {
      // 2. ADIM: CARİ HESAP HAREKETİ (BORÇLANMA)
      final cariServis = CariHesaplarVeritabaniServisi();
      await cariServis.cariIslemEkle(
        cariId: cariId,
        tutar: genelToplam,
        isBorc: false, // Alış -> Cari Alacak (Credit)
        islemTuru: 'Alış Yapıldı',
        aciklama: aciklama,
        tarih: tarih,
        kullanici: kullanici,
        entegrasyonRef: integrationRef,
        paraBirimi: paraBirimi,
        kur: kur,
        belgeNo: faturaNo,
        vadeTarihi: alisBilgileri['vadeTarihi'] is DateTime
            ? alisBilgileri['vadeTarihi'] as DateTime
            : null,
        urunAdi: items.isNotEmpty
            ? (items.first['name'] ?? items.first['code'])
            : null,
        miktar: items.isNotEmpty
            ? double.tryParse(items.first['quantity'].toString())
            : null,
        birim: items.isNotEmpty ? items.first['unit'] : null,
        birimFiyat: items.isNotEmpty
            ? double.tryParse(items.first['price'].toString())
            : null,
        hamFiyat: items.isNotEmpty
            ? double.tryParse(items.first['price'].toString())
            : null,
        session: s, // Transaction Session
      );

      // 3. ADIM: ÖDEME KONTROLÜ
      if (verilenTutar > 0) {
        // Otomatik açıklama oluşturma yok: kullanıcı boş bıraktıysa boş kalır.
        final String odemeAciklama = odemeAciklamaSecimi.isNotEmpty
            ? odemeAciklamaSecimi
            : '';

        await _odemeIsle(
          verilenTutar: verilenTutar,
          odemeYeri: odemeYeri,
          odemeHesapKodu: odemeHesapKodu,
          odemeAciklama: odemeAciklama,
          tarih: tarih,
          cariKodu: cariKodu,
          cariAdi: cariAdi,
          kullanici: kullanici,
          integrationRef: integrationRef,
          alisBilgileri: alisBilgileri,
          faturaNo: faturaNo,
          session: s,
        );
      }
    }

    // 4. ADIM: SİPARİŞ DURUM GÜNCELLEME (VARSA)
    final int? orderId = int.tryParse(
      alisBilgileri['orderRef']?.toString() ?? '',
    );
    if (orderId != null) {
      final String status = alisBilgileri['orderStatus'] ?? 'Alış Yapıldı';
      await SiparislerVeritabaniServisi().siparisDurumGuncelle(
        orderId,
        status,
        session: s,
      );
    }
  }

  // --- HELPER METHODS FOR MODULAR REUSE (SMART UPDATE) ---

  Future<void> _stokItemsIsle({
    required List<dynamic> items,
    required Map<String, int> urunIdMap,
    required DateTime tarih,
    required String aciklama,
    required String kullanici,
    required String integrationRef,
    required Map<int, int> shipmentIdByWarehouse,
    required TxSession session,
  }) async {
    final urunServisi = UrunlerVeritabaniServisi();
    double toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
    }

    for (var item in items) {
      final String kod = item['code'];
      final double miktar = double.tryParse(item['quantity'].toString()) ?? 0.0;
      final double fiyat = double.tryParse(item['price'].toString()) ?? 0.0;
      final int? depoId = int.tryParse(item['warehouseId']?.toString() ?? '');
      final String itemCurrency = item['currency']?.toString() ?? 'TRY';
      final double itemRate = toDouble(item['exchangeRate'] ?? 1.0);

      final int? urunId = urunIdMap[kod];

      if (urunId != null) {
        await urunServisi.stokIslemiYap(
          urunId: urunId,
          urunKodu: kod,
          miktar: miktar,
          isGiris: true, // ALIŞ İŞLEMİ GİRİŞTİR
          islemTuru: 'Alış Faturası',
          tarih: tarih,
          aciklama: aciklama,
          kullanici: kullanici,
          birimFiyat: fiyat,
          paraBirimi: itemCurrency,
          kur: itemRate,
          depoId: depoId,
          shipmentId: depoId != null ? shipmentIdByWarehouse[depoId] : null,
          entegrasyonRef: integrationRef,
          serialNumber: item['serialNumber'],
          session: session,
        );
      } else {
        // Üretim kartı (productions) stok güncelle
        await _uretimStokGuncelle(
          kod: kod,
          miktar: miktar,
          isGiris: true,
          depoId: depoId,
          session: session,
        );
      }
    }
  }

  Future<Map<String, Map<String, String>>> _stokKalemiMetaGetir(
    List<String> kodlar,
    TxSession session,
  ) async {
    if (kodlar.isEmpty) return {};

    final uniqueCodes = kodlar.toSet().toList();
    final Map<String, Map<String, String>> meta = {};

    try {
      final urunRes = await session.execute(
        Sql.named(
          'SELECT kod, ad, birim FROM products WHERE kod = ANY(@codes)',
        ),
        parameters: {'codes': uniqueCodes},
      );
      for (final row in urunRes) {
        meta[row[0] as String] = {
          'name': (row[1] as String?) ?? '',
          'unit': (row[2] as String?) ?? 'Adet',
        };
      }
    } catch (e) {
      debugPrint('Ürün meta sorgu hatası: $e');
    }

    try {
      final uretimRes = await session.execute(
        Sql.named(
          'SELECT kod, ad, birim FROM productions WHERE kod = ANY(@codes)',
        ),
        parameters: {'codes': uniqueCodes},
      );
      for (final row in uretimRes) {
        final code = row[0] as String;
        meta.putIfAbsent(code, () {
          return {
            'name': (row[1] as String?) ?? '',
            'unit': (row[2] as String?) ?? 'Adet',
          };
        });
      }
    } catch (e) {
      debugPrint('Üretim meta sorgu hatası: $e');
    }

    return meta;
  }

  String _alisShipmentAciklamaOlustur({
    required String belgeTuru,
    required String belgeNo,
    required String cariAdi,
    required String cariKodu,
    required String aciklama,
  }) {
    // Patisyo V10 Update:
    // Otomatik açıklama (prefix) oluşturma kapatıldı.
    // Sadece kullanıcının girdiği açıklama kaydedilecek.
    return aciklama;
  }

  Future<Map<int, int>> _stokHareketiShipmentleriOlustur({
    required List<dynamic> items,
    required DateTime tarih,
    required String belgeTuru,
    required String belgeNo,
    required String aciklama,
    required String cariAdi,
    required String cariKodu,
    required String kullanici,
    required String entegrasyonRef,
    required TxSession session,
  }) async {
    final codes = items
        .map((e) => e['code']?.toString() ?? '')
        .where((c) => c.isNotEmpty)
        .toList(growable: false);

    final metaMap = await _stokKalemiMetaGetir(codes, session);
    final Map<int, List<Map<String, dynamic>>> byWarehouse = {};

    double toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
    }

    for (final raw in items) {
      final code = raw['code']?.toString() ?? '';
      if (code.isEmpty) continue;

      final int? warehouseId = int.tryParse(
        raw['warehouseId']?.toString() ?? '',
      );
      if (warehouseId == null || warehouseId <= 0) {
        throw Exception('Lütfen bir depo seçiniz. ($code)');
      }

      final double quantity =
          double.tryParse(raw['quantity']?.toString() ?? '') ?? 0.0;
      final double unitPrice =
          double.tryParse(raw['price']?.toString() ?? '') ?? 0.0;
      final String currency = raw['currency']?.toString() ?? 'TRY';
      final double rate = toDouble(raw['exchangeRate'] ?? 1.0);
      final double localUnitPrice = (currency != 'TRY' && rate > 0)
          ? (unitPrice * rate)
          : unitPrice;
      final double lineTotal = toDouble(raw['total']);
      final double localLineTotal = (currency != 'TRY' && rate > 0)
          ? (lineTotal * rate)
          : lineTotal;

      final double discountRate = toDouble(
        raw['discountRate'] ?? raw['discount'] ?? raw['iskonto'],
      );
      final double vatRate = toDouble(raw['vatRate'] ?? raw['vat_rate']);
      final double otvRate = toDouble(raw['otvRate'] ?? raw['otv_rate']);
      final double oivRate = toDouble(raw['oivRate'] ?? raw['oiv_rate']);
      final dynamic kdvTevkifatOrani =
          raw['kdvTevkifatOrani'] ??
          raw['kdv_tevkifat_orani'] ??
          raw['tevkifatOrani'] ??
          raw['tevkifat'] ??
          0;

      final name = (raw['name']?.toString().trim().isNotEmpty ?? false)
          ? raw['name'].toString()
          : (metaMap[code]?['name'] ?? code);
      final unit = (raw['unit']?.toString().trim().isNotEmpty ?? false)
          ? raw['unit'].toString()
          : (metaMap[code]?['unit'] ?? 'Adet');

      byWarehouse.putIfAbsent(warehouseId, () => []);
      byWarehouse[warehouseId]!.add({
        'code': code,
        'name': name,
        'unit': unit,
        'quantity': quantity,
        'unitCost': localUnitPrice,
        'total': localLineTotal,
        'discountRate': discountRate,
        'vatRate': vatRate,
        'otvRate': otvRate,
        'oivRate': oivRate,
        'kdvTevkifatOrani': kdvTevkifatOrani,
        'currency': currency,
        'exchangeRate': rate,
        'serialNumber': raw['serialNumber'],
      });
    }

    final String description = _alisShipmentAciklamaOlustur(
      belgeTuru: belgeTuru,
      belgeNo: belgeNo,
      cariAdi: cariAdi,
      cariKodu: cariKodu,
      aciklama: aciklama,
    );

    final Map<int, int> shipmentIds = {};
    final now = DateTime.now();

    for (final entry in byWarehouse.entries) {
      final wid = entry.key;
      final itemsJson = entry.value;

      final res = await session.execute(
        Sql.named('''
          INSERT INTO shipments (
            source_warehouse_id,
            dest_warehouse_id,
            date,
            description,
            items,
            integration_ref,
            created_by,
            created_at
          )
          VALUES (
            NULL,
            @destId,
            @date,
            @description,
            @items,
            @integration_ref,
            @created_by,
            @created_at
          )
          RETURNING id
        '''),
        parameters: {
          'destId': wid,
          'date': tarih,
          'description': description,
          'items': jsonEncode(itemsJson),
          'integration_ref': entegrasyonRef,
          'created_by': kullanici,
          'created_at': now,
        },
      );

      shipmentIds[wid] = res[0][0] as int;
    }

    return shipmentIds;
  }

  Future<void> _uretimStokGuncelle({
    required String kod,
    required double miktar,
    required bool isGiris,
    required int? depoId,
    required TxSession session,
  }) async {
    if (miktar == 0) return;

    // Üretim kaydı var mı?
    final prodRes = await session.execute(
      Sql.named('SELECT stok, ad FROM productions WHERE kod = @kod FOR UPDATE'),
      parameters: {'kod': kod},
    );
    if (prodRes.isEmpty) return;

    final double mevcutStok =
        double.tryParse(prodRes.first[0]?.toString() ?? '') ?? 0.0;
    final String ad = prodRes.first[1] as String? ?? kod;

    if (!isGiris) {
      try {
        final genelAyarlar = await AyarlarVeritabaniServisi()
            .genelAyarlariGetir();
        if (!genelAyarlar.eksiStokSatis && mevcutStok < miktar) {
          throw Exception(
            'Yetersiz stok! Mevcut stok: $mevcutStok, İstenen miktar: $miktar. '
            'Eksi stok satışı genel ayarlardan kapalı. ($ad)',
          );
        }
      } catch (e) {
        if (e.toString().contains('Yetersiz stok')) rethrow;
        debugPrint('Genel ayarlar okunamadı, eksi stok kontrolü atlanıyor: $e');
      }
    }

    final double delta = isGiris ? miktar : -miktar;
    await session.execute(
      Sql.named('UPDATE productions SET stok = stok + @delta WHERE kod = @kod'),
      parameters: {'delta': delta, 'kod': kod},
    );

    if (depoId != null) {
      await session.execute(
        Sql.named('''
          INSERT INTO warehouse_stocks (warehouse_id, product_code, quantity)
          VALUES (@depoId, @kod, @miktar)
          ON CONFLICT (warehouse_id, product_code)
          DO UPDATE SET quantity = warehouse_stocks.quantity + EXCLUDED.quantity, updated_at = CURRENT_TIMESTAMP
        '''),
        parameters: {'depoId': depoId, 'kod': kod, 'miktar': delta},
      );
    }
  }

  Future<bool> _odemeIsle({
    required double verilenTutar,
    required String odemeYeri,
    required String odemeHesapKodu,
    required String odemeAciklama,
    required DateTime tarih,
    required String cariKodu,
    required String cariAdi,
    required String kullanici,
    required String integrationRef,
    required Map<String, dynamic> alisBilgileri,
    required String faturaNo,
    required TxSession session,
  }) async {
    bool cariOdemeServisUzerindenIslendi = false;

    if (odemeYeri == 'Kasa') {
      int? kasaId;
      final cacheKey = 'KASA_$odemeHesapKodu';
      if (_accountCache.containsKey(cacheKey)) {
        kasaId = _accountCache[cacheKey];
      }

      if (kasaId == null) {
        final kasalar = await KasalarVeritabaniServisi().kasaAra(
          odemeHesapKodu,
          limit: 1,
          session: session,
        );
        if (kasalar.isNotEmpty) {
          kasaId = kasalar.first.id;
        } else {
          final kasalarList = await KasalarVeritabaniServisi().kasalariGetir(
            sayfaBasinaKayit: 1,
            session: session,
          );
          if (kasalarList.isNotEmpty) kasaId = kasalarList.first.id;
        }
        if (kasaId != null) {
          if (_accountCache.length > 500) _accountCache.clear();
          _accountCache[cacheKey] = kasaId;
        }
      }

      if (kasaId != null) {
        await KasalarVeritabaniServisi().kasaIslemEkle(
          kasaId: kasaId,
          tutar: verilenTutar,
          islemTuru: 'Ödeme',
          aciklama: odemeAciklama,
          tarih: tarih,
          cariTuru: 'Cari Hesap',
          cariKodu: cariKodu,
          cariAdi: cariAdi,
          kullanici: kullanici,
          entegrasyonRef: integrationRef,
          cariEntegrasyonYap: true,
          session: session,
        );
        cariOdemeServisUzerindenIslendi = true;
      } else {
        throw Exception(
          'Ödeme yapılacak Kasa bulunamadı! Lütfen Kasa tanımlayın veya seçin.',
        );
      }
    } else if (odemeYeri == 'Banka') {
      int? bankaId;
      final cacheKey = 'BANKA_$odemeHesapKodu';
      if (_accountCache.containsKey(cacheKey)) {
        bankaId = _accountCache[cacheKey];
      }

      final bankaServis = BankalarVeritabaniServisi();
      if (bankaId == null) {
        final bankalar = await bankaServis.bankaAra(
          odemeHesapKodu,
          limit: 1,
          session: session,
        );
        if (bankalar.isNotEmpty) {
          bankaId = bankalar.first.id;
        } else {
          final bankalarList = await bankaServis.bankalariGetir(
            sayfaBasinaKayit: 1,
            session: session,
          );
          if (bankalarList.isNotEmpty) bankaId = bankalarList.first.id;
        }
        if (bankaId != null) {
          if (_accountCache.length > 500) _accountCache.clear();
          _accountCache[cacheKey] = bankaId;
        }
      }

      if (bankaId != null) {
        await bankaServis.bankaIslemEkle(
          bankaId: bankaId,
          tutar: verilenTutar,
          islemTuru: 'Ödeme',
          aciklama: odemeAciklama,
          tarih: tarih,
          cariTuru: 'Cari Hesap',
          cariKodu: cariKodu,
          cariAdi: cariAdi,
          kullanici: kullanici,
          entegrasyonRef: integrationRef,
          cariEntegrasyonYap: true,
          session: session,
        );
        cariOdemeServisUzerindenIslendi = true;
      } else {
        throw Exception(
          'Ödeme yapılacak Banka bulunamadı! Lütfen Banka tanımlayın veya seçin.',
        );
      }
    } else if (odemeYeri == 'Kredi Kartı') {
      int? krediKartiId;
      final cacheKey = 'POS_$odemeHesapKodu';
      if (_accountCache.containsKey(cacheKey)) {
        krediKartiId = _accountCache[cacheKey];
      }

      final krediKartiServis = KrediKartlariVeritabaniServisi();
      if (krediKartiId == null) {
        final kartlar = await krediKartiServis.krediKartiAra(
          odemeHesapKodu,
          limit: 1,
          session: session,
        );
        if (kartlar.isNotEmpty) {
          krediKartiId = kartlar.first.id;
        } else {
          final kartlarList = await krediKartiServis.krediKartlariniGetir(
            sayfaBasinaKayit: 1,
            session: session,
          );
          if (kartlarList.isNotEmpty) krediKartiId = kartlarList.first.id;
        }
        if (krediKartiId != null) {
          if (_accountCache.length > 500) _accountCache.clear();
          _accountCache[cacheKey] = krediKartiId;
        }
      }

      if (krediKartiId != null) {
        await krediKartiServis.krediKartiIslemEkle(
          krediKartiId: krediKartiId,
          tutar: verilenTutar,
          islemTuru: 'Çıkış',
          aciklama: odemeAciklama,
          tarih: tarih,
          cariTuru: 'Cari Hesap',
          cariKodu: cariKodu,
          cariAdi: cariAdi,
          kullanici: kullanici,
          entegrasyonRef: integrationRef,
          cariEntegrasyonYap: true,
          session: session,
        );
        cariOdemeServisUzerindenIslendi = true;
      } else {
        throw Exception(
          'Ödeme yapılacak POS/Kredi Kartı Hesabı bulunamadı! Lütfen tanımlayın.',
        );
      }
    } else if (odemeYeri == 'Çek') {
      final cekServis = CeklerVeritabaniServisi();
      await cekServis.cekEkle(
        CekModel(
          id: 0,
          tur: 'Verilen Çek',
          tahsilat: 'Ödenmedi',
          cariKod: cariKodu,
          cariAdi: cariAdi,
          duzenlenmeTarihi: DateFormat('dd.MM.yyyy').format(tarih),
          kesideTarihi: DateFormat(
            'dd.MM.yyyy',
          ).format(alisBilgileri['vadeTarihi'] ?? tarih),
          tutar: verilenTutar,
          paraBirimi: 'TRY',
          cekNo: 'VERILEN-${DateTime.now().millisecondsSinceEpoch}',
          banka: 'Kendi Bankamız',
          aciklama: odemeAciklama,
          kullanici: kullanici,
          aktifMi: true,
          integrationRef: integrationRef,
        ),
        session: session,
        cariEntegrasyonYap: true,
      );
      cariOdemeServisUzerindenIslendi = true;
    } else if (odemeYeri == 'Senet') {
      final senetServis = SenetlerVeritabaniServisi();
      await senetServis.senetEkle(
        SenetModel(
          id: 0,
          tur: 'Verilen Senet',
          tahsilat: 'Ödenmedi',
          cariKod: cariKodu,
          cariAdi: cariAdi,
          duzenlenmeTarihi: DateFormat('dd.MM.yyyy').format(tarih),
          kesideTarihi: DateFormat(
            'dd.MM.yyyy',
          ).format(alisBilgileri['vadeTarihi'] ?? tarih),
          tutar: verilenTutar,
          paraBirimi: 'TRY',
          senetNo: 'SENET-${DateTime.now().millisecondsSinceEpoch}',
          banka: '-',
          aciklama: odemeAciklama,
          kullanici: kullanici,
          aktifMi: true,
          integrationRef: integrationRef,
        ),
        session: session,
        cariEntegrasyonYap: true,
      );
      cariOdemeServisUzerindenIslendi = true;
    } else if (odemeYeri == 'Diğer') {
      try {
        final int sanalKasaId = await KasalarVeritabaniServisi().getSanalKasaId(
          userName: kullanici,
          session: session,
        );
        await KasalarVeritabaniServisi().kasaIslemEkle(
          kasaId: sanalKasaId,
          tutar: verilenTutar,
          islemTuru: 'Ödeme',
          aciklama: odemeAciklama,
          tarih: tarih,
          cariTuru: 'Cari Hesap',
          cariKodu: cariKodu,
          cariAdi: cariAdi,
          kullanici: kullanici,
          entegrasyonRef: integrationRef,
          cariEntegrasyonYap: true,
          session: session,
        );
        cariOdemeServisUzerindenIslendi = true;
      } catch (e) {
        debugPrint('Sanal Kasa Hatası: $e');
        cariOdemeServisUzerindenIslendi = false;
      }
    }

    return cariOdemeServisUzerindenIslendi;
  }

  /// Alış İşlemini Geri Alır (İptal)
  /// [ACID] Atomik işlem.
  Future<void> alisIsleminiSil(
    String entegrasyonRef, {
    TxSession? session,
  }) async {
    Future<void> operation(TxSession s) async {
      debugPrint('Alış İptali Başlatılıyor. Ref: $entegrasyonRef');

      // 0. [CRITICAL] Silinmeden Önce Etkilenen Ürünleri ve Tarihi Bul
      // Maliyet tekrar hesaplaması için silinecek hareketlerin ürün ID'lerini ve en eski tarihini sakla.
      List<Map<String, dynamic>> affectedProducts = [];
      try {
        final result = await s.execute(
          Sql.named(
            "SELECT product_id, MIN(movement_date) as min_date FROM stock_movements WHERE integration_ref = @ref GROUP BY product_id",
          ),
          parameters: {'ref': entegrasyonRef},
        );
        for (final row in result) {
          affectedProducts.add({
            'id': row[0] as int,
            'date': row[1] as DateTime,
          });
        }
      } catch (e) {
        debugPrint('Etkilenen ürünleri bulma hatası silme öncesi: $e');
      }

      // 1. [ÖNCELİKLİ] Çek ve Senet Silme
      await CeklerVeritabaniServisi().cekSilByRef(entegrasyonRef, session: s);
      await SenetlerVeritabaniServisi().senetSilByRef(
        entegrasyonRef,
        session: s,
      );

      // 2. Kasa/Banka/Kredi Kartı Mali Entegrasyonlarını Sil
      await KasalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
        entegrasyonRef,
        haricKasaIslemId: -1,
        session: s,
      );
      await BankalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
        entegrasyonRef,
        haricBankaIslemId: -1,
        session: s,
      );
      await KrediKartlariVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
        entegrasyonRef,
        haricKrediKartiIslemId: -1,
        session: s,
      );

      // 3. Stok Hareketlerini Sil
      await UrunlerVeritabaniServisi().stokIslemiSilByRef(
        entegrasyonRef,
        session: s,
      );

      // 4. Cari Hareketlerini Sil
      await CariHesaplarVeritabaniServisi().cariIslemSilByRef(
        entegrasyonRef,
        session: s,
      );

      debugPrint('Alış İptali Tamamlandı.');

      // 5. [SMART SYNC] Sipariş Bağlantısını Kopar (Varsa Beklemede yap)
      // Eğer bu alış bir siparişten geldiyse, siparişi tekrar 'Beklemede' durumuna çeker.
      await SiparislerVeritabaniServisi().siparisDurumGuncelleBySalesRef(
        entegrasyonRef,
        'Beklemede',
        session: s,
      );

      // 6. [NEW] Maliyetleri Yeniden Hesapla
      // Silinen hareketlerden sonraki zinciri düzelt.
      if (affectedProducts.isNotEmpty) {
        debugPrint(
          'Maliyetler yeniden hesaplanıyor (${affectedProducts.length} Ürün)...',
        );
        for (final item in affectedProducts) {
          await MaliyetHesaplamaServisi().maliyetleriYenidenHesapla(
            item['id'],
            item['date'],
            session: s,
          );
        }
      }
    }

    if (session != null) {
      await operation(session);
    } else {
      await UrunlerVeritabaniServisi().transactionBaslat((s) async {
        await operation(s);
      }, isolationLevel: IsolationLevel.serializable);
    }
  }

  /// Alış İşlemini Günceller
  /// [ACID] Atomik işlem: Full reset (sil + aynı ref ile yeniden yaz)
  Future<void> alisIsleminiGuncelle({
    required String oldIntegrationRef,
    required Map<String, dynamic> newAlisBilgileri,
  }) async {
    final ref = oldIntegrationRef.trim();
    if (ref.isEmpty) return;

    debugPrint('Alış Güncelleme (Full Reset) Başlatıldı. Ref: $ref');
    await UrunlerVeritabaniServisi().transactionBaslat((s) async {
      await alisIsleminiSil(ref, session: s);
      await _alisIsleminiKaydetInternal(newAlisBilgileri, s, existingRef: ref);
    }, isolationLevel: IsolationLevel.serializable);
    debugPrint('Alış Güncelleme (Full Reset) Tamamlandı. Ref: $ref');
  }
}
