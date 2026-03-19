import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lospos/servisler/veritabani_yapilandirma.dart';
import 'package:lospos/yardimcilar/ceviri/ceviri_servisi.dart';

class YazdirmaErisimKontrolu {
  const YazdirmaErisimKontrolu._();

  static bool get mobilBulutYazdirmaPasif {
    if (kIsWeb) return false;
    if (!(Platform.isAndroid || Platform.isIOS)) return false;
    return VeritabaniYapilandirma.connectionMode == 'cloud';
  }

  static bool get mobilYerelAgMasaustuYazdirmaAktif {
    if (kIsWeb) return false;
    if (!(Platform.isAndroid || Platform.isIOS)) return false;
    final mode = VeritabaniYapilandirma.connectionMode;
    return mode == 'local' || mode == 'hybrid';
  }

  static bool get yazdirmaKullanilabilir => !mobilBulutYazdirmaPasif;

  static bool isPrintIcon(IconData icon) {
    return _matches(icon, Icons.print) ||
        _matches(icon, Icons.print_outlined) ||
        _matches(icon, Icons.print_rounded);
  }

  static String tooltip([String? enabledTooltip]) {
    if (mobilBulutYazdirmaPasif) {
      return tr('print.disabled.mobile_cloud');
    }
    return enabledTooltip ?? tr('common.print');
  }

  static bool _matches(IconData a, IconData b) {
    return a.codePoint == b.codePoint &&
        a.fontFamily == b.fontFamily &&
        a.fontPackage == b.fontPackage;
  }
}
