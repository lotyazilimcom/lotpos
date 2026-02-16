import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:patisyov10/servisler/bankalar_veritabani_servisi.dart';
import 'package:patisyov10/servisler/cari_hesaplar_veritabani_servisi.dart';
import 'package:patisyov10/servisler/kasalar_veritabani_servisi.dart';
import 'package:patisyov10/servisler/kredi_kartlari_veritabani_servisi.dart';
import 'package:patisyov10/servisler/lite_kisitlari.dart';
import 'package:patisyov10/servisler/urunler_veritabani_servisi.dart';

/// Perakende Satış işlemleriyle ilgili Entegre Veritabanı Servisi
class PerakendeSatisVeritabaniServisi {
  static final PerakendeSatisVeritabaniServisi _instance =
      PerakendeSatisVeritabaniServisi._internal();
  factory PerakendeSatisVeritabaniServisi() => _instance;
  PerakendeSatisVeritabaniServisi._internal();

  Future<void> satisIsleminiKaydet({
    required Map<String, dynamic> satisBilgileri,
  }) async {
    final urunServisi = UrunlerVeritabaniServisi();
    await urunServisi.transactionBaslat((s) async {
      if (LiteKisitlari.isLiteMode) {
        await _ensureGunlukPerakendeSatisLimiti(
          satisBilgileri: satisBilgileri,
          session: s,
        );
      }
      await _satisKaydetInternal(satisBilgileri, s);
    }, isolationLevel: IsolationLevel.serializable);
  }

  Future<void> _ensureGunlukPerakendeSatisLimiti({
    required Map<String, dynamic> satisBilgileri,
    required TxSession session,
  }) async {
    if (!LiteKisitlari.isLiteMode) return;

    final DateTime tarih =
        satisBilgileri['tarih'] as DateTime? ?? DateTime.now();
    final gunBas = DateTime(tarih.year, tarih.month, tarih.day);
    final gunSon = gunBas.add(const Duration(days: 1));

    final cap = LiteKisitlari.maxGunlukPerakendeSatis;
    final res = await session.execute(
      Sql.named('''
        SELECT COUNT(*) FROM (
          SELECT DISTINCT integration_ref
          FROM stock_movements
          WHERE integration_ref IS NOT NULL
            AND integration_ref LIKE 'RETAIL-%'
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
        'LITE sürümde günlük en fazla $cap perakende satış işlemi yapılabilir. Pro sürüme geçin.',
      );
    }
  }

  /// Perakende satış işlemini (RETAIL-*) tüm bağlı kayıtlarıyla geri alır.
  ///
  /// - Kasa/Banka/Kredi Kartı entegrasyon hareketleri
  /// - Stok hareketleri + shipments
  /// - (Varsa) Cari hareketi (eski kayıtlar için)
  Future<void> satisIsleminiSil(
    String entegrasyonRef, {
    TxSession? session,
  }) async {
    final ref = entegrasyonRef.trim();
    if (ref.isEmpty) return;

    Future<void> operation(TxSession s) async {
      await KasalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
        ref,
        haricKasaIslemId: -1,
        session: s,
      );
      await BankalarVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
        ref,
        haricBankaIslemId: -1,
        session: s,
      );
      await KrediKartlariVeritabaniServisi().entegrasyonBaglantiliIslemleriSil(
        ref,
        haricKrediKartiIslemId: -1,
        session: s,
      );

      await UrunlerVeritabaniServisi().stokIslemiSilByRef(ref, session: s);

      await CariHesaplarVeritabaniServisi().cariIslemSilByRef(
        ref,
        session: s,
      );
    }

    if (session != null) {
      await operation(session);
      return;
    }

    await UrunlerVeritabaniServisi().transactionBaslat((s) async {
      await operation(s);
    }, isolationLevel: IsolationLevel.serializable);
  }

  Future<void> _satisKaydetInternal(
    Map<String, dynamic> satisBilgileri,
    TxSession s,
  ) async {
    final urunServisi = UrunlerVeritabaniServisi();

    double toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
    }

    final DateTime tarih =
        satisBilgileri['tarih'] as DateTime? ?? DateTime.now();
    final String aciklama = satisBilgileri['aciklama'] ?? 'Perakende Satış';
    final double genelToplam = toDouble(satisBilgileri['genelToplam']);
    final List<dynamic> items = satisBilgileri['items'] ?? [];
    final List<dynamic> payments = satisBilgileri['payments'] ?? [];
    final String kullanici = satisBilgileri['kullanici'] ?? 'Sistem';

    final int? cariId = int.tryParse(
      satisBilgileri['cariId']?.toString() ?? '',
    );
    final String cariKodu = satisBilgileri['selectedCariCode'] ?? 'PERAKENDE';
    final String cariAdi =
        satisBilgileri['selectedCariName'] ?? 'Perakende Müşteri';
    final String paraBirimi = satisBilgileri['paraBirimi'] ?? 'TRY';

    final String integrationRef =
        satisBilgileri['integrationRef'] ??
        'RETAIL-${DateTime.now().millisecondsSinceEpoch}';

    // 1. Batch Fetch Product IDs
    final List<String> urunKodlari = items
        .map<String>((e) => e['code'].toString())
        .toList();
    final Map<String, int> urunIdMap = await urunServisi.urunIdleriniGetir(
      urunKodlari,
    );

    // 2. Shipments
    final shipmentIdByWarehouse = await _stokHareketiShipmentleriOlustur(
      items: items,
      tarih: tarih,
      aciklama: aciklama,
      cariAdi: cariAdi,
      cariKodu: cariKodu,
      kullanici: kullanici,
      entegrasyonRef: integrationRef,
      session: s,
    );

    // 3. Stock Movements
    for (var item in items) {
      final String kod = item['code'];
      final double miktar = toDouble(item['quantity']);
      final double fiyat = toDouble(item['price']);
      final int? depoId = int.tryParse(item['warehouseId']?.toString() ?? '');
      final int? urunId = urunIdMap[kod];

      if (urunId != null) {
        await urunServisi.stokIslemiYap(
          urunId: urunId,
          urunKodu: kod,
          miktar: miktar,
          isGiris: false,
          islemTuru: 'Perakende Satış',
          tarih: tarih,
          aciklama: aciklama,
          kullanici: kullanici,
          birimFiyat: fiyat,
          paraBirimi: paraBirimi,
          kur: 1.0,
          depoId: depoId,
          shipmentId: depoId != null ? shipmentIdByWarehouse[depoId] : null,
          entegrasyonRef: integrationRef,
          session: s,
        );
      }
    }

    // 4. Cari Hesap Hareketi
    if (cariId != null && cariId > 0) {
      await CariHesaplarVeritabaniServisi().cariIslemEkle(
        cariId: cariId,
        tutar: genelToplam,
        isBorc: true,
        islemTuru: 'Perakende Satış',
        aciklama: aciklama,
        tarih: tarih,
        kullanici: kullanici,
        entegrasyonRef: integrationRef,
        paraBirimi: paraBirimi,
        session: s,
      );
    }

    // 5. Tahsilat İşlemleri
    for (var p in payments) {
      final double tutar = toDouble(p['amount']);
      final String pYeri = p['type'] ?? 'Kasa';
      final String pHesap = p['accountCode'] ?? '';

      if (tutar <= 0) continue;

      if (pYeri == 'Kasa') {
        int? kasaId;
        if (pHesap.trim().isNotEmpty) {
          final kasalar = await KasalarVeritabaniServisi().kasaAra(
            pHesap,
            limit: 1,
            session: s,
          );
          if (kasalar.isNotEmpty) {
            kasaId = kasalar.first.id;
          }
        }

        if (kasaId == null) {
          final defaults = await KasalarVeritabaniServisi().kasalariGetir(
            sayfaBasinaKayit: 1,
            varsayilan: true,
            session: s,
          );
          if (defaults.isNotEmpty) {
            kasaId = defaults.first.id;
          } else {
            final first = await KasalarVeritabaniServisi().kasalariGetir(
              sayfaBasinaKayit: 1,
              session: s,
            );
            if (first.isNotEmpty) kasaId = first.first.id;
          }
        }

        if (kasaId != null) {
          await KasalarVeritabaniServisi().kasaIslemEkle(
            kasaId: kasaId,
            tutar: tutar,
            islemTuru: 'Tahsilat',
            aciklama: aciklama,
            tarih: tarih,
            cariTuru: 'Cari Hesap',
            cariKodu: cariKodu,
            cariAdi: cariAdi,
            kullanici: kullanici,
            entegrasyonRef: integrationRef,
            cariEntegrasyonYap: cariId != null && cariId > 0,
            session: s,
          );
        }
      } else if (pYeri == 'Banka') {
        final bankalar = await BankalarVeritabaniServisi().bankaAra(
          pHesap,
          limit: 1,
          session: s,
        );
        if (bankalar.isNotEmpty) {
          await BankalarVeritabaniServisi().bankaIslemEkle(
            bankaId: bankalar.first.id,
            tutar: tutar,
            islemTuru: 'Tahsilat',
            aciklama: aciklama,
            tarih: tarih,
            cariTuru: 'Cari Hesap',
            cariKodu: cariKodu,
            cariAdi: cariAdi,
            kullanici: kullanici,
            entegrasyonRef: integrationRef,
            cariEntegrasyonYap: cariId != null && cariId > 0,
            session: s,
          );
        }
      } else if (pYeri == 'Kredi Kartı') {
        int? kartId;
        if (pHesap.trim().isNotEmpty) {
          final kartlar = await KrediKartlariVeritabaniServisi().krediKartiAra(
            pHesap,
            limit: 1,
            session: s,
          );
          if (kartlar.isNotEmpty) {
            kartId = kartlar.first.id;
          }
        }

        if (kartId == null) {
          final defaults = await KrediKartlariVeritabaniServisi()
              .krediKartlariniGetir(
                sayfaBasinaKayit: 1,
                varsayilan: true,
                session: s,
              );
          if (defaults.isNotEmpty) {
            kartId = defaults.first.id;
          } else {
            final first = await KrediKartlariVeritabaniServisi()
                .krediKartlariniGetir(
                  sayfaBasinaKayit: 1,
                  session: s,
                );
            if (first.isNotEmpty) kartId = first.first.id;
          }
        }

        if (kartId != null) {
          await KrediKartlariVeritabaniServisi().krediKartiIslemEkle(
            krediKartiId: kartId,
            tutar: tutar,
            islemTuru: 'Giriş',
            aciklama: aciklama,
            tarih: tarih,
            cariTuru: 'Cari Hesap',
            cariKodu: cariKodu,
            cariAdi: cariAdi,
            kullanici: kullanici,
            entegrasyonRef: integrationRef,
            cariEntegrasyonYap: cariId != null && cariId > 0,
            session: s,
          );
        }
      }
    }
  }

  Future<Map<int, int>> _stokHareketiShipmentleriOlustur({
    required List<dynamic> items,
    required DateTime tarih,
    required String aciklama,
    required String cariAdi,
    required String cariKodu,
    required String kullanici,
    required String entegrasyonRef,
    required TxSession session,
  }) async {
    final Map<int, List<Map<String, dynamic>>> byWarehouse = {};
    for (final raw in items) {
      final int? warehouseId = int.tryParse(
        raw['warehouseId']?.toString() ?? '',
      );
      if (warehouseId == null || warehouseId <= 0) continue;
      byWarehouse.putIfAbsent(warehouseId, () => []);
      byWarehouse[warehouseId]!.add({
        'code': raw['code'],
        'name': raw['name'],
        'unit': raw['unit'] ?? 'Adet',
        'quantity': double.tryParse(raw['quantity']?.toString() ?? '0') ?? 0.0,
        'unitCost': double.tryParse(raw['price']?.toString() ?? '0') ?? 0.0,
        'total': double.tryParse(raw['total']?.toString() ?? '0') ?? 0.0,
      });
    }
    final Map<int, int> shipmentIds = {};
    for (final entry in byWarehouse.entries) {
      final res = await session.execute(
        Sql.named('''
          INSERT INTO shipments (
            source_warehouse_id, dest_warehouse_id, date, description, items, integration_ref, created_by
          ) VALUES (
            @sourceId, NULL, @date, @description, @items, @integration_ref, @created_by
          ) RETURNING id
        '''),
        parameters: {
          'sourceId': entry.key,
          'date': tarih,
          'description': aciklama,
          'items': jsonEncode(entry.value),
          'integration_ref': entegrasyonRef,
          'created_by': kullanici,
        },
      );
      shipmentIds[entry.key] = res[0][0] as int;
    }
    return shipmentIds;
  }
}
