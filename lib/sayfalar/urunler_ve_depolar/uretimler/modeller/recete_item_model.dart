/// Üretim Reçetesi Kalemi Modeli
/// Bir üretimin hangi ürünlerden ve ne miktarlardan oluştuğunu tutar
class ReceteItem {
  ReceteItem({
    required this.kod,
    required this.ad,
    required this.birim,
    required this.miktar,
  });

  final String kod;
  final String ad;
  final String birim;
  final double miktar;

  Map<String, dynamic> toMap() {
    return {
      'product_code': kod,
      'product_name': ad,
      'unit': birim,
      'quantity': miktar,
    };
  }

  factory ReceteItem.fromMap(Map<String, dynamic> map) {
    return ReceteItem(
      kod: (map['product_code'] ?? '').toString(),
      ad: (map['product_name'] ?? '').toString(),
      birim: (map['unit'] ?? '').toString(),
      miktar: (map['quantity'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
