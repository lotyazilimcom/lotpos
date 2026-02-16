import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../../servisler/bankalar_veritabani_servisi.dart';
import '../../servisler/satisyap_veritabani_servisleri.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../servisler/oturum_servisi.dart';
import '../../servisler/yazdirma_veritabani_servisi.dart';
import '../../yardimcilar/yazdirma/dinamik_yazdirma_servisi.dart';
import '../ayarlar/yazdirma_ayarlari/modeller/yazdirma_sablonu_model.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../bilesenler/tek_tarih_secici_dialog.dart';
import '../../bilesenler/akilli_aciklama_input.dart';
import '../ortak/print_preview_screen.dart';
import 'modeller/transaction_item.dart';

class SatisSonrasiYazdirSayfasi extends StatefulWidget {
  final String entegrasyonRef;
  final String cariAdi;
  final String cariKodu;
  final double genelToplam;
  final String paraBirimi;
  final String initialFaturaNo;
  final String initialIrsaliyeNo;
  final DateTime initialTarih;
  final List<Map<String, dynamic>> items; // Ürün listesi (yazdırma için)

  const SatisSonrasiYazdirSayfasi({
    super.key,
    required this.entegrasyonRef,
    required this.cariAdi,
    required this.cariKodu,
    required this.genelToplam,
    required this.paraBirimi,
    this.initialFaturaNo = '',
    this.initialIrsaliyeNo = '',
    required this.initialTarih,
    required this.items,
  });

  @override
  State<SatisSonrasiYazdirSayfasi> createState() =>
      _SatisSonrasiYazdirSayfasiState();
}

class _SatisSonrasiYazdirSayfasiState extends State<SatisSonrasiYazdirSayfasi> {
  final _formKey = GlobalKey<FormState>();

  // Kontrolcüler
  final _irsaliyeNoController = TextEditingController();
  final _faturaNoController = TextEditingController();
  final _irsaliyeTarihiController = TextEditingController();
  final _fiiliSevkTarihiController = TextEditingController();
  final _faturaTarihiController = TextEditingController();
  final _duzenlemeTarihiController = TextEditingController();
  final _duzenlemeSaatiController = TextEditingController();
  final _siparisNoController = TextEditingController();
  final _sonOdemeTarihiController = TextEditingController();

  final List<TextEditingController> _aciklamaControllers = List.generate(
    5,
    (_) => TextEditingController(),
  );

  DateTime _irsaliyeTarihi = DateTime.now();
  DateTime _fiiliSevkTarihi = DateTime.now();
  DateTime _faturaTarihi = DateTime.now();
  DateTime _duzenlemeTarihi = DateTime.now();
  DateTime _sonOdemeTarihi = DateTime.now();

  List<YazdirmaSablonuModel> _sablonlar = [];
  YazdirmaSablonuModel? _secilenSablon;
  bool _yukleniyor = true;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  @override
  void initState() {
    super.initState();
    _irsaliyeNoController.text = widget.initialIrsaliyeNo;
    _faturaNoController.text = widget.initialFaturaNo;

    _irsaliyeTarihi = widget.initialTarih;
    _fiiliSevkTarihi = widget.initialTarih;
    _faturaTarihi = widget.initialTarih;
    _duzenlemeTarihi = widget.initialTarih;
    _sonOdemeTarihi = widget.initialTarih;

    _updateDateControllers();
    _duzenlemeSaatiController.text = DateFormat('HH:mm').format(DateTime.now());

    _sablonlariYukle();
  }

  void _updateDateControllers() {
    _irsaliyeTarihiController.text = DateFormat(
      'dd.MM.yyyy',
    ).format(_irsaliyeTarihi);
    _fiiliSevkTarihiController.text = DateFormat(
      'dd.MM.yyyy',
    ).format(_fiiliSevkTarihi);
    _faturaTarihiController.text = DateFormat(
      'dd.MM.yyyy',
    ).format(_faturaTarihi);
    _duzenlemeTarihiController.text = DateFormat(
      'dd.MM.yyyy',
    ).format(_duzenlemeTarihi);
    _sonOdemeTarihiController.text = DateFormat(
      'dd.MM.yyyy',
    ).format(_sonOdemeTarihi);
  }

  Future<void> _sablonlariYukle() async {
    try {
      final sablonlar = await YazdirmaVeritabaniServisi().sablonlariGetir();
      GenelAyarlarModel genelAyarlar = GenelAyarlarModel();
      try {
        genelAyarlar = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      } catch (e) {
        debugPrint('Genel ayarlar alınamadı: $e');
      }
      setState(() {
        _sablonlar = sablonlar;
        _genelAyarlar = genelAyarlar;
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() => _yukleniyor = false);
      if (!mounted) return;
      MesajYardimcisi.hataGoster(
        context,
        tr('print_after_sale.template_error'),
      );
    }
  }

  Future<void> _tarihSec(BuildContext context, String tip) async {
    DateTime initial;
    switch (tip) {
      case 'irsaliye':
        initial = _irsaliyeTarihi;
        break;
      case 'sevk':
        initial = _fiiliSevkTarihi;
        break;
      case 'fatura':
        initial = _faturaTarihi;
        break;
      case 'duzenleme':
        initial = _duzenlemeTarihi;
        break;
      case 'vade':
        initial = _sonOdemeTarihi;
        break;
      default:
        initial = DateTime.now();
    }

    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) =>
          TekTarihSeciciDialog(initialDate: initial, title: tr('common.date')),
    );

    if (picked != null) {
      if (!mounted) return;
      setState(() {
        switch (tip) {
          case 'irsaliye':
            _irsaliyeTarihi = picked;
            break;
          case 'sevk':
            _fiiliSevkTarihi = picked;
            break;
          case 'fatura':
            _faturaTarihi = picked;
            break;
          case 'duzenleme':
            _duzenlemeTarihi = picked;
            break;
          case 'vade':
            _sonOdemeTarihi = picked;
            break;
        }
        _updateDateControllers();
      });
    }
  }

  Future<void> _yazdir() async {
    if (_secilenSablon == null) {
      MesajYardimcisi.uyariGoster(
        context,
        tr('print_after_sale.error.no_template_selected'),
      );
      return;
    }

    // Önce veritabanını güncelle
    await _guncelle();

    // Bakiyeleri çek ve hesapla
    double currentBalance = 0;
    double previousBalance = 0;
    String balanceCurrency = widget.paraBirimi;
    try {
      final cari = await CariHesaplarVeritabaniServisi().cariHesapGetirByKod(
        widget.cariKodu,
      );
      if (cari != null) {
        balanceCurrency = cari.paraBirimi;
        // bakiye_durumu 'Borç' ise bakiye pozitiftir, 'Alacak' ise negatif gibi düşünülür.
        // Ama modelde bakiyeBorc ve bakiyeAlacak ayrı ayrı.
        // Genelde Net Bakiye = Borç - Alacak.
        currentBalance = cari.bakiyeBorc - cari.bakiyeAlacak;
        // Önceki bakiye = Şu anki bakiye - bu işlemin tutarı (çünkü işlem veritabanına işlendi)
        previousBalance = currentBalance - widget.genelToplam;
      }
    } catch (e) {
      debugPrint('Bakiye çekme hatası: $e');
    }

    try {
      final sablon = _secilenSablon!;
      final printData = await _hazirlaYazdirmaVerisi(
        previousBalance: previousBalance,
        currentBalance: currentBalance,
        balanceCurrency: balanceCurrency,
      );

      if (!mounted) return;

      final PdfPageFormat baseFormat = _templateBasePageFormat(sablon);

      // [2026] Generate Toggles
      final uniqueKeys = <String>{};
      final toggles = <CustomContentToggle>[];
      for (final el in sablon.layout) {
        if (uniqueKeys.add(el.key)) {
          // Use 'label' if available, otherwise 'key'
          String label = el.label.isNotEmpty ? el.label : el.key;
          toggles.add(CustomContentToggle(key: el.key, label: label));
        }
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PrintPreviewScreen(
            title: sablon.name,
            headers: const [],
            data: const [],
            pdfBuilder: ({required format, required margins, toggles}) async {
              final doc = await DinamikYazdirmaServisi().pdfOlustur(
                sablon: sablon,
                veri: printData,
                formatOverride: format,
                margin: margins,
                visibleElements: toggles,
              );
              return doc.save();
            },
            initialPageFormat: baseFormat,
            initialLandscape: sablon.isLandscape,
            initialMarginType: 'none',
            lockPaperSize: false,
            lockOrientation: false,
            lockMargins: false,
            enableExcelExport: false,
            showHeaderFooterOption: false,
            showBackgroundGraphicsOption: false,
            customToggles: toggles,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      MesajYardimcisi.hataGoster(
        context,
        tr('print.error.during_print').replaceAll('{error}', e.toString()),
      );
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _fmtMoney(num value, {int? decimalDigits}) {
    return FormatYardimcisi.sayiFormatlaOndalikli(
      value,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: decimalDigits ?? _genelAyarlar.fiyatOndalik,
    );
  }

  String _fmtQuantity(num value) {
    // Miktar: ondalık varsa göster, yoksa tam sayı (örn: 12 / 12,25)
    return FormatYardimcisi.sayiFormatla(
      value,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.miktarOndalik,
    );
  }

  String _fmtRate(num value) {
    return FormatYardimcisi.sayiFormatlaOran(
      value,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.kurOndalik,
    );
  }

  String _currencyDisplay(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return '';
    if (!_genelAyarlar.sembolGoster) return normalized;
    return FormatYardimcisi.paraBirimiSembol(normalized);
  }

  String _formatAddress({
    required String address,
    required String district,
    required String city,
    required String postalCode,
  }) {
    final parts = <String>[
      address.trim(),
      district.trim(),
      city.trim(),
      postalCode.trim(),
    ].where((p) => p.isNotEmpty).toList();
    return parts.join(' ');
  }

  String _firstShippingAddress(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map) {
          final adr = first['adres']?.toString() ?? '';
          final ilce = first['ilce']?.toString() ?? '';
          final sehir = first['sehir']?.toString() ?? '';
          return _formatAddress(
            address: adr,
            district: ilce,
            city: sehir,
            postalCode: '',
          );
        }
      }
    } catch (_) {}
    return '';
  }

  PdfPageFormat _templateBasePageFormat(YazdirmaSablonuModel template) {
    final mm = PdfPageFormat.mm;
    return switch (template.paperSize) {
      'A4' => PdfPageFormat.a4,
      'A5' => PdfPageFormat.a5,
      'Continuous' => PdfPageFormat(240 * mm, 280 * mm),
      'Thermal80' => PdfPageFormat(80 * mm, 200 * mm),
      'Thermal58' => PdfPageFormat(58 * mm, 150 * mm),
      _ => PdfPageFormat(
        (template.customWidth ?? 210) * mm,
        (template.customHeight ?? 297) * mm,
      ),
    };
  }

  Future<
    ({List<Map<String, dynamic>> shipments, List<Map<String, dynamic>> items})
  >
  _entegrasyonItemsGetir() async {
    try {
      final shipments = await CariHesaplarVeritabaniServisi()
          .entegrasyonShipmentsGetir(widget.entegrasyonRef);
      final items = <Map<String, dynamic>>[];
      for (final shipment in shipments) {
        final raw = shipment['items'];
        if (raw is List) {
          for (final it in raw) {
            if (it is Map) items.add(Map<String, dynamic>.from(it));
          }
        } else if (raw is Map) {
          items.add(Map<String, dynamic>.from(raw));
        }
      }
      if (items.isNotEmpty) return (shipments: shipments, items: items);
      return (shipments: shipments, items: widget.items);
    } catch (e) {
      debugPrint('Entegrasyon kalemleri alınamadı: $e');
    }
    return (shipments: const <Map<String, dynamic>>[], items: widget.items);
  }

  Future<Map<String, dynamic>> _hazirlaYazdirmaVerisi({
    required double previousBalance,
    required double currentBalance,
    required String balanceCurrency,
  }) async {
    final sirket = OturumServisi().aktifSirket;
    final headerLines = (sirket?.ustBilgiSatirlari.isNotEmpty ?? false)
        ? sirket!.ustBilgiSatirlari
        : (sirket?.basliklar ?? const <String>[]);

    final cariServisi = CariHesaplarVeritabaniServisi();
    final cari = await cariServisi.cariHesapGetirByKod(widget.cariKodu);

    final shipmentData = await _entegrasyonItemsGetir();
    final shipments = shipmentData.shipments;
    final itemsRaw = shipmentData.items;

    final cariIslem = await cariServisi.cariIslemGetirByRef(
      widget.entegrasyonRef,
    );
    final odemeBilgisi = await cariServisi.entegrasyonOdemeBilgisiGetir(
      widget.entegrasyonRef,
    );

    final balanceCurrencySymbol = _currencyDisplay(balanceCurrency);
    final docCurrencySymbol = _currencyDisplay(widget.paraBirimi);

    final txItems = <TransactionItem>[];
    for (final raw in itemsRaw) {
      final m = Map<String, dynamic>.from(raw);
      final qty = _toDouble(m['quantity']);
      final unitCost = _toDouble(
        m['unitCost'] ??
            m['unit_cost'] ??
            m['price'] ??
            m['unitPrice'] ??
            m['unit_price'],
      );
      txItems.add(
        TransactionItem(
          code: m['code']?.toString() ?? '',
          name: m['name']?.toString() ?? '',
          barcode: m['barcode']?.toString() ?? '',
          unit: m['unit']?.toString() ?? '',
          quantity: qty,
          unitPrice: unitCost,
          currency: m['currency']?.toString() ?? widget.paraBirimi,
          exchangeRate: _toDouble(m['exchangeRate'] ?? 1),
          vatRate: _toDouble(m['vatRate']),
          discountRate: _toDouble(m['discountRate']),
          warehouseId: _toInt(m['warehouseId']),
          warehouseName: m['warehouseName']?.toString() ?? '',
          vatIncluded: false,
          otvRate: _toDouble(m['otvRate']),
          otvIncluded: false,
          oivRate: _toDouble(m['oivRate']),
          oivIncluded: false,
          kdvTevkifatOrani: _toDouble(m['kdvTevkifatOrani']),
          serialNumber: m['serialNumber']?.toString(),
        ),
      );
    }

    double subtotal = 0;
    double discountTotal = 0;
    double taxableAmount = 0;
    double vatTotal = 0;
    double otvAmount = 0;
    double oivAmount = 0;
    double tevkifatAmount = 0;
    double grandTotal = 0;

    for (final it in txItems) {
      subtotal += (it.quantity * it.netUnitPrice);
      discountTotal += it.discountAmount;
      taxableAmount += it.vatBase;
      vatTotal += it.vatAmount;
      otvAmount += it.otvAmount;
      oivAmount += it.oivAmount;
      tevkifatAmount += it.kdvTevkifatAmount;
      grandTotal += it.total;
    }

    // VAT breakdown (up to 6 groups)
    final Map<double, ({double base, double amount})> vatGroups = {};
    for (final it in txItems) {
      final key = it.vatRate;
      final current = vatGroups[key];
      vatGroups[key] = (
        base: (current?.base ?? 0) + it.vatBase,
        amount: (current?.amount ?? 0) + it.vatAmount,
      );
    }
    final sortedRates = vatGroups.keys.toList()..sort();

    final itemLineNo = <String>[];
    final itemName = <String>[];
    final itemCode = <String>[];
    final itemBarcode = <String>[];
    final itemDescription = <String>[];
    final itemQuantity = <String>[];
    final itemUnit = <String>[];
    final itemDiscountRate = <String>[];
    final itemDiscountAmount = <String>[];
    final itemVatRate = <String>[];
    final itemOtvRate = <String>[];
    final itemOivRate = <String>[];
    final itemTevkifatRate = <String>[];
    final itemUnitPriceExcl = <String>[];
    final itemUnitPriceIncl = <String>[];
    final itemTotalExcl = <String>[];
    final itemTotalIncl = <String>[];
    final itemCurrency = <String>[];

    for (int i = 0; i < txItems.length; i++) {
      final it = txItems[i];
      itemLineNo.add('${i + 1}');
      itemName.add(it.name);
      itemCode.add(it.code);
      itemBarcode.add(it.barcode);
      itemDescription.add(
        (it.serialNumber?.trim().isNotEmpty ?? false)
            ? 'IMEI/SN: ${it.serialNumber}'
            : (it.warehouseName.trim().isNotEmpty ? it.warehouseName : '-'),
      );
      itemQuantity.add(_fmtQuantity(it.quantity));
      itemUnit.add(it.unit);
      itemDiscountRate.add(_fmtRate(it.discountRate));
      itemDiscountAmount.add(_fmtMoney(it.discountAmount));
      itemVatRate.add(_fmtRate(it.vatRate));
      itemOtvRate.add(_fmtRate(it.otvRate));
      itemOivRate.add(_fmtRate(it.oivRate));
      itemTevkifatRate.add(_fmtRate(it.kdvTevkifatOrani * 100));
      itemUnitPriceExcl.add(_fmtMoney(it.netUnitPrice));
      itemUnitPriceIncl.add(
        it.quantity == 0 ? '' : _fmtMoney(it.total / it.quantity),
      );
      // Kullanıcı beklentisi: satır toplamında vergiler dahil tutar
      itemTotalExcl.add(_fmtMoney(it.total));
      itemTotalIncl.add(_fmtMoney(it.total));
      itemCurrency.add(_currencyDisplay(it.currency));
    }

    ({String serial, String sequence}) splitSerialSequence(String value) {
      final v = value.trim();
      if (v.isEmpty) return (serial: '', sequence: '');

      // Common formats: AA/12345, AA-12345, AA 12345
      for (final sep in const ['/', '-', ' ']) {
        if (!v.contains(sep)) continue;
        final parts = v
            .split(sep)
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
        if (parts.length >= 2) {
          return (serial: parts.first, sequence: parts.sublist(1).join(sep));
        }
      }

      // Fallback: leading letters => serial, remainder => sequence
      final m = RegExp(r'^([A-Za-z]+)\\s*(.+)$').firstMatch(v);
      if (m != null) return (serial: m.group(1)!, sequence: m.group(2)!);

      return (serial: '', sequence: v);
    }

    DateTime? toDateTime(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      return DateTime.tryParse(raw.toString());
    }

    final invoiceNoRaw = _faturaNoController.text.trim();
    final serialSeq = splitSerialSequence(invoiceNoRaw);
    final String serialNo = serialSeq.serial.trim().isEmpty
        ? '-'
        : serialSeq.serial.trim();
    final String sequenceNo = serialSeq.sequence.trim().isEmpty
        ? (invoiceNoRaw.isEmpty ? '-' : invoiceNoRaw)
        : serialSeq.sequence.trim();

    final DateTime baseTime =
        toDateTime(shipments.isNotEmpty ? shipments.first['date'] : null) ??
        toDateTime(cariIslem?['date']) ??
        DateTime.now();
    final String dispatchTime = DateFormat('HH:mm').format(baseTime);

    final String validityDate = _sonOdemeTarihiController.text.trim().isNotEmpty
        ? _sonOdemeTarihiController.text.trim()
        : (_faturaTarihiController.text.trim().isNotEmpty
              ? _faturaTarihiController.text.trim()
              : DateFormat('dd.MM.yyyy').format(baseTime));

    final inputNotes = _aciklamaControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList(growable: false);

    String noteText = inputNotes.isNotEmpty ? inputNotes.join('\\n') : '';
    if (noteText.isEmpty) {
      noteText = (cariIslem?['description']?.toString() ?? '').trim();
    }
    if (noteText.isEmpty && shipments.isNotEmpty) {
      noteText = (shipments.first['description']?.toString() ?? '').trim();
    }
    if (noteText.isEmpty) noteText = '-';

    String buildItemsTable({required bool extended}) {
      if (txItems.isEmpty) return '-';
      final lines = <String>[];
      for (int i = 0; i < txItems.length; i++) {
        final it = txItems[i];
        final qty = _fmtQuantity(it.quantity);
        final unit = it.unit.trim();
        final cur = _currencyDisplay(it.currency);
        final total = _fmtMoney(it.total);

        if (!extended) {
          lines.add(
            '${i + 1}) ${it.name} | $qty${unit.isEmpty ? '' : ' $unit'} | $total $cur',
          );
        } else {
          final unitPrice = _fmtMoney(it.netUnitPrice);
          final disc = _fmtRate(it.discountRate);
          final vat = _fmtRate(it.vatRate);
          lines.add(
            '${i + 1}) ${it.code} ${it.name} | $qty${unit.isEmpty ? '' : ' $unit'} | BF:$unitPrice | İsk:$disc | KDV:$vat | $total $cur',
          );
          if (it.serialNumber?.trim().isNotEmpty ?? false) {
            lines.add('   IMEI/SN: ${it.serialNumber}');
          }
        }
      }
      return lines.join('\\n');
    }

    final itemsTable = buildItemsTable(extended: false);
    final itemsTableExtended = buildItemsTable(extended: true);

    final double grandTotalRounded = widget.genelToplam;
    final double roundingRaw = grandTotalRounded - grandTotal;
    final double roundingValue = roundingRaw.abs() < 0.0001 ? 0.0 : roundingRaw;

    double docExchangeRate = 1.0;
    if (txItems.isNotEmpty) {
      final firstNonZero = txItems
          .map((e) => e.exchangeRate)
          .firstWhere((r) => r > 0, orElse: () => 1.0);
      docExchangeRate = firstNonZero;
    }

    String buildVatSummary() {
      if (sortedRates.isEmpty) {
        return '${_fmtRate(0)} Matrah: ${_fmtMoney(0)} KDV: ${_fmtMoney(0)}';
      }
      final lines = <String>[];
      for (final r in sortedRates) {
        final g = vatGroups[r]!;
        lines.add(
          '${_fmtRate(r)} Matrah: ${_fmtMoney(g.base)} KDV: ${_fmtMoney(g.amount)}',
        );
      }
      return lines.join('\\n');
    }

    String buildRateSummary({
      required Map<double, ({double base, double amount})> groups,
      required String amountLabel,
    }) {
      if (groups.isEmpty) {
        return '${_fmtRate(0)} Matrah: ${_fmtMoney(0)} $amountLabel: ${_fmtMoney(0)}';
      }
      final keys = groups.keys.toList()..sort();
      final lines = <String>[];
      for (final r in keys) {
        final g = groups[r]!;
        lines.add(
          '${_fmtRate(r)} Matrah: ${_fmtMoney(g.base)} $amountLabel: ${_fmtMoney(g.amount)}',
        );
      }
      return lines.join('\\n');
    }

    final Map<double, ({double base, double amount})> otvGroups = {};
    final Map<double, ({double base, double amount})> oivGroups = {};
    final Map<double, ({double base, double amount})> tevkifatGroups = {};

    for (final it in txItems) {
      final base = it.quantity * it.netUnitPrice;

      if (it.otvRate != 0 || it.otvAmount != 0) {
        final r = it.otvRate;
        final current = otvGroups[r];
        otvGroups[r] = (
          base: (current?.base ?? 0) + base,
          amount: (current?.amount ?? 0) + it.otvAmount,
        );
      }

      if (it.oivRate != 0 || it.oivAmount != 0) {
        final r = it.oivRate;
        final current = oivGroups[r];
        oivGroups[r] = (
          base: (current?.base ?? 0) + base,
          amount: (current?.amount ?? 0) + it.oivAmount,
        );
      }

      if (it.kdvTevkifatOrani != 0 || it.kdvTevkifatAmount != 0) {
        final r = it.kdvTevkifatOrani * 100;
        final current = tevkifatGroups[r];
        tevkifatGroups[r] = (
          base: (current?.base ?? 0) + it.vatAmount,
          amount: (current?.amount ?? 0) + it.kdvTevkifatAmount,
        );
      }
    }

    final vatSummary = buildVatSummary();
    final otvSummary = buildRateSummary(groups: otvGroups, amountLabel: 'ÖTV');
    final oivSummary = buildRateSummary(groups: oivGroups, amountLabel: 'ÖİV');
    final tevkifatSummary = buildRateSummary(
      groups: tevkifatGroups,
      amountLabel: 'Tevkifat',
    );

    final odemeYeri = (odemeBilgisi?['odemeYeri']?.toString() ?? '').trim();
    final odemeAciklama = (odemeBilgisi?['odemeAciklama']?.toString() ?? '')
        .trim();
    final double odemeTutar = _toDouble(odemeBilgisi?['tutar']);

    String paymentType = odemeAciklama.isNotEmpty ? odemeAciklama : odemeYeri;
    if (paymentType.trim().isEmpty) paymentType = 'Nakit';

    double cashPaid = 0.0;
    double cardPaid = 0.0;
    final lowerPay = paymentType.toLowerCase();
    if (odemeYeri == 'Kasa' || lowerPay.contains('nakit')) {
      cashPaid = odemeTutar > 0 ? odemeTutar : grandTotalRounded;
    } else {
      cardPaid = odemeTutar > 0 ? odemeTutar : grandTotalRounded;
    }
    final changeValue = cashPaid > grandTotalRounded
        ? (cashPaid - grandTotalRounded)
        : 0.0;

    final cashierNameRaw = (cariIslem?['user_name']?.toString() ?? '').trim();
    final cashierName = cashierNameRaw.isNotEmpty
        ? cashierNameRaw
        : ((shipments.isNotEmpty
                      ? shipments.first['created_by']?.toString()
                      : null) ??
                  '')
              .trim();

    final receiptQrData = widget.entegrasyonRef.trim().isNotEmpty
        ? widget.entegrasyonRef.trim()
        : (invoiceNoRaw.isNotEmpty ? invoiceNoRaw : '-');

    String bankInfo = '';
    try {
      final bankalar = await BankalarVeritabaniServisi().bankalariGetir(
        sayfaBasinaKayit: 1,
        varsayilan: true,
        aktifMi: true,
      );
      if (bankalar.isNotEmpty) {
        final b = bankalar.first;
        final lines = <String>[];
        if (b.ad.trim().isNotEmpty) lines.add(b.ad.trim());

        final branch = [
          b.subeAdi.trim(),
          b.subeKodu.trim(),
        ].where((p) => p.isNotEmpty).join(' ');
        if (branch.isNotEmpty) lines.add(branch);

        if (b.hesapNo.trim().isNotEmpty) {
          lines.add('Hesap: ${b.hesapNo.trim()}');
        }
        if (b.iban.trim().isNotEmpty) {
          lines.add('IBAN: ${FormatYardimcisi.ibanFormatla(b.iban.trim())}');
        }
        if (b.bilgi1.trim().isNotEmpty) lines.add(b.bilgi1.trim());
        if (b.bilgi2.trim().isNotEmpty) lines.add(b.bilgi2.trim());
        bankInfo = lines.join('\\n');
      }
    } catch (e) {
      debugPrint('Banka bilgisi alınamadı: $e');
    }

    if (bankInfo.trim().isEmpty) {
      final hesapAdi = (odemeBilgisi?['hesapAdi']?.toString() ?? '').trim();
      final hesapKodu = (odemeBilgisi?['hesapKodu']?.toString() ?? '').trim();
      final parts = <String>[
        odemeYeri,
        hesapAdi,
        hesapKodu.isEmpty ? '' : '($hesapKodu)',
      ].where((p) => p.isNotEmpty).toList();
      bankInfo = parts.isNotEmpty ? parts.join(' ') : '-';
    }

    return {
      // Firma
      'header_line_1': headerLines.isNotEmpty ? headerLines[0] : '',
      'header_line_2': headerLines.length > 1 ? headerLines[1] : '',
      'header_line_3': headerLines.length > 2 ? headerLines[2] : '',
      'seller_logo': sirket?.ustBilgiLogosu ?? '',
      'seller_name': sirket?.ad ?? '',
      'seller_address': sirket?.adres ?? '',
      'seller_tax_office': sirket?.vergiDairesi ?? '',
      'seller_tax_no': sirket?.vergiNo ?? '',
      'seller_phone': sirket?.telefon ?? '',
      'seller_email': sirket?.eposta ?? '',
      'seller_web': sirket?.webAdresi ?? '',
      'bank_info': bankInfo,

      // Cari
      'customer_name': widget.cariAdi,
      'customer_code': widget.cariKodu,
      'customer_account_name': cari?.adi ?? widget.cariAdi,
      'customer_invoice_title': (cari?.fatUnvani.isNotEmpty ?? false)
          ? cari!.fatUnvani
          : (cari?.adi ?? widget.cariAdi),
      'customer_address': cari == null
          ? ''
          : _formatAddress(
              address: cari.fatAdresi,
              district: cari.fatIlce,
              city: cari.fatSehir,
              postalCode: cari.postaKodu,
            ),
      'customer_shipping_address': cari == null
          ? ''
          : _firstShippingAddress(cari.sevkAdresleri),
      'tax_office': cari?.vDairesi ?? '',
      'tax_no': cari?.vNumarasi ?? '',
      'customer_phone': cari?.telefon1 ?? '',
      'customer_phone2': cari?.telefon2 ?? '',
      'customer_email': cari?.eposta ?? '',
      'customer_web': cari?.webAdresi ?? '',
      'customer_info1': cari?.bilgi1 ?? '',
      'customer_info2': cari?.bilgi2 ?? '',
      'customer_info3': cari?.bilgi3 ?? '',
      'customer_info4': cari?.bilgi4 ?? '',
      'customer_info5': cari?.bilgi5 ?? '',

      // Bakiye
      'previous_balance': _fmtMoney(previousBalance),
      'current_balance': _fmtMoney(currentBalance),
      'balance_currency': balanceCurrencySymbol,

      // Belge
      'invoice_type': tr('documents.type.sales_invoice'),
      'invoice_date': _faturaTarihiController.text,
      'invoice_no': _faturaNoController.text,
      'serial_no': serialNo,
      'sequence_no': sequenceNo,
      'dispatch_number': _irsaliyeNoController.text,
      'dispatch_date': _irsaliyeTarihiController.text,
      'dispatch_time': dispatchTime,
      'actual_dispatch_date': _fiiliSevkTarihiController.text,
      'due_date': _sonOdemeTarihiController.text,
      'validity_date': validityDate,
      'created_date': _duzenlemeTarihiController.text,
      'created_time': _duzenlemeSaatiController.text,
      'order_no': _siparisNoController.text,
      'date': _faturaTarihiController.text,
      'time': _duzenlemeSaatiController.text,
      'page_no': '1',
      'note': noteText,
      'description1': _aciklamaControllers[0].text,
      'description2': _aciklamaControllers[1].text,
      'description3': _aciklamaControllers[2].text,
      'description4': _aciklamaControllers[3].text,
      'description5': _aciklamaControllers[4].text,

      // Ürünler (repeat)
      'items_table': itemsTable,
      'items_table_extended': itemsTableExtended,
      'item_line_no': itemLineNo,
      'item_name': itemName,
      'item_code': itemCode,
      'item_barcode': itemBarcode,
      'item_description': itemDescription,
      'item_quantity': itemQuantity,
      'item_unit': itemUnit,
      'item_discount_rate': itemDiscountRate,
      'item_discount_amount': itemDiscountAmount,
      'item_vat_rate': itemVatRate,
      'item_otv_rate': itemOtvRate,
      'item_oiv_rate': itemOivRate,
      'item_tevkifat_rate': itemTevkifatRate,
      'item_unit_price_excl': itemUnitPriceExcl,
      'item_unit_price_incl': itemUnitPriceIncl,
      'item_total_excl': itemTotalExcl,
      'item_total_incl': itemTotalIncl,
      'item_currency': itemCurrency,

      // Toplamlar
      'subtotal': _fmtMoney(subtotal),
      'discount_total': _fmtMoney(discountTotal),
      'taxable_amount': _fmtMoney(taxableAmount),
      'vat_total': _fmtMoney(vatTotal),
      'otv_amount': _fmtMoney(otvAmount),
      'oiv_amount': _fmtMoney(oivAmount),
      'tevkifat_amount': _fmtMoney(tevkifatAmount),
      'rounding': _fmtMoney(roundingValue),
      'grand_total': _fmtMoney(grandTotal),
      'grand_total_rounded': _fmtMoney(grandTotalRounded),
      'currency': docCurrencySymbol,
      'exchange_rate': _fmtRate(docExchangeRate),
      'total_as_text': FormatYardimcisi.tutarYaziyaCevir(
        grandTotalRounded,
        paraBirimiKodu: widget.paraBirimi,
        yalnizEkle: true,
        kurusBasamak: _genelAyarlar.fiyatOndalik.clamp(0, 2),
      ),
      'vat_summary': vatSummary,
      'otv_summary': otvSummary,
      'oiv_summary': oivSummary,
      'tevkifat_summary': tevkifatSummary,

      // Ödeme
      'payment_type': paymentType,
      'cash_amount': _fmtMoney(cashPaid),
      'card_amount': _fmtMoney(cardPaid),
      'change_amount': _fmtMoney(changeValue),
      'cashier_name': cashierName.isNotEmpty ? cashierName : 'Sistem',
      'receipt_qr': receiptQrData,

      for (int i = 0; i < 6; i++) ...{
        // [2026 FIX] Show 0/0,00 instead of empty string for unused VAT fields
        'vat_rate_${i + 1}': i < sortedRates.length
            ? _fmtRate(sortedRates[i])
            : _fmtRate(0),
        'vat_base_${i + 1}': i < sortedRates.length
            ? _fmtMoney(vatGroups[sortedRates[i]]!.base)
            : _fmtMoney(0),
        'vat_amount_${i + 1}': i < sortedRates.length
            ? _fmtMoney(vatGroups[sortedRates[i]]!.amount)
            : _fmtMoney(0),
      },
    };
  }

  Future<void> _guncelle() async {
    final Map<String, dynamic> yazdirmaBilgileri = {
      'irsaliyeNo': _irsaliyeNoController.text,
      'faturaNo': _faturaNoController.text,
      'irsaliyeTarihi': _irsaliyeTarihi,
      'fiiliSevkTarihi': _fiiliSevkTarihi,
      'faturaTarihi': _faturaTarihi,
      'duzenlemeTarihi': _duzenlemeTarihi,
      'duzenlemeSaati': _duzenlemeSaatiController.text,
      'siparisNo': _siparisNoController.text,
      'sonOdemeTarihi': _sonOdemeTarihi,
      'aciklamalar': _aciklamaControllers.map((c) => c.text).toList(),
    };

    try {
      await SatisYapVeritabaniServisi()
          .satisIsleminiYazdirmaBilgileriyleGuncelle(
            entegrasyonRef: widget.entegrasyonRef,
            yazdirmaBilgileri: yazdirmaBilgileri,
          );
    } catch (e) {
      debugPrint('Güncelleme hatası: $e');
    }
  }

  bool _isFieldInTemplate(String key) {
    if (_secilenSablon == null) {
      // Şablon seçilmediyse hepsi pasif kalsın
      return false;
    }
    return _secilenSablon!.layout.any((e) => e.key == key);
  }

  void _closePage() {
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    const primaryColor = Color(0xFF2C3E50);
    final theme = Theme.of(context);
    final bool isMobileLayout = MediaQuery.sizeOf(context).width < 900;
    final double pagePadding = isMobileLayout ? 12 : 24;
    final double sectionGap = isMobileLayout ? 16 : 24;

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _closePage},
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: _closePage,
              ),
              Text(
                tr('common.esc'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          leadingWidth: 80,
          title: Text(
            tr('common.print_document'),
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: isMobileLayout ? 19 : 20,
            ),
          ),
          centerTitle: false,
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(pagePadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobileLayout ? 760 : 800,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionCard(
                            title: tr(
                              'print_after_sale.section.print_settings',
                            ),
                            icon: Icons.print_outlined,
                            color: primaryColor,
                            isCompact: isMobileLayout,
                            child: _buildDropdown(
                              value: _secilenSablon,
                              label: tr('print_after_sale.field.template'),
                              items: _sablonlar,
                              onChanged: (v) =>
                                  setState(() => _secilenSablon = v),
                              color: primaryColor,
                            ),
                          ),
                          SizedBox(height: sectionGap),
                          _buildSectionCard(
                            title: tr('print_after_sale.section.document_info'),
                            icon: Icons.description_outlined,
                            color: primaryColor,
                            isCompact: isMobileLayout,
                            child: _buildFormFields(primaryColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildFooter(primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    IconData icon,
    Color color, {
    bool compact = false,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(compact ? 6 : 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(compact ? 6 : 8),
          ),
          child: Icon(icon, color: color, size: compact ? 18 : 20),
        ),
        SizedBox(width: compact ? 10 : 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    bool isCompact = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: isCompact ? 12 : 16,
            offset: Offset(0, isCompact ? 4 : 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(title, icon, color, compact: isCompact),
          SizedBox(height: isCompact ? 12 : 16),
          child,
        ],
      ),
    );
  }

  Widget _buildResponsiveRow({
    required Widget first,
    required Widget second,
    double spacing = 16,
    bool secondOnlyOnNarrow = false,
  }) {
    final bool isCompact = MediaQuery.sizeOf(context).width < 700;
    if (isCompact) {
      if (secondOnlyOnNarrow) return second;
      return Column(
        children: [
          first,
          SizedBox(height: spacing),
          second,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        SizedBox(width: spacing),
        Expanded(child: second),
      ],
    );
  }

  Widget _buildFooter(Color primaryColor) {
    final bool isCompact = MediaQuery.sizeOf(context).width < 760;
    return Container(
      padding: EdgeInsets.all(isCompact ? 12.0 : 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isCompact ? 760 : 800),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _secilenSablon == null ? null : _yazdir,
                        icon: const Icon(Icons.print_rounded),
                        label: Text(
                          tr('common.print'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () async {
                          await _guncelle();
                          if (!mounted) return;
                          Navigator.of(context).pop(true);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          tr('common.exit_menu'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        await _guncelle();
                        if (!mounted) return;
                        Navigator.of(context).pop(true);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        tr('common.exit_menu'),
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _secilenSablon == null ? null : _yazdir,
                      icon: const Icon(Icons.print_rounded),
                      label: Text(
                        tr('common.print'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFormFields(Color defaultColor) {
    const irsaliyeColor = Color(0xFF2C3E50); // Teal
    const faturaColor = Color(0xFF7E57C2); // Muted Purple
    const siparisColor = Color(0xFF607D8B); // Blue Grey

    return Column(
      children: [
        _buildResponsiveRow(
          first: _buildModernField(
            tr('print_after_sale.dispatch_number'),
            _irsaliyeNoController,
            color: irsaliyeColor,
            enabled: _isFieldInTemplate('dispatch_number'),
          ),
          second: _buildModernField(
            tr('print_after_sale.dispatch_date'),
            _irsaliyeTarihiController,
            color: irsaliyeColor,
            isDate: true,
            onTap: () => _tarihSec(context, 'irsaliye'),
            enabled: _isFieldInTemplate('dispatch_date'),
          ),
        ),
        const SizedBox(height: 16),
        _buildResponsiveRow(
          first: const SizedBox.shrink(),
          second: _buildModernField(
            tr('print_after_sale.actual_dispatch_date'),
            _fiiliSevkTarihiController,
            color: irsaliyeColor,
            isDate: true,
            onTap: () => _tarihSec(context, 'sevk'),
            enabled: _isFieldInTemplate('actual_dispatch_date'),
          ),
          secondOnlyOnNarrow: true,
        ),
        const SizedBox(height: 24), // Group spacing
        _buildResponsiveRow(
          first: _buildModernField(
            tr('print_after_sale.invoice_number'),
            _faturaNoController,
            color: faturaColor,
            enabled: _isFieldInTemplate('invoice_no'),
          ),
          second: _buildModernField(
            tr('print_after_sale.invoice_date'),
            _faturaTarihiController,
            color: faturaColor,
            isDate: true,
            onTap: () => _tarihSec(context, 'fatura'),
            enabled: _isFieldInTemplate('invoice_date'),
          ),
        ),
        const SizedBox(height: 16),
        _buildResponsiveRow(
          first: _buildModernField(
            tr('print_after_sale.created_date'),
            _duzenlemeTarihiController,
            color: faturaColor,
            isDate: true,
            onTap: () => _tarihSec(context, 'duzenleme'),
            enabled: _isFieldInTemplate('created_date'),
          ),
          second: _buildModernField(
            tr('print_after_sale.created_time'),
            _duzenlemeSaatiController,
            color: faturaColor,
            enabled: _isFieldInTemplate('created_time'),
          ),
        ),
        const SizedBox(height: 24), // Group spacing
        _buildResponsiveRow(
          first: _buildModernField(
            tr('print_after_sale.order_number'),
            _siparisNoController,
            color: siparisColor,
            enabled: _isFieldInTemplate('order_no'),
          ),
          second: _buildModernField(
            tr('print_after_sale.due_date'),
            _sonOdemeTarihiController,
            color: siparisColor,
            isDate: true,
            onTap: () => _tarihSec(context, 'vade'),
            enabled: _isFieldInTemplate('due_date'),
          ),
        ),
        const SizedBox(height: 32),
        Column(
          children: [
            _buildResponsiveRow(
              first: AkilliAciklamaInput(
                controller: _aciklamaControllers[0],
                label: tr(
                  'common.description_with_number',
                ).replaceAll('{n}', '1'),
                category: 'satis_sonrasi_yazdir_aciklama',
                color: defaultColor,
                isDense: true,
                enabled: _isFieldInTemplate('description1'),
                defaultItems: [
                  tr('orders.defaults.description.1'),
                  tr('orders.defaults.description.2'),
                  tr('orders.defaults.description.3'),
                  tr('orders.defaults.description.4'),
                  tr('orders.defaults.description.5'),
                ],
              ),
              second: AkilliAciklamaInput(
                controller: _aciklamaControllers[1],
                label: tr(
                  'common.description_with_number',
                ).replaceAll('{n}', '2'),
                category: 'satis_sonrasi_yazdir_aciklama',
                color: defaultColor,
                isDense: true,
                enabled: _isFieldInTemplate('description2'),
                defaultItems: [
                  tr('orders.defaults.description2.1'),
                  tr('orders.defaults.description2.2'),
                  tr('orders.defaults.description2.3'),
                  tr('orders.defaults.description2.4'),
                  tr('orders.defaults.description2.5'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildResponsiveRow(
              first: AkilliAciklamaInput(
                controller: _aciklamaControllers[2],
                label: tr(
                  'common.description_with_number',
                ).replaceAll('{n}', '3'),
                category: 'satis_sonrasi_yazdir_aciklama',
                color: defaultColor,
                isDense: true,
                enabled: _isFieldInTemplate('description3'),
                defaultItems: [
                  tr('quotes.defaults.description.1'),
                  tr('quotes.defaults.description.2'),
                  tr('quotes.defaults.description.3'),
                  tr('quotes.defaults.description.4'),
                  tr('quotes.defaults.description.5'),
                ],
              ),
              second: AkilliAciklamaInput(
                controller: _aciklamaControllers[3],
                label: tr(
                  'common.description_with_number',
                ).replaceAll('{n}', '4'),
                category: 'satis_sonrasi_yazdir_aciklama',
                color: defaultColor,
                isDense: true,
                enabled: _isFieldInTemplate('description4'),
                defaultItems: [
                  tr('quotes.defaults.description2.1'),
                  tr('quotes.defaults.description2.2'),
                  tr('quotes.defaults.description2.3'),
                  tr('quotes.defaults.description2.4'),
                  tr('quotes.defaults.description2.5'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 700;
                final widget5 = AkilliAciklamaInput(
                  controller: _aciklamaControllers[4],
                  label: tr(
                    'common.description_with_number',
                  ).replaceAll('{n}', '5'),
                  category: 'satis_sonrasi_yazdir_aciklama',
                  color: defaultColor,
                  isDense: true,
                  enabled: _isFieldInTemplate('description5'),
                  defaultItems: [
                    tr('smart_select.sale.desc.1'),
                    tr('smart_select.sale.desc.2'),
                    tr('smart_select.sale.desc.3'),
                    tr('smart_select.sale.desc.4'),
                    tr('smart_select.sale.desc.5'),
                  ],
                );

                if (isCompact) return widget5;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: widget5),
                    const SizedBox(width: 16),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernField(
    String label,
    TextEditingController controller, {
    required Color color,
    bool isDate = false,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    final bool isCompact = MediaQuery.sizeOf(context).width < 640;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isCompact ? 13 : 14,
            fontWeight: FontWeight.w600,
            color: (enabled ? color : Colors.grey).withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: isDate,
          enabled: enabled,
          onTap: enabled ? onTap : null,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 7 : 8),
            suffixIcon: isDate
                ? Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: (enabled ? color : Colors.grey).withValues(
                      alpha: 0.5,
                    ),
                  )
                : const SizedBox(width: 16, height: 16),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color: (enabled ? color : Colors.grey).withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: (enabled ? color : Colors.grey).withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: color, width: 2),
            ),
          ),
          style: TextStyle(
            fontSize: isCompact ? 15 : 16,
            color: enabled ? null : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  // Eski field builderlar modernleştirme ile kaldırıldı.

  Widget _buildDropdown({
    required YazdirmaSablonuModel? value,
    required String label,
    required List<YazdirmaSablonuModel> items,
    required void Function(YazdirmaSablonuModel?) onChanged,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<YazdirmaSablonuModel>(
          initialValue: value,
          isExpanded: true,
          onChanged: onChanged,
          items: items
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.name, style: const TextStyle(fontSize: 16)),
                ),
              )
              .toList(),
          decoration: InputDecoration(
            isDense: true,
            hintText: tr('print_after_sale.select_template'),
            hintStyle: const TextStyle(fontSize: 16, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: color, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
