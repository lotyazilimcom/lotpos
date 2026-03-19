import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnlineVeritabaniKimlikleri {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final bool sslRequired;
  final String? apiBaseUrl;
  final String? apiReadBaseUrl;
  final String? apiWriteBaseUrl;
  final String? apiToken;

  const OnlineVeritabaniKimlikleri({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    required this.sslRequired,
    required this.apiBaseUrl,
    required this.apiReadBaseUrl,
    required this.apiWriteBaseUrl,
    required this.apiToken,
  });

  factory OnlineVeritabaniKimlikleri.fromMap(Map<String, dynamic> row) {
    String? normUrl(Object? v) {
      final s = (v as String?)?.trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    final apiBaseUrl = normUrl(row['api_base_url']);
    final apiReadBaseUrl =
        normUrl(row['api_read_base_url']) ?? normUrl(row['api_read_url']);
    final apiWriteBaseUrl =
        normUrl(row['api_write_base_url']) ?? normUrl(row['api_write_url']);
    final apiToken = (row['api_token'] as String?)?.trim();
    return OnlineVeritabaniKimlikleri(
      host: (row['db_host'] as String?)?.trim() ?? '',
      port: (row['db_port'] as num?)?.toInt() ?? 5432,
      database: (row['db_name'] as String?)?.trim() ?? '',
      username: (row['db_user'] as String?)?.trim() ?? '',
      password: (row['db_password'] as String?)?.trim() ?? '',
      // Cloud PG genelde SSL ister; alan yoksa/boşsa varsayılanı "true" kabul et.
      sslRequired: row['ssl_required'] == false ? false : true,
      apiBaseUrl: apiBaseUrl,
      apiReadBaseUrl: apiReadBaseUrl,
      apiWriteBaseUrl: apiWriteBaseUrl,
      apiToken: (apiToken == null || apiToken.isEmpty) ? null : apiToken,
    );
  }

  bool get isValidDb =>
      host.isNotEmpty &&
      database.isNotEmpty &&
      username.isNotEmpty &&
      password.isNotEmpty;

  bool get isValidApi {
    final url = (apiWriteBaseUrl ?? apiBaseUrl ?? apiReadBaseUrl ?? '').trim();
    final db = database.trim();
    final token = (apiToken ?? '').trim();
    return url.isNotEmpty && db.isNotEmpty && token.isNotEmpty;
  }

  bool get isValid => isValidApi || isValidDb;
}

class OnlineVeritabaniCihazBilgisi {
  final String hardwareId;
  final String? machineName;

  const OnlineVeritabaniCihazBilgisi({
    required this.hardwareId,
    required this.machineName,
  });

  factory OnlineVeritabaniCihazBilgisi.fromMap(Map<String, dynamic> row) {
    final hw = (row['hardware_id'] as String?)?.trim() ?? '';
    final mn = (row['machine_name'] as String?)?.trim();
    return OnlineVeritabaniCihazBilgisi(
      hardwareId: hw,
      machineName: (mn == null || mn.isEmpty) ? null : mn,
    );
  }

  String get displayName {
    final mn = machineName?.trim();
    if (mn != null && mn.isNotEmpty) return mn;
    return hardwareId;
  }
}

class OnlineVeritabaniServisi {
  static final OnlineVeritabaniServisi _instance =
      OnlineVeritabaniServisi._internal();
  factory OnlineVeritabaniServisi() => _instance;
  OnlineVeritabaniServisi._internal();

  /// Bir Lisans Kimliği'ne (License ID) bağlı cihazların bilgilerini döner.
  ///
  /// - Yeni şemada: `program_deneme.license_id` üzerinden gruplar.
  /// - Geriye dönük: Kullanıcı eski sürümden "hardware_id" paylaştıysa, onu da kabul eder.
  Future<List<OnlineVeritabaniCihazBilgisi>> cihazBilgileriGetirByLisansKimligi(
    String licenseId,
  ) async {
    final normalized = licenseId.trim().toUpperCase();
    if (normalized.isEmpty) return const [];

    final client = Supabase.instance.client;
    final Map<String, OnlineVeritabaniCihazBilgisi> result = {};

    // Backward-compatible: allow direct hardware_id lookup.
    try {
      final row = await client
          .from('program_deneme')
          .select('hardware_id, machine_name')
          .eq('hardware_id', normalized)
          .maybeSingle();
      if (row is Map<String, dynamic>) {
        final info = OnlineVeritabaniCihazBilgisi.fromMap(row);
        if (info.hardwareId.isNotEmpty) result[info.hardwareId] = info;
      }
    } on PostgrestException catch (e) {
      final msg = (e.message).toLowerCase();
      final machineNameColumnMissing =
          msg.contains('machine_name') &&
          (msg.contains('column') || msg.contains('schema'));
      if (!machineNameColumnMissing) {
        debugPrint(
          'OnlineVeritabaniServisi: hardware_id cihaz bilgisi lookup hatası: $e',
        );
      } else {
        // Fallback: eski şemalarda machine_name olmayabilir.
        try {
          final row = await client
              .from('program_deneme')
              .select('hardware_id')
              .eq('hardware_id', normalized)
              .maybeSingle();
          if (row is Map<String, dynamic>) {
            final hw = (row['hardware_id'] as String?)?.trim() ?? '';
            if (hw.isNotEmpty) {
              result[hw] = OnlineVeritabaniCihazBilgisi(
                hardwareId: hw,
                machineName: null,
              );
            }
          }
        } catch (e2) {
          debugPrint(
            'OnlineVeritabaniServisi: hardware_id fallback lookup hatası: $e2',
          );
        }
      }
    } catch (e) {
      debugPrint(
        'OnlineVeritabaniServisi: hardware_id cihaz bilgisi lookup hatası: $e',
      );
    }

    // Preferred: license_id grouping (may not exist on older schemas).
    try {
      final data = await client
          .from('program_deneme')
          .select('hardware_id, machine_name')
          .eq('license_id', normalized);
      for (final row in data) {
        final info = OnlineVeritabaniCihazBilgisi.fromMap(row);
        if (info.hardwareId.isNotEmpty) result[info.hardwareId] = info;
      }
    } on PostgrestException catch (e) {
      final msg = (e.message).toLowerCase();
      final licenseIdColumnMissing =
          msg.contains('license_id') &&
          (msg.contains('column') || msg.contains('schema'));
      final machineNameColumnMissing =
          msg.contains('machine_name') &&
          (msg.contains('column') || msg.contains('schema'));

      if (licenseIdColumnMissing) {
        // Eski şema: license_id yoksa sessizce geç.
      } else if (machineNameColumnMissing) {
        // Fallback: machine_name yoksa sadece hardware_id çek.
        try {
          final data = await client
              .from('program_deneme')
              .select('hardware_id')
              .eq('license_id', normalized);
          for (final row in data) {
            final hw = (row['hardware_id'] as String?)?.trim() ?? '';
            if (hw.isNotEmpty) {
              result[hw] = OnlineVeritabaniCihazBilgisi(
                hardwareId: hw,
                machineName: null,
              );
            }
          }
        } on PostgrestException catch (e2) {
          final msg2 = (e2.message).toLowerCase();
          final licenseMissing2 =
              msg2.contains('license_id') &&
              (msg2.contains('column') || msg2.contains('schema'));
          if (!licenseMissing2) {
            debugPrint(
              'OnlineVeritabaniServisi: license_id fallback lookup hatası: $e2',
            );
          }
        } catch (e2) {
          debugPrint(
            'OnlineVeritabaniServisi: license_id fallback lookup hatası: $e2',
          );
        }
      } else {
        debugPrint(
          'OnlineVeritabaniServisi: license_id cihaz bilgisi lookup hatası: $e',
        );
      }
    } catch (e) {
      debugPrint(
        'OnlineVeritabaniServisi: license_id cihaz bilgisi lookup hatası: $e',
      );
    }

    return result.values.toList();
  }

  /// Bir Lisans Kimliği'ne (License ID) bağlı cihazların `hardware_id` listesini döner.
  ///
  /// - Yeni şemada: `program_deneme.license_id` üzerinden gruplar.
  /// - Geriye dönük: Kullanıcı eski sürümden "hardware_id" paylaştıysa, onu da kabul eder.
  Future<List<String>> cihazlariGetirByLisansKimligi(String licenseId) async {
    final infos = await cihazBilgileriGetirByLisansKimligi(licenseId);
    return infos.map((e) => e.hardwareId).where((e) => e.isNotEmpty).toList();
  }

  /// Lisans Kimliği'ne bağlı cihazlardan herhangi birinde bulut veritabanı kimliği varsa döner.
  Future<OnlineVeritabaniKimlikleri?> kimlikleriGetirByLisansKimligi(
    String licenseId,
  ) async {
    final hwIds = await cihazlariGetirByLisansKimligi(licenseId);
    for (final hw in hwIds) {
      final creds = await kimlikleriGetir(hw);
      if (creds != null) return creds;
    }
    return null;
  }

  /// Var olan bir bulut veritabanı kimliğini bu cihaza kopyalar (best-effort).
  ///
  /// Not: Bu işlem sadece admin panel görünürlüğü / tekrar indirme kolaylığı içindir.
  /// Uygulama bağlantısı için `VeritabaniYapilandirma.saveCloudDatabaseCredentials` yeterlidir.
  Future<void> kimlikleriCihazaKaydet({
    required String hardwareId,
    required OnlineVeritabaniKimlikleri kimlikler,
  }) async {
    if (hardwareId.trim().isEmpty) return;

    try {
      final client = Supabase.instance.client;
      final payload = <String, dynamic>{
        'hardware_id': hardwareId.trim(),
        'db_host': kimlikler.host,
        'db_port': kimlikler.port,
        'db_name': kimlikler.database,
        'db_user': kimlikler.username,
        'db_password': kimlikler.password,
        if (kimlikler.apiBaseUrl != null) 'api_base_url': kimlikler.apiBaseUrl,
        if (kimlikler.apiToken != null) 'api_token': kimlikler.apiToken,
        'ssl_required': kimlikler.sslRequired,
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await client
            .from('online_db_credentials')
            .upsert(payload, onConflict: 'hardware_id');
      } on PostgrestException catch (e) {
        final msg = (e.message).toLowerCase();
        final missingApiCols =
            (msg.contains('api_base_url') || msg.contains('api_token')) &&
            (msg.contains('column') || msg.contains('schema'));
        if (!missingApiCols) rethrow;

        // Backward compatible: older schemas may not have api_* columns.
        final fallback = Map<String, dynamic>.from(payload)
          ..remove('api_base_url')
          ..remove('api_token');
        await client
            .from('online_db_credentials')
            .upsert(fallback, onConflict: 'hardware_id');
      }

      await client.from('online_db_requests').upsert({
        'hardware_id': hardwareId.trim(),
        'status': 'configured',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'hardware_id');
    } catch (e) {
      debugPrint('OnlineVeritabaniServisi: Kimlik kopyalama hatası: $e');
    }
  }

  Future<void> talepGonder({
    required String hardwareId,
    required String source,
  }) async {
    try {
      final client = Supabase.instance.client;
      await client.from('online_db_requests').upsert({
        'hardware_id': hardwareId,
        'status': 'pending',
        'source': source,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'hardware_id');
    } catch (e) {
      debugPrint('OnlineVeritabaniServisi: Talep gönderilemedi: $e');
    }
  }

  Future<OnlineVeritabaniKimlikleri?> kimlikleriGetir(String hardwareId) async {
    try {
      final client = Supabase.instance.client;
      final data = await client
          .from('online_db_credentials')
          .select('*')
          .eq('hardware_id', hardwareId)
          .maybeSingle();

      if (data is Map<String, dynamic>) {
        final creds = OnlineVeritabaniKimlikleri.fromMap(data);
        return creds.isValid ? creds : null;
      }
      return null;
    } catch (e) {
      debugPrint('OnlineVeritabaniServisi: Kimlikler alınamadı: $e');
      return null;
    }
  }
}
