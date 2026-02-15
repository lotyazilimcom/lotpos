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
  Future<void> _kasasiYazmaZinciri = Future<void>.value();
  DateTime? _kasasiMaxSeenUtc;

  static const Duration _clockRollbackTolerance = Duration(minutes: 10);
  static const Duration _kasasiTouchInterval = Duration(minutes: 15);

  String get _vaultSecret => '$_licenseSecret|$_secKey|LOT-LICENSE-VAULT-V1';

  String? _hardwareId;
  bool _isLicensed = false;
  DateTime? _licenseEndDate;
  bool _isInitialized = false;
  bool? _lastOnlineStatus; // Durum önbelleği (Caching)
  bool _inheritedPro = false; // Sunucudan devralınan lisans durumu
  bool _noOnlineLicenseLogged = false;

  String? get hardwareId => _hardwareId;
  bool get isLicensed => _isLicensed || _inheritedPro;
  bool get isLiteMode => !isLicensed;
  bool get inheritedPro => _inheritedPro;
  DateTime? get licenseEndDate => _licenseEndDate;
  String? _licenseKey;
  String? get licenseKey => _licenseKey;

  static const String _prefsInheritedProKey = 'inherited_pro_status';
  static const String _prefsHardwareIdKey = 'patisyo_hardware_id_v1';

  /// Sunucudan devralınan lisans durumunu ayarlar
  Future<void> setInheritedPro(bool status) async {
    if (_inheritedPro == status) return;
    _inheritedPro = status;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsInheritedProKey, status);
    notifyListeners();
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

      // Açılışta lisansı doğrula:
      // - Online erişilebiliyorsa: sadece online kayıt belirleyicidir (yerel lisansa bakılmaz).
      // - Online erişilemiyorsa: yerel lisans (vault/prefs) ile devam edilir.
      await dogrula(onlineTimeout: const Duration(seconds: 4));

      // Lite ayar cache'ini yükle (offline-first)
      await LiteAyarlarServisi().baslat();

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

    // Admin panel görünürlüğü için cihaz kaydı (best-effort) + geo (best-effort)
    unawaited(_ensureProgramDenemeRowExistsBestEffort());
    unawaited(_updateGeoInfo());

    // Online işareti (best-effort)
    unawaited(durumGuncelle(true));
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

      await supabase
          .from('program_deneme')
          .update({
            'is_online': online,
            'machine_name': machineName,
            'last_activity': DateTime.now().toIso8601String(),
            'last_heartbeat': DateTime.now().toIso8601String(),
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

  /// Kalp Atışı (Heartbeat) Gönderir
  Future<void> heartbeatGonder() async {
    if (_hardwareId == null) return;
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('program_deneme')
          .update({
            'last_heartbeat': DateTime.now().toIso8601String(),
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
    // Perf: Donanım ID üretimi (device_info_plus/android_id) bazı cihazlarda pahalı olabiliyor.
    // Cache'lenmiş 8 haneli ID varsa direkt kullan (özellik/akış değiştirmeden).
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsHardwareIdKey);
      if (cached != null) {
        final normalized = cached.trim().toUpperCase();
        final isValid = RegExp(r'^[0-9A-F]{8}$').hasMatch(normalized);
        if (isValid) return normalized;
      }
    } catch (_) {
      // Cache okunamadıysa devam et.
    }

    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String rawId = '';
    bool cacheable = true;

    try {
      if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        // Windows için en benzersiz ve değişmeyen kimlik deviceId (GUID) dir.
        // Bilgisayar adı değişse bile bu ID değişmez.
        rawId = windowsInfo.deviceId;
      } else if (Platform.isMacOS) {
        final macOsInfo = await deviceInfo.macOsInfo;
        rawId = macOsInfo.systemGUID ?? macOsInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        rawId = linuxInfo.machineId ?? linuxInfo.name;
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

        rawId = 'ANDROID:${androidId ?? fallbackId}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final idfv = iosInfo.identifierForVendor;
        final machine = iosInfo.utsname.machine;
        rawId = 'IOS:${idfv ?? machine}';
      } else {
        rawId = 'GENERIC-DEVICE';
      }
    } catch (e) {
      debugPrint('Hardware ID Üretim Hatası: $e');
      rawId = 'ERROR-DEVICE-${DateTime.now().millisecondsSinceEpoch}';
      cacheable = false;
    }

    var bytes = utf8.encode(rawId);
    var digest = sha256.convert(bytes);
    // 8 haneli ID çakışma ihtimalini trilyonda bire düşürür
    final hardwareId = digest.toString().substring(0, 8).toUpperCase();

    if (cacheable) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsHardwareIdKey, hardwareId);
      } catch (_) {
        // Cache yazılamazsa sorun değil.
      }
    }

    return hardwareId;
  }

  /// Cihaz adını alır (Supabase'de görünmesi için)
  Future<String> _getMachineName() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isWindows) {
        return (await deviceInfo.windowsInfo).computerName;
      } else if (Platform.isMacOS) {
        return (await deviceInfo.macOsInfo).computerName;
      } else if (Platform.isLinux) {
        return (await deviceInfo.linuxInfo).name;
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

    final tokenInfo = _verifyAndParseLicenseToken(localKey);
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
      // Online-first: Supabase'e erişilebiliyorsa yerel lisans dikkate alınmaz.
      // Online sorgu başarıyla dönüp kayıt yoksa (silinmişse) cihaz direkt LITE'a düşer.
      final data = await _lisansBilgisiGetirOnlineOrThrow(timeout: onlineTimeout);

      if (data == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefsLicenseKeyKey);
        _licenseKey = null;
        _isLicensed = false;
        await _setLicenseEndDate(null);
        notifyListeners();
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

      final key = data['license_key']?.toString() ?? '';
      final isCancelled = key.startsWith('CANCELLED');

      final endDateRaw = data['end_date'];
      final parsedEndDate = endDateRaw != null
          ? DateTime.tryParse(endDateRaw.toString())
          : null;

      if (parsedEndDate != null) {
        await _setLicenseEndDate(parsedEndDate);
      }

      if (isCancelled || key.trim().isEmpty) {
        if (_licenseKey != null || _isLicensed) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_prefsLicenseKeyKey);
          _licenseKey = null;
          _isLicensed = false;
          unawaited(_persistKasasiBestEffort(includeLicenseKey: false));
          notifyListeners();
        }
        return _isLicensed;
      }

      if (parsedEndDate != null && _isExpiredByDate(parsedEndDate)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefsLicenseKeyKey);
        _licenseKey = null;
        _isLicensed = false;
        unawaited(_persistKasasiBestEffort(includeLicenseKey: false));
        notifyListeners();
        return _isLicensed;
      }

      // PRO (aktif lisans)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsLicenseKeyKey);
      _licenseKey = key;
      _isLicensed = true;
      unawaited(_persistKasasiBestEffort());
      notifyListeners();
      return _isLicensed;
    } catch (e) {
      // Online doğrulama başarısız; yerel lisans ile devam.
      debugPrint('Lisans Servisi: Online doğrulama başarısız, yerel lisansa düşülüyor: $e');
      await _checkLicenseStatus();
      return _isLicensed;
    } finally {
      unawaited(_ensureProgramDenemeRowExistsBestEffort());
    }
  }

  Future<void> _ensureProgramDenemeRowExistsBestEffort() async {
    if (_hardwareId == null) return;

    final supabase = Supabase.instance.client;
    final machineName = await _getMachineName();
    final now = DateTime.now().toIso8601String();
    final desiredStatus = isLicensed ? 'converted' : 'active';
    final hid = _hardwareId!;

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

      try {
        await supabase.from('program_deneme').insert(payload);
      } on PostgrestException catch (e) {
        final msg = (e.message).toLowerCase();
        final statusColumnMissing =
            msg.contains('status') && (msg.contains('column') || msg.contains('schema'));
        if (!statusColumnMissing) rethrow;

        // Eski şemalarda `status` sütunu yoksa insert'i status olmadan tekrar dene.
        await supabase.from('program_deneme').insert({
          'hardware_id': hid,
          'machine_name': machineName,
          'install_date': now,
          'last_activity': now,
          'is_online': true,
          'last_heartbeat': now,
        });
      }
      debugPrint('Lisans Servisi: program_deneme cihaz kaydı oluşturuldu.');
    } on PostgrestException catch (e) {
      final msg = (e.message).toLowerCase();
      final isDuplicate = msg.contains('duplicate') || msg.contains('unique');
      if (!isDuplicate) {
        debugPrint('program_deneme insert hatası: $e');
        return;
      }

      try {
        final updatePayload = {
          'machine_name': machineName,
          'last_activity': now,
          'is_online': true,
          'last_heartbeat': now,
          'status': desiredStatus,
        };

        try {
          await supabase
              .from('program_deneme')
              .update(updatePayload)
              .eq('hardware_id', hid);
        } on PostgrestException catch (e2) {
          final msg2 = (e2.message).toLowerCase();
          final statusColumnMissing = msg2.contains('status') &&
              (msg2.contains('column') || msg2.contains('schema'));
          if (!statusColumnMissing) rethrow;

          // Eski şemalarda `status` sütunu yoksa status olmadan güncelle.
          await supabase
              .from('program_deneme')
              .update({
                'machine_name': machineName,
                'last_activity': now,
                'is_online': true,
                'last_heartbeat': now,
              })
              .eq('hardware_id', hid);
        }
      } catch (e2) {
        debugPrint('program_deneme update hatası: $e2');
      }
    } catch (e) {
      debugPrint('program_deneme ensure hatası: $e');
    }
  }

  Future<void> _updateGeoInfo() async {
    if (_hardwareId == null) return;
    try {
      final geoInfo = await _getGeoInfo();
      if (geoInfo['ip'] == null || geoInfo['city'] == null) return;

      final ip = geoInfo['ip']!;
      final city = geoInfo['city']!;
      if (ip == 'Unknown' && city == 'Unknown') return;

      final supabase = Supabase.instance.client;
      await supabase
          .from('program_deneme')
          .update({'ip_address': ip, 'city': city})
          .eq('hardware_id', _hardwareId!);
    } catch (e) {
      debugPrint('Geo Info Güncelleme Hatası: $e');
    }
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
      final expiryStr = decoded['expiry_date']?.toString();
      if (hardwareId == null || expiryStr == null) return null;

      final expiry = DateTime.tryParse(expiryStr);
      if (expiry == null) return null;

      final expiryDateOnly = DateTime(expiry.year, expiry.month, expiry.day);
      return _LicenseTokenInfo(
        hardwareId: hardwareId,
        expiryDate: expiryDateOnly,
      );
    } catch (_) {
      return null;
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
  }) async {
    if (_hardwareId == null) return null;
    final supabase = Supabase.instance.client;
    final data = await supabase
        .from('licenses')
        .select()
        .eq('hardware_id', _hardwareId!)
        .order('end_date', ascending: false)
        .limit(1)
        .maybeSingle()
        .timeout(timeout);
    return data;
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

  /// Lisans aktivasyonunu gerçekleştirir
  Future<bool> lisansla() async {
    if (_hardwareId == null) return false;
    final data = await lisansBilgisiGetir();
    if (data != null && data['license_key'] != null) {
      final key = data['license_key']?.toString() ?? '';

      // İptal edilmiş mi kontrolü
      if (key.isEmpty || key.startsWith('CANCELLED')) {
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

  /// Geo Info Alır
  Future<Map<String, String>> _getGeoInfo() async {
    // 1) ipwho.is (anahtar istemez, hızlı)
    try {
      final response = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final success = data['success'] == true;
        if (success) {
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

    // 2) ipapi.co (hızlı, basit)
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
      debugPrint('Geo Info Hatası: $e');
    }

    // 3) ipinfo.io (rate-limited olabilir)
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
      debugPrint('Geo Info Fallback Hatası: $e');
    }

    // 4) FreeIPAPI (bazı ağlarda/operatörlerde engellenebiliyor; en sona alındı)
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
    } catch (_) {
      // En sonda olduğundan sessizce yut (log spam/jank istemiyoruz).
    }
    return {'ip': 'Unknown', 'city': 'Unknown'};
  }
}

class _LicenseTokenInfo {
  final String hardwareId;
  final DateTime expiryDate;

  const _LicenseTokenInfo({required this.hardwareId, required this.expiryDate});
}
