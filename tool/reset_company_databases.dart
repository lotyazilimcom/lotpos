// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:postgres/postgres.dart';

/// Şirket veritabanlarını sıfırlayan bağımsız Dart scripti.
///
/// ÇALIŞTIRMA:
///   Proje klasöründe:
///     dart run tool/reset_company_databases.dart
///
/// NOTLAR:
/// - Sadece PostgreSQL sunucusundaki verileri sıfırlar.
/// - `lospossettings` ayar veritabanına DOKUNMAZ.
/// - `company_settings` tablosundaki tüm şirket kodlarını okur,
///   her biri için ilgili şirket veritabanını bulur ve şu tabloları temizler:
///     - products (ürünler)
///     - productions (üretimler)
///     - production_recipe_items (reçeteler)
///     - production_stock_movements (üretim stok hareketleri)
///     - stock_movements (genel stok hareketleri)
///     - depots (depolar)
///     - warehouse_stocks (depo stokları)
///     - shipments (sevkiyatlar)
///     - sequences (kod/barkod sayaçları)
Future<void> main() async {
  final String host = Platform.environment['LOSPOS_PG_HOST'] ?? 'localhost';
  final int port =
      int.tryParse(Platform.environment['LOSPOS_PG_PORT'] ?? '') ?? 5432;
  final String username = Platform.environment['LOSPOS_PG_USER'] ?? 'lospos';
  final String password = Platform.environment['LOSPOS_PG_PASSWORD'] ?? '';
  const String settingsDb = 'lospossettings';

  print('--- Şirket veritabanı reset scripti başlıyor ---');

  // 1. Ayar veritabanına bağlan ve şirket kodlarını al
  Connection? settingsConn;
  final List<String> companyCodes = [];

  try {
    settingsConn = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: settingsDb,
        username: username,
        password: password,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );

    final result = await settingsConn.execute(
      'SELECT kod FROM company_settings',
    );

    if (result.isEmpty) {
      print(
        'company_settings tablosunda hiç şirket yok. Sıfırlanacak veritabanı bulunamadı.',
      );
      await settingsConn.close();
      print('--- İşlem bitti ---');
      return;
    }

    for (final row in result) {
      final Object? raw = row[0];
      final String code = (raw ?? '').toString().trim();
      if (code.isNotEmpty) {
        companyCodes.add(code);
      }
    }
  } on ServerException catch (e) {
    print(
      'lospossettings veritabanına bağlanırken hata (ServerException): ${e.code} ${e.message}',
    );
    await settingsConn?.close();
    return;
  } catch (e) {
    print('lospossettings veritabanına bağlanırken hata: $e');
    await settingsConn?.close();
    return;
  } finally {
    await settingsConn?.close();
  }

  if (companyCodes.isEmpty) {
    print(
      'company_settings tablosundan geçerli şirket kodu okunamadı. İşlem yapılmadı.',
    );
    print('--- İşlem bitti ---');
    return;
  }

  print('Bulunan şirket kodları: $companyCodes');

  // 2. Her şirket için ilgili veritabanını resetle
  for (final code in companyCodes) {
    final dbName = _veritabaniAdiHesapla(code);

    // Güvenlik: ayar veritabanına asla dokunma
    if (dbName == settingsDb) {
      print('Atlanıyor (ayar veritabanı): $dbName');
      continue;
    }

    await _resetSirketVeritabani(
      host: host,
      port: port,
      username: username,
      password: password,
      dbName: dbName,
    );
  }

  print('--- Tüm şirket veritabanları için reset denemesi tamamlandı ---');
}

/// OturumServisi.aktifVeritabaniAdi ile aynı mantık:
/// - Kod `lospos2026` ise -> `lospos2026`
/// - Diğer kodlar için -> `lospos_<safeCode>`
String _veritabaniAdiHesapla(String kod) {
  final trimmed = kod.trim();
  if (trimmed == 'lospos2026') {
    return 'lospos2026';
  }

  final safeCode = trimmed
      .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
      .toLowerCase();
  return 'lospos_$safeCode';
}

Future<void> _resetSirketVeritabani({
  required String host,
  required int port,
  required String username,
  required String password,
  required String dbName,
}) async {
  print('>>> Sıfırlama başlıyor: $dbName');

  Connection? conn;
  try {
    conn = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: dbName,
        username: username,
        password: password,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );

    // Tabloları tek tek truncate et; yoksa sessiz geç
    // Sıra önemli değil, FK'ler için CASCADE kullanıyoruz.
    await _safeTruncate(conn, 'production_recipe_items');
    await _safeTruncate(conn, 'production_stock_movements');
    await _safeTruncate(conn, 'stock_movements');

    await _safeTruncate(conn, 'shipments');
    await _safeTruncate(conn, 'warehouse_stocks');
    await _safeTruncate(conn, 'depots');

    await _safeTruncate(conn, 'productions');
    await _safeTruncate(conn, 'products');

    await _safeTruncate(conn, 'sequences');

    print('>>> Sıfırlama tamamlandı: $dbName');
  } on ServerException catch (e) {
    print(
      '!!! "$dbName" veritabanına erişirken ServerException: ${e.code} ${e.message}',
    );
  } catch (e) {
    print('!!! "$dbName" veritabanı sıfırlanırken hata: $e');
  } finally {
    await conn?.close();
  }
}

Future<void> _safeTruncate(Connection conn, String tableName) async {
  try {
    await conn.execute('TRUNCATE TABLE $tableName RESTART IDENTITY CASCADE');
    print('  - TRUNCATE OK: $tableName');
  } on ServerException catch (e) {
    // 42P01: undefined_table -> tablo yoksa atla
    if (e.code == '42P01') {
      print('  - Tablo yok, atlanıyor: $tableName');
      return;
    }
    print('  - TRUNCATE hata ($tableName): ${e.code} ${e.message}');
  } catch (e) {
    print('  - TRUNCATE beklenmeyen hata ($tableName): $e');
  }
}
