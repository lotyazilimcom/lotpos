import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../servisler/ayarlar_veritabani_servisi.dart';
import '../../servisler/bankalar_veritabani_servisi.dart';
import '../../servisler/cekler_veritabani_servisi.dart';
import '../../servisler/kasalar_veritabani_servisi.dart';
import '../../servisler/kredi_kartlari_veritabani_servisi.dart';
import '../../servisler/urunler_veritabani_servisi.dart';
import '../../servisler/depolar_veritabani_servisi.dart';
import '../../servisler/uretimler_veritabani_servisi.dart';
import '../../servisler/cari_hesaplar_veritabani_servisi.dart';
import '../../servisler/giderler_veritabani_servisi.dart';
import '../../servisler/personel_islemleri_veritabani_servisi.dart';
import '../../servisler/siparisler_veritabani_servisi.dart';
import '../../servisler/teklifler_veritabani_servisi.dart';
import '../../yardimcilar/ceviri/ceviri_servisi.dart';
import '../ayarlar/sirketayarlari/modeller/sirket_ayarlari_model.dart';
import '../../main.dart';
import '../../servisler/oturum_servisi.dart';
import '../../servisler/senetler_veritabani_servisi.dart';
import '../../servisler/veritabani_aktarim_servisi.dart';
import '../../servisler/veritabani_yapilandirma.dart';
import '../../yardimcilar/mesaj_yardimcisi.dart';
import '../../bilesenler/veritabani_aktarim_secim_dialog.dart';
import '../mobil_kurulum/mobil_kurulum_sayfasi.dart';
import '../ayarlar/veritabaniyedekayarlari/veritabani_yedek_ayarlari_sayfasi.dart';

enum _YerelDbProbeSonucu { ok, databaseMissing, serverUnreachable, other }

class GirisSayfasi extends StatefulWidget {
  const GirisSayfasi({super.key});

  @override
  State<GirisSayfasi> createState() => _GirisSayfasiState();
}

class _GirisSayfasiState extends State<GirisSayfasi> {
  final _formKey = GlobalKey<FormState>();
  final _kullaniciAdiController = TextEditingController();
  final _sifreController = TextEditingController();

  bool _beniHatirla = false;
  bool _sifreGizli = true;
  bool _yukleniyor = false;
  bool _sirketSecimiAcik = false;

  List<SirketAyarlariModel> _sirketler = [];
  SirketAyarlariModel? _seciliSirket;
  bool _sirketlerYukleniyor = false;
  bool _dbAktarimKontrolEdildi = false;

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _isDesktopPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  String _warmupPrefsKey() {
    final cfg = VeritabaniYapilandirma();
    final mode = VeritabaniYapilandirma.connectionMode;
    // Host/port + DB adı ile bağlamı ayırt et (tek cihazda farklı DB'ler).
    return 'patisyo_warmup_done_${mode}_${cfg.host}_${cfg.port}_${OturumServisi().aktifVeritabaniAdi}';
  }

  Future<_YerelDbProbeSonucu> _yerelDbHazirMi(String dbName) async {
    final cfg = VeritabaniYapilandirma();
    Connection? conn;
    try {
      conn = await Connection.open(
        Endpoint(
          host: cfg.host,
          port: cfg.port,
          database: dbName.trim(),
          username: cfg.username,
          password: cfg.password,
        ),
        settings: ConnectionSettings(
          sslMode: cfg.sslMode,
          connectTimeout: const Duration(seconds: 2),
          onOpen: cfg.tuneConnection,
        ),
      );
      await conn.execute('SELECT 1');
      return _YerelDbProbeSonucu.ok;
    } on SocketException {
      return _YerelDbProbeSonucu.serverUnreachable;
    } on ServerException catch (e) {
      if (e.code == '3D000') return _YerelDbProbeSonucu.databaseMissing;
      return _YerelDbProbeSonucu.other;
    } catch (_) {
      return _YerelDbProbeSonucu.other;
    } finally {
      try {
        await conn?.close();
      } catch (_) {}
    }
  }

  String _yerelSirketVeritabaniAdi(SirketAyarlariModel sirket) {
    final kod = sirket.kod.trim();
    if (kod == 'patisyo2025') return 'patisyo2025';
    final safeCode = kod.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    return 'patisyo_$safeCode';
  }

  Future<bool> _mobilYerelSirketVeritabaniniDogrula() async {
    // Bu kontrol "terminal/uzak" senaryoları içindir:
    // - Mobil + Yerel Sunucu (ana bilgisayar)
    // - Masaüstü + Uzak DB host (sunucuya bağlanan terminal)
    final mode = VeritabaniYapilandirma.connectionMode;
    if (mode != 'local' && mode != 'hybrid') return true;

    final cfg = VeritabaniYapilandirma();
    final host = cfg.host.trim().toLowerCase();
    final isLocalHost =
        host == '127.0.0.1' || host == 'localhost' || host == '::1';
    if (isLocalHost) return true;

    final sirket = _seciliSirket;
    if (sirket == null) return false;

    final dbName = _yerelSirketVeritabaniAdi(sirket);
    final probe = await _yerelDbHazirMi(dbName);

    if (probe == _YerelDbProbeSonucu.ok) return true;

    if (probe == _YerelDbProbeSonucu.serverUnreachable) {
      if (mounted) {
        MesajYardimcisi.hataGoster(
          context,
          tr('setup.local.server_not_found_open_app'),
        );
      }
      return false;
    }

    if (probe == _YerelDbProbeSonucu.databaseMissing) {
      // Seçili şirket DB'si yoksa, geçerli ilk şirketi otomatik seçmeye çalış.
      final List<SirketAyarlariModel> candidates = [
        ..._sirketler.where((s) => s.kod.trim() == 'patisyo2025'),
        ..._sirketler.where((s) => s.kod.trim() != 'patisyo2025'),
      ];

      for (final cand in candidates) {
        if (cand.kod.trim() == sirket.kod.trim()) continue;
        final candDb = _yerelSirketVeritabaniAdi(cand);
        final candProbe = await _yerelDbHazirMi(candDb);
        if (candProbe == _YerelDbProbeSonucu.ok) {
          if (mounted) {
            setState(() => _seciliSirket = cand);
          }
          OturumServisi().aktifSirket = cand;
          return true;
        }
        if (candProbe == _YerelDbProbeSonucu.serverUnreachable) {
          if (mounted) {
            MesajYardimcisi.hataGoster(
              context,
              tr('setup.local.server_not_found_open_app'),
            );
          }
          return false;
        }
      }

      if (mounted) {
        MesajYardimcisi.hataGoster(
          context,
          tr('setup.local.company_database_missing'),
        );
      }
      return false;
    }

    if (mounted) {
      MesajYardimcisi.hataGoster(context, tr('common.unknown_error'));
    }
    return false;
  }

  Future<void> _servisleriIsit({bool background = false}) async {
    Future<void> step(Future<void> Function() fn) async {
      try {
        await fn();
      } catch (e) {
        debugPrint('Servis ısıtma hatası: $e');
      } finally {
        if (background) {
          // UI'ı bloklamamak için kısa yield
          await Future<void>.delayed(const Duration(milliseconds: 8));
        }
      }
    }

    // Depolar, shipments/warehouse_stocks gibi ortak tabloları kurduğu için öne al.
    await step(() => DepolarVeritabaniServisi().baslat());
    await step(() => UrunlerVeritabaniServisi().baslat());
    await step(() => UretimlerVeritabaniServisi().baslat());

    await step(() => KasalarVeritabaniServisi().baslat());
    await step(() => BankalarVeritabaniServisi().baslat());
    await step(() => KrediKartlariVeritabaniServisi().baslat());
    await step(() => CeklerVeritabaniServisi().baslat());
    await step(() => SenetlerVeritabaniServisi().baslat());

    await step(() => CariHesaplarVeritabaniServisi().baslat());
    await step(() => GiderlerVeritabaniServisi().baslat());
    await step(() => PersonelIslemleriVeritabaniServisi().baslat());
    await step(() => SiparislerVeritabaniServisi().baslat());
    await step(() => TekliflerVeritabaniServisi().baslat());
  }

  Future<void> _veritabaniSeciminiAc() async {
    if (_yukleniyor) return;

    setState(() => _yukleniyor = true);
    try {
      // Mevcut bağlantıları kapat (yeni seçime temiz başlasın)
      await AyarlarVeritabaniServisi().baglantiyiKapat();
      await DepolarVeritabaniServisi().baglantiyiKapat();
      await UrunlerVeritabaniServisi().baglantiyiKapat();
      await UretimlerVeritabaniServisi().baglantiyiKapat();
      await CariHesaplarVeritabaniServisi().baglantiyiKapat();
      await GiderlerVeritabaniServisi().baglantiyiKapat();
      await PersonelIslemleriVeritabaniServisi().baglantiyiKapat();
      await SiparislerVeritabaniServisi().baglantiyiKapat();
      await TekliflerVeritabaniServisi().baglantiyiKapat();
      await KasalarVeritabaniServisi().baglantiyiKapat();
      await BankalarVeritabaniServisi().baglantiyiKapat();
      await KrediKartlariVeritabaniServisi().baglantiyiKapat();
      await CeklerVeritabaniServisi().baglantiyiKapat();
      await SenetlerVeritabaniServisi().baglantiyiKapat();
    } catch (e) {
      debugPrint('Veritabanı seçimine geçiş uyarısı: $e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MobilKurulumSayfasi()),
    );
  }

  Future<void> _masaustuVeritabaniSeciminiAc() async {
    if (_yukleniyor) return;
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const VeritabaniYedekAyarlariSayfasi(standalone: true),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _kayitliBilgileriYukle();
    _varsayilanSirketiYukle();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_bekleyenVeritabaniAktariminiKontrolEt());
    });
  }

  @override
  void dispose() {
    _kullaniciAdiController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  Future<void> _kayitliBilgileriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _beniHatirla = prefs.getBool('beni_hatirla') ?? false;
      if (_beniHatirla) {
        _kullaniciAdiController.text = prefs.getString('kullanici_adi') ?? '';
        _sifreController.text = prefs.getString('sifre') ?? '';
      }
    });
  }

  Future<void> _varsayilanSirketiYukle() async {
    setState(() => _sirketlerYukleniyor = true);
    try {
      final sirketler = await AyarlarVeritabaniServisi().sirketleriGetir(
        sayfa: 1,
        sayfaBasinaKayit: 100,
      );

      if (mounted) {
        setState(() {
          _sirketler = sirketler;
          if (sirketler.isNotEmpty) {
            // Varsayılan şirketi bul, yoksa ilkini seç
            try {
              _seciliSirket = sirketler.firstWhere((s) => s.varsayilanMi);
            } catch (_) {
              _seciliSirket = sirketler.first;
            }
          } else if (VeritabaniYapilandirma.connectionMode == 'cloud' ||
              VeritabaniYapilandirma.connectionMode ==
                  VeritabaniYapilandirma.cloudPendingMode) {
            // Cloud modda şirket bulunamazsa otomatik ata
            _seciliSirket = _bulutVarsayilanSirket();
          }
          _sirketlerYukleniyor = false;
        });
      }
    } catch (e) {
      debugPrint('Şirketler yüklenirken hata: $e');
      if (mounted) {
        setState(() {
          _sirketlerYukleniyor = false;
          // Cloud modda hata olursa bile varsayılan şirketle devam et
          if ((VeritabaniYapilandirma.connectionMode == 'cloud' ||
                  VeritabaniYapilandirma.connectionMode ==
                      VeritabaniYapilandirma.cloudPendingMode) &&
              _seciliSirket == null) {
            _seciliSirket = _bulutVarsayilanSirket();
          }
        });
      }
    }
  }

  String _aktarimTabloEtiketi(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    final base = trimmed.contains('.') ? trimmed.split('.').last : trimmed;
    final key = 'dbsync.table.$base';
    final translated = tr(key);
    if (translated != key) return translated;

    return _snakeToTitleCase(base);
  }

  String _snakeToTitleCase(String value) {
    final parts = value.split('_').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return value;
    return parts
        .map(
          (p) => p.length <= 1
              ? p.toUpperCase()
              : '${p[0].toUpperCase()}${p.substring(1)}',
        )
        .join(' ');
  }

  Future<void> _bekleyenVeritabaniAktariminiKontrolEt() async {
    if (_dbAktarimKontrolEdildi) return;
    _dbAktarimKontrolEdildi = true;

    if (!_isMobilePlatform && !_isDesktopPlatform) return;

    final aktarim = VeritabaniAktarimServisi();
    final niyet = await aktarim.niyetOku();
    if (niyet == null) return;

    // Cloud tarafını içeren aktarım niyeti varsa ama cloud kimlikler hazır değilse,
    // bağlantı denemek yerine erken çık. Kullanıcıya gereksiz hata snackbar'ı gösterme.
    final fromMode = niyet.fromMode.trim();
    final toMode = niyet.toMode.trim();

    // Karma (Yerel+Bulut) modda: Local->Cloud seed/backup işlemi login akışını
    // kesinlikle bloklamamalı. Bu senaryoda aktarımı arka plan servisine bırak.
    if (VeritabaniYapilandirma.connectionMode == 'hybrid' &&
        fromMode == 'local' &&
        toMode == 'cloud') {
      debugPrint(
        'DB aktarım kontrolü: Karma mod (local->cloud) arka planda çalışacak, login bloklanmadı.',
      );
      return;
    }

    if ((fromMode == 'cloud' || toMode == 'cloud') &&
        !VeritabaniYapilandirma.cloudCredentialsReady) {
      debugPrint(
        'DB aktarım kontrolü: Cloud kimlikler hazır değil, atlanıyor.',
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedChoice = prefs.getString(
      VeritabaniYapilandirma.prefPendingTransferChoiceKey,
    );

    if (!mounted) return;
    final prepNavigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 450,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('dbsync.preparing.title'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('dbsync.preparing.message'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF606368),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    VeritabaniAktarimHazirlik? hazirlik;
    try {
      hazirlik = await aktarim.hazirlikYap(niyet: niyet);
    } catch (e) {
      try {
        if (prepNavigator.canPop()) prepNavigator.pop();
      } catch (_) {}
      debugPrint('DB aktarım hazırlık hatası: $e');
      // Bağlantı hatası olabilir — kullanıcıyı rahatsız etme, sessizce çık.
      return;
    }

    try {
      if (prepNavigator.canPop()) prepNavigator.pop();
    } catch (_) {}

    if (hazirlik == null) {
      // Desktop'ta kullanıcı daha önce seçim yaptıysa (full/merge) ve hedef bulut ise,
      // önce bulut tarafındaki şemayı/tabloları bootstrap edip tekrar dene.
      final bool shouldBootstrapCloudTarget =
          (niyet.toMode.trim() == 'cloud' &&
          VeritabaniYapilandirma.connectionMode == 'cloud' &&
          VeritabaniYapilandirma.cloudCredentialsReady);

      if (shouldBootstrapCloudTarget) {
        if (!mounted) return;
        final navigator = Navigator.of(context, rootNavigator: true);
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Container(
              width: 450,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('setup.cloud.preparing_title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr('setup.cloud.preparing_message'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF606368),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        try {
          await _servisleriIsit(background: false);
        } finally {
          try {
            if (navigator.canPop()) navigator.pop();
          } catch (_) {}
        }

        try {
          hazirlik = await aktarim.hazirlikYap(niyet: niyet);
        } catch (e) {
          debugPrint('DB aktarım ikinci hazırlık hatası: $e');
        }
      }

      // Hazır değilse kullanıcıyı bloklama; niyeti sakla, uygun zamanda tekrar denesin.
      // Ancak kullanıcı masaüstünde daha önce bir seçim yaptıysa (full/merge),
      // sessizce geçmek "çalışmadı" gibi görünür. Bu durumda bilgilendir —
      // AMA cloud bağlantı sorunu varsa snackbar gösterme (zaten bootstrap sayfasında
      // gösterildi veya kullanıcı bilerek yerele geçti).
      if (hazirlik == null && _isDesktopPlatform) {
        if (savedChoice != null) {
          // Cloud tarafı sorunluysa sessiz kal, kullanıcı zaten bilgilendirildi
          final cloudInvolved = fromMode == 'cloud' || toMode == 'cloud';
          if (!cloudInvolved) {
            if (!mounted) return;
            MesajYardimcisi.hataGoster(context, tr('dbsync.prepare_failed'));
          }
        }
      }
      return;
    }

    if (!mounted) return;

    final bool localToCloud =
        hazirlik.fromMode == 'local' && hazirlik.toMode == 'cloud';

    if (!mounted) return;

    VeritabaniAktarimTipi? secim;
    if (savedChoice != null) {
      if (savedChoice == 'merge') {
        secim = VeritabaniAktarimTipi.birlestir;
      } else if (savedChoice == 'full') {
        secim = VeritabaniAktarimTipi.tamAktar;
      }
    }

    if (secim == null && _isDesktopPlatform) {
      final desktopSecim = await veritabaniAktarimSecimDialogGoster(
        context: context,
        localToCloud: localToCloud,
        barrierDismissible: false,
      );
      if (desktopSecim == null ||
          desktopSecim == DesktopVeritabaniAktarimSecimi.hicbirSeyYapma) {
        await prefs.remove(VeritabaniYapilandirma.prefPendingTransferChoiceKey);
        await aktarim.niyetTemizle();
        return;
      }

      secim = desktopSecim == DesktopVeritabaniAktarimSecimi.birlestir
          ? VeritabaniAktarimTipi.birlestir
          : VeritabaniAktarimTipi.tamAktar;

      final stored = secim == VeritabaniAktarimTipi.birlestir
          ? 'merge'
          : 'full';
      await prefs.setString(
        VeritabaniYapilandirma.prefPendingTransferChoiceKey,
        stored,
      );
    } else if (secim == null && !_isDesktopPlatform) {
      final mobileSecim = await veritabaniAktarimSecimDialogGoster(
        context: context,
        localToCloud: localToCloud,
        barrierDismissible: false,
      );

      if (mobileSecim == null ||
          mobileSecim == DesktopVeritabaniAktarimSecimi.hicbirSeyYapma) {
        await prefs.remove(VeritabaniYapilandirma.prefPendingTransferChoiceKey);
        await aktarim.niyetTemizle();
        return;
      }

      secim = mobileSecim == DesktopVeritabaniAktarimSecimi.birlestir
          ? VeritabaniAktarimTipi.birlestir
          : VeritabaniAktarimTipi.tamAktar;
    }

    if (secim == null) {
      await prefs.remove(VeritabaniYapilandirma.prefPendingTransferChoiceKey);
      await aktarim.niyetTemizle();
      return;
    }

    if (!mounted) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    final progress = ValueNotifier<VeritabaniAktarimIlerleme?>(null);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<VeritabaniAktarimIlerleme?>(
        valueListenable: progress,
        builder: (context, value, _) {
          final ratio = value?.oran;
          final pct = value?.yuzde;
          final currentRaw = (value?.mevcut ?? '').trim();
          final hideCurrent =
              currentRaw == 'truncate' ||
              currentRaw == 'sequences' ||
              currentRaw.endsWith('.truncate') ||
              currentRaw.endsWith('.sequences');
          final current = hideCurrent ? '' : _aktarimTabloEtiketi(currentRaw);
          final detail = (pct != null && value!.toplamAdim > 0)
              ? '$pct% (${value.tamamlananAdim}/${value.toplamAdim})'
              : '';

          final infoText = <String>[
            if (detail.isNotEmpty) detail,
            if (current.isNotEmpty) current,
          ].join(' • ');

          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Container(
              width: 450,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('dbsync.progress.title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr('dbsync.progress.message'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF606368),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: const Color(0xFFE0E0E0),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF2C3E50),
                      ),
                      minHeight: 6,
                    ),
                  ),
                  if (infoText.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      infoText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF606368),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );

    try {
      await aktarim.aktarimYap(
        hazirlik: hazirlik,
        tip: secim,
        onIlerleme: (p) => progress.value = p,
      );
      await aktarim.niyetTemizle();
      await prefs.remove(VeritabaniYapilandirma.prefPendingTransferChoiceKey);
      if (!mounted) return;
      MesajYardimcisi.basariGoster(context, tr('dbsync.success'));
    } catch (e) {
      if (mounted) {
        MesajYardimcisi.hataGoster(
          context,
          tr('dbsync.error', args: {'error': e.toString()}),
        );
      }
    } finally {
      try {
        if (navigator.canPop()) navigator.pop();
      } catch (_) {}
      progress.dispose();
    }
  }

  /// Cloud modda kullanılacak varsayılan şirket modeli
  SirketAyarlariModel _bulutVarsayilanSirket() {
    final dbName = VeritabaniYapilandirma().database;
    return SirketAyarlariModel(
      kod: dbName,
      ad: dbName,
      basliklar: [],
      logolar: [],
      aktifMi: true,
      varsayilanMi: true,
      duzenlenebilirMi: false,
    );
  }

  Future<void> _girisYap() async {
    if (!_formKey.currentState!.validate()) return;

    if (_seciliSirket == null && _sirketler.isNotEmpty) {
      try {
        _seciliSirket = _sirketler.firstWhere((s) => s.varsayilanMi);
      } catch (_) {
        _seciliSirket = _sirketler.first;
      }
    }

    if (_seciliSirket == null) {
      final mode = VeritabaniYapilandirma.connectionMode;
      final isCloudLike =
          mode == 'cloud' || mode == VeritabaniYapilandirma.cloudPendingMode;

      if (isCloudLike) {
        _seciliSirket = _bulutVarsayilanSirket();
      }
    }

    if (_seciliSirket == null) {
      MesajYardimcisi.hataGoster(context, tr('login.company.required'));
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      final kullanici = await AyarlarVeritabaniServisi().girisYap(
        _kullaniciAdiController.text,
        _sifreController.text,
      );

      if (mounted) {
        if (kullanici != null) {
          if (!kullanici.aktifMi) {
            setState(() => _yukleniyor = false);
            MesajYardimcisi.hataGoster(context, tr('login.error.userInactive'));
            return;
          }

          // Beni hatırla işlemleri
          final prefs = await SharedPreferences.getInstance();

          // Save current_username for session usage (Required for transaction logging)
          await prefs.setString('current_username', kullanici.kullaniciAdi);

          if (_beniHatirla) {
            await prefs.setBool('beni_hatirla', true);
            await prefs.setString(
              'kullanici_adi',
              _kullaniciAdiController.text,
            );
            await prefs.setString('sifre', _sifreController.text);
          } else {
            await prefs.remove('beni_hatirla');
            await prefs.remove('kullanici_adi');
            await prefs.remove('sifre');
          }

          // Oturum Servisine Aktif Şirketi Bildir
          OturumServisi().aktifSirket = _seciliSirket;

          // Mobil/Tablet + Yerel: Seçili şirket DB yoksa (3D000) modüllerde her sayfada hata basmasın.
          // Bu kontrol login sırasında yapılıp uygun şirkete otomatik düşer veya kullanıcıyı uyarır.
          final yerelOk = await _mobilYerelSirketVeritabaniniDogrula();
          if (!yerelOk) {
            if (mounted) setState(() => _yukleniyor = false);
            return;
          }

          final bool isCloud = VeritabaniYapilandirma.connectionMode == 'cloud';

          // Mobil/Tablet + Bulut: ilk kurulumda beklet, sonraki açılışlarda giriş "ışık hızı" olsun.
          if (_isMobilePlatform && isCloud) {
            final warmKey = _warmupPrefsKey();
            final warmedUp = prefs.getBool(warmKey) ?? false;

            if (warmedUp) {
              if (!mounted) return;

              // Önce kullanıcıyı içeri al, servisleri arka planda ısıt.
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => HomePage(
                    currentUser: kullanici,
                    currentCompany: _seciliSirket!,
                  ),
                ),
              );

              unawaited(_servisleriIsit(background: true));
              return;
            }

            // İlk kez: şema kurulumu / servis init tamamlanana kadar bekle.
            await _servisleriIsit(background: false);
            await prefs.setBool(warmKey, true);
          } else {
            // Desktop ve/veya local: mevcut stabil davranış (bekleyerek init)
            await _servisleriIsit(background: false);
          }

          if (!mounted) return;

          // Ana sayfaya yönlendir
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => HomePage(
                  currentUser: kullanici,
                  currentCompany: _seciliSirket!,
                ),
              ),
            );
          }
        } else {
          setState(() => _yukleniyor = false);
          MesajYardimcisi.hataGoster(
            context,
            tr('login.error.invalidCredentials'),
          );
        }
      }
    } catch (e) {
      debugPrint('Giriş hatası: $e');
      if (mounted) {
        setState(() => _yukleniyor = false);
        MesajYardimcisi.hataGoster(context, '${tr('common.error.generic')} $e');
      }
    }
  }

  void _sirketSeciminiAc() {
    setState(() {
      _sirketSecimiAcik = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final mode = VeritabaniYapilandirma.connectionMode;
    final dbModeLabel =
        (mode == 'cloud' || mode == VeritabaniYapilandirma.cloudPendingMode)
        ? 'Bulut'
        : 'Yerel';

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
          shift: true,
        ): _sirketSeciminiAc,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true):
            _sirketSeciminiAc,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: [
              // Arkaplan
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF95A5A6), // Ana arka plan tonu
                      Color(0xFF7F8C8D), // Daha koyu derinlik
                    ],
                  ),
                ),
              ),

              // Dekoratif Daireler
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF95A5A6).withValues(alpha: 0.16),
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -50,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2C3E50).withValues(alpha: 0.12),
                  ),
                ),
              ),

              Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: 850,
                    maxHeight: isDesktop
                        ? 500
                        : MediaQuery.of(context).size.height - 40,
                  ),
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Sol Taraf - Marka Alanı (Sadece Desktop)
                      if (isDesktop)
                        Expanded(
                          flex: 5,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF2C3E50),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(24),
                                bottomLeft: Radius.circular(24),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(
                                32.0,
                              ), // Reduced from 48
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(
                                      12,
                                    ), // Reduced from 16
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF2C3E50,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 40, // Reduced from 48
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 24), // Reduced from 32
                                  Text(
                                    tr('login.brand.title'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26, // Reduced from 32
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12), // Reduced from 16
                                  Text(
                                    tr('login.brand.description'),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 14, // Reduced from 16
                                      height: 1.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12, // Reduced from 16
                                      vertical: 6, // Reduced from 8
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF2C3E50,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF2C3E50,
                                        ).withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            tr('login.brand.optimized'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Sağ Taraf - Giriş Formu
                      Expanded(
                        flex: 6,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(32.0),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: isDesktop
                                      ? constraints.maxHeight - 64
                                      : 0, // Mobile'da zorunlu yükseklik yok
                                ),
                                child: IntrinsicHeight(
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tr('login.welcome'),
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          tr('login.subtitle'),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // Şirket Seçimi (Gizli/Açık)
                                        if (_sirketSecimiAcik) ...[
                                          Text(
                                            tr('login.company.label'),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF2C3E50),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          DropdownButtonFormField<
                                            SirketAyarlariModel
                                          >(
                                            mouseCursor: WidgetStateMouseCursor.clickable,
                                            dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
                                            // ignore: deprecated_member_use
                                            value: _seciliSirket,
                                            decoration: InputDecoration(
                                              hintText: _sirketlerYukleniyor
                                                  ? tr('login.company.loading')
                                                  : tr(
                                                      'login.company.placeholder',
                                                    ),
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 0,
                                                    vertical: 12,
                                                  ),
                                            ),
                                            items: _sirketler.map((sirket) {
                                              return DropdownMenuItem(
                                                value: sirket,
                                                child: Text(sirket.ad),
                                              );
                                            }).toList(),
                                            onChanged: _sirketlerYukleniyor
                                                ? null
                                                : (val) {
                                                    setState(
                                                      () => _seciliSirket = val,
                                                    );
                                                  },
                                            validator: (val) => val == null
                                                ? tr('login.company.required')
                                                : null,
                                          ),
                                          const SizedBox(height: 16),
                                        ],

                                        // Kullanıcı Adı
                                        Text(
                                          tr('login.username.label'),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          controller: _kullaniciAdiController,
                                          decoration: InputDecoration(
                                            hintText: tr(
                                              'login.username.label',
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.person_outline,
                                              size: 20,
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 0,
                                                  vertical: 12,
                                                ),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return tr(
                                                'login.username.required',
                                              );
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),

                                        // Şifre
                                        Text(
                                          tr('login.password.label'),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          controller: _sifreController,
                                          obscureText: _sifreGizli,
                                          decoration: InputDecoration(
                                            hintText: '******',
                                            prefixIcon: const Icon(
                                              Icons.lock_outline,
                                              size: 20,
                                            ),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _sifreGizli
                                                    ? Icons.visibility_outlined
                                                    : Icons
                                                          .visibility_off_outlined,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _sifreGizli = !_sifreGizli;
                                                });
                                              },
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 0,
                                                  vertical: 12,
                                                ),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return tr(
                                                'login.password.required',
                                              );
                                            }
                                            if (value.length < 4) {
                                              return tr(
                                                'login.password.tooShort',
                                              );
                                            }
                                            return null;
                                          },
                                          onFieldSubmitted: (_) => _girisYap(),
                                        ),
                                        const SizedBox(height: 12),

                                        // Beni Hatırla & Şifremi Unuttum
                                        // Beni Hatırla & Şifremi Unuttum
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: Checkbox(
                                                      value: _beniHatirla,
                                                      activeColor: const Color(
                                                        0xFF2C3E50,
                                                      ),
                                                      onChanged: (val) {
                                                        setState(
                                                          () => _beniHatirla =
                                                              val ?? false,
                                                        );
                                                      },
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      tr('login.remember'),
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),

                                        // Giriş Butonu
                                        SizedBox(
                                          width: double.infinity,
                                          height: 48,
                                          child: FilledButton(
                                            onPressed: _yukleniyor
                                                ? null
                                                : _girisYap,
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFEA4335,
                                              ),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: _yukleniyor
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: Color(
                                                            0xFF2C3E50,
                                                          ),
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : Text(
                                                    tr('login.submit'),
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        if (_isMobilePlatform ||
                                            _isDesktopPlatform) ...[
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 44,
                                            child: OutlinedButton(
                                              onPressed: _yukleniyor
                                                  ? null
                                                  : (_isMobilePlatform
                                                        ? _veritabaniSeciminiAc
                                                        : _masaustuVeritabaniSeciminiAc),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(
                                                  0xFF2C3E50,
                                                ),
                                                side: BorderSide(
                                                  color: const Color(
                                                    0xFF2C3E50,
                                                  ).withValues(alpha: 0.22),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.storage_rounded,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    "Veritabanı: $dbModeLabel • Değiştir",
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        const SizedBox(height: 16),

                                        // Güvenlik Bilgisi
                                        Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.lock_outline,
                                                size: 14,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                tr('login.connection.secure'),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
