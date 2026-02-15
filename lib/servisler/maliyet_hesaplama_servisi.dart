import 'package:flutter/foundation.dart';
import 'package:patisyov10/servisler/urunler_veritabani_servisi.dart';
import 'package:postgres/postgres.dart';

class MaliyetHesaplamaServisi {
  static final MaliyetHesaplamaServisi _instance =
      MaliyetHesaplamaServisi._internal();
  factory MaliyetHesaplamaServisi() => _instance;
  MaliyetHesaplamaServisi._internal();

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final normalized = value.toString().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0.0;
  }

  /// Belirli bir ürün için tarihi baz alarak stok hareketlerini tarar ve
  /// Ağırlıklı Ortalama Maliyet (Weighted Average Cost) ile Anlık Stok (Running Stock)
  /// değerlerini yeniden hesaplar ve günceller.
  ///
  /// [stockId]: Ürün ID
  /// [startDate]: Hangi tarihten itibaren hesaplanacak. Genellikle değiştirilen/silinen işlemin tarihi.
  /// [session]: Transaction bütünlüğü için gerekli session.
  Future<void> maliyetleriYenidenHesapla(
    int stockId,
    DateTime startDate, {
    TxSession? session,
  }) async {
    // Eğer session yoksa, yeni bir transaction başlat ve içinde çalıştır.
    if (session == null) {
      await UrunlerVeritabaniServisi().transactionBaslat((s) async {
        await maliyetleriYenidenHesapla(stockId, startDate, session: s);
      });
      return;
    }

    final executor = session;

    try {
      // 1. Başlangıç Değerlerini Bul (startDate'den önceki son durum)
      // Bu, zincirin kopmaması için gereklidir.
      // Eğer startDate öncesinde hiç kayıt yoksa 0 kabul edilir.

      double currentStock = 0;
      double currentCost = 0;

      final lastStateResult = await executor.execute(
        Sql.named("""
          SELECT running_stock, running_cost 
          FROM stock_movements 
          WHERE product_id = @stockId AND movement_date < @startDate
          ORDER BY movement_date DESC, created_at DESC 
          LIMIT 1
        """),
        parameters: {
          'stockId': stockId,
          'startDate': startDate.toIso8601String(), // Timestamp olarak gitmeli
        },
      );

      if (lastStateResult.isNotEmpty) {
        currentStock = _toDouble(lastStateResult.first[0]);
        currentCost = _toDouble(lastStateResult.first[1]);
      }

      // 2. Etkilenen Hareketleri Getir (Tarih ve Oluşturulma sırasına göre)
      // Bu hareketlerin 'running_stock' ve 'running_cost' değerleri güncellenecek.
      final movementsResult = await executor.execute(
        Sql.named("""
          SELECT id, quantity, unit_price, is_giris, movement_type 
          FROM stock_movements 
          WHERE product_id = @stockId AND movement_date >= @startDate
          ORDER BY movement_date ASC, created_at ASC
        """),
        parameters: {
          'stockId': stockId,
          'startDate': startDate.toIso8601String(),
        },
      );

      // 3. Hesaplama Döngüsü
      for (final row in movementsResult) {
        final int id = row[0] as int;
        final double qty = _toDouble(row[1]);
        final double price =
            _toDouble(row[2]); // Alışta Maliyet, Satışta Satış Fiyatı
        final bool isGiris = row[3] as bool;
        // final String type = row[4] as String;

        if (isGiris) {
          // GİRİŞ: Ağırlıklı Ortalama Maliyet Hesabı
          // Yeni Maliyet = ((Mevcut Stok * Mevcut Maliyet) + (Giren Miktar * Giren Fiyat)) / Toplam Miktar

          double totalExistingValue = currentStock * currentCost;
          double totalIncomingValue = qty * price;
          double distinctTotalStock = currentStock + qty;

          if (distinctTotalStock > 0) {
            currentCost =
                (totalExistingValue + totalIncomingValue) / distinctTotalStock;
          } else {
            if (distinctTotalStock == 0) currentCost = 0;
          }
          currentStock = distinctTotalStock;
        } else {
          // ÇIKIŞ: Maliyet değişmez, Stok düşer.
          // Satış anındaki maliyet (COGS) korunur.
          currentStock -= qty;
        }

        // 4. Satırı Güncelle
        await executor.execute(
          Sql.named("""
            UPDATE stock_movements 
            SET running_stock = @stk, running_cost = @cst 
            WHERE id = @id
          """),
          parameters: {'stk': currentStock, 'cst': currentCost, 'id': id},
        );
      }

      // 5. Ürün Kartını Güncelle (Son Durum)
      await executor.execute(
        Sql.named("""
          UPDATE products 
          SET stok = @stk, alis_fiyati = @cst
          WHERE id = @id
        """),
        parameters: {'stk': currentStock, 'cst': currentCost, 'id': stockId},
      );

      // debugPrint('Maliyet Hesaplama Başarılı: StokID=$stockId, YeniStok=$currentStock, YeniMaliyet=$currentCost');
    } catch (e) {
      debugPrint('Maliyet Hesaplama Hatası (StokID: $stockId): $e');
      rethrow;
    }
  }
}
