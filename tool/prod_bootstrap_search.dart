// ignore_for_file: avoid_print

import 'dart:io';

import 'package:postgres/postgres.dart';

import 'package:patisyov10/servisler/arama/buyuk_olcek_arama_bootstrap_spec.dart';
import 'package:patisyov10/servisler/pg_eklentiler.dart';

/// Prod bakım penceresi için tek seferlik bootstrap scripti.
///
/// Amaç:
/// - `pg_search` (ParadeDB) + BM25 indexleri
/// - `citus` + dağıtım (sharding)
///
/// Güvenlik:
/// - Yanlışlıkla çalışmasın diye `PATISYO_ALLOW_HEAVY_MAINTENANCE=true` zorunlu.
///
/// ÇALIŞTIRMA (örnek):
///   PATISYO_ALLOW_HEAVY_MAINTENANCE=true \\
///   PATISYO_PG_HOST=127.0.0.1 \\
///   PATISYO_PG_PORT=5432 \\
///   PATISYO_PG_USER=patisyo \\
///   PATISYO_PG_PASSWORD=... \\
///   dart run tool/prod_bootstrap_search.dart
///
/// Not:
/// - Bu script extension binary'lerini OS'e kurmaz. `pg_search`/`citus` extension dosyaları
///   Postgres'e kurulmuş olmalıdır (pg_available_extensions içinde görünmeli).
Future<void> main(List<String> args) async {
  if (!_isTruthy(Platform.environment['PATISYO_ALLOW_HEAVY_MAINTENANCE'])) {
    print(
      '❌ Bu script sadece bakım penceresinde çalıştırılmalı. '
      'Çalıştırmak için env: PATISYO_ALLOW_HEAVY_MAINTENANCE=true',
    );
    exitCode = 2;
    return;
  }

  final host = (Platform.environment['PATISYO_PG_HOST'] ??
          Platform.environment['PATISYO_DB_HOST'] ??
          '127.0.0.1')
      .trim();
  final port = int.tryParse(
        (Platform.environment['PATISYO_PG_PORT'] ??
                Platform.environment['PATISYO_DB_PORT'] ??
                '')
            .trim(),
      ) ??
      5432;
  final username = (Platform.environment['PATISYO_PG_USER'] ??
          Platform.environment['PATISYO_DB_USER'] ??
          'patisyo')
      .trim();
  final password = (Platform.environment['PATISYO_PG_PASSWORD'] ??
          Platform.environment['PATISYO_DB_PASSWORD'] ??
          '')
      .trim();

  const settingsDb = 'patisyosettings';
  const defaultDb = 'patisyo2025';

  final onlyDb = _parseOnlyDbArg(args);

  final dbNames = <String>{};
  if (onlyDb != null) {
    dbNames.add(onlyDb);
  } else {
    dbNames.add(defaultDb);
    final codes = await _fetchCompanyCodesBestEffort(
      host: host,
      port: port,
      username: username,
      password: password,
      settingsDb: settingsDb,
    );
    for (final code in codes) {
      dbNames.add(_veritabaniAdiHesapla(code));
    }
  }

  print('--- Prod Search Bootstrap Başlıyor ---');
  print('Host: $host:$port  User: $username  DB count: ${dbNames.length}');
  if (onlyDb != null) {
    print('Sadece DB hedefi: $onlyDb');
  }

  for (final db in dbNames) {
    await _bootstrapDb(
      host: host,
      port: port,
      username: username,
      password: password,
      database: db,
    );
  }

  print('--- Prod Search Bootstrap Bitti ---');
}

String? _parseOnlyDbArg(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final a = args[i].trim();
    if (a == '--db' && i + 1 < args.length) {
      final v = args[i + 1].trim();
      return v.isEmpty ? null : v;
    }
    if (a.startsWith('--db=')) {
      final v = a.substring('--db='.length).trim();
      return v.isEmpty ? null : v;
    }
  }
  return null;
}

Future<void> _bootstrapDb({
  required String host,
  required int port,
  required String username,
  required String password,
  required String database,
}) async {
  final db = database.trim();
  if (db.isEmpty) return;

  print('');
  print('=== DB: $db ===');

  Connection? conn;
  try {
    conn = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: db,
        username: username,
        password: password,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );

    // 1) Extensions (best-effort)
    await PgEklentiler.ensurePgSearch(conn);
    await PgEklentiler.ensureCitus(conn);

    final hasPgSearch = await PgEklentiler.hasExtension(conn, 'pg_search');
    final hasCitus = await PgEklentiler.hasExtension(conn, 'citus');

    print('pg_search: ${hasPgSearch ? 'OK' : 'YOK'}');
    print('citus: ${hasCitus ? 'OK' : 'YOK'}');

    // 2) BM25 indexes
    var bm25Ok = 0;
    var bm25Skip = 0;
    if (!hasPgSearch) {
      print('BM25 index: atlandı (pg_search yok)');
    } else {
      for (final table in BuyukOlcekAramaBootstrapSpec.bm25Tables) {
        final exists = await _tableExists(conn, table);
        if (!exists) {
          bm25Skip++;
          continue;
        }
        final idx = 'idx_${table}_search_tags_bm25';
        await PgEklentiler.ensureBm25Index(conn, table: table, indexName: idx);
        final ok =
            await PgEklentiler.hasIndex(conn, idx) ||
            await PgEklentiler.hasBm25IndexForTable(conn, table);
        if (ok) bm25Ok++;
      }
      print(
        'BM25 index: OK=$bm25Ok SKIP(table yok)=$bm25Skip TOTAL=${BuyukOlcekAramaBootstrapSpec.bm25Tables.length}',
      );
    }

    // 3) Citus distribution
    var citusOk = 0;
    var citusSkip = 0;
    if (!hasCitus) {
      print('Citus dağıtımı: atlandı (citus yok)');
    } else {
      for (final s in BuyukOlcekAramaBootstrapSpec.citusDistributionSpecs) {
        final exists = await _tableExists(conn, s.table);
        if (!exists) {
          citusSkip++;
          continue;
        }
        await PgEklentiler.ensureDistributedTable(
          conn,
          table: s.table,
          distributionColumn: s.column,
          colocateWith: s.colocateWith,
        );
        final ok = await PgEklentiler.isCitusTable(conn, s.table);
        if (ok) citusOk++;
      }
      print(
        'Citus dağıtımı: OK=$citusOk SKIP(table yok)=$citusSkip TOTAL=${BuyukOlcekAramaBootstrapSpec.citusDistributionSpecs.length}',
      );
    }
  } on ServerException catch (e) {
    print('DB hata (ServerException): ${e.code} ${e.message}');
  } catch (e) {
    print('DB hata: $e');
  } finally {
    await conn?.close();
  }
}

Future<List<String>> _fetchCompanyCodesBestEffort({
  required String host,
  required int port,
  required String username,
  required String password,
  required String settingsDb,
}) async {
  Connection? conn;
  try {
    conn = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: settingsDb,
        username: username,
        password: password,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );

    // company_settings yoksa veya erişim yoksa: sessiz düş.
    final res = await conn.execute('SELECT kod FROM company_settings');
    final out = <String>[];
    for (final row in res) {
      final v = (row[0] ?? '').toString().trim();
      if (v.isNotEmpty) out.add(v);
    }
    return out;
  } catch (_) {
    return const <String>[];
  } finally {
    await conn?.close();
  }
}

/// OturumServisi.aktifVeritabaniAdi ile aynı mantık:
/// - Kod `patisyo2025` ise -> `patisyo2025`
/// - Diğer kodlar için -> `patisyo_<safeCode>`
String _veritabaniAdiHesapla(String kod) {
  final trimmed = kod.trim();
  if (trimmed == 'patisyo2025') return 'patisyo2025';
  final safeCode =
      trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
  return 'patisyo_$safeCode';
}

bool _isTruthy(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  return v == '1' || v == 'true' || v == 'yes' || v == 'on';
}

Future<bool> _tableExists(Session executor, String table) async {
  final t = table.trim();
  if (t.isEmpty) return false;
  try {
    final res = await executor.execute(
      Sql.named(
        "SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name=@t LIMIT 1",
      ),
      parameters: {'t': t},
    );
    return res.isNotEmpty;
  } catch (_) {
    return false;
  }
}
