import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lisans_kasasi.dart';
import 'lite_ayarlar_servisi.dart';
import 'online_veritabani_servisi.dart';

/// Patisyo Lisans Servisi (CIA Level Security & Supabase SDK Implementation)
///
/// Bu servis, uygulamanın lisans durumunu yönetir, donanım kimliği üretir
/// ve Supabase üzerinden lisans (PRO) / kısıtlı (LITE) durumunu senkronize eder.
class LisansServisi extends ChangeNotifier {
  static final LisansServisi _instance = LisansServisi._internal();
  factory LisansServisi() => _instance;
  LisansServisi._internal();

  // CIA Level Obfuscation - XOR Encryption with a static key
  static const String _secKey = 'PATISYO-CIA-2025-SECURITY-KEY-!@#';

  // "https://nnistfbawmeyojpcdyho.supabase.co" XOR encoded then Base64
  static final String _uEnc =
      'ODUgOSBjYAItJyheRlZQVFo+IDo6ODk3PVQjKndeVDBCMiAnLH06IA==';

  // Supabase Anon Key XOR encoded then Base64
  static final String _kEnc =
      'NTgeITEeLEQMIAtkZ0p7BGM6DDAcPBthOm4CcxBGURh1EwttZzYgBV0gegxEfVl4T0kLBysMPw8uA34CNhBDayx5OQhiAD5sOkwbB3F3X3paUR9iKSYCazg3HmMgIA5FVwlKJyg3JGoqFX4KfwhAdEVQBxk6CQAfIhAMCEQELxwebzpiKQwuACoUC3QwACx7BlNxfBseLwJhHB0zLmIPDC5jT3ANNQQhCgAwHEIXIjleVUp9T2QpPQYhZ3psKU4PKQl6VTVCDxUgMBIwInwsIg==';

  // License Token Secret (Used by Admin Panel) XOR encoded then Base64
  static final String _lsEnc = 'HA4AZAAcDHgRDGx+ZnFmfGIdaHFlYH95EmgS';

  // CIA-level Offline Vault (AES-256-GCM + HMAC signature) + clock tamper defense
  final LisansKasasi _kasasi = LisansKasasi();
  Timer? _kasasiDokunmaTimer;
  Timer? _heartbeatTimer;
  Future<void> _kasasiYazmaZinciri = Future<void>.value();
  DateTime? _kasasiMaxSeenUtc;

  static const Duration _clockRollbackTolerance = Duration(minutes: 10);
  static const Duration _kasasiTouchInterval = Duration(minutes: 15);
  static const Duration _licenseIdSyncInterval = Duration(minutes: 10);
  static const Duration _losPaySyncInterval = Duration(minutes: 10);
  static const Duration _periodicLicenseValidationTimeout = Duration(
    seconds: 3,
  );
  static const String _manualCodePrefix = 'ALI';
  static const int _manualCodeVersion = 2;
  static const int _manualCodeDayBits = 11;
  static const int _manualCodeVersionBits = 2;
  static const int _manualCodePackageBits = 2;
  static const int _manualCodeMacBits = 24;
  static const int _legacyManualCodeVersion = 1;
  static const int _legacyManualCodeDayBits = 13;
  static const int _legacyManualCodeMacBits = 22;
  static const int _manualPackageLite = 0;
  static const int _manualPackageMonthly = 1;
  static const int _manualPackageSemiannual = 2;
  static const int _manualPackageYearly = 3;

  String get _vaultSecret => '$_licenseSecret|$_secKey|LOT-LICENSE-VAULT-V1';

  String? _hardwareId;
  String? _licenseId;
  bool _isLicensed = false;
  DateTime? _licenseEndDate;
  double _losPayBalance = 0;
  bool _isInitialized = false;
  bool? _lastOnlineStatus; // Durum önbelleği (Caching)
  bool? _serverReachable;
  bool _inheritedPro = false; // Sunucudan devralınan lisans durumu
  bool _noOnlineLicenseLogged = false;
  DateTime? _licenseIdLastSyncUtc;
  DateTime? _losPayLastSyncUtc;
  bool _periodicLicenseValidationRunning = false;

  String? get hardwareId => _hardwareId;
  String? get licenseId => _licenseId;
  bool get isLicensed => _isLicensed || _inheritedPro;
  bool get isLiteMode => !isLicensed;
  bool get inheritedPro => _inheritedPro;
  bool get serverReachable => _serverReachable ?? false;
  bool get serverReachabilityKnown => _serverReachable != null;
  DateTime? get licenseEndDate => _licenseEndDate;
  double get losPayBalance => _losPayBalance;
  String? _licenseKey;
  String? get licenseKey => _licenseKey;

  static const String _prefsInheritedProKey = 'inherited_pro_status';
  static const String _prefsHardwareIdKey = 'patisyo_hardware_id_v1';

  /// Sunucudan devralınan lisans durumunu ayarlar
  Future<void> setInheritedPro(bool status) async {
    if (_inheritedPro == status) return;
    await _setInheritedProLocal(status);
    debugPrint('Lisans Servisi: Devralınan PRO durumu: $status');
  }

  static String get u => _ciaDecode(_uEnc, _secKey);
  static String get k => _ciaDecode(_kEnc, _secKey);
  static String get _licenseSecret => _ciaDecode(_lsEnc, _secKey);

  /// CIA Level Decoding (XOR + Base64)
  static String _ciaDecode(String enc, String key) {
    var bytes = base64.decode(enc);
    var keyBytes = utf8.encode(key);
    var result = List<int>.filled(bytes.length, 0);
    for (var i = 0; i < bytes.length; i++) {
      result[i] = bytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return utf8.decode(result);
  }

  String _requireHardwareId() {
    final id = _hardwareId;
    if (id == null || id.trim().isEmpty) {
      throw StateError('Hardware ID bulunamadı. Lisans servisi başlatılmamış.');
    }
    return id;
  }

  String get _prefsLicenseKeyKey => 'license_key_${_requireHardwareId()}';
  String get _prefsLicenseEndDateKey =>
      'license_end_date_${_requireHardwareId()}';
  String get _prefsLicenseIdKey => 'license_id_${_requireHardwareId()}';
  String get _prefsLosPayBalanceKey => 'lospay_balance_${_requireHardwareId()}';

  DateTime _nowUtc() => DateTime.now().toUtc();

  DateTime _secureNowUtc() {
    final now = _nowUtc();
    final maxSeen = _kasasiMaxSeenUtc;
    if (maxSeen == null) return now;

    if (now.isBefore(maxSeen.subtract(_clockRollbackTolerance))) {
      debugPrint(
        'Lisans Servisi: Sistem saati geri alınmış görünüyor. Offline süre takibi maxSeen üzerinden ilerleyecek.',
      );
      return maxSeen;
    }

    if (now.isAfter(maxSeen)) {
      _kasasiMaxSeenUtc = now;
      return now;
    }

    return maxSeen;
  }

  DateTime _secureTodayUtc() {
    final now = _secureNowUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  /// Servisi başlatır ve ilk kontrolü yapar
  Future<void> baslat() async {
    if (_isInitialized) return;

    try {
      _hardwareId = await _generateHardwareId();
      debugPrint('Lisans Servisi: Hardware ID: $_hardwareId');
      // Devralınan PRO durumunu (best-effort) yükle.
      // Not: Lisans kararı online-first yapılır; yerel lisans sadece online erişilemiyorsa devreye girer.
      final prefs = await SharedPreferences.getInstance();
      _inheritedPro = prefs.getBool(_prefsInheritedProKey) ?? false;
      final cachedLicenseId = prefs.getString(_prefsLicenseIdKey);
      if (cachedLicenseId != null) {
        final normalized = cachedLicenseId.trim().toUpperCase();
        _licenseId = normalized.isNotEmpty ? normalized : null;
      }
      _losPayBalance = prefs.getDouble(_prefsLosPayBalanceKey) ?? 0;

      // Önce cache'den yükle; canlı senkronu kritik yolu bloklamasın.
      await LiteAyarlarServisi().baslat();

      // Açılışta lisansı doğrula:
      // - Online erişilebiliyorsa: sadece online kayıt belirleyicidir (yerel lisansa bakılmaz).
      // - Online erişilemiyorsa: yerel lisans (vault/prefs) ile devam edilir.
      await dogrula(onlineTimeout: const Duration(milliseconds: 1200));

      _startKasasiDokunmaTimer();
      unawaited(_persistKasasiBestEffort());

      _isInitialized = true;

      // Non-blocking startup: Online senkronu ve durum güncelleme arka planda
      unawaited(_startupBackgroundSync());
    } catch (e) {
      debugPrint('Lisans Servisi Başlatma Hatası: $e');
    }
  }

  Future<void> _startupBackgroundSync() async {
    try {
      await dogrula();
    } catch (_) {}

    // Lite ayarları (best-effort): internet varsa Supabase'ten çek
    unawaited(LiteAyarlarServisi().senkronizeBestEffort(force: true));

    // Admin panel görünürlüğü için cihaz kaydı + geo + ilk hediye kredi toparlaması.
    unawaited(_syncLicenseIdFromServerBestEffort(force: true));
    unawaited(
      _syncOnlineRecoveryBestEffort(
        forceLiteSettingsSync: true,
        refreshGeo: true,
        forceStatusPush: true,
      ),
    );

    // Periyodik heartbeat: her 60 saniyede bir durumGuncelle(true)
    // Bu sayede uygulama force-kill olduğunda admin panelde 2 dk içinde offline olarak algılanır.
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      // Cache bypass: heartbeat her zaman gönderilmeli
      _lastOnlineStatus = null;
      unawaited(_periodicLicenseValidationBestEffort());
      unawaited(durumGuncelle(true));
      unawaited(_syncLicenseIdFromServerBestEffort());
      unawaited(_syncLosPayBalanceFromServerBestEffort());
    });
  }

  Future<void> _periodicLicenseValidationBestEffort() async {
    if (_periodicLicenseValidationRunning) return;

    _periodicLicenseValidationRunning = true;
    try {
      await dogrula(onlineTimeout: _periodicLicenseValidationTimeout);
    } catch (_) {
      // dogrula() zaten online/offline fallback'i kendi içinde yönetiyor.
    } finally {
      _periodicLicenseValidationRunning = false;
    }
  }

  /// Online/Offline durumunu günceller
  Future<void> durumGuncelle(bool online) async {
    if (_hardwareId == null) return;

    // Eğer durum zaten aynıysa boşuna network isteği atma (Veri Tasarrufu)
    if (_lastOnlineStatus == online) return;

    try {
      debugPrint(
        'Lisans Servisi: Durum güncelleniyor: ${online ? 'Online' : 'Offline'}',
      );
      final supabase = Supabase.instance.client;
      final machineName = await _getMachineName();
      final now = _nowUtc().toIso8601String();

      await supabase
          .from('program_deneme')
          .update({
            'is_online': online,
            'machine_name': machineName,
            'last_activity': now,
            'last_heartbeat': now,
          })
          .eq('hardware_id', _hardwareId!);

      _lastOnlineStatus = online;
      if (online) {
        unawaited(LiteAyarlarServisi().senkronizeBestEffort());
      }
    } catch (e) {
      debugPrint('Durum Güncelleme Hatası ($online): $e');
    }
  }

  /// Uygulama kapanırken "EN HIZLI" offline sinyali.
  ///
  /// Neden ayrı?
  /// - Kapanış anında ekstra IO (device_info vb.) bazen yetişmeyebiliyor.
  /// - Bu yüzden `machine_name` okumadan sadece kritik alanları günceller.
  /// - Ayrıca heartbeat timer'ını durdurur ki kapanış sırasında tekrar Online yazılmasın.
  Future<void> kapanisOfflineSinyaliGonder() async {
    final hid = _hardwareId;
    if (hid == null || hid.trim().isEmpty) return;

    try {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      // Force: kapanış anında mutlaka yaz.
      _lastOnlineStatus = null;

      final supabase = Supabase.instance.client;
      final now = _nowUtc().toIso8601String();

      final updated = await supabase
          .from('program_deneme')
          .update({
            'is_online': false,
            'last_activity': now,
            'last_heartbeat': now,
          })
          .eq('hardware_id', hid)
          .select('hardware_id');

      final updatedCount = updated.length;
      if (updatedCount == 0) {
        // Satır yoksa önce best-effort oluşturup tekrar dene.
        await _ensureProgramDenemeRowExistsBestEffort();
        await supabase
            .from('program_deneme')
            .update({
              'is_online': false,
              'last_activity': now,
              'last_heartbeat': now,
            })
            .eq('hardware_id', hid);
      }

      _lastOnlineStatus = false;
      debugPrint('Lisans Servisi: Offline sinyali gönderildi.');
    } catch (e) {
      debugPrint('Lisans Servisi: Offline sinyali gönderilemedi: $e');
    }
  }

  /// Kalp Atışı (Heartbeat) Gönderir
  Future<void> heartbeatGonder() async {
    if (_hardwareId == null) return;
    try {
      final supabase = Supabase.instance.client;
      final now = _nowUtc().toIso8601String();
      await supabase
          .from('program_deneme')
          .update({
            'last_heartbeat': now,
            'is_online': true, // Kalp atışı geliyorsa online'dır
          })
          .eq('hardware_id', _hardwareId!);

      _lastOnlineStatus = true;
      unawaited(LiteAyarlarServisi().senkronizeBestEffort());
      debugPrint('Lisans Servisi: Heartbeat gönderildi.');
    } catch (e) {
      debugPrint('Heartbeat Hatası: $e');
    }
  }

  /// Donanım bilgilerinden (Anakart/Cihaz ID) 8 haneli benzersiz ID üretir
  Future<String> _generateHardwareId() async {
    String? cachedHardwareId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsHardwareIdKey);
      if (cached != null) {
        final normalized = cached.trim().toUpperCase();
        final isValid = RegExp(r'^[0-9A-F]{8}$').hasMatch(normalized);
        if (isValid) {
          cachedHardwareId = normalized;
        }
      }
    } catch (_) {
      cachedHardwareId = null;
    }

    final identity = await _resolveRawHardwareIdentity();
    if (identity != null) {
      final hardwareId = _computeHardwareIdFromRawId(identity.rawId);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsHardwareIdKey, hardwareId);
      } catch (_) {}
      return hardwareId;
    }

    if (cachedHardwareId != null) {
      return cachedHardwareId;
    }

    final fallbackRawId =
        'ERROR-DEVICE-${DateTime.now().millisecondsSinceEpoch}';
    return _computeHardwareIdFromRawId(fallbackRawId);
  }

  Future<_HardwareIdentityResolution?> _resolveRawHardwareIdentity() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return _HardwareIdentityResolution(rawId: windowsInfo.deviceId);
      } else if (Platform.isMacOS) {
        final macOsInfo = await deviceInfo.macOsInfo;
        return _HardwareIdentityResolution(
          rawId: macOsInfo.systemGUID ?? macOsInfo.computerName,
        );
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return _HardwareIdentityResolution(
          rawId: linuxInfo.machineId ?? linuxInfo.name,
        );
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final androidId = await const AndroidId().getId();

        final serial = androidInfo.serialNumber.trim();
        final fallbackId =
            (serial.isNotEmpty && serial.toLowerCase() != 'unknown')
            ? serial
            : (androidInfo.fingerprint.isNotEmpty
                  ? androidInfo.fingerprint
                  : '${androidInfo.manufacturer}-${androidInfo.model}-${androidInfo.device}');

        return _HardwareIdentityResolution(
          rawId: 'ANDROID:${androidId ?? fallbackId}',
        );
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final idfv = iosInfo.identifierForVendor;
        final machine = iosInfo.utsname.machine;
        return _HardwareIdentityResolution(rawId: 'IOS:${idfv ?? machine}');
      } else {
        return const _HardwareIdentityResolution(rawId: 'GENERIC-DEVICE');
      }
    } catch (e) {
      debugPrint('Hardware ID Üretim Hatası: $e');
      return null;
    }
  }

  String _computeHardwareIdFromRawId(String rawId) {
    var bytes = utf8.encode(rawId);
    var digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8).toUpperCase();
  }

  /// Cihaz adını alır (Supabase'de görünmesi için)
  Future<String> _getMachineName() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        final base = winInfo.computerName;
        final details = <String>[];
        // productName: "Windows 10 Pro", "Windows 11 Home" vb.
        final productName = winInfo.productName;
        if (productName.isNotEmpty) details.add(productName);
        // displayVersion: "22H2", "24H2" vb.
        final displayVersion = winInfo.displayVersion;
        if (displayVersion.isNotEmpty) details.add(displayVersion);
        final detailText = details.join(' • ').trim();
        return detailText.isNotEmpty ? '$base ($detailText)' : base;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        final base = macInfo.computerName.isNotEmpty
            ? macInfo.computerName
            : macInfo.model;
        final details = <String>[];
        final osVersion =
            'macOS ${macInfo.majorVersion}.${macInfo.minorVersion}.${macInfo.patchVersion}';
        details.add(osVersion);
        if (macInfo.model.isNotEmpty && macInfo.model != macInfo.computerName) {
          details.add(macInfo.model);
        }
        final arch = macInfo.arch;
        if (arch.isNotEmpty) details.add(arch);
        final detailText = details.join(' • ').trim();
        return detailText.isNotEmpty ? '$base ($detailText)' : base;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        final base = linuxInfo.prettyName.isNotEmpty
            ? linuxInfo.prettyName
            : (linuxInfo.name.isNotEmpty ? linuxInfo.name : 'Linux');
        final details = <String>[];
        final version = linuxInfo.versionId ?? '';
        if (version.isNotEmpty) details.add('v$version');
        final machine = linuxInfo.machineId ?? '';
        if (machine.isNotEmpty && machine.length <= 12) details.add(machine);
        final detailText = details.join(' • ').trim();
        return detailText.isNotEmpty ? '$base ($detailText)' : base;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final manufacturer = (androidInfo.manufacturer).trim();
        final model = (androidInfo.model).trim();
        final device = (androidInfo.device).trim();
        final version = (androidInfo.version.release).trim();
        final sdk = androidInfo.version.sdkInt;

        final base = [
          manufacturer,
          model,
        ].where((p) => p.trim().isNotEmpty).join(' ').trim();

        final details = <String>[
          if (version.isNotEmpty) 'Android $version',
          'SDK $sdk',
          if (device.isNotEmpty && device.toLowerCase() != model.toLowerCase())
            device,
        ];

        final detailText = details.join(' • ').trim();
        if (base.isNotEmpty) {
          return detailText.isNotEmpty ? '$base ($detailText)' : base;
        }
        return detailText.isNotEmpty
            ? 'Android Device ($detailText)'
            : 'Android Device';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final name = (iosInfo.name).trim();
        final localizedModel = (iosInfo.localizedModel).trim();
        final model = (iosInfo.model).trim();
        final systemName = (iosInfo.systemName).trim();
        final systemVersion = (iosInfo.systemVersion).trim();
        final machine = (iosInfo.utsname.machine).trim();

        final base = name.isNotEmpty
            ? name
            : (localizedModel.isNotEmpty
                  ? localizedModel
                  : (model.isNotEmpty ? model : 'iOS Device'));

        final osText =
            '${systemName.isNotEmpty ? systemName : 'iOS'} $systemVersion'
                .trim();
        final details = <String>[
          if (osText.isNotEmpty) osText,
          if (machine.isNotEmpty) machine,
        ];

        final detailText = details.join(' • ').trim();
        return detailText.isNotEmpty ? '$base ($detailText)' : base;
      }
    } catch (_) {}
    return 'Bilinmeyen Cihaz';
  }

  void _startKasasiDokunmaTimer() {
    _kasasiDokunmaTimer?.cancel();
    _kasasiDokunmaTimer = Timer.periodic(_kasasiTouchInterval, (_) {
      unawaited(_persistKasasiBestEffort());
    });
  }

  Future<void> _kasasiYazSirala(Future<void> Function() action) async {
    _kasasiYazmaZinciri = _kasasiYazmaZinciri.then((_) => action());
    try {
      await _kasasiYazmaZinciri;
    } catch (_) {}
  }

  Future<LisansKasasiKaydi?> _readKasasiBestEffort() async {
    final hid = _hardwareId;
    if (hid == null || kIsWeb) return null;

    try {
      final exists = await _kasasi.dosyaVarMi(hardwareId: hid);
      final record = await _kasasi.oku(hardwareId: hid, secret: _vaultSecret);
      if (exists && record == null) {
        debugPrint(
          'Lisans Servisi: Lisans kasası bozuk/tamper tespit edildi. Sıfırlanıyor.',
        );
        await _kasasi.sil(hardwareId: hid);
      }
      return record;
    } catch (_) {
      return null;
    }
  }

  void _applyKasasiRecord(LisansKasasiKaydi record) {
    _kasasiMaxSeenUtc = record.maxSeenUtc.toUtc();

    _licenseKey = record.licenseKey;
    _licenseEndDate = record.licenseEndDateUtc?.toUtc();
  }

  Future<void> _persistKasasiBestEffort({bool includeLicenseKey = true}) async {
    final hid = _hardwareId;
    if (hid == null || kIsWeb) return;

    final nowUtc = _nowUtc();
    final previousMax = _kasasiMaxSeenUtc;

    final rollbackDetected =
        previousMax != null &&
        nowUtc.isBefore(previousMax.subtract(_clockRollbackTolerance));
    if (rollbackDetected) {
      debugPrint(
        'Lisans Servisi: Saat geri alındı tespit edildi (vault). Süre takibi uzatılmayacak.',
      );
    }

    final effectiveNow = (previousMax != null && nowUtc.isBefore(previousMax))
        ? previousMax
        : nowUtc;
    final newMax = (previousMax == null || effectiveNow.isAfter(previousMax))
        ? effectiveNow
        : previousMax;

    _kasasiMaxSeenUtc = newMax;

    final licenseEnd = _licenseEndDate;
    final licenseEndDateUtc = licenseEnd != null
        ? DateTime.utc(licenseEnd.year, licenseEnd.month, licenseEnd.day)
        : null;

    final record = LisansKasasiKaydi(
      version: 2,
      hardwareId: hid,
      licenseKey: includeLicenseKey ? _licenseKey : null,
      licenseEndDateUtc: licenseEndDateUtc,
      lastSeenUtc: effectiveNow,
      maxSeenUtc: newMax,
    );

    await _kasasiYazSirala(
      () => _kasasi.yaz(hardwareId: hid, secret: _vaultSecret, record: record),
    );
  }

  Future<void> _setLicenseEndDate(DateTime? endDate) async {
    _licenseEndDate = endDate;
    final prefs = await SharedPreferences.getInstance();

    if (endDate == null) {
      await prefs.remove(_prefsLicenseEndDateKey);
      unawaited(_persistKasasiBestEffort(includeLicenseKey: false));
      return;
    }

    await prefs.setString(_prefsLicenseEndDateKey, endDate.toIso8601String());
    unawaited(_persistKasasiBestEffort());
  }

  Future<void> _setLicenseIdLocal(String? licenseId) async {
    if (_hardwareId == null) return;

    final normalized = licenseId?.toString().trim().toUpperCase();
    final cleaned = (normalized != null && normalized.trim().isNotEmpty)
        ? normalized
        : null;
    if (_licenseId == cleaned) return;

    _licenseId = cleaned;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (cleaned == null) {
        await prefs.remove(_prefsLicenseIdKey);
      } else {
        await prefs.setString(_prefsLicenseIdKey, cleaned);
      }
    } catch (_) {}

    notifyListeners();
  }

  Future<_LocalManualActivation?> _readValidLocalManualActivation() async {
    final hardwareId = _hardwareId?.trim().toUpperCase() ?? '';
    if (hardwareId.isEmpty) return null;

    String? rawToken = (_licenseKey != null && _licenseKey!.trim().isNotEmpty)
        ? _licenseKey!.trim()
        : null;

    if (rawToken == null) {
      final prefs = await SharedPreferences.getInstance();
      final legacyToken = prefs.getString(_prefsLicenseKeyKey);
      if (legacyToken != null && legacyToken.trim().isNotEmpty) {
        rawToken = legacyToken.trim();
      }
    }

    if (rawToken == null) {
      final vaultRecord = await _readKasasiBestEffort();
      final vaultToken = vaultRecord?.licenseKey;
      if (vaultToken != null && vaultToken.trim().isNotEmpty) {
        rawToken = vaultToken.trim();
      }
    }

    if (rawToken == null || rawToken.isEmpty) return null;

    final tokenInfo = _verifyAndParseManualActivationCode(rawToken);
    if (tokenInfo == null) return null;

    if (tokenInfo.hardwareId.trim().toUpperCase() != hardwareId) {
      return null;
    }

    if (_isLitePackageName(tokenInfo.packageName) ||
        _isExpiredByDate(tokenInfo.expiryDate)) {
      return null;
    }

    return _LocalManualActivation(rawToken: rawToken, tokenInfo: tokenInfo);
  }

  Future<void> _applyManualActivationLocally(
    _LocalManualActivation activation, {
    bool notify = true,
    bool persist = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLicenseKeyKey);

    _licenseKey = activation.rawToken;
    _isLicensed = true;
    _noOnlineLicenseLogged = false;

    await _setInheritedProLocal(false, notify: false);
    await _setLicenseEndDate(activation.tokenInfo.expiryDate);

    final normalizedLicenseId = activation.tokenInfo.licenseId
        ?.trim()
        .toUpperCase();
    final currentLicenseId = _licenseId?.trim().toUpperCase();
    await _setLicenseIdLocal(
      (normalizedLicenseId != null && normalizedLicenseId.isNotEmpty)
          ? normalizedLicenseId
          : ((currentLicenseId != null && currentLicenseId.isNotEmpty)
                ? currentLicenseId
                : (_hardwareId ?? '')),
    );

    if (persist) {
      await _persistKasasiBestEffort();
    }

    if (notify) {
      notifyListeners();
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.trim().replaceAll(',', '.');
      return double.tryParse(normalized) ?? 0;
    }
    return 0;
  }

  Future<void> _setLosPayBalanceLocal(
    double amount, {
    bool notify = true,
  }) async {
    if (_hardwareId == null) return;

    final double sanitized = amount.isFinite
        ? (amount < 0 ? 0.0 : amount)
        : 0.0;
    if ((_losPayBalance - sanitized).abs() < 0.0001) return;

    _losPayBalance = sanitized;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsLosPayBalanceKey, sanitized);
    } catch (_) {}

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> losPayBakiyesiGuncelle(
    double amount, {
    bool notify = true,
  }) async {
    await _setLosPayBalanceLocal(amount, notify: notify);
  }

  Future<void> _setInheritedProLocal(bool status, {bool notify = true}) async {
    if (_inheritedPro == status) return;

    _inheritedPro = status;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsInheritedProKey, status);

    if (notify) {
      notifyListeners();
    }
  }

  void _setServerReachable(bool value, {bool notify = true}) {
    if (_serverReachable == value) return;
    _serverReachable = value;
    if (notify) {
      notifyListeners();
    }
  }

  bool _isLitePackageName(String? packageName) {
    final value = (packageName ?? '').trim().toUpperCase();
    if (value.isEmpty) return false;
    return value.contains('LITE');
  }

  Future<void> _clearOnlineLicenseState({
    bool clearInheritedPro = false,
    bool notify = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLicenseKeyKey);

    _licenseKey = null;
    _isLicensed = false;

    if (clearInheritedPro) {
      await _setInheritedProLocal(false, notify: false);
    }

    await _setLicenseEndDate(null);
    unawaited(_persistKasasiBestEffort(includeLicenseKey: false));

    if (notify) {
      notifyListeners();
    }
  }

  bool _isExpiredByDate(DateTime endDate) {
    final today = _secureTodayUtc();
    final end = DateTime.utc(endDate.year, endDate.month, endDate.day);
    return end.isBefore(today);
  }

  /// Yerel lisans durumunu kontrol eder
  Future<void> _checkLicenseStatus() async {
    if (_hardwareId == null) return;

    final prefs = await SharedPreferences.getInstance();
    _inheritedPro = prefs.getBool(_prefsInheritedProKey) ?? false;
    final legacyPrefsKey = prefs.getString(_prefsLicenseKeyKey);

    // Vault varsa oku ve local state'e uygula
    final vaultRecord = await _readKasasiBestEffort();
    if (vaultRecord != null) {
      _applyKasasiRecord(vaultRecord);
    }

    final localKey = (_licenseKey != null && _licenseKey!.trim().isNotEmpty)
        ? _licenseKey
        : legacyPrefsKey;

    if (localKey == null || localKey.trim().isEmpty) {
      _licenseKey = null;
      _isLicensed = false;
      await _setLicenseEndDate(null);
      if (legacyPrefsKey != null) await prefs.remove(_prefsLicenseKeyKey);
      unawaited(_persistKasasiBestEffort(includeLicenseKey: false));
      notifyListeners();
      return;
    }

    if (localKey.startsWith('CANCELLED')) {
      await prefs.remove(_prefsLicenseKeyKey);
      _licenseKey = null;
      _isLicensed = false;
      await _setLicenseEndDate(null);
      unawaited(_persistKasasiBestEffort(includeLicenseKey: false));
      notifyListeners();
      debugPrint('Lisans Servisi: Yerel lisans iptal edilmiş.');
      return;
    }

    final tokenInfo = _parseLicenseProof(localKey);
    if (tokenInfo == null) {
      await prefs.remove(_prefsLicenseKeyKey);
      _licenseKey = null;
      _isLicensed = false;
      await _setLicenseEndDate(null);
      unawaited(_persistKasasiBestEffort(includeLicenseKey: false));
      notifyListeners();
      debugPrint(
        'Lisans Servisi: Yerel lisans doğrulanamadı (token geçersiz).',
      );
      return;
    }

    final tokenHardwareId = tokenInfo.hardwareId.toUpperCase();
    if (tokenHardwareId != _hardwareId!.toUpperCase()) {
      await prefs.remove(_prefsLicenseKeyKey);
      _licenseKey = null;
      _isLicensed = false;
      await _setLicenseEndDate(null);
      unawaited(_persistKasasiBestEffort(includeLicenseKey: false));
      notifyListeners();
      debugPrint('Lisans Servisi: Yerel lisans bu cihaz için değil.');
      return;
    }

    if (_isLitePackageName(tokenInfo.packageName)) {
      await prefs.remove(_prefsLicenseKeyKey);
      _licenseKey = null;
      _isLicensed = false;
      await _setLicenseEndDate(null);
      unawaited(_persistKasasiBestEffort(includeLicenseKey: false));
      notifyListeners();
      debugPrint('Lisans Servisi: Yerel paket Lite olarak işaretlendi.');
      return;
    }

    final endDate = tokenInfo.expiryDate;
    await _setLicenseEndDate(endDate);

    if (_isExpiredByDate(endDate)) {
      await prefs.remove(_prefsLicenseKeyKey);
      _licenseKey = null;
      _isLicensed = false;
      unawaited(_persistKasasiBestEffort(includeLicenseKey: false));
      notifyListeners();
      debugPrint(
        'Lisans Servisi: Yerel lisans süresi dolmuş. LITE sürüme düşüldü.',
      );
      return;
    }

    _licenseKey = localKey;
    _isLicensed = true;
    await _persistKasasiBestEffort();
    if (legacyPrefsKey != null) await prefs.remove(_prefsLicenseKeyKey);
    notifyListeners();
    debugPrint('Lisans Servisi: Yerel lisans bulundu ve doğrulandı.');
  }

  /// Lisans doğrulama:
  /// - Yerelde: Offline token doğrulaması + süre kontrolü.
  /// - Online (best-effort): Supabase `licenses` tablosundan en güncel lisansı çekip günceller.
  ///
  /// Kural: Lisans bitince uygulama kapanmaz; otomatik olarak LITE moda düşer.
  Future<bool> dogrula({
    Duration onlineTimeout = const Duration(seconds: 4),
  }) async {
    try {
      bool forceLiteByLifecycle = false;
      final localManualActivation = await _readValidLocalManualActivation();
      final wasServerReachable = _serverReachable == true;
      final lifecycle = await _programDurumuGetirOnlineOrThrow(
        timeout: onlineTimeout,
      );
      final serverLicenseId = lifecycle?.licenseId;
      if (lifecycle != null) {
        await _setLicenseIdLocal(serverLicenseId);
        // Online cevap geldiyse lisans kararı artık çevrim içi kayıttan alınır.
        await _setInheritedProLocal(false, notify: false);

        final status = lifecycle.status;
        if (status != null && status.isNotEmpty && status != 'converted') {
          forceLiteByLifecycle = true;
        }
      }

      // Online-first: Supabase'e erişilebiliyorsa yerel lisans dikkate alınmaz.
      // Online sorgu başarıyla dönüp kayıt yoksa (silinmişse) cihaz direkt LITE'a düşer.
      final data = await _lisansBilgisiGetirOnlineOrThrow(
        timeout: onlineTimeout,
        groupLicenseIdOverride: serverLicenseId,
      );
      _setServerReachable(true, notify: false);
      await _syncLosPayBalanceFromServerBestEffort(
        licenseData: data,
        timeout: onlineTimeout,
        force: true,
        notify: false,
        clearOnMissing: true,
      );
      final shouldRunOnlineRecovery =
          !wasServerReachable || _losPayBalance <= 0.0001;
      if (shouldRunOnlineRecovery) {
        await _syncOnlineRecoveryBestEffort(
          forceLiteSettingsSync: true,
          refreshGeo: true,
          forceStatusPush: !wasServerReachable,
        );
      }

      if (data == null) {
        if (localManualActivation != null) {
          await _applyManualActivationLocally(localManualActivation);
          return _isLicensed;
        }
        await _clearOnlineLicenseState(notify: true);
        if (!_noOnlineLicenseLogged) {
          _noOnlineLicenseLogged = true;
          debugPrint(
            'Lisans Servisi: Online lisans kaydı bulunamadı. Yerel lisans yok sayıldı ve LITE moda düşüldü.',
          );
        }
        return _isLicensed;
      }

      // Online lisans bulundu (veya kayıt var): tekrar log basabilmek için sıfırla.
      _noOnlineLicenseLogged = false;

      final currentHardwareId = _hardwareId?.trim().toUpperCase() ?? '';
      final dataHardwareId =
          data['hardware_id']?.toString().trim().toUpperCase() ?? '';
      final hasDirectOnlineLicense =
          currentHardwareId.isNotEmpty && dataHardwareId == currentHardwareId;

      if (forceLiteByLifecycle && !hasDirectOnlineLicense) {
        if (localManualActivation != null) {
          await _applyManualActivationLocally(localManualActivation);
          return _isLicensed;
        }
        await _clearOnlineLicenseState(notify: true);
        return _isLicensed;
      }

      final key = data['license_key']?.toString() ?? '';
      final packageName = data['package_name']?.toString();
      final isLitePackage = _isLitePackageName(packageName);
      final isCancelled = key.startsWith('CANCELLED');

      final endDateRaw = data['end_date'];
      final parsedEndDate = endDateRaw != null
          ? DateTime.tryParse(endDateRaw.toString())
          : null;

      if (isLitePackage || isCancelled || key.trim().isEmpty) {
        await _clearOnlineLicenseState(notify: true);
        return _isLicensed;
      }

      if (parsedEndDate != null && _isExpiredByDate(parsedEndDate)) {
        await _clearOnlineLicenseState(notify: true);
        return _isLicensed;
      }

      // PRO (aktif lisans)
      await _setLicenseEndDate(parsedEndDate);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsLicenseKeyKey);
      _licenseKey = key;
      _isLicensed = true;
      unawaited(_persistKasasiBestEffort());
      notifyListeners();
      return _isLicensed;
    } catch (e) {
      // Online doğrulama başarısız; yerel lisans ile devam.
      _setServerReachable(false, notify: false);
      debugPrint(
        'Lisans Servisi: Online doğrulama başarısız, yerel lisansa düşülüyor: $e',
      );
      await _checkLicenseStatus();
      return _isLicensed;
    } finally {
      if (_isInitialized) {
        unawaited(_ensureProgramDenemeRowExistsBestEffort());
      }
    }
  }

  Future<void> _ensureProgramDenemeRowExistsBestEffort({
    bool forceLiteSettingsSync = false,
  }) async {
    if (_hardwareId == null) return;

    final supabase = Supabase.instance.client;
    final machineName = await _getMachineName();
    final now = _nowUtc().toIso8601String();
    final desiredStatus = isLicensed ? 'converted' : 'active';
    final hid = _hardwareId!;
    if (forceLiteSettingsSync) {
      await LiteAyarlarServisi().baslat();
      await LiteAyarlarServisi().senkronizeBestEffort(force: true);
    }

    bool isMissingColumn(PostgrestException error, String columnName) {
      final msg = error.message.toLowerCase();
      return msg.contains(columnName) &&
          (msg.contains('column') || msg.contains('schema'));
    }

    Future<void> insertProgramDeneme(Map<String, dynamic> payload) async {
      final nextPayload = Map<String, dynamic>.from(payload);

      while (true) {
        try {
          await supabase.from('program_deneme').insert(nextPayload);
          return;
        } on PostgrestException catch (e) {
          if (isMissingColumn(e, 'status') &&
              nextPayload.containsKey('status')) {
            nextPayload.remove('status');
            continue;
          }
          rethrow;
        }
      }
    }

    Future<void> updateProgramDeneme(Map<String, dynamic> payload) async {
      final nextPayload = Map<String, dynamic>.from(payload);

      while (true) {
        try {
          await supabase
              .from('program_deneme')
              .update(nextPayload)
              .eq('hardware_id', hid);
          return;
        } on PostgrestException catch (e) {
          if (isMissingColumn(e, 'status') &&
              nextPayload.containsKey('status')) {
            nextPayload.remove('status');
            continue;
          }
          rethrow;
        }
      }
    }

    try {
      final payload = {
        'hardware_id': hid,
        'machine_name': machineName,
        'install_date': now,
        'last_activity': now,
        'is_online': true,
        'last_heartbeat': now,
        'status': desiredStatus,
      };

      await insertProgramDeneme(payload);
      debugPrint('Lisans Servisi: program_deneme cihaz kaydı oluşturuldu.');
    } on PostgrestException catch (e) {
      final msg = (e.message).toLowerCase();
      final isDuplicate = msg.contains('duplicate') || msg.contains('unique');
      if (!isDuplicate) {
        debugPrint('program_deneme insert hatası: $e');
        return;
      }

      try {
        await updateProgramDeneme({
          'machine_name': machineName,
          'last_activity': now,
          'is_online': true,
          'last_heartbeat': now,
          'status': desiredStatus,
        });
      } catch (e2) {
        debugPrint('program_deneme update hatası: $e2');
      }
    } catch (e) {
      debugPrint('program_deneme ensure hatası: $e');
    }
  }

  String? _normalizeGeoSyncValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized.toLowerCase() == 'unknown') return null;
    return normalized;
  }

  Future<void> _ensureLiteInstallBenefitsBestEffort({
    String? ipAddress,
    String? city,
  }) async {
    final hid = _hardwareId;
    if (hid == null || hid.trim().isEmpty) return;

    final normalizedLicenseId = _licenseId?.trim().toUpperCase();
    final normalizedIpAddress = _normalizeGeoSyncValue(ipAddress);
    final normalizedCity = _normalizeGeoSyncValue(city);
    final bodyPayload = <String, dynamic>{
      'hardware_id': hid,
      if (normalizedLicenseId != null && normalizedLicenseId.isNotEmpty)
        'license_id': normalizedLicenseId,
    };
    if (normalizedIpAddress != null) {
      bodyPayload['ip_address'] = normalizedIpAddress;
    }
    if (normalizedCity != null) {
      bodyPayload['city'] = normalizedCity;
    }

    try {
      final response = await http
          .post(
            Uri.parse(
              '${LisansServisi.u}/functions/v1/ensure-lite-install-benefits',
            ),
            headers: {
              'Content-Type': 'application/json',
              'apikey': LisansServisi.k,
              'Authorization': 'Bearer ${LisansServisi.k}',
            },
            body: jsonEncode(bodyPayload),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Lisans Servisi: Lite kurulum hediyesi senkron hatası '
          '(${response.statusCode}): ${response.body}',
        );
        return;
      }

      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final currentBalance = _toDouble(body['current_balance']);
        if (currentBalance >= 0) {
          await _setLosPayBalanceLocal(currentBalance, notify: false);
        }
      }
    } catch (e) {
      debugPrint('Lisans Servisi: Lite kurulum hediyesi senkron hatası: $e');
    }
  }

  Future<void> _syncLicenseIdFromServerBestEffort({bool force = false}) async {
    final hid = _hardwareId;
    if (hid == null || hid.trim().isEmpty) return;

    final now = _nowUtc();
    final last = _licenseIdLastSyncUtc;
    if (!force &&
        last != null &&
        now.difference(last) < _licenseIdSyncInterval) {
      return;
    }
    _licenseIdLastSyncUtc = now;

    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('program_deneme')
          .select('license_id')
          .eq('hardware_id', hid)
          .maybeSingle();

      if (data is Map<String, dynamic>) {
        final serverLicenseId = data['license_id']?.toString().trim();
        unawaited(_setLicenseIdLocal(serverLicenseId));
      }
    } on PostgrestException catch (e) {
      final msg = (e.message).toLowerCase();
      final licenseIdColumnMissing =
          msg.contains('license_id') &&
          (msg.contains('column') || msg.contains('schema'));
      if (licenseIdColumnMissing) return;
      debugPrint('Lisans Servisi: license_id senkron hatası: $e');
    } catch (e) {
      debugPrint('Lisans Servisi: license_id senkron hatası: $e');
    }
  }

  Future<void> _syncLosPayBalanceFromServerBestEffort({
    Map<String, dynamic>? licenseData,
    Duration timeout = const Duration(seconds: 4),
    bool force = false,
    bool notify = true,
    bool clearOnMissing = false,
  }) async {
    final hid = _hardwareId;
    if (hid == null || hid.trim().isEmpty) return;

    final now = _nowUtc();
    final last = _losPayLastSyncUtc;
    if (!force && last != null && now.difference(last) < _losPaySyncInterval) {
      return;
    }
    _losPayLastSyncUtc = now;

    final supabase = Supabase.instance.client;
    bool isMissingLosPayColumn(PostgrestException error) {
      final msg = error.message.toLowerCase();
      return msg.contains('lospay_credit') &&
          (msg.contains('column') || msg.contains('schema'));
    }

    try {
      final rawCustomerId = licenseData?['customer_id']?.toString().trim();
      double? customerBalance;
      bool hasCustomerBalance = false;
      double? programBalance;
      bool hasProgramBalance = false;

      if (rawCustomerId != null && rawCustomerId.isNotEmpty) {
        try {
          final result = await supabase
              .from('customers')
              .select('lospay_credit')
              .eq('id', rawCustomerId)
              .maybeSingle()
              .timeout(timeout);
          if (result is Map<String, dynamic>) {
            customerBalance = _toDouble(result['lospay_credit']);
            hasCustomerBalance = true;
          }
        } on PostgrestException catch (e) {
          if (!isMissingLosPayColumn(e)) rethrow;
        }
      } else {
        try {
          final rowsRaw = await supabase
              .from('customers')
              .select('lospay_credit')
              .eq('hardware_id', hid)
              .timeout(timeout);
          final rows = List<Map<String, dynamic>>.from(rowsRaw as List);
          for (final row in rows) {
            final value = _toDouble(row['lospay_credit']);
            if (!hasCustomerBalance || value > (customerBalance ?? 0)) {
              customerBalance = value;
              hasCustomerBalance = true;
            }
          }
        } on PostgrestException catch (e) {
          if (!isMissingLosPayColumn(e)) rethrow;
        }
      }

      try {
        final demoData = await supabase
            .from('program_deneme')
            .select('lospay_credit')
            .eq('hardware_id', hid)
            .maybeSingle()
            .timeout(timeout);
        if (demoData is Map<String, dynamic>) {
          programBalance = _toDouble(demoData['lospay_credit']);
          hasProgramBalance = true;
        }
      } on PostgrestException catch (e) {
        if (!isMissingLosPayColumn(e)) rethrow;
      }

      if (hasCustomerBalance || hasProgramBalance) {
        var resolvedBalance = 0.0;
        if (hasCustomerBalance) {
          resolvedBalance = customerBalance ?? 0;
        }
        if (hasProgramBalance &&
            (!hasCustomerBalance || (programBalance ?? 0) > resolvedBalance)) {
          resolvedBalance = programBalance ?? 0;
        }
        await _setLosPayBalanceLocal(resolvedBalance, notify: notify);
        return;
      }

      if (clearOnMissing) {
        await _setLosPayBalanceLocal(0, notify: notify);
      }
    } on PostgrestException catch (e) {
      if (isMissingLosPayColumn(e)) return;
      debugPrint('Lisans Servisi: LosPay senkron hatası: $e');
    } catch (e) {
      debugPrint('Lisans Servisi: LosPay senkron hatası: $e');
    }
  }

  Future<void> senkronizeLosPayBakiyesiBestEffort({
    Map<String, dynamic>? licenseData,
    Duration timeout = const Duration(seconds: 4),
    bool force = false,
    bool clearOnMissing = false,
  }) {
    return _syncLosPayBalanceFromServerBestEffort(
      licenseData: licenseData,
      timeout: timeout,
      force: force,
      notify: true,
      clearOnMissing: clearOnMissing,
    );
  }

  /// Cihazı verilen Lisans Kimliği'ne (License ID) bağlar.
  ///
  /// Not: Bu işlem sadece `program_deneme.license_id` alanını günceller.
  /// (Cihazın kendi `hardware_id` kimliği değişmez.)
  Future<bool> lisansKimligiGuncelle(String licenseId) async {
    final hid = _hardwareId;
    final normalized = licenseId.trim().toUpperCase();
    if (hid == null || hid.trim().isEmpty) return false;
    if (normalized.isEmpty) return false;

    try {
      // Satır yoksa önce oluşturmayı dene (best-effort).
      await _ensureProgramDenemeRowExistsBestEffort();

      final supabase = Supabase.instance.client;
      await supabase
          .from('program_deneme')
          .update({'license_id': normalized})
          .eq('hardware_id', hid);

      _licenseIdLastSyncUtc = _nowUtc();
      await _setLicenseIdLocal(normalized);
      return true;
    } on PostgrestException catch (e) {
      final msg = (e.message).toLowerCase();
      final licenseIdColumnMissing =
          msg.contains('license_id') &&
          (msg.contains('column') || msg.contains('schema'));
      if (licenseIdColumnMissing) return false;

      debugPrint('Lisans Servisi: license_id güncelleme hatası: $e');
      return false;
    } catch (e) {
      debugPrint('Lisans Servisi: license_id güncelleme hatası: $e');
      return false;
    }
  }

  Future<void> _updateGeoInfo({
    String? ipOverride,
    String? cityOverride,
  }) async {
    final hid = _hardwareId;
    if (hid == null) return;
    try {
      String? ip = _normalizeGeoSyncValue(ipOverride);
      String? city = _normalizeGeoSyncValue(cityOverride);

      if (ip == null && city == null) {
        final geoInfo = await _getGeoInfo();
        ip = _normalizeGeoSyncValue(geoInfo['ip']);
        city = _normalizeGeoSyncValue(geoInfo['city']);
      }

      if (ip == null && city == null) return;

      final payload = <String, dynamic>{};
      if (ip != null) payload['ip_address'] = ip;
      if (city != null) payload['city'] = city;
      if (payload.isEmpty) return;

      final supabase = Supabase.instance.client;
      await supabase
          .from('program_deneme')
          .update(payload)
          .eq('hardware_id', hid);
      await supabase.from('customers').update(payload).eq('hardware_id', hid);
    } catch (e) {
      debugPrint('Geo Info Güncelleme Hatası: $e');
    }
  }

  Future<void> _syncOnlineRecoveryBestEffort({
    bool forceLiteSettingsSync = false,
    bool refreshGeo = false,
    bool forceStatusPush = false,
  }) async {
    final hid = _hardwareId;
    if (hid == null || hid.trim().isEmpty) return;

    String? ipAddress;
    String? city;

    try {
      await _ensureProgramDenemeRowExistsBestEffort(
        forceLiteSettingsSync: forceLiteSettingsSync,
      );

      if (refreshGeo) {
        final geoInfo = await _getGeoInfo();
        ipAddress = _normalizeGeoSyncValue(geoInfo['ip']);
        city = _normalizeGeoSyncValue(geoInfo['city']);
      }

      if (forceStatusPush) {
        _lastOnlineStatus = null;
      }
      await durumGuncelle(true);

      if (ipAddress != null || city != null) {
        await _updateGeoInfo(ipOverride: ipAddress, cityOverride: city);
      }

      await _ensureLiteInstallBenefitsBestEffort(
        ipAddress: ipAddress,
        city: city,
      );
      await _syncLicenseIdFromServerBestEffort(force: true);
      await _syncLosPayBalanceFromServerBestEffort(force: true, notify: true);
    } catch (e) {
      debugPrint('Lisans Servisi: Online toparlama senkronu hatası: $e');
    }
  }

  DateTime get _manualCodeEpochUtc => DateTime.utc(2024, 1, 1);

  String? _manualPackageNameFromCode(int packageCode) {
    switch (packageCode) {
      case _manualPackageLite:
        return 'LOT LITE - Sınırlı';
      case _manualPackageMonthly:
        return 'LOT PRO - Aylık Plan';
      case _manualPackageSemiannual:
        return 'LOT PRO - 6 Aylık Plan';
      case _manualPackageYearly:
        return 'LOT PRO - Yıllık Plan';
      default:
        return null;
    }
  }

  String? _manualPlanCodeFromCode(int packageCode) {
    switch (packageCode) {
      case _manualPackageLite:
        return 'lite';
      case _manualPackageMonthly:
        return 'monthly';
      case _manualPackageSemiannual:
        return 'semiannual';
      case _manualPackageYearly:
        return 'yearly';
      default:
        return null;
    }
  }

  String _normalizeManualActivationCode(String rawCode) {
    final compact = rawCode.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    if (compact.startsWith(_manualCodePrefix)) {
      return compact.substring(_manualCodePrefix.length);
    }
    return compact;
  }

  int _computeManualCodeMac(
    String hardwareId,
    String expiryDate,
    int packageCode, {
    required int version,
    required int macBits,
  }) {
    final macMask = (1 << macBits) - 1;
    final payload =
        '$_manualCodePrefix$version|${hardwareId.toUpperCase()}|$expiryDate|$packageCode';
    final digest = Hmac(
      sha256,
      utf8.encode(_licenseSecret),
    ).convert(utf8.encode(payload));

    return ((digest.bytes[0] << 16) |
            (digest.bytes[1] << 8) |
            digest.bytes[2]) &
        macMask;
  }

  _LicenseTokenInfo? _tryParseManualActivationCodeLayout(
    String normalized, {
    required int version,
    required int dayBits,
    required int macBits,
  }) {
    final shift = _manualCodeVersionBits + _manualCodePackageBits + macBits;
    final versionShift = _manualCodePackageBits + macBits;
    final packageShift = macBits;
    final packageMask = (1 << _manualCodePackageBits) - 1;
    final macMask = (1 << macBits) - 1;
    final maxDayOffset = (1 << dayBits) - 1;
    final numericValue = int.tryParse(normalized);
    if (numericValue == null) return null;

    final dayOffset = numericValue >> shift;
    final parsedVersion =
        (numericValue >> versionShift) & ((1 << _manualCodeVersionBits) - 1);
    final packageCode = (numericValue >> packageShift) & packageMask;
    final mac = numericValue & macMask;

    if (parsedVersion != version) return null;
    if (dayOffset < 0 || dayOffset > maxDayOffset) return null;

    final expiryUtc = _manualCodeEpochUtc.add(Duration(days: dayOffset));
    final expiryDate = DateTime(expiryUtc.year, expiryUtc.month, expiryUtc.day);
    final hardwareId = (_hardwareId ?? '').trim().toUpperCase();
    if (hardwareId.isEmpty) return null;

    final expiryText =
        '${expiryUtc.year.toString().padLeft(4, '0')}-'
        '${expiryUtc.month.toString().padLeft(2, '0')}-'
        '${expiryUtc.day.toString().padLeft(2, '0')}';
    final expectedMac = _computeManualCodeMac(
      hardwareId,
      expiryText,
      packageCode,
      version: version,
      macBits: macBits,
    );
    if (expectedMac != mac) return null;

    return _LicenseTokenInfo(
      hardwareId: hardwareId,
      licenseId: null,
      expiryDate: expiryDate,
      packageName: _manualPackageNameFromCode(packageCode),
      planCode: _manualPlanCodeFromCode(packageCode),
    );
  }

  _LicenseTokenInfo? _verifyAndParseManualActivationCode(String rawCode) {
    try {
      final normalized = _normalizeManualActivationCode(rawCode);
      if (!RegExp(r'^\d{12}$').hasMatch(normalized)) return null;
      return _tryParseManualActivationCodeLayout(
            normalized,
            version: _manualCodeVersion,
            dayBits: _manualCodeDayBits,
            macBits: _manualCodeMacBits,
          ) ??
          _tryParseManualActivationCodeLayout(
            normalized,
            version: _legacyManualCodeVersion,
            dayBits: _legacyManualCodeDayBits,
            macBits: _legacyManualCodeMacBits,
          );
    } catch (_) {
      return null;
    }
  }

  _LicenseTokenInfo? _parseLicenseProof(String rawValue) {
    final normalized = rawValue.trim();
    if (normalized.isEmpty) return null;
    return _verifyAndParseLicenseToken(normalized) ??
        _verifyAndParseManualActivationCode(normalized);
  }

  _LicenseTokenInfo? _verifyAndParseLicenseToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 2) return null;

      final base64Data = parts[0];
      final signaturePart = parts[1];

      final String data;
      try {
        data = utf8.decode(base64.decode(base64Data));
      } catch (_) {
        return null;
      }

      if (!_verifyLicenseSignature(data, signaturePart)) return null;

      final decoded = json.decode(data);
      if (decoded is! Map) return null;

      final hardwareId = decoded['hardware_id']?.toString();
      final licenseId = decoded['license_id']?.toString();
      final expiryStr = decoded['expiry_date']?.toString();
      final packageName = decoded['package_name']?.toString();
      final planCode = decoded['plan_code']?.toString();
      if (hardwareId == null || expiryStr == null) return null;

      final expiry = DateTime.tryParse(expiryStr);
      if (expiry == null) return null;

      final expiryDateOnly = DateTime(expiry.year, expiry.month, expiry.day);
      return _LicenseTokenInfo(
        hardwareId: hardwareId,
        licenseId: licenseId,
        expiryDate: expiryDateOnly,
        packageName: packageName,
        planCode: planCode,
      );
    } catch (_) {
      return null;
    }
  }

  Future<_ProgramLisansDurumu?> _programDurumuGetirOnlineOrThrow({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (_hardwareId == null) return null;

    final supabase = Supabase.instance.client;

    try {
      final data = await supabase
          .from('program_deneme')
          .select('status, license_id')
          .eq('hardware_id', _hardwareId!)
          .maybeSingle()
          .timeout(timeout);

      if (data is! Map<String, dynamic>) return null;

      final status = data['status']?.toString().trim().toLowerCase();
      final licenseId = data['license_id']?.toString().trim().toUpperCase();

      return _ProgramLisansDurumu(
        status: (status == null || status.isEmpty) ? null : status,
        licenseId: (licenseId == null || licenseId.isEmpty) ? null : licenseId,
      );
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final missingKnownColumn =
          (msg.contains('status') || msg.contains('license_id')) &&
          (msg.contains('column') || msg.contains('schema'));
      if (missingKnownColumn) {
        return null;
      }
      rethrow;
    }
  }

  bool _verifyLicenseSignature(String data, String signaturePart) {
    final secret = _licenseSecret;

    if (signaturePart.startsWith('FB-')) {
      final sig = signaturePart.substring(3);
      return _pureJSHmacFallback(secret, data) == sig;
    }

    try {
      final hmac = Hmac(sha256, utf8.encode(secret));
      final expected = base64.encode(hmac.convert(utf8.encode(data)).bytes);
      return expected == signaturePart;
    } catch (_) {
      return false;
    }
  }

  String _pureJSHmacFallback(String key, String message) {
    int hash = 0;
    final combined = key + message;
    for (final codeUnit in combined.codeUnits) {
      hash = ((hash << 5) - hash) + codeUnit;
      hash = hash & 0xFFFFFFFF;
      if ((hash & 0x80000000) != 0) {
        hash = hash - 0x100000000;
      }
    }
    return hash.abs().toRadixString(16);
  }

  Future<Map<String, dynamic>?> _lisansBilgisiGetirOnlineOrThrow({
    Duration timeout = const Duration(seconds: 4),
    String? groupLicenseIdOverride,
  }) async {
    if (_hardwareId == null) return null;
    final supabase = Supabase.instance.client;
    final direct = await supabase
        .from('licenses')
        .select()
        .eq('hardware_id', _hardwareId!)
        .order('end_date', ascending: false)
        .limit(1)
        .maybeSingle()
        .timeout(timeout);

    // Eğer cihaz bir lisans grubuna (license_id) bağlıysa, lisans bilgisini grup bazında al.
    // Böylece kullanıcı farklı cihazda PRO lisans aldıysa, birleşen tüm cihazlarda PRO görünür.
    final groupId = (groupLicenseIdOverride ?? _licenseId)
        ?.trim()
        .toUpperCase();
    if (groupId == null || groupId.isEmpty) return direct;

    final hwIds = await OnlineVeritabaniServisi().cihazlariGetirByLisansKimligi(
      groupId,
    );
    if (hwIds.isEmpty) return direct;

    final inherited = await supabase
        .from('licenses')
        .select()
        .inFilter('hardware_id', hwIds)
        .order('end_date', ascending: false)
        .limit(1)
        .maybeSingle()
        .timeout(timeout);
    return inherited ?? direct;
  }

  /// Supabase üzerinden lisans bilgilerini sorgular (best-effort).
  ///
  /// - Online erişilemiyorsa `null` döner.
  /// - Online erişilip kayıt yoksa yine `null` döner (bu ayrımı yapmak isteyenler
  ///   `_lisansBilgisiGetirOnlineOrThrow` kullanmalı).
  Future<Map<String, dynamic>?> lisansBilgisiGetir() async {
    try {
      return await _lisansBilgisiGetirOnlineOrThrow();
    } catch (e) {
      debugPrint('Lisans Bilgisi Sorgulama Hatası: $e');
      return null;
    }
  }

  Future<ManualLisansUygulamaSonucu> manuelLisansKoduUygula(
    String rawToken,
  ) async {
    if (_hardwareId == null || _hardwareId!.trim().isEmpty) {
      _hardwareId = await _generateHardwareId();
    }

    final token = rawToken.trim();
    if (token.isEmpty) {
      return ManualLisansUygulamaSonucu.bosKod;
    }

    final tokenInfo = _parseLicenseProof(token);
    if (tokenInfo == null) {
      return ManualLisansUygulamaSonucu.gecersizKod;
    }

    final hardwareId = _hardwareId?.trim().toUpperCase() ?? '';
    if (hardwareId.isEmpty ||
        tokenInfo.hardwareId.trim().toUpperCase() != hardwareId) {
      return ManualLisansUygulamaSonucu.farkliCihaz;
    }

    if (_isLitePackageName(tokenInfo.packageName)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsLicenseKeyKey);
      _licenseKey = null;
      _isLicensed = false;
      _noOnlineLicenseLogged = false;
      await _setInheritedProLocal(false, notify: false);
      await _setLicenseEndDate(null);
      unawaited(_persistKasasiBestEffort(includeLicenseKey: false));
      notifyListeners();
      return ManualLisansUygulamaSonucu.litePaketeGecildi;
    }

    if (_isExpiredByDate(tokenInfo.expiryDate)) {
      return ManualLisansUygulamaSonucu.suresiDolmus;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLicenseKeyKey);
    final normalizedLicenseId = tokenInfo.licenseId?.trim().toUpperCase();
    await _applyManualActivationLocally(
      _LocalManualActivation(
        rawToken: token,
        tokenInfo: _LicenseTokenInfo(
          hardwareId: tokenInfo.hardwareId,
          licenseId:
              (normalizedLicenseId != null && normalizedLicenseId.isNotEmpty)
              ? normalizedLicenseId
              : (_licenseId ?? hardwareId),
          expiryDate: tokenInfo.expiryDate,
          packageName: tokenInfo.packageName,
          planCode: tokenInfo.planCode,
        ),
      ),
      notify: false,
      persist: true,
    );
    unawaited(_ensureProgramDenemeRowExistsBestEffort());
    if (_serverReachable == true) {
      unawaited(
        _syncOnlineRecoveryBestEffort(
          forceLiteSettingsSync: true,
          refreshGeo: true,
          forceStatusPush: true,
        ),
      );
    }
    notifyListeners();

    return ManualLisansUygulamaSonucu.basarili;
  }

  /// Lisans aktivasyonunu gerçekleştirir
  Future<bool> lisansla() async {
    if (_hardwareId == null) return false;
    final data = await lisansBilgisiGetir();
    if (data != null && data['license_key'] != null) {
      unawaited(
        _syncLosPayBalanceFromServerBestEffort(licenseData: data, force: true),
      );
      final key = data['license_key']?.toString() ?? '';
      final packageName = data['package_name']?.toString();
      final isLitePackage = _isLitePackageName(packageName);

      // İptal edilmiş mi kontrolü
      if (isLitePackage || key.isEmpty || key.startsWith('CANCELLED')) {
        return false;
      }

      final endDateRaw = data['end_date'];
      final parsedEndDate = endDateRaw != null
          ? DateTime.tryParse(endDateRaw.toString())
          : null;
      if (parsedEndDate != null) {
        await _setLicenseEndDate(parsedEndDate);
        if (_isExpiredByDate(parsedEndDate)) {
          // Süresi dolmuş lisans: LITE moda düş (veriler kalır, uygulama kapanmaz)
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_prefsLicenseKeyKey);
          _licenseKey = null;
          _isLicensed = false;
          unawaited(_persistKasasiBestEffort(includeLicenseKey: false));
          notifyListeners();
          debugPrint(
            'Lisans Servisi: Lisans süresi dolmuş. LITE sürüme düşüldü.',
          );
          return false;
        }
      }

      // Yerel olarak kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsLicenseKeyKey);
      _licenseKey = key;
      _isLicensed = true;
      unawaited(_persistKasasiBestEffort());
      notifyListeners();

      debugPrint('Lisans Servisi: Lisans başarıyla aktif edildi.');
      return true;
    }
    return false;
  }

  /// Geo Info Alır — Paralel çift kontrol + akıllı seçim
  Future<Map<String, String>> _getGeoInfo() async {
    // ──────────────────────────────────────────────────────────
    // Paralel: FreeIPAPI (en doğru) + ipwho.is (hızlı)
    // FreeIPAPI Türk ISP'lerde şehir seviyesinde doğru sonuç veriyor.
    // Test: 212.174.243.202 → FreeIPAPI=Niğde ✅, ipwho=Ankara ❌
    // ──────────────────────────────────────────────────────────
    try {
      final results = await Future.wait([_tryFreeIpApi(), _tryIpWhoIs()]);

      // FreeIPAPI başarılıysa onu tercih et (daha doğru)
      final freeIpResult = results[0];
      if (freeIpResult != null) return freeIpResult;

      // FreeIPAPI başarısızsa ipwho'ya düş
      final ipWhoResult = results[1];
      if (ipWhoResult != null) return ipWhoResult;
    } catch (e) {
      debugPrint('Geo Info Paralel Hatası: $e');
    }

    // ──── Fallback: sırayla dene ────

    // 3) ipapi.co
    try {
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ip = data['ip']?.toString();
        final city = data['city']?.toString();
        if (ip != null && ip.isNotEmpty) {
          return {
            'ip': ip,
            'city': city?.isNotEmpty == true ? city! : 'Unknown',
          };
        }
      }
    } catch (e) {
      debugPrint('Geo Info (ipapi.co) Hatası: $e');
    }

    // 4) ipinfo.io
    try {
      final response = await http
          .get(Uri.parse('https://ipinfo.io/json'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ip = data['ip']?.toString();
        final city = data['city']?.toString();
        if (ip != null && ip.isNotEmpty) {
          return {
            'ip': ip,
            'city': city?.isNotEmpty == true ? city! : 'Unknown',
          };
        }
      }
    } catch (e) {
      debugPrint('Geo Info (ipinfo.io) Hatası: $e');
    }

    return {'ip': 'Unknown', 'city': 'Unknown'};
  }

  /// FreeIPAPI — Türk ISP'lerde en doğru şehir tespiti
  Future<Map<String, String>?> _tryFreeIpApi() async {
    try {
      final response = await http
          .get(Uri.parse('https://freeipapi.com/api/json/'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ip = data['ipAddress']?.toString();
        final city = data['cityName']?.toString();
        if (ip != null && ip.isNotEmpty) {
          return {
            'ip': ip,
            'city': city?.isNotEmpty == true ? city! : 'Unknown',
          };
        }
      }
    } on HandshakeException {
      // Bazı ağlarda/operatörlerde bu endpoint TLS yönlendirmesi veya filtre nedeniyle
      // handshake hatası verebilir. Sessizce fallback'e düş.
    } on http.ClientException catch (e) {
      final msg = e.message.toLowerCase();
      final isTlsIssue =
          msg.contains('handshake') ||
          msg.contains('wrong_version_number') ||
          msg.contains('tls');
      if (isTlsIssue) return null;
      debugPrint('Geo Info (freeipapi) Hatası: $e');
    } on TimeoutException {
      // Sessizce fallback'e düş.
    } catch (e) {
      debugPrint('Geo Info (freeipapi) Hatası: $e');
    }
    return null;
  }

  /// ipwho.is — Hızlı, genel amaçlı
  Future<Map<String, String>?> _tryIpWhoIs() async {
    try {
      final response = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final ip = data['ip']?.toString();
          final city = data['city']?.toString();
          if (ip != null && ip.isNotEmpty) {
            return {
              'ip': ip,
              'city': city?.isNotEmpty == true ? city! : 'Unknown',
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Geo Info (ipwho) Hatası: $e');
    }
    return null;
  }
}

enum ManualLisansUygulamaSonucu {
  basarili,
  litePaketeGecildi,
  bosKod,
  gecersizKod,
  farkliCihaz,
  suresiDolmus,
}

class _LicenseTokenInfo {
  final String hardwareId;
  final String? licenseId;
  final DateTime expiryDate;
  final String? packageName;
  final String? planCode;

  const _LicenseTokenInfo({
    required this.hardwareId,
    required this.licenseId,
    required this.expiryDate,
    required this.packageName,
    required this.planCode,
  });
}

class _LocalManualActivation {
  final String rawToken;
  final _LicenseTokenInfo tokenInfo;

  const _LocalManualActivation({
    required this.rawToken,
    required this.tokenInfo,
  });
}

class _ProgramLisansDurumu {
  final String? status;
  final String? licenseId;

  const _ProgramLisansDurumu({required this.status, required this.licenseId});
}

class _HardwareIdentityResolution {
  final String rawId;

  const _HardwareIdentityResolution({required this.rawId});
}
