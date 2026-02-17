import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnlineVeritabaniKimlikleri {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final bool sslRequired;

  const OnlineVeritabaniKimlikleri({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    required this.sslRequired,
  });

  factory OnlineVeritabaniKimlikleri.fromMap(Map<String, dynamic> row) {
    return OnlineVeritabaniKimlikleri(
      host: (row['db_host'] as String?)?.trim() ?? '',
      port: (row['db_port'] as num?)?.toInt() ?? 5432,
      database: (row['db_name'] as String?)?.trim() ?? '',
      username: (row['db_user'] as String?)?.trim() ?? '',
      password: (row['db_password'] as String?)?.trim() ?? '',
      // Cloud PG genelde SSL ister; alan yoksa/boşsa varsayılanı "true" kabul et.
      sslRequired: row['ssl_required'] == false ? false : true,
    );
  }

  bool get isValid =>
      host.isNotEmpty &&
      database.isNotEmpty &&
      username.isNotEmpty &&
      password.isNotEmpty;
}

class OnlineVeritabaniServisi {
  static final OnlineVeritabaniServisi _instance =
      OnlineVeritabaniServisi._internal();
  factory OnlineVeritabaniServisi() => _instance;
  OnlineVeritabaniServisi._internal();

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
