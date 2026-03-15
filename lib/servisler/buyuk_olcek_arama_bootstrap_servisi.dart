import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import 'arama/buyuk_olcek_arama_bootstrap_spec.dart';
import 'pg_eklentiler.dart';
import 'veritabani_havuzu.dart';
import 'veritabani_yapilandirma.dart';

/// [2026] Harici search ve Citus olmadan saf PostgreSQL performans bootstrap'i.
///
/// Omurga:
/// - `pg_trgm`
/// - `search_tags` trigram GIN
/// - `search_tags` FTS GIN
/// - büyük tarih akışlarında BRIN
/// - keyset sıraları için temel composite index'ler
class BuyukOlcekAramaBootstrapServisi {
  static final BuyukOlcekAramaBootstrapServisi _instance =
      BuyukOlcekAramaBootstrapServisi._internal();
  factory BuyukOlcekAramaBootstrapServisi() => _instance;
  BuyukOlcekAramaBootstrapServisi._internal();

  final Map<String, Future<void>> _inFlightByDb = <String, Future<void>>{};
  final Set<String> _completedByDb = <String>{};

  Future<void> hazirlaTablolarZorunlu({
    required String databaseName,
    required List<String> tables,
  }) async {
    final db = databaseName.trim();
    if (db.isEmpty) return;
    final safeTables = tables
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (safeTables.isEmpty) return;

    final pool = await VeritabaniHavuzu().havuzAl(database: db);
    await _ensureCoreIndexes(
      pool: pool,
      onlyTables: safeTables.toSet(),
      includeHeavyIndexes: true,
    );
  }

  Future<void> hazirlaBestEffort({
    required String databaseName,
    bool force = false,
  }) {
    final db = databaseName.trim();
    if (db.isEmpty) return Future.value();

    if (!force && _completedByDb.contains(db)) return Future.value();
    final inFlight = _inFlightByDb[db];
    if (inFlight != null && !force) return inFlight;

    final f = _hazirlaInternal(db).whenComplete(() {
      _inFlightByDb.remove(db);
    });
    _inFlightByDb[db] = f;
    return f;
  }

  void iptalEt({String? databaseName}) {
    if (databaseName == null) {
      _inFlightByDb.clear();
      _completedByDb.clear();
      return;
    }
    final db = databaseName.trim();
    if (db.isEmpty) return;
    _inFlightByDb.remove(db);
    _completedByDb.remove(db);
  }

  Future<void> _hazirlaInternal(String db) async {
    final cfg = VeritabaniYapilandirma();
    if (!cfg.allowBackgroundDbMaintenance) return;

    final pool = await VeritabaniHavuzu().havuzAl(database: db);
    await _ensureCoreIndexes(
      pool: pool,
      includeHeavyIndexes: cfg.allowBackgroundHeavyMaintenance,
    );
    _completedByDb.add(db);
  }

  Future<void> _ensureCoreIndexes({
    required Session pool,
    Set<String>? onlyTables,
    required bool includeHeavyIndexes,
  }) async {
    final filter = onlyTables;

    try {
      await PgEklentiler.ensurePgTrgm(pool);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('pg_trgm ensure uyarisi: $e');
      }
    }

    for (final table in BuyukOlcekAramaBootstrapSpec.searchTables) {
      if (filter != null && !filter.contains(table)) continue;
      try {
        await PgEklentiler.ensureSearchTagsNotNullDefault(pool, table);
        await PgEklentiler.ensureSearchTagsTrgmIndex(
          pool,
          table: table,
          indexName: 'idx_${table}_search_tags_gin',
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Core search index uyarisi: table=$table err=$e');
        }
      }
    }

    if (!includeHeavyIndexes) return;

    for (final spec in BuyukOlcekAramaBootstrapSpec.brinSpecs) {
      if (filter != null && !filter.contains(spec.table)) continue;
      try {
        await PgEklentiler.ensureBrinIndex(
          pool,
          table: spec.table,
          indexName: spec.indexName,
          column: spec.column,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'BRIN ensure uyarisi: ${spec.table}.${spec.column} err=$e',
          );
        }
      }
    }

    for (final spec in BuyukOlcekAramaBootstrapSpec.compositeSpecs) {
      if (filter != null && !filter.contains(spec.table)) continue;
      try {
        await PgEklentiler.ensureCompositeIndex(
          pool,
          table: spec.table,
          indexName: spec.indexName,
          expressions: spec.expressions,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'Composite index uyarisi: ${spec.table}/${spec.indexName} err=$e',
          );
        }
      }
    }
  }
}
