import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiteAyarlar {
  final int maxCurrentAccounts;
  final int maxDailyTransactions;
  final int maxDailyRetailSales;
  final int reportDaysLimit;
  final bool isBankCreditActive;
  final bool isCheckPromissoryActive;
  final bool isCloudBackupActive;
  final bool isExcelExportActive;
  final DateTime? updatedAtUtc;

  const LiteAyarlar({
    required this.maxCurrentAccounts,
    required this.maxDailyTransactions,
    required this.maxDailyRetailSales,
    required this.reportDaysLimit,
    required this.isBankCreditActive,
    required this.isCheckPromissoryActive,
    required this.isCloudBackupActive,
    required this.isExcelExportActive,
    this.updatedAtUtc,
  });

  static const LiteAyarlar defaults = LiteAyarlar(
    maxCurrentAccounts: 20,
    maxDailyTransactions: 50,
    maxDailyRetailSales: 65,
    reportDaysLimit: 7,
    isBankCreditActive: false,
    isCheckPromissoryActive: false,
    isCloudBackupActive: false,
    isExcelExportActive: false,
    updatedAtUtc: null,
  );

  static int _toInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static bool _toBool(dynamic value, bool fallback) {
    if (value == null) return fallback;
    if (value is bool) return value;
    final v = value.toString().toLowerCase().trim();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no') return false;
    return fallback;
  }

  static DateTime? _toDateTimeUtc(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    final parsed = DateTime.tryParse(value.toString());
    return parsed?.toUtc();
  }

  factory LiteAyarlar.fromMap(Map<String, dynamic> map) {
    return LiteAyarlar(
      maxCurrentAccounts:
          _toInt(map['max_current_accounts'], LiteAyarlar.defaults.maxCurrentAccounts),
      maxDailyTransactions:
          _toInt(map['max_daily_transactions'], LiteAyarlar.defaults.maxDailyTransactions),
      maxDailyRetailSales:
          _toInt(map['max_daily_retail_sales'], LiteAyarlar.defaults.maxDailyRetailSales),
      reportDaysLimit:
          _toInt(map['report_days_limit'], LiteAyarlar.defaults.reportDaysLimit),
      isBankCreditActive:
          _toBool(map['is_bank_credit_active'], LiteAyarlar.defaults.isBankCreditActive),
      isCheckPromissoryActive: _toBool(
        map['is_check_promissory_active'],
        LiteAyarlar.defaults.isCheckPromissoryActive,
      ),
      isCloudBackupActive:
          _toBool(map['is_cloud_backup_active'], LiteAyarlar.defaults.isCloudBackupActive),
      isExcelExportActive:
          _toBool(map['is_excel_export_active'], LiteAyarlar.defaults.isExcelExportActive),
      updatedAtUtc: _toDateTimeUtc(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'max_current_accounts': maxCurrentAccounts,
      'max_daily_transactions': maxDailyTransactions,
      'max_daily_retail_sales': maxDailyRetailSales,
      'report_days_limit': reportDaysLimit,
      'is_bank_credit_active': isBankCreditActive,
      'is_check_promissory_active': isCheckPromissoryActive,
      'is_cloud_backup_active': isCloudBackupActive,
      'is_excel_export_active': isExcelExportActive,
      'updated_at': updatedAtUtc?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is LiteAyarlar &&
        other.maxCurrentAccounts == maxCurrentAccounts &&
        other.maxDailyTransactions == maxDailyTransactions &&
        other.maxDailyRetailSales == maxDailyRetailSales &&
        other.reportDaysLimit == reportDaysLimit &&
        other.isBankCreditActive == isBankCreditActive &&
        other.isCheckPromissoryActive == isCheckPromissoryActive &&
        other.isCloudBackupActive == isCloudBackupActive &&
        other.isExcelExportActive == isExcelExportActive &&
        other.updatedAtUtc == updatedAtUtc;
  }

  @override
  int get hashCode => Object.hash(
        maxCurrentAccounts,
        maxDailyTransactions,
        maxDailyRetailSales,
        reportDaysLimit,
        isBankCreditActive,
        isCheckPromissoryActive,
        isCloudBackupActive,
        isExcelExportActive,
        updatedAtUtc,
      );
}

/// Lite sürüm kısıtlamaları için online (Supabase) konfigürasyon + offline cache.
///
/// - İnternet yoksa: `LiteAyarlar.defaults` veya cache kullanılır.
/// - İnternet varsa: `lite_settings(id=1)` satırı çekilir ve cache güncellenir.
class LiteAyarlarServisi extends ChangeNotifier {
  static final LiteAyarlarServisi _instance = LiteAyarlarServisi._internal();
  factory LiteAyarlarServisi() => _instance;
  LiteAyarlarServisi._internal();

  static const String _prefsCacheKey = 'lite_settings_cache_v1';

  bool _initialized = false;
  LiteAyarlar _ayarlar = LiteAyarlar.defaults;

  DateTime? _lastSyncAttemptUtc;
  DateTime? _lastSyncSuccessUtc;
  Future<void>? _syncInFlight;

  LiteAyarlar get ayarlar => _ayarlar;
  DateTime? get lastSyncSuccessUtc => _lastSyncSuccessUtc;

  int get maxCurrentAccounts => _ayarlar.maxCurrentAccounts;
  int get maxDailyTransactions => _ayarlar.maxDailyTransactions;
  int get maxDailyRetailSales => _ayarlar.maxDailyRetailSales;
  int get reportDaysLimit => _ayarlar.reportDaysLimit;
  bool get isBankCreditActive => _ayarlar.isBankCreditActive;
  bool get isCheckPromissoryActive => _ayarlar.isCheckPromissoryActive;
  bool get isCloudBackupActive => _ayarlar.isCloudBackupActive;
  bool get isExcelExportActive => _ayarlar.isExcelExportActive;

  Future<void> baslat() async {
    if (_initialized) return;
    await _loadFromPrefsBestEffort();
    _initialized = true;
  }

  Future<void> _loadFromPrefsBestEffort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsCacheKey);
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      final map = decoded.cast<String, dynamic>();
      _ayarlar = LiteAyarlar.fromMap(map);
      notifyListeners();
    } catch (e) {
      debugPrint('Lite Ayarlar: Cache okuma hatası: $e');
    }
  }

  Future<void> _saveToPrefsBestEffort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsCacheKey, jsonEncode(_ayarlar.toMap()));
    } catch (e) {
      debugPrint('Lite Ayarlar: Cache yazma hatası: $e');
    }
  }

  Future<void> senkronizeBestEffort({
    bool force = false,
    Duration minInterval = const Duration(minutes: 5),
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      await senkronize(force: force, minInterval: minInterval, timeout: timeout);
    } catch (_) {}
  }

  Future<LiteAyarlar> senkronize({
    bool force = false,
    Duration minInterval = const Duration(minutes: 5),
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (!_initialized) await baslat();

    final inFlight = _syncInFlight;
    if (inFlight != null) {
      await inFlight;
      return _ayarlar;
    }

    final now = DateTime.now().toUtc();
    final lastAttempt = _lastSyncAttemptUtc;
    if (!force && lastAttempt != null && now.difference(lastAttempt) < minInterval) {
      return _ayarlar;
    }

    final completer = Completer<void>();
    _syncInFlight = completer.future;
    _lastSyncAttemptUtc = now;

    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('lite_settings')
          .select()
          .eq('id', 1)
          .maybeSingle()
          .timeout(timeout);

      if (data == null) return _ayarlar;

      final next = LiteAyarlar.fromMap(data);
      if (next != _ayarlar) {
        _ayarlar = next;
        notifyListeners();
      }

      _lastSyncSuccessUtc = now;
      await _saveToPrefsBestEffort();
      return _ayarlar;
    } catch (e) {
      debugPrint('Lite Ayarlar: Senkron hatası: $e');
      return _ayarlar;
    } finally {
      completer.complete();
      _syncInFlight = null;
    }
  }
}

