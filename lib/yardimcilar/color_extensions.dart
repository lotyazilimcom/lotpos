import 'package:flutter/material.dart';

/// Color sınıfı için alpha değerini ayarlamaya yarayan uzantı.
///
/// Örnek Kullanım:
/// ```dart
/// Colors.blue.withValues(alpha: 0.5)
/// ```
extension ColorAlphaExtension on Color {
  /// Belirtilen alpha değeri ile yeni bir renk döndürür.
  ///
  /// [alpha] değeri 0.0 (tamamen saydam) ile 1.0 (tamamen opak) arasında olmalıdır.
  Color withValues({double? alpha}) {
    if (alpha == null) return this;
    // Alpha değerini 0.0-1.0 aralığında tut
    final clampedAlpha = alpha.clamp(0.0, 1.0);
    // Yeni Color API'sine uygun şekilde ARGB ile oluşturuyoruz
    // r, g, b değerleri 0.0-1.0 aralığında, 255 ile çarpıp int'e çeviriyoruz
    return Color.fromARGB(
      (clampedAlpha * 255).round(),
      (r * 255.0).round() & 0xff,
      (g * 255.0).round() & 0xff,
      (b * 255.0).round() & 0xff,
    );
  }
}
