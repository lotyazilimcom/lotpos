import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:lospos/servisler/bankalar_veritabani_servisi.dart';
import 'package:lospos/servisler/cari_hesaplar_veritabani_servisi.dart';
import 'package:lospos/servisler/kasalar_veritabani_servisi.dart';
import 'package:lospos/servisler/kredi_kartlari_veritabani_servisi.dart';
import 'package:lospos/servisler/lite_kisitlari.dart';
import 'package:lospos/servisler/urunler_veritabani_servisi.dart';

class PerakendeSonSatisKaydi {
  final String integrationRef;
  final String faturaNo;
  final DateTime tarih;
  final String kullanici;
  final String aciklama;
  final double genelToplam;
  final double toplamMiktar;
  final double nakitTutar;
  final double krediKartiTutar;
  final double havaleTutar;
  final List<Map<String, dynamic>> kalemler;

  const PerakendeSonSatisKaydi({
    required this.integrationRef,
    required this.faturaNo,
    required this.tarih,
    required this.kullanici,
    required this.aciklama,
    required this.genelToplam,
    required this.toplamMiktar,
    required this.nakitTutar,
    required this.krediKartiTutar,
    required this.havaleTutar,
    required this.kalemler,
  });

  bool get hasMultiplePaymentTypes {
    int count = 0;
    if (nakitTutar > 0.0001) count++;
    if (krediKartiTutar > 0.0001) count++;
    if (havaleTutar > 0.0001) count++;
    return count > 1;
  }
}

/// Perakende Satış işlemleriyle ilgili Entegre Veritabanı Servisi
class PerakendeSatisVeritabaniServisi {
  static final PerakendeSatisVeritabaniServisi _instance =
      PerakendeSatisVeritabaniServisi._internal();
  factory PerakendeSatisVeritabaniServisi() => _instance;
  PerakendeSatisVeritabaniServisi._internal();

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }

  List<Map<String, dynamic>> _itemsFromDynamic(dynamic raw) {
    if (raw == null) return const [];
    dynamic decoded = raw;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        return const [];
      }
    }

    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    return const [];
  }

  Future<List<PerakendeSonSatisKaydi>> sonSatislariGetir({
    int limit = 10,
  }) async {
    final urunServisi = UrunlerVeritabaniServisi();
    return urunServisi.transactionBaslat((s) async {
      final rows = await s.execute(
        Sql.named(r'''
          WITH retail_sales AS (
            SELECT
              MAX(COALESCE(s.integration_ref, '')) AS integration_ref,
              MAX(s.date) AS tarih,
              MAX(COALESCE(s.created_by, '')) AS created_by,
              MAX(COALESCE(NULLIF(TRIM(s.description), ''), 'Perakende Satış')) AS aciklama,
              COALESCE(
                jsonb_agg(item ORDER BY COALESCE(item->>'code', ''), COALESCE(item->>'name', ''))
                  FILTER (WHERE item IS NOT NULL),
                '[]'::jsonb
              ) AS items,
              COALESCE(
                SUM(
                  COALESCE(
                    CASE
                      WHEN COALESCE(item->>'total', '') ~ '^-?[0-9]+([.,][0-9]+)?$' THEN
                        REPLACE(item->>'total', ',', '.')::numeric
                      ELSE NULL
                    END,
                    COALESCE(
                      CASE
                        WHEN COALESCE(item->>'quantity', '') ~ '^-?[0-9]+([.,][0-9]+)?$' THEN
                          REPLACE(item->>'quantity', ',', '.')::numeric
                        ELSE NULL
                      END,
                      0
                    ) *
                    COALESCE(
                      CASE
                        WHEN COALESCE(item->>'price', '') ~ '^-?[0-9]+([.,][0-9]+)?$' THEN
                          REPLACE(item->>'price', ',', '.')::numeric
                        ELSE NULL
                      END,
                      CASE
                        WHEN COALESCE(item->>'unitCost', '') ~ '^-?[0-9]+([.,][0-9]+)?$' THEN
                          REPLACE(item->>'unitCost', ',', '.')::numeric
                        ELSE NULL
                      END,
                      0
                    )
                  )
                ),
                0
              ) AS amount,
              COALESCE(
                SUM(
                  COALESCE(
                    CASE
                      WHEN COALESCE(item->>'quantity', '') ~ '^-?[0-9]+([.,][0-9]+)?$' THEN
                        REPLACE(item->>'quantity', ',', '.')::numeric
                      ELSE NULL
                    END,
                    0
                  )
                ),
                0
              ) AS total_quantity
            FROM shipments s
            LEFT JOIN LATERAL jsonb_array_elements(COALESCE(s.items, '[]'::jsonb)) item ON TRUE
            WHERE COALESCE(s.integration_ref, '') LIKE 'RETAIL-%'
            GROUP BY s.integration_ref
          ),
          cash_tx AS (
            SELECT
              integration_ref,
              COALESCE(SUM(amount), 0) AS amount,
              COALESCE(MAX(user_name), '') AS user_name
            FROM cash_register_transactions
            WHERE COALESCE(integration_ref, '') LIKE 'RETAIL-%'
            GROUP BY integration_ref
          ),
          bank_tx AS (
            SELECT
              integration_ref,
              COALESCE(SUM(amount), 0) AS amount,
              COALESCE(MAX(user_name), '') AS user_name
            FROM bank_transactions
            WHERE COALESCE(integration_ref, '') LIKE 'RETAIL-%'
            GROUP BY integration_ref
          ),
          card_tx AS (
            SELECT
              integration_ref,
              COALESCE(SUM(amount), 0) AS amount,
              COALESCE(MAX(user_name), '') AS user_name
            FROM credit_card_transactions
            WHERE COALESCE(integration_ref, '') LIKE 'RETAIL-%'
            GROUP BY integration_ref
          )
          SELECT
            rs.integration_ref,
            rs.tarih,
            COALESCE(
              NULLIF(TRIM(card_tx.user_name), ''),
              NULLIF(TRIM(cash_tx.user_name), ''),
              NULLIF(TRIM(bank_tx.user_name), ''),
              NULLIF(TRIM(rs.created_by), ''),
              'Sistem'
            ) AS kullanici,
            rs.aciklama,
            rs.items,
            rs.amount,
            rs.total_quantity,
            COALESCE(cash_tx.amount, 0) AS cash_amount,
            COALESCE(card_tx.amount, 0) AS card_amount,
            COALESCE(bank_tx.amount, 0) AS bank_amount
          FROM retail_sales rs
          LEFT JOIN cash_tx ON cash_tx.integration_ref = rs.integration_ref
          LEFT JOIN card_tx ON card_tx.integration_ref = rs.integration_ref
          LEFT JOIN bank_tx ON bank_tx.integration_ref = rs.integration_ref
          ORDER BY rs.tarih DESC, rs.integration_ref DESC
          LIMIT @limit
        '''),
        parameters: {'limit': limit},
      );

      return rows
          .map((row) {
            final integrationRef = (row[0] ?? '').toString().trim();
            final tarih = row[1] is DateTime
                ? row[1] as DateTime
                : DateTime.tryParse('${row[1]}') ?? DateTime.now();
            final kullanici = (row[2] ?? '').toString().trim();
            final aciklama = (row[3] ?? '').toString().trim();
            final items = _itemsFromDynamic(row[4]);
            final faturaNo = integrationRef.startsWith('RETAIL-')
                ? integrationRef.substring('RETAIL-'.length)
                : integrationRef;

            return PerakendeSonSatisKaydi(
              integrationRef: integrationRef,
              faturaNo: faturaNo,
              tarih: tarih,
              kullanici: kullanici.isEmpty ? 'Sistem' : kullanici,
              aciklama: aciklama.isEmpty ? 'Perakende Satış' : aciklama,
              genelToplam: _toDouble(row[5]),
              toplamMiktar: _toDouble(row[6]),
              nakitTutar: _toDouble(row[7]),
              krediKartiTutar: _toDouble(row[8]),
              havaleTutar: _toDouble(row[9]),
              kalemler: items,
            );
          })
          .toList(growable: false);
    }, isolationLevel: IsolationLevel.readCommitted);
  }

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

      await CariHesaplarVeritabaniServisi().cariIslemSilByRef(ref, session: s);
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
      final String pSourceType = p['sourceType']?.toString() ?? '';

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
          String displayCariAdi = cariAdi;
          if (integrationRef.startsWith('RETAIL-')) {
            final String lowSource = pSourceType.toLowerCase();
            final String suffix =
                lowSource.contains('nakit') || lowSource.contains('kasa')
                ? '(Nakit)'
                : lowSource.contains('kredi')
                ? '(K. Kartı)'
                : lowSource.contains('havale')
                ? '(Banka Havale)'
                : '(Banka)';
            displayCariAdi = 'Perakende Satış Yapıldı $suffix';
          }
          await BankalarVeritabaniServisi().bankaIslemEkle(
            bankaId: bankalar.first.id,
            tutar: tutar,
            islemTuru: 'Tahsilat',
            aciklama: aciklama,
            tarih: tarih,
            cariTuru: 'Cari Hesap',
            cariKodu: cariKodu,
            cariAdi: displayCariAdi,
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
                .krediKartlariniGetir(sayfaBasinaKayit: 1, session: s);
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
    double toDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
    }

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
        'quantity': toDouble(raw['quantity']),
        'unitCost': toDouble(raw['price']),
        'total': toDouble(raw['total']),
        'discountRate': toDouble(
          raw['discountRate'] ?? raw['discount'] ?? raw['iskonto'],
        ),
        'vatRate': toDouble(raw['vatRate'] ?? raw['vat_rate']),
        'vatIncluded': raw['vatIncluded'] == true,
        'otvRate': toDouble(raw['otvRate'] ?? raw['otv_rate']),
        'otvIncluded': raw['otvIncluded'] == true,
        'oivRate': toDouble(raw['oivRate'] ?? raw['oiv_rate']),
        'oivIncluded': raw['oivIncluded'] == true,
        'kdvTevkifatOrani': toDouble(
          raw['kdvTevkifatOrani'] ??
              raw['kdv_tevkifat_orani'] ??
              raw['tevkifatOrani'] ??
              raw['tevkifat'],
        ),
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
