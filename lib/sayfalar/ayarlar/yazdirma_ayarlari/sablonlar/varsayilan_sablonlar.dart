import '../modeller/yazdirma_sablonu_model.dart';
import '../../../../servisler/yazdirma_veritabani_servisi.dart';

/// GİB standartlarına uygun profesyonel Türk ticari belge şablonları.
/// Bu sınıf, uygulama ilk kurulumunda veya kullanıcı isteğiyle
/// varsayılan şablonları veritabanına ekler.
///
/// MEVCUT TOPLAM ALANLARI (TransactionItem modelinden):
/// - subtotal = Mal Hizmet Toplamı (quantity * netUnitPrice)
/// - discount_total = Toplam İskonto (discountAmount toplamı)
/// - taxable_amount = KDV Matrahı (vatBase toplamı)
/// - vat_total = Hesaplanan KDV (vatAmount toplamı)
/// - otv_total = Toplam ÖTV
/// - oiv_total = Toplam ÖİV
/// - tevkifat_total = Toplam Tevkifat
/// - grand_total = Genel Toplam
class VarsayilanSablonlar {
  static final YazdirmaVeritabaniServisi _dbServisi =
      YazdirmaVeritabaniServisi();

  /// Tüm varsayılan şablonları veritabanına ekler.
  static Future<void> tumSablonlariEkle() async {
    await eFaturaSablonuEkle();
    await irsaliyeliFaturaSablonuEkle();
    await sevkIrsaliyesiSablonuEkle();
    await satisFisiSablonuEkle();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 1. E-FATURA ŞABLONU (A4 - 210x297mm)
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> eFaturaSablonuEkle() async {
    final layout = <LayoutElement>[
      // ─────────────────────────────────────────────────────────────────────
      // SATICI BİLGİLERİ (Sol Üst)
      // ─────────────────────────────────────────────────────────────────────
      LayoutElement(
        id: 'ef_seller_name',
        key: 'seller_name',
        label: 'Satıcı Unvanı',
        x: 10,
        y: 10,
        width: 85,
        height: 8,
        fontSize: '12',
        fontWeight: 'bold',
      ),
      LayoutElement(
        id: 'ef_seller_address',
        key: 'seller_address',
        label: 'Satıcı Adresi',
        x: 10,
        y: 19,
        width: 85,
        height: 12,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'ef_seller_tax_office',
        key: 'seller_tax_office',
        label: 'Vergi Dairesi',
        x: 10,
        y: 32,
        width: 42,
        height: 6,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'ef_seller_tax_no',
        key: 'seller_tax_no',
        label: 'VKN',
        x: 53,
        y: 32,
        width: 42,
        height: 6,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'ef_seller_phone',
        key: 'seller_phone',
        label: 'Tel',
        x: 10,
        y: 39,
        width: 42,
        height: 5,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'ef_seller_email',
        key: 'seller_email',
        label: 'E-posta',
        x: 53,
        y: 39,
        width: 42,
        height: 5,
        fontSize: '8',
      ),

      // ─────────────────────────────────────────────────────────────────────
      // FATURA BAŞLIK BİLGİLERİ (Sağ Üst)
      // ─────────────────────────────────────────────────────────────────────
      LayoutElement(
        id: 'ef_invoice_type',
        key: 'invoice_type',
        label: 'SATIŞ FATURASI',
        x: 130,
        y: 10,
        width: 70,
        height: 10,
        fontSize: '14',
        fontWeight: 'bold',
        alignment: 'center',
      ),
      LayoutElement(
        id: 'ef_serial_no',
        key: 'serial_no',
        label: 'Seri',
        x: 130,
        y: 21,
        width: 34,
        height: 6,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'ef_sequence_no',
        key: 'sequence_no',
        label: 'Sıra No',
        x: 166,
        y: 21,
        width: 34,
        height: 6,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'ef_date',
        key: 'date',
        label: 'Tarih',
        x: 130,
        y: 28,
        width: 34,
        height: 6,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'ef_time',
        key: 'time',
        label: 'Saat',
        x: 166,
        y: 28,
        width: 34,
        height: 6,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'ef_ettn',
        key: 'ettn',
        label: 'ETTN',
        x: 130,
        y: 35,
        width: 70,
        height: 5,
        fontSize: '7',
      ),
      LayoutElement(
        id: 'ef_due_date',
        key: 'due_date',
        label: 'Vade Tarihi',
        x: 130,
        y: 41,
        width: 70,
        height: 5,
        fontSize: '8',
      ),

      // ─────────────────────────────────────────────────────────────────────
      // MÜŞTERİ BİLGİLERİ (Sol - Orta)
      // ─────────────────────────────────────────────────────────────────────
      LayoutElement(
        id: 'ef_customer_label',
        key: 'custom_text',
        label: 'SAYIN',
        x: 10,
        y: 52,
        width: 20,
        height: 6,
        fontSize: '9',
        fontWeight: 'bold',
      ),
      LayoutElement(
        id: 'ef_customer_name',
        key: 'customer_name',
        label: 'Müşteri Adı',
        x: 10,
        y: 58,
        width: 95,
        height: 8,
        fontSize: '11',
        fontWeight: 'bold',
      ),
      LayoutElement(
        id: 'ef_customer_address',
        key: 'customer_address',
        label: 'Müşteri Adresi',
        x: 10,
        y: 67,
        width: 95,
        height: 12,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'ef_tax_office',
        key: 'tax_office',
        label: 'V.D.',
        x: 10,
        y: 80,
        width: 47,
        height: 6,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'ef_tax_no',
        key: 'tax_no',
        label: 'VKN/TCKN',
        x: 58,
        y: 80,
        width: 47,
        height: 6,
        fontSize: '8',
      ),

      // ─────────────────────────────────────────────────────────────────────
      // ÜRÜN TABLOSU
      // ─────────────────────────────────────────────────────────────────────
      LayoutElement(
        id: 'ef_items_table',
        key: 'items_table_extended',
        label: 'Ürün Tablosu',
        x: 10,
        y: 92,
        width: 190,
        height: 115,
        fontSize: '9',
      ),

      // ─────────────────────────────────────────────────────────────────────
      // VERGİ VE TOPLAM ALANI (Resimdeki gibi)
      // ─────────────────────────────────────────────────────────────────────
      // Mal Hizmet Toplamı
      LayoutElement(
        id: 'ef_subtotal',
        key: 'subtotal',
        label: 'Mal Hizmet Toplamı',
        x: 130,
        y: 212,
        width: 70,
        height: 6,
        fontSize: '9',
        alignment: 'right',
      ),
      // Toplam İskonto
      LayoutElement(
        id: 'ef_discount_total',
        key: 'discount_total',
        label: 'Toplam İskonto',
        x: 130,
        y: 219,
        width: 70,
        height: 6,
        fontSize: '9',
        alignment: 'right',
      ),
      // KDV Matrahı
      LayoutElement(
        id: 'ef_taxable_amount',
        key: 'taxable_amount',
        label: 'KDV Matrahı',
        x: 130,
        y: 226,
        width: 70,
        height: 6,
        fontSize: '9',
        alignment: 'right',
      ),
      // Hesaplanan KDV
      LayoutElement(
        id: 'ef_vat_total',
        key: 'vat_total',
        label: 'Hesaplanan KDV',
        x: 130,
        y: 233,
        width: 70,
        height: 6,
        fontSize: '9',
        alignment: 'right',
      ),

      // ÖTV Tutarı (varsa)
      LayoutElement(
        id: 'ef_otv_total',
        key: 'otv_amount',
        label: 'ÖTV Tutarı',
        x: 10,
        y: 240,
        width: 50,
        height: 5,
        fontSize: '8',
      ),
      // ÖİV Tutarı (varsa)
      LayoutElement(
        id: 'ef_oiv_total',
        key: 'oiv_amount',
        label: 'ÖİV Tutarı',
        x: 65,
        y: 240,
        width: 50,
        height: 5,
        fontSize: '8',
      ),
      // Tevkifat Tutarı (varsa)
      LayoutElement(
        id: 'ef_tevkifat',
        key: 'tevkifat_amount',
        label: 'Tevkifat Tutarı',
        x: 10,
        y: 246,
        width: 50,
        height: 5,
        fontSize: '8',
      ),

      // GENEL TOPLAM
      LayoutElement(
        id: 'ef_grand_total',
        key: 'grand_total',
        label: 'GENEL TOPLAM',
        x: 130,
        y: 242,
        width: 70,
        height: 12,
        fontSize: '14',
        fontWeight: 'bold',
        alignment: 'right',
      ),

      // Yazı ile
      LayoutElement(
        id: 'ef_total_as_text',
        key: 'total_as_text',
        label: 'Yalnız',
        x: 10,
        y: 258,
        width: 140,
        height: 8,
        fontSize: '9',
      ),

      // ─────────────────────────────────────────────────────────────────────
      // ALT BİLGİLER
      // ─────────────────────────────────────────────────────────────────────
      LayoutElement(
        id: 'ef_bank_info',
        key: 'bank_info',
        label: 'Banka Bilgileri',
        x: 10,
        y: 270,
        width: 95,
        height: 15,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'ef_note',
        key: 'note',
        label: 'Not',
        x: 110,
        y: 270,
        width: 90,
        height: 15,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'ef_payment_type',
        key: 'payment_type',
        label: 'Ödeme Şekli',
        x: 10,
        y: 287,
        width: 50,
        height: 6,
        fontSize: '8',
      ),
    ];

    final sablon = YazdirmaSablonuModel(
      name: 'Profesyonel E-Fatura',
      docType: 'invoice',
      paperSize: 'A4',
      layout: layout,
      isDefault: true,
      isLandscape: false,
    );

    await _dbServisi.sablonEkle(sablon);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 2. İRSALİYELİ FATURA ŞABLONU (A4 - 210x297mm)
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> irsaliyeliFaturaSablonuEkle() async {
    final layout = <LayoutElement>[
      // Satıcı Bilgileri
      LayoutElement(
        id: 'if_seller_name',
        key: 'seller_name',
        label: 'Satıcı Unvanı',
        x: 10,
        y: 10,
        width: 85,
        height: 8,
        fontSize: '12',
        fontWeight: 'bold',
      ),
      LayoutElement(
        id: 'if_seller_address',
        key: 'seller_address',
        label: 'Satıcı Adresi',
        x: 10,
        y: 19,
        width: 85,
        height: 10,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'if_seller_tax_office',
        key: 'seller_tax_office',
        label: 'V.D.',
        x: 10,
        y: 30,
        width: 42,
        height: 5,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'if_seller_tax_no',
        key: 'seller_tax_no',
        label: 'VKN',
        x: 53,
        y: 30,
        width: 42,
        height: 5,
        fontSize: '8',
      ),

      // Fatura Başlık
      LayoutElement(
        id: 'if_invoice_type',
        key: 'invoice_type',
        label: 'İRSALİYELİ FATURA',
        x: 125,
        y: 10,
        width: 75,
        height: 10,
        fontSize: '13',
        fontWeight: 'bold',
        alignment: 'center',
      ),
      LayoutElement(
        id: 'if_irsaliye_ibaresi',
        key: 'irsaliye_yerine_gecer',
        label: 'İRSALİYE YERİNE GEÇER',
        x: 125,
        y: 21,
        width: 75,
        height: 6,
        fontSize: '8',
        fontWeight: 'bold',
        alignment: 'center',
        color: '#FF0000',
      ),
      LayoutElement(
        id: 'if_serial_no',
        key: 'serial_no',
        label: 'Seri',
        x: 125,
        y: 28,
        width: 37,
        height: 5,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'if_sequence_no',
        key: 'sequence_no',
        label: 'Sıra No',
        x: 163,
        y: 28,
        width: 37,
        height: 5,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'if_date',
        key: 'date',
        label: 'Tarih',
        x: 125,
        y: 34,
        width: 37,
        height: 5,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'if_time',
        key: 'time',
        label: 'Saat',
        x: 163,
        y: 34,
        width: 37,
        height: 5,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'if_dispatch_date',
        key: 'dispatch_date',
        label: 'Sevk Tarihi',
        x: 125,
        y: 40,
        width: 37,
        height: 5,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'if_dispatch_time',
        key: 'dispatch_time',
        label: 'Sevk Saati',
        x: 163,
        y: 40,
        width: 37,
        height: 5,
        fontSize: '8',
      ),

      // Müşteri Bilgileri
      LayoutElement(
        id: 'if_customer_name',
        key: 'customer_name',
        label: 'Sayın',
        x: 10,
        y: 45,
        width: 95,
        height: 8,
        fontSize: '11',
        fontWeight: 'bold',
      ),
      LayoutElement(
        id: 'if_customer_address',
        key: 'customer_address',
        label: 'Adres',
        x: 10,
        y: 54,
        width: 95,
        height: 10,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'if_tax_office',
        key: 'tax_office',
        label: 'V.D.',
        x: 10,
        y: 65,
        width: 47,
        height: 5,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'if_tax_no',
        key: 'tax_no',
        label: 'VKN',
        x: 58,
        y: 65,
        width: 47,
        height: 5,
        fontSize: '8',
      ),

      // Sevk Bilgileri
      LayoutElement(
        id: 'if_driver_name',
        key: 'driver_name',
        label: 'Şoför',
        x: 125,
        y: 50,
        width: 75,
        height: 5,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'if_driver_tckn',
        key: 'driver_tckn',
        label: 'TCKN',
        x: 125,
        y: 56,
        width: 37,
        height: 5,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'if_vehicle_plate',
        key: 'vehicle_plate',
        label: 'Plaka',
        x: 163,
        y: 56,
        width: 37,
        height: 5,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'if_delivery_address',
        key: 'delivery_address',
        label: 'Sevk Adresi',
        x: 125,
        y: 62,
        width: 75,
        height: 10,
        fontSize: '8',
      ),

      // Ürün Tablosu
      LayoutElement(
        id: 'if_items_table',
        key: 'items_table_extended',
        label: 'Ürün Tablosu',
        x: 10,
        y: 78,
        width: 190,
        height: 105,
        fontSize: '9',
      ),

      // Toplamlar (Resimdeki sırayla)
      LayoutElement(
        id: 'if_subtotal',
        key: 'subtotal',
        label: 'Mal Hizmet Toplamı',
        x: 130,
        y: 188,
        width: 70,
        height: 5,
        fontSize: '9',
        alignment: 'right',
      ),
      LayoutElement(
        id: 'if_discount',
        key: 'discount_total',
        label: 'Toplam İskonto',
        x: 130,
        y: 194,
        width: 70,
        height: 5,
        fontSize: '9',
        alignment: 'right',
      ),
      LayoutElement(
        id: 'if_taxable',
        key: 'taxable_amount',
        label: 'KDV Matrahı',
        x: 130,
        y: 200,
        width: 70,
        height: 5,
        fontSize: '9',
        alignment: 'right',
      ),
      LayoutElement(
        id: 'if_kdv_total',
        key: 'vat_total',
        label: 'Hesaplanan KDV',
        x: 130,
        y: 206,
        width: 70,
        height: 5,
        fontSize: '9',
        alignment: 'right',
      ),

      // ÖTV, ÖİV, Tevkifat
      LayoutElement(
        id: 'if_otv',
        key: 'otv_amount',
        label: 'ÖTV',
        x: 10,
        y: 212,
        width: 40,
        height: 5,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'if_oiv',
        key: 'oiv_amount',
        label: 'ÖİV',
        x: 55,
        y: 212,
        width: 40,
        height: 5,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'if_tevkifat',
        key: 'tevkifat_amount',
        label: 'Tevkifat',
        x: 100,
        y: 212,
        width: 40,
        height: 5,
        fontSize: '8',
      ),

      // GENEL TOPLAM
      LayoutElement(
        id: 'if_grand_total',
        key: 'grand_total',
        label: 'GENEL TOPLAM',
        x: 130,
        y: 214,
        width: 70,
        height: 10,
        fontSize: '12',
        fontWeight: 'bold',
        alignment: 'right',
      ),
      LayoutElement(
        id: 'if_total_text',
        key: 'total_as_text',
        label: 'Yalnız',
        x: 10,
        y: 228,
        width: 140,
        height: 8,
        fontSize: '9',
      ),

      // Teslim Bilgileri
      LayoutElement(
        id: 'if_delivered_by',
        key: 'delivered_by',
        label: 'Teslim Eden',
        x: 10,
        y: 245,
        width: 60,
        height: 25,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'if_received_by',
        key: 'received_by',
        label: 'Teslim Alan',
        x: 75,
        y: 245,
        width: 60,
        height: 25,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'if_signature',
        key: 'delivery_signature',
        label: 'İmza',
        x: 140,
        y: 245,
        width: 60,
        height: 25,
        fontSize: '9',
      ),

      // Not
      LayoutElement(
        id: 'if_note',
        key: 'note',
        label: 'Açıklama',
        x: 10,
        y: 275,
        width: 190,
        height: 15,
        fontSize: '8',
      ),
    ];

    final sablon = YazdirmaSablonuModel(
      name: 'İrsaliyeli Fatura',
      docType: 'invoice',
      paperSize: 'A4',
      layout: layout,
      isDefault: false,
      isLandscape: false,
    );

    await _dbServisi.sablonEkle(sablon);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3. SEVK İRSALİYESİ ŞABLONU (A4 - 210x297mm)
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> sevkIrsaliyesiSablonuEkle() async {
    final layout = <LayoutElement>[
      // Satıcı Bilgileri
      LayoutElement(
        id: 'si_seller_name',
        key: 'seller_name',
        label: 'Firma Unvanı',
        x: 10,
        y: 10,
        width: 90,
        height: 10,
        fontSize: '12',
        fontWeight: 'bold',
      ),
      LayoutElement(
        id: 'si_seller_address',
        key: 'seller_address',
        label: 'Adres',
        x: 10,
        y: 21,
        width: 90,
        height: 12,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'si_seller_tax_office',
        key: 'seller_tax_office',
        label: 'V.D.',
        x: 10,
        y: 34,
        width: 45,
        height: 5,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'si_seller_tax_no',
        key: 'seller_tax_no',
        label: 'VKN',
        x: 56,
        y: 34,
        width: 44,
        height: 5,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'si_seller_phone',
        key: 'seller_phone',
        label: 'Tel',
        x: 10,
        y: 40,
        width: 45,
        height: 5,
        fontSize: '8',
      ),

      // İrsaliye Başlık
      LayoutElement(
        id: 'si_title',
        key: 'custom_text',
        label: 'SEVK İRSALİYESİ',
        x: 120,
        y: 10,
        width: 80,
        height: 12,
        fontSize: '14',
        fontWeight: 'bold',
        alignment: 'center',
      ),
      LayoutElement(
        id: 'si_dispatch_number',
        key: 'dispatch_number',
        label: 'İrsaliye No',
        x: 120,
        y: 24,
        width: 80,
        height: 6,
        fontSize: '10',
        fontWeight: 'bold',
        alignment: 'center',
      ),
      LayoutElement(
        id: 'si_dispatch_date',
        key: 'dispatch_date',
        label: 'Tarih',
        x: 120,
        y: 32,
        width: 40,
        height: 5,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'si_dispatch_time',
        key: 'dispatch_time',
        label: 'Saat',
        x: 161,
        y: 32,
        width: 39,
        height: 5,
        fontSize: '9',
      ),

      // Alıcı Bilgileri
      LayoutElement(
        id: 'si_customer_label',
        key: 'custom_text',
        label: 'TESLİM EDİLECEK',
        x: 10,
        y: 52,
        width: 50,
        height: 6,
        fontSize: '9',
        fontWeight: 'bold',
      ),
      LayoutElement(
        id: 'si_customer_name',
        key: 'customer_name',
        label: 'Firma/Kişi Adı',
        x: 10,
        y: 59,
        width: 90,
        height: 8,
        fontSize: '11',
        fontWeight: 'bold',
      ),
      LayoutElement(
        id: 'si_delivery_address',
        key: 'delivery_address',
        label: 'Teslimat Adresi',
        x: 10,
        y: 68,
        width: 90,
        height: 15,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'si_customer_phone',
        key: 'customer_phone',
        label: 'Tel',
        x: 10,
        y: 84,
        width: 45,
        height: 5,
        fontSize: '8',
      ),

      // Taşıma/Sevk Bilgileri
      LayoutElement(
        id: 'si_driver_label',
        key: 'custom_text',
        label: 'TAŞIMA BİLGİLERİ',
        x: 120,
        y: 45,
        width: 80,
        height: 6,
        fontSize: '9',
        fontWeight: 'bold',
      ),
      LayoutElement(
        id: 'si_driver_name',
        key: 'driver_name',
        label: 'Şoför Adı Soyadı',
        x: 120,
        y: 52,
        width: 80,
        height: 6,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'si_driver_tckn',
        key: 'driver_tckn',
        label: 'Şoför TCKN',
        x: 120,
        y: 59,
        width: 80,
        height: 6,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'si_vehicle_plate',
        key: 'vehicle_plate',
        label: 'Araç Plakası',
        x: 120,
        y: 66,
        width: 80,
        height: 8,
        fontSize: '11',
        fontWeight: 'bold',
      ),
      LayoutElement(
        id: 'si_shipment_address',
        key: 'shipment_address',
        label: 'Sevk Adresi',
        x: 120,
        y: 75,
        width: 80,
        height: 12,
        fontSize: '8',
      ),

      // Ürün Tablosu
      LayoutElement(
        id: 'si_items_table',
        key: 'items_table',
        label: 'Malzeme Listesi',
        x: 10,
        y: 95,
        width: 190,
        height: 140,
        fontSize: '9',
      ),

      // İrsaliye Notu
      LayoutElement(
        id: 'si_waybill_note',
        key: 'waybill_note',
        label: 'Not',
        x: 10,
        y: 240,
        width: 120,
        height: 20,
        fontSize: '8',
      ),

      // Teslim Alanları
      LayoutElement(
        id: 'si_delivered_label',
        key: 'custom_text',
        label: 'TESLİM EDEN',
        x: 10,
        y: 265,
        width: 60,
        height: 5,
        fontSize: '8',
        fontWeight: 'bold',
      ),
      LayoutElement(
        id: 'si_delivered_by',
        key: 'delivered_by',
        label: 'Ad Soyad / İmza',
        x: 10,
        y: 271,
        width: 60,
        height: 20,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'si_received_label',
        key: 'custom_text',
        label: 'TESLİM ALAN',
        x: 140,
        y: 265,
        width: 60,
        height: 5,
        fontSize: '8',
        fontWeight: 'bold',
      ),
      LayoutElement(
        id: 'si_received_by',
        key: 'received_by',
        label: 'Ad Soyad / İmza',
        x: 140,
        y: 271,
        width: 60,
        height: 20,
        fontSize: '9',
      ),
    ];

    final sablon = YazdirmaSablonuModel(
      name: 'Sevk İrsaliyesi',
      docType: 'receipt',
      paperSize: 'A4',
      layout: layout,
      isDefault: false,
      isLandscape: false,
    );

    await _dbServisi.sablonEkle(sablon);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 4. SATIŞ FİŞİ / ÖKC FİŞİ (THERMAL80 - 80x200mm) - Market Fişi
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> satisFisiSablonuEkle() async {
    final layout = <LayoutElement>[
      // ─────────────────────────────────────────────────────────────────────
      // FİRMA BİLGİLERİ (Üst Kısım)
      // ─────────────────────────────────────────────────────────────────────
      LayoutElement(
        id: 'fis_seller_name',
        key: 'seller_name',
        label: 'MARKET ADI',
        x: 5,
        y: 5,
        width: 70,
        height: 10,
        fontSize: '14',
        fontWeight: 'bold',
        alignment: 'center',
      ),
      LayoutElement(
        id: 'fis_seller_address',
        key: 'seller_address',
        label: 'Adres',
        x: 5,
        y: 16,
        width: 70,
        height: 12,
        fontSize: '8',
        alignment: 'center',
      ),
      LayoutElement(
        id: 'fis_seller_phone',
        key: 'seller_phone',
        label: 'Tel',
        x: 5,
        y: 29,
        width: 70,
        height: 5,
        fontSize: '8',
        alignment: 'center',
      ),
      LayoutElement(
        id: 'fis_seller_tax_office',
        key: 'seller_tax_office',
        label: 'V.D.',
        x: 5,
        y: 35,
        width: 35,
        height: 5,
        fontSize: '7',
      ),
      LayoutElement(
        id: 'fis_seller_tax_no',
        key: 'seller_tax_no',
        label: 'VKN',
        x: 41,
        y: 35,
        width: 34,
        height: 5,
        fontSize: '7',
      ),

      // Ayırıcı çizgi
      LayoutElement(
        id: 'fis_line1',
        key: 'horizontal_line',
        label: '--------------------------------',
        x: 5,
        y: 42,
        width: 70,
        height: 3,
        fontSize: '8',
        alignment: 'center',
      ),

      // ─────────────────────────────────────────────────────────────────────
      // FİŞ BİLGİLERİ
      // ─────────────────────────────────────────────────────────────────────
      LayoutElement(
        id: 'fis_date',
        key: 'date',
        label: 'Tarih',
        x: 5,
        y: 47,
        width: 35,
        height: 5,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'fis_time',
        key: 'time',
        label: 'Saat',
        x: 41,
        y: 47,
        width: 34,
        height: 5,
        fontSize: '8',
        alignment: 'right',
      ),
      LayoutElement(
        id: 'fis_sequence_no',
        key: 'sequence_no',
        label: 'Fiş No',
        x: 5,
        y: 53,
        width: 35,
        height: 5,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'fis_cashier',
        key: 'cashier_name',
        label: 'Kasiyer',
        x: 41,
        y: 53,
        width: 34,
        height: 5,
        fontSize: '8',
        alignment: 'right',
      ),

      // Ayırıcı
      LayoutElement(
        id: 'fis_line2',
        key: 'horizontal_line',
        label: '================================',
        x: 5,
        y: 60,
        width: 70,
        height: 3,
        fontSize: '8',
        alignment: 'center',
      ),

      // ─────────────────────────────────────────────────────────────────────
      // ÜRÜN LİSTESİ
      // ─────────────────────────────────────────────────────────────────────
      LayoutElement(
        id: 'fis_items_table',
        key: 'items_table',
        label: 'Ürünler',
        x: 5,
        y: 65,
        width: 70,
        height: 60,
        fontSize: '8',
      ),

      // Ayırıcı
      LayoutElement(
        id: 'fis_line3',
        key: 'horizontal_line',
        label: '--------------------------------',
        x: 5,
        y: 127,
        width: 70,
        height: 3,
        fontSize: '8',
        alignment: 'center',
      ),

      // ─────────────────────────────────────────────────────────────────────
      // TOPLAM VE VERGİ BİLGİLERİ (Resimdeki sırayla)
      // ─────────────────────────────────────────────────────────────────────
      LayoutElement(
        id: 'fis_subtotal',
        key: 'subtotal',
        label: 'Mal Hizmet Toplamı',
        x: 5,
        y: 132,
        width: 70,
        height: 5,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'fis_discount',
        key: 'discount_total',
        label: 'Toplam İskonto',
        x: 5,
        y: 138,
        width: 70,
        height: 5,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'fis_taxable',
        key: 'taxable_amount',
        label: 'KDV Matrahı',
        x: 5,
        y: 144,
        width: 70,
        height: 5,
        fontSize: '9',
      ),
      LayoutElement(
        id: 'fis_vat_total',
        key: 'vat_total',
        label: 'Hesaplanan KDV',
        x: 5,
        y: 150,
        width: 70,
        height: 5,
        fontSize: '9',
      ),

      // GENEL TOPLAM
      LayoutElement(
        id: 'fis_grand_total',
        key: 'grand_total',
        label: 'GENEL TOPLAM',
        x: 5,
        y: 158,
        width: 70,
        height: 10,
        fontSize: '14',
        fontWeight: 'bold',
        alignment: 'center',
      ),

      // Ayırıcı
      LayoutElement(
        id: 'fis_line4',
        key: 'horizontal_line',
        label: '================================',
        x: 5,
        y: 170,
        width: 70,
        height: 3,
        fontSize: '8',
        alignment: 'center',
      ),

      // ─────────────────────────────────────────────────────────────────────
      // ÖDEME BİLGİLERİ
      // ─────────────────────────────────────────────────────────────────────
      LayoutElement(
        id: 'fis_payment_type',
        key: 'payment_type',
        label: 'Ödeme',
        x: 5,
        y: 175,
        width: 35,
        height: 5,
        fontSize: '9',
        fontWeight: 'bold',
      ),
      LayoutElement(
        id: 'fis_cash_amount',
        key: 'cash_amount',
        label: 'Nakit',
        x: 5,
        y: 181,
        width: 35,
        height: 4,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'fis_card_amount',
        key: 'card_amount',
        label: 'Kart',
        x: 41,
        y: 181,
        width: 34,
        height: 4,
        fontSize: '8',
      ),
      LayoutElement(
        id: 'fis_change',
        key: 'change_amount',
        label: 'Para Üstü',
        x: 5,
        y: 186,
        width: 70,
        height: 5,
        fontSize: '9',
      ),

      // ─────────────────────────────────────────────────────────────────────
      // MALİ BİLGİLER
      // ─────────────────────────────────────────────────────────────────────
      LayoutElement(
        id: 'fis_fisc_symbol',
        key: 'fisc_symbol',
        label: 'MF',
        x: 5,
        y: 193,
        width: 10,
        height: 5,
        fontSize: '9',
        fontWeight: 'bold',
      ),
      LayoutElement(
        id: 'fis_device_serial',
        key: 'device_serial',
        label: 'Sicil No',
        x: 16,
        y: 193,
        width: 30,
        height: 5,
        fontSize: '7',
      ),
      LayoutElement(
        id: 'fis_z_report',
        key: 'z_report_no',
        label: 'Z',
        x: 47,
        y: 193,
        width: 28,
        height: 5,
        fontSize: '7',
      ),
      LayoutElement(
        id: 'fis_eft_no',
        key: 'eft_receipt_no',
        label: 'EKÜ',
        x: 5,
        y: 199,
        width: 70,
        height: 4,
        fontSize: '7',
      ),

      // QR Kod
      LayoutElement(
        id: 'fis_qr',
        key: 'receipt_qr',
        label: 'QR',
        x: 20,
        y: 205,
        width: 40,
        height: 40,
        fontSize: '8',
        alignment: 'center',
      ),

      // Teşekkür Mesajı
      LayoutElement(
        id: 'fis_thanks',
        key: 'note',
        label: 'Bizi tercih ettiğiniz için teşekkür ederiz.',
        x: 5,
        y: 248,
        width: 70,
        height: 8,
        fontSize: '8',
        alignment: 'center',
      ),
    ];

    final sablon = YazdirmaSablonuModel(
      name: 'Satış Fişi (Market)',
      docType: 'receipt',
      paperSize: 'Thermal80',
      layout: layout,
      isDefault: true,
      isLandscape: false,
    );

    await _dbServisi.sablonEkle(sablon);
  }
}
