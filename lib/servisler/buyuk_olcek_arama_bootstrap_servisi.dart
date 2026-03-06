import 'dart:async';

import 'package:flutter/foundation.dart';

import 'arama/buyuk_olcek_arama_bootstrap_spec.dart';
import 'pg_eklentiler.dart';
import 'veritabani_havuzu.dart';
import 'veritabani_yapilandirma.dart';

/// [2026] 100B+ veri için opsiyonel (env ile açılan) büyük ölçek arama bootstrap'i.
///
/// Amaç:
/// - ParadeDB/pg_search extension + BM25 indexleri (index-first arama için)
/// - Citus dağıtımı (sharding) için best-effort hook
///
/// Varsayılan davranış:
/// - `PATISYO_ALLOW_HEAVY_MAINTENANCE` açık değilse ağır DDL/backfill yok.
/// - Best-effort: izin/extension yoksa uygulama akışı bozulmaz.
class BuyukOlcekAramaBootstrapServisi {
  static final BuyukOlcekAramaBootstrapServisi _instance =
      BuyukOlcekAramaBootstrapServisi._internal();
  factory BuyukOlcekAramaBootstrapServisi() => _instance;
  BuyukOlcekAramaBootstrapServisi._internal();

  final Map<String, Future<void>> _inFlightByDb = <String, Future<void>>{};
  final Set<String> _completedByDb = <String>{};

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

    // Extension kurulumu (best-effort)
    try {
      await PgEklentiler.ensurePgSearch(pool);
    } catch (_) {}
    try {
      await PgEklentiler.ensureCitus(pool);
    } catch (_) {}

    // Ağır DDL işleri sadece explicit maintenance'te.
    // Heavy maintenance kapalıysa bu DB için bir sonraki çağrıları skip edebiliriz.
    if (!cfg.allowBackgroundHeavyMaintenance) {
      _completedByDb.add(db);
      return;
    }

    // BM25 indexleri: index-first path için zorunlu.
    for (final table in BuyukOlcekAramaBootstrapSpec.bm25Tables) {
      try {
        await PgEklentiler.ensureBm25Index(
          pool,
          table: table,
          indexName: 'idx_${table}_search_tags_bm25',
        );
      } catch (e) {
        // Best-effort
        if (kDebugMode) {
          debugPrint('BM25 ensure uyarısı: table=$table err=$e');
        }
      }
    }

    // Citus dağıtımı (best-effort).
    for (final s in BuyukOlcekAramaBootstrapSpec.citusDistributionSpecs) {
      try {
        await PgEklentiler.ensureDistributedTable(
          pool,
          table: s.table,
          distributionColumn: s.column,
          colocateWith: s.colocateWith,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'Citus distribute uyarısı: table=${s.table} col=${s.column} err=$e',
          );
        }
      }
    }

    // Heavy maintenance açıkken tablolar henüz oluşmamış olabilir (bootstrap yarışları).
    // Bu yüzden burada "completed" işaretlemiyoruz; sonraki çağrılar tekrar deneyebilir.
  }
}
