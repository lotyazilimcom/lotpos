class CihazModel {
  final int id;
  final int productId;
  final String identityType; // IMEI, Seri No, vb.
  final String identityValue;
  final String condition; // Sıfır, İkinci El, vb.
  final String? color;
  final String? capacity;
  final DateTime? warrantyEndDate;
  final bool hasBox;
  final bool hasInvoice;
  final bool hasOriginalCharger;

  final bool isSold;
  final String? saleRef;

  const CihazModel({
    required this.id,
    required this.productId,
    required this.identityType,
    required this.identityValue,
    required this.condition,
    this.color,
    this.capacity,
    this.warrantyEndDate,
    this.hasBox = false,
    this.hasInvoice = false,
    this.hasOriginalCharger = false,
    this.isSold = false,
    this.saleRef,
  });

  CihazModel copyWith({
    int? id,
    int? productId,
    String? identityType,
    String? identityValue,
    String? condition,
    String? color,
    String? capacity,
    DateTime? warrantyEndDate,
    bool? hasBox,
    bool? hasInvoice,
    bool? hasOriginalCharger,
    bool? isSold,
    String? saleRef,
  }) {
    return CihazModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      identityType: identityType ?? this.identityType,
      identityValue: identityValue ?? this.identityValue,
      condition: condition ?? this.condition,
      color: color ?? this.color,
      capacity: capacity ?? this.capacity,
      warrantyEndDate: warrantyEndDate ?? this.warrantyEndDate,
      hasBox: hasBox ?? this.hasBox,
      hasInvoice: hasInvoice ?? this.hasInvoice,
      hasOriginalCharger: hasOriginalCharger ?? this.hasOriginalCharger,
      isSold: isSold ?? this.isSold,
      saleRef: saleRef ?? this.saleRef,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id == 0 ? null : id,
      'product_id': productId,
      'identity_type': identityType,
      'identity_value': identityValue,
      'condition': condition,
      'color': color,
      'capacity': capacity,
      'warranty_end_date': warrantyEndDate?.toIso8601String(),
      'has_box': hasBox ? 1 : 0,
      'has_invoice': hasInvoice ? 1 : 0,
      'has_original_charger': hasOriginalCharger ? 1 : 0,
      'is_sold': isSold ? 1 : 0,
      'sale_ref': saleRef,
    };
  }

  factory CihazModel.fromMap(Map<String, dynamic> map) {
    return CihazModel(
      id: map['id'] as int? ?? 0,
      productId: map['product_id'] as int? ?? 0,
      identityType: map['identity_type'] as String? ?? 'IMEI',
      identityValue: map['identity_value'] as String? ?? '',
      condition: map['condition'] as String? ?? 'Sıfır',
      color: map['color'] as String?,
      capacity: map['capacity'] as String?,
      warrantyEndDate: map['warranty_end_date'] != null
          ? DateTime.tryParse(map['warranty_end_date'].toString())
          : null,
      hasBox: (map['has_box'] ?? 0) == 1,
      hasInvoice: (map['has_invoice'] ?? 0) == 1,
      hasOriginalCharger: (map['has_original_charger'] ?? 0) == 1,
      isSold: (map['is_sold'] ?? 0) == 1,
      saleRef: map['sale_ref'] as String?,
    );
  }
}
