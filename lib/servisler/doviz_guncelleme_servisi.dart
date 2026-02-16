import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'ayarlar_veritabani_servisi.dart';
import 'lisans_yazma_koruma.dart';
import '../sayfalar/ayarlar/genel_ayarlar/modeller/doviz_kuru_model.dart';

class DovizGuncellemeServisi {
  static final DovizGuncellemeServisi _instance =
      DovizGuncellemeServisi._internal();
  factory DovizGuncellemeServisi() => _instance;
  DovizGuncellemeServisi._internal();

  static const Duration _requestTimeout = Duration(seconds: 8);
  static const int _maxRequestAttempts = 3;
  static const Duration _retryBaseDelay = Duration(milliseconds: 250);

  Timer? _timer;
  bool _isUpdating = false;

  void baslat() {
    debugPrint('DovizGuncellemeServisi: Başlatılıyor...');
    // Hemen bir kere güncelle
    guncelle();
    // Sonra her 15 dakikada bir güncelle
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (timer) {
      debugPrint('DovizGuncellemeServisi: Otomatik güncelleme tetiklendi.');
      guncelle();
    });
  }

  void durdur() {
    _timer?.cancel();
  }

  Future<bool> guncelle() async {
    if (_isUpdating) return false;
    _isUpdating = true;

    try {
      final settings = await AyarlarVeritabaniServisi().genelAyarlariGetir();
      final currencies = settings.kullanilanParaBirimleri
          .map(_normalizeCurrencyCode)
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();

      if (currencies.length < 2) {
        debugPrint('DovizGuncellemeServisi: En az 2 para birimi gereklidir.');
        _isUpdating = false;
        return false;
      }

      // API: open.er-api.com
      // Not: Bu API key gerektirmez ve makul sıklıkta güncellemeler sunar.

      bool anySuccess = false;
      for (final from in currencies) {
        try {
          final data = await _fetchRatesDataBestEffort(from, currencies);
          if (data != null) {
            if (data['result'] == 'success') {
              final rates = data['rates'] as Map<String, dynamic>?;
              if (rates == null) {
                debugPrint(
                  'DovizGuncellemeServisi: $from için rates verisi bulunamadı.',
                );
                continue;
              }
              final updateTime = DateTime.now();

              for (final to in currencies) {
                if (from == to) continue;
                if (rates.containsKey(to)) {
                  final rate = (rates[to] as num).toDouble();
                  await AyarlarVeritabaniServisi().kurKaydet(
                    DovizKuruModel(
                      kaynakParaBirimi: from,
                      hedefParaBirimi: to,
                      kur: rate,
                      guncellemeZamani: updateTime,
                    ),
                  );
                  anySuccess = true;
                }
              }
            }
          }
        } catch (e) {
          if (e is LisansYazmaEngelliHatasi) {
            _isUpdating = false;
            return false;
          }
          debugPrint('DovizGuncellemeServisi: $from kuru alınırken hata: $e');
        }
      }

      if (anySuccess) {
        debugPrint('DovizGuncellemeServisi: Kurlar başarıyla güncellendi.');
      } else {
        debugPrint('DovizGuncellemeServisi: Hiçbir kur güncellenemedi.');
      }

      _isUpdating = false;
      return anySuccess;
    } catch (e) {
      if (e is LisansYazmaEngelliHatasi) {
        _isUpdating = false;
        return false;
      }
      debugPrint('DovizGuncellemeServisi: Genel güncelleme hatası: $e');
      _isUpdating = false;
      return false;
    }
  }

  String _normalizeCurrencyCode(String code) {
    final c = code.trim().toUpperCase();
    if (c == 'TL') return 'TRY';
    return c;
  }

  Future<Map<String, dynamic>?> _fetchRatesDataBestEffort(
    String base,
    List<String> currencies,
  ) async {
    final symbols = currencies.where((c) => c != base).toSet();
    if (symbols.isEmpty) {
      return {'result': 'success', 'rates': <String, dynamic>{}};
    }

    // 1) open.er-api.com (no key)
    final openEr = await _getJsonWithRetry(
      Uri.parse('https://open.er-api.com/v6/latest/$base'),
    );
    if (openEr != null &&
        openEr['result'] == 'success' &&
        openEr['rates'] is Map) {
      return openEr;
    }

    // 2) frankfurter.app (no key)
    final frankfurter = await _getJsonWithRetry(
      Uri.https('api.frankfurter.app', '/latest', {
        'from': base,
        'to': symbols.join(','),
      }),
    );
    if (frankfurter != null && frankfurter['rates'] is Map) {
      return {'result': 'success', 'rates': frankfurter['rates']};
    }

    // 3) fawaz currency-api via pages.dev (no key, broad coverage)
    final baseLower = base.toLowerCase();
    final fawaz = await _getJsonWithRetry(
      Uri.parse(
        'https://latest.currency-api.pages.dev/v1/currencies/$baseLower.json',
      ),
    );
    if (fawaz != null && fawaz[baseLower] is Map) {
      final raw = Map<String, dynamic>.from(fawaz[baseLower] as Map);
      final rates = <String, dynamic>{};
      for (final to in symbols) {
        final v = raw[to.toLowerCase()];
        if (v is num) rates[to] = v;
      }
      return {'result': 'success', 'rates': rates};
    }

    return null;
  }

  Future<Map<String, dynamic>?> _getJsonWithRetry(Uri uri) async {
    for (int attempt = 1; attempt <= _maxRequestAttempts; attempt++) {
      try {
        final response = await http.get(uri).timeout(_requestTimeout);
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          return decoded is Map<String, dynamic> ? decoded : null;
        }

        final retryableStatus =
            response.statusCode == 429 || response.statusCode >= 500;
        if (attempt < _maxRequestAttempts && retryableStatus) {
          await Future.delayed(_retryDelay(attempt));
          continue;
        }
        return null;
      } catch (e) {
        if (attempt < _maxRequestAttempts && _isRetryableNetworkError(e)) {
          await Future.delayed(_retryDelay(attempt));
          continue;
        }
        return null;
      }
    }
    return null;
  }

  Duration _retryDelay(int attempt) {
    final ms = _retryBaseDelay.inMilliseconds * attempt;
    return Duration(milliseconds: ms);
  }

  bool _isRetryableNetworkError(Object e) {
    return e is TimeoutException ||
        e is SocketException ||
        e is HandshakeException ||
        e is http.ClientException;
  }
}
