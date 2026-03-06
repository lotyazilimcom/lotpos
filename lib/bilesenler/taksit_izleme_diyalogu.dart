import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../yardimcilar/ceviri/ceviri_servisi.dart';
import '../yardimcilar/format_yardimcisi.dart';
import '../yardimcilar/mesaj_yardimcisi.dart';
import '../servisler/taksit_veritabani_servisi.dart';
import '../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../servisler/kasalar_veritabani_servisi.dart';
import '../servisler/bankalar_veritabani_servisi.dart';
import '../servisler/kredi_kartlari_veritabani_servisi.dart';
import '../servisler/ayarlar_veritabani_servisi.dart';
import '../sayfalar/ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';

class TaksitIzlemeDiyalogu extends StatefulWidget {
  final String integrationRef;
  final String cariAdi;

  const TaksitIzlemeDiyalogu({
    super.key,
    required this.integrationRef,
    required this.cariAdi,
  });

  @override
  State<TaksitIzlemeDiyalogu> createState() => _TaksitIzlemeDiyaloguState();
}

class _TaksitIzlemeDiyaloguState extends State<TaksitIzlemeDiyalogu> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  List<Map<String, dynamic>> _taksitler = [];
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  // Peşinat bilgisi (taksitli satış)
  double _pesinatTutar = 0.0;
  String _pesinatDurum = '';
  String _pesinatDetay = '';
  String _pesinatParaBirimi = 'TRY';

  // Düzenleme Editörleri
  final List<TextEditingController> _tutarControllers = [];
  final List<DateTime> _vadeTarihleri = [];
  final List<TextEditingController> _aciklamaControllers = [];

  @override
  void initState() {
    super.initState();
    _bilgileriYukle();
  }

  Future<void> _bilgileriYukle() async {
    setState(() => _isLoading = true);
    try {
      _genelAyarlar = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      final res = await TaksitVeritabaniServisi().taksitleriGetir(
        widget.integrationRef,
      );

      // Peşinat bilgisi: önce gerçek ödeme, yoksa satış açıklamasındaki nottan oku.
      final cariServis = CariHesaplarVeritabaniServisi();
      final saleMaster = await cariServis.entegrasyonSatisAnaIslemGetir(
        widget.integrationRef,
      );
      final odeme = await cariServis.entegrasyonOdemeBilgisiGetir(
        widget.integrationRef,
      );

      double pesinatTutar = 0.0;
      String pesinatDurum = '';
      String pesinatDetay = '';
      String pesinatParaBirimi =
          (saleMaster?['para_birimi']?.toString() ?? 'TRY');

      double parseDouble(dynamic value) {
        if (value == null) return 0.0;
        if (value is num) return value.toDouble();
        final text = value.toString().trim();
        if (text.isEmpty) return 0.0;
        return double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
      }

      Map<String, dynamic>? parsePesinatFromDescription(String description) {
        if (description.trim().isEmpty) return null;
        final parts = description.split(' - ');
        for (final rawPart in parts) {
          final part = rawPart.trim();
          final lower = part.toLowerCase();
          if (lower.startsWith('peşinat:') || lower.startsWith('pesinat:')) {
            final int open = part.lastIndexOf('(');
            final int close = part.lastIndexOf(')');
            String status = '';
            String valuePart = part;

            if (open != -1 && close != -1 && close > open) {
              status = part.substring(open + 1, close).trim();
              valuePart = part.substring(0, open).trim();
            }

            // "Peşinat: 10,00 TRY"
            final colonIdx = valuePart.indexOf(':');
            final afterColon = colonIdx != -1
                ? valuePart.substring(colonIdx + 1).trim()
                : valuePart.trim();

            final tokens = afterColon.split(RegExp(r'\s+'));
            if (tokens.isEmpty) return null;

            String currency = pesinatParaBirimi;
            String amountText = afterColon;
            if (tokens.length >= 2) {
              currency = tokens.last.trim();
              amountText = tokens
                  .sublist(0, tokens.length - 1)
                  .join(' ')
                  .trim();
            }

            final double amount = FormatYardimcisi.parseDouble(
              amountText,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
            );

            return {
              'amount': amount.abs(),
              'currency': currency,
              'status': status,
            };
          }
        }
        return null;
      }

      if (odeme != null && parseDouble(odeme['tutar']) > 0) {
        pesinatTutar = parseDouble(odeme['tutar']).abs();
        pesinatDurum = 'Ödendi';
        final String odemeYeri = odeme['odemeYeri']?.toString() ?? '';
        final String hesapAdi = odeme['hesapAdi']?.toString() ?? '';
        final String hesapKodu = odeme['hesapKodu']?.toString() ?? '';
        final hesapLabel = [
          if (hesapAdi.isNotEmpty) hesapAdi,
          if (hesapKodu.isNotEmpty) hesapKodu,
        ].join(' ');
        pesinatDetay = odemeYeri.isNotEmpty
            ? '$odemeYeri${hesapLabel.isNotEmpty ? ': $hesapLabel' : ''}'
            : hesapLabel;
      } else {
        final note = parsePesinatFromDescription(
          saleMaster?['description']?.toString() ?? '',
        );
        if (note != null && parseDouble(note['amount']) > 0) {
          pesinatTutar = parseDouble(note['amount']).abs();
          pesinatParaBirimi =
              note['currency']?.toString().trim().isNotEmpty == true
              ? note['currency']?.toString() ?? pesinatParaBirimi
              : pesinatParaBirimi;
          pesinatDurum = (note['status']?.toString().trim().isNotEmpty == true)
              ? note['status']?.toString() ?? 'Silindi'
              : 'Silindi';
          if (pesinatDurum.toLowerCase().contains('sil')) {
            pesinatDetay = 'Peşinat ödemesi silindi.';
          }
        }
      }

      setState(() {
        _taksitler = res;
        _pesinatTutar = pesinatTutar;
        _pesinatDurum = pesinatDurum;
        _pesinatDetay = pesinatDetay;
        _pesinatParaBirimi = pesinatParaBirimi;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Taksitler yüklenirken hata: $e');
      setState(() => _isLoading = false);
    }
  }

  void _editModunaGec() {
    _tutarControllers.clear();
    _vadeTarihleri.clear();
    _aciklamaControllers.clear();

    for (var t in _taksitler) {
      final tutarValue = double.tryParse(t['tutar'].toString()) ?? 0;
      _tutarControllers.add(
        TextEditingController(
          text: FormatYardimcisi.sayiFormatlaOndalikli(
            tutarValue,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: _genelAyarlar.fiyatOndalik,
          ),
        ),
      );
      final rawVade = t['vade_tarihi'];
      _vadeTarihleri.add(
        rawVade is DateTime ? rawVade : DateTime.parse(rawVade.toString()),
      );
      _aciklamaControllers.add(
        TextEditingController(text: t['aciklama']?.toString() ?? ''),
      );
    }

    setState(() {
      _isEditing = true;
    });
  }

  Future<void> _taksitleriKaydet() async {
    setState(() => _isSaving = true);
    try {
      for (int i = 0; i < _taksitler.length; i++) {
        final double tutarVal = FormatYardimcisi.parseDouble(
          _tutarControllers[i].text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        );

        await TaksitVeritabaniServisi().taksitGuncelle(
          id: _taksitler[i]['id'],
          vade: _vadeTarihleri[i],
          tutar: tutarVal,
          aciklama: _aciklamaControllers[i].text,
        );
      }

      await _bilgileriYukle();
      setState(() {
        _isEditing = false;
        _isSaving = false;
        _anyChange = true;
      });
      if (mounted) {
        MesajYardimcisi.basariGoster(
          context,
          tr('common.saved_successfully'),
        );
      }
    } catch (e) {
      debugPrint('Kaydetme hatası: $e');
      setState(() => _isSaving = false);
      if (mounted) {
        MesajYardimcisi.hataGoster(context, tr('common.error_occurred'));
      }
    }
  }

  Future<void> _odemeYap(Map<String, dynamic> taksit) async {
    // 1. Hesap Seçme Diyaloğu
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _HesapSecimDialog(
        tutar: double.tryParse(taksit['tutar'].toString()) ?? 0,
      ),
    );

    if (result == null) return;

    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = prefs.getString('current_username') ?? 'admin';
      final double tutarValue =
          double.tryParse(taksit['tutar'].toString()) ?? 0;

      final String vadeStr = DateFormat('dd.MM.yyyy').format(
        taksit['vade_tarihi'] is DateTime
            ? taksit['vade_tarihi']
            : DateTime.parse(taksit['vade_tarihi'].toString()),
      );

      final String customAciklama =
          '${tr('sale.complete.installment_payment_desc')} (${tr('sale.complete.installment_vade_desc').replaceAll('{vade}', vadeStr)})';

      // 2. Cari İşlemi Kaydet (CariHesaplarVeritabaniServisi üzerinden)
      final int? txId = await CariHesaplarVeritabaniServisi()
          .cariParaAlVerKaydet(
            cariId: taksit['cari_id'],
            tutar: tutarValue,
            islemTipi: 'para_al', // Tahsilat
            lokasyon: result['type'], // cash, bank, credit_card
            hedefId: result['id'], // Kasa/Banka ID
            aciklama: customAciklama,
            tarih: DateTime.now(),
            kullanici: currentUser,
            kaynakAdi: result['name'],
            kaynakKodu: result['code'],
            cariAdi: widget.cariAdi,
            cariKodu: '', // Opsiyonel
          );

      // 3. Taksit Durumunu Güncelle (İşlem ID'si ile bağla)
      await TaksitVeritabaniServisi().taksitDurumGuncelle(
        taksit['id'],
        'Ödendi',
        hareketId: txId,
      );

      await _bilgileriYukle();
      if (mounted) {
        MesajYardimcisi.basariGoster(
          context,
          tr('sale.complete.installment_payment_success'),
        );
      }
    } catch (e) {
      debugPrint('Ödeme hatası: $e');
      if (mounted) {
        MesajYardimcisi.hataGoster(
          context,
          '${tr('common.error.generic')}$e',
        );
      }
    } finally {
      setState(() => _isSaving = false);
      // Başarılı ödeme sonrası ana sayfayı yenilemek için sinyal gönder
      _anyChange = true;
    }
  }

  bool _anyChange = false;

  @override
  Widget build(BuildContext context) {
    const dialogRadius = 16.0;
    const primaryColor = Color(0xFF2C3E50);

    double toplamTutar = 0;
    for (var t in _taksitler) {
      toplamTutar += double.tryParse(t['tutar'].toString()) ?? 0;
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dialogRadius),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(dialogRadius),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('sale.complete.installments_title'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF202124),
                          ),
                        ),
                        Text(
                          widget.cariAdi,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isEditing && !_isLoading)
                    IconButton(
                      onPressed: _editModunaGec,
                      icon: const Icon(Icons.edit_note_rounded),
                      color: primaryColor,
                      tooltip: tr('common.edit'),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, _anyChange),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),

            if (_isLoading || _isSaving)
              const Padding(
                padding: EdgeInsets.all(48.0),
                child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
              )
            else if (_taksitler.isEmpty)
              Padding(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('common.no_records_found'),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (_pesinatDurum.isNotEmpty && _pesinatTutar > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.payments_rounded,
                                  color: primaryColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr('installments.down_payment'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: Color(0xFF202124),
                                      ),
                                    ),
                                    if (_pesinatDetay.trim().isNotEmpty)
                                      Text(
                                        _pesinatDetay,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${FormatYardimcisi.sayiFormatlaOndalikli(_pesinatTutar, binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} $_pesinatParaBirimi',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: Color(0xFF202124),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildStatusBadge(_pesinatDurum),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Özet Kartı
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSummaryItem(
                              label: tr('common.total'),
                              value: FormatYardimcisi.sayiFormatlaOndalikli(
                                toplamTutar,
                              ),
                              color: primaryColor,
                            ),
                            _buildSummaryItem(
                              label: tr('sale.complete.installment_count'),
                              value: _taksitler.length.toString(),
                              color: Colors.blue.shade700,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Taksit Listesi
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _taksitler.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final t = _taksitler[index];
                          final durum = t['durum'] ?? 'Bekliyor';
                          final bool isPaid = durum == 'Ödendi';

                          if (_isEditing) {
                            return _buildEditItem(index);
                          }

                          final vade = t['vade_tarihi'] is DateTime
                              ? t['vade_tarihi'] as DateTime
                              : DateTime.parse(t['vade_tarihi'].toString());
                          final tutar =
                              double.tryParse(t['tutar'].toString()) ?? 0;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isPaid
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat('dd.MM.yyyy').format(vade),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (t['aciklama'] != null &&
                                          t['aciklama'].toString().isNotEmpty)
                                        Text(
                                          t['aciklama'],
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      FormatYardimcisi.sayiFormatlaOndalikli(
                                        tutar,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: Color(0xFF202124),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildStatusBadge(durum),
                                  ],
                                ),
                                if (!isPaid) ...[
                                  const SizedBox(width: 16),
                                  InkWell(
                                    mouseCursor: WidgetStateMouseCursor.clickable,
                                    onTap: () => _odemeYap(t),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.payments_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isEditing) ...[
                    TextButton(
                      onPressed: () => setState(() => _isEditing = false),
                      child: Text(
                        tr('common.cancel'),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _taksitleriKaydet,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(tr('common.save')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ] else
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, _anyChange),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        tr('common.close'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditItem(int index) {
    const primaryColor = Color(0xFF2C3E50);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Vade Seçici
              Expanded(
                child: InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _vadeTarihleri[index],
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: primaryColor,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() => _vadeTarihleri[index] = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat(
                            'dd.MM.yyyy',
                          ).format(_vadeTarihleri[index]),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Tutar
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _tutarControllers[index],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(12),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixText: 'TRY',
                    suffixStyle: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _aciklamaControllers[index],
            decoration: InputDecoration(
              hintText: tr('common.description'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String durum) {
    final bool isPaid = durum == 'Ödendi';
    final bool isDeleted = durum.toLowerCase().contains('sil');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDeleted
            ? Colors.red.withValues(alpha: 0.1)
            : (isPaid
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isDeleted
            ? tr('common.deleted')
            : tr(
                durum == 'Ödendi'
                    ? 'common.status.paid'
                    : 'common.status.pending',
              ),
        style: TextStyle(
          color: isDeleted
              ? Colors.red.shade700
              : (isPaid ? Colors.green.shade700 : Colors.orange.shade700),
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Hesap Seçim Diyaloğu (Kasa/Banka)
class _HesapSecimDialog extends StatefulWidget {
  final double tutar;
  const _HesapSecimDialog({required this.tutar});

  @override
  State<_HesapSecimDialog> createState() => _HesapSecimDialogState();
}

class _HesapSecimDialogState extends State<_HesapSecimDialog> {
  String _selectedType = 'cash';
  List<Map<String, dynamic>> _hesaplar = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _hesaplariYukle();
  }

  Future<void> _hesaplariYukle() async {
    setState(() => _isLoading = true);
    try {
      if (_selectedType == 'cash') {
        final res = await KasalarVeritabaniServisi().kasalariGetir();
        _hesaplar = res
            .map(
              (e) => {'id': e.id, 'code': e.kod, 'name': e.ad, 'type': 'cash'},
            )
            .toList();
      } else if (_selectedType == 'bank') {
        final res = await BankalarVeritabaniServisi().bankalariGetir();
        _hesaplar = res
            .map(
              (e) => {'id': e.id, 'code': e.kod, 'name': e.ad, 'type': 'bank'},
            )
            .toList();
      } else {
        final res = await KrediKartlariVeritabaniServisi()
            .krediKartlariniGetir();
        _hesaplar = res
            .map(
              (e) => {
                'id': e.id,
                'code': e.kod,
                'name': e.ad,
                'type': 'credit_card',
              },
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Hesap yükleme hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('sale.complete.select_payment_account')),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Segmented Type Selector
            Row(
              children: [
                _buildTypeTab('cash', Icons.money_rounded),
                _buildTypeTab('bank', Icons.account_balance_rounded),
                _buildTypeTab('credit_card', Icons.credit_card_rounded),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_hesaplar.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(tr('common.no_records_found')),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _hesaplar.length,
                  itemBuilder: (context, index) {
                    final h = _hesaplar[index];
                    return ListTile(
                      title: Text(h['name']),
                      subtitle: Text(h['code']),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(context, h),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('common.cancel')),
        ),
      ],
    );
  }

  Widget _buildTypeTab(String type, IconData icon) {
    final isSelected = _selectedType == type;
    const primaryColor = Color(0xFF2C3E50);
    return Expanded(
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () {
          setState(() => _selectedType = type);
          _hesaplariYukle();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? primaryColor : Colors.grey.shade200,
                width: 2,
              ),
            ),
          ),
          child: Icon(icon, color: isSelected ? primaryColor : Colors.grey),
        ),
      ),
    );
  }
}
