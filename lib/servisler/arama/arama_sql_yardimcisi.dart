import '../pg_eklentiler.dart';

class AramaSqlYardimcisi {
  static final RegExp _tokenSplitter = RegExp(r'\s+');

  static String normalizeQuery(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    return trimmed
        .toLowerCase()
        .replaceAll('i̇', 'i')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');
  }

  static List<String> tokenizeQuery(
    String query, {
    int minTokenLength = 1,
    int maxTokens = 8,
  }) {
    final normalized = normalizeQuery(query);
    if (normalized.isEmpty) return const <String>[];
    final tokens = normalized
        .split(_tokenSplitter)
        .map((e) => e.trim())
        .where((e) => e.length >= minTokenLength)
        .toList(growable: false);
    if (tokens.length <= maxTokens) return tokens;
    return tokens.take(maxTokens).toList(growable: false);
  }

  static bool bindSearchParams(
    Map<String, dynamic> params,
    String rawQuery, {
    String prefix = 'search_',
    int minTokenLength = 1,
    int maxTokens = 8,
  }) {
    final normalized = normalizeQuery(rawQuery);
    if (normalized.isEmpty) return false;
    final tokens = tokenizeQuery(
      normalized,
      minTokenLength: minTokenLength,
      maxTokens: maxTokens,
    );
    final ftsQuery = tokens.isEmpty ? normalized : tokens.join(' ');
    params['${prefix}fts_query'] = ftsQuery;
    params['${prefix}trgm_query'] = normalized;
    params['${prefix}trgm_enabled'] =
        normalized.length >= 3 || tokens.any((token) => token.length >= 3);
    return true;
  }

  static String buildSearchTagsClause(
    String expression, {
    String prefix = 'search_',
  }) {
    final coalescedExpression = "COALESCE($expression, '')";
    final searchVector =
        "to_tsvector('${PgEklentiler.searchTextConfig}'::regconfig, $coalescedExpression)";
    return '''
      (
        $searchVector @@ plainto_tsquery('${PgEklentiler.searchTextConfig}'::regconfig, @${prefix}fts_query)
        OR (@${prefix}trgm_enabled AND $coalescedExpression % @${prefix}trgm_query)
      )
    ''';
  }
}
