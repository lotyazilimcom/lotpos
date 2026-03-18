import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nsd/nsd.dart' show Service;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'modeller/genel_ayarlar_model.dart';
import 'package:patisyov10/sayfalar/ayarlar/genel_ayarlar/modeller/para_birimleri_data.dart';
import 'package:patisyov10/sayfalar/baslangic/bootstrap_sayfasi.dart';
import 'veri_kaynagi/genel_ayarlar_veri_kaynagi.dart';
import 'package:patisyov10/yardimcilar/ceviri/ceviri_servisi.dart';
import 'modeller/doviz_kuru_model.dart';
import 'package:patisyov10/servisler/ayarlar_veritabani_servisi.dart';
import 'package:patisyov10/servisler/doviz_guncelleme_servisi.dart';
import 'package:patisyov10/servisler/bankalar_veritabani_servisi.dart';
import 'package:patisyov10/servisler/kasalar_veritabani_servisi.dart';
import 'package:patisyov10/servisler/kredi_kartlari_veritabani_servisi.dart';
import 'package:patisyov10/servisler/lisans_servisi.dart';
import 'package:patisyov10/servisler/local_network_discovery_service.dart';
import 'package:patisyov10/servisler/veritabani_baglanti_sifirlayici.dart';
import 'package:patisyov10/servisler/veritabani_yapilandirma.dart';
import 'package:patisyov10/bilesenler/standart_alt_aksiyon_bar.dart';
import 'package:patisyov10/yardimcilar/yazdirma/yazdirma_erisim_kontrolu.dart';
import 'package:intl/intl.dart';
import 'package:patisyov10/sayfalar/bankalar/modeller/banka_model.dart';
import 'package:patisyov10/sayfalar/kasalar/modeller/kasa_model.dart';
import 'package:patisyov10/sayfalar/kredikartlari/modeller/kredi_karti_model.dart';

class GenelAyarlarSayfasi extends StatefulWidget {
  const GenelAyarlarSayfasi({super.key});

  @override
  State<GenelAyarlarSayfasi> createState() => _GenelAyarlarSayfasiState();
}

class _GenelAyarlarSayfasiState extends State<GenelAyarlarSayfasi>
    with SingleTickerProviderStateMixin {
  // Colors from project constitution
  static const Color _primaryColor = Color(0xFF2C3E50);
  static const Color _accentColor = Color(0xFFEA4335);
  static const Color _bgColor = Color(0xFFF8F9FA);
  static const Color _mutedColor = Color(0xFF95A5A6);
  static const Color _actionPrimary = Color(0xFF2C3E50);

  final GenelAyarlarVeriKaynagi _veriKaynagi = GenelAyarlarVeriKaynagi();
  GenelAyarlarModel _ayarlar = GenelAyarlarModel();
  GenelAyarlarModel? _kayitliAyarlar;
  bool _yukleniyor = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late TabController _tabController;

  List<DovizKuruModel> _dovizKurlari = [];
  bool _kurGuncelleniyor = false;

  List<KasaModel> _perakendeKasalar = [];
  List<BankaModel> _perakendeBankalar = [];
  List<KrediKartiModel> _perakendeKrediKartlari = [];

  late TextEditingController _nakit1Controller;
  late TextEditingController _nakit2Controller;
  late TextEditingController _nakit3Controller;
  late TextEditingController _nakit4Controller;
  late TextEditingController _nakit5Controller;
  late TextEditingController _nakit6Controller;
  late TextEditingController _kopyaSayisiController;
  final GlobalKey _printerPickerAnchorKey = GlobalKey();
  List<Printer> _sistemYazicilari = [];
  bool _sistemYazicilariYukleniyor = false;
  String? _sistemYazicilariHatasi;
  String _baglantiRolu = 'server';
  String _kayitliBaglantiRolu = 'server';
  List<Service> _yerelSunucular = [];
  bool _yerelSunucularYukleniyor = false;
  bool _yerelSunucularTarandi = false;
  String? _seciliYerelSunucuHost;
  String? _yerelSunucularHatasi;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _ayarlariYukle();
    if (_masaustuYaziciSecimiDestekleniyor) {
      _sistemYazicilariniYukle();
    }
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _nakit1Controller.dispose();
    _nakit2Controller.dispose();
    _nakit3Controller.dispose();
    _nakit4Controller.dispose();
    _nakit5Controller.dispose();
    _nakit6Controller.dispose();
    _kopyaSayisiController.dispose();
    super.dispose();
  }

  bool get _masaustuYerelSunucuSecimiDestekleniyor =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  String _aktifBaglantiRolu() {
    final currentMode = VeritabaniYapilandirma.connectionMode;
    if (currentMode == 'cloud') {
      return _ayarlar.sunucuModu == 'terminal' ? 'terminal' : 'server';
    }
    final discoveredHost = (VeritabaniYapilandirma.discoveredHost ?? '').trim();
    return VeritabaniYapilandirma.yerelAnaSunucuHostMu(discoveredHost)
        ? 'server'
        : 'terminal';
  }

  Future<void> _yerelSunuculariTara({bool showError = true}) async {
    if (!_masaustuYerelSunucuSecimiDestekleniyor || _yerelSunucularYukleniyor) {
      return;
    }

    setState(() {
      _yerelSunucularYukleniyor = true;
      _yerelSunucularTarandi = true;
      _yerelSunucularHatasi = null;
    });

    try {
      final servers = await LocalNetworkDiscoveryService().sunuculariBul(
        timeout: const Duration(seconds: 3),
      );
      servers.sort((a, b) {
        final titleA = (a.name ?? a.host ?? '').trim().toLowerCase();
        final titleB = (b.name ?? b.host ?? '').trim().toLowerCase();
        return titleA.compareTo(titleB);
      });

      if (!mounted) return;

      final savedHost =
          (_seciliYerelSunucuHost ??
                  VeritabaniYapilandirma.discoveredHost ??
                  '')
              .trim();
      String? selectedHost = savedHost.isEmpty ? null : savedHost;
      if (servers.isNotEmpty) {
        final hasSavedMatch =
            selectedHost != null &&
            servers.any((s) => (s.host ?? '').trim() == selectedHost);
        selectedHost = hasSavedMatch
            ? selectedHost
            : (servers.first.host ?? '').trim();
      }

      setState(() {
        _yerelSunucular = servers;
        _seciliYerelSunucuHost = selectedHost;
        _yerelSunucularYukleniyor = false;
      });

      if (showError && servers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('settings.database.mobile_local_requires_server')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yerelSunucular = [];
        _yerelSunucularYukleniyor = false;
        _yerelSunucularHatasi = e.toString();
      });
      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('settings.connection.server_search_error')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _uygulaYerelSunucuLisansBestEffort(Service? service) async {
    if (service == null) return;
    try {
      final txt = service.txt;
      if (txt == null || txt['isPro'] == null) return;
      final inherited = utf8.decode(txt['isPro']!) == 'true';
      await LisansServisi().setInheritedPro(inherited);
    } catch (_) {
      // Sessiz: keşif lisans bilgisi opsiyonel.
    }
  }

  Future<void> _ayarlariYukle() async {
    setState(() => _yukleniyor = true);
    try {
      final ayarlar = await _veriKaynagi.ayarlariGetir();
      await _kurlariYukle();
      final currentRole = _aktifBaglantiRolu();
      final currentHost = (VeritabaniYapilandirma.discoveredHost ?? '').trim();
      setState(() {
        _ayarlar = ayarlar;
        _kayitliAyarlar = _cloneAyarlar(ayarlar);
        _baglantiRolu = currentRole;
        _kayitliBaglantiRolu = currentRole;
        _seciliYerelSunucuHost = currentHost.isEmpty ? null : currentHost;
        _initControllers();
        _yukleniyor = false;
      });
      await _perakendeHesaplariYukle();
      if (_masaustuYerelSunucuSecimiDestekleniyor &&
          currentRole == 'terminal') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _yerelSunuculariTara(showError: false);
        });
      }
    } catch (e) {
      debugPrint('Ayarlar yüklenirken hata: $e');
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _perakendeHesaplariYukle() async {
    try {
      final results = await Future.wait([
        KasalarVeritabaniServisi().tumKasalariGetir(),
        BankalarVeritabaniServisi().tumBankalariGetir(),
        KrediKartlariVeritabaniServisi().tumKrediKartlariniGetir(),
      ]);

      if (!mounted) return;

      final kasalar = (results[0] as List<KasaModel>)
        ..sort((a, b) => a.kod.compareTo(b.kod));
      final bankalar = (results[1] as List<BankaModel>)
        ..sort((a, b) => a.kod.compareTo(b.kod));
      final kartlar = (results[2] as List<KrediKartiModel>)
        ..sort((a, b) => a.kod.compareTo(b.kod));

      setState(() {
        _perakendeKasalar = kasalar;
        _perakendeBankalar = bankalar;
        _perakendeKrediKartlari = kartlar;
      });
    } catch (e) {
      debugPrint('Perakende hesapları yüklenirken hata: $e');
    }
  }

  GenelAyarlarModel _cloneAyarlar(GenelAyarlarModel source) {
    final jsonMap =
        jsonDecode(jsonEncode(source.toMap())) as Map<String, dynamic>;
    return GenelAyarlarModel.fromMap(jsonMap);
  }

  void _controllersFromModel(GenelAyarlarModel model) {
    _nakit1Controller.text = model.nakit1;
    _nakit2Controller.text = model.nakit2;
    _nakit3Controller.text = model.nakit3;
    _nakit4Controller.text = model.nakit4;
    _nakit5Controller.text = model.nakit5;
    _nakit6Controller.text = model.nakit6;
    _kopyaSayisiController.text = model.kopyaSayisi;
  }

  void _iptalEt() {
    final kayitli = _kayitliAyarlar;
    if (kayitli == null) return;

    setState(() {
      _ayarlar = _cloneAyarlar(kayitli);
      _baglantiRolu = _kayitliBaglantiRolu;
      final savedHost = (VeritabaniYapilandirma.discoveredHost ?? '').trim();
      _seciliYerelSunucuHost = savedHost.isEmpty ? null : savedHost;
      _controllersFromModel(_ayarlar);
    });

    if (_masaustuYerelSunucuSecimiDestekleniyor &&
        _baglantiRolu == 'terminal' &&
        !_yerelSunucularYukleniyor) {
      _yerelSunuculariTara(showError: false);
    }
  }

  Future<void> _kurlariYukle() async {
    final kurlar = await AyarlarVeritabaniServisi().kurlariGetir();
    setState(() => _dovizKurlari = kurlar);
  }

  Future<void> _manuelKurGuncelle() async {
    setState(() => _kurGuncelleniyor = true);
    final basarili = await DovizGuncellemeServisi().guncelle();
    if (basarili) await _kurlariYukle();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            basarili
                ? tr('settings.currencyRates.updateSuccess')
                : tr('settings.currencyRates.updateError'),
          ),
          backgroundColor: basarili ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    setState(() => _kurGuncelleniyor = false);
  }

  void _initControllers() {
    _nakit1Controller = TextEditingController(text: _ayarlar.nakit1);
    _nakit2Controller = TextEditingController(text: _ayarlar.nakit2);
    _nakit3Controller = TextEditingController(text: _ayarlar.nakit3);
    _nakit4Controller = TextEditingController(text: _ayarlar.nakit4);
    _nakit5Controller = TextEditingController(text: _ayarlar.nakit5);
    _nakit6Controller = TextEditingController(text: _ayarlar.nakit6);
    _kopyaSayisiController = TextEditingController(text: _ayarlar.kopyaSayisi);
  }

  Service? _seciliYerelSunucuServisi() {
    final selectedHost = (_seciliYerelSunucuHost ?? '').trim();
    if (selectedHost.isEmpty) return null;
    for (final server in _yerelSunucular) {
      if ((server.host ?? '').trim() == selectedHost) {
        return server;
      }
    }
    return null;
  }

  Future<void> _kaydet() async {
    final bool masaustuBaglantiAkisi = _masaustuYerelSunucuSecimiDestekleniyor;
    final String oncekiRolu = _kayitliBaglantiRolu;
    final String oncekiHost = (VeritabaniYapilandirma.discoveredHost ?? '')
        .trim();
    String? hedefHost = masaustuBaglantiAkisi && _baglantiRolu == 'terminal'
        ? (_seciliYerelSunucuHost ?? '').trim()
        : null;

    if (masaustuBaglantiAkisi &&
        _baglantiRolu == 'terminal' &&
        (hedefHost == null || hedefHost.isEmpty)) {
      await _yerelSunuculariTara(showError: false);
      hedefHost = (_seciliYerelSunucuHost ?? '').trim();
    }

    if (masaustuBaglantiAkisi &&
        _baglantiRolu == 'terminal' &&
        (hedefHost == null || hedefHost.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('settings.connection.select_server_required')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _ayarlar.nakit1 = _nakit1Controller.text;
      _ayarlar.nakit2 = _nakit2Controller.text;
      _ayarlar.nakit3 = _nakit3Controller.text;
      _ayarlar.nakit4 = _nakit4Controller.text;
      _ayarlar.nakit5 = _nakit5Controller.text;
      _ayarlar.nakit6 = _nakit6Controller.text;
      _ayarlar.kopyaSayisi = _kopyaSayisiController.text;
    });

    try {
      final kaydedilecekAyarlar = _cloneAyarlar(_ayarlar);
      if (masaustuBaglantiAkisi) {
        final bool uzakIstemciUzerindenCalisiyor =
            oncekiHost.isNotEmpty &&
            VeritabaniYapilandirma.connectionMode != 'cloud';
        if (!uzakIstemciUzerindenCalisiyor) {
          kaydedilecekAyarlar.sunucuModu = _baglantiRolu;
        } else {
          kaydedilecekAyarlar.sunucuModu =
              _kayitliAyarlar?.sunucuModu ?? _ayarlar.sunucuModu;
        }
      }

      await _veriKaynagi.ayarlariKaydet(kaydedilecekAyarlar);
      _ayarlar = _cloneAyarlar(kaydedilecekAyarlar);
      _kayitliAyarlar = _cloneAyarlar(kaydedilecekAyarlar);
      _kayitliBaglantiRolu = _baglantiRolu;

      final String normalizedTargetHost = (hedefHost ?? '').trim();
      final bool baglantiDegisti =
          masaustuBaglantiAkisi &&
          (oncekiRolu != _baglantiRolu || oncekiHost != normalizedTargetHost);

      if (baglantiDegisti) {
        await VeritabaniYapilandirma.saveConnectionPreferences(
          VeritabaniYapilandirma.connectionMode,
          normalizedTargetHost.isEmpty ? null : normalizedTargetHost,
        );
        await _uygulaYerelSunucuLisansBestEffort(_seciliYerelSunucuServisi());
        await VeritabaniBaglantiSifirlayici().tumunuKapat();
        await VeritabaniYapilandirma.loadPersistedConfig(force: true);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BootstrapSayfasi()),
          (_) => false,
        );
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('settings.general.actions.saveSuccess')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('common.error.generic')}$e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = _isMobileLayout(constraints.maxWidth);

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.enter): _kaydet,
            const SingleActivator(LogicalKeyboardKey.numpadEnter): _kaydet,
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (_searchController.text.isNotEmpty) _searchController.clear();
            },
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _buildHeader(isMobile: isMobile),
                    if (_searchQuery.isEmpty)
                      _buildModernTabBar(isMobile: isMobile),
                    Expanded(
                      child: Container(
                        color: _bgColor,
                        child: _searchQuery.isNotEmpty
                            ? _buildSearchResults(isMobile: isMobile)
                            : TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildGenelTab(isMobile: isMobile),
                                  _buildVergiTab(isMobile: isMobile),
                                  _buildPerakendeTab(isMobile: isMobile),
                                  _buildUrunStokTab(isMobile: isMobile),
                                  _buildKodUretimiTab(isMobile: isMobile),
                                  _buildYazdirmaTab(isMobile: isMobile),
                                  _buildBaglantiTab(isMobile: isMobile),
                                ],
                              ),
                      ),
                    ),
                    _buildBottomActionBar(isCompact: isMobile),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomActionBar({required bool isCompact}) {
    return StandartAltAksiyonBar(
      isCompact: isCompact,
      secondaryText: tr('common.cancel'),
      onSecondaryPressed: _iptalEt,
      primaryText: tr('settings.general.actions.save'),
      onPrimaryPressed: _kaydet,
      alignment: Alignment.centerRight,
    );
  }

  bool _isMobileLayout(double width) => width < 860;

  bool get _masaustuYaziciSecimiDestekleniyor =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  bool get _printingDisabled => YazdirmaErisimKontrolu.mobilBulutYazdirmaPasif;

  EdgeInsets _contentPadding(bool isMobile) {
    return EdgeInsets.symmetric(
      horizontal: isMobile ? 14 : 20,
      vertical: isMobile ? 14 : 20,
    );
  }

  Widget _buildResponsiveCardPair({
    required bool isMobile,
    required Widget first,
    Widget? second,
  }) {
    if (isMobile) {
      return Column(
        children: [
          first,
          if (second != null) ...[const SizedBox(height: 16), second],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        if (second != null) ...[
          const SizedBox(width: 16),
          Expanded(child: second),
        ],
      ],
    );
  }

  Widget _buildHeader({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        isMobile ? 14 : 20,
        isMobile ? 16 : 24,
        isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('settings.general.title'),
            style: TextStyle(
              fontSize: isMobile ? 20 : 22,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr('settings.general.subtitle'),
            style: const TextStyle(fontSize: 13, color: _mutedColor),
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: tr('settings.general.search.placeholder'),
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTabBar({required bool isMobile}) {
    return Container(
      height: isMobile ? 46 : 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: _accentColor,
        indicatorWeight: 3,
        labelColor: _accentColor,
        unselectedLabelColor: _primaryColor,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        labelPadding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20),
        tabs: [
          Tab(text: 'Genel'),
          Tab(text: 'Vergi'),
          Tab(text: 'Perakende Satış'),
          Tab(text: 'Ürün & Stok'),
          Tab(text: 'Kod Üretimi'),
          Tab(text: 'Yazdırma'),
          Tab(text: tr('settings.connection.title')),
        ],
      ),
    );
  }

  // ==================== TAB CONTENTS ====================

  Widget _buildGenelTab({required bool isMobile}) {
    return SingleChildScrollView(
      padding: _contentPadding(isMobile),
      child: Column(
        children: [
          _buildParaBirimiCard(),
          const SizedBox(height: 16),
          _buildResponsiveCardPair(
            isMobile: isMobile,
            first: _buildSayisalAyarlarCard(),
            second: _buildDovizKurlariCard(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildVergiTab({required bool isMobile}) {
    return SingleChildScrollView(
      padding: _contentPadding(isMobile),
      child: Column(
        children: [_buildVergiAyarlariCard(), const SizedBox(height: 40)],
      ),
    );
  }

  Widget _buildPerakendeTab({required bool isMobile}) {
    return SingleChildScrollView(
      padding: _contentPadding(isMobile),
      child: Column(
        children: [_buildPerakendeSatisCard(), const SizedBox(height: 40)],
      ),
    );
  }

  Widget _buildUrunStokTab({required bool isMobile}) {
    return SingleChildScrollView(
      padding: _contentPadding(isMobile),
      child: Column(
        children: [
          _buildResponsiveCardPair(
            isMobile: isMobile,
            first: _buildUrunAyarlariCard(),
            second: _buildStokAyarlariCard(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildKodUretimiTab({required bool isMobile}) {
    return SingleChildScrollView(
      padding: _contentPadding(isMobile),
      child: Column(
        children: [_buildKodUretimiCard(), const SizedBox(height: 40)],
      ),
    );
  }

  Widget _buildYazdirmaTab({required bool isMobile}) {
    return SingleChildScrollView(
      padding: _contentPadding(isMobile),
      child: Column(
        children: [_buildYazdirmaCard(), const SizedBox(height: 40)],
      ),
    );
  }

  Widget _buildBaglantiTab({required bool isMobile}) {
    final bool mobileOrTabletPlatform = Platform.isAndroid || Platform.isIOS;
    return SingleChildScrollView(
      padding: _contentPadding(isMobile),
      child: Column(
        children: [
          mobileOrTabletPlatform
              ? _buildYaziciAyarlariCard()
              : _buildResponsiveCardPair(
                  isMobile: isMobile,
                  first: _buildBaglantiAyarlariCard(),
                  second: _buildBaglantiYaziciAyarlariCard(),
                ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSearchResults({required bool isMobile}) {
    return SingleChildScrollView(
      padding: _contentPadding(isMobile),
      child: Column(
        children: [
          _buildParaBirimiCard(),
          const SizedBox(height: 16),
          _buildResponsiveCardPair(
            isMobile: isMobile,
            first: _buildSayisalAyarlarCard(),
            second: _buildDovizKurlariCard(),
          ),
          const SizedBox(height: 16),
          _buildPerakendeSatisCard(),
          const SizedBox(height: 16),
          _buildVergiAyarlariCard(),
          const SizedBox(height: 16),
          _buildResponsiveCardPair(
            isMobile: isMobile,
            first: _buildUrunAyarlariCard(),
            second: _buildStokAyarlariCard(),
          ),
          const SizedBox(height: 16),
          _buildKodUretimiCard(),
          const SizedBox(height: 16),
          _buildYazdirmaCard(),
          const SizedBox(height: 16),
          (Platform.isAndroid || Platform.isIOS)
              ? _buildYaziciAyarlariCard()
              : _buildResponsiveCardPair(
                  isMobile: isMobile,
                  first: _buildBaglantiAyarlariCard(),
                  second: _buildBaglantiYaziciAyarlariCard(),
                ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ==================== CARD BUILDERS ====================

  Widget _buildCompactCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 480;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.06),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: accentColor.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: isNarrow && trailing != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(icon, size: 16, color: accentColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: trailing,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, size: 16, color: accentColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                          ?trailing,
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingRow({
    required String label,
    String? description,
    required Widget trailing,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 460;

        if (isNarrow) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _primaryColor,
                  ),
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: trailing),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _primaryColor,
                      ),
                    ),
                    if (description != null)
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing,
            ],
          ),
        );
      },
    );
  }

  // ==================== INDIVIDUAL CARDS ====================

  Widget _buildSayisalAyarlarCard() {
    return _buildCompactCard(
      title: tr('settings.general.group.numeric.title'),
      icon: Icons.numbers_rounded,
      accentColor: const Color(0xFF3B82F6),
      children: [
        _buildSettingRow(
          label: tr('settings.general.fields.priceDecimals.label'),
          trailing: _buildNumberStepper(
            value: _ayarlar.fiyatOndalik,
            onChanged: (v) => setState(() => _ayarlar.fiyatOndalik = v),
          ),
        ),
        _buildSettingRow(
          label: tr('settings.general.fields.rateDecimals.label'),
          trailing: _buildNumberStepper(
            value: _ayarlar.kurOndalik,
            onChanged: (v) => setState(() => _ayarlar.kurOndalik = v),
          ),
        ),
        _buildSettingRow(
          label: tr('settings.general.fields.quantityDecimals.label'),
          trailing: _buildNumberStepper(
            value: _ayarlar.miktarOndalik,
            onChanged: (v) => setState(() => _ayarlar.miktarOndalik = v),
          ),
        ),
      ],
    );
  }

  Widget _buildDovizKurlariCard() {
    return _buildCompactCard(
      title: tr('settings.currencyRates.title'),
      icon: Icons.currency_exchange_rounded,
      accentColor: const Color(0xFFF59E0B),
      trailing: TextButton.icon(
        onPressed: _kurGuncelleniyor ? null : _manuelKurGuncelle,
        icon: _kurGuncelleniyor
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh, size: 16),
        label: Text(
          tr('settings.currencyRates.updateNow'),
          style: const TextStyle(fontSize: 12),
        ),
        style: TextButton.styleFrom(
          foregroundColor: _actionPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
      children: [
        if (_dovizKurlari.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                tr('settings.currencyRates.noRates'),
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else
          ..._dovizKurlari.map(
            (kur) => Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isNarrow = constraints.maxWidth < 360;
                  final Widget kurMetni = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '1 ${kur.kaynakParaBirimi}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        kur.kur.toStringAsFixed(4),
                        style: const TextStyle(
                          color: _actionPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        kur.hedefParaBirimi,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );

                  final Widget tarihMetni = Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(kur.guncellemeZamani),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        kurMetni,
                        const SizedBox(height: 4),
                        tarihMetni,
                      ],
                    );
                  }

                  return Row(children: [kurMetni, const Spacer(), tarihMetni]);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPerakendeSatisCard() {
    const options = <String>['cash', 'bank', 'credit_card'];

    String labelFor(String value) {
      switch (value) {
        case 'cash':
          return tr('settings.users.payment.source.cash');
        case 'bank':
          return tr('settings.users.payment.source.bank');
        case 'credit_card':
          return tr('settings.users.payment.source.credit_card');
        default:
          return value;
      }
    }

    final kasaByKod = {for (final kasa in _perakendeKasalar) kasa.kod: kasa};
    final bankaByKod = {
      for (final banka in _perakendeBankalar) banka.kod: banka,
    };
    final kartByKod = {
      for (final kart in _perakendeKrediKartlari) kart.kod: kart,
    };

    List<String> hesapItems(String target) {
      final items = <String>[''];
      switch (target) {
        case 'cash':
          items.addAll(_perakendeKasalar.map((e) => e.kod));
          break;
        case 'bank':
          items.addAll(_perakendeBankalar.map((e) => e.kod));
          break;
        case 'credit_card':
          items.addAll(_perakendeKrediKartlari.map((e) => e.kod));
          break;
      }
      return items;
    }

    String hesapLabel(String target, String value) {
      if (value.isEmpty) return tr('common.default');
      switch (target) {
        case 'cash':
          final kasa = kasaByKod[value];
          return kasa == null ? value : '${kasa.kod} - ${kasa.ad}';
        case 'bank':
          final banka = bankaByKod[value];
          return banka == null ? value : '${banka.kod} - ${banka.ad}';
        case 'credit_card':
          final kart = kartByKod[value];
          return kart == null ? value : '${kart.kod} - ${kart.ad}';
        default:
          return value;
      }
    }

    Widget buildTahsilatColumn({
      required String label,
      required String targetValue,
      required ValueChanged<String> onTargetChanged,
      required String accountValue,
      required ValueChanged<String> onAccountChanged,
    }) {
      final accounts = hesapItems(targetValue);
      final safeAccountValue = accounts.contains(accountValue)
          ? accountValue
          : '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDropdown(
            label: label,
            value: targetValue,
            items: options,
            onChanged: onTargetChanged,
            labelBuilder: labelFor,
          ),
          const SizedBox(height: 10),
          _buildDropdown(
            label: tr('common.account'),
            value: safeAccountValue,
            items: accounts,
            onChanged: onAccountChanged,
            labelBuilder: (v) => hesapLabel(targetValue, v),
          ),
        ],
      );
    }

    return _buildCompactCard(
      title: tr('settings.retail.card.title'),
      icon: Icons.point_of_sale_rounded,
      accentColor: const Color(0xFF26A69A),
      children: [
        Text(
          tr('settings.retail.card.subtitle'),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth > 600;
            final double width = isWide
                ? (constraints.maxWidth - 24) / 3
                : double.infinity;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: buildTahsilatColumn(
                    label: tr('settings.retail.cash_destination.label'),
                    targetValue: _ayarlar.perakendeNakitIslemeYeri,
                    onTargetChanged: (v) => setState(() {
                      _ayarlar.perakendeNakitIslemeYeri = v;
                      _ayarlar.perakendeNakitIslemeHesapKodu = '';
                    }),
                    accountValue: _ayarlar.perakendeNakitIslemeHesapKodu,
                    onAccountChanged: (v) => setState(
                      () => _ayarlar.perakendeNakitIslemeHesapKodu = v,
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: buildTahsilatColumn(
                    label: tr('settings.retail.credit_card_destination.label'),
                    targetValue: _ayarlar.perakendeKrediKartiIslemeYeri,
                    onTargetChanged: (v) => setState(() {
                      _ayarlar.perakendeKrediKartiIslemeYeri = v;
                      _ayarlar.perakendeKrediKartiIslemeHesapKodu = '';
                    }),
                    accountValue: _ayarlar.perakendeKrediKartiIslemeHesapKodu,
                    onAccountChanged: (v) => setState(
                      () => _ayarlar.perakendeKrediKartiIslemeHesapKodu = v,
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: buildTahsilatColumn(
                    label: tr('settings.retail.transfer_destination.label'),
                    targetValue: _ayarlar.perakendeHavaleIslemeYeri,
                    onTargetChanged: (v) => setState(() {
                      _ayarlar.perakendeHavaleIslemeYeri = v;
                      _ayarlar.perakendeHavaleIslemeHesapKodu = '';
                    }),
                    accountValue: _ayarlar.perakendeHavaleIslemeHesapKodu,
                    onAccountChanged: (v) => setState(
                      () => _ayarlar.perakendeHavaleIslemeHesapKodu = v,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildParaBirimiCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _actionPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.attach_money,
                  color: _actionPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('settings.general.currencyCard.title'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    Text(
                      tr('settings.general.currencyCard.subtitle'),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: isWide
                        ? (constraints.maxWidth - 24) / 3
                        : double.infinity,
                    child: _buildDropdown(
                      label: tr(
                        'settings.general.currencyCard.defaultCurrency.label',
                      ),
                      value: _ayarlar.varsayilanParaBirimi,
                      items: _ayarlar.kullanilanParaBirimleri,
                      onChanged: (v) =>
                          setState(() => _ayarlar.varsayilanParaBirimi = v),
                      labelBuilder: (code) {
                        final countryKey =
                            ParaBirimleriData.tumParaBirimleri[code];
                        final cName = countryKey != null
                            ? tr('country.$countryKey')
                            : '';
                        return '$code ($cName)';
                      },
                    ),
                  ),
                  SizedBox(
                    width: isWide
                        ? (constraints.maxWidth - 24) / 3
                        : double.infinity,
                    child: _buildDropdown(
                      label: tr(
                        'settings.general.currencyCard.thousandSeparator.label',
                      ),
                      value: _ayarlar.binlikAyiraci,
                      items: const ['.', ',', ' '],
                      onChanged: (v) =>
                          setState(() => _ayarlar.binlikAyiraci = v),
                      labelBuilder: (v) => v == ' '
                          ? tr('settings.general.currencyCard.separator.space')
                          : v,
                    ),
                  ),
                  SizedBox(
                    width: isWide
                        ? (constraints.maxWidth - 24) / 3
                        : double.infinity,
                    child: _buildDropdown(
                      label: tr(
                        'settings.general.currencyCard.decimalSeparator.label',
                      ),
                      value: _ayarlar.ondalikAyiraci,
                      items: const ['.', ',', ' '],
                      onChanged: (v) =>
                          setState(() => _ayarlar.ondalikAyiraci = v),
                      labelBuilder: (v) => v == ' '
                          ? tr('settings.general.currencyCard.separator.space')
                          : v,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            tr('settings.general.currency.active_currencies'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ..._ayarlar.kullanilanParaBirimleri.map((code) {
                final countryKey = ParaBirimleriData.tumParaBirimleri[code];
                final cName = countryKey != null
                    ? tr('country.$countryKey')
                    : '';
                final isDefault = code == _ayarlar.varsayilanParaBirimi;
                return Chip(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  label: Text(
                    '$code ($cName)',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDefault ? _actionPrimary : _primaryColor,
                    ),
                  ),
                  deleteIcon: isDefault
                      ? null
                      : const Icon(Icons.close, size: 14),
                  onDeleted: isDefault
                      ? null
                      : () => setState(
                          () => _ayarlar.kullanilanParaBirimleri.remove(code),
                        ),
                  backgroundColor: isDefault
                      ? _actionPrimary.withValues(alpha: 0.1)
                      : _bgColor,
                  side: BorderSide(
                    color: isDefault
                        ? _actionPrimary.withValues(alpha: 0.3)
                        : Colors.grey.shade300,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.add, size: 14),
                label: Text(
                  tr('settings.general.currency.add'),
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: _showAddCurrencyDialog,
                mouseCursor: WidgetStateMouseCursor.clickable,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 420;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('settings.general.currencyCard.showSymbol.label'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildSwitch(
                        value: _ayarlar.sembolGoster,
                        onChanged: (v) =>
                            setState(() => _ayarlar.sembolGoster = v),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('settings.general.currencyCard.showSymbol.label'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _buildSwitch(
                    value: _ayarlar.sembolGoster,
                    onChanged: (v) => setState(() => _ayarlar.sembolGoster = v),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 420;
              final Widget vatDropdown = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    mouseCursor: WidgetStateMouseCursor.clickable,
                    dropdownMenuItemMouseCursor:
                        WidgetStateMouseCursor.clickable,
                    value: _ayarlar.varsayilanKdvDurumu,
                    isDense: true,
                    style: const TextStyle(fontSize: 12, color: _primaryColor),
                    items: [
                      DropdownMenuItem(
                        value: 'excluded',
                        child: Text(
                          tr('settings.general.currencyCard.vatExcluded'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'included',
                        child: Text(
                          tr('settings.general.currencyCard.vatIncluded'),
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _ayarlar.varsayilanKdvDurumu = v!),
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('settings.general.currencyCard.defaultVatStatus'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: vatDropdown),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('settings.general.currencyCard.defaultVatStatus'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  vatDropdown,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _actionPrimary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _actionPrimary.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Text(
                  tr('settings.general.currencyCard.preview.label'),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrencyPreview(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _actionPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVergiAyarlariCard() {
    return _buildCompactCard(
      title: tr('settings.general.group.tax.title'),
      icon: Icons.receipt_long_rounded,
      accentColor: const Color(0xFFEF4444),
      children: [
        _buildSettingRow(
          label: tr('settings.general.fields.otv.label'),
          description: tr('settings.general.fields.otv.help'),
          trailing: _buildSwitch(
            value: _ayarlar.otvKullanimi,
            onChanged: (v) => setState(() => _ayarlar.otvKullanimi = v),
          ),
        ),
        if (_ayarlar.otvKullanimi) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: _buildSettingRow(
              label: tr('settings.general.fields.otvVatMode.label'),
              trailing: _buildMiniDropdown(
                value: _ayarlar.otvKdvDurumu,
                items: const ['excluded', 'included'],
                labelBuilder: (v) => v == 'excluded'
                    ? tr('settings.general.option.taxMode.excluded')
                    : tr('settings.general.option.taxMode.included'),
                onChanged: (v) => setState(() => _ayarlar.otvKdvDurumu = v),
              ),
            ),
          ),
        ],
        _buildSettingRow(
          label: tr('settings.general.fields.oiv.label'),
          description: tr('settings.general.fields.oiv.help'),
          trailing: _buildSwitch(
            value: _ayarlar.oivKullanimi,
            onChanged: (v) => setState(() => _ayarlar.oivKullanimi = v),
          ),
        ),
        if (_ayarlar.oivKullanimi) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: _buildSettingRow(
              label: tr('settings.general.fields.oivVatMode.label'),
              trailing: _buildMiniDropdown(
                value: _ayarlar.oivKdvDurumu,
                items: const ['excluded', 'included'],
                labelBuilder: (v) => v == 'excluded'
                    ? tr('settings.general.option.taxMode.excluded')
                    : tr('settings.general.option.taxMode.included'),
                onChanged: (v) => setState(() => _ayarlar.oivKdvDurumu = v),
              ),
            ),
          ),
        ],
        _buildSettingRow(
          label: tr('settings.general.fields.vatWithholding.label'),
          description: tr('settings.general.fields.vatWithholding.help'),
          trailing: _buildSwitch(
            value: _ayarlar.kdvTevkifati,
            onChanged: (v) => setState(() => _ayarlar.kdvTevkifati = v),
          ),
        ),
      ],
    );
  }

  Widget _buildUrunAyarlariCard() {
    return _buildCompactCard(
      title: tr('settings.general.group.product.title'),
      icon: Icons.inventory_2_rounded,
      accentColor: const Color(0xFF10B981),
      children: [
        _buildSettingRow(
          label: tr('settings.general.fields.orderDecrease.label'),
          trailing: _buildSwitch(
            value: _ayarlar.siparistenDus,
            onChanged: (v) => setState(() => _ayarlar.siparistenDus = v),
          ),
        ),
        _buildSettingRow(
          label: tr('settings.general.fields.quoteDecrease.label'),
          trailing: _buildSwitch(
            value: _ayarlar.tekliftenDus,
            onChanged: (v) => setState(() => _ayarlar.tekliftenDus = v),
          ),
        ),
        const Divider(height: 20),
        Text(
          tr('settings.general.units.group.title'),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: _primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        _buildUnitChips(),
        const SizedBox(height: 16),
        Text(
          tr('settings.general.groups.group.title'),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: _primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        _buildGroupChips(),
      ],
    );
  }

  Widget _buildStokAyarlariCard() {
    return _buildCompactCard(
      title: tr('settings.general.group.stock.title'),
      icon: Icons.warehouse_rounded,
      accentColor: const Color(0xFFEC4899),
      children: [
        _buildSettingRow(
          label: tr('settings.general.fields.allowSaleWithoutStock.label'),
          trailing: _buildSwitch(
            value: _ayarlar.eksiStokSatis,
            onChanged: (v) => setState(() => _ayarlar.eksiStokSatis = v),
          ),
        ),
        _buildSettingRow(
          label: tr(
            'settings.general.fields.allowProductionWithoutStock.label',
          ),
          trailing: _buildSwitch(
            value: _ayarlar.eksiStokUretim,
            onChanged: (v) => setState(() => _ayarlar.eksiStokUretim = v),
          ),
        ),
        _buildSettingRow(
          label: tr('settings.general.fields.negativeBalanceCheck.label'),
          trailing: _buildSwitch(
            value: _ayarlar.eksiBakiyeKontrol,
            onChanged: (v) => setState(() => _ayarlar.eksiBakiyeKontrol = v),
          ),
        ),
      ],
    );
  }

  Widget _buildKodUretimiCard() {
    return _buildCompactCard(
      title: tr('settings.codeGeneration.title'),
      icon: Icons.qr_code_rounded,
      accentColor: const Color(0xFF0EA5E9),
      children: [
        _buildCodeRow(
          tr('settings.general.fields.autoProductCode.label'),
          _ayarlar.otoStokKodu,
          (v) => _ayarlar.otoStokKodu = v,
          _ayarlar.otoStokKoduAlfanumerik,
          (v) => _ayarlar.otoStokKoduAlfanumerik = v,
        ),
        _buildCodeRow(
          tr('settings.general.fields.autoProductBarcode.label'),
          _ayarlar.otoStokBarkodu,
          (v) => _ayarlar.otoStokBarkodu = v,
          _ayarlar.otoStokBarkoduAlfanumerik,
          (v) => _ayarlar.otoStokBarkoduAlfanumerik = v,
        ),
        _buildCodeRow(
          tr('settings.general.fields.autoProductionCode.label'),
          _ayarlar.otoUretimKodu,
          (v) => _ayarlar.otoUretimKodu = v,
          _ayarlar.otoUretimKoduAlfanumerik,
          (v) => _ayarlar.otoUretimKoduAlfanumerik = v,
        ),
        _buildCodeRow(
          tr('settings.general.fields.autoProductionBarcode.label'),
          _ayarlar.otoUretimBarkodu,
          (v) => _ayarlar.otoUretimBarkodu = v,
          _ayarlar.otoUretimBarkoduAlfanumerik,
          (v) => _ayarlar.otoUretimBarkoduAlfanumerik = v,
        ),
        _buildCodeRow(
          tr('settings.general.fields.autoWarehouseCode.label'),
          _ayarlar.otoDepoKodu,
          (v) => _ayarlar.otoDepoKodu = v,
          _ayarlar.otoDepoKoduAlfanumerik,
          (v) => _ayarlar.otoDepoKoduAlfanumerik = v,
        ),
        _buildCodeRow(
          tr('settings.general.fields.autoCustomerCode.label'),
          _ayarlar.otoCariKodu,
          (v) => _ayarlar.otoCariKodu = v,
          _ayarlar.otoCariKoduAlfanumerik,
          (v) => _ayarlar.otoCariKoduAlfanumerik = v,
        ),
        _buildCodeRow(
          tr('settings.general.fields.autoCashCode.label'),
          _ayarlar.otoKasaKodu,
          (v) => _ayarlar.otoKasaKodu = v,
          _ayarlar.otoKasaKoduAlfanumerik,
          (v) => _ayarlar.otoKasaKoduAlfanumerik = v,
        ),
        _buildCodeRow(
          tr('settings.general.fields.autoBankCode.label'),
          _ayarlar.otoBankaKodu,
          (v) => _ayarlar.otoBankaKodu = v,
          _ayarlar.otoBankaKoduAlfanumerik,
          (v) => _ayarlar.otoBankaKoduAlfanumerik = v,
        ),
        _buildCodeRow(
          tr('settings.general.fields.autoCreditCardCode.label'),
          _ayarlar.otoKrediKartiKodu,
          (v) => _ayarlar.otoKrediKartiKodu = v,
          _ayarlar.otoKrediKartiKoduAlfanumerik,
          (v) => _ayarlar.otoKrediKartiKoduAlfanumerik = v,
        ),
        _buildCodeRow(
          tr('settings.general.fields.autoEmployeeCode.label'),
          _ayarlar.otoPersonelKodu,
          (v) => _ayarlar.otoPersonelKodu = v,
          _ayarlar.otoPersonelKoduAlfanumerik,
          (v) => _ayarlar.otoPersonelKoduAlfanumerik = v,
        ),
      ],
    );
  }

  Widget _buildCodeRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
    bool alfaValue,
    ValueChanged<bool> onAlfaChanged,
  ) {
    Widget formatSelector() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                hitTestBehavior: HitTestBehavior.deferToChild,
                child: GestureDetector(
                  onTap: () => setState(() => onAlfaChanged(false)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: !alfaValue ? _actionPrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      tr('settings.codeGeneration.format.numeric'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: !alfaValue ? Colors.white : _mutedColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                hitTestBehavior: HitTestBehavior.deferToChild,
                child: GestureDetector(
                  onTap: () => setState(() => onAlfaChanged(true)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: alfaValue ? _actionPrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      tr('settings.codeGeneration.format.alphanumeric'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: alfaValue ? Colors.white : _mutedColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: value ? _accentColor.withValues(alpha: 0.04) : _bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value
              ? _accentColor.withValues(alpha: 0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 520;
          final Widget toggle = _buildSwitch(
            value: value,
            onChanged: (v) => setState(() => onChanged(v)),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                          color: value ? _primaryColor : _mutedColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    toggle,
                  ],
                ),
                if (value) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: formatSelector(),
                  ),
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                    color: value ? _primaryColor : _mutedColor,
                  ),
                ),
              ),
              if (value) ...[formatSelector(), const SizedBox(width: 16)],
              toggle,
            ],
          );
        },
      ),
    );
  }

  Widget _buildYazdirmaCard() {
    return _buildCompactCard(
      title: tr('settings.cashPrint.title'),
      icon: Icons.print_rounded,
      accentColor: const Color(0xFF14B8A6),
      children: [
        Text(
          tr('settings.cashPrint.cashGroup.title'),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: _primaryColor,
          ),
        ),
        const SizedBox(height: 10),
        _buildCashInputRow(_nakit1Controller, _nakit2Controller),
        const SizedBox(height: 8),
        _buildCashInputRow(_nakit3Controller, _nakit4Controller),
        const SizedBox(height: 8),
        _buildCashInputRow(_nakit5Controller, _nakit6Controller),
        const Divider(height: 24),
        Text(
          tr('settings.cashPrint.printGroup.title'),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: _primaryColor,
          ),
        ),
        const SizedBox(height: 10),
        _buildSettingRow(
          label: tr('settings.cashPrint.print.enable.label'),
          trailing: _buildSwitch(
            value: _ayarlar.otomatikYazdir,
            onChanged: (v) => setState(() => _ayarlar.otomatikYazdir = v),
          ),
        ),
        _buildSettingRow(
          label: tr('settings.cashPrint.print.mode.label'),
          trailing: _buildMiniDropdown(
            value: _ayarlar.yazdirmaSablonu,
            items: const ['sales', 'detailed'],
            labelBuilder: (v) => v == 'sales'
                ? tr('settings.cashPrint.print.mode.option.sales')
                : tr('settings.cashPrint.print.mode.option.detailed'),
            onChanged: (v) => setState(() => _ayarlar.yazdirmaSablonu = v),
          ),
        ),
        _buildSettingRow(
          label: tr('settings.cashPrint.print.copyCount.label'),
          trailing: SizedBox(
            width: 80,
            height: 34,
            child: TextField(
              controller: _kopyaSayisiController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: _bgColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCashInputRow(
    TextEditingController firstController,
    TextEditingController secondController,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 420;
        if (isNarrow) {
          return Column(
            children: [
              _buildCashInput(firstController),
              const SizedBox(height: 8),
              _buildCashInput(secondController),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _buildCashInput(firstController)),
            const SizedBox(width: 8),
            Expanded(child: _buildCashInput(secondController)),
          ],
        );
      },
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        hitTestBehavior: HitTestBehavior.deferToChild,
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 24,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: value ? _accentColor : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
              boxShadow: value
                  ? [
                      BoxShadow(
                        color: _accentColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: value
                    ? const Icon(Icons.check, size: 12, color: _accentColor)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBaglantiAyarlariCard() {
    return _buildCompactCard(
      title: tr('settings.connection.title'),
      icon: Icons.lan_rounded,
      accentColor: _actionPrimary,
      children: [
        Text(
          tr('settings.connection.mode.description'),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),
        _buildConnectionModeOption(
          title: tr('settings.connection.mode.server'),
          subtitle: tr('settings.connection.mode.server.subtitle'),
          mode: 'server',
          icon: Icons.dns_rounded,
        ),
        const SizedBox(height: 12),
        _buildConnectionModeOption(
          title: tr('settings.connection.mode.terminal'),
          subtitle: tr('settings.connection.mode.terminal.subtitle'),
          mode: 'terminal',
          icon: Icons.computer_rounded,
        ),
        if (_masaustuYerelSunucuSecimiDestekleniyor &&
            _baglantiRolu == 'terminal') ...[
          const SizedBox(height: 16),
          _buildYerelSunucuSecimPaneli(),
        ],
      ],
    );
  }

  Widget _buildYerelSunucuSecimPaneli() {
    final hasServers = _yerelSunucular.isNotEmpty;
    final selectedHost = (_seciliYerelSunucuHost ?? '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _actionPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _actionPrimary.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _actionPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.router_rounded,
                  size: 15,
                  color: _actionPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('settings.connection.server_list_title'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _primaryColor,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _yerelSunucularYukleniyor
                    ? null
                    : () => _yerelSunuculariTara(showError: true),
                icon: _yerelSunucularYukleniyor
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _actionPrimary.withValues(alpha: 0.8),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(tr('common.search_again')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _actionPrimary,
                  side: BorderSide(
                    color: _actionPrimary.withValues(alpha: 0.2),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tr('settings.connection.server_list_help'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          if (_yerelSunucularYukleniyor && !hasServers)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _actionPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('settings.connection.server_searching'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (!hasServers)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('settings.connection.server_list_empty'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _yerelSunucularHatasi?.trim().isNotEmpty == true
                        ? tr('settings.connection.server_list_error_hint')
                        : tr('settings.connection.server_list_empty_hint'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (selectedHost.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      tr(
                        'settings.connection.current_server_label',
                        args: {'host': selectedHost},
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _actionPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: RadioGroup<String>(
                groupValue: selectedHost.isEmpty ? null : selectedHost,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _seciliYerelSunucuHost = value);
                },
                child: Column(
                  children: _yerelSunucular.asMap().entries.map((entry) {
                    final index = entry.key;
                    final server = entry.value;
                    final host = (server.host ?? '').trim();
                    final title = (server.name ?? host).trim();
                    final isSelected = selectedHost == host;

                    return InkWell(
                      mouseCursor: WidgetStateMouseCursor.clickable,
                      onTap: () =>
                          setState(() => _seciliYerelSunucuHost = host),
                      borderRadius: BorderRadius.vertical(
                        top: index == 0
                            ? const Radius.circular(12)
                            : Radius.zero,
                        bottom: index == _yerelSunucular.length - 1
                            ? const Radius.circular(12)
                            : Radius.zero,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: index == _yerelSunucular.length - 1
                              ? null
                              : Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade100,
                                  ),
                                ),
                          color: isSelected
                              ? _actionPrimary.withValues(alpha: 0.05)
                              : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title.isEmpty ? host : title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? _actionPrimary
                                          : _primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    host,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Radio<String>(
                              value: host,
                              activeColor: _actionPrimary,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _sistemYazicilariniYukle() async {
    if (!_masaustuYaziciSecimiDestekleniyor) return;

    setState(() {
      _sistemYazicilariYukleniyor = true;
      _sistemYazicilariHatasi = null;
    });

    try {
      final printers = (await Printing.listPrinters()).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;

      setState(() {
        _sistemYazicilari = printers;
        _sistemYazicilariYukleniyor = false;
      });
    } catch (e) {
      debugPrint('Sistem yazıcıları yüklenemedi: $e');
      if (!mounted) return;

      setState(() {
        _sistemYazicilari = [];
        _sistemYazicilariYukleniyor = false;
        _sistemYazicilariHatasi = e.toString();
      });
    }
  }

  String _yaziciKimligi(Printer printer) {
    final url = printer.url.trim();
    if (url.isNotEmpty) return url;
    return printer.name.trim();
  }

  Printer? _kayitliYaziciSecimi() {
    final raw = _ayarlar.yaziciSecimi.trim();
    if (raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Printer.fromMap(decoded);
      }
    } catch (_) {}

    return Printer(url: raw, name: raw);
  }

  Printer? _sistemdeSeciliYaziciyiBul() {
    final selectedPrinter = _kayitliYaziciSecimi();
    if (selectedPrinter == null) return null;

    final selectedIdentity = _yaziciKimligi(selectedPrinter);
    for (final printer in _sistemYazicilari) {
      if (_yaziciKimligi(printer) == selectedIdentity ||
          printer.name.trim() == selectedPrinter.name.trim()) {
        return printer;
      }
    }

    return null;
  }

  Printer? _yaziciyiKimliktenBul(String identity) {
    for (final printer in _sistemYazicilari) {
      if (_yaziciKimligi(printer) == identity) {
        return printer;
      }
    }

    return null;
  }

  String _yaziciListeEtiketi(String identity) {
    if (identity.isEmpty) return tr('common.none');

    final printer = _yaziciyiKimliktenBul(identity);
    if (printer == null) return identity;

    final isDefault = printer.isDefault ? ' (${tr('common.default')})' : '';
    return '${printer.name}$isDefault';
  }

  String _yaziciMetaBilgisi(Printer printer) {
    final parts = <String>[
      if ((printer.model ?? '').trim().isNotEmpty) printer.model!.trim(),
      if ((printer.location ?? '').trim().isNotEmpty) printer.location!.trim(),
    ];

    return parts.join(' • ');
  }

  Widget _buildBaglantiYaziciAyarlariCard() {
    final selectedPrinter = _sistemdeSeciliYaziciyiBul();
    final selectedIdentity = selectedPrinter != null
        ? _yaziciKimligi(selectedPrinter)
        : '';
    final hasStoredPrinter = _ayarlar.yaziciSecimi.trim().isNotEmpty;
    final storedPrinterMissing = hasStoredPrinter && selectedPrinter == null;
    final printerItems = <String>['', ..._sistemYazicilari.map(_yaziciKimligi)];
    const accentColor = Color(0xFF0F766E);

    return _buildCompactCard(
      title: tr('settings.connection.printer.title'),
      icon: Icons.print_rounded,
      accentColor: accentColor,
      trailing: OutlinedButton.icon(
        onPressed: _sistemYazicilariYukleniyor
            ? null
            : _sistemYazicilariniYukle,
        icon: _sistemYazicilariYukleniyor
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded, size: 16),
        label: Text(
          tr('settings.connection.printer.refresh'),
          style: const TextStyle(fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: BorderSide(color: accentColor.withValues(alpha: 0.18)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      children: [
        Text(
          tr('settings.connection.printer.description'),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.12)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.devices_rounded,
                  size: 20,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('settings.connection.printer.section.title'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('settings.connection.printer.section.subtitle'),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_sistemYazicilariYukleniyor) ...[
          Text(
            tr('settings.connection.printer.loading'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(minHeight: 6),
          ),
        ] else if (_sistemYazicilariHatasi != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('settings.connection.printer.error'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF7F1D1D),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (_sistemYazicilari.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.print_disabled_rounded,
                  size: 18,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('settings.connection.printer.empty'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          _buildDropdown(
            label: tr('settings.connection.printer.dropdown.label'),
            value: printerItems.contains(selectedIdentity)
                ? selectedIdentity
                : '',
            items: printerItems,
            onChanged: (value) {
              setState(() {
                if (value.isEmpty) {
                  _ayarlar.yaziciSecimi = '';
                  return;
                }

                final printer = _yaziciyiKimliktenBul(value);
                if (printer != null) {
                  _ayarlar.yaziciSecimi = jsonEncode(printer.toMap());
                }
              });
            },
            labelBuilder: _yaziciListeEtiketi,
          ),
          const SizedBox(height: 8),
          Text(
            tr('settings.connection.printer.dropdown.help'),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
        if (selectedPrinter != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.print_rounded,
                    size: 18,
                    color: Color(0xFF047857),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedPrinter.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _yaziciMetaBilgisi(selectedPrinter).isNotEmpty
                            ? _yaziciMetaBilgisi(selectedPrinter)
                            : tr('settings.connection.printer.dropdown.help'),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedPrinter.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      tr('common.default'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (storedPrinterMissing) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('settings.connection.printer.missing'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _selectedPrinterNameOrFallback() {
    return _kayitliYaziciSecimi()?.name ?? tr('common.none');
  }

  Future<void> _pickPrinter() async {
    try {
      Rect? bounds;
      final renderBox =
          _printerPickerAnchorKey.currentContext?.findRenderObject()
              as RenderBox?;
      if (renderBox != null) {
        final offset = renderBox.localToGlobal(Offset.zero);
        bounds = offset & renderBox.size;
      }

      final printer = await Printing.pickPrinter(
        context: context,
        bounds: bounds,
        title: tr('settings.printer.select.title'),
      );

      if (!mounted) return;
      if (printer == null) return;

      setState(() {
        _ayarlar.yaziciSecimi = jsonEncode(printer.toMap());
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('settings.printer.select.error', args: {'error': '$e'}),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _printTestPage() async {
    if (_printingDisabled) return;

    try {
      final doc = pw.Document();
      final now = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Center(
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    'Patisyo',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    tr('settings.printer.test.pageTitle'),
                    style: const pw.TextStyle(fontSize: 16),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text('${tr('common.date')}: $now'),
                ],
              ),
            );
          },
        ),
      );

      final Uint8List bytes = await doc.save();

      await Printing.layoutPdf(
        name: tr('settings.printer.test.document'),
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('settings.printer.test.error', args: {'error': '$e'}),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildYaziciAyarlariCard() {
    final selectedPrinterName = _selectedPrinterNameOrFallback();

    return _buildCompactCard(
      title: tr('settings.printer.title'),
      icon: Icons.print_rounded,
      accentColor: const Color(0xFF14B8A6),
      children: [
        Text(
          tr('settings.cashPrint.print.printer.help'),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        _buildSettingRow(
          label: tr('settings.printer.default.label'),
          description: tr('settings.cashPrint.print.printer.help'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                mouseCursor: WidgetStateMouseCursor.clickable,
                key: _printerPickerAnchorKey,
                onTap: _pickPrinter,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.print_rounded,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          selectedPrinterName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
              if (_ayarlar.yaziciSecimi.trim().isNotEmpty) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: tr('common.clear'),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () => setState(() => _ayarlar.yaziciSecimi = ''),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 24),
        _buildSettingRow(
          label: tr('settings.cashPrint.print.enable.label'),
          trailing: _buildSwitch(
            value: _ayarlar.otomatikYazdir,
            onChanged: (v) => setState(() => _ayarlar.otomatikYazdir = v),
          ),
        ),
        _buildSettingRow(
          label: tr('settings.cashPrint.print.mode.label'),
          trailing: _buildMiniDropdown(
            value: _ayarlar.yazdirmaSablonu,
            items: const ['sales', 'detailed'],
            labelBuilder: (v) => v == 'sales'
                ? tr('settings.cashPrint.print.mode.option.sales')
                : tr('settings.cashPrint.print.mode.option.detailed'),
            onChanged: (v) => setState(() => _ayarlar.yazdirmaSablonu = v),
          ),
        ),
        _buildSettingRow(
          label: tr('settings.cashPrint.print.copyCount.label'),
          trailing: SizedBox(
            width: 80,
            height: 34,
            child: TextField(
              controller: _kopyaSayisiController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: _bgColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _printingDisabled ? null : _printTestPage,
            icon: const Icon(Icons.print_rounded, size: 18),
            label: Text(tr('settings.printer.test.button')),
            style: OutlinedButton.styleFrom(
              foregroundColor: _printingDisabled
                  ? Colors.grey.shade500
                  : _primaryColor,
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionModeOption({
    required String title,
    required String subtitle,
    required String mode,
    required IconData icon,
  }) {
    final isSelected = _baglantiRolu == mode;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: () {
        setState(() => _baglantiRolu = mode);
        if (mode == 'terminal' &&
            _masaustuYerelSunucuSecimiDestekleniyor &&
            !_yerelSunucularYukleniyor &&
            (!_yerelSunucularTarandi || _yerelSunucular.isEmpty)) {
          _yerelSunuculariTara(showError: false);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _actionPrimary.withValues(alpha: 0.05) : _bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _actionPrimary : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? _actionPrimary.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? _actionPrimary : _mutedColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: isSelected ? _actionPrimary : _primaryColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: _actionPrimary),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberStepper({
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      width: 100,
      height: 32,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: value > 0
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: InkWell(
              mouseCursor: WidgetStateMouseCursor.clickable,
              onTap: value > 0 ? () => onChanged(value - 1) : null,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(7),
              ),
              child: SizedBox(
                width: 28,
                height: double.infinity,
                child: Icon(
                  Icons.remove,
                  size: 14,
                  color: value > 0 ? _primaryColor : Colors.grey.shade400,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          MouseRegion(
            cursor: value < 6
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: InkWell(
              mouseCursor: WidgetStateMouseCursor.clickable,
              onTap: value < 6 ? () => onChanged(value + 1) : null,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(7),
              ),
              child: SizedBox(
                width: 28,
                height: double.infinity,
                child: Icon(
                  Icons.add,
                  size: 14,
                  color: value < 6 ? _primaryColor : Colors.grey.shade400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    String Function(String)? labelBuilder,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<String>(
      mouseCursor: WidgetStateMouseCursor.clickable,
      dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
      key: ValueKey('ga_dropdown_${label}_${value}_${items.length}'),
      initialValue: items.contains(value) ? value : items.first,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13, color: _primaryColor),
      items: items
          .map(
            (i) => DropdownMenuItem(
              value: i,
              child: Text(labelBuilder != null ? labelBuilder(i) : i),
            ),
          )
          .toList(),
      onChanged: enabled ? (v) => onChanged(v!) : null,
    );
  }

  Widget _buildMiniDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    String Function(String)? labelBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          mouseCursor: WidgetStateMouseCursor.clickable,
          dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
          value: value,
          isDense: true,
          style: const TextStyle(fontSize: 11, color: _primaryColor),
          items: items
              .map(
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(labelBuilder != null ? labelBuilder(i) : i),
                ),
              )
              .toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }

  Widget _buildCashInput(TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: '0.00',
        hintStyle: TextStyle(color: Colors.grey.shade400),
        filled: true,
        fillColor: _bgColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(
          Icons.payments_outlined,
          size: 16,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildUnitChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ..._ayarlar.urunBirimleri.map((unit) {
          final isDefault = unit['isDefault'] == true;
          return Chip(
            mouseCursor: WidgetStateMouseCursor.clickable,
            label: Text(
              unit['name'],
              style: TextStyle(
                fontSize: 11,
                color: isDefault ? _actionPrimary : _primaryColor,
              ),
            ),
            backgroundColor: isDefault
                ? _actionPrimary.withValues(alpha: 0.1)
                : _bgColor,
            side: BorderSide(
              color: isDefault
                  ? _actionPrimary.withValues(alpha: 0.3)
                  : Colors.grey.shade300,
            ),
            deleteIcon: const Icon(Icons.close, size: 14),
            onDeleted: () {
              setState(() {
                _ayarlar.urunBirimleri.remove(unit);
                if (isDefault && _ayarlar.urunBirimleri.isNotEmpty) {
                  _ayarlar.urunBirimleri.first['isDefault'] = true;
                }
              });
            },
            visualDensity: VisualDensity.compact,
          );
        }),
        ActionChip(
          avatar: const Icon(Icons.add, size: 14),
          label: Text(tr('common.add'), style: const TextStyle(fontSize: 11)),
          onPressed: _showAddUnitDialog,
          mouseCursor: WidgetStateMouseCursor.clickable,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildGroupChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ..._ayarlar.urunGruplari.map((group) {
          final color = Color(group['color'] ?? 0xFF2196F3);
          return Chip(
            mouseCursor: WidgetStateMouseCursor.clickable,
            avatar: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            label: Text(group['name'], style: const TextStyle(fontSize: 11)),
            deleteIcon: const Icon(Icons.close, size: 14),
            onDeleted: () =>
                setState(() => _ayarlar.urunGruplari.remove(group)),
            backgroundColor: _bgColor,
            side: BorderSide(color: Colors.grey.shade300),
            visualDensity: VisualDensity.compact,
          );
        }),
        ActionChip(
          avatar: const Icon(Icons.add, size: 14),
          label: Text(
            tr('settings.general.groups.addButton'),
            style: const TextStyle(fontSize: 11),
          ),
          onPressed: _showAddGroupDialog,
          mouseCursor: WidgetStateMouseCursor.clickable,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  String _formatCurrencyPreview() {
    String integerPart = '12345';
    String decimalPart = '67';
    if (_ayarlar.binlikAyiraci == '.') {
      integerPart = '12.345';
    } else if (_ayarlar.binlikAyiraci == ',') {
      integerPart = '12,345';
    } else if (_ayarlar.binlikAyiraci == ' ') {
      integerPart = '12 345';
    }
    String separator = _ayarlar.ondalikAyiraci == ' '
        ? ' '
        : _ayarlar.ondalikAyiraci;
    String result = '$integerPart$separator$decimalPart';
    if (_ayarlar.sembolGoster) {
      switch (_ayarlar.varsayilanParaBirimi) {
        case 'TRY':
          result = '₺$result';
        case 'USD':
          result = '\$$result';
        case 'EUR':
          result = '€$result';
        case 'GBP':
          result = '£$result';
        default:
          result = '$result ${_ayarlar.varsayilanParaBirimi}';
      }
    }
    return result;
  }

  // ==================== DIALOGS ====================

  void _showAddCurrencyDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            final allCurrencies = ParaBirimleriData.tumParaBirimleri.entries
                .where(
                  (entry) =>
                      !_ayarlar.kullanilanParaBirimleri.contains(entry.key),
                )
                .where((entry) {
                  final code = entry.key.toLowerCase();
                  final country = tr('country.${entry.value}').toLowerCase();
                  final query = searchQuery.toLowerCase();
                  return code.contains(query) || country.contains(query);
                })
                .toList();

            return AlertDialog(
              title: Text(tr('settings.general.currency.add.title')),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: tr('settings.general.currency.add.search'),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (val) =>
                          setStateBuilder(() => searchQuery = val),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: allCurrencies.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(tr('common.no_results')),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: allCurrencies.length,
                              itemBuilder: (context, index) {
                                final entry = allCurrencies[index];
                                return ListTile(
                                  title: Text(
                                    '${entry.key} (${tr('country.${entry.value}')})',
                                  ),
                                  onTap: () {
                                    setState(
                                      () => _ayarlar.kullanilanParaBirimleri
                                          .add(entry.key),
                                    );
                                    Navigator.pop(dialogContext);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(tr('common.cancel')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddUnitDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('settings.general.units.addDialog.title')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: tr('settings.general.units.addDialog.nameHint'),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _ayarlar.urunBirimleri.add({
                    'name': controller.text.trim(),
                    'isDefault': _ayarlar.urunBirimleri.isEmpty,
                  });
                });
                Navigator.pop(context);
              }
            },
            child: Text(tr('settings.general.units.addDialog.save')),
          ),
        ],
      ),
    );
  }

  void _showAddGroupDialog() {
    final controller = TextEditingController();
    int selectedColor = 0xFF2196F3;
    final colors = [
      0xFF2196F3,
      0xFF4CAF50,
      0xFFFF9800,
      0xFFF44336,
      0xFF9C27B0,
      0xFF00BCD4,
      0xFF795548,
      0xFF607D8B,
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(tr('settings.general.groups.addButton')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: tr('settings.general.groups.group.title'),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((color) {
                  final isSelected = selectedColor == color;
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    hitTestBehavior: HitTestBehavior.deferToChild,
                    child: GestureDetector(
                      onTap: () => setState(() => selectedColor = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(context).primaryColor,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('common.cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  this.setState(
                    () => _ayarlar.urunGruplari.add({
                      'name': controller.text.trim(),
                      'color': selectedColor,
                    }),
                  );
                  Navigator.pop(context);
                }
              },
              child: Text(tr('settings.general.groups.addDialog.save')),
            ),
          ],
        ),
      ),
    );
  }
}
