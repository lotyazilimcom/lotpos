import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import 'bankalar_veritabani_servisi.dart';
import 'bulut_sema_dogrulama_servisi.dart';
import 'cari_hesaplar_veritabani_servisi.dart';
import 'cekler_veritabani_servisi.dart';
import 'depolar_veritabani_servisi.dart';
import 'giderler_veritabani_servisi.dart';
import 'kasalar_veritabani_servisi.dart';
import 'kredi_kartlari_veritabani_servisi.dart';
import 'oturum_servisi.dart';
import 'personel_islemleri_veritabani_servisi.dart';
import 'senetler_veritabani_servisi.dart';
import 'siparisler_veritabani_servisi.dart';
import 'teklifler_veritabani_servisi.dart';
import 'uretimler_veritabani_servisi.dart';
import 'urunler_veritabani_servisi.dart';
import 'veritabani_havuzu.dart';
import 'veritabani_yapilandirma.dart';

/// Bulut (Supabase/Neon vb.) veritabanında arama için kritik şema parçalarını
/// (pg_trgm, normalize_text, trigger'lar, search_tags indeksleri) best-effort
/// olarak ayağa kaldırır.
///
/// Not: Kurulum/DDL işlemleri modül servislerinin kendi `_tablolariOlustur()`
/// akışlarıyla yapılır. Bu servis sadece "proaktif" tetikler.
class BulutSemaBootstrapServisi {
  static final BulutSemaBootstrapServisi _instance =
      BulutSemaBootstrapServisi._internal();
  factory BulutSemaBootstrapServisi() => _instance;
  BulutSemaBootstrapServisi._internal();

  Future<void>? _inFlight;
  int _token = 0;

  Future<void> hazirlaBestEffort({bool force = false}) {
    final existing = _inFlight;
    if (existing != null) {
      if (!force) return existing;
      // Force is requested: run a second pass after the current one finishes.
      return existing.whenComplete(() {
        final followUp = _hazirlaInternal(force: true);
        _inFlight = followUp;
        return followUp;
      });
    }

    final created = _hazirlaInternal(force: force);
    _inFlight = created;
    return created;
  }

  void iptalEt() {
    _token++;
    _inFlight = null;
  }

  Future<void> _hazirlaInternal({required bool force}) async {
    if (VeritabaniYapilandirma.connectionMode != 'cloud') return;
    if (!VeritabaniYapilandirma.cloudAccessReady) return;

    final String dbName = OturumServisi().aktifVeritabaniAdi.trim();
    if (dbName.isEmpty) return;

    final int myToken = ++_token;

    Pool<void>? pool;
    try {
      pool = await VeritabaniHavuzu().havuzAl(database: dbName);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BulutSemaBootstrap: pool alınamadı: $e');
      }
      return;
    }

    try {
      // Eğer şema zaten hazırsa, ekstra iş yapma.
      final ok = await BulutSemaDogrulamaServisi().bulutSemasiHazirMi(
        executor: pool,
        databaseName: dbName,
      );
      if (ok && !force) return;

      if (kDebugMode) {
        debugPrint(
          'BulutSemaBootstrap: Bulut şema eksik/force. Bootstrap başlıyor (db=$dbName).',
        );
      }

      // Modül servislerini sırayla başlat: her biri eksikleri best-effort kurar.
      final List<Future<void> Function()> steps = <Future<void> Function()>[
        () => CariHesaplarVeritabaniServisi().baslat(),
        () => BankalarVeritabaniServisi().baslat(),
        () => KasalarVeritabaniServisi().baslat(),
        () => KrediKartlariVeritabaniServisi().baslat(),
        () => CeklerVeritabaniServisi().baslat(),
        () => SenetlerVeritabaniServisi().baslat(),
        () => GiderlerVeritabaniServisi().baslat(),
        () => DepolarVeritabaniServisi().baslat(),
        () => UrunlerVeritabaniServisi().baslat(),
        () => UretimlerVeritabaniServisi().baslat(),
        () => SiparislerVeritabaniServisi().baslat(),
        () => TekliflerVeritabaniServisi().baslat(),
        () => PersonelIslemleriVeritabaniServisi().baslat(),
      ];

      for (final step in steps) {
        if (myToken != _token) return;
        try {
          await step();
        } catch (e) {
          // Best-effort: tek bir modül fail olursa tüm bootstrap'i durdurma.
          if (kDebugMode) {
            debugPrint('BulutSemaBootstrap: adım hatası: $e');
          }
        }
      }

      if (myToken != _token) return;

      final okAfter = await BulutSemaDogrulamaServisi().bulutSemasiHazirMi(
        executor: pool,
        databaseName: dbName,
      );

      if (kDebugMode) {
        debugPrint(
          okAfter
              ? 'BulutSemaBootstrap: Bulut şema hazır.'
              : 'BulutSemaBootstrap: Bootstrap tamamlandı ama şema hâlâ eksik (yetki/managed kısıtı olabilir).',
        );
      }
    } finally {
      _inFlight = null;
    }
  }
}
