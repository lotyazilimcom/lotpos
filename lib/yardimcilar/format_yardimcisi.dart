import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class FormatYardimcisi {
  static const List<String> _trBirler = [
    '',
    'Bir',
    'İki',
    'Üç',
    'Dört',
    'Beş',
    'Altı',
    'Yedi',
    'Sekiz',
    'Dokuz',
  ];

  static const List<String> _trOnlar = [
    '',
    'On',
    'Yirmi',
    'Otuz',
    'Kırk',
    'Elli',
    'Altmış',
    'Yetmiş',
    'Seksen',
    'Doksan',
  ];

  static const List<String> _trGruplar = [
    '',
    'Bin',
    'Milyon',
    'Milyar',
    'Trilyon',
    'Katrilyon',
    'Kentilyon',
  ];

  static String sayiFormatla(
    dynamic sayi, {
    String binlik = '.',
    String ondalik = ',',
    int? decimalDigits,
  }) {
    if (sayi == null) return '';
    if (sayi is String) {
      if (sayi.trim().isEmpty) return '';
      // Temizle ve double'a çevir
      final temiz = sayi.replaceAll(binlik, '').replaceAll(ondalik, '.');
      sayi = double.tryParse(temiz) ?? 0;
    }

    double deger;
    if (sayi is num) {
      deger = sayi.toDouble();
    } else {
      return '';
    }

    // Standart en_US formatı (binlik: , ondalık: .)
    // Ondalık kısmı yoksa gösterme
    String pattern;
    final int? decimals = decimalDigits;

    if (deger % 1 == 0 || (decimals != null && decimals == 0)) {
      // Tam sayı ise veya ondalık basamak istemiyorsak
      pattern = '#,###';
    } else {
      final int usedDecimals = decimals ?? 2;
      if (usedDecimals <= 0) {
        pattern = '#,###';
      } else {
        // Örn: 2 için "#,###.##", 4 için "#,###.####"
        pattern = '#,###.${'#' * usedDecimals}';
      }
    }

    final formatter = NumberFormat(pattern, 'en_US');
    String formatted = formatter.format(deger);

    // Sembolleri değiştir
    formatted = formatted.replaceAll(',', '###GROUP###');
    formatted = formatted.replaceAll('.', '###DECIMAL###');

    formatted = formatted.replaceAll('###GROUP###', binlik);
    formatted = formatted.replaceAll('###DECIMAL###', ondalik);

    return formatted;
  }

  /// KDV / oran formatı
  ///
  /// - Tam sayı ise: sadece tam kısmı gösterir (ör: 18)
  /// - Ondalıklı ise: [decimalDigits] kadar sabit ondalık gösterir (ör: 18,20)
  static String sayiFormatlaOran(
    dynamic sayi, {
    String binlik = '.',
    String ondalik = ',',
    int decimalDigits = 2,
  }) {
    if (sayi == null) return '';
    if (sayi is String) {
      if (sayi.trim().isEmpty) return '';
      final temiz = sayi.replaceAll(binlik, '').replaceAll(ondalik, '.');
      sayi = double.tryParse(temiz) ?? 0;
    }

    double deger;
    if (sayi is num) {
      deger = sayi.toDouble();
    } else {
      return '';
    }

    // Ondalık kısmı yoksa sade göster
    if (deger % 1 == 0) {
      return sayiFormatla(
        deger,
        binlik: binlik,
        ondalik: ondalik,
        decimalDigits: 0,
      );
    }

    // Ondalıklıysa sabit basamak sayısıyla göster
    return sayiFormatlaOndalikli(
      deger,
      binlik: binlik,
      ondalik: ondalik,
      decimalDigits: decimalDigits,
    );
  }

  static String sayiFormatlaOndalikli(
    dynamic sayi, {
    String binlik = '.',
    String ondalik = ',',
    int decimalDigits = 2,
  }) {
    if (sayi == null) return '';
    if (sayi is String) {
      if (sayi.isEmpty) return '';
      final temiz = sayi.replaceAll(binlik, '').replaceAll(ondalik, '.');
      sayi = double.tryParse(temiz) ?? 0;
    }

    double deger;
    if (sayi is num) {
      deger = sayi.toDouble();
    } else {
      return '';
    }

    final String decimalPattern = decimalDigits > 0
        ? '.${'0' * decimalDigits}'
        : '';
    final String pattern = '#,##0$decimalPattern';

    final formatter = NumberFormat(pattern, 'en_US');
    String formatted = formatter.format(deger);

    formatted = formatted.replaceAll(',', '###GROUP###');
    formatted = formatted.replaceAll('.', '###DECIMAL###');

    formatted = formatted.replaceAll('###GROUP###', binlik);
    formatted = formatted.replaceAll('###DECIMAL###', ondalik);

    return formatted;
  }

  static double parseDouble(
    String text, {
    String binlik = '.',
    String ondalik = ',',
  }) {
    if (text.isEmpty) return 0;
    String clean = text.replaceAll(binlik, '').replaceAll(ondalik, '.');
    return double.tryParse(clean) ?? 0;
  }

  static String ibanFormatla(String iban) {
    if (iban.isEmpty) return '';
    // Boşlukları temizle
    String clean = iban.replaceAll(' ', '');
    // 4'erli bloklara ayır
    List<String> blocks = [];
    for (int i = 0; i < clean.length; i += 4) {
      if (i + 4 < clean.length) {
        blocks.add(clean.substring(i, i + 4));
      } else {
        blocks.add(clean.substring(i));
      }
    }
    return blocks.join(' ');
  }

  static String paraBirimiSembol(String code) {
    final normalized = code.trim().toUpperCase();
    return switch (normalized) {
      'TRY' || 'TL' => '₺',
      'USD' => r'$',
      'EUR' => '€',
      'GBP' => '£',
      'JPY' => '¥',
      'RUB' => '₽',
      _ => normalized.isEmpty ? '' : normalized,
    };
  }

  static String tutarYaziyaCevir(
    num tutar, {
    String paraBirimiKodu = 'TRY',
    bool yalnizEkle = true,
    int kurusBasamak = 2,
  }) {
    final normalizedCurrency = paraBirimiKodu.trim().toUpperCase();

    String anaBirim;
    String altBirim;
    switch (normalizedCurrency) {
      case 'TRY':
      case 'TL':
        anaBirim = 'Türk Lirası';
        altBirim = 'Kuruş';
        break;
      case 'USD':
        anaBirim = 'Dolar';
        altBirim = 'Cent';
        break;
      case 'EUR':
        anaBirim = 'Euro';
        altBirim = 'Cent';
        break;
      case 'GBP':
        anaBirim = 'Sterlin';
        altBirim = 'Peni';
        break;
      default:
        anaBirim = normalizedCurrency.isEmpty ? '' : normalizedCurrency;
        altBirim = '';
    }

    final bool isNegative = tutar < 0;
    final double absValue = tutar.abs().toDouble();

    final int digits = kurusBasamak < 0 ? 0 : kurusBasamak;
    final int factor = _pow10(digits);
    final int scaled = (absValue * factor).round();
    final int whole = factor == 0 ? scaled : (scaled ~/ factor);
    final int fraction = factor == 0 ? 0 : (scaled % factor);

    final parts = <String>[];
    if (yalnizEkle) parts.add('Yalnız');
    if (isNegative) parts.add('Eksi');

    parts.add(_sayiYaziyaCevir(whole));
    if (anaBirim.isNotEmpty) parts.add(anaBirim);

    if (digits > 0 && fraction > 0 && altBirim.isNotEmpty) {
      parts.add(_sayiYaziyaCevir(fraction));
      parts.add(altBirim);
    }

    return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static int _pow10(int exponent) {
    if (exponent <= 0) return 1;
    int result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  static String _sayiYaziyaCevir(int sayi) {
    if (sayi == 0) return 'Sıfır';

    int n = sayi;
    final parts = <String>[];
    int groupIndex = 0;

    while (n > 0) {
      final int group = n % 1000;
      if (group != 0) {
        String groupText;
        String scale = _trGruplar.length > groupIndex ? _trGruplar[groupIndex] : '';

        if (groupIndex == 1 && group == 1) {
          // 1.000 = "Bin" (Bir Bin değil)
          groupText = 'Bin';
          scale = '';
        } else {
          groupText = _ucHaneYazi(group);
        }

        final combined = [
          groupText,
          if (scale.isNotEmpty) scale,
        ].join(' ').trim();

        if (combined.isNotEmpty) {
          parts.insert(0, combined);
        }
      }
      n ~/= 1000;
      groupIndex++;
    }

    return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _ucHaneYazi(int sayi) {
    if (sayi == 0) return '';
    final int yuzler = sayi ~/ 100;
    final int onlar = (sayi % 100) ~/ 10;
    final int birler = sayi % 10;

    final parts = <String>[];
    if (yuzler > 0) {
      if (yuzler == 1) {
        parts.add('Yüz');
      } else {
        parts.add(_trBirler[yuzler]);
        parts.add('Yüz');
      }
    }
    if (onlar > 0) {
      parts.add(_trOnlar[onlar]);
    }
    if (birler > 0) {
      parts.add(_trBirler[birler]);
    }
    return parts.join(' ').trim();
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  final String binlik;
  final String ondalik;
  final int? maxDecimalDigits;

  CurrencyInputFormatter({
    this.binlik = '.',
    this.ondalik = ',',
    this.maxDecimalDigits,
  });

  String _formatIntegerPart(String digits) {
    if (digits.isEmpty) return '0';
    try {
      final number = int.parse(digits);
      final formatter = NumberFormat("#,###", "en_US");
      return formatter.format(number).replaceAll(',', binlik);
    } catch (_) {
      return digits;
    }
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final raw = newValue.text;

    final endsWithSeparator = raw.endsWith('.') || raw.endsWith(',');
    final lastDot = raw.lastIndexOf('.');
    final lastComma = raw.lastIndexOf(',');
    final hasDot = lastDot != -1;
    final hasComma = lastComma != -1;

    bool treatAsDecimal = false;
    int decimalIndex = -1;

    if (endsWithSeparator) {
      treatAsDecimal = true;
      decimalIndex = raw.length - 1;
    } else if (hasDot && hasComma) {
      treatAsDecimal = true;
      decimalIndex = lastDot > lastComma ? lastDot : lastComma;
    } else if (hasDot || hasComma) {
      final sep = hasDot ? '.' : ',';
      final sepCount = raw.split(sep).length - 1;

      if (sepCount == 1) {
        decimalIndex = raw.lastIndexOf(sep);
        final digitsAfter = raw.length - decimalIndex - 1;
        final treatByConfig = sep == ondalik;
        final treatByMax = maxDecimalDigits != null &&
            digitsAfter > 0 &&
            digitsAfter <= maxDecimalDigits!;
        treatAsDecimal = digitsAfter > 0 && (treatByConfig || treatByMax);
      }
    }

    if (treatAsDecimal) {
      final String integerRaw;
      final String decimalRaw;
      if (endsWithSeparator) {
        integerRaw = raw.substring(0, raw.length - 1);
        decimalRaw = '';
      } else {
        integerRaw = raw.substring(0, decimalIndex);
        decimalRaw = raw.substring(decimalIndex + 1);
      }

      String integerDigits = integerRaw.replaceAll(RegExp(r'[^0-9]'), '');
      if (integerDigits.isEmpty) {
        integerDigits = '0';
      }
      final formattedInteger = _formatIntegerPart(integerDigits);

      String decimalDigits = decimalRaw.replaceAll(RegExp(r'[^0-9]'), '');
      if (maxDecimalDigits != null && decimalDigits.length > maxDecimalDigits!) {
        decimalDigits = decimalDigits.substring(0, maxDecimalDigits!);
      }

      final formatted = '$formattedInteger$ondalik$decimalDigits';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    // Integer only
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final formatted = _formatIntegerPart(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
