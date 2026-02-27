import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

class ClusterKimligiServisi {
  static final ClusterKimligiServisi _instance =
      ClusterKimligiServisi._internal();
  factory ClusterKimligiServisi() => _instance;
  ClusterKimligiServisi._internal();

  static const String clusterIdKey = 'cluster_id';

  static String _uuidV4() {
    final rng = () {
      try {
        return Random.secure();
      } catch (_) {
        // Web gibi ortamlarda Random.secure desteklenmeyebilir; Cluster ID için
        // kriptografik RNG şart değil.
        return Random();
      }
    }();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<Connection> _open(
    Endpoint endpoint, {
    required SslMode sslMode,
    required Duration connectTimeout,
  }) async {
    return Connection.open(
      endpoint,
      settings: ConnectionSettings(
        sslMode: sslMode,
        connectTimeout: connectTimeout,
        onOpen: (c) async {
          // Managed PG ortamlarda varsayılan statement_timeout düşük olabiliyor.
          // Basit meta okuma/yazma için güvenli: 0 (limitsiz).
          try {
            await c.execute('SET statement_timeout TO 0');
          } catch (_) {}
        },
      ),
    );
  }

  Future<String?> oku({
    required Endpoint endpoint,
    required SslMode sslMode,
    Duration connectTimeout = const Duration(seconds: 6),
  }) async {
    Connection? conn;
    try {
      conn = await _open(
        endpoint,
        sslMode: sslMode,
        connectTimeout: connectTimeout,
      );
      final res = await conn.execute(
        Sql.named(
          'SELECT value FROM public.general_settings WHERE key = @k LIMIT 1',
        ),
        parameters: {'k': clusterIdKey},
      );
      if (res.isEmpty) return null;
      final v = (res.first[0] as String?)?.trim();
      return (v == null || v.isEmpty) ? null : v;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ClusterKimligiServisi: oku failed: $e');
      }
      return null;
    } finally {
      try {
        await conn?.close();
      } catch (_) {}
    }
  }

  Future<String?> okuVeyaOlustur({
    required Endpoint endpoint,
    required SslMode sslMode,
    Duration connectTimeout = const Duration(seconds: 8),
    bool allowCreate = true,
  }) async {
    Connection? conn;
    try {
      conn = await _open(
        endpoint,
        sslMode: sslMode,
        connectTimeout: connectTimeout,
      );

      final existing = await conn.execute(
        Sql.named(
          'SELECT value FROM public.general_settings WHERE key = @k LIMIT 1',
        ),
        parameters: {'k': clusterIdKey},
      );
      if (existing.isNotEmpty) {
        final v = (existing.first[0] as String?)?.trim();
        if (v != null && v.isNotEmpty) return v;
      }

      if (!allowCreate) return null;

      final id = _uuidV4();
      await conn.execute(
        Sql.named('''
          INSERT INTO public.general_settings (key, value)
          VALUES (@k, @v)
          ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value
        '''),
        parameters: {'k': clusterIdKey, 'v': id},
      );
      return id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ClusterKimligiServisi: okuVeyaOlustur failed: $e');
      }
      return null;
    } finally {
      try {
        await conn?.close();
      } catch (_) {}
    }
  }
}
