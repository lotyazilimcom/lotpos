import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import 'modeller/cari_hesap_model.dart';

import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../servisler/kasalar_veritabani_servisi.dart';
import '../../servisler/bankalar_veritabani_servisi.dart';
import '../../servisler/kredi_kartlari_veritabani_servisi.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../kasalar/modeller/kasa_model.dart';
import '../bankalar/modeller/banka_model.dart';
import '../kredikartlari/modeller/kredi_karti_model.dart';
import '../../bilesenler/akilli_aciklama_input.dart';
import '../../bilesenler/tek_tarih_secici_dialog.dart';
import '../../servisler/sayfa_senkronizasyon_servisi.dart';

/// Cari Hesap Para Al/Ver Sayfası
/// Kasa, Banka veya Kredi Kartı üzerinden para alınması veya verilmesi işlemlerini yönetir.
class CariParaAlVerSayfasi extends StatefulWidget {
  final CariHesapModel cari;
  final Map<String, dynamic>? duzenlenecekIslem;

  const CariParaAlVerSayfasi({
    super.key,
    required this.cari,
    this.duzenlenecekIslem,
  });

  @override
  State<CariParaAlVerSayfasi> createState() => _CariParaAlVerSayfasiState();
}

class _CariParaAlVerSayfasiState extends State<CariParaAlVerSayfasi> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();

  // Controllers
  final _dateController = TextEditingController();
  final _accountCodeController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Focus Nodes
  final _accountCodeFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();

  // State
  String _selectedTransactionType = 'para_al'; // para_al / para_ver
  String _selectedLocation = 'cash'; // cash / bank / credit_card
  DateTime _selectedDate = DateTime.now();
  int? _selectedHesapId;
  bool _userEdited = false;
  int _loadSequence = 0;

  // Transaction Type Options
  final List<Map<String, String>> _transactionTypeOptions = [
    {'value': 'para_al', 'key': 'accounts.transaction.receive_money'},
    {'value': 'para_ver', 'key': 'accounts.transaction.give_money'},
  ];

  // Location Options
  final List<Map<String, String>> _locationOptions = [
    {'value': 'cash', 'key': 'cashregisters.transaction.type.cash'},
    {'value': 'bank', 'key': 'cashregisters.transaction.type.bank'},
    {
      'value': 'credit_card',
      'key': 'cashregisters.transaction.type.credit_card',
    },
  ];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd.MM.yyyy').format(_selectedDate);
    _loadSettings();
    _attachPriceFormatter();

    if (widget.duzenlenecekIslem != null) {
      _initializeForEditing(widget.duzenlenecekIslem!);
    } else {
      // Focus amount field after build only for new records
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _amountFocusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CariParaAlVerSayfasi oldWidget) {
    super.didUpdateWidget(oldWidget);

    // [2025 FIX] Daha güçlü karşılaştırma: ID + source_id kombinasyonu
    final newId = _extractTransactionId(widget.duzenlenecekIslem);
    final oldId = _extractTransactionId(oldWidget.duzenlenecekIslem);
    final newSourceId = _extractSourceId(widget.duzenlenecekIslem);
    final oldSourceId = _extractSourceId(oldWidget.duzenlenecekIslem);

    // Hem transaction ID hem de source_id değişikliğini kontrol et
    final bool isNewTransaction =
        (newId != null && newId != oldId) ||
        (newSourceId != null && newSourceId != oldSourceId);

    if (isNewTransaction && widget.duzenlenecekIslem != null) {
      _initializeForEditing(widget.duzenlenecekIslem!);
      return;
    }

    if (oldWidget.duzenlenecekIslem != null &&
        widget.duzenlenecekIslem == null) {
      _resetFormState();
      _dateController.text = DateFormat('dd.MM.yyyy').format(_selectedDate);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _amountFocusNode.requestFocus();
        }
      });
    }
  }

  int? _extractTransactionId(Map<String, dynamic>? item) {
    if (item == null) return null;
    final raw = item['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  int? _extractSourceId(Map<String, dynamic>? item) {
    if (item == null) return null;
    final raw = item['source_id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  void _initializeForEditing(Map<String, dynamic> item) {
    // [2025 FIX] Tam sıfırlama ve setState ile UI güncelleme
    _loadSequence++; // Önceki async işlemleri iptal et

    _isEditing = false;
    _isLoading = false;
    _selectedTransactionType = 'para_al';
    _selectedLocation = 'cash';
    _selectedDate = DateTime.now();
    _selectedHesapId = null;
    _userEdited = false;

    // Controller'ları temizle
    _dateController.clear();
    _accountCodeController.clear();
    _accountNameController.clear();
    _amountController.clear();
    _descriptionController.clear();

    // Düzenleme modunu aktifleştir
    _isEditing = true;

    // [2025 FIX] Item'ın bir kopyasını al (Map referans sorunu önleme)
    final Map<String, dynamic> itemCopy = Map<String, dynamic>.from(item);

    // Formu cari işlem verileriyle doldur
    _fillFormFromCariTransaction(itemCopy);

    // UI'ı güncelle
    if (mounted) {
      setState(() {});
    }

    // Kaynak işlem detaylarını async olarak yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadTransactionDetails();
      }
    });
  }

  Future<void> _loadTransactionDetails() async {
    if (!mounted) return;

    // [2025 FIX] Null kontrolü ve kopyalama - race condition önleme
    if (widget.duzenlenecekIslem == null) {
      return;
    }

    // İşlem verisinin kopyasını al (async süresince widget değişebilir)
    final Map<String, dynamic> item = Map<String, dynamic>.from(
      widget.duzenlenecekIslem!,
    );

    // [2025 FIX] loadSequence'i burada artırma - sadece _initializeForEditing'de artırılmalı
    final int loadSeq = _loadSequence;
    setState(() => _isLoading = true);
    try {
      // Alias kontrolü: DB'den dönen tr map'inde islem_turu olabilir, source_type olabilir.
      final srcType =
          (item['source_type'] ?? item['islem_turu'])
              ?.toString()
              .toLowerCase() ??
          '';

      final srcId = item['source_id'] is int
          ? item['source_id'] as int
          : int.tryParse(item['source_id']?.toString() ?? '');

      if (srcId == null) throw Exception('Kaynak işlem ID bulunamadı.');

      bool found = false;

      // 1. Önce Kasa Olarak Dene (Eğer banka/kart olduğu kesin değilse)
      if (!srcType.contains('bank') && !srcType.contains('kart')) {
        final tx = await KasalarVeritabaniServisi().kasaIslemGetir(srcId);
        if (!mounted || loadSeq != _loadSequence) return;
        if (tx != null) {
          if (!_userEdited) {
            _selectedLocation = 'cash';
          }
          // [2025 FIX] TUTAR HARİÇ - sadece hesap bilgilerini al
          // Tutar cari işlemden gelir, kaynak işlemden değil
          _fillFormFromTransaction(tx, isKasa: true, overwrite: false);
          // Sadece hesap kodunu/adını güncelle
          _accountCodeController.text =
              (tx['kasa_kodu'] ?? tx['kasaKodu'] ?? tx['code'])?.toString() ??
              _accountCodeController.text;
          _accountNameController.text =
              (tx['kasa_adi'] ?? tx['kasaAdi'] ?? tx['name'])?.toString() ??
              _accountNameController.text;
          _selectedHesapId =
              tx['cash_register_id'] ?? tx['kasa_id'] ?? _selectedHesapId;
          found = true;
        }
      }

      // 2. Bulunamadıysa Banka Olarak Dene (Eğer kasa olduğu kesin değilse)
      if (!found && !srcType.contains('kasa') && !srcType.contains('cash')) {
        final tx = await BankalarVeritabaniServisi().bankaIslemGetir(srcId);
        if (!mounted || loadSeq != _loadSequence) return;
        if (tx != null) {
          if (!_userEdited) {
            _selectedLocation = 'bank';
          }
          // [2025 FIX] TUTAR HARİÇ - sadece hesap bilgilerini al
          _fillFormFromTransaction(tx, isKasa: false, overwrite: false);
          _accountCodeController.text =
              (tx['banka_kodu'] ?? tx['bankaKodu'] ?? tx['code'])?.toString() ??
              _accountCodeController.text;
          _accountNameController.text =
              (tx['banka_adi'] ?? tx['bankaAdi'] ?? tx['name'])?.toString() ??
              _accountNameController.text;
          _selectedHesapId =
              tx['bank_account_id'] ?? tx['banka_id'] ?? _selectedHesapId;
          found = true;
        }
      }

      // 3. Fallback: Eğer hala bulunamadıysa (veya srcType "Para Alındı" gibi belirsizse), her yeri dene
      if (!found) {
        // Kasa dene (tekrar, yukarıda girilmemiş olabilir)
        final txKasa = await KasalarVeritabaniServisi().kasaIslemGetir(srcId);
        if (!mounted || loadSeq != _loadSequence) return;
        if (txKasa != null) {
          if (!_userEdited) {
            _selectedLocation = 'cash';
          }
          // [2025 FIX] TUTAR HARİÇ
          _accountCodeController.text =
              (txKasa['kasa_kodu'] ?? txKasa['kasaKodu'] ?? txKasa['code'])
                  ?.toString() ??
              _accountCodeController.text;
          _accountNameController.text =
              (txKasa['kasa_adi'] ?? txKasa['kasaAdi'] ?? txKasa['name'])
                  ?.toString() ??
              _accountNameController.text;
          _selectedHesapId =
              txKasa['cash_register_id'] ??
              txKasa['kasa_id'] ??
              _selectedHesapId;
          found = true;
        } else {
          // Banka dene
          final txBanka = await BankalarVeritabaniServisi().bankaIslemGetir(
            srcId,
          );
          if (!mounted || loadSeq != _loadSequence) return;
          if (txBanka != null) {
            if (!_userEdited) {
              _selectedLocation = 'bank';
            }
            // [2025 FIX] TUTAR HARİÇ
            _accountCodeController.text =
                (txBanka['banka_kodu'] ??
                        txBanka['bankaKodu'] ??
                        txBanka['code'])
                    ?.toString() ??
                _accountCodeController.text;
            _accountNameController.text =
                (txBanka['banka_adi'] ?? txBanka['bankaAdi'] ?? txBanka['name'])
                    ?.toString() ??
                _accountNameController.text;
            _selectedHesapId =
                txBanka['bank_account_id'] ??
                txBanka['banka_id'] ??
                _selectedHesapId;
            found = true;
          }
        }
      }

      // 4. SON ÇARE: Kaynak işlem (Kasa/Banka satırı) silinmiş veya bulunamıyor olabilir.
      // Bu durumda Cari Hareket üzerindeki kopyalanmış verilerle formu dolduruyoruz.
      if (!found) {
        debugPrint(
          'Kaynak işlem bulunamadı, Cari Hareket verisiyle dolduruluyor (Fallback)...',
        );
        if (!_userEdited) {
          _fillFormFromCariTransaction(item);
        }

        // [2025 FIX] Eğer kod/ad eksikse ve ID varsa, DB'den çek (Legacy/Eksik veri tamamlama)
        if (_selectedHesapId != null && _accountCodeController.text.isEmpty) {
          try {
            if (_selectedLocation == 'cash') {
              final ks = await KasalarVeritabaniServisi().kasalariGetir(
                kasaId: _selectedHesapId!,
              );
              if (!mounted || loadSeq != _loadSequence) return;
              if (ks.isNotEmpty) {
                _accountCodeController.text = ks.first.kod;
                _accountNameController.text = ks.first.ad;
              }
            } else if (_selectedLocation == 'bank') {
              final bs = await BankalarVeritabaniServisi().bankalariGetir(
                bankaId: _selectedHesapId!,
              );
              if (!mounted || loadSeq != _loadSequence) return;
              if (bs.isNotEmpty) {
                _accountCodeController.text = bs.first.kod;
                _accountNameController.text = bs.first.ad;
              }
            }
          } catch (e) {
            debugPrint('Hesap detay tamamlama hatası: $e');
          }
        }

        found = true;
      }

      if (mounted && loadSeq == _loadSequence) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('HATA: İşlem detayları yüklenemedi: $e');
      if (mounted && loadSeq == _loadSequence) {
        setState(() => _isLoading = false);
        MesajYardimcisi.hataGoster(
          context,
          '${tr('accounts.transaction.error.load_failed')}: $e',
        );
      }
    }
  }

  void _fillFormFromCariTransaction(Map<String, dynamic> item) {
    // Tutar (amount veya tutar anahtarına bak)
    final double tutar =
        double.tryParse((item['amount'] ?? item['tutar'])?.toString() ?? '') ??
        0.0;
    _amountController.text = FormatYardimcisi.sayiFormatlaOndalikli(
      tutar,
      binlik: _genelAyarlar.binlikAyiraci,
      ondalik: _genelAyarlar.ondalikAyiraci,
      decimalDigits: _genelAyarlar.fiyatOndalik,
    );

    // Tarih (date veya tarih anahtarına bak)
    final dynamic tarihRaw = item['date'] ?? item['tarih'];
    if (tarihRaw != null) {
      if (tarihRaw is DateTime) {
        _selectedDate = tarihRaw;
      } else {
        final String dateStr = tarihRaw.toString();
        // UI formatını (dd.MM.yyyy) dene
        try {
          _selectedDate = DateFormat('dd.MM.yyyy').parse(dateStr);
        } catch (_) {
          // ISO formatını dene
          _selectedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
        }
      }
      _dateController.text = DateFormat('dd.MM.yyyy').format(_selectedDate);
    }

    // Açıklama (description veya aciklama anahtarına bak)
    _descriptionController.text =
        (item['description'] ?? item['aciklama'])?.toString() ?? '';

    // Kaynak Bilgisi (Cari harekete kopyalanmışsa)
    _accountNameController.text =
        item['kaynak_adi']?.toString() ??
        item['source_name']?.toString() ??
        'Bilinmeyen Kaynak';
    _accountCodeController.text =
        item['kaynak_kodu']?.toString() ??
        item['source_code']?.toString() ??
        '';

    // [2025 FIX] source_id varsa set et
    final srcId = int.tryParse(item['source_id']?.toString() ?? '');
    if (srcId != null && srcId > 0) {
      _selectedHesapId = srcId;
    }

    // Yön (Alacak/Borç)
    // Cari Alacak (Para Alındı) -> Alacak
    // Cari Borç (Para Verildi) -> Borç
    final String yon =
        item['yon']?.toString() ?? item['type']?.toString() ?? '';
    final bool isAlacak =
        yon.toLowerCase() == 'alacak' ||
        yon.toLowerCase() == 'credit' ||
        yon.toLowerCase() == 'tahsilat';
    _selectedTransactionType = isAlacak ? 'para_al' : 'para_ver';

    // Lokasyon Tahmini
    final srcType =
        (item['source_type'] ?? item['islem_turu'])?.toString().toLowerCase() ??
        '';
    if (srcType.contains('bank')) {
      _selectedLocation = 'bank';
    } else if (srcType.contains('kart') || srcType.contains('credit')) {
      _selectedLocation = 'credit_card';
    } else {
      _selectedLocation = 'cash'; // Varsayılan
    }
  }

  void _fillFormFromTransaction(
    Map<String, dynamic> tx, {
    required bool isKasa,
    bool overwrite = true,
  }) {
    if (overwrite) {
      _selectedHesapId = isKasa
          ? (tx['cash_register_id'] ?? tx['kasa_id'])
          : (tx['bank_account_id'] ?? tx['banka_id']);
      final rawType =
          (tx['islem'] ?? tx['type'])?.toString().toLowerCase() ?? '';
      final isIncoming =
          tx['isIncoming'] == true ||
          rawType.contains('tahsilat') ||
          rawType.contains('para alındı') ||
          rawType.contains('para alindi') ||
          rawType.contains('giriş') ||
          rawType.contains('giris');
      _selectedTransactionType = isIncoming ? 'para_al' : 'para_ver';
    }

    if (overwrite || _amountController.text.trim().isEmpty) {
      _amountController.text = FormatYardimcisi.sayiFormatlaOndalikli(
        tx['tutar'] ?? 0.0,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
        decimalDigits: _genelAyarlar.fiyatOndalik,
      );
    }

    if (overwrite || _dateController.text.trim().isEmpty) {
      DateTime dt = DateTime.now();
      if (tx['tarih'] != null) {
        if (tx['tarih'] is DateTime) {
          dt = tx['tarih'];
        } else {
          dt = DateTime.tryParse(tx['tarih'].toString()) ?? DateTime.now();
        }
      }
      _selectedDate = dt;
      _dateController.text = DateFormat('dd.MM.yyyy').format(dt);
    }

    if (overwrite || _descriptionController.text.trim().isEmpty) {
      _descriptionController.text = tx['aciklama']?.toString() ?? '';
    }

    if (isKasa) {
      if (overwrite || _accountCodeController.text.trim().isEmpty) {
        _accountCodeController.text =
            (tx['kasa_kodu'] ?? tx['kasaKodu'])?.toString() ?? '';
      }
      if (overwrite || _accountNameController.text.trim().isEmpty) {
        _accountNameController.text =
            (tx['kasa_adi'] ?? tx['kasaAdi'])?.toString() ?? '';
      }
    } else {
      if (overwrite || _accountCodeController.text.trim().isEmpty) {
        _accountCodeController.text =
            (tx['banka_kodu'] ?? tx['bankaKodu'])?.toString() ?? '';
      }
      if (overwrite || _accountNameController.text.trim().isEmpty) {
        _accountNameController.text =
            (tx['banka_adi'] ?? tx['bankaAdi'])?.toString() ?? '';
      }
    }
  }

  void _attachPriceFormatter() {
    _amountFocusNode.addListener(() {
      if (!_amountFocusNode.hasFocus) {
        final text = _amountController.text.trim();
        if (text.isEmpty) return;
        final value = FormatYardimcisi.parseDouble(
          text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        );
        final formatted = FormatYardimcisi.sayiFormatlaOndalikli(
          value,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: _genelAyarlar.fiyatOndalik,
        );
        _amountController
          ..text = formatted
          ..selection = TextSelection.collapsed(offset: formatted.length);
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      // Ayarlar gelmeden önceki format bilgisini sakla.
      // (Düzenleme ekranı ilk açıldığında tutar bu formatla doldurulmuş olabilir.)
      final String oldBinlik = _genelAyarlar.binlikAyiraci;
      final String oldOndalik = _genelAyarlar.ondalikAyiraci;

      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      if (mounted) {
        final String currentAmountText = _amountController.text;
        final double? parsedAmount =
            (!_userEdited && currentAmountText.isNotEmpty)
                ? FormatYardimcisi.parseDouble(
                    currentAmountText,
                    binlik: oldBinlik,
                    ondalik: oldOndalik,
                  )
                : null;

        setState(() => _genelAyarlar = settings);

        // Ayarlar yüklendikten sonra tutarı tekrar formatla (özellikle düzenleme modu için)
        if (parsedAmount != null) {
          final formatted = FormatYardimcisi.sayiFormatlaOndalikli(
            parsedAmount,
            binlik: settings.binlikAyiraci,
            ondalik: settings.ondalikAyiraci,
            decimalDigits: settings.fiyatOndalik,
          );
          _amountController
            ..text = formatted
            ..selection = TextSelection.collapsed(offset: formatted.length);
        }

        // Yeni kayıt ise varsayılan kasayı yükle
        if (widget.duzenlenecekIslem == null) {
          final varsayilanKasa = await KasalarVeritabaniServisi()
              .varsayilanKasaGetir();
          if (varsayilanKasa != null && mounted) {
            setState(() {
              _accountCodeController.text = varsayilanKasa.kod;
              _accountNameController.text = varsayilanKasa.ad;
              _selectedHesapId = varsayilanKasa.id;
              _selectedLocation = 'cash';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Ayarlar yüklenirken hata: $e');
    }
  }

  void _markUserEdited() {
    if (_isEditing) _userEdited = true;
  }

  void _resetFormState() {
    _loadSequence++;
    _isEditing = false;
    _selectedTransactionType = 'para_al';
    _selectedLocation = 'cash';
    _selectedDate = DateTime.now();
    _selectedHesapId = null;
    _userEdited = false;
    _dateController.clear();
    _accountCodeController.clear();
    _accountNameController.clear();
    _amountController.clear();
    _descriptionController.clear();
  }

  void _closePage([bool? result]) {
    if (!mounted) return;
    _resetFormState();
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _resetFormState();
    _dateController.dispose();
    _accountCodeController.dispose();
    _accountNameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _accountCodeFocusNode.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _clearAccountFields() {
    setState(() {
      _accountCodeController.clear();
      _accountNameController.clear();
      _selectedHesapId = null;
    });
  }

  Future<void> _openSearchDialog() async {
    switch (_selectedLocation) {
      case 'cash':
        _showKasaSearchDialog();
        break;
      case 'bank':
        _showBankaSearchDialog();
        break;
      case 'credit_card':
        _showKrediKartiSearchDialog();
        break;
    }
  }

  void _showKasaSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _KasaSearchDialog(
        onSelect: (kasa) {
          setState(() {
            _accountCodeController.text = kasa.kod;
            _accountNameController.text = kasa.ad;
            _selectedHesapId = kasa.id;
          });
          _markUserEdited();
        },
      ),
    );
  }

  void _showBankaSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _BankaSearchDialog(
        onSelect: (banka) {
          setState(() {
            _accountCodeController.text = banka.kod;
            _accountNameController.text = banka.ad;
            _selectedHesapId = banka.id;
          });
          _markUserEdited();
        },
      ),
    );
  }

  void _showKrediKartiSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => _KrediKartiSearchDialog(
        onSelect: (kart) {
          setState(() {
            _accountCodeController.text = kart.kod;
            _accountNameController.text = kart.ad;
            _selectedHesapId = kart.id;
          });
          _markUserEdited();
        },
      ),
    );
  }

  Future<int?> _resolveSelectedHesapId() async {
    final code = _accountCodeController.text.trim();
    if (code.isEmpty) return null;

    switch (_selectedLocation) {
      case 'cash':
        final kasalar = await KasalarVeritabaniServisi().kasaAra(
          code,
          limit: 1,
        );
        return kasalar.isEmpty ? null : kasalar.first.id;
      case 'bank':
        final bankalar = await BankalarVeritabaniServisi().bankaAra(
          code,
          limit: 1,
        );
        return bankalar.isEmpty ? null : bankalar.first.id;
      case 'credit_card':
        final kartlar = await KrediKartlariVeritabaniServisi().krediKartiAra(
          code,
          limit: 1,
        );
        return kartlar.isEmpty ? null : kartlar.first.id;
      default:
        return null;
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => TekTarihSeciciDialog(
        initialDate: _selectedDate,
        title: tr('cashregisters.transaction.date'),
      ),
    );
    if (picked != null) {
      final now = DateTime.now();
      final DateTime dateWithTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        now.hour,
        now.minute,
      );

      if (dateWithTime != _selectedDate) {
        setState(() {
          _selectedDate = dateWithTime;
          _dateController.text = DateFormat('dd.MM.yyyy').format(dateWithTime);
        });
      }
      _markUserEdited();
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that location account is selected
    if (_accountCodeController.text.trim().isEmpty) {
      MesajYardimcisi.hataGoster(context, tr('validation.required'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final currentUser = prefs.getString('current_username') ?? 'Sistem';

      final double amount = FormatYardimcisi.parseDouble(
        _amountController.text,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );

      // Resolve hesap ID if not already set
      final int? hedefId = _selectedHesapId ?? await _resolveSelectedHesapId();
      if (hedefId == null) {
        if (mounted) {
          String errorMsg = '';
          switch (_selectedLocation) {
            case 'cash':
              errorMsg = tr('cashregisters.no_cashregisters_found');
              break;
            case 'bank':
              errorMsg = tr('banks.no_banks_found');
              break;
            case 'credit_card':
              errorMsg = tr('creditcards.no_creditcards_found');
              break;
          }
          MesajYardimcisi.hataGoster(context, errorMsg);
          setState(() => _isLoading = false);
        }
        return;
      }

      // [2025 ELITE] Master Service Call
      final cariServis = CariHesaplarVeritabaniServisi();
      await cariServis.cariParaAlVerKaydet(
        cariId: widget.cari.id,
        tutar: amount,
        islemTipi: _selectedTransactionType,
        lokasyon: _selectedLocation,
        hedefId: hedefId,
        aciklama: _descriptionController.text.trim(),
        tarih: _selectedDate,
        kullanici: currentUser,
        kaynakAdi: _accountNameController.text,
        kaynakKodu: _accountCodeController.text,
        cariAdi: widget.cari.adi,
        cariKodu: widget.cari.kodNo,
        duzenlenecekIslem: _isEditing ? widget.duzenlenecekIslem : null,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        MesajYardimcisi.basariGoster(context, tr('common.saved_successfully'));
        SayfaSenkronizasyonServisi().veriDegisti('cari');
        _closePage(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _closePage();
        },
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_isLoading) _handleSave();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_isLoading) _handleSave();
        },
      },
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Focus(
          autofocus: true,
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
                  Text(tr('common.esc'),
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
                _isEditing
                    ? '${tr('accounts.transaction.money_exchange')} ${tr('common.edit')}'
                    : tr('accounts.transaction.money_exchange'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 21,
                ),
              ),
              centerTitle: false,
            ),
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 850),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(theme),
                              const SizedBox(height: 32),
                              _buildSection(
                                theme,
                                title: isEditingTitle(),
                                child: _buildFormFields(theme),
                                icon: Icons.currency_exchange_rounded,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildBottomBar(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String isEditingTitle() {
    return _isEditing
        ? '${tr('accounts.transaction.money_exchange')} ${tr('common.edit')}'
        : tr('accounts.transaction.money_exchange');
  }

  Widget _buildHeader(ThemeData theme) {
    final bakiye = widget.cari.bakiyeBorc - widget.cari.bakiyeAlacak;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('accounts.form.code'),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.cari.kodNo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF202124),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 40, width: 1, color: Colors.grey.shade300),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('accounts.form.name'),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.cari.adi,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF202124),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(height: 40, width: 1, color: Colors.grey.shade300),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  tr('accounts.table.balance'),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${FormatYardimcisi.sayiFormatlaOndalikli(bakiye.abs(), binlik: _genelAyarlar.binlikAyiraci, ondalik: _genelAyarlar.ondalikAyiraci, decimalDigits: _genelAyarlar.fiyatOndalik)} ${widget.cari.paraBirimi}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: bakiye >= 0
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required String title,
    required Widget child,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  fontSize: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildFormFields(ThemeData theme) {
    final requiredColor = Colors.red.shade700;
    final optionalColor = Colors.blue.shade700;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Column(
          children: [
            // İşlem Tipi (Para Al / Para Ver)
            _buildDropdown<String>(
              value: _selectedTransactionType,
              label: tr('products.transaction.type'),
              items: _transactionTypeOptions.map((e) => e['value']!).toList(),
              itemLabels: Map.fromEntries(
                _transactionTypeOptions.map(
                  (e) => MapEntry(e['value']!, tr(e['key']!)),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _selectedTransactionType = val!;
                });
                _markUserEdited();
              },
              isRequired: true,
              color: requiredColor,
            ),
            const SizedBox(height: 16),
            // Yer (Kasa / Banka / Kredi Kartı)
            _buildDropdown<String>(
              value: _selectedLocation,
              label: tr('accounts.transaction.location'),
              items: _locationOptions.map((e) => e['value']!).toList(),
              itemLabels: Map.fromEntries(
                _locationOptions.map(
                  (e) => MapEntry(e['value']!, tr(e['key']!)),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _selectedLocation = val!;
                  _clearAccountFields();
                });
                _markUserEdited();
              },
              isRequired: true,
              color: requiredColor,
            ),
            const SizedBox(height: 16),
            // Hesap Kodu & Hesap Adı
            _buildRow(isWide, [
              _buildAutocompleteField(
                controller: _accountCodeController,
                label: tr('cashregisters.transaction.account_code'),
                isRequired: true,
                color: requiredColor,
                focusNode: _accountCodeFocusNode,
              ),
              _buildTextField(
                controller: _accountNameController,
                label: tr('cashregisters.transaction.account_name'),
                isRequired: true,
                color: requiredColor,
                readOnly: true,
                noGrayBackground: true,
              ),
            ]),
            const SizedBox(height: 16),
            // Tutar & Tarih
            _buildRow(isWide, [
              _buildTextField(
                controller: _amountController,
                label: tr('cashregisters.transaction.amount'),
                isNumeric: true,
                isRequired: true,
                color: requiredColor,
                focusNode: _amountFocusNode,
                onChanged: (_) => _markUserEdited(),
              ),
              _buildDateField(
                controller: _dateController,
                label: tr('cashregisters.transaction.date'),
                onTap: _selectDate,
                isRequired: true,
                color: requiredColor,
              ),
            ]),
            const SizedBox(height: 16),
            // Açıklama
            AkilliAciklamaInput(
              controller: _descriptionController,
              label: tr('cashregisters.transaction.description'),
              category: 'cari_money_exchange_description',
              color: optionalColor,
              onChanged: (_) => _markUserEdited(),
              defaultItems: [
                tr('smart_select.cash_deposit.desc.1'),
                tr('smart_select.cash_deposit.desc.2'),
                tr('smart_select.cash_deposit.desc.3'),
                tr('smart_select.cash_deposit.desc.4'),
                tr('smart_select.cash_deposit.desc.5'),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16.0),
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
          constraints: const BoxConstraints(maxWidth: 850),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _closePage,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  tr('common.cancel'),
                  style: const TextStyle(
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA4335),
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
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tr('common.save'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildRow(bool isWide, List<Widget> children) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.asMap().entries.map<Widget>((entry) {
          final isLast = entry.key == children.length - 1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : 16),
              child: entry.value,
            ),
          );
        }).toList(),
      );
    } else {
      return Column(
        children: children
            .map(
              (c) =>
                  Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
            )
            .toList(),
      );
    }
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String label,
    required bool isRequired,
    required Color color,
    FocusNode? focusNode,
  }) {
    final theme = Theme.of(context);

    // Helpers to get data based on source
    Future<Iterable<Map<String, String>>> search(String query) async {
      if (query.isEmpty) return [];

      try {
        List<Map<String, String>> results = [];

        switch (_selectedLocation) {
          case 'cash':
            final items = await KasalarVeritabaniServisi().kasalariGetir(
              aramaKelimesi: query,
              sayfaBasinaKayit: 10,
            );
            results = items
                .where((e) => e.aktifMi)
                .map(
                  (e) => {
                    'code': e.kod,
                    'name': e.ad,
                    'type': 'Kasa',
                    'id': e.id.toString(),
                    'address': '',
                  },
                )
                .toList();
            break;

          case 'bank':
            final items = await BankalarVeritabaniServisi().bankalariGetir(
              aramaKelimesi: query,
              sayfaBasinaKayit: 10,
            );
            results = items
                .where((e) => e.aktifMi)
                .map(
                  (e) => {
                    'code': e.kod,
                    'name': e.ad,
                    'type': 'Banka',
                    'id': e.id.toString(),
                    'address': '',
                  },
                )
                .toList();
            break;

          case 'credit_card':
            final items = await KrediKartlariVeritabaniServisi()
                .krediKartlariniGetir(
                  aramaKelimesi: query,
                  sayfaBasinaKayit: 10,
                );
            results = items
                .where((e) => e.aktifMi)
                .map(
                  (e) => {
                    'code': e.kod,
                    'name': e.ad,
                    'type': 'Kredi Kartı',
                    'id': e.id.toString(),
                    'address': '',
                  },
                )
                .toList();
            break;

          default:
            return [];
        }
        return results;
      } catch (e) {
        debugPrint('Arama hatası: $e');
        return [];
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isRequired ? '$label *' : label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              tr('common.search_fields.code_name'),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        RawAutocomplete<Map<String, String>>(
          focusNode: focusNode,
          textEditingController: controller,
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.isEmpty) return [];
            return await search(textEditingValue.text);
          },
          displayStringForOption: (option) => option['code']!,
          onSelected: (option) {
            setState(() {
              controller.text = option['code']!;
              _accountNameController.text = option['name']!;
              _selectedHesapId = int.tryParse(option['id'] ?? '');
            });
            _markUserEdited();
          },
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                  validator: isRequired
                      ? (value) {
                          if (value == null || value.isEmpty) {
                            return tr('validation.required');
                          }
                          return null;
                        }
                      : null,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(Icons.search, color: color),
                      onPressed: _openSearchDialog,
                    ),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: color.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: color.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: color, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (_) => _markUserEdited(),
                  onFieldSubmitted: (value) => onFieldSubmitted(),
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 250,
                    maxWidth: 400,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option['name']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Color(0xFF202124),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${option['code']!}${option['address'] != null && option['address']!.isNotEmpty ? ' • ${option['address']}' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isNumeric = false,
    bool isRequired = false,
    Color? color,
    String? hint,
    FocusNode? focusNode,
    bool readOnly = false,
    bool noGrayBackground = false,
    ValueChanged<String>? onChanged,
    String? errorText,
    String? suffix,
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          keyboardType: isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
          maxLines: maxLines,
          inputFormatters: isNumeric
              ? [
                  CurrencyInputFormatter(
                    binlik: _genelAyarlar.binlikAyiraci,
                    ondalik: _genelAyarlar.ondalikAyiraci,
                    maxDecimalDigits: _genelAyarlar.fiyatOndalik,
                  ),
                  LengthLimitingTextInputFormatter(20),
                ]
              : [LengthLimitingTextInputFormatter(200)],
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return tr('validation.required');
            }
            return null;
          },
          onChanged: onChanged,
          decoration: InputDecoration(
            errorText: errorText,
            hintText: hint,
            suffixText: suffix,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.withValues(alpha: 0.3),
              fontSize: 16,
            ),
            filled: readOnly && !noGrayBackground,
            fillColor: Colors.grey.shade100,
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color: effectiveColor.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: effectiveColor.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: effectiveColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
    bool isRequired = false,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                mouseCursor: SystemMouseCursors.click,
                child: IgnorePointer(
                  child: TextFormField(
                    controller: controller,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
                    validator: (value) {
                      if (isRequired && (value == null || value.isEmpty)) {
                        return tr('validation.required');
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: tr('common.placeholder.date'),
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.withValues(alpha: 0.3),
                        fontSize: 16,
                      ),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: effectiveColor.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: effectiveColor.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: effectiveColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 20, color: Colors.red),
                onPressed: () {
                  setState(() {
                    controller.clear();
                  });
                  _markUserEdited();
                },
                tooltip: tr('common.clear'),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: effectiveColor,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String label,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    bool isRequired = false,
    Color? color,
    Map<T, String>? itemLabels,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$label *' : label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          initialValue: items.contains(value) ? value : null,
          decoration: InputDecoration(
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.withValues(alpha: 0.3),
              fontSize: 16,
            ),
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color: effectiveColor.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: effectiveColor.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: effectiveColor, width: 2),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemLabels?[item] ?? item.toString(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down, color: effectiveColor),
          validator: isRequired
              ? (value) {
                  if (value == null) {
                    return tr('validation.required');
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }
}

// ===================== SEARCH DIALOGS =====================

// --- KASA SEARCH DIALOG ---
class _KasaSearchDialog extends StatefulWidget {
  final Function(KasaModel) onSelect;
  const _KasaSearchDialog({required this.onSelect});

  @override
  State<_KasaSearchDialog> createState() => _KasaSearchDialogState();
}

class _KasaSearchDialogState extends State<_KasaSearchDialog> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<KasaModel> _items = [];
  bool _isLoading = false;
  Timer? _debounce;
  static const Color _primaryColor = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    _search('');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await KasalarVeritabaniServisi().kasalariGetir(
        aramaKelimesi: query,
      );
      if (mounted) {
        setState(() {
          _items = results.where((k) => k.aktifMi).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
        child: Column(
          children: [
            _buildDialogHeader(
              tr('cashregisters.search_title'),
              tr('cashregisters.search_subtitle'),
            ),
            const SizedBox(height: 24),
            _buildSearchInput(),
            const SizedBox(height: 20),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF606368),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('common.esc'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9AA0A6),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.close, size: 22, color: Color(0xFF3C4043)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('common.search'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A4A4A),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
          decoration: InputDecoration(
            hintText: tr('cashregisters.search_placeholder'),
            prefixIcon: const Icon(
              Icons.search,
              size: 20,
              color: Color(0xFFBDC1C6),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 48,
              color: Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 16),
            Text(
              tr('cashregisters.no_cashregisters_found'),
              style: const TextStyle(fontSize: 16, color: Color(0xFF606368)),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
      itemBuilder: (context, index) {
        final item = _items[index];
        return InkWell(
          onTap: () {
            widget.onSelect(item);
            Navigator.pop(context);
          },
          hoverColor: const Color(0xFFF5F7FA),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.ad,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.kod,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF606368),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Color(0xFFBDC1C6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- BANKA SEARCH DIALOG ---
class _BankaSearchDialog extends StatefulWidget {
  final Function(BankaModel) onSelect;
  const _BankaSearchDialog({required this.onSelect});

  @override
  State<_BankaSearchDialog> createState() => _BankaSearchDialogState();
}

class _BankaSearchDialogState extends State<_BankaSearchDialog> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<BankaModel> _items = [];
  bool _isLoading = false;
  Timer? _debounce;
  static const Color _primaryColor = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    _search('');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await BankalarVeritabaniServisi().bankalariGetir(
        aramaKelimesi: query,
      );
      if (mounted) {
        setState(() {
          _items = results.where((b) => b.aktifMi).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
        child: Column(
          children: [
            _buildDialogHeader(
              tr('banks.search_title'),
              tr('banks.search_subtitle'),
            ),
            const SizedBox(height: 24),
            _buildSearchInput(),
            const SizedBox(height: 20),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF606368),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('common.esc'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9AA0A6),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.close, size: 22, color: Color(0xFF3C4043)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('common.search'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A4A4A),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
          decoration: InputDecoration(
            hintText: tr('banks.search_placeholder'),
            prefixIcon: const Icon(
              Icons.search,
              size: 20,
              color: Color(0xFFBDC1C6),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_outlined,
              size: 48,
              color: Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 16),
            Text(
              tr('banks.no_banks_found'),
              style: const TextStyle(fontSize: 16, color: Color(0xFF606368)),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
      itemBuilder: (context, index) {
        final item = _items[index];
        return InkWell(
          onTap: () {
            widget.onSelect(item);
            Navigator.pop(context);
          },
          hoverColor: const Color(0xFFF5F7FA),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.ad,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.kod,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF606368),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Color(0xFFBDC1C6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- KREDİ KARTI SEARCH DIALOG ---
class _KrediKartiSearchDialog extends StatefulWidget {
  final Function(KrediKartiModel) onSelect;
  const _KrediKartiSearchDialog({required this.onSelect});

  @override
  State<_KrediKartiSearchDialog> createState() =>
      _KrediKartiSearchDialogState();
}

class _KrediKartiSearchDialogState extends State<_KrediKartiSearchDialog> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<KrediKartiModel> _items = [];
  bool _isLoading = false;
  Timer? _debounce;
  static const Color _primaryColor = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    _search('');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await KrediKartlariVeritabaniServisi()
          .krediKartlariniGetir(aramaKelimesi: query);
      if (mounted) {
        setState(() {
          _items = results.where((k) => k.aktifMi).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
        child: Column(
          children: [
            _buildDialogHeader(
              tr('creditcards.search_title'),
              tr('creditcards.search_subtitle'),
            ),
            const SizedBox(height: 24),
            _buildSearchInput(),
            const SizedBox(height: 20),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF606368),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('common.esc'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9AA0A6),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.close, size: 22, color: Color(0xFF3C4043)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('common.search'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A4A4A),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
          decoration: InputDecoration(
            hintText: tr('creditcards.search_placeholder'),
            prefixIcon: const Icon(
              Icons.search,
              size: 20,
              color: Color(0xFFBDC1C6),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.credit_card_outlined,
              size: 48,
              color: Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 16),
            Text(
              tr('creditcards.no_creditcards_found'),
              style: const TextStyle(fontSize: 16, color: Color(0xFF606368)),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
      itemBuilder: (context, index) {
        final item = _items[index];
        return InkWell(
          onTap: () {
            widget.onSelect(item);
            Navigator.pop(context);
          },
          hoverColor: const Color(0xFFF5F7FA),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.credit_card,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.ad,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.kod,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF606368),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Color(0xFFBDC1C6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
