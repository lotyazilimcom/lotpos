import 'dart:convert';

import 'package:postgres/postgres.dart';

class HizliSayimYardimcisi {
  static Future<int> tahminiVeyaKesinSayim(
    Session executor, {
    required String fromClause,
    List<String> whereConditions = const <String>[],
    Map<String, dynamic> params = const <String, dynamic>{},
    String? unfilteredTable,
    int exactThreshold = 50000,
  }) async {
    final whereClause = whereConditions.isEmpty
        ? ''
        : ' WHERE ${whereConditions.join(' AND ')}';

    if (whereConditions.isEmpty) {
      final table = (unfilteredTable ?? '').trim();
      if (table.isNotEmpty) {
        try {
          final approx = await executor.execute(
            Sql.named(
              'SELECT reltuples::BIGINT FROM pg_class WHERE relname = @table LIMIT 1',
            ),
            parameters: {'table': table},
          );
          if (approx.isNotEmpty && approx.first[0] != null) {
            final value =
                num.tryParse(approx.first[0].toString())?.toInt() ?? 0;
            if (value > 0) return value;
          }
        } catch (_) {}
      }
    }

    try {
      final explain = await executor.execute(
        Sql.named(
          'EXPLAIN (FORMAT JSON) SELECT 1 FROM $fromClause$whereClause',
        ),
        parameters: params,
      );
      if (explain.isNotEmpty && explain.first.isNotEmpty) {
        final raw = explain.first[0];
        dynamic decoded = raw;
        if (raw is String) {
          decoded = jsonDecode(raw);
        }

        if (decoded is List && decoded.isNotEmpty) {
          final rows =
              num.tryParse(
                decoded.first['Plan']?['Plan Rows']?.toString() ?? '',
              )?.toInt() ??
              0;
          if (rows > exactThreshold) return rows;
        }
      }
    } catch (_) {}

    final result = await executor.execute(
      Sql.named('SELECT COUNT(*) FROM $fromClause$whereClause'),
      parameters: params,
    );
    if (result.isEmpty || result.first.isEmpty) return 0;
    return num.tryParse(result.first[0].toString())?.toInt() ?? 0;
  }
}
