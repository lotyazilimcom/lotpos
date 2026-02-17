import 'package:postgres/postgres.dart';

class PgEklentiler {
  static const String _ensurePgTrgmSql = '''
DO \$\$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
  WHEN unique_violation THEN
    NULL;
END;
\$\$;
''';

  static Future<void> ensurePgTrgm(Session session) async {
    await session.execute(_ensurePgTrgmSql);
  }
}
