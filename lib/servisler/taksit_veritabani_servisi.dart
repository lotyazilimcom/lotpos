import 'package:postgres/postgres.dart';
import 'urunler_veritabani_servisi.dart';

class TaksitVeritabaniServisi {
  static final TaksitVeritabaniServisi _instance =
      TaksitVeritabaniServisi._internal();
  factory TaksitVeritabaniServisi() => _instance;
  TaksitVeritabaniServisi._internal();

  final _urunServisi = UrunlerVeritabaniServisi();

  Future<bool> cariIcinTaksitVarMi(int cariId) async {
    try {
      return await _urunServisi.transactionBaslat((s) async {
        final res = await s.execute(
          Sql.named('SELECT 1 FROM installments WHERE cari_id = @id LIMIT 1'),
          parameters: {'id': cariId},
        );
        return res.isNotEmpty;
      });
    } catch (e) {
      // [GUARD] Tablo henüz yoksa veya migration tamamlanmadıysa sessizce false dön
      if (e.toString().contains('42P01')) return false;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> cariTaksitleriniGetir(
    int cariId, {
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
  }) async {
    try {
      return await _urunServisi.transactionBaslat((s) async {
        final DateTime? endExclusive = bitisTarihi?.add(
          const Duration(days: 1),
        );

        final where = <String>['ins.cari_id = @cariId'];
        final params = <String, dynamic>{'cariId': cariId};
        if (baslangicTarihi != null) {
          where.add('COALESCE(sale.date, ins.vade_tarihi) >= @start');
          params['start'] = baslangicTarihi;
        }
        if (endExclusive != null) {
          where.add('COALESCE(sale.date, ins.vade_tarihi) < @end');
          params['end'] = endExclusive;
        }

        final res = await s.execute(
          Sql.named('''
            SELECT
              ins.*,
              sale.date AS satis_tarihi,
              sale.amount AS satis_tutar,
              sale.fatura_no AS satis_fatura_no,
              sale.user_name AS satis_kullanici,
              sale.description AS satis_aciklama,
              pay.date AS odeme_tarihi,
              pay.source_type AS odeme_kaynak_turu,
              pay.source_name AS odeme_kaynak_adi,
              pay.source_code AS odeme_kaynak_kodu,
              pay.user_name AS odeme_kullanici
            FROM installments ins
            LEFT JOIN LATERAL (
              SELECT cat.*
              FROM current_account_transactions cat
              WHERE cat.integration_ref = ins.integration_ref
                AND cat.current_account_id = ins.cari_id
              ORDER BY cat.date ASC
              LIMIT 1
            ) sale ON TRUE
            LEFT JOIN current_account_transactions pay
              ON pay.id = ins.hareket_id
            WHERE ${where.join(' AND ')}
            ORDER BY
              COALESCE(sale.date, ins.vade_tarihi) DESC,
              ins.integration_ref,
              ins.vade_tarihi ASC,
              ins.id ASC
          '''),
          parameters: params,
        );

        return res.map((row) => row.toColumnMap()).toList();
      });
    } catch (e) {
      // [GUARD] Tablo henüz yoksa sessizce boş dön
      if (e.toString().contains('42P01')) return [];
      rethrow;
    }
  }

  Future<void> tablolariOlustur({TxSession? session}) async {
    final queries = [
      '''
      CREATE TABLE IF NOT EXISTS installments (
        id SERIAL PRIMARY KEY,
        integration_ref TEXT NOT NULL,
        cari_id INTEGER NOT NULL,
        vade_tarihi TIMESTAMP NOT NULL,
        tutar NUMERIC NOT NULL,
        durum TEXT DEFAULT 'Bekliyor',
        aciklama TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        hareket_id INTEGER
      )
      ''',
      'CREATE INDEX IF NOT EXISTS idx_installments_ref ON installments(integration_ref)',
      'CREATE INDEX IF NOT EXISTS idx_installments_cari ON installments(cari_id)',
      'ALTER TABLE installments ADD COLUMN IF NOT EXISTS hareket_id INTEGER',
    ];

    if (session != null) {
      for (var query in queries) {
        await session.execute(query);
      }
    } else {
      await _urunServisi.transactionBaslat((s) async {
        for (var query in queries) {
          await s.execute(query);
        }
      });
    }
  }

  Future<void> taksitleriKaydet({
    required String integrationRef,
    required int cariId,
    required List<Map<String, dynamic>> taksitler,
    TxSession? session,
  }) async {
    if (taksitler.isEmpty) return;

    Future<void> action(TxSession s) async {
      // Önce varsa eski taksitleri temizle (Güncelleme durumu için)
      await s.execute(
        Sql.named('DELETE FROM installments WHERE integration_ref = @ref'),
        parameters: {'ref': integrationRef},
      );

      for (var taksit in taksitler) {
        await s.execute(
          Sql.named('''
            INSERT INTO installments (integration_ref, cari_id, vade_tarihi, tutar, aciklama)
            VALUES (@ref, @cariId, @vade, @tutar, @aciklama)
          '''),
          parameters: {
            'ref': integrationRef,
            'cariId': cariId,
            'vade': taksit['vade_tarihi'],
            'tutar': taksit['tutar'],
            'aciklama': taksit['aciklama'] ?? '',
          },
        );
      }
    }

    if (session != null) {
      await action(session);
    } else {
      await _urunServisi.transactionBaslat(action);
    }
  }

  Future<void> taksitleriSil(
    String integrationRef, {
    TxSession? session,
  }) async {
    Future<void> action(TxSession s) async {
      await s.execute(
        Sql.named('DELETE FROM installments WHERE integration_ref = @ref'),
        parameters: {'ref': integrationRef},
      );
    }

    if (session != null) {
      await action(session);
    } else {
      await _urunServisi.transactionBaslat(action);
    }
  }

  Future<List<Map<String, dynamic>>> taksitleriGetir(
    String integrationRef,
  ) async {
    return await _urunServisi.transactionBaslat((s) async {
      final res = await s.execute(
        Sql.named(
          'SELECT * FROM installments WHERE integration_ref = @ref ORDER BY vade_tarihi ASC',
        ),
        parameters: {'ref': integrationRef},
      );

      return res.map((row) => row.toColumnMap()).toList();
    });
  }

  /// [NEW] Taksit Durumunu Güncelle (Ödendi/Bekliyor)
  Future<void> taksitDurumGuncelle(
    int id,
    String durum, {
    int? hareketId,
    TxSession? session,
  }) async {
    Future<void> action(TxSession s) async {
      try {
        await s.execute(
          Sql.named(
            'UPDATE installments SET durum = @durum, hareket_id = @hid, updated_at = NOW() WHERE id = @id',
          ),
          parameters: {'id': id, 'durum': durum, 'hid': hareketId},
        );
      } catch (e) {
        // [GUARD] Kolon henüz oluşmamışsa (hareket_id), sadece durumu güncellemeye çalış
        if (e.toString().contains('42703')) {
          await s.execute(
            Sql.named(
              'UPDATE installments SET durum = @durum, updated_at = NOW() WHERE id = @id',
            ),
            parameters: {'id': id, 'durum': durum},
          );
          return;
        }
        rethrow;
      }
    }

    if (session != null) {
      await action(session);
    } else {
      await _urunServisi.transactionBaslat(action);
    }
  }

  /// [NEW] Hareket ID ile taksiti resetle (Ödeme silindiğinde)
  Future<void> hareketIdIleTaksitResetle(
    int hareketId, {
    TxSession? session,
  }) async {
    Future<void> action(TxSession s) async {
      try {
        await s.execute(
          Sql.named(
            'UPDATE installments SET durum = @durum, hareket_id = NULL, updated_at = NOW() WHERE hareket_id = @hid',
          ),
          parameters: {'durum': 'Bekliyor', 'hid': hareketId},
        );
      } catch (e) {
        // [GUARD] Tablo veya kolon henüz oluşmamışsa sessizce geç
        if (e.toString().contains('42P01') || e.toString().contains('42703')) {
          return;
        }
        rethrow;
      }
    }

    if (session != null) {
      await action(session);
    } else {
      await _urunServisi.transactionBaslat(action);
    }
  }

  /// [NEW] Tekil Taksit Verilerini Güncelle
  Future<void> taksitGuncelle({
    required int id,
    required DateTime vade,
    required double tutar,
    String? aciklama,
    TxSession? session,
  }) async {
    Future<void> action(TxSession s) async {
      await s.execute(
        Sql.named('''
          UPDATE installments 
          SET vade_tarihi = @vade, tutar = @tutar, aciklama = @aciklama, updated_at = NOW() 
          WHERE id = @id
        '''),
        parameters: {
          'id': id,
          'vade': vade,
          'tutar': tutar,
          'aciklama': aciklama ?? '',
        },
      );
    }

    if (session != null) {
      await action(session);
    } else {
      await _urunServisi.transactionBaslat(action);
    }
  }
}
