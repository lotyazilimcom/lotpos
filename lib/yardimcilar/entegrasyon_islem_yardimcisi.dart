import 'package:flutter/foundation.dart';

import '../sayfalar/alimsatimislemleri/modeller/transaction_item.dart';
import '../sayfalar/urunler_ve_depolar/depolar/modeller/depo_model.dart';
import '../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../servisler/depolar_veritabani_servisi.dart';

class EntegrasyonIslemYardimcisi {
  static Future<List<TransactionItem>> entegrasyonKalemleriniYukle(
    String ref,
  ) async {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      final text = value.toString().trim();
      if (text.isEmpty) return 0.0;
      final normalized = text
          .replaceAll(',', '.')
          .replaceAll('%', '')
          .replaceAll(RegExp(r'\s+'), '');
      return double.tryParse(normalized) ?? 0.0;
    }

    double parseRatio(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      final text = value.toString().trim();
      if (text.isEmpty) return 0.0;
      if (text.contains('/')) {
        final parts = text.split('/');
        if (parts.length == 2) {
          final num = parseDouble(parts[0]);
          final den = parseDouble(parts[1]);
          if (den != 0) return num / den;
        }
      }
      final parsed = parseDouble(text);
      if (parsed > 1 && parsed <= 100) return parsed / 100.0;
      return parsed;
    }

    final shipments = await CariHesaplarVeritabaniServisi()
        .entegrasyonShipmentsGetir(ref);

    if (shipments.isEmpty) return [];

    final List<DepoModel> depolar =
        await DepolarVeritabaniServisi().tumDepolariGetir();
    final Map<int, DepoModel> depoById = {for (final d in depolar) d.id: d};
    final int fallbackWarehouseId = depolar.isNotEmpty ? depolar.first.id : 0;
    final String fallbackWarehouseName =
        depolar.isNotEmpty ? depolar.first.ad : '';

    final List<TransactionItem> items = [];
    for (final s in shipments) {
      final int? warehouseId =
          (s['source_warehouse_id'] as int?) ??
          (s['dest_warehouse_id'] as int?);
      final int safeWarehouseId = warehouseId ?? fallbackWarehouseId;
      final String warehouseName =
          depoById[safeWarehouseId]?.ad ?? fallbackWarehouseName;

      final rawItems = s['items'];
      if (rawItems is! List) continue;

      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final code = raw['code']?.toString() ?? '';
        if (code.isEmpty) continue;

        String currency = raw['currency']?.toString() ?? 'TRY';
        if (currency == 'TL') currency = 'TRY';

        final double rate = parseDouble(raw['exchangeRate'] ?? 1.0);
        final double unitCostLocal = parseDouble(
          raw['unitCost'] ??
              raw['unit_cost'] ??
              raw['unitPrice'] ??
              raw['unit_price'] ??
              raw['price'] ??
              raw['birim_fiyat'] ??
              raw['birimFiyat'] ??
              raw['ham_fiyat'] ??
              raw['hamFiyat'],
        );
        final double unitPrice =
            (currency != 'TRY' && rate > 0) ? (unitCostLocal / rate) : unitCostLocal;

        final double quantity = parseDouble(
          raw['quantity'] ?? raw['miktar'] ?? raw['qty'],
        );
        final double discountRate = parseDouble(
          raw['discountRate'] ??
              raw['discount_rate'] ??
              raw['discount'] ??
              raw['iskonto'] ??
              raw['iskontoOrani'] ??
              raw['iskonto_orani'],
        );
        final double vatRate = parseDouble(
          raw['vatRate'] ??
              raw['vat_rate'] ??
              raw['kdvOrani'] ??
              raw['kdv_orani'] ??
              raw['kdvRate'] ??
              raw['kdv_rate'] ??
              raw['kdv'],
        );
        final double otvRate = parseDouble(
          raw['otvRate'] ??
              raw['otv_rate'] ??
              raw['otvOrani'] ??
              raw['otv_orani'] ??
              raw['otv'],
        );
        final double oivRate = parseDouble(
          raw['oivRate'] ??
              raw['oiv_rate'] ??
              raw['oivOrani'] ??
              raw['oiv_orani'] ??
              raw['oiv'],
        );
        final double tevkifatOrani = parseRatio(
          raw['kdvTevkifatOrani'] ??
              raw['kdv_tevkifat_orani'] ??
              raw['tevkifatOrani'] ??
              raw['tevkifat_orani'] ??
              raw['kdvTevkifat'] ??
              raw['kdv_tevkifat'] ??
              raw['kdvTevkifatValue'] ??
              raw['kdv_tevkifat_value'] ??
              raw['tevkifat'],
        );

        final double lineTotalLocal = parseDouble(
          raw['total'] ?? raw['lineTotal'] ?? raw['line_total'],
        );
        final double lineTotal =
            (currency != 'TRY' && rate > 0) ? (lineTotalLocal / rate) : lineTotalLocal;

        double resolvedVatRate = vatRate;
        if (resolvedVatRate <= 0 && lineTotal > 0 && quantity > 0) {
          final double base = quantity * unitPrice;
          final double otvAmount = base * (otvRate / 100);
          final double oivAmount = base * (oivRate / 100);

          final double subtotal = base + otvAmount + oivAmount;
          final double discountAmount = subtotal * (discountRate / 100);
          final double vatBase = subtotal - discountAmount;

          if (vatBase > 0) {
            final double netVatAmount = (lineTotal - vatBase).clamp(
              0,
              double.infinity,
            );

            if (netVatAmount > 0) {
              final double divisor = (1.0 - tevkifatOrani);
              final double inferredVatAmount =
                  (divisor > 0) ? (netVatAmount / divisor) : netVatAmount;
              resolvedVatRate = (inferredVatAmount / vatBase) * 100.0;

              if (resolvedVatRate.isFinite) {
                final rounded = resolvedVatRate.roundToDouble();
                if ((resolvedVatRate - rounded).abs() < 0.05) {
                  resolvedVatRate = rounded;
                }
              }
            }
          }
        }

        items.add(
          TransactionItem(
            code: code,
            name: raw['name']?.toString() ?? code,
            barcode: raw['barcode']?.toString() ?? '',
            unit: raw['unit']?.toString() ?? '',
            quantity: quantity,
            unitPrice: unitPrice,
            currency: currency,
            exchangeRate: rate,
            vatRate: resolvedVatRate,
            discountRate: discountRate,
            warehouseId: safeWarehouseId,
            warehouseName: warehouseName,
            vatIncluded: false,
            otvRate: otvRate,
            otvIncluded: false,
            oivRate: oivRate,
            oivIncluded: false,
            kdvTevkifatOrani: tevkifatOrani,
          ),
        );
      }
    }

    return items;
  }

  static void logError(Object error) {
    debugPrint('EntegrasyonIslemYardimcisi hata: $error');
  }
}

