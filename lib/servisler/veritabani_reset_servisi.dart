import 'dart:async';
import 'dart:io';

import 'package:postgres/postgres.dart';

/// VERİTABANI SIFIRLAMA SERVİSİ (CLI Sürümü)
///
/// Bu dosya tamamen bağımsız (standalone) bir Dart scriptidir.
/// Flutter bağımlılığı içermez, bu sayede doğrudan 'dart' komutu ile çalışabilir.
///
/// ÖNCE: 'patisyosettings' veritabanına bağlanıp şirket kodlarını alır.
/// SONRA: Her şirket veritabanındaki operasyonel tabloları TRUNCATE eder.
///
/// ÇALIŞTIRMA:
///   dart lib/servisler/veritabani_reset_servisi.dart
///
class VeritabaniResetServisi {
  // Yapılandırma Bilgileri (VeritabaniYapilandirma'dan kopyalandı)
  final String _host = Platform.environment['PATISYO_DB_HOST'] ?? 'localhost';
  final int _port =
      int.tryParse(Platform.environment['PATISYO_DB_PORT'] ?? '5432') ?? 5432;
  final String _username = Platform.environment['PATISYO_DB_USER'] ?? 'patisyo';
  final String _mainDbName =
      (Platform.environment['PATISYO_SETTINGS_DB_NAME'] ?? 'patisyosettings')
          .trim();

  String? _cachedPassword;

  QueryMode get _queryMode {
    final raw = (Platform.environment['PATISYO_DB_QUERY_MODE'] ?? '')
        .trim()
        .toLowerCase();
    if (raw == 'simple') return QueryMode.simple;
    if (raw == 'extended') return QueryMode.extended;

    final poolerMode = (Platform.environment['PATISYO_DB_POOLER_MODE'] ?? '')
        .trim()
        .toLowerCase();
    if (poolerMode == 'transaction' || poolerMode == 'tx') {
      return QueryMode.simple;
    }
    if (poolerMode == 'session') return QueryMode.extended;

    final hostLower = _host.trim().toLowerCase();
    final bool looksLikePooler =
        hostLower.contains('-pooler') || hostLower.contains('pooler.');
    final bool looksLikeTxPort = _port == 6543;

    if (looksLikePooler || looksLikeTxPort) return QueryMode.simple;
    return QueryMode.extended;
  }

  bool get _looksLocalHost {
    final h = _host.trim().toLowerCase();
    return h == 'localhost' || h == '127.0.0.1' || h == '::1';
  }

  SslMode get _sslMode {
    final raw = (Platform.environment['PATISYO_DB_SSLMODE'] ?? '')
        .trim()
        .toLowerCase();
    if (raw == 'require') return SslMode.require;
    if (raw == 'disable') return SslMode.disable;
    return _looksLocalHost ? SslMode.disable : SslMode.require;
  }

  Future<String> _getPassword({bool forcePrompt = false}) async {
    if (!forcePrompt && _cachedPassword != null) return _cachedPassword!;

    if (!forcePrompt) {
      final envPass = (Platform.environment['PATISYO_DB_PASSWORD'] ?? '5828486')
          .trim();
      if (envPass.isNotEmpty) {
        _cachedPassword = envPass;
        return envPass;
      }

      final pgPass = (Platform.environment['PGPASSWORD'] ?? '').trim();
      if (pgPass.isNotEmpty) {
        _cachedPassword = pgPass;
        return pgPass;
      }

      // Local dev default: try empty password first; only prompt if auth fails.
      if (_looksLocalHost) {
        _cachedPassword = '';
        return '';
      }
    }

    if (!stdin.hasTerminal) {
      if (_looksLocalHost) {
        _cachedPassword = '';
        return '';
      }
      throw StateError(
        'PATISYO_DB_PASSWORD zorunludur (non-interactive). '
        'Yerel kullanım için PATISYO_DB_PASSWORD/PGPASSWORD ayarlayın '
        'veya localhost için boş şifre kullanın.',
      );
    }

    stdout.write('🔐 PATISYO_DB_PASSWORD gir (boş = empty): ');
    String typed = '';
    try {
      final prev = stdin.echoMode;
      stdin.echoMode = false;
      try {
        typed = (stdin.readLineSync() ?? '').trimRight();
      } finally {
        stdin.echoMode = prev;
        stdout.writeln();
      }
    } catch (_) {
      // Fallback: echo kapatılamazsa normal oku.
      typed = (stdin.readLineSync() ?? '').trimRight();
    }

    _cachedPassword = typed;
    return typed;
  }

  Future<Connection> _openConnection({
    required String database,
    int maxPasswordAttempts = 3,
  }) async {
    int attempts = 0;
    while (true) {
      attempts++;
      final password = await _getPassword(forcePrompt: attempts > 1);
      try {
        return await Connection.open(
          Endpoint(
            host: _host,
            port: _port,
            database: database,
            username: _username,
            password: password,
          ),
          settings: ConnectionSettings(
            sslMode: _sslMode,
            queryMode: _queryMode,
          ),
        );
      } on ServerException catch (e) {
        final authFailed = e.code == '28P01' || e.code == '28000';
        if (authFailed && stdin.hasTerminal && attempts < maxPasswordAttempts) {
          stdout.writeln('❌ Şifre doğrulama başarısız. Tekrar dene.');
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> tumSirketVeritabanlariniSifirla() async {
    stdout.writeln(
      '------------------------------------------------------------',
    );
    stdout.writeln('🚀 PATİSYO VERİTABANI SIFIRLAMA (2025 CLI)');
    stdout.writeln(
      '------------------------------------------------------------',
    );

    List<String> sirketKodlari = [];

    // 1. Şirket Listesini Al
    Connection? settingsConn;
    try {
      settingsConn = await _openConnection(database: _mainDbName);

      final result = await settingsConn.execute(
        'SELECT kod FROM company_settings',
      );
      for (final row in result) {
        final String? kod = row[0] as String?;
        if (kod != null && kod.trim().isNotEmpty) {
          sirketKodlari.add(kod.trim());
        }
      }
    } catch (e) {
      stdout.writeln(
        '❌ Ayar veritabanına bağlanılamadı veya şirketler okunamadı: $e',
      );

      // Fallback: settings DB yoksa tek veritabanını doğrudan resetlemeyi dene.
      final directDb =
          (Platform.environment['PATISYO_RESET_DB_NAME'] ??
                  Platform.environment['PATISYO_DB_NAME'] ??
                  '')
              .trim();
      final directCompanyCode =
          (Platform.environment['PATISYO_RESET_COMPANY_CODE'] ?? '').trim();

      if (directDb.isNotEmpty) {
        stdout.writeln('ℹ️ Doğrudan sıfırlama deneniyor -> $directDb');
        await _sirketVeritabaniSifirla(directDb);
      } else if (directCompanyCode.isNotEmpty) {
        stdout.writeln(
          'ℹ️ Şirket kodu ile sıfırlama deneniyor -> $directCompanyCode',
        );
        await sirketVeritabaniSifirlaKodIle(directCompanyCode);
      } else {
        stdout.writeln(
          '💡 Tek DB için: PATISYO_RESET_DB_NAME=... (veya PATISYO_DB_NAME) ayarla.',
        );
      }
      return;
    } finally {
      await settingsConn?.close();
    }

    if (sirketKodlari.isEmpty) {
      stdout.writeln('ℹ️ Sıfırlanacak şirket veritabanı bulunamadı.');
      return;
    }

    stdout.writeln(
      '📂 Bulunan Şirket Veritabanı Sayısı: ${sirketKodlari.length}',
    );

    // 2. Her Şirketi Sıfırla
    for (final kod in sirketKodlari) {
      final String dbName = _veritabaniAdiHesapla(kod);

      if (dbName == 'patisyosettings') {
        stdout.writeln('🛡️ patisyosettings atlandı.');
        continue;
      }

      await _sirketVeritabaniSifirla(dbName);
    }
  }

  Future<void> sirketVeritabaniSifirlaKodIle(String sirketKodu) async {
    final String dbName = _veritabaniAdiHesapla(sirketKodu);
    if (dbName == 'patisyosettings') {
      stdout.writeln('🛡️ patisyosettings ayar veritabanı, sıfırlanmadı.');
      return;
    }
    await _sirketVeritabaniSifirla(dbName);
  }

  String _veritabaniAdiHesapla(String kod) {
    if (kod == 'patisyo2025') return 'patisyo2025';
    final safeCode = kod.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    return 'patisyo_$safeCode';
  }

  Future<void> _sirketVeritabaniSifirla(String dbName) async {
    stdout.writeln('\n🧹 Sıfırlama başlıyor -> $dbName');

    Connection? conn;
    try {
      conn = await _openConnection(database: dbName);

      final List<String> tablar = [
        // 1. SATIŞ / ALIŞ / SİPARİŞ / TEKLİF
        'sales',
        'sale_items',
        'purchases',
        'purchase_items',
        'orders',
        'order_items',
        'quotes',
        'quote_items',
        'shipments',

        // 2. STOK VE HAREKETLER
        'stock_movements',
        'warehouse_stocks',
        'products',
        'product_metadata',
        'product_devices',
        'table_counts',

        // 3. FİNANSAL TABLOLAR (KASA, BANKA, KART, GİDER)
        'cash_register_transactions',
        'bank_transactions',
        'banks',
        'credit_card_transactions',
        'credit_cards',
        'expenses',
        'expense_items',

        // 4. ÇEK VE SENET
        'cheques',
        'cheque_transactions',
        'promissory_notes',
        'note_transactions',

        // 5. CARİ HESAPLAR
        'current_account_transactions',
        'current_accounts',
        'account_metadata',
        'installments',

        // 6. ÜRETİM
        'productions',
        'production_recipe_items',
        'production_stock_movements',
        'production_metadata',

        // 7. PERSONEL VE SİSTEM
        'user_transactions',
        'users',
        'roles',
        'sync_delta_outbox',
        'sync_tombstones',
        'sync_outbox',
        'sequences',
        'logs',

        // 8. AYARLAR VE TANIMLAR
        'company_settings',
        'general_settings',
        'saved_descriptions',
        'hidden_descriptions',
        'currency_rates',
      ];

      for (final table in tablar) {
        await _safeTruncate(conn, table);
      }

      stdout.writeln('✅ Sıfırlama tamamlandı -> $dbName');
    } on ServerException catch (e) {
      if (e.code == '3D000') {
        stdout.writeln(
          '⏭️ Şirket veritabanı mevcut değil, atlanıyor ($dbName).',
        );
      } else {
        stdout.writeln('❌ "$dbName" ServerException: ${e.code} ${e.message}');
      }
    } catch (e) {
      stdout.writeln('❌ "$dbName" beklenmeyen hata: $e');
    } finally {
      await conn?.close();
    }
  }

  Future<void> _safeTruncate(Connection conn, String tableName) async {
    try {
      await conn.execute('TRUNCATE TABLE $tableName RESTART IDENTITY CASCADE');
      stdout.writeln('   🔹 $tableName temizlendi');
    } on ServerException catch (e) {
      if (e.code == '42P01') {
        // Tablo yoksa sessizce geç
        return;
      }
      stdout.writeln('   ⚠️ $tableName hatası: ${e.code} ${e.message}');
    } catch (e) {
      stdout.writeln('   ⚠️ $tableName beklenmeyen hata: $e');
    }
  }
}

Future<void> main() async {
  stdout.writeln('\n🔔 BAŞLATILIYOR...');
  await VeritabaniResetServisi().tumSirketVeritabanlariniSifirla();
  stdout.writeln('\n🏁 TÜM İŞLEMLER BİTTİ.\n');
}
