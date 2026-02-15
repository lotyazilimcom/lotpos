/// Alım ve Satım işlemlerinde kullanılan ortak ürün kalemi modeli.
///
/// Bu model, [SatisYapSayfasi] ve [AlisYapSayfasi] tarafından
/// ortak olarak kullanılır ve kod tekrarını önler.
class TransactionItem {
  final String code;
  final String name;
  final String barcode;
  final String unit;
  final double quantity;
  final double unitPrice;
  final String currency;
  final double exchangeRate;
  final double otvRate;
  final bool otvIncluded;
  final double oivRate;
  final bool oivIncluded;
  final double kdvTevkifatOrani; // 0.0 ile 1.0 arası (örn: 5/10 için 0.5)
  final double vatRate;
  final double discountRate;
  final int warehouseId;
  final String warehouseName;
  final bool vatIncluded; // KDV Dahil mi?

  final String? serialNumber;

  TransactionItem({
    required this.code,
    required this.name,
    required this.barcode,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.currency,
    this.exchangeRate = 1.0,
    required this.vatRate,
    required this.discountRate,
    required this.warehouseId,
    required this.warehouseName,
    this.vatIncluded = false,
    this.otvRate = 0,
    this.otvIncluded = false,
    this.oivRate = 0,
    this.oivIncluded = false,
    this.kdvTevkifatOrani = 0,
    this.serialNumber,
  });

  // Derived calculations

  /// Birim Fiyat (Vergiler Hariç Saf Birim Fiyat)
  double get netUnitPrice {
    double price = unitPrice;

    // Eğer KDV dahilse, KDV'yi düş (KDV, ÖTV ve ÖİV eklenmiş tutar üzerinden hesaplanır)
    if (vatIncluded) {
      price = price / (1 + vatRate / 100);
    }

    // Şimdi elimizde (Saf Fiyat + ÖTV + ÖİV) var. ÖTV ve ÖİV saf fiyat üzerinden hesaplandığı için:
    // (P + P*otv + P*oiv) = price => P(1 + otv + oiv) = price => P = price / (1 + otv + oiv)

    double divisor = 1.0;
    if (otvIncluded) divisor += (otvRate / 100);
    if (oivIncluded) divisor += (oivRate / 100);

    return price / divisor;
  }

  /// Satır ÖTV Tutarı
  double get otvAmount => (quantity * netUnitPrice) * (otvRate / 100);

  /// Satır ÖİV Tutarı
  double get oivAmount => (quantity * netUnitPrice) * (oivRate / 100);

  /// Satır İskonto Tutarı (Saf tutar üzerinden)
  double get discountAmount => (quantity * netUnitPrice) * (discountRate / 100);

  /// KDV Matrahı (Saf Tutar + ÖTV + ÖİV - İskonto)
  double get vatBase {
    final subtotal = (quantity * netUnitPrice) + otvAmount + oivAmount;
    // İskonto genellikle toplam matrah üzerinden düşülür
    final totalDiscount = subtotal * (discountRate / 100);
    return subtotal - totalDiscount;
  }

  /// KDV Tutarı (Brüt)
  double get vatAmount => vatBase * (vatRate / 100);

  /// KDV Tevkifat Tutarı
  double get kdvTevkifatAmount => vatAmount * kdvTevkifatOrani;

  /// Ödenecek KDV (Net)
  double get netVatAmount => vatAmount - kdvTevkifatAmount;

  /// KDV Hariç Toplam (Tüm vergiler dahil ama KDV hariç)
  double get totalBeforeVat => vatBase;

  /// Genel Toplam (Ödenecek Tutar: Matrah + Net KDV)
  double get total => vatBase + netVatAmount;

  TransactionItem copyWith({
    String? code,
    String? name,
    String? barcode,
    String? unit,
    double? quantity,
    double? unitPrice,
    String? currency,
    double? exchangeRate,
    double? vatRate,
    double? discountRate,
    int? warehouseId,
    String? warehouseName,
    bool? vatIncluded,
    double? otvRate,
    bool? otvIncluded,
    double? oivRate,
    bool? oivIncluded,
    double? kdvTevkifatOrani,
    String? serialNumber,
  }) {
    return TransactionItem(
      code: code ?? this.code,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      vatRate: vatRate ?? this.vatRate,
      discountRate: discountRate ?? this.discountRate,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      vatIncluded: vatIncluded ?? this.vatIncluded,
      otvRate: otvRate ?? this.otvRate,
      otvIncluded: otvIncluded ?? this.otvIncluded,
      oivRate: oivRate ?? this.oivRate,
      oivIncluded: oivIncluded ?? this.oivIncluded,
      kdvTevkifatOrani: kdvTevkifatOrani ?? this.kdvTevkifatOrani,
      serialNumber: serialNumber ?? this.serialNumber,
    );
  }

  /// Ürün kodu ve toplam bilgisini yazdırır
  @override
  String toString() {
    return 'TransactionItem(code: $code, name: $name, qty: $quantity, serial: $serialNumber, total: $total, netUnitPrice: $netUnitPrice)';
  }
}

/// SaleItem için geriye dönük uyumluluk sağlayan typedef
typedef SaleItem = TransactionItem;

/// PurchaseItem için geriye dönük uyumluluk sağlayan typedef
typedef PurchaseItem = TransactionItem;
