import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'ayarlar/menu_ayarlari.dart';
import 'bilesenler/ust_bar.dart';
import 'bilesenler/yan_menu.dart';
import 'bilesenler/tab_yonetici.dart';
import 'bilesenler/tab_acici_scope.dart';
import 'sayfalar/carihesaplar/modeller/cari_hesap_model.dart';
import 'yardimcilar/ceviri/ceviri_servisi.dart';
import 'yardimcilar/app_route_observer.dart';
import 'sayfalar/ayarlar/veritabaniyedekayarlari/veritabani_yedek_ayarlari_sayfasi.dart';
import 'sayfalar/ayarlar/genel_ayarlar/genel_ayarlar_sayfasi.dart';
import 'ayarlar/ai_ayarlari_sayfasi.dart';
import 'sayfalar/ayarlar/dil/dil_ayarlari.dart';
import 'sayfalar/ayarlar/sirketayarlari/sirket_ayarlari_sayfasi.dart';
import 'sayfalar/ayarlar/kullanicilar/kullanici_ayarlari_sayfasi.dart';
import 'sayfalar/ayarlar/roller_ve_izinler/roller_ve_izinler_sayfasi.dart';
import 'servisler/oturum_servisi.dart';
import 'sayfalar/alimsatimislemleri/modeller/transaction_item.dart';
import 'sayfalar/ayarlar/kullanicilar/modeller/kullanici_model.dart';
import 'sayfalar/ayarlar/sirketayarlari/modeller/sirket_ayarlari_model.dart';
import 'package:patisyov10/sayfalar/urunler_ve_depolar/depolar/depolar_sayfasi.dart';
import 'package:patisyov10/sayfalar/alimsatimislemleri/alis_yap_sayfasi.dart';
import 'package:patisyov10/sayfalar/alimsatimislemleri/satis_yap_sayfasi.dart';
import 'package:patisyov10/sayfalar/alimsatimislemleri/perakende_satis_sayfasi.dart';
import 'package:patisyov10/sayfalar/alimsatimislemleri/hizli_satis_sayfasi.dart';
import 'sayfalar/urunler_ve_depolar/urunler/urunler_sayfasi.dart';
import 'sayfalar/urunler_ve_depolar/uretimler/uretimler_sayfasi.dart';
import 'sayfalar/carihesaplar/cari_hesaplar_sayfasi.dart';
import 'sayfalar/kasalar/kasalar_sayfasi.dart';
import 'sayfalar/bankalar/bankalar_sayfasi.dart';
import 'sayfalar/kredikartlari/kredi_kartlari_sayfasi.dart';
import 'sayfalar/ceksenet/cekler_sayfasi.dart';
import 'sayfalar/ceksenet/senetler_sayfasi.dart';
import 'sayfalar/carihesaplar/cari_karti_sayfasi.dart';
import 'sayfalar/siparisler_teklifler/siparisler_sayfasi.dart';
import 'sayfalar/siparisler_teklifler/teklifler_sayfasi.dart';
import 'servisler/pencere_durumu_servisi.dart';
import 'servisler/sayfa_senkronizasyon_servisi.dart';
import 'sayfalar/giderler/giderler_sayfasi.dart';
import 'sayfalar/ayarlar/yazdirma_ayarlari/yazdirma_ayarlari_sayfasi.dart';
import 'sayfalar/ayarlar/moduller/moduller_sayfasi.dart';
import 'sayfalar/urunler_ve_depolar/urunler/urun_karti_sayfasi.dart';
import 'sayfalar/urunler_ve_depolar/urunler/modeller/urun_model.dart';
import 'servisler/lisans_servisi.dart';
import 'sayfalar/baslangic/bootstrap_sayfasi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mobil/Tablet (iOS/Android) cihazlarda uygulamayı varsayılan olarak dikey
  // (portrait) kilitli kullan. (Perakende Satış sayfası tablette landscape'i
  // sayfa özelinde açar.)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  // Desktop pencere yönetimi kodlarını birebir koruyoruz (User Rule: "Cerrah Titizliği")
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    final savedWindowState = await PencereDurumuServisi().kayitliDurumuGetir();
    final Size initialSize = Platform.isWindows
        ? const Size(1280, 720)
        : (savedWindowState?.size ?? const Size(1280, 720));

    final WindowOptions windowOptions = WindowOptions(
      size: initialSize,
      minimumSize: const Size(360, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (Platform.isWindows) {
        await windowManager.maximize();
        await windowManager.show();
        await windowManager.focus();
        return;
      }

      final bool shouldMaximize = savedWindowState?.isMaximized ?? true;
      if (shouldMaximize) await windowManager.maximize();

      await windowManager.show();
      await windowManager.focus();
    });

    await PencereDurumuServisi().dinlemeyiBaslat();
  }

  // Tüm ağır servis başlatma işlemleri BootstrapSayfasi içinde BaglantiYoneticisi tarafından yapılacak.
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp>
    with WidgetsBindingObserver, WindowListener {
  Timer? _heartbeatTimer;
  final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    windowManager.addListener(this);
    _initWindow();

    // Heartbeat başlatan timer (Her 5 dakikada bir)
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      LisansServisi().heartbeatGonder();
    });
  }

  void _initWindow() async {
    // Kapatma isteğini yakalamak için preventClose'u aktif yapıyoruz
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await windowManager.setPreventClose(true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Pencere kapatılırken anlık offline sinyali gönder
    debugPrint('Lisans Servisi: Uygulama kapatılıyor, offline yapılıyor...');
    // UX: Önce pencereyi gizle (kapatma hissi anlık olsun)
    try {
      await windowManager.hide();
    } catch (_) {}

    // Offline sinyalini gönder ama kapanmayı bekletme (timeout ile)
    try {
      await LisansServisi()
          .durumGuncelle(false)
          .timeout(const Duration(milliseconds: 1500));
    } catch (e) {
      debugPrint('Lisans Servisi: Offline sinyali gonderilemedi: $e');
    }

    // Pencereyi yok et
    await windowManager.destroy();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama durumuna göre online/offline güncelle
    // Flickering'i önlemek için:
    // - Masaüstünde 'inactive' durumu bazen pencere focusu değişince tetiklenir, bu yüzden 'paused' beklemek daha güvenlidir.
    if (state == AppLifecycleState.resumed) {
      LisansServisi().durumGuncelle(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Sadece uygulama gerçekten arka plana atıldığında veya kapandığında offline yap
      LisansServisi().durumGuncelle(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: CeviriServisi()),
        ChangeNotifierProvider.value(value: SayfaSenkronizasyonServisi()),
      ],
      child: Consumer<CeviriServisi>(
        builder: (context, ceviriServisi, child) {
          final baseScheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFF2C3E50),
          );
          final scheme = baseScheme.copyWith(
            primary: const Color(0xFF2C3E50),
            onPrimary: Colors.white,
            secondary: const Color(0xFFF39C12),
            onSecondary: Colors.white,
            tertiary: const Color(0xFFEA4335),
            onTertiary: Colors.white,
            error: const Color(0xFFEA4335),
            onError: Colors.white,
          );

	          return MaterialApp(
	            navigatorKey: _rootNavigatorKey,
	            navigatorObservers: [appRouteObserver],
	            debugShowCheckedModeBanner: false,
	            title: tr('app.title'),
	            theme: ThemeData(
	              useMaterial3: true,
              colorScheme: scheme,
              primaryColor: const Color(0xFF2C3E50),
              fontFamily: 'Inter',
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA4335),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEA4335),
                  foregroundColor: Colors.white,
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2C3E50),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2C3E50),
                ),
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xFFEA4335),
                foregroundColor: Colors.white,
              ),
            ),
            locale: Locale(ceviriServisi.mevcutDil),
            supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const BootstrapSayfasi(),
          );
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final KullaniciModel currentUser;
  final SirketAyarlariModel currentCompany;

  const HomePage({
    super.key,
    required this.currentUser,
    required this.currentCompany,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSidebarExpanded = false;
  int _selectedIndex = 0;
  Timer? _hoverTimer;
  bool _isSidebarPinned = true;
  bool _isSidebarHovered = false;
  int _refreshKey = 0;
  late SirketAyarlariModel _currentCompany;

  // Tab sistemi için değişkenler
  final List<TabVeri> _acikTablar = [];
  int _aktifTabIndex = -1;
  CariHesapModel? _pendingInitialCari;
  UrunModel? _pendingInitialUrun;
  List<TransactionItem>? _pendingInitialItems;
  String? _pendingInitialCurrency;
  String? _pendingInitialDescription;
  String? _pendingInitialOrderRef;
  int? _pendingQuoteRef;
  double? _pendingInitialRate;
  Map<String, dynamic>? _pendingDuzenlenecekIslem;
  String? _pendingInitialSearchQuery;
  String? _aktifAlisDuzenlemeRef;
  String? _aktifSatisDuzenlemeRef;

  // Perakende satış index'i (Navigator ile açılıyor - Mevcut yapı korunuyor)
  static const int _perakendeSatisIndex = 12;

  String? _extractIntegrationRef(Map<String, dynamic>? islem) {
    if (islem == null) return null;
    final raw =
        islem['integration_ref'] ?? islem['integrationRef'] ?? islem['ref'];
    final ref = raw?.toString().trim() ?? '';
    return ref.isEmpty ? null : ref;
  }

  void _clearPendingInitialParams() {
    _pendingInitialCari = null;
    _pendingInitialUrun = null;
    _pendingInitialItems = null;
    _pendingInitialCurrency = null;
    _pendingInitialDescription = null;
    _pendingInitialOrderRef = null;
    _pendingQuoteRef = null;
    _pendingInitialRate = null;
    _pendingDuzenlenecekIslem = null;
    _pendingInitialSearchQuery = null;
  }

  @override
  void initState() {
    super.initState();
    _currentCompany = widget.currentCompany;
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  /// Menüden bir öğe seçildiğinde çağrılır
  void _onMenuItemSelected(int index) {
    // Bir sayfa seçildiğinde sidebar'ı kapat (sadece iconlar kalsın)
    // Hover ile yine açılabilir
    if (_isSidebarPinned) {
      setState(() {
        _isSidebarPinned = false;
      });
    }

    /* 
    // Ayarlar menüsü artık tab sistemi içinde açılacak
    if (_ayarlarIndexleri.contains(index)) {
      setState(() {
        _selectedIndex = index;
        _aktifTabIndex = -1; 
      });
      return;
    }
    */

    // Perakende satış ayrı sayfada açılır
    if (index == _perakendeSatisIndex) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PerakendeSatisSayfasi()),
      );
      return;
    }

    // Diğer sayfalar tab olarak açılır
    _tabAcVeyaSec(index);
  }

  /// Tab açar veya mevcut tab'ı seçer (isteğe bağlı parametreler ile)
  void _tabAcVeyaSec(
    int menuIndex, {
    CariHesapModel? initialCari,
    UrunModel? initialUrun,
    List<TransactionItem>? initialItems,
    String? initialCurrency,
    String? initialDescription,
    String? initialOrderRef,
    int? quoteRef,
    double? initialRate,
    String? initialSearchQuery,
    Map<String, dynamic>? duzenlenecekIslem,
  }) {
    // Parametreleri sakla
    _pendingInitialCari = initialCari;
    _pendingInitialUrun = initialUrun;
    _pendingInitialItems = initialItems;
    _pendingInitialCurrency = initialCurrency;
    _pendingInitialDescription = initialDescription;
    _pendingInitialOrderRef = initialOrderRef;
    _pendingQuoteRef = quoteRef;
    _pendingInitialRate = initialRate;
    _pendingInitialSearchQuery = initialSearchQuery;
    _pendingDuzenlenecekIslem = duzenlenecekIslem;

    final String? islemRef = _extractIntegrationRef(duzenlenecekIslem);
    final bool isTradingOperation = menuIndex == 10 || menuIndex == 11;
    final String? aktifIslemRef = isTradingOperation
        ? (menuIndex == 10 ? _aktifAlisDuzenlemeRef : _aktifSatisDuzenlemeRef)
        : null;

    // Cari ve Ürün Kartı için özel tab ID oluştur
    final bool isCariKarti = menuIndex == TabAciciScope.cariKartiIndex;
    final bool isUrunKarti = menuIndex == TabAciciScope.urunKartiIndex;

    final String cariKartiId = isCariKarti && initialCari != null
        ? 'cari_karti_${initialCari.id}'
        : '';
    final String urunKartiId = isUrunKarti && initialUrun != null
        ? 'urun_karti_${initialUrun.id}'
        : '';

    // Tab zaten açık mı kontrol et
    final mevcutTabIndex = _acikTablar.indexWhere((t) {
      if (isCariKarti && initialCari != null) {
        return t.id == cariKartiId;
      }
      if (isUrunKarti && initialUrun != null) {
        return t.id == urunKartiId;
      }
      return t.menuIndex == menuIndex;
    });

    if (mevcutTabIndex != -1) {
      // Satış/Alış düzenleme: aynı entegrasyon ref zaten açıksa yeni tab/sayfa açma,
      // mevcut tab'a odaklan.
      if (isTradingOperation && islemRef != null && aktifIslemRef == islemRef) {
        _clearPendingInitialParams();
        setState(() {
          _aktifTabIndex = mevcutTabIndex;
          _selectedIndex = menuIndex;
        });
        return;
      }

      // Tab zaten açık, onu seç
      // Eğer initialCari varsa ve Cari Kartı değilse yeni bir tab açmamız gerekiyor
      if (initialCari != null && !isCariKarti) {
        // Alış/Satış sayfaları için: Mevcut tab'ı kapat ve yenisini aç
        _acikTablar.removeAt(mevcutTabIndex);
        if (_aktifTabIndex >= mevcutTabIndex) {
          _aktifTabIndex = (_aktifTabIndex - 1).clamp(
            0,
            _acikTablar.length - 1,
          );
        }
      } else {
        // Cari/Ürün Kartı zaten açık veya normal sayfa - mevcut tab'a geç
        _clearPendingInitialParams();
        setState(() {
          _aktifTabIndex = mevcutTabIndex;
          _selectedIndex = menuIndex;
        });
        return;
      }
    }

    // Yeni tab oluştur
    final tabVeri = _tabVeriOlustur(
      menuIndex,
      cariKartiId: cariKartiId,
      urunKartiId: urunKartiId,
    );
    if (tabVeri != null) {
      setState(() {
        _acikTablar.add(tabVeri);
        _aktifTabIndex = _acikTablar.length - 1;
        _selectedIndex = menuIndex;
        if (isTradingOperation) {
          if (menuIndex == 10) {
            _aktifAlisDuzenlemeRef = islemRef;
          } else if (menuIndex == 11) {
            _aktifSatisDuzenlemeRef = islemRef;
          }
        }
      });
    }
  }

  /// Tab verisi oluşturur
  TabVeri? _tabVeriOlustur(
    int menuIndex, {
    String cariKartiId = '',
    String urunKartiId = '',
  }) {
    // Cari Kartı için özel durum
    if (menuIndex == TabAciciScope.cariKartiIndex &&
        _pendingInitialCari != null) {
      final cari = _pendingInitialCari!;
      return TabVeri(
        id: cariKartiId.isNotEmpty ? cariKartiId : 'cari_karti_${cari.id}',
        baslik: '${cari.adi} - ${tr('accounts.card_title')}',
        baslikOlusturucu: () => '${cari.adi} - ${tr('accounts.card_title')}',
        ikon: Icons.person_rounded,
        menuIndex: menuIndex,
        sayfaOlusturucu: () => CariKartiSayfasi(cariHesap: cari),
      );
    }

    // Ürün Kartı için özel durum
    if (menuIndex == TabAciciScope.urunKartiIndex &&
        _pendingInitialUrun != null) {
      final urun = _pendingInitialUrun!;
      return TabVeri(
        id: urunKartiId.isNotEmpty ? urunKartiId : 'urun_karti_${urun.id}',
        baslik: '${urun.ad} - ${tr('products.card.title')}',
        baslikOlusturucu: () => '${urun.ad} - ${tr('products.card.title')}',
        ikon: Icons.inventory_2_rounded,
        menuIndex: menuIndex,
        sayfaOlusturucu: () => UrunKartiSayfasi(urun: urun),
      );
    }

    final menuItem = MenuAyarlari.findByIndex(menuIndex);
    if (menuItem == null) return null;

    return TabVeri(
      id: '${menuItem.id}_$menuIndex',
      baslik: tr(menuItem.labelKey),
      baslikKey: menuItem.labelKey,
      ikon: menuItem.icon,
      menuIndex: menuIndex,
      sayfaOlusturucu: () => _pageForIndex(menuIndex),
    );
  }

  /// Tab kapatıldığında çağrılır
  void _onTabKapatildi(int tabIndex) {
    if (tabIndex < 0 || tabIndex >= _acikTablar.length) return;

    setState(() {
      final kapatilanMenuIndex = _acikTablar[tabIndex].menuIndex;
      _acikTablar.removeAt(tabIndex);
      if (kapatilanMenuIndex == 10) {
        _aktifAlisDuzenlemeRef = null;
      } else if (kapatilanMenuIndex == 11) {
        _aktifSatisDuzenlemeRef = null;
      }

      if (_acikTablar.isEmpty) {
        _aktifTabIndex = -1;
        _selectedIndex = 0; // Ana sayfaya dön
      } else if (tabIndex <= _aktifTabIndex) {
        // Aktif tab veya önceki bir tab kapatıldı
        _aktifTabIndex = (_aktifTabIndex - 1).clamp(0, _acikTablar.length - 1);
        _selectedIndex = _acikTablar[_aktifTabIndex].menuIndex;
      }
    });
  }

  /// Tab seçildiğinde çağrılır
  void _onTabSecildi(int tabIndex) {
    if (tabIndex < 0 || tabIndex >= _acikTablar.length) return;

    setState(() {
      _aktifTabIndex = tabIndex;
      _selectedIndex = _acikTablar[tabIndex].menuIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final isMobilePlatform =
              !kIsWeb && (Platform.isAndroid || Platform.isIOS);
          final isTablet =
              isMobilePlatform &&
              MediaQuery.sizeOf(context).shortestSide >= 600;
          final double bottomInset =
              isTablet ? MediaQuery.paddingOf(context).bottom : 0.0;

          Widget layout;

          // Wide desktop/web layout (mevcut yapı korunuyor)
          if (isWide && !isMobilePlatform) {
            final bool isSidebarExpanded = _isSidebarPinned || _isSidebarHovered;
            final sidebarWidth = isSidebarExpanded ? 248.0 : 56.0;

            final sidebar = MouseRegion(
              opaque: true,
              hitTestBehavior: HitTestBehavior.opaque,
              cursor: SystemMouseCursors.basic,
              onEnter: (_) {
                _hoverTimer?.cancel();
                if (!_isSidebarHovered && mounted) {
                  setState(() {
                    _isSidebarHovered = true;
                  });
                }
              },
              onExit: (_) {
                if (_isSidebarPinned) return;
                _hoverTimer?.cancel();
                _hoverTimer = Timer(const Duration(milliseconds: 300), () {
                  if (!mounted) return;
                  if (mounted) {
                    setState(() {
                      _isSidebarHovered = false;
                    });
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: sidebarWidth,
                child: YanMenu(
                  isExpanded: isSidebarExpanded,
                  selectedIndex: _selectedIndex == TabAciciScope.cariKartiIndex
                      ? 9
                      : _selectedIndex,
                  onToggle: () {
                    if (!mounted) return;
                    setState(() {
                      _isSidebarPinned = !_isSidebarPinned;
                      if (!_isSidebarPinned) {
                        _isSidebarHovered = true;
                      }
                      _hoverTimer?.cancel();
                    });
                  },
                  onItemSelected: _onMenuItemSelected,
                  onCompanySwitched: () {
                    if (!mounted) return;
                    setState(() {
                      _currentCompany = OturumServisi().aktifSirket!;
                      _selectedIndex = 0;
                      _refreshKey++;
                      // Şirket değiştiğinde tüm tabları kapat
                      _acikTablar.clear();
                      _aktifTabIndex = -1;
                      _aktifAlisDuzenlemeRef = null;
                      _aktifSatisDuzenlemeRef = null;
                    });
                  },
                  currentUser: widget.currentUser,
                  currentCompany: _currentCompany,
                ),
              ),
            );

            final content = Expanded(
              child: Column(
                children: [
                  UstBar(
                    title: _titleForIndex(),
                    onMenuPressed: () {
                      // Geniş ekranda menü tuşu sidebar'ı etkilemez.
                    },
                  ),
                  TabYonetici(
                    acikTablar: _acikTablar,
                    aktifTabIndex: _aktifTabIndex,
                    onTabSecildi: _onTabSecildi,
                    onTabKapatildi: _onTabKapatildi,
                    onTumunuKapat: () {
                      setState(() {
                        _acikTablar.clear();
                        _aktifTabIndex = -1;
                        _selectedIndex = 0;
                        _aktifAlisDuzenlemeRef = null;
                        _aktifSatisDuzenlemeRef = null;
                      });
                    },
                    refreshKey: _refreshKey,
                  ),
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      padding: _acikTablar.isNotEmpty && _aktifTabIndex >= 0
                          ? const EdgeInsets.fromLTRB(16, 12, 16, 16)
                          : const EdgeInsets.all(16),
                      child: _buildContent(),
                    ),
                  ),
                ],
              ),
            );

            layout = Row(children: <Widget>[sidebar, content]);
          } else if (isTablet) {
            // Tablet: Mobil (kart) görünümü + hamburger menü (soldan kaymadan).
            final rawDrawerWidth = constraints.maxWidth * 0.55;
            final sidebarWidth = rawDrawerWidth.clamp(260.0, 360.0).toDouble();

            layout = Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      UstBar(
                        title: _titleForIndex(),
                        forceShowMenuButton: true,
                        onMenuPressed: () {
                          if (!mounted) return;
                          setState(() {
                            _isSidebarExpanded = !_isSidebarExpanded;
                          });
                        },
                      ),
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            16 + bottomInset,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: KeyedSubtree(
                              key: ValueKey<int>(_selectedIndex),
                              child: _pageForIndex(_selectedIndex),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isSidebarExpanded)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        if (!mounted) return;
                        setState(() {
                          _isSidebarExpanded = false;
                        });
                      },
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: sidebarWidth,
                  child: IgnorePointer(
                    ignoring: !_isSidebarExpanded,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      opacity: _isSidebarExpanded ? 1 : 0,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOut,
                        alignment: Alignment.topLeft,
                        scale: _isSidebarExpanded ? 1 : 0.98,
                        child: Material(
                          elevation: 18,
                          color: Colors.transparent,
                          child: Container(
                            color: const Color(0xFF2C3E50),
                            padding: EdgeInsets.only(bottom: bottomInset),
                            child: YanMenu(
                              isExpanded: true,
                              selectedIndex:
                                  _selectedIndex == TabAciciScope.cariKartiIndex
                                      ? 9
                                      : _selectedIndex,
                              onToggle: () {
                                if (!mounted) return;
                                setState(() {
                                  _isSidebarExpanded = false;
                                });
                              },
                              onItemSelected: (index) {
                                if (!mounted) return;
                                // Tablet: Mobil davranışı korunuyor, sadece soldan kayma yok.
                                if (index == _perakendeSatisIndex) {
                                  setState(() {
                                    _isSidebarExpanded = false;
                                  });
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const PerakendeSatisSayfasi(),
                                    ),
                                  );
                                  return;
                                }
                                setState(() {
                                  _selectedIndex = index;
                                  _isSidebarExpanded = false;
                                });
                              },
                              onCompanySwitched: () {
                                if (!mounted) return;
                                setState(() {
                                  _isSidebarExpanded = false;
                                  _currentCompany = OturumServisi().aktifSirket!;
                                  _selectedIndex = 0;
                                  _refreshKey++;
                                  // Şirket değiştiğinde tüm tabları kapat
                                  _acikTablar.clear();
                                  _aktifTabIndex = -1;
                                  _aktifAlisDuzenlemeRef = null;
                                  _aktifSatisDuzenlemeRef = null;
                                });
                              },
                              currentUser: widget.currentUser,
                              currentCompany: _currentCompany,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Dar ekran (mobil): Tab sistemi YOK, mevcut yapı korunuyor
            final rawDrawerWidth = constraints.maxWidth * 0.85;
            final sidebarWidth = rawDrawerWidth.clamp(220.0, 280.0).toDouble();

            layout = Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      UstBar(
                        title: _titleForIndex(),
                        onMenuPressed: () {
                          if (!mounted) return;
                          setState(() {
                            _isSidebarExpanded = !_isSidebarExpanded;
                          });
                        },
                      ),
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(16),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: KeyedSubtree(
                              key: ValueKey<int>(_selectedIndex),
                              child: _pageForIndex(_selectedIndex),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isSidebarExpanded)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        if (!mounted) return;
                        setState(() {
                          _isSidebarExpanded = false;
                        });
                      },
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  top: 0,
                  bottom: 0,
                  left: _isSidebarExpanded ? 0 : -sidebarWidth,
                  width: sidebarWidth,
                  child: YanMenu(
                    isExpanded: true,
                    selectedIndex:
                        _selectedIndex == TabAciciScope.cariKartiIndex
                            ? 9
                            : _selectedIndex,
                    onToggle: () {
                      if (!mounted) return;
                      setState(() {
                        _isSidebarExpanded = false;
                      });
                    },
                    onItemSelected: (index) {
                      if (!mounted) return;
                      // Mobilde perakende satış ayrı sayfada açılır
                      if (index == _perakendeSatisIndex) {
                        setState(() {
                          _isSidebarExpanded = false;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PerakendeSatisSayfasi(),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _selectedIndex = index;
                        _isSidebarExpanded = false;
                      });
                    },
                    currentUser: widget.currentUser,
                    currentCompany: _currentCompany,
                  ),
                ),
              ],
            );
          }

          final safeChild = isTablet
              ? MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: layout,
                )
              : layout;

          return SafeArea(
            bottom: !isTablet,
            child: safeChild,
          );
        },
      ),
    );
  }

  /// İçerik widget'ını oluşturur
  Widget _buildContent() {
    Widget content;

    /* 
    // Ayarlar sayfaları artık tab sistemi içinde
    if (_ayarlarIndexleri.contains(_selectedIndex)) {
      content = KeyedSubtree(
        key: ValueKey<String>('settings_${_selectedIndex}_$_refreshKey'),
        child: _pageForIndex(_selectedIndex),
      );
    }
    */
    // Tab içeriği
    if (_aktifTabIndex >= 0 && _aktifTabIndex < _acikTablar.length) {
      content = TabIcerik(
        acikTablar: _acikTablar,
        aktifTabIndex: _aktifTabIndex,
        refreshKey: _refreshKey,
      );
    }
    // Hiçbir tab açık değilse ana sayfa göster
    else {
      content = KeyedSubtree(
        key: ValueKey<String>('home_$_refreshKey'),
        child: _pageForIndex(0),
      );
    }

    // TabAciciScope ile sarmalayarak child'ların tab açmasını sağla
    return TabAciciScope(
      tabAc:
          ({
            required int menuIndex,
            CariHesapModel? initialCari,
            UrunModel? initialUrun,
            List<TransactionItem>? initialItems,
            String? initialCurrency,
            String? initialDescription,
            String? initialOrderRef,
            int? quoteRef,
            double? initialRate,
            String? initialSearchQuery,
            Map<String, dynamic>? duzenlenecekIslem,
          }) {
            _tabAcVeyaSec(
              menuIndex,
              initialCari: initialCari,
              initialUrun: initialUrun,
              initialItems: initialItems,
              initialCurrency: initialCurrency,
              initialDescription: initialDescription,
              initialOrderRef: initialOrderRef,
              quoteRef: quoteRef,
              initialRate: initialRate,
              initialSearchQuery: initialSearchQuery,
              duzenlenecekIslem: duzenlenecekIslem,
            );
          },
      child: content,
    );
  }

  String _titleForIndex() {
    // Ayarlar altındaki sayfalar için başlık "Ayarlar" olmalı
    if ((_selectedIndex >= 2 && _selectedIndex <= 5) ||
        _selectedIndex == 20 ||
        _selectedIndex == 50) {
      return tr('nav.settings');
    }

    // Ürünler / Depolar altındaki sayfalar için başlık "Ürünler / Depolar" olmalı
    if (_selectedIndex == 6 || _selectedIndex == 7 || _selectedIndex == 8) {
      return tr('nav.products_warehouses');
    }

    // Cari Hesaplar sayfası veya Cari Kartı için başlık
    if (_selectedIndex == 9 || _selectedIndex == TabAciciScope.cariKartiIndex) {
      return tr('nav.accounts');
    }

    // Ürün Kartı için başlık
    if (_selectedIndex == TabAciciScope.urunKartiIndex) {
      return tr('nav.products_warehouses');
    }

    // Alım Satım İşlemleri
    if (_selectedIndex == 10 ||
        _selectedIndex == 11 ||
        _selectedIndex == 12 ||
        _selectedIndex == 23) {
      return tr('nav.trading_operations');
    }

    // Siparişler / Teklifler
    if (_selectedIndex == 18 || _selectedIndex == 19) {
      return tr('nav.orders_quotes');
    }

    final item = MenuAyarlari.findByIndex(_selectedIndex);
    if (item != null) {
      return tr(item.labelKey);
    }
    return tr('nav.home');
  }

  Widget _pageForIndex(int index) {
    if (index == 22) {
      return const ModullerSayfasi();
    }
    if (index == 1) {
      return const KullaniciAyarlarSayfasi();
    }
    if (index == 2) {
      return const RollerVeIzinlerSayfasi();
    }
    if (index == 3) {
      return const SirketAyarlariSayfasi();
    }
    if (index == 4) {
      return const GenelAyarlarSayfasi();
    }
    if (index == 20) {
      return const AiAyarlariSayfasi();
    }
    if (index == 5) {
      return const DilAyarlariSayfasi();
    }
    if (index == 50) {
      return const VeritabaniYedekAyarlariSayfasi();
    }
    if (index == 6) {
      return const DepolarSayfasi();
    }
    if (index == 7) {
      return const UrunlerSayfasi();
    }
    if (index == 8) {
      return const UretimlerSayfasi();
    }
    if (index == 9) {
      return const CariHesaplarSayfasi();
    }
    if (index == 10) {
      final cari = _pendingInitialCari;
      final items = _pendingInitialItems;
      final currency = _pendingInitialCurrency;
      final desc = _pendingInitialDescription;
      final orderRef = _pendingInitialOrderRef;
      final rate = _pendingInitialRate;
      final editTx = _pendingDuzenlenecekIslem;

      _pendingInitialCari = null;
      _pendingInitialItems = null;
      _pendingInitialCurrency = null;
      _pendingInitialDescription = null;
      _pendingInitialOrderRef = null;
      _pendingInitialRate = null;
      _pendingDuzenlenecekIslem = null;

      return AlisYapSayfasi(
        initialCari: cari,
        initialItems: items,
        initialCurrency: currency,
        initialDescription: desc,
        initialOrderRef: orderRef,
        initialRate: rate,
        duzenlenecekIslem: editTx,
      );
    }
    if (index == 11) {
      final cari = _pendingInitialCari;
      final items = _pendingInitialItems;
      final currency = _pendingInitialCurrency;
      final desc = _pendingInitialDescription;
      final orderRef = _pendingInitialOrderRef;
      final quoteRef = _pendingQuoteRef;
      final rate = _pendingInitialRate;
      final editTx = _pendingDuzenlenecekIslem;

      _pendingInitialCari = null;
      _pendingInitialItems = null;
      _pendingInitialCurrency = null;
      _pendingInitialDescription = null;
      _pendingInitialOrderRef = null;
      _pendingQuoteRef = null;
      _pendingInitialRate = null;
      _pendingDuzenlenecekIslem = null;

      return SatisYapSayfasi(
        initialCari: cari,
        initialItems: items,
        initialCurrency: currency,
        initialDescription: desc,
        initialOrderRef: orderRef,
        quoteRef: quoteRef,
        initialRate: rate,
        duzenlenecekIslem: editTx,
      );
    }
    if (index == 23) {
      return const HizliSatisSayfasi();
    }
    if (index == 13) {
      final q = _pendingInitialSearchQuery;
      _pendingInitialSearchQuery = null;
      return KasalarSayfasi(initialSearchQuery: q);
    }
    if (index == 15) {
      final q = _pendingInitialSearchQuery;
      _pendingInitialSearchQuery = null;
      return BankalarSayfasi(initialSearchQuery: q);
    }
    if (index == 16) {
      final q = _pendingInitialSearchQuery;
      _pendingInitialSearchQuery = null;
      return KrediKartlariSayfasi(initialSearchQuery: q);
    }
    if (index == 14) {
      final q = _pendingInitialSearchQuery;
      _pendingInitialSearchQuery = null;
      return CeklerSayfasi(initialSearchQuery: q);
    }
    if (index == 17) {
      final q = _pendingInitialSearchQuery;
      _pendingInitialSearchQuery = null;
      return SenetlerSayfasi(initialSearchQuery: q);
    }
    if (index == 18) {
      return const SiparislerSayfasi(tur: 'Sipariş');
    }
    if (index == 19) {
      return const TekliflerSayfasi(tur: 'Teklif');
    }

    // Cari Kartı sayfası (Menüde yok ama tab veya mobile geçişte kullanılıyor)
    if (index == TabAciciScope.cariKartiIndex) {
      final cari = _pendingInitialCari;
      // _pendingInitialCari = null; // Tab sistemi için null yapmamalıyız çünkü sayfa tekrar oluşturulabilir
      if (cari != null) {
        return CariKartiSayfasi(cariHesap: cari);
      }
    }

    // Giderler sayfası
    if (index == 100) {
      return const GiderlerSayfasi();
    }

    // Yazdırma Ayarları sayfası
    if (index == 101) {
      return const YazdirmaAyarlariSayfasi();
    }

    // Placeholder pages for now
    return Center(
      child: Text(
        tr('page.placeholder').replaceAll('{title}', _titleForIndex()),
      ),
    );
  }
}
