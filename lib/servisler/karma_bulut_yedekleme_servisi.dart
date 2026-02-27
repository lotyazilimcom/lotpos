import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lisans_servisi.dart';
import 'lite_kisitlari.dart';
import 'online_veritabani_servisi.dart';
import 'oturum_servisi.dart';
import 'veritabani_aktarim_servisi.dart';
import 'veritabani_yapilandirma.dart';

class KarmaBulutYedeklemeServisi extends ChangeNotifier {
  static final KarmaBulutYedeklemeServisi _instance =
      KarmaBulutYedeklemeServisi._internal();
  factory KarmaBulutYedeklemeServisi() => _instance;
  KarmaBulutYedeklemeServisi._internal();

  // Bu ayarlar "Veritabanı / Yedek Ayarları" sayfasındaki UI ile eşleşir.
  static const String prefBackupEnabledKey = 'patisyo_cloud_backup_enabled';
  static const String prefBackupPeriodKey = 'patisyo_cloud_backup_period';

  // Telemetry (yerel): kullanıcıya göstermeden güvenli planlama için.
  static const String _prefLastSuccessAtKey =
      'patisyo_cloud_backup_last_success_at';
  static const String _prefLastDeltaSuccessAtKey =
      'patisyo_cloud_backup_last_delta_success_at';
  static const String _prefLastCloudPullSuccessAtKey =
      'patisyo_cloud_backup_last_cloud_pull_success_at';
  static const String _prefLastRequestAtKey =
      'patisyo_cloud_backup_last_request_at';

  // Hybrid modda, cloud kimlikleri sonradan hazır olursa kullanıcıdan aktarım
  // seçimi (merge/full/none) istemek için UI tetikleyicisi.
  static final ValueNotifier<int> hybridSeedChoicePromptTick =
      ValueNotifier<int>(0);

  Timer? _timer;
  bool _started = false;
  bool _inFlight = false;
  int _consecutiveFailures = 0;
  DateTime? _lastTickAt;

  static const Duration _cloudHealthCacheTtl = Duration(seconds: 30);
  DateTime? _lastCloudHealthCheckAt;
  bool _lastCloudHealthOk = false;

  String? _lastError;
  String? get lastError => _lastError;
  bool get started => _started;
  bool get inFlight => _inFlight;
  int get consecutiveFailures => _consecutiveFailures;
  DateTime? get lastTickAt => _lastTickAt;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('KarmaYedek: $message');
    }
  }

  Future<void> baslat() async {
    if (_started) return;
    _started = true;
    _schedule(const Duration(seconds: 2));
  }

  void durdur() {
    _started = false;
    _timer?.cancel();
    _timer = null;
    _consecutiveFailures = 0;
    _lastError = null;
    _lastTickAt = null;
    _lastCloudHealthCheckAt = null;
    _lastCloudHealthOk = false;
  }

  Future<void> ayarlariUygulaVeBaslat() async {
    final shouldRun = await _shouldRunNow();
    if (!shouldRun) {
      durdur();
      return;
    }
    await baslat();
  }

  Future<void> tetikle({bool force = false}) async {
    if (!_started) {
      await baslat();
    }
    _schedule(force ? Duration.zero : const Duration(seconds: 2));
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    if (!_started) return;
    _timer = Timer(delay, () => unawaited(_tick()));
  }

  Future<bool> _shouldRunNow() async {
    // Yedekleme sadece Karma (Yerel+Bulut) modda çalışır.
    if (VeritabaniYapilandirma.connectionMode != 'hybrid') return false;

    // LITE kısıtları: bulut/hibrit yedek kapalıysa servis tamamen kapansın.
    if (LiteKisitlari.isLiteMode && !LiteKisitlari.isCloudBackupActive) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(prefBackupEnabledKey) ?? true;
    if (!enabled) return false;
    return true;
  }

  Duration _periodToDuration(String period) {
    switch (period.trim()) {
      case 'monthly':
        return const Duration(days: 30);
      case '3months':
        return const Duration(days: 90);
      case '6months':
        return const Duration(days: 180);
      case '15days':
      default:
        return const Duration(days: 15);
    }
  }

  Future<DateTime?> _getLastSuccessAt(SharedPreferences prefs) async {
    final raw = (prefs.getString(_prefLastSuccessAtKey) ?? '').trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _setLastSuccessAt(SharedPreferences prefs, DateTime at) async {
    await prefs.setString(_prefLastSuccessAtKey, at.toIso8601String());
  }

  DateTime? _getLastDeltaSuccessAt(SharedPreferences prefs) {
    final raw = (prefs.getString(_prefLastDeltaSuccessAtKey) ?? '').trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _setLastDeltaSuccessAt(
    SharedPreferences prefs,
    DateTime at,
  ) async {
    await prefs.setString(_prefLastDeltaSuccessAtKey, at.toIso8601String());
  }

  DateTime? _getLastCloudPullSuccessAt(SharedPreferences prefs) {
    final raw = (prefs.getString(_prefLastCloudPullSuccessAtKey) ?? '').trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _setLastCloudPullSuccessAt(
    SharedPreferences prefs,
    DateTime at,
  ) async {
    await prefs.setString(_prefLastCloudPullSuccessAtKey, at.toIso8601String());
  }

  DateTime? _getLastRequestAt(SharedPreferences prefs) {
    final raw = (prefs.getString(_prefLastRequestAtKey) ?? '').trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _setLastRequestAt(SharedPreferences prefs, DateTime at) async {
    await prefs.setString(_prefLastRequestAtKey, at.toIso8601String());
  }

  Future<void> _ensureSupabaseInitialized() async {
    try {
      await Supabase.initialize(url: LisansServisi.u, anonKey: LisansServisi.k);
    } catch (_) {
      // Zaten başlatılmış olabilir.
    }
  }

  Future<bool> _ensureCloudCredentialsReadyBestEffort({
    required SharedPreferences prefs,
    required String requestSource,
  }) async {
    if (VeritabaniYapilandirma.cloudCredentialsReady) {
      final now = DateTime.now();
      final last = _lastCloudHealthCheckAt;
      if (last != null && now.difference(last) < _cloudHealthCacheTtl) {
        return _lastCloudHealthOk;
      }
      final ok = await VeritabaniYapilandirma.testSavedCloudDatabaseConnection(
        timeout: const Duration(seconds: 6),
      );
      _lastCloudHealthCheckAt = now;
      _lastCloudHealthOk = ok;
      return ok;
    }

    await _ensureSupabaseInitialized();
    try {
      await LisansServisi().baslat();
    } catch (_) {}

    final hw = (LisansServisi().hardwareId ?? '').trim();
    if (hw.isEmpty) return false;

    // Admin panel görünürlüğü için talep gönder (spam korumalı).
    final now = DateTime.now();
    final lastReq = _getLastRequestAt(prefs);
    final shouldSend =
        lastReq == null || now.difference(lastReq) > const Duration(minutes: 30);
    if (shouldSend) {
      await OnlineVeritabaniServisi().talepGonder(
        hardwareId: hw,
        source: requestSource,
      );
      await _setLastRequestAt(prefs, now);
    }

    final creds = await OnlineVeritabaniServisi().kimlikleriGetir(hw);
    if (creds == null) return false;

    await VeritabaniYapilandirma.saveCloudDatabaseCredentials(
      host: creds.host,
      port: creds.port,
      username: creds.username,
      password: creds.password,
      database: creds.database,
      sslRequired: creds.sslRequired,
    );

    if (!VeritabaniYapilandirma.cloudCredentialsReady) return false;
    final checkedAt = DateTime.now();
    final ok = await VeritabaniYapilandirma.testSavedCloudDatabaseConnection(
      timeout: const Duration(seconds: 8),
    );
    _lastCloudHealthCheckAt = checkedAt;
    _lastCloudHealthOk = ok;
    return ok;
  }

  bool _pendingSeedNeedsChoice({
    required VeritabaniAktarimNiyeti? niyet,
    required String? savedChoice,
  }) {
    if (niyet == null) return false;
    final from = niyet.fromMode.trim();
    final to = niyet.toMode.trim();
    if (!(from == 'local' && to == 'cloud')) return false;
    final choice = (savedChoice ?? '').trim().toLowerCase();
    if (choice == 'merge' || choice == 'full' || choice == 'none') return false;
    return true;
  }

  VeritabaniAktarimTipi? _choiceToTransferType(String choice) {
    final v = choice.trim().toLowerCase();
    if (v == 'merge') return VeritabaniAktarimTipi.birlestir;
    if (v == 'full') return VeritabaniAktarimTipi.tamAktar;
    return null;
  }

  Duration _failureBackoffDelay() {
    // 1) 30s, 2) 1m, 3) 2m, 4) 5m, 5+) 10m
    final n = _consecutiveFailures;
    if (n <= 0) return const Duration(seconds: 30);
    if (n == 1) return const Duration(minutes: 1);
    if (n == 2) return const Duration(minutes: 2);
    if (n == 3) return const Duration(minutes: 5);
    return const Duration(minutes: 10);
  }

  Future<void> _tick() async {
    if (!_started) return;

    final shouldRun = await _shouldRunNow();
    if (!shouldRun) {
      durdur();
      return;
    }

    if (_inFlight) {
      _schedule(const Duration(seconds: 3));
      return;
    }

    final now = DateTime.now();
    final lastAttempt = _lastTickAt;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(seconds: 2)) {
      _schedule(const Duration(seconds: 2));
      return;
    }

    _inFlight = true;
    _lastTickAt = now;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cloudReady = await _ensureCloudCredentialsReadyBestEffort(
        prefs: prefs,
        requestSource: 'hybrid_backup',
      );
      if (!cloudReady) {
        _consecutiveFailures++;
        _lastError = 'Cloud credentials not ready';
        notifyListeners();
        _schedule(_failureBackoffDelay());
        return;
      }

      final aktarim = VeritabaniAktarimServisi();
      final niyet = await aktarim.niyetOku();
      final savedChoice = prefs.getString(
        VeritabaniYapilandirma.prefPendingTransferChoiceKey,
      );

      if (_pendingSeedNeedsChoice(niyet: niyet, savedChoice: savedChoice)) {
        // UI tarafı bu tick'i dinleyip dialog açacak.
        hybridSeedChoicePromptTick.value =
            hybridSeedChoicePromptTick.value + 1;
        _schedule(const Duration(minutes: 2));
        return;
      }

      // 1) Öncelik: bekleyen local->cloud seed niyeti varsa onu çalıştır (merge/full).
      if (niyet != null &&
          niyet.fromMode.trim() == 'local' &&
          niyet.toMode.trim() == 'cloud') {
        final choice = (savedChoice ?? '').trim().toLowerCase();
        if (choice == 'none') {
          // Kullanıcı açıkça "dokunma" dedi: Karma modda buluta hiçbir veri gönderme.
          // (Delta sync altyapısı devreye girene kadar en güvenli davranış: otomatik yedeği kapat.)
          await prefs.setBool(prefBackupEnabledKey, false);
          await prefs.remove(VeritabaniYapilandirma.prefPendingTransferChoiceKey);
          await aktarim.niyetTemizle();
          _consecutiveFailures = 0;
          _lastError = null;
          notifyListeners();
          durdur();
          return;
        }

        final tip = _choiceToTransferType(choice);
        if (tip == null) {
          // Bu noktaya normalde düşmemeli (prompt tick daha önce).
          _schedule(const Duration(minutes: 2));
          return;
        }

        _log('Seed start (hybrid): local -> cloud, tip=$choice');
        final hazirlik = await aktarim.hazirlikYap(niyet: niyet);
        if (hazirlik == null) {
          _consecutiveFailures++;
          _lastError = 'Seed preparation failed (hazirlik=null)';
          notifyListeners();
          _schedule(_failureBackoffDelay());
          return;
        }

        await aktarim.aktarimYap(hazirlik: hazirlik, tip: tip);
        await aktarim.niyetTemizle();
        await prefs.remove(VeritabaniYapilandirma.prefPendingTransferChoiceKey);
        await _setLastSuccessAt(prefs, DateTime.now());
        await _setLastDeltaSuccessAt(prefs, DateTime.now());
        _consecutiveFailures = 0;
        _lastError = null;
        notifyListeners();
        _schedule(const Duration(seconds: 4));
        return;
      }

      // 2) Delta sync: Yerelde değişiklik olduysa buluta anında gönder (best-effort, upsert).
      final localHost =
          (VeritabaniYapilandirma.discoveredHost ?? '127.0.0.1').trim();
      final localCompanyDb = OturumServisi().aktifVeritabaniAdi;

      final lastDelta = _getLastDeltaSuccessAt(prefs);
      final lastFull = await _getLastSuccessAt(prefs);
      final baseline =
          lastDelta ?? lastFull ?? DateTime.now().subtract(const Duration(minutes: 5));

      final deltaReport = await aktarim.deltaSenkronYerelBulut(
        localHost: localHost.isEmpty ? '127.0.0.1' : localHost,
        localCompanyDb: localCompanyDb,
        since: baseline,
      );

      if (deltaReport.tabloSayisi > 0) {
        await _setLastDeltaSuccessAt(prefs, DateTime.now());
      }

      // 3) Delta pull: Bulutta değişiklik olduysa yerele anında indir (best-effort, upsert).
      final lastPull = _getLastCloudPullSuccessAt(prefs);
      final pullBaseline =
          lastPull ?? DateTime.now().subtract(const Duration(minutes: 5));

      final pullReport = await aktarim.deltaSenkronBulutYerel(
        localHost: localHost.isEmpty ? '127.0.0.1' : localHost,
        localCompanyDb: localCompanyDb,
        since: pullBaseline,
      );

      if (pullReport.tabloSayisi > 0) {
        await _setLastCloudPullSuccessAt(prefs, DateTime.now());
      }

      // 4) Periyodik bulut yedekleme: due ise merge transfer çalıştır.
      final enabled = prefs.getBool(prefBackupEnabledKey) ?? true;
      if (!enabled) {
        _consecutiveFailures = 0;
        _lastError = null;
        notifyListeners();
        _schedule(const Duration(seconds: 10));
        return;
      }

      final period = prefs.getString(prefBackupPeriodKey) ?? '15days';
      final interval = _periodToDuration(period);
      final lastSuccess = await _getLastSuccessAt(prefs);
      final dueAt = lastSuccess?.add(interval);
      final now = DateTime.now();

      final isDue = dueAt == null || now.isAfter(dueAt);
      if (!isDue) {
        _consecutiveFailures = 0;
        _lastError = null;
        notifyListeners();
        _schedule(const Duration(seconds: 3));
        return;
      }

      // Backup niyeti (UI'ı bloklamadan).
      final backupNiyet = VeritabaniAktarimNiyeti(
        fromMode: 'local',
        toMode: 'cloud',
        localHost: localHost,
        localCompanyDb: localCompanyDb,
        createdAt: DateTime.now(),
      );

      _log('Backup start (hybrid): local -> cloud, period=$period');
      final hazirlik = await aktarim.hazirlikYap(niyet: backupNiyet);
      if (hazirlik == null) {
        _consecutiveFailures++;
        _lastError = 'Backup preparation failed (hazirlik=null)';
        notifyListeners();
        _schedule(_failureBackoffDelay());
        return;
      }

      await aktarim.aktarimYap(
        hazirlik: hazirlik,
        tip: VeritabaniAktarimTipi.birlestir,
      );

      await _setLastSuccessAt(prefs, DateTime.now());
      _consecutiveFailures = 0;
      _lastError = null;
      notifyListeners();
      _schedule(const Duration(seconds: 6));
    } catch (e) {
      _consecutiveFailures++;
      _lastError = e.toString();
      notifyListeners();
      _schedule(_failureBackoffDelay());
    } finally {
      _inFlight = false;
    }
  }
}
