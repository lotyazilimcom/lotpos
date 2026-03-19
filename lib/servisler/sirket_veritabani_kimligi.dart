class SirketVeritabaniKimligi {
  static const String legacyDefaultDatabaseName = 'lospos2026';

  static const Set<String> _legacyDefaultCompanyCodes = <String>{'lospos2026'};

  static bool isLegacyDefaultCompanyCode(String? code) {
    final normalized = (code ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return _legacyDefaultCompanyCodes.contains(normalized);
  }

  static String databaseNameFromCompanyCode(String? code) {
    final raw = (code ?? '').trim();
    if (raw.isEmpty) return legacyDefaultDatabaseName;
    if (isLegacyDefaultCompanyCode(raw)) return legacyDefaultDatabaseName;

    final safe = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    if (safe.isEmpty) return legacyDefaultDatabaseName;
    return 'lospos_$safe';
  }
}
