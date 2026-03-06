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
import 'package:patisyov10/servisler/teklifler_veritabani_servisi.dart';
import 'package:patisyov10/servisler/siparisler_veritabani_servisi.dart';
import 'package:patisyov10/servisler/maliyet_hesaplama_servisi.dart';
import 'package:patisyov10/servisler/taksit_veritabani_servisi.dart';
import 'package:patisyov10/servisler/lite_kisitlari.dart';
import 'package:intl/intl.dart';

/// Satış yap işlemleriyle ilgili Entegre Veritabanı Servisi
class SatisYapVeritabaniServisi {
  static final SatisYapVeritabaniServisi _instance =
      SatisYapVeritabaniServisi._internal();
  factory SatisYapVeritabaniServisi() => _instance;
  SatisYapVeritabaniServisi._internal();

  /// Satış işlemini Tam Entegre şekilde kaydeder.

  Future<void> satisIsleminiKaydet(
    Map<String, dynamic> satisBilgileri, {
    TxSession? session,
  }) async {
    final urunServisi = UrunlerVeritabaniServisi();

    if (session != null) {
      if (LiteKisitlari.isLiteMode) {
        await _ensureGunlukSatisLimiti(
          satisBilgileri: satisBilgileri,
          session: session,
        );
      }
      await _satisIsleminiKaydetInternal(satisBilgileri, session);
    } else {
      await urunServisi.transactionBaslat((s) async {
        if (LiteKisitlari.isLiteMode) {
          await _ensureGunlukSatisLimiti(
            satisBilgileri: satisBilgileri,
            session: s,
          );
        }
        await _satisIsleminiKaydetInternal(satisBilgileri, s);
      }, isolationLevel: IsolationLevel.serializable);
    }
  }

  Future<void> _ensureGunlukSatisLimiti({
    required Map<String, dynamic> satisBilgileri,
    required TxSession session,
  }) async {
    if (!LiteKisitlari.isLiteMode) return;

    final DateTime tarih =
        satisBilgileri['tarih'] as DateTime? ?? DateTime.now();
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

  Future<void> _satisIsleminiKaydetInternal(
    Map<String, dynamic> satisBilgileri,
    TxSession s, {
    String? existingRef,
  }) async {
    final urunServisi = UrunlerVeritabaniServisi();

    double toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
    }

    final int cariId = int.tryParse(satisBilgileri['cariId'].toString()) ?? 0;
    final DateTime tarih = satisBilgileri['tarih'] as DateTime;
    final String belgeTuru = satisBilgileri['belgeTuru'] ?? 'Fatura';
    final String faturaNo = satisBilgileri['faturaNo'] ?? '';
    String aciklama = satisBilgileri['aciklama'] ?? '';
    final double genelToplam = toDouble(satisBilgileri['genelToplam']);
    final double alinanTutar = toDouble(
      satisBilgileri['alinanTutar'] ?? satisBilgileri['verilenTutar'],
    );
    final String odemeYeri = satisBilgileri['odemeYeri'] ?? 'Kasa';
    final String odemeHesapKodu = satisBilgileri['odemeHesapKodu'] ?? '';
    final String odemeAciklamaSecimi =
        (satisBilgileri['odemeAciklama'] as String?)?.trim() ?? '';
    final List<dynamic> items = satisBilgileri['items'] ?? [];
    final String kullanici = satisBilgileri['kullanici'] ?? 'Sistem';

    final String cariKodu = satisBilgileri['selectedCariCode'] ?? '';
    final String cariAdi = satisBilgileri['selectedCariName'] ?? '';
    final String paraBirimi = satisBilgileri['paraBirimi'] ?? 'TRY';
    final double kur = toDouble(satisBilgileri['kur'] ?? 1.0);

    // TAKSİTLERİ ÖNCEDEN HAZIRLA (Açıklama ve Kayıt için)
    final List<Map<String, dynamic>>? taksitlerList =
        (satisBilgileri['taksitler'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList();

    // TAKSİT BİLGİSİNİ AÇIKLAMAYA EKLE (Kullanıcı Talebi)
    if (taksitlerList != null && taksitlerList.isNotEmpty) {
      final taksitSayisi = taksitlerList.length;
      final taksitEki = 'Taksitli Satış ($taksitSayisi)';
      if (aciklama.isEmpty) {
        aciklama = taksitEki;
      } else if (!aciklama.contains(taksitEki)) {
        aciklama = '$aciklama - $taksitEki';
      }
    }

    // ENTEGRASYON REF (SAĞLAM SİLME VE GÜNCELLEME İÇİN)
    // Güncelleme işleminde eski referansı koruyarak zinciri sürdürüyoruz.
    final String integrationRef =
        existingRef ??
        'SALE-${DateTime.now().millisecondsSinceEpoch}-${(1000 + (DateTime.now().microsecond % 9000))}';

    // [PERFORMANCE FIX] Batch Fetch IDs (N+1 Optimization)
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

    // 2. ADIM: CARİ HESAP HAREKETİ (BORÇLANDIRMA)
    // İrsaliye ise cari borçlandırma yapılmaz, sadece stok düşer.
    if (belgeTuru != 'İrsaliye') {
      final cariServis = CariHesaplarVeritabaniServisi();
      await cariServis.cariIslemEkle(
        cariId: cariId,
        tutar: genelToplam,
        isBorc: true, // Satış -> Cari Borç (Debit)
        islemTuru: 'Satış Yapıldı',
        aciklama: aciklama,
        tarih: tarih,
        kullanici: kullanici,
        entegrasyonRef: integrationRef,
        paraBirimi: paraBirimi,
        kur: kur,
        belgeNo: faturaNo,
        vadeTarihi: satisBilgileri['vadeTarihi'] is DateTime
            ? satisBilgileri['vadeTarihi'] as DateTime
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

      // 3. ADIM: TAHSİLAT KONTROLÜ
      if (alinanTutar > 0) {
        // Taksitli satışta, girilen tutar peşinat kabul edilir ve açıklama buna göre zenginleştirilir.
        String odemeAciklama =
            odemeAciklamaSecimi.isNotEmpty ? odemeAciklamaSecimi : '';
        if (taksitlerList != null && taksitlerList.isNotEmpty) {
          final String purpose = faturaNo.trim().isNotEmpty
              ? 'Taksitli Satış Peşinatı (Fatura: $faturaNo)'
              : 'Taksitli Satış Peşinatı';
          odemeAciklama =
              odemeAciklama.isNotEmpty ? '$odemeAciklama - $purpose' : purpose;
        }

        await _tahsilatIsle(
          alinanTutar: alinanTutar,
          odemeYeri: odemeYeri,
          odemeHesapKodu: odemeHesapKodu,
          odemeAciklama: odemeAciklama,
          tarih: tarih,
          cariKodu: cariKodu,
          cariAdi: cariAdi,
          kullanici: kullanici,
          integrationRef: integrationRef,
          satisBilgileri: satisBilgileri,
          faturaNo: faturaNo,
          session: s,
        );
      }
    }

    // 4. ADIM: TEKLİF/SİPARİŞ DURUM GÜNCELLEME (VARSA)
    final int? quoteId = int.tryParse(
      satisBilgileri['quoteRef']?.toString() ?? '',
    );
    if (quoteId != null) {
      final String status = satisBilgileri['quoteStatus'] ?? 'Satış Yapıldı';
      await TekliflerVeritabaniServisi().teklifDurumGuncelle(
        quoteId,
        status,
        session: s,
      );
    }

    final int? orderId = int.tryParse(
      satisBilgileri['orderRef']?.toString() ?? '',
    );
    if (orderId != null) {
      final String status = satisBilgileri['orderStatus'] ?? 'Satış Yapıldı';
      await SiparislerVeritabaniServisi().siparisDurumGuncelle(
        orderId,
        status,
        session: s,
      );
      // [SMART SYNC] Siparişe Satış Referansını Yaz (Geri İzlenebilirlik)
      await SiparislerVeritabaniServisi().siparisSatisReferansGuncelle(
        orderId,
        integrationRef,
        session: s,
      );
    }

    // 5. ADIM: TAKSİT BİLGİLERİNİ KAYDET (VARSA)
    if (taksitlerList != null && taksitlerList.isNotEmpty) {
      await TaksitVeritabaniServisi().tablolariOlustur(session: s);
      await TaksitVeritabaniServisi().taksitleriKaydet(
        integrationRef: integrationRef,
        cariId: cariId,
        taksitler: taksitlerList,
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
          isGiris: false,
          islemTuru: 'Satış Faturası',
          tarih: tarih,
          aciklama: aciklama,
          kullanici: kullanici,
          birimFiyat: fiyat,
          paraBirimi: itemCurrency,
          kur: itemRate,
          depoId: depoId,
          shipmentId: depoId != null ? shipmentIdByWarehouse[depoId] : null,
          entegrasyonRef: integrationRef,
          serialNumber: item['serialNumber'], // IMEI bilgisini ilet
          session: session,
        );
      } else {
        await _uretimStokGuncelle(
          kod: kod,
          miktar: miktar,
          isGiris: false,
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

  String _satisShipmentAciklamaOlustur({
    required String belgeTuru,
    required String belgeNo,
    required String cariAdi,
    required String cariKodu,
    required String aciklama,
  }) {
    // Patisyo V10 Update:
    // Otomatik açıklama (prefix) oluşturma kapatıldı.
    // Sadece kullanıcının girdiği açıklama kaydedilecek.

    // [FIX] Kullanıcı "Satış Yapıldı" gibi otomatik metinlerin description'a yazılmasını istemiyor.
    if (aciklama == 'Satış Yapıldı') return '';

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
        'serialNumber': raw['serialNumber'], // Sevkiyat detayına IMEI ekle
      });
    }

    final String description = _satisShipmentAciklamaOlustur(
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
            @sourceId,
            NULL,
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
          'sourceId': wid,
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

  Future<bool> _tahsilatIsle({
    required double alinanTutar,
    required String odemeYeri,
    required String odemeHesapKodu,
    required String odemeAciklama,
    required DateTime tarih,
    required String cariKodu,
    required String cariAdi,
    required String kullanici,
    required String integrationRef,
    required Map<String, dynamic> satisBilgileri,
    required String faturaNo,
    required TxSession session,
  }) async {
    bool cariTahsilatServisUzerindenIslendi = false;

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
          tutar: alinanTutar,
          islemTuru: 'Tahsilat',
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
        cariTahsilatServisUzerindenIslendi = true;
      } else {
        throw Exception(
          'Ödeme alınacak Kasa bulunamadı! Lütfen Kasa tanımlayın veya seçin.',
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
          tutar: alinanTutar,
          islemTuru: 'Tahsilat',
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
        cariTahsilatServisUzerindenIslendi = true;
      } else {
        throw Exception(
          'Ödeme alınacak Banka bulunamadı! Lütfen Banka tanımlayın veya seçin.',
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
          tutar: alinanTutar,
          islemTuru: 'Giriş',
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
        cariTahsilatServisUzerindenIslendi = true;
      } else {
        throw Exception(
          'Ödeme alınacak POS/Kredi Kartı Hesabı bulunamadı! Lütfen tanımlayın.',
        );
      }
    } else if (odemeYeri == 'Çek') {
      final cekServis = CeklerVeritabaniServisi();
      await cekServis.cekEkle(
        CekModel(
          id: 0,
          tur: 'Alınan Çek',
          tahsilat: 'Portföyde',
          cariKod: cariKodu,
          cariAdi: cariAdi,
          duzenlenmeTarihi: DateFormat('dd.MM.yyyy').format(tarih),
          kesideTarihi: DateFormat(
            'dd.MM.yyyy',
          ).format(satisBilgileri['vadeTarihi'] ?? tarih),
          tutar: alinanTutar,
          paraBirimi: 'TRY',
          cekNo: 'OTOMATIK-${DateTime.now().millisecondsSinceEpoch}',
          banka: '-',
          aciklama: odemeAciklama,
          integrationRef: integrationRef,
          kullanici: kullanici,
          aktifMi: true,
        ),
        session: session,
        cariEntegrasyonYap: true,
      );
      cariTahsilatServisUzerindenIslendi = true;
    } else if (odemeYeri == 'Senet') {
      final senetServis = SenetlerVeritabaniServisi();
      await senetServis.senetEkle(
        SenetModel(
          id: 0,
          tur: 'Alınan Senet',
          tahsilat: 'Portföyde',
          cariKod: cariKodu,
          cariAdi: cariAdi,
          duzenlenmeTarihi: DateFormat('dd.MM.yyyy').format(tarih),
          kesideTarihi: DateFormat(
            'dd.MM.yyyy',
          ).format(satisBilgileri['vadeTarihi'] ?? tarih),
          tutar: alinanTutar,
          paraBirimi: 'TRY',
          senetNo: 'OTOMATIK-${DateTime.now().millisecondsSinceEpoch}',
          banka: '-',
          aciklama: odemeAciklama,
          integrationRef: integrationRef,
          kullanici: kullanici,
          aktifMi: true,
        ),
        session: session,
        cariEntegrasyonYap: true,
      );
      cariTahsilatServisUzerindenIslendi = true;
    } else if (odemeYeri == 'Diğer') {
      try {
        final int sanalKasaId = await KasalarVeritabaniServisi().getSanalKasaId(
          userName: kullanici,
          session: session,
        );
        await KasalarVeritabaniServisi().kasaIslemEkle(
          kasaId: sanalKasaId,
          tutar: alinanTutar,
          islemTuru: 'Tahsilat',
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
        cariTahsilatServisUzerindenIslendi = true;
      } catch (e) {
        debugPrint('Sanal Kasa Hatası: $e');
        cariTahsilatServisUzerindenIslendi = false;
      }
    }

    return cariTahsilatServisUzerindenIslendi;
  }

  /// Satış işlemini yazdırma sonrası girilen bilgilerle günceller.
  Future<void> satisIsleminiYazdirmaBilgileriyleGuncelle({
    required String entegrasyonRef,
    required Map<String, dynamic> yazdirmaBilgileri,
  }) async {
    final urunServisi = UrunlerVeritabaniServisi();

    await urunServisi.transactionBaslat((s) async {
      final DateTime? irsaliyeTarihi = yazdirmaBilgileri['irsaliyeTarihi'];
      final DateTime? faturaTarihi = yazdirmaBilgileri['faturaTarihi'];
      final DateTime? sonOdemeTarihi = yazdirmaBilgileri['sonOdemeTarihi'];
      final String irsaliyeNo = yazdirmaBilgileri['irsaliyeNo'] ?? '';
      final String faturaNo = yazdirmaBilgileri['faturaNo'] ?? '';
      final List<String> aciklamalar = List<String>.from(
        yazdirmaBilgileri['aciklamalar'] ?? [],
      );

      // 1. Shipments tablosunu güncelle
      String shipmentDescription = aciklamalar
          .where((a) => a.trim().isNotEmpty)
          .join(' | ');

      await s.execute(
        Sql.named('''
          UPDATE shipments 
          SET description = @desc, 
              date = COALESCE(@irsaliyeDate, date)
          WHERE integration_ref = @ref
        '''),
        parameters: {
          'desc': shipmentDescription,
          'irsaliyeDate': irsaliyeTarihi,
          'ref': entegrasyonRef,
        },
      );

      // 2. Cari Hesap Hareketlerini güncelle
      await s.execute(
        Sql.named('''
          UPDATE current_account_transactions 
          SET fatura_no = CASE WHEN @faturaNo <> '' THEN @faturaNo ELSE fatura_no END,
              irsaliye_no = CASE WHEN @irsaliyeNo <> '' THEN @irsaliyeNo ELSE irsaliye_no END,
              description = @desc,
              vade_tarihi = COALESCE(@vadeDate, vade_tarihi),
              date = COALESCE(@faturaDate, date)
          WHERE integration_ref = @ref
        '''),
        parameters: {
          'faturaNo': faturaNo,
          'irsaliyeNo': irsaliyeNo,
          'desc': shipmentDescription,
          'vadeDate': sonOdemeTarihi,
          'faturaDate': faturaTarihi,
          'ref': entegrasyonRef,
        },
      );

      // 3. Stok hareketlerini güncelle
      await s.execute(
        Sql.named('''
          UPDATE stock_movements 
          SET description = @desc,
              movement_date = COALESCE(@irsaliyeDate, movement_date)
          WHERE integration_ref = @ref
        '''),
        parameters: {
          'desc': shipmentDescription,
          'irsaliyeDate': irsaliyeTarihi,
          'ref': entegrasyonRef,
        },
      );
    });
  }

  /// Satış İşlemini Geri Alır (İptal)
  /// [ACID] Atomik işlem: Tek bir transaction içinde tüm bağlı kayıtları siler.
  Future<void> satisIsleminiSil(
    String entegrasyonRef, {
    TxSession? session,
  }) async {
    // Transaction wrapper logic
    Future<void> operation(TxSession s) async {
      debugPrint('Satış İptali Başlatılıyor. Ref: $entegrasyonRef');

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

      // 1. [ÖNCELİKLİ] Çek ve Senet Silme - Tahsil edilmişlerse mali entegrasyonları geri alır
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

      // 3. Stok Hareketlerini Sil (Stokları geri yükle)
      await UrunlerVeritabaniServisi().stokIslemiSilByRef(
        entegrasyonRef,
        session: s,
      );

      await CariHesaplarVeritabaniServisi().cariIslemSilByRef(
        entegrasyonRef,
        session: s,
      );

      // 4.1. Taksitleri Sil
      await TaksitVeritabaniServisi().taksitleriSil(entegrasyonRef, session: s);

      // 5. [SMART SYNC] Sipariş Bağlantısını Kopar (Varsa Beklemede yap)
      // Eğer bu satış bir siparişten geldiyse, siparişi tekrar 'Beklemede' durumuna çeker.
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

      debugPrint('Satış İptali Tamamlandı.');
    }

    if (session != null) {
      await operation(session);
    } else {
      await UrunlerVeritabaniServisi().transactionBaslat((s) async {
        await operation(s);
      }, isolationLevel: IsolationLevel.serializable);
    }
  }

  /// Satış İşlemini Günceller
  /// [ACID] Atomik işlem: Full reset (sil + aynı ref ile yeniden yaz)
  Future<void> satisIsleminiGuncelle({
    required String oldIntegrationRef,
    required Map<String, dynamic> newSatisBilgileri,
  }) async {
    final ref = oldIntegrationRef.trim();
    if (ref.isEmpty) return;

    debugPrint('Satış Güncelleme (Full Reset) Başlatıldı. Ref: $ref');
    await UrunlerVeritabaniServisi().transactionBaslat((s) async {
      await satisIsleminiSil(ref, session: s);
      await _satisIsleminiKaydetInternal(
        newSatisBilgileri,
        s,
        existingRef: ref,
      );
    }, isolationLevel: IsolationLevel.serializable);
    debugPrint('Satış Güncelleme (Full Reset) Tamamlandı. Ref: $ref');
  }
}
