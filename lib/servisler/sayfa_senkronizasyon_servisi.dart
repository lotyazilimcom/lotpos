import 'package:flutter/foundation.dart';
import 'dart:async';

/// [SayfaSenkronizasyonServisi]
/// Uygulama genelinde veritabanı değişikliklerini sayfalara bildirmek için kullanılır.
/// Singleton pattern kullanılarak her yerden erişilebilir.
class SayfaSenkronizasyonServisi extends ChangeNotifier {
  static final SayfaSenkronizasyonServisi _instance =
      SayfaSenkronizasyonServisi._internal();
  factory SayfaSenkronizasyonServisi() => _instance;
  SayfaSenkronizasyonServisi._internal();

  static const Duration _debounceWindow = Duration(milliseconds: 140);
  final Map<String, Timer> _debounceTimers = <String, Timer>{};

  /// Veri değiştiğinde tetiklenir
  /// [tur]: Değişen verinin türü (cari, kasa, banka vb.)
  void veriDegisti(String tur) {
    final key = tur.trim().toLowerCase();
    if (key.isEmpty) return;

    // Aynı tür için çok kısa aralıkta gelen tetiklemeleri tek notify'a indir.
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(_debounceWindow, () {
      _debounceTimers.remove(key);
      debugPrint('🔄 Sayfa Senkronizasyonu Tetiklendi: $key');
      notifyListeners();
    });
  }
}
