import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../ayarlar/genel_ayarlar/modeller/genel_ayarlar_model.dart';
import '../../yardimcilar/format_yardimcisi.dart';
import 'modeller/cari_hesap_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../servisler/sayfa_senkronizasyon_servisi.dart';

class CariHesapEkleSayfasi extends StatefulWidget {
  const CariHesapEkleSayfasi({super.key, this.cariHesap});

  final CariHesapModel? cariHesap;

  @override
  State<CariHesapEkleSayfasi> createState() => _CariHesapEkleSayfasiState();
}

class _CariHesapEkleSayfasiState extends State<CariHesapEkleSayfasi> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  GenelAyarlarModel _genelAyarlar = GenelAyarlarModel();
  String? _codeError;

  // Temel Bilgiler
  final _kodNoController = TextEditingController();
  final _adiController = TextEditingController();
  String? _selectedHesapTuru = 'Alıcı';
  String _selectedParaBirimi = 'TRY';
  String? _selectedSfGrubu = 'Satış Fiyatı 1';
  final _sIskontoController = TextEditingController();
  final _vadeGunController = TextEditingController();
  final _riskLimitiController = TextEditingController();
  String _bakiyeDurumu = 'Borç';
  final _bakiyeController = TextEditingController();

  // İletişim
  final _telefon1Controller = TextEditingController();
  final _telefon2Controller = TextEditingController();
  final _epostaController = TextEditingController();
  final _webAdresiController = TextEditingController();

  // Fatura Bilgileri
  final _fatUnvaniController = TextEditingController();
  final _fatAdresiController = TextEditingController();
  final _fatIlceController = TextEditingController();
  final _fatSehirController = TextEditingController();
  final _postaKoduController = TextEditingController();
  final _vDairesiController = TextEditingController();
  final _vNumarasiController = TextEditingController();

  // Bilgi Alanları (5 adet)
  final List<TextEditingController> _bilgiControllers = [];

  // Sevk Adresleri (5 adet)
  final List<Map<String, TextEditingController>> _sevkAdresleri = [];

  // Resimler
  final List<String> _selectedImages = [];

  // Dropdown Data
  List<String> _hesapTurleri = ['Alıcı', 'Satıcı', 'Alıcı/Satıcı'];
  List<String> _sfGruplari = [];

  // Focus Nodes
  late FocusNode _kodNoFocusNode;
  late FocusNode _adiControllerFocusNode;
  late FocusNode _sIskontoFocusNode;
  late FocusNode _vadeGunFocusNode;
  late FocusNode _riskLimitiFocusNode;
  late FocusNode _bakiyeFocusNode;

  // İletişim Focus Nodes
  late FocusNode _telefon1FocusNode;
  late FocusNode _telefon2FocusNode;
  late FocusNode _epostaFocusNode;
  late FocusNode _webAdresiFocusNode;

  // Fatura Focus Nodes
  late FocusNode _fatUnvaniFocusNode;
  late FocusNode _fatAdresiFocusNode;
  late FocusNode _fatIlceFocusNode;
  late FocusNode _fatSehirFocusNode;
  late FocusNode _postaKoduFocusNode;
  late FocusNode _vDairesiFocusNode;
  late FocusNode _vNumarasiFocusNode;

  // Dropdown Focus Nodes
  late FocusNode _hesapTuruFocusNode;
  late FocusNode _paraBirimiFocusNode;
  late FocusNode _sfGrubuFocusNode;
  late FocusNode _bakiyeDurumuFocusNode;

  final FocusNode _pageFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _kodNoFocusNode = FocusNode();
    _adiControllerFocusNode = FocusNode();
    _sIskontoFocusNode = FocusNode();
    _vadeGunFocusNode = FocusNode();
    _riskLimitiFocusNode = FocusNode();
    _bakiyeFocusNode = FocusNode();

    _telefon1FocusNode = FocusNode();
    _telefon2FocusNode = FocusNode();
    _epostaFocusNode = FocusNode();
    _webAdresiFocusNode = FocusNode();

    _fatUnvaniFocusNode = FocusNode();
    _fatAdresiFocusNode = FocusNode();
    _fatIlceFocusNode = FocusNode();
    _fatSehirFocusNode = FocusNode();
    _postaKoduFocusNode = FocusNode();
    _vDairesiFocusNode = FocusNode();
    _vNumarasiFocusNode = FocusNode();

    _hesapTuruFocusNode = FocusNode();
    _paraBirimiFocusNode = FocusNode();
    _sfGrubuFocusNode = FocusNode();
    _bakiyeDurumuFocusNode = FocusNode();

    _attachPriceFormatter(_riskLimitiFocusNode, _riskLimitiController);
    _attachPriceFormatter(_bakiyeFocusNode, _bakiyeController);
    _attachPercentFormatter(_sIskontoFocusNode, _sIskontoController);

    if (widget.cariHesap != null) {
      _populateForm();
    }

    // Ayarları yükle ve tamamlandığında formu göster + focus ayarla
    _initializeAndFocus();
  }

  void _attachPriceFormatter(
    FocusNode focusNode,
    TextEditingController controller,
  ) {
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        final text = controller.text.trim();
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
        controller
          ..text = formatted
          ..selection = TextSelection.collapsed(offset: formatted.length);
      }
    });
  }

  void _attachPercentFormatter(
    FocusNode focusNode,
    TextEditingController controller,
  ) {
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        final text = controller.text.trim();
        if (text.isEmpty) return;
        final value = FormatYardimcisi.parseDouble(
          text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        );
        final formatted = FormatYardimcisi.sayiFormatlaOran(
          value,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
          decimalDigits: 2,
        );
        controller
          ..text = formatted
          ..selection = TextSelection.collapsed(offset: formatted.length);
      }
    });
  }

  void _populateForm() {
    final cari = widget.cariHesap!;
    _kodNoController.text = cari.kodNo;
    _adiController.text = cari.adi;
    _selectedHesapTuru = cari.hesapTuru.isNotEmpty ? cari.hesapTuru : null;
    _selectedParaBirimi = cari.paraBirimi;
    _selectedSfGrubu = cari.sfGrubu.isNotEmpty ? cari.sfGrubu : null;
    _sIskontoController.text = cari.sIskonto > 0
        ? FormatYardimcisi.sayiFormatlaOran(
            cari.sIskonto,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: 2,
          )
        : '';
    _vadeGunController.text = cari.vadeGun > 0 ? cari.vadeGun.toString() : '';
    _riskLimitiController.text = cari.riskLimiti > 0
        ? FormatYardimcisi.sayiFormatlaOndalikli(
            cari.riskLimiti,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: _genelAyarlar.fiyatOndalik,
          )
        : '';
    _bakiyeDurumu = cari.bakiyeDurumu;
    final bakiye = cari.bakiyeDurumu == 'Borç'
        ? cari.bakiyeBorc
        : cari.bakiyeAlacak;
    _bakiyeController.text = bakiye > 0
        ? FormatYardimcisi.sayiFormatlaOndalikli(
            bakiye,
            binlik: _genelAyarlar.binlikAyiraci,
            ondalik: _genelAyarlar.ondalikAyiraci,
            decimalDigits: _genelAyarlar.fiyatOndalik,
          )
        : '';

    _telefon1Controller.text = cari.telefon1;
    _telefon2Controller.text = cari.telefon2;
    _epostaController.text = cari.eposta;
    _webAdresiController.text = cari.webAdresi;

    _fatUnvaniController.text = cari.fatUnvani;
    _fatAdresiController.text = cari.fatAdresi;
    _fatIlceController.text = cari.fatIlce;
    _fatSehirController.text = cari.fatSehir;
    _postaKoduController.text = cari.postaKodu;
    _vDairesiController.text = cari.vDairesi;
    _vNumarasiController.text = cari.vNumarasi;

    // Bilgi alanları
    final bilgiler = [
      cari.bilgi1,
      cari.bilgi2,
      cari.bilgi3,
      cari.bilgi4,
      cari.bilgi5,
    ];
    for (final bilgi in bilgiler) {
      if (bilgi.isNotEmpty) {
        _bilgiControllers.add(TextEditingController(text: bilgi));
      }
    }

    // Sevk adresleri
    if (cari.sevkAdresleri.isNotEmpty) {
      try {
        final List<dynamic> adrList = jsonDecode(cari.sevkAdresleri);
        for (var adr in adrList) {
          _sevkAdresleri.add({
            'adres': TextEditingController(text: adr['adres'] ?? ''),
            'ilce': TextEditingController(text: adr['ilce'] ?? ''),
            'sehir': TextEditingController(text: adr['sehir'] ?? ''),
          });
        }
      } catch (_) {}
    }

    // Resimler
    _selectedImages.addAll(cari.resimler);
  }

  /// Sayfa açıldığında ayarları ve kodu PARALEL yükler.
  /// Form ANINDA gösterilir, async işlemler arka planda çalışır.
  Future<void> _initializeAndFocus() async {
    // Düzenleniyorsa veya kod zaten doluysa focus'u hemen ayarla
    if (widget.cariHesap != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _adiControllerFocusNode.requestFocus();
      });
      // Ayarları arka planda yükle (form zaten hazır)
      _loadSettings();
      return;
    }

    // Yeni kayıt: Ayarları ve listeleri paralel yükle
    try {
      // Paralel: Ayarlar + listeler aynı anda çekilir
      final results = await Future.wait([
        AyarlarVeritabaniServisi().genelAyarlariGetir(),
        CariHesaplarVeritabaniServisi().sfGruplariniGetir(),
        CariHesaplarVeritabaniServisi().hesapTurleriniGetir(),
      ]);

      if (!mounted) return;

      final settings = results[0] as GenelAyarlarModel;
      final sfGruplariDb = results[1] as List<String>;
      final hesapTurleri = results[2] as List<String>;

      String? yeniKod;
      if (settings.otoCariKodu) {
        yeniKod = await CariHesaplarVeritabaniServisi().siradakiCariKoduGetir(
          alfanumerik: settings.otoCariKoduAlfanumerik,
        );
      }

      // SF Grupları
      final List<String> sfGruplari = List.from(sfGruplariDb);
      const defaultPrices = [
        'Satış Fiyatı 1',
        'Satış Fiyatı 2',
        'Satış Fiyatı 3',
      ];
      for (final price in defaultPrices) {
        if (!sfGruplari.contains(price)) sfGruplari.add(price);
      }

      // Hesap Türleri
      final Set<String> tumTurler = {'Alıcı', 'Satıcı', 'Alıcı/Satıcı'};
      tumTurler.addAll(hesapTurleri);

      // Para birimi
      String currency = settings.varsayilanParaBirimi;
      if (currency == 'TL') currency = 'TRY';

      setState(() {
        _genelAyarlar = settings;
        _sfGruplari = sfGruplari;
        _hesapTurleri = tumTurler.toList();
        _selectedParaBirimi = currency;
        // Otomatik kod aktifse set et
        if (yeniKod != null && _kodNoController.text.isEmpty) {
          _kodNoController.text = yeniKod;
        }
      });

      // Focus'u ayarla (kod doluysa -> adı, değilse -> kod)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_kodNoController.text.isNotEmpty) {
          _adiControllerFocusNode.requestFocus();
        } else {
          _kodNoFocusNode.requestFocus();
        }
      });
    } catch (e) {
      debugPrint('Başlatma hatası: $e');
      // Hata olsa bile focus'u ayarla
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _kodNoFocusNode.requestFocus();
      });
    }
  }

  Future<void> _loadSettings() async {
    final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
    final sfGruplariDb = await CariHesaplarVeritabaniServisi()
        .sfGruplariniGetir();

    // Add default sales prices if not present
    final List<String> sfGruplari = List.from(sfGruplariDb);
    const defaultPrices = [
      'Satış Fiyatı 1',
      'Satış Fiyatı 2',
      'Satış Fiyatı 3',
    ];
    for (final price in defaultPrices) {
      if (!sfGruplari.contains(price)) {
        sfGruplari.add(price);
      }
    }

    final hesapTurleri = await CariHesaplarVeritabaniServisi()
        .hesapTurleriniGetir();

    // Varsayılan türleri garanti et ve gelenleri ekle
    final Set<String> tumTurler = {'Alıcı', 'Satıcı', 'Alıcı/Satıcı'};
    tumTurler.addAll(hesapTurleri);

    if (mounted) {
      setState(() {
        _genelAyarlar = settings;
        _sfGruplari = sfGruplari;
        _hesapTurleri = tumTurler.toList();

        String currency = settings.varsayilanParaBirimi;
        if (currency == 'TL') currency = 'TRY';
        _selectedParaBirimi = currency;

        // Düzenleme modunda değerleri tekrar formatla (ayarlar yüklendiği için)
        if (widget.cariHesap != null) {
          final cari = widget.cariHesap!;
          if (cari.riskLimiti > 0) {
            _riskLimitiController.text = FormatYardimcisi.sayiFormatlaOndalikli(
              cari.riskLimiti,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
              decimalDigits: _genelAyarlar.fiyatOndalik,
            );
          }
          final bakiye = cari.bakiyeDurumu == 'Borç'
              ? cari.bakiyeBorc
              : cari.bakiyeAlacak;
          if (bakiye > 0) {
            _bakiyeController.text = FormatYardimcisi.sayiFormatlaOndalikli(
              bakiye,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
              decimalDigits: _genelAyarlar.fiyatOndalik,
            );
          }
          if (cari.sIskonto > 0) {
            _sIskontoController.text = FormatYardimcisi.sayiFormatlaOran(
              cari.sIskonto,
              binlik: _genelAyarlar.binlikAyiraci,
              ondalik: _genelAyarlar.ondalikAyiraci,
              decimalDigits: 2,
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _kodNoFocusNode.dispose();
    _adiControllerFocusNode.dispose();
    _sIskontoFocusNode.dispose();
    _vadeGunFocusNode.dispose();
    _riskLimitiFocusNode.dispose();
    _bakiyeFocusNode.dispose();

    _telefon1FocusNode.dispose();
    _telefon2FocusNode.dispose();
    _epostaFocusNode.dispose();
    _webAdresiFocusNode.dispose();

    _fatUnvaniFocusNode.dispose();
    _fatAdresiFocusNode.dispose();
    _fatIlceFocusNode.dispose();
    _fatSehirFocusNode.dispose();
    _postaKoduFocusNode.dispose();
    _vDairesiFocusNode.dispose();
    _vNumarasiFocusNode.dispose();
    _hesapTuruFocusNode.dispose();
    _paraBirimiFocusNode.dispose();
    _sfGrubuFocusNode.dispose();
    _bakiyeDurumuFocusNode.dispose();
    _kodNoController.dispose();
    _adiController.dispose();
    _sIskontoController.dispose();
    _vadeGunController.dispose();
    _riskLimitiController.dispose();
    _bakiyeController.dispose();
    _telefon1Controller.dispose();
    _telefon2Controller.dispose();
    _epostaController.dispose();
    _webAdresiController.dispose();
    _fatUnvaniController.dispose();
    _fatAdresiController.dispose();
    _fatIlceController.dispose();
    _fatSehirController.dispose();
    _postaKoduController.dispose();
    _vDairesiController.dispose();
    _vNumarasiController.dispose();
    for (var c in _bilgiControllers) {
      c.dispose();
    }
    for (var adr in _sevkAdresleri) {
      adr['adres']?.dispose();
      adr['ilce']?.dispose();
      adr['sehir']?.dispose();
    }
    _pageFocusNode.dispose();
    super.dispose();
  }

  void _addBilgiRow() {
    if (_bilgiControllers.length >= 5) return;
    setState(() {
      _bilgiControllers.add(TextEditingController());
    });
  }

  void _removeBilgiRow(int index) {
    setState(() {
      _bilgiControllers[index].dispose();
      _bilgiControllers.removeAt(index);
    });
  }

  void _addSevkAdresiRow() {
    if (_sevkAdresleri.length >= 5) return;
    setState(() {
      _sevkAdresleri.add({
        'adres': TextEditingController(),
        'ilce': TextEditingController(),
        'sehir': TextEditingController(),
      });
    });
  }

  void _removeSevkAdresiRow(int index) {
    setState(() {
      _sevkAdresleri[index]['adres']?.dispose();
      _sevkAdresleri[index]['ilce']?.dispose();
      _sevkAdresleri[index]['sehir']?.dispose();
      _sevkAdresleri.removeAt(index);
    });
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) {
      MesajYardimcisi.uyariGoster(context, tr('products.form.images.limit'));
      return;
    }
    try {
      final XTypeGroup typeGroup = XTypeGroup(
        label: tr('common.images'),
        extensions: <String>['jpg', 'png', 'jpeg'],
        uniformTypeIdentifiers: ['public.image'],
      );
      final List<XFile> files = await openFiles(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );
      if (files.isNotEmpty) {
        for (final file in files) {
          if (_selectedImages.length >= 5) break;
          final bytes = await file.readAsBytes();
          final base64Image = base64Encode(bytes);
          setState(() {
            _selectedImages.add(base64Image);
          });
        }
      }
    } catch (e) {
      debugPrint('Resim seçme hatası: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _handleSave() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final isDuplicate = await CariHesaplarVeritabaniServisi()
          .kodNumarasiVarMi(
            _kodNoController.text,
            haricId: widget.cariHesap?.id,
          );

      if (isDuplicate) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _codeError = tr('common.code_exists_error');
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final currentUser = prefs.getString('current_username') ?? 'Sistem';

      // Bilgi alanları
      String bilgi1 = '', bilgi2 = '', bilgi3 = '', bilgi4 = '', bilgi5 = '';
      if (_bilgiControllers.isNotEmpty) bilgi1 = _bilgiControllers[0].text;
      if (_bilgiControllers.length > 1) bilgi2 = _bilgiControllers[1].text;
      if (_bilgiControllers.length > 2) bilgi3 = _bilgiControllers[2].text;
      if (_bilgiControllers.length > 3) bilgi4 = _bilgiControllers[3].text;
      if (_bilgiControllers.length > 4) bilgi5 = _bilgiControllers[4].text;

      // Sevk adresleri JSON
      final sevkJson = jsonEncode(
        _sevkAdresleri.map((adr) {
          return {
            'adres': adr['adres']?.text ?? '',
            'ilce': adr['ilce']?.text ?? '',
            'sehir': adr['sehir']?.text ?? '',
          };
        }).toList(),
      );

      final bakiyeValue = FormatYardimcisi.parseDouble(
        _bakiyeController.text,
        binlik: _genelAyarlar.binlikAyiraci,
        ondalik: _genelAyarlar.ondalikAyiraci,
      );

      final cari = CariHesapModel(
        id: widget.cariHesap?.id ?? 0,
        kodNo: _kodNoController.text,
        adi: _adiController.text,
        hesapTuru: _selectedHesapTuru ?? '',
        paraBirimi: _selectedParaBirimi,
        bakiyeBorc: _bakiyeDurumu == 'Borç' ? bakiyeValue : 0,
        bakiyeAlacak: _bakiyeDurumu == 'Alacak' ? bakiyeValue : 0,
        bakiyeDurumu: _bakiyeDurumu,
        telefon1: _telefon1Controller.text,
        telefon2: _telefon2Controller.text,
        eposta: _epostaController.text,
        webAdresi: _webAdresiController.text,
        fatUnvani: _fatUnvaniController.text,
        fatAdresi: _fatAdresiController.text,
        fatIlce: _fatIlceController.text,
        fatSehir: _fatSehirController.text,
        postaKodu: _postaKoduController.text,
        vDairesi: _vDairesiController.text,
        vNumarasi: _vNumarasiController.text,
        sfGrubu: _selectedSfGrubu ?? '',
        sIskonto: FormatYardimcisi.parseDouble(
          _sIskontoController.text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        ),
        vadeGun: int.tryParse(_vadeGunController.text) ?? 0,
        riskLimiti: FormatYardimcisi.parseDouble(
          _riskLimitiController.text,
          binlik: _genelAyarlar.binlikAyiraci,
          ondalik: _genelAyarlar.ondalikAyiraci,
        ),
        bilgi1: bilgi1,
        bilgi2: bilgi2,
        bilgi3: bilgi3,
        bilgi4: bilgi4,
        bilgi5: bilgi5,
        sevkAdresleri: sevkJson,
        resimler: _selectedImages,
        kullanici: currentUser,
        aktifMi: true,
      );

      if (widget.cariHesap != null) {
        await CariHesaplarVeritabaniServisi().cariHesapGuncelle(cari);
      } else {
        await CariHesaplarVeritabaniServisi().cariHesapEkle(cari);
      }

      if (!mounted) return;

      MesajYardimcisi.basariGoster(
        context,
        widget.cariHesap != null
            ? tr('common.updated_successfully')
            : tr('common.saved_successfully'),
      );

      SayfaSenkronizasyonServisi().veriDegisti('cari');

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      MesajYardimcisi.hataGoster(context, '${tr('common.error')}: $e');
    }
  }

  void _handleClear() {
    _formKey.currentState?.reset();
    _kodNoController.clear();
    _adiController.clear();
    _sIskontoController.clear();
    _vadeGunController.clear();
    _riskLimitiController.clear();
    _bakiyeController.clear();
    _telefon1Controller.clear();
    _telefon2Controller.clear();
    _epostaController.clear();
    _webAdresiController.clear();
    _fatUnvaniController.clear();
    _fatAdresiController.clear();
    _fatIlceController.clear();
    _fatSehirController.clear();
    _postaKoduController.clear();
    _vDairesiController.clear();
    _vNumarasiController.clear();

    setState(() {
      _codeError = null;
      _selectedHesapTuru = 'Alıcı';
      _selectedSfGrubu = 'Satış Fiyatı 1';
      _bakiyeDurumu = 'Borç';
      for (var c in _bilgiControllers) {
        c.dispose();
      }
      _bilgiControllers.clear();
      for (var adr in _sevkAdresleri) {
        adr['adres']?.dispose();
        adr['ilce']?.dispose();
        adr['sehir']?.dispose();
      }
      _sevkAdresleri.clear();
      _selectedImages.clear();
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        // Zorunlu alanlar doluysa Enter ile kaydet
        final kodDolu = _kodNoController.text.trim().isNotEmpty;
        final adiDolu = _adiController.text.trim().isNotEmpty;

        if (kodDolu && adiDolu) {
          _handleSave();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isMobileLayout = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.of(context).pop(),
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
          widget.cariHesap != null
              ? tr('accounts.form.edit_title')
              : tr('accounts.add'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 21,
          ),
        ),
        centerTitle: false,
      ),
      body: FocusScope(
        onKeyEvent: _handleKeyEvent,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(theme),
                          const SizedBox(height: 32),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth > 800) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: FocusTraversalGroup(
                                        child: _buildLeftColumn(theme),
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: FocusTraversalGroup(
                                        child: _buildRightColumn(theme),
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                return Column(
                                  children: [
                                    _buildLeftColumn(theme),
                                    const SizedBox(height: 24),
                                    _buildRightColumn(theme),
                                  ],
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: isMobileLayout
                  ? const EdgeInsets.fromLTRB(16, 12, 16, 12)
                  : const EdgeInsets.all(16),
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
                  constraints: BoxConstraints(
                    maxWidth: isMobileLayout ? 760 : 1200,
                  ),
                  child: _buildActionButtons(
                    theme,
                    isCompact: isMobileLayout,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.add_box_rounded,
            color: theme.colorScheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.cariHesap != null
                  ? tr('accounts.form.edit_title')
                  : tr('accounts.add'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                fontSize: 23,
              ),
            ),
            Text(
              tr('accounts.form.subtitle'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeftColumn(ThemeData theme) {
    return Column(
      children: [
        _buildSection(
          theme,
          title: tr('accounts.form.section.basic'),
          child: _buildBasicInfoSection(theme),
          icon: Icons.info_rounded,
          color: Colors.blue.shade700,
        ),
        const SizedBox(height: 24),
        _buildSection(
          theme,
          title: tr('accounts.form.section.info'),
          child: _buildInfoSection(theme),
          icon: Icons.note_alt_rounded,
          color: Colors.purple.shade700,
        ),
        const SizedBox(height: 24),
        _buildSection(
          theme,
          title: tr('accounts.form.section.shipment'),
          child: _buildShipmentSection(theme),
          icon: Icons.local_shipping_rounded,
          color: Colors.indigo.shade700,
        ),
      ],
    );
  }

  Widget _buildRightColumn(ThemeData theme) {
    return Column(
      children: [
        _buildSection(
          theme,
          title: tr('accounts.form.section.contact'),
          child: _buildContactSection(theme),
          icon: Icons.phone_rounded,
          color: Colors.green.shade700,
        ),
        const SizedBox(height: 24),
        _buildSection(
          theme,
          title: tr('accounts.form.section.invoice'),
          child: _buildInvoiceSection(theme),
          icon: Icons.receipt_long_rounded,
          color: Colors.orange.shade700,
        ),
        const SizedBox(height: 24),
        _buildSection(
          theme,
          title: tr('accounts.form.section.images'),
          child: _buildImagesSection(theme),
          icon: Icons.image_rounded,
          color: Colors.teal.shade700,
        ),
      ],
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

  Widget _buildBasicInfoSection(ThemeData theme) {
    final requiredColor = Colors.red.shade700;
    final optionalColor = Colors.blue.shade700;

    return Column(
      children: [
        _buildTextField(
          controller: _kodNoController,
          label: tr('accounts.form.code'),
          hint: tr('accounts.form.example.code'),
          isRequired: true,
          color: requiredColor,
          focusNode: _kodNoFocusNode,
          errorText: _codeError,
          onChanged: (val) {
            if (_codeError != null) setState(() => _codeError = null);
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _adiController,
          label: tr('accounts.form.name'),
          hint: tr('accounts.form.example.name'),
          isRequired: true,
          color: requiredColor,
          focusNode: _adiControllerFocusNode,
        ),
        const SizedBox(height: 16),
        _buildDropdown<String>(
          value: _selectedHesapTuru,
          label: tr('accounts.form.account_type'),
          items: _hesapTurleri,
          onChanged: (val) => setState(() => _selectedHesapTuru = val),
          color: optionalColor,
          focusNode: _hesapTuruFocusNode,
        ),
        const SizedBox(height: 16),
        _buildDropdown<String>(
          value: _selectedParaBirimi,
          label: tr('common.currency'),
          items: _genelAyarlar.kullanilanParaBirimleri.isNotEmpty
              ? _genelAyarlar.kullanilanParaBirimleri
              : ['TRY', 'USD', 'EUR'],
          onChanged: (val) =>
              setState(() => _selectedParaBirimi = val ?? 'TRY'),
          color: optionalColor,
          focusNode: _paraBirimiFocusNode,
        ),
        const SizedBox(height: 16),
        _buildDropdown<String>(
          value: _selectedSfGrubu,
          label: tr('accounts.form.price_group'),
          items: _sfGruplari,
          onChanged: (val) => setState(() => _selectedSfGrubu = val),
          color: optionalColor,
          focusNode: _sfGrubuFocusNode,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _sIskontoController,
          label: tr('accounts.form.discount'),
          isNumeric: true,
          color: optionalColor,
          focusNode: _sIskontoFocusNode,
          suffix: '%',
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _vadeGunController,
          label: tr('accounts.form.payment_term'),
          isNumeric: true,
          color: optionalColor,
          focusNode: _vadeGunFocusNode,
          suffix: tr('common.day'),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _riskLimitiController,
          label: tr('accounts.form.risk_limit'),
          isNumeric: true,
          color: optionalColor,
          focusNode: _riskLimitiFocusNode,
          suffix: _selectedParaBirimi,
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: 120,
              child: _buildDropdown<String>(
                value: _bakiyeDurumu,
                label: tr('accounts.form.balance'),
                items: ['Borç', 'Alacak'],
                onChanged: (val) =>
                    setState(() => _bakiyeDurumu = val ?? 'Borç'),
                itemLabelBuilder: (item) => item == 'Borç'
                    ? tr('accounts.table.type_debit')
                    : tr('accounts.table.type_credit'),
                color: optionalColor,
                focusNode: _bakiyeDurumuFocusNode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                controller: _bakiyeController,
                label: '',
                isNumeric: true,
                color: optionalColor,
                focusNode: _bakiyeFocusNode,
                suffix: _selectedParaBirimi,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactSection(ThemeData theme) {
    final color = Colors.green.shade700;
    return Column(
      children: [
        _buildTextField(
          controller: _telefon1Controller,
          label: tr('accounts.form.phone1'),
          hint: tr('common.placeholder.phone'),
          color: color,
          focusNode: _telefon1FocusNode,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _telefon2Controller,
          label: tr('accounts.form.phone2'),
          hint: tr('common.placeholder.phone'),
          color: color,
          focusNode: _telefon2FocusNode,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _epostaController,
          label: tr('accounts.form.email'),
          hint: tr('common.placeholder.email'),
          color: color,
          focusNode: _epostaFocusNode,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _webAdresiController,
          label: tr('accounts.form.website'),
          hint: tr('common.placeholder.website'),
          color: color,
          focusNode: _webAdresiFocusNode,
        ),
      ],
    );
  }

  Widget _buildInvoiceSection(ThemeData theme) {
    final color = Colors.orange.shade700;
    return Column(
      children: [
        _buildTextField(
          controller: _fatUnvaniController,
          label: tr('accounts.form.invoice_title'),
          color: color,
          focusNode: _fatUnvaniFocusNode,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _fatAdresiController,
          label: tr('accounts.form.invoice_address'),
          color: color,
          focusNode: _fatAdresiFocusNode,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _fatIlceController,
                label: tr('accounts.form.invoice_district'),
                color: color,
                focusNode: _fatIlceFocusNode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                controller: _fatSehirController,
                label: tr('accounts.form.invoice_city'),
                color: color,
                focusNode: _fatSehirFocusNode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _postaKoduController,
          label: tr('accounts.form.postal_code'),
          color: color,
          focusNode: _postaKoduFocusNode,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _vDairesiController,
          label: tr('accounts.form.tax_office'),
          color: color,
          focusNode: _vDairesiFocusNode,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _vNumarasiController,
          label: tr('accounts.form.tax_number'),
          color: color,
          focusNode: _vNumarasiFocusNode,
        ),
      ],
    );
  }

  Widget _buildInfoSection(ThemeData theme) {
    final color = Colors.purple.shade700;
    return Column(
      children: [
        if (_bilgiControllers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              tr('accounts.form.info_empty'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
                fontSize: 18,
              ),
            ),
          ),
        ..._bilgiControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: controller,
                    label: '${tr('accounts.form.info')} ${index + 1}',
                    color: color,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeBilgiRow(index),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _bilgiControllers.length >= 5 ? null : _addBilgiRow,
            icon: const Icon(Icons.add_circle_outline, size: 19),
            label: Text(
              tr('accounts.form.info_add'),
              style: const TextStyle(fontSize: 18),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _bilgiControllers.length >= 5
                  ? Colors.grey
                  : theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShipmentSection(ThemeData theme) {
    final color = Colors.indigo.shade700;
    return Column(
      children: [
        if (_sevkAdresleri.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              tr('accounts.form.shipment_empty'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
                fontSize: 18,
              ),
            ),
          ),
        ..._sevkAdresleri.asMap().entries.map((entry) {
          final index = entry.key;
          final adr = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${tr('accounts.form.shipment_address')} ${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () => _removeSevkAdresiRow(index),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: adr['adres']!,
                  label: tr('accounts.form.address'),
                  color: color,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: adr['ilce']!,
                        label: tr('accounts.form.district'),
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: adr['sehir']!,
                        label: tr('accounts.form.city'),
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _sevkAdresleri.length >= 5 ? null : _addSevkAdresiRow,
            icon: const Icon(Icons.add_circle_outline, size: 19),
            label: Text(
              tr('accounts.form.shipment_add'),
              style: const TextStyle(fontSize: 18),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _sevkAdresleri.length >= 5
                  ? Colors.grey
                  : theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagesSection(ThemeData theme) {
    final color = Colors.teal.shade700;
    final isFull = _selectedImages.length >= 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isFull)
          InkWell(
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 24,
                    color: color.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tr('products.form.image.dropzone_hint'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedImages.length}/5',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey.shade200,
                        child: Image.memory(
                          base64Decode(_selectedImages[index]),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.broken_image,
                                size: 42,
                                color: Colors.grey,
                              ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme, {bool isCompact = false}) {
    if (isCompact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final double maxRowWidth =
              constraints.maxWidth > 320 ? 320 : constraints.maxWidth;
          const double gap = 10;
          final double buttonWidth = (maxRowWidth - gap) / 2;

          return Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: maxRowWidth,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: buttonWidth,
                    child: OutlinedButton.icon(
                      onPressed: _handleClear,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: Colors.grey.shade300),
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.refresh, size: 15),
                      label: Text(
                        tr('common.clear'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: buttonWidth,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              tr('common.save'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _handleClear,
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          ),
          child: Row(
            children: [
              const Icon(Icons.refresh, size: 20),
              const SizedBox(width: 8),
              Text(
                tr('common.clear'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  tr('common.save'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
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
        if (label.isNotEmpty)
          Text(
            isRequired ? '$label *' : label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: effectiveColor,
              fontSize: 14,
            ),
          ),
        if (label.isNotEmpty) const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
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
              : null,
          onFieldSubmitted: (value) {
            FocusScope.of(context).nextFocus();
          },
          textInputAction: TextInputAction.next,
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return tr('validation.required');
            }
            return null;
          },
          decoration: InputDecoration(
            errorText: errorText,
            hintText: hint,
            suffixText: suffix,
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
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String label,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String Function(T item)? itemLabelBuilder,
    Color? color,
    FocusNode? focusNode,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: effectiveColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          focusNode: focusNode,
          initialValue: items.contains(value) ? value : null,
          onChanged: (val) {
            onChanged(val);
            FocusScope.of(context).nextFocus();
          },
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
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemLabelBuilder?.call(item) ?? item.toString(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          icon: Icon(Icons.arrow_drop_down, color: effectiveColor),
        ),
      ],
    );
  }
}
