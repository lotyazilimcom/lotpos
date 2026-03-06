import 'dart:io';
import 'package:postgres/postgres.dart';

void main() async {
  stdout.writeln('Checking PostgreSQL connection...');

  // Defaults from veritabani_yapilandirma.dart (override via env vars).
  final host = Platform.environment['PATISYO_PG_HOST'] ?? '127.0.0.1';
  final port =
      int.tryParse(Platform.environment['PATISYO_PG_PORT'] ?? '') ?? 5432;
  final database =
      Platform.environment['PATISYO_PG_DB'] ?? 'patisyosettings';
  final username =
      Platform.environment['PATISYO_PG_USER'] ?? 'patisyo';
  final password = Platform.environment['PATISYO_PG_PASSWORD'] ?? '';

  final endpoint = Endpoint(
    host: host,
    port: port,
    database: database,
    username: username,
    password: password,
  );

  try {
    final connection = await Connection.open(endpoint);
    stdout.writeln('✅ Connection successful!');
    await connection.close();
    stdout.writeln('Connection closed.');
  } catch (e) {
    stdout.writeln('❌ Connection failed: $e');
    // Try to connect to 'postgres' database to check if server is running at least
    try {
      stdout.writeln('Trying to connect to default "postgres" database...');
      final endpointDefault = Endpoint(
        host: host,
        port: port,
        database: 'postgres',
        username: Platform.environment['USER'] ?? 'postgres',
        password: password,
      );
      final connection = await Connection.open(endpointDefault);
      stdout.writeln('✅ Connected to "postgres" database!');
      await connection.close();
    } catch (e2) {
      stdout.writeln('❌ Default connection also failed: $e2');
    }
  }
}
