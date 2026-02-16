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
  final String _mainDbName = 'patisyosettings';

  String get _password {
    final pass = Platform.environment['PATISYO_DB_PASSWORD'];
    if (pass != null && pass.trim().isNotEmpty) return pass.trim();
    throw StateError(
      'PATISYO_DB_PASSWORD zorunludur. Güvenlik için fallback şifre kaldırıldı.',
    );
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
      settingsConn = await Connection.open(
        Endpoint(
          host: _host,
          port: _port,
          database: _mainDbName,
          username: _username,
          password: _password,
        ),
        settings: const ConnectionSettings(sslMode: SslMode.disable),
      );

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
      conn = await Connection.open(
        Endpoint(
          host: _host,
          port: _port,
          database: dbName,
          username: _username,
          password: _password,
        ),
        settings: const ConnectionSettings(sslMode: SslMode.disable),
      );

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
        'depots',

        // 3. FİNANSAL TABLOLAR (KASA, BANKA, KART, GİDER)
        'cash_register_transactions',
        'cash_registers',
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
