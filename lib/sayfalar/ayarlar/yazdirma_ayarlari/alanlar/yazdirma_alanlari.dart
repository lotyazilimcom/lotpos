import 'package:patisyov10/yardimcilar/ceviri/ceviri_servisi.dart';

enum YazdirmaAlanTipi { text, image, line }

class YazdirmaAlanTanim {
  final String key;
  final String labelKey; // Çeviri key'i
  final YazdirmaAlanTipi type;
  final bool isStatic;
  final bool repeat;
  final double defaultWidthMm;
  final double defaultHeightMm;

  const YazdirmaAlanTanim({
    required this.key,
    required this.labelKey,
    this.type = YazdirmaAlanTipi.text,
    this.isStatic = false,
    this.repeat = false,
    this.defaultWidthMm = 60,
    this.defaultHeightMm = 8,
  });

  /// Çevrilmiş label döndürür
  String get label => tr(labelKey);
}

class YazdirmaAlanlari {
  static const String staticTextKey = '__static_text__';

  /// Tasarımcı sol panelinde gösterilecek alanlar.
  ///
  /// Not:
  /// - `repeat=true` olanlar "Ürün Satır" alanıdır ve her satır için tekrarlanır.
  /// - `isStatic=true` olanlar veri bağlanmaz, yazdırmada `label` basılır.
  static const List<YazdirmaAlanTanim> tumAlanlar = [
    // ────────────────────────────────────────────────────────────────────
    // SABİT / YARDIMCI
    // ────────────────────────────────────────────────────────────────────
    YazdirmaAlanTanim(
      key: staticTextKey,
      labelKey: 'print.field.static_title',
      isStatic: true,
      defaultWidthMm: 60,
      defaultHeightMm: 8,
    ),
    YazdirmaAlanTanim(
      key: 'horizontal_line',
      labelKey: 'print.field.static_line',
      type: YazdirmaAlanTipi.line,
      defaultWidthMm: 120,
      defaultHeightMm: 3,
    ),

    // ────────────────────────────────────────────────────────────────────
    // ANTET / ÜST BİLGİ
    // ────────────────────────────────────────────────────────────────────
    YazdirmaAlanTanim(
      key: 'header_line_1',
      labelKey: 'print.field.header_line_1',
      defaultWidthMm: 90,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'header_line_2',
      labelKey: 'print.field.header_line_2',
      defaultWidthMm: 90,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'header_line_3',
      labelKey: 'print.field.header_line_3',
      defaultWidthMm: 90,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'seller_logo',
      labelKey: 'print.field.seller_logo',
      type: YazdirmaAlanTipi.image,
      defaultWidthMm: 30,
      defaultHeightMm: 20,
    ),
    YazdirmaAlanTanim(
      key: 'page_no',
      labelKey: 'print.field.page_no',
      defaultWidthMm: 25,
      defaultHeightMm: 6,
    ),

    // ────────────────────────────────────────────────────────────────────
    // SATICI (FİRMA) BİLGİLERİ
    // ────────────────────────────────────────────────────────────────────
    YazdirmaAlanTanim(
      key: 'seller_name',
      labelKey: 'print.field.seller_name',
      defaultWidthMm: 90,
      defaultHeightMm: 8,
    ),
    YazdirmaAlanTanim(
      key: 'seller_address',
      labelKey: 'print.field.seller_address',
      defaultWidthMm: 90,
      defaultHeightMm: 14,
    ),
    YazdirmaAlanTanim(
      key: 'seller_tax_office',
      labelKey: 'print.field.seller_tax_office',
      defaultWidthMm: 45,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'seller_tax_no',
      labelKey: 'print.field.seller_tax_no',
      defaultWidthMm: 45,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'seller_phone',
      labelKey: 'print.field.seller_phone',
      defaultWidthMm: 45,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'seller_email',
      labelKey: 'print.field.seller_email',
      defaultWidthMm: 60,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'seller_web',
      labelKey: 'print.field.seller_web',
      defaultWidthMm: 60,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'bank_info',
      labelKey: 'print.field.bank_info',
      defaultWidthMm: 90,
      defaultHeightMm: 14,
    ),

    // ────────────────────────────────────────────────────────────────────
    // CARİ (MÜŞTERİ) BİLGİLERİ
    // ────────────────────────────────────────────────────────────────────
    YazdirmaAlanTanim(
      key: 'customer_code',
      labelKey: 'print.field.customer_code',
      defaultWidthMm: 45,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'customer_account_name',
      labelKey: 'print.field.customer_account_name',
      defaultWidthMm: 90,
      defaultHeightMm: 8,
    ),
    YazdirmaAlanTanim(
      key: 'customer_invoice_title',
      labelKey: 'print.field.customer_invoice_title',
      defaultWidthMm: 90,
      defaultHeightMm: 8,
    ),
    YazdirmaAlanTanim(
      key: 'customer_name',
      labelKey: 'print.field.customer_name',
      defaultWidthMm: 90,
      defaultHeightMm: 8,
    ),
    YazdirmaAlanTanim(
      key: 'customer_address',
      labelKey: 'print.field.customer_address',
      defaultWidthMm: 95,
      defaultHeightMm: 14,
    ),
    YazdirmaAlanTanim(
      key: 'customer_shipping_address',
      labelKey: 'print.field.customer_shipping_address',
      defaultWidthMm: 95,
      defaultHeightMm: 14,
    ),
    YazdirmaAlanTanim(
      key: 'tax_office',
      labelKey: 'print.field.tax_office',
      defaultWidthMm: 47,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'tax_no',
      labelKey: 'print.field.tax_no',
      defaultWidthMm: 47,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'customer_phone',
      labelKey: 'print.field.customer_phone',
      defaultWidthMm: 45,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'customer_phone2',
      labelKey: 'print.field.customer_phone2',
      defaultWidthMm: 45,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'customer_email',
      labelKey: 'print.field.customer_email',
      defaultWidthMm: 60,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'customer_web',
      labelKey: 'print.field.customer_web',
      defaultWidthMm: 60,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'customer_info1',
      labelKey: 'print.field.customer_info1',
      defaultWidthMm: 60,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'customer_info2',
      labelKey: 'print.field.customer_info2',
      defaultWidthMm: 60,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'customer_info3',
      labelKey: 'print.field.customer_info3',
      defaultWidthMm: 60,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'customer_info4',
      labelKey: 'print.field.customer_info4',
      defaultWidthMm: 60,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'customer_info5',
      labelKey: 'print.field.customer_info5',
      defaultWidthMm: 60,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'previous_balance',
      labelKey: 'print.field.previous_balance',
      defaultWidthMm: 40,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'current_balance',
      labelKey: 'print.field.current_balance',
      defaultWidthMm: 40,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'balance_currency',
      labelKey: 'print.field.balance_currency',
      defaultWidthMm: 20,
      defaultHeightMm: 6,
    ),

    // ────────────────────────────────────────────────────────────────────
    // BELGE BİLGİLERİ
    // ────────────────────────────────────────────────────────────────────
    YazdirmaAlanTanim(
      key: 'invoice_type',
      labelKey: 'print.field.invoice_type',
      defaultWidthMm: 45,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'invoice_no',
      labelKey: 'print.field.invoice_no',
      defaultWidthMm: 50,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'invoice_date',
      labelKey: 'print.field.invoice_date',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'serial_no',
      labelKey: 'print.field.serial_no',
      defaultWidthMm: 25,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'sequence_no',
      labelKey: 'print.field.sequence_no',
      defaultWidthMm: 30,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'date',
      labelKey: 'print.field.date',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'time',
      labelKey: 'print.field.time',
      defaultWidthMm: 25,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'created_date',
      labelKey: 'print.field.created_date',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'created_time',
      labelKey: 'print.field.created_time',
      defaultWidthMm: 25,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'dispatch_number',
      labelKey: 'print.field.dispatch_number',
      defaultWidthMm: 50,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'dispatch_date',
      labelKey: 'print.field.dispatch_date',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'dispatch_time',
      labelKey: 'print.field.dispatch_time',
      defaultWidthMm: 25,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'actual_dispatch_date',
      labelKey: 'print.field.actual_dispatch_date',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'order_no',
      labelKey: 'print.field.order_no',
      defaultWidthMm: 50,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'due_date',
      labelKey: 'print.field.due_date',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'validity_date',
      labelKey: 'print.field.validity_date',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'note',
      labelKey: 'print.field.note',
      defaultWidthMm: 100,
      defaultHeightMm: 10,
    ),
    YazdirmaAlanTanim(
      key: 'description1',
      labelKey: 'print.field.description1',
      defaultWidthMm: 100,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'description2',
      labelKey: 'print.field.description2',
      defaultWidthMm: 100,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'description3',
      labelKey: 'print.field.description3',
      defaultWidthMm: 100,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'description4',
      labelKey: 'print.field.description4',
      defaultWidthMm: 100,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'description5',
      labelKey: 'print.field.description5',
      defaultWidthMm: 100,
      defaultHeightMm: 6,
    ),

    // ────────────────────────────────────────────────────────────────────
    // ÜRÜN TABLOSU
    // ────────────────────────────────────────────────────────────────────
    YazdirmaAlanTanim(
      key: 'items_table',
      labelKey: 'print.field.items_table',
      defaultWidthMm: 190,
      defaultHeightMm: 80,
    ),
    YazdirmaAlanTanim(
      key: 'items_table_extended',
      labelKey: 'print.field.items_table_extended',
      defaultWidthMm: 190,
      defaultHeightMm: 80,
    ),

    // ────────────────────────────────────────────────────────────────────
    // ÜRÜN SATIR (TEKRARLANAN)
    // ────────────────────────────────────────────────────────────────────
    YazdirmaAlanTanim(
      key: 'item_line_no',
      labelKey: 'print.field.item_line_no',
      repeat: true,
      defaultWidthMm: 10,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_name',
      labelKey: 'print.field.item_name',
      repeat: true,
      defaultWidthMm: 70,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_code',
      labelKey: 'print.field.item_code',
      repeat: true,
      defaultWidthMm: 30,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_barcode',
      labelKey: 'print.field.item_barcode',
      repeat: true,
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_description',
      labelKey: 'print.field.item_description',
      repeat: true,
      defaultWidthMm: 60,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_unit',
      labelKey: 'print.field.item_unit',
      repeat: true,
      defaultWidthMm: 15,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_quantity',
      labelKey: 'print.field.item_quantity',
      repeat: true,
      defaultWidthMm: 18,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_discount_rate',
      labelKey: 'print.field.item_discount_rate',
      repeat: true,
      defaultWidthMm: 15,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_discount_amount',
      labelKey: 'print.field.item_discount_amount',
      repeat: true,
      defaultWidthMm: 20,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_vat_rate',
      labelKey: 'print.field.item_vat_rate',
      repeat: true,
      defaultWidthMm: 12,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_otv_rate',
      labelKey: 'print.field.item_otv_rate',
      repeat: true,
      defaultWidthMm: 12,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_oiv_rate',
      labelKey: 'print.field.item_oiv_rate',
      repeat: true,
      defaultWidthMm: 12,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_tevkifat_rate',
      labelKey: 'print.field.item_tevkifat_rate',
      repeat: true,
      defaultWidthMm: 15,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_unit_price_excl',
      labelKey: 'print.field.item_unit_price_excl',
      repeat: true,
      defaultWidthMm: 25,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_unit_price_incl',
      labelKey: 'print.field.item_unit_price_incl',
      repeat: true,
      defaultWidthMm: 25,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_total_excl',
      labelKey: 'print.field.item_total_excl',
      repeat: true,
      defaultWidthMm: 25,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_total_incl',
      labelKey: 'print.field.item_total_incl',
      repeat: true,
      defaultWidthMm: 25,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'item_currency',
      labelKey: 'print.field.item_currency',
      repeat: true,
      defaultWidthMm: 15,
      defaultHeightMm: 6,
    ),

    // ────────────────────────────────────────────────────────────────────
    // TOPLAMLAR / VERGİLER
    // ────────────────────────────────────────────────────────────────────
    YazdirmaAlanTanim(
      key: 'subtotal',
      labelKey: 'print.field.subtotal',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'discount_total',
      labelKey: 'print.field.discount_total',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'taxable_amount',
      labelKey: 'print.field.taxable_amount',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'vat_total',
      labelKey: 'print.field.vat_total',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'otv_amount',
      labelKey: 'print.field.otv_amount',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'oiv_amount',
      labelKey: 'print.field.oiv_amount',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'tevkifat_amount',
      labelKey: 'print.field.tevkifat_amount',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'rounding',
      labelKey: 'print.field.rounding',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'grand_total',
      labelKey: 'print.field.grand_total',
      defaultWidthMm: 70,
      defaultHeightMm: 8,
    ),
    YazdirmaAlanTanim(
      key: 'grand_total_rounded',
      labelKey: 'print.field.grand_total_rounded',
      defaultWidthMm: 70,
      defaultHeightMm: 8,
    ),
    YazdirmaAlanTanim(
      key: 'currency',
      labelKey: 'print.field.currency',
      defaultWidthMm: 20,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'exchange_rate',
      labelKey: 'print.field.exchange_rate',
      defaultWidthMm: 25,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'total_as_text',
      labelKey: 'print.field.total_as_text',
      defaultWidthMm: 100,
      defaultHeightMm: 8,
    ),
    YazdirmaAlanTanim(
      key: 'vat_summary',
      labelKey: 'print.field.vat_summary',
      defaultWidthMm: 55,
      defaultHeightMm: 20,
    ),
    YazdirmaAlanTanim(
      key: 'otv_summary',
      labelKey: 'print.field.otv_summary',
      defaultWidthMm: 55,
      defaultHeightMm: 20,
    ),
    YazdirmaAlanTanim(
      key: 'oiv_summary',
      labelKey: 'print.field.oiv_summary',
      defaultWidthMm: 55,
      defaultHeightMm: 20,
    ),
    YazdirmaAlanTanim(
      key: 'tevkifat_summary',
      labelKey: 'print.field.tevkifat_summary',
      defaultWidthMm: 55,
      defaultHeightMm: 20,
    ),

    // KDV 1-6
    YazdirmaAlanTanim(key: 'vat_rate_1', labelKey: 'print.field.vat_rate_1'),
    YazdirmaAlanTanim(key: 'vat_base_1', labelKey: 'print.field.vat_base_1'),
    YazdirmaAlanTanim(
      key: 'vat_amount_1',
      labelKey: 'print.field.vat_amount_1',
    ),
    YazdirmaAlanTanim(key: 'vat_rate_2', labelKey: 'print.field.vat_rate_2'),
    YazdirmaAlanTanim(key: 'vat_base_2', labelKey: 'print.field.vat_base_2'),
    YazdirmaAlanTanim(
      key: 'vat_amount_2',
      labelKey: 'print.field.vat_amount_2',
    ),
    YazdirmaAlanTanim(key: 'vat_rate_3', labelKey: 'print.field.vat_rate_3'),
    YazdirmaAlanTanim(key: 'vat_base_3', labelKey: 'print.field.vat_base_3'),
    YazdirmaAlanTanim(
      key: 'vat_amount_3',
      labelKey: 'print.field.vat_amount_3',
    ),
    YazdirmaAlanTanim(key: 'vat_rate_4', labelKey: 'print.field.vat_rate_4'),
    YazdirmaAlanTanim(key: 'vat_base_4', labelKey: 'print.field.vat_base_4'),
    YazdirmaAlanTanim(
      key: 'vat_amount_4',
      labelKey: 'print.field.vat_amount_4',
    ),
    YazdirmaAlanTanim(key: 'vat_rate_5', labelKey: 'print.field.vat_rate_5'),
    YazdirmaAlanTanim(key: 'vat_base_5', labelKey: 'print.field.vat_base_5'),
    YazdirmaAlanTanim(
      key: 'vat_amount_5',
      labelKey: 'print.field.vat_amount_5',
    ),
    YazdirmaAlanTanim(key: 'vat_rate_6', labelKey: 'print.field.vat_rate_6'),
    YazdirmaAlanTanim(key: 'vat_base_6', labelKey: 'print.field.vat_base_6'),
    YazdirmaAlanTanim(
      key: 'vat_amount_6',
      labelKey: 'print.field.vat_amount_6',
    ),

    // ────────────────────────────────────────────────────────────────────
    // ÖDEME / FİŞ
    // ────────────────────────────────────────────────────────────────────
    YazdirmaAlanTanim(
      key: 'payment_type',
      labelKey: 'print.field.payment_type',
      defaultWidthMm: 40,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'cash_amount',
      labelKey: 'print.field.cash_amount',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'card_amount',
      labelKey: 'print.field.card_amount',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'change_amount',
      labelKey: 'print.field.change_amount',
      defaultWidthMm: 35,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'cashier_name',
      labelKey: 'print.field.cashier_name',
      defaultWidthMm: 50,
      defaultHeightMm: 6,
    ),
    YazdirmaAlanTanim(
      key: 'receipt_qr',
      labelKey: 'print.field.receipt_qr',
      type: YazdirmaAlanTipi.image,
      defaultWidthMm: 25,
      defaultHeightMm: 25,
    ),
  ];
}
